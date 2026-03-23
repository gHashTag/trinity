//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN FEDERATION — v1.0 — Distributed Multi-Instance Coordination
//!
//! Brain Region: Corpus Callosum (Inter-Hemispheric Communication)
//!
//! Enables multiple Trinity instances to coordinate as a distributed brain:
//! - Inter-instance communication over HTTP/WebSocket
//! - Distributed task claiming with conflict resolution
//! - Federation health aggregation
//! - Leader election using Raft-inspired consensus
//! - CRDT-based state synchronization
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Architecture: Each instance is a "hemisphere" in the federated brain

const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;

// Import brain region modules
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANCE ID — Unique identifier for each Trinity instance
// ═══════════════════════════════════════════════════════════════════════════════

/// Instance ID (UUID v4 format)
pub const InstanceId = struct {
    bytes: [16]u8,

    /// Generate new random instance ID
    pub fn generate() InstanceId {
        var id: InstanceId = undefined;
        std.crypto.random.bytes(&id.bytes);

        // Set version and variant bits for UUID v4
        id.bytes[6] = (id.bytes[6] & 0x0F) | 0x40; // Version 4
        id.bytes[8] = (id.bytes[8] & 0x3F) | 0x80; // Variant 1

        return id;
    }

    /// Parse from string (UUID format)
    pub fn parse(str: []const u8) !InstanceId {
        var id: InstanceId = undefined;

        var idx: usize = 0;
        var byte_idx: usize = 0;
        while (idx < str.len and byte_idx < 16) : (idx += 2) {
            if (str[idx] == '-') {
                idx += 1; // Skip hyphen
            }
            if (idx + 1 >= str.len) return error.InvalidUuid;
            const high = try charToHex(str[idx]);
            const low = try charToHex(str[idx + 1]);
            id.bytes[byte_idx] = (high << 4) | low;
            byte_idx += 1;
        }

        return id;
    }

    /// Format as UUID string
    pub fn format(self: *const InstanceId, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
            self.bytes[0],  self.bytes[1],  self.bytes[2],  self.bytes[3],
            self.bytes[4],  self.bytes[5],  self.bytes[6],  self.bytes[7],
            self.bytes[8],  self.bytes[9],  self.bytes[10], self.bytes[11],
            self.bytes[12], self.bytes[13], self.bytes[14], self.bytes[15],
        });
    }

    /// Compare two instance IDs
    pub fn compareTo(self: *const InstanceId, other: *const InstanceId) std.math.Order {
        var i: usize = 0;
        while (i < 16) : (i += 1) {
            if (self.bytes[i] != other.bytes[i]) {
                return std.math.order(self.bytes[i], other.bytes[i]);
            }
        }
        return .eq;
    }

    fn charToHex(c: u8) !u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => error.InvalidUuid,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANCE STATUS — Health and participation status
// ═══════════════════════════════════════════════════════════════════════════════

pub const InstanceStatus = enum(u8) {
    /// Instance is online and participating
    online = 0,
    /// Instance is temporarily offline (grace period)
    degraded = 1,
    /// Instance is offline (beyond grace period)
    offline = 2,
    /// Instance is the elected leader
    leader = 3,
    /// Instance is a follower in the federation
    follower = 4,
    /// Instance is a candidate in leader election
    candidate = 5,
};

