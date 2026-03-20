const std = @import("std");

pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  HABENULA unfair-detect: P1 TODO - not implemented yet\n", .{});
    return 1;
}
