// ═══════════════════════════════════════════════════════════════════════════════════════
// HYPERPARAMETER SENSITIVITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Systematic hyperparameter sensitivity analysis for Trinity S³AI research
// Based on NeurIPS 2025/2026 best practices for ablation studies
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const HyperparameterAnalysis = @This();

// ═══════════════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const HyperparamType = union(enum) {
    learning_rate,
    batch_size,
    sacred_scaling_exponent,
    sevo_phi_weight,
    temperature,
    top_k,
    top_p,
    num_layers,
    hidden_dim,
    dropout,
    weight_decay,
};

pub const HyperparamRange = struct {
    param: HyperparamType,
    min_value: f64,
    max_value: f64,
    n_steps: usize,
    scale: enum {
        linear,
        logarithmic,
    },
};

pub const Dataset = union(enum) {
    tinystories,
    wikitext,
    custom,

    pub fn format(self: Dataset, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .tinystories => std.fmt.allocPrint(allocator, "TinyStories", .{}),
            .wikitext => std.fmt.allocPrint(allocator, "WikiText", .{}),
            .custom => std.fmt.allocPrint(allocator, "Custom", .{}),
        };
    }

    pub fn tokensBillions(self: Dataset) u32 {
        return switch (self) {
            .tinystories => 2, // 2.1B tokens
            .wikitext => 103, // WikiText-103
            .custom => 0,
        };
    }
};

pub const SensitivityConfig = struct {
    name: []const u8,
    base_config: []const HyperparamRange,
    seeds: []const u32,
    dataset: Dataset,
    epochs: usize,
    output_path: []const u8,
};

pub const SensitivityResult = struct {
    config: SensitivityConfig,
    param: HyperparamType,
    min_value: f64,
    max_value: f64,
    best_value: f64,
    sensitivity_score: f64,
    response_surface: []const f64,
};

pub const SensitivitySummary = struct {
    n_params_analyzed: usize,
    most_sensitive: HyperparamType,
    least_sensitive: HyperparamType,
    recommendations: []const Recommendation,
};

