const std = @import("std");

const O = enum(u8) { A = 1, B = 2 };

pub fn main() !void {
    const x: O = @enumFromInt(O, 1);
    std.debug.print("Result: {}\n", .{x});
}
