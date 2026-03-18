// @origin(spec:tokenizer.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — BPE Tokenizer
// 729-vocab (3⁶) byte-pair encoding tokenizer with ternary encoding
// Each token ID can be represented as a 6-trit balanced ternary number
//
// Layout: [0-3] special | [4-259] raw bytes | [260-728] BPE merges

const std = @import("std");
const constants = @import("constants.zig");
const bpe_merges = @import("bpe_merges.zig");

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

// BPE merge tokens: 260..728 (469 learned merge rules)
pub const MERGE_OFFSET: u16 = BYTE_OFFSET + BYTE_COUNT; // 260
pub const MERGE_COUNT: u16 = VOCAB_SIZE - MERGE_OFFSET; // 469

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tokenizer = struct {
    // merge_lookup: pair(left, right) → merge token ID
    merge_lookup: std.AutoHashMap(u32, u16),
    // For decode: precomputed byte offsets into flattened byte data
    byte_offsets: [MERGE_COUNT]u16,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .merge_lookup = std.AutoHashMap(u32, u16).init(allocator),
            .byte_offsets = undefined,
            .allocator = allocator,
        };

        // Build merge lookup from comptime data
        // Lower merge index = higher priority (learned first = most frequent)
        for (0..MERGE_COUNT) |i| {
            const rule = bpe_merges.merge_rules[i];
            const key = pairKey(rule[0], rule[1]);
            // Only insert if not already present (first occurrence = highest priority)
            const entry = try self.merge_lookup.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = MERGE_OFFSET + @as(u16, @intCast(i));
            }
        }

        // Precompute byte offsets for decode
        var offset: u16 = 0;
        for (0..MERGE_COUNT) |i| {
            self.byte_offsets[i] = offset;
            offset += bpe_merges.merge_byte_lengths[i];
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.merge_lookup.deinit();
    }

    /// Encode text to token IDs using BPE
    pub fn encode(_: *Self, text: []const u8, output: []u16) usize {
        var out_idx: usize = 0;
        const max_out = output.len;

        // BOS
        if (out_idx < max_out) {
            output[out_idx] = BOS_TOKEN;
            out_idx += 1;
        }

        if (text.len == 0) {
            if (out_idx < max_out) {
                output[out_idx] = EOS_TOKEN;
                out_idx += 1;
            }
            return out_idx;
        }

        // Step 1: Convert text to byte tokens
        // Use output buffer as workspace for initial byte tokens
        // We need space for byte tokens + BOS + EOS, so limit input
        const max_input = @min(text.len, max_out -| 2);

        // Use a separate workspace for BPE merging
        var work_buf: [8192]u16 = undefined;
        const work_len = @min(max_input, work_buf.len);

        for (0..work_len) |i| {
            work_buf[i] = BYTE_OFFSET + @as(u16, text[i]);
        }

        // Step 2: Iteratively apply merges (highest priority first)
        // BPE merge: scan for each merge rule in priority order
        var seq_len: usize = work_len;
        for (0..MERGE_COUNT) |merge_idx| {
            if (seq_len < 2) break;
            const rule = bpe_merges.merge_rules[merge_idx];
            const left = rule[0];
            const right = rule[1];
            const new_token = MERGE_OFFSET + @as(u16, @intCast(merge_idx));

            // Scan and merge in-place
            var read_pos: usize = 0;
            var write_pos: usize = 0;
            while (read_pos < seq_len) {
                if (read_pos + 1 < seq_len and
                    work_buf[read_pos] == left and
                    work_buf[read_pos + 1] == right)
                {
                    work_buf[write_pos] = new_token;
                    write_pos += 1;
                    read_pos += 2;
                } else {
                    work_buf[write_pos] = work_buf[read_pos];
                    write_pos += 1;
                    read_pos += 1;
                }
            }
            seq_len = write_pos;
        }

        // Step 3: Copy merged tokens to output
        const copy_len = @min(seq_len, max_out -| out_idx -| 1); // leave room for EOS
        @memcpy(output[out_idx .. out_idx + copy_len], work_buf[0..copy_len]);
        out_idx += copy_len;

        // EOS
        if (out_idx < max_out) {
            output[out_idx] = EOS_TOKEN;
            out_idx += 1;
        }

        return out_idx;
    }

    /// Decode token IDs back to text
    pub fn decode(self: *const Self, tokens: []const u16, output: []u8) usize {
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

            if (token >= MERGE_OFFSET and token < VOCAB_SIZE) {
                // BPE merge token → variable-length byte sequence
                const idx = token - MERGE_OFFSET;
                const start = self.byte_offsets[idx];
                const len = bpe_merges.merge_byte_lengths[idx];
                const bytes = bpe_merges.merge_byte_data[start .. start + len];
                const copy_len = @min(len, output.len - out_idx);
                @memcpy(output[out_idx .. out_idx + copy_len], bytes[0..copy_len]);
                out_idx += copy_len;
            } else if (token >= BYTE_OFFSET and token < MERGE_OFFSET) {
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

    fn pairKey(a: u16, b: u16) u32 {
        return (@as(u32, a) << 16) | @as(u32, b);
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

test "tokenizer roundtrip various strings" {
    const allocator = std.testing.allocator;
    var tok = try Tokenizer.init(allocator);
    defer tok.deinit();

    const test_strings = [_][]const u8{
        "The quick brown fox",
        "Once upon a time",
        "Hello, World!",
        "a",
        "ab",
        "the the the",
        "1234567890",
    };

    for (test_strings) |text| {
        var tokens: [256]u16 = undefined;
        const n = tok.encode(text, &tokens);
        var decoded: [512]u8 = undefined;
        const m = tok.decode(tokens[0..n], &decoded);
        try std.testing.expectEqualStrings(text, decoded[0..m]);
    }
}

test "BPE compression ratio" {
    const allocator = std.testing.allocator;
    var tok = try Tokenizer.init(allocator);
    defer tok.deinit();

    const text = "Once upon a time there was a little girl named Lily. She loved to play in the garden.";
    var tokens: [256]u16 = undefined;
    const n = tok.encode(text, &tokens);

    // n includes BOS + EOS, so content tokens = n - 2
    const content_tokens = n - 2;
    const ratio = @as(f64, @floatFromInt(content_tokens)) / @as(f64, @floatFromInt(text.len));
    // BPE should compress better than 1:1 (< 0.7 tokens/byte)
    try std.testing.expect(ratio < 0.7);
}

test "token to trits roundtrip" {
    // Test all 729 token IDs
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
    try std.testing.expect(MERGE_OFFSET == 260);
    try std.testing.expect(MERGE_OFFSET + MERGE_COUNT == VOCAB_SIZE);
}
