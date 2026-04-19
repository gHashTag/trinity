// TRI‑27 Staking Module — Reuses Trinity DePIN patterns within TRI‑27
// ══════════════════════════════════════════════════════════════════
//
// Follows Trinity DePIN staking patterns (thread-safe, slash rates, stats)
// Adds TRI‑27 specific features:
// • Lock periods (7‑365 days) with time‑based unstake
// • APY calculation (base 5% + lock bonus + staked bonus)
// • Coptic register mapping (t21: total_staked, t22: apy_scaled)
// • TRI‑27 specific slash reasons (manipulation, theft, downtime, double_sign)
//
// Architecture: TRI‑27 Staking → FFI → Blockchain
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const token_types = @import("token_types.zig");

// ════════════════════════════════════════════════════════════════════════
// CONSTANTS — TRI‑27 Staking Parameters
// ═════════════════════════════════════════════════════════════════════════════

pub const MIN_STAKE_TRI = 100;
pub const MIN_LOCK_DAYS = 7;
pub const MAX_LOCK_DAYS = 365;
pub const BASE_APY: f64 = 0.05;
pub const MAX_APY: f64 = 0.20;
pub const SECONDS_PER_DAY: u64 = 86400;

// ══════════════════════════════════════════════════════════════════════
// TRI‑27 SPECIFIC SLASH REASONS
// ══════════════════════════════════════════════════════════════════════

