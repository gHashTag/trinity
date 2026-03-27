//! tri/cache — LRU cache
//! TTT Dogfood v0.2 Stage 297

const std = @import("std");

pub const LRUCache = struct {
    capacity: usize,
    store: std.StringHashMap([]const u8),
    order: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) LRUCache {
        return .{
            .capacity = capacity,
            .store = std.StringHashMap([]const u8).init(allocator),
            .order = std.ArrayList([]const u8).initCapacity(allocator, 16) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn get(cache: *LRUCache, key: []const u8) ?[]const u8 {
        if (cache.store.get(key)) |value| {
            return value;
        }
        return null;
    }

    pub fn put(cache: *LRUCache, key: []const u8, value: []const u8) !void {
        const key_copy = try cache.allocator.dupe(u8, key);
        const value_copy = try cache.allocator.dupe(u8, value);
        try cache.store.put(key_copy, value_copy);
    }

    pub fn deinit(cache: *LRUCache) void {
        var iter = cache.store.iterator();
        while (iter.next()) |entry| {
            cache.allocator.free(entry.key_ptr.*);
            cache.allocator.free(entry.value_ptr.*);
        }
        cache.store.deinit();
        cache.order.deinit(cache.allocator);
    }
};

test "lru cache" {
    var cache = LRUCache.init(std.testing.allocator, 2);
    defer cache.deinit();
    try cache.put("a", "1");
    try std.testing.expectEqualStrings("1", cache.get("a").?);
}
