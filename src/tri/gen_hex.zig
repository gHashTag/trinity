//! tri/hex — Hexadecimal encoding
//! Auto-generated from specs/tri/tri_hex.tri
//! TTT Dogfood v0.2 Stage 98

const std = @import("std");

/// Hex codec
pub const Hex = struct {
    uppercase: bool,

    /// Lowercase a-f encoder
    pub fn lowerCase() Hex {
        return .{ .uppercase = false };
    }

    /// Uppercase A-F encoder
    pub fn upperCase() Hex {
        return .{ .uppercase = true };
    }

    /// Convert bytes to hex string
    pub fn encode(codec: Hex, input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        const output = try allocator.alloc(u8, input.len * 2);
        const alphabet = if (codec.uppercase) "0123456789ABCDEF" else "0123456789abcdef";

        for (input, 0..) |byte, i| {
            output[i * 2] = alphabet[byte >> 4];
            output[i * 2 + 1] = alphabet[byte & 0x0F];
        }

        return output;
    }

    /// Parse hex string to bytes
    pub fn decode(input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        if (input.len % 2 != 0) return error.InvalidLength;

        const output = try allocator.alloc(u8, input.len / 2);

        for (0..input.len / 2) |i| {
            const high = try charToVal(input[i * 2]);
            const low = try charToVal(input[i * 2 + 1]);
            output[i] = (high << 4) | low;
        }

        return output;
    }

    fn charToVal(c: u8) !u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => error.InvalidCharacter,
        };
    }
};

test "Hex.encode lower" {
    const codec = Hex.lowerCase();
    const result = try codec.encode(&[_]u8{ 0xDE, 0xAD, 0xBE, 0xEF }, std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "deadbeef", result);
}

test "Hex.encode upper" {
    const codec = Hex.upperCase();
    const result = try codec.encode(&[_]u8{ 0xDE, 0xAD, 0xBE, 0xEF }, std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "DEADBEEF", result);
}

test "Hex.decode" {
    const result = try Hex.decode("deadbeef", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xDE, 0xAD, 0xBE, 0xEF }, result);
}

test "Hex.decode uppercase" {
    const result = try Hex.decode("DEADBEEF", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xDE, 0xAD, 0xBE, 0xEF }, result);
}
