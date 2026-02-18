// ═══════════════════════════════════════════════════════════════════════════════
// SLASHING ESCROW — Time-Locked Disputes with Governance Voting
// Trinity Storage Network v2.0
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const EscrowConfig = struct {
    /// Time lock duration for disputes (seconds)
    dispute_window_secs: i64 = 86400, // 24 hours
    /// Minimum votes to resolve a dispute
    min_governance_votes: u32 = 5,
    /// Threshold of votes to overturn slash (0.0-1.0)
    overturn_threshold: f64 = 0.667,
    /// Maximum concurrent escrows per node
    max_escrows_per_node: u32 = 10,
    /// Penalty for frivolous disputes (wei)
    frivolous_dispute_penalty_wei: u128 = 1_000_000_000_000_000_000, // 1 TRI
};

pub const EscrowStatus = enum(u8) {
    pending = 0, // Slash pending, within dispute window
    disputed = 1, // Dispute filed, awaiting governance vote
    executed = 2, // Slash executed (no dispute or dispute rejected)
    overturned = 3, // Slash overturned by governance
    expired = 4, // Dispute window expired, auto-execute
};

pub const EscrowEntry = struct {
    escrow_id: u64,
    node_id: [32]u8,
    slash_amount_wei: u128,
    reason: SlashReason,
    created_at: i64,
    dispute_deadline: i64,
    status: EscrowStatus,
    dispute_evidence: ?[32]u8, // hash of evidence
    votes_for_overturn: u32,
    votes_against_overturn: u32,
    voters: std.AutoHashMap([32]u8, bool), // voter → vote (true=overturn)
};

pub const SlashReason = enum(u8) {
    pos_failure = 0,
    data_corruption = 1,
    downtime = 2,
    protocol_violation = 3,
};

pub const DisputeResult = enum(u8) {
    accepted = 0,
    rejected_no_escrow = 1,
    rejected_already_disputed = 2,
    rejected_expired = 3,
    rejected_max_escrows = 4,
};

pub const VoteResult = enum(u8) {
    accepted = 0,
    rejected_not_disputed = 1,
    rejected_already_voted = 2,
    rejected_self_vote = 3,
    rejected_expired = 4,
};

pub const ResolutionResult = struct {
    escrow_id: u64,
    status: EscrowStatus,
    slash_executed: bool,
    amount_returned_wei: u128,
    amount_slashed_wei: u128,
};

pub const EscrowStats = struct {
    total_escrows: u64,
    active_escrows: u32,
    disputes_filed: u64,
    disputes_overturned: u64,
    disputes_rejected: u64,
    slashes_executed: u64,
    total_escrowed_wei: u128,
    total_returned_wei: u128,
    total_slashed_wei: u128,
    governance_votes_cast: u64,
};

