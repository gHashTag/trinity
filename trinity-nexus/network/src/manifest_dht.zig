// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MANIFEST DHT v1.4 - Distributed Manifest Storage
// XOR-distance routing for FileManifest distribution across peers
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_discovery = @import("storage_discovery.zig");
const protocol = @import("protocol.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// XOR DISTANCE - Kademlia-style distance metric
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute byte-wise XOR distance between two 32-byte IDs
pub fn xorDistance(a: [32]u8, b: [32]u8) [32]u8 {
    var result: [32]u8 = undefined;
    for (0..32) |i| {
        result[i] = a[i] ^ b[i];
    }
    return result;
}

/// Compare two XOR distances (for sorting: returns true if a < b)
fn distanceLessThan(a: [32]u8, b: [32]u8) bool {
    for (0..32) |i| {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }
    return false; // equal
}

// ═══════════════════════════════════════════════════════════════════════════════
// MANIFEST DHT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ManifestDHT = struct {
    local_manifests: std.AutoHashMap([32]u8, []u8), // file_id -> serialized manifest
    allocator: std.mem.Allocator,
    replication_factor: u32,
    peer_registry: *storage_discovery.StoragePeerRegistry,
    local_node_id: [32]u8,

    // Stats
    manifests_stored: u64,
    manifests_retrieved: u64,
    manifests_distributed: u64,

    pub fn init(
        allocator: std.mem.Allocator,
        peer_registry: *storage_discovery.StoragePeerRegistry,
        local_node_id: [32]u8,
    ) ManifestDHT {
        return ManifestDHT{
            .local_manifests = std.AutoHashMap([32]u8, []u8).init(allocator),
            .allocator = allocator,
            .replication_factor = 3,
            .peer_registry = peer_registry,
            .local_node_id = local_node_id,
            .manifests_stored = 0,
            .manifests_retrieved = 0,
            .manifests_distributed = 0,
        };
    }

    pub fn deinit(self: *ManifestDHT) void {
        var it = self.local_manifests.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.local_manifests.deinit();
    }

    /// Store a manifest locally and distribute to k closest peers
    pub fn storeManifest(self: *ManifestDHT, file_id: [32]u8, data: []const u8) !void {
        // Store locally
        const local_copy = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(local_copy);

        const result = try self.local_manifests.getOrPut(file_id);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*);
        }
        result.value_ptr.* = local_copy;
        self.manifests_stored += 1;

        // Find k closest peers and distribute (best-effort)
        const responsible = self.findResponsiblePeers(file_id) catch return;
        defer self.allocator.free(responsible);

        // Distribution would happen via TCP in production
        // For now, track the count
        self.manifests_distributed += @intCast(responsible.len);
    }

    /// Get a manifest: check local first, then would query DHT peers
    pub fn getManifest(self: *ManifestDHT, file_id: [32]u8) ?[]const u8 {
        if (self.local_manifests.get(file_id)) |data| {
            self.manifests_retrieved += 1;
            return data;
        }
        // In production: query peers by XOR distance until one responds
        return null;
    }

    /// Handle incoming manifest store from a remote peer
    pub fn handleManifestStore(self: *ManifestDHT, file_id: [32]u8, data: []const u8) !void {
        const copy = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(copy);

        const result = try self.local_manifests.getOrPut(file_id);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*);
        }
        result.value_ptr.* = copy;
        self.manifests_stored += 1;
    }

    /// Handle incoming manifest retrieve request
    pub fn handleManifestRetrieve(self: *ManifestDHT, file_id: [32]u8) ?[]const u8 {
        return self.local_manifests.get(file_id);
    }

    /// Find the k closest peers to file_id by XOR distance
    pub fn findResponsiblePeers(self: *ManifestDHT, file_id: [32]u8) ![][32]u8 {
        // Get all peers
        const peers = try self.peer_registry.findPeersWithCapacity(0, self.allocator);
        defer self.allocator.free(peers);

        if (peers.len == 0) return self.allocator.alloc([32]u8, 0);

        // Compute distances and sort
        const PeerDist = struct {
            node_id: [32]u8,
            distance: [32]u8,
        };

        var peer_dists = try self.allocator.alloc(PeerDist, peers.len);
        defer self.allocator.free(peer_dists);

        var valid_count: usize = 0;
        for (peers) |peer| {
            // Skip self
            if (std.mem.eql(u8, &peer.node_id, &self.local_node_id)) continue;
            peer_dists[valid_count] = PeerDist{
                .node_id = peer.node_id,
                .distance = xorDistance(file_id, peer.node_id),
            };
            valid_count += 1;
        }

        // Sort by distance (ascending)
        const valid = peer_dists[0..valid_count];
        std.mem.sort(PeerDist, valid, {}, struct {
            fn lessThan(_: void, a: PeerDist, b_val: PeerDist) bool {
                return distanceLessThan(a.distance, b_val.distance);
            }
        }.lessThan);

        // Take top k
        const k = @min(self.replication_factor, @as(u32, @intCast(valid_count)));
        const result = try self.allocator.alloc([32]u8, k);
        for (0..k) |i| {
            result[i] = valid[i].node_id;
        }

        return result;
    }

    /// Get stored manifest count
    pub fn getManifestCount(self: *ManifestDHT) u32 {
        return @intCast(self.local_manifests.count());
    }

    /// Get DHT stats
    pub fn getStats(self: *ManifestDHT) DHTStats {
        return DHTStats{
            .local_manifests = self.getManifestCount(),
            .manifests_stored = self.manifests_stored,
            .manifests_retrieved = self.manifests_retrieved,
            .manifests_distributed = self.manifests_distributed,
        };
    }
};

