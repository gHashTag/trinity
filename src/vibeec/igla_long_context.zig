//! IGLA Long Context Engine v1.0
//! Sliding window + summarization for unlimited conversation history
//! Part of the IGLA (Intelligent Generative Language Architecture) system
//!
//! Features:
//! - Sliding window to keep recent messages
//! - Automatic summarization of older context
//! - Token counting and budget management
//! - Priority-based message retention
//! - Chunked context retrieval
//!
//! Golden Chain Cycle 22 - phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

pub const MAX_MESSAGES: usize = 100;
pub const MAX_CONTENT_LEN: usize = 512;
pub const MAX_SUMMARY_LEN: usize = 256;
pub const DEFAULT_WINDOW_SIZE: usize = 10;
pub const DEFAULT_MAX_TOKENS: usize = 4096;
pub const DEFAULT_SUMMARY_RATIO: f32 = 0.25;
pub const TOKENS_PER_WORD: f32 = 1.3;

// ============================================================================
// MESSAGE ROLE
// ============================================================================

pub const MessageRole = enum {
    User,
    Assistant,
    System,
    Summary,

    pub fn getName(self: MessageRole) []const u8 {
        return switch (self) {
            .User => "user",
            .Assistant => "assistant",
            .System => "system",
            .Summary => "summary",
        };
    }

    pub fn fromString(s: []const u8) MessageRole {
        if (std.mem.eql(u8, s, "user")) return .User;
        if (std.mem.eql(u8, s, "assistant")) return .Assistant;
        if (std.mem.eql(u8, s, "system")) return .System;
        if (std.mem.eql(u8, s, "summary")) return .Summary;
        return .User;
    }

    pub fn isImportant(self: MessageRole) bool {
        return self == .System or self == .Summary;
    }
};

// ============================================================================
// MESSAGE PRIORITY
// ============================================================================

pub const MessagePriority = enum {
    Low,
    Normal,
    High,
    Critical,
    Pinned,

    pub fn getValue(self: MessagePriority) u8 {
        return switch (self) {
            .Low => 1,
            .Normal => 5,
            .High => 7,
            .Critical => 9,
            .Pinned => 10,
        };
    }

    pub fn getName(self: MessagePriority) []const u8 {
        return switch (self) {
            .Low => "low",
            .Normal => "normal",
            .High => "high",
            .Critical => "critical",
            .Pinned => "pinned",
        };
    }

    pub fn shouldRetain(self: MessagePriority) bool {
        return self == .Critical or self == .Pinned;
    }
};

// ============================================================================
// MESSAGE
// ============================================================================

pub const Message = struct {
    role: MessageRole,
    content: [MAX_CONTENT_LEN]u8,
    content_len: usize,
    timestamp: i64,
    tokens: usize,
    priority: MessagePriority,
    is_summarized: bool,
    original_count: usize, // How many messages this summary represents

    pub fn init(role: MessageRole, content: []const u8) Message {
        var msg = Message{
            .role = role,
            .content = undefined,
            .content_len = 0,
            .timestamp = std.time.timestamp(),
            .tokens = 0,
            .priority = .Normal,
            .is_summarized = false,
            .original_count = 1,
        };
        msg.setContent(content);
        return msg;
    }

    pub fn setContent(self: *Message, content: []const u8) void {
        const len = @min(content.len, MAX_CONTENT_LEN);
        @memcpy(self.content[0..len], content[0..len]);
        self.content_len = len;
        self.tokens = TokenCounter.countTokens(content);
    }

    pub fn getContent(self: *const Message) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn setPriority(self: *Message, priority: MessagePriority) void {
        self.priority = priority;
    }

    pub fn markSummarized(self: *Message, original_count: usize) void {
        self.is_summarized = true;
        self.original_count = original_count;
        self.role = .Summary;
    }

    pub fn getAge(self: *const Message) i64 {
        return std.time.timestamp() - self.timestamp;
    }

    pub fn shouldRetain(self: *const Message) bool {
        return self.priority.shouldRetain() or self.role.isImportant();
    }
};

// ============================================================================
// TOKEN COUNTER
// ============================================================================

pub const TokenCounter = struct {
    total_counted: usize,
    count_calls: usize,

    pub fn init() TokenCounter {
        return TokenCounter{
            .total_counted = 0,
            .count_calls = 0,
        };
    }

    pub fn countTokens(text: []const u8) usize {
        if (text.len == 0) return 0;

        // Approximate: count words and multiply by tokens per word
        var word_count: usize = 0;
        var in_word = false;

        for (text) |c| {
            const is_space = c == ' ' or c == '\n' or c == '\t' or c == '\r';
            if (!is_space and !in_word) {
                word_count += 1;
                in_word = true;
            } else if (is_space) {
                in_word = false;
            }
        }

        // At minimum 1 token for non-empty text
        if (word_count == 0 and text.len > 0) word_count = 1;

        const tokens_f: f32 = @as(f32, @floatFromInt(word_count)) * TOKENS_PER_WORD;
        return @max(1, @as(usize, @intFromFloat(tokens_f)));
    }

    pub fn countMessage(self: *TokenCounter, msg: *const Message) usize {
        const tokens = msg.tokens;
        self.total_counted += tokens;
        self.count_calls += 1;
        return tokens;
    }

    pub fn countMessages(self: *TokenCounter, messages: []const Message) usize {
        var total: usize = 0;
        for (messages) |*msg| {
            total += self.countMessage(msg);
        }
        return total;
    }

    pub fn reset(self: *TokenCounter) void {
        self.total_counted = 0;
        self.count_calls = 0;
    }

    pub fn getAverageTokens(self: *const TokenCounter) f32 {
        if (self.count_calls == 0) return 0;
        return @as(f32, @floatFromInt(self.total_counted)) / @as(f32, @floatFromInt(self.count_calls));
    }
};

