//! tri/shell_sort — Shell Sort with gap sequence
//! Auto-generated from specs/tri/tri_shell_sort.tri
//! TTT Dogfood v0.2 Stage 174

const std = @import("std");

/// Sort using Shell's original gap sequence
pub fn sort(values: []i64) void {
    const n = values.len;
    if (n <= 1) return;

    // Start with gap = n/2, halve each time
    var gap: usize = n / 2;

    while (gap > 0) {
        // Do gapped insertion sort
        var i: usize = gap;
        while (i < n) : (i += 1) {
            const temp = values[i];
            var j: usize = i;

            while (j >= gap and values[j - gap] > temp) {
                values[j] = values[j - gap];
                if (j >= gap) j -= gap else break;
            }

            values[j] = temp;
        }

        if (gap == 1) break;
        gap = gap / 2;
    }
}

test "shell sort basic" {
    var input = [_]i64{ 12, 34, 54, 2, 3 };
    sort(&input);

    try std.testing.expectEqual(@as(i64, 2), input[0]);
    try std.testing.expectEqual(@as(i64, 54), input[4]);
}

test "shell sort empty" {
    var input = [_]i64{};
    sort(&input);

    try std.testing.expectEqual(@as(usize, 0), input.len);
}

test "shell sort single" {
    var input = [_]i64{42};
    sort(&input);

    try std.testing.expectEqual(@as(i64, 42), input[0]);
}
