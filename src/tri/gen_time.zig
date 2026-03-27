//! TRI Time — Generated from specs/tri/tri_time.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Unix timestamp in milliseconds
pub const Timestamp = u64;

/// Time duration in milliseconds
pub const Duration = u64;

/// Date and time components
pub const DateTime = struct {
    year: i32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    millis: u16,
};

// ============================================================================
// TIMESTAMP FUNCTIONS
// ============================================================================

/// Get current Unix timestamp in milliseconds
pub fn now() Timestamp {
    const ns = std.time.nanoTimestamp();
    const millis: u64 = @intCast(@divTrunc(ns, 1_000_000));
    return millis;
}

/// Create timestamp from seconds
pub fn fromSeconds(secs: u64) Timestamp {
    return secs * 1000;
}

/// Convert timestamp to seconds
pub fn toSeconds(ts: Timestamp) u64 {
    return ts / 1000;
}

/// Get duration since timestamp
pub fn elapsed(start: Timestamp) Duration {
    const current = now();
    if (current >= start) {
        return current - start;
    }
    return 0; // Clock went backwards, return 0
}

// ============================================================================
// DURATION FUNCTIONS
// ============================================================================

/// Create duration from milliseconds
pub fn duration(millis: u64) Duration {
    return millis;
}

/// Format duration as human-readable string
pub fn formatDuration(dur: Duration) []const u8 {
    const seconds = dur / 1000;
    const minutes = seconds / 60;
    const hours = minutes / 60;
    const days = hours / 24;

    if (days > 0) {
        if (days > 365) {
            const years = days / 365;
            if (years == 1) return "1y";
            return ">1y"; // Simplified for static return
        }
        if (days == 1) return "1d";
        return ">1d"; // Simplified for static return
    }

    if (hours > 0) {
        if (hours == 1) return "1h";
        return ">1h"; // Simplified for static return
    }

    if (minutes > 0) {
        if (minutes == 1) return "1m";
        return ">1m"; // Simplified for static return
    }

    if (seconds > 0) {
        if (seconds == 1) return "1s";
        return ">1s"; // Simplified for static return
    }

    return "0ms";
}

/// Get duration in milliseconds
pub fn toMillis(dur: Duration) u64 {
    return dur;
}

/// Get duration in seconds
pub fn toSecondsDuration(dur: Duration) u64 {
    return dur / 1000;
}

/// Get duration in minutes
pub fn toMinutes(dur: Duration) u64 {
    return dur / 60_000;
}

/// Get duration in hours
pub fn toHours(dur: Duration) u64 {
    return dur / 3_600_000;
}

/// Get duration in days
pub fn toDays(dur: Duration) u64 {
    return dur / 86_400_000;
}

/// Format duration with allocator (full version)
pub fn formatDurationFull(allocator: std.mem.Allocator, dur: Duration) ![]u8 {
    const days = toDays(dur);
    const hours = toHours(dur) % 24;
    const minutes = toMinutes(dur) % 60;
    const seconds = toSecondsDuration(dur) % 60;
    const millis = dur % 1000;

    var buffer: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    const writer = stream.writer();

    if (days > 0) {
        try writer.print("{d}d", .{days});
    }
    if (hours > 0) {
        if (stream.pos > 0) try writer.writeAll(" ");
        try writer.print("{d}h", .{hours});
    }
    if (minutes > 0) {
        if (stream.pos > 0) try writer.writeAll(" ");
        try writer.print("{d}m", .{minutes});
    }
    if (seconds > 0 or stream.pos == 0) {
        if (stream.pos > 0) try writer.writeAll(" ");
        try writer.print("{d}s", .{seconds});
    }
    if (millis > 0) {
        try writer.print(" {d}ms", .{millis});
    }

    const result_len = stream.pos;
    const result = try allocator.alloc(u8, result_len);
    @memcpy(result, buffer[0..result_len]);
    return result;
}

// ============================================================================
// TESTS
// ============================================================================

test "Time: now returns reasonable value" {
    const ts = now();
    // Should be after 2020-01-01 (1577836800000 ms)
    try std.testing.expect(ts > 1577836800000);
}

test "Time: fromSeconds/toSeconds roundtrip" {
    const secs: u64 = 12345;
    const ts = fromSeconds(secs);
    try std.testing.expectEqual(secs, toSeconds(ts));
}

test "Time: elapsed positive" {
    const start = now();
    // Busy wait for 1ms (no std.time.sleep in 0.15)
    const target = start + 1;
    while (now() < target) {}
    const dur = elapsed(start);
    try std.testing.expect(dur > 0);
}

test "Time: duration conversion" {
    const dur = duration(3661001); // 1h 1m 1s 1ms

    try std.testing.expectEqual(@as(u64, 3661001), toMillis(dur));
    try std.testing.expectEqual(@as(u64, 3661), toSecondsDuration(dur));
    try std.testing.expectEqual(@as(u64, 61), toMinutes(dur));
    try std.testing.expectEqual(@as(u64, 1), toHours(dur));
    try std.testing.expectEqual(@as(u64, 0), toDays(dur));
}

test "Time: formatDuration short" {
    try std.testing.expectEqualStrings("0ms", formatDuration(0));
    try std.testing.expectEqualStrings("1s", formatDuration(1000));
    try std.testing.expectEqualStrings(">1s", formatDuration(2000));
    try std.testing.expectEqualStrings("1m", formatDuration(60000));
    try std.testing.expectEqualStrings("1h", formatDuration(3600000));
    try std.testing.expectEqualStrings("1d", formatDuration(86400000));
}

test "Time: formatDurationFull" {
    const allocator = std.testing.allocator;

    {
        const result = try formatDurationFull(allocator, 3661001);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("1h 1m 1s 1ms", result);
    }

    {
        const result = try formatDurationFull(allocator, 90061001); // 1d 1h 1m 1s 1ms
        defer allocator.free(result);
        try std.testing.expectEqualStrings("1d 1h 1m 1s 1ms", result);
    }

    {
        const result = try formatDurationFull(allocator, 0);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("0s", result);
    }
}

test "Time: toDays" {
    const one_day_ms = 86_400_000;
    try std.testing.expectEqual(@as(u64, 0), toDays(one_day_ms - 1));
    try std.testing.expectEqual(@as(u64, 1), toDays(one_day_ms));
    try std.testing.expectEqual(@as(u64, 2), toDays(one_day_ms * 2));
}
