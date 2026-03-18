// ═══════════════════════════════════════════════════════════════════════════════
// GEMATRIA INTEGRATION MODULE v3.6
// ═══════════════════════════════════════════════════════════════════════════════
//
// Bridges existing Coptic Gematria engine (src/tri/gematria.zig) with
// Sacred Formula fitting engine (sacred_formula.zig).
//
// CLI: tri gematria <number|text>  /  tri math gematria <number|text>
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const gematria_engine = @import("../gematria.zig");
const sacred_formula = @import("formula.zig");

// ANSI colors
const GOLDEN = "\x1b[33m";
const CYAN = "\x1b[36m";
const PURPLE = "\x1b[35m";
const WHITE = "\x1b[97m";
const GRAY = "\x1b[90m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

/// Run gematria command: tri gematria <number|text>
pub fn runGematriaCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printGematriaHelp();
        return;
    }

    const input = args[0];

    // Try to parse as number first
    const maybe_number = std.fmt.parseInt(u32, input, 10) catch null;

    if (maybe_number) |number| {
        try runNumberMode(allocator, number);
    } else {
        try runTextMode(allocator, input);
    }
}

/// Number mode: decompose number into Coptic glyphs + sacred formula fit
fn runNumberMode(allocator: Allocator, number: u32) !void {
    const glyphs = try gematria_engine.numberToGlyphs(allocator, number);
    defer allocator.free(glyphs);

    // Compute sacred formula fit
    const target: f64 = @floatFromInt(number);
    const fit = sacred_formula.fitSacredFormula(target);

    printHeader("Number → Glyphs + Sacred Formula");

    std.debug.print("  {s}Number:{s} {s}{d}{s}\n\n", .{ GRAY, RESET, WHITE, number, RESET });

    // Print glyph decomposition
    std.debug.print("  {s}Coptic Decomposition:{s}\n", .{ CYAN, RESET });
    for (glyphs, 0..) |g, i| {
        if (i > 0) std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        const kingdom = if (g.value >= 100)
            "info"
        else if (g.value >= 10)
            "energy"
        else
            "matter";
        std.debug.print("    {s}{s}{s} = {s}{d}{s}  {s}({s}){s}\n", .{
            GOLDEN, g.glyph[0..g.glyph_len], RESET,
            WHITE,  g.value,                 RESET,
            GRAY,   kingdom,                 RESET,
        });
    }
    std.debug.print("\n  {s}Total:{s} {s}{d}{s}\n", .{ GRAY, RESET, GOLDEN, number, RESET });

    // Print sacred formula fit
    printSacredFit(fit, target);
    printFooter();
}

