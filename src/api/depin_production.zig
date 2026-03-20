// @origin(spec:depin_production_api.tri) @regen(manual-impl)
// ═════════════════════════════════════════════════════════════════════════════════════════════════
// Phase 5: Production REST API Extension
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═════════════════════════════════════════════════════════════════════════════════════════════════
// PRODUCTION API TYPES
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const ProductionApiServer = struct {
    allocator: Allocator,
    port: u16,
    stakes: std.StringHashMapUnmanaged(StakeInfo),
    pending_rewards: std.StringHashMapUnmanaged(RewardInfo),
    governance: std.StringHashMapUnmanaged(GovernanceProposal),

    pub fn init(allocator: Allocator, port: u16) ProductionApiServer {
        return ProductionApiServer{
            .allocator = allocator,
            .port = port,
            .stakes = .{},
            .pending_rewards = .{},
            .governance = .{},
        };
    }

    /// Get all stakes
    pub fn getAllStakes(self: *const ProductionApiServer) ![]const StakeInfo {
        var result = std.ArrayList(StakeInfo).initCapacity(self.allocator, @intCast(self.stakes.count()));
        var iter = self.stakes.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.value_ptr.*);
        }
        return result.toOwnedSlice();
    }

    /// Add stake record
    pub fn addStake(self: *ProductionApiServer, stake: StakeInfo) !void {
        const stake_id = try std.fmt.allocPrint(self.allocator, "{x}", .{stake.address});
        try self.stakes.put(self.allocator, stake_id, stake);
    }

    /// Get pending rewards
    pub fn getPendingRewards(self: *const ProductionApiServer, address: [20]u8) ![]const RewardInfo {
        var result = std.ArrayList(RewardInfo).initCapacity(self.allocator, @intCast(self.pending_rewards.count()));
        var iter = self.pending_rewards.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.recipient, &address)) {
                try result.append(entry.value_ptr.*);
            }
        }
        return result.toOwnedSlice();
    }

    /// Claim rewards
    pub fn claimRewards(self: *ProductionApiServer, address: [20]u8) !u128 {
        var total: u128 = 0;
        var iter = self.pending_rewards.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.recipient, &address)) {
                total += entry.value_ptr.amount;
                _ = self.pending_rewards.remove(entry.key_ptr.*);
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.recipient);
            }
        }
        return total;
    }

    /// Create governance proposal
    pub fn createProposal(self: *ProductionApiServer, proposal: GovernanceProposal) ![]const u8 {
        const proposal_id = try std.fmt.allocPrint(self.allocator, "gov_{d}", .{std.time.timestamp()});
        try self.governance.put(self.allocator, proposal_id, proposal);
        return proposal_id;
    }

    /// Vote on proposal
    pub fn vote(self: *ProductionApiServer, proposal_id: []const u8, voter: [20]u8, support: bool) !void {
        if (self.governance.getEntry(proposal_id)) |entry| {
            const vote_record = VoteRecord{
                .voter = voter,
                .support = support,
                .timestamp = std.time.timestamp(),
            };
            try entry.value_ptr.votes.append(self.allocator, vote_record);
        }
    }

    /// Get proposal status
    pub fn getProposalStatus(self: *const ProductionApiServer, proposal_id: []const u8) ?ProposalStatus {
        return if (self.governance.get(proposal_id)) |proposal| {
            const support_count: usize = 0;
            const against_count: usize = 0;

            for (proposal.votes.items) |v| {
                if (v.support) support_count += 1 else against_count += 1;
            }

            const total_votes = support_count + against_count;
            return ProposalStatus{
                .proposal_id = proposal_id,
                .title = proposal.title,
                .status = proposal.status,
                .support_votes = support_count,
                .against_votes = against_count,
                .total_votes = total_votes,
                .approval_percentage = @as(f64, @floatFromInt(support_count * 100)) / @as(f64, @floatFromInt(total_votes)),
            };
        } else null;
    }

    pub fn deinit(self: *ProductionApiServer) void {
        var iter = self.stakes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.stakes.deinit(self.allocator);

        {
            var iter2 = self.pending_rewards.iterator();
            while (iter2.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.recipient);
            }
        }
        self.pending_rewards.deinit(self.allocator);

        {
            var iter2 = self.governance.iterator();
            while (iter2.next()) |entry| {
                const proposal = entry.value_ptr;
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(proposal.title);
                self.allocator.free(proposal.description);
                for (proposal.votes.items) |*v| {
                    self.allocator.free(v.voter);
                }
                proposal.votes.deinit(self.allocator);
            }
        }
        self.governance.deinit(self.allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════
// API TYPES
// ═════════════════════════════════════════════════════════════════════════════════════════════════════

pub const StakeInfo = struct {
    address: [20]u8,
    amount: u128,
    lock_period: []const u8,
    unlock_time: i64,
    is_delegated: bool,
    quality_score: f64,
};

pub const RewardInfo = struct {
    recipient: [20]u8,
    amount: u128,
    operation_type: []const u8,
    pending_since: i64,
};

pub const GovernanceProposal = struct {
    proposal_id: []const u8,
    title: []const u8,
    description: []const u8,
    proposal_type: ProposalType,
    proposer: [20]u8,
    start_time: i64,
    end_time: i64,
    status: ProposalStatus,
    votes: std.ArrayListUnmanaged(VoteRecord),
};

pub const ProposalType = enum {
    parameter_change,
    slashing_appeal,
    new_feature,
    grant_request,
};

pub const ProposalStatus = enum {
    active,
    passed,
    rejected,
    executed,
    cancelled,
};

pub const VoteRecord = struct {
    voter: [20]u8,
    support: bool,
    timestamp: i64,
};

pub const ProposalStatusResponse = struct {
    proposal_id: []const u8,
    title: []const u8,
    status: ProposalStatus,
    support_votes: usize,
    against_votes: usize,
    total_votes: usize,
    approval_percentage: f64,
};

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "ProductionApiServer init" {
    const allocator = std.testing.allocator;
    const server = ProductionApiServer.init(allocator, 8080);
    try std.testing.expectEqual(@as(u16, 8080), server.port);
}

test "add and get stake" {
    const allocator = std.testing.allocator;
    var server = ProductionApiServer.init(allocator, 8080);
    defer server.deinit();

    var address: [20]u8 = undefined;
    @memset(&address, 0);

    const stake = StakeInfo{
        .address = address,
        .amount = 1000,
        .lock_period = "6M",
        .unlock_time = std.time.timestamp() + 86400,
        .is_delegated = false,
        .quality_score = 0.85,
    };

    try server.addStake(stake);
    const stakes = try server.getAllStakes();
    defer allocator.free(stakes);

    try std.testing.expectEqual(@as(usize, 1), stakes.len);
}

test "governance proposal" {
    const allocator = std.testing.allocator;
    var server = ProductionApiServer.init(allocator, 8080);
    defer server.deinit();

    var proposer: [20]u8 = undefined;
    @memset(&proposer, 0);

    const proposal = GovernanceProposal{
        .proposal_id = "test_proposal",
        .title = "Test Proposal",
        .description = "Test description",
        .proposal_type = .parameter_change,
        .proposer = proposer,
        .start_time = std.time.timestamp(),
        .end_time = std.time.timestamp() + 86400,
        .status = .active,
        .votes = .{},
    };

    const proposal_id = try server.createProposal(proposal);
    defer allocator.free(proposal_id);

    // Add some votes
    var voter1: [20]u8 = undefined;
    @memset(&voter1, 0);
    voter1[0] = 0x11;

    try server.vote(proposal_id, voter1, true);

    const status = server.getProposalStatus(proposal_id).?;
    try std.testing.expectEqual(@as(usize, 1), status.support_votes);
}