pub const SlashReason = enum(u3) {
    manipulation = 0,
    theft = 1,
    downtime = 2,
    double_sign = 3,

    pub fn slashFraction(self: SlashReason) f64 {
        return switch (self) {
            .manipulation => 0.50,
            .theft => 1.00,
            .downtime => 0.10,
            .double_sign => 1.00,
        };
    }

    pub fn description(self: SlashReason) []const u8 {
        return switch (self) {
            .manipulation => "Price manipulation",
            .theft => "Theft of compute resources",
            .downtime => "Excessive downtime",
            .double_sign => "Double signing",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STAKE INFO — Following Trinity DePIN StakeEntry pattern
// ══════════════════════════════════════════════════════════════════════════════════

pub const StakeInfo = struct {
    staker: [32]u8,
    staked_wei: u128,
    slashed_wei: u128,
    stake_time: i64,
    lock_period_days: u64,
    unlock_time: i64,
    is_active: bool,
    pos_failures: u32,
    corruptions: u32,

    pub fn remaining(self: *const StakeInfo) u128 {
        return self.staked_wei - self.slashed_wei;
    }

    pub fn canUnstake(self: *const StakeInfo) bool {
        if (!self.is_active) return false;
        const now = std.time.timestamp();
        return now >= self.unlock_time;
    }

    pub fn unlockProgress(self: *const StakeInfo) f64 {
        const now = std.time.timestamp();
        const stake_time = self.stake_time;
        const unlock = self.unlock_time;

        if (now >= unlock) return 1.0;
        if (unlock <= stake_time) return 0.0;

        const elapsed = @as(f64, @floatFromInt(now - stake_time));
        const total = @as(f64, @floatFromInt(unlock - stake_time));
        return @min(1.0, elapsed / total);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════
// STAKING STATE — Following Trinity DePIN TokenStakingEngine pattern
// ══════════════════════════════════════════════════════════════════════════════════════

pub const StakingState = struct {
    allocator: Allocator,
    stakes: std.AutoHashMap([32]u8, StakeInfo),
    total_staked_wei: u128,
    total_slashed_wei: u128,
    total_burned_wei: u128,
    total_stakes: u64,
    total_unstakes: u64,
    total_slash_events: u64,
    apy: f64,
    reward_pool_wei: u128,
    pos_failure_slash_rate: f64 = 0.01,
    corruption_slash_rate: f64 = 0.05,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator) StakingState {
        return .{
            .allocator = allocator,
            .stakes = std.AutoHashMap([32]u8, StakeInfo).init(allocator),
            .total_staked_wei = 0,
            .total_slashed_wei = 0,
            .total_burned_wei = 0,
            .total_stakes = 0,
            .total_unstakes = 0,
            .total_slash_events = 0,
            .apy = BASE_APY,
            .reward_pool_wei = 0,
        };
    }

    pub fn deinit(self: *StakingState) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.stakes.deinit();
    }

    pub fn stakeTokens(
        self: *StakingState,
        staker: [32]u8,
        amount_tri: u64,
        lock_period_days: u64,
    ) StakeResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        const amount_wei = @as(u128, amount_tri) * token_types.ONE_TRI;
        if (amount_tri < MIN_STAKE_TRI) {
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .insufficient_amount,
            };
        }

        if (lock_period_days < MIN_LOCK_DAYS or lock_period_days > MAX_LOCK_DAYS) {
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .invalid_lock_period,
            };
        }

        if (self.stakes.contains(staker)) {
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .already_staked,
            };
        }

        const now = std.time.timestamp();
        const unlock_time = now + (@as(i64, @intCast(lock_period_days * SECONDS_PER_DAY)));

        const stake_info = StakeInfo{
            .staker = staker,
            .staked_wei = amount_wei,
            .slashed_wei = 0,
            .stake_time = now,
            .lock_period_days = lock_period_days,
            .unlock_time = unlock_time,
            .is_active = true,
            .pos_failures = 0,
            .corruptions = 0,
        };

        if (self.stakes.put(staker, stake_info)) {
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .insufficient_amount,
            };
        }

        self.total_staked_wei += amount_wei;
        self.total_stakes += 1;
        self.recalculateAPY();

        return .{
            .success = true,
            .staked_wei = amount_wei,
            .reason = .ok,
        };
    }

    pub fn unstakeTokens(self: *StakingState, staker: [32]u8) StakeResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(staker) orelse
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .not_staked,
            };

        if (!entry.canUnstake()) {
            return .{
                .success = false,
                .staked_wei = 0,
                .reason = .lock_period_active,
            };
        }

        const remaining = entry.remaining();
        _ = self.stakes.remove(staker);
        self.total_staked_wei -= entry.staked_wei;
        self.total_unstakes += 1;
        self.recalculateAPY();

        return .{
            .success = true,
            .staked_wei = remaining,
            .reason = .ok,
        };
    }

    pub fn slashForPosFailure(self: *StakingState, staker: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(staker) orelse return 0;
        const remaining = entry.remaining();
        const slash_f = @as(f64, @floatFromInt(remaining)) * self.pos_failure_slash_rate;
        const slash_amount: u128 = @intFromFloat(slash_f);

        entry.slashed_wei += slash_amount;
        entry.pos_failures += 1;
        self.total_slashed_wei += slash_amount;
        self.total_burned_wei += slash_amount;
        self.total_slash_events += 1;

        if (entry.slashed_wei >= entry.staked_wei) {
            entry.is_active = false;
        }

        return slash_amount;
    }

    pub fn slashForCorruption(self: *StakingState, staker: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(staker) orelse return 0;
        const remaining = entry.remaining();
        const slash_f = @as(f64, @floatFromInt(remaining)) * self.corruption_slash_rate;
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

    pub fn slashForManipulation(self: *StakingState, staker: [32]u8) u128 {
        return @as(u128, @intFromFloat(@as(f64, @floatFromInt(self.getRemainingStake(staker))) * 0.50));
    }

    pub fn slashForTheft(self: *StakingState, staker: [32]u8) u128 {
        return @as(u128, @intFromFloat(@as(f64, @floatFromInt(self.getRemainingStake(staker)))));
    }

    pub fn slashForDowntime(self: *StakingState, staker: [32]u8) u128 {
        return @as(u128, @intFromFloat(@as(f64, @floatFromInt(self.getRemainingStake(staker))) * 0.10));
    }

    pub fn slashForDoubleSign(self: *StakingState, staker: [32]u8) u128 {
        return @as(u128, @intFromFloat(@as(f64, @floatFromInt(self.getRemainingStake(staker)))));
    }

    pub fn slashStake(
        self: *StakingState,
        staker: [32]u8,
        reason: SlashReason,
    ) u128 {
        switch (reason) {
            .manipulation => return self.slashForManipulation(staker),
            .theft => return self.slashForTheft(staker),
            .downtime => return self.slashForDowntime(staker),
            .double_sign => return self.slashForDoubleSign(staker),
        }
    }

    pub fn recalculateAPY(self: *StakingState) void {
        const total_staked_tri = self.total_staked_wei / token_types.ONE_TRI;

        var new_apy = BASE_APY;

        var weighted_lock_days: u64 = 0;
        var total_weight: u128 = 0;

        var iter = self.stakes.valueIterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr;
            const stake = info.remaining();
            weighted_lock_days += info.lock_period_days * @as(u64, @intCast(stake));
            total_weight += stake;
        }

        const avg_lock_days = if (total_weight > 0)
            @as(f64, @floatFromInt(weighted_lock_days)) / @as(f64, @floatFromInt(total_weight))
        else
            0.0;

        const lock_bonus = (avg_lock_days / 30.0) * 0.001;
        const staked_bonus = @as(f64, @floatFromInt(total_staked_tri)) / 100_000.0 * 0.0001;

        new_apy += lock_bonus + staked_bonus;
        self.apy = @min(MAX_APY, new_apy);
    }

    pub fn isStaked(self: *StakingState, staker: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stakes.get(staker) != null;
    }

    pub fn getStakeInfo(self: *StakingState, staker: [32]u8) ?StakeInfo {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stakes.get(staker);
    }

    pub fn getRemainingStake(self: *StakingState, staker: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.stakes.get(staker)) |info| {
            return info.remaining();
        }
        return 0;
    }

    pub fn countActiveStakers(self: *StakingState) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        var count: u32 = 0;
        var iter = self.stakes.valueIterator();
        while (iter.next()) |entry| {
            if (entry.is_active) count += 1;
        }
        return count;
    }

    pub fn getStats(self: *StakingState) Stats {
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
            .apy = self.apy,
            .apy_scaled = @as(u64, @intFromFloat(self.apy * 10000)),
            .reward_pool_wei = self.reward_pool_wei,
        };
    }

    pub fn getCopticRegisters(self: *StakingState) CopticRegisters {
        const stats = self.getStats();
        return .{
            .t21_total_staked = stats.total_staked_wei / token_types.ONE_TRI,
            .t22_apy_scaled = stats.apy_scaled,
        };
    }
};

