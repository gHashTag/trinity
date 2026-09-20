//! GF binary-exponent ladder — the whole φ-sized rung family from one rule.
//!
//! Every binary GoldenFloat rung is sized by ONE normative rule (FORMAT-SPEC-001 v1.2):
//!
//!   e = round((N - 1) / φ²),  m = N - 1 - e,  bias = 2^(e-1) - 1,  exp_max = 2^e - 1
//!
//! so the exp:mantissa split tracks 1/φ ≈ 0.618 at every width. This factory derives
//! the rungs the README documents: GF4 / GF8 / GF12 / GF16 / GF20 / GF24 / GF32.
//! (GF8 and GF16 also have dedicated, φ-FMA-rich implementations in
//! golden_float16.zig / formats_root.zig; those stay the production entry points —
//! this module completes the *ladder* in code and is the reference for the other rungs.)
//!
//! Value (normal):   (-1)^sign * (1 + M / 2^m) * 2^(e - bias)
//! Specials:         e = 0        -> zero (mantissa 0) / flush subnormals to 0
//!                   e = exp_max  -> Inf (mantissa 0) / NaN (mantissa != 0)
//!
//! **Usage:**
//! ```zig
//! const gfb = @import("gf_binary.zig");
//! const x = gfb.GF12.fromF32(3.14159);
//! std.debug.print("{d}\n", .{x.toF32()});
//! const Custom = gfb.GF(48); // any width the rule accepts
//! ```
//!
//! phi^2 + 1/phi^2 = 3 | TRINITY

const std = @import("std");

const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI; // ≈ 2.618033988749895

