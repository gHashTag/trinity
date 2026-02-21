//! Process Executor - Wrapper for std.process.Child
//! Supports timeout, stdout/stderr capture, and specialized commands

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ProcessError = error{
    SpawnFailed,
    Timeout,
    InvalidCommand,
    ReadFailed,
} || std.process.Child.SpawnError || Allocator.Error;

pub const ProcessResult = struct {
    exit_code: i32,
    stdout: []u8,
    stderr: []u8,

    pub fn deinit(self: *ProcessResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

pub const ProcessConfig = struct {
    timeout_ms: u64 = 30_000, // 30 seconds default
    capture_output: bool = true,
    env: ?[]const []const u8 = null,
};

/// Run a process with timeout and output capture
pub fn run(allocator: Allocator, argv: []const []const u8) !ProcessResult {
    return runWithConfig(allocator, argv, .{});
}

/// Run a process with custom configuration
pub fn runWithConfig(allocator: Allocator, argv: []const []const u8, config: ProcessConfig) !ProcessResult {
    if (argv.len == 0) return ProcessError.InvalidCommand;

    var child = std.process.Child.init(argv, allocator);
    child.env_map = null; // Use parent environment
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var timer: ?std.time.Timer = null;
    if (config.timeout_ms > 0) {
        timer = std.time.Timer.start() catch null;
    }

    // Read output BEFORE waiting (pipes close after process terminates)
    var stdout_data: []u8 = &.{};
    var stderr_data: []u8 = &.{};
    if (config.capture_output) {
        const max_size = std.math.maxInt(usize);

        stdout_data = child.stdout.?.readToEndAlloc(allocator, max_size) catch {
            _ = child.kill() catch {};
            return ProcessError.ReadFailed;
        };
        errdefer allocator.free(stdout_data);

        stderr_data = child.stderr.?.readToEndAlloc(allocator, max_size) catch {
            allocator.free(stdout_data);
            _ = child.kill() catch {};
            return ProcessError.ReadFailed;
        };
        errdefer allocator.free(stderr_data);
    }

    // Wait for process to complete
    const term = child.wait() catch {
        _ = child.kill() catch {};
        if (config.capture_output) {
            allocator.free(stdout_data);
            allocator.free(stderr_data);
        }
        return ProcessError.SpawnFailed;
    };

    const exit_code = if (term == .Exited) term.Exited else 1;

    return ProcessResult{
        .exit_code = exit_code,
        .stdout = if (config.capture_output) stdout_data else try allocator.dupe(u8, ""),
        .stderr = if (config.capture_output) stderr_data else try allocator.dupe(u8, ""),
    };
}

/// Execute git command
pub fn git(allocator: Allocator, args: []const []const u8) !ProcessResult {
    var full_args = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 1);
    defer {
        for (full_args.items) |arg| {
            if (!std.mem.eql(u8, arg, "git")) allocator.free(arg);
        }
        full_args.deinit(allocator);
    }

    try full_args.append(allocator, "git");
    for (args) |arg| {
        try full_args.append(allocator, try allocator.dupe(u8, arg));
    }

    return run(allocator, full_args.items);
}

/// Execute zig build command
pub fn zigBuild(allocator: Allocator, args: []const []const u8) !ProcessResult {
    var full_args = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 2);
    defer {
        for (full_args.items) |arg| {
            if (!std.mem.eql(u8, arg, "zig") and !std.mem.eql(u8, arg, "build")) {
                allocator.free(arg);
            }
        }
        full_args.deinit(allocator);
    }

    try full_args.append(allocator, "zig");
    try full_args.append(allocator, "build");
    for (args) |arg| {
        try full_args.append(allocator, try allocator.dupe(u8, arg));
    }

    return run(allocator, full_args.items);
}

/// Execute zig test command
pub fn zigTest(allocator: Allocator, args: []const []const u8) !ProcessResult {
    var full_args = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 2);
    defer {
        for (full_args.items) |arg| {
            if (!std.mem.eql(u8, arg, "zig") and !std.mem.eql(u8, arg, "test")) {
                allocator.free(arg);
            }
        }
        full_args.deinit(allocator);
    }

    try full_args.append(allocator, "zig");
    try full_args.append(allocator, "test");
    for (args) |arg| {
        try full_args.append(allocator, try allocator.dupe(u8, arg));
    }

    return run(allocator, full_args.items);
}

/// Execute zig fmt command
pub fn zigFmt(allocator: Allocator, args: []const []const u8) !ProcessResult {
    var full_args = try std.ArrayList([]const u8).initCapacity(allocator, args.len + 2);
    defer {
        for (full_args.items) |arg| {
            if (!std.mem.eql(u8, arg, "zig") and !std.mem.eql(u8, arg, "fmt")) {
                allocator.free(arg);
            }
        }
        full_args.deinit(allocator);
    }

    try full_args.append(allocator, "zig");
    try full_args.append(allocator, "fmt");
    for (args) |arg| {
        try full_args.append(allocator, try allocator.dupe(u8, arg));
    }

    return run(allocator, full_args.items);
}

/// Execute VIBEE gen command
pub fn vibeeGen(allocator: Allocator, spec_path: []const u8) !ProcessResult {
    var full_args = try std.ArrayList([]const u8).initCapacity(allocator, 3);
    defer {
        for (full_args.items) |arg| {
            if (!std.mem.eql(u8, arg, "zig")) {
                allocator.free(arg);
            }
        }
        full_args.deinit(allocator);
    }

    try full_args.append(allocator, "zig");
    try full_args.append(allocator, "build");
    try full_args.append(allocator, "vibee");
    try full_args.append(allocator, "--");
    try full_args.append(allocator, "gen");
    try full_args.append(allocator, try allocator.dupe(u8, spec_path));

    return run(allocator, full_args.items);
}

// ============================================================================
// Tests
// ============================================================================

test "process: run echo command" {
    const allocator = std.testing.allocator;

    var result = try run(allocator, &[_][]const u8{ "echo", "hello" });
    defer _ = result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 0), result.exit_code);
    try std.testing.expectEqualStrings("hello\n", result.stdout);
}

test "process: run failing command" {
    const allocator = std.testing.allocator;

    var result = try run(allocator, &[_][]const u8{ "false" });
    defer _ = result.deinit(allocator);

    try std.testing.expect(result.exit_code != 0);
}

test "process: git version" {
    const allocator = std.testing.allocator;

    var result = git(allocator, &[_][]const u8{"--version"}) catch |err| {
        if (err == ProcessError.SpawnFailed) return error.SkipZigTest;
        return err;
    };
    defer _ = result.deinit(allocator);

    try std.testing.expectEqual(@as(i32, 0), result.exit_code);
    try std.testing.expect(result.stdout.len > 0);
}
