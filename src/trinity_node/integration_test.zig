// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY INTEGRATION TEST v2.6 - 800-Node Scale, WAL Disk Persistence
// Extends v2.5 (Parallel Step Execution, 700-Node Scale)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");
const shard_manager_mod = @import("shard_manager.zig");
const manifest_dht_mod = @import("manifest_dht.zig");
const storage_discovery = @import("storage_discovery.zig");
const protocol = @import("protocol.zig");
const connection_pool_mod = @import("connection_pool.zig");
// v1.5 modules
const proof_of_storage_mod = @import("proof_of_storage.zig");
const shard_rebalancer_mod = @import("shard_rebalancer.zig");
const bandwidth_aggregator_mod = @import("bandwidth_aggregator.zig");
// v1.6 modules
const shard_scrubber_mod = @import("shard_scrubber.zig");
const node_reputation_mod = @import("node_reputation.zig");
const graceful_shutdown_mod = @import("graceful_shutdown.zig");
const network_stats_mod = @import("network_stats.zig");
// v1.7 modules
const auto_repair_mod = @import("auto_repair.zig");
const incentive_slashing_mod = @import("incentive_slashing.zig");
const prometheus_metrics_mod = @import("prometheus_metrics.zig");
// v1.8 modules
const repair_rate_limiter_mod = @import("repair_rate_limiter.zig");
const token_staking_mod = @import("token_staking.zig");
const peer_latency_mod = @import("peer_latency.zig");
// v1.9 modules
const erasure_repair_mod = @import("erasure_repair.zig");
const reputation_consensus_mod = @import("reputation_consensus.zig");
const stake_delegation_mod = @import("stake_delegation.zig");
const reed_solomon_mod = @import("reed_solomon.zig");
// v2.0 modules
const region_topology_mod = @import("region_topology.zig");
const slashing_escrow_mod = @import("slashing_escrow.zig");
const prometheus_http_mod = @import("prometheus_http.zig");
// v2.1 modules
const cross_shard_tx_mod = @import("cross_shard_tx.zig");
const vsa_shard_locks_mod = @import("vsa_shard_locks.zig");
const region_router_mod = @import("region_router.zig");
// v2.2 modules
const dynamic_erasure_mod = @import("dynamic_erasure.zig");
// v2.3 modules
const saga_coordinator_mod = @import("saga_coordinator.zig");
// v2.4 modules
const transaction_wal_mod = @import("transaction_wal.zig");
// v2.5 modules
const parallel_saga_mod = @import("parallel_saga.zig");
// v2.6 modules
const wal_disk_mod = @import("wal_disk.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: 12-node RS store and retrieve with progressive failures
// ═══════════════════════════════════════════════════════════════════════════════

test "12-node RS store and retrieve with progressive failures" {
    const allocator = std.testing.allocator;

    // Create 12 storage providers (simulated nodes)
    const NODE_COUNT = 12;
    const SHARD_SIZE = 512;
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024, // 1 MB per node
            .shard_size = SHARD_SIZE,
            .replication_factor = 1,
            .rs_parity_ratio = 0.5, // 50% parity
        });
    }
    defer {
        for (0..NODE_COUNT) |i| {
            nodes[i].deinit();
        }
    }

    // Build peer array
    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        peers[i] = &nodes[i];
    }

    // Configuration with RS enabled
    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = SHARD_SIZE,
        .replication_factor = 1,
        .rs_parity_ratio = 0.5,
    };

    const sm = shard_manager_mod.ShardManager.init(allocator, config);

    // Create test file: 2KB of patterned data
    var file_data: [2048]u8 = undefined;
    for (0..2048) |i| {
        file_data[i] = @intCast((i * 7 + 13) % 256);
    }

    const key = [_]u8{0xDE} ** 32;

    // Store file across 12 nodes
    const manifest = try sm.storeFile(&file_data, "integration_test_8kb.bin", key, &peers);
    defer allocator.free(manifest.shard_hashes);

    // Verify RS fields are set
    try std.testing.expect(manifest.hasReedSolomon());
    try std.testing.expect(manifest.rs_data_shards > 0);
    try std.testing.expect(manifest.rs_parity_shards > 0);
    try std.testing.expectEqual(manifest.rs_data_shards + manifest.rs_parity_shards, manifest.shard_count);

    const data_shards = manifest.rs_data_shards;
    const parity_shards = manifest.rs_parity_shards;

    // Test 1: Retrieve with all nodes alive — byte-exact
    {
        const recovered = try sm.retrieveFile(&manifest, key, &peers);
        defer allocator.free(recovered);
        try std.testing.expectEqualSlices(u8, &file_data, recovered);
    }

    // Test 2: Kill 1 data shard, RS recovers
    {
        // Remove shard 0 from its node
        var removed_data: ?[]const u8 = null;
        for (0..NODE_COUNT) |n| {
            if (nodes[n].shards.fetchRemove(manifest.shard_hashes[0])) |kv| {
                removed_data = kv.value;
                break;
            }
        }
        defer if (removed_data) |d| allocator.free(d);

        const recovered = try sm.retrieveFile(&manifest, key, &peers);
        defer allocator.free(recovered);
        try std.testing.expectEqualSlices(u8, &file_data, recovered);
    }

    // Test 3: Kill more shards (up to parity_shards total) — RS still recovers
    // We already removed 1. Remove parity_shards - 1 more = total parity_shards missing.
    {
        var removed_extras = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (removed_extras.items) |d| allocator.free(d);
            removed_extras.deinit(allocator);
        }

        var killed: u32 = 1; // Already killed 1
        var shard_idx: u32 = 1;
        while (killed < parity_shards and shard_idx < manifest.shard_count) : (shard_idx += 1) {
            for (0..NODE_COUNT) |n| {
                if (nodes[n].shards.fetchRemove(manifest.shard_hashes[shard_idx])) |kv| {
                    try removed_extras.append(allocator, kv.value);
                    killed += 1;
                    break;
                }
            }
        }

        // Should still recover (exactly parity_shards missing = k data shards present)
        const recovered = try sm.retrieveFile(&manifest, key, &peers);
        defer allocator.free(recovered);
        try std.testing.expectEqualSlices(u8, &file_data, recovered);
    }

    // Test 4: Kill one more shard — exceeds RS tolerance, should fail
    {
        // Find one more shard to remove
        var found_extra = false;
        for (parity_shards..manifest.shard_count) |idx| {
            for (0..NODE_COUNT) |n| {
                if (nodes[n].shards.fetchRemove(manifest.shard_hashes[idx])) |kv| {
                    allocator.free(kv.value);
                    found_extra = true;
                    break;
                }
            }
            if (found_extra) break;
        }

        if (found_extra) {
            // Now we have parity_shards + 1 missing, which exceeds RS capacity
            const result = sm.retrieveFile(&manifest, key, &peers);
            try std.testing.expectError(error.ShardNotFound, result);
        }
    }

    _ = data_shards;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: 10-node bandwidth tracking under load
// ═══════════════════════════════════════════════════════════════════════════════

test "10-node bandwidth tracking under load" {
    const allocator = std.testing.allocator;

    const NODE_COUNT = 10;
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 128,
            .replication_factor = 1,
            .rs_parity_ratio = 0.5,
        });
    }
    defer {
        for (0..NODE_COUNT) |i| {
            nodes[i].deinit();
        }
    }

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        peers[i] = &nodes[i];
    }

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 128,
        .replication_factor = 1,
        .rs_parity_ratio = 0.5,
    };

    const sm = shard_manager_mod.ShardManager.init(allocator, config);
    const key = [_]u8{0xAB} ** 32;

    // Store 3 files of different sizes
    const sizes = [_]usize{ 1024, 2048, 4096 };
    var manifests: [3]storage_mod.FileManifest = undefined;
    var shard_hash_allocs: [3]?[]const [32]u8 = .{ null, null, null };

    defer {
        for (0..3) |i| {
            if (shard_hash_allocs[i]) |hashes| allocator.free(hashes);
        }
    }

    for (sizes, 0..) |size, i| {
        const data = try allocator.alloc(u8, size);
        defer allocator.free(data);
        for (0..size) |j| data[j] = @intCast((j * 11 + i * 37) % 256);

        manifests[i] = try sm.storeFile(data, "test_file.bin", key, &peers);
        shard_hash_allocs[i] = manifests[i].shard_hashes;
    }

    // Count total shards stored across all nodes
    var total_shards: u64 = 0;
    for (0..NODE_COUNT) |n| {
        total_shards += nodes[n].getStats().total_shards;
    }

    // Should have distributed shards
    try std.testing.expect(total_shards > 0);

    // Each file's manifest should have RS info
    for (0..3) |i| {
        try std.testing.expect(manifests[i].hasReedSolomon());
    }

    // Verify all files retrievable
    for (sizes, 0..) |size, i| {
        const recovered = try sm.retrieveFile(&manifests[i], key, &peers);
        defer allocator.free(recovered);
        try std.testing.expectEqual(size, recovered.len);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: 10-node manifest DHT resilience
// ═══════════════════════════════════════════════════════════════════════════════

test "10-node manifest DHT resilience" {
    const allocator = std.testing.allocator;

    // Create peer registry with 10 peers
    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const NODE_COUNT = 10;
    var node_ids: [NODE_COUNT][32]u8 = undefined;
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9333);

    for (0..NODE_COUNT) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
        const announce = protocol.StorageAnnounce{
            .node_id = node_ids[i],
            .available_bytes = 1024 * 1024,
            .total_bytes = 10 * 1024 * 1024,
            .shard_count = 0,
            .timestamp = std.time.timestamp(),
        };
        registry.updateFromAnnounce(announce, addr);
    }

    // Create local DHT node
    const local_id = [_]u8{0xFF} ** 32;
    var dht = manifest_dht_mod.ManifestDHT.init(allocator, &registry, local_id);
    defer dht.deinit();

    // Store 5 manifests
    for (0..5) |i| {
        var file_id: [32]u8 = undefined;
        @memset(&file_id, @intCast(i + 0x10));
        const data = try std.fmt.allocPrint(allocator, "manifest_data_{d}", .{i});
        defer allocator.free(data);
        try dht.storeManifest(file_id, data);
    }

    // Verify all 5 are retrievable locally
    for (0..5) |i| {
        var file_id: [32]u8 = undefined;
        @memset(&file_id, @intCast(i + 0x10));
        const retrieved = dht.getManifest(file_id);
        try std.testing.expect(retrieved != null);
    }

    // Stats check
    try std.testing.expectEqual(@as(u32, 5), dht.getManifestCount());
    try std.testing.expectEqual(@as(u64, 5), dht.manifests_stored);

    // Simulate receiving manifests from peers (handleManifestStore)
    for (0..3) |i| {
        var file_id: [32]u8 = undefined;
        @memset(&file_id, @intCast(i + 0x50));
        const data = try std.fmt.allocPrint(allocator, "remote_manifest_{d}", .{i});
        defer allocator.free(data);
        try dht.handleManifestStore(file_id, data);
    }

    // Now 8 manifests stored locally
    try std.testing.expectEqual(@as(u32, 8), dht.getManifestCount());

    // Verify findResponsiblePeers returns correct count
    const file_id = [_]u8{0x42} ** 32;
    const responsible = try dht.findResponsiblePeers(file_id);
    defer allocator.free(responsible);
    try std.testing.expectEqual(@as(usize, 3), responsible.len); // replication_factor=3
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST: Connection pool creation
// ═══════════════════════════════════════════════════════════════════════════════

test "connection pool lifecycle" {
    var pool = connection_pool_mod.ConnectionPool.init(std.testing.allocator);
    defer pool.deinit();

    // Verify initial state
    try std.testing.expectEqual(@as(u32, 0), pool.getTotalConnections());
    try std.testing.expectEqual(@as(u32, 0), pool.getActiveConnections());

    // Prune with no connections
    try std.testing.expectEqual(@as(u32, 0), pool.pruneIdle());

    // Check stats
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.total_acquired);
    try std.testing.expectEqual(@as(u64, 0), stats.total_pruned);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.5 INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "v1.5: node churn — 10 nodes with dynamic join and leave" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 10;
    const TARGET_REPLICATION = 3;

    // Create 10 storage providers
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Create rebalancer
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, TARGET_REPLICATION);
    defer rebalancer.deinit();

    // Store 3 files (3 shards each → 9 unique shard hashes)
    var shard_hashes: [3][32]u8 = undefined;
    for (0..3) |f| {
        var shard_data: [64]u8 = undefined;
        @memset(&shard_data, @intCast(f * 42 + 7));
        std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hashes[f], .{});

        // Store on first 3 nodes (fully replicated)
        for (0..TARGET_REPLICATION) |n| {
            _ = try nodes[n].storeShard(shard_hashes[f], &shard_data);
            try rebalancer.registerShardLocation(shard_hashes[f], peer_ids[n]);
        }
    }

    // Verify all shards at target replication
    for (0..3) |f| {
        try std.testing.expectEqual(@as(u32, TARGET_REPLICATION), rebalancer.getReplicaCount(shard_hashes[f]));
    }

    // "Kill" nodes 0, 1, 2 (remove from rebalancer)
    for (0..3) |n| {
        _ = rebalancer.removeNode(peer_ids[n]);
    }

    // All shards now at 0 replicas — under-replicated
    for (0..3) |f| {
        try std.testing.expectEqual(@as(u32, 0), rebalancer.getReplicaCount(shard_hashes[f]));
    }

    // Re-store shard data on nodes 3-5 as "new replica sources"
    for (0..3) |f| {
        var shard_data: [64]u8 = undefined;
        @memset(&shard_data, @intCast(f * 42 + 7));
        _ = try nodes[3].storeShard(shard_hashes[f], &shard_data);
        try rebalancer.registerShardLocation(shard_hashes[f], peer_ids[3]);
    }

    // Rebalance — should copy to 2 more peers each
    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    const rebalanced = try rebalancer.rebalance(&peers, &peer_ids);

    // Each of 3 shards needs 2 more copies = 6 total
    try std.testing.expectEqual(@as(u32, 6), rebalanced);

    // All shards now at target replication
    for (0..3) |f| {
        try std.testing.expectEqual(@as(u32, TARGET_REPLICATION), rebalancer.getReplicaCount(shard_hashes[f]));
    }

    // Stats check
    const rb_stats = rebalancer.getStats();
    try std.testing.expectEqual(@as(u64, 6), rb_stats.shards_rebalanced);
    try std.testing.expectEqual(@as(u64, 1), rb_stats.rebalance_rounds);
}

test "v1.5: proof-of-storage challenge round across 8 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 8;

    // Create 8 storage providers with shared shard data
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 128,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Store same shard on all 8 nodes
    var shard_data: [128]u8 = undefined;
    for (0..128) |i| shard_data[i] = @intCast((i * 13 + 7) % 256);
    var shard_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hash, .{});
    for (0..NODE_COUNT) |i| {
        _ = try nodes[i].storeShard(shard_hash, &shard_data);
    }

    // Challenger engine (node 0 is the challenger)
    var engine = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer engine.deinit();

    // Challenge each of the other 7 nodes — all should pass
    for (1..NODE_COUNT) |i| {
        const challenge = try engine.createChallenge(peer_ids[0], peer_ids[i], shard_hash, 128);
        const proof = try proof_of_storage_mod.ProofOfStorageEngine.respondToChallenge(challenge, &nodes[i], peer_ids[i]);
        const valid = try engine.verifyProof(proof, &nodes[0]);
        try std.testing.expect(valid);
    }

    try std.testing.expectEqual(@as(u64, 7), engine.challenges_issued);
    try std.testing.expectEqual(@as(u64, 7), engine.challenges_passed);
    try std.testing.expectEqual(@as(u64, 0), engine.challenges_failed);

    // Simulate tampered node 7 by sending a fake proof with wrong hash
    const bad_challenge = try engine.createChallenge(peer_ids[0], peer_ids[7], shard_hash, 128);
    const fake_proof = protocol.StorageProofMsg{
        .challenge_id = bad_challenge.challenge_id,
        .prover_id = peer_ids[7],
        .proof_hash = [_]u8{0xFF} ** 32, // Wrong hash — simulates corrupted data
        .timestamp = std.time.timestamp(),
    };
    const bad_valid = try engine.verifyProof(fake_proof, &nodes[0]);
    try std.testing.expect(!bad_valid);
    try std.testing.expectEqual(@as(u64, 1), engine.challenges_failed);
    try std.testing.expectEqual(@as(u32, 1), engine.getFailureCount(peer_ids[7]));
}

