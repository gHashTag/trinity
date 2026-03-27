//! tri/trie — Prefix tree for strings
//! TTT Dogfood v0.2 Stage 206

const std = @import("std");

pub const TrieNode = struct {
    children: std.AutoHashMap(u8, *TrieNode),
    is_end: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*TrieNode {
        const node = try allocator.create(TrieNode);
        node.* = .{
            .children = std.AutoHashMap(u8, *TrieNode).init(allocator),
            .is_end = false,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(node: *TrieNode) void {
        var iter = node.children.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            node.allocator.destroy(entry.value_ptr.*);
        }
        node.children.deinit();
    }
};

pub const Trie = struct {
    root: *TrieNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Trie {
        const root = try TrieNode.init(allocator);
        return .{
            .root = root,
            .allocator = allocator,
        };
    }

    pub fn insert(trie: *Trie, word: []const u8) !void {
        var node = trie.root;
        for (word) |c| {
            const result = try node.children.getOrPut(c);
            if (!result.found_existing) {
                result.value_ptr.* = try TrieNode.init(trie.allocator);
            }
            node = result.value_ptr.*;
        }
        node.is_end = true;
    }

    pub fn contains(trie: *const Trie, word: []const u8) bool {
        var node = trie.root;
        for (word) |c| {
            if (node.children.get(c)) |child| {
                node = child;
            } else {
                return false;
            }
        }
        return node.is_end;
    }

    pub fn hasPrefix(trie: *const Trie, prefix: []const u8) bool {
        var node = trie.root;
        for (prefix) |c| {
            if (node.children.get(c)) |child| {
                node = child;
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn deinit(trie: *Trie) void {
        trie.root.deinit();
        trie.allocator.destroy(trie.root);
    }
};

test "trie insert contains" {
    var trie = try Trie.init(std.testing.allocator);
    defer trie.deinit();

    try trie.insert("hello");
    try trie.insert("world");

    try std.testing.expect(trie.contains("hello"));
    try std.testing.expect(!trie.contains("hell"));
}

test "trie has prefix" {
    var trie = try Trie.init(std.testing.allocator);
    defer trie.deinit();

    try trie.insert("hello");
    try trie.insert("hey");

    try std.testing.expect(trie.hasPrefix("he"));
    try std.testing.expect(!trie.hasPrefix("hi"));
}
