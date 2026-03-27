//! tri/ring — Fixed-size circular buffer
//! Auto-generated from specs/tri/tri_ring.tri
//! TTT Dogfood v0.2 Stage 86

const std = @import("std");

/// Fixed-size circular buffer
pub fn Ring(comptime T: type) type {
    return struct {
        buffer: []T,
        head: usize,
        tail: usize,
        capacity: usize,

        const Self = @This();

        /// Create ring buffer
        pub fn new(cap: usize, allocator: std.mem.Allocator) !Self {
            const buf = try allocator.alloc(T, cap);
            return .{
                .buffer = buf,
                .head = 0,
                .tail = 0,
                .capacity = cap,
            };
        }

        /// Add to back, false if full
        pub fn push(self: *Self, val: T) bool {
            if (self.isFull()) return false;

            self.buffer[self.tail] = val;
            self.tail = (self.tail + 1) % self.capacity;
            return true;
        }

        /// Remove from front
        pub fn pop(self: *Self) ?T {
            if (self.isEmpty()) return null;

            const val = self.buffer[self.head];
            self.head = (self.head + 1) % self.capacity;
            return val;
        }

        /// Check if empty
        pub fn isEmpty(self: Self) bool {
            return self.head == self.tail;
        }

        /// Check if full
        pub fn isFull(self: Self) bool {
            return (self.tail + 1) % self.capacity == self.head;
        }

        /// Get current size
        pub fn size(self: Self) usize {
            if (self.tail >= self.head) return self.tail - self.head;
            return self.capacity - self.head + self.tail;
        }
    };
}

test "Ring.push/pop" {
    var ring = try Ring(i32).new(4, std.testing.allocator);
    defer std.testing.allocator.free(ring.buffer, ring.buffer.len);

    _ = ring.push(1);
    _ = ring.push(2);

    try std.testing.expectEqual(@as(i32, 1), ring.pop().?);
    try std.testing.expectEqual(@as(i32, 2), ring.pop().?);
}

test "Ring.isFull" {
    var ring = try Ring(i32).new(2, std.testing.allocator);
    defer std.testing.allocator.free(ring.buffer, ring.buffer.len);

    _ = ring.push(1);
    _ = ring.push(2);

    try std.testing.expect(ring.isFull());
}

test "Ring.wrap" {
    var ring = try Ring(i32).new(4, std.testing.allocator);
    defer std.testing.allocator.free(ring.buffer, ring.buffer.len);

    _ = ring.push(1);
    _ = ring.push(2);
    _ = ring.push(3);
    _ = ring.push(4);
    _ = ring.pop();
    _ = ring.pop();
    _ = ring.push(5);

    try std.testing.expectEqual(@as(usize, 3), ring.size());
}
