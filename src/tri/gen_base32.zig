//! tri/base32 — RFC 4648 Base32 encoding
//! Auto-generated from specs/tri/tri_base32.tri
//! TTT Dogfood v0.2 Stage 113

const std = @import("std");

/// RFC 4648 Base32 alphabet
const standard_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

/// Base32 codec configuration
pub const Base32 = struct {
    alphabet: []const u8 = standard_alphabet,
    padding: bool = true,

    /// Create standard RFC 4648 Base32 codec
    pub fn standard() Base32 {
        return .{ .alphabet = standard_alphabet, .padding = true };
    }
};

/// Encode to Base32
pub fn encode(codec: Base32, input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    // Base32 encodes 5 bytes to 8 characters
    const output_len = (input.len + 4) / 5 * 8;
    var result = try std.ArrayList(u8).initCapacity(allocator, output_len);

    var i: usize = 0;
    while (i < input.len) : (i += 5) {
        // Get up to 5 bytes
        const bytes = [5]u8{
            input[i],
            if (i + 1 < input.len) input[i + 1] else 0,
            if (i + 2 < input.len) input[i + 2] else 0,
            if (i + 3 < input.len) input[i + 3] else 0,
            if (i + 4 < input.len) input[i + 4] else 0,
        };

        // Encode to 8 characters (using u8 to avoid truncation)
        const quintet = [8]u8{
            bytes[0] >> 3,
            ((bytes[0] & 0x07) << 2) | (bytes[1] >> 6),
            (bytes[1] >> 1) & 0x1F,
            ((bytes[1] & 0x01) << 4) | (bytes[2] >> 4),
            ((bytes[2] & 0x0F) << 1) | (bytes[3] >> 7),
            (bytes[3] >> 2) & 0x1F,
            ((bytes[3] & 0x03) << 3) | (bytes[4] >> 5),
            bytes[4] & 0x1F,
        };

        // Determine how many chars are valid
        const remaining = input.len - i;
        const valid_chars: usize = if (remaining == 1) 2 else if (remaining == 2) 4 else if (remaining == 3) 5 else if (remaining == 4) 7 else 8;

        for (quintet[0..valid_chars]) |idx| {
            try result.append(allocator, codec.alphabet[idx]);
        }

        // Add padding if needed
        if (codec.padding) {
            const padding_needed = 8 - valid_chars;
            for (0..padding_needed) |_| {
                try result.append(allocator, '=');
            }
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Decode from Base32
pub fn decode(codec: Base32, input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    // Remove padding and validate
    var cleaned_len = input.len;
    var padding_count: usize = 0;
    for (input) |c| {
        if (c == '=') padding_count += 1;
    }
    cleaned_len -= padding_count;

    const output_len = cleaned_len * 5 / 8;
    var result = try std.ArrayList(u8).initCapacity(allocator, output_len);

    // Build decode lookup
    var lookup: [256]u8 = undefined;
    @memset(&lookup, 0xFF);
    for (codec.alphabet, 0..) |c, i| {
        lookup[c] = @intCast(i);
    }

    var i: usize = 0;
    while (i < input.len and input[i] != '=') : (i += 8) {
        // Get up to 8 characters
        const chars_len = @min(8, input.len - i);
        var indices: [8]u8 = undefined;
        var valid_count: usize = 0;

        for (0..chars_len) |j| {
            const c = input[i + j];
            if (c == '=') break;
            const val = lookup[c];
            if (val == 0xFF) return error.InvalidCharacter;
            indices[j] = val;
            valid_count += 1;
        }

        // Decode to bytes
        const bytes = [5]u8{
            (indices[0] << 3) | (indices[1] >> 2),
            ((indices[1] & 0x03) << 6) | (indices[2] << 1) | (indices[3] >> 4),
            ((indices[3] & 0x0F) << 4) | (indices[4] >> 1),
            ((indices[4] & 0x01) << 7) | (indices[5] << 2) | (indices[6] >> 3),
            ((indices[6] & 0x07) << 5) | indices[7],
        };

        // Determine output bytes based on valid chars
        const output_bytes: usize = if (valid_count == 2) 1 else if (valid_count == 4) 2 else if (valid_count == 5) 3 else if (valid_count == 7) 4 else if (valid_count == 8) 5 else return error.InvalidLength;

        for (bytes[0..output_bytes]) |b| {
            try result.append(allocator, b);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "encode simple" {
    const codec = Base32.standard();
    const input = "foobar";
    const result = try encode(codec, input, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("MZXW6YTBOI======", result);
}

test "decode simple" {
    const codec = Base32.standard();
    const input = "MZXW6YTBOI======";
    const result = try decode(codec, input, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("foobar", result);
}

test "roundtrip" {
    const codec = Base32.standard();
    const original = "Hello, World!";
    const encoded = try encode(codec, original, std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    const decoded = try decode(codec, encoded, std.testing.allocator);
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}
