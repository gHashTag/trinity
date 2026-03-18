// tool_protocol.zig — JSON build/parse for Anthropic Messages API tool_use protocol
// Manual string scanning — no third-party JSON parser, same pattern as bot/json_utils.zig.
const std = @import("std");

// ─── Types ───────────────────────────────────────────────────────────────────

pub const ToolUseBlock = struct {
    id: []const u8,
    name: []const u8,
    input_json: []const u8,
};

pub const ContentBlock = union(enum) {
    text: []const u8,
    tool_use: ToolUseBlock,
};

pub const ParsedResponse = struct {
    blocks: std.ArrayList(ContentBlock),
    stop_reason: []const u8, // "end_turn" | "tool_use" | "max_tokens"
    input_tokens: u32,
    output_tokens: u32,

    pub fn deinit(self: *ParsedResponse, allocator: std.mem.Allocator) void {
        self.blocks.deinit(allocator);
    }
};

// ─── Response parsing ────────────────────────────────────────────────────────

/// Parse an Anthropic Messages API response body into typed blocks.
/// Scans for "type":"text" and "type":"tool_use" content blocks.
pub fn parseResponse(allocator: std.mem.Allocator, body: []const u8) ParsedResponse {
    var result = ParsedResponse{
        .blocks = std.ArrayList(ContentBlock).empty,
        .stop_reason = "end_turn",
        .input_tokens = 0,
        .output_tokens = 0,
    };

    // Extract stop_reason
    if (extractField(body, "stop_reason")) |sr| {
        result.stop_reason = sr;
    }

    // Extract usage tokens
    if (extractField(body, "input_tokens")) |it| {
        result.input_tokens = std.fmt.parseInt(u32, it, 10) catch 0;
    }
    if (extractField(body, "output_tokens")) |ot| {
        result.output_tokens = std.fmt.parseInt(u32, ot, 10) catch 0;
    }

    // Find content blocks by scanning for "type":"text" and "type":"tool_use"
    var pos: usize = 0;
    while (pos < body.len) {
        // Look for "type":"text"
        if (std.mem.indexOfPos(u8, body, pos, "\"type\":\"text\"")) |idx| {
            const tool_idx = std.mem.indexOfPos(u8, body, pos, "\"type\":\"tool_use\"") orelse body.len;
            if (idx < tool_idx) {
                // Text block — extract "text" field near this position
                const block_start = if (idx >= 50) idx - 50 else 0;
                const block_end = @min(idx + 8192, body.len);
                const block = body[block_start..block_end];
                if (extractFieldAfter(block, "text", "\"type\":\"text\"")) |text_val| {
                    result.blocks.append(allocator, .{ .text = text_val }) catch |err| {
                        std.log.debug("tool_protocol: failed to append text block: {}", .{err});
                    };
                }
                pos = idx + 12;
                continue;
            }
        }

        // Look for "type":"tool_use"
        if (std.mem.indexOfPos(u8, body, pos, "\"type\":\"tool_use\"")) |idx| {
            const block_end = findBlockEnd(body, idx);
            const block = body[idx..block_end];

            const id = extractField(block, "id") orelse "unknown";
            const name = extractField(block, "name") orelse "unknown";
            // Extract input as raw JSON object
            const input_json = extractObject(body, idx, "input") orelse "{}";

            result.blocks.append(allocator, .{ .tool_use = .{
                .id = id,
                .name = name,
                .input_json = input_json,
            } }) catch |err| {
                std.log.debug("tool_protocol: failed to append tool_use block: {}", .{err});
            };
            pos = block_end;
            continue;
        }

        break; // No more content blocks
    }

    return result;
}

// ─── Request building ────────────────────────────────────────────────────────

/// Write tool definitions for the 4 built-in tools (no outer brackets).
pub fn writeToolDefinitions(writer: anytype) !void {
    try writer.writeAll(
        \\{"name":"read_file","description":"Read a file at the given path","input_schema":{"type":"object","properties":{"path":{"type":"string","description":"File path to read"}},"required":["path"]}},
        \\{"name":"write_file","description":"Write content to a file","input_schema":{"type":"object","properties":{"path":{"type":"string","description":"File path"},"content":{"type":"string","description":"Content to write"}},"required":["path","content"]}},
        \\{"name":"bash","description":"Run a bash command","input_schema":{"type":"object","properties":{"command":{"type":"string","description":"Shell command to execute"}},"required":["command"]}},
        \\{"name":"grep","description":"Search files with grep -rn","input_schema":{"type":"object","properties":{"pattern":{"type":"string","description":"Search pattern"},"path":{"type":"string","description":"Directory to search (default: .)"}},"required":["pattern"]}}
    );
}

/// Write a tool_result content block as JSON.
pub fn writeToolResult(writer: anytype, tool_use_id: []const u8, content: []const u8, is_error: bool) !void {
    try writer.writeAll("{\"type\":\"tool_result\",\"tool_use_id\":\"");
    try writer.writeAll(tool_use_id);
    try writer.writeAll("\",\"content\":\"");
    try writeJsonEscaped(writer, content);
    try writer.writeByte('"');
    if (is_error) {
        try writer.writeAll(",\"is_error\":true");
    }
    try writer.writeByte('}');
}

