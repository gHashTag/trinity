//! tri/b_tree — B-Tree multiway balanced tree
//! Auto-generated from specs/tri/tri_b_tree.tri
//! TTT Dogfood v0.2 Stage 161

const std = @import("std");

/// B-Tree node
pub const BTreeNode = struct {
    keys: []usize,
    children: []?*BTreeNode,
    leaf: bool,
    count: usize,
    allocator: std.mem.Allocator,

    /// Free node
    pub fn deinit(self: *BTreeNode) void {
        self.allocator.free(self.keys);
        self.allocator.free(self.children);
    }
};

/// B-Tree with minimum degree t
pub const BTree = struct {
    root: ?*BTreeNode,
    t: usize,
    allocator: std.mem.Allocator,

    /// Create B-tree with min degree t
    pub fn init(allocator: std.mem.Allocator, min_degree: usize) !BTree {
        if (min_degree < 2) return error.InvalidDegree;

        const root_node = try allocator.create(BTreeNode);
        root_node.* = .{
            .keys = &[_]usize{},
            .children = &[_]?*BTreeNode{},
            .leaf = true,
            .count = 0,
            .allocator = allocator,
        };

        return .{
            .root = root_node,
            .t = min_degree,
            .allocator = allocator,
        };
    }

    /// Search for key
    pub fn search(tree: *const BTree, key: usize) bool {
        const node = tree.root orelse return false;
        return searchNode(node, key);
    }

    fn searchNode(node: *const BTreeNode, key: usize) bool {
        var i: usize = 0;
        while (i < node.count and key > node.keys[i]) {
            i += 1;
        }

        if (i < node.count and key == node.keys[i]) return true;
        if (node.leaf) return false;

        const child = node.children[i].?; // Non-leaf has children
        return searchNode(child, key);
    }

    /// Insert key into tree
    pub fn insert(tree: *BTree, key: usize) !void {
        const root = tree.root orelse return;
        const t = tree.t;

        if (root.count == 2 * t - 1) {
            // Root is full, split it
            const new_root = try tree.allocator.create(BTreeNode);
            new_root.* = .{
                .keys = try tree.allocator.alloc(usize, 2 * t - 1),
                .children = try tree.allocator.alloc(?*BTreeNode, 2 * t),
                .leaf = false,
                .count = 0,
                .allocator = tree.allocator,
            };
            @memset(new_root.keys, 0);
            @memset(new_root.children, null);
            new_root.children[0] = root;

            try splitChild(new_root, 0, t);
            try insertNonFull(new_root, key, t);
            tree.root = new_root;
        } else {
            try insertNonFull(root, key, t);
        }
    }

    fn splitChild(parent: *BTreeNode, index: usize, t: usize) !void {
        const allocator = parent.allocator;
        const full = parent.children[index].?;

        const new_node = try allocator.create(BTreeNode);
        new_node.* = .{
            .keys = try allocator.alloc(usize, 2 * t - 1),
            .children = try allocator.alloc(?*BTreeNode, 2 * t),
            .leaf = full.leaf,
            .count = t - 1,
            .allocator = allocator,
        };
        @memset(new_node.keys, 0);
        @memset(new_node.children, null);

        // Copy keys
        for (0..t - 1) |i| {
            new_node.keys[i] = full.keys[t + i];
        }

        // Copy children if not leaf
        if (!full.leaf) {
            for (0..t) |i| {
                new_node.children[i] = full.children[t + i];
            }
        }

        full.count = t - 1;

        // Shift parent's children and keys
        var i = parent.count;
        while (i > index) : (i -= 1) {
            parent.children[i + 1] = parent.children[i];
        }
        parent.children[index + 1] = new_node;

        i = parent.count - 1;
        while (i >= index) : (i -= 1) {
            parent.keys[i + 1] = parent.keys[i];
        }
        parent.keys[index] = full.keys[t - 1];
        parent.count += 1;
    }

    fn insertNonFull(node: *BTreeNode, key: usize, t: usize) !void {
        var i = node.count - 1;

        if (node.leaf) {
            // Insert key into leaf
            while (i >= 0 and key < node.keys[i]) : (i -= 1) {
                node.keys[i + 1] = node.keys[i];
            }
            node.keys[i + 1] = key;
            node.count += 1;
        } else {
            // Find child to descend into
            while (i >= 0 and key < node.keys[i]) {
                i -= 1;
            }
            i += 1;

            const child = node.children[i].?;
            if (child.count == 2 * t - 1) {
                try splitChild(node, i, t);
                if (key > node.keys[i]) {
                    i += 1;
                }
            }
            try insertNonFull(node.children[i].?, key, t);
        }
    }

    /// Free all nodes
    pub fn deinit(tree: *BTree) void {
        if (tree.root) |r| {
            freeNode(r, tree.allocator);
        }
    }

    fn freeNode(node: *BTreeNode, allocator: std.mem.Allocator) void {
        if (!node.leaf) {
            for (node.children[0..node.count + 1]) |maybe_child| {
                if (maybe_child) |child| {
                    freeNode(child, allocator);
                }
            }
        }
        node.deinit();
        allocator.destroy(node);
    }
};

test "b tree init" {
    const tree = try BTree.init(std.testing.allocator, 2);
    defer tree.deinit();

    try std.testing.expect(tree.root != null);
    try std.testing.expectEqual(@as(usize, 2), tree.t);
}

test "b tree insert and search" {
    var tree = try BTree.init(std.testing.allocator, 2);
    defer tree.deinit();

    const keys = [_]usize{ 10, 20, 5, 6, 12, 30, 7, 17 };

    for (keys) |k| {
        try tree.insert(k);
    }

    try std.testing.expect(tree.search(10));
    try std.testing.expect(tree.search(20));
    try std.testing.expect(tree.search(5));
    try std.testing.expect(tree.search(30));
    try std.testing.expect(!tree.search(99));
}
