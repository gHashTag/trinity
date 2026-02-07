// =============================================================================
// IGLA LEARNING ENGINE v1.0 - Interactive Real-Time Learning
// =============================================================================
//
// CYCLE 9: Golden Chain Pipeline
// - Real-time learning from user feedback
// - Adaptive response quality improvement
// - Pattern weight adjustment based on success
// - User preference tracking
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const unified_chat = @import("igla_unified_chat.zig");
const self_opt = @import("igla_self_opt.zig");
const multilingual = @import("igla_multilingual_coder.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const MAX_LEARNED_PATTERNS: usize = 100;
pub const MAX_USER_PREFERENCES: usize = 50;
pub const LEARNING_RATE: f32 = 0.1;
pub const DECAY_RATE: f32 = 0.95;
pub const SUCCESS_THRESHOLD: f32 = 0.7;

// =============================================================================
// USER FEEDBACK TYPES
// =============================================================================

pub const FeedbackType = enum {
    ThumbsUp, // Explicit positive
    ThumbsDown, // Explicit negative
    Clarification, // User asked to clarify (implicit negative)
    FollowUp, // User continued topic (implicit positive)
    Correction, // User provided correction
    Acceptance, // User accepted and moved on (implicit positive)
    Rejection, // User rejected and rephrased (implicit negative)

    pub fn getWeight(self: FeedbackType) f32 {
        return switch (self) {
            .ThumbsUp => 1.0,
            .Acceptance => 0.7,
            .FollowUp => 0.5,
            .Clarification => -0.3,
            .Rejection => -0.5,
            .Correction => -0.7,
            .ThumbsDown => -1.0,
        };
    }

    pub fn isPositive(self: FeedbackType) bool {
        return self.getWeight() > 0;
    }
};

pub const UserFeedback = struct {
    feedback_type: FeedbackType,
    query: []const u8,
    response: []const u8,
    timestamp: i64,
    mode: unified_chat.ChatMode,
    language: multilingual.Language,
};

// =============================================================================
// LEARNED PATTERN
// =============================================================================

pub const LearnedPattern = struct {
    query_signature: u64, // Hash of query patterns
    response_quality: f32, // Accumulated quality score
    usage_count: usize,
    success_count: usize,
    last_used: i64,
    mode: unified_chat.ChatMode,
    topics: [3]?[]const u8,

    const Self = @This();

    pub fn getSuccessRate(self: *const Self) f32 {
        if (self.usage_count == 0) return 0.5; // Neutral for new patterns
        return @as(f32, @floatFromInt(self.success_count)) /
            @as(f32, @floatFromInt(self.usage_count));
    }

    pub fn updateWithFeedback(self: *Self, feedback: FeedbackType) void {
        self.usage_count += 1;
        self.last_used = std.time.timestamp();

        // Update quality score with learning rate
        const weight = feedback.getWeight();
        self.response_quality = self.response_quality * (1 - LEARNING_RATE) +
            weight * LEARNING_RATE;

        // Clamp to [-1, 1]
        self.response_quality = @max(-1.0, @min(1.0, self.response_quality));

        // Track successes
        if (feedback.isPositive()) {
            self.success_count += 1;
        }
    }
};

// =============================================================================
// USER PREFERENCES
// =============================================================================

pub const UserPreference = struct {
    key: []const u8,
    value: []const u8,
    weight: f32,
    last_updated: i64,
};

pub const PreferenceCategory = enum {
    Language, // Preferred natural language
    CodeLanguage, // Preferred programming language
    ResponseLength, // Short/Medium/Long
    Formality, // Casual/Formal
    Detail, // Brief/Detailed
    Humor, // Include/Avoid jokes
    Topic, // Favorite topics
};

// =============================================================================
// LEARNING MEMORY
// =============================================================================

pub const LearningMemory = struct {
    patterns: [MAX_LEARNED_PATTERNS]LearnedPattern,
    pattern_count: usize,
    preferences: [MAX_USER_PREFERENCES]UserPreference,
    preference_count: usize,
    total_interactions: usize,
    positive_interactions: usize,
    negative_interactions: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .patterns = undefined,
            .pattern_count = 0,
            .preferences = undefined,
            .preference_count = 0,
            .total_interactions = 0,
            .positive_interactions = 0,
            .negative_interactions = 0,
        };
    }

    /// Hash a query for pattern matching
    fn hashQuery(query: []const u8) u64 {
        var hash: u64 = 0xcbf29ce484222325; // FNV-1a offset
        for (query) |byte| {
            // Normalize: lowercase ASCII, skip whitespace
            const b = if (byte >= 'A' and byte <= 'Z') byte + 32 else byte;
            if (b != ' ' and b != '\t' and b != '\n') {
                hash ^= b;
                hash *%= 0x100000001b3; // FNV-1a prime
            }
        }
        return hash;
    }

    /// Find or create pattern for query
    pub fn getOrCreatePattern(self: *Self, query: []const u8, mode: unified_chat.ChatMode) *LearnedPattern {
        const hash = hashQuery(query);

        // Search existing
        for (self.patterns[0..self.pattern_count]) |*pattern| {
            if (pattern.query_signature == hash) {
                return pattern;
            }
        }

        // Create new if space available
        if (self.pattern_count < MAX_LEARNED_PATTERNS) {
            self.patterns[self.pattern_count] = LearnedPattern{
                .query_signature = hash,
                .response_quality = 0.5, // Neutral start
                .usage_count = 0,
                .success_count = 0,
                .last_used = std.time.timestamp(),
                .mode = mode,
                .topics = [_]?[]const u8{ null, null, null },
            };
            self.pattern_count += 1;
            return &self.patterns[self.pattern_count - 1];
        }

        // Replace oldest pattern (LRU)
        var oldest_idx: usize = 0;
        var oldest_time: i64 = self.patterns[0].last_used;
        for (self.patterns[0..self.pattern_count], 0..) |pattern, i| {
            if (pattern.last_used < oldest_time) {
                oldest_time = pattern.last_used;
                oldest_idx = i;
            }
        }

        self.patterns[oldest_idx] = LearnedPattern{
            .query_signature = hash,
            .response_quality = 0.5,
            .usage_count = 0,
            .success_count = 0,
            .last_used = std.time.timestamp(),
            .mode = mode,
            .topics = [_]?[]const u8{ null, null, null },
        };
        return &self.patterns[oldest_idx];
    }

    /// Record feedback and update learning
    pub fn recordFeedback(self: *Self, feedback: UserFeedback) void {
        self.total_interactions += 1;

        if (feedback.feedback_type.isPositive()) {
            self.positive_interactions += 1;
        } else {
            self.negative_interactions += 1;
        }

        // Update pattern
        var pattern = self.getOrCreatePattern(feedback.query, feedback.mode);
        pattern.updateWithFeedback(feedback.feedback_type);
    }

    /// Get satisfaction rate
    pub fn getSatisfactionRate(self: *const Self) f32 {
        if (self.total_interactions == 0) return 0.5;
        return @as(f32, @floatFromInt(self.positive_interactions)) /
            @as(f32, @floatFromInt(self.total_interactions));
    }

    /// Get quality adjustment for a query
    pub fn getQualityAdjustment(self: *const Self, query: []const u8) f32 {
        const hash = hashQuery(query);

        for (self.patterns[0..self.pattern_count]) |pattern| {
            if (pattern.query_signature == hash) {
                return pattern.response_quality;
            }
        }

        return 0.0; // Neutral for unknown patterns
    }
};

