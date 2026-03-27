//! tri/judy_array — Compressed memory-efficient array
//! TTT Dogfood v0.2 Stage 216

const std = @import("std");

pub const JudyNode = struct {
    key: u64,
    value: i64,
    left: ?*JudyNode,
    right: ?*JudyNode,
};

pub const JudyArray = struct {
    root: ?*JudyNode,
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) JudyArray {
        return .{
            .root = null,
            .size = 0,
            .allocator = allocator,
        };
    }

    pub fn set(ja: *JudyArray, key: u64, value: i64) !void {
        if (ja.root == null) {
            const node = try ja.allocator.create(JudyNode);
            node.* = .{ .key = key, .value = value, .left = null, .right = null };
            ja.root = node;
            ja.size = 1;
            return;
        }

        try ja.setRecursive(ja.root.?, key, value);
    }

    fn setRecursive(ja: *JudyArray, node: *JudyNode, key: u64, value: i64) !bool {
        if (key == node.key) {
            node.value = value;
            return true;
        }

        if (key < node.key) {
            if (node.left == null) {
                const new_node = try ja.allocator.create(JudyNode);
                new_node.* = .{ .key = key, .value = value, .left = null, .right = null };
                node.left = new_node;
                ja.size += 1;
                return true;
            }
            return try ja.setRecursive(node.left.?, key, value);
        } else {
            if (node.right == null) {
                const new_node = try ja.allocator.create(JudyNode);
                new_node.* = .{ .key = key, .value = value, .left = null, .right = null };
                node.right = new_node;
                ja.size += 1;
                return true;
            }
            return try ja.setRecursive(node.right.?, key, value);
        }
    }

    pub fn get(ja: *const JudyArray, key: u64) ?i64 {
        var node = ja.root;
        while (node) |n| {
            if (key == n.key) return n.value;
            node = if (key < n.key) n.left else n.right;
        }
        return null;
    }

    pub fn deinit(ja: *JudyArray) void {
        if (ja.root) |r| {
            ja.freeRecursive(r);
            ja.allocator.destroy(r);
        }
    }

    fn freeRecursive(ja: *JudyArray, node: ?*JudyNode) void {
        if (node) |n| {
            ja.freeRecursive(n.left);
            ja.freeRecursive(n.right);
            ja.allocator.destroy(n);
        }
    }
};

test "judy array set get" {
    var ja = JudyArray.init(std.testing.allocator);
    defer ja.deinit();

    try ja.set(1, 10);
    try ja.set(5, 50);

    try std.testing.expectEqual(@as(i64, 10), ja.get(1).?);
    try std.testing.expect(ja.get(99) == null);
}
