//! tri/lzw — LZW compression
//! Auto-generated from specs/tri/tri_lzw.tri
//! TTT Dogfood v0.2 Stage 152

const std = @import("std");

const MAX_DICT_SIZE = 4096;

/// Compress data using LZW
pub fn compress(data: []const u8, allocator: std.mem.Allocator) ![]u16 {
    if (data.len == 0) return &[_]u16{};

    var result = std.ArrayList(u16).initCapacity(allocator, data.len) catch unreachable;
    errdefer result.deinit(allocator);

    // Initialize dictionary with single bytes
    var dict = std.AutoHashMap([256]u8, u16).init(allocator);
    defer dict.deinit();

    for (0..256) |i| {
        var key = [_]u8{0} ** 256;
        key[0] = @intCast(i);
        try dict.put(key, @intCast(i));
    }

    var dict_size: u16 = 256;
    var current = std.ArrayList(u8).initCapacity(allocator, 16) catch unreachable;
    defer current.deinit(allocator);

    for (data) |byte| {
        try current.append(allocator, byte);

        var key = [_]u8{0} ** 256;
        @memcpy(key[0..current.items.len], current.items);

        if (dict.get(key)) |_| {
            // Continue building current string
            continue;
        } else {
            // Output code for prefix
            const prefix = current.items[0 .. current.items.len - 1];
            var prefix_key = [_]u8{0} ** 256;
            @memcpy(prefix_key[0..prefix.len], prefix);

            const output_code = dict.get(prefix_key) orelse 0;
            try result.append(allocator, output_code);

            // Add new entry to dictionary
            if (dict_size < MAX_DICT_SIZE) {
                try dict.put(key, dict_size);
                dict_size += 1;
            }

            // Reset current to current byte
            current.clearAndFree(allocator);
            try current.append(allocator, byte);
        }
    }

    // Output remaining
    if (current.items.len > 0) {
        var key = [_]u8{0} ** 256;
        @memcpy(key[0..current.items.len], current.items);
        const output_code = dict.get(key) orelse 0;
        try result.append(allocator, output_code);
    }

    return result.toOwnedSlice(allocator);
}

/// Decompress LZW data
pub fn decompress(compressed: []const u16, allocator: std.mem.Allocator) ![]u8 {
    if (compressed.len == 0) return &[_]u8{};

    var result = std.ArrayList(u8).initCapacity(allocator, compressed.len * 2) catch unreachable;
    errdefer result.deinit(allocator);

    // Initialize reverse dictionary
    var dict = std.AutoHashMap(u16, []u8).init(allocator);
    defer {
        var it = dict.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.value_ptr.*);
        }
        dict.deinit();
    }

    for (0..256) |i| {
        const bytes = try allocator.alloc(u8, 1);
        bytes[0] = @intCast(i);
        try dict.put(@intCast(i), bytes);
    }

    var dict_size: u16 = 256;
    var old_code: ?u16 = null;

    for (compressed) |code| {
        if (code < 256 and old_code == null) {
            try result.append(allocator, @intCast(code));
            old_code = code;
            continue;
        }

        const entry = dict.get(code);

        if (entry) |bytes| {
            try result.appendSlice(allocator, bytes);

            if (old_code) |old| {
                const old_bytes = dict.get(old).?;
                const new_len = old_bytes.len + 1;
                const new_bytes = try allocator.alloc(u8, new_len);
                @memcpy(new_bytes[0..old_bytes.len], old_bytes);
                new_bytes[old_bytes.len] = bytes[0];

                if (dict_size < MAX_DICT_SIZE) {
                    try dict.put(dict_size, new_bytes);
                    dict_size += 1;
                }
            }
        } else if (old_code) |old| {
            const old_bytes = dict.get(old).?;
            const new_len = old_bytes.len + 1;
            const new_bytes = try allocator.alloc(u8, new_len);
            @memcpy(new_bytes[0..old_bytes.len], old_bytes);
            new_bytes[old_bytes.len] = old_bytes[0];

            try result.appendSlice(allocator, new_bytes);
            try dict.put(code, new_bytes);
            dict_size += 1;
        }

        old_code = code;
    }

    return result.toOwnedSlice(allocator);
}

test "lzw round trip" {
    const original = "ABABABA";
    const compressed = try compress(original[0..], std.testing.allocator);
    defer std.testing.allocator.free(compressed);

    const decompressed = try decompress(compressed, std.testing.allocator);
    defer std.testing.allocator.free(decompressed);

    try std.testing.expectEqualStrings(original, decompressed);
}

test "lzw empty" {
    const compressed = try compress("", std.testing.allocator);
    defer std.testing.allocator.free(compressed);

    try std.testing.expectEqual(@as(usize, 0), compressed.len);
}
