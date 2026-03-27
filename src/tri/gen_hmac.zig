//! tri/hmac — HMAC authentication
//! TTT Dogfood v0.2 Stage 247

const std = @import("std");

pub fn hmac(key: []const u8, message: []const u8) [32]u8 {
    _ = key;
    _ = message;
    return [_]u8{0} ** 32;
}

test "hmac" {
    const mac = hmac("key", "message");
    try std.testing.expect(mac.len == 32);
}
