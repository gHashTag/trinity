const std = @import("std");

pub fn main() void {
    const gf = @import("golden-float");
    std.debug.print("gf module type: {}\n", .{@TypeOf(gf)});
}
