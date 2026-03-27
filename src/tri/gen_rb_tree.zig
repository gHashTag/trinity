//! tri/rb_tree — Red-Black tree
//! Auto-generated from specs/tri/tri_rb_tree.tri
//! TTT Dogfood v0.2 Stage 148

const std = @import("std");

/// Node color
pub const Color = enum {
    RED,
    BLACK,
};

/// Red-Black tree node
pub fn RBNode(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,
        color: Color = .RED,
        left: ?*RBNode(K, V),
        right: ?*RBNode(K, V),
        parent: ?*RBNode(K, V),
    };
}

/// Red-Black tree
pub fn RBTree(comptime K: type, comptime V: type) type {
    return struct {
        root: ?*RBNode(K, V),
        size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty red-black tree
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
        fn destroyNode(self: *Self, node: *RBNode(K, V)) void {
            if (node.left) |l| self.destroyNode(l);
            if (node.right) |r| self.destroyNode(r);
            self.allocator.destroy(node);
        }

        /// Left rotate around x
        fn leftRotate(self: *Self, x: *RBNode(K, V)) void {
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

        /// Right rotate around x
        fn rightRotate(self: *Self, x: *RBNode(K, V)) void {
            const y = x.left orelse return;
            x.left = y.right;

            if (y.right) |yr| {
                yr.parent = x;
            }

            y.parent = x.parent;

            if (x.parent == null) {
                self.root = y;
            } else if (x == x.parent.?.right) {
                x.parent.?.right = y;
            } else {
                x.parent.?.left = y;
            }

            y.right = x;
            x.parent = y;
        }

        /// Insert key-value pair
        pub fn insert(self: *Self, key: K, value: V) !void {
            const node = try self.allocator.create(RBNode(K, V));
            node.* = .{
                .key = key,
                .value = value,
                .color = .RED,
                .left = null,
                .right = null,
                .parent = null,
            };

            var y: ?*RBNode(K, V) = null;
            var x = self.root;

            while (x != null) {
                y = x;
                if (key < x.?.key) {
                    x = x.?.left;
                } else {
                    x = x.?.right;
                }
            }

            node.parent = y;

            if (y == null) {
                self.root = node;
            } else if (key < y.?.key) {
                y.?.left = node;
            } else {
                y.?.right = node;
            }

            self.insertFixup(node);
            self.size += 1;
        }

        /// Fix red-black properties after insert
        fn insertFixup(self: *Self, z_ptr: *RBNode(K, V)) void {
            var z = z_ptr;
            while (z.parent) |zp| {
                if (zp.color != .RED) break;

                const zpp = zp.parent orelse break;

                if (zp == zpp.left) {
                    const y = zpp.right;

                    if (y != null and y.?.color == .RED) {
                        zp.color = .BLACK;
                        y.?.color = .BLACK;
                        zpp.color = .RED;
                        z = zpp;
                    } else {
                        if (z == zp.right) {
                            z = zp;
                            self.leftRotate(z);
                        }

                        if (z.parent) |zp2| {
                            zp2.color = .BLACK;
                        }
                        if (z.parent) |zp2| {
                            if (zp2.parent) |zpp2| {
                                zpp2.color = .RED;
                                self.rightRotate(zpp2);
                            }
                        }
                    }
                } else {
                    // Mirror case
                    const y = zpp.left;

                    if (y != null and y.?.color == .RED) {
                        zp.color = .BLACK;
                        y.?.color = .BLACK;
                        zpp.color = .RED;
                        z = zpp;
                    } else {
                        if (z == zp.left) {
                            z = zp;
                            self.rightRotate(z);
                        }

                        if (z.parent) |zp2| {
                            zp2.color = .BLACK;
                        }
                        if (z.parent) |zp2| {
                            if (zp2.parent) |zpp2| {
                                zpp2.color = .RED;
                                self.leftRotate(zpp2);
                            }
                        }
                    }
                }
            }

            if (self.root) |r| {
                r.color = .BLACK;
            }
        }

        /// Look up value by key
        pub fn find(self: *const Self, key: K) ?V {
            var current = self.root;

            while (current != null) {
                if (key == current.?.key) {
                    return current.?.value;
                } else if (key < current.?.key) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            return null;
        }

        /// Delete key (simplified - doesn't rebalance)
        pub fn delete(self: *Self, key: K) bool {
            var current = self.root;
            var parent: ?*RBNode(K, V) = null;

            while (current != null) {
                if (key == current.?.key) {
                    // Node found - simplified delete (no rebalancing)
                    const curr = current.?;
                    if (curr.left == null) {
                        self.transplant(curr, curr.right);
                    } else if (curr.right == null) {
                        self.transplant(curr, curr.left);
                    } else {
                        // Two children - find successor
                        var successor = curr.right;
                        while (successor.?.left != null) {
                            successor = successor.?.left;
                        }
                        self.transplant(curr, successor.?.right);
                        successor.?.left = curr.left;
                        if (curr.left) |l| {
                            l.parent = successor;
                        }
                    }

                    self.allocator.destroy(curr);
                    self.size -= 1;
                    return true;
                }

                parent = current;
                if (key < current.?.key) {
                    current = current.?.left;
                } else {
                    current = current.?.right;
                }
            }

            return false;
        }

        /// Replace subtree u with v
        fn transplant(self: *Self, u: *RBNode(K, V), v: ?*RBNode(K, V)) void {
            if (u.parent == null) {
                self.root = v;
            } else if (u == u.parent.?.left) {
                u.parent.?.left = v;
            } else {
                u.parent.?.right = v;
            }

            if (v != null) {
                v.?.parent = u.parent;
            }
        }
    };
}

test "rb tree init" {
    var tree = RBTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try std.testing.expectEqual(@as(usize, 0), tree.size);
}

test "rb tree insert find" {
    var tree = RBTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expectEqualStrings("five", tree.find(5).?);
    try std.testing.expectEqualStrings("three", tree.find(3).?);
    try std.testing.expect(tree.find(10) == null);
}

test "rb tree delete" {
    var tree = RBTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expect(tree.delete(5));
    try std.testing.expect(tree.find(5) == null);
    try std.testing.expectEqual(@as(usize, 2), tree.size);
}
