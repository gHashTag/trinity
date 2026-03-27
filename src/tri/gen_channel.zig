//! tri/channel — CSP-style communication
//! Auto-generated from specs/tri/tri_channel.tri
//! TTT Dogfood v0.2 Stage 74

const std = @import("std");

/// Async communication channel
pub fn Channel(comptime T: type) type {
    return struct {
        capacity: usize,
        buffer: std.ArrayList(T),
        sender_count: usize,
        receiver_count: usize,
        closed: bool,
        mutex: std.Thread.Mutex,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create buffered channel
        pub fn init(cap: usize, allocator: std.mem.Allocator) Self {
            return .{
                .capacity = cap,
                .buffer = std.ArrayList(T).initCapacity(allocator, cap) catch unreachable,
                .sender_count = 0,
                .receiver_count = 0,
                .closed = false,
                .mutex = std.Thread.Mutex{},
                .allocator = allocator,
            };
        }

        /// Deinitialize channel
        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
        }

        /// Send value, return true if successful
        pub fn send(self: *Self, value: T) !bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.closed) return error.ChannelClosed;

            if (self.buffer.items.len >= self.capacity) {
                return false; // Channel full
            }

            try self.buffer.append(self.allocator, value);
            return true;
        }

        /// Receive value, null if closed and empty
        pub fn recv(self: *Self) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.buffer.items.len == 0) {
                if (self.closed) return null;
                return null; // Would block in real implementation
            }

            return self.buffer.orderedRemove(0);
        }

        /// Try receive without blocking
        pub fn tryRecv(self: *Self) ?T {
            return self.recv();
        }

        /// Close channel
        pub fn close(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.closed = true;
        }

        /// Check if channel is closed
        pub fn isClosed(self: *Self) bool {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.closed;
        }

        /// Get current length
        pub fn len(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.buffer.items.len;
        }

        /// Check if channel is empty
        pub fn isEmpty(self: *Self) bool {
            return self.len() == 0;
        }

        /// Check if channel is full
        pub fn isFull(self: *Self) bool {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.buffer.items.len >= self.capacity;
        }
    };
}

test "Channel send/recv" {
    var channel = Channel(i32).init(2, std.testing.allocator);
    defer channel.deinit();

    const sent1 = try channel.send(42);
    try std.testing.expect(sent1);

    const sent2 = try channel.send(99);
    try std.testing.expect(sent2);

    const received = channel.recv();
    try std.testing.expectEqual(@as(i32, 42), received);
}

test "Channel capacity" {
    var channel = Channel(i32).init(2, std.testing.allocator);
    defer channel.deinit();

    _ = try channel.send(1);
    _ = try channel.send(2);

    const result = try channel.send(3);
    try std.testing.expect(!result); // Full
}

test "Channel close" {
    var channel = Channel(i32).init(2, std.testing.allocator);
    defer channel.deinit();

    _ = try channel.send(42);
    channel.close();

    try std.testing.expect(channel.isClosed());

    const received = channel.recv();
    try std.testing.expectEqual(@as(i32, 42), received);
}

test "Channel send after close" {
    var channel = Channel(i32).init(2, std.testing.allocator);
    defer channel.deinit();

    channel.close();

    const result = channel.send(42);
    try std.testing.expectError(error.ChannelClosed, result);
}

test "Channel len" {
    var channel = Channel(i32).init(10, std.testing.allocator);
    defer channel.deinit();

    try std.testing.expectEqual(@as(usize, 0), channel.len());

    _ = try channel.send(1);
    _ = try channel.send(2);

    try std.testing.expectEqual(@as(usize, 2), channel.len());

    _ = channel.recv();

    try std.testing.expectEqual(@as(usize, 1), channel.len());
}

test "Channel isEmpty/isFull" {
    var channel = Channel(i32).init(2, std.testing.allocator);
    defer channel.deinit();

    try std.testing.expect(channel.isEmpty());
    try std.testing.expect(!channel.isFull());

    _ = try channel.send(1);
    _ = try channel.send(2);

    try std.testing.expect(!channel.isEmpty());
    try std.testing.expect(channel.isFull());
}
