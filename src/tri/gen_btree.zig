//! tri/btree — B-tree index
//! TTT Dogfood v0.2 Stage 292

const std = @import("std");

pub const BTree = struct {
    root: ?*Node,
    allocator: std.mem.Allocator,

    const Node = struct {
        keys: std.ArrayList(i32),
        children: std.ArrayList(?*Node),
        is_leaf: bool,
    };

    pub fn init(allocator: std.mem.Allocator) BTree {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *BTree, key: i32) !void {
        _ = tree;
        _ = key;
    }

    pub fn search(tree: *const BTree, key: i32) bool {
        _ = tree;
        _ = key;
        return false;
    }
};

test "btree" {
    var tree = BTree.init(std.testing.allocator);
    _ = try tree.insert(42);
    _ = tree;
}
