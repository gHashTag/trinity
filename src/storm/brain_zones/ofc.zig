const std = @import("std");

// Stub for OFC module (storm_ofc.zig)
pub fn cmdVerdict(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    _ = allocator;
    _ = args;
    std.debug.print("⚠️  OFC verdict: P1 TODO - not implemented yet\n", .{});
    return 1;
}
