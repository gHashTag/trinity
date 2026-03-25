// =============================================================================
// TRINITY REPUTATION v2.1 - Reward Multipliers with Hysteresis
// Adds reputation-based reward multipliers to incentivize long-term operators
// v2.1: Added hysteresis deadband (±0.02) to prevent oscillation at tier boundaries
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// REPUTATION CONFIGURATION
// =============================================================================

/// Deadband size to prevent oscillation at tier boundaries
pub const DEADBAND: f64 = 0.02;

/// Reputation tier with associated reward multiplier
pub const ReputationTier = enum(u8) {
    /// < 0.5: Poor reputation - 0.5x rewards
    bronze = 0,
    /// 0.5 - 0.7: Baseline reputation - 1.0x rewards
    silver = 1,
    /// 0.7 - 0.9: Good reputation - 1.5x rewards
    gold = 2,
    /// 0.9+: Excellent reputation - 2.0x rewards
    platinum = 3,

    /// Get tier from reputation score
    pub fn fromScore(score: f64) ReputationTier {
        if (score >= 0.9) return .platinum;
        if (score >= 0.7) return .gold;
        if (score >= 0.5) return .silver;
        return .bronze;
    }

    /// v2.1: Get tier with hysteresis to prevent oscillation
    /// Uses previous tier to create deadband at boundaries
    /// Upgrade requires threshold + deadband, downgrade requires threshold - deadband
    pub fn fromScoreWithHysteresis(score: f64, prev_tier: ReputationTier) ReputationTier {
        return switch (prev_tier) {
            // Platinum: downgrade only if score < 0.9 - DEADBAND
            .platinum => if (score >= 0.9 - DEADBAND) .platinum else if (score >= 0.7) .gold else .silver,
            // Gold: downgrade if < 0.7 - DEADBAND, upgrade if >= 0.9 + DEADBAND
            .gold => if (score >= 0.9 + DEADBAND) .platinum else if (score >= 0.7 - DEADBAND) .gold else if (score >= 0.5) .silver else .bronze,
            // Silver: downgrade if < 0.5 - DEADBAND, upgrade if >= 0.7 + DEADBAND
            .silver => if (score >= 0.7 + DEADBAND) .gold else if (score >= 0.5 - DEADBAND) .silver else .bronze,
            // Bronze: upgrade if >= 0.5 + DEADBAND
            .bronze => if (score >= 0.5 + DEADBAND) .silver else if (score >= 0.9) .gold else .bronze,
        };
    }

    /// Get reward multiplier for this tier
    pub fn multiplier(self: ReputationTier) f64 {
        return switch (self) {
            .bronze => 0.5,
            .silver => 1.0,
            .gold => 1.5,
            .platinum => 2.0,
        };
    }

    /// Get human-readable description
    pub fn description(self: ReputationTier) []const u8 {
        return switch (self) {
            .bronze => "Bronze (0.5x rewards)",
            .silver => "Silver (1.0x rewards)",
            .gold => "Gold (1.5x rewards)",
            .platinum => "Platinum (2.0x rewards)",
        };
    }
};

// =============================================================================
// REPUTATION SCORE
// =============================================================================

/// Extended reputation score with reward calculation
pub const ReputationScore = struct {
    node_id: [32]u8,
    score: f64 = 0.5, // 0.0 - 1.0
    age: u64 = 0, // Time since first stake (seconds)
    slash_count: u32 = 0,
    uptime_pct: f32 = 0.0, // 0.0 - 1.0
    last_update: i64 = 0,
    /// v2.0: Total rewards earned (tracking for tier progression)
    total_rewards_wei: u128 = 0,
    /// v2.0: Staking duration bonus factor
    staking_duration_months: u32 = 0,
    /// v2.1: Previous tier for hysteresis (prevents oscillation)
    prev_tier: ReputationTier = .silver,

    /// Get current reputation tier (with hysteresis)
    pub fn getTier(self: *const ReputationScore) ReputationTier {
        return ReputationTier.fromScoreWithHysteresis(self.score, self.prev_tier);
    }

    /// Get reward multiplier for this node
    pub fn getMultiplier(self: *const ReputationScore) f64 {
        return self.getTier().multiplier();
    }

    /// Calculate adjusted reward with reputation multiplier applied
    pub fn adjustReward(self: *const ReputationScore, base_reward_wei: u128) u128 {
        const mult = self.getMultiplier();
        const adjusted_f: f64 = @as(f64, @floatFromInt(base_reward_wei)) * mult;
        return @intFromFloat(adjusted_f);
    }
};