// ============================================================================
// MESSAGE BUFFER (Circular)
// ============================================================================

pub const MessageBuffer = struct {
    messages: [MAX_MESSAGES]Message,
    count: usize,
    head: usize, // Next write position
    total_added: usize,

    pub fn init() MessageBuffer {
        return MessageBuffer{
            .messages = undefined,
            .count = 0,
            .head = 0,
            .total_added = 0,
        };
    }

    pub fn add(self: *MessageBuffer, msg: Message) bool {
        if (self.count >= MAX_MESSAGES) {
            // Buffer full, overwrite oldest
            self.messages[self.head] = msg;
            self.head = (self.head + 1) % MAX_MESSAGES;
        } else {
            self.messages[self.count] = msg;
            self.count += 1;
        }
        self.total_added += 1;
        return true;
    }

    pub fn addNew(self: *MessageBuffer, role: MessageRole, content: []const u8) bool {
        const msg = Message.init(role, content);
        return self.add(msg);
    }

    pub fn get(self: *MessageBuffer, index: usize) ?*Message {
        if (index >= self.count) return null;
        const actual_index = if (self.count >= MAX_MESSAGES)
            (self.head + index) % MAX_MESSAGES
        else
            index;
        return &self.messages[actual_index];
    }

    pub fn getConst(self: *const MessageBuffer, index: usize) ?*const Message {
        if (index >= self.count) return null;
        const actual_index = if (self.count >= MAX_MESSAGES)
            (self.head + index) % MAX_MESSAGES
        else
            index;
        return &self.messages[actual_index];
    }

    pub fn getLast(self: *MessageBuffer, n: usize) []Message {
        if (self.count == 0) return self.messages[0..0];
        const actual_n = @min(n, self.count);
        const start = self.count - actual_n;
        // Return slice from linear portion
        if (self.count < MAX_MESSAGES) {
            return self.messages[start..self.count];
        }
        // For circular buffer, we return from head position
        return self.messages[0..actual_n];
    }

    pub fn getTotalTokens(self: *const MessageBuffer) usize {
        var total: usize = 0;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.getConst(i)) |msg| {
                total += msg.tokens;
            }
        }
        return total;
    }

    pub fn clear(self: *MessageBuffer) void {
        self.count = 0;
        self.head = 0;
    }

    pub fn isEmpty(self: *const MessageBuffer) bool {
        return self.count == 0;
    }

    pub fn isFull(self: *const MessageBuffer) bool {
        return self.count >= MAX_MESSAGES;
    }
};

// ============================================================================
// SLIDING WINDOW
// ============================================================================

pub const SlidingWindow = struct {
    window_size: usize,
    max_tokens: usize,
    current_tokens: usize,

    pub fn init() SlidingWindow {
        return SlidingWindow{
            .window_size = DEFAULT_WINDOW_SIZE,
            .max_tokens = DEFAULT_MAX_TOKENS,
            .current_tokens = 0,
        };
    }

    pub fn initWithSize(window_size: usize, max_tokens: usize) SlidingWindow {
        return SlidingWindow{
            .window_size = window_size,
            .max_tokens = max_tokens,
            .current_tokens = 0,
        };
    }

    pub fn setWindowSize(self: *SlidingWindow, size: usize) void {
        self.window_size = size;
    }

    pub fn setMaxTokens(self: *SlidingWindow, max: usize) void {
        self.max_tokens = max;
    }

    pub fn getWindowMessages(self: *SlidingWindow, buffer: *MessageBuffer) usize {
        // Get messages that fit in window
        var count: usize = 0;
        var tokens: usize = 0;
        var i: usize = buffer.count;

        while (i > 0) {
            i -= 1;
            if (buffer.get(i)) |msg| {
                const msg_tokens = msg.tokens;
                if (tokens + msg_tokens > self.max_tokens and count > 0) {
                    break;
                }
                tokens += msg_tokens;
                count += 1;
                if (count >= self.window_size) break;
            }
        }

        self.current_tokens = tokens;
        return count;
    }

    pub fn shouldSummarize(self: *const SlidingWindow, buffer: *const MessageBuffer) bool {
        // Summarize when we have more messages than window size
        return buffer.count > self.window_size * 2;
    }

    pub fn getOldestToSummarize(self: *const SlidingWindow, buffer: *const MessageBuffer) usize {
        // Return count of messages that should be summarized
        if (buffer.count <= self.window_size) return 0;
        return buffer.count - self.window_size;
    }

    pub fn getRemainingTokens(self: *const SlidingWindow) usize {
        if (self.current_tokens >= self.max_tokens) return 0;
        return self.max_tokens - self.current_tokens;
    }

    pub fn isWithinBudget(self: *const SlidingWindow) bool {
        return self.current_tokens <= self.max_tokens;
    }
};

