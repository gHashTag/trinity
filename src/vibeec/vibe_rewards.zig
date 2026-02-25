//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.3: $TRI Reward System for Improvements
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Calculates $TRI rewards for quality improvements.
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// VIBEE Reward System
pub const VibeRewardSystem = struct {
    /// Calculate $TRI reward for quality improvement
    pub fn rewardForImprovement(
        quality_score: f32,
        complexity: u8,
    ) f64 {
        // Base: quality * 10 (max 10)
        const base = @min(quality_score * 10, 10);

        // Complexity bonus: +0.5 per point (max +4)
        const bonus = @min(@as(f64, @floatFromInt(complexity)) * 0.5, 4);

        return base + bonus;
    }

    /// Staking $TRI gives priority on own module improvements
    pub fn getStakeBonus(staked_amount: f64) f64 {
        // 0 $TRI = 1.0x (normal priority)
        // 100 $TRI = 1.5x
        // 500 $TRI = 2.0x
        if (staked_amount < 100) return 1.0;
        if (staked_amount < 500) return 1.5;
        return 2.0;
    }

    /// Daily earnings cap (prevents gaming)
    pub const DAILY_CAP: f64 = 100;

    /// Get reward tier based on quality score
    pub fn getRewardTier(quality_score: f32) Tier {
        if (quality_score >= 0.95) return .platinum;
        if (quality_score >= 0.90) return .gold;
        if (quality_score >= 0.85) return .silver;
        if (quality_score >= 0.75) return .bronze;
        return .unranked;
    }
};

/// Reward tier classification
pub const Tier = enum {
    /// Quality >= 0.95
    platinum,
    /// Quality >= 0.90
    gold,
    /// Quality >= 0.85
    silver,
    /// Quality >= 0.75
    bronze,
    /// Quality < 0.75
    unranked,
};

/// Reward statistics for an agent
pub const RewardStats = struct {
    agent_id: []const u8,
    total_earned: f64,
    improvements_count: usize,
    tier_counts: [5]usize, // platinum, gold, silver, bronze, unranked

    pub fn init(allocator: std.mem.Allocator, agent_id: []const u8) !@This() {
        const id_copy = try allocator.dupe(u8, agent_id);
        return .{
            .agent_id = id_copy,
            .total_earned = 0,
            .improvements_count = 0,
            .tier_counts = [_]usize{0} ** 5,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.agent_id);
    }

    pub fn addReward(self: *@This(), reward: f64, quality: f32) void {
        self.total_earned += reward;
        self.improvements_count += 1;

        const tier = VibeRewardSystem.getRewardTier(quality);
        self.tier_counts[@intFromEnum(tier)] += 1;
    }

    pub fn format(self: *const @This(), writer: anytype) !void {
        try writer.print("Agent: {s}\n", .{self.agent_id});
        try writer.print("  Total earned: ${d:.2} $TRI\n", .{self.total_earned});
        try writer.print("  Improvements: {d}\n", .{self.improvements_count});
        try writer.print("  Tiers: Platinum={d}, Gold={d}, Silver={d}, Bronze={d}\n", .{
            self.tier_counts[0], self.tier_counts[1], self.tier_counts[2], self.tier_counts[3],
        });
    }
};
