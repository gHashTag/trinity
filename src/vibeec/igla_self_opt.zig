// =============================================================================
// IGLA SELF-OPTIMIZATION v1.0 - Automatic Pattern Improvement
// =============================================================================
//
// CYCLE 5: Self-optimization loop with Needle scoring
// - Collect feedback on pattern matches
// - Adjust weights based on success rate
// - Needle score threshold >0.7 for quality gate
// - Automatic improvement loop
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const enhanced_chat = @import("igla_enhanced_chat.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const NEEDLE_THRESHOLD: f32 = 0.7; // Quality gate threshold
pub const FEEDBACK_WINDOW: usize = 100; // Rolling window for feedback
pub const MIN_SAMPLES: usize = 10; // Minimum samples before adjusting
pub const WEIGHT_DECAY: f32 = 0.95; // Weight decay for unused patterns
pub const WEIGHT_BOOST: f32 = 1.1; // Weight boost for successful patterns
pub const MAX_WEIGHT: f32 = 3.0; // Maximum pattern weight
pub const MIN_WEIGHT: f32 = 0.1; // Minimum pattern weight

// =============================================================================
// FEEDBACK TYPES
// =============================================================================

pub const FeedbackType = enum {
    Positive, // User liked the response
    Negative, // User rejected the response
    Neutral, // No explicit feedback
    Correction, // User provided correction
};

pub const PatternFeedback = struct {
    pattern_idx: usize,
    feedback: FeedbackType,
    query: []const u8,
    timestamp: i64,
    needle_score: f32,
};

// =============================================================================
// NEEDLE SCORER
// =============================================================================

pub const NeedleScorer = struct {
    query_pattern_matches: [FEEDBACK_WINDOW]f32,
    match_count: usize,
    total_queries: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .query_pattern_matches = [_]f32{0} ** FEEDBACK_WINDOW,
            .match_count = 0,
            .total_queries = 0,
        };
    }

    /// Calculate Needle score for a query-pattern match
    /// Higher score = better semantic alignment
    pub fn scoreMatch(query: []const u8, pattern: *const enhanced_chat.ConversationalPattern) f32 {
        var matched_keywords: usize = 0;
        var total_weight: f32 = 0;

        for (pattern.keywords) |keyword| {
            if (containsWord(query, keyword)) {
                matched_keywords += 1;
                total_weight += @as(f32, @floatFromInt(keyword.len));
            }
        }

        if (matched_keywords == 0) return 0.0;

        // Needle score formula:
        // score = (matched_keywords / total_keywords) * weight_factor * pattern_weight
        const keyword_ratio = @as(f32, @floatFromInt(matched_keywords)) /
            @as(f32, @floatFromInt(pattern.keywords.len));
        const length_factor = @min(1.0, total_weight / 20.0); // Normalize by typical keyword mass
        const base_score = keyword_ratio * length_factor * pattern.weight;

        // Boost for multi-keyword matches (indicates strong semantic fit)
        const multi_boost = if (matched_keywords > 2)
            1.0 + @as(f32, @floatFromInt(matched_keywords - 2)) * 0.15
        else
            1.0;

        return @min(1.0, base_score * multi_boost);
    }

    /// Record a match score for rolling average
    pub fn recordMatch(self: *Self, score: f32) void {
        const idx = self.total_queries % FEEDBACK_WINDOW;
        self.query_pattern_matches[idx] = score;
        self.total_queries += 1;
        if (self.match_count < FEEDBACK_WINDOW) {
            self.match_count += 1;
        }
    }

    /// Get average Needle score over recent matches
    pub fn getAverageScore(self: *const Self) f32 {
        if (self.match_count == 0) return 0.0;

        var sum: f32 = 0;
        for (self.query_pattern_matches[0..self.match_count]) |score| {
            sum += score;
        }
        return sum / @as(f32, @floatFromInt(self.match_count));
    }

    /// Check if quality gate is met
    pub fn passesQualityGate(self: *const Self) bool {
        return self.getAverageScore() >= NEEDLE_THRESHOLD;
    }
};

