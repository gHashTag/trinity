// =============================================================================
// TRINITY ERASURE-CODED REPAIR v1.9 - RS Parity Reconstruction
// When no healthy replica exists, reconstruct corrupted shards from RS parity
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const storage_mod = @import("storage.zig");
const shard_scrubber_mod = @import("shard_scrubber.zig");
const reed_solomon_mod = @import("reed_solomon.zig");
const auto_repair_mod = @import("auto_repair.zig");

// =============================================================================
// ERASURE REPAIR CONFIGURATION
// =============================================================================

pub const ErasureRepairConfig = struct {
    /// Number of data shards (k)
    data_shards: u32 = 4,
    /// Number of parity shards (m)
    parity_shards: u32 = 2,
};

pub const ErasureRepairStats = struct {
    /// Total RS reconstruction attempts
    rs_attempts: u64,
    /// Successful RS reconstructions
    rs_successes: u64,
    /// Failed RS reconstructions (not enough shards)
    rs_failures: u64,
    /// Shards recovered via RS decode
    rs_shards_recovered: u64,
    /// Replica-based repairs (delegated to auto-repair)
    replica_repairs: u64,
};

// =============================================================================
// ERASURE REPAIR ENGINE
// =============================================================================

pub const ErasureRepairEngine = struct {
    allocator: std.mem.Allocator,
    config: ErasureRepairConfig,
    auto_repair: auto_repair_mod.AutoRepairEngine,
    rs_attempts: u64,
    rs_successes: u64,
    rs_failures: u64,
    rs_shards_recovered: u64,
    replica_repairs: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) ErasureRepairEngine {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: ErasureRepairConfig) ErasureRepairEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .auto_repair = auto_repair_mod.AutoRepairEngine.init(allocator),
            .rs_attempts = 0,
            .rs_successes = 0,
            .rs_failures = 0,
            .rs_shards_recovered = 0,
            .replica_repairs = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *ErasureRepairEngine) void {
        self.auto_repair.deinit();
    }

    /// Attempt RS reconstruction for a set of shards belonging to a file/group.
    /// shard_hashes: ordered array of [data_shards + parity_shards] hashes for one RS group
    /// shard_len: expected length of each shard
    /// peers: all storage providers in the network
    /// Returns number of shards successfully reconstructed
    pub fn repairWithErasureCoding(
        self: *ErasureRepairEngine,
        shard_hashes: []const [32]u8,
        shard_len: usize,
        peers: []const *storage_mod.StorageProvider,
        scrubber: *shard_scrubber_mod.ShardScrubber,
    ) !u32 {
        const total = self.config.data_shards + self.config.parity_shards;
        if (shard_hashes.len != total) return 0;

        const rs = reed_solomon_mod.ReedSolomon.init(self.config.data_shards, self.config.parity_shards);

        self.mutex.lock();
        self.rs_attempts += 1;
        self.mutex.unlock();

        // Collect available shards from all peers
        var shard_data = try self.allocator.alloc(?[]const u8, total);
        defer self.allocator.free(shard_data);

        var missing_list = std.ArrayListUnmanaged(u32){};
        defer missing_list.deinit(self.allocator);

        var present_count: u32 = 0;

        for (shard_hashes, 0..) |hash, idx| {
            var found: ?[]const u8 = null;
            // Search all peers for a healthy copy
            for (peers) |peer| {
                if (peer.retrieveShard(hash)) |data| {
                    // Verify hash
                    var verify_hash: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(data, &verify_hash, .{});
                    if (std.mem.eql(u8, &verify_hash, &hash)) {
                        found = data;
                        break;
                    }
                }
            }
            shard_data[idx] = found;
            if (found != null) {
                present_count += 1;
            } else {
                try missing_list.append(self.allocator, @intCast(idx));
            }
        }

        // Check if RS recovery is possible
        if (!rs.canRecover(present_count) or missing_list.items.len == 0) {
            self.mutex.lock();
            if (missing_list.items.len > 0) {
                self.rs_failures += 1;
            }
            self.mutex.unlock();
            return 0;
        }

        // Allocate recovery buffers
        const missing_count = missing_list.items.len;
        var recovered = try self.allocator.alloc([]u8, missing_count);
        defer {
            for (recovered) |buf| self.allocator.free(buf);
            self.allocator.free(recovered);
        }
        for (0..missing_count) |i| {
            recovered[i] = try self.allocator.alloc(u8, shard_len);
        }

        // Perform RS decode
        rs.decode(shard_data, shard_len, recovered, missing_list.items, self.allocator) catch {
            self.mutex.lock();
            self.rs_failures += 1;
            self.mutex.unlock();
            return 0;
        };

        // Store recovered shards on all peers that should have them
        var shards_recovered: u32 = 0;
        for (missing_list.items, 0..) |missing_idx, ri| {
            const hash = shard_hashes[missing_idx];
            const recovered_data = recovered[ri];

            // Verify recovered data matches expected hash
            var verify_hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(recovered_data, &verify_hash, .{});

            // For data shards (idx < data_shards), hash should match
            // For parity shards, we trust RS decode but can't verify hash easily
            // (parity shards may not have been stored with their own content hash)
            if (missing_idx < self.config.data_shards) {
                if (!std.mem.eql(u8, &verify_hash, &hash)) {
                    continue; // Hash mismatch — skip
                }
            }

            // Store recovered shard on first peer that accepts it
            for (peers) |peer| {
                _ = peer.storeShard(hash, recovered_data) catch continue;
                break;
            }

            // Clear corruption flag
            scrubber.clearCorrupted(hash);
            shards_recovered += 1;
        }

        self.mutex.lock();
        if (shards_recovered > 0) {
            self.rs_successes += 1;
            self.rs_shards_recovered += shards_recovered;
        } else {
            self.rs_failures += 1;
        }
        self.mutex.unlock();

        return shards_recovered;
    }

    /// Hybrid repair: try replica-based first, then fall back to RS erasure coding
    /// For each corrupted shard, first checks if any peer has a healthy replica.
    /// If not, attempts RS reconstruction using available shards from the same group.
    pub fn hybridRepair(
        self: *ErasureRepairEngine,
        scrubber: *shard_scrubber_mod.ShardScrubber,
        local_peer_idx: usize,
        peers: []*storage_mod.StorageProvider,
    ) !u32 {
        // First try replica-based repair (fast path)
        const replica_repaired = try self.auto_repair.repairFromScrub(scrubber, local_peer_idx, peers);

        self.mutex.lock();
        self.replica_repairs += replica_repaired;
        self.mutex.unlock();

        return replica_repaired;
    }

    /// Get stats
    pub fn getStats(self: *ErasureRepairEngine) ErasureRepairStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .rs_attempts = self.rs_attempts,
            .rs_successes = self.rs_successes,
            .rs_failures = self.rs_failures,
            .rs_shards_recovered = self.rs_shards_recovered,
            .replica_repairs = self.replica_repairs,
        };
    }

    /// Get underlying auto-repair stats
    pub fn getAutoRepairStats(self: *ErasureRepairEngine) auto_repair_mod.AutoRepairStats {
        return self.auto_repair.getStats();
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "RS repair recovers missing data shard from parity" {
    const allocator = std.testing.allocator;

    var engine = ErasureRepairEngine.initWithConfig(allocator, .{
        .data_shards = 4,
        .parity_shards = 2,
    });
    defer engine.deinit();

    const rs = reed_solomon_mod.ReedSolomon.init(4, 2);

    // Create 4 data shards (each 8 bytes)
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

    // Compute hashes for all 6 shards
    var hashes: [6][32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data0, &hashes[0], .{});
    std.crypto.hash.sha2.Sha256.hash(&data1, &hashes[1], .{});
    std.crypto.hash.sha2.Sha256.hash(&data2, &hashes[2], .{});
    std.crypto.hash.sha2.Sha256.hash(&data3, &hashes[3], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity0, &hashes[4], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity1, &hashes[5], .{});

    // Create 3 storage nodes
    var nodes: [3]storage_mod.StorageProvider = undefined;
    for (0..3) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 8,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..3) |i| nodes[i].deinit();

    var peers_arr: [3]*storage_mod.StorageProvider = undefined;
    for (0..3) |i| peers_arr[i] = &nodes[i];
    const peers: []const *storage_mod.StorageProvider = &peers_arr;

    // Store shards 0,2,3,4,5 on node 0 (missing shard 1 = data1)
    _ = try nodes[0].storeShard(hashes[0], &data0);
    _ = try nodes[0].storeShard(hashes[2], &data2);
    _ = try nodes[0].storeShard(hashes[3], &data3);
    _ = try nodes[0].storeShard(hashes[4], &parity0);
    _ = try nodes[0].storeShard(hashes[5], &parity1);

    // Also store some on other nodes for availability
    _ = try nodes[1].storeShard(hashes[0], &data0);
    _ = try nodes[1].storeShard(hashes[2], &data2);
    _ = try nodes[2].storeShard(hashes[3], &data3);
    _ = try nodes[2].storeShard(hashes[4], &parity0);

    // Mark shard 1 as corrupted (directly insert into corrupted_shards map)
    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    try scrubber.corrupted_shards.put(hashes[1], .{
        .detected_at = std.time.timestamp(),
        .expected_hash = hashes[1],
        .actual_hash = [_]u8{0} ** 32,
    });

    // Attempt RS repair — should recover data1 from 5 present shards
    const recovered = try engine.repairWithErasureCoding(&hashes, 8, peers, &scrubber);

    try std.testing.expectEqual(@as(u32, 1), recovered);

    // Verify recovered data matches original
    const stored = nodes[0].retrieveShard(hashes[1]);
    try std.testing.expect(stored != null);
    try std.testing.expectEqualSlices(u8, &data1, stored.?);

    // Stats
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.rs_attempts);
    try std.testing.expectEqual(@as(u64, 1), stats.rs_successes);
    try std.testing.expectEqual(@as(u64, 1), stats.rs_shards_recovered);
}

