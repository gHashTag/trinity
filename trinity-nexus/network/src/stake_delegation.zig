// =============================================================================
// TRINITY STAKE DELEGATION v1.9 - Delegate $TRI to Operators
// Token holders can delegate stake to operators, sharing rewards and slashing
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// DELEGATION CONFIGURATION
// =============================================================================

pub const DelegationConfig = struct {
    /// Minimum delegation amount (wei)
    min_delegation_wei: u128 = 10_000_000_000_000_000_000, // 10 TRI
    /// Maximum delegators per operator
    max_delegators_per_operator: u32 = 100,
    /// Operator commission rate (fraction of delegator rewards)
    default_commission_rate: f64 = 0.10, // 10%
    /// Slashing is shared: operator takes this fraction of total slash
    operator_slash_share: f64 = 0.50, // 50% of slash hits operator, 50% delegators
};

pub const DelegationEntry = struct {
    delegator_id: [32]u8,
    operator_id: [32]u8,
    amount_wei: u128,
    delegation_time: i64,
    rewards_earned_wei: u128,
    slashed_wei: u128,
    is_active: bool,
};

pub const OperatorInfo = struct {
    operator_id: [32]u8,
    commission_rate: f64,
    total_delegated_wei: u128,
    delegator_count: u32,
    total_rewards_distributed_wei: u128,
    total_slashed_wei: u128,
};

pub const DelegationResult = struct {
    success: bool,
    reason: DelegationReason,
    amount_wei: u128,
};

pub const DelegationReason = enum {
    ok,
    insufficient_amount,
    operator_full,
    already_delegated,
    not_delegated,
    self_delegation,
};

pub const DelegationStats = struct {
    total_delegated_wei: u128,
    total_undelegated_wei: u128,
    total_rewards_wei: u128,
    total_slashed_wei: u128,
    active_delegations: u32,
    total_operators: u32,
};

// =============================================================================
// STAKE DELEGATION ENGINE
// =============================================================================

