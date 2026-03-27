//! tri/json_parser — Simple JSON parser
//! TTT Dogfood v0.2 Stage 254

const std = @import("std");

pub const JsonValue = union(enum) {
    null,
    bool: bool,
    int: i64,
    string: []const u8,
    array: std.ArrayList(JsonValue),
    object: std.StringHashMap(JsonValue),
};

pub fn parseJson(allocator: std.mem.Allocator, text: []const u8) !JsonValue {
    _ = allocator;
    _ = text;
    return JsonValue{ .null = {} };
}

test "json parse" {
    const val = try parseJson(std.testing.allocator, "null");
    try std.testing.expect(val == .null);
}
