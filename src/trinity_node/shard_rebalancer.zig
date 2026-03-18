// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY SHARD REBALANCER v1.5 - Auto-Redistribute Shards on Peer Join/Leave
// Maintains target replication factor by detecting under-replicated shards
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD LOCATION TRACKING
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardLocationEntry = struct {
    node_ids: std.ArrayListUnmanaged([32]u8),

    pub fn deinit(self: *ShardLocationEntry, allocator: std.mem.Allocator) void {
        self.node_ids.deinit(allocator);
    }
};

pub const UnderReplicatedShard = struct {
    shard_hash: [32]u8,
    current_replicas: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHARD REBALANCER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ShardRebalancer = struct {
    allocator: std.mem.Allocator,
    shard_locations: std.AutoHashMap([32]u8, ShardLocationEntry),
    target_replication: u32,
    rebalance_interval_secs: i64,
    last_rebalance_time: i64,
    mutex: std.Thread.Mutex,

    // Stats
    shards_rebalanced: u64,
    rebalance_rounds: u64,

    pub fn init(allocator: std.mem.Allocator, target_replication: u32) ShardRebalancer {
        return .{
            .allocator = allocator,
            .shard_locations = std.AutoHashMap([32]u8, ShardLocationEntry).init(allocator),
            .target_replication = target_replication,
            .rebalance_interval_secs = 60,
            .last_rebalance_time = 0,
            .mutex = .{},
            .shards_rebalanced = 0,
            .rebalance_rounds = 0,
        };
    }

    pub fn deinit(self: *ShardRebalancer) void {
        var iter = self.shard_locations.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.node_ids.deinit(self.allocator);
        }
        self.shard_locations.deinit();
    }

    /// Register that a shard is stored on a particular node
    pub fn registerShardLocation(self: *ShardRebalancer, shard_hash: [32]u8, node_id: [32]u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = try self.shard_locations.getOrPut(shard_hash);
        if (!result.found_existing) {
            result.value_ptr.* = .{ .node_ids = .{} };
        }

        // Don't add duplicate node_ids
        for (result.value_ptr.node_ids.items) |existing| {
            if (std.mem.eql(u8, &existing, &node_id)) return;
        }

        try result.value_ptr.node_ids.append(self.allocator, node_id);
    }

    /// Remove all shard locations for a node (node went offline)
    pub fn removeNode(self: *ShardRebalancer, node_id: [32]u8) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var affected: u32 = 0;
        var iter = self.shard_locations.iterator();
        while (iter.next()) |entry| {
            var i: usize = 0;
            while (i < entry.value_ptr.node_ids.items.len) {
                if (std.mem.eql(u8, &entry.value_ptr.node_ids.items[i], &node_id)) {
                    _ = entry.value_ptr.node_ids.swapRemove(i);
                    affected += 1;
                } else {
                    i += 1;
                }
            }
        }

        return affected;
    }

    /// Find shards with fewer replicas than target_replication
    pub fn findUnderReplicated(self: *ShardRebalancer, allocator: std.mem.Allocator) ![]UnderReplicatedShard {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged(UnderReplicatedShard){};
        errdefer result.deinit(allocator);

        var iter = self.shard_locations.iterator();
        while (iter.next()) |entry| {
            const count: u32 = @intCast(entry.value_ptr.node_ids.items.len);
            if (count < self.target_replication) {
                try result.append(allocator, .{
                    .shard_hash = entry.key_ptr.*,
                    .current_replicas = count,
                });
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Execute one round of rebalancing using local peers
    /// Copies under-replicated shards from existing holders to new peers
    pub fn rebalance(
        self: *ShardRebalancer,
        peers: []const *storage_mod.StorageProvider,
        peer_ids: []const [32]u8,
    ) !u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var rebalanced: u32 = 0;
        self.rebalance_rounds += 1;

        var iter = self.shard_locations.iterator();
        while (iter.next()) |entry| {
            const count: u32 = @intCast(entry.value_ptr.node_ids.items.len);
            if (count >= self.target_replication) continue;
            if (count == 0) continue; // No source to copy from

            const shard_hash = entry.key_ptr.*;
            const needed = self.target_replication - count;

            // Find a source node that has this shard
            var source_data: ?[]const u8 = null;
            for (entry.value_ptr.node_ids.items) |holder_id| {
                for (peers, 0..) |peer, pi| {
                    if (std.mem.eql(u8, &peer_ids[pi], &holder_id)) {
                        source_data = peer.shards.get(shard_hash);
                        if (source_data != null) break;
                    }
                }
                if (source_data != null) break;
            }

            if (source_data == null) continue;

            // Find target nodes that don't have this shard
            var copies_made: u32 = 0;
            for (peers, 0..) |peer, pi| {
                if (copies_made >= needed) break;

                const target_id = peer_ids[pi];
                // Skip if already holds this shard
                var already_has = false;
                for (entry.value_ptr.node_ids.items) |holder_id| {
                    if (std.mem.eql(u8, &holder_id, &target_id)) {
                        already_has = true;
                        break;
                    }
                }
                if (already_has) continue;

                // Copy shard to new peer
                _ = peer.storeShard(shard_hash, source_data.?) catch continue;
                entry.value_ptr.node_ids.append(self.allocator, target_id) catch continue;
                copies_made += 1;
                rebalanced += 1;
            }
        }

        self.shards_rebalanced += rebalanced;
        self.last_rebalance_time = std.time.timestamp();

        return rebalanced;
    }

    /// Get replica count for a shard
    pub fn getReplicaCount(self: *ShardRebalancer, shard_hash: [32]u8) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.shard_locations.get(shard_hash)) |entry| {
            return @intCast(entry.node_ids.items.len);
        }
        return 0;
    }

    /// Check if rebalance is needed
    pub fn shouldRebalance(self: *ShardRebalancer) bool {
        const now = std.time.timestamp();
        return (now - self.last_rebalance_time) >= self.rebalance_interval_secs;
    }

    /// Get all shard hashes held by a specific node (v1.6: for graceful shutdown)
    pub fn getShardLocationsForNode(self: *ShardRebalancer, node_id: [32]u8, allocator: std.mem.Allocator) ![][32]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged([32]u8){};
        errdefer result.deinit(allocator);

        var iter = self.shard_locations.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.node_ids.items) |holder_id| {
                if (std.mem.eql(u8, &holder_id, &node_id)) {
                    try result.append(allocator, entry.key_ptr.*);
                    break;
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Get stats
    pub fn getStats(self: *ShardRebalancer) RebalancerStats {
        return .{
            .shards_tracked = @intCast(self.shard_locations.count()),
            .shards_rebalanced = self.shards_rebalanced,
            .rebalance_rounds = self.rebalance_rounds,
            .target_replication = self.target_replication,
        };
    }
};

pub const RebalancerStats = struct {
    shards_tracked: u32,
    shards_rebalanced: u64,
    rebalance_rounds: u64,
    target_replication: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "register and track shard locations" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const shard_hash = [_]u8{0xAA} ** 32;
    const node1 = [_]u8{0x01} ** 32;
    const node2 = [_]u8{0x02} ** 32;
    const node3 = [_]u8{0x03} ** 32;

    try rebalancer.registerShardLocation(shard_hash, node1);
    try rebalancer.registerShardLocation(shard_hash, node2);
    try rebalancer.registerShardLocation(shard_hash, node3);

    try std.testing.expectEqual(@as(u32, 3), rebalancer.getReplicaCount(shard_hash));

    // Duplicate registration should not increase count
    try rebalancer.registerShardLocation(shard_hash, node1);
    try std.testing.expectEqual(@as(u32, 3), rebalancer.getReplicaCount(shard_hash));
}

test "removeNode reduces replica count" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const shard_hash = [_]u8{0xBB} ** 32;
    const node1 = [_]u8{0x01} ** 32;
    const node2 = [_]u8{0x02} ** 32;
    const node3 = [_]u8{0x03} ** 32;

    try rebalancer.registerShardLocation(shard_hash, node1);
    try rebalancer.registerShardLocation(shard_hash, node2);
    try rebalancer.registerShardLocation(shard_hash, node3);

    try std.testing.expectEqual(@as(u32, 3), rebalancer.getReplicaCount(shard_hash));

    const affected = rebalancer.removeNode(node2);
    try std.testing.expectEqual(@as(u32, 1), affected);
    try std.testing.expectEqual(@as(u32, 2), rebalancer.getReplicaCount(shard_hash));
}

