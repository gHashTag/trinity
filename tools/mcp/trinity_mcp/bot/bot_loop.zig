// bot_loop.zig — Main poll → parse → dispatch → repeat loop
// v2.0: Direct Anthropic API (no claude CLI)
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const json_utils = @import("json_utils.zig");
const command_parser = @import("command_parser.zig");
const handlers = @import("handlers.zig");
const claude_stream = @import("claude_stream.zig");

const BotConfig = telegram_api.BotConfig;

/// Shared state for streaming — module-level, accessible from main + worker threads
var stream_state = claude_stream.StreamState{};

/// Runtime state — model selection, persists across commands within a bot run
var bot_state = handlers.BotState{};

/// Run the bot loop: poll Telegram, parse commands, dispatch handlers.
/// Never returns (infinite loop). Main thread stays responsive while
/// worker thread handles Claude streaming.
pub fn run(allocator: std.mem.Allocator, config: BotConfig) void {
    var last_update_id: i64 = 0;

    // Announce startup
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 TRI BOT v3.0 online! Send /help for commands.");

    std.debug.print("[tri-bot] Started (Phase 2.5: streaming + sessions). Polling Telegram...\n", .{});

    while (true) {
        const body = telegram_api.getUpdates(allocator, config.bot_token, last_update_id + 1) orelse {
            // Network error — wait and retry
            std.Thread.sleep(5 * std.time.ns_per_s);
            continue;
        };
        defer allocator.free(body);

        var max_id = last_update_id;
        processUpdates(allocator, config, body, &max_id);
        last_update_id = max_id;
    }
}

fn processUpdates(allocator: std.mem.Allocator, config: BotConfig, body: []const u8, max_id: *i64) void {
    var pos: usize = 0;
    while (pos < body.len) {
        const needle = "\"update_id\":";
        const idx = std.mem.indexOfPos(u8, body, pos, needle) orelse break;

        const next_idx = std.mem.indexOfPos(u8, body, idx + needle.len + 1, needle) orelse body.len;
        const block = body[idx..next_idx];

        const uid = json_utils.extractInt(block, "update_id") orelse {
            pos = idx + needle.len;
            continue;
        };

        if (uid > max_id.*) {
            max_id.* = uid;
        }

        // Extract chat_id from nested message.chat.id
        const chat_id_val = blk: {
            const chat_needle = "\"chat\":{\"id\":";
            const ci = std.mem.indexOf(u8, block, chat_needle) orelse break :blk @as(i64, 0);
            const cs = ci + chat_needle.len;
            var ce = cs;
            while (ce < block.len and ((block[ce] >= '0' and block[ce] <= '9') or block[ce] == '-')) : (ce += 1) {}
            break :blk std.fmt.parseInt(i64, block[cs..ce], 10) catch 0;
        };

        // Auth check
        const expected_chat_id = std.fmt.parseInt(i64, config.chat_id, 10) catch 0;
        if (chat_id_val != expected_chat_id) {
            std.debug.print("[tri-bot] Ignoring update from chat {d}\n", .{chat_id_val});
            pos = next_idx;
            continue;
        }

        const text = json_utils.extractString(block, "text") orelse {
            pos = next_idx;
            continue;
        };

        std.debug.print("[tri-bot] Update {d}: \"{s}\"\n", .{ uid, text });

        const cmd = command_parser.parse(text);
        dispatch(allocator, config, cmd);

        pos = next_idx;
    }
}

/// Helper: check if busy + spawn streaming worker thread.
fn spawnStreaming(allocator: std.mem.Allocator, config: BotConfig, opts: claude_stream.StreamOpts) void {
    stream_state.is_busy.store(true, .release);
    _ = std.Thread.spawn(.{}, claude_stream.runStreaming, .{ allocator, config, opts, &stream_state }) catch {
        stream_state.is_busy.store(false, .release);
        allocator.free(opts.args);
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to spawn worker thread");
        return;
    };
}

fn dispatch(allocator: std.mem.Allocator, config: BotConfig, cmd: command_parser.Command) void {
    if (std.mem.eql(u8, cmd.name, "help")) {
        handlers.handleHelp(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "ask")) {
        // Streaming /ask via worker thread
        if (cmd.args.len == 0) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Usage: /ask <question>");
            return;
        }
        if (stream_state.is_busy.load(.acquire)) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x8f\xb3 Already processing. Send /stop first.");
            return;
        }
        const args_owned = allocator.dupe(u8, cmd.args) catch return;
        spawnStreaming(allocator, config, .{
            .args = args_owned,
            .model = bot_state.getModel(),
        });
    } else if (std.mem.eql(u8, cmd.name, "resume") or std.mem.eql(u8, cmd.name, "continue")) {
        // Resume a session: /resume [id] or /continue (latest)
        if (stream_state.is_busy.load(.acquire)) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x8f\xb3 Already processing. Send /stop first.");
            return;
        }
        const session_id = if (cmd.args.len > 0) cmd.args else "";
        const history = handlers.loadSessionMessages(allocator, session_id) orelse {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No session found. Use /sessions to list.");
            return;
        };
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\x94\x84 Resuming session. Send your next message with /ask.");
        // For now, free the loaded history — full streaming resume requires a follow-up /ask
        allocator.free(history);
    } else if (std.mem.eql(u8, cmd.name, "model")) {
        // Blocking: set/show model
        handlers.handleModel(allocator, config, cmd.args, &bot_state);
    } else if (std.mem.eql(u8, cmd.name, "sessions")) {
        // Blocking: list sessions
        handlers.handleSessions(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "status")) {
        // Blocking: project status
        handlers.handleStatus(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "stop")) {
        // Cancel active streaming request
        claude_stream.stopProcess(allocator, config, &stream_state);
    } else if (cmd.name.len > 0) {
        var buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x93 Unknown command: /{s}. Try /help", .{cmd.name});
    }
    // Plain text (no command) — ignore silently
}
