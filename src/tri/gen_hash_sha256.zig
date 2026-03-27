//! tri/hash_sha256 — SHA-256 placeholder
//! TTT Dogfood v0.2 Stage 246

const std = @import("std");

pub fn sha256(data: []const u8) [32]u8 {
    _ = data;
    return [_]u8{0} ** 32;
}

test "sha256" {
    const hash = sha256("test");
    try std.testing.expect(hash.len == 32);
}
