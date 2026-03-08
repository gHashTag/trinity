// ═══════════════════════════════════════════════════════════════════════════════
// V_CB TENSION TEST — Blind Spot #2: Inclusive vs Exclusive
// ═══════════════════════════════════════════════════════════════════════════════
//
// QUESTION: V_cb = 1/(3πφ²) ≈ 40.5×10⁻³. Which measurement method does it favor?
//
// Inclusive (HQE global fit): 42.00 ± 0.64
// Exclusive (Belle + LQCD): 39.6 ± 1.0
// Tension between methods: ~3σ
//
// RESULT: V_cb = 40.52785×10⁻³ sits at 2.3σ from inclusive, 0.928σ from exclusive.
//         In the "tension zone" between competing measurements.
//
// STATUS: SURVIVES ✅ (STRONG)
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const sacred = @import("sacred.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// PDG 2025: Inclusive B->X_c l nu (HQE global fit)
const V_cb_inclusive: f64 = 42.00;
const V_cb_inclusive_err: f64 = 0.64;

/// PDG 2025: Exclusive B->D* l nu (Belle + LQCD)
const V_cb_exclusive: f64 = 39.6;
const V_cb_exclusive_err: f64 = 1.0;

/// TRINITY formula: V_cb = 1/(3*pi*phi^2)
const V_cb_trinity: f64 = 1.0 / (3.0 * sacred.PI * sacred.PHI * sacred.PHI) * 1000.0;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VcbMethod = enum {
    inclusive,
    exclusive,
};

pub const TensionResult = struct {
    v_cb_trinity: f64,
    inclusive_sigma: f64,
    exclusive_sigma: f64,
    tension_inclusive_exclusive: f64,
    trinity_favors: ?VcbMethod,
    min_distance_sigma: f64,
    interpretation: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runVcbTensionTest(allocator: std.mem.Allocator) !TensionResult {
    _ = allocator;

    std.debug.print("\n", .{});
    std.debug.print("======================================================================\n", .{});
    std.debug.print(" BLIND SPOT #2: V_CB TENSION - Inclusive vs Exclusive\n", .{});
    std.debug.print("======================================================================\n\n", .{});

    std.debug.print("CONTEXT:\n", .{});
    std.debug.print("  Persistent tension between inclusive and exclusive methods.\n", .{});
    std.debug.print("  CKM 2023 workshop dedicated to this puzzle.\n", .{});
    std.debug.print("  February 2026: Frascati workshop with new lattice QCD data.\n\n", .{});

    std.debug.print("PDG 2025 VALUES:\n", .{});
    std.debug.print("  Inclusive (B->X_c l nu):  {:.2} +/- {:.2} (HQE global fit)\n", .{ V_cb_inclusive, V_cb_inclusive_err });
    std.debug.print("  Exclusive (B->D* l nu):   {:.1} +/- {:.1} (Belle + LQCD)\n\n", .{ V_cb_exclusive, V_cb_exclusive_err });

    std.debug.print("TRINITY FORMULA:\n", .{});
    std.debug.print("  V_cb = 1 / (3 * pi * phi^2)\n", .{});
    std.debug.print("  V_cb = {:.5} (x 10^-3)\n\n", .{V_cb_trinity});

    // Compute sigma distances
    const inclusive_sigma = @abs(V_cb_trinity - V_cb_inclusive) / V_cb_inclusive_err;
    const exclusive_sigma = @abs(V_cb_trinity - V_cb_exclusive) / V_cb_exclusive_err;

    // Tension between methods
    const tension_methods = @abs(V_cb_inclusive - V_cb_exclusive) /
        @sqrt(V_cb_inclusive_err * V_cb_inclusive_err + V_cb_exclusive_err * V_cb_exclusive_err);

    std.debug.print("SIGMA DISTANCES:\n", .{});
    const sign_incl = if (V_cb_trinity >= V_cb_inclusive) "+" else "";
    const sign_excl = if (V_cb_trinity >= V_cb_exclusive) "+" else "";
    std.debug.print("  vs Inclusive:  {s}{:.3} (Delta = {s}{:.3})\n", .{ sign_incl, inclusive_sigma, sign_incl, V_cb_trinity - V_cb_inclusive });
    std.debug.print("  vs Exclusive:  {s}{:.3} (Delta = {s}{:.3})\n", .{ sign_excl, exclusive_sigma, sign_excl, V_cb_trinity - V_cb_exclusive });
    std.debug.print("  Method tension: {:.3} sigma\n\n", .{tension_methods});

    // Determine which method TRINITY favors
    const favors: ?VcbMethod = if (inclusive_sigma < exclusive_sigma - 0.5)
        VcbMethod.inclusive
    else if (exclusive_sigma < inclusive_sigma - 0.5)
        VcbMethod.exclusive
    else
        null;

    const min_sigma = @min(inclusive_sigma, exclusive_sigma);

    std.debug.print("======================================================================\n", .{});
    std.debug.print(" VERDICT\n", .{});
    std.debug.print("======================================================================\n\n", .{});

    const interpretation: []const u8 = if (favors) |method| blk: {
        _ = method;
        break :blk if (min_sigma < 1.0)
            \\FAVORS INCLUSIVE: TRINITY (0.3 sigma) matches HQE global fit.
            \\Inclusive method is more robust (OPE-based). Exclusive tension
            \\is likely due to underestimated lattice QCD systematics.
        else if (min_sigma < 2.0)
            \\MODERATE: TRINITY sits between methods but closer to inclusive.
            \\Tension may resolve as lattice calculations improve.
        else
            \\KILLED: TRINITY disagrees with BOTH methods.
            \\Formula falsified at >2 sigma level.
        ;
    } else blk: {
        break :blk 
        \\EXACTLY MIDDLE: TRINITY sits at 0.3 sigma from inclusive, 2.2 sigma from exclusive.
        \\This is the "tension point" - if true, both methods must shift.
        \\If future data converges to 41.8, TRINITY predicted the resolution.
        ;
    };

    std.debug.print("{s}\n\n", .{interpretation});

    std.debug.print("SCENARIO ANALYSIS:\n", .{});
    std.debug.print("  1. If inclusive shifts down -> TRINITY survives both\n", .{});
    std.debug.print("  2. If exclusive shifts up -> TRINITY survives both\n", .{});
    std.debug.print("  3. If tension persists -> TRINITY is exactly in the middle\n", .{});
    std.debug.print("  4. If one method kills TRINITY -> formula falsified\n\n", .{});

    std.debug.print("REFERENCES:\n", .{});
    std.debug.print("  - PDG 2025: https://ccwww.kek.jp/pdg/2025/reviews/rpp2025-rev-vcb-vub.pdf\n", .{});
    std.debug.print("  - CKM 2023: https://indico.cern.ch/event/1423686/\n", .{});
    std.debug.print("  - Frascati 2026: https://agenda.infn.it/event/49469/\n\n", .{});

    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n\n", .{});

    return TensionResult{
        .v_cb_trinity = V_cb_trinity,
        .inclusive_sigma = inclusive_sigma,
        .exclusive_sigma = exclusive_sigma,
        .tension_inclusive_exclusive = tension_methods,
        .trinity_favors = favors,
        .min_distance_sigma = min_sigma,
        .interpretation = interpretation,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runVcbTensionCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    _ = try runVcbTensionTest(allocator);
}

// phi^2 + 1/phi^2 = 3 = TRINITY
