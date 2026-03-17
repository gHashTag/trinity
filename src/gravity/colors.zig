// ANSI color codes — local copy to avoid circular dep on trinity.tri
// Source of truth: src/tri/tri_colors.zig

const std = @import("std");

pub const GREEN = "\x1b[38;2;0;229;153m";
pub const GOLDEN = "\x1b[38;2;255;215;0m";
pub const WHITE = "\x1b[38;2;255;255;255m";
pub const GRAY = "\x1b[38;2;156;156;160m";
pub const RED = "\x1b[38;2;239;68;68m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const YELLOW = "\x1b[38;2;255;255;0m";
pub const RESET = "\x1b[0m";

pub fn printGold(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(GOLDEN ++ fmt ++ RESET, args);
}

pub fn printGreen(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(GREEN ++ fmt ++ RESET, args);
}

pub fn printWhite(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(WHITE ++ fmt ++ RESET, args);
}

pub fn printYellow(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(YELLOW ++ fmt ++ RESET, args);
}

pub fn printCyan(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(CYAN ++ fmt ++ RESET, args);
}

pub fn printRed(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(RED ++ fmt ++ RESET, args);
}

pub fn printPurple(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(PURPLE ++ fmt ++ RESET, args);
}

pub fn printGray(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(GRAY ++ fmt ++ RESET, args);
}
