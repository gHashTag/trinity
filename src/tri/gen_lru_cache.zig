//! tri/lru_cache — Least recently used cache
//! Auto-generated from specs/tri/tri_lru_cache.tri
//! TTT Dogfood v0.2 Stage 142

const std = @import("std");

/// LRU cache node
pub fn LRUNode(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,
        prev: ?*LRUNode(K, V),
        next: ?*LRUNode(K, V),
    };
}

/// LRU cache
pub fn LRUCache(comptime K: type, comptime V: type) type {
    return struct {
        capacity: usize,
        size: usize,
        head: ?*LRUNode(K, V),
        tail: ?*LRUNode(K, V),
        map: std.AutoHashMap(K, *LRUNode(K, V)),
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create LRU cache
        pub fn init(capacity: usize, allocator: std.mem.Allocator) Self {
            return .{
                .capacity = capacity,
                .size = 0,
                .head = null,
                .tail = null,
                .map = std.AutoHashMap(K, *LRUNode(K, V)).init(allocator),
                .allocator = allocator,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                current = next;
            }
            self.map.deinit();
        }

        /// Move node to front (most recently used)
        fn moveToFront(self: *Self, node: *LRUNode(K, V)) void {
            if (node == self.head) return;

            // Remove from current position
            if (node.prev) |prev| {
                prev.next = node.next;
            }
            if (node.next) |next| {
                next.prev = node.prev;
            }
            if (node == self.tail) {
                self.tail = node.prev;
            }

            // Insert at front
            node.prev = null;
            node.next = self.head;
            if (self.head) |h| {
                h.prev = node;
            }
            self.head = node;

            if (self.tail == null) {
                self.tail = node;
            }
        }

        /// Remove and return LRU node
        fn removeLRU(self: *Self) ?*LRUNode(K, V) {
            const lru = self.tail orelse return null;

            if (lru.prev) |prev| {
                prev.next = null;
            }
            self.tail = lru.prev;

            if (self.head == lru) {
                self.head = null;
            }

            return lru;
        }

        /// Get value and move to front
        pub fn get(self: *Self, key: K) ?V {
            if (self.map.get(key)) |node| {
                self.moveToFront(node);
                return node.value;
            }
            return null;
        }

        /// Insert key-value pair
        pub fn put(self: *Self, key: K, value: V) !void {
            // If key exists, update and move to front
            if (self.map.get(key)) |node| {
                node.value = value;
                self.moveToFront(node);
                return;
            }

            // Create new node
            const node = try self.allocator.create(LRUNode(K, V));
            node.* = .{
                .key = key,
                .value = value,
                .prev = null,
                .next = self.head,
            };

            try self.map.put(key, node);

            if (self.head) |h| {
                h.prev = node;
            }
            self.head = node;

            if (self.tail == null) {
                self.tail = node;
            }

            self.size += 1;

            // Evict if over capacity
            if (self.size > self.capacity) {
                if (self.removeLRU()) |lru| {
                    _ = self.map.remove(lru.key);
                    self.allocator.destroy(lru);
                    self.size -= 1;
                }
            }
        }
    };
}

test "lru cache init" {
    var cache = LRUCache(u32, []const u8).init(2, std.testing.allocator);
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 2), cache.capacity);
}

test "lru cache put get" {
    var cache = LRUCache(u32, []const u8).init(2, std.testing.allocator);
    defer cache.deinit();

    try cache.put(1, "one");
    try std.testing.expectEqualStrings("one", cache.get(1).?);

    try cache.put(2, "two");
    try std.testing.expectEqualStrings("two", cache.get(2).?);
}

test "lru cache eviction" {
    var cache = LRUCache(u32, []const u8).init(2, std.testing.allocator);
    defer cache.deinit();

    try cache.put(1, "one");
    try cache.put(2, "two");
    try cache.put(3, "three"); // Evicts key 1 (LRU)

    try std.testing.expect(cache.get(1) == null); // Evicted
    try std.testing.expect(cache.get(2) != null);
    try std.testing.expect(cache.get(3) != null);
}
