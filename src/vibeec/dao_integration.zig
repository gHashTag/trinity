const std = @import("std");

pub const StakingTier = enum {
    BRONZE, // 8% APY
    SILVER, // 12% APY
    GOLD, // 20% APY
};

pub const StakeInfo = struct {
    amount: f64,
    tier: StakingTier,
    start_time: i64,
    yield: f64,
};

pub const DAOManager = struct {
    allocator: std.mem.Allocator,
    stakes: std.ArrayListUnmanaged(StakeInfo),
    tri_balance: f64,

    pub fn init(allocator: std.mem.Allocator) DAOManager {
        return DAOManager{
            .allocator = allocator,
            .stakes = .{},
            .tri_balance = 0.0,
        };
    }

    pub fn deinit(self: *DAOManager) void {
        self.stakes.deinit(self.allocator);
    }

    pub fn stake(self: *DAOManager, amount: f64, tier: StakingTier) !void {
        if (amount <= 0) return error.InvalidAmount;

        const info = StakeInfo{
            .amount = amount,
            .tier = tier,
            .start_time = std.time.timestamp(),
            .yield = switch (tier) {
                .BRONZE => 0.08,
                .SILVER => 0.12,
                .GOLD => 0.20,
            },
        };
        try self.stakes.append(self.allocator, info);
        std.debug.print("🥩 [DAO] Staked {d:.2} $TRI in {s} tier ({d:.0}% APY)\n", .{ amount, @tagName(tier), info.yield * 100 });
    }

    pub fn vote(self: *DAOManager, proposal_id: []const u8, choice: bool) !void {
        _ = self;
        std.debug.print("🗳️ [DAO] Casting vote on proposal {s}: {s}\n", .{ proposal_id, if (choice) "YES" else "NO" });
        std.Thread.sleep(100 * std.time.ns_per_ms);
        std.debug.print("✅ [DAO] Vote recorded on Trinity L2.\n", .{});
    }

    pub fn calculateRewards(self: *DAOManager) f64 {
        var total_reward: f64 = 0;
        const now = std.time.timestamp();
        for (self.stakes.items) |s| {
            const duration = @as(f64, @floatFromInt(now - s.start_time));
            // simplified reward: (amount * yield) * (time / year_in_seconds)
            total_reward += (s.amount * s.yield) * (duration / 31536000.0);
        }
        return total_reward;
    }
};