/// Text mode: sum Coptic glyph values + sacred formula fit
fn runTextMode(allocator: Allocator, text: []const u8) !void {
    const total = gematria_engine.textToGematriaValue(text);
    const glyphs = try gematria_engine.textToGlyphs(allocator, text);
    defer allocator.free(glyphs);

    printHeader("Text → Number + Sacred Formula");

    std.debug.print("  {s}Input:{s} {s}{s}{s}\n\n", .{ GRAY, RESET, WHITE, text, RESET });

    if (glyphs.len == 0) {
        std.debug.print("  {s}No Coptic glyphs found in input{s}\n", .{ RED, RESET });
        printFooter();
        return;
    }

    // Print glyph breakdown
    std.debug.print("  {s}Glyphs:{s}\n", .{ CYAN, RESET });
    for (glyphs, 0..) |g, i| {
        if (i > 0) std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        std.debug.print("    {s}{s}{s} = {s}{d}{s}\n", .{
            GOLDEN, g.glyph[0..g.glyph_len], RESET,
            WHITE,  g.value,                 RESET,
        });
    }
    std.debug.print("\n  {s}Sum:{s} {s}{d}{s}\n", .{ GRAY, RESET, GOLDEN, total, RESET });

    // Sacred formula fit
    if (total > 0) {
        const target: f64 = @floatFromInt(total);
        const fit = sacred_formula.fitSacredFormula(target);
        printSacredFit(fit, target);
    }
    printFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

fn printHeader(title: []const u8) void {
    std.debug.print("\n{s}Coptic Gematria{s} {s}({s}){s}\n", .{ GOLDEN, RESET, GRAY, title, RESET });
    std.debug.print("{s}================================{s}\n\n", .{ GRAY, RESET });
}

fn printSacredFit(fit: sacred_formula.SacredFormulaFit, target: f64) void {
    std.debug.print("\n  {s}Sacred Formula:{s}\n", .{ PURPLE, RESET });
    std.debug.print("  {s}V = n × 3^k × π^m × φ^p × e^q{s}\n\n", .{ GRAY, RESET });

    var formula_buf: [128]u8 = undefined;
    const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);
    std.debug.print("  {s}Best fit:{s} {s}V = {s}{s}\n", .{ GRAY, RESET, GOLDEN, formula_str, RESET });
    std.debug.print("  {s}Computed:{s} {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, fit.computed, RESET });
    std.debug.print("  {s}Target:{s}   {s}{d:.6}{s}\n", .{ GRAY, RESET, WHITE, target, RESET });

    const err_color = if (fit.error_pct < 1.0) GREEN else if (fit.error_pct < 5.0) CYAN else RED;
    std.debug.print("  {s}Error:{s}    {s}{d:.4}%{s}\n", .{ GRAY, RESET, err_color, fit.error_pct, RESET });

    std.debug.print("\n  {s}Parameters:{s} n={s}{d}{s} k={s}{d}{s} m={s}{d}{s} p={s}{d}{s} q={s}{d}{s}\n", .{
        GRAY,  RESET,
        WHITE, fit.n,
        RESET, WHITE,
        fit.k, RESET,
        WHITE, fit.m,
        RESET, WHITE,
        fit.p, RESET,
        WHITE, fit.q,
        RESET,
    });
}

fn printFooter() void {
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printGematriaHelp() void {
    std.debug.print("\n{s}Coptic Gematria + Sacred Formula v3.6{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}====================================={s}\n\n", .{ GRAY, RESET });
    std.debug.print("  {s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("    tri gematria <number>    Decompose number into Coptic glyphs\n", .{});
    std.debug.print("    tri gematria <text>      Sum Coptic glyph values in text\n", .{});
    std.debug.print("    tri math gematria <n>    Same via math subcommand\n", .{});
    std.debug.print("\n  {s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("    tri gematria 137         137 = Ⲥ(100) + Ⲗ(30) + Ⲍ(7)\n", .{});
    std.debug.print("    tri gematria 42          42 = Ⲙ(40) + Ⲃ(2)\n", .{});
    std.debug.print("    tri gematria 999         999 = Ϥ(900) + Ⲣ(90) + Ⲑ(9)\n", .{});
    std.debug.print("\n  {s}27 Coptic Glyphs (3³):{s}\n", .{ CYAN, RESET });
    std.debug.print("    Matter  (1-9):    Ⲁ Ⲃ Ⲅ Ⲇ Ⲉ Ⲋ Ⲍ Ⲏ Ⲑ\n", .{});
    std.debug.print("    Energy  (10-90):  Ⲓ Ⲕ Ⲗ Ⲙ Ⲛ Ⲝ Ⲟ Ⲡ Ⲣ\n", .{});
    std.debug.print("    Info    (100-900):Ⲥ Ⲧ Ⲩ Ⲫ Ⲭ Ⲯ Ⲱ Ϣ Ϥ\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gematria engine integration" {
    // Verify the import works
    const val = gematria_engine.glyphToValue(0x2C80); // Ⲁ = 1
    try std.testing.expectEqual(@as(?u16, 1), val);
}

test "sacred formula integration" {
    const fit = sacred_formula.fitSacredFormula(3.0);
    try std.testing.expectApproxEqAbs(0.0, fit.error_pct, 1e-10);
}

test "number to glyphs with fit" {
    const allocator = std.testing.allocator;
    const glyphs = try gematria_engine.numberToGlyphs(allocator, 137);
    defer allocator.free(glyphs);

    try std.testing.expectEqual(@as(usize, 3), glyphs.len);

    const target: f64 = 137.0;
    const fit = sacred_formula.fitSacredFormula(target);
    try std.testing.expect(fit.error_pct < 10.0);
}
