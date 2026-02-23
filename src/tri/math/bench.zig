// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — BENCHMARK MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// Performance benchmarks
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const parent_mod = @import("mod.zig");
const format = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    ops_per_sec: f64,
    avg_time_ns: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RUN BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

fn benchmarkGoldenWrap(iterations: usize) BenchmarkResult {
    var timer = std.time.Timer.start() catch return .{
        .name = "Golden Wrap (skipped - timer not supported)",
        .ops_per_sec = 0,
        .avg_time_ns = 0,
    };
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = parent_mod.goldenWrap(@as(i16, @intCast(i % 54)) - 26);
    }

    const elapsed_ns = timer.read() - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1e9 / avg_ns;

    return .{
        .name = "Golden Wrap",
        .ops_per_sec = ops_per_sec,
        .avg_time_ns = avg_ns,
    };
}

fn benchmarkPhiHash(iterations: usize) BenchmarkResult {
    var timer = std.time.Timer.start() catch return .{
        .name = "Phi Hash (skipped - timer not supported)",
        .ops_per_sec = 0,
        .avg_time_ns = 0,
    };
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = parent_mod.phiHash(@intCast(i), 64 - 16);
    }

    const elapsed_ns = timer.read() - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1e9 / avg_ns;

    return .{
        .name = "Phi Hash",
        .ops_per_sec = ops_per_sec,
        .avg_time_ns = avg_ns,
    };
}

fn benchmarkPhiPower(iterations: usize) BenchmarkResult {
    var timer = std.time.Timer.start() catch return .{
        .name = "φ^n (skipped - timer not supported)",
        .ops_per_sec = 0,
        .avg_time_ns = 0,
    };
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = std.math.pow(f64, parent_mod.PHI, @as(f64, @floatFromInt(i % 100)));
    }

    const elapsed_ns = timer.read() - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1e9 / avg_ns;

    return .{
        .name = "φ^n (float)",
        .ops_per_sec = ops_per_sec,
        .avg_time_ns = avg_ns,
    };
}

fn benchmarkFibonacci(iterations: usize) BenchmarkResult {
    var timer = std.time.Timer.start() catch return .{
        .name = "Fibonacci (skipped - timer not supported)",
        .ops_per_sec = 0,
        .avg_time_ns = 0,
    };
    const start = timer.read();

    // Compute F(80) multiple times - safe from i64 overflow (F(92) is max for i64)
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = parent_mod.fibonacci(80);
    }

    const elapsed_ns = timer.read() - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1e9 / avg_ns;

    return .{
        .name = "Fibonacci F(80)",
        .ops_per_sec = ops_per_sec,
        .avg_time_ns = avg_ns,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRINT RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printBenchmarkResults(writer: anytype, allocator: std.mem.Allocator) !void {
    try writer.writeAll(format.colors.bold);
    try writer.writeAll("╔════════════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║                    PERFORMANCE BENCHMARKS                         ║\n");
    try writer.writeAll("╠════════════════════════════════════════════════════════════════════╣\n");
    try writer.writeAll(format.colors.reset);

    // Core operations
    try writer.writeAll(format.colors.gold);
    try writer.writeAll("  CORE OPERATIONS\n");
    try writer.writeAll(format.colors.reset);
    try writer.writeAll("  ────────────────────────────────────────────────────────────────\n");

    const core_iterations = 1_000_000;

    const golden_wrap = benchmarkGoldenWrap(core_iterations);
    try printBenchmarkResult(writer, &golden_wrap);

    const phi_hash = benchmarkPhiHash(core_iterations);
    try printBenchmarkResult(writer, &phi_hash);

    // Floating point
    try writer.writeAll("\n");
    try writer.writeAll(format.colors.cyan);
    try writer.writeAll("  FLOATING POINT\n");
    try writer.writeAll(format.colors.reset);
    try writer.writeAll("  ────────────────────────────────────────────────────────────────\n");

    const phi_power = benchmarkPhiPower(100_000);
    try printBenchmarkResult(writer, &phi_power);

    // Sequences
    try writer.writeAll("\n");
    try writer.writeAll(format.colors.purple);
    try writer.writeAll("  SEQUENCES\n");
    try writer.writeAll(format.colors.reset);
    try writer.writeAll("  ────────────────────────────────────────────────────────────────\n");

    const fibonacci = benchmarkFibonacci(1_000);
    try printBenchmarkResult(writer, &fibonacci);

    try writer.writeAll(format.colors.bold);
    try writer.writeAll("\n╚════════════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll(format.colors.reset);

    _ = allocator;
}

fn printBenchmarkResult(writer: anytype, result: *const BenchmarkResult) !void {
    try writer.print("  {s:.<30}", .{result.name});
    try writer.writeAll(format.colors.green);

    if (result.ops_per_sec >= 1_000_000) {
        try writer.print("{d:.[1]} M ops/sec", .{ result.ops_per_sec / 1_000_000, 2 });
    } else if (result.ops_per_sec >= 1_000) {
        try writer.print("{d:.[1]} K ops/sec", .{ result.ops_per_sec / 1_000, 2 });
    } else {
        try writer.print("{d:.[1]} ops/sec", .{ result.ops_per_sec, 2 });
    }

    try writer.writeAll(format.colors.reset);
    try writer.print(" ({d:.[1]} ns/op)\n", .{ result.avg_time_ns, 2 });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "benchmark golden wrap" {
    const result = benchmarkGoldenWrap(1000);
    try std.testing.expect(result.ops_per_sec > 0);
    try std.testing.expect(result.avg_time_ns > 0);
}
