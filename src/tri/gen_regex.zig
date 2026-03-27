//! tri/regex — Simple pattern matching
//! Auto-generated from specs/tri/tri_regex.tri
//! TTT Dogfood v0.2 Stage 102

const std = @import("std");

/// Compiled pattern (simplified)
pub const Regex = struct {
    pattern: []const u8 = "",
    compiled: bool = false,

    /// Parse regex pattern (simplified - just stores literal)
    pub fn compile(pattern: []const u8, allocator: std.mem.Allocator) !Regex {
        _ = allocator;
        return .{ .pattern = pattern, .compiled = true };
    }
};

/// Pattern match result
pub const Match = struct {
    start: usize = 0,
    end: usize = 0,
    groups: std.ArrayList([]const u8),

    /// Create empty match
    pub fn init(allocator: std.mem.Allocator) !Match {
        return .{ .groups = try std.ArrayList([]const u8).initCapacity(allocator, 0) };
    }

    /// Free resources
    pub fn deinit(self: *Match) void {
        self.groups.deinit();
    }
};

/// Find first match or null (literal match only for v0.1)
pub fn match(regex: Regex, text: []const u8) ?Match {
    if (!regex.compiled) return null;
    if (regex.pattern.len == 0) return null;

    // Simple literal search
    const idx = std.mem.indexOf(u8, text, regex.pattern) orelse return null;
    return .{
        .start = idx,
        .end = idx + regex.pattern.len,
        .groups = undefined,
    };
}

/// Find all matches
pub fn findAll(regex: Regex, text: []const u8, allocator: std.mem.Allocator) ![]Match {
    var list = try std.ArrayList(Match).initCapacity(allocator, 0);

    if (!regex.compiled or regex.pattern.len == 0) {
        return list.toOwnedSlice(allocator);
    }

    var start: usize = 0;
    while (start < text.len) {
        const idx = std.mem.indexOfScalarPos(u8, text, regex.pattern[0], start) orelse break;
        if (idx + regex.pattern.len > text.len) break;

        if (std.mem.eql(u8, text[idx..][0..regex.pattern.len], regex.pattern)) {
            try list.append(allocator, .{
                .start = idx,
                .end = idx + regex.pattern.len,
                .groups = undefined,
            });
            start = idx + regex.pattern.len;
        } else {
            start += 1;
        }
    }

    return list.toOwnedSlice(allocator);
}

test "Regex.compile" {
    const regex = try Regex.compile("test", std.testing.allocator);
    try std.testing.expect(regex.compiled);
}

test "match literal" {
    const regex = try Regex.compile("hello", std.testing.allocator);
    const result = match(regex, "hello world");
    try std.testing.expect(result != null);
    if (result) |m| {
        try std.testing.expectEqual(@as(usize, 0), m.start);
        try std.testing.expectEqual(@as(usize, 5), m.end);
    }
}

test "match not found" {
    const regex = try Regex.compile("xyz", std.testing.allocator);
    const result = match(regex, "hello world");
    try std.testing.expect(result == null);
}
