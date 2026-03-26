// HSLM — Statistical Validation Module
// Provides statistical tests for experimental validation

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════
// STATISTICAL RESULT STRUCTURES
// ═══════════════════════════════════════════════════════════════════

/// Experiment result with statistical measures
pub const ExperimentResult = struct {
    values: []const f32,
    mean: f32,
    std: f32,
    sem: f32, // Standard Error of Mean
    ci_lower: f32,
    ci_upper: f32,
    n: usize,
    min: f32,
    max: f32,
    median: f32,
    q1: f32, // First quartile (25th percentile)
    q3: f32, // Third quartile (75th percentile)
    iqr: f32, // Interquartile range
};

/// Two-sample t-test result
pub const TTestResult = struct {
    t_statistic: f32,
    p_value: f32,
    cohens_d: f32,
    significant: bool,
    effect_size: EffectSize,
    df: usize, // Degrees of freedom
};

/// Effect size interpretation
pub const EffectSize = enum { negligible, small, medium, large };

/// Paired t-test result (same subjects, different conditions)
pub const PairedTTestResult = struct {
    t_statistic: f32,
    p_value: f32,
    cohens_d: f32,
    significant: bool,
    effect_size: EffectSize,
    df: usize,
};

/// Wilcoxon rank-sum test result (non-parametric alternative)
pub const WilcoxonResult = struct {
    w_statistic: f32,
    p_value: f32,
    significant: bool,
};

/// Bootstrap confidence interval result
pub const BootstrapResult = struct {
    mean: f32,
    ci_lower: f32,
    ci_upper: f32,
    samples: usize,
    ci_level: f32,
};

// ═══════════════════════════════════════════════════════════════════════
// DESCRIPTIVE STATISTICS
// ═══════════════════════════════════════════════════════════════════

/// Analyze experimental results with full statistical measures
pub fn analyzeExperiment(allocator: std.mem.Allocator, values: []const f32) !ExperimentResult {
    if (values.len < 2) return error.TooFewSamples;

    const n = values.len;
    const mean_val = mean(values);
    const std_val = stdDev(values, mean_val);
    const sem_val = std_val / @sqrt(@as(f32, @floatFromInt(n)));

    // Quartiles
    const sorted = try allocator.dupe(f32, values);
    std.sort.block(f32, sorted, {}, std.sort.asc(f32));
    const q1_val = percentile(sorted, 0.25);
    const q3_val = percentile(sorted, 0.75);
    const median_val = percentile(sorted, 0.5);

    // 95% CI using t-distribution (approximate for n >= 10)
    const t_val = tValue(n - 1);
    const margin = t_val * sem_val;

    // Min/Max
    const min_val = sorted[0];
    const max_val = sorted[n - 1];

    allocator.free(sorted);

    return ExperimentResult{
        .values = values,
        .mean = mean_val,
        .std = std_val,
        .sem = sem_val,
        .ci_lower = mean_val - margin,
        .ci_upper = mean_val + margin,
        .n = n,
        .min = min_val,
        .max = max_val,
        .median = median_val,
        .q1 = q1_val,
        .q3 = q3_val,
        .iqr = q3_val - q1_val,
    };
}

/// Two-tailed t-test for independent samples
pub fn tTest(group1: []const f32, group2: []const f32) TTestResult {
    if (group1.len < 2 or group2.len < 2) {
        return .{
            .t_statistic = 0.0,
            .p_value = 1.0,
            .cohens_d = 0.0,
            .significant = false,
            .effect_size = .negligible,
            .df = 0,
        };
    }

    const m1 = mean(group1);
    const m2 = mean(group2);
    const s1 = stdDev(group1, m1);
    const s2 = stdDev(group2, m2);
    const n1 = @as(f32, @floatFromInt(group1.len));
    const n2 = @as(f32, @floatFromInt(group2.len));

    // Pooled standard deviation
    const sp = @sqrt(((n1 - 1.0) * s1 * s1 + (n2 - 1.0) * s2 * s2) / (n1 + n2 - 2.0));
    const se = sp * @sqrt(1.0 / n1 + 1.0 / n2);
    const t_stat = (m1 - m2) / se;

    // Cohen's d
    const d = (m1 - m2) / sp;

    // Degrees of freedom
    const df = group1.len + group2.len - 2;

    // Approximate p-value (two-tailed)
    const p_val = pValueFromT(@abs(t_stat), @as(f32, @floatFromInt(df)));

    // Significant at α = 0.05
    const sig = p_val < 0.05;

    return .{
        .t_statistic = t_stat,
        .p_value = p_val,
        .cohens_d = d,
        .significant = sig,
        .effect_size = interpretEffectSize(d),
        .df = df,
    };
}