pub const StakeDelegationEngine = struct {
    allocator: std.mem.Allocator,
    config: DelegationConfig,
    delegations: std.AutoHashMap([32]u8, DelegationEntry), // delegator_id -> entry
    operators: std.AutoHashMap([32]u8, OperatorInfo), // operator_id -> info
    total_delegated_wei: u128,
    total_undelegated_wei: u128,
    total_rewards_wei: u128,
    total_slashed_wei: u128,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) StakeDelegationEngine {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: DelegationConfig) StakeDelegationEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .delegations = std.AutoHashMap([32]u8, DelegationEntry).init(allocator),
            .operators = std.AutoHashMap([32]u8, OperatorInfo).init(allocator),
            .total_delegated_wei = 0,
            .total_undelegated_wei = 0,
            .total_rewards_wei = 0,
            .total_slashed_wei = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *StakeDelegationEngine) void {
        self.delegations.deinit();
        self.operators.deinit();
    }

    /// Register an operator that can accept delegations
    pub fn registerOperator(self: *StakeDelegationEngine, operator_id: [32]u8, commission_rate: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const clamped = @min(1.0, @max(0.0, commission_rate));

        try self.operators.put(operator_id, .{
            .operator_id = operator_id,
            .commission_rate = clamped,
            .total_delegated_wei = 0,
            .delegator_count = 0,
            .total_rewards_distributed_wei = 0,
            .total_slashed_wei = 0,
        });
    }

    /// Delegate tokens from delegator to operator
    pub fn delegate(self: *StakeDelegationEngine, delegator_id: [32]u8, operator_id: [32]u8, amount_wei: u128) DelegationResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Prevent self-delegation
        if (std.mem.eql(u8, &delegator_id, &operator_id)) {
            return .{ .success = false, .reason = .self_delegation, .amount_wei = 0 };
        }

        // Check minimum amount
        if (amount_wei < self.config.min_delegation_wei) {
            return .{ .success = false, .reason = .insufficient_amount, .amount_wei = 0 };
        }

        // Check not already delegated
        if (self.delegations.contains(delegator_id)) {
            return .{ .success = false, .reason = .already_delegated, .amount_wei = 0 };
        }

        // Check operator exists and not full
        const op = self.operators.getPtr(operator_id) orelse {
            return .{ .success = false, .reason = .operator_full, .amount_wei = 0 };
        };

        if (op.delegator_count >= self.config.max_delegators_per_operator) {
            return .{ .success = false, .reason = .operator_full, .amount_wei = 0 };
        }

        // Create delegation
        self.delegations.put(delegator_id, .{
            .delegator_id = delegator_id,
            .operator_id = operator_id,
            .amount_wei = amount_wei,
            .delegation_time = std.time.timestamp(),
            .rewards_earned_wei = 0,
            .slashed_wei = 0,
            .is_active = true,
        }) catch {
            return .{ .success = false, .reason = .operator_full, .amount_wei = 0 };
        };

        op.total_delegated_wei += amount_wei;
        op.delegator_count += 1;
        self.total_delegated_wei += amount_wei;

        return .{ .success = true, .reason = .ok, .amount_wei = amount_wei };
    }

    /// Undelegate: return remaining amount after slashing
    pub fn undelegate(self: *StakeDelegationEngine, delegator_id: [32]u8) DelegationResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.delegations.getPtr(delegator_id) orelse {
            return .{ .success = false, .reason = .not_delegated, .amount_wei = 0 };
        };

        if (!entry.is_active) {
            return .{ .success = false, .reason = .not_delegated, .amount_wei = 0 };
        }

        const remaining = if (entry.amount_wei > entry.slashed_wei)
            entry.amount_wei - entry.slashed_wei
        else
            0;

        // Update operator
        if (self.operators.getPtr(entry.operator_id)) |op| {
            if (op.total_delegated_wei >= entry.amount_wei) {
                op.total_delegated_wei -= entry.amount_wei;
            } else {
                op.total_delegated_wei = 0;
            }
            if (op.delegator_count > 0) op.delegator_count -= 1;
        }

        entry.is_active = false;
        self.total_undelegated_wei += remaining;

        return .{ .success = true, .reason = .ok, .amount_wei = remaining };
    }

    /// Distribute rewards to an operator and their delegators
    /// Total reward split: operator gets commission, delegators get rest proportional to delegation
    pub fn distributeRewards(self: *StakeDelegationEngine, operator_id: [32]u8, total_reward_wei: u128) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const op = self.operators.getPtr(operator_id) orelse return 0;

        // Commission for operator
        const commission_f: f64 = @floatFromInt(total_reward_wei);
        const operator_share: u128 = @intFromFloat(commission_f * op.commission_rate);
        const delegator_pool = total_reward_wei - operator_share;

        if (op.total_delegated_wei == 0 or op.delegator_count == 0) {
            op.total_rewards_distributed_wei += total_reward_wei;
            self.total_rewards_wei += total_reward_wei;
            return total_reward_wei; // All goes to operator
        }

        // Distribute to delegators proportional to stake
        var iter = self.delegations.iterator();
        while (iter.next()) |kv| {
            const entry = kv.value_ptr;
            if (!entry.is_active) continue;
            if (!std.mem.eql(u8, &entry.operator_id, &operator_id)) continue;

            // Proportional share
            const share_f: f64 = @as(f64, @floatFromInt(entry.amount_wei)) / @as(f64, @floatFromInt(op.total_delegated_wei));
            const delegator_reward: u128 = @intFromFloat(@as(f64, @floatFromInt(delegator_pool)) * share_f);
            entry.rewards_earned_wei += delegator_reward;
        }

        op.total_rewards_distributed_wei += total_reward_wei;
        self.total_rewards_wei += total_reward_wei;

        return total_reward_wei;
    }

    /// Slash operator and their delegators
    /// Operator takes operator_slash_share of total slash, rest divided among delegators
    pub fn slashOperator(self: *StakeDelegationEngine, operator_id: [32]u8, slash_amount_wei: u128) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const op = self.operators.getPtr(operator_id) orelse return 0;

        // Split slash between operator and delegators
        const operator_slash_f: f64 = @floatFromInt(slash_amount_wei);
        const operator_portion: u128 = @intFromFloat(operator_slash_f * self.config.operator_slash_share);
        const delegator_portion = slash_amount_wei - operator_portion;

        op.total_slashed_wei += operator_portion;

        // Distribute delegator portion proportionally
        if (op.total_delegated_wei > 0 and delegator_portion > 0) {
            var iter = self.delegations.iterator();
            while (iter.next()) |kv| {
                const entry = kv.value_ptr;
                if (!entry.is_active) continue;
                if (!std.mem.eql(u8, &entry.operator_id, &operator_id)) continue;

                const share_f: f64 = @as(f64, @floatFromInt(entry.amount_wei)) / @as(f64, @floatFromInt(op.total_delegated_wei));
                const delegator_slash: u128 = @intFromFloat(@as(f64, @floatFromInt(delegator_portion)) * share_f);
                entry.slashed_wei += delegator_slash;

                // Deactivate if fully slashed
                if (entry.slashed_wei >= entry.amount_wei) {
                    entry.is_active = false;
                }
            }
        }

        self.total_slashed_wei += slash_amount_wei;
        return slash_amount_wei;
    }

    /// Get delegation entry
    pub fn getDelegation(self: *StakeDelegationEngine, delegator_id: [32]u8) ?DelegationEntry {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.delegations.get(delegator_id);
    }

    /// Get operator info
    pub fn getOperator(self: *StakeDelegationEngine, operator_id: [32]u8) ?OperatorInfo {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.operators.get(operator_id);
    }

    /// Count active delegations
    pub fn countActiveDelegations(self: *StakeDelegationEngine) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        var count: u32 = 0;
        var iter = self.delegations.valueIterator();
        while (iter.next()) |entry| {
            if (entry.is_active) count += 1;
        }
        return count;
    }

    /// Get stats
    pub fn getStats(self: *StakeDelegationEngine) DelegationStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active: u32 = 0;
        var iter = self.delegations.valueIterator();
        while (iter.next()) |entry| {
            if (entry.is_active) active += 1;
        }

        return .{
            .total_delegated_wei = self.total_delegated_wei,
            .total_undelegated_wei = self.total_undelegated_wei,
            .total_rewards_wei = self.total_rewards_wei,
            .total_slashed_wei = self.total_slashed_wei,
            .active_delegations = active,
            .total_operators = @intCast(self.operators.count()),
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "delegate and undelegate" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;
    const delegator = [_]u8{0x02} ** 32;

    try engine.registerOperator(operator, 0.10);

    const result = engine.delegate(delegator, operator, 1000);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u128, 1000), result.amount_wei);

    const entry = engine.getDelegation(delegator);
    try std.testing.expect(entry != null);
    try std.testing.expect(entry.?.is_active);

    const undel = engine.undelegate(delegator);
    try std.testing.expect(undel.success);
    try std.testing.expectEqual(@as(u128, 1000), undel.amount_wei);
}