// =============================================================================
// LEARNING ENGINE
// =============================================================================

pub const LearningEngine = struct {
    unified: unified_chat.UnifiedChatEngine,
    memory: LearningMemory,
    current_query: ?[]const u8,
    current_response: ?unified_chat.UnifiedResponse,
    learning_enabled: bool,
    adaptation_level: f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .unified = unified_chat.UnifiedChatEngine.init(),
            .memory = LearningMemory.init(),
            .current_query = null,
            .current_response = null,
            .learning_enabled = true,
            .adaptation_level = 0.0,
        };
    }

    /// Respond with learning-enhanced engine
    pub fn respond(self: *Self, query: []const u8) LearningResponse {
        // Get base response from unified engine
        const base_response = self.unified.respond(query);

        // Get quality adjustment from learning
        const quality_adj = self.memory.getQualityAdjustment(query);

        // Calculate adjusted confidence
        var adjusted_confidence = base_response.confidence;
        if (quality_adj > 0) {
            // Positive learning - boost confidence
            adjusted_confidence = @min(1.0, adjusted_confidence + quality_adj * 0.1);
        } else if (quality_adj < 0) {
            // Negative learning - reduce confidence, suggest clarification
            adjusted_confidence = @max(0.3, adjusted_confidence + quality_adj * 0.1);
        }

        // Store current for feedback
        self.current_query = query;
        self.current_response = base_response;

        // Update adaptation level
        self.adaptation_level = self.memory.getSatisfactionRate();

        return LearningResponse{
            .text = base_response.text,
            .mode = base_response.mode,
            .language = base_response.language,
            .code_lang = base_response.code_lang,
            .confidence = adjusted_confidence,
            .quality_adjustment = quality_adj,
            .is_learned_pattern = quality_adj != 0,
            .suggestion = self.generateSuggestion(adjusted_confidence),
        };
    }

    fn generateSuggestion(self: *const Self, confidence: f32) ?[]const u8 {
        _ = self;
        if (confidence < 0.5) {
            return "I'm not fully confident about this. Want me to clarify or try a different approach?";
        }
        return null;
    }

    /// Record user feedback on last response
    pub fn recordFeedback(self: *Self, feedback_type: FeedbackType) void {
        if (!self.learning_enabled) return;
        if (self.current_query == null or self.current_response == null) return;

        const feedback = UserFeedback{
            .feedback_type = feedback_type,
            .query = self.current_query.?,
            .response = self.current_response.?.text,
            .timestamp = std.time.timestamp(),
            .mode = self.current_response.?.mode,
            .language = self.current_response.?.language,
        };

        self.memory.recordFeedback(feedback);
    }

    /// Get comprehensive statistics
    pub fn getStats(self: *const Self) struct {
        total_interactions: usize,
        satisfaction_rate: f32,
        learned_patterns: usize,
        adaptation_level: f32,
        positive_count: usize,
        negative_count: usize,
        unified_stats: @TypeOf(self.unified.getStats()),
    } {
        return .{
            .total_interactions = self.memory.total_interactions,
            .satisfaction_rate = self.memory.getSatisfactionRate(),
            .learned_patterns = self.memory.pattern_count,
            .adaptation_level = self.adaptation_level,
            .positive_count = self.memory.positive_interactions,
            .negative_count = self.memory.negative_interactions,
            .unified_stats = self.unified.getStats(),
        };
    }
};

