// Stub for Zig 0.15 API compatibility
// fly_wave9 temporarily stubbed to avoid EnvMap API issues

const std = @import("std");

// Stub functions
pub fn deployWave9(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    return error.NotImplemented;
}

pub fn showWave9Status(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    return error.NotImplemented;
}

pub fn recycleWave9(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    return error.NotImplemented;
}
