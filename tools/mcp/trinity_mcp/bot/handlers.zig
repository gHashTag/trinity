// handlers.zig — Command handlers for tri-bot
// No claude CLI dependency. /status uses git directly.
const std = @import("std");
const telegram_api = @import("telegram_api.zig");

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
        "\xf0\x9f\xa4\x96 TRI BOT v2.0 \xe2\x80\x94 Direct Anthropic API\n" ++
        "\n" ++
        "/ask <question> \xe2\x80\x94 Ask Claude (streaming SSE)\n" ++
        "/model <name> \xe2\x80\x94 Set Claude model\n" ++
        "/status \xe2\x80\x94 Git project status\n" ++
        "/stop \xe2\x80\x94 Cancel active request\n" ++
        "/help \xe2\x80\x94 This message\n" ++
        "\n" ++
        "Phase 5: /continue, /resume, /sessions";
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, help_text);
}

/// /status — Show git project status (branch, commits, changes).
/// Uses git commands directly — no claude CLI.
pub fn handleStatus(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8a Checking status...");

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    out.appendSlice(allocator, "\xf0\x9f\x93\x8a Project Status\n\n") catch return;

    // Branch
    out.appendSlice(allocator, "Branch: ") catch return;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "branch", "--show-current" });

    // Recent commits
    out.appendSlice(allocator, "\nRecent commits:\n") catch return;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "log", "-5", "--oneline" });

    // Working tree changes
    out.appendSlice(allocator, "\nChanges:\n") catch return;
    const before_changes = out.items.len;
    appendCommandOutput(allocator, &out, config.project_root, &.{ "git", "status", "--short" });
    if (out.items.len == before_changes) {
        out.appendSlice(allocator, "(clean)\n") catch {};
    }

    if (out.items.len > 20) {
        telegram_api.sendLongMessage(allocator, config, out.items);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Could not get status");
    }
}

/// /model <name> — Set Claude model for subsequent requests.
pub fn handleModel(allocator: std.mem.Allocator, config: BotConfig, args: []const u8, bot_state: *BotState) void {
    if (args.len == 0) {
        // Show current model
        if (bot_state.getModel()) |model| {
            var buf: [256]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xf0\x9f\xa4\x96 Current model: {s}", .{model});
        } else {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 Model: default (claude-sonnet-4-20250514)");
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

/// /sessions — Stubbed for Phase 5.
pub fn handleSessions(allocator: std.mem.Allocator, config: BotConfig) void {
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x93\x8b Sessions: coming in Phase 5. Use /ask for new conversations.");
}

/// Run a command and append its stdout to the output buffer.
fn appendCommandOutput(allocator: std.mem.Allocator, out: *std.ArrayList(u8), cwd: []const u8, argv: []const []const u8) void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = 64 * 1024,
    }) catch {
        out.appendSlice(allocator, "(error)\n") catch {};
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        out.appendSlice(allocator, result.stdout) catch {};
        // Ensure trailing newline
        if (result.stdout[result.stdout.len - 1] != '\n') {
            out.appendSlice(allocator, "\n") catch {};
        }
    }
}