test "v1.5: bandwidth aggregation across 10 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 10;

    var aggregator = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer aggregator.deinit();

    // Create 10 RewardTrackers with increasing bandwidth
    var trackers: [NODE_COUNT]storage_mod.RewardTracker = undefined;
    var peer_ids: [NODE_COUNT][32]u8 = undefined;

    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
        trackers[i] = storage_mod.RewardTracker{
            .shards_hosted = @as(u64, (i + 1)) * 10,
            .retrievals_served = @as(u64, (i + 1)) * 5,
            .hosting_start = std.time.timestamp() - 3600,
            .bytes_uploaded = @as(u64, (i + 1)) * 100 * 1024 * 1024, // (i+1)*100 MB
            .bytes_downloaded = @as(u64, (i + 1)) * 50 * 1024 * 1024, // (i+1)*50 MB
        };

        // Generate local report and record it
        const report = bandwidth_aggregator_mod.BandwidthAggregator.generateLocalReport(&trackers[i], peer_ids[i]);
        aggregator.recordReport(report);
    }

    // Verify report count
    try std.testing.expectEqual(@as(u32, NODE_COUNT), aggregator.getReportCount());

    // Aggregate
    const summary = aggregator.aggregate();
    try std.testing.expectEqual(@as(u32, NODE_COUNT), summary.node_count);

    // Total upload = (1+2+...+10) * 100 MB = 55 * 100 MB
    const expected_upload: u64 = 55 * 100 * 1024 * 1024;
    try std.testing.expectEqual(expected_upload, summary.total_upload);

    // Total download = (1+2+...+10) * 50 MB = 55 * 50 MB
    const expected_download: u64 = 55 * 50 * 1024 * 1024;
    try std.testing.expectEqual(expected_download, summary.total_download);

    // Total throughput
    const total_throughput = aggregator.getTotalThroughput();
    try std.testing.expectEqual(expected_upload + expected_download, total_throughput);

    // Verify proportional reward shares
    // Node 1: (100+50) MB of total (55*150 MB) = 150/(55*150) = 1/55
    // Node 10: (1000+500) MB of total = 1500/(55*150) = 10/55
    const share1 = aggregator.getRewardShare(peer_ids[0]);
    const share10 = aggregator.getRewardShare(peer_ids[9]);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 55.0), share1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0 / 55.0), share10, 0.001);

    // All shares sum to 1.0
    var share_sum: f64 = 0.0;
    for (0..NODE_COUNT) |i| {
        share_sum += aggregator.getRewardShare(peer_ids[i]);
    }
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), share_sum, 0.001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.6 INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "v1.6: 20-node multi-file RS with churn, PoS, and bandwidth" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 20;
    const TARGET_REPLICATION = 3;

    // Create 20 storage providers
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0.5,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    const config = storage_mod.StorageConfig{
        .max_bytes = 1024 * 1024,
        .shard_size = 64,
        .replication_factor = 1,
        .rs_parity_ratio = 0.5,
    };
    const sm = shard_manager_mod.ShardManager.init(allocator, config);
    const key = [_]u8{0xDE} ** 32;

    // Store 5 files of increasing size
    const FILE_COUNT = 5;
    const file_sizes = [FILE_COUNT]usize{ 256, 512, 1024, 2048, 4096 };
    var manifests: [FILE_COUNT]storage_mod.FileManifest = undefined;
    var shard_allocs: [FILE_COUNT]?[]const [32]u8 = .{ null, null, null, null, null };
    defer for (0..FILE_COUNT) |i| {
        if (shard_allocs[i]) |h| allocator.free(h);
    };

    for (file_sizes, 0..) |size, i| {
        const data = try allocator.alloc(u8, size);
        defer allocator.free(data);
        for (0..size) |j| data[j] = @intCast((j * 11 + i * 37 + 3) % 256);
        manifests[i] = try sm.storeFile(data, "test_file.bin", key, &peers);
        shard_allocs[i] = manifests[i].shard_hashes;
    }

    // Verify all files retrievable
    for (file_sizes, 0..) |size, i| {
        const recovered = try sm.retrieveFile(&manifests[i], key, &peers);
        defer allocator.free(recovered);
        try std.testing.expectEqual(size, recovered.len);
    }

    // Register all shards in rebalancer
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, TARGET_REPLICATION);
    defer rebalancer.deinit();

    for (0..FILE_COUNT) |f| {
        for (0..manifests[f].shard_count) |s| {
            const hash = manifests[f].shard_hashes[s];
            // Find which node has it and register
            for (0..NODE_COUNT) |n| {
                if (nodes[n].shards.contains(hash)) {
                    try rebalancer.registerShardLocation(hash, peer_ids[n]);
                }
            }
        }
    }

    // Set up bandwidth aggregator
    var aggregator = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer aggregator.deinit();

    for (0..NODE_COUNT) |i| {
        var tracker = storage_mod.RewardTracker{
            .shards_hosted = nodes[i].getStats().total_shards,
            .retrievals_served = @as(u64, i + 1) * 3,
            .hosting_start = std.time.timestamp() - 3600,
            .bytes_uploaded = @as(u64, (i + 1)) * 50 * 1024 * 1024,
            .bytes_downloaded = @as(u64, (i + 1)) * 25 * 1024 * 1024,
        };
        const report = bandwidth_aggregator_mod.BandwidthAggregator.generateLocalReport(&tracker, peer_ids[i]);
        aggregator.recordReport(report);
    }

    try std.testing.expectEqual(@as(u32, NODE_COUNT), aggregator.getReportCount());

    // Simulate churn: kill nodes 0-3 (4 nodes depart)
    for (0..4) |n| {
        _ = rebalancer.removeNode(peer_ids[n]);
    }

    // Rebalance — redistribute shards to remaining 16 nodes
    const rebalanced = try rebalancer.rebalance(&peers, &peer_ids);
    try std.testing.expect(rebalanced > 0);

    // Set up PoS engine and challenge nodes that hold shards
    var engine = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer engine.deinit();

    // Find a shard that exists on at least 2 nodes (for challenger + prover)
    var challenger_idx: usize = 0;
    var prover_idx: usize = 1;
    var test_hash: [32]u8 = undefined;
    var found_pos_pair = false;

    outer: for (0..FILE_COUNT) |f| {
        for (0..manifests[f].shard_count) |s| {
            const hash = manifests[f].shard_hashes[s];
            var holders: [NODE_COUNT]usize = undefined;
            var holder_count: usize = 0;
            for (0..NODE_COUNT) |n| {
                if (nodes[n].shards.contains(hash)) {
                    holders[holder_count] = n;
                    holder_count += 1;
                    if (holder_count >= 2) {
                        challenger_idx = holders[0];
                        prover_idx = holders[1];
                        test_hash = hash;
                        found_pos_pair = true;
                        break :outer;
                    }
                }
            }
        }
    }

    if (found_pos_pair) {
        // Get actual shard data length for challenge
        const actual_data = nodes[prover_idx].shards.get(test_hash) orelse unreachable;
        const actual_len: u32 = @intCast(actual_data.len);
        const challenge = try engine.createChallenge(peer_ids[challenger_idx], peer_ids[prover_idx], test_hash, actual_len);
        const proof = try proof_of_storage_mod.ProofOfStorageEngine.respondToChallenge(challenge, &nodes[prover_idx], peer_ids[prover_idx]);
        const valid = try engine.verifyProof(proof, &nodes[challenger_idx]);
        try std.testing.expect(valid);
    }

    // Bandwidth check
    const summary = aggregator.aggregate();
    try std.testing.expectEqual(@as(u32, NODE_COUNT), summary.node_count);
    try std.testing.expect(summary.total_upload > 0);
    try std.testing.expect(summary.total_download > 0);
}

test "v1.6: shard scrubbing across 20 nodes — detect corruption" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 20;

    // Create 20 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    // Store 1 shard per node (20 unique shards)
    var shard_hashes: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(i + 42));
        std.crypto.hash.sha2.Sha256.hash(&data, &shard_hashes[i], .{});
        _ = try nodes[i].storeShard(shard_hashes[i], &data);
    }

    // Create scrubber and scrub all nodes — should be clean
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    for (0..NODE_COUNT) |i| {
        const corrupted = scrubber.scrubNode(&nodes[i]);
        try std.testing.expectEqual(@as(u32, 0), corrupted);
    }

    var stats = scrubber.getStats();
    try std.testing.expectEqual(@as(u64, 20), stats.shards_checked);
    try std.testing.expectEqual(@as(u64, 0), stats.corruptions_found);

    // Tamper with 2 nodes (nodes 5 and 15) — corrupt their shard data
    for ([_]usize{ 5, 15 }) |n| {
        if (nodes[n].shards.getPtr(shard_hashes[n])) |data_ptr| {
            // Flip some bytes to simulate bit-rot
            data_ptr.*[0] ^= 0xFF;
            data_ptr.*[1] ^= 0xFF;
        }
    }

    // Re-scrub all nodes — should find exactly 2 corruptions
    for (0..NODE_COUNT) |i| {
        _ = scrubber.scrubNode(&nodes[i]);
    }

    stats = scrubber.getStats();
    try std.testing.expectEqual(@as(u64, 40), stats.shards_checked); // 20 + 20
    try std.testing.expectEqual(@as(u64, 2), stats.corruptions_found);

    // Verify the corrupted hashes are tracked
    try std.testing.expect(scrubber.isCorrupted(shard_hashes[5]));
    try std.testing.expect(scrubber.isCorrupted(shard_hashes[15]));
    try std.testing.expect(!scrubber.isCorrupted(shard_hashes[0]));

    const corrupted_list = try scrubber.getCorruptedShards(allocator);
    defer allocator.free(corrupted_list);
    try std.testing.expectEqual(@as(usize, 2), corrupted_list.len);
}

test "v1.6: node reputation ranking with 20 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 20;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Each node gets proportional PoS results, uptime, and bandwidth
    for (0..NODE_COUNT) |i| {
        // PoS: node i passes (i+1) out of 20 challenges
        for (0..(i + 1)) |_| {
            reputation.recordPosResult(peer_ids[i], true);
        }
        for (0..(19 - i)) |_| {
            reputation.recordPosResult(peer_ids[i], false);
        }

        // Uptime: proportional to index
        reputation.recordUptime(peer_ids[i], @as(u64, (i + 1)) * 180, 3600);

        // Bandwidth: proportional to index
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 1024 * 1024);
    }

    // Rank all nodes
    const ranked = try reputation.rankNodes(allocator);
    defer allocator.free(ranked);
    try std.testing.expectEqual(@as(usize, NODE_COUNT), ranked.len);

    // Should be sorted descending — node 20 (index 19) should be first
    try std.testing.expect(ranked[0].score >= ranked[1].score);
    try std.testing.expect(ranked[0].score >= ranked[NODE_COUNT - 1].score);

    // Last node should have lowest score
    try std.testing.expect(ranked[NODE_COUNT - 1].score <= ranked[0].score);

    // Top node should be peer_ids[19] (highest PoS, uptime, bandwidth)
    try std.testing.expectEqualSlices(u8, &peer_ids[19], &ranked[0].node_id);

    // Bottom node should be peer_ids[0] (lowest everything)
    try std.testing.expectEqualSlices(u8, &peer_ids[0], &ranked[NODE_COUNT - 1].node_id);

    // Select top 5 peers, excluding node 19
    const best = try reputation.selectBestPeers(5, peer_ids[19], allocator);
    defer allocator.free(best);
    try std.testing.expectEqual(@as(usize, 5), best.len);
    // None should be peer_ids[19]
    for (best) |id| {
        try std.testing.expect(!std.mem.eql(u8, &id, &peer_ids[19]));
    }
}

test "v1.6: graceful shutdown redistribution — 10 nodes, 1 departs" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 10;
    const TARGET_REPLICATION = 3;

    // Create 10 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Create rebalancer
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, TARGET_REPLICATION);
    defer rebalancer.deinit();

    // Store 5 shards on node 0, with replication across nodes 1, 2
    var shard_hashes: [5][32]u8 = undefined;
    for (0..5) |f| {
        var shard_data: [64]u8 = undefined;
        @memset(&shard_data, @intCast(f * 33 + 7));
        std.crypto.hash.sha2.Sha256.hash(&shard_data, &shard_hashes[f], .{});

        // Store on nodes 0, 1, 2
        for (0..TARGET_REPLICATION) |n| {
            _ = try nodes[n].storeShard(shard_hashes[f], &shard_data);
            try rebalancer.registerShardLocation(shard_hashes[f], peer_ids[n]);
        }
    }

    // Verify: all 5 shards at replication 3
    for (0..5) |f| {
        try std.testing.expectEqual(@as(u32, TARGET_REPLICATION), rebalancer.getReplicaCount(shard_hashes[f]));
    }

    // Graceful shutdown of node 0
    var shutdown_mgr = graceful_shutdown_mod.GracefulShutdownManager.init(allocator);
    defer shutdown_mgr.deinit();

    // Initiate — should find 5 shards to redistribute
    const plan = try shutdown_mgr.initiateShutdown(peer_ids[0], &rebalancer);
    try std.testing.expectEqual(@as(u32, 5), plan.shards_to_move);
    try std.testing.expect(shutdown_mgr.isShuttingDown(peer_ids[0]));

    // Execute — removes node 0 from rebalancer, rebalances
    const moved = try shutdown_mgr.executeShutdown(peer_ids[0], &rebalancer, &peers, &peer_ids);

    // Node 0 was removed, 5 shards lost 1 replica each → 5 rebalanced
    try std.testing.expectEqual(@as(u32, 5), moved);

    // All shards should be back at target replication
    for (0..5) |f| {
        try std.testing.expectEqual(@as(u32, TARGET_REPLICATION), rebalancer.getReplicaCount(shard_hashes[f]));
    }

    // Stats
    try std.testing.expectEqual(@as(u64, 1), shutdown_mgr.completed_plans);
    try std.testing.expectEqual(@as(u64, 5), shutdown_mgr.total_shards_moved);
}

test "v1.6: network stats report with 20 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 20;
    const TARGET_REPLICATION = 3;

    // Set up storage providers
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Rebalancer
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, TARGET_REPLICATION);
    defer rebalancer.deinit();

    // Store 10 shards across first 3 nodes
    for (0..10) |f| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(f + 100));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        for (0..TARGET_REPLICATION) |n| {
            _ = try nodes[n].storeShard(hash, &data);
            try rebalancer.registerShardLocation(hash, peer_ids[n]);
        }
    }

    // PoS engine
    var pos = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer pos.deinit();

    // Bandwidth aggregator
    var bw_agg = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer bw_agg.deinit();

    for (0..NODE_COUNT) |i| {
        var tracker = storage_mod.RewardTracker{
            .shards_hosted = nodes[i].getStats().total_shards,
            .retrievals_served = @as(u64, i + 1),
            .hosting_start = std.time.timestamp() - 3600,
            .bytes_uploaded = @as(u64, (i + 1)) * 10 * 1024 * 1024,
            .bytes_downloaded = @as(u64, (i + 1)) * 5 * 1024 * 1024,
        };
        const report = bandwidth_aggregator_mod.BandwidthAggregator.generateLocalReport(&tracker, peer_ids[i]);
        bw_agg.recordReport(report);
    }

    // Storage peer registry
    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    for (0..NODE_COUNT) |i| {
        registry.updateFromAnnounce(.{
            .node_id = peer_ids[i],
            .available_bytes = @as(u64, (i + 1)) * 50 * 1024,
            .total_bytes = 1024 * 1024,
            .shard_count = @intCast(nodes[i].getStats().total_shards),
            .timestamp = std.time.timestamp(),
        }, null);
    }

    // Scrubber (optional v1.6)
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    // Scrub first 5 nodes
    for (0..5) |i| {
        _ = scrubber.scrubNode(&nodes[i]);
    }

    // Reputation (optional v1.6)
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    for (0..NODE_COUNT) |i| {
        for (0..10) |_| reputation.recordPosResult(peer_ids[i], true);
        reputation.recordUptime(peer_ids[i], 3500, 3600);
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 1024 * 1024);
    }

    // Generate report
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const health = reporter.generateReport(&peers, &rebalancer, &pos, &bw_agg, &registry, &scrubber, &reputation);

    try std.testing.expectEqual(@as(u32, NODE_COUNT), health.node_count);
    try std.testing.expect(health.total_shards > 0);
    try std.testing.expect(health.total_bytes_used > 0);
    try std.testing.expect(health.total_upload + health.total_download > 0);

    // Format as text
    const text = try reporter.formatText(health);
    defer allocator.free(text);
    try std.testing.expect(text.len > 0);

    // Format as JSON
    const json = try reporter.formatJson(health);
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);
    // JSON should contain "node_count"
    try std.testing.expect(std.mem.indexOf(u8, json, "node_count") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.7 INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "v1.7: 30-node auto-repair from scrub — detect and recover corruption" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 30;

    // Create 30 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Store 10 shards, each replicated on 3 consecutive nodes
    var shard_hashes: [10][32]u8 = undefined;
    for (0..10) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 42));
        std.crypto.hash.sha2.Sha256.hash(&data, &shard_hashes[s], .{});

        // Store on nodes s*3, s*3+1, s*3+2
        for (0..3) |r| {
            const node_idx = (s * 3 + r) % NODE_COUNT;
            _ = try nodes[node_idx].storeShard(shard_hashes[s], &data);
        }
    }

    // Corrupt shard_hashes[0] on node 0, shard_hashes[3] on node 9, shard_hashes[6] on node 18
    const corrupt_shards = [_]usize{ 0, 3, 6 };
    for (corrupt_shards) |s| {
        const node_idx = (s * 3) % NODE_COUNT;
        if (nodes[node_idx].shards.getPtr(shard_hashes[s])) |ptr| {
            ptr.*[0] ^= 0xFF;
            ptr.*[1] ^= 0xFF;
        }
    }

    // Scrub all 30 nodes to detect corruptions
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    var total_corrupt: u32 = 0;
    for (0..NODE_COUNT) |i| {
        total_corrupt += scrubber.scrubNode(&nodes[i]);
    }

    try std.testing.expectEqual(@as(u32, 3), total_corrupt);

    // Auto-repair: scan all nodes for corrupted shards
    var repair_engine = auto_repair_mod.AutoRepairEngine.init(allocator);
    defer repair_engine.deinit();

    var total_repaired: u32 = 0;
    for (0..NODE_COUNT) |i| {
        total_repaired += try repair_engine.repairFromScrub(&scrubber, i, &peers);
    }

    // All 3 corruptions should be repaired
    try std.testing.expectEqual(@as(u32, 3), total_repaired);

    const repair_stats = repair_engine.getStats();
    try std.testing.expectEqual(@as(u64, 3), repair_stats.repairs_succeeded);
    try std.testing.expectEqual(@as(u64, 0), repair_stats.repairs_failed);
    try std.testing.expectEqual(@as(u64, 3), repair_stats.shards_replaced);

    // Verify: scrubber should have no corrupted shards left
    const remaining = try scrubber.getCorruptedShards(allocator);
    defer allocator.free(remaining);
    try std.testing.expectEqual(@as(usize, 0), remaining.len);
}

test "v1.7: 30-node incentive slashing — bad nodes get reduced rewards" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 30;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // First 10 nodes: bad reputation (2/10 PoS)
    for (0..10) |i| {
        for (0..10) |j| {
            reputation.recordPosResult(peer_ids[i], j < 2);
        }
    }

    // Middle 10 nodes: medium reputation (6/10 PoS + some uptime)
    for (10..20) |i| {
        for (0..10) |j| {
            reputation.recordPosResult(peer_ids[i], j < 6);
        }
        reputation.recordUptime(peer_ids[i], 1800, 3600); // 50% uptime
    }

    // Last 10 nodes: good reputation (10/10 PoS + full uptime + bandwidth)
    for (20..30) |i| {
        for (0..10) |_| {
            reputation.recordPosResult(peer_ids[i], true);
        }
        reputation.recordUptime(peer_ids[i], 3600, 3600);
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 1024 * 1024);
    }

    // Create slashing engine
    var slasher = incentive_slashing_mod.IncentiveSlashingEngine.init(allocator);
    defer slasher.deinit();

    const base_reward: u128 = 1_000_000_000_000_000_000; // 1 TRI

    // Evaluate all 30 nodes
    var total_slashed_count: u32 = 0;
    var total_unslashed_count: u32 = 0;

    for (0..NODE_COUNT) |i| {
        const result = slasher.evaluateReward(peer_ids[i], base_reward, &reputation);
        if (result.was_slashed) {
            total_slashed_count += 1;
            // Slashed reward should be less than original
            try std.testing.expect(result.slashed_reward_wei < base_reward);
        } else {
            total_unslashed_count += 1;
            try std.testing.expectEqual(base_reward, result.slashed_reward_wei);
        }
    }

    // Bad nodes (0-9) should all be slashed
    try std.testing.expect(total_slashed_count >= 10);
    // Good nodes (20-29) should not be slashed
    try std.testing.expect(total_unslashed_count >= 10);

    const stats = slasher.getStats();
    try std.testing.expectEqual(@as(u64, 30), stats.total_evaluations);
    try std.testing.expect(stats.total_wei_slashed > 0);
}

test "v1.7: 30-node reputation decay — stale nodes lose ranking" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 30;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // All 30 nodes start with perfect 10/10 PoS and full uptime
    for (0..NODE_COUNT) |i| {
        for (0..10) |_| {
            reputation.recordPosResult(peer_ids[i], true);
        }
        reputation.recordUptime(peer_ids[i], 3600, 3600);
        reputation.recordBandwidth(peer_ids[i], 1024 * 1024);
    }

    // Without decay, all should have similar scores
    const undecayed_first = reputation.getScore(peer_ids[0]);
    const undecayed_last = reputation.getScore(peer_ids[29]);
    try std.testing.expectApproxEqAbs(undecayed_first.score, undecayed_last.score, 0.01);

    // Enable decay with 1-hour half-life
    reputation.enableDecay(3600);

    // Make first 15 nodes "stale" (last activity 2 hours ago)
    const now = std.time.timestamp();
    for (0..15) |i| {
        if (reputation.entries.getPtr(peer_ids[i])) |entry| {
            entry.last_activity_ts = now - 7200; // 2 hours ago
        }
    }

    // Keep last 15 nodes "fresh" (last activity now)
    for (15..30) |i| {
        if (reputation.entries.getPtr(peer_ids[i])) |entry| {
            entry.last_activity_ts = now;
        }
    }

    // Rank nodes — fresh nodes should rank higher
    const ranked = try reputation.rankNodes(allocator);
    defer allocator.free(ranked);

    try std.testing.expectEqual(@as(usize, NODE_COUNT), ranked.len);

    // Top-ranked node should be from fresh set (nodes 15-29)
    try std.testing.expect(ranked[0].score > ranked[NODE_COUNT - 1].score);

    // Fresh nodes (score ~original) vs stale nodes (score ~25% after 2 half-lives)
    const fresh_score = ranked[0].score;
    const stale_score = ranked[NODE_COUNT - 1].score;
    try std.testing.expect(fresh_score > stale_score * 2.0);
}