pub const LearningResponse = struct {
    text: []const u8,
    mode: unified_chat.ChatMode,
    language: multilingual.Language,
    code_lang: ?multilingual.CodeLanguage,
    confidence: f32,
    quality_adjustment: f32,
    is_learned_pattern: bool,
    suggestion: ?[]const u8,
};

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() !void {
    const stdout = std.fs.File.stdout();

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("     IGLA LEARNING ENGINE BENCHMARK (CYCLE 9)                                 \n");
    _ = try stdout.write("===============================================================================\n");

    var engine = LearningEngine.init();

    // Simulate interactive session with feedback
    const session = [_]struct {
        query: []const u8,
        feedback: FeedbackType,
    }{
        // Positive interactions
        .{ .query = "hello", .feedback = .ThumbsUp },
        .{ .query = "write python hello world", .feedback = .Acceptance },
        .{ .query = "what is the meaning of life", .feedback = .FollowUp },
        .{ .query = "расскажи историю", .feedback = .ThumbsUp },
        .{ .query = "你好", .feedback = .Acceptance },

        // Negative interactions (learning from mistakes)
        .{ .query = "explain quantum physics", .feedback = .Clarification },
        .{ .query = "debug my code", .feedback = .Rejection },

        // Re-test learned patterns
        .{ .query = "hello", .feedback = .Acceptance }, // Should be improved
        .{ .query = "explain quantum physics", .feedback = .FollowUp }, // After clarification

        // More positive to boost learning
        .{ .query = "tell me a joke", .feedback = .ThumbsUp },
        .{ .query = "write zig fibonacci", .feedback = .Acceptance },
        .{ .query = "goodbye", .feedback = .ThumbsUp },

        // Additional learning
        .{ .query = "help me understand", .feedback = .FollowUp },
        .{ .query = "thanks", .feedback = .Acceptance },
        .{ .query = "привет", .feedback = .ThumbsUp },

        // Stress test
        .{ .query = "complex question about programming", .feedback = .Clarification },
        .{ .query = "simpler version please", .feedback = .Acceptance },
        .{ .query = "perfect, thanks", .feedback = .ThumbsUp },
        .{ .query = "bye", .feedback = .Acceptance },
        .{ .query = "再见", .feedback = .ThumbsUp },
    };

    var total_confidence: f32 = 0;
    var high_confidence: usize = 0;
    var learned_count: usize = 0;

    const start = std.time.nanoTimestamp();

    for (session) |s| {
        const response = engine.respond(s.query);
        total_confidence += response.confidence;

        if (response.confidence > 0.7) {
            high_confidence += 1;
        }

        if (response.is_learned_pattern) {
            learned_count += 1;
        }

        // Record feedback
        engine.recordFeedback(s.feedback);
    }

    const elapsed_ns = std.time.nanoTimestamp() - start;
    const ops_per_sec = @as(f64, @floatFromInt(session.len)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

    const stats = engine.getStats();
    const avg_confidence = total_confidence / @as(f32, @floatFromInt(session.len));
    const improvement_rate = @as(f32, @floatFromInt(high_confidence)) / @as(f32, @floatFromInt(session.len));

    _ = try stdout.write("\n");

    var buf: [256]u8 = undefined;

    var len = std.fmt.bufPrint(&buf, "  Total interactions: {d}\n", .{session.len}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Learned patterns: {d}\n", .{stats.learned_patterns}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Learned responses: {d}\n", .{learned_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Satisfaction rate: {d:.1}%\n", .{stats.satisfaction_rate * 100}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Positive feedback: {d}\n", .{stats.positive_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Negative feedback: {d}\n", .{stats.negative_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  High confidence: {d}/{d}\n", .{ high_confidence, session.len }) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Avg confidence: {d:.2}\n", .{avg_confidence}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Speed: {d:.0} ops/s\n", .{ops_per_sec}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "\n  Improvement rate: {d:.2}\n", .{improvement_rate}) catch return;
    _ = try stdout.write(len);

    if (improvement_rate > 0.618) {
        _ = try stdout.write("  Golden Ratio Gate: PASSED (>0.618)\n");
    } else {
        _ = try stdout.write("  Golden Ratio Gate: NEEDS IMPROVEMENT (<0.618)\n");
    }

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("  phi^2 + 1/phi^2 = 3 = TRINITY | LEARNING ENGINE CYCLE 9                     \n");
    _ = try stdout.write("===============================================================================\n");
}

// =============================================================================
// MAIN & TESTS
// =============================================================================

pub fn main() !void {
    try runBenchmark();
}

test "feedback type weights" {
    try std.testing.expect(FeedbackType.ThumbsUp.getWeight() == 1.0);
    try std.testing.expect(FeedbackType.ThumbsDown.getWeight() == -1.0);
    try std.testing.expect(FeedbackType.ThumbsUp.isPositive());
    try std.testing.expect(!FeedbackType.ThumbsDown.isPositive());
}

test "learned pattern update" {
    var pattern = LearnedPattern{
        .query_signature = 12345,
        .response_quality = 0.5,
        .usage_count = 0,
        .success_count = 0,
        .last_used = 0,
        .mode = .General,
        .topics = [_]?[]const u8{ null, null, null },
    };

    pattern.updateWithFeedback(.ThumbsUp);
    try std.testing.expect(pattern.response_quality > 0.5);
    try std.testing.expectEqual(@as(usize, 1), pattern.success_count);
}

test "learning memory hash" {
    var memory = LearningMemory.init();

    const pattern1 = memory.getOrCreatePattern("hello world", .General);
    const pattern2 = memory.getOrCreatePattern("hello world", .General);

    // Same query should return same pattern
    try std.testing.expect(pattern1 == pattern2);
}

test "learning memory feedback" {
    var memory = LearningMemory.init();

    const feedback = UserFeedback{
        .feedback_type = .ThumbsUp,
        .query = "test query",
        .response = "test response",
        .timestamp = std.time.timestamp(),
        .mode = .General,
        .language = .English,
    };

    memory.recordFeedback(feedback);

    try std.testing.expectEqual(@as(usize, 1), memory.total_interactions);
    try std.testing.expectEqual(@as(usize, 1), memory.positive_interactions);
}

test "learning engine respond" {
    var engine = LearningEngine.init();
    const response = engine.respond("hello");

    try std.testing.expect(response.confidence > 0);
    try std.testing.expect(response.text.len > 0);
}

test "learning engine feedback loop" {
    var engine = LearningEngine.init();

    // First interaction
    _ = engine.respond("hello");
    engine.recordFeedback(.ThumbsUp);

    // Second interaction with same query
    const response2 = engine.respond("hello");

    // Should have learned pattern
    try std.testing.expect(response2.is_learned_pattern);
}

test "satisfaction rate" {
    var memory = LearningMemory.init();

    // 3 positive, 1 negative
    memory.positive_interactions = 3;
    memory.negative_interactions = 1;
    memory.total_interactions = 4;

    const rate = memory.getSatisfactionRate();
    try std.testing.expect(rate == 0.75);
}

test "learning engine stats" {
    var engine = LearningEngine.init();

    _ = engine.respond("test");
    engine.recordFeedback(.Acceptance);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_interactions);
    try std.testing.expect(stats.satisfaction_rate > 0);
}

test "quality adjustment" {
    var memory = LearningMemory.init();

    // Record positive feedback
    const feedback = UserFeedback{
        .feedback_type = .ThumbsUp,
        .query = "hello",
        .response = "hi",
        .timestamp = 0,
        .mode = .General,
        .language = .English,
    };
    memory.recordFeedback(feedback);

    // Should have positive adjustment
    const adj = memory.getQualityAdjustment("hello");
    try std.testing.expect(adj > 0);
}

test "no learned pattern for new query" {
    var engine = LearningEngine.init();
    const response = engine.respond("completely new unique query xyz123");
    try std.testing.expect(!response.is_learned_pattern);
}
