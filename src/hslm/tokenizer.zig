// HSLM — Ternary Tokenizer
// 729-vocab (3⁶) byte-level tokenizer with ternary encoding
// Each token ID can be represented as a 6-trit balanced ternary number

const std = @import("std");
const constants = @import("constants.zig");

pub const VOCAB_SIZE = constants.VOCAB_SIZE; // 729

// ═══════════════════════════════════════════════════════════════════════════════
// SPECIAL TOKENS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PAD_TOKEN: u16 = 0;
pub const BOS_TOKEN: u16 = 1; // Beginning of sequence
pub const EOS_TOKEN: u16 = 2; // End of sequence
pub const UNK_TOKEN: u16 = 3; // Unknown
pub const SPECIAL_COUNT: u16 = 4;

// Byte tokens: 4..259 (256 byte values)
pub const BYTE_OFFSET: u16 = SPECIAL_COUNT;
pub const BYTE_COUNT: u16 = 256;

// Bigram tokens: 260..728 (469 most common bigrams)
pub const BIGRAM_OFFSET: u16 = BYTE_OFFSET + BYTE_COUNT; // 260
pub const BIGRAM_COUNT: u16 = VOCAB_SIZE - BIGRAM_OFFSET; // 469

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tokenizer = struct {
    // Top 469 bigrams sorted by frequency (English text)
    bigram_table: [BIGRAM_COUNT][2]u8,
    // Reverse lookup: hash(byte1, byte2) -> bigram index
    bigram_lookup: std.AutoHashMap(u16, u16),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .bigram_table = undefined,
            .bigram_lookup = std.AutoHashMap(u16, u16).init(allocator),
            .allocator = allocator,
        };

        // Initialize bigram table with most common English bigrams
        try self.initBigrams();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.bigram_lookup.deinit();
    }

    /// Encode text to token IDs
    pub fn encode(self: *Self, text: []const u8, output: []u16) usize {
        var out_idx: usize = 0;
        const max_out = output.len;

        // BOS
        if (out_idx < max_out) {
            output[out_idx] = BOS_TOKEN;
            out_idx += 1;
        }

        var i: usize = 0;
        while (i < text.len and out_idx < max_out) {
            // Try bigram first
            if (i + 1 < text.len) {
                const key = bigramKey(text[i], text[i + 1]);
                if (self.bigram_lookup.get(key)) |bigram_idx| {
                    output[out_idx] = BIGRAM_OFFSET + bigram_idx;
                    out_idx += 1;
                    i += 2;
                    continue;
                }
            }
            // Fall back to byte token
            output[out_idx] = BYTE_OFFSET + @as(u16, text[i]);
            out_idx += 1;
            i += 1;
        }

        // EOS
        if (out_idx < max_out) {
            output[out_idx] = EOS_TOKEN;
            out_idx += 1;
        }

        return out_idx;
    }

    /// Decode token IDs back to text
    pub fn decode(self: *Self, tokens: []const u16, output: []u8) usize {
        var out_idx: usize = 0;

        for (tokens) |token| {
            if (token == PAD_TOKEN or token == BOS_TOKEN or token == EOS_TOKEN) continue;
            if (token == UNK_TOKEN) {
                if (out_idx < output.len) {
                    output[out_idx] = '?';
                    out_idx += 1;
                }
                continue;
            }

            if (token >= BIGRAM_OFFSET and token < VOCAB_SIZE) {
                // Bigram token
                const idx = token - BIGRAM_OFFSET;
                const pair = self.bigram_table[idx];
                if (out_idx + 1 < output.len) {
                    output[out_idx] = pair[0];
                    output[out_idx + 1] = pair[1];
                    out_idx += 2;
                }
            } else if (token >= BYTE_OFFSET and token < BIGRAM_OFFSET) {
                // Byte token
                if (out_idx < output.len) {
                    output[out_idx] = @intCast(token - BYTE_OFFSET);
                    out_idx += 1;
                }
            }
        }

        return out_idx;
    }

    /// Convert token ID to 6-trit balanced ternary representation
    pub fn tokenToTrits(token: u16) [6]i8 {
        // Map 0..728 to balanced ternary with offset
        // 729 values = 3^6, center at 364
        var val: i32 = @as(i32, @intCast(token)) - 364;
        var trits: [6]i8 = .{ 0, 0, 0, 0, 0, 0 };

        for (0..6) |i| {
            var rem = @mod(val, 3);
            if (rem == 2) rem = -1;
            trits[i] = @intCast(rem);
            val = @divFloor(val - rem, 3);
        }

        return trits;
    }

    /// Convert 6-trit balanced ternary back to token ID
    pub fn tritsToToken(trits: [6]i8) u16 {
        var val: i32 = 0;
        var base: i32 = 1;
        for (0..6) |i| {
            val += @as(i32, trits[i]) * base;
            base *= 3;
        }
        val += 364; // Restore offset
        if (val < 0) return 0;
        if (val >= VOCAB_SIZE) return UNK_TOKEN;
        return @intCast(val);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRIVATE
    // ═══════════════════════════════════════════════════════════════════════

    fn bigramKey(a: u8, b: u8) u16 {
        return @as(u16, a) * 256 + @as(u16, b);
    }

    fn initBigrams(self: *Self) !void {
        // Top English bigrams by frequency
        const top_bigrams = [_][2]u8{
            .{ 't', 'h' }, .{ 'h', 'e' }, .{ 'i', 'n' }, .{ 'e', 'r' },
            .{ 'a', 'n' }, .{ 'r', 'e' }, .{ 'o', 'n' }, .{ 'a', 't' },
            .{ 'e', 'n' }, .{ 'n', 'd' }, .{ 't', 'i' }, .{ 'e', 's' },
            .{ 'o', 'r' }, .{ 't', 'e' }, .{ 'o', 'f' }, .{ 'e', 'd' },
            .{ 'i', 's' }, .{ 'i', 't' }, .{ 'a', 'l' }, .{ 'a', 'r' },
            .{ 's', 't' }, .{ 't', 'o' }, .{ 'n', 't' }, .{ 'n', 'g' },
            .{ 's', 'e' }, .{ 'h', 'a' }, .{ 'a', 's' }, .{ 'o', 'u' },
            .{ 'i', 'o' }, .{ 'l', 'e' }, .{ 'v', 'e' }, .{ 'c', 'o' },
            .{ 'm', 'e' }, .{ 'd', 'e' }, .{ 'h', 'i' }, .{ 'r', 'i' },
            .{ 'r', 'o' }, .{ 'i', 'c' }, .{ 'n', 'e' }, .{ 'e', 'a' },
            .{ 'r', 'a' }, .{ 'c', 'e' }, .{ ' ', 't' }, .{ ' ', 'a' },
            .{ ' ', 'i' }, .{ ' ', 's' }, .{ ' ', 'o' }, .{ ' ', 'w' },
            .{ ' ', 'h' }, .{ ' ', 'b' }, .{ ' ', 'c' }, .{ ' ', 'f' },
            .{ ' ', 'd' }, .{ ' ', 'm' }, .{ ' ', 'p' }, .{ 'e', ' ' },
            .{ 's', ' ' }, .{ 't', ' ' }, .{ 'd', ' ' }, .{ 'n', ' ' },
            .{ 'l', ' ' }, .{ 'y', ' ' }, .{ 'r', ' ' }, .{ 'f', ' ' },
            .{ ',', ' ' }, .{ '.', ' ' }, .{ 'l', 'l' }, .{ 'w', 'h' },
        };

        // Fill bigram table — first from our known list, rest are common byte pairs
        var idx: u16 = 0;
        for (top_bigrams) |bg| {
            if (idx >= BIGRAM_COUNT) break;
            self.bigram_table[idx] = bg;
            try self.bigram_lookup.put(bigramKey(bg[0], bg[1]), idx);
            idx += 1;
        }

        // Fill remaining slots with systematic byte pairs (a-z combinations)
        var c1: u8 = 'a';
        while (c1 <= 'z' and idx < BIGRAM_COUNT) : (c1 += 1) {
            var c2: u8 = 'a';
            while (c2 <= 'z' and idx < BIGRAM_COUNT) : (c2 += 1) {
                const key = bigramKey(c1, c2);
                if (!self.bigram_lookup.contains(key)) {
                    self.bigram_table[idx] = .{ c1, c2 };
                    try self.bigram_lookup.put(key, idx);
                    idx += 1;
                }
            }
        }

        // Fill any remaining with printable ASCII pairs
        var p1: u8 = 32;
        while (p1 < 127 and idx < BIGRAM_COUNT) : (p1 += 1) {
            var p2: u8 = 32;
            while (p2 < 127 and idx < BIGRAM_COUNT) : (p2 += 1) {
                const key = bigramKey(p1, p2);
                if (!self.bigram_lookup.contains(key)) {
                    self.bigram_table[idx] = .{ p1, p2 };
                    try self.bigram_lookup.put(key, idx);
                    idx += 1;
                }
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tokenizer encode/decode roundtrip" {
    const allocator = std.testing.allocator;
    var tok = try Tokenizer.init(allocator);
    defer tok.deinit();

    const text = "hello world";
    var tokens: [64]u16 = undefined;
    const n = tok.encode(text, &tokens);

    try std.testing.expect(n > 0);
    try std.testing.expect(tokens[0] == BOS_TOKEN);
    try std.testing.expect(tokens[n - 1] == EOS_TOKEN);

    var decoded: [128]u8 = undefined;
    const m = tok.decode(tokens[0..n], &decoded);
    try std.testing.expectEqualStrings(text, decoded[0..m]);
}

test "token to trits roundtrip" {
    // Test a few token IDs
    for (0..VOCAB_SIZE) |i| {
        const token: u16 = @intCast(i);
        const trits = Tokenizer.tokenToTrits(token);
        const recovered = Tokenizer.tritsToToken(trits);
        try std.testing.expectEqual(token, recovered);
    }
}

test "special tokens" {
    try std.testing.expect(PAD_TOKEN == 0);
    try std.testing.expect(BOS_TOKEN == 1);
    try std.testing.expect(EOS_TOKEN == 2);
    try std.testing.expect(UNK_TOKEN == 3);
    try std.testing.expect(BYTE_OFFSET == 4);
    try std.testing.expect(BIGRAM_OFFSET == 260);
    try std.testing.expect(BIGRAM_OFFSET + BIGRAM_COUNT == VOCAB_SIZE);
}
