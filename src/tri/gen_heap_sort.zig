//! tri/heap_sort — Heap Sort in-place O(n log n)
//! Auto-generated from specs/tri/tri_heap_sort.tri
//! TTT Dogfood v0.2 Stage 171

const std = @import("std");

/// Sort in place using heap sort
pub fn sort(values: []i64) void {
    const n = values.len;
    if (n <= 1) return;

    // Build max heap
    var i: usize = n / 2;
    while (i > 0) {
        i -= 1;
        siftDown(values, i, n);
    }

    // Extract elements from heap
    var end = n;
    while (end > 1) {
        end -= 1;
        // Swap root (max) with last element
        const tmp = values[0];
        values[0] = values[end];
        values[end] = tmp;
        siftDown(values, 0, end);
    }
}

fn siftDown(values: []i64, start: usize, end: usize) void {
    var root = start;

    while (2 * root + 1 < end) {
        const child = 2 * root + 1; // Left child
        var swap_idx = root;

        if (values[swap_idx] < values[child]) {
            swap_idx = child;
        }

        if (child + 1 < end and values[swap_idx] < values[child + 1]) {
            swap_idx = child + 1;
        }

        if (swap_idx == root) return;

        // Swap
        const tmp = values[root];
        values[root] = values[swap_idx];
        values[swap_idx] = tmp;

        root = swap_idx;
    }
}

test "heap sort basic" {
    var input = [_]i64{ 12, 11, 13, 5, 6, 7 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 5), input[0]);
    try std.testing.expectEqual(@as(i64, 13), input[5]);
}

test "heap sort empty" {
    var input = [_]i64{};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "heap sort single" {
    var input = [_]i64{42};
    sort(&input);

    try std.testing.expectEqual(@as(i64, 42), input[0]);
}

test "heap sort two elements" {
    var input = [_]i64{ 5, 2 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 2), input[0]);
    try std.testing.expectEqual(@as(i64, 5), input[1]);
}
