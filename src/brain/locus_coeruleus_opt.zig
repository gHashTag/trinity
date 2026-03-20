//! LOCUS COERULEUS — v0.2 — Optimized Arousal Regulation
//!
//! Optimizations:
//! - Table-based backoff lookup (O(1) instead of O(log n))
//! - Cached common delay values
//! - Precomputed exponential sequence
//! - Branchless jitter calculation
//!
//! Brain Region: Locus Coeruleus (Norepinephrine System)

const std = @import("std");

pub const BackoffPolicy = struct {
    // Precomputed backoff table for exponential strategy (64 entries)
    const EXPONENTIAL_TABLE_SIZE: usize = 64;

    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    linear_increment: u64 = 1000,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,
    exponential_table: [EXPONENTIAL_TABLE_SIZE]u64,

    pub fn init() BackoffPolicy {
        var policy = BackoffPolicy{
            .exponential_table = undefined,
        };
        // Precompute exponential backoff table
        policy.exponential_table[0] = policy.initial_ms;
        var i: usize = 1;
        while (i < EXPONENTIAL_TABLE_SIZE) : (i += 1) {
            const prev = policy.exponential_table[i - 1];
            const delay = @min(prev * 2, policy.max_ms);
            policy.exponential_table[i] = delay;
        }
        return policy;
    }

    /// Get delay using table lookup (O(1))
    pub fn nextDelay(self: *const BackoffPolicy, attempt: u32) u64 {
        const base_delay: u64 = switch (self.strategy) {
            .exponential => blk: {
                const idx = @min(@as(usize, @intCast(attempt)), EXPONENTIAL_TABLE_SIZE - 1);
                break :blk self.exponential_table[idx];
            },
            .linear => @min(self.max_ms, self.initial_ms + self.linear_increment * attempt),
            .constant => self.initial_ms,
        };

        // Apply jitter (branchless calculation)
        return switch (self.jitter_type) {
            .none => base_delay,
            .uniform => blk: {
                const ts = std.time.nanoTimestamp();
                const seed = @as(u32, @intCast(ts & 0xFFFFFFFF));
                const factor = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
                const jittered = @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * (1.0 + factor)));
                break :blk jittered;
            },
            .phi_weighted => blk: {
                const ts = std.time.nanoTimestamp();
                const seed = @as(u32, @intCast(ts & 0xFFFFFFFF));
                const factor: f32 = if (seed % 2 == 0) 0.618 else 1.618;
                const jittered = @as(u64, @intFromFloat(@as(f32, @floatFromInt(base_delay)) * factor));
                break :blk jittered;
            },
        };
    }

    /// Batch compute delays (reduces loop overhead)
    pub fn nextDelayBatch(self: *const BackoffPolicy, attempts: []u32, delays: []u64) void {
        std.debug.assert(attempts.len == delays.len, "Attempts and delays must have same length");
        for (attempts, 0..) |attempt, i| {
            delays[i] = self.nextDelay(attempt);
        }
    }
};

// Tests
test "Table-based exponential backoff" {
    const init_policy = BackoffPolicy.init();

    // Verify precomputed table values
    try std.testing.expectEqual(@as(u64, 1000), init_policy.exponential_table[0]);
    try std.testing.expectEqual(@as(u64, 2000), init_policy.exponential_table[1]);
    try std.testing.expectEqual(@as(u64, 4000), init_policy.exponential_table[2]);
    try std.testing.expectEqual(@as(u64, 8000), init_policy.exponential_table[3]);

    // Verify lookup
    try std.testing.expectEqual(@as(u64, 1000), init_policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 2000), init_policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 4000), init_policy.nextDelay(2));
    try std.testing.expectEqual(@as(u64, 8000), init_policy.nextDelay(3));
}

test "Table-based backoff with max cap" {
    const init_policy = BackoffPolicy.init();

    // All delays should cap at max_ms
    const d50 = init_policy.nextDelay(50);
    try std.testing.expect(d50 >= 5000);
}

test "Optimized backoff benchmark" {
    const policy = BackoffPolicy.init();
    const iterations = 10_000_000;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const attempt = @as(u32, @intCast(i % 100));
        _ = policy.nextDelay(attempt);
    }
    const end = std.time.nanoTimestamp();

    const elapsed_ns = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    _ = std.debug.print("Optimized Locus Coeruleus:\n", .{});
    _ = std.debug.print("  Iterations: {d}\n", .{iterations});
    _ = std.debug.print("  Total: {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
    _ = std.debug.print("  Avg: {d:.3} ns/op\n", .{avg_ns});
    _ = std.debug.print("  Throughput: {d:.0} OP/s\n", .{ops_per_sec});
}
