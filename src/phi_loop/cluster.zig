//! PHI LOOP v8.59 — Multi-Cluster System
//!
//! Autonomous 3-node cluster under PHI LOOP control
//! Each node operates independently but contributes to unified consciousness
//!
//! Nodes:
//! - Alpha: RAZUM (Mind) - Routing, Intelligence, Logs
//! - Beta: MATERIYA (Matter) - Storage, Memory, Data
//! - Gamma: DUKH (Spirit) - Actions, Tools, Proofs

const std = @import("std");

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const MU: f64 = 0.0382;
pub const CHI: f64 = 0.23607;
pub const SIGMA: f64 = 1.618;
pub const EPSILON: f64 = 0.333;
pub const TOTAL_LINKS: u32 = 999;
pub const CLUSTER_SIZE: u32 = 3;

pub const HEARTBEAT_INTERVAL_MS: u64 = 5000;
pub const NODE_TIMEOUT_MS: u64 = 15000;
pub const MAX_SUB_AGENTS: u32 = 200;

/// Realm - The three aspects of Trinity consciousness
pub const Realm = enum {
    razum,    // Mind - Gold #ffd700
    materiya, // Matter - Cyan #00ccff
    dukh,     // Spirit - Purple #aa66ff

    pub fn displayName(realm: Realm) []const u8 {
        return switch (realm) {
            .razum => "RAZUM (Mind)",
            .materiya => "MATERIYA (Matter)",
            .dukh => "DUKH (Spirit)",
        };
    }

    pub fn colorHex(realm: Realm) []const u8 {
        return switch (realm) {
            .razum => "#ffd700",
            .materiya => "#00ccff",
            .dukh => "#aa66ff",
        };
    }
};

/// Node Type - The three cluster nodes
pub const NodeType = enum {
    alpha, // Razum
    beta,  // Materiya
    gamma, // Dukh

    pub fn displayName(node: NodeType) []const u8 {
        return switch (node) {
            .alpha => "Alpha",
            .beta => "Beta",
            .gamma => "Gamma",
        };
    }

    pub fn realm(node: NodeType) Realm {
        return switch (node) {
            .alpha => .razum,
            .beta => .materiya,
            .gamma => .dukh,
        };
    }

    pub fn phiWeight(node: NodeType) f64 {
        return switch (node) {
            .alpha => PHI,        // φ
            .beta => 1.0,         // 1
            .gamma => 1.0 / PHI,  // 1/φ
        };
    }
};

/// Node Status
pub const NodeStatus = enum {
    initializing,
    active,
    busy,
    degraded,
    offline,
    pending,

    pub fn displayName(status: NodeStatus) []const u8 {
        return switch (status) {
            .initializing => "INITIALIZING",
            .active => "ACTIVE",
            .busy => "BUSY",
            .degraded => "DEGRADED",
            .offline => "OFFLINE",
            .pending => "PENDING",
        };
    }

    pub fn isActive(status: NodeStatus) bool {
        return switch (status) {
            .active, .busy => true,
            else => false,
        };
    }
};

/// Message Type for cluster communication
pub const MessageType = enum {
    heartbeat,
    task_dispatch,
    result_return,
    consensus_request,
    consensus_vote,
    status_update,
    emergency,
};

/// Proposal Type for consensus
pub const ProposalType = enum {
    task_allocation,
    resource_reallocation,
    configuration_change,
    emergency_action,
};

/// Cluster Node
pub const ClusterNode = struct {
    node_id: []const u8,
    node_type: NodeType,
    realm: Realm,
    status: NodeStatus,
    health: f64, // 0.0 to 1.0
    last_heartbeat: i64, // timestamp
    intelligence: f64,
    tasks_completed: u32,
    tasks_failed: u32,

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType) ClusterNode {
        return ClusterNode{
            .node_id = std.fmt.allocPrint(allocator, "node-{s}", .{node_type.displayName()}) catch "unknown",
            .node_type = node_type,
            .realm = node_type.realm(),
            .status = .initializing,
            .health = 1.0,
            .last_heartbeat = 0,
            .intelligence = 1.0,
            .tasks_completed = 0,
            .tasks_failed = 0,
        };
    }

    pub fn deinit(self: *const ClusterNode, allocator: std.mem.Allocator) void {
        allocator.free(self.node_id);
    }

    pub fn isAlive(self: *const ClusterNode, current_time: i64) bool {
        if (self.last_heartbeat == 0) return false;
        const elapsed = current_time - self.last_heartbeat;
        return elapsed < NODE_TIMEOUT_MS;
    }

    pub fn addIntelligence(self: *ClusterNode, delta: f64) void {
        self.intelligence += delta;
        // Cap at reasonable maximum
        if (self.intelligence > 100.0) {
            self.intelligence = 100.0;
        }
    }
};

