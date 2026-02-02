// GGUF TOKENIZER - Encode text to tokens
// BPE tokenization from GGUF metadata
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: [][]const u8,
    vocab_size: usize,
    token_to_id: std.StringHashMap(u32),

    // Special tokens
    bos_token: u32,
    eos_token: u32,
    pad_token: u32,

    pub fn init(allocator: std.mem.Allocator, reader: *const gguf.GGUFReader) !Tokenizer {
        var tokenizer = Tokenizer{
            .allocator = allocator,
            .vocab = undefined,
            .vocab_size = 0,
            .token_to_id = std.StringHashMap(u32).init(allocator),
            .bos_token = 1,
            .eos_token = 2,
            .pad_token = 0,
        };

        // Load vocab from GGUF metadata
        if (reader.metadata.get("tokenizer.ggml.tokens")) |v| {
            if (v == .array) {
                const arr = v.array;
                tokenizer.vocab_size = arr.len;
                tokenizer.vocab = try allocator.alloc([]const u8, arr.len);

                for (arr, 0..) |item, i| {
                    if (item == .string) {
                        tokenizer.vocab[i] = item.string;
                        // Build reverse lookup
                        try tokenizer.token_to_id.put(item.string, @intCast(i));
                    } else {
                        tokenizer.vocab[i] = "";
                    }
                }
            }
        }

        // Get special token IDs
        if (reader.getMetadataU32("tokenizer.ggml.bos_token_id")) |id| {
            tokenizer.bos_token = id;
        }
        if (reader.getMetadataU32("tokenizer.ggml.eos_token_id")) |id| {
            tokenizer.eos_token = id;
        }
        if (reader.getMetadataU32("tokenizer.ggml.padding_token_id")) |id| {
            tokenizer.pad_token = id;
        }
        
        return tokenizer;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.token_to_id.deinit();
        self.allocator.free(self.vocab);
    }

    // Simple greedy tokenization (longest match)
    // Supports both GPT-2 style (Ġ = 0xC4 0xA0) and Llama style (▁ = 0xE2 0x96 0x81)
    pub fn encode(self: *const Tokenizer, allocator: std.mem.Allocator, text: []const u8) ![]u32 {
        var tokens = std.ArrayList(u32).init(allocator);
        errdefer tokens.deinit();

        // Add BOS token
        try tokens.append(self.bos_token);

        var pos: usize = 0;
        while (pos < text.len) {
            // First check for special tokens (they have priority)
            var found_special = false;
            const special_tokens = [_][]const u8{
                // Qwen/ChatML tokens
                "<|im_start|>", "<|im_end|>", "<|endoftext|>",
                "<|object_ref_start|>", "<|object_ref_end|>",
                "<|box_start|>", "<|box_end|>",
                "<|quad_start|>", "<|quad_end|>",
                "<|vision_start|>", "<|vision_end|>",
                "<|vision_pad|>", "<|image_pad|>", "<|video_pad|>",
                "<tool_call>", "</tool_call>",
                "<|fim_prefix|>", "<|fim_middle|>", "<|fim_suffix|>",
                "<|fim_pad|>", "<|repo_name|>", "<|file_sep|>",
                // DeepSeek tokens
                "<|User|>", "<|Assistant|>", "<|EOT|>",
                "<｜begin▁of▁sentence｜>", "<｜end▁of▁sentence｜>",
                "<｜fim▁hole｜>", "<｜fim▁begin｜>", "<｜fim▁end｜>",
            };
            
            for (special_tokens) |special| {
                if (pos + special.len <= text.len and 
                    std.mem.eql(u8, text[pos..][0..special.len], special)) {
                    if (self.token_to_id.get(special)) |id| {
                        try tokens.append(id);
                        pos += special.len;
                        found_special = true;
                        break;
                    }
                }
            }
            if (found_special) continue;
            
            // Skip spaces at start of words - they become part of the next token
            const at_word_start = pos == 0 or (pos > 0 and text[pos - 1] == ' ');
            
            // Try to find longest matching token
            var best_len: usize = 0;
            var best_token: u32 = 0;

            // Try different lengths (longest first)
            var len: usize = @min(text.len - pos, 20); // Max token length
            while (len > 0) : (len -= 1) {
                const substr = text[pos..][0..len];
                
                // Handle newline - convert to Ċ (0xC4 0x8A) for GPT-2 style
                if (substr[0] == '\n') {
                    // Try to find "Ċ" + rest of substr
                    var with_newline: [32]u8 = undefined;
                    with_newline[0] = 0xC4;
                    with_newline[1] = 0x8A;
                    if (len == 1) {
                        // Just newline
                        if (self.token_to_id.get(with_newline[0..2])) |id| {
                            best_len = 1;
                            best_token = id;
                            break;
                        }
                    } else if (len > 1) {
                        const rest = substr[1..];
                        if (rest.len + 2 <= 32) {
                            @memcpy(with_newline[2..][0..rest.len], rest);
                            if (self.token_to_id.get(with_newline[0 .. rest.len + 2])) |id| {
                                best_len = len;
                                best_token = id;
                                break;
                            }
                        }
                    }
                    // Fallback: try raw newline
                    if (self.token_to_id.get("\n")) |id| {
                        best_len = 1;
                        best_token = id;
                        break;
                    }
                    // Skip newline if not found
                    best_len = 1;
                    best_token = 0;
                    break;
                }
                
                // Skip if substr starts with space - we handle spaces specially
                if (substr[0] == ' ') {
                    // Try to find "Ġ" + rest of substr (GPT-2 style)
                    if (len > 1) {
                        var with_gpt2_space: [32]u8 = undefined;
                        with_gpt2_space[0] = 0xC4;
                        with_gpt2_space[1] = 0xA0;
                        const rest = substr[1..];
                        if (rest.len + 2 <= 32) {
                            @memcpy(with_gpt2_space[2..][0..rest.len], rest);
                            if (self.token_to_id.get(with_gpt2_space[0 .. rest.len + 2])) |id| {
                                best_len = len;
                                best_token = id;
                                break;
                            }
                        }
                    }
                    // Single space - try Ġ alone
                    if (len == 1) {
                        const gpt2_space = [_]u8{ 0xC4, 0xA0 };
                        if (self.token_to_id.get(&gpt2_space)) |id| {
                            best_len = 1;
                            best_token = id;
                            break;
                        }
                        best_len = 1;
                        best_token = 0; // Will be skipped
                        break;
                    }
                    continue;
                }

                // Check with GPT-2 style space prefix (Ġ = 0xC4 0xA0) for word starts
                if (at_word_start and pos > 0) {
                    var with_gpt2_space: [32]u8 = undefined;
                    with_gpt2_space[0] = 0xC4;
                    with_gpt2_space[1] = 0xA0;
                    if (len + 2 <= 32) {
                        @memcpy(with_gpt2_space[2..][0..len], substr);
                        if (self.token_to_id.get(with_gpt2_space[0 .. len + 2])) |id| {
                            if (len + 2 > best_len) {
                                best_len = len;
                                best_token = id;
                            }
                        }
                    }
                }

                // Check with Llama style space prefix (▁ = 0xE2 0x96 0x81)
                if (at_word_start and pos > 0) {
                    var with_llama_space: [32]u8 = undefined;
                    with_llama_space[0] = 0xE2;
                    with_llama_space[1] = 0x96;
                    with_llama_space[2] = 0x81;
                    if (len + 3 <= 32) {
                        @memcpy(with_llama_space[3..][0..len], substr);
                        if (self.token_to_id.get(with_llama_space[0 .. len + 3])) |id| {
                            if (len + 3 > best_len) {
                                best_len = len;
                                best_token = id;
                            }
                        }
                    }
                }

                // Check without space prefix
                if (self.token_to_id.get(substr)) |id| {
                    if (len > best_len) {
                        best_len = len;
                        best_token = id;
                    }
                }

                if (best_len > 0) break;
            }

            if (best_len > 0) {
                if (best_token != 0) { // Skip UNK for spaces
                    try tokens.append(best_token);
                }
                pos += best_len;
            } else {
                // Unknown character - try single byte
                const byte_str = text[pos..][0..1];
                if (self.token_to_id.get(byte_str)) |id| {
                    try tokens.append(id);
                } else {
                    // Skip unknown byte
                    try tokens.append(0); // UNK token
                }
                pos += 1;
            }
        }

        return tokens.toOwnedSlice();
    }

    // Decode tokens to text
    pub fn decode(self: *const Tokenizer, allocator: std.mem.Allocator, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        for (tokens) |token| {
            if (token < self.vocab_size) {
                const text = self.vocab[token];
                // Replace special space characters with regular space
                var i: usize = 0;
                while (i < text.len) {
                    // Llama-style space: ▁ (U+2581) = 0xE2 0x96 0x81
                    if (i + 2 < text.len and text[i] == 0xE2 and text[i + 1] == 0x96 and text[i + 2] == 0x81) {
                        try result.append(' ');
                        i += 3;
                    }
                    // GPT-2 style space: Ġ (U+0120) = 0xC4 0xA0
                    else if (i + 1 < text.len and text[i] == 0xC4 and text[i + 1] == 0xA0) {
                        try result.append(' ');
                        i += 2;
                    }
                    // Newline token: Ċ (U+010A) = 0xC4 0x8A
                    else if (i + 1 < text.len and text[i] == 0xC4 and text[i + 1] == 0x8A) {
                        try result.append('\n');
                        i += 2;
                    }
                    else {
                        try result.append(text[i]);
                        i += 1;
                    }
                }
            }
        }

        return result.toOwnedSlice();
    }

    // Get token string
    pub fn getToken(self: *const Tokenizer, id: u32) []const u8 {
        if (id < self.vocab_size) {
            return self.vocab[id];
        }
        return "<UNK>";
    }

    pub fn printInfo(self: *const Tokenizer) void {
        std.debug.print("TOKENIZER INFO\n", .{});
        std.debug.print("  Vocab size:  {d}\n", .{self.vocab_size});
        std.debug.print("  BOS token:   {d}\n", .{self.bos_token});
        std.debug.print("  EOS token:   {d}\n", .{self.eos_token});
        std.debug.print("  PAD token:   {d}\n", .{self.pad_token});
    }
};