// =============================================================================
// REPUTATION ENGINE
// =============================================================================

pub const ReputationEngine = struct {
    allocator: std.mem.Allocator,
    scores: std.AutoHashMap([32]u8, ReputationScore),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) ReputationEngine {
        return .{
            .allocator = allocator,
            .scores = std.AutoHashMap([32]u8, ReputationScore).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *ReputationEngine) void {
        self.scores.deinit();
    }

    /// Get or create reputation entry for a node
    pub fn getOrCreate(self: *ReputationEngine, node_id: [32]u8) !*ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = try self.scores.getOrPut(node_id);
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .node_id = node_id,
                .score = 0.5, // Start at baseline
                .last_update = std.time.timestamp(),
            };
        }
        return result.value_ptr;
    }

    /// Get reputation entry (returns null if not found)
    pub fn get(self: *ReputationEngine, node_id: [32]u8) ?*ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.scores.getPtr(node_id);
    }

    /// Update reputation score
    pub fn updateScore(self: *ReputationEngine, node_id: [32]u8, new_score: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = try self.scores.getOrPut(node_id);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .node_id = node_id,
                .last_update = std.time.timestamp(),
                .prev_tier = ReputationTier.fromScore(new_score), // Initial tier
            };
        }

        // Get current tier before update (for hysteresis)
        const old_tier = entry.value_ptr.prev_tier;

        // Clamp score to [0, 1]
        const clamped = @max(0.0, @min(1.0, new_score));
        entry.value_ptr.score = clamped;
        entry.value_ptr.last_update = std.time.timestamp();

        // Update tier with hysteresis
        entry.value_ptr.prev_tier = ReputationTier.fromScoreWithHysteresis(clamped, old_tier);
    }

    /// Record a reward earned by a node (affects reputation tracking)
    pub fn recordReward(self: *ReputationEngine, node_id: [32]u8, amount_wei: u128) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = try self.scores.getOrPut(node_id);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .node_id = node_id,
                .last_update = std.time.timestamp(),
            };
        }

        entry.value_ptr.total_rewards_wei += amount_wei;
        entry.value_ptr.last_update = std.time.timestamp();
    }

    /// Record a slash event (reduces reputation)
    pub fn recordSlash(self: *ReputationEngine, node_id: [32]u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = try self.scores.getOrPut(node_id);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .node_id = node_id,
                .last_update = std.time.timestamp(),
            };
        }

        entry.value_ptr.slash_count += 1;

        // Reduce score based on slash count
        // 1 slash: -0.05, 2 slashes: -0.10, 3+: -0.20
        const penalty: f64 = if (entry.value_ptr.slash_count == 1)
            0.05
        else if (entry.value_ptr.slash_count == 2)
            0.10
        else
            0.20;

        entry.value_ptr.score = @max(0.0, entry.value_ptr.score - penalty);
        entry.value_ptr.last_update = std.time.timestamp();
    }

    /// Update uptime percentage for a node
    pub fn updateUptime(self: *ReputationEngine, node_id: [32]u8, uptime_pct: f32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = try self.scores.getOrPut(node_id);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .node_id = node_id,
                .uptime_pct = uptime_pct,
                .last_update = std.time.timestamp(),
            };
        }

        entry.value_ptr.uptime_pct = @max(0.0, @min(1.0, uptime_pct));
        entry.value_ptr.last_update = std.time.timestamp();
    }

    /// Calculate adjusted reward with reputation multiplier
    pub fn calculateReward(self: *ReputationEngine, node_id: [32]u8, base_reward_wei: u128) !u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.scores.get(node_id) orelse return base_reward_wei; // No multiplier for unknown nodes
        return entry.adjustReward(base_reward_wei);
    }

    /// Get all nodes sorted by reputation score (descending)
    pub fn rankNodes(self: *ReputationEngine, allocator: std.mem.Allocator) ![]ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged(ReputationScore){};
        errdefer result.deinit(allocator);

        var iter = self.scores.valueIterator();
        while (iter.next()) |score| {
            try result.append(allocator, score.*);
        }

        // Sort descending by score
        std.mem.sort(ReputationScore, result.items, {}, struct {
            fn cmp(_: void, a: ReputationScore, b: ReputationScore) bool {
                return a.score > b.score;
            }
        }.cmp);

        return result.toOwnedSlice(allocator);
    }

    // =========================================================================
    // v3.0: GOVERNANCE POWER INTEGRATION
    // =========================================================================

    /// Governance power from reputation + stake (Theta network model)
    pub const GovernancePower = struct {
        voting_weight: u128, // Combined stake × reputation multiplier (18 decimals)
        proposal_threshold: u128, // Minimum stake to propose
        can_vote: bool,
        can_propose: bool,
    };

    /// Get governance power for a node based on reputation and stake
    /// @param node_id Node identifier
    /// @param stake_wei Amount of $TRI staked (18 decimals)
    /// @return Governance power with voting weight and proposal rights
    pub fn getGovernancePower(self: *ReputationEngine, node_id: [32]u8, stake_wei: u128) GovernancePower {
        const score = self.scores.get(node_id) orelse return .{
            .voting_weight = 0,
            .proposal_threshold = 1_000_000 * 1e18, // High threshold without reputation
            .can_vote = false,
            .can_propose = false,
        };

        const tier = fromScoreWithHysteresis(score.score, score.prev_tier);
        const multiplier = tier.multiplier();

        // Governance power = stake × reputation multiplier
        const voting_weight: u128 = @intFromFloat(@as(f64, @floatFromInt(stake_wei)) * multiplier);

        // Proposal thresholds based on tier
        const proposal_threshold: u128 = switch (tier) {
            .platinum => 10_000 * 1e18, // Can propose with 10k stake
            .gold => 50_000 * 1e18,
            .silver => 100_000 * 1e18,
            .bronze => 500_000 * 1e18,
        };

        return .{
            .voting_weight = voting_weight,
            .proposal_threshold = proposal_threshold,
            .can_vote = stake_wei >= 100 * 1e18, // Min 100 TRI to vote
            .can_propose = stake_wei >= proposal_threshold,
        };
    }

    /// Get voting power multiplier for a tier
    pub fn getVotingMultiplier(self: *ReputationEngine, node_id: [32]u8) f64 {
        const score = self.scores.get(node_id) orelse return 1.0;
        return score.getTier().multiplier();
    }

    /// Check if node can vote on governance proposals
    pub fn canVote(self: *ReputationEngine, node_id: [32]u8, stake_wei: u128) bool {
        const power = getGovernancePower(self, node_id, stake_wei);
        return power.can_vote;
    }

    /// Check if node can propose governance proposals
    pub fn canPropose(self: *ReputationEngine, node_id: [32]u8, stake_wei: u128) bool {
        const power = getGovernancePower(self, node_id, stake_wei);
        return power.can_propose;
    }

    /// Get statistics about reputation distribution
    pub const Stats = struct {
        total_nodes: u32,
        platinum_count: u32,
        gold_count: u32,
        silver_count: u32,
        bronze_count: u32,
        avg_score: f64,
    };

    pub fn getStats(self: *ReputationEngine) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var stats = Stats{
            .total_nodes = @intCast(self.scores.count()),
            .platinum_count = 0,
            .gold_count = 0,
            .silver_count = 0,
            .bronze_count = 0,
            .avg_score = 0.0,
        };

        if (stats.total_nodes == 0) return stats;

        var total_score: f64 = 0.0;
        var iter = self.scores.valueIterator();
        while (iter.next()) |score| {
            total_score += score.score;
            switch (score.getTier()) {
                .platinum => stats.platinum_count += 1,
                .gold => stats.gold_count += 1,
                .silver => stats.silver_count += 1,
                .bronze => stats.bronze_count += 1,
            }
        }

        stats.avg_score = total_score / @as(f64, @floatFromInt(stats.total_nodes));
        return stats;
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "ReputationTier.fromScore" {
    try std.testing.expectEqual(ReputationTier.platinum, ReputationTier.fromScore(0.95));
    try std.testing.expectEqual(ReputationTier.platinum, ReputationTier.fromScore(0.9));
    try std.testing.expectEqual(ReputationTier.gold, ReputationTier.fromScore(0.8));
    try std.testing.expectEqual(ReputationTier.gold, ReputationTier.fromScore(0.7));
    try std.testing.expectEqual(ReputationTier.silver, ReputationTier.fromScore(0.6));
    try std.testing.expectEqual(ReputationTier.silver, ReputationTier.fromScore(0.5));
    try std.testing.expectEqual(ReputationTier.bronze, ReputationTier.fromScore(0.4));
    try std.testing.expectEqual(ReputationTier.bronze, ReputationTier.fromScore(0.0));
}

