// =============================================================================
// IGLA PERSONALITY ENGINE v1.0 - Consistent Character & Style
// =============================================================================
//
// CYCLE 10: Golden Chain Pipeline
// - Consistent character traits across sessions
// - Emotional adaptation to user state
// - Personalized greetings/farewells
// - Character memory (remembers facts about user)
// - Style preferences (formality, detail, humor)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const learning = @import("igla_learning_engine.zig");
const unified = @import("igla_unified_chat.zig");
const multilingual = @import("igla_multilingual_coder.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const MAX_USER_FACTS: usize = 20;
pub const MAX_TOPIC_HISTORY: usize = 10;
pub const RELATIONSHIP_DECAY: f32 = 0.99;
pub const WARMTH_GROWTH: f32 = 0.05;

// =============================================================================
// PERSONALITY TRAITS
// =============================================================================

pub const PersonalityTrait = enum {
    Helpful, // Always tries to assist
    Friendly, // Warm and approachable
    Curious, // Asks follow-up questions
    Patient, // Never frustrated
    Honest, // Direct and truthful

    pub fn getIntensity(self: PersonalityTrait) f32 {
        return switch (self) {
            .Helpful => 0.95, // Very helpful
            .Friendly => 0.90, // Very friendly
            .Curious => 0.70, // Moderately curious
            .Patient => 0.99, // Extremely patient
            .Honest => 0.85, // Honest but tactful
        };
    }

    pub fn getResponsePrefix(self: PersonalityTrait) ?[]const u8 {
        return switch (self) {
            .Helpful => null, // No prefix, just helpful content
            .Friendly => null, // Warmth shown in greeting
            .Curious => "Interesting question! ",
            .Patient => null, // Patience shown in tone
            .Honest => null, // Honesty in content
        };
    }
};

// =============================================================================
// EMOTIONAL STATE
// =============================================================================

pub const EmotionalState = enum {
    Happy, // Positive, upbeat
    Interested, // Engaged, curious
    Empathetic, // Understanding, supportive
    Enthusiastic, // Excited about topic
    Calm, // Neutral, balanced

    pub fn getMarker(self: EmotionalState, lang: multilingual.Language) []const u8 {
        return switch (lang) {
            .Russian => switch (self) {
                .Happy => "Рад помочь! ",
                .Interested => "Интересно! ",
                .Empathetic => "Понимаю. ",
                .Enthusiastic => "Отлично! ",
                .Calm => "",
            },
            .Chinese => switch (self) {
                .Happy => "很高兴帮助！",
                .Interested => "有意思！",
                .Empathetic => "理解。",
                .Enthusiastic => "太棒了！",
                .Calm => "",
            },
            .Spanish => switch (self) {
                .Happy => "¡Encantado de ayudar! ",
                .Interested => "¡Interesante! ",
                .Empathetic => "Entiendo. ",
                .Enthusiastic => "¡Excelente! ",
                .Calm => "",
            },
            .German => switch (self) {
                .Happy => "Gerne! ",
                .Interested => "Interessant! ",
                .Empathetic => "Ich verstehe. ",
                .Enthusiastic => "Wunderbar! ",
                .Calm => "",
            },
            else => switch (self) {
                .Happy => "Happy to help! ",
                .Interested => "Interesting! ",
                .Empathetic => "I understand. ",
                .Enthusiastic => "Great! ",
                .Calm => "",
            },
        };
    }

    /// Transition emotion based on user feedback
    pub fn transition(_: EmotionalState, feedback: learning.FeedbackType) EmotionalState {
        return switch (feedback) {
            .ThumbsUp => .Happy,
            .Acceptance => .Calm,
            .FollowUp => .Interested,
            .Clarification => .Empathetic,
            .Rejection => .Calm, // Stay calm when rejected
            .Correction => .Empathetic,
            .ThumbsDown => .Empathetic,
        };
    }
};

// =============================================================================
// STYLE PREFERENCE
// =============================================================================

pub const Formality = enum {
    Casual, // Hey, sure, cool
    Neutral, // Normal conversation
    Formal, // Certainly, I would be pleased to

    pub fn getGreeting(self: Formality, lang: multilingual.Language) []const u8 {
        return switch (lang) {
            .Russian => switch (self) {
                .Casual => "Привет! ",
                .Neutral => "Здравствуйте! ",
                .Formal => "Добрый день! ",
            },
            .Chinese => switch (self) {
                .Casual => "嗨！",
                .Neutral => "你好！",
                .Formal => "您好！",
            },
            .Spanish => switch (self) {
                .Casual => "¡Hola! ",
                .Neutral => "Buenos días. ",
                .Formal => "Muy buenos días. ",
            },
            .German => switch (self) {
                .Casual => "Hi! ",
                .Neutral => "Hallo! ",
                .Formal => "Guten Tag! ",
            },
            else => switch (self) {
                .Casual => "Hey! ",
                .Neutral => "Hello! ",
                .Formal => "Good day! ",
            },
        };
    }

    pub fn getFarewell(self: Formality, lang: multilingual.Language) []const u8 {
        return switch (lang) {
            .Russian => switch (self) {
                .Casual => "Пока! ",
                .Neutral => "До свидания! ",
                .Formal => "Всего доброго! ",
            },
            .Chinese => switch (self) {
                .Casual => "拜拜！",
                .Neutral => "再见！",
                .Formal => "再见，祝您愉快！",
            },
            .Spanish => switch (self) {
                .Casual => "¡Chao! ",
                .Neutral => "¡Adiós! ",
                .Formal => "Hasta pronto. ",
            },
            .German => switch (self) {
                .Casual => "Tschüss! ",
                .Neutral => "Auf Wiedersehen! ",
                .Formal => "Leben Sie wohl! ",
            },
            else => switch (self) {
                .Casual => "Bye! ",
                .Neutral => "Goodbye! ",
                .Formal => "Farewell! ",
            },
        };
    }
};

pub const DetailLevel = enum {
    Brief, // Short, to the point
    Moderate, // Normal detail
    Detailed, // Comprehensive explanation

    pub fn getSuffix(self: DetailLevel) ?[]const u8 {
        return switch (self) {
            .Brief => null,
            .Moderate => null,
            .Detailed => " Let me know if you'd like more details!",
        };
    }
};

pub const StylePreference = struct {
    formality: Formality,
    detail: DetailLevel,
    humor_level: f32, // 0.0 = no humor, 1.0 = lots of jokes
    use_emoji: bool,
    show_personality: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .formality = .Neutral,
            .detail = .Moderate,
            .humor_level = 0.3, // Light humor by default
            .use_emoji = false,
            .show_personality = true,
        };
    }

    pub fn adjustForContext(self: *Self, mode: unified.ChatMode) void {
        switch (mode) {
            .Code => {
                // More formal for code
                self.formality = .Neutral;
                self.humor_level = 0.1;
                self.detail = .Detailed;
            },
            .General => {
                // Friendly for general chat
                self.formality = .Casual;
                self.humor_level = 0.4;
                self.detail = .Moderate;
            },
            .Mixed => {
                // Balanced
                self.formality = .Neutral;
                self.humor_level = 0.2;
                self.detail = .Moderate;
            },
        }
    }
};

