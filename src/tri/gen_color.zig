//! tri/color — Color operations
//! TTT Dogfood v0.2 Stage 276

const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn toHex(color: Color) [7]u8 {
        return [_]u8{
            '#',
            intToHex(color.r / 16),
            intToHex(color.r % 16),
            intToHex(color.g / 16),
            intToHex(color.g % 16),
            intToHex(color.b / 16),
            intToHex(color.b % 16),
        };
    }
};

fn intToHex(v: u8) u8 {
    return if (v < 10) '0' + v else 'a' + v - 10;
}

test "color" {
    const c = Color.rgb(255, 0, 0);
    const hex = c.toHex();
    try std.testing.expectEqual(@as(u8, '#'), hex[0]);
}
