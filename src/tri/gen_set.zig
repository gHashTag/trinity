//! tri/set — Immutable set
//! Auto-generated from specs/tri/tri_set.tri
//! TTT Dogfood v0.2 Stage 82

const std = @import("std");

/// Immutable set of unique values
pub fn Set(comptime T: type) type {
    return struct {
        items: []const T,

        const Self = @This();

        /// Create empty set
        pub fn empty() Self {
            return .{ .items = &[_]T{} };
        }

        /// Create set with one element
        pub fn singleton(allocator: std.mem.Allocator, val: T) !Self {
            const new_items = try allocator.alloc(T, 1);
            new_items[0] = val;
            return .{ .items = new_items };
        }

        /// Check membership
        pub fn contains(self: Self, val: T) bool {
            for (self.items) |item| {
                if (std.meta.eql(item, val)) return true;
            }
            return false;
        }

        /// Add element (if not present)
        pub fn insert(self: Self, allocator: std.mem.Allocator, val: T) !Self {
            if (self.contains(val)) return self;

            var new_items = try allocator.alloc(T, self.items.len + 1);
            @memcpy(new_items[0..self.items.len], self.items);
            new_items[self.items.len] = val;
            return .{ .items = new_items };
        }

        /// Remove element
        pub fn remove(self: Self, allocator: std.mem.Allocator, val: T) !Self {
            if (!self.contains(val)) return self;

            var new_items = try allocator.alloc(T, self.items.len - 1);
            var idx: usize = 0;
            for (self.items) |item| {
                if (!std.meta.eql(item, val)) {
                    new_items[idx] = item;
                    idx += 1;
                }
            }
            return .{ .items = new_items };
        }

        /// Set union
        pub fn setUnion(self: Self, other: Self, allocator: std.mem.Allocator) !Self {
            var list = try std.ArrayList(T).initCapacity(allocator, self.items.len + other.items.len);

            for (self.items) |item| try list.append(allocator, item);
            for (other.items) |item| {
                if (!self.contains(item)) try list.append(allocator, item);
            }

            return .{ .items = try list.toOwnedSlice(allocator) };
        }

        /// Get size
        pub fn size(self: Self) usize {
            return self.items.len;
        }
    };
}

test "Set.empty" {
    const set = Set(i32).empty();
    try std.testing.expectEqual(@as(usize, 0), set.size());
}

test "Set.singleton" {
    const set = try Set(i32).singleton(std.testing.allocator, 42);
    defer std.testing.allocator.free(set.items);
    try std.testing.expectEqual(@as(usize, 1), set.size());
    try std.testing.expect(set.contains(42));
}

test "Set.contains" {
    const set = try Set(i32).singleton(std.testing.allocator, 42);
    defer std.testing.allocator.free(set.items);
    try std.testing.expect(set.contains(42));
    try std.testing.expect(!set.contains(99));
}

test "Set.setUnion" {
    const set1 = try Set(i32).singleton(std.testing.allocator, 1);
    defer std.testing.allocator.free(set1.items);
    const set2 = try Set(i32).singleton(std.testing.allocator, 2);
    defer std.testing.allocator.free(set2.items);
    const union_set = try set1.setUnion(set2, std.testing.allocator);
    defer std.testing.allocator.free(union_set.items);

    try std.testing.expect(union_set.contains(1));
    try std.testing.expect(union_set.contains(2));
}
