//! tri/fenwick — Fenwick Tree (Binary Indexed Tree)
//! Auto-generated from specs/tri/tri_fenwick.tri
//! TTT Dogfood v0.2 Stage 163

const std = @import("std");

/// Fenwick Tree for prefix sums
pub const FenwickTree = struct {
    data: []i64,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create tree of given size (1-indexed internally)
    pub fn init(allocator: std.mem.Allocator, size: usize) !FenwickTree {
        const data = try allocator.alloc(i64, size + 1);
        @memset(data, 0);

        return .{
            .data = data,
            .size = size,
            .allocator = allocator,
        };
    }

    /// Build tree from initial array
    pub fn build(allocator: std.mem.Allocator, values: []const i64) !FenwickTree {
        const n = values.len;
        var tree = try init(allocator, n);

        for (values, 0..) |v, i| {
            tree.update(i, v);
        }

        return tree;
    }

    /// Prefix sum [0..index]
    pub fn query(tree: *const FenwickTree, index: usize) i64 {
        var sum: i64 = 0;
        var i = index + 1; // 1-indexed

        while (i > 0) {
            sum += tree.data[i];
            i -= i & (~i + 1); // i -= (i & (-i))
        }

        return sum;
    }

    /// Sum on range [left, right]
    pub fn rangeQuery(tree: *const FenwickTree, left: usize, right: usize) i64 {
        if (left == 0) return tree.query(right);
        return tree.query(right) - tree.query(left - 1);
    }

    /// Add delta to element at index
    pub fn update(tree: *FenwickTree, index: usize, delta: i64) void {
        var i = index + 1; // 1-indexed
        const n = tree.size;

        while (i <= n) {
            tree.data[i] += delta;
            i += i & (~i + 1); // i += (i & (-i))
        }
    }

    /// Free tree memory
    pub fn deinit(tree: *FenwickTree) void {
        tree.allocator.free(tree.data);
    }
};

test "fenwick init and query" {
    var tree = try FenwickTree.init(std.testing.allocator, 10);
    defer tree.deinit();

    // Initially all zeros
    try std.testing.expectEqual(@as(i64, 0), tree.query(5));
}

test "fenwick build and range query" {
    const values = [_]i64{ 1, 2, 3, 4, 5 };
    var tree = try FenwickTree.build(std.testing.allocator, &values);
    defer tree.deinit();

    try std.testing.expectEqual(@as(i64, 1), tree.query(0));
    try std.testing.expectEqual(@as(i64, 6), tree.query(2));
    try std.testing.expectEqual(@as(i64, 15), tree.query(4));

    try std.testing.expectEqual(@as(i64, 12), tree.rangeQuery(2, 4));
}

test "fenwick update" {
    const values = [_]i64{ 1, 2, 3, 4, 5 };
    var tree = try FenwickTree.build(std.testing.allocator, &values);
    defer tree.deinit();

    try std.testing.expectEqual(@as(i64, 15), tree.query(4));

    tree.update(2, 10); // Add 10 to index 2
    try std.testing.expectEqual(@as(i64, 25), tree.query(4));
    try std.testing.expectEqual(@as(i64, 16), tree.query(2));
}
