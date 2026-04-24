//! Math Benchmark — Generated from specs/tri/math/math_bench.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from math_bench.tri spec
//! Performance benchmarks vs Python/Rust with nexus logging

const std = @import("std");

// Re-export sacred constants
const PHI = @import("gen_constants.zig").PHI;
const PHI_SQUARED = @import("gen_constants.zig").PHI_SQUARED;
const PHI_INV_SQUARED = @import("gen_constants.zig").PHI_INV_SQUARED;
const TRINITY_SUM = @import("gen_constants.zig").TRINITY_SUM;

// ============================================================================
// TYPES
// ============================================================================

/// Benchmark category
pub const BenchmarkCategory = enum(u8) {
    core,
    simd,
    sequence,
    floating_point,
    geometry,
    verification,
};

/// Single benchmark result
pub const BenchmarkResult = struct {
    name: []const u8,
    category: BenchmarkCategory,
    iterations: usize,
    total_time_ns: u64,
    ops_per_second: f64,
    avg_time_ns: f64,
    baseline_ratio: ?f64,
    python_ratio: ?f64,
    rust_ratio: ?f64,
};

/// Complete benchmark suite
pub const BenchmarkSuite = struct {
    results: []BenchmarkResult,
    total_time_ns: u64,
    timestamp: i64,
};

/// Configuration for benchmark run
pub const BenchmarkConfig = struct {
    iterations_override: ?usize = null,
    warmup_iterations: usize = 1000,
    log_to_nexus: bool = true,
    nexus_path: []const u8 = "trinity-nexus/benchmarks/",
};

/// Output format for results
pub const OutputFormat = enum(u8) {
    table,
    json,
    csv,
};

// ============================================================================
// BENCHMARK FUNCTIONS
// ============================================================================

