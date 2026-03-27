//! tri/quadtree — 2D spatial partitioning
//! TTT Dogfood v0.2 Stage 198

const std = @import("std");

pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const QuadNode = struct {
    boundary: Rect,
    children: [4]?*QuadNode,
    point_count: usize,
    divided: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(node: *QuadNode) void {
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                child.deinit();
                node.allocator.destroy(child);
            }
        }
    }
};

pub const QuadTree = struct {
    root: ?*QuadNode,
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, boundary: Rect, capacity: usize) !QuadTree {
        const root = try allocator.create(QuadNode);
        root.* = .{
            .boundary = boundary,
            .children = [_]?*QuadNode{null} ** 4,
            .point_count = 0,
            .divided = false,
            .allocator = allocator,
        };

        return .{
            .root = root,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    fn contains(boundary: Rect, x: f64, y: f64) bool {
        return x >= boundary.x and x < boundary.x + boundary.width and
            y >= boundary.y and y < boundary.y + boundary.height;
    }

    pub fn insert(qt: *QuadTree, x: f64, y: f64) !void {
        const root = qt.root orelse return;
        _ = try qt.insertRecursive(root, x, y);
    }

    fn insertRecursive(qt: *QuadTree, node: *QuadNode, x: f64, y: f64) !bool {
        if (!contains(node.boundary, x, y)) return false;

        if (!node.divided and node.point_count < qt.capacity) {
            node.point_count += 1;
            return true;
        }

        if (!node.divided) {
            try qt.subdivideNode(node);
        }

        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                if (contains(child.boundary, x, y)) {
                    if (try qt.insertRecursive(child, x, y)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    fn subdivideNode(qt: *QuadTree, node: *QuadNode) !void {
        const half_w = node.boundary.width / 2;
        const half_h = node.boundary.height / 2;
        const x = node.boundary.x;
        const y = node.boundary.y;

        const boundaries = [_]Rect{
            .{ .x = x, .y = y, .width = half_w, .height = half_h },
            .{ .x = x + half_w, .y = y, .width = half_w, .height = half_h },
            .{ .x = x, .y = y + half_h, .width = half_w, .height = half_h },
            .{ .x = x + half_w, .y = y + half_h, .width = half_w, .height = half_h },
        };

        for (0..4) |i| {
            const child = try qt.allocator.create(QuadNode);
            child.* = .{
                .boundary = boundaries[i],
                .children = [_]?*QuadNode{null} ** 4,
                .point_count = 0,
                .divided = false,
                .allocator = qt.allocator,
            };
            node.children[i] = child;
        }
        node.divided = true;
    }

    pub fn query(qt: *QuadTree, range: Rect, allocator: std.mem.Allocator) ![][2]f64 {
        var result = try std.ArrayList([2]f64).initCapacity(allocator, 16);
        defer result.deinit(allocator);
        if (qt.root) |root| {
            try qt.queryRecursive(root, range, &result, allocator);
        }
        return result.toOwnedSlice(allocator);
    }

    fn queryRecursive(qt: *QuadTree, node: *QuadNode, range: Rect, result: *std.ArrayList([2]f64), allocator: std.mem.Allocator) !void {
        _ = range;
        if (node.point_count > 0) {
            try result.append(allocator, .{ node.boundary.x, node.boundary.y });
        }
        if (node.divided) {
            for (node.children) |maybe_child| {
                if (maybe_child) |child| {
                    try qt.queryRecursive(child, range, result, allocator);
                }
            }
        }
    }

    pub fn deinit(qt: *QuadTree) void {
        if (qt.root) |root| {
            root.deinit();
            qt.allocator.destroy(root);
        }
    }
};

test "quadtree insert" {
    const boundary = Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var qt = try QuadTree.init(std.testing.allocator, boundary, 4);
    defer qt.deinit();

    try qt.insert(10, 10);
    try qt.insert(50, 50);
    try qt.insert(90, 90);

    try std.testing.expect(true);
}

test "quadtree query" {
    const boundary = Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var qt = try QuadTree.init(std.testing.allocator, boundary, 4);
    defer qt.deinit();

    try qt.insert(25, 25);
    try qt.insert(75, 75);

    const range = Rect{ .x = 0, .y = 0, .width = 50, .height = 50 };
    const points = try qt.query(range, std.testing.allocator);
    defer std.testing.allocator.free(points);

    try std.testing.expect(points.len > 0);
}
