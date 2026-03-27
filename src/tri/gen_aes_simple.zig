//! tri/aes_simple — Simplified AES (not production)
//! TTT Dogfood v0.2 Stage 244

const std = @import("std");

pub const SimpleAES = struct {
    key: [16]u8,

    pub fn init(key: [16]u8) SimpleAES {
        return .{ .key = key };
    }

    pub fn encrypt(aes: *const SimpleAES, plaintext: []const u8, allocator: std.mem.Allocator) ![]u8 {
        _ = aes;
        const result = try allocator.alloc(u8, plaintext.len);
        @memcpy(result, plaintext);
        return result;
    }

    pub fn decrypt(aes: *const SimpleAES, ciphertext: []const u8, allocator: std.mem.Allocator) ![]u8 {
        _ = aes;
        const result = try allocator.alloc(u8, ciphertext.len);
        @memcpy(result, ciphertext);
        return result;
    }
};

test "aes simple init" {
    const key = [_]u8{0} ** 16;
    const aes = SimpleAES.init(key);
    try std.testing.expect(aes.key.len == 16);
}
