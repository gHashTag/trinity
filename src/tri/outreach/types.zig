//! Trinity Outreach System — Scientist email outreach with proper deliverability
//!
//! CRITICAL FIXES (2026-03-28):
//! - Email resolution from institutional pages
//! - Shortened templates (80-120 words, not 300+)
//! - Domain warming schedule (2→10 emails/day)
//! - 14-day follow-up (not 7-day)
//! - Bounce handling
//! - Timezone awareness
//! - In-Reply-To headers
//! - Unsubscribe link (CAN-SPAM)

const std = @import("std");

/// Scientist contact information
pub const Scientist = struct {
    id: u32,
    name: []const u8,
    org: []const u8,
    field: []const u8,
    hook: []const u8,

    /// Email address — may be placeholder like "ResearchGate" requiring resolution
    email: []const u8,

    /// Email source: "direct", "institution", "arXiv", "social", "unknown"
    email_source: []const u8,

    priority: Priority,
    tier: Tier,
    arxiv_id: ?[]const u8 = null,

    /// Institutional URL for email resolution if email is placeholder
    institutional_url: ?[]const u8 = null,
};

pub const Priority = enum(u8) {
    /// Day 1-2: Sherbon, Karpouzas (α↔φ parallel discovery)
    warming_week1_day1,
    warming_week1_day2,
    warming_week1_day3,

    /// Week 2: VSA community
    week2,

    /// Week 3: LQG + cosmology
    week3,

    /// Week 4: Particle physics + AI
    week4,
};

pub const Tier = enum(u8) {
    /// Golden Ratio + Constants allies (Sherbon, Karpougas, Øye)
    golden_ratio_allies,

    /// VSA / HDC experts (Kleyko, Kanerva, Rahimi)
    vsa_experts,

    /// Ternary / BitNet / Quantized NN (BitNet authors, TerEffic)
    ternary_researchers,

    /// Loop Quantum Gravity (Smolin, Rovelli, Ashtekar)
    lqg_physicists,

    /// Cosmology / Dark Energy (Afshordi, Peik)
    cosmologists,

    /// Particle Physics (Jarlskog, Parke)
    particle_physicists,

    /// FPGA / Open Source Hardware (Rabaey, Yosys devs)
    fpga_researchers,

    /// AI / ML (Chollet, Marcus)
    ai_researchers,

    /// Physics Critics + Communicators (Hossenfelder, Baez, Woit)
    critics,

    /// High-value bonus (Wolfram, LeCun, Karpathy)
    bonus,
};

pub const OutreachStatus = enum(u8) {
    pending,
    queued,

    /// Sent successfully
    sent,

    /// Confirmed delivered (via SMTP response)
    delivered,

    /// Opened (if tracking enabled)
    opened,

    /// Replied — scientist responded
    replied,

    /// Engaged — ongoing conversation
    engaged,

    /// Collaborating — active collaboration
    collaborating,

    /// Declined — not interested
    declined,

    /// Bounced — invalid email
    bounced,

    /// Spam complaint — never email again
    spam_complaint,
};

pub const EmailMessage = struct {
    to: []const u8,
    to_name: []const u8,
    subject: []const u8,
    body_text: []const u8,
    body_html: ?[]const u8 = null,

    scientist_id: u32,
    template_id: []const u8,

    sent_at: i64,
    status: OutreachStatus,

    /// For follow-ups — thread this is a reply to
    in_reply_to_message_id: ?[]const u8 = null,

    /// Message-ID for this email (for threading follow-ups)
    message_id: []const u8,

    /// Unsubscribe URL (CAN-SPAM requirement)
    unsubscribe_url: []const u8,
};

pub const OutreachConfig = struct {
    // SMTP settings
    smtp_host: []const u8 = "smtp.zoho.com",
    smtp_port: u16 = 465,
    sender_email: []const u8 = "admin@t27.ai",
    zoho_app_password: []const u8,

    // API settings
    zoho_client_id: []const u8,
    zoho_client_secret: []const u8,
    refresh_token: []const u8,
    account_id: []const u8,

    // Rate limiting — WARMING SCHEDULE
    /// Week 1: 2-3 emails/day
    /// Week 2: 5 emails/day
    /// Week 3: 7 emails/day
    /// Week 4+: 10 emails/day
    daily_limit: u32 = 2,
    interval_seconds: u32 = 30,

    /// Follow-up after 14 days, then 21 days (NOT 7 days!)
    follow_up_days: []const u32 = &.{ 14, 21 },

    /// Send between 6-9 AM recipient's local time
    send_window_start_hour: u8 = 6,
    send_window_end_hour: u8 = 9,

    // Telegram notifications
    telegram_bot_token: []const u8,
    telegram_chat_id: []const u8 = "@t27_dev",

    // Base URL for unsubscribe links
    base_url: []const u8 = "https://t27.ai",

    /// Current warming week (1-4)
    warming_week: u32 = 1,
};

pub const OutreachRecord = struct {
    scientist_id: u32,
    scientist_name: []const u8,

    sent_date: ?i64,
    delivered_date: ?i64,
    opened_date: ?i64,
    replied_date: ?i64,

    status: OutreachStatus,

    /// Email thread (all messages in conversation)
    email_thread: std.ArrayList(EmailMessage),

    /// Last follow-up number (0 = initial, 1 = first follow-up, etc.)
    follow_up_count: u32 = 0,

    /// Bounced reason (if status = .bounced)
    bounce_reason: ?[]const u8 = null,

    /// Never email this scientist again (spam complaint, explicit request)
    do_not_email: bool = false,
};

/// Email resolution result
pub const EmailResolution = struct {
    email: []const u8,
    confidence: f32, // 0.0-1.0
    source: []const u8, // "institutional_page", "google_scholar", "arxiv", "manual"
};

/// Warming schedule — critical for new domain reputation
pub const WarmingSchedule = struct {
    week: u32,
    daily_limit: u32,
    notes: []const u8,

    pub const weeks = [_]WarmingSchedule{
        .{ .week = 1, .daily_limit = 2, .notes = "Sherbon + Karpougas (golden ratio allies)" },
        .{ .week = 2, .daily_limit = 3, .notes = "VSA experts (Kleyko, Kanerva)" },
        .{ .week = 3, .daily_limit = 5, .notes = "LQG physicists (Smolin, Rovelli)" },
        .{ .week = 4, .daily_limit = 7, .notes = "Cosmologists + particle physicists" },
        .{ .week = 5, .daily_limit = 10, .notes = "Full speed — AI + FPGA + bonus" },
    };

    pub fn getDailyLimit(week: u32) u32 {
        for (weeks) |w| {
            if (w.week == week) return w.daily_limit;
        }
        return 10; // Default after week 5
    }
};

test "WarmingSchedule" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 2), WarmingSchedule.getDailyLimit(1));
    try std.testing.expectEqual(@as(u32, 3), WarmingSchedule.getDailyLimit(2));
    try std.testing.expectEqual(@as(u32, 5), WarmingSchedule.getDailyLimit(3));
    try std.testing.expectEqual(@as(u32, 7), WarmingSchedule.getDailyLimit(4));
    try std.testing.expectEqual(@as(u32, 10), WarmingSchedule.getDailyLimit(5));
    try std.testing.expectEqual(@as(u32, 10), WarmingSchedule.getDailyLimit(99));
}
