// @origin(spec:depin_staking.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// Phase 4: Testnet Preparation - Staking Manager
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// LOCK-UP PERIODS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LockPeriod = enum(u8) {
    one_month = 1,
    three_months = 3,
    six_months = 6,
    twelve_months = 12,

    /// Get multiplier for this lock period (longer = more rewards)
    pub fn getMultiplier(self: LockPeriod) f64 {
        return switch (self) {
            .one_month => 1.0, // No bonus
            .three_months => 1.2, // 20% bonus
            .six_months => 1.5, // 50% bonus
            .twelve_months => 2.0, // 100% bonus
        };
    }

    /// Get seconds in lock period
    pub fn getSeconds(self: LockPeriod) u64 {
        const seconds_per_day: u64 = 24 * 60 * 60;
        const days_per_month: u64 = 30;
        return switch (self) {
            .one_month => 1 * days_per_month * seconds_per_day,
            .three_months => 3 * days_per_month * seconds_per_day,
            .six_months => 6 * days_per_month * seconds_per_day,
            .twelve_months => 12 * days_per_month * seconds_per_day,
        };
    }

    /// Parse from string
    pub fn fromString(str: []const u8) ?LockPeriod {
        if (std.mem.eql(u8, str, "1M")) return .one_month;
        if (std.mem.eql(u8, str, "3M")) return .three_months;
        if (std.mem.eql(u8, str, "6M")) return .six_months;
        if (std.mem.eql(u8, str, "12M")) return .twelve_months;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STAKE POSITION
// ═══════════════════════════════════════════════════════════════════════════════

pub const StakePosition = struct {
    /// Unique stake ID
    stake_id: []const u8,
    /// Staker address (20 bytes)
    staker_address: [20]u8,
    /// Delegator address (null if self-stake)
    delegator_address: ?[20]u8,
    /// Amount staked (in TRI wei)
    amount: u128,
    /// Lock-up period
    lock_period: LockPeriod,
    /// Timestamp when stake was created
    start_timestamp: i64,
    /// Timestamp when stake can be withdrawn
    unlock_timestamp: i64,
    /// Whether stake is slashed
    is_slashed: bool,
    /// Current reward accumulator
    rewards: u128,
    /// Whether stake is active
    is_active: bool,

    pub fn deinit(self: *StakePosition, allocator: Allocator) void {
        allocator.free(self.stake_id);
    }

    /// Check if stake can be withdrawn
    pub fn canWithdraw(self: *const StakePosition) bool {
        if (self.is_slashed) return true;
        const now = std.time.timestamp();
        return now >= self.unlock_timestamp;
    }

    /// Calculate current rewards with multiplier
    pub fn calculateRewards(self: *const StakePosition, base_reward_rate: f64) u128 {
        if (self.is_slashed or !self.is_active) return 0;

        const elapsed = @as(f64, @floatFromInt(std.time.timestamp() - self.start_timestamp));
        const hours = elapsed / 3600.0;
        const multiplier = self.lock_period.getMultiplier();
        const reward = base_reward_rate * hours * multiplier;

        return @intFromFloat(reward);
    }

    /// Apply slashing to stake
    pub fn applySlash(self: *StakePosition, penalty_percentage: f64) void {
        const slash_amount = @as(u128, @intFromFloat(@as(f64, @floatFromInt(self.amount)) * penalty_percentage));
        self.amount -= slash_amount;
        self.is_slashed = true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STAKING MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const StakingManager = struct {
    allocator: Allocator,
    /// All stake positions indexed by stake_id
    stakes: std.StringHashMapUnmanaged(StakePosition),
    /// Stakes indexed by staker address
    staker_stakes: std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8)),
    /// Total staked amount
    total_staked: u128,
    /// Minimum stake amount (100 TRI)
    const MIN_STAKE: u128 = 100 * std.math.pow(u128, 10, 18);

    pub fn init(allocator: Allocator) StakingManager {
        return StakingManager{
            .allocator = allocator,
            .stakes = .{},
            .staker_stakes = .{},
            .total_staked = 0,
        };
    }

    /// Create a new stake position
    pub fn createStake(
        self: *StakingManager,
        staker_address: [20]u8,
        amount: u128,
        lock_period: LockPeriod,
    ) ![]const u8 {
        if (amount < MIN_STAKE) return error.StakeBelowMinimum;

        const now = std.time.timestamp();
        const stake_id = try self.generateStakeId(staker_address, now);

        const position = StakePosition{
            .stake_id = stake_id,
            .staker_address = staker_address,
            .delegator_address = null,
            .amount = amount,
            .lock_period = lock_period,
            .start_timestamp = now,
            .unlock_timestamp = now + @as(i64, @intCast(lock_period.getSeconds())),
            .is_slashed = false,
            .rewards = 0,
            .is_active = true,
        };

        try self.stakes.put(self.allocator, stake_id, position);
        try self.addToStakerIndex(staker_address, stake_id);
        self.total_staked += amount;

        return stake_id;
    }

    /// Create delegated stake
    pub fn createDelegatedStake(
        self: *StakingManager,
        staker_address: [20]u8,
        delegator_address: [20]u8,
        amount: u128,
        lock_period: LockPeriod,
    ) ![]const u8 {
        if (amount < MIN_STAKE) return error.StakeBelowMinimum;

        const now = std.time.timestamp();
        const stake_id = try self.generateStakeId(delegator_address, now);

        const position = StakePosition{
            .stake_id = stake_id,
            .staker_address = staker_address,
            .delegator_address = delegator_address,
            .amount = amount,
            .lock_period = lock_period,
            .start_timestamp = now,
            .unlock_timestamp = now + @as(i64, @intCast(lock_period.getSeconds())),
            .is_slashed = false,
            .rewards = 0,
            .is_active = true,
        };

        try self.stakes.put(self.allocator, stake_id, position);
        try self.addToStakerIndex(delegator_address, stake_id);
        self.total_staked += amount;

        return stake_id;
    }

    /// Withdraw stake
    pub fn withdrawStake(self: *StakingManager, stake_id: []const u8) !u128 {
        const position = self.stakes.get(stake_id) orelse return error.StakeNotFound;

        if (!position.canWithdraw()) {
            return error.StakeLocked;
        }

        const amount = position.amount;
        const staker = position.staker_address;

        _ = self.stakes.remove(stake_id);
        _ = self.removeFromStakerIndex(staker, stake_id);
        self.total_staked -= amount;

        // Free stake_id
        self.allocator.free(stake_id);

        return amount;
    }

    /// Get stake position
    pub fn getStake(self: *const StakingManager, stake_id: []const u8) ?StakePosition {
        return self.stakes.get(stake_id);
    }

    /// Get all stakes for an address
    pub fn getStakerStakes(self: *const StakingManager, address: [20]u8, allocator: Allocator) ![]StakePosition {
        const key = try self.addressToKey(address);
        defer allocator.free(key);

        const stake_ids = self.staker_stakes.get(key) orelse return &[_]StakePosition{};

        var positions = try allocator.alloc(StakePosition, stake_ids.items.len);
        for (stake_ids.items, 0..) |id, i| {
            const pos = self.stakes.get(id) orelse continue;
            positions[i] = pos.*;
        }

        return positions;
    }

    /// Get total staked by address
    pub fn getStakerTotal(self: *const StakingManager, address: [20]u8) !u128 {
        const stakes = try self.getStakerStakes(address, self.allocator);
        defer self.allocator.free(stakes);

        var total: u128 = 0;
        for (stakes) |stake| {
            if (stake.is_active and !stake.is_slashed) {
                total += stake.amount;
            }
        }

        return total;
    }

    /// Apply slashing to all stakes of a staker
    pub fn slashStaker(self: *StakingManager, address: [20]u8, penalty_percentage: f64) !usize {
        const stakes = try self.getStakerStakes(address, self.allocator);
        defer self.allocator.free(stakes);

        var slashed_count: usize = 0;
        for (stakes) |*stake| {
            if (stake.is_active and !stake.is_slashed) {
                stake.applySlash(penalty_percentage);
                slashed_count += 1;
            }
        }

        return slashed_count;
    }

    pub fn deinit(self: *StakingManager) void {
        var stake_iter = self.stakes.iterator();
        while (stake_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.stakes.deinit(self.allocator);

        var staker_iter = self.staker_stakes.iterator();
        while (staker_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |stake_id| {
                self.allocator.free(stake_id);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.staker_stakes.deinit(self.allocator);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ═════════════════════════════════════════════════════════════════════════

    fn generateStakeId(self: *StakingManager, address: [20]u8, timestamp: i64) ![]const u8 {
        const hex = std.fmt.bytesToHex(&address, .lower);
        const id_str = try std.fmt.allocPrint(self.allocator, "stake_{s}_{d}", .{
            hex,
            timestamp,
        });
        return id_str;
    }

    fn addressToKey(self: *const StakingManager, address: [20]u8) ![]const u8 {
        const hex = std.fmt.bytesToHex(&address, .lower);
        return std.fmt.allocPrint(self.allocator, "{s}", .{hex});
    }

    fn addToStakerIndex(self: *StakingManager, address: [20]u8, stake_id: []const u8) !void {
        const key = try self.addressToKey(address);
        errdefer self.allocator.free(key);

        const duped_id = try self.allocator.dupe(u8, stake_id);
        errdefer self.allocator.free(duped_id);

        if (self.staker_stakes.getEntry(key)) |entry| {
            try entry.value_ptr.append(self.allocator, duped_id);
        } else {
            var list = std.ArrayListUnmanaged([]const u8){};
            try list.append(self.allocator, duped_id);
            try self.staker_stakes.put(self.allocator, key, list);
        }
    }

    fn removeFromStakerIndex(self: *StakingManager, address: [20]u8, stake_id: []const u8) bool {
        const key_alloc = self.addressToKey(address) catch return false;
        defer self.allocator.free(key_alloc);

        if (self.staker_stakes.getEntry(key_alloc)) |entry| {
            const list = entry.value_ptr;
            for (list.items, 0..) |id, i| {
                if (std.mem.eql(u8, id, stake_id)) {
                    _ = list.orderedRemove(i);
                    self.allocator.free(id);
                    if (list.items.len == 0) {
                        list.deinit(self.allocator);
                        _ = self.staker_stakes.remove(entry.key_ptr.*);
                        self.allocator.free(entry.key_ptr.*);
                    }
                    return true;
                }
            }
        }
        return false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LockPeriod multipliers" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), LockPeriod.one_month.getMultiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.2), LockPeriod.three_months.getMultiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), LockPeriod.six_months.getMultiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), LockPeriod.twelve_months.getMultiplier(), 0.01);
}

test "LockPeriod fromString" {
    try std.testing.expectEqual(@as(?LockPeriod, .one_month), LockPeriod.fromString("1M"));
    try std.testing.expectEqual(@as(?LockPeriod, .three_months), LockPeriod.fromString("3M"));
    try std.testing.expectEqual(@as(?LockPeriod, .six_months), LockPeriod.fromString("6M"));
    try std.testing.expectEqual(@as(?LockPeriod, .twelve_months), LockPeriod.fromString("12M"));
    try std.testing.expectEqual(@as(?LockPeriod, null), LockPeriod.fromString("invalid"));
}

test "StakingManager create stake" {
    const allocator = std.testing.allocator;
    var manager = StakingManager.init(allocator);
    defer manager.deinit();

    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0x12;
    address[1] = 0x34;

    const stake_id = try manager.createStake(address, 100 * std.math.pow(u128, 10, 18), .one_month);
    try std.testing.expect(stake_id.len > 0);
}

test "StakingManager minimum stake" {
    const allocator = std.testing.allocator;
    var manager = StakingManager.init(allocator);
    defer manager.deinit();

    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0x56;
    address[1] = 0x78;

    const result = manager.createStake(address, 50 * std.math.pow(u128, 10, 18), .one_month);
    try std.testing.expectError(error.StakeBelowMinimum, result);
}

test "StakePosition calculateRewards" {
    var position: StakePosition = undefined;
    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0x9A;
    address[1] = 0xBC;

    position.stake_id = "test_stake";
    position.staker_address = address;
    position.delegator_address = null;
    position.amount = 1000 * std.math.pow(u128, 10, 18);
    position.lock_period = .six_months; // 1.5x multiplier
    position.start_timestamp = std.time.timestamp() - 3600; // 1 hour ago
    position.unlock_timestamp = std.time.timestamp() + 86400;
    position.is_slashed = false;
    position.rewards = 0;
    position.is_active = true;

    const rewards = position.calculateRewards(1.0); // 1 TRI per hour base
    try std.testing.expect(rewards > 0);
}

test "StakePosition canWithdraw" {
    var position: StakePosition = undefined;
    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0xDE;

    position.stake_id = "test_stake";
    position.staker_address = address;
    position.delegator_address = null;
    position.amount = 1000;
    position.lock_period = .one_month;
    position.start_timestamp = std.time.timestamp();
    position.unlock_timestamp = std.time.timestamp() + 86400;
    position.is_slashed = false;
    position.rewards = 0;
    position.is_active = true;

    try std.testing.expect(!position.canWithdraw()); // Still locked
}

test "StakePosition slash" {
    var position: StakePosition = undefined;
    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0xAB;

    position.stake_id = "test_stake";
    position.staker_address = address;
    position.delegator_address = null;
    position.amount = 1000;
    position.lock_period = .one_month;
    position.start_timestamp = std.time.timestamp();
    position.unlock_timestamp = std.time.timestamp() + 86400;
    position.is_slashed = false;
    position.rewards = 0;
    position.is_active = true;

    position.applySlash(0.5); // 50% penalty
    try std.testing.expectEqual(@as(u128, 500), position.amount);
    try std.testing.expect(position.is_slashed);
}

test "StakingManager delegated stake" {
    const allocator = std.testing.allocator;
    var manager = StakingManager.init(allocator);
    defer manager.deinit();

    var staker: [20]u8 = undefined;
    @memset(&staker, 0);
    staker[0] = 0x11;

    var delegator: [20]u8 = undefined;
    @memset(&delegator, 0);
    delegator[0] = 0x22;

    const stake_id = try manager.createDelegatedStake(staker, delegator, 200 * std.math.pow(u128, 10, 18), .three_months);
    try std.testing.expect(stake_id.len > 0);

    const position = manager.getStake(stake_id).?;
    try std.testing.expect(position.delegator_address != null);
}
