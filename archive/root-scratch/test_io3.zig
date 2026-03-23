const std = @import("std");
pub fn main() !void {
    const stderr = std.io.getStdErr();
    try std.io.getStdErr().writeAll("test");
}$
