// Trinity Economy: Reward Ledger
// DEV-003: Display-friendly wrapper around KG reward calculations
// v2.0: Reputation-based reward multipliers
//
// Wraps the core KgRewardCalculator from kg_sync.zig for monitoring use.
// Provides aggregated metrics suitable for dashboard display.
// Generated from: specs/tri/swarm_watch.tri

const std = @import("std");

// =============================================================================
// v2.0: REPUTATION MULTIPLIER INTERFACE
// =============================================================================

/// Opaque reputation engine interface (to avoid circular dependencies)
/// Applications should integrate at a higher level using the concrete type.
pub const ReputationEngineInterface = struct {
    ptr: *anyopaque,
    getScoreFn: *const fn (*anyopaque, [32]u8) ?f64,
    getMultiplierFn: *const fn (*anyopaque, [32]u8) f64,

    /// Get reputation score for a node
    pub fn getScore(self: ReputationEngineInterface, node_id: [32]u8) ?f64 {
        return self.getScoreFn(self.ptr, node_id);
    }

    /// Get reward multiplier for a node
    pub fn getMultiplier(self: ReputationEngineInterface, node_id: [32]u8) f64 {
        return self.getMultiplierFn(self.ptr, node_id);
    }
};

// =============================================================================
// CONSTANTS
// =============================================================================

/// TRI per triple reward (0.0002 TRI = 200_000_000_000_000 wei)
pub const REWARD_PER_TRIPLE_WEI: u128 = 200_000_000_000_000;

/// Minimum contributions before rewards are claimable
pub const MIN_CONTRIBUTIONS_FOR_CLAIM: u32 = 5;

/// Wei to TRI divisor (10^18)
pub const WEI_DIVISOR: f64 = 1_000_000_000_000_000_000.0;

// =============================================================================
// TYPES
// =============================================================================

/// A single reward event record
pub const RewardEvent = struct {
    node_id_prefix: [8]u8 = [_]u8{0} ** 8,
    amount_wei: u128 = 0,
    triple_count: u32 = 0,
    timestamp: i64 = 0,
    claimed: bool = false,

    pub fn amountTri(self: *const RewardEvent) f64 {
        return @as(f64, @floatFromInt(self.amount_wei)) / WEI_DIVISOR;
    }
};

/// Aggregated reward statistics for display
pub const RewardStats = struct {
    total_earned_wei: u128 = 0,
    total_claimed_wei: u128 = 0,
    pending_wei: u128 = 0,
    triples_rewarded: u64 = 0,
    claim_count: u32 = 0,
    contributors: u32 = 0,

    pub fn totalEarnedTri(self: *const RewardStats) f64 {
        return @as(f64, @floatFromInt(self.total_earned_wei)) / WEI_DIVISOR;
    }

    pub fn totalClaimedTri(self: *const RewardStats) f64 {
        return @as(f64, @floatFromInt(self.total_claimed_wei)) / WEI_DIVISOR;
    }

    pub fn pendingTri(self: *const RewardStats) f64 {
        return @as(f64, @floatFromInt(self.pending_wei)) / WEI_DIVISOR;
    }
};

// =============================================================================
// REWARD LEDGER
// =============================================================================

const MAX_REWARD_EVENTS: usize = 64;

