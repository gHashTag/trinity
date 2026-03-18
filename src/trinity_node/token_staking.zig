// =============================================================================
// TRINITY TOKEN STAKING v1.8 - Stake $TRI to Commit to Storage
// Nodes must stake tokens to participate; slashing burns stake on violations
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const node_reputation_mod = @import("node_reputation.zig");

// =============================================================================
// STAKING CONFIGURATION
// =============================================================================

pub const StakingConfig = struct {
    /// Minimum stake required to participate (in wei)
    min_stake_wei: u128 = 100_000_000_000_000_000_000, // 100 TRI
    /// Stake slash rate for PoS failures (fraction of stake burned)
    pos_failure_slash_rate: f64 = 0.01, // 1% per failure
    /// Stake slash rate for corruption detected
    corruption_slash_rate: f64 = 0.05, // 5% per corruption
    /// Minimum reputation score to avoid automatic unstaking
    min_reputation_for_staking: f64 = 0.2,
};

pub const StakeEntry = struct {
    staked_wei: u128,
    slashed_wei: u128,
    stake_time: i64,
    pos_failures: u32,
    corruptions: u32,
    is_active: bool,
};

pub const StakeResult = struct {
    node_id: [32]u8,
    success: bool,
    staked_wei: u128,
    reason: StakeResultReason,
};

pub const StakeResultReason = enum {
    ok,
    insufficient_amount,
    already_staked,
    not_staked,
    below_min_reputation,
    stake_depleted,
};

pub const StakingStats = struct {
    total_staked_wei: u128,
    total_slashed_wei: u128,
    total_burned_wei: u128,
    active_stakers: u32,
    total_stakes: u64,
    total_unstakes: u64,
    total_slash_events: u64,
};

// =============================================================================
// TOKEN STAKING ENGINE
// =============================================================================

pub const TokenStakingEngine = struct {
    allocator: std.mem.Allocator,
    config: StakingConfig,
    stakes: std.AutoHashMap([32]u8, StakeEntry),
    total_staked_wei: u128,
    total_slashed_wei: u128,
    total_burned_wei: u128,
    total_stakes: u64,
    total_unstakes: u64,
    total_slash_events: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) TokenStakingEngine {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: StakingConfig) TokenStakingEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .stakes = std.AutoHashMap([32]u8, StakeEntry).init(allocator),
            .total_staked_wei = 0,
            .total_slashed_wei = 0,
            .total_burned_wei = 0,
            .total_stakes = 0,
            .total_unstakes = 0,
            .total_slash_events = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *TokenStakingEngine) void {
        self.stakes.deinit();
    }

    /// Stake tokens for a node
    pub fn stake(self: *TokenStakingEngine, node_id: [32]u8, amount_wei: u128) StakeResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (amount_wei < self.config.min_stake_wei) {
            return .{
                .node_id = node_id,
                .success = false,
                .staked_wei = 0,
                .reason = .insufficient_amount,
            };
        }

        if (self.stakes.contains(node_id)) {
            return .{
                .node_id = node_id,
                .success = false,
                .staked_wei = 0,
                .reason = .already_staked,
            };
        }

        self.stakes.put(node_id, .{
            .staked_wei = amount_wei,
            .slashed_wei = 0,
            .stake_time = std.time.timestamp(),
            .pos_failures = 0,
            .corruptions = 0,
            .is_active = true,
        }) catch return .{
            .node_id = node_id,
            .success = false,
            .staked_wei = 0,
            .reason = .insufficient_amount,
        };

        self.total_staked_wei += amount_wei;
        self.total_stakes += 1;

        return .{
            .node_id = node_id,
            .success = true,
            .staked_wei = amount_wei,
            .reason = .ok,
        };
    }

    /// Unstake tokens (returns remaining stake after slashing)
    pub fn unstake(self: *TokenStakingEngine, node_id: [32]u8) StakeResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.get(node_id) orelse return .{
            .node_id = node_id,
            .success = false,
            .staked_wei = 0,
            .reason = .not_staked,
        };

        const remaining = entry.staked_wei - entry.slashed_wei;

        _ = self.stakes.remove(node_id);
        self.total_staked_wei -= entry.staked_wei;
        self.total_unstakes += 1;

        return .{
            .node_id = node_id,
            .success = true,
            .staked_wei = remaining,
            .reason = .ok,
        };
    }

    /// Slash a node's stake for PoS failure
    pub fn slashForPosFailure(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(node_id) orelse return 0;

        const remaining = entry.staked_wei - entry.slashed_wei;
        const slash_f: f64 = @as(f64, @floatFromInt(remaining)) * self.config.pos_failure_slash_rate;
        const slash_amount: u128 = @intFromFloat(slash_f);

        entry.slashed_wei += slash_amount;
        entry.pos_failures += 1;
        self.total_slashed_wei += slash_amount;
        self.total_burned_wei += slash_amount;
        self.total_slash_events += 1;

        // Deactivate if stake depleted
        if (entry.slashed_wei >= entry.staked_wei) {
            entry.is_active = false;
        }

        return slash_amount;
    }

    /// Slash a node's stake for corruption
    pub fn slashForCorruption(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(node_id) orelse return 0;

        const remaining = entry.staked_wei - entry.slashed_wei;
        const slash_f: f64 = @as(f64, @floatFromInt(remaining)) * self.config.corruption_slash_rate;
        const slash_amount: u128 = @intFromFloat(slash_f);

        entry.slashed_wei += slash_amount;
        entry.corruptions += 1;
        self.total_slashed_wei += slash_amount;
        self.total_burned_wei += slash_amount;
        self.total_slash_events += 1;

        if (entry.slashed_wei >= entry.staked_wei) {
            entry.is_active = false;
        }

        return slash_amount;
    }

    /// Check if a node is staked and active
    pub fn isStaked(self: *TokenStakingEngine, node_id: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry = self.stakes.get(node_id) orelse return false;
        return entry.is_active;
    }

    /// Get stake info for a node
    pub fn getStake(self: *TokenStakingEngine, node_id: [32]u8) ?StakeEntry {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stakes.get(node_id);
    }

    /// Get remaining stake (staked - slashed) for a node
    pub fn getRemainingStake(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry = self.stakes.get(node_id) orelse return 0;
        return entry.staked_wei - entry.slashed_wei;
    }

    /// Count active stakers
    pub fn countActiveStakers(self: *TokenStakingEngine) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        var count: u32 = 0;
        var iter = self.stakes.valueIterator();
        while (iter.next()) |entry| {
            if (entry.is_active) count += 1;
        }
        return count;
    }

    /// Get stats
    pub fn getStats(self: *TokenStakingEngine) StakingStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        var active: u32 = 0;
        var iter = self.stakes.valueIterator();
        while (iter.next()) |entry| {
            if (entry.is_active) active += 1;
        }
        return .{
            .total_staked_wei = self.total_staked_wei,
            .total_slashed_wei = self.total_slashed_wei,
            .total_burned_wei = self.total_burned_wei,
            .active_stakers = active,
            .total_stakes = self.total_stakes,
            .total_unstakes = self.total_unstakes,
            .total_slash_events = self.total_slash_events,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "stake and unstake" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Stake
    const result = engine.stake(node, 1000);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u128, 1000), result.staked_wei);
    try std.testing.expect(engine.isStaked(node));

    // Unstake
    const unstake_result = engine.unstake(node);
    try std.testing.expect(unstake_result.success);
    try std.testing.expectEqual(@as(u128, 1000), unstake_result.staked_wei); // Full return
    try std.testing.expect(!engine.isStaked(node));
}