pub const SlashingEscrow = struct {
    allocator: std.mem.Allocator,
    config: EscrowConfig,
    escrows: std.AutoHashMap(u64, EscrowEntry),
    node_escrow_count: std.AutoHashMap([32]u8, u32),
    next_escrow_id: u64,
    stats: EscrowStats,

    pub fn init(allocator: std.mem.Allocator) SlashingEscrow {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: EscrowConfig) SlashingEscrow {
        return .{
            .allocator = allocator,
            .config = config,
            .escrows = std.AutoHashMap(u64, EscrowEntry).init(allocator),
            .node_escrow_count = std.AutoHashMap([32]u8, u32).init(allocator),
            .next_escrow_id = 1,
            .stats = std.mem.zeroes(EscrowStats),
        };
    }

    pub fn deinit(self: *SlashingEscrow) void {
        var it = self.escrows.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.voters.deinit();
        }
        self.escrows.deinit();
        self.node_escrow_count.deinit();
    }

    /// Create a new escrow for a pending slash
    pub fn createEscrow(self: *SlashingEscrow, node_id: [32]u8, slash_amount_wei: u128, reason: SlashReason, current_time: i64) !u64 {
        const count = self.node_escrow_count.get(node_id) orelse 0;
        if (count >= self.config.max_escrows_per_node) return error.MaxEscrowsReached;

        const id = self.next_escrow_id;
        self.next_escrow_id += 1;

        var entry = EscrowEntry{
            .escrow_id = id,
            .node_id = node_id,
            .slash_amount_wei = slash_amount_wei,
            .reason = reason,
            .created_at = current_time,
            .dispute_deadline = current_time + self.config.dispute_window_secs,
            .status = .pending,
            .dispute_evidence = null,
            .votes_for_overturn = 0,
            .votes_against_overturn = 0,
            .voters = std.AutoHashMap([32]u8, bool).init(self.allocator),
        };
        _ = &entry;

        try self.escrows.put(id, entry);
        try self.node_escrow_count.put(node_id, count + 1);

        self.stats.total_escrows += 1;
        self.stats.active_escrows += 1;
        self.stats.total_escrowed_wei += slash_amount_wei;

        return id;
    }

    /// File a dispute against a pending slash
    pub fn fileDispute(self: *SlashingEscrow, escrow_id: u64, evidence_hash: [32]u8, current_time: i64) DisputeResult {
        const entry = self.escrows.getPtr(escrow_id) orelse return .rejected_no_escrow;

        if (entry.status != .pending) return .rejected_already_disputed;
        if (current_time > entry.dispute_deadline) return .rejected_expired;

        entry.status = .disputed;
        entry.dispute_evidence = evidence_hash;
        self.stats.disputes_filed += 1;

        return .accepted;
    }

    /// Vote on a disputed escrow
    pub fn vote(self: *SlashingEscrow, escrow_id: u64, voter_id: [32]u8, vote_overturn: bool, current_time: i64) !VoteResult {
        const entry = self.escrows.getPtr(escrow_id) orelse return .rejected_not_disputed;

        if (entry.status != .disputed) return .rejected_not_disputed;
        if (current_time > entry.dispute_deadline) return .rejected_expired;
        if (std.mem.eql(u8, &voter_id, &entry.node_id)) return .rejected_self_vote;
        if (entry.voters.get(voter_id) != null) return .rejected_already_voted;

        try entry.voters.put(voter_id, vote_overturn);
        if (vote_overturn) {
            entry.votes_for_overturn += 1;
        } else {
            entry.votes_against_overturn += 1;
        }

        self.stats.governance_votes_cast += 1;
        return .accepted;
    }

    /// Resolve an escrow (check if governance votes are sufficient)
    pub fn resolveEscrow(self: *SlashingEscrow, escrow_id: u64, current_time: i64) ?ResolutionResult {
        const entry = self.escrows.getPtr(escrow_id) orelse return null;

        // Already resolved
        if (entry.status == .executed or entry.status == .overturned) return null;

        const total_votes = entry.votes_for_overturn + entry.votes_against_overturn;

        // If disputed and enough votes cast
        if (entry.status == .disputed and total_votes >= self.config.min_governance_votes) {
            const overturn_ratio = @as(f64, @floatFromInt(entry.votes_for_overturn)) /
                @as(f64, @floatFromInt(total_votes));

            if (overturn_ratio >= self.config.overturn_threshold) {
                // Overturn: return funds
                entry.status = .overturned;
                self.stats.disputes_overturned += 1;
                self.stats.active_escrows -= 1;
                self.stats.total_returned_wei += entry.slash_amount_wei;
                self.decrementNodeCount(entry.node_id);

                return .{
                    .escrow_id = escrow_id,
                    .status = .overturned,
                    .slash_executed = false,
                    .amount_returned_wei = entry.slash_amount_wei,
                    .amount_slashed_wei = 0,
                };
            } else {
                // Dispute rejected: execute slash
                entry.status = .executed;
                self.stats.disputes_rejected += 1;
                self.stats.slashes_executed += 1;
                self.stats.active_escrows -= 1;
                self.stats.total_slashed_wei += entry.slash_amount_wei;
                self.decrementNodeCount(entry.node_id);

                return .{
                    .escrow_id = escrow_id,
                    .status = .executed,
                    .slash_executed = true,
                    .amount_returned_wei = 0,
                    .amount_slashed_wei = entry.slash_amount_wei,
                };
            }
        }

        // If dispute window expired
        if (current_time > entry.dispute_deadline) {
            if (entry.status == .pending) {
                // No dispute filed: auto-execute
                entry.status = .executed;
                self.stats.slashes_executed += 1;
                self.stats.active_escrows -= 1;
                self.stats.total_slashed_wei += entry.slash_amount_wei;
                self.decrementNodeCount(entry.node_id);

                return .{
                    .escrow_id = escrow_id,
                    .status = .executed,
                    .slash_executed = true,
                    .amount_returned_wei = 0,
                    .amount_slashed_wei = entry.slash_amount_wei,
                };
            }
            // Disputed but not enough votes yet — check if threshold met with current votes
            if (entry.status == .disputed and total_votes > 0) {
                const overturn_ratio = @as(f64, @floatFromInt(entry.votes_for_overturn)) /
                    @as(f64, @floatFromInt(total_votes));
                if (total_votes >= self.config.min_governance_votes and overturn_ratio >= self.config.overturn_threshold) {
                    entry.status = .overturned;
                    self.stats.disputes_overturned += 1;
                    self.stats.active_escrows -= 1;
                    self.stats.total_returned_wei += entry.slash_amount_wei;
                    self.decrementNodeCount(entry.node_id);

                    return .{
                        .escrow_id = escrow_id,
                        .status = .overturned,
                        .slash_executed = false,
                        .amount_returned_wei = entry.slash_amount_wei,
                        .amount_slashed_wei = 0,
                    };
                }
                // Not enough votes to overturn: execute
                entry.status = .executed;
                self.stats.disputes_rejected += 1;
                self.stats.slashes_executed += 1;
                self.stats.active_escrows -= 1;
                self.stats.total_slashed_wei += entry.slash_amount_wei;
                self.decrementNodeCount(entry.node_id);

                return .{
                    .escrow_id = escrow_id,
                    .status = .executed,
                    .slash_executed = true,
                    .amount_returned_wei = 0,
                    .amount_slashed_wei = entry.slash_amount_wei,
                };
            }
        }

        return null; // Not yet resolvable
    }

    /// Get escrow entry by ID
    pub fn getEscrow(self: *SlashingEscrow, escrow_id: u64) ?EscrowEntry {
        const entry = self.escrows.get(escrow_id) orelse return null;
        return entry;
    }

    pub fn getStats(self: *SlashingEscrow) EscrowStats {
        return self.stats;
    }

    fn decrementNodeCount(self: *SlashingEscrow, node_id: [32]u8) void {
        if (self.node_escrow_count.getPtr(node_id)) |count| {
            if (count.* > 0) count.* -= 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "create escrow and auto-execute on expiry" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.init(allocator);
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);

    const id = try escrow.createEscrow(node, 5_000_000, .pos_failure, 1000);
    try std.testing.expectEqual(@as(u64, 1), id);

    // Not resolvable yet (within dispute window)
    const early = escrow.resolveEscrow(id, 1000);
    try std.testing.expect(early == null);

    // After dispute window: auto-execute
    const result = escrow.resolveEscrow(id, 1000 + 86401);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(EscrowStatus.executed, result.?.status);
    try std.testing.expect(result.?.slash_executed);
    try std.testing.expectEqual(@as(u128, 5_000_000), result.?.amount_slashed_wei);
}

