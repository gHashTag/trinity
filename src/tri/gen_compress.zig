//! tri/compress — Data compression
//! Auto-generated from specs/tri/tri_compress.tri
//! TTT Dogfood v0.2 Stage 112

const std = @import("std");

/// Compressed data with original size tracking
pub const Compressed = struct {
    data: []u8,
    original_len: usize,

    /// Free resources
    pub fn deinit(self: Compressed, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// Simple run-length encoding compression
/// Note: For production use, integrate std.stdlib.zlib or similar
pub fn compress(input: []const u8, allocator: std.mem.Allocator) !Compressed {
    if (input.len == 0) {
        return .{
            .data = try allocator.dupe(u8, ""),
            .original_len = 0,
        };
    }

    var result = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const byte = input[i];
        var count: usize = 1;

        // Count consecutive identical bytes
        while (i + count < input.len and input[i + count] == byte and count < 255) {
            count += 1;
        }

        // Write count and byte
        try result.append(allocator, @intCast(count));
        try result.append(allocator, byte);

        i += count;
    }

    return .{
        .data = try result.toOwnedSlice(allocator),
        .original_len = input.len,
    };
}

/// Decompress RLE-compressed data
pub fn decompress(compressed: Compressed, allocator: std.mem.Allocator) ![]u8 {
    if (compressed.data.len == 0) {
        return allocator.dupe(u8, "");
    }

    var result = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < compressed.data.len) {
        if (i + 1 >= compressed.data.len) return error.InvalidFormat;

        const count = compressed.data[i];
        const byte = compressed.data[i + 1];

        for (0..count) |_| {
            try result.append(allocator, byte);
        }

        i += 2;
    }

    const output = try result.toOwnedSlice(allocator);
    if (output.len != compressed.original_len) return error.SizeMismatch;

    return output;
}

test "compress simple" {
    const input = "aaaabbbccddddd";
    const result = try compress(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 14), result.original_len);
    // 4a, 3b, 2c, 5d = 8 bytes
    try std.testing.expectEqual(@as(usize, 8), result.data.len);
}

test "decompress" {
    const input = "aaaabbbccddddd";
    const compressed = try compress(input, std.testing.allocator);
    defer compressed.deinit(std.testing.allocator);

    const result = try decompress(compressed, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(input, result);
}

test "roundtrip empty" {
    const input = "";
    const compressed = try compress(input, std.testing.allocator);
    defer compressed.deinit(std.testing.allocator);

    const result = try decompress(compressed, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(input, result);
}

test "roundtrip single char" {
    const input = "a";
    const compressed = try compress(input, std.testing.allocator);
    defer compressed.deinit(std.testing.allocator);

    const result = try decompress(compressed, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(input, result);
}

test "roundtrip no repeats" {
    const input = "abcdefghij";
    const compressed = try compress(input, std.testing.allocator);
    defer compressed.deinit(std.testing.allocator);

    const result = try decompress(compressed, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(input, result);
}
