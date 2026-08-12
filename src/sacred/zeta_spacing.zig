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
    ks_statistic: f64, // Kolmogorov-Smirnov statistic D (effect size)
    ks_critical_95: f64, // two-sided 95% critical value, 1.36/sqrt(n)
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
    const d_crit = ksCriticalValue95(spacings.count);

    // Reported as an effect size against the surmise, not as a hypothesis test:
    // the surmise is an approximation to the exact GUE gap law, so at large n
    // D exceeds D_crit for reasons that have nothing to do with the data.
    const verdict = if (ks_stat <= d_crit)
        "D <= D_crit(95%) vs Wigner surmise"
    else if (ks_stat <= 2.0 * d_crit)
        "D within 2x D_crit(95%) vs Wigner surmise (surmise is approximate; not a rejection of GUE)"
    else
        "D > 2x D_crit(95%) vs Wigner surmise (compare against the exact GUE gap law before concluding)";

    return GUEComparison{
        .ks_statistic = ks_stat,
        .ks_critical_95 = d_crit,
        .verdict = verdict,
    };
}

/// erf via Abramowitz & Stegun 7.1.26 (|error| <= 1.5e-7).
/// NOTE: the exp(-a^2) factor is part of the formula -- dropping it is the
/// defect found in tools/uart_echo_test.zig:normalCDFApprox.
fn erfAS(x: f64) f64 {
    const sign: f64 = if (x < 0) -1.0 else 1.0;
    const a = @abs(x);
    const t = 1.0 / (1.0 + 0.3275911 * a);
    const poly = ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t;
    return sign * (1.0 - poly * std.math.exp(-a * a));
}

/// Wigner surmise CDF for the GUE spacing distribution, unit mean spacing.
///
///   p(s) = (32/π²) s² exp(-4s²/π)
///   F(s) = erf(2s/√π) − (4s/π) exp(-4s²/π)      [exact, closed form]
///
/// Previous implementation was `1 − e^{-x}(1+x)`, x = 4s²/π. Differentiating it
/// gives (32/π²) s³ e^{-4s²/π} — an s³ density, not the GUE surmise. It also
/// produced the p95 = 1.93 / 2.15 family of wrong reference values.
/// Verified: dF/ds = p(s), F(∞) = 1, ∫s·p = 1 (see scripts, and the analytic
/// check that the erf coefficient is exactly 1 and the second term exactly 4s/π).
fn wignerCDF(s: f64) f64 {
    if (s <= 0.0) return 0.0;
    const pi = std.math.pi;
    return erfAS(2.0 * s / @sqrt(pi)) - (4.0 * s / pi) * std.math.exp(-4.0 * s * s / pi);
}

/// Two-sided KS critical value at the 95% level, D_crit ≈ 1.36/√n.
///
/// Replaces the former `ksPValue` (p ≈ 2·exp(−2n·D²)). A p-value here is not
/// meaningful: the Wigner surmise is not the exact GUE gap distribution
/// (that is a Fredholm determinant / Painlevé V), so the systematic
/// reference error is fixed while D_crit shrinks as 1/√n — at n = 10⁵ any
/// dataset is rejected by construction. Report D as an effect size instead.
fn ksCriticalValue95(n: usize) f64 {
    const n_f = @as(f64, @floatFromInt(n));
    return 1.36 / @sqrt(n_f);
}

test "wignerCDF: derivative reproduces the surmise pdf" {
    const h = 1e-6;
    for ([_]f64{ 0.1, 0.5, 1.0, 1.7518, 3.0 }) |s| {
        const pdf = (32.0 / (std.math.pi * std.math.pi)) * s * s * std.math.exp(-4.0 * s * s / std.math.pi);
        const d = (wignerCDF(s + h) - wignerCDF(s - h)) / (2.0 * h);
        try std.testing.expect(@abs(d - pdf) < 1e-5);
    }
}

test "wignerCDF: normalised, and is GUE rather than GOE" {
    try std.testing.expect(@abs(wignerCDF(12.0) - 1.0) < 1e-6);
    // GUE(0.3) = 0.027254; GOE(0.3) = 1 - exp(-π·0.09/4) = 0.068245.
    // The two curves cross near s = 1 (0.5331 vs 0.5441), so a guard placed
    // at s = 1 would pass even if the functions were swapped.
    try std.testing.expect(@abs(wignerCDF(0.3) - 0.027254) < 1e-4);
    try std.testing.expect(@abs(wignerCDF(1.7518) - 0.95) < 1e-4);
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

    const verdict_color = if (gue_result.ks_statistic <= gue_result.ks_critical_95) "\x1b[32m" else "\x1b[33m";
    std.debug.print("  KS statistic: {d:.6}  (effect size, not a test)\n", .{gue_result.ks_statistic});
    std.debug.print("  D_crit(95%): {d:.6}\n", .{gue_result.ks_critical_95});
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
