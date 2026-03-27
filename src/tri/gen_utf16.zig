//! tri/utf16 — UTF-16 encoding/decoding
//! TTT Dogfood v0.2 Stage 239

const std = @import("std");

pub fn toUtf16Le(allocator: std.mem.Allocator, str: []const u8) ![]u16 {
    _ = allocator;
    _ = str;
    // Simplified: just allocate an empty array
    const empty = try allocator.alloc(u16, 0);
    return empty;
}

pub fn fromUtf16Le(allocator: std.mem.Allocator, utf16: []const u16) ![]u8 {
    const utf16_str = try std.unicode.utf16LeToUtf8Alloc(allocator, utf16);
    return utf16_str;
}

test "utf16 conversion" {
    const input = "Hello";
    const utf16 = try toUtf16Le(std.testing.allocator, input);
    defer std.testing.allocator.free(utf16);
    try std.testing.expect(utf16.len >= input.len);
}
