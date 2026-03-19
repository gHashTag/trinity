// @origin(spec:fusiform_gyrus.tri) @regen(manual-impl)
// FUSIFORM GYRUS — Format Conversion for Sensation
//
// Fusiform Gyrus: Visual format converter for Trinity cortex
// Handles cross-format conversions: FP16 ↔ GF16, BF16 ↔ GF16, f32 ↔ GF16
// Provides SIMD-optimized batch operations
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const ips = @import("intraparietal_sulcus.zig");
const f16_utils = @import("f16_utils.zig");
const simd_config = @import("simd_config.zig");

const Allocator = std.mem.Allocator;
const GoldenFloat16 = ips.GoldenFloat16;
const TernaryFloat9 = ips.TernaryFloat9;

// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-FORMAT CONVERSIONS — FP16/BF16 ↔ GF16
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert IEEE 754 FP16 (sign:1, exp:5, mant:10) to GoldenFloat16
/// FP16 has 10-bit mantissa, GF16 has 9-bit → precision loss on conversion
pub fn fp16ToGf16(fp16_bits: u16) GoldenFloat16 {
    const sign: u1 = @truncate(fp16_bits >> 15);
    const fp16_exp: u5 = @truncate((fp16_bits >> 10) & 0x1F);
    const fp16_mant: u10 = @truncate(fp16_bits & 0x3FF);

    // Check for zero/subnormal (exp = 0) or all-ones exp (Inf/NaN)
    if (fp16_exp == 0) {
        // Zero or subnormal → return zero GF16
        return .{ .sign = sign, .exp = 0, .mant = 0 };
    }
    if (fp16_exp == 31) {
        // Inf/NaN → saturate to max GF16
        return .{ .sign = sign, .exp = 62, .mant = 511 };
    }

    // FP16 exponent bias = 15, GF16 bias = 31
    // Convert unbiased: exp_fp - 15 + 31 = exp_gf + 16
    var exp_unbiased = @as(i32, fp16_exp) - 15;
    exp_unbiased += 31; // Add GF16 bias offset
    exp_unbiased = @min(exp_unbiased, 62); // Clamp to GF16 max (6-bit: bias-1 = 62)

    // Convert mantissa: 10 bits → 9 bits (round to nearest even)
    var gf16_mant: u10 = fp16_mant >> 1; // Shift right (loses 1 bit)
    const round_bit: u10 = fp16_mant & 1; // Lost bit for rounding
    const lsb = gf16_mant & 1;
    if (round_bit == 1 and lsb == 1) {
        // Tie to even: increment if odd
        gf16_mant += 1;
    }
    gf16_mant = gf16_mant & 0x1FF; // Keep only 9 bits

    return .{
        .sign = sign,
        .exp = @intCast(exp_unbiased),
        .mant = @truncate(gf16_mant),
    };
}

/// Convert Brain Float 16 (sign:1, exp:8, mant:7) to GoldenFloat16
/// BF16 has 7-bit mantissa, GF16 has 9-bit → zero padding needed
pub fn bf16ToGf16(bf16_bits: u16) GoldenFloat16 {
    const sign: u1 = @truncate(bf16_bits >> 15);
    const bf16_exp: u8 = @truncate((bf16_bits >> 7) & 0xFF);
    const bf16_mant: u7 = @truncate(bf16_bits & 0x7F);

    // Check for zero/subnormal (exp = 0) or all-ones exp (Inf/NaN)
    if (bf16_exp == 0) {
        // Zero or subnormal → return zero GF16
        return .{ .sign = sign, .exp = 0, .mant = 0 };
    }
    if (bf16_exp == 255) {
        // Inf/NaN → saturate to max GF16
        return .{ .sign = sign, .exp = 62, .mant = 511 };
    }

    // BF16 exponent bias = 127, GF16 bias = 31
    // Convert unbiased: exp_bf - 127 + 31 = exp_gf - 96
    var exp_unbiased = @as(i32, bf16_exp) - 96;
    exp_unbiased = @max(exp_unbiased, 1); // Minimum GF16 exponent is 1
    exp_unbiased = @min(exp_unbiased, 62);

    // BF16 mantissa (7 bits) → GF16 mantissa (9 bits)
    // Zero-pad the 2 low bits of GF16 mantissa
    const gf16_mant: u9 = @as(u9, bf16_mant) << 2;

    return .{
        .sign = sign,
        .exp = @intCast(exp_unbiased),
        .mant = gf16_mant,
    };
}

