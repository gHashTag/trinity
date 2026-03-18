// main.zig — Entry point for Ralph autonomous agent daemon
//
// Usage:
//   zig build agent          # Run with defaults
//   zig build agent -- --single-shot   # Run once and exit
//
// Environment variables:
//   GH_TOKEN              — GitHub token (required)
//   GITHUB_OWNER          — Repository owner (default: gHashTag)
//   GITHUB_REPO           — Repository name (default: trinity)
//   RALPH_SLEEP_INTERVAL  — Seconds between wakes (default: 1800)
//   RALPH_MAX_TURNS       — Max Claude CLI turns per session (default: 50)
//   RALPH_MAX_WAKES       — Max wake cycles, 0=infinite (default: 0)
//   PROJECT_ROOT          — Project root path (auto-detected if unset)
//   TELEGRAM_BOT_TOKEN    — Telegram bot token (optional, enables TG reporting)
//   TELEGRAM_CHAT_ID      — Telegram chat ID (optional, enables TG reporting)
//
const std = @import("std");
const agent_loop = @import("agent_loop.zig");
const telegram = @import("telegram.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Required: GH_TOKEN
    const gh_token: []const u8 = std.posix.getenv("GH_TOKEN") orelse {
        std.debug.print("[ralph-agent] ERROR: GH_TOKEN environment variable not set\n", .{});
        std.process.exit(1);
    };

    // Optional config from env — [:0]const u8 coerces to []const u8
    const owner: []const u8 = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
    const repo: []const u8 = std.posix.getenv("GITHUB_REPO") orelse "trinity";
    const sleep_s: []const u8 = std.posix.getenv("RALPH_SLEEP_INTERVAL") orelse "1800";
    const turns_s: []const u8 = std.posix.getenv("RALPH_MAX_TURNS") orelse "50";
    const wakes_s: []const u8 = std.posix.getenv("RALPH_MAX_WAKES") orelse "0";

    const sleep_interval = std.fmt.parseInt(u64, sleep_s, 10) catch 1800;
    const max_turns = std.fmt.parseInt(u32, turns_s, 10) catch 50;
    const max_wakes = std.fmt.parseInt(u32, wakes_s, 10) catch 0;

    // Telegram reporting (optional)
    const tg_token: []const u8 = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse "";
    const tg_chat_id: []const u8 = std.posix.getenv("TELEGRAM_CHAT_ID") orelse "";
    const tg_enabled = tg_token.len > 0 and tg_chat_id.len > 0;

    // Detect project root
    const project_root = blk: {
        if (std.posix.getenv("PROJECT_ROOT")) |root| break :blk @as([]const u8, root);
        // Fallback: git rev-parse --show-toplevel
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "--show-toplevel" },
        }) catch {
            std.debug.print("[ralph-agent] ERROR: Cannot detect project root. Set PROJECT_ROOT.\n", .{});
            std.process.exit(1);
        };
        defer allocator.free(result.stderr);
        // Note: result.stdout is intentionally NOT freed here — it's used as project_root
        // for the lifetime of the program. The GPA will report it as "leaked" but it's
        // needed until process exit.
        if (result.stdout.len == 0) {
            std.debug.print("[ralph-agent] ERROR: Not in a git repository.\n", .{});
            std.process.exit(1);
        }
        // Trim trailing newline
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
        \\[ralph-agent] Ralph Autonomous Agent v2.0.0
        \\[ralph-agent] Hooks + Telegram + Session Resume
        \\[ralph-agent] ---
        \\
    , .{});

    if (tg_enabled) {
        std.debug.print("[ralph-agent] Telegram: enabled (chat_id={s})\n", .{tg_chat_id});
    } else {
        std.debug.print("[ralph-agent] Telegram: disabled (set TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID)\n", .{});
    }

    try agent_loop.run(allocator, .{
        .project_root = project_root,
        .gh_token = gh_token,
        .owner = owner,
        .repo = repo,
        .sleep_interval_s = sleep_interval,
        .max_turns = max_turns,
        .max_wakes = max_wakes,
        .single_shot = single_shot,
        .tg_config = .{
            .bot_token = tg_token,
            .chat_id = tg_chat_id,
            .enabled = tg_enabled,
        },
    });
}
