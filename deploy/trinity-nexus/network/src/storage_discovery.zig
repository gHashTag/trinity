// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY STORAGE PEER DISCOVERY v1.2 - Track Peers with Storage Capacity
// Maintains registry of peers that provide storage, populated from StorageAnnounce
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("protocol.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Peers not seen within this many seconds are considered stale
pub const STALE_TIMEOUT_SECS: i64 = 60;

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE PEER INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const StoragePeerInfo = struct {
    node_id: [32]u8,
    available_bytes: u64,
    total_bytes: u64,
    shard_count: u32,
    last_seen: i64,
    address: ?std.net.Address,
    reliable: bool = true, // v1.5: false if proof-of-storage challenges failed
    reputation_score: f64 = 0.0, // v1.6: composite reputation score

    /// Check if this peer has been seen recently
    pub fn isAlive(self: *const StoragePeerInfo, now: i64) bool {
        return (now - self.last_seen) < STALE_TIMEOUT_SECS;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STORAGE PEER REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const StoragePeerRegistry = struct {
    allocator: std.mem.Allocator,
    peers: std.AutoHashMap([32]u8, StoragePeerInfo),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) StoragePeerRegistry {
        return .{
            .allocator = allocator,
            .peers = std.AutoHashMap([32]u8, StoragePeerInfo).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *StoragePeerRegistry) void {
        self.peers.deinit();
    }

    /// Update or insert a peer from a StorageAnnounce message
    pub fn updateFromAnnounce(self: *StoragePeerRegistry, announce: protocol.StorageAnnounce, addr: ?std.net.Address) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Preserve reliability flag if peer already known
        const existing_reliable = if (self.peers.get(announce.node_id)) |existing| existing.reliable else true;
        self.peers.put(announce.node_id, .{
            .node_id = announce.node_id,
            .available_bytes = announce.available_bytes,
            .total_bytes = announce.total_bytes,
            .shard_count = announce.shard_count,
            .last_seen = announce.timestamp,
            .address = addr,
            .reliable = existing_reliable,
        }) catch {};
    }

    /// Find peers with at least min_bytes available
    pub fn findPeersWithCapacity(self: *StoragePeerRegistry, min_bytes: u64, allocator: std.mem.Allocator) ![]StoragePeerInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var result = std.ArrayListUnmanaged(StoragePeerInfo){};
        errdefer result.deinit(allocator);

        var iter = self.peers.valueIterator();
        while (iter.next()) |info| {
            if (info.isAlive(now) and info.available_bytes >= min_bytes) {
                try result.append(allocator, info.*);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// Remove peers not seen within STALE_TIMEOUT_SECS
    pub fn pruneStale(self: *StoragePeerRegistry) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var count: u32 = 0;
        var to_remove = std.ArrayListUnmanaged([32]u8){};
        defer to_remove.deinit(self.allocator);

        var iter = self.peers.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.isAlive(now)) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            _ = self.peers.remove(key);
            count += 1;
        }

        return count;
    }

    /// Get total number of tracked peers
    pub fn getPeerCount(self: *StoragePeerRegistry) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.peers.count();
    }

    /// v1.5: Mark a peer as unreliable (failed proof-of-storage)
    pub fn markUnreliable(self: *StoragePeerRegistry, node_id: [32]u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.peers.getPtr(node_id)) |info| {
            info.reliable = false;
        }
    }

    /// v1.5: Check if a peer is reliable
    pub fn isReliable(self: *StoragePeerRegistry, node_id: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.peers.get(node_id)) |info| {
            return info.reliable;
        }
        return false; // Unknown peer is not reliable
    }

    /// v1.5: Find peers with capacity, excluding unreliable ones
    pub fn findReliablePeersWithCapacity(self: *StoragePeerRegistry, min_bytes: u64, allocator: std.mem.Allocator) ![]StoragePeerInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var result = std.ArrayListUnmanaged(StoragePeerInfo){};
        errdefer result.deinit(allocator);

        var iter = self.peers.valueIterator();
        while (iter.next()) |info| {
            if (info.isAlive(now) and info.available_bytes >= min_bytes and info.reliable) {
                try result.append(allocator, info.*);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    /// v1.6: Update the reputation score for a peer
    pub fn updateReputation(self: *StoragePeerRegistry, node_id: [32]u8, score: f64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.peers.getPtr(node_id)) |info| {
            info.reputation_score = score;
        }
    }

    /// v1.6: Get the reputation score for a peer
    pub fn getReputation(self: *StoragePeerRegistry, node_id: [32]u8) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.peers.get(node_id)) |info| {
            return info.reputation_score;
        }
        return 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "registry add and find peers" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    // Add 3 peers with different capacities
    var id1: [32]u8 = undefined;
    @memset(&id1, 0x11);
    registry.updateFromAnnounce(.{
        .node_id = id1,
        .available_bytes = 1024 * 1024 * 1024, // 1 GB
        .total_bytes = 10 * 1024 * 1024 * 1024,
        .shard_count = 10,
        .timestamp = now,
    }, null);

    var id2: [32]u8 = undefined;
    @memset(&id2, 0x22);
    registry.updateFromAnnounce(.{
        .node_id = id2,
        .available_bytes = 500 * 1024 * 1024, // 500 MB
        .total_bytes = 5 * 1024 * 1024 * 1024,
        .shard_count = 5,
        .timestamp = now,
    }, null);

    var id3: [32]u8 = undefined;
    @memset(&id3, 0x33);
    registry.updateFromAnnounce(.{
        .node_id = id3,
        .available_bytes = 100 * 1024 * 1024, // 100 MB
        .total_bytes = 1024 * 1024 * 1024,
        .shard_count = 50,
        .timestamp = now,
    }, null);

    try std.testing.expectEqual(@as(usize, 3), registry.getPeerCount());

    // Find peers with >= 500 MB
    const big_peers = try registry.findPeersWithCapacity(500 * 1024 * 1024, allocator);
    defer allocator.free(big_peers);
    try std.testing.expectEqual(@as(usize, 2), big_peers.len); // id1 (1GB) and id2 (500MB)

    // Find peers with >= 2 GB — none qualify
    const huge_peers = try registry.findPeersWithCapacity(2 * 1024 * 1024 * 1024, allocator);
    defer allocator.free(huge_peers);
    try std.testing.expectEqual(@as(usize, 0), huge_peers.len);
}