/// Convert GoldenFloat16 to IEEE 754 FP16
pub fn gf16ToFp16(gf: GoldenFloat16) u16 {
    if (gf.exp == 0 and gf.mant == 0) {
        return if (gf.sign == 1) 0x8000 else 0x0000; // Preserve sign for -0
    }

    const sign_bit: u16 = @as(u16, gf.sign) << 15;

    // GF16 exponent bias = 31, FP16 bias = 15
    const exp_unbiased = @as(i32, gf.exp) - 31;
    var fp16_exp: u5 = 0;
    if (exp_unbiased + 15 > 0 and exp_unbiased + 15 < 31) {
        fp16_exp = @intCast(exp_unbiased + 15);
    } else if (exp_unbiased + 15 >= 31) {
        fp16_exp = 31; // Saturate to FP16 max exponent
    }

    // GF16 mantissa (9 bits) → FP16 mantissa (10 bits)
    // Zero-pad the low bit
    const fp16_mant: u10 = @as(u10, gf.mant) << 1;

    return sign_bit | (@as(u16, fp16_exp) << 10) | fp16_mant;
}

/// Convert GoldenFloat16 to Brain Float 16
pub fn gf16Tobf16(gf: GoldenFloat16) u16 {
    if (gf.exp == 0 and gf.mant == 0) {
        return if (gf.sign == 1) 0x8000 else 0x0000;
    }

    const sign_bit: u16 = @as(u16, gf.sign) << 15;

    // GF16 exponent bias = 31, BF16 bias = 127
    const exp_unbiased = @as(i32, gf.exp) - 31;
    var bf16_exp: u8 = 0;
    if (exp_unbiased + 127 > 0 and exp_unbiased + 127 < 255) {
        bf16_exp = @intCast(exp_unbiased + 127);
    } else if (exp_unbiased + 127 >= 255) {
        bf16_exp = 254; // Saturate (actually overflow for BF16, but use max)
    }

    // GF16 mantissa (9 bits) → BF16 mantissa (7 bits)
    // Shift right (loses 2 bits)
    const bf16_mant: u7 = @truncate(gf.mant >> 2);

    return sign_bit | (@as(u16, bf16_exp) << 7) | bf16_mant;
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// SLICE CONVERSIONS — SIMD-optimized batch operations
// ═════════════════════════════════════════════════════════════════════════════════

/// Convert f32 slice to GF16 slice using IPS core functions
pub fn f32ToGf16Slice(allocator: Allocator, input: []const f32) ![]GoldenFloat16 {
    return ips.f32ToGf16Slice(allocator, input);
}

/// Convert GF16 slice to f32 slice using IPS core functions
pub fn gf16ToF32Slice(allocator: Allocator, input: []const GoldenFloat16) ![]f32 {
    return ips.gf16ToF32Slice(allocator, input);
}

/// Convert FP16 slice to GF16 slice (cross-format)
pub fn fp16ToGf16Slice(allocator: Allocator, input: []const f16) ![]GoldenFloat16 {
    const output = try allocator.alloc(GoldenFloat16, input.len);
    for (input, 0..) |val, i| {
        const fp16_bits: u16 = @bitCast(val);
        output[i] = fp16ToGf16(fp16_bits);
    }
    return output;
}

/// Convert GF16 slice to FP16 slice (cross-format)
pub fn gf16ToFp16Slice(allocator: Allocator, input: []const GoldenFloat16) ![]f16 {
    const output = try allocator.alloc(f16, input.len);
    for (input, 0..) |gf, i| {
        const fp16_bits = gf16ToFp16(gf);
        output[i] = @bitCast(fp16_bits);
    }
    return output;
}

/// Convert BF16 slice to GF16 slice (cross-format)
pub fn bf16ToGf16Slice(allocator: Allocator, input: []const f16) ![]GoldenFloat16 {
    const output = try allocator.alloc(GoldenFloat16, input.len);
    for (input, 0..) |val, i| {
        const bf16_bits: u16 = @bitCast(val);
        output[i] = bf16ToGf16(bf16_bits);
    }
    return output;
}

/// Convert GF16 slice to BF16 slice (cross-format)
pub fn gf16Tobf16Slice(allocator: Allocator, input: []const GoldenFloat16) ![]f16 {
    const output = try allocator.alloc(f16, input.len);
    for (input, 0..) |gf, i| {
        const bf16_bits = gf16Tobf16(gf);
        output[i] = @bitCast(bf16_bits);
    }
    return output;
}

/// Convert f32 slice to TF3-9 slice using IPS core functions
pub fn f32ToTf3Slice(allocator: Allocator, input: []const f32) ![]TernaryFloat9 {
    return ips.f32ToTf3Slice(allocator, input);
}

/// Convert TF3-9 slice to f32 slice using IPS core functions
pub fn tf3ToF32Slice(allocator: Allocator, input: []const TernaryFloat9) ![]f32 {
    return ips.tf3ToF32Slice(allocator, input);
}

// ═════════════════════════════════════════════════════════════════════════════════
// SIMD-ACCELERATED BATCH CONVERSIONS — Using adaptive width from simd_config
// ═════════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized f32 → GF16 conversion
/// Uses adaptive vector width (16/32-wide based on CPU features)
pub fn f32ToGf16SliceSimd(allocator: Allocator, input: []const f32) ![]GoldenFloat16 {
    const vec_len = simd_config.capabilities.optimal_f32_width;
    const num_vecs = input.len / vec_len;
    _ = input.len % vec_len; // tail_len - calculated for future SIMD tail handling

    const output = try allocator.alloc(GoldenFloat16, input.len);

    // Process vectors in parallel
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const chunk_f32 = input[i..][0..vec_len].*;

        inline for (0..vec_len) |j| {
            output[i + j] = ips.gf16FromF32(chunk_f32[j]);
        }
    }

    // Handle tail (scalar, for < vec_len elements)
    while (i < input.len) : (i += 1) {
        output[i] = ips.gf16FromF32(input[i]);
    }

    return output;
}

