// handlers.zig — Command handlers for tri-bot
// Each handler: receives args + config, runs claude CLI, sends result to Telegram
const std = @import("std");
const telegram_api = @import("telegram_api.zig");

const BotConfig = telegram_api.BotConfig;

/// /help — Send list of available commands
pub fn handleHelp(allocator: std.mem.Allocator, config: BotConfig) void {
    const help_text =
        "\xf0\x9f\xa4\x96 TRI BOT \xe2\x80\x94 Claude Code Remote Control\n" ++
        "\n" ++
        "/ask <question> \xe2\x80\x94 Ask Claude anything\n" ++
        "/continue <question> \xe2\x80\x94 Continue last session\n" ++
        "/status \xe2\x80\x94 Project status\n" ++
        "/stop \xe2\x80\x94 Stop running Claude process\n" ++
        "/help \xe2\x80\x94 This message\n" ++
        "\n" ++
        "Phase 2: /resume, /model, /board, /pr, /worktree";
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, help_text);
}

/// /ask <question> — Run claude -p "<question>" and send result
pub fn handleAsk(allocator: std.mem.Allocator, config: BotConfig, args: []const u8) void {
    if (args.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Usage: /ask <question>");
        return;
    }

    // Notify user
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa7\xa0 TRI thinking...");

    // Build turns string
    var turns_buf: [16]u8 = undefined;
    const turns_str = std.fmt.bufPrint(&turns_buf, "{d}", .{config.max_turns}) catch "10";

    // Spawn claude -p "<args>" --output-format text --max-turns N
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "claude", "-p", args, "--output-format", "text", "--max-turns", turns_str },
        .cwd = config.project_root,
        .max_output_bytes = 512 * 1024,
    }) catch |err| {
        var err_buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Claude error: {s}", .{@errorName(err)});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Claude returned empty response");
        return;
    }

    // Telegram message limit: 4096 chars. Split if needed.
    sendLongMessage(allocator, config, result.stdout);
}

/// /continue <question> — Run claude -p "<question>" --continue
pub fn handleContinue(allocator: std.mem.Allocator, config: BotConfig, args: []const u8) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x94\x84 TRI continuing...");

    var turns_buf: [16]u8 = undefined;
    const turns_str = std.fmt.bufPrint(&turns_buf, "{d}", .{config.max_turns}) catch "10";

    const argv: []const []const u8 = if (args.len > 0)
        &.{ "claude", "-p", args, "--continue", "--output-format", "text", "--max-turns", turns_str }
    else
        &.{ "claude", "--continue", "--output-format", "text", "--max-turns", turns_str };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = config.project_root,
        .max_output_bytes = 512 * 1024,
    }) catch |err| {
        var err_buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Claude error: {s}", .{@errorName(err)});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Claude returned empty response");
        return;
    }

    sendLongMessage(allocator, config, result.stdout);
}

/// /status — Run claude -p "Summarize project status in 5 lines"
pub fn handleStatus(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8a TRI checking status...");

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "claude",                                                                                                                                "-p",
            "Summarize the project status in 5 short lines: open issues count, last commit, test status, current branch, any blockers. Be concise.", "--output-format",
            "text",                                                                                                                                  "--max-turns",
            "3",
        },
        .cwd = config.project_root,
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        var err_buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Status error: {s}", .{@errorName(err)});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No status available");
        return;
    }

    sendLongMessage(allocator, config, result.stdout);
}

/// Send a potentially long message, splitting at 4096 char boundary
fn sendLongMessage(allocator: std.mem.Allocator, config: BotConfig, text: []const u8) void {
    const max_len: usize = 4000; // Leave some margin below 4096
    var pos: usize = 0;

    while (pos < text.len) {
        const end = @min(pos + max_len, text.len);
        // Try to split at a newline
        var split = end;
        if (end < text.len) {
            var j = end;
            while (j > pos + max_len / 2) : (j -= 1) {
                if (text[j] == '\n') {
                    split = j + 1;
                    break;
                }
            }
        }
        const chunk = text[pos..split];
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, chunk);
        pos = split;
    }
}
