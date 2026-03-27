//! tri/zipper — Functional cursor for tree navigation
//! Auto-generated from specs/tri/tri_zipper.tri
//! TTT Dogfood v0.2 Stage 92

const std = @import("std");

/// Focus point with left and right contexts
pub fn Zipper(comptime T: type) type {
    return struct {
        focus: T,
        left: std.ArrayList(T),
        right: std.ArrayList(T),

        const Self = @This();

        /// Create zipper from slice
        pub fn fromSlice(items: []const T, allocator: std.mem.Allocator) !Self {
            if (items.len == 0) return error.EmptySlice;
            const left_list = try std.ArrayList(T).initCapacity(allocator, items.len);
            var right_list = try std.ArrayList(T).initCapacity(allocator, items.len - 1);
            try right_list.appendSlice(allocator, items[1..]);
            return .{
                .focus = items[0],
                .left = left_list,
                .right = right_list,
            };
        }

        /// Get focused element
        pub fn current(self: Self) T {
            return self.focus;
        }

        /// Move focus to left sibling
        pub fn goLeft(self: Self, allocator: std.mem.Allocator) !Self {
            if (self.left.items.len == 0) return error.NoLeft;
            const idx = self.left.items.len - 1;
            const new_focus = self.left.items[idx];
            var new_right = try std.ArrayList(T).initCapacity(allocator, self.right.items.len + 1);
            try new_right.append(allocator, self.focus);
            try new_right.appendSlice(allocator, self.right.items);
            var new_left = try std.ArrayList(T).initCapacity(allocator, idx);
            try new_left.appendSlice(allocator, self.left.items[0..idx]);
            return .{
                .focus = new_focus,
                .left = new_left,
                .right = new_right,
            };
        }

        /// Move focus to right sibling
        pub fn goRight(self: Self, allocator: std.mem.Allocator) !Self {
            if (self.right.items.len == 0) return error.NoRight;
            // Get first element from right list
            const new_focus = self.right.items[0];
            var new_left = try std.ArrayList(T).initCapacity(allocator, self.left.items.len + 1);
            try new_left.appendSlice(allocator, self.left.items);
            try new_left.append(allocator, self.focus);
            var new_right = try std.ArrayList(T).initCapacity(allocator, self.right.items.len - 1);
            try new_right.appendSlice(allocator, self.right.items[1..]);
            return .{
                .focus = new_focus,
                .left = new_left,
                .right = new_right,
            };
        }

        /// Convert back to list
        pub fn toList(self: Self, allocator: std.mem.Allocator) ![]T {
            var list = try std.ArrayList(T).initCapacity(allocator, self.left.items.len + 1 + self.right.items.len);
            try list.appendSlice(allocator, self.left.items);
            try list.append(allocator, self.focus);
            try list.appendSlice(allocator, self.right.items);
            return list.toOwnedSlice(allocator);
        }
    };
}

test "Zipper.current" {
    var zipper = try Zipper(i32).fromSlice(&[_]i32{ 1, 2, 3 }, std.testing.allocator);
    defer {
        zipper.left.deinit(std.testing.allocator);
        zipper.right.deinit(std.testing.allocator);
    }
    try std.testing.expectEqual(@as(i32, 1), zipper.current());
}

test "Zipper.goRight" {
    var zipper = try Zipper(i32).fromSlice(&[_]i32{ 1, 2, 3 }, std.testing.allocator);
    defer {
        zipper.left.deinit(std.testing.allocator);
        zipper.right.deinit(std.testing.allocator);
    }
    zipper = try zipper.goRight(std.testing.allocator);
    try std.testing.expectEqual(@as(i32, 2), zipper.current());
}

test "Zipper.toList" {
    var zipper = try Zipper(i32).fromSlice(&[_]i32{ 1, 2, 3 }, std.testing.allocator);
    defer {
        zipper.left.deinit(std.testing.allocator);
        zipper.right.deinit(std.testing.allocator);
    }
    const list = try zipper.toList(std.testing.allocator);
    defer std.testing.allocator.free(list);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, list);
}
