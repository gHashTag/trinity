const std = @import("std");

pub const Node = struct {
    id: [8]u8,
    balance: f64,
    latency_ms: u64,
};

pub const SwarmManager = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node),
    total_swarm_size: usize = 10000,
    gossip_interval_ms: u64 = 500,

    pub fn init(allocator: std.mem.Allocator) !SwarmManager {
        var self = SwarmManager{
            .allocator = allocator,
            .nodes = .{},
        };
        // Seed initial 10 representative nodes for simulation
        for (0..10) |i| {
            var id: [8]u8 = undefined;
            const res = try std.fmt.bufPrint(&id, "{d}", .{i});
            // Ensure id is null-terminated or handled correctly if needed,
            // but for a 8-byte buffer we can just pads it or use a slice.
            // For the mock, we'll just use the slice.
            _ = res;
            try self.nodes.append(allocator, .{
                .id = id,
                .balance = 0.0,
                .latency_ms = 10 + i * 5,
            });
        }
        return self;
    }

    pub fn deinit(self: *SwarmManager) void {
        self.nodes.deinit(self.allocator);
    }

    pub fn simulateGossip(self: *SwarmManager) void {
        std.debug.print("🔗 [P2P Swarm] Propagating earnings across {d} virtual nodes...\n", .{self.total_swarm_size});
        for (self.nodes.items) |*node| {
            node.balance += 0.01; // Tiny mock earnings per gossip
        }
        std.debug.print("✅ [P2P Swarm] Gossip complete. Swarm Health: BLESSED\n", .{});
    }

    pub fn findOptimalJobNode(self: *SwarmManager) ?*Node {
        var best: ?*Node = null;
        var min_latency: u64 = std.math.maxInt(u64);
        for (self.nodes.items) |*node| {
            if (node.latency_ms < min_latency) {
                min_latency = node.latency_ms;
                best = node;
            }
        }
        return best;
    }
};
