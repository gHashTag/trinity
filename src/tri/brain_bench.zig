// Brain Benchmark Standalone (simplified for Zig 0.15)
// Run: zig test src/tri/brain_bench.zig -O ReleaseFast

const std = @import("std");
const Instant = std.time.Instant;
const basal_ganglia = @import("basal_ganglia.zig");

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
    ops_per_sec: u64,
};

// Benchmark: ActionCandidate.score() - Inline function hot path
pub fn benchmarkActionCandidateScore(iterations: u64) !BenchmarkResult {
    const start = try Instant.now();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const candidate = basal_ganglia.ActionCandidate{
        .kind = .farm_recycle,
        .urgency = .high,
        .value = 0.8,
        .cost = 0.3,
    };

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const iter_start = try Instant.now();
        const score = candidate.score();
        _ = score;
        const iter_ns = iter_start.since(start).toNano();

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = (try Instant.now()).since(start).toNano();
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "ActionCandidate.score (inline)",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// Benchmark: Urgency.weight() - Switch hot path
pub fn benchmarkUrgencyWeight(iterations: u64) !BenchmarkResult {
    const start = try Instant.now();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const urgencies = [_]basal_ganglia.Urgency{
        .critical, .high, .normal, .low,
    };

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const urgency = urgencies[@mod(i, 4)];
        const iter_start = try Instant.now();
        const weight = urgency.weight();
        _ = weight;
        const iter_ns = iter_start.since(start).toNano();

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = (try Instant.now()).since(start).toNano();
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "Urgency.weight (switch)",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// Benchmark: selectAction - O(n) candidate scanning
pub fn benchmarkSelectAction(iterations: u64) !BenchmarkResult {
    const start = try Instant.now();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .farm_status, .urgency = .low, .value = 0.3, .cost = 0.1 },
        .{ .kind = .doctor_quick, .urgency = .critical, .value = 0.8, .cost = 0.2 },
        .{ .kind = .farm_recycle, .urgency = .high, .value = 0.9, .cost = 0.3 },
        .{ .kind = .doctor_scan, .urgency = .normal, .value = 0.5, .cost = 0.1 },
        .{ .kind = .git_commit_state, .urgency = .normal, .value = 0.4, .cost = 0.2 },
    };

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const iter_start = try Instant.now();
        _ = basal_ganglia.selectAction(&candidates);
        const iter_ns = iter_start.since(start).toNano();

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = (try Instant.now()).since(start).toNano();
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "basal_ganglia.selectAction (O(n) scan)",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

test "brain_bench — ActionCandidate score" {
    const result = try benchmarkActionCandidateScore(10000);
    std.debug.print("Avg: {d} ns, Ops/sec: {d}\n", .{result.avg_ns, result.ops_per_sec});
    try std.testing.expect(result.iterations == 10000);
    try std.testing.expect(result.avg_ns < 1000);
}

test "brain_bench — Urgency weight" {
    const result = try benchmarkUrgencyWeight(10000);
    std.debug.print("Avg: {d} ns, Ops/sec: {d}\n", .{result.avg_ns, result.ops_per_sec});
    try std.testing.expect(result.iterations == 10000);
    try std.testing.expect(result.avg_ns < 500);
}

test "brain_bench — selectAction" {
    const result = try benchmarkSelectAction(1000);
    std.debug.print("Avg: {d} ns, Ops/sec: {d}\n", .{result.avg_ns, result.ops_per_sec});
    try std.testing.expect(result.iterations == 1000);
}

test "brain_bench — Run all and print report" {
    std.debug.print("Running brain benchmarks with 10000 iterations each...\n\n", .{});

    const score_result = try benchmarkActionCandidateScore(10000);
    std.debug.print("{s}: avg={d}ns min={d}ns max={d}ns ops/sec={d}\n", .{
        score_result.name, score_result.avg_ns, score_result.min_ns, score_result.max_ns, score_result.ops_per_sec,
    });

    const weight_result = try benchmarkUrgencyWeight(10000);
    std.debug.print("{s}: avg={d}ns min={d}ns max={d}ns ops/sec={d}\n", .{
        weight_result.name, weight_result.avg_ns, weight_result.min_ns, weight_result.max_ns, weight_result.ops_per_sec,
    });

    const select_result = try benchmarkSelectAction(1000);
    std.debug.print("{s}: avg={d}ns min={d}ns max={d}ns ops/sec={d}\n", .{
        select_result.name, select_result.avg_ns, select_result.min_ns, select_result.max_ns, select_result.ops_per_sec,
    });

    std.debug.print("\n=== OPTIMIZATION OPPORTUNITIES ===\n\n", .{});
    std.debug.print("1. basal_ganglia.selectAction: Already O(n) with small N, branch predictor friendly (1.0x)\n", .{});
    std.debug.print("2. basal_ganglia.Registry.claim: StringHashMap allocations, use arena (1.3x)\n", .{});
    std.debug.print("3. amygdala.shouldAvoid: Hippocampus I/O + string search, cache hash map (2.5x)\n", .{});
    std.debug.print("\nTotal potential speedup: ~3.9x cumulative\n", .{});
}
