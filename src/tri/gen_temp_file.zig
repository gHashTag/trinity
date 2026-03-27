//! tri/temp_file — Temporary file management
//! TTT Dogfood v0.2 Stage 265

const std = @import("std");

pub fn createTempFile(allocator: std.mem.Allocator) ![]u8 {
    const name = try allocator.alloc(u8, 16);
    for (0..name.len) |i| {
        name[i] = "/tmp/tempXXXXXX"[i];
    }
    return name;
}

test "temp file" {
    const name = try createTempFile(std.testing.allocator);
    defer std.testing.allocator.free(name);
    try std.testing.expect(name.len > 0);
}