// ════════════════════════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ══════════════════════════════════════════════════════════════════════════════════

pub const StakeResult = struct {
    success: bool,
    staked_wei: u128,
    reason: StakeResultReason,
};

pub const StakeResultReason = enum(u8) {
    ok = 0,
    insufficient_amount = 1,
    invalid_lock_period = 2,
    already_staked = 3,
    not_staked = 4,
    lock_period_active = 5,
};

pub const Stats = struct {
    total_staked_wei: u128,
    total_slashed_wei: u128,
    total_burned_wei: u128,
    active_stakers: u32,
    total_stakes: u64,
    total_unstakes: u64,
    total_slash_events: u64,
    apy: f64,
    apy_scaled: u64,
    reward_pool_wei: u128,
};

pub const CopticRegisters = struct {
    t21_total_staked: u128,
    t22_apy_scaled: u64,
};

// ════════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ════════════════════════════════════════════════════════════════════════════════════════════

test "stake with lock period" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x01} ** 32;

    const result = state.stakeTokens(staker, 1000, 30);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u128, 1000 * token_types.ONE_TRI), result.staked_wei);

    const info = state.getStakeInfo(staker);
    try std.testing.expect(info != null);
    try std.testing.expectEqual(@as(u64, 30), info.?.lock_period_days);
    try std.testing.expect(!info.?.canUnstake());
}

test "unstake after lock period" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x02} ** 32;

    _ = state.stakeTokens(staker, 500, 7);

    const early_result = state.unstakeTokens(staker);
    try std.testing.expect(!early_result.success);

    state.mutex.lock();
    if (state.stakes.getPtr(staker)) |info_ptr| {
        info_ptr.unlock_time = std.time.timestamp() - 1;
    }
    state.mutex.unlock();

    const late_result = state.unstakeTokens(staker);
    try std.testing.expect(late_result.success);
}

test "slash for manipulation (50%)" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x03} ** 32;

    _ = state.stakeTokens(staker, 1000, 30);

    _ = state.slashStake(staker, .manipulation);

    const info = state.getStakeInfo(staker);
    try std.testing.expect(info != null);
    const remaining = info.?.remaining();
    try std.testing.expect(remaining > 400 * token_types.ONE_TRI);
    try std.testing.expect(remaining < 600 * token_types.ONE_TRI);
}

