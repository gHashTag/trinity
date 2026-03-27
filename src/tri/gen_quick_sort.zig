//! tri/quick_sort — Quick Sort in-place partition sort
//! Auto-generated from specs/tri/tri_quick_sort.tri
//! TTT Dogfood v0.2 Stage 170

const std = @import("std");

/// Sort in place using Lomuto partition
pub fn sort(values: []i64) void {
    if (values.len <= 1) return;
    sortRange(values, 0, values.len - 1);
}

/// Sort subarray [low, high]
pub fn sortRange(values: []i64, low: usize, high: usize) void {
    if (low >= high or low >= values.len) return;

    const pivot_index = partition(values, low, high);

    // Recursively sort left and right
    if (pivot_index > 0) {
        sortRange(values, low, pivot_index - 1);
    }
    if (pivot_index < high) {
        sortRange(values, pivot_index + 1, high);
    }
}

fn partition(values: []i64, low: usize, high: usize) usize {
    const pivot = values[high];
    var i = low;

    for (low..high) |j| {
        if (values[j] < pivot) {
            // Swap values[i] and values[j]
            const tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
            i += 1;
        }
    }

    // Swap values[i] and values[high] (pivot)
    const tmp = values[i];
    values[i] = values[high];
    values[high] = tmp;

    return i;
}

test "quick sort basic" {
    var input = [_]i64{ 10, 80, 30, 90, 40, 50, 70 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 10), input[0]);
    try std.testing.expectEqual(@as(i64, 90), input[6]);
}

test "quick sort empty" {
    var input = [_]i64{};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "quick sort single" {
    var input = [_]i64{42};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 1), input.len);
    try std.testing.expectEqual(@as(i64, 42), input[0]);
}

test "quick sort two elements" {
    var input = [_]i64{ 5, 2 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 2), input[0]);
    try std.testing.expectEqual(@as(i64, 5), input[1]);
}

test "quick sort already sorted" {
    var input = [_]i64{ 1, 2, 3, 4, 5 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 1), input[0]);
    try std.testing.expectEqual(@as(i64, 5), input[4]);
}

test "quick sort reverse sorted" {
    var input = [_]i64{ 5, 4, 3, 2, 1 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 1), input[0]);
    try std.testing.expectEqual(@as(i64, 5), input[4]);
}
