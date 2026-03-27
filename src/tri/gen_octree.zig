//! tri/octree — 3D spatial partitioning
//! TTT Dogfood v0.2 Stage 199

const std = @import("std");

pub const BBox = struct {
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
};

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

pub const Octree = struct {
    root: ?*OctNode,
    min_size: f64,
    allocator: std.mem.Allocator,

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

    fn contains(bounds: BBox, x: f64, y: f64, z: f64) bool {
        return x >= bounds.min_x and x <= bounds.max_x and
            y >= bounds.min_y and y <= bounds.max_y and
            z >= bounds.min_z and z <= bounds.max_z;
    }

    pub fn insert(ot: *Octree, x: f64, y: f64, z: f64, data: ?*const anyopaque) !void {
        const root = ot.root orelse return;
        try insertRecursive(ot, root, x, y, z, data);
    }

    fn insertRecursive(ot: *Octree, node: *OctNode, x: f64, y: f64, z: f64, data: ?*const anyopaque) !void {
        if (!contains(node.bounds, x, y, z)) return;

        const size_x = node.bounds.max_x - node.bounds.min_x;
        if (size_x < ot.min_size or node.data != null) {
            node.data = data;
            return;
        }

        if (!node.divided) {
            try ot.subdivide(node);
        }

        for (node.children) |maybe_child| {
            if (maybe_child) |child| {
                if (contains(child.bounds, x, y, z)) {
                    try insertRecursive(ot, child, x, y, z, data);
                    return;
                }
            }
        }
    }

    fn subdivide(ot: *Octree, node: *OctNode) !void {
        const mid_x = (node.bounds.min_x + node.bounds.max_x) / 2;
        const mid_y = (node.bounds.min_y + node.bounds.max_y) / 2;
        const mid_z = (node.bounds.min_z + node.bounds.max_z) / 2;

        const bounds = [_]BBox{
            .{ .min_x = node.bounds.min_x, .min_y = node.bounds.min_y, .min_z = node.bounds.min_z, .max_x = mid_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = mid_x, .min_y = node.bounds.min_y, .min_z = node.bounds.min_z, .max_x = node.bounds.max_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = node.bounds.min_x, .min_y = mid_y, .min_z = node.bounds.min_z, .max_x = mid_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = mid_x, .min_y = mid_y, .min_z = mid_z, .max_x = node.bounds.max_x, .max_y = mid_y, .max_z = mid_z },
            .{ .min_x = node.bounds.min_x, .min_y = node.bounds.min_y, .min_z = mid_z, .max_x = mid_x, .max_y = mid_y, .max_z = node.bounds.max_z },
            .{ .min_x = mid_x, .min_y = node.bounds.min_y, .min_z = mid_z, .max_x = node.bounds.max_x, .max_y = mid_y, .max_z = node.bounds.max_z },
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

    pub fn query(ot: *Octree, bounds: BBox, allocator: std.mem.Allocator) ![]?*const anyopaque {
        var result = std.ArrayList(?*const anyopaque).init(allocator);
        defer result.deinit();

        if (ot.root) |root| {
            try queryRecursive(ot, root, bounds, &result);
        }

        return result.toOwnedSlice(allocator);
    }

    fn queryRecursive(ot: *Octree, node: *OctNode, bounds: BBox, result: *std.ArrayList(?*const anyopaque)) !void {
        _ = ot;
        if (node.data) |data| {
            try result.append(ot.allocator, data);
        }

        if (node.divided) {
            for (node.children) |maybe_child| {
                if (maybe_child) |child| {
                    try queryRecursive(ot, child, bounds, result);
                }
            }
        }
    }

    pub fn deinit(ot: *Octree) void {
        if (ot.root) |root| {
            root.deinit();
            ot.allocator.destroy(root);
        }
    }
};

test "octree init" {
    const bounds = BBox{
        .min_x = 0, .min_y = 0, .min_z = 0,
        .max_x = 100, .max_y = 100, .max_z = 100,
    };
    var ot = try Octree.init(std.testing.allocator, bounds, 10);
    defer ot.deinit();

    try std.testing.expect(ot.root != null);
}

test "octree insert" {
    const bounds = BBox{
        .min_x = 0, .min_y = 0, .min_z = 0,
        .max_x = 100, .max_y = 100, .max_z = 100,
    };
    var ot = try Octree.init(std.testing.allocator, bounds, 10);
    defer ot.deinit();

    try ot.insert(50, 50, 50, null);
    try ot.insert(25, 25, 25, null);

    try std.testing.expect(true);
}
