//! tri/bk_tree — Burkhard-Keller tree for edit distance
//! TTT Dogfood v0.2 Stage 215

const std = @import("std");

pub const BKNode = struct {
    word: []const u8,
    children: std.AutoHashMap(usize, *BKNode),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, word: []const u8) !*BKNode {
        const node = try allocator.create(BKNode);
        node.* = .{
            .word = word,
            .children = std.AutoHashMap(usize, *BKNode).init(allocator),
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(node: *BKNode) void {
        var iter = node.children.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            node.allocator.destroy(entry.value_ptr.*);
        }
        node.children.deinit();
    }
};

pub const BKTree = struct {
    root: ?*BKNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BKTree {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    fn editDistance(a: []const u8, b: []const u8) usize {
        if (a.len == 0) return b.len;
        if (b.len == 0) return a.len;
        if (a[0] == b[0]) return editDistance(a[1..], b[1..]);
        return 1 + @min(
            editDistance(a[1..], b),
            @min(editDistance(a, b[1..]), editDistance(a[1..], b)),
        );
    }

    pub fn insert(tree: *BKTree, word: []const u8) !void {
        const node = try BKNode.init(tree.allocator, word);

        if (tree.root == null) {
            tree.root = node;
            return;
        }

        _ = try tree.insertRecursive(tree.root.?, node);
    }

    fn insertRecursive(tree: *BKTree, parent: *BKNode, node: *BKNode) !bool {
        const dist = editDistance(parent.word, node.word);

        const result = try parent.children.getOrPut(dist);
        if (!result.found_existing) {
            result.value_ptr.* = node;
            return true;
        }

        _ = try tree.insertRecursive(result.value_ptr.*, node);
        return false;
    }

    pub fn find(tree: *BKTree, word: []const u8, max_dist: usize) !std.ArrayList([]const u8) {
        var results = try std.ArrayList([]const u8).initCapacity(tree.allocator, 4);
        if (tree.root) |r| {
            try tree.findRecursive(r, word, max_dist, &results);
        }
        return results;
    }

    fn findRecursive(tree: *BKTree, node: *BKNode, word: []const u8, max_dist: usize, results: *std.ArrayList([]const u8)) !void {
        const dist = editDistance(node.word, word);

        if (dist <= max_dist) {
            try results.append(tree.allocator, node.word);
        }

        var iter = node.children.iterator();
        while (iter.next()) |entry| {
            const child_dist = entry.key_ptr.*;
            if (child_dist > dist - max_dist and child_dist < dist + max_dist) {
                try tree.findRecursive(entry.value_ptr.*, word, max_dist, results);
            }
        }
    }

    pub fn deinit(tree: *BKTree) void {
        if (tree.root) |r| {
            r.deinit();
            tree.allocator.destroy(r);
        }
    }
};

test "bk tree insert find" {
    var tree = BKTree.init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert("hello");
    try tree.insert("hell");
    try tree.insert("help");

    const results = try tree.find("helo", 2);
    defer results.deinit(tree.allocator);

    try std.testing.expect(results.items.len > 0);
}
