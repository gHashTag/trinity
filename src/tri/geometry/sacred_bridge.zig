// ═══════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY v2.0 — Sacred Formula Bridge
// ═══════════════════════════════════════════════════════════════════════════════
// Bridges geometry constants with the Sacred Formula engine:
//   V = n × 3^k × π^m × φ^p × e^q
//
// Every geometry constant is expressed through the Sacred Formula.
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");
const sacred_formula = @import("../math/formula.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// GEOMETRY CONSTANTS TABLE
// ═══════════════════════════════════════════════════════════════════════════════

const GeomConstant = struct {
    name: []const u8,
    value: f64,
    description: []const u8,
};

pub const GEOM_CONSTANTS = [_]GeomConstant{
    // Fractal dimensions
    .{ .name = "Sierpinski dim", .value = mod.SIERPINSKI_DIM, .description = "log(3)/log(2) = bits/trit" },
    .{ .name = "Koch dim", .value = mod.KOCH_DIM, .description = "log(4)/log(3)" },
    .{ .name = "Cantor dim", .value = mod.CANTOR_DIM, .description = "log(2)/log(3)" },
    // Golden constants
    .{ .name = "phi", .value = mod.PHI, .description = "golden ratio" },
    .{ .name = "phi^2", .value = mod.PHI_SQ, .description = "phi + 1" },
    .{ .name = "1/phi", .value = mod.INV_PHI, .description = "phi - 1" },
    // Roots
    .{ .name = "sqrt(2)", .value = mod.SQRT2, .description = "diagonal of unit square" },
    .{ .name = "sqrt(3)", .value = mod.SQRT3, .description = "vesica height/radius" },
    .{ .name = "sqrt(5)", .value = mod.SQRT5, .description = "diagonal of 1x2 rectangle" },
    // Spiral
    .{ .name = "golden spiral b", .value = mod.GOLDEN_SPIRAL_B, .description = "2*ln(phi)/pi" },
    // Platonic dihedral angles
    .{ .name = "tetra dihedral", .value = 70.528779365509308, .description = "acos(1/3)" },
    .{ .name = "cube dihedral", .value = 90.0, .description = "right angle" },
    .{ .name = "octa dihedral", .value = 109.47122063449069, .description = "acos(-1/3)" },
    .{ .name = "dodeca dihedral", .value = 116.56505117707799, .description = "acos(-1/sqrt(5))" },
    .{ .name = "icosa dihedral", .value = 138.18968510422140, .description = "acos(-sqrt(5)/3)" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri geom sacred — Show all geometry constants with Sacred Formula fits
pub fn cmdSacred() void {
    fmt.boxHeader("SACRED FORMULA BRIDGE — Geometry Constants");
    std.debug.print("  {s}V = n * 3^k * pi^m * phi^p * e^q{s}\n", .{ fmt.GRAY, fmt.RESET });
    std.debug.print("\n", .{});

    // Table header
    std.debug.print("  {s}{s: <20} {s: >12} {s: >24} {s: >8} {s}{s}\n", .{
        fmt.GOLD, "Constant", "Value", "Formula", "Error%", "Description", fmt.RESET,
    });
    std.debug.print("  {s}{s}{s}\n", .{ fmt.GRAY, "-" ** 90, fmt.RESET });

    var total_err: f64 = 0;
    var exact_count: u32 = 0;

    for (GEOM_CONSTANTS) |c| {
        const fit = sacred_formula.fitSacredFormula(c.value);
        var formula_buf: [128]u8 = undefined;
        const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);

        const err_color = if (fit.error_pct < 0.01) fmt.GREEN else if (fit.error_pct < 1.0) fmt.WHITE else fmt.RED;

        std.debug.print("  {s}{s: <20}{s} {s}{d: >12.6}{s} {s}{s: >24}{s} {s}{d: >7.4}{s} {s}{s}{s}\n", .{
            fmt.CYAN, c.name, fmt.RESET,
            fmt.WHITE, c.value, fmt.RESET,
            fmt.GOLD, formula_str, fmt.RESET,
            err_color, fit.error_pct, fmt.RESET,
            fmt.GRAY, c.description, fmt.RESET,
        });

        total_err += fit.error_pct;
        if (fit.error_pct < 0.01) exact_count += 1;
    }

    fmt.separator();
    const avg_err = total_err / @as(f64, @floatFromInt(GEOM_CONSTANTS.len));
    std.debug.print("  {s}Constants:{s} {s}{d}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, GEOM_CONSTANTS.len, fmt.RESET });
    std.debug.print("  {s}Exact fits (<0.01%):{s} {s}{d}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.GREEN, exact_count, fmt.RESET });
    std.debug.print("  {s}Average error:{s} {s}{d:.4}%{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, avg_err, fmt.RESET });
    std.debug.print("\n  {s}Every geometry constant = product of {{3, pi, phi, e}}{s}\n", .{ fmt.GOLD, fmt.RESET });

    fmt.boxFooter();
}

/// Reusable helper: print a single Sacred Formula fit
pub fn printFormulaFit(value: f64, label: []const u8) void {
    const fit = sacred_formula.fitSacredFormula(value);
    var formula_buf: [128]u8 = undefined;
    const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);

    const err_color = if (fit.error_pct < 0.01) fmt.GREEN else if (fit.error_pct < 1.0) fmt.CYAN else fmt.RED;

    std.debug.print("    {s}{s: <22}{s} {s}{d:.6}{s}  =  {s}{s}{s}  {s}(err: {d:.4}%){s}\n", .{
        fmt.WHITE, label, fmt.RESET,
        fmt.CYAN, value, fmt.RESET,
        fmt.GOLD, formula_str, fmt.RESET,
        err_color, fit.error_pct, fmt.RESET,
    });
}

/// tri geom formula-predict <value> — Fit any value to Sacred Formula
pub fn cmdFormulaPredict(args: []const []const u8) void {
    if (args.len == 0) {
        std.debug.print("Usage: tri geom formula-predict <value>\n", .{});
        std.debug.print("  Fits any number to V = n * 3^k * pi^m * phi^p * e^q\n", .{});
        return;
    }

    const value = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Error: cannot parse '{s}' as a number\n", .{args[0]});
        return;
    };

    fmt.boxHeader("SACRED FORMULA PREDICTION");
    std.debug.print("\n", .{});

    const fit = sacred_formula.fitSacredFormula(value);
    var formula_buf: [128]u8 = undefined;
    const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);

    std.debug.print("  {s}Target:{s}   {s}{d:.10}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, value, fmt.RESET });
    std.debug.print("  {s}Formula:{s}  {s}V = {s}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.GOLD, formula_str, fmt.RESET });
    std.debug.print("  {s}Computed:{s} {s}{d:.10}{s}\n", .{ fmt.GRAY, fmt.RESET, fmt.WHITE, fit.computed, fmt.RESET });

    const err_color = if (fit.error_pct < 0.01) fmt.GREEN else if (fit.error_pct < 1.0) fmt.CYAN else fmt.RED;
    std.debug.print("  {s}Error:{s}    {s}{d:.6}%{s}\n", .{ fmt.GRAY, fmt.RESET, err_color, fit.error_pct, fmt.RESET });

    fmt.separator();
    std.debug.print("  {s}Parameters:{s}  n={s}{d}{s}  k={s}{d}{s}  m={s}{d}{s}  p={s}{d}{s}  q={s}{d}{s}\n", .{
        fmt.GRAY, fmt.RESET,
        fmt.WHITE, fit.n, fmt.RESET,
        fmt.WHITE, fit.k, fmt.RESET,
        fmt.WHITE, fit.m, fmt.RESET,
        fmt.WHITE, fit.p, fmt.RESET,
        fmt.WHITE, fit.q, fmt.RESET,
    });
    std.debug.print("  {s}Meaning:{s}   {d} * 3^{d} * pi^{d} * phi^{d} * e^{d}\n", .{
        fmt.GRAY, fmt.RESET,
        fit.n, fit.k, fit.m, fit.p, fit.q,
    });

    // Check if close to known geometry constants
    std.debug.print("\n", .{});
    fmt.sectionHeader("Nearest Geometry Constants");
    var found_match = false;
    for (GEOM_CONSTANTS) |c| {
        const diff = @abs(c.value - value) / @max(@abs(value), 1e-15) * 100.0;
        if (diff < 5.0) {
            std.debug.print("    {s}{s}{s} = {d:.6}  ({d:.3}% away)\n", .{
                fmt.CYAN, c.name, fmt.RESET, c.value, diff,
            });
            found_match = true;
        }
    }
    if (!found_match) {
        std.debug.print("    {s}(no close geometry constants found){s}\n", .{ fmt.GRAY, fmt.RESET });
    }

    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GEOM_CONSTANTS has expected length" {
    try std.testing.expectEqual(@as(usize, 15), GEOM_CONSTANTS.len);
}

test "fitSacredFormula finds reasonable fit for Sierpinski dim" {
    const fit = sacred_formula.fitSacredFormula(mod.SIERPINSKI_DIM);
    try std.testing.expect(fit.error_pct < 5.0);
}

test "fitSacredFormula finds exact fit for phi" {
    const fit = sacred_formula.fitSacredFormula(mod.PHI);
    // phi should be exactly n=1, p=1 → error ≈ 0%
    try std.testing.expect(fit.error_pct < 0.01);
}

test "fitSacredFormula finds reasonable fit for dihedral angles" {
    const tetra_fit = sacred_formula.fitSacredFormula(70.528779365509308);
    try std.testing.expect(tetra_fit.error_pct < 5.0);
    const icosa_fit = sacred_formula.fitSacredFormula(138.18968510422140);
    try std.testing.expect(icosa_fit.error_pct < 5.0);
}
