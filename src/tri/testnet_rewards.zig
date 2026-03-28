// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY TESTNET REWARDS TRACKING — Leaderboard & Reward Distribution
// Tracks node operator rewards, bug bounties, community testers
// φ² + 1/φ² = 3 | TESTNET PHASE 1
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testnet_config = @import("testnet_config.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardType = enum(u8) {
    /// Node operator reward (uptime + jobs)
    node_operator = 0,
    /// Bug bounty reward
    bug_bounty = 1,
    /// Community tester reward
    community_tester = 2,
    /// Early adopter bonus
    early_adopter = 3,
    /// Referral bonus
    referral = 4,

    pub fn toString(self: RewardType) []const u8 {
        return switch (self) {
            .node_operator => "node_operator",
            .bug_bounty => "bug_bounty",
            .community_tester => "community_tester",
            .early_adopter => "early_adopter",
            .referral => "referral",
        };
    }

    pub fn fromString(str: []const u8) ?RewardType {
        if (std.mem.eql(u8, str, "node_operator")) return .node_operator;
        if (std.mem.eql(u8, str, "bug_bounty")) return .bug_bounty;
        if (std.mem.eql(u8, str, "community_tester")) return .community_tester;
        if (std.mem.eql(u8, str, "early_adopter")) return .early_adopter;
        if (std.mem.eql(u8, str, "referral")) return .referral;
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD ENTRY — Single reward record
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardEntry = struct {
    /// Unique reward ID
    id: []const u8,
    /// Recipient address
    address: []const u8,
    /// Reward type
    reward_type: RewardType,
    /// Amount in test $TRI
    amount: u64,
    /// Timestamp awarded
    timestamp: u64,
    /// Vesting timestamp (0 = immediately vested)
    vesting_timestamp: u64,
    /// Whether claimed
    claimed: bool,
    /// Claim timestamp (0 = not claimed)
    claimed_timestamp: u64,
    /// Associated issue/bug ID (for bug bounties)
    reference_id: ?[]const u8 = null,
    /// Metadata (JSON string)
    metadata: ?[]const u8 = null,

    pub fn isVested(self: RewardEntry) bool {
        if (self.vesting_timestamp == 0) return true;
        const now = @as(u64, @intCast(std.time.timestamp()));
        return now >= self.vesting_timestamp;
    }

    pub fn canClaim(self: RewardEntry) bool {
        return !self.claimed and self.isVested();
    }

    pub fn timeUntilVesting(self: RewardEntry) ?u64 {
        if (self.vesting_timestamp == 0) return null;
        const now = @as(u64, @intCast(std.time.timestamp()));
        if (now >= self.vesting_timestamp) return null;
        return self.vesting_timestamp - now;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE REWARD ENTRY — Node operator specific tracking
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeRewardEntry = struct {
    /// Node ID
    node_id: []const u8,
    /// Wallet address
    address: []const u8,
    /// Total uptime (hours)
    uptime_hours: f64,
    /// Total jobs completed
    jobs_completed: usize,
    /// Total tokens processed
    tokens_processed: u64,
    /// Total rewards earned
    total_rewards: u64,
    /// Pending (unclaimed) rewards
    pending_rewards: u64,
    /// Tier
    tier: testnet_config.Tier,
    /// Quality score (0.0-1.0)
    quality_score: f64,
    /// First seen timestamp
    first_seen: u64,
    /// Last active timestamp
    last_active: u64,
    /// Reward entries
    rewards: std.ArrayListUnmanaged(RewardEntry),

    pub fn init(allocator: std.mem.Allocator, node_id: []const u8, address: []const u8) NodeRewardEntry {
        return NodeRewardEntry{
            .node_id = allocator.dupe(u8, node_id) catch unreachable,
            .address = allocator.dupe(u8, address) catch unreachable,
            .uptime_hours = 0,
            .jobs_completed = 0,
            .tokens_processed = 0,
            .total_rewards = 0,
            .pending_rewards = 0,
            .tier = .free,
            .quality_score = 1.0,
            .first_seen = @as(u64, @intCast(std.time.timestamp())),
            .last_active = @as(u64, @intCast(std.time.timestamp())),
            .rewards = .{},
        };
    }

    pub fn deinit(self: *NodeRewardEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.node_id);
        allocator.free(self.address);
        for (self.rewards.items) |*r| {
            allocator.free(r.id);
            allocator.free(r.address);
            if (r.reference_id) |ref| allocator.free(ref);
            if (r.metadata) |meta| allocator.free(meta);
        }
        self.rewards.deinit(allocator);
    }

    /// Calculate reward rate (TRI per hour)
    pub fn rewardRate(self: NodeRewardEntry) f64 {
        if (self.uptime_hours <= 0) return 0;
        return @as(f64, @floatFromInt(self.total_rewards)) / self.uptime_hours;
    }

    /// Update uptime and recalculate rewards
    pub fn updateUptime(self: *NodeRewardEntry, additional_hours: f64, allocator: std.mem.Allocator) !void {
        self.uptime_hours += additional_hours;
        self.last_active = @as(u64, @intCast(std.time.timestamp()));

        // Calculate reward for this period
        const reward = testnet_config.calculateNodeReward(
            self.uptime_hours,
            self.jobs_completed,
            self.tier,
        );

        if (reward > 0) {
            const entry = RewardEntry{
                .id = try std.fmt.allocPrint(allocator, "reward-{d}-{d}", .{
                    @as(u64, @intCast(std.time.timestamp())),
                    self.rewards.items.len,
                }),
                .address = try allocator.dupe(u8, self.address),
                .reward_type = .node_operator,
                .amount = reward,
                .timestamp = @as(u64, @intCast(std.time.timestamp())),
                .vesting_timestamp = 0, // Testnet rewards vest immediately
                .claimed = false,
                .claimed_timestamp = 0,
            };

            try self.rewards.append(allocator, entry);
            self.total_rewards += reward;
            self.pending_rewards += reward;
        }
    }

    /// Add job completion
    pub fn addJob(self: *NodeRewardEntry, tokens_processed: u64) void {
        self.jobs_completed += 1;
        self.tokens_processed += tokens_processed;
        self.last_active = @as(u64, @intCast(std.time.timestamp()));
    }

    /// Update quality score
    pub fn updateQuality(self: *NodeRewardEntry, success: bool, latency_ms: u64) void {
        const latency_bonus: f64 = if (latency_ms < 100)
            0.05
        else if (latency_ms < 500)
            0.02
        else
            0;

        if (success) {
            self.quality_score = @min(1.0, self.quality_score + 0.01 + latency_bonus);
        } else {
            self.quality_score = @max(0.0, self.quality_score - 0.1);
        }
    }

    /// Check if node is healthy (active in last hour)
    pub fn isHealthy(self: NodeRewardEntry) bool {
        const now = @as(u64, @intCast(std.time.timestamp()));
        const seconds_since_active = now - self.last_active;
        return seconds_since_active < 3600;
    }

    /// Get leaderboard score
    pub fn leaderboardScore(self: NodeRewardEntry) f64 {
        const uptime_weight = 0.4;
        const job_weight = 0.3;
        const quality_weight = 0.3;

        const uptime_score = @min(1.0, self.uptime_hours / 168.0); // Normalize to 1 week
        const job_score = @min(1.0, @as(f64, @floatFromInt(self.jobs_completed)) / 100.0);

        return uptime_score * uptime_weight +
            job_score * job_weight +
            self.quality_score * quality_weight;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BUG BOUNTY ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const BugBountyEntry = struct {
    /// Bug ID (GitHub issue number)
    bug_id: []const u8,
    /// Reporter address
    reporter: []const u8,
    /// Severity
    severity: testnet_config.BugBounty.Severity,
    /// Title
    title: []const u8,
    /// Description
    description: []const u8,
    /// Reward amount
    reward: u64,
    /// Awarded timestamp
    awarded_at: u64,
    /// Claimed
    claimed: bool,
    /// Status
    status: BugStatus,

    pub const BugStatus = enum(u8) {
        submitted,
        verified,
        paid,
        rejected,

        pub fn toString(self: BugStatus) []const u8 {
            return switch (self) {
                .submitted => "submitted",
                .verified => "verified",
                .paid => "paid",
                .rejected => "rejected",
            };
        }
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARDS MANAGER — Main rewards tracking
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardsManager = struct {
    allocator: std.mem.Allocator,
    /// Map: node_id -> NodeRewardEntry
    node_rewards: std.StringHashMapUnmanaged(NodeRewardEntry),
    /// Bug bounties
    bug_bounties: std.ArrayListUnmanaged(BugBountyEntry),
    /// Reward pool
    pool: testnet_config.RewardPool,
    /// Total dispensed
    total_dispensed: u64,
    /// Testnet start timestamp
    testnet_start: u64,

    pub fn init(allocator: std.mem.Allocator) RewardsManager {
        return RewardsManager{
            .allocator = allocator,
            .node_rewards = .{},
            .bug_bounties = .{},
            .pool = .{},
            .total_dispensed = 0,
            .testnet_start = @as(u64, @intCast(std.time.timestamp())),
        };
    }

    pub fn deinit(self: *RewardsManager) void {
        var node_iter = self.node_rewards.iterator();
        while (node_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.node_rewards.deinit(self.allocator);

        for (self.bug_bounties.items) |*bounty| {
            self.allocator.free(bounty.bug_id);
            self.allocator.free(bounty.reporter);
            self.allocator.free(bounty.title);
            self.allocator.free(bounty.description);
        }
        self.bug_bounties.deinit(self.allocator);
    }

    /// Register a node for rewards tracking
    pub fn registerNode(self: *RewardsManager, node_id: []const u8, address: []const u8) !void {
        // Check if already registered
        if (self.node_rewards.get(node_id) != null) return error.NodeAlreadyRegistered;

        // For StringHashMapUnmanaged, we need to dupe the key
        const node_id_copy = try self.allocator.dupe(u8, node_id);
        errdefer self.allocator.free(node_id_copy);

        // Initialize the entry with its own copy of node_id (separate from HashMap key)
        const entry = NodeRewardEntry.init(self.allocator, node_id, address);

        // Insert into HashMap (HashMap owns node_id_copy now)
        try self.node_rewards.put(self.allocator, node_id_copy, entry);
    }

    /// Record node activity
    pub fn recordNodeActivity(
        self: *RewardsManager,
        node_id: []const u8,
        uptime_hours: f64,
        jobs_completed: usize,
        quality_score: f64,
    ) !void {
        const entry = self.node_rewards.getPtr(node_id) orelse return error.NodeNotFound;

        const old_rewards = entry.total_rewards;
        try entry.updateUptime(uptime_hours, self.allocator);
        entry.jobs_completed += jobs_completed;
        entry.quality_score = quality_score;

        // Update pool tracking
        const new_rewards = entry.total_rewards - old_rewards;
        self.total_dispensed += new_rewards;
    }

    /// Add bug bounty
    pub fn addBugBounty(
        self: *RewardsManager,
        bug_id: []const u8,
        reporter: []const u8,
        severity: testnet_config.BugBounty.Severity,
        title: []const u8,
        description: []const u8,
    ) !void {
        const bounty = testnet_config.BugBounty{};
        const reward = bounty.getReward(severity);

        const entry = BugBountyEntry{
            .bug_id = try self.allocator.dupe(u8, bug_id),
            .reporter = try self.allocator.dupe(u8, reporter),
            .severity = severity,
            .title = try self.allocator.dupe(u8, title),
            .description = try self.allocator.dupe(u8, description),
            .reward = reward,
            .awarded_at = @as(u64, @intCast(std.time.timestamp())),
            .claimed = false,
            .status = .verified,
        };

        try self.bug_bounties.append(self.allocator, entry);
        self.total_dispensed += reward;
    }

    /// Get leaderboard (top N nodes by score)
    pub fn getLeaderboard(self: *RewardsManager, limit: usize) ![]LeaderboardEntry {
        var entries = try std.ArrayList(LeaderboardEntry).initCapacity(self.allocator, self.node_rewards.count());

        var iter = self.node_rewards.iterator();
        while (iter.next()) |node| {
            const entry = LeaderboardEntry{
                .node_id = node.key_ptr.*,
                .address = node.value_ptr.address,
                .score = node.value_ptr.leaderboardScore(),
                .total_rewards = node.value_ptr.total_rewards,
                .uptime_hours = node.value_ptr.uptime_hours,
                .jobs_completed = node.value_ptr.jobs_completed,
                .quality_score = node.value_ptr.quality_score,
                .tier = node.value_ptr.tier,
            };
            try entries.append(self.allocator, entry);
        }

        // Sort by score descending
        std.sort.block(LeaderboardEntry, entries.items, {}, compareScoreDesc);

        // Limit results
        if (entries.items.len > limit) {
            entries.shrinkRetainingCapacity(limit);
        }

        return entries.toOwnedSlice(self.allocator);
    }

    /// Get rewards for address
    pub fn getRewardsForAddress(self: *RewardsManager, address: []const u8) ![]RewardEntry {
        var rewards = try std.ArrayList(RewardEntry).initCapacity(self.allocator, 32);

        var iter = self.node_rewards.iterator();
        while (iter.next()) |node| {
            if (std.mem.eql(u8, node.value_ptr.address, address)) {
                for (node.value_ptr.rewards.items) |reward| {
                    try rewards.append(self.allocator, reward);
                }
            }
        }

        // Also check bug bounties
        for (self.bug_bounties.items) |bounty| {
            if (std.mem.eql(u8, bounty.reporter, address)) {
                const entry = RewardEntry{
                    .id = try self.allocator.dupe(u8, bounty.bug_id),
                    .address = try self.allocator.dupe(u8, bounty.reporter),
                    .reward_type = .bug_bounty,
                    .amount = bounty.reward,
                    .timestamp = bounty.awarded_at,
                    .vesting_timestamp = 0,
                    .claimed = bounty.claimed,
                    .claimed_timestamp = 0,
                    .reference_id = try self.allocator.dupe(u8, bounty.bug_id),
                    .metadata = try std.fmt.allocPrint(self.allocator,
                        \\"severity":"{s}","title":"{s}"**
                    , .{ @tagName(bounty.severity), bounty.title }),
                };
                try rewards.append(self.allocator, entry);
            }
        }

        return rewards.toOwnedSlice(self.allocator);
    }

    /// Get statistics
    pub fn getStats(self: *const RewardsManager) RewardsStats {
        return RewardsStats{
            .total_nodes = self.node_rewards.count(),
            .active_nodes = blk: {
                var count: usize = 0;
                var iter = self.node_rewards.iterator();
                while (iter.next()) |node| {
                    if (node.value_ptr.isHealthy()) count += 1;
                }
                break :blk count;
            },
            .total_rewards_dispensed = self.total_dispensed,
            .remaining_pool = self.pool.total() - self.total_dispensed,
            .bug_bounties_paid = self.bug_bounties.items.len,
            .testnet_duration_hours = (@as(u64, @intCast(std.time.timestamp())) - self.testnet_start) / 3600,
        };
    }

    /// Export to JSON
    pub fn exportToJson(self: *RewardsManager) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);

        try buffer.appendSlice(self.allocator, "{");

        // Add stats
        const stats = self.getStats();
        try buffer.appendSlice(self.allocator, "\"stats\":{");
        try buffer.writer(self.allocator).print("{d}", .{stats.total_nodes});
        try buffer.appendSlice(self.allocator, ",\"active_nodes\":");
        try buffer.writer(self.allocator).print("{d}", .{stats.active_nodes});
        try buffer.appendSlice(self.allocator, ",\"total_rewards\":");
        try buffer.writer(self.allocator).print("{d}", .{stats.total_rewards_dispensed});
        try buffer.appendSlice(self.allocator, "}");

        try buffer.appendSlice(self.allocator, "}");

        return buffer.toOwnedSlice(self.allocator);
    }
};

pub const LeaderboardEntry = struct {
    node_id: []const u8,
    address: []const u8,
    score: f64,
    total_rewards: u64,
    uptime_hours: f64,
    jobs_completed: usize,
    quality_score: f64,
    tier: testnet_config.Tier,
};

pub const RewardsStats = struct {
    total_nodes: usize,
    active_nodes: usize,
    total_rewards_dispensed: u64,
    remaining_pool: u64,
    bug_bounties_paid: usize,
    testnet_duration_hours: u64,
};

fn compareScoreDesc(context: void, a: LeaderboardEntry, b: LeaderboardEntry) bool {
    _ = context;
    return a.score > b.score;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RewardType toString/fromString" {
    try std.testing.expectEqualStrings("node_operator", @tagName(.node_operator));
    try std.testing.expectEqualStrings("bug_bounty", @tagName(.bug_bounty));

    try std.testing.expectEqual(.node_operator, RewardType.fromString("node_operator").?);
    try std.testing.expect(RewardType.fromString("invalid") == null);
}

test "RewardEntry vesting" {
    const now = @as(u64, @intCast(std.time.timestamp()));

    var entry = RewardEntry{
        .id = "test",
        .address = "0x123",
        .reward_type = .node_operator,
        .amount = 1000,
        .timestamp = now,
        .vesting_timestamp = 0,
        .claimed = false,
        .claimed_timestamp = 0,
    };

    try std.testing.expect(entry.isVested());
    try std.testing.expect(entry.canClaim());
    try std.testing.expect(entry.timeUntilVesting() == null);

    entry.vesting_timestamp = now + 3600;
    try std.testing.expect(!entry.isVested());
    try std.testing.expect(!entry.canClaim());
    try std.testing.expect(entry.timeUntilVesting() != null);
}

test "NodeRewardEntry init" {
    const allocator = std.testing.allocator;
    var entry = NodeRewardEntry.init(allocator, "node-1", "0x123");
    defer entry.deinit(allocator);

    try std.testing.expectEqualStrings("node-1", entry.node_id);
    try std.testing.expectEqual(@as(usize, 0), entry.jobs_completed);
    try std.testing.expectEqual(@as(u64, 0), entry.total_rewards);
}

test "NodeRewardEntry addJob" {
    const allocator = std.testing.allocator;
    var entry = NodeRewardEntry.init(allocator, "node-1", "0x123");
    defer entry.deinit(allocator);

    entry.addJob(1000);
    try std.testing.expectEqual(@as(usize, 1), entry.jobs_completed);
    try std.testing.expectEqual(@as(u64, 1000), entry.tokens_processed);

    entry.addJob(500);
    try std.testing.expectEqual(@as(usize, 2), entry.jobs_completed);
    try std.testing.expectEqual(@as(u64, 1500), entry.tokens_processed);
}

test "NodeRewardEntry updateQuality" {
    const allocator = std.testing.allocator;
    var entry = NodeRewardEntry.init(allocator, "node-1", "0x123");
    defer entry.deinit(allocator);

    // First, reduce quality score so we can test increase
    entry.quality_score = 0.8;
    const initial = entry.quality_score;

    entry.updateQuality(true, 50);
    try std.testing.expect(entry.quality_score > initial);

    const before = entry.quality_score;
    entry.updateQuality(false, 1000);
    try std.testing.expect(entry.quality_score < before);
}

test "NodeRewardEntry isHealthy" {
    const allocator = std.testing.allocator;
    var entry = NodeRewardEntry.init(allocator, "node-1", "0x123");
    defer entry.deinit(allocator);

    try std.testing.expect(entry.isHealthy());

    entry.last_active = @as(u64, @intCast(std.time.timestamp())) - 7200;
    try std.testing.expect(!entry.isHealthy());
}

test "NodeRewardEntry leaderboardScore" {
    const allocator = std.testing.allocator;
    var entry = NodeRewardEntry.init(allocator, "node-1", "0x123");
    defer entry.deinit(allocator);

    const initial = entry.leaderboardScore();

    entry.uptime_hours = 168; // 1 week
    entry.jobs_completed = 100;
    entry.quality_score = 1.0;

    const final = entry.leaderboardScore();
    try std.testing.expect(final > initial);
}

test "RewardsManager init" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.node_rewards.count());
    try std.testing.expectEqual(@as(usize, 0), manager.bug_bounties.items.len);
}

test "RewardsManager registerNode" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.registerNode("node-1", "0x123");

    try std.testing.expectEqual(@as(usize, 1), manager.node_rewards.count());

    const entry = manager.node_rewards.get("node-1").?;
    try std.testing.expectEqualStrings("0x123", entry.address);
}

test "RewardsManager registerNode duplicate" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.registerNode("node-1", "0x123");
    const err = manager.registerNode("node-1", "0x456");
    try std.testing.expectError(error.NodeAlreadyRegistered, err);
}

test "RewardsManager recordNodeActivity" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.registerNode("node-1", "0x123");
    try manager.recordNodeActivity("node-1", 10.0, 50, 0.9);

    const entry = manager.node_rewards.get("node-1").?;
    try std.testing.expectEqual(@as(usize, 50), entry.jobs_completed);
}

test "RewardsManager getLeaderboard" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.registerNode("node-1", "0x123");
    try manager.registerNode("node-2", "0x456");

    const leaderboard = try manager.getLeaderboard(10);
    defer allocator.free(leaderboard);

    try std.testing.expectEqual(@as(usize, 2), leaderboard.len);
}

