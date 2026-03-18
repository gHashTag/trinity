// @origin(spec:simd_ops.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — SIMD Ternary Operations
// Vectorized ternary matmul using @Vector(8, f32) with 4x unrolling.
// 8 × f32 = 256-bit = native AVX2 on x86, NEON on ARM.
// 4x unroll processes 32 elements/iter → reduces loop overhead, better pipelining.
// Key insight: {-1,0,+1} * val = {-val, 0, val} — branchless via fmla

const std = @import("std");

const VEC_SIZE = 8;
const UNROLL = 4;
const BLOCK = VEC_SIZE * UNROLL; // 32 elements per iteration
const Vec8 = @Vector(VEC_SIZE, f32);
const Vec8i = @Vector(VEC_SIZE, i8);
const Vec8i16 = @Vector(VEC_SIZE, i16);
const zero_vec: Vec8 = @splat(0.0);

// ═══════════════════════════════════════════════════════════════════════════════
// FORWARD: y[j] = Sum_i W[i*out_dim+j] * x[i]
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD ternary matrix-vector multiply (forward).
/// Scatter pattern: outer=input i (broadcast), inner=output j (SIMD 8-wide × 4 unroll).
/// Weight layout: row-major W[i * out_dim + j], contiguous in j for fixed i.
/// 4x unroll: processes 32 elements/iter, reduces loop overhead ~4x.
pub fn ternaryMatvecSimd(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    // Zero output accumulator
    @memset(output[0..out_dim], 0.0);

    for (0..in_dim) |i| {
        const val = input[i];
        if (val == 0.0) continue; // Skip zero inputs (common in ReLU'd activations)
        const val_vec: Vec8 = @splat(val);
        const w_base = i * out_dim;

        // 4x unrolled loop: 32 elements per iteration
        var j: usize = 0;
        while (j + BLOCK <= out_dim) : (j += BLOCK) {
            inline for (0..UNROLL) |u| {
                const off = j + u * VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                var out_vec: Vec8 = output[off..][0..VEC_SIZE].*;
                out_vec += w_f32 * val_vec;
                output[off..][0..VEC_SIZE].* = out_vec;
            }
        }
        // Tail: remaining 8-wide chunks
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
            var out_vec: Vec8 = output[j..][0..VEC_SIZE].*;
            out_vec += w_f32 * val_vec;
            output[j..][0..VEC_SIZE].* = out_vec;
        }
        // Scalar remainder (243%8=3, 729%8=1)
        while (j < out_dim) : (j += 1) {
            const w = weights[w_base + j];
            if (w == 1) {
                output[j] += val;
            } else if (w == -1) {
                output[j] -= val;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKWARD INPUT GRAD: g_in[i] = Sum_j W[i*out_dim+j] * g_out[j]
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD ternary vector-matrix multiply (backward input gradient).
/// Gather pattern: for each row i, dot product of weight row with grad_output.
/// Both W[i*out+j..j+8] and grad_output[j..j+8] are contiguous.
/// 4x unroll: 4 independent accumulators reduce data dependency stalls.
pub fn ternaryVecmatSimd(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        // 4 independent accumulators — better instruction pipelining
        var acc0: Vec8 = zero_vec;
        var acc1: Vec8 = zero_vec;
        var acc2: Vec8 = zero_vec;
        var acc3: Vec8 = zero_vec;
        var j: usize = 0;
        while (j + BLOCK <= out_dim) : (j += BLOCK) {
            {
                const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
            }
            {
                const off = j + VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc1 += w_f32 * @as(Vec8, grad_output[off..][0..VEC_SIZE].*);
            }
            {
                const off = j + 2 * VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc2 += w_f32 * @as(Vec8, grad_output[off..][0..VEC_SIZE].*);
            }
            {
                const off = j + 3 * VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc3 += w_f32 * @as(Vec8, grad_output[off..][0..VEC_SIZE].*);
            }
        }
        // Tail: remaining 8-wide chunks
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
            acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
        }
        // Merge 4 accumulators → single sum
        const merged = acc0 + acc1 + acc2 + acc3;
        var sum: f32 = @reduce(.Add, merged);
        // Scalar remainder
        while (j < out_dim) : (j += 1) {
            const w = weights[w_base + j];
            if (w == 1) {
                sum += grad_output[j];
            } else if (w == -1) {
                sum -= grad_output[j];
            }
        }
        grad_input[i] = sum;
    }
}

/// Same as ternaryVecmatSimd but ADDS to grad_input (for residual paths).
/// 4x unrolled with independent accumulators.
pub fn ternaryVecmatSimdAccum(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        var acc0: Vec8 = zero_vec;
        var acc1: Vec8 = zero_vec;
        var acc2: Vec8 = zero_vec;
        var acc3: Vec8 = zero_vec;
        var j: usize = 0;
        while (j + BLOCK <= out_dim) : (j += BLOCK) {
            inline for (0..UNROLL) |u| {
                const off = j + u * VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                const g: Vec8 = grad_output[off..][0..VEC_SIZE].*;
                switch (u) {
                    0 => acc0 += w_f32 * g,
                    1 => acc1 += w_f32 * g,
                    2 => acc2 += w_f32 * g,
                    3 => acc3 += w_f32 * g,
                    else => unreachable,
                }
            }
        }
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
            acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
        }
        const merged = acc0 + acc1 + acc2 + acc3;
        var sum: f32 = @reduce(.Add, merged);
        while (j < out_dim) : (j += 1) {
            const w = weights[w_base + j];
            if (w == 1) {
                sum += grad_output[j];
            } else if (w == -1) {
                sum -= grad_output[j];
            }
        }
        grad_input[i] += sum; // += for residual accumulation
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKWARD WEIGHT GRAD: g_W[i*out+j] += g_out[j] * cached_in[i]
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD outer product accumulation (backward weight gradient).
/// For each row i: g_W[i*out + j] += g_out[j] * cached[i] (broadcast * vector).
/// 4x unrolled: 32 elements per iteration.
pub fn outerProductAccumSimd(
    grad_weights: []f32,
    grad_output: []const f32,
    cached_input: []const f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const cached_val = cached_input[i];
        if (cached_val == 0.0) continue; // Skip zero cached values
        const val_vec: Vec8 = @splat(cached_val);
        const gw_base = i * out_dim;

        // 4x unrolled loop
        var j: usize = 0;
        while (j + BLOCK <= out_dim) : (j += BLOCK) {
            inline for (0..UNROLL) |u| {
                const off = j + u * VEC_SIZE;
                const g: Vec8 = grad_output[off..][0..VEC_SIZE].*;
                var gw: Vec8 = grad_weights[gw_base + off ..][0..VEC_SIZE].*;
                gw += g * val_vec;
                grad_weights[gw_base + off ..][0..VEC_SIZE].* = gw;
            }
        }
        // Tail: remaining 8-wide chunks
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const g: Vec8 = grad_output[j..][0..VEC_SIZE].*;
            var gw: Vec8 = grad_weights[gw_base + j ..][0..VEC_SIZE].*;
            gw += g * val_vec;
            grad_weights[gw_base + j ..][0..VEC_SIZE].* = gw;
        }
        // Scalar remainder
        while (j < out_dim) : (j += 1) {
            grad_weights[gw_base + j] += grad_output[j] * cached_val;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCALAR REFERENCE (for tests)
// ═══════════════════════════════════════════════════════════════════════════════

/// Scalar reference implementation for correctness tests.
fn ternaryMatvecScalar(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
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

fn ternaryVecmatScalar(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        var sum: f32 = 0.0;
        for (0..out_dim) |j| {
            const w = weights[i * out_dim + j];
            if (w == 1) {
                sum += grad_output[j];
            } else if (w == -1) {
                sum -= grad_output[j];
            }
        }
        grad_input[i] = sum;
    }
}

fn outerProductAccumScalar(
    grad_weights: []f32,
    grad_output: []const f32,
    cached_input: []const f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        for (0..out_dim) |j| {
            grad_weights[i * out_dim + j] += grad_output[j] * cached_input[i];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const TOLERANCE: f32 = 1e-5;

fn approxEqual(a: f32, b: f32) bool {
    return @abs(a - b) < TOLERANCE;
}

/// Fill buffer with deterministic pseudo-random f32 in [-range, range].
fn fillRandom(buf: []f32, seed: u64, range: f32) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*v| {
        v.* = (random.float(f32) * 2.0 - 1.0) * range;
    }
}

/// Fill weight buffer with deterministic ternary values {-1, 0, +1}.
fn fillTernaryWeights(buf: []i8, seed: u64) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*w| {
        const r = random.intRangeAtMost(i8, -1, 1);
        w.* = r;
    }
}

test "simd forward matches scalar — 243x243" {
    const in_dim = 243;
    const out_dim = 243;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output_simd: [out_dim]f32 = undefined;
    var output_scalar: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA001, 1.0);
    fillTernaryWeights(&weights, 0xB001);

    ternaryMatvecSimd(&input, &weights, &output_simd, in_dim, out_dim);
    ternaryMatvecScalar(&input, &weights, &output_scalar, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(output_simd[j], output_scalar[j]));
    }
}

