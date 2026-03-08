// SIMD BENCHMARK - and withtowithand and and
// innotand withto and SIMD and
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");
const engine = @import("trinity_inference_engine.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const WARMUP_ITERATIONS = 10;
const BENCHMARK_ITERATIONS = 100;

//  for to (and for LLM)
const BATCH_SIZE = 1;
const IN_FEATURES = 4096; // hidden_size
const OUT_FEATURES = 4096; // hidden_size

// ═══════════════════════════════════════════════════════════════════════════════
// SCALAR IMPLEMENTATION (BASELINE)
// ═══════════════════════════════════════════════════════════════════════════════

/// toon and - in and for withinnotand
pub fn scalarMatmul(
    output: []f32,
    input: []const f32,
    weights: []const prometheus.TritWeight,
    in_features: usize,
    out_features: usize,
) void {
    @memset(output, 0.0);

    for (0..out_features) |o| {
        var sum: f32 = 0.0;
        const weight_offset = o * in_features;

        for (0..in_features) |i| {
            const w = weights[weight_offset + i];
            const x = input[i];

            switch (w) {
                .pos => sum += x,
                .neg => sum -= x,
                .zero => {},
            }
        }

        output[o] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD IMPLEMENTATION - AVX2 (256-bit vectors)
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD vector 8 x f32 = 256 and (AVX2)
const Vec8f = @Vector(8, f32);

/// SIMD vector 32 x i8 = 256 and (for andin)
const Vec32i8 = @Vector(32, i8);

/// inand andin in i8 array for SIMD
fn tritsToI8(trits: []const prometheus.TritWeight, out: []i8) void {
    for (trits, 0..) |t, i| {
        out[i] = t.toInt();
    }
}

/// SIMD-andandin and and
/// Processes 8 login onand
pub fn simdMatmul(
    output: []f32,
    input: []const f32,
    weights: []const prometheus.TritWeight,
    in_features: usize,
    out_features: usize,
    trit_buffer: []i8,
) void {
    @memset(output, 0.0);

    // inand and in i8 and
    for (weights, 0..) |w, i| {
        trit_buffer[i] = w.toInt();
    }

    for (0..out_features) |o| {
        var sum_vec: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const weight_offset = o * in_features;

        // in by 8 elementin
        var i: usize = 0;
        while (i + 8 <= in_features) : (i += 8) {
            //  8 login onand
            const input_vec: Vec8f = input[i..][0..8].*;

            //  8 andin and toinand in f32
            const t0: f32 = @floatFromInt(trit_buffer[weight_offset + i + 0]);
            const t1: f32 = @floatFromInt(trit_buffer[weight_offset + i + 1]);
            const t2: f32 = @floatFromInt(trit_buffer[weight_offset + i + 2]);
            const t3: f32 = @floatFromInt(trit_buffer[weight_offset + i + 3]);
            const t4: f32 = @floatFromInt(trit_buffer[weight_offset + i + 4]);
            const t5: f32 = @floatFromInt(trit_buffer[weight_offset + i + 5]);
            const t6: f32 = @floatFromInt(trit_buffer[weight_offset + i + 6]);
            const t7: f32 = @floatFromInt(trit_buffer[weight_offset + i + 7]);

            const trit_vec: Vec8f = .{ t0, t1, t2, t3, t4, t5, t6, t7 };

            // SIMD and and ontoand
            //  andin {-1, 0, +1} this toinandin:
            // +1: beforeinand x
            // -1: inwith x
            //  0: and
            sum_vec += input_vec * trit_vec;
        }

        // andon with SIMD into
        const sum_arr: [8]f32 = sum_vec;
        for (sum_arr) |v| {
            sum_scalar += v;
        }

        // withto (withto)
        while (i < in_features) : (i += 1) {
            const w = trit_buffer[weight_offset + i];
            const x = input[i];
            sum_scalar += x * @as(f32, @floatFromInt(w));
        }

        output[o] = sum_scalar;
    }
}

/// SIMD  and - to withand/inand via withtoand
pub fn simdMatmulNoMul(
    output: []f32,
    input: []const f32,
    weights: []const prometheus.TritWeight,
    in_features: usize,
    out_features: usize,
    trit_buffer: []i8,
) void {
    @memset(output, 0.0);

    // inand and in i8
    for (weights, 0..) |w, i| {
        trit_buffer[i] = w.toInt();
    }

    for (0..out_features) |o| {
        var pos_sum: Vec8f = @splat(0.0);
        var neg_sum: Vec8f = @splat(0.0);
        var pos_scalar: f32 = 0.0;
        var neg_scalar: f32 = 0.0;
        const weight_offset = o * in_features;

        var i: usize = 0;
        while (i + 8 <= in_features) : (i += 8) {
            const input_vec: Vec8f = input[i..][0..8].*;

            // yes withtoand for byand and fromand andin
            const t = trit_buffer[weight_offset + i ..][0..8];

            // withto byand (t == 1)
            const pos_mask: @Vector(8, bool) = .{
                t[0] == 1, t[1] == 1, t[2] == 1, t[3] == 1,
                t[4] == 1, t[5] == 1, t[6] == 1, t[7] == 1,
            };

            // withto fromand (t == -1)
            const neg_mask: @Vector(8, bool) = .{
                t[0] == -1, t[1] == -1, t[2] == -1, t[3] == -1,
                t[4] == -1, t[5] == -1, t[6] == -1, t[7] == -1,
            };

            // and withtoand
            const zeros: Vec8f = @splat(0.0);
            pos_sum += @select(f32, pos_mask, input_vec, zeros);
            neg_sum += @select(f32, neg_mask, input_vec, zeros);
        }

        // and with
        const pos_arr: [8]f32 = pos_sum;
        const neg_arr: [8]f32 = neg_sum;
        for (pos_arr) |v| pos_scalar += v;
        for (neg_arr) |v| neg_scalar += v;

        // withto
        while (i < in_features) : (i += 1) {
            const w = trit_buffer[weight_offset + i];
            const x = input[i];
            if (w == 1) pos_scalar += x else if (w == -1) neg_scalar += x;
        }

        output[o] = pos_scalar - neg_scalar;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY SIMD BENCHMARK                             ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Matrix size: {d} x {d}                                    ║\n", .{ IN_FEATURES, OUT_FEATURES });
    std.debug.print("║ Total weights: {d:>10}                                   ║\n", .{IN_FEATURES * OUT_FEATURES});
    std.debug.print("║ Iterations: {d}                                             ║\n", .{BENCHMARK_ITERATIONS});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Allocate buffers
    const input = try allocator.alloc(f32, IN_FEATURES);
    defer allocator.free(input);

    const weights = try allocator.alloc(prometheus.TritWeight, IN_FEATURES * OUT_FEATURES);
    defer allocator.free(weights);

    const output = try allocator.alloc(f32, OUT_FEATURES);
    defer allocator.free(output);

    const trit_buffer = try allocator.alloc(i8, IN_FEATURES * OUT_FEATURES);
    defer allocator.free(trit_buffer);

    // Initialize with random data
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    for (input) |*x| {
        x.* = random.float(f32) * 2.0 - 1.0;
    }

    for (weights) |*w| {
        const r = random.int(u8) % 3;
        w.* = switch (r) {
            0 => .neg,
            1 => .zero,
            else => .pos,
        };
    }

    // Warmup
    std.debug.print("\nWarming up...\n", .{});
    for (0..WARMUP_ITERATIONS) |_| {
        scalarMatmul(output, input, weights, IN_FEATURES, OUT_FEATURES);
    }

    // Benchmark scalar
    std.debug.print("Benchmarking scalar...\n", .{});
    var timer = try std.time.Timer.start();

    for (0..BENCHMARK_ITERATIONS) |_| {
        scalarMatmul(output, input, weights, IN_FEATURES, OUT_FEATURES);
    }

    const scalar_ns = timer.read();
    const scalar_ms = @as(f64, @floatFromInt(scalar_ns)) / 1_000_000.0;
    const scalar_per_iter = scalar_ms / @as(f64, BENCHMARK_ITERATIONS);

    // Benchmark SIMD with multiply
    std.debug.print("Benchmarking SIMD (with multiply)...\n", .{});
    timer.reset();

    for (0..BENCHMARK_ITERATIONS) |_| {
        simdMatmul(output, input, weights, IN_FEATURES, OUT_FEATURES, trit_buffer);
    }

    const simd_mul_ns = timer.read();
    const simd_mul_ms = @as(f64, @floatFromInt(simd_mul_ns)) / 1_000_000.0;
    const simd_mul_per_iter = simd_mul_ms / @as(f64, BENCHMARK_ITERATIONS);

    // Benchmark SIMD without multiply
    std.debug.print("Benchmarking SIMD (no multiply)...\n", .{});
    timer.reset();

    for (0..BENCHMARK_ITERATIONS) |_| {
        simdMatmulNoMul(output, input, weights, IN_FEATURES, OUT_FEATURES, trit_buffer);
    }

    const simd_nomul_ns = timer.read();
    const simd_nomul_ms = @as(f64, @floatFromInt(simd_nomul_ns)) / 1_000_000.0;
    const simd_nomul_per_iter = simd_nomul_ms / @as(f64, BENCHMARK_ITERATIONS);

    // Calculate GFLOPS equivalent
    const ops_per_matmul: f64 = @floatFromInt(IN_FEATURES * OUT_FEATURES * 2); // add + potential sub
    const scalar_gops = ops_per_matmul / (scalar_per_iter * 1_000_000.0);
    const simd_mul_gops = ops_per_matmul / (simd_mul_per_iter * 1_000_000.0);
    const simd_nomul_gops = ops_per_matmul / (simd_nomul_per_iter * 1_000_000.0);

    // Print results
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           BENCHMARK RESULTS                                  ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ SCALAR:                                                      ║\n", .{});
    std.debug.print("║   Total time:     {d:>10.2} ms                              ║\n", .{scalar_ms});
    std.debug.print("║   Per iteration:  {d:>10.4} ms                              ║\n", .{scalar_per_iter});
    std.debug.print("║   Throughput:     {d:>10.2} GOP/s                           ║\n", .{scalar_gops});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ SIMD (with multiply):                                        ║\n", .{});
    std.debug.print("║   Total time:     {d:>10.2} ms                              ║\n", .{simd_mul_ms});
    std.debug.print("║   Per iteration:  {d:>10.4} ms                              ║\n", .{simd_mul_per_iter});
    std.debug.print("║   Throughput:     {d:>10.2} GOP/s                           ║\n", .{simd_mul_gops});
    std.debug.print("║   Speedup:        {d:>10.2}x                                ║\n", .{scalar_per_iter / simd_mul_per_iter});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ SIMD (no multiply - masks):                                  ║\n", .{});
    std.debug.print("║   Total time:     {d:>10.2} ms                              ║\n", .{simd_nomul_ms});
    std.debug.print("║   Per iteration:  {d:>10.4} ms                              ║\n", .{simd_nomul_per_iter});
    std.debug.print("║   Throughput:     {d:>10.2} GOP/s                           ║\n", .{simd_nomul_gops});
    std.debug.print("║   Speedup:        {d:>10.2}x                                ║\n", .{scalar_per_iter / simd_nomul_per_iter});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Verify correctness
    std.debug.print("\nVerifying correctness...\n", .{});

    const scalar_output = try allocator.alloc(f32, OUT_FEATURES);
    defer allocator.free(scalar_output);
    const simd_output = try allocator.alloc(f32, OUT_FEATURES);
    defer allocator.free(simd_output);

    scalarMatmul(scalar_output, input, weights, IN_FEATURES, OUT_FEATURES);
    simdMatmul(simd_output, input, weights, IN_FEATURES, OUT_FEATURES, trit_buffer);

    var max_diff: f32 = 0.0;
    for (scalar_output, simd_output) |s, m| {
        const diff = @abs(s - m);
        if (diff > max_diff) max_diff = diff;
    }

    std.debug.print("Max difference: {d:.6}\n", .{max_diff});
    if (max_diff < 0.001) {
        std.debug.print("✅ Results match!\n", .{});
    } else {
        std.debug.print("❌ Results differ!\n", .{});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runBenchmark(gpa.allocator());
}

test "simd benchmark" {
    try runBenchmark(std.testing.allocator);
}
