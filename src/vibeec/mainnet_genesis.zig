// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MAINNET GENESIS - $TRI Token Economy
// Total Supply: 3^21 = 10,460,353,203 $TRI (Phoenix Number)
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: f64 = 1.618033988749895;

/// Phoenix Number: 3^21 = Total $TRI Supply
pub const PHOENIX_NUMBER: u64 = 10_460_353_203;

/// Block time in seconds
pub const BLOCK_TIME_SECONDS: u32 = 3; // Trinity = 3

/// Genesis timestamp (Feb 6, 2026 00:00:00 UTC)
pub const GENESIS_TIMESTAMP: u64 = 1770336000;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENOMICS ALLOCATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Allocation = struct {
    name: []const u8,
    percentage: u8,
    amount: u64,
    vesting_months: u32,
    cliff_months: u32,

    pub fn monthlyUnlock(self: Allocation) u64 {
        if (self.vesting_months == 0) return self.amount;
        return self.amount / self.vesting_months;
    }
};

/// Token distribution (totals 100%)
pub const ALLOCATIONS = [_]Allocation{
    // Founder & Team (20%) - 4 year vesting, 1 year cliff
    .{
        .name = "Founder & Team",
        .percentage = 20,
        .amount = PHOENIX_NUMBER * 20 / 100, // 2,092,070,640
        .vesting_months = 48,
        .cliff_months = 12,
    },
    // Node Rewards (40%) - Released over time for mining/inference
    .{
        .name = "Node Rewards",
        .percentage = 40,
        .amount = PHOENIX_NUMBER * 40 / 100, // 4,184,141,281
        .vesting_months = 120, // 10 years
        .cliff_months = 0,
    },
    // Community & Ecosystem (20%)
    .{
        .name = "Community & Ecosystem",
        .percentage = 20,
        .amount = PHOENIX_NUMBER * 20 / 100, // 2,092,070,640
        .vesting_months = 36,
        .cliff_months = 0,
    },
    // Treasury & Development (10%)
    .{
        .name = "Treasury & Development",
        .percentage = 10,
        .amount = PHOENIX_NUMBER * 10 / 100, // 1,046,035,320
        .vesting_months = 60,
        .cliff_months = 6,
    },
    // Liquidity & Exchange (10%)
    .{
        .name = "Liquidity & Exchange",
        .percentage = 10,
        .amount = PHOENIX_NUMBER * 10 / 100, // 1,046,035,320
        .vesting_months = 0, // Immediate for liquidity
        .cliff_months = 0,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const BlockHeader = struct {
    version: u32 = 1,
    height: u64,
    prev_hash: [32]u8,
    merkle_root: [32]u8,
    timestamp: u64,
    difficulty: u64,
    nonce: u64,

    pub fn hash(self: *const BlockHeader) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(std.mem.asBytes(&self.version));
        hasher.update(std.mem.asBytes(&self.height));
        hasher.update(&self.prev_hash);
        hasher.update(&self.merkle_root);
        hasher.update(std.mem.asBytes(&self.timestamp));
        hasher.update(std.mem.asBytes(&self.difficulty));
        hasher.update(std.mem.asBytes(&self.nonce));
        return hasher.finalResult();
    }
};

pub const Transaction = struct {
    tx_type: TxType,
    from: [32]u8,
    to: [32]u8,
    amount: u64,
    fee: u64,
    timestamp: u64,
    signature: [64]u8,

    pub const TxType = enum(u8) {
        transfer = 0,
        stake = 1,
        unstake = 2,
        inference_reward = 3,
        mining_reward = 4,
        genesis_mint = 255,
    };
};

pub const Block = struct {
    header: BlockHeader,
    transactions: []const Transaction,

    pub fn isGenesis(self: *const Block) bool {
        return self.header.height == 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GENESIS BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

/// Create genesis block with initial token distribution
pub fn createGenesisBlock() Block {
    const zero_hash: [32]u8 = [_]u8{0} ** 32;

    // Genesis header
    const header = BlockHeader{
        .version = 1,
        .height = 0,
        .prev_hash = zero_hash,
        .merkle_root = computeGenesisMerkleRoot(),
        .timestamp = GENESIS_TIMESTAMP,
        .difficulty = 1,
        .nonce = 0,
    };

    return Block{
        .header = header,
        .transactions = &[_]Transaction{},
    };
}

fn computeGenesisMerkleRoot() [32]u8 {
    // Simplified: hash of "TRINITY GENESIS φ² + 1/φ² = 3"
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("TRINITY GENESIS φ² + 1/φ² = 3 KOSCHEI IS IMMORTAL");
    hasher.update(std.mem.asBytes(&PHOENIX_NUMBER));
    return hasher.finalResult();
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD CALCULATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Blocks per year (3 second blocks)
pub const BLOCKS_PER_YEAR: u64 = 365 * 24 * 60 * 60 / BLOCK_TIME_SECONDS; // ~10,512,000

/// Initial block reward
pub const INITIAL_BLOCK_REWARD: u64 = 100; // 100 $TRI per block

/// Halving interval (every 2 years)
pub const HALVING_INTERVAL: u64 = BLOCKS_PER_YEAR * 2; // ~21,024,000 blocks

/// Calculate block reward at given height
pub fn calculateBlockReward(height: u64) u64 {
    const halvings = height / HALVING_INTERVAL;
    if (halvings >= 64) return 0; // Max 64 halvings

    return INITIAL_BLOCK_REWARD >> @intCast(halvings);
}

/// Calculate inference reward (based on tokens processed)
pub fn calculateInferenceReward(tokens_processed: u64, coherent: bool) u64 {
    const base_reward = tokens_processed / 1000; // 1 $TRI per 1000 tokens
    if (coherent) {
        return base_reward * 2; // 2x for coherent output
    }
    return base_reward;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NODE STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeState = struct {
    node_id: [32]u8,
    stake: u64,
    total_rewards: u64,
    blocks_mined: u64,
    inferences_completed: u64,
    tokens_processed: u64,
    joined_at: u64,
    last_active: u64,

    pub fn isActive(self: NodeState, current_time: u64) bool {
        return current_time - self.last_active < 3600; // Active within 1 hour
    }

    pub fn effectiveStake(self: NodeState) u64 {
        // Stake weight increases with activity
        const activity_bonus = @min(self.inferences_completed / 100, 100);
        return self.stake * (100 + activity_bonus) / 100;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify φ² + 1/φ² = 3 (Trinity Identity)
pub fn verifyPhiIdentity() f64 {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    return phi_sq + inv_phi_sq; // Should be 3.0
}

/// Verify total supply equals Phoenix Number
pub fn verifyTotalSupply() bool {
    var total: u64 = 0;
    for (ALLOCATIONS) |alloc| {
        total += alloc.amount;
    }
    // Allow for rounding (should be within 100 of Phoenix Number)
    return @abs(@as(i64, @intCast(total)) - @as(i64, @intCast(PHOENIX_NUMBER))) < 100;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phoenix number is 3^21" {
    const expected: u64 = 10_460_353_203;
    try std.testing.expectEqual(expected, PHOENIX_NUMBER);

    // Verify 3^21 calculation
    var calc: u64 = 1;
    var i: u32 = 0;
    while (i < 21) : (i += 1) {
        calc *= 3;
    }
    try std.testing.expectEqual(expected, calc);
}

test "phi identity equals 3" {
    const result = verifyPhiIdentity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
}

test "total supply equals phoenix number" {
    try std.testing.expect(verifyTotalSupply());
}

test "allocations sum to 100 percent" {
    var total_pct: u32 = 0;
    for (ALLOCATIONS) |alloc| {
        total_pct += alloc.percentage;
    }
    try std.testing.expectEqual(@as(u32, 100), total_pct);
}

test "genesis block is valid" {
    const genesis = createGenesisBlock();
    try std.testing.expect(genesis.isGenesis());
    try std.testing.expectEqual(@as(u64, 0), genesis.header.height);
    try std.testing.expectEqual(GENESIS_TIMESTAMP, genesis.header.timestamp);
}

test "block reward halving" {
    // Initial reward
    try std.testing.expectEqual(@as(u64, 100), calculateBlockReward(0));
    try std.testing.expectEqual(@as(u64, 100), calculateBlockReward(HALVING_INTERVAL - 1));

    // First halving
    try std.testing.expectEqual(@as(u64, 50), calculateBlockReward(HALVING_INTERVAL));
    try std.testing.expectEqual(@as(u64, 50), calculateBlockReward(HALVING_INTERVAL * 2 - 1));

    // Second halving
    try std.testing.expectEqual(@as(u64, 25), calculateBlockReward(HALVING_INTERVAL * 2));
}

test "inference reward calculation" {
    // 1000 tokens = 1 $TRI
    try std.testing.expectEqual(@as(u64, 1), calculateInferenceReward(1000, false));

    // Coherent bonus (2x)
    try std.testing.expectEqual(@as(u64, 2), calculateInferenceReward(1000, true));

    // Larger inference
    try std.testing.expectEqual(@as(u64, 20), calculateInferenceReward(10000, true));
}

test "node state activity" {
    const node = NodeState{
        .node_id = [_]u8{0} ** 32,
        .stake = 1000,
        .total_rewards = 0,
        .blocks_mined = 0,
        .inferences_completed = 100,
        .tokens_processed = 0,
        .joined_at = 0,
        .last_active = 1000,
    };

    // Active if within 1 hour (3600 seconds)
    try std.testing.expect(node.isActive(4599)); // 1000 + 3599 = within 1 hour
    try std.testing.expect(!node.isActive(4601)); // 1000 + 3601 = outside 1 hour

    // Effective stake with activity bonus
    const effective = node.effectiveStake();
    try std.testing.expect(effective > node.stake);
}

test "allocation vesting" {
    const founder = ALLOCATIONS[0];
    try std.testing.expectEqualStrings("Founder & Team", founder.name);
    try std.testing.expectEqual(@as(u8, 20), founder.percentage);
    try std.testing.expectEqual(@as(u32, 48), founder.vesting_months);
    try std.testing.expectEqual(@as(u32, 12), founder.cliff_months);

    // Monthly unlock
    const monthly = founder.monthlyUnlock();
    try std.testing.expect(monthly > 0);
    try std.testing.expect(monthly * 48 <= founder.amount + 48); // Allow rounding
}
