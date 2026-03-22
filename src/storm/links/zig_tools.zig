//! Zig Tools Links (Links 7-9)
//! AST check, format check, and build verification

const std = @import("std");

pub const astCheckLinkID = 7;
pub const fmtCheckLinkID = 8;
pub const buildLinkID = 9;

pub fn executeAstCheck(allocator: std.mem.Allocator, task: []const u8, file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("🔍 AST Check: {s}", .{file });

    const zig_binary = "zig";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ zig_binary, "ast-check", "-t", file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run ast-check: {}", .{err}),
            .duration_ms = 0,
            .exit_code = 1,
        };
    };
    defer result.deinit();

    const stdout = try result.stdout.allocator.dupe(allocator, result.stdout.items);
    defer allocator.free(stdout);
    const stderr = try result.stderr.allocator.dupe(allocator, result.stderr.items);
    defer allocator.free(stderr);
    const duration = std.time.nanoTimestamp() - result.start_time;

    if (result.term != .Exited or result.code != 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\AST check failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    // Parse output for errors
    var errors: usize = 0;
    for (stdout) |line| {
        if (std.mem.indexOfScalar(u8, line, "error") != null or
            std.mem.indexOfScalar(u8, line, "Error") != null)
        {
            errors += 1;
        }
    }

    if (errors > 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\Found {d} AST errors\\n{s}
            , .{errors, stdout }),
            .duration_ms = duration,
            .exit_code = 1,
        };
    }

    log.info("✅ AST check passed");
    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "AST valid: {s}", .{file}),
        .duration_ms = duration,
        .exit_code = 0,
    };
}

pub fn executeFmtCheck(allocator: std.mem.Allocator, task: []const u8, file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("✏️️  FMT Check: {s}", .{file });

    const zig_binary = "zig";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ zig_binary, "fmt", "--check", file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run fmt --check: {}", .{err}),
            .duration_ms = 0,
            .exit_code = 1,
        };
    };
    defer result.deinit();

    const stdout = try result.stdout.allocator.dupe(allocator, result.stdout.items);
    defer allocator.free(stdout);
    const stderr = try result.stderr.allocator.dupe(allocator, result.stderr.items);
    defer allocator.free(stderr);
    const duration = std.time.nanoTimestamp() - result.start_time;

    if (result.term != .Exited or result.code != 0) {
        // Exit code 1 means formatting issues found
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\File needs formatting\\nStderr: {s}
            , .{stderr }),
            .duration_ms = duration,
            .exit_code = 1,
        };
    }

    log.info("✅ Format check passed");
    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "Formatted correctly: {s}", .{file }),
        .duration_ms = duration,
        .exit_code = 0,
    };
}

pub fn executeBuild(allocator: std.mem.Allocator, task: []const u8, file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("🔨 Build: {s}", .{file });

    const zig_binary = "zig";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ zig_binary, "build", file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run zig build: {}", .{err}),
            .duration_ms = 0,
            .exit_code = 1,
        };
    };
    defer result.deinit();

    const stdout = try result.stdout.allocator.dupe(allocator, result.stdout.items);
    defer allocator.free(stdout);
    const stderr = try result.stderr.allocator.dupe(allocator, result.stderr.items);
    defer allocator.free(stderr);
    const duration = std.time.nanoTimestamp() - result.start_time;

    // Parse build output for errors
    var has_errors = false;
    for (stderr) |line| {
        if (std.mem.indexOfScalar(u8, line, "error:") != null or
            std.mem.indexOfScalar(u8, line, " Error") != null)
        {
            has_errors = true;
            break;
        }
    }

    if (result.term != .Exited or result.code != 0 or has_errors) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\Build failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    log.info("✅ Build successful");
    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "Built: {s}", .{file }),
        .duration_ms = duration,
        .exit_code = 0,
    };
}
