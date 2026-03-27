//! tri/selection_sort — Selection Sort O(n^2)
//! Auto-generated from specs/tri/tri_selection_sort.tri
//! TTT Dogfood v0.2 Stage 173

const std = @import("std");

/// Sort in place using selection sort
pub fn sort(values: []i64) void {
    const n = values.len;
    if (n <= 1) return;

    var i: usize = 0;
    while (i < n - 1) : (i += 1) {
        var min_idx = i;

        var j: usize = i + 1;
        while (j < n) : (j += 1) {
            if (values[j] < values[min_idx]) {
                min_idx = j;
            }
        }

        // Swap
        const tmp = values[i];
        values[i] = values[min_idx];
        values[min_idx] = tmp;
    }
}

test "selection sort basic" {
    var input = [_]i64{ 64, 25, 12, 22, 11 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 11), input[0]);
    try std.testing.expectEqual(@as(i64, 64), input[4]);
}

test "selection sort empty" {
    var input = [_]i64{};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "selection sort single" {
    var input = [_]i64{42};
    sort(&input);

    try std.testing.expectEqual(@as(i64, 42), input[0]);
}
