//! tri/octree — Octree for 3D spatial partitioning
//! Auto-generated from specs/tri_octree.tri
//! TTT Dogfood v0.2 Stage 199

const std = @import("std");

/// 3D bounding box
pub const BBox = struct {
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
};

/// Octree node
pub const OctNode = struct {
    bounds: BBox,
    children: [8]?*OctNode,
    data: ?*const anyopaque,
    divided: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(node: *OctNode) void {
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                child.deinit();
                node.allocator.destroy(child);
            }
        }
    }
};

/// 3D spatial partitioning
pub const Octree = struct {
    root: ?*OctNode,
    min_size: f64,
    allocator: std.mem.Allocator,

    /// Create octree
    pub fn init(allocator: std.mem.Allocator, bounds: BBox, min_size: f64) !Octree {
        const root = try allocator.create(OctNode);
        root.* = .{
            .bounds = bounds,
            .children = [_]?*OctNode{null} ** 8,
            .data = null,
            .divided = false,
            .allocator = allocator,
        };

        return .{
            .root = root,
            .min_size = min_size,
            .allocator = allocator,
        };
    }

    /// Check if point is in bounds
    fn contains(bounds: BBox, x: f64, y: f64, z: f64) bool {
        return x >= bounds.min_x and x <= bounds.max_x and
            y >= bounds.min_y and y <= bounds.max_y and
            z >= bounds.min_z and z <= bounds.max_z;
    }

    /// Insert point with data
    pub fn insert(ot: *Octree, x: f64, y: f64, z: f64, data: ?*const anyopaque) !void {
        const root = ot.root orelse return;
        try ot.insertRecursive(root, x, y, z, data);
    }

    fn insertRecursive(node: *OctNode, x: f64, y: f64, z: f64, data: ?*const anyopaque) !void {
        if (!node.contains(node.bounds, x, y, z)) return;

        const size_x = node.bounds.max_x - node.bounds.min_x;
        if (size_x < ot.min_size or node.data != null) {
            // Leaf node or too small
            node.data = data;
            return;
        }

        if (!node.divided) {
            try ot.subdivide(node);
        }

        // Insert into appropriate octant
        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                if (child.contains(child.bounds, x, y, z)) {
                    ot.insertRecursive(child, x, y, z, data);
                    return;
                }
            }
        }
    }

    /// Subdivide node into 8 octants
    fn subdivide(ot: *Octree, node: *OctNode) !void {
        const mid_x = (node.bounds.min_x + node.bounds.max_x) / 2;
        const mid_y = (node.bounds.min_y + node.bounds.max_y) / 2;
        const mid_z = (node.bounds.min_z + node.bounds.max_z) / 2;

        const bounds = [_]BBox{
            .{ .min_x = node.bounds.min_x, .min_y = node.bounds.min_y, .min_z = node.bounds.min_z, .max_x = mid_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = mid_x, .min_y = node.bounds.min_y, .min_z = node.bounds.min_z, .max_x = node.bounds.max_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = node.bounds.min_x, .min_y = mid_y, .min_z = node.bounds.min_z, .max_x = mid_x, .max_y = mid_y, .max_z = node.bounds.max_z },
            .{ .min_x = mid_x, .min_y = mid_y, .min_z = mid_z, .max_x = node.bounds.max_x, .max_y = node.bounds.max_y, .max_z = mid_z },
            .{ .min_x = node.bounds.min_x, .min_y = node.bounds.min_y, .min_z = mid_z, .max_x = mid_x, .max_y = mid_y, .max_z = node.bounds.max_z },
            .{ .min_x = node.bounds.min_x, .min_y = node.bounds.min_y, .min_z = mid_z, .max_x = mid_x, .max_y = node.bounds.max_y, .max_z = node.bounds.max_z },
            .{ .min_x = mid_x, .min_y = mid_y, .min_z = mid_z, .max_x = node.bounds.max_x, .max_y = mid_y, .max_z = node.bounds.max_z },
            .{ .min_x = mid_x, .min_y = mid_y, .min_z = mid_z, .max_x = node.bounds.max_x, .max_y = node.bounds.max_y, .max_z = node.bounds.max_z },
        };

        for (0..8) |i| {
            const child = try ot.allocator.create(OctNode);
            child.* = .{
                .bounds = bounds[i],
                .children = [_]?*OctNode{null} ** 8,
                .data = null,
                .divided = false,
                .allocator = ot.allocator,
            };
            node.children[i] = child;
        }

        node.divided = true;
    }

    /// Find data in region
    pub fn query(ot: *Octree, bounds: BBox, allocator: std.mem.Allocator) ![]?*const anyopaque {
        var result = std.ArrayList(?*const anyopaque).init(allocator);
        defer result.deinit();

        if (ot.root) |root| {
            try ot.queryRecursive(root, bounds, &result);
        }

        return result.toOwnedSlice(allocator);
    }

    fn queryRecursive(node: *OctNode, bounds: BBox, result: *std.ArrayList(?*const anyopaque)) !void {
        if (!boxOverlap(node.bounds, bounds)) return;

        if (node.data) |data| {
            if (containsBox(node.bounds, bounds)) {
                try result.append(data);
            }
        }

        if (node.divided) {
            for (node.children) |maybe_child| {
                if (maybe_child) |child| {
                    try ot.queryRecursive(child, bounds, result);
                }
            }
        }
    }

    fn boxOverlap(a: BBox, b: BBox) bool {
        return a.min_x <= b.max_x and a.max_x >= b.min_x and
            a.min_y <= b.max_y and a.max_y >= b.min_y and
            a.min_z <= b.max_z and a.max_z >= b.min_z;
    }

    fn containsBox(inner: BBox, outer: BBox) bool {
        return inner.min_x >= outer.min_x and inner.max_x <= outer.max_x and
            inner.min_y >= outer.min_y and inner.max_y <= outer.max_y and
            inner.min_z >= outer.min_z and inner.max_z <= outer.max_z;
    }

    /// Free tree
    pub fn deinit(ot: *Octree) void {
        if (ot.root) |root| {
            root.deinit();
            ot.allocator.destroy(root);
        }
    }
};

test "octree init" {
    const bounds = BBox{
        .min_x = 0,
        .min_y = 0,
        .min_z = 0,
        .max_x = 100,
        .max_y = 100,
        .max_z = 100,
    };
    var ot = try Octree.init(std.testing.allocator, bounds, 10);
    defer ot.deinit();

    try std.testing.expect(ot.root != null);
}

test "octree insert" {
    const bounds = BBox{
        .min_x = 0,
        .min_y = 0,
        .min_z = 0,
        .max_x = 100,
        .max_y = 100,
        .max_z = 100,
    };
    var ot = try Octree.init(std.testing.allocator, bounds, 10);
    defer ot.deinit();

    try ot.insert(50, 50, 50, null);
    try ot.insert(25, 25, 25, null);

    // Just verify no crash
    try std.testing.expect(true);
}