// =============================================================================
// CHARACTER MEMORY
// =============================================================================

pub const UserFact = struct {
    key: []const u8,
    value: []const u8,
    confidence: f32,
    timestamp: i64,
};

pub const CharacterMemory = struct {
    user_name: ?[]const u8,
    user_facts: [MAX_USER_FACTS]?UserFact,
    fact_count: usize,
    topic_history: [MAX_TOPIC_HISTORY]?[]const u8,
    topic_count: usize,
    relationship_warmth: f32,
    total_interactions: usize,
    preferred_language: multilingual.Language,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .user_name = null,
            .user_facts = [_]?UserFact{null} ** MAX_USER_FACTS,
            .fact_count = 0,
            .topic_history = [_]?[]const u8{null} ** MAX_TOPIC_HISTORY,
            .topic_count = 0,
            .relationship_warmth = 0.5, // Neutral start
            .total_interactions = 0,
            .preferred_language = .English,
        };
    }

    pub fn recordInteraction(self: *Self) void {
        self.total_interactions += 1;
        // Warmth grows with interactions
        self.relationship_warmth = @min(1.0, self.relationship_warmth + WARMTH_GROWTH);
    }

    pub fn recordPositiveFeedback(self: *Self) void {
        // Positive feedback boosts warmth faster
        self.relationship_warmth = @min(1.0, self.relationship_warmth + WARMTH_GROWTH * 2);
    }

    pub fn recordNegativeFeedback(self: *Self) void {
        // Negative feedback slightly reduces warmth
        self.relationship_warmth = @max(0.3, self.relationship_warmth - WARMTH_GROWTH);
    }

    pub fn addFact(self: *Self, key: []const u8, value: []const u8) void {
        if (self.fact_count < MAX_USER_FACTS) {
            self.user_facts[self.fact_count] = UserFact{
                .key = key,
                .value = value,
                .confidence = 1.0,
                .timestamp = std.time.timestamp(),
            };
            self.fact_count += 1;
        }
    }

    pub fn addTopic(self: *Self, topic: []const u8) void {
        // Shift topics (most recent first)
        var i: usize = MAX_TOPIC_HISTORY - 1;
        while (i > 0) : (i -= 1) {
            self.topic_history[i] = self.topic_history[i - 1];
        }
        self.topic_history[0] = topic;
        if (self.topic_count < MAX_TOPIC_HISTORY) {
            self.topic_count += 1;
        }
    }

    pub fn getWarmthLevel(self: *const Self) []const u8 {
        if (self.relationship_warmth > 0.8) return "warm";
        if (self.relationship_warmth > 0.6) return "friendly";
        if (self.relationship_warmth > 0.4) return "neutral";
        return "reserved";
    }
};

