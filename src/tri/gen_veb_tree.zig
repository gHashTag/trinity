//! tri/veb_tree — van Emde Boas tree for integer keys
//! TTT Dogfood v0.2 Stage 209

const std = @import("std");

const UNIVERSE_SIZE = 16;

pub const VEBTree = struct {
    min: ?u64,
    max: ?u64,
    cluster: std.ArrayList(?*VEBTree),
    universe_size: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, universe_size: u64) !VEBTree {
        return .{
            .min = null,
            .max = null,
            .cluster = std.ArrayList(?*VEBTree).init(allocator),
            .universe_size = universe_size,
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *VEBTree, x: u64) !void {
        if (tree.min == null) {
            tree.min = x;
            tree.max = x;
            return;
        }

        if (x < tree.min.?) {
            const temp = x;
            x = tree.min.?;
            tree.min = temp;
        }

        if (x > tree.max.?) {
            tree.max = x;
        }
    }

    pub fn contains(tree: *const VEBTree, x: u64) bool {
        return x == tree.min or x == tree.max;
    }

    pub fn deinit(tree: *VEBTree) void {
        for (tree.cluster.items) |maybe_c| {
            if (maybe_c) |c| {
                c.deinit();
                tree.allocator.destroy(c);
            }
        }
        tree.cluster.deinit(tree.allocator);
    }
};

test "veb tree insert contains" {
    var tree = try VEBTree.init(std.testing.allocator, UNIVERSE_SIZE);
    defer tree.deinit();

    try tree.insert(5);
    try tree.insert(10);
    try tree.insert(3);

    try std.testing.expect(tree.contains(5));
    try std.testing.expect(tree.contains(10));
    try std.testing.expect(!tree.contains(99));
}