// ============================================================================
// SUMMARIZER
// ============================================================================

pub const Summarizer = struct {
    summary_ratio: f32,
    summaries_created: usize,
    messages_summarized: usize,
    tokens_saved: usize,

    pub fn init() Summarizer {
        return Summarizer{
            .summary_ratio = DEFAULT_SUMMARY_RATIO,
            .summaries_created = 0,
            .messages_summarized = 0,
            .tokens_saved = 0,
        };
    }

    pub fn initWithRatio(ratio: f32) Summarizer {
        return Summarizer{
            .summary_ratio = @min(1.0, @max(0.1, ratio)),
            .summaries_created = 0,
            .messages_summarized = 0,
            .tokens_saved = 0,
        };
    }

    pub fn summarize(self: *Summarizer, messages: []const Message) Message {
        if (messages.len == 0) {
            return Message.init(.Summary, "[No messages to summarize]");
        }

        // Create summary by extracting key content
        var summary_buf: [MAX_SUMMARY_LEN]u8 = undefined;
        var summary_len: usize = 0;

        // Header
        const header = "[Summary of ";
        @memcpy(summary_buf[summary_len..][0..header.len], header);
        summary_len += header.len;

        // Count
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{}", .{messages.len}) catch "?";
        @memcpy(summary_buf[summary_len..][0..count_str.len], count_str);
        summary_len += count_str.len;

        const msgs_text = " messages] ";
        @memcpy(summary_buf[summary_len..][0..msgs_text.len], msgs_text);
        summary_len += msgs_text.len;

        // Extract key points from each message
        var original_tokens: usize = 0;
        for (messages) |*msg| {
            original_tokens += msg.tokens;
            const content = msg.getContent();
            // Take first 30 chars of each message
            const take_len = @min(30, content.len);
            if (summary_len + take_len + 5 > MAX_SUMMARY_LEN) break;

            @memcpy(summary_buf[summary_len..][0..take_len], content[0..take_len]);
            summary_len += take_len;

            if (take_len < content.len) {
                const ellipsis = "... ";
                @memcpy(summary_buf[summary_len..][0..ellipsis.len], ellipsis);
                summary_len += ellipsis.len;
            } else {
                summary_buf[summary_len] = ' ';
                summary_len += 1;
            }
        }

        var summary = Message.init(.Summary, summary_buf[0..summary_len]);
        summary.markSummarized(messages.len);

        // Track stats
        self.summaries_created += 1;
        self.messages_summarized += messages.len;
        if (original_tokens > summary.tokens) {
            self.tokens_saved += original_tokens - summary.tokens;
        }

        return summary;
    }

    pub fn getSummaryTargetTokens(self: *const Summarizer, original_tokens: usize) usize {
        const target_f: f32 = @as(f32, @floatFromInt(original_tokens)) * self.summary_ratio;
        return @max(10, @as(usize, @intFromFloat(target_f)));
    }

    pub fn getCompressionRatio(self: *const Summarizer) f32 {
        if (self.messages_summarized == 0) return 0;
        return @as(f32, @floatFromInt(self.summaries_created)) / @as(f32, @floatFromInt(self.messages_summarized));
    }

    pub fn reset(self: *Summarizer) void {
        self.summaries_created = 0;
        self.messages_summarized = 0;
        self.tokens_saved = 0;
    }
};

// ============================================================================
// CONTEXT CONFIG
// ============================================================================

pub const ContextConfig = struct {
    max_tokens: usize,
    window_size: usize,
    summary_ratio: f32,
    auto_summarize: bool,
    retain_system: bool,
    retain_critical: bool,

    pub fn init() ContextConfig {
        return ContextConfig{
            .max_tokens = DEFAULT_MAX_TOKENS,
            .window_size = DEFAULT_WINDOW_SIZE,
            .summary_ratio = DEFAULT_SUMMARY_RATIO,
            .auto_summarize = true,
            .retain_system = true,
            .retain_critical = true,
        };
    }

    pub fn withMaxTokens(self: ContextConfig, max: usize) ContextConfig {
        var config = self;
        config.max_tokens = max;
        return config;
    }

    pub fn withWindowSize(self: ContextConfig, size: usize) ContextConfig {
        var config = self;
        config.window_size = size;
        return config;
    }

    pub fn withSummaryRatio(self: ContextConfig, ratio: f32) ContextConfig {
        var config = self;
        config.summary_ratio = ratio;
        return config;
    }

    pub fn withAutoSummarize(self: ContextConfig, enabled: bool) ContextConfig {
        var config = self;
        config.auto_summarize = enabled;
        return config;
    }
};

// ============================================================================
// CONTEXT WINDOW (View)
// ============================================================================