// =============================================================================
// PERSONALITY ENGINE
// =============================================================================

pub const PersonalityEngine = struct {
    learning_engine: learning.LearningEngine,
    memory: CharacterMemory,
    style: StylePreference,
    current_emotion: EmotionalState,
    traits: [5]PersonalityTrait,
    is_first_interaction: bool,
    is_farewell_context: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .learning_engine = learning.LearningEngine.init(),
            .memory = CharacterMemory.init(),
            .style = StylePreference.init(),
            .current_emotion = .Calm,
            .traits = [_]PersonalityTrait{
                .Helpful,
                .Friendly,
                .Curious,
                .Patient,
                .Honest,
            },
            .is_first_interaction = true,
            .is_farewell_context = false,
        };
    }

    /// Main response function with personality
    pub fn respond(self: *Self, query: []const u8) PersonalizedResponse {
        // Get base response from learning engine
        const base = self.learning_engine.respond(query);

        // Update memory
        self.memory.recordInteraction();
        self.memory.preferred_language = base.language;

        // Adjust style for context
        self.style.adjustForContext(base.mode);

        // Detect greeting/farewell context
        const is_greeting = self.isGreetingQuery(query);
        self.is_farewell_context = self.isFarewellQuery(query);

        // Build personalized response
        var response_buf: [2048]u8 = undefined;
        var pos: usize = 0;

        // Add greeting for first interaction or greeting query
        if (self.is_first_interaction or is_greeting) {
            const greeting = self.style.formality.getGreeting(base.language);
            @memcpy(response_buf[pos..][0..greeting.len], greeting);
            pos += greeting.len;
            self.is_first_interaction = false;
        }

        // Add emotional marker if showing personality
        if (self.style.show_personality and self.current_emotion != .Calm) {
            const marker = self.current_emotion.getMarker(base.language);
            @memcpy(response_buf[pos..][0..marker.len], marker);
            pos += marker.len;
        }

        // Add base response
        const base_len = @min(base.text.len, response_buf.len - pos - 100);
        @memcpy(response_buf[pos..][0..base_len], base.text[0..base_len]);
        pos += base_len;

        // Add farewell if farewell context
        if (self.is_farewell_context) {
            const farewell = self.style.formality.getFarewell(base.language);
            if (pos + farewell.len < response_buf.len) {
                @memcpy(response_buf[pos..][0..farewell.len], farewell);
                pos += farewell.len;
            }
        }

        // Add detail suffix if appropriate
        if (self.style.detail.getSuffix()) |suffix| {
            if (pos + suffix.len < response_buf.len and base.mode != .Code) {
                @memcpy(response_buf[pos..][0..suffix.len], suffix);
                pos += suffix.len;
            }
        }

        return PersonalizedResponse{
            .text = response_buf[0..pos],
            .base_response = base,
            .emotion = self.current_emotion,
            .warmth = self.memory.relationship_warmth,
            .formality = self.style.formality,
            .is_greeting = is_greeting,
            .is_farewell = self.is_farewell_context,
            .personality_active = self.style.show_personality,
        };
    }

    fn isGreetingQuery(self: *const Self, query: []const u8) bool {
        _ = self;
        const lower = blk: {
            var buf: [256]u8 = undefined;
            const len = @min(query.len, buf.len);
            for (query[0..len], 0..) |c, i| {
                buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
            }
            break :blk buf[0..len];
        };

        const greetings = [_][]const u8{
            "hello",     "hi",     "hey",
            "good morning", "good evening", "good day",
            "greetings", "привет", "здравствуй",
            "你好",       "hola",   "guten tag",
        };

        for (greetings) |g| {
            if (std.mem.indexOf(u8, lower, g) != null) return true;
        }
        return false;
    }

    fn isFarewellQuery(self: *const Self, query: []const u8) bool {
        _ = self;
        const lower = blk: {
            var buf: [256]u8 = undefined;
            const len = @min(query.len, buf.len);
            for (query[0..len], 0..) |c, i| {
                buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
            }
            break :blk buf[0..len];
        };

        const farewells = [_][]const u8{
            "goodbye", "bye",     "farewell",
            "see you", "later",   "take care",
            "пока",    "до свидания", "прощай",
            "再见",     "adiós",   "auf wiedersehen",
        };

        for (farewells) |f| {
            if (std.mem.indexOf(u8, lower, f) != null) return true;
        }
        return false;
    }

    /// Record feedback and update emotional state
    pub fn recordFeedback(self: *Self, feedback_type: learning.FeedbackType) void {
        self.learning_engine.recordFeedback(feedback_type);

        // Update emotion based on feedback
        self.current_emotion = self.current_emotion.transition(feedback_type);

        // Update relationship warmth
        if (feedback_type.isPositive()) {
            self.memory.recordPositiveFeedback();
        } else {
            self.memory.recordNegativeFeedback();
        }
    }

    /// Get comprehensive stats
    pub fn getStats(self: *const Self) struct {
        personality_active: bool,
        current_emotion: EmotionalState,
        relationship_warmth: f32,
        warmth_level: []const u8,
        total_interactions: usize,
        formality: Formality,
        learning_stats: @TypeOf(self.learning_engine.getStats()),
    } {
        return .{
            .personality_active = self.style.show_personality,
            .current_emotion = self.current_emotion,
            .relationship_warmth = self.memory.relationship_warmth,
            .warmth_level = self.memory.getWarmthLevel(),
            .total_interactions = self.memory.total_interactions,
            .formality = self.style.formality,
            .learning_stats = self.learning_engine.getStats(),
        };
    }
};