/// SIMD-optimized GF16 → f32 conversion
pub fn gf16ToF32SliceSimd(allocator: Allocator, input: []const GoldenFloat16) ![]f32 {
    const vec_len = simd_config.capabilities.optimal_f32_width;
    const num_vecs = input.len / vec_len;
    _ = input.len % vec_len; // tail_len - calculated for future SIMD tail handling

    const output = try allocator.alloc(f32, input.len);

    // Process vectors in parallel
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const chunk_gf = input[i..][0..vec_len].*;

        inline for (0..vec_len) |j| {
            output[i + j] = ips.gf16ToF32(chunk_gf[j]);
        }
    }

    // Handle tail
    while (i < input.len) : (i += 1) {
        output[i] = ips.gf16ToF32(input[i]);
    }

    return output;
}

/// SIMD-optimized FP16 → GF16 conversion (cross-format)
pub fn fp16ToGf16SliceSimd(allocator: Allocator, input: []const f16) ![]GoldenFloat16 {
    const vec_len = simd_config.capabilities.optimal_f16_width;
    const num_vecs = input.len / vec_len;

    const output = try allocator.alloc(GoldenFloat16, input.len);

    // FP16 as u16 for bit-level operations
    const input_bits: []const u16 = @ptrCast(input.ptr);
    var i: usize = 0;
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const chunk_bits = input_bits[i..][0..vec_len].*;

        inline for (0..vec_len) |j| {
            const gf16 = fp16ToGf16(chunk_bits[j]);
            output[i + j] = gf16;
        }
    }

    // Handle tail
    while (i < input.len) : (i += 1) {
        const gf16 = fp16ToGf16(input_bits[i]);
        output[i] = gf16;
    }

    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════════
// COMPACT FORMATS — Special GF16 values for sparse storage
// ═════════════════════════════════════════════════════════════════════════════════════

/// Encode GF16 value into compact 16-bit representation
/// Same as GF16 (already packed), useful for API consistency
pub inline fn compactGf16(gf: GoldenFloat16) u16 {
    return @bitCast(gf);
}

/// Decode compact 16-bit to GF16
/// Identity function (no-op), useful for API consistency
pub inline fn expandCompactGf16(bits: u16) GoldenFloat16 {
    return @bitCast(bits);
}

/// Count non-finite GF16 values in slice (Inf/NaN → saturates to max)
pub fn countNonFiniteGf16(data: []const GoldenFloat16) usize {
    var count: usize = 0;
    for (data) |gf| {
        // Check if exponent is max (saturated to Inf)
        // GF16 max exp is 62 (bias-1), mant max is 511
        if (gf.exp == 62 and gf.mant == 511) {
            count += 1;
        }
    }
    return count;
}