test "registry prune stale peers" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    // Add a fresh peer
    var id_fresh: [32]u8 = undefined;
    @memset(&id_fresh, 0xAA);
    registry.updateFromAnnounce(.{
        .node_id = id_fresh,
        .available_bytes = 1024,
        .total_bytes = 2048,
        .shard_count = 1,
        .timestamp = now,
    }, null);

    // Add a stale peer (last seen 120 seconds ago)
    var id_stale: [32]u8 = undefined;
    @memset(&id_stale, 0xBB);
    registry.updateFromAnnounce(.{
        .node_id = id_stale,
        .available_bytes = 1024,
        .total_bytes = 2048,
        .shard_count = 1,
        .timestamp = now - 120, // 2 minutes ago = stale
    }, null);

    try std.testing.expectEqual(@as(usize, 2), registry.getPeerCount());

    // Prune stale peers
    const pruned = registry.pruneStale();
    try std.testing.expectEqual(@as(u32, 1), pruned);
    try std.testing.expectEqual(@as(usize, 1), registry.getPeerCount());

    // Only fresh peer should remain
    const remaining = try registry.findPeersWithCapacity(0, allocator);
    defer allocator.free(remaining);
    try std.testing.expectEqual(@as(usize, 1), remaining.len);
    try std.testing.expectEqualSlices(u8, &id_fresh, &remaining[0].node_id);
}

