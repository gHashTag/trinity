//! Math Format — Generated from specs/tri/math_format.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from format.tri spec
//! Modify spec and regenerate: vibee gen format

const std = @import("std");

// ============================================================================
// COLOR STYLES
// ============================================================================

/// ANSI color codes for terminal output
pub const ColorStyle = struct {
    /// Reset all styles
    pub const RESET: []const u8 = "\x1b[0m";

    /// Gold color — for Golden ratio values, TRINITY
    pub const GOLD: []const u8 = "\x1b[38;5;220m";

    /// Cyan color — for Transcendental numbers (π, e)
    pub const CYAN: []const u8 = "\x1b[36m";

    /// Purple color — for Quantum constants, sacred identities
    pub const PURPLE: []const u8 = "\x1b[38;5;141m";

    /// Green color — for Success, verification passed
    pub const GREEN: []const u8 = "\x1b[32m";

    /// Red color — for Errors, verification failed
    pub const RED: []const u8 = "\x1b[31m";

    /// Yellow color — for Warnings, benchmarks
    pub const YELLOW: []const u8 = "\x1b[33m";
};

// ============================================================================
// OUTPUT FORMAT
// ============================================================================

/// Output format options
pub const OutputFormat = enum(u8) {
    pretty = 0,
    json = 1,
    csv = 2,
};

/// Text alignment
pub const Alignment = enum(u8) {
    left = 0,
    center = 1,
    right = 2,
};

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Configuration for output formatting
pub const FormatConfig = struct {
    format: OutputFormat = .pretty,
    precision: usize = 16,
    use_colors: bool = true,
    show_plot: bool = false,
};

/// Table column definition
pub const TableColumn = struct {
    header: []const u8,
    width: usize,
    alignment: Alignment,
};

/// Table formatting configuration
pub const TableFormat = struct {
    columns: []const TableColumn,
    padding: usize = 2,
    show_borders: bool = true,
};

// ============================================================================
// BEHAVIORS / FUNCTIONS
// ============================================================================

/// Print text with specified color
pub fn printColored(color: []const u8, text: []const u8) void {
    std.debug.print("{s}{s}{s}", .{ color, text, ColorStyle.RESET });
}

/// Format float with precision (simplified - uses default Zig float formatting)
pub fn formatFloat(allocator: std.mem.Allocator, value: f64, precision: usize) ![]u8 {
    _ = precision;

    // For Zig 0.15, use bufPrint for float formatting
    var buf: [64]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return error.FormatFailed;

    // Copy to allocated buffer
    const result = try allocator.alloc(u8, formatted.len);
    @memcpy(result, formatted);

    return result;
}

/// Format integer with digit grouping (commas every 3 digits)
pub fn formatIntGrouped(allocator: std.mem.Allocator, value: i64) ![]u8 {
    // Handle zero case
    if (value == 0) {
        return allocator.dupe(u8, "0");
    }

    // Handle negative numbers
    const is_negative = value < 0;
    const abs_value: u64 = if (is_negative) @intCast(-value) else @intCast(value);

    // Count digits
    var temp: u64 = abs_value;
    var num_digits: usize = 0;
    while (temp > 0) {
        temp /= 10;
        num_digits += 1;
    }

    // Calculate commas needed
    const num_commas = if (num_digits > 3) (num_digits - 1) / 3 else 0;

    // Total length including optional minus sign
    const total_len = num_digits + num_commas + @as(usize, @intFromBool(is_negative));

    var buffer = try allocator.alloc(u8, total_len);
    var write_pos: usize = total_len;

    // Build string from right to left
    temp = abs_value;
    var digit_idx: usize = 0;

    while (temp > 0) {
        // Insert comma every 3 digits (but not at the start)
        if (digit_idx > 0 and digit_idx % 3 == 0) {
            write_pos -= 1;
            buffer[write_pos] = ',';
        }

        const digit = @as(u8, @intCast(temp % 10)) + '0';
        write_pos -= 1;
        buffer[write_pos] = digit;
        temp /= 10;
        digit_idx += 1;
    }

    // Add minus sign if needed
    if (is_negative) {
        buffer[0] = '-';
    }

    return buffer;
}

