// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY REMOTE STORAGE v1.3 - Network Shard Distribution & Retrieval
// TCP client for storing/retrieving shards on remote peers
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const protocol = @import("protocol.zig");
const storage_mod = @import("storage.zig");
const storage_discovery = @import("storage_discovery.zig");
const connection_pool = @import("connection_pool.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// REMOTE PEER CLIENT - TCP client for shard operations
// ═══════════════════════════════════════════════════════════════════════════════

pub const RemotePeerClient = struct {
    allocator: std.mem.Allocator,
    address: std.net.Address,
    timeout_ns: u64 = 5_000_000_000, // 5 seconds
    // v1.4: Optional connection pool
    pool: ?*connection_pool.ConnectionPool = null,
    node_id: [32]u8 = [_]u8{0} ** 32, // Peer node_id for pool lookup

    /// Send a shard to a remote peer via TCP
    pub fn storeShard(self: *RemotePeerClient, shard_hash: [32]u8, data: []const u8, local_node_id: [32]u8) !void {
        // Build StoreRequest
        const req = protocol.StoreRequest{
            .shard_hash = shard_hash,
            .file_id = [_]u8{0} ** 32, // Not used for remote shard store
            .shard_index = 0,
            .total_shards = 0,
            .data = data,
        };

        const payload = try req.serialize(self.allocator);
        defer self.allocator.free(payload);

        // Build message header
        const header = protocol.MessageHeader{
            .msg_type = .store_request,
            .length = @intCast(payload.len),
        };

        // Connect and send (use pool if available)
        const use_pool = self.pool != null;
        const stream = if (self.pool) |p|
            p.acquire(self.node_id, self.address) catch try std.net.tcpConnectToAddress(self.address)
        else
            try std.net.tcpConnectToAddress(self.address);
        errdefer {
            if (use_pool) {
                if (self.pool) |p| p.discard(self.node_id, stream);
            } else {
                stream.close();
            }
        }

        const header_bytes = header.serialize();
        _ = try stream.write(&header_bytes);
        _ = try stream.write(payload);

        // Read response header
        var resp_header_buf: [protocol.MessageHeader.SIZE]u8 = undefined;
        const resp_header_read = try stream.read(&resp_header_buf);
        if (resp_header_read < protocol.MessageHeader.SIZE) return error.IncompleteResponse;

        const resp_header = try protocol.MessageHeader.deserialize(&resp_header_buf);
        if (resp_header.msg_type != .store_response) return error.UnexpectedResponse;

        // Read response payload
        var resp_buf: [protocol.StoreResponse.SIZE]u8 = undefined;
        const resp_read = try stream.read(&resp_buf);
        if (resp_read < protocol.StoreResponse.SIZE) return error.IncompleteResponse;

        const resp = try protocol.StoreResponse.deserialize(&resp_buf);
        _ = local_node_id;
        if (!resp.success) return error.RemoteStoreRejected;

        // Release back to pool on success
        if (self.pool) |p| {
            p.release(self.node_id, stream);
        } else {
            stream.close();
        }
    }

    /// Retrieve a shard from a remote peer via TCP
    pub fn retrieveShard(self: *RemotePeerClient, shard_hash: [32]u8, local_node_id: [32]u8) ![]const u8 {
        // Build RetrieveRequest
        const req = protocol.RetrieveRequest{
            .shard_hash = shard_hash,
            .requester_id = local_node_id,
        };

        // Build message header
        const payload_bytes = req.serialize();
        const header = protocol.MessageHeader{
            .msg_type = .retrieve_request,
            .length = protocol.RetrieveRequest.SIZE,
        };

        // Connect and send (use pool if available)
        const use_pool = self.pool != null;
        const stream = if (self.pool) |p|
            p.acquire(self.node_id, self.address) catch try std.net.tcpConnectToAddress(self.address)
        else
            try std.net.tcpConnectToAddress(self.address);
        errdefer {
            if (use_pool) {
                if (self.pool) |p| p.discard(self.node_id, stream);
            } else {
                stream.close();
            }
        }

        const header_bytes = header.serialize();
        _ = try stream.write(&header_bytes);
        _ = try stream.write(&payload_bytes);

        // Read response header
        var resp_header_buf: [protocol.MessageHeader.SIZE]u8 = undefined;
        const resp_header_read = try stream.read(&resp_header_buf);
        if (resp_header_read < protocol.MessageHeader.SIZE) return error.IncompleteResponse;

        const resp_header = try protocol.MessageHeader.deserialize(&resp_header_buf);
        if (resp_header.msg_type != .retrieve_response) return error.UnexpectedResponse;

        // Read response payload
        if (resp_header.length < 37) return error.IncompleteResponse;
        const resp_buf = try self.allocator.alloc(u8, resp_header.length);
        defer self.allocator.free(resp_buf);

        var total_read: usize = 0;
        while (total_read < resp_header.length) {
            const n = try stream.read(resp_buf[total_read..]);
            if (n == 0) return error.ConnectionClosed;
            total_read += n;
        }

        const resp = try protocol.RetrieveResponse.deserialize(resp_buf, self.allocator);
        if (!resp.found) {
            self.allocator.free(resp.data);
            return error.ShardNotFound;
        }

        // Release back to pool on success
        if (self.pool) |p| {
            p.release(self.node_id, stream);
        } else {
            stream.close();
        }

        return resp.data; // Caller owns this allocation
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK SHARD DISTRIBUTOR - Distribute shards to remote peers
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkShardDistributor = struct {
    allocator: std.mem.Allocator,
    peer_registry: *storage_discovery.StoragePeerRegistry,
    local_storage: *storage_mod.StorageProvider,
    reward_tracker: ?*storage_mod.RewardTracker,
    local_node_id: [32]u8,
    replication_factor: u32 = 2,
    // v1.4: Connection pool
    connection_pool: ?*connection_pool.ConnectionPool = null,

    /// Distribute a shard to remote peers (round-robin with replication)
    /// Returns the number of successful remote copies made
    pub fn distributeToRemotePeers(
        self: *NetworkShardDistributor,
        shard_hash: [32]u8,
        data: []const u8,
    ) !u32 {
        // Find peers with enough capacity
        const peers = self.peer_registry.findPeersWithCapacity(data.len, self.allocator) catch return 0;
        defer self.allocator.free(peers);

        if (peers.len == 0) return 0;

        var success_count: u32 = 0;
        for (peers) |peer| {
            if (success_count >= self.replication_factor) break;

            // Skip self
            if (std.mem.eql(u8, &peer.node_id, &self.local_node_id)) continue;

            // Get peer address
            const addr = peer.address orelse continue;

            var client = RemotePeerClient{
                .allocator = self.allocator,
                .address = addr,
                .pool = self.connection_pool,
                .node_id = peer.node_id,
            };

            client.storeShard(shard_hash, data, self.local_node_id) catch continue;

            success_count += 1;

            // Record bandwidth
            if (self.reward_tracker) |tracker| {
                tracker.recordUpload(data.len);
            }
        }

        return success_count;
    }

    /// Try to retrieve a shard from remote peers
    /// Returns shard data (caller owns) or error
    pub fn retrieveFromRemotePeers(
        self: *NetworkShardDistributor,
        shard_hash: [32]u8,
    ) ![]const u8 {
        // Get all known peers
        const peers = self.peer_registry.findPeersWithCapacity(0, self.allocator) catch return error.NoPeersAvailable;
        defer self.allocator.free(peers);

        if (peers.len == 0) return error.NoPeersAvailable;

        for (peers) |peer| {
            // Skip self
            if (std.mem.eql(u8, &peer.node_id, &self.local_node_id)) continue;

            const addr = peer.address orelse continue;

            var client = RemotePeerClient{
                .allocator = self.allocator,
                .address = addr,
                .pool = self.connection_pool,
                .node_id = peer.node_id,
            };

            const data = client.retrieveShard(shard_hash, self.local_node_id) catch continue;

            // Record bandwidth
            if (self.reward_tracker) |tracker| {
                tracker.recordDownload(data.len);
            }

            // Cache locally for future access
            _ = self.local_storage.storeShard(shard_hash, data) catch |err| {
                std.log.debug("remote_storage: cache shard locally failed: {}", .{err});
            };

            return data;
        }

        return error.ShardNotFound;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RemotePeerClient struct creation" {
    // Test that RemotePeerClient can be created with expected defaults
    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9333);
    const client = RemotePeerClient{
        .allocator = std.testing.allocator,
        .address = addr,
    };
    try std.testing.expectEqual(@as(u64, 5_000_000_000), client.timeout_ns);
}

test "NetworkShardDistributor with empty registry returns 0" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    var local = storage_mod.StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer local.deinit();

    var distributor = NetworkShardDistributor{
        .allocator = allocator,
        .peer_registry = &registry,
        .local_storage = &local,
        .reward_tracker = null,
        .local_node_id = [_]u8{0x42} ** 32,
    };

    // With no peers, distribution should return 0 (best-effort)
    const shard_hash = [_]u8{0xAA} ** 32;
    const result = try distributor.distributeToRemotePeers(shard_hash, "test data");
    try std.testing.expectEqual(@as(u32, 0), result);
}

test "NetworkShardDistributor records bandwidth on tracker" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    var local = storage_mod.StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer local.deinit();

    var tracker = storage_mod.RewardTracker.init();

    var distributor = NetworkShardDistributor{
        .allocator = allocator,
        .peer_registry = &registry,
        .local_storage = &local,
        .reward_tracker = &tracker,
        .local_node_id = [_]u8{0x42} ** 32,
    };

    // No peers = no distribution, but tracker should still be attached
    const shard_hash = [_]u8{0xBB} ** 32;
    const result = try distributor.distributeToRemotePeers(shard_hash, "test data");
    try std.testing.expectEqual(@as(u32, 0), result);

    // Bandwidth should be 0 since no peers were reached
    try std.testing.expectEqual(@as(u64, 0), tracker.bytes_uploaded);
}

test "NetworkShardDistributor retrieve from empty registry fails" {
    const allocator = std.testing.allocator;

    var registry = storage_discovery.StoragePeerRegistry.init(allocator);
    defer registry.deinit();

    var local = storage_mod.StorageProvider.init(allocator, .{ .max_bytes = 1024 * 1024 });
    defer local.deinit();

    var distributor = NetworkShardDistributor{
        .allocator = allocator,
        .peer_registry = &registry,
        .local_storage = &local,
        .reward_tracker = null,
        .local_node_id = [_]u8{0x42} ** 32,
    };

    const shard_hash = [_]u8{0xCC} ** 32;
    const result = distributor.retrieveFromRemotePeers(shard_hash);
    try std.testing.expectError(error.NoPeersAvailable, result);
}
