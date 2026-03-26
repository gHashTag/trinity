//! Sacred Statistics — φ-based Statistical Functions
//!
//! Implements statistical functions using golden ratio φ for
//! natural confidence intervals and effect size calculations.
//!
//! Mathematical Foundation:
//! - φ-based confidence intervals: CI = x̄ ± t·σ/√n · φ⁻¹
//! - Sacred effect size: d = (μ₁-μ₂) / σ_pooled · φ
//! - Natural variance: σ²_φ = σ² · (1 + φ⁻²)

const std = @import("std");

// Golden ratio constants (defined here for self-containment)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 1.0 / PHI; // ≈ 0.618
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV; // ≈ 0.382
pub const PHI_INV_CUBED: f64 = PHI_INV * PHI_INV * PHI_INV; // ≈ 0.236

// Re-export from sacred_math for compatibility
pub const Trit = @import("sacred_math.zig").Trit;

/// Confidence level options
pub const ConfidenceLevel = enum(u8) {
    c80,
    c90,
    c95,
    c99,

    /// Get z-score for this confidence level (two-tailed)
    pub fn zScore(self: ConfidenceLevel) f64 {
        return switch (self) {
            .c80 => 1.282,
            .c90 => 1.645,
            .c95 => 1.960,
            .c99 => 2.576,
        };
    }

    /// Get sacred multiplier (φ-adjusted)
    pub fn sacredMultiplier(self: ConfidenceLevel) f64 {
        return self.zScore() * PHI_INV;
    }
};

/// Statistical result with confidence interval
pub const ConfidenceInterval = struct {
    mean: f64,
    std_err: f64,
    lower: f64,
    upper: f64,
    level: ConfidenceLevel,
    n: usize,

    /// Calculate width of CI
    pub fn width(self: *const ConfidenceInterval) f64 {
        return self.upper - self.lower;
    }

    /// Format as [lower, upper]
    pub fn format(self: *const ConfidenceInterval, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "[{d:.2}, {d:.2}]", .{ self.lower, self.upper });
    }

    /// Check if value is within CI
    pub fn contains(self: *const ConfidenceInterval, value: f64) bool {
        return value >= self.lower and value <= self.upper;
    }
};

/// Calculate mean of slice
pub fn mean(data: []const f64) f64 {
    if (data.len == 0) return 0.0;
    var sum: f64 = 0.0;
    for (data) |x| sum += x;
    return sum / @as(f64, @floatFromInt(data.len));
}

/// Calculate variance (sample)
pub fn variance(data: []const f64) f64 {
    if (data.len < 2) return 0.0;
    const m = mean(data);
    var sum_sq: f64 = 0.0;
    for (data) |x| {
        const diff = x - m;
        sum_sq += diff * diff;
    }
    return sum_sq / @as(f64, @floatFromInt(data.len - 1));
}

/// Calculate standard deviation
pub fn stdDev(data: []const f64) f64 {
    return std.math.sqrt(variance(data));
}

/// Sacred variance (φ-weighted): σ²_φ = σ² · (1 + φ⁻²)
pub fn sacredVariance(data: []const f64) f64 {
    const v = variance(data);
    // (1 + φ⁻²) = (1 + 0.382) = 1.382
    return v * (1.0 + PHI_INV_SQ);
}

/// Sacred standard deviation
pub fn sacredStdDev(data: []const f64) f64 {
    return std.math.sqrt(sacredVariance(data));
}

/// Calculate standard error: σ / √n
pub fn stdError(data: []const f64) f64 {
    if (data.len == 0) return 0.0;
    return stdDev(data) / std.math.sqrt(@as(f64, @floatFromInt(data.len)));
}

/// Sacred standard error (φ-adjusted)
pub fn sacredStdError(data: []const f64) f64 {
    if (data.len == 0) return 0.0;
    return sacredStdDev(data) / std.math.sqrt(@as(f64, @floatFromInt(data.len)));
}

/// Calculate confidence interval using φ-adjustment
pub fn confidenceInterval(data: []const f64, level: ConfidenceLevel) ConfidenceInterval {
    if (data.len == 0) {
        return .{
            .mean = 0.0,
            .std_err = 0.0,
            .lower = 0.0,
            .upper = 0.0,
            .level = level,
            .n = 0,
        };
    }

    const m = mean(data);
    const se = sacredStdError(data);
    const margin = se * level.sacredMultiplier();

    return .{
        .mean = m,
        .std_err = se,
        .lower = m - margin,
        .upper = m + margin,
        .level = level,
        .n = data.len,
    };
}

