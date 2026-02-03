// ═══════════════════════════════════════════════════════════════════════════════
// DePIN INTEGRATION - $TRI Token Mock for ЖАР ПТИЦА
// Decentralized Physical Infrastructure Network
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// $TRI TOKEN CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRI_DECIMALS: u8 = 18;
pub const TRI_TOTAL_SUPPLY: u128 = 100_000_000 * std.math.pow(u128, 10, TRI_DECIMALS);
pub const TRI_SYMBOL = "$TRI";
pub const TRI_NAME = "Trinity Token";

// Reward rates (in TRI wei per operation)
pub const REWARD_EVOLUTION_GEN: u128 = 1_000_000_000_000_000; // 0.001 TRI per generation
pub const REWARD_NAVIGATION_STEP: u128 = 100_000_000_000_000; // 0.0001 TRI per step
pub const REWARD_CONVERSION: u128 = 10_000_000_000_000_000; // 0.01 TRI per conversion
pub const REWARD_BENCHMARK: u128 = 5_000_000_000_000_000; // 0.005 TRI per benchmark

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET
// ═══════════════════════════════════════════════════════════════════════════════

pub const Wallet = struct {
    address: [20]u8,
    balance: u128,
    nonce: u64,
    pending_rewards: u128,

    pub fn init(seed: u64) Wallet {
        var rng = std.Random.DefaultPrng.init(seed);
        var address: [20]u8 = undefined;
        rng.fill(&address);

        return Wallet{
            .address = address,
            .balance = 0,
            .nonce = 0,
            .pending_rewards = 0,
        };
    }

    pub fn getAddressHex(self: *const Wallet) [42]u8 {
        var hex: [42]u8 = undefined;
        hex[0] = '0';
        hex[1] = 'x';
        for (self.address, 0..) |byte, i| {
            const high = byte >> 4;
            const low = byte & 0x0F;
            hex[2 + i * 2] = if (high < 10) '0' + high else 'a' + high - 10;
            hex[3 + i * 2] = if (low < 10) '0' + low else 'a' + low - 10;
        }
        return hex;
    }

    pub fn addReward(self: *Wallet, amount: u128) void {
        self.pending_rewards += amount;
    }

    pub fn claimRewards(self: *Wallet) u128 {
        const rewards = self.pending_rewards;
        self.balance += rewards;
        self.pending_rewards = 0;
        self.nonce += 1;
        return rewards;
    }

    pub fn getBalanceFormatted(self: *const Wallet) f64 {
        return @as(f64, @floatFromInt(self.balance)) / @as(f64, @floatFromInt(std.math.pow(u128, 10, TRI_DECIMALS)));
    }

    pub fn getPendingFormatted(self: *const Wallet) f64 {
        return @as(f64, @floatFromInt(self.pending_rewards)) / @as(f64, @floatFromInt(std.math.pow(u128, 10, TRI_DECIMALS)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DePIN NODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeStatus = enum {
    offline,
    syncing,
    online,
    earning,
};

pub const DePINNode = struct {
    wallet: Wallet,
    status: NodeStatus,
    operations_count: u64,
    total_earned: u128,
    uptime_seconds: u64,
    start_time: i64,

    pub fn init(seed: u64) DePINNode {
        return DePINNode{
            .wallet = Wallet.init(seed),
            .status = .offline,
            .operations_count = 0,
            .total_earned = 0,
            .uptime_seconds = 0,
            .start_time = 0,
        };
    }

    pub fn start(self: *DePINNode) void {
        self.status = .syncing;
        self.start_time = std.time.timestamp();
        // Simulate sync
        self.status = .online;
    }

    pub fn stop(self: *DePINNode) void {
        if (self.start_time > 0) {
            self.uptime_seconds += @intCast(std.time.timestamp() - self.start_time);
        }
        self.status = .offline;
        self.start_time = 0;
    }

    pub fn recordOperation(self: *DePINNode, op_type: OperationType) void {
        if (self.status != .online and self.status != .earning) return;

        self.operations_count += 1;
        self.status = .earning;

        const reward = switch (op_type) {
            .evolution => REWARD_EVOLUTION_GEN,
            .navigation => REWARD_NAVIGATION_STEP,
            .conversion => REWARD_CONVERSION,
            .benchmark => REWARD_BENCHMARK,
        };

        self.wallet.addReward(reward);
        self.total_earned += reward;
    }

    pub fn getStats(self: *const DePINNode) NodeStats {
        return NodeStats{
            .status = self.status,
            .operations = self.operations_count,
            .earned_tri = self.wallet.getBalanceFormatted() + self.wallet.getPendingFormatted(),
            .pending_tri = self.wallet.getPendingFormatted(),
            .uptime_hours = @as(f64, @floatFromInt(self.uptime_seconds)) / 3600.0,
        };
    }
};

pub const OperationType = enum {
    evolution,
    navigation,
    conversion,
    benchmark,
};

pub const NodeStats = struct {
    status: NodeStatus,
    operations: u64,
    earned_tri: f64,
    pending_tri: f64,
    uptime_hours: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardCalculator = struct {
    /// Calculate rewards for evolution run
    pub fn calculateEvolutionReward(generations: usize, fitness: f64) u128 {
        const base = REWARD_EVOLUTION_GEN * @as(u128, @intCast(generations));
        // Bonus for high fitness
        const bonus: u128 = if (fitness > 0.9)
            base / 2
        else if (fitness > 0.7)
            base / 4
        else
            0;
        return base + bonus;
    }

    /// Calculate rewards for navigation
    pub fn calculateNavigationReward(steps: usize, final_similarity: f64) u128 {
        const base = REWARD_NAVIGATION_STEP * @as(u128, @intCast(steps));
        // Bonus for reaching target similarity
        const bonus: u128 = if (final_similarity > 0.8)
            base
        else if (final_similarity > 0.5)
            base / 2
        else
            0;
        return base + bonus;
    }

    /// Calculate rewards for WASM conversion
    pub fn calculateConversionReward(instructions: usize) u128 {
        const base = REWARD_CONVERSION;
        // Bonus for complex modules
        const complexity_bonus = @as(u128, @intCast(instructions)) * 1_000_000_000_000; // 0.000001 TRI per instruction
        return base + complexity_bonus;
    }

    /// Format TRI amount for display
    pub fn formatTRI(amount: u128) f64 {
        return @as(f64, @floatFromInt(amount)) / @as(f64, @floatFromInt(std.math.pow(u128, 10, TRI_DECIMALS)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "wallet creation" {
    const wallet = Wallet.init(12345);
    try std.testing.expectEqual(@as(u128, 0), wallet.balance);
    try std.testing.expectEqual(@as(u64, 0), wallet.nonce);
}

test "wallet rewards" {
    var wallet = Wallet.init(12345);

    wallet.addReward(REWARD_EVOLUTION_GEN * 10);
    try std.testing.expect(wallet.pending_rewards > 0);

    const claimed = wallet.claimRewards();
    try std.testing.expectEqual(REWARD_EVOLUTION_GEN * 10, claimed);
    try std.testing.expectEqual(@as(u128, 0), wallet.pending_rewards);
    try std.testing.expectEqual(@as(u64, 1), wallet.nonce);
}

test "depin node operations" {
    var node = DePINNode.init(12345);
    try std.testing.expectEqual(NodeStatus.offline, node.status);

    node.start();
    try std.testing.expectEqual(NodeStatus.online, node.status);

    node.recordOperation(.evolution);
    try std.testing.expectEqual(NodeStatus.earning, node.status);
    try std.testing.expectEqual(@as(u64, 1), node.operations_count);

    node.stop();
    try std.testing.expectEqual(NodeStatus.offline, node.status);
}

test "reward calculator" {
    const evo_reward = RewardCalculator.calculateEvolutionReward(100, 0.95);
    try std.testing.expect(evo_reward > REWARD_EVOLUTION_GEN * 100);

    const nav_reward = RewardCalculator.calculateNavigationReward(25, 0.85);
    try std.testing.expect(nav_reward > REWARD_NAVIGATION_STEP * 25);

    const conv_reward = RewardCalculator.calculateConversionReward(200);
    try std.testing.expect(conv_reward > REWARD_CONVERSION);
}

test "format TRI" {
    const amount: u128 = 1_000_000_000_000_000_000; // 1 TRI
    const formatted = RewardCalculator.formatTRI(amount);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), formatted, 0.0001);
}