test "RewardsManager getStats" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.registerNode("node-1", "0x123");

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_nodes);
    try std.testing.expect(stats.remaining_pool > 0);
}

test "RewardsManager addBugBounty" {
    const allocator = std.testing.allocator;
    var manager = RewardsManager.init(allocator);
    defer manager.deinit();

    try manager.addBugBounty(
        "issue-1",
        "0x123",
        .minor,
        "Test bug",
        "This is a test bug",
    );

    try std.testing.expectEqual(@as(usize, 1), manager.bug_bounties.items.len);

    const bounty = &manager.bug_bounties.items[0];
    try std.testing.expectEqual(@as(u64, 1000), bounty.reward); // minor bounty
}

test "BugBounty severity rewards" {
    const bounty = testnet_config.BugBounty{};

    try std.testing.expectEqual(@as(u64, 10_000), bounty.getReward(.critical));
    try std.testing.expectEqual(@as(u64, 5_000), bounty.getReward(.major));
    try std.testing.expectEqual(@as(u64, 1_000), bounty.getReward(.minor));
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRYPOINT — testnet-rewards executable
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: testnet-rewards <command>", .{});
        std.log.err("Commands:", .{});
        std.log.err("  leaderboard <n>    - Get top n nodes (default: 50)", .{});
        std.log.err("  register <node> <addr>  - Register a node for rewards", .{});
        std.log.err("  stats               - Get reward statistics", .{});
        std.log.err("  claim <address>      - Claim rewards for address", .{});
        std.process.exit(1);
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "leaderboard")) {
        const n = if (args.len > 2)
            try std.fmt.parseInt(usize, args[2], 10)
        else
            50;

        var manager = RewardsManager.init(allocator);
        defer manager.deinit();

        const leaderboard = try manager.getLeaderboard(n);
        defer {
            for (leaderboard) |entry| {
                allocator.free(entry.node_id);
            }
            allocator.free(leaderboard);
        }

        std.log.info("Leaderboard (top {d}):", .{leaderboard.len});
        for (leaderboard, 0..) |entry, i| {
            std.log.info("  {d}. {s} - {d} $TRI ({d:.2} score)", .{ i + 1, entry.node_id[0..@min(20, entry.node_id.len)], entry.total_rewards, entry.score });
        }
    } else if (std.mem.eql(u8, command, "register")) {
        if (args.len < 4) {
            std.log.err("Usage: testnet-rewards register <node_id> <address>", .{});
            std.process.exit(1);
        }

        const node_id = args[2];
        const address = args[3];

        var manager = RewardsManager.init(allocator);
        defer manager.deinit();

        try manager.registerNode(node_id, address);
        std.log.info("Registered node {s} with address {s}", .{ node_id, address });
    } else if (std.mem.eql(u8, command, "stats")) {
        var manager = RewardsManager.init(allocator);
        defer manager.deinit();

        const stats = manager.getStats();
        std.log.info("Reward Statistics:", .{});
        std.log.info("  Total nodes: {d}", .{stats.total_nodes});
        std.log.info("  Active nodes: {d}", .{stats.active_nodes});
        std.log.info("  Total dispensed: {d} $TRI", .{stats.total_rewards_dispensed});
        std.log.info("  Remaining pool: {d} $TRI", .{stats.remaining_pool});
        std.log.info("  Bug bounties: {d}", .{stats.bug_bounties_paid});
    } else if (std.mem.eql(u8, command, "claim")) {
        if (args.len < 3) {
            std.log.err("Usage: testnet-rewards claim <address>", .{});
            std.process.exit(1);
        }

        const address = args[2];

        var manager = RewardsManager.init(allocator);
        defer manager.deinit();

        const rewards = try manager.getRewardsForAddress(address);
        defer {
            for (rewards) |*r| {
                allocator.free(r.id);
                allocator.free(r.address);
                if (r.reference_id) |ref| allocator.free(ref);
                if (r.metadata) |meta| allocator.free(meta);
            }
            allocator.free(rewards);
        }

        var claimable: u64 = 0;
        for (rewards) |r| {
            if (r.canClaim()) claimable += r.amount;
        }

        std.log.info("Claimable rewards for {s}: {d} $TRI", .{ address, claimable });
    } else {
        std.log.err("Unknown command: {s}", .{command});
        std.process.exit(1);
    }
}