test "findUnderReplicated detects missing replicas" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const shard1 = [_]u8{0xAA} ** 32;
    const shard2 = [_]u8{0xBB} ** 32;
    const node1 = [_]u8{0x01} ** 32;
    const node2 = [_]u8{0x02} ** 32;
    const node3 = [_]u8{0x03} ** 32;

    // shard1: 3 replicas (fully replicated)
    try rebalancer.registerShardLocation(shard1, node1);
    try rebalancer.registerShardLocation(shard1, node2);
    try rebalancer.registerShardLocation(shard1, node3);

    // shard2: only 2 replicas (under-replicated)
    try rebalancer.registerShardLocation(shard2, node1);
    try rebalancer.registerShardLocation(shard2, node2);

    const under = try rebalancer.findUnderReplicated(allocator);
    defer allocator.free(under);

    try std.testing.expectEqual(@as(usize, 1), under.len);
    try std.testing.expectEqualSlices(u8, &shard2, &under[0].shard_hash);
    try std.testing.expectEqual(@as(u32, 2), under[0].current_replicas);
}

test "rebalance redistributes under-replicated shards" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    // Create 5 storage providers
    const PEER_COUNT = 5;
    var nodes: [PEER_COUNT]storage_mod.StorageProvider = undefined;
    for (0..PEER_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..PEER_COUNT) |i| nodes[i].deinit();

    var peers: [PEER_COUNT]*storage_mod.StorageProvider = undefined;
    var peer_ids: [PEER_COUNT][32]u8 = undefined;
    for (0..PEER_COUNT) |i| {
        peers[i] = &nodes[i];
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Store a shard on peer 0 only
    var shard_data: [64]u8 = undefined;
    @memset(&shard_data, 0x42);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try nodes[0].storeShard(shard_hash, &shard_data);

    // Register only on peer 0
    try rebalancer.registerShardLocation(shard_hash, peer_ids[0]);
    try std.testing.expectEqual(@as(u32, 1), rebalancer.getReplicaCount(shard_hash));

    // Rebalance → should copy to 2 more peers (target=3)
    const rebalanced = try rebalancer.rebalance(&peers, &peer_ids);
    try std.testing.expectEqual(@as(u32, 2), rebalanced);
    try std.testing.expectEqual(@as(u32, 3), rebalancer.getReplicaCount(shard_hash));

    // Verify the shard is actually on the new peers
    var found_count: u32 = 0;
    for (0..PEER_COUNT) |i| {
        if (nodes[i].shards.get(shard_hash) != null) found_count += 1;
    }
    try std.testing.expectEqual(@as(u32, 3), found_count);
}

