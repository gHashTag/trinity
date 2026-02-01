const std = @import("std");
const dao = @import("dao_integration.zig");

// ============================================================================
// TRINITY: OPTIMIZED STAKING (PHASE 26) - Ko Samui Low-Latency Edition
// Features: Latency-based APY boost, auto-compound, 8-core optimized
// ============================================================================

/// Ko Samui latency thresholds
pub const LatencyTier = enum {
    Ultra, // <30ms: +20% APY boost
    Fast, // 30-50ms: +10% APY boost
    Normal, // 50-100ms: standard APY
    Slow, // >100ms: reduced features

    pub fn fromMs(latency: u64) LatencyTier {
        if (latency < 30) return .Ultra;
        if (latency < 50) return .Fast;
        if (latency < 100) return .Normal;
        return .Slow;
    }

    pub fn getBoostMultiplier(self: LatencyTier) f32 {
        return switch (self) {
            .Ultra => 1.20, // +20% APY boost
            .Fast => 1.10, // +10% APY boost
            .Normal => 1.0, // Standard
            .Slow => 0.95, // Slight penalty
        };
    }
};

/// Enhanced staking tier with dynamic APY
pub const OptimizedStakingTier = enum {
    Bronze, // Base: 8% APY
    Silver, // Base: 12% APY
    Gold, // Base: 20% APY
    Diamond, // Base: 25% APY (new!)

    pub fn getBaseAPY(self: OptimizedStakingTier) f32 {
        return switch (self) {
            .Bronze => 0.08,
            .Silver => 0.12,
            .Gold => 0.20,
            .Diamond => 0.25,
        };
    }
};

/// Stake info with latency-based optimization
pub const OptimizedStakeInfo = struct {
    amount: f64,
    tier: OptimizedStakingTier,
    latency_tier: LatencyTier,
    start_time: i64,
    base_apy: f32,
    effective_apy: f32,
    auto_compound: bool = true,
};

/// Optimized staking manager for Ko Samui
pub const OptimizedStakingManager = struct {
    allocator: std.mem.Allocator,
    stakes: std.ArrayListUnmanaged(OptimizedStakeInfo),
    total_staked: f64 = 0,
    total_rewards: f64 = 0,
    current_latency: u64 = 50, // Default 50ms

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .stakes = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.stakes.deinit(self.allocator);
    }

    /// Update network latency (call periodically)
    pub fn updateLatency(self: *Self, latency_ms: u64) void {
        self.current_latency = latency_ms;
        const tier = LatencyTier.fromMs(latency_ms);
        std.debug.print("🏝️ [Ko Samui] Latency: {d}ms ({s})\n", .{
            latency_ms,
            @tagName(tier),
        });
    }

    /// Stake with latency-based APY optimization
    pub fn stakeOptimized(self: *Self, amount: f64, tier: OptimizedStakingTier) !void {
        if (amount < 100) return error.MinimumStakeRequired;

        const latency_tier = LatencyTier.fromMs(self.current_latency);
        const base_apy = tier.getBaseAPY();
        const boost = latency_tier.getBoostMultiplier();
        const effective_apy = base_apy * boost;

        const stake = OptimizedStakeInfo{
            .amount = amount,
            .tier = tier,
            .latency_tier = latency_tier,
            .start_time = std.time.timestamp(),
            .base_apy = base_apy,
            .effective_apy = effective_apy,
        };

        try self.stakes.append(self.allocator, stake);
        self.total_staked += amount;

        std.debug.print("🥩 [Optimized Staking] {d:.2} TRI in {s} tier\n", .{
            amount,
            @tagName(tier),
        });
        std.debug.print("   Base APY: {d:.0}% | Boost: {d:.0}% | Effective: {d:.1}%\n", .{
            base_apy * 100,
            (boost - 1.0) * 100,
            effective_apy * 100,
        });
    }

    /// Calculate rewards with auto-compound
    pub fn calculateRewards(self: *Self) f64 {
        var total: f64 = 0;
        const now = std.time.timestamp();

        for (self.stakes.items) |stake| {
            const duration_secs: f64 = @floatFromInt(now - stake.start_time);
            const years = duration_secs / 31536000.0;

            // Simple compound: A = P * (1 + r)^t
            if (stake.auto_compound) {
                const compound = std.math.pow(f64, 1.0 + stake.effective_apy, years);
                total += stake.amount * (compound - 1.0);
            } else {
                total += stake.amount * stake.effective_apy * years;
            }
        }

        self.total_rewards = total;
        return total;
    }

    /// Print portfolio summary
    pub fn printPortfolio(self: *Self) void {
        std.debug.print("\n💼 Staking Portfolio:\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("   Total staked: {d:.2} TRI\n", .{self.total_staked});
        std.debug.print("   Active stakes: {d}\n", .{self.stakes.items.len});
        std.debug.print("   Current latency: {d}ms ({s})\n", .{
            self.current_latency,
            @tagName(LatencyTier.fromMs(self.current_latency)),
        });

        if (self.stakes.items.len > 0) {
            std.debug.print("\n   Stakes:\n", .{});
            for (self.stakes.items, 0..) |stake, i| {
                std.debug.print("   {d}. {d:.2} TRI @ {d:.1}% APY ({s})\n", .{
                    i + 1,
                    stake.amount,
                    stake.effective_apy * 100,
                    @tagName(stake.tier),
                });
            }
        }

        const rewards = self.calculateRewards();
        std.debug.print("\n   💰 Pending rewards: {d:.4} TRI\n", .{rewards});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    }
};

// ============================================================================
// DEMO
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🌟 OPTIMIZED STAKING - Ko Samui Edition\n", .{});
    std.debug.print("   Low-latency APY boost: up to +20%!\n\n", .{});

    var staking = OptimizedStakingManager.init(allocator);
    defer staking.deinit();

    // Ko Samui network simulation
    std.debug.print("📡 Simulating Ko Samui network conditions...\n\n", .{});

    // Ultra low latency - best APY
    staking.updateLatency(25);
    try staking.stakeOptimized(10000, .Gold);

    // Fast mode
    staking.updateLatency(40);
    try staking.stakeOptimized(5000, .Diamond);

    // Normal
    staking.updateLatency(75);
    try staking.stakeOptimized(2500, .Silver);

    // Print portfolio
    staking.printPortfolio();

    std.debug.print("\n✅ Optimized Staking Phase 26 Complete!\n", .{});
    std.debug.print("🏝️ Ko Samui low-latency mode: +20%% APY boost active\n\n", .{});
}
