//! tri/message_queue — In-memory message queue
//! TTT Dogfood v0.2 Stage 255

const std = @import("std");

pub const MessageQueue = struct {
    messages: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !MessageQueue {
        const messages = try std.ArrayList([]const u8).initCapacity(allocator, 10);
        return .{
            .messages = messages,
            .allocator = allocator,
        };
    }

    pub fn enqueue(q: *MessageQueue, msg: []const u8) !void {
        try q.messages.append(q.allocator, msg);
    }

    pub fn dequeue(q: *MessageQueue) ?[]const u8 {
        return q.messages.orderedRemove(0);
    }

    pub fn deinit(q: *MessageQueue) void {
        q.messages.deinit(q.allocator);
    }
};

test "message queue" {
    var q = try MessageQueue.init(std.testing.allocator);
    defer q.deinit();
    try q.enqueue("test");
    try std.testing.expect(q.dequeue() != null);
}
