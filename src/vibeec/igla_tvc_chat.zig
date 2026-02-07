// ═══════════════════════════════════════════════════════════════════════════════
// IGLA TVC CHAT — Distributed Continual Learning Chat Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wraps IglaLocalChat with TVC (Ternary Vector Corpus) support:
// - TVC HIT: Return cached response (skip pattern matching)
// - TVC MISS: Pattern match, then store to TVC for future
// - Distributed: Share patterns across nodes via .tvc files
//
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL | TVC DISTRIBUTED
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const igla_chat = @import("igla_chat");
const tvc_corpus = @import("tvc_corpus");

const IglaLocalChat = igla_chat.IglaLocalChat;
const ChatResponse = igla_chat.ChatResponse;
const ChatCategory = igla_chat.ChatCategory;
const Language = igla_chat.Language;
const TVCCorpus = tvc_corpus.TVCCorpus;
const TVCSearchResult = tvc_corpus.TVCSearchResult;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// TVC similarity threshold for chat (slightly lower than pipeline)
pub const CHAT_TVC_THRESHOLD: f64 = 0.55;

/// Auto-save interval (every N stores)
pub const CHAT_AUTOSAVE_INTERVAL: u32 = 5;

// ═══════════════════════════════════════════════════════════════════════════════
// TVC CHAT RESPONSE
// ═══════════════════════════════════════════════════════════════════════════════

/// Extended chat response with TVC info
pub const TVCChatResponse = struct {
    /// Base response
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,

    /// TVC source info
    from_tvc: bool,
    tvc_similarity: f64,
    tvc_entry_id: ?u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// IGLA TVC CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaTVCChat = struct {
    /// Base chat engine
    base_chat: IglaLocalChat,

    /// TVC Corpus (optional - null if disabled)
    corpus: ?*TVCCorpus,

    /// TVC settings
    similarity_threshold: f64,
    auto_store: bool,

    /// Statistics
    tvc_hits: u64,
    tvc_misses: u64,
    tvc_stores: u64,

    /// Auto-save path (optional)
    autosave_path: ?[]const u8,
    stores_since_save: u32,

    const Self = @This();

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize without TVC (backwards compatible)
    pub fn init() Self {
        return Self{
            .base_chat = IglaLocalChat.init(),
            .corpus = null,
            .similarity_threshold = CHAT_TVC_THRESHOLD,
            .auto_store = true,
            .tvc_hits = 0,
            .tvc_misses = 0,
            .tvc_stores = 0,
            .autosave_path = null,
            .stores_since_save = 0,
        };
    }

    /// Initialize with TVC support
    pub fn initWithTVC(corpus: *TVCCorpus) Self {
        return Self{
            .base_chat = IglaLocalChat.init(),
            .corpus = corpus,
            .similarity_threshold = CHAT_TVC_THRESHOLD,
            .auto_store = true,
            .tvc_hits = 0,
            .tvc_misses = 0,
            .tvc_stores = 0,
            .autosave_path = null,
            .stores_since_save = 0,
        };
    }

    /// Enable auto-save
    pub fn enableAutosave(self: *Self, path: []const u8) void {
        self.autosave_path = path;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Respond with TVC support
    pub fn respond(self: *Self, query: []const u8) TVCChatResponse {
        // Step 1: Check TVC first (if enabled)
        if (self.corpus) |corpus| {
            if (corpus.search(query, self.similarity_threshold)) |tvc_result| {
                self.tvc_hits += 1;
                return TVCChatResponse{
                    .response = tvc_result.response,
                    .category = .Unknown, // TVC doesn't store category
                    .language = .Unknown, // TVC doesn't store language
                    .confidence = @floatCast(tvc_result.similarity),
                    .from_tvc = true,
                    .tvc_similarity = tvc_result.similarity,
                    .tvc_entry_id = tvc_result.entry_id,
                };
            }
        }

        // Step 2: TVC miss - use pattern matching
        self.tvc_misses += 1;
        const base_response = self.base_chat.respond(query);

        // Step 3: Store to TVC for future queries
        if (self.auto_store and self.corpus != null) {
            self.storeToTVC(query, base_response.response);
        }

        return TVCChatResponse{
            .response = base_response.response,
            .category = base_response.category,
            .language = base_response.language,
            .confidence = base_response.confidence,
            .from_tvc = false,
            .tvc_similarity = 0.0,
            .tvc_entry_id = null,
        };
    }

    /// Store query/response pair to TVC
    fn storeToTVC(self: *Self, query: []const u8, response: []const u8) void {
        if (self.corpus) |corpus| {
            _ = corpus.store(query, response) catch {
                return; // Silent fail - don't break chat flow
            };
            self.tvc_stores += 1;
            self.stores_since_save += 1;

            // Auto-save if configured
            if (self.autosave_path) |path| {
                if (self.stores_since_save >= CHAT_AUTOSAVE_INTERVAL) {
                    corpus.save(path) catch {};
                    self.stores_since_save = 0;
                }
            }
        }
    }

    /// Check if query is conversational
    pub fn isConversational(query: []const u8) bool {
        return IglaLocalChat.isConversational(query);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get TVC hit rate
    pub fn getTVCHitRate(self: *const Self) f64 {
        const total = self.tvc_hits + self.tvc_misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.tvc_hits)) / @as(f64, @floatFromInt(total));
    }

    /// Get statistics
    pub fn getStats(self: *const Self) TVCChatStats {
        const base_stats = self.base_chat.getStats();
        return TVCChatStats{
            .total_chats = base_stats.total_chats,
            .patterns_available = base_stats.patterns_available,
            .categories = base_stats.categories,
            .tvc_enabled = self.corpus != null,
            .tvc_hits = self.tvc_hits,
            .tvc_misses = self.tvc_misses,
            .tvc_stores = self.tvc_stores,
            .tvc_hit_rate = self.getTVCHitRate(),
            .tvc_corpus_size = if (self.corpus) |c| c.count else 0,
        };
    }

    /// Print statistics
    pub fn printStats(self: *const Self) void {
        const stats = self.getStats();
        const GOLDEN = "\x1b[38;2;255;215;0m";
        const GREEN = "\x1b[38;2;0;229;153m";
        const CYAN = "\x1b[38;2;0;255;255m";
        const RESET = "\x1b[0m";

        std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}              IGLA TVC CHAT STATISTICS{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
        std.debug.print("Total chats:       {d}\n", .{stats.total_chats});
        std.debug.print("Patterns:          {d}\n", .{stats.patterns_available});
        std.debug.print("TVC Enabled:       {s}{s}{s}\n", .{ if (stats.tvc_enabled) GREEN else CYAN, if (stats.tvc_enabled) "Yes" else "No", RESET });
        if (stats.tvc_enabled) {
            std.debug.print("TVC Hits:          {s}{d}{s}\n", .{ GREEN, stats.tvc_hits, RESET });
            std.debug.print("TVC Misses:        {d}\n", .{stats.tvc_misses});
            std.debug.print("TVC Hit Rate:      {s}{d:.1}%{s}\n", .{ GREEN, stats.tvc_hit_rate * 100, RESET });
            std.debug.print("TVC Corpus Size:   {d}\n", .{stats.tvc_corpus_size});
        }
        std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });
    }
};