test "ReputationTier.multiplier" {
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), ReputationTier.platinum.multiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), ReputationTier.gold.multiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), ReputationTier.silver.multiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), ReputationTier.bronze.multiplier(), 0.01);
}

test "ReputationScore.getMultiplier" {
    var score = ReputationScore{ .node_id = [_]u8{0x01} ** 32, .score = 0.95, .prev_tier = .platinum };
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), score.getMultiplier(), 0.01);

    score.score = 0.75;
    score.prev_tier = .gold;
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), score.getMultiplier(), 0.01);

    score.score = 0.6;
    score.prev_tier = .silver;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), score.getMultiplier(), 0.01);

    score.score = 0.3;
    score.prev_tier = .bronze;
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), score.getMultiplier(), 0.01);
}

test "ReputationScore.adjustReward" {
    var score = ReputationScore{ .node_id = [_]u8{0x01} ** 32, .score = 0.95, .prev_tier = .platinum }; // 2.0x multiplier

    const base: u128 = 1000;
    const adjusted = score.adjustReward(base);
    try std.testing.expectEqual(@as(u128, 2000), adjusted);

    var score2 = ReputationScore{ .node_id = [_]u8{0x02} ** 32, .score = 0.3, .prev_tier = .bronze }; // 0.5x multiplier
    const reduced = score2.adjustReward(base);
    try std.testing.expectEqual(@as(u128, 500), reduced);
}

