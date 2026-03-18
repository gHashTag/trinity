// =============================================================================
// TRINITY INCENTIVE SLASHING v1.7 - Reputation-Based Reward Reduction
// Low-reputation nodes receive reduced rewards; penalties proportional to score
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const node_reputation_mod = @import("node_reputation.zig");
const storage_mod = @import("storage.zig");

// =============================================================================
// SLASHING CONFIGURATION
// =============================================================================

pub const SlashingConfig = struct {
    /// Reputation threshold below which slashing activates (0.0 to 1.0)
    threshold: f64 = 0.5,
    /// Maximum slash percentage (0.0 to 1.0). At score=0, slash this much
    max_slash_rate: f64 = 0.8,
    /// Minimum slash percentage when below threshold
    min_slash_rate: f64 = 0.1,
};

pub const SlashResult = struct {
    node_id: [32]u8,
    reputation_score: f64,
    original_reward_wei: u128,
    slashed_reward_wei: u128,
    slash_rate: f64,
    was_slashed: bool,
};

pub const SlashingStats = struct {
    total_evaluations: u64,
    total_slashed: u64,
    total_wei_slashed: u128,
};

// =============================================================================
// INCENTIVE SLASHING ENGINE
// =============================================================================

pub const IncentiveSlashingEngine = struct {
    allocator: std.mem.Allocator,
    config: SlashingConfig,
    total_evaluations: u64,
    total_slashed: u64,
    total_wei_slashed: u128,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) IncentiveSlashingEngine {
        return .{
            .allocator = allocator,
            .config = .{},
            .total_evaluations = 0,
            .total_slashed = 0,
            .total_wei_slashed = 0,
            .mutex = .{},
        };
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: SlashingConfig) IncentiveSlashingEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .total_evaluations = 0,
            .total_slashed = 0,
            .total_wei_slashed = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *IncentiveSlashingEngine) void {
        _ = self;
    }

    /// Calculate the slash rate for a given reputation score
    /// Returns 0.0 if score >= threshold, otherwise interpolates between min and max slash
    pub fn calculateSlashRate(self: *const IncentiveSlashingEngine, reputation_score: f64) f64 {
        if (reputation_score >= self.config.threshold) {
            return 0.0; // No slashing for good reputation
        }

        // Linear interpolation: at score=0 -> max_slash, at score=threshold -> min_slash
        const t = reputation_score / self.config.threshold; // 0.0 to 1.0
        return self.config.max_slash_rate - t * (self.config.max_slash_rate - self.config.min_slash_rate);
    }

    /// Evaluate a node's reward, applying slashing based on reputation
    pub fn evaluateReward(
        self: *IncentiveSlashingEngine,
        node_id: [32]u8,
        original_reward_wei: u128,
        reputation: *node_reputation_mod.NodeReputationSystem,
    ) SlashResult {
        const score = reputation.getScore(node_id);
        const slash_rate = self.calculateSlashRate(score.score);

        self.mutex.lock();
        self.total_evaluations += 1;

        if (slash_rate > 0.0) {
            const slash_amount_f: f64 = @as(f64, @floatFromInt(original_reward_wei)) * slash_rate;
            const slash_amount: u128 = @intFromFloat(slash_amount_f);
            const slashed_reward = original_reward_wei - slash_amount;

            self.total_slashed += 1;
            self.total_wei_slashed += slash_amount;
            self.mutex.unlock();

            return .{
                .node_id = node_id,
                .reputation_score = score.score,
                .original_reward_wei = original_reward_wei,
                .slashed_reward_wei = slashed_reward,
                .slash_rate = slash_rate,
                .was_slashed = true,
            };
        }

        self.mutex.unlock();

        return .{
            .node_id = node_id,
            .reputation_score = score.score,
            .original_reward_wei = original_reward_wei,
            .slashed_reward_wei = original_reward_wei,
            .slash_rate = 0.0,
            .was_slashed = false,
        };
    }

    /// Batch evaluate rewards for multiple nodes
    pub fn evaluateBatch(
        self: *IncentiveSlashingEngine,
        node_ids: [][32]u8,
        rewards_wei: []const u128,
        reputation: *node_reputation_mod.NodeReputationSystem,
    ) ![]SlashResult {
        var results = try self.allocator.alloc(SlashResult, node_ids.len);
        for (node_ids, 0..) |nid, i| {
            results[i] = self.evaluateReward(nid, rewards_wei[i], reputation);
        }
        return results;
    }

    /// Get stats
    pub fn getStats(self: *IncentiveSlashingEngine) SlashingStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .total_evaluations = self.total_evaluations,
            .total_slashed = self.total_slashed,
            .total_wei_slashed = self.total_wei_slashed,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "good reputation - no slashing" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const node = [_]u8{0x01} ** 32;
    // Perfect PoS + full uptime + bandwidth = score > 0.5
    for (0..10) |_| reputation.recordPosResult(node, true);
    reputation.recordUptime(node, 3600, 3600);
    reputation.recordBandwidth(node, 1024 * 1024);

    const score = reputation.getScore(node);
    try std.testing.expect(score.score >= 0.5);

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    const result = engine.evaluateReward(node, 1_000_000_000_000_000_000, &reputation);
    try std.testing.expect(!result.was_slashed);
    try std.testing.expectEqual(@as(u128, 1_000_000_000_000_000_000), result.slashed_reward_wei);
    try std.testing.expectEqual(@as(f64, 0.0), result.slash_rate);
}

