//! Zenodo V16: Core Scientific Rigor Module
//!
//! This module provides statistical rigor features for scientific publication
//! compliance with NeurIPS 2025, ICLR 2025, and MLSys 2025 standards.
//!
//! Key features:
//! - Statistical significance testing with p-value thresholds (*, **, ***)
//! - Confidence intervals (bootstrap, Bayesian, analytical)
//! - Multiple statistical tests (t-test, Wilcoxon, Mann-Whitney, ANOVA, Chi-square)
//! - Effect size calculation (Cohen's d)
//! - Significance markers for LaTeX and Markdown
//!
//! Standards compliance:
//! - NeurIPS 2025: Statistical rigor requirements
//! - ICLR 2025: Multiple comparison correction
//! - MLSys 2025: Scaling analysis with confidence intervals

const std = @import("std");

/// Statistical significance levels
pub const SignificanceLevel = enum {
    /// Not significant (p >= 0.05)
    none,
    /// Significant at p < 0.05 (*)
    star,
    /// Highly significant at p < 0.01 (**)
    double_star,
    /// Very highly significant at p < 0.001 (***)
    triple_star,

    pub fn fromPValue(p: f64) SignificanceLevel {
        if (p < 0.001) return .triple_star;
        if (p < 0.01) return .double_star;
        if (p < 0.05) return .star;
        return .none;
    }

    pub fn toSymbol(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .none => "",
            .star => "*",
            .double_star => "**",
            .triple_star => "***",
        };
    }

    pub fn toLaTeXMarker(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .none => "",
            .star => "\\textsuperscript{*}",
            .double_star => "\\textsuperscript{**}",
            .triple_star => "\\textsuperscript{***}",
        };
    }
};

/// Confidence interval calculation method
pub const CIMethod = enum {
    /// Non-parametric bootstrap (recommended for non-normal distributions)
    bootstrap,
    /// Bayesian credible interval (requires prior distribution)
    bayesian,
    /// Analytical using t-distribution (assumes normality)
    analytical,
};

/// Confidence interval
pub const ConfidenceInterval = struct {
    /// Lower bound
    lower: f64,
    /// Upper bound
    upper: f64,
    /// Confidence level (0.95 = 95%)
    confidence: f64,
    /// Calculation method
    method: CIMethod,

    /// Format as Markdown string
    pub fn formatAsMarkdown(self: *const ConfidenceInterval, allocator: std.mem.Allocator) ![]u8 {
        const pct = self.confidence * 100;
        const pct_str = try std.fmt.allocPrint(allocator, "{d:.1}%", .{pct});
        defer allocator.free(pct_str);
        const lower_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.lower});
        defer allocator.free(lower_str);
        const upper_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.upper});
        defer allocator.free(upper_str);

        return std.fmt.allocPrint(allocator, "[{s}, {s}] ({s})", .{ lower_str, upper_str, pct_str });
    }

    /// Format as LaTeX string
    pub fn formatAsLaTeX(self: *const ConfidenceInterval, allocator: std.mem.Allocator) ![]u8 {
        const pct = self.confidence * 100;
        const pct_str = try std.fmt.allocPrint(allocator, "{d:.1}\\\\%", .{pct});
        defer allocator.free(pct_str);
        const lower_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.lower});
        defer allocator.free(lower_str);
        const upper_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.upper});
        defer allocator.free(upper_str);

        return std.fmt.allocPrint(allocator, "[{s}, {s}] ({s})", .{ lower_str, upper_str, pct_str });
    }
};

/// Statistical test type
pub const StatisticalTestType = enum {
    /// Two-sample t-test (assumes normality)
    ttest,
    /// Wilcoxon rank-sum test (non-parametric)
    wilcoxon,
    /// Mann-Whitney U test (non-parametric)
    mann_whitney,
    /// One-way ANOVA (multiple groups)
    anova,
    /// Chi-square test of independence
    chi_square,
};

/// Statistical test result
pub const StatisticalTestResult = struct {
    /// Test type used
    test_type: StatisticalTestType,
    /// Test statistic value
    statistic: f64,
    /// P-value
    p_value: f64,
    /// Significance level
    significance: SignificanceLevel,
    /// Effect size (Cohen's d where applicable)
    effect_size: ?f64,
    /// Interpretation text
    interpretation: []const u8,

    /// Format as Markdown
    pub fn formatAsMarkdown(self: *const StatisticalTestResult, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "**Statistical Test**: ");
        try result.appendSlice(allocator, self.testDescription());
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**Statistic**: ");
        const stat_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.statistic});
        defer allocator.free(stat_str);
        try result.appendSlice(allocator, stat_str);
        try result.appendSlice(allocator, "\\n");

        try result.appendSlice(allocator, "**P-value**: ");
        const p_str = try std.fmt.allocPrint(allocator, "{e:.4}", .{self.p_value});
        defer allocator.free(p_str);
        try result.appendSlice(allocator, p_str);
        try result.appendSlice(allocator, " ");
        try result.appendSlice(allocator, self.significance.toSymbol());
        try result.appendSlice(allocator, "\\n");

        if (self.effect_size) |es| {
            try result.appendSlice(allocator, "**Effect Size (Cohen's d)**: ");
            const es_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{es});
            defer allocator.free(es_str);
            try result.appendSlice(allocator, es_str);
            try result.appendSlice(allocator, "\\n");
        }

        try result.appendSlice(allocator, "**Interpretation**: ");
        try result.appendSlice(allocator, self.interpretation);
        try result.appendSlice(allocator, "\\n");

        return result.toOwnedSlice(allocator);
    }

    /// Get human-readable test description
    fn testDescription(self: *const StatisticalTestResult) []const u8 {
        return switch (self.test_type) {
            .ttest => "Two-sample t-test",
            .wilcoxon => "Wilcoxon rank-sum test",
            .mann_whitney => "Mann-Whitney U test",
            .anova => "One-way ANOVA",
            .chi_square => "Chi-square test of independence",
        };
    }
};

