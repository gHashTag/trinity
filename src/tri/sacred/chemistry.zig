// Stub chemistry module for compilation
const std = @import("std");

pub fn init(allocator: std.mem.Allocator) void {
    _ = allocator;
}

pub fn deinit(self: *anyerror!void) void {
    _ = self;
}