/// Welch's t-test result
pub const WelchTestResult = struct {
    t_statistic: f64,
    degrees_of_freedom: f64,
    p_value: f64,
    significant: bool,
    alpha: f64,

    /// Format result for scientific papers
    pub fn format(self: *const WelchTestResult, allocator: std.mem.Allocator) ![]u8 {
        const sig_str = if (self.significant) "p < 0.05**" else "p = n.s.";
        return std.fmt.allocPrint(allocator, "Welch's t-test: t({d:.1}) = {d:.2}, {s}", .{ self.degrees_of_freedom, self.t_statistic, sig_str });
    }
};

/// Perform Welch's t-test (unequal variances)
pub fn welchTTest(sample1: []const f64, sample2: []const f64, alpha: f64) WelchTestResult {
    if (sample1.len < 2 or sample2.len < 2) {
        return .{
            .t_statistic = 0.0,
            .degrees_of_freedom = 0.0,
            .p_value = 1.0,
            .significant = false,
            .alpha = alpha,
        };
    }

    const m1 = mean(sample1);
    const m2 = mean(sample2);
    const v1 = variance(sample1);
    const v2 = variance(sample2);
    const n1: f64 = @floatFromInt(sample1.len);
    const n2: f64 = @floatFromInt(sample2.len);

    // t-statistic
    const se1 = v1 / n1;
    const se2 = v2 / n2;
    const se = std.math.sqrt(se1 + se2);
    const t_stat = (m1 - m2) / se;

    // Degrees of freedom (Welch-Satterthwaite)
    const se1_sq = se1 * se1;
    const se2_sq = se2 * se2;
    const df = (se1_sq + se2_sq) * (se1_sq + se2_sq) /
        ((se1_sq * se1_sq) / (n1 - 1.0) + (se2_sq * se2_sq) / (n2 - 1.0));

    // Approximate p-value (two-tailed)
    // Using error function approximation
    const abs_t = if (t_stat < 0) -t_stat else t_stat;
    const z = abs_t / std.math.sqrt(2.0);
    const p_value = 2.0 * (1.0 - erfApprox(z));

    return .{
        .t_statistic = t_stat,
        .degrees_of_freedom = df,
        .p_value = p_value,
        .significant = p_value < alpha,
        .alpha = alpha,
    };
}

/// Error function approximation (numerical recipes)
fn erfApprox(x: f64) f64 {
    const signs: f64 = if (x < 0) -1.0 else 1.0;
    const a = @abs(x);

    // Constants
    const p = 0.3275911;
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;

    const t = 1.0 / (1.0 + p * a);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * std.math.exp(-a * a);

    return signs * y;
}

/// Cohen's d effect size (sacred version)
pub const EffectSize = struct {
    cohens_d: f64,
    sacred_d: f64, // φ-adjusted
    interpretation: []const u8,

    /// Get interpretation string
    pub fn getInterpretation(self: *const EffectSize) []const u8 {
        const abs_d = if (self.cohens_d < 0) -self.cohens_d else self.cohens_d;
        if (abs_d < 0.2) return "negligible";
        if (abs_d < 0.5) return "small";
        if (abs_d < 0.8) return "medium";
        return "large";
    }
};

/// Calculate Cohen's d (effect size)
pub fn cohensD(sample1: []const f64, sample2: []const f64) EffectSize {
    if (sample1.len == 0 or sample2.len == 0) {
        return .{
            .cohens_d = 0.0,
            .sacred_d = 0.0,
            .interpretation = "undefined",
        };
    }

    const m1 = mean(sample1);
    const m2 = mean(sample2);
    const v1 = variance(sample1);
    const v2 = variance(sample2);
    const n1: f64 = @floatFromInt(sample1.len);
    const n2: f64 = @floatFromInt(sample2.len);

    // Pooled standard deviation
    const pooled_var = ((n1 - 1.0) * v1 + (n2 - 1.0) * v2) / (n1 + n2 - 2.0);
    const pooled_sd = std.math.sqrt(pooled_var);

    const d = if (pooled_sd > 0) (m1 - m2) / pooled_sd else 0.0;
    const sacred_d = d * PHI; // φ-adjusted effect size

    return .{
        .cohens_d = d,
        .sacred_d = sacred_d,
        .interpretation = undefined, // Use getInterpretation()
    };
}

/// Sacred distance metric: d(a, b) = |a - b| / φ
pub fn sacredDistance(a: f64, b: f64) f64 {
    return @abs(a - b) / PHI;
}

