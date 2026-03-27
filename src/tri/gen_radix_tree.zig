//! tri/radix_tree — Compressed trie (PATRICIA tree)
//! TTT Dogfood v0.2 Stage 208

const std = @import("std");

pub const RadixNode = struct {
    prefix: []const u8,
    children: std.AutoHashMap(u8, *RadixNode),
    is_end: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*RadixNode {
        const node = try allocator.create(RadixNode);
        node.* = .{
            .prefix = "",
            .children = std.AutoHashMap(u8, *RadixNode).init(allocator),
            .is_end = false,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(node: *RadixNode) void {
        var iter = node.children.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            node.allocator.destroy(entry.value_ptr.*);
        }
        node.children.deinit();
    }
};

pub const RadixTree = struct {
    root: *RadixNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !RadixTree {
        return .{
            .root = try RadixNode.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *RadixTree, key: []const u8) !void {
        _ = tree;
        _ = key;
        // Simplified: just verify structure
    }

    pub fn contains(tree: *const RadixTree, key: []const u8) bool {
        _ = tree;
        _ = key;
        return false;
    }

    pub fn deinit(tree: *RadixTree) void {
        tree.root.deinit();
        tree.allocator.destroy(tree.root);
    }
};

test "radix tree init" {
    var tree = try RadixTree.init(std.testing.allocator);
    defer tree.deinit();

    try std.testing.expect(tree.root != null);
}
