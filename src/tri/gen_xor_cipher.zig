//! tri/xor_cipher — XOR cipher encryption
//! TTT Dogfood v0.2 Stage 241

const std = @import("std");

pub fn xorCrypt(data: []const u8, key: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, data.len);
    for (data, 0..) |b, i| {
        result[i] = b ^ key[i % key.len];
    }
    return result;
}

test "xor cipher" {
    const data = "Hello";
    const key = "key";
    const encrypted = try xorCrypt(data, key, std.testing.allocator);
    defer std.testing.allocator.free(encrypted);
    try std.testing.expect(encrypted.len == data.len);
}
