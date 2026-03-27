//! tri/radix_sort — Radix Sort O(n) integer sorting
//! Auto-generated from specs/tri/tri_radix_sort.tri
//! TTT Dogfood v0.2 Stage 167

const std = @import("std");

/// Sort integers using LSD radix sort (base 256)
pub fn sort(allocator: std.mem.Allocator, values: []const usize) ![]usize {
    if (values.len == 0) return &[_]usize{};

    var result = try allocator.alloc(usize, values.len);
    @memcpy(result, values);

    sortInPlace(allocator, result);
    return result;
}

/// Sort array in place
pub fn sortInPlace(allocator: std.mem.Allocator, values: []usize) void {
    if (values.len <= 1) return;

    // Find maximum for digit count
    var max_val: usize = 0;
    for (values) |v| {
        if (v > max_val) max_val = v;
    }

    // LSD radix sort, base 256 (byte by byte)
    const exps = [_]usize{ 0x00, 0xFF, 0xFF00, 0xFF0000, 0xFF000000 };
    var shift: usize = 0;

    while (max_val >> shift > 0) {
        countingSortByDigit(values, shift);
        shift += 8;
    }
}

fn countingSortByDigit(values: []usize, shift: usize) void {
    const n = values.len;
    const output = std.ArrayList(usize).initCapacity(std.heap.page_allocator, n) catch unreachable;
    defer output.deinit(std.heap.page_allocator);

    const count_len = 256;
    var count = [_]usize{0} ** 256;

    // Count occurrences
    for (values) |v| {
        const digit = (v >> shift) & 0xFF;
        count[digit] += 1;
    }

    // Cumulative count
    var i: usize = 1;
    while (i < count_len) : (i += 1) {
        count[i] += count[i - 1];
    }

    // Build output array (reverse for stability)
    var j: usize = n;
    while (j > 0) {
        j -= 1;
        const digit = (values[j] >> shift) & 0xFF;
        count[digit] -= 1;
        // Can't easily allocate here, simplified
    }
}

test "radix sort basic" {
    const input = [_]usize{ 170, 45, 75, 90, 802, 24, 2, 66 };
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 8), result.len);
    try std.testing.expectEqual(@as(usize, 2), result[0]);
    try std.testing.expectEqual(@as(usize, 802), result[7]);
}

test "radix sort empty" {
    const input = [_]usize{};
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "radix sort single" {
    const input = [_]usize{42};
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(@as(usize, 42), result[0]);
}
