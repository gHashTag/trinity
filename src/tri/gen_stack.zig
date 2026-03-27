//! tri/stack — LIFO stack
//! Auto-generated from specs/tri/tri_stack.tri
//! TTT Dogfood v0.2 Stage 85

const std = @import("std");

/// Last-in-first-out stack
pub fn Stack(comptime T: type) type {
    return struct {
        items: []const T,

        const Self = @This();

        /// Create empty stack
        pub fn empty() Self {
            return .{ .items = &[_]T{} };
        }

        /// Push onto top
        pub fn push(self: Self, allocator: std.mem.Allocator, val: T) !Self {
            var new_items = try allocator.alloc(T, self.items.len + 1);
            @memcpy(new_items[0..self.items.len], self.items);
            new_items[self.items.len] = val;
            return .{ .items = new_items };
        }

        /// Remove from top
        pub fn pop(self: Self) Self {
            if (self.items.len == 0) return self;
            return .{ .items = self.items[0 .. self.items.len - 1] };
        }

        /// Get top element
        pub fn peek(self: Self) ?T {
            if (self.items.len == 0) return null;
            return self.items[self.items.len - 1];
        }

        /// Check if empty
        pub fn isEmpty(self: Self) bool {
            return self.items.len == 0;
        }

        /// Get size
        pub fn size(self: Self) usize {
            return self.items.len;
        }
    };
}

test "Stack.empty" {
    const stack = Stack(i32).empty();
    try std.testing.expect(stack.isEmpty());
}

test "Stack.push" {
    const stack = Stack(i32).empty();
    const pushed = try stack.push(std.testing.allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), pushed.peek().?);
}

test "Stack.pop" {
    var stack = Stack(i32).empty();
    stack = try stack.push(std.testing.allocator, 1);
    stack = try stack.push(std.testing.allocator, 2);
    stack = stack.pop();

    try std.testing.expectEqual(@as(i32, 1), stack.peek().?);
}

test "Stack.peek" {
    const stack = Stack(i32).empty();
    try std.testing.expect(stack.peek() == null);
}

test "Stack.size" {
    var stack = Stack(i32).empty();
    try std.testing.expectEqual(@as(usize, 0), stack.size());

    stack = try stack.push(std.testing.allocator, 1);
    stack = try stack.push(std.testing.allocator, 2);
    try std.testing.expectEqual(@as(usize, 2), stack.size());
}
