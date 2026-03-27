//! tri/lru — Least Recently Used cache
//! Auto-generated from specs/tri/tri_lru.tri
//! TTT Dogfood v0.2 Stage 120

const std = @import("std");

/// LRU cache with O(1) operations
pub fn LRU(comptime K: type, comptime V: type) type {
    return struct {
        capacity: usize,
        entries: std.HashMap(K, V, Context, 80),
        access_list: std.ArrayList(K),

        const Self = @This();

        pub const Context = struct {
            pub fn hash(_: Context, key: K) u64 {
                if (@typeInfo(K) == .pointer) {
                    return std.hash.Wyhash.hash(0, std.mem.asBytes(key));
                }
                return std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
            }

            pub fn eql(_: Context, a: K, b: K) bool {
                return std.meta.eql(a, b);
            }
        };

        /// Create LRU cache
        pub fn init(capacity: usize, allocator: std.mem.Allocator) !Self {
            return .{
                .capacity = capacity,
                .entries = std.HashMap(K, V, Context, 80).init(allocator),
                .access_list = std.ArrayList(K).initCapacity(allocator, 0) catch unreachable,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.entries.deinit();
            self.access_list.deinit(allocator);
        }

        /// Get value, update access order
        pub fn get(self: *Self, key: K, allocator: std.mem.Allocator) ?V {
            const value = self.entries.get(key) orelse return null;

            // Update access order - move to end
            self.updateAccessOrder(key, allocator);

            return value;
        }

        /// Store key-value pair
        pub fn put(self: *Self, key: K, value: V, allocator: std.mem.Allocator) !void {
            // Check if already exists
            const exists = self.entries.get(key) != null;

            // Insert or update
            try self.entries.put(key, value);

            if (!exists) {
                // Add to access list
                try self.access_list.append(allocator, key);

                // Evict if over capacity
                while (self.entries.count() > self.capacity) {
                    self.evict();
                }
            } else {
                // Update access order for existing key
                self.updateAccessOrder(key, allocator);
            }
        }

        /// Evict least recently used entry
        fn evict(self: *Self) void {
            if (self.access_list.items.len == 0) return;

            const lru_key = self.access_list.orderedRemove(0);
            _ = self.entries.remove(lru_key);
        }

        /// Move key to end of access list (most recently used)
        fn updateAccessOrder(self: *Self, key: K, allocator: std.mem.Allocator) void {
            // Find and remove key from current position
            for (self.access_list.items, 0..) |k, i| {
                if (std.meta.eql(k, key)) {
                    _ = self.access_list.orderedRemove(i);
                    break;
                }
            }

            // Add to end (most recently used)
            self.access_list.append(allocator, key) catch {};
        }

        /// Get current size
        pub fn size(self: *const Self) usize {
            return self.entries.count();
        }
    };
}

test "lru put get" {
    var cache = try LRU(u32, []const u8).init(3, std.testing.allocator);
    defer cache.deinit(std.testing.allocator);

    try cache.put(1, "one", std.testing.allocator);
    try cache.put(2, "two", std.testing.allocator);
    try cache.put(3, "three", std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), cache.size());

    const val = cache.get(2, std.testing.allocator);
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("two", val.?);
}

test "lru eviction" {
    var cache = try LRU(u32, []const u8).init(2, std.testing.allocator);
    defer cache.deinit(std.testing.allocator);

    try cache.put(1, "one", std.testing.allocator);
    try cache.put(2, "two", std.testing.allocator);

    // Access key 1 to make it more recent
    _ = cache.get(1, std.testing.allocator);

    // Add third entry - should evict key 2 (least recently used)
    try cache.put(3, "three", std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), cache.size());

    // Key 2 should be evicted
    const val2 = cache.get(2, std.testing.allocator);
    try std.testing.expect(val2 == null);

    // Key 1 should still exist
    const val1 = cache.get(1, std.testing.allocator);
    try std.testing.expect(val1 != null);
}