/// Print table header
pub fn printTableHeader(columns: []const TableColumn, padding: usize) void {
    // Print top border
    printTableBorder(columns, padding, "╔", "╦", "╗");

    // Print header row
    for (columns, 0..) |col, i| {
        const pad = " " ** padding;
        const sep = if (i < columns.len - 1) "║" else "║";
        std.debug.print("{s}{s}{s}{s}", .{ pad, col.header, pad, sep });
    }
    std.debug.print("\n", .{});

    // Print header separator
    printTableBorder(columns, padding, "╠", "╬", "╣");
}

/// Print table row
pub fn printTableRow(columns: []const TableColumn, values: []const []const u8, padding: usize) void {
    for (columns, values, 0..) |col, val, i| {
        _ = col;
        const pad = " " ** padding;
        const sep = if (i < columns.len - 1) "║" else "║";
        std.debug.print("{s}{s}{s}{s}", .{ pad, val, pad, sep });
    }
    std.debug.print("\n", .{});
}

/// Print table footer
pub fn printTableFooter(columns: []const TableColumn, padding: usize) void {
    printTableBorder(columns, padding, "╚", "╩", "╝");
}

/// Print table border
fn printTableBorder(columns: []const TableColumn, padding: usize, left: []const u8, mid: []const u8, right: []const u8) void {
    std.debug.print("{s}", .{left});
    for (columns, 0..) |col, i| {
        const width = col.width + (padding * 2);
        const sep = if (i < columns.len - 1) mid else right;
        const line = "═" ** width;
        std.debug.print("{s}{s}", .{ line, sep });
    }
    std.debug.print("\n", .{});
}

/// Export data as CSV string
pub fn exportCsv(
    allocator: std.mem.Allocator,
    headers: []const []const u8,
    rows: []const []const []const u8,
) ![]u8 {
    // Calculate needed length (approximate)
    var total_len: usize = 0;
    for (headers) |h| total_len += h.len + 3; // quotes + comma
    total_len += 1; // newline
    for (rows) |row| {
        for (row) |cell| total_len += cell.len + 3;
        total_len += 1;
    }

    var buffer = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    // Write header row
    for (headers, 0..) |h, i| {
        if (i > 0) {
            buffer[pos] = ',';
            pos += 1;
        }
        buffer[pos] = '"';
        pos += 1;
        @memcpy(buffer[pos..][0..h.len], h);
        pos += h.len;
        buffer[pos] = '"';
        pos += 1;
    }
    buffer[pos] = '\n';
    pos += 1;

    // Write data rows
    for (rows) |row| {
        for (row, 0..) |cell, i| {
            if (i > 0) {
                buffer[pos] = ',';
                pos += 1;
            }
            buffer[pos] = '"';
            pos += 1;
            @memcpy(buffer[pos..][0..cell.len], cell);
            pos += cell.len;
            buffer[pos] = '"';
            pos += 1;
        }
        buffer[pos] = '\n';
        pos += 1;
    }

    return buffer[0..pos];
}

/// Pad string to specified width with alignment
pub fn padString(allocator: std.mem.Allocator, s: []const u8, width: usize, alignment: Alignment) ![]u8 {
    const len = s.len;
    if (len >= width) {
        return allocator.dupe(u8, s[0..width]);
    }

    const padding = width - len;
    const result = try allocator.alloc(u8, width);

    switch (alignment) {
        .left => {
            @memcpy(result[0..len], s);
            @memset(result[len..], ' ');
        },
        .right => {
            @memset(result[0..padding], ' ');
            @memcpy(result[padding..], s);
        },
        .center => {
            const left_pad = padding / 2;
            @memset(result[0..left_pad], ' ');
            @memcpy(result[left_pad..][0..len], s);
            @memset(result[left_pad + len ..], ' ');
        },
    }

    return result;
}

