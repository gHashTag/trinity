//! CLOUD TOOLS — MCP Tool Module for Cloud Agent Orchestration
//! Shells out to `tri cloud` CLI commands.
//! φ² + 1/φ² = 3 | TRINITY

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
// INTERNAL — shell out to tri cloud
// ═══════════════════════════════════════════════════════════════════════════════

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
    child.stderr_behavior = .Pipe;
    child.spawn() catch {
        return copyToBuf(buf, "Error: Failed to spawn tri process");
    };

    // Read stdout via File.readToEndAlloc
    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read output");
    };
    defer std.heap.page_allocator.free(stdout);

    _ = child.wait() catch |err| {
        std.log.debug("cloud_tools: child.wait failed: {}", .{err});
    };

    if (stdout.len == 0) {
        return copyToBuf(buf, "OK (no output)");
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

const TRI_PATH = "/Users/playra/trinity-w1/zig-out/bin/tri";
