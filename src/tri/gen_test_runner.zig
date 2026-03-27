//! tri/test_runner — Simple test runner
//! TTT Dogfood v0.2 Stage 301

const std = @import("std");

pub const TestCase = struct {
    name: []const u8,
    fn_ptr: *const fn () anyerror!void,
};

pub const TestRunner = struct {
    tests: std.ArrayList(TestCase),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TestRunner {
        return .{
            .tests = std.ArrayList(TestCase).initCapacity(allocator, 16) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn add(runner: *TestRunner, name: []const u8, fn_ptr: *const fn () anyerror!void) !void {
        const name_copy = try runner.allocator.dupe(u8, name);
        try runner.tests.append(runner.allocator, TestCase{ .name = name_copy, .fn_ptr = fn_ptr });
    }

    pub fn run(runner: *const TestRunner) !usize {
        var passed: usize = 0;
        for (runner.tests.items) |tc| {
            if (tc.fn_ptr()) |_| {
                passed += 1;
            } else |_| {}
        }
        return passed;
    }

    pub fn deinit(runner: *TestRunner) void {
        for (runner.tests.items) |tc| {
            runner.allocator.free(tc.name);
        }
        runner.tests.deinit(runner.allocator);
    }
};

test "test runner" {
    var runner = TestRunner.init(std.testing.allocator);
    defer runner.deinit();
    try runner.add("dummy", struct {
        fn dummy() !void { return; }
    }.dummy);
    const passed = try runner.run();
    try std.testing.expectEqual(@as(usize, 1), passed);
}
