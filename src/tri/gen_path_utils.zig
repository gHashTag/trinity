//! tri/path_utils — File path utilities
//! TTT Dogfood v0.2 Stage 262

const std = @import("std");

pub fn basename(path: []const u8) []const u8 {
    const idx = std.mem.lastIndexOfScalar(u8, path, '/');
    if (idx) |i| {
        return path[i + 1 ..];
    }
    return path;
}

pub fn dirname(path: []const u8) []const u8 {
    const idx = std.mem.lastIndexOfScalar(u8, path, '/');
    if (idx) |i| {
        return path[0..i];
    }
    return ".";
}

test "path utils" {
    const path = "/home/user/file.txt";
    try std.testing.expectEqualSlices(u8, "file.txt", basename(path));
}
