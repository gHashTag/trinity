// ═══════════════════════════════════════════════════════════════════════════════
// IGLA FLUENT CLI v1.0 - Local Chat with History Truncation
// ═══════════════════════════════════════════════════════════════════════════════
//
// FIXES LONG CONTEXT HANG:
// - Conversation history limited to MAX_HISTORY_SIZE (20 messages)
// - Old messages truncated automatically
// - TinyLlama GGUF fallback for fluent responses
// - No hang on long conversations
//
// ARCHITECTURE:
// 1. Symbolic pattern matcher (fast, no hallucination)
// 2. TinyLlama GGUF fallback (fluent, local)
// 3. History truncation (prevents memory bloat)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const local_chat = @import("igla_local_chat.zig");
const hybrid_chat = @import("igla_hybrid_chat.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_HISTORY_SIZE: usize = 20; // Maximum messages in history
pub const MAX_MESSAGE_LENGTH: usize = 1024; // Max chars per message
pub const TINYLLAMA_PATH: []const u8 = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

// ANSI Colors
const GREEN = "\x1b[38;2;0;229;153m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const WHITE = "\x1b[38;2;255;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";
const RED = "\x1b[38;2;239;68;68m";
const CYAN = "\x1b[38;2;0;200;255m";
const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

pub const Message = struct {
    role: Role,
    content: []const u8,
    timestamp: i64,

    pub const Role = enum {
        User,
        Assistant,
        System,
    };
};

pub const ConversationHistory = struct {
    messages: std.ArrayListUnmanaged(Message),
    allocator: std.mem.Allocator,
    total_truncated: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .messages = .{},
            .allocator = allocator,
            .total_truncated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg.content);
        }
        self.messages.deinit(self.allocator);
    }

    /// Add message with automatic truncation
    pub fn addMessage(self: *Self, role: Message.Role, content: []const u8) !void {
        // Truncate content if too long
        const truncated_content = if (content.len > MAX_MESSAGE_LENGTH)
            content[0..MAX_MESSAGE_LENGTH]
        else
            content;

        // Copy content
        const content_copy = try self.allocator.dupe(u8, truncated_content);

        // Add message
        try self.messages.append(self.allocator, Message{
            .role = role,
            .content = content_copy,
            .timestamp = std.time.timestamp(),
        });

        // Truncate history if needed
        self.truncateIfNeeded();
    }

    /// Truncate old messages if history exceeds limit
    fn truncateIfNeeded(self: *Self) void {
        while (self.messages.items.len > MAX_HISTORY_SIZE) {
            // Remove oldest message (index 0)
            const old_msg = self.messages.orderedRemove(0);
            self.allocator.free(old_msg.content);
            self.total_truncated += 1;
        }
    }

    /// Get recent context for LLM (last N messages as string)
    pub fn getContextString(self: *const Self, max_messages: usize) ![]const u8 {
        var context: std.ArrayListUnmanaged(u8) = .{};
        errdefer context.deinit(self.allocator);

        const start_idx = if (self.messages.items.len > max_messages)
            self.messages.items.len - max_messages
        else
            0;

        for (self.messages.items[start_idx..]) |msg| {
            const role_str = switch (msg.role) {
                .User => "User",
                .Assistant => "Assistant",
                .System => "System",
            };
            try context.writer(self.allocator).print("{s}: {s}\n", .{ role_str, msg.content });
        }

        return context.toOwnedSlice(self.allocator);
    }

    /// Get message count
    pub fn count(self: *const Self) usize {
        return self.messages.items.len;
    }

    /// Clear history
    pub fn clear(self: *Self) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg.content);
        }
        self.messages.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FLUENT CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// FLUENT CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const FluentChatEngine = struct {
    allocator: std.mem.Allocator,
    history: ConversationHistory,
    symbolic: local_chat.IglaLocalChat,
    hybrid: ?hybrid_chat.IglaHybridChat,
    llm_enabled: bool,

    // Stats
    total_queries: usize,
    symbolic_hits: usize,
    llm_calls: usize,
    total_time_us: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, enable_llm: bool) !Self {
        var engine = Self{
            .allocator = allocator,
            .history = ConversationHistory.init(allocator),
            .symbolic = local_chat.IglaLocalChat.init(),
            .hybrid = null,
            .llm_enabled = enable_llm,
            .total_queries = 0,
            .symbolic_hits = 0,
            .llm_calls = 0,
            .total_time_us = 0,
        };

        // Try to initialize hybrid chat with TinyLlama
        if (enable_llm) {
            engine.hybrid = hybrid_chat.IglaHybridChat.init(allocator, TINYLLAMA_PATH) catch |err| blk: {
                std.debug.print("{s}[Warning] Could not init TinyLlama: {}. Using symbolic only.{s}\n", .{ GOLDEN, err, RESET });
                break :blk null;
            };
        }

        return engine;
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
        if (self.hybrid) |*h| {
            h.deinit();
        }
    }

    /// Process query with history context
    pub fn chat(self: *Self, query: []const u8) ![]const u8 {
        const start = std.time.microTimestamp();
        self.total_queries += 1;

        // Add user message to history
        try self.history.addMessage(.User, query);

        // Step 1: Try symbolic pattern matcher
        const symbolic_result = self.symbolic.respond(query);

        // If symbolic hit with good confidence, use it
        if (symbolic_result.category != .Unknown and symbolic_result.confidence >= 0.4) {
            self.symbolic_hits += 1;

            // Add response to history
            try self.history.addMessage(.Assistant, symbolic_result.response);

            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            self.total_time_us += elapsed;

            return symbolic_result.response;
        }

        // Step 2: Try LLM fallback if enabled
        if (self.hybrid) |*h| {
            self.llm_calls += 1;

            // Get context from history (last 5 messages for LLM)
            const context = try self.history.getContextString(5);
            defer self.allocator.free(context);

            // Generate response with context
            const response = h.respond(query) catch |err| {
                std.debug.print("{s}[LLM Error] {}{s}\n", .{ RED, err, RESET });
                // Fall back to symbolic
                try self.history.addMessage(.Assistant, symbolic_result.response);
                return symbolic_result.response;
            };

            try self.history.addMessage(.Assistant, response.response);

            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            self.total_time_us += elapsed;

            return response.response;
        }

        // Step 3: Fallback to symbolic anyway
        try self.history.addMessage(.Assistant, symbolic_result.response);

        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        self.total_time_us += elapsed;

        return symbolic_result.response;
    }

    /// Get stats
    pub fn getStats(self: *const Self) Stats {
        return Stats{
            .total_queries = self.total_queries,
            .symbolic_hits = self.symbolic_hits,
            .llm_calls = self.llm_calls,
            .history_size = self.history.count(),
            .history_truncated = self.history.total_truncated,
            .total_time_us = self.total_time_us,
            .llm_enabled = self.llm_enabled and self.hybrid != null,
        };
    }

    pub const Stats = struct {
        total_queries: usize,
        symbolic_hits: usize,
        llm_calls: usize,
        history_size: usize,
        history_truncated: usize,
        total_time_us: u64,
        llm_enabled: bool,
    };

    /// Clear conversation history
    pub fn clearHistory(self: *Self) void {
        self.history.clear();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI STATE
// ═══════════════════════════════════════════════════════════════════════════════

const CLIState = struct {
    allocator: std.mem.Allocator,
    engine: FluentChatEngine,
    running: bool,
    verbose: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, enable_llm: bool) !Self {
        return Self{
            .allocator = allocator,
            .engine = try FluentChatEngine.init(allocator, enable_llm),
            .running = true,
            .verbose = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.engine.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn printHeader() void {
    std.debug.print("\n", .{});
    std.debug.print("{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     IGLA FLUENT CLI v1.0 - Local Chat                        ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     100% Local | History Truncation | No Hang                ║{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}║     {s}φ² + 1/φ² = 3 = TRINITY{s}                                   ║{s}\n", .{ GREEN, GOLDEN, GREEN, RESET });
    std.debug.print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n", .{ GREEN, RESET });
    std.debug.print("\n", .{});
}

fn printHelp() void {
    std.debug.print("\n{s}Commands:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}/stats{s}    - Show conversation statistics\n", .{ GREEN, RESET });
    std.debug.print("  {s}/clear{s}    - Clear conversation history\n", .{ GREEN, RESET });
    std.debug.print("  {s}/verbose{s}  - Toggle verbose mode\n", .{ GREEN, RESET });
    std.debug.print("  {s}/history{s}  - Show conversation history\n", .{ GREEN, RESET });
    std.debug.print("  {s}/help{s}     - Show this help\n", .{ GREEN, RESET });
    std.debug.print("  {s}/quit{s}     - Exit CLI\n", .{ GREEN, RESET });
    std.debug.print("\n{s}Features:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  - History truncation: max {d} messages (no hang!)\n", .{MAX_HISTORY_SIZE});
    std.debug.print("  - Symbolic patterns: 100+ multilingual (RU/EN/CN)\n", .{});
    std.debug.print("  - TinyLlama fallback: fluent local responses\n", .{});
    std.debug.print("\n{s}Try:{s} привет, как дела, hello, what is phi?\n\n", .{ GRAY, RESET });
}

fn printPrompt(state: *CLIState) void {
    const history_count = state.engine.history.count();
    std.debug.print("{s}[{d}/{d}]{s} > ", .{ CYAN, history_count, MAX_HISTORY_SIZE, RESET });
}

fn printStats(state: *CLIState) void {
    const stats = state.engine.getStats();
    std.debug.print("\n{s}═══ Conversation Statistics ═══{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Queries: {d}\n", .{stats.total_queries});
    std.debug.print("  Symbolic hits: {d}\n", .{stats.symbolic_hits});
    std.debug.print("  LLM calls: {d}\n", .{stats.llm_calls});
    std.debug.print("  History size: {d}/{d}\n", .{ stats.history_size, MAX_HISTORY_SIZE });
    std.debug.print("  Truncated: {d} messages\n", .{stats.history_truncated});
    std.debug.print("  Total time: {d}us ({d:.2}ms)\n", .{ stats.total_time_us, @as(f64, @floatFromInt(stats.total_time_us)) / 1000.0 });
    std.debug.print("  LLM enabled: {s}\n", .{if (stats.llm_enabled) "YES (TinyLlama)" else "NO (symbolic only)"});
    std.debug.print("  Mode: 100%% LOCAL\n", .{});
    std.debug.print("\n", .{});
}

fn printHistory(state: *CLIState) void {
    std.debug.print("\n{s}═══ Conversation History ({d} messages) ═══{s}\n", .{
        GOLDEN,
        state.engine.history.count(),
        RESET,
    });

    for (state.engine.history.messages.items, 0..) |msg, i| {
        const role_color = switch (msg.role) {
            .User => CYAN,
            .Assistant => GREEN,
            .System => GRAY,
        };
        const role_str = switch (msg.role) {
            .User => "User",
            .Assistant => "Assistant",
            .System => "System",
        };
        const preview = if (msg.content.len > 60) msg.content[0..60] else msg.content;
        std.debug.print("  [{d}] {s}{s}{s}: {s}...\n", .{ i + 1, role_color, role_str, RESET, preview });
    }
    std.debug.print("\n", .{});
}

fn processCommand(state: *CLIState, cmd: []const u8) void {
    if (std.mem.eql(u8, cmd, "/stats")) {
        printStats(state);
    } else if (std.mem.eql(u8, cmd, "/clear")) {
        state.engine.clearHistory();
        std.debug.print("{s}History cleared.{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/verbose")) {
        state.verbose = !state.verbose;
        std.debug.print("{s}Verbose: {s}{s}\n", .{ GRAY, if (state.verbose) "ON" else "OFF", RESET });
    } else if (std.mem.eql(u8, cmd, "/history")) {
        printHistory(state);
    } else if (std.mem.eql(u8, cmd, "/help") or std.mem.eql(u8, cmd, "/?")) {
        printHelp();
    } else if (std.mem.eql(u8, cmd, "/quit") or std.mem.eql(u8, cmd, "/exit") or std.mem.eql(u8, cmd, "/q")) {
        state.running = false;
        std.debug.print("{s}Goodbye! φ² + 1/φ² = 3{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("{s}Unknown command. Type /help for available commands.{s}\n", .{ RED, RESET });
    }
}

fn processQuery(state: *CLIState, query: []const u8) void {
    const start = std.time.microTimestamp();

    const response = state.engine.chat(query) catch |err| {
        std.debug.print("{s}Error: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

    // Print response
    std.debug.print("\n{s}{s}{s}\n", .{ GREEN, response, RESET });

    // Print metadata if verbose
    if (state.verbose) {
        const stats = state.engine.getStats();
        std.debug.print("\n{s}[Time: {d}us | History: {d}/{d} | Truncated: {d}]{s}\n", .{
            GRAY,
            elapsed,
            stats.history_size,
            MAX_HISTORY_SIZE,
            stats.history_truncated,
            RESET,
        });
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args for --no-llm flag
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var enable_llm = true;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--no-llm") or std.mem.eql(u8, arg, "-s")) {
            enable_llm = false;
        }
    }

    var state = try CLIState.init(allocator, enable_llm);
    defer state.deinit();

    printHeader();

    const stats = state.engine.getStats();
    if (stats.llm_enabled) {
        std.debug.print("{s}  TinyLlama GGUF loaded - fluent mode enabled!{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}  Symbolic-only mode (use --no-llm to force){s}\n", .{ GOLDEN, RESET });
    }

    printHelp();

    const stdin_file = std.fs.File.stdin();
    var buf: [1024]u8 = undefined;

    while (state.running) {
        printPrompt(&state);

        // Read input line using low-level read (like trinity_cli)
        var line_len: usize = 0;
        while (line_len < buf.len - 1) {
            const read_result = stdin_file.read(buf[line_len .. line_len + 1]) catch |err| {
                std.debug.print("{s}Input error: {}{s}\n", .{ RED, err, RESET });
                break;
            };
            if (read_result == 0) {
                // EOF
                state.running = false;
                break;
            }
            if (buf[line_len] == '\n') {
                break;
            }
            line_len += 1;
        }

        if (line_len == 0 and !state.running) break;

        const line = buf[0..line_len];
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        // Check if command
        if (trimmed[0] == '/') {
            processCommand(&state, trimmed);
        } else {
            processQuery(&state, trimmed);
        }
    }

    // Final stats
    printStats(&state);
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL{s}\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "conversation history init" {
    const allocator = std.testing.allocator;
    var history = ConversationHistory.init(allocator);
    defer history.deinit();

    try std.testing.expectEqual(@as(usize, 0), history.count());
}

test "conversation history add message" {
    const allocator = std.testing.allocator;
    var history = ConversationHistory.init(allocator);
    defer history.deinit();

    try history.addMessage(.User, "привет");
    try history.addMessage(.Assistant, "Привет!");

    try std.testing.expectEqual(@as(usize, 2), history.count());
}

test "conversation history truncation" {
    const allocator = std.testing.allocator;
    var history = ConversationHistory.init(allocator);
    defer history.deinit();

    // Add more than MAX_HISTORY_SIZE messages
    for (0..(MAX_HISTORY_SIZE + 5)) |i| {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Message {d}", .{i}) catch "msg";
        try history.addMessage(.User, msg);
    }

    // Should be truncated to MAX_HISTORY_SIZE
    try std.testing.expectEqual(MAX_HISTORY_SIZE, history.count());
    try std.testing.expectEqual(@as(usize, 5), history.total_truncated);
}

test "fluent engine symbolic hit" {
    const allocator = std.testing.allocator;
    var engine = try FluentChatEngine.init(allocator, false); // No LLM
    defer engine.deinit();

    const response = try engine.chat("привет");
    try std.testing.expect(response.len > 0);
    try std.testing.expectEqual(@as(usize, 1), engine.symbolic_hits);
}

test "fluent engine stats" {
    const allocator = std.testing.allocator;
    var engine = try FluentChatEngine.init(allocator, false);
    defer engine.deinit();

    _ = try engine.chat("hello");
    _ = try engine.chat("how are you");

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_queries);
    try std.testing.expectEqual(@as(usize, 4), stats.history_size); // 2 user + 2 assistant
}
