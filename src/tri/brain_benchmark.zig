// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN BENCHMARK — Profile and optimize hot paths in brain regions
// ═══════════════════════════════════════════════════════════════════════════════
// Profiles key operations:
//   - basal_ganglia.zig: task operations (selectAction, claim, heartbeat)
//   - reticular_aras.zig: event operations (sweepOnce)
//   - amygdala.zig: salience analysis (shouldAvoid, getEmotionalSummary)
//   - queen_dlpfc.zig: decision logic (decide, readSenses)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timer = std.time.Timer;
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_aras = @import("reticular_aras.zig");
const amygdala = @import("amygdala.zig");
const qt = @import("queen_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RESULT — Single benchmark measurement
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
    ops_per_sec: u64,

    pub fn format(self: BenchmarkResult, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            \\ {s}: {d} iterations
            \\   Total: {d:>12} ns  Avg: {d:>10} ns  Min: {d:>10} ns  Max: {d:>10} ns
            \\   Throughput: {d:>12} ops/sec
        , .{
            self.name,
            self.iterations,
            self.total_ns,
            self.avg_ns,
            self.min_ns,
            self.max_ns,
            self.ops_per_sec,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK SUITE — Collection of benchmarks
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkSuite = struct {
    results: std.ArrayList(BenchmarkResult),
    allocator: Allocator,

    pub fn init(allocator: Allocator) !BenchmarkSuite {
        const results = try std.ArrayList(BenchmarkResult).initCapacity(allocator, 16);
        return .{
            .results = results,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit(self.allocator);
    }

    pub fn addResult(self: *BenchmarkSuite, result: BenchmarkResult) !void {
        try self.results.append(self.allocator, result);
    }

    pub fn printReport(self: *const BenchmarkSuite) !void {
        std.debug.print(
            \\╔════════════════════════════════════════════════════════════════════════════╗
            \\║                        BRAIN BENCHMARK REPORT                                ║
            \\╚════════════════════════════════════════════════════════════════════════════╝
            \\
        );

        for (self.results.items) |result| {
            std.debug.print("{}\n\n", .{result});
        }

        try self.printComparison();
    }

    pub fn printComparison(self: *const BenchmarkSuite) !void {
        std.debug.print(
            \\╔════════════════════════════════════════════════════════════════════════════╗
            \\║                       SPEEDUP ANALYSIS (OPTIMIZED)                          ║
            \\╚════════════════════════════════════════════════════════════════════════════╝
            \\
        );

        // Find baseline (first result) and compare
        if (self.results.items.len < 2) return;

        std.debug.print("All benchmarks show baseline performance (no optimizations applied yet).\n", .{});
        std.debug.print("Run benchmark suite after optimizations to see speedup.\n\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Basal Ganglia — selectAction
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkSelectAction(iterations: u64) !BenchmarkResult {
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    // Create candidate list (typical Queen decision scenario)
    const candidates = [_]basal_ganglia.ActionCandidate{
        .{ .kind = .farm_status, .urgency = .low, .value = 0.3, .cost = 0.1 },
        .{ .kind = .doctor_quick, .urgency = .critical, .value = 0.8, .cost = 0.2 },
        .{ .kind = .farm_recycle, .urgency = .high, .value = 0.9, .cost = 0.3 },
        .{ .kind = .doctor_scan, .urgency = .normal, .value = 0.5, .cost = 0.1 },
        .{ .kind = .git_commit_state, .urgency = .normal, .value = 0.4, .cost = 0.2 },
    };

    const start = timer.read();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const iter_start = timer.read();
        _ = basal_ganglia.selectAction(&candidates);
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "basal_ganglia.selectAction",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

pub fn benchmarkSelectActionAlloc(allocator: Allocator, iterations: u64) !BenchmarkResult {
    _ = allocator;
    return benchmarkSelectAction(iterations);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Basal Ganglia — Task Claim Registry
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkTaskClaim(allocator: Allocator, iterations: u64) !BenchmarkResult {
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    const start = timer.read();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);

        const iter_start = timer.read();
        _ = try registry.claim(allocator, task_id, "agent-1", 60000);
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "basal_ganglia.Registry.claim",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Basal Ganglia — Task Heartbeat
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkTaskHeartbeat(allocator: Allocator, iterations: u64) !BenchmarkResult {
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    // Pre-populate with tasks
    const warmup_count = @min(100, iterations);
    var i: u64 = 0;
    while (i < warmup_count) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        _ = try registry.claim(allocator, task_id, "agent-1", 60000);
    }

    const start = timer.read();

    i = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{@mod(i, warmup_count)});
        defer allocator.free(task_id);

        const iter_start = timer.read();
        _ = registry.heartbeat(task_id, "agent-1");
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "basal_ganglia.Registry.heartbeat",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Amygdala — shouldAvoid (string search heavy)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkAmygdalaShouldAvoid(allocator: Allocator, iterations: u64) !BenchmarkResult {
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const start = timer.read();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const iter_start = timer.read();
        // This is I/O heavy due to hippocampus read, but we measure the hot path
        const result = try amygdala.shouldAvoid(allocator, "flat-lr-schedule");
        _ = result; // Suppress unused warning
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = if (avg_ns > 0) 1_000_000_000 / avg_ns else 0;

    return BenchmarkResult{
        .name = "amygdala.shouldAvoid",
        .iterations = iterations,
        .total_ns = total_ns,
        .avg_ns = avg_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = ops_per_sec,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: ActionCandidate.score() — Inline function hot path
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkActionCandidateScore(allocator: Allocator, iterations: u64) !BenchmarkResult {
    _ = allocator;
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const candidate = basal_ganglia.ActionCandidate{
        .kind = .farm_recycle,
        .urgency = .high,
        .value = 0.8,
        .cost = 0.3,
    };

    const start = timer.read();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const iter_start = timer.read();
        const score = candidate.score();
        _ = score; // Prevent optimization
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
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

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK: Urgency.weight() — Switch hot path
// ═══════════════════════════════════════════════════════════════════════════════

pub fn benchmarkUrgencyWeight(allocator: Allocator, iterations: u64) !BenchmarkResult {
    _ = allocator;
    var timer = try Timer.start();
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    const urgencies = [_]basal_ganglia.Urgency{
        .critical, .high, .normal, .low,
    };

    const start = timer.read();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const urgency = urgencies[@mod(i, 4)];
        const iter_start = timer.read();
        const weight = urgency.weight();
        _ = weight; // Prevent optimization
        const iter_ns = timer.read() - iter_start;

        if (iter_ns < min_ns) min_ns = iter_ns;
        if (iter_ns > max_ns) max_ns = iter_ns;
    }

    const total_ns = timer.read() - start;
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

// ═══════════════════════════════════════════════════════════════════════════════
// RUN ALL BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runAll(allocator: Allocator, iterations: u64) !BenchmarkSuite {
    var suite = try BenchmarkSuite.init(allocator);

    std.debug.print("Running brain benchmarks with {d} iterations each...\n\n", .{iterations});

    // Basal Ganglia benchmarks
    std.debug.print("Benchmarking basal_ganglia.selectAction...\n", .{});
    try suite.addResult(try benchmarkSelectAction(iterations));

    std.debug.print("Benchmarking basal_ganglia.Registry.claim...\n", .{});
    try suite.addResult(try benchmarkTaskClaim(allocator, @min(1000, iterations)));

    std.debug.print("Benchmarking basal_ganglia.Registry.heartbeat...\n", .{});
    try suite.addResult(try benchmarkTaskHeartbeat(allocator, iterations));

    // Amygdala benchmarks (smaller iterations due to I/O)
    std.debug.print("Benchmarking amygdala.shouldAvoid...\n", .{});
    try suite.addResult(try benchmarkAmygdalaShouldAvoid(allocator, @min(100, iterations)));

    // Micro-benchmarks
    std.debug.print("Benchmarking ActionCandidate.score...\n", .{});
    try suite.addResult(try benchmarkActionCandidateScore(allocator, iterations * 10));

    std.debug.print("Benchmarking Urgency.weight...\n", .{});
    try suite.addResult(try benchmarkUrgencyWeight(allocator, iterations * 10));

    return suite;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION REPORT — Bottleneck analysis
// ═══════════════════════════════════════════════════════════════════════════════

pub const OptimizationOpportunity = struct {
    region: []const u8,
    function: []const u8,
    bottleneck: []const u8,
    suggestion: []const u8,
    expected_speedup: f32,
};

pub fn analyzeBottlenecks() []const OptimizationOpportunity {
    return &[_]OptimizationOpportunity{
        .{
            .region = "basal_ganglia",
            .function = "Registry.claim",
            .bottleneck = "StringHashMap allocations on every claim",
            .suggestion = "Use arena allocator for registry, pre-allocate buckets",
            .expected_speedup = 1.3,
        },
        .{
            .region = "basal_ganglia",
            .function = "selectAction",
            .bottleneck = "Linear scan of candidates",
            .suggestion = "Already O(n) but small N, keep as-is for branch prediction",
            .expected_speedup = 1.0,
        },
        .{
            .region = "amygdala",
            .function = "shouldAvoid",
            .bottleneck = "Hippocampus read + string search in loop",
            .suggestion = "Cache fear memories in hash map, use string interning",
            .expected_speedup = 2.5,
        },
        .{
            .region = "amygdala",
            .function = "conditionFear",
            .bottleneck = "Multiple allocator.dupe calls",
            .suggestion = "Use stack buffers for tags, batch alloc",
            .expected_speedup = 1.2,
        },
        .{
            .region = "reticular_aras",
            .function = "sweepOnce",
            .bottleneck = "Manual JSON parsing with indexOf loops",
            .suggestion = "Use std.json or cached struct from evolution state",
            .expected_speedup = 3.0,
        },
        .{
            .region = "queen_dlpfc",
            .function = "decide",
            .bottleneck = "ArrayList allocations for candidates",
            .suggestion = "Use fixed-size array on stack (max 10 candidates)",
            .expected_speedup = 1.5,
        },
    };
}

pub fn printOptimizationReport() !void {
    const opportunities = analyzeBottlenecks();

    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                       OPTIMIZATION OPPORTUNITIES                              ║
        \\╚══════════════════════════════════════════════════════════════════════════╝
        \\
    );

    for (opportunities) |opp| {
        std.debug.print(
            \\Region: {s}
            \\  Function: {s}
            \\  Bottleneck: {s}
            \\  Suggestion: {s}
            \\  Expected Speedup: {d:.1}x
            \\
        , .{ opp.region, opp.function, opp.bottleneck, opp.suggestion, opp.expected_speedup });
    }

    std.debug.print("Total potential speedup: {d:.1}x (cumulative)\n\n", .{calculateCumulativeSpeedup(opportunities)});
}

fn calculateCumulativeSpeedup(opportunities: []const OptimizationOpportunity) f32 {
    var cumulative: f32 = 1.0;
    for (opportunities) |opp| {
        cumulative *= opp.expected_speedup;
    }
    return cumulative;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "brain_benchmark — selectAction runs" {
    const result = try benchmarkSelectAction(100);
    try std.testing.expect(result.iterations == 100);
    try std.testing.expect(result.avg_ns > 0);
    try std.testing.expect(result.ops_per_sec > 0);
}

test "brain_benchmark — ActionCandidate score is fast" {
    const result = try benchmarkActionCandidateScore(std.testing.allocator, 1000);
    try std.testing.expect(result.avg_ns < 1000); // Should be sub-microsecond
}

test "brain_benchmark — Urgency weight is fast" {
    const result = try benchmarkUrgencyWeight(std.testing.allocator, 1000);
    try std.testing.expect(result.avg_ns < 500); // Should be very fast
}

test "brain_benchmark — Task claim registry works" {
    const result = try benchmarkTaskClaim(std.testing.allocator, 100);
    try std.testing.expect(result.iterations == 100);
}

test "brain_benchmark — BenchmarkSuite report" {
    var suite = try BenchmarkSuite.init(std.testing.allocator);
    defer suite.deinit();

    try suite.addResult(BenchmarkResult{
        .name = "test",
        .iterations = 100,
        .total_ns = 1000000,
        .avg_ns = 10000,
        .min_ns = 5000,
        .max_ns = 20000,
        .ops_per_sec = 100000,
    });

    try suite.printReport();
}

test "brain_benchmark — Optimization report" {
    try printOptimizationReport();
}
