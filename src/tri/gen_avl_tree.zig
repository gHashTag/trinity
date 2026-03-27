//! tri/avl_tree — AVL tree (height-balanced BST)
//! Auto-generated from specs/tri/tri_avl_tree.tri
//! TTT Dogfood v0.2 Stage 149

const std = @import("std");

/// AVL tree node
pub fn AVLNode(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,
        height: i32 = 1,
        left: ?*AVLNode(K, V),
        right: ?*AVLNode(K, V),
    };
}

/// AVL tree
pub fn AVLTree(comptime K: type, comptime V: type) type {
    return struct {
        root: ?*AVLNode(K, V),
        size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty AVL tree
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
        fn destroyNode(self: *Self, node: *AVLNode(K, V)) void {
            if (node.left) |l| self.destroyNode(l);
            if (node.right) |r| self.destroyNode(r);
            self.allocator.destroy(node);
        }

        /// Get node height
        fn height(node: ?*AVLNode(K, V)) i32 {
            if (node == null) return 0;
            return node.?.height;
        }

        /// Get balance factor
        fn getBalance(node: ?*AVLNode(K, V)) i32 {
            if (node == null) return 0;
            return height(node.?.left) - height(node.?.right);
        }

        /// Update node height
        fn updateHeight(node: *AVLNode(K, V)) void {
            const left_h = height(node.left);
            const right_h = height(node.right);
            node.height = @max(left_h, right_h) + 1;
        }

        /// Right rotate
        fn rightRotate(y: *AVLNode(K, V)) *AVLNode(K, V) {
            const x = y.left orelse return y;
            const T2 = x.right;

            x.right = y;
            y.left = T2;

            updateHeight(y);
            updateHeight(x);

            return x;
        }

        /// Left rotate
        fn leftRotate(x: *AVLNode(K, V)) *AVLNode(K, V) {
            const y = x.right orelse return x;
            const T2 = y.left;

            y.left = x;
            x.right = T2;

            updateHeight(x);
            updateHeight(y);

            return y;
        }

        /// Insert key-value pair
        pub fn insert(self: *Self, key: K, value: V) !void {
            self.root = try self.insertNode(self.root, key, value);
            self.size += 1;
        }

        /// Recursive insert
        fn insertNode(self: *Self, node: ?*AVLNode(K, V), key: K, value: V) !*AVLNode(K, V) {
            if (node == null) {
                const new_node = try self.allocator.create(AVLNode(K, V));
                new_node.* = .{
                    .key = key,
                    .value = value,
                    .height = 1,
                    .left = null,
                    .right = null,
                };
                return new_node;
            }

            if (key < node.?.key) {
                node.?.left = try self.insertNode(node.?.left, key, value);
            } else if (key > node.?.key) {
                node.?.right = try self.insertNode(node.?.right, key, value);
            } else {
                // Key exists - update value
                node.?.value = value;
                return node.?;
            }

            updateHeight(node.?);

            const balance = getBalance(node);

            // Left Left
            if (balance > 1 and key < node.?.left.?.key) {
                return rightRotate(node.?);
            }

            // Right Right
            if (balance < -1 and key > node.?.right.?.key) {
                return leftRotate(node.?);
            }

            // Left Right
            if (balance > 1 and key > node.?.left.?.key) {
                node.?.left = leftRotate(node.?.left.?);
                return rightRotate(node.?);
            }

            // Right Left
            if (balance < -1 and key < node.?.right.?.key) {
                node.?.right = rightRotate(node.?.right.?);
                return leftRotate(node.?);
            }

            return node.?;
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

        /// Delete key
        pub fn delete(self: *Self, key: K) bool {
            if (self.find(key) == null) return false;

            self.root = self.deleteNode(self.root, key);
            self.size -= 1;
            return true;
        }

        /// Recursive delete
        fn deleteNode(self: *Self, node: ?*AVLNode(K, V), key: K) ?*AVLNode(K, V) {
            if (node == null) return null;

            if (key < node.?.key) {
                node.?.left = self.deleteNode(node.?.left, key);
            } else if (key > node.?.key) {
                node.?.right = self.deleteNode(node.?.right, key);
            } else {
                // Found node to delete
                if (node.?.left == null or node.?.right == null) {
                    const temp = if (node.?.left != null) node.?.left else node.?.right;

                    if (temp == null) {
                        self.allocator.destroy(node.?);
                        return null;
                    } else {
                        // Copy temp data
                        node.?.key = temp.?.key;
                        node.?.value = temp.?.value;
                        node.?.left = null;
                        node.?.right = null;
                        self.allocator.destroy(temp.?);
                    }
                } else {
                    // Two children - get inorder successor
                    var temp = node.?.right;
                    while (temp.?.left != null) {
                        temp = temp.?.left;
                    }

                    node.?.key = temp.?.key;
                    node.?.value = temp.?.value;
                    node.?.right = self.deleteNode(node.?.right, temp.?.key);
                }
            }

            if (node == null) return null;

            updateHeight(node.?);

            const balance = getBalance(node);

            // Rebalance if needed
            if (balance > 1 and getBalance(node.?.left) >= 0) {
                return rightRotate(node.?);
            }
            if (balance > 1 and getBalance(node.?.left) < 0) {
                node.?.left = leftRotate(node.?.left.?);
                return rightRotate(node.?);
            }
            if (balance < -1 and getBalance(node.?.right) <= 0) {
                return leftRotate(node.?);
            }
            if (balance < -1 and getBalance(node.?.right) > 0) {
                node.?.right = rightRotate(node.?.right.?);
                return leftRotate(node.?);
            }

            return node;
        }
    };
}

test "avl tree init" {
    var tree = AVLTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try std.testing.expectEqual(@as(usize, 0), tree.size);
}

test "avl tree insert find" {
    var tree = AVLTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expectEqualStrings("five", tree.find(5).?);
    try std.testing.expectEqualStrings("three", tree.find(3).?);
}

test "avl tree delete" {
    var tree = AVLTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert(5, "five");
    try tree.insert(3, "three");
    try tree.insert(7, "seven");

    try std.testing.expect(tree.delete(5));
    try std.testing.expect(tree.find(5) == null);
    try std.testing.expectEqual(@as(usize, 2), tree.size);
}

test "avl tree balancing" {
    var tree = AVLTree(i32, []const u8).init(std.testing.allocator);
    defer tree.deinit();

    // Insert in ascending order - should trigger rotations
    try tree.insert(1, "one");
    try tree.insert(2, "two");
    try tree.insert(3, "three");
    try tree.insert(4, "four");
    try tree.insert(5, "five");

    // All values should be findable
    try std.testing.expect(tree.find(1) != null);
    try std.testing.expect(tree.find(5) != null);
}
