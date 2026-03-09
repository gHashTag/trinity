// command_parser.zig — Parse /command args from Telegram message text
const std = @import("std");

pub const Command = struct {
    name: []const u8, // e.g. "ask", "status", "help"
    args: []const u8, // everything after the command name
};

/// Parse a Telegram message into a Command.
/// "/ask what is this project" → {name:"ask", args:"what is this project"}
/// "hello" → {name:"", args:"hello"} (not a command)
pub fn parse(text: []const u8) Command {
    if (text.len == 0) return .{ .name = "", .args = "" };
    if (text[0] != '/') return .{ .name = "", .args = text };

    // Skip the /
    const after_slash = text[1..];

    // Find end of command name (space or @botname or end)
    var name_end: usize = 0;
    while (name_end < after_slash.len) : (name_end += 1) {
        const c = after_slash[name_end];
        if (c == ' ' or c == '@') break;
    }

    const name = after_slash[0..name_end];

    // Skip spaces after command
    var args_start = name_end;
    // Skip @botname if present
    if (args_start < after_slash.len and after_slash[args_start] == '@') {
        while (args_start < after_slash.len and after_slash[args_start] != ' ') : (args_start += 1) {}
    }
    while (args_start < after_slash.len and after_slash[args_start] == ' ') : (args_start += 1) {}

    const args = if (args_start < after_slash.len) after_slash[args_start..] else "";

    return .{ .name = name, .args = args };
}

test "parse /ask with args" {
    const cmd = parse("/ask what is this project");
    try std.testing.expectEqualStrings("ask", cmd.name);
    try std.testing.expectEqualStrings("what is this project", cmd.args);
}

test "parse /help no args" {
    const cmd = parse("/help");
    try std.testing.expectEqualStrings("help", cmd.name);
    try std.testing.expectEqualStrings("", cmd.args);
}

test "parse /ask@bot_name with args" {
    const cmd = parse("/ask@trinity_bot hello world");
    try std.testing.expectEqualStrings("ask", cmd.name);
    try std.testing.expectEqualStrings("hello world", cmd.args);
}

test "parse plain text" {
    const cmd = parse("hello world");
    try std.testing.expectEqualStrings("", cmd.name);
    try std.testing.expectEqualStrings("hello world", cmd.args);
}

test "parse empty" {
    const cmd = parse("");
    try std.testing.expectEqualStrings("", cmd.name);
    try std.testing.expectEqualStrings("", cmd.args);
}
