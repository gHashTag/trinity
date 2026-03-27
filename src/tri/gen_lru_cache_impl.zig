//! tri/lru_cache — LRU cache with HashMap + doubly-linked list
//! TTT Dogfood v0.2 Stage 196

const std = @import("std");

const LRUNode = struct {
    key: usize,
    value: i64,
    prev: ?*LRUNode,
    next: ?*LRUNode,
};

pub const LRUCache = struct {
    capacity: usize,
    map: std.AutoHashMap(usize, *LRUNode),
    list_head: *LRUNode,
    list_tail: *LRUNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !LRUCache {
        const head = try allocator.create(LRUNode);
        head.* = .{ .key = 0, .value = 0, .prev = null, .next = null };

        const tail = try allocator.create(LRUNode);
        tail.* = .{ .key = 0, .value = 0, .prev = null, .next = null };

        head.next = tail;
        tail.prev = head;

        var cache = LRUCache{
            .capacity = capacity,
            .map = std.AutoHashMap(usize, *LRUNode).init(allocator),
            .list_head = head,
            .list_tail = tail,
            .allocator = allocator,
        };
        return cache;
    }

    fn removeNode(_: *LRUCache, node: *LRUNode) void {
        if (node.prev) |p| p.next = node.next;
        if (node.next) |n| n.prev = node.prev;
    }

    fn moveToFront(cache: *LRUCache, node: *LRUNode) void {
        cache.removeNode(node);
        node.next = cache.list_head.next;
        node.prev = cache.list_head;
        if (cache.list_head.next) |n| n.prev = node;
        cache.list_head.next = node;
    }

    pub fn get(cache: *LRUCache, key: usize) ?i64 {
        if (cache.map.get(key)) |node| {
            const value = node.value;
            cache.moveToFront(node);
            return value;
        }
        return null;
    }

    pub fn put(cache: *LRUCache, key: usize, value: i64) !void {
        if (cache.map.get(key)) |node| {
            node.value = value;
            cache.moveToFront(node);
            return;
        }

        const node = try cache.allocator.create(LRUNode);
        node.* = .{
            .key = key,
            .value = value,
            .prev = cache.list_head,
            .next = cache.list_head.next,
        };

        if (cache.list_head.next) |n| n.prev = node;
        cache.list_head.next = node;
        try cache.map.put(key, node);

        if (cache.map.count() > cache.capacity) {
            const lru = cache.list_tail.prev.?;
            _ = cache.map.remove(lru.key);
            cache.removeNode(lru);
            cache.allocator.destroy(lru);
        }
    }

    pub fn deinit(cache: *LRUCache) void {
        var current_opt = cache.list_head.next;
        while (current_opt) |current| {
            if (current == cache.list_tail) break;
            const next_opt = current.next;
            cache.allocator.destroy(current);
            current_opt = next_opt;
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
    try cache.put(3, 300);

    try std.testing.expect(cache.get(1) == null);
    try std.testing.expectEqual(@as(i64, 200), cache.get(2).?);
}
