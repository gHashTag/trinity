// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY TESTNET CONFIGURATION — Testnet Parameters
// Chain ID: φ-based (1.618033988749895... → 1618016180)
// φ² + 1/φ² = 3 | TESTNET PHASE 0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS — TESTNET
// ═══════════════════════════════════════════════════════════════════════════════

/// Testnet Chain ID (φ-based: 1.618033988749895... → 1618016180)
pub const CHAIN_ID: u32 = 1618016180;

/// Genesis timestamp (dynamic, set at first block)
pub const GENESIS_TIMESTAMP: u64 = 0; // Set when testnet starts

/// Block time in seconds (3 seconds = Trinity)
pub const BLOCK_TIME: u32 = 3;

/// Initial block reward (10x mainnet for testing)
pub const INITIAL_REWARD: u64 = 1000; // 1000 $TRI per block (vs 100 mainnet)

/// Halving interval (blocks)
pub const HALVING_INTERVAL: u64 = 210_000; // ~7.3 days at 3s blocks

/// Faucet drip amount
pub const FAUCET_DRIP_AMOUNT: u64 = 10_000; // 10,000 test $TRI per request

/// Faucet rate limit (seconds)
pub const FAUCET_RATE_LIMIT_SECONDS: u64 = 86_400; // 24 hours

/// Minimum stake for node registration
pub const MIN_STAKE: u64 = 1_000; // 1,000 test $TRI

/// Bootstrap nodes (testnet)
pub const BOOTSTRAP_NODES: []const BootstrapNode = &.{
    .{ .host = "bootstrap-us.test.trinity.network", .port = 9333 },
    .{ .host = "bootstrap-eu.test.trinity.network", .port = 9333 },
    .{ .host = "bootstrap-asia.test.trinity.network", .port = 9333 },
    .{ .host = "bootstrap-sa.test.trinity.network", .port = 9333 },
    .{ .host = "bootstrap-za.test.trinity.network", .port = 9333 },
};

pub const BootstrapNode = struct {
    host: []const u8,
    port: u16,
};

/// DNS seed for bootstrap discovery
pub const DNS_SEED: []const u8 = "_bootstrap._tcp.test.trinity.network";

/// Testnet explorer URL
pub const EXPLORER_URL: []const u8 = "https://testnet.trinity.network";

/// Testnet API base URL
pub const API_URL: []const u8 = "https://api.test.trinity.network";

/// Max nodes for testnet
pub const MAX_NODES: usize = 500;

/// Reward allocation (from 50M $TRI testnet pool)
pub const REWARD_ALLOCATION: u64 = 50_000_000;

/// Reward distribution:
/// - 50% (25M) for node operators
/// - 25% (12.5M) for bug bounties
/// - 15% (7.5M) for community testers
/// - 10% (5M) for early adopter bonus
pub const RewardPool = struct {
    node_operators: u64 = 25_000_000,
    bug_bounties: u64 = 12_500_000,
    community_testers: u64 = 7_500_000,
    early_adopter: u64 = 5_000_000,

    pub fn total(self: RewardPool) u64 {
        return self.node_operators + self.bug_bounties + self.community_testers + self.early_adopter;
    }
};

/// Bug bounty tiers
pub const BugBounty = struct {
    critical: u64 = 10_000, // 10K $TRI
    major: u64 = 5_000, // 5K $TRI
    minor: u64 = 1_000, // 1K $TRI

    pub fn getReward(self: BugBounty, severity: Severity) u64 {
        return switch (severity) {
            .critical => self.critical,
            .major => self.major,
            .minor => self.minor,
        };
    }

    pub const Severity = enum {
        critical,
        major,
        minor,
    };
};

/// Node tier multipliers (testnet = 10x mainnet)
pub const TIER_MULTIPLIER_FREE: f64 = 10.0;
pub const TIER_MULTIPLIER_STAKER: f64 = 15.0;
pub const TIER_MULTIPLIER_POWER: f64 = 20.0;
pub const TIER_MULTIPLIER_WHALE: f64 = 30.0;

