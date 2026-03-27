//! tri/splay_tree — Splay tree (self-adjusting BST)
//! Auto-generated from specs/tri/tri_splay_tree.tri
//! TTT Dogfood v0.2 Stage 150

const std = @import("std");

/// Splay tree node
pub fn SplayNode(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,
        left: ?*SplayNode(K, V),
        right: ?*SplayNode(K, V),
        parent: ?*SplayNode(K, V),
    };
}

/// Splay tree
pub fn SplayTree(comptime K: type, comptime V: type) type {
    return struct {
        root: ?*SplayNode(K, V),
        size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty splay tree
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .root = null,
                .size = 0,
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self) void {
            if (self.root) |r| {
                self.destroyNode(r);
            }
        }

        /// Recursively destroy subtree
        fn destroyNode(self: *Self, node: *SplayNode(K, V)) void {
            if (node.left) |l| self.destroyNode(l);
            if (node.right) |r| self.destroyNode(r);
            self.allocator.destroy(node);
        }

        /// Right rotate
        fn rightRotate(self: *Self, x: *SplayNode(K, V)) void {
            const y = x.left orelse return;
            x.left = y.right;

            if (y.right) |yr| {
                yr.parent = x;
            }

            y.parent = x.parent;

            if (x.parent == null) {
                self.root = y;
            } else if (x == x.parent.?.left) {
                x.parent.?.left = y;
            } else {
                x.parent.?.right = y;
            }

            y.right = x;
            x.parent = y;
        }

        /// Left rotate
        fn leftRotate(self: *Self, x: *SplayNode(K, V)) void {
            const y = x.right orelse return;
            x.right = y.left;

            if (y.left) |yl| {
                yl.parent = x;
            }

            y.parent = x.parent;

            if (x.parent == null) {
                self.root = y;
            } else if (x == x.parent.?.left) {
                x.parent.?.left = y;
            } else {
                x.parent.?.right = y;
            }

            y.left = x;
            x.parent = y;
        }

        /// Splay node to root
        fn splay(self: *Self, node: *SplayNode(K, V)) void {
            while (node.parent) |parent| {
                const grandparent = parent.parent;

                // Zig - node is child of root
                if (grandparent == null) {
                    if (node == parent.left) {
                        self.rightRotate(parent);
                    } else {
                        self.leftRotate(parent);
                    }
                }
                // Zig-zig
                else if (node == parent.left and parent == grandparent.?.left) {
                    self.rightRotate(grandparent.?);
                    self.rightRotate(parent);
                } else if (node == parent.right and parent == grandparent.?.right) {
                    self.leftRotate(grandparent.?);
                    self.leftRotate(parent);
                }
                // Zig-zag
                else if (node == parent.right and parent == grandparent.?.left) {
                    self.leftRotate(parent);
                    self.rightRotate(grandparent.?);
                } else {
                    self.rightRotate(parent);
                    self.leftRotate(grandparent.?);
                }
            }
        }

        /// Find key and splay to root
        pub fn find(self: *Self, key: K) ?V {
            var current = self.root;
            var last_visited: ?*SplayNode(K, V) = null;

            while (current != null) {
                last_visited = current;

                if (key == current.?.key) {
                    self.splay(current.?);
                    return current.?.value;
                } else if (key < current.?.key) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            // Splay the last visited node
            if (last_visited) |lv| {
                self.splay(lv);
            }

            return null;
        }

        /// Insert and splay to root
        pub fn insert(self: *Self, key: K, value: V) !void {
            if (self.root == null) {
                const new_node = try self.allocator.create(SplayNode(K, V));
                new_node.* = .{
                    .key = key,
                    .value = value,
                    .left = null,
                    .right = null,
                    .parent = null,
                };
                self.root = new_node;
                self.size += 1;
                return;
            }

            var current = self.root;
            var parent: ?*SplayNode(K, V) = null;

            while (current != null) {
                parent = current;

                if (key == current.?.key) {
                    // Update existing key and splay
                    current.?.value = value;
                    self.splay(current.?);
                    return;
                } else if (key < current.?.key) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            const new_node = try self.allocator.create(SplayNode(K, V));
            new_node.* = .{
                .key = key,
                .value = value,
                .left = null,
                .right = null,
                .parent = parent,
            };

            if (parent) |p| {
                if (key < p.key) {
                    p.left = new_node;
                } else {
                    p.right = new_node;
                }
            }

            self.splay(new_node);
            self.size += 1;
        }

        /// Delete key
        pub fn delete(self: *Self, key: K) bool {
            if (self.find(key) == null) return false;

            const old_root = self.root orelse return false;

            self.root = null;

            if (old_root.left == null) {
                self.root = old_root.right;
                if (self.root) |r| {
                    r.parent = null;
                }
            } else if (old_root.right == null) {
                self.root = old_root.left;
                if (self.root) |r| {
                    r.parent = null;
                }
            } else {
                // Two children - split and join
                const left_subtree = old_root.left;
                left_subtree.?.parent = null;

                const right_subtree = old_root.right;
                right_subtree.?.parent = null;

                self.root = left_subtree;

                // Find max in left subtree
                var max_node = left_subtree;
                while (max_node.?.right != null) {
                    max_node = max_node.?.right;
                }

                self.splay(max_node.?);
                self.root.?.right = right_subtree;
                if (right_subtree) |r| {
                    r.parent = self.root;
                }
            }

            self.allocator.destroy(old_root);
            self.size -= 1;
            return true;
        }
    };
}

test "splay tree init" {
    var tree = SplayTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try std.testing.expectEqual(@as(usize, 0), tree.size);
}

test "splay tree insert find" {
    var tree = SplayTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expectEqualStrings("five", tree.find(5).?);
    try std.testing.expectEqualStrings("three", tree.find(3).?);
}

test "splay tree delete" {
    var tree = SplayTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expect(tree.delete(5));
    try std.testing.expect(tree.find(5) == null);
    try std.testing.expectEqual(@as(usize, 2), tree.size);
}

test "splay tree splaying" {
    var tree = SplayTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(1, "one");
    try tree.insert(2, "two");
    try tree.insert(3, "three");

    // After finding 1, it should be at root
    _ = tree.find(1);
    try std.testing.expectEqual(@as(i32, 1), tree.root.?.key);
}