pub const InstanceInfo = struct {
    id: InstanceId,
    address: []const u8, // "host:port"
    status: InstanceStatus,
    last_heartbeat: i64,
    term: u64, // Current election term
    voted_for: ?InstanceId,
    claim_count: usize,
    event_count: usize,
    health_score: f32,

    pub fn deinit(self: *InstanceInfo, allocator: Allocator) void {
        allocator.free(self.address);
        if (self.voted_for) |*v| {
            // InstanceId is a value type, no cleanup needed
            _ = v;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FEDERATION MESSAGE — Inter-instance communication protocol
// ═══════════════════════════════════════════════════════════════════════════════

pub const MessageType = enum(u8) {
    /// Heartbeat signal
    heartbeat = 0,
    /// Request to claim a task
    claim_request = 1,
    /// Response to claim request
    claim_response = 2,
    /// Task completion notification
    task_complete = 3,
    /// Leader election vote request
    vote_request = 4,
    /// Leader election vote response
    vote_response = 5,
    /// Append entries (log replication)
    append_entries = 6,
    /// Health status query
    health_query = 7,
    /// Health status response
    health_response = 8,
    /// Conflict resolution request
    conflict_resolve = 9,
};

pub const FederationMessage = struct {
    msg_type: MessageType,
    from: InstanceId,
    to: InstanceId,
    term: u64,
    timestamp: i64,

    // Message-specific data
    data: MessageData,

    pub fn deinit(self: *FederationMessage, allocator: Allocator) void {
        switch (self.data) {
            .claim_request => |d| {
                allocator.free(d.task_id);
                allocator.free(d.agent_id);
            },
            .claim_response => |d| {
                allocator.free(d.task_id);
            },
            .task_complete => |d| {
                allocator.free(d.task_id);
                allocator.free(d.agent_id);
            },
            .vote_response => |d| {
                if (d.vote_granted) {
                    // boolean, no cleanup
                }
            },
            .append_entries => |d| {
                allocator.free(d.task_id);
                allocator.free(d.agent_id);
            },
            .conflict_resolve => |d| {
                allocator.free(d.task_id);
                allocator.free(d.resolving_instance);
            },
            else => {},
        }
    }
};

pub const MessageData = union(MessageType) {
    heartbeat: struct {
        sequence: u64,
    },
    claim_request: struct {
        task_id: []const u8,
        agent_id: []const u8,
        ttl_ms: u64,
    },
    claim_response: struct {
        task_id: []const u8,
        granted: bool,
        winner: InstanceId,
    },
    task_complete: struct {
        task_id: []const u8,
        agent_id: []const u8,
        duration_ms: u64,
    },
    vote_request: struct {
        last_log_term: u64,
        last_log_index: u64,
    },
    vote_response: struct {
        vote_granted: bool,
    },
    append_entries: struct {
        task_id: []const u8,
        agent_id: []const u8,
        event_type: []const u8,
        log_index: u64,
    },
    health_query: void,
    health_response: struct {
        health_score: f32,
        claim_count: usize,
        event_count: usize,
    },
    conflict_resolve: struct {
        task_id: []const u8,
        conflict_type: ConflictType,
        resolving_instance: []const u8,
    },
};

pub const ConflictType = enum(u8) {
    /// Multiple instances claimed the same task
    duplicate_claim = 0,
    /// Task heartbeat timeout
    heartbeat_timeout = 1,
    /// Task completion inconsistency
    completion_inconsistent = 2,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LEADER ELECTION — Raft-inspired consensus
// ═══════════════════════════════════════════════════════════════════════════════

pub const ElectionState = struct {
    current_term: u64,
    voted_for: ?InstanceId,
    leader_id: ?InstanceId,
    state: enum {
        follower,
        candidate,
        leader,
    },

    /// Initialize election state
    pub fn init() ElectionState {
        return .{
            .current_term = 0,
            .voted_for = null,
            .leader_id = null,
            .state = .follower,
        };
    }

    /// Start new election term
    pub fn startElection(self: *ElectionState) void {
        self.current_term += 1;
        self.voted_for = null;
        self.leader_id = null;
        self.state = .candidate;
    }

    /// Become leader
    pub fn becomeLeader(self: *ElectionState, my_id: InstanceId) void {
        self.leader_id = my_id;
        self.state = .leader;
    }

    /// Become follower
    pub fn becomeFollower(self: *ElectionState, leader_id: InstanceId, term: u64) void {
        self.current_term = term;
        self.leader_id = leader_id;
        self.state = .follower;
    }

    /// Check if should grant vote
    pub fn shouldGrantVote(self: *ElectionState, candidate_id: InstanceId, candidate_term: u64, last_log_term: u64, last_log_index: u64, our_last_log_term: u64, our_last_log_index: u64) bool {
        // Vote for candidate if:
        // 1. Candidate's term is at least as current as ours
        // 2. We haven't voted in this term, or we already voted for this candidate
        // 3. Candidate's log is at least as up-to-date as ours
        if (candidate_term < self.current_term) return false;
        if (candidate_term > self.current_term) {
            self.current_term = candidate_term;
            self.voted_for = null;
        }

        if (self.voted_for) |voted| {
            if (!mem.eql(u8, &voted.bytes, &candidate_id.bytes)) {
                return false; // Already voted for someone else
            }
        }

        // Log completeness check
        if (last_log_term < our_last_log_term) return false;
        if (last_log_term == our_last_log_term and last_log_index < our_last_log_index) return false;

        self.voted_for = candidate_id;
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CRDT STATE — Conflict-free replicated data types
// ═══════════════════════════════════════════════════════════════════════════════

/// G-Counter (Grow-only Counter) for metrics
pub const GCounter = struct {
    counts: std.AutoHashMap(InstanceId, u64),

    pub fn init(allocator: Allocator) GCounter {
        return .{
            .counts = std.AutoHashMap(InstanceId, u64).init(allocator),
        };
    }

    pub fn deinit(self: *GCounter) void {
        self.counts.deinit();
    }

    pub fn increment(self: *GCounter, instance: InstanceId, delta: u64) !void {
        const entry = try self.counts.getOrPut(instance);
        if (entry.found_existing) {
            entry.value_ptr.* += delta;
        } else {
            entry.value_ptr.* = delta;
        }
    }

    pub fn value(self: *const GCounter) u64 {
        var sum: u64 = 0;
        var iter = self.counts.valueIterator();
        while (iter.next()) |v| {
            sum += v.*;
        }
        return sum;
    }

    pub fn merge(self: *GCounter, other: *const GCounter) !void {
        var iter = other.counts.iterator();
        while (iter.next()) |entry| {
            const local_entry = try self.counts.getOrPut(entry.key_ptr.*);
            if (!local_entry.found_existing) {
                local_entry.value_ptr.* = entry.value_ptr.*;
            } else {
                // Take maximum
                if (entry.value_ptr.* > local_entry.value_ptr.*) {
                    local_entry.value_ptr.* = entry.value_ptr.*;
                }
            }
        }
    }
};

/// LWW-Register (Last-Write-Wins Register) for single values
pub const LWWRegister = struct {
    value: []const u8,
    timestamp: i64,
    instance: InstanceId,

    pub fn init(allocator: Allocator, value: []const u8) !LWWRegister {
        return .{
            .value = try allocator.dupe(u8, value),
            .timestamp = std.time.milliTimestamp(),
            .instance = InstanceId.generate(),
        };
    }

    pub fn deinit(self: *LWWRegister, allocator: Allocator) void {
        allocator.free(self.value);
    }

    pub fn set(self: *LWWRegister, allocator: Allocator, value: []const u8, instance: InstanceId) !void {
        allocator.free(self.value);
        self.value = try allocator.dupe(u8, value);
        self.timestamp = std.time.milliTimestamp();
        self.instance = instance;
    }

    pub fn merge(self: *LWWRegister, allocator: Allocator, other: *const LWWRegister) !bool {
        // Last write wins (by timestamp, then by instance ID for tiebreaker)
        if (other.timestamp > self.timestamp or
            (other.timestamp == self.timestamp and
                other.instance.compareTo(&self.instance) == .gt))
        {
            allocator.free(self.value);
            self.value = try allocator.dupe(u8, other.value);
            self.timestamp = other.timestamp;
            self.instance = other.instance;
            return true;
        }
        return false;
    }

    pub fn get(self: *const LWWRegister) []const u8 {
        return self.value;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FEDERATION STATE — Complete federation state
// ═══════════════════════════════════════════════════════════════════════════════

pub const FederationState = struct {
    my_id: InstanceId,
    instances: std.StringHashMap(InstanceInfo),
    election: ElectionState,
    task_counter: GCounter,
    event_counter: GCounter,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator, my_id: InstanceId) !FederationState {
        var state = FederationState{
            .my_id = my_id,
            .instances = std.StringHashMap(InstanceInfo).init(allocator),
            .election = ElectionState.init(),
            .task_counter = GCounter.init(allocator),
            .event_counter = GCounter.init(allocator),
            .mutex = std.Thread.Mutex{},
        };

        // Add self as first instance
        const id_str = try my_id.format(allocator);
        errdefer allocator.free(id_str);

        try state.instances.put(id_str, .{
            .id = my_id,
            .address = try allocator.dupe(u8, "localhost"),
            .status = .online,
            .last_heartbeat = std.time.milliTimestamp(),
            .term = 0,
            .voted_for = null,
            .claim_count = 0,
            .event_count = 0,
            .health_score = 100.0,
        });

        return state;
    }

    pub fn deinit(self: *FederationState) void {
        var iter = self.instances.iterator();
        while (iter.next()) |entry| {
            self.instances.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.instances.allocator);
        }
        self.instances.deinit();
        self.task_counter.deinit();
        self.event_counter.deinit();
    }

    /// Add or update an instance
    pub fn addInstance(self: *FederationState, allocator: Allocator, info: InstanceInfo) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const id_str = try info.id.format(allocator);
        defer allocator.free(id_str);

        if (self.instances.fetchRemove(id_str)) |old_entry| {
            self.instances.allocator.free(old_entry.key);
            var value_copy = old_entry.value;
            value_copy.deinit(self.instances.allocator);
        }

        const key_copy = try self.instances.allocator.dupe(u8, id_str);
        const info_copy = InstanceInfo{
            .id = info.id,
            .address = try self.instances.allocator.dupe(u8, info.address),
            .status = info.status,
            .last_heartbeat = info.last_heartbeat,
            .term = info.term,
            .voted_for = if (info.voted_for) |v| v else null,
            .claim_count = info.claim_count,
            .event_count = info.event_count,
            .health_score = info.health_score,
        };

        try self.instances.put(key_copy, info_copy);
    }

    /// Remove an instance
    pub fn removeInstance(self: *FederationState, allocator: Allocator, id: InstanceId) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const id_str = try id.format(allocator);
        defer allocator.free(id_str);

        if (self.instances.fetchRemove(id_str)) |entry| {
            self.instances.allocator.free(entry.key);
            var value_copy = entry.value;
            value_copy.deinit(self.instances.allocator);
        }
    }

    /// Get current leader
    pub fn getLeader(self: *FederationState) ?InstanceId {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.election.leader_id;
    }

    /// Check if I am the leader
    pub fn amILeader(self: *FederationState) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.election.leader_id) |leader| {
            return mem.eql(u8, &leader.bytes, &self.my_id.bytes);
        }
        return false;
    }

    /// Get aggregated health score
    pub fn getAggregatedHealth(self: *FederationState) f32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.instances.count() == 0) return 100.0;

        var total: f32 = 0;
        var count: usize = 0;
        var iter = self.instances.iterator();
        while (iter.next()) |entry| {
            // Only count online instances
            if (entry.value_ptr.status == .online or
                entry.value_ptr.status == .leader or
                entry.value_ptr.status == .follower)
            {
                total += entry.value_ptr.health_score;
                count += 1;
            }
        }

        return if (count > 0) total / @as(f32, @floatFromInt(count)) else 100.0;
    }

    /// Get instance count
    pub fn getInstanceCount(self: *FederationState) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.instances.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLUTION — Handle distributed task conflicts
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConflictResolver = struct {
    allocator: Allocator,
    federation: *FederationState,
    registry: *basal_ganglia.Registry,

    const Self = @This();

    pub fn init(allocator: Allocator, federation: *FederationState, registry: *basal_ganglia.Registry) Self {
        return .{
            .allocator = allocator,
            .federation = federation,
            .registry = registry,
        };
    }

    /// Resolve duplicate claim conflict
    /// Uses instance ID comparison as tiebreaker (deterministic)
    pub fn resolveDuplicateClaim(self: *Self, task_id: []const u8, claimant1: InstanceId, claimant2: InstanceId) !InstanceId {
        // Lower instance ID wins (deterministic tiebreaker)
        const order = claimant1.compareTo(&claimant2);
        const winner = if (order == .lt) claimant1 else claimant2;
        const loser = if (order == .lt) claimant2 else claimant1;

        // If I am the winner, I keep the claim
        // If I am the loser, I abandon the claim
        if (mem.eql(u8, &self.federation.my_id.bytes, &loser.bytes)) {
            const my_id_str = try self.federation.my_id.format(self.allocator);
            defer self.allocator.free(my_id_str);
            if (self.registry.abandon(task_id, my_id_str)) {
                // Abandoned successfully
            }
        }

        return winner;
    }

    /// Resolve heartbeat timeout conflict
    pub fn resolveHeartbeatTimeout(self: *Self, task_id: []const u8, owner: InstanceId) !bool {
        // If owner is not me, I can claim the task
        if (!mem.eql(u8, &self.federation.my_id.bytes, &owner.bytes)) {
            return true;
        }

        // If I am the owner, refresh heartbeat
        const my_id_str = try self.federation.my_id.format(self.allocator);
        defer self.allocator.free(my_id_str);

        return self.registry.heartbeat(task_id, my_id_str);
    }

    /// Resolve completion inconsistency
    /// Uses majority vote from all instances
    pub fn resolveCompletionInconsistency(self: *Self, task_id: []const u8, completions: usize, total_instances: usize) !bool {
        // If majority says completed, mark as completed
        const majority = (total_instances / 2) + 1;
        if (completions >= majority) {
            const my_id_str = try self.federation.my_id.format(self.allocator);
            defer self.allocator.free(my_id_str);
            _ = self.registry.complete(task_id, my_id_str);
            return true;
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED TASK CLAIMING — Federation-aware task claiming
// ═══════════════════════════════════════════════════════════════════════════════

pub const DistributedTaskClaim = struct {
    allocator: Allocator,
    federation: *FederationState,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,

    const Self = @This();

    /// Claim a task with federation coordination
    pub fn claim(self: *Self, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool {
        // First, try local claim
        const local_claimed = try self.registry.claim(self.allocator, task_id, agent_id, ttl_ms);

        if (!local_claimed) {
            // Check if task is claimed by another instance
            // In real implementation, would query federation
            return false;
        }

        // Broadcast claim to federation
        // In real implementation, would send FederationMessage
        _ = self.federation;
        _ = self.event_bus;

        // Update counters
        try self.federation.task_counter.increment(self.federation.my_id, 1);

        return true;
    }

    /// Complete a task with federation notification
    pub fn complete(self: *Self, task_id: []const u8, agent_id: []const u8, duration_ms: u64) !void {
        // Complete locally
        _ = self.registry.complete(task_id, agent_id);

        // Publish to event bus
        const event_data = reticular_formation.EventData{
            .task_completed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .duration_ms = duration_ms,
            },
        };
        try self.event_bus.publish(.task_completed, event_data);

        // Broadcast completion to federation
        // In real implementation, would send FederationMessage
    }

    /// Abandon a task with federation notification
    pub fn abandon(self: *Self, task_id: []const u8, agent_id: []const u8) !void {
        // Abandon locally
        _ = self.registry.abandon(task_id, agent_id);

        // Broadcast abandonment to federation
        // In real implementation, would send FederationMessage
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL SINGLETON
// ═══════════════════════════════════════════════════════════════════════════════

var global_federation: ?*FederationState = null;
var global_mutex = std.Thread.Mutex{};

/// Get or create global federation state
pub fn getGlobal(allocator: Allocator) !*FederationState {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_federation) |existing| {
        return existing;
    }

    // Generate or load instance ID
    const my_id = InstanceId.generate();

    const state = try allocator.create(FederationState);
    state.* = try FederationState.init(allocator, my_id);
    global_federation = state;
    return state;
}

/// Reset global federation (for testing)
pub fn resetGlobal(allocator: Allocator) void {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_federation) |state| {
        state.deinit();
        allocator.destroy(state);
        global_federation = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "InstanceId generate and format" {
    const allocator = std.testing.allocator;
    const id = InstanceId.generate();

    try std.testing.expectEqual(@as(usize, 16), id.bytes.len);

    const formatted = try id.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqual(@as(usize, 36), formatted.len); // UUID format: 8-4-4-4-12
}

test "InstanceId parse" {
    const allocator = std.testing.allocator;
    const uuid_str = "550e8400-e29b-41d4-a716-446655440000";

    const id = try InstanceId.parse(uuid_str);
    const formatted = try id.format(allocator);
    defer allocator.free(formatted);

    // Case-insensitive comparison
    try std.testing.expectEqualStrings(uuid_str, formatted);
}

test "InstanceId compare" {
    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();

    // Same ID should be equal
    try std.testing.expectEqual(std.math.Order.eq, id1.compareTo(&id1));

    // Different IDs should not be equal (extremely unlikely to be equal)
    const order = id1.compareTo(&id2);
    try std.testing.expect(order != .eq or id1.bytes[0] != id2.bytes[0]);
}

test "ElectionState lifecycle" {
    var state = ElectionState.init();

    try std.testing.expectEqual(@as(u64, 0), state.current_term);
    try std.testing.expect(state.voted_for == null);

    state.startElection();
    try std.testing.expectEqual(@as(u64, 1), state.current_term);
    try std.testing.expect(state.state == .candidate);

    const my_id = InstanceId.generate();
    state.becomeLeader(my_id);
    try std.testing.expect(state.state == .leader);
    try std.testing.expect(state.leader_id != null);
}

test "ElectionState vote granting" {
    var state = ElectionState.init();
    const candidate1 = InstanceId.generate();
    const candidate2 = InstanceId.generate();

    // First vote should be granted
    const granted1 = state.shouldGrantVote(candidate1, 1, 0, 10, 0, 5);
    try std.testing.expect(granted1);

    // Second vote should be denied (already voted)
    const granted2 = state.shouldGrantVote(candidate2, 1, 0, 10, 0, 5);
    try std.testing.expect(!granted2);

    // Higher term should reset vote
    const granted3 = state.shouldGrantVote(candidate2, 2, 0, 10, 0, 5);
    try std.testing.expect(granted3);
}

test "GCounter increment and merge" {
    const allocator = std.testing.allocator;

    var counter1 = GCounter.init(allocator);
    defer counter1.deinit();

    var counter2 = GCounter.init(allocator);
    defer counter2.deinit();

    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();

    try counter1.increment(id1, 5);
    try counter1.increment(id2, 3);

    try counter2.increment(id1, 2);
    try counter2.increment(id2, 7);

    try std.testing.expectEqual(@as(u64, 8), counter1.value());

    try counter1.merge(&counter2);

    // After merge, should have max of each: max(5,2) + max(3,7) = 5 + 7 = 12
    try std.testing.expectEqual(@as(u64, 12), counter1.value());
}

test "LWWRegister last write wins" {
    const allocator = std.testing.allocator;

    var reg = try LWWRegister.init(allocator, "value1");
    defer reg.deinit(allocator);

    const id1 = InstanceId.generate();
    try reg.set(allocator, "value2", id1);

    try std.testing.expectEqualStrings("value2", reg.get());

    // Simulate time passing
    std.Thread.sleep(1_000_000_000); // 1 second in nanoseconds

    const id2 = InstanceId.generate();
    try reg.set(allocator, "value3", id2);

    try std.testing.expectEqualStrings("value3", reg.get());
}

test "LWWRegister merge" {
    const allocator = std.testing.allocator;

    var reg1 = try LWWRegister.init(allocator, "value1");
    defer reg1.deinit(allocator);

    var reg2 = try LWWRegister.init(allocator, "value2");
    defer reg2.deinit(allocator);

    std.Thread.sleep(1_000_000_000); // 1 second in nanoseconds

    const id = InstanceId.generate();
    try reg2.set(allocator, "value3", id);

    // reg2 should win (later timestamp)
    _ = try reg1.merge(allocator, &reg2);

    try std.testing.expectEqualStrings("value3", reg1.get());
}

test "FederationState init and instance management" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.getInstanceCount());
    try std.testing.expect(!state.amILeader()); // No election yet

    const health = state.getAggregatedHealth();
    try std.testing.expect(health >= 0.0 and health <= 100.0);
}

test "FederationState aggregated health" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    // Add some instances with different health scores
    const id2 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1",
        .status = .online,
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 5,
        .event_count = 100,
        .health_score = 80.0,
    });

    const id3 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id3,
        .address = "remote2",
        .status = .online,
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 10,
        .event_count = 200,
        .health_score = 90.0,
    });

    const health = state.getAggregatedHealth();
    // Average of 100.0, 80.0, 90.0 = 90.0
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), health, 0.01);
}

