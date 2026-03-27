//! tri/caesar — Caesar cipher
//! TTT Dogfood v0.2 Stage 242

const std = @import("std");

pub fn caesarEncrypt(text: []const u8, shift: u8, allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = c + shift;
    }
    return result;
}

pub fn caesarDecrypt(text: []const u8, shift: u8, allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = c - shift;
    }
    return result;
}

test "caesar cipher" {
    const encrypted = try caesarEncrypt("ABC", 1, std.testing.allocator);
    defer std.testing.allocator.free(encrypted);
    try std.testing.expectEqual(@as(u8, 'B'), encrypted[0]);
}
