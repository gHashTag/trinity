// self_review.zig — Build gate + test gate + repair loop for agent entrypoint
// Runs: zig fmt --check → zig build → zig build test (with 3 repair attempts)
const std = @import("std");

pub const ReviewResult = struct {
    passed: bool,
    fmt_ok: bool,
    build_ok: bool,
    test_ok: bool,
    attempts: u8,
    output: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ReviewResult) void {
        if (self.output.len > 0) self.allocator.free(self.output);
    }

    pub fn summary(self: *const ReviewResult, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf,
            \\fmt:{s} build:{s} test:{s} attempts:{d}
        , .{
            if (self.fmt_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c",
            if (self.build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c",
            if (self.test_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c",
            self.attempts,
        }) catch "review failed";
    }
};

/// Run self-review gates with repair loop.
/// Attempts to fix format issues automatically, retries build up to max_attempts.
pub fn run(allocator: std.mem.Allocator, worktree_path: []const u8, max_attempts: u8) ReviewResult {
    var attempt: u8 = 0;
    var last_output: []const u8 = "";

    while (attempt < max_attempts) : (attempt += 1) {
        // 1. Format check (auto-fix)
        const fmt_result = runCommand(allocator, worktree_path, &.{ "zig", "fmt", "src/" });
        const fmt_ok = fmt_result.success;
        if (fmt_result.output.len > 0) allocator.free(fmt_result.output);

        // 2. Build
        const build_result = runCommand(allocator, worktree_path, &.{ "zig", "build" });
        if (!build_result.success) {
            if (last_output.len > 0) allocator.free(last_output);
            last_output = build_result.output;
            std.debug.print("[self-review] build failed (attempt {d}/{d})\n", .{ attempt + 1, max_attempts });
            continue;
        }
        if (build_result.output.len > 0) allocator.free(build_result.output);

        // 3. Test
        const test_result = runCommand(allocator, worktree_path, &.{ "zig", "build", "test" });
        if (!test_result.success) {
            if (last_output.len > 0) allocator.free(last_output);
            last_output = test_result.output;
            std.debug.print("[self-review] tests failed (attempt {d}/{d})\n", .{ attempt + 1, max_attempts });
            continue;
        }
        if (test_result.output.len > 0) allocator.free(test_result.output);

        // All passed
        if (last_output.len > 0) allocator.free(last_output);
        return .{
            .passed = true,
            .fmt_ok = fmt_ok,
            .build_ok = true,
            .test_ok = true,
            .attempts = attempt + 1,
            .output = allocator.dupe(u8, "all gates passed") catch "",
            .allocator = allocator,
        };
    }

    // Failed after all attempts
    return .{
        .passed = false,
        .fmt_ok = false,
        .build_ok = false,
        .test_ok = false,
        .attempts = max_attempts,
        .output = last_output,
        .allocator = allocator,
    };
}

const CommandResult = struct {
    success: bool,
    output: []const u8,
};

fn runCommand(allocator: std.mem.Allocator, cwd: []const u8, argv: []const []const u8) CommandResult {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = 128 * 1024,
    }) catch return .{ .success = false, .output = "" };

    // Combine stderr+stdout for error reporting
    const success = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };

    // Prefer stderr for error output, stdout otherwise
    if (!success and result.stderr.len > 0) {
        allocator.free(result.stdout);
        return .{ .success = false, .output = result.stderr };
    }

    allocator.free(result.stderr);
    if (!success) {
        return .{ .success = false, .output = result.stdout };
    }

    allocator.free(result.stdout);
    return .{ .success = true, .output = "" };
}

test "ReviewResult summary" {
    const allocator = std.testing.allocator;
    var r = ReviewResult{
        .passed = true,
        .fmt_ok = true,
        .build_ok = true,
        .test_ok = true,
        .attempts = 1,
        .output = try allocator.dupe(u8, "ok"),
        .allocator = allocator,
    };
    defer r.deinit();

    var buf: [128]u8 = undefined;
    const s = r.summary(&buf);
    try std.testing.expect(s.len > 0);
}
