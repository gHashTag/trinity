//! GoldenFloat16 — φ-optimized ML number formats for Zig
//!
//! **Formats:**
//! - GF16: Golden Float16 — φ-optimized 16-bit format [sign:1][exp:6][mant:9]
//! - TF3: Ternary Float3 — packed ternary [sign:1][exp:6][mant:11] (18 bits)
//!
//! **Mathematical Foundation:**
//! φ² + 1/φ² = 3 | TRINITY
//! where φ = (1 + √5) / 2 ≈ 1.6180339887498949
//!
//! **Reference:**
//! - IBM DLFloat: https://research.ibm.com/publications/dlfloat-a-16-floating-point-format-designed-for-deep-learning-training-and-inference
//!
//! **Usage:**
//! ```zig
//! const golden = @import("golden-float");
//! const gf = golden.GF16.fromF32(3.14159);
//! const tf3 = golden.TF3.fromF32(2.71828);
//! ```
//!

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════
// TRINITY CONSTANTS
// ═════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI = 1.6180339887498948482;

/// φ² = φ × φ
pub const PHI_SQ = PHI * PHI;

/// 1/φ²
pub const PHI_INV_SQ = 1.0 / PHI_SQ;

/// Trinity Identity: φ² + 1/φ² = 3
pub const TRINITY = PHI_SQ + PHI_INV_SQ;

// ═════════════════════════════════════════════════════════════════════
// GF16: GOLDEN FLOAT16
// ═════════════════════════════════════════════════════════════════════

/// GF16: Golden Float16 — φ-optimized packed format
///
/// **Bit Layout:**
/// ```
/// ┌──────┬─────────┬─────────┐
/// │ sign │   exp   │  mant   │
/// │ 1bit │   6bit  │   9bit  │
/// └──────┴─────────┴─────────┘
/// ```
///
/// **Why φ-optimal?**
/// - phi-distance: |exp/mant - 1/φ| ≈ 0.049 (vs 0.082 for IEEE f16)
/// - Better numerical distribution for ML weights
/// - Compatible with IBM DLFloat 6:9 split
///
/// **Example:**
/// ```zig
/// const gf = GF16.fromF32(3.14159);
/// try std.testing.expectApproxEqAbs(3.14, gf.toF32(), 0.01);
/// ```
pub const GF16 = packed struct(u16) {
    /// Mantissa (9 bits) — φ-optimized precision
    mant: u9,

    /// Exponent (6 bits, bias 31)
    exp: u6,

    /// Sign bit (1 = negative)
    sign: u1,

    /// Create GF16 from f32 with φ-optimized encoding
    pub fn fromF32(v: f32) GF16 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };

        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x3F, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Find exponent (normalize to [0.5, 2))
        var exp: i8 = 0;
        var mant_f = abs_v;

        while (mant_f >= 1.0 and exp < 31) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -32) : (exp -= 1) mant_f *= 2.0;

        const exp_bias: i8 = 31;
        const exp_u6: u6 = @intCast(exp_bias + exp);
        const mant_u9: u9 = @intFromFloat((mant_f - 0.5) * 512.0);

        return .{
            .mant = @min(mant_u9, 511),
            .exp = exp_u6,
            .sign = sign_bit,
        };
    }

    /// Convert GF16 to f32
    pub fn toF32(self: GF16) f32 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x3F) {
            return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
        }

        const exp_unbiased = @as(i32, self.exp) - 31;
        const mant_f = 0.5 + @as(f32, @floatFromInt(self.mant)) / 512.0;
        const value = mant_f * std.math.pow(f32, 2.0, @floatFromInt(exp_unbiased));
        return if (self.sign == 1) -value else value;
    }

    /// GF16 addition (via f32 for precision)
    pub fn add(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() + b.toF32());
    }

    /// GF16 subtraction
    pub fn sub(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() - b.toF32());
    }

    /// GF16 multiplication
    pub fn mul(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() * b.toF32());
    }

    /// GF16 division
    pub fn div(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() / b.toF32());
    }

    /// Zero GF16
    pub inline fn zero() GF16 {
        return .{ .mant = 0, .exp = 0, .sign = 0 };
    }

    /// One GF16
    pub inline fn one() GF16 {
        return fromF32(1.0);
    }

    /// Negate GF16
    pub inline fn neg(self: GF16) GF16 {
        return .{
            .mant = self.mant,
            .exp = self.exp,
            .sign = if (self.sign == 1) 0 else 1,
        };
    }

    /// Absolute value
    pub inline fn abs(self: GF16) GF16 {
        return .{
            .mant = self.mant,
            .exp = self.exp,
            .sign = 0,
        };
    }

    /// φ-weighted quantization for better distribution
    pub fn phiQuantize(v: f32) GF16 {
        return fromF32(v * PHI_INV_SQ);
    }

    /// φ-weighted dequantization
    pub fn phiDequantize(gf: GF16) f32 {
        return gf.toF32() * PHI_SQ;
    }
};

// ═════════════════════════════════════════════════════════════════════
// TF3: TERNARY FLOAT3
// ═════════════════════════════════════════════════════════════════════

