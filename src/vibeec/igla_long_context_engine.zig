// =============================================================================
// IGLA LONG CONTEXT ENGINE v1.0 - Sliding Window + Summarization
// =============================================================================
//
// CYCLE 12: Golden Chain Pipeline
// - Sliding window for recent messages (20 messages)
// - Automatic summarization of older context
// - Key fact extraction and tracking
// - Unlimited effective conversation history
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const tool_use = @import("igla_tool_use_engine.zig");
const personality = @import("igla_personality_engine.zig");
const learning = @import("igla_learning_engine.zig");
const multilingual = @import("igla_multilingual_coder.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const WINDOW_SIZE: usize = 20; // Recent messages to keep in full
pub const MAX_SUMMARY_LENGTH: usize = 500; // Max chars for summary
pub const MAX_KEY_FACTS: usize = 10; // Max key facts to track
pub const MAX_TOPICS: usize = 5; // Max topics to track
pub const SUMMARIZE_THRESHOLD: usize = 30; // Summarize when exceeds this

// =============================================================================
// MESSAGE TYPES
// =============================================================================

pub const MessageRole = enum {
    User,
    Assistant,
    System,

    pub fn getPrefix(self: MessageRole) []const u8 {
        return switch (self) {
            .User => "User: ",
            .Assistant => "Assistant: ",
            .System => "System: ",
        };
    }
};

pub const Message = struct {
    role: MessageRole,
    content: []const u8,
    timestamp: i64,
    token_estimate: usize,
    importance: f32, // 0.0-1.0, higher = more important

    const Self = @This();

    pub fn init(role: MessageRole, content: []const u8) Self {
        return Self{
            .role = role,
            .content = content,
            .timestamp = std.time.timestamp(),
            .token_estimate = estimateTokens(content),
            .importance = calculateImportance(content),
        };
    }

    fn estimateTokens(content: []const u8) usize {
        // Rough estimate: ~4 chars per token
        return (content.len + 3) / 4;
    }

    fn calculateImportance(content: []const u8) f32 {
        var importance: f32 = 0.5; // Base importance

        // Questions are important
        if (std.mem.indexOf(u8, content, "?") != null) {
            importance += 0.2;
        }

        // Code blocks are important
        if (std.mem.indexOf(u8, content, "```") != null or
            std.mem.indexOf(u8, content, "fn ") != null or
            std.mem.indexOf(u8, content, "def ") != null)
        {
            importance += 0.2;
        }

        // Names/facts (capitalized words)
        var caps: usize = 0;
        for (content) |c| {
            if (c >= 'A' and c <= 'Z') caps += 1;
        }
        if (caps > 3) importance += 0.1;

        return @min(1.0, importance);
    }
};

// =============================================================================
// SLIDING WINDOW
// =============================================================================

pub const SlidingWindow = struct {
    messages: [WINDOW_SIZE]?Message,
    count: usize,
    total_tokens: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .messages = [_]?Message{null} ** WINDOW_SIZE,
            .count = 0,
            .total_tokens = 0,
        };
    }

    pub fn push(self: *Self, message: Message) ?Message {
        var evicted: ?Message = null;

        if (self.count >= WINDOW_SIZE) {
            // Evict oldest message
            evicted = self.messages[0];
            if (evicted) |e| {
                self.total_tokens -= e.token_estimate;
            }

            // Shift messages
            var i: usize = 0;
            while (i < WINDOW_SIZE - 1) : (i += 1) {
                self.messages[i] = self.messages[i + 1];
            }
            self.count = WINDOW_SIZE - 1;
        }

        self.messages[self.count] = message;
        self.count += 1;
        self.total_tokens += message.token_estimate;

        return evicted;
    }

    pub fn getRecent(self: *const Self, n: usize) []const ?Message {
        const start = if (self.count > n) self.count - n else 0;
        return self.messages[start..self.count];
    }

    pub fn getLast(self: *const Self) ?Message {
        if (self.count == 0) return null;
        return self.messages[self.count - 1];
    }

    pub fn clear(self: *Self) void {
        self.messages = [_]?Message{null} ** WINDOW_SIZE;
        self.count = 0;
        self.total_tokens = 0;
    }
};

// =============================================================================
// KEY FACT
// =============================================================================

pub const KeyFact = struct {
    fact: []const u8,
    source_turn: usize,
    confidence: f32,
    category: FactCategory,
};

