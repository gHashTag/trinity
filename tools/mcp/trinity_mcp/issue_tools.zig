// @origin(manual) @regen(pending)
//! ISSUE TOOLS — MCP Tool Module for GitHub Issue Management
//! Shells out to `tri issue` CLI commands.
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const MAX_OUTPUT = 8192;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — called from server.zig handleIssueTool()
// ═══════════════════════════════════════════════════════════════════════════════

pub fn issueList(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriIssue(buf, &.{"list"});
}

pub fn issueView(buf: *[MAX_OUTPUT]u8, number: []const u8) []const u8 {
    return runTriIssue(buf, &.{ "view", number });
}

pub fn issueCreate(buf: *[MAX_OUTPUT]u8, title: []const u8, body: []const u8) []const u8 {
    if (body.len > 0) {
        return runTriIssue(buf, &.{ "create", title, body });
    }
    return runTriIssue(buf, &.{ "create", title });
}

pub fn issueComment(buf: *[MAX_OUTPUT]u8, number: []const u8, body: []const u8) []const u8 {
    return runTriIssue(buf, &.{ "comment", number, body });
}

pub fn issueClose(buf: *[MAX_OUTPUT]u8, number: []const u8) []const u8 {
    return runTriIssue(buf, &.{ "close", number });
}

pub fn issueAssign(buf: *[MAX_OUTPUT]u8, number: []const u8, user: []const u8) []const u8 {
    return runTriIssue(buf, &.{ "assign", number, user });
}

pub fn issueDecompose(buf: *[MAX_OUTPUT]u8, number: []const u8) []const u8 {
    return runTriIssue(buf, &.{ "decompose", number });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL — shell out to tri issue
// ═══════════════════════════════════════════════════════════════════════════════

fn runTriIssue(buf: *[MAX_OUTPUT]u8, args: []const []const u8) []const u8 {
    var argv: [16][]const u8 = undefined;
    argv[0] = TRI_PATH;
    argv[1] = "issue";
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
            else => "Error: Failed to spawn tri issue process",
        });
    };
    defer {
        _ = child.wait() catch |err| {
            std.log.warn("issue_tools: child.wait() failed: {}", .{err});
        };
    }

    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read tri issue output");
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
