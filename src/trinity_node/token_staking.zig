// =============================================================================
// TRINITY TOKEN STAKING v3.1 - Sacred Supply + LST Limits + Dynamic Deterrence
// Nodes must stake tokens to participate; slashing burns stake on violations
// v3.1: LST concentration limits, dynamic verification probability
//
// SACRED NUMBER: Total Supply = 3^21 = 10,460,353,203 $TRI
// Derived from Trinity Identity: unique states of 21 balanced ternary trits
//
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const node_reputation_mod = @import("node_reputation.zig");

// =============================================================================
// SACRED CONSTANTS
// =============================================================================

/// SACRED: Total $TRI supply = 3^21 (21 balanced ternary trits)
pub const SACRED_SUPPLY: u256 = 10_460_353_203 * 1_000_000_000_000_000_000; // 18 decimals

/// Maximum stake per operator (1% of sacred supply)
pub const MAX_STAKE_PER_OPERATOR: u256 = SACRED_SUPPLY / 100;

/// Minimum stake for governance participation (0.001% of sacred supply)
pub const GOVERNANCE_MIN_STAKE: u256 = SACRED_SUPPLY / 100_000;

// =============================================================================
// CONSTANTS v3.1
// =============================================================================

/// Unbonding period: 7 days to detect slashable offenses
pub const UNBONDING_PERIOD_SECS: u64 = 7 * 24 * 3600;

/// Maximum pending unbond requests per node
const MAX_UNBOND_REQUESTS: usize = 16;

/// v3.1: Base verification probability (can be adjusted dynamically)
pub const BASE_VERIFICATION_PROBABILITY: f64 = 0.95; // 95%

/// v3.1: Minimum verification probability (lower bound)
pub const MIN_VERIFICATION_PROBABILITY: f64 = 0.50; // 50%

/// v3.1: Maximum verification probability (upper bound)
pub const MAX_VERIFICATION_PROBABILITY: f64 = 0.99; // 99%

/// v3.1: Maximum LST protocol concentration (30% = 3000 bps)
pub const MAX_LST_CONCENTRATION_BPS: u256 = 3000;

/// v3.1: Correlation bonus for mass slash events
pub const CORRELATION_SLASH_BONUS: f64 = 0.03; // +3%

/// v3.1: Independent monitor bonus per monitor
pub const INDEPENDENT_MONITOR_BONUS: f64 = 0.01; // +1% per monitor

// =============================================================================
// STAKING CONFIGURATION v3.1
// =============================================================================

pub const StakingConfig = struct {
    /// v3.0: USD-pegged minimum stake ($100 USD)
    min_stake_usd: u128 = 100 * 1e18, // $100 minimum (18 decimals)

    /// v3.0: USD-pegged maximum stake per operator ($1M USD)
    max_stake_usd: u128 = 1_000_000 * 1e18, // $1M max per operator

    /// Legacy: Minimum stake in TRI (100 TRI) - DEPRECATED, use min_stake_usd
    min_stake_wei: u128 = 100_000_000_000_000_000_000, // 100 TRI (DEPRECATED)

    /// Minimum reputation score to avoid automatic unstaking
    min_reputation_for_staking: f64 = 0.2,

    /// Maximum slash history entries to keep per node
    max_slash_history: usize = 32,

    /// v3.1: Dynamic verification probability enabled
    enable_dynamic_verification: bool = true,

    /// v3.1: Number of independent monitoring sources
    independent_monitors: u32 = 3,
};

// =============================================================================
// TIERED SLASHING SYSTEM (v2.0)
// =============================================================================

/// Slash severity levels (Polkadot-inspired tiered system)
pub const SlashLevel = enum(u8) {
    /// 0.1% - honest mistakes (missed heartbeat, transient failure)
    minor = 0,
    /// 1% - repeated failures (current default equivalent)
    moderate = 1,
    /// 10% - coordinated attacks or severe protocol violations
    major = 2,
    /// 100% - malicious behavior, complete stake forfeiture
    severe = 3,

    /// Get slash rate as fraction (0.0 to 1.0)
    pub fn rate(self: SlashLevel) f64 {
        return switch (self) {
            .minor => 0.001, // 0.1%
            .moderate => 0.01, // 1%
            .major => 0.10, // 10%
            .severe => 1.00, // 100%
        };
    }

    /// Get human-readable description
    pub fn description(self: SlashLevel) []const u8 {
        return switch (self) {
            .minor => "Honest mistake (0.1%)",
            .moderate => "Repeated failure (1%)",
            .major => "Protocol violation (10%)",
            .severe => "Malicious behavior (100%)",
        };
    }
};

