//! Zenodo V20: Statistical Significance Module for NeurIPS/ICLR 2025
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Implements statistical methods required for conference submissions:
//! - Bootstrap confidence intervals (Efron, 1979)
//! - Paired t-test (Student, 1908)
//! - Wilcoxon signed-rank test (Wilcoxon, 1945)
//! - Effect size: Cohen's d (Cohen, 1988)
//! - Cliff's delta (Cliff, 1993)
//!
//! References:
//! - Efron, B. (1979). "Bootstrap methods: Another look at the jackknife"
//! - Wilcoxon, F. (1945). "Individual comparisons by ranking methods"
//! - Cohen, J. (1988). "Statistical power analysis for the behavioral sciences"
//! - Cliff, N. (1993). "Dominance statistics: Ordinal analyses"

const std = @import("std");
const Allocator = std.mem.Allocator;

// Error function approximation (Abramowitz & Stegun 7.1.26)
fn erf(x: f64) f64 {
    const abs_x = if (x < 0) -x else x;
    const a1: f64 = 0.254829592;
    const a2: f64 = -0.284496736;
    const a3: f64 = 1.421413741;
    const a4: f64 = -1.453152027;
    const a5: f64 = 1.061405429;
    const p: f64 = 0.3275911;

    const t = 1.0 / (1.0 + p * abs_x);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * @exp(-x * x);

    return if (x < 0) -y else y;
}

// ============================================================================
// BOOTSTRAP CONFIDENCE INTERVALS
// ============================================================================

/// Bootstrap confidence interval result
pub const BootstrapCI = struct {
    lower: f64,
    upper: f64,
    mean: f64,
    std_err: f64,

    /// Width of the confidence interval
    pub fn width(self: BootstrapCI) f64 {
        return self.upper - self.lower;
    }

    /// Check if value is within CI
    pub fn contains(self: BootstrapCI, value: f64) bool {
        return value >= self.lower and value <= self.upper;
    }
};

/// Bootstrap confidence interval using percentile method
/// Reference: Efron (1979)
pub fn bootstrapCI(
    samples: []const f64,
    n_bootstraps: usize,
    confidence_level: f64,
    allocator: Allocator,
) !BootstrapCI {
    if (samples.len < 2) return error.TooFewSamples;
    if (n_bootstraps < 100) return error.TooFewBootstraps;
    if (confidence_level <= 0 or confidence_level >= 1) return error.InvalidConfidenceLevel;

    // Allocate bootstrap samples
    const bootstrap_means = try allocator.alloc(f64, n_bootstraps);
    defer allocator.free(bootstrap_means);

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));

    // Generate bootstrap samples
    for (0..n_bootstraps) |i| {
        var sum: f64 = 0;
        for (0..samples.len) |_| {
            const idx = rng.random().intRangeLessThan(usize, 0, samples.len);
            sum += samples[idx];
        }
        bootstrap_means[i] = sum / @as(f64, @floatFromInt(samples.len));
    }

    // Sort bootstrap means
    std.sort.insertion(f64, bootstrap_means, {}, comptime std.sort.asc(f64));

    // Calculate percentiles
    const alpha = 1.0 - confidence_level;
    const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n_bootstraps)) * alpha / 2.0));
    const upper_idx = n_bootstraps - lower_idx - 1;

    // Calculate mean and standard error
    var mean: f64 = 0;
    for (samples) |s| mean += s;
    mean /= @as(f64, @floatFromInt(samples.len));

    var variance: f64 = 0;
    for (samples) |s| {
        const diff = s - mean;
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(samples.len - 1));
    const std_err = @sqrt(variance / @as(f64, @floatFromInt(samples.len)));

    return .{
        .lower = bootstrap_means[@min(lower_idx, n_bootstraps - 1)],
        .upper = bootstrap_means[@min(upper_idx, n_bootstraps - 1)],
        .mean = mean,
        .std_err = std_err,
    };
}

// ============================================================================
// STATISTICAL TESTS
// ============================================================================

