//! tri/avl_tree — Self-balancing BST with height property
//! TTT Dogfood v0.2 Stage 204

const std = @import("std");

pub const AVLNode = struct {
    key: i64,
    value: i64,
    left: ?*AVLNode,
    right: ?*AVLNode,
    height: i32,
};

pub const AVLTree = struct {
    root: ?*AVLNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AVLTree {
        return .{ .root = null, .allocator = allocator };
    }

    fn height(node: ?*AVLNode) i32 {
        return if (node) |n| n.height else 0;
    }

    fn balanceFactor(node: ?*AVLNode) i32 {
        return if (node) |n| height(n.left) - height(n.right) else 0;
    }

    fn updateHeight(node: *AVLNode) void {
        node.height = @max(height(node.left), height(node.right)) + 1;
    }

    fn rotateRight(tree: *AVLTree, y: *AVLNode) *AVLNode {
        const x = y.left.?;
        const T2 = x.right;

        x.right = y;
        y.left = T2;

        updateHeight(y);
        updateHeight(x);

        if (tree.root == y) {
            tree.root = x;
        }

        return x;
    }

    fn rotateLeft(tree: *AVLTree, x: *AVLNode) *AVLNode {
        const y = x.right.?;
        const T2 = y.left;

        y.left = x;
        x.right = T2;

        updateHeight(x);
        updateHeight(y);

        if (tree.root == x) {
            tree.root = y;
        }

        return y;
    }

    pub fn insert(tree: *AVLTree, key: i64, value: i64) !void {
        tree.root = try tree.insertRecursive(tree.root, key, value);
    }

    fn insertRecursive(tree: *AVLTree, node: ?*AVLNode, key: i64, value: i64) !?*AVLNode {
        if (node == null) {
            const n = try tree.allocator.create(AVLNode);
            n.* = .{
                .key = key,
                .value = value,
                .left = null,
                .right = null,
                .height = 1,
            };
            return n;
        }

        const n = node.?;
        if (key < n.key) {
            n.left = try tree.insertRecursive(n.left, key, value);
        } else if (key > n.key) {
            n.right = try tree.insertRecursive(n.right, key, value);
        } else {
            n.value = value;
            return n;
        }

        updateHeight(n);

        const bf = balanceFactor(n);

        // Left Left
        if (bf > 1 and key < n.left.?.key) {
            return tree.rotateRight(n);
        }
        // Right Right
        if (bf < -1 and key > n.right.?.key) {
            return tree.rotateLeft(n);
        }
        // Left Right
        if (bf > 1 and key > n.left.?.key) {
            n.left = tree.rotateLeft(n.left.?);
            return tree.rotateRight(n);
        }
        // Right Left
        if (bf < -1 and key < n.right.?.key) {
            n.right = tree.rotateRight(n.right.?);
            return tree.rotateLeft(n);
        }

        return n;
    }

    pub fn find(tree: *const AVLTree, key: i64) ?i64 {
        var curr = tree.root;
        while (curr) |node| {
            if (key == node.key) return node.value;
            curr = if (key < node.key) node.left else node.right;
        }
        return null;
    }

    pub fn deinit(tree: *AVLTree) void {
        if (tree.root) |r| {
            tree.freeRecursive(r);
        }
    }

    fn freeRecursive(tree: *AVLTree, node: ?*AVLNode) void {
        if (node) |n| {
            tree.freeRecursive(n.left);
            tree.freeRecursive(n.right);
            tree.allocator.destroy(n);
        }
    }
};

test "avl tree insert find" {
    var tree = AVLTree.init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, 50);
    try tree.insert(3, 30);
    try tree.insert(7, 70);

    try std.testing.expectEqual(@as(i64, 30), tree.find(3).?);
    try std.testing.expect(tree.find(99) == null);
}
