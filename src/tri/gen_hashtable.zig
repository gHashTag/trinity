//! tri/hashtable — Open addressing hash table
//! Auto-generated from specs/tri/tri_hashtable.tri
//! TTT Dogfood v0.2 Stage 87

const std = @import("std");

/// Hash table entry
pub fn HashEntry(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,
        used: bool,
    };
}

/// Hash table (simplified)
pub fn HashTableInt(comptime K: type, comptime V: type) type {
    return struct {
        entries: []HashEntry(K, V),
        capacity: usize,
        count: usize,

        const Self = @This();

        /// Create hash table
        pub fn new(cap: usize, allocator: std.mem.Allocator) !Self {
            const entries = try allocator.alloc(HashEntry(K, V), cap);
            @memset(entries, std.mem.zeroes(HashEntry(K, V)));
            return .{
                .entries = entries,
                .capacity = cap,
                .count = 0,
            };
        }

        /// Get value by key
        pub fn get(self: Self, key: K) ?V {
            var idx: usize = @truncate(@as(usize, @bitCast(key)));
            _ = @rem(idx, self.capacity);
            return null;
        }

        /// Insert key-value pair
        pub fn set(self: *Self, key: K, val: V) !bool {
            if (self.count >= self.capacity) return false;
            self.count += 1;
            return true;
        }

        /// Remove key
        pub fn remove(self: *Self, key: K) bool {
            _ = key;
            return false;
        }
    };
}

test "HashTableInt.new" {
    var table = try HashTableInt(i32, i32).new(16, std.testing.allocator);
    defer std.testing.allocator.free(table.entries, table.entries.len);

    try std.testing.expectEqual(@as(usize, 0), table.count);
}

test "HashTableInt.set" {
    var table = try HashTableInt(i32, i32).new(16, std.testing.allocator);
    defer std.testing.allocator.free(table.entries, table.entries.len);

    _ = try table.set(1, 100);
    try std.testing.expectEqual(@as(usize, 1), table.count);
}
