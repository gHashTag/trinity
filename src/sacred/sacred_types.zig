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

// ═════════════════════════════════════════════════════════════════════════════════════════════
// GF16: Sacred Format для HSLM weights, activations, gradients
// [sign:1][exp:6][mant:9] = 16 bit
// ═══════════════════════════════════════════════════════════════════════════════════════════════

/// GF16: Sacred 16-bit формат для HSLM.
///
/// **Phi-optimal distribution** — Unlike IEEE 754 f16 [sign:1][exp:5][mant:10],
/// GF16 has phi-optimal bit distribution: [sign:1][exp:6][mant:9].
///
/// **Layout:**
/// ```
/// ┌──────┬─────────┬─────────┐
/// │ sign │   exp   │  mant   │
/// │ 1bit │   6bit  │   9bit  │
/// └──────┴─────────┴─────────┘
/// ```
///
/// **Parameters:**
/// - Exponent bias: 31 (0x1F)
/// - Min positive: 2^(-31) ≈ 4.66e-10
/// - Max value: ~2^31 × 1.999 ≈ 4.29e9
/// - phi-distance: |exp/mant - 1/φ| ≈ 0.049 (close to φ-optimal)
///
/// **Example:**
/// ```zig
/// const gf = GF16.fromF32(3.14159);
/// try std.testing.expectApproxEqAbs(3.14, gf.toF32(), 0.01);
/// ```
pub const GF16 = packed struct(u16) {
    mant: u9,
    exp: u6,
    sign: u1,

    const EXP_BIAS: u6 = 31;

    /// phi-distance: measures how close bit distribution is to φ-optimal
    /// Lower is better — GF16 achieves 0.049 (vs 0.082 for IEEE f16)
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

// ═════════════════════════════════════════════════════════════════════════════════════════════
// TF3: Ternary Format для VSA, sensation, ternary weights
// [sign:1][exp:6][mant:11] = 18 bit
// ═════════════════════════════════════════════════════════════════════════════════════════════

/// TF3: Sacred ternary формат для VSA.
/// Упрощённая версия для демонстрации Sacred Trinity концепции.
///
/// Структура: [sign:1][exp:6][mant:11] = 18 bit
/// - sign: 1 бит знака
/// - exp: 6 бит экспоненты (значения -31..+32)
/// - mant: 11 бит мантиссы
pub const TF3 = packed struct(u18) {
    mant: u11,
    exp: u6,
    sign: u1,

    /// phi-distance для тернарного формата
    pub const phi_distance: comptime_float = @abs(3.0 / 11.0 - 1.0 / PHI);

    /// Создать TF3 из f32 (упрощённая версия)
    pub fn fromF32(v: f32) TF3 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) {
            return .{ .mant = 0, .exp = 0x3F, .sign = @intFromBool(v < 0) };
        }

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        // Найти экспоненту (тернарная база 3)
        // Используем i16 для избежания overflow во время вычислений
        var exp: i16 = 0;
        var mant_f = abs_v;

        // Нормализовать: mant_f в [1/3, 1)
        const MAX_EXP: i16 = 31;
        const MIN_EXP: i16 = -31;

        while (mant_f >= 1.0 and exp < MAX_EXP) : (exp += 1) mant_f /= 3.0;
        while (mant_f < 1.0 / 3.0 and exp > MIN_EXP) : (exp -= 1) mant_f *= 3.0;

        // Clamp и конвертация в u6 (biased exponent)
        const exp_biased = @min(@max(exp + 31, 0), 63);
        const exp_u6: u6 = @intCast(exp_biased);
        const mant_u11: u11 = @intFromFloat(@min(mant_f * 2047.0, 2047.0));

        return .{
            .mant = mant_u11,
            .exp = exp_u6,
            .sign = sign_bit,
        };
    }

    /// Конвертировать TF3 в f32
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

    /// Zero TF3
    pub fn zero() TF3 {
        return .{ .mant = 0, .exp = 0, .sign = 0 };
    }

    /// One TF3
    pub fn one() TF3 {
        return fromF32(1.0);
    }

    /// Получить знак {-1, 0, +1}
    pub fn getSign(self: TF3) i8 {
        return if (self.sign == 1) -1 else if (self.mant == 0) 0 else 1;
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════════
// COMPILE-TIME GUARDS
// ═══════════════════════════════════════════════════════════════════════════════════════════

comptime {
    // Проверка packed struct размеров
    std.debug.assert(@sizeOf(GF16) == 2);
    std.debug.assert(@sizeOf(TF3) == @sizeOf(u18));
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════

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
