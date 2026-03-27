//! tri/trie — Prefix tree for string keys
//! Auto-generated from specs/tri/tri_trie.tri
//! TTT Dogfood v0.2 Stage 93

const std = @import("std");

/// Trie node with children
pub fn TrieNode(comptime V: type) type {
    return struct {
        is_end: bool = false,
        value: V,
        children: std.HashMap(u8, *TrieNode(V), std.hash_map.AutoContext(u8), 80),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .value = undefined,
                .children = std.HashMap(u8, *TrieNode(V), std.hash_map.AutoContext(u8), 80).init(allocator),
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            var iter = self.children.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.*.deinit(allocator);
                allocator.destroy(entry.value_ptr.*);
            }
            self.children.deinit();
        }
    };
}

/// Prefix tree root
pub fn Trie(comptime V: type) type {
    return struct {
        root: *TrieNode(V),
        size: usize = 0,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create empty trie
        pub fn init(allocator: std.mem.Allocator) !Self {
            const node = try allocator.create(TrieNode(V));
            node.* = TrieNode(V).init(allocator);
            return .{ .root = node, .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
            self.allocator.destroy(self.root);
        }

        /// Insert key-value pair
        pub fn insert(self: *Self, key: []const u8, value: V) !void {
            var current = self.root;
            for (key) |c| {
                const entry = try current.children.getOrPut(c);
                if (!entry.found_existing) {
                    const node = try self.allocator.create(TrieNode(V));
                    node.* = TrieNode(V).init(self.allocator);
                    entry.value_ptr.* = node;
                }
                current = entry.value_ptr.*;
            }
            current.is_end = true;
            current.value = value;
        }

        /// Lookup by exact key
        pub fn get(self: *const Self, key: []const u8) ?V {
            var current = self.root;
            for (key) |c| {
                if (current.children.get(c)) |node| {
                    current = node;
                } else return null;
            }
            if (!current.is_end) return null;
            return current.value;
        }

        /// Check if any key has prefix
        pub fn hasPrefix(self: *const Self, prefix: []const u8) bool {
            var current = self.root;
            for (prefix) |c| {
                if (current.children.get(c)) |node| {
                    current = node;
                } else return false;
            }
            return true;
        }

        /// Delete key, true if existed
        pub fn remove(self: *Self, key: []const u8) bool {
            // Simplified: mark as not end, don't prune nodes
            var current = self.root;
            for (key) |c| {
                if (current.children.get(c)) |node| {
                    current = node;
                } else return false;
            }
            if (!current.is_end) return false;
            current.is_end = false;
            self.size -= 1;
            return true;
        }
    };
}

test "Trie.insert" {
    var trie = try Trie(i32).init(std.testing.allocator);
    defer trie.deinit();
    try trie.insert("hello", 42);
    try std.testing.expectEqual(@as(i32, 42), trie.get("hello").?);
}

test "Trie.get" {
    var trie = try Trie(i32).init(std.testing.allocator);
    defer trie.deinit();
    try trie.insert("test", 100);
    try std.testing.expect(trie.get("test") != null);
    try std.testing.expect(trie.get("missing") == null);
}

test "Trie.hasPrefix" {
    var trie = try Trie(i32).init(std.testing.allocator);
    defer trie.deinit();
    try trie.insert("hello", 1);
    try trie.insert("hello world", 2);
    try std.testing.expect(trie.hasPrefix("hell"));
    try std.testing.expect(!trie.hasPrefix("xyz"));
}
