// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY — FORMAT & ASCII RENDERING
// ═══════════════════════════════════════════════════════════════════════════════
// Shared formatting helpers for geometry CLI output.
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ANSI color codes
pub const GOLD = "\x1b[38;2;255;215;0m";
pub const CYAN = "\x1b[38;2;0;204;255m";
pub const PURPLE = "\x1b[38;2;170;102;255m";
pub const GREEN = "\x1b[38;2;0;229;153m";
pub const WHITE = "\x1b[97m";
pub const GRAY = "\x1b[90m";
pub const RED = "\x1b[91m";
pub const RESET = "\x1b[0m";
pub const BOLD = "\x1b[1m";

/// Print a box header
pub fn boxHeader(title: []const u8) void {
    std.debug.print("\n  {s}+====================================================================+{s}\n", .{ GOLD, RESET });
    std.debug.print("  {s}|  {s: <64}|{s}\n", .{ GOLD, title, RESET });
    std.debug.print("  {s}+====================================================================+{s}\n", .{ GOLD, RESET });
}

/// Print a section header
pub fn sectionHeader(title: []const u8) void {
    std.debug.print("\n  {s}{s}{s}\n", .{ GOLD, title, RESET });
    std.debug.print("  {s}---------------------------------------------{s}\n", .{ GRAY, RESET });
}

/// Print a labeled float value
pub fn labelFloat(label: []const u8, value: f64) void {
    std.debug.print("  {s: <22}{s}{d:.6}{s}\n", .{ label, WHITE, value, RESET });
}

/// Print a labeled float value with unit
pub fn labelFloatUnit(label: []const u8, value: f64, unit: []const u8) void {
    std.debug.print("  {s: <22}{s}{d:.6}{s} {s}{s}{s}\n", .{ label, WHITE, value, RESET, GRAY, unit, RESET });
}

/// Print a labeled integer value
pub fn labelInt(label: []const u8, value: i32) void {
    std.debug.print("  {s: <22}{s}{d}{s}\n", .{ label, WHITE, value, RESET });
}

/// Print a labeled string value
pub fn labelStr(label: []const u8, value: []const u8) void {
    std.debug.print("  {s: <22}{s}{s}{s}\n", .{ label, WHITE, value, RESET });
}

/// Print a ternary trit indicator with color: +1 (green), 0 (cyan), -1 (purple)
pub fn tritIndicator(value: i8) void {
    switch (value) {
        1 => std.debug.print("{s}+1{s}", .{ GREEN, RESET }),
        0 => std.debug.print("{s} 0{s}", .{ CYAN, RESET }),
        -1 => std.debug.print("{s}-1{s}", .{ PURPLE, RESET }),
        else => std.debug.print("??", .{}),
    }
}

/// Print a ternary result line
pub fn tritResult(label: []const u8, value: i8) void {
    std.debug.print("  {s: <22}", .{label});
    tritIndicator(value);
    const meaning: []const u8 = switch (value) {
        1 => " (positive/inside/CCW)",
        0 => " (zero/boundary/collinear)",
        -1 => " (negative/outside/CW)",
        else => "",
    };
    std.debug.print("{s}{s}{s}\n", .{ GRAY, meaning, RESET });
}

/// Print a separator line
pub fn separator() void {
    std.debug.print("  {s}---------------------------------------------{s}\n", .{ GRAY, RESET });
}

/// Print a box footer
pub fn boxFooter() void {
    std.debug.print("  {s}+====================================================================+{s}\n\n", .{ GOLD, RESET });
}

/// Print verification result
pub fn verified(label: []const u8, ok: bool) void {
    if (ok) {
        std.debug.print("  {s: <22}{s}VERIFIED{s}\n", .{ label, GREEN, RESET });
    } else {
        std.debug.print("  {s: <22}{s}FAILED{s}\n", .{ label, RED, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOMETRY FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "format_colors_defined" {
    try std.testing.expect(GOLD.len > 0);
    try std.testing.expect(CYAN.len > 0);
    try std.testing.expect(PURPLE.len > 0);
    try std.testing.expect(GREEN.len > 0);
    try std.testing.expect(WHITE.len > 0);
    try std.testing.expect(GRAY.len > 0);
    try std.testing.expect(RED.len > 0);
    try std.testing.expect(RESET.len > 0);
    try std.testing.expect(BOLD.len > 0);
}

test "format_trit_indicator_positive" {
    // Test positive trit (+1) - should print green +1
    // Can't easily test output, but can verify function doesn't crash
    tritIndicator(1);
}

test "format_trit_indicator_zero" {
    // Test zero trit (0) - should print cyan 0
    tritIndicator(0);
}

test "format_trit_indicator_negative" {
    // Test negative trit (-1) - should print purple -1
    tritIndicator(-1);
}

test "format_trit_indicator_invalid" {
    // Test invalid trit value
    tritIndicator(2);
    tritIndicator(-2);
}

test "format_label_functions" {
    // Test all label functions don't crash
    labelFloat("Test Float", 3.14159);
    labelFloatUnit("Test Unit", 2.71828, "rad");
    labelInt("Test Int", 42);
    labelStr("Test Str", "hello");
}

test "format_box_functions" {
    // Test box formatting functions don't crash
    boxHeader("Test Header");
    separator();
    sectionHeader("Test Section");
    boxFooter();
}

test "format_trit_result" {
    // Test trit result with all values
    tritResult("Positive Test", 1);
    tritResult("Zero Test", 0);
    tritResult("Negative Test", -1);
}

test "format_verified" {
    // Test verified function
    verified("Good Test", true);
    verified("Bad Test", false);
}

test "format_all_trit_values" {
    // Verify all valid trit values
    const trit_values = [_]i8{ -1, 0, 1 };
    for (trit_values) |v| {
        tritIndicator(v);
        tritResult("Test", v);
    }
}