test "v1.7: 30-node prometheus metrics export" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 30;

    // Set up all subsystems
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Store some shards
    for (0..15) |f| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(f + 100));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        _ = try nodes[f % NODE_COUNT].storeShard(hash, &data);
    }

    // Rebalancer
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    // PoS
    var pos = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer pos.deinit();

    // Bandwidth
    var bw_agg = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer bw_agg.deinit();

    for (0..NODE_COUNT) |i| {
        var tracker = storage_mod.RewardTracker{
            .shards_hosted = nodes[i].getStats().total_shards,
            .retrievals_served = @as(u64, i + 1),
            .hosting_start = std.time.timestamp() - 3600,
            .bytes_uploaded = @as(u64, (i + 1)) * 10 * 1024 * 1024,
            .bytes_downloaded = @as(u64, (i + 1)) * 5 * 1024 * 1024,
        };
        const report = bandwidth_aggregator_mod.BandwidthAggregator.generateLocalReport(&tracker, peer_ids[i]);
        bw_agg.recordReport(report);
    }

    // Scrubber
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    // Reputation
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    for (0..NODE_COUNT) |i| {
        for (0..10) |_| reputation.recordPosResult(peer_ids[i], true);
        reputation.recordUptime(peer_ids[i], 3500, 3600);
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 1024 * 1024);
    }

    // Generate network stats report
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const health = reporter.generateReport(&peers, &rebalancer, &pos, &bw_agg, null, &scrubber, &reputation);

    // Export as Prometheus metrics
    var exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const metrics = try exporter.exportMetrics(health);
    defer allocator.free(metrics);

    // Verify Prometheus format
    try std.testing.expect(metrics.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_node_count 30") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_shards_total gauge") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_reputation_avg") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_bandwidth_upload_bytes_total") != null);
}

test "v1.7: full pipeline — scrub, repair, slash, decay, metrics on 30 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 30;

    // Step 1: Create 30 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    // Step 2: Store 20 shards with replication factor 2
    var shard_hashes: [20][32]u8 = undefined;
    for (0..20) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 10));
        std.crypto.hash.sha2.Sha256.hash(&data, &shard_hashes[s], .{});
        // Store on 2 nodes each
        _ = try nodes[s % NODE_COUNT].storeShard(shard_hashes[s], &data);
        _ = try nodes[(s + 1) % NODE_COUNT].storeShard(shard_hashes[s], &data);
    }

    // Step 3: Set up reputation with varying quality
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    for (0..NODE_COUNT) |i| {
        // Nodes 0-9: bad PoS (2/10)
        // Nodes 10-19: medium PoS (6/10)
        // Nodes 20-29: perfect PoS (10/10)
        const pass_count: usize = if (i < 10) 2 else if (i < 20) 6 else 10;
        for (0..10) |j| {
            reputation.recordPosResult(peer_ids[i], j < pass_count);
        }
        reputation.recordUptime(peer_ids[i], @as(u64, (i + 1)) * 360, 3600);
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 512 * 1024);
    }

    // Step 4: Corrupt 5 shards on bad nodes
    for (0..5) |s| {
        if (nodes[s].shards.getPtr(shard_hashes[s])) |ptr| {
            ptr.*[0] ^= 0xFF;
        }
    }

    // Step 5: Scrub bad nodes
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    for (0..10) |i| {
        _ = scrubber.scrubNode(&nodes[i]);
    }

    const scrub_stats = scrubber.getStats();
    try std.testing.expectEqual(@as(u64, 5), scrub_stats.corruptions_found);

    // Step 6: Auto-repair
    var repair_engine = auto_repair_mod.AutoRepairEngine.init(allocator);
    defer repair_engine.deinit();

    var total_repaired: u32 = 0;
    for (0..10) |i| {
        total_repaired += try repair_engine.repairFromScrub(&scrubber, i, &peers);
    }
    try std.testing.expectEqual(@as(u32, 5), total_repaired);

    // Step 7: Apply incentive slashing
    var slasher = incentive_slashing_mod.IncentiveSlashingEngine.init(allocator);
    defer slasher.deinit();

    const base_reward: u128 = 1_000_000_000_000_000_000;
    var slashed_count: u32 = 0;
    for (0..NODE_COUNT) |i| {
        const result = slasher.evaluateReward(peer_ids[i], base_reward, &reputation);
        if (result.was_slashed) slashed_count += 1;
    }
    // Bad nodes should be slashed
    try std.testing.expect(slashed_count >= 10);

    // Step 8: Generate health report
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    var pos = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer pos.deinit();

    var bw_agg = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer bw_agg.deinit();

    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const health = reporter.generateReport(&peers, &rebalancer, &pos, &bw_agg, null, &scrubber, &reputation);

    try std.testing.expectEqual(@as(u32, NODE_COUNT), health.node_count);

    // Step 9: Export Prometheus metrics
    var exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const metrics = try exporter.exportMetrics(health);
    defer allocator.free(metrics);
    try std.testing.expect(metrics.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_node_count 30") != null);

    // Step 10: Verify repair stats
    const repair_stats = repair_engine.getStats();
    try std.testing.expectEqual(@as(u64, 5), repair_stats.repairs_succeeded);
    try std.testing.expectEqual(@as(u64, 0), repair_stats.repairs_failed);
    try std.testing.expectEqual(@as(u64, 5), repair_stats.shards_replaced);

    // Step 11: Verify slashing stats
    const slash_stats = slasher.getStats();
    try std.testing.expectEqual(@as(u64, 30), slash_stats.total_evaluations);
    try std.testing.expect(slash_stats.total_wei_slashed > 0);
}

// =============================================================================
// v1.8 INTEGRATION TESTS
// =============================================================================

test "v1.8: 50-node rate-limited repair — throttled auto-repair" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 50;

    // Create 50 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Store 8 shards with 2 replicas each
    var hashes: [8][32]u8 = undefined;
    for (0..8) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x50));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s].storeShard(hashes[s], &data);
        _ = try nodes[s + 10].storeShard(hashes[s], &data);
    }

    // Corrupt all 8 on primary nodes
    for (0..8) |s| {
        if (nodes[s].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    // Scrub primary nodes
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..8) |s| _ = scrubber.scrubNode(&nodes[s]);

    try std.testing.expectEqual(@as(u64, 8), scrubber.getStats().corruptions_found);

    // Rate-limited repair: only 5 per window
    var limiter = repair_rate_limiter_mod.RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 5,
        .window_secs = 60,
        .max_consecutive_failures = 20,
        .cooldown_secs = 300,
    });
    defer limiter.deinit();

    // Only repair corrupted nodes (0..8) — each throttledRepair call sees ALL corrupted hashes
    // so one call is enough to attempt all 8 repairs (5 allowed, 3 throttled)
    const total_repaired = try limiter.throttledRepair(&scrubber, 0, &peers);

    // Should repair exactly 5 (rate limit), throttle 3
    try std.testing.expectEqual(@as(u32, 5), total_repaired);

    const stats = limiter.getStats();
    try std.testing.expectEqual(@as(u64, 5), stats.total_allowed);
    try std.testing.expectEqual(@as(u64, 3), stats.total_throttled);
    try std.testing.expect(!stats.circuit_breaker_open);
}

test "v1.8: 50-node token staking with slashing" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 50;

    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.05, // 5%
        .corruption_slash_rate = 0.10, // 10%
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // All 50 nodes stake 10,000 wei
    for (0..NODE_COUNT) |i| {
        const result = staking.stake(peer_ids[i], 10_000);
        try std.testing.expect(result.success);
    }

    try std.testing.expectEqual(@as(u32, 50), staking.countActiveStakers());

    // Slash first 10 nodes for PoS failures (2 failures each)
    for (0..10) |i| {
        _ = staking.slashForPosFailure(peer_ids[i]);
        _ = staking.slashForPosFailure(peer_ids[i]);
    }

    // Slash nodes 10-14 for corruption
    for (10..15) |i| {
        _ = staking.slashForCorruption(peer_ids[i]);
    }

    // Verify slashed nodes have reduced stake
    for (0..10) |i| {
        const remaining = staking.getRemainingStake(peer_ids[i]);
        try std.testing.expect(remaining < 10_000);
    }
    for (10..15) |i| {
        const remaining = staking.getRemainingStake(peer_ids[i]);
        try std.testing.expect(remaining < 10_000);
    }

    // Unslashed nodes keep full stake
    for (15..50) |i| {
        try std.testing.expectEqual(@as(u128, 10_000), staking.getRemainingStake(peer_ids[i]));
    }

    // Unstake 5 nodes
    for (45..50) |i| {
        const result = staking.unstake(peer_ids[i]);
        try std.testing.expect(result.success);
        try std.testing.expectEqual(@as(u128, 10_000), result.staked_wei); // Full return (unslashed)
    }

    const stats = staking.getStats();
    try std.testing.expectEqual(@as(u64, 50), stats.total_stakes);
    try std.testing.expectEqual(@as(u64, 5), stats.total_unstakes);
    try std.testing.expectEqual(@as(u64, 25), stats.total_slash_events); // 20 PoS + 5 corruption
    try std.testing.expect(stats.total_burned_wei > 0);
}

test "v1.8: 50-node latency-aware peer selection" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 50;

    var tracker = peer_latency_mod.PeerLatencyTracker.initWithConfig(allocator, .{
        .max_samples = 100,
        .slow_threshold_ns = 10_000_000, // 10ms
        .ema_alpha = 0.3,
    });
    defer tracker.deinit();

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        @memset(&peer_ids[i], @intCast(i + 1));
    }

    // Record latencies: first 10 fast (1ms), middle 30 medium (5ms), last 10 slow (50ms)
    for (0..10) |i| {
        tracker.recordLatency(peer_ids[i], 1_000_000); // 1ms
    }
    for (10..40) |i| {
        tracker.recordLatency(peer_ids[i], 5_000_000); // 5ms
    }
    for (40..50) |i| {
        tracker.recordLatency(peer_ids[i], 50_000_000); // 50ms
    }

    // Rank — top should be fast nodes
    const ranked = try tracker.rankByLatency(allocator);
    defer allocator.free(ranked);

    try std.testing.expectEqual(@as(usize, NODE_COUNT), ranked.len);

    // Fastest nodes should be from first 10
    try std.testing.expect(ranked[0].avg_latency_ns <= 1_000_000);
    // Slowest nodes should be from last 10
    try std.testing.expect(ranked[NODE_COUNT - 1].avg_latency_ns >= 50_000_000);

    // Select top 5, excluding fastest node (node 0)
    const best = try tracker.selectFastestPeers(5, peer_ids[0], allocator);
    defer allocator.free(best);

    try std.testing.expectEqual(@as(usize, 5), best.len);
    // None should be node 0
    for (best) |id| {
        try std.testing.expect(!std.mem.eql(u8, &id, &peer_ids[0]));
    }

    // Stats
    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(u64, 50), stats.total_samples);
    try std.testing.expectEqual(@as(u32, 50), stats.peers_tracked);
    try std.testing.expectEqual(@as(u32, 10), stats.slow_peers); // Last 10
}

test "v1.8: full pipeline — repair, stake, slash, latency, metrics on 50 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 50;

    // Step 1: Create 50 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    var peer_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&peer_ids[i], @intCast(i + 1));

    // Step 2: All nodes stake
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.05,
        .corruption_slash_rate = 0.10,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    for (0..NODE_COUNT) |i| {
        _ = staking.stake(peer_ids[i], 10_000);
    }
    try std.testing.expectEqual(@as(u32, 50), staking.countActiveStakers());

    // Step 3: Store 10 shards with replicas
    var hashes: [10][32]u8 = undefined;
    for (0..10) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x60));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s].storeShard(hashes[s], &data);
        _ = try nodes[s + 20].storeShard(hashes[s], &data);
    }

    // Step 4: Record latencies
    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();

    for (0..NODE_COUNT) |i| {
        const latency: u64 = if (i < 20) 1_000_000 else if (i < 40) 5_000_000 else 50_000_000;
        latency_tracker.recordLatency(peer_ids[i], latency);
    }

    // Step 5: Set up reputation
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    for (0..NODE_COUNT) |i| {
        const pass_count: usize = if (i < 15) 2 else if (i < 35) 6 else 10;
        for (0..10) |j| {
            reputation.recordPosResult(peer_ids[i], j < pass_count);
        }
        reputation.recordUptime(peer_ids[i], @as(u64, (i + 1)) * 72, 3600);
        reputation.recordBandwidth(peer_ids[i], @as(u64, (i + 1)) * 512 * 1024);
    }

    // Step 6: Corrupt 5 shards on primary nodes
    for (0..5) |s| {
        if (nodes[s].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    // Step 7: Scrub + rate-limited repair
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();

    for (0..10) |i| _ = scrubber.scrubNode(&nodes[i]);
    try std.testing.expectEqual(@as(u64, 5), scrubber.getStats().corruptions_found);

    var limiter = repair_rate_limiter_mod.RepairRateLimiter.initWithConfig(allocator, .{
        .max_repairs_per_window = 10,
        .window_secs = 60,
        .max_consecutive_failures = 20,
        .cooldown_secs = 300,
    });
    defer limiter.deinit();

    var total_repaired: u32 = 0;
    for (0..NODE_COUNT) |i| {
        total_repaired += try limiter.throttledRepair(&scrubber, i, &peers);
    }
    try std.testing.expectEqual(@as(u32, 5), total_repaired);

    // Step 8: Slash bad nodes' stakes for PoS failures
    for (0..15) |i| {
        _ = staking.slashForPosFailure(peer_ids[i]);
    }
    // Slash corrupted nodes' stakes
    for (0..5) |i| {
        _ = staking.slashForCorruption(peer_ids[i]);
    }

    // Step 9: Apply incentive slashing
    var slasher = incentive_slashing_mod.IncentiveSlashingEngine.init(allocator);
    defer slasher.deinit();

    const base_reward: u128 = 1_000_000_000_000_000_000;
    var slashed_count: u32 = 0;
    for (0..NODE_COUNT) |i| {
        const result = slasher.evaluateReward(peer_ids[i], base_reward, &reputation);
        if (result.was_slashed) slashed_count += 1;
    }
    try std.testing.expect(slashed_count >= 15);

    // Step 10: Generate health report + Prometheus
    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    var pos = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer pos.deinit();

    var bw_agg = bandwidth_aggregator_mod.BandwidthAggregator.init(allocator);
    defer bw_agg.deinit();

    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const health = reporter.generateReport(&peers, &rebalancer, &pos, &bw_agg, null, &scrubber, &reputation);

    try std.testing.expectEqual(@as(u32, NODE_COUNT), health.node_count);

    var exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const metrics = try exporter.exportMetrics(health);
    defer allocator.free(metrics);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_node_count 50") != null);

    // Step 11: Verify all stats
    const staking_stats = staking.getStats();
    try std.testing.expectEqual(@as(u64, 50), staking_stats.total_stakes);
    try std.testing.expect(staking_stats.total_burned_wei > 0);

    const latency_stats = latency_tracker.getStats();
    try std.testing.expectEqual(@as(u64, 50), latency_stats.total_samples);
    try std.testing.expectEqual(@as(u32, 50), latency_stats.peers_tracked);

    const repair_stats = limiter.getRepairStats();
    try std.testing.expectEqual(@as(u64, 5), repair_stats.repairs_succeeded);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.9 INTEGRATION TESTS: 100-Node Scale
// ═══════════════════════════════════════════════════════════════════════════════

test "v1.9: 100-node erasure-coded repair — reconstruct from RS parity" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 100;

    // Create 100 nodes
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 8,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers_arr: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers_arr[i] = &nodes[i];
    const peers: []const *storage_mod.StorageProvider = &peers_arr;

    // RS config: 4 data + 2 parity = 6 total shards per group
    const rs = reed_solomon_mod.ReedSolomon.init(4, 2);

    // Create 4 data shards
    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };
    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    // Encode parity
    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };
    rs.encode(&data_slices, &parity_out);

    // Compute hashes
    var hashes: [6][32]u8 = undefined;
    const all_data = [_][]const u8{ &data0, &data1, &data2, &data3, &parity0, &parity1 };
    for (0..6) |i| std.crypto.hash.sha2.Sha256.hash(all_data[i], &hashes[i], .{});

    // Distribute shards: store 5 of 6 on different nodes (missing data1)
    _ = try nodes[0].storeShard(hashes[0], &data0);
    // hashes[1] NOT stored — will be reconstructed
    _ = try nodes[2].storeShard(hashes[2], &data2);
    _ = try nodes[3].storeShard(hashes[3], &data3);
    _ = try nodes[4].storeShard(hashes[4], &parity0);
    _ = try nodes[5].storeShard(hashes[5], &parity1);

    // Mark shard 1 as corrupted
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    try scrubber.corrupted_shards.put(hashes[1], .{
        .detected_at = std.time.timestamp(),
        .expected_hash = hashes[1],
        .actual_hash = [_]u8{0} ** 32,
    });

    // Erasure repair
    var engine = erasure_repair_mod.ErasureRepairEngine.initWithConfig(allocator, .{
        .data_shards = 4,
        .parity_shards = 2,
    });
    defer engine.deinit();

    const recovered = try engine.repairWithErasureCoding(&hashes, 8, peers, &scrubber);
    try std.testing.expectEqual(@as(u32, 1), recovered);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.rs_successes);
    try std.testing.expectEqual(@as(u64, 1), stats.rs_shards_recovered);
}

test "v1.9: 100-node reputation consensus — BFT voting" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 100;

    var consensus = reputation_consensus_mod.ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 10,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.15,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    // Create 100 node IDs
    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&node_ids[i], @intCast(i + 1));

    // Evaluate 5 target nodes, each gets 19 votes from dedicated voters
    // 5 targets (indices 0-4) + 5*19=95 voters (indices 5-99) = 100 nodes
    const target_count = 5;
    const voters_per_target = 19;
    const honest_per_target = 15;
    const dishonest_per_target = 4;

    for (0..target_count) |t| {
        // 15 honest voters agree (~0.7)
        for (0..honest_per_target) |v| {
            const voter_idx = target_count + t * voters_per_target + v;
            const score = 0.68 + @as(f64, @floatFromInt(v % 3)) * 0.02;
            try consensus.submitVote(node_ids[voter_idx], node_ids[t], score);
        }
        // 4 dishonest voters
        for (0..dishonest_per_target) |v| {
            const voter_idx = target_count + t * voters_per_target + honest_per_target + v;
            try consensus.submitVote(node_ids[voter_idx], node_ids[t], 0.05);
        }
    }

    // Run consensus for 5 target nodes
    const targets = node_ids[0..target_count];
    const results = try consensus.applyConsensus(targets, &reputation);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, target_count), results.len);

    // Count valid consensus results — 15/19 = 0.789 > 0.667 threshold
    var valid_count: u32 = 0;
    for (results) |r| {
        if (r.is_valid) valid_count += 1;
        try std.testing.expectEqual(@as(u32, voters_per_target), r.voter_count);
    }

    // All 5 should be valid (79% honest agreement)
    try std.testing.expectEqual(@as(u32, target_count), valid_count);

    const stats = consensus.getStats();
    try std.testing.expectEqual(@as(u64, target_count), stats.total_rounds);
    try std.testing.expectEqual(@as(u64, target_count), stats.successful_rounds);
    try std.testing.expect(stats.total_votes_cast == 95); // 5 targets * 19 votes each
    try std.testing.expect(stats.fraud_detections >= 20); // 4 fraud per target * 5 targets
}

