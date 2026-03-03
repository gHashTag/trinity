//! Resources stub for Trinity MCP
const std = @import("std");

pub fn generateResourcesList(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "{\"resources\":[]}";
}

pub fn hasResource(uri: []const u8) bool {
    _ = uri;
    return false;
}

pub fn loadResource(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    _ = allocator;
    _ = uri;
    return error.ResourceNotFound;
}