pub const RewardLedger = struct {
    stats: RewardStats = .{},
    events: [MAX_REWARD_EVENTS]RewardEvent = [_]RewardEvent{.{}} ** MAX_REWARD_EVENTS,
    event_head: usize = 0,
    event_count: usize = 0,
    /// v2.0: Optional reputation engine interface for multipliers
    reputation_engine: ?ReputationEngineInterface = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    /// Set the reputation engine for reward multipliers
    pub fn setReputationEngine(self: *Self, engine: ReputationEngineInterface) void {
        self.reputation_engine = engine;
    }

    /// Record a reward earned (before claiming)
    pub fn recordEarned(self: *Self, node_prefix: [8]u8, amount_wei: u128, triple_count: u32) void {
        self.stats.total_earned_wei += amount_wei;
        self.stats.pending_wei += amount_wei;
        self.stats.triples_rewarded += triple_count;

        const idx = self.event_head;
        self.events[idx] = .{
            .node_id_prefix = node_prefix,
            .amount_wei = amount_wei,
            .triple_count = triple_count,
            .timestamp = std.time.timestamp(),
            .claimed = false,
        };
        self.event_head = (self.event_head + 1) % MAX_REWARD_EVENTS;
        if (self.event_count < MAX_REWARD_EVENTS) self.event_count += 1;
    }

    /// Record a reward claimed
    pub fn recordClaimed(self: *Self, amount_wei: u128) void {
        if (amount_wei > self.stats.pending_wei) {
            self.stats.pending_wei = 0;
        } else {
            self.stats.pending_wei -= amount_wei;
        }
        self.stats.total_claimed_wei += amount_wei;
        self.stats.claim_count += 1;
    }

    /// Update stats from external data
    pub fn syncFromExternal(self: *Self, total_paid_wei: u128, triples_rewarded: u64, contributors: u32) void {
        self.stats.total_earned_wei = total_paid_wei;
        self.stats.triples_rewarded = triples_rewarded;
        self.stats.contributors = contributors;
    }

    /// Calculate reward for N triples
    pub fn calculateReward(triple_count: u32) u128 {
        return @as(u128, triple_count) * REWARD_PER_TRIPLE_WEI;
    }

    /// v2.0: Calculate reward with reputation multiplier applied
    pub fn calculateRewardWithMultiplier(self: *const Self, node_id: [32]u8, triple_count: u32) struct { base: u128, adjusted: u128, multiplier: f64 } {
        const base = Self.calculateReward(triple_count);

        if (self.reputation_engine) |engine| {
            const mult = engine.getMultiplier(node_id);
            const adjusted_f: f64 = @as(f64, @floatFromInt(base)) * mult;
            const adjusted: u128 = @intFromFloat(adjusted_f);

            return .{ .base = base, .adjusted = adjusted, .multiplier = mult };
        }

        return .{ .base = base, .adjusted = base, .multiplier = 1.0 };
    }

    /// Render reward summary to writer
    pub fn renderSummary(self: *const Self, writer: anytype) !void {
        try writer.print("\x1b[33m$TRI Reward Ledger\x1b[0m\n", .{});
        try writer.print("  Earned:     \x1b[33m{d:.6} TRI\x1b[0m\n", .{self.stats.totalEarnedTri()});
        try writer.print("  Claimed:    \x1b[32m{d:.6} TRI\x1b[0m\n", .{self.stats.totalClaimedTri()});
        try writer.print("  Pending:    \x1b[33m{d:.6} TRI\x1b[0m\n", .{self.stats.pendingTri()});
        try writer.print("  Rewarded:   {d} triples\n", .{self.stats.triples_rewarded});
        try writer.print("  Claims:     {d}\n", .{self.stats.claim_count});
        try writer.print("  Rate:       0.0002 TRI/triple\n", .{});
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "RewardLedger.init" {
    const ledger = RewardLedger.init();
    try std.testing.expectEqual(@as(u128, 0), ledger.stats.total_earned_wei);
    try std.testing.expectEqual(@as(usize, 0), ledger.event_count);
}

test "RewardLedger.recordEarned" {
    var ledger = RewardLedger.init();
    ledger.recordEarned([_]u8{0xAB} ** 8, REWARD_PER_TRIPLE_WEI * 5, 5);
    try std.testing.expectEqual(@as(u64, 5), ledger.stats.triples_rewarded);
    try std.testing.expect(ledger.stats.total_earned_wei > 0);
    try std.testing.expectEqual(@as(usize, 1), ledger.event_count);
}

test "RewardLedger.recordClaimed" {
    var ledger = RewardLedger.init();
    ledger.recordEarned([_]u8{0} ** 8, 1000, 1);
    ledger.recordClaimed(500);
    try std.testing.expectEqual(@as(u128, 500), ledger.stats.pending_wei);
    try std.testing.expectEqual(@as(u128, 500), ledger.stats.total_claimed_wei);
    try std.testing.expectEqual(@as(u32, 1), ledger.stats.claim_count);
}

test "RewardLedger.calculateReward" {
    const reward = RewardLedger.calculateReward(10);
    try std.testing.expectEqual(REWARD_PER_TRIPLE_WEI * 10, reward);
}

test "RewardStats.pendingTri" {
    var stats = RewardStats{};
    stats.pending_wei = 1_000_000_000_000_000_000;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), stats.pendingTri(), 0.001);
}

// =============================================================================
// v2.0 TESTS - Reputation Multipliers
// =============================================================================

// Mock data for testing reputation interface
const MockReputationState = struct {
    scores: std.AutoHashMap([32]u8, f64),

    fn getScore(ptr: *anyopaque, node_id: [32]u8) ?f64 {
        const self = @as(*MockReputationState, @ptrCast(@alignCast(ptr)));
        return self.scores.get(node_id);
    }

    fn getMultiplier(ptr: *anyopaque, node_id: [32]u8) f64 {
        const self = @as(*MockReputationState, @ptrCast(@alignCast(ptr)));
        const score = self.scores.get(node_id) orelse return 1.0;
        if (score >= 0.9) return 2.0;
        if (score >= 0.7) return 1.5;
        if (score >= 0.5) return 1.0;
        return 0.5;
    }
};

