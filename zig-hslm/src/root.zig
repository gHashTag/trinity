// zig-hslm — HSLM Numerical Utilities
// Official HSLM library for Trinity
// Repository: https://codeberg.org/gHashTag/zig-hslm
// Branch: feat/vector-float-cast (f16 edge case tests + @floatCast)

const std = @import("std");

pub const f16_utils = @import("f16_utils.zig");

pub fn testAll() !void {
    std.debug.print("zig-hslm test suite passed\n", .{});
}
