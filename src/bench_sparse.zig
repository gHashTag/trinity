// Trinity Sparse vs Dense Benchmark
// Compares memory and performance of sparse vs dense representations
//
// Run: zig run benchmarks/bench_sparse.zig -O ReleaseFast

const std = @import("std");
const sparse = @import("sparse.zig");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const SparseVector = sparse.SparseVector;
const HybridBigInt = hybrid.HybridBigInt;

const ITERATIONS = 10000;
const WARMUP = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║              TRINITY SPARSE vs DENSE BENCHMARK                              ║\n", .{});
    try stdout.print("║                                                                              ║\n", .{});
    try stdout.print("║  Comparing memory and performance at different sparsity levels               ║\n", .{});
    try stdout.print("║  φ² + 1/φ² = 3                                                               ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n\n", .{});

    const dimension: u32 = 10000;
    const densities = [_]f64{ 0.01, 0.05, 0.10, 0.20, 0.33 };

    try stdout.print("  Dimension: {d} trits\n", .{dimension});
    try stdout.print("  Iterations: {d}\n\n", .{ITERATIONS});

    // Memory comparison
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  MEMORY COMPARISON\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    const dense_bytes = dimension * @sizeOf(i8);
    try stdout.print("  Dense storage: {d} bytes\n\n", .{dense_bytes});

    try stdout.print("  ┌──────────┬──────────┬──────────┬──────────┬──────────┐\n", .{});
    try stdout.print("  │ Density  │ NNZ      │ Sparse   │ Savings  │ Breakeven│\n", .{});
    try stdout.print("  ├──────────┼──────────┼──────────┼──────────┼──────────┤\n", .{});

    for (densities) |density| {
        var sparse_vec = try SparseVector.random(allocator, dimension, density, 12345);
        defer sparse_vec.deinit();

        const sparse_bytes = sparse_vec.memoryBytes();
        const savings = sparse_vec.memorySavings();
        const nnz = sparse_vec.nnz();

        // Breakeven point: when sparse_bytes == dense_bytes
        // sparse_bytes = nnz * (4 + 1) + overhead ≈ nnz * 5
        // dense_bytes = dimension * 1
        // breakeven: nnz * 5 = dimension -> nnz/dimension = 0.2 (20% density)
        const breakeven = if (savings > 0) "Yes" else "No";

        try stdout.print("  │ {d:6.1}%  │ {d:8} │ {d:8} │ {d:7.1}% │ {s:8} │\n", .{
            density * 100,
            nnz,
            sparse_bytes,
            savings * 100,
            breakeven,
        });
    }

    try stdout.print("  └──────────┴──────────┴──────────┴──────────┴──────────┘\n\n", .{});

    // Performance comparison
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  PERFORMANCE COMPARISON (10% density)\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    const test_density: f64 = 0.10;

    // Create test vectors
    var sparse_a = try SparseVector.random(allocator, dimension, test_density, 11111);
    defer sparse_a.deinit();
    var sparse_b = try SparseVector.random(allocator, dimension, test_density, 22222);
    defer sparse_b.deinit();

    var dense_a = sparse_a.toDense();
    var dense_b = sparse_b.toDense();

    // Warmup
    for (0..WARMUP) |_| {
        var r1 = try SparseVector.bind(allocator, &sparse_a, &sparse_b);
        r1.deinit();
        _ = vsa.bind(&dense_a, &dense_b);
    }

    // BIND benchmark
    {
        // Sparse
        var timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            var result = try SparseVector.bind(allocator, &sparse_a, &sparse_b);
            std.mem.doNotOptimizeAway(&result);
            result.deinit();
        }
        const sparse_elapsed = timer.read();
        const sparse_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(sparse_elapsed)) / 1e9);

        // Dense
        timer = std.time.Timer.start() catch unreachable;
        for (0..ITERATIONS) |_| {
            var result = vsa.bind(&dense_a, &dense_b);
            std.mem.doNotOptimizeAway(&result);
        }
        const dense_elapsed = timer.read();
        const dense_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(dense_elapsed)) / 1e9);

        const speedup = sparse_ops / dense_ops;

        try stdout.print("  BIND:\n", .{});
        try stdout.print("    Sparse: {d:.0} ops/sec\n", .{sparse_ops});
        try stdout.print("    Dense:  {d:.0} ops/sec\n", .{dense_ops});
        try stdout.print("    Ratio:  {d:.2}x {s}\n\n", .{ if (speedup > 1) speedup else 1.0 / speedup, if (speedup > 1) "(sparse faster)" else "(dense faster)" });
    }

    // SIMILARITY benchmark
    {
        // Sparse
        var timer = std.time.Timer.start() catch unreachable;
        var sparse_result: f64 = undefined;
        for (0..ITERATIONS) |_| {
            sparse_result = SparseVector.cosineSimilarity(&sparse_a, &sparse_b);
            std.mem.doNotOptimizeAway(&sparse_result);
        }
        const sparse_elapsed = timer.read();
        const sparse_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(sparse_elapsed)) / 1e9);

        // Dense
        timer = std.time.Timer.start() catch unreachable;
        var dense_result: f64 = undefined;
        for (0..ITERATIONS) |_| {
            dense_result = vsa.cosineSimilarity(&dense_a, &dense_b);
            std.mem.doNotOptimizeAway(&dense_result);
        }
        const dense_elapsed = timer.read();
        const dense_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(dense_elapsed)) / 1e9);

        const speedup = sparse_ops / dense_ops;

        try stdout.print("  COSINE SIMILARITY:\n", .{});
        try stdout.print("    Sparse: {d:.0} ops/sec\n", .{sparse_ops});
        try stdout.print("    Dense:  {d:.0} ops/sec\n", .{dense_ops});
        try stdout.print("    Ratio:  {d:.2}x {s}\n\n", .{ if (speedup > 1) speedup else 1.0 / speedup, if (speedup > 1) "(sparse faster)" else "(dense faster)" });
    }

    // HAMMING benchmark
    {
        // Sparse
        var timer = std.time.Timer.start() catch unreachable;
        var sparse_result: usize = undefined;
        for (0..ITERATIONS) |_| {
            sparse_result = SparseVector.hammingDistance(&sparse_a, &sparse_b);
            std.mem.doNotOptimizeAway(&sparse_result);
        }
        const sparse_elapsed = timer.read();
        const sparse_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(sparse_elapsed)) / 1e9);

        // Dense
        timer = std.time.Timer.start() catch unreachable;
        var dense_result: usize = undefined;
        for (0..ITERATIONS) |_| {
            dense_result = vsa.hammingDistance(&dense_a, &dense_b);
            std.mem.doNotOptimizeAway(&dense_result);
        }
        const dense_elapsed = timer.read();
        const dense_ops = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(dense_elapsed)) / 1e9);

        const speedup = sparse_ops / dense_ops;

        try stdout.print("  HAMMING DISTANCE:\n", .{});
        try stdout.print("    Sparse: {d:.0} ops/sec\n", .{sparse_ops});
        try stdout.print("    Dense:  {d:.0} ops/sec\n", .{dense_ops});
        try stdout.print("    Ratio:  {d:.2}x {s}\n\n", .{ if (speedup > 1) speedup else 1.0 / speedup, if (speedup > 1) "(sparse faster)" else "(dense faster)" });
    }

    // Summary
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("  SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n\n", .{});

    try stdout.print("  WHEN TO USE SPARSE:\n", .{});
    try stdout.print("  ✓ Density < 20%% (memory savings)\n", .{});
    try stdout.print("  ✓ Bind operations (result is sparser)\n", .{});
    try stdout.print("  ✓ Memory-constrained environments\n", .{});
    try stdout.print("  ✓ Large dimensions (>10K)\n\n", .{});

    try stdout.print("  WHEN TO USE DENSE:\n", .{});
    try stdout.print("  ✓ Density > 20%%\n", .{});
    try stdout.print("  ✓ Bundle operations (result may be denser)\n", .{});
    try stdout.print("  ✓ SIMD acceleration needed\n", .{});
    try stdout.print("  ✓ Random access patterns\n\n", .{});

    try stdout.print("  φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL\n\n", .{});
}
