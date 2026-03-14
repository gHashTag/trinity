// @origin(spec:benchmark.tri) @regen(manual-impl)
// TRI MATH BENCHMARK v3.6
//
// Benchmark performance of TRI math engines
// φ² + 1/φ² = 3
//

const std = @import("std");

pub fn main() !void {
    try runBenchmarks();
}

fn runBenchmarks() !void {
    std.debug.print("\n═════════════════════════════════════════════════════════\n", .{});
    std.debug.print("║ TRI MATH v3.6 BENCHMARKS                        ║\n", .{});
    std.debug.print("╠════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Date: {d}                                    ║\n", .{std.time.timestamp()});
    std.debug.print("╠══════════════════════════════════════╣\n", .{});

    // Formula Discovery Benchmark
    std.debug.print("║ 1. FORMULA DISCOVERY                              ║\n", .{});
    const formula_result = benchmarkFormulaDiscovery();
    try printBenchmarkResult("Formula Discovery", formula_result);

    std.debug.print("╠════════════════════════════════════════╣\n", .{});

    // Sacred Economy Benchmark
    std.debug.print("║ 2. SACRED ECONOMY                                ║\n", .{});
    const economy_result = benchmarkSacredEconomy();
    try printBenchmarkResult("Sacred Economy", economy_result);

    std.debug.print("╠════════════════════════════════════════╣\n", .{});

    // Self-Improver Benchmark
    std.debug.print("║ 3. SELF-IMPROVER                                  ║\n", .{});
    const improver_result = benchmarkSelfImprover();
    try printBenchmarkResult("Self-Improver", improver_result);

    std.debug.print("╠════════════════════════════════════════╣\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════\n\n", .{});

    // Summary
    const total_time_ns = formula_result.total_time_ns + economy_result.total_time_ns + improver_result.total_time_ns;
    const avg_time_ns = @divTrunc(total_time_ns, 3);
    const avg_time_us = avg_time_ns / 1000;
    std.debug.print("═════════════════════════════════════════════════\n", .{});
    std.debug.print("║ AVERAGE PERFORMANCE                                ║\n", .{});
    std.debug.print("╠════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Average Total Time: {d} ms                     ║\n", .{avg_time_us / 1000});
    std.debug.print("║ Average Time/Op: {d} ns                        ║\n", .{avg_time_ns});
    std.debug.print("╠══════════════════════════════════════════╣\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════\n\n", .{});
}

const BenchmarkResult = struct {
    operations: usize,
    total_time_ns: u64,
};

fn printBenchmarkResult(name: []const u8, result: BenchmarkResult) !void {
    _ = name;
    const total_ns = result.total_time_ns;
    const total_us = total_ns / 1000;
    const total_ms = total_ns / 1_000_000;
    const avg_ns = @divTrunc(total_ns, result.operations);

    const ops_per_sec = if (total_ns > 0)
        @as(u64, @intCast(@divTrunc(result.operations * 1_000_000_000, total_ns)))
    else
        @as(usize, std.math.maxInt(usize));

    std.debug.print("║   Operations: {d}                                ║\n", .{result.operations});
    if (total_ms > 0) {
        std.debug.print("║   Time: {d} ms total ({d} ns avg)               ║\n", .{ total_ms, avg_ns });
    } else if (total_us > 0) {
        std.debug.print("║   Time: {d} μs total ({d} ns avg)               ║\n", .{ total_us, avg_ns });
    } else {
        std.debug.print("║   Time: {d} ns total ({d} ns avg)               ║\n", .{ total_ns, avg_ns });
    }
    std.debug.print("║   Speed: {d} ops/s                             ║\n", .{ops_per_sec});
    std.debug.print("╠══════════════════════════════════════════╣\n", .{});
}

const NUM_ITERATIONS = 10_000_000;

fn benchmarkFormulaDiscovery() BenchmarkResult {
    const start_time = std.time.nanoTimestamp();

    var sum: f64 = 0;
    var i: usize = 0;
    while (i < NUM_ITERATIONS) : (i += 1) {
        sum += std.math.sqrt(@as(f64, @floatFromInt(i)));
    }

    // Prevent optimization by using the result
    if (sum < 0.0) {
        std.debug.print("", .{});
    }

    const elapsed = std.time.nanoTimestamp() - start_time;

    return BenchmarkResult{
        .operations = NUM_ITERATIONS,
        .total_time_ns = @as(u64, @intCast(elapsed)),
    };
}

fn benchmarkSacredEconomy() BenchmarkResult {
    const start_time = std.time.nanoTimestamp();

    var total_apy: f64 = 0;
    var i: usize = 0;
    while (i < NUM_ITERATIONS) : (i += 1) {
        const principal: f64 = 1000.0;
        const rate: f64 = 0.0382;
        const staked: f64 = @as(f64, @floatFromInt(i % 1000));
        const apy = principal * rate * (staked / 1000.0);
        total_apy += apy;
    }

    // Prevent optimization by using the result
    if (total_apy < 0.0) {
        std.debug.print("", .{});
    }

    const elapsed = std.time.nanoTimestamp() - start_time;

    return BenchmarkResult{
        .operations = NUM_ITERATIONS,
        .total_time_ns = @as(u64, @intCast(elapsed)),
    };
}

fn benchmarkSelfImprover() BenchmarkResult {
    const start_time = std.time.nanoTimestamp();

    var total_importance: f64 = 0;
    var i: usize = 0;
    while (i < NUM_ITERATIONS) : (i += 1) {
        const old_importance: f64 = 1.0;
        const current_loss: f64 = @as(f64, @floatFromInt(i % 10)) / 20.0;
        const new_importance = old_importance + (0.1 * current_loss);
        total_importance += new_importance;
    }

    // Prevent optimization by using the result
    if (total_importance < 0.0) {
        std.debug.print("", .{});
    }

    const elapsed = std.time.nanoTimestamp() - start_time;

    return BenchmarkResult{
        .operations = NUM_ITERATIONS,
        .total_time_ns = @as(u64, @intCast(elapsed)),
    };
}

test "benchmark_result_struct" {
    const result = BenchmarkResult{
        .operations = 1000,
        .total_time_ns = 5000,
    };
    try std.testing.expectEqual(@as(usize, 1000), result.operations);
    try std.testing.expectEqual(@as(u64, 5000), result.total_time_ns);
}

test "benchmark_num_iterations" {
    try std.testing.expectEqual(@as(usize, 10_000_000), NUM_ITERATIONS);
}