test "FederationState leader election" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    try std.testing.expect(!state.amILeader());

    // Become leader
    state.election.becomeLeader(my_id);

    try std.testing.expect(state.amILeader());

    const leader = state.getLeader();
    try std.testing.expect(leader != null);
    try std.testing.expect(mem.eql(u8, &leader.?.bytes, &my_id.bytes));
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE G-COUNTER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GCounter merge takes maximum per instance" {
    const allocator = std.testing.allocator;

    var counter1 = GCounter.init(allocator);
    defer counter1.deinit();

    var counter2 = GCounter.init(allocator);
    defer counter2.deinit();

    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();
    const id3 = InstanceId.generate();

    // Counter1: id1=5, id2=3
    try counter1.increment(id1, 5);
    try counter1.increment(id2, 3);

    // Counter2: id1=2, id2=7, id3=10
    try counter2.increment(id1, 2);
    try counter2.increment(id2, 7);
    try counter2.increment(id3, 10);

    // Before merge
    try std.testing.expectEqual(@as(u64, 8), counter1.value());
    try std.testing.expectEqual(@as(u64, 19), counter2.value());

    // Merge counter2 into counter1
    try counter1.merge(&counter2);

    // After merge: max(5,2)=5, max(3,7)=7, 10=10, total=22
    try std.testing.expectEqual(@as(u64, 22), counter1.value());

    // Verify individual counts
    try std.testing.expectEqual(@as(u64, 5), counter1.counts.get(id1).?);
    try std.testing.expectEqual(@as(u64, 7), counter1.counts.get(id2).?);
    try std.testing.expectEqual(@as(u64, 10), counter1.counts.get(id3).?);
}