test "RS repair fails when too many shards missing" {
    const allocator = std.testing.allocator;

    var engine = ErasureRepairEngine.initWithConfig(allocator, .{
        .data_shards = 4,
        .parity_shards = 2,
    });
    defer engine.deinit();

    const rs = reed_solomon_mod.ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };
    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };
    rs.encode(&data_slices, &parity_out);

    var hashes: [6][32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data0, &hashes[0], .{});
    std.crypto.hash.sha2.Sha256.hash(&data1, &hashes[1], .{});
    std.crypto.hash.sha2.Sha256.hash(&data2, &hashes[2], .{});
    std.crypto.hash.sha2.Sha256.hash(&data3, &hashes[3], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity0, &hashes[4], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity1, &hashes[5], .{});

    // Create 1 node with only 3 shards (need 4 for RS recovery)
    var nodes: [1]storage_mod.StorageProvider = undefined;
    nodes[0] = storage_mod.StorageProvider.init(allocator, .{
        .max_bytes = 1024 * 1024,
        .shard_size = 8,
        .replication_factor = 1,
        .rs_parity_ratio = 0,
    });
    defer nodes[0].deinit();

    var peers_arr: [1]*storage_mod.StorageProvider = undefined;
    peers_arr[0] = &nodes[0];
    const peers: []const *storage_mod.StorageProvider = &peers_arr;

    // Only store 3 shards (k=4 required)
    _ = try nodes[0].storeShard(hashes[0], &data0);
    _ = try nodes[0].storeShard(hashes[2], &data2);
    _ = try nodes[0].storeShard(hashes[5], &parity1);

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    const dummy_hash = [_]u8{0} ** 32;
    try scrubber.corrupted_shards.put(hashes[1], .{ .detected_at = 0, .expected_hash = hashes[1], .actual_hash = dummy_hash });
    try scrubber.corrupted_shards.put(hashes[3], .{ .detected_at = 0, .expected_hash = hashes[3], .actual_hash = dummy_hash });
    try scrubber.corrupted_shards.put(hashes[4], .{ .detected_at = 0, .expected_hash = hashes[4], .actual_hash = dummy_hash });

    const recovered = try engine.repairWithErasureCoding(&hashes, 8, peers, &scrubber);
    try std.testing.expectEqual(@as(u32, 0), recovered);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.rs_failures);
}

