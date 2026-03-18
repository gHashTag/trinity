// @origin(spec:tri_zenodo.tri) @regen(manual-impl)

const std = @import("std");
const print = std.debug.print;

const RESET = "\x1b[0m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

pub const InputMode = enum {
    normal,
};

pub const REPLState = struct {
    mode: InputMode,
    buffer: []u8,
};

pub fn processREPLCommand(state: *REPLState, input: []const u8) !void {
    _ = state;
    _ = input;
    print("{s}REPL is disabled — use tri chat instead{s}\n", .{ YELLOW, RESET });
}

pub fn runInteractiveMode(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("{s}Interactive mode moved to tri chat{s}\n", .{ YELLOW, RESET });
}

pub fn processInput(allocator: std.mem.Allocator, state: *REPLState, input: []const u8) !void {
    _ = allocator;
    _ = state;
    _ = input;
    print("{s}Input processing moved to tri chat{s}\n", .{ YELLOW, RESET });
}

pub fn detectMode(input: []const u8) InputMode {
    _ = input;
    return .normal;
}

test "detectMode returns normal" {
    try std.testing.expectEqual(InputMode.normal, detectMode("hello"));
    try std.testing.expectEqual(InputMode.normal, detectMode(""));
}

test "REPLState fields" {
    var buf: [64]u8 = undefined;
    var state = REPLState{ .mode = .normal, .buffer = &buf };
    try std.testing.expectEqual(InputMode.normal, state.mode);
    state.mode = .normal;
    try std.testing.expectEqual(InputMode.normal, state.mode);
}
