//! tri/sort — Sorting algorithms
//! Auto-generated from specs/tri/tri_sort.tri
//! TTT Dogfood v0.2 Stage 117

const std = @import("std");

/// Sort direction
pub const SortOrder = enum {
    Ascending,
    Descending,
};

/// Sort slice (generic for orderable types)
pub fn sort(comptime T: type, items: []const T, order: SortOrder, allocator: std.mem.Allocator) ![]T {
    var result = try allocator.dupe(T, items);
    errdefer allocator.free(result);

    std.mem.sort(T, result, {}, struct {
        fn compare(_: void, a: T, b: T) bool {
            return switch (order) {
                .Ascending => if (@typeInfo(T) == .float) a < b else a < b,
                .Descending => if (@typeInfo(T) == .float) a > b else a > b,
            };
        }
    }.compare);

    return result;
}

/// Sort by key function (returns std.math.Order)
pub fn sortBy(comptime T: type, items: []const T, key_fn: fn(T) std.math.Order, allocator: std.mem.Allocator) ![]T {
    var result = try allocator.dupe(T, items);
    errdefer allocator.free(result);

    std.mem.sort(T, result, key_fn, struct {
        fn compare(key_fn_ptr: fn(T) std.math.Order, a: T, b: T) bool {
            return key_fn_ptr(a).compare(key_fn_ptr(b)) == .lt;
        }
    }.compare);

    return result;
}

test "sort ascending" {
    const items = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    const result = try sort(i32, &items, .Ascending, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 8), result.len);
    try std.testing.expectEqual(@as(i32, 1), result[0]);
    try std.testing.expectEqual(@as(i32, 9), result[7]);
}

test "sort descending" {
    const items = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    const result = try sort(i32, &items, .Descending, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqual(@as(usize, 8), result.len);
    try std.testing.expectEqual(@as(i32, 9), result[0]);
    try std.testing.expectEqual(@as(i32, 1), result[7]);
}