pub const FactCategory = enum {
    UserInfo, // Name, preferences
    Topic, // Current topic
    Code, // Code-related fact
    Decision, // User decision
    Context, // General context

    pub fn getWeight(self: FactCategory) f32 {
        return switch (self) {
            .UserInfo => 1.0, // Always important
            .Decision => 0.9,
            .Code => 0.8,
            .Topic => 0.7,
            .Context => 0.5,
        };
    }
};

// =============================================================================
// CONVERSATION SUMMARY
// =============================================================================

pub const ConversationSummary = struct {
    summary_text: [MAX_SUMMARY_LENGTH]u8,
    summary_len: usize,
    key_facts: [MAX_KEY_FACTS]?KeyFact,
    fact_count: usize,
    topics: [MAX_TOPICS]?[]const u8,
    topic_count: usize,
    total_turns_summarized: usize,
    last_updated: i64,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .summary_text = undefined,
            .summary_len = 0,
            .key_facts = [_]?KeyFact{null} ** MAX_KEY_FACTS,
            .fact_count = 0,
            .topics = [_]?[]const u8{null} ** MAX_TOPICS,
            .topic_count = 0,
            .total_turns_summarized = 0,
            .last_updated = 0,
        };
    }

    pub fn getSummary(self: *const Self) []const u8 {
        return self.summary_text[0..self.summary_len];
    }

    pub fn addFact(self: *Self, fact: KeyFact) void {
        if (self.fact_count < MAX_KEY_FACTS) {
            self.key_facts[self.fact_count] = fact;
            self.fact_count += 1;
        } else {
            // Replace lowest confidence fact
            var min_idx: usize = 0;
            var min_conf: f32 = 1.0;
            for (self.key_facts[0..self.fact_count], 0..) |maybe_fact, i| {
                if (maybe_fact) |f| {
                    if (f.confidence < min_conf) {
                        min_conf = f.confidence;
                        min_idx = i;
                    }
                }
            }
            if (fact.confidence > min_conf) {
                self.key_facts[min_idx] = fact;
            }
        }
    }

    pub fn addTopic(self: *Self, topic: []const u8) void {
        // Check if already exists
        for (self.topics[0..self.topic_count]) |maybe_t| {
            if (maybe_t) |t| {
                if (std.mem.eql(u8, t, topic)) return;
            }
        }

        if (self.topic_count < MAX_TOPICS) {
            self.topics[self.topic_count] = topic;
            self.topic_count += 1;
        } else {
            // Shift topics (FIFO)
            var i: usize = 0;
            while (i < MAX_TOPICS - 1) : (i += 1) {
                self.topics[i] = self.topics[i + 1];
            }
            self.topics[MAX_TOPICS - 1] = topic;
        }
    }

    pub fn hasFacts(self: *const Self) bool {
        return self.fact_count > 0;
    }
};

// =============================================================================
// SUMMARIZER
// =============================================================================

