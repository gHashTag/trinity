//! GF-T — balanced-ternary-EXPONENT GoldenFloat ladder (GF-T4 / GF-T8 / GF-T16 / GF-T32).
//!
//! GF-T is the ternary-exponent sibling of the binary GF ladder. The exponent is a
//! balanced-ternary number (digits -1/0/+1) stored as an unsigned OFFSET in
//! `[0, 3^E - 1]`; the balanced exponent is `e = offset - EXP_OFFSET`. There is no
//! regime decode (unlike posit/tekum) and the mantissa keeps GF's uniform binary
//! precision.
//!
//!   value = (-1)^sign * (1 + M / 2^m) * 2^e,   e = offset - EXP_OFFSET
//!   EXP_OFFSET = (3^E - 1) / 2    (balanced zero point; offset EXP_OFFSET => e = 0)
//!   OFFSET_MAX = 3^E - 1          (reserved top row: Inf / NaN)
//!   finite iff offset < OFFSET_MAX
//!
//! Rungs (authoritative — t27/specs/numeric/gft{4,8,16,32}.t27, see specs/gft.tri):
//!   GF-T4  : E=2 trits, M=1  bit , EXP_OFFSET=4  , e in [-4  ,+3  ], ~2.4 decades
//!   GF-T8  : E=3 trits, M=4  bits, EXP_OFFSET=13 , e in [-13 ,+12 ], ~8   decades
//!   GF-T16 : E=4 trits, M=9  bits, EXP_OFFSET=40 , e in [-40 ,+39 ], ~24  decades
//!   GF-T32 : E=6 trits, M=25 bits, EXP_OFFSET=364, e in [-364,+363], ~219 decades
//!
//! **Usage:**
//! ```zig
//! const gft = @import("gft.zig");
//! const x = gft.GFT16.fromF32(3.14159);
//! const y = gft.GFT16.fromF32(2.71828);
//! const z = x.mul(y);
//! std.debug.print("{d}\n", .{z.toF32()}); // ~8.539
//! ```
//!
//! phi^2 + 1/phi^2 = 3 | TRINITY

const std = @import("std");