test "no rebalance when fully replicated" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 2);
    defer rebalancer.deinit();

    // Create 3 storage providers
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

    // Shard on 2 nodes (target=2, fully replicated)
    var shard_data: [64]u8 = undefined;
    @memset(&shard_data, 0x77);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    _ = try nodes[0].storeShard(shard_hash, &shard_data);
    _ = try nodes[1].storeShard(shard_hash, &shard_data);

    try rebalancer.registerShardLocation(shard_hash, peer_ids[0]);
    try rebalancer.registerShardLocation(shard_hash, peer_ids[1]);

    const rebalanced = try rebalancer.rebalance(&peers, &peer_ids);
    try std.testing.expectEqual(@as(u32, 0), rebalanced);
}

test "getShardLocationsForNode returns correct shards" {
    const allocator = std.testing.allocator;

    var rebalancer = ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    const node_a = [_]u8{0x01} ** 32;
    const node_b = [_]u8{0x02} ** 32;
    const shard1 = [_]u8{0xAA} ** 32;
    const shard2 = [_]u8{0xBB} ** 32;
    const shard3 = [_]u8{0xCC} ** 32;

    // node_a holds shard1 and shard2; node_b holds shard2 and shard3
    try rebalancer.registerShardLocation(shard1, node_a);
    try rebalancer.registerShardLocation(shard2, node_a);
    try rebalancer.registerShardLocation(shard2, node_b);
    try rebalancer.registerShardLocation(shard3, node_b);

    const node_a_shards = try rebalancer.getShardLocationsForNode(node_a, allocator);
    defer allocator.free(node_a_shards);

    try std.testing.expectEqual(@as(usize, 2), node_a_shards.len);

    const node_b_shards = try rebalancer.getShardLocationsForNode(node_b, allocator);
    defer allocator.free(node_b_shards);

    try std.testing.expectEqual(@as(usize, 2), node_b_shards.len);

    // Unknown node returns empty
    const unknown = [_]u8{0xFF} ** 32;
    const empty = try rebalancer.getShardLocationsForNode(unknown, allocator);
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}