/// Build a binary GF rung of `bits` total width using the φ² sizing rule.
pub fn GF(comptime bits: comptime_int) type {
    comptime {
        if (bits < 4) @compileError("GF requires at least 4 bits (1 sign + >=1 exp + >=1 mantissa)");
    }
    const e_bits: comptime_int = @intFromFloat(@round(@as(f64, bits - 1) / PHI_SQ));
    const m_bits: comptime_int = bits - 1 - e_bits;
    comptime {
        if (e_bits < 1 or m_bits < 1) @compileError("degenerate rung: exp or mantissa < 1 bit");
    }
    const bias_c: comptime_int = (1 << (e_bits - 1)) - 1;
    const exp_max_c: comptime_int = (1 << e_bits) - 1;

    const Mant = std.meta.Int(.unsigned, m_bits);
    const Exp = std.meta.Int(.unsigned, e_bits);
    const ReprInt = std.meta.Int(.unsigned, bits);

    return packed struct(ReprInt) {
        mant: Mant,
        exp: Exp,
        sign: u1,

        const Self = @This();

        pub const BITS: u32 = bits;
        pub const EXP_BITS: u32 = e_bits;
        pub const MANT_BITS: u32 = m_bits;
        pub const BIAS: u32 = bias_c;
        pub const EXP_MAX: u32 = exp_max_c; // reserved Inf/NaN exponent
        pub const Repr = ReprInt;

        const MANT_SCALE: f32 = @floatFromInt(@as(u64, 1) << m_bits);
        const MANT_LIMIT: i64 = @as(i64, 1) << m_bits;
        // largest finite unbiased exponent is (exp_max-1) - bias.
        const MAX_E: i32 = @as(i32, exp_max_c - 1) - @as(i32, bias_c);
        // smallest normal unbiased exponent is 1 - bias (exp field 1).
        const MIN_E: i32 = 1 - @as(i32, bias_c);

        /// Encode f32 (round-to-nearest, saturate to Inf, flush subnormals to zero).
        pub fn fromF32(v: f32) Self {
            if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = @intFromBool(std.math.signbit(v)) };
            if (std.math.isNan(v)) return .{ .mant = 1, .exp = @intCast(exp_max_c), .sign = 0 };
            if (std.math.isInf(v)) return .{ .mant = 0, .exp = @intCast(exp_max_c), .sign = @intFromBool(v < 0) };

            const sign: u1 = @intFromBool(v < 0);
            var f: f32 = @abs(v);
            var e: i32 = 0;
            while (f >= 2.0) : (e += 1) f /= 2.0;
            while (f < 1.0) : (e -= 1) f *= 2.0;

            if (e > MAX_E) return .{ .mant = 0, .exp = @intCast(exp_max_c), .sign = sign }; // -> Inf
            if (e < MIN_E) return .{ .mant = 0, .exp = 0, .sign = sign }; // flush to zero (no subnormals)

            var mant: i64 = @intFromFloat(std.math.round((f - 1.0) * MANT_SCALE));
            var exp_field: i32 = e + @as(i32, bias_c);
            if (mant >= MANT_LIMIT) { // significand rounded to 2.0 -> carry
                mant = 0;
                exp_field += 1;
                if (exp_field >= @as(i32, exp_max_c)) return .{ .mant = 0, .exp = @intCast(exp_max_c), .sign = sign };
            }
            return .{ .mant = @intCast(mant), .exp = @intCast(exp_field), .sign = sign };
        }

        /// Decode back to f32.
        pub fn toF32(self: Self) f32 {
            if (self.exp == exp_max_c) {
                if (self.mant == 0) return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
                return std.math.nan(f32);
            }
            if (self.exp == 0) return if (self.sign == 1) -0.0 else 0.0; // zero (subnormals flushed)
            const e: i32 = @as(i32, self.exp) - @as(i32, bias_c);
            const f: f32 = 1.0 + @as(f32, @floatFromInt(self.mant)) / MANT_SCALE;
            const val = f * std.math.exp2(@as(f32, @floatFromInt(e)));
            return if (self.sign == 1) -val else val;
        }

        pub fn isFinite(self: Self) bool {
            return self.exp != exp_max_c;
        }
        pub fn bits_(self: Self) ReprInt {
            return @bitCast(self);
        }
        pub fn fromBits(b: ReprInt) Self {
            return @bitCast(b);
        }
        pub fn zero() Self {
            return .{ .mant = 0, .exp = 0, .sign = 0 };
        }
        pub fn one() Self {
            return fromF32(1.0);
        }
        pub fn neg(self: Self) Self {
            return .{ .mant = self.mant, .exp = self.exp, .sign = self.sign ^ 1 };
        }
        pub fn abs(self: Self) Self {
            return .{ .mant = self.mant, .exp = self.exp, .sign = 0 };
        }
        pub fn add(a: Self, b: Self) Self {
            return fromF32(a.toF32() + b.toF32());
        }
        pub fn sub(a: Self, b: Self) Self {
            return fromF32(a.toF32() - b.toF32());
        }
        pub fn mul(a: Self, b: Self) Self {
            return fromF32(a.toF32() * b.toF32());
        }
        pub fn div(a: Self, b: Self) Self {
            return fromF32(a.toF32() / b.toF32());
        }
    };
}

/// The φ-sized binary rungs the README documents.
pub const GF4 = GF(4);
pub const GF8 = GF(8);
pub const GF12 = GF(12);
pub const GF16 = GF(16);
pub const GF20 = GF(20);
pub const GF24 = GF(24);
pub const GF32 = GF(32);

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

test "GF ladder rule matches the SSOT catalog (e / m / bias)" {
    try std.testing.expectEqual(@as(u32, 1), GF4.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 2), GF4.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 0), GF4.BIAS);
    try std.testing.expectEqual(@as(u32, 3), GF8.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 4), GF8.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 3), GF8.BIAS);
    try std.testing.expectEqual(@as(u32, 4), GF12.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 7), GF12.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 7), GF12.BIAS);
    try std.testing.expectEqual(@as(u32, 6), GF16.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 9), GF16.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 31), GF16.BIAS);
    try std.testing.expectEqual(@as(u32, 7), GF20.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 12), GF20.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 63), GF20.BIAS);
    try std.testing.expectEqual(@as(u32, 9), GF24.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 14), GF24.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 255), GF24.BIAS);
    try std.testing.expectEqual(@as(u32, 12), GF32.EXP_BITS);
    try std.testing.expectEqual(@as(u32, 19), GF32.MANT_BITS);
    try std.testing.expectEqual(@as(u32, 2047), GF32.BIAS);
}