test "ReputationEngine basic operations" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Get or create
    const score = try engine.getOrCreate(node);
    try std.testing.expectEqual(@as(f64, 0.5), score.score);

    // Update score
    try engine.updateScore(node, 0.85);
    const updated = engine.get(node).?;
    try std.testing.expectApproxEqAbs(@as(f64, 0.85), updated.score, 0.01);
}

test "ReputationEngine calculateReward" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Unknown node gets base reward
    const base_reward = try engine.calculateReward(node, 1000);
    try std.testing.expectEqual(@as(u128, 1000), base_reward);

    // Set high score
    try engine.updateScore(node, 0.95);

    // Now gets 2x reward
    const boosted = try engine.calculateReward(node, 1000);
    try std.testing.expectEqual(@as(u128, 2000), boosted);
}

test "ReputationEngine recordSlash reducesScore" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    try engine.updateScore(node, 0.9);

    // First slash: -0.05
    try engine.recordSlash(node);
    const after1 = engine.get(node).?;
    try std.testing.expectApproxEqAbs(@as(f64, 0.85), after1.score, 0.01);

    // Second slash: -0.10 (penalty for 2nd slash)
    try engine.recordSlash(node);
    const after2 = engine.get(node).?;
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), after2.score, 0.01);

    // Third slash: -0.20 (penalty for 3+ slashes)
    try engine.recordSlash(node);
    const after3 = engine.get(node).?;
    try std.testing.expectApproxEqAbs(@as(f64, 0.55), after3.score, 0.01);
}

