//! F16 Utils — zig-hslm (official HSLM library)
//!
//! Float16 utilities for Trinity's numerical layer (Intraparietal Sulcus).
//! Official repo: https://codeberg.org/gHashTag/zig-hslm
//! Branch: feat/vector-float-cast
//!
//! Note: Due to Codeberg clone issues, this is a local copy.

const std = @import("std");

/// Float16 type alias
pub const f16 = std.meta.Float(.f16);

/// GF16 (Golden Float16) — φ-optimized packed format
pub const GF16 = packed struct(u16) {
    sign: u1,
    exponent: u11,
    mantissa: u4,

    pub fn from_f32(v: f32) GF16 {
        return @bitCast(@as(u16, @intFromFloat(v)));
    }

    pub fn to_f32(self: GF16) f32 {
        return @floatFromInt(@as(i32, @bitCast(self)));
    }
};

/// TF3 (Ternary Float3) — packed ternary format
pub const TF3 = packed struct(u16) {
    v0: u2, v1: u2, v2: u2, v3: u2,
    v4: u2, v5: u2, v6: u2, v7: u2,

    const NEG: u2 = 2;
    const ZERO: u2 = 0;
    const POS: u2 = 1;

    pub fn get(self: TF3, idx: usize) i2 {
        const values = [_]u2{ self.v0, self.v1, self.v2, self.v3, self.v4, self.v5, self.v6, self.v7 };
        return switch (values[idx]) {
            NEG => -1,
            ZERO => 0,
            POS => 1,
            else => 0,
        };
    }

    pub fn set(self: *TF3, idx: usize, val: i2) void {
        const enc = switch (val) {
            -1 => NEG, 0 => ZERO, 1 => POS, else => ZERO,
        };
        switch (idx) {
            0 => self.v0 = enc, 1 => self.v1 = enc, 2 => self.v2 = enc, 3 => self.v3 = enc,
            4 => self.v4 = enc, 5 => self.v5 = enc, 6 => self.v6 = enc, 7 => self.v7 = enc,
            else => {},
        }
    }
};

/// Safe f16 to f32 conversion
pub fn safeF16ToF32(v: f16) f32 {
    return @floatFromFloat(v);
}

/// Vector-safe float cast
pub fn vectorFloatCast(comptime T: type, src: anytype) T {
    return @floatCast(src);
}

/// Batch f16 to f32 conversion
pub fn f16BatchToF32(comptime N: usize, src: [N]f16) [N]f32 {
    var result: [N]f32 = undefined;
    for (0..N) |i| result[i] = @floatFromFloat(src[i]);
    return result;
}

/// Batch f32 to f16 conversion
pub fn f32BatchToF16(comptime N: usize, src: [N]f32) [N]f16 {
    var result: [N]f16 = undefined;
    for (0..N) |i| result[i] = @floatCast(src[i]);
    return result;
}

/// φ-weighted quantization
pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.6180339887498949;

pub fn phiQuantize(v: f32) f16 {
    return @floatCast(v * PHI_INV);
}

pub fn phiDequantize(v: f16) f32 {
    return @floatFromFloat(v) * PHI;
}

// Tests
test "f16 basic conversion" {
    const original: f32 = 3.14159;
    const f16_val: f16 = @floatCast(original);
    const f32_val: f32 = @floatFromFloat(f16_val);
    try std.testing.expect(f32_val > 3.0 and f32_val < 3.2);
}

test "TF3 encoding" {
    var tf3 = TF3{ .v0 = 0, .v1 = 0, .v2 = 0, .v3 = 0, .v4 = 0, .v5 = 0, .v6 = 0, .v7 = 0 };
    tf3.set(0, -1);
    tf3.set(1, 0);
    tf3.set(2, 1);
    try std.testing.expectEqual(@as(i2, -1), tf3.get(0));
    try std.testing.expectEqual(@as(i2, 0), tf3.get(1));
    try std.testing.expectEqual(@as(i2, 1), tf3.get(2));
}

test "φ quantization roundtrip" {
    const original: f32 = 2.71828;
    const quantized = phiQuantize(original);
    const dequantized = phiDequantize(quantized);
    const error_pct = std.math.abs((dequantized - original) / original) * 100.0;
    try std.testing.expect(error_pct < 15.0);
}
