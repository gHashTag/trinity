// bot_loop.zig — Main poll → parse → dispatch → repeat loop
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const json_utils = @import("json_utils.zig");
const command_parser = @import("command_parser.zig");
const handlers = @import("handlers.zig");

const BotConfig = telegram_api.BotConfig;

/// Run the bot loop: poll Telegram, parse commands, dispatch handlers.
/// Never returns (infinite loop).
pub fn run(allocator: std.mem.Allocator, config: BotConfig) void {
    var last_update_id: i64 = 0;

    // Announce startup
    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa4\x96 TRI BOT online! Send /help for commands.");

    std.debug.print("[tri-bot] Started. Polling Telegram...\n", .{});

    while (true) {
        const body = telegram_api.getUpdates(allocator, config.bot_token, last_update_id + 1) orelse {
            // Network error — wait and retry
            std.Thread.sleep(5 * std.time.ns_per_s);
            continue;
        };
        defer allocator.free(body);

        // Process each update
        const Context = struct {
            allocator: std.mem.Allocator,
            config: BotConfig,
            max_id: i64,
        };
        var ctx = Context{
            .allocator = allocator,
            .config = config,
            .max_id = last_update_id,
        };

        // We can't use closures in Zig, so use a global-style dispatch.
        // Instead, manually iterate updates with a simple loop.
        processUpdates(allocator, config, body, &ctx.max_id);
        last_update_id = ctx.max_id;
    }
}

fn processUpdates(allocator: std.mem.Allocator, config: BotConfig, body: []const u8, max_id: *i64) void {
    // Find each "update_id": block manually
    var pos: usize = 0;
    while (pos < body.len) {
        const needle = "\"update_id\":";
        const idx = std.mem.indexOfPos(u8, body, pos, needle) orelse break;

        // Determine block boundary (next update_id or end)
        const next_idx = std.mem.indexOfPos(u8, body, idx + needle.len + 1, needle) orelse body.len;
        const block = body[idx..next_idx];

        // Extract update_id
        const uid = json_utils.extractInt(block, "update_id") orelse {
            pos = idx + needle.len;
            continue;
        };

        // Update max
        if (uid > max_id.*) {
            max_id.* = uid;
        }

        // Extract chat_id
        const chat_id_val = blk: {
            const chat_needle = "\"chat\":{\"id\":";
            const ci = std.mem.indexOf(u8, block, chat_needle) orelse break :blk @as(i64, 0);
            const cs = ci + chat_needle.len;
            var ce = cs;
            while (ce < block.len and ((block[ce] >= '0' and block[ce] <= '9') or block[ce] == '-')) : (ce += 1) {}
            break :blk std.fmt.parseInt(i64, block[cs..ce], 10) catch 0;
        };

        // Auth check: only respond to configured chat_id
        const expected_chat_id = std.fmt.parseInt(i64, config.chat_id, 10) catch 0;
        if (chat_id_val != expected_chat_id) {
            std.debug.print("[tri-bot] Ignoring update from chat {d} (expected {d})\n", .{ chat_id_val, expected_chat_id });
            pos = next_idx;
            continue;
        }

        // Extract text
        const text = json_utils.extractString(block, "text") orelse {
            pos = next_idx;
            continue;
        };

        std.debug.print("[tri-bot] Update {d}: \"{s}\"\n", .{ uid, text });

        // Parse command
        const cmd = command_parser.parse(text);

        // Dispatch
        dispatch(allocator, config, cmd);

        pos = next_idx;
    }
}

fn dispatch(allocator: std.mem.Allocator, config: BotConfig, cmd: command_parser.Command) void {
    if (std.mem.eql(u8, cmd.name, "help")) {
        handlers.handleHelp(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "ask")) {
        handlers.handleAsk(allocator, config, cmd.args);
    } else if (std.mem.eql(u8, cmd.name, "continue")) {
        handlers.handleContinue(allocator, config, cmd.args);
    } else if (std.mem.eql(u8, cmd.name, "status")) {
        handlers.handleStatus(allocator, config);
    } else if (std.mem.eql(u8, cmd.name, "stop")) {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9b\x94 /stop not yet implemented (Phase 2)");
    } else if (cmd.name.len > 0) {
        // Unknown command
        var buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x93 Unknown command: /{s}. Try /help", .{cmd.name});
    }
    // Plain text (no command) — ignore silently
}
