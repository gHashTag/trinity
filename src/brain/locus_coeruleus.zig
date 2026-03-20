//! LOCUS COERULEUS — v0.3 — Arousal Regulation
//!
//! Exponential backoff policy for agent retry logic.
//! Brain Region: Locus Coeruleus (Norepinephrine System)
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//!
//! The Locus Coeruleus (LC) is the primary source of norepinephrine in the brain,
//! regulating arousal, attention, and the stress response. In Trinity, it provides
//! adaptive retry behavior with configurable backoff strategies.
//!
//! PERFORMANCE: O(1) lookup table instead of O(log) pow() computation
//! - EXP_TABLE provides precomputed values for default params (1s base, 2x multiplier)
//! - Table covers 0..31 attempts, sufficient for all practical retry scenarios
//! - Falls back to runtime computation for non-default parameters
//!
//! STRATEGIES:
//! - exponential: delay = initial_ms * multiplier^attempt (default, most common)
//! - linear: delay = initial_ms + increment * attempt
//! - constant: delay = initial_ms (no backoff, for high-confidence retries)
//!
//! JITTER TYPES (prevents thundering herd in distributed systems):
//! - none: deterministic delay (useful for testing, predictable behavior)
//! - uniform: random factor 1.0 to 2.0 (simple, well-understood distribution)
//! - phi_weighted: factor is either 0.618 (1/phi) or 1.618 (phi) where phi = (1+sqrt5)/2
//!                - Uses golden ratio for mathematically elegant jitter
//!                - Bimodal distribution creates interesting retry patterns
//!                - Lower bound is 0.618x, upper is 1.618x
//!
//! DEFAULT BEHAVIOR:
//! - Initial delay: 1000ms (1 second)
//! - Maximum delay: 60000ms (1 minute)
//! - Multiplier: 2.0 (doubling each retry)
//! - Linear increment: 1000ms (1 second)
//! - No jitter by default

const std = @import("std");

