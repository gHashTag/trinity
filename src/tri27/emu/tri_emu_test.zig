
const std = @import("std");

pub const TestCase = struct {
    name: []const u8,
    test: *const fn () bool,
};

var results = std.ArrayList(bool).init(allocator);
defer results.deinit();

const test_cases = [_]TestCase{
    .{ .name = "CPUState init", .test = testCpuInit },
    .{ .name = "LDI immediate", .test = testLdiImmediate },
    .{ .name = "LDI src1, dst", .test = testLdiSrc1 },
};