test "file dispute and governance overturn" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 86400,
        .min_governance_votes = 5,
        .overturn_threshold = 0.6,
        .max_escrows_per_node = 10,
        .frivolous_dispute_penalty_wei = 1_000,
    });
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xAA);

    const id = try escrow.createEscrow(node, 10_000, .data_corruption, 1000);

    // File dispute
    const dispute = escrow.fileDispute(id, evidence, 2000);
    try std.testing.expectEqual(DisputeResult.accepted, dispute);

    // 4 voters vote to overturn, 1 against
    for (0..4) |v| {
        var voter: [32]u8 = undefined;
        @memset(&voter, @intCast(v + 10));
        const vote_result = try escrow.vote(id, voter, true, 3000);
        try std.testing.expectEqual(VoteResult.accepted, vote_result);
    }
    var against: [32]u8 = undefined;
    @memset(&against, 50);
    const vote_result = try escrow.vote(id, against, false, 3000);
    try std.testing.expectEqual(VoteResult.accepted, vote_result);

    // Resolve: 4/5 = 0.8 >= 0.6 threshold → overturn
    const result = escrow.resolveEscrow(id, 4000);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(EscrowStatus.overturned, result.?.status);
    try std.testing.expect(!result.?.slash_executed);
    try std.testing.expectEqual(@as(u128, 10_000), result.?.amount_returned_wei);

    const stats = escrow.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.disputes_overturned);
    try std.testing.expectEqual(@as(u64, 5), stats.governance_votes_cast);
}

