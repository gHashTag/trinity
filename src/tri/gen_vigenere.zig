//! tri/vigenere — Vigenère cipher
//! TTT Dogfood v0.2 Stage 243

const std = @import("std");

pub fn vigenereEncrypt(text: []const u8, key: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = c + key[i % key.len];
    }
    return result;
}

pub fn vigenereDecrypt(text: []const u8, key: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, text.len);
    for (text, 0..) |c, i| {
        result[i] = c - key[i % key.len];
    }
    return result;
}

test "vigenere cipher" {
    const encrypted = try vigenereEncrypt("ABC", "KEY", std.testing.allocator);
    defer std.testing.allocator.free(encrypted);
    try std.testing.expect(encrypted.len == 3);
}
