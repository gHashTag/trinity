//! Sacred Types — единственный источник правды для форматов Trinity.
//! Везде использовать только эти типы; сырой f16/u16/i8 запрещён.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Золотое сечение φ = (1 + √5) / 2
pub const PHI = 1.6180339887498948482;
pub const PHI_SQ = PHI * PHI;
pub const INV_PHI = 1.0 / PHI;
pub const TRINITY = PHI_SQ + 1.0 / PHI_SQ; // = 3.0

// Compile-time верификация Sacred констант
comptime {
    if (@abs(TRINITY - 3.0) > 1e-15)
        @compileError("φ² + 1/φ² ≠ 3 — Trinity math broken!");
}

// ═══════════════════════════════════════════════════════════════════════════════
// GF16: Sacred Format для HSLM weights, activations, gradients
// [sign:1][exp:6][mant:9] = 16 bit
// ═══════════════════════════════════════════════════════════════════════════════

/// GF16: Sacred 16-bit формат для HSLM.
/// В отличие от IEEE 754 f16 [sign:1][exp:5][mant:10],
/// GF16 имеет phi-оптимальное распределение: [sign:1][exp:6][mant:9].
///
/// Биас экспоненты = 31 (0x1F), мантисса = 9 бит.
/// Минимальное положительное: 2^(-31) ≈ 4.66e-10
/// Максимальное: ~2^31 × 1.999 ≈ 4.29e9
pub const GF16 = packed struct(u16) {
    mant: u9,
    exp: u6,
    sign: u1,

    const EXP_BIAS: u6 = 31;

    /// phi-distance: насколько распределение бит оптимально относительно φ
    pub const phi_distance: comptime_float = @abs(6.0 / 9.0 - 1.0 / PHI);

    /// Создать GF16 из f32
    pub fn fromF32(v: f32) GF16 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x3F, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Найти экспоненту
        var exp: i8 = 0;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp < 31) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -32) : (exp -= 1) mant_f *= 2.0;

        const exp_i8: i8 = exp;
        const exp_bias: i8 = EXP_BIAS;
        const exp_u6: u6 = @intCast(exp_bias + exp_i8);
        const mant_u9: u9 = @intFromFloat((mant_f - 0.5) * 512.0);

        return .{
            .mant = @min(mant_u9, 511),
            .exp = exp_u6,
            .sign = sign_bit,
        };
    }

    /// Конвертировать GF16 в f32
    pub fn toF32(self: GF16) f32 {
        if (self.exp == 0 and self.mant == 0) {
            return if (self.sign == 1) -0.0 else 0.0;
        }
        if (self.exp == 0x3F) {
            return if (self.sign == 1) -std.math.inf(f32) else std.math.inf(f32);
        }

        const exp_unbiased = @as(i32, self.exp) - EXP_BIAS;
        const mant_f = 0.5 + @as(f32, @floatFromInt(self.mant)) / 512.0;
        const value = mant_f * std.math.pow(f32, 2.0, @floatFromInt(exp_unbiased));

        return if (self.sign == 1) -value else value;
    }

    /// Сложение GF16 (через f32 для точности)
    pub fn add(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() + b.toF32());
    }

    /// Вычитание GF16
    pub fn sub(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() - b.toF32());
    }

    /// Умножение GF16
    pub fn mul(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() * b.toF32());
    }

    /// Деление GF16
    pub fn div(a: GF16, b: GF16) GF16 {
        return fromF32(a.toF32() / b.toF32());
    }

    /// Zero GF16
    pub fn zero() GF16 {
        return .{ .mant = 0, .exp = 0, .sign = 0 };
    }

    /// One GF16
    pub fn one() GF16 {
        return fromF32(1.0);
    }

    /// Negate GF16
    pub fn neg(self: GF16) GF16 {
        return .{
            .mant = self.mant,
            .exp = self.exp,
            .sign = if (self.sign == 1) 0 else 1,
        };
    }

    /// Абсолютное значение
    pub fn abs(self: GF16) GF16 {
        return .{
            .mant = self.mant,
            .exp = self.exp,
            .sign = 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TF3: Ternary Format для VSA, sensation, ternary weights
// [sign_trit:2][exp_trits:6][mant_trits:10] = 18 bit
// ═══════════════════════════════════════════════════════════════════════════════

/// TF3: Sacred ternary формат для VSA.
/// Каждый трит кодируется 2 битами: {-1=01, 0=00, +1=10}
///
/// Структура: [sign_trit:2][exp_trits:6][mant_trits:10] = 18 bit
/// - sign_trit: знак числа {-1, 0, +1}
/// - exp_trits: 3 трита экспоненты (2^(-4) до 2^+4)
/// - mant_trits: 5 тритов мантиссы
///
/// φ-distance оптимально для тернарного резонанса 3^k
pub const TF3 = packed struct(u18) {
    mant_trits: u10,  // 5 тритов × 2 бита
    exp_trits: u6,    // 3 трита × 2 бита
    sign_trit: u2,    // {-1=01, 0=00, +1=10}

    /// phi-distance для тернарного формата
    pub const phi_distance: comptime_float = @abs(3.0 / 5.0 - 1.0 / PHI);

    /// Кодировка трита в 2 бита
    const TRIT_MINUS: u2 = 0b01;
    const TRIT_ZERO: u2 = 0b00;
    const TRIT_PLUS: u2 = 0b10;

    /// Декодировать 2 бита в трит
    fn decodeTrit(bits: u2) i8 {
        return switch (bits) {
            TRIT_MINUS => -1,
            TRIT_ZERO => 0,
            TRIT_PLUS => 1,
            0b11 => 0, // invalid -> zero
        };
    }

    /// Кодировать трит в 2 бита
    fn encodeTrit(t: i8) u2 {
        return switch (t) {
            -1 => TRIT_MINUS,
            0 => TRIT_ZERO,
            1 => TRIT_PLUS,
            else => TRIT_ZERO,
        };
    }

    /// Создать TF3 из f32
    pub fn fromF32(v: f32) TF3 {
        if (v == 0.0) return .{
            .mant_trits = 0,
            .exp_trits = 0,
            .sign_trit = TRIT_ZERO,
        };
        if (!std.math.isFinite(v)) {
            return .{
                .mant_trits = 0,
                .exp_trits = 0x3F, // max exp
                .sign_trit = if (v < 0) TRIT_MINUS else TRIT_PLUS,
            };
        }

        const abs_v = @abs(v);

        // Найти тернарную экспоненту (-4 до +4)
        var exp_i8: i8 = -4;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp_i8 < 4) : (exp_i8 += 1) mant_f /= 3.0;
        while (mant_f < 1.0 / 3.0 and exp_i8 > -4) : (exp_i8 -= 1) mant_f *= 3.0;

        // Кодировать триты экспоненты
        const exp_u8: u8 = @intCast(exp_i8 + 4);
        const exp_trits_u6: u6 = @intCast(encodeTrits3(exp_u8));

        // Тернарная мантисса (5 тритов: -121, -120, ..., 0, ..., +120, +121)
        const mant_i8: i8 = @intFromFloat(mant_f * 121.0);
        const mant_clamped = @max(-121, @min(121, mant_i8));
        const mant_trits_u10: u10 = encodeTrits5(@intCast(mant_clamped + 121));

        const sign_trit_u2: u2 = if (v < 0) TRIT_MINUS else TRIT_PLUS;

        return .{
            .mant_trits = mant_trits_u10,
            .exp_trits = exp_trits_u6,
            .sign_trit = sign_trit_u2,
        };
    }

    /// Конвертировать TF3 в f32
    pub fn toF32(self: TF3) f32 {
        const sign = decodeTrit(self.sign_trit);
        if (sign == 0) return 0.0;

        // Декодировать экспоненту (3 трита: 0..7 -> -4..+3)
        const exp_raw = decodeTrits3(self.exp_trits);
        const exp_val = @as(i8, @intCast(exp_raw)) - 4;

        // Декодировать мантиссу (5 тритов: 0..242 -> -121..+121)
        const mant_raw = decodeTrits5(self.mant_trits);
        const mant_i16 = @as(i16, @intCast(mant_raw)) - 121;
        const mant_val: i8 = @intCast(mant_i16);

        const value = @as(f32, @floatFromInt(mant_val)) / 121.0
            * std.math.pow(f32, 3.0, @floatFromInt(exp_val));

        return @as(f32, @floatFromInt(sign)) * value;
    }

    /// Кодировать 3 трита (0..26) в 6 бит
    fn encodeTrits3(v: u8) u6 {
        var result: u6 = 0;
        var i: u3 = 0;
        var val = v;
        while (i < 3 and val > 0) : (i += 1) {
            const trit = @rem(val, 3);
            const bits = encodeTrit(@intCast(if (trit == 2) -1 else trit));
            result |= @as(u6, bits) << @as(u3, i * 2);
            val /= 3;
        }
        return result;
    }

    /// Декодировать 3 трита из 6 бит (0..26)
    fn decodeTrits3(bits: u6) u8 {
        var result: u8 = 0;
        var power: u8 = 1;
        inline for (0..3) |i| {
            const trit_bits = @as(u2, @truncate(bits >> @as(u3, @intCast(i * 2))));
            const trit = decodeTrit(trit_bits);
            result += @as(u8, @intCast(if (trit == -1) 2 else trit)) * power;
            power *= 3;
        }
        return result;
    }

    /// Кодировать 5 тритов (0..242) в 10 бит
    fn encodeTrits5(v: u8) u10 {
        var result: u10 = 0;
        var i: u4 = 0;
        var val = v;
        while (i < 5 and val > 0) : (i += 1) {
            const trit = @rem(val, 3);
            const bits = encodeTrit(@intCast(if (trit == 2) -1 else trit));
            result |= @as(u10, bits) << @as(u4, i * 2);
            val /= 3;
        }
        return result;
    }

    /// Декодировать 5 тритов из 10 бит (0..242)
    fn decodeTrits5(bits: u10) u8 {
        var result: u8 = 0;
        var power: u8 = 1;
        inline for (0..5) |i| {
            const trit_bits = @as(u2, @truncate(bits >> @as(u4, @intCast(i * 2))));
            const trit = decodeTrit(trit_bits);
            result += @as(u8, @intCast(if (trit == -1) 2 else trit)) * power;
            power *= 3;
        }
        return result;
    }

    /// Zero TF3
    pub fn zero() TF3 {
        return .{
            .mant_trits = 0,
            .exp_trits = 0,
            .sign_trit = TRIT_ZERO,
        };
    }

    /// One TF3
    pub fn one() TF3 {
        return fromF32(1.0);
    }

    /// Получить знак как трит {-1, 0, +1}
    pub fn getSign(self: TF3) i8 {
        return decodeTrit(self.sign_trit);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMPILE-TIME GUARDS
// ═══════════════════════════════════════════════════════════════════════════════

comptime {
    // Проверка packed struct размеров
    std.debug.assert(@sizeOf(GF16) == 2);
    std.debug.assert(@sizeOf(TF3) == @sizeOf(u18));

    // Проверка phi-distance
    std.debug.assert(GF16.phi_distance < 0.1);
    std.debug.assert(TF3.phi_distance < 0.1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GF16 zero and one" {
    const zero = GF16.zero();
    try std.testing.expectEqual(@as(f32, 0), zero.toF32());

    const one = GF16.one();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), one.toF32(), 0.01);
}

test "GF16 roundtrip positive" {
    const values = [_]f32{ 0.0, 0.5, 1.0, 2.0, 3.14, 100.0, 1000.0 };
    for (values) |v| {
        const gf = GF16.fromF32(v);
        const result = gf.toF32();
        const err = @abs(v - result) / @abs(v + 0.001);
        try std.testing.expect(err < 0.05); // 5% error tolerance
    }
}

test "GF16 roundtrip negative" {
    const values = [_]f32{ -0.5, -1.0, -2.0, -3.14, -100.0 };
    for (values) |v| {
        const gf = GF16.fromF32(v);
        const result = gf.toF32();
        const err = @abs(v - result) / @abs(v + 0.001);
        try std.testing.expect(err < 0.05);
    }
}

test "GF16 add" {
    const a = GF16.fromF32(1.5);
    const b = GF16.fromF32(2.5);
    const sum = GF16.add(a, b);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), sum.toF32(), 0.05);
}

test "GF16 mul" {
    const a = GF16.fromF32(2.0);
    const b = GF16.fromF32(3.0);
    const product = GF16.mul(a, b);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), product.toF32(), 0.1);
}

test "GF16 neg and abs" {
    const v = GF16.fromF32(3.14);
    const neg = v.neg();
    try std.testing.expect(neg.toF32() < -3.0);

    const abs = neg.abs();
    try std.testing.expect(abs.toF32() > 3.0);
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
        const tf = TF3.fromF32(v);
        const result = tf.toF32();
        const err = @abs(v - result) / @abs(v + 0.001);
        try std.testing.expect(err < 0.5); // Ternary format less precise
    }
}

test "TF3 sign encoding" {
    const plus = TF3.fromF32(1.0);
    const zero = TF3.zero();
    const minus = TF3.fromF32(-1.0);

    try std.testing.expectEqual(@as(i8, 1), plus.getSign());
    try std.testing.expectEqual(@as(i8, 0), zero.getSign());
    try std.testing.expectEqual(@as(i8, -1), minus.getSign());
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
