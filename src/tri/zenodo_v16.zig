//! Zenodo V16: Statistical Significance Module
//! Placeholder for future implementation

const std = @import("std");

pub const Method = enum {
    bootstrap,
    bayesian,
    analytical,
};

pub const ConfidenceInterval = struct {
    lower: f64,
    upper: f64,
    confidence: f64,
    method: Method,
};

pub const SignificanceLevel = enum {
    ns,
    single_star,
    double_star,
    triple_star,

    pub fn emoji(self: SignificanceLevel) []const u8 {
        return switch (self) {
            .ns => "",
            .single_star => "*",
            .double_star => "**",
            .triple_star => "***",
        };
    }
};

pub const StatisticalTestResult = struct {
    test_type: TestType,
    statistic: f64,
    p_value: f64,
    significance: SignificanceLevel,
    effect_size: f64,
    interpretation: []const u8,
};

pub const TestType = enum {
    ttest,
    wilcoxon,
    mann_whitney,
    anova,
    chi_square,
};

pub const StatisticalSignificance = enum(u8) {
    ns, // p > 0.05
    @"*", // p ≤ 0.05
    @"**", // p ≤ 0.01
    @"***", // p ≤ 0.001

    pub fn format(self: StatisticalSignificance) []const u8 {
        return switch (self) {
            .ns => "ns",
            .@"*" => "p ≤ 0.05",
            .@"**" => "p ≤ 0.01",
            .@"***" => "p ≤ 0.001",
        };
    }
};

test "v16 placeholder" {
    try std.testing.expectEqual(StatisticalSignificance.@"***".format(), "p ≤ 0.001");
}