/// Detailed slash condition for audit trail
pub const SlashCondition = struct {
    level: SlashLevel,
    reason: []const u8,
    evidence: []const u8,
    timestamp: i64,
};

/// Slash event history entry
pub const SlashEvent = struct {
    node_id: [32]u8,
    level: SlashLevel,
    amount_slashed_wei: u128,
    reason: []const u8,
    timestamp: i64,
};

/// Unbonding request for delayed unstake
pub const UnbondRequest = struct {
    node_id: [32]u8,
    amount_wei: u128,
    request_time: i64,
    unlock_time: i64,
    is_withdrawn: bool,
};

pub const StakeEntry = struct {
    staked_wei: u128,
    slashed_wei: u128,
    stake_time: i64,
    slash_count: u32 = 0, // v2.0: Total slash events
    last_slash_time: i64 = 0, // v2.0: Time of most recent slash
    is_active: bool,
    /// v2.0: Slash history (up to max_slash_history entries)
    slash_history: std.ArrayListUnmanaged(SlashEvent) = .{},
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
    /// v2.0: Pending unbond amount
    pending_unbond_wei: u128,
    /// v2.0: Active unbond requests count
    active_unbonds: u32,
    /// v3.0: Percentage of sacred supply staked
    sacred_supply_staked_bp: u32, // basis points (10000 = 100%)
};

// =============================================================================
// v3.1: LIQUID STAKING SUPPORT + CONCENTRATION LIMITS
// =============================================================================

/// v3.1: LST Protocol configuration
pub const LstProtocolConfig = struct {
    name: []const u8,
    address: [32]u8,
    verified: bool = false, // Passed security audit
    max_concentration_bps: u256 = 3000, // 30% max per protocol
};

/// v3.1: LST concentration tracking
pub const LstConcentration = struct {
    protocol: []const u8,
    total_staked: u128,
    concentration_bps: u256, // basis points (10000 = 100%)
};

/// Liquid staking protocol support
pub const LiquidStakeRequest = struct {
    node_id: [32]u8,
    amount_wei: u128,
    lst_protocol: []const u8, // e.g., "sfTRI", "glifTRI"
    lst_address: [32]u8, // Contract address
    request_time: i64,
};