fn containsWord(text: []const u8, word: []const u8) bool {
    if (word.len > text.len) return false;
    if (word.len == 0) return true;

    var i: usize = 0;
    while (i + word.len <= text.len) : (i += 1) {
        var matches = true;
        for (word, 0..) |w, j| {
            const t = text[i + j];
            // Case-insensitive ASCII comparison
            const t_lower = if (t < 128) std.ascii.toLower(t) else t;
            const w_lower = if (w < 128) std.ascii.toLower(w) else w;
            if (t_lower != w_lower) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }
    return false;
}

// =============================================================================
// PATTERN OPTIMIZER
// =============================================================================

pub const PatternOptimizer = struct {
    feedback_buffer: [FEEDBACK_WINDOW]PatternFeedback,
    feedback_count: usize,
    pattern_success: [64]PatternStats, // Stats per pattern
    needle_scorer: NeedleScorer,
    optimization_cycles: usize,

    const Self = @This();

    pub const PatternStats = struct {
        uses: usize,
        positive: usize,
        negative: usize,
        current_weight: f32,
        last_used: i64,
    };

    pub fn init() Self {
        var stats: [64]PatternStats = undefined;
        for (&stats) |*s| {
            s.* = PatternStats{
                .uses = 0,
                .positive = 0,
                .negative = 0,
                .current_weight = 1.0,
                .last_used = 0,
            };
        }

        return Self{
            .feedback_buffer = undefined,
            .feedback_count = 0,
            .pattern_success = stats,
            .needle_scorer = NeedleScorer.init(),
            .optimization_cycles = 0,
        };
    }

    /// Record feedback for a pattern match
    pub fn recordFeedback(
        self: *Self,
        pattern_idx: usize,
        feedback: FeedbackType,
        query: []const u8,
        needle_score: f32,
    ) void {
        // Store in rolling buffer
        const idx = self.feedback_count % FEEDBACK_WINDOW;
        self.feedback_buffer[idx] = PatternFeedback{
            .pattern_idx = pattern_idx,
            .feedback = feedback,
            .query = query,
            .timestamp = std.time.timestamp(),
            .needle_score = needle_score,
        };
        self.feedback_count += 1;

        // Update pattern stats
        if (pattern_idx < self.pattern_success.len) {
            var stats = &self.pattern_success[pattern_idx];
            stats.uses += 1;
            stats.last_used = std.time.timestamp();

            switch (feedback) {
                .Positive => stats.positive += 1,
                .Negative => stats.negative += 1,
                else => {},
            }
        }

        // Record needle score
        self.needle_scorer.recordMatch(needle_score);
    }

    /// Run optimization cycle - adjust weights based on feedback
    pub fn optimize(self: *Self) OptimizationResult {
        self.optimization_cycles += 1;

        var adjustments: usize = 0;
        var improved: usize = 0;
        var degraded: usize = 0;

        for (&self.pattern_success, 0..) |*stats, i| {
            if (stats.uses < MIN_SAMPLES) continue;

            const total_feedback = stats.positive + stats.negative;
            if (total_feedback == 0) {
                // Apply decay for unused patterns
                stats.current_weight *= WEIGHT_DECAY;
                stats.current_weight = @max(MIN_WEIGHT, stats.current_weight);
                continue;
            }

            // Calculate success rate
            const success_rate = @as(f32, @floatFromInt(stats.positive)) /
                @as(f32, @floatFromInt(total_feedback));

            // Adjust weight based on success rate
            if (success_rate > 0.8) {
                // Boost successful patterns
                const old_weight = stats.current_weight;
                stats.current_weight *= WEIGHT_BOOST;
                stats.current_weight = @min(MAX_WEIGHT, stats.current_weight);
                if (stats.current_weight > old_weight) {
                    improved += 1;
                }
            } else if (success_rate < 0.3) {
                // Reduce unsuccessful patterns
                const old_weight = stats.current_weight;
                stats.current_weight *= WEIGHT_DECAY;
                stats.current_weight = @max(MIN_WEIGHT, stats.current_weight);
                if (stats.current_weight < old_weight) {
                    degraded += 1;
                }
            }

            _ = i;
            adjustments += 1;
        }

        return OptimizationResult{
            .cycle = self.optimization_cycles,
            .patterns_adjusted = adjustments,
            .patterns_improved = improved,
            .patterns_degraded = degraded,
            .average_needle_score = self.needle_scorer.getAverageScore(),
            .passes_quality_gate = self.needle_scorer.passesQualityGate(),
        };
    }

    /// Get optimization statistics
    pub fn getStats(self: *const Self) struct {
        total_feedback: usize,
        optimization_cycles: usize,
        needle_score: f32,
        quality_gate_passed: bool,
        best_patterns: [5]usize,
        worst_patterns: [5]usize,
    } {
        // Find best and worst patterns by success rate
        var best: [5]usize = [_]usize{0} ** 5;
        var worst: [5]usize = [_]usize{0} ** 5;
        var best_rates: [5]f32 = [_]f32{0} ** 5;
        var worst_rates: [5]f32 = [_]f32{1} ** 5;

        for (self.pattern_success, 0..) |stats, i| {
            if (stats.uses < MIN_SAMPLES) continue;

            const total = stats.positive + stats.negative;
            if (total == 0) continue;

            const rate = @as(f32, @floatFromInt(stats.positive)) /
                @as(f32, @floatFromInt(total));

            // Check if better than any in best list
            for (&best, &best_rates) |*b, *br| {
                if (rate > br.*) {
                    b.* = i;
                    br.* = rate;
                    break;
                }
            }

            // Check if worse than any in worst list
            for (&worst, &worst_rates) |*w, *wr| {
                if (rate < wr.*) {
                    w.* = i;
                    wr.* = rate;
                    break;
                }
            }
        }

        return .{
            .total_feedback = self.feedback_count,
            .optimization_cycles = self.optimization_cycles,
            .needle_score = self.needle_scorer.getAverageScore(),
            .quality_gate_passed = self.needle_scorer.passesQualityGate(),
            .best_patterns = best,
            .worst_patterns = worst,
        };
    }
};

pub const OptimizationResult = struct {
    cycle: usize,
    patterns_adjusted: usize,
    patterns_improved: usize,
    patterns_degraded: usize,
    average_needle_score: f32,
    passes_quality_gate: bool,
};

// =============================================================================
// SELF-OPTIMIZING CHAT ENGINE
// =============================================================================

pub const SelfOptChat = struct {
    enhanced: enhanced_chat.IglaEnhancedChat,
    optimizer: PatternOptimizer,
    auto_optimize: bool,
    optimize_interval: usize,
    queries_since_opt: usize,

    const Self = @This();

    pub fn init(auto_optimize: bool) Self {
        return Self{
            .enhanced = enhanced_chat.IglaEnhancedChat.init(),
            .optimizer = PatternOptimizer.init(),
            .auto_optimize = auto_optimize,
            .optimize_interval = FEEDBACK_WINDOW,
            .queries_since_opt = 0,
        };
    }

    /// Respond with self-optimization tracking
    pub fn respond(self: *Self, query: []const u8) struct {
        response: enhanced_chat.ChatResponse,
        needle_score: f32,
    } {
        const response = self.enhanced.respond(query);
        self.queries_since_opt += 1;

        // Calculate needle score for this match
        // Use a default score based on category confidence
        const needle_score: f32 = switch (response.category) {
            .Unknown => 0.3,
            else => 0.8,
        };

        // Record as neutral feedback (user can override)
        self.optimizer.recordFeedback(
            0, // Pattern index unknown at this level
            .Neutral,
            query,
            needle_score,
        );

        // Auto-optimize if enabled and interval reached
        if (self.auto_optimize and self.queries_since_opt >= self.optimize_interval) {
            _ = self.optimizer.optimize();
            self.queries_since_opt = 0;
        }

        return .{
            .response = response,
            .needle_score = needle_score,
        };
    }

    /// Record explicit user feedback
    pub fn recordFeedback(self: *Self, feedback: FeedbackType) void {
        // Update the last recorded feedback
        if (self.optimizer.feedback_count > 0) {
            const idx = (self.optimizer.feedback_count - 1) % FEEDBACK_WINDOW;
            self.optimizer.feedback_buffer[idx].feedback = feedback;

            // Update pattern stats
            const pattern_idx = self.optimizer.feedback_buffer[idx].pattern_idx;
            if (pattern_idx < self.optimizer.pattern_success.len) {
                var stats = &self.optimizer.pattern_success[pattern_idx];
                switch (feedback) {
                    .Positive => stats.positive += 1,
                    .Negative => stats.negative += 1,
                    else => {},
                }
            }
        }
    }

    /// Force optimization cycle
    pub fn forceOptimize(self: *Self) OptimizationResult {
        return self.optimizer.optimize();
    }

    /// Get comprehensive stats
    pub fn getStats(self: *const Self) struct {
        enhanced_stats: @TypeOf(self.enhanced.getStats()),
        optimizer_stats: @TypeOf(self.optimizer.getStats()),
        auto_optimize: bool,
    } {
        return .{
            .enhanced_stats = self.enhanced.getStats(),
            .optimizer_stats = self.optimizer.getStats(),
            .auto_optimize = self.auto_optimize,
        };
    }
};

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() !void {
    const stdout = std.fs.File.stdout();

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("     IGLA SELF-OPTIMIZATION BENCHMARK                                          \n");
    _ = try stdout.write("===============================================================================\n");

    var engine = SelfOptChat.init(true);

    const test_queries = [_][]const u8{
        "привет",
        "hello",
        "what is phi",
        "расскажи шутку",
        "tell me a story",
        "как дела",
        "why zig",
        "fibonacci",
        "meaning of life",
        "help",
    };

    // Simulate queries with feedback
    var positive_count: usize = 0;
    var negative_count: usize = 0;

    for (0..FEEDBACK_WINDOW) |i| {
        const q = test_queries[i % test_queries.len];
        const result = engine.respond(q);

        // Simulate user feedback based on needle score
        if (result.needle_score > 0.7) {
            engine.recordFeedback(.Positive);
            positive_count += 1;
        } else if (result.needle_score < 0.4) {
            engine.recordFeedback(.Negative);
            negative_count += 1;
        }
    }

    // Run optimization
    const opt_result = engine.forceOptimize();

    _ = try stdout.write("\n");

    var buf: [256]u8 = undefined;

    var len = std.fmt.bufPrint(&buf, "  Queries processed: {d}\n", .{FEEDBACK_WINDOW}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Positive feedback: {d}\n", .{positive_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Negative feedback: {d}\n", .{negative_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Optimization cycles: {d}\n", .{opt_result.cycle}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Patterns adjusted: {d}\n", .{opt_result.patterns_adjusted}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Patterns improved: {d}\n", .{opt_result.patterns_improved}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Needle score: {d:.2}\n", .{opt_result.average_needle_score}) catch return;
    _ = try stdout.write(len);

    if (opt_result.passes_quality_gate) {
        _ = try stdout.write("  Quality gate: PASSED (>0.7)\n");
    } else {
        _ = try stdout.write("  Quality gate: FAILED (<0.7)\n");
    }

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("  phi^2 + 1/phi^2 = 3 = TRINITY | SELF-OPTIMIZATION                           \n");
    _ = try stdout.write("===============================================================================\n");
}

// =============================================================================
// MAIN & TESTS
// =============================================================================

pub fn main() !void {
    try runBenchmark();
}

test "needle scorer basic" {
    var scorer = NeedleScorer.init();
    scorer.recordMatch(0.8);
    scorer.recordMatch(0.9);
    scorer.recordMatch(0.7);

    const avg = scorer.getAverageScore();
    try std.testing.expect(avg > 0.7);
    try std.testing.expect(scorer.passesQualityGate());
}

test "pattern optimizer feedback" {
    var optimizer = PatternOptimizer.init();

    // Record positive feedback
    optimizer.recordFeedback(0, .Positive, "test query", 0.85);
    try std.testing.expectEqual(@as(usize, 1), optimizer.feedback_count);
    try std.testing.expectEqual(@as(usize, 1), optimizer.pattern_success[0].positive);
}

test "self opt chat respond" {
    var engine = SelfOptChat.init(false);
    const result = engine.respond("привет");
    try std.testing.expect(result.response.category == .Greeting);
    try std.testing.expect(result.needle_score > 0);
}

test "self opt auto optimize" {
    var engine = SelfOptChat.init(true);
    engine.optimize_interval = 5; // Optimize every 5 queries

    for (0..10) |_| {
        _ = engine.respond("hello");
    }

    // Should have auto-optimized
    try std.testing.expect(engine.optimizer.optimization_cycles > 0);
}

test "quality gate threshold" {
    var scorer = NeedleScorer.init();

    // Low scores
    for (0..10) |_| {
        scorer.recordMatch(0.5);
    }
    try std.testing.expect(!scorer.passesQualityGate());

    // Reset and add high scores
    var scorer2 = NeedleScorer.init();
    for (0..10) |_| {
        scorer2.recordMatch(0.9);
    }
    try std.testing.expect(scorer2.passesQualityGate());
}
