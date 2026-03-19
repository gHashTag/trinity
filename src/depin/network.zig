// ═══════════════════════════════════════════════════════════════════════════════
// DePIN NETWORK v1.1 — Directed Discovery + Persistence Integration
// UDP: 9333 | TCP Jobs: 9334 | REST API: 8080
// φ² + 1/φ² = 3 = TRINITY | Order #100-1 | Phase 1 Update
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const bootstrap = @import("bootstrap");
const persistence = @import("persistence");
const metrics_mod = @import("metrics");

// Forward decls for firebird types (will be imported by build.zig)
pub const NodeStatus = enum {
    offline,
    syncing,
    online,
    earning,
};

// Firebird constants (imported from DePIN module)
pub const TIER_MULTIPLIER_FREE: f64 = 1.0;
pub const TIER_MULTIPLIER_STAKER: f64 = 1.5;
pub const TIER_MULTIPLIER_POWER: f64 = 2.0;
pub const TIER_MULTIPLIER_WHALE: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const UDP_DISCOVERY_PORT = 9333;
pub const TCP_JOB_PORT = 9334;
pub const HTTP_API_PORT = 8080;
pub const DISCOVERY_TIMEOUT_MS = 5000;
pub const MAX_PACKET_SIZE = 4096;
pub const MAX_NODES = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeRole = enum(u8) {
    coordinator = 0,
    worker = 1,
    storage = 2,

    pub fn toString(self: NodeRole) []const u8 {
        return switch (self) {
            .coordinator => "coordinator",
            .worker => "worker",
            .storage => "storage",
        };
    }
};

pub const NodeTier = enum(u8) {
    free = 0,
    staker = 1,
    power = 2,
    whale = 3,

    pub fn toString(self: NodeTier) []const u8 {
        return switch (self) {
            .free => "FREE",
            .staker => "STAKER",
            .power => "POWER",
            .whale => "WHALE",
        };
    }

    pub fn getMultiplier(self: NodeTier) f64 {
        return switch (self) {
            .free => TIER_MULTIPLIER_FREE,
            .staker => TIER_MULTIPLIER_STAKER,
            .power => TIER_MULTIPLIER_POWER,
            .whale => TIER_MULTIPLIER_WHALE,
        };
    }
};

pub const SocketAddr = struct {
    ip: []const u8,
    port: u16,

    pub fn format(self: *const SocketAddr, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}", .{ self.ip, self.port });
    }
};

pub const NodeDiscovery = struct {
    cluster_id: []const u8,
    node_id: []const u8,
    addr: SocketAddr,
    role: NodeRole,
    tier: NodeTier,
    timestamp: u64,
};

pub const JobPacket = struct {
    job_id: []const u8,
    payload: []const u8,
    reward: f64,
    timestamp: u64,

    pub fn toJson(self: *const JobPacket, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"job_id":"{s}","payload":"{s}","reward":{d:.6},"timestamp":{d}}}
        , .{ self.job_id, self.payload, self.reward, self.timestamp });
    }
};

pub const NetworkError = error{
    SocketCreateFailed,
    BindFailed,
    SendFailed,
    ReceiveFailed,
    InvalidPacket,
    Timeout,
    ConnectionFailed,
};

