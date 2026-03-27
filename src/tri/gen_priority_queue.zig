//! tri/priority_queue — Min-heap priority queue
//! Auto-generated from specs/tri/tri_priority_queue.tri
//! TTT Dogfood v0.2 Stage 88

const std = @import("std");

/// Min-heap priority queue (simplified for integers)
pub fn PriorityQueueInt(comptime T: type) type {
    return struct {
        items: []T,
        count: usize,

        const Self = @This();

        /// Create empty queue
        pub fn new() Self {
            return .{ .items = &[_]T{}, .count = 0 };
        }

        /// Get parent index
        fn parent(idx: usize) usize {
            return (idx - 1) / 2;
        }

        /// Get left child index
        fn leftChild(idx: usize) usize {
            return 2 * idx + 1;
        }

        /// Get right child index
        fn rightChild(idx: usize) usize {
            return 2 * idx + 2;
        }

        /// Swap two elements
        fn swap(self: *Self, i: usize, j: usize) void {
            const temp = self.items[i];
            self.items[i] = self.items[j];
            self.items[j] = temp;
        }

        /// Bubble up element
        fn bubbleUp(self: *Self, idx: usize) void {
            while (idx > 0) {
                const parent_idx = Self.parent(idx);
                if (self.items[idx] < self.items[parent_idx]) {
                    self.swap(idx, parent_idx);
                    idx = parent_idx;
                } else break;
            }
        }

        /// Bubble down element
        fn bubbleDown(self: *Self, idx: usize) void {
            while (idx < self.count) {
                const left = Self.leftChild(idx);
                const right = Self.rightChild(idx);
                var smallest = idx;

                if (left < self.count and self.items[left] < self.items[smallest]) {
                    smallest = left;
                }
                if (right < self.count and self.items[right] < self.items[smallest]) {
                    smallest = right;
                }

                if (smallest != idx) {
                    self.swap(idx, smallest);
                    idx = smallest;
                } else break;
            }
        }

        /// Insert value
        pub fn insert(self: *Self, allocator: std.mem.Allocator, val: T) !void {
            if (self.items.len <= self.count) {
                const new_items = try allocator.alloc(T, self.count * 2 + 1);
                @memcpy(new_items[0..self.items.len], self.items);
                self.items = new_items;
            }

            self.items[self.count] = val;
            self.count += 1;
            self.bubbleUp(self.count - 1);
        }

        /// Remove and return minimum
        pub fn extractMin(self: *Self) ?T {
            if (self.count == 0) return null;

            const min_val = self.items[0];
            self.items[0] = self.items[self.count - 1];
            self.count -= 1;
            self.bubbleDown(0);
            return min_val;
        }

        /// Get minimum without removing
        pub fn peekMin(self: Self) ?T {
            if (self.count == 0) return null;
            return self.items[0];
        }
    };
}

test "PriorityQueueInt.new" {
    const pq = PriorityQueueInt(i32).new();
    try std.testing.expect(pq.peekMin() == null);
}

test "PriorityQueueInt.insert" {
    var pq = PriorityQueueInt(i32).new();
    try pq.insert(std.testing.allocator, 3);
    try pq.insert(std.testing.allocator, 1);
    try pq.insert(std.testing.allocator, 2);

    try std.testing.expectEqual(@as(i32, 1), pq.peekMin().?);
}

test "PriorityQueueInt.extractMin" {
    var pq = PriorityQueueInt(i32).new();
    try pq.insert(std.testing.allocator, 3);
    try pq.insert(std.testing.allocator, 1);
    try pq.insert(std.testing.allocator, 2);

    try std.testing.expectEqual(@as(i32, 1), pq.extractMin().?);
    try std.testing.expectEqual(@as(i32, 2), pq.extractMin().?);
    try std.testing.expectEqual(@as(i32, 3), pq.extractMin().?);
}
