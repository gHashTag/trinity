// @origin(spec:depin_rest.tri) @regen(manual-impl)
// Unified DePIN REST API — Phase 3
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Method = enum {
    GET,
    POST,
    PUT,
};

pub const NodeStatus = enum {
    offline,
    syncing,
    online,
    earning,
};

pub const NodeInfo = struct {
    node_id: []const u8,
    host: []const u8,
    port: u16,
    status: NodeStatus,
    quality_score: f64,
    uptime_hours: f64,
    operations_count: u64,
    last_seen: i64,
};

pub const DePINRestServer = struct {
    allocator: Allocator,
    port: u16,
    nodes: std.StringHashMapUnmanaged(NodeInfo),
    const MIN_STAKE: f64 = 100.0;

    pub fn init(allocator: Allocator, port: u16) DePINRestServer {
        return DePINRestServer{
            .allocator = allocator,
            .port = port,
            .nodes = .{},
        };
    }

    pub fn deinit(self: *DePINRestServer) void {
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.node_id);
            self.allocator.free(entry.value_ptr.host);
        }
        self.nodes.deinit(self.allocator);
    }
};

test "DePINRestServer init" {
    const allocator = std.testing.allocator;
    var server = DePINRestServer.init(allocator, 8080);
    defer server.deinit();

    try std.testing.expectEqual(@as(u16, 8080), server.port);
}

test "min stake validation" {
    try std.testing.expect(DePINRestServer.MIN_STAKE >= 100.0);
}

test "NodeStatus enum" {
    try std.testing.expectEqual(@as(?NodeStatus, .offline), std.meta.stringToEnum(NodeStatus, "offline"));
}