test "insufficient delegation rejected" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 1000,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;
    const delegator = [_]u8{0x02} ** 32;

    try engine.registerOperator(operator, 0.10);

    const result = engine.delegate(delegator, operator, 500);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(DelegationReason.insufficient_amount, result.reason);
}

test "self-delegation rejected" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.init(allocator);
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    try engine.registerOperator(node, 0.10);

    const result = engine.delegate(node, node, 1_000_000);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(DelegationReason.self_delegation, result.reason);
}

test "double delegation rejected" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;
    const delegator = [_]u8{0x02} ** 32;

    try engine.registerOperator(operator, 0.10);

    const result1 = engine.delegate(delegator, operator, 1000);
    try std.testing.expect(result1.success);

    const result2 = engine.delegate(delegator, operator, 2000);
    try std.testing.expect(!result2.success);
    try std.testing.expectEqual(DelegationReason.already_delegated, result2.reason);
}

test "operator full rejects delegation" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 2, // Only 2 slots
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;

    try engine.registerOperator(operator, 0.10);

    // Fill both slots
    const d1 = [_]u8{0x10} ** 32;
    const d2 = [_]u8{0x11} ** 32;
    const d3 = [_]u8{0x12} ** 32;

    try std.testing.expect(engine.delegate(d1, operator, 500).success);
    try std.testing.expect(engine.delegate(d2, operator, 500).success);

    // Third should fail
    const result = engine.delegate(d3, operator, 500);
    try std.testing.expect(!result.success);
    try std.testing.expectEqual(DelegationReason.operator_full, result.reason);
}

