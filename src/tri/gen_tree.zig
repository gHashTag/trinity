//! tri/tree — Immutable binary tree
//! Auto-generated from specs/tri/tri_tree.tri
//! TTT Dogfood v0.2 Stage 81

const std = @import("std");

/// Binary tree node
pub fn TreeNode(comptime T: type) type {
    return struct {
        is_leaf: bool,
        value: T,
        left: ?*const TreeNode(T),
        right: ?*const TreeNode(T),

        const Self = @This();

        /// Create leaf node
        pub fn leaf(val: T) Self {
            return .{ .is_leaf = true, .value = val, .left = null, .right = null };
        }

        /// Create branch node
        pub fn branch(l: *const Self, r: *const Self) Self {
            return .{ .is_leaf = false, .value = undefined, .left = l, .right = r };
        }

        /// Check if is leaf
        pub fn isLeaf(self: Self) bool {
            return self.is_leaf;
        }

        /// Get tree height
        pub fn height(self: Self) usize {
            if (self.is_leaf) return 1;
            const left_h = if (self.left) |n| n.height() else 0;
            const right_h = if (self.right) |n| n.height() else 0;
            return 1 + @max(left_h, right_h);
        }

        /// Count nodes
        pub fn size(self: Self) usize {
            if (self.is_leaf) return 1;
            var count: usize = 1;
            if (self.left) |n| count += n.size();
            if (self.right) |n| count += n.size();
            return count;
        }

        /// In-order traversal
        pub fn inorder(self: Self, allocator: std.mem.Allocator) ![]T {
            var list = std.ArrayList(T).init(allocator);
            try self.inorderHelper(&list);
            return list.toOwnedSlice();
        }

        fn inorderHelper(self: Self, list: *std.ArrayList(T)) !void {
            if (self.left) |n| try n.inorderHelper(list);
            if (!self.is_leaf) return;
            try list.append(self.value);
            if (self.right) |n| try n.inorderHelper(list);
        }
    };
}

test "TreeNode.leaf" {
    const node = TreeNode(i32).leaf(42);
    try std.testing.expect(node.isLeaf());
    try std.testing.expectEqual(@as(i32, 42), node.value);
}

test "TreeNode.height" {
    const node1 = TreeNode(i32).leaf(1);
    const node2 = TreeNode(i32).leaf(2);
    const branch = TreeNode(i32).branch(&node1, &node2);

    try std.testing.expectEqual(@as(usize, 2), branch.height());
}

test "TreeNode.size" {
    const node1 = TreeNode(i32).leaf(1);
    const node2 = TreeNode(i32).leaf(2);
    const node3 = TreeNode(i32).leaf(3);
    const branch1 = TreeNode(i32).branch(&node1, &node2);
    const branch2 = TreeNode(i32).branch(&branch1, &node3);

    try std.testing.expectEqual(@as(usize, 5), branch2.size());
}
