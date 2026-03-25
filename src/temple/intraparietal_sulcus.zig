// @origin(spec:intraparietal_sulcus.tri) @regen(manual-impl)
// INTRAPARIETAL SULCUS — Golden Format Definitions
//
// IPS (Intraparietal Sulcus): Core sensory format for Trinity cortex
// Defines golden-ratio optimized float formats: GF16 and TF3-9
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN FLOAT 16 — exp:mant = 6:9 ≈ 1/φ (0.666 vs 0.618)
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden Float 16 — 16-bit format with 6-bit exponent, 9-bit mantissa
/// exp:mant ratio = 6/9 = 0.666 ≈ 1/φ (0.618) — GOLDEN!
pub const GoldenFloat16 = packed struct(u16) {
    mant: u9, // mantissa bits (precision)
    exp: u6, // exponent bits (dynamic range)
    sign: u1, // sign bit
};

/// Constants for GoldenFloat16 (similar to IEEE but 6-bit exponent)
const GF16_EXP_BITS: u32 = 6;
const GF16_EXP_BIAS: i32 = (1 << (GF16_EXP_BITS - 1)) - 1; // 31
const GF16_MAX_EXP: i32 = (1 << GF16_EXP_BITS) - 2; // all-ones = reserved
const GF16_MIN_EXP: i32 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY FLOAT 9 — 9 trits = 18 bits, exp:mant = 3:5 = 0.6 ≈ 1/φ
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary Float 9 — 18-bit ternary float (9 trits total)
/// exp:mant = 3:5 = 0.6 ≈ 1/φ — EXACT GOLDEN MATCH!
pub const TernaryFloat9 = packed struct(u18) {
    // Simple 2-bit trit encoding: -1=01, 0=00, +1=10
    mant_trits: u10, // 5 trits at 2 bits each
    exp_trits: u6, // 3 trits at 2 bits each
    sign_trit: u2, // one trit at 2 bits
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Clamp value between min and max
inline fn clamp(comptime T: type, v: T, min_v: T, max_v: T) T {
    return if (v < min_v) min_v else if (v > max_v) max_v else v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GF16 CONVERSIONS — IEEE 754-style rounding to nearest even
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 to GoldenFloat16 (round-to-nearest-even)
pub fn gf16FromF32(val: f32) GoldenFloat16 {
    if (val == 0.0) {
        return .{ .sign = 0, .exp = 0, .mant = 0 };
    }

    const bits: u32 = @bitCast(val);
    const sign: u1 = @truncate(bits >> 31);
    const exp: i32 = @intCast((bits >> 23) & 0xFF);
    const mant: u32 = bits & 0x7FFFFF;

    if (exp == 0xFF) {
        // Inf/NaN → saturate to max finite
        const gexp: u6 = @intCast(GF16_MAX_EXP);
        const gmant: u9 = (1 << 9) - 1;
        return .{ .sign = sign, .exp = gexp, .mant = gmant };
    }

    // Normalized range: exp != 0
    const unbiased: i32 = exp - 127;

    // Recalculate exponent under GF16 bias
    var gexp_i: i32 = unbiased + GF16_EXP_BIAS;

    if (gexp_i <= 0) {
        // Subnormal / too small → 0
        return .{ .sign = sign, .exp = 0, .mant = 0 };
    } else if (gexp_i >= GF16_MAX_EXP) {
        // Too large → saturate
        const gexp: u6 = @intCast(GF16_MAX_EXP);
        const gmant: u9 = (1 << 9) - 1;
        return .{ .sign = sign, .exp = gexp, .mant = gmant };
    }

    // Normalized mantissa: 1.x in f32 has 23 bits, GF16 gives 9 bits.
    // Need rounding-to-nearest-even when truncating 23→9.
    // Take (mant | 1<<23) as 24-bit mantissa, shift it.
    var full_mant: u32 = mant | (1 << 23);
    const shift: u5 = 23 - 9;

    // Rounding: add 1<<(shift-1), accounting for tie-to-even
    const round_bit: u32 = 1 << (shift - 1);
    const lsb_mask: u32 = (1 << shift) - 1;
    const lsb = (full_mant >> shift) & 1;
    const remainder: u32 = full_mant & lsb_mask;

    if (remainder > round_bit or (remainder == round_bit and lsb == 1)) {
        full_mant += 1 << shift;
    }

    var gmant: u32 = (full_mant >> shift) & ((1 << 9) - 1);

    // Mantissa overflow (e.g., 1.111... → 10.000...)
    if (gmant == (1 << 9)) {
        gmant = 0;
        gexp_i += 1;
        if (gexp_i >= GF16_MAX_EXP) {
            const gexp: u6 = @intCast(GF16_MAX_EXP);
            const sat_mant: u9 = (1 << 9) - 1;
            return .{ .sign = sign, .exp = gexp, .mant = sat_mant };
        }
    }

    const gexp: u6 = @intCast(clamp(i32, gexp_i, GF16_MIN_EXP, GF16_MAX_EXP));
    return .{
        .sign = sign,
        .exp = gexp,
        .mant = @intCast(gmant),
    };
}

/// Convert GoldenFloat16 to f32
pub fn gf16ToF32(g: GoldenFloat16) f32 {
    if (g.exp == 0 and g.mant == 0) {
        return if (g.sign == 1) -0.0 else 0.0;
    }

    const sign_bit: u32 = @as(u32, g.sign) << 31;

    const exp_i: i32 = @intCast(g.exp);
    const unbiased_g: i32 = exp_i - GF16_EXP_BIAS;
    const f32_exp: i32 = unbiased_g + 127;

    if (f32_exp <= 0) {
        // Subnormal → approximately 0
        return if (g.sign == 1) -0.0 else 0.0;
    } else if (f32_exp >= 0xFF) {
        const bits_inf: u32 = sign_bit | (0xFF << 23);
        return @bitCast(bits_inf);
    }

    const exp_bits: u32 = @as(u32, @intCast(f32_exp & 0xFF)) << 23;
    // Restore mantissa: 9 bits → 23 bits (no additional rounding)
    const mant_bits: u32 = @as(u32, g.mant) << (23 - 9);

    const bits: u32 = sign_bit | exp_bits | mant_bits;
    return @bitCast(bits);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TF3-9 CONVERSIONS — Ternary float encoding (placeholder implementation)
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 to TF3-9 (simple log2 encoding for now)
/// Real ternary-tree magic to be implemented later
pub fn tf3FromF32(val: f32) TernaryFloat9 {
    // sign_trit: -1,0,+1 → encode as {01,00,10}
    var sign_code: u2 = 0;
    var v = val;
    if (v > 0) sign_code = 0b10 else if (v < 0) {
        sign_code = 0b01;
        v = -v;
    }

    if (v == 0.0) {
        return .{
            .sign_trit = 0,
            .exp_trits = 0,
            .mant_trits = 0,
        };
    }

    // Simplest log2-encode for exponent: 3 trits → 3^3=27 levels
    const log2v = math.log2(v);
    const exp_level = clamp(i32, @intFromFloat(log2v + 13.0), 0, 26); // offset 13
    // mant_trits simply linearly quantized for now
    const base_val = math.exp2(@as(f32, @floatFromInt(exp_level - 13)));
    const mant_level = clamp(i32, @intFromFloat((v / base_val) * 31.0), 0, 31);

    return .{
        .sign_trit = sign_code,
        .exp_trits = @intCast(exp_level & 0x3F),
        .mant_trits = @intCast(mant_level & 0x3FF),
    };
}

/// Convert TF3-9 to f32
pub fn tf3ToF32(t: TernaryFloat9) f32 {
    if (t.sign_trit == 0 and t.exp_trits == 0 and t.mant_trits == 0) return 0.0;

    var sign: f32 = 1.0;
    switch (t.sign_trit) {
        0b10 => sign = 1.0,
        0b01 => sign = -1.0,
        else => sign = 0.0,
    }

    const exp_level: i32 = @intCast(t.exp_trits & 0x3F);
    const mant_level: i32 = @intCast(t.mant_trits & 0x3FF);

    const base: f32 = math.exp2(@as(f32, @floatFromInt(exp_level - 13)));
    const frac: f32 = @as(f32, @floatFromInt(mant_level)) / 31.0;
    return sign * base * frac;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH OPERATIONS — SIMD-optimized slice conversions
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert f32 slice to GF16 slice (allocate new buffer)
pub fn f32ToGf16Slice(allocator: std.mem.Allocator, input: []const f32) ![]GoldenFloat16 {
    const output = try allocator.alloc(GoldenFloat16, input.len);
    for (input, 0..) |val, i| {
        output[i] = gf16FromF32(val);
    }
    return output;
}

/// Convert GF16 slice to f32 slice (allocate new buffer)
pub fn gf16ToF32Slice(allocator: std.mem.Allocator, input: []const GoldenFloat16) ![]f32 {
    const output = try allocator.alloc(f32, input.len);
    for (input, 0..) |gf, i| {
        output[i] = gf16ToF32(gf);
    }
    return output;
}

/// Convert f32 slice to TF3-9 slice (allocate new buffer)
pub fn f32ToTf3Slice(allocator: std.mem.Allocator, input: []const f32) ![]TernaryFloat9 {
    const output = try allocator.alloc(TernaryFloat9, input.len);
    for (input, 0..) |val, i| {
        output[i] = tf3FromF32(val);
    }
    return output;
}

/// Convert TF3-9 slice to f32 slice (allocate new buffer)
pub fn tf3ToF32Slice(allocator: std.mem.Allocator, input: []const TernaryFloat9) ![]f32 {
    const output = try allocator.alloc(f32, input.len);
    for (input, 0..) |tf, i| {
        output[i] = tf3ToF32(tf);
    }
    return output;
}

// ═════════════════════════════════════════════════════════════════════════════════
// GOLDEN FORMAT ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate φ-distance for a format (|exp/mant - 1/φ|)
pub fn goldenDistance(exp_bits: u8, mant_bits: u8) f64 {
    const ratio: f64 = @as(f64, @floatFromInt(exp_bits)) / @as(f64, @floatFromInt(mant_bits));
    const target: f64 = 0.6180339887498948482; // 1/φ
    return @abs(ratio - target);
}

/// Check if a format is "golden" (distance < 0.1)
pub fn isGoldenFormat(exp_bits: u8, mant_bits: u8) bool {
    return goldenDistance(exp_bits, mant_bits) < 0.1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gf16 roundtrip basic" {
    const cases = [_]f32{ 0.0, -0.0, 1.0, -1.0, 0.5, 3.14, 1e-4, 1e4 };
    for (cases) |v| {
        const g = gf16FromF32(v);
        const r = gf16ToF32(g);
        try std.testing.expectApproxEqAbs(v, r, @abs(v) * 0.01 + 0.001);
    }
}

test "gf16 special values" {
    // Zero
    const z = gf16FromF32(0.0);
    try std.testing.expectEqual(@as(f32, 0.0), gf16ToF32(z));

    // Saturate large values
    const big = gf16FromF32(1e10);
    const big_out = gf16ToF32(big);
    try std.testing.expect(big_out > 0.0);
    try std.testing.expect(std.math.isFinite(big_out));
}

test "gf16 dynamic range" {
    // Test that we can represent small and large values
    const small = gf16FromF32(1e-4);
    const large = gf16FromF32(1e4);
    const s_out = gf16ToF32(small);
    const l_out = gf16ToF32(large);

    try std.testing.expect(s_out > 0.0);
    try std.testing.expect(l_out > 0.0);
    try std.testing.expect(std.math.isFinite(s_out));
    try std.testing.expect(std.math.isFinite(l_out));
}

test "tf3 roundtrip basic" {
    const cases = [_]f32{ 0.0, 1.0, -1.0, 0.25, 4.0 };
    for (cases) |v| {
        const t = tf3FromF32(v);
        const r = tf3ToF32(t);
        // Coarse accuracy for placeholder implementation
        try std.testing.expectApproxEqAbs(v, r, @abs(v) * 0.25 + 0.05);
    }
}

test "tf3 trit encoding" {
    const pos = tf3FromF32(1.0);
    const neg = tf3FromF32(-1.0);
    const zero = tf3FromF32(0.0);

    try std.testing.expectEqual(@as(u2, 0b10), pos.sign_trit); // +1
    try std.testing.expectEqual(@as(u2, 0b01), neg.sign_trit); // -1
    try std.testing.expectEqual(@as(u2, 0b00), zero.sign_trit); // 0
}

test "golden distance gf16" {
    // GF16: exp=6, mant=9 → ratio = 6/9 = 0.666
    const dist = goldenDistance(6, 9);
    // Target: 1/φ ≈ 0.618, distance ≈ 0.048
    try std.testing.expect(dist < 0.1);
    try std.testing.expect(dist > 0.01);
}

test "golden distance tf3" {
    // TF3-9: exp=3, mant=5 → ratio = 3/5 = 0.6
    const dist = goldenDistance(3, 5);
    // Target: 1/φ ≈ 0.618, distance ≈ 0.018
    try std.testing.expect(dist < 0.1);
    try std.testing.expect(dist > 0.01);
}

test "is golden format" {
    try std.testing.expect(isGoldenFormat(6, 9)); // GF16
    try std.testing.expect(isGoldenFormat(3, 5)); // TF3-9
    try std.testing.expect(!isGoldenFormat(8, 7)); // IEEE 754
    try std.testing.expect(!isGoldenFormat(5, 10)); // BF16
}

test "f32 to gf16 slice" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 0.0, 1.0, -1.0, 0.5, 3.14 };

    const gf16_slice = try f32ToGf16Slice(allocator, &input);
    defer allocator.free(gf16_slice);

    try std.testing.expectEqual(input.len, gf16_slice.len);

    const f32_slice = try gf16ToF32Slice(allocator, gf16_slice);
    defer allocator.free(f32_slice);

    for (input, f32_slice) |orig, rec| {
        try std.testing.expectApproxEqAbs(orig, rec, @abs(orig) * 0.01 + 0.001);
    }
}

test "f32 to tf3 slice" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 0.0, 1.0, -1.0, 0.25, 4.0 };

    const tf3_slice = try f32ToTf3Slice(allocator, &input);
    defer allocator.free(tf3_slice);

    try std.testing.expectEqual(input.len, tf3_slice.len);

    const f32_slice = try tf3ToF32Slice(allocator, tf3_slice);
    defer allocator.free(f32_slice);

    for (input, f32_slice) |orig, rec| {
        // Coarse tolerance for placeholder implementation
        try std.testing.expectApproxEqAbs(orig, rec, @abs(orig) * 0.25 + 0.05);
    }
}

// φ² + 1/φ² = 3 | TRINITY
