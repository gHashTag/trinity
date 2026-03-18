// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — FORMATTING MODULE
// ═══════════════════════════════════════════════════════════════════════════════
// Colors, tables, JSON/CSV export, ASCII spiral plot
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI COLOR CODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ColorStyle = struct {
    reset: []const u8 = "\x1b[0m",
    gold: []const u8 = "\x1b[38;5;220m",
    cyan: []const u8 = "\x1b[36m",
    purple: []const u8 = "\x1b[38;5;141m",
    green: []const u8 = "\x1b[32m",
    red: []const u8 = "\x1b[31m",
    yellow: []const u8 = "\x1b[33m",
    blue: []const u8 = "\x1b[34m",
    dim: []const u8 = "\x1b[2m",
    bold: []const u8 = "\x1b[1m",
};

pub const colors = ColorStyle{};

// ═══════════════════════════════════════════════════════════════════════════════
// OUTPUT FORMAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const OutputFormat = enum {
    pretty,
    json,
    csv,
};

pub const FormatConfig = struct {
    format: OutputFormat = .pretty,
    precision: usize = 16,
    use_colors: bool = true,
    show_plot: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

pub const Alignment = enum {
    left,
    center,
    right,
};

pub const TableColumn = struct {
    header: []const u8,
    width: usize,
    alignment: Alignment = .left,
    color: []const u8 = colors.reset,
};

pub fn printTable(writer: anytype, columns: []const TableColumn, rows: []const []const []const u8) !void {
    const total_width = blk: {
        var sum: usize = 0;
        for (columns) |col| sum += col.width + 1; // +1 for padding
        break :blk sum + 1;
    };
    _ = total_width; // Currently unused but kept for potential future use

    // Top border
    try writer.writeAll("╔");
    for (columns, 0..) |col, i| {
        try writer.writeByteNTimes('═', col.width);
        if (i < columns.len - 1) try writer.writeAll("╦");
    }
    try writer.writeAll("╗\n");

    // Header
    try writer.writeAll("║");
    for (columns) |col| {
        const padded = try padString(col.header, col.width, col.alignment);
        try writer.writeAll(col.color);
        try writer.writeAll(padded);
        try writer.writeAll(colors.reset);
        try writer.writeAll("║");
    }
    try writer.writeAll("\n");

    // Separator
    try writer.writeAll("╠");
    for (columns, 0..) |col, i| {
        try writer.writeByteNTimes('═', col.width);
        if (i < columns.len - 1) try writer.writeAll("╬");
    }
    try writer.writeAll("╣\n");

    // Data rows
    for (rows) |row| {
        try writer.writeAll("║");
        for (columns, 0..) |col, i| {
            if (i < row.len) {
                const padded = try padString(row[i], col.width, col.alignment);
                try writer.writeAll(padded);
            } else {
                try writer.writeByteNTimes(' ', col.width);
            }
            try writer.writeAll("║");
        }
        try writer.writeAll("\n");
    }

    // Bottom border
    try writer.writeAll("╚");
    for (columns, 0..) |col, i| {
        try writer.writeByteNTimes('═', col.width);
        if (i < columns.len - 1) try writer.writeAll("╩");
    }
    try writer.writeAll("╝\n");
}

fn padString(str: []const u8, width: usize, align_param: Alignment) ![width:0]u8 {
    var result: [width:0]u8 = undefined;
    @memset(&result, ' ');

    if (str.len >= width) {
        @memcpy(result[0..width], str[0..width]);
    } else {
        const start = switch (align_param) {
            .left => 0,
            .center => (width - str.len) / 2,
            .right => width - str.len,
        };
        @memcpy(result[start..][0..str.len], str);
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLOAT FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

pub fn formatFloat(allocator: std.mem.Allocator, value: f64, precision: usize) ![]u8 {
    _ = precision;
    const max_buf_len = 100;
    var buffer: [max_buf_len]u8 = undefined;
    const formatted = try std.fmt.bufPrintZ(&buffer, "{d:.6}", .{value});
    return allocator.dupe(u8, formatted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASCII SPIRAL PLOT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn plotSpiralAscii(writer: anytype, n_points: u32) !void {
    const width = 60;
    const height = 30;

    // Clear buffer
    var grid: [width * height]u8 = [_]u8{' '} ** (width * height);

    // Plot axes
    const mid_x = width / 2;
    const mid_y = height / 2;

    var i: usize = 0;
    while (i < width) : (i += 1) {
        grid[mid_y * width + i] = if (i == mid_x) '+' else '-';
    }
    i = 0;
    while (i < height) : (i += 1) {
        if (i == mid_y) continue;
        grid[i * width + mid_x] = '|';
    }

    // Plot spiral points
    const parent_mod = @import("mod.zig");
    var n: u32 = 0;
    while (n < n_points) : (n += 1) {
        const spiral = parent_mod.phiSpiral(n);

        // Scale and translate to grid
        const scale_x: f64 = 0.3;
        const scale_y: f64 = 0.3;
        const grid_x = @as(i32, @intFromFloat(spiral.x * scale_x)) + @as(i32, @intCast(mid_x));
        const grid_y = @as(i32, @intFromFloat(spiral.y * scale_y)) + @as(i32, @intCast(mid_y));

        if (grid_x >= 0 and grid_x < width and grid_y >= 0 and grid_y < height) {
            const idx = @as(usize, @intCast(grid_y)) * width + @as(usize, @intCast(grid_x));
            if (idx < grid.len) {
                grid[idx] = '*';
            }
        }
    }

    // Draw legend
    try writer.print("  φ-SPIRAL ({} points)\n", .{n_points});
    try writer.writeAll("  ╔════════════════════════════════════════════════════════════╗\n");

    var y: usize = 0;
    while (y < height) : (y += 1) {
        try writer.writeAll("  ║");
        try writer.writeAll(grid[y * width ..][0..width]);
        try writer.writeAll("║\n");
    }

    try writer.writeAll("  ╚════════════════════════════════════════════════════════════╝\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "format float" {
    const result = try formatFloat(std.testing.allocator, 1.618, 3);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("1.618", result);
}
