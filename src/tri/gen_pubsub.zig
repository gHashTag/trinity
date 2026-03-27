//! tri/pubsub — Publish-subscribe pattern
//! TTT Dogfood v0.2 Stage 256

const std = @import("std");

pub const PubSub = struct {
    subscribers: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PubSub {
        const subscribers = try std.ArrayList([]const u8).initCapacity(allocator, 10);
        return .{
            .subscribers = subscribers,
            .allocator = allocator,
        };
    }

    pub fn subscribe(ps: *PubSub, topic: []const u8) !void {
        try ps.subscribers.append(ps.allocator, topic);
    }

    pub fn publish(ps: *PubSub, msg: []const u8) !usize {
        _ = msg;
        return ps.subscribers.items.len;
    }

    pub fn deinit(ps: *PubSub) void {
        ps.subscribers.deinit(ps.allocator);
    }
};

test "pubsub" {
    var ps = try PubSub.init(std.testing.allocator);
    defer ps.deinit();
    try ps.subscribe("topic1");
    try std.testing.expectEqual(@as(usize, 1), try ps.publish("msg"));
}
