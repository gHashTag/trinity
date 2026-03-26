// STATISTICAL METRICS — Research Reporting Infrastructure
//
// Provides statistical analysis for experimental results:
// - Confidence intervals (95% CI)
// - t-tests with p-values
// - Effect sizes (Cohen's d)
// - Sample size calculations
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const ConfidenceInterval = struct {
    lower: f64,
    upper: f64,
    level: f64 = 0.95,

    pub fn format(self: ConfidenceInterval, allocator: std.mem.Allocator) ![]const u8 {
        const level_pct = self.level * 100.0;
        return std.fmt.allocPrint(allocator, "{d:.0}% CI: [{d:.2}, {d:.2}]", .{ level_pct, self.lower, self.upper });
    }

    pub fn contains(self: ConfidenceInterval, value: f64) bool {
        return value >= self.lower and value <= self.upper;
    }
};

pub const TTestResult = struct {
    t_statistic: f64,
    p_value: f64,
    df: usize,
    significant: bool,
    alpha: f64 = 0.05,

    pub fn format(self: TTestResult, allocator: std.mem.Allocator) ![]const u8 {
        const sig_str = if (self.significant)
            try std.fmt.allocPrint(allocator, "p < {d:.2}", .{self.alpha})
        else
            try std.fmt.allocPrint(allocator, "p = {d:.4}", .{self.p_value});
        return std.fmt.allocPrint(allocator, "t({d}) = {d:.2}, {s}", .{ self.df, self.t_statistic, sig_str });
    }
};

pub const ExperimentResult = struct {
    mean: f64,
    std_err: f64,
    ci: ConfidenceInterval,
    t_test: ?TTestResult,
    cohens_d: ?f64,
    n: usize,

    pub fn formatSummary(self: ExperimentResult, allocator: std.mem.Allocator) ![]const u8 {
        var result = try std.fmt.allocPrint(allocator, "Value: {d:.2} ± {d:.2} (n={d})\n", .{ self.mean, self.std_err, self.n });

        const ci_str = try self.ci.format(allocator);
        defer allocator.free(ci_str);

        const with_ci = try std.fmt.allocPrint(allocator, "{s}{s}\n", .{ result, ci_str });
        allocator.free(result);
        result = with_ci;

        if (self.t_test) |tt| {
            const tt_str = try tt.format(allocator);
            defer allocator.free(tt_str);

            const with_tt = try std.fmt.allocPrint(allocator, "{s}{s}\n", .{ result, tt_str });
            allocator.free(result);
            result = with_tt;
        }

        if (self.cohens_d) |cd_value| {
            const with_cd = try std.fmt.allocPrint(allocator, "{s}Effect size: d = {d:.2}\n", .{ result, cd_value });
            allocator.free(result);
            result = with_cd;
        }

        return result;
    }
};

/// Calculate mean and standard error
pub fn meanStdErr(values: []const f64) struct { mean: f64, stderr: f64 } {
    if (values.len == 0) return .{ .mean = 0.0, .stderr = 0.0 };

    var sum: f64 = 0.0;
    for (values) |v| sum += v;
    const mean = sum / @as(f64, @floatFromInt(values.len));

    if (values.len == 1) return .{ .mean = mean, .stderr = 0.0 };

    var variance: f64 = 0.0;
    for (values) |v| {
        const diff = v - mean;
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(values.len - 1));
    const stderr = @sqrt(variance / @as(f64, @floatFromInt(values.len)));

    return .{ .mean = mean, .stderr = stderr };
}

/// Calculate 95% confidence interval using t-distribution
pub fn confidenceInterval(mean: f64, stderr: f64, n: usize, level: f64) ConfidenceInterval {
    if (n < 2) return .{
        .lower = mean,
        .upper = mean,
        .level = level,
    };

    // t-critical values (approximate for common confidence levels)
    var t_critical: f64 = 1.960;
    if (@abs(level - 0.90) < 0.001) t_critical = 1.645 else if (@abs(level - 0.95) < 0.001) t_critical = 1.960 else if (@abs(level - 0.99) < 0.001) t_critical = 2.576;

    // Adjust for small sample sizes (simplified)
    const df = @as(f64, @floatFromInt(n - 1));
    const adjustment = if (df < 30) 1.0 + (1.0 / df) else 1.0;
    const margin = t_critical * stderr * adjustment;

    return .{
        .lower = mean - margin,
        .upper = mean + margin,
        .level = level,
    };
}

/// Calculate Cohen's d effect size
pub fn cohensD(mean1: f64, mean2: f64, std1: f64, std2: f64, n1: usize, n2: usize) f64 {
    const fn1: f64 = @floatFromInt(n1);
    const fn2: f64 = @floatFromInt(n2);

    // Pooled standard deviation
    const pooled_var = ((fn1 - 1) * std1 * std1 + (fn2 - 1) * std2 * std2) / (fn1 + fn2 - 2);
    const pooled_std = @sqrt(pooled_var);

    if (pooled_std < 0.0001) return 0.0;
    return (mean1 - mean2) / pooled_std;
}