/// Batch sacred distance (vector to vector)
pub fn sacredDistanceVec(vec1: []const f64, vec2: []const f64) !f64 {
    if (vec1.len != vec2.len) return error.DimensionMismatch;

    var sum_sq: f64 = 0.0;
    for (vec1, vec2) |v1, v2| {
        const dist = sacredDistance(v1, v2);
        sum_sq += dist * dist;
    }
    return std.math.sqrt(sum_sq);
}

/// Correlation coefficient (Pearson)
pub fn correlation(x_data: []const f64, y_data: []const f64) !f64 {
    if (x_data.len != y_data.len or x_data.len < 2) return error.InvalidData;
    const mx = mean(x_data);
    const my = mean(y_data);

    var num: f64 = 0.0;
    var sum_x2: f64 = 0.0;
    var sum_y2: f64 = 0.0;

    for (x_data, y_data) |x, y| {
        const dx = x - mx;
        const dy = y - my;
        num += dx * dy;
        sum_x2 += dx * dx;
        sum_y2 += dy * dy;
    }

    const den = std.math.sqrt(sum_x2 * sum_y2);
    return if (den > 0) num / den else 0.0;
}

/// Median calculation
pub fn median(data: []const f64) f64 {
    if (data.len == 0) return 0.0;

    // Copy and sort
    const sorted = std.heap.page_allocator.dupe(f64, data) catch return 0.0;
    defer std.heap.page_allocator.free(sorted);

    std.sort.insertion(f64, sorted, {}, comptime std.sort.asc(f64));

    const mid = sorted.len / 2;
    if (sorted.len % 2 == 0) {
        return (sorted[mid - 1] + sorted[mid]) / 2.0;
    } else {
        return sorted[mid];
    }
}

/// Percentile calculation
pub fn percentile(data: []const f64, p: f64) f64 {
    if (data.len == 0 or p < 0 or p > 100) return 0.0;

    const sorted = std.heap.page_allocator.dupe(f64, data) catch return 0.0;
    defer std.heap.page_allocator.free(sorted);

    std.sort.insertion(f64, sorted, {}, comptime std.sort.asc(f64));

    const idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * p / 100.0));
    return sorted[idx];
}

// Tests
test "ConfidenceInterval calculation" {
    const data = [_]f64{ 125.0, 126.0, 124.0, 125.5, 125.3 };

    const ci = confidenceInterval(&data, .c95);

    try std.testing.expect(ci.mean > 124 and ci.mean < 127);
    try std.testing.expect(ci.lower < ci.mean);
    try std.testing.expect(ci.upper > ci.mean);
    try std.testing.expect(ci.width() > 0);
}

test "Welch's t-test" {
    const sample1 = [_]f64{ 125.3, 125.1, 125.5, 125.0, 125.7 };
    const sample2 = [_]f64{ 128.7, 128.5, 129.0, 128.3, 128.8 };

    const result = welchTTest(&sample1, &sample2, 0.05);

    try std.testing.expect(result.t_statistic < 0); // sample1 < sample2
    try std.testing.expect(result.p_value < 0.05); // Should be significant
    try std.testing.expect(result.significant);
}

test "Cohen's d effect size" {
    const sample1 = [_]f64{ 10.0, 11.0, 12.0, 10.5, 11.5 };
    const sample2 = [_]f64{ 8.0, 9.0, 8.5, 9.5, 8.3 };

    const effect = cohensD(&sample1, &sample2);

    try std.testing.expect(effect.cohens_d > 0); // sample1 > sample2
    try std.testing.expect(effect.sacred_d > effect.cohens_d); // φ-adjusted > standard
}

test "Sacred distance" {
    const dist = sacredDistance(10.0, 5.0);
    const expected = 5.0 / PHI; // |10-5| / φ

    try std.testing.expectApproxEqRel(dist, expected, 0.001);
}

test "Correlation coefficient" {
    const x = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const y = [_]f64{ 2.0, 4.0, 6.0, 8.0, 10.0 }; // Perfect linear: y = 2x

    const r = try correlation(&x, &y);

    try std.testing.expectApproxEqRel(r, 1.0, 0.001); // Perfect correlation
}

test "Median calculation" {
    const odd = [_]f64{ 1.0, 3.0, 2.0, 5.0, 4.0 };
    const even = [_]f64{ 1.0, 3.0, 2.0, 4.0 };

    try std.testing.expectEqual(@as(f64, 3.0), median(&odd));
    try std.testing.expectEqual(@as(f64, 2.5), median(&even));
}

test "Percentile calculation" {
    const data = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 };

    try std.testing.expectEqual(@as(f64, 5.0), percentile(&data, 50)); // Median
    try std.testing.expectEqual(@as(f64, 9.0), percentile(&data, 90)); // 90th percentile
}
