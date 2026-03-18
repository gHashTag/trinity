// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY v2.0 — Golden Logarithmic Spiral
// ═══════════════════════════════════════════════════════════════════════════════
// True golden spiral: r(θ) = a × φ^(2θ/π)
//
// Properties:
//   - Growth factor b = 2×ln(φ)/π = 0.30635
//   - Radius multiplies by φ every quarter turn (90°)
//   - Radius multiplies by φ² every half turn (180°)
//   - Self-similar: every quarter turn is a scaled copy
//
// Unlike the existing math/compute.zig spiral (linear radius),
// this is the true logarithmic spiral found in nautilus shells,
// galaxies, and hurricanes.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoldenSpiralPoint = struct {
    theta: f64, // radians
    theta_deg: f64,
    r: f64,
    x: f64,
    y: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Growth factor: b = 2*ln(φ)/π
pub const GROWTH_FACTOR: f64 = 2.0 * @log(mod.PHI) / mod.PI;

/// Compute a point on the golden logarithmic spiral
/// r(θ) = a × e^(b×θ) where b = 2*ln(φ)/π
/// Equivalently: r(θ) = a × φ^(2θ/π)
pub fn goldenSpiralPoint(theta: f64, a: f64) GoldenSpiralPoint {
    const r = a * @exp(GROWTH_FACTOR * theta);
    return .{
        .theta = theta,
        .theta_deg = theta * 180.0 / mod.PI,
        .r = r,
        .x = r * @cos(theta),
        .y = r * @sin(theta),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom spiral [turns] [scale]
pub fn cmdSpiral(args: []const []const u8) void {
    var turns: u32 = 2;
    var scale: f64 = 1.0;
    if (args.len > 0) {
        turns = std.fmt.parseInt(u32, args[0], 10) catch 2;
    }
    if (args.len > 1) {
        scale = std.fmt.parseFloat(f64, args[1]) catch 1.0;
    }
    if (turns > 10) turns = 10;
    if (turns == 0) turns = 1;

    fmt.boxHeader("GOLDEN LOGARITHMIC SPIRAL");
    std.debug.print("  {s}r(theta) = a * phi^(2*theta/pi){s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    // Properties
    fmt.sectionHeader("Properties");
    fmt.labelFloatUnit("Scale (a):", scale, "");
    fmt.labelFloatUnit("Growth factor (b):", GROWTH_FACTOR, "= 2*ln(phi)/pi");
    fmt.labelFloatUnit("phi:", mod.PHI, "golden ratio");
    std.debug.print("  {s}Quarter turn:{s}  r multiplied by {s}phi = {d:.6}{s}\n", .{
        fmt.GRAY, fmt.RESET, fmt.GOLD, mod.PHI, fmt.RESET,
    });
    std.debug.print("  {s}Half turn:{s}     r multiplied by {s}phi^2 = {d:.6}{s}\n", .{
        fmt.GRAY, fmt.RESET, fmt.GOLD, mod.PHI_SQ, fmt.RESET,
    });
    std.debug.print("  {s}Full turn:{s}     r multiplied by {s}phi^4 = {d:.6}{s}\n", .{
        fmt.GRAY, fmt.RESET, fmt.GOLD, mod.PHI_SQ * mod.PHI_SQ, fmt.RESET,
    });

    // Coordinate table
    fmt.sectionHeader("Coordinates");
    std.debug.print("  {s}{s: >6} {s: >8} {s: >10} {s: >10} {s: >10}{s}\n", .{
        fmt.GOLD, "deg", "rad", "r", "x", "y", fmt.RESET,
    });
    std.debug.print("  {s}{s}{s}\n", .{ fmt.GRAY, "-" ** 52, fmt.RESET });

    const points_per_turn: u32 = 12;
    const total_points = turns * points_per_turn + 1;
    const step = 2.0 * mod.PI / @as(f64, @floatFromInt(points_per_turn));

    var i: u32 = 0;
    while (i < total_points) : (i += 1) {
        const theta = @as(f64, @floatFromInt(i)) * step;
        const pt = goldenSpiralPoint(theta, scale);
        std.debug.print("  {d: >6.0} {d: >8.3} {d: >10.4} {d: >10.4} {d: >10.4}\n", .{
            pt.theta_deg, pt.theta, pt.r, pt.x, pt.y,
        });
    }

    // ASCII spiral visualization
    fmt.sectionHeader("Visualization");
    renderAsciiSpiral(turns, scale);

    // Sacred connection
    std.debug.print("\n  {s}Sacred connection:{s}\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("  {s}The spiral expands by phi every 90 degrees.{s}\n", .{ fmt.WHITE, fmt.RESET });
    std.debug.print("  {s}Found in: nautilus shells, galaxy arms, hurricanes,{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}          sunflower seeds, DNA helix, cochlea.{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("  {s}Self-similarity: each quarter turn is a phi-scaled copy.{s}\n", .{ fmt.GRAY, fmt.RESET });

    fmt.boxFooter();
}

fn renderAsciiSpiral(turns: u32, scale: f64) void {
    const W: usize = 60;
    const H: usize = 30;
    var canvas: [H][W]u8 = undefined;

    // Clear canvas
    for (0..H) |row| {
        for (0..W) |col| {
            canvas[row][col] = ' ';
        }
    }

    // Plot spiral points
    const total_steps: u32 = turns * 120;
    const max_theta = @as(f64, @floatFromInt(turns)) * 2.0 * mod.PI;

    // Find max radius for scaling
    const max_pt = goldenSpiralPoint(max_theta, scale);
    const plot_scale = @min(
        @as(f64, @floatFromInt(W / 2 - 2)) / max_pt.r,
        @as(f64, @floatFromInt(H / 2 - 2)) / max_pt.r * 2.0,
    );

    const cx = W / 2;
    const cy = H / 2;

    var step: u32 = 0;
    while (step <= total_steps) : (step += 1) {
        const theta = @as(f64, @floatFromInt(step)) * max_theta / @as(f64, @floatFromInt(total_steps));
        const pt = goldenSpiralPoint(theta, scale);

        const sx = @as(i32, @intFromFloat(pt.x * plot_scale)) + @as(i32, @intCast(cx));
        const sy = @as(i32, @intFromFloat(-pt.y * plot_scale / 2.0)) + @as(i32, @intCast(cy));

        if (sx >= 0 and sx < @as(i32, @intCast(W)) and sy >= 0 and sy < @as(i32, @intCast(H))) {
            const ux: usize = @intCast(sx);
            const uy: usize = @intCast(sy);
            canvas[uy][ux] = '*';
        }
    }

    // Mark center
    canvas[cy][cx] = '+';

    // Render
    for (0..H) |row| {
        std.debug.print("    {s}", .{fmt.CYAN});
        for (0..W) |col| {
            if (canvas[row][col] == '+') {
                std.debug.print("{s}+{s}", .{ fmt.GOLD, fmt.CYAN });
            } else {
                std.debug.print("{c}", .{canvas[row][col]});
            }
        }
        std.debug.print("{s}\n", .{fmt.RESET});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "at theta=0, r=a" {
    const pt = goldenSpiralPoint(0.0, 1.0);
    try std.testing.expectApproxEqAbs(1.0, pt.r, 1e-10);
}

test "at theta=pi/2, r=a*phi (quarter turn)" {
    const pt = goldenSpiralPoint(std.math.pi / 2.0, 1.0);
    try std.testing.expectApproxEqAbs(mod.PHI, pt.r, 1e-6);
}

test "at theta=pi, r=a*phi^2 (half turn)" {
    const pt = goldenSpiralPoint(std.math.pi, 1.0);
    try std.testing.expectApproxEqAbs(mod.PHI_SQ, pt.r, 1e-6);
}

test "growth factor matches expected value" {
    try std.testing.expectApproxEqAbs(mod.GOLDEN_SPIRAL_B, GROWTH_FACTOR, 1e-10);
}

test "point coordinates are consistent" {
    const pt = goldenSpiralPoint(std.math.pi / 4.0, 2.0);
    const expected_x = pt.r * @cos(std.math.pi / 4.0);
    const expected_y = pt.r * @sin(std.math.pi / 4.0);
    try std.testing.expectApproxEqAbs(expected_x, pt.x, 1e-10);
    try std.testing.expectApproxEqAbs(expected_y, pt.y, 1e-10);
}
