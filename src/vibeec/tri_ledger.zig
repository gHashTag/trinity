//! ═══════════════════════════════════════════════════════════════════════════════
//! VIBEE v10.6: $TRI Blockchain Ledger
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Full blockchain ledger for tracking $TRI rewards:
//! - Block-based transaction history
//! - Agent balance tracking
//! - Seed reward minting
//! - Persistent storage
//!
//! φ² + 1/φ² = 3
//!
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Transaction types
pub const TxType = enum {
    seed_reward,
    transfer,
    stake,
    slash,
};

/// Transaction record
pub const Transaction = struct {
    id: [32]u8,
    type: TxType,
    from: ?[20]u8, // null = minted
    to: [20]u8,
    amount: u128,
    timestamp: i64,
    metadata: []const u8,
    block_height: u64,

    /// Create a new transaction (generates ID)
    pub fn create(
        allocator: Allocator,
        tx_type: TxType,
        from: ?[20]u8,
        to: [20]u8,
        amount: u128,
        metadata: []const u8,
        block_height: u64,
    ) !Transaction {
        var id: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(metadata, &id);

        return Transaction{
            .id = id,
            .type = tx_type,
            .from = from,
            .to = to,
            .amount = amount,
            .timestamp = std.time.timestamp(),
            .metadata = try allocator.dupe(u8, metadata),
            .block_height = block_height,
        };
    }

    pub fn deinit(self: *const Transaction, allocator: Allocator) void {
        allocator.free(self.metadata);
    }
};

/// Block in the blockchain
pub const Block = struct {
    height: u64,
    hash: [32]u8,
    prev_hash: [32]u8,
    transactions: std.ArrayList(Transaction),
    timestamp: i64,
    nonce: u64,

    pub fn init(allocator: Allocator, height: u64, prev_hash: [32]u8) Block {
        return Block{
            .height = height,
            .hash = [_]u8{0} ** 32,
            .prev_hash = prev_hash,
            .transactions = std.ArrayList(Transaction).init(allocator),
            .timestamp = std.time.timestamp(),
            .nonce = 0,
        };
    }

    pub fn deinit(self: *Block, allocator: Allocator) void {
        for (self.transactions.items) |*tx| {
            tx.deinit(allocator);
        }
        self.transactions.deinit(allocator);
    }

    /// Compute block hash
    pub fn computeHash(self: *const Block) ![32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var buf: [100]u8 = undefined;

        // Hash height
        std.mem.writeInt(u64, &buf, self.height, .little);
        hasher.update(&buf);

        // Hash prev_hash
        hasher.update(&self.prev_hash);

        // Hash transactions
        for (self.transactions.items) |tx| {
            hasher.update(&tx.id);
            const amount_bytes = std.mem.asBytes(&tx.amount);
            hasher.update(amount_bytes);
        }

        // Hash timestamp
        std.mem.writeInt(i64, &buf, self.timestamp, .little);
        hasher.update(&buf[0..8]);

        // Hash nonce
        std.mem.writeInt(u64, &buf, self.nonce, .little);
        hasher.update(&buf[0..8]);

        var hash: [32]u8 = undefined;
        hasher.final(&hash);
        return hash;
    }

    /// Finalize block (compute and set hash)
    pub fn finalize(self: *Block) !void {
        self.hash = try self.computeHash();
    }
};