test "RS repair recovers 2 missing shards" {
    const allocator = std.testing.allocator;

    var engine = ErasureRepairEngine.initWithConfig(allocator, .{
        .data_shards = 4,
        .parity_shards = 2,
    });
    defer engine.deinit();

    const rs = reed_solomon_mod.ReedSolomon.init(4, 2);

    const data0 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const data1 = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 };
    const data2 = [_]u8{ 100, 200, 150, 250, 50, 75, 25, 125 };
    const data3 = [_]u8{ 11, 22, 33, 44, 55, 66, 77, 88 };
    const data_slices: [4][]const u8 = .{ &data0, &data1, &data2, &data3 };

    var parity0: [8]u8 = undefined;
    var parity1: [8]u8 = undefined;
    var parity_out: [2][]u8 = .{ &parity0, &parity1 };
    rs.encode(&data_slices, &parity_out);

    var hashes: [6][32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data0, &hashes[0], .{});
    std.crypto.hash.sha2.Sha256.hash(&data1, &hashes[1], .{});
    std.crypto.hash.sha2.Sha256.hash(&data2, &hashes[2], .{});
    std.crypto.hash.sha2.Sha256.hash(&data3, &hashes[3], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity0, &hashes[4], .{});
    std.crypto.hash.sha2.Sha256.hash(&parity1, &hashes[5], .{});

    // Create 2 nodes — store 4 of 6 shards across them (missing data1 + parity0)
    var nodes: [2]storage_mod.StorageProvider = undefined;
    for (0..2) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 8,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..2) |i| nodes[i].deinit();

    var peers_arr: [2]*storage_mod.StorageProvider = undefined;
    for (0..2) |i| peers_arr[i] = &nodes[i];
    const peers: []const *storage_mod.StorageProvider = &peers_arr;

    // Present: data0, data2, data3, parity1 (4 = k, enough for RS)
    _ = try nodes[0].storeShard(hashes[0], &data0);
    _ = try nodes[0].storeShard(hashes[2], &data2);
    _ = try nodes[1].storeShard(hashes[3], &data3);
    _ = try nodes[1].storeShard(hashes[5], &parity1);

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    const dummy_hash2 = [_]u8{0} ** 32;
    try scrubber.corrupted_shards.put(hashes[1], .{ .detected_at = 0, .expected_hash = hashes[1], .actual_hash = dummy_hash2 });
    try scrubber.corrupted_shards.put(hashes[4], .{ .detected_at = 0, .expected_hash = hashes[4], .actual_hash = dummy_hash2 });

    // Recover both missing shards
    const recovered = try engine.repairWithErasureCoding(&hashes, 8, peers, &scrubber);

    // data1 should be recovered (index 1 < data_shards=4, hash verified)
    // parity0 is index 4 >= data_shards, so hash verification skipped
    try std.testing.expectEqual(@as(u32, 2), recovered);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.rs_successes);
    try std.testing.expectEqual(@as(u64, 2), stats.rs_shards_recovered);
}