pub const DHTStats = struct {
    local_manifests: u32,
    manifests_stored: u64,
    manifests_retrieved: u64,
    manifests_distributed: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ManifestDHT local store and retrieve" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    const node_id = [_]u8{0x42} ** 32;
    var dht = ManifestDHT.init(allocator, &registry, node_id);
    defer dht.deinit();

    // Store a manifest
    const file_id = [_]u8{0xAA} ** 32;
    const manifest_data = "test_manifest_data_v1.4";
    try dht.storeManifest(file_id, manifest_data);

    // Retrieve it
    const retrieved = dht.getManifest(file_id);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, manifest_data, retrieved.?);

    // Non-existent file_id
    const missing = [_]u8{0xBB} ** 32;
    try std.testing.expect(dht.getManifest(missing) == null);

    // Stats
    try std.testing.expectEqual(@as(u32, 1), dht.getManifestCount());
    try std.testing.expectEqual(@as(u64, 1), dht.manifests_stored);
    try std.testing.expectEqual(@as(u64, 1), dht.manifests_retrieved);
}

test "ManifestDHT xorDistance properties" {
    // d(a, a) = 0
    const a = [_]u8{0x42} ** 32;
    const d_aa = xorDistance(a, a);
    try std.testing.expectEqual([_]u8{0} ** 32, d_aa);

    // Symmetry: d(a, b) = d(b, a)
    const b = [_]u8{0xFF} ** 32;
    const d_ab = xorDistance(a, b);
    const d_ba = xorDistance(b, a);
    try std.testing.expectEqualSlices(u8, &d_ab, &d_ba);

    // d(a, b) != 0 when a != b
    const zero = [_]u8{0} ** 32;
    try std.testing.expect(!std.mem.eql(u8, &d_ab, &zero));
}

test "ManifestDHT findResponsiblePeers ordering" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    // Add 5 peers with different node_ids via StorageAnnounce
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9333);
    for (0..5) |i| {
        var peer_id: [32]u8 = undefined;
        @memset(&peer_id, @intCast(i + 1)); // 0x01..01, 0x02..02, etc.
        const announce = protocol.StorageAnnounce{
            .node_id = peer_id,
            .available_bytes = 1024 * 1024,
            .total_bytes = 10 * 1024 * 1024,
            .shard_count = 0,
            .timestamp = std.time.timestamp(),
        };
        registry.updateFromAnnounce(announce, addr);
    }

    const local_id = [_]u8{0xFF} ** 32;
    var dht = ManifestDHT.init(allocator, &registry, local_id);
    defer dht.deinit();
    dht.replication_factor = 3;

    // Find responsible peers for a file
    const file_id = [_]u8{0x03} ** 32; // Close to peer 0x03..03
    const responsible = try dht.findResponsiblePeers(file_id);
    defer allocator.free(responsible);

    // Should return up to k=3 peers
    try std.testing.expectEqual(@as(usize, 3), responsible.len);

    // The closest peer should be 0x03..03 (XOR distance = 0)
    try std.testing.expectEqual([_]u8{0x03} ** 32, responsible[0]);

    // Verify ordering: each peer should be closer or equal to next
    for (0..responsible.len - 1) |i| {
        const d_i = xorDistance(file_id, responsible[i]);
        const d_next = xorDistance(file_id, responsible[i + 1]);
        // d_i <= d_next (not strictly less due to possible ties)
        try std.testing.expect(!distanceLessThan(d_next, d_i));
    }
}

test "ManifestDHT handleManifestStore from remote" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    var dht = ManifestDHT.init(allocator, &registry, [_]u8{0x42} ** 32);
    defer dht.deinit();

    // Simulate receiving a manifest from a remote peer
    const file_id = [_]u8{0xCC} ** 32;
    const data = "remote_manifest_data";
    try dht.handleManifestStore(file_id, data);

    // Should be retrievable
    const retrieved = dht.handleManifestRetrieve(file_id);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualSlices(u8, data, retrieved.?);
}