test "v1.9: 100-node stake delegation with rewards and slashing" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 100;

    var delegation = stake_delegation_mod.StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 50,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer delegation.deinit();

    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&node_ids[i], @intCast(i + 1));

    // First 10 nodes are operators
    for (0..10) |i| {
        const commission = 0.05 + @as(f64, @floatFromInt(i)) * 0.02;
        try delegation.registerOperator(node_ids[i], commission);
    }

    // Remaining 90 nodes delegate to operators (9 per operator)
    for (10..NODE_COUNT) |i| {
        const op_idx = (i - 10) % 10;
        const amount: u128 = @intCast((i + 1) * 1000);
        const result = delegation.delegate(node_ids[i], node_ids[op_idx], amount);
        try std.testing.expect(result.success);
    }

    const stats_before = delegation.getStats();
    try std.testing.expectEqual(@as(u32, 90), stats_before.active_delegations);
    try std.testing.expectEqual(@as(u32, 10), stats_before.total_operators);

    // Distribute rewards to each operator
    for (0..10) |i| {
        _ = delegation.distributeRewards(node_ids[i], 10_000);
    }

    // Slash 3 operators
    for (0..3) |i| {
        _ = delegation.slashOperator(node_ids[i], 5_000);
    }

    const stats_after = delegation.getStats();
    try std.testing.expectEqual(@as(u128, 100_000), stats_after.total_rewards_wei);
    try std.testing.expectEqual(@as(u128, 15_000), stats_after.total_slashed_wei);

    // Verify slashed operators have reduced delegator stakes
    for (10..19) |i| { // First 9 delegators (operator 0's delegators)
        const entry = delegation.getDelegation(node_ids[i]);
        try std.testing.expect(entry != null);
        if ((i - 10) % 10 < 3) {
            // Delegated to slashed operator — should have some slash
            try std.testing.expect(entry.?.slashed_wei > 0 or entry.?.rewards_earned_wei > 0);
        }
    }
}

test "v1.9: full pipeline — erasure repair, consensus, delegation, all subsystems on 100 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 100;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| @memset(&node_ids[i], @intCast(i + 1));

    // === STORE 20 SHARDS ACROSS NODES ===
    var hashes: [20][32]u8 = undefined;
    for (0..20) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        // Store on 3 nodes each (replication factor 3)
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 10) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 50) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === SCRUB AND REPAIR ===
    // Corrupt 5 shards on primary nodes
    for (0..5) |s| {
        const node_idx = s % NODE_COUNT;
        if (nodes[node_idx].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..NODE_COUNT) |i| _ = scrubber.scrubNode(&nodes[i]);

    // Repair via hybrid (replica-based)
    var erasure_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
    defer erasure_engine.deinit();
    const repaired = try erasure_engine.hybridRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 5), repaired);

    // === REPUTATION + CONSENSUS ===
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    // Record PoS results
    for (0..NODE_COUNT) |i| {
        const passed = i < 80; // 80 nodes pass, 20 fail
        reputation.recordPosResult(node_ids[i], passed);
        reputation.recordUptime(node_ids[i], if (passed) 3600 else 1800, 3600);
    }

    var consensus = reputation_consensus_mod.ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 5,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.2,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    // Submit votes for first 10 nodes
    for (0..10) |target| {
        for (20..30) |voter| {
            const score = reputation.getScore(node_ids[target]).score;
            try consensus.submitVote(node_ids[voter], node_ids[target], score);
        }
    }
    _ = consensus.runConsensus(node_ids[0]);

    // === STAKING + DELEGATION ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.05,
        .corruption_slash_rate = 0.10,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    for (0..NODE_COUNT) |i| {
        _ = staking.stake(node_ids[i], 10_000);
    }

    // Slash failing nodes
    for (80..100) |i| {
        _ = staking.slashForPosFailure(node_ids[i]);
    }

    var delegation = stake_delegation_mod.StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 50,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer delegation.deinit();

    // Top 10 nodes are operators
    for (0..10) |i| try delegation.registerOperator(node_ids[i], 0.10);

    // 50 delegators
    for (10..60) |i| {
        _ = delegation.delegate(node_ids[i], node_ids[i % 10], 5_000);
    }

    _ = delegation.distributeRewards(node_ids[0], 50_000);

    // === LATENCY ===
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    for (0..NODE_COUNT) |i| {
        latency.recordLatency(node_ids[i], @intCast((i + 1) * 10_000));
    }

    // === PROMETHEUS METRICS ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    const health_report = reporter.generateReport(
        peers_const,
        null,
        null,
        null,
        null,
        null,
        null,
    );

    var exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator);
    const metrics_output = try exporter.exportMetrics(health_report);
    defer allocator.free(metrics_output);
    try std.testing.expect(metrics_output.len > 0);

    // === VERIFY ALL SUBSYSTEMS ===
    const erasure_stats = erasure_engine.getStats();
    try std.testing.expectEqual(@as(u64, 5), erasure_stats.replica_repairs);

    const consensus_stats = consensus.getStats();
    try std.testing.expect(consensus_stats.total_rounds >= 1);

    const staking_stats = staking.getStats();
    try std.testing.expectEqual(@as(u32, 100), staking_stats.active_stakers);
    try std.testing.expect(staking_stats.total_burned_wei > 0);

    const delegation_stats = delegation.getStats();
    try std.testing.expectEqual(@as(u32, 50), delegation_stats.active_delegations);
    try std.testing.expectEqual(@as(u128, 50_000), delegation_stats.total_rewards_wei);

    const latency_stats = latency.getStats();
    try std.testing.expectEqual(@as(u64, 100), latency_stats.total_samples);
    try std.testing.expectEqual(@as(u32, 100), latency_stats.peers_tracked);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.0 TESTS: 200-NODE SCALE — Multi-Region, Slashing Escrow, Prometheus HTTP
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.0: 200-node multi-region topology — geo-aware shard placement" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 200;

    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 3,
        .max_replicas_per_region = 10,
        .local_read_threshold_ns = 50_000_000,
        .max_write_latency_ms = 300,
    });
    defer topo.deinit();

    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();

    // Create 200 node IDs
    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        var id: [32]u8 = undefined;
        @memset(&id, 0);
        id[0] = @intCast((i >> 8) & 0xFF);
        id[1] = @intCast(i & 0xFF);
        id[31] = @intCast((i + 1) & 0xFF);
        node_ids[i] = id;
    }

    // Distribute 200 nodes across 9 regions (~22 per region)
    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        const region = regions[i % 9];
        try topo.registerNode(node_ids[i], region);

        // Record latency based on region (simulate real-world)
        const base_latency: u64 = switch (region) {
            .us_east => 5_000_000, // 5ms
            .us_west => 8_000_000,
            .eu_west => 12_000_000,
            .eu_east => 15_000_000,
            .asia_east => 20_000_000,
            .asia_south => 25_000_000,
            .oceania => 30_000_000,
            .south_america => 35_000_000,
            .africa => 40_000_000,
            .unknown => 100_000_000,
        };
        latency.recordLatency(node_ids[i], base_latency + @as(u64, @intCast(i * 1000)));
    }

    // Verify all 9 regions populated
    try std.testing.expectEqual(@as(u64, 200), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    // Test placement decisions from different regions
    for (regions) |req_region| {
        const decision = topo.computePlacement(req_region);
        try std.testing.expect(decision.region_count >= 3); // min_regions_per_shard = 3
        try std.testing.expect(decision.cross_region); // must span regions
    }

    // Test local read preference
    const read_node = topo.selectReadNode(.us_east, &latency);
    try std.testing.expect(read_node != null);

    // Verify latency zones
    try std.testing.expectEqual(@as(u8, 0), region_topology_mod.RegionTopology.getLatencyZone(.us_east, .us_east));
    try std.testing.expectEqual(@as(u8, 1), region_topology_mod.RegionTopology.getLatencyZone(.us_east, .us_west));
    try std.testing.expectEqual(@as(u8, 2), region_topology_mod.RegionTopology.getLatencyZone(.us_east, .asia_east));

    const topo_stats = topo.getStats();
    try std.testing.expectEqual(@as(u64, 9), topo_stats.placement_decisions); // 9 region placements
    try std.testing.expect(topo_stats.cross_region_placements >= 9);
}

test "v2.0: 200-node slashing escrow — time-locked disputes with governance" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 200;

    var escrow = slashing_escrow_mod.SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 86400,
        .min_governance_votes = 10,
        .overturn_threshold = 0.667,
        .max_escrows_per_node = 5,
        .frivolous_dispute_penalty_wei = 1_000,
    });
    defer escrow.deinit();

    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        var id: [32]u8 = undefined;
        @memset(&id, 0);
        id[0] = @intCast((i >> 8) & 0xFF);
        id[1] = @intCast(i & 0xFF);
        id[31] = @intCast((i + 1) & 0xFF);
        node_ids[i] = id;
    }

    // Create 20 escrows for first 20 nodes (simulating slashing events)
    var escrow_ids: [20]u64 = undefined;
    for (0..20) |i| {
        const amount: u128 = @intCast((i + 1) * 10_000);
        escrow_ids[i] = try escrow.createEscrow(
            node_ids[i],
            amount,
            switch (i % 4) {
                0 => .pos_failure,
                1 => .data_corruption,
                2 => .downtime,
                3 => .protocol_violation,
                else => unreachable,
            },
            1000,
        );
    }

    try std.testing.expectEqual(@as(u64, 20), escrow.getStats().total_escrows);
    try std.testing.expectEqual(@as(u32, 20), escrow.getStats().active_escrows);

    // 10 nodes file disputes (escrows 0-9)
    for (0..10) |i| {
        var evidence: [32]u8 = undefined;
        @memset(&evidence, @intCast(i + 0xA0));
        const result = escrow.fileDispute(escrow_ids[i], evidence, 2000);
        try std.testing.expectEqual(slashing_escrow_mod.DisputeResult.accepted, result);
    }

    try std.testing.expectEqual(@as(u64, 10), escrow.getStats().disputes_filed);

    // Governance voting: 15 voters per disputed escrow
    // Escrows 0-4: mostly overturn votes (12/15 = 0.8 > 0.667)
    for (0..5) |i| {
        for (0..12) |v| {
            const voter_idx = 50 + i * 15 + v; // voters from nodes 50+
            const result = try escrow.vote(escrow_ids[i], node_ids[voter_idx], true, 3000);
            try std.testing.expectEqual(slashing_escrow_mod.VoteResult.accepted, result);
        }
        for (12..15) |v| {
            const voter_idx = 50 + i * 15 + v;
            _ = try escrow.vote(escrow_ids[i], node_ids[voter_idx], false, 3000);
        }
    }

    // Escrows 5-9: mostly against overturn (3/15 = 0.2 < 0.667)
    for (5..10) |i| {
        for (0..3) |v| {
            const voter_idx = 50 + i * 15 + v;
            _ = try escrow.vote(escrow_ids[i], node_ids[voter_idx], true, 3000);
        }
        for (3..15) |v| {
            const voter_idx = 50 + i * 15 + v;
            _ = try escrow.vote(escrow_ids[i], node_ids[voter_idx], false, 3000);
        }
    }

    // Resolve disputed escrows (0-9)
    var overturned: u32 = 0;
    var executed: u32 = 0;
    for (0..10) |i| {
        const result = escrow.resolveEscrow(escrow_ids[i], 4000);
        try std.testing.expect(result != null);
        if (result.?.status == .overturned) {
            overturned += 1;
        } else if (result.?.status == .executed) {
            executed += 1;
        }
    }

    // 5 overturned (escrows 0-4), 5 executed (escrows 5-9)
    try std.testing.expectEqual(@as(u32, 5), overturned);
    try std.testing.expectEqual(@as(u32, 5), executed);

    // Remaining 10 escrows (10-19): no dispute, auto-execute after deadline
    for (10..20) |i| {
        const result = escrow.resolveEscrow(escrow_ids[i], 1000 + 86401);
        try std.testing.expect(result != null);
        try std.testing.expectEqual(slashing_escrow_mod.EscrowStatus.executed, result.?.status);
    }

    const stats = escrow.getStats();
    try std.testing.expectEqual(@as(u64, 20), stats.total_escrows);
    try std.testing.expectEqual(@as(u32, 0), stats.active_escrows);
    try std.testing.expectEqual(@as(u64, 5), stats.disputes_overturned);
    try std.testing.expectEqual(@as(u64, 5), stats.disputes_rejected);
    try std.testing.expectEqual(@as(u64, 15), stats.slashes_executed); // 5 rejected + 10 auto-executed
    try std.testing.expect(stats.governance_votes_cast == 150); // 10 escrows * 15 votes
}

test "v2.0: 200-node prometheus HTTP endpoint — live /metrics scraping" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 200;

    var endpoint = prometheus_http_mod.PrometheusHttpEndpoint.initWithConfig(allocator, .{
        .port = 9090,
        .cache_ttl_ms = 5000,
    });
    defer endpoint.deinit();

    // Create storage nodes for report generation
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    // Store some shards
    for (0..50) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hash, &data);
    }

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // Generate health report
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    const health_report = reporter.generateReport(
        peers_const,
        null,
        null,
        null,
        null,
        null,
        null,
    );

    // Test /metrics endpoint
    const response = try endpoint.handleRequest("/metrics", health_report, 1000);
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(response.body_len > 0);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "trinity_node_count") != null);

    // Test caching: multiple rapid scrapes
    for (0..10) |scrape| {
        _ = try endpoint.handleRequest("/metrics", health_report, @intCast(1000 + scrape * 100));
    }

    // 1 cache miss (first), 10 cache hits
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().cache_misses);
    try std.testing.expectEqual(@as(u64, 10), endpoint.getStats().cache_hits);

    // After TTL: fresh scrape
    _ = try endpoint.handleRequest("/metrics", health_report, 7000);
    try std.testing.expectEqual(@as(u64, 2), endpoint.getStats().cache_misses);

    // Test 404 for bad paths
    const bad = try endpoint.handleRequest("/health", health_report, 8000);
    try std.testing.expectEqual(@as(u16, 404), bad.status_code);

    // Test HTTP response formatting
    const http_response = try endpoint.handleRequest("/metrics", health_report, 8000);
    const raw = try endpoint.formatHttpResponse(http_response);
    defer allocator.free(raw);
    try std.testing.expect(std.mem.startsWith(u8, raw, "HTTP/1.1 200 OK"));

    // Self-monitoring metrics
    const self_metrics = try endpoint.getEndpointMetrics();
    defer allocator.free(self_metrics);
    try std.testing.expect(std.mem.indexOf(u8, self_metrics, "trinity_metrics_requests_total") != null);

    const stats = endpoint.getStats();
    try std.testing.expectEqual(@as(u64, 14), stats.total_requests); // 1 + 10 + 1 + 1 + 1
    try std.testing.expect(stats.total_bytes_served > 0);
}

test "v2.0: full pipeline — region topology, escrow, prometheus, all subsystems on 200 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 200;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    var node_ids: [NODE_COUNT][32]u8 = undefined;
    for (0..NODE_COUNT) |i| {
        var id: [32]u8 = undefined;
        @memset(&id, 0);
        id[0] = @intCast((i >> 8) & 0xFF);
        id[1] = @intCast(i & 0xFF);
        id[31] = @intCast((i + 1) & 0xFF);
        node_ids[i] = id;
    }

    // === STORE 40 SHARDS ACROSS NODES ===
    var hashes: [40][32]u8 = undefined;
    for (0..40) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 50) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 100) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === MULTI-REGION TOPOLOGY ===
    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
        .max_replicas_per_region = 25,
        .local_read_threshold_ns = 50_000_000,
        .max_write_latency_ms = 300,
    });
    defer topo.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        try topo.registerNode(node_ids[i], regions[i % 9]);
    }

    const placement = topo.computePlacement(.us_east);
    try std.testing.expect(placement.region_count >= 2);

    // === SCRUB AND REPAIR ===
    for (0..10) |s| {
        if (nodes[s % NODE_COUNT].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..NODE_COUNT) |i| _ = scrubber.scrubNode(&nodes[i]);

    var erasure_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
    defer erasure_engine.deinit();
    const repaired = try erasure_engine.hybridRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 10), repaired);

    // === REPUTATION + CONSENSUS ===
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    for (0..NODE_COUNT) |i| {
        const passed = i < 160; // 80% pass
        reputation.recordPosResult(node_ids[i], passed);
        reputation.recordUptime(node_ids[i], if (passed) 3600 else 1800, 3600);
    }

    var consensus = reputation_consensus_mod.ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 5,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.2,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    for (0..5) |target| {
        for (10..20) |voter| {
            const score = reputation.getScore(node_ids[target]).score;
            try consensus.submitVote(node_ids[voter], node_ids[target], score);
        }
    }
    _ = consensus.runConsensus(node_ids[0]);

    // === STAKING + DELEGATION ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.05,
        .corruption_slash_rate = 0.10,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    for (0..NODE_COUNT) |i| {
        _ = staking.stake(node_ids[i], 10_000);
    }

    // === SLASHING ESCROW ===
    var escrow = slashing_escrow_mod.SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 86400,
        .min_governance_votes = 5,
        .overturn_threshold = 0.667,
        .max_escrows_per_node = 5,
        .frivolous_dispute_penalty_wei = 1_000,
    });
    defer escrow.deinit();

    // Slash 10 failing nodes with escrow
    for (160..170) |i| {
        _ = staking.slashForPosFailure(node_ids[i]);
        _ = try escrow.createEscrow(node_ids[i], 500, .pos_failure, 1000);
    }

    // 5 nodes dispute, all overturned
    for (0..5) |i| {
        var evidence: [32]u8 = undefined;
        @memset(&evidence, @intCast(i + 0xE0));
        _ = escrow.fileDispute(@intCast(i + 1), evidence, 2000);
        // 8 voters overturn
        for (0..8) |v| {
            _ = try escrow.vote(@intCast(i + 1), node_ids[v + 180], true, 3000);
        }
        const res = escrow.resolveEscrow(@intCast(i + 1), 4000);
        try std.testing.expect(res != null);
    }

    // 5 auto-execute after deadline
    for (5..10) |i| {
        const res = escrow.resolveEscrow(@intCast(i + 1), 1000 + 86401);
        try std.testing.expect(res != null);
        try std.testing.expectEqual(slashing_escrow_mod.EscrowStatus.executed, res.?.status);
    }

    // === DELEGATION ===
    var delegation = stake_delegation_mod.StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 50,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer delegation.deinit();

    for (0..20) |i| try delegation.registerOperator(node_ids[i], 0.10);
    for (20..120) |i| {
        _ = delegation.delegate(node_ids[i], node_ids[i % 20], 5_000);
    }
    _ = delegation.distributeRewards(node_ids[0], 100_000);

    // === LATENCY ===
    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();
    for (0..NODE_COUNT) |i| {
        latency_tracker.recordLatency(node_ids[i], @intCast((i + 1) * 10_000));
    }

    // === PROMETHEUS HTTP ENDPOINT ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    const health_report = reporter.generateReport(
        peers_const,
        null,
        null,
        null,
        null,
        null,
        null,
    );

    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const response = try http_endpoint.handleRequest("/metrics", health_report, 5000);
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(response.body_len > 0);

    // === VERIFY ALL SUBSYSTEMS ===
    const topo_stats = topo.getStats();
    try std.testing.expectEqual(@as(u64, 200), topo_stats.total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo_stats.total_regions);

    const erasure_stats = erasure_engine.getStats();
    try std.testing.expectEqual(@as(u64, 10), erasure_stats.replica_repairs);

    const escrow_stats = escrow.getStats();
    try std.testing.expectEqual(@as(u64, 10), escrow_stats.total_escrows);
    try std.testing.expectEqual(@as(u32, 0), escrow_stats.active_escrows);

    const staking_stats = staking.getStats();
    try std.testing.expectEqual(@as(u32, 200), staking_stats.active_stakers);

    const delegation_stats = delegation.getStats();
    try std.testing.expectEqual(@as(u32, 100), delegation_stats.active_delegations);

    const latency_stats = latency_tracker.getStats();
    try std.testing.expectEqual(@as(u64, 200), latency_stats.total_samples);

    const http_stats = http_endpoint.getStats();
    try std.testing.expectEqual(@as(u64, 1), http_stats.total_requests);
    try std.testing.expect(http_stats.total_bytes_served > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.1 TESTS: 300-NODE SCALE — Cross-Shard 2PC, VSA Locks, Region-Aware Router
// ═══════════════════════════════════════════════════════════════════════════════

fn makeNodeId(i: usize) [32]u8 {
    var id: [32]u8 = undefined;
    @memset(&id, 0);
    id[0] = @intCast((i >> 8) & 0xFF);
    id[1] = @intCast(i & 0xFF);
    id[31] = @intCast((i + 1) & 0xFF);
    return id;
}

test "v2.1: 300-node cross-shard 2PC — atomic transactions" {
    const allocator = std.testing.allocator;

    var coord = cross_shard_tx_mod.CrossShardTxCoordinator.initWithConfig(allocator, .{
        .max_shards_per_tx = 64,
        .prepare_timeout_ms = 30_000,
        .max_concurrent_tx = 256,
        .max_rollback_retries = 3,
    });
    defer coord.deinit();

    const coordinator_id = makeNodeId(0);

    // Create 50 cross-shard transactions, each spanning 6 shards
    var tx_ids: [50]u64 = undefined;
    for (0..50) |t| {
        tx_ids[t] = try coord.beginTransaction(coordinator_id, @intCast(t * 100));

        for (0..6) |s| {
            const shard = makeNodeId(300 + t * 6 + s);
            const node = makeNodeId(1 + (t * 6 + s) % 300);
            try coord.addParticipant(tx_ids[t], shard, node, @intCast(t * 100));
        }

        try coord.prepare(tx_ids[t]);
    }

    // 40 transactions: all participants vote commit
    for (0..40) |t| {
        for (0..6) |s| {
            const shard = makeNodeId(300 + t * 6 + s);
            try coord.recordVote(tx_ids[t], shard, true);
        }
        const result = try coord.commit(tx_ids[t], @intCast(t * 100 + 500));
        try std.testing.expect(result.success);
        try std.testing.expectEqual(@as(u32, 6), result.participants_committed);
    }

    // 10 transactions: one participant votes abort
    for (40..50) |t| {
        for (0..5) |s| {
            const shard = makeNodeId(300 + t * 6 + s);
            try coord.recordVote(tx_ids[t], shard, true);
        }
        // Last participant votes abort
        const abort_shard = makeNodeId(300 + t * 6 + 5);
        try coord.recordVote(tx_ids[t], abort_shard, false);
        // Should auto-transition to aborting
        const result = try coord.abort(tx_ids[t], @intCast(t * 100 + 500));
        try std.testing.expect(!result.success);
    }

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 50), stats.total_transactions);
    try std.testing.expectEqual(@as(u64, 40), stats.committed_transactions);
    try std.testing.expectEqual(@as(u64, 10), stats.aborted_transactions);
    try std.testing.expectEqual(@as(u64, 300), stats.total_participants); // 50 * 6
    try std.testing.expectEqual(@as(u64, 300), stats.total_prepare_votes);
    try std.testing.expectEqual(@as(u64, 240), stats.total_commit_acks); // 40 * 6
}

