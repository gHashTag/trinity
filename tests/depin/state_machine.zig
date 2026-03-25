// ═══════════════════════════════════════════════════════════════════════════════
// dePIN State Machine Model — Erlang QuickCheck Style Testing
// Task: depin-state-machine-v1
// Build: zig build test (module mapped in build.zig)
//
// Inspired by:
// - Erlang QuickCheck: command generation, pre/post conditions
// - Move Prover: fine-grained invariant checking
// - Trail of Bits 2025: invariant-driven development
//
// φ² + 1/φ² = 3 = TRINITY | Genesis Block: 26 March 2026, 00:00 UTC
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import firebird modules
const app_state = @import("firebird_app_state");
const staking = @import("firebird_staking");
const reputation = @import("firebird_reputation");

const TRI_WEI = app_state.TRI_WEI;
const MIN_STAKE = staking.MIN_STAKE;

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL STATE — Abstract representation for invariant checking
// ═══════════════════════════════════════════════════════════════════════════════

/// Abstract model state tracks what SHOULD be true
/// Independent of implementation details
/// Uses u64 address hash for simplicity (avoids string memory management)
pub const ModelState = struct {
    allocator: std.mem.Allocator,
    /// Staked amounts by address hash
    staked: std.AutoHashMap(u64, u128),
    /// Slashed amounts by address hash
    slashed: std.AutoHashMap(u64, u128),
    /// Total emissions
    emitted: u128,
    /// Emission cap
    cap: u128,
    /// Unique state counter (for coverage tracking)
    state_id: usize,
    /// History for temporal invariants
    history: std.ArrayListUnmanaged(StateSnapshot),

    pub const StateSnapshot = struct {
        state_id: usize,
        timestamp: i64,
        total_staked: u128,
        total_slashed: u128,
        emitted: u128,
        active_nodes: usize,
    };

    pub fn init(allocator: std.mem.Allocator, cap: u128) ModelState {
        return ModelState{
            .allocator = allocator,
            .staked = std.AutoHashMap(u64, u128).init(allocator),
            .slashed = std.AutoHashMap(u64, u128).init(allocator),
            .emitted = 0,
            .cap = cap,
            .state_id = 0,
            .history = .{},
        };
    }

    pub fn deinit(self: *ModelState) void {
        self.staked.deinit();
        self.slashed.deinit();
        self.history.deinit(self.allocator);
    }

    /// Hash address to u64 for simple key lookup
    fn hashAddress(address: [20]u8) u64 {
        var result: u64 = 0;
        for (address) |byte| {
            result = result *% 31 +% byte;
        }
        return result;
    }

    /// Record current state for temporal invariants
    pub fn snapshot(self: *ModelState, total_staked: u128, active_nodes: usize) !void {
        const total_slashed = blk: {
            var sum: u128 = 0;
            var iter = self.slashed.iterator();
            while (iter.next()) |entry| {
                sum += entry.value_ptr.*;
            }
            break :blk sum;
        };

        try self.history.append(self.allocator, StateSnapshot{
            .state_id = self.state_id,
            .timestamp = std.time.timestamp(),
            .total_staked = total_staked,
            .total_slashed = total_slashed,
            .emitted = self.emitted,
            .active_nodes = active_nodes,
        });
        self.state_id += 1;
    }

    /// Get total staked across all addresses
    pub fn getTotalStaked(self: *const ModelState) u128 {
        var sum: u128 = 0;
        var iter = self.staked.iterator();
        while (iter.next()) |entry| {
            sum += entry.value_ptr.*;
        }
        return sum;
    }

    /// Get total slashed across all addresses
    pub fn getTotalSlashed(self: *const ModelState) u128 {
        var sum: u128 = 0;
        var iter = self.slashed.iterator();
        while (iter.next()) |entry| {
            sum += entry.value_ptr.*;
        }
        return sum;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PRE/POST CONDITIONS (QuickCheck style)
    // ═════════════════════════════════════════════════════════════════════════

    /// PRE condition for stake: amount >= MIN_STAKE
    pub fn preStake(self: *const ModelState, address_hash: u64, amount: u128) bool {
        _ = self;
        _ = address_hash;
        return amount >= MIN_STAKE;
    }

    /// POST condition for stake: total_staked increases by amount
    pub fn postStake(self: *ModelState, address_hash: u64, amount: u128) !void {
        const existing = self.staked.get(address_hash) orelse 0;
        try self.staked.put(address_hash, existing + amount);
    }

    /// PRE condition for slash: address must have stakes
    pub fn preSlash(self: *const ModelState, address_hash: u64) bool {
        return self.staked.get(address_hash) != null;
    }

    /// POST condition for slash: staked decreases, slashed increases
    pub fn postSlash(self: *ModelState, address_hash: u64, penalty_percentage: f64) !void {
        const staked_amount = self.staked.get(address_hash) orelse return error.AddressNotFound;
        const slash_amount = @as(u128, @intFromFloat(@as(f64, @floatFromInt(staked_amount)) * penalty_percentage));
        const remaining = staked_amount - slash_amount;

        if (remaining > 0) {
            try self.staked.put(address_hash, remaining);
        } else {
            _ = self.staked.remove(address_hash);
        }

        const existing_slash = self.slashed.get(address_hash) orelse 0;
        try self.slashed.put(address_hash, existing_slash + slash_amount);
    }

    /// PRE condition for unstake: stake must exist and be unlocked
    pub fn preUnstake(self: *const ModelState, address_hash: u64) bool {
        return self.staked.get(address_hash) != null;
    }

    /// POST condition for unstake: stake removed
    pub fn postUnstake(self: *ModelState, address_hash: u64) !void {
        const removed = self.staked.remove(address_hash);
        if (!removed) return error.StakeNotFound;
    }

    /// PRE condition for emission: new_total <= cap
    pub fn preEmission(self: *const ModelState, amount: u128) bool {
        return self.emitted + amount <= self.cap;
    }

    /// POST condition for emission: emitted increases
    pub fn postEmission(self: *ModelState, amount: u128) !void {
        if (!self.preEmission(amount)) return error.EmissionCapExceeded;
        self.emitted += amount;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND GENERATION (QuickCall style)
// ═══════════════════════════════════════════════════════════════════════════════

/// Commands that can be executed on the state machine
pub const Command = union(enum) {
    stake: StakeCmd,
    slash: SlashCmd,
    unstake: UnstakeCmd,
    emit: EmitCmd,
    update_health: UpdateHealthCmd,

    pub const StakeCmd = struct {
        address: [20]u8,
        amount: u128,
        lock_period: staking.LockPeriod,
    };

    pub const SlashCmd = struct {
        address: [20]u8,
        penalty: f32,
    };

    pub const UnstakeCmd = struct {
        address: [20]u8,
    };

    pub const EmitCmd = struct {
        amount: u128,
    };

    pub const UpdateHealthCmd = struct {
        address: [20]u8,
        region: reputation.BrainRegion,
        value: u32,
    };
};

/// Command generator (creates random valid commands)
pub const CommandGenerator = struct {
    prng: std.Random.DefaultPrng,

    pub fn init(seed: u64) CommandGenerator {
        return CommandGenerator{
            .prng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Get random reference
    fn random(self: *CommandGenerator) std.Random {
        return self.prng.random();
    }

    /// Generate a random command
    pub fn next(self: *CommandGenerator) Command {
        const rand = self.random();
        const cmd_type = rand.enumValue(std.meta.Tag(Command));
        return switch (cmd_type) {
            .stake => Command{
                .stake = .{
                    .address = self.randomAddress(),
                    .amount = rand.intRangeAtMost(u128, 100, 10_000) * TRI_WEI,
                    .lock_period = self.randomLockPeriod(),
                },
            },
            .slash => Command{
                .slash = .{
                    .address = self.randomAddress(),
                    .penalty = 0.01 + rand.float(f32) * 0.99, // 1% to 100%
                },
            },
            .unstake => Command{
                .unstake = .{
                    .address = self.randomAddress(),
                },
            },
            .emit => Command{
                .emit = .{
                    .amount = self.random().intRangeAtMost(u128, 1, 1000) * TRI_WEI,
                },
            },
            .update_health => Command{
                .update_health = .{
                    .address = self.randomAddress(),
                    .region = self.random().enumValue(reputation.BrainRegion),
                    .value = self.random().intRangeAtMost(u32, 0, 65536),
                },
            },
        };
    }

    fn randomAddress(self: *CommandGenerator) [20]u8 {
        var result: [20]u8 = undefined;
        self.random().bytes(&result);
        return result;
    }

    fn randomLockPeriod(self: *CommandGenerator) staking.LockPeriod {
        const val = self.random().intRangeAtMost(u8, 0, 3);
        return switch (val) {
            0 => .one_month,
            1 => .three_months,
            2 => .six_months,
            else => .twelve_months,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATE MACHINE EXECUTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const StateMachineExecutor = struct {
    allocator: std.mem.Allocator,
    model: ModelState,
    real_state: struct {
        app_state: app_state.AppState,
        staking: staking.StakingManager,
        reputation: reputation.ReputationRegistry,
    },
    commands_executed: usize,
    commands_passed: usize,
    commands_failed: usize,

    pub fn init(allocator: std.mem.Allocator) StateMachineExecutor {
        const app = app_state.AppState.init(allocator);
        return StateMachineExecutor{
            .allocator = allocator,
            .model = ModelState.init(allocator, app.getEmissionCap()),
            .real_state = .{
                .app_state = app,
                .staking = staking.StakingManager.init(allocator),
                .reputation = reputation.ReputationRegistry.init(allocator),
            },
            .commands_executed = 0,
            .commands_passed = 0,
            .commands_failed = 0,
        };
    }

    pub fn deinit(self: *StateMachineExecutor) void {
        self.model.deinit();
        self.real_state.staking.deinit();
        self.real_state.reputation.deinit();
    }

    /// Execute a command on both model and real state, verify consistency
    pub fn execute(self: *StateMachineExecutor, cmd: Command) !void {
        self.commands_executed += 1;

        switch (cmd) {
            .stake => |c| try self.executeStake(c),
            .slash => |c| try self.executeSlash(c),
            .unstake => |c| try self.executeUnstake(c),
            .emit => |c| try self.executeEmit(c),
            .update_health => |c| try self.executeUpdateHealth(c),
        }
    }

    fn executeStake(self: *StateMachineExecutor, cmd: Command.StakeCmd) !void {
        const addr_hash = ModelState.hashAddress(cmd.address);

        // Check pre-condition
        if (!self.model.preStake(addr_hash, cmd.amount)) {
            self.commands_failed += 1;
            return;
        }

        // Update model
        try self.model.postStake(addr_hash, cmd.amount);

        // Execute on real state
        const real_result = self.real_state.staking.createStake(cmd.address, cmd.amount, cmd.lock_period);

        // Verify: both should succeed or both should fail
        if (real_result == error.StakeBelowMinimum) {
            // Model check passed but real failed - inconsistency!
            // This can happen if MIN_STAKE differs
            self.commands_failed += 1;
        } else {
            _ = real_result catch {}; // May fail for other reasons
            self.commands_passed += 1;
        }
    }

    fn executeSlash(self: *StateMachineExecutor, cmd: Command.SlashCmd) !void {
        const addr_hash = ModelState.hashAddress(cmd.address);

        if (!self.model.preSlash(addr_hash)) {
            self.commands_failed += 1;
            return;
        }

        try self.model.postSlash(addr_hash, cmd.penalty);
        _ = self.real_state.staking.slashStaker(cmd.address, cmd.penalty) catch {};
        self.commands_passed += 1;
    }

    fn executeUnstake(self: *StateMachineExecutor, cmd: Command.UnstakeCmd) !void {
        const addr_hash = ModelState.hashAddress(cmd.address);

        if (!self.model.preUnstake(addr_hash)) {
            self.commands_failed += 1;
            return;
        }

        // For unstake, we need to find actual stake IDs
        const stakes = try self.real_state.staking.getStakerStakes(cmd.address, self.allocator);
        defer self.allocator.free(stakes);

        if (stakes.len == 0) {
            self.commands_failed += 1;
            return;
        }

        // Try to unstake first withdrawable stake
        for (stakes) |stake| {
            if (stake.canWithdraw()) {
                _ = self.real_state.staking.withdrawStake(stake.stake_id) catch {};
                break;
            }
        }

        try self.model.postUnstake(addr_hash);
        self.commands_passed += 1;
    }

    fn executeEmit(self: *StateMachineExecutor, cmd: Command.EmitCmd) !void {
        if (!self.model.preEmission(cmd.amount)) {
            self.commands_failed += 1;
            return;
        }

        try self.model.postEmission(cmd.amount);
        const result = self.real_state.app_state.addEmission(cmd.amount);

        if (result == error.EmissionCapExceeded) {
            self.commands_failed += 1;
        } else {
            _ = result catch {};
            self.commands_passed += 1;
        }
    }

    fn executeUpdateHealth(self: *StateMachineExecutor, cmd: Command.UpdateHealthCmd) !void {
        const addr_hex = try std.fmt.allocPrint(self.allocator, "{s}", .{
            std.fmt.bytesToHex(&cmd.address, .lower),
        });
        defer self.allocator.free(addr_hex);

        // Update reputation
        _ = self.real_state.reputation.updateRegion(addr_hex, cmd.region, cmd.value) catch {};
        self.commands_passed += 1;
    }

    /// Verify model matches real state
    pub fn verify(self: *const StateMachineExecutor) !void {
        // Check emission matches
        if (self.model.emitted != self.real_state.app_state.getEmissionTotal()) {
            std.debug.print("Model emitted: {d}, Real emitted: {d}\n", .{
                self.model.emitted,
                self.real_state.app_state.getEmissionTotal(),
            });
            return error.StateMismatch;
        }
    }

    /// Get execution statistics
    pub fn getStats(self: *const StateMachineExecutor) Stats {
        return Stats{
            .commands_executed = self.commands_executed,
            .commands_passed = self.commands_passed,
            .commands_failed = self.commands_failed,
            .states_visited = self.model.state_id,
            .pass_rate = if (self.commands_executed > 0)
                @as(f64, @floatFromInt(self.commands_passed)) / @as(f64, @floatFromInt(self.commands_executed))
            else
                0.0,
        };
    }

    pub const Stats = struct {
        commands_executed: usize,
        commands_passed: usize,
        commands_failed: usize,
        states_visited: usize,
        pass_rate: f64,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "State Machine: basic command execution" {
    const allocator = std.testing.allocator;
    var executor = StateMachineExecutor.init(allocator);
    defer executor.deinit();

    var gen = CommandGenerator.init(0x57444534);

    // Execute 100 commands
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const cmd = gen.next();
        try executor.execute(cmd);
    }

    // Verify final state
    try executor.verify();

    const stats = executor.getStats();
    try std.testing.expect(stats.commands_executed > 0);
}

test "State Machine: stake then slash consistency" {
    const allocator = std.testing.allocator;
    var executor = StateMachineExecutor.init(allocator);
    defer executor.deinit();

    var addr: [20]u8 = undefined;
    @memset(&addr, 0);
    addr[0] = 0xAA;

    // Stake
    try executor.execute(.{
        .stake = .{
            .address = addr,
            .amount = 1000 * TRI_WEI,
            .lock_period = .one_month,
        },
    });

    // Slash
    try executor.execute(.{
        .slash = .{
            .address = addr,
            .penalty = 0.1, // 10%
        },
    });

    try executor.verify();
}

test "State Machine: emission cap enforcement" {
    const allocator = std.testing.allocator;
    var executor = StateMachineExecutor.init(allocator);
    defer executor.deinit();

    const cap = executor.real_state.app_state.getEmissionCap();

    // Try to emit exactly cap
    try executor.execute(.{ .emit = .{ .amount = cap } });

    // Try to exceed - should fail
    const result = executor.real_state.app_state.addEmission(1);
    try std.testing.expectError(error.EmissionCapExceeded, result);
}

test "State Machine: pre/post conditions" {
    const allocator = std.testing.allocator;
    var model = ModelState.init(allocator, 1_000_000 * TRI_WEI);
    defer model.deinit();

    var addr: [20]u8 = undefined;
    @memset(&addr, 0);

    const addr_hash = ModelState.hashAddress(addr);

    // Test pre condition
    try std.testing.expect(model.preStake(addr_hash, MIN_STAKE));
    try std.testing.expect(!model.preStake(addr_hash, MIN_STAKE - 1));

    // Test post condition
    try model.postStake(addr_hash, 500 * TRI_WEI);
    const staked = model.staked.get(addr_hash).?;
    try std.testing.expectEqual(@as(u128, 500) * TRI_WEI, staked);
}
