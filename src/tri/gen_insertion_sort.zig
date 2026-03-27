//! tri/insertion_sort — Insertion Sort O(n^2)
//! Auto-generated from specs/tri/tri_insertion_sort.tri
//! TTT Dogfood v0.2 Stage 172

const std = @import("std");

/// Sort in place using insertion sort
pub fn sort(values: []i64) void {
    var i: usize = 1;
    while (i < values.len) : (i += 1) {
        const key = values[i];
        var j = i;

        while (j > 0 and values[j - 1] > key) : (j -= 1) {
            values[j] = values[j - 1];
        }

        values[j] = key;
    }
}

test "insertion sort basic" {
    var input = [_]i64{ 12, 11, 13, 5, 6, 7 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 5), input[0]);
    try std.testing.expectEqual(@as(i64, 13), input[5]);
}

test "insertion sort empty" {
    var input = [_]i64{};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "insertion sort single" {
    var input = [_]i64{42};
    sort(&input);

    try std.testing.expectEqual(@as(i64, 42), input[0]);
}

test "insertion sort already sorted" {
    var input = [_]i64{ 1, 2, 3, 4, 5 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 1), input[0]);
    try std.testing.expectEqual(@as(i64, 5), input[4]);
}