test "v2.1: 300-node VSA shard locks — semantic locking" {
    const allocator = std.testing.allocator;

    var locks = vsa_shard_locks_mod.VsaShardLocks.initWithConfig(allocator, .{
        .vector_dim = 1024,
        .similarity_threshold = 0.85,
        .max_locks_per_holder = 64,
        .lock_timeout_ms = 60_000,
    });
    defer locks.deinit();

    // 30 holders each lock 10 shards = 300 total locks
    for (0..30) |h| {
        const holder = makeNodeId(h);
        for (0..10) |s| {
            const shard = makeNodeId(300 + h * 10 + s);
            const tx_id: u64 = @intCast(h * 100 + s);
            const result = try locks.acquireLock(shard, holder, tx_id, 1000);
            try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
        }
    }

    try std.testing.expectEqual(@as(u32, 300), locks.getStats().active_locks);

    // Verify all locks — correct holder passes, wrong holder fails
    for (0..30) |h| {
        const holder = makeNodeId(h);
        const wrong = makeNodeId(h + 100);
        for (0..10) |s| {
            const shard = makeNodeId(300 + h * 10 + s);
            try std.testing.expect(locks.verifyLock(shard, holder));
            try std.testing.expect(!locks.verifyLock(shard, wrong));
        }
    }

    // Contention: 30 different nodes try to lock already-locked shards
    var contentions: u32 = 0;
    for (0..30) |h| {
        const attacker = makeNodeId(h + 200);
        const shard = makeNodeId(300 + h * 10); // First shard of holder h
        const result = try locks.acquireLock(shard, attacker, 9999, 2000);
        if (result == .already_locked) contentions += 1;
    }
    try std.testing.expectEqual(@as(u32, 30), contentions);

    // Release 10 holders' locks via transaction release
    for (0..10) |h| {
        for (0..10) |s| {
            const tx_id: u64 = @intCast(h * 100 + s);
            _ = locks.releaseTransactionLocks(tx_id);
        }
    }

    // 100 locks released, 200 remain
    try std.testing.expectEqual(@as(u32, 200), locks.getStats().active_locks);

    const stats = locks.getStats();
    try std.testing.expectEqual(@as(u64, 300), stats.total_acquisitions);
    try std.testing.expectEqual(@as(u64, 30), stats.lock_contentions);
    try std.testing.expect(stats.verification_successes >= 300);
    try std.testing.expect(stats.verification_failures >= 30);
}

test "v2.1: 300-node region-aware router — multi-region routing" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    // Register 300 nodes across 9 regions
    for (0..300) |i| {
        const node_id = makeNodeId(i);
        const region = regions[i % 9];
        try topo.registerNode(node_id, region);

        // Record latency based on region
        const base_lat: u64 = @as(u64, @intCast(@intFromEnum(region))) * 5_000_000 + 2_000_000;
        latency.recordLatency(node_id, base_lat);

        // Record reputation (90% pass)
        reputation.recordPosResult(node_id, i % 10 != 0);
        reputation.recordUptime(node_id, if (i % 10 != 0) 3600 else 1800, 3600);
    }

    var router = region_router_mod.RegionRouter.initWithConfig(allocator, .{
        .latency_weight = 0.4,
        .reputation_weight = 0.4,
        .locality_weight = 0.2,
        .max_candidates = 50,
        .min_reputation = 0.3,
    });
    defer router.deinit();

    // Route from each region — verify selection works
    for (regions) |req_region| {
        const decision = router.routeRequest(req_region, &topo, &latency, &reputation);
        try std.testing.expect(decision != null);
        try std.testing.expect(decision.?.composite_score > 0);
    }

    // Route for cross-shard transaction: 3 target regions
    var target_regions = [_]bool{false} ** 9;
    target_regions[0] = true; // us_east
    target_regions[2] = true; // eu_west
    target_regions[4] = true; // asia_east

    const tx_routes = try router.routeForTransaction(.us_east, target_regions, &topo, &latency, &reputation);
    defer allocator.free(tx_routes);

    try std.testing.expectEqual(@as(usize, 3), tx_routes.len);

    const stats = router.getStats();
    try std.testing.expectEqual(@as(u64, 12), stats.total_route_decisions); // 9 single + 3 tx
    try std.testing.expect(stats.local_routes >= 9); // Each region routes locally
    try std.testing.expect(stats.avg_composite_score > 0);
}

test "v2.1: full pipeline — 2PC, VSA locks, region router, all subsystems on 300 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 300;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === STORE 60 SHARDS ===
    var hashes: [60][32]u8 = undefined;
    for (0..60) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 100) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 200) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === REGION TOPOLOGY + ROUTER ===
    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
    });
    defer topo.deinit();

    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        const nid = makeNodeId(i);
        try topo.registerNode(nid, regions[i % 9]);
        latency_tracker.recordLatency(nid, @intCast((i % 9 + 1) * 5_000_000));
        reputation.recordPosResult(nid, i < 240); // 80% pass
        reputation.recordUptime(nid, if (i < 240) 3600 else 1800, 3600);
    }

    var router = region_router_mod.RegionRouter.init(allocator);
    defer router.deinit();

    const route = router.routeRequest(.us_east, &topo, &latency_tracker, &reputation);
    try std.testing.expect(route != null);

    // === CROSS-SHARD 2PC ===
    var coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    const coordinator_id = makeNodeId(0);
    const tx1 = try coord.beginTransaction(coordinator_id, 1000);

    // Transaction spans 10 shards
    for (0..10) |s| {
        try coord.addParticipant(tx1, hashes[s], makeNodeId(s + 1), 1000);
    }

    // === VSA SHARD LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();

    // Lock all 10 transaction shards
    for (0..10) |s| {
        const result = try locks.acquireLock(hashes[s], coordinator_id, tx1, 1000);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
    }

    // Verify all locks
    for (0..10) |s| {
        try std.testing.expect(locks.verifyLock(hashes[s], coordinator_id));
    }

    // Execute 2PC
    try coord.prepare(tx1);
    for (0..10) |s| {
        try coord.recordVote(tx1, hashes[s], true);
    }
    const tx_result = try coord.commit(tx1, 2000);
    try std.testing.expect(tx_result.success);
    try std.testing.expectEqual(@as(u32, 10), tx_result.participants_committed);

    // Release locks after commit
    const released = locks.releaseTransactionLocks(tx1);
    try std.testing.expectEqual(@as(u32, 10), released);

    // === REPAIR ===
    for (0..5) |s| {
        if (nodes[s % NODE_COUNT].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..NODE_COUNT) |i| _ = scrubber.scrubNode(&nodes[i]);

    var erasure_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
    defer erasure_engine.deinit();
    _ = try erasure_engine.hybridRepair(&scrubber, 0, &peers);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (240..245) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i));
        _ = try escrow.createEscrow(makeNodeId(i), 500, .pos_failure, 1000);
    }

    // === PROMETHEUS ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    const health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);

    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const metrics_resp = try http_endpoint.handleRequest("/metrics", health_report, 5000);
    try std.testing.expectEqual(@as(u16, 200), metrics_resp.status_code);

    // === VERIFY ALL v2.1 SUBSYSTEMS ===
    try std.testing.expectEqual(@as(u64, 300), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);
    try std.testing.expect(route != null);

    try std.testing.expectEqual(@as(u64, 1), coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u64, 10), coord.getStats().total_participants);

    try std.testing.expectEqual(@as(u64, 10), locks.getStats().total_acquisitions);
    try std.testing.expectEqual(@as(u32, 0), locks.getStats().active_locks);

    try std.testing.expectEqual(@as(u32, 300), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 5), escrow.getStats().total_escrows);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.2 INTEGRATION TESTS — 400-Node Scale, Dynamic Erasure Coding
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.2: 400-node dynamic erasure — adaptive RS under excellent health" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 400;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    // === REPUTATION: 95% pass rate ===
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();
    for (0..NODE_COUNT) |i| {
        const nid = makeNodeId(i);
        reputation.recordPosResult(nid, i < 380); // 380/400 = 95% pass
        reputation.recordUptime(nid, 3500, 3600);
        reputation.recordBandwidth(nid, 10_000_000);
    }

    // === NETWORK HEALTH REPORT (excellent) ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);

    // Override with realistic 400-node stats
    health_report.node_count = 400;
    health_report.pos_challenges_issued = 4000;
    health_report.pos_challenges_passed = 3900;
    health_report.pos_challenges_failed = 100; // 2.5% failure
    health_report.scrub_total = 2000;
    health_report.scrub_corruptions = 5; // 0.25% corruption
    health_report.reputation_avg = 0.93;
    health_report.reputation_min = 0.60;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 200_000_000;
    health_report.total_bytes_available = 2_000_000_000;
    health_report.shards_rebalanced = 50;

    // === DYNAMIC ERASURE ENGINE ===
    var engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});

    // Recommend for 8 data shards
    const rec = engine.recommend(health_report, 8);

    // Excellent health → reduced parity ratio, low parity shards
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, rec.health_level);
    try std.testing.expectEqual(dynamic_erasure_mod.AdaptiveReason.default_healthy, rec.reason);
    try std.testing.expect(rec.parity_ratio < 0.5); // below baseline
    try std.testing.expect(rec.parity_shards >= 1);
    try std.testing.expect(rec.parity_shards <= 4); // not excessive
    try std.testing.expect(rec.health_score >= 0.85);
    try std.testing.expect(rec.confidence >= 0.8); // high data volume

    // Recommend for 16 data shards (bigger file)
    const rec16 = engine.recommend(health_report, 16);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, rec16.health_level);
    try std.testing.expect(rec16.parity_shards >= 1);
    try std.testing.expect(rec16.data_shards == 16);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_recommendations);
    try std.testing.expectEqual(@as(u64, 2), stats.excellent_count);
}

test "v2.2: 400-node dynamic erasure — degraded health increases parity" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 400;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    // === NETWORK HEALTH REPORT (degraded) ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);

    // Simulate degraded network: high PoS failures, high corruption
    health_report.node_count = 400;
    health_report.pos_challenges_issued = 4000;
    health_report.pos_challenges_passed = 3200;
    health_report.pos_challenges_failed = 800; // 20% failure — critical
    health_report.scrub_total = 2000;
    health_report.scrub_corruptions = 120; // 6% corruption — degraded
    health_report.reputation_avg = 0.62; // low
    health_report.reputation_min = 0.20;
    health_report.reputation_max = 0.85;
    health_report.total_bytes_used = 800_000_000;
    health_report.total_bytes_available = 2_000_000_000;
    health_report.shards_rebalanced = 600; // high churn

    var engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});

    // Degraded/critical health → higher parity
    const rec = engine.recommend(health_report, 8);
    try std.testing.expect(rec.health_level == .degraded or rec.health_level == .critical);
    try std.testing.expect(rec.parity_ratio >= 0.5); // above baseline
    try std.testing.expect(rec.parity_shards >= 4); // substantial parity
    try std.testing.expect(rec.health_score < 0.65);

    // Compare: excellent vs degraded for same file
    var excellent_report = health_report;
    excellent_report.pos_challenges_failed = 20;
    excellent_report.scrub_corruptions = 2;
    excellent_report.reputation_avg = 0.95;
    excellent_report.shards_rebalanced = 20;
    const excellent_rec = engine.recommend(excellent_report, 8);

    // Degraded should have more parity than excellent
    try std.testing.expect(rec.parity_shards >= excellent_rec.parity_shards);
    try std.testing.expect(rec.parity_ratio >= excellent_rec.parity_ratio);
}

test "v2.2: 400-node dynamic erasure — storage pressure overrides" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 400;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);

    // Storage nearly full (96%) — should reduce parity despite other metrics
    // All other metrics healthy so storage_pressure is the dominant reason
    health_report.node_count = 400;
    health_report.pos_challenges_issued = 4000;
    health_report.pos_challenges_passed = 3960;
    health_report.pos_challenges_failed = 40; // 1% — healthy
    health_report.scrub_total = 2000;
    health_report.scrub_corruptions = 5; // 0.25% — healthy
    health_report.reputation_avg = 0.92; // above good threshold
    health_report.reputation_min = 0.70;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 1_920_000_000; // 96% of 2B
    health_report.total_bytes_available = 2_000_000_000;
    health_report.shards_rebalanced = 30; // low churn

    var engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const rec = engine.recommend(health_report, 8);

    // Storage pressure → minimum parity regardless of other factors
    try std.testing.expectEqual(dynamic_erasure_mod.AdaptiveReason.storage_pressure, rec.reason);
    try std.testing.expectEqual(@as(f64, 0.25), rec.parity_ratio); // minimum
    try std.testing.expectEqual(@as(u32, 2), rec.parity_shards); // RS(8,2)
}

test "v2.2: full pipeline — dynamic erasure, 2PC, VSA locks, router, all subsystems on 400 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 400;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === STORE 80 SHARDS (scaled up from 60) ===
    var hashes: [80][32]u8 = undefined;
    for (0..80) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 133) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 266) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === REGION TOPOLOGY + ROUTER ===
    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
    });
    defer topo.deinit();

    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        const nid = makeNodeId(i);
        try topo.registerNode(nid, regions[i % 9]);
        latency_tracker.recordLatency(nid, @intCast((i % 9 + 1) * 5_000_000));
        reputation.recordPosResult(nid, i < 360); // 90% pass
        reputation.recordUptime(nid, if (i < 360) 3600 else 1800, 3600);
        reputation.recordBandwidth(nid, 10_000_000);
    }

    var router = region_router_mod.RegionRouter.init(allocator);
    defer router.deinit();

    const route = router.routeRequest(.us_east, &topo, &latency_tracker, &reputation);
    try std.testing.expect(route != null);

    // === DYNAMIC ERASURE CODING ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);

    health_report.node_count = 400;
    health_report.pos_challenges_issued = 4000;
    health_report.pos_challenges_passed = 3900;
    health_report.pos_challenges_failed = 100;
    health_report.scrub_total = 2000;
    health_report.scrub_corruptions = 8;
    health_report.reputation_avg = 0.91;
    health_report.reputation_min = 0.55;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 400_000_000;
    health_report.total_bytes_available = 4_000_000_000;
    health_report.shards_rebalanced = 60;

    var erasure_engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const ec_rec = erasure_engine.recommend(health_report, 8);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, ec_rec.health_level);
    try std.testing.expect(ec_rec.parity_shards >= 1);
    try std.testing.expect(ec_rec.confidence >= 0.5);

    // Second recommendation for degraded scenario
    var degraded_report = health_report;
    degraded_report.pos_challenges_failed = 800;
    degraded_report.scrub_corruptions = 100;
    degraded_report.reputation_avg = 0.55;
    degraded_report.shards_rebalanced = 500;
    const degraded_rec = erasure_engine.recommend(degraded_report, 8);
    try std.testing.expect(degraded_rec.parity_shards > ec_rec.parity_shards);

    // === CROSS-SHARD 2PC ===
    var coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer coord.deinit();

    const coordinator_id = makeNodeId(0);
    const tx1 = try coord.beginTransaction(coordinator_id, 1000);

    for (0..12) |s| {
        try coord.addParticipant(tx1, hashes[s], makeNodeId(s + 1), 1000);
    }

    // === VSA SHARD LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();

    for (0..12) |s| {
        const result = try locks.acquireLock(hashes[s], coordinator_id, tx1, 1000);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
    }

    for (0..12) |s| {
        try std.testing.expect(locks.verifyLock(hashes[s], coordinator_id));
    }

    try coord.prepare(tx1);
    for (0..12) |s| {
        try coord.recordVote(tx1, hashes[s], true);
    }
    const tx_result = try coord.commit(tx1, 2000);
    try std.testing.expect(tx_result.success);
    try std.testing.expectEqual(@as(u32, 12), tx_result.participants_committed);

    const released = locks.releaseTransactionLocks(tx1);
    try std.testing.expectEqual(@as(u32, 12), released);

    // === REPAIR ===
    for (0..8) |s| {
        if (nodes[s % NODE_COUNT].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..NODE_COUNT) |i| _ = scrubber.scrubNode(&nodes[i]);

    var repair_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
    defer repair_engine.deinit();
    _ = try repair_engine.hybridRepair(&scrubber, 0, &peers);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (360..368) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i));
        _ = try escrow.createEscrow(makeNodeId(i), 500, .pos_failure, 1000);
    }

    // === PROMETHEUS ===
    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const metrics_resp = try http_endpoint.handleRequest("/metrics", health_report, 5000);
    try std.testing.expectEqual(@as(u16, 200), metrics_resp.status_code);

    // === VERIFY ALL v2.2 SUBSYSTEMS ===
    try std.testing.expectEqual(@as(u64, 400), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);
    try std.testing.expect(route != null);

    try std.testing.expectEqual(@as(u64, 1), coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u64, 12), coord.getStats().total_participants);

    try std.testing.expectEqual(@as(u64, 12), locks.getStats().total_acquisitions);
    try std.testing.expectEqual(@as(u32, 0), locks.getStats().active_locks);

    try std.testing.expectEqual(@as(u32, 400), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 8), escrow.getStats().total_escrows);

    const ec_stats = erasure_engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), ec_stats.total_recommendations);
    try std.testing.expect(ec_stats.avg_health_score > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.3 INTEGRATION TESTS — 500-Node Scale, Saga Pattern
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.3: 500-node saga — full success path (multi-shard write saga)" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 500;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    // === STORE 100 SHARDS ===
    var hashes: [100][32]u8 = undefined;
    for (0..100) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === SAGA COORDINATOR: 50 successful sagas ===
    var coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer coord.deinit();

    for (0..50) |saga_i| {
        const coordinator_id = makeNodeId(saga_i);
        const saga_id = try coord.createSaga(coordinator_id, @intCast(1000 + saga_i * 100));

        // Each saga writes to 5 shards
        for (0..5) |step_j| {
            const shard_idx = (saga_i * 5 + step_j) % 100;
            const node_idx = (saga_i + step_j) % NODE_COUNT;
            _ = try coord.addStep(saga_id, .shard_write, hashes[shard_idx], makeNodeId(node_idx));
        }

        // Execute all steps sequentially
        try coord.execute(saga_id, @intCast(2000 + saga_i * 100));
        for (0..5) |step_j| {
            const result = try coord.stepSucceeded(saga_id, @intCast(step_j), @intCast(2000 + saga_i * 100 + (step_j + 1) * 10));
            if (step_j == 4) {
                // Last step should complete the saga
                try std.testing.expect(result != null);
                try std.testing.expect(result.?.success);
                try std.testing.expectEqual(saga_coordinator_mod.SagaPhase.completed, result.?.phase);
            }
        }
    }

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 50), stats.total_sagas);
    try std.testing.expectEqual(@as(u64, 50), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 250), stats.steps_succeeded); // 50 × 5
    try std.testing.expectEqual(@as(u64, 0), stats.compensated_sagas);
    try std.testing.expect(stats.avg_saga_duration_ms > 0);
}

