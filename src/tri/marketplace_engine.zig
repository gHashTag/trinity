// ═══════════════════════════════════════════════════════════════════════════════
// marketplace_engine.zig — $TRI Sacred Computation Marketplace Engine
// Generated from: specs/tri/tri_marketplace.vibee v3.1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes marketplace data for API consumption:
//   - Dashboard stats (tokenomics, top computations)
//   - Staking tiers (Fibonacci × phi multipliers)
//   - Proof-of-computation validation (accuracy tiers)
//   - Tokenomics model (phi-deflation schedule)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = 2.6180339887498948482;
const PHI_INV_SQ: f64 = 0.3819660112501051518;
const MU: f64 = 0.0382; // Inflation rate
const CHI: f64 = 0.0618; // Deflation rate

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const StakingTier = struct {
    tier: u8,
    stake_amount: u32,
    multiplier: f64,
    annual_yield_pct: f64,
    lock_days: u32,
};

pub const AccuracyTier = struct {
    name: []const u8,
    max_error_pct: f64,
    reward_multiplier: f64,
    label: []const u8,
};

pub const TopComputation = struct {
    rank: u8,
    formula: []const u8,
    accuracy_pct: f64,
    reward_phi_power: u8,
    reward_value: f64,
};

pub const TokenomicsEpoch = struct {
    epoch: u32,
    supply: f64,
    inflation: f64,
    staked_pct: f64,
    burned: f64,
    net_change: f64,
};

