// main.zig — Entry point for MU self-healing agent daemon
//
// Usage:
//   zig build mu-agent          # Run with defaults
//   zig build mu-agent -- --single-shot   # Run once and exit
//
// Environment variables:
//   MU_SLEEP_INTERVAL   — Seconds between wakes (default: 300)
//   MU_MAX_WAKES        — Max wake cycles, 0=infinite (default: 0)
//   PROJECT_ROOT        — Project root path (auto-detected if unset)
//   TELEGRAM_BOT_TOKEN  — Telegram bot token (optional, enables TG reporting)
//   TELEGRAM_CHAT_ID    — Telegram chat ID (optional, enables TG reporting)
//
const std = @import("std");
const mu_loop = @import("mu_loop.zig");
const telegram = @import("telegram");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Optional config from env
    const sleep_s: []const u8 = std.posix.getenv("MU_SLEEP_INTERVAL") orelse "300";
    const wakes_s: []const u8 = std.posix.getenv("MU_MAX_WAKES") orelse "0";

    const sleep_interval = std.fmt.parseInt(u64, sleep_s, 10) catch 300;
    const max_wakes = std.fmt.parseInt(u32, wakes_s, 10) catch 0;

    // Telegram reporting (optional)
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
            std.debug.print("[mu-agent] ERROR: Cannot detect project root. Set PROJECT_ROOT.\n", .{});
            std.process.exit(1);
        };
        defer allocator.free(result.stderr);
        if (result.stdout.len == 0) {
            std.debug.print("[mu-agent] ERROR: Not in a git repository.\n", .{});
            std.process.exit(1);
        }
        break :blk std.mem.trimRight(u8, result.stdout, &std.ascii.whitespace);
    };

    // Parse CLI args for --single-shot
    var single_shot = false;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--single-shot")) {
            single_shot = true;
        }
    }

    std.debug.print(
        \\[mu-agent] MU Self-Healing Agent v1.0.0
        \\[mu-agent] Autonomous error scanning + auto-fix
        \\[mu-agent] ---
        \\
    , .{});

    if (tg_enabled) {
        std.debug.print("[mu-agent] Telegram: enabled (chat_id={s})\n", .{tg_chat_id});
    } else {
        std.debug.print("[mu-agent] Telegram: disabled\n", .{});
    }

    std.debug.print("[mu-agent] Sleep interval: {d}s, Max wakes: {d}\n", .{ sleep_interval, max_wakes });

    try mu_loop.run(allocator, .{
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
