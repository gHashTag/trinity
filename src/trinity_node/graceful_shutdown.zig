// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY GRACEFUL SHUTDOWN v1.6 - Pre-Departure Shard Redistribution
// Proactively move shards before a node leaves (vs reactive rebalancing)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");
const shard_rebalancer_mod = @import("shard_rebalancer.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SHUTDOWN PLAN
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShutdownPlan = struct {
    node_id: [32]u8,
    shards_to_move: u32,
    shards_moved: u32,
    initiated_at: i64,
    completed: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRACEFUL SHUTDOWN MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const GracefulShutdownManager = struct {
    allocator: std.mem.Allocator,
    active_plans: std.AutoHashMap([32]u8, ShutdownPlan),
    completed_plans: u64,
    total_shards_moved: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) GracefulShutdownManager {
        return .{
            .allocator = allocator,
            .active_plans = std.AutoHashMap([32]u8, ShutdownPlan).init(allocator),
            .completed_plans = 0,
            .total_shards_moved = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *GracefulShutdownManager) void {
        self.active_plans.deinit();
    }

    /// Initiate a graceful shutdown for a node — identify shards that need redistribution
    pub fn initiateShutdown(
        self: *GracefulShutdownManager,
        node_id: [32]u8,
        rebalancer: *shard_rebalancer_mod.ShardRebalancer,
    ) !ShutdownPlan {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Count how many shards this node holds
        var shard_count: u32 = 0;
        var iter = rebalancer.shard_locations.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.node_ids.items) |holder_id| {
                if (std.mem.eql(u8, &holder_id, &node_id)) {
                    shard_count += 1;
                    break;
                }
            }
        }

        const plan = ShutdownPlan{
            .node_id = node_id,
            .shards_to_move = shard_count,
            .shards_moved = 0,
            .initiated_at = std.time.timestamp(),
            .completed = false,
        };

        try self.active_plans.put(node_id, plan);
        return plan;
    }

    /// Execute the shutdown: remove node from rebalancer and trigger redistribution
    /// Returns the number of shards successfully redistributed
    pub fn executeShutdown(
        self: *GracefulShutdownManager,
        node_id: [32]u8,
        rebalancer: *shard_rebalancer_mod.ShardRebalancer,
        peers: []const *storage_mod.StorageProvider,
        peer_ids: []const [32]u8,
    ) !u32 {
        // Remove the departing node from rebalancer's tracking
        _ = rebalancer.removeNode(node_id);

        // Now rebalance to fill the gaps
        const moved = try rebalancer.rebalance(peers, peer_ids);

        self.mutex.lock();
        defer self.mutex.unlock();

        // Update plan
        if (self.active_plans.getPtr(node_id)) |plan| {
            plan.shards_moved = moved;
            plan.completed = true;
        }

        self.completed_plans += 1;
        self.total_shards_moved += moved;

        return moved;
    }

    /// Check if a node is in the process of shutting down
    pub fn isShuttingDown(self: *GracefulShutdownManager, node_id: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.active_plans.get(node_id)) |plan| {
            return !plan.completed;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "initiate shutdown identifies shard count" {
    const allocator = std.testing.allocator;

    var manager = GracefulShutdownManager.init(allocator);
    defer manager.deinit();

    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const node_a = [_]u8{0x01} ** 32;
    const node_b = [_]u8{0x02} ** 32;
    const shard1 = [_]u8{0xAA} ** 32;
    const shard2 = [_]u8{0xBB} ** 32;

    try rebalancer.registerShardLocation(shard1, node_a);
    try rebalancer.registerShardLocation(shard1, node_b);
    try rebalancer.registerShardLocation(shard2, node_a);

    const plan = try manager.initiateShutdown(node_a, &rebalancer);
    try std.testing.expectEqual(@as(u32, 2), plan.shards_to_move);
    try std.testing.expect(!plan.completed);
}

test "execute shutdown redistributes and completes" {
    const allocator = std.testing.allocator;

    var manager = GracefulShutdownManager.init(allocator);
    defer manager.deinit();

    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 2);
    defer rebalancer.deinit();

    // Create 3 nodes
    var nodes: [3]storage_mod.StorageProvider = undefined;
    for (0..3) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..3) |i| nodes[i].deinit();

    var peers: [3]*storage_mod.StorageProvider = undefined;
    var peer_ids: [3][32]u8 = undefined;
    for (0..3) |i| {
        peers[i] = &nodes[i];
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Store shard on node 0 and node 1
    var data: [64]u8 = undefined;
    @memset(&data, 0x42);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
    _ = try nodes[0].storeShard(hash, &data);
    _ = try nodes[1].storeShard(hash, &data);

    try rebalancer.registerShardLocation(hash, peer_ids[0]);
    try rebalancer.registerShardLocation(hash, peer_ids[1]);

    // Initiate shutdown of node 0
    _ = try manager.initiateShutdown(peer_ids[0], &rebalancer);
    try std.testing.expect(manager.isShuttingDown(peer_ids[0]));

    // Execute shutdown (remove node 0, rebalance to target=2)
    const moved = try manager.executeShutdown(peer_ids[0], &rebalancer, &peers, &peer_ids);

    // Should have copied to node 2 (since node 0 was removed, only node 1 remains, need 1 more)
    try std.testing.expectEqual(@as(u32, 1), moved);
    try std.testing.expect(!manager.isShuttingDown(peer_ids[0])); // completed
    try std.testing.expectEqual(@as(u64, 1), manager.completed_plans);
}

test "removeNode in rebalancer cleans up" {
    const allocator = std.testing.allocator;

    var manager = GracefulShutdownManager.init(allocator);
    defer manager.deinit();

    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const node_a = [_]u8{0x01} ** 32;
    const shard = [_]u8{0xCC} ** 32;

    try rebalancer.registerShardLocation(shard, node_a);
    try std.testing.expectEqual(@as(u32, 1), rebalancer.getReplicaCount(shard));

    // Initiate + partial execute (just removeNode)
    _ = try manager.initiateShutdown(node_a, &rebalancer);
    _ = rebalancer.removeNode(node_a);
    try std.testing.expectEqual(@as(u32, 0), rebalancer.getReplicaCount(shard));
}

test "isShuttingDown returns false for unknown node" {
    const allocator = std.testing.allocator;

    var manager = GracefulShutdownManager.init(allocator);
    defer manager.deinit();

    const unknown = [_]u8{0xFF} ** 32;
    try std.testing.expect(!manager.isShuttingDown(unknown));
}

test "idempotent initiate shutdown" {
    const allocator = std.testing.allocator;

    var manager = GracefulShutdownManager.init(allocator);
    defer manager.deinit();

    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const node = [_]u8{0x01} ** 32;
    const shard = [_]u8{0xAA} ** 32;
    try rebalancer.registerShardLocation(shard, node);

    const plan1 = try manager.initiateShutdown(node, &rebalancer);
    const plan2 = try manager.initiateShutdown(node, &rebalancer);

    try std.testing.expectEqual(plan1.shards_to_move, plan2.shards_to_move);
}
