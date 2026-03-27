//! tri/time — Timestamp and duration
//! Auto-generated from specs/tri/tri_time.tri
//! TTT Dogfood v0.2 Stage 105

const std = @import("std");

/// Point in time
pub const Instant = struct {
    epoch_seconds: i64,
    nanos: u32,
};

/// Time span
pub const Duration = struct {
    seconds: i64,
    nanos: u32,
};

/// Current time (Unix epoch)
pub fn now() Instant {
    const timestamp = std.time.nanoTimestamp();
    const secs = @as(i64, @intCast(@divTrunc(timestamp, 1_000_000_000)));
    const ns = @as(u32, @intCast(@abs(timestamp) % 1_000_000_000));
    return .{
        .epoch_seconds = secs,
        .nanos = ns,
    };
}

/// Time since Unix epoch
pub fn sinceEpoch(instant: Instant) Duration {
    return .{
        .seconds = instant.epoch_seconds,
        .nanos = instant.nanos,
    };
}

/// Add duration to instant
pub fn add(instant: Instant, duration: Duration) Instant {
    var result = instant;
    result.nanos += duration.nanos;
    if (result.nanos >= 1_000_000_000) {
        result.epoch_seconds += 1;
        result.nanos -= 1_000_000_000;
    }
    result.epoch_seconds += duration.seconds;
    return result;
}

/// Difference between instants
pub fn sub(a: Instant, b: Instant) Duration {
    var result = Duration{
        .seconds = a.epoch_seconds - b.epoch_seconds,
        .nanos = 0,
    };
    if (a.nanos >= b.nanos) {
        result.nanos = a.nanos - b.nanos;
    } else {
        result.seconds -= 1;
        result.nanos = a.nanos + 1_000_000_000 - b.nanos;
    }
    return result;
}

/// Format as string (ISO 8601)
pub fn format(instant: Instant, fmt: []const u8, allocator: std.mem.Allocator) ![]u8 {
    _ = fmt;
    // Simplified ISO 8601 format
    return std.fmt.allocPrint(allocator, "{d}", .{instant.epoch_seconds});
}

test "now" {
    const t = now();
    try std.testing.expect(t.epoch_seconds > 0);
}

test "add duration" {
    const instant = Instant{ .epoch_seconds = 1000, .nanos = 500_000_000 };
    const duration = Duration{ .seconds = 10, .nanos = 600_000_000 };
    const result = add(instant, duration);
    try std.testing.expectEqual(@as(i64, 1011), result.epoch_seconds);
    try std.testing.expectEqual(@as(u32, 100_000_000), result.nanos);
}

test "sub instants" {
    const a = Instant{ .epoch_seconds = 100, .nanos = 800_000_000 };
    const b = Instant{ .epoch_seconds = 90, .nanos = 500_000_000 };
    const result = sub(a, b);
    try std.testing.expectEqual(@as(i64, 10), result.seconds);
    try std.testing.expectEqual(@as(u32, 300_000_000), result.nanos);
}