test "bad reputation - reward slashed" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const node = [_]u8{0x02} ** 32;
    // 2/10 PoS, no uptime, no bandwidth = low score
    for (0..10) |i| reputation.recordPosResult(node, i < 2);

    const score = reputation.getScore(node);
    try std.testing.expect(score.score < 0.5);

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    const original: u128 = 1_000_000_000_000_000_000; // 1 TRI
    const result = engine.evaluateReward(node, original, &reputation);
    try std.testing.expect(result.was_slashed);
    try std.testing.expect(result.slashed_reward_wei < original);
    try std.testing.expect(result.slash_rate > 0.0);
}

test "zero reputation - maximum slashing" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const node = [_]u8{0x03} ** 32;
    // 0/10 PoS = score of 0
    for (0..10) |_| reputation.recordPosResult(node, false);

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    const original: u128 = 1_000_000_000_000_000_000;
    const result = engine.evaluateReward(node, original, &reputation);
    try std.testing.expect(result.was_slashed);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), result.slash_rate, 0.01); // max slash
    // Slashed reward = 20% of original
    const expected_reward: u128 = 200_000_000_000_000_000;
    try std.testing.expect(result.slashed_reward_wei >= expected_reward - 1_000_000);
    try std.testing.expect(result.slashed_reward_wei <= expected_reward + 1_000_000);
}

test "calculateSlashRate at threshold boundary" {
    const allocator = std.testing.allocator;

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    // At threshold (0.5) - no slash
    try std.testing.expectEqual(@as(f64, 0.0), engine.calculateSlashRate(0.5));
    // Above threshold - no slash
    try std.testing.expectEqual(@as(f64, 0.0), engine.calculateSlashRate(0.7));
    // At 0 - max slash (0.8)
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), engine.calculateSlashRate(0.0), 0.001);
    // Midpoint (0.25) - interpolated
    const mid = engine.calculateSlashRate(0.25);
    try std.testing.expect(mid > 0.1 and mid < 0.8);
}

test "custom slashing config" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const node = [_]u8{0x04} ** 32;
    for (0..10) |_| reputation.recordPosResult(node, false); // 0 score

    var engine = IncentiveSlashingEngine.initWithConfig(allocator, .{
        .threshold = 0.3,
        .max_slash_rate = 1.0, // 100% slash at 0 reputation
        .min_slash_rate = 0.5,
    });
    defer engine.deinit();

    const result = engine.evaluateReward(node, 1_000_000_000_000_000_000, &reputation);
    try std.testing.expect(result.was_slashed);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.slash_rate, 0.01);
}

test "batch evaluate rewards" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var node_ids: [3][32]u8 = undefined;
    for (0..3) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
        // Node 0: bad (2/10), Node 1: medium (5/10), Node 2: good (10/10)
        for (0..10) |j| {
            reputation.recordPosResult(node_ids[i], j < (i + 1) * 3 + 2);
        }
    }

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    const rewards = [_]u128{
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
    };

    const results = try engine.evaluateBatch(&node_ids, &rewards, &reputation);
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 3), results.len);

    // Stats should reflect 3 evaluations
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total_evaluations);
}

test "slashing stats accumulate" {
    const allocator = std.testing.allocator;

    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    const bad_node = [_]u8{0x01} ** 32;
    const good_node = [_]u8{0x02} ** 32;

    for (0..10) |_| reputation.recordPosResult(bad_node, false);
    for (0..10) |_| reputation.recordPosResult(good_node, true);
    reputation.recordUptime(good_node, 3600, 3600);
    reputation.recordBandwidth(good_node, 1024 * 1024);

    var engine = IncentiveSlashingEngine.init(allocator);
    defer engine.deinit();

    _ = engine.evaluateReward(bad_node, 1_000_000, &reputation);
    _ = engine.evaluateReward(good_node, 1_000_000, &reputation);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_evaluations);
    try std.testing.expectEqual(@as(u64, 1), stats.total_slashed);
    try std.testing.expect(stats.total_wei_slashed > 0);
}