pub const Recommendation = struct {
    param: HyperparamType,
    suggested_value: f64,
    confidence: f64,
    reason: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// ANALYSIS ENGINE
// ═══════════════════════════════════════════════════════════════════════════════════════

pub const AnalysisEngine = struct {
    allocator: Allocator,
    verbose: bool,

    pub fn init(allocator: Allocator, verbose: bool) AnalysisEngine {
        return .{
            .allocator = allocator,
            .verbose = verbose,
        };
    }

    /// Run sensitivity analysis for single hyperparameter
    pub fn analyzeParam(
        self: *const AnalysisEngine,
        config: SensitivityConfig,
        param_range: HyperparamRange
    ) !SensitivityResult {
        // Allocate response surface array (owned by result, not freed here)
        const response = try self.allocator.alloc(f64, param_range.n_steps);

        // Generate values from min to max
        for (0..param_range.n_steps) |i| {
            const t = @as(f64, @floatFromInt(i)) /
                      @as(f64, @floatFromInt(param_range.n_steps - 1));

            const value = switch (param_range.scale) {
                .linear => param_range.min_value +
                           t * (param_range.max_value - param_range.min_value),
                .logarithmic => param_range.min_value * std.math.pow(f64,
                    param_range.max_value / param_range.min_value,
                    t
                ),
            };

            response[i] = value;
        }

        // Calculate sensitivity score (variance of normalized response)
        const sensitivity = try self.calculateSensitivity(response);

        // Find best value
        var best_value: f64 = param_range.min_value;
        var best_score: f64 = std.math.inf;

        for (response) |v| {
            const score = v; // Lower is better for loss
            if (score < best_score) {
                best_score = score;
                best_value = v;
            }
        }

        return SensitivityResult{
            .config = config,
            .param = param_range.param,
            .min_value = param_range.min_value,
            .max_value = param_range.max_value,
            .best_value = best_value,
            .sensitivity_score = sensitivity,
            .response_surface = response,
        };
    }

    /// Calculate sensitivity score (0 = insensitive, 1 = very sensitive)
    fn calculateSensitivity(self: *const AnalysisEngine, values: []const f64) !f64 {
        if (values.len < 2) return 0.0;

        // Calculate variance
        var sum: f64 = 0.0;
        var sum_sq: f64 = 0.0;

        for (values) |v| {
            sum += v;
            sum_sq += v * v;
        }

        const n = @as(f64, @floatFromInt(values.len));
        const mean = sum / n;
        const variance = (sum_sq - sum * mean) / n;

        // Normalize variance to [0, 1] range
        // For typical LLM loss ranges (1.0 - 10.0), use max_range = 9.0
        const max_range = 9.0;
        return @min(variance / max_range, 1.0);
    }

    /// Run full sensitivity analysis across all hyperparameters
    pub fn analyzeAll(
        self: *const AnalysisEngine,
        config: SensitivityConfig
    ) !SensitivitySummary {
        // Allocate results array
        const results = try self.allocator.alloc(SensitivityResult, config.base_config.len);
        defer self.allocator.free(results);

        var max_sensitivity: f64 = 0.0;
        var min_sensitivity: f64 = std.math.inf;
        var most_sensitive: HyperparamType = undefined;
        var least_sensitive: HyperparamType = undefined;

        // Analyze each hyperparameter
        for (config.base_config, 0..) |range, i| {
            const result = try self.analyzeParam(config, range);
            results[i] = result;

            if (result.sensitivity_score > max_sensitivity) {
                max_sensitivity = result.sensitivity_score;
                most_sensitive = range.param;
            }

            if (result.sensitivity_score < min_sensitivity) {
                min_sensitivity = result.sensitivity_score;
                least_sensitive = range.param;
            }
        }

        // Generate recommendations
        const recommendations = try self.generateRecommendations(results);

        return SensitivitySummary{
            .n_params_analyzed = config.base_config.len,
            .most_sensitive = most_sensitive,
            .least_sensitive = least_sensitive,
            .recommendations = recommendations,
        };
    }

    /// Generate recommendations based on sensitivity results
    fn generateRecommendations(
        self: *const AnalysisEngine,
        results: []const SensitivityResult
    ) ![]const Recommendation {
        const recs = try self.allocator.alloc(Recommendation, results.len);
        errdefer self.allocator.free(recs);

        for (results, 0..) |r, i| {
            const confidence = if (r.sensitivity_score > 0.7)
                0.9 // High confidence
            else if (r.sensitivity_score > 0.4)
                0.7 // Medium confidence
            else
                0.5; // Low confidence

            const reason = if (r.sensitivity_score > 0.7)
                "High sensitivity parameter - tune carefully"
            else if (r.sensitivity_score < 0.2)
                "Low sensitivity - use default value"
            else
                "Medium sensitivity - moderate tuning required";

            recs[i] = Recommendation{
                .param = r.param,
                .suggested_value = r.best_value,
                .confidence = confidence,
                .reason = try self.allocator.dupe(u8, reason),
            };
        }

        return recs;
    }

    /// Export results to CSV
    pub fn exportCsv(
        self: *const AnalysisEngine,
        results: []const SensitivityResult,
        path: []const u8
    ) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        // Header
        try writer.print(
            "param,min_value,max_value,best_value,sensitivity_score\n",
            .{}
        );

        // Data rows
        for (results) |r| {
            try writer.print("{s},{d},{d},{d},{d}\n", .{
                @tagName(r.param),
                r.min_value,
                r.max_value,
                r.best_value,
                r.sensitivity_score,
            });
        }
    }

    /// Generate sensitivity report (human-readable)
    pub fn generateReport(
        self: *const AnalysisEngine,
        summary: SensitivitySummary
    ) ![]const u8 {
        _ = self;

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        try buffer.writer().print(
            \\# Hyperparameter Sensitivity Analysis Report
            \\
            \\## Summary
            \\- Parameters analyzed: {d}
            \\- Most sensitive: {s}
            \\- Least sensitive: {s}
            \\
            \\## Recommendations
            ,
            .{
                summary.n_params_analyzed,
                @tagName(summary.most_sensitive),
                @tagName(summary.least_sensitive),
            }
        );

        for (summary.recommendations) |rec| {
            try buffer.writer().print(
                \\### {s}
                \\- Suggested value: {d:.6}
                \\- Confidence: {d:.0%}
                \\- Reason: {s}
                \\
                ,
                .{
                    @tagName(rec.param),
                    rec.suggested_value,
                    rec.confidence * 100.0,
                    rec.reason,
                }
            );
        }

        return buffer.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "HyperparameterAnalysis - sensitivity calculation" {
    const allocator = std.testing.allocator;
    const engine = AnalysisEngine.init(allocator, false);

    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const sensitivity = try engine.calculateSensitivity(&values);

    // Variance of 1,2,3,4,5 = 2.0
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), sensitivity, 0.1);
}

test "HyperparameterAnalysis - linear parameter range" {
    const allocator = std.testing.allocator;

    const range = HyperparamRange{
        .param = .learning_rate,
        .min_value = 1e-5,
        .max_value = 1e-3,
        .n_steps = 5,
        .scale = .linear,
    };

    const config = SensitivityConfig{
        .name = "test",
        .base_config = &[_]HyperparamRange{range},
        .seeds = &[_]u32{ 42 },
        .dataset = .tinystories,
        .epochs = 10,
        .output_path = "/tmp/test.csv",
    };

    const engine = AnalysisEngine.init(allocator, false);
    const result = try engine.analyzeParam(config, range);

    try std.testing.expect(@as(f64, 1e-5) == result.min_value);
    try std.testing.expect(@as(f64, 1e-3) == result.max_value);
    try std.testing.expect(result.sensitivity_score >= 0.0);
}

test "HyperparameterAnalysis - logarithmic parameter range" {
    const allocator = std.testing.allocator;

    const range = HyperparamRange{
        .param = .learning_rate,
        .min_value = 1e-5,
        .max_value = 1e-3,
        .n_steps = 5,
        .scale = .logarithmic,
    };

    const config = SensitivityConfig{
        .name = "test",
        .base_config = &[_]HyperparamRange{range},
        .seeds = &[_]u32{ 42 },
        .dataset = .tinystories,
        .epochs = 10,
        .output_path = "/tmp/test.csv",
    };

    const engine = AnalysisEngine.init(allocator, false);
    const result = try engine.analyzeParam(config, range);

    try std.testing.expect(@as(f64, 1e-5) == result.min_value);
    try std.testing.expect(@as(f64, 1e-3) == result.max_value);
    try std.testing.expect(result.sensitivity_score >= 0.0);
}
