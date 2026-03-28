// @origin(spec:depin_bootstrap.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// BOOTSTRAP NODES — Directed Discovery for Railway DePIN
// ═══════════════════════════════════════════════════════════════════════════════
//
// Problem: UDP broadcast 255.255.255.255:9333 only works in same subnet
// Solution: Directed discovery to known bootstrap nodes with public IPs
//
// Railway services have public IPs → can use directed UDP discovery
// Fallback: Railway API discovery for service list
//
// φ² + 1/φ² = 3 = TRINITY | DePIN Phase 1
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const DEFAULT_DISCOVERY_PORT = 9333;

/// Network mode (mainnet or testnet)
pub const NetworkMode = enum(u8) {
    mainnet,
    testnet,

    pub fn toString(self: NetworkMode) []const u8 {
        return switch (self) {
            .mainnet => "mainnet",
            .testnet => "testnet",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BOOTSTRAP PEER — Known entry point to DePIN network
// ═══════════════════════════════════════════════════════════════════════════════

pub const BootstrapPeer = struct {
    /// IP address or hostname
    host: []const u8,
    /// UDP discovery port (default 9333)
    port: u16,
    /// Trust score (0.0-1.0) based on historical reliability
    trust_score: f64,
    /// Last successful connection timestamp
    last_seen: u64,
    /// Failure count since last success
    failures: u32,

    pub fn formatAddress(self: *const BootstrapPeer, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}", .{ self.host, self.port });
    }

    pub fn isHealthy(self: *const BootstrapPeer) bool {
        const now: i64 = std.time.timestamp();
        const hours_since_seen: f64 = if (self.last_seen > 0)
            @as(f64, @floatFromInt(now - @as(i64, @intCast(self.last_seen)))) / 3600.0
        else
            999999.0;

        // Healthy if: seen in last 24h AND fewer than 3 failures
        return hours_since_seen < 24.0 and self.failures < 3;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BOOTSTRAP SOURCE — Where to get initial peer list
// ═══════════════════════════════════════════════════════════════════════════════

pub const BootstrapSource = enum {
    /// Hardcoded in binary (fastest, most reliable)
    hardcoded,
    /// DNS seed record (e.g., bootstrap.trinity.network)
    dns_seed,
    /// Railway API discovery (fallback)
    railway_api,
    /// Local cache (.tri-cluster.json)
    local_cache,
};

/// Mainnet bootstrap addresses (production)
pub const MAINNET_BOOTSTRAPS = [_][]const u8{
    "bootstrap-us.trinity.network:9333",
    "bootstrap-eu.trinity.network:9333",
    "bootstrap-asia.trinity.network:9333",
};

/// Testnet bootstrap addresses (for testing)
pub const TESTNET_BOOTSTRAPS = [_][]const u8{
    "bootstrap-us.test.trinity.network:9333",
    "bootstrap-eu.test.trinity.network:9333",
    "bootstrap-asia.test.trinity.network:9333",
    "bootstrap-sa.test.trinity.network:9333",
    "bootstrap-za.test.trinity.network:9333",
};

/// Get default bootstrap addresses for network mode
pub fn getDefaultBootstraps(mode: NetworkMode) []const []const u8 {
    return switch (mode) {
        .mainnet => &MAINNET_BOOTSTRAPS,
        .testnet => &TESTNET_BOOTSTRAPS,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOOTSTRAP MANAGER — Manages bootstrap peer list
// ═══════════════════════════════════════════════════════════════════════════════

pub const BootstrapManager = struct {
    allocator: Allocator,
    /// Known bootstrap peers
    peers: std.ArrayListUnmanaged(BootstrapPeer),
    /// Discovered peers (from network)
    discovered: std.ArrayListUnmanaged(DiscoveredPeer),
    /// DNS seed hostname (if configured)
    dns_seed: ?[]const u8,

    const DiscoveredPeer = struct {
        host: []const u8,
        port: u16,
        cluster_id: []const u8,
        node_id: []const u8,
        trust_score: f64,
        last_seen: u64,
    };

    pub fn init(allocator: Allocator) BootstrapManager {
        return BootstrapManager{
            .allocator = allocator,
            .peers = .{},
            .discovered = .{},
            .dns_seed = null,
        };
    }

    pub fn deinit(self: *BootstrapManager) void {
        for (self.peers.items) |*peer| {
            self.allocator.free(peer.host);
        }
        self.peers.deinit(self.allocator);

        for (self.discovered.items) |*peer| {
            self.allocator.free(peer.host);
            self.allocator.free(peer.cluster_id);
            self.allocator.free(peer.node_id);
        }
        self.discovered.deinit(self.allocator);

        if (self.dns_seed) |seed| {
            self.allocator.free(seed);
        }
    }

    /// Add hardcoded bootstrap peers (called at startup)
    pub fn addHardcodedPeer(self: *BootstrapManager, host: []const u8, port: u16) !void {
        const host_copy = try self.allocator.dupe(u8, host);
        errdefer self.allocator.free(host_copy);

        try self.peers.append(self.allocator, BootstrapPeer{
            .host = host_copy,
            .port = port,
            .trust_score = 1.0, // Initial trust
            .last_seen = 0,
            .failures = 0,
        });
    }

    /// Get all bootstrap peers (for directed discovery)
    pub fn getBootstrapPeers(self: *const BootstrapManager) []const BootstrapPeer {
        return self.peers.items;
    }

    /// Get only healthy bootstrap peers
    pub fn getHealthyPeers(self: *const BootstrapManager) []const BootstrapPeer {
        // Return all peers for now (filtering would require allocation)
        return self.peers.items;
    }

    /// Add a newly discovered peer from the network
    pub fn addDiscoveredPeer(
        self: *BootstrapManager,
        host: []const u8,
        port: u16,
        cluster_id: []const u8,
        node_id: []const u8,
    ) !void {
        // Check if already discovered
        for (self.discovered.items) |*peer| {
            if (std.mem.eql(u8, peer.node_id, node_id)) {
                // Update last_seen
                peer.last_seen = @intCast(std.time.timestamp());
                return;
            }
        }

        const host_copy = try self.allocator.dupe(u8, host);
        errdefer self.allocator.free(host_copy);

        const cluster_copy = try self.allocator.dupe(u8, cluster_id);
        errdefer self.allocator.free(cluster_copy);

        const node_copy = try self.allocator.dupe(u8, node_id);
        errdefer self.allocator.free(node_copy);

        try self.discovered.append(self.allocator, DiscoveredPeer{
            .host = host_copy,
            .port = port,
            .cluster_id = cluster_copy,
            .node_id = node_copy,
            .trust_score = 0.5, // Start with medium trust
            .last_seen = @intCast(std.time.timestamp()),
        });
    }

    /// Mark a bootstrap peer as seen successfully
    pub fn markPeerSeen(self: *BootstrapManager, host: []const u8) void {
        for (self.peers.items) |*peer| {
            if (std.mem.eql(u8, peer.host, host)) {
                peer.last_seen = @intCast(std.time.timestamp());
                peer.failures = 0;
                // Increase trust score
                peer.trust_score = @min(1.0, peer.trust_score + 0.1);
                break;
            }
        }
    }

    /// Mark a bootstrap peer as failed
    pub fn markPeerFailed(self: *BootstrapManager, host: []const u8) void {
        for (self.peers.items) |*peer| {
            if (std.mem.eql(u8, peer.host, host)) {
                peer.failures += 1;
                // Decrease trust score
                peer.trust_score = @max(0.0, peer.trust_score - 0.2);
                break;
            }
        }
    }

    /// Get all known peers (bootstrap + discovered)
    pub fn getAllKnownPeers(self: *const BootstrapManager, allocator: Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(allocator);

        // Add bootstrap peers
        for (self.peers.items) |peer| {
            const addr = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ peer.host, peer.port });
            try list.append(addr);
        }

        // Add discovered peers
        for (self.discovered.items) |peer| {
            const addr = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ peer.host, peer.port });
            try list.append(addr);
        }

        return list.toOwnedSlice();
    }

    /// Get statistics
    pub fn getStats(self: *const BootstrapManager) BootstrapStats {
        var healthy: usize = 0;
        for (self.peers.items) |peer| {
            if (peer.isHealthy()) healthy += 1;
        }

        return BootstrapStats{
            .total_bootstrap = self.peers.items.len,
            .healthy_bootstrap = healthy,
            .total_discovered = self.discovered.items.len,
        };
    }
};

pub const BootstrapStats = struct {
    total_bootstrap: usize,
    healthy_bootstrap: usize,
    total_discovered: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RAILWAY DISCOVERY — Fallback using Railway API
// ═══════════════════════════════════════════════════════════════════════════════

pub const RailwayDiscovery = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) RailwayDiscovery {
        return RailwayDiscovery{
            .allocator = allocator,
        };
    }

    /// Discover Railway services with public IPs
    /// Returns list of "public-ip:9333" addresses
    pub fn discoverServices(self: *RailwayDiscovery, railway_token: []const u8, project_id: []const u8) ![][]const u8 {
        _ = railway_token;
        _ = project_id;
        // DEFERRED: Actual Railway API call
        // For now, return empty list
        return std.ArrayList([]const u8).init(self.allocator).toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DNS SEED — Resolve bootstrap nodes from DNS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DnsSeedResolver = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) DnsSeedResolver {
        return DnsSeedResolver{
            .allocator = allocator,
        };
    }

    /// Resolve DNS seed to bootstrap peer addresses
    /// e.g., _bootstrap._tcp.trinity.network SRV record
    pub fn resolveSeed(self: *DnsSeedResolver, seed_host: []const u8) ![][]const u8 {
        _ = seed_host;
        // DEFERRED: Actual DNS resolution
        // For now, return empty list
        return std.ArrayList([]const u8).init(self.allocator).toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BootstrapManager init and add hardcoded peer" {
    const allocator = std.testing.allocator;
    var manager = BootstrapManager.init(allocator);
    defer manager.deinit();

    try manager.addHardcodedPeer("1.2.3.4", 9333);
    try manager.addHardcodedPeer("bootstrap.trinity.network", 9333);

    const peers = manager.getBootstrapPeers();
    try std.testing.expectEqual(@as(usize, 2), peers.len);
    try std.testing.expectEqualStrings("1.2.3.4", peers[0].host);
    try std.testing.expectEqual(@as(u16, 9333), peers[0].port);
}

test "BootstrapPeer health check" {
    var peer = BootstrapPeer{
        .host = "1.2.3.4",
        .port = 9333,
        .trust_score = 1.0,
        .last_seen = @intCast(std.time.timestamp()),
        .failures = 0,
    };

    try std.testing.expect(peer.isHealthy());

    // Old peer (seen 25 hours ago)
    const now = std.time.timestamp();
    peer.last_seen = @intCast(now - @as(i64, @intCast(25 * 3600)));
    try std.testing.expect(!peer.isHealthy());
}

test "BootstrapManager add discovered peer" {
    const allocator = std.testing.allocator;
    var manager = BootstrapManager.init(allocator);
    defer manager.deinit();

    try manager.addDiscoveredPeer("5.6.7.8", 9333, "test-cluster", "node-123");

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_discovered);
}

test "BootstrapManager mark peer seen/failed" {
    const allocator = std.testing.allocator;
    var manager = BootstrapManager.init(allocator);
    defer manager.deinit();

    try manager.addHardcodedPeer("1.2.3.4", 9333);

    // Mark seen
    manager.markPeerSeen("1.2.3.4");
    const peers = manager.getBootstrapPeers();
    try std.testing.expect(peers[0].last_seen > 0);
    try std.testing.expectEqual(@as(u32, 0), peers[0].failures);

    // Mark failed
    manager.markPeerFailed("1.2.3.4");
    try std.testing.expectEqual(@as(u32, 1), peers[0].failures);
}

test "BootstrapPeer format address" {
    const allocator = std.testing.allocator;
    var peer = BootstrapPeer{
        .host = "1.2.3.4",
        .port = 9333,
        .trust_score = 1.0,
        .last_seen = 0,
        .failures = 0,
    };

    const addr = try peer.formatAddress(allocator);
    defer allocator.free(addr);

    try std.testing.expectEqualStrings("1.2.3.4:9333", addr);
}

test "NetworkMode toString" {
    try std.testing.expectEqualStrings("mainnet", NetworkMode.mainnet.toString());
    try std.testing.expectEqualStrings("testnet", NetworkMode.testnet.toString());
}

test "getDefaultBootstraps mainnet" {
    const bootstraps = getDefaultBootstraps(.mainnet);
    try std.testing.expectEqual(@as(usize, 3), bootstraps.len);
    try std.testing.expectEqualStrings("bootstrap-us.trinity.network:9333", bootstraps[0]);
}

test "getDefaultBootstraps testnet" {
    const bootstraps = getDefaultBootstraps(.testnet);
    try std.testing.expectEqual(@as(usize, 5), bootstraps.len);
    try std.testing.expectEqualStrings("bootstrap-us.test.trinity.network:9333", bootstraps[0]);
    try std.testing.expectEqualStrings("bootstrap-sa.test.trinity.network:9333", bootstraps[3]);
}
