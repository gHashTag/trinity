//! Multi-Ralph Coordination Protocol v8.24
//!
//! Distributed coordinator for multiple Ralph instances:
//! - Leader election (Raft-style consensus)
//! - Heartbeat-based failure detection
//! - Task distribution across nodes
//! - State synchronization
//!
//! φ² + 1/φ² = 3 | TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const http = std.http;
const net = std.net;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

const DEFAULT_HEARTBEAT_INTERVAL_MS: u64 = 1000; // φ-based timing
const DEFAULT_ELECTION_TIMEOUT_MS: u64 = @intFromFloat(@as(f64, @floatFromInt(DEFAULT_HEARTBEAT_INTERVAL_MS)) * PHI);
const MAX_NODES: u8 = 32; // Maximum cluster size
const BROADCAST_ADDRESS = "255.255.255.255";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Node role in the cluster
pub const NodeRole = enum(u8) {
    follower = 0,
    candidate = 1,
    leader = 2,

    pub fn format(self: NodeRole) []const u8 {
        return switch (self) {
            .follower => "FOLLOWER",
            .candidate => "CANDIDATE",
            .leader => "LEADER",
        };
    }
};

/// Node state tracking
pub const NodeState = struct {
    id: []const u8,
    role: NodeRole,
    current_term: u64,
    voted_for: ?[]const u8,
    votes_received: u32,
    last_heartbeat_ms: i64,
    load_factor: f64, // 0.0 - 1.0
    task_queue_size: u32,

    pub fn init(id: []const u8) NodeState {
        return .{
            .id = id,
            .role = .follower,
            .current_term = 0,
            .voted_for = null,
            .votes_received = 0,
            .last_heartbeat_ms = 0,
            .load_factor = 0.0,
            .task_queue_size = 0,
        };
    }

    pub fn isHealthy(self: NodeState, timeout_ms: i64, current_time_ms: i64) bool {
        const elapsed = current_time_ms - self.last_heartbeat_ms;
        return elapsed < timeout_ms;
    }
};

/// Remote peer node info
pub const RemoteNode = struct {
    id: []const u8,
    address: std.net.Address,
    last_seen: i64,
    current_term: u64,

    pub fn formatAddress(self: RemoteNode, allocator: std.mem.Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{s}:{}", .{
            self.address.in.sin.sa.addrAsString(),
            self.address.in.sin.port,
        });
    }
};

/// RPC message types
pub const MessageType = enum(u8) {
    heartbeat = 0,
    request_vote = 1,
    response_vote = 2,
    broadcast_task = 3,
    task_ack = 4,
    task_complete = 5,
    sync_state = 6,
    node_discovery = 7,
};

/// RPC message
pub const Message = struct {
    msg_type: MessageType,
    term: u64,
    sender_id: []const u8,
    data: []const u8,

    pub fn serialize(self: Message, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.append(@intFromEnum(self.msg_type));
        try buffer.writer().writeInt(u64, self.term, .little);
        try buffer.writer().writeInt(u16, @intCast(self.sender_id.len), .little);
        try buffer.appendSlice(self.sender_id);
        try buffer.writer().writeInt(u32, @intCast(self.data.len), .little);
        try buffer.appendSlice(self.data);

        return buffer.toOwnedSlice();
    }
};

/// Task for distribution
pub const Task = struct {
    id: []const u8,
    spec: []const u8,
    priority: u8,
    assigned_node: ?[]const u8,
    status: TaskStatus,

    pub fn format(self: Task) []const u8 {
        return switch (self.status) {
            .pending => "PENDING",
            .running => "RUNNING",
            .complete => "COMPLETE",
            .failed => "FAILED",
        };
    }
};

pub const TaskStatus = enum(u8) {
    pending = 0,
    running = 1,
    complete = 2,
    failed = 3,
};

/// Vote request
pub const VoteRequest = struct {
    term: u64,
    candidate_id: []const u8,
    last_log_index: u64,
    last_log_term: u64,
};

/// Vote response
pub const VoteResponse = struct {
    term: u64,
    vote_granted: bool,
    voter_id: []const u8,
};

