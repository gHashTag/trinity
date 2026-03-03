//! Prompts stub for Trinity MCP
const std = @import("std");

pub fn generatePromptsList(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "{\"prompts\":[]}";
}

pub fn hasPrompt(name: []const u8) bool {
    _ = name;
    return false;
}

pub fn generatePromptGetResponse(allocator: std.mem.Allocator, name: []const u8, args: ?[]const u8) ![]const u8 {
    _ = allocator;
    _ = name;
    _ = args;
    return error.PromptNotFound;
}