test "GF ladder packed struct widths" {
    inline for (.{ GF4, GF8, GF12, GF16, GF20, GF24, GF32 }, .{ 4, 8, 12, 16, 20, 24, 32 }) |T, n| {
        try std.testing.expectEqual(@as(u32, n), T.BITS);
    }
}

fn checkRoundtrip(comptime T: type, values: []const f32, tol: f32) !void {
    for (values) |v| {
        const q = T.fromF32(v).toF32();
        const err = @abs(q - v) / (@abs(v) + 1e-9);
        try std.testing.expect(err <= tol);
    }
}

test "GF16 roundtrip (9-bit mantissa)" {
    const vals = [_]f32{ 1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, 12345.0 };
    try checkRoundtrip(GF16, &vals, 0.005);
}

test "GF32 roundtrip (19-bit mantissa, wide range)" {
    const vals = [_]f32{ 1.0, 3.14159, 1e30, -1e30, 1e-30, 6.022e23, 1e-9 };
    try checkRoundtrip(GF32, &vals, 1e-4);
}

test "GF8 roundtrip (small, 4-bit mantissa)" {
    const vals = [_]f32{ 1.0, -1.0, 1.5, 2.0, 0.5, 0.25 };
    try checkRoundtrip(GF8, &vals, 0.05);
}

test "GF specials: Inf / NaN / zero across the ladder" {
    inline for (.{ GF4, GF8, GF12, GF16, GF20, GF24, GF32 }) |T| {
        try std.testing.expect(std.math.isInf(T.fromF32(std.math.inf(f32)).toF32()));
        try std.testing.expect(T.fromF32(-std.math.inf(f32)).toF32() < 0);
        try std.testing.expect(std.math.isNan(T.fromF32(std.math.nan(f32)).toF32()));
        try std.testing.expectEqual(@as(f32, 0.0), T.zero().toF32());
        try std.testing.expect(!T.fromF32(std.math.inf(f32)).isFinite());
    }
}

test "GF wider rungs strictly extend range (GF16 overflows where GF32 holds)" {
    try std.testing.expect(std.math.isInf(GF16.fromF32(1e30).toF32())); // GF16 max ~2^31
    try std.testing.expect(GF32.fromF32(1e30).isFinite()); // GF32 max ~2^2047
}

test "GF arithmetic (GF16)" {
    const a = GF16.fromF32(1.5);
    const b = GF16.fromF32(2.5);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), a.add(b).toF32(), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), a.mul(b).toF32(), 0.02);
}

test "GF bits roundtrip" {
    const x = GF20.fromF32(-6.28);
    try std.testing.expectEqual(x.bits_(), GF20.fromBits(x.bits_()).bits_());
}

