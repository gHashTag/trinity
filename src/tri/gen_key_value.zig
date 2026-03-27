//! tri/key_value — Simple key-value store
//! TTT Dogfood v0.2 Stage 291

const std = @import("std");

pub const KeyValueStore = struct {
    map: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !KeyValueStore {
        return .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn put(store: *KeyValueStore, key: []const u8, value: []const u8) !void {
        const key_copy = try store.allocator.dupe(u8, key);
        const value_copy = try store.allocator.dupe(u8, value);
        try store.map.put(key_copy, value_copy);
    }

    pub fn get(store: *const KeyValueStore, key: []const u8) ?[]const u8 {
        return store.map.get(key);
    }

    pub fn remove(store: *KeyValueStore, key: []const u8) bool {
        return store.map.remove(key);
    }

    pub fn deinit(store: *KeyValueStore) void {
        var iter = store.map.iterator();
        while (iter.next()) |entry| {
            store.allocator.free(entry.key_ptr.*);
            store.allocator.free(entry.value_ptr.*);
        }
        store.map.deinit();
    }
};

test "key value" {
    var store = try KeyValueStore.init(std.testing.allocator);
    defer store.deinit();
    try store.put("foo", "bar");
    try std.testing.expectEqualStrings("bar", store.get("foo").?);
}
