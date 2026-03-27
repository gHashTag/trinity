//! tri/splay_tree — Self-adjusting binary search tree
//! TTT Dogfood v0.2 Stage 203

const std = @import("std");

pub const SplayNode = struct {
    key: i64,
    value: i64,
    left: ?*SplayNode,
    right: ?*SplayNode,
    parent: ?*SplayNode,
};

pub const SplayTree = struct {
    root: ?*SplayNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SplayTree {
        return .{ .root = null, .allocator = allocator };
    }

    pub fn insert(tree: *SplayTree, key: i64, value: i64) !void {
        const node = try tree.allocator.create(SplayNode);
        node.* = .{
            .key = key,
            .value = value,
            .left = null,
            .right = null,
            .parent = null,
        };

        if (tree.root == null) {
            tree.root = node;
            return;
        }

        var curr = tree.root.?;
        while (true) {
            if (key < curr.key) {
                if (curr.left == null) {
                    curr.left = node;
                    node.parent = curr;
                    break;
                }
                curr = curr.left.?;
            } else {
                if (curr.right == null) {
                    curr.right = node;
                    node.parent = curr;
                    break;
                }
                curr = curr.right.?;
            }
        }

        tree.splay(node);
        tree.root = node;
    }

    fn splay(tree: *SplayTree, node: *SplayNode) void {
        _ = tree;
        while (node.parent) |p| {
            const pp = p.parent;
            if (pp == null) {
                // Zig
                if (p.left == node) {
                    tree.rotateRight(p);
                } else {
                    tree.rotateLeft(p);
                }
            } else {
                const gp = pp.?;
                if ((gp.left == p and p.left == node) or
                    (gp.right == p and p.right == node)) {
                    // Zig-zig
                    if (gp.left == p) {
                        tree.rotateRight(gp);
                        tree.rotateRight(p);
                    } else {
                        tree.rotateLeft(gp);
                        tree.rotateLeft(p);
                    }
                } else {
                    // Zig-zag
                    if (p.left == node) {
                        tree.rotateRight(p);
                        tree.rotateLeft(pp.?);
                    } else {
                        tree.rotateLeft(p);
                        tree.rotateRight(pp.?);
                    }
                }
            }
        }
    }

    fn rotateLeft(tree: *SplayTree, x: *SplayNode) void {
        const y = x.right.?;
        x.right = y.left;
        if (y.left) |yl| {
            yl.parent = x;
        }
        y.parent = x.parent;
        if (x.parent) |xp| {
            if (xp.left == x) {
                xp.left = y;
            } else {
                xp.right = y;
            }
        } else {
            tree.root = y;
        }
        y.left = x;
        x.parent = y;
    }

    fn rotateRight(tree: *SplayTree, y: *SplayNode) void {
        const x = y.left.?;
        y.left = x.right;
        if (x.right) |xr| {
            xr.parent = y;
        }
        x.parent = y.parent;
        if (y.parent) |yp| {
            if (yp.right == y) {
                yp.right = x;
            } else {
                yp.left = x;
            }
        } else {
            tree.root = x;
        }
        x.right = y;
        y.parent = x;
    }

    pub fn find(tree: *SplayTree, key: i64) ?i64 {
        var curr = tree.root;
        while (curr) |node| {
            if (key == node.key) {
                tree.splay(node);
                tree.root = node;
                return node.value;
            }
            curr = if (key < node.key) node.left else node.right;
        }
        return null;
    }

    pub fn deinit(tree: *SplayTree) void {
        if (tree.root) |r| {
            tree.freeRecursive(r);
        }
    }

    fn freeRecursive(tree: *SplayTree, node: ?*SplayNode) void {
        if (node) |n| {
            tree.freeRecursive(n.left);
            tree.freeRecursive(n.right);
            tree.allocator.destroy(n);
        }
    }
};

test "splay tree insert find" {
    var tree = SplayTree.init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, 50);
    try tree.insert(3, 30);
    try tree.insert(7, 70);

    try std.testing.expectEqual(@as(i64, 30), tree.find(3).?);
    try std.testing.expect(tree.find(99) == null);
}