pub const ClusterNode = struct {
    id: []const u8,
    address: SocketAddr,
    role: NodeRole,
    tier: NodeTier,
    status: NodeStatus,
    operations_count: u64,
    earned_tri: f64,
    pending_tri: f64,
    last_heartbeat: u64,
    /// Quality score (0.0-1.0) based on uptime/responsiveness
    quality_score: f64 = 1.0,
    /// First discovered timestamp
    first_seen: u64 = 0,

    pub fn calculateReward(self: *const ClusterNode, base_reward: f64) f64 {
        return base_reward * self.tier.getMultiplier() * self.quality_score;
    }

    /// Check if node is healthy (seen in last hour, quality > 0.3)
    pub fn isHealthy(self: *const ClusterNode) bool {
        const now = std.time.timestamp();
        const hours_since_seen: f64 = if (self.last_heartbeat > 0)
            @as(f64, @floatFromInt(now - self.last_heartbeat)) / 3600.0
        else
            999999.0;

        return hours_since_seen < 1.0 and self.quality_score > 0.3;
    }

    /// Update quality score based on interaction
    pub fn updateQuality(self: *ClusterNode, success: bool, latency_ms: u64) void {
        const now = std.time.timestamp();
        if (self.first_seen == 0) self.first_seen = now;
        self.last_heartbeat = now;

        if (success) {
            const latency_bonus = if (latency_ms < 100)
                0.05
            else if (latency_ms < 500)
                0.02
            else
                0.0;
            self.quality_score = @min(1.0, self.quality_score + 0.1 + latency_bonus);
        } else {
            self.quality_score = @max(0.0, self.quality_score - 0.2);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UDP DISCOVERY
// ═══════════════════════════════════════════════════════════════════════════════

pub const UDPDiscovery = struct {
    socket: std.posix.socket_t,
    port: u16,
    allocator: std.mem.Allocator,

    pub fn init(port: u16, allocator: std.mem.Allocator) !UDPDiscovery {
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);

        // Enable broadcast
        const broadcast_value: u32 = 1;
        _ = std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, &std.mem.toBytes(@as(c_int, @intCast(broadcast_value)))) catch |err| {
            std.posix.close(socket);
            return err;
        };

        // Enable reuse address
        const reuse_value: u32 = 1;
        _ = std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, @intCast(reuse_value)))) catch |err| {
            std.posix.close(socket);
            return err;
        };

        // Bind to address
        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, port);
        std.posix.bind(socket, &addr.any, addr.getOsSockLen()) catch |err| {
            std.posix.close(socket);
            return err;
        };

        return UDPDiscovery{
            .socket = socket,
            .port = port,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UDPDiscovery) void {
        std.posix.close(self.socket);
    }

    pub fn broadcastDiscovery(self: *const UDPDiscovery, cluster_id: []const u8, node_id: []const u8) !void {
        const packet = try std.fmt.allocPrint(self.allocator,
            \\{{"type":"discovery","cluster_id":"{s}","node_id":"{s}","timestamp":{d}}}
        , .{ cluster_id, node_id, std.time.milliTimestamp() });
        defer self.allocator.free(packet);

        const broadcast_addr = std.net.Address.initIp4(.{ 255, 255, 255, 255 }, self.port);

        _ = try std.posix.sendto(self.socket, packet, 0, &broadcast_addr.any, broadcast_addr.getOsSockLen());
    }

    /// Directed discovery to specific IP address (for Railway public IPs)
    pub fn directedDiscovery(self: *const UDPDiscovery, target_ip: []const u8, target_port: u16, cluster_id: []const u8, node_id: []const u8) !void {
        const packet = try std.fmt.allocPrint(self.allocator,
            \\{{"type":"discovery","cluster_id":"{s}","node_id":"{s}","timestamp":{d}}}
        , .{ cluster_id, node_id, std.time.milliTimestamp() });
        defer self.allocator.free(packet);

        // Parse IP address
        var iter = std.mem.splitScalar(u8, target_ip, '.');
        var octets: [4]u8 = undefined;
        var i: usize = 0;
        while (iter.next()) |octet| {
            octets[i] = try std.fmt.parseInt(u8, octet, 10);
            i += 1;
        }

        const target_addr = std.net.Address.initIp4(octets, target_port);

        _ = try std.posix.sendto(self.socket, packet, 0, &target_addr.any, target_addr.getOsSockLen());
    }

    /// Directed discovery to multiple bootstrap peers
    pub fn discoverFromBootstrap(self: *const UDPDiscovery, bootstrap_peers: []const bootstrap.BootstrapPeer, cluster_id: []const u8, node_id: []const u8) !usize {
        var sent: usize = 0;

        for (bootstrap_peers) |peer| {
            // Only send to healthy peers
            if (!peer.isHealthy()) continue;

            self.directedDiscovery(peer.host, peer.port, cluster_id, node_id) catch |err| {
                std.log.debug("network: failed to send discovery to {s}: {}", .{ peer.host, err });
                continue;
            };
            sent += 1;
        }

        return sent;
    }

    pub fn receiveDiscovery(self: *UDPDiscovery, timeout_ms: u64) !?NodeDiscovery {
        // Set receive timeout
        if (timeout_ms > 0) {
            const tv = std.posix.timeval{
                .sec = @intCast(timeout_ms / 1000),
                .usec = @intCast((timeout_ms % 1000) * 1000),
            };
            _ = std.posix.setsockopt(self.socket, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, &std.mem.toBytes(tv)) catch |err| {
                std.log.debug("network: failed to set receive timeout: {}", .{err});
            };
        }

        var buf: [MAX_PACKET_SIZE]u8 = undefined;
        var src_addr: std.net.Address = undefined;
        var src_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

        const len = std.posix.recvfrom(self.socket, &buf, 0, &src_addr.any, &src_len) catch |err| {
            if (err == error.WouldBlock) return null;
            return err;
        };

        const data = buf[0..len];

        // Parse JSON discovery packet
        // Simplified parsing (in production, use proper JSON parser)
        if (std.mem.indexOf(u8, data, "\"type\":\"discovery\"") == null) {
            return NetworkError.InvalidPacket;
        }

        // Extract fields (simplified)
        const cluster_id_start = std.mem.indexOf(u8, data, "\"cluster_id\":\"") orelse return NetworkError.InvalidPacket;
        const cluster_id_end = std.mem.indexOf(u8, data[cluster_id_start + 14 ..], "\"") orelse return NetworkError.InvalidPacket;
        const cluster_id = data[cluster_id_start + 14 .. cluster_id_start + 14 + cluster_id_end];

        const node_id_start = std.mem.indexOf(u8, data, "\"node_id\":\"") orelse return NetworkError.InvalidPacket;
        const node_id_end = std.mem.indexOf(u8, data[node_id_start + 11 ..], "\"") orelse return NetworkError.InvalidPacket;
        const node_id = data[node_id_start + 11 .. node_id_start + 11 + node_id_end];

        // Get IP string from src_addr (IPv4 only for now)
        // Extract bytes from the in_addr struct
        const bytes: *const [4]u8 = @ptrCast(&src_addr.in.sa.addr);
        const ip_alloc = try std.fmt.allocPrint(self.allocator, "{d}.{d}.{d}.{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
        errdefer self.allocator.free(ip_alloc);

        return NodeDiscovery{
            .cluster_id = try self.allocator.dupe(u8, cluster_id),
            .node_id = try self.allocator.dupe(u8, node_id),
            .addr = SocketAddr{
                .ip = ip_alloc,
                .port = src_addr.getPort(),
            },
            .role = .worker, // Default
            .tier = .free, // Default
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
        };
    }

    pub fn respondToDiscovery(self: *const UDPDiscovery, dest_addr: std.net.Address, cluster_id: []const u8, node_id: []const u8, role: NodeRole, tier: NodeTier) !void {
        const packet = try std.fmt.allocPrint(self.allocator,
            \\{{"type":"discovery_response","cluster_id":"{s}","node_id":"{s}","role":"{s}","tier":"{s}","timestamp":{d}}}
        , .{ cluster_id, node_id, role.toString(), tier.toString(), @as(u64, @intCast(std.time.milliTimestamp())) });
        defer self.allocator.free(packet);

        _ = try std.posix.sendto(self.socket, packet, 0, &dest_addr.any, dest_addr.getOsSockLen());
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TCP JOB DISTRIBUTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const TCPJobServer = struct {
    server_socket: std.posix.socket_t,
    port: u16,
    allocator: std.mem.Allocator,
    running: bool,

    pub fn init(port: u16, allocator: std.mem.Allocator) !TCPJobServer {
        const server_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);

        // Enable reuse address
        const reuse_value: u32 = 1;
        _ = std.posix.setsockopt(server_socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, @intCast(reuse_value)))) catch |err| {
            std.posix.close(server_socket);
            return err;
        };

        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, port);
        std.posix.bind(server_socket, &addr.any, addr.getOsSockLen()) catch |err| {
            std.posix.close(server_socket);
            return err;
        };

        try std.posix.listen(server_socket, 128);

        return TCPJobServer{
            .server_socket = server_socket,
            .port = port,
            .allocator = allocator,
            .running = false,
        };
    }

    pub fn deinit(self: *TCPJobServer) void {
        self.running = false;
        std.posix.close(self.server_socket);
    }

    pub fn start(self: *TCPJobServer) void {
        self.running = true;
    }

    pub fn acceptConnection(self: *TCPJobServer) !TCPJobConnection {
        var client_addr: std.net.Address = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

        const client_socket = std.posix.accept(self.server_socket, &client_addr.any, &addr_len) catch |err| {
            return err;
        };

        return TCPJobConnection{
            .socket = client_socket,
            .address = client_addr,
            .allocator = self.allocator,
        };
    }
};