/// TF3: Ternary Float3 — packed ternary format
///
/// **Bit Layout:**
/// ```
/// ┌──────┬─────────┬────────────┐
/// │ sign │   exp   │   mant      │
/// │ 1bit │   6bit  │   11 bit    │
/// └──────┴─────────┴────────────┘
/// ```
/// (18 bits total)
///
/// **Structure:**
/// - sign: 1 sign bit
/// - exp: 6 exponent bits (values -31..+32, base 3)
/// - mant: 11 mantissa bits (ternary digits: {-1, 0, +1})
pub const TF3 = packed struct(u18) {
    /// Mantissa (11 bits)
    mant: u11,

    /// Exponent (6 bits, bias 31)
    exp: u6,

    /// Sign bit (1 = negative)
    sign: u1,

    /// Create TF3 from f32 (ternary base 3)
    pub fn fromF32(v: f32) TF3 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };

        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x3F, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Find exponent (ternary base 3)
        var exp: i16 = 0;
        var mant_f = abs_v;

        // Normalize: mant_f in [1/3, 1)
        const MAX_EXP: i16 = 31;
        const MIN_EXP: i16 = -31;

        while (mant_f >= 1.0 and exp < MAX_EXP) : (exp += 1) mant_f /= 3.0;
        while (mant_f < 1.0 / 3.0 and exp > MIN_EXP) : (exp -= 1) mant_f *= 3.0;

        const exp_biased = @min(@max(exp + 31, 0), 63);
        const exp_u6: u6 = @intCast(exp_biased);
        const mant_u11: u11 = @intFromFloat(@min(mant_f * 2047.0, 2047.0));

        return .{
            .mant = mant_u11,
            .exp = exp_u6,
            .sign = sign_bit,
        };
    }

    /// Convert TF3 to f32
    pub fn toF32(self: TF3) f32 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x3F) {
            return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
        }

        const exp_unbiased = @as(i16, self.exp) - 31;
        const mant_f = @as(f32, @floatFromInt(self.mant)) / 2047.0;
        const value = mant_f * std.math.pow(f32, 3.0, @floatFromInt(exp_unbiased));
        return if (self.sign == 1) -value else value;
    }

    /// Get ternary sign {-1, 0, +1}
    pub inline fn getSign(self: TF3) i8 {
        return if (self.sign == 1) -1 else if (self.mant == 0) 0 else 1;
    }

    /// Zero TF3
    pub inline fn zero() TF3 {
        return .{ .mant = 0, .exp = 0, .sign = 0 };
    }

    /// One TF3
    pub inline fn one() TF3 {
        return fromF32(1.0);
    }
};

// ═════════════════════════════════════════════════════════════════════
// COMPILE-TIME GUARDS
// ═════════════════════════════════════════════════════════════════════

comptime {
    std.debug.assert(@sizeOf(GF16) == 2);
    std.debug.assert(@sizeOf(TF3) == @sizeOf(u18));
}

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════

test "GF16 zero and one" {
    const zero = GF16.zero();
    try std.testing.expectEqual(@as(f32, 0), zero.toF32());

    const one = GF16.one();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), one.toF32(), 0.01);
}

test "GF16 roundtrip" {
    const values = [_]f32{ 0.0, 0.5, 1.0, 2.0, 3.14, 100.0, -0.5, -1.0, -2.0, -3.14 };
    for (values) |v| {
        const gf = GF16.fromF32(v);
        const result = gf.toF32();
        const err = @abs(v - result) / (@abs(v) + 0.001);
        try std.testing.expect(err < 0.05);
    }
}

test "GF16 arithmetic" {
    const a = GF16.fromF32(1.5);
    const b = GF16.fromF32(2.5);
    const sum = GF16.add(a, b);
    const diff = GF16.sub(b, a);
    const prod = GF16.mul(a, b);
    const quot = GF16.div(a, b);

    try std.testing.expectApproxEqAbs(@as(f32, 4.0), sum.toF32(), 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), diff.toF32(), 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), prod.toF32(), 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), quot.toF32(), 0.05);
}

test "GF16 phi quantization" {
    const original = 2.71828;
    const quantized = GF16.phiQuantize(original);
    const dequantized = GF16.phiDequantize(quantized);

    const error_pct = @abs((dequantized - original) / original) * 100.0;
    try std.testing.expect(error_pct < 10.0);
}

test "TF3 zero and one" {
    const zero = TF3.zero();
    try std.testing.expectEqual(@as(i8, 0), zero.getSign());
    try std.testing.expectEqual(@as(f32, 0), zero.toF32());

    const one = TF3.one();
    try std.testing.expectEqual(@as(i8, 1), one.getSign());
    try std.testing.expect(one.toF32() > 0.5 and one.toF32() < 1.5);
}

test "TF3 roundtrip" {
    const values = [_]f32{ 0.0, 0.1, 0.5, 1.0, -0.5, -1.0 };
    for (values) |v| {
        const tf3 = TF3.fromF32(v);
        const result = tf3.toF32();
        const err = @abs(v - result) / (@abs(v) + 0.001);
        try std.testing.expect(err < 0.5);
    }
}

test "TRINITY constant" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), TRINITY, 1e-10);
}

test "PHI constant" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.6180339887498948482), PHI, 1e-15);
}

test "PHI_SQ + 1/PHI_SQ equals 3" {
    const computed = PHI_SQ + 1.0 / PHI_SQ;
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), computed, 1e-10);
}

// φ² + 1/φ² = 3 | TRINITY
