//! tri/map — Immutable key-value store
//! Auto-generated from specs/tri/tri_map.tri
//! TTT Dogfood v0.2 Stage 83

const std = @import("std");

/// Immutable map from keys to values
pub fn Map(comptime K: type, comptime V: type) type {
    return struct {
        keys: []const K,
        values: []const V,

        const Self = @This();

        /// Create empty map
        pub fn empty() Self {
            return .{ .keys = &[_]K{}, .values = &[_]V{} };
        }

        /// Create map with one entry
        pub fn singleton(key: K, val: V) Self {
            return .{ .keys = &[_]K{key}, .values = &[_]V{val} };
        }

        /// Get value by key
        pub fn get(self: Self, key: K) ?V {
            for (self.keys, 0..) |k, i| {
                if (std.meta.eql(k, key)) return self.values[i];
            }
            return null;
        }

        /// Insert or update key
        pub fn set(self: Self, allocator: std.mem.Allocator, key: K, val: V) !Self {
            const existing_idx = for (self.keys, 0..) |k, i| {
                if (std.meta.eql(k, key)) break i;
            } else null;

            if (existing_idx) |idx| {
                // Update existing
                var new_values = try allocator.alloc(V, self.values.len);
                @memcpy(new_values, self.values);
                new_values[idx] = val;
                return .{ .keys = self.keys, .values = new_values };
            } else {
                // Insert new
                var new_keys = try allocator.alloc(K, self.keys.len + 1);
                var new_values = try allocator.alloc(V, self.values.len + 1);
                @memcpy(new_keys[0..self.keys.len], self.keys);
                @memcpy(new_values[0..self.values.len], self.values);
                new_keys[self.keys.len] = key;
                new_values[self.values.len] = val;
                return .{ .keys = new_keys, .values = new_values };
            }
        }

        /// Get all keys
        pub fn keys(self: Self) []const K {
            return self.keys;
        }

        /// Get all values
        pub fn values(self: Self) []const V {
            return self.values;
        }

        /// Get size
        pub fn size(self: Self) usize {
            return self.keys.len;
        }
    };
}

test "Map.empty" {
    const map = Map(i32, i32).empty();
    try std.testing.expectEqual(@as(usize, 0), map.size());
}

test "Map.singleton" {
    const map = Map(i32, i32).singleton(1, 100);
    try std.testing.expectEqual(@as(i32, 100), map.get(1).?);
}

test "Map.get" {
    const map = Map(i32, i32).singleton(1, 100);
    try std.testing.expectEqual(@as(i32, 100), map.get(1).?);
    try std.testing.expect(map.get(99) == null);
}

test "Map.set update" {
    const map = Map(i32, i32).singleton(1, 100);
    const updated = try map.set(std.testing.allocator, 1, 200);
    try std.testing.expectEqual(@as(i32, 200), updated.get(1).?);
}

test "Map.keys" {
    const map = Map(i32, i32).singleton(1, 100);
    try std.testing.expectEqual(@as(i32, 1), map.keys()[0]);
}
