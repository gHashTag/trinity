// ═══════════════════════════════════════════════════════════════════════════════
// DePIN NETWORK BENCHMARKS
// Order #100-1 — REAL DEPIN NETWORK TRANSCENDENCE
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const network = @import("network.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\═══════════════════════════════════════════════════════════════
        \\  DePIN NETWORK BENCHMARKS
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});

    // Benchmark 1: Reward Calculation
    try benchmarkRewardCalculation(stdout);

    // Benchmark 2: Tier Multiplier
    try benchmarkTierMultiplier(stdout);

    // Benchmark 3: Node Creation
    try benchmarkNodeCreation(stdout);

    // Benchmark 4: JSON Serialization
    try benchmarkJsonSerialization(stdout);

    try stdout.print(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\  BENCHMARKS COMPLETE
        \\═══════════════════════════════════════════════════════════════
        \\
    , .{});
}

fn benchmarkRewardCalculation(stdout: anytype) !void {
    const iterations = 10_000_000;

    var node = network.ClusterNode{
        .id = "bench-node",
        .address = .{ .ip = "127.0.0.1", .port = 9334 },
        .role = .worker,
        .tier = .staker,
        .status = .online,
        .operations_count = 0,
        .earned_tri = 0.0,
        .pending_tri = 0.0,
        .last_heartbeat = 0,
    };

    const start = std.time.nanoTimestamp();
    var total: f64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        total += node.calculateReward(0.001);
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    try stdout.print(
        \\[1/4] Reward Calculation
        \\  Iterations:     {d:,}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} ops/s
        \\  Avg Reward:     {d:.6} TRI
        \\
    , .{ iterations, elapsed_ms, throughput, total / @as(f64, @floatFromInt(iterations)) });
}

fn benchmarkTierMultiplier(stdout: anytype) !void {
    const iterations = 100_000_000;

    const start = std.time.nanoTimestamp();
    var total: f64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const tier: network.NodeTier = @enumFromInt(@as(u8, @intCast(i % 4)));
        total += tier.getMultiplier();
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    try stdout.print(
        \\[2/4] Tier Multiplier
        \\  Iterations:     {d:,}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} ops/s
        \\  Avg Multiplier: {d:.3}x
        \\
    , .{ iterations, elapsed_ms, throughput, total / @as(f64, @floatFromInt(iterations)) });
}

fn benchmarkNodeCreation(stdout: anytype) !void {
    const iterations = 1_000_000;
    _ = std.heap.page_allocator; // Available for future allocations

    const start = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var node = network.ClusterNode{
            .id = "test-node",
            .address = .{ .ip = "127.0.0.1", .port = 9334 },
            .role = .worker,
            .tier = .free,
            .status = .online,
            .operations_count = 0,
            .earned_tri = 0.0,
            .pending_tri = 0.0,
            .last_heartbeat = 0,
        };
        _ = node.calculateReward(0.001);
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);

    try stdout.print(
        \\[3/4] Node Creation + Reward
        \\  Iterations:     {d:,}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} nodes/s
        \\
    , .{ iterations, elapsed_ms, throughput });
}

fn benchmarkJsonSerialization(stdout: anytype) !void {
    const iterations = 100_000;
    const allocator = std.heap.page_allocator;

    var job = network.JobPacket{
        .job_id = "job-test-123",
        .payload = "compute-sha256-hash",
        .reward = 0.001,
        .timestamp = std.time.milliTimestamp(),
    };

    const start = std.time.nanoTimestamp();
    var total_size: usize = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const json = try job.toJson(allocator);
        defer allocator.free(json);
        total_size += json.len;
    }
    const elapsed_ns = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(iterations)) / (elapsed_ms / 1000.0);
    const avg_size = @as(f64, @floatFromInt(total_size)) / @as(f64, @floatFromInt(iterations));

    try stdout.print(
        \\[4/4] JSON Serialization
        \\  Iterations:     {d:,}
        \\  Time:           {d:.2} ms
        \\  Throughput:     {d:.0} serializations/s
        \\  Avg Size:       {d:.0} bytes
        \\
    , .{ iterations, elapsed_ms, throughput, avg_size });
}
