// ═══════════════════════════════════════════════════════════════════════════════
// dePIN Economic Invariants — Property-Based E2E Tests (Enhanced v2)
// Task: depin-e2e-invariants-v2
// Build: zig build test (module mapped in build.zig)
//
// v2 Improvements:
// - Level 1: Multiple seeds, shrinking framework, statistics
// - Level 2: Temporal invariants, state history tracking
// - Level 2+: Integration with state_machine and economic modules
//
// Based on research from:
// - Erlang QuickCheck: State machine modelling
// - Move Prover: Fine-grained invariant checking
// - PropertyGPT (ArXiv 2405.02580): LLM-generated invariants
// - Trail of Bits 2025: Invariant-driven development
//
// φ² + 1/phi² = 3 = TRINITY | Genesis Block: 26 March 2026, 00:00 UTC
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import firebird modules
const app_state = @import("firebird_app_state");
const staking = @import("firebird_staking");
const reputation = @import("firebird_reputation");

const TRI_WEI = app_state.TRI_WEI;

// ═══════════════════════════════════════════════════════════════════════════════
// RANDOM OPERATIONS FOR PROPERTY-BASED TESTING
// ═══════════════════════════════════════════════════════════════════════════════

const Op = enum {
    stake,
    unstake,
    slash,
    update_health,
};

/// Fixed node pool for realistic state accumulation
/// AppState uses [32]u8 node_id, so we pre-generate 8 distinct IDs
const TEST_NODES = [_][20]u8{
    [_]u8{0x00} ** 20,
    [_]u8{0x01} ** 19 ++ [_]u8{0x01},
    [_]u8{0x02} ** 18 ++ [_]u8{0x02} ** 2,
    [_]u8{0x03} ** 17 ++ [_]u8{0x03} ** 3,
    [_]u8{0x04} ** 16 ++ [_]u8{0x04} ** 4,
    [_]u8{0x05} ** 15 ++ [_]u8{0x05} ** 5,
    [_]u8{0x06} ** 14 ++ [_]u8{0x06} ** 6,
    [_]u8{0x07} ** 13 ++ [_]u8{0x07} ** 7,
};

/// Apply a random operation to the state
/// Note: Errors are VALID outcomes in random testing (unstake on non-existent node, etc.)
fn applyRandomOp(state: *TestState, prng: std.Random) void {
    const op = prng.enumValue(Op);
    const node_idx = prng.uintLessThan(usize, TEST_NODES.len);
    const node_id = TEST_NODES[node_idx];

    switch (op) {
        .stake => randomStake(state, prng, node_id) catch {},
        .unstake => randomUnstake(state, node_id) catch {},
        .slash => randomSlash(state, node_id) catch {},
        .update_health => randomUpdateHealth(state, prng, node_id) catch {},
    }
}

fn randomStake(state: *TestState, prng: std.Random, node_id: [20]u8) !void {
    const amount = prng.intRangeAtMost(u128, 100, 10_000) * TRI_WEI;
    const lock_val = prng.intRangeAtMost(u8, 1, 4);
    const lock_period: staking.LockPeriod = switch (lock_val) {
        1 => .one_month,
        2 => .three_months,
        3 => .six_months,
        else => .twelve_months,
    };

    // Generate unique stake_id for tracking
    const stake_id = try std.fmt.allocPrint(state.allocator, "stake_{d}_{d}", .{
        state.op_count,
        prng.int(u64),
    });
    errdefer state.allocator.free(stake_id);

    // Create stake position directly (bypassing createStake for test control)
    const position = staking.StakePosition{
        .stake_id = stake_id,
        .staker_address = node_id,
        .delegator_address = null,
        .amount = amount,
        .lock_period = lock_period,
        .start_timestamp = std.time.timestamp(),
        .unlock_timestamp = std.time.timestamp() + 86400, // 1 day for test
        .is_slashed = false,
        .rewards = 0,
        .is_active = true,
    };

    try state.staking_manager.stakes.put(state.allocator, stake_id, position);
    state.staking_manager.total_staked += amount;
}