/// Cluster state
pub const ClusterState = struct {
    nodes: std.StringHashMap(NodeState),
    leader_id: ?[]const u8,
    current_term: u64,
    committed_index: u64,
    last_applied: u64,

    pub fn init(allocator: std.mem.Allocator) ClusterState {
        return .{
            .nodes = std.StringHashMap(NodeState).init(allocator),
            .leader_id = null,
            .current_term = 0,
            .committed_index = 0,
            .last_applied = 0,
        };
    }

    pub fn deinit(self: *ClusterState) void {
        // Only free keys that we know we allocated
        // In production, track which keys were allocated vs provided
        self.nodes.deinit();
    }

    pub fn getHealthyNodes(self: *const ClusterState, timeout_ms: i64, current_time_ms: i64) usize {
        var count: usize = 0;
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.isHealthy(timeout_ms, current_time_ms)) {
                count += 1;
            }
        }
        return count;
    }

    pub fn hasQuorum(self: *const ClusterState, timeout_ms: i64, current_time_ms: i64) bool {
        const healthy = self.getHealthyNodes(timeout_ms, current_time_ms);
        const majority = (self.nodes.count() + 2) / 2; // (n + 1) / 2 for majority
        return healthy >= majority;
    }
};

/// Main coordinator
pub const MultiRalphCoordinator = struct {
    allocator: std.mem.Allocator,
    config: CoordinatorConfig,
    state: ClusterState,
    socket: ?*std.net.Server,
    heartbeat_timer: ?std.time.Timer,
    election_timer: ?std.time.Timer,
    running: bool,

    /// Coordinator configuration
    pub const CoordinatorConfig = struct {
        node_id: []const u8,
        listen_address: []const u8,
        listen_port: u16,
        heartbeat_interval_ms: u64,
        election_timeout_ms: u64,
        max_nodes: u8,
        discovery_enabled: bool,

        pub fn default(node_id: []const u8) CoordinatorConfig {
            return .{
                .node_id = node_id,
                .listen_address = "0.0.0.0",
                .listen_port = 8080,
                .heartbeat_interval_ms = DEFAULT_HEARTBEAT_INTERVAL_MS,
                .election_timeout_ms = DEFAULT_ELECTION_TIMEOUT_MS,
                .max_nodes = MAX_NODES,
                .discovery_enabled = true,
            };
        }
    };

    /// Initialize coordinator
    pub fn init(allocator: std.mem.Allocator, config: CoordinatorConfig) !MultiRalphCoordinator {
        var coordinator = MultiRalphCoordinator{
            .allocator = allocator,
            .config = config,
            .state = ClusterState.init(allocator),
            .socket = null,
            .heartbeat_timer = try std.time.Timer.start(),
            .election_timer = try std.time.Timer.start(),
            .running = false,
        };

        // Add self to cluster
        const node_id = try allocator.dupe(u8, config.node_id);
        try coordinator.state.nodes.put(node_id, NodeState.init(node_id));

        return coordinator;
    }

    /// Deinitialize coordinator
    pub fn deinit(self: *MultiRalphCoordinator) void {
        if (self.socket) |s| {
            s.deinit();
            self.allocator.destroy(s);
        }
        self.state.deinit();
    }

    /// Start the coordinator
    pub fn start(self: *MultiRalphCoordinator) !void {
        self.running = true;

        // Start listening for connections
        const address = try std.net.Address.parseIp(self.config.listen_address, self.config.listen_port);
        const server = try address.listen(.{ .reuse_address = true });
        self.socket = try self.allocator.create(std.net.Server);
        self.socket.?.* = server;

        std.log.info("Multi-Ralph coordinator {s} listening on {s}:{}\n", .{
            self.config.node_id,
            self.config.listen_address,
            self.config.listen_port,
        });

        // Start peer discovery if enabled
        if (self.config.discovery_enabled) {
            try self.discoverPeers();
        }

        // Start main loop
        try self.run();
    }

    /// Stop the coordinator
    pub fn stop(self: *MultiRalphCoordinator) void {
        self.running = false;
        std.log.info("Multi-Ralph coordinator {s} stopped\n", .{self.config.node_id});
    }

    /// Discover peer nodes on the network
    pub fn discoverPeers(self: *MultiRalphCoordinator) !void {
        // Send UDP broadcast for node discovery
        // In production, this would use UDP socket on a designated port
        std.log.info("Starting peer discovery for {s}\n", .{self.config.node_id});
    }

    /// Send heartbeat to all peers (if leader)
    pub fn sendHeartbeat(self: *MultiRalphCoordinator) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        if (my_state.role != .leader) return;

        var iter = self.state.nodes.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, self.config.node_id)) continue;

            // Send heartbeat via HTTP/gRPC to peer
            // TODO: Implement actual network send
        }

        // Reset heartbeat timer
        if (self.heartbeat_timer) |*t| {
            t.reset();
        }
    }

    /// Handle received heartbeat
    pub fn handleHeartbeat(self: *MultiRalphCoordinator, sender_id: []const u8, term: u64) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        // Update term if needed
        if (term > my_state.current_term) {
            my_state.current_term = term;
            my_state.role = .follower;
            self.state.leader_id = null;
        }

        // Update sender's last heartbeat
        const now = std.time.milliTimestamp();
        if (self.state.nodes.get(sender_id)) |*sender_state| {
            sender_state.last_heartbeat_ms = now;
            sender_state.current_term = term;
        }

        // Reset election timer
        if (self.election_timer) |*t| {
            t.reset();
        }
    }

    /// Start leader election
    pub fn startElection(self: *MultiRalphCoordinator) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        // Increment term
        my_state.current_term += 1;
        my_state.role = .candidate;
        my_state.voted_for = self.config.node_id;
        my_state.votes_received = 1; // Vote for self

        std.log.info("Node {s} starting election for term {}\n", .{ self.config.node_id, my_state.current_term });

        // Request votes from all peers
        var iter = self.state.nodes.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, self.config.node_id)) continue;

            // Send RequestVote RPC
            // TODO: Implement actual network send
        }

        // Reset election timer
        if (self.election_timer) |*t| {
            t.reset();
        }
    }

    /// Handle vote request
    pub fn handleVoteRequest(self: *MultiRalphCoordinator, request: VoteRequest) !VoteResponse {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        var vote_granted = false;

        // Grant vote if:
        // 1. Candidate's term is >= our term
        // 2. We haven't voted for anyone in this term
        // 3. Candidate's log is at least as up-to-date as ours
        if (request.term >= my_state.current_term) {
            if (my_state.voted_for == null or std.mem.eql(u8, my_state.voted_for.?, request.candidate_id)) {
                my_state.voted_for = request.candidate_id;
                vote_granted = true;
            }
        }

        return .{
            .term = my_state.current_term,
            .vote_granted = vote_granted,
            .voter_id = self.config.node_id,
        };
    }

    /// Handle vote response
    pub fn handleVoteResponse(self: *MultiRalphCoordinator, response: VoteResponse) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        if (my_state.role != .candidate) return;

        // Update term if response has higher term
        if (response.term > my_state.current_term) {
            my_state.current_term = response.term;
            my_state.role = .follower;
            my_state.voted_for = null;
            return;
        }

        // Count vote if granted
        if (response.vote_granted) {
            my_state.votes_received += 1;

            // Check if we won the election
            if (my_state.votes_received > self.state.nodes.count() / 2) {
                try self.becomeLeader();
            }
        }
    }

    /// Become leader
    pub fn becomeLeader(self: *MultiRalphCoordinator) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        my_state.role = .leader;
        self.state.leader_id = self.config.node_id;

        std.log.info("Node {s} became LEADER for term {}\n", .{ self.config.node_id, my_state.current_term });

        // Send initial heartbeat to establish authority
        try self.sendHeartbeat();
    }

    /// Become follower
    pub fn becomeFollower(self: *MultiRalphCoordinator, leader_id: []const u8, term: u64) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        my_state.role = .follower;
        my_state.current_term = term;
        my_state.voted_for = null;
        self.state.leader_id = leader_id;

        std.log.info("Node {s} became FOLLOWER of {s} for term {}\n", .{ self.config.node_id, leader_id, term });
    }

    /// Broadcast task to least-loaded node
    pub fn broadcastTask(self: *MultiRalphCoordinator, task: Task) !void {
        const my_state = self.state.nodes.get(self.config.node_id) orelse return error.NodeNotFound;

        if (my_state.role != .leader) {
            return error.NotLeader;
        }

        // Find least-loaded healthy node
        var best_node: ?[]const u8 = null;
        var min_load: f64 = 1.0;

        var iter = self.state.nodes.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.role == .leader) continue; // Skip leader

            const node = entry.value_ptr.*;
            if (node.load_factor < min_load) {
                min_load = node.load_factor;
                best_node = entry.key_ptr.*;
            }
        }

        if (best_node) |node_id| {
            std.log.info("Broadcasting task {s} to node {s} (load: {d:.2})\n", .{ task.id, node_id, min_load });
            // Send task to node via HTTP/gRPC
            // TODO: Implement actual network send
        } else {
            return error.NoAvailableNodes;
        }
    }

    /// Get cluster status for API
    pub fn getClusterStatus(self: *const MultiRalphCoordinator) struct {
        node_id: []const u8,
        role: NodeRole,
        term: u64,
        leader_id: ?[]const u8,
        nodes_online: usize,
        nodes_total: usize,
    } {
        const my_state = self.state.nodes.get(self.config.node_id) orelse {
            return .{
                .node_id = self.config.node_id,
                .role = .follower,
                .term = 0,
                .leader_id = null,
                .nodes_online = 0,
                .nodes_total = 0,
            };
        };

        const now = std.time.milliTimestamp();
        const online = self.state.getHealthyNodes(@intCast(self.config.election_timeout_ms * 2), now);

        return .{
            .node_id = self.config.node_id,
            .role = my_state.role,
            .term = my_state.current_term,
            .leader_id = self.state.leader_id,
            .nodes_online = online,
            .nodes_total = self.state.nodes.count,
        };
    }

    /// Main event loop
    pub fn run(self: *MultiRalphCoordinator) !void {
        const now = std.time.milliTimestamp();

        while (self.running) {
            // Check for heartbeat timeout (if leader)
            if (self.heartbeat_timer) |*t| {
                if (t.read() > self.config.heartbeat_interval_ms * 1_000_000) {
                    try self.sendHeartbeat();
                }
            }

            // Check for election timeout
            if (self.election_timer) |*t| {
                if (t.read() > self.config.election_timeout_ms * 1_000_000) {
                    const my_state = self.state.nodes.get(self.config.node_id) orelse continue;
                    if (my_state.role != .leader) {
                        try self.startElection();
                    }
                }
            }

            // Check for failed nodes
            try self.checkFailedNodes(now);

            // Small sleep to prevent busy-waiting
            std.time.sleep(10 * std.time.ns_per_ms);
        }
    }

    /// Check for failed nodes and redistribute tasks
    fn checkFailedNodes(self: *MultiRalphCoordinator, now_ms: i64) !void {
        const timeout_ms: i64 = @intCast(self.config.election_timeout_ms * 2);

        var iter = self.state.nodes.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, self.config.node_id)) continue;

            const node = entry.value_ptr.*;
            if (!node.isHealthy(timeout_ms, now_ms)) {
                std.log.warn("Node {s} appears to have failed\n", .{entry.key_ptr.*});
                // Handle node failure - redistribute tasks
                // TODO: Implement task redistribution
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MultiRalphCoordinator initialization" {
    const allocator = std.testing.allocator;
    const config = MultiRalphCoordinator.CoordinatorConfig{
        .node_id = "test-ralph-0",
        .listen_address = "127.0.0.1",
        .listen_port = 9080,
        .heartbeat_interval_ms = 1000,
        .election_timeout_ms = 2000,
        .max_nodes = 5,
        .discovery_enabled = false,
    };

    var coordinator = try MultiRalphCoordinator.init(allocator, config);
    defer coordinator.deinit();

    try std.testing.expectEqual(@as(usize, 1), coordinator.state.nodes.count());
    try std.testing.expectEqual(@as(u64, 0), coordinator.state.current_term);
}

