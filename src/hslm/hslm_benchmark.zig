// @origin(spec:hslm_benchmark.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM Platform Benchmark Suite
// Standalone executable for arXiv paper Evaluation section
// Measures: single-thread, multi-thread inference, ternary matmul, platform comparison
//
// NOTE: model.zig uses 3 TrinityBlocks, FPGA uses 4 TrinityBlocks
//       Table notes configuration explicitly for paper honesty

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const tokenizer_mod = @import("tokenizer.zig");
const bench = @import("bench.zig");
const simd_ops = @import("simd_ops.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const NUM_BLOCKS = constants.NUM_BLOCKS;

const WARMUP_ITERS = 50;
const BENCH_ITERS = 1000;
const MATMUL_ITERS = 100_000;

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const allocator = std.heap.page_allocator;

    try stdout.print("\n", .{});
    try printHeader(stdout);

    // Part 1: Single-thread forward pass
    const single = try benchSingleThread(allocator, stdout);

    // Part 2: Multi-thread inference
    const multi = try benchMultiThread(allocator, stdout);

    // Part 3: Ternary matmul bandwidth
    try benchMatmul(stdout);

    // Part 4: Memory usage
    try printMemory(stdout);

    // Part 5: Platform comparison table
    try printPlatformTable(stdout, single, multi);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

fn printHeader(writer: anytype) !void {
    try writer.print("==============================================================\n", .{});
    try writer.print("  HSLM Inference Benchmark Suite\n", .{});
    try writer.print("  {d}x TrinityBlock, ~{d:.2}M ternary params, dim={d}/{d}\n", .{
        NUM_BLOCKS,
        @as(f64, @floatFromInt(constants.ESTIMATED_PARAMS)) / 1_000_000.0,
        EMBED_DIM,
        HIDDEN_DIM,
    });
    try writer.print("  Vocab={d}, Context={d}, Iterations={d}\n", .{
        VOCAB_SIZE,
        constants.CONTEXT_LEN,
        BENCH_ITERS,
    });
    try writer.print("==============================================================\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PART 1: SINGLE-THREAD FORWARD PASS
// ═══════════════════════════════════════════════════════════════════════════════

const LatencyStats = struct {
    min_us: f64,
    avg_us: f64,
    max_us: f64,
    throughput_tok_s: f64,
};

fn benchSingleThread(allocator: std.mem.Allocator, writer: anytype) !LatencyStats {
    try writer.print("[1/4] Single-thread forward pass\n", .{});
    try writer.print("      Initializing HSLM model... ", .{});

    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    try writer.print("OK\n", .{});

    // Sample tokens (BOS + content)
    const tokens = [_]u16{ 1, 42, 100, 200, 50, 75, 120, 300 };
    const seq_len = tokens.len;
    var logits: [VOCAB_SIZE]f32 = undefined;

    // Warmup
    try writer.print("      Warmup ({d} iters)... ", .{WARMUP_ITERS});
    for (0..WARMUP_ITERS) |_| {
        model.forward(&tokens, &logits);
    }
    try writer.print("OK\n", .{});

    // Benchmark
    try writer.print("      Benchmarking ({d} iters)... ", .{BENCH_ITERS});

    var min_ns: i128 = std.math.maxInt(i128);
    var max_ns: i128 = 0;
    var total_ns: i128 = 0;

    for (0..BENCH_ITERS) |_| {
        const start = std.time.nanoTimestamp();
        model.forward(&tokens, &logits);
        const end = std.time.nanoTimestamp();
        const elapsed = end - start;
        total_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    const avg_ns = @divTrunc(total_ns, BENCH_ITERS);
    const min_us = @as(f64, @floatFromInt(min_ns)) / 1000.0;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const max_us = @as(f64, @floatFromInt(max_ns)) / 1000.0;
    const avg_ms = avg_us / 1000.0;
    const throughput = @as(f64, @floatFromInt(seq_len)) / (avg_us / 1_000_000.0);

    try writer.print("DONE\n", .{});
    try writer.print("      ┌─────────────────────────────────────────────┐\n", .{});
    try writer.print("      │ Min: {d:>10.1} us                          │\n", .{min_us});
    try writer.print("      │ Avg: {d:>10.1} us ({d:.2} ms)              │\n", .{ avg_us, avg_ms });
    try writer.print("      │ Max: {d:>10.1} us                          │\n", .{max_us});
    try writer.print("      │ Throughput: {d:>8.1} tok/s                 │\n", .{throughput});
    try writer.print("      └─────────────────────────────────────────────┘\n\n", .{});

    return LatencyStats{
        .min_us = min_us,
        .avg_us = avg_us,
        .max_us = max_us,
        .throughput_tok_s = throughput,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PART 2: MULTI-THREAD INFERENCE
// ═══════════════════════════════════════════════════════════════════════════════

const WorkerContext = struct {
    allocator: std.mem.Allocator,
    iterations: usize,
    done: bool = false,
    elapsed_ns: i128 = 0,
    err: bool = false,
};

fn workerFn(ctx: *WorkerContext) void {
    var model = model_mod.HSLM.init(ctx.allocator) catch {
        ctx.err = true;
        ctx.done = true;
        return;
    };
    defer model.deinit();

    const tokens = [_]u16{ 1, 42, 100, 200, 50, 75, 120, 300 };
    var logits: [VOCAB_SIZE]f32 = undefined;

    const start = std.time.nanoTimestamp();
    for (0..ctx.iterations) |_| {
        model.forward(&tokens, &logits);
    }
    const end = std.time.nanoTimestamp();

    ctx.elapsed_ns = end - start;
    ctx.done = true;
}

fn benchMultiThread(allocator: std.mem.Allocator, writer: anytype) !LatencyStats {
    const cpu_count: usize = std.Thread.getCpuCount() catch 1;
    const n_threads: usize = @min(cpu_count, 8); // Cap at 8

    try writer.print("[2/4] Multi-thread inference ({d} threads)\n", .{n_threads});

    const iters_per_thread: usize = BENCH_ITERS / n_threads;

    var contexts: [8]WorkerContext = undefined;
    var threads: [8]std.Thread = undefined;

    // Warmup single pass per thread happens inside worker

    const wall_start = std.time.nanoTimestamp();

    for (0..n_threads) |i| {
        contexts[i] = WorkerContext{
            .allocator = allocator,
            .iterations = iters_per_thread,
        };
        threads[i] = try std.Thread.spawn(.{}, workerFn, .{&contexts[i]});
    }

    for (0..n_threads) |i| {
        threads[i].join();
    }

    const wall_end = std.time.nanoTimestamp();
    const wall_ns = wall_end - wall_start;

    // Check for errors
    var any_err = false;
    for (0..n_threads) |i| {
        if (contexts[i].err) any_err = true;
    }
    if (any_err) {
        try writer.print("      ERROR: Some worker threads failed\n\n", .{});
        return LatencyStats{ .min_us = 0, .avg_us = 0, .max_us = 0, .throughput_tok_s = 0 };
    }

    const total_inferences = n_threads * iters_per_thread;
    const tokens_per_inference: usize = 8;
    const total_tokens = total_inferences * tokens_per_inference;
    const wall_us = @as(f64, @floatFromInt(wall_ns)) / 1000.0;
    const wall_ms = wall_us / 1000.0;
    const effective_throughput = @as(f64, @floatFromInt(total_tokens)) / (wall_us / 1_000_000.0);
    const avg_latency_us = wall_us / @as(f64, @floatFromInt(total_inferences));

    try writer.print("      ┌─────────────────────────────────────────────┐\n", .{});
    try writer.print("      │ Threads: {d}                                │\n", .{n_threads});
    try writer.print("      │ Total inferences: {d}                       │\n", .{total_inferences});
    try writer.print("      │ Wall time: {d:.1} ms                        │\n", .{wall_ms});
    try writer.print("      │ Avg latency: {d:.1} us/inference            │\n", .{avg_latency_us});
    try writer.print("      │ Effective throughput: {d:.1} tok/s           │\n", .{effective_throughput});
    try writer.print("      └─────────────────────────────────────────────┘\n\n", .{});

    return LatencyStats{
        .min_us = avg_latency_us,
        .avg_us = avg_latency_us,
        .max_us = avg_latency_us,
        .throughput_tok_s = effective_throughput,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PART 3: TERNARY MATMUL BANDWIDTH
// ═══════════════════════════════════════════════════════════════════════════════

fn benchMatmul(writer: anytype) !void {
    try writer.print("[3/4] Ternary MatVec {d}x{d}\n", .{ EMBED_DIM, HIDDEN_DIM });

    const scalar = bench.benchTernaryMatmul(MATMUL_ITERS);
    const simd = bench.benchTernaryMatmulSimd(MATMUL_ITERS);

    const scalar_ns = scalar.latency_us * 1000.0;
    const simd_ns = simd.latency_us * 1000.0;
    const speedup = if (simd_ns > 0) scalar_ns / simd_ns else 0.0;

    try writer.print("      ┌─────────────────────────────────────────────┐\n", .{});
    try writer.print("      │ Scalar: {d:>8.1} ns/op  ({d:.2} GOPS)      │\n", .{ scalar_ns, scalar.ops_per_sec / 1e9 });
    try writer.print("      │ SIMD:   {d:>8.1} ns/op  ({d:.2} GOPS)      │\n", .{ simd_ns, simd.ops_per_sec / 1e9 });
    try writer.print("      │ Speedup: {d:.2}x                            │\n", .{speedup});
    try writer.print("      └─────────────────────────────────────────────┘\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PART 4: MEMORY USAGE
// ═══════════════════════════════════════════════════════════════════════════════

fn printMemory(writer: anytype) !void {
    const mem_kb = bench.memoryUsage();
    const float32_kb = constants.ESTIMATED_PARAMS * 4 / 1024;
    const ratio = @as(f64, @floatFromInt(float32_kb)) / @as(f64, @floatFromInt(if (mem_kb > 0) mem_kb else 1));

    try writer.print("      ┌─────────────────────────────────────────────┐\n", .{});
    try writer.print("      │ Ternary (1.58 bit/param): {d:>6} KB          │\n", .{mem_kb});
    try writer.print("      │ Float32 equivalent:       {d:>6} KB          │\n", .{float32_kb});
    try writer.print("      │ Compression ratio:        {d:>6.1}x           │\n", .{ratio});
    try writer.print("      │ Parameters:          {d:>10}             │\n", .{constants.ESTIMATED_PARAMS});
    try writer.print("      └─────────────────────────────────────────────┘\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PART 5: PLATFORM COMPARISON TABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn printPlatformTable(writer: anytype, single: LatencyStats, multi: LatencyStats) !void {
    const single_ms = single.avg_us / 1000.0;
    const multi_ms = multi.avg_us / 1000.0;
    // Railway estimate: ~2x slower than M1 Pro single-thread (shared vCPU)
    const railway_ms = single_ms * 2.0;
    const railway_throughput = single.throughput_tok_s / 2.0;

    try writer.print("==============================================================\n", .{});
    try writer.print("  HSLM Platform Comparison (for arXiv paper)\n", .{});
    try writer.print("==============================================================\n", .{});
    try writer.print("  Platform               Latency    Throughput  Power   Cost\n", .{});
    try writer.print("  --------------------   --------   ----------  -----   ------\n", .{});
    try writer.print("  M1 Pro (1-thread)*     {d:>7.2} ms  {d:>6.0} tok/s   15W    $0/hr\n", .{ single_ms, single.throughput_tok_s });
    try writer.print("  M1 Pro ({d}-thread)*    {d:>7.2} ms  {d:>6.0} tok/s   20W    $0/hr\n", .{ std.Thread.getCpuCount() catch 1, multi_ms, multi.throughput_tok_s });
    try writer.print("  FPGA Artix-7**          28.50 ms      35 tok/s  0.5W   $0/hr\n", .{});
    try writer.print("  Railway CPU (est)***   {d:>7.2} ms  {d:>6.0} tok/s    ?W   $0.02/hr\n", .{ railway_ms, railway_throughput });
    try writer.print("  --------------------   --------   ----------  -----   ------\n", .{});
    try writer.print("\n", .{});
    try writer.print("  *   CPU config: {d}x TrinityBlock, {d:.2}M params\n", .{
        NUM_BLOCKS,
        @as(f64, @floatFromInt(constants.ESTIMATED_PARAMS)) / 1_000_000.0,
    });
    try writer.print("  **  FPGA config: 4x TrinityBlock, measured on Artix-7 XC7A35T\n", .{});
    try writer.print("  *** Railway estimate: 2x single-thread latency (shared vCPU)\n", .{});
    try writer.print("==============================================================\n", .{});
}
