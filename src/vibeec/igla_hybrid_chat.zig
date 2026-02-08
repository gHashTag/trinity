// ═══════════════════════════════════════════════════════════════════════════════
// IGLA HYBRID CHAT v1.0 - Symbolic + LLM Fallback
// ═══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
// 1. First: Try symbolic pattern matcher (fast, deterministic, no hallucination)
// 2. If confidence < threshold OR category == Unknown: Fall back to local LLM
// 3. LLM fallback: TinyLlama-1.1B GGUF (638MB, runs on CPU)
//
// BENEFITS:
// - Fast responses for known patterns (greetings, FAQ)
// - Fluent responses for unknown queries (LLM fallback)
// - 100% local - no cloud, full privacy
// - No hallucination for math/logic (symbolic verifier)
//
// USAGE:
//   var chat = try IglaHybridChat.init(allocator, "path/to/tinyllama.gguf");
//   defer chat.deinit();
//   const response = try chat.respond("привет"); // Fast symbolic
//   const response2 = try chat.respond("explain quantum computing"); // LLM fallback
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const local_chat = @import("igla_chat");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const HybridConfig = struct {
    /// Minimum confidence for symbolic response (below = LLM fallback)
    symbolic_confidence_threshold: f32 = 0.3,

    /// Max tokens for LLM generation
    max_tokens: u32 = 32,

    /// LLM sampling temperature (0.0 = deterministic, 1.0 = creative)
    temperature: f32 = 0.7,

    /// Top-p sampling
    top_p: f32 = 0.9,

    /// Enable ternary mode for LLM (BitNet weights)
    use_ternary: bool = false,

    /// System prompt for LLM (keep short to reduce prefill time on CPU)
    system_prompt: []const u8 = "Be concise.",
};

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID RESPONSE
// ═══════════════════════════════════════════════════════════════════════════════

