// GGUF CHAT - Interactive Chat Interface
// Chat with LLM using GGUF model
// SIMD-optimized inference via simd_matmul
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");

// Chat template for formatting prompts
const ChatTemplate = tokenizer_mod.ChatTemplate;

// Sampling parameters struct
const SamplingParams = inference.SamplingParams;

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATION HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

const Message = struct {
    role: Role,
    content: []const u8,

    const Role = enum { system, user, assistant };
};

const ConversationHistory = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList(Message),
    max_messages: usize,

    pub fn init(allocator: std.mem.Allocator, max_messages: usize) ConversationHistory {
        return .{
            .allocator = allocator,
            .messages = .{},
            .max_messages = max_messages,
        };
    }

    pub fn deinit(self: *ConversationHistory) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg.content);
        }
        self.messages.deinit(self.allocator);
    }

    pub fn addMessage(self: *ConversationHistory, role: Message.Role, content: []const u8) !void {
        // Copy content
        const content_copy = try self.allocator.dupe(u8, content);

        // Truncate old messages if needed (keep system + last N)
        while (self.messages.items.len >= self.max_messages) {
            // Keep first message if it's system
            const start_idx: usize = if (self.messages.items.len > 0 and
                self.messages.items[0].role == .system) 1 else 0;

            if (self.messages.items.len > start_idx) {
                const removed = self.messages.orderedRemove(start_idx);
                self.allocator.free(removed.content);
            } else {
                break;
            }
        }

        try self.messages.append(self.allocator, .{ .role = role, .content = content_copy });
    }

    pub fn formatForModel(self: *const ConversationHistory, allocator: std.mem.Allocator, template: *const ChatTemplate) ![]u8 {
        var result: std.ArrayList(u8) = .{};
        errdefer result.deinit(allocator);

        for (self.messages.items) |msg| {
            switch (msg.role) {
                .system => {
                    // Skip system message if template doesn't support it (empty prefix)
                    if (template.system_prefix.len > 0) {
                        try result.appendSlice(allocator, template.system_prefix);
                        try result.appendSlice(allocator, msg.content);
                        try result.appendSlice(allocator, template.system_suffix);
                    }
                },
                .user => {
                    try result.appendSlice(allocator, template.user_prefix);
                    try result.appendSlice(allocator, msg.content);
                    try result.appendSlice(allocator, template.user_suffix);
                },
                .assistant => {
                    try result.appendSlice(allocator, template.assistant_prefix);
                    try result.appendSlice(allocator, msg.content);
                    try result.appendSlice(allocator, template.assistant_suffix);
                },
            }
        }

        // Add assistant prefix for generation
        try result.appendSlice(allocator, template.assistant_prefix);

        return result.toOwnedSlice(allocator);
    }

    pub fn getMessageCount(self: *const ConversationHistory) usize {
        return self.messages.items.len;
    }

    pub fn clear(self: *ConversationHistory) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg.content);
        }
        self.messages.clearRetainingCapacity();
    }
};

// Auto-detect chat template based on model name
fn detectChatTemplate(model_path: []const u8) ChatTemplate {
    // Check for DeepSeek models
    if (std.mem.indexOf(u8, model_path, "deepseek") != null or
        std.mem.indexOf(u8, model_path, "DeepSeek") != null) {
        return ChatTemplate.DEEPSEEK;
    }
    // Check for Qwen models
    if (std.mem.indexOf(u8, model_path, "qwen") != null or
        std.mem.indexOf(u8, model_path, "Qwen") != null) {
        return ChatTemplate.QWEN;
    }
    // Check for SmolLM models
    if (std.mem.indexOf(u8, model_path, "smollm") != null or
        std.mem.indexOf(u8, model_path, "SmolLM") != null) {
        return ChatTemplate.SMOLLM;
    }
    // Check for Llama2 models
    if (std.mem.indexOf(u8, model_path, "llama-2") != null or
        std.mem.indexOf(u8, model_path, "Llama-2") != null) {
        return ChatTemplate.LLAMA2;
    }
    // Default to TinyLlama/ChatML format
    return ChatTemplate.TINYLLAMA;
}

