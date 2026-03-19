// @origin(spec:depin_slashing.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// Phase 2: Security Layer - Slashing Engine
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// DEPIN TOKENOMICS CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const REWARD_STORAGE_SHARD_HOUR: u128 = 50_000_000_000_000; // 0.00005 TRI per shard per hour
pub const TRI_PHOENIX_NUMBER: u128 = 10_460_353_203; // 3^21
pub const TRI_TOTAL_SUPPLY: u128 = TRI_PHOENIX_NUMBER * std.math.pow(u128, 10, 18);

// ═══════════════════════════════════════════════════════════════════════════════
// VIOLATION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ViolationType = enum {
    /// Minor - temporary downtime (5% penalty)
    downtime,
    /// Moderate - repeated downtime (10% penalty)
    repeated_downtime,
    /// Severe - extended downtime (20% penalty)
    extended_downtime,
    /// Critical - double-spending (50% penalty)
    double_spend,
    /// Critical - fraud (100% penalty)
    fraud,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SLASH CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════

pub const SlashContext = struct {
    /// Node being slashed
    node_id: []const u8,
    /// Reason for slashing
    violation: ViolationType,
    /// Amount of TRI to slash (in wei, 18 decimals)
    amount: u128,
    /// Timestamp when violation occurred
    timestamp: u64,
    /// Optional additional context
    context: ?[]const u8,

    pub fn deinit(self: *SlashContext, allocator: Allocator) void {
        allocator.free(self.node_id);
        if (self.context) |ctx| allocator.free(ctx);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SLASHING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const SlashingEngine = struct {
    allocator: Allocator,
    /// Violations committed since node registration
    violations: std.ArrayListUnmanaged(SlashContext),
    /// Node stakes indexed by node_id (for full stake slashing)
    node_stakes: std.StringHashMapUnmanaged(u128),

    pub fn init(allocator: Allocator) SlashingEngine {
        return SlashingEngine{
            .allocator = allocator,
            .violations = .{},
            .node_stakes = .{},
        };
    }

    /// Calculate slash amount for a violation
    pub fn calculateSlash(self: *const SlashingEngine, violation: ViolationType, uptime_hours: f64) u128 {
        _ = self; // Self not used for calculation, kept for API consistency
        return switch (violation) {
            .downtime => @as(u128, @intFromFloat(uptime_hours * 60.0)) * REWARD_STORAGE_SHARD_HOUR / 10, // ~5% of hourly rewards
            .repeated_downtime => @as(u128, @intFromFloat(uptime_hours * 60.0)) * REWARD_STORAGE_SHARD_HOUR / 5, // ~10%
            .extended_downtime => @as(u128, @intFromFloat(uptime_hours * 60.0)) * REWARD_STORAGE_SHARD_HOUR * 2 / 5, // ~20%
            .double_spend => TRI_TOTAL_SUPPLY / 2, // 50% of total supply
            .fraud => TRI_TOTAL_SUPPLY, // 100% = full stake
        };
    }

    /// Parse violation type from string
    pub fn parseViolationType(str: []const u8) ?ViolationType {
        if (std.mem.eql(u8, str, "downtime")) return .downtime;
        if (std.mem.eql(u8, str, "repeated_downtime")) return .repeated_downtime;
        if (std.mem.eql(u8, str, "extended_downtime")) return .extended_downtime;
        if (std.mem.eql(u8, str, "double_spend")) return .double_spend;
        if (std.mem.eql(u8, str, "fraud")) return .fraud;
        return null;
    }

    /// Get penalty percentage for a violation type
    pub fn getPenaltyPercentage(violation: ViolationType) f64 {
        return switch (violation) {
            .downtime => 0.05, // 5%
            .repeated_downtime => 0.10, // 10%
            .extended_downtime => 0.20, // 20%
            .double_spend => 0.50, // 50%
            .fraud => 1.00, // 100%
        };
    }

    /// Apply slash to a node
    pub fn slash(self: *SlashingEngine, node_id: []const u8, violation: ViolationType, amount: u128) !void {
        const duped_id = try self.allocator.dupe(u8, node_id);
        errdefer self.allocator.free(duped_id);

        const context = SlashContext{
            .node_id = duped_id,
            .violation = violation,
            .amount = amount,
            .timestamp = @as(u64, @intCast(std.time.timestamp())),
            .context = null,
        };

        try self.violations.append(self.allocator, context);
        std.log.warn("SLASHING: node {s} slashed for {s}: {d} TRI ({d:.2}%)", .{
            node_id,
            @tagName(violation),
            amount,
            getPenaltyPercentage(violation) * 100.0,
        });
    }

    /// Get total slashed amount for a node
    pub fn getTotalSlashed(self: *const SlashingEngine, node_id: []const u8) u128 {
        var total: u128 = 0;
        for (self.violations.items) |ctx| {
            if (std.mem.eql(u8, ctx.node_id, node_id)) {
                total += ctx.amount;
            }
        }
        return total;
    }

    /// Get all violations for a node
    pub fn getNodeViolations(self: *const SlashingEngine, node_id: []const u8, allocator: Allocator) ![]const SlashContext {
        var count: usize = 0;
        for (self.violations.items) |ctx| {
            if (std.mem.eql(u8, ctx.node_id, node_id)) count += 1;
        }

        var result = try allocator.alloc(SlashContext, count);
        var idx: usize = 0;
        for (self.violations.items) |ctx| {
            if (std.mem.eql(u8, ctx.node_id, node_id)) {
                result[idx] = ctx;
                idx += 1;
            }
        }
        return result;
    }

    /// Set node stake for full stake calculation
    pub fn setNodeStake(self: *SlashingEngine, node_id: []const u8, stake: u128) !void {
        const duped_id = try self.allocator.dupe(u8, node_id);
        errdefer self.allocator.free(duped_id);

        try self.node_stakes.put(self.allocator, duped_id, stake);
    }

    /// Get node stake
    pub fn getNodeStake(self: *const SlashingEngine, node_id: []const u8) ?u128 {
        return self.node_stakes.get(node_id);
    }

    pub fn deinit(self: *SlashingEngine) void {
        for (self.violations.items) |*ctx| {
            ctx.deinit(self.allocator);
        }
        self.violations.deinit(self.allocator);

        var stake_iter = self.node_stakes.iterator();
        while (stake_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.node_stakes.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "slash calculation - downtime" {
    const allocator = std.testing.allocator;
    var engine = SlashingEngine.init(allocator);
    defer engine.deinit();

    // Test downtime (5% penalty based on uptime)
    const downtime_amount = engine.calculateSlash(.downtime, 24.0);
    // 24 hours * 60 * 50_000_000_000_000 / 10 = 7.2 TRI for 24h uptime
    try std.testing.expect(downtime_amount > 0);
}

test "slash calculation - fraud" {
    const allocator = std.testing.allocator;
    var engine = SlashingEngine.init(allocator);
    defer engine.deinit();

    // Test fraud (100% penalty = full total supply)
    const fraud_amount = engine.calculateSlash(.fraud, 24.0);
    try std.testing.expectEqual(TRI_TOTAL_SUPPLY, fraud_amount);
}

test "slash calculation - double_spend" {
    const allocator = std.testing.allocator;
    var engine = SlashingEngine.init(allocator);
    defer engine.deinit();

    // Test double-spend (50% penalty)
    const double_spend_amount = engine.calculateSlash(.double_spend, 24.0);
    try std.testing.expectEqual(TRI_TOTAL_SUPPLY / 2, double_spend_amount);
}

test "parse violation type" {
    try std.testing.expectEqual(@as(?ViolationType, .downtime), SlashingEngine.parseViolationType("downtime"));
    try std.testing.expectEqual(@as(?ViolationType, .fraud), SlashingEngine.parseViolationType("fraud"));
    try std.testing.expectEqual(@as(?ViolationType, null), SlashingEngine.parseViolationType("invalid"));
}

test "get penalty percentage" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.05), SlashingEngine.getPenaltyPercentage(.downtime), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.10), SlashingEngine.getPenaltyPercentage(.repeated_downtime), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.20), SlashingEngine.getPenaltyPercentage(.extended_downtime), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.50), SlashingEngine.getPenaltyPercentage(.double_spend), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.00), SlashingEngine.getPenaltyPercentage(.fraud), 0.001);
}

test "apply slash" {
    const allocator = std.testing.allocator;
    var engine = SlashingEngine.init(allocator);
    defer engine.deinit();

    try engine.slash("test-node-123", .downtime, 100_000_000_000_000);

    try std.testing.expectEqual(@as(usize, 1), engine.violations.items.len);
    try std.testing.expectEqual(@as(u128, 100_000_000_000_000), engine.getTotalSlashed("test-node-123"));
}

test "node stake tracking" {
    const allocator = std.testing.allocator;
    var engine = SlashingEngine.init(allocator);
    defer engine.deinit();

    try engine.setNodeStake("rich-node", 1_000_000 * std.math.pow(u128, 10, 18));
    const stake = engine.getNodeStake("rich-node");

    try std.testing.expect(stake != null);
    try std.testing.expectEqual(@as(u128, 1_000_000) * std.math.pow(u128, 10, 18), stake.?);
}