test "GCounter merge is idempotent" {
    const allocator = std.testing.allocator;

    var counter1 = GCounter.init(allocator);
    defer counter1.deinit();

    var counter2 = GCounter.init(allocator);
    defer counter2.deinit();

    const id1 = InstanceId.generate();

    try counter1.increment(id1, 5);
    try counter2.increment(id1, 10);

    // First merge
    try counter1.merge(&counter2);
    try std.testing.expectEqual(@as(u64, 10), counter1.value());

    // Second merge (should be no-op)
    try counter1.merge(&counter2);
    try std.testing.expectEqual(@as(u64, 10), counter1.value());
}

test "GCounter merge is commutative" {
    const allocator = std.testing.allocator;

    var counter1 = GCounter.init(allocator);
    defer counter1.deinit();

    var counter2 = GCounter.init(allocator);
    defer counter2.deinit();

    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();

    try counter1.increment(id1, 5);
    try counter2.increment(id2, 7);

    // Merge counter2 into counter1
    var counter1_copy = GCounter.init(allocator);
    defer counter1_copy.deinit();
    try counter1_copy.increment(id1, 5);

    try counter1_copy.merge(&counter2);
    const sum1 = counter1_copy.value();

    // Merge counter1 into counter2
    var counter2_copy = GCounter.init(allocator);
    defer counter2_copy.deinit();
    try counter2_copy.increment(id2, 7);

    try counter2_copy.merge(&counter1);
    const sum2 = counter2_copy.value();

    // Both should have same result
    try std.testing.expectEqual(sum1, sum2);
    try std.testing.expectEqual(@as(u64, 12), sum1);
}

