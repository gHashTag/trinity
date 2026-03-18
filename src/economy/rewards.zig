// Trinity Economy: Reward Ledger
// DEV-003: Display-friendly wrapper around KG reward calculations
//
// Wraps the core KgRewardCalculator from kg_sync.zig for monitoring use.
// Provides aggregated metrics suitable for dashboard display.
// Generated from: specs/tri/swarm_watch.tri

const std = @import("std");

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

    const Self = @This();

    pub fn init() Self {
        return .{};
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
