//! META-LEARNER v8.16 — FixType Strategy Tracking
//!
//! Tracks optimal μ for each FixType based on historical success.
//! Learns which mutation rates work best for different error categories.

const std = @import("std");
const diagnostic = @import("diagnostic.zig");
const FixType = diagnostic.FixType;

const Allocator = std.mem.Allocator;

/// Strategy statistics for a single FixType
pub const FixStrategy = struct {
    fix_type: FixType,
    success_count: usize,
    attempt_count: usize,
    avg_confidence: f64,
    last_mu_used: f64,
    optimal_mu: f64,
    total_confidence: f64, // internal accumulator

    /// Calculate success rate for this FixType
    pub fn successRate(self: *const FixStrategy) f64 {
        if (self.attempt_count == 0) return 0.0;
        return @as(f64, @floatFromInt(self.success_count)) / @as(f64, @floatFromInt(self.attempt_count));
    }

    /// Initialize a new strategy
    pub fn init(fix_type: FixType) FixStrategy {
        return FixStrategy{
            .fix_type = fix_type,
            .success_count = 0,
            .attempt_count = 0,
            .avg_confidence = 0.0,
            .last_mu_used = 0.0382,
            .optimal_mu = 0.0382,
            .total_confidence = 0.0,
        };
    }

    /// Record an outcome and update strategy
    pub fn recordOutcome(self: *FixStrategy, success: bool, mu_used: f64, confidence: f64) void {
        self.attempt_count += 1;
        self.last_mu_used = mu_used;

        if (success) {
            self.success_count += 1;
            self.total_confidence += confidence;

            // Update average confidence
            self.avg_confidence = self.total_confidence / @as(f64, @floatFromInt(self.success_count));

            // Adjust optimal μ using exponential moving average
            // If successful with current μ, move optimal μ slightly toward it
            const alpha = 0.1; // Learning rate
            self.optimal_mu = (1.0 - alpha) * self.optimal_mu + alpha * mu_used;
        } else {
            // On failure, increase optimal μ slightly (be more aggressive next time)
            const alpha = 0.05;
            self.optimal_mu = @min(0.1, self.optimal_mu * (1.0 + alpha));
        }
    }

    /// Get recommended μ for next attempt
    pub fn getRecommendedMu(self: *const FixStrategy) f64 {
        // Blend between optimal μ and last μ based on confidence
        const confidence_factor = if (self.attempt_count > 5)
            @min(1.0, self.avg_confidence * 2.0)
        else
            0.5;

        return (1.0 - confidence_factor) * 0.0382 + confidence_factor * self.optimal_mu;
    }
};