pub const DashboardStats = struct {
    network_active: bool,
    total_constants: u32,
    verify_passing: u32,
    verify_total: u32,
    formula_fits: u32,
    exact_fits: u32,
    total_supply: f64,
    circulating: f64,
    staked: f64,
    inflation_rate: f64,
    deflation_rate: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Computation Functions
// ═══════════════════════════════════════════════════════════════════════════════

pub fn computeDashboard() DashboardStats {
    return .{
        .network_active = true,
        .total_constants = 145,
        .verify_passing = 38,
        .verify_total = 38,
        .formula_fits = 18,
        .exact_fits = 4,
        .total_supply = 999999.0,
        .circulating = 618033.0,
        .staked = 381966.0,
        .inflation_rate = MU,
        .deflation_rate = CHI,
    };
}

pub fn computeStakingTiers(allocator: Allocator) ![]StakingTier {
    var result: std.ArrayListUnmanaged(StakingTier) = .{};
    const fib_stakes = [_]u32{ 3, 5, 8, 13, 21, 34, 55, 89, 144, 233 };
    var tier: u8 = 0;
    while (tier < 10) : (tier += 1) {
        const mult = std.math.pow(f64, PHI, @as(f64, @floatFromInt(tier)));
        const yield_pct = mult * MU * 100.0 * 12.0;
        const lock = (@as(u32, tier) + 1) * 3;
        try result.append(allocator, .{
            .tier = tier,
            .stake_amount = fib_stakes[tier],
            .multiplier = mult,
            .annual_yield_pct = yield_pct,
            .lock_days = lock,
        });
    }
    return result.toOwnedSlice(allocator);
}

pub fn getAccuracyTiers(allocator: Allocator) ![]AccuracyTier {
    var result: std.ArrayListUnmanaged(AccuracyTier) = .{};
    try result.append(allocator, .{ .name = "EXACT", .max_error_pct = 0.01, .reward_multiplier = std.math.pow(f64, PHI, 4.0), .label = "Sacred Fit" });
    try result.append(allocator, .{ .name = "CLOSE", .max_error_pct = 0.1, .reward_multiplier = PHI_SQ, .label = "Golden Fit" });
    try result.append(allocator, .{ .name = "NEAR", .max_error_pct = 1.0, .reward_multiplier = PHI, .label = "Silver Fit" });
    try result.append(allocator, .{ .name = "APPROXIMATE", .max_error_pct = 5.0, .reward_multiplier = 1.0, .label = "Bronze Fit" });
    try result.append(allocator, .{ .name = "REJECTED", .max_error_pct = 100.0, .reward_multiplier = 0.0, .label = "No Reward" });
    return result.toOwnedSlice(allocator);
}

pub fn computeTopComputations(allocator: Allocator) ![]TopComputation {
    var result: std.ArrayListUnmanaged(TopComputation) = .{};
    try result.append(allocator, .{ .rank = 1, .formula = "m_tau/m_e = 4*3^3*pi^3*phi^-2*e", .accuracy_pct = 0.0002, .reward_phi_power = 4, .reward_value = std.math.pow(f64, PHI, 4.0) });
    try result.append(allocator, .{ .rank = 2, .formula = "CHSH = 8*3^4*pi^-3", .accuracy_pct = 0.0020, .reward_phi_power = 3, .reward_value = std.math.pow(f64, PHI, 3.0) });
    try result.append(allocator, .{ .rank = 3, .formula = "gamma_BI = 7*3^-3*pi^2*e^-3", .accuracy_pct = 0.0082, .reward_phi_power = 3, .reward_value = std.math.pow(f64, PHI, 3.0) });
    try result.append(allocator, .{ .rank = 4, .formula = "Age = 1*3^4*pi^-2*phi^-1*e", .accuracy_pct = 0.0051, .reward_phi_power = 3, .reward_value = std.math.pow(f64, PHI, 3.0) });
    try result.append(allocator, .{ .rank = 5, .formula = "1/alpha sacred formula", .accuracy_pct = 0.0002, .reward_phi_power = 4, .reward_value = std.math.pow(f64, PHI, 4.0) });
    return result.toOwnedSlice(allocator);
}

pub fn computeTokenomicsSchedule(allocator: Allocator, epochs: u32) ![]TokenomicsEpoch {
    var result: std.ArrayListUnmanaged(TokenomicsEpoch) = .{};
    var supply: f64 = 999999.0;
    var staked_pct: f64 = 38.2;
    var epoch: u32 = 0;
    while (epoch < epochs) : (epoch += 1) {
        const inflation = supply * MU / 12.0;
        const burned = supply * CHI / 12.0 * (staked_pct / 100.0);
        const net = inflation - burned;
        try result.append(allocator, .{
            .epoch = epoch,
            .supply = supply,
            .inflation = inflation,
            .staked_pct = staked_pct,
            .burned = burned,
            .net_change = net,
        });
        supply += net;
        staked_pct = @min(61.8, staked_pct + 0.5);
    }
    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

pub fn marketplaceToJson(allocator: Allocator, mode_str: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    const trinity = PHI_SQ + PHI_INV_SQ;
    try w.writeAll("{");
    try std.fmt.format(w, "\"mode\":\"{s}\",\"trinity_check\":{d:.6}", .{ mode_str, trinity });

    if (std.mem.eql(u8, mode_str, "dashboard")) {
        const stats = computeDashboard();
        try std.fmt.format(w, ",\"dashboard\":{{\"network_active\":{},\"total_constants\":{d},\"verify_passing\":{d},\"verify_total\":{d},\"formula_fits\":{d},\"exact_fits\":{d},\"total_supply\":{d:.0},\"circulating\":{d:.0},\"staked\":{d:.0},\"inflation_rate\":{d:.4},\"deflation_rate\":{d:.4}}}", .{
            stats.network_active, stats.total_constants, stats.verify_passing, stats.verify_total, stats.formula_fits, stats.exact_fits, stats.total_supply, stats.circulating, stats.staked, stats.inflation_rate, stats.deflation_rate,
        });

        const top = try computeTopComputations(allocator);
        defer allocator.free(top);
        try w.writeAll(",\"top_computations\":[");
        for (top, 0..) |c, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"rank\":{d},\"formula\":\"{s}\",\"accuracy_pct\":{d:.4},\"reward_phi_power\":{d},\"reward_value\":{d:.4}}}", .{
                c.rank, c.formula, c.accuracy_pct, c.reward_phi_power, c.reward_value,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "staking")) {
        const tiers = try computeStakingTiers(allocator);
        defer allocator.free(tiers);
        try w.writeAll(",\"staking_tiers\":[");
        for (tiers, 0..) |t, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"tier\":{d},\"stake_amount\":{d},\"multiplier\":{d:.4},\"annual_yield_pct\":{d:.2},\"lock_days\":{d}}}", .{
                t.tier, t.stake_amount, t.multiplier, t.annual_yield_pct, t.lock_days,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "proof")) {
        const tiers = try getAccuracyTiers(allocator);
        defer allocator.free(tiers);
        try w.writeAll(",\"accuracy_tiers\":[");
        for (tiers, 0..) |t, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"name\":\"{s}\",\"max_error_pct\":{d:.2},\"reward_multiplier\":{d:.4},\"label\":\"{s}\"}}", .{
                t.name, t.max_error_pct, t.reward_multiplier, t.label,
            });
        }
        try w.writeAll("]");
        try w.writeAll(",\"difficulty_base\":27,\"difficulty_formula\":\"27^tier\"");
    } else if (std.mem.eql(u8, mode_str, "tokenomics")) {
        const schedule = try computeTokenomicsSchedule(allocator, 12);
        defer allocator.free(schedule);
        try w.writeAll(",\"tokenomics\":[");
        for (schedule, 0..) |e, idx| {
            if (idx > 0) try w.writeAll(",");
            try std.fmt.format(w, "{{\"epoch\":{d},\"supply\":{d:.0},\"inflation\":{d:.1},\"staked_pct\":{d:.1},\"burned\":{d:.1},\"net_change\":{d:.1}}}", .{
                e.epoch, e.supply, e.inflation, e.staked_pct, e.burned, e.net_change,
            });
        }
        try w.writeAll("]");
    } else {
        try w.writeAll(",\"modes\":[\"dashboard\",\"staking\",\"proof\",\"tokenomics\"]");
    }

    try w.writeAll("}");
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity" {
    const trinity = PHI_SQ + PHI_INV_SQ;
    try std.testing.expectApproxEqAbs(trinity, 3.0, 0.0001);
}

