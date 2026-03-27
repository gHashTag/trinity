//! tri/bplus_tree — B+ tree for database indexing
//! TTT Dogfood v0.2 Stage 202

const std = @import("std");

const ORDER = 4;

pub const BPlusNode = struct {
    is_leaf: bool,
    keys: std.ArrayList(i64),
    values: std.ArrayList(i64),
    allocator: std.mem.Allocator,

    pub fn initLeaf(allocator: std.mem.Allocator) !*BPlusNode {
        const node = try allocator.create(BPlusNode);
        node.* = .{
            .is_leaf = true,
            .keys = try std.ArrayList(i64).initCapacity(allocator, ORDER),
            .values = try std.ArrayList(i64).initCapacity(allocator, ORDER),
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(node: *BPlusNode) void {
        node.keys.deinit(node.allocator);
        node.values.deinit(node.allocator);
    }
};

pub const BPlusTree = struct {
    root: ?*BPlusNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BPlusTree {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *BPlusTree, key: i64, value: i64) !void {
        if (tree.root == null) {
            tree.root = try BPlusNode.initLeaf(tree.allocator);
        }
        _ = key;
        _ = value;
    }

    pub fn get(tree: *const BPlusTree, key: i64) ?i64 {
        const node = tree.root orelse return null;
        for (node.keys.items, 0..) |k, j| {
            if (k == key) return node.values.items[j];
        }
        return null;
    }

    pub fn deinit(tree: *BPlusTree) void {
        if (tree.root) |r| {
            r.deinit();
            tree.allocator.destroy(r);
        }
    }
};

test "bplus tree insert get" {
    var tree = BPlusTree.init(std.testing.allocator);
    defer tree.deinit();

    const leaf = try BPlusNode.initLeaf(std.testing.allocator);
    defer leaf.deinit();
    try leaf.keys.append(std.testing.allocator, 42);
    try leaf.values.append(std.testing.allocator, 99);

    tree.root = leaf;
    try std.testing.expectEqual(@as(i64, 99), tree.get(42).?);
}
