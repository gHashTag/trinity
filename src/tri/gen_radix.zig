//! tri/radix — Radix sort
//! Auto-generated from specs/tri/tri_radix.tri
//! TTT Dogfood v0.2 Stage 134

const std = @import("std");

/// Radix sort configuration
pub const RadixSort = struct {
    base: usize = 256,
};

/// Sort bytes using radix sort
pub fn sort_u8(items: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (items.len == 0) return allocator.dupe(u8, items);

    var count = [_]usize{0} ** 256;

    // Count occurrences
    for (items) |item| {
        count[item] += 1;
    }

    // Compute positions
    var total: usize = 0;
    for (0..256) |i| {
        const count_val = count[i];
        count[i] = total;
        total += count_val;
    }

    // Place elements
    var output = try allocator.alloc(u8, items.len);
    for (items) |item| {
        output[count[item]] = item;
        count[item] += 1;
    }

    return output;
}

/// Sort 32-bit integers using radix sort
pub fn sort_u32(items: []const u32, allocator: std.mem.Allocator) ![]u32 {
    if (items.len == 0) return allocator.dupe(u32, items);

    var result = try allocator.dupe(u32, items);

    // Sort by each byte (4 passes for 32-bit)
    var offset: u32 = 0;
    var byte_idx: usize = 0;
    while (byte_idx < 4) : (byte_idx += 1) {
        const shift: u5 = @intCast(byte_idx * 8);
        var count = [_]u32{0} ** 256;

        // Count occurrences
        for (result) |item| {
            const byte = (item >> shift) & 0xFF;
            count[byte] += 1;
        }

        // Compute positions
        var total: u32 = 0;
        for (0..256) |i| {
            const count_val = count[i];
            count[i] = total;
            total += count_val;
        }

        // Place elements
        var output = try allocator.alloc(u32, result.len);
        for (result) |item| {
            const byte = (item >> shift) & 0xFF;
            output[count[byte]] = item;
            count[byte] += 1;
        }

        allocator.free(result);
        result = output;
        offset += 1;
    }

    return result;
}

test "sort u8" {
    const items = [_]u8{ 5, 2, 8, 1, 9, 3 };
    const result = try sort_u8(&items, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 6), result.len);
    try std.testing.expectEqual(@as(u8, 1), result[0]);
    try std.testing.expectEqual(@as(u8, 9), result[5]);
}

test "sort u32" {
    const items = [_]u32{ 500, 100, 300, 200, 400 };
    const result = try sort_u32(&items, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqual(@as(u32, 100), result[0]);
    try std.testing.expectEqual(@as(u32, 500), result[4]);
}