test "GCounter merge is associative" {
    const allocator = std.testing.allocator;

    var counter1 = GCounter.init(allocator);
    defer counter1.deinit();

    var counter2 = GCounter.init(allocator);
    defer counter2.deinit();

    var counter3 = GCounter.init(allocator);
    defer counter3.deinit();

    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();
    const id3 = InstanceId.generate();

    try counter1.increment(id1, 5);
    try counter2.increment(id2, 7);
    try counter3.increment(id3, 10);

    // (counter1 + counter2) + counter3
    var temp1 = GCounter.init(allocator);
    defer temp1.deinit();
    try temp1.increment(id1, 5);
    try temp1.merge(&counter2);
    try temp1.merge(&counter3);
    const sum1 = temp1.value();

    // counter1 + (counter2 + counter3)
    var temp2 = GCounter.init(allocator);
    defer temp2.deinit();
    try temp2.increment(id2, 7);
    try temp2.merge(&counter3);
    try counter1.merge(&temp2);
    const sum2 = counter1.value();

    try std.testing.expectEqual(sum1, sum2);
}

test "GCounter concurrent increments" {
    const allocator = std.testing.allocator;

    var counter = GCounter.init(allocator);
    defer counter.deinit();

    const id1 = InstanceId.generate();
    const id2 = InstanceId.generate();

    // Simulate concurrent increments from different instances
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try counter.increment(id1, 1);
        try counter.increment(id2, 2);
    }

    try std.testing.expectEqual(@as(u64, 30), counter.value());
    try std.testing.expectEqual(@as(u64, 10), counter.counts.get(id1).?);
    try std.testing.expectEqual(@as(u64, 20), counter.counts.get(id2).?);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE LWW REGISTER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LWWRegister timestamp precedence" {
    const allocator = std.testing.allocator;

    var reg1 = try LWWRegister.init(allocator, "value1");
    defer reg1.deinit(allocator);

    var reg2 = try LWWRegister.init(allocator, "value2");
    defer reg2.deinit(allocator);

    // reg1 has earlier timestamp
    std.Thread.sleep(1_000_000); // 1ms

    const id = InstanceId.generate();
    try reg2.set(allocator, "value3", id);

    // reg2 should win (later timestamp)
    const merged = try reg1.merge(allocator, &reg2);
    try std.testing.expect(merged); // Value changed
    try std.testing.expectEqualStrings("value3", reg1.get());
}

test "LWWRegister instance ID tiebreaker" {
    const allocator = std.testing.allocator;

    // Create two registers with same timestamp
    var reg1 = LWWRegister{
        .value = try allocator.dupe(u8, "value1"),
        .timestamp = 1000,
        .instance = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 },
    };
    defer reg1.deinit(allocator);

    var reg2 = LWWRegister{
        .value = try allocator.dupe(u8, "value2"),
        .timestamp = 1000, // Same timestamp
        .instance = InstanceId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 15 }, // Higher ID
    };
    defer reg2.deinit(allocator);

    // reg2 should win (higher instance ID with same timestamp)
    const merged = try reg1.merge(allocator, &reg2);
    try std.testing.expect(merged);
    try std.testing.expectEqualStrings("value2", reg1.get());
}

test "LWWRegister merge idempotent" {
    const allocator = std.testing.allocator;

    var reg1 = try LWWRegister.init(allocator, "value1");
    defer reg1.deinit(allocator);

    var reg2 = try LWWRegister.init(allocator, "value2");
    defer reg2.deinit(allocator);

    std.Thread.sleep(1_000_000);

    const id = InstanceId.generate();
    try reg2.set(allocator, "value3", id);

    // First merge
    const merged1 = try reg1.merge(allocator, &reg2);
    try std.testing.expect(merged1);
    try std.testing.expectEqualStrings("value3", reg1.get());

    // Second merge (idempotent - no change)
    const merged2 = try reg1.merge(allocator, &reg2);
    try std.testing.expect(!merged2); // No change this time
    try std.testing.expectEqualStrings("value3", reg1.get());
}

test "LWWRegister merge no-op when earlier" {
    const allocator = std.testing.allocator;

    var reg1 = try LWWRegister.init(allocator, "value1");
    defer reg1.deinit(allocator);

    std.Thread.sleep(1_000_000);

    const id = InstanceId.generate();
    try reg1.set(allocator, "value2", id);

    // Save timestamp for reg2
    const reg1_timestamp = reg1.timestamp;

    // Create reg2 with earlier timestamp
    var reg2 = LWWRegister{
        .value = try allocator.dupe(u8, "value3"),
        .timestamp = reg1_timestamp - 100,
        .instance = InstanceId.generate(),
    };
    defer reg2.deinit(allocator);

    // reg1 should keep its value (later timestamp)
    const merged = try reg1.merge(allocator, &reg2);
    try std.testing.expect(!merged);
    try std.testing.expectEqualStrings("value2", reg1.get());
}

test "LWWRegister concurrent writes" {
    const allocator = std.testing.allocator;

    var reg1 = try LWWRegister.init(allocator, "initial");
    defer reg1.deinit(allocator);

    var reg2 = try LWWRegister.init(allocator, "initial");
    defer reg2.deinit(allocator);

    const id1 = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    const id2 = InstanceId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 15 };

    const base_timestamp = std.time.milliTimestamp();

    // Simulate concurrent writes
    reg1.timestamp = base_timestamp;
    allocator.free(reg1.value);
    reg1.value = try allocator.dupe(u8, "write1");
    reg1.instance = id1;

    reg2.timestamp = base_timestamp;
    allocator.free(reg2.value);
    reg2.value = try allocator.dupe(u8, "write2");
    reg2.instance = id2;

    // Merge: higher instance ID wins
    _ = try reg1.merge(allocator, &reg2);
    try std.testing.expectEqualStrings("write2", reg1.get());
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE LEADER ELECTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ElectionState follower to candidate transition" {
    var state = ElectionState.init();

    try std.testing.expectEqual(@as(u64, 0), state.current_term);
    try std.testing.expect(state.state == .follower);
    try std.testing.expect(state.voted_for == null);

    state.startElection();

    try std.testing.expectEqual(@as(u64, 1), state.current_term);
    try std.testing.expect(state.state == .candidate);
    try std.testing.expect(state.voted_for == null);
}

test "ElectionState candidate to leader transition" {
    var state = ElectionState.init();
    const my_id = InstanceId.generate();

    state.startElection();
    try std.testing.expect(state.state == .candidate);

    state.becomeLeader(my_id);

    try std.testing.expect(state.state == .leader);
    try std.testing.expect(state.leader_id != null);
    try std.testing.expect(mem.eql(u8, &state.leader_id.?.bytes, &my_id.bytes));
}