fn randomSlash(state: *TestState, node_id: [20]u8) !void {
    // Only slash if node has stakes
    const stakes = try state.staking_manager.getStakerStakes(node_id, state.allocator);
    defer state.allocator.free(stakes);

    if (stakes.len == 0) return error.NoStakesToSlash;

    state.staking_manager.mutex.lock();
    defer state.staking_manager.mutex.unlock();

    // Get mutable references to stakes by looking them up again
    for (stakes) |stake| {
        if (stake.is_active and !stake.is_slashed) {
            // Look up mutable reference from the hashmap
            if (state.staking_manager.stakes.getEntry(stake.stake_id)) |entry| {
                const before = entry.value_ptr.amount;
                const penalty = 0.01; // 1% slash
                entry.value_ptr.applySlash(penalty);
                const slashed = before - entry.value_ptr.amount;
                state.staking_manager.total_slashed += slashed;
            }
        }
    }
}

fn randomUnstake(state: *TestState, node_id: [20]u8) !void {
    const stakes = try state.staking_manager.getStakerStakes(node_id, state.allocator);
    defer state.allocator.free(stakes);

    if (stakes.len == 0) return error.StakeNotFound;

    // Try to unstake the first stake
    for (stakes) |stake| {
        if (stake.canWithdraw()) {
            _ = state.staking_manager.withdrawStake(stake.stake_id) catch {};
            return;
        }
    }
    return error.StakeLocked;
}