test "registry update from announce" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    var id: [32]u8 = undefined;
    @memset(&id, 0xCC);

    // First announce
    registry.updateFromAnnounce(.{
        .node_id = id,
        .available_bytes = 1000,
        .total_bytes = 2000,
        .shard_count = 5,
        .timestamp = now - 30,
    }, null);

    // Second announce with updated values
    registry.updateFromAnnounce(.{
        .node_id = id,
        .available_bytes = 500,
        .total_bytes = 2000,
        .shard_count = 10,
        .timestamp = now,
    }, null);

    // Should still be 1 peer (updated, not duplicated)
    try std.testing.expectEqual(@as(usize, 1), registry.getPeerCount());

    // Should have updated values
    const peers = try registry.findPeersWithCapacity(0, allocator);
    defer allocator.free(peers);
    try std.testing.expectEqual(@as(u64, 500), peers[0].available_bytes);
    try std.testing.expectEqual(@as(u32, 10), peers[0].shard_count);
}

test "registry mark unreliable and check reliability" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    var id: [32]u8 = undefined;
    @memset(&id, 0xDD);
    registry.updateFromAnnounce(.{
        .node_id = id,
        .available_bytes = 1024,
        .total_bytes = 2048,
        .shard_count = 5,
        .timestamp = now,
    }, null);

    // Initially reliable
    try std.testing.expect(registry.isReliable(id));

    // Mark unreliable
    registry.markUnreliable(id);
    try std.testing.expect(!registry.isReliable(id));

    // Unknown peer is not reliable
    var unknown: [32]u8 = undefined;
    @memset(&unknown, 0xEE);
    try std.testing.expect(!registry.isReliable(unknown));

    // Re-announce should preserve unreliable flag
    registry.updateFromAnnounce(.{
        .node_id = id,
        .available_bytes = 2048,
        .total_bytes = 4096,
        .shard_count = 10,
        .timestamp = now + 10,
    }, null);
    try std.testing.expect(!registry.isReliable(id));
}

test "registry findReliablePeersWithCapacity skips unreliable" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    // Add 3 peers
    for (0..3) |i| {
        var id: [32]u8 = undefined;
        @memset(&id, @intCast(i + 1));
        registry.updateFromAnnounce(.{
            .node_id = id,
            .available_bytes = 1024 * 1024,
            .total_bytes = 10 * 1024 * 1024,
            .shard_count = 0,
            .timestamp = now,
        }, null);
    }

    // All 3 reliable initially
    const all = try registry.findReliablePeersWithCapacity(0, allocator);
    defer allocator.free(all);
    try std.testing.expectEqual(@as(usize, 3), all.len);

    // Mark peer 2 unreliable
    var id2: [32]u8 = undefined;
    @memset(&id2, 0x02);
    registry.markUnreliable(id2);

    // Only 2 reliable now
    const reliable = try registry.findReliablePeersWithCapacity(0, allocator);
    defer allocator.free(reliable);
    try std.testing.expectEqual(@as(usize, 2), reliable.len);

    // findPeersWithCapacity still returns all 3 (backward compat)
    const all_peers = try registry.findPeersWithCapacity(0, allocator);
    defer allocator.free(all_peers);
    try std.testing.expectEqual(@as(usize, 3), all_peers.len);
}

test "v1.6: updateReputation and getReputation" {
    const allocator = std.testing.allocator;

    var registry = StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const now = std.time.timestamp();

    var id: [32]u8 = undefined;
    @memset(&id, 0xAA);
    registry.updateFromAnnounce(.{
        .node_id = id,
        .available_bytes = 1024,
        .total_bytes = 2048,
        .shard_count = 5,
        .timestamp = now,
    }, null);

    // Initially 0.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), registry.getReputation(id), 0.001);

    // Update to 0.85
    registry.updateReputation(id, 0.85);
    try std.testing.expectApproxEqAbs(@as(f64, 0.85), registry.getReputation(id), 0.001);

    // Unknown peer returns 0.0
    var unknown: [32]u8 = undefined;
    @memset(&unknown, 0xFF);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), registry.getReputation(unknown), 0.001);
}
