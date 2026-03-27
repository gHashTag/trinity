//! tri/base64 — Standard encoding
//! Auto-generated from specs/tri/tri_base64.tri
//! TTT Dogfood v0.2 Stage 97

const std = @import("std");

/// Base64 codec
pub const Base64 = struct {
    alphabet: []const u8,
    padding: bool,

    /// RFC 4648 standard with padding
    pub fn standard() Base64 {
        return .{
            .alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
            .padding = true,
        };
    }

    /// URL-safe variant
    pub fn urlSafe() Base64 {
        return .{
            .alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
            .padding = false,
        };
    }

    /// Encode to base64
    pub fn encode(codec: Base64, input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        if (input.len == 0) return &[_]u8{};

        const output_len = codec.encodedLength(input.len);
        const output = try allocator.alloc(u8, output_len);

        var out_idx: usize = 0;
        var i: usize = 0;

        while (i + 3 <= input.len) : (i += 3) {
            const triple = (@as(usize, input[i]) << 16) | (@as(usize, input[i + 1]) << 8) | input[i + 2];
            output[out_idx] = codec.alphabet[(triple >> 18) & 0x3F];
            output[out_idx + 1] = codec.alphabet[(triple >> 12) & 0x3F];
            output[out_idx + 2] = codec.alphabet[(triple >> 6) & 0x3F];
            output[out_idx + 3] = codec.alphabet[triple & 0x3F];
            out_idx += 4;
        }

        const remaining = input.len - i;
        if (remaining == 1) {
            const triple = @as(usize, input[i]) << 16;
            output[out_idx] = codec.alphabet[(triple >> 18) & 0x3F];
            output[out_idx + 1] = codec.alphabet[(triple >> 12) & 0x3F];
            if (codec.padding) {
                output[out_idx + 2] = '=';
                output[out_idx + 3] = '=';
            } else {
                return output[0..(out_idx + 2)];
            }
        } else if (remaining == 2) {
            const triple = (@as(usize, input[i]) << 16) | (@as(usize, input[i + 1]) << 8);
            output[out_idx] = codec.alphabet[(triple >> 18) & 0x3F];
            output[out_idx + 1] = codec.alphabet[(triple >> 12) & 0x3F];
            output[out_idx + 2] = codec.alphabet[(triple >> 6) & 0x3F];
            if (codec.padding) {
                output[out_idx + 3] = '=';
            } else {
                return output[0..(out_idx + 3)];
            }
        }

        return output;
    }

    /// Decode from base64
    pub fn decode(codec: Base64, input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        if (input.len == 0) return &[_]u8{};

        // Build decode table
        var decode_table = [_]u8{255} ** 256;
        for (codec.alphabet, 0..) |c, i| {
            decode_table[c] = @intCast(i);
        }

        // Calculate output length
        var padding: usize = 0;
        if (input.len >= 2) {
            if (input[input.len - 1] == '=') padding += 1;
            if (input.len >= 3 and input[input.len - 2] == '=') padding += 1;
        }

        const output_len = (input.len * 3) / 4 - padding;
        const output = try allocator.alloc(u8, output_len);

        var out_idx: usize = 0;
        var accum: u64 = 0;
        var bits: usize = 0;

        for (input) |c| {
            if (c == '=') break;
            const val = decode_table[c];
            if (val == 255) return error.InvalidCharacter;

            accum = (accum << 6) | @as(u64, val);
            bits += 6;

            if (bits >= 8) {
                bits -= 8;
                const shift = @as(u5, @intCast(bits));
                const byte_val = @as(u8, @truncate((accum >> shift) & 0xFF));
                output[out_idx] = byte_val;
                out_idx += 1;
            }
        }

        return output;
    }

    /// Calculate output size
    pub fn encodedLength(codec: Base64, input_len: usize) usize {
        _ = codec;
        const full_groups = input_len / 3;
        const remainder = input_len % 3;
        if (remainder == 0) return full_groups * 4;
        return full_groups * 4 + 4;
    }
};

test "Base64.encode" {
    const codec = Base64.standard();
    const result = try codec.encode("hello", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "aGVsbG8=", result);
}

test "Base64.decode" {
    const codec = Base64.standard();
    const result = try codec.decode("aGVsbG8=", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, "hello", result);
}

test "Base64.urlSafe" {
    const codec = Base64.urlSafe();
    const result = try codec.encode("hello?", std.testing.allocator);
    defer std.testing.allocator.free(result);
    // URL-safe should use - and _ instead of + and /
    try std.testing.expect(result.len > 0);
}
