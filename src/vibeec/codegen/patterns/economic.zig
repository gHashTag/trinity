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
    const name = b.name;

    // Pattern: earnTaskReward* / earn_task_reward -> calculate and credit $TRI reward
    // Use indexOf (not startsWith) to match both camelCase and snake_case
    if (std.mem.indexOf(u8, name, "earn") != null and std.mem.indexOf(u8, name, "task") != null and std.mem.indexOf(u8, name, "reward") != null)
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
    if (std.mem.indexOf(u8, name, "stake") != null and std.mem.indexOf(u8, name, "tri") != null)
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
    if (std.mem.indexOf(u8, name, "spend") != null and std.mem.indexOf(u8, name, "tri") != null)
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
    if (std.mem.indexOf(u8, name, "depin") != null)
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
    if (std.mem.indexOf(u8, name, "reward") != null and std.mem.indexOf(u8, name, "distribution") != null)
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
    if (std.mem.indexOf(u8, name, "fee") != null and std.mem.indexOf(u8, name, "task") != null)
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
    if (std.mem.indexOf(u8, name, "vote") != null and std.mem.indexOf(u8, name, "governance") != null)
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
    if (std.mem.indexOf(u8, name, "hire") != null and std.mem.indexOf(u8, name, "agent") != null)
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
    if (std.mem.indexOf(u8, name, "terminate") != null and std.mem.indexOf(u8, name, "agent") != null)
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

    // ═══════════════════════════════════════════════════════════════════════════════
    // MARKETPLACE PATTERNS (v10 Phase 3)
    // ═══════════════════════════════════════════════════════════════════════════════

    // Pattern: createMarketplaceListing* / create_marketplace_listing -> agent lists capabilities
    if (std.mem.indexOf(u8, name, "create") != null and std.mem.indexOf(u8, name, "marketplace") != null and std.mem.indexOf(u8, name, "listing") != null)
    {
        try builder.writeFmt("pub fn {s}(agent: *AgentInfo, capabilities: []const Capability, hourly_rate: f64) !MarketplaceListing {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create marketplace listing for agent capabilities");
        try builder.writeLine("return MarketplaceListing{");
        try builder.writeLine("    .agent_id = agent.wallet.address,");
        try builder.writeLine("    .capabilities = capabilities,");
        try builder.writeLine("    .hourly_rate_tri = hourly_rate,");
        try builder.writeLine("    .reputation_score = agent.reputation_score,");
        try builder.writeLine("    .status = .active,");
        try builder.writeLine("    .created_at = std.time.timestamp(),");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: searchMarketplace* / search_marketplace -> tenant searches for agents
    if (std.mem.indexOf(u8, name, "search") != null and std.mem.indexOf(u8, name, "marketplace") != null)
    {
        try builder.writeFmt("pub fn {s}(marketplace: []const MarketplaceListing, required_capability: []const u8, max_rate: f64) ![]const MarketplaceListing {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Search marketplace for agents with required capability under rate");
        try builder.writeLine("var results = std.ArrayList(MarketplaceListing).init(marketplace.allocator);");
        try builder.writeLine("defer results.deinit();");
        try builder.writeLine("");
        try builder.writeLine("for (marketplace) |listing| {");
        builder.incIndent();
        try builder.writeLine("// Check if agent has required capability");
        try builder.writeLine("for (listing.capabilities) |cap| {");
        builder.incIndent();
        try builder.writeLine("if (std.mem.eql(u8, cap.name, required_capability) and");
        try builder.writeLine("    listing.hourly_rate_tri <= max_rate and");
        try builder.writeLine("    listing.status == .active)");
        try builder.writeLine("{");
        builder.incIndent();
        try builder.writeLine("try results.append(listing);");
        try builder.writeLine("break;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return results.toOwnedSlice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: matchAgentToTask* / match_agent_to_task -> matchmaking algorithm
    if (std.mem.indexOf(u8, name, "match") != null and std.mem.indexOf(u8, name, "agent") != null and std.mem.indexOf(u8, name, "task") != null)
    {
        try builder.writeFmt("pub fn {s}(task: *Task, candidates: []const AgentInfo) ?*AgentInfo {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Match best agent using φ-based scoring");
        try builder.writeLine("var best_agent: ?*AgentInfo = null;");
        try builder.writeLine("var best_score: f32 = 0;");
        try builder.writeLine("");
        try builder.writeLine("for (candidates) |*agent| {");
        builder.incIndent();
        try builder.writeLine("// Score = reputation * skill_match * availability");
        try builder.writeLine("const skill_match = calculateSkillMatch(task.required_capability, agent.capabilities);");
        try builder.writeLine("const availability = if (agent.status == .idle) @as(f32, 1.0) else 0.0;");
        try builder.writeLine("const score = agent.reputation_score * skill_match * availability;");
        try builder.writeLine("");
        try builder.writeLine("if (score > best_score) {");
        builder.incIndent();
        try builder.writeLine("best_score = score;");
        try builder.writeLine("best_agent = agent;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return best_agent;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: acceptMarketplaceOffer* / accept_marketplace_offer -> accept agent contract
    if (std.mem.indexOf(u8, name, "accept") != null and std.mem.indexOf(u8, name, "marketplace") != null and std.mem.indexOf(u8, name, "offer") != null)
    {
        try builder.writeFmt("pub fn {s}(offer: *MarketplaceOffer, tenant_wallet: *Wallet) !Contract {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Accept marketplace offer, create contract, deduct escrow");
        try builder.writeLine("const escrow_amount = offer.hourly_rate * @as(f32, @floatFromInt(offer.duration_hours));");
        try builder.writeLine("if (tenant_wallet.balance_tri < escrow_amount) return error.InsufficientBalance;");
        try builder.writeLine("");
        try builder.writeLine("tenant_wallet.balance_tri -= escrow_amount;");
        try builder.writeLine("offer.status = .accepted;");
        try builder.writeLine("");
        try builder.writeLine("return Contract{");
        try builder.writeLine("    .agent_id = offer.agent_id,");
        try builder.writeLine("    .tenant_id = tenant_wallet.address,");
        try builder.writeLine("    .escrow_tri = escrow_amount,");
        try builder.writeLine("    .hourly_rate = offer.hourly_rate,");
        try builder.writeLine("    .started_at = std.time.timestamp(),");
        try builder.writeLine("    .status = .active,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: rejectMarketplaceOffer* / reject_marketplace_offer -> reject agent contract
    if (std.mem.indexOf(u8, name, "reject") != null and std.mem.indexOf(u8, name, "marketplace") != null and std.mem.indexOf(u8, name, "offer") != null)
    {
        try builder.writeFmt("pub fn {s}(offer: *MarketplaceOffer, reason: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Reject marketplace offer with reason");
        try builder.writeLine("offer.status = .rejected;");
        try builder.writeLine("offer.rejection_reason = reason;");
        try builder.writeLine("// Agent returns to available pool");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MULTI-TENANT PATTERNS (v10 Phase 3)
    // ═══════════════════════════════════════════════════════════════════════════════

    // Pattern: multiTenantIsolate* / multi_tenant_isolate -> isolate tenant execution
    if (std.mem.indexOf(u8, name, "multi") != null and std.mem.indexOf(u8, name, "tenant") != null and std.mem.indexOf(u8, name, "isolate") != null)
    {
        try builder.writeFmt("pub fn {s}(tenant: *Tenant, task: *Task) !TenantContext {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create isolated execution context for tenant");
        try builder.writeLine("const ctx = TenantContext{");
        try builder.writeLine("    .tenant_id = tenant.id,");
        try builder.writeLine("    .isolation_key = generateIsolationKey(tenant.id),");
        try builder.writeLine("    .resource_limits = tenant.resource_limits,");
        try builder.writeLine("    .task = task,");
        try builder.writeLine("    .created_at = std.time.timestamp(),");
        try builder.writeLine("};");
        try builder.writeLine("");
        try builder.writeLine("// Enforce resource isolation");
        try builder.writeLine("try enforceResourceLimits(&ctx);");
        try builder.writeLine("");
        try builder.writeLine("return ctx;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: tenantResourceLimit* / tenant_resource_limit -> enforce per-tenant limits
    if (std.mem.indexOf(u8, name, "tenant") != null and std.mem.indexOf(u8, name, "resource") != null and std.mem.indexOf(u8, name, "limit") != null)
    {
        try builder.writeFmt("pub fn {s}(tenant: *Tenant, resource_type: ResourceType, amount: u64) !bool {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Check if tenant has sufficient resource quota");
        try builder.writeLine("const current_usage = getCurrentUsage(tenant.id, resource_type);");
        try builder.writeLine("const limit = getLimit(tenant.resource_limits, resource_type);");
        try builder.writeLine("");
        try builder.writeLine("if (current_usage + amount > limit) {");
        builder.incIndent();
        try builder.writeLine("// Resource limit exceeded");
        try builder.writeLine("return false;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Update usage tracking");
        try builder.writeLine("updateUsage(tenant.id, resource_type, current_usage + amount);");
        try builder.writeLine("return true;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: tenantBilling* / tenant_billing -> bill tenant for usage
    if (std.mem.indexOf(u8, name, "tenant") != null and std.mem.indexOf(u8, name, "billing") != null)
    {
        try builder.writeFmt("pub fn {s}(tenant: *Tenant, billing_period: BillingPeriod) !TenantInvoice {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Generate billing invoice for tenant");
        try builder.writeLine("const usage_records = getUsageRecords(tenant.id, billing_period);");
        try builder.writeLine("var total_tri: f64 = 0;");
        try builder.writeLine("");
        try builder.writeLine("// Calculate cost per resource type");
        try builder.writeLine("var line_items = std.ArrayList(InvoiceLineItem).init(usage_records.allocator);");
        try builder.writeLine("for (usage_records) |record| {");
        builder.incIndent();
        try builder.writeLine("const cost = record.amount * record.unit_price_tri;");
        try builder.writeLine("total_tri += cost;");
        try builder.writeLine("try line_items.append(.{");
        try builder.writeLine("    .resource_type = record.resource_type,");
        try builder.writeLine("    .amount = record.amount,");
        try builder.writeLine("    .unit_price_tri = record.unit_price_tri,");
        try builder.writeLine("    .total_tri = cost,");
        try builder.writeLine("});");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return TenantInvoice{");
        try builder.writeLine("    .tenant_id = tenant.id,");
        try builder.writeLine("    .period = billing_period,");
        try builder.writeLine("    .line_items = line_items.toOwnedSlice(),");
        try builder.writeLine("    .total_tri = total_tri,");
        try builder.writeLine("    .status = .pending,");
        try builder.writeLine("    .created_at = std.time.timestamp(),");
        try builder.writeLine("};");
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

// ═══════════════════════════════════════════════════════════════════════════════
// MARKETPLACE TYPE DEFINITIONS (v10 Phase 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Capability = struct {
    name: []const u8,
    skill_level: f32,
    verified: bool,
};

pub const MarketplaceListing = struct {
    agent_id: []const u8,
    capabilities: []const Capability,
    hourly_rate_tri: f64,
    reputation_score: f64,
    status: ListingStatus,
    created_at: i64,
};

pub const ListingStatus = enum {
    active,
    paused,
    sold,
    expired,
};

pub const MarketplaceOffer = struct {
    agent_id: []const u8,
    tenant_id: []const u8,
    hourly_rate: f64,
    duration_hours: u32,
    status: OfferStatus,
    rejection_reason: []const u8,
};

pub const OfferStatus = enum {
    pending,
    accepted,
    rejected,
    expired,
};

pub const Contract = struct {
    agent_id: []const u8,
    tenant_id: []const u8,
    escrow_tri: f64,
    hourly_rate: f64,
    started_at: i64,
    status: ContractStatus,
};

pub const ContractStatus = enum {
    active,
    completed,
    terminated,
    disputed,
};

pub const Task = struct {
    task_id: []const u8,
    required_capability: []const u8,
    priority: f32,
    max_payment_tri: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-TENANT TYPE DEFINITIONS (v10 Phase 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tenant = struct {
    id: []const u8,
    wallet: *Wallet,
    resource_limits: ResourceLimits,
    created_at: i64,
};

pub const ResourceLimits = struct {
    max_agents: u32,
    max_tasks_per_hour: u32,
    max_storage_mb: u64,
    max_compute_units: u64,
};

pub const TenantContext = struct {
    tenant_id: []const u8,
    isolation_key: []const u8,
    resource_limits: ResourceLimits,
    task: *Task,
    created_at: i64,
};

pub const ResourceType = enum {
    agent,
    task,
    storage,
    compute,
    bandwidth,
};

pub const BillingPeriod = struct {
    start: i64,
    end: i64,
};

pub const UsageRecord = struct {
    resource_type: ResourceType,
    amount: u64,
    unit_price_tri: f64,
};

pub const InvoiceLineItem = struct {
    resource_type: ResourceType,
    amount: u64,
    unit_price_tri: f64,
    total_tri: f64,
};

pub const TenantInvoice = struct {
    tenant_id: []const u8,
    period: BillingPeriod,
    line_items: []const InvoiceLineItem,
    total_tri: f64,
    status: InvoiceStatus,
    created_at: i64,
};

pub const InvoiceStatus = enum {
    pending,
    paid,
    overdue,
    cancelled,
};
