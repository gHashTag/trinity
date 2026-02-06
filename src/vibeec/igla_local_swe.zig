// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL SWE - Pure Local Autonomous Coding Agent
// ═══════════════════════════════════════════════════════════════════════════════
//
// 100% LOCAL code generation using BitNet-2B model on Apple M1 Pro:
// - NO cloud APIs (no Groq, OpenAI, Anthropic, Zhipu)
// - NO fallback to external services
// - Pure local LLM inference with SIMD optimization
//
// Capabilities:
// - CodeGen: Generate new code from natural language
// - BugFix: Fix bugs in existing code
// - Refactor: Improve code structure
// - Explain: Explain code functionality
// - Test: Generate test cases
// - Document: Add documentation/comments
//
// Languages: Zig, VIBEE, Python, Rust, JavaScript, Go
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL | 100% LOCAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskType = enum {
    CodeGen,    // Generate new code
    BugFix,     // Fix bugs
    Refactor,   // Improve structure
    Explain,    // Explain code
    Test,       // Generate tests
    Document,   // Add docs/comments
    Reason,     // Chain-of-thought reasoning
};

pub const Language = enum {
    Zig,
    VIBEE,
    Python,
    Rust,
    JavaScript,
    Go,
    TypeScript,
    Unknown,

    pub fn name(self: Language) []const u8 {
        return switch (self) {
            .Zig => "Zig",
            .VIBEE => "VIBEE",
            .Python => "Python",
            .Rust => "Rust",
            .JavaScript => "JavaScript",
            .Go => "Go",
            .TypeScript => "TypeScript",
            .Unknown => "Unknown",
        };
    }

    pub fn extension(self: Language) []const u8 {
        return switch (self) {
            .Zig => ".zig",
            .VIBEE => ".vibee",
            .Python => ".py",
            .Rust => ".rs",
            .JavaScript => ".js",
            .Go => ".go",
            .TypeScript => ".ts",
            .Unknown => ".txt",
        };
    }
};

pub const SWERequest = struct {
    task: TaskType,
    language: Language,
    prompt: []const u8,
    context: ?[]const u8 = null,  // Existing code for bugfix/refactor
    max_tokens: u32 = 512,
};

pub const SWEResult = struct {
    code: []const u8,
    explanation: []const u8,
    task: TaskType,
    language: Language,
    tokens_generated: usize,
    inference_time_ms: u64,
    source: []const u8,  // "bitnet_local"
};

// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL SWE AGENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaLocalSWE = struct {
    allocator: std.mem.Allocator,
    model: ?*model_mod.FullModel,
    tokenizer: ?*tokenizer_mod.Tokenizer,
    model_path: []const u8,
    model_loaded: bool,

    // Statistics
    total_requests: usize,
    total_tokens: usize,
    total_time_ms: u64,

    const Self = @This();

    const SYSTEM_PROMPT_CODER =
        \\You are an expert software engineer assistant. You write clean, efficient,
        \\well-documented code. Always explain your approach briefly before the code.
        \\Focus on correctness, readability, and best practices.
    ;

    const SYSTEM_PROMPT_DEBUGGER =
        \\You are an expert debugger. Analyze code carefully, identify bugs, and
        \\provide fixed code with explanations of what was wrong and how you fixed it.
    ;

    const SYSTEM_PROMPT_REFACTOR =
        \\You are a code refactoring expert. Improve code structure, readability,
        \\and performance while maintaining functionality. Explain your changes.
    ;

    pub fn init(allocator: std.mem.Allocator, model_path: []const u8) Self {
        return Self{
            .allocator = allocator,
            .model = null,
            .tokenizer = null,
            .model_path = model_path,
            .model_loaded = false,
            .total_requests = 0,
            .total_tokens = 0,
            .total_time_ms = 0,
        };
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
    }

    /// Load the BitNet model (lazy loading)
    pub fn loadModel(self: *Self) !void {
        if (self.model_loaded) return;

        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║        IGLA LOCAL SWE - Pure Local Coding Agent              ║\n", .{});
        std.debug.print("║        BitNet-2B | M1 Pro Metal | No Cloud                   ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        std.debug.print("\nLoading BitNet model: {s}\n", .{self.model_path});

        // Allocate model
        const model = try self.allocator.create(model_mod.FullModel);
        errdefer self.allocator.destroy(model);

        model.* = model_mod.FullModel.init(self.allocator, self.model_path) catch |err| {
            std.debug.print("Error initializing model: {}\n", .{err});
            return err;
        };
        errdefer model.deinit();

        // Load weights
        var timer = try std.time.Timer.start();
        try model.loadWeights();
        const load_time = timer.read();
        std.debug.print("Model loaded in {d:.2}s\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

        // Initialize tokenizer
        const tokenizer = try self.allocator.create(tokenizer_mod.Tokenizer);
        errdefer self.allocator.destroy(tokenizer);

        tokenizer.* = try tokenizer_mod.Tokenizer.init(self.allocator, &model.reader);

        self.model = model;
        self.tokenizer = tokenizer;
        self.model_loaded = true;

        std.debug.print("✓ IGLA Local SWE ready (100%% local, no cloud)\n\n", .{});
    }

    /// Main entry: Execute SWE task
    pub fn execute(self: *Self, request: SWERequest) !SWEResult {
        const start = std.time.milliTimestamp();

        // Ensure model is loaded
        if (!self.model_loaded) {
            try self.loadModel();
        }

        self.total_requests += 1;

        // Build prompt based on task type
        const full_prompt = try self.buildPrompt(request);
        defer self.allocator.free(full_prompt);

        // Generate response
        const response = try self.generate(full_prompt, request.max_tokens);

        // Parse code from response
        const code = try self.extractCode(response, request.language);
        const explanation = try self.extractExplanation(response);

        const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start));
        self.total_time_ms += elapsed;
        self.total_tokens += response.len;

        return SWEResult{
            .code = code,
            .explanation = explanation,
            .task = request.task,
            .language = request.language,
            .tokens_generated = response.len,
            .inference_time_ms = elapsed,
            .source = "bitnet_local",
        };
    }

    /// Quick code generation (convenience wrapper)
    pub fn generateCode(self: *Self, prompt: []const u8, language: Language) ![]const u8 {
        const result = try self.execute(.{
            .task = .CodeGen,
            .language = language,
            .prompt = prompt,
        });
        return result.code;
    }

    /// Fix bug in code
    pub fn fixBug(self: *Self, code: []const u8, bug_description: []const u8, language: Language) ![]const u8 {
        const result = try self.execute(.{
            .task = .BugFix,
            .language = language,
            .prompt = bug_description,
            .context = code,
        });
        return result.code;
    }

    /// Refactor code
    pub fn refactor(self: *Self, code: []const u8, instructions: []const u8, language: Language) ![]const u8 {
        const result = try self.execute(.{
            .task = .Refactor,
            .language = language,
            .prompt = instructions,
            .context = code,
        });
        return result.code;
    }

    /// Explain code
    pub fn explain(self: *Self, code: []const u8, language: Language) ![]const u8 {
        const result = try self.execute(.{
            .task = .Explain,
            .language = language,
            .prompt = "Explain this code",
            .context = code,
        });
        return result.explanation;
    }

    // ───────────────────────────────────────────────────────────────────────────
    // INTERNAL METHODS
    // ───────────────────────────────────────────────────────────────────────────

    fn buildPrompt(self: *Self, request: SWERequest) ![]u8 {
        // System prompt based on task
        const system = switch (request.task) {
            .BugFix => SYSTEM_PROMPT_DEBUGGER,
            .Refactor => SYSTEM_PROMPT_REFACTOR,
            else => SYSTEM_PROMPT_CODER,
        };

        const ctx = request.context orelse "";
        const lang = request.language.name();

        // Calculate size and allocate
        const estimated_size = system.len + request.prompt.len + ctx.len + lang.len + 500;
        const buf = try self.allocator.alloc(u8, estimated_size);
        errdefer self.allocator.free(buf);

        // Build user message based on task
        const user_part = switch (request.task) {
            .CodeGen => std.fmt.bufPrint(buf, "Write {s} code: {s}", .{ lang, request.prompt }) catch return error.BufferTooSmall,
            .BugFix => std.fmt.bufPrint(buf, "Fix the bug in this {s} code:\n```\n{s}\n```\nBug: {s}", .{ lang, ctx, request.prompt }) catch return error.BufferTooSmall,
            .Refactor => std.fmt.bufPrint(buf, "Refactor this {s} code:\n```\n{s}\n```\nInstructions: {s}", .{ lang, ctx, request.prompt }) catch return error.BufferTooSmall,
            .Explain => std.fmt.bufPrint(buf, "Explain this {s} code:\n```\n{s}\n```", .{ lang, ctx }) catch return error.BufferTooSmall,
            .Test => std.fmt.bufPrint(buf, "Write tests for this {s} code:\n```\n{s}\n```", .{ lang, ctx }) catch return error.BufferTooSmall,
            .Document => std.fmt.bufPrint(buf, "Add documentation to this {s} code:\n```\n{s}\n```", .{ lang, ctx }) catch return error.BufferTooSmall,
            .Reason => std.fmt.bufPrint(buf, "Think step by step: {s}", .{request.prompt}) catch return error.BufferTooSmall,
        };

        // Build full ChatML prompt
        const full_buf = try self.allocator.alloc(u8, system.len + user_part.len + 200);
        const full_prompt = std.fmt.bufPrint(full_buf, "<|im_start|>system\n{s}\n<|im_end|>\n<|im_start|>user\n{s}\n<|im_end|>\n<|im_start|>assistant\n", .{ system, user_part }) catch return error.BufferTooSmall;

        self.allocator.free(buf);

        // Shrink to actual size
        const result = try self.allocator.dupe(u8, full_prompt);
        self.allocator.free(full_buf);
        return result;
    }

    fn generate(self: *Self, prompt: []const u8, max_tokens: u32) ![]const u8 {
        const model = self.model orelse return error.ModelNotLoaded;
        const tokenizer = self.tokenizer orelse return error.TokenizerNotLoaded;

        // Tokenize prompt
        const tokens = try tokenizer.encode(self.allocator, prompt);
        defer self.allocator.free(tokens);

        // Generate tokens - use fixed buffer for simplicity
        var output_tokens: [4096]u32 = undefined;
        var output_len: usize = 0;

        var pos: usize = 0;
        var prev_token: u32 = tokens[tokens.len - 1];

        // Feed prompt tokens
        for (tokens) |token| {
            const logits = try model.forward(token, pos);
            self.allocator.free(logits);
            pos += 1;
        }

        // Generate new tokens
        var generated: u32 = 0;
        while (generated < max_tokens and output_len < output_tokens.len) : (generated += 1) {
            const logits = try model.forward(prev_token, pos);

            // Sample next token (greedy for now)
            var max_logit: f32 = logits[0];
            var max_idx: u32 = 0;
            for (logits[1..], 1..) |l, i| {
                if (l > max_logit) {
                    max_logit = l;
                    max_idx = @intCast(i);
                }
            }

            // Cleanup logits
            self.allocator.free(logits);

            // Check for EOS
            if (max_idx == tokenizer.eos_token) break;

            output_tokens[output_len] = max_idx;
            output_len += 1;
            prev_token = max_idx;
            pos += 1;
        }

        // Decode tokens to text
        const output = try tokenizer.decode(self.allocator, output_tokens[0..output_len]);
        return output;
    }

    fn extractCode(self: *Self, response: []const u8, language: Language) ![]const u8 {
        _ = language;

        // Look for code blocks
        if (std.mem.indexOf(u8, response, "```")) |start| {
            const code_start = start + 3;
            // Skip language identifier if present
            var actual_start = code_start;
            if (std.mem.indexOfScalar(u8, response[code_start..], '\n')) |nl| {
                actual_start = code_start + nl + 1;
            }

            if (std.mem.indexOf(u8, response[actual_start..], "```")) |end| {
                return try self.allocator.dupe(u8, response[actual_start..][0..end]);
            }
        }

        // Return full response if no code block
        return try self.allocator.dupe(u8, response);
    }

    fn extractExplanation(self: *Self, response: []const u8) ![]const u8 {
        // Get text before code block
        if (std.mem.indexOf(u8, response, "```")) |code_start| {
            if (code_start > 0) {
                return try self.allocator.dupe(u8, response[0..code_start]);
            }
        }
        return try self.allocator.dupe(u8, "");
    }

    // ───────────────────────────────────────────────────────────────────────────
    // STATISTICS
    // ───────────────────────────────────────────────────────────────────────────

    pub fn printStats(self: *const Self) void {
        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║                 IGLA LOCAL SWE STATISTICS                     ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Total Requests:       {d:>10}                             ║\n", .{self.total_requests});
        std.debug.print("║  Total Tokens:         {d:>10}                             ║\n", .{self.total_tokens});
        std.debug.print("║  Total Time:           {d:>10} ms                          ║\n", .{self.total_time_ms});
        if (self.total_requests > 0) {
            std.debug.print("║  Avg Time/Request:     {d:>10} ms                          ║\n", .{self.total_time_ms / self.total_requests});
        }
        std.debug.print("║  Source:               100%% LOCAL (BitNet)                   ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Default model path
    const model_path = if (args.len > 1) args[1] else "models/bitnet-2b-fixed.gguf";

    var swe = IglaLocalSWE.init(allocator, model_path);
    defer swe.deinit();

    // Demo: Generate code
    std.debug.print("\n══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  DEMO: Pure Local Code Generation (No Cloud)\n", .{});
    std.debug.print("══════════════════════════════════════════════════════════════\n", .{});

    const demos = [_]struct { prompt: []const u8, lang: Language }{
        .{ .prompt = "Write a hello world program", .lang = .Zig },
        .{ .prompt = "Write a fibonacci function", .lang = .Zig },
        .{ .prompt = "Write a function to check if a number is prime", .lang = .Python },
    };

    for (demos) |demo| {
        std.debug.print("\n▶ Prompt: {s} ({s})\n", .{ demo.prompt, demo.lang.name() });
        std.debug.print("─────────────────────────────────────────────────────────────\n", .{});

        const result = swe.execute(.{
            .task = .CodeGen,
            .language = demo.lang,
            .prompt = demo.prompt,
            .max_tokens = 256,
        }) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            continue;
        };
        defer allocator.free(result.code);
        defer allocator.free(result.explanation);

        std.debug.print("Generated code ({d} tokens, {d}ms):\n", .{ result.tokens_generated, result.inference_time_ms });
        std.debug.print("```{s}\n{s}\n```\n", .{ demo.lang.extension(), result.code });
    }

    swe.printStats();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "prompt building" {
    const allocator = std.testing.allocator;
    var swe = IglaLocalSWE.init(allocator, "test.gguf");
    defer swe.deinit();

    const prompt = try swe.buildPrompt(.{
        .task = .CodeGen,
        .language = .Zig,
        .prompt = "hello world",
    });
    defer allocator.free(prompt);

    try std.testing.expect(std.mem.indexOf(u8, prompt, "Write Zig code") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "hello world") != null);
}