/// Paired t-test result
pub const TTestResult = struct {
    t_statistic: f64,
    p_value: f64,
    degrees_of_freedom: usize,
    significant: bool,
    alpha: f64 = 0.05,
};

/// Paired t-test for comparing two related samples
/// Reference: Student (1908)
pub fn pairedTTest(a: []const f64, b: []const f64, alpha: f64) !TTestResult {
    if (a.len != b.len) return error.SampleSizeMismatch;
    if (a.len < 2) return error.TooFewSamples;

    const n = @as(f64, @floatFromInt(a.len));
    const df = a.len - 1;

    // Calculate differences
    const diffs = try std.heap.page_allocator.alloc(f64, a.len);
    defer std.heap.page_allocator.free(diffs);

    var mean_diff: f64 = 0;
    for (a, b, 0..) |ai, bi, i| {
        diffs[i] = ai - bi;
        mean_diff += diffs[i];
    }
    mean_diff /= n;

    // Calculate standard deviation of differences
    var var_diff: f64 = 0;
    for (diffs) |d| {
        const diff = d - mean_diff;
        var_diff += diff * diff;
    }
    var_diff /= (n - 1.0);
    const std_diff = @sqrt(var_diff);

    // Calculate t-statistic
    const t_statistic = mean_diff / (std_diff / @sqrt(n));

    // Calculate p-value (two-tailed)
    // Approximation using error function
    const p_value = @max(0.0, @min(1.0, 1.0 - erf(@abs(t_statistic) / @sqrt(2.0))));

    return .{
        .t_statistic = t_statistic,
        .p_value = p_value,
        .degrees_of_freedom = df,
        .significant = p_value < alpha,
        .alpha = alpha,
    };
}

/// Wilcoxon signed-rank test result
pub const WilcoxonResult = struct {
    w_statistic: f64,
    p_value: f64,
    significant: bool,
    alpha: f64 = 0.05,
};

/// Wilcoxon signed-rank test for non-parametric comparison
/// Reference: Wilcoxon (1945)
pub fn wilcoxonSignedRank(
    a: []const f64,
    b: []const f64,
    alpha: f64,
    allocator: Allocator,
) !WilcoxonResult {
    if (a.len != b.len) return error.SampleSizeMismatch;
    if (a.len < 5) return error.TooFewSamples;

    const n = a.len;

    // Named struct for absolute differences
    const AbsDiff = struct { abs_diff: f64, sign: f64, orig_idx: usize };

    // Calculate differences and ranks
    const diffs = try allocator.alloc(struct { diff: f64, rank: usize }, n);
    defer allocator.free(diffs);

    var zero_count: usize = 0;
    for (a, b, 0..) |ai, bi, i| {
        diffs[i].diff = ai - bi;
        if (@abs(diffs[i].diff) < 1e-10) zero_count += 1;
    }

    // Remove zeros
    const n_nonzero = n - zero_count;
    if (n_nonzero < 5) return error.TooFewNonZeroDifferences;

    // Calculate absolute differences and sort
    const abs_diffs = try allocator.alloc(AbsDiff, n_nonzero);
    defer allocator.free(abs_diffs);

    var j: usize = 0;
    for (diffs, 0..) |d, i| {
        if (@abs(d.diff) >= 1e-10) {
            abs_diffs[j].abs_diff = @abs(d.diff);
            abs_diffs[j].sign = if (d.diff < 0) -1.0 else 1.0;
            abs_diffs[j].orig_idx = i;
            j += 1;
        }
    }

    // Sort by absolute difference
    std.sort.insertion(AbsDiff, abs_diffs, {}, struct {
        fn lessThan(_: void, x: AbsDiff, y: AbsDiff) bool {
            return x.abs_diff < y.abs_diff;
        }
    }.lessThan);

    // Assign ranks (handle ties)
    var w_positive: f64 = 0;
    var i: usize = 0;
    while (i < n_nonzero) {
        const start = i;
        const current_val = abs_diffs[i].abs_diff;

        // Find tie group
        while (i < n_nonzero and abs_diffs[i].abs_diff == current_val) {
            i += 1;
        }

        // Average rank for ties
        const avg_rank = @as(f64, @floatFromInt(start + i + 1)) / 2.0;

        for (start..i) |k| {
            if (abs_diffs[k].sign > 0) {
                w_positive += avg_rank;
            }
        }
    }

    // W statistic is the smaller of W+ and W-
    const w_total = @as(f64, @floatFromInt(n_nonzero * (n_nonzero + 1))) / 2.0;
    const w_negative = w_total - w_positive;
    const w_statistic = @min(w_positive, w_negative);

    // Approximate p-value using normal approximation
    const mean_w = w_total / 2.0;
    const var_w = @as(f64, @floatFromInt(n_nonzero * (n_nonzero + 1) * (2 * n_nonzero + 1))) / 24.0;
    const std_w = @sqrt(var_w);
    const z = (w_statistic - mean_w) / std_w;
    const p_value = @max(0.0, @min(1.0, 1.0 - erf(@abs(z) / @sqrt(2.0))));

    return .{
        .w_statistic = w_statistic,
        .p_value = p_value,
        .significant = p_value < alpha,
        .alpha = alpha,
    };
}