test "v2.3: 500-node saga — failure and compensation (20 sagas, 10 fail)" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 500;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var hashes: [60][32]u8 = undefined;
    for (0..60) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
    }

    var coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer coord.deinit();

    // Create 20 sagas: first 10 succeed, last 10 fail at step 2
    for (0..20) |saga_i| {
        const saga_id = try coord.createSaga(makeNodeId(saga_i), @intCast(1000 + saga_i * 200));

        // 3 steps per saga
        for (0..3) |step_j| {
            const shard_idx = (saga_i * 3 + step_j) % 60;
            _ = try coord.addStep(saga_id, .shard_write, hashes[shard_idx], makeNodeId(step_j));
        }

        try coord.execute(saga_id, @intCast(2000 + saga_i * 200));

        // Step 0 always succeeds
        _ = try coord.stepSucceeded(saga_id, 0, @intCast(2050 + saga_i * 200));

        // Step 1 always succeeds
        _ = try coord.stepSucceeded(saga_id, 1, @intCast(2100 + saga_i * 200));

        if (saga_i < 10) {
            // Success: step 2 succeeds
            const result = try coord.stepSucceeded(saga_id, 2, @intCast(2150 + saga_i * 200));
            try std.testing.expect(result != null);
            try std.testing.expect(result.?.success);
        } else {
            // Failure: step 2 fails → compensation of steps 0, 1
            try coord.stepFailed(saga_id, 2, 500, @intCast(2150 + saga_i * 200));

            // Compensate step 1, then step 0
            _ = try coord.compensationSucceeded(saga_id, 1, @intCast(2200 + saga_i * 200));
            const comp_result = try coord.compensationSucceeded(saga_id, 0, @intCast(2250 + saga_i * 200));
            try std.testing.expect(comp_result != null);
            try std.testing.expectEqual(saga_coordinator_mod.SagaPhase.compensated, comp_result.?.phase);
        }
    }

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 20), stats.total_sagas);
    try std.testing.expectEqual(@as(u64, 10), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 10), stats.compensated_sagas);
    try std.testing.expectEqual(@as(u64, 50), stats.steps_succeeded); // 10×3 + 10×2
    try std.testing.expectEqual(@as(u64, 20), stats.steps_compensated); // 10×2
}

test "v2.3: 500-node saga — timeout and abort handling" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 500;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var hashes: [20][32]u8 = undefined;
    for (0..20) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
    }

    var coord = saga_coordinator_mod.SagaCoordinator.initWithConfig(allocator, .{
        .max_saga_duration_ms = 5000,
    });
    defer coord.deinit();

    // Saga 1: will timeout
    const s1 = try coord.createSaga(makeNodeId(0), 1000);
    _ = try coord.addStep(s1, .shard_write, hashes[0], makeNodeId(1));
    _ = try coord.addStep(s1, .lock_acquire, hashes[1], makeNodeId(2));
    try coord.execute(s1, 2000);
    _ = try coord.stepSucceeded(s1, 0, 2100);
    // Step 1 is running... will timeout

    // Saga 2: will be aborted
    const s2 = try coord.createSaga(makeNodeId(10), 3000);
    _ = try coord.addStep(s2, .shard_write, hashes[2], makeNodeId(3));
    _ = try coord.addStep(s2, .lock_acquire, hashes[3], makeNodeId(4));
    try coord.execute(s2, 4000);
    _ = try coord.stepSucceeded(s2, 0, 4100);

    // Abort saga 2
    try coord.abortSaga(s2, 4200);
    const s2_saga = coord.getSaga(s2).?;
    try std.testing.expectEqual(saga_coordinator_mod.SagaPhase.compensating, s2_saga.phase);

    // Compensate saga 2
    const s2_result = try coord.compensationSucceeded(s2, 0, 4300);
    try std.testing.expect(s2_result != null);
    try std.testing.expectEqual(saga_coordinator_mod.SagaPhase.compensated, s2_result.?.phase);

    // Check timeout on saga 1 (8 seconds after start)
    const timed_out = coord.checkTimeouts(10000);
    try std.testing.expectEqual(@as(u32, 1), timed_out);

    const s1_saga = coord.getSaga(s1).?;
    try std.testing.expectEqual(saga_coordinator_mod.SagaPhase.compensating, s1_saga.phase);
    try std.testing.expectEqual(saga_coordinator_mod.StepPhase.failed, s1_saga.steps.items[1].phase);
    try std.testing.expectEqual(@as(u32, 408), s1_saga.steps.items[1].error_code);

    // Compensate saga 1
    const s1_result = try coord.compensationSucceeded(s1, 0, 10100);
    try std.testing.expect(s1_result != null);

    const stats = coord.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.compensated_sagas);
}

test "v2.3: full pipeline — saga, dynamic erasure, 2PC, VSA locks, router, all subsystems on 500 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 500;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === STORE 100 SHARDS ===
    var hashes: [100][32]u8 = undefined;
    for (0..100) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 166) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 333) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === REGION TOPOLOGY + ROUTER ===
    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
    });
    defer topo.deinit();

    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        const nid = makeNodeId(i);
        try topo.registerNode(nid, regions[i % 9]);
        latency_tracker.recordLatency(nid, @intCast((i % 9 + 1) * 5_000_000));
        reputation.recordPosResult(nid, i < 450); // 90% pass
        reputation.recordUptime(nid, if (i < 450) 3600 else 1800, 3600);
        reputation.recordBandwidth(nid, 10_000_000);
    }

    var router = region_router_mod.RegionRouter.init(allocator);
    defer router.deinit();
    const route = router.routeRequest(.us_east, &topo, &latency_tracker, &reputation);
    try std.testing.expect(route != null);

    // === DYNAMIC ERASURE CODING ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);
    health_report.node_count = 500;
    health_report.pos_challenges_issued = 5000;
    health_report.pos_challenges_passed = 4900;
    health_report.pos_challenges_failed = 100;
    health_report.scrub_total = 3000;
    health_report.scrub_corruptions = 10;
    health_report.reputation_avg = 0.92;
    health_report.reputation_min = 0.50;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 500_000_000;
    health_report.total_bytes_available = 5_000_000_000;
    health_report.shards_rebalanced = 80;

    var erasure_engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const ec_rec = erasure_engine.recommend(health_report, 10);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, ec_rec.health_level);

    // === SAGA COORDINATOR: 10 successful + 5 compensated ===
    var saga_coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer saga_coord.deinit();

    // 10 successful sagas (4 steps each)
    for (0..10) |saga_i| {
        const saga_id = try saga_coord.createSaga(makeNodeId(saga_i), @intCast(5000 + saga_i * 100));
        for (0..4) |step_j| {
            _ = try saga_coord.addStep(saga_id, .shard_write, hashes[(saga_i * 4 + step_j) % 100], makeNodeId(step_j));
        }
        try saga_coord.execute(saga_id, @intCast(6000 + saga_i * 100));
        for (0..4) |step_j| {
            _ = try saga_coord.stepSucceeded(saga_id, @intCast(step_j), @intCast(6000 + saga_i * 100 + (step_j + 1) * 10));
        }
    }

    // 5 compensated sagas (3 steps each, step 2 fails)
    for (0..5) |saga_i| {
        const saga_id = try saga_coord.createSaga(makeNodeId(100 + saga_i), @intCast(8000 + saga_i * 100));
        for (0..3) |step_j| {
            _ = try saga_coord.addStep(saga_id, .lock_acquire, hashes[(50 + saga_i * 3 + step_j) % 100], makeNodeId(step_j));
        }
        try saga_coord.execute(saga_id, @intCast(9000 + saga_i * 100));
        _ = try saga_coord.stepSucceeded(saga_id, 0, @intCast(9050 + saga_i * 100));
        _ = try saga_coord.stepSucceeded(saga_id, 1, @intCast(9100 + saga_i * 100));
        try saga_coord.stepFailed(saga_id, 2, 500, @intCast(9150 + saga_i * 100));
        _ = try saga_coord.compensationSucceeded(saga_id, 1, @intCast(9200 + saga_i * 100));
        _ = try saga_coord.compensationSucceeded(saga_id, 0, @intCast(9250 + saga_i * 100));
    }

    // === CROSS-SHARD 2PC (for comparison) ===
    var tx_coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer tx_coord.deinit();

    const tx_id = try tx_coord.beginTransaction(makeNodeId(0), 10000);
    for (0..8) |s| {
        try tx_coord.addParticipant(tx_id, hashes[s], makeNodeId(s + 1), 10000);
    }

    // === VSA SHARD LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();
    for (0..8) |s| {
        const result = try locks.acquireLock(hashes[s], makeNodeId(0), tx_id, 10000);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
    }

    try tx_coord.prepare(tx_id);
    for (0..8) |s| {
        try tx_coord.recordVote(tx_id, hashes[s], true);
    }
    const tx_result = try tx_coord.commit(tx_id, 11000);
    try std.testing.expect(tx_result.success);
    const released = locks.releaseTransactionLocks(tx_id);
    try std.testing.expectEqual(@as(u32, 8), released);

    // === REPAIR ===
    for (0..10) |s| {
        if (nodes[s % NODE_COUNT].shards.getPtr(hashes[s])) |ptr| ptr.*[0] ^= 0xFF;
    }
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    for (0..NODE_COUNT) |i| _ = scrubber.scrubNode(&nodes[i]);

    var repair_engine = erasure_repair_mod.ErasureRepairEngine.init(allocator);
    defer repair_engine.deinit();
    _ = try repair_engine.hybridRepair(&scrubber, 0, &peers);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (450..460) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i));
        _ = try escrow.createEscrow(makeNodeId(i), 500, .pos_failure, 10000);
    }

    // === PROMETHEUS ===
    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const metrics_resp = try http_endpoint.handleRequest("/metrics", health_report, 12000);
    try std.testing.expectEqual(@as(u16, 200), metrics_resp.status_code);

    // === VERIFY ALL v2.3 SUBSYSTEMS ===
    try std.testing.expectEqual(@as(u64, 500), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    const saga_stats = saga_coord.getStats();
    try std.testing.expectEqual(@as(u64, 15), saga_stats.total_sagas);
    try std.testing.expectEqual(@as(u64, 10), saga_stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 5), saga_stats.compensated_sagas);
    try std.testing.expectEqual(@as(u64, 50), saga_stats.steps_succeeded); // 10×4 + 5×2
    try std.testing.expectEqual(@as(u64, 10), saga_stats.steps_compensated); // 5×2

    try std.testing.expectEqual(@as(u64, 1), tx_coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u64, 8), locks.getStats().total_acquisitions);
    try std.testing.expectEqual(@as(u32, 0), locks.getStats().active_locks);

    try std.testing.expectEqual(@as(u32, 500), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 10), escrow.getStats().total_escrows);
    try std.testing.expect(ec_rec.health_score >= 0.85);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.4 INTEGRATION TESTS — 600-Node Scale, Transaction Write-Ahead Log
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.4: 600-node WAL — saga lifecycle logging and recovery" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 600;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer wal.deinit();

    // Log 30 complete sagas (3 steps each)
    for (0..30) |saga_i| {
        const coord = makeNodeId(saga_i);
        const ts: i64 = @intCast(1000 + saga_i * 100);
        const sid: u64 = @intCast(saga_i + 1);

        _ = try wal.logSagaCreated(sid, coord, ts);
        for (0..3) |step_j| {
            _ = try wal.logSagaStepAdded(sid, @intCast(step_j), 0x01, ts + 10);
        }
        _ = try wal.logSagaExecuteStart(sid, ts + 50);
        for (0..3) |step_j| {
            _ = try wal.logSagaStepSucceeded(sid, @intCast(step_j), @intCast(ts + 60 + @as(i64, @intCast(step_j)) * 10));
        }
        _ = try wal.logSagaCompleted(sid, ts + 90);
    }

    // Log 10 incomplete sagas (executing, 2/3 steps done — simulates crash)
    for (0..10) |saga_i| {
        const coord = makeNodeId(100 + saga_i);
        const ts: i64 = @intCast(5000 + saga_i * 100);
        const sid: u64 = @intCast(31 + saga_i);

        _ = try wal.logSagaCreated(sid, coord, ts);
        for (0..3) |step_j| {
            _ = try wal.logSagaStepAdded(sid, @intCast(step_j), 0x01, ts + 10);
        }
        _ = try wal.logSagaExecuteStart(sid, ts + 50);
        _ = try wal.logSagaStepSucceeded(sid, 0, ts + 60);
        _ = try wal.logSagaStepSucceeded(sid, 1, ts + 70);
        // Step 2 never completed — crash
    }

    // Verify pre-recovery state
    try std.testing.expectEqual(@as(u32, 10), wal.getActiveCount()); // 10 incomplete

    // Run recovery
    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 10), report.sagas_recovered);
    try std.testing.expectEqual(@as(u32, 0), report.corrupted_records);

    // All 10 incomplete sagas should resume execution
    var resume_count: u32 = 0;
    for (report.recovery_entries.items) |entry| {
        if (entry.is_saga and entry.action == .saga_resume_execute) {
            try std.testing.expectEqual(@as(u32, 2), entry.steps_succeeded);
            resume_count += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 10), resume_count);

    const stats = wal.getStats();
    try std.testing.expect(stats.saga_events > 200); // 30×8 + 10×7 = 310
    try std.testing.expectEqual(@as(u64, 1), stats.recoveries_performed);
}

test "v2.4: 600-node WAL — 2PC crash recovery (commit-phase crash)" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 600;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var hashes: [60][32]u8 = undefined;
    for (0..60) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
    }

    var wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer wal.deinit();

    // TX 1-5: complete (commit phase finished)
    for (0..5) |tx_i| {
        const coord = makeNodeId(tx_i);
        const tid: u64 = @intCast(tx_i + 1);
        const ts: i64 = @intCast(1000 + tx_i * 200);

        _ = try wal.logTxCreated(tid, coord, ts);
        for (0..4) |p| {
            _ = try wal.logTxParticipantAdded(tid, hashes[tx_i * 4 + p], makeNodeId(p + 100), ts + 10);
        }
        _ = try wal.logTxPrepareStart(tid, ts + 50);
        for (0..4) |p| {
            _ = try wal.logTxVoteReceived(tid, hashes[tx_i * 4 + p], true, ts + 60);
        }
        _ = try wal.logTxCommitStart(tid, ts + 80);
        _ = try wal.logTxCommitComplete(tid, ts + 90);
    }

    // TX 6-10: crashed during commit (commit_start logged, not commit_complete)
    for (0..5) |tx_i| {
        const coord = makeNodeId(50 + tx_i);
        const tid: u64 = @intCast(6 + tx_i);
        const ts: i64 = @intCast(3000 + tx_i * 200);

        _ = try wal.logTxCreated(tid, coord, ts);
        for (0..3) |p| {
            _ = try wal.logTxParticipantAdded(tid, hashes[20 + tx_i * 3 + p], makeNodeId(p + 200), ts + 10);
        }
        _ = try wal.logTxPrepareStart(tid, ts + 50);
        for (0..3) |p| {
            _ = try wal.logTxVoteReceived(tid, hashes[20 + tx_i * 3 + p], true, ts + 60);
        }
        _ = try wal.logTxCommitStart(tid, ts + 80);
        // CRASH — commit_complete never logged
    }

    try std.testing.expectEqual(@as(u32, 5), wal.getActiveCount()); // 5 incomplete TXs

    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 5), report.txs_recovered);
    try std.testing.expectEqual(@as(u32, 0), report.corrupted_records);

    // All 5 should resume commit
    var commit_resume_count: u32 = 0;
    for (report.recovery_entries.items) |entry| {
        if (!entry.is_saga and entry.action == .tx_resume_commit) {
            try std.testing.expectEqual(@as(u32, 3), entry.step_count); // 3 participants
            commit_resume_count += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 5), commit_resume_count);

    const stats = wal.getStats();
    try std.testing.expect(stats.tx_events > 50);
}

test "v2.4: 600-node WAL — mixed saga + 2PC with checkpoints" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 600;

    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var hashes: [20][32]u8 = undefined;
    for (0..20) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
    }

    var wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer wal.deinit();

    const coord = makeNodeId(0);

    // Complete saga
    _ = try wal.logSagaCreated(1, coord, 1000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 1010);
    _ = try wal.logSagaExecuteStart(1, 1050);
    _ = try wal.logSagaStepSucceeded(1, 0, 1060);
    _ = try wal.logSagaCompleted(1, 1070);

    // Checkpoint
    _ = try wal.writeCheckpoint(1500);

    // Complete 2PC
    _ = try wal.logTxCreated(2, coord, 2000);
    _ = try wal.logTxParticipantAdded(2, hashes[0], makeNodeId(1), 2010);
    _ = try wal.logTxPrepareStart(2, 2050);
    _ = try wal.logTxVoteReceived(2, hashes[0], true, 2060);
    _ = try wal.logTxCommitStart(2, 2080);
    _ = try wal.logTxCommitComplete(2, 2090);

    // Incomplete saga (compensating)
    _ = try wal.logSagaCreated(3, coord, 3000);
    _ = try wal.logSagaStepAdded(3, 0, 0x01, 3010);
    _ = try wal.logSagaStepAdded(3, 1, 0x02, 3020);
    _ = try wal.logSagaExecuteStart(3, 3050);
    _ = try wal.logSagaStepSucceeded(3, 0, 3060);
    _ = try wal.logSagaStepFailed(3, 1, 500, 3070);
    // Compensation not logged — crash during compensation

    try std.testing.expectEqual(@as(u32, 1), wal.getActiveCount());

    var report = try wal.recover();
    defer report.recovery_entries.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 1), report.checkpoints_found);
    try std.testing.expectEqual(@as(u32, 1), report.sagas_recovered);
    try std.testing.expectEqual(@as(u32, 0), report.txs_recovered);

    // Find incomplete saga 3
    var found = false;
    for (report.recovery_entries.items) |entry| {
        if (entry.id == 3 and entry.is_saga) {
            try std.testing.expectEqual(transaction_wal_mod.RecoveryAction.saga_resume_compensate, entry.action);
            found = true;
        }
    }
    try std.testing.expect(found);

    const stats = wal.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.checkpoints);
    try std.testing.expect(stats.saga_events > 0);
    try std.testing.expect(stats.tx_events > 0);
}

