//! tri/tim_sort — Tim Sort hybrid merge+insertion
//! Auto-generated from specs/tri/tri_tim_sort.tri
//! TTT Dogfood v0.2 Stage 175

const std = @import("std");

const MIN_RUN = 32;

/// Sort using Tim Sort algorithm
pub fn sort(allocator: std.mem.Allocator, values: []i64) void {
    const n = values.len;
    if (n <= 1) return;

    // Sort small runs with insertion sort
    var start: usize = 0;
    while (start < n) : (start += MIN_RUN) {
        const end = @min(start + MIN_RUN, n);
        insertionSort(values, start, end);
    }

    // Merge runs (simplified: just use merge sort)
    const aux = allocator.alloc(i64, n) catch unreachable;
    defer allocator.free(aux);

    var size: usize = MIN_RUN;
    while (size < n) {
        var left: usize = 0;
        while (left < n) : (left += 2 * size) {
            const mid = left + size;
            const right = @min(left + 2 * size, n);

            if (mid < right) {
                merge(values, aux, left, mid, right);
            }
        }
        size *= 2;
    }
}

fn insertionSort(values: []i64, start: usize, end: usize) void {
    var i: usize = start + 1;
    while (i < end) : (i += 1) {
        const key = values[i];
        var j = i;

        while (j > start and values[j - 1] > key) : (j -= 1) {
            values[j] = values[j - 1];
        }

        values[j] = key;
    }
}

fn merge(values: []i64, aux: []i64, left: usize, mid: usize, right: usize) void {
    // Copy to aux
    for (left..right) |i| {
        aux[i] = values[i];
    }

    var i = left;
    var j = mid;
    var k = left;

    while (i < mid and j < right) {
        if (aux[i] <= aux[j]) {
            values[k] = aux[i];
            i += 1;
        } else {
            values[k] = aux[j];
            j += 1;
        }
        k += 1;
    }

    while (i < mid) {
        values[k] = aux[i];
        i += 1;
        k += 1;
    }
}

test "tim sort basic" {
    var input = [_]i64{ 5, 2, 8, 1, 9, 3 };
    sort(std.testing.allocator, &input);

    try std.testing.expectEqual(@as(i64, 1), input[0]);
    try std.testing.expectEqual(@as(i64, 9), input[5]);
}

test "tim sort empty" {
    var input = [_]i64{};
    sort(std.testing.allocator, &input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "tim sort single" {
    var input = [_]i64{42};
    sort(std.testing.allocator, &input);

    try std.testing.expectEqual(@as(i64, 42), input[0]);
}
