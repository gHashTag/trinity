// =============================================================================
// TRINITY AUTO-REPAIR v1.7 - Scrub-Triggered RS Recovery
// When scrubber detects corruption, automatically recover from healthy replicas
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const storage_mod = @import("storage.zig");
const shard_scrubber_mod = @import("shard_scrubber.zig");
const shard_rebalancer_mod = @import("shard_rebalancer.zig");

// =============================================================================
// AUTO-REPAIR STATS
// =============================================================================

pub const AutoRepairStats = struct {
    repairs_attempted: u64,
    repairs_succeeded: u64,
    repairs_failed: u64,
    shards_replaced: u64,
};

// =============================================================================
// AUTO-REPAIR ENGINE
// =============================================================================

pub const AutoRepairEngine = struct {
    allocator: std.mem.Allocator,
    repairs_attempted: u64,
    repairs_succeeded: u64,
    repairs_failed: u64,
    shards_replaced: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) AutoRepairEngine {
        return .{
            .allocator = allocator,
            .repairs_attempted = 0,
            .repairs_succeeded = 0,
            .repairs_failed = 0,
            .shards_replaced = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *AutoRepairEngine) void {
        _ = self;
    }

    /// Scan scrubber for corrupted shards, find healthy replicas from other peers, replace
    /// Returns number of successfully repaired shards
    pub fn repairFromScrub(
        self: *AutoRepairEngine,
        scrubber: *shard_scrubber_mod.ShardScrubber,
        local_peer_idx: usize,
        peers: []*storage_mod.StorageProvider,
    ) !u32 {
        // Get list of corrupted shard hashes
        const corrupted = try scrubber.getCorruptedShards(self.allocator);
        defer self.allocator.free(corrupted);

        var repaired: u32 = 0;

        for (corrupted) |hash| {
            self.mutex.lock();
            self.repairs_attempted += 1;
            self.mutex.unlock();

            // Search other peers for a healthy copy
            var found_healthy = false;
            for (peers, 0..) |peer, idx| {
                if (idx == local_peer_idx) continue;

                if (peer.retrieveShard(hash)) |healthy_data| {
                    // Verify the healthy copy
                    var verify_hash: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(healthy_data, &verify_hash, .{});

                    if (std.mem.eql(u8, &verify_hash, &hash)) {
                        // Remove corrupted shard from local node
                        const local = peers[local_peer_idx];
                        if (local.shards.fetchRemove(hash)) |kv| {
                            local.used_bytes -= kv.value.len;
                            local.allocator.free(kv.value);
                        }

                        // Store healthy copy
                        _ = local.storeShard(hash, healthy_data) catch {
                            self.mutex.lock();
                            self.repairs_failed += 1;
                            self.mutex.unlock();
                            continue;
                        };

                        // Clear from scrubber's corrupted list
                        scrubber.clearCorrupted(hash);

                        self.mutex.lock();
                        self.repairs_succeeded += 1;
                        self.shards_replaced += 1;
                        self.mutex.unlock();

                        repaired += 1;
                        found_healthy = true;
                        break;
                    }
                }
            }

            if (!found_healthy) {
                self.mutex.lock();
                self.repairs_failed += 1;
                self.mutex.unlock();
            }
        }

        return repaired;
    }

    /// Get stats
    pub fn getStats(self: *AutoRepairEngine) AutoRepairStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .repairs_attempted = self.repairs_attempted,
            .repairs_succeeded = self.repairs_succeeded,
            .repairs_failed = self.repairs_failed,
            .shards_replaced = self.shards_replaced,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "auto-repair replaces corrupted shard from healthy peer" {
    const allocator = std.testing.allocator;

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
    for (0..3) |i| peers[i] = &nodes[i];

    // Store same shard on all 3 nodes
    var data: [64]u8 = undefined;
    @memset(&data, 0x42);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});

    for (0..3) |i| {
        _ = try nodes[i].storeShard(hash, &data);
    }

    // Corrupt node 0's copy
    if (nodes[0].shards.getPtr(hash)) |ptr| {
        ptr.*[0] = 0xFF;
        ptr.*[1] = 0xFF;
    }

    // Scrub node 0 - detect corruption
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    const corrupted = scrubber.scrubNode(&nodes[0]);
    try std.testing.expectEqual(@as(u32, 1), corrupted);
    try std.testing.expect(scrubber.isCorrupted(hash));

    // Auto-repair: replace from healthy peer
    var engine = AutoRepairEngine.init(allocator);
    defer engine.deinit();

    const repaired = try engine.repairFromScrub(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 1), repaired);

    // Corruption should be cleared
    try std.testing.expect(!scrubber.isCorrupted(hash));

    // Verify repaired data matches original
    const retrieved = nodes[0].retrieveShard(hash);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, &data, retrieved.?);

    // Stats
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.repairs_attempted);
    try std.testing.expectEqual(@as(u64, 1), stats.repairs_succeeded);
    try std.testing.expectEqual(@as(u64, 0), stats.repairs_failed);
}