/// Meta-learner for all FixType strategies
pub const MetaLearner = struct {
    strategies: [17]FixStrategy,
    init_done: bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !MetaLearner {
        var learner = MetaLearner{
            .strategies = undefined,
            .init_done = false,
            .allocator = allocator,
        };

        // Initialize all 17 FixType strategies
        const fix_types = [_]FixType{
            .SPEC_FIX,
            .GENERATOR_PATCH,
            .TEMPLATE_FIX,
            .IMPORT_FIX,
            .TYPE_FIX,
            .SYNTAX_FIX,
            .UNKNOWN,
            .ALLOCATOR_FIX,
            .ERROR_UNION_FIX,
            .COMPTIME_FIX,
            .VSA_FIX,
            .MEM_FIX,
            .IOPATTERN_FIX,
            .COMPTIME_QUOTA_FIX,
            .UNMANAGED_FIX,
            .TYPEFUNCTION_FIX,
            .INLINE_FIX,
        };

        for (fix_types, 0..) |fix_type, i| {
            learner.strategies[i] = FixStrategy.init(fix_type);
        }

        learner.init_done = true;
        return learner;
    }

    /// Get strategy for a FixType
    pub fn getStrategy(self: *const MetaLearner, fix_type: FixType) *const FixStrategy {
        const index = @intFromEnum(fix_type);
        if (index >= self.strategies.len) return &self.strategies[@intFromEnum(FixType.UNKNOWN)];
        return &self.strategies[index];
    }

    /// Get mutable strategy for a FixType
    pub fn getStrategyMut(self: *MetaLearner, fix_type: FixType) *FixStrategy {
        const index = @intFromEnum(fix_type);
        if (index >= self.strategies.len) return &self.strategies[@intFromEnum(FixType.UNKNOWN)];
        return &self.strategies[index];
    }

    /// Record fix outcome and update strategy
    pub fn recordOutcome(self: *MetaLearner, fix_type: FixType, success: bool, mu_used: f64, confidence: f64) void {
        const strategy = self.getStrategyMut(fix_type);
        strategy.recordOutcome(success, mu_used, confidence);
    }

    /// Get optimal μ for this FixType
    pub fn getOptimalMu(self: *const MetaLearner, fix_type: FixType) f64 {
        const strategy = self.getStrategy(fix_type);
        return strategy.optimal_mu;
    }

    /// Get recommended μ for next attempt with this FixType
    pub fn getRecommendedMu(self: *const MetaLearner, fix_type: FixType) f64 {
        const strategy = self.getStrategy(fix_type);
        return strategy.getRecommendedMu();
    }

    /// Propose new FixType if pattern doesn't match (meta-innovation)
    /// Returns null if confident existing FixType should work
    pub fn proposeNewFixType(self: *const MetaLearner, error_context: []const u8) ?FixType {
        _ = error_context;

        // Find FixType with lowest success rate that has attempts
        var worst_type: ?FixType = null;
        var worst_rate: f64 = 1.0;

        for (self.strategies) |strategy| {
            if (strategy.attempt_count > 0) {
                const rate = strategy.successRate();
                if (rate < worst_rate) {
                    worst_rate = rate;
                    worst_type = strategy.fix_type;
                }
            }
        }

        // If all types have high success, try UNKNOWN (requires manual review)
        if (worst_rate > 0.8) return FixType.UNKNOWN;

        // Otherwise, suggest trying the worst-performing type with different μ
        return worst_type orelse FixType.UNKNOWN;
    }

    /// Export strategies as markdown
    pub fn exportMarkdown(self: *const MetaLearner, writer: anytype) !void {
        try writer.writeAll(
            \\# META-LEARNING STRATEGIES
            \\
            \\| FixType | Success Rate | Optimal μ | Attempts | Avg Confidence |
            \\|---------|--------------|-----------|----------|---------------|
            \\
        );

        for (self.strategies) |strategy| {
            const rate = strategy.successRate();
            const rate_str = if (strategy.attempt_count > 0)
                try std.fmt.allocPrint(self.allocator, "{d:.1}", .{rate * 100.0})
            else
                "N/A";
            defer if (strategy.attempt_count > 0) self.allocator.free(rate_str);

            const fix_name = @tagName(strategy.fix_type);

            try writer.print(
                "| {s} | {s} | {d:.4} | {d} | {d:.2} |\n",
                .{
                    fix_name,
                    rate_str,
                    strategy.optimal_mu,
                    strategy.attempt_count,
                    strategy.avg_confidence,
                },
            );
        }
    }
};

/// Global meta-learner instance
var global_learner: ?MetaLearner = null;
var global_learner_init = false;

/// Get or create global meta-learner
pub fn getGlobalLearner() !*MetaLearner {
    if (!global_learner_init) {
        global_learner = try MetaLearner.init(std.heap.page_allocator);
        global_learner_init = true;
    }
    return &global_learner.?;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "FixStrategy: initialization" {
    const strategy = FixStrategy.init(.TYPE_FIX);

    try std.testing.expectEqual(@as(usize, 0), strategy.success_count);
    try std.testing.expectEqual(@as(usize, 0), strategy.attempt_count);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), strategy.optimal_mu, 0.001);
}

