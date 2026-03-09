// main.zig — TRI BOT entry point
// Telegram bot as Claude Code CLI remote control
const std = @import("std");
const bot_loop = @import("bot_loop.zig");
const telegram_api = @import("telegram_api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read configuration from environment
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse {
        std.debug.print("[tri-bot] ERROR: TELEGRAM_BOT_TOKEN not set\n", .{});
        return error.MissingConfig;
    };
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse {
        std.debug.print("[tri-bot] ERROR: TELEGRAM_CHAT_ID not set\n", .{});
        return error.MissingConfig;
    };
    const project_root = std.posix.getenv("PROJECT_ROOT") orelse
        std.posix.getenv("TRINITY_PROJECT_ROOT") orelse ".";
    const api_key = std.posix.getenv("ANTHROPIC_API_KEY") orelse {
        std.debug.print("[tri-bot] ERROR: ANTHROPIC_API_KEY not set\n", .{});
        return error.MissingConfig;
    };

    const max_turns_str = std.posix.getenv("MAX_TURNS") orelse "10";
    const max_turns = std.fmt.parseInt(u32, max_turns_str, 10) catch 10;

    const config = telegram_api.BotConfig{
        .bot_token = bot_token,
        .chat_id = chat_id,
        .project_root = project_root,
        .api_key = api_key,
        .max_turns = max_turns,
    };

    std.debug.print(
        \\[tri-bot] TRI BOT v2.0.0 (Direct API)
        \\[tri-bot] Chat ID: {s}
        \\[tri-bot] Project: {s}
        \\[tri-bot] Max turns: {d}
        \\
    , .{ chat_id, project_root, max_turns });

    // Run the bot loop (never returns)
    bot_loop.run(allocator, config);
}
