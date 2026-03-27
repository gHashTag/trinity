//! tri/merge_sort — Merge Sort stable divide-and-conquer
//! Auto-generated from specs/tri/tri_merge_sort.tri
//! TTT Dogfood v0.2 Stage 169

const std = @import("std");

/// Sort using merge sort (stable)
pub fn sort(allocator: std.mem.Allocator, values: []const i64) ![]i64 {
    if (values.len <= 1) {
        const result = try allocator.alloc(i64, values.len);
        @memcpy(result, values);
        return result;
    }

    const result = try allocator.alloc(i64, values.len);
    @memcpy(result, values);

    sortInPlace(allocator, result);
    return result;
}

/// Sort in place using auxiliary buffer
pub fn sortInPlace(allocator: std.mem.Allocator, values: []i64) void {
    if (values.len <= 1) return;

    const aux = allocator.alloc(i64, values.len) catch unreachable;
    defer allocator.free(aux);

    mergeSort(values, aux, 0, values.len - 1);
}

fn mergeSort(values: []i64, aux: []i64, left: usize, right: usize) void {
    if (left >= right) return;

    const mid = (left + right) / 2;
    mergeSort(values, aux, left, mid);
    mergeSort(values, aux, mid + 1, right);
    merge(values, aux, left, mid, right);
}

fn merge(values: []i64, aux: []i64, left: usize, mid: usize, right: usize) void {
    // Copy to aux
    for (left..right + 1) |i| {
        aux[i] = values[i];
    }

    var i = left;
    var j = mid + 1;
    var k = left;

    while (i <= mid and j <= right) {
        if (aux[i] <= aux[j]) {
            values[k] = aux[i];
            i += 1;
        } else {
            values[k] = aux[j];
            j += 1;
        }
        k += 1;
    }

    // Copy remaining
    while (i <= mid) {
        values[k] = aux[i];
        i += 1;
        k += 1;
    }
}

test "merge sort basic" {
    const input = [_]i64{ 38, 27, 43, 3, 9, 82, 10 };
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 7), result.len);
    try std.testing.expectEqual(@as(i64, 3), result[0]);
    try std.testing.expectEqual(@as(i64, 82), result[6]);
}

test "merge sort empty" {
    const input = [_]i64{};
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "merge sort stable" {
    // Test stability with equal elements
    const input = [_]i64{ 3, 1, 3, 2, 1 };
    const result = try sort(std.testing.allocator, &input);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(i64, 1), result[0]);
    try std.testing.expectEqual(@as(i64, 1), result[1]);
    try std.testing.expectEqual(@as(i64, 3), result[4]);
}