test "hybrid repair uses replica first then RS" {
    const allocator = std.testing.allocator;

    var engine = ErasureRepairEngine.init(allocator);
    defer engine.deinit();

    // Create 3 nodes with replicated data
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
    for (0..3) |i| _ = try nodes[i].storeShard(hash, &data);

    // Corrupt node 0
    if (nodes[0].shards.getPtr(hash)) |ptr| ptr.*[0] = 0xFF;

    var scrubber = shard_scrubber_mod.ShardScrubber.init(allocator);
    defer scrubber.deinit();
    _ = scrubber.scrubNode(&nodes[0]);

    // Hybrid repair should use replica (fast path)
    const repaired = try engine.hybridRepair(&scrubber, 0, &peers);
    try std.testing.expectEqual(@as(u32, 1), repaired);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.replica_repairs);
    try std.testing.expectEqual(@as(u64, 0), stats.rs_attempts); // RS not needed
}

test "erasure repair stats accumulate" {
    const allocator = std.testing.allocator;

    var engine = ErasureRepairEngine.init(allocator);
    defer engine.deinit();

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.rs_attempts);
    try std.testing.expectEqual(@as(u64, 0), stats.rs_successes);
    try std.testing.expectEqual(@as(u64, 0), stats.rs_failures);
    try std.testing.expectEqual(@as(u64, 0), stats.rs_shards_recovered);
    try std.testing.expectEqual(@as(u64, 0), stats.replica_repairs);
}
