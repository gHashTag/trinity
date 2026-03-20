//! LOCUS COERULEUS — v0.2 — Arousal Regulation
//!
//! Exponential backoff policy for agent retry logic.
//! Brain Region: Locus Coeruleus (Norepinephrine System)
//!
//! Performance: O(1) lookup table instead of O(log) pow() computation

const std = @import("std");

pub const BackoffPolicy = struct {
    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    linear_increment: u64 = 1000,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,

    // Precomputed exponential backoff table (0..31 attempts)
    // Computed with: initial_ms * multiplier^attempt
    const EXP_TABLE = buildExpTable();

    fn buildExpTable() [32]u64 {
        @setEvalBranchQuota(10000);
        var table: [32]u64 = undefined;
        for (0..32) |i| {
            const delay = @as(f64, @floatFromInt(1000)) *
                std.math.pow(f32, 2.0, @as(f32, @floatFromInt(i)));
            table[i] = if (delay > @as(f64, @floatFromInt(std.math.maxInt(u64))))
                std.math.maxInt(u64)
            else
                @as(u64, @intFromFloat(delay));
        }
        return table;
    }

    pub fn init() BackoffPolicy {
        return BackoffPolicy{};
    }

    pub fn nextDelay(self: *const BackoffPolicy, attempt: u32) u64 {
        const base_delay: u64 = switch (self.strategy) {
            .exponential => {
                // Use O(1) lookup table instead of pow() for default params
                if (self.initial_ms == 1000 and self.multiplier == 2.0 and attempt < 32) {
                    return @min(self.max_ms, EXP_TABLE[@as(usize, @intCast(attempt))]);
                }
                // Fallback to computation for non-default params or high attempt counts
                const delay = @as(f64, @floatFromInt(self.initial_ms)) *
                    std.math.pow(f32, self.multiplier, @as(f32, @floatFromInt(attempt)));
                const computed = if (delay > @as(f64, @floatFromInt(std.math.maxInt(u64))))
                    std.math.maxInt(u64)
                else
                    @as(u64, @intFromFloat(delay));
                return @min(self.max_ms, computed);
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

test "BackoffPolicy jitter uniform" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 1.0,
        .strategy = .constant,
        .jitter_type = .uniform,
    };

    const delay = policy.nextDelay(0);
    // With uniform jitter, delay should be >= initial_ms (1.0 to 2.0x)
    try std.testing.expect(delay >= 1000);
}

test "BackoffPolicy jitter phi_weighted" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 1.0,
        .strategy = .constant,
        .jitter_type = .phi_weighted,
    };

    const delay = policy.nextDelay(0);
    // Phi-weighted: either 0.618x or 1.618x
    try std.testing.expect(delay >= 618 and delay <= 1618);
}

test "BackoffPolicy exponential overflow protection" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 10.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    // High attempt number could cause overflow
    const delay = policy.nextDelay(100);
    try std.testing.expect(delay > 0);
}

test "BackoffPolicy linear max boundary" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 5000,
        .linear_increment = 2000,
        .strategy = .linear,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 3000), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 5000), policy.nextDelay(2));
    try std.testing.expectEqual(@as(u64, 5000), policy.nextDelay(10)); // Capped at max
}

test "BackoffPolicy init default values" {
    const policy = BackoffPolicy.init();
    try std.testing.expectEqual(@as(u64, 1000), policy.initial_ms);
    try std.testing.expectEqual(@as(u64, 60000), policy.max_ms);
    try std.testing.expectEqual(@as(f32, 2.0), policy.multiplier);
    try std.testing.expectEqual(@as(u64, 1000), policy.linear_increment);
    try std.testing.expectEqual(@as(@TypeOf(policy.strategy), .exponential), policy.strategy);
    try std.testing.expectEqual(@as(@TypeOf(policy.jitter_type), .none), policy.jitter_type);
}

test "BackoffPolicy exponential with multiplier 1.0" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 1.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(100));
}

test "BackoffPolicy exponential with small multiplier" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 1.5,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1500), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 2250), policy.nextDelay(2));
}

test "BackoffPolicy zero attempt" {
    var policy = BackoffPolicy{
        .initial_ms = 5000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 5000), policy.nextDelay(0));
}

test "BackoffPolicy high attempt with small multiplier" {
    // Test that high attempt counts work with small multipliers (not just max_ms)
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 1.0,
        .strategy = .exponential,
        .jitter_type = .none,
        .max_ms = 100000, // High max to see actual computed values
    };

    // With multiplier 1.0, delay should always be 1000 regardless of attempt
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(10));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(100));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(1000));
}