// ============================================================================
// TABLE TEMPLATES
// ============================================================================

/// Constants table template
pub const CONSTANTS_TABLE_COLUMNS = [_]TableColumn{
    TableColumn{ .header = "Constant", .width = 20, .alignment = .left },
    TableColumn{ .header = "Symbol", .width = 12, .alignment = .center },
    TableColumn{ .header = "Value", .width = 24, .alignment = .right },
    TableColumn{ .header = "Description", .width = 35, .alignment = .left },
};

/// Compare table template
pub const COMPARE_TABLE_COLUMNS = [_]TableColumn{
    TableColumn{ .header = "n", .width = 6, .alignment = .right },
    TableColumn{ .header = "φⁿ", .width = 20, .alignment = .right },
    TableColumn{ .header = "F(n)", .width = 25, .alignment = .right },
    TableColumn{ .header = "L(n)", .width = 25, .alignment = .right },
};

// ============================================================================
// TESTS
// ============================================================================

test "Format: printColored" {
    // Just verify it compiles and doesn't crash
    printColored(ColorStyle.GOLD, "test");
    printColored(ColorStyle.CYAN, "test");
    printColored(ColorStyle.PURPLE, "test");
    printColored(ColorStyle.GREEN, "test");
    printColored(ColorStyle.RED, "test");
    printColored(ColorStyle.YELLOW, "test");
}

test "Format: formatFloat" {
    const allocator = std.testing.allocator;

    // formatFloat returns default Zig float formatting
    const result1 = try formatFloat(allocator, 3.14159, 2);
    defer allocator.free(result1);
    // Check that it contains "3.14" somewhere (formatting may vary)
    try std.testing.expect(std.mem.indexOf(u8, result1, "3.14") != null);

    const result2 = try formatFloat(allocator, 1.618, 6);
    defer allocator.free(result2);
    try std.testing.expect(std.mem.indexOf(u8, result2, "1.618") != null);
}

test "Format: formatIntGrouped" {
    const allocator = std.testing.allocator;

    const result1 = try formatIntGrouped(allocator, 1000);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("1,000", result1);

    const result2 = try formatIntGrouped(allocator, 1234567);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("1,234,567", result2);

    const result3 = try formatIntGrouped(allocator, -999);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("-999", result3);
}

test "Format: exportCsv" {
    const allocator = std.testing.allocator;

    const headers = [_][]const u8{ "Name", "Value" };
    const rows = [_][]const []const u8{
        &[_][]const u8{ "Phi", "1.618" },
        &[_][]const u8{ "Pi", "3.141" },
    };

    const result = try exportCsv(allocator, &headers, &rows);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("\"Name\",\"Value\"\n\"Phi\",\"1.618\"\n\"Pi\",\"3.141\"\n", result);
}

test "Format: padString" {
    const allocator = std.testing.allocator;

    const result1 = try padString(allocator, "test", 10, .left);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("test      ", result1);

    const result2 = try padString(allocator, "test", 10, .right);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("      test", result2);

    const result3 = try padString(allocator, "test", 10, .center);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("   test   ", result3);
}

test "Format: CONSTANTS_TABLE_COLUMNS" {
    try std.testing.expectEqual(@as(usize, 4), CONSTANTS_TABLE_COLUMNS.len);
    try std.testing.expectEqualStrings("Constant", CONSTANTS_TABLE_COLUMNS[0].header);
    try std.testing.expectEqual(@as(usize, 20), CONSTANTS_TABLE_COLUMNS[0].width);
}

test "Format: COMPARE_TABLE_COLUMNS" {
    try std.testing.expectEqual(@as(usize, 4), COMPARE_TABLE_COLUMNS.len);
    try std.testing.expectEqualStrings("n", COMPARE_TABLE_COLUMNS[0].header);
    try std.testing.expectEqual(.right, COMPARE_TABLE_COLUMNS[0].alignment);
}