test "dispute rejected by governance" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 86400,
        .min_governance_votes = 5,
        .overturn_threshold = 0.667,
        .max_escrows_per_node = 10,
        .frivolous_dispute_penalty_wei = 1_000,
    });
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xBB);

    const id = try escrow.createEscrow(node, 8_000, .downtime, 1000);
    _ = escrow.fileDispute(id, evidence, 2000);

    // 1 votes overturn, 4 against
    for (0..4) |v| {
        var voter: [32]u8 = undefined;
        @memset(&voter, @intCast(v + 20));
        _ = try escrow.vote(id, voter, false, 3000);
    }
    var for_voter: [32]u8 = undefined;
    @memset(&for_voter, 99);
    _ = try escrow.vote(id, for_voter, true, 3000);

    // Resolve: 1/5 = 0.2 < 0.667 → slash executed
    const result = escrow.resolveEscrow(id, 4000);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(EscrowStatus.executed, result.?.status);
    try std.testing.expect(result.?.slash_executed);
    try std.testing.expectEqual(@as(u128, 8_000), result.?.amount_slashed_wei);
}

test "self-vote rejected" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.init(allocator);
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xCC);

    const id = try escrow.createEscrow(node, 5_000, .protocol_violation, 1000);
    _ = escrow.fileDispute(id, evidence, 2000);

    // Node tries to vote on its own dispute
    const result = try escrow.vote(id, node, true, 3000);
    try std.testing.expectEqual(VoteResult.rejected_self_vote, result);
}

test "double vote rejected" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.init(allocator);
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    var voter: [32]u8 = undefined;
    @memset(&voter, 2);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xDD);

    const id = try escrow.createEscrow(node, 5_000, .pos_failure, 1000);
    _ = escrow.fileDispute(id, evidence, 2000);

    const v1 = try escrow.vote(id, voter, true, 3000);
    try std.testing.expectEqual(VoteResult.accepted, v1);
    const v2 = try escrow.vote(id, voter, false, 3000);
    try std.testing.expectEqual(VoteResult.rejected_already_voted, v2);
}

test "max escrows per node limit" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.initWithConfig(allocator, .{
        .max_escrows_per_node = 2,
    });
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);

    _ = try escrow.createEscrow(node, 1_000, .pos_failure, 1000);
    _ = try escrow.createEscrow(node, 2_000, .downtime, 2000);

    // Third escrow should fail
    const result = escrow.createEscrow(node, 3_000, .data_corruption, 3000);
    try std.testing.expectError(error.MaxEscrowsReached, result);
}

test "expired dispute auto-executes" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 3600,
        .min_governance_votes = 10, // High threshold
    });
    defer escrow.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xEE);

    const id = try escrow.createEscrow(node, 7_000, .data_corruption, 1000);
    _ = escrow.fileDispute(id, evidence, 2000);

    // Only 2 votes (below min_governance_votes of 10)
    var v1: [32]u8 = undefined;
    @memset(&v1, 10);
    var v2: [32]u8 = undefined;
    @memset(&v2, 11);
    _ = try escrow.vote(id, v1, true, 2500);
    _ = try escrow.vote(id, v2, true, 2500);

    // After expiry: not enough votes → execute slash
    const result = escrow.resolveEscrow(id, 1000 + 3601);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(EscrowStatus.executed, result.?.status);
    try std.testing.expect(result.?.slash_executed);
}

test "escrow stats accumulate" {
    const allocator = std.testing.allocator;
    var escrow = SlashingEscrow.initWithConfig(allocator, .{
        .dispute_window_secs = 100,
        .min_governance_votes = 1,
        .overturn_threshold = 0.5,
        .max_escrows_per_node = 10,
        .frivolous_dispute_penalty_wei = 0,
    });
    defer escrow.deinit();

    var n1: [32]u8 = undefined;
    @memset(&n1, 1);
    var n2: [32]u8 = undefined;
    @memset(&n2, 2);
    var voter: [32]u8 = undefined;
    @memset(&voter, 10);
    var evidence: [32]u8 = undefined;
    @memset(&evidence, 0xFF);

    // Escrow 1: auto-execute (no dispute)
    const id1 = try escrow.createEscrow(n1, 1_000, .pos_failure, 100);
    _ = escrow.resolveEscrow(id1, 201); // expired

    // Escrow 2: dispute + overturn
    const id2 = try escrow.createEscrow(n2, 2_000, .downtime, 300);
    _ = escrow.fileDispute(id2, evidence, 350);
    _ = try escrow.vote(id2, voter, true, 360);
    _ = escrow.resolveEscrow(id2, 370);

    const stats = escrow.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_escrows);
    try std.testing.expectEqual(@as(u64, 1), stats.slashes_executed);
    try std.testing.expectEqual(@as(u64, 1), stats.disputes_overturned);
    try std.testing.expectEqual(@as(u128, 1_000), stats.total_slashed_wei);
    try std.testing.expectEqual(@as(u128, 2_000), stats.total_returned_wei);
}
