// ANSI Terminal Colors — Generated from specs/terminal/colors.tri
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// COLOR CONSTANTS (ANSI 256-color mode)
// ============================================================================

pub const GREEN = "\x1b[38;2;0;229;153m";
pub const GOLDEN = "\x1b[38;2;255;215;0m";
pub const WHITE = "\x1b[38;2;255;255;255m";
pub const GRAY = "\x1b[38;2;156;156;160m";
pub const RED = "\x1b[38;2;239;68;68m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const YELLOW = "\x1b[38;2;255;255;0m";
pub const RESET = "\x1b[0m";

// ============================================================================
// PRINT FUNCTIONS
// ============================================================================

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

// ============================================================================
// TESTS
// ============================================================================

test "ANSI Colors - GREEN exists" {
    try std.testing.expect(GREEN.len > 0);
}

test "ANSI Colors - RESET exists" {
    try std.testing.expectEqualStrings("\x1b[0m", RESET);
}

test "ANSI Colors - All colors defined" {
    try std.testing.expect(GREEN.len > 0);
    try std.testing.expect(GOLDEN.len > 0);
    try std.testing.expect(WHITE.len > 0);
    try std.testing.expect(GRAY.len > 0);
    try std.testing.expect(RED.len > 0);
    try std.testing.expect(CYAN.len > 0);
    try std.testing.expect(PURPLE.len > 0);
    try std.testing.expect(YELLOW.len > 0);
}
