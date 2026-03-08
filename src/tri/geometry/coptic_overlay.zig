// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY v2.0 — Coptic 27-Glyph Lattice Overlay
// ═══════════════════════════════════════════════════════════════════════════════
// Maps 27 Coptic glyphs to the ternary 3D lattice {-1,0,+1}^3.
//
// Mapping: glyph index i → (x, y, z) where:
//   z = i/9 - 1       layer: -1=matter(1-9), 0=energy(10-90), +1=info(100-900)
//   y = (i%9)/3 - 1   row
//   x = i%3 - 1       column
//
// 27 = 3^3 = 1 tryte = complete ternary cube
// Sum of all glyph values = 4995
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const fmt = @import("format.zig");
const gematria = @import("../gematria.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const CopticLatticePoint = struct {
    x: i8,
    y: i8,
    z: i8,
    glyph_index: u8,
    value: u16,
    kingdom: Kingdom,
};

pub const Kingdom = enum {
    matter, // 1-9 (units)
    energy, // 10-90 (tens)
    info, // 100-900 (hundreds)
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMPTIME LATTICE
// ═══════════════════════════════════════════════════════════════════════════════

/// Map glyph index to ternary 3D coordinates
fn mapIndexToCoords(i: u8) struct { x: i8, y: i8, z: i8 } {
    const zi: i8 = @as(i8, @intCast(i / 9)) - 1;
    const yi: i8 = @as(i8, @intCast((i % 9) / 3)) - 1;
    const xi: i8 = @as(i8, @intCast(i % 3)) - 1;
    return .{ .x = xi, .y = yi, .z = zi };
}

/// Full 27-point Coptic lattice (comptime generated)
pub const COPTIC_LATTICE: [27]CopticLatticePoint = blk: {
    var lattice: [27]CopticLatticePoint = undefined;
    for (0..27) |i| {
        const coords = mapIndexToCoords(@intCast(i));
        const kingdom: Kingdom = if (i < 9) .matter else if (i < 18) .energy else .info;
        lattice[i] = .{
            .x = coords.x,
            .y = coords.y,
            .z = coords.z,
            .glyph_index = @intCast(i),
            .value = gematria.COPTIC_TABLE[i].value,
            .kingdom = kingdom,
        };
    }
    break :blk lattice;
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom coptic — Display 27 Coptic glyphs mapped to ternary lattice
pub fn cmdCoptic() void {
    fmt.boxHeader("COPTIC 27-GLYPH TERNARY LATTICE");
    std.debug.print("  {s}27 = 3^3 = 1 tryte | 3 kingdoms x 9 glyphs{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    const kingdom_names = [3][]const u8{ "MATTER (units 1-9)", "ENERGY (tens 10-90)", "INFO (hundreds 100-900)" };
    const kingdom_colors = [3][]const u8{ fmt.CYAN, fmt.GREEN, fmt.GOLD };
    const z_values = [3]i8{ -1, 0, 1 };

    var grand_total: u32 = 0;

    for (0..3) |layer| {
        std.debug.print("  {s}{s}{s}  (z = {d})\n", .{
            kingdom_colors[layer], kingdom_names[layer], fmt.RESET, z_values[layer],
        });
        std.debug.print("  {s}---------------------------------------------{s}\n", .{ fmt.GRAY, fmt.RESET });

        // 3x3 grid
        var y: i8 = -1;
        while (y <= 1) : (y += 1) {
            std.debug.print("    y={d: >2}  ", .{y});
            var x: i8 = -1;
            while (x <= 1) : (x += 1) {
                // Find the point
                const idx: usize = @intCast(@as(i32, z_values[layer] + 1) * 9 + @as(i32, y + 1) * 3 + @as(i32, x + 1));
                const pt = COPTIC_LATTICE[idx];

                // Encode glyph as UTF-8
                var glyph_buf: [4]u8 = undefined;
                const glyph_len = std.unicode.utf8Encode(gematria.COPTIC_TABLE[pt.glyph_index].codepoint, &glyph_buf) catch 0;

                std.debug.print("{s}{s}{s}={d: <4} ", .{
                    kingdom_colors[layer],
                    glyph_buf[0..glyph_len],
                    fmt.RESET,
                    pt.value,
                });
                grand_total += pt.value;
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    fmt.separator();
    std.debug.print("  {s}Sum of all values:{s} {s}{d}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.GOLD, grand_total, fmt.RESET });
    std.debug.print("  {s}Total glyphs:{s}     {s}27 = 3^3 = 1 tryte{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, fmt.RESET });
    std.debug.print("  {s}Coordinate range:{s} {s}{{-1, 0, +1}}^3{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, fmt.RESET });
    std.debug.print("\n  {s}3 kingdoms x 9 glyphs = 27 = 3^3 = 1 tryte{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}Each kingdom is a 3x3 slice of the ternary cube.{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

/// tri geom trit3d-coptic — Enhanced 27-point lattice with glyph labels
pub fn cmdTrit3DCoptic() void {
    fmt.boxHeader("TERNARY 3D LATTICE + COPTIC OVERLAY");
    std.debug.print("  {s}27 points = {{-1,0,+1}}^3 with Coptic glyph labels{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    std.debug.print("  {s}{s: >4} {s: >4} {s: >4}   {s: >6} {s: >5} {s: >8}{s}\n", .{
        fmt.GOLD, "x", "y", "z", "glyph", "value", "kingdom", fmt.RESET,
    });
    std.debug.print("  {s}{s}{s}\n", .{ fmt.GRAY, "-" ** 45, fmt.RESET });

    for (COPTIC_LATTICE) |pt| {
        var glyph_buf: [4]u8 = undefined;
        const glyph_len = std.unicode.utf8Encode(gematria.COPTIC_TABLE[pt.glyph_index].codepoint, &glyph_buf) catch 0;

        const color = switch (pt.kingdom) {
            .matter => fmt.CYAN,
            .energy => fmt.GREEN,
            .info => fmt.GOLD,
        };
        const kingdom_str = switch (pt.kingdom) {
            .matter => "matter",
            .energy => "energy",
            .info => "info",
        };

        std.debug.print("  {d: >4} {d: >4} {d: >4}   {s}{s: >6}{s} {d: >5} {s}{s: >8}{s}\n", .{
            pt.x,      pt.y,                    pt.z,
            color,     glyph_buf[0..glyph_len], fmt.RESET,
            pt.value,  color,                   kingdom_str,
            fmt.RESET,
        });
    }

    fmt.separator();

    // Summary statistics
    var matter_sum: u32 = 0;
    var energy_sum: u32 = 0;
    var info_sum: u32 = 0;
    for (COPTIC_LATTICE) |pt| {
        switch (pt.kingdom) {
            .matter => matter_sum += pt.value,
            .energy => energy_sum += pt.value,
            .info => info_sum += pt.value,
        }
    }

    std.debug.print("  {s}Matter sum (units):{s}    {s}{d}{s}   (1+2+...+9)\n", .{
        fmt.CYAN, fmt.RESET, fmt.WHITE, matter_sum, fmt.RESET,
    });
    std.debug.print("  {s}Energy sum (tens):{s}     {s}{d}{s}  (10+20+...+90)\n", .{
        fmt.GREEN, fmt.RESET, fmt.WHITE, energy_sum, fmt.RESET,
    });
    std.debug.print("  {s}Info sum (hundreds):{s}   {s}{d}{s} (100+200+...+900)\n", .{
        fmt.GOLD, fmt.RESET, fmt.WHITE, info_sum, fmt.RESET,
    });
    std.debug.print("  {s}Grand total:{s}           {s}{d}{s}\n", .{
        fmt.GRAY, fmt.RESET, fmt.GOLD, matter_sum + energy_sum + info_sum, fmt.RESET,
    });

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "COPTIC_LATTICE has 27 entries" {
    try std.testing.expectEqual(@as(usize, 27), COPTIC_LATTICE.len);
}

test "index 0 maps to (-1,-1,-1)" {
    const pt = COPTIC_LATTICE[0];
    try std.testing.expectEqual(@as(i8, -1), pt.x);
    try std.testing.expectEqual(@as(i8, -1), pt.y);
    try std.testing.expectEqual(@as(i8, -1), pt.z);
}

test "index 13 maps to (1,0,0)" {
    const pt = COPTIC_LATTICE[13];
    try std.testing.expectEqual(@as(i8, 1), pt.x);
    try std.testing.expectEqual(@as(i8, 1), pt.y);
    try std.testing.expectEqual(@as(i8, 0), pt.z);
}

test "index 26 maps to (1,1,1)" {
    const pt = COPTIC_LATTICE[26];
    try std.testing.expectEqual(@as(i8, 1), pt.x);
    try std.testing.expectEqual(@as(i8, 1), pt.y);
    try std.testing.expectEqual(@as(i8, 1), pt.z);
}

test "kingdom ranges are correct" {
    for (0..9) |i| {
        try std.testing.expectEqual(Kingdom.matter, COPTIC_LATTICE[i].kingdom);
    }
    for (9..18) |i| {
        try std.testing.expectEqual(Kingdom.energy, COPTIC_LATTICE[i].kingdom);
    }
    for (18..27) |i| {
        try std.testing.expectEqual(Kingdom.info, COPTIC_LATTICE[i].kingdom);
    }
}

test "sum of all values is 4995" {
    var sum: u32 = 0;
    for (COPTIC_LATTICE) |pt| {
        sum += pt.value;
    }
    try std.testing.expectEqual(@as(u32, 4995), sum);
}
