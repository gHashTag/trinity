//! P10: Timeout Handler — simplified for P10
const std = @import("std");

pub const TimeoutHandler = struct {
    allocator: std.mem.Allocator,
    default_timeout_ms: u64 = 300_000,

    pub const TimeoutResult = struct {
        timed_out: bool,
        duration_ms: u64,
        was_killed: bool = false,
    };

    pub fn init(allocator: std.mem.Allocator) TimeoutHandler {
        return .{
            .allocator = allocator,
        };
    }

    pub fn executeWithTimeout(
        _: *const TimeoutHandler,
        comptime func: anytype,
        args: anytype,
        timeout_ms: u64,
    ) !TimeoutResult {
        const start = std.time.nanoTimestamp();

        // Execute function and check for errors
        if (func(args)) |_| {
            // Function succeeded
        } else |err| {
            return err;
        }

        const elapsed = std.time.nanoTimestamp() - start;
        const duration_ms = @as(u64, @intFromFloat(@divTrunc(@as(f128, @floatFromInt(elapsed)), 1_000_000)));
        const timed_out = duration_ms > timeout_ms;

        return .{
            .timed_out = timed_out,
            .duration_ms = duration_ms,
            .was_killed = timed_out,
        };
    }

    pub fn executeProcessWithTimeout(
        _: *const TimeoutHandler,
        argv: []const []const u8,
        _: u64, // timeout_ms - unused in P10 simplified version
    ) !struct {
        exit_code: u8,
        timed_out: bool,
        duration_ms: u64,
        stdout: []const u8,
        stderr: []const u8,
    } {
        const start = std.time.nanoTimestamp();

        var child = std.process.Child.init(argv, std.heap.page_allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        const result = child.wait() catch |err| {
            return .{
                .exit_code = 1,
                .timed_out = false,
                .duration_ms = 0,
                .stdout = "",
                .stderr = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{err}),
            };
        };

        const end = std.time.nanoTimestamp();
        const duration_ms = @as(u64, @intFromFloat(@divTrunc(@as(f128, @floatFromInt(end - start)), 1_000_000)));

        var exit_code: u8 = 1;
        switch (result) {
            .Exited => |code| exit_code = code,
            .Signal => |sig| exit_code = 128 + @as(u8, @truncate(sig)),
            else => {},
        }

        return .{
            .exit_code = exit_code,
            .timed_out = false,
            .duration_ms = duration_ms,
            .stdout = "",
            .stderr = "",
        };
    }
};
