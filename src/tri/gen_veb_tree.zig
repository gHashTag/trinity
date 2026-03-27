//! tri/veb_tree — van Emde Boas tree for integer keys
//! TTT Dogfood v0.2 Stage 209

const std = @import("std");

const UNIVERSE_SIZE = 16;

pub const VEBTree = struct {
    min: ?u64,
    max: ?u64,
    summary: ?*VEBTree,
    cluster: []?*VEBTree,
    universe_size: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, universe_size: u64) !VEBTree {
        const upper = @sqrt(@as(f64, @floatFromInt(universe_size)));
        const cluster_size = @as(usize, @intCast(@ceil(upper)));
        const cluster = try allocator.alloc(?*VEBTree, cluster_size);
        @memset(cluster, null);

        return .{
            .min = null,
            .max = null,
            .summary = null,
            .cluster = cluster,
            .universe_size = universe_size,
            .allocator = allocator,
        };
    }

    fn high(tree: *const VEBTree, x: u64) u64 {
        const upper = @sqrt(@as(f64, @floatFromInt(tree.universe_size)));
        const size = @as(u64, @intCast(@ceil(upper)));
        return x / size;
    }

    fn low(tree: *const VEBTree, x: u64) u64 {
        const upper = @sqrt(@as(f64, @floatFromInt(tree.universe_size)));
        const size = @as(u64, @intCast(@ceil(upper)));
        return x % size;
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

        if (tree.universe_size > 2) {
            const i = tree.high(x);
            const j = tree.low(x);

            if (tree.cluster[i] == null) {
                const upper = @sqrt(@as(f64, @floatFromInt(tree.universe_size)));
                const size = @as(u64, @intCast(@ceil(upper)));
                const sub = try tree.allocator.create(VEBTree);
                sub.* = try VEBTree.init(tree.allocator, size);
                tree.cluster[i] = sub;

                if (tree.summary == null) {
                    const s_size = @as(u64, @intCast(@ceil(upper)));
                    const sum = try tree.allocator.create(VEBTree);
                    sum.* = try VEBTree.init(tree.allocator, s_size);
                    tree.summary = sum;
                }

                try tree.summary.?.insert(i);
            }

            try tree.cluster[i].?.insert(j);
        }

        if (x > tree.max.?) {
            tree.max = x;
        }
    }

    pub fn contains(tree: *const VEBTree, x: u64) bool {
        if (x == tree.min or x == tree.max) {
            return true;
        }

        if (tree.universe_size == 2) {
            return false;
        }

        const i = tree.high(x);
        const j = tree.low(x);

        if (tree.cluster[i] == null) {
            return false;
        }

        return tree.cluster[i].?.contains(j);
    }

    pub fn deinit(tree: *VEBTree) void {
        if (tree.summary) |s| {
            s.deinit();
            tree.allocator.destroy(s);
        }
        for (tree.cluster) |maybe_c| {
            if (maybe_c) |c| {
                c.deinit();
                tree.allocator.destroy(c);
            }
        }
        tree.allocator.free(tree.cluster);
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
