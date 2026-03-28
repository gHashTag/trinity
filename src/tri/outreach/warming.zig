//! Domain Warming Schedule — Critical for new domain reputation
//!
//! PROBLEM: New domain t27.ai has no email reputation.
//! Sending 10 emails Day 1 = immediate spam classification.
//!
//! SOLUTION: 14-day manual warmup + gradual scaling over 5 weeks
//! - Days 1-14: Manual warmup (send to self + reply)
//! - Days 15-21: Engaged contacts (3-5/day)
//! - Days 22-28: Scaling (5-8/day)
//! - Day 29+: Full volume (10/day)
//!
//! DATA: First follow-up after 14 days increases response by 50%
//! Adding third follow-up DECREASES effectiveness.
//! Source: https://stripo.email/blog/five-data-driven-ways-to-improve-cold-email-response-rates/
//! Reference: https://leadsmonky.com/warm-up-your-email-domain-for-cold-outreach/

const std = @import("std");

pub const WarmingWeek = struct {
    week: u32,
    day_start: u32,
    day_end: u32,
    daily_limit: u32,
    phase: []const u8,
    focus: []const u8,
    scientists: []const []const u8,
};

/// Warming schedule — WHO to send WHEN
/// Phase 1 (Days 1-14): Manual warmup to self
/// Phase 2 (Days 15-21): Engaged contacts
/// Phase 3 (Days 22-28): Scaling
/// Phase 4 (Day 29+): Full volume
pub const schedule = [_]WarmingWeek{
    // Phase 1: Manual Warmup (Days 1-14) — Send to yourself!
    // Send to personal Gmail/Outlook/Yahoo, then OPEN + REPLY + mark "not spam"
    .{
        .week = 0,
        .day_start = 1,
        .day_end = 14,
        .daily_limit = 3,
        .phase = "manual_warmup",
        .focus = "Send to YOUR personal accounts (Gmail, Outlook, Yahoo) — then OPEN + REPLY + mark 'not spam'",
        .scientists = &[_][]const u8{
            "your-personal-gmail",
            "your-personal-outlook",
            "your-personal-yahoo",
        },
    },
    // Phase 2: Engaged Contacts (Days 15-21)
    .{
        .week = 1,
        .day_start = 15,
        .day_end = 21,
        .daily_limit = 3,
        .phase = "engaged_contacts",
        .focus = "Golden Ratio Allies (parallel discovery — high reply rate expected)",
        .scientists = &[_][]const u8{
            "Michael Sherbon", // α↔φ parallel discovery
            "Kostas Karpougas", // φ⁵ formulas
            "Enos Øye", // α↔φ via electron wavelength
        },
    },
    // Phase 3: Scaling (Days 22-28)
    .{
        .week = 2,
        .day_start = 22,
        .day_end = 28,
        .daily_limit = 5,
        .phase = "scaling",
        .focus = "VSA Community (experts for review)",
        .scientists = &[_][]const u8{
            "Denis Kleyko", // VSA survey author
            "Pentti Kanerva", // VSA founder
            "Abbas Rahimi", // HDC hardware
            "Jan Rabaey", // FPGA evaluation
            "Hongyu Wang", // BitNet {-1,0,+1}
        },
    },
    // Phase 4: Full Volume (Day 29+)
    .{
        .week = 3,
        .day_start = 29,
        .day_end = 35,
        .daily_limit = 8,
        .phase = "full_volume",
        .focus = "LQG + Cosmology (γ parameter, G constant)",
        .scientists = &[_][]const u8{
            "Lee Smolin", // LQG, DELTA-001
            "Carlo Rovelli", // t_present = φ⁻²
            "Sabine Hossenfelder", // FAILURES FIRST
            "Niayesh Afshordi", // Ω_Λ from φ
            "Ekkehard Peik", // CODATA verification
            "Cecilia Jarlskog", // CKM matrix
            "Stephen Parke", // PMNS matrix
        },
    },
    .{
        .week = 4,
        .day_start = 36,
        .day_end = 42,
        .daily_limit = 10,
        .phase = "full_volume",
        .focus = "Particle Physics + AI",
        .scientists = &[_][]const u8{
            "François Chollet", // ARC via VSA
            "Garrett Lisi", // E₈ × VSA
            "Stephanie Wehner", // CHSH from VSA
            "Giulio Tononi", // IIT consciousness
        },
    },
    .{
        .week = 5,
        .day_start = 43,
        .day_end = 999,
        .daily_limit = 10,
        .phase = "full_volume",
        .focus = "Full speed — all remaining scientists",
        .scientists = &[_][]const u8{
            // All remaining scientists
        },
    },
};

/// Get daily limit for current day since start
pub fn getDailyLimit(days_since_start: u32) u32 {
    for (schedule) |w| {
        if (days_since_start >= w.day_start and days_since_start <= w.day_end) {
            return w.daily_limit;
        }
    }
    return 10; // Default after week 5
}

