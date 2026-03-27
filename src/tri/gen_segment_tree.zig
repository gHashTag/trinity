//! tri/segment_tree — Segment Tree for range queries
//! Auto-generated from specs/tri/tri_segment_tree.tri
//! TTT Dogfood v0.2 Stage 162

const std = @import("std");

/// Segment Tree for range sum queries
pub const SegmentTree = struct {
    data: []i64,
    size: usize,
    allocator: std.mem.Allocator,

    /// Build segment tree from array
    pub fn init(allocator: std.mem.Allocator, values: []const i64) !SegmentTree {
        const n = values.len;
        // Next power of 2
        var size: usize = 1;
        while (size < n) {
            size *= 2;
        }

        const data = try allocator.alloc(i64, 2 * size);
        @memset(data, 0);

        // Copy leaves
        for (values, 0..) |v, i| {
            data[size + i] = v;
        }

        // Build internal nodes
        var i: usize = size - 1;
        while (i > 0) : (i -= 1) {
            data[i] = data[2 * i] + data[2 * i + 1];
        }

        return .{
            .data = data,
            .size = size,
            .allocator = allocator,
        };
    }

    /// Sum query on range [left, right]
    pub fn query(tree: *const SegmentTree, left: usize, right: i64) i64 {
        var result: i64 = 0;
        var l = left + tree.size;
        var r = @as(usize, @intCast(right)) + tree.size;

        while (l <= r) {
            if (l % 2 == 1) {
                result += tree.data[l];
                l += 1;
            }
            if (r % 2 == 0) {
                result += tree.data[r];
                if (r == 0) break;
                r -= 1;
            }
            l /= 2;
            r /= 2;
        }

        return result;
    }

    /// Update element at index
    pub fn update(tree: *SegmentTree, index: usize, value: i64) void {
        var i = index + tree.size;
        tree.data[i] = value;
        i /= 2;

        while (i > 0) {
            tree.data[i] = tree.data[2 * i] + tree.data[2 * i + 1];
            i /= 2;
        }
    }

    /// Free tree memory
    pub fn deinit(tree: *SegmentTree) void {
        tree.allocator.free(tree.data);
    }
};

test "segment tree build and query" {
    const values = [_]i64{ 1, 2, 3, 4, 5 };
    var tree = try SegmentTree.init(std.testing.allocator, &values);
    defer tree.deinit();

    // Sum of all
    const total = tree.query(0, 4);
    try std.testing.expectEqual(@as(i64, 15), total);

    // Sum of first 3
    const first3 = tree.query(0, 2);
    try std.testing.expectEqual(@as(i64, 6), first3);

    // Sum of last 2
    const last2 = tree.query(3, 4);
    try std.testing.expectEqual(@as(i64, 9), last2);
}

test "segment tree update" {
    const values = [_]i64{ 1, 2, 3, 4, 5 };
    var tree = try SegmentTree.init(std.testing.allocator, &values);
    defer tree.deinit();

    try std.testing.expectEqual(@as(i64, 15), tree.query(0, 4));

    tree.update(2, 10);
    try std.testing.expectEqual(@as(i64, 22), tree.query(0, 4));
    try std.testing.expectEqual(@as(i64, 13), tree.query(0, 2));
}