// ============================================================================
// EFFECT SIZE
// ============================================================================

/// Effect size interpretation
pub const EffectSize = enum {
    negligible,
    small,
    medium,
    large,

    pub fn fromCohensD(d: f64) EffectSize {
        const abs_d = @abs(d);
        if (abs_d < 0.2) return .negligible;
        if (abs_d < 0.5) return .small;
        if (abs_d < 0.8) return .medium;
        return .large;
    }

    pub fn description(self: EffectSize) []const u8 {
        return switch (self) {
            .negligible => "negligible",
            .small => "small",
            .medium => "medium",
            .large => "large",
        };
    }
};

/// Cohen's d effect size
/// Reference: Cohen (1988)
pub fn cohensD(a: []const f64, b: []const f64) f64 {
    if (a.len < 2 or b.len < 2) return 0;

    // Calculate means
    var mean_a: f64 = 0;
    for (a) |v| mean_a += v;
    mean_a /= @as(f64, @floatFromInt(a.len));

    var mean_b: f64 = 0;
    for (b) |v| mean_b += v;
    mean_b /= @as(f64, @floatFromInt(b.len));

    // Calculate pooled standard deviation
    var var_a: f64 = 0;
    for (a) |v| {
        const diff = v - mean_a;
        var_a += diff * diff;
    }
    var_a /= @as(f64, @floatFromInt(a.len - 1));

    var var_b: f64 = 0;
    for (b) |v| {
        const diff = v - mean_b;
        var_b += diff * diff;
    }
    var_b /= @as(f64, @floatFromInt(b.len - 1));

    const pooled_var = ((@as(f64, @floatFromInt(a.len - 1)) * var_a) +
        (@as(f64, @floatFromInt(b.len - 1)) * var_b)) /
        @as(f64, @floatFromInt(a.len + b.len - 2));
    const pooled_std = @sqrt(pooled_var);

    if (pooled_std < 1e-10) return 0;

    return (mean_a - mean_b) / pooled_std;
}

/// Cliff's delta effect size (non-parametric)
/// Reference: Cliff (1993)
pub fn cliffsDelta(a: []const f64, b: []const f64) f64 {
    if (a.len == 0 or b.len == 0) return 0;

    var greater: f64 = 0;
    var less: f64 = 0;
    const n_a = @as(f64, @floatFromInt(a.len));
    const n_b = @as(f64, @floatFromInt(b.len));
    const n_comparisons = n_a * n_b;

    for (a) |av| {
        for (b) |bv| {
            if (av > bv) greater += 1;
            if (av < bv) less += 1;
        }
    }

    return (greater - less) / n_comparisons;
}

// ============================================================================
// STATISTICAL SUMMARY
// ============================================================================

