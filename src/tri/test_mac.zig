const std = @import("std");

pub const NodeRole = enum {
    coordinator,
    worker,
};

pub const MacNode = struct {
    id: usize,
    hostname: []const u8,
};

pub const MacCluster = struct {
    nodes: std.ArrayListUnmanaged(MacNode),
    coordinator_id: ?usize,

    pub fn init(allocator: std.mem.Allocator) !MacCluster {
        return MacCluster{
            .nodes = std.ArrayListUnmanaged(MacNode){},
            .coordinator_id = null,
        };
    }

    pub fn deinit(self: *MacCluster, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }
};

test "simple" {
    const allocator = std.testing.allocator;
    const cluster = try MacCluster.init(allocator);
    defer cluster.deinit(allocator);
}
