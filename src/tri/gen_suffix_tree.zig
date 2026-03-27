//! tri/suffix_tree — Compressed suffix tree for strings
//! TTT Dogfood v0.2 Stage 207

const std = @import("std");

pub const SuffixNode = struct {
    children: std.AutoHashMap(u8, *SuffixNode),
    suffix_index: ?usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*SuffixNode {
        const node = try allocator.create(SuffixNode);
        node.* = .{
            .children = std.AutoHashMap(u8, *SuffixNode).init(allocator),
            .suffix_index = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(node: *SuffixNode) void {
        var iter = node.children.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            node.allocator.destroy(entry.value_ptr.*);
        }
        node.children.deinit();
    }
};

pub const SuffixTree = struct {
    root: *SuffixNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !SuffixTree {
        return .{
            .root = try SuffixNode.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn build(tree: *SuffixTree, text: []const u8) !void {
        for (0..text.len) |i| {
            try tree.insertSuffix(text[i..], i);
        }
    }

    fn insertSuffix(tree: *SuffixTree, suffix: []const u8, index: usize) !void {
        var node = tree.root;
        for (suffix) |c| {
            const result = try node.children.getOrPut(c);
            if (!result.found_existing) {
                result.value_ptr.* = try SuffixNode.init(tree.allocator);
            }
            node = result.value_ptr.*;
        }
        node.suffix_index = index;
    }

    pub fn search(tree: *const SuffixTree, pattern: []const u8) bool {
        var node = tree.root;
        for (pattern) |c| {
            if (node.children.get(c)) |child| {
                node = child;
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn deinit(tree: *SuffixTree) void {
        tree.root.deinit();
        tree.allocator.destroy(tree.root);
    }
};

test "suffix tree build search" {
    var tree = try SuffixTree.init(std.testing.allocator);
    defer tree.deinit();

    try tree.build("banana");

    try std.testing.expect(tree.search("ana"));
    try std.testing.expect(tree.search("nan"));
    try std.testing.expect(!tree.search("xyz"));
}