/// v3.1: Liquid staking engine with concentration limits
pub const LiquidStakeEngine = struct {
    base: TokenStakingEngine,
    requests: std.AutoHashMap(u32, LiquidStakeRequest),
    next_request_id: u32,

    /// v3.1: Verified LST protocols
    verified_protocols: std.StringHashMap(bool),

    /// v3.1: Current concentration per protocol
    concentration_map: std.StringHashMap(u256), // protocol -> amount staked

    /// Protocols supported for liquid staking (legacy, for compatibility)
    supported_lst_protocols: std.StringHashMap([32]u8),

    pub fn init(allocator: std.mem.Allocator) LiquidStakeEngine {
        const base = TokenStakingEngine.init(allocator);
        return .{
            .base = base,
            .requests = std.AutoHashMap(u32, LiquidStakeRequest).init(allocator),
            .next_request_id = 0,
            .verified_protocols = std.StringHashMap(bool).init(allocator),
            .concentration_map = std.StringHashMap(u256).init(allocator),
            .supported_lst_protocols = std.StringHashMap([32]u8).init(allocator),
        };
    }

    pub fn deinit(self: *LiquidStakeEngine) void {
        self.base.deinit();
        self.requests.deinit();
        self.verified_protocols.deinit();
        self.concentration_map.deinit();
        self.supported_lst_protocols.deinit();
    }

    /// v3.1: Register a verified LST protocol
    pub fn registerVerifiedLst(self: *LiquidStakeEngine, name: []const u8, address: [32]u8) !void {
        try self.verified_protocols.put(name, true);
        try self.supported_lst_protocols.put(name, address);
    }

    /// v3.1: Get current concentration for a protocol
    pub fn getConcentration(self: *LiquidStakeEngine, protocol: []const u8) struct {
        total: u128,
        bps: u256,
    } {
        const total = self.concentration_map.get(protocol) orelse 0;
        const total_staked = self.base.totalStaked();
        const bps = if (total_staked > 0)
            (@as(u256, total) * 10000) / @as(u256, total_staked)
        else
            0;
        return .{ .total = total, .bps = bps };
    }

    /// v3.1: Request liquid staking with concentration check
    pub fn requestLiquidStake(self: *LiquidStakeEngine, node_id: [32]u8, amount_wei: u128, lst_protocol: []const u8) !u32 {
        // v3.1: Verify protocol is verified (not just supported)
        const is_verified = self.verified_protocols.get(lst_protocol) orelse false;
        if (!is_verified) {
            return error.UnverifiedLSTProtocol;
        }

        // Get LST address
        const lst_address = self.supported_lst_protocols.get(lst_protocol) orelse return error.LSTProtocolNotFound;

        // v3.1: Check concentration limit
        const current = self.concentration_map.get(lst_protocol) orelse 0;
        const total_staked = self.base.totalStaked();
        const new_concentration_bps = ((current + amount_wei) * 10000) / total_staked;

        if (new_concentration_bps > MAX_LST_CONCENTRATION_BPS) {
            std.log.warn("LST concentration limit exceeded: {s} would reach {d} bps", .{ lst_protocol, new_concentration_bps });
            return error.LSTConcentrationLimitExceeded;
        }

        // Update concentration
        try self.concentration_map.put(lst_protocol, current + amount_wei);

        // Request unbond first (can't liquid stake active stake)
        _ = try self.base.requestUnbond(node_id, amount_wei);

        const request_id = self.next_request_id;
        self.next_request_id += 1;

        try self.requests.put(request_id, .{
            .node_id = node_id,
            .amount_wei = amount_wei,
            .lst_protocol = lst_protocol,
            .lst_address = lst_address,
            .request_time = std.time.timestamp(),
        });

        return request_id;
    }
};

// =============================================================================
// v3.1: DYNAMIC DETERRENCE EQUATION
// =============================================================================

/// v3.1: Monitoring coverage configuration
pub const MonitoringCoverage = struct {
    /// Percentage of nodes under active monitoring
    coverage_ratio: f64 = 0.95, // 95%

    /// Number of independent monitoring sources
    independent_monitors: u32 = 3,

    /// Last update timestamp
    last_update: i64,
};

/// v3.1: Calculate dynamic verification probability based on conditions
/// Returns P(Verified) in range [0.5, 0.99]
pub fn calculateDynamicPVerified(engine: *TokenStakingEngine, node_id: [32]u8, level: SlashLevel, coverage: MonitoringCoverage) !f64 {
    _ = level; // Severity can be used for future adjustments

    var p = coverage.coverage_ratio;

    // Bonus for independent monitors
    p += @as(f64, @floatFromInt(coverage.independent_monitors)) * INDEPENDENT_MONITOR_BONUS;

    // Penalty for low-reputation nodes
    if (engine.reputation_engine) |rep_engine| {
        if (rep_engine.getScore(node_id)) |score| {
            if (score < 0.3) {
                p -= 0.05; // -5% for suspicious nodes
            }
        }
    }

    // Correlation bonus: mass slash = higher detection probability
    const recent_slashes = getRecentSlashCount(engine, 86400); // Last 24 hours
    if (recent_slashes > 10) {
        p += CORRELATION_SLASH_BONUS;
    }

    // Clamp to [MIN_VERIFICATION_PROBABILITY, MAX_VERIFICATION_PROBABILITY]
    if (p < MIN_VERIFICATION_PROBABILITY) p = MIN_VERIFICATION_PROBABILITY;
    if (p > MAX_VERIFICATION_PROBABILITY) p = MAX_VERIFICATION_PROBABILITY;

    return p;
}

/// v3.1: Get recent slash count within time window (helper)
fn getRecentSlashCount(engine: *TokenStakingEngine, window_secs: i64) u32 {
    _ = engine;
    _ = window_secs;
    // TODO: Implement slash history time-window query
    // For now, return 0 (no recent slashes)
    return 0;
}