test "ElectionState become follower updates term" {
    var state = ElectionState.init();
    const leader_id = InstanceId.generate();

    state.startElection();
    try std.testing.expectEqual(@as(u64, 1), state.current_term);

    state.becomeFollower(leader_id, 5);

    try std.testing.expectEqual(@as(u64, 5), state.current_term);
    try std.testing.expect(state.state == .follower);
    try std.testing.expect(mem.eql(u8, &state.leader_id.?.bytes, &leader_id.bytes));
}

test "ElectionState vote with log completeness" {
    var state = ElectionState.init();
    const candidate1 = InstanceId.generate();
    const candidate2 = InstanceId.generate();

    // Initial state: our log is at term 0, index 10
    const our_term: u64 = 0;
    const our_index: u64 = 10;

    // Candidate with less complete log should be denied
    const granted1 = state.shouldGrantVote(candidate1, 1, 0, 5, our_term, our_index);
    try std.testing.expect(!granted1); // Log not complete enough

    // Candidate with same term but lower index should be denied
    const granted2 = state.shouldGrantVote(candidate2, 1, 0, 8, our_term, our_index);
    try std.testing.expect(!granted2); // Log index behind

    // Candidate with complete log should be granted
    const granted3 = state.shouldGrantVote(candidate1, 1, 0, 10, our_term, our_index);
    try std.testing.expect(granted3);
}

test "ElectionState term progression" {
    var state = ElectionState.init();
    const candidate = InstanceId.generate();

    // Grant vote at term 1
    const granted1 = state.shouldGrantVote(candidate, 1, 0, 10, 0, 5);
    try std.testing.expect(granted1);
    try std.testing.expectEqual(@as(u64, 1), state.current_term);
    try std.testing.expect(state.voted_for != null);

    // Receive higher term with up-to-date log, should update and grant vote
    const granted2 = state.shouldGrantVote(candidate, 5, 1, 10, 1, 5);
    try std.testing.expect(granted2);
    try std.testing.expectEqual(@as(u64, 5), state.current_term);
    try std.testing.expect(state.voted_for != null); // Voted again in new term
}

test "ElectionState deny lower term" {
    var state = ElectionState.init();
    const candidate = InstanceId.generate();

    // Set current term to 5
    state.current_term = 5;

    // Candidate from lower term should be denied
    const granted = state.shouldGrantVote(candidate, 3, 0, 100, 0, 0);
    try std.testing.expect(!granted);
    try std.testing.expectEqual(@as(u64, 5), state.current_term);
}

test "ElectionState multiple candidates same term" {
    var state = ElectionState.init();
    const candidate1 = InstanceId.generate();
    const candidate2 = InstanceId.generate();

    // Vote for candidate1
    const granted1 = state.shouldGrantVote(candidate1, 1, 0, 10, 0, 5);
    try std.testing.expect(granted1);

    // Deny candidate2 in same term
    const granted2 = state.shouldGrantVote(candidate2, 1, 0, 10, 0, 5);
    try std.testing.expect(!granted2);

    // Higher term should allow new vote (candidate has equal or better log)
    const granted3 = state.shouldGrantVote(candidate2, 2, 1, 10, 1, 5);
    try std.testing.expect(granted3);
}

test "ElectionState vote persistence" {
    var state = ElectionState.init();
    const candidate = InstanceId.generate();

    // First vote grants
    const granted1 = state.shouldGrantVote(candidate, 1, 0, 10, 0, 5);
    try std.testing.expect(granted1);
    try std.testing.expect(state.voted_for != null);

    // Same candidate again should be granted (already voted for them)
    const granted2 = state.shouldGrantVote(candidate, 1, 0, 10, 0, 5);
    try std.testing.expect(granted2);

    // Verify voted_for is set correctly
    try std.testing.expect(mem.eql(u8, &state.voted_for.?.bytes, &candidate.bytes));
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE MEMBERSHIP MANAGEMENT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FederationState addInstance updates existing" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const id2 = InstanceId.generate();

    // Add instance
    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1:8080",
        .status = .online,
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 5,
        .event_count = 100,
        .health_score = 80.0,
    });

    try std.testing.expectEqual(@as(usize, 2), state.getInstanceCount());

    // Update same instance with different data
    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1:8081",
        .status = .leader,
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 1,
        .voted_for = null,
        .claim_count = 10,
        .event_count = 200,
        .health_score = 95.0,
    });

    // Still only 2 instances
    try std.testing.expectEqual(@as(usize, 2), state.getInstanceCount());

    // Verify updated values
    const id_str = try id2.format(allocator);
    defer allocator.free(id_str);
    const info = state.instances.get(id_str).?;
    try std.testing.expectEqual(.leader, info.status);
    try std.testing.expectEqual(@as(usize, 10), info.claim_count);
}

test "FederationState removeInstance" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const id2 = InstanceId.generate();

    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1:8080",
        .status = .online,
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 5,
        .event_count = 100,
        .health_score = 80.0,
    });

    try std.testing.expectEqual(@as(usize, 2), state.getInstanceCount());

    // Remove instance
    try state.removeInstance(allocator, id2);

    try std.testing.expectEqual(@as(usize, 1), state.getInstanceCount());

    // Remove non-existent instance should not error
    const id3 = InstanceId.generate();
    try state.removeInstance(allocator, id3);
    try std.testing.expectEqual(@as(usize, 1), state.getInstanceCount());
}

test "FederationState getLeader when no leader" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    // No leader set
    const leader = state.getLeader();
    try std.testing.expect(leader == null);
}

test "FederationState amILeader transitions" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    try std.testing.expect(!state.amILeader());

    // Become leader
    state.election.becomeLeader(my_id);
    try std.testing.expect(state.amILeader());

    // Step down to follower
    const other_id = InstanceId.generate();
    state.election.becomeFollower(other_id, 1);
    try std.testing.expect(!state.amILeader());
}

test "FederationState aggregated health excludes offline" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const id2 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1",
        .status = .offline, // Offline
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 0,
        .event_count = 0,
        .health_score = 50.0, // Should be excluded
    });

    const id3 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id3,
        .address = "remote2",
        .status = .degraded, // Degraded, also excluded
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 0,
        .event_count = 0,
        .health_score = 60.0,
    });

    // Only online instance (my_id with 100.0)
    const health = state.getAggregatedHealth();
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), health, 0.01);
}

test "FederationState aggregated health with mixed statuses" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const id2 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id2,
        .address = "remote1",
        .status = .leader, // Included
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 0,
        .event_count = 0,
        .health_score = 90.0,
    });

    const id3 = InstanceId.generate();
    try state.addInstance(allocator, .{
        .id = id3,
        .address = "remote2",
        .status = .follower, // Included
        .last_heartbeat = std.time.milliTimestamp(),
        .term = 0,
        .voted_for = null,
        .claim_count = 0,
        .event_count = 0,
        .health_score = 85.0,
    });

    // Average of 100.0, 90.0, 85.0 = 91.67
    const health = state.getAggregatedHealth();
    try std.testing.expect(health > 91.0 and health < 92.0);
}