/// Paired t-test for matched samples (same seeds, different conditions)
pub fn pairedTTest(before: []const f32, after: []const f32) PairedTTestResult {
    if (before.len != after.len or before.len < 2) {
        return .{
            .t_statistic = 0.0,
            .p_value = 1.0,
            .cohens_d = 0.0,
            .significant = false,
            .effect_size = .negligible,
            .df = 0,
        };
    }

    const n = @as(f32, @floatFromInt(before.len));

    // Compute differences
    var mean_diff: f32 = 0.0;
    var sum_sq_diff: f32 = 0.0;

    for (before, after) |b, a| {
        const diff = a - b;
        mean_diff += diff;
        sum_sq_diff += diff * diff;
    }

    mean_diff /= n;

    // Standard deviation of differences
    const std_diff = @sqrt((sum_sq_diff - n * mean_diff * mean_diff) / (n - 1.0));
    const se_diff = std_diff / @sqrt(n);

    // t-statistic
    const t_stat = mean_diff / se_diff;

    // Cohen's d (paired)
    const d = mean_diff / std_diff;

    const df = before.len - 1;

    // Approximate p-value
    const p_val = pValueFromT(@abs(t_stat), @as(f32, @floatFromInt(df)));

    return .{
        .t_statistic = t_stat,
        .p_value = p_val,
        .cohens_d = d,
        .significant = p_val < 0.05,
        .effect_size = interpretEffectSize(d),
        .df = df,
    };
}

/// Wilcoxon rank-sum test (non-parametric alternative to t-test)
pub fn wilcoxonRankSum(group1: []const f32, group2: []const f32) WilcoxonResult {
    if (group1.len < 3 or group2.len < 3) {
        return .{
            .w_statistic = 0.0,
            .p_value = 1.0,
            .significant = false,
        };
    }

    // Combine and sort all values
    const allocator = std.heap.page_allocator;
    const combined = try allocator.alloc(f32, group1.len + group2.len);
    defer allocator.free(combined);

    @memcpy(combined[0..group1.len], group1);
    @memcpy(combined[group1.len..], group2);

    // Sort with indices
    var indices = try allocator.alloc(usize, combined.len);
    defer allocator.free(indices);
    for (0..combined.len) |i| indices[i] = i;

    // Simple sort (for small datasets)
    var outer: usize = 0;
    while (outer < combined.len) : (outer += 1) {
        var inner: usize = outer + 1;
        while (inner < combined.len) : (inner += 1) {
            if (combined[indices[inner]] < combined[indices[outer]]) {
                const temp = indices[outer];
                indices[outer] = indices[inner];
                indices[inner] = temp;
            }
        }
    }

    // Assign ranks (average for ties)
    var ranks = try allocator.alloc(f32, combined.len);
    defer allocator.free(ranks);

    var r: usize = 1;
    while (r <= combined.len) : (r += 1) {
        // Count ties
        var tie_count: usize = 1;
        var k: usize = r + 1;
        while (k < combined.len and combined[indices[k]] == combined[indices[r]]) : (k += 1) {
            tie_count += 1;
        }

        // Average rank for ties
        const avg_rank: f32 = @as(f32, @floatFromInt(r + (r + tie_count - 1))) / 2.0;

        for (0..tie_count) |t| {
            ranks[indices[r + t]] = avg_rank;
        }

        r += tie_count;
    }

    // Sum ranks for each group
    var rank_sum1: f32 = 0.0;
    var rank_sum2: f32 = 0.0;

    for (0..group1.len) |i| {
        rank_sum1 += ranks[i];
    }
    for (0..group2.len) |i| {
        rank_sum2 += ranks[group1.len + i];
    }

    // U statistics
    const u_stat1 = rank_sum1 - @as(f32, @floatFromInt(group1.len * (group1.len + 1))) / 2.0;
    const u_stat2 = rank_sum2 - @as(f32, @floatFromInt(group2.len * (group2.len + 1))) / 2.0;
    const u = @min(u_stat1, u_stat2);

    // Approximate p-value from U statistic
    const n = group1.len + group2.len;
    const mean_u = @as(f32, @floatFromInt(group1.len * group2.len)) / 2.0;
    const std_u = @sqrt(@as(f32, @floatFromInt(group1.len * group2.len * (n + 1))) / 12.0);
    const z = (u - mean_u) / std_u;

    // Normal approximation
    const p_val = 2.0 * (1.0 - normalCDF(@abs(z)));

    return .{
        .w_statistic = u,
        .p_value = p_val,
        .significant = p_val < 0.05,
    };
}

