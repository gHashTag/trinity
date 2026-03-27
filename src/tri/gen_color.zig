//! tri/color — Color manipulation
//! Auto-generated from specs/tri/tri_color.tri
//! TTT Dogfood v0.2 Stage 125

const std = @import("std");

/// Color space
pub const ColorSpace = enum {
    RGB,
    HSV,
    HSL,
    LAB,
};

/// RGBA color
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    /// Create RGB color
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    /// Create RGBA color
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Convert to hex string (#RRGGBB or #RRGGBBAA)
    pub fn toHex(self: Color, allocator: std.mem.Allocator) ![]u8 {
        const has_alpha = self.a != 255;
        const result = try allocator.alloc(u8, if (has_alpha) 9 else 7);
        result[0] = '#';

        const hex_chars = "0123456789ABCDEF";
        result[1] = hex_chars[self.r >> 4];
        result[2] = hex_chars[self.r & 0xF];
        result[3] = hex_chars[self.g >> 4];
        result[4] = hex_chars[self.g & 0xF];
        result[5] = hex_chars[self.b >> 4];
        result[6] = hex_chars[self.b & 0xF];

        if (has_alpha) {
            result[7] = hex_chars[self.a >> 4];
            result[8] = hex_chars[self.a & 0xF];
        }

        return result;
    }

    /// Linear interpolate between two colors
    pub fn blend(a: Color, b: Color, factor: f64) Color {
        const f = if (factor < 0) 0 else if (factor > 1) 1 else factor;
        return .{
            .r = @intFromFloat(@as(f64, @floatFromInt(a.r)) * (1 - f) + @as(f64, @floatFromInt(b.r)) * f),
            .g = @intFromFloat(@as(f64, @floatFromInt(a.g)) * (1 - f) + @as(f64, @floatFromInt(b.g)) * f),
            .b = @intFromFloat(@as(f64, @floatFromInt(a.b)) * (1 - f) + @as(f64, @floatFromInt(b.b)) * f),
            .a = @intFromFloat(@as(f64, @floatFromInt(a.a)) * (1 - f) + @as(f64, @floatFromInt(b.a)) * f),
        };
    }
};

test "color rgb" {
    const c = Color.rgb(255, 128, 0);
    try std.testing.expectEqual(@as(u8, 255), c.r);
    try std.testing.expectEqual(@as(u8, 128), c.g);
    try std.testing.expectEqual(@as(u8, 0), c.b);
    try std.testing.expectEqual(@as(u8, 255), c.a);
}

test "color to hex" {
    const c = Color.rgb(255, 128, 0);
    const hex = try c.toHex(std.testing.allocator);
    defer std.testing.allocator.free(hex);

    try std.testing.expectEqualStrings("#FF8000", hex);
}

test "color to hex with alpha" {
    const c = Color.rgba(255, 128, 0, 128);
    const hex = try c.toHex(std.testing.allocator);
    defer std.testing.allocator.free(hex);

    try std.testing.expectEqualStrings("#FF800080", hex);
}

test "color blend" {
    const red = Color.rgb(255, 0, 0);
    const blue = Color.rgb(0, 0, 255);
    const purple = Color.blend(red, blue, 0.5);

    try std.testing.expectEqual(@as(u8, 127), purple.r);
    try std.testing.expectEqual(@as(u8, 0), purple.g);
    try std.testing.expectEqual(@as(u8, 127), purple.b);
}