/// Build a GF-T rung from its exponent-trit count and mantissa-bit count.
/// `exp_trits` and `mant_bits` fully determine the format; everything else
/// (offset range, bias, storage width) is derived at comptime.
pub fn GFT(comptime exp_trits: comptime_int, comptime mant_bits: comptime_int) type {
    // 3^exp_trits
    const pow3: comptime_int = blk: {
        var p: comptime_int = 1;
        var i: comptime_int = 0;
        while (i < exp_trits) : (i += 1) p *= 3;
        break :blk p;
    };
    const offset_max: comptime_int = pow3 - 1; // reserved special row
    const exp_offset: comptime_int = (pow3 - 1) / 2; // balanced zero point

    // Bits needed to hold an offset in [0, offset_max]: smallest b with 2^b >= pow3.
    const exp_field_bits: comptime_int = blk: {
        var b: comptime_int = 0;
        while ((1 << b) < pow3) : (b += 1) {}
        break :blk b;
    };
    const total_bits: comptime_int = 1 + exp_field_bits + mant_bits;

    const Mant = std.meta.Int(.unsigned, mant_bits);
    const Off = std.meta.Int(.unsigned, exp_field_bits);
    const ReprInt = std.meta.Int(.unsigned, total_bits);

    return packed struct(ReprInt) {
        // Field order is low-to-high: mantissa in the low bits, sign in the top bit
        // (mirrors GF16's `[mant][exp][sign]` packed layout).
        mant: Mant,
        offset: Off,
        sign: u1,

        const Self = @This();

        pub const EXP_TRITS: u32 = exp_trits;
        pub const MANT_BITS: u32 = mant_bits;
        pub const EXP_OFFSET: u32 = exp_offset;
        pub const OFFSET_MAX: u32 = offset_max; // reserved Inf/NaN row
        pub const BITS: u32 = total_bits;
        /// Underlying unsigned storage integer (use with `bits()` / `fromBits()`).
        pub const Repr = ReprInt;

        const MAX_E: i32 = @as(i32, exp_offset) - 1; // max finite exponent (offset_max-1 - exp_offset)
        const MIN_E: i32 = -@as(i32, exp_offset); // min finite exponent (offset 0)
        const MANT_SCALE: f32 = @floatFromInt(@as(u64, 1) << mant_bits);
        const MANT_LIMIT: i64 = @as(i64, 1) << mant_bits;

        /// Encode an f32 into this GF-T rung (round-to-nearest, saturate to Inf,
        /// flush-to-zero on underflow).
        pub fn fromF32(v: f32) Self {
            if (v == 0.0) return .{ .mant = 0, .offset = 0, .sign = @intFromBool(std.math.signbit(v)) };
            if (std.math.isNan(v)) return .{ .mant = 1, .offset = @intCast(offset_max), .sign = 0 };
            if (std.math.isInf(v)) return .{ .mant = 0, .offset = @intCast(offset_max), .sign = @intFromBool(v < 0) };

            const sign: u1 = @intFromBool(v < 0);
            var f: f32 = @abs(v);
            var e: i32 = 0;
            // Normalize the significand into [1, 2).
            while (f >= 2.0) : (e += 1) f /= 2.0;
            while (f < 1.0) : (e -= 1) f *= 2.0;

            if (e > MAX_E) return .{ .mant = 0, .offset = @intCast(offset_max), .sign = sign }; // -> Inf
            if (e < MIN_E) return .{ .mant = 0, .offset = 0, .sign = sign }; // underflow -> 0

            var mant: i64 = @intFromFloat(std.math.round((f - 1.0) * MANT_SCALE));
            var off: i32 = e + @as(i32, exp_offset);
            if (mant >= MANT_LIMIT) { // significand rounded up to 2.0 -> carry into exponent
                mant = 0;
                off += 1;
                if (off >= @as(i32, offset_max)) return .{ .mant = 0, .offset = @intCast(offset_max), .sign = sign };
            }
            return .{ .mant = @intCast(mant), .offset = @intCast(off), .sign = sign };
        }

        /// Decode this GF-T rung back to f32 (exact for the represented value).
        pub fn toF32(self: Self) f32 {
            if (self.offset == offset_max) {
                if (self.mant == 0) return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
                return std.math.nan(f32);
            }
            if (self.offset == 0 and self.mant == 0) return if (self.sign == 1) -0.0 else 0.0;
            const e: i32 = @as(i32, self.offset) - @as(i32, exp_offset);
            const f: f32 = 1.0 + @as(f32, @floatFromInt(self.mant)) / MANT_SCALE;
            const val = f * std.math.exp2(@as(f32, @floatFromInt(e)));
            return if (self.sign == 1) -val else val;
        }

        /// True unless this is the reserved Inf/NaN row.
        pub fn isFinite(self: Self) bool {
            return self.offset != offset_max;
        }

        /// Raw storage bits (for serialization / FFI).
        pub fn bits(self: Self) ReprInt {
            return @bitCast(self);
        }
        /// Rebuild from raw storage bits.
        pub fn fromBits(b: ReprInt) Self {
            return @bitCast(b);
        }

        pub fn zero() Self {
            return .{ .mant = 0, .offset = 0, .sign = 0 };
        }
        pub fn one() Self {
            return fromF32(1.0);
        }
        pub fn neg(self: Self) Self {
            return .{ .mant = self.mant, .offset = self.offset, .sign = self.sign ^ 1 };
        }
        pub fn abs(self: Self) Self {
            return .{ .mant = self.mant, .offset = self.offset, .sign = 0 };
        }

        // Arithmetic via f32 (exact-enough; the format is the storage, f32 is the ALU).
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

/// The four practical rungs of the GF-T ladder.
pub const GFT4 = GFT(2, 1);
pub const GFT8 = GFT(3, 4);
pub const GFT16 = GFT(4, 9);
pub const GFT32 = GFT(6, 25);

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

test "GF-T constants match the authoritative ladder" {
    try std.testing.expectEqual(@as(u32, 4), GFT4.EXP_OFFSET);
    try std.testing.expectEqual(@as(u32, 8), GFT4.OFFSET_MAX);
    try std.testing.expectEqual(@as(u32, 13), GFT8.EXP_OFFSET);
    try std.testing.expectEqual(@as(u32, 26), GFT8.OFFSET_MAX);
    try std.testing.expectEqual(@as(u32, 40), GFT16.EXP_OFFSET);
    try std.testing.expectEqual(@as(u32, 80), GFT16.OFFSET_MAX);
    try std.testing.expectEqual(@as(u32, 364), GFT32.EXP_OFFSET);
    try std.testing.expectEqual(@as(u32, 728), GFT32.OFFSET_MAX);
}

test "GF-T unity encodes to the balanced zero offset" {
    const one16 = GFT16.fromF32(1.0);
    try std.testing.expectEqual(@as(u32, 40), @as(u32, one16.offset)); // e = 0
    try std.testing.expectEqual(@as(u9, 0), one16.mant);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), one16.toF32(), 1e-6);
}

