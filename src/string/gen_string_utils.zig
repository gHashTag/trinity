//! String Utilities — Generated from string_utils.tri spec
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from string_utils.tri spec
//! Modify spec and regenerate: tri vibee-gen string_utils

const std = @import("std");

/// ═══════════════════════════════════════════════════════════════════════════
/// STRING TRIMMING
/// ═══════════════════════════════════════════════════════════════════════════
/// Trim leading and trailing whitespace
pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, &std.ascii.whitespace);
}

/// Trim leading whitespace only
pub fn trimLeft(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len and std.ascii.isWhitespace(s[start])) {
        start += 1;
    }
    return s[start..];
}

/// Trim trailing whitespace only
pub fn trimRight(s: []const u8) []const u8 {
    var end: usize = s.len;
    while (end > 0 and std.ascii.isWhitespace(s[end - 1])) {
        end -= 1;
    }
    return s[0..end];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// STRING SEARCHING
/// ═══════════════════════════════════════════════════════════════════════════
/// Check if string starts with prefix
pub fn startsWith(s: []const u8, prefix: []const u8) bool {
    if (prefix.len > s.len) return false;
    return std.mem.eql(u8, s[0..prefix.len], prefix);
}

/// Check if string ends with suffix
pub fn endsWith(s: []const u8, suffix: []const u8) bool {
    if (suffix.len > s.len) return false;
    const start = s.len - suffix.len;
    return std.mem.eql(u8, s[start..], suffix);
}

/// Find substring in string
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// STRING VALIDATION
/// ═══════════════════════════════════════════════════════════════════════════════
/// Check if all characters are ASCII
pub fn isAscii(s: []const u8) bool {
    for (s) |c| {
        if (c > 127) return false;
    }
    return true;
}

/// Check if string is alphanumeric (ASCII)
pub fn isAlnum(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
        const is_digit = c >= '0' and c <= '9';
        if (!is_alpha and !is_digit) return false;
    }
    return true;
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// STRING COMPARISON
/// ═══════════════════════════════════════════════════════════════════════════════
/// Case-insensitive string comparison (ASCII only)
pub fn equalCaseInsensitive(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const lower_a = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lower_b = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (lower_a != lower_b) return false;
    }
    return true;
}

/// ═════════════════════════════════════════════════════════════════════════════════════
/// STRING CONCATENATION
/// ═══════════════════════════════════════════════════════════════════════════════
/// Join strings with separator
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8, sep: []const u8) ![]u8 {
    if (parts.len == 0) return allocator.dupe(u8, "");

    var total_len: usize = 0;
    for (parts) |part| {
        total_len += part.len;
    }
    total_len += sep.len * (parts.len - 1);

    var result = try allocator.alloc(u8, total_len);
    var offset: usize = 0;

    for (parts, 0..) |part, i| {
        @memcpy(result[offset .. offset + part.len], part);
        offset += part.len;
        if (i < parts.len - 1) {
            @memcpy(result[offset .. offset + sep.len], sep);
            offset += sep.len;
        }
    }

    return result;
}

/// ═══════════════════════════════════════════════════════════════════════════════════
/// STRING PARSING
/// ═════════════════════════════════════════════════════════════════════════════════

// Split function omitted due to Zig 0.15 ArrayList API changes

/// Parse i64 from string
pub fn parseInt(s: []const u8) !i64 {
    return std.fmt.parseInt(i64, s, 10);
}

/// Format i64 to string
pub fn formatInt(allocator: std.mem.Allocator, n: i64) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{n});
}

/// Convert string to lowercase (ASCII only) - uses allocator
pub fn toLowerAlloc(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return result;
}

/// Convert string to uppercase (ASCII only) - uses allocator
pub fn toUpperAlloc(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════

test "trim removes whitespace" {
    try std.testing.expectEqualSlices(u8, "hello", trim("  hello  "));
    try std.testing.expectEqualSlices(u8, "test", trim("\t\n test\r\n"));
}

test "trimLeft removes leading only" {
    try std.testing.expectEqualSlices(u8, "test  ", trimLeft("  test  "));
}

test "trimRight removes trailing only" {
    try std.testing.expectEqualSlices(u8, "  test", trimRight("  test  "));
}

test "startsWith finds prefix" {
    try std.testing.expect(startsWith("hello world", "hello"));
    try std.testing.expect(!startsWith("hello", "hello world"));
    try std.testing.expect(startsWith("", ""));
}

test "endsWith finds suffix" {
    try std.testing.expect(endsWith("hello world", "world"));
    try std.testing.expect(!endsWith("world", "hello world"));
}

test "contains finds substring" {
    try std.testing.expect(contains("hello world", "lo wo"));
    try std.testing.expect(!contains("hello", "xyz"));
}

test "toLowerAlloc converts case" {
    const allocator = std.testing.allocator;
    const result = try toLowerAlloc(allocator, "HeLLo");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "hello", result);
}

test "toUpperAlloc converts case" {
    const allocator = std.testing.allocator;
    const result = try toUpperAlloc(allocator, "HeLLo");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "HELLO", result);
}

test "isAscii checks characters" {
    try std.testing.expect(isAscii("hello"));
    try std.testing.expect(!isAscii("héllo"));
    try std.testing.expect(!isAscii("test\xff"));
}

test "isAlnum checks alphanumeric" {
    try std.testing.expect(isAlnum("abc123"));
    try std.testing.expect(!isAlnum("abc 123"));
    try std.testing.expect(!isAlnum(""));
}

test "equalCaseInsensitive ignores case" {
    try std.testing.expect(equalCaseInsensitive("Hello", "hello"));
    try std.testing.expect(!equalCaseInsensitive("hello", "world"));
}

test "join combines strings" {
    const allocator = std.testing.allocator;
    const parts = [_][]const u8{ "a", "b", "c" };
    const result = try join(allocator, &parts, "-");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "a-b-c", result);
}

test "parseInt parses numbers" {
    try std.testing.expectEqual(@as(i64, 42), try parseInt("42"));
    try std.testing.expectEqual(@as(i64, -7), try parseInt("-7"));
    try std.testing.expectError(error.InvalidCharacter, parseInt("abc"));
}

test "formatInt creates string" {
    const allocator = std.testing.allocator;
    const result = try formatInt(allocator, 12345);
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "12345", result);
}