// Exact-bit golden vectors — pin the encoding, not just an approximate round-trip.
// Tolerance tests are blind to a systematic layout shift (e.g. a wrong exponent bias
// still round-trips symmetrically); these catch it. Values are exact in a 4-bit
// mantissa and inside GF8's tight range. Hand-check: GF8(-2.5) = sign 1, |2.5| =
// 1.25·2^1 -> exp field bias+1 = 4 = 0b100, mant 0.25·16 = 4 = 0b0100 -> 0b1_100_0100
// = 0xC4. A deliberate codec change must update these on purpose.
test "GF ladder: exact-bit golden vectors (encoding regression guard)" {
    const E = std.testing.expectEqual;
    // gf8 [1:3:4] b3
    try E(@as(GF8.Repr, 0x30), GF8.fromF32(1.0).bits_());
    try E(@as(GF8.Repr, 0x38), GF8.fromF32(1.5).bits_());
    try E(@as(GF8.Repr, 0x40), GF8.fromF32(2.0).bits_());
    try E(@as(GF8.Repr, 0xC4), GF8.fromF32(-2.5).bits_());
    // gf12 [1:4:7] b7
    try E(@as(GF12.Repr, 0x380), GF12.fromF32(1.0).bits_());
    try E(@as(GF12.Repr, 0x3C0), GF12.fromF32(1.5).bits_());
    try E(@as(GF12.Repr, 0x400), GF12.fromF32(2.0).bits_());
    try E(@as(GF12.Repr, 0xC20), GF12.fromF32(-2.5).bits_());
    // gf16 [1:6:9] b31 — the primary production rung (shared with golden_float16.GF16)
    try E(@as(GF16.Repr, 0x3E00), GF16.fromF32(1.0).bits_());
    try E(@as(GF16.Repr, 0x3F00), GF16.fromF32(1.5).bits_());
    try E(@as(GF16.Repr, 0x4000), GF16.fromF32(2.0).bits_());
    try E(@as(GF16.Repr, 0xC080), GF16.fromF32(-2.5).bits_());
    // gf20 [1:7:12] b63
    try E(@as(GF20.Repr, 0x3F000), GF20.fromF32(1.0).bits_());
    try E(@as(GF20.Repr, 0x3F800), GF20.fromF32(1.5).bits_());
    try E(@as(GF20.Repr, 0x40000), GF20.fromF32(2.0).bits_());
    try E(@as(GF20.Repr, 0xC0400), GF20.fromF32(-2.5).bits_());
    // gf24 [1:9:14] b255
    try E(@as(GF24.Repr, 0x3FC000), GF24.fromF32(1.0).bits_());
    try E(@as(GF24.Repr, 0x3FE000), GF24.fromF32(1.5).bits_());
    try E(@as(GF24.Repr, 0x400000), GF24.fromF32(2.0).bits_());
    try E(@as(GF24.Repr, 0xC01000), GF24.fromF32(-2.5).bits_());
    // gf32 [1:12:19] b2047
    try E(@as(GF32.Repr, 0x3FF80000), GF32.fromF32(1.0).bits_());
    try E(@as(GF32.Repr, 0x3FFC0000), GF32.fromF32(1.5).bits_());
    try E(@as(GF32.Repr, 0x40000000), GF32.fromF32(2.0).bits_());
    try E(@as(GF32.Repr, 0xC0020000), GF32.fromF32(-2.5).bits_());
}

// Normative-rule conformance — machine-check that every rung's factory constants satisfy
// the ONE sizing rule the spec encodes (FORMAT-SPEC-001):
//   e = round((N-1)/φ²),  m = N-1-e,  bias = 2^(e-1)-1,  exp_max = 2^e-1
// Re-derived here independently of the factory, so a future edit to GF() that drifts from
// the rule fails loudly. This is the class of guard that was missing when GF8 carried a
// wrong bias (spec bias=7 vs canonical=3, #84). (A full spec<->.tri parse-time check is a
// separate effort — tri_reader lives outside this module's import path.)
test "GF ladder: factory constants obey the normative φ² rule" {
    const rungs = [_]u32{ 8, 12, 16, 20, 24, 32 };
    inline for (rungs) |N| {
        const T = GF(N);
        const e: u32 = @intFromFloat(@round(@as(f64, N - 1) / PHI_SQ));
        const m: u32 = N - 1 - e;
        const bias: u32 = (@as(u32, 1) << @intCast(e - 1)) - 1;
        const exp_max: u32 = (@as(u32, 1) << @intCast(e)) - 1;
        try std.testing.expectEqual(e, T.EXP_BITS);
        try std.testing.expectEqual(m, T.MANT_BITS);
        try std.testing.expectEqual(bias, T.BIAS);
        try std.testing.expectEqual(exp_max, T.EXP_MAX);
        try std.testing.expectEqual(@as(u32, N), T.BITS);
        try std.testing.expectEqual(N, 1 + T.EXP_BITS + T.MANT_BITS); // fields tile the width
    }
}