/// Legacy: Calculate if slashing is sufficient deterrent (fixed P)
/// E[L] = P(Misconduct Verified) × SlashRate × Stake > GainExploit
pub fn calculateDeterrence(stake_wei: u128, slash_rate: f64, gain_exploit_wei: u128) bool {
    const expected_loss = @as(f64, @floatFromInt(stake_wei)) * BASE_VERIFICATION_PROBABILITY * slash_rate;
    const expected_loss_wei = @as(u128, @intFromFloat(expected_loss));

    return expected_loss_wei > gain_exploit_wei;
}

/// v3.1: Calculate deterrence with dynamic verification probability
pub fn calculateDynamicDeterrence(stake_wei: u128, slash_rate: f64, gain_exploit_wei: u128, p_verified: f64) bool {
    const expected_loss = @as(f64, @floatFromInt(stake_wei)) * p_verified * slash_rate;
    const expected_loss_wei = @as(u128, @intFromFloat(expected_loss));

    return expected_loss_wei > gain_exploit_wei;
}

/// Enhanced slash with deterrence check
pub fn slashWithDeterrence(self: *TokenStakingEngine, node_id: [32]u8, level: SlashLevel, estimated_gain_wei: u128, reason: []const u8) !u128 {
    const entry = self.stakes.get(node_id) orelse return error.NotStaked;
    const remaining = entry.staked_wei - entry.slashed_wei;

    // Check if slashing is actually a deterrent
    if (!calculateDeterrence(remaining, level.rate(), estimated_gain_wei)) {
        // Log but don't apply - slash would be ineffective
        std.log.warn("Slash {s} would not deter exploit (stake={d}, gain={d})", .{ reason, remaining, estimated_gain_wei });
        return 0;
    }

    // Apply normal slash
    return self.slash(node_id, level, reason);
}

/// v3.1: Enhanced slash with DYNAMIC deterrence check
/// Uses coverage-based verification probability
pub fn slashWithDynamicDeterrence(self: *TokenStakingEngine, node_id: [32]u8, level: SlashLevel, estimated_gain_wei: u128, reason: []const u8, coverage: MonitoringCoverage) !u128 {
    const entry = self.stakes.get(node_id) orelse return error.NotStaked;
    const remaining = entry.staked_wei - entry.slashed_wei;

    // v3.1: Calculate dynamic verification probability
    const p_verified = try calculateDynamicPVerified(self, node_id, level, coverage);

    // Check if slashing is actually a deterrent with dynamic P
    const expected_loss = @as(f64, @floatFromInt(remaining)) * p_verified * level.rate();
    const expected_loss_wei = @as(u128, @intFromFloat(expected_loss));

    if (expected_loss_wei <= estimated_gain_wei) {
        // v3.1: Log with detailed information
        std.log.warn("Slash {s} INSUFFICIENT DETERRENT: stake={d}, gain={d}, p={d:.2}, rate={d:.3}", .{ reason, remaining, estimated_gain_wei, p_verified, level.rate() });
        return error.InsufficientDeterrence;
    }

    // Apply normal slash
    return self.slash(node_id, level, reason);
}

// =============================================================================
// v3.0: USD-PEGGED STAKING
// =============================================================================

/// Get USD value of TRI (placeholder - oracle integration required)
pub fn getTriUsdPrice(allocator: std.mem.Allocator) !f64 {
    _ = allocator;
    // TODO: Integrate with oracle or use TWAP
    // For now, return placeholder
    return 1.0; // 1 TRI = $1
}

/// USD-pegged staking result
pub const UsdStakeResult = struct {
    node_id: [32]u8,
    success: bool,
    staked_usd: u128, // Amount in USD (18 decimals)
    staked_wei: u128, // Amount in TRI wei
    reason: StakeResultReason,
};

