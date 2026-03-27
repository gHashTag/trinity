//! TRI Terminal — Generated from specs/tri/tri_terminal.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Color = enum(u8) {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    default,
};

pub const Style = enum(u8) {
    bold,
    dim,
    italic,
    underline,
    reverse,
};

pub const TerminalSize = struct {
    width: usize,
    height: usize,
};

pub fn getSize() TerminalSize {
    return .{ .width = 80, .height = 24 }; // Default fallback
}

pub fn colorize(allocator: std.mem.Allocator, text: []const u8, fg: Color) ![]u8 {
    const codes = [_]u8{ 30, 31, 32, 33, 34, 35, 36, 37, 39 };
    const code = codes[@intFromEnum(fg)];
    return std.fmt.allocPrint(allocator, "\x1b[{d}m{s}\x1b[0m", .{ code, text });
}

pub fn reset() []const u8 {
    return "\x1b[0m";
}

test "Terminal: colorize" {
    const allocator = std.testing.allocator;
    const result = try colorize(allocator, "test", .red);
    defer allocator.free(result);
    try std.testing.expect(result.len > 0);
}
