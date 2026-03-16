// @origin(manual) @regen(pending)
//! DEPLOY TOOLS — MCP Tool Module for Deployment Management
//! Shells out to `tri deploy` CLI commands.
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const MAX_OUTPUT = 8192;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — called from server.zig handleDeployTool()
// ═══════════════════════════════════════════════════════════════════════════════

pub fn deployStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriDeploy(buf, &.{"status"});
}

pub fn deployLogs(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriDeploy(buf, &.{"logs"});
}

pub fn deployVars(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriDeploy(buf, &.{"vars"});
}

pub fn deployStart(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriDeploy(buf, &.{"start"});
}

pub fn deployStop(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriDeploy(buf, &.{"stop"});
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL — shell out to tri deploy
// ═══════════════════════════════════════════════════════════════════════════════

fn runTriDeploy(buf: *[MAX_OUTPUT]u8, args: []const []const u8) []const u8 {
    var argv: [16][]const u8 = undefined;
    argv[0] = TRI_PATH;
    argv[1] = "deploy";
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
            else => "Error: Failed to spawn tri deploy process",
        });
    };
    defer {
        _ = child.wait() catch |err| {
            std.log.warn("deploy_tools: child.wait() failed: {}", .{err});
        };
    }

    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read tri deploy output");
    };
    defer std.heap.page_allocator.free(stdout);

    if (stdout.len == 0) {
        return copyToBuf(buf, "OK (no output — check stderr)");
    }

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
