//! TRI Collections — Generated from specs/tri/tri_collections.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// STACK (i32)
// ============================================================================

/// LIFO stack with dynamic growth
pub const Stacki32 = struct {
    items: []i32,
    count: usize,

    /// Create new stack
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Stacki32 {
        const items = try allocator.alloc(i32, capacity);
        return .{
            .items = items,
            .count = 0,
        };
    }

    /// Free stack memory
    pub fn deinit(self: *Stacki32, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
        self.* = undefined;
    }

    /// Push item onto stack
    pub fn push(self: *Stacki32, allocator: std.mem.Allocator, item: i32) !void {
        if (self.count >= self.items.len) {
            // Grow by 2x
            const new_capacity = self.items.len * 2;
            const new_items = try allocator.realloc(self.items, new_capacity);
            self.items = new_items;
        }
        self.items[self.count] = item;
        self.count += 1;
    }

    /// Pop item from stack
    pub fn pop(self: *Stacki32) ?i32 {
        if (self.count == 0) return null;
        self.count -= 1;
        return self.items[self.count];
    }

    /// Peek at top item
    pub fn peek(self: *const Stacki32) ?i32 {
        if (self.count == 0) return null;
        return self.items[self.count - 1];
    }

    /// Check if stack is empty
    pub fn isEmpty(self: *const Stacki32) bool {
        return self.count == 0;
    }

    /// Get current size
    pub fn size(self: *const Stacki32) usize {
        return self.count;
    }
};

// ============================================================================
// QUEUE (i32)
// ============================================================================

/// FIFO queue with dynamic growth
pub const Queuei32 = struct {
    items: []i32,
    head: usize,
    tail: usize,
    count: usize,

    /// Create new queue
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Queuei32 {
        const items = try allocator.alloc(i32, capacity);
        return .{
            .items = items,
            .head = 0,
            .tail = 0,
            .count = 0,
        };
    }

    /// Free queue memory
    pub fn deinit(self: *Queuei32, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
        self.* = undefined;
    }

    /// Add item to back of queue
    pub fn enqueue(self: *Queuei32, allocator: std.mem.Allocator, item: i32) !void {
        if (self.count >= self.items.len) {
            // Grow by 2x and rearrange
            const new_capacity = self.items.len * 2;
            const new_items = try allocator.alloc(i32, new_capacity);
            // Copy items in order from head to tail
            for (0..self.count) |i| {
                new_items[i] = self.items[(self.head + i) % self.items.len];
            }
            allocator.free(self.items);
            self.items = new_items;
            self.head = 0;
            self.tail = self.count;
        }
        self.items[self.tail] = item;
        self.tail = (self.tail + 1) % self.items.len;
        self.count += 1;
    }

    /// Remove item from front of queue
    pub fn dequeue(self: *Queuei32) ?i32 {
        if (self.count == 0) return null;
        const item = self.items[self.head];
        self.head = (self.head + 1) % self.items.len;
        self.count -= 1;
        return item;
    }

    /// Peek at front item
    pub fn peek(self: *const Queuei32) ?i32 {
        if (self.count == 0) return null;
        return self.items[self.head];
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const Queuei32) bool {
        return self.count == 0;
    }

    /// Get current size
    pub fn size(self: *const Queuei32) usize {
        return self.count;
    }
};

// ============================================================================
// RING BUFFER (i32)
// ============================================================================