/// Perform two-sample t-test (independent samples)
pub fn twoSampleTTest(values1: []const f64, values2: []const f64) TTestResult {
    if (values1.len == 0 or values2.len == 0) {
        return .{
            .t_statistic = 0.0,
            .p_value = 1.0,
            .df = 0,
            .significant = false,
        };
    }

    const stats1 = meanStdErr(values1);
    const stats2 = meanStdErr(values2);

    const n1: f64 = @floatFromInt(values1.len);
    const n2: f64 = @floatFromInt(values2.len);

    // Pooled standard deviation
    const var1 = stats1.stderr * stats1.stderr * n1;
    const var2 = stats2.stderr * stats2.stderr * n2;
    const pooled_var = (var1 + var2) / (n1 + n2 - 2);
    const pooled_std = @sqrt(pooled_var);

    if (pooled_std < 0.0001) {
        return .{
            .t_statistic = 0.0,
            .p_value = 1.0,
            .df = values1.len + values2.len - 2,
            .significant = false,
        };
    }

    // t-statistic
    const se_diff = @sqrt(var1 / n1 + var2 / n2);
    const t_statistic = (stats1.mean - stats2.mean) / se_diff;

    // Degrees of freedom (Welch's t-test approximation)
    const df = values1.len + values2.len - 2;

    // P-value approximation using error function
    // For large |t|, p < 0.0001; for small |t|, use approximation
    const abs_t = @abs(t_statistic);
    var p_value: f64 = 0.5;
    if (abs_t > 3.0) {
        p_value = 0.0001;
    } else if (abs_t > 2.58) {
        p_value = 0.01;
    } else if (abs_t > 1.96) {
        p_value = 0.05;
    }

    return .{
        .t_statistic = t_statistic,
        .p_value = p_value,
        .df = df,
        .significant = abs_t > 1.96,
    };
}

/// Create experiment result from raw values
pub fn analyzeExperiment(values: []const f64, compare_values: ?[]const f64) ExperimentResult {
    const stats = meanStdErr(values);
    const ci = confidenceInterval(stats.mean, stats.stderr, values.len, 0.95);

    const t_test = if (compare_values) |cv|
        twoSampleTTest(values, cv)
    else
        null;

    const cohens_d = if (compare_values) |cv|
        cohensD(stats.mean, meanStdErr(cv).mean, stats.stderr, meanStdErr(cv).stderr, values.len, cv.len)
    else
        null;

    return .{
        .mean = stats.mean,
        .std_err = stats.stderr,
        .ci = ci,
        .t_test = t_test,
        .cohens_d = cohens_d,
        .n = values.len,
    };
}

// Tests
test "statistical: mean and std error" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const result = meanStdErr(&values);

    try std.testing.expectApproxEqAbs(3.0, result.mean, 0.01);
    try std.testing.expectApproxEqAbs(0.707, result.stderr, 0.01);
}

test "statistical: confidence interval" {
    const ci = confidenceInterval(100.0, 5.0, 100, 0.95);

    try std.testing.expect(ci.lower < 100.0);
    try std.testing.expect(ci.upper > 100.0);
    // For n=100, margin ≈ 1.98 * 5 ≈ 9.9, width ≈ 19.8
    try std.testing.expectApproxEqAbs(19.8, ci.upper - ci.lower, 1.0);
}

test "statistical: t-test" {
    const group1 = [_]f64{ 10.0, 12.0, 11.0, 13.0, 12.0 };
    const group2 = [_]f64{ 8.0, 9.0, 8.5, 9.5, 9.0 };

    const result = twoSampleTTest(&group1, &group2);

    try std.testing.expect(result.significant);
    try std.testing.expect(result.t_statistic > 0);
}

test "statistical: Cohen's d" {
    const d = cohensD(100.0, 90.0, 15.0, 15.0, 50, 50);

    try std.testing.expect(d > 0.0);
    try std.testing.expect(d < 1.0);
}

test "statistical: analyze experiment" {
    const values = [_]f64{ 85.0, 86.0, 84.0, 87.0, 85.0 };
    const baseline = [_]f64{ 80.0, 81.0, 79.0, 82.0, 80.0 };

    const result = analyzeExperiment(&values, &baseline);

    try std.testing.expectApproxEqAbs(85.4, result.mean, 0.1);
    try std.testing.expect(result.n == 5);
    try std.testing.expect(result.t_test != null);
    try std.testing.expect(result.cohens_d != null);
}

test "statistical: format summary" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const result = analyzeExperiment(&values, null);

    const summary = try result.formatSummary(std.testing.allocator);
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "Value:") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "CI:") != null);
}
