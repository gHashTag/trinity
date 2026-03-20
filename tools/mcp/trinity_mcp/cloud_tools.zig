// @origin(spec:cloud_tools.tri) @regen(manual-impl)
//! CLOUD TOOLS — MCP Tool Module for Cloud Agent Orchestration
//! Shells out to `tri cloud` CLI commands.
//! φ² + 1/φ² = 3 | TRINITY
// @origin(manual) @regen(pending)

const std = @import("std");

const MAX_OUTPUT = 8192;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — called from server.zig handleCloudTool()
// ═══════════════════════════════════════════════════════════════════════════════

pub fn cloudSpawn(buf: *[MAX_OUTPUT]u8, issue_number: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "spawn", issue_number });
}

pub fn cloudKill(buf: *[MAX_OUTPUT]u8, issue_number: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "kill", issue_number });
}

pub fn cloudList(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"agents"});
}

pub fn cloudStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"status"});
}

pub fn cloudCleanup(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"cleanup"});
}

pub fn cloudSpawnAll(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"spawn-all"});
}

pub fn cloudLogs(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"logs"});
}

pub fn cloudHistory(buf: *[MAX_OUTPUT]u8, issue_number: []const u8) []const u8 {
    if (issue_number.len > 0) {
        return runTriCloud(buf, &.{ "history", issue_number });
    }
    return runTriCloud(buf, &.{"history"});
}

pub fn cloudApiCheck(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"api-check"});
}

pub fn cloudRedeploy(buf: *[MAX_OUTPUT]u8, service_id: []const u8, issue_number: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "redeploy", service_id, issue_number });
}

pub fn cloudDiagnose(buf: *[MAX_OUTPUT]u8, issue_number: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "diagnose", issue_number });
}

pub fn cloudIssueCreate(buf: *[MAX_OUTPUT]u8, title: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "issue-create", title });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FARM Tools — Multi-Account Railway Management
// ═══════════════════════════════════════════════════════════════════════════════

pub fn cloudFarm(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"farm"});
}

pub fn cloudFarmSync(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{ "farm", "sync" });
}

pub fn cloudFarmCapacity(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{ "farm", "capacity" });
}

pub fn cloudFarmRebalance(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{ "farm", "rebalance" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING Tools — HSLM experiment spawning on Railway farm
// ═══════════════════════════════════════════════════════════════════════════════

pub fn cloudTrain(buf: *[MAX_OUTPUT]u8, name: []const u8) []const u8 {
    return runTriCloud(buf, &.{ "train", name });
}

pub fn cloudTrainBatch(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCloud(buf, &.{"train-batch"});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FARM EVOLVE Tools — Health + Watch + Notify
// ═══════════════════════════════════════════════════════════════════════════════

pub fn cloudFarmEvolveHealth(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "evolve", "status" });
}

pub fn cloudFarmEvolveNotify(buf: *[MAX_OUTPUT]u8, dry_run: bool) []const u8 {
    if (dry_run) {
        return runTriCmd(buf, &.{ "farm", "evolve", "notify", "--dry-run" });
    }
    return runTriCmd(buf, &.{ "farm", "evolve", "notify" });
}

pub fn cloudFarmEvolveWatch(buf: *[MAX_OUTPUT]u8, sacred: bool, dry_run: bool) []const u8 {
    // Always --once for MCP (no daemon mode)
    if (sacred and dry_run) {
        return runTriCmd(buf, &.{ "farm", "evolve", "watch", "--once", "--sacred", "--notify", "--dry-run" });
    } else if (sacred) {
        return runTriCmd(buf, &.{ "farm", "evolve", "watch", "--once", "--sacred", "--notify" });
    } else if (dry_run) {
        return runTriCmd(buf, &.{ "farm", "evolve", "watch", "--once", "--notify", "--dry-run" });
    }
    return runTriCmd(buf, &.{ "farm", "evolve", "watch", "--once", "--notify" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN TOOLS — MCP wrappers for 26 Golden Chain links
// Each chain_* tool shells out to `tri chain <link_name> --task <task>`
// ═══════════════════════════════════════════════════════════════════════════════

pub fn chainRun(buf: *[MAX_OUTPUT]u8, link_name: []const u8, task: []const u8) []const u8 {
    if (task.len > 0) {
        return runTriCmd(buf, &.{ "chain", link_name, "--task", task });
    }
    return runTriCmd(buf, &.{ "chain", link_name });
}

pub fn chainList(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"chain"});
}

pub fn decomposeIssue(buf: *[MAX_OUTPUT]u8, issue_number: []const u8, template: []const u8) []const u8 {
    if (template.len > 0) {
        return runTriCmd(buf, &.{ "decompose", issue_number, "--template", template });
    }
    return runTriCmd(buf, &.{ "decompose", issue_number });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL — shell out to tri cloud
// ═══════════════════════════════════════════════════════════════════════════════

/// Generic runner: tri <args...>
fn runTriCmd(buf: *[MAX_OUTPUT]u8, args: []const []const u8) []const u8 {
    var argv: [16][]const u8 = undefined;
    argv[0] = TRI_PATH;
    const n = @min(args.len, 15);
    for (0..n) |i| {
        argv[1 + i] = args[i];
    }

    var child = std.process.Child.init(argv[0 .. 1 + n], std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    child.spawn() catch |err| {
        return copyToBuf(buf, switch (err) {
            error.FileNotFound => "Error: tri binary not found (run zig build)",
            else => "Error: Failed to spawn tri process",
        });
    };
    defer {
        _ = child.wait() catch |err| {
            std.log.warn("cloud_tools: child.wait() failed: {}", .{err});
        };
    }

    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read tri output");
    };
    defer std.heap.page_allocator.free(stdout);

    if (stdout.len == 0) {
        return copyToBuf(buf, "OK (no output — check stderr)");
    }

    const len = @min(stdout.len, MAX_OUTPUT);
    @memcpy(buf[0..len], stdout[0..len]);
    return buf[0..len];
}

fn runTriCloud(buf: *[MAX_OUTPUT]u8, args: []const []const u8) []const u8 {
    // Build command: tri cloud <args...>
    var argv: [16][]const u8 = undefined;
    argv[0] = TRI_PATH;
    argv[1] = "cloud";
    const n = @min(args.len, 14);
    for (0..n) |i| {
        argv[2 + i] = args[i];
    }

    var child = std.process.Child.init(argv[0 .. 2 + n], std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    child.spawn() catch |err| {
        return copyToBuf(buf, switch (err) {
            error.FileNotFound => "Error: tri binary not found (run zig build)",
            else => "Error: Failed to spawn tri cloud process",
        });
    };
    defer {
        _ = child.wait() catch |err| {
            std.log.warn("cloud_tools: child.wait() failed: {}", .{err});
        };
    }

    // Read stdout via File.readToEndAlloc
    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read tri cloud output");
    };
    defer std.heap.page_allocator.free(stdout);

    if (stdout.len == 0) {
        return copyToBuf(buf, "OK (no output — check stderr)");
    }

    // Copy to provided buffer
    const len = @min(stdout.len, MAX_OUTPUT);
    @memcpy(buf[0..len], stdout[0..len]);
    return buf[0..len];
}

fn copyToBuf(buf: *[MAX_OUTPUT]u8, msg: []const u8) []const u8 {
    const len = @min(msg.len, MAX_OUTPUT);
    @memcpy(buf[0..len], msg[0..len]);
    return buf[0..len];
}

const TRI_PATH = "zig-out/bin/tri";
