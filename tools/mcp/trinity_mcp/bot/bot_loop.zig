// bot_loop.zig — Main poll → parse → dispatch → repeat loop
// Phase 2: Two-thread arch — main thread polls, worker thread streams Claude output
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const json_utils = @import("json_utils.zig");
const command_parser = @import("command_parser.zig");
const handlers = @import("handlers.zig");
const claude_stream = @import("claude_stream.zig");

const BotConfig = telegram_api.BotConfig;

/// Shared state for streaming — module-level, accessible from main + worker threads
var stream_state = claude_stream.StreamState{};

/// Run the bot loop: poll Telegram, parse commands, dispatch handlers.
/// Never returns (infinite loop). Main thread stays responsive while
/// worker thread handles Claude streaming.
pub fn run(allocator: std.mem.Allocator, config: BotConfig) void {
    var last_update_id: i64 = 0;

    // Announce startup
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 TRI BOT v2.0 online! Send /help for commands.");

    std.debug.print("[tri-bot] Started (Phase 2: streaming). Polling Telegram...\n", .{});

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

fn dispatch(allocator: std.mem.Allocator, config: BotConfig, cmd: command_parser.Command) void {
    if (std.mem.eql(u8, cmd.name, "help")) {
        handlers.handleHelp(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "ask")) {
        // Phase 2: streaming /ask via worker thread
        if (cmd.args.len == 0) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Usage: /ask <question>");
            return;
        }
        if (stream_state.is_busy.load(.acquire)) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x8f\xb3 Already processing. Send /stop first.");
            return;
        }
        // Dupe args — they point into getUpdates body which will be freed
        const args_owned = allocator.dupe(u8, cmd.args) catch return;
        stream_state.is_busy.store(true, .release);
        _ = std.Thread.spawn(.{}, claude_stream.runStreaming, .{ allocator, config, args_owned, false, &stream_state }) catch {
            stream_state.is_busy.store(false, .release);
            allocator.free(args_owned);
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to spawn worker thread");
            return;
        };
    } else if (std.mem.eql(u8, cmd.name, "continue")) {
        // Phase 2: streaming /continue via worker thread
        if (stream_state.is_busy.load(.acquire)) {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x8f\xb3 Already processing. Send /stop first.");
            return;
        }
        const args_owned = allocator.dupe(u8, cmd.args) catch return;
        stream_state.is_busy.store(true, .release);
        _ = std.Thread.spawn(.{}, claude_stream.runStreaming, .{ allocator, config, args_owned, true, &stream_state }) catch {
            stream_state.is_busy.store(false, .release);
            allocator.free(args_owned);
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to spawn worker thread");
            return;
        };
    } else if (std.mem.eql(u8, cmd.name, "status")) {
        // Status stays blocking (short query, no streaming needed)
        handlers.handleStatus(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "stop")) {
        // Phase 2: /stop kills active Claude process
        claude_stream.stopProcess(allocator, config, &stream_state);
    } else if (cmd.name.len > 0) {
        var buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x93 Unknown command: /{s}. Try /help", .{cmd.name});
    }
    // Plain text (no command) — ignore silently
}
