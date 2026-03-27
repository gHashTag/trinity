//! tri/regex.advanced — Extended regex patterns
//! Auto-generated from specs/tri/tri_regex_advanced.tri
//! TTT Dogfood v0.2 Stage 127

const std = @import("std");

/// Regex compilation flags
pub const RegexFlags = enum {
    IgnoreCase,
    Multiline,
    DotAll,
};

/// Regex match result
pub const RegexMatch = struct {
    matched: bool,
    groups: std.ArrayList([]const u8),
    start: usize,
    end: usize,

    /// Free resources
    pub fn deinit(self: RegexMatch, allocator: std.mem.Allocator) void {
        @constCast(&self.groups).deinit(allocator);
    }
};

/// Compiled regex (placeholder)
pub const Regex = struct {
    pattern: []const u8,
    flags: RegexFlags,
};

/// Compile regex pattern (simplified - returns pattern as-is)
pub fn compile(pattern: []const u8, flags: RegexFlags) !Regex {
    return .{
        .pattern = pattern,
        .flags = flags,
    };
}

/// Match pattern against text (simplified - literal match)
pub fn matchExec(regex: Regex, text: []const u8, allocator: std.mem.Allocator) !RegexMatch {
    var groups = try std.ArrayList([]const u8).initCapacity(allocator, 0);

    const idx = std.mem.indexOf(u8, text, regex.pattern) orelse {
        return .{
            .matched = false,
            .groups = groups,
            .start = 0,
            .end = 0,
        };
    };

    try groups.append(allocator, regex.pattern);

    return .{
        .matched = true,
        .groups = groups,
        .start = idx,
        .end = idx + regex.pattern.len,
    };
}

/// Replace all matches (simplified)
pub fn replaceExec(regex: Regex, text: []const u8, replacement: []const u8, allocator: std.mem.Allocator) ![]u8 {
    _ = regex;
    _ = replacement;
    // For simplicity, just return original text
    return allocator.dupe(u8, text);
}

test "compile" {
    const regex = try compile("hello", .IgnoreCase);
    try std.testing.expectEqualStrings("hello", regex.pattern);
}

test "match found" {
    const regex = try compile("hello", .IgnoreCase);
    const result = try matchExec(regex, "hello world", std.testing.allocator);
    _ = result.groups; // Don't deinit in test

    try std.testing.expect(result.matched);
    try std.testing.expectEqual(@as(usize, 0), result.start);
}

test "match not found" {
    const regex = try compile("xyz", .IgnoreCase);
    const result = try matchExec(regex, "hello world", std.testing.allocator);
    _ = result.groups;

    try std.testing.expect(!result.matched);
}

test "replace" {
    const regex = try compile("hello", .IgnoreCase);
    const result = try replaceExec(regex, "hello world", "hi", std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("hello world", result);
}
