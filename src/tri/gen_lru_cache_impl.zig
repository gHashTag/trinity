//! tri/lru_cache_impl — LRU cache implementation
//! Auto-generated from specs/tri_lru_cache_impl.tri
//! TTT Dogfood v0.2 Stage 196

const std = @import("std");

/// LRU cache node
const LRUNode = struct {
    key: usize,
    value: i64,
    prev: ?*LRUNode,
    next: ?*LRUNode,
};

/// LRU cache using HashMap + doubly-linked list
pub const LRUCache = struct {
    capacity: usize,
    map: std.AutoHashMap(usize, *LRUNode),
    list_head: *LRUNode,
    list_tail: *LRUNode,
    allocator: std.mem.Allocator,

    /// Create LRU cache
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !LRUCache {
        var cache = LRUCache{
            .capacity = capacity,
            .map = std.AutoHashMap(usize, *LRUNode).init(allocator),
            .list_head = undefined,
            .list_tail = undefined,
            .allocator = allocator,
        };

        // Create dummy head and tail nodes
        cache.list_head = try allocator.create(LRUNode);
        cache.list_head.* = .{ .key = 0, .value = 0, .prev = null, .next = null };

        cache.list_tail = try allocator.create(LRUNode);
        cache.list_tail.* = .{ .key = 0, .value = 0, .prev = null, .next = null };

        cache.list_head.next = cache.list_tail;
        cache.list_tail.prev = cache.list_head;

        return cache;
    }

    /// Remove node from list
    fn removeNode(cache: *LRUCache, node: *LRUNode) void {
        if (node.prev) |p| {
            p.next = node.next;
        }
        if (node.next) |n| {
            n.prev = node.prev;
        }
    }

    /// Move node to front (most recently used)
    fn moveToFront(cache: *LRUCache, node: *LRUNode) void {
        cache.removeNode(node);

        node.next = cache.list_head.next;
        node.prev = cache.list_head;

        if (cache.list_head.next) |n| {
            n.prev = node;
        }
        cache.list_head.next = node;
    }

    /// Get value, move to front
    pub fn get(cache: *LRUCache, key: usize) ?i64 {
        if (cache.map.get(key)) |node| {
            const value = node.value;
            cache.moveToFront(node);
            return value;
        }
        return null;
    }

    /// Insert, evict LRU if full
    pub fn put(cache: *LRUCache, key: usize, value: i64) !void {
        if (cache.map.get(key)) |node| {
            node.value = value;
            cache.moveToFront(node);
            return;
        }

        // Create new node
        const node = try cache.allocator.create(LRUNode);
        node.* = .{
            .key = key,
            .value = value,
            .prev = cache.list_head,
            .next = cache.list_head.next,
        };

        if (cache.list_head.next) |n| {
            n.prev = node;
        }
        cache.list_head.next = node;

        try cache.map.put(key, node);

        // Evict if full
        if (cache.map.count() > cache.capacity) {
            // LRU is at tail
            const lru = cache.list_tail.prev.?;

            _ = cache.map.remove(lru.key);
            cache.removeNode(lru);
            cache.allocator.destroy(lru);
        }
    }

    /// Free cache
    pub fn deinit(cache: *LRUCache) void {
        var current = cache.list_head.next;
        while (current != cache.list_tail) {
            const next = current.next.?;
            cache.allocator.destroy(current);
            current = next;
        }

        cache.allocator.destroy(cache.list_head);
        cache.allocator.destroy(cache.list_tail);
        cache.map.deinit();
    }
};

test "lru cache put get" {
    var cache = try LRUCache.init(std.testing.allocator, 3);
    defer cache.deinit();

    try cache.put(1, 100);
    try cache.put(2, 200);
    try cache.put(3, 300);

    try std.testing.expectEqual(@as(i64, 200), cache.get(2).?);
    try std.testing.expect(cache.get(99) == null);
}

test "lru cache eviction" {
    var cache = try LRUCache.init(std.testing.allocator, 2);
    defer cache.deinit();

    try cache.put(1, 100);
    try cache.put(2, 200);
    try cache.put(3, 300); // Evicts key 1

    try std.testing.expect(cache.get(1) == null);
    try std.testing.expectEqual(@as(i64, 200), cache.get(2).?);
    try std.testing.expectEqual(@as(i64, 300), cache.get(3).?);
}