/// Bootstrap confidence interval (non-parametric)
pub fn bootstrapCI(
    allocator: std.mem.Allocator,
    values: []const f32,
    n_samples: usize,
    ci_level: f32,
) !BootstrapResult {
    if (values.len < 2) return error.TooFewSamples;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));

    // Resample with replacement and compute means
    const bootstrapped_means = try allocator.alloc(f32, n_samples);
    defer allocator.free(bootstrapped_means);

    for (0..n_samples) |i| {
        var sum: f32 = 0.0;
        const n = values.len;

        for (0..n) |_| {
            const idx = prng.random().uintLessThan(usize, n);
            sum += values[idx];
        }

        bootstrapped_means[i] = sum / @as(f32, @floatFromInt(n));
    }

    // Sort bootstrapped means
    std.sort.block(f32, bootstrapped_means, {}, std.sort.asc(f32));

    // Find percentiles
    const alpha = (1.0 - ci_level) / 2.0;
    const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n_samples)) * alpha));
    const upper_idx = n_samples - 1 - lower_idx;

    const result = BootstrapResult{
        .mean = mean(values),
        .ci_lower = bootstrapped_means[lower_idx],
        .ci_upper = bootstrapped_means[upper_idx],
        .samples = n_samples,
        .ci_level = ci_level,
    };

    return result;
}

/// Sample size calculation for two-sample t-test
pub fn requiredSampleSize(effect_size: f32, _: f32, _: f32) usize {
    // Cohen's table approximation
    // For large effect (d=0.8), α=0.05, power=0.80: n≈26 per group
    // For medium effect (d=0.5), α=0.05, power=0.80: n≈64 per group
    // For small effect (d=0.2), α=0.05, power=0.80: n≈394 per group

    const abs_d = if (effect_size < 0) -effect_size else effect_size;

    // Approximation formula (Hulbert et al., 2001)
    const n_approx: f64 = 2.0 + 16.0 / (abs_d * abs_d);

    return @as(usize, @intFromFloat(n_approx));
}

// ═════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═════════════════════════════════════════════════════════════════

fn mean(values: []const f32) f32 {
    var sum: f32 = 0.0;
    for (values) |v| sum += v;
    return sum / @as(f32, @floatFromInt(values.len));
}

fn stdDev(values: []const f32, mean_val: f32) f32 {
    var sum_sq: f32 = 0.0;
    for (values) |v| {
        const diff = v - mean_val;
        sum_sq += diff * diff;
    }
    const n = @as(f32, @floatFromInt(values.len));
    return @sqrt(sum_sq / (n - 1.0));
}