pub const ContextWindow = struct {
    messages: [DEFAULT_WINDOW_SIZE * 2]Message,
    count: usize,
    total_tokens: usize,
    has_summary: bool,
    summary_covers: usize,

    pub fn init() ContextWindow {
        return ContextWindow{
            .messages = undefined,
            .count = 0,
            .total_tokens = 0,
            .has_summary = false,
            .summary_covers = 0,
        };
    }

    pub fn addMessage(self: *ContextWindow, msg: Message) bool {
        if (self.count >= DEFAULT_WINDOW_SIZE * 2) return false;
        self.messages[self.count] = msg;
        self.count += 1;
        self.total_tokens += msg.tokens;
        if (msg.is_summarized) {
            self.has_summary = true;
            self.summary_covers += msg.original_count;
        }
        return true;
    }

    pub fn get(self: *ContextWindow, index: usize) ?*Message {
        if (index >= self.count) return null;
        return &self.messages[index];
    }

    pub fn getEffectiveMessageCount(self: *const ContextWindow) usize {
        return self.count + self.summary_covers;
    }

    pub fn clear(self: *ContextWindow) void {
        self.count = 0;
        self.total_tokens = 0;
        self.has_summary = false;
        self.summary_covers = 0;
    }
};

// ============================================================================
// LONG CONTEXT STATS
// ============================================================================

pub const LongContextStats = struct {
    messages_added: usize,
    messages_in_window: usize,
    messages_summarized: usize,
    total_tokens_processed: usize,
    current_tokens: usize,
    summaries_created: usize,
    tokens_saved: usize,
    context_retrievals: usize,

    pub fn init() LongContextStats {
        return LongContextStats{
            .messages_added = 0,
            .messages_in_window = 0,
            .messages_summarized = 0,
            .total_tokens_processed = 0,
            .current_tokens = 0,
            .summaries_created = 0,
            .tokens_saved = 0,
            .context_retrievals = 0,
        };
    }

    pub fn getCompressionRatio(self: *const LongContextStats) f32 {
        if (self.total_tokens_processed == 0) return 0;
        return @as(f32, @floatFromInt(self.tokens_saved)) / @as(f32, @floatFromInt(self.total_tokens_processed));
    }

    pub fn getEfficiency(self: *const LongContextStats) f32 {
        if (self.messages_added == 0) return 0;
        return @as(f32, @floatFromInt(self.messages_in_window)) / @as(f32, @floatFromInt(self.messages_added));
    }

    pub fn reset(self: *LongContextStats) void {
        self.* = LongContextStats.init();
    }
};

// ============================================================================
// LONG CONTEXT ENGINE
// ============================================================================

pub const MAX_SUMMARIES: usize = 20;

