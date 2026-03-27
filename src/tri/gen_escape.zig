//! tri/escape — String escaping utilities
//! TTT Dogfood v0.2 Stage 240

const std = @import("std");

pub fn escapeJson(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);

    for (str) |c| {
        switch (c) {
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '"' => try result.appendSlice(allocator, "\\\""),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}

test "escape json" {
    const escaped = try escapeJson(std.testing.allocator, "Hello\nWorld");
    defer std.testing.allocator.free(escaped);
    try std.testing.expect(std.mem.indexOfScalar(u8, escaped, '\\') != null);
}