/// Sparsity analysis: count zero GF16 values in slice
pub fn countZeroGf16(data: []const GoldenFloat16) usize {
    var count: usize = 0;
    for (data) |gf| {
        if (gf.exp == 0 and gf.mant == 0) count += 1;
    }
    return count;
}

/// Calculate sparsity ratio (zeros / total)
pub fn sparsityRatioGf16(data: []const GoldenFloat16) f32 {
    if (data.len == 0) return 0.0;
    const zeros = countZeroGf16(data);
    return @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(data.len));
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "fp16 to gf16 roundtrip basic" {
    const f32_vals = [_]f32{ 1.0, 0.5, 2.0, -1.0, -0.5 };
    for (f32_vals) |val| {
        const fp16: f16 = @floatCast(val);
        const gf = fp16ToGf16(@bitCast(fp16));
        const gf_back = ips.gf16ToF32(gf);
        // Allow some precision loss (10 bits → 9 bits)
        try std.testing.expectApproxEqAbs(val, gf_back, @abs(val) * 0.02 + 0.01);
    }
}

test "bf16 to gf16 roundtrip basic" {
    const f32_vals = [_]f32{ 1.0, 0.5, 2.0, -1.0, -0.5 };
    for (f32_vals) |val| {
        // Manually create BF16 bits (f16_utils.bf16ToF32 inverts this)
        // BF16: sign:1, exp:8, mant:7 (uses f32 exponent layout)
        const bits_f32: u32 = @bitCast(val);
        const sign: u1 = @truncate(bits_f32 >> 31);
        const exp_f32: u8 = @truncate((bits_f32 >> 23) & 0xFF);
        const mant_f32_u32 = bits_f32 & 0x7FFFFF;

        // BF16 uses same 8-bit exponent as f32, but only 7 bits of mantissa
        const bf16_bits: u16 = (@as(u16, sign) << 15) |
            (@as(u16, exp_f32) << 7) |
            @as(u16, @truncate(mant_f32_u32 >> 16));

        const gf = bf16ToGf16(bf16_bits);
        const gf_back = ips.gf16ToF32(gf);
        // Allow more precision loss (7 bits → 9 bits padded)
        try std.testing.expectApproxEqAbs(val, gf_back, @abs(val) * 0.05 + 0.01);
    }
}

test "gf16 to fp16 cross format" {
    const vals = [_]f32{ 1.0, 0.5, -1.0, 0.0, 3.14 };
    for (vals) |val| {
        const gf = ips.gf16FromF32(val);
        const fp16_bits = gf16ToFp16(gf);
        // Note: fp16_bits is u16 representation of FP16 format
        // For roundtrip, we interpret as f32 using the FP16 bits
        const back = f16_utils.f16ToF32(@bitCast(fp16_bits));
        try std.testing.expectApproxEqAbs(val, back, @abs(val) * 0.02 + 0.01);
    }
}

test "gf16 to bf16 cross format" {
    const vals = [_]f32{ 1.0, 0.5, -1.0, 0.0, 3.14 };
    for (vals) |val| {
        const gf = ips.gf16FromF32(val);
        const bf16_bits = gf16Tobf16(gf);
        // bf16_bits is u16 representation of BF16 format
        const back = f16_utils.bf16ToF32(@bitCast(bf16_bits));
        try std.testing.expectApproxEqAbs(val, back, @abs(val) * 0.05 + 0.01);
    }
}

test "f32 to gf16 slice matches scalar" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 0.0, 1.0, -1.0, 0.5, 3.14 };
    const gf16_slice = try f32ToGf16Slice(allocator, &input);
    defer allocator.free(gf16_slice);

    for (input, gf16_slice) |orig, gf| {
        const gf_f32 = ips.gf16ToF32(gf);
        try std.testing.expectApproxEqAbs(orig, gf_f32, @abs(orig) * 0.01 + 0.001);
    }
}

test "gf16 special values preserve zero" {
    const zero = ips.gf16FromF32(0.0);
    const zero_neg = ips.gf16FromF32(-0.0);

    // IPS gf16FromF32 normalizes -0.0 to +0.0 (sign bit not preserved)
    try std.testing.expect(zero.sign == 0);
    try std.testing.expect(zero.exp == 0);
    try std.testing.expect(zero.mant == 0);

    // -0.0 is also normalized to +0.0 in IPS
    try std.testing.expect(zero_neg.sign == 0);
    try std.testing.expect(zero_neg.exp == 0);
    try std.testing.expect(zero_neg.mant == 0);
}

