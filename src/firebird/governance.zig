// @origin(spec:depin_governance.tri) @regen(manual-impl)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════
// Phase 5: Governance Module — DAO for Slash Appeals
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// GOVERNANCE TYPES
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const SlashAppeal = struct {
    appeal_id: []const u8,
    slashed_node: [20]u8,
    original_violation: []const u8,
    appeal_reason: []const u8,
    evidence_urls: std.ArrayListUnmanaged([]const u8),
    appellant: [20]u8,
    created_at: i64,
    status: AppealStatus,
    voting_deadline: i64,
    votes_for: usize,
    votes_against: usize,
    required_quorum: usize,
};

pub const AppealStatus = enum {
    pending,
    voting,
    approved, // Slash overturned
    rejected, // Slash upheld
    executed,
};

pub const ParameterChangeProposal = struct {
    proposal_id: []const u8,
    parameter_name: []const u8,
    old_value: []const u8,
    new_value: []const u8,
    reason: []const u8,
    proposer: [20]u8,
    created_at: i64,
    voting_end_at: i64,
    status: ProposalStatus,
};

pub const ProposalStatus = enum {
    active,
    passed,
    rejected,
    executed,
    cancelled,
};

pub const Vote = struct {
    voter: [20]u8,
    proposal_id: []const u8,
    support: bool,
    timestamp: i64,
    stake_weight: u128,
};

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// GOVERNANCE CONFIG
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const GovernanceConfig = struct {
    // Voting parameters
    const VOTING_PERIOD_HOURS: u64 = 72; // 3 days
    const EXECUTION_DELAY_HOURS: u64 = 24; // 1 day after voting ends
    const APPEAL_DEADLINE_HOURS: u64 = 168; // 7 days to submit appeal
    const MIN_STAKE_FOR_VOTE: u128 = 100 * std.math.pow(u128, 10, 18); // 100 TRI

    // Quorum requirements
    const PARAM_CHANGE_QUORUM: f64 = 0.60; // 60%
    const SLASH_APPEAL_QUORUM: f64 = 0.75; // 75% needed to overturn

    // Slash parameters
    const APPEAL_COST: u128 = 10 * std.math.pow(u128, 10, 18); // 10 TRI cost to appeal
    const APPEAL_REWARD: u128 = 1000 * std.math.pow(u128, 10, 18); // 1000 TRI if appeal succeeds

    // Governor limits
    const MAX_PROPOSALS_PER_WEEK: usize = 10;
    const MAX_APPEALS_PER_MONTH: usize = 3;
};

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// GOVERNANCE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const GovernanceManager = struct {
    allocator: Allocator,
    appeals: std.StringHashMapUnmanaged(SlashAppeal),
    proposals: std.StringHashMapUnmanaged(ParameterChangeProposal),
    votes: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(Vote)),
    governance_token: [20]u8, // TRI token contract address

    pub fn init(allocator: Allocator) GovernanceManager {
        return GovernanceManager{
            .allocator = allocator,
            .appeals = .{},
            .proposals = .{},
            .votes = std.StringHashMapUnmanaged(std.ArrayListUnmanaged(Vote)).init(allocator),
            .governance_token = undefined, // Set in production
        };
    }

    /// Submit slash appeal
    pub fn submitAppeal(
        self: *GovernanceManager,
        slashed_node: [20]u8,
        original_violation: []const u8,
        appeal_reason: []const u8,
        evidence_urls: []const []const u8,
        appellant: [20]u8,
    ) ![]const u8 {
        const appeal_id = try std.fmt.allocPrint(self.allocator, "appeal_{d}_{x}", .{
            std.time.timestamp(), std.math.maxInt(u64),
        });

        var evidence_list = std.ArrayListUnmanaged([]const u8).init(self.allocator);
        for (evidence_urls) |url| {
            const duped = try self.allocator.dupe(u8, url);
            try evidence_list.append(self.allocator, duped);
        }

        const appeal = SlashAppeal{
            .appeal_id = appeal_id,
            .slashed_node = slashed_node,
            .original_violation = original_violation,
            .appeal_reason = appeal_reason,
            .evidence_urls = evidence_list,
            .appellant = appellant,
            .created_at = std.time.timestamp(),
            .status = .pending,
            .voting_deadline = std.time.timestamp() + GovernanceConfig.APPEAL_DEADLINE_HOURS * 3600,
            .votes_for = 0,
            .votes_against = 0,
            .required_quorum = @intFromFloat(GovernanceConfig.SLASH_APPEAL_QUORUM * 100.0),
        };

        try self.appeals.put(self.allocator, appeal_id, appeal);

        std.log.info("GOVERNANCE: Submitted appeal {s} for violation {s}", .{
            appeal_id, original_violation,
        });

        return appeal_id;
    }

    /// Vote on appeal
    pub fn voteOnAppeal(
        self: *GovernanceManager,
        appeal_id: []const u8,
        voter: [20]u8,
        support: bool,
        stake_weight: u128,
    ) !void {
        const appeal = self.appeals.get(appeal_id) orelse return error.AppealNotFound;
        if (appeal.status != .voting and appeal.status != .pending) {
            return error.AppealNotVoting;
        }

        if (std.time.timestamp() > appeal.voting_deadline) {
            return error.VotingExpired;
        }

        const vote = Vote{
            .voter = voter,
            .proposal_id = appeal_id,
            .support = support,
            .timestamp = std.time.timestamp(),
            .stake_weight = stake_weight,
        };

        // Add vote to proposal
        if (self.votes.get(appeal_id)) |*vote_list| {
            try vote_list.append(self.allocator, vote);
        } else {
            var list = std.ArrayListUnmanaged(Vote).init(self.allocator);
            try list.append(self.allocator, vote);
            try self.votes.put(self.allocator, appeal_id, list);
        }

        // Update appeal vote counts
        if (self.appeals.getEntry(appeal_id)) |entry| {
            if (support) {
                entry.value_ptr.votes_for += 1;
            } else {
                entry.value_ptr.votes_against += 1;
            }
        }

        // Check if quorum reached
        const total_votes = entry.value_ptr.votes_for + entry.value_ptr.votes_against;
        if (total_votes >= entry.value_ptr.required_quorum) {
            const support_ratio = @as(f64, @floatFromInt(entry.value_ptr.votes_for * 100)) / @as(f64, @floatFromInt(total_votes));
            if (support_ratio >= GovernanceConfig.SLASH_APPEAL_QUORUM * 100.0) {
                // Appeal approved - overturn slash
                entry.value_ptr.status = .approved;
                std.log.info("GOVERNANCE: Appeal {s} approved - slash overturned", .{appeal_id});
            } else {
                // Appeal rejected - slash upheld
                entry.value_ptr.status = .rejected;
                std.log.info("GOVERNANCE: Appeal {s} rejected - slash upheld", .{appeal_id});
            }
        }
    }

    /// Submit parameter change proposal
    pub fn submitProposal(
        self: *GovernanceManager,
        parameter_name: []const u8,
        old_value: []const u8,
        new_value: []const u8,
        reason: []const u8,
        proposer: [20]u8,
    ) ![]const u8 {
        const proposal_id = try std.fmt.allocPrint(self.allocator, "param_{d}_{x}", .{
            std.time.timestamp(), std.math.maxInt(u64),
        });

        const proposal = ParameterChangeProposal{
            .proposal_id = proposal_id,
            .parameter_name = parameter_name,
            .old_value = old_value,
            .new_value = new_value,
            .reason = reason,
            .proposer = proposer,
            .created_at = std.time.timestamp(),
            .voting_end_at = std.time.timestamp() + GovernanceConfig.VOTING_PERIOD_HOURS * 3600,
            .status = .active,
        };

        try self.proposals.put(self.allocator, proposal_id, proposal);

        std.log.info("GOVERNANCE: Submitted proposal {s} to change {s}", .{
            proposal_id, parameter_name,
        });

        return proposal_id;
    }

    /// Execute passed proposal
    pub fn executeProposal(self: *GovernanceManager, proposal_id: []const u8) !void {
        const proposal = self.proposals.get(proposal_id) orelse return error.ProposalNotFound;

        if (proposal.status != .passed) {
            return error.ProposalNotPassed;
        }

        proposal.status = .executed;

        std.log.info("GOVERNANCE: Executed proposal {s} - {s}: {s}", .{
            proposal_id, proposal.parameter_name, proposal.new_value,
        });
    }

    /// Get appeal by ID
    pub fn getAppeal(self: *const GovernanceManager, appeal_id: []const u8) ?SlashAppeal {
        return self.appeals.get(appeal_id);
    }

    /// Get all active appeals
    pub fn getActiveAppeals(self: *const GovernanceManager, allocator: Allocator) ![]SlashAppeal {
        var result = std.ArrayList(SlashAppeal).init(allocator);
        var iter = self.appeals.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.status == .voting or entry.value_ptr.status == .pending) {
                try result.append(entry.value_ptr.*);
            }
        }
        return result.toOwnedSlice();
    }

    pub fn deinit(self: *GovernanceManager) void {
        var iter = self.appeals.iterator();
        while (iter.next()) |entry| {
            const appeal = entry.value_ptr;
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(appeal.appeal_id);
            self.allocator.free(appeal.original_violation);
            self.allocator.free(appeal.appeal_reason);
            for (appeal.evidence_urls.items) |*url| {
                self.allocator.free(url.*);
            }
            appeal.evidence_urls.deinit(self.allocator);
        }
        self.appeals.deinit(self.allocator);

        iter = self.proposals.iterator();
        while (iter.next()) |entry| {
            const proposal = entry.value_ptr;
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(proposal.parameter_name);
            self.allocator.free(proposal.old_value);
            self.allocator.free(proposal.new_value);
            self.allocator.free(proposal.reason);
            self.allocator.free(proposal.proposal_id);
        }
        self.proposals.deinit(self.allocator);

        iter = self.votes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            const vote_list = entry.value_ptr;
            for (vote_list.items) |*vote| {
                self.allocator.free(vote.voter);
            }
            vote_list.deinit(self.allocator);
        }
        self.votes.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "submit appeal" {
    const allocator = std.testing.allocator;
    var gov = GovernanceManager.init(allocator);
    defer gov.deinit();

    var node: [20]u8 = undefined;
    @memset(&node, 0);

    const appeal_id = try gov.submitAppeal(
        node,
        "downtime",
        "False positive - node was online",
        "Node was online during downtime window",
        &[_][]const u8{},
        node,
    );

    try std.testing.expect(appeal_id.len > 0);
}

test "vote on appeal" {
    const allocator = std.testing.allocator;
    var gov = GovernanceManager.init(allocator);
    defer gov.deinit();

    var node: [20]u8 = undefined;
    @memset(&node, 0);

    const appeal_id = try gov.submitAppeal(
        node,
        "downtime",
        "False positive",
        "False positive",
        &[_][]const u8{},
        node,
    );

    var voter: [20]u8 = undefined;
    @memset(&voter, 0);
    voter[0] = 0xAA;

    try gov.voteOnAppeal(appeal_id, voter, true, 1000);

    const appeal = gov.getAppeal(appeal_id).?;
    try std.testing.expectEqual(@as(usize, 1), appeal.votes_for);
}

test "submit parameter proposal" {
    const allocator = std.testing.allocator;
    var gov = GovernanceManager.init(allocator);
    defer gov.deinit();

    var proposer: [20]u8 = undefined;
    @memset(&proposer, 0);
    proposer[0] = 0xBB;

    const proposal_id = try gov.submitProposal(
        "MIN_STAKE",
        "100",
        "50",
        "Lower minimum stake for testing",
        proposer,
    );

    try std.testing.expect(proposal_id.len > 0);
}