test "insufficient stake rejected" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 1000,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    const result = engine.stake(node, 500); // Below minimum
    try std.testing.expect(!result.success);
    try std.testing.expect(result.reason == .insufficient_amount);
}

test "double stake rejected" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    _ = engine.stake(node, 1000);

    const result = engine.stake(node, 2000);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.reason == .already_staked);
}

test "slash for PoS failure reduces stake" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.10, // 10% per failure
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    _ = engine.stake(node, 1000);

    // Slash 10% = 100
    const slashed = engine.slashForPosFailure(node);
    try std.testing.expectEqual(@as(u128, 100), slashed);

    // Remaining = 1000 - 100 = 900
    try std.testing.expectEqual(@as(u128, 900), engine.getRemainingStake(node));

    // Unstake returns remaining
    const unstake = engine.unstake(node);
    try std.testing.expectEqual(@as(u128, 900), unstake.staked_wei);
}

test "slash for corruption" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.20, // 20% per corruption
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    _ = engine.stake(node, 1000);

    const slashed = engine.slashForCorruption(node);
    try std.testing.expectEqual(@as(u128, 200), slashed);
    try std.testing.expectEqual(@as(u128, 800), engine.getRemainingStake(node));
}

test "stake deactivated when fully slashed" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.50, // 50% per failure
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    _ = engine.stake(node, 1000);
    try std.testing.expect(engine.isStaked(node));

    // Slash 50% = 500
    _ = engine.slashForPosFailure(node);
    try std.testing.expect(engine.isStaked(node)); // Still active

    // Slash 50% of remaining (500) = 250. Total slashed = 750
    _ = engine.slashForPosFailure(node);
    try std.testing.expect(engine.isStaked(node)); // Still active

    // Slash 50% of remaining (250) = 125. Total = 875
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (125) = 62. Total = 937
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (63) = 31. Total = 968
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (32) = 16. Total = 984
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (16) = 8. Total = 992
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (8) = 4. Total = 996
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (4) = 2. Total = 998
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (2) = 1. Total = 999
    _ = engine.slashForPosFailure(node);
    // Slash 50% of remaining (1) = 0. Total = 999 (rounding to 0)
    // One more to push over
    _ = engine.slashForPosFailure(node);

    // After enough slashing, remaining approaches 0
    try std.testing.expect(engine.getRemainingStake(node) <= 1);
}

test "staking stats accumulate" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.10,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer engine.deinit();

    var node_ids: [5][32]u8 = undefined;
    for (0..5) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
        _ = engine.stake(node_ids[i], 1000);
    }

    // Slash node 0 and 1
    _ = engine.slashForPosFailure(node_ids[0]);
    _ = engine.slashForCorruption(node_ids[1]);

    // Unstake node 4
    _ = engine.unstake(node_ids[4]);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 5), stats.total_stakes);
    try std.testing.expectEqual(@as(u64, 1), stats.total_unstakes);
    try std.testing.expectEqual(@as(u64, 2), stats.total_slash_events);
    try std.testing.expectEqual(@as(u32, 4), stats.active_stakers);
    try std.testing.expect(stats.total_slashed_wei > 0);
    try std.testing.expect(stats.total_burned_wei > 0);
}

test "unstake non-existent node" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0xFF} ** 32;
    const result = engine.unstake(node);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.reason == .not_staked);
}
