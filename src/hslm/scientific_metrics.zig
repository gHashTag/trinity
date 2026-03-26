//! HSLM Scientific Metrics — Sacred Statistics Integration
//!
//! Integrates sacred mathematical functions with HSLM training metrics
//! for NeurIPS 2026 publication-ready analysis.
//!
//! Provides:
//! - Sacred learning rate schedules for HSLM training
//! - Statistical analysis of perplexity curves
//! - CI95 confidence intervals for metrics
//! - Scientific reporting functions

const std = @import("std");
const sacred_stats = @import("../temple/sacred_statistics.zig");
const sacred_funcs = @import("../temple/sacred_functions.zig");

// ═══════════════════════════════════════════════════════════════════════════
// HSLM TRAINING CONFIG WITH SACRED SCHEDULES
// ═══════════════════════════════════════════════════════════════════════════

/// HSLM training configuration with sacred defaults
pub const HSLMConfig = struct {
    /// Peak learning rate (after warmup)
    lr_peak: f64 = 3e-4,
    /// Minimum learning rate at end
    lr_min: f64 = 1e-6,
    /// Total training steps
    total_steps: u32 = 30000,
    /// Warmup steps
    warmup_steps: u32 = 5000,
    /// Batch size
    batch_size: u32 = 64,
    /// Gradient clipping norm
    grad_clip: f64 = 1.0,
    /// Weight decay (L2 regularization)
    weight_decay: f64 = 0.01,
    /// Use sacred learning rate schedule
    use_sacred_lr: bool = true,
    /// Target perplexity for early stopping
    target_ppl: f64 = 125.0,
    /// Maximum patience for early stopping
    max_patience: u32 = 5000,

    /// Get default config for HSLM-1.95M
    pub fn default1_95M() HSLMConfig {
        return .{
            .lr_peak = 3e-4,
            .lr_min = 1e-6,
            .total_steps = 30000,
            .warmup_steps = 5000,
            .batch_size = 64,
            .grad_clip = 1.0,
            .weight_decay = 0.01,
            .use_sacred_lr = true,
            .target_ppl = 125.0,
            .max_patience = 5000,
        };
    }

    /// Validate configuration
    pub fn validate(self: HSLMConfig) !void {
        if (self.lr_peak <= 0) return error.InvalidLrPeak;
        if (self.lr_min < 0) return error.InvalidLrMin;
        if (self.lr_min >= self.lr_peak) return error.LrRangeError;
        if (self.total_steps == 0) return error.InvalidTotalSteps;
        if (self.warmup_steps >= self.total_steps) return error.InvalidWarmup;
        if (self.batch_size == 0) return error.InvalidBatchSize;
        if (self.grad_clip <= 0) return error.InvalidGradClip;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// SACRED LEARNING RATE SCHEDULES
// ═══════════════════════════════════════════════════════════════════════════

/// Learning rate schedule types
pub const LRSchedule = enum {
    constant,
    linear,
    cosine,
    sacred, // φ-based decay
    sacred_cosine, // cosine with φ modulation
    warmup_sacred, // warmup + sacred decay

    pub fn toString(self: LRSchedule) []const u8 {
        return switch (self) {
            .constant => "constant",
            .linear => "linear",
            .cosine => "cosine",
            .sacred => "sacred",
            .sacred_cosine => "sacred_cosine",
            .warmup_sacred => "warmup_sacred",
        };
    }
};

/// Get learning rate at given step using specified schedule
pub fn getLR(schedule: LRSchedule, config: HSLMConfig, step: u32) f64 {
    if (step >= config.total_steps) return config.lr_min;

    return switch (schedule) {
        .constant => config.lr_peak,

        .linear => {
            const progress: f64 = @as(f64, @floatFromInt(step)) /
                @as(f64, @floatFromInt(config.total_steps));
            config.lr_peak * (1.0 - progress) + config.lr_min * progress;
        },

        .cosine => {
            const progress: f64 = @as(f64, @floatFromInt(step)) /
                @as(f64, @floatFromInt(config.total_steps));
            const cosine = 0.5 * (1.0 + std.math.cos(std.math.pi * progress));
            config.lr_peak * cosine + config.lr_min * (1.0 - cosine);
        },

        .sacred => config.lr_peak * sacred_funcs.PHI_INV *
            std.math.pow(f64, sacred_funcs.PHI, -@as(f64, @floatFromInt(step)) /
                @as(f64, @floatFromInt(config.total_steps)) / sacred_funcs.PHI),

        .sacred_cosine => {
            const progress: f64 = @as(f64, @floatFromInt(step)) /
                @as(f64, @floatFromInt(config.total_steps));
            const cosine = 0.5 * (1.0 + std.math.cos(std.math.pi * progress / sacred_funcs.PHI));
            config.lr_peak * cosine + config.lr_min * (1.0 - cosine);
        },

        .warmup_sacred => {
            if (step < config.warmup_steps) {
                // Linear warmup
                const warmup_prog: f64 = @as(f64, @floatFromInt(step)) /
                    @as(f64, @floatFromInt(config.warmup_steps));
                return config.lr_min + (config.lr_peak - config.lr_min) * warmup_prog;
            }
            // Sacred decay after warmup
            const remaining = config.total_steps - config.warmup_steps;
            const decay_step = step - config.warmup_steps;
            const progress: f64 = @as(f64, @floatFromInt(decay_step)) /
                @as(f64, @floatFromInt(remaining));
            return config.lr_peak * std.math.pow(f64, sacred_funcs.PHI, -progress / sacred_funcs.PHI);
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// TRAINING METRICS WITH STATISTICAL ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════

/// Single training step metrics
pub const StepMetrics = struct {
    step: u32,
    loss: f64,
    perplexity: f64,
    lr: f64,
    tokens_per_sec: f64,
    timestamp: i64,

    /// Create from loss value
    pub fn fromLoss(step: u32, loss: f64, lr: f64) StepMetrics {
        return .{
            .step = step,
            .loss = loss,
            .perplexity = std.math.exp(loss),
            .lr = lr,
            .tokens_per_sec = 0.0,
            .timestamp = std.time.nanoTimestamp(),
        };
    }
};

/// Training run statistics (multiple runs for CI95)
pub const RunStatistics = struct {
    /// Perplexity values from each run at final step
    final_ppls: []const f64,
    /// Best perplexity from each run
    best_ppls: []const f64,
    /// Convergence step for each run
    convergence_steps: []const u32,

    /// Calculate mean final perplexity
    pub fn meanFinalPPL(self: *const RunStatistics) f64 {
        return sacred_stats.mean(self.final_ppls);
    }

    /// Calculate std error of final perplexity
    pub fn stderrFinalPPL(self: *const RunStatistics) f64 {
        return sacred_stats.stdError(self.final_ppls);
    }

    /// Calculate CI95 for final perplexity
    pub fn ci95FinalPPL(self: *const RunStatistics) sacred_stats.ConfidenceInterval {
        return sacred_stats.confidenceInterval(self.final_ppls, .c95);
    }

    /// Format as NeurIPS table row
    pub fn formatTableRow(self: *const RunStatistics, allocator: std.mem.Allocator, method_name: []const u8) ![]u8 {
        const ci = self.ci95FinalPPL();
        const ci_str = try ci.format(allocator);
        defer allocator.free(ci_str);

        return std.fmt.allocPrint(allocator,
            \\{s} & {d:.1} \\pm {d:.1} & {s} \\\\
        , .{
            method_name,
            self.meanFinalPPL(),
            self.stderrFinalPPL(),
            ci_str,
        });
    }
};

/// Training session tracker
pub const TrainingSession = struct {
    config: HSLMConfig,
    schedule: LRSchedule,
    steps: std.ArrayList(StepMetrics),
    start_time: i64,
    allocator: std.mem.Allocator,

    /// Initialize new training session
    pub fn init(allocator: std.mem.Allocator, config: HSLMConfig, schedule: LRSchedule) TrainingSession {
        return .{
            .config = config,
            .schedule = schedule,
            .steps = std.ArrayList(StepMetrics).init(allocator),
            .start_time = std.time.nanoTimestamp(),
            .allocator = allocator,
        };
    }

    /// Record a training step
    pub fn recordStep(self: *TrainingSession, step: u32, loss: f64, tokens_per_sec: f64) !void {
        const lr = getLR(self.schedule, self.config, step);
        const metrics = StepMetrics{
            .step = step,
            .loss = loss,
            .perplexity = std.math.exp(loss),
            .lr = lr,
            .tokens_per_sec = tokens_per_sec,
            .timestamp = std.time.nanoTimestamp(),
        };
        try self.steps.append(metrics);
    }

    /// Get all losses as slice
    pub fn getLosses(self: *const TrainingSession) []f64 {
        const result = self.allocator.alloc(f64, self.steps.items.len) catch return &[_]f64{};
        for (self.steps.items, 0..) |m, i| {
            result[i] = m.loss;
        }
        return result;
    }

    /// Get all perplexities as slice
    pub fn getPerplexities(self: *const TrainingSession) []f64 {
        const result = self.allocator.alloc(f64, self.steps.items.len) catch return &[_]f64{};
        for (self.steps.items, 0..) |m, i| {
            result[i] = m.perplexity;
        }
        return result;
    }

    /// Calculate final statistics
    pub fn getFinalStats(self: *const TrainingSession) RunStatistics {
        _ = self;
        // Would aggregate from multiple runs
        return RunStatistics{
            .final_ppls = &[_]f64{},
            .best_ppls = &[_]f64{},
            .convergence_steps = &[_]u32{},
        };
    }

    /// Export training data as CSV
    pub fn exportCSV(self: *const TrainingSession, writer: anytype) !void {
        try writer.print("step,loss,perplexity,lr,tokens_per_sec,timestamp_ns\n", .{});
        for (self.steps.items) |m| {
            try writer.print("{d},{e},{e},{e},{e},{d}\n", .{
                m.step, m.loss, m.perplexity, m.lr, m.tokens_per_sec, m.timestamp,
            });
        }
    }

    /// Deinitialize
    pub fn deinit(self: *TrainingSession) void {
        self.steps.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// STATISTICAL COMPARISON
// ═══════════════════════════════════════════════════════════════════════════

/// Compare two training runs (e.g., sacred vs standard scaling)
pub const ComparisonResult = struct {
    method_a: []const u8,
    method_b: []const u8,
    ppl_a: f64,
    ppl_b: f64,
    improvement: f64,
    welch_result: sacred_stats.WelchTestResult,
    effect_size: sacred_stats.EffectSize,
    significant: bool,

    /// Format comparison as LaTeX table row
    pub fn formatLatex(self: *const ComparisonResult, allocator: std.mem.Allocator) ![]u8 {
        const sig_str = if (self.significant) "$^{**}$" else "";
        const eff_str = self.effect_size.getInterpretation();

        return std.fmt.allocPrint(allocator,
            \\{s} & {d:.1} & {d:.1} & {d:.1} & {s} & {s} \\\\
        , .{
            self.method_a,
            self.ppl_a,
            self.ppl_b,
            self.improvement,
            sig_str,
            eff_str,
        });
    }
};

/// Perform statistical comparison between two methods
pub fn compareMethods(allocator: std.mem.Allocator, method_a: []const u8, ppl_values_a: []const f64, method_b: []const u8, ppl_values_b: []const f64, alpha: f64) !ComparisonResult {
    const mean_a = sacred_stats.mean(ppl_values_a);
    const mean_b = sacred_stats.mean(ppl_values_b);

    const welch = sacred_stats.welchTTest(ppl_values_a, ppl_values_b, alpha);
    const effect = sacred_stats.cohensD(ppl_values_a, ppl_values_b);

    return ComparisonResult{
        .method_a = try allocator.dupe(u8, method_a),
        .method_b = try allocator.dupe(u8, method_b),
        .ppl_a = mean_a,
        .ppl_b = mean_b,
        .improvement = mean_b - mean_a, // Positive means b is better (lower PPL)
        .welch_result = welch,
        .effect_size = effect,
        .significant = welch.significant,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// SACRED LOSS FUNCTIONS FOR HSLM
// ═══════════════════════════════════════════════════════════════════════════

/// Calculate cross-entropy loss with sacred normalization
pub fn sacredCrossEntropyLoss(logits: []const f64, targets: []const u32) f64 {
    if (logits.len != targets.len) return 0.0;

    var sum: f64 = 0.0;
    for (logits, targets) |l, t| {
        const target_idx: usize = @intCast(t);
        if (target_idx < logits.len) {
            const clamped = if (l < 0.0001) 0.0001 else l;
            sum += @log(clamped);
        }
    }

    return -sum / sacred_funcs.PHI;
}

/// Calculate perplexity from loss
pub fn lossToPerplexity(loss: f64) f64 {
    return std.math.exp(loss);
}

/// Calculate sacred perplexity (φ-adjusted)
pub fn sacredPerplexity(loss: f64) f64 {
    return std.math.exp(loss / sacred_funcs.PHI);
}

// ═══════════════════════════════════════════════════════════════════════════
// NEURIPS TABLE GENERATION
// ═══════════════════════════════════════════════════════════════════════════

/// Generate NeurIPS-style results table
pub fn generateNeurIPSTable(allocator: std.mem.Allocator, comparisons: []const ComparisonResult) ![]u8 {
    var table = std.ArrayList(u8).init(allocator);
    defer table.deinit();

    try table.appendSlice("\\begin{table}[h]\n");
    try table.appendSlice("\\centering\n");
    try table.appendSlice("\\caption{Perplexity Comparison on TinyStories}\n");
    try table.appendSlice("\\begin{tabular}{lccc}\n");
    try table.appendSlice("\\toprule\n");
    try table.appendSlice("Method & PPL & StdErr & CI95 \\\\\n");
    try table.appendSlice("\\midrule\n");

    for (comparisons) |comp| {
        const row = try comp.formatLatex(allocator);
        defer allocator.free(row);
        try table.appendSlice(row);
        try table.appendSlice("\n");
    }

    try table.appendSlice("\\bottomrule\n");
    try table.appendSlice("\\end{tabular}\n");
    try table.appendSlice("\\end{table}\n");

    return table.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "HSLMConfig validation" {
    const config = HSLMConfig.default1_95M();
    try config.validate();

    var invalid = config;
    invalid.lr_peak = -1.0;
    try std.testing.expectError(error.InvalidLrPeak, invalid.validate());
}

test "Learning rate schedules" {
    const config = HSLMConfig.default1_95M();

    // Test sacred schedule
    const lr_0 = getLR(.sacred, config, 0);
    const lr_mid = getLR(.sacred, config, 15000);
    const lr_end = getLR(.sacred, config, 30000);

    try std.testing.expect(lr_0 >= lr_mid);
    try std.testing.expect(lr_mid >= lr_end);
}

test "Sacred cross-entropy loss" {
    const logits = [_]f64{ 0.1, 0.2, 0.7 };
    const targets = [_]u32{ 2, 2, 2 };

    const loss = sacredCrossEntropyLoss(&logits, &targets);
    try std.testing.expect(loss > 0);
}

test "Perplexity conversion" {
    const loss = 4.8; // ~122 perplexity
    const ppl = lossToPerplexity(loss);

    try std.testing.expect(ppl > 100);
    try std.testing.expect(ppl < 150);
}

test "Method comparison" {
    const method_a_ppl = [_]f64{ 125.3, 125.1, 125.5, 125.0, 125.7 };
    const method_b_ppl = [_]f64{ 128.7, 128.5, 129.0, 128.3, 128.8 };

    const comp = try compareMethods(std.testing.allocator, "Sacred", &method_a_ppl, "Standard", &method_b_ppl, 0.05);

    try std.testing.expect(comp.ppl_a < comp.ppl_b); // Sacred should be better
    try std.testing.expect(comp.significant); // Should be statistically significant
}

test "StepMetrics fromLoss" {
    const metrics = StepMetrics.fromLoss(100, 4.8, 0.001);

    try std.testing.expectEqual(@as(u32, 100), metrics.step);
    try std.testing.expectApproxEqRel(4.8, metrics.loss, 0.01);
    try std.testing.expect(metrics.perplexity > 100);
}

test "NeurIPS table generation" {
    const method_a_ppl = [_]f64{ 125.3, 125.1, 125.5 };
    const method_b_ppl = [_]f64{ 128.7, 128.5, 129.0 };

    const comp = try compareMethods(std.testing.allocator, "Sacred", &method_a_ppl, "Standard", &method_b_ppl, 0.05);

    const comparisons = [_]ComparisonResult{comp};
    const table = try generateNeurIPSTable(std.testing.allocator, &comparisons);
    defer std.testing.allocator.free(table);

    try std.testing.expect(std.mem.indexOf(u8, table, "\\begin{table}") != null);
    try std.testing.expect(std.mem.indexOf(u8, table, "Sacred") != null);
}