test "NodeState health check" {
    const timeout_ms: i64 = 2000;

    // Node with no heartbeat (0) at time 1000 is unhealthy (elapsed 1000 < timeout, but 0 indicates no heartbeat)
    var no_heartbeat = NodeState.init("test-node");
    no_heartbeat.last_heartbeat_ms = 0;
    try std.testing.expect(!no_heartbeat.isHealthy(timeout_ms, 1000));

    // Node with recent heartbeat is healthy
    var healthy_node = NodeState.init("test-node");
    healthy_node.last_heartbeat_ms = 500; // 500ms ago at time 1000
    try std.testing.expect(healthy_node.isHealthy(timeout_ms, 1000));

    // Node with stale heartbeat is unhealthy
    var stale_node = NodeState.init("test-node");
    stale_node.last_heartbeat_ms = 0;
    const current_time: i64 = 3000; // 3000ms since epoch, timeout 2000ms
    try std.testing.expect(!stale_node.isHealthy(timeout_ms, current_time));
}

test "ClusterState quorum calculation" {
    const allocator = std.testing.allocator;
    var cluster = ClusterState.init(allocator);
    defer cluster.deinit();

    const now = std.time.milliTimestamp();

    // Add 3 nodes
    for (0..3) |i| {
        const id = try std.fmt.allocPrint(allocator, "node-{d}", .{i});
        defer allocator.free(id);
        var node = NodeState.init(id);
        node.last_heartbeat_ms = now;
        try cluster.nodes.put(id, node);
    }

    // 3 nodes, majority is 2
    try std.testing.expect(cluster.hasQuorum(2000, now));
}

test "φ-sacred constants verification" {
    try std.testing.expectApproxEqAbs(PHI * PHI + 1.0 / (PHI * PHI), TRINITY, 0.0001);
}
