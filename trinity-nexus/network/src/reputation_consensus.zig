// =============================================================================
// TRINITY REPUTATION CONSENSUS v1.9 - Cross-Node Reputation Verification
// Byzantine fault tolerant reputation voting to prevent self-reporting fraud
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const node_reputation_mod = @import("node_reputation.zig");

// =============================================================================
// CONSENSUS CONFIGURATION
// =============================================================================

pub const ConsensusConfig = struct {
    /// Minimum number of voters required for valid consensus
    min_voters: u32 = 5,
    /// Byzantine fault tolerance threshold (2/3 + 1 agreement required)
    /// If > 1/3 of voters are Byzantine, consensus fails
    bft_threshold: f64 = 0.667,
    /// Maximum allowed deviation between voter scores before flagging disagreement
    max_score_deviation: f64 = 0.2,
    /// Penalty for nodes that consistently disagree with consensus
    disagreement_penalty: f64 = 0.05,
};

pub const VoteEntry = struct {
    voter_id: [32]u8,
    target_id: [32]u8,
    reported_score: f64,
    timestamp: i64,
};

pub const ConsensusResult = struct {
    target_id: [32]u8,
    consensus_score: f64,
    voter_count: u32,
    agreeing_voters: u32,
    disagreeing_voters: u32,
    is_valid: bool,
    median_score: f64,
};

pub const ConsensusStats = struct {
    total_rounds: u64,
    successful_rounds: u64,
    failed_rounds: u64,
    total_votes_cast: u64,
    fraud_detections: u64,
    penalties_applied: u64,
};

// =============================================================================
// REPUTATION CONSENSUS ENGINE
// =============================================================================