/// Testnet phases
pub const TestnetPhase = enum(u8) {
    /// Phase 0: Foundation (Week 1-2) — Faucet, Bootstrap, Config
    foundation = 0,
    /// Phase 1: Incentivized Testnet (Week 3-8) — Rewards, Validation
    incentivized = 1,
    /// Phase 2: Stress Testing (Week 9-12) — Chaos, Load, Security
    stress_test = 2,
    /// Phase 3: Complete — Ready for mainnet migration
    complete = 3,

    pub fn toString(self: TestnetPhase) []const u8 {
        return switch (self) {
            .foundation => "foundation",
            .incentivized => "incentivized",
            .stress_test => "stress_test",
            .complete => "complete",
        };
    }

    pub fn durationWeeks(self: TestnetPhase) u8 {
        return switch (self) {
            .foundation => 2,
            .incentivized => 6,
            .stress_test => 4,
            .complete => 0,
        };
    }
};

/// Current testnet phase (will be updated as testnet progresses)
pub const CURRENT_PHASE: TestnetPhase = .foundation;

/// Validation targets for Phase 1
pub const ValidationTargets = struct {
    active_nodes: usize = 50,
    uptime_percent: f64 = 95.0,
    inference_jobs: usize = 1_000,
    bug_reports: usize = 10,
    regions: usize = 3,

    pub fn isMet(self: ValidationTargets, active_nodes: usize, uptime: f64, jobs: usize, bugs: usize, regions: usize) bool {
        return active_nodes >= self.active_nodes and
            uptime >= self.uptime_percent and
            jobs >= self.inference_jobs and
            bugs >= self.bug_reports and
            regions >= self.regions;
    }
};

/// Vested rewards (6 months after mainnet)
pub const VESTING_PERIOD_SECONDS: u64 = 15_552_000; // 180 days

/// Calculate block reward at given height (testnet = 10x)
pub fn calculateBlockReward(height: u64) u64 {
    const halvings = height / HALVING_INTERVAL;
    if (halvings >= 64) return 0;

    return INITIAL_REWARD >> @intCast(halvings);
}

/// Calculate testnet reward for node operator
pub fn calculateNodeReward(uptime_hours: f64, jobs_completed: usize, tier: Tier) u64 {
    const base_reward: u64 = 100; // Base reward per hour
    // Minimum 1x for any uptime, max 2x for 1+ week
    const uptime_bonus = @as(u64, @intFromFloat(@max(1.0, @min(2.0, uptime_hours / 168.0))));
    const job_bonus = @min(10, jobs_completed / 100); // Max 10x for 1000+ jobs
    const tier_mult = tier.multiplier();

    return base_reward * uptime_bonus * (1 + job_bonus) * tier_mult / 10;
}

pub const Tier = enum {
    free,
    staker,
    power,
    whale,

    pub fn multiplier(self: Tier) u64 {
        return switch (self) {
            .free => 10,
            .staker => 15,
            .power => 20,
            .whale => 30,
        };
    }
};

/// Get testnet bootstrap address string
pub fn getBootstrapAddress(allocator: std.mem.Allocator, index: usize) ![]const u8 {
    if (index >= BOOTSTRAP_NODES.len) return error.IndexOutOfBounds;
    const node = BOOTSTRAP_NODES[index];
    return std.fmt.allocPrint(allocator, "{s}:{d}", .{ node.host, node.port });
}

/// Get all bootstrap addresses
pub fn getAllBootstrapAddresses(allocator: std.mem.Allocator) ![][]const u8 {
    var addrs = try std.ArrayList([]const u8).initCapacity(allocator, BOOTSTRAP_NODES.len);
    errdefer {
        for (addrs.items) |a| allocator.free(a);
        addrs.deinit(allocator);
    }

    for (BOOTSTRAP_NODES) |node| {
        const addr = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ node.host, node.port });
        try addrs.append(allocator, addr);
    }

    return addrs.toOwnedSlice(allocator);
}

