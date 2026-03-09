// ralph_hook.zig — Tiny binary for Claude Code hooks → Telegram
//
// Called by Claude Code hooks (type: "command"):
//   Reads JSON from stdin: {hook_event_name, tool_name, tool_input, tool_output}
//   Formats and sends to Telegram via sendMessage
//
// Usage in .claude-plugin/hooks/hooks.json:
//   "command": "$CLAUDE_PROJECT_DIR/zig-out/bin/ralph-hook"
//
// Env vars: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
const std = @import("std");
const telegram = @import("telegram.zig");

pub fn main() !void {
    // Read Telegram config from env
    const bot_token: []const u8 = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse return;
    const chat_id: []const u8 = std.posix.getenv("TELEGRAM_CHAT_ID") orelse return;
    const config = telegram.TelegramConfig{
        .bot_token = bot_token,
        .chat_id = chat_id,
        .enabled = true,
    };

    // Read hook JSON from stdin via posix.read
    var input_buf: [65536]u8 = undefined;
    var total: usize = 0;
    while (total < input_buf.len) {
        const n = std.posix.read(0, input_buf[total..]) catch break;
        if (n == 0) break;
        total += n;
    }
    if (total == 0) return;
    const input = input_buf[0..total];

    // Extract fields via simple string search
    const event = extractJsonString(input, "hook_event_name") orelse "unknown";
    const tool = extractJsonString(input, "tool_name") orelse "";

    // Format message based on event type
    var buf: [512]u8 = undefined;
    const msg = if (std.mem.eql(u8, event, "PostToolUse"))
        std.fmt.bufPrint(&buf, "<b>ralph</b> | {s} done", .{truncate(tool, 40)}) catch return
    else if (std.mem.eql(u8, event, "PostToolUseFailure"))
        std.fmt.bufPrint(&buf, "<b>ralph</b> | {s} FAILED", .{truncate(tool, 40)}) catch return
    else if (std.mem.eql(u8, event, "PreToolUse"))
        std.fmt.bufPrint(&buf, "<b>ralph</b> | {s}...", .{truncate(tool, 40)}) catch return
    else if (std.mem.eql(u8, event, "Stop"))
        std.fmt.bufPrint(&buf, "<b>ralph</b> | Session finished", .{}) catch return
    else if (std.mem.eql(u8, event, "SessionStart"))
        std.fmt.bufPrint(&buf, "<b>ralph</b> | Session started", .{}) catch return
    else
        return; // Unknown event, skip

    telegram.send(config, msg);
}

/// Extract a JSON string value by key using simple pattern matching.
/// Looks for "key":"value" in the input.
fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Build needle: "key":"
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;

    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    // Find closing quote (skip escaped quotes)
    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

fn truncate(s: []const u8, max: usize) []const u8 {
    return if (s.len <= max) s else s[0..max];
}

test "extractJsonString basic" {
    const json = "{\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Bash\"}";
    const event = extractJsonString(json, "hook_event_name") orelse return error.NotFound;
    try std.testing.expectEqualStrings("PostToolUse", event);
    const tool = extractJsonString(json, "tool_name") orelse return error.NotFound;
    try std.testing.expectEqualStrings("Bash", tool);
}

test "extractJsonString missing key" {
    const json = "{\"hook_event_name\":\"Stop\"}";
    try std.testing.expect(extractJsonString(json, "tool_name") == null);
}
