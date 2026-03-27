//! tri/heap — Binary heap data structure
//! Auto-generated from specs/tri/tri_heap.tri
//! TTT Dogfood v0.2 Stage 119

const std = @import("std");

/// Max-heap priority queue
pub fn Heap(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

        const Self = @This();

        /// Create empty heap
        pub fn empty(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.ArrayList(T).initCapacity(allocator, 0) catch unreachable,
            };
        }

        /// Free resources
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }

        /// Get number of elements
        pub fn size(self: *const Self) usize {
            return self.items.items.len;
        }

        /// Insert item
        pub fn push(self: *Self, item: T, allocator: std.mem.Allocator) !void {
            try self.items.append(allocator, item);
            self.siftUp();
        }

        /// Extract max element
        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;

            const max = self.items.items[0];
            const last = self.items.pop() orelse return null;

            if (self.items.items.len > 0) {
                self.items.items[0] = last;
                self.siftDown();
            }

            return max;
        }

        /// View max element without removing
        pub fn peek(self: *const Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[0];
        }

        /// Move last element up to restore heap property
        fn siftUp(self: *Self) void {
            var idx = self.items.items.len - 1;
            while (idx > 0) {
                const parent_idx = (idx - 1) / 2;
                if (self.items.items[idx] <= self.items.items[parent_idx]) break;

                // Swap
                const temp = self.items.items[idx];
                self.items.items[idx] = self.items.items[parent_idx];
                self.items.items[parent_idx] = temp;

                idx = parent_idx;
            }
        }

        /// Move root element down to restore heap property
        fn siftDown(self: *Self) void {
            var idx: usize = 0;
            const len = self.items.items.len;

            while (true) {
                const left_child = 2 * idx + 1;
                const right_child = 2 * idx + 2;
                var largest = idx;

                if (left_child < len and self.items.items[left_child] > self.items.items[largest]) {
                    largest = left_child;
                }
                if (right_child < len and self.items.items[right_child] > self.items.items[largest]) {
                    largest = right_child;
                }

                if (largest == idx) break;

                // Swap
                const temp = self.items.items[idx];
                self.items.items[idx] = self.items.items[largest];
                self.items.items[largest] = temp;

                idx = largest;
            }
        }
    };
}

test "heap push pop" {
    var heap = Heap(i32).empty(std.testing.allocator);
    defer heap.deinit(std.testing.allocator);

    try heap.push(5, std.testing.allocator);
    try heap.push(3, std.testing.allocator);
    try heap.push(7, std.testing.allocator);
    try heap.push(1, std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), heap.size());

    const max1 = heap.pop();
    try std.testing.expectEqual(@as(i32, 7), max1);

    const max2 = heap.pop();
    try std.testing.expectEqual(@as(i32, 5), max2);
}

test "heap peek" {
    var heap = Heap(i32).empty(std.testing.allocator);
    defer heap.deinit(std.testing.allocator);

    try heap.push(5, std.testing.allocator);
    try heap.push(3, std.testing.allocator);

    const peeked = heap.peek();
    try std.testing.expectEqual(@as(i32, 5), peeked);

    // Peek should not remove
    try std.testing.expectEqual(@as(usize, 2), heap.size());
}
