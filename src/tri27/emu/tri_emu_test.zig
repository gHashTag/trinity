
const std = @import("std");

pub const TestCase = struct {
    name: []const u8,
    test_fn: *const fn () bool,
};

var results = std.ArrayList(bool).init(allocator);
defer results.deinit();

const test_cases = [_]TestCase{
    .{ .name = "CPUState init", .test_fn =testCpuInit },
    .{ .name = "LDI immediate", .test_fn =testLdiImmediate },
    .{ .name = "LDI src1, dst", .test_fn =testLdiSrc1 },
};