pub const LongContextEngine = struct {
    buffer: MessageBuffer,
    window: SlidingWindow,
    summarizer: Summarizer,
    counter: TokenCounter,
    config: ContextConfig,
    stats: LongContextStats,
    summaries: [MAX_SUMMARIES]Message,
    summary_count: usize,

    pub fn init() LongContextEngine {
        return LongContextEngine{
            .buffer = MessageBuffer.init(),
            .window = SlidingWindow.init(),
            .summarizer = Summarizer.init(),
            .counter = TokenCounter.init(),
            .config = ContextConfig.init(),
            .stats = LongContextStats.init(),
            .summaries = undefined,
            .summary_count = 0,
        };
    }

    pub fn initWithConfig(config: ContextConfig) LongContextEngine {
        var engine = LongContextEngine.init();
        engine.config = config;
        engine.window.setWindowSize(config.window_size);
        engine.window.setMaxTokens(config.max_tokens);
        engine.summarizer.summary_ratio = config.summary_ratio;
        return engine;
    }

    pub fn addMessage(self: *LongContextEngine, role: MessageRole, content: []const u8) bool {
        const msg = Message.init(role, content);
        const tokens = msg.tokens;

        const success = self.buffer.add(msg);
        if (success) {
            self.stats.messages_added += 1;
            self.stats.total_tokens_processed += tokens;
            self.stats.current_tokens = self.buffer.getTotalTokens();

            // Auto-summarize if needed
            if (self.config.auto_summarize and self.window.shouldSummarize(&self.buffer)) {
                self.performSummarization();
            }
        }
        return success;
    }

    pub fn addUserMessage(self: *LongContextEngine, content: []const u8) bool {
        return self.addMessage(.User, content);
    }

    pub fn addAssistantMessage(self: *LongContextEngine, content: []const u8) bool {
        return self.addMessage(.Assistant, content);
    }

    pub fn addSystemMessage(self: *LongContextEngine, content: []const u8) bool {
        return self.addMessage(.System, content);
    }

    pub fn performSummarization(self: *LongContextEngine) void {
        const to_summarize = self.window.getOldestToSummarize(&self.buffer);
        if (to_summarize == 0) return;

        // Collect messages to summarize
        var msgs_to_summarize: [50]Message = undefined;
        var count: usize = 0;

        var i: usize = 0;
        while (i < to_summarize and count < 50) : (i += 1) {
            if (self.buffer.get(i)) |msg| {
                // Skip retained messages
                if (!msg.shouldRetain()) {
                    msgs_to_summarize[count] = msg.*;
                    count += 1;
                }
            }
        }

        if (count > 0) {
            const summary = self.summarizer.summarize(msgs_to_summarize[0..count]);
            if (self.summary_count < MAX_SUMMARIES) {
                self.summaries[self.summary_count] = summary;
                self.summary_count += 1;
            }
            self.stats.summaries_created += 1;
            self.stats.messages_summarized += count;
            self.stats.tokens_saved = self.summarizer.tokens_saved;
        }
    }

    pub fn getContext(self: *LongContextEngine) ContextWindow {
        var context = ContextWindow.init();

        // Add summaries first
        var i: usize = 0;
        while (i < self.summary_count) : (i += 1) {
            _ = context.addMessage(self.summaries[i]);
        }

        // Add recent messages from window
        const window_count = self.window.getWindowMessages(&self.buffer);
        const start = if (self.buffer.count > window_count) self.buffer.count - window_count else 0;

        i = start;
        while (i < self.buffer.count) : (i += 1) {
            if (self.buffer.get(i)) |msg| {
                _ = context.addMessage(msg.*);
            }
        }

        self.stats.context_retrievals += 1;
        self.stats.messages_in_window = context.count;

        return context;
    }

    pub fn getContextTokens(self: *LongContextEngine) usize {
        const context = self.getContext();
        return context.total_tokens;
    }

    pub fn getLastNMessages(self: *LongContextEngine, n: usize) ContextWindow {
        var context = ContextWindow.init();
        const actual_n = @min(n, self.buffer.count);
        const start = self.buffer.count - actual_n;

        var i = start;
        while (i < self.buffer.count) : (i += 1) {
            if (self.buffer.get(i)) |msg| {
                _ = context.addMessage(msg.*);
            }
        }

        return context;
    }

    pub fn setMessagePriority(self: *LongContextEngine, index: usize, priority: MessagePriority) bool {
        if (self.buffer.get(index)) |msg| {
            msg.setPriority(priority);
            return true;
        }
        return false;
    }

    pub fn pinMessage(self: *LongContextEngine, index: usize) bool {
        return self.setMessagePriority(index, .Pinned);
    }

    pub fn getStats(self: *LongContextEngine) LongContextStats {
        self.stats.current_tokens = self.buffer.getTotalTokens();
        return self.stats;
    }

    pub fn getMessageCount(self: *const LongContextEngine) usize {
        return self.buffer.count;
    }

    pub fn getTotalTokens(self: *const LongContextEngine) usize {
        return self.buffer.getTotalTokens();
    }

    pub fn getSummaryCount(self: *const LongContextEngine) usize {
        return self.summary_count;
    }

    pub fn reset(self: *LongContextEngine) void {
        self.buffer.clear();
        self.summarizer.reset();
        self.counter.reset();
        self.stats.reset();
        self.summary_count = 0;
    }

    pub fn setConfig(self: *LongContextEngine, config: ContextConfig) void {
        self.config = config;
        self.window.setWindowSize(config.window_size);
        self.window.setMaxTokens(config.max_tokens);
        self.summarizer.summary_ratio = config.summary_ratio;
    }
};

// ============================================================================
// BENCHMARK
// ============================================================================

