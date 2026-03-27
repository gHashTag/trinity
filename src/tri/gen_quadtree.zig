//! tri/quadtree — Quadtree for 2D spatial partitioning
//! Auto-generated from specs/tri_quadtree.tri
//! TTT Dogfood v0.2 Stage 198

const std = @import("std");

/// Rectangle boundary
pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

/// Quadtree node
pub const QuadNode = struct {
    boundary: Rect,
    children: [4]?*QuadNode,
    points: std.ArrayList([2]f64),
    divided: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(node: *QuadNode) void {
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                child.deinit();
                node.allocator.destroy(child);
            }
        }
        node.points.deinit(node.allocator);
    }
};

/// Quadtree for spatial queries
pub const QuadTree = struct {
    root: ?*QuadNode,
    capacity: usize,
    allocator: std.mem.Allocator,

    /// Create quadtree
    pub fn init(allocator: std.mem.Allocator, boundary: Rect, capacity: usize) !QuadTree {
        const root = try allocator.create(QuadNode);
        root.* = .{
            .boundary = boundary,
            .children = [_]?*QuadNode{null} ** 4,
            .points = std.ArrayList([2]f64).init(allocator),
            .divided = false,
            .allocator = allocator,
        };

        return .{
            .root = root,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    /// Check if point is in boundary
    fn contains(boundary: Rect, x: f64, y: f64) bool {
        return x >= boundary.x and x < boundary.x + boundary.width and
            y >= boundary.y and y < boundary.y + boundary.height;
    }

    /// Insert point
    pub fn insert(qt: *QuadTree, x: f64, y: f64) !void {
        const root = qt.root orelse return;

        if (!qt.insertRecursive(root, x, y, qt.capacity)) {
            // Point was outside boundary
        }
    }

    fn insertRecursive(node: *QuadNode, x: f64, y: f64, capacity: usize) !bool {
        if (!node.contains(node.boundary, x, y)) return false;

        if (!node.divided and node.points.items.len < capacity) {
            try node.points.append(.{ x, y });
            return true;
        }

        if (!node.divided) {
            try qt.subdivide(node);
        }

        // Insert into appropriate quadrant
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                if (child.contains(child.boundary, x, y)) {
                    if (qt.insertRecursive(child, x, y, capacity)) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    /// Subdivide node
    fn subdivide(qt: *QuadTree, node: *QuadNode) !void {
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
                .points = std.ArrayList([2]f64).init(qt.allocator),
                .divided = false,
                .allocator = qt.allocator,
            };
            node.children[i] = child;
        }

        node.divided = true;
    }

    /// Find points in range
    pub fn query(qt: *QuadTree, range: Rect, allocator: std.mem.Allocator) ![][2]f64 {
        var result = std.ArrayList([2]f64).init(allocator);
        if (qt.root) |root| {
            try qt.queryRecursive(root, range, &result);
        }
        return result.toOwnedSlice(allocator);
    }

    fn queryRecursive(node: *QuadNode, range: Rect, result: *std.ArrayList([2]f64)) !void {
        if (!rectOverlap(node.boundary, range)) return;

        for (node.points.items) |point| {
            if (range.contains(point[0], point[1])) {
                try result.append(point);
            }
        }

        if (node.divided) {
            for (node.children) |maybe_child| {
                if (maybe_child) |child| {
                    try qt.queryRecursive(child, range, result);
                }
            }
        }
    }

    fn rectOverlap(a: Rect, b: Rect) bool {
        return a.x < b.x + b.width and a.x + a.width > b.x and
            a.y < b.y + b.height and a.y + a.height > b.y;
    }

    /// Free tree
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

    // Just verify no crash
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

    // Should contain (25, 25)
    try std.testing.expect(points.len > 0);
}