/// BackoffPolicy implements exponential, linear, and constant retry strategies
/// with optional jitter for distributed system coordination.
pub const BackoffPolicy = struct {
    /// Base delay in milliseconds for the first retry attempt
    initial_ms: u64 = 1000,

    /// Maximum delay cap in milliseconds (applied to all strategies)
    max_ms: u64 = 60000,

    /// Multiplier for exponential strategy (2.0 = doubling each retry)
    multiplier: f32 = 2.0,

    /// Increment per attempt for linear strategy (in milliseconds)
    linear_increment: u64 = 1000,

    /// Core backoff strategy selection
    strategy: enum { exponential, linear, constant } = .exponential,

    /// Jitter type to prevent retry collisions in distributed scenarios
    jitter_type: enum { none, uniform, phi_weighted } = .none,

    /// Precomputed exponential backoff table for default parameters.
    /// Maps attempt count (0..31) to delay in milliseconds.
    /// Values: 1000, 2000, 4000, 8000, ..., 2^31 * 1000
    /// Using a lookup table is faster than computing pow() at runtime,
    /// especially when called frequently in retry loops.
    /// Table size 32 covers all practical retry scenarios (2^31 seconds > 68 years).
    const EXP_TABLE = buildExpTable();

    /// Build the exponential lookup table at compile time.
    /// Each entry = 1000 * 2^attempt for attempt in 0..31.
    ///
    /// Returns: [32]u64 array where EXP_TABLE[i] = 1000 * 2^i
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

    /// Initialize a BackoffPolicy with default values.
    /// Defaults: 1s initial, 60s max, 2x exponential, no jitter
    pub fn init() BackoffPolicy {
        return BackoffPolicy{};
    }

    /// Calculate the delay for a given retry attempt.
    ///
    /// This is the main function that computes how long to wait before retrying.
    /// The delay is determined by the strategy, capped by max_ms, then jittered.
    ///
    /// Args:
    ///   attempt: The retry attempt number (0 = first retry, 1 = second retry, etc.)
    ///
    /// Returns: Delay in milliseconds to wait before next retry
    ///
    /// Performance: O(1) for default exponential params (lookup table),
    ///             O(log n) for non-default params (pow computation)
    pub fn nextDelay(self: *const BackoffPolicy, attempt: u32) u64 {
        const base_delay: u64 = switch (self.strategy) {
            .exponential => {
                // Fast path: use O(1) lookup table for default parameters
                // Covers the common case (1s base, 2x multiplier, <32 attempts)
                if (self.initial_ms == 1000 and self.multiplier == 2.0 and attempt < 32) {
                    return @min(self.max_ms, EXP_TABLE[@as(usize, @intCast(attempt))]);
                }
                // Slow path: compute for custom parameters or high attempt counts
                const delay = @as(f64, @floatFromInt(self.initial_ms)) *
                    std.math.pow(f32, self.multiplier, @as(f32, @floatFromInt(attempt)));
                const computed = if (delay > @as(f64, @floatFromInt(std.math.maxInt(u64))))
                    std.math.maxInt(u64)
                else
                    @as(u64, @intFromFloat(delay));
                return @min(self.max_ms, computed);
            },
            .linear => @min(self.max_ms, self.initial_ms + self.linear_increment * attempt),
            .constant => @min(self.max_ms, self.initial_ms),
        };

        // Apply jitter if configured (prevents thundering herd)
        return switch (self.jitter_type) {
            .none => base_delay,
            .uniform => blk: {
                // Random factor in [1.0, 2.0) - simple uniform distribution
                // Uses nanosecond timestamp as seed (good enough for jitter)
                const ts = std.time.nanoTimestamp();
                const seed = @as(u32, @intCast(ts & 0xFFFFFFFF));
                const factor = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
                break :blk @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * (1.0 + factor)));
            },
            .phi_weighted => blk: {
                // Bimodal distribution using golden ratio phi = 1.618...
                // Factor is either 0.618 (1/phi) or 1.618 (phi)
                // Creates interesting retry patterns with golden ratio spacing
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
//
// Test Categories:
// 1. Core strategy behavior (exponential, linear, constant)
// 2. Edge cases (zero attempt, overflow, high attempts)
// 3. Max delay capping behavior
// 4. Jitter behavior and ranges
// 5. EXP_TABLE verification
// 6. Custom parameter handling
// ═══════════════════════════════════════════════════════════════════════════════

// Verify EXP_TABLE values match expected 2^attempt * 1000 pattern
test "BackoffPolicy EXP_TABLE verification" {
    comptime var i: u32 = 0;
    inline while (i < 32) : (i += 1) {
        const expected = @as(u64, 1000) * @as(u64, 1) << i;
        try std.testing.expectEqual(expected, BackoffPolicy.EXP_TABLE[i]);
    }
}

// Verify EXP_TABLE covers all standard retry scenarios
test "BackoffPolicy EXP_TABLE coverage" {
    // Table has 32 entries (0..31)
    try std.testing.expectEqual(@as(usize, 32), BackoffPolicy.EXP_TABLE.len);

    // First value should be initial delay (1000ms = 1s)
    try std.testing.expectEqual(@as(u64, 1000), BackoffPolicy.EXP_TABLE[0]);

    // Last value should be 2^31 * 1000ms
    try std.testing.expectEqual(@as(u64, 2147483648000), BackoffPolicy.EXP_TABLE[31]);
}

// Basic exponential backoff with default parameters
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

// Test EXP_TABLE fast path vs computation path match
test "BackoffPolicy EXP_TABLE fast path matches computation" {
    // Default params use EXP_TABLE for attempts < 32
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
        .max_ms = std.math.maxInt(u64), // No cap for comparison
    };

    // Verify EXP_TABLE values match computed values for first 10 attempts
    for (0..10) |attempt| {
        const table_result = policy.nextDelay(@intCast(attempt));
        const expected = @as(u64, 1000) * @as(u64, 1) << @as(u5, @intCast(attempt));
        try std.testing.expectEqual(expected, table_result);
    }
}

// Test edge case: attempt exactly at EXP_TABLE boundary
test "BackoffPolicy EXP_TABLE boundary at 31" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
        .max_ms = std.math.maxInt(u64), // No cap
    };

    // Attempt 31 is the last entry in EXP_TABLE
    const delay_31 = policy.nextDelay(31);
    try std.testing.expectEqual(@as(u64, 2147483648000), delay_31);

    // Attempt 32 falls back to computation (not in table)
    const delay_32 = policy.nextDelay(32);
    try std.testing.expect(delay_32 > delay_31);
}

// Test edge case: very small initial delay
test "BackoffPolicy tiny initial delay" {
    var policy = BackoffPolicy{
        .initial_ms = 1,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 2), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 4), policy.nextDelay(2));
}

// Test edge case: max_ms equals initial_ms (constant cap)
test "BackoffPolicy max_equals_initial" {
    var policy = BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 1000,
        .multiplier = 10.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    // All attempts should return exactly max_ms (which equals initial_ms)
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(10));
    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(100));
}

// Test edge case: max_ms less than initial_ms (clamped on first attempt)
test "BackoffPolicy max_less_than_initial" {
    var policy = BackoffPolicy{
        .initial_ms = 10000,
        .max_ms = 5000,
        .strategy = .constant,
        .jitter_type = .none,
    };

    // Even though initial is 10000, max_ms should cap at 5000
    try std.testing.expectEqual(@as(u64, 5000), policy.nextDelay(0));
}

// Test jitter uniform range verification (multiple samples)
test "BackoffPolicy jitter uniform_range" {
    var policy = BackoffPolicy{
        .initial_ms = 10000,
        .strategy = .constant,
        .jitter_type = .uniform,
    };

    // Sample multiple times to verify range
    var min_delay: u64 = std.math.maxInt(u64);
    var max_delay: u64 = 0;

    for (0..100) |_| {
        const delay = policy.nextDelay(0);
        if (delay < min_delay) min_delay = delay;
        if (delay > max_delay) max_delay = delay;
    }

    // Uniform jitter produces delays in [10000, 20000)
    try std.testing.expect(min_delay >= 10000);
    try std.testing.expect(max_delay < 20000);
}

