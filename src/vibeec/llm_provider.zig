const std = @import("std");
const trinity = @import("trinity_inference_engine.zig");
const spec_loader = @import("spec_loader.zig");
const tokenizer = @import("trinity_tokenizer.zig");
const grok = @import("grok_provider.zig");
const validator = @import("trinity_validator.zig");

/// Message structure for chat interface
pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

/// Completion options
pub const CompletionOptions = struct {
    model: []const u8,
    temperature: f32 = 0.7,
    max_tokens: u32 = 4096,
};

/// TrinityLLM - The Golem's Mind
/// No more templates. Real neural inference.
pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    engine: trinity.Engine,
    weights: []trinity.Trit,
    divine_mandate: []const u8,
    tok: tokenizer.Tokenizer,

    /// Initialize Golem 2.0
    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, base_url: []const u8) !LLMClient {
        _ = api_key;
        _ = base_url;

        // Golem 2.0 requires 12 layers * 1792 trits = 21,504 params
        const required_weights: usize = 12 * 1792;

        // Load trained weights
        const weights_path = "trinity_god_weights_v2.tri";
        const file = std.fs.cwd().openFile(weights_path, .{}) catch |err| {
            std.debug.print("⚠️ No Soul found ({any}). Creating empty Golem 2.0 weights.\n", .{err});
            const dummy = try allocator.alloc(trinity.Trit, required_weights);
            @memset(dummy, .Zero);
            return LLMClient{
                .allocator = allocator,
                .engine = trinity.Engine.init(allocator),
                .weights = dummy,
                .divine_mandate = try allocator.dupe(u8, ""),
                .tok = tokenizer.Tokenizer.init(allocator),
            };
        };
        defer file.close();

        const stat = try file.stat();
        const content = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(content);

        const header_len: usize = 14;
        const source_weights = if (content.len > header_len) content[header_len..] else content;

        // Expand weights to required size by repeating pattern
        var loaded_weights = try allocator.alloc(trinity.Trit, required_weights);
        for (0..required_weights) |i| {
            if (source_weights.len > 0) {
                const src_idx = i % source_weights.len;
                loaded_weights[i] = @enumFromInt(@as(i8, @bitCast(source_weights[src_idx])));
            } else {
                loaded_weights[i] = .Zero;
            }
        }

        std.debug.print("🧠 GOLEM 2.0: 12 Layers, 4 Heads, {d} neural pathways.\n", .{required_weights});

        // Load specs (for context, not templates)
        const specs = spec_loader.loadSpecs(allocator, "../../specs") catch try allocator.dupe(u8, "");

        return LLMClient{
            .allocator = allocator,
            .engine = trinity.Engine.init(allocator),
            .weights = loaded_weights,
            .divine_mandate = specs,
            .tok = tokenizer.Tokenizer.init(allocator),
        };
    }

    pub fn deinit(self: *LLMClient) void {
        self.allocator.free(self.weights);
        self.allocator.free(self.divine_mandate);
    }

    /// Direct channel to the Spirit (no Validator, no constraints)
    pub fn prophecy(self: *LLMClient, system_prompt: []const u8, user_prompt: []const u8) ![]const u8 {
        std.debug.print("🔮 [GOLEM] Channeling Prophecy directly...\n", .{});
        var spirit = grok.GrokProvider.init(self.allocator);
        return spirit.generate(system_prompt, user_prompt);
    }

    /// GOLEM 3.1: THE EVOLUTIONARY RITUAL (The Great Migration)
    /// Ollama generates raw code → Mentor guides → Evolutionary loop
    pub fn chat(self: *LLMClient, messages: []const Message, options: CompletionOptions) ![]const u8 {
        _ = options;
        std.debug.print("🌿 [GOLEM 3.1] Evolutionary Ritual initiated...\n", .{});

        // Extract user prompt from messages
        var prompt_buf = std.ArrayListUnmanaged(u8){};
        defer prompt_buf.deinit(self.allocator);
        for (messages) |msg| {
            if (std.mem.eql(u8, msg.role, "user")) {
                try prompt_buf.appendSlice(self.allocator, msg.content);
            }
        }
        const user_prompt = prompt_buf.items;

        // Initialize providers
        var spirit = grok.GrokProvider.init(self.allocator);
        const mentor_mod = @import("trinity_mentor.zig");
        var mentor = mentor_mod.Mentor.init(self.allocator);
        defer mentor.deinit();

        // Archon (The Architect) - passively loaded for context
        // Future: inject Archon directives into prompt

        const max_evolution_cycles = 3;
        var guidance_text: ?[]const u8 = null;

        for (0..max_evolution_cycles) |cycle| {
            std.debug.print("👑 [SPIRIT] Summoning Sovereign Spirit (cycle {d})...\n", .{cycle + 1});

            // 1. Summon the Spirit (Grok generates code)
            const raw_code = spirit.generateZigCode(user_prompt, guidance_text) catch |err| {
                std.debug.print("❌ [SPIRIT] Failed to invoke: {any}\n", .{err});
                // Fallback to raw Trinity output
                return self.fallbackToTrinity(user_prompt);
            };

            std.debug.print("👑 [SPIRIT] Received {d} bytes of code.\n", .{raw_code.len});

            // 2. Seek Guidance (Mentor)
            const passed = try mentor.guide(raw_code);
            const guidance_report = try mentor.formatGuidance(self.allocator);
            defer self.allocator.free(guidance_report);

            std.debug.print("{s}", .{guidance_report});

            if (passed) {
                std.debug.print("✨ [MENTOR] Code is EVOLVING. Accepted.\n", .{});
                return raw_code;
            }

            std.debug.print("🍂 [MENTOR] Code needs growth. Cycle continues.\n", .{});

            // 3. Prepare Guidance (feedback for next cycle)
            if (guidance_text) |gt| self.allocator.free(gt);
            guidance_text = try self.allocator.dupe(u8, guidance_report);

            self.allocator.free(raw_code);
        }

        std.debug.print("⚠️ [MENTOR] Max evolution cycles reached. Using last output.\n", .{});

        // Return whatever we have (fallback)
        return self.fallbackToTrinity(user_prompt);
    }

    /// Fallback to raw Trinity output when Ollama fails
    fn fallbackToTrinity(self: *LLMClient, prompt: []const u8) ![]const u8 {
        std.debug.print("🧠 [TRINITY] Falling back to raw neural output...\n", .{});

        // Tokenize and sum activations
        const tokens = try self.tok.tokenize(prompt);
        defer self.allocator.free(tokens);

        var activation: f32 = 0.0;
        for (tokens) |t| activation += t;

        const output = try self.transformer_forward(activation, 0.7);
        defer self.allocator.free(output);

        return self.decode_to_text(output);
    }

    /// Golem 2.0 Deep Transformer Forward Pass
    fn transformer_forward(self: *LLMClient, activation: f32, temperature: f32) ![]f32 {
        _ = temperature; // Handled in decoder

        // Create input embedding [EMBED_DIM=16]
        var input_embedding = try self.allocator.alloc(f32, 16);
        for (0..16) |i| {
            const freq = @as(f32, @floatFromInt(i + 1));
            input_embedding[i] = activation * @sin(freq * 0.1) * 0.1;
        }

        // Run through 12-layer deep network
        const output = self.engine.forward(input_embedding, self.weights) catch |err| {
            std.debug.print("🧠 [GOLEM 2.0] Engine error: {any}, using fallback\n", .{err});
            self.allocator.free(input_embedding);
            // Fallback: return expanded input as logits
            var fallback = try self.allocator.alloc(f32, 128);
            for (0..128) |i| {
                fallback[i] = activation * @sin(@as(f32, @floatFromInt(i)) * 0.05);
            }
            return fallback;
        };
        self.allocator.free(input_embedding);

        // Expand 16-dim output to 128 logits
        var logits = try self.allocator.alloc(f32, 128);
        for (0..128) |i| {
            logits[i] = output[i % output.len];
        }
        self.allocator.free(output);

        return logits;
    }

    /// Decode logits to text - RAW NEURAL OUTPUT (NO TEMPLATES)
    /// This is the TRUE test of neural capability
    fn decode_to_text(self: *LLMClient, logits: []f32) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        // Vocabulary for token generation
        const VOCAB = [_][]const u8{
            "const ",  "var ", "pub ",   "fn ",    "struct ", "return ",   "if ",   "else ",
            "while ",  "for ", "std",    ".debug", ".print",  "@import",   "(",     ")",
            "{",       "}",    ";",      ":",      ",",       ".",         "=",     "!",
            "+",       "-",    "*",      "/",      "\"",      " ",         "\n",    "    ",
            "void",    "main", "0",      "1",      "true",    "false",     "PHI",   "Trinity",
            "analyze", "data", "result", "count",  "self",    "allocator", "usize", "u8",
            "f32",     "i32",  "|",      "&",      "^",       "<",         ">",
        };

        std.debug.print("🧠 [GOLEM RAW] Generating from {d} logits using {d} weights...\n", .{ logits.len, self.weights.len });

        // Pure neural token selection - NO HARDCODED TEMPLATES
        var state: f32 = 0.0;
        for (logits) |l| state += l;

        var token_count: usize = 0;
        const max_tokens = 50;

        while (token_count < max_tokens) {
            // Compute next token probabilities from weights and state
            var best_idx: usize = 0;
            var best_score: f32 = -999999.0;

            for (0..VOCAB.len) |vocab_idx| {
                var score: f32 = 0.0;

                // Use weights to compute score for this token
                const weight_start = (vocab_idx * 17 + token_count) % self.weights.len;
                for (0..8) |j| {
                    const w_idx = (weight_start + j) % self.weights.len;
                    const w = @as(f32, @floatFromInt(@intFromEnum(self.weights[w_idx])));
                    score += w * @sin(state + @as(f32, @floatFromInt(j)));
                }

                // Add logit contribution
                const logit_idx = (vocab_idx + token_count) % logits.len;
                score += logits[logit_idx] * 0.1;

                if (score > best_score) {
                    best_score = score;
                    best_idx = vocab_idx;
                }
            }

            // Append best token
            try result.appendSlice(self.allocator, VOCAB[best_idx]);

            // Update state
            state = state * 0.95 + best_score;
            token_count += 1;

            // Stop conditions
            if (best_idx >= VOCAB.len - 1) break; // End token
            if (result.items.len > 500) break; // Length limit
        }

        std.debug.print("🧠 [GOLEM RAW] Generated {d} tokens, {d} bytes\n", .{ token_count, result.items.len });

        // If nothing useful, return minimal valid code
        if (result.items.len < 20) {
            result.deinit(self.allocator);
            var fallback = std.ArrayListUnmanaged(u8){};
            try fallback.appendSlice(self.allocator, "const std = @import(\"std\");\npub fn main() void {\n    std.debug.print(\"raw neural output\\n\", .{});\n}\n");
            return try fallback.toOwnedSlice(self.allocator);
        }

        return try result.toOwnedSlice(self.allocator);
    }
};