test "GF-T zero and negative zero" {
    try std.testing.expectEqual(@as(f32, 0.0), GFT16.zero().toF32());
    try std.testing.expectEqual(@as(f32, 0.0), GFT16.fromF32(0.0).toF32());
    try std.testing.expect(std.math.signbit(GFT16.fromF32(-0.0).toF32()));
}

fn checkRoundtrip(comptime T: type, values: []const f32, tol: f32) !void {
    for (values) |v| {
        const q = T.fromF32(v).toF32();
        const err = @abs(q - v) / (@abs(v) + 1e-9);
        try std.testing.expect(err <= tol);
    }
}

test "GF-T16 roundtrip (9-bit mantissa, tight)" {
    const vals = [_]f32{ 1.0, -1.0, 0.5, 2.0, 3.14159, -3.14159, 100.0, 0.001, -0.001, 12345.0, 1e-9 };
    try checkRoundtrip(GFT16, &vals, 0.005); // < 0.5% for a 9-bit mantissa
}

test "GF-T8 roundtrip (4-bit mantissa, looser)" {
    const vals = [_]f32{ 1.0, -1.0, 0.5, 2.0, 3.0, -3.0, 50.0, 0.01 };
    try checkRoundtrip(GFT8, &vals, 0.05); // < 5% for a 4-bit mantissa
}

test "GF-T4 roundtrip (1-bit mantissa, coarse)" {
    const vals = [_]f32{ 1.0, -1.0, 1.5, 2.0, 4.0, 0.5, 0.25 };
    try checkRoundtrip(GFT4, &vals, 0.30); // 1-bit mantissa -> ~25% steps
}

test "GF-T32 huge dynamic range" {
    const vals = [_]f32{ 1e30, -1e30, 1e-30, 1e18, 1e-18, 6.022e23 };
    try checkRoundtrip(GFT32, &vals, 0.001); // 25-bit mantissa is very precise
}

test "GF-T Inf and NaN roundtrip" {
    inline for (.{ GFT4, GFT8, GFT16, GFT32 }) |T| {
        try std.testing.expect(std.math.isInf(T.fromF32(std.math.inf(f32)).toF32()));
        try std.testing.expect(T.fromF32(-std.math.inf(f32)).toF32() < 0);
        try std.testing.expect(std.math.isNan(T.fromF32(std.math.nan(f32)).toF32()));
        try std.testing.expect(!T.fromF32(std.math.inf(f32)).isFinite());
        try std.testing.expect(T.fromF32(1.0).isFinite());
    }
}