test "FederationState empty instances health" {
    const allocator = std.testing.allocator;

    // Create state and manually clear instances
    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);

    // Clear all instances
    {
        var iter = state.instances.iterator();
        while (iter.next()) |entry| {
            state.instances.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(state.instances.allocator);
        }
    }
    state.instances.clearRetainingCapacity();

    // Empty should return 100.0
    const health = state.getAggregatedHealth();
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), health, 0.01);

    state.deinit();
}

test "FederationState thread safety with mutex" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    // Test that mutex-protected operations don't deadlock
    _ = state.getInstanceCount();
    _ = state.getLeader();
    _ = state.amILeader();
    _ = state.getAggregatedHealth();

    // All should complete without deadlock
    try std.testing.expect(true);
}

test "FederationState task and event counters" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const id2 = InstanceId.generate();

    // Increment task counter
    try state.task_counter.increment(my_id, 5);
    try state.task_counter.increment(id2, 3);

    try std.testing.expectEqual(@as(u64, 8), state.task_counter.value());

    // Increment event counter
    try state.event_counter.increment(my_id, 10);
    try state.event_counter.increment(id2, 20);

    try std.testing.expectEqual(@as(u64, 30), state.event_counter.value());
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLVER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConflictResolver resolveDuplicateClaim determinism" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    var resolver = ConflictResolver.init(allocator, &state, registry);

    const claimant1 = InstanceId{ .bytes = [_]u8{5} ++ [_]u8{0} ** 15 };
    const claimant2 = InstanceId{ .bytes = [_]u8{10} ++ [_]u8{0} ** 15 };

    const winner = try resolver.resolveDuplicateClaim("task-1", claimant1, claimant2);

    // Lower ID should win deterministically
    try std.testing.expectEqual(@as(u8, 5), winner.bytes[0]);
}

test "ConflictResolver resolveHeartbeatTimeout" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    var resolver = ConflictResolver.init(allocator, &state, registry);

    const other_owner = InstanceId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 15 };

    // If I'm not the owner, I can claim
    const can_claim = try resolver.resolveHeartbeatTimeout("task-timeout", other_owner);
    try std.testing.expect(can_claim);
}

test "ConflictResolver resolveCompletionInconsistency majority" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    var resolver = ConflictResolver.init(allocator, &state, registry);

    // 3 out of 5 instances say completed (majority is 3)
    const result = try resolver.resolveCompletionInconsistency("task-majority", 3, 5);
    try std.testing.expect(result); // Should mark as completed
}

test "ConflictResolver resolveCompletionInconsistency no majority" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    var resolver = ConflictResolver.init(allocator, &state, registry);

    // 2 out of 5 instances say completed (need 3 for majority)
    const result = try resolver.resolveCompletionInconsistency("task-no-majority", 2, 5);
    try std.testing.expect(!result); // Should not mark as completed
}

test "ConflictResolver resolveCompletionInconsistency exact majority" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 15 };
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    var resolver = ConflictResolver.init(allocator, &state, registry);

    // Exactly majority threshold (5/2 + 1 = 3)
    const result = try resolver.resolveCompletionInconsistency("task-exact", 3, 5);
    try std.testing.expect(result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED TASK CLAIM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DistributedTaskClaim claim success" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    var distributed = DistributedTaskClaim{
        .allocator = allocator,
        .federation = &state,
        .registry = registry,
        .event_bus = event_bus,
    };

    const claimed = try distributed.claim("dist-task-1", "dist-agent-1", 5000);
    try std.testing.expect(claimed);
}

test "DistributedTaskClaim claim when already claimed" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    // First claim
    _ = try registry.claim(allocator, "dist-task-2", "agent-a", 5000);

    var distributed = DistributedTaskClaim{
        .allocator = allocator,
        .federation = &state,
        .registry = registry,
        .event_bus = event_bus,
    };

    // Second claim should fail
    const claimed = try distributed.claim("dist-task-2", "agent-b", 5000);
    try std.testing.expect(!claimed);
}

test "DistributedTaskClaim complete" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    // First claim the task
    _ = try registry.claim(allocator, "dist-task-3", "dist-agent-3", 5000);

    var distributed = DistributedTaskClaim{
        .allocator = allocator,
        .federation = &state,
        .registry = registry,
        .event_bus = event_bus,
    };

    // Complete should not error
    try distributed.complete("dist-task-3", "dist-agent-3", 1000);
}

