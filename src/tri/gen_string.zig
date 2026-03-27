//! TRI String — Generated from specs/tri/string.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub fn concat(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, a.len + b.len);
    @memcpy(result[0..a.len], a);
    @memcpy(result[a.len..], b);
    return result;
}

pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

pub fn startsWith(s: []const u8, prefix: []const u8) bool {
    if (s.len < prefix.len) return false;
    return std.mem.eql(u8, s[0..prefix.len], prefix);
}

pub fn endsWith(s: []const u8, suffix: []const u8) bool {
    if (s.len < suffix.len) return false;
    return std.mem.eql(u8, s[s.len - suffix.len ..], suffix);
}

pub fn toUpper(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
    }
    return result;
}

pub fn toLower(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return result;
}

test "String: concat" {
    const allocator = std.testing.allocator;
    const result = try concat(allocator, "hello", " world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "String: trim" {
    try std.testing.expectEqualStrings("test", trim("  test  "));
}

test "String: contains" {
    try std.testing.expect(contains("hello world", "world"));
}

test "String: startsWith" {
    try std.testing.expect(startsWith("hello", "he"));
}

test "String: endsWith" {
    try std.testing.expect(endsWith("hello", "lo"));
}

test "String: toUpper" {
    const allocator = std.testing.allocator;
    const result = try toUpper(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}

test "String: toLower" {
    const allocator = std.testing.allocator;
    const result = try toLower(allocator, "HELLO");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}