/// Stake with USD-pegged amount
pub fn stakeUsdPegged(self: *TokenStakingEngine, node_id: [32]u8, stake_usd: u128, allocator: std.mem.Allocator) !UsdStakeResult {
    self.mutex.lock();
    defer self.mutex.unlock();

    const tri_price = try getTriUsdPrice(allocator);
    const required_wei: u128 = @as(u128, @intFromFloat(@as(f64, @floatFromInt(stake_usd)) / tri_price));

    // Check if user has sufficient balance (placeholder - would check wallet)
    const entry = self.stakes.get(node_id) orelse {
        return .{
            .node_id = node_id,
            .success = false,
            .staked_usd = 0,
            .staked_wei = 0,
            .reason = .not_staked,
        };
    };

    const remaining = entry.staked_wei - entry.slashed_wei;
    if (remaining < required_wei) {
        return .{
            .node_id = node_id,
            .success = false,
            .staked_usd = 0,
            .staked_wei = 0,
            .reason = .insufficient_amount,
        };
    }

    return .{
        .node_id = node_id,
        .success = true,
        .staked_usd = stake_usd,
        .staked_wei = required_wei,
        .reason = .ok,
    };
}

// =============================================================================
// TOKEN STAKING ENGINE
// =============================================================================

pub const TokenStakingEngine = struct {
    allocator: std.mem.Allocator,
    config: StakingConfig,
    stakes: std.AutoHashMap([32]u8, StakeEntry),
    /// v2.0: Pending unbond requests
    unbond_requests: std.AutoHashMap(u32, UnbondRequest),
    /// v2.0: Next unbond request ID
    next_unbond_id: u32,
    total_staked_wei: u128,
    total_slashed_wei: u128,
    total_burned_wei: u128,
    total_stakes: u64,
    total_unstakes: u64,
    total_slash_events: u64,
    /// v2.0: Global slash event history
    slash_history: std.ArrayListUnmanaged(SlashEvent),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) TokenStakingEngine {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: StakingConfig) TokenStakingEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .stakes = std.AutoHashMap([32]u8, StakeEntry).init(allocator),
            .unbond_requests = std.AutoHashMap(u32, UnbondRequest).init(allocator),
            .next_unbond_id = 0,
            .total_staked_wei = 0,
            .total_slashed_wei = 0,
            .total_burned_wei = 0,
            .total_stakes = 0,
            .total_unstakes = 0,
            .total_slash_events = 0,
            .slash_history = .{},
            .mutex = .{},
        };
    }

    pub fn deinit(self: *TokenStakingEngine) void {
        // Clean up slash history in each stake entry
        var stake_iter = self.stakes.valueIterator();
        while (stake_iter.next()) |entry| {
            // Free reason strings in slash history
            for (entry.slash_history.items) |event| {
                self.allocator.free(event.reason);
            }
            entry.slash_history.deinit(self.allocator);
        }
        self.stakes.deinit();
        self.unbond_requests.deinit();

        // Free reason strings in global slash history
        for (self.slash_history.items) |event| {
            self.allocator.free(event.reason);
        }
        self.slash_history.deinit(self.allocator);
    }

    /// Stake tokens for a node
    pub fn stake(self: *TokenStakingEngine, node_id: [32]u8, amount_wei: u128) StakeResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        // v3.0: Check against sacred supply caps
        if (amount_wei > MAX_STAKE_PER_OPERATOR) {
            return .{
                .node_id = node_id,
                .success = false,
                .staked_wei = 0,
                .reason = .insufficient_amount, // Actually exceeds max
            };
        }

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

        const now = std.time.timestamp();
        self.stakes.put(node_id, .{
            .staked_wei = amount_wei,
            .slashed_wei = 0,
            .stake_time = now,
            .slash_count = 0,
            .last_slash_time = 0,
            .is_active = true,
            .slash_history = .{},
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

    // =========================================================================
    // v2.0: UNBONDING PERIOD (7-day security delay)
    // =========================================================================

    /// Request unbonding (initiates 7-day waiting period)
    pub fn requestUnbond(self: *TokenStakingEngine, node_id: [32]u8, amount_wei: u128) !u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.get(node_id) orelse return error.NotStaked;
        const remaining = entry.staked_wei - entry.slashed_wei;

        if (amount_wei > remaining) return error.InsufficientStake;
        if (amount_wei == 0) return error.InvalidAmount;

        const now = std.time.timestamp();
        const request_id = self.next_unbond_id;

        try self.unbond_requests.put(request_id, .{
            .node_id = node_id,
            .amount_wei = amount_wei,
            .request_time = now,
            .unlock_time = now + UNBONDING_PERIOD_SECS,
            .is_withdrawn = false,
        });

        self.next_unbond_id += 1;
        return request_id;
    }

    /// Request full unbonding (entire remaining stake)
    pub fn requestUnbondAll(self: *TokenStakingEngine, node_id: [32]u8) !u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.get(node_id) orelse return error.NotStaked;
        const remaining = entry.staked_wei - entry.slashed_wei;

        if (remaining == 0) return error.NoStakeToUnbond;

        self.mutex.unlock();
        const result = try self.requestUnbond(node_id, remaining);
        self.mutex.lock();

        return result;
    }

    /// Check if an unbond request is ready for withdrawal
    pub fn isUnbondReady(self: *TokenStakingEngine, request_id: u32) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const req = self.unbond_requests.get(request_id) orelse return false;
        if (req.is_withdrawn) return false;

        const now = std.time.timestamp();
        return now >= req.unlock_time;
    }

    /// Get time remaining until unbond is ready (seconds)
    pub fn unbondTimeRemaining(self: *TokenStakingEngine, request_id: u32) i64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const req = self.unbond_requests.get(request_id) orelse return -1;
        if (req.is_withdrawn) return -1;

        const now = std.time.timestamp();
        const remaining = req.unlock_time - now;
        return if (remaining < 0) 0 else remaining;
    }

    /// Withdraw unbonded tokens (after 7-day period)
    pub fn withdrawUnbonded(self: *TokenStakingEngine, request_id: u32) !u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const req = self.unbond_requests.getPtr(request_id) orelse return error.RequestNotFound;
        if (req.is_withdrawn) return error.AlreadyWithdrawn;

        const now = std.time.timestamp();
        if (now < req.unlock_time) {
            return error.UnbondPeriodNotElapsed;
        }

        const entry = self.stakes.getPtr(req.node_id) orelse return error.StakeEntryNotFound;
        const remaining = entry.staked_wei - entry.slashed_wei;

        req.is_withdrawn = true;

        if (req.amount_wei >= remaining) {
            for (entry.slash_history.items) |event| {
                self.allocator.free(event.reason);
            }
            entry.slash_history.deinit(self.allocator);
            _ = self.stakes.remove(req.node_id);
            self.total_staked_wei -= entry.staked_wei;
        } else {
            entry.staked_wei -= req.amount_wei;
        }

        self.total_unstakes += 1;
        _ = self.unbond_requests.remove(request_id);

        return req.amount_wei;
    }

    /// Cancel an unbond request (before unlock time)
    pub fn cancelUnbond(self: *TokenStakingEngine, request_id: u32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const req = self.unbond_requests.get(request_id) orelse return error.RequestNotFound;
        if (req.is_withdrawn) return error.AlreadyWithdrawn;

        const now = std.time.timestamp();
        if (now >= req.unlock_time) {
            return error.UnbondPeriodElapsed;
        }

        _ = self.unbond_requests.remove(request_id);
    }

    /// Get all pending unbond requests for a node
    pub fn getPendingUnbonds(self: *TokenStakingEngine, node_id: [32]u8, allocator: std.mem.Allocator) ![]UnbondRequest {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged(UnbondRequest){};
        errdefer result.deinit(allocator);

        var iter = self.unbond_requests.valueIterator();
        while (iter.next()) |req| {
            if (std.mem.eql(u8, &req.node_id, &node_id) and !req.is_withdrawn) {
                try result.append(allocator, req.*);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    // =========================================================================
    // v2.0: TIERED SLASHING SYSTEM
    // =========================================================================

    /// Slash a node's stake using tiered system
    pub fn slash(self: *TokenStakingEngine, node_id: [32]u8, level: SlashLevel, reason: []const u8) !u128 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.getPtr(node_id) orelse return error.NotStaked;
        const remaining = entry.staked_wei - entry.slashed_wei;

        if (remaining == 0) {
            try self.slashPendingUnbondsLocked(node_id, level);
            return 0;
        }

        const slash_rate = level.rate();
        const slash_f: f64 = @as(f64, @floatFromInt(remaining)) * slash_rate;
        const slash_amount: u128 = @as(u128, @intFromFloat(slash_f));

        entry.slashed_wei += slash_amount;
        entry.slash_count += 1;
        entry.last_slash_time = std.time.timestamp();

        if (entry.slash_history.items.len < self.config.max_slash_history) {
            const now = std.time.timestamp();
            try entry.slash_history.append(self.allocator, .{
                .node_id = node_id,
                .level = level,
                .amount_slashed_wei = slash_amount,
                .reason = try self.allocator.dupe(u8, reason),
                .timestamp = now,
            });
        }

        try self.slashPendingUnbondsLocked(node_id, level);

        const now = std.time.timestamp();
        try self.slash_history.append(self.allocator, .{
            .node_id = node_id,
            .level = level,
            .amount_slashed_wei = slash_amount,
            .reason = try self.allocator.dupe(u8, reason),
            .timestamp = now,
        });

        self.total_slashed_wei += slash_amount;
        self.total_burned_wei += slash_amount;
        self.total_slash_events += 1;

        if (entry.slashed_wei >= entry.staked_wei) {
            entry.is_active = false;
        }

        return slash_amount;
    }

    fn slashPendingUnbondsLocked(self: *TokenStakingEngine, node_id: [32]u8, level: SlashLevel) !void {
        const slash_rate = level.rate();

        var iter = self.unbond_requests.valueIterator();
        while (iter.next()) |req| {
            if (std.mem.eql(u8, &req.node_id, &node_id) and !req.is_withdrawn) {
                const unbond_slash_rate: f64 = switch (level) {
                    .minor => slash_rate * 0.5,
                    .moderate => slash_rate * 0.5,
                    .major => slash_rate * 1.0,
                    .severe => slash_rate * 1.0,
                };

                const slash_f: f64 = @as(f64, @floatFromInt(req.amount_wei)) * unbond_slash_rate;
                const slash_amount: u128 = @as(u128, @intFromFloat(slash_f));

                if (slash_amount > 0) {
                    req.amount_wei -= slash_amount;
                    self.total_slashed_wei += slash_amount;
                    self.total_burned_wei += slash_amount;
                }
            }
        }
    }

    pub fn slashForPosFailure(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        return self.slash(node_id, .moderate, "PoS failure") catch |err| {
            std.log.err("slashForPosFailure failed: {}", .{err});
            return 0;
        };
    }

    pub fn slashForCorruption(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        return self.slash(node_id, .major, "Corruption detected") catch |err| {
            std.log.err("slashForCorruption failed: {}", .{err});
            return 0;
        };
    }

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
        const staked_wei = entry.staked_wei;

        if (self.stakes.getPtr(node_id)) |mutable_entry| {
            for (mutable_entry.slash_history.items) |event| {
                self.allocator.free(event.reason);
            }
            mutable_entry.slash_history.deinit(self.allocator);
        }

        _ = self.stakes.remove(node_id);
        self.total_staked_wei -= staked_wei;
        self.total_unstakes += 1;

        return .{
            .node_id = node_id,
            .success = true,
            .staked_wei = remaining,
            .reason = .ok,
        };
    }

    pub fn isStaked(self: *TokenStakingEngine, node_id: [32]u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry = self.stakes.get(node_id) orelse return false;
        return entry.is_active;
    }

    pub fn getStake(self: *TokenStakingEngine, node_id: [32]u8) ?StakeEntry {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stakes.get(node_id);
    }

    pub fn getRemainingStake(self: *TokenStakingEngine, node_id: [32]u8) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry = self.stakes.get(node_id) orelse return 0;
        return entry.staked_wei - entry.slashed_wei;
    }

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

    pub fn getStats(self: *TokenStakingEngine) StakingStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active: u32 = 0;
        var stake_iter = self.stakes.valueIterator();
        while (stake_iter.next()) |entry| {
            if (entry.is_active) active += 1;
        }

        var pending_unbond_wei: u128 = 0;
        var active_unbonds: u32 = 0;
        var unbond_iter = self.unbond_requests.valueIterator();
        while (unbond_iter.next()) |req| {
            if (!req.is_withdrawn) {
                pending_unbond_wei += req.amount_wei;
                active_unbonds += 1;
            }
        }

        // v3.0: Calculate percentage of sacred supply staked
        const sacred_staked_bp = if (SACRED_SUPPLY > 0)
            @as(u64, @intFromFloat((@as(f64, @floatFromInt(self.total_staked_wei)) * 10000) / @as(f64, @floatFromInt(SACRED_SUPPLY))))
        else
            0;

        return .{
            .total_staked_wei = self.total_staked_wei,
            .total_slashed_wei = self.total_slashed_wei,
            .total_burned_wei = self.total_burned_wei,
            .active_stakers = active,
            .total_stakes = self.total_stakes,
            .total_unstakes = self.total_unstakes,
            .total_slash_events = self.total_slash_events,
            .pending_unbond_wei = pending_unbond_wei,
            .active_unbonds = active_unbonds,
            .sacred_supply_staked_bp = @intCast(sacred_staked_bp),
        };
    }

    pub fn getSlashHistory(self: *TokenStakingEngine, node_id: [32]u8, allocator: std.mem.Allocator) ![]SlashEvent {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.stakes.get(node_id) orelse return error.NotStaked;

        var result = std.ArrayListUnmanaged(SlashEvent){};
        errdefer result.deinit(allocator);

        for (entry.slash_history.items) |event| {
            try result.append(allocator, event);
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn getGlobalSlashHistory(self: *TokenStakingEngine, allocator: std.mem.Allocator) ![]SlashEvent {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = try std.ArrayListUnmanaged(SlashEvent).allocCapacity(allocator, self.slash_history.items.len);
        errdefer result.deinit(allocator);

        for (self.slash_history.items) |event| {
            try result.append(allocator, event);
        }

        return result.toOwnedSlice(allocator);
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "sacred supply constant" {
    // 3^21 = 10,460,353,203
    const expected: u256 = 10_460_353_203 * 1_000_000_000_000_000_000;
    try std.testing.expectEqual(expected, SACRED_SUPPLY);
}

test "max stake per operator" {
    // 1% of sacred supply
    const expected: u256 = SACRED_SUPPLY / 100;
    try std.testing.expectEqual(expected, MAX_STAKE_PER_OPERATOR);
}

test "v3.0: deterrence equation - sufficient stake" {
    // 1000 TRI stake, 1% slash, 50 TRI gain exploit
    // E[L] = 0.95 * 0.01 * 1000 = 9.5 TRI > 5 TRI gain
    const stake: u128 = 1000;
    const gain: u128 = 5;
    const result = calculateDeterrence(stake * 1_000_000_000_000_000_000, SlashLevel.moderate.rate(), gain * 1_000_000_000_000_000_000);
    try std.testing.expect(result); // Should deter
}

test "v3.0: deterrence equation - insufficient stake" {
    // 100 TRI stake, 1% slash, 50 TRI gain exploit
    // E[L] = 0.95 * 0.01 * 100 = 0.95 TRI < 50 TRI gain
    const stake: u128 = 100;
    const gain: u128 = 50;
    const result = calculateDeterrence(stake * 1_000_000_000_000_000_000, SlashLevel.moderate.rate(), gain * 1_000_000_000_000_000_000);
    try std.testing.expect(!result); // Should NOT deter
}

test "stake and unstake" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .min_reputation_for_staking = 0.2,
        .max_slash_history = 32,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    const result = engine.stake(node, 1000);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u128, 1000), result.staked_wei);
    try std.testing.expect(engine.isStaked(node));

    const unstake_result = engine.unstake(node);
    try std.testing.expect(unstake_result.success);
    try std.testing.expectEqual(@as(u128, 1000), unstake_result.staked_wei);
    try std.testing.expect(!engine.isStaked(node));
}

test "v3.0: stake exceeds max per operator" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .min_reputation_for_staking = 0.2,
        .max_slash_history = 32,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;

    // Try to stake more than MAX_STAKE_PER_OPERATOR (1% of sacred supply)
    const result = engine.stake(node, MAX_STAKE_PER_OPERATOR + 1);
    try std.testing.expect(!result.success);
    try std.testing.expect(result.reason == .insufficient_amount);
}

test "stats include sacred supply percentage" {
    const allocator = std.testing.allocator;

    var engine = TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .min_reputation_for_staking = 0.2,
        .max_slash_history = 32,
    });
    defer engine.deinit();

    const node = [_]u8{0x01} ** 32;
    _ = engine.stake(node, 1_000_000_000); // 1 TRI staked

    const stats = engine.getStats();
    // Should be very small percentage of sacred supply
    try std.testing.expect(stats.sacred_supply_staked_bp < 1); // < 0.01%
}