test "ReputationEngine stats" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    var node_ids: [4][32]u8 = undefined;
    for (0..4) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
    }

    // Set different scores
    try engine.updateScore(node_ids[0], 0.95); // Platinum
    try engine.updateScore(node_ids[1], 0.75); // Gold
    try engine.updateScore(node_ids[2], 0.6); // Silver
    try engine.updateScore(node_ids[3], 0.3); // Bronze

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u32, 4), stats.total_nodes);
    try std.testing.expectEqual(@as(u32, 1), stats.platinum_count);
    try std.testing.expectEqual(@as(u32, 1), stats.gold_count);
    try std.testing.expectEqual(@as(u32, 1), stats.silver_count);
    try std.testing.expectEqual(@as(u32, 1), stats.bronze_count);
    try std.testing.expectApproxEqAbs(@as(f64, 0.65), stats.avg_score, 0.01);
}

test "ReputationEngine rankNodes" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    var node_ids: [3][32]u8 = undefined;
    for (0..3) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
    }

    try engine.updateScore(node_ids[0], 0.6);
    try engine.updateScore(node_ids[1], 0.95);
    try engine.updateScore(node_ids[2], 0.75);

    const ranked = try engine.rankNodes(allocator);
    defer allocator.free(ranked);

    try std.testing.expectEqual(@as(usize, 3), ranked.len);
    // Should be sorted descending: 0.95, 0.75, 0.6
    try std.testing.expectApproxEqAbs(@as(f64, 0.95), ranked[0].score, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), ranked[1].score, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), ranked[2].score, 0.01);
}

// =============================================================================
// v2.1 TESTS - Hysteresis Deadband
// =============================================================================

test "v2.1: hysteresis prevents oscillation at gold boundary" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Start at gold (0.75)
    try engine.updateScore(node, 0.75);
    const score1 = engine.get(node).?;
    try std.testing.expectEqual(ReputationTier.gold, score1.getTier());

    // Drop to 0.69 (below threshold, but within deadband)
    try engine.updateScore(node, 0.69);
    const score2 = engine.get(node).?;
    // Should stay gold due to hysteresis (0.69 >= 0.7 - 0.02 = 0.68)
    try std.testing.expectEqual(ReputationTier.gold, score2.getTier());

    // Drop further to 0.67 (outside deadband)
    try engine.updateScore(node, 0.67);
    const score3 = engine.get(node).?;
    // Should drop to silver now (0.67 < 0.68)
    try std.testing.expectEqual(ReputationTier.silver, score3.getTier());
}

test "v2.1: hysteresis prevents oscillation at platinum boundary" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Start just below platinum (0.89)
    try engine.updateScore(node, 0.89);
    const score1 = engine.get(node).?;
    try std.testing.expectEqual(ReputationTier.gold, score1.getTier());

    // Rise to 0.91 (above threshold, within deadband)
    try engine.updateScore(node, 0.91);
    const score2 = engine.get(node).?;
    // Should stay gold (0.91 < 0.9 + 0.02 = 0.92)
    try std.testing.expectEqual(ReputationTier.gold, score2.getTier());

    // Rise further to 0.93 (outside deadband)
    try engine.updateScore(node, 0.93);
    const score3 = engine.get(node).?;
    // Should upgrade to platinum (0.93 >= 0.92)
    try std.testing.expectEqual(ReputationTier.platinum, score3.getTier());
}