/// $TRI Blockchain Ledger
pub const TriLedger = struct {
    allocator: Allocator,
    blocks: std.ArrayList(Block),
    pending_txs: std.ArrayList(Transaction),
    balances: std.StringHashMap(u128),
    addresses: std.StringHashMap([20]u8),

    const Self = @This();

    /// Initialize with genesis block
    pub fn init(allocator: Allocator) !Self {
        var ledger = Self{
            .allocator = allocator,
            .blocks = std.ArrayList(Block).init(allocator),
            .pending_txs = std.ArrayList(Transaction).init(allocator),
            .balances = std.StringHashMap(u128).init(allocator),
            .addresses = std.StringHashMap([20]u8).init(allocator),
        };

        // Create genesis block
        const genesis = Block.init(allocator, 0, [_]u8{0} ** 32);
        try genesis.finalize();
        try ledger.blocks.append(allocator, genesis);

        return ledger;
    }

    pub fn deinit(self: *Self) void {
        for (self.blocks.items) |*block| {
            block.deinit(self.allocator);
        }
        self.blocks.deinit(self.allocator);

        for (self.pending_txs.items) |*tx| {
            tx.deinit(self.allocator);
        }
        self.pending_txs.deinit(self.allocator);

        self.balances.deinit();
        self.addresses.deinit();
    }

    /// Get or create address for agent
    pub fn getOrCreateAddress(self: *Self, agent_id: []const u8) ![20]u8 {
        if (self.addresses.get(agent_id)) |addr| {
            return addr;
        }

        // Generate new address (simplified - just hash of agent name)
        var addr: [20]u8 = undefined;
        const hash = std.crypto.hash.sha2.Sha256.hash(agent_id, &addr);
        @memcpy(&addr, hash[0..20]);

        try self.addresses.put(agent_id, addr);
        return addr;
    }

    /// Get balance for agent
    pub fn getBalance(self: *const Self, agent_id: []const u8) !u128 {
        const addr = self.getOrCreateAddress(agent_id) catch return 0;
        return self.balances.get(addr) orelse 0;
    }

    /// Mint seed reward transaction
    pub fn mintSeedReward(
        self: *Self,
        agent: []const u8,
        seed_name: []const u8,
        quality: f32,
    ) !Transaction {
        const reward = @as(u128, @intFromFloat(@round(quality * 10)));

        const to_addr = try self.getOrCreateAddress(agent);

        const metadata = try std.fmt.allocPrint(
            self.allocator,
            "seed_reward:{s}:quality={d:.2}",
            .{ seed_name, quality },
        );

        const tx = try Transaction.create(
            self.allocator,
            .seed_reward,
            null, // Minted (no from address)
            to_addr,
            reward,
            metadata,
            self.blocks.items.len,
        );

        try self.pending_txs.append(self.allocator, tx);
        return tx;
    }

    /// Mine new block with pending transactions
    pub fn mineBlock(self: *Self) !Block {
        if (self.pending_txs.items.len == 0) return error.NoTransactions;

        const prev_block = &self.blocks.items[self.blocks.items.len - 1];
        var block = Block.init(
            self.allocator,
            prev_block.height + 1,
            prev_block.hash,
        );

        // Move transactions from pending to block
        for (self.pending_txs.items) |tx| {
            try block.transactions.append(self.allocator, tx);
        }

        // Clear pending
        for (self.pending_txs.items) |*tx| {
            tx.deinit(self.allocator);
        }
        self.pending_txs.clearRetainingCapacity();

        // Finalize block
        try block.finalize();

        // Update balances
        for (block.transactions.items) |tx| {
            if (tx.from) |from_addr| {
                const from_balance = self.balances.get(from_addr) orelse 0;
                if (from_balance >= tx.amount) {
                    try self.balances.put(from_addr, from_balance - tx.amount);
                }
            }

            const to_balance = self.balances.get(tx.to) orelse 0;
            try self.balances.put(tx.to, to_balance + tx.amount);
        }

        try self.blocks.append(self.allocator, block);
        return block;
    }

    /// Get transaction history for agent
    pub fn getHistory(
        self: *const Self,
        allocator: Allocator,
        agent_id: []const u8,
    ) ![]Transaction {
        const addr = try self.getOrCreateAddress(agent_id);

        var history = std.ArrayList(Transaction).init(allocator);

        for (self.blocks.items) |block| {
            for (block.transactions.items) |tx| {
                const is_to = std.mem.eql(u8, &tx.to, &addr);
                const is_from = if (tx.from) |from|
                    std.mem.eql(u8, &from, &addr)
                else
                    false;

                if (is_to or is_from) {
                    // Clone transaction (simplified)
                    const metadata_copy = try allocator.dupe(u8, tx.metadata);
                    try history.append(allocator, .{
                        .id = tx.id,
                        .type = tx.type,
                        .from = tx.from,
                        .to = tx.to,
                        .amount = tx.amount,
                        .timestamp = tx.timestamp,
                        .metadata = metadata_copy,
                        .block_height = tx.block_height,
                    });
                }
            }
        }

        return history.toOwnedSlice(allocator);
    }

    /// Get ledger statistics
    pub const Stats = struct {
        total_blocks: u64 = 0,
        total_transactions: u64 = 0,
        total_minted: u128 = 0,
        unique_agents: u64 = 0,
    };

    pub fn getStats(self: *const Self) Stats {
        var stats = Stats{
            .total_blocks = @intCast(self.blocks.items.len),
        };

        var agent_set = std.StringHashMap(void).init(self.allocator);

        for (self.blocks.items) |block| {
            for (block.transactions.items) |tx| {
                stats.total_transactions += 1;

                if (tx.from == null) {
                    stats.total_minted += tx.amount;
                }
            }
        }

        var iter = self.addresses.iterator();
        while (iter.next()) |entry| {
            agent_set.put(entry.key_ptr.*, {}) catch {};
        }
        stats.unique_agents = @intCast(agent_set.count());

        return stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "TriLedger: init" {
    const ledger = try TriLedger.init(std.testing.allocator);
    defer ledger.deinit();

    try std.testing.expect(ledger.blocks.items.len == 1);
    try std.testing.expect(ledger.blocks.items[0].height == 0);
}

test "TriLedger: mint reward" {
    var ledger = try TriLedger.init(std.testing.allocator);
    defer ledger.deinit();

    const tx = try ledger.mintSeedReward("test-agent", "test_seed", 0.95);
    try std.testing.expect(tx.type == .seed_reward);
    try std.testing.expect(tx.amount == 10); // 0.95 * 10 = 9.5, rounded = 10
    try std.testing.expect(ledger.pending_txs.items.len == 1);
}

test "TriLedger: mine block" {
    var ledger = try TriLedger.init(std.testing.allocator);
    defer ledger.deinit();

    _ = try ledger.mintSeedReward("agent1", "seed1", 0.8);
    _ = try ledger.mintSeedReward("agent2", "seed2", 0.9);

    const block = try ledger.mineBlock();

    try std.testing.expect(block.height == 1);
    try std.testing.expect(block.transactions.items.len == 2);
    try std.testing.expect(ledger.pending_txs.items.len == 0);
}

test "TriLedger: balance tracking" {
    var ledger = try TriLedger.init(std.testing.allocator);
    defer ledger.deinit();

    _ = try ledger.mintSeedReward("agent1", "seed1", 0.8);
    _ = try ledger.mintSeedReward("agent1", "seed2", 0.9);

    _ = try ledger.mineBlock();

    const balance = try ledger.getBalance("agent1");
    try std.testing.expect(balance == 17); // 8 + 9 = 17
}