test "v2.4: full pipeline — WAL, saga, dynamic erasure, 2PC, VSA locks, router, all subsystems on 600 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 600;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === STORE 120 SHARDS ===
    var hashes: [120][32]u8 = undefined;
    for (0..120) |s| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(s + 0x80));
        std.crypto.hash.sha2.Sha256.hash(&data, &hashes[s], .{});
        _ = try nodes[s % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 200) % NODE_COUNT].storeShard(hashes[s], &data);
        _ = try nodes[(s + 400) % NODE_COUNT].storeShard(hashes[s], &data);
    }

    // === TRANSACTION WAL ===
    var wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer wal.deinit();

    // === SAGA WITH WAL LOGGING ===
    var saga_coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer saga_coord.deinit();

    // 5 sagas logged to WAL
    for (0..5) |saga_i| {
        const coord_id = makeNodeId(saga_i);
        const ts: i64 = @intCast(1000 + saga_i * 200);
        const saga_id = try saga_coord.createSaga(coord_id, ts);
        _ = try wal.logSagaCreated(saga_id, coord_id, ts);

        for (0..3) |step_j| {
            _ = try saga_coord.addStep(saga_id, .shard_write, hashes[saga_i * 3 + step_j], makeNodeId(step_j + 100));
            _ = try wal.logSagaStepAdded(saga_id, @intCast(step_j), 0x01, ts + 10);
        }

        try saga_coord.execute(saga_id, ts + 50);
        _ = try wal.logSagaExecuteStart(saga_id, ts + 50);

        for (0..3) |step_j| {
            _ = try saga_coord.stepSucceeded(saga_id, @intCast(step_j), @intCast(ts + 60 + @as(i64, @intCast(step_j)) * 10));
            _ = try wal.logSagaStepSucceeded(saga_id, @intCast(step_j), @intCast(ts + 60 + @as(i64, @intCast(step_j)) * 10));
        }
        _ = try wal.logSagaCompleted(saga_id, ts + 90);
    }

    // === 2PC WITH WAL LOGGING ===
    var tx_coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer tx_coord.deinit();

    const tx_coord_id = makeNodeId(0);
    const tx_id = try tx_coord.beginTransaction(tx_coord_id, 5000);
    _ = try wal.logTxCreated(tx_id, tx_coord_id, 5000);

    for (0..6) |s| {
        try tx_coord.addParticipant(tx_id, hashes[s], makeNodeId(s + 1), 5000);
        _ = try wal.logTxParticipantAdded(tx_id, hashes[s], makeNodeId(s + 1), 5010);
    }

    try tx_coord.prepare(tx_id);
    _ = try wal.logTxPrepareStart(tx_id, 5050);

    for (0..6) |s| {
        try tx_coord.recordVote(tx_id, hashes[s], true);
        _ = try wal.logTxVoteReceived(tx_id, hashes[s], true, 5060);
    }

    _ = try wal.logTxCommitStart(tx_id, 5080);
    const tx_result = try tx_coord.commit(tx_id, 5090);
    try std.testing.expect(tx_result.success);
    _ = try wal.logTxCommitComplete(tx_id, 5090);

    // Checkpoint
    _ = try wal.writeCheckpoint(6000);

    // === REGION TOPOLOGY + ROUTER ===
    var topo = region_topology_mod.RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
    });
    defer topo.deinit();

    var latency_tracker = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency_tracker.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };

    for (0..NODE_COUNT) |i| {
        const nid = makeNodeId(i);
        try topo.registerNode(nid, regions[i % 9]);
        latency_tracker.recordLatency(nid, @intCast((i % 9 + 1) * 5_000_000));
        reputation.recordPosResult(nid, i < 540); // 90% pass
        reputation.recordUptime(nid, if (i < 540) 3600 else 1800, 3600);
    }

    var router = region_router_mod.RegionRouter.init(allocator);
    defer router.deinit();
    const route = router.routeRequest(.us_east, &topo, &latency_tracker, &reputation);
    try std.testing.expect(route != null);

    // === DYNAMIC ERASURE ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);
    health_report.node_count = 600;
    health_report.pos_challenges_issued = 6000;
    health_report.pos_challenges_passed = 5900;
    health_report.pos_challenges_failed = 100;
    health_report.scrub_total = 3000;
    health_report.scrub_corruptions = 10;
    health_report.reputation_avg = 0.93;
    health_report.reputation_min = 0.50;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 600_000_000;
    health_report.total_bytes_available = 6_000_000_000;
    health_report.shards_rebalanced = 100;

    var erasure_engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const ec_rec = erasure_engine.recommend(health_report, 10);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, ec_rec.health_level);

    // === VSA SHARD LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();
    for (0..10) |s| {
        const result = try locks.acquireLock(hashes[s], tx_coord_id, tx_id, 7000);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
    }
    const released = locks.releaseTransactionLocks(tx_id);
    try std.testing.expectEqual(@as(u32, 10), released);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (540..552) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i));
        _ = try escrow.createEscrow(makeNodeId(i), 500, .pos_failure, 7000);
    }

    // === PROMETHEUS ===
    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const metrics_resp = try http_endpoint.handleRequest("/metrics", health_report, 8000);
    try std.testing.expectEqual(@as(u16, 200), metrics_resp.status_code);

    // === VERIFY ALL v2.4 SUBSYSTEMS ===
    const wal_stats = wal.getStats();
    try std.testing.expect(wal_stats.total_records_written > 50);
    try std.testing.expect(wal_stats.saga_events > 0);
    try std.testing.expect(wal_stats.tx_events > 0);
    try std.testing.expectEqual(@as(u64, 1), wal_stats.checkpoints);
    try std.testing.expectEqual(@as(u32, 0), wal.getActiveCount()); // all complete

    try std.testing.expectEqual(@as(u64, 600), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    const saga_stats = saga_coord.getStats();
    try std.testing.expectEqual(@as(u64, 5), saga_stats.completed_sagas);

    try std.testing.expectEqual(@as(u64, 1), tx_coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u32, 600), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 12), escrow.getStats().total_escrows);
    try std.testing.expect(ec_rec.health_score >= 0.85);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.5 TESTS — 700-Node Scale: Parallel Step Execution (Dependency Graph)
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.5: 700-node parallel saga — diamond pattern (fan-out + fan-in)" {
    const allocator = std.testing.allocator;
    const NODE_COUNT: u32 = 700;

    // === PARALLEL SAGA: DIAMOND PATTERN ===
    // 30 sagas, each: step 0 → (steps 1,2,3 parallel) → step 4
    var engine = parallel_saga_mod.ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = makeNodeId(0);

    for (0..30) |saga_i| {
        const saga_id = try engine.createSaga(cid, 1000 + @as(i64, @intCast(saga_i)) * 100);

        // Step 0: root (level 0)
        const s0 = try engine.addStep(saga_id, .shard_write, makeNodeId(saga_i % NODE_COUNT), makeNodeId(saga_i));
        // Steps 1,2,3: depend on step 0 (level 1 — run in parallel)
        const s1 = try engine.addStepWithDeps(saga_id, .lock_acquire, makeNodeId((saga_i + 1) % NODE_COUNT), makeNodeId(saga_i), &.{s0});
        const s2 = try engine.addStepWithDeps(saga_id, .stake_lock, makeNodeId((saga_i + 2) % NODE_COUNT), makeNodeId(saga_i), &.{s0});
        const s3 = try engine.addStepWithDeps(saga_id, .escrow_create, makeNodeId((saga_i + 3) % NODE_COUNT), makeNodeId(saga_i), &.{s0});
        // Step 4: fan-in (level 2 — depends on all 3)
        _ = try engine.addStepWithDeps(saga_id, .route_select, makeNodeId(saga_i % NODE_COUNT), makeNodeId(saga_i), &.{ s1, s2, s3 });

        // Execute
        const started = try engine.execute(saga_id, 2000 + @as(i64, @intCast(saga_i)) * 100);
        try std.testing.expectEqual(@as(u32, 1), started); // only root at level 0

        // Step 0 succeeds → 3 parallel steps start
        _ = try engine.stepSucceeded(saga_id, 0, 2050 + @as(i64, @intCast(saga_i)) * 100);
        // Steps 1,2,3 succeed in parallel
        _ = try engine.stepSucceeded(saga_id, 1, 2060 + @as(i64, @intCast(saga_i)) * 100);
        _ = try engine.stepSucceeded(saga_id, 2, 2060 + @as(i64, @intCast(saga_i)) * 100);
        _ = try engine.stepSucceeded(saga_id, 3, 2060 + @as(i64, @intCast(saga_i)) * 100);
        // Step 4 succeeds → saga completed
        const result = try engine.stepSucceeded(saga_id, 4, 2070 + @as(i64, @intCast(saga_i)) * 100);
        try std.testing.expect(result != null);
        try std.testing.expect(result.?.success);
        try std.testing.expectEqual(@as(u32, 3), result.?.levels_executed); // 3 levels
        try std.testing.expectEqual(@as(u32, 3), result.?.max_parallelism); // 3 parallel at level 1
    }

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 30), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 150), stats.steps_succeeded); // 30 × 5
    try std.testing.expect(stats.max_parallelism_seen >= 3);
    try std.testing.expect(stats.avg_parallelism >= 2.0); // average across sagas
}

test "v2.5: 700-node parallel saga — failure with parallel compensation" {
    const allocator = std.testing.allocator;
    const NODE_COUNT: u32 = 700;

    var engine = parallel_saga_mod.ParallelSagaEngine.init(allocator);
    defer engine.deinit();

    const cid = makeNodeId(0);

    // 20 sagas: 10 succeed, 10 fail at step 3 (level 1)
    for (0..20) |saga_i| {
        const saga_id = try engine.createSaga(cid, 1000 + @as(i64, @intCast(saga_i)) * 100);
        const will_fail = saga_i >= 10;

        // Diamond: s0 → (s1, s2, s3) → s4
        const s0 = try engine.addStep(saga_id, .shard_write, makeNodeId(saga_i % NODE_COUNT), makeNodeId(saga_i));
        const s1 = try engine.addStepWithDeps(saga_id, .lock_acquire, makeNodeId(saga_i), makeNodeId(saga_i), &.{s0});
        const s2 = try engine.addStepWithDeps(saga_id, .stake_lock, makeNodeId(saga_i), makeNodeId(saga_i), &.{s0});
        const s3 = try engine.addStepWithDeps(saga_id, .escrow_create, makeNodeId(saga_i), makeNodeId(saga_i), &.{s0});
        _ = try engine.addStepWithDeps(saga_id, .route_select, makeNodeId(saga_i), makeNodeId(saga_i), &.{ s1, s2, s3 });

        _ = try engine.execute(saga_id, 2000);
        _ = try engine.stepSucceeded(saga_id, 0, 2050); // root succeeds

        if (will_fail) {
            // Steps 1,2 succeed but step 3 fails
            _ = try engine.stepSucceeded(saga_id, 1, 2060);
            _ = try engine.stepSucceeded(saga_id, 2, 2060);
            try engine.stepFailed(saga_id, 3, 500, 2070);

            // Compensate steps 0, 1, 2 (all succeeded before failure)
            _ = try engine.compensationSucceeded(saga_id, 2, 2080);
            _ = try engine.compensationSucceeded(saga_id, 1, 2080);
            const comp_result = try engine.compensationSucceeded(saga_id, 0, 2090);
            try std.testing.expect(comp_result != null);
            try std.testing.expectEqual(parallel_saga_mod.ParallelSagaPhase.compensated, comp_result.?.phase);
        } else {
            // All succeed
            _ = try engine.stepSucceeded(saga_id, 1, 2060);
            _ = try engine.stepSucceeded(saga_id, 2, 2060);
            _ = try engine.stepSucceeded(saga_id, 3, 2060);
            const result = try engine.stepSucceeded(saga_id, 4, 2070);
            try std.testing.expect(result != null);
            try std.testing.expect(result.?.success);
        }
    }

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 10), stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 10), stats.compensated_sagas);
    // 10 sagas × 5 steps + 10 sagas × 3 succeeded = 80
    try std.testing.expectEqual(@as(u64, 80), stats.steps_succeeded);
    try std.testing.expectEqual(@as(u64, 30), stats.steps_compensated); // 10 × 3
}

test "v2.5: 700-node parallel saga — fully parallel (all level 0) with timeout and abort" {
    const allocator = std.testing.allocator;

    var engine = parallel_saga_mod.ParallelSagaEngine.initWithConfig(allocator, .{
        .max_saga_duration_ms = 5000,
    });
    defer engine.deinit();

    const cid = makeNodeId(0);
    const shard = makeNodeId(1);
    const node = makeNodeId(2);

    // Saga 1: 8 fully parallel steps, times out after 5 seconds
    const s1_id = try engine.createSaga(cid, 1000);
    for (0..8) |_| _ = try engine.addStep(s1_id, .shard_write, shard, node);
    const started1 = try engine.execute(s1_id, 2000);
    try std.testing.expectEqual(@as(u32, 8), started1); // all 8 at level 0

    // Complete 4 of 8, then timeout
    for (0..4) |i| _ = try engine.stepSucceeded(s1_id, @intCast(i), 2100);
    const timed_out = engine.checkTimeouts(12000);
    try std.testing.expectEqual(@as(u32, 1), timed_out);

    // Compensate 4 succeeded steps
    for (0..4) |i| _ = try engine.compensationSucceeded(s1_id, @intCast(i), 12100);

    const saga1 = engine.getSaga(s1_id).?;
    try std.testing.expectEqual(parallel_saga_mod.ParallelSagaPhase.compensated, saga1.phase);
    try std.testing.expectEqual(@as(u32, 4), saga1.steps_compensated);

    // Saga 2: 6 fully parallel steps, explicitly aborted
    const s2_id = try engine.createSaga(cid, 3000);
    for (0..6) |_| _ = try engine.addStep(s2_id, .lock_acquire, shard, node);
    const started2 = try engine.execute(s2_id, 4000);
    try std.testing.expectEqual(@as(u32, 6), started2);

    // Complete 2 then abort
    _ = try engine.stepSucceeded(s2_id, 0, 4100);
    _ = try engine.stepSucceeded(s2_id, 1, 4100);
    try engine.abortSaga(s2_id, 4200);

    // Compensate 2 succeeded steps
    _ = try engine.compensationSucceeded(s2_id, 0, 4300);
    _ = try engine.compensationSucceeded(s2_id, 1, 4300);

    const saga2 = engine.getSaga(s2_id).?;
    try std.testing.expectEqual(parallel_saga_mod.ParallelSagaPhase.compensated, saga2.phase);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.compensated_sagas);
    try std.testing.expect(stats.max_parallelism_seen >= 8);
}

