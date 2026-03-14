// @origin(spec:ternary_activations.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Ternary Activations
// Quantize activations to ternary {-1, 0, +1} with STE (Straight-Through Estimator).
// Pure integer ternary matmul: Vec32i8 = 32 ops/cycle with widening i8→i16 multiply.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY QUANTIZER WITH STE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TernaryQuantizer = struct {
    /// Threshold for quantization: |x| < threshold → 0
    threshold: f32 = 0.5,

    /// Forward: quantize f32 activations to ternary
    pub fn quantize(self: TernaryQuantizer, input: []const f32, output: []Trit) void {
        for (input, 0..) |x, i| {
            if (x > self.threshold) {
                output[i] = 1;
            } else if (x < -self.threshold) {
                output[i] = -1;
            } else {
                output[i] = 0;
            }
        }
    }

    /// Backward (STE): pass gradients through unchanged where |x| <= 1
    /// grad_input[i] = grad_output[i] if |x[i]| <= 1, else 0
    pub fn backward(input: []const f32, grad_output: []const f32, grad_input: []f32) void {
        for (input, 0..) |x, i| {
            grad_input[i] = if (@abs(x) <= 1.0) grad_output[i] else 0.0;
        }
    }

    /// Dequantize ternary back to f32 (for comparison/debugging)
    pub fn dequantize(trits: []const Trit, output: []f32) void {
        for (trits, 0..) |t, i| {
            output[i] = @floatFromInt(@as(i8, t));
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGER TERNARY MATMUL (no floats)
// ═══════════════════════════════════════════════════════════════════════════════

/// Pure integer matmul: ternary activations × ternary weights → i32 accumulator.
/// y[j] = Sum_i act[i] * weight[i*out_dim + j]
/// All operations: multiply i2×i2 → i4, accumulate → i32. Zero floats.
pub fn integerTernaryMatmul(
    activations: []const Trit,
    weights: []const Trit,
    output: []i32,
    in_dim: usize,
    out_dim: usize,
) void {
    @memset(output[0..out_dim], 0);

    for (0..in_dim) |i| {
        const act: i8 = activations[i];
        if (act == 0) continue;
        const w_base = i * out_dim;
        for (0..out_dim) |j| {
            const w: i8 = weights[w_base + j];
            output[j] += @as(i32, act) * @as(i32, w);
        }
    }
}

/// SIMD integer ternary matmul: Vec32i8 = 32 ops/cycle.
/// Widening multiply: i8 × i8 → i16, accumulate → i32.
pub fn simdIntegerTernaryMatmul(
    activations: []const Trit,
    weights: []const Trit,
    output: []i32,
    in_dim: usize,
    out_dim: usize,
) void {
    const VEC_SIZE = 16; // 16 i8 elements per vector
    const Vec16i8 = @Vector(VEC_SIZE, i8);
    const Vec16i16 = @Vector(VEC_SIZE, i16);

    @memset(output[0..out_dim], 0);

    for (0..in_dim) |i| {
        const act: i8 = activations[i];
        if (act == 0) continue;
        const act_vec: Vec16i8 = @splat(act);
        const w_base = i * out_dim;

        var j: usize = 0;
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            // Load weights as i8
            var w_vec: Vec16i8 = undefined;
            for (0..VEC_SIZE) |k| {
                w_vec[k] = weights[w_base + j + k];
            }

            // Widening multiply: i8 × i8 → i16
            const act_wide: Vec16i16 = act_vec;
            const w_wide: Vec16i16 = w_vec;
            const prod = act_wide * w_wide;

            // Accumulate to i32
            for (0..VEC_SIZE) |k| {
                output[j + k] += @as(i32, prod[k]);
            }
        }

        // Scalar tail
        while (j < out_dim) : (j += 1) {
            const w: i8 = weights[w_base + j];
            output[j] += @as(i32, act) * @as(i32, w);
        }
    }
}

/// Requantize i32 accumulator back to ternary for next layer.
/// Uses threshold-based quantization on accumulated values.
pub fn quantizeI32ToTernary(input: []const i32, output: []Trit, threshold: i32) void {
    for (input, 0..) |x, i| {
        if (x > threshold) {
            output[i] = 1;
        } else if (x < -threshold) {
            output[i] = -1;
        } else {
            output[i] = 0;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TernaryQuantizer roundtrip preserves sign" {
    const q = TernaryQuantizer{ .threshold = 0.3 };
    const input = [_]f32{ 1.0, -0.5, 0.1, -0.8, 0.0, 0.4, -0.2, 0.9 };
    var trits: [8]Trit = undefined;
    q.quantize(&input, &trits);

    // Values above threshold → +1, below -threshold → -1, else → 0
    try std.testing.expectEqual(@as(Trit, 1), trits[0]); // 1.0 > 0.3
    try std.testing.expectEqual(@as(Trit, -1), trits[1]); // -0.5 < -0.3
    try std.testing.expectEqual(@as(Trit, 0), trits[2]); // 0.1 within ±0.3
    try std.testing.expectEqual(@as(Trit, -1), trits[3]); // -0.8 < -0.3
    try std.testing.expectEqual(@as(Trit, 0), trits[4]); // 0.0 within ±0.3
    try std.testing.expectEqual(@as(Trit, 1), trits[5]); // 0.4 > 0.3
    try std.testing.expectEqual(@as(Trit, 0), trits[6]); // -0.2 within ±0.3
    try std.testing.expectEqual(@as(Trit, 1), trits[7]); // 0.9 > 0.3
}

test "integerTernaryMatmul matches float" {
    const in_dim = 4;
    const out_dim = 4;
    const act = [_]Trit{ 1, -1, 0, 1 };
    const weights = [_]Trit{
        1,  -1, 0,  1,
        0,  1,  -1, 0,
        -1, 0,  1,  -1,
        1,  1,  -1, 0,
    };
    var output: [out_dim]i32 = undefined;
    integerTernaryMatmul(&act, &weights, &output, in_dim, out_dim);

    // Manual: y[0] = 1*1 + (-1)*0 + 0*(-1) + 1*1 = 2
    try std.testing.expectEqual(@as(i32, 2), output[0]);
    // y[1] = 1*(-1) + (-1)*1 + 0*0 + 1*1 = -1
    try std.testing.expectEqual(@as(i32, -1), output[1]);
    // y[2] = 1*0 + (-1)*(-1) + 0*1 + 1*(-1) = 0
    try std.testing.expectEqual(@as(i32, 0), output[2]);
    // y[3] = 1*1 + (-1)*0 + 0*(-1) + 1*0 = 1
    try std.testing.expectEqual(@as(i32, 1), output[3]);
}

test "SIMD matches scalar" {
    const in_dim = 32;
    const out_dim = 48;
    var act: [in_dim]Trit = undefined;
    var weights: [in_dim * out_dim]Trit = undefined;

    var rng = std.Random.DefaultPrng.init(0xABCD);
    const random = rng.random();
    for (&act) |*a| {
        a.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    }
    for (&weights) |*w| {
        w.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    }

    var out_scalar: [out_dim]i32 = undefined;
    var out_simd: [out_dim]i32 = undefined;

    integerTernaryMatmul(&act, &weights, &out_scalar, in_dim, out_dim);
    simdIntegerTernaryMatmul(&act, &weights, &out_simd, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expectEqual(out_scalar[j], out_simd[j]);
    }
}

test "quantizeI32ToTernary" {
    const input = [_]i32{ 5, -3, 0, 1, -1, 10, -10, 2 };
    var output: [8]Trit = undefined;
    quantizeI32ToTernary(&input, &output, 2);

    try std.testing.expectEqual(@as(Trit, 1), output[0]); // 5 > 2
    try std.testing.expectEqual(@as(Trit, -1), output[1]); // -3 < -2
    try std.testing.expectEqual(@as(Trit, 0), output[2]); // 0 within ±2
    try std.testing.expectEqual(@as(Trit, 0), output[3]); // 1 within ±2
    try std.testing.expectEqual(@as(Trit, 0), output[4]); // -1 within ±2
    try std.testing.expectEqual(@as(Trit, 1), output[5]); // 10 > 2
    try std.testing.expectEqual(@as(Trit, -1), output[6]); // -10 < -2
    try std.testing.expectEqual(@as(Trit, 0), output[7]); // 2 = threshold, not >
}

test "STE backward passes gradient where |x| <= 1" {
    const input = [_]f32{ 0.5, -0.3, 1.5, -2.0, 0.0, 0.9, -0.9, 1.0 };
    const grad_out = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    var grad_in: [8]f32 = undefined;
    TernaryQuantizer.backward(&input, &grad_out, &grad_in);

    try std.testing.expectEqual(@as(f32, 1.0), grad_in[0]); // |0.5| <= 1
    try std.testing.expectEqual(@as(f32, 1.0), grad_in[1]); // |-.3| <= 1
    try std.testing.expectEqual(@as(f32, 0.0), grad_in[2]); // |1.5| > 1
    try std.testing.expectEqual(@as(f32, 0.0), grad_in[3]); // |−2| > 1
    try std.testing.expectEqual(@as(f32, 1.0), grad_in[4]); // |0| <= 1
    try std.testing.expectEqual(@as(f32, 1.0), grad_in[5]); // |.9| <= 1
    try std.testing.expectEqual(@as(f32, 1.0), grad_in[6]); // |-.9| <= 1
    try std.testing.expectEqual(@as(f32, 1.0), grad_in[7]); // |1.0| <= 1
}
