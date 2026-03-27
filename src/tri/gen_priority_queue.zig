//! tri/priority_queue — Max priority queue (binary heap)
//! Auto-generated from specs/tri_priority_queue.tri
//! TTT Dogfood v0.2 Stage 192

const std = @import("std");

/// Max priority queue
pub const PriorityQueue = struct {
    data: []i64,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create empty priority queue
    pub fn init(allocator: std.mem.Allocator) !PriorityQueue {
        const data = try allocator.alloc(i64, 16);
        return .{
            .data = data,
            .size = 0,
            .allocator = allocator,
        };
    }

    fn ensureCapacity(pq: *PriorityQueue) !void {
        if (pq.size < pq.data.len) return;

        const new_len = pq.data.len * 2;
        const new_data = try pq.allocator.alloc(i64, new_len);
        @memcpy(new_data[0..pq.data.len], pq.data);
        pq.allocator.free(pq.data);
        pq.data = new_data;
    }

    fn siftUp(pq: *PriorityQueue, start_index: usize) void {
        var index = start_index;
        while (index > 0) {
            const parent = (index - 1) / 2;
            if (pq.data[index] <= pq.data[parent]) break;

            const tmp = pq.data[index];
            pq.data[index] = pq.data[parent];
            pq.data[parent] = tmp;
            index = parent;
        }
    }

    fn siftDown(pq: *PriorityQueue, start_index: usize) void {
        var index = start_index;
        const n = pq.size;
        while (true) {
            const left = 2 * index + 1;
            const right = 2 * index + 2;
            var largest = index;

            if (left < n and pq.data[left] > pq.data[largest]) {
                largest = left;
            }
            if (right < n and pq.data[right] > pq.data[largest]) {
                largest = right;
            }

            if (largest == index) break;

            const tmp = pq.data[index];
            pq.data[index] = pq.data[largest];
            pq.data[largest] = tmp;
            index = largest;
        }
    }

    /// Insert with priority
    pub fn enqueue(pq: *PriorityQueue, value: i64) !void {
        try pq.ensureCapacity();

        pq.data[pq.size] = value;
        pq.siftUp(pq.size);
        pq.size += 1;
    }

    /// Remove max element
    pub fn dequeue(pq: *PriorityQueue) i64 {
        if (pq.size == 0) return 0;

        const max = pq.data[0];
        pq.size -= 1;

        if (pq.size > 0) {
            pq.data[0] = pq.data[pq.size];
            pq.siftDown(0);
        }

        return max;
    }

    /// Get max without removing
    pub fn peek(pq: *const PriorityQueue) i64 {
        if (pq.size == 0) return 0;
        return pq.data[0];
    }

    /// Check if empty
    pub fn isEmpty(pq: *const PriorityQueue) bool {
        return pq.size == 0;
    }

    /// Free queue
    pub fn deinit(pq: *PriorityQueue) void {
        pq.allocator.free(pq.data);
    }
};

test "priority queue enqueue dequeue" {
    var pq = try PriorityQueue.init(std.testing.allocator);
    defer pq.deinit();

    try pq.enqueue(3);
    try pq.enqueue(1);
    try pq.enqueue(5);
    try pq.enqueue(2);

    try std.testing.expectEqual(@as(i64, 5), pq.dequeue());
    try std.testing.expectEqual(@as(i64, 3), pq.dequeue());
    try std.testing.expectEqual(@as(i64, 2), pq.dequeue());
    try std.testing.expectEqual(@as(i64, 1), pq.dequeue());
}

test "priority queue peek" {
    var pq = try PriorityQueue.init(std.testing.allocator);
    defer pq.deinit();

    try pq.enqueue(10);
    try pq.enqueue(5);

    try std.testing.expectEqual(@as(i64, 10), pq.peek());
    try std.testing.expectEqual(@as(i64, 10), pq.peek()); // Should still be there
}

test "priority queue empty" {
    var pq = try PriorityQueue.init(std.testing.allocator);
    defer pq.deinit();

    try std.testing.expect(pq.isEmpty());
    try std.testing.expectEqual(@as(i64, 0), pq.dequeue());
}