/// Fixed-size circular buffer
pub const RingBufferi32 = struct {
    items: []i32,
    head: usize,
    tail: usize,
    capacity: usize,
    count: usize,

    /// Create new ring buffer
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !RingBufferi32 {
        const items = try allocator.alloc(i32, capacity);
        return .{
            .items = items,
            .head = 0,
            .tail = 0,
            .capacity = capacity,
            .count = 0,
        };
    }

    /// Free ring buffer memory
    pub fn deinit(self: *RingBufferi32, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
        self.* = undefined;
    }

    /// Write item to ring (overwrites oldest if full)
    pub fn write(self: *RingBufferi32, item: i32) void {
        // Check if buffer is full before writing
        if (self.count >= self.capacity) {
            // Buffer is full, drop oldest by moving head
            self.head = (self.head + 1) % self.capacity;
            self.count -= 1;
        }
        self.items[self.tail] = item;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;
    }

    /// Read item from ring
    pub fn read(self: *RingBufferi32) ?i32 {
        if (self.count == 0) return null;
        const item = self.items[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;
        return item;
    }

    /// Peek at next item without consuming
    pub fn peek(self: *const RingBufferi32) ?i32 {
        if (self.count == 0) return null;
        return self.items[self.head];
    }

    /// Check if ring is empty
    pub fn isEmpty(self: *const RingBufferi32) bool {
        return self.count == 0;
    }

    /// Get current size
    pub fn size(self: *const RingBufferi32) usize {
        return self.count;
    }

    /// Get capacity
    pub fn getCapacity(self: *const RingBufferi32) usize {
        return self.capacity;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Collections: Stack push/pop" {
    const allocator = std.testing.allocator;
    var stack = try Stacki32.init(allocator, 4);
    defer stack.deinit(allocator);

    try stack.push(allocator, 1);
    try stack.push(allocator, 2);
    try stack.push(allocator, 3);

    try std.testing.expectEqual(@as(i32, 3), stack.pop().?);
    try std.testing.expectEqual(@as(i32, 2), stack.pop().?);
    try std.testing.expectEqual(@as(i32, 1), stack.pop().?);
    try std.testing.expect(stack.pop() == null);
}

test "Collections: Stack peek" {
    const allocator = std.testing.allocator;
    var stack = try Stacki32.init(allocator, 4);
    defer stack.deinit(allocator);

    try stack.push(allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), stack.peek().?);
    try std.testing.expectEqual(@as(i32, 42), stack.peek().?); // Still there
    try std.testing.expectEqual(@as(i32, 42), stack.pop().?);
    try std.testing.expect(stack.peek() == null);
}

test "Collections: Stack isEmpty" {
    const allocator = std.testing.allocator;
    var stack = try Stacki32.init(allocator, 4);
    defer stack.deinit(allocator);

    try std.testing.expect(stack.isEmpty());
    try stack.push(allocator, 1);
    try std.testing.expect(!stack.isEmpty());
    _ = stack.pop();
    try std.testing.expect(stack.isEmpty());
}

test "Collections: Stack growth" {
    const allocator = std.testing.allocator;
    var stack = try Stacki32.init(allocator, 2);
    defer stack.deinit(allocator);

    try stack.push(allocator, 1);
    try stack.push(allocator, 2);
    try stack.push(allocator, 3); // Should grow
    try stack.push(allocator, 4);

    try std.testing.expectEqual(@as(usize, 4), stack.size());
}

test "Collections: Queue enqueue/dequeue" {
    const allocator = std.testing.allocator;
    var queue = try Queuei32.init(allocator, 4);
    defer queue.deinit(allocator);

    try queue.enqueue(allocator, 1);
    try queue.enqueue(allocator, 2);
    try queue.enqueue(allocator, 3);

    try std.testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try std.testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try std.testing.expectEqual(@as(i32, 3), queue.dequeue().?);
    try std.testing.expect(queue.dequeue() == null);
}

test "Collections: Queue FIFO" {
    const allocator = std.testing.allocator;
    var queue = try Queuei32.init(allocator, 4);
    defer queue.deinit(allocator);

    try queue.enqueue(allocator, 10);
    try queue.enqueue(allocator, 20);
    try queue.enqueue(allocator, 30);

    try std.testing.expectEqual(@as(i32, 10), queue.dequeue().?);
    try std.testing.expectEqual(@as(i32, 20), queue.dequeue().?);
    try std.testing.expectEqual(@as(i32, 30), queue.dequeue().?);
}

test "Collections: Queue peek" {
    const allocator = std.testing.allocator;
    var queue = try Queuei32.init(allocator, 4);
    defer queue.deinit(allocator);

    try queue.enqueue(allocator, 99);
    try std.testing.expectEqual(@as(i32, 99), queue.peek().?);
    try std.testing.expectEqual(@as(i32, 99), queue.peek().?); // Still there
    try std.testing.expectEqual(@as(i32, 99), queue.dequeue().?);
    try std.testing.expect(queue.peek() == null);
}

test "Collections: Ring buffer write/read" {
    const allocator = std.testing.allocator;
    var ring = try RingBufferi32.init(allocator, 4);
    defer ring.deinit(allocator);

    ring.write(1);
    ring.write(2);
    ring.write(3);

    try std.testing.expectEqual(@as(i32, 1), ring.read().?);
    try std.testing.expectEqual(@as(i32, 2), ring.read().?);
    try std.testing.expectEqual(@as(i32, 3), ring.read().?);
    try std.testing.expect(ring.read() == null);
}

test "Collections: Ring buffer overwrite" {
    const allocator = std.testing.allocator;
    var ring = try RingBufferi32.init(allocator, 3);
    defer ring.deinit(allocator);

    ring.write(1);
    ring.write(2);
    ring.write(3);
    ring.write(4); // Overwrites 1
    ring.write(5); // Overwrites 2

    try std.testing.expectEqual(@as(i32, 3), ring.read().?);
    try std.testing.expectEqual(@as(i32, 4), ring.read().?);
    try std.testing.expectEqual(@as(i32, 5), ring.read().?);
    try std.testing.expect(ring.read() == null);
}

test "Collections: Ring buffer size" {
    const allocator = std.testing.allocator;
    var ring = try RingBufferi32.init(allocator, 4);
    defer ring.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), ring.size());
    ring.write(1);
    try std.testing.expectEqual(@as(usize, 1), ring.size());
    ring.write(2);
    try std.testing.expectEqual(@as(usize, 2), ring.size());
    _ = ring.read();
    try std.testing.expectEqual(@as(usize, 1), ring.size());
}