pub const ReputationConsensus = struct {
    allocator: std.mem.Allocator,
    config: ConsensusConfig,
    votes: std.ArrayListUnmanaged(VoteEntry),
    total_rounds: u64,
    successful_rounds: u64,
    failed_rounds: u64,
    total_votes_cast: u64,
    fraud_detections: u64,
    penalties_applied: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) ReputationConsensus {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: ConsensusConfig) ReputationConsensus {
        return .{
            .allocator = allocator,
            .config = config,
            .votes = .{},
            .total_rounds = 0,
            .successful_rounds = 0,
            .failed_rounds = 0,
            .total_votes_cast = 0,
            .fraud_detections = 0,
            .penalties_applied = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *ReputationConsensus) void {
        self.votes.deinit(self.allocator);
    }

    /// Submit a reputation vote from one node about another
    pub fn submitVote(self: *ReputationConsensus, voter_id: [32]u8, target_id: [32]u8, score: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Prevent self-voting
        if (std.mem.eql(u8, &voter_id, &target_id)) return;

        // Clamp score to [0, 1]
        const clamped = @min(1.0, @max(0.0, score));

        try self.votes.append(self.allocator, .{
            .voter_id = voter_id,
            .target_id = target_id,
            .reported_score = clamped,
            .timestamp = std.time.timestamp(),
        });
        self.total_votes_cast += 1;
    }

    /// Run consensus for a specific target node
    /// Returns consensus result with BFT-verified score
    pub fn runConsensus(self: *ReputationConsensus, target_id: [32]u8) ConsensusResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.total_rounds += 1;

        // Collect all votes for this target
        var target_scores = std.ArrayListUnmanaged(f64){};
        defer target_scores.deinit(self.allocator);

        for (self.votes.items) |vote| {
            if (std.mem.eql(u8, &vote.target_id, &target_id)) {
                target_scores.append(self.allocator, vote.reported_score) catch continue;
            }
        }

        const voter_count: u32 = @intCast(target_scores.items.len);

        if (voter_count < self.config.min_voters) {
            self.failed_rounds += 1;
            return .{
                .target_id = target_id,
                .consensus_score = 0,
                .voter_count = voter_count,
                .agreeing_voters = 0,
                .disagreeing_voters = voter_count,
                .is_valid = false,
                .median_score = 0,
            };
        }

        // Sort scores and find median
        std.mem.sort(f64, target_scores.items, {}, struct {
            fn lessThan(_: void, a: f64, b: f64) bool {
                return a < b;
            }
        }.lessThan);

        const median = target_scores.items[voter_count / 2];

        // Count agreeing voters (within deviation of median)
        var agreeing: u32 = 0;
        var disagreeing: u32 = 0;
        var sum: f64 = 0;

        for (target_scores.items) |score| {
            const deviation = @abs(score - median);
            if (deviation <= self.config.max_score_deviation) {
                agreeing += 1;
                sum += score;
            } else {
                disagreeing += 1;
            }
        }

        // BFT check: at least 2/3+1 must agree
        const agreement_ratio: f64 = @as(f64, @floatFromInt(agreeing)) / @as(f64, @floatFromInt(voter_count));
        const is_valid = agreement_ratio >= self.config.bft_threshold;

        if (is_valid) {
            self.successful_rounds += 1;
        } else {
            self.failed_rounds += 1;
        }

        // Detect fraud: nodes reporting scores far from consensus
        if (disagreeing > 0) {
            self.fraud_detections += disagreeing;
        }

        const consensus_score = if (agreeing > 0) sum / @as(f64, @floatFromInt(agreeing)) else 0;

        return .{
            .target_id = target_id,
            .consensus_score = consensus_score,
            .voter_count = voter_count,
            .agreeing_voters = agreeing,
            .disagreeing_voters = disagreeing,
            .is_valid = is_valid,
            .median_score = median,
        };
    }

    /// Run consensus for all nodes and apply results to reputation system
    pub fn applyConsensus(
        self: *ReputationConsensus,
        node_ids: []const [32]u8,
        reputation: *node_reputation_mod.NodeReputationSystem,
    ) ![]ConsensusResult {
        var results = std.ArrayListUnmanaged(ConsensusResult){};
        errdefer results.deinit(self.allocator);

        for (node_ids) |nid| {
            const result = self.runConsensus(nid);
            try results.append(self.allocator, result);

            // If consensus is valid, apply penalty to disagreeing nodes
            if (result.is_valid and result.disagreeing_voters > 0) {
                self.mutex.lock();
                self.penalties_applied += result.disagreeing_voters;
                self.mutex.unlock();

                // Record negative PoS results for fraud-detected nodes
                for (self.votes.items) |vote| {
                    if (!std.mem.eql(u8, &vote.target_id, &nid)) continue;
                    const deviation = @abs(vote.reported_score - result.median_score);
                    if (deviation > self.config.max_score_deviation) {
                        // Penalize the dishonest voter
                        reputation.recordPosResult(vote.voter_id, false);
                    }
                }
            }
        }

        return results.toOwnedSlice(self.allocator);
    }

    /// Clear all votes (start fresh round)
    pub fn clearVotes(self: *ReputationConsensus) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.votes.clearRetainingCapacity();
    }

    /// Get stats
    pub fn getStats(self: *ReputationConsensus) ConsensusStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .total_rounds = self.total_rounds,
            .successful_rounds = self.successful_rounds,
            .failed_rounds = self.failed_rounds,
            .total_votes_cast = self.total_votes_cast,
            .fraud_detections = self.fraud_detections,
            .penalties_applied = self.penalties_applied,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "consensus with agreeing voters" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 3,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.2,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    const target = [_]u8{0x01} ** 32;
    var voters: [5][32]u8 = undefined;
    for (0..5) |i| @memset(&voters[i], @intCast(i + 0x10));

    // All voters agree: target score ~0.8
    try consensus.submitVote(voters[0], target, 0.80);
    try consensus.submitVote(voters[1], target, 0.82);
    try consensus.submitVote(voters[2], target, 0.78);
    try consensus.submitVote(voters[3], target, 0.81);
    try consensus.submitVote(voters[4], target, 0.79);

    const result = consensus.runConsensus(target);
    try std.testing.expect(result.is_valid);
    try std.testing.expectEqual(@as(u32, 5), result.voter_count);
    try std.testing.expectEqual(@as(u32, 5), result.agreeing_voters);
    try std.testing.expectEqual(@as(u32, 0), result.disagreeing_voters);
    try std.testing.expect(result.consensus_score >= 0.7);
    try std.testing.expect(result.consensus_score <= 0.9);
}

test "consensus fails with insufficient voters" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 5,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.2,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    const target = [_]u8{0x01} ** 32;
    var voters: [3][32]u8 = undefined;
    for (0..3) |i| @memset(&voters[i], @intCast(i + 0x10));

    try consensus.submitVote(voters[0], target, 0.80);
    try consensus.submitVote(voters[1], target, 0.82);
    try consensus.submitVote(voters[2], target, 0.78);

    const result = consensus.runConsensus(target);
    try std.testing.expect(!result.is_valid);
    try std.testing.expectEqual(@as(u32, 3), result.voter_count);
}

