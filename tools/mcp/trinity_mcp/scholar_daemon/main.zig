// main.zig — Entry point for Scholar research agent daemon
//
// Usage:
//   zig build scholar-agent          # Run with defaults
//   zig build scholar-agent -- --single-shot   # Run once and exit
//
// Environment variables:
//   SCHOLAR_SLEEP_INTERVAL — Seconds between wakes (default: 600)
//   SCHOLAR_MAX_WAKES      — Max wake cycles, 0=infinite (default: 0)
//   PROJECT_ROOT           — Project root path (auto-detected if unset)
//   TELEGRAM_BOT_TOKEN     — Telegram bot token (optional)
//   TELEGRAM_CHAT_ID       — Telegram chat ID (optional)
//
const std = @import("std");
const scholar_loop = @import("scholar_loop.zig");
const telegram = @import("telegram");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sleep_s: []const u8 = std.posix.getenv("SCHOLAR_SLEEP_INTERVAL") orelse "600";
    const wakes_s: []const u8 = std.posix.getenv("SCHOLAR_MAX_WAKES") orelse "0";

    const sleep_interval = std.fmt.parseInt(u64, sleep_s, 10) catch 600;
    const max_wakes = std.fmt.parseInt(u32, wakes_s, 10) catch 0;

    const tg_token: []const u8 = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse "";
    const tg_chat_id: []const u8 = std.posix.getenv("TELEGRAM_CHAT_ID") orelse "";
    const tg_enabled = tg_token.len > 0 and tg_chat_id.len > 0;

    // Detect project root
    const project_root = blk: {
        if (std.posix.getenv("PROJECT_ROOT")) |root| break :blk @as([]const u8, root);
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "--show-toplevel" },
        }) catch {
            std.debug.print("[scholar] ERROR: Cannot detect project root. Set PROJECT_ROOT.\n", .{});
            std.process.exit(1);
        };
        defer allocator.free(result.stderr);
        if (result.stdout.len == 0) {
            std.debug.print("[scholar] ERROR: Not in a git repository.\n", .{});
            std.process.exit(1);
        }
        break :blk std.mem.trimRight(u8, result.stdout, &std.ascii.whitespace);
    };

    var single_shot = false;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--single-shot")) {
            single_shot = true;
        }
    }

    std.debug.print(
        \\[scholar] Scholar Research Agent v1.0.0
        \\[scholar] SCAN → RESEARCH → FEED MU → NOTIFY
        \\[scholar] ---
        \\
    , .{});

    if (tg_enabled) {
        std.debug.print("[scholar] Telegram: enabled\n", .{});
    } else {
        std.debug.print("[scholar] Telegram: disabled\n", .{});
    }

    std.debug.print("[scholar] Sleep interval: {d}s, Max wakes: {d}\n", .{ sleep_interval, max_wakes });

    try scholar_loop.run(allocator, .{
        .project_root = project_root,
        .sleep_interval_s = sleep_interval,
        .max_wakes = max_wakes,
        .single_shot = single_shot,
        .tg_config = .{
            .bot_token = tg_token,
            .chat_id = tg_chat_id,
            .enabled = tg_enabled,
        },
    });
}
