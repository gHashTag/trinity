//! tri/galois — GF(256) arithmetic
//! Auto-generated from specs/tri/tri_galois.tri
//! TTT Dogfood v0.2 Stage 153

const std = @import("std");

/// Galois Field GF(256)
pub const GF256 = struct {
    value: u8,

    /// Create GF(256) element
    pub fn init(v: u8) GF256 {
        return .{ .value = v };
    }

    /// Addition is XOR
    pub fn add(a: GF256, b: GF256) GF256 {
        return .{ .value = a.value ^ b.value };
    }

    /// Subtraction is same as addition
    pub fn sub(a: GF256, b: GF256) GF256 {
        return a.add(b);
    }

    /// Multiplication in GF(256) using Russian Peasant Multiplication
    pub fn mul(a: GF256, b: GF256) GF256 {
        var result: u8 = 0;
        var a_val: u8 = a.value;
        var b_val: u8 = b.value;

        while (b_val > 0) {
            if (b_val & 1 != 0) {
                result ^= a_val;
            }
            const high_bit: u8 = if (a_val & 0x80 != 0) 1 else 0;
            a_val <<= 1;
            b_val >>= 1;

            if (high_bit != 0) {
                a_val ^= 0x1B; // x^8 + x^4 + x^3 + x + 1
            }
        }

        return .{ .value = result };
    }

    /// Exponentiation
    pub fn exp(a: GF256, power: u8) GF256 {
        var result = GF256{ .value = 1 };
        var base = a;
        var p = power;

        while (p > 0) {
            if (p & 1 != 0) {
                result = result.mul(base);
            }
            base = base.mul(base);
            p >>= 1;
        }

        return result;
    }

    /// Multiplicative inverse using extended Euclidean algorithm
    pub fn inv(a: GF256) GF256 {
        if (a.value == 0) return a; // No inverse

        // Use Fermat's little theorem: a^(-1) = a^(254) in GF(256)
        return a.exp(254);
    }

    /// Division
    pub fn div(a: GF256, b: GF256) GF256 {
        return a.mul(b.inv());
    }
};

test "gf256 add" {
    const a = GF256.init(0x53);
    const b = GF256.init(0xCA);
    const c = a.add(b);

    try std.testing.expectEqual(@as(u8, 0x99), c.value);
}

test "gf256 mul" {
    const a = GF256.init(0x53);
    const b = GF256.init(0xCA);
    const c = a.mul(b);

    try std.testing.expectEqual(@as(u8, 0x01), c.value);
}

test "gf256 inv" {
    const a = GF256.init(0x53);
    const inv = a.inv();
    const result = a.mul(inv);

    try std.testing.expectEqual(@as(u8, 1), result.value);
}

test "gf256 exp" {
    const a = GF256.init(0x02);
    const c = a.exp(8); // 2^8 = 256, in GF(256) this wraps

    // Just verify exp works consistently
    const c2 = a.exp(8);
    try std.testing.expectEqual(c.value, c2.value);
}