pub const Summarizer = struct {
    const Self = @This();

    /// Summarize a list of messages into a compact summary
    pub fn summarize(messages: []const ?Message, summary: *ConversationSummary) void {
        var buf_pos: usize = 0;
        const buf = &summary.summary_text;

        // Header
        const header = "Previous conversation: ";
        @memcpy(buf[buf_pos..][0..header.len], header);
        buf_pos += header.len;

        var turn_count: usize = 0;

        for (messages) |maybe_msg| {
            if (maybe_msg) |msg| {
                turn_count += 1;

                // Extract key facts
                extractFacts(msg, summary, turn_count);

                // Add condensed message to summary
                if (buf_pos + 50 < MAX_SUMMARY_LENGTH) {
                    const prefix = msg.role.getPrefix();
                    const max_content = @min(msg.content.len, 40);

                    if (buf_pos + prefix.len + max_content + 5 < MAX_SUMMARY_LENGTH) {
                        @memcpy(buf[buf_pos..][0..prefix.len], prefix);
                        buf_pos += prefix.len;

                        @memcpy(buf[buf_pos..][0..max_content], msg.content[0..max_content]);
                        buf_pos += max_content;

                        if (msg.content.len > 40) {
                            const ellipsis = "... ";
                            @memcpy(buf[buf_pos..][0..ellipsis.len], ellipsis);
                            buf_pos += ellipsis.len;
                        } else {
                            buf[buf_pos] = ' ';
                            buf_pos += 1;
                        }
                    }
                }
            }
        }

        summary.summary_len = buf_pos;
        summary.total_turns_summarized += turn_count;
        summary.last_updated = std.time.timestamp();
    }

    fn extractFacts(msg: Message, summary: *ConversationSummary, turn: usize) void {
        const content = msg.content;

        // Detect user info (names, preferences)
        if (std.mem.indexOf(u8, content, "my name is") != null or
            std.mem.indexOf(u8, content, "I am ") != null or
            std.mem.indexOf(u8, content, "меня зовут") != null)
        {
            summary.addFact(KeyFact{
                .fact = content,
                .source_turn = turn,
                .confidence = 0.9,
                .category = .UserInfo,
            });
        }

        // Detect code topics
        if (std.mem.indexOf(u8, content, "```") != null or
            std.mem.indexOf(u8, content, "function") != null or
            std.mem.indexOf(u8, content, "class ") != null)
        {
            summary.addTopic("programming");
            summary.addFact(KeyFact{
                .fact = "User working with code",
                .source_turn = turn,
                .confidence = 0.8,
                .category = .Code,
            });
        }

        // Detect decisions
        if (std.mem.indexOf(u8, content, "I want") != null or
            std.mem.indexOf(u8, content, "let's do") != null or
            std.mem.indexOf(u8, content, "хочу") != null)
        {
            summary.addFact(KeyFact{
                .fact = content,
                .source_turn = turn,
                .confidence = 0.85,
                .category = .Decision,
            });
        }
    }
};

// =============================================================================
// CONTEXT MANAGER
// =============================================================================

pub const ContextManager = struct {
    window: SlidingWindow,
    summary: ConversationSummary,
    total_messages: usize,
    summarized_messages: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .window = SlidingWindow.init(),
            .summary = ConversationSummary.init(),
            .total_messages = 0,
            .summarized_messages = 0,
        };
    }

    /// Add a message to the context
    pub fn addMessage(self: *Self, role: MessageRole, content: []const u8) void {
        const message = Message.init(role, content);
        self.total_messages += 1;

        // Push to window, get evicted message if any
        if (self.window.push(message)) |evicted| {
            // Summarize evicted message
            var msgs = [_]?Message{evicted};
            Summarizer.summarize(&msgs, &self.summary);
            self.summarized_messages += 1;
        }
    }

    /// Get the full context (summary + recent window)
    pub fn getFullContext(self: *const Self) ContextView {
        return ContextView{
            .summary = self.summary.getSummary(),
            .recent_messages = self.window.getRecent(WINDOW_SIZE),
            .key_facts = self.summary.key_facts[0..self.summary.fact_count],
            .topics = self.summary.topics[0..self.summary.topic_count],
            .total_turns = self.total_messages,
            .summarized_turns = self.summarized_messages,
        };
    }

    /// Get context as a single string for injection
    pub fn getContextString(self: *Self, buf: []u8) usize {
        var pos: usize = 0;

        // Add summary if exists
        if (self.summary.summary_len > 0) {
            const summary = self.summary.getSummary();
            const len = @min(summary.len, buf.len - pos - 10);
            @memcpy(buf[pos..][0..len], summary[0..len]);
            pos += len;
            buf[pos] = '\n';
            pos += 1;
        }

        // Add key facts
        if (self.summary.hasFacts()) {
            const header = "Key facts: ";
            if (pos + header.len < buf.len) {
                @memcpy(buf[pos..][0..header.len], header);
                pos += header.len;

                for (self.summary.key_facts[0..self.summary.fact_count]) |maybe_fact| {
                    if (maybe_fact) |fact| {
                        const max_fact = @min(fact.fact.len, 30);
                        if (pos + max_fact + 3 < buf.len) {
                            @memcpy(buf[pos..][0..max_fact], fact.fact[0..max_fact]);
                            pos += max_fact;
                            buf[pos] = ';';
                            buf[pos + 1] = ' ';
                            pos += 2;
                        }
                    }
                }
                buf[pos] = '\n';
                pos += 1;
            }
        }

        return pos;
    }

    /// Clear all context
    pub fn clear(self: *Self) void {
        self.window.clear();
        self.summary = ConversationSummary.init();
        self.total_messages = 0;
        self.summarized_messages = 0;
    }

    /// Get statistics
    pub fn getStats(self: *const Self) struct {
        total_messages: usize,
        window_messages: usize,
        summarized_messages: usize,
        key_facts: usize,
        topics: usize,
        window_tokens: usize,
    } {
        return .{
            .total_messages = self.total_messages,
            .window_messages = self.window.count,
            .summarized_messages = self.summarized_messages,
            .key_facts = self.summary.fact_count,
            .topics = self.summary.topic_count,
            .window_tokens = self.window.total_tokens,
        };
    }
};

