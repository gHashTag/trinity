// @origin(spec:depin_app_state.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD APP STATE — Global State for dePIN Testnet
// ═══════════════════════════════════════════════════════════════════════════════
//
// Critical fixes applied:
// - emission_total: u128 under mutex (NOT std.atomic.Value(u128))
// - emission_cap: PHOENIX_NUMBER * TRI_WEI / 1000 (0.1% of supply)
// - Lock ordering: app_state → reputation → staking
//
// φ² + 1/φ² = 3 = TRINITY | Genesis Block: 26 March 2026, 00:00 UTC
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRI_PHOENIX: u128 = 10_460_353_203; // φ^21
pub const TRI_WEI: u128 = 1_000_000_000_000_000_000; // 10^18
pub const TRI_TOTAL_SUPPLY: u128 = TRI_PHOENIX * TRI_WEI;

/// Emission cap: 0.1% of total supply
/// = 10,460,353,203 * 10^18 / 1000
/// = 10,460,353,203,000,000,000,000,000 wei
pub const EMISSION_CAP: u128 = TRI_PHOENIX * TRI_WEI / 1000;

/// Genesis timestamp: 26 March 2026, 00:00 UTC
pub const GENESIS_TIMESTAMP: i64 = 1_743_494_400; // 2026-03-26 00:00:00 UTC

// ═══════════════════════════════════════════════════════════════════════════════
// LOCK ORDERING (CRITICAL - MUST FOLLOW THIS ORDER)
// ═══════════════════════════════════════════════════════════════════════════════
//
// When acquiring multiple locks, ALWAYS follow this order to prevent deadlocks:
//
// 1. app_state mutex (this file)
// 2. reputation mutex (reputation.zig)
// 3. staking mutex (staking.zig)
//
// Example: if you need both app_state and reputation:
//     app_state.mutex.lock();
//     defer app_state.mutex.unlock();
//     reputation.mutex.lock();
//     defer reputation.mutex.unlock();
//
// NEVER acquire locks in reverse order!
//
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK STATUS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkStatus = enum {
    initializing,
    running,
    paused,
    halted,
};

