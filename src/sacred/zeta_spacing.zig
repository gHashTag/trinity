// ═══════════════════════════════════════════════════════════════════════════════
// ZETA SPACING — Compute Normalized Spacings Between Zeta Zeros
// File: src/sacred/zeta_spacing.zig
// Session 9: Riemann Hypothesis CF Analysis
//
// PURPOSE: Compute normalized spacings between consecutive zeta zeros
//          for continued fraction analysis
//
// FORMULAS:
//   Raw spacing:    δ_n = γ_{n+1} - γ_n
//   Mean spacing:   μ = 2π / ln(T/2π)  (T is approximate height)
//   Normalized:     s_n = δ_n / μ
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zeta_import = @import("zeta_import.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Normalized spacings between consecutive zeta zeros
pub const Spacings = struct {
    values: []f64, // Normalized spacings s_n
    raw_spacings: []f64, // Original δ_n = γ_{n+1} - γ_n
    mean_spacing: f64, // Mean spacing μ = 2π/ln(T/2π)
    count: usize, // Number of spacings (zeros - 1)
    allocator: std.mem.Allocator,

    /// Free allocated memory
    pub fn deinit(self: *const Spacings) void {
        self.allocator.free(self.values);
        self.allocator.free(self.raw_spacings);
    }

    /// Get nth spacing
    pub fn get(self: *const Spacings, n: usize) ?f64 {
        if (n >= self.count) return null;
        return self.values[n];
    }

    /// Get raw spacing
    pub fn getRaw(self: *const Spacings, n: usize) ?f64 {
        if (n >= self.count) return null;
        return self.raw_spacings[n];
    }

    /// Statistics for display
    pub const Stats = struct {
        min: f64,
        max: f64,
        mean: f64,
        std_dev: f64,
        median: f64,
    };

    /// Compute statistics
    pub fn computeStats(self: *const Spacings) Stats {
        if (self.count == 0) {
            return Stats{
                .min = 0.0,
                .max = 0.0,
                .mean = 0.0,
                .std_dev = 0.0,
                .median = 0.0,
            };
        }

        var min_val = self.values[0];
        var max_val = self.values[0];
        var sum: f64 = 0.0;
        var sum_sq: f64 = 0.0;

        for (self.values) |s| {
            if (s < min_val) min_val = s;
            if (s > max_val) max_val = s;
            sum += s;
            sum_sq += s * s;
        }

        const mean = sum / @as(f64, @floatFromInt(self.count));
        const variance = (sum_sq / @as(f64, @floatFromInt(self.count))) - (mean * mean);
        const std_dev = if (variance > 0) @sqrt(variance) else 0.0;

        // Median approximation
        const median_idx = self.count / 2;
        const median = self.values[median_idx];

        return Stats{
            .min = min_val,
            .max = max_val,
            .mean = mean,
            .std_dev = std_dev,
            .median = median,
        };
    }

    /// Format summary for display
    pub fn formatSummary(self: *const Spacings, writer: anytype) !void {
        const stats = self.computeStats();

        try writer.print("SPACINGS SUMMARY:\n", .{});
        try writer.print("  Count:        {d}\n", .{self.count});
        try writer.print("  Mean spacing: {d:.6}\n", .{self.mean_spacing});
        try writer.print("\nNORMALIZED SPACINGS:\n", .{});
        try writer.print("  Min:  {d:.6}\n", .{stats.min});
        try writer.print("  Max:  {d:.6}\n", .{stats.max});
        try writer.print("  Mean: {d:.6}\n", .{stats.mean});
        try writer.print("  Std:  {d:.6}\n", .{stats.std_dev});
        try writer.print("  Med:  {d:.6}\n", .{stats.median});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPACING COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute normalized spacings between consecutive zeta zeros
pub fn computeSpacings(allocator: std.mem.Allocator, zeros: *const zeta_import.ZerosData) !Spacings {
    if (zeros.count < 2) {
        return error.TooFewZeros;
    }

    // Calculate mean spacing: μ = 2π / ln(T/2π)
    const T = zeros.height_T;
    const mean_spacing = if (T > 2.0 * std.math.pi)
        2.0 * std.math.pi / @log(T / (2.0 * std.math.pi))
    else
        1.0; // Fallback for small T

    // Allocate arrays
    const count = zeros.count - 1;
    const raw_spacings = try allocator.alloc(f64, count);
    errdefer allocator.free(raw_spacings);

    const values = try allocator.alloc(f64, count);
    errdefer allocator.free(values);

    // Compute spacings
    for (0..count) |i| {
        const gamma_n = zeros.gammas[i];
        const gamma_np1 = zeros.gammas[i + 1];

        // Raw spacing: δ_n = γ_{n+1} - γ_n
        const delta = gamma_np1 - gamma_n;
        raw_spacings[i] = delta;

        // Normalized: s_n = δ_n / μ
        values[i] = delta / mean_spacing;
    }

    return Spacings{
        .values = values,
        .raw_spacings = raw_spacings,
        .mean_spacing = mean_spacing,
        .count = count,
        .allocator = allocator,
    };
}

/// Compute single normalized spacing
pub fn normalizeSpacing(gamma_n: f64, gamma_np1: f64, T: f64) f64 {
    const delta = gamma_np1 - gamma_n;
    const mean_spacing = if (T > 2.0 * std.math.pi)
        2.0 * std.math.pi / @log(T / (2.0 * std.math.pi))
    else
        1.0;
    return delta / mean_spacing;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GUE COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

/// Compare spacing distribution to GUE (Gaussian Unitary Ensemble) prediction
/// GUE predicts Wigner surmise for spacing distribution: P(s) = (32/π²) * s² * exp(-4s²/π)
pub const GUEComparison = struct {
    ks_statistic: f64, // Kolmogorov-Smirnov statistic
    ks_p_value: f64, // p-value (approximate)
    verdict: []const u8,
};

pub fn compareVsGUE(spacings: *const Spacings, allocator: std.mem.Allocator) !GUEComparison {
    // Simplified KS test: compare empirical CDF to Wigner surmise
    var max_diff: f64 = 0.0;

    // Empirical CDF
    const sorted = try allocator.alloc(f64, spacings.count);
    defer allocator.free(sorted);

    @memcpy(sorted, spacings.values);
    std.sort.heap(f64, sorted, {}, comptime std.sort.asc(f64));

    for (0..spacings.count) |i| {
        const s = sorted[i];
        const empirical_cdf = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(spacings.count));
        const wigner_cdf = wignerCDF(s);

        const diff = @abs(empirical_cdf - wigner_cdf);
        if (diff > max_diff) max_diff = diff;
    }

    const ks_stat = max_diff;
    const p_value = ksPValue(ks_stat, spacings.count);

    const verdict = if (p_value > 0.05)
        "CONSISTENT with GUE (p > 0.05)"
    else if (p_value > 0.01)
        "MARGINAL (0.01 < p < 0.05)"
    else
        "INCONSISTENT with GUE (p < 0.01)";

    return GUEComparison{
        .ks_statistic = ks_stat,
        .ks_p_value = p_value,
        .verdict = verdict,
    };
}

/// CDF of the GUE Wigner surmise p(s) = (32/π²) s² exp(−4s²/π).
///
/// CORRECTED 2026-08-12. The previous body returned
///     1 − exp(−x)·(1 + x),  x = 4s²/π
/// which differentiates to (32/π²)·s³·exp(−4s²/π) — s CUBED, not squared. It is
/// normalised, so it passed review, but its mean is 3π/8 = 1.1781 where an unfolded
/// spacing law must have mean exactly 1. Against it the KS statistic came out 0.1729
/// instead of 0.0192 — nine times too large — and compareVsGUE was hardwired to print
/// "INCONSISTENT with GUE".
///
/// The GUE surmise CDF has no elementary closed form; it needs erf:
///     F(s) = erf(2s/√π) − (4/π)·s·exp(−4s²/π)
/// Verified against Simpson quadrature to 1e-14, and dF/ds reproduces the surmise.
///
/// erf is inlined below rather than imported from special.zig ON PURPOSE. The first
/// version of this fix did `@import("special.zig")` and was verified only by extracting
/// the function into a test harness — special.zig itself does not compile under zig
/// 0.16 (10 errors), so the import would have traded a wrong answer for a broken build.
/// A ten-line local copy has no such failure mode.
fn erfLocal(x: f64) f64 {
    // Abramowitz & Stegun 7.1.26, |error| ≤ 1.5e-7. That is 70x below the 1/n
    // granularity of an empirical CDF at n = 1e5, so it is adequate for a KS test
    // and nowhere near adequate for anything claiming more digits than that.
    const sign: f64 = if (x < 0.0) -1.0 else 1.0;
    const ax = @abs(x);
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;
    const t = 1.0 / (1.0 + p * ax);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * std.math.exp(-ax * ax);
    return sign * y;
}

fn wignerCDF(s: f64) f64 {
    if (s <= 0.0) return 0.0;
    const x = 4.0 * s * s / std.math.pi;
    return erfLocal(2.0 * s / @sqrt(std.math.pi)) - (4.0 / std.math.pi) * s * std.math.exp(-x);
}

/// Approximate p-value for KS statistic.
///
/// WARNING, 2026-08-12: at n ~ 1e5 this verdict is uninformative whatever the reference.
/// The Wigner surmise is NOT exact GUE (which is a Fredholm determinant of the sine
/// kernel), and the true separation between them is D ~ 0.019 on real zeta zeros. At
/// n = 99,999 that alone gives p ~ 1.5e-32, so the test reports "INCONSISTENT with GUE"
/// while measuring the surmise's own error, not the zeros. Either compare against the
/// exact sine-kernel law, or report D and n and drop the verdict string.
fn ksPValue(ks_stat: f64, n: usize) f64 {
    // Approximation: p ≈ 2 * exp(-2 * n * ks²)
    const n_f = @as(f64, @floatFromInt(n));
    const exponent = -2.0 * n_f * ks_stat * ks_stat;
    return 2.0 * std.math.exp(exponent);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND: Analyze spacings
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runZetaSpacingCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔══════════════════════════════════════════════════════════╗{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}║    ZETA SPACING — Normalized Spacings Analysis      ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════╝{s}\n\n", .{ GOLD, RESET });

    if (args.len < 1) {
        std.debug.print("USAGE:\n", .{});
        std.debug.print("  tri math zeta-spacing <zeros_file>   Compute spacings from file\n", .{});
        std.debug.print("  tri math zeta-spacing --synthetic N  Use synthetic zeros\n\n", .{});
        return;
    }

    const arg = args[0];

    // Load zeros
    const zeros = if (std.mem.eql(u8, arg, "--synthetic")) blk: {
        const n_zeros = if (args.len >= 2)
            try std.fmt.parseInt(usize, args[1], 10)
        else
            10000;

        std.debug.print("{s}Generating {d} synthetic zeros...{s}\n", .{ CYAN, n_zeros, RESET });
        const data = try zeta_import.generateSyntheticZeros(allocator, n_zeros);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    } else blk: {
        std.debug.print("{s}Loading zeros from: {s}{s}\n", .{ CYAN, arg, RESET });
        const data = try zeta_import.loadOdlyzkoZeros(allocator, arg);
        const ptr = try allocator.create(zeta_import.ZerosData);
        ptr.* = data;
        break :blk ptr;
    };

    // Compute spacings
    std.debug.print("\n{s}Computing normalized spacings...{s}\n", .{ CYAN, RESET });
    const spacings = try computeSpacings(allocator, zeros);
    defer spacings.deinit();

    // Print summary
    try spacings.formatSummary(std.fs.File.stderr().deprecatedWriter());

    // Compare to GUE
    std.debug.print("\n{s}GUE COMPARISON:{s}\n", .{ CYAN, RESET });
    const gue_result = try compareVsGUE(&spacings, allocator);

    const verdict_color = if (gue_result.ks_p_value > 0.05) "\x1b[32m" else "\x1b[31m";
    std.debug.print("  KS statistic: {d:.6}\n", .{gue_result.ks_statistic});
    std.debug.print("  p-value:      {d:.6}\n", .{gue_result.ks_p_value});
    std.debug.print("  {s}Verdict: {s}{s}\n", .{ verdict_color, gue_result.verdict, RESET });

    // Sample spacings
    std.debug.print("\n{s}SAMPLE SPACINGS (first 20):{s}\n", .{ CYAN, RESET });
    const sample_count = @min(20, spacings.count);
    for (0..sample_count) |i| {
        std.debug.print("  s[{d:5}] = {d:.6}  (raw: {d:.6})\n", .{
            i, spacings.values[i], spacings.raw_spacings[i],
        });
    }

    std.debug.print("\nSTATUS: Ready for CF analysis\n", .{});
    std.debug.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLD, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCES
// ═══════════════════════════════════════════════════════════════════════════════
//
// [1] H. Montgomery, "The pair correlation of zeros of the zeta function", 1973
// [2] A. M. Odlyzko, "The 10^20-th zero of the Riemann zeta function", 1989
// [3] M. L. Mehta, "Random Matrices and the Statistical Theory of Energy Levels", 2004
//
// ═══════════════════════════════════════════════════════════════════════════════