/// TVC Chat statistics
pub const TVCChatStats = struct {
    total_chats: usize,
    patterns_available: usize,
    categories: usize,
    tvc_enabled: bool,
    tvc_hits: u64,
    tvc_misses: u64,
    tvc_stores: u64,
    tvc_hit_rate: f64,
    tvc_corpus_size: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEMO
// ═══════════════════════════════════════════════════════════════════════════════

/// Demo TVC chat
pub fn demoTVCChat() !void {
    const GOLDEN = "\x1b[38;2;255;215;0m";
    const GREEN = "\x1b[38;2;0;229;153m";
    const CYAN = "\x1b[38;2;0;255;255m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              IGLA TVC CHAT DEMO{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    var corpus = TVCCorpus.init();
    var chat = IglaTVCChat.initWithTVC(&corpus);

    // First query - TVC miss, pattern match
    std.debug.print("{s}Query 1:{s} \"Hello!\"\n", .{ CYAN, RESET });
    const r1 = chat.respond("Hello!");
    std.debug.print("Response: {s}\n", .{r1.response});
    std.debug.print("From TVC: {s}{s}{s}\n\n", .{ if (r1.from_tvc) GREEN else CYAN, if (r1.from_tvc) "Yes" else "No", RESET });

    // Second query - same, should hit TVC
    std.debug.print("{s}Query 2:{s} \"Hello!\" (repeat)\n", .{ CYAN, RESET });
    const r2 = chat.respond("Hello!");
    std.debug.print("Response: {s}\n", .{r2.response});
    std.debug.print("From TVC: {s}{s}{s} (similarity: {d:.3})\n\n", .{ if (r2.from_tvc) GREEN else CYAN, if (r2.from_tvc) "Yes (cached!)" else "No", RESET, r2.tvc_similarity });

    // Third query - similar
    std.debug.print("{s}Query 3:{s} \"Hi there!\"\n", .{ CYAN, RESET });
    const r3 = chat.respond("Hi there!");
    std.debug.print("Response: {s}\n", .{r3.response});
    std.debug.print("From TVC: {s}{s}{s}\n\n", .{ if (r3.from_tvc) GREEN else CYAN, if (r3.from_tvc) "Yes" else "No", RESET });

    chat.printStats();

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY | TVC DISTRIBUTED{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "IglaTVCChat without TVC" {
    var chat = IglaTVCChat.init();
    const response = chat.respond("Hello!");
    try std.testing.expect(!response.from_tvc);
    try std.testing.expect(response.confidence > 0);
}

test "IglaTVCChat with TVC" {
    var corpus = TVCCorpus.init();
    var chat = IglaTVCChat.initWithTVC(&corpus);

    // First query - miss
    const r1 = chat.respond("Hello there!");
    try std.testing.expect(!r1.from_tvc);

    // Same query - should hit
    const r2 = chat.respond("Hello there!");
    try std.testing.expect(r2.from_tvc);
    try std.testing.expect(r2.tvc_similarity >= CHAT_TVC_THRESHOLD);
}

test "IglaTVCChat statistics" {
    var corpus = TVCCorpus.init();
    var chat = IglaTVCChat.initWithTVC(&corpus);

    _ = chat.respond("Test query 1");
    _ = chat.respond("Test query 1"); // Should hit TVC
    _ = chat.respond("Different query");

    const stats = chat.getStats();
    try std.testing.expect(stats.tvc_enabled);
    try std.testing.expect(stats.tvc_hits == 1);
    try std.testing.expect(stats.tvc_misses == 2);
}