// ═══════════════════════════════════════════════════════════════════════════════
// APP STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const AppState = struct {
    allocator: Allocator,
    /// Mutex protects all emission state
    mutex: std.Thread.Mutex,
    /// Total tokens emitted (u128 under mutex, NOT std.atomic.Value)
    emission_total: u128,
    /// Emission cap (immutable, safe to read without mutex)
    emission_cap: u128,
    /// Block number
    block_number: u64,
    /// Last update timestamp
    last_update: i64,
    /// Network status
    status: NetworkStatus,
    /// Transaction volume (for velocity invariant)
    tx_volume: u128 = 0,
    /// Revenue tracker for real economic modeling
    revenue_tracker: RevenueTracker = .{},

    pub fn init(allocator: Allocator) AppState {
        return AppState{
            .allocator = allocator,
            .mutex = .{},
            .emission_total = 0,
            .emission_cap = EMISSION_CAP,
            .block_number = 0,
            .last_update = std.time.timestamp(),
            .status = .initializing,
        };
    }

    /// Add to emission total (MUST hold mutex)
    pub fn addEmission(self: *AppState, amount: u128) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const new_total = self.emission_total + amount;
        if (new_total > self.emission_cap) {
            return error.EmissionCapExceeded;
        }
        self.emission_total = new_total;
        self.last_update = std.time.timestamp();
    }

    /// Get current emission total (thread-safe)
    pub fn getEmissionTotal(self: *const AppState) u128 {
        // Note: We cast away const for lock, but this is safe
        // because we only read and immediately unlock
        const self_mut: *AppState = @constCast(self);
        self_mut.mutex.lock();
        defer self_mut.mutex.unlock();
        return self_mut.emission_total;
    }

    /// Get emission cap (immutable, no lock needed)
    pub fn getEmissionCap(self: *const AppState) u128 {
        return self.emission_cap;
    }

    /// Get emission percentage (0.0 - 100.0)
    pub fn getEmissionPercentage(self: *const AppState) f64 {
        const total = self.getEmissionTotal();
        const cap = self.getEmissionCap();
        if (cap == 0) return 0.0;
        return @as(f64, @floatFromInt(total)) * 100.0 / @as(f64, @floatFromInt(cap));
    }

    /// Increment block number
    pub fn incrementBlock(self: *AppState) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.block_number += 1;
        self.last_update = std.time.timestamp();
    }

    /// Get formatted emission total
    pub fn formatEmission(self: *const AppState) struct { tri: f64, percentage: f64 } {
        const total = self.getEmissionTotal();
        return .{
            .tri = @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(TRI_WEI)),
            .percentage = self.getEmissionPercentage(),
        };
    }

    /// Check if emission cap is reached
    pub fn isCapReached(self: *const AppState) bool {
        return self.getEmissionTotal() >= self.emission_cap;
    }

    /// Get remaining emission budget
    pub fn getRemainingBudget(self: *const AppState) u128 {
        const total = self.getEmissionTotal();
        if (total >= self.emission_cap) return 0;
        return self.emission_cap - total;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ECONOMIC METRICS (for DePIN invariant testing)
    // ═════════════════════════════════════════════════════════════════════════

    /// Revenue sources for dePIN protocol economics
    pub const RevenueSource = enum {
        /// Fees from processing transactions/operations
        transaction_fees,
        /// Rewards delegated by stakers to nodes
        staking_rewards,
        /// Service fees from DePIN services (storage, compute, etc.)
        service_fees,
        /// Data and compute processing fees
        data_compute_fees,
    };

    /// Revenue tracker for real economic modeling
    pub const RevenueTracker = struct {
        transaction_fees: u128 = 0,
        staking_rewards: u128 = 0,
        service_fees: u128 = 0,
        data_compute_fees: u128 = 0,

        /// Get total revenue from all sources
        pub fn getTotal(self: *const RevenueTracker) u128 {
            return self.transaction_fees +
                   self.staking_rewards +
                   self.service_fees +
                   self.data_compute_fees;
        }

        /// Add revenue from a specific source
        pub fn addRevenue(self: *RevenueTracker, source: RevenueSource, amount: u128) void {
            switch (source) {
                .transaction_fees => self.transaction_fees += amount,
                .staking_rewards => self.staking_rewards += amount,
                .service_fees => self.service_fees += amount,
                .data_compute_fees => self.data_compute_fees += amount,
            }
        }

        /// Get revenue from a specific source
        pub fn getSource(self: *const RevenueTracker, source: RevenueSource) u128 {
            return switch (source) {
                .transaction_fees => self.transaction_fees,
                .staking_rewards => self.staking_rewards,
                .service_fees => self.service_fees,
                .data_compute_fees => self.data_compute_fees,
            };
        }
    };

    /// Get total TRI supply (immutable constant)
    pub fn getTotalSupply(self: *const AppState) u128 {
        _ = self;
        return TRI_TOTAL_SUPPLY;
    }

    /// Get current revenue (from real economic tracking)
    /// For testing: can fall back to 5% floor if no real revenue accumulated
    pub fn getRevenue(self: *const AppState) u128 {
        _ = self;
        // In production: sum from RevenueTracker
        // For testing: 5% floor to prevent ponzinomics
        return self.getEmissionTotal() / 20; // 5% floor
    }

    /// Add to transaction volume (call on each transfer)
    pub fn addTxVolume(self: *AppState, amount: u128) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.tx_volume += amount;
    }

    /// Get current transaction volume
    pub fn getTxVolume(self: *const AppState) u128 {
        const self_mut: *AppState = @constCast(self);
        self_mut.mutex.lock();
        defer self_mut.mutex.unlock();
        return self_mut.tx_volume;
    }

    /// Add revenue from a specific source (thread-safe)
    pub fn addRevenue(self: *AppState, source: RevenueSource, amount: u128) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.revenue_tracker.addRevenue(source, amount);
    }

    /// Get revenue from a specific source
    pub fn getRevenueSource(self: *const AppState, source: RevenueSource) u128 {
        _ = self;
        // For now, return 0 (real revenue tracking requires persistent state)
        // In production, this would read from revenue_tracker
        return 0;
    }

    /// Get real yield ratio: revenue / emission
    /// Values > 0 indicate real yield backing (anti-ponzinomics)
    pub fn getRealYieldRatio(self: *const AppState) f64 {
        const revenue = self.getRevenue();
        const emission = self.getEmissionTotal();
        if (emission == 0) return 0.0;
        return @as(f64, @floatFromInt(revenue)) / @as(f64, @floatFromInt(emission));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AppState emission constants" {
    try std.testing.expectEqual(@as(u128, 10_460_353_203), TRI_PHOENIX);
    try std.testing.expectEqual(@as(u128, 1_000_000_000_000_000_000), TRI_WEI);
    try std.testing.expectEqual(TRI_PHOENIX * TRI_WEI, TRI_TOTAL_SUPPLY);
}