test "gf16 special values saturate" {
    const huge = ips.gf16FromF32(1e10);
    try std.testing.expect(huge.exp == 62); // Saturated to GF16_MAX_EXP
    try std.testing.expect(huge.mant == 511); // Max mantissa

    const tiny = ips.gf16FromF32(1e-10);
    try std.testing.expect(tiny.exp == 0 or tiny.mant == 0); // Underflow to zero
}

test "fp16 zero to gf16 preserves zero" {
    const fp16_zero: f16 = 0.0;
    const gf = fp16ToGf16(@bitCast(fp16_zero));
    try std.testing.expect(gf.sign == 0);
    try std.testing.expect(gf.exp == 0);
    try std.testing.expect(gf.mant == 0);
}

test "bf16 zero to gf16 preserves zero" {
    const bf16_zero: f16 = 0.0;
    const gf = bf16ToGf16(@bitCast(bf16_zero));
    try std.testing.expect(gf.sign == 0);
    try std.testing.expect(gf.exp == 0);
}

test "count non finite gf16" {
    const data = [_]GoldenFloat16{
        ips.gf16FromF32(1.0),
        ips.gf16FromF32(0.0),
        ips.gf16FromF32(std.math.inf(f32)),
        ips.gf16FromF32(1e10), // Saturates
    };
    const count = countNonFiniteGf16(&data);
    // Two: Inf + saturated huge
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "count zero gf16" {
    const data = [_]GoldenFloat16{
        ips.gf16FromF32(1.0),
        ips.gf16FromF32(0.0),
        ips.gf16FromF32(-1.0),
        ips.gf16FromF32(0.0),
        ips.gf16FromF32(2.5),
    };
    const zeros = countZeroGf16(&data);
    try std.testing.expectEqual(@as(usize, 2), zeros);
}

test "sparsity ratio gf16" {
    const data = [_]GoldenFloat16{
        ips.gf16FromF32(1.0),
        ips.gf16FromF32(0.0),
        ips.gf16FromF32(0.0),
        ips.gf16FromF32(2.0),
        ips.gf16FromF32(0.0),
    };
    const ratio = sparsityRatioGf16(&data);
    // 3 zeros out of 5 = 0.6
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), ratio, 0.01);
}

test "compact expand gf16 is identity" {
    const gf = GoldenFloat16{ .sign = 1, .exp = 30, .mant = 100 };
    const compact = compactGf16(gf);
    const expanded = expandCompactGf16(compact);
    try std.testing.expectEqual(gf, expanded);
}

test "f32 to tf3 slice" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 0.0, 1.0, -1.0, 0.5, 4.0 };
    const tf3_slice = try f32ToTf3Slice(allocator, &input);
    defer allocator.free(tf3_slice);

    for (input, tf3_slice) |orig, tf| {
        const tf_f32 = ips.tf3ToF32(tf);
        // Coarse accuracy for placeholder implementation
        try std.testing.expectApproxEqAbs(orig, tf_f32, @abs(orig) * 0.3 + 0.05);
    }
}

test "fp16 slice to gf16 slice roundtrip" {
    const allocator = std.testing.allocator;
    const f32_vals = [_]f32{ 0.0, 1.0, -1.0, 0.5, 3.14 };
    var f16_vals: [f32_vals.len]f16 = undefined;
    for (f32_vals, 0..) |v, i| f16_vals[i] = @floatCast(v);

    const gf16_slice = try fp16ToGf16Slice(allocator, &f16_vals);
    defer allocator.free(gf16_slice);

    // Convert GF16 back to f32 directly (more accurate than going through FP16)
    for (f32_vals, 0..) |orig, i| {
        const rec = ips.gf16ToF32(gf16_slice[i]);
        // Allow for precision loss in FP16 + GF16 conversion chain
        // f32 (24-bit mant) → f16 (10-bit mant) → gf16 (9-bit mant)
        try std.testing.expectApproxEqAbs(orig, rec, @abs(orig) * 0.05 + 0.02);
    }
}

// φ² + 1/φ² = 3 | TRINITY