test "simd forward matches scalar — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output_simd: [out_dim]f32 = undefined;
    var output_scalar: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA002, 1.0);
    fillTernaryWeights(&weights, 0xB002);

    ternaryMatvecSimd(&input, &weights, &output_simd, in_dim, out_dim);
    ternaryMatvecScalar(&input, &weights, &output_scalar, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(output_simd[j], output_scalar[j]));
    }
}

test "simd forward matches scalar — 729x243" {
    const in_dim = 729;
    const out_dim = 243;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output_simd: [out_dim]f32 = undefined;
    var output_scalar: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA003, 1.0);
    fillTernaryWeights(&weights, 0xB003);

    ternaryMatvecSimd(&input, &weights, &output_simd, in_dim, out_dim);
    ternaryMatvecScalar(&input, &weights, &output_scalar, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(output_simd[j], output_scalar[j]));
    }
}

test "simd vecmat matches scalar — 243x243" {
    const in_dim = 243;
    const out_dim = 243;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_simd: [in_dim]f32 = undefined;
    var grad_scalar: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC001, 1.0);
    fillTernaryWeights(&weights, 0xD001);

    ternaryVecmatSimd(&grad_output, &weights, &grad_simd, in_dim, out_dim);
    ternaryVecmatScalar(&grad_output, &weights, &grad_scalar, in_dim, out_dim);

    for (0..in_dim) |i| {
        try std.testing.expect(approxEqual(grad_simd[i], grad_scalar[i]));
    }
}

