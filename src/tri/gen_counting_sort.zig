//! tri/counting_sort — Counting Sort O(n+k) integer sorting
//! Auto-generated from specs/tri/tri_counting_sort.tri
//! TTT Dogfood v0.2 Stage 168

const std = @import("std");

/// Sort integers using counting sort
pub fn sort(allocator: std.mem.Allocator, values: []const usize, max_val: usize) ![]usize {
    if (values.len == 0) return &[_]usize{};

    const k = max_val + 1;
    var count = try allocator.alloc(usize, k);
    defer allocator.free(count);
    @memset(count, 0);

    // Count occurrences
    for (values) |v| {
        if (v < k) {
            count[v] += 1;
        }
    }

    // Convert to cumulative count
    var i: usize = 1;
    while (i < k) : (i += 1) {
        count[i] += count[i - 1];
    }

    // Build output (reverse for stability)
    const output = try allocator.alloc(usize, values.len);
    var j: usize = values.len;
    while (j > 0) {
        j -= 1;
        const v = values[j];
        if (v < k) {
            count[v] -= 1;
            output[count[v]] = v;
        } else {
            // Place out-of-range values at end
            output[values.len - 1] = v;
        }
    }

    return output;
}

test "counting sort basic" {
    const input = [_]usize{ 4, 2, 2, 8, 3, 3, 1 };
    const result = try sort(std.testing.allocator, &input, 10);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 7), result.len);
    try std.testing.expectEqual(@as(usize, 1), result[0]);
    try std.testing.expectEqual(@as(usize, 8), result[6]);
}

test "counting sort empty" {
    const input = [_]usize{};
    const result = try sort(std.testing.allocator, &input, 10);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "counting sort single" {
    const input = [_]usize{5};
    const result = try sort(std.testing.allocator, &input, 10);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(@as(usize, 5), result[0]);
}
