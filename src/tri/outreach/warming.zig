//! Domain Warming Schedule — Critical for new domain reputation
//!
//! PROBLEM: New domain t27.ai has no email reputation.
//! Sending 10 emails Day 1 = immediate spam classification.
//!
//! SOLUTION: Gradual warming over 4 weeks
//! - Week 1: 2-3 emails/day (golden ratio allies only)
//! - Week 2: 5 emails/day (add VSA experts)
//! - Week 3: 7 emails/day (add LQG physicists)
//! - Week 4+: 10 emails/day (full speed)
//!
//! DATA: First follow-up after 14 days increases response by 50%
//! Adding third follow-up DECREASES effectiveness.
//! Source: https://stripo.email/blog/five-data-driven-ways-to-improve-cold-email-response-rates/

const std = @import("std");

pub const WarmingWeek = struct {
    week: u32,
    daily_limit: u32,
    focus: []const u8,
    scientists: []const []const u8, // Names or IDs
};

/// Warming schedule — WHO to send WHEN
pub const schedule = [_]WarmingWeek{
    .{
        .week = 1,
        .daily_limit = 2,
        .focus = "Golden Ratio Allies (parallel discovery)",
        .scientists = &[_][]const u8{
            "Michael Sherbon", // α↔φ parallel discovery
            "Kostas Karpougas", // φ⁵ formulas
            // Day 2-3: Enos Øye (α↔φ via electron wavelength)
        },
    },
    .{
        .week = 2,
        .daily_limit = 3,
        .focus = "VSA Community (experts for review)",
        .scientists = &[_][]const u8{
            "Denis Kleyko", // VSA survey author
            "Pentti Kanerva", // VSA founder
            "Abbas Rahimi", // HDC hardware
        },
    },
    .{
        .week = 3,
        .daily_limit = 5,
        .focus = "LQG + Cosmology (γ parameter, G constant)",
        .scientists = &[_][]const u8{
            "Lee Smolin", // LQG, DELTA-001
            "Carlo Rovelli", // t_present = φ⁻²
            "Sabine Hossenfelder", // FAILURES FIRST
            "Niayesh Afshordi", // Ω_Λ from φ
            "Ekkehard Peik", // CODATA verification
        },
    },
    .{
        .week = 4,
        .daily_limit = 7,
        .focus = "Particle Physics + AI",
        .scientists = &[_][]const u8{
            "Cecilia Jarlskog", // CKM matrix
            "Stephen Parke", // PMNS matrix
            "François Chollet", // ARC via VSA
            "Hongyu Wang", // BitNet {-1,0,+1}
            "Jan Rabaey", // FPGA evaluation
            "Garrett Lisi", // E₈ × VSA
            "Stephanie Wehner", // CHSH from VSA
        },
    },
    .{
        .week = 5,
        .daily_limit = 10,
        .focus = "Full speed — remaining scientists",
        .scientists = &[_][]const u8{
            // All remaining Tier 2-3 scientists
        },
    },
};

/// Get daily limit for current warming week
pub fn getDailyLimit(week: u32) u32 {
    for (schedule) |w| {
        if (w.week == week) return w.daily_limit;
    }
    return 10; // Default after week 5
}

/// Get focus description for current week
pub fn getFocus(week: u32) []const u8 {
    for (schedule) |w| {
        if (w.week == week) return w.focus;
    }
    return "All remaining scientists";
}

/// Check if we should send to this scientist this week
pub fn shouldSendThisWeek(week: u32, scientist_name: []const u8) bool {
    for (schedule[0..@min(week, schedule.len)]) |w| {
        for (w.scientists) |s| {
            if (std.mem.indexOf(u8, s, scientist_name) != null) {
                return true;
            }
        }
    }
    return week >= 5; // After week 4, send to everyone
}

/// Calculate warming week from start date
pub fn getCurrentWeek(start_date: i64, current_date: i64) u32 {
    const seconds_per_week = 7 * 24 * 60 * 60;
    const weeks_since_start = @as(u32, @intCast((current_date - start_date) / seconds_per_week));
    return @min(weeks_since_start + 1, 5); // Cap at week 5
}

/// Follow-up schedule — WHEN to send follow-ups
/// KEY: 14 days first follow-up (not 7!), 21 days second
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
    try std.testing.expectEqual(@as(u32, 2), getDailyLimit(1));
    try std.testing.expectEqual(@as(u32, 3), getDailyLimit(2));
    try std.testing.expectEqual(@as(u32, 5), getDailyLimit(3));
    try std.testing.expectEqual(@as(u32, 7), getDailyLimit(4));
    try std.testing.expectEqual(@as(u32, 10), getDailyLimit(5));
    try std.testing.expectEqual(@as(u32, 10), getDailyLimit(99));
}

test "shouldSendThisWeek" {
    const std = @import("std");
    try std.testing.expect(shouldSendThisWeek(1, "Michael Sherbon"));
    try std.testing.expect(shouldSendThisWeek(1, "Kostas Karpougas"));
    try std.testing.expect(shouldSendThisWeek(2, "Denis Kleyko"));
    try std.testing.expect(!shouldSendThisWeek(1, "Denis Kleyko")); // Week 2 only
}
