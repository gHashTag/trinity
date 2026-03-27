//! tri/queue — FIFO queue
//! Auto-generated from specs/tri/tri_queue.tri
//! TTT Dogfood v0.2 Stage 84

const std = @import("std");

/// First-in-first-out queue
pub fn Queue(comptime T: type) type {
    return struct {
        front: []const T,
        back: []const T,

        const Self = @This();

        /// Create empty queue
        pub fn empty() Self {
            return .{ .front = &[_]T{}, .back = &[_]T{} };
        }

        /// Add to back
        pub fn enqueue(self: Self, allocator: std.mem.Allocator, val: T) !Self {
            var new_back = try allocator.alloc(T, self.back.len + 1);
            @memcpy(new_back[0..self.back.len], self.back);
            new_back[self.back.len] = val;

            return .{ .front = self.front, .back = new_back };
        }

        /// Remove from front
        pub fn dequeue(self: Self) Self {
            if (self.front.len > 0) {
                return .{ .front = self.front[1..], .back = self.back };
            } else if (self.back.len > 0) {
                // Reverse back to front
                const reversed = self.back[self.back.len - 1];
                return .{ .front = self.back[0 .. self.back.len - 1], .back = &[_]T{reversed} };
            }
            return self;
        }

        /// Get front element
        pub fn peek(self: Self) ?T {
            if (self.front.len > 0) return self.front[0];
            if (self.back.len > 0) return self.back[self.back.len - 1];
            return null;
        }

        /// Check if empty
        pub fn isEmpty(self: Self) bool {
            return self.front.len == 0 and self.back.len == 0;
        }

        /// Get size
        pub fn size(self: Self) usize {
            return self.front.len + self.back.len;
        }
    };
}

test "Queue.empty" {
    const queue = Queue(i32).empty();
    try std.testing.expect(queue.isEmpty());
}

test "Queue.enqueue" {
    const queue = Queue(i32).empty();
    const queued = try queue.enqueue(std.testing.allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), queued.peek().?);
}

test "Queue.dequeue" {
    var queue = Queue(i32).empty();
    queue = try queue.enqueue(std.testing.allocator, 1);
    queue = try queue.enqueue(std.testing.allocator, 2);
    queue = queue.dequeue();

    try std.testing.expectEqual(@as(i32, 2), queue.peek().?);
}

test "Queue.peek" {
    var queue = Queue(i32).empty();
    queue = try queue.enqueue(std.testing.allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), queue.peek().?);
}

test "Queue.size" {
    var queue = Queue(i32).empty();
    try std.testing.expectEqual(@as(usize, 0), queue.size());

    queue = try queue.enqueue(std.testing.allocator, 1);
    queue = try queue.enqueue(std.testing.allocator, 2);
    try std.testing.expectEqual(@as(usize, 2), queue.size());
}