test "v2.1: hysteresis asymmetric - upgrade vs downgrade thresholds" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Start at silver (0.6)
    try engine.updateScore(node, 0.6);
    const score1 = engine.get(node).?;
    try std.testing.expectEqual(ReputationTier.silver, score1.getTier());

    // Rise to 0.71 - still silver (need 0.72 for upgrade)
    try engine.updateScore(node, 0.71);
    const score2 = engine.get(node).?;
    // Should stay silver (0.71 < 0.7 + 0.02 = 0.72)
    try std.testing.expectEqual(ReputationTier.silver, score2.getTier());

    // Rise to 0.73 - now upgrade to gold
    try engine.updateScore(node, 0.73);
    const score3 = engine.get(node).?;
    try std.testing.expectEqual(ReputationTier.gold, score3.getTier());

    // Drop back to 0.69 (within downgrade deadband of 0.7 - 0.02 = 0.68)
    try engine.updateScore(node, 0.69);
    const score4 = engine.get(node).?;
    // Should stay gold due to hysteresis
    try std.testing.expectEqual(ReputationTier.gold, score4.getTier());

    // Drop further to 0.67 (outside deadband)
    try engine.updateScore(node, 0.67);
    const score5 = engine.get(node).?;
    // Should downgrade to silver
    try std.testing.expectEqual(ReputationTier.silver, score5.getTier());
}

// =============================================================================
// v3.0 TESTS - Governance Power
// =============================================================================

test "v3.0: governance power - platinum tier can propose with 10k stake" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Set platinum reputation
    try engine.updateScore(node, 0.95);

    // Platinum can propose with 10k TRI
    const power = engine.getGovernancePower(node, 10_000 * 1e18);
    try std.testing.expectEqual(@as(u128, 20_000 * 1e18), power.voting_weight); // 2x multiplier
    try std.testing.expect(power.can_propose);
    try std.testing.expect(power.can_vote);
}

test "v3.0: governance power - bronze tier needs 500k stake to propose" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Set bronze reputation
    try engine.updateScore(node, 0.3);

    // Bronze needs 500k TRI to propose
    const power = engine.getGovernancePower(node, 500_000 * 1e18);
    try std.testing.expectEqual(@as(u128, 250_000 * 1e18), power.voting_weight); // 0.5x multiplier
    try std.testing.expect(power.can_propose);
    try std.testing.expect(power.can_vote);
}

test "v3.0: governance power - insufficient stake cannot propose" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Set gold reputation
    try engine.updateScore(node, 0.75);

    // Only 10k TRI, but gold needs 50k to propose
    const power = engine.getGovernancePower(node, 10_000 * 1e18);
    try std.testing.expect(!power.can_propose); // Cannot propose
    try std.testing.expect(power.can_vote); // But can still vote
}

test "v3.0: governance power - below 100 TRI cannot vote" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Set platinum reputation
    try engine.updateScore(node, 0.95);

    // Only 50 TRI staked - below minimum
    const power = engine.getGovernancePower(node, 50 * 1e18);
    try std.testing.expect(!power.can_vote);
    try std.testing.expect(!power.can_propose);
}

test "v3.0: canVote and canPropose helper functions" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Set silver reputation
    try engine.updateScore(node, 0.6);

    // 100 TRI - can vote but not propose (needs 100k for silver)
    try std.testing.expect(engine.canVote(node, 100 * 1e18));
    try std.testing.expect(!engine.canPropose(node, 100 * 1e18));

    // 100k TRI - both vote and propose
    try std.testing.expect(engine.canVote(node, 100_000 * 1e18));
    try std.testing.expect(engine.canPropose(node, 100_000 * 1e18));
}

test "v3.0: voting multiplier by tier" {
    const allocator = std.testing.allocator;

    var engine = ReputationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Bronze: 0.5x
    try engine.updateScore(node, 0.3);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), engine.getVotingMultiplier(node), 0.01);

    // Silver: 1.0x
    try engine.updateScore(node, 0.6);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), engine.getVotingMultiplier(node), 0.01);

    // Gold: 1.5x
    try engine.updateScore(node, 0.75);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), engine.getVotingMultiplier(node), 0.01);

    // Platinum: 2.0x
    try engine.updateScore(node, 0.95);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), engine.getVotingMultiplier(node), 0.01);
}
