// Trinity Benchmarks - Core Operations
// Measures throughput, latency, and memory efficiency
//
// Run: zig build-exe benchmarks/bench_core.zig -O ReleaseFast && ./bench_core
// Or:  zig run benchmarks/bench_core.zig -O ReleaseFast

const std = @import("std");
const trinity = @import("../src/trinity.zig");
const vsa = @import("../src/vsa.zig");

const Hypervector = trinity.Hypervector;
const HybridBigInt = trinity.HybridBigInt;

// Benchmark configuration
const WARMUP_ITERATIONS = 100;
const BENCHMARK_ITERATIONS = 10000;
const DIMENSIONS = [_]usize{ 1000, 4000, 10000 };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              TRINITY BENCHMARK SUITE v0.2.0                      ║\n", .{});
    try stdout.print("║                                                                  ║\n", .{});
    try stdout.print("║  Measuring: Throughput, Latency, Memory Efficiency               ║\n", .{});
    try stdout.print("║  φ² + 1/φ² = 3                                                   ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n\n", .{});

    // System info
    try stdout.print("SYSTEM INFO:\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────────\n", .{});
    try stdout.print("  Warmup iterations:    {d}\n", .{WARMUP_ITERATIONS});
    try stdout.print("  Benchmark iterations: {d}\n", .{BENCHMARK_ITERATIONS});
    try stdout.print("  Dimensions tested:    {d}, {d}, {d}\n\n", .{ DIMENSIONS[0], DIMENSIONS[1], DIMENSIONS[2] });

    // Run benchmarks for each dimension
    for (DIMENSIONS) |dim| {
        try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});
        try stdout.print("  DIMENSION: {d}\n", .{dim});
        try stdout.print("═══════════════════════════════════════════════════════════════════\n\n", .{});

        try benchmarkBind(stdout, dim);
        try benchmarkBundle(stdout, dim);
        try benchmarkPermute(stdout, dim);
        try benchmarkSimilarity(stdout, dim);
        try benchmarkMemory(stdout, dim);
        try stdout.print("\n", .{});
    }

    // Summary
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  BENCHMARK COMPLETE\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});
}

fn benchmarkBind(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 12345);
    var b = vsa.randomVector(dim, 67890);

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }

    // Benchmark
    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.bind(&a, &b);
    }
    const elapsed_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(BENCHMARK_ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));

    try writer.print("  BIND:\n", .{});
    try writer.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    try writer.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    try writer.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkBundle(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 11111);
    var b = vsa.randomVector(dim, 22222);

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }

    // Benchmark
    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.bundle2(&a, &b);
    }
    const elapsed_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(BENCHMARK_ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));

    try writer.print("  BUNDLE:\n", .{});
    try writer.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    try writer.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    try writer.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkPermute(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 33333);

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.permute(&a, 1);
    }

    // Benchmark
    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.permute(&a, 1);
    }
    const elapsed_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(BENCHMARK_ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));

    try writer.print("  PERMUTE:\n", .{});
    try writer.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    try writer.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    try writer.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkSimilarity(writer: anytype, dim: usize) !void {
    var a = vsa.randomVector(dim, 44444);
    var b = vsa.randomVector(dim, 55555);

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }

    // Benchmark
    var timer = std.time.Timer.start() catch unreachable;
    for (0..BENCHMARK_ITERATIONS) |_| {
        _ = vsa.cosineSimilarity(&a, &b);
    }
    const elapsed_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(BENCHMARK_ITERATIONS)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));

    try writer.print("  SIMILARITY:\n", .{});
    try writer.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    try writer.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    try writer.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkMemory(writer: anytype, dim: usize) !void {
    // Memory efficiency comparison
    const naive_bytes = dim * 1; // 1 byte per trit (naive)
    const packed_bytes = (dim + 4) / 5; // 5 trits per byte (packed)
    const theoretical_bits = @as(f64, @floatFromInt(dim)) * 1.585; // log2(3) bits per trit
    const theoretical_bytes = @as(usize, @intFromFloat(theoretical_bits / 8.0)) + 1;

    const compression_ratio = @as(f64, @floatFromInt(naive_bytes)) / @as(f64, @floatFromInt(packed_bytes));
    const efficiency = @as(f64, @floatFromInt(theoretical_bytes)) / @as(f64, @floatFromInt(packed_bytes)) * 100.0;

    try writer.print("  MEMORY:\n", .{});
    try writer.print("    Naive (1 byte/trit):     {d} bytes\n", .{naive_bytes});
    try writer.print("    Packed (5 trits/byte):   {d} bytes\n", .{packed_bytes});
    try writer.print("    Theoretical minimum:     {d} bytes\n", .{theoretical_bytes});
    try writer.print("    Compression ratio:       {d:.2}x\n", .{compression_ratio});
    try writer.print("    Packing efficiency:      {d:.1}%\n\n", .{efficiency});
}