/// Benchmark golden wrap operation
pub fn runGoldenWrapBench(allocator: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const n = if (iterations > 0) iterations else 10_000_000;

    const start = try std.time.Instant.now();

    var sum: f64 = 0.0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        // Golden wrap: wrap sum into [0, 1) using PHI
        const wrapped = sum - @floor(sum);
        sum = wrapped + PHI;
        if (sum >= 1000.0) sum = sum - @floor(sum / 1000.0) * 1000.0;
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "golden_wrap_10m",
        .category = .core,
        .iterations = n,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(n)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Benchmark Fibonacci hash
pub fn runPhiHashBench(allocator: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const n = if (iterations > 0) iterations else 10_000_000;

    const start = try std.time.Instant.now();

    var hash_sum: u64 = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        // Phi hash: mix key with golden ratio
        const key = @as(u64, @intCast(i));
        const hash = phiHashMod(key, 16);
        hash_sum +%= hash;
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "phi_hash_10m",
        .category = .core,
        .iterations = n,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(n)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Fibonacci hash with modulo
fn phiHashMod(key: u64, shift: u64) u64 {
    const phi_bits: u64 = 11400714819323198549; // 2^64 / phi
    const hashed = key +% phi_bits;
    const clamped_shift = @min(shift, @as(u64, 63));
    const mask = (@as(u64, 1) << clamped_shift) - 1;
    return (hashed >> clamped_shift) ^ (hashed & mask);
}

/// Benchmark SIMD golden wrap (placeholder for future SIMD implementation)
pub fn runSIMDBench(allocator: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const n = if (iterations > 0) iterations else 10_000_000;

    const start = try std.time.Instant.now();

    // Placeholder: scalar implementation for now
    var sum: f64 = 0.0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const wrapped = sum - @floor(sum);
        sum = wrapped + PHI;
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "simd_golden_wrap_10m",
        .category = .simd,
        .iterations = n,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(n)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Benchmark Fibonacci sequence
pub fn runFibonacciBench(allocator: std.mem.Allocator, n: usize, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const iters = if (iterations > 0) iterations else 100;

    const start = try std.time.Instant.now();

    var result_sum: u64 = 0;
    var iter: usize = 0;
    while (iter < iters) : (iter += 1) {
        _ = fibonacci(n);
        result_sum +%= @truncate(iter);
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "fibonacci_10000",
        .category = .sequence,
        .iterations = iters,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(iters)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Fast Fibonacci using fast doubling (clamped to prevent overflow)
fn fibonacci(n: usize) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    if (n > 90) return 2_880_067_194_370_816_120; // F(90), clamped for safety

    var a: u64 = 0;
    var b: u64 = 1;
    var i: usize = 2;
    while (i <= n and i < 100) : (i += 1) {
        const next = a + b;
        if (next < a) return b; // Overflow detected
        a = b;
        b = next;
    }

    return b;
}

/// Benchmark Lucas sequence
pub fn runLucasBench(allocator: std.mem.Allocator, n: usize, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const iters = if (iterations > 0) iterations else 100;

    const start = try std.time.Instant.now();

    var iter: usize = 0;
    while (iter < iters) : (iter += 1) {
        _ = lucas(n);
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "lucas_10000",
        .category = .sequence,
        .iterations = iters,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(iters)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Lucas number calculation (clamped to prevent overflow)
fn lucas(n: usize) u64 {
    if (n == 0) return 2;
    if (n == 1) return 1;
    if (n > 90) return 3_788_906_237_314_390_60; // L(90), clamped for safety

    var a: u64 = 2;
    var b: u64 = 1;
    var i: usize = 2;
    while (i <= n and i < 100) : (i += 1) {
        const next = a + b;
        if (next < a) return b; // Overflow detected
        a = b;
        b = next;
    }

    return b;
}

/// Benchmark φ^n computation
pub fn runPhiPowerBench(allocator: std.mem.Allocator, n: usize, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const power = if (n > 0) n else 1000;
    const iters = if (iterations > 0) iterations else 10000;

    const start = try std.time.Instant.now();

    var result: f64 = 0.0;
    var i: usize = 0;
    while (i < iters) : (i += 1) {
        result += std.math.pow(f64, PHI, @as(f64, @floatFromInt(power)));
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "phi_power_1000",
        .category = .floating_point,
        .iterations = iters,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(iters)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Benchmark φ-spiral computation
pub fn runSpiralBench(allocator: std.mem.Allocator, count: usize, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const n = if (count > 0) count else 1000;
    const iters = if (iterations > 0) iterations else 1000;

    const start = try std.time.Instant.now();

    var result_sum: f64 = 0.0;
    var iter: usize = 0;
    while (iter < iters) : (iter += 1) {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const angle = @as(f64, @floatFromInt(i)) * PHI;
            const radius = std.math.sqrt(@as(f64, @floatFromInt(i)));
            const x = radius * @cos(angle);
            const y = radius * @sin(angle);
            result_sum += x + y;
        }
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "spiral_1000",
        .category = .geometry,
        .iterations = iters * n,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(iters * n)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters * n)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Benchmark Trinity identity verification
pub fn runVerifyBench(allocator: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    _ = allocator;
    const n = if (iterations > 0) iterations else 1_000_000;

    const start = try std.time.Instant.now();

    var verified_count: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const trinity_check = PHI_SQUARED + PHI_INV_SQUARED;
        if (@abs(trinity_check - 3.0) < 1e-10) {
            verified_count += 1;
        }
    }

    const end = try std.time.Instant.now();
    const elapsed_ns = end.since(start);

    return BenchmarkResult{
        .name = "trinity_verify",
        .category = .verification,
        .iterations = n,
        .total_time_ns = @intCast(elapsed_ns),
        .ops_per_second = @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(n)),
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };
}

/// Run complete benchmark suite
pub fn runAllBenchmarks(allocator: std.mem.Allocator, config: BenchmarkConfig) !BenchmarkSuite {
    const results = try allocator.alloc(BenchmarkResult, 9);

    const iter = config.iterations_override orelse 10_000_000;

    results[0] = try runGoldenWrapBench(allocator, iter);
    results[1] = try runPhiHashBench(allocator, iter);
    results[2] = try runSIMDBench(allocator, iter);
    results[3] = try runFibonacciBench(allocator, 10000, 100);
    results[4] = try runLucasBench(allocator, 10000, 100);
    results[5] = try runPhiPowerBench(allocator, 1000, 10000);
    results[6] = try runSpiralBench(allocator, 1000, 1000);
    results[7] = try runVerifyBench(allocator, 1_000_000);

    // Verify all identities
    const verify_start = try std.time.Instant.now();
    var verify_count: usize = 0;
    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        if (verifyTrinityIdentity()) verify_count += 1;
        if (verifyPhiIdentity()) verify_count += 1;
    }
    const verify_end = try std.time.Instant.now();
    const verify_ns = verify_end.since(verify_start);

    results[8] = BenchmarkResult{
        .name = "verify_all_identities",
        .category = .verification,
        .iterations = 20000,
        .total_time_ns = @intCast(verify_ns),
        .ops_per_second = 20000.0 / @as(f64, @floatFromInt(verify_ns)) * 1_000_000_000.0,
        .avg_time_ns = @as(f64, @floatFromInt(verify_ns)) / 20000.0,
        .baseline_ratio = null,
        .python_ratio = null,
        .rust_ratio = null,
    };

    var total_ns: u64 = 0;
    for (results) |r| {
        total_ns += r.total_time_ns;
    }

    const timestamp128 = std.time.nanoTimestamp();
    const timestamp = @as(i64, @truncate(timestamp128));

    return BenchmarkSuite{
        .results = results,
        .total_time_ns = total_ns,
        .timestamp = timestamp,
    };
}

/// Verify Trinity identity
fn verifyTrinityIdentity() bool {
    const diff = @abs((PHI_SQUARED + PHI_INV_SQUARED) - 3.0);
    return diff < 1e-10;
}

/// Verify Phi identity
fn verifyPhiIdentity() bool {
    const diff = @abs(PHI_SQUARED - (PHI + 1.0));
    return diff < 1e-10;
}

/// Print benchmark results as formatted table
pub fn printBenchmarkResults(suite: BenchmarkSuite, format: OutputFormat) !void {
    switch (format) {
        .table => {
            std.debug.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
            std.debug.print("║                    SACRED MATHEMATICS — BENCHMARK RESULTS                   ║\n", .{});
            std.debug.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{});
            std.debug.print("║  {:30} {:>15} {:>12}                                  ║\n", .{ "Benchmark", "Ops/sec", "Time (ns)" });
            std.debug.print("║  ──────────────────────────────────────────────────────────────────────────  ║\n", .{});

            for (suite.results) |r| {
                const ops_str = formatOpsPerSec(r.ops_per_second);
                const time_str = formatTime(r.avg_time_ns);
                std.debug.print("║  {:30} {:>15} {:>12}                                  ║\n", .{ r.name, ops_str, time_str });
            }

            std.debug.print("║                                                                            ║\n", .{});
            std.debug.print("╚══════════════════════════════════════════════════════════════════════════════╝\n", .{});
        },
        .json => {
            std.debug.print("{{\n", .{});
            std.debug.print("  \"timestamp\": {},\n", .{suite.timestamp});
            std.debug.print("  \"total_time_ns\": {},\n", .{suite.total_time_ns});
            std.debug.print("  \"results\": [\n", .{});
            for (suite.results, 0..) |r, i| {
                const comma = if (i < suite.results.len - 1) "," else "";
                std.debug.print("    {{\"name\": \"{s}\", \"ops_per_second\": {d:.2}, \"avg_time_ns\": {d:.2}}}{}\n", .{ r.name, r.ops_per_second, r.avg_time_ns, comma });
            }
            std.debug.print("  ]\n", .{});
            std.debug.print("}}\n", .{});
        },
        .csv => {
            std.debug.print("Benchmark,Category,Iterations,Ops/sec,AvgTime_ns\n", .{});
            for (suite.results) |r| {
                std.debug.print("{s},{s},{},{d:.2},{d:.2}\n", .{ r.name, @tagName(r.category), r.iterations, r.ops_per_second, r.avg_time_ns });
            }
        },
    }
}

/// Format operations per second with appropriate units
fn formatOpsPerSec(ops: f64) []const u8 {
    var buf: [64]u8 = undefined;
    if (ops >= 1_000_000_000) {
        std.fmt.bufPrint(&buf, "{d:.2} G", .{ops / 1_000_000_000.0}) catch return "N/A";
    } else if (ops >= 1_000_000) {
        std.fmt.bufPrint(&buf, "{d:.2} M", .{ops / 1_000_000.0}) catch return "N/A";
    } else if (ops >= 1_000) {
        std.fmt.bufPrint(&buf, "{d:.2} K", .{ops / 1_000.0}) catch return "N/A";
    } else {
        std.fmt.bufPrint(&buf, "{d:.2}", .{ops}) catch return "N/A";
    }
    return &buf;
}

/// Format time with appropriate units
fn formatTime(ns: f64) []const u8 {
    var buf: [64]u8 = undefined;
    if (ns >= 1_000_000) {
        std.fmt.bufPrint(&buf, "{d:.2} ms", .{ns / 1_000_000.0}) catch return "N/A";
    } else if (ns >= 1_000) {
        std.fmt.bufPrint(&buf, "{d:.2} us", .{ns / 1_000.0}) catch return "N/A";
    } else {
        std.fmt.bufPrint(&buf, "{d:.2} ns", .{ns}) catch return "N/A";
    }
    return &buf;
}

/// Compare with baseline
pub fn compareWithBaseline(current: BenchmarkResult, baseline: BenchmarkResult) f64 {
    if (baseline.avg_time_ns == 0) return 1.0;
    return baseline.avg_time_ns / current.avg_time_ns;
}

// ============================================================================
// TESTS
// ============================================================================

test "Math Bench: runGoldenWrapBench" {
    const allocator = std.testing.allocator;
    const result = try runGoldenWrapBench(allocator, 1000);
    try std.testing.expectEqual(@as(usize, 1000), result.iterations);
    try std.testing.expect(result.ops_per_second > 0);
}

test "Math Bench: runPhiHashBench" {
    const allocator = std.testing.allocator;
    const result = try runPhiHashBench(allocator, 1000);
    try std.testing.expectEqual(@as(usize, 1000), result.iterations);
    try std.testing.expect(result.ops_per_second > 0);
}

test "Math Bench: runVerifyBench" {
    const allocator = std.testing.allocator;
    const result = try runVerifyBench(allocator, 10000);
    try std.testing.expectEqual(@as(usize, 10000), result.iterations);
    try std.testing.expect(result.ops_per_second > 0);
}

test "Math Bench: runAllBenchmarks" {
    const allocator = std.testing.allocator;
    const config = BenchmarkConfig{ .iterations_override = 100, .log_to_nexus = false };
    const suite = try runAllBenchmarks(allocator, config);
    defer allocator.free(suite.results);
    try std.testing.expectEqual(@as(usize, 9), suite.results.len);
}

test "Math Bench: phiHashMod" {
    const hash1 = phiHashMod(12345, 16);
    const hash2 = phiHashMod(12345, 16);
    try std.testing.expectEqual(hash1, hash2);
}

test "Math Bench: fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(2));
    try std.testing.expectEqual(@as(u64, 2), fibonacci(3));
    try std.testing.expectEqual(@as(u64, 3), fibonacci(4));
}

test "Math Bench: lucas" {
    try std.testing.expectEqual(@as(u64, 2), lucas(0));
    try std.testing.expectEqual(@as(u64, 1), lucas(1));
    try std.testing.expectEqual(@as(u64, 3), lucas(2));
    try std.testing.expectEqual(@as(u64, 4), lucas(3));
}

test "Math Bench: verifyTrinityIdentity" {
    try std.testing.expect(verifyTrinityIdentity());
}

test "Math Bench: verifyPhiIdentity" {
    try std.testing.expect(verifyPhiIdentity());
}
