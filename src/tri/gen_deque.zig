//! tri/deque — Double-ended queue
//! Auto-generated from specs/tri/tri_deque.tri
//! TTT Dogfood v0.2 Stage 183

const std = @import("std");

/// Double-ended queue
pub const Deque = struct {
    data: []i64,
    front: usize,
    back: usize,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create empty deque
    pub fn init(allocator: std.mem.Allocator) !Deque {
        return .{
            .data = &[_]i64{},
            .front = 0,
            .back = 0,
            .size = 0,
            .allocator = allocator,
        };
    }

    /// Ensure capacity
    fn ensureCapacity(deque: *Deque) !void {
        if (deque.size < deque.data.len) return;

        const new_len = if (deque.data.len == 0) 4 else deque.data.len * 2;
        const new_data = try deque.allocator.alloc(i64, new_len);
        @memset(new_data, 0);

        // Copy elements to new array
        for (0..deque.size) |i| {
            const idx = (deque.front + i) % deque.data.len;
            if (deque.data.len > 0) {
                new_data[i] = deque.data[idx];
            }
        }

        if (deque.data.len > 0) {
            deque.allocator.free(deque.data);
        }
        deque.data = new_data;
        deque.front = 0;
        deque.back = deque.size;
    }

    /// Add to front
    pub fn pushFront(deque: *Deque, value: i64) !void {
        try deque.ensureCapacity();

        if (deque.size == 0) {
            deque.front = 0;
            deque.back = 0;
        } else {
            deque.front = if (deque.front == 0) deque.data.len - 1 else deque.front - 1;
        }

        deque.data[deque.front] = value;
        deque.size += 1;
    }

    /// Add to back
    pub fn pushBack(deque: *Deque, value: i64) !void {
        try deque.ensureCapacity();

        deque.data[deque.back] = value;
        deque.back = (deque.back + 1) % deque.data.len;
        deque.size += 1;
    }

    /// Remove from front
    pub fn popFront(deque: *Deque) i64 {
        if (deque.size == 0) return 0;

        const value = deque.data[deque.front];
        deque.front = (deque.front + 1) % deque.data.len;
        deque.size -= 1;
        return value;
    }

    /// Remove from back
    pub fn popBack(deque: *Deque) i64 {
        if (deque.size == 0) return 0;

        deque.back = if (deque.back == 0) deque.data.len - 1 else deque.back - 1;
        const value = deque.data[deque.back];
        deque.size -= 1;
        return value;
    }

    /// Free deque
    pub fn deinit(deque: *Deque) void {
        if (deque.data.len > 0) {
            deque.allocator.free(deque.data);
        }
    }
};

test "deque push pop front" {
    var deque = try Deque.init(std.testing.allocator);
    defer deque.deinit();

    try deque.pushFront(1);
    try deque.pushFront(2);

    try std.testing.expectEqual(@as(i64, 2), deque.popFront());
    try std.testing.expectEqual(@as(i64, 1), deque.popFront());
}

test "deque push pop back" {
    var deque = try Deque.init(std.testing.allocator);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);

    try std.testing.expectEqual(@as(i64, 1), deque.popFront());
    try std.testing.expectEqual(@as(i64, 2), deque.popFront());
}

test "deque mixed operations" {
    var deque = try Deque.init(std.testing.allocator);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushFront(0);
    try deque.pushBack(2);

    try std.testing.expectEqual(@as(i64, 0), deque.popFront());
    try std.testing.expectEqual(@as(i64, 1), deque.popFront());
    try std.testing.expectEqual(@as(i64, 2), deque.popBack());
}
