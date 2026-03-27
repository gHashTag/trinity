//! tri/search — Search algorithms
//! Auto-generated from specs/tri/tri_search.tri
//! TTT Dogfood v0.2 Stage 118

const std = @import("std");

/// Search result
pub const SearchResult = struct {
    index: ?usize,
    found: bool,

    /// Create found result
    pub fn initFound(idx: usize) SearchResult {
        return .{ .index = idx, .found = true };
    }

    /// Create not found result
    pub fn initNotFound() SearchResult {
        return .{ .index = null, .found = false };
    }
};

/// Binary search in sorted array (O(log n))
pub fn binary(comptime T: type, sorted: []const T, target: T) SearchResult {
    var left: usize = 0;
    var right = sorted.len;

    while (left < right) {
        const mid = left + (right - left) / 2;
        if (sorted[mid] == target) {
            return SearchResult.initFound(mid);
        } else if (sorted[mid] < target) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return SearchResult.initNotFound();
}

/// Linear scan (O(n))
pub fn linear(comptime T: type, items: []const T, target: T) SearchResult {
    for (items, 0..) |item, i| {
        if (item == target) {
            return SearchResult.initFound(i);
        }
    }
    return SearchResult.initNotFound();
}

/// Lower bound: first position >= value
pub fn lowerBound(comptime T: type, sorted: []const T, value: T) usize {
    var left: usize = 0;
    var right = sorted.len;

    while (left < right) {
        const mid = left + (right - left) / 2;
        if (sorted[mid] < value) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return left;
}

test "binary search found" {
    const items = [_]i32{ 1, 3, 5, 7, 9, 11, 13 };
    const result = binary(i32, &items, 7);
    try std.testing.expect(result.found);
    try std.testing.expectEqual(@as(?usize, 3), result.index);
}

test "binary search not found" {
    const items = [_]i32{ 1, 3, 5, 7, 9, 11, 13 };
    const result = binary(i32, &items, 8);
    try std.testing.expect(!result.found);
}

test "linear search found" {
    const items = [_]i32{ 5, 2, 8, 1, 9 };
    const result = linear(i32, &items, 8);
    try std.testing.expect(result.found);
    try std.testing.expectEqual(@as(?usize, 2), result.index);
}

test "lower bound" {
    const items = [_]i32{ 1, 3, 5, 7, 9, 11, 13 };
    try std.testing.expectEqual(@as(usize, 0), lowerBound(i32, &items, 0));
    try std.testing.expectEqual(@as(usize, 3), lowerBound(i32, &items, 7));
    try std.testing.expectEqual(@as(usize, 4), lowerBound(i32, &items, 8));
    try std.testing.expectEqual(@as(usize, 7), lowerBound(i32, &items, 99));
}
