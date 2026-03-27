//! tri/ring_buffer — Lock-free ring buffer
//! TTT Dogfood v0.2 Stage 228

const std = @import("std");

pub const RingBuffer = struct {
    buffer: []i64,
    capacity: usize,
    head: usize,
    tail: usize,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !RingBuffer {
        const buffer = try allocator.alloc(i64, capacity);
        @memset(buffer, 0);
        return .{
            .buffer = buffer,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
        };
    }

    pub fn enqueue(rb: *RingBuffer, value: i64) !bool {
        const next_tail = (rb.tail + 1) % rb.capacity;
        if (next_tail == rb.head) return false;
        rb.buffer[rb.tail] = value;
        rb.tail = next_tail;
        return true;
    }

    pub fn dequeue(rb: *RingBuffer) ?i64 {
        if (rb.head == rb.tail) return null;
        const value = rb.buffer[rb.head];
        rb.head = (rb.head + 1) % rb.capacity;
        return value;
    }

    pub fn isEmpty(rb: *const RingBuffer) bool {
        return rb.head == rb.tail;
    }

    pub fn deinit(rb: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(rb.buffer);
    }
};

test "ring buffer enqueue dequeue" {
    var rb = try RingBuffer.init(std.testing.allocator, 4);
    defer rb.deinit(std.testing.allocator);
    try std.testing.expect(try rb.enqueue(10));
    try std.testing.expectEqual(@as(i64, 10), rb.dequeue().?);
    try std.testing.expect(rb.isEmpty());
}
