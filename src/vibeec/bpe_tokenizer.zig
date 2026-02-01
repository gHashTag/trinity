// BPE TOKENIZER - Byte Pair Encoding для Qwen2.5-Coder
// Загрузка tokenizer.json и encode/decode текста
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// SPECIAL TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecialTokens = struct {
    pub const PAD: u32 = 151643;
    pub const EOS: u32 = 151645; // <|endoftext|>
    pub const BOS: u32 = 151643;

    // Qwen chat format
    pub const IM_START: u32 = 151644; // <|im_start|>
    pub const IM_END: u32 = 151645; // <|im_end|>
};

// ═══════════════════════════════════════════════════════════════════════════════
// BPE TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BPETokenizer = struct {
    allocator: std.mem.Allocator,

    // Token -> ID mapping
    vocab: std.StringHashMap(u32),

    // ID -> Token mapping (for decode)
    id_to_token: std.AutoHashMap(u32, []const u8),

    // BPE merges: (token1, token2) -> merged_token
    merges: std.StringHashMap([]const u8),

    vocab_size: u32,

    pub fn init(allocator: std.mem.Allocator) BPETokenizer {
        return BPETokenizer{
            .allocator = allocator,
            .vocab = std.StringHashMap(u32).init(allocator),
            .id_to_token = std.AutoHashMap(u32, []const u8).init(allocator),
            .merges = std.StringHashMap([]const u8).init(allocator),
            .vocab_size = 0,
        };
    }

    pub fn deinit(self: *BPETokenizer) void {
        // Free vocab keys
        var vocab_it = self.vocab.iterator();
        while (vocab_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.vocab.deinit();

        // Free id_to_token values
        var id_it = self.id_to_token.iterator();
        while (id_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.id_to_token.deinit();

        // Free merges
        var merge_it = self.merges.iterator();
        while (merge_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.merges.deinit();
    }

    /// Load from tokenizer.json file
    pub fn loadFromFile(self: *BPETokenizer, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(content);
        _ = try file.readAll(content);

        try self.parseTokenizerJson(content);
    }

    /// Parse tokenizer.json content
    fn parseTokenizerJson(self: *BPETokenizer, json: []const u8) !void {
        // Find vocab section
        const vocab_start = std.mem.indexOf(u8, json, "\"vocab\": {") orelse return error.InvalidFormat;
        const vocab_content_start = vocab_start + 10;

        // Find matching closing brace
        var brace_count: i32 = 1;
        var vocab_end: usize = vocab_content_start;
        while (vocab_end < json.len and brace_count > 0) : (vocab_end += 1) {
            if (json[vocab_end] == '{') brace_count += 1;
            if (json[vocab_end] == '}') brace_count -= 1;
        }

        // Parse vocab entries
        var i: usize = vocab_content_start;
        while (i < vocab_end) {
            // Find token string
            const quote1 = std.mem.indexOf(u8, json[i..], "\"") orelse break;
            const token_start = i + quote1 + 1;

            // Find end of token (handle escaped quotes)
            var token_end = token_start;
            while (token_end < json.len) : (token_end += 1) {
                if (json[token_end] == '"' and (token_end == token_start or json[token_end - 1] != '\\')) {
                    break;
                }
            }

            if (token_end >= json.len) break;

            const token = json[token_start..token_end];

            // Find ID
            const colon = std.mem.indexOf(u8, json[token_end..], ":") orelse break;
            const id_start = token_end + colon + 1;

            // Skip whitespace
            var id_pos = id_start;
            while (id_pos < json.len and (json[id_pos] == ' ' or json[id_pos] == '\n')) : (id_pos += 1) {}

            // Parse ID number
            var id_end = id_pos;
            while (id_end < json.len and json[id_end] >= '0' and json[id_end] <= '9') : (id_end += 1) {}

            if (id_end == id_pos) {
                i = id_end + 1;
                continue;
            }

            const id = std.fmt.parseInt(u32, json[id_pos..id_end], 10) catch {
                i = id_end + 1;
                continue;
            };

            // Unescape token and add to vocab
            const unescaped = try self.unescapeToken(token);
            const token_copy = try self.allocator.dupe(u8, unescaped);
            self.allocator.free(unescaped);

            try self.vocab.put(token_copy, id);

            const token_for_id = try self.allocator.dupe(u8, token_copy);
            try self.id_to_token.put(id, token_for_id);

            if (id >= self.vocab_size) {
                self.vocab_size = id + 1;
            }

            i = id_end + 1;
        }

        std.debug.print("Loaded {d} tokens\n", .{self.vocab.count()});
    }

    /// Unescape JSON string (handle \n, \t, \\, etc.)
    fn unescapeToken(self: *BPETokenizer, token: []const u8) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);

        var i: usize = 0;
        while (i < token.len) {
            if (token[i] == '\\' and i + 1 < token.len) {
                switch (token[i + 1]) {
                    'n' => try result.append('\n'),
                    't' => try result.append('\t'),
                    'r' => try result.append('\r'),
                    '\\' => try result.append('\\'),
                    '"' => try result.append('"'),
                    'u' => {
                        // Unicode escape \uXXXX
                        if (i + 5 < token.len) {
                            const hex = token[i + 2 .. i + 6];
                            const codepoint = std.fmt.parseInt(u21, hex, 16) catch {
                                try result.append('\\');
                                try result.append('u');
                                i += 2;
                                continue;
                            };
                            var buf: [4]u8 = undefined;
                            const len = std.unicode.utf8Encode(codepoint, &buf) catch 0;
                            try result.appendSlice(buf[0..len]);
                            i += 6;
                            continue;
                        }
                        try result.append(token[i]);
                        i += 1;
                        continue;
                    },
                    else => {
                        try result.append(token[i]);
                        i += 1;
                        continue;
                    },
                }
                i += 2;
            } else {
                try result.append(token[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice();
    }

    /// Encode text to token IDs
    pub fn encode(self: *BPETokenizer, text: []const u8) ![]u32 {
        var tokens = std.ArrayList(u32).init(self.allocator);

        // Convert text to bytes with Ġ prefix for spaces
        var processed = std.ArrayList(u8).init(self.allocator);
        defer processed.deinit();

        var first = true;
        for (text) |c| {
            if (c == ' ') {
                // Ġ is the GPT-2 style space marker (U+0120)
                try processed.appendSlice("Ġ");
            } else if (c == '\n') {
                try processed.appendSlice("Ċ");
            } else {
                if (first and c != ' ') {
                    // Don't add space marker at start
                }
                try processed.append(c);
            }
            first = false;
        }

        // Greedy tokenization (simplified - not full BPE)
        var i: usize = 0;
        while (i < processed.items.len) {
            // Try to find longest matching token
            var best_len: usize = 0;
            var best_id: u32 = 0;

            // Try lengths from max to 1
            const max_len = @min(processed.items.len - i, 20);
            var len: usize = max_len;
            while (len > 0) : (len -= 1) {
                const substr = processed.items[i .. i + len];
                if (self.vocab.get(substr)) |id| {
                    best_len = len;
                    best_id = id;
                    break;
                }
            }

            if (best_len > 0) {
                try tokens.append(best_id);
                i += best_len;
            } else {
                // Unknown byte - use byte fallback
                const byte_token = [_]u8{processed.items[i]};
                if (self.vocab.get(&byte_token)) |id| {
                    try tokens.append(id);
                } else {
                    // Skip unknown
                    std.debug.print("Unknown byte: {d}\n", .{processed.items[i]});
                }
                i += 1;
            }
        }

        return tokens.toOwnedSlice();
    }

    /// Decode token IDs to text
    pub fn decode(self: *BPETokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);

        for (tokens) |token_id| {
            if (self.id_to_token.get(token_id)) |token| {
                // Replace Ġ with space, Ċ with newline
                for (token) |c| {
                    if (c == 0xC4) {
                        // Start of Ġ (U+0120) or Ċ (U+010A) in UTF-8
                        continue;
                    } else if (c == 0xA0) {
                        // Second byte of Ġ
                        try result.append(' ');
                    } else if (c == 0x8A) {
                        // Second byte of Ċ
                        try result.append('\n');
                    } else {
                        try result.append(c);
                    }
                }
            }
        }

        return result.toOwnedSlice();
    }

    /// Get token string by ID
    pub fn getToken(self: *const BPETokenizer, id: u32) ?[]const u8 {
        return self.id_to_token.get(id);
    }

    /// Get ID by token string
    pub fn getId(self: *const BPETokenizer, token: []const u8) ?u32 {
        return self.vocab.get(token);
    }

    /// Print tokenizer info
    pub fn printInfo(self: *const BPETokenizer) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           BPE TOKENIZER INFO                                 ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Vocab size:       {d:>10}                               ║\n", .{self.vocab_size});
        std.debug.print("║ Loaded tokens:    {d:>10}                               ║\n", .{self.vocab.count()});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE TOKENIZER (for testing without full vocab)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimpleTokenizer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SimpleTokenizer {
        return SimpleTokenizer{ .allocator = allocator };
    }

    /// Simple character-level encoding
    pub fn encode(self: *SimpleTokenizer, text: []const u8) ![]u32 {
        var tokens = try self.allocator.alloc(u32, text.len);
        for (text, 0..) |c, i| {
            tokens[i] = c;
        }
        return tokens;
    }

    /// Simple character-level decoding
    pub fn decode(self: *SimpleTokenizer, tokens: []const u32) ![]u8 {
        var result = try self.allocator.alloc(u8, tokens.len);
        for (tokens, 0..) |t, i| {
            result[i] = @truncate(t);
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "simple tokenizer" {
    const allocator = std.testing.allocator;
    var tokenizer = SimpleTokenizer.init(allocator);

    const text = "Hello";
    const tokens = try tokenizer.encode(text);
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 5), tokens.len);
    try std.testing.expectEqual(@as(u32, 'H'), tokens[0]);

    const decoded = try tokenizer.decode(tokens);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(text, decoded);
}

test "bpe tokenizer init" {
    const allocator = std.testing.allocator;
    var tokenizer = BPETokenizer.init(allocator);
    defer tokenizer.deinit();

    try std.testing.expectEqual(@as(u32, 0), tokenizer.vocab_size);
}

test "bpe tokenizer load" {
    const allocator = std.testing.allocator;
    var tokenizer = BPETokenizer.init(allocator);
    defer tokenizer.deinit();

    // Skip if file doesn't exist
    std.fs.cwd().access("models/qwen-coder-7b/tokenizer.json", .{}) catch {
        std.debug.print("Skipping: tokenizer.json not found\n", .{});
        return;
    };

    try tokenizer.loadFromFile("models/qwen-coder-7b/tokenizer.json");
    tokenizer.printInfo();

    // At least some tokens should be loaded
    try std.testing.expect(tokenizer.vocab_size > 100);
}

test "bpe encode decode" {
    const allocator = std.testing.allocator;
    var tokenizer = BPETokenizer.init(allocator);
    defer tokenizer.deinit();

    // Skip if file doesn't exist
    std.fs.cwd().access("models/qwen-coder-7b/tokenizer.json", .{}) catch {
        std.debug.print("Skipping: tokenizer.json not found\n", .{});
        return;
    };

    try tokenizer.loadFromFile("models/qwen-coder-7b/tokenizer.json");

    const text = "Hello world";
    const tokens = try tokenizer.encode(text);
    defer allocator.free(tokens);

    std.debug.print("Encoded '{s}' to {d} tokens: ", .{ text, tokens.len });
    for (tokens) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    const decoded = try tokenizer.decode(tokens);
    defer allocator.free(decoded);

    std.debug.print("Decoded: '{s}'\n", .{decoded});
}