test "reward distribution with commission" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;
    const d1 = [_]u8{0x10} ** 32;
    const d2 = [_]u8{0x11} ** 32;

    try engine.registerOperator(operator, 0.20); // 20% commission

    _ = engine.delegate(d1, operator, 600); // 60% of pool
    _ = engine.delegate(d2, operator, 400); // 40% of pool

    // Distribute 1000 wei reward
    const distributed = engine.distributeRewards(operator, 1000);
    try std.testing.expectEqual(@as(u128, 1000), distributed);

    // Operator gets 20% = 200, delegator pool = 800
    // d1 gets 60% of 800 = 480, d2 gets 40% of 800 = 320
    const e1 = engine.getDelegation(d1).?;
    const e2 = engine.getDelegation(d2).?;
    try std.testing.expect(e1.rewards_earned_wei >= 470 and e1.rewards_earned_wei <= 490);
    try std.testing.expect(e2.rewards_earned_wei >= 310 and e2.rewards_earned_wei <= 330);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u128, 1000), stats.total_rewards_wei);
}

test "slashing shared between operator and delegators" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50, // 50-50 split
    });
    defer engine.deinit();

    const operator = [_]u8{0x01} ** 32;
    const d1 = [_]u8{0x10} ** 32;
    const d2 = [_]u8{0x11} ** 32;

    try engine.registerOperator(operator, 0.10);

    _ = engine.delegate(d1, operator, 500);
    _ = engine.delegate(d2, operator, 500);

    // Slash 100 wei total: 50 to operator, 50 to delegators (25 each)
    const slashed = engine.slashOperator(operator, 100);
    try std.testing.expectEqual(@as(u128, 100), slashed);

    const op = engine.getOperator(operator).?;
    try std.testing.expectEqual(@as(u128, 50), op.total_slashed_wei);

    const e1 = engine.getDelegation(d1).?;
    const e2 = engine.getDelegation(d2).?;
    try std.testing.expectEqual(@as(u128, 25), e1.slashed_wei);
    try std.testing.expectEqual(@as(u128, 25), e2.slashed_wei);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u128, 100), stats.total_slashed_wei);
}

test "delegation stats" {
    const allocator = std.testing.allocator;

    var engine = StakeDelegationEngine.initWithConfig(allocator, .{
        .min_delegation_wei = 100,
        .max_delegators_per_operator = 10,
        .default_commission_rate = 0.10,
        .operator_slash_share = 0.50,
    });
    defer engine.deinit();

    const op1 = [_]u8{0x01} ** 32;
    const op2 = [_]u8{0x02} ** 32;

    try engine.registerOperator(op1, 0.10);
    try engine.registerOperator(op2, 0.15);

    const d1 = [_]u8{0x10} ** 32;
    const d2 = [_]u8{0x11} ** 32;
    const d3 = [_]u8{0x12} ** 32;

    _ = engine.delegate(d1, op1, 500);
    _ = engine.delegate(d2, op1, 300);
    _ = engine.delegate(d3, op2, 700);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u128, 1500), stats.total_delegated_wei);
    try std.testing.expectEqual(@as(u32, 3), stats.active_delegations);
    try std.testing.expectEqual(@as(u32, 2), stats.total_operators);
}
