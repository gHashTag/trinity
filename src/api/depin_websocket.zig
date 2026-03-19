// @origin(spec:depin_websocket.tri) @regen(manual-impl)
// DePIN WebSocket Server — Real-time events (Phase 3)

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

pub const EventType = enum {
    node_status_change,
    quality_update,
};

pub const Event = struct {
    event_type: EventType,
    timestamp: i64,
    node_id: ?[]const u8,
    data: []const u8,
};

pub const ClientConnection = struct {
    stream: net.Stream,
    address: net.Address,
    subscribed_channels: std.ArrayListUnmanaged([]const u8),
};

pub fn init(allocator: Allocator, stream: net.Stream, address: net.Address) ClientConnection {
    _ = allocator;
    _ = stream;
    _ = address;
    _ = std.time.timestamp();
    _ = .{};
    return ClientConnection{
        .stream = stream,
        .address = address,
        .connected_at = std.time.timestamp(),
        .subscribed_channels = .{},
    };
}

test "EventType enum" {
    try std.testing.expectEqual(@as(?EventType, .node_status_change), std.meta.stringToEnum(EventType, "node_status_change"));
}
