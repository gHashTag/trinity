// @origin(spec:tri_hub.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI HUB — Ouroboros v2 Pipeline Hub
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pipeline: CI check → gate → farm recycle → Telegram
// State: .trinity/hub_state.json
//
// Commands:
//   tri cloud hub status    — pipeline state
//   tri cloud hub gate      — check CI, return pass/fail
//   tri cloud hub pipeline  — full: CI check → gate → farm recycle
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const tri_farm = @import("tri_farm.zig");
const experience_hooks = @import("experience_hooks.zig");

const print = std.debug.print;
const eql = std.mem.eql;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const DIM = "\x1b[2m";

// State file path
const STATE_PATH = ".trinity/hub_state.json";

pub fn runHubCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (eql(u8, subcmd, "status")) {
        return hubStatus(allocator);
    } else if (eql(u8, subcmd, "gate")) {
        _ = try hubGate(allocator);
    } else if (eql(u8, subcmd, "pipeline")) {
        const force = args.len > 1 and eql(u8, args[1], "--force");
        return hubPipeline(allocator, force);
    } else {
        print(
            \\
            \\Usage: tri cloud hub <command>
            \\
            \\Commands:
            \\  status           Show pipeline state (default)
            \\  gate             Check CI gate (pass/fail)
            \\  pipeline         Full pipeline: CI → gate → farm recycle → notify
            \\
            \\Pipeline options:
            \\  --force          Override closed gate
            \\
        , .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — show pipeline state from hub_state.json
// ═══════════════════════════════════════════════════════════════════════════════

fn hubStatus(allocator: Allocator) void {
    print("\n{s}🔮 OUROBOROS v2 — Hub Pipeline State{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const state = readState(allocator) catch {
        print("  {s}No pipeline state yet.{s}\n", .{ GRAY, RESET });
        print("  Run {s}tri cloud hub pipeline{s} to start.\n\n", .{ CYAN, RESET });
        return;
    };
    defer freeState(allocator, state);

    // Gate status
    const gate_icon: []const u8 = if (state.gate_open) "🟢 OPEN" else "🔴 CLOSED";
    const gate_color: []const u8 = if (state.gate_open) GREEN else RED;

    print("  {s}Gate:{s}           {s}{s}{s}\n", .{ BOLD, RESET, gate_color, gate_icon, RESET });
    print("  {s}Last CI SHA:{s}    {s}{s}{s}\n", .{ BOLD, RESET, CYAN, state.last_ci_sha, RESET });
    print("  {s}CI Status:{s}      {s}{s}{s}\n", .{
        BOLD,
        RESET,
        if (eql(u8, state.last_ci_status, "success")) GREEN else RED,
        state.last_ci_status,
        RESET,
    });
    print("  {s}Deploy SHA:{s}     {s}{s}{s}\n", .{ BOLD, RESET, CYAN, state.last_deploy_sha, RESET });
    print("  {s}Gate checked:{s}   {s}{s}{s}\n", .{ BOLD, RESET, GRAY, state.last_gate_check, RESET });
    print("  {s}Pipeline ran:{s}   {s}{s}{s}\n", .{ BOLD, RESET, GRAY, state.last_pipeline_run, RESET });

    print("\n{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// GATE — check CI via `gh run list`, return pass/fail
// ═══════════════════════════════════════════════════════════════════════════════

fn hubGate(allocator: Allocator) !bool {
    print("\n{s}🚦 CI GATE CHECK{s}\n", .{ BOLD, RESET });
    print("{s}────────────────────────────────────────{s}\n", .{ DIM, RESET });

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gh", "run", "list", "--workflow", "ci-runner.yml", "--limit", "1", "--json", "conclusion,headSha" },
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        print("  {s}❌ Could not run gh: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
        return false;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    };
    if (exit_code != 0) {
        print("  {s}❌ gh run list failed (exit {d}){s}\n", .{ RED, exit_code, RESET });
        if (result.stderr.len > 0) print("  {s}\n", .{result.stderr});
        print("\n", .{});
        return false;
    }

    // Parse JSON array: [{"conclusion":"success","headSha":"abc123"}]
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, result.stdout, .{}) catch {
        print("  {s}❌ Invalid JSON from gh{s}\n\n", .{ RED, RESET });
        return false;
    };
    defer parsed.deinit();

    if (parsed.value != .array or parsed.value.array.items.len == 0) {
        print("  {s}⚠️  No CI runs found{s}\n\n", .{ YELLOW, RESET });
        saveState(allocator, .{
            .last_ci_sha = "unknown",
            .last_ci_status = "none",
            .last_deploy_sha = "unknown",
            .gate_open = false,
            .last_gate_check = "now",
            .last_pipeline_run = "",
        });
        return false;
    }

    const run = parsed.value.array.items[0];
    const conclusion = getJsonString(run, "conclusion");
    const head_sha = getJsonString(run, "headSha");

    const gate_open = eql(u8, conclusion, "success");

    if (gate_open) {
        print("  {s}✅ GATE OPEN — CI passed{s}\n", .{ GREEN, RESET });
    } else {
        print("  {s}🔴 GATE CLOSED — CI status: {s}{s}\n", .{ RED, conclusion, RESET });
    }
    print("  SHA: {s}{s}{s}\n\n", .{ CYAN, head_sha, RESET });

    // Read existing state to preserve deploy SHA
    var deploy_sha: []const u8 = "unknown";
    var last_pipeline: []const u8 = "";
    if (readState(allocator)) |old_state| {
        deploy_sha = old_state.last_deploy_sha;
        last_pipeline = old_state.last_pipeline_run;
        // Note: we don't defer freeState here because we need the strings
        // to survive until after saveState. Instead we save first, then free.
        saveState(allocator, .{
            .last_ci_sha = head_sha,
            .last_ci_status = conclusion,
            .last_deploy_sha = deploy_sha,
            .gate_open = gate_open,
            .last_gate_check = "now",
            .last_pipeline_run = last_pipeline,
        });
        freeState(allocator, old_state);
    } else |_| {
        saveState(allocator, .{
            .last_ci_sha = head_sha,
            .last_ci_status = conclusion,
            .last_deploy_sha = "unknown",
            .gate_open = gate_open,
            .last_gate_check = "now",
            .last_pipeline_run = "",
        });
    }

    return gate_open;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE — full Ouroboros v2 cycle: CI → gate → farm recycle → notify
// ═══════════════════════════════════════════════════════════════════════════════

fn hubPipeline(allocator: Allocator, force: bool) !void {
    print("\n{s}🔄 HUB PIPELINE — Ouroboros v2{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Step 1: Check gate
    print("{s}[1/4]{s} Checking CI gate...\n", .{ CYAN, RESET });
    const gate_open = try hubGate(allocator);

    if (!gate_open and !force) {
        print("{s}⛔ Gate closed. Use --force to override.{s}\n\n", .{ RED, RESET });
        experience_hooks.autoSaveExperience("hub pipeline", "gate closed", false);
        return;
    }

    if (!gate_open and force) {
        print("{s}⚠️  Gate closed but --force specified. Continuing...{s}\n\n", .{ YELLOW, RESET });
    }

    // Step 2: Farm recycle
    print("{s}[2/4]{s} Running farm recycle...\n", .{ CYAN, RESET });
    tri_farm.runFarmRecycle(allocator, &.{"--skip-ci"}) catch |err| {
        print("{s}❌ Farm recycle failed: {s}{s}\n\n", .{ RED, @errorName(err), RESET });
        experience_hooks.autoSaveExperience("hub pipeline", "farm recycle failed", false);
        return;
    };

    // Step 3: Get current HEAD SHA for state
    print("{s}[3/4]{s} Updating state...\n", .{ CYAN, RESET });
    const head_sha = getCurrentSha(allocator);
    defer if (head_sha) |sha| allocator.free(sha);

    const sha_str: []const u8 = head_sha orelse "unknown";

    // Update state with deploy SHA
    if (readState(allocator)) |old_state| {
        saveState(allocator, .{
            .last_ci_sha = old_state.last_ci_sha,
            .last_ci_status = old_state.last_ci_status,
            .last_deploy_sha = sha_str,
            .gate_open = old_state.gate_open,
            .last_gate_check = old_state.last_gate_check,
            .last_pipeline_run = "now",
        });
        freeState(allocator, old_state);
    } else |_| {
        saveState(allocator, .{
            .last_ci_sha = sha_str,
            .last_ci_status = "success",
            .last_deploy_sha = sha_str,
            .gate_open = true,
            .last_gate_check = "now",
            .last_pipeline_run = "now",
        });
    }

    // Step 4: Telegram notify (fire-and-forget)
    print("{s}[4/4]{s} Sending notification...\n", .{ CYAN, RESET });
    const notify_msg = std.fmt.allocPrint(
        allocator,
        "Hub Pipeline complete. SHA={s} gate={s}",
        .{ sha_str, if (gate_open) "open" else "forced" },
    ) catch "Hub Pipeline complete";
    defer if (notify_msg.len > 0 and notify_msg.ptr != "Hub Pipeline complete".ptr) allocator.free(notify_msg);

    // Fire-and-forget: spawn tri notify in background
    var notify_child = std.process.Child.init(&.{ "tri", "notify", notify_msg }, allocator);
    notify_child.spawn() catch |err| {
        print("  {s}⚠️  Notify spawn failed: {s} (non-fatal){s}\n", .{ YELLOW, @errorName(err), RESET });
    };

    print("\n{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}✅ HUB PIPELINE COMPLETE{s}\n", .{ GREEN, RESET });
    print("  Deploy SHA: {s}{s}{s}\n\n", .{ CYAN, sha_str, RESET });

    experience_hooks.autoSaveExperience("hub pipeline", "", true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// State persistence
// ═══════════════════════════════════════════════════════════════════════════════

const HubState = struct {
    last_ci_sha: []const u8,
    last_ci_status: []const u8,
    last_deploy_sha: []const u8,
    gate_open: bool,
    last_gate_check: []const u8,
    last_pipeline_run: []const u8,
};

fn readState(allocator: Allocator) !HubState {
    const file = try std.fs.cwd().openFile(STATE_PATH, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 16 * 1024);
    defer allocator.free(contents);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, contents, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidState;

    // Dupe all strings so they outlive parsed
    return HubState{
        .last_ci_sha = try allocator.dupe(u8, getJsonString(root, "last_ci_sha")),
        .last_ci_status = try allocator.dupe(u8, getJsonString(root, "last_ci_status")),
        .last_deploy_sha = try allocator.dupe(u8, getJsonString(root, "last_deploy_sha")),
        .gate_open = if (root.object.get("gate_open")) |v| switch (v) {
            .bool => |b| b,
            else => false,
        } else false,
        .last_gate_check = try allocator.dupe(u8, getJsonString(root, "last_gate_check")),
        .last_pipeline_run = try allocator.dupe(u8, getJsonString(root, "last_pipeline_run")),
    };
}

fn freeState(allocator: Allocator, state: HubState) void {
    allocator.free(state.last_ci_sha);
    allocator.free(state.last_ci_status);
    allocator.free(state.last_deploy_sha);
    allocator.free(state.last_gate_check);
    allocator.free(state.last_pipeline_run);
}

fn saveState(allocator: Allocator, state: HubState) void {
    const json = std.fmt.allocPrint(allocator,
        \\{{
        \\  "last_ci_sha": "{s}",
        \\  "last_ci_status": "{s}",
        \\  "last_deploy_sha": "{s}",
        \\  "gate_open": {s},
        \\  "last_gate_check": "{s}",
        \\  "last_pipeline_run": "{s}"
        \\}}
    , .{
        state.last_ci_sha,
        state.last_ci_status,
        state.last_deploy_sha,
        if (state.gate_open) "true" else "false",
        state.last_gate_check,
        state.last_pipeline_run,
    }) catch return;
    defer allocator.free(json);

    // Ensure .trinity directory exists
    std.fs.cwd().makePath(".trinity") catch {};

    const file = std.fs.cwd().createFile(STATE_PATH, .{}) catch return;
    defer file.close();
    file.writeAll(json) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn getJsonString(val: std.json.Value, key: []const u8) []const u8 {
    if (val != .object) return "?";
    const v = val.object.get(key) orelse return "?";
    if (v != .string) return "?";
    return v.string;
}

fn getCurrentSha(allocator: Allocator) ?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "rev-parse", "--short", "HEAD" },
        .max_output_bytes = 256,
    }) catch return null;
    defer allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    };
    if (exit_code != 0) {
        allocator.free(result.stdout);
        return null;
    }

    // Trim trailing newline
    const stdout = result.stdout;
    if (stdout.len == 0) {
        allocator.free(stdout);
        return null;
    }

    var end = stdout.len;
    while (end > 0 and (stdout[end - 1] == '\n' or stdout[end - 1] == '\r')) {
        end -= 1;
    }

    if (end == stdout.len) return stdout;

    // Need to return a trimmed copy
    const trimmed = allocator.dupe(u8, stdout[0..end]) catch {
        allocator.free(stdout);
        return null;
    };
    allocator.free(stdout);
    return trimmed;
}

test "hub command help" {
    // Just verify dispatch doesn't crash on unknown subcommand
    const allocator = std.testing.allocator;
    try runHubCommand(allocator, &.{"help"});
}
