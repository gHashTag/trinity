//! Zenodo V20: Advanced Statistical Methods
//! Placeholder for future implementation

const std = @import("std");

pub const StatisticalTest = enum {
    t_test,
    wilcoxon,
    mann_whitney,
    anova,
    chi_square,
};

pub const TestResult = struct {
    test_type: StatisticalTest,
    statistic: f64,
    p_value: f64,
    significant: bool,
    confidence_interval: ?[2]f64, // [lower, upper]

    pub fn isSignificant(self: TestResult, alpha: f64) bool {
        return self.p_value < alpha;
    }

    pub fn formatMarkdown(self: TestResult, allocator: std.mem.Allocator) ![]const u8 {
        const sig_str = if (self.isSignificant(0.05)) "**significant**" else "not significant";
        return std.fmt.allocPrint(allocator,
            \\{s}: statistic={d:.3}, p={d:.4} ({s})
        , .{
            @tagName(self.test_type), self.statistic, self.p_value, sig_str
        });
    }
};

test "v20 stats placeholder" {
    const result = TestResult{
        .test_type = .t_test,
        .statistic = 2.5,
        .p_value = 0.01,
        .significant = true,
        .confidence_interval = null,
    };
    try std.testing.expect(result.isSignificant(0.05));
    try std.testing.expect(!result.isSignificant(0.001));
}