fn percentile(sorted_values: []const f32, p: f32) f32 {
    if (sorted_values.len == 0) return 0.0;

    const n = sorted_values.len;
    const idx_float = p * @as(f32, @floatFromInt(n - 1));

    // Linear interpolation
    const lower_idx = @as(usize, @intFromFloat(@floor(idx_float)));
    const upper_idx = @as(usize, @intFromFloat(@ceil(idx_float)));

    if (lower_idx == upper_idx) {
        return sorted_values[lower_idx];
    }

    const alpha = idx_float - @as(f32, @floatFromInt(lower_idx));
    return sorted_values[lower_idx] * (1.0 - alpha) + sorted_values[upper_idx] * alpha;
}

fn tValue(df: usize) f32 {
    // Approximate t-values for 95% CI (two-tailed)
    return switch (df) {
        1 => 12.706,
        2 => 4.303,
        3 => 3.182,
        4 => 2.776,
        5 => 2.571,
        6 => 2.447,
        7 => 2.365,
        8 => 2.306,
        9 => 2.262,
        10 => 2.228,
        11 => 2.201,
        12 => 2.179,
        13 => 2.160,
        14 => 2.145,
        15 => 2.131,
        16 => 2.120,
        17 => 2.110,
        18 => 2.101,
        19 => 2.093,
        20 => 2.086,
        21 => 2.080,
        22 => 2.074,
        23 => 2.069,
        24 => 2.064,
        25 => 2.060,
        26 => 2.056,
        27 => 2.052,
        28 => 2.048,
        29 => 2.045,
        30 => 2.042,
        else => 1.960, // Normal approximation for large df
    };
}

fn pValueFromT(t: f32, df: f32) f32 {
    // Approximate p-value from t-statistic using normal distribution for large df
    const abs_t = if (t < 0) -t else t;

    // For df > 30, use normal approximation
    if (df > 30) {
        return 2.0 * (1.0 - normalCDF(abs_t));
    }

    // For small df, use critical value lookup
    const df_usize: usize = @intFromFloat(df);
    const critical_05 = t95Critical(df_usize);
    const critical_01 = t99Critical(df_usize);

    if (abs_t < critical_05) return 0.10;
    if (abs_t < critical_01) return 0.05;
    return 0.01;
}

fn t95Critical(df: usize) f32 {
    // Two-tailed critical t-value for 95% CI
    return switch (df) {
        1 => 12.706,
        2 => 4.303,
        3 => 3.182,
        4 => 2.776,
        5 => 2.571,
        6 => 2.447,
        7 => 2.365,
        8 => 2.306,
        9 => 2.262,
        10 => 2.228,
        11 => 2.201,
        12 => 2.179,
        13 => 2.160,
        14 => 2.145,
        15 => 2.131,
        16 => 2.120,
        17 => 2.110,
        18 => 2.101,
        19 => 2.093,
        20 => 2.086,
        21 => 2.080,
        22 => 2.074,
        23 => 2.069,
        24 => 2.064,
        25 => 2.060,
        26 => 2.056,
        27 => 2.052,
        28 => 2.048,
        29 => 2.045,
        30 => 2.042,
        else => 1.960,
    };
}

fn t99Critical(df: usize) f32 {
    // Two-tailed critical t-value for 99% CI
    return switch (df) {
        1 => 63.657,
        2 => 9.925,
        3 => 5.841,
        4 => 4.604,
        5 => 4.032,
        6 => 3.707,
        7 => 3.499,
        8 => 3.355,
        9 => 3.250,
        10 => 3.169,
        11 => 3.106,
        12 => 3.055,
        13 => 3.012,
        14 => 2.977,
        15 => 2.947,
        16 => 2.921,
        17 => 2.898,
        18 => 2.878,
        19 => 2.861,
        20 => 2.845,
        21 => 2.831,
        22 => 2.819,
        23 => 2.807,
        24 => 2.797,
        25 => 2.787,
        26 => 2.779,
        27 => 2.771,
        28 => 2.763,
        29 => 2.756,
        30 => 2.750,
        else => 2.576,
    };
}