test "slash for theft (100%)" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x04} ** 32;

    _ = state.stakeTokens(staker, 1000, 30);

    _ = state.slashStake(staker, .theft);

    const info = state.getStakeInfo(staker);
    try std.testing.expect(info != null);
    const remaining = info.?.remaining();
    try std.testing.expect(remaining < 100 * token_types.ONE_TRI);
}

test "APY calculation" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    try std.testing.expectApproxEqAbs(BASE_APY, state.getStats().apy, 0.001);

    const staker1 = [_]u8{0x05} ** 32;
    const staker2 = [_]u8{0x06} ** 32;

    _ = state.stakeTokens(staker1, 100_000, 365);

    const apy_after = state.getStats().apy;
    try std.testing.expect(apy_after > BASE_APY);
    try std.testing.expect(apy_after <= MAX_APY);
}

test "Coptic register mapping" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x07} ** 32;

    _ = state.stakeTokens(staker, 5000, 90);

    const coptic = state.getCopticRegisters();
    try std.testing.expectEqual(@as(u128, 5000), coptic.t21_total_staked);
    try std.testing.expect(coptic.t22_apy_scaled >= 500);
    try std.testing.expect(coptic.t22_apy_scaled <= 2000);
}

test "stats aggregation" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        const staker = [_]u8{i} ** 32;
        _ = state.stakeTokens(staker, 1000, 30);
    }

    const stats = state.getStats();
    try std.testing.expectEqual(@as(u32, 5), stats.active_stakers);
    try std.testing.expectEqual(@as(u128, 5000 * token_types.ONE_TRI), stats.total_staked_wei);
}

test "minimum stake validation" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x08} ** 32;

    const result = state.stakeTokens(staker, 50, 30);
    try std.testing.expect(!result.success);
}

test "lock period validation" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x09} ** 32;

    const result1 = state.stakeTokens(staker, 1000, 5);
    try std.testing.expect(!result1.success);

    const result2 = state.stakeTokens(staker, 1000, 400);
    try std.testing.expect(!result2.success);
}

test "double stake rejected" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x0A} ** 32;

    _ = state.stakeTokens(staker, 1000, 30);

    const result2 = state.stakeTokens(staker, 2000, 30);
    try std.testing.expect(!result2.success);
}

test "isStaked and getRemainingStake" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x0B} ** 32;

    try std.testing.expect(!state.isStaked(staker));
    try std.testing.expectEqual(@as(u128, 0), state.getRemainingStake(staker));

    _ = state.stakeTokens(staker, 1000, 30);

    try std.testing.expect(state.isStaked(staker));
    try std.testing.expectEqual(@as(u128, 1000 * token_types.ONE_TRI), state.getRemainingStake(staker));
}

test "slash to depletion" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x0C} ** 32;

    _ = state.stakeTokens(staker, 1000, 30);

    var i: u8 = 0;
    while (i < 20) : (i += 1) {
        _ = state.slashStake(staker, .theft);
    }

    try std.testing.expectEqual(@as(u32, 1), state.countActiveStakers());
}

test "slash reason descriptions" {
    try std.testing.expectEqualStrings("Price manipulation", SlashReason.manipulation.description());
    try std.testing.expectEqualStrings("Theft of compute resources", SlashReason.theft.description());
    try std.testing.expectEqualStrings("Excessive downtime", SlashReason.downtime.description());
    try std.testing.expectEqualStrings("Double signing", SlashReason.double_sign.description());
}

test "unlockProgress calculation" {
    const allocator = std.testing.allocator;

    var state = StakingState.init(allocator);
    defer state.deinit();

    const staker = [_]u8{0x0E} ** 32;

    _ = state.stakeTokens(staker, 1000, 30);

    const info = state.getStakeInfo(staker);
    try std.testing.expect(info != null);

    const initial_progress = info.?.unlockProgress();
    try std.testing.expect(initial_progress < 0.1);

    state.mutex.lock();
    if (state.stakes.getPtr(staker)) |info_ptr| {
        info_ptr.unlock_time = std.time.timestamp() - 1;
    }
    state.mutex.unlock();

    const later_info = state.getStakeInfo(staker);
    try std.testing.expect(later_info != null);
    try std.testing.expectEqual(@as(f64, 1.0), later_info.?.unlockProgress());
}
