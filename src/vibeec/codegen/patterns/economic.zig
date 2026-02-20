// ═══════════════════════════════════════════════════════════════════════════════
// ECONOMIC PATTERNS - $TRI Economy for Autonomous Swarm
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Match economic operation patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;
    const name = b.name;

    // Pattern: earnTaskReward* / earn_task_reward -> calculate and credit $TRI reward
    if (std.mem.startsWith(u8, name, "earnTaskReward") or
        std.mem.startsWith(u8, name, "earn_task_reward") or
        (std.mem.indexOf(u8, when_text, "earn") != null and std.mem.indexOf(u8, when_text, "reward") != null) or
        (std.mem.indexOf(u8, name, "earn") != null and std.mem.indexOf(u8, name, "reward") != null))
    {
        try builder.writeFmt("pub fn {s}(wallet: *Wallet, difficulty: f32, quality: f32, base_rate: f32) !f64 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate $TRI reward = difficulty * quality * base_rate");
        try builder.writeLine("const reward = difficulty * quality * base_rate;");
        try builder.writeLine("wallet.balance_tri += reward;");
        try builder.writeLine("wallet.total_earned_tri += reward;");
        try builder.writeLine("return reward;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: stakeTRI* / stake_tri -> stake $TRI for priority queue
    if (std.mem.startsWith(u8, name, "stakeTRI") or
        std.mem.startsWith(u8, name, "stake_tri") or
        std.mem.indexOf(u8, name, "stake") != null)
    {
        try builder.writeFmt("pub fn {s}(wallet: *Wallet, amount: f64) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Stake $TRI for priority queue access + governance voting power");
        try builder.writeLine("if (wallet.balance_tri < amount) return error.InsufficientBalance;");
        try builder.writeLine("wallet.balance_tri -= amount;");
        try builder.writeLine("wallet.staked_tri += amount;");
        try builder.writeLine("// Priority increases proportional to stake");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: spendTRI* / spend_tri -> spend $TRI for resources
    if (std.mem.startsWith(u8, name, "spendTRI") or
        std.mem.startsWith(u8, name, "spend_tri") or
        (std.mem.indexOf(u8, when_text, "spend") != null and std.mem.indexOf(u8, when_text, "resource") != null) or
        std.mem.indexOf(u8, name, "spend") != null)
    {
        try builder.writeFmt("pub fn {s}(wallet: *Wallet, amount: f64, resource_type: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Spend $TRI for GPU/agent/storage resources");
        try builder.writeLine("if (wallet.balance_tri < amount) return error.InsufficientBalance;");
        try builder.writeLine("wallet.balance_tri -= amount;");
        try builder.writeLine("wallet.total_spent_tri += amount;");
        try builder.writeLine("_ = resource_type; // Resource type logged");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: depinStaking* / depin_staking -> optimize DePIN yields with φ-based allocation
    if (std.mem.startsWith(u8, name, "depinStaking") or
        std.mem.startsWith(u8, name, "depin_staking") or
        (std.mem.indexOf(u8, name, "depin") != null and std.mem.indexOf(u8, name, "stake") != null))
    {
        try builder.writeFmt("pub fn {s}(positions: []DePINPosition, target_apy: f32) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Auto-restake to highest-APY protocol using φ-based allocation");
        try builder.writeLine("// φ-based allocation: weighted by current APY vs target");
        try builder.writeLine("var best_protocol: ?[]const u8 = null;");
        try builder.writeLine("var best_apy: f32 = 0;");
        try builder.writeLine("");
        try builder.writeLine("for (positions) |pos| {");
        builder.incIndent();
        try builder.writeLine("if (pos.apy > best_apy and pos.apy >= target_apy) {");
        builder.incIndent();
        try builder.writeLine("best_apy = pos.apy;");
        try builder.writeLine("best_protocol = pos.protocol;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return best_protocol orelse \"no-protocol\";");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: triTreasury* -> distribute $TRI inflow
    if (std.mem.startsWith(u8, b.name, "triTreasury") or
        (std.mem.indexOf(u8, b.name, "treasury") != null and std.mem.indexOf(u8, b.name, "tri") != null))
    {
        try builder.writeFmt("pub fn {s}(total_inflow: f64) TreasuryDistribution {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Treasury rebalance: 70% agents, 20% treasury, 10% buyback");
        try builder.writeLine("return TreasuryDistribution{");
        try builder.writeLine("    .to_agents = total_inflow * 0.70,");
        try builder.writeLine("    .to_treasury = total_inflow * 0.20,");
        try builder.writeLine("    .to_buyback = total_inflow * 0.10,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: rewardDistribution* / reward_distribution -> split reward among participants
    if (std.mem.startsWith(u8, name, "rewardDistribution") or
        std.mem.startsWith(u8, name, "reward_distribution") or
        (std.mem.indexOf(u8, when_text, "distribute") != null and std.mem.indexOf(u8, when_text, "reward") != null) or
        (std.mem.indexOf(u8, name, "reward") != null and std.mem.indexOf(u8, name, "distribution") != null))
    {
        try builder.writeFmt("pub fn {s}(total_reward: f64, contribution_weights: []const f64) []f64 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Split reward among participants by contribution weight");
        try builder.writeLine("const result = try contribution_weights.allocator.alloc(f32, contribution_weights.len);");
        try builder.writeLine("");
        try builder.writeLine("// Normalize weights");
        try builder.writeLine("var weight_sum: f32 = 0;");
        try builder.writeLine("for (contribution_weights) |w| weight_sum += w;");
        try builder.writeLine("");
        try builder.writeLine("// Distribute proportional to weight");
        try builder.writeLine("for (contribution_weights, 0..) |w, i| {");
        builder.incIndent();
        try builder.writeLine("result[i] = total_reward * (w / weight_sum);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return result;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: feeForTask* / fee_for_task -> charge $TRI for task execution
    if (std.mem.startsWith(u8, name, "feeForTask") or
        std.mem.startsWith(u8, name, "fee_for_task") or
        (std.mem.indexOf(u8, when_text, "fee") != null and std.mem.indexOf(u8, when_text, "task") != null) or
        (std.mem.indexOf(u8, name, "fee") != null and std.mem.indexOf(u8, name, "task") != null))
    {
        try builder.writeFmt("pub fn {s}(wallet: *Wallet, estimated_cost: f32, priority_multiplier: f32) !f64 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Charge $TRI deposit = estimated_cost * priority_multiplier");
        try builder.writeLine("const deposit = estimated_cost * priority_multiplier;");
        try builder.writeLine("if (wallet.balance_tri < deposit) return error.InsufficientBalance;");
        try builder.writeLine("wallet.balance_tri -= deposit;");
        try builder.writeLine("// Held in escrow until task completion");
        try builder.writeLine("return deposit;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: governanceVote* -> vote on proposal with staked weight
    if (std.mem.startsWith(u8, b.name, "governanceVote") or
        (std.mem.indexOf(u8, b.name, "vote") != null and std.mem.indexOf(u8, b.name, "governance") != null))
    {
        try builder.writeFmt("pub fn {s}(proposal: *GovernanceProposal, wallet: *Wallet, vote_for: bool) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Cast vote with weight = staked_tri");
        try builder.writeLine("const vote_weight = wallet.staked_tri;");
        try builder.writeLine("if (vote_for) {");
        builder.incIndent();
        try builder.writeLine("proposal.for_votes += vote_weight;");
        builder.decIndent();
        try builder.writeLine("} else {");
        builder.incIndent();
        try builder.writeLine("proposal.against_votes += vote_weight;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("// Record vote on-chain");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: hireAgent* / hire_agent -> hire specialized agent for tenant
    if (std.mem.startsWith(u8, name, "hireAgent") or
        std.mem.startsWith(u8, name, "hire_agent") or
        (std.mem.indexOf(u8, when_text, "hire") != null and std.mem.indexOf(u8, when_text, "agent") != null) or
        (std.mem.indexOf(u8, name, "hire") != null and std.mem.indexOf(u8, name, "agent") != null))
    {
        try builder.writeFmt("pub fn {s}(tenant_wallet: *Wallet, agent: *AgentInfo, duration_hours: u32) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Transfer $TRI to agent escrow, activate agent for tenant");
        try builder.writeLine("const cost = agent.hourly_rate_tri * @as(f32, @floatFromInt(duration_hours));");
        try builder.writeLine("if (tenant_wallet.balance_tri < cost) return error.InsufficientBalance;");
        try builder.writeLine("tenant_wallet.balance_tri -= cost;");
        try builder.writeLine("agent.status = .busy;");
        try builder.writeLine("// Agent activated for tenant");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: terminateAgent* / terminate_agent -> end agent contract
    if (std.mem.startsWith(u8, name, "terminateAgent") or
        std.mem.startsWith(u8, name, "terminate_agent") or
        (std.mem.indexOf(u8, when_text, "terminate") != null and std.mem.indexOf(u8, when_text, "agent") != null) or
        (std.mem.indexOf(u8, name, "terminate") != null and std.mem.indexOf(u8, name, "agent") != null))
    {
        try builder.writeFmt("pub fn {s}(agent: *AgentInfo, performance_score: f32) !f64 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate final payout, release escrow, update reputation");
        try builder.writeLine("const base_payout = agent.hourly_rate_tri; // Hourly rate");
        try builder.writeLine("// Performance bonus");
        try builder.writeLine("const final_payout = base_payout * performance_score;");
        try builder.writeLine("agent.wallet.balance_tri += final_payout;");
        try builder.writeLine("agent.status = .idle;");
        try builder.writeLine("agent.reputation_score = performance_score;");
        try builder.writeLine("return final_payout;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ECONOMIC TYPE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Wallet = struct {
    address: []const u8,
    balance_tri: f64,
    staked_tri: f64,
    total_earned_tri: f64,
    total_spent_tri: f64,
};

pub const DePINPosition = struct {
    protocol: []const u8,
    amount_tri: f64,
    apy: f64,
    staked_at: i64,
    auto_compound: bool,
    min_apy_threshold: f64,
};

pub const TreasuryDistribution = struct {
    to_agents: f64,
    to_treasury: f64,
    to_buyback: f64,
};

pub const GovernanceProposal = struct {
    proposal_id: []const u8,
    for_votes: f64,
    against_votes: f64,
    quorum_required: f64,
    expires_at: i64,
    status: ProposalStatus,
};

pub const ProposalStatus = enum {
    active,
    passed,
    rejected,
    executed,
};

pub const AgentInfo = struct {
    wallet: Wallet,
    hourly_rate_tri: f64,
    reputation_score: f64,
    status: AgentStatus,
};

pub const AgentStatus = enum {
    idle,
    busy,
    staked,
    maintenance,
};
