//! LOCUS COERULEUS — v0.1 — Arousal Regulation
//!
//! Exponential backoff policy for agent retry logic.
//! Brain Region: Locus Coeruleus (Norepinephrine System)

const std = @import("std");

pub const BackoffPolicy = struct {
    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    linear_increment: u64 = 1000,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,

    pub fn init() BackoffPolicy {
        return BackoffPolicy{};
    }

    pub fn nextDelay(self: *const BackoffPolicy, attempt: u32) u64 {
        const base_delay: u64 = switch (self.strategy) {
            .exponential => {
                const delay = @as(f64, @floatFromInt(self.initial_ms)) *
                    std.math.pow(f32, self.multiplier, @as(f32, @floatFromInt(attempt)));
                if (delay > @as(f64, @floatFromInt(std.math.maxInt(u64))))
                    return std.math.maxInt(u64);
                return @as(u64, @intFromFloat(delay));
            },
            .linear => @min(self.max_ms, self.initial_ms + self.linear_increment * attempt),
            .constant => self.initial_ms,
        };

        // Apply jitter
        return switch (self.jitter_type) {
            .none => base_delay,
            .uniform => blk: {
                const ts = std.time.nanoTimestamp();
                const seed = @as(u32, @intCast(ts & 0xFFFFFFFF));
                const factor = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
                break :blk @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * (1.0 + factor)));
            },
            .phi_weighted => blk: {
                const ts = std.time.nanoTimestamp();
                const seed = @as(u32, @intCast(ts & 0xFFFFFFFF));
                const factor: f32 = if (seed % 2 == 0) 0.618 else 1.618;
                break :blk @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * factor));
            },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BackoffPolicy exponential strategy" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 4000), policy.nextDelay(2));
    try std.testing.expectEqual(@as(u64, 8000), policy.nextDelay(3));
}

test "BackoffPolicy linear strategy" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .linear_increment = 500,
        .strategy = .linear,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1500), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(2));
}

test "BackoffPolicy max caps delay" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 5000,
        .multiplier = 10.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    // Should cap at max_ms (5000)
    const delay = policy.nextDelay(10);
    try std.testing.expect(delay >= 5000);
}

test "BackoffPolicy constant strategy" {
    var policy = BackoffPolicy{
        .initial_ms = 2000,
        .strategy = .constant,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(5));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(100));
}