test "simd vecmat matches scalar — 729x243" {
    const in_dim = 729;
    const out_dim = 243;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_simd: [in_dim]f32 = undefined;
    var grad_scalar: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC002, 1.0);
    fillTernaryWeights(&weights, 0xD002);

    ternaryVecmatSimd(&grad_output, &weights, &grad_simd, in_dim, out_dim);
    ternaryVecmatScalar(&grad_output, &weights, &grad_scalar, in_dim, out_dim);

    for (0..in_dim) |i| {
        try std.testing.expect(approxEqual(grad_simd[i], grad_scalar[i]));
    }
}

test "simd outer product matches scalar — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var grad_output: [out_dim]f32 = undefined;
    var cached_input: [in_dim]f32 = undefined;
    var gw_simd: [in_dim * out_dim]f32 = [_]f32{0.0} ** (in_dim * out_dim);
    var gw_scalar: [in_dim * out_dim]f32 = [_]f32{0.0} ** (in_dim * out_dim);

    fillRandom(&grad_output, 0xE001, 0.5);
    fillRandom(&cached_input, 0xF001, 1.0);

    outerProductAccumSimd(&gw_simd, &grad_output, &cached_input, in_dim, out_dim);
    outerProductAccumScalar(&gw_scalar, &grad_output, &cached_input, in_dim, out_dim);

    for (0..in_dim * out_dim) |idx| {
        try std.testing.expect(approxEqual(gw_simd[idx], gw_scalar[idx]));
    }
}

test "simd edge cases — all zero weights" {
    const dim = 16;
    var input: [dim]f32 = undefined;
    var weights: [dim * dim]i8 = [_]i8{0} ** (dim * dim);
    var output: [dim]f32 = undefined;

    fillRandom(&input, 0x1111, 1.0);

    ternaryMatvecSimd(&input, &weights, &output, dim, dim);

    for (0..dim) |j| {
        try std.testing.expect(output[j] == 0.0);
    }
}

test "simd benchmark — 729x729 forward (1000 iters)" {
    const in_dim = 729;
    const out_dim = 729;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output_simd: [out_dim]f32 = undefined;
    var output_scalar: [out_dim]f32 = undefined;

    fillRandom(&input, 0xBEEF, 1.0);
    fillTernaryWeights(&weights, 0xCAFE);

    const ITERS = 1000;

    // Benchmark SIMD (4x unrolled)
    var timer_simd = std.time.Timer.start() catch return;
    for (0..ITERS) |_| {
        ternaryMatvecSimd(&input, &weights, &output_simd, in_dim, out_dim);
    }
    const simd_ns = timer_simd.read();

    // Benchmark scalar reference
    var timer_scalar = std.time.Timer.start() catch return;
    for (0..ITERS) |_| {
        ternaryMatvecScalar(&input, &weights, &output_scalar, in_dim, out_dim);
    }
    const scalar_ns = timer_scalar.read();

    const simd_us = simd_ns / 1000;
    const scalar_us = scalar_ns / 1000;
    const speedup = @as(f64, @floatFromInt(scalar_ns)) / @as(f64, @floatFromInt(simd_ns));

    std.debug.print(
        \\
        \\  ═══ SIMD BENCHMARK (729×729, {d} iters) ═══
        \\  Scalar:  {d} µs ({d:.1} µs/iter)
        \\  SIMD 4x: {d} µs ({d:.1} µs/iter)
        \\  Speedup: {d:.2}x
        \\
    , .{
        ITERS,
        scalar_us,
        @as(f64, @floatFromInt(scalar_us)) / ITERS,
        simd_us,
        @as(f64, @floatFromInt(simd_us)) / ITERS,
        speedup,
    });

    // SIMD must be faster than scalar
    try std.testing.expect(simd_ns < scalar_ns);
}