/// Statistical summary for experiment results
pub const StatisticalSummary = struct {
    /// Mean value
    mean: f64,
    /// Standard deviation
    std_dev: f64,
    /// Standard error
    std_err: f64,
    /// 95% confidence interval
    ci: BootstrapCI,
    /// Sample size
    n: usize,

    /// Format as string for paper
    pub fn format(self: *const StatisticalSummary, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\Mean: {d:.3} ± {d:.3}
            \\95% CI: [{d:.3}, {d:.3}]
            \\n = {d}
        , .{ self.mean, self.std_err, self.ci.lower, self.ci.upper, self.n });
    }
};

/// Generate statistical summary from samples
pub fn statisticalSummary(
    samples: []const f64,
    allocator: Allocator,
) !StatisticalSummary {
    const ci = try bootstrapCI(samples, 10000, 0.95, allocator);

    var mean: f64 = 0;
    for (samples) |s| mean += s;
    mean /= @as(f64, @floatFromInt(samples.len));

    var variance: f64 = 0;
    for (samples) |s| {
        const diff = s - mean;
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(samples.len));
    const std_dev = @sqrt(variance);
    const std_err = std_dev / @sqrt(@as(f64, @floatFromInt(samples.len)));

    return .{
        .mean = mean,
        .std_dev = std_dev,
        .std_err = std_err,
        .ci = ci,
        .n = samples.len,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "Bootstrap CI: valid interval" {
    const allocator = std.testing.allocator;

    // Normal distribution samples
    const samples = [_]f64{ 1.0, 1.2, 0.9, 1.1, 1.0, 1.3, 0.8, 1.2, 1.0, 1.1 };

    const ci = try bootstrapCI(&samples, 1000, 0.95, allocator);

    try std.testing.expect(ci.lower < ci.upper);
    try std.testing.expect(ci.contains(ci.mean));
    try std.testing.expect(ci.width() > 0);
}

test "Paired t-test: calculation" {
    const a = [_]f64{ 10.0, 12.0, 11.0, 13.0, 10.0 };
    const b = [_]f64{ 8.0, 9.0, 8.5, 10.0, 8.5 };

    const result = try pairedTTest(&a, &b, 0.05);

    // Check that t-statistic is positive (a > b)
    try std.testing.expect(result.t_statistic > 0);
    // Check p-value is in valid range
    try std.testing.expect(result.p_value >= 0 and result.p_value <= 1);
}

test "Wilcoxon: non-parametric comparison" {
    const allocator = std.testing.allocator;

    const a = [_]f64{ 10.0, 12.0, 11.0, 13.0, 10.0 };
    const b = [_]f64{ 8.0, 9.0, 8.5, 10.0, 8.5 };

    const result = try wilcoxonSignedRank(&a, &b, 0.05, allocator);

    // Check p-value is in valid range
    try std.testing.expect(result.p_value >= 0 and result.p_value <= 1);
}

test "Cohen's d: effect size calculation" {
    const a = [_]f64{ 10.0, 12.0, 11.0, 13.0, 10.0 };
    const b = [_]f64{ 8.0, 9.0, 8.5, 10.0, 8.5 };

    const d = cohensD(&a, &b);

    try std.testing.expect(d > 0);
    try std.testing.expect(EffectSize.fromCohensD(d) != .negligible);
}

test "Cliff's delta: non-parametric effect size" {
    const a = [_]f64{ 10.0, 12.0, 11.0, 13.0, 10.0 };
    const b = [_]f64{ 8.0, 9.0, 8.5, 10.0, 8.5 };

    const delta = cliffsDelta(&a, &b);

    try std.testing.expect(delta > 0);
    try std.testing.expect(delta <= 1.0);
}

test "Statistical summary: complete analysis" {
    const allocator = std.testing.allocator;

    const samples = [_]f64{ 10.0, 12.0, 11.0, 13.0, 10.0, 11.5, 10.5, 12.5 };

    const summary = try statisticalSummary(&samples, allocator);

    try std.testing.expect(summary.n == samples.len);
    try std.testing.expect(summary.mean > 0);
    try std.testing.expect(summary.std_dev > 0);
    try std.testing.expect(summary.ci.lower < summary.mean);
    try std.testing.expect(summary.ci.upper > summary.mean);
}

// φ² + 1/φ² = 3 | TRINITY