test "GF-T overflow saturates to Inf, underflow flushes to zero" {
    // GF-T16 max finite exponent is +39 (~5.5e11); 1e30 overflows.
    try std.testing.expect(std.math.isInf(GFT16.fromF32(1e30).toF32()));
    // ...and 1e-30 underflows below 2^-40.
    try std.testing.expectEqual(@as(f32, 0.0), GFT16.fromF32(1e-30).toF32());
    // GF-T32 covers both.
    try std.testing.expect(GFT32.fromF32(1e30).isFinite());
}

test "GF-T neg / abs" {
    const x = GFT16.fromF32(3.5);
    try std.testing.expectApproxEqAbs(@as(f32, -3.5), x.neg().toF32(), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), x.neg().abs().toF32(), 0.02);
}

test "GF-T arithmetic (GF-T16)" {
    const a = GFT16.fromF32(1.5);
    const b = GFT16.fromF32(2.5);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), a.add(b).toF32(), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), b.sub(a).toF32(), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), a.mul(b).toF32(), 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), a.div(b).toF32(), 0.02);
}

test "GF-T bits roundtrip" {
    const x = GFT16.fromF32(-6.28);
    const y = GFT16.fromBits(x.bits());
    try std.testing.expectEqual(x.bits(), y.bits());
    try std.testing.expectApproxEqAbs(x.toF32(), y.toF32(), 1e-9);
}

test "GF-T storage widths (nominal name vs real bits)" {
    // The nominal name (4/8/16/32) tags the GF lineage; ternary exponent + full
    // mantissa need a wider container than the binary rung.
    try std.testing.expectEqual(@as(u32, 6), GFT4.BITS); // 1 + 4 + 1
    try std.testing.expectEqual(@as(u32, 10), GFT8.BITS); // 1 + 5 + 4
    try std.testing.expectEqual(@as(u32, 17), GFT16.BITS); // 1 + 7 + 9
    try std.testing.expectEqual(@as(u32, 36), GFT32.BITS); // 1 + 10 + 25
}

// Exact-bit golden vectors — pin the ternary-exponent encoding. A tolerance-based
// round-trip is blind to an offset/bias shift; these pin it. Hand-check:
// GFT16(-2.5) = sign 1, |2.5| = 1.25·2^1 -> offset EXP_OFFSET+1 = 41, mant 0.25·512 =
// 128 = 0x80 -> (41<<9) | 0x80 | (1<<16) = 0x15280. Update deliberately if the codec
// layout changes.
test "GF-T: exact-bit golden vectors (encoding regression guard)" {
    const E = std.testing.expectEqual;
    // gft8 (E3 M4, offset 13)
    try E(@as(GFT8.Repr, 0x0D0), GFT8.fromF32(1.0).bits());
    try E(@as(GFT8.Repr, 0x0E0), GFT8.fromF32(2.0).bits());
    try E(@as(GFT8.Repr, 0x2D0), GFT8.fromF32(-1.0).bits());
    try E(@as(GFT8.Repr, 0x2E4), GFT8.fromF32(-2.5).bits());
    // gft16 (E4 M9, offset 40)
    try E(@as(GFT16.Repr, 0x05000), GFT16.fromF32(1.0).bits());
    try E(@as(GFT16.Repr, 0x05200), GFT16.fromF32(2.0).bits());
    try E(@as(GFT16.Repr, 0x15000), GFT16.fromF32(-1.0).bits());
    try E(@as(GFT16.Repr, 0x15280), GFT16.fromF32(-2.5).bits());
    // gft32 (E6 M25, offset 364)
    try E(@as(GFT32.Repr, 0x2D8000000), GFT32.fromF32(1.0).bits());
    try E(@as(GFT32.Repr, 0x2DA000000), GFT32.fromF32(2.0).bits());
    try E(@as(GFT32.Repr, 0xAD8000000), GFT32.fromF32(-1.0).bits());
    try E(@as(GFT32.Repr, 0xADA800000), GFT32.fromF32(-2.5).bits());
}