test "v2.5: full pipeline — parallel saga, WAL, sequential saga, dynamic erasure, 2PC, VSA locks, router, all subsystems on 700 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 700;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === REGION TOPOLOGY (700 nodes across 9 regions) ===
    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    const regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };
    for (0..NODE_COUNT) |i| {
        try topo.registerNode(makeNodeId(i), regions[i % 9]);
    }
    try std.testing.expectEqual(@as(u64, 700), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    // === DYNAMIC ERASURE ===
    var reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = reporter.generateReport(peers_const, null, null, null, null, null, null);
    health_report.node_count = 700;
    health_report.pos_challenges_issued = 7000;
    health_report.pos_challenges_passed = 6900;
    health_report.pos_challenges_failed = 100;
    health_report.scrub_total = 3500;
    health_report.scrub_corruptions = 10;
    health_report.reputation_avg = 0.93;
    health_report.reputation_min = 0.50;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 700_000_000;
    health_report.total_bytes_available = 7_000_000_000;
    health_report.shards_rebalanced = 120;

    var erasure_engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const ec_rec = erasure_engine.recommend(health_report, 10);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, ec_rec.health_level);

    // === PARALLEL SAGA (v2.5 — NEW) ===
    var par_engine = parallel_saga_mod.ParallelSagaEngine.init(allocator);
    defer par_engine.deinit();

    const cid = makeNodeId(0);

    // 10 diamond sagas (succeed) + 5 diamond sagas (compensated)
    for (0..15) |saga_i| {
        const saga_id = try par_engine.createSaga(cid, 5000 + @as(i64, @intCast(saga_i)) * 100);
        const will_fail = saga_i >= 10;

        const s0 = try par_engine.addStep(saga_id, .shard_write, makeNodeId(saga_i % NODE_COUNT), makeNodeId(saga_i));
        const s1 = try par_engine.addStepWithDeps(saga_id, .lock_acquire, makeNodeId(saga_i), makeNodeId(saga_i), &.{s0});
        const s2 = try par_engine.addStepWithDeps(saga_id, .stake_lock, makeNodeId(saga_i), makeNodeId(saga_i), &.{s0});
        _ = try par_engine.addStepWithDeps(saga_id, .route_select, makeNodeId(saga_i), makeNodeId(saga_i), &.{ s1, s2 });

        _ = try par_engine.execute(saga_id, 6000);
        _ = try par_engine.stepSucceeded(saga_id, 0, 6010);

        if (will_fail) {
            _ = try par_engine.stepSucceeded(saga_id, 1, 6020);
            try par_engine.stepFailed(saga_id, 2, 500, 6030);
            _ = try par_engine.compensationSucceeded(saga_id, 1, 6040);
            _ = try par_engine.compensationSucceeded(saga_id, 0, 6050);
        } else {
            _ = try par_engine.stepSucceeded(saga_id, 1, 6020);
            _ = try par_engine.stepSucceeded(saga_id, 2, 6020);
            _ = try par_engine.stepSucceeded(saga_id, 3, 6030);
        }
    }

    const par_stats = par_engine.getStats();
    try std.testing.expectEqual(@as(u64, 10), par_stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 5), par_stats.compensated_sagas);
    try std.testing.expect(par_stats.max_parallelism_seen >= 2);

    // === TRANSACTION WAL ===
    var wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer wal.deinit();
    _ = try wal.logSagaCreated(1, cid, 7000);
    _ = try wal.logSagaStepAdded(1, 0, 0x01, 7001);
    _ = try wal.logSagaStepAdded(1, 1, 0x01, 7002);
    _ = try wal.logSagaExecuteStart(1, 7010);
    _ = try wal.logSagaStepSucceeded(1, 0, 7020);
    _ = try wal.logSagaStepSucceeded(1, 1, 7030);
    _ = try wal.logSagaCompleted(1, 7040);
    _ = try wal.logTxCreated(100, cid, 7100);
    for (0..10) |p| _ = try wal.logTxParticipantAdded(100, makeNodeId(p), makeNodeId(p + 100), 7110);
    _ = try wal.logTxPrepareStart(100, 7200);
    for (0..10) |v| _ = try wal.logTxVoteReceived(100, makeNodeId(v), true, 7210);
    _ = try wal.logTxCommitStart(100, 7300);
    _ = try wal.logTxCommitComplete(100, 7400);
    _ = try wal.writeCheckpoint(7500);

    const wal_stats = wal.getStats();
    try std.testing.expect(wal_stats.total_records_written > 20);
    try std.testing.expect(wal_stats.saga_events > 0);
    try std.testing.expect(wal_stats.tx_events > 0);
    try std.testing.expectEqual(@as(u64, 1), wal_stats.checkpoints);

    // === SEQUENTIAL SAGA (v2.3) ===
    var saga_coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer saga_coord.deinit();
    for (0..5) |si| {
        const sid = try saga_coord.createSaga(cid, 8000 + @as(i64, @intCast(si)) * 100);
        for (0..3) |_| _ = try saga_coord.addStep(sid, .shard_write, makeNodeId(si), makeNodeId(si));
        try saga_coord.execute(sid, 8050 + @as(i64, @intCast(si)) * 100);
        _ = try saga_coord.stepSucceeded(sid, 0, 8060 + @as(i64, @intCast(si)) * 100);
        _ = try saga_coord.stepSucceeded(sid, 1, 8070 + @as(i64, @intCast(si)) * 100);
        _ = try saga_coord.stepSucceeded(sid, 2, 8080 + @as(i64, @intCast(si)) * 100);
    }
    try std.testing.expectEqual(@as(u64, 5), saga_coord.getStats().completed_sagas);

    // === 2PC ===
    var tx_coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer tx_coord.deinit();
    const tx_id = try tx_coord.beginTransaction(cid, 9000);
    var tx_hashes: [8][32]u8 = undefined;
    for (0..8) |p| {
        tx_hashes[p] = makeNodeId(p + 200);
        try tx_coord.addParticipant(tx_id, tx_hashes[p], makeNodeId(p + 100), 9050);
    }
    try tx_coord.prepare(tx_id);
    for (0..8) |p| try tx_coord.recordVote(tx_id, tx_hashes[p], true);
    const tx_result = try tx_coord.commit(tx_id, 9200);
    try std.testing.expect(tx_result.success);
    try std.testing.expectEqual(@as(u64, 1), tx_coord.getStats().committed_transactions);

    // === VSA LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();
    var hashes: [10][32]u8 = undefined;
    for (0..10) |s| hashes[s] = makeNodeId(s + 500);
    const tx_coord_id = makeNodeId(999);
    for (0..10) |s| {
        const result = try locks.acquireLock(hashes[s], tx_coord_id, tx_id, 9300);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, result);
    }
    const released = locks.releaseTransactionLocks(tx_id);
    try std.testing.expectEqual(@as(u32, 10), released);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (0..12) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i + 640));
        _ = try escrow.createEscrow(makeNodeId(i + 640), 500, .pos_failure, 9400);
    }

    // === PROMETHEUS ===
    var http_endpoint = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer http_endpoint.deinit();
    const metrics_resp = try http_endpoint.handleRequest("/metrics", health_report, 9500);
    try std.testing.expectEqual(@as(u16, 200), metrics_resp.status_code);

    // === VERIFY ALL v2.5 SUBSYSTEMS ===
    try std.testing.expectEqual(@as(u64, 700), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);
    try std.testing.expectEqual(@as(u64, 10), par_stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 5), par_stats.compensated_sagas);
    try std.testing.expect(par_stats.max_parallelism_seen >= 2);
    try std.testing.expect(wal_stats.total_records_written > 20);
    try std.testing.expectEqual(@as(u64, 5), saga_coord.getStats().completed_sagas);
    try std.testing.expectEqual(@as(u64, 1), tx_coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u32, 700), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 12), escrow.getStats().total_escrows);
    try std.testing.expect(ec_rec.health_score >= 0.85);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.6 TESTS — WAL Disk Persistence, 800-Node Scale
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.6: 800-node WAL disk persistence — saga lifecycle with fsync and rotation" {
    const allocator = std.testing.allocator;

    // Initialize WAL Disk with rotation every 50 records
    var wd = wal_disk_mod.WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 50,
        .fsync_per_write = true,
    });
    defer wd.deinit();
    try wd.open(1000);

    // Run 40 saga lifecycles (each ~5 records = 200 total, 4+ segments)
    for (0..40) |i| {
        const saga_id: u64 = @intCast(i + 1);
        const coord_id = makeNodeId(i % 800);
        const ts: i64 = 1000 + @as(i64, @intCast(i)) * 100;

        _ = try wd.logSagaCreated(saga_id, coord_id, ts);
        _ = try wd.logSagaStepAdded(saga_id, 0, 0x01, ts + 10);
        _ = try wd.logSagaExecuteStart(saga_id, ts + 20);
        _ = try wd.logSagaStepSucceeded(saga_id, 0, ts + 30);
        _ = try wd.logSagaCompleted(saga_id, ts + 40);
    }

    // Verify rotation occurred
    const disk_stats = wd.getDiskStats();
    try std.testing.expect(disk_stats.total_segments_created >= 4);
    try std.testing.expectEqual(@as(u64, 200), disk_stats.total_records_on_disk);
    try std.testing.expect(disk_stats.total_fsyncs >= 200);

    // All 40 sagas complete
    for (0..40) |i| {
        const saga_id: u64 = @intCast(i + 1);
        try std.testing.expect(wd.isComplete(saga_id));
    }
    try std.testing.expectEqual(@as(u32, 0), wd.getActiveCount());
}

test "v2.6: 800-node WAL disk persistence — batch fsync mode with 2PC" {
    const allocator = std.testing.allocator;

    // Batch fsync mode: sync every 8 records
    var wd = wal_disk_mod.WalDisk.initWithConfig(allocator, .{
        .fsync_per_write = false,
        .fsync_on_batch = true,
        .batch_size = 8,
    });
    defer wd.deinit();
    try wd.open(1000);

    // Run 20 2PC transactions (each ~6 records = 120 total, 15 batch fsyncs)
    for (0..20) |i| {
        const tx_id: u64 = @intCast(i + 1);
        const coord_id = makeNodeId(i % 800);
        const shard = makeNodeId(i + 100);
        const node = makeNodeId(i + 200);
        const ts: i64 = 1000 + @as(i64, @intCast(i)) * 100;

        _ = try wd.logTxCreated(tx_id, coord_id, ts);
        _ = try wd.logTxParticipantAdded(tx_id, shard, node, ts + 10);
        _ = try wd.logTxPrepareStart(tx_id, ts + 20);
        _ = try wd.logTxVoteReceived(tx_id, shard, true, ts + 30);
        _ = try wd.logTxCommitStart(tx_id, ts + 40);
        _ = try wd.logTxCommitComplete(tx_id, ts + 50);
    }

    const disk_stats = wd.getDiskStats();
    try std.testing.expectEqual(@as(u64, 120), disk_stats.total_records_on_disk);
    try std.testing.expect(disk_stats.total_fsyncs >= 15);

    // All 20 transactions complete
    for (0..20) |i| {
        try std.testing.expect(wd.isComplete(@intCast(i + 1)));
    }

    // Flush remaining
    try wd.flush(9000);
}

test "v2.6: 800-node WAL disk persistence — compaction under load" {
    const allocator = std.testing.allocator;

    var wd = wal_disk_mod.WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 100,
        .fsync_per_write = false,
    });
    defer wd.deinit();
    try wd.open(1000);

    // Phase 1: 30 completed sagas (150 records)
    for (0..30) |i| {
        const saga_id: u64 = @intCast(i + 1);
        const coord_id = makeNodeId(i % 800);
        const ts: i64 = 1000 + @as(i64, @intCast(i)) * 100;

        _ = try wd.logSagaCreated(saga_id, coord_id, ts);
        _ = try wd.logSagaStepAdded(saga_id, 0, 0x01, ts + 10);
        _ = try wd.logSagaExecuteStart(saga_id, ts + 20);
        _ = try wd.logSagaStepSucceeded(saga_id, 0, ts + 30);
        _ = try wd.logSagaCompleted(saga_id, ts + 40);
    }

    // Phase 2: 10 incomplete sagas (30 records)
    for (0..10) |i| {
        const saga_id: u64 = @intCast(i + 31);
        const coord_id = makeNodeId(i % 800);
        const ts: i64 = 5000 + @as(i64, @intCast(i)) * 100;

        _ = try wd.logSagaCreated(saga_id, coord_id, ts);
        _ = try wd.logSagaStepAdded(saga_id, 0, 0x01, ts + 10);
        _ = try wd.logSagaExecuteStart(saga_id, ts + 20);
    }

    // Before compaction: 180 records
    try std.testing.expectEqual(@as(usize, 180), wd.wal.records.items.len);
    try std.testing.expectEqual(@as(u32, 10), wd.getActiveCount());

    // Compact
    const result = try wd.compact(8000);

    // 30 completed sagas (150 records) purged, 10 active (30 records) kept
    try std.testing.expectEqual(@as(u64, 180), result.records_before);
    try std.testing.expectEqual(@as(u64, 30), result.records_after);
    try std.testing.expectEqual(@as(u64, 150), result.completed_ops_purged);
    try std.testing.expect(result.bytes_before > result.bytes_after);
    try std.testing.expectEqual(@as(u32, 10), wd.getActiveCount());
    try std.testing.expectEqual(@as(u64, 1), wd.stats.total_segments_compacted);
}

test "v2.6: full pipeline — WAL disk, parallel saga, sequential saga, dynamic erasure, 2PC, VSA locks, router, all subsystems on 800 nodes" {
    const allocator = std.testing.allocator;
    const NODE_COUNT = 800;

    // === STORAGE NODES ===
    var nodes: [NODE_COUNT]storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..NODE_COUNT) |i| nodes[i].deinit();

    var peers: [NODE_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..NODE_COUNT) |i| peers[i] = &nodes[i];

    // === REGION TOPOLOGY (800 nodes across 9 regions) ===
    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    const v26_regions = [_]region_topology_mod.Region{
        .us_east,    .us_west, .eu_west,       .eu_east, .asia_east,
        .asia_south, .oceania, .south_america, .africa,
    };
    for (0..NODE_COUNT) |i| {
        try topo.registerNode(makeNodeId(i), v26_regions[i % 9]);
    }
    try std.testing.expectEqual(@as(u64, 800), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    // === DYNAMIC ERASURE ===
    var stat_reporter = network_stats_mod.NetworkStatsReporter.init(allocator);
    const peers_const: []const *storage_mod.StorageProvider = &peers;
    var health_report = stat_reporter.generateReport(peers_const, null, null, null, null, null, null);
    health_report.node_count = 800;
    health_report.pos_challenges_issued = 8000;
    health_report.pos_challenges_passed = 7880;
    health_report.pos_challenges_failed = 120;
    health_report.scrub_total = 4000;
    health_report.scrub_corruptions = 12;
    health_report.reputation_avg = 0.94;
    health_report.reputation_min = 0.52;
    health_report.reputation_max = 0.99;
    health_report.total_bytes_used = 800_000_000;
    health_report.total_bytes_available = 8_000_000_000;
    health_report.shards_rebalanced = 140;

    var erasure_engine = dynamic_erasure_mod.DynamicErasureEngine.init(.{});
    const ec_rec = erasure_engine.recommend(health_report, 10);
    try std.testing.expectEqual(dynamic_erasure_mod.HealthLevel.excellent, ec_rec.health_level);

    // === WAL DISK PERSISTENCE (v2.6 — NEW) ===
    var wd = wal_disk_mod.WalDisk.initWithConfig(allocator, .{
        .max_records_per_segment = 100,
        .fsync_per_write = false,
        .fsync_on_batch = true,
        .batch_size = 8,
    });
    defer wd.deinit();
    try wd.open(5000);

    const cid = makeNodeId(0);

    // Log 15 saga lifecycles to disk WAL (10 succeed + 5 compensated)
    for (0..15) |saga_i| {
        const saga_id: u64 = @intCast(saga_i + 1);
        const ts: i64 = 5100 + @as(i64, @intCast(saga_i)) * 200;

        _ = try wd.logSagaCreated(saga_id, cid, ts);
        _ = try wd.logSagaStepAdded(saga_id, 0, 0x01, ts + 10);
        _ = try wd.logSagaStepAdded(saga_id, 1, 0x01, ts + 20);
        _ = try wd.logSagaStepAdded(saga_id, 2, 0x01, ts + 30);
        _ = try wd.logSagaExecuteStart(saga_id, ts + 40);

        if (saga_i < 10) {
            _ = try wd.logSagaStepSucceeded(saga_id, 0, ts + 50);
            _ = try wd.logSagaStepSucceeded(saga_id, 1, ts + 60);
            _ = try wd.logSagaStepSucceeded(saga_id, 2, ts + 70);
            _ = try wd.logSagaCompleted(saga_id, ts + 80);
        } else {
            _ = try wd.logSagaStepSucceeded(saga_id, 0, ts + 50);
            _ = try wd.logSagaStepSucceeded(saga_id, 1, ts + 60);
            _ = try wd.logSagaStepFailed(saga_id, 2, 500, ts + 70);
            _ = try wd.logSagaCompensationSucceeded(saga_id, 0, ts + 80);
            _ = try wd.logSagaCompensationSucceeded(saga_id, 1, ts + 90);
            _ = try wd.logSagaCompensated(saga_id, ts + 100);
        }
    }

    _ = try wd.writeCheckpoint(8000);

    const wd_stats = wd.getDiskStats();
    try std.testing.expect(wd_stats.total_records_on_disk > 100);
    try std.testing.expect(wd_stats.total_segments_created >= 1);
    try std.testing.expect(wd_stats.total_fsyncs > 0);

    const compact_result = try wd.compact(8500);
    try std.testing.expect(compact_result.records_after < compact_result.records_before);
    try std.testing.expect(compact_result.completed_ops_purged > 0);

    // === PARALLEL SAGA (v2.5) ===
    var par_engine = parallel_saga_mod.ParallelSagaEngine.init(allocator);
    defer par_engine.deinit();

    for (0..15) |saga_i| {
        const par_saga_id = try par_engine.createSaga(cid, 5000 + @as(i64, @intCast(saga_i)) * 100);
        const shard = makeNodeId(saga_i + 10);
        const node = makeNodeId(saga_i + 50);

        const s0 = try par_engine.addStep(par_saga_id, .shard_write, shard, node);
        _ = try par_engine.addStepWithDeps(par_saga_id, .shard_write, shard, node, &[_]u32{s0});
        _ = try par_engine.addStepWithDeps(par_saga_id, .shard_write, shard, node, &[_]u32{s0});
        _ = try par_engine.addStepWithDeps(par_saga_id, .shard_write, shard, node, &[_]u32{s0});

        const started = try par_engine.execute(par_saga_id, 6000);
        try std.testing.expectEqual(@as(u32, 1), started);
        _ = try par_engine.stepSucceeded(par_saga_id, 0, 6100);
        _ = try par_engine.stepSucceeded(par_saga_id, 1, 6200);

        if (saga_i < 10) {
            _ = try par_engine.stepSucceeded(par_saga_id, 2, 6300);
            _ = try par_engine.stepSucceeded(par_saga_id, 3, 6400);
        } else {
            _ = try par_engine.stepFailed(par_saga_id, 2, 500, 6300);
            _ = try par_engine.compensationSucceeded(par_saga_id, 0, 6400);
            _ = try par_engine.compensationSucceeded(par_saga_id, 1, 6500);
        }
    }

    const par_stats = par_engine.getStats();

    // === IN-MEMORY WAL (v2.4) ===
    var mem_wal = transaction_wal_mod.TransactionWal.init(allocator);
    defer mem_wal.deinit();

    _ = try mem_wal.logSagaCreated(100, cid, 8000);
    _ = try mem_wal.logSagaStepAdded(100, 0, 0x01, 8100);
    _ = try mem_wal.logSagaExecuteStart(100, 8200);
    _ = try mem_wal.logSagaStepSucceeded(100, 0, 8300);
    _ = try mem_wal.logSagaCompleted(100, 8400);
    _ = try mem_wal.writeCheckpoint(8500);
    const wal_stats = mem_wal.getStats();

    // === SEQUENTIAL SAGA (v2.3) ===
    var saga_coord = saga_coordinator_mod.SagaCoordinator.init(allocator);
    defer saga_coord.deinit();

    for (0..5) |i| {
        const sid = try saga_coord.createSaga(makeNodeId(i), @intCast(9000 + i * 100));
        _ = try saga_coord.addStep(sid, .shard_write, makeNodeId(i + 10), makeNodeId(i + 50));
        _ = try saga_coord.execute(sid, @intCast(9050 + i * 100));
        _ = try saga_coord.stepSucceeded(sid, 0, @intCast(9060 + i * 100));
    }

    // === CROSS-SHARD 2PC (v2.1) ===
    var tx_coord = cross_shard_tx_mod.CrossShardTxCoordinator.init(allocator);
    defer tx_coord.deinit();

    const tx_id = try tx_coord.beginTransaction(cid, 9000);
    var tx_hashes: [8][32]u8 = undefined;
    for (0..8) |p| {
        tx_hashes[p] = makeNodeId(p + 200);
        try tx_coord.addParticipant(tx_id, tx_hashes[p], makeNodeId(p + 100), 9050);
    }
    try tx_coord.prepare(tx_id);
    for (0..8) |p| {
        try tx_coord.recordVote(tx_id, tx_hashes[p], true);
    }
    const tx_result = try tx_coord.commit(tx_id, 9200);
    try std.testing.expect(tx_result.success);

    // === VSA LOCKS ===
    var locks = vsa_shard_locks_mod.VsaShardLocks.init(allocator);
    defer locks.deinit();
    var lock_hashes: [10][32]u8 = undefined;
    for (0..10) |s| lock_hashes[s] = makeNodeId(s + 500);
    const v26_lock_holder = makeNodeId(999);
    for (0..10) |s| {
        const lock_result = try locks.acquireLock(lock_hashes[s], v26_lock_holder, tx_id, 9300);
        try std.testing.expectEqual(vsa_shard_locks_mod.LockResult.acquired, lock_result);
    }
    const released = locks.releaseTransactionLocks(tx_id);
    try std.testing.expectEqual(@as(u32, 10), released);

    // === STAKING + ESCROW ===
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
    });
    defer staking.deinit();
    for (0..NODE_COUNT) |i| _ = staking.stake(makeNodeId(i), 10_000);

    var escrow = slashing_escrow_mod.SlashingEscrow.init(allocator);
    defer escrow.deinit();
    for (0..12) |i| {
        _ = staking.slashForPosFailure(makeNodeId(i + 740));
        _ = try escrow.createEscrow(makeNodeId(i + 740), 500, .pos_failure, 9400);
    }

    // === PROMETHEUS ===
    var v26_http = prometheus_http_mod.PrometheusHttpEndpoint.init(allocator);
    defer v26_http.deinit();
    const v26_metrics = try v26_http.handleRequest("/metrics", health_report, 9500);
    try std.testing.expectEqual(@as(u16, 200), v26_metrics.status_code);

    // === VERIFY ALL v2.6 SUBSYSTEMS ===
    try std.testing.expectEqual(@as(u64, 800), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);
    try std.testing.expectEqual(@as(u64, 10), par_stats.completed_sagas);
    try std.testing.expectEqual(@as(u64, 5), par_stats.compensated_sagas);
    try std.testing.expect(par_stats.max_parallelism_seen >= 2);
    try std.testing.expect(wal_stats.total_records_written > 0);
    try std.testing.expect(wd_stats.total_records_on_disk > 0);
    try std.testing.expect(wd_stats.total_fsyncs > 0);
    try std.testing.expect(compact_result.completed_ops_purged > 0);
    try std.testing.expectEqual(@as(u64, 5), saga_coord.getStats().completed_sagas);
    try std.testing.expectEqual(@as(u64, 1), tx_coord.getStats().committed_transactions);
    try std.testing.expectEqual(@as(u32, 800), staking.getStats().active_stakers);
    try std.testing.expectEqual(@as(u64, 12), escrow.getStats().total_escrows);
    try std.testing.expect(ec_rec.health_score >= 0.85);
}
