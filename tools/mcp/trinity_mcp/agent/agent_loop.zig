// agent_loop.zig — Sleep-wake cycle for Ralph autonomous agent
const std = @import("std");
const identity_mod = @import("identity.zig");
const handover = @import("handover.zig");
const github_poller = @import("github_poller.zig");
const context_builder = @import("context_builder.zig");
const claude_runner = @import("claude_runner.zig");
const state_mod = @import("state.zig");

pub const Config = struct {
    project_root: []const u8,
    gh_token: []const u8,
    owner: []const u8,
    repo: []const u8,
    sleep_interval_s: u64 = 1800, // 30 minutes
    max_turns: u32 = 50,
    max_wakes: u32 = 0, // 0 = infinite
    single_shot: bool = false, // true = run once and exit
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

    while (true) {
        // === WAKE ===
        const wake_count = state.incrementWakeCount() catch 0;
        log("=== WAKE #{d} ===", .{wake_count});

        if (config.max_wakes > 0 and wake_count > config.max_wakes) {
            log("Max wakes ({d}) reached. Exiting.", .{config.max_wakes});
            break;
        }

        // Load identity
        var id = identity_mod.load(allocator, config.project_root);
        defer id.deinit();

        // Read previous handover
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
            if (config.single_shot) break;
            std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
            continue;
        }

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

        // === WORK ===
        var result = claude_runner.spawn(
            allocator,
            prompt,
            config.project_root,
            config.max_turns,
        ) catch |err| {
            log("Claude spawn error: {s}", .{@errorName(err)});
            if (config.single_shot) break;
            std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
            continue;
        };
        defer result.deinit();

        log("Claude exited with code {d} ({d} bytes output)", .{ result.exit_code, result.stdout.len });

        // Save session log
        claude_runner.saveLog(allocator, config.project_root, result.stdout);

        // === SLEEP ===
        // Check if handover was written by the session
        const new_handover = handover.read(allocator, config.project_root);
        if (new_handover) |nh| {
            allocator.free(nh);
        } else {
            // Emergency handover — session didn't write one
            log("WARNING: No handover written. Creating emergency handover.", .{});
            handover.writeEmergency(allocator, config.project_root, wake_count, current_issue) catch {
                log("Failed to write emergency handover!", .{});
            };
        }

        // Update state
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{wake_count}) catch "0";
        state.write("last_wake", count_str) catch {};

        if (config.single_shot) {
            log("Single-shot mode. Exiting.", .{});
            break;
        }

        log("Sleeping for {d}s...", .{config.sleep_interval_s});
        std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
    }

    log("Agent loop terminated.", .{});
}