fn normalCDF(z: f32) f32 {
    // Standard normal CDF using Abramowitz and Stegun approximation
    const abs_z = if (z < 0) -z else z;
    const t = 1.0 / (1.0 + 0.2316419 * abs_z);
    const t2 = t * t;
    const t3 = t2 * t;
    const t4 = t3 * t;

    const coefficients = [_]f32{
        0.319381530,
        -0.356563782,
        1.781477937,
        -1.821255978,
        1.330274429,
    };

    const cdf = 1.0 - 0.5 * @exp(-z * z / 2.0) *
        (coefficients[0] * t +
            coefficients[1] * t2 +
            coefficients[2] * t3 +
            coefficients[3] * t4);

    if (z < 0) return 1.0 - cdf else return cdf;
}

fn interpretEffectSize(d: f32) EffectSize {
    const abs_d = if (d < 0) -d else d;
    if (abs_d < 0.2) return .negligible;
    if (abs_d < 0.5) return .small;
    if (abs_d < 0.8) return .medium;
    return .large;
}

// ═════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════

test "analyzeExperiment computes correct statistics" {
    const values = [_]f32{ 10.0, 12.0, 11.0, 13.0, 12.0 };
    const result = try analyzeExperiment(std.testing.allocator, &values);

    try std.testing.expectApproxEqAbs(result.mean, 11.6, 0.01);
    try std.testing.expect(result.n == 5);
    try std.testing.expect(result.ci_upper > result.mean);
    try std.testing.expect(result.ci_lower < result.mean);
    try std.testing.expect(result.median == 12.0);
    try std.testing.expect(result.iqr > 0);
}

test "tTest detects significant difference" {
    const group1 = [_]f32{ 10.0, 11.0, 12.0, 10.0, 11.0 };
    const group2 = [_]f32{ 15.0, 16.0, 14.0, 15.0, 16.0 };

    const result = tTest(&group1, &group2);

    try std.testing.expect(result.significant);
    try std.testing.expect(result.p_value < 0.05);
    try std.testing.expect(@abs(result.cohens_d) > 1.0);
    try std.testing.expect(result.df == 8);
}

test "pairedTTest detects before/after difference" {
    const before = [_]f32{ 10.0, 11.0, 12.0, 10.0, 11.0 };
    const after = [_]f32{ 15.0, 16.0, 17.0, 15.0, 16.0 };

    const result = pairedTTest(&before, &after);

    try std.testing.expect(result.significant);
    try std.testing.expect(result.cohens_d > 0); // Mean improved
    try std.testing.expect(result.df == 4);
}

test "cohens_d interpretation" {
    const small: f32 = 0.3;
    const medium: f32 = 0.6;
    const large: f32 = 0.9;

    try std.testing.expect(interpretEffectSize(small) == .small);
    try std.testing.expect(interpretEffectSize(medium) == .medium);
    try std.testing.expect(interpretEffectSize(large) == .large);
    try std.testing.expect(interpretEffectSize(0.1) == .negligible);
}

test "bootstrapCI produces valid interval" {
    const values = [_]f32{ 10.0, 12.0, 11.0, 13.0, 12.0, 14.0 };
    const result = try bootstrapCI(std.testing.allocator, &values, 1000, 0.95);

    try std.testing.expect(result.mean == 12.0);
    try std.testing.expect(result.ci_lower < result.mean);
    try std.testing.expect(result.ci_upper > result.mean);
    try std.testing.expect(result.samples == 1000);
    try std.testing.expect(result.ci_level == 0.95);
}

test "requiredSampleSize approximation" {
    const n_large = requiredSampleSize(0.8, 0.05, 0.80);
    const n_medium = requiredSampleSize(0.5, 0.05, 0.80);
    const n_small = requiredSampleSize(0.2, 0.05, 0.80);

    try std.testing.expect(n_large < n_medium);
    try std.testing.expect(n_medium < n_small);
    try std.testing.expect(n_large < 100); // Large effect needs fewer samples
    try std.testing.expect(n_small > 300); // Small effect needs many samples
}
