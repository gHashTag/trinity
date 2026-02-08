// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE DISCOVERY - UDP Peer Discovery
// Broadcast + Bootstrap node fallback
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ArrayList = std.array_list.Managed;
const protocol = @import("protocol.zig");
const crypto = @import("crypto.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DISCOVERY_PORT: u16 = 9333;
pub const BROADCAST_INTERVAL_MS: u64 = 5000; // 5 seconds
pub const PEER_TIMEOUT_MS: u64 = 30000; // 30 seconds
pub const MAX_PEERS: usize = 256;

// Default bootstrap nodes
pub const DEFAULT_BOOTSTRAP_NODES = [_][]const u8{
    "bootstrap1.trinity.network:9333",
    "bootstrap2.trinity.network:9333",
};

// ═══════════════════════════════════════════════════════════════════════════════
// PEER INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const Peer = struct {
    node_id: protocol.NodeId,
    public_key: [32]u8,
    address: std.net.Address,
    listen_port: u16,
    last_seen: i64,
    latency_ms: u32,
    capabilities_hash: [32]u8,

    pub fn isAlive(self: *const Peer) bool {
        const now = std.time.timestamp();
        return (now - self.last_seen) * 1000 < PEER_TIMEOUT_MS;
    }

    pub fn updateLastSeen(self: *Peer) void {
        self.last_seen = std.time.timestamp();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PEER LIST
// ═══════════════════════════════════════════════════════════════════════════════

pub const PeerList = struct {
    peers: [MAX_PEERS]?Peer,
    count: usize,
    mutex: std.Thread.Mutex,

    pub fn init() PeerList {
        return PeerList{
            .peers = [_]?Peer{null} ** MAX_PEERS,
            .count = 0,
            .mutex = .{},
        };
    }

    /// Add or update peer
    pub fn addOrUpdate(self: *PeerList, peer: Peer) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if peer already exists
        for (&self.peers) |*slot| {
            if (slot.*) |*existing| {
                if (std.mem.eql(u8, &existing.node_id, &peer.node_id)) {
                    existing.* = peer;
                    existing.updateLastSeen();
                    return;
                }
            }
        }

        // Add new peer
        for (&self.peers) |*slot| {
            if (slot.* == null) {
                slot.* = peer;
                self.count += 1;
                return;
            }
        }
    }

    /// Remove dead peers
    pub fn pruneDeadPeers(self: *PeerList) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        var removed: usize = 0;
        for (&self.peers) |*slot| {
            if (slot.*) |*peer| {
                if (!peer.isAlive()) {
                    slot.* = null;
                    self.count -= 1;
                    removed += 1;
                }
            }
        }
        return removed;
    }

    /// Get all alive peers
    pub fn getAlivePeers(self: *PeerList, allocator: std.mem.Allocator) ![]Peer {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = ArrayList(Peer).init(allocator);
        for (self.peers) |slot| {
            if (slot) |peer| {
                if (peer.isAlive()) {
                    try list.append(peer);
                }
            }
        }
        return list.toOwnedSlice();
    }

    /// Get peer by node ID
    pub fn getPeer(self: *PeerList, node_id: protocol.NodeId) ?Peer {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.peers) |slot| {
            if (slot) |peer| {
                if (std.mem.eql(u8, &peer.node_id, &node_id)) {
                    return peer;
                }
            }
        }
        return null;
    }

    /// Get best peer (lowest latency)
    pub fn getBestPeer(self: *PeerList) ?Peer {
        self.mutex.lock();
        defer self.mutex.unlock();

        var best: ?Peer = null;
        var best_latency: u32 = std.math.maxInt(u32);

        for (self.peers) |slot| {
            if (slot) |peer| {
                if (peer.isAlive() and peer.latency_ms < best_latency) {
                    best = peer;
                    best_latency = peer.latency_ms;
                }
            }
        }
        return best;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UDP DISCOVERY SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiscoveryService = struct {
    socket: std.posix.socket_t,
    node_id: protocol.NodeId,
    public_key: [32]u8,
    listen_port: u16,
    peers: PeerList,
    running: std.atomic.Value(bool),
    broadcast_thread: ?std.Thread,
    receive_thread: ?std.Thread,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, node_id: protocol.NodeId, public_key: [32]u8, listen_port: u16) !*DiscoveryService {
        const self = try allocator.create(DiscoveryService);

        // Create UDP socket
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        errdefer std.posix.close(socket);

        // Enable broadcast
        const broadcast_opt: i32 = 1;
        try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, std.mem.asBytes(&broadcast_opt));

        // Bind to discovery port
        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, DISCOVERY_PORT);
        std.posix.bind(socket, &addr.any, addr.getOsSockLen()) catch |err| {
            // Port might be in use, try with a random port
            if (err == error.AddressInUse) {
                const alt_addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 0);
                try std.posix.bind(socket, &alt_addr.any, alt_addr.getOsSockLen());
            } else {
                return err;
            }
        };

        self.* = DiscoveryService{
            .socket = socket,
            .node_id = node_id,
            .public_key = public_key,
            .listen_port = listen_port,
            .peers = PeerList.init(),
            .running = std.atomic.Value(bool).init(false),
            .broadcast_thread = null,
            .receive_thread = null,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *DiscoveryService) void {
        self.stop();
        std.posix.close(self.socket);
        self.allocator.destroy(self);
    }

    /// Start discovery service
    pub fn start(self: *DiscoveryService) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);

        // Start broadcast thread
        self.broadcast_thread = try std.Thread.spawn(.{}, broadcastLoop, .{self});

        // Start receive thread
        self.receive_thread = try std.Thread.spawn(.{}, receiveLoop, .{self});
    }

    /// Stop discovery service
    pub fn stop(self: *DiscoveryService) void {
        self.running.store(false, .release);

        if (self.broadcast_thread) |thread| {
            thread.join();
            self.broadcast_thread = null;
        }

        if (self.receive_thread) |thread| {
            thread.join();
            self.receive_thread = null;
        }
    }

    /// Broadcast loop - announces our presence
    fn broadcastLoop(self: *DiscoveryService) void {
        while (self.running.load(.acquire)) {
            self.broadcastAnnounce() catch {};
            std.Thread.sleep(BROADCAST_INTERVAL_MS * std.time.ns_per_ms);
        }
    }

    /// Receive loop - listens for peer announcements
    fn receiveLoop(self: *DiscoveryService) void {
        var buf: [1024]u8 = undefined;

        while (self.running.load(.acquire)) {
            var src_addr: std.posix.sockaddr = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

            const len = std.posix.recvfrom(self.socket, &buf, 0, &src_addr, &addr_len) catch |err| {
                if (err == error.WouldBlock) continue;
                break;
            };

            if (len >= 106) {
                self.handleAnnounce(buf[0..len], std.net.Address{ .any = src_addr }) catch {};
            }
        }
    }

    /// Broadcast our peer announcement
    fn broadcastAnnounce(self: *DiscoveryService) !void {
        const announce = protocol.PeerAnnounce{
            .node_id = self.node_id,
            .public_key = self.public_key,
            .listen_port = self.listen_port,
            .capabilities_hash = crypto.sha256(&self.node_id), // TODO: real capabilities hash
            .timestamp = std.time.timestamp(),
        };

        const bytes = announce.serialize();

        // Broadcast to local network
        const broadcast_addr = std.net.Address.initIp4(.{ 255, 255, 255, 255 }, DISCOVERY_PORT);
        _ = std.posix.sendto(self.socket, &bytes, 0, &broadcast_addr.any, broadcast_addr.getOsSockLen()) catch {};
    }

    /// Handle incoming peer announcement
    fn handleAnnounce(self: *DiscoveryService, data: []const u8, src_addr: std.net.Address) !void {
        const announce = try protocol.PeerAnnounce.deserialize(data);

        // Ignore our own announcements
        if (std.mem.eql(u8, &announce.node_id, &self.node_id)) return;

        // Add or update peer
        const peer = Peer{
            .node_id = announce.node_id,
            .public_key = announce.public_key,
            .address = src_addr,
            .listen_port = announce.listen_port,
            .last_seen = std.time.timestamp(),
            .latency_ms = 0, // TODO: measure latency
            .capabilities_hash = announce.capabilities_hash,
        };

        self.peers.addOrUpdate(peer);
    }

    /// Get number of known peers
    pub fn getPeerCount(self: *DiscoveryService) usize {
        return self.peers.count;
    }

    /// Get all alive peers
    pub fn getAlivePeers(self: *DiscoveryService) ![]Peer {
        return self.peers.getAlivePeers(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "peer list operations" {
    var list = PeerList.init();

    var peer = Peer{
        .node_id = undefined,
        .public_key = undefined,
        .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9333),
        .listen_port = 9334,
        .last_seen = std.time.timestamp(),
        .latency_ms = 100,
        .capabilities_hash = undefined,
    };
    @memset(&peer.node_id, 0xAB);
    @memset(&peer.public_key, 0xCD);
    @memset(&peer.capabilities_hash, 0xEF);

    list.addOrUpdate(peer);
    try std.testing.expectEqual(@as(usize, 1), list.count);

    const found = list.getPeer(peer.node_id);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(peer.listen_port, found.?.listen_port);
}

test "peer alive check" {
    var peer = Peer{
        .node_id = undefined,
        .public_key = undefined,
        .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 9333),
        .listen_port = 9334,
        .last_seen = std.time.timestamp(),
        .latency_ms = 100,
        .capabilities_hash = undefined,
    };

    try std.testing.expect(peer.isAlive());

    // Simulate old peer
    peer.last_seen = std.time.timestamp() - 60; // 60 seconds ago
    try std.testing.expect(!peer.isAlive());
}
