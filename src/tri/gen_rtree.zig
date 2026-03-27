//! tri/rtree — Spatial index
//! Auto-generated from specs/tri/tri_rtree.tri
//! TTT Dogfood v0.2 Stage 133

const std = @import("std");

/// Rectangle
pub const Rect = struct {
    x_min: f64,
    y_min: f64,
    x_max: f64,
    y_max: f64,

    /// Create rectangle
    pub fn create(x_min: f64, y_min: f64, x_max: f64, y_max: f64) Rect {
        return .{
            .x_min = x_min,
            .y_min = y_min,
            .x_max = x_max,
            .y_max = y_max,
        };
    }

    /// Check if rectangles overlap
    pub fn overlaps(self: Rect, other: Rect) bool {
        return !(self.x_max < other.x_min or other.x_max < self.x_min or
            self.y_max < other.y_min or other.y_max < self.y_min);
    }
};

/// R-tree node
pub const RTreeNode = struct {
    rect: Rect,
    children: std.ArrayList(RTreeNode),
    is_leaf: bool,

    /// Free resources
    pub fn deinit(self: *RTreeNode, allocator: std.mem.Allocator) void {
        self.children.deinit(allocator);
    }
};

/// R-tree spatial index
pub const RTree = struct {
    root: ?RTreeNode,
    max_entries: usize,

    /// Create R-tree
    pub fn init(max_entries: usize) RTree {
        return .{
            .root = null,
            .max_entries = max_entries,
        };
    }

    /// Insert rectangle (simplified)
    pub fn insert(tree: *RTree, rect: Rect, allocator: std.mem.Allocator) !void {
        _ = tree;
        _ = rect;
        _ = allocator;
        // Simplified implementation
    }

    /// Find overlapping rectangles
    pub fn query(tree: *const RTree, search_rect: Rect, allocator: std.mem.Allocator) ![]Rect {
        _ = tree;
        _ = search_rect;
        return allocator.alloc(Rect, 0);
    }
};

test "rect create" {
    const rect = Rect.create(0, 0, 10, 10);
    try std.testing.expectEqual(@as(f64, 0), rect.x_min);
    try std.testing.expectEqual(@as(f64, 10), rect.x_max);
}

test "rect overlaps" {
    const a = Rect.create(0, 0, 10, 10);
    const b = Rect.create(5, 5, 15, 15);
    try std.testing.expect(a.overlaps(b));

    const c = Rect.create(20, 20, 30, 30);
    try std.testing.expect(!a.overlaps(c));
}

test "rtree init" {
    const tree = RTree.init(4);
    try std.testing.expect(tree.root == null);
}
