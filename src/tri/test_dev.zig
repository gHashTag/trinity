const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main(allocator: Allocator, args: []const u8) !void {
    _ = args;
    std.debug.print("Testing dev commands module", .{});
    std.debug.print("Command: {s}", .{if (args.len > 0) args[0] else "none"});
}
