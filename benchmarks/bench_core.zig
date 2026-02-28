// Trinity Benchmarks - Core Operations
// Measures throughput, latency, and memory efficiency
//
// Run: zig build bench

const std = @import("std");
const vsa = @import("vsa");

// Benchmark configuration
const WARMUP_ITERATIONS = 100;
const BENCHMARK_ITERATIONS = 10000;
const DIMENSIONS = [_]usize{ 1000, 4000, 10000 };

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              TRINITY BENCHMARK SUITE v0.2.0                      ║\n", .{});
    std.debug.print("║                                                                  ║\n", .{});
    std.debug.print("║  Measuring: Throughput, Latency, Memory Efficiency               ║\n", .{});
    std.debug.print("║  φ² + 1/φ² = 3                                                   ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n\n", .{});

    // System info
    std.debug.print("SYSTEM INFO:\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Warmup iterations:    {d}\n", .{WARMUP_ITERATIONS});
    std.debug.print("  Benchmark iterations: {d}\n", .{BENCHMARK_ITERATIONS});
    std.debug.print("  Dimensions tested:    {d}, {d}, {d}\n\n", .{ DIMENSIONS[0], DIMENSIONS[1], DIMENSIONS[2] });

    // Run benchmarks for each dimension
    for (DIMENSIONS) |dim| {
        std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("  DIMENSION: {d}\n", .{dim});
        std.debug.print("═══════════════════════════════════════════════════════════════════\n\n", .{});

        try benchmarkBind(dim);
        try benchmarkBundle(dim);
        try benchmarkPermute(dim);
        try benchmarkSimilarity(dim);
        try benchmarkMemory(dim);
        std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  BENCHMARK COMPLETE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════\n", .{});
}

fn benchmarkBind(dim: usize) !void {
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

    std.debug.print("  BIND:\n", .{});
    std.debug.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    std.debug.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    std.debug.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkBundle(dim: usize) !void {
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

    std.debug.print("  BUNDLE:\n", .{});
    std.debug.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    std.debug.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    std.debug.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkPermute(dim: usize) !void {
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

    std.debug.print("  PERMUTE:\n", .{});
    std.debug.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    std.debug.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    std.debug.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkSimilarity(dim: usize) !void {
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

    std.debug.print("  SIMILARITY:\n", .{});
    std.debug.print("    Throughput: {d:.2} ops/sec\n", .{ops_per_sec});
    std.debug.print("    Latency:    {d:.2} ns/op\n", .{ns_per_op});
    std.debug.print("    Total time: {d:.2} ms\n\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
}

fn benchmarkMemory(dim: usize) !void {
    // Memory efficiency comparison
    const naive_bytes = dim * 1; // 1 byte per trit (naive)
    const packed_bytes = (dim + 4) / 5; // 5 trits per byte (packed)
    const theoretical_bits = @as(f64, @floatFromInt(dim)) * 1.585; // log2(3) bits per trit
    const theoretical_bytes = @as(usize, @intFromFloat(theoretical_bits / 8.0)) + 1;

    const compression_ratio = @as(f64, @floatFromInt(naive_bytes)) / @as(f64, @floatFromInt(packed_bytes));
    const efficiency = @as(f64, @floatFromInt(theoretical_bytes)) / @as(f64, @floatFromInt(packed_bytes)) * 100.0;

    std.debug.print("  MEMORY:\n", .{});
    std.debug.print("    Naive (1 byte/trit):     {d} bytes\n", .{naive_bytes});
    std.debug.print("    Packed (5 trits/byte):   {d} bytes\n", .{packed_bytes});
    std.debug.print("    Theoretical minimum:     {d} bytes\n", .{theoretical_bytes});
    std.debug.print("    Compression ratio:       {d:.2}x\n", .{compression_ratio});
    std.debug.print("    Packing efficiency:      {d:.1}%\n\n", .{efficiency});
}