pub fn runBenchmark() void {
    std.debug.print("\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("     IGLA LONG CONTEXT ENGINE BENCHMARK (CYCLE 22)\n", .{});
    std.debug.print("===============================================================================\n", .{});
    std.debug.print("\n", .{});

    var engine = LongContextEngine.init();
    std.debug.print("  Window size: {}\n", .{engine.config.window_size});
    std.debug.print("  Max tokens: {}\n", .{engine.config.max_tokens});
    std.debug.print("  Summary ratio: {d:.2}\n", .{engine.config.summary_ratio});
    std.debug.print("\n", .{});

    // Add many messages to test sliding window
    std.debug.print("  Adding 50 conversation turns...\n", .{});
    const start_time = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        var user_buf: [64]u8 = undefined;
        const user_msg = std.fmt.bufPrint(&user_buf, "User message number {} with some content", .{i + 1}) catch "User message";
        _ = engine.addUserMessage(user_msg);

        var asst_buf: [64]u8 = undefined;
        const asst_msg = std.fmt.bufPrint(&asst_buf, "Assistant response {} with helpful info", .{i + 1}) catch "Assistant response";
        _ = engine.addAssistantMessage(asst_msg);
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns: i64 = @intCast(end_time - start_time);
    const elapsed_us: u64 = @intCast(@divFloor(elapsed_ns, 1000));

    std.debug.print("\n", .{});
    std.debug.print("  Messages added: {}\n", .{engine.getMessageCount()});
    std.debug.print("  Summaries created: {}\n", .{engine.getSummaryCount()});
    std.debug.print("  Total tokens: {}\n", .{engine.getTotalTokens()});
    std.debug.print("\n", .{});

    // Get context
    std.debug.print("  Getting context window...\n", .{});
    const context = engine.getContext();
    std.debug.print("  Context messages: {}\n", .{context.count});
    std.debug.print("  Context tokens: {}\n", .{context.total_tokens});
    std.debug.print("  Has summary: {}\n", .{context.has_summary});
    std.debug.print("  Effective messages: {}\n", .{context.getEffectiveMessageCount()});
    std.debug.print("\n", .{});

    // Stats
    const stats = engine.getStats();
    std.debug.print("  Stats:\n", .{});
    std.debug.print("    Messages added: {}\n", .{stats.messages_added});
    std.debug.print("    Messages summarized: {}\n", .{stats.messages_summarized});
    std.debug.print("    Tokens processed: {}\n", .{stats.total_tokens_processed});
    std.debug.print("    Tokens saved: {}\n", .{stats.tokens_saved});
    std.debug.print("    Compression ratio: {d:.2}\n", .{stats.getCompressionRatio()});
    std.debug.print("    Efficiency: {d:.2}\n", .{stats.getEfficiency()});
    std.debug.print("\n", .{});

    // Performance
    const msgs_per_sec = if (elapsed_us > 0)
        (100 * 1_000_000) / elapsed_us
    else
        0;

    std.debug.print("  Performance:\n", .{});
    std.debug.print("    Total time: {}us\n", .{elapsed_us});
    std.debug.print("    Throughput: {} msgs/s\n", .{msgs_per_sec});
    std.debug.print("\n", .{});

    // Golden ratio check
    const improvement = stats.getEfficiency() + stats.getCompressionRatio();
    const passed = improvement > 0.618;
    std.debug.print("  Improvement rate: {d:.2}\n", .{improvement});
    std.debug.print("  Golden Ratio Gate: {s} (>0.618)\n", .{if (passed) "PASSED" else "FAILED"});
}

pub fn main() void {
    runBenchmark();
}

// ============================================================================
// TESTS
// ============================================================================

test "MessageRole getName" {
    try std.testing.expectEqualStrings("user", MessageRole.User.getName());
    try std.testing.expectEqualStrings("assistant", MessageRole.Assistant.getName());
    try std.testing.expectEqualStrings("system", MessageRole.System.getName());
    try std.testing.expectEqualStrings("summary", MessageRole.Summary.getName());
}

test "MessageRole fromString" {
    try std.testing.expectEqual(MessageRole.User, MessageRole.fromString("user"));
    try std.testing.expectEqual(MessageRole.Assistant, MessageRole.fromString("assistant"));
    try std.testing.expectEqual(MessageRole.System, MessageRole.fromString("system"));
}

test "MessageRole isImportant" {
    try std.testing.expect(MessageRole.System.isImportant());
    try std.testing.expect(MessageRole.Summary.isImportant());
    try std.testing.expect(!MessageRole.User.isImportant());
}

test "MessagePriority getValue" {
    try std.testing.expectEqual(@as(u8, 1), MessagePriority.Low.getValue());
    try std.testing.expectEqual(@as(u8, 5), MessagePriority.Normal.getValue());
    try std.testing.expectEqual(@as(u8, 10), MessagePriority.Pinned.getValue());
}

test "MessagePriority shouldRetain" {
    try std.testing.expect(MessagePriority.Critical.shouldRetain());
    try std.testing.expect(MessagePriority.Pinned.shouldRetain());
    try std.testing.expect(!MessagePriority.Normal.shouldRetain());
}

test "Message init" {
    const msg = Message.init(.User, "Hello world");
    try std.testing.expectEqual(MessageRole.User, msg.role);
    try std.testing.expectEqualStrings("Hello world", msg.getContent());
    try std.testing.expect(msg.tokens > 0);
}

test "Message setContent" {
    var msg = Message.init(.User, "initial");
    msg.setContent("updated content");
    try std.testing.expectEqualStrings("updated content", msg.getContent());
}

test "Message setPriority" {
    var msg = Message.init(.User, "test");
    msg.setPriority(.High);
    try std.testing.expectEqual(MessagePriority.High, msg.priority);
}

test "Message markSummarized" {
    var msg = Message.init(.User, "test");
    msg.markSummarized(5);
    try std.testing.expect(msg.is_summarized);
    try std.testing.expectEqual(@as(usize, 5), msg.original_count);
    try std.testing.expectEqual(MessageRole.Summary, msg.role);
}

test "Message shouldRetain" {
    var msg = Message.init(.User, "test");
    try std.testing.expect(!msg.shouldRetain());
    msg.setPriority(.Critical);
    try std.testing.expect(msg.shouldRetain());
}

test "TokenCounter countTokens" {
    try std.testing.expect(TokenCounter.countTokens("hello world") > 0);
    try std.testing.expect(TokenCounter.countTokens("one two three") >= 3);
    try std.testing.expectEqual(@as(usize, 0), TokenCounter.countTokens(""));
}

test "TokenCounter countMessage" {
    var counter = TokenCounter.init();
    const msg = Message.init(.User, "hello world");
    const tokens = counter.countMessage(&msg);
    try std.testing.expect(tokens > 0);
    try std.testing.expectEqual(tokens, counter.total_counted);
}

test "TokenCounter getAverageTokens" {
    var counter = TokenCounter.init();
    const msg1 = Message.init(.User, "hello world");
    const msg2 = Message.init(.User, "foo bar baz");
    _ = counter.countMessage(&msg1);
    _ = counter.countMessage(&msg2);
    try std.testing.expect(counter.getAverageTokens() > 0);
}

test "MessageBuffer init" {
    const buffer = MessageBuffer.init();
    try std.testing.expectEqual(@as(usize, 0), buffer.count);
    try std.testing.expect(buffer.isEmpty());
}

test "MessageBuffer add" {
    var buffer = MessageBuffer.init();
    const msg = Message.init(.User, "test");
    try std.testing.expect(buffer.add(msg));
    try std.testing.expectEqual(@as(usize, 1), buffer.count);
}

test "MessageBuffer addNew" {
    var buffer = MessageBuffer.init();
    try std.testing.expect(buffer.addNew(.User, "hello"));
    try std.testing.expectEqual(@as(usize, 1), buffer.count);
}

test "MessageBuffer get" {
    var buffer = MessageBuffer.init();
    _ = buffer.addNew(.User, "first");
    _ = buffer.addNew(.User, "second");
    if (buffer.get(0)) |msg| {
        try std.testing.expectEqualStrings("first", msg.getContent());
    } else {
        try std.testing.expect(false);
    }
}

test "MessageBuffer getTotalTokens" {
    var buffer = MessageBuffer.init();
    _ = buffer.addNew(.User, "hello world");
    _ = buffer.addNew(.User, "foo bar");
    try std.testing.expect(buffer.getTotalTokens() > 0);
}

test "MessageBuffer clear" {
    var buffer = MessageBuffer.init();
    _ = buffer.addNew(.User, "test");
    buffer.clear();
    try std.testing.expectEqual(@as(usize, 0), buffer.count);
    try std.testing.expect(buffer.isEmpty());
}

test "SlidingWindow init" {
    const window = SlidingWindow.init();
    try std.testing.expectEqual(DEFAULT_WINDOW_SIZE, window.window_size);
    try std.testing.expectEqual(DEFAULT_MAX_TOKENS, window.max_tokens);
}

test "SlidingWindow setWindowSize" {
    var window = SlidingWindow.init();
    window.setWindowSize(20);
    try std.testing.expectEqual(@as(usize, 20), window.window_size);
}

test "SlidingWindow getWindowMessages" {
    var window = SlidingWindow.init();
    var buffer = MessageBuffer.init();
    _ = buffer.addNew(.User, "msg1");
    _ = buffer.addNew(.User, "msg2");
    _ = buffer.addNew(.User, "msg3");
    const count = window.getWindowMessages(&buffer);
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "SlidingWindow shouldSummarize" {
    var window = SlidingWindow.initWithSize(2, 1000);
    var buffer = MessageBuffer.init();
    _ = buffer.addNew(.User, "msg1");
    _ = buffer.addNew(.User, "msg2");
    try std.testing.expect(!window.shouldSummarize(&buffer));
    _ = buffer.addNew(.User, "msg3");
    _ = buffer.addNew(.User, "msg4");
    _ = buffer.addNew(.User, "msg5");
    try std.testing.expect(window.shouldSummarize(&buffer));
}

test "SlidingWindow isWithinBudget" {
    var window = SlidingWindow.init();
    try std.testing.expect(window.isWithinBudget());
}

test "Summarizer init" {
    const summarizer = Summarizer.init();
    try std.testing.expect(summarizer.summary_ratio > 0);
    try std.testing.expectEqual(@as(usize, 0), summarizer.summaries_created);
}

test "Summarizer summarize" {
    var summarizer = Summarizer.init();
    var msgs: [2]Message = undefined;
    msgs[0] = Message.init(.User, "Hello this is a test message");
    msgs[1] = Message.init(.Assistant, "This is the response");
    const summary = summarizer.summarize(&msgs);
    try std.testing.expectEqual(MessageRole.Summary, summary.role);
    try std.testing.expect(summary.is_summarized);
    try std.testing.expectEqual(@as(usize, 2), summary.original_count);
}

test "Summarizer getCompressionRatio" {
    var summarizer = Summarizer.init();
    var msgs: [3]Message = undefined;
    msgs[0] = Message.init(.User, "Message one");
    msgs[1] = Message.init(.User, "Message two");
    msgs[2] = Message.init(.User, "Message three");
    _ = summarizer.summarize(&msgs);
    try std.testing.expect(summarizer.getCompressionRatio() > 0);
}

test "ContextConfig init" {
    const config = ContextConfig.init();
    try std.testing.expectEqual(DEFAULT_MAX_TOKENS, config.max_tokens);
    try std.testing.expect(config.auto_summarize);
}

test "ContextConfig withMaxTokens" {
    const config = ContextConfig.init().withMaxTokens(8192);
    try std.testing.expectEqual(@as(usize, 8192), config.max_tokens);
}

test "ContextConfig withWindowSize" {
    const config = ContextConfig.init().withWindowSize(20);
    try std.testing.expectEqual(@as(usize, 20), config.window_size);
}

test "ContextWindow init" {
    const context = ContextWindow.init();
    try std.testing.expectEqual(@as(usize, 0), context.count);
    try std.testing.expect(!context.has_summary);
}

test "ContextWindow addMessage" {
    var context = ContextWindow.init();
    const msg = Message.init(.User, "test");
    try std.testing.expect(context.addMessage(msg));
    try std.testing.expectEqual(@as(usize, 1), context.count);
}

test "ContextWindow getEffectiveMessageCount" {
    var context = ContextWindow.init();
    const msg = Message.init(.User, "test");
    _ = context.addMessage(msg);
    var summary = Message.init(.Summary, "summary");
    summary.markSummarized(5);
    _ = context.addMessage(summary);
    try std.testing.expectEqual(@as(usize, 7), context.getEffectiveMessageCount());
}

test "LongContextStats init" {
    const stats = LongContextStats.init();
    try std.testing.expectEqual(@as(usize, 0), stats.messages_added);
    try std.testing.expectEqual(@as(usize, 0), stats.summaries_created);
}

test "LongContextStats getCompressionRatio" {
    var stats = LongContextStats.init();
    stats.total_tokens_processed = 100;
    stats.tokens_saved = 50;
    try std.testing.expect(stats.getCompressionRatio() > 0);
}

test "LongContextEngine init" {
    const engine = LongContextEngine.init();
    try std.testing.expectEqual(@as(usize, 0), engine.getMessageCount());
}

test "LongContextEngine addMessage" {
    var engine = LongContextEngine.init();
    try std.testing.expect(engine.addMessage(.User, "hello"));
    try std.testing.expectEqual(@as(usize, 1), engine.getMessageCount());
}

test "LongContextEngine addUserMessage" {
    var engine = LongContextEngine.init();
    try std.testing.expect(engine.addUserMessage("hello user"));
    try std.testing.expectEqual(@as(usize, 1), engine.getMessageCount());
}

test "LongContextEngine addAssistantMessage" {
    var engine = LongContextEngine.init();
    try std.testing.expect(engine.addAssistantMessage("hello assistant"));
    try std.testing.expectEqual(@as(usize, 1), engine.getMessageCount());
}

test "LongContextEngine addSystemMessage" {
    var engine = LongContextEngine.init();
    try std.testing.expect(engine.addSystemMessage("system prompt"));
    try std.testing.expectEqual(@as(usize, 1), engine.getMessageCount());
}

test "LongContextEngine getContext" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("hello");
    _ = engine.addAssistantMessage("hi there");
    const context = engine.getContext();
    try std.testing.expect(context.count >= 2);
}

test "LongContextEngine getLastNMessages" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("one");
    _ = engine.addUserMessage("two");
    _ = engine.addUserMessage("three");
    const context = engine.getLastNMessages(2);
    try std.testing.expectEqual(@as(usize, 2), context.count);
}