/// Get current phase (manual_warmup, engaged_contacts, scaling, full_volume)
pub fn getPhase(days_since_start: u32) []const u8 {
    for (schedule) |w| {
        if (days_since_start >= w.day_start and days_since_start <= w.day_end) {
            return w.phase;
        }
    }
    return "full_volume";
}

/// Get focus description for current day
pub fn getFocus(days_since_start: u32) []const u8 {
    for (schedule) |w| {
        if (days_since_start >= w.day_start and days_since_start <= w.day_end) {
            return w.focus;
        }
    }
    return "All remaining scientists";
}

/// Check if manual warmup is needed (days 1-14)
pub fn needsManualWarmup(days_since_start: u32) bool {
    return days_since_start <= 14;
}

/// Check if we should send to this scientist this week
pub fn shouldSendThisWeek(days_since_start: u32, scientist_name: []const u8) bool {
    const current_week = getCurrentWeek(days_since_start);

    for (schedule[0 .. current_week + 1]) |w| {
        for (w.scientists) |s| {
            if (std.mem.indexOf(u8, s, scientist_name)) |_| {
                return true;
            }
        }
    }

    return current_week >= 5; // After week 5, send to everyone
}

/// Get current week number (0-indexed)
fn getCurrentWeek(days_since_start: u32) usize {
    for (schedule, 0..) |w, i| {
        if (days_since_start >= w.day_start and days_since_start <= w.day_end) {
            return i;
        }
    }
    return schedule.len - 1;
}

/// Calculate warming week from start date
pub fn getWeekNumber(start_date: i64, current_date: i64) u32 {
    const seconds_per_day = 24 * 60 * 60;
    const days_since_start = @as(u32, @intCast((current_date - start_date) / seconds_per_day));
    return @as(u32, @intCast(getCurrentWeek(days_since_start)));
}

/// Follow-up schedule — 14 days first, 21 days second (NOT 7 days!)
pub const FollowUpSchedule = struct {
    days_after_send: u32,
    template_id: []const u8,

    pub const all = [_]FollowUpSchedule{
        .{ .days_after_send = 14, .template_id = "followup_1_gentle" },
        .{ .days_after_send = 21, .template_id = "followup_2_final" },
    };
};

/// Get pending follow-ups for a scientist
pub fn getPendingFollowUps(sent_date: i64, current_date: i64, follow_up_count: u32) std.ArrayList(FollowUpSchedule) {
    _ = sent_date;
    _ = current_date;
    _ = follow_up_count;
    // TODO: Implement
    return std.ArrayList(FollowUpSchedule).init(std.heap.page_allocator);
}

/// Timezone-aware sending — send 6-9 AM recipient's local time
pub const SendWindow = struct {
    start_hour_utc: u8,
    end_hour_utc: u8,

    /// Get optimal send time for recipient timezone
    pub fn getOptimalSendTime(recipient_timezone: []const u8) !struct { hour: u8, minute: u8 } {
        _ = recipient_timezone;
        // TODO: Implement timezone conversion
        // For now, default to 9 AM UTC (works for Europe morning)
        return .{ .hour = 9, .minute = 0 };
    }

    /// Check if current time is within optimal window
    pub fn isWithinWindow(current_hour_utc: u8) bool {
        _ = current_hour_utc;
        return true; // TODO: Implement
    }
};

test "warming schedule" {
    const std = @import("std");

    // Manual warmup phase
    try std.testing.expectEqual(@as(u32, 3), getDailyLimit(1));
    try std.testing.expectEqual(@as(u32, 3), getDailyLimit(14));
    try std.testing.expectEqual(@as(u32, 3), getDailyLimit(15));

    // Scaling phase
    try std.testing.expectEqual(@as(u32, 5), getDailyLimit(22));

    // Full volume
    try std.testing.expectEqual(@as(u32, 10), getDailyLimit(35));
    try std.testing.expectEqual(@as(u32, 10), getDailyLimit(99));
}

test "shouldSendThisWeek" {
    const std = @import("std");

    // During manual warmup, no real scientists
    try std.testing.expect(!shouldSendThisWeek(5, "Michael Sherbon"));

    // Week 1 (days 15-21)
    try std.testing.expect(shouldSendThisWeek(15, "Michael Sherbon"));
    try std.testing.expect(shouldSendThisWeek(15, "Kostas Karpougas"));
    try std.testing.expect(!shouldSendThisWeek(15, "Denis Kleyko")); // Week 2 only
}

test "needsManualWarmup" {
    const std = @import("std");

    try std.testing.expect(needsManualWarmup(1));
    try std.testing.expect(needsManualWarmup(14));
    try std.testing.expect(!needsManualWarmup(15));
}

test "getPhase" {
    const std = @import("std");

    try std.testing.expectEqualStrings("manual_warmup", getPhase(1));
    try std.testing.expectEqualStrings("manual_warmup", getPhase(14));
    try std.testing.expectEqualStrings("engaged_contacts", getPhase(15));
    try std.testing.expectEqualStrings("scaling", getPhase(22));
    try std.testing.expectEqualStrings("full_volume", getPhase(29));
}