test "v2.0: calculateRewardWithMultiplier - platinum tier" {
    const allocator = std.testing.allocator;

    var mock_state = MockReputationState{
        .scores = std.AutoHashMap([32]u8, f64).init(allocator),
    };
    defer mock_state.scores.deinit();

    const node = [_]u8{0x01} ** 32;
    try mock_state.scores.put(node, 0.95); // Platinum = 2.0x

    var ledger = RewardLedger.init();
    ledger.setReputationEngine(.{
        .ptr = &mock_state,
        .getScoreFn = MockReputationState.getScore,
        .getMultiplierFn = MockReputationState.getMultiplier,
    });

    const result = ledger.calculateRewardWithMultiplier(node, 10);

    try std.testing.expectEqual(@as(u128, 10 * REWARD_PER_TRIPLE_WEI), result.base);
    try std.testing.expectEqual(@as(u128, 20 * REWARD_PER_TRIPLE_WEI), result.adjusted); // 2x
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), result.multiplier, 0.01);
}

test "v2.0: calculateRewardWithMultiplier - gold tier" {
    const allocator = std.testing.allocator;

    var mock_state = MockReputationState{
        .scores = std.AutoHashMap([32]u8, f64).init(allocator),
    };
    defer mock_state.scores.deinit();

    const node = [_]u8{0x01} ** 32;
    try mock_state.scores.put(node, 0.75); // Gold = 1.5x

    var ledger = RewardLedger.init();
    ledger.setReputationEngine(.{
        .ptr = &mock_state,
        .getScoreFn = MockReputationState.getScore,
        .getMultiplierFn = MockReputationState.getMultiplier,
    });

    const result = ledger.calculateRewardWithMultiplier(node, 10);

    try std.testing.expectEqual(@as(u128, 15 * REWARD_PER_TRIPLE_WEI), result.adjusted); // 1.5x
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), result.multiplier, 0.01);
}

test "v2.0: calculateRewardWithMultiplier - bronze tier" {
    const allocator = std.testing.allocator;

    var mock_state = MockReputationState{
        .scores = std.AutoHashMap([32]u8, f64).init(allocator),
    };
    defer mock_state.scores.deinit();

    const node = [_]u8{0x01} ** 32;
    try mock_state.scores.put(node, 0.3); // Bronze = 0.5x

    var ledger = RewardLedger.init();
    ledger.setReputationEngine(.{
        .ptr = &mock_state,
        .getScoreFn = MockReputationState.getScore,
        .getMultiplierFn = MockReputationState.getMultiplier,
    });

    const result = ledger.calculateRewardWithMultiplier(node, 10);

    try std.testing.expectEqual(@as(u128, 5 * REWARD_PER_TRIPLE_WEI), result.adjusted); // 0.5x
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result.multiplier, 0.01);
}

test "v2.0: calculateRewardWithMultiplier - unknown node" {
    const allocator = std.testing.allocator;

    var mock_state = MockReputationState{
        .scores = std.AutoHashMap([32]u8, f64).init(allocator),
    };
    defer mock_state.scores.deinit();

    var ledger = RewardLedger.init();
    ledger.setReputationEngine(.{
        .ptr = &mock_state,
        .getScoreFn = MockReputationState.getScore,
        .getMultiplierFn = MockReputationState.getMultiplier,
    });

    const node = [_]u8{0xFF} ** 32;
    const result = ledger.calculateRewardWithMultiplier(node, 10);

    // Unknown nodes get 1.0x multiplier
    try std.testing.expectEqual(@as(u128, 10 * REWARD_PER_TRIPLE_WEI), result.base);
    try std.testing.expectEqual(@as(u128, 10 * REWARD_PER_TRIPLE_WEI), result.adjusted);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.multiplier, 0.01);
}

test "v2.0: calculateRewardWithMultiplier - no engine" {
    var ledger = RewardLedger.init();
    // No reputation engine set

    const node = [_]u8{0x01} ** 32;
    const result = ledger.calculateRewardWithMultiplier(node, 10);

    // Without engine, gets 1.0x multiplier
    try std.testing.expectEqual(@as(u128, 10 * REWARD_PER_TRIPLE_WEI), result.base);
    try std.testing.expectEqual(@as(u128, 10 * REWARD_PER_TRIPLE_WEI), result.adjusted);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.multiplier, 0.01);
}
