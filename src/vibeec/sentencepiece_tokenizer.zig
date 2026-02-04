// ═══════════════════════════════════════════════════════════════════════════════
// SENTENCEPIECE BPE TOKENIZER
// Proper decoding with ▁ space markers and byte fallback
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// SENTENCEPIECE TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const SentencePieceTokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: std.StringHashMap(u32),
    id_to_token: std.AutoHashMap(u32, []const u8),
    bos_token_id: u32 = 1,  // <s>
    eos_token_id: u32 = 2,  // </s>
    unk_token_id: u32 = 0,  // <unk>
    
    // Space marker: ▁ (U+2581, LOWER ONE EIGHTH BLOCK)
    // UTF-8 encoding: 0xE2 0x96 0x81
    const SPACE_MARKER = "\xe2\x96\x81";
    
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !SentencePieceTokenizer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
        defer allocator.free(content);
        
        var parsed = try json.parseFromSlice(json.Value, allocator, content, .{});
        defer parsed.deinit();
        
        var vocab = std.StringHashMap(u32).init(allocator);
        var id_to_token = std.AutoHashMap(u32, []const u8).init(allocator);
        
        // Parse vocab from model section
        if (parsed.value.object.get("model")) |model| {
            if (model.object.get("vocab")) |vocab_obj| {
                var it = vocab_obj.object.iterator();
                while (it.next()) |entry| {
                    const token = try allocator.dupe(u8, entry.key_ptr.*);
                    const id: u32 = @intCast(entry.value_ptr.*.integer);
                    try vocab.put(token, id);
                    try id_to_token.put(id, token);
                }
            }
        }
        
        std.debug.print("Loaded SentencePiece tokenizer with {d} tokens\n", .{vocab.count()});
        
        return SentencePieceTokenizer{
            .allocator = allocator,
            .vocab = vocab,
            .id_to_token = id_to_token,
        };
    }
    
    /// Encode text to token IDs using greedy longest-match
    pub fn encode(self: *SentencePieceTokenizer, text: []const u8) ![]u32 {
        var tokens = std.ArrayList(u32).init(self.allocator);
        
        // Add BOS token
        try tokens.append(self.bos_token_id);
        
        // Prepend space marker for first word (SentencePiece convention)
        var processed_text = std.ArrayList(u8).init(self.allocator);
        defer processed_text.deinit();
        try processed_text.appendSlice(SPACE_MARKER);
        try processed_text.appendSlice(text);
        
        const input = processed_text.items;
        var i: usize = 0;
        
        while (i < input.len) {
            var found = false;
            
            // Try to match longest token first (greedy)
            var max_len = @min(input.len - i, 50); // Max token length
            while (max_len > 0) : (max_len -= 1) {
                const substr = input[i..i + max_len];
                if (self.vocab.get(substr)) |id| {
                    try tokens.append(id);
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
                    try tokens.append(id);
                } else {
                    // Unknown byte, use UNK
                    try tokens.append(self.unk_token_id);
                }
                i += 1;
            }
        }
        
        return tokens.toOwnedSlice();
    }
    
    /// Decode token IDs to text with proper SentencePiece handling
    pub fn decode(self: *SentencePieceTokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        
        for (tokens) |id| {
            // Skip special tokens
            if (id == self.bos_token_id or id == self.eos_token_id) continue;
            
            if (self.id_to_token.get(id)) |token| {
                // Check for byte fallback tokens <0xNN>
                if (token.len == 6 and token[0] == '<' and token[1] == '0' and token[2] == 'x' and token[5] == '>') {
                    // Parse hex byte
                    const hex = token[3..5];
                    const byte = std.fmt.parseInt(u8, hex, 16) catch {
                        try result.appendSlice(token);
                        continue;
                    };
                    try result.append(byte);
                    continue;
                }
                
                // Process token character by character
                var j: usize = 0;
                while (j < token.len) {
                    // Check for space marker ▁ (3 bytes: 0xE2 0x96 0x81)
                    if (j + 3 <= token.len and 
                        token[j] == 0xE2 and 
                        token[j + 1] == 0x96 and 
                        token[j + 2] == 0x81) 
                    {
                        try result.append(' ');
                        j += 3;
                    } else {
                        try result.append(token[j]);
                        j += 1;
                    }
                }
            } else {
                // Unknown token
                try result.appendSlice("[UNK]");
            }
        }
        
        // Strip leading space (SentencePiece convention)
        const output = try result.toOwnedSlice();
        if (output.len > 0 and output[0] == ' ') {
            const trimmed = try self.allocator.dupe(u8, output[1..]);
            self.allocator.free(output);
            return trimmed;
        }
        
        return output;
    }
    
    /// Decode with detailed token info (for debugging)
    pub fn decodeVerbose(self: *SentencePieceTokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        
        for (tokens, 0..) |id, idx| {
            if (id == self.bos_token_id) {
                try result.appendSlice("[BOS]");
                continue;
            }
            if (id == self.eos_token_id) {
                try result.appendSlice("[EOS]");
                continue;
            }
            
            if (self.id_to_token.get(id)) |token| {
                // Show token with ID
                var buf: [64]u8 = undefined;
                const info = std.fmt.bufPrint(&buf, "[{d}:", .{id}) catch "";
                try result.appendSlice(info);
                
                // Process token
                var j: usize = 0;
                while (j < token.len) {
                    if (j + 3 <= token.len and 
                        token[j] == 0xE2 and 
                        token[j + 1] == 0x96 and 
                        token[j + 2] == 0x81) 
                    {
                        try result.append('_'); // Show space marker as underscore
                        j += 3;
                    } else {
                        try result.append(token[j]);
                        j += 1;
                    }
                }
                try result.append(']');
            } else {
                var buf: [32]u8 = undefined;
                const unk = std.fmt.bufPrint(&buf, "[UNK:{d}]", .{id}) catch "[UNK]";
                try result.appendSlice(unk);
            }
            
            if (idx < tokens.len - 1) {
                try result.append(' ');
            }
        }
        
        return result.toOwnedSlice();
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

test "space marker detection" {
    const SPACE_MARKER = "\xe2\x96\x81";
    try std.testing.expectEqual(@as(usize, 3), SPACE_MARKER.len);
    try std.testing.expectEqual(@as(u8, 0xE2), SPACE_MARKER[0]);
    try std.testing.expectEqual(@as(u8, 0x96), SPACE_MARKER[1]);
    try std.testing.expectEqual(@as(u8, 0x81), SPACE_MARKER[2]);
}

test "byte fallback parsing" {
    const token = "<0x0A>";
    try std.testing.expectEqual(@as(usize, 6), token.len);
    try std.testing.expectEqual(@as(u8, '<'), token[0]);
    try std.testing.expectEqual(@as(u8, '0'), token[1]);
    try std.testing.expectEqual(@as(u8, 'x'), token[2]);
    
    const hex = token[3..5];
    const byte = try std.fmt.parseInt(u8, hex, 16);
    try std.testing.expectEqual(@as(u8, 0x0A), byte); // newline
}
