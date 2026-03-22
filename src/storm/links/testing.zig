//! Testing Links (Links 10-11)
//! Unit tests and VSA verification

const std = @import("std");
const storm = @import("../golden_chain.zig");

pub const unitTestLinkID = 10;
pub const integrationTestLinkID = 11;
pub const stressTestLinkID = 12;
pub const fuzzTestLinkID = 13;
pub const benchmarkLinkID = 14;

pub fn executeUnitTest(allocator: std.mem.Allocator, task: []const u8, file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("🧪 Unit Test: {s}", .{file });

    const zig_binary = "zig";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ zig_binary, "test", file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run zig test: {}", .{err}),
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

    // Parse test results
    var passed: usize = 0;
    var failed: usize = 0;
    var skipped: usize = 0;

    for (stdout) |line| {
        if (std.mem.indexOfScalar(u8, line, "PASS") != null) {
            passed += 1;
        } else if (std.mem.indexOfScalar(u8, line, "FAIL") != null) {
            failed += 1;
        } else if (std.mem.indexOfScalar(u8, line, "SKIP") != null) {
            skipped += 1;
        }
    }

    if (result.term != .Exited or result.code != 0) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\Test execution failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    const total = passed + failed + skipped;
    const status = if (failed == 0 and total > 0) "PASSED" else if (failed > 0) "FAILED" else "NO TESTS";

    log.info("Test results: {d}/{d} passed, {d} failed", .{passed, total, failed});

    return .{
        .success = (failed == 0),
        .message = try std.fmt.allocPrint(allocator,
            \\{s}: {d}/{d} tests passed, {d} skipped\\n{d} failed
        , .{status, passed, skipped, failed }),
        .duration_ms = duration,
        .exit_code = if (failed == 0) 0 else 1,
        .stdout = try allocator.dupe(u8, stdout),
    };
}

pub fn executeVsaVerify(allocator: std.mem.Allocator, task: []const u8, spec_file: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("🔬 VSA Verify: {s}", .{spec_file });

    const tri_binary = "zig-out/bin/tri";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ tri_binary, "vsacodegen", "verify", spec_file },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run vsacodegen verify: {}", .{err}),
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
                \\VSA verification failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    // Parse verification results
    var verified: bool = false;
    for (stdout) |line| {
        if (std.mem.indexOfScalar(u8, line, "VERIFIED") != null or
            std.mem.indexOfScalar(u8, line, "OK") != null)
        {
            verified = true;
            break;
        }
    }

    if (!verified) {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator,
                \\VSA verification failed\\nStdout: {s}
            , .{stdout }),
            .duration_ms = duration,
            .exit_code = 1,
        };
    }

    log.info("✅ VSA verification passed");
    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "VSA verified: {s}", .{spec_file }),
        .duration_ms = duration,
        .exit_code = 0,
    };
}

pub fn executeIntegrationTest(allocator: std.mem.Allocator, task: []const u8, config: []const u8) !storm.golden_chain.LinkResult {
    _ = allocator;
    _ = task;

    const log = std.log.scoped(.info);
    log.info("🔗 Integration Test: {s}", .{config });

    const tri_binary = "zig-out/bin/tri";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ tri_binary, "integration-test", "--config", config },
    }) catch |err| {
        return .{
            .success = false,
            .message = try std.fmt.allocPrint(allocator, "Failed to run integration test: {}", .{err}),
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
                \\Integration test failed (code: {d})\\nStderr: {s}
            , .{ result.code, stderr }),
            .duration_ms = duration,
            .exit_code = result.code orelse 1,
        };
    }

    log.info("✅ Integration test passed");
    return .{
        .success = true,
        .message = try std.fmt.allocPrint(allocator, "Integration test passed: {s}", .{config }),
        .duration_ms = duration,
        .exit_code = 0,
    };
}
