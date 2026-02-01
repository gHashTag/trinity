const std = @import("std");

pub fn main() !void {
    const stdout = try std.io.getStdOut().writer();
    try stdout.print("I am Vibeec Codex, an expert Zig programmer.", .{});
}