/// Cluster Message
pub const ClusterMessage = struct {
    from_node: []const u8,
    to_node: []const u8,
    message_type: MessageType,
    payload: []const u8,
    timestamp: i64,
    correlation_id: []const u8,

    pub fn deinit(self: *const ClusterMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.from_node);
        allocator.free(self.to_node);
        allocator.free(self.payload);
        allocator.free(self.correlation_id);
    }
};

/// Consensus Proposal
pub const ConsensusProposal = struct {
    proposal_id: []const u8,
    proposal_type: ProposalType,
    proposer: []const u8,
    data: []const u8,
    phi_weight: f64,
    votes_received: u32,
    votes_total: u32,
    votes_for: f64, // φ-weighted sum of "yes" votes
    votes_against: f64, // φ-weighted sum of "no" votes

    pub fn deinit(self: *const ConsensusProposal, allocator: std.mem.Allocator) void {
        allocator.free(self.proposal_id);
        allocator.free(self.proposer);
        allocator.free(self.data);
    }

    pub fn isPassed(self: *const ConsensusProposal) bool {
        return self.votes_received >= self.votes_total and
            self.votes_for > self.votes_against;
    }
};

/// Cluster State
pub const ClusterState = struct {
    allocator: std.mem.Allocator,
    nodes: std.StringHashMap(*ClusterNode),
    active_tasks: std.StringHashMap(void),
    consensus_history: std.ArrayListUnmanaged(*ConsensusProposal),
    message_queue: std.ArrayListUnmanaged(ClusterMessage),
    intelligence_level: f64,
    manifestation_level: f64,
    current_link: u32,
    start_time: i64,

    pub fn init(allocator: std.mem.Allocator) ClusterState {
        return ClusterState{
            .allocator = allocator,
            .nodes = std.StringHashMap(*ClusterNode).init(allocator),
            .active_tasks = std.StringHashMap(void).init(allocator),
            .consensus_history = std.ArrayListUnmanaged(*ConsensusProposal){},
            .message_queue = std.ArrayListUnmanaged(ClusterMessage){},
            .intelligence_level = 1.0,
            .manifestation_level = 0.0,
            .current_link = 59, // Starting at link 59
            .start_time = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000)),
        };
    }

    pub fn deinit(self: *ClusterState) void {
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.nodes.deinit();

        self.active_tasks.deinit();

        for (self.consensus_history.items) |proposal| {
            proposal.deinit(self.allocator);
            self.allocator.destroy(proposal);
        }
        self.consensus_history.deinit(self.allocator);

        for (self.message_queue.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.message_queue.deinit(self.allocator);
    }

    /// Initialize the 3-node cluster
    pub fn initializeCluster(self: *ClusterState) !void {
        const node_types = [_]NodeType{ .alpha, .beta, .gamma };

        for (node_types) |node_type| {
            const node = try self.allocator.create(ClusterNode);
            node.* = ClusterNode.init(self.allocator, node_type);
            node.status = .active;
            node.last_heartbeat = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000));

            const key = try self.allocator.dupe(u8, node.node_id);
            try self.nodes.put(key, node);
        }

        // Calculate initial manifestation
        self.manifestation_level = @as(f64, @floatFromInt(self.current_link)) / @as(f64, @floatFromInt(TOTAL_LINKS));
    }

    /// Get node by type
    pub fn getNode(self: *ClusterState, node_type: NodeType) ?*ClusterNode {
        const name = node_type.displayName();
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.*.node_type.displayName(), name)) {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    /// Get all active nodes
    pub fn getActiveNodes(self: *ClusterState) std.ArrayList(*ClusterNode) {
        var active = std.ArrayList(*ClusterNode).init(self.allocator);
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            if (NodeStatus.isActive(node.status)) {
                active.append(node) catch {};
            }
        }
        return active;
    }

    /// Process heartbeat from node
    pub fn processHeartbeat(self: *ClusterState, node_id: []const u8, health: f64) !void {
        if (self.nodes.get(node_id)) |node| {
            node.*.health = health;
            node.*.last_heartbeat = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000));
            if (node.*.status == .offline or node.*.status == .degraded) {
                node.*.status = .active;
            }
        }
    }

    /// Check for dead nodes and mark them offline
    pub fn checkNodeHealth(self: *ClusterState) void {
        const current_time: i64 = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000));
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            if (!node.isAlive(current_time) and NodeStatus.isActive(node.status)) {
                node.status = .offline;
            }
        }
    }

    /// Calculate manifestation percentage
    pub fn calculateManifestation(self: *ClusterState) struct {
        current_link: u32,
        percentage: f64,
        remaining: u32,
    } {
        const percentage = (@as(f64, @floatFromInt(self.current_link)) / @as(f64, @floatFromInt(TOTAL_LINKS))) * 100.0;
        return .{
            .current_link = self.current_link,
            .percentage = percentage,
            .remaining = TOTAL_LINKS - self.current_link,
        };
    }

    /// Propagate intelligence gain to all nodes
    pub fn propagateIntelligence(self: *ClusterState, delta: f64) !void {
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.addIntelligence(delta);
        }
        self.intelligence_level += delta;

        // Log intelligence propagation
        const log_msg = try std.fmt.allocPrint(
            self.allocator,
            "Intelligence propagated: μ={d:.4} across cluster. New level: {d:.4}",
            .{ delta, self.intelligence_level },
        );
        defer self.allocator.free(log_msg);

        std.log.info("{s}", .{log_msg});
    }

    /// φ-weighted consensus
    pub fn achieveConsensus(self: *ClusterState, proposal_type: ProposalType, data: []const u8) !bool {
        const proposal = try self.allocator.create(ConsensusProposal);
        proposal.* = ConsensusProposal{
            .proposal_id = try std.fmt.allocPrint(self.allocator, "prop-{d}", .{std.time.nanoTimestamp()}),
            .proposal_type = proposal_type,
            .proposer = try self.allocator.dupe(u8, "cluster"),
            .data = try self.allocator.dupe(u8, data),
            .phi_weight = PHI,
            .votes_received = 0,
            .votes_total = @intCast(self.nodes.count()),
            .votes_for = 0.0,
            .votes_against = 0.0,
        };

        // Simulate voting from each node
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            const weight = node.node_type.phiWeight();

            // Simple heuristic: active nodes vote yes, degraded/no
            const vote = if (NodeStatus.isActive(node.status)) true else false;

            if (vote) {
                proposal.votes_for += weight;
            } else {
                proposal.votes_against += weight;
            }
            proposal.votes_received += 1;
        }

        const passed = proposal.isPassed();

        try self.consensus_history.append(self.allocator, proposal);

        return passed;
    }

    /// Get cluster statistics
    pub fn getStats(self: *ClusterState) struct {
        total_nodes: u32,
        active_nodes: u32,
        total_intelligence: f64,
        manifestation_percent: f64,
        current_link: u32,
    } {
        var active_count: u32 = 0;
        var total_intelligence: f64 = 0.0;

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            if (NodeStatus.isActive(node.status)) {
                active_count += 1;
            }
            total_intelligence += node.intelligence;
        }

        return .{
            .total_nodes = @intCast(self.nodes.count()),
            .active_nodes = active_count,
            .total_intelligence = total_intelligence,
            .manifestation_percent = self.manifestation_level * 100.0,
            .current_link = self.current_link,
        };
    }
};