/// Check if address is testnet bootstrap
pub fn isTestnetBootstrap(host: []const u8, port: u16) bool {
    for (BOOTSTRAP_NODES) |node| {
        if (std.mem.eql(u8, node.host, host) and node.port == port) {
            return true;
        }
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "chain ID is φ-based" {
    // 1.618033988749895... * 10^9 ≈ 1618016180
    try std.testing.expectEqual(@as(u32, 1618016180), CHAIN_ID);
}

test "bootstrap nodes count" {
    try std.testing.expectEqual(@as(usize, 5), BOOTSTRAP_NODES.len);
}

test "reward pool totals 50M" {
    const pool = RewardPool{};
    try std.testing.expectEqual(@as(u64, 50_000_000), pool.total());
}

test "bug bounty rewards" {
    const bounty = BugBounty{};
    try std.testing.expectEqual(@as(u64, 10_000), bounty.getReward(.critical));
    try std.testing.expectEqual(@as(u64, 5_000), bounty.getReward(.major));
    try std.testing.expectEqual(@as(u64, 1_000), bounty.getReward(.minor));
}

test "block reward calculation" {
    // Initial reward
    try std.testing.expectEqual(@as(u64, 1000), calculateBlockReward(0));

    // First halving
    try std.testing.expectEqual(@as(u64, 500), calculateBlockReward(210_000));

    // Second halving
    try std.testing.expectEqual(@as(u64, 250), calculateBlockReward(420_000));
}

test "node reward calculation" {
    // Free tier, 1 hour uptime, 50 jobs
    const reward = calculateNodeReward(1.0, 50, .free);
    try std.testing.expect(reward > 0);

    // Whale tier should earn more
    const whale_reward = calculateNodeReward(1.0, 50, .whale);
    try std.testing.expect(whale_reward > reward);
}

test "tier multipliers" {
    try std.testing.expectEqual(@as(u64, 10), Tier.free.multiplier());
    try std.testing.expectEqual(@as(u64, 15), Tier.staker.multiplier());
    try std.testing.expectEqual(@as(u64, 20), Tier.power.multiplier());
    try std.testing.expectEqual(@as(u64, 30), Tier.whale.multiplier());
}

test "phase durations" {
    try std.testing.expectEqual(@as(u8, 2), TestnetPhase.foundation.durationWeeks());
    try std.testing.expectEqual(@as(u8, 6), TestnetPhase.incentivized.durationWeeks());
    try std.testing.expectEqual(@as(u8, 4), TestnetPhase.stress_test.durationWeeks());
    try std.testing.expectEqual(@as(u8, 0), TestnetPhase.complete.durationWeeks());
}

test "validation targets" {
    const targets = ValidationTargets{};

    // Not met (zero values)
    try std.testing.expect(!targets.isMet(0, 0, 0, 0, 0));

    // Met with minimum values
    try std.testing.expect(targets.isMet(50, 95.0, 1000, 10, 3));

    // Met with exceeded values
    try std.testing.expect(targets.isMet(100, 99.0, 2000, 20, 5));
}

test "bootstrap address formatting" {
    const allocator = std.testing.allocator;

    const addr = try getBootstrapAddress(allocator, 0);
    defer allocator.free(addr);
    try std.testing.expectEqualStrings("bootstrap-us.test.trinity.network:9333", addr);

    const all_addrs = try getAllBootstrapAddresses(allocator);
    defer {
        for (all_addrs) |a| allocator.free(a);
        allocator.free(all_addrs);
    }
    try std.testing.expectEqual(@as(usize, 5), all_addrs.len);
}

test "is testnet bootstrap" {
    try std.testing.expect(isTestnetBootstrap("bootstrap-us.test.trinity.network", 9333));
    try std.testing.expect(isTestnetBootstrap("bootstrap-eu.test.trinity.network", 9333));
    try std.testing.expect(!isTestnetBootstrap("mainnet.trinity.network", 9333));
    try std.testing.expect(!isTestnetBootstrap("bootstrap-us.test.trinity.network", 8080));
}

test "faucet config" {
    try std.testing.expectEqual(@as(u64, 10_000), FAUCET_DRIP_AMOUNT);
    try std.testing.expectEqual(@as(u64, 86_400), FAUCET_RATE_LIMIT_SECONDS);
}

test "tier multipliers match testnet (10x)" {
    try std.testing.expectEqual(@as(f64, 10.0), TIER_MULTIPLIER_FREE);
    try std.testing.expectEqual(@as(f64, 15.0), TIER_MULTIPLIER_STAKER);
    try std.testing.expectEqual(@as(f64, 20.0), TIER_MULTIPLIER_POWER);
    try std.testing.expectEqual(@as(f64, 30.0), TIER_MULTIPLIER_WHALE);
}
