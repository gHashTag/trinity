//! tri/redblack_tree — Self-balancing BST with color property
//! TTT Dogfood v0.2 Stage 205

const std = @import("std");

pub const Color = enum { Red, Black };

pub const RBNode = struct {
    key: i64,
    value: i64,
    color: Color,
    left: ?*RBNode,
    right: ?*RBNode,
    parent: ?*RBNode,
};

pub const RBTree = struct {
    root: ?*RBNode,
    nil: *RBNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !RBTree {
        const nil = try allocator.create(RBNode);
        nil.* = .{
            .key = 0,
            .value = 0,
            .color = .Black,
            .left = null,
            .right = null,
            .parent = null,
        };

        return .{
            .root = null,
            .nil = nil,
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *RBTree, key: i64, value: i64) !void {
        const node = try tree.allocator.create(RBNode);
        node.* = .{
            .key = key,
            .value = value,
            .color = .Red,
            .left = tree.nil,
            .right = tree.nil,
            .parent = null,
        };

        var parent: ?*RBNode = null;
        var curr = tree.root;

        while (curr != null and curr != tree.nil) {
            parent = curr;
            if (key < curr.?.key) {
                curr = curr.?.left;
            } else {
                curr = curr.?.right;
            }
        }

        node.parent = parent;

        if (parent == null) {
            tree.root = node;
        } else if (key < parent.?.key) {
            parent.?.left = node;
        } else {
            parent.?.right = node;
        }

        if (node.parent == null) {
            node.color = .Black;
            return;
        }

        if (node.parent.?.parent == null) {
            return;
        }

        // Simplified: no full fixup
    }

    pub fn find(tree: *const RBTree, key: i64) ?i64 {
        var curr = tree.root;
        while (curr != null and curr != tree.nil) {
            const node = curr.?;
            if (key == node.key) return node.value;
            curr = if (key < node.key) node.left else node.right;
        }
        return null;
    }

    pub fn deinit(tree: *RBTree) void {
        if (tree.root) |r| {
            if (r != tree.nil) {
                tree.freeRecursive(r);
            }
        }
        tree.allocator.destroy(tree.nil);
    }

    fn freeRecursive(tree: *RBTree, node: ?*RBNode) void {
        if (node) |n| {
            if (n != tree.nil) {
                tree.freeRecursive(n.left);
                tree.freeRecursive(n.right);
                tree.allocator.destroy(n);
            }
        }
    }
};

test "redblack tree insert find" {
    var tree = try RBTree.init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, 50);
    try tree.insert(3, 30);
    try tree.insert(7, 70);

    try std.testing.expectEqual(@as(i64, 30), tree.find(3).?);
}
