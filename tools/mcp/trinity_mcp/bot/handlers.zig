// handlers.zig — Command handlers for tri-bot
// Each handler: receives args + config, runs claude CLI, sends result to Telegram
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const json_utils = @import("json_utils.zig");

const BotConfig = telegram_api.BotConfig;

/// Runtime state that persists across commands within a bot run.
pub const BotState = struct {
    model_buf: [64]u8 = undefined,
    model_len: usize = 0,

    pub fn getModel(self: *const BotState) ?[]const u8 {
        if (self.model_len == 0) return null;
        return self.model_buf[0..self.model_len];
    }

    pub fn setModel(self: *BotState, name: []const u8) void {
        const len = @min(name.len, self.model_buf.len);
        @memcpy(self.model_buf[0..len], name[0..len]);
        self.model_len = len;
    }
};

/// /help — Send list of available commands
pub fn handleHelp(allocator: std.mem.Allocator, config: BotConfig) void {
    const help_text =
        "\xf0\x9f\xa4\x96 TRI BOT \xe2\x80\x94 Claude Code Remote Control\n" ++
        "\n" ++
        "/ask <question> \xe2\x80\x94 Ask Claude (streaming)\n" ++
        "/continue [msg] \xe2\x80\x94 Continue session\n" ++
        "/resume <id> \xe2\x80\x94 Resume session by ID\n" ++
        "/sessions \xe2\x80\x94 List recent sessions\n" ++
        "/model <name> \xe2\x80\x94 Set Claude model\n" ++
        "/status \xe2\x80\x94 Project status\n" ++
        "/stop \xe2\x80\x94 Stop running process\n" ++
        "/help \xe2\x80\x94 This message\n" ++
        "\n" ++
        "Phase 3: /board, /pr, /worktree";
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
    telegram_api.sendLongMessage(allocator, config, result.stdout);
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

    telegram_api.sendLongMessage(allocator, config, result.stdout);
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

    telegram_api.sendLongMessage(allocator, config, result.stdout);
}

/// /model <name> — Set Claude model for subsequent requests.
pub fn handleModel(allocator: std.mem.Allocator, config: BotConfig, args: []const u8, bot_state: *BotState) void {
    if (args.len == 0) {
        // Show current model
        if (bot_state.getModel()) |model| {
            var buf: [256]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xf0\x9f\xa4\x96 Current model: {s}", .{model});
        } else {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 Model: default (no override)");
        }
        return;
    }

    if (args.len > 64) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Model name too long (max 64 chars)");
        return;
    }

    bot_state.setModel(args);
    var buf: [256]u8 = undefined;
    telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9c\x85 Model set: {s}", .{args});
}

/// /sessions — List recent Claude sessions.
pub fn handleSessions(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8b Fetching sessions...");

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "claude", "sessions", "list", "--json" },
        .cwd = config.project_root,
        .max_output_bytes = 128 * 1024,
    }) catch |err| {
        var err_buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &err_buf, "\xe2\x9d\x8c Sessions error: {s}", .{@errorName(err)});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No sessions found");
        return;
    }

    // Format sessions: extract id + summary from JSON array
    var out_buf: std.ArrayList(u8) = .empty;
    defer out_buf.deinit(allocator);

    out_buf.appendSlice(allocator, "\xf0\x9f\x93\x8b Recent sessions:\n") catch return;
    formatSessions(allocator, &out_buf, result.stdout);

    if (out_buf.items.len > 20) {
        telegram_api.sendLongMessage(allocator, config, out_buf.items);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Could not parse sessions");
    }
}

/// Parse JSON session list and append formatted entries to output buffer.
fn formatSessions(allocator: std.mem.Allocator, out: *std.ArrayList(u8), json: []const u8) void {
    var count: usize = 0;
    var pos: usize = 0;
    const id_needle = "\"session_id\":\"";

    while (pos < json.len and count < 10) {
        const idx = std.mem.indexOfPos(u8, json, pos, id_needle) orelse break;
        const id_start = idx + id_needle.len;
        const id_end = std.mem.indexOfPos(u8, json, id_start, "\"") orelse break;
        const session_id = json[id_start..id_end];

        // Try to find summary near this session entry
        const block_end = std.mem.indexOfPos(u8, json, id_end, id_needle) orelse json.len;
        const block = json[idx..block_end];
        const summary = json_utils.extractString(block, "summary") orelse
            json_utils.extractString(block, "name") orelse "(no summary)";

        count += 1;
        var num_buf: [4]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{count}) catch "?";
        out.appendSlice(allocator, num_str) catch {};
        out.appendSlice(allocator, ". ") catch {};
        // Show short ID (first 8 chars or full if shorter)
        const short_id = if (session_id.len > 8) session_id[0..8] else session_id;
        out.appendSlice(allocator, short_id) catch {};
        out.appendSlice(allocator, " \xe2\x80\x94 ") catch {};
        // Truncate summary to 60 chars
        const max_sum: usize = 60;
        const sum_display = if (summary.len > max_sum) summary[0..max_sum] else summary;
        out.appendSlice(allocator, sum_display) catch {};
        if (summary.len > max_sum) out.appendSlice(allocator, "...") catch {};
        out.appendSlice(allocator, "\n") catch {};

        pos = block_end;
    }

    if (count == 0) {
        out.appendSlice(allocator, "(no sessions found)\n") catch {};
    }
}