/// Write a JSON-escaped string (handles \n, \r, \t, \\, \", control chars).
pub fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => {
                try writer.print("\\u{x:0>4}", .{c});
            },
            else => try writer.writeByte(c),
        }
    }
}

// ─── JSON field extraction (shared with tool_executor) ───────────────────────

/// Extract a JSON string value: "key":"value" → "value"
pub fn extractField(data: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, data, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= data.len) return null;

    var end = start;
    while (end < data.len) : (end += 1) {
        if (data[end] == '"' and (end == start or data[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return data[start..end];
}

/// Extract a JSON string value starting from a given position.
pub fn extractFieldFrom(data: []const u8, start: usize, key: []const u8) ?[]const u8 {
    if (start >= data.len) return null;
    return extractField(data[start..], key);
}

/// Extract a JSON string field that appears AFTER a marker string.
fn extractFieldAfter(data: []const u8, key: []const u8, after: []const u8) ?[]const u8 {
    const marker_pos = std.mem.indexOf(u8, data, after) orelse return null;
    const search_region = data[marker_pos..];
    return extractField(search_region, key);
}

/// Extract a JSON object value: "key":{...} → {...}
fn extractObject(data: []const u8, search_start: usize, key: []const u8) ?[]const u8 {
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":", .{key}) catch return null;

    const idx = std.mem.indexOfPos(u8, data, search_start, needle) orelse return null;
    var start = idx + needle.len;

    // Skip whitespace
    while (start < data.len and (data[start] == ' ' or data[start] == '\t' or data[start] == '\n')) : (start += 1) {}
    if (start >= data.len or data[start] != '{') return null;

    // Match braces
    var depth: u32 = 0;
    var end = start;
    var in_string = false;
    while (end < data.len) : (end += 1) {
        if (in_string) {
            if (data[end] == '"' and (end == 0 or data[end - 1] != '\\')) in_string = false;
            continue;
        }
        switch (data[end]) {
            '"' => in_string = true,
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return data[start .. end + 1];
            },
            else => {},
        }
    }
    return null;
}

/// Find the end of a content block (next "type": or end of content array).
fn findBlockEnd(data: []const u8, start: usize) usize {
    // Look for next "type" after current position
    const search_start = start + 10;
    if (search_start >= data.len) return data.len;
    if (std.mem.indexOfPos(u8, data, search_start, "\"type\":")) |next| {
        // Walk back to find the comma or bracket before it
        var pos = next;
        while (pos > start and data[pos] != '{') : (pos -= 1) {}
        return pos;
    }
    return data.len;
}

/// Unescape a JSON string: \\n → \n, \\t → \t, \\\\ → \\, \\" → "
pub fn unescapeString(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '\\' and i + 1 < s.len) {
            switch (s[i + 1]) {
                'n' => {
                    out.append(allocator, '\n') catch return error.OutOfMemory;
                    i += 1;
                },
                't' => {
                    out.append(allocator, '\t') catch return error.OutOfMemory;
                    i += 1;
                },
                'r' => {
                    out.append(allocator, '\r') catch return error.OutOfMemory;
                    i += 1;
                },
                '\\' => {
                    out.append(allocator, '\\') catch return error.OutOfMemory;
                    i += 1;
                },
                '"' => {
                    out.append(allocator, '"') catch return error.OutOfMemory;
                    i += 1;
                },
                else => out.append(allocator, s[i]) catch return error.OutOfMemory,
            }
        } else {
            out.append(allocator, s[i]) catch return error.OutOfMemory;
        }
    }
    return out.toOwnedSlice(allocator) catch return error.OutOfMemory;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test "extractField basic" {
    const data = "{\"name\":\"hello\",\"value\":\"world\"}";
    try std.testing.expectEqualStrings("hello", extractField(data, "name").?);
    try std.testing.expectEqualStrings("world", extractField(data, "value").?);
    try std.testing.expect(extractField(data, "missing") == null);
}

test "extractField stop_reason" {
    const data =
        \\{"stop_reason":"tool_use","usage":{"input_tokens":100}}
    ;
    try std.testing.expectEqualStrings("tool_use", extractField(data, "stop_reason").?);
}

test "extractObject basic" {
    const data =
        \\{"name":"read_file","input":{"path":"build.zig"}}
    ;
    const obj = extractObject(data, 0, "input").?;
    try std.testing.expectEqualStrings("{\"path\":\"build.zig\"}", obj);
}

test "unescapeString" {
    const allocator = std.testing.allocator;
    const result = try unescapeString(allocator, "hello\\nworld\\t!");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello\nworld\t!", result);
}

test "writeJsonEscaped" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeJsonEscaped(fbs.writer(), "line1\nline2\ttab\"quote");
    try std.testing.expectEqualStrings("line1\\nline2\\ttab\\\"quote", fbs.getWritten());
}