// Chat template for TinyLlama
pub const ChatTemplate = struct {
    system_prefix: []const u8,
    system_suffix: []const u8,
    user_prefix: []const u8,
    user_suffix: []const u8,
    assistant_prefix: []const u8,
    assistant_suffix: []const u8,

    pub const TINYLLAMA = ChatTemplate{
        .system_prefix = "<|system|>\n",
        .system_suffix = "</s>\n",
        .user_prefix = "<|user|>\n",
        .user_suffix = "</s>\n",
        .assistant_prefix = "<|assistant|>\n",
        .assistant_suffix = "</s>\n",
    };

    pub const LLAMA2 = ChatTemplate{
        .system_prefix = "[INST] <<SYS>>\n",
        .system_suffix = "\n<</SYS>>\n\n",
        .user_prefix = "",
        .user_suffix = " [/INST] ",
        .assistant_prefix = "",
        .assistant_suffix = " </s><s>[INST] ",
    };

    // Qwen2.5 chat template
    pub const QWEN = ChatTemplate{
        .system_prefix = "<|im_start|>system\n",
        .system_suffix = "<|im_end|>\n",
        .user_prefix = "<|im_start|>user\n",
        .user_suffix = "<|im_end|>\n",
        .assistant_prefix = "<|im_start|>assistant\n",
        .assistant_suffix = "<|im_end|>\n",
    };

    // SmolLM chat template
    pub const SMOLLM = ChatTemplate{
        .system_prefix = "<|im_start|>system\n",
        .system_suffix = "<|im_end|>\n",
        .user_prefix = "<|im_start|>user\n",
        .user_suffix = "<|im_end|>\n",
        .assistant_prefix = "<|im_start|>assistant\n",
        .assistant_suffix = "<|im_end|>\n",
    };

    // DeepSeek Coder chat template (no system prompt)
    pub const DEEPSEEK = ChatTemplate{
        .system_prefix = "",
        .system_suffix = "",
        .user_prefix = "<|User|>",
        .user_suffix = "\n",
        .assistant_prefix = "<|Assistant|>",
        .assistant_suffix = "<|EOT|>\n",
    };

    pub fn formatPrompt(
        self: *const ChatTemplate,
        allocator: std.mem.Allocator,
        system: ?[]const u8,
        user: []const u8,
    ) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        // System message
        if (system) |sys| {
            try result.appendSlice(self.system_prefix);
            try result.appendSlice(sys);
            try result.appendSlice(self.system_suffix);
        }

        // User message
        try result.appendSlice(self.user_prefix);
        try result.appendSlice(user);
        try result.appendSlice(self.user_suffix);

        // Assistant prefix (model will continue from here)
        try result.appendSlice(self.assistant_prefix);

        return result.toOwnedSlice();
    }
};

test "chat_template" {
    const allocator = std.testing.allocator;

    const prompt = try ChatTemplate.TINYLLAMA.formatPrompt(
        allocator,
        "You are a helpful assistant.",
        "Hello!",
    );
    defer allocator.free(prompt);

    try std.testing.expect(prompt.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Hello!") != null);
}
