// ═══════════════════════════════════════════════════════════════════════════════
// DePIN NETWORK BENCHMARKS (Standalone)
// Run: zig run bench-depin.zig
// Order #100-1 — REAL DEPIN NETWORK TRANSCENDENCE
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Tier multipliers (from Firebird)
const TIER_MULTIPLIER_FREE: f64 = 1.0;
const TIER_MULTIPLIER_STAKER: f64 = 1.5;
const TIER_MULTIPLIER_POWER: f64 = 2.0;
const TIER_MULTIPLIER_WHALE: f64 = 3.0;

const NodeTier = enum(u8) {
    free = 0,
    staker = 1,
    power = 2,
    whale = 3,

    pub fn getMultiplier(self: NodeTier) f64 {
        return switch (self) {
            .free => TIER_MULTIPLIER_FREE,
            .staker => TIER_MULTIPLIER_STAKER,
            .power => TIER_MULTIPLIER_POWER,
            .whale => TIER_MULTIPLIER_WHALE,
        };
    }
};

pub fn main() !void {
    std.debug.print(
        \\═══════════════════════════════════════════════════════════════
        \\  DePIN NETWORK BENCHMARKS
        \\  Order #100-1 — REAL DEPIN NETWORK TRANSCENDENCE
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});

    // Benchmark 1: Tier Multiplier
    try benchmarkTierMultiplier();

    // Benchmark 2: Reward Calculation
    try benchmarkRewardCalculation();

    // Benchmark 3: Node Discovery (simulated)
    try benchmarkNodeDiscovery();

    // Benchmark 4: Job Packet JSON
    try benchmarkJobPacketJson();

    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\  SUMMARY
        \\═══════════════════════════════════════════════════════════════
        \\
        \\  UDP Port:  9333 (Discovery)
        \\  TCP Port:  9334 (Jobs)
        \\  HTTP Port: 8080 (API)
        \\
        \\  Target Metrics:
        \\  - UDP Latency:    < 10ms
        \\  - TCP Job Dist:   < 50ms
        \\  - Reward Calc:    > 100M ops/s
        \\  - Cluster Save:   > 100 ops/s
        \\
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});
}

fn benchmarkTierMultiplier() !void {
    const iterations = 100_000_000;

    const start = std.time.nanoTimestamp();
    var total: f64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const tier: NodeTier = @enumFromInt(@as(u8, @intCast(i % 4)));
        total += tier.getMultiplier();
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    std.debug.print(
        \\[1/4] Tier Multiplier Lookup
        \\  Iterations:     {d}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} ops/s
        \\  Avg Multiplier: {d:.3}x
        \\
    , .{ iterations, elapsed_ms, throughput, total / @as(f64, @floatFromInt(iterations)) });

    if (throughput > 50_000_000) {
        std.debug.print("  Status:         ✓ FAST\n\n", .{});
    } else {
        std.debug.print("  Status:         ✗ SLOW\n\n", .{});
    }
}

fn benchmarkRewardCalculation() !void {
    const iterations = 10_000_000;

    const start = std.time.nanoTimestamp();
    var total: f64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const tier: NodeTier = @enumFromInt(@as(u8, @intCast(i % 4)));
        const base_reward: f64 = 0.001;
        total += base_reward * tier.getMultiplier();
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    std.debug.print(
        \\[2/4] Reward Calculation
        \\  Iterations:     {d}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} ops/s
        \\  Avg Reward:     {d:.6} TRI
        \\
    , .{ iterations, elapsed_ms, throughput, total / @as(f64, @floatFromInt(iterations)) });

    if (throughput > 100_000_000) {
        std.debug.print("  Status:         ✓ EXCELLENT\n\n", .{});
    } else {
        std.debug.print("  Status:         ✗ NEEDS OPTIMIZATION\n\n", .{});
    }
}

fn benchmarkNodeDiscovery() !void {
    const iterations = 1_000_000;

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        // Simulate node discovery packet creation
        const node_id = i;
        const tier: NodeTier = @enumFromInt(@as(u8, @intCast(i % 4)));
        const multiplier = tier.getMultiplier();
        _ = node_id;
        _ = multiplier;
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    std.debug.print(
        \\[3/4] Node Discovery (Simulated)
        \\  Iterations:     {d}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} nodes/s
        \\
    , .{ iterations, elapsed_ms, throughput });

    if (throughput > 10_000_000) {
        std.debug.print("  Status:         ✓ FAST\n\n", .{});
    } else {
        std.debug.print("  Status:         ✗ SLOW\n\n", .{});
    }
}

fn benchmarkJobPacketJson() !void {
    const iterations = 100_000;
    const allocator = std.heap.page_allocator;

    var i: usize = 0;
    const start = std.time.nanoTimestamp();
    var total_size: usize = 0;
    while (i < iterations) : (i += 1) {
        const json = try std.fmt.allocPrint(allocator,
            \\{{"job_id":"job-{d}","payload":"compute","reward":{d:.6}}}
        , .{ i, 0.001 });
        defer allocator.free(json);
        total_size += json.len;
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);
    const avg_size = @as(f64, @floatFromInt(total_size)) / @as(f64, @floatFromInt(iterations));

    std.debug.print(
        \\[4/4] Job Packet JSON Serialization
        \\  Iterations:     {d}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} packets/s
        \\  Avg Size:       {d:.0} bytes
        \\
    , .{ iterations, elapsed_ms, throughput, avg_size });

    if (throughput > 100_000) {
        std.debug.print("  Status:         ✓ FAST\n\n", .{});
    } else {
        std.debug.print("  Status:         ✗ SLOW\n\n", .{});
    }
}