test "dashboard stats" {
    const stats = computeDashboard();
    try std.testing.expect(stats.network_active);
    try std.testing.expectEqual(@as(u32, 145), stats.total_constants);
    try std.testing.expectApproxEqAbs(@as(f64, 999999.0), stats.total_supply, 1.0);
}

test "staking tiers" {
    const allocator = std.testing.allocator;
    const tiers = try computeStakingTiers(allocator);
    defer allocator.free(tiers);
    try std.testing.expectEqual(@as(usize, 10), tiers.len);
    try std.testing.expectEqual(@as(u32, 3), tiers[0].stake_amount);
    try std.testing.expectEqual(@as(u32, 233), tiers[9].stake_amount);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), tiers[0].multiplier, 0.01);
    try std.testing.expect(tiers[9].multiplier > tiers[0].multiplier);
}

test "accuracy tiers" {
    const allocator = std.testing.allocator;
    const tiers = try getAccuracyTiers(allocator);
    defer allocator.free(tiers);
    try std.testing.expectEqual(@as(usize, 5), tiers.len);
    try std.testing.expectEqualStrings("EXACT", tiers[0].name);
    try std.testing.expectEqualStrings("REJECTED", tiers[4].name);
}

test "top computations" {
    const allocator = std.testing.allocator;
    const top = try computeTopComputations(allocator);
    defer allocator.free(top);
    try std.testing.expectEqual(@as(usize, 5), top.len);
    try std.testing.expectEqual(@as(u8, 1), top[0].rank);
}

test "tokenomics schedule" {
    const allocator = std.testing.allocator;
    const schedule = try computeTokenomicsSchedule(allocator, 12);
    defer allocator.free(schedule);
    try std.testing.expectEqual(@as(usize, 12), schedule.len);
    try std.testing.expectApproxEqAbs(@as(f64, 999999.0), schedule[0].supply, 1.0);
}

test "dashboard json output" {
    const allocator = std.testing.allocator;
    const json = try marketplaceToJson(allocator, "dashboard");
    defer allocator.free(json);
    try std.testing.expect(json.len > 100);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"dashboard\":{") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"top_computations\":[") != null);
}

test "staking json output" {
    const allocator = std.testing.allocator;
    const json = try marketplaceToJson(allocator, "staking");
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"staking_tiers\":[") != null);
}
