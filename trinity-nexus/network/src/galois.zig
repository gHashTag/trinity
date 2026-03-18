// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY GALOIS FIELD v1.4 - GF(2^8) Finite Field Arithmetic
// Reed-Solomon erasure coding foundation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// GF(2^8) - Galois Field with 256 elements
// Primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 = 0x11D
// Used for Reed-Solomon erasure coding (same as RAID-6, QR codes)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GF256 = struct {
    exp_table: [512]u8, // Double-size for modular reduction convenience
    log_table: [256]u8,

    const PRIMITIVE_POLY: u16 = 0x11D; // x^8 + x^4 + x^3 + x^2 + 1
    const FIELD_SIZE: u16 = 256;

    /// Initialize GF(2^8) lookup tables using primitive polynomial 0x11D
    pub fn init() GF256 {
        var gf = GF256{
            .exp_table = undefined,
            .log_table = undefined,
        };

        // Build exponentation table: exp[i] = 2^i mod primitive_poly
        var x: u16 = 1;
        for (0..255) |i| {
            gf.exp_table[i] = @intCast(x);
            gf.exp_table[i + 255] = @intCast(x); // Duplicate for wraparound
            gf.log_table[@intCast(x)] = @intCast(i);

            // Multiply by primitive element (2) in GF(2^8)
            x = x << 1;
            if (x >= FIELD_SIZE) {
                x = x ^ PRIMITIVE_POLY;
            }
        }
        // exp[255] = 1 (wraps around), but we set it for both halves
        gf.exp_table[255] = gf.exp_table[0];
        gf.exp_table[510] = gf.exp_table[0];
        gf.log_table[0] = 0; // Convention: log(0) = 0 (undefined, but useful)

        return gf;
    }

    /// Addition in GF(2^8) is XOR
    pub fn add(_: *const GF256, a: u8, b: u8) u8 {
        return a ^ b;
    }

    /// Subtraction in GF(2^8) is also XOR (same as addition)
    pub fn sub(_: *const GF256, a: u8, b: u8) u8 {
        return a ^ b;
    }

    /// Multiplication in GF(2^8) via log/exp tables
    pub fn mul(self: *const GF256, a: u8, b: u8) u8 {
        if (a == 0 or b == 0) return 0;
        const log_a: u16 = self.log_table[a];
        const log_b: u16 = self.log_table[b];
        return self.exp_table[log_a + log_b]; // exp_table is double-size, handles wrap
    }

    /// Division in GF(2^8) via log/exp tables
    pub fn div(self: *const GF256, a: u8, b: u8) u8 {
        if (a == 0) return 0;
        if (b == 0) @panic("GF256: division by zero");
        const log_a: u16 = self.log_table[a];
        const log_b: u16 = self.log_table[b];
        // Add 255 to avoid underflow before subtraction
        return self.exp_table[log_a + 255 - log_b];
    }

    /// Exponentiation in GF(2^8): a^n
    pub fn pow(self: *const GF256, a: u8, n: u8) u8 {
        if (n == 0) return 1;
        if (a == 0) return 0;
        const log_a: u16 = self.log_table[a];
        const exp: u16 = (@as(u16, log_a) * @as(u16, n)) % 255;
        return self.exp_table[exp];
    }

    /// Multiplicative inverse in GF(2^8): a^(-1) such that a * a^(-1) = 1
    pub fn inverse(self: *const GF256, a: u8) u8 {
        if (a == 0) @panic("GF256: inverse of zero");
        return self.exp_table[255 - @as(u16, self.log_table[a])];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GF256 multiplication identity" {
    const gf = GF256.init();
    // a * 1 = a for all a
    for (0..256) |i| {
        const a: u8 = @intCast(i);
        try std.testing.expectEqual(a, gf.mul(a, 1));
        try std.testing.expectEqual(a, gf.mul(1, a));
    }
    // a * 0 = 0 for all a
    for (0..256) |i| {
        const a: u8 = @intCast(i);
        try std.testing.expectEqual(@as(u8, 0), gf.mul(a, 0));
    }
}

test "GF256 inverse" {
    const gf = GF256.init();
    // a * inverse(a) = 1 for all a != 0
    for (1..256) |i| {
        const a: u8 = @intCast(i);
        const inv = gf.inverse(a);
        try std.testing.expectEqual(@as(u8, 1), gf.mul(a, inv));
    }
}

test "GF256 add is XOR" {
    const gf = GF256.init();
    // a + a = 0 (characteristic 2)
    for (0..256) |i| {
        const a: u8 = @intCast(i);
        try std.testing.expectEqual(@as(u8, 0), gf.add(a, a));
    }
    // Commutativity: a + b = b + a
    try std.testing.expectEqual(gf.add(0x53, 0xCA), gf.add(0xCA, 0x53));
    // Identity: a + 0 = a
    try std.testing.expectEqual(@as(u8, 0x42), gf.add(0x42, 0));
}

test "GF256 tables consistency" {
    const gf = GF256.init();
    // exp[log[a]] = a for all a != 0
    for (1..256) |i| {
        const a: u8 = @intCast(i);
        try std.testing.expectEqual(a, gf.exp_table[gf.log_table[a]]);
    }
    // Primitive element 2 has order 255: 2^255 = 1
    try std.testing.expectEqual(@as(u8, 1), gf.pow(2, 255));
    // 2^0 = 1
    try std.testing.expectEqual(@as(u8, 1), gf.pow(2, 0));
}

test "GF256 division" {
    const gf = GF256.init();
    // a / a = 1 for all a != 0
    for (1..256) |i| {
        const a: u8 = @intCast(i);
        try std.testing.expectEqual(@as(u8, 1), gf.div(a, a));
    }
    // (a * b) / b = a
    const a: u8 = 0x53;
    const b: u8 = 0xCA;
    const product = gf.mul(a, b);
    try std.testing.expectEqual(a, gf.div(product, b));
    try std.testing.expectEqual(b, gf.div(product, a));
    // 0 / a = 0
    try std.testing.expectEqual(@as(u8, 0), gf.div(0, b));
}
