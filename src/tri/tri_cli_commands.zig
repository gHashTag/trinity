// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

const std = @import("std");
const print = std.debug.print;

const RESET = "\x1b[0m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";

pub fn runCodeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}code command moved to tri run{s}\n", .{ YELLOW, RESET });
}

pub fn runChatCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}chat command moved to tri chat{s}\n", .{ YELLOW, RESET });
}

pub fn runSWECommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}swe command moved to tri loop{s}\n", .{ YELLOW, RESET });
}

pub fn runIntelligenceCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}intelligence command moved to tri agent run{s}\n", .{ YELLOW, RESET });
}

test "cli commands are callable" {
    const alloc = std.testing.allocator;
    const empty: []const []const u8 = &.{};
    try runCodeCommand(alloc, empty);
    try runChatCommand(alloc, empty);
    try runSWECommand(alloc, empty);
    try runIntelligenceCommand(alloc, empty);
}