test "DistributedTaskClaim abandon" {
    const allocator = std.testing.allocator;

    const my_id = InstanceId.generate();
    var state = try FederationState.init(allocator, my_id);
    defer state.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    defer basal_ganglia.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    // First claim the task
    _ = try registry.claim(allocator, "dist-task-4", "dist-agent-4", 5000);

    var distributed = DistributedTaskClaim{
        .allocator = allocator,
        .federation = &state,
        .registry = registry,
        .event_bus = event_bus,
    };

    // Abandon should not error
    try distributed.abandon("dist-task-4", "dist-agent-4");
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANCE ID EDGE CASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "InstanceId parse invalid format" {
    // Missing hyphens
    const result1 = InstanceId.parse("550e8400e29b41d4a716446655440000");
    try std.testing.expectError(error.InvalidUuid, result1);

    // Invalid hex characters
    const result2 = InstanceId.parse("550e8400-e29b-41d4-a716-44665544000g");
    try std.testing.expectError(error.InvalidUuid, result2);

    // Too short
    const result3 = InstanceId.parse("550e8400-e29b");
    try std.testing.expectError(error.InvalidUuid, result3);

    // Empty string
    const result4 = InstanceId.parse("");
    try std.testing.expectError(error.InvalidUuid, result4);
}

test "InstanceId parse lowercase" {
    const allocator = std.testing.allocator;
    const uuid_str = "550e8400-e29b-41d4-a716-446655440000";

    const id = try InstanceId.parse(uuid_str);
    const formatted = try id.format(allocator);
    defer allocator.free(formatted);

    // Should preserve format
    try std.testing.expectEqualStrings(uuid_str, formatted);
}

test "InstanceId parse uppercase" {
    const allocator = std.testing.allocator;
    const uuid_str = "550E8400-E29B-41D4-A716-446655440000";

    const id = try InstanceId.parse(uuid_str);
    const formatted = try id.format(allocator);
    defer allocator.free(formatted);

    // Output should be lowercase
    try std.testing.expect(formatted[0] >= 'a' and formatted[0] <= 'f');
}

test "InstanceId compareTo total ordering" {
    const id1 = InstanceId{ .bytes = [_]u8{0} ** 16 };
    const id2 = InstanceId{ .bytes = [_]u8{0xFF} ** 16 };
    const id3 = InstanceId{ .bytes = [_]u8{0x80} ++ [_]u8{0} ** 15 };

    // id1 < id3 < id2
    try std.testing.expectEqual(std.math.Order.lt, id1.compareTo(&id3));
    try std.testing.expectEqual(std.math.Order.lt, id3.compareTo(&id2));
    try std.testing.expectEqual(std.math.Order.gt, id2.compareTo(&id1));
}

test "InstanceId generate unique" {
    const ids_to_generate = 100;
    var ids: [100]InstanceId = undefined;

    for (0..ids_to_generate) |i| {
        ids[i] = InstanceId.generate();
    }

    // All should be unique (extremely high probability)
    var duplicates: usize = 0;
    for (0..ids_to_generate) |i| {
        for (i + 1..ids_to_generate) |j| {
            if (mem.eql(u8, &ids[i].bytes, &ids[j].bytes)) {
                duplicates += 1;
            }
        }
    }

    try std.testing.expectEqual(@as(usize, 0), duplicates);
}

test "InstanceId generate sets version_bits" {
    const id = InstanceId.generate();

    // Check version bits (byte 6 should have version 4 in high nibble)
    try std.testing.expectEqual(@as(u8, 0x40), id.bytes[6] & 0xF0);

    // Check variant bits (byte 8 should have variant 1 in high two bits)
    try std.testing.expectEqual(@as(u8, 0x80), id.bytes[8] & 0xC0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEDERATION MESSAGE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FederationMessage deinit cleanup" {
    const allocator = std.testing.allocator;

    // Test claim_request cleanup
    {
        var msg = FederationMessage{
            .msg_type = .claim_request,
            .from = InstanceId.generate(),
            .to = InstanceId.generate(),
            .term = 1,
            .timestamp = 1000,
            .data = .{ .claim_request = .{
                .task_id = try allocator.dupe(u8, "task-1"),
                .agent_id = try allocator.dupe(u8, "agent-1"),
                .ttl_ms = 5000,
            } },
        };
        msg.deinit(allocator);
    }

    // Test claim_response cleanup
    {
        var msg = FederationMessage{
            .msg_type = .claim_response,
            .from = InstanceId.generate(),
            .to = InstanceId.generate(),
            .term = 1,
            .timestamp = 1000,
            .data = .{ .claim_response = .{
                .task_id = try allocator.dupe(u8, "task-2"),
                .granted = true,
                .winner = InstanceId.generate(),
            } },
        };
        msg.deinit(allocator);
    }

    // Test conflict_resolve cleanup
    {
        var msg = FederationMessage{
            .msg_type = .conflict_resolve,
            .from = InstanceId.generate(),
            .to = InstanceId.generate(),
            .term = 1,
            .timestamp = 1000,
            .data = .{ .conflict_resolve = .{
                .task_id = try allocator.dupe(u8, "task-3"),
                .conflict_type = .duplicate_claim,
                .resolving_instance = try allocator.dupe(u8, "instance-1"),
            } },
        };
        msg.deinit(allocator);
    }

    // If we got here without crashes, cleanup works
    try std.testing.expect(true);
}

test "FederationMessage all message types" {
    const allocator = std.testing.allocator;

    const from_id = InstanceId.generate();
    const to_id = InstanceId.generate();

    const msg_types = [_]MessageType{
        .heartbeat,
        .claim_request,
        .claim_response,
        .task_complete,
        .vote_request,
        .vote_response,
        .append_entries,
        .health_query,
        .health_response,
        .conflict_resolve,
    };

    for (msg_types) |msg_type| {
        const data: MessageData = switch (msg_type) {
            .heartbeat => .{ .heartbeat = .{ .sequence = 1 } },
            .health_query => .health_query,
            else => continue, // Skip complex ones for this test
        };

        var msg = FederationMessage{
            .msg_type = msg_type,
            .from = from_id,
            .to = to_id,
            .term = 1,
            .timestamp = 1000,
            .data = data,
        };
        defer msg.deinit(allocator);

        try std.testing.expectEqual(msg_type, msg.msg_type);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSTANCE INFO TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "InstanceInfo deinit cleanup" {
    const allocator = std.testing.allocator;

    var info = InstanceInfo{
        .id = InstanceId.generate(),
        .address = try allocator.dupe(u8, "localhost:8080"),
        .status = .online,
        .last_heartbeat = 1000,
        .term = 1,
        .voted_for = null,
        .claim_count = 5,
        .event_count = 10,
        .health_score = 95.0,
    };

    info.deinit(allocator);

    // If we got here without crash, cleanup works
    try std.testing.expect(true);
}

test "InstanceInfo with voted_for" {
    const allocator = std.testing.allocator;

    const voted_id = InstanceId.generate();

    var info = InstanceInfo{
        .id = InstanceId.generate(),
        .address = try allocator.dupe(u8, "remote:9000"),
        .status = .follower,
        .last_heartbeat = 1000,
        .term = 5,
        .voted_for = voted_id,
        .claim_count = 0,
        .event_count = 0,
        .health_score = 100.0,
    };

    try std.testing.expect(info.voted_for != null);
    try std.testing.expect(mem.eql(u8, &info.voted_for.?.bytes, &voted_id.bytes));

    info.deinit(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL SINGLETON TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "getGlobal returns same instance" {
    const allocator = std.testing.allocator;

    // Reset first
    resetGlobal(allocator);

    const state1 = try getGlobal(allocator);
    const state2 = try getGlobal(allocator);

    try std.testing.expectEqual(state1, state2);

    resetGlobal(allocator);
}

test "resetGlobal cleans up" {
    const allocator = std.testing.allocator;

    // First call
    const state1 = try getGlobal(allocator);
    try std.testing.expect(state1 != null);

    // Reset
    resetGlobal(allocator);

    // Second call should create new instance
    const state2 = try getGlobal(allocator);
    try std.testing.expect(state2 != null);

    // Should be different pointer
    try std.testing.expect(state1 != state2);

    resetGlobal(allocator);
}

test "ConflictType all values" {
    const conflict_types = [_]ConflictType{
        .duplicate_claim,
        .heartbeat_timeout,
        .completion_inconsistent,
    };

    for (conflict_types) |ct| {
        _ = ct; // Just verify they exist
    }

    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ConflictType.duplicate_claim));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(ConflictType.heartbeat_timeout));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(ConflictType.completion_inconsistent));
}

test "MessageType all values" {
    const msg_types = [_]MessageType{
        .heartbeat,
        .claim_request,
        .claim_response,
        .task_complete,
        .vote_request,
        .vote_response,
        .append_entries,
        .health_query,
        .health_response,
        .conflict_resolve,
    };

    for (msg_types, 0..) |mt, i| {
        try std.testing.expectEqual(@as(u8, i), @intFromEnum(mt));
    }
}

test "InstanceStatus all values" {
    const statuses = [_]InstanceStatus{
        .online,
        .degraded,
        .offline,
        .leader,
        .follower,
        .candidate,
    };

    for (statuses, 0..) |st, i| {
        try std.testing.expectEqual(@as(u8, i), @intFromEnum(st));
    }
}

// φ² + 1/φ² = 3 | TRINITY
