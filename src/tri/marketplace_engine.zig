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
const BASE_YIELD_RATE: f64 = 0.1618;
const ORACLE_CONFIDENCE_DECAY: f64 = 0.9382;
const LP_FEE_RATE: f64 = 0.003;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;

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

pub const YieldPool = struct {
    name: [16]u8,
    name_len: u8,
    pair_constant: f64,
    tier: u8,
    tvl: f64,
    apy_pct: f64,
    reward_per_epoch: f64,
    impermanent_loss_phi: f64,
};

pub const SacredOracle = struct {
    constant_name: [16]u8,
    name_len: u8,
    current_price_tri: f64,
    confidence_pct: f64,
    epochs_since_update: u32,
    twap_24h: f64,
};

pub const LiquidityPool = struct {
    pool_id: u8,
    reserve_tri: f64,
    reserve_paired: f64,
    k_invariant: f64,
    fee_accumulated: f64,
    lp_token_supply: f64,
    phi_fee_boost: f64,
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

fn phiPow(n: u8) f64 {
    var result: f64 = 1.0;
    for (0..n) |_| result *= PHI;
    return result;
}

fn copyName(dest: *[16]u8, src: []const u8) u8 {
    const len: u8 = @intCast(@min(src.len, 16));
    for (0..len) |i| {
        dest[i] = src[i];
    }
    return len;
}

pub fn computeYieldFarming() [5]YieldPool {
    const names = [_][]const u8{ "PHI-TRI", "PI-TRI", "E-TRI", "TRINITY-TRI", "ALPHA-TRI" };
    const pair_constants = [_]f64{ PHI, PI, E, 3.0, 137.036 };
    var pools: [5]YieldPool = undefined;

    for (0..5) |i| {
        const tier: u8 = @intCast(i + 1);
        var name: [16]u8 = [_]u8{0} ** 16;
        const name_len = copyName(&name, names[i]);
        const phi_t = phiPow(tier);
        const tvl = 100000.0 * phi_t;
        const pc = pair_constants[i];
        const sqrt_pc = @sqrt(pc);

        pools[i] = .{
            .name = name,
            .name_len = name_len,
            .pair_constant = pc,
            .tier = tier,
            .tvl = tvl,
            .apy_pct = BASE_YIELD_RATE * phi_t * 100.0,
            .reward_per_epoch = tvl * BASE_YIELD_RATE * phi_t / 365.0,
            .impermanent_loss_phi = 1.0 - (2.0 * sqrt_pc / (1.0 + pc)),
        };
    }
    return pools;
}

pub fn computeSacredOracles() [5]SacredOracle {
    const names = [_][]const u8{ "PHI", "PI", "E", "TRINITY", "ALPHA_INV" };
    const pair_values = [_]f64{ PHI, PI, E, 3.0, 137.036 };
    const epochs = [_]u32{ 0, 1, 3, 7, 12 };
    var oracles: [5]SacredOracle = undefined;

    for (0..5) |i| {
        var cname: [16]u8 = [_]u8{0} ** 16;
        const cname_len = copyName(&cname, names[i]);
        const ep = epochs[i];
        const price = pair_values[i] * PHI;
        const conf = 100.0 * std.math.pow(f64, ORACLE_CONFIDENCE_DECAY, @as(f64, @floatFromInt(ep)));
        const ep_f: f64 = @floatFromInt(ep);
        const twap = price * (1.0 + 0.01 * @sin(ep_f * PHI));

        oracles[i] = .{
            .constant_name = cname,
            .name_len = cname_len,
            .current_price_tri = price,
            .confidence_pct = conf,
            .epochs_since_update = ep,
            .twap_24h = twap,
        };
    }
    return oracles;
}

pub fn computeLiquidityPools() [5]LiquidityPool {
    const reserves_tri = [_]f64{ 10000, 16180, 27182, 31416, 137036 };
    var pools: [5]LiquidityPool = undefined;

    for (0..5) |i| {
        const pool_id: u8 = @intCast(i);
        const r_tri = reserves_tri[i];
        const r_paired = r_tri * PHI;
        const k = r_tri * r_paired;
        const fee = k * LP_FEE_RATE * 0.01;
        const lp_supply = @sqrt(k);
        const pool_id_f: f64 = @floatFromInt(pool_id);
        const phi_boost = PHI_INV_SQ * (1.0 + 0.1 * pool_id_f);

        pools[i] = .{
            .pool_id = pool_id,
            .reserve_tri = r_tri,
            .reserve_paired = r_paired,
            .k_invariant = k,
            .fee_accumulated = fee,
            .lp_token_supply = lp_supply,
            .phi_fee_boost = phi_boost,
        };
    }
    return pools;
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
    } else if (std.mem.eql(u8, mode_str, "yield_farming")) {
        const pools = computeYieldFarming();
        try w.writeAll(",\"yield_pools\":[");
        for (0..5) |idx| {
            if (idx > 0) try w.writeAll(",");
            const p = pools[idx];
            const name_slice = p.name[0..p.name_len];
            try std.fmt.format(w, "{{\"name\":\"{s}\",\"pair_constant\":{d:.6},\"tier\":{d},\"tvl\":{d:.2},\"apy_pct\":{d:.4},\"reward_per_epoch\":{d:.4},\"impermanent_loss_phi\":{d:.6}}}", .{
                name_slice, p.pair_constant, p.tier, p.tvl, p.apy_pct, p.reward_per_epoch, p.impermanent_loss_phi,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "oracle")) {
        const oracles = computeSacredOracles();
        try w.writeAll(",\"sacred_oracles\":[");
        for (0..5) |idx| {
            if (idx > 0) try w.writeAll(",");
            const o = oracles[idx];
            const cname_slice = o.constant_name[0..o.name_len];
            try std.fmt.format(w, "{{\"constant_name\":\"{s}\",\"current_price_tri\":{d:.6},\"confidence_pct\":{d:.4},\"epochs_since_update\":{d},\"twap_24h\":{d:.6}}}", .{
                cname_slice, o.current_price_tri, o.confidence_pct, o.epochs_since_update, o.twap_24h,
            });
        }
        try w.writeAll("]");
    } else if (std.mem.eql(u8, mode_str, "liquidity")) {
        const pools = computeLiquidityPools();
        try w.writeAll(",\"liquidity_pools\":[");
        for (0..5) |idx| {
            if (idx > 0) try w.writeAll(",");
            const lp = pools[idx];
            try std.fmt.format(w, "{{\"pool_id\":{d},\"reserve_tri\":{d:.2},\"reserve_paired\":{d:.2},\"k_invariant\":{d:.2},\"fee_accumulated\":{d:.4},\"lp_token_supply\":{d:.4},\"phi_fee_boost\":{d:.6}}}", .{
                lp.pool_id, lp.reserve_tri, lp.reserve_paired, lp.k_invariant, lp.fee_accumulated, lp.lp_token_supply, lp.phi_fee_boost,
            });
        }
        try w.writeAll("]");
    } else {
        try w.writeAll(",\"modes\":[\"dashboard\",\"staking\",\"proof\",\"tokenomics\",\"yield_farming\",\"oracle\",\"liquidity\"]");
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

test "yield farming" {
    const pools = computeYieldFarming();
    // Verify 5 pools
    try std.testing.expectEqual(@as(usize, 5), pools.len);
    // Verify first pool name is PHI-TRI
    try std.testing.expectEqualStrings("PHI-TRI", pools[0].name[0..pools[0].name_len]);
    // Verify tiers are 1-5
    try std.testing.expectEqual(@as(u8, 1), pools[0].tier);
    try std.testing.expectEqual(@as(u8, 5), pools[4].tier);
    // APY increases with tier
    try std.testing.expect(pools[1].apy_pct > pools[0].apy_pct);
    try std.testing.expect(pools[2].apy_pct > pools[1].apy_pct);
    try std.testing.expect(pools[3].apy_pct > pools[2].apy_pct);
    try std.testing.expect(pools[4].apy_pct > pools[3].apy_pct);
    // TVL increases with tier
    try std.testing.expect(pools[4].tvl > pools[0].tvl);
    // Impermanent loss is between 0 and 1
    for (0..5) |i| {
        try std.testing.expect(pools[i].impermanent_loss_phi >= 0.0);
        try std.testing.expect(pools[i].impermanent_loss_phi < 1.0);
    }
}

test "sacred oracles" {
    const oracles = computeSacredOracles();
    // Verify 5 oracles
    try std.testing.expectEqual(@as(usize, 5), oracles.len);
    // Verify first oracle name is PHI
    try std.testing.expectEqualStrings("PHI", oracles[0].constant_name[0..oracles[0].name_len]);
    // Verify last oracle name is ALPHA_INV
    try std.testing.expectEqualStrings("ALPHA_INV", oracles[4].constant_name[0..oracles[4].name_len]);
    // Confidence decays with epochs (first oracle has 0 epochs -> 100%)
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), oracles[0].confidence_pct, 0.01);
    // Confidence decays: later oracles have lower confidence
    try std.testing.expect(oracles[0].confidence_pct > oracles[1].confidence_pct);
    try std.testing.expect(oracles[1].confidence_pct > oracles[2].confidence_pct);
    try std.testing.expect(oracles[2].confidence_pct > oracles[3].confidence_pct);
    try std.testing.expect(oracles[3].confidence_pct > oracles[4].confidence_pct);
    // All prices are positive
    for (0..5) |i| {
        try std.testing.expect(oracles[i].current_price_tri > 0.0);
        try std.testing.expect(oracles[i].twap_24h > 0.0);
    }
}

test "liquidity pools" {
    const pools = computeLiquidityPools();
    // Verify 5 pools
    try std.testing.expectEqual(@as(usize, 5), pools.len);
    // Verify pool IDs are 0-4
    try std.testing.expectEqual(@as(u8, 0), pools[0].pool_id);
    try std.testing.expectEqual(@as(u8, 4), pools[4].pool_id);
    // k_invariant = reserve_tri * reserve_paired
    for (0..5) |i| {
        const expected_k = pools[i].reserve_tri * pools[i].reserve_paired;
        try std.testing.expectApproxEqAbs(expected_k, pools[i].k_invariant, 0.01);
    }
    // reserve_paired = reserve_tri * PHI
    for (0..5) |i| {
        const expected_paired = pools[i].reserve_tri * PHI;
        try std.testing.expectApproxEqAbs(expected_paired, pools[i].reserve_paired, 0.01);
    }
    // lp_token_supply = sqrt(k_invariant)
    for (0..5) |i| {
        const expected_supply = @sqrt(pools[i].k_invariant);
        try std.testing.expectApproxEqAbs(expected_supply, pools[i].lp_token_supply, 0.01);
    }
    // All fees positive
    for (0..5) |i| {
        try std.testing.expect(pools[i].fee_accumulated > 0.0);
        try std.testing.expect(pools[i].phi_fee_boost > 0.0);
    }
}