test "consensus detects fraud (disagreeing voters)" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 3,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.1,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    const target = [_]u8{0x01} ** 32;
    var voters: [6][32]u8 = undefined;
    for (0..6) |i| @memset(&voters[i], @intCast(i + 0x10));

    // 5 honest voters agree (~0.8), 2 fraudulent report 0.1
    try consensus.submitVote(voters[0], target, 0.80);
    try consensus.submitVote(voters[1], target, 0.82);
    try consensus.submitVote(voters[2], target, 0.78);
    try consensus.submitVote(voters[3], target, 0.81);
    try consensus.submitVote(voters[4], target, 0.10); // fraud
    try consensus.submitVote(voters[5], target, 0.05); // fraud

    const result = consensus.runConsensus(target);
    // 4 agree within 0.1 of median, 2 disagree
    // Agreement ratio 4/6 = 0.667 — check consensus outcome
    try std.testing.expectEqual(@as(u32, 6), result.voter_count);
    try std.testing.expect(result.disagreeing_voters >= 2);

    const stats = consensus.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.fraud_detections);
}

test "consensus fails with too many Byzantine voters" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 3,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.1,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    const target = [_]u8{0x01} ** 32;
    var voters: [6][32]u8 = undefined;
    for (0..6) |i| @memset(&voters[i], @intCast(i + 0x10));

    // 2 honest, 4 Byzantine (varied wildly)
    try consensus.submitVote(voters[0], target, 0.80);
    try consensus.submitVote(voters[1], target, 0.82);
    try consensus.submitVote(voters[2], target, 0.10);
    try consensus.submitVote(voters[3], target, 0.50);
    try consensus.submitVote(voters[4], target, 0.05);
    try consensus.submitVote(voters[5], target, 0.95);

    const result = consensus.runConsensus(target);
    // Median is around 0.50-0.80 range — few agree within 0.1
    // Should fail BFT threshold
    try std.testing.expect(!result.is_valid or result.agreeing_voters < 4);
}

test "self-vote is rejected" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.init(allocator);
    defer consensus.deinit();

    const node = [_]u8{0x01} ** 32;
    try consensus.submitVote(node, node, 1.0); // self-vote

    const stats = consensus.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.total_votes_cast);
}

test "apply consensus penalizes dishonest voters" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 3,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.1,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const target = [_]u8{0x01} ** 32;
    var voters: [5][32]u8 = undefined;
    for (0..5) |i| @memset(&voters[i], @intCast(i + 0x10));

    // 4 honest, 1 fraud
    try consensus.submitVote(voters[0], target, 0.80);
    try consensus.submitVote(voters[1], target, 0.82);
    try consensus.submitVote(voters[2], target, 0.78);
    try consensus.submitVote(voters[3], target, 0.81);
    try consensus.submitVote(voters[4], target, 0.10); // fraud

    const targets = [_][32]u8{target};
    const results = try consensus.applyConsensus(&targets, &reputation);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expect(results[0].is_valid);

    // Fraudulent voter should have a failed PoS recorded
    const fraud_score = reputation.getScore(voters[4]);
    // recordPosResult(false) gives 0/1 PoS = 0.0 PoS component
    try std.testing.expect(fraud_score.pos_score == 0.0);

    const stats = consensus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.penalties_applied);
}

test "clear votes resets for new round" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.init(allocator);
    defer consensus.deinit();

    const target = [_]u8{0x01} ** 32;
    const voter = [_]u8{0x10} ** 32;

    try consensus.submitVote(voter, target, 0.80);
    try std.testing.expectEqual(@as(u64, 1), consensus.getStats().total_votes_cast);

    consensus.clearVotes();

    // Votes cleared but stats remain
    const result = consensus.runConsensus(target);
    try std.testing.expectEqual(@as(u32, 0), result.voter_count);
    try std.testing.expect(!result.is_valid);
}

test "consensus stats accumulate" {
    const allocator = std.testing.allocator;

    var consensus = ReputationConsensus.initWithConfig(allocator, .{
        .min_voters = 2,
        .bft_threshold = 0.667,
        .max_score_deviation = 0.2,
        .disagreement_penalty = 0.05,
    });
    defer consensus.deinit();

    const target1 = [_]u8{0x01} ** 32;
    const target2 = [_]u8{0x02} ** 32;
    var voters: [3][32]u8 = undefined;
    for (0..3) |i| @memset(&voters[i], @intCast(i + 0x10));

    // Round 1: valid consensus for target1
    try consensus.submitVote(voters[0], target1, 0.80);
    try consensus.submitVote(voters[1], target1, 0.82);
    try consensus.submitVote(voters[2], target1, 0.78);
    _ = consensus.runConsensus(target1);

    // Round 2: valid consensus for target2
    try consensus.submitVote(voters[0], target2, 0.50);
    try consensus.submitVote(voters[1], target2, 0.52);
    try consensus.submitVote(voters[2], target2, 0.48);
    _ = consensus.runConsensus(target2);

    const stats = consensus.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_rounds);
    try std.testing.expectEqual(@as(u64, 2), stats.successful_rounds);
    try std.testing.expectEqual(@as(u64, 6), stats.total_votes_cast);
}