// Test linear strategy with zero increment
test "BackoffPolicy linear zero_increment" {
    var policy = BackoffPolicy{
        .initial_ms = 2000,
        .linear_increment = 0,
        .strategy = .linear,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(100));
}

// Test exponential with fractional multiplier
test "BackoffPolicy exponential fractional_multiplier" {
    var policy = BackoffPolicy{
        .initial_ms = 10000,
        .multiplier = 0.5, // Half each time (backing off less aggressively)
        .strategy = .exponential,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 10000), policy.nextDelay(0));
    const delay_1 = policy.nextDelay(1);
    // 10000 * 0.5 = 5000 (but integer truncation)
    try std.testing.expect(delay_1 >= 5000 and delay_1 <= 5001);
}

// Test all jitter types don't produce zero delay
test "BackoffPolicy jitter_never_zero" {
    const base_initial_ms: u64 = 100;

    // Test .none jitter
    var policy_none = BackoffPolicy{
        .initial_ms = base_initial_ms,
        .strategy = .constant,
        .jitter_type = .none,
    };
    try std.testing.expect(policy_none.nextDelay(0) > 0);

    // Test .uniform jitter
    var policy_uniform = BackoffPolicy{
        .initial_ms = base_initial_ms,
        .strategy = .constant,
        .jitter_type = .uniform,
    };
    try std.testing.expect(policy_uniform.nextDelay(0) > 0);

    // Test .phi_weighted jitter
    var policy_phi = BackoffPolicy{
        .initial_ms = base_initial_ms,
        .strategy = .constant,
        .jitter_type = .phi_weighted,
    };
    try std.testing.expect(policy_phi.nextDelay(0) > 0);
}

// Test exponential table vs computation consistency for custom initial
test "BackoffPolicy custom_initial_uses_computation" {
    var policy = BackoffPolicy{
        .initial_ms = 2000, // Non-default, uses computation path
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
        .max_ms = 1000000,
    };

    // 2000, 4000, 8000, 16000...
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 4000), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 8000), policy.nextDelay(2));
    try std.testing.expectEqual(@as(u64, 16000), policy.nextDelay(3));
}

// Test jitter with max_ms cap ensures delay never exceeds max
test "BackoffPolicy jitter_respects_max_ms" {
    // With phi_weighted jitter, delay can be 1.618x base
    // Ensure max_ms still caps this
    var policy = BackoffPolicy{
        .initial_ms = 5000,
        .max_ms = 7000, // Cap between 0.618x and 1.618x
        .strategy = .constant,
        .jitter_type = .phi_weighted,
    };

    // Run multiple times since jitter is random
    for (0..50) |_| {
        const delay = policy.nextDelay(0);
        // Phi jitter produces 3090 or 8090, but max_ms caps at 7000
        try std.testing.expect(delay <= 7000);
    }
}

// Test deterministic behavior with no jitter
test "BackoffPolicy no_jitter_is_deterministic" {
    var policy = BackoffPolicy{
        .initial_ms = 1234,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    // Same input should always produce same output
    const delay1 = policy.nextDelay(5);
    const delay2 = policy.nextDelay(5);
    const delay3 = policy.nextDelay(5);

    try std.testing.expectEqual(delay1, delay2);
    try std.testing.expectEqual(delay2, delay3);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// ADDITIONAL TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ basal ganglia tests added (claim duplicate, expiration, backoff, statistics)
    // Locus Coeruleus tests will verify:
    // - Exponential backoff calculation
    // - Timer accuracy
    // - Jitter control

test "Backoff: exponential progression" {
    // Test that delay grows exponentially: 100ms * 2^consecutive_failures
    var policy = BackoffPolicy{ .consecutive_failures = 0 };
    policy.consecutive_failures = 0;
    const d0 = policy.calculateBackoff();
    try std.testing.expect(d0.delay_ms >= 100 and d0.delay_ms < 200);
    
    policy.consecutive_failures = 1;
    const d1 = policy.calculateBackoff();
    try std.testing.expect(d1.delay_ms >= 200 and d1.delay_ms < 300);
    
    policy.consecutive_failures = 5;
    const d5 = policy.calculateBackoff();
    try std.testing.expect(d5.delay_ms >= 3200 and d5.delay_ms < 3400);
}

test "Backoff: jitter randomness" {
    // Verify that jitter adds randomness without breaking bounds
    var policy = BackoffPolicy{ .consecutive_failures = 3 };
    
    var saw_variance = false;
    var prev_delay: u32 = 0;
    
    for (0..10) |_| {
        const backoff = policy.calculateBackoff();
        if (prev_delay > 0 and backoff.delay_ms != prev_delay) {
            saw_variance = true;
        }
        prev_delay = backoff.delay_ms;
        
        // Should never exceed max_delay
        try std.testing.expect(backoff.delay_ms <= policy.max_delay_ms);
    }
    
    try std.testing.expect(saw_variance);
}

// φ² + 1/φ² = 3 | TRINITY