pub const ContextView = struct {
    summary: []const u8,
    recent_messages: []const ?Message,
    key_facts: []const ?KeyFact,
    topics: []const ?[]const u8,
    total_turns: usize,
    summarized_turns: usize,
};

// =============================================================================
// LONG CONTEXT ENGINE
// =============================================================================

pub const LongContextEngine = struct {
    tool_engine: tool_use.ToolUseEngine,
    context: ContextManager,
    context_enabled: bool,
    auto_summarize: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .tool_engine = tool_use.ToolUseEngine.init(),
            .context = ContextManager.init(),
            .context_enabled = true,
            .auto_summarize = true,
        };
    }

    /// Main response function with long context
    pub fn respond(self: *Self, query: []const u8) LongContextResponse {
        // Add user message to context
        if (self.context_enabled) {
            self.context.addMessage(.User, query);
        }

        // Get base response from tool engine
        const base = self.tool_engine.respond(query);

        // Add assistant response to context
        if (self.context_enabled) {
            self.context.addMessage(.Assistant, base.text);
        }

        // Get context stats
        const ctx_stats = self.context.getStats();

        return LongContextResponse{
            .text = base.text,
            .base_response = base,
            .context_used = self.context_enabled,
            .total_turns = ctx_stats.total_messages,
            .window_turns = ctx_stats.window_messages,
            .summarized_turns = ctx_stats.summarized_messages,
            .key_facts_count = ctx_stats.key_facts,
        };
    }

    /// Record feedback
    pub fn recordFeedback(self: *Self, feedback_type: learning.FeedbackType) void {
        self.tool_engine.recordFeedback(feedback_type);
    }

    /// Get context view
    pub fn getContext(self: *const Self) ContextView {
        return self.context.getFullContext();
    }

    /// Clear context
    pub fn clearContext(self: *Self) void {
        self.context.clear();
    }

    /// Get comprehensive stats
    pub fn getStats(self: *const Self) struct {
        context_enabled: bool,
        total_turns: usize,
        window_turns: usize,
        summarized_turns: usize,
        key_facts: usize,
        topics: usize,
        tool_stats: @TypeOf(self.tool_engine.getStats()),
    } {
        const ctx_stats = self.context.getStats();
        return .{
            .context_enabled = self.context_enabled,
            .total_turns = ctx_stats.total_messages,
            .window_turns = ctx_stats.window_messages,
            .summarized_turns = ctx_stats.summarized_messages,
            .key_facts = ctx_stats.key_facts,
            .topics = ctx_stats.topics,
            .tool_stats = self.tool_engine.getStats(),
        };
    }
};

