//! tri/circular_buffer — Circular buffer / ring buffer
//! Auto-generated from specs/tri/tri_circular_buffer.tri
//! TTT Dogfood v0.2 Stage 182

const std = @import("std");

/// Fixed-size ring buffer
pub const CircularBuffer = struct {
    data: []i64,
    head: usize,
    tail: usize,
    count: usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    /// Create buffer with given capacity
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !CircularBuffer {
        const data = try allocator.alloc(i64, capacity);
        return .{
            .data = data,
            .head = 0,
            .tail = 0,
            .count = 0,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    /// Write value (overwrites if full)
    pub fn write(buf: *CircularBuffer, value: i64) !void {
        buf.data[buf.tail] = value;
        buf.tail = (buf.tail + 1) % buf.capacity;

        if (buf.count == buf.capacity) {
            // Buffer is full, advance head (overwrites oldest)
            buf.head = (buf.head + 1) % buf.capacity;
        } else {
            buf.count += 1;
        }
    }

    /// Read next value
    pub fn read(buf: *CircularBuffer) i64 {
        if (buf.count == 0) return 0;

        const value = buf.data[buf.head];
        buf.head = (buf.head + 1) % buf.capacity;
        buf.count -= 1;
        return value;
    }

    /// Check if buffer is empty
    pub fn isEmpty(buf: *const CircularBuffer) bool {
        return buf.count == 0;
    }

    /// Free buffer
    pub fn deinit(buf: *CircularBuffer) void {
        buf.allocator.free(buf.data);
    }
};

test "circular buffer write read" {
    var buf = try CircularBuffer.init(std.testing.allocator, 4);
    defer buf.deinit();

    try buf.write(1);
    try buf.write(2);
    try buf.write(3);

    try std.testing.expectEqual(@as(i64, 1), buf.read());
    try std.testing.expectEqual(@as(i64, 2), buf.read());
}

test "circular buffer wrap" {
    var buf = try CircularBuffer.init(std.testing.allocator, 3);
    defer buf.deinit();

    try buf.write(1);
    try buf.write(2);
    try buf.write(3);
    try buf.write(4); // Overwrites 1

    try std.testing.expectEqual(@as(i64, 2), buf.read());
    try std.testing.expectEqual(@as(i64, 3), buf.read());
}

test "circular buffer empty" {
    var buf = try CircularBuffer.init(std.testing.allocator, 4);
    defer buf.deinit();

    try std.testing.expect(buf.isEmpty());
}
