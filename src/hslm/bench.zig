// @origin(spec:bench.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Performance Benchmarks
// API defined in specs/tri/hslm_bench.tri
// Measures inference, ternary matmul, VSA attention, tokenizer, memory

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const tokenizer_mod = @import("tokenizer.zig");
const attention = @import("attention.zig");
const simd_ops = @import("simd_ops.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VSA_DIM = constants.VSA_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const NUM_BLOCKS = constants.NUM_BLOCKS;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCH RESULT (from specs/tri/hslm_bench.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchResult = struct {
    name: []const u8,
    ops_per_sec: f64,
    latency_us: f64,
    memory_kb: usize,
    params: usize,
};

pub const ComparisonRow = struct {
    model_name: []const u8,
    inference_ms: f64,
    memory_kb: usize,
    params: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

/// Benchmark forward pass latency
pub fn benchForwardPass(model: *model_mod.HSLM, iterations: usize) BenchResult {
    const tokens = [_]u16{ 1, 42, 100, 200, 50, 75, 120, 300 };
    var logits: [VOCAB_SIZE]f32 = undefined;

    const timer = std.time.Timer{ .started = std.time.Instant.now() catch unreachable };
    _ = timer;

    var total_ns: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        model.forward(&tokens, &logits);
        const end = std.time.nanoTimestamp();
        total_ns +%= @intCast(end - start);
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const ops = 1_000_000.0 / avg_us;

    return BenchResult{
        .name = "forward_pass",
        .ops_per_sec = ops,
        .latency_us = avg_us,
        .memory_kb = memoryUsage(),
        .params = constants.ESTIMATED_PARAMS,
    };
}

/// Benchmark ternary matmul (the core operation)
pub fn benchTernaryMatmul(iterations: usize) BenchResult {
    var input: [EMBED_DIM]f32 = undefined;
    var output: [HIDDEN_DIM]f32 = undefined;
    var weights: [EMBED_DIM * HIDDEN_DIM]i8 = undefined;

    // Fill with random data
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 2.0 - 1.0;
    for (&weights) |*w| w.* = rng.intRangeAtMost(i8, -1, 1);

    var total_ns: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        ternaryMatvec(&input, &weights, &output, EMBED_DIM, HIDDEN_DIM);
        const end = std.time.nanoTimestamp();
        total_ns +%= @intCast(end - start);
        std.mem.doNotOptimizeAway(&output);
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    // ops = EMBED_DIM * HIDDEN_DIM additions per matmul
    const flops = @as(f64, @floatFromInt(EMBED_DIM * HIDDEN_DIM));
    const ops = flops / (avg_us / 1_000_000.0);

    return BenchResult{
        .name = "ternary_matmul",
        .ops_per_sec = ops,
        .latency_us = avg_us,
        .memory_kb = (EMBED_DIM * HIDDEN_DIM) / 1024, // 1 byte per weight
        .params = EMBED_DIM * HIDDEN_DIM,
    };
}

/// Benchmark SIMD ternary matmul (optimized operation)
pub fn benchTernaryMatmulSimd(iterations: usize) BenchResult {
    var input: [EMBED_DIM]f32 = undefined;
    var output: [HIDDEN_DIM]f32 = undefined;
    var weights: [EMBED_DIM * HIDDEN_DIM]i8 = undefined;

    // Fill with random data (same seed as scalar for fair comparison)
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 2.0 - 1.0;
    for (&weights) |*w| w.* = rng.intRangeAtMost(i8, -1, 1);

    var total_ns: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        simd_ops.ternaryMatvecSimd(&input, &weights, &output, EMBED_DIM, HIDDEN_DIM);
        const end = std.time.nanoTimestamp();
        total_ns +%= @intCast(end - start);
        std.mem.doNotOptimizeAway(&output);
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const flops = @as(f64, @floatFromInt(EMBED_DIM * HIDDEN_DIM));
    const ops = flops / (avg_us / 1_000_000.0);

    return BenchResult{
        .name = "ternary_matmul_simd",
        .ops_per_sec = ops,
        .latency_us = avg_us,
        .memory_kb = (EMBED_DIM * HIDDEN_DIM) / 1024,
        .params = EMBED_DIM * HIDDEN_DIM,
    };
}

/// Benchmark VSA attention (cosine similarity + bundle)
pub fn benchVSAAttention(iterations: usize) BenchResult {
    var query: [VSA_DIM]i8 = undefined;
    var keys: [CONTEXT_LEN * VSA_DIM]i8 = undefined;

    var prng = std.Random.DefaultPrng.init(123);
    const rng = prng.random();
    for (&query) |*v| v.* = rng.intRangeAtMost(i8, -1, 1);
    for (&keys) |*v| v.* = rng.intRangeAtMost(i8, -1, 1);

    var total_ns: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        // Compute similarity with all keys
        for (0..CONTEXT_LEN) |i| {
            const key = keys[i * VSA_DIM .. (i + 1) * VSA_DIM];
            const sim = attention.cosineSimilarityTrit(&query, key);
            std.mem.doNotOptimizeAway(&sim);
        }
        const end = std.time.nanoTimestamp();
        total_ns +%= @intCast(end - start);
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const sims_per_sec = @as(f64, @floatFromInt(CONTEXT_LEN)) * 1_000_000.0 / avg_us;

    return BenchResult{
        .name = "vsa_attention",
        .ops_per_sec = sims_per_sec,
        .latency_us = avg_us,
        .memory_kb = (CONTEXT_LEN * VSA_DIM) / 1024,
        .params = 0,
    };
}

/// Benchmark tokenizer throughput
pub fn benchTokenizer(allocator: std.mem.Allocator, iterations: usize) BenchResult {
    var tok = tokenizer_mod.Tokenizer.init(allocator) catch return BenchResult{
        .name = "tokenizer",
        .ops_per_sec = 0,
        .latency_us = 0,
        .memory_kb = 0,
        .params = 0,
    };
    defer tok.deinit();

    const text = "The quick brown fox jumps over the lazy dog. A simple test sentence for benchmarking the HSLM tokenizer.";
    var tokens: [256]u16 = undefined;
    var decoded: [512]u8 = undefined;

    var total_ns: u64 = 0;
    var total_tokens: u64 = 0;
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        const n = tok.encode(text, &tokens);
        _ = tok.decode(tokens[0..n], &decoded);
        const end = std.time.nanoTimestamp();
        total_ns +%= @intCast(end - start);
        total_tokens += n;
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    const tps = @as(f64, @floatFromInt(total_tokens)) * 1_000_000_000.0 / @as(f64, @floatFromInt(total_ns));

    return BenchResult{
        .name = "tokenizer",
        .ops_per_sec = tps,
        .latency_us = avg_us,
        .memory_kb = 4, // Small overhead
        .params = VOCAB_SIZE,
    };
}

/// Memory breakdown
pub fn memoryUsage() usize {
    // Ternary weights: 1.58 bits per param
    const weight_bits = constants.ESTIMATED_PARAMS * 158 / 100;
    const weight_kb = weight_bits / 8 / 1024;

    // Embeddings: float (VOCAB × EMBED) + trit (VOCAB × VSA)
    const embed_float_kb = (VOCAB_SIZE * EMBED_DIM * 4) / 1024;
    const embed_trit_kb = (VOCAB_SIZE * VSA_DIM) / 1024;

    // Position encodings
    const pos_kb = (CONTEXT_LEN * EMBED_DIM * 4) / 1024;

    return weight_kb + embed_float_kb + embed_trit_kb + pos_kb;
}

/// Generate comparison table
pub fn compareWithBitNet() [2]ComparisonRow {
    const hslm_mem = memoryUsage();
    return [2]ComparisonRow{
        .{
            .model_name = "HSLM (ours)",
            .inference_ms = 0.0, // Filled by bench
            .memory_kb = hslm_mem,
            .params = constants.ESTIMATED_PARAMS,
        },
        .{
            .model_name = "BitNet b1.58 (equiv.)",
            .inference_ms = 0.0, // Reference: same param count
            .memory_kb = constants.ESTIMATED_PARAMS * 2 / 8 / 1024, // 2 bits per weight
            .params = constants.ESTIMATED_PARAMS,
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn ternaryMatvec(input: []const f32, weights: []const i8, output: []f32, in_dim: usize, out_dim: usize) void {
    for (0..out_dim) |j| {
        var sum: f32 = 0.0;
        for (0..in_dim) |i| {
            const w = weights[i * out_dim + j];
            if (w == 1) {
                sum += input[i];
            } else if (w == -1) {
                sum -= input[i];
            }
        }
        output[j] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "memory usage reasonable" {
    const mem = memoryUsage();
    // Should be under 2MB for 1.24M params
    try std.testing.expect(mem > 100); // > 100KB
    try std.testing.expect(mem < 2048); // < 2MB
}

test "comparison table" {
    const rows = compareWithBitNet();
    try std.testing.expectEqualStrings("HSLM (ours)", rows[0].model_name);
    try std.testing.expectEqualStrings("BitNet b1.58 (equiv.)", rows[1].model_name);
    try std.testing.expect(rows[0].params == constants.ESTIMATED_PARAMS);
}

test "bench ternary matmul runs" {
    const result = benchTernaryMatmul(10);
    try std.testing.expect(result.ops_per_sec > 0);
    try std.testing.expect(result.latency_us > 0);
}

test "bench vsa attention runs" {
    const result = benchVSAAttention(10);
    try std.testing.expect(result.ops_per_sec > 0);
}

test "bench tokenizer runs" {
    const allocator = std.testing.allocator;
    const result = benchTokenizer(allocator, 10);
    try std.testing.expect(result.ops_per_sec > 0);
}
