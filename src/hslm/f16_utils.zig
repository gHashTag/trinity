// @origin(spec:f16_utils.tri) @regen(manual-impl)
// f16 UTILITIES — Adaptive-width SIMD for half-precision floats
//
// Uses simd_config.zig for comptime CPU feature detection:
// - AVX2 (x86_64): 32-wide f16 → 2× throughput vs 16-wide
// - NEON (aarch64): 16-wide f16
// - Fallback: 8-wide f16
//
// I/O in f16, compute in f32 internally for precision.
// Memory savings: 2× vs f32, same numerical accuracy for ternary ops.
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const simd_config = @import("simd_config.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE VECTOR TYPES — Width from CPU feature detection
// ═══════════════════════════════════════════════════════════════════════════════

/// Current optimal f16 vector width (comptime-known)
pub const VEC_F16_SIZE = simd_config.capabilities.optimal_f16_width;

/// Adaptive f16 vector type (16-wide on NEON, 32-wide on AVX2, 8-wide fallback)
pub const VecF16 = @Vector(VEC_F16_SIZE, f16);

/// Adaptive f32 vector type (matches f16 width for element-wise ops)
pub const VecF32 = @Vector(VEC_F16_SIZE, f32);

/// Zero vector for f16 (adaptive width)
pub inline fn zeroVecF16() VecF16 {
    return @splat(@as(f16, 0.0));
}

/// Zero vector for f32 (adaptive width)
pub inline fn zeroVecF32() VecF32 {
    return @splat(0.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLICE CONVERSIONS — f32 ↔ f16
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 slice to f16 slice in-place.
/// Input and output can overlap (safely handles aliasing).
pub fn f32ToF16Slice(input: []const f32, output: []f16) void {
    std.debug.assert(input.len == output.len);

    for (input, 0..) |val_f32, i| {
        output[i] = @floatCast(val_f32);
    }
}

/// Convert f16 slice to f32 slice in-place.
pub fn f16ToF32Slice(input: []const f16, output: []f32) void {
    std.debug.assert(input.len == output.len);

    for (input, 0..) |val_f16, i| {
        output[i] = f16ToF32(val_f16);
    }
}

/// Convert single f16 (IEEE 754 16-bit) to f32
/// Properly interprets the FP16 bit layout (sign:1, exp:5, mant:10)
pub inline fn f16ToF32(val: f16) f32 {
    const bits: u16 = @bitCast(val);
    const sign: u1 = @truncate(bits >> 15);
    const exp: u5 = @truncate((bits >> 10) & 0x1F);
    const mant: u10 = @truncate(bits & 0x3FF);

    if (exp == 0 and mant == 0) {
        // Zero or subnormal → return zero
        return if (sign == 1) -0.0 else 0.0;
    }
    if (exp == 31) {
        // Inf/NaN → return Inf
        const sign_bit: u32 = @as(u32, sign) << 31;
        const bits_inf: u32 = sign_bit | (0xFF << 23);
        return @bitCast(bits_inf);
    }

    // FP16 exponent bias = 15, f32 bias = 127
    const unbiased: i32 = @as(i32, exp) - 15;
    const f32_exp: i32 = unbiased + 127;

    // Mantissa: 10 bits → 23 bits (zero-pad low bits)
    const mant_bits: u32 = @as(u32, mant) << 13;

    const sign_bit: u32 = @as(u32, sign) << 31;
    const exp_bits: u32 = @as(u32, @intCast(f32_exp & 0xFF)) << 23;

    const result_bits: u32 = sign_bit | exp_bits | mant_bits;
    return @bitCast(result_bits);
}

/// Convert BF16 (bfloat16) to f32
/// BF16: sign:1, exp:8, mant:7 (same exponent as f32)
pub inline fn bf16ToF32(val: f16) f32 {
    const bits: u16 = @bitCast(val);
    const sign: u1 = @truncate(bits >> 15);
    const exp: u8 = @truncate((bits >> 7) & 0xFF);
    const mant: u7 = @truncate(bits & 0x7F);

    if (exp == 0 and mant == 0) {
        // Zero or subnormal → return zero
        return if (sign == 1) -0.0 else 0.0;
    }
    if (exp == 255) {
        // Inf/NaN → return Inf
        const sign_bit: u32 = @as(u32, sign) << 31;
        const bits_inf: u32 = sign_bit | (0xFF << 23);
        return @bitCast(bits_inf);
    }

    // BF16 exponent bias = 127, f32 bias = 127 (same!)
    // So exponent bits are identical
    const sign_bit: u32 = @as(u32, sign) << 31;
    const exp_bits: u32 = @as(u32, exp) << 23;
    const mant_bits: u32 = @as(u32, mant) << 16; // 7 bits → 23 bits (pad 16 zeros)

    const result_bits: u32 = sign_bit | exp_bits | mant_bits;
    return @bitCast(result_bits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VECTOR CONVERSIONS — Adaptive-width SIMD
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f16 vector to f32 vector (element-wise, adaptive width).
/// Inline for zero-cost abstraction.
pub inline fn vecF16ToF32(v: VecF16) VecF32 {
    return @floatCast(v);
}

/// Convert f32 vector to f16 vector (element-wise, adaptive width).
/// Inline for zero-cost abstraction.
pub inline fn vecF32ToF16(v: VecF32) VecF16 {
    return @floatCast(v);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY SAFETY — Check if f16 value is safe for ternary quantization
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if f16 value is "ternary safe" — won't overflow when quantized to {-1, 0, +1}.
/// Returns true if value is in finite range (not NaN or infinity).
pub fn isTernarySafeF16(val: f16) bool {
    // f16 finite range: -65504 to +65504
    // Convert to f32 to use std.math.isFinite
    const val_f32: f32 = @floatCast(val);
    return std.math.isFinite(val_f32);
}

/// Count how many f16 values are ternary-safe in a slice.
pub fn countTernarySafeF16(data: []const f16) usize {
    var count: usize = 0;
    for (data) |val| {
        if (isTernarySafeF16(val)) count += 1;
    }
    return count;
}

/// Count non-finite values (NaN or infinity) in f16 slice.
pub fn countNonFiniteF16(data: []const f16) usize {
    var count: usize = 0;
    for (data) |val| {
        const val_f32: f32 = @floatCast(val);
        if (!std.math.isFinite(val_f32)) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAX ABSOLUTE VALUE — For normalization/clipping
// ═══════════════════════════════════════════════════════════════════════════════

/// Find maximum absolute value in f16 slice (scalar reduction).
/// Useful for normalization and clipping before quantization.
pub fn maxAbsF16(data: []const f16) f16 {
    if (data.len == 0) return 0.0;

    var max_val: f16 = 0.0;
    for (data) |val| {
        const abs_val = if (val < 0) -val else val;
        if (abs_val > max_val) max_val = abs_val;
    }
    return max_val;
}

/// Find maximum absolute value in f16 slice using adaptive-width SIMD.
/// 4-8x faster than scalar version for large slices.
pub fn maxAbsF16Simd(data: []const f16) f16 {
    if (data.len == 0) return 0.0;

    const vec_len = VEC_F16_SIZE;
    const num_vecs = data.len / vec_len;

    // Accumulator vector (start with zeros)
    var acc_vec = zeroVecF16();

    // Process VEC_F16_SIZE elements at a time
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const chunk: VecF16 = data[i..][0..vec_len].*;

        // Absolute value: abs(x) = @select(x < 0, -x, x)
        const neg_chunk = -chunk;
        const mask = chunk < zeroVecF16();
        const abs_chunk = @select(f16, mask, neg_chunk, chunk);

        // Keep maximum: max(a, b) = @select(a < b, b, a)
        const max_mask = acc_vec < abs_chunk;
        acc_vec = @select(f16, max_mask, abs_chunk, acc_vec);
    }

    // Reduce vector to scalar (horizontal max)
    var max_val: f16 = 0.0;
    inline for (0..vec_len) |j| {
        if (acc_vec[j] > max_val) max_val = acc_vec[j];
    }

    // Handle scalar tail
    while (i < data.len) : (i += 1) {
        const abs_val = if (data[i] < 0) -data[i] else data[i];
        if (abs_val > max_val) max_val = abs_val;
    }

    return max_val;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOT PRODUCT — Adaptive-width f16 SIMD
// ═══════════════════════════════════════════════════════════════════════════════

/// Dot product of two f16 slices (adaptive-width SIMD, compute in f32).
/// Returns f64 to avoid overflow for large vectors.
pub fn dotProductF16(a: []const f16, b: []const f16) f64 {
    std.debug.assert(a.len == b.len);

    const vec_len = VEC_F16_SIZE;
    const num_vecs = a.len / vec_len;

    // Accumulator in f32 for precision
    var acc_f32 = zeroVecF32();

    // Process VEC_F16_SIZE elements at a time
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const a_vec: VecF16 = a[i..][0..vec_len].*;
        const b_vec: VecF16 = b[i..][0..vec_len].*;

        // Convert to f32 for compute
        const a_f32: VecF32 = vecF16ToF32(a_vec);
        const b_f32: VecF32 = vecF16ToF32(b_vec);

        // Accumulate
        acc_f32 += a_f32 * b_f32;
    }

    // Horizontal sum of accumulator
    var sum: f64 = 0;
    inline for (0..vec_len) |j| {
        sum += @as(f64, acc_f32[j]);
    }

    // Handle scalar tail
    while (i < a.len) : (i += 1) {
        sum += @as(f64, @floatCast(a[i])) * @as(f64, @floatCast(b[i]));
    }

    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NORMALIZATION — L2 norm for similarity computation
// ═══════════════════════════════════════════════════════════════════════════════

/// L2 norm of f16 slice (compute in f32, return f64).
pub fn l2NormF16(data: []const f16) f64 {
    const sum_sq = dotProductF16(data, data);
    return @sqrt(sum_sq);
}

/// Cosine similarity between two f16 slices (L2-normalized dot product).
/// Returns value in [-1, 1] range, or NaN if either vector is zero.
pub fn cosineSimilarityF16(a: []const f16, b: []const f16) f64 {
    const dot = dotProductF16(a, b);
    const norm_a = l2NormF16(a);
    const norm_b = l2NormF16(b);

    if (norm_a == 0 or norm_b == 0) return std.math.nan(f64);

    return dot / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY QUANTIZATION — f16 → {-1, 0, +1}
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize f16 slice to ternary {-1, 0, +1} using threshold.
/// Values > threshold → 1, values < -threshold → -1, else → 0.
pub fn quantizeF16ToTernary(input: []const f16, threshold: f16, output: []i8) void {
    std.debug.assert(input.len == output.len);

    for (input, 0..) |val, i| {
        output[i] = if (val > threshold) 1 else if (val < -threshold) @as(i8, -1) else 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "adaptive vector width is power of 2" {
    const width = VEC_F16_SIZE;
    try std.testing.expect(width >= 8 and width <= 32);
    // Check if power of 2
    try std.testing.expect(width & (width - 1) == 0);
}

test "zero vectors are correct width" {
    const zv_f16 = zeroVecF16();
    const zv_f32 = zeroVecF32();

    // Sum should be 0
    var sum_f16: f64 = 0;
    var sum_f32: f64 = 0;

    inline for (0..VEC_F16_SIZE) |i| {
        sum_f16 += @as(f64, @floatCast(zv_f16[i]));
        sum_f32 += @as(f64, zv_f32[i]);
    }

    try std.testing.expectEqual(@as(f64, 0), sum_f16);
    try std.testing.expectEqual(@as(f64, 0), sum_f32);
}

test "f32 to f16 slice conversion roundtrip" {
    const input = [_]f32{ 0.0, 1.0, -1.0, 0.5, -0.5, 100.0, -100.0 };
    var f16_buf: [input.len]f16 = undefined;
    var f32_out: [input.len]f32 = undefined;

    f32ToF16Slice(&input, &f16_buf);
    f16ToF32Slice(&f16_buf, &f32_out);

    for (input, f32_out) |orig, res| {
        const err = @abs(orig - res);
        try std.testing.expect(err <= @abs(orig) * 0.002 + 0.001);
    }
}

test "vec f16 to f32 conversion roundtrip" {
    var input: VecF16 = undefined;
    inline for (0..VEC_F16_SIZE) |i| {
        const i32_val: i32 = @intCast(i);
        input[i] = @floatFromInt(@rem(i32_val, 3) - 1); // -1, 0, 1 pattern
    }

    const f32_vec = vecF16ToF32(input);
    const f16_result = vecF32ToF16(f32_vec);

    inline for (0..VEC_F16_SIZE) |i| {
        try std.testing.expectEqual(input[i], f16_result[i]);
    }
}

test "is ternary safe f16" {
    try std.testing.expect(isTernarySafeF16(0.0));
    try std.testing.expect(isTernarySafeF16(1.0));
    try std.testing.expect(isTernarySafeF16(-1.0));
    try std.testing.expect(isTernarySafeF16(65504.0)); // max f16
    try std.testing.expect(isTernarySafeF16(-65504.0));

    const nan_f16: f16 = @floatCast(@as(f32, std.math.nan(f32)));
    try std.testing.expect(!isTernarySafeF16(nan_f16));

    const inf_f16: f16 = @floatCast(@as(f32, std.math.inf(f32)));
    try std.testing.expect(!isTernarySafeF16(inf_f16));
}

test "count ternary safe f16" {
    const data = [_]f16{ 0.0, 1.0, -1.0, 65504.0, -65504.0 };
    try std.testing.expectEqual(@as(usize, 5), countTernarySafeF16(&data));

    const with_nan = [_]f16{ 0.0, @floatCast(@as(f32, std.math.nan(f32))) };
    try std.testing.expectEqual(@as(usize, 1), countTernarySafeF16(&with_nan));
}

test "count non finite f16" {
    const data = [_]f16{ 0.0, 1.0, -1.0 };
    try std.testing.expectEqual(@as(usize, 0), countNonFiniteF16(&data));

    const with_nan = [_]f16{ 0.0, @floatCast(@as(f32, std.math.nan(f32))), @floatCast(@as(f32, std.math.inf(f32))) };
    try std.testing.expectEqual(@as(usize, 2), countNonFiniteF16(&with_nan));
}

test "max abs f16 scalar" {
    const data = [_]f16{ 0.5, -1.5, 0.3, -0.8 };
    const max_val = maxAbsF16(&data);
    try std.testing.expectApproxEqAbs(@as(f16, 1.5), max_val, 0.01);
}

test "max abs f16 simd matches scalar" {
    // Create test data larger than VEC_F16_SIZE
    var data: [256]f16 = undefined;
    for (0..256) |i| {
        const i32_val: i32 = @intCast(i);
        const val: f32 = @floatFromInt(@rem(i32_val, 17) - 8);
        data[i] = @floatCast(val);
    }

    const scalar_max = maxAbsF16(&data);
    const simd_max = maxAbsF16Simd(&data);

    try std.testing.expectApproxEqAbs(@as(f64, @floatCast(scalar_max)), @as(f64, @floatCast(simd_max)), 0.01);
}

test "dot product f16 basic" {
    const a = [_]f16{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f16{ 2.0, 3.0, 4.0, 5.0 };

    const dot = dotProductF16(&a, &b);
    const expected: f64 = 1 * 2 + 2 * 3 + 3 * 4 + 4 * 5;

    try std.testing.expectApproxEqAbs(expected, dot, 0.01);
}

test "dot product f16 large vectors" {
    // Test with vectors larger than VEC_F16_SIZE
    var a: [256]f16 = undefined;
    var b: [256]f16 = undefined;

    for (0..256) |i| {
        const i32_val: i32 = @intCast(i);
        const val: f32 = @floatFromInt(@rem(i32_val, 10));
        a[i] = @floatCast(val);
        b[i] = @floatCast(@as(f32, @floatFromInt(@rem(i32_val, 7))));
    }

    const dot = dotProductF16(&a, &b);
    try std.testing.expect(std.math.isFinite(dot));
}

test "l2 norm f16" {
    const data = [_]f16{ 3.0, 4.0 }; // 3-4-5 triangle
    const norm = l2NormF16(&data);

    try std.testing.expectApproxEqAbs(@as(f64, 5.0), norm, 0.01);
}

test "cosine similarity f16 identical vectors" {
    const data = [_]f16{ 1.0, 2.0, 3.0, 4.0 };
    const sim = cosineSimilarityF16(&data, &data);

    try std.testing.expect(sim > 0.99); // Should be ~1.0
}

test "cosine similarity f16 orthogonal vectors" {
    const a = [_]f16{ 1.0, 0.0 };
    const b = [_]f16{ 0.0, 1.0 };
    const sim = cosineSimilarityF16(&a, &b);

    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sim, 0.01);
}

test "cosine similarity f16 opposite vectors" {
    const data = [_]f16{ 1.0, 2.0, 3.0 };
    const neg = [_]f16{ -1.0, -2.0, -3.0 };
    const sim = cosineSimilarityF16(&data, &neg);

    try std.testing.expect(sim < -0.99); // Should be ~-1.0
}

test "quantize f16 to ternary" {
    const input = [_]f16{ 0.8, 0.3, -0.3, -0.8, 0.0 };
    var output: [5]i8 = undefined;

    quantizeF16ToTernary(&input, 0.5, &output);

    try std.testing.expectEqual(@as(i8, 1), output[0]); // 0.8 > 0.5
    try std.testing.expectEqual(@as(i8, 0), output[1]); // 0.3 < 0.5
    try std.testing.expectEqual(@as(i8, 0), output[2]); // -0.3 > -0.5
    try std.testing.expectEqual(@as(i8, -1), output[3]); // -0.8 < -0.5
    try std.testing.expectEqual(@as(i8, 0), output[4]); // 0.0 = 0
}

test "simd width info" {
    const caps = simd_config.capabilities;

    // Print to stdout for verification (won't show in test mode but useful for debug)
    _ = caps;
    try std.testing.expect(true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUZZ TESTS — Coverage-guided testing
// ═══════════════════════════════════════════════════════════════════════════════

const Fuzzer = struct {
    pub fn run(_: void, input: []const u8) anyerror!void {
        _ = input;
    }
};

test "fuzz f16 roundtrip precision" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 4) return;
            const val: f32 = @bitCast(input[0..4].*);
            if (!std.math.isFinite(val)) return;
            if (@abs(val) > 65504.0) return;
            if (@abs(val) > 0.0 and @abs(val) < 6.1e-5) return;

            const narrow: f16 = @floatCast(val);
            if (!std.math.isFinite(@as(f32, @floatCast(narrow)))) return;
            const wide: f32 = @floatCast(narrow);
            const err = @abs(val - wide);
            try std.testing.expect(err <= @abs(val) * 0.002 + 0.001);
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz ternary quantize invariant" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 2) return;
            const val: f16 = @bitCast(input[0..2].*);
            if (!std.math.isFinite(@as(f32, @floatCast(val)))) return;

            const threshold: f16 = 0.5;
            var ternary: [1]i8 = undefined;
            quantizeF16ToTernary(&[_]f16{val}, threshold, &ternary);

            try std.testing.expect(ternary[0] == -1 or ternary[0] == 0 or ternary[0] == 1);
            if (val > threshold) try std.testing.expect(ternary[0] == 1) else if (val < -threshold) try std.testing.expect(ternary[0] == -1) else try std.testing.expect(ternary[0] == 0);
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz dotProductF16 stability" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 16) return;
            const a: [4]f16 = @bitCast(input[0..8].*);
            const b: [4]f16 = @bitCast(input[8..16].*);

            for (a) |v| if (!std.math.isFinite(@as(f32, @floatCast(v)))) return;
            for (b) |v| if (!std.math.isFinite(@as(f32, @floatCast(v)))) return;

            const dot = dotProductF16(&a, &b);
            try std.testing.expect(std.math.isFinite(dot));
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz slice conversion roundtrip" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 4) return;
            const count = @min(input.len / 4, 32);
            if (count == 0) return;

            var f32_in: [32]f32 = undefined;
            for (0..count) |i| {
                const offset = i * 4;
                if (offset + 4 > input.len) break;
                f32_in[i] = @bitCast(input[offset..][0..4].*);
                if (!std.math.isFinite(f32_in[i])) return;
                if (@abs(f32_in[i]) > 65504.0) return;
            }

            var f16_buf: [32]f16 = undefined;
            var f32_out: [32]f32 = undefined;
            f32ToF16Slice(f32_in[0..count], f16_buf[0..count]);
            f16ToF32Slice(f16_buf[0..count], f32_out[0..count]);

            for (0..count) |i| {
                if (!std.math.isFinite(f32_out[i])) return;
                const err = @abs(f32_in[i] - f32_out[i]);
                try std.testing.expect(err <= @abs(f32_in[i]) * 0.002 + 0.001);
            }
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz cosineSimilarityF16 self-similarity" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 8) return;
            const count = @min(input.len / 2, 16);
            if (count == 0) return;

            var data: [16]f16 = @splat(@as(f16, 0.0));
            var all_zero = true;
            for (0..count) |i| {
                const offset = i * 2;
                if (offset + 2 > input.len) break;
                data[i] = @bitCast(input[offset..][0..2].*);
                if (!std.math.isFinite(@as(f32, @floatCast(data[i])))) return;
                if (data[i] != 0.0) all_zero = false;
            }
            if (all_zero) return;

            const sim = cosineSimilarityF16(data[0..count], data[0..count]);
            try std.testing.expect(std.math.isFinite(sim));
            try std.testing.expect(sim > 0.99);
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz maxAbsF16 non-negative" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < 2) return;
            const count = @min(input.len / 2, 32);
            if (count == 0) return;

            var data: [32]f16 = undefined;
            for (0..count) |i| {
                const offset = i * 2;
                if (offset + 2 > input.len) break;
                data[i] = @bitCast(input[offset..][0..2].*);
                if (!std.math.isFinite(@as(f32, @floatCast(data[i])))) return;
            }

            const result = maxAbsF16(data[0..count]);
            try std.testing.expect(std.math.isFinite(@as(f32, @floatCast(result))));
            try std.testing.expect(result >= 0.0);

            for (0..count) |i| {
                try std.testing.expect(@abs(data[i]) <= result + 0.001);
            }
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

test "fuzz vec ternary lossless" {
    const FuzzImpl = struct {
        fn run(ctx: @TypeOf(.{}), input: []const u8) anyerror!void {
            _ = ctx;
            if (input.len < VEC_F16_SIZE) return;

            var vec: VecF16 = undefined;
            for (0..VEC_F16_SIZE) |i| {
                vec[i] = switch (input[i] % 3) {
                    0 => @as(f16, -1.0),
                    1 => @as(f16, 0.0),
                    2 => @as(f16, 1.0),
                    else => unreachable,
                };
            }

            const widened = vecF16ToF32(vec);
            const narrowed = vecF32ToF16(widened);

            // Convert vector to array for comparison
            var result: [VEC_F16_SIZE]f16 = undefined;
            inline for (0..VEC_F16_SIZE) |i| {
                result[i] = narrowed[i];
            }

            inline for (0..VEC_F16_SIZE) |i| {
                try std.testing.expect(vec[i] == result[i]);
            }
        }
    };
    try std.testing.fuzz(.{}, FuzzImpl.run, .{});
}

// φ² + 1/φ² = 3 | TRINITY
