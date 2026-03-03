// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Shared Constants
// ═══════════════════════════════════════════════════════════════════════════════
//
// ANSI color codes and version constants shared across all TRI modules.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const GREEN = "\x1b[38;2;0;229;153m";
pub const GOLDEN = "\x1b[38;2;255;215;0m";
pub const YELLOW = "\x1b[38;2;255;255;0m";
pub const WHITE = "\x1b[38;2;255;255;255m";
pub const GRAY = "\x1b[38;2;156;156;160m";
pub const RED = "\x1b[38;2;239;68;68m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const MAGENTA = "\x1b[38;2;255;0;255m";
pub const RESET = "\x1b[0m";

pub const VERSION = "1.0.1";

// ═══════════════════════════════════════════════════════════════════════════════
// Color Printing Functions
// ═══════════════════════════════════════════════════════════════════════════════

pub fn printGold(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ GOLDEN } ++ args ++ .{RESET});
}

pub fn printGreen(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ GREEN } ++ args ++ .{RESET});
}

pub fn printWhite(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ WHITE } ++ args ++ .{RESET});
}

pub fn printGray(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ GRAY } ++ args ++ .{RESET});
}

pub fn printRed(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ RED } ++ args ++ .{RESET});
}

pub fn printCyan(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ CYAN } ++ args ++ .{RESET});
}

pub fn printPurple(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ PURPLE } ++ args ++ .{RESET});
}

pub fn printMagenta(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ MAGENTA } ++ args ++ .{RESET});
}

pub fn printYellow(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ fmt ++ "{s}", .{ YELLOW } ++ args ++ .{RESET});
}