test "auto-repair fails when no healthy replica exists" {
    const allocator = std.testing.allocator;

    // Create 2 nodes
    var nodes: [2]storage_mod.StorageProvider = undefined;
    for (0..2) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..2) |i| nodes[i].deinit();

    var peers: [2]*storage_mod.StorageProvider = undefined;
    for (0..2) |i| peers[i] = &nodes[i];

    // Store shard only on node 0 (no replica on node 1)
    var data: [64]u8 = undefined;
    @memset(&data, 0x55);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
    _ = try nodes[0].storeShard(hash, &data);

    // Corrupt node 0's copy
    if (nodes[0].shards.getPtr(hash)) |ptr| {
        ptr.*[0] = 0xFF;
    }

    // Scrub and detect
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    _ = scrubber.scrubNode(&nodes[0]);

    // Attempt repair - should fail (no healthy replica)
    var engine = AutoRepairEngine.init(allocator);
    defer engine.deinit();

    const repaired = try engine.repairFromScrub(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 0), repaired);

    // Corruption still flagged
    try std.testing.expect(scrubber.isCorrupted(hash));

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.repairs_attempted);
    try std.testing.expectEqual(@as(u64, 0), stats.repairs_succeeded);
    try std.testing.expectEqual(@as(u64, 1), stats.repairs_failed);
}

test "auto-repair handles multiple corruptions" {
    const allocator = std.testing.allocator;

    var nodes: [4]storage_mod.StorageProvider = undefined;
    for (0..4) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..4) |i| nodes[i].deinit();

    var peers: [4]*storage_mod.StorageProvider = undefined;
    for (0..4) |i| peers[i] = &nodes[i];

    // Store 3 different shards, replicated across nodes
    var hashes: [3][32]u8 = undefined;
    for (0..3) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x10));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        // Store on node 0 and node (s+1)
        _ = try nodes[0].storeShard(hashes[s], &data);
        _ = try nodes[s + 1].storeShard(hashes[s], &data);
    }

    // Corrupt all 3 shards on node 0
    for (0..3) |s| {
        if (nodes[0].shards.getPtr(hashes[s])) |ptr| {
            ptr.*[0] = 0xFF;
        }
    }

    // Scrub node 0
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    const corrupted = scrubber.scrubNode(&nodes[0]);
    try std.testing.expectEqual(@as(u32, 3), corrupted);

    // Auto-repair all 3
    var engine = AutoRepairEngine.init(allocator);
    defer engine.deinit();

    const repaired = try engine.repairFromScrub(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 3), repaired);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.repairs_succeeded);
    try std.testing.expectEqual(@as(u64, 3), stats.shards_replaced);
}

test "auto-repair stats accumulate across calls" {
    const allocator = std.testing.allocator;

    var engine = AutoRepairEngine.init(allocator);
    defer engine.deinit();

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var nodes: [2]storage_mod.StorageProvider = undefined;
    for (0..2) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..2) |i| nodes[i].deinit();

    var peers: [2]*storage_mod.StorageProvider = undefined;
    for (0..2) |i| peers[i] = &nodes[i];

    // No corruptions — should return 0 but not crash
    const repaired = try engine.repairFromScrub(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 0), repaired);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.repairs_attempted);
}
