// agent_loop.zig — Sleep-wake cycle for Ralph autonomous agent
// Hooks handle per-tool Telegram reporting. This loop only sends WAKE/SLEEP.
// Uses --continue for native session resume (replaces HANDOVER.md).
const std = @import("std");
const identity_mod = @import("identity.zig");
const handover = @import("handover.zig");
const github_poller = @import("github_poller.zig");
const context_builder = @import("context_builder.zig");
const claude_runner = @import("claude_runner.zig");
const state_mod = @import("state.zig");
const telegram = @import("telegram.zig");

pub const Config = struct {
    project_root: []const u8,
    gh_token: []const u8,
    owner: []const u8,
    repo: []const u8,
    sleep_interval_s: u64 = 1800, // 30 minutes
    max_turns: u32 = 50,
    max_wakes: u32 = 0, // 0 = infinite
    single_shot: bool = false,
    tg_config: telegram.TelegramConfig = .{ .bot_token = "", .chat_id = "", .enabled = false },
};

fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[ralph-agent] " ++ fmt ++ "\n", args);
}

/// Run the sleep-wake loop.
pub fn run(allocator: std.mem.Allocator, config: Config) !void {
    var state = try state_mod.State.init(allocator, config.project_root);
    defer state.deinit();

    log("Starting sleep-wake loop", .{});
    log("  project: {s}", .{config.project_root});
    log("  repo: {s}/{s}", .{ config.owner, config.repo });
    log("  sleep interval: {d}s", .{config.sleep_interval_s});
    log("  max turns: {d}", .{config.max_turns});
    log("  telegram: {s}", .{if (config.tg_config.enabled) "enabled" else "disabled"});

    while (true) {
        // === WAKE ===
        const wake_count = state.incrementWakeCount() catch 0;
        log("=== WAKE #{d} ===", .{wake_count});

        // Telegram: announce wake
        var tg_buf: [512]u8 = undefined;
        telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xe2\x98\x80\xef\xb8\x8f Wake #{d}", .{wake_count});

        if (config.max_wakes > 0 and wake_count > config.max_wakes) {
            log("Max wakes ({d}) reached. Exiting.", .{config.max_wakes});
            telegram.send(config.tg_config, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\x9b\x91 \xd0\x9c\xd0\xb0\xd0\xba\xd1\x81 \xd0\xbf\xd1\x80\xd0\xbe\xd0\xb1\xd1\x83\xd0\xb6\xd0\xb4\xd0\xb5\xd0\xbd\xd0\xb8\xd0\xb9.");
            break;
        }

        // Load identity
        var id = identity_mod.load(allocator, config.project_root);
        defer id.deinit();

        // Read previous handover (used for first wake context only)
        const handover_content = handover.read(allocator, config.project_root);
        defer if (handover_content) |h| allocator.free(h);

        // Poll GitHub for pending issues
        log("Polling GitHub issues...", .{});
        const issues_json = github_poller.fetchPending(
            allocator,
            config.owner,
            config.repo,
            config.gh_token,
        );
        defer if (issues_json) |j| allocator.free(j);

        if (issues_json == null) {
            log("No pending issues or GitHub API unavailable. Sleeping.", .{});
            telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\x98\xb4 \xd0\x9d\xd0\xb5\xd1\x82 \xd0\xb7\xd0\xb0\xd0\xb4\xd0\xb0\xd1\x87. \xd0\xa1\xd0\xbf\xd0\xbb\xd1\x8e {d}\xd0\xbc\xd0\xb8\xd0\xbd.", .{config.sleep_interval_s / 60});
            if (config.single_shot) break;
            std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
            continue;
        }

        // Telegram: issues found
        telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\x93\x8b Issues! \xd0\xa1\xd1\x82\xd1\x80\xd0\xbe\xd1\x8e \xd0\xba\xd0\xbe\xd0\xbd\xd1\x82\xd0\xb5\xd0\xba\xd1\x81\xd1\x82...", .{});

        // Read current state
        const current_issue = state.read("current_issue");
        defer if (current_issue) |v| allocator.free(v);
        const current_branch = state.read("current_branch");
        defer if (current_branch) |v| allocator.free(v);

        // === BUILD CONTEXT ===
        const prompt = try context_builder.build(allocator, .{
            .identity = id.content,
            .handover_content = handover_content,
            .issues_json = issues_json,
            .current_issue = current_issue,
            .current_branch = current_branch,
            .wake_count = wake_count,
        });
        defer allocator.free(prompt);

        log("Context built ({d} bytes). Spawning Claude CLI...", .{prompt.len});

        // Use --continue for session resume after first wake
        const use_continue = wake_count > 1;

        // Telegram: spawning Claude
        telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\xa7\xa0 \xd0\xa0\xd0\xb0\xd0\xb1\xd0\xbe\xd1\x82\xd0\xb0\xd1\x8e ({s})...", .{
            if (use_continue) "--continue" else "new session",
        });

        // === WORK ===
        var result = claude_runner.spawn(
            allocator,
            prompt,
            config.project_root,
            config.max_turns,
            use_continue,
        ) catch |err| {
            log("Claude spawn error: {s}", .{@errorName(err)});
            telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xe2\x9d\x8c Spawn FAILED: {s}", .{@errorName(err)});
            if (config.single_shot) break;
            std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
            continue;
        };
        defer result.deinit();

        log("Claude exited with code {d} ({d} bytes output)", .{ result.exit_code, result.stdout.len });

        // Telegram: Claude finished
        if (result.exit_code == 0) {
            telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xe2\x9c\x85 \xd0\x93\xd0\xbe\xd1\x82\xd0\xbe\xd0\xb2\xd0\xbe ({d}b)", .{result.stdout.len});
        } else {
            telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xe2\x9d\x8c \xd0\x9e\xd1\x88\xd0\xb8\xd0\xb1\xd0\xba\xd0\xb0 (exit={d})", .{result.exit_code});
        }

        // Save session log
        claude_runner.saveLog(allocator, config.project_root, result.stdout);

        // === SLEEP ===
        // Update state
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{wake_count}) catch "0";
        state.write("last_wake", count_str) catch {};

        if (config.single_shot) {
            log("Single-shot mode. Exiting.", .{});
            telegram.send(config.tg_config, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\x8f\x81 \xd0\x93\xd0\xbe\xd1\x82\xd0\xbe\xd0\xb2\xd0\xbe.");
            break;
        }

        log("Sleeping for {d}s...", .{config.sleep_interval_s});
        telegram.sendFmt(config.tg_config, &tg_buf, "\xf0\x9f\x94\xa7 Ralph  \xf0\x9f\x98\xb4 \xd0\xa1\xd0\xbf\xd0\xbb\xd1\x8e {d}\xd0\xbc\xd0\xb8\xd0\xbd.", .{config.sleep_interval_s / 60});
        std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
    }

    log("Agent loop terminated.", .{});
}