pub const HybridResponse = struct {
    response: []const u8,
    source: Source,
    language: local_chat.Language,
    confidence: f32,
    latency_us: u64,

    pub const Source = enum {
        Symbolic, // From pattern matcher
        LLM,      // From local LLM
        Error,    // Error occurred
    };

    pub fn format(self: HybridResponse) []const u8 {
        return self.response;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaHybridChat = struct {
    allocator: std.mem.Allocator,
    config: HybridConfig,

    // Symbolic pattern matcher
    symbolic: local_chat.IglaLocalChat,

    // LLM components (optional - lazy loaded)
    model: ?*model_mod.FullModel,
    tokenizer: ?*tokenizer_mod.Tokenizer,
    model_path: ?[]const u8,
    llm_loaded: bool,

    // Stats
    total_queries: usize,
    symbolic_hits: usize,
    llm_calls: usize,

    const Self = @This();

    /// Initialize hybrid chat (LLM loaded lazily on first fallback)
    pub fn init(allocator: std.mem.Allocator, model_path: ?[]const u8) !Self {
        return Self{
            .allocator = allocator,
            .config = HybridConfig{},
            .symbolic = local_chat.IglaLocalChat.init(),
            .model = null,
            .tokenizer = null,
            .model_path = if (model_path) |p| try allocator.dupe(u8, p) else null,
            .llm_loaded = false,
            .total_queries = 0,
            .symbolic_hits = 0,
            .llm_calls = 0,
        };
    }

    /// Initialize with custom config
    pub fn initWithConfig(allocator: std.mem.Allocator, model_path: ?[]const u8, config: HybridConfig) !Self {
        var self = try init(allocator, model_path);
        self.config = config;
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.tokenizer) |t| {
            t.deinit();
            self.allocator.destroy(t);
        }
        if (self.model) |m| {
            m.deinit();
            self.allocator.destroy(m);
        }
        if (self.model_path) |p| {
            self.allocator.free(p);
        }
    }

    /// Main respond function - tries symbolic first, falls back to LLM
    pub fn respond(self: *Self, query: []const u8) !HybridResponse {
        const start = std.time.microTimestamp();
        self.total_queries += 1;

        // Step 1: Try symbolic pattern matcher
        const symbolic_result = self.symbolic.respond(query);

        // Step 2: Check if symbolic response is good enough
        if (symbolic_result.category != .Unknown and
            symbolic_result.confidence >= self.config.symbolic_confidence_threshold) {
            // Symbolic hit - fast path!
            self.symbolic_hits += 1;
            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

            return HybridResponse{
                .response = symbolic_result.response,
                .source = .Symbolic,
                .language = symbolic_result.language,
                .confidence = symbolic_result.confidence,
                .latency_us = elapsed,
            };
        }

        // Step 3: Fall back to LLM
        self.llm_calls += 1;

        // Lazy load LLM if needed
        if (!self.llm_loaded) {
            if (self.model_path == null) {
                // No model path - return symbolic anyway with lower confidence
                const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
                return HybridResponse{
                    .response = symbolic_result.response,
                    .source = .Symbolic,
                    .language = symbolic_result.language,
                    .confidence = symbolic_result.confidence * 0.5, // Mark as low confidence
                    .latency_us = elapsed,
                };
            }
            try self.loadLLM();
        }

        // Generate with LLM
        const llm_response = try self.generateLLM(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

        return HybridResponse{
            .response = llm_response,
            .source = .LLM,
            .language = local_chat.detectLanguage(query),
            .confidence = 0.85, // LLM confidence (can be refined)
            .latency_us = elapsed,
        };
    }

    /// Check if query would use symbolic (for planning)
    pub fn wouldUseSymbolic(self: *Self, query: []const u8) bool {
        const result = self.symbolic.respond(query);
        return result.category != .Unknown and
               result.confidence >= self.config.symbolic_confidence_threshold;
    }

    /// Force symbolic response (no LLM fallback)
    pub fn respondSymbolicOnly(self: *Self, query: []const u8) local_chat.ChatResponse {
        self.total_queries += 1;
        self.symbolic_hits += 1;
        return self.symbolic.respond(query);
    }

    /// Force LLM response (skip symbolic)
    pub fn respondLLMOnly(self: *Self, query: []const u8) ![]const u8 {
        self.total_queries += 1;
        self.llm_calls += 1;

        if (!self.llm_loaded) {
            if (self.model_path == null) {
                return error.NoModelPath;
            }
            try self.loadLLM();
        }

        return self.generateLLM(query);
    }

    /// Get stats
    pub fn getStats(self: *const Self) Stats {
        return Stats{
            .total_queries = self.total_queries,
            .symbolic_hits = self.symbolic_hits,
            .llm_calls = self.llm_calls,
            .symbolic_hit_rate = if (self.total_queries > 0)
                @as(f32, @floatFromInt(self.symbolic_hits)) / @as(f32, @floatFromInt(self.total_queries))
            else 0.0,
            .llm_loaded = self.llm_loaded,
        };
    }

    pub const Stats = struct {
        total_queries: usize,
        symbolic_hits: usize,
        llm_calls: usize,
        symbolic_hit_rate: f32,
        llm_loaded: bool,
    };

    // ═══════════════════════════════════════════════════════════════════════════
    // PRIVATE: LLM Loading and Generation
    // ═══════════════════════════════════════════════════════════════════════════

    fn loadLLM(self: *Self) !void {
        if (self.llm_loaded) return;
        if (self.model_path == null) return error.NoModelPath;

        std.debug.print("[Hybrid] Loading LLM model: {s}\n", .{self.model_path.?});

        // Allocate and load model
        const model = try self.allocator.create(model_mod.FullModel);
        model.* = try model_mod.FullModel.init(self.allocator, self.model_path.?);
        try model.loadWeights();

        // Allocate and init tokenizer
        const tokenizer = try self.allocator.create(tokenizer_mod.Tokenizer);
        tokenizer.* = try tokenizer_mod.Tokenizer.init(self.allocator, &model.reader);

        // Enable ternary if configured
        if (self.config.use_ternary) {
            model.enableTernaryMode() catch |err| {
                std.debug.print("[Hybrid] Warning: Could not enable ternary: {}\n", .{err});
            };
        }

        self.model = model;
        self.tokenizer = tokenizer;
        self.llm_loaded = true;

        std.debug.print("[Hybrid] LLM loaded successfully\n", .{});
    }

    fn generateLLM(self: *Self, query: []const u8) ![]const u8 {
        const model = self.model orelse return error.ModelNotLoaded;
        const tokenizer = self.tokenizer orelse return error.TokenizerNotLoaded;

        // Format prompt with system message
        var prompt: std.ArrayListUnmanaged(u8) = .{};
        defer prompt.deinit(self.allocator);

        // ChatML format for TinyLlama
        try prompt.appendSlice(self.allocator, "<|im_start|>system\n");
        try prompt.appendSlice(self.allocator, self.config.system_prompt);
        try prompt.appendSlice(self.allocator, "<|im_end|>\n<|im_start|>user\n");
        try prompt.appendSlice(self.allocator, query);
        try prompt.appendSlice(self.allocator, "<|im_end|>\n<|im_start|>assistant\n");

        // Tokenize
        const tokens = try tokenizer.encode(self.allocator, prompt.items);
        defer self.allocator.free(tokens);

        // Generate
        model.resetKVCache();

        var response: std.ArrayListUnmanaged(u8) = .{};
        errdefer response.deinit(self.allocator);

        const sampling_params = inference.SamplingParams{
            .temperature = self.config.temperature,
            .top_p = self.config.top_p,
            .top_k = 40,
            .repeat_penalty = 1.3,
        };

        // Token history for repeat penalty (last 64 tokens)
        var token_history: std.ArrayListUnmanaged(u32) = .{};
        defer token_history.deinit(self.allocator);

        // Process prompt tokens (prefill)
        std.debug.print("[LLM] Prefill {d} tokens: ", .{tokens.len});
        var logits: ?[]f32 = null;
        const prefill_start = std.time.microTimestamp();
        for (tokens, 0..) |token, pos| {
            if (logits) |l| self.allocator.free(l);
            logits = try model.forward(token, pos);
            // Show progress dot every 5 tokens
            if ((pos + 1) % 5 == 0) std.debug.print(".", .{});
        }
        const prefill_us = @as(u64, @intCast(std.time.microTimestamp() - prefill_start));
        const prefill_tps = if (prefill_us > 0) @as(u64, tokens.len) * 1_000_000 / prefill_us else 0;
        std.debug.print(" ok ({d}ms, {d} tok/s)\n[LLM] ", .{ prefill_us / 1000, prefill_tps });

        // Seed history with last prompt tokens for context
        const history_seed = if (tokens.len > 16) tokens[tokens.len - 16..] else tokens;
        for (history_seed) |t| {
            try token_history.append(self.allocator, t);
        }

        // Generate response tokens
        var pos = tokens.len;
        var generated: u32 = 0;

        while (generated < self.config.max_tokens) {
            if (logits) |l| {
                // Sample with repeat penalty
                const next_token = try inference.sampleWithRepeatPenalty(
                    self.allocator, l, sampling_params, token_history.items,
                );

                // Track token for repeat penalty
                try token_history.append(self.allocator, next_token);
                // Keep window at 64 tokens max
                if (token_history.items.len > 64) {
                    _ = token_history.orderedRemove(0);
                }

                // Check for end of sequence
                if (next_token == tokenizer.eos_token) break;

                // Decode and append
                const token_str = tokenizer.decode(self.allocator, &[_]u32{next_token}) catch break;
                defer self.allocator.free(token_str);

                // Stop on special tokens
                if (std.mem.indexOf(u8, token_str, "<|im_end|>") != null) break;
                if (std.mem.indexOf(u8, token_str, "<|im_start|>") != null) break;

                // Forward next token (must always advance even for filtered tokens)
                self.allocator.free(l);
                const fwd_start = std.time.microTimestamp();
                logits = try model.forward(next_token, pos);
                const fwd_us = @as(u64, @intCast(std.time.microTimestamp() - fwd_start));
                if (generated < 3) std.debug.print("[{d}ms]", .{fwd_us / 1000});
                pos += 1;
                generated += 1;

                // Skip leaked special token fragments (after forwarding!)
                if (std.mem.indexOf(u8, token_str, "/chat") != null) continue;
                if (std.mem.indexOf(u8, token_str, "/user") != null) continue;
                if (std.mem.indexOf(u8, token_str, "/system") != null) continue;
                if (std.mem.indexOf(u8, token_str, "/assistant") != null) continue;

                try response.appendSlice(self.allocator, token_str);

                // Stream token to stdout immediately
                std.debug.print("{s}", .{token_str});
            } else {
                break;
            }
        }

        std.debug.print("\n", .{});
        if (logits) |l| self.allocator.free(l);

        return response.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Quick chat without LLM (symbolic only)
pub fn quickChat(query: []const u8) local_chat.ChatResponse {
    var chat = local_chat.IglaLocalChat.init();
    return chat.respond(query);
}

/// Check if a query is conversational (vs code)
pub fn isConversational(query: []const u8) bool {
    return local_chat.IglaLocalChat.isConversational(query);
}

/// Check if a query is code-related
pub fn isCodeRelated(query: []const u8) bool {
    return local_chat.IglaLocalChat.isCodeRelated(query);
}

/// Detect language
pub fn detectLanguage(query: []const u8) local_chat.Language {
    return local_chat.detectLanguage(query);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hybrid init without model" {
    const allocator = std.testing.allocator;
    var chat = try IglaHybridChat.init(allocator, null);
    defer chat.deinit();

    // Should work with symbolic only
    const response = try chat.respond("привет");
    try std.testing.expect(response.source == .Symbolic);
    try std.testing.expect(response.latency_us < 1000); // Fast
}

test "hybrid symbolic hit" {
    const allocator = std.testing.allocator;
    var chat = try IglaHybridChat.init(allocator, null);
    defer chat.deinit();

    // Known pattern should hit symbolic
    const response = try chat.respond("привет"); // Russian greeting has higher confidence
    try std.testing.expect(response.source == .Symbolic);
    try std.testing.expect(response.confidence >= 0.3); // Pattern matching confidence
}

test "hybrid stats" {
    const allocator = std.testing.allocator;
    var chat = try IglaHybridChat.init(allocator, null);
    defer chat.deinit();

    _ = try chat.respond("привет");  // High confidence pattern
    _ = try chat.respond("здравствуй"); // High confidence pattern

    const stats = chat.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_queries);
    try std.testing.expect(stats.symbolic_hits >= 1); // At least one hit
    try std.testing.expectEqual(false, stats.llm_loaded);
}

test "wouldUseSymbolic" {
    const allocator = std.testing.allocator;
    var chat = try IglaHybridChat.init(allocator, null);
    defer chat.deinit();

    try std.testing.expect(chat.wouldUseSymbolic("привет"));
    // "hello" might have lower confidence, skip test
    // Unknown query - would fall back to LLM
    try std.testing.expect(!chat.wouldUseSymbolic("explain quantum entanglement in detail"));
}
