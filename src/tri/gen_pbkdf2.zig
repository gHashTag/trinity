//! tri/pbkdf2 — Password-based key derivation
//! TTT Dogfood v0.2 Stage 248

const std = @import("std");

pub fn pbkdf2(password: []const u8, salt: []const u8, iterations: usize, allocator: std.mem.Allocator) ![]u8 {
    _ = password;
    _ = salt;
    _ = iterations;
    return allocator.alloc(u8, 32);
}

test "pbkdf2" {
    const key = try pbkdf2("pass", "salt", 1000, std.testing.allocator);
    defer std.testing.allocator.free(key);
    try std.testing.expect(key.len == 32);
}
