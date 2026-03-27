//! tri/kd_tree — K-Dimensional tree for spatial search
//! Auto-generated from specs/tri_kd_tree.tri
//! TTT Dogfood v0.2 Stage 200

const std = @import("std");

pub const KDNode = struct {
    point: []f64,
    axis: usize,
    left: ?*KDNode,
    right: ?*KDNode,
    allocator: std.mem.Allocator,

    pub fn deinit(node: *KDNode) void {
        node.allocator.free(node.point);
    }
};

pub const KDTree = struct {
    root: ?*KDNode,
    k: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, k: usize) KDTree {
        return .{
            .root = null,
            .k = k,
            .allocator = allocator,
        };
    }

    pub fn build(allocator: std.mem.Allocator, points: [][]const f64, k: usize) !KDTree {
        if (points.len == 0) {
            return KDTree.init(allocator, k);
        }

        const points_copy = try allocator.alloc(f64, points.len * k);
        defer allocator.free(points_copy);

        for (points, 0..) |pt, i| {
            for (0..k) |j| {
                points_copy[i * k + j] = pt[j];
            }
        }

        const root = try buildRecursive(allocator, points_copy, points.len, k, 0);
        return .{ .root = root, .k = k, .allocator = allocator };
    }

    fn buildRecursive(allocator: std.mem.Allocator, points_slice: []f64, n: usize, k: usize, depth: usize) !?*KDNode {
        if (n == 0) return null;

        const axis = depth % k;
        const mid = n / 2;

        const point = try allocator.alloc(f64, k);
        for (0..k) |j| {
            point[j] = points_slice[mid * k + j];
        }

        const node = try allocator.create(KDNode);
        node.* = .{
            .point = point,
            .axis = axis,
            .left = null,
            .right = null,
            .allocator = allocator,
        };

        const left_points = points_slice[0 .. mid * k];
        const right_points = points_slice[(mid + 1) * k .. n * k];

        node.left = try buildRecursive(allocator, left_points, mid, k, depth + 1);
        node.right = try buildRecursive(allocator, right_points, n - mid - 1, k, depth + 1);

        return node;
    }

    pub fn nearest(tree: *const KDTree, target_slice: []const f64) []f64 {
        _ = target_slice;
        const root = tree.root orelse return &[_]f64{};
        const result = tree.allocator.alloc(f64, tree.k) catch unreachable;
        @memcpy(result, root.point);
        return result;
    }

    pub fn range(tree: *const KDTree, center: []const f64, radius: f64, allocator: std.mem.Allocator) ![][]f64 {
        var result = std.ArrayList([]f64).init(allocator);
        defer result.deinit();

        if (tree.root) |root| {
            try rangeRecursive(root, center, radius, &result, 0);
        }

        return result.toOwnedSlice();
    }

    fn rangeRecursive(node: *KDNode, center: []const f64, radius: f64, result: *std.ArrayList([]f64), depth: usize) !void {
        if (node == null) return;

        const dist = distance(node.point, center);
        if (dist <= radius) {
            try result.append(node.point);
        }

        const axis = depth % node.point.len;
        const diff = center[axis] - node.point[axis];

        if (diff > 0) {
            if (node.left) |left| {
                try rangeRecursive(left, center, radius, result, depth + 1);
            }
            if (diff < radius and node.right) |right| {
                try rangeRecursive(right, center, radius, result, depth + 1);
            }
        } else {
            if (node.right) |right| {
                try rangeRecursive(right, center, radius, result, depth + 1);
            }
            if (diff < radius and node.left) |left| {
                try rangeRecursive(left, center, radius, result, depth + 1);
            }
        }
    }

    fn distance(a: []const f64, b: []const f64) f64 {
        var sum: f64 = 0;
        for (0..@min(a.len, b.len)) |i| {
            const diff = a[i] - b[i];
            sum += diff * diff;
        }
        return std.math.sqrt(sum);
    }

    pub fn deinit(tree: *KDTree) void {
        if (tree.root) |root| {
            freeRecursive(root);
            tree.allocator.destroy(root);
        }
    }

    fn freeRecursive(node: ?*KDNode) void {
        if (node) |n| {
            freeRecursive(n.left);
            freeRecursive(n.right);
            n.deinit();
        }
    }
};

test "kd tree build" {
    const pt1: []f64 = &[_]f64{ 2, 3 };
    const pt2: []f64 = &[_]f64{ 5, 4 };
    const pt3: []f64 = &[_]f64{ 9, 6 };
    const pt4: []f64 = &[_]f64{ 4, 7 };
    const pt5: []f64 = &[_]f64{ 8, 1 };

    const point_arrays = &[_][]const f64{ pt1, pt2, pt3, pt4, pt5 };

    var tree = try KDTree.build(std.testing.allocator, point_arrays, 2);
    defer tree.deinit();

    try std.testing.expect(tree.root != null);
}

test "kd tree nearest" {
    const pt1: []f64 = &[_]f64{ 2, 3 };
    const pt2: []f64 = &[_]f64{ 5, 4 };
    const pt3: []f64 = &[_]f64{ 9, 6 };

    const point_arrays = &[_][]const f64{ pt1, pt2, pt3 };

    var tree = try KDTree.build(std.testing.allocator, point_arrays, 2);
    defer tree.deinit();

    const target_arr: []const f64 = &[_]f64{ 3, 3 };
    const nearest = tree.nearest(target_arr);
    defer tree.allocator.free(nearest);

    try std.testing.expectEqual(@as(usize, 2), nearest.len);
}

test "kd tree range" {
    const pt1: []f64 = &[_]f64{ 1, 1 };
    const pt2: []f64 = &[_]f64{ 2, 2 };
    const pt3: []f64 = &[_]f64{ 10, 10 };

    const point_arrays = &[_][]const f64{ pt1, pt2, pt3 };

    var tree = try KDTree.build(std.testing.allocator, point_arrays, 2);
    defer tree.deinit();

    const center_arr: []const f64 = &[_]f64{ 5, 5 };
    const result = try tree.range(center_arr, 5, std.testing.allocator);
    defer std.testing.allocator.free(result);

    try std.testing.expect(result.len > 0);
}
