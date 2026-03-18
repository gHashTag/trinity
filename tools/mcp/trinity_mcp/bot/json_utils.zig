// json_utils.zig — Simple JSON extraction without full parser
// Pattern from ralph_hook.zig extractJsonString
const std = @import("std");

/// Extract a JSON string value by key: "key":"value"
pub fn extractString(json: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

/// Extract a JSON integer value by key: "key":123
pub fn extractInt(json: []const u8, key: []const u8) ?i64 {
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    // Skip whitespace
    var s = start;
    while (s < json.len and (json[s] == ' ' or json[s] == '\t')) : (s += 1) {}
    if (s >= json.len) return null;

    // Handle negative
    const negative = json[s] == '-';
    if (negative) s += 1;

    var end = s;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == s) return null;

    const val = std.fmt.parseInt(i64, json[s..end], 10) catch return null;
    return if (negative) -val else val;
}

/// Find all "update_id":N values and their corresponding "text":"..." in getUpdates response.
/// Calls callback for each update found.
pub fn iterateUpdates(json: []const u8, callback: *const fn (update_id: i64, chat_id: i64, text: []const u8) void) void {
    // Find each {"update_id": block
    var pos: usize = 0;
    while (pos < json.len) {
        const needle = "\"update_id\":";
        const idx = std.mem.indexOfPos(u8, json, pos, needle) orelse break;

        // Find the enclosing object boundaries (rough: next "update_id" or end)
        const next_idx = std.mem.indexOfPos(u8, json, idx + needle.len + 1, needle) orelse json.len;
        const block = json[idx..next_idx];

        const uid = extractInt(block, "update_id") orelse {
            pos = idx + needle.len;
            continue;
        };

        // Extract chat_id from nested message.chat.id — look for "chat":{"id":N
        const chat_id = blk: {
            const chat_needle = "\"chat\":{\"id\":";
            const ci = std.mem.indexOf(u8, block, chat_needle) orelse break :blk @as(i64, 0);
            const cs = ci + chat_needle.len;
            var ce = cs;
            while (ce < block.len and ((block[ce] >= '0' and block[ce] <= '9') or block[ce] == '-')) : (ce += 1) {}
            break :blk std.fmt.parseInt(i64, block[cs..ce], 10) catch 0;
        };

        const text = extractString(block, "text") orelse "";

        callback(uid, chat_id, text);
        pos = next_idx;
    }
}

test "extractString basic" {
    const json = "{\"name\":\"hello\",\"value\":\"world\"}";
    try std.testing.expectEqualStrings("hello", extractString(json, "name").?);
    try std.testing.expectEqualStrings("world", extractString(json, "value").?);
}

test "extractInt basic" {
    const json = "{\"update_id\":12345,\"count\":-7}";
    try std.testing.expectEqual(@as(i64, 12345), extractInt(json, "update_id").?);
    try std.testing.expectEqual(@as(i64, -7), extractInt(json, "count").?);
}

test "extractString missing" {
    try std.testing.expect(extractString("{}", "missing") == null);
}
