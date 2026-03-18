// ═══════════════════════════════════════════════════════════════════════════════
// BPE TOKENIZER (HuggingFace format)
// Handles Ġ space markers, byte fallback, added_tokens
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BPE TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SentencePieceTokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: std.StringHashMap(u32),
    id_to_token: std.AutoHashMap(u32, []const u8),
    bos_token_id: u32 = 128000,
    eos_token_id: u32 = 128001,

    // BPE space marker: Ġ (U+0120)
    // UTF-8 encoding: 0xC4 0xA0
    const SPACE_MARKER = "\xc4\xa0";

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !SentencePieceTokenizer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
        defer allocator.free(content);

        var parsed = try json.parseFromSlice(json.Value, allocator, content, .{});
        defer parsed.deinit();

        var vocab = std.StringHashMap(u32).init(allocator);
        var id_to_token = std.AutoHashMap(u32, []const u8).init(allocator);

        var bos_id: u32 = 128000;
        var eos_id: u32 = 128001;

        // Parse added_tokens for special token IDs
        if (parsed.value.object.get("added_tokens")) |added| {
            for (added.array.items) |item| {
                const content_val = item.object.get("content") orelse continue;
                const id_val = item.object.get("id") orelse continue;
                const id: u32 = @intCast(id_val.integer);

                const tok_str = try allocator.dupe(u8, content_val.string);
                try vocab.put(tok_str, id);
                try id_to_token.put(id, tok_str);

                if (std.mem.eql(u8, content_val.string, "<|begin_of_text|>")) {
                    bos_id = id;
                } else if (std.mem.eql(u8, content_val.string, "<|end_of_text|>")) {
                    eos_id = id;
                }
            }
        }

        // Parse vocab from model section
        if (parsed.value.object.get("model")) |model| {
            if (model.object.get("vocab")) |vocab_obj| {
                var it = vocab_obj.object.iterator();
                while (it.next()) |entry| {
                    // Skip if already added (from added_tokens)
                    if (vocab.contains(entry.key_ptr.*)) continue;

                    const token = try allocator.dupe(u8, entry.key_ptr.*);
                    const id: u32 = @intCast(entry.value_ptr.*.integer);
                    try vocab.put(token, id);
                    try id_to_token.put(id, token);
                }
            }
        }

        std.debug.print("Loaded BPE tokenizer with {d} tokens (BOS={d}, EOS={d})\n", .{ vocab.count(), bos_id, eos_id });

        return SentencePieceTokenizer{
            .allocator = allocator,
            .vocab = vocab,
            .id_to_token = id_to_token,
            .bos_token_id = bos_id,
            .eos_token_id = eos_id,
        };
    }

    /// Encode text to token IDs using greedy longest-match
    /// Spaces in input are replaced with Ġ marker for BPE lookup
    pub fn encode(self: *SentencePieceTokenizer, text: []const u8) ![]u32 {
        var tokens: std.ArrayList(u32) = .empty;

        // Add BOS token
        try tokens.append(self.allocator, self.bos_token_id);

        // Replace spaces with Ġ marker (BPE convention)
        var processed: std.ArrayList(u8) = .empty;
        defer processed.deinit(self.allocator);

        for (text) |ch| {
            if (ch == ' ') {
                try processed.appendSlice(self.allocator, SPACE_MARKER);
            } else {
                try processed.append(self.allocator, ch);
            }
        }

        const input = processed.items;
        var i: usize = 0;

        while (i < input.len) {
            var found = false;

            // Try longest token first (greedy)
            var max_len = @min(input.len - i, 64);
            while (max_len > 0) : (max_len -= 1) {
                const substr = input[i .. i + max_len];
                if (self.vocab.get(substr)) |id| {
                    try tokens.append(self.allocator, id);
                    i += max_len;
                    found = true;
                    break;
                }
            }

            if (!found) {
                // Byte fallback: encode as <0xNN>
                const byte = input[i];
                var byte_token: [6]u8 = undefined;
                _ = std.fmt.bufPrint(&byte_token, "<0x{X:0>2}>", .{byte}) catch unreachable;

                if (self.vocab.get(&byte_token)) |id| {
                    try tokens.append(self.allocator, id);
                } else {
                    // Skip unknown byte
                    std.debug.print("Warning: unknown byte 0x{X:0>2} at position {d}\n", .{ byte, i });
                }
                i += 1;
            }
        }

        return tokens.toOwnedSlice(self.allocator);
    }

    /// Decode token IDs to text
    pub fn decode(self: *SentencePieceTokenizer, tokens: []const u32) ![]u8 {
        var result: std.ArrayList(u8) = .empty;

        for (tokens) |id| {
            // Skip special tokens
            if (id == self.bos_token_id or id == self.eos_token_id) continue;
            if (id >= 128000) continue; // Skip all special tokens

            if (self.id_to_token.get(id)) |token| {
                // Check for byte fallback tokens <0xNN>
                if (token.len == 6 and token[0] == '<' and token[1] == '0' and token[2] == 'x' and token[5] == '>') {
                    const hex = token[3..5];
                    const byte = std.fmt.parseInt(u8, hex, 16) catch {
                        try result.appendSlice(self.allocator, token);
                        continue;
                    };
                    try result.append(self.allocator, byte);
                    continue;
                }

                // Process token: replace Ġ (0xC4 0xA0) with space
                var j: usize = 0;
                while (j < token.len) {
                    if (j + 2 <= token.len and
                        token[j] == 0xC4 and
                        token[j + 1] == 0xA0)
                    {
                        try result.append(self.allocator, ' ');
                        j += 2;
                    } else {
                        try result.append(self.allocator, token[j]);
                        j += 1;
                    }
                }
            } else {
                try result.appendSlice(self.allocator, "[UNK]");
            }
        }

        // Strip leading space if present
        const output = try result.toOwnedSlice(self.allocator);
        if (output.len > 0 and output[0] == ' ') {
            const trimmed = try self.allocator.dupe(u8, output[1..]);
            self.allocator.free(output);
            return trimmed;
        }

        return output;
    }

    pub fn deinit(self: *SentencePieceTokenizer) void {
        var it = self.vocab.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.vocab.deinit();
        self.id_to_token.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "space marker Ġ detection" {
    const SPACE_MARKER = "\xc4\xa0";
    try std.testing.expectEqual(@as(usize, 2), SPACE_MARKER.len);
    try std.testing.expectEqual(@as(u8, 0xC4), SPACE_MARKER[0]);
    try std.testing.expectEqual(@as(u8, 0xA0), SPACE_MARKER[1]);
}

test "byte fallback parsing" {
    const token = "<0x0A>";
    try std.testing.expectEqual(@as(usize, 6), token.len);

    const hex = token[3..5];
    const byte = try std.fmt.parseInt(u8, hex, 16);
    try std.testing.expectEqual(@as(u8, 0x0A), byte);
}
