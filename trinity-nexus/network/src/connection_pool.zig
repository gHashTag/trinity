// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CONNECTION POOL v1.4 - TCP Connection Pool with TTL
// Reuse connections to remote peers instead of 1-per-operation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// POOLED CONNECTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const PooledConnection = struct {
    stream: std.net.Stream,
    last_used: i128, // nanoTimestamp
    in_use: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PEER POOL - connections to a single peer
// ═══════════════════════════════════════════════════════════════════════════════

pub const PeerPool = struct {
    connections: std.ArrayListUnmanaged(PooledConnection),
    address: std.net.Address,

    pub fn init(address: std.net.Address) PeerPool {
        return PeerPool{
            .connections = .{},
            .address = address,
        };
    }

    pub fn deinit(self: *PeerPool, allocator: std.mem.Allocator) void {
        // Close all connections
        for (self.connections.items) |conn| {
            conn.stream.close();
        }
        self.connections.deinit(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONNECTION POOL - manages per-peer connection pools
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConnectionPool = struct {
    pools: std.AutoHashMap([32]u8, PeerPool),
    allocator: std.mem.Allocator,
    max_per_peer: u32,
    idle_timeout_ns: i128,
    mutex: std.Thread.Mutex,

    // Stats
    total_acquired: u64,
    total_released: u64,
    total_discarded: u64,
    total_pruned: u64,

    pub fn init(allocator: std.mem.Allocator) ConnectionPool {
        return ConnectionPool{
            .pools = std.AutoHashMap([32]u8, PeerPool).init(allocator),
            .allocator = allocator,
            .max_per_peer = 4,
            .idle_timeout_ns = 30_000_000_000, // 30 seconds
            .mutex = .{},
            .total_acquired = 0,
            .total_released = 0,
            .total_discarded = 0,
            .total_pruned = 0,
        };
    }

    pub fn deinit(self: *ConnectionPool) void {
        var it = self.pools.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.pools.deinit();
    }

    /// Acquire a connection to a peer. Returns existing idle connection or opens new one.
    pub fn acquire(self: *ConnectionPool, node_id: [32]u8, address: std.net.Address) !std.net.Stream {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Look for existing idle connection
        if (self.pools.getPtr(node_id)) |pool| {
            for (pool.connections.items) |*conn| {
                if (!conn.in_use) {
                    conn.in_use = true;
                    conn.last_used = std.time.nanoTimestamp();
                    self.total_acquired += 1;
                    return conn.stream;
                }
            }

            // Check if we can add more connections to this peer
            if (pool.connections.items.len >= self.max_per_peer) {
                return error.PoolExhausted;
            }
        }

        // Open new connection
        const stream = try std.net.tcpConnectToAddress(address);

        const pooled = PooledConnection{
            .stream = stream,
            .last_used = std.time.nanoTimestamp(),
            .in_use = true,
        };

        // Ensure pool entry exists
        const result = try self.pools.getOrPut(node_id);
        if (!result.found_existing) {
            result.value_ptr.* = PeerPool.init(address);
        }

        try result.value_ptr.connections.append(self.allocator, pooled);
        self.total_acquired += 1;

        return stream;
    }

    /// Release a connection back to the pool (mark as idle)
    pub fn release(self: *ConnectionPool, node_id: [32]u8, stream: std.net.Stream) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pools.getPtr(node_id)) |pool| {
            for (pool.connections.items) |*conn| {
                if (conn.stream.handle == stream.handle and conn.in_use) {
                    conn.in_use = false;
                    conn.last_used = std.time.nanoTimestamp();
                    self.total_released += 1;
                    return;
                }
            }
        }
    }

    /// Discard a connection (close and remove from pool, e.g. after error)
    pub fn discard(self: *ConnectionPool, node_id: [32]u8, stream: std.net.Stream) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pools.getPtr(node_id)) |pool| {
            var i: usize = 0;
            while (i < pool.connections.items.len) {
                if (pool.connections.items[i].stream.handle == stream.handle) {
                    pool.connections.items[i].stream.close();
                    _ = pool.connections.swapRemove(i);
                    self.total_discarded += 1;
                    return;
                }
                i += 1;
            }
        }
    }

    /// Prune idle connections that have exceeded the timeout
    pub fn pruneIdle(self: *ConnectionPool) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.nanoTimestamp();
        var pruned: u32 = 0;

        var it = self.pools.iterator();
        while (it.next()) |entry| {
            var pool = entry.value_ptr;
            var i: usize = 0;
            while (i < pool.connections.items.len) {
                const conn = &pool.connections.items[i];
                if (!conn.in_use and (now - conn.last_used) > self.idle_timeout_ns) {
                    conn.stream.close();
                    _ = pool.connections.swapRemove(i);
                    pruned += 1;
                } else {
                    i += 1;
                }
            }
        }

        self.total_pruned += pruned;
        return pruned;
    }

    /// Get total number of connections across all peers
    pub fn getTotalConnections(self: *ConnectionPool) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var total: u32 = 0;
        var it = self.pools.iterator();
        while (it.next()) |entry| {
            total += @intCast(entry.value_ptr.connections.items.len);
        }
        return total;
    }

    /// Get number of active (in-use) connections
    pub fn getActiveConnections(self: *ConnectionPool) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active: u32 = 0;
        var it = self.pools.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.connections.items) |conn| {
                if (conn.in_use) active += 1;
            }
        }
        return active;
    }

    /// Get pool stats
    pub fn getStats(self: *ConnectionPool) PoolStats {
        return PoolStats{
            .total_connections = self.getTotalConnections(),
            .active_connections = self.getActiveConnections(),
            .total_acquired = self.total_acquired,
            .total_released = self.total_released,
            .total_discarded = self.total_discarded,
            .total_pruned = self.total_pruned,
        };
    }
};

pub const PoolStats = struct {
    total_connections: u32,
    active_connections: u32,
    total_acquired: u64,
    total_released: u64,
    total_discarded: u64,
    total_pruned: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "pool struct creation and deinit" {
    var pool = ConnectionPool.init(std.testing.allocator);
    defer pool.deinit();

    try std.testing.expectEqual(@as(u32, 4), pool.max_per_peer);
    try std.testing.expectEqual(@as(i128, 30_000_000_000), pool.idle_timeout_ns);
    try std.testing.expectEqual(@as(u32, 0), pool.getTotalConnections());
    try std.testing.expectEqual(@as(u32, 0), pool.getActiveConnections());
}

test "pool stats tracking" {
    var pool = ConnectionPool.init(std.testing.allocator);
    defer pool.deinit();

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u32, 0), stats.total_connections);
    try std.testing.expectEqual(@as(u32, 0), stats.active_connections);
    try std.testing.expectEqual(@as(u64, 0), stats.total_acquired);
    try std.testing.expectEqual(@as(u64, 0), stats.total_released);
    try std.testing.expectEqual(@as(u64, 0), stats.total_discarded);
    try std.testing.expectEqual(@as(u64, 0), stats.total_pruned);
}

test "pool pruneIdle with no connections returns 0" {
    var pool = ConnectionPool.init(std.testing.allocator);
    defer pool.deinit();

    const pruned = pool.pruneIdle();
    try std.testing.expectEqual(@as(u32, 0), pruned);
}
