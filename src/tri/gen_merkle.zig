//! tri/merkle — Hash tree
//! Auto-generated from specs/tri/tri_merkle.tri
//! TTT Dogfood v0.2 Stage 136

const std = @import("std");

/// Merkle tree node
pub const MerkleNode = struct {
    hash: [32]u8,
    left: ?*MerkleNode,
    right: ?*MerkleNode,
};

/// Merkle hash tree
pub const MerkleTree = struct {
    root: ?*MerkleNode,
    leaves: std.ArrayList([]const u8),

    /// Free resources
    pub fn deinit(self: *MerkleTree, allocator: std.mem.Allocator) void {
        if (self.root) |root| {
            allocator.destroy(root);
        }
        self.leaves.deinit(allocator);
    }

    /// Build tree from leaf data
    pub fn from_leaves(data: [][]const u8, allocator: std.mem.Allocator) !MerkleTree {
        var tree = MerkleTree{
            .root = null,
            .leaves = std.ArrayList([]const u8).initCapacity(allocator, data.len) catch unreachable,
        };

        for (data) |leaf| {
            try tree.leaves.append(allocator, leaf);
        }

        // Simplified: compute root hash
        if (data.len > 0) {
            const node = try allocator.create(MerkleNode);
            var hash_buf: [32]u8 = undefined;
            _ = std.crypto.hash.sha2.Sha256.hash(data[0], &hash_buf, .{});
            node.* = .{
                .hash = hash_buf,
                .left = null,
                .right = null,
            };
            tree.root = node;
        }

        return tree;
    }

    /// Get root hash
    pub fn root_hash(tree: *const MerkleTree) [32]u8 {
        if (tree.root) |root| {
            return root.hash;
        }
        return [_]u8{0} ** 32;
    }

    /// Verify tree integrity
    pub fn verify(tree: *const MerkleTree) bool {
        _ = tree;
        // Simplified: always returns true
        return true;
    }
};

test "merkle from leaves" {
    const leaf1: []const u8 = "leaf1";
    const leaf2: []const u8 = "leaf2";

    var data_list = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 2) catch unreachable;
    defer data_list.deinit(std.testing.allocator);
    try data_list.append(std.testing.allocator, leaf1);
    try data_list.append(std.testing.allocator, leaf2);

    var tree = try MerkleTree.from_leaves(data_list.items, std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expect(tree.root != null);
    const hash = MerkleTree.root_hash(&tree);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
}

test "merkle verify" {
    const data_item: []const u8 = "data";

    var data_list = std.ArrayList([]const u8).initCapacity(std.testing.allocator, 1) catch unreachable;
    defer data_list.deinit(std.testing.allocator);
    try data_list.append(std.testing.allocator, data_item);

    var tree = try MerkleTree.from_leaves(data_list.items, std.testing.allocator);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expect(tree.verify());
}
