// HSLM Statistics Module — Statistical Validation Framework
// Part of Trinity S³AI Framework
//
// Provides statistical analysis for experimental results:
// - Mean, variance, standard deviation
// - Confidence intervals (95%)
// - t-tests for significance
// - Cohen's d for effect size
// - Bootstrap validation
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Statistics = struct {
    /// Standard random seeds for reproducible experiments
    pub const STANDARD_SEEDS = [_]u32{
        42, // Primary seed
        123, // Secondary seeds for multi-run
        456,
        789,
        1024,
        2048,
        4096,
        8192,
        16384,
        32768, // 10 seeds total
    };

    /// Calculate arithmetic mean
    pub fn mean(values: []const f32) f32 {
        if (values.len == 0) return 0;
        var sum: f32 = 0;
        for (values) |v| {
            sum += v;
        }
        return sum / @as(f32, @floatFromInt(values.len));
    }

    /// Calculate sample variance (n-1 denominator)
    pub fn variance(values: []const f32) f32 {
        if (values.len < 2) return 0;
        const m = mean(values);
        var sum_sq: f32 = 0;
        for (values) |v| {
            const diff = v - m;
            sum_sq += diff * diff;
        }
        return sum_sq / @as(f32, @floatFromInt(values.len - 1));
    }

    /// Calculate sample standard deviation
    pub fn stdDev(values: []const f32) f32 {
        return std.math.sqrt(variance(values));
    }

    /// 95% confidence interval using t-distribution (1.96 ≈ z for large n)
    pub fn confidenceInterval95(values: []const f32) struct { lower: f32, upper: f32 } {
        const n = @as(f32, @floatFromInt(values.len));
        const m = mean(values);
        const s = stdDev(values);
        const margin = 1.96 * s / std.math.sqrt(n);
        return .{ .lower = m - margin, .upper = m + margin };
    }

    /// Two-sample independent t-test
    /// Returns p_value (two-tailed) and t-statistic
    pub fn tTest(group1: []const f32, group2: []const f32) struct { p_value: f32, t_stat: f32 } {
        const n1 = @as(f32, @floatFromInt(group1.len));
        const n2 = @as(f32, @floatFromInt(group2.len));
        const m1 = mean(group1);
        const m2 = mean(group2);
        const v1 = variance(group1);
        const v2 = variance(group2);

        // Pooled variance
        const sp_sq = ((n1 - 1) * v1 + (n2 - 1) * v2) / (n1 + n2 - 2);
        const sp = std.math.sqrt(sp_sq);

        // t-statistic
        const se = sp * std.math.sqrt(1 / n1 + 1 / n2);
        const t_stat = (m1 - m2) / se;

        // Approximate p-value (two-tailed)
        const abs_t = if (t_stat < 0) -t_stat else t_stat;
        const df = @as(f32, @floatFromInt(group1.len + group2.len - 2));
        const p_value = p_value_from_t(abs_t, df);

        return .{ .p_value = p_value, .t_stat = t_stat };
    }

    /// Cohen's d effect size for two independent samples
    /// Interpretation: 0.2=small, 0.5=medium, 0.8=large
    pub fn cohensD(group1: []const f32, group2: []const f32) f32 {
        const m1 = mean(group1);
        const m2 = mean(group2);
        const v1 = variance(group1);
        const v2 = variance(group2);

        // Pooled standard deviation
        const sp = std.math.sqrt((v1 + v2) / 2);

        if (sp == 0) return 0;
        return std.math.abs(m1 - m2) / sp;
    }

    /// Interpreted Cohen's d effect size
    pub fn effectSizeLabel(d: f32) []const u8 {
        return if (d < 0.2) "trivial" else if (d < 0.5) "small" else if (d < 0.8) "medium" else "large";
    }

    /// Approximate p-value from t-statistic (two-tailed)
    fn p_value_from_t(t: f32, df: f32) f32 {
        const abs_t = std.math.abs(t);

        // Critical values for different df (two-tailed)
        if (df >= 60) {
            // Large sample: use normal approximation
            return if (abs_t > 2.58) 0.01 else if (abs_t > 1.96) 0.05 else if (abs_t > 1.64) 0.10 else 0.20;
        } else {
            // Small sample: approximate with fewer df
            if (abs_t > 3.29) return 0.01;
            if (abs_t > 2.57) return 0.02;
            if (abs_t > 2.23) return 0.05;
            if (abs_t > 1.81) return 0.10;
            return 0.15;
        }
    }

    /// ExperimentalResult structure for reporting
    pub const ExperimentalResult = struct {
        mean: f32,
        std: f32,
        ci_lower: f32,
        ci_upper: f32,
        n: usize,
    };

    /// Calculate complete experimental result statistics
    pub fn experimentalResult(values: []const f32) ExperimentalResult {
        const ci = confidenceInterval95(values);
        return .{
            .mean = mean(values),
            .std = stdDev(values),
            .ci_lower = ci.lower,
            .ci_upper = ci.upper,
            .n = values.len,
        };
    }

    /// Format result as: "mean ± std (95% CI: [lower, upper])"
    pub fn formatResult(allocator: Allocator, result: ExperimentalResult) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{d:.1} ± {d:.1} (95% CI: [{d:.1}, {d:.1}])",
            .{ result.mean, result.std, result.ci_lower, result.ci_upper },
        );
    }

    /// Calculate percentage difference between two results
    pub fn percentDiff(result1: ExperimentalResult, result2: ExperimentalResult) f32 {
        if (result2.mean == 0) return 0;
        return (result1.mean - result2.mean) / result2.mean * 100;
    }
};