test "FixStrategy: record outcome success" {
    var strategy = FixStrategy.init(.TYPE_FIX);

    strategy.recordOutcome(true, 0.0382, 0.9);
    strategy.recordOutcome(true, 0.04, 0.85);

    try std.testing.expectEqual(@as(usize, 2), strategy.success_count);
    try std.testing.expectEqual(@as(usize, 2), strategy.attempt_count);
    try std.testing.expectApproxEqRel(@as(f64, 0.875), strategy.avg_confidence, 0.01);
}

test "FixStrategy: record outcome failure" {
    var strategy = FixStrategy.init(.TYPE_FIX);

    strategy.recordOutcome(false, 0.0382, 0.0);
    strategy.recordOutcome(true, 0.04, 0.9);

    try std.testing.expectEqual(@as(usize, 1), strategy.success_count);
    try std.testing.expectEqual(@as(usize, 2), strategy.attempt_count);
    try std.testing.expect(strategy.optimal_mu > 0.0382); // Should increase after failure
}

test "FixStrategy: success rate" {
    var strategy = FixStrategy.init(.TYPE_FIX);

    strategy.recordOutcome(true, 0.0382, 0.9);
    strategy.recordOutcome(true, 0.04, 0.85);
    strategy.recordOutcome(false, 0.035, 0.0);

    const rate = strategy.successRate();
    try std.testing.expectApproxEqRel(@as(f64, 0.6667), rate, 0.01);
}

test "MetaLearner: initialization" {
    const allocator = std.testing.allocator;
    var learner = try MetaLearner.init(allocator);

    try std.testing.expect(learner.init_done);

    // All 17 strategies initialized
    const type_fix_strategy = learner.getStrategy(.TYPE_FIX);
    try std.testing.expectEqual(@as(usize, 0), type_fix_strategy.attempt_count);
}

test "MetaLearner: track multiple types" {
    const allocator = std.testing.allocator;
    var learner = try MetaLearner.init(allocator);

    learner.recordOutcome(.TYPE_FIX, true, 0.0382, 0.9);
    learner.recordOutcome(.SYNTAX_FIX, false, 0.0382, 0.0);
    learner.recordOutcome(.TYPE_FIX, true, 0.04, 0.85);

    const type_strategy = learner.getStrategy(.TYPE_FIX);
    try std.testing.expectEqual(@as(usize, 2), type_strategy.attempt_count);
    try std.testing.expectEqual(@as(usize, 2), type_strategy.success_count);

    const syntax_strategy = learner.getStrategy(.SYNTAX_FIX);
    try std.testing.expectEqual(@as(usize, 1), syntax_strategy.attempt_count);
    try std.testing.expectEqual(@as(usize, 0), syntax_strategy.success_count);
}

test "MetaLearner: optimal μ evolves" {
    const allocator = std.testing.allocator;
    var learner = try MetaLearner.init(allocator);

    // Start with baseline
    const initial_mu = learner.getOptimalMu(.TYPE_FIX);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), initial_mu, 0.001);

    // After 10 successful fixes with μ = 0.05, optimal should trend upward
    for (0..10) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.05, 0.9);
    }

    const final_mu = learner.getOptimalMu(.TYPE_FIX);
    try std.testing.expect(final_mu > initial_mu);
}

test "MetaLearner: recommend μ blends optimal and baseline" {
    const allocator = std.testing.allocator;
    var learner = try MetaLearner.init(allocator);

    // With no history, should return baseline
    const rec1 = learner.getRecommendedMu(.TYPE_FIX);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), rec1, 0.001);

    // After successful fixes, should blend toward optimal
    for (0..10) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.045, 0.9);
    }

    const rec2 = learner.getRecommendedMu(.TYPE_FIX);
    // Should be between baseline and optimal
    try std.testing.expect(rec2 > 0.0382);
    try std.testing.expect(rec2 < 0.045);
}