// Auto-detect system prompt based on model type
fn detectSystemPrompt(model_path: []const u8) []const u8 {
    // Coder models
    if (std.mem.indexOf(u8, model_path, "coder") != null or
        std.mem.indexOf(u8, model_path, "Coder") != null or
        std.mem.indexOf(u8, model_path, "code") != null) {
        return "You are Qwen, a helpful coding assistant. Write clean, efficient code with clear explanations.";
    }
    // Default assistant
    return "You are a helpful AI assistant. Be concise and direct.";
}

// Entry point for CLI chat command (with ternary support)
pub fn runChatWithTernary(allocator: std.mem.Allocator, model_path: []const u8, initial_prompt: ?[]const u8, max_tokens: u32, temperature: f32, top_p: f32, use_ternary: bool) !void {
    return runChatInternal(allocator, model_path, initial_prompt, max_tokens, temperature, top_p, use_ternary);
}

// Entry point for CLI chat command (backward compatible)
pub fn runChat(allocator: std.mem.Allocator, model_path: []const u8, initial_prompt: ?[]const u8, max_tokens: u32, temperature: f32, top_p: f32) !void {
    return runChatInternal(allocator, model_path, initial_prompt, max_tokens, temperature, top_p, false);
}

fn runChatInternal(allocator: std.mem.Allocator, model_path: []const u8, initial_prompt: ?[]const u8, max_tokens: u32, temperature: f32, top_p: f32, use_ternary: bool) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY CHAT - SIMD Optimized LLM                  ║\n", .{});
    std.debug.print("║           Temperature + Top-p Sampling                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Create sampling params
    const sampling_params = SamplingParams{
        .temperature = temperature,
        .top_p = top_p,
        .top_k = 40,
        .repeat_penalty = 1.1,
    };

    // Load model
    std.debug.print("Loading model: {s}\n", .{model_path});
    var model = model_mod.FullModel.init(allocator, model_path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    model.printConfig();

    std.debug.print("\nLoading weights (SIMD matmul enabled)...\n", .{});
    var timer = try std.time.Timer.start();
    model.loadWeights() catch |err| {
        std.debug.print("Error loading weights: {}\n", .{err});
        return;
    };
    const load_time = timer.read();
    std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

    // Enable ternary mode if requested (BitNet {-1, 0, +1})
    if (use_ternary) {
        std.debug.print("\nEnabling ternary mode (BitNet weights)...\n", .{});
        model.enableTernaryMode() catch |err| {
            std.debug.print("Warning: Could not enable ternary mode: {}\n", .{err});
        };
    }

    // Initialize tokenizer
    std.debug.print("\nInitializing tokenizer...\n", .{});
    var tokenizer = tokenizer_mod.Tokenizer.init(allocator, &model.reader) catch |err| {
        std.debug.print("Error initializing tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();

    // Auto-detect model and select appropriate chat template
    const template = detectChatTemplate(model_path);
    const system_prompt = detectSystemPrompt(model_path);

    // Initialize conversation history (keep last 10 messages + system)
    var history = ConversationHistory.init(allocator, 12);
    defer history.deinit();

    // Add system message
    try history.addMessage(.system, system_prompt);

    // Print detected template name
    const template_name = if (std.mem.indexOf(u8, model_path, "deepseek") != null or std.mem.indexOf(u8, model_path, "DeepSeek") != null)
        "DeepSeek"
    else if (std.mem.indexOf(u8, model_path, "qwen") != null or std.mem.indexOf(u8, model_path, "Qwen") != null)
        "Qwen (ChatML)"
    else if (std.mem.indexOf(u8, model_path, "smollm") != null or std.mem.indexOf(u8, model_path, "SmolLM") != null)
        "SmolLM (ChatML)"
    else
        "TinyLlama (ChatML)";
    std.debug.print("Chat template: {s}\n", .{template_name});
    std.debug.print("System: {s}\n", .{system_prompt});
    std.debug.print("Sampling: temperature={d:.2}, top_p={d:.2}\n", .{sampling_params.temperature, sampling_params.top_p});
    std.debug.print("History: enabled (last 10 messages)\n", .{});
    std.debug.print("\nCommands: 'quit' to exit, '/clear' to reset history\n", .{});
    std.debug.print("\nReady! Type your message:\n\n", .{});

    // Handle initial prompt if provided
    if (initial_prompt) |prompt| {
        try history.addMessage(.user, prompt);
        const stdout_initial = std.fs.File.stdout();
        const response = try generateWithHistory(allocator, stdout_initial, &model, &tokenizer, &template, &history, max_tokens, sampling_params);
        if (response) |resp| {
            try history.addMessage(.assistant, resp);
            allocator.free(resp);
        }
    }

    // Interactive loop - using low-level read for Zig 0.15 compatibility
    const stdin_file = std.fs.File.stdin();
    var buf: [1024]u8 = undefined;

    while (true) {
        std.debug.print("User: ", .{});

        // Read line byte by byte (Zig 0.15 compatible)
        var line_len: usize = 0;
        while (line_len < buf.len - 1) {
            const read_result = stdin_file.read(buf[line_len .. line_len + 1]) catch break;
            if (read_result == 0) break; // EOF
            if (buf[line_len] == '\n') break;
            line_len += 1;
        }

        const trimmed = std.mem.trim(u8, buf[0..line_len], " \t\r\n");

        if (trimmed.len == 0) continue;
        if (std.mem.eql(u8, trimmed, "quit") or std.mem.eql(u8, trimmed, "exit")) break;

        // Handle commands
        if (std.mem.eql(u8, trimmed, "/clear")) {
            history.clear();
            try history.addMessage(.system, system_prompt);
            model.resetKVCache();
            std.debug.print("[History cleared]\n\n", .{});
            continue;
        }

        if (std.mem.eql(u8, trimmed, "/history")) {
            std.debug.print("[{d} messages in history]\n\n", .{history.getMessageCount()});
            continue;
        }

        // Add user message to history
        try history.addMessage(.user, trimmed);

        // Generate response with full history
        const stdout_file = std.fs.File.stdout();
        const response = try generateWithHistory(allocator, stdout_file, &model, &tokenizer, &template, &history, max_tokens, sampling_params);

        // Add assistant response to history
        if (response) |resp| {
            try history.addMessage(.assistant, resp);
            allocator.free(resp);
        }
    }

    std.debug.print("Goodbye!\n", .{});
}

// Generate response with conversation history
fn generateWithHistory(
    allocator: std.mem.Allocator,
    _: std.fs.File, // unused, using std.debug.print
    model: *model_mod.FullModel,
    tokenizer: *tokenizer_mod.Tokenizer,
    template: *const ChatTemplate,
    history: *const ConversationHistory,
    max_tokens: u32,
    params: SamplingParams,
) !?[]u8 {
    // Format full conversation history
    const formatted = try history.formatForModel(allocator, template);
    defer allocator.free(formatted);

    std.debug.print("Assistant: ", .{});
    var gen_timer = try std.time.Timer.start();

    // Tokenize formatted prompt
    const tokens = tokenizer.encode(allocator, formatted) catch {
        std.debug.print("[tokenization error]\n", .{});
        return null;
    };
    defer allocator.free(tokens);

    // Check context length
    if (tokens.len > model.config.context_length - max_tokens) {
        std.debug.print("[context too long, use /clear]\n", .{});
        return null;
    }

    // Reset KV cache for full history processing
    model.resetKVCache();

    // Process all history tokens (prefill)
    var last_logits: ?[]f32 = null;
    for (tokens, 0..) |token, pos| {
        if (last_logits) |l| allocator.free(l);
        last_logits = model.forward(token, pos) catch {
            std.debug.print("[forward error]\n", .{});
            return null;
        };
    }

    // Generate tokens with streaming output
    var generated: u32 = 0;
    var current_pos = tokens.len;
    var current_logits = last_logits orelse return null;
    var last_token: u32 = 0;

    // Collect response for history
    var response: std.ArrayList(u8) = .{};
    errdefer response.deinit(allocator);

    while (generated < max_tokens) : (generated += 1) {
        // Sample next token
        const sampled_token = inference.sampleWithParams(allocator, current_logits, params) catch blk: {
            var max_idx: u32 = 0;
            var max_val: f32 = current_logits[0];
            for (current_logits[1..], 1..) |l, i| {
                if (l > max_val) {
                    max_val = l;
                    max_idx = @intCast(i);
                }
            }
            break :blk max_idx;
        };

        allocator.free(current_logits);

        // Check for EOS
        if (sampled_token == tokenizer.eos_token) break;

        // Decode token
        const decoded = tokenizer.decode(allocator, &[_]u32{sampled_token}) catch " ";
        defer if (decoded.len > 0) allocator.free(decoded);

        // Stream output
        std.debug.print("{s}", .{decoded});

        // Collect for history
        try response.appendSlice(allocator, decoded);

        // Check for end markers
        if (std.mem.indexOf(u8, decoded, "</s>") != null) break;
        if (std.mem.indexOf(u8, decoded, "<|") != null) break;

        // Get next logits
        last_token = sampled_token;
        current_logits = model.forward(last_token, current_pos) catch break;
        current_pos += 1;
    }
    std.debug.print("\n", .{});

    const gen_time = gen_timer.read();
    const tok_per_sec = @as(f64, @floatFromInt(generated)) / (@as(f64, @floatFromInt(gen_time)) / 1e9);
    std.debug.print("[{d} tokens, {d:.1} tok/s, history: {d} msgs]\n\n", .{ generated, tok_per_sec, history.getMessageCount() });

    const result = try response.toOwnedSlice(allocator);
    return result;
}

// Generate response with chat template and streaming output (legacy single-turn)
// NOTE: This function is kept for compatibility but is not currently used
fn generateWithTemplate(
    allocator: std.mem.Allocator,
    model: *model_mod.FullModel,
    tokenizer: *tokenizer_mod.Tokenizer,
    template: *const ChatTemplate,
    system: []const u8,
    user_input: []const u8,
    max_tokens: u32,
    params: SamplingParams,
) !void {
    // Format prompt with chat template
    const formatted = try template.formatPrompt(allocator, system, user_input);
    defer allocator.free(formatted);

    std.debug.print("Assistant: ", .{});
    var gen_timer = try std.time.Timer.start();

    // Tokenize formatted prompt
    const tokens = tokenizer.encode(allocator, formatted) catch {
        std.debug.print("[tokenization error]\n", .{});
        return;
    };
    defer allocator.free(tokens);

    // Reset KV cache for new conversation
    model.resetKVCache();

    // Process prompt tokens (prefill) - build up KV cache
    var last_logits: ?[]f32 = null;
    for (tokens, 0..) |token, pos| {
        if (last_logits) |l| allocator.free(l);
        last_logits = model.forward(token, pos) catch {
            std.debug.print("[forward error]\n", .{});
            return;
        };
    }

    // Generate tokens with streaming output
    var generated: u32 = 0;
    var current_pos = tokens.len;

    // Use logits from last prefill token for first generation
    var current_logits = last_logits orelse return;
    var last_token: u32 = 0;

    while (generated < max_tokens) : (generated += 1) {
        // Sample next token with temperature + top-p
        const sampled_token = inference.sampleWithParams(allocator, current_logits, params) catch blk: {
            // Fallback to greedy on error
            var max_idx: u32 = 0;
            var max_val: f32 = current_logits[0];
            for (current_logits[1..], 1..) |l, i| {
                if (l > max_val) {
                    max_val = l;
                    max_idx = @intCast(i);
                }
            }
            break :blk max_idx;
        };

        // Free current logits
        allocator.free(current_logits);

        // Check for EOS
        if (sampled_token == tokenizer.eos_token) break;

        // Decode and stream output immediately
        const decoded = tokenizer.decode(allocator, &[_]u32{sampled_token}) catch " ";
        defer if (decoded.len > 0) allocator.free(decoded);

        // Stream: print immediately without buffering
        std.debug.print("{s}", .{decoded});

        // Check for </s> or end markers in decoded text
        if (std.mem.indexOf(u8, decoded, "</s>") != null) break;
        if (std.mem.indexOf(u8, decoded, "<|") != null) break;

        // Get next logits
        last_token = sampled_token;
        current_logits = model.forward(last_token, current_pos) catch break;
        current_pos += 1;
    }
    std.debug.print("\n", .{});

    const gen_time = gen_timer.read();
    const tok_per_sec = @as(f64, @floatFromInt(generated)) / (@as(f64, @floatFromInt(gen_time)) / 1e9);
    std.debug.print("[{d} tokens, {d:.1} tok/s]\n\n", .{ generated, tok_per_sec });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-q8_0.gguf";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY CHAT - LLM in Pure Zig                     ║\n", .{});
    std.debug.print("║           phi^2 + 1/phi^2 = 3 = TRINITY                      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Load model
    std.debug.print("Loading model: {s}\n", .{path});
    var model = model_mod.FullModel.init(allocator, path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    model.printConfig();

    std.debug.print("\nLoading weights...\n", .{});
    var timer = try std.time.Timer.start();
    model.loadWeights() catch |err| {
        std.debug.print("Error loading weights: {}\n", .{err});
        return;
    };
    const load_time = timer.read();
    std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

    // Initialize tokenizer
    std.debug.print("\nInitializing tokenizer...\n", .{});
    var tokenizer = tokenizer_mod.Tokenizer.init(allocator, &model.reader) catch |err| {
        std.debug.print("Error initializing tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    tokenizer.printInfo();

    // Demo prompts
    const prompts = [_][]const u8{
        "Write a Python function to calculate fibonacci:",
        "What is the capital of France?",
        "Explain quantum computing in simple terms:",
    };

    const system_prompt = "You are a helpful AI assistant.";
    const max_tokens: usize = 50;
    const temperature: f32 = 0.7;

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    CHAT DEMO                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    for (prompts) |user_prompt| {
        std.debug.print("\n", .{});
        std.debug.print("USER: {s}\n", .{user_prompt});
        std.debug.print("\n", .{});

        // Format prompt with chat template
        const formatted = try tokenizer_mod.ChatTemplate.TINYLLAMA.formatPrompt(
            allocator,
            system_prompt,
            user_prompt,
        );
        defer allocator.free(formatted);

        // Encode prompt
        const prompt_tokens = try tokenizer.encode(allocator, formatted);
        defer allocator.free(prompt_tokens);

        std.debug.print("Prompt tokens: {d}\n", .{prompt_tokens.len});

        // Reset KV cache for new conversation
        model.resetKVCache();

        // Process prompt tokens (prefill)
        std.debug.print("Processing prompt...\n", .{});
        timer.reset();

        var last_token: u32 = prompt_tokens[0];
        for (prompt_tokens, 0..) |token, pos| {
            _ = model.forward(token, pos) catch |err| {
                std.debug.print("Prefill error: {}\n", .{err});
                break;
            };
            last_token = token;
        }

        const prefill_time = timer.read();
        std.debug.print("Prefill: {d:.2}s ({d:.1} tok/s)\n", .{
            @as(f64, @floatFromInt(prefill_time)) / 1e9,
            @as(f64, @floatFromInt(prompt_tokens.len)) / (@as(f64, @floatFromInt(prefill_time)) / 1e9),
        });

        // Generate response
        std.debug.print("\nASSISTANT: ", .{});
        timer.reset();

        var generated: usize = 0;
        var pos = prompt_tokens.len;

        while (generated < max_tokens) {
            const next_token = model.generate(last_token, pos, temperature) catch |err| {
                std.debug.print("\nGeneration error: {}\n", .{err});
                break;
            };

            // Check for EOS
            if (next_token == tokenizer.eos_token) {
                break;
            }

            // Print token (streaming)
            const token_str = tokenizer.getToken(next_token);
            // Replace special space with regular space
            for (token_str) |c| {
                if (c == 0xE2) {
                    std.debug.print(" ", .{});
                } else if (c != 0x96 and c != 0x81) {
                    std.debug.print("{c}", .{c});
                }
            }

            last_token = next_token;
            pos += 1;
            generated += 1;
        }

        const gen_time = timer.read();
        std.debug.print("\n\n", .{});
        std.debug.print("Generated {d} tokens in {d:.2}s ({d:.2} tok/s)\n", .{
            generated,
            @as(f64, @floatFromInt(gen_time)) / 1e9,
            @as(f64, @floatFromInt(generated)) / (@as(f64, @floatFromInt(gen_time)) / 1e9),
        });
        std.debug.print("─────────────────────────────────────────────────────────────\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