pub const TCPJobConnection = struct {
    socket: std.posix.socket_t,
    address: std.net.Address,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TCPJobConnection) void {
        std.posix.close(self.socket);
    }

    pub fn sendJob(self: *TCPJobConnection, job: JobPacket) !void {
        const json = try job.toJson(self.allocator);
        defer self.allocator.free(json);

        const header = try std.fmt.allocPrint(self.allocator, "Content-Length: {d}\r\n\r\n", .{json.len});
        defer self.allocator.free(header);

        // Send header
        _ = try std.posix.send(self.socket, header, 0);

        // Send body
        _ = try std.posix.send(self.socket, json, 0);
    }

    pub fn receiveResult(self: *TCPJobConnection, max_size: usize) ![]const u8 {
        _ = max_size; // Will be used for size limiting
        var buffer: [MAX_PACKET_SIZE]u8 = undefined;

        const len = std.posix.recv(self.socket, &buffer, 0) catch |err| {
            return err;
        };

        if (len == 0) return error.ConnectionClosed;

        return self.allocator.dupe(u8, buffer[0..len]);
    }
};

pub const TCPJobClient = struct {
    socket: std.posix.socket_t,
    allocator: std.mem.Allocator,

    pub fn connect(address: std.net.Address, allocator: std.mem.Allocator) !TCPJobClient {
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);

        std.posix.connect(socket, &address.any, address.getOsSockLen()) catch |err| {
            std.posix.close(socket);
            return err;
        };

        return TCPJobClient{
            .socket = socket,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TCPJobClient) void {
        std.posix.close(self.socket);
    }

    pub fn receiveJob(self: *TCPJobClient) !JobPacket {
        // Receive header
        var header_buf: [256]u8 = undefined;
        const header_len = std.posix.recv(self.socket, &header_buf, 0) catch |err| {
            return err;
        };

        const header = header_buf[0..header_len];

        // Parse Content-Length
        const len_start = std.mem.indexOf(u8, header, "Content-Length: ") orelse return NetworkError.InvalidPacket;
        const len_end = std.mem.indexOf(u8, header[len_start..], "\r\n") orelse return NetworkError.InvalidPacket;
        const content_len_str = header[len_start + 16 .. len_start + len_end];
        const content_len = try std.fmt.parseInt(usize, content_len_str, 10);

        // Receive body
        var body_buf: [MAX_PACKET_SIZE]u8 = undefined;
        var total_received: usize = 0;

        while (total_received < content_len) {
            const received = std.posix.recv(self.socket, body_buf[total_received..], 0) catch |err| {
                return err;
            };
            if (received == 0) return error.ConnectionClosed;
            total_received += received;
        }

        // Parse JobPacket from JSON (simplified)
        const body = body_buf[0..content_len];

        const job_id_start = std.mem.indexOf(u8, body, "\"job_id\":\"") orelse return NetworkError.InvalidPacket;
        const job_id_end = std.mem.indexOf(u8, body[job_id_start + 10 ..], "\"") orelse return NetworkError.InvalidPacket;
        const job_id = body[job_id_start + 10 .. job_id_start + 10 + job_id_end];

        const payload_start = std.mem.indexOf(u8, body, "\"payload\":\"") orelse return NetworkError.InvalidPacket;
        const payload_end = std.mem.indexOf(u8, body[payload_start + 11 ..], "\"") orelse return NetworkError.InvalidPacket;
        const payload = body[payload_start + 11 .. payload_start + 11 + payload_end];

        const reward_start = std.mem.indexOf(u8, body, "\"reward\":") orelse return NetworkError.InvalidPacket;
        const reward_end = std.mem.indexOf(u8, body[reward_start + 9 ..], ",") orelse return NetworkError.InvalidPacket;
        const reward_str = body[reward_start + 9 .. reward_start + 9 + reward_end];
        const reward = try std.fmt.parseFloat(f64, reward_str);

        return JobPacket{
            .job_id = try self.allocator.dupe(u8, job_id),
            .payload = try self.allocator.dupe(u8, payload),
            .reward = reward,
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn sendResult(self: *TCPJobClient, result: []const u8) !void {
        _ = try std.posix.send(self.socket, result, 0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLUSTER MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ClusterManager = struct {
    cluster_id: []const u8,
    node_id: []const u8,
    role: NodeRole,
    tier: NodeTier,
    nodes: std.ArrayListUnmanaged(ClusterNode),
    udp: ?UDPDiscovery,
    tcp_server: ?TCPJobServer,
    allocator: std.mem.Allocator,
    /// Bootstrap manager for directed discovery
    bootstrap_mgr: bootstrap.BootstrapManager,
    /// Persistence manager for state save/load
    persistence_mgr: persistence.PersistenceManager,
    /// State file loaded flag
    state_loaded: bool = false,

    pub fn init(cluster_id: []const u8, node_id: []const u8, role: NodeRole, tier: NodeTier, allocator: std.mem.Allocator) !ClusterManager {
        return ClusterManager{
            .cluster_id = try allocator.dupe(u8, cluster_id),
            .node_id = try allocator.dupe(u8, node_id),
            .role = role,
            .tier = tier,
            .nodes = .{},
            .udp = null,
            .tcp_server = null,
            .allocator = allocator,
            .bootstrap_mgr = bootstrap.BootstrapManager.init(allocator),
            .persistence_mgr = persistence.PersistenceManager.init(allocator),
        };
    }

    pub fn deinit(self: *ClusterManager) void {
        self.allocator.free(self.cluster_id);
        self.allocator.free(self.node_id);

        for (self.nodes.items) |*node| {
            self.allocator.free(node.id);
            self.allocator.free(node.address.ip);
        }
        self.nodes.deinit(self.allocator);

        if (self.udp) |*udp| udp.deinit();
        if (self.tcp_server) |*tcp| tcp.deinit();

        self.bootstrap_mgr.deinit();
        self.persistence_mgr.deinit();
    }

    /// Load cluster state from .tri-cluster.json
    pub fn loadState(self: *ClusterManager) !bool {
        var state = try self.persistence_mgr.load() orelse return false;

        // Convert PeerState to ClusterNode
        for (state.peers.items) |peer| {
            const ip = try self.allocator.dupe(u8, peer.host);
            errdefer self.allocator.free(ip);

            const node_id_copy = try self.allocator.dupe(u8, peer.node_id);
            errdefer self.allocator.free(node_id_copy);

            const node = ClusterNode{
                .id = node_id_copy,
                .address = SocketAddr{
                    .ip = ip,
                    .port = peer.port,
                },
                .role = if (peer.role == .coordinator) .coordinator else if (peer.role == .storage) .storage else .worker,
                .tier = if (peer.tier == .staker) .staker else if (peer.tier == .power) .power else if (peer.tier == .whale) .whale else .free,
                .status = .offline,
                .operations_count = 0,
                .earned_tri = 0.0,
                .pending_tri = 0.0,
                .last_heartbeat = peer.last_seen,
                .quality_score = peer.quality_score,
                .first_seen = peer.first_seen,
            };

            try self.nodes.append(self.allocator, node);
        }

        // Also add to bootstrap manager
        for (state.peers.items) |peer| {
            try self.bootstrap_mgr.addDiscoveredPeer(
                peer.host,
                peer.port,
                peer.cluster_id,
                peer.node_id,
            );
        }

        state.deinit(self.allocator);
        self.state_loaded = true;
        return true;
    }

    /// Save cluster state to .tri-cluster.json
    pub fn saveState(self: *ClusterManager) !void {
        var state = persistence.ClusterState.init(
            self.cluster_id,
            self.node_id,
        );
        defer state.deinit(self.allocator);

        const now = @as(u64, @intCast(std.time.timestamp()));

        for (self.nodes.items) |node| {
            const peer = persistence.PeerState{
                .node_id = node.id,
                .host = node.address.ip,
                .port = node.address.port,
                .cluster_id = self.cluster_id,
                .quality_score = node.quality_score,
                .last_seen = node.last_heartbeat,
                .first_seen = if (node.first_seen > 0) node.first_seen else now,
                .role = if (node.role == .coordinator) .coordinator else if (node.role == .storage) .storage else .worker,
                .tier = if (node.tier == .staker) .staker else if (node.tier == .power) .power else if (node.tier == .whale) .whale else .free,
            };

            try state.addOrUpdatePeer(self.allocator, peer);
        }

        try self.persistence_mgr.save(&state);
    }

    /// Add bootstrap peer for directed discovery
    pub fn addBootstrapPeer(self: *ClusterManager, host: []const u8, port: u16) !void {
        try self.bootstrap_mgr.addHardcodedPeer(host, port);
    }

    /// Get discovered peers count
    pub fn getDiscoveredCount(self: *const ClusterManager) usize {
        const stats = self.bootstrap_mgr.getStats();
        return stats.total_discovered;
    }

    pub fn startCoordinator(self: *ClusterManager, udp_port: u16, tcp_port: u16) !void {
        self.udp = try UDPDiscovery.init(udp_port, self.allocator);
        self.tcp_server = try TCPJobServer.init(tcp_port, self.allocator);
        self.tcp_server.?.start();
    }

    pub fn startWorker(self: *ClusterManager, coordinator_addr: std.net.Address) !void {
        _ = self; // Will be used for connection
        _ = coordinator_addr; // Will be used to connect
        // Implementation: send discovery response, wait for jobs
    }

    pub fn discoverNodes(self: *ClusterManager, timeout_ms: u64) !usize {
        if (self.udp == null) return NetworkError.SocketCreateFailed;

        // First, try directed discovery to bootstrap peers
        const bootstrap_peers = self.bootstrap_mgr.getBootstrapPeers();
        if (bootstrap_peers.len > 0) {
            _ = try self.udp.?.discoverFromBootstrap(bootstrap_peers, self.cluster_id, self.node_id);
        }

        // Fall back to broadcast (for local subnet)
        try self.udp.?.broadcastDiscovery(self.cluster_id, self.node_id);

        var discovered: usize = 0;
        const start_time = std.time.milliTimestamp();

        while (std.time.milliTimestamp() - start_time < timeout_ms) {
            const discovery = try self.udp.?.receiveDiscovery(1000);
            if (discovery) |d| {
                // Check if node already exists
                var exists = false;
                for (self.nodes.items) |*node| {
                    if (std.mem.eql(u8, node.id, d.node_id)) {
                        exists = true;
                        // Update existing node
                        node.last_heartbeat = d.timestamp;
                        break;
                    }
                }

                if (!exists) {
                    // Add node to cluster
                    const node = ClusterNode{
                        .id = try self.allocator.dupe(u8, d.node_id),
                        .address = d.addr,
                        .role = d.role,
                        .tier = d.tier,
                        .status = .online,
                        .operations_count = 0,
                        .earned_tri = 0.0,
                        .pending_tri = 0.0,
                        .last_heartbeat = d.timestamp,
                        .quality_score = 0.5, // Start with medium quality
                        .first_seen = d.timestamp,
                    };

                    try self.nodes.append(self.allocator, node);

                    // Add to bootstrap manager for future discovery
                    try self.bootstrap_mgr.addDiscoveredPeer(
                        d.addr.ip,
                        d.addr.port,
                        d.cluster_id,
                        d.node_id,
                    );

                    discovered += 1;
                }

                // Free discovery allocations
                self.allocator.free(d.cluster_id);
                self.allocator.free(d.node_id);
                self.allocator.free(d.addr.ip);
            }
        }

        // Auto-save state after discovery
        self.saveState() catch |err| {
            std.log.debug("network: failed to save state: {}", .{err});
        };

        return discovered;
    }

    /// Directed discovery to specific bootstrap peer
    pub fn discoverFromPeer(self: *ClusterManager, host: []const u8, port: u16) !usize {
        if (self.udp == null) return NetworkError.SocketCreateFailed;

        try self.udp.?.directedDiscovery(host, port, self.cluster_id, self.node_id);

        // Wait for responses
        var discovered: usize = 0;
        const timeout_ms = 5000;
        const start_time = std.time.milliTimestamp();

        while (std.time.milliTimestamp() - start_time < timeout_ms) {
            const recv_result = self.udp.?.receiveDiscovery(1000) catch |err| {
                if (err == error.WouldBlock) continue;
                return err;
            };

            if (recv_result) |d| {
                // Check if node already exists
                var exists = false;
                for (self.nodes.items) |*node| {
                    if (std.mem.eql(u8, node.id, d.node_id)) {
                        exists = true;
                        node.last_heartbeat = d.timestamp;
                        break;
                    }
                }

                if (!exists) {
                    const node = ClusterNode{
                        .id = try self.allocator.dupe(u8, d.node_id),
                        .address = d.addr,
                        .role = d.role,
                        .tier = d.tier,
                        .status = .online,
                        .operations_count = 0,
                        .earned_tri = 0.0,
                        .pending_tri = 0.0,
                        .last_heartbeat = d.timestamp,
                        .quality_score = 0.5,
                        .first_seen = d.timestamp,
                    };

                    try self.nodes.append(self.allocator, node);
                    discovered += 1;
                }

                self.allocator.free(d.cluster_id);
                self.allocator.free(d.node_id);
                self.allocator.free(d.addr.ip);
            }
        }

        // Auto-save state
        self.saveState() catch {};

        return discovered;
    }

    pub fn distributeJob(self: *ClusterManager, payload: []const u8, base_reward: f64) !void {
        if (self.tcp_server == null) return NetworkError.SocketCreateFailed;

        // Accept connection from worker
        const conn = try self.tcp_server.?.acceptConnection();
        defer conn.deinit();

        // Create job packet
        const job_id = try std.fmt.allocPrint(self.allocator, "job-{d}", .{std.time.milliTimestamp()});
        defer self.allocator.free(job_id);

        const job = JobPacket{
            .job_id = job_id,
            .payload = payload,
            .reward = base_reward,
            .timestamp = std.time.milliTimestamp(),
        };

        try conn.sendJob(job);

        // Receive result
        const result = try conn.receiveResult(MAX_PACKET_SIZE);

        // DEFERRED: Process result - currently just acknowledges receipt
        _ = result.len; // Use result to indicate processing

        self.allocator.free(result);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REST API (HTTP 8080) — /status, /claim, /dashboard
// ═══════════════════════════════════════════════════════════════════════════════

pub const RestApiResponse = struct {
    status: u16,
    content_type: []const u8,
    body: []const u8,
};

pub const RestApiServer = struct {
    server_socket: std.posix.socket_t,
    port: u16,
    cluster: *ClusterManager,
    allocator: std.mem.Allocator,
    running: bool,

    pub fn init(port: u16, cluster: *ClusterManager, allocator: std.mem.Allocator) !RestApiServer {
        const server_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);

        // Enable reuse address
        const reuse_value: u32 = 1;
        _ = std.posix.setsockopt(server_socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, @intCast(reuse_value)))) catch |err| {
            std.posix.close(server_socket);
            return err;
        };

        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, port);
        std.posix.bind(server_socket, &addr.any, addr.getOsSockLen()) catch |err| {
            std.posix.close(server_socket);
            return err;
        };

        try std.posix.listen(server_socket, 128);

        return RestApiServer{
            .server_socket = server_socket,
            .port = port,
            .cluster = cluster,
            .allocator = allocator,
            .running = false,
        };
    }

    pub fn deinit(self: *RestApiServer) void {
        self.running = false;
        std.posix.close(self.server_socket);
    }

    pub fn start(self: *RestApiServer) void {
        self.running = true;
    }

    /// Handle GET /api/status — Return cluster status, nodes, $TRI balances
    pub fn handleStatus(self: *RestApiServer) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        try buffer.appendSlice(
            \\{"cluster_id":""
        );
        try buffer.appendSlice(self.cluster.cluster_id);
        try buffer.appendSlice(
            \\","node_id":""
        );
        try buffer.appendSlice(self.cluster.node_id);
        try buffer.appendSlice(
            \\","role":""
        );
        try buffer.appendSlice(self.cluster.role.toString());
        try buffer.appendSlice(
            \\","tier":""
        );
        try buffer.appendSlice(self.cluster.tier.toString());
        try buffer.appendSlice(
            \\","nodes":[
        );

        for (self.cluster.nodes.items, 0..) |node, i| {
            if (i > 0) try buffer.append(',');
            try buffer.appendSlice(
                \\{"id":""
            );
            try buffer.appendSlice(node.id);
            try buffer.appendSlice(
                \\","role":""
            );
            try buffer.appendSlice(node.role.toString());
            try buffer.appendSlice(
                \\","tier":""
            );
            try buffer.appendSlice(node.tier.toString());
            try buffer.appendSlice(
                \\","status":""
            );
            try buffer.appendSlice(@tagName(node.status));
            try buffer.appendSlice(
                \\","operations":
            );
            try std.fmt.formatInt(buffer.writer(), node.operations_count, 10, .lower, .{});
            try buffer.appendSlice(
                \\,"earned_tri":
            );
            try std.fmt.formatFloat(buffer.writer(), node.earned_tri, .{ .decimal_digits = 6 });
            try buffer.appendSlice(
                \\,"pending_tri":
            );
            try std.fmt.formatFloat(buffer.writer(), node.pending_tri, .{ .decimal_digits = 6 });
            try buffer.appendSlice('}');
        }

        try buffer.appendSlice(
            \\]}
        );

        return self.allocator.dupe(u8, buffer.items);
    }

    /// Handle POST /api/claim — Claim pending $TRI rewards
    pub fn handleClaim(self: *RestApiServer, node_id: []const u8) ![]const u8 {
        _ = node_id; // Will be used to find specific node

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        // For now, just return pending TRI from current node (self)
        // DEFERRED: Cross-node reward lookup - currently only returns local pending TRI

        try buffer.appendSlice(
            \\{"success":true,"claimed_tri":
        );
        try std.fmt.formatFloat(buffer.writer(), 0.0, .{ .decimal_digits = 6 });
        try buffer.appendSlice(
            \\,"new_balance":
        );
        try std.fmt.formatFloat(buffer.writer(), 0.0, .{ .decimal_digits = 6 });
        try buffer.appendSlice('}');

        return self.allocator.dupe(u8, buffer.items);
    }

    /// Handle GET /api/dashboard — Full dashboard HTML
    pub fn handleDashboard(self: *RestApiServer) ![]const u8 {
        const html =
            \\<!DOCTYPE html>
            \\<html>
            \\<head><title>TRINITY DePIN Dashboard</title></head>
            \\<body>
            \\  <h1>φ² + 1/φ² = 3 = TRINITY</h1>
            \\  <h2>Cluster: {s}</h2>
            \\  <p>Nodes: {d}</p>
            \\  <p>UDP Discovery: :{d}</p>
            \\  <p>TCP Jobs: :{d}</p>
            \\  <p>REST API: :{d}</p>
            \\</body>
            \\</html>
        ;

        return std.fmt.allocPrint(self.allocator, html, .{ self.cluster.cluster_id, self.cluster.nodes.items.len, UDP_DISCOVERY_PORT, TCP_JOB_PORT, HTTP_API_PORT });
    }

    /// Parse HTTP request and route to handler
    pub fn handleRequest(self: *RestApiServer, request: []const u8) !RestApiResponse {
        // Simple routing
        if (std.mem.indexOf(u8, request, "GET /api/status") != null) {
            const body = try self.handleStatus();
            return RestApiResponse{
                .status = 200,
                .content_type = "application/json",
                .body = body,
            };
        }

        if (std.mem.indexOf(u8, request, "POST /api/claim") != null) {
            const body = try self.handleClaim("self");
            return RestApiResponse{
                .status = 200,
                .content_type = "application/json",
                .body = body,
            };
        }

        if (std.mem.indexOf(u8, request, "GET /api/dashboard") != null) {
            const body = try self.handleDashboard();
            return RestApiResponse{
                .status = 200,
                .content_type = "text/html",
                .body = body,
            };
        }

        if (std.mem.indexOf(u8, request, "GET / ") != null) {
            const body = try self.handleDashboard();
            return RestApiResponse{
                .status = 200,
                .content_type = "text/html",
                .body = body,
            };
        }

        // 404 Not Found
        return RestApiResponse{
            .status = 404,
            .content_type = "text/plain",
            .body = "Not Found",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "UDP Discovery init and cleanup" {
    const allocator = std.testing.allocator;
    var udp = try UDPDiscovery.init(UDP_DISCOVERY_PORT, allocator);
    defer udp.deinit();

    try std.testing.expect(udp.port == UDP_DISCOVERY_PORT);
}

test "TCP JobServer init and cleanup" {
    const allocator = std.testing.allocator;
    var server = try TCPJobServer.init(TCP_JOB_PORT, allocator);
    defer server.deinit();

    try std.testing.expect(server.port == TCP_JOB_PORT);
}

test "NodeTier multipliers" {
    try std.testing.expectEqual(TIER_MULTIPLIER_FREE, NodeTier.free.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_STAKER, NodeTier.staker.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_POWER, NodeTier.power.getMultiplier());
    try std.testing.expectEqual(TIER_MULTIPLIER_WHALE, NodeTier.whale.getMultiplier());
}

test "ClusterManager init and cleanup" {
    const allocator = std.testing.allocator;
    var cluster = try ClusterManager.init("test-cluster", "test-node", .coordinator, .free, allocator);
    defer cluster.deinit();

    try std.testing.expectEqualStrings("test-cluster", cluster.cluster_id);
    try std.testing.expectEqualStrings("test-node", cluster.node_id);
}

test "ClusterNode reward calculation" {
    const node = ClusterNode{
        .id = "test",
        .address = SocketAddr{ .ip = "127.0.0.1", .port = 9334 },
        .role = .worker,
        .tier = .staker,
        .status = .online,
        .operations_count = 0,
        .earned_tri = 0.0,
        .pending_tri = 0.0,
        .last_heartbeat = 0,
    };

    const reward = node.calculateReward(0.001);
    try std.testing.expectApproxEqAbs(0.0015, reward, 0.0001);
}
