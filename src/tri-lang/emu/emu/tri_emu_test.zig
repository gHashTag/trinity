const std = @import("std");

pub const TestCase = struct {
    name: []const u8,
    test_fn: *const fn () bool,
};

pub fn runTests() !void {
    const allocator = std.testing.allocator;
    var results = std.ArrayList(bool).init(allocator);
    defer results.deinit();

    const test_cases = [_]TestCase{
        .{ .name = "CPUState init", .test_fn = testCpuInit },
        .{ .name = "LDI immediate", .test_fn = testLdiImmediate },
        .{ .name = "LDI src1, dst", .test_fn = testLdiSrc1 },
    };

    for (test_cases) |tc| {
        const result = tc.test_fn();
        try results.append(result);
    }
}

// Stub test functions
fn testCpuInit() bool {
    return true;
}

fn testLdiImmediate() bool {
    return true;
}

fn testLdiSrc1() bool {
    return true;
}
