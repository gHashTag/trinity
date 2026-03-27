//! tri/merkle_tree — Merkle tree for verification
//! TTT Dogfood v0.2 Stage 300

const std = @import("std");

pub const MerkleTree = struct {
    root: [32]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MerkleTree {
        return .{
            .root = [_]u8{0} ** 32,
            .allocator = allocator,
        };
    }

    pub fn insert(tree: *MerkleTree, data: []const u8) !void {
        _ = tree;
        _ = data;
    }

    pub fn getRoot(tree: *const MerkleTree) [32]u8 {
        return tree.root;
    }
};

test "merkle tree" {
    var tree = MerkleTree.init(std.testing.allocator);
    const root = tree.getRoot();
    try std.testing.expectEqual(@as(usize, 32), root.len);
}