test "LongContextEngine setMessagePriority" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("test");
    try std.testing.expect(engine.setMessagePriority(0, .High));
}

test "LongContextEngine pinMessage" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("important");
    try std.testing.expect(engine.pinMessage(0));
}

test "LongContextEngine getStats" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("test");
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.messages_added);
}

test "LongContextEngine reset" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("test");
    engine.reset();
    try std.testing.expectEqual(@as(usize, 0), engine.getMessageCount());
}

test "LongContextEngine setConfig" {
    var engine = LongContextEngine.init();
    const config = ContextConfig.init().withMaxTokens(8192).withWindowSize(20);
    engine.setConfig(config);
    try std.testing.expectEqual(@as(usize, 8192), engine.config.max_tokens);
    try std.testing.expectEqual(@as(usize, 20), engine.config.window_size);
}

test "LongContextEngine multiple messages" {
    var engine = LongContextEngine.init();
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = engine.addUserMessage("user message");
        _ = engine.addAssistantMessage("assistant response");
    }
    try std.testing.expectEqual(@as(usize, 40), engine.getMessageCount());
}

test "LongContextEngine auto summarization" {
    var engine = LongContextEngine.initWithConfig(
        ContextConfig.init().withWindowSize(5).withAutoSummarize(true),
    );
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = engine.addUserMessage("user message content here");
        _ = engine.addAssistantMessage("assistant response content");
    }
    // Should have created summaries
    try std.testing.expect(engine.getSummaryCount() > 0);
}

test "LongContextEngine token tracking" {
    var engine = LongContextEngine.init();
    _ = engine.addUserMessage("hello world this is a test");
    const tokens = engine.getTotalTokens();
    try std.testing.expect(tokens > 0);
}

test "Integration: full conversation flow" {
    var engine = LongContextEngine.init();

    // Add system message
    _ = engine.addSystemMessage("You are a helpful assistant.");

    // Simulate conversation
    _ = engine.addUserMessage("What is the weather like?");
    _ = engine.addAssistantMessage("I don't have access to weather data.");
    _ = engine.addUserMessage("Can you tell me a joke?");
    _ = engine.addAssistantMessage("Why did the chicken cross the road?");

    // Get context
    const context = engine.getContext();
    try std.testing.expect(context.count >= 5);

    // Get stats
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 5), stats.messages_added);
}