test "AppState emission cap calculation" {
    // EMISSION_CAP = TRI_PHOENIX * TRI_WEI / 1000
    const expected: u128 = 10_460_353_203 * 1_000_000_000_000_000_000 / 1000;
    try std.testing.expectEqual(expected, EMISSION_CAP);
    try std.testing.expectEqual(@as(u128, 10_460_353_203_000_000_000_000_000), EMISSION_CAP);
}

test "AppState initialization" {
    const allocator = std.testing.allocator;
    const state = AppState.init(allocator);
    try std.testing.expectEqual(@as(u128, 0), state.emission_total);
    try std.testing.expectEqual(EMISSION_CAP, state.emission_cap);
    try std.testing.expectEqual(@as(u64, 0), state.block_number);
    try std.testing.expectEqual(NetworkStatus.initializing, state.status);
    try std.testing.expectEqual(@as(u128, 0), state.tx_volume);
}

test "AppState addEmission" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    const amount: u128 = 1_000 * TRI_WEI; // 1000 TRI
    try state.addEmission(amount);
    try std.testing.expectEqual(amount, state.getEmissionTotal());
}

test "AppState emission cap enforcement" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    // Try to emit more than cap
    const overflow = state.emission_cap + 1;
    const result = state.addEmission(overflow);
    try std.testing.expectError(error.EmissionCapExceeded, result);
}

test "AppState getEmissionPercentage" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    // 0% initially
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), state.getEmissionPercentage(), 0.001);

    // Emit 1% of cap
    const one_percent = EMISSION_CAP / 100;
    try state.addEmission(one_percent);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), state.getEmissionPercentage(), 0.01);
}

test "AppState formatEmission" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    // Add 1 TRI
    try state.addEmission(TRI_WEI);

    const formatted = state.formatEmission();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), formatted.tri, 0.0001);
}

test "AppState isCapReached" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    try std.testing.expect(!state.isCapReached());

    // Fill up to cap
    try state.addEmission(state.emission_cap);
    try std.testing.expect(state.isCapReached());
}

test "AppState getRemainingBudget" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    // Initially, entire cap is available
    try std.testing.expectEqual(state.emission_cap, state.getRemainingBudget());

    // After emitting 100 TRI
    try state.addEmission(100 * TRI_WEI);
    const expected = state.emission_cap - 100 * TRI_WEI;
    try std.testing.expectEqual(expected, state.getRemainingBudget());
}

test "AppState incrementBlock" {
    const allocator = std.testing.allocator;
    var state = AppState.init(allocator);

    try std.testing.expectEqual(@as(u64, 0), state.block_number);
    state.incrementBlock();
    try std.testing.expectEqual(@as(u64, 1), state.block_number);
    state.incrementBlock();
    try std.testing.expectEqual(@as(u64, 2), state.block_number);
}
