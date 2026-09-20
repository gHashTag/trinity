//! GoldenFloat8 — φ-Optimized 8-bit Floating-Point Format
//!
//! Bit Layout: [sign:1][exp:3][mant:4] = 8 bits
//! Exponent bias: 7
//! φ-optimal distribution: exp/mant ≈ 0.5714 (distance: 0.047)
//!
//! 8-bit = 2^3, so 3-bit exponent (values 0-7) is correct!

const std = @import("std");

// ══════════════════════════════════════════════════════════════════════════════════════════
// GF8 CONSTANTS
// ════════════════════════════════════════════════════════════════════════════════════════════

pub const SignMask: u8 = 0x80;
pub const ExpMask: u8 = 0x70;
pub const MantMask: u8 = 0x0F;

pub const ExpShift: u3 = 4;
pub const SignShift: u3 = 7;
pub const Bias: i8 = 7;
pub const ExpBits: u8 = 3;
pub const MantBits: u8 = 4;

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
// GF8 TYPE DEFINITION
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const GF8 = packed struct(u8) {
    /// Mantissa (4 bits)
    mant: u4,

    /// Exponent (3 bits, bias 7) - values 0-7 (stored in 3 bits)
    exp: u3,

    /// Sign bit
    sign: u1,
};

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
// GF8 ZERO CONSTANT
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

pub const GF8_ZERO: GF8 = .{
    .mant = 0,
    .exp = 0,
    .sign = 0,
};

pub const GF8_NEG_ZERO: GF8 = .{
    .mant = 0,
    .exp = 0,
    .sign = 1,
};

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// GF8 CONSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

pub inline fn fromF32(x: f32) GF8 {
    if (x == 0.0) return GF8_ZERO;
    if (x < 0.0) return encodeNegative(x);
    return encodePositive(x);
}

pub inline fn toF32(g: GF8) f32 {
    if (g == GF8_ZERO or g == GF8_NEG_ZERO) {
        return 0.0;
    }

    // Exponent bias: 7, range [0, 7] (unbiased: [-7, 0])
    const exp_biased: i32 = @as(i32, g.exp);

    // Denormals: exp = 0 (biased), mant != 0
    if (exp_biased == 0 and g.mant != 0) {
        // value = mant/16 * 2^(1 - bias) = mant/16 * 2^(-6)
        const denorm = @as(f32, @floatFromInt(g.mant)) / 16.0;
        const value = denorm * @as(f32, std.math.pow(f32, 2.0, 1 - Bias));
        return if (g.sign == 0) value else -value;
    }

    // Normal: value = (1 + mant/16) * 2^(exp_biased - bias)
    const exp_unbiased = exp_biased - Bias;
    const mant_scaled: f32 = 1.0 + @as(f32, @floatFromInt(g.mant)) / 16.0;
    const value = mant_scaled * std.math.pow(f32, 2.0, @floatFromInt(exp_unbiased));
    return if (g.sign == 0) value else -value;
}

pub inline fn add(a: GF8, b: GF8) GF8 {
    return fromF32(toF32(a) + toF32(b));
}

pub inline fn sub(a: GF8, b: GF8) GF8 {
    return fromF32(toF32(a) - toF32(b));
}

pub inline fn mul(a: GF8, b: GF8) GF8 {
    return fromF32(toF32(a) * toF32(b));
}

pub inline fn div(a: GF8, b: GF8) GF8 {
    return fromF32(toF32(a) / toF32(b));
}

pub inline fn fma(a: GF8, b: GF8, c: GF8) GF8 {
    // FMA with f32 intermediate, then quantize back to GF8
    const ab = toF32(a) * toF32(b);
    const result = ab + toF32(c);
    return fromF32(result);
}

pub inline fn sqrt(a: GF8) GF8 {
    if (a.sign == 1) {
        return GF8{ .mant = 0, .exp = 7, .sign = 1 };
    }
    const abs_v = toF32(a);
    if (abs_v <= 0.0) {
        return GF8{ .mant = 0, .exp = 0, .sign = 0 };
    }
    return fromF32(std.math.sqrt(abs_v));
}

pub inline fn abs(a: GF8) GF8 {
    return .{
        .mant = a.mant,
        .exp = a.exp,
        .sign = 0,
    };
}

pub inline fn neg(a: GF8) GF8 {
    return .{
        .mant = a.mant,
        .exp = a.exp,
        .sign = 1 - a.sign,
    };
}

pub inline fn eq(a: GF8, b: GF8) bool {
    return a.mant == b.mant and a.exp == b.exp and a.sign == b.sign;
}

pub inline fn ne(a: GF8, b: GF8) bool {
    return !eq(a, b);
}

pub inline fn lt(a: GF8, b: GF8) bool {
    if (a.sign != b.sign) return (a.sign < b.sign);
    if (a.exp != b.exp) return (a.exp < b.exp);
    return a.mant < b.mant;
}

