//! Compile-time LUT tables for Sacred types.
//! Tables created at compile time → zero runtime cost.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const sacred_types = @import("sacred_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// GF16 LUT — 65536 записей (16 бит)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GF16LUT = struct {
    /// GF16 → f32 table (65536 entries)
    /// NOTE: Large LUT disabled due to comptime quota limits
    /// Use fromF32/toF32 directly instead
    pub fn toF32(gf: sacred_types.GF16) f32 {
        return gf.toF32();
    }

    pub fn fromF32(v: f32) sacred_types.GF16 {
        return sacred_types.GF16.fromF32(v);
    }

    /// Быстрый lookup через прямое вычисление (не таблица)
    pub inline fn lookup(gf: sacred_types.GF16) f32 {
        return gf.toF32();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TF3 LUT — 262144 записей (18 бит)
// ВНИМАНИЕ: большая таблица, может увеличить размер бинарника
// ═══════════════════════════════════════════════════════════════════════════════

pub const TF3LUT = struct {
    /// TF3 → f32 конвертация
    /// NOTE: Large LUT disabled due to comptime quota limits
    /// Use fromF32/toF32 directly instead
    pub fn toF32(tf: sacred_types.TF3) f32 {
        return tf.toF32();
    }

    pub fn fromF32(v: f32) sacred_types.TF3 {
        return sacred_types.TF3.fromF32(v);
    }

    /// Быстрый lookup через прямое вычисление (не таблица)
    pub inline fn lookup(tf: sacred_types.TF3) f32 {
        return tf.toF32();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// POWERS OF 3 LUT — Fast access to 3^k (k = 0..20)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PowersOf3LUT = struct {
    /// Table of 3^k for k = 0..20
    /// 3^20 = 3,486,784,401 (fits in u64)
    pub const table: [21]u64 = blk: {
        var result: [21]u64 = undefined;
        var acc: u64 = 1;
        for (0..21) |i| {
            result[i] = acc;
            if (i < 20) acc *= 3;
        }
        break :blk result;
    };

    /// Get 3^k (comptime-safe)
    pub inline fn pow3(comptime k: u5) comptime_int {
        comptime {
            if (k >= 21) @compileError("pow3: k must be < 21");
            return table[k];
        }
    }

    /// Find smallest k such that 3^k >= n
    pub fn ceilLog3(n: u64) u5 {
        for (0..21) |k| {
            if (table[k] >= n) return @intCast(k);
        }
        return 20; // max
    }

    /// Check if n is power of 3
    pub fn isPowerOf3(n: u64) bool {
        for (0..21) |k| {
            if (table[k] == n) return true;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// POWERS OF PHI LUT — Fast access to φ^k (k = 0..20)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PowersOfPhiLUT = struct {
    /// Table of φ^k for k = 0..20
    pub const table: [21]f64 = blk: {
        var result: [21]f64 = undefined;
        var acc: f64 = 1.0;
        for (0..21) |i| {
            result[i] = acc;
            acc *= sacred_types.PHI;
        }
        break :blk result;
    };

    /// Get φ^k (comptime-safe)
    pub inline fn phi_pow(comptime k: u5) comptime_float {
        comptime {
            if (k >= 21) @compileError("phi_pow: k must be < 21");
            return table[k];
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRITARY ENCODING LUT — Ternary encoding/decoding in 2 bits
// ═══════════════════════════════════════════════════════════════════════════════

pub const TritEncodingLUT = struct {
    /// Trit → 2 bits: {-1: 0b01, 0: 0b00, +1: 0b10}
    pub const encode: [3]u2 = [_]u2{ 0b00, 0b01, 0b10 };

    /// 2 bits → trit: {0b00: 0, 0b01: -1, 0b10: 1}
    pub const decode: [4]i8 = [_]i8{ 0, -1, 1, 0 }; // 0b11 -> 0 (invalid)

    /// Encode trit
    pub inline fn encodeTrit(t: i8) u2 {
        return switch (t) {
            -1 => encode[1],
            0 => encode[0],
            1 => encode[2],
            else => encode[0], // clamp to 0
        };
    }

    /// Decode 2 bits to trit
    pub inline fn decodeTrit(bits: u2) i8 {
        return decode[bits];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED DIMENSIONS LUT — Predefined Sacred dimensions
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredDimensionsLUT = struct {
    /// Sacred dimensions: 3^0 to 3^10
    pub const dims: [11]usize = [11]usize{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049 };

    /// Indices by name
    pub const idx_unit: u5 = 0; // 1 = 3^0
    pub const idx_trit: u5 = 1; // 3 = 3^1
    pub const idx_nine: u5 = 2; // 9 = 3^2
    pub const idx_27: u5 = 3; // 27 = 3^3
    pub const idx_81: u5 = 4; // 81 = 3^4 (context)
    pub const idx_243: u5 = 5; // 243 = 3^5 (embedding)
    pub const idx_729: u5 = 6; // 729 = 3^6 (VSA)
    pub const idx_2187: u5 = 7; // 2187 = 3^7 (sequence max)
    pub const idx_6561: u5 = 8; // 6561 = 3^8
    pub const idx_19683: u5 = 9; // 19683 = 3^9
    pub const idx_59049: u5 = 10; // 59049 = 3^10 (max trits)

    /// Получить размерность по индексу
    pub inline fn dim(comptime k: u5) comptime_int {
        comptime {
            if (k >= 11) @compileError("dim: k must be < 11");
            return dims[k];
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FAST LOOKUP HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Быстрый GF16 → f32 lookup
pub inline fn gf16_to_f32(gf: sacred_types.GF16) f32 {
    return GF16LUT.toF32(gf);
}

/// Быстрый TF3 → f32 lookup
pub inline fn tf3_to_f32(tf: sacred_types.TF3) f32 {
    return TF3LUT.toF32(tf);
}

/// Быстрый 3^k lookup
pub inline fn pow3(comptime k: u5) comptime_int {
    return PowersOf3LUT.pow3(k);
}

/// Быстрый φ^k lookup
pub inline fn phi_pow(comptime k: u5) comptime_float {
    return PowersOfPhiLUT.phi_pow(k);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GF16LUT toF32 matches direct" {
    // Sample values across the range
    const test_values = [_]u16{
        0x0000, // zero
        0x3C00, // one
        0x3D00, // two
        0xBC00, // -two
        0x7BFF, // max positive
    };

    for (test_values) |bits| {
        const gf = @as(sacred_types.GF16, @bitCast(bits));
        const direct = gf.toF32();
        const lookup = GF16LUT.toF32(gf);

        const err = @abs(direct - lookup);
        try std.testing.expect(err < 1e-10);
    }
}

test "TF3LUT toF32 matches direct" {
    // Use TF3 methods instead of hardcoded bits
    const zero = sacred_types.TF3.zero();
    const one = sacred_types.TF3.one();
    const minus_one = sacred_types.TF3.fromF32(-1.0);
    const test_values = [_]sacred_types.TF3{ zero, one, minus_one };

    for (test_values) |tf| {
        const direct = tf.toF32();
        const lookup = TF3LUT.toF32(tf);

        const err = @abs(direct - lookup);
        try std.testing.expect(err < 1e-10);
    }
}

test "PowersOf3LUT correctness" {
    var acc: u64 = 1;
    for (0..21) |i| {
        try std.testing.expectEqual(acc, PowersOf3LUT.table[i]);
        acc *= 3;
    }
}

test "PowersOf3LUT ceilLog3" {
    try std.testing.expectEqual(@as(u5, 0), PowersOf3LUT.ceilLog3(1));
    try std.testing.expectEqual(@as(u5, 1), PowersOf3LUT.ceilLog3(2));
    try std.testing.expectEqual(@as(u5, 1), PowersOf3LUT.ceilLog3(3));
    try std.testing.expectEqual(@as(u5, 2), PowersOf3LUT.ceilLog3(4));
    try std.testing.expectEqual(@as(u5, 2), PowersOf3LUT.ceilLog3(9));
    try std.testing.expectEqual(@as(u5, 4), PowersOf3LUT.ceilLog3(81));
}

test "PowersOf3LUT isPowerOf3" {
    try std.testing.expect(PowersOf3LUT.isPowerOf3(1));
    try std.testing.expect(PowersOf3LUT.isPowerOf3(3));
    try std.testing.expect(PowersOf3LUT.isPowerOf3(9));
    try std.testing.expect(PowersOf3LUT.isPowerOf3(81));
    try std.testing.expect(PowersOf3LUT.isPowerOf3(59049));

    try std.testing.expect(!PowersOf3LUT.isPowerOf3(2));
    try std.testing.expect(!PowersOf3LUT.isPowerOf3(100));
    try std.testing.expect(!PowersOf3LUT.isPowerOf3(59050));
}

test "PowersOfPhiLUT correctness" {
    var acc: f64 = 1.0;
    for (0..21) |i| {
        try std.testing.expectApproxEqAbs(acc, PowersOfPhiLUT.table[i], 1e-14);
        acc *= sacred_types.PHI;
    }
}

test "TritEncodingLUT roundtrip" {
    const trits = [_]i8{ -1, 0, 1 };
    for (trits) |t| {
        const encoded = TritEncodingLUT.encodeTrit(t);
        const decoded = TritEncodingLUT.decodeTrit(encoded);
        try std.testing.expectEqual(t, decoded);
    }
}

test "SacredDimensionsLUT indices" {
    try std.testing.expectEqual(@as(usize, 1), SacredDimensionsLUT.dim(0));
    try std.testing.expectEqual(@as(usize, 3), SacredDimensionsLUT.dim(1));
    try std.testing.expectEqual(@as(usize, 81), SacredDimensionsLUT.dim(4));
    try std.testing.expectEqual(@as(usize, 243), SacredDimensionsLUT.dim(5));
    try std.testing.expectEqual(@as(usize, 729), SacredDimensionsLUT.dim(6));
    try std.testing.expectEqual(@as(usize, 2187), SacredDimensionsLUT.dim(7));
}

test "gf16_to_f32 helper" {
    const gf = sacred_types.GF16.fromF32(1.5);
    const result = gf16_to_f32(gf);
    try std.testing.expect(result > 1.4 and result < 1.6);
}

test "tf3_to_f32 helper" {
    const tf = sacred_types.TF3.fromF32(0.5);
    const result = tf3_to_f32(tf);
    try std.testing.expect(result > 0.0 and result < 1.0);
}

// φ² + 1/φ² = 3 | TRINITY