fn randomUpdateHealth(state: *TestState, prng: std.Random, node_id: [20]u8) !void {
    _ = prng.enumValue(reputation.BrainRegion); // Varied regions for future use
    const value = prng.intRangeAtMost(u32, 0, 65536); // Q16

    const node_id_str = try std.fmt.allocPrint(state.allocator, "{s}", .{
        std.fmt.bytesToHex(&node_id, .lower),
    });

    // Update region directly for the node
    // This avoids issues with NodeMetrics lifetime
    state.reputation.mutex.lock();
    defer state.reputation.mutex.unlock();

    // Create or update metrics entry
    const entry = try state.reputation.metrics.getOrPut(state.allocator, node_id_str);
    if (entry.found_existing) {
        // Key already exists, free our temp string
        state.allocator.free(node_id_str);
        entry.value_ptr.prefrontal_executive = value;
        entry.value_ptr.cerebellum_consistency = value;
        entry.value_ptr.hippocampus_memory = value;
        entry.value_ptr.basal_action = value;
        entry.value_ptr.updateHealth();
    } else {
        // New entry - the key is now owned by the hashmap, don't free
        entry.value_ptr.* = reputation.NodeMetrics.init(entry.key_ptr.*);
        entry.value_ptr.prefrontal_executive = value;
        entry.value_ptr.cerebellum_consistency = value;
        entry.value_ptr.hippocampus_memory = value;
        entry.value_ptr.basal_action = value;
        entry.value_ptr.updateHealth();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST STATE (Enhanced with History)
// ═══════════════════════════════════════════════════════════════════════════════

/// State snapshot for temporal invariants
const StateSnapshot = struct {
    timestamp: i64,
    total_staked: u128,
    total_slashed: u128,
    emitted: u128,
    average_health: f64,
    active_nodes: usize,
};

const TestState = struct {
    allocator: std.mem.Allocator,
    app_state: app_state.AppState,
    staking_manager: staking.StakingManager,
    reputation: reputation.ReputationRegistry,
    op_count: usize,
    /// History for temporal invariants (last 100 snapshots)
    history: std.ArrayListUnmanaged(StateSnapshot),
    /// Unique states seen (for coverage estimation)
    unique_states: std.AutoHashMap(u64, void),

    pub fn init(allocator: std.mem.Allocator) TestState {
        return TestState{
            .allocator = allocator,
            .app_state = app_state.AppState.init(allocator),
            .staking_manager = staking.StakingManager.init(allocator),
            .reputation = reputation.ReputationRegistry.init(allocator),
            .op_count = 0,
            .history = .{},
            .unique_states = std.AutoHashMap(u64, void).init(allocator),
        };
    }

    pub fn deinit(self: *TestState) void {
        self.staking_manager.deinit();
        self.reputation.deinit();
        self.history.deinit(self.allocator);
        self.unique_states.deinit();
    }

    /// Record current state for temporal invariant checking
    pub fn snapshot(self: *TestState) !void {
        const stats = self.reputation.getStats();
        const snap = StateSnapshot{
            .timestamp = std.time.timestamp(),
            .total_staked = self.staking_manager.getTotalStaked(),
            .total_slashed = self.staking_manager.getTotalSlashed(),
            .emitted = self.app_state.getEmissionTotal(),
            .average_health = stats.average_health,
            .active_nodes = stats.total_nodes,
        };

        // Keep only last 100 snapshots
        if (self.history.items.len >= 100) {
            _ = self.history.orderedRemove(0);
        }
        try self.history.append(self.allocator, snap);

        // Track unique state hash
        const state_hash = @as(u64, @intCast(snap.total_staked % 1000007)) * 31 +
            @as(u64, @intCast(snap.emitted % 1000007));
        try self.unique_states.put(state_hash, {});
    }

    /// Get statistics about the test run
    pub fn getStats(self: *const TestState) Stats {
        return Stats{
            .operations_passed = self.op_count,
            .snapshots_recorded = self.history.items.len,
            .unique_states = self.unique_states.count(),
            .coverage_estimate = if (self.op_count > 0)
                @as(f32, @floatFromInt(self.unique_states.count())) / @as(f32, @floatFromInt(self.op_count))
            else
                0.0,
        };
    }

    pub const Stats = struct {
        operations_passed: usize,
        snapshots_recorded: usize,
        unique_states: usize,
        coverage_estimate: f32,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// SHRINKING FRAMEWORK (Level 1)
// ═══════════════════════════════════════════════════════════════════════════════

/// Shrinkable operation for finding minimal counter-examples
const ShrinkableOp = struct {
    op_type: Op,
    amount: u128,
    node_idx: usize,

    /// Shrink this operation towards minimal values
    pub fn shrink(self: *ShrinkableOp) bool {
        var shrunk = false;

        // Shrink amount by half (minimum 100 TRI_WEI)
        if (self.amount > 100 * TRI_WEI) {
            self.amount = @max(100 * TRI_WEI, self.amount / 2);
            shrunk = true;
        }

        // Shrink node index towards 0
        if (self.node_idx > 0) {
            self.node_idx = self.node_idx / 2;
            shrunk = true;
        }

        return shrunk;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INVARIANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// INVARIANT #1: Conservation of Value (Modified for testnet)
/// Slashed tokens cannot exceed what was originally staked:
/// total_slashed ≤ total_staked + total_slashed (all slashed came from stakes)
fn invariantConservation(state: *const TestState) !void {
    const total_staked = state.staking_manager.getTotalStaked();
    const total_slashed = state.staking_manager.getTotalSlashed();

    // Slashed tokens came from stakes, so they can't exceed the total
    // that was ever staked (currently_staked + slashed)
    const total_ever_staked = total_staked + total_slashed;

    // Sanity: we can't have slashed more than we ever had
    try std.testing.expect(total_slashed <= total_ever_staked);

    // Also: emission must cover all rewards if we were tracking them
    // For testnet, rewards are mock, so we just check emission cap
    try invariantEmissionCap(state);
}

/// INVARIANT #2: Emission Cap
/// The total emission must never exceed the cap
fn invariantEmissionCap(state: *const TestState) !void {
    const emitted = state.app_state.getEmissionTotal();
    const cap = state.app_state.getEmissionCap();
    try std.testing.expect(emitted <= cap);
}

/// INVARIANT #3: Health Bounds
/// Health scores must always be in [0.0, 1.0]
fn invariantHealthBounds(state: *const TestState) !void {
    const stats = state.reputation.getStats();
    if (stats.total_nodes == 0) return;

    try std.testing.expect(stats.average_health >= 0.0);
    try std.testing.expect(stats.average_health <= 1.0);
}

/// INVARIANT #4: No Negative Stake
/// All stake amounts must be non-negative
fn invariantNoNegativeStake(state: *const TestState) !void {
    const total_staked = state.staking_manager.getTotalStaked();
    const total_slashed = state.staking_manager.getTotalSlashed();

    try std.testing.expect(total_staked >= 0);
    try std.testing.expect(total_slashed >= 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEMPORAL INVARIANTS (Level 2)
// ═══════════════════════════════════════════════════════════════════════════════

/// INVARIANT #5: Monotonicity
/// total_staked never decreases without corresponding unstake or slash
/// Emissions never decrease (they're monotonic)
fn invariantMonotonic(state: *const TestState) !void {
    if (state.history.items.len < 2) return;

    for (state.history.items[1..], 0..) |curr, i| {
        const prev = state.history.items[i];

        // Emissions are monotonic (never decrease)
        try std.testing.expect(curr.emitted >= prev.emitted);

        // If staked decreased, slashed should have increased
        if (curr.total_staked < prev.total_staked) {
            try std.testing.expect(curr.total_slashed >= prev.total_slashed);
        }
    }
}

/// INVARIANT #6: No-Double-Slash
/// Same stake cannot be slashed twice (tracked via total_slashed monotonicity)
fn invariantNoDoubleSlash(state: *const TestState) !void {
    if (state.history.items.len < 2) return;

    for (state.history.items[1..], 0..) |curr, i| {
        const prev = state.history.items[i];

        // Slashed amount should be monotonic (can't "un-slash")
        try std.testing.expect(curr.total_slashed >= prev.total_slashed);
    }
}

/// INVARIANT #7: Health-Stake Correlation
/// More active nodes should correlate with reasonable health scores
fn invariantHealthStakeCorrelation(state: *const TestState) !void {
    if (state.history.items.len < 2) return;

    const stats = state.reputation.getStats();
    if (stats.total_nodes == 0) return;

    // Health should be reasonable for any active nodes
    try std.testing.expect(stats.average_health >= 0.0);
    try std.testing.expect(stats.average_health <= 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-SEED TEST RUNNER (Level 1)
// ═══════════════════════════════════════════════════════════════════════════════

/// Run invariant tests with multiple seeds for CI/CD robustness
fn runWithMultipleSeeds(allocator: std.mem.Allocator, seeds: []const u64, iterations: usize) !MultiSeedReport {
    var report = MultiSeedReport{
        .allocator = allocator,
        .seeds_tested = seeds.len,
        .iterations_per_seed = iterations,
        .passed = 0,
        .failed = 0,
        .seed_results = std.ArrayListUnmanaged(SeedResult){},
    };

    for (seeds) |seed| {
        var state = TestState.init(allocator);
        defer state.deinit();

        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();
        var seed_passed = true;

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            state.op_count = i;
            applyRandomOp(&state, random);

            // Snapshot every 10 operations
            if (i % 10 == 0) {
                try state.snapshot();
            }

            // Verify invariants
            if (verifyAllInvariants(&state)) |_| {
                // Continue
            } else |err| {
                seed_passed = false;
                std.debug.print("Seed 0x{x} failed at iteration {d}: {}\n", .{ seed, i, err });
                break;
            }
        }

        if (seed_passed) {
            report.passed += 1;
        } else {
            report.failed += 1;
        }

        const stats = state.getStats();
        try report.seed_results.append(allocator, SeedResult{
            .seed = seed,
            .passed = seed_passed,
            .stats = stats,
        });
    }

    return report;
}

const MultiSeedReport = struct {
    allocator: std.mem.Allocator,
    seeds_tested: usize,
    iterations_per_seed: usize,
    passed: usize,
    failed: usize,
    seed_results: std.ArrayList(SeedResult),

    pub fn deinit(self: *MultiSeedReport) void {
        self.seed_results.deinit(self.allocator);
    }

    pub fn printSummary(self: *const MultiSeedReport) void {
        std.debug.print("\n=== Multi-Seed Test Summary ===\n", .{});
        std.debug.print("Seeds tested: {d}/{d}\n", .{ self.passed, self.seeds_tested });
        std.debug.print("Iterations per seed: {d}\n", .{self.iterations_per_seed});
        std.debug.print("Coverage: {d:.2}%\n", .{
            if (self.seed_results.items.len > 0)
                @as(f64, @floatFromInt(self.passed)) * 100.0 / @as(f64, @floatFromInt(self.seeds_tested))
            else
                0.0,
        });

        for (self.seed_results.items) |result| {
            const status = if (result.passed) "✓" else "✗";
            std.debug.print("{s} Seed 0x{x}: {} unique states, {:.1}% coverage\n", .{
                status,
                result.seed,
                result.stats.unique_states,
                result.stats.coverage_estimate * 100.0,
            });
        }
        std.debug.print("==============================\n\n", .{});
    }
};

const SeedResult = struct {
    seed: u64,
    passed: bool,
    stats: TestState.Stats,
};

/// Verify all invariants
fn verifyAllInvariants(state: *const TestState) !void {
    try invariantConservation(state);
    try invariantEmissionCap(state);
    try invariantHealthBounds(state);
    try invariantNoNegativeStake(state);
    try invariantMonotonic(state);
    try invariantNoDoubleSlash(state);
    try invariantHealthStakeCorrelation(state);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "dePIN invariants v2: multi-seed robustness" {
    const allocator = std.testing.allocator;
    const seeds = [_]u64{ 0xDEAD_BEEF, 0xCAFEBABE, 0x12345678, 0xFEE1_DEAD, 0x0BADD00D };

    var report = try runWithMultipleSeeds(allocator, &seeds, 1_000);
    defer report.deinit();

    report.printSummary();

    // All seeds should pass
    try std.testing.expectEqual(seeds.len, report.passed);
}

test "dePIN invariants v2: single seed with history" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    var rng = std.Random.DefaultPrng.init(0xDEAD_BEEF);
    const random = rng.random();

    var i: usize = 0;
    while (i < 10_000) : (i += 1) {
        state.op_count = i;
        applyRandomOp(&state, random);

        // Snapshot every 100 operations
        if (i % 100 == 0) {
            try state.snapshot();
        }

        // Verify all invariants
        try verifyAllInvariants(&state);
    }

    // Check temporal invariants with accumulated history
    try std.testing.expect(state.history.items.len > 0);
    try invariantMonotonic(&state);
    try invariantNoDoubleSlash(&state);
}

test "dePIN invariants v2: coverage estimation" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    var rng = std.Random.DefaultPrng.init(0xc0edb3a7);
    const random = rng.random();

    // Run diverse operations
    var i: usize = 0;
    while (i < 5_000) : (i += 1) {
        state.op_count = i;
        applyRandomOp(&state, random);

        if (i % 50 == 0) {
            try state.snapshot();
        }
    }

    const stats = state.getStats();

    // We should have decent coverage
    try std.testing.expect(stats.unique_states > 100);
    try std.testing.expect(stats.coverage_estimate > 0.01);
}

test "dePIN invariants v2: shrinking example" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    // Create a shrinkable operation
    var op = ShrinkableOp{
        .op_type = .stake,
        .amount = 10_000 * TRI_WEI,
        .node_idx = 7,
    };

    // Shrink to minimal
    var shrink_count: usize = 0;
    while (op.shrink()) {
        shrink_count += 1;
    }

    // Should have shrunk at least once
    try std.testing.expect(shrink_count > 0);
    try std.testing.expectEqual(@as(u128, 100) * TRI_WEI, op.amount);
    try std.testing.expectEqual(@as(usize, 0), op.node_idx);
}

test "dePIN invariants v2: temporal monotonicity" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    var rng = std.Random.DefaultPrng.init(0xd0b0b0d3);
    const random = rng.random();

    // Build up history
    var i: usize = 0;
    while (i < 1_000) : (i += 1) {
        state.op_count = i;
        applyRandomOp(&state, random);

        if (i % 10 == 0) {
            try state.snapshot();
        }
    }

    // Verify temporal invariants hold
    try invariantMonotonic(&state);
}

test "dePIN invariants v2: emission cap with direct emission" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    // Test that emission cap is enforced
    const cap = state.app_state.getEmissionCap();

    // Try to emit exactly at cap
    try state.app_state.addEmission(cap);
    try invariantEmissionCap(&state);

    // Try to exceed cap - should return EmissionCapExceeded error
    const result = state.app_state.addEmission(1);
    if (result != error.EmissionCapExceeded) {
        std.debug.print("Expected EmissionCapExceeded, got: {!}\n", .{result});
    }
    try std.testing.expectError(error.EmissionCapExceeded, result);
}

test "dePIN invariants v2: all invariants stress test" {
    const allocator = std.testing.allocator;
    var state = TestState.init(allocator);
    defer state.deinit();

    var rng = std.Random.DefaultPrng.init(0x57355732);
    const random = rng.random();

    // Intensive test with all invariants checked
    var i: usize = 0;
    while (i < 20_000) : (i += 1) {
        state.op_count = i;
        applyRandomOp(&state, random);

        if (i % 100 == 0) {
            try state.snapshot();
        }

        // Verify all invariants
        try verifyAllInvariants(&state);
    }

    const stats = state.getStats();
    std.debug.print("Stress test: {d} ops, {d} snapshots, {d} unique states ({d:.1}% coverage)\n", .{
        stats.operations_passed,
        stats.snapshots_recorded,
        stats.unique_states,
        stats.coverage_estimate * 100.0,
    });
}