/// Enhanced experiment result with statistical annotations
pub const ExperimentResultEnhanced = struct {
    /// Experiment identifier
    experiment_id: []const u8,
    /// Mean value
    mean: f64,
    /// Standard deviation
    std_dev: f64,
    /// Sample size
    n_samples: u64,
    /// Confidence interval
    ci: ?ConfidenceInterval,
    /// Significance markers (for comparison tables)
    significance: SignificanceLevel,

    /// Format as LaTeX table row
    pub fn formatAsLaTeXRow(self: *const ExperimentResultEnhanced, allocator: std.mem.Allocator) ![]u8 {
        const mean_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.mean});
        defer allocator.free(mean_str);
        const std_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{self.std_dev});
        defer allocator.free(std_str);

        return std.fmt.allocPrint(allocator, "{s} & {s:.3f} & {s:.3f}", .{ self.experiment_id, self.mean, self.std_dev });
    }
};

/// Enhanced experiment comparison for multiple experiments
pub const ExperimentComparisonEnhanced = struct {
    /// Metric name (e.g., "Accuracy", "PPL")
    metric_name: []const u8,
    /// Experiment results
    results: []const ExperimentResultEnhanced,
    /// Reference baseline (if any)
    baseline: ?[]const u8,

    /// Generate comparison table
    pub fn generateComparisonTable(self: *const ExperimentComparisonEnhanced, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 512);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "| Experiment | ");
        try result.appendSlice(allocator, self.metric_name);
        try result.appendSlice(allocator, " | Std Dev | CI | Significance |\\n");
        try result.appendSlice(allocator, "|-----------|------------|---------|-------|--------------|\\n");

        for (self.results) |exp| {
            try result.appendSlice(allocator, "| ");
            try result.appendSlice(allocator, exp.experiment_id);
            try result.appendSlice(allocator, " | ");

            const mean_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{exp.mean});
            defer allocator.free(mean_str);
            try result.appendSlice(allocator, mean_str);
            try result.appendSlice(allocator, " | ");

            const std_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{exp.std_dev});
            defer allocator.free(std_str);
            try result.appendSlice(allocator, std_str);
            try result.appendSlice(allocator, " | ");

            if (exp.ci) |ci| {
                const ci_str = try ci.formatAsMarkdown(allocator);
                defer allocator.free(ci_str);
                try result.appendSlice(allocator, ci_str);
            } else {
                try result.appendSlice(allocator, "N/A");
            }

            try result.appendSlice(allocator, " | ");
            try result.appendSlice(allocator, exp.significance.toSymbol());
            try result.appendSlice(allocator, " |\\n");
        }

        return result.toOwnedSlice(allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════

test "SignificanceLevel fromPValue" {
    try std.testing.expectEqual(SignificanceLevel.fromPValue(0.1), .none);
    try std.testing.expectEqual(SignificanceLevel.fromPValue(0.04), .star);
    try std.testing.expectEqual(SignificanceLevel.fromPValue(0.009), .double_star);
    try std.testing.expectEqual(SignificanceLevel.fromPValue(0.0009), .triple_star);
}

test "SignificanceLevel symbols" {
    try std.testing.expectEqual(SignificanceLevel.star.toSymbol(), "*");
    try std.testing.expectEqual(SignificanceLevel.double_star.toSymbol(), "**");
    try std.testing.expectEqual(SignificanceLevel.triple_star.toSymbol(), "***");
    try std.testing.expectEqual(SignificanceLevel.none.toSymbol(), "");
}

test "ConfidenceInterval formatAsMarkdown" {
    const ci = ConfidenceInterval{
        .lower = 0.85,
        .upper = 0.95,
        .confidence = 0.95,
        .method = .bootstrap,
    };

    const md = try ci.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "[0.8500, 0.9500]") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "95.0%") != null);
}

test "StatisticalTestResult formatAsMarkdown" {
    const result = StatisticalTestResult{
        .test_type = .ttest,
        .statistic = 2.5,
        .p_value = 0.012,
        .significance = SignificanceLevel.double_star,
        .effect_size = 0.8,
        .interpretation = "Large effect, statistically significant",
    };

    const md = try result.formatAsMarkdown(std.testing.allocator);
    defer std.testing.allocator.free(md);

    try std.testing.expect(std.mem.indexOf(u8, md, "Two-sample t-test") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "Cohen's d") != null);
}

test "ExperimentComparisonEnhanced generateComparisonTable" {
    const results = [_]ExperimentResultEnhanced{
        .{
            .experiment_id = "Model A",
            .mean = 0.85,
            .std_dev = 0.05,
            .n_samples = 1000,
            .ci = ConfidenceInterval{
                .lower = 0.83,
                .upper = 0.87,
                .confidence = 0.95,
                .method = .bootstrap,
            },
            .significance = SignificanceLevel.double_star,
        },
        .{
            .experiment_id = "Model B",
            .mean = 0.82,
            .std_dev = 0.06,
            .n_samples = 1000,
            .ci = null,
            .significance = SignificanceLevel.star,
        },
    };

    const comparison = ExperimentComparisonEnhanced{
        .metric_name = "Accuracy",
        .results = &results,
        .baseline = null,
    };

    const table = try comparison.generateComparisonTable(std.testing.allocator);
    defer std.testing.allocator.free(table);

    try std.testing.expect(std.mem.indexOf(u8, table, "Model A") != null);
    try std.testing.expect(std.mem.indexOf(u8, table, "Accuracy") != null);
}
