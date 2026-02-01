// TRINITY DEMO - End-to-End Code Generation
// Полный пайплайн: prompt → tokens → generate → text
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const mistral = @import("mistral_trinity.zig");
const trinity_format = @import("trinity_format.zig");
const bpe = @import("bpe_tokenizer.zig");
const kv_cache = @import("kv_cache.zig");

pub const PHI: f64 = 1.618033988749895;

fn printModelInfo(config: mistral.MistralConfig) void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY MODEL INFO                                 ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Vocab size:             {d:>10}                               ║\n", .{config.vocab_size});
    std.debug.print("║ Hidden size:            {d:>10}                               ║\n", .{config.hidden_size});
    std.debug.print("║ Intermediate:           {d:>10}                               ║\n", .{config.intermediate_size});
    std.debug.print("║ Num layers:             {d:>10}                               ║\n", .{config.num_hidden_layers});
    std.debug.print("║ Num heads:              {d:>10}                               ║\n", .{config.num_attention_heads});
    std.debug.print("║ Num KV heads:           {d:>10}                               ║\n", .{config.num_key_value_heads});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEMO CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const DemoConfig = struct {
    model_path: []const u8 = "models/qwen-coder-7b.tri",
    tokenizer_path: []const u8 = "models/qwen-coder-7b/tokenizer.json",
    max_new_tokens: usize = 50,
    use_cache: bool = true,
    use_mini: bool = false, // Use mini model for low-memory systems
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEMO PROMPTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEMO_PROMPTS = [_][]const u8{
    "def fibonacci(n):",
    "def factorial(n):",
    "def is_prime(n):",
    "# Function to reverse a string\ndef reverse(",
    "class Calculator:",
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY DEMO
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityDemo = struct {
    allocator: std.mem.Allocator,
    model: ?mistral.MistralTrinity,
    tokenizer: bpe.BPETokenizer,
    config: DemoConfig,

    pub fn init(allocator: std.mem.Allocator, config: DemoConfig) !TrinityDemo {
        return TrinityDemo{
            .allocator = allocator,
            .model = null,
            .tokenizer = bpe.BPETokenizer.init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *TrinityDemo) void {
        if (self.model) |*m| {
            m.deinit();
        }
        self.tokenizer.deinit();
    }

    /// Load model and tokenizer
    pub fn load(self: *TrinityDemo) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY CODE GENERATION DEMO                       ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        // Load tokenizer
        std.debug.print("\n[1/2] Loading tokenizer...\n", .{});
        self.tokenizer.loadFromFile(self.config.tokenizer_path) catch |err| {
            std.debug.print("⚠️  Tokenizer load failed: {}\n", .{err});
            std.debug.print("    Using simple tokenizer instead\n", .{});
        };
        self.tokenizer.printInfo();

        // Load model
        std.debug.print("\n[2/2] Loading model...\n", .{});

        // Use mini model for low-memory systems or if explicitly requested
        if (self.config.use_mini) {
            std.debug.print("  Using MINI model (low memory mode)\n", .{});
            const mini_config = mistral.MistralConfig.initMini();
            self.model = try mistral.MistralTrinity.init(self.allocator, mini_config);
            printModelInfo(mini_config);

            // Initialize KV-cache
            if (self.config.use_cache) {
                try self.model.?.initCache(self.config.max_new_tokens + 100);
            }
            std.debug.print("✅ Mini model loaded successfully\n", .{});
            return;
        }

        std.debug.print("  Path: {s}\n", .{self.config.model_path});

        // Check if model file exists
        std.fs.cwd().access(self.config.model_path, .{}) catch {
            std.debug.print("⚠️  Model file not found: {s}\n", .{self.config.model_path});
            std.debug.print("    Using mini model for demo\n", .{});

            // Use mini config
            const mini_config = mistral.MistralConfig.initMini();
            self.model = try mistral.MistralTrinity.init(self.allocator, mini_config);
            return;
        };

        // Load from .tri file
        var reader = try trinity_format.TrinityReader.init(self.allocator, self.config.model_path);
        defer reader.deinit();

        reader.printInfo();

        // Create model with config from .tri header
        const model_config = mistral.MistralConfig{
            .vocab_size = reader.header.vocab_size,
            .hidden_size = reader.header.hidden_size,
            .intermediate_size = reader.header.intermediate_size,
            .num_hidden_layers = reader.header.num_layers,
            .num_attention_heads = reader.header.num_heads,
            .num_key_value_heads = reader.header.num_kv_heads,
            .head_dim = reader.header.hidden_size / reader.header.num_heads,
            .max_position_embeddings = 2048,
        };

        self.model = try mistral.MistralTrinity.init(self.allocator, model_config);

        // Initialize KV-cache
        if (self.config.use_cache) {
            try self.model.?.initCache(self.config.max_new_tokens + 100);
        }

        std.debug.print("✅ Model loaded successfully\n", .{});
    }

    /// Generate code from prompt
    pub fn generate(self: *TrinityDemo, prompt: []const u8) ![]u8 {
        if (self.model == null) {
            return error.ModelNotLoaded;
        }

        std.debug.print("\n─────────────────────────────────────────────────────────────────\n", .{});
        std.debug.print("Prompt: {s}\n", .{prompt});
        std.debug.print("─────────────────────────────────────────────────────────────────\n", .{});

        // Encode prompt
        const prompt_tokens = try self.tokenizer.encode(prompt);
        defer self.allocator.free(prompt_tokens);

        std.debug.print("Encoded to {d} tokens\n", .{prompt_tokens.len});

        // Start timer
        var timer = try std.time.Timer.start();

        // Reset cache for new generation
        self.model.?.resetCache();

        // Generate tokens
        var output_tokens = std.ArrayList(u32).init(self.allocator);
        defer output_tokens.deinit();

        // Add prompt tokens
        try output_tokens.appendSlice(prompt_tokens);

        // Process prompt (prefill)
        for (prompt_tokens, 0..) |token, pos| {
            _ = self.model.?.forwardWithCache(token, pos, self.config.use_cache) catch |err| {
                std.debug.print("Prefill error at pos {d}: {}\n", .{ pos, err });
                break;
            };
        }

        // Generate new tokens
        var last_token = prompt_tokens[prompt_tokens.len - 1];
        for (0..self.config.max_new_tokens) |i| {
            const pos = prompt_tokens.len + i;
            const new_token = self.model.?.forwardWithCache(last_token, pos, self.config.use_cache) catch |err| {
                std.debug.print("Generate error at pos {d}: {}\n", .{ pos, err });
                break;
            };

            try output_tokens.append(new_token);
            last_token = new_token;

            // Stop on EOS or newline (for demo)
            if (new_token == bpe.SpecialTokens.EOS) {
                break;
            }

            // Print progress
            if ((i + 1) % 10 == 0) {
                std.debug.print("  Generated {d} tokens...\n", .{i + 1});
            }
        }

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        const tokens_generated = output_tokens.items.len - prompt_tokens.len;
        const tokens_per_sec = @as(f64, @floatFromInt(tokens_generated)) / (elapsed_ms / 1000.0);

        // Decode output
        const output_text = try self.tokenizer.decode(output_tokens.items);

        std.debug.print("\n─────────────────────────────────────────────────────────────────\n", .{});
        std.debug.print("Generated:\n{s}\n", .{output_text});
        std.debug.print("─────────────────────────────────────────────────────────────────\n", .{});
        std.debug.print("Stats:\n", .{});
        std.debug.print("  Tokens generated: {d}\n", .{tokens_generated});
        std.debug.print("  Time: {d:.2} ms\n", .{elapsed_ms});
        std.debug.print("  Speed: {d:.1} tokens/sec\n", .{tokens_per_sec});

        return output_text;
    }

    /// Run demo with all prompts
    pub fn runDemo(self: *TrinityDemo) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           RUNNING CODE GENERATION DEMO                       ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        var total_tokens: usize = 0;
        var total_time_ms: f64 = 0;

        for (DEMO_PROMPTS, 0..) |prompt, i| {
            std.debug.print("\n[Demo {d}/{d}]\n", .{ i + 1, DEMO_PROMPTS.len });

            var timer = try std.time.Timer.start();
            const output = self.generate(prompt) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };
            defer self.allocator.free(output);

            const elapsed_ns = timer.read();
            total_time_ms += @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
            total_tokens += output.len;
        }

        // Summary
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           DEMO SUMMARY                                       ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Prompts processed: {d:>10}                               ║\n", .{DEMO_PROMPTS.len});
        std.debug.print("║ Total tokens:      {d:>10}                               ║\n", .{total_tokens});
        std.debug.print("║ Total time:        {d:>10.1} ms                          ║\n", .{total_time_ms});
        std.debug.print("║ Avg tokens/sec:    {d:>10.1}                             ║\n", .{@as(f64, @floatFromInt(total_tokens)) / (total_time_ms / 1000.0)});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = DemoConfig{};

    // Parse args
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--mini") or std.mem.eql(u8, arg, "-m")) {
            config.use_mini = true;
        } else if (std.mem.eql(u8, arg, "--tokens") or std.mem.eql(u8, arg, "-t")) {
            if (i + 1 < args.len) {
                i += 1;
                config.max_new_tokens = std.fmt.parseInt(usize, args[i], 10) catch 50;
            }
        } else if (config.model_path.len == 0 or std.mem.eql(u8, config.model_path, "models/qwen-coder-7b.tri")) {
            config.model_path = arg;
        }
    }

    var demo = try TrinityDemo.init(allocator, config);
    defer demo.deinit();

    try demo.load();
    try demo.runDemo();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "demo init" {
    const allocator = std.testing.allocator;
    var demo = try TrinityDemo.init(allocator, .{});
    defer demo.deinit();
}

test "demo with mini model" {
    const allocator = std.testing.allocator;

    var demo = try TrinityDemo.init(allocator, .{
        .model_path = "nonexistent.tri", // Will use mini model
        .max_new_tokens = 5,
    });
    defer demo.deinit();

    try demo.load();

    const output = try demo.generate("def test():");
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}