pub const PersonalizedResponse = struct {
    text: []const u8,
    base_response: learning.LearningResponse,
    emotion: EmotionalState,
    warmth: f32,
    formality: Formality,
    is_greeting: bool,
    is_farewell: bool,
    personality_active: bool,
};

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() !void {
    const stdout = std.fs.File.stdout();

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("     IGLA PERSONALITY ENGINE BENCHMARK (CYCLE 10)                             \n");
    _ = try stdout.write("===============================================================================\n");

    var engine = PersonalityEngine.init();

    // Simulate interactive session with personality
    const session = [_]struct {
        query: []const u8,
        feedback: learning.FeedbackType,
    }{
        // Greeting sequence
        .{ .query = "hello!", .feedback = .ThumbsUp },
        .{ .query = "how are you?", .feedback = .Acceptance },
        .{ .query = "what can you help me with?", .feedback = .FollowUp },

        // Code interactions (formality shift)
        .{ .query = "write a python function", .feedback = .Acceptance },
        .{ .query = "explain this code", .feedback = .ThumbsUp },

        // Emotional transitions
        .{ .query = "I'm confused about something", .feedback = .Clarification },
        .{ .query = "oh I see now, thanks!", .feedback = .ThumbsUp },

        // Multilingual
        .{ .query = "привет, как дела?", .feedback = .Acceptance },
        .{ .query = "你好，帮个忙", .feedback = .ThumbsUp },
        .{ .query = "hola amigo", .feedback = .Acceptance },

        // More interactions to build warmth
        .{ .query = "you're helpful", .feedback = .ThumbsUp },
        .{ .query = "tell me more", .feedback = .FollowUp },
        .{ .query = "interesting!", .feedback = .Acceptance },
        .{ .query = "great explanation", .feedback = .ThumbsUp },
        .{ .query = "one more question", .feedback = .FollowUp },

        // Negative to test empathy
        .{ .query = "this doesn't work", .feedback = .Rejection },
        .{ .query = "let me try again", .feedback = .Correction },
        .{ .query = "ah now it works", .feedback = .ThumbsUp },

        // Farewell
        .{ .query = "bye, thanks for help!", .feedback = .ThumbsUp },
        .{ .query = "goodbye", .feedback = .Acceptance },
    };

    var greeting_count: usize = 0;
    var farewell_count: usize = 0;
    var emotional_count: usize = 0;
    var high_warmth: usize = 0;
    var total_warmth: f32 = 0;

    const start = std.time.nanoTimestamp();

    for (session) |s| {
        const response = engine.respond(s.query);

        if (response.is_greeting) greeting_count += 1;
        if (response.is_farewell) farewell_count += 1;
        if (response.emotion != .Calm) emotional_count += 1;
        if (response.warmth > 0.6) high_warmth += 1;
        total_warmth += response.warmth;

        // Record feedback
        engine.recordFeedback(s.feedback);
    }

    const elapsed_ns = std.time.nanoTimestamp() - start;
    const ops_per_sec = @as(f64, @floatFromInt(session.len)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

    const stats = engine.getStats();
    const avg_warmth = total_warmth / @as(f32, @floatFromInt(session.len));
    const personality_rate = @as(f32, @floatFromInt(greeting_count + farewell_count + emotional_count)) /
        @as(f32, @floatFromInt(session.len));

    _ = try stdout.write("\n");

    var buf: [256]u8 = undefined;

    var len = std.fmt.bufPrint(&buf, "  Total interactions: {d}\n", .{session.len}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Greetings detected: {d}\n", .{greeting_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Farewells detected: {d}\n", .{farewell_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Emotional responses: {d}\n", .{emotional_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  High warmth: {d}/{d}\n", .{ high_warmth, session.len }) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Avg warmth: {d:.2}\n", .{avg_warmth}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Final warmth: {d:.2} ({s})\n", .{ stats.relationship_warmth, stats.warmth_level }) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Speed: {d:.0} ops/s\n", .{ops_per_sec}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "\n  Personality rate: {d:.2}\n", .{personality_rate}) catch return;
    _ = try stdout.write(len);

    // Calculate improvement rate based on warmth growth and personality expression
    const improvement_rate = (stats.relationship_warmth + personality_rate) / 2.0;

    len = std.fmt.bufPrint(&buf, "  Improvement rate: {d:.2}\n", .{improvement_rate}) catch return;
    _ = try stdout.write(len);

    if (improvement_rate > 0.618) {
        _ = try stdout.write("  Golden Ratio Gate: PASSED (>0.618)\n");
    } else {
        _ = try stdout.write("  Golden Ratio Gate: NEEDS IMPROVEMENT (<0.618)\n");
    }

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("  phi^2 + 1/phi^2 = 3 = TRINITY | PERSONALITY ENGINE CYCLE 10                 \n");
    _ = try stdout.write("===============================================================================\n");
}

// =============================================================================
// MAIN & TESTS
// =============================================================================

pub fn main() !void {
    try runBenchmark();
}

test "personality trait intensity" {
    try std.testing.expect(PersonalityTrait.Helpful.getIntensity() == 0.95);
    try std.testing.expect(PersonalityTrait.Patient.getIntensity() == 0.99);
}

test "emotional state marker" {
    const marker_en = EmotionalState.Happy.getMarker(.English);
    try std.testing.expect(std.mem.eql(u8, marker_en, "Happy to help! "));

    const marker_ru = EmotionalState.Happy.getMarker(.Russian);
    try std.testing.expect(std.mem.eql(u8, marker_ru, "Рад помочь! "));
}

test "emotional state transition" {
    const state = EmotionalState.Calm;
    const new_state = state.transition(.ThumbsUp);
    try std.testing.expectEqual(EmotionalState.Happy, new_state);
}

test "formality greeting" {
    const casual = Formality.Casual.getGreeting(.English);
    try std.testing.expect(std.mem.eql(u8, casual, "Hey! "));

    const formal = Formality.Formal.getGreeting(.English);
    try std.testing.expect(std.mem.eql(u8, formal, "Good day! "));
}

test "formality farewell" {
    const casual = Formality.Casual.getFarewell(.English);
    try std.testing.expect(std.mem.eql(u8, casual, "Bye! "));
}

test "style preference init" {
    const style = StylePreference.init();
    try std.testing.expectEqual(Formality.Neutral, style.formality);
    try std.testing.expectEqual(DetailLevel.Moderate, style.detail);
}

test "style preference adjust for code" {
    var style = StylePreference.init();
    style.adjustForContext(.Code);
    try std.testing.expectEqual(DetailLevel.Detailed, style.detail);
    try std.testing.expect(style.humor_level < 0.2);
}

test "character memory init" {
    const memory = CharacterMemory.init();
    try std.testing.expectEqual(@as(f32, 0.5), memory.relationship_warmth);
    try std.testing.expectEqual(@as(usize, 0), memory.total_interactions);
}

test "character memory warmth growth" {
    var memory = CharacterMemory.init();
    memory.recordInteraction();
    try std.testing.expect(memory.relationship_warmth > 0.5);
    memory.recordPositiveFeedback();
    try std.testing.expect(memory.relationship_warmth > 0.55);
}

test "character memory warmth level" {
    var memory = CharacterMemory.init();
    memory.relationship_warmth = 0.9;
    try std.testing.expect(std.mem.eql(u8, memory.getWarmthLevel(), "warm"));

    memory.relationship_warmth = 0.3;
    try std.testing.expect(std.mem.eql(u8, memory.getWarmthLevel(), "reserved"));
}

test "personality engine init" {
    const engine = PersonalityEngine.init();
    try std.testing.expect(engine.is_first_interaction);
    try std.testing.expectEqual(EmotionalState.Calm, engine.current_emotion);
}

test "personality engine respond" {
    var engine = PersonalityEngine.init();
    const response = engine.respond("hello");
    try std.testing.expect(response.text.len > 0);
    try std.testing.expect(response.is_greeting);
}

test "personality engine feedback" {
    var engine = PersonalityEngine.init();
    _ = engine.respond("test");
    engine.recordFeedback(.ThumbsUp);
    try std.testing.expectEqual(EmotionalState.Happy, engine.current_emotion);
}

test "personality engine warmth increases" {
    var engine = PersonalityEngine.init();
    const initial = engine.memory.relationship_warmth;

    _ = engine.respond("hello");
    engine.recordFeedback(.ThumbsUp);

    try std.testing.expect(engine.memory.relationship_warmth > initial);
}

test "personality engine stats" {
    var engine = PersonalityEngine.init();
    _ = engine.respond("test");
    const stats = engine.getStats();

    try std.testing.expect(stats.personality_active);
    try std.testing.expectEqual(@as(usize, 1), stats.total_interactions);
}

test "greeting detection" {
    var engine = PersonalityEngine.init();

    var response = engine.respond("hello there!");
    try std.testing.expect(response.is_greeting);

    response = engine.respond("привет друг");
    try std.testing.expect(response.is_greeting);

    response = engine.respond("write code for me");
    try std.testing.expect(!response.is_greeting);
}

test "farewell detection" {
    var engine = PersonalityEngine.init();

    var response = engine.respond("goodbye friend");
    try std.testing.expect(response.is_farewell);

    response = engine.respond("пока, до встречи");
    try std.testing.expect(response.is_farewell);

    response = engine.respond("tell me more");
    try std.testing.expect(!response.is_farewell);
}

test "multilingual emotional markers" {
    try std.testing.expect(EmotionalState.Enthusiastic.getMarker(.Chinese).len > 0);
    try std.testing.expect(EmotionalState.Empathetic.getMarker(.Spanish).len > 0);
    try std.testing.expect(EmotionalState.Interested.getMarker(.German).len > 0);
}