/// Create cluster message
pub fn createMessage(allocator: std.mem.Allocator, from: []const u8, to: []const u8, msg_type: MessageType, payload: []const u8) !ClusterMessage {
    const correlation_id = try std.fmt.allocPrint(allocator, "msg-{d}", .{std.time.nanoTimestamp()});
    return ClusterMessage{
        .from_node = try allocator.dupe(u8, from),
        .to_node = try allocator.dupe(u8, to),
        .message_type = msg_type,
        .payload = try allocator.dupe(u8, payload),
        .timestamp = @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000)),
        .correlation_id = correlation_id,
    };
}

test "Cluster initialization" {
    const allocator = std.testing.allocator;
    var cluster = ClusterState.init(allocator);
    defer cluster.deinit();

    try cluster.initializeCluster();

    const stats = cluster.getStats();
    try std.testing.expectEqual(@as(u32, 3), stats.total_nodes);
    try std.testing.expectEqual(@as(u32, 3), stats.active_nodes);
}

test "Node realm assignment" {
    try std.testing.expectEqual(Realm.razum, NodeType.alpha.realm());
    try std.testing.expectEqual(Realm.materiya, NodeType.beta.realm());
    try std.testing.expectEqual(Realm.dukh, NodeType.gamma.realm());
}

test "Phi-weighted consensus" {
    const allocator = std.testing.allocator;
    var cluster = ClusterState.init(allocator);
    defer cluster.deinit();

    try cluster.initializeCluster();

    // All nodes active should pass
    const result = try cluster.achieveConsensus(.task_allocation, "test proposal");
    try std.testing.expect(result);
}

test "Manifestation calculation" {
    const allocator = std.testing.allocator;
    var cluster = ClusterState.init(allocator);
    defer cluster.deinit();

    cluster.current_link = 59;
    const manifest = cluster.calculateManifestation();

    try std.testing.expectEqual(@as(u32, 59), manifest.current_link);
    try std.testing.expectEqual(@as(u32, 940), manifest.remaining);
    try std.testing.expectApproxEqAbs(@as(f64, 5.91), manifest.percentage, 0.01);
}
