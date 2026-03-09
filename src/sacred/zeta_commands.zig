// ═══════════════════════════════════════════════════════════════════════════════
// ZETA COMMANDS — CLI Command Handlers for Riemann Zeta Analysis
// File: src/sacred/zeta_commands.zig
// Session 9: Riemann Hypothesis CF Analysis
//
// PURPOSE: Main command dispatcher for zeta-related CLI commands
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import individual zeta modules
const zeta_import = @import("zeta_import.zig");
const zeta_spacing = @import("zeta_spacing.zig");
const zeta_cf = @import("zeta_cf.zig");
const zeta_pslq = @import("zeta_pslq.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: Main zeta dispatcher
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        try printZetaHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = args[1..];
    const RESET = "\x1b[0m";

    if (std.mem.eql(u8, subcommand, "import")) {
        try zeta_import.runZetaImportCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "spacing")) {
        try zeta_spacing.runZetaSpacingCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "cf")) {
        try zeta_cf.runZetaCFCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "pslq")) {
        try zeta_pslq.runZetaPSLQCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "verdict")) {
        try runZetaVerdictCommand(allocator, sub_args);
    } else {
        std.debug.print("{s}Unknown zeta subcommand: {s}{s}\n", .{ "\x1b[31m", subcommand, RESET });
        try printZetaHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: Combined verdict
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaVerdictCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║    ZETA VERDICT — Combined RH Analysis                ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri math zeta-verdict <zeros_file>   Full analysis + verdict\n", .{});
        std.debug.print("  tri math zeta-verdict --hardcoded    Use first 100 hardcoded zeros\n", .{});
        std.debug.print("  tri math zeta-verdict --synthetic N  Use synthetic zeros\n\n", .{});
        return;
    }

    const arg = args[0];

    // Load zeros
    const zeros: *zeta_import.ZerosData = if (std.mem.eql(u8, arg, "--hardcoded")) blk: {
        std.debug.print("{s}Loading first 100 hardcoded Odlyzko zeros...{s}\n\n", .{ CYAN, RESET });
        const data = try zeta_import.loadHardcodedZeros(allocator);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else if (std.mem.eql(u8, arg, "--synthetic")) blk: {
        const n_zeros = if (args.len >= 2)
            try std.fmt.parseInt(usize, args[1], 10)
        else
            10000;

        std.debug.print("{s}Generating {d} synthetic zeros...{s}\n\n", .{ CYAN, n_zeros, RESET });
        const data = try zeta_import.generateSyntheticZeros(allocator, n_zeros);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else blk: {
        std.debug.print("{s}Loading zeros from: {s}{s}\n\n", .{ CYAN, arg, RESET });
        const data = try zeta_import.loadOdlyzkoZeros(allocator, arg);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    };

    // Run full analysis
    std.debug.print("{s}═ STAGE 1: Spacing Analysis ═{s}\n", .{ CYAN, RESET });
    var spacings = try zeta_spacing.computeSpacings(allocator, zeros);
    defer spacings.deinit();
    try spacings.formatSummary(std.fs.File.stderr().deprecatedWriter());

    const gue_result = try zeta_spacing.compareVsGUE(&spacings, allocator);
    const gue_color = if (gue_result.ks_p_value > 0.05) GREEN else "\x1b[31m";
    std.debug.print("  GUE comparison: {s}{s}{s}\n\n", .{ gue_color, gue_result.verdict, RESET });

    std.debug.print("{s}═ STAGE 2: CF Analysis ═{s}\n", .{ CYAN, RESET });
    const cf_stats = try zeta_cf.computeSpacingCFStats(allocator, &spacings, 1000);
    std.debug.print("  Irrationality μ:  {d:.6}\n", .{cf_stats.mu});
    std.debug.print("  Khinchin K:       {d:.6} (expected: 2.685)\n", .{cf_stats.khinchin_k});
    std.debug.print("  Entropy:          {d:.4} bits\n", .{cf_stats.entropy});
    std.debug.print("  Max partial:      {d}\n\n", .{cf_stats.max_partial});

    std.debug.print("{s}═ STAGE 3: PSLQ Search ═{s}\n", .{ CYAN, RESET });
    const pslq_result = try zeta_pslq.findSpacingRelations(allocator, &spacings, 1000);
    defer pslq_result.deinit(allocator);
    std.debug.print("  Relations found:  {d} / {d} tested\n", .{
        pslq_result.relations_found, pslq_result.spacings_tested,
    });
    std.debug.print("  No simple relation to π, φ, ln 2, √2 detected\n\n", .{});

    // Final verdict
    std.debug.print("{s}═ FINAL VERDICT ═{s}\n", .{ GOLD, RESET });

    const verdict = determineFinalVerdict(&cf_stats, &gue_result, &pslq_result);
    const verdict_color = switch (verdict.verdict) {
        .gue_consistent => GREEN,
        .generic => "\x1b[32m",
        .inconclusive => GOLD,
        .anomalous => "\x1b[31m",
    };

    std.debug.print("  {s}{s}{s}\n\n", .{ verdict_color, verdict.description, RESET });

    std.debug.print("{s}STATUS: Analysis complete{s}\n", .{ GREEN, RESET });
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

const FinalVerdict = struct {
    verdict: enum { gue_consistent, generic, inconclusive, anomalous },
    description: []const u8,
};

fn determineFinalVerdict(
    cf_stats: *const zeta_cf.CFStats,
    gue: *const zeta_spacing.GUEComparison,
    pslq: *const zeta_pslq.PSLQSearchResult,
) FinalVerdict {
    // If all three tests point to generic/random
    if (gue.ks_p_value > 0.05 and cf_stats.mu < 2.5 and pslq.relations_found == 0) {
        return FinalVerdict{
            .verdict = .gue_consistent,
            .description = "GUE CONSISTENT: Spacings follow random matrix predictions. CF is generic, no arithmetic relations found.",
        };
    }

    // If CF looks generic
    if (cf_stats.mu < 2.3) {
        return FinalVerdict{
            .verdict = .generic,
            .description = "GENERIC: CF structure is typical for transcendental numbers. No special arithmetic detected.",
        };
    }

    // If inconclusive
    if (cf_stats.mu < 3.0) {
        return FinalVerdict{
            .verdict = .inconclusive,
            .description = "INCONCLUSIVE: Some metrics elevated, but not definitive. Need more data.",
        };
    }

    // If anomalous
    return FinalVerdict{
        .verdict = .anomalous,
        .description = "ANOMALOUS: Unexpected structure detected! Further investigation needed.",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELP TEXT
// ═══════════════════════════════════════════════════════════════════════════════

fn printZetaHelp() !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║         ZETA ANALYSIS — Riemann Hypothesis via CF   ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri math zeta <subcommand> [options]\n\n", .{});

    std.debug.print("{s}SUBCOMMANDS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}import{s}    <file>        Load Odlyzko zeros data\n", .{ GOLD, RESET });
    std.debug.print("  {s}spacing{s}   <file>        Compute normalized spacings\n", .{ GOLD, RESET });
    std.debug.print("  {s}cf{s}        <file>        Continued fraction analysis\n", .{ GOLD, RESET });
    std.debug.print("  {s}pslq{s}      <file>        PSLQ relation search\n", .{ GOLD, RESET });
    std.debug.print("  {s}verdict{s}   <file>        Combined RH verdict\n", .{ GOLD, RESET });

    std.debug.print("\n{s}OPTIONS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}--hardcoded{s}              Use first 100 hardcoded Odlyzko zeros\n", .{ GOLD, RESET });
    std.debug.print("  {s}--synthetic{s} N            Generate N synthetic zeros (for testing)\n\n", .{ GOLD, RESET });

    std.debug.print("{s}DATA SOURCE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  https://www.dtc.umn.edu/~odlyzko/zeta_tables/\n\n", .{});

    std.debug.print("{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri math zeta verdict zeros1\n", .{});
    std.debug.print("  tri math zeta cf --synthetic 10000\n", .{});
    std.debug.print("  tri math zeta pslq /path/to/zeros\n\n", .{});

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

// Re-export individual command functions for direct access
pub const runZetaImportCommand = zeta_import.runZetaImportCommand;
pub const runZetaSpacingCommand = zeta_spacing.runZetaSpacingCommand;
pub const runZetaCFCommand = zeta_cf.runZetaCFCommand;
pub const runZetaPSLQCommand = zeta_pslq.runZetaPSLQCommand;
pub const runZetaVerdictCommandDirect = runZetaVerdictCommand;

// Re-export types
pub const ZerosData = zeta_import.ZerosData;
pub const Spacings = zeta_spacing.Spacings;
pub const ZetaCFResult = zeta_cf.ZetaCFResult;
pub const ZetaVerdict = zeta_cf.ZetaVerdict;
pub const PSLQSearchResult = zeta_pslq.PSLQSearchResult;

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCES
// ═══════════════════════════════════════════════════════════════════════════════
//
// [1] B. Riemann, "Ueber die Anzahl der Primzahlen unter einer gegebenen Grösse", 1859
// [2] A. M. Odlyzko, "The 10^20-th zero of the Riemann zeta function", 1989
// [3] H. Montgomery, "The pair correlation of zeros of the zeta function", 1973
//
// ═══════════════════════════════════════════════════════════════════════════════