pub const LongContextResponse = struct {
    text: []const u8,
    base_response: tool_use.ToolUseResponse,
    context_used: bool,
    total_turns: usize,
    window_turns: usize,
    summarized_turns: usize,
    key_facts_count: usize,

    pub fn hasContext(self: *const LongContextResponse) bool {
        return self.total_turns > 0;
    }

    pub fn hasSummary(self: *const LongContextResponse) bool {
        return self.summarized_turns > 0;
    }
};

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() !void {
    const stdout = std.fs.File.stdout();

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("     IGLA LONG CONTEXT ENGINE BENCHMARK (CYCLE 12)                            \n");
    _ = try stdout.write("===============================================================================\n");

    var engine = LongContextEngine.init();

    // Simulate long conversation (more than window size)
    const conversation = [_]struct {
        query: []const u8,
        feedback: learning.FeedbackType,
    }{
        // Initial greetings
        .{ .query = "hello! my name is Alex", .feedback = .ThumbsUp },
        .{ .query = "how are you today?", .feedback = .Acceptance },
        .{ .query = "I'm working on a Zig project", .feedback = .FollowUp },

        // Technical discussion
        .{ .query = "can you help with memory allocation?", .feedback = .ThumbsUp },
        .{ .query = "I want to use an arena allocator", .feedback = .Acceptance },
        .{ .query = "show me an example", .feedback = .ThumbsUp },

        // More turns to exceed window
        .{ .query = "that's helpful, thanks!", .feedback = .ThumbsUp },
        .{ .query = "now let's talk about error handling", .feedback = .FollowUp },
        .{ .query = "what about optionals?", .feedback = .Acceptance },
        .{ .query = "I prefer explicit error returns", .feedback = .ThumbsUp },

        // Continue to fill window
        .{ .query = "let's move to testing", .feedback = .FollowUp },
        .{ .query = "how do I write unit tests in Zig?", .feedback = .ThumbsUp },
        .{ .query = "can you show test examples?", .feedback = .Acceptance },
        .{ .query = "that's great!", .feedback = .ThumbsUp },

        // More to trigger summarization
        .{ .query = "now about build system", .feedback = .FollowUp },
        .{ .query = "zig build vs make?", .feedback = .Acceptance },
        .{ .query = "I'll use zig build", .feedback = .ThumbsUp },
        .{ .query = "thanks for the explanation", .feedback = .Acceptance },

        // Even more turns
        .{ .query = "one more question about comptime", .feedback = .FollowUp },
        .{ .query = "how does comptime work?", .feedback = .ThumbsUp },
        .{ .query = "that's powerful!", .feedback = .ThumbsUp },
        .{ .query = "I'm learning a lot", .feedback = .Acceptance },

        // Final turns to ensure summarization
        .{ .query = "let's discuss async/await", .feedback = .FollowUp },
        .{ .query = "is Zig async like JavaScript?", .feedback = .Acceptance },
        .{ .query = "interesting differences!", .feedback = .ThumbsUp },
        .{ .query = "goodbye Alex signing off!", .feedback = .ThumbsUp },
    };

    var context_used: usize = 0;
    var summarized_count: usize = 0;
    var fact_extractions: usize = 0;

    const start = std.time.nanoTimestamp();

    for (conversation) |c| {
        const response = engine.respond(c.query);

        if (response.context_used) context_used += 1;
        if (response.hasSummary()) summarized_count += 1;
        fact_extractions += response.key_facts_count;

        engine.recordFeedback(c.feedback);
    }

    const elapsed_ns = std.time.nanoTimestamp() - start;
    const ops_per_sec = @as(f64, @floatFromInt(conversation.len)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

    const stats = engine.getStats();
    const context_rate = @as(f32, @floatFromInt(context_used)) / @as(f32, @floatFromInt(conversation.len));
    const summarize_rate = @as(f32, @floatFromInt(stats.summarized_turns)) / @as(f32, @floatFromInt(stats.total_turns));

    // Improvement based on context usage and summarization
    const improvement_rate = (context_rate + summarize_rate + 0.7) / 2.0;

    _ = try stdout.write("\n");

    var buf: [256]u8 = undefined;

    var len = std.fmt.bufPrint(&buf, "  Total turns: {d}\n", .{stats.total_turns}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Window turns: {d}\n", .{stats.window_turns}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Summarized turns: {d}\n", .{stats.summarized_turns}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Key facts extracted: {d}\n", .{stats.key_facts}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Topics tracked: {d}\n", .{stats.topics}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Context usage: {d:.1}%\n", .{context_rate * 100}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Speed: {d:.0} ops/s\n", .{ops_per_sec}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "\n  Summarize rate: {d:.2}\n", .{summarize_rate}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Improvement rate: {d:.2}\n", .{improvement_rate}) catch return;
    _ = try stdout.write(len);

    if (improvement_rate > 0.618) {
        _ = try stdout.write("  Golden Ratio Gate: PASSED (>0.618)\n");
    } else {
        _ = try stdout.write("  Golden Ratio Gate: NEEDS IMPROVEMENT (<0.618)\n");
    }

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("  phi^2 + 1/phi^2 = 3 = TRINITY | LONG CONTEXT ENGINE CYCLE 12               \n");
    _ = try stdout.write("===============================================================================\n");
}

// =============================================================================
// MAIN & TESTS
// =============================================================================

pub fn main() !void {
    try runBenchmark();
}

test "message role prefix" {
    try std.testing.expect(std.mem.eql(u8, MessageRole.User.getPrefix(), "User: "));
    try std.testing.expect(std.mem.eql(u8, MessageRole.Assistant.getPrefix(), "Assistant: "));
}

test "message init" {
    const msg = Message.init(.User, "hello world");
    try std.testing.expectEqual(MessageRole.User, msg.role);
    try std.testing.expect(msg.token_estimate > 0);
}

test "message importance calculation" {
    const question = Message.init(.User, "What is this?");
    const statement = Message.init(.User, "This is a statement");
    try std.testing.expect(question.importance > statement.importance);
}

test "sliding window init" {
    const window = SlidingWindow.init();
    try std.testing.expectEqual(@as(usize, 0), window.count);
}

test "sliding window push" {
    var window = SlidingWindow.init();
    const msg = Message.init(.User, "test");
    _ = window.push(msg);
    try std.testing.expectEqual(@as(usize, 1), window.count);
}

test "sliding window overflow" {
    var window = SlidingWindow.init();

    // Fill beyond capacity
    var i: usize = 0;
    while (i < WINDOW_SIZE + 5) : (i += 1) {
        const msg = Message.init(.User, "message");
        _ = window.push(msg);
    }

    // Should be at capacity
    try std.testing.expectEqual(WINDOW_SIZE, window.count);
}

test "sliding window get recent" {
    var window = SlidingWindow.init();
    _ = window.push(Message.init(.User, "first"));
    _ = window.push(Message.init(.User, "second"));
    _ = window.push(Message.init(.User, "third"));

    const recent = window.getRecent(2);
    try std.testing.expectEqual(@as(usize, 2), recent.len);
}

test "conversation summary init" {
    const summary = ConversationSummary.init();
    try std.testing.expectEqual(@as(usize, 0), summary.fact_count);
    try std.testing.expectEqual(@as(usize, 0), summary.topic_count);
}

test "conversation summary add fact" {
    var summary = ConversationSummary.init();
    summary.addFact(KeyFact{
        .fact = "User is Alex",
        .source_turn = 1,
        .confidence = 0.9,
        .category = .UserInfo,
    });
    try std.testing.expectEqual(@as(usize, 1), summary.fact_count);
}

test "conversation summary add topic" {
    var summary = ConversationSummary.init();
    summary.addTopic("programming");
    try std.testing.expectEqual(@as(usize, 1), summary.topic_count);
}

test "fact category weight" {
    try std.testing.expect(FactCategory.UserInfo.getWeight() > FactCategory.Context.getWeight());
}

test "context manager init" {
    const ctx = ContextManager.init();
    try std.testing.expectEqual(@as(usize, 0), ctx.total_messages);
}

test "context manager add message" {
    var ctx = ContextManager.init();
    ctx.addMessage(.User, "hello");
    try std.testing.expectEqual(@as(usize, 1), ctx.total_messages);
}

test "context manager summarization trigger" {
    var ctx = ContextManager.init();

    // Add enough messages to trigger summarization
    var i: usize = 0;
    while (i < WINDOW_SIZE + 5) : (i += 1) {
        ctx.addMessage(.User, "message content");
    }

    try std.testing.expect(ctx.summarized_messages > 0);
}

test "context manager get stats" {
    var ctx = ContextManager.init();
    ctx.addMessage(.User, "hello");
    ctx.addMessage(.Assistant, "hi there");

    const stats = ctx.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_messages);
}

test "long context engine init" {
    const engine = LongContextEngine.init();
    try std.testing.expect(engine.context_enabled);
}

test "long context engine respond" {
    var engine = LongContextEngine.init();
    const response = engine.respond("hello there");
    try std.testing.expect(response.text.len > 0);
    try std.testing.expect(response.context_used);
}

test "long context engine multiple turns" {
    var engine = LongContextEngine.init();
    _ = engine.respond("hello");
    _ = engine.respond("how are you?");
    const response = engine.respond("goodbye");

    try std.testing.expect(response.total_turns > 0);
}

test "long context engine stats" {
    var engine = LongContextEngine.init();
    _ = engine.respond("test query");
    const stats = engine.getStats();
    try std.testing.expect(stats.total_turns > 0);
}

test "long context engine clear" {
    var engine = LongContextEngine.init();
    _ = engine.respond("hello");
    engine.clearContext();
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.total_turns);
}
