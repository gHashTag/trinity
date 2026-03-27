// GF(2^8) Galois Field — Generated from specs/crypto/gf256.tri
// Primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 = 0x11D
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const PRIMITIVE_POLY: u16 = 0x11D;
pub const FIELD_SIZE: u16 = 256;

pub const GF256 = struct {
    exp_table: [512]u8,
    log_table: [256]u8,

    pub fn init() GF256 {
        var gf = GF256{
            .exp_table = undefined,
            .log_table = undefined,
        };

        var x: u16 = 1;
        for (0..255) |i| {
            gf.exp_table[i] = @intCast(x);
            gf.exp_table[i + 255] = @intCast(x);
            gf.log_table[@intCast(x)] = @intCast(i);

            x = x << 1;
            if (x >= FIELD_SIZE) {
                x = x ^ PRIMITIVE_POLY;
            }
        }
        gf.exp_table[255] = gf.exp_table[0];
        gf.exp_table[510] = gf.exp_table[0];
        gf.log_table[0] = 0;

        return gf;
    }

    pub fn add(_: *const GF256, a: u8, b: u8) u8 {
        return a ^ b;
    }

    pub fn sub(_: *const GF256, a: u8, b: u8) u8 {
        return a ^ b;
    }

    pub fn mul(self: *const GF256, a: u8, b: u8) u8 {
        if (a == 0 or b == 0) return 0;
        const log_a: u16 = self.log_table[a];
        const log_b: u16 = self.log_table[b];
        return self.exp_table[log_a + log_b];
    }

    pub fn div(self: *const GF256, a: u8, b: u8) !u8 {
        if (a == 0) return 0;
        if (b == 0) return error.DivisionByZero;
        const log_a: u16 = self.log_table[a];
        const log_b: u16 = self.log_table[b];
        return self.exp_table[log_a + 255 - log_b];
    }

    pub fn pow(self: *const GF256, a: u8, n: u8) u8 {
        if (n == 0) return 1;
        if (a == 0) return 0;
        const log_a: u16 = self.log_table[a];
        const exp: u16 = (@as(u16, log_a) * @as(u16, n)) % 255;
        return self.exp_table[exp];
    }

    pub fn inverse(self: *const GF256, a: u8) !u8 {
        if (a == 0) return error.InverseOfZero;
        return self.exp_table[255 - @as(u16, self.log_table[a])];
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "GF256 multiplication identity" {
    const gf = GF256.init();
    try std.testing.expectEqual(@as(u8, 1), gf.mul(1, 1));
    try std.testing.expectEqual(@as(u8, 42), gf.mul(42, 1));
}

test "GF256 multiplication commutative" {
    const gf = GF256.init();
    try std.testing.expectEqual(gf.mul(7, 13), gf.mul(13, 7));
}

test "GF256 division" {
    const gf = GF256.init();
    const a: u8 = 15;
    const b: u8 = 7;
    const result = try gf.div(a, b);
    try std.testing.expectEqual(a, gf.mul(result, b));
}

test "GF256 inverse" {
    const gf = GF256.init();
    const a: u8 = 13;
    const inv = try gf.inverse(a);
    try std.testing.expectEqual(@as(u8, 1), gf.mul(a, inv));
}

test "GF256 add same as sub" {
    const gf = GF256.init();
    try std.testing.expectEqual(gf.add(10, 15), gf.sub(10, 15));
}

test "GF256 zero handling" {
    const gf = GF256.init();
    try std.testing.expectEqual(@as(u8, 0), gf.mul(0, 42));
    try std.testing.expectEqual(@as(u8, 0), gf.mul(42, 0));
    try std.testing.expectEqual(@as(u8, 1), gf.pow(42, 0));
    try std.testing.expectEqual(@as(u8, 0), gf.pow(0, 5));
}