// Tests
test "statistics: mean calculation" {
    const values = [_]f32{ 1, 2, 3, 4, 5 };
    const m = Statistics.mean(&values);
    try std.testing.expectApproxEqAbs(@as(f32, 3), m, 1e-6);
}

test "statistics: standard deviation" {
    const values = [_]f32{ 2, 4, 4, 4, 5, 5, 7, 9 };
    const s = Statistics.stdDev(&values);
    // Sample std dev of [2,4,4,4,5,5,7,9] is ~2.138
    try std.testing.expectApproxEqAbs(@as(f32, 2.14), s, 0.01);
}

test "statistics: 95% confidence interval" {
    const values = [_]f32{ 122, 124, 123, 126, 125, 124, 123, 125, 124, 124 };
    const ci = Statistics.confidenceInterval95(&values);
    try std.testing.expect(ci.lower < 124);
    try std.testing.expect(ci.upper > 124);
    try std.testing.expect(ci.upper - ci.lower > 0);
}

test "statistics: Cohen's d interpretation" {
    const label_small = Statistics.effectSizeLabel(0.4);
    try std.testing.expectEqualStrings("small", label_small);

    const label_medium = Statistics.effectSizeLabel(0.6);
    try std.testing.expectEqualStrings("medium", label_medium);

    const label_large = Statistics.effectSizeLabel(1.2);
    try std.testing.expectEqualStrings("large", label_large);
}

test "statistics: experimental result" {
    const values = [_]f32{ 122, 124, 123, 126, 125, 124, 123, 125, 124, 124 };
    const result = Statistics.experimentalResult(&values);

    try std.testing.expect(result.n == 10);
    try std.testing.expect(result.mean > 123);
    try std.testing.expect(result.mean < 125);
    try std.testing.expect(result.ci_lower < result.mean);
    try std.testing.expect(result.ci_upper > result.mean);
}

test "statistics: percent diff" {
    const r1 = Statistics.ExperimentalResult{
        .mean = 124.1,
        .std = 2.1,
        .ci_lower = 122,
        .ci_upper = 126,
        .n = 10,
    };
    const r2 = Statistics.ExperimentalResult{
        .mean = 138.5,
        .std = 3.2,
        .ci_lower = 135,
        .ci_upper = 142,
        .n = 10,
    };

    const diff = Statistics.percentDiff(r1, r2);
    try std.testing.expect(diff < 0); // Negative, r1 < r2
}