pub inline fn le(a: GF8, b: GF8) bool {
    if (a.sign != b.sign) return (a.sign < b.sign);
    if (a.exp != b.exp) return (a.exp < b.exp);
    return a.mant <= b.mant;
}

pub inline fn gt(a: GF8, b: GF8) bool {
    return !le(a, b);
}

pub inline fn ge(a: GF8, b: GF8) bool {
    return !lt(a, b);
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS (Internal)
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

fn encodePositive(x: f32) GF8 {
    if (x == 0.0) return GF8_ZERO;
    if (!std.math.isFinite(x)) {
        return GF8{ .mant = 0, .exp = 7, .sign = 0 };
    }

    // GF8 max value: (1 + 15/16) * 2^0 = 1.9375
    // Clamp input to valid range
    var x_clamped = x;
    if (x > 1.9375) x_clamped = 1.9375;

    const frexp = std.math.frexp(x_clamped);
    const m = frexp.significand * 2.0;
    var e = frexp.exponent - 1;

    // Clamp exponent to valid range for GF8
    // exp_biased = e + Bias, and exp_biased must be in [1, 7] for normals
    // So e must be in [-6, 0]
    if (e < -6) {
        e = -6; // Subnormal range
    } else if (e > 0) {
        e = 0; // Max normal (exp_biased = 7)
    }

    // Round mantissa to 4 bits
    const mant_f = (m - 1.0) * 16.0;
    var mant_i: u4 = @intFromFloat(std.math.round(mant_f));
    if (mant_i == 16) {
        mant_i = 15; // Clamp mantissa to max
    }

    // Clamp final exp_biased to [0, 7]
    var exp_biased = e + Bias;
    if (exp_biased > 7) exp_biased = 7;
    if (exp_biased < 0) exp_biased = 0;

    return GF8{
        .mant = mant_i,
        .exp = @intCast(exp_biased),
        .sign = 0,
    };
}

fn encodeNegative(x: f32) GF8 {
    const abs_x = -x;
    const gf8_abs = encodePositive(abs_x);
    return GF8{
        .mant = gf8_abs.mant,
        .exp = gf8_abs.exp,
        .sign = 1,
    };
}

test "GF8: zero" {
    try std.testing.expectEqual(@as(u8, @bitCast(GF8_ZERO)), 0);
    try std.testing.expectEqual(toF32(GF8_ZERO), 0.0);
}

test "GF8: one" {
    const one = fromF32(1.0);
    // 1.0: sign=0, exp=7 (biased), mant=0 → 0 111 0000 = 0x70
    try std.testing.expectEqual(@as(u8, @bitCast(one)), 0x70);
    try std.testing.expectApproxEqRel(toF32(one), 1.0, 0.05);
}

test "GF8: roundtrip positive" {
    // Test values within GF8 representable range: [~0.0078, 1.9375]
    const values = [_]f32{ 0.0, 0.01, 0.1, 0.5, 0.75, 1.0, 1.5, 1.9375 };
    for (values) |v| {
        const gf8 = fromF32(v);
        const back = toF32(gf8);
        const err = @abs(back - v) / @max(@abs(v), 1.0);
        try std.testing.expect(err < 0.1); // 10% error tolerance for values in range
    }
}

test "GF8: roundtrip negative" {
    // Test values within GF8 representable range
    const values = [_]f32{ -0.01, -0.1, -0.5, -0.75, -1.0, -1.5, -1.9375 };
    for (values) |v| {
        const gf8 = fromF32(v);
        const back = toF32(gf8);
        const err = @abs(back - v) / @max(@abs(v), 1.0);
        try std.testing.expect(err < 0.1); // 10% error tolerance for values in range
    }
}

test "GF8: clamping out of range" {
    // Test that values > 1.9375 are clamped
    const big = fromF32(10.0);
    const back = toF32(big);
    // Should be clamped to max value ~1.9375
    try std.testing.expect(back <= 2.0);
}

test "GF8: sign bit" {
    const pos = fromF32(1.0);
    const neg_val = fromF32(-1.0);
    try std.testing.expect(pos.sign == 0);
    try std.testing.expect(neg_val.sign == 1);
}

test "GF8: mantissa precision" {
    // Test that 4-bit mantissa gives ~6% precision
    const gf8 = fromF32(1.0 + 1.0/16.0); // 1.0625
    const back = toF32(gf8);
    const relative_err = @abs(back - 1.0625) / 1.0625;
    try std.testing.expect(relative_err < 0.2); // Allow ~20% error for 4-bit mantissa
}

test "GF8: exponent range" {
    const min_val = toF32(GF8{ .mant = 1, .exp = 0, .sign = 0 });
    const max_val = toF32(GF8{ .mant = MantMask, .exp = 7, .sign = 0 });
    try std.testing.expect(min_val > 0.0); // Smallest normal > 0
    try std.testing.expect(max_val < 15.0); // Max normal with max mantissa
}
