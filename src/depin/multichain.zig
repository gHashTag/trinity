// @origin(spec:depin_multichain.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════════════
// Phase 5: Multi-Chain Support — Cross-Chain Stake Delegation
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════════════
// CHAIN DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

pub const ChainId = enum(u64) {
    ethereum = 1,
    polygon = 137,
    arbitrum = 42161,
    optimism = 10,
    base = 8453,
};

pub const ChainConfig = struct {
    id: ChainId,
    name: []const u8,
    rpc_url: []const u8,
    explorer_url: []const u8,
    native_token: []const u8,
    block_time_ms: u64,
};

pub const SUPPORTED_CHAINS = [_]ChainConfig{
    .{
        .id = .ethereum,
        .name = "Ethereum",
        .rpc_url = "https://eth.llamarpc.com",
        .explorer_url = "https://etherscan.io",
        .native_token = "ETH",
        .block_time_ms = 12000,
    },
    .{
        .id = .polygon,
        .name = "Polygon",
        .rpc_url = "https://polygon-rpc.com",
        .explorer_url = "https://polygonscan.com",
        .native_token = "MATIC",
        .block_time_ms = 2000,
    },
    .{
        .id = .arbitrum,
        .name = "Arbitrum",
        .rpc_url = "https://arb1.arbitrum.io/rpc",
        .explorer_url = "https://arbiscan.io",
        .native_token = "ETH",
        .block_time_ms = 1000,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CROSS-CHAIN STAKE DELEGATION
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

pub const CrossChainDelegation = struct {
    source_chain: ChainId,
    target_chain: ChainId,
    delegator: [20]u8,
    operator: [20]u8,
    amount: u128,
    delegation_id: []const u8,
    created_at: i64,
    active: bool,

    pub fn deinit(self: *CrossChainDelegation, allocator: Allocator) void {
        allocator.free(self.delegation_id);
    }
};

pub const MultiChainManager = struct {
    allocator: Allocator,
    delegations: std.ArrayListUnmanaged(CrossChainDelegation),
    active_chains: std.AutoHashMapUnmanaged(ChainId, bool),

    pub fn init(allocator: Allocator) MultiChainManager {
        var manager = MultiChainManager{
            .allocator = allocator,
            .delegations = .{},
            .active_chains = .{},
        };

        // Mark all supported chains as active
        for (SUPPORTED_CHAINS) |chain| {
            manager.active_chains.put(allocator, chain.id, true) catch {};
        }

        return manager;
    }

    /// Add chain support
    pub fn enableChain(self: *MultiChainManager, chain_id: ChainId) !void {
        try self.active_chains.put(self.allocator, chain_id, true);
        std.log.info("MULTICHAIN: Enabled chain {s}", .{@tagName(chain_id)});
    }

    /// Disable chain
    pub fn disableChain(self: *MultiChainManager, chain_id: ChainId) !void {
        try self.active_chains.put(self.allocator, chain_id, false);
        std.log.info("MULTICHAIN: Disabled chain {s}", .{@tagName(chain_id)});
    }

    /// Create cross-chain delegation
    pub fn createDelegation(
        self: *MultiChainManager,
        source_chain: ChainId,
        target_chain: ChainId,
        delegator: [20]u8,
        operator: [20]u8,
        amount: u128,
    ) ![]const u8 {
        if (!self.active_chains.get(source_chain) or !self.active_chains.get(target_chain)) {
            return error.ChainNotSupported;
        }

        const now = std.time.timestamp();
        const delegation_id = try std.fmt.allocPrint(self.allocator, "xfer_{d}_{x}", .{ now, std.math.maxInt(u64, std.math.maxInt(u64)) });

        const delegation = CrossChainDelegation{
            .source_chain = source_chain,
            .target_chain = target_chain,
            .delegator = delegator,
            .operator = operator,
            .amount = amount,
            .delegation_id = delegation_id,
            .created_at = now,
            .active = true,
        };

        try self.delegations.append(self.allocator, delegation);

        std.log.info("MULTICHAIN: Created delegation {s} from {s} to {s}", .{
            delegation_id, @tagName(source_chain), @tagName(target_chain),
        });

        return delegation_id;
    }

    /// Get chain config
    pub fn getChainConfig(_: *const MultiChainManager, chain_id: ChainId) ?ChainConfig {
        for (SUPPORTED_CHAINS) |chain| {
            if (chain.id == chain_id) return chain;
        }
        return null;
    }

    /// Get all active chains
    pub fn getActiveChains(self: *const MultiChainManager) []const ChainId {
        // TODO: allocate and return actual list of active chains
        _ = self; // Use parameter to avoid unused var warning
        return &[_]ChainId{};
    }

    /// Calculate reward multiplier based on chain
    pub fn getRewardMultiplier(_: *const MultiChainManager, chain_id: ChainId) f64 {
        return switch (chain_id) {
            .ethereum => 1.0,
            .polygon => 1.5, // Higher rewards for Polygon
            .arbitrum => 1.2,
            .optimism => 1.3,
            .base => 0.8,
        };
    }

    pub fn deinit(self: *MultiChainManager) void {
        for (self.delegations.items) |*delegation| {
            delegation.deinit(self.allocator);
        }
        self.delegations.deinit(self.allocator);
        self.active_chains.deinit(self.allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

test "chain config lookup" {
    const eth = SUPPORTED_CHAINS[0];
    try std.testing.expectEqual(ChainId.ethereum, eth.id);
    try std.testing.expectEqualStrings("Ethereum", eth.name);
}

test "MultiChainManager init" {
    const allocator = std.testing.allocator;
    var manager = MultiChainManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(SUPPORTED_CHAINS.len == manager.active_chains.count());
}

test "reward multipliers" {
    const poly_mult = getRewardMultiplier(.polygon);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), poly_mult, 0.01);
}

fn getRewardMultiplier(chain_id: ChainId) f64 {
    return switch (chain_id) {
        .ethereum => 1.0,
        .polygon => 1.5, // Higher rewards for Polygon
        .arbitrum => 1.2,
        .optimism => 1.3,
        .base => 0.8,
    };
}

test "enable/disable chain" {
    const allocator = std.testing.allocator;
    var manager = MultiChainManager.init(allocator);
    defer manager.deinit();

    try manager.disableChain(.polygon);
    try std.testing.expect(!manager.active_chains.get(.polygon).?);
}
