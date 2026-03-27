//! tri/base64 — Base64 encoding/decoding
//! TTT Dogfood v0.2 Stage 236

const std = @import("std");

const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

pub fn encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const out_len = (data.len + 2) / 3 * 4;
    var result = try allocator.alloc(u8, out_len);

    var i: usize = 0;
    var out_idx: usize = 0;
    while (i + 3 <= data.len) : (i += 3) {
        const triple = (@as(usize, data[i]) << 16) | (@as(usize, data[i + 1]) << 8) | data[i + 2];
        result[out_idx] = alphabet[(triple >> 18) & 63];
        result[out_idx + 1] = alphabet[(triple >> 12) & 63];
        result[out_idx + 2] = alphabet[(triple >> 6) & 63];
        result[out_idx + 3] = alphabet[triple & 63];
        out_idx += 4;
    }

    if (i < data.len) {
        const remaining = data.len - i;
        var triple: usize = @as(usize, data[i]) << 16;
        if (remaining == 2) {
            triple |= @as(usize, data[i + 1]) << 8;
        }
        result[out_idx] = alphabet[(triple >> 18) & 63];
        result[out_idx + 1] = alphabet[(triple >> 12) & 63];
        result[out_idx + 2] = if (remaining == 2) alphabet[(triple >> 6) & 63] else '=';
        result[out_idx + 3] = '=';
    }

    return result;
}

test "base64 encode" {
    const encoded = try encode(std.testing.allocator, "ABC");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, "QUJD", encoded);
}
