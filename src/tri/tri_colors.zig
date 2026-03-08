// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Shared Constants
// ═══════════════════════════════════════════════════════════════════════════════
//
// ANSI color codes and version constants shared across all TRI modules.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

pub const GREEN = "\x1b[38;2;0;229;153m";
pub const GOLDEN = "\x1b[38;2;255;215;0m";
pub const WHITE = "\x1b[38;2;255;255;255m";
pub const GRAY = "\x1b[38;2;156;156;160m";
pub const RED = "\x1b[38;2;239;68;68m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const YELLOW = "\x1b[38;2;255;255;0m";
pub const RESET = "\x1b[0m";

pub const VERSION = "1.0.1";

const std = @import("std");

// Helper functions for colored output - each function is inline
// Color codes are comptime-known constants
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
