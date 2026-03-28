// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY TESTNET EXPLORER — Block Explorer Backend
// Provides REST API for testnet blocks, transactions, nodes
// φ² + 1/φ² = 3 | TESTNET PHASE 0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testnet_config = @import("testnet_config.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK EXPLORER DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

pub const BlockInfo = struct {
    height: u64,
    hash: []const u8,
    prev_hash: []const u8,
    timestamp: u64,
    transaction_count: usize,
    total_fees: u64,
    reward: u64,
    miner: []const u8,
    size: usize,

    pub fn toJson(self: *const BlockInfo, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"height":{d},"hash":"{s}","prev_hash":"{s}","timestamp":{d},"tx_count":{d},"fees":{d},"reward":{d},"miner":"{s}","size":{d}}}
        , .{
            self.height,            self.hash,       self.prev_hash, self.timestamp,
            self.transaction_count, self.total_fees, self.reward,    self.miner,
            self.size,
        });
    }
};

pub const TransactionInfo = struct {
    tx_hash: []const u8,
    block_height: u64,
    timestamp: u64,
    from: []const u8,
    to: []const u8,
    amount: u64,
    fee: u64,
    tx_type: TxType,

    pub const TxType = enum(u8) {
        transfer = 0,
        stake = 1,
        unstake = 2,
        inference_reward = 3,
        mining_reward = 4,
        faucet = 5,

        pub fn toString(self: TxType) []const u8 {
            return switch (self) {
                .transfer => "transfer",
                .stake => "stake",
                .unstake => "unstake",
                .inference_reward => "inference_reward",
                .mining_reward => "mining_reward",
                .faucet => "faucet",
            };
        }
    };

    pub fn toJson(self: *const TransactionInfo, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"hash":"{s}","block":{d},"timestamp":{d},"from":"{s}","to":"{s}","amount":{d},"fee":{d},"type":"{s}"}}
        , .{
            self.tx_hash, self.block_height,       self.timestamp,
            self.from,    self.to,                 self.amount,
            self.fee,     self.tx_type.toString(),
        });
    }
};

pub const NodeInfo = struct {
    node_id: []const u8,
    address: []const u8,
    tier: testnet_config.Tier,
    uptime_hours: f64,
    jobs_completed: usize,
    earned_tri: u64,
    quality_score: f64,
    status: NodeStatus,
    first_seen: u64,
    last_active: u64,
    region: ?[]const u8 = null,

    pub const NodeStatus = enum(u8) {
        offline,
        online,
        earning,

        pub fn toString(self: NodeStatus) []const u8 {
            return switch (self) {
                .offline => "offline",
                .online => "online",
                .earning => "earning",
            };
        }
    };

    pub fn toJson(self: *const NodeInfo, allocator: std.mem.Allocator) ![]const u8 {
        const region_str = if (self.region) |r|
            try std.fmt.allocPrint(allocator, ",\"region\":\"{s}\"", .{r})
        else
            "";
        defer if (self.region != null) allocator.free(region_str);

        return std.fmt.allocPrint(allocator,
            \\{{"node_id":"{s}","address":"{s}","tier":"{s}","uptime":{d:.2},"jobs":{d},"earned":{d},"quality":{d:.2},"status":"{s}"{s}}}
        , .{
            self.node_id,       self.address,           @tagName(self.tier),
            self.uptime_hours,  self.jobs_completed,    self.earned_tri,
            self.quality_score, self.status.toString(), region_str,
        });
    }
};

pub const ExplorerStats = struct {
    /// Total blocks
    block_count: u64,
    /// Total transactions
    tx_count: u64,
    /// Active nodes
    active_nodes: usize,
    /// Total nodes
    total_nodes: usize,
    /// Network hash rate (H/s)
    hash_rate: f64,
    /// Average block time (seconds)
    avg_block_time: f64,
    /// Total test $TRI supply
    total_supply: u64,
    /// Current phase
    current_phase: testnet_config.TestnetPhase,
    /// Testnet start timestamp
    testnet_start: u64,
    /// Testnet duration (hours)
    testnet_duration_hours: u64,

    pub fn toJson(self: *const ExplorerStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"blocks":{d},"transactions":{d},"active_nodes":{d},"total_nodes":{d},"hash_rate":{d:.2},"avg_block_time":{d:.2},"supply":{d},"phase":"{s}","testnet_duration_hours":{d}}}
        , .{
            self.block_count,            self.tx_count,       self.active_nodes, self.total_nodes,
            self.hash_rate,              self.avg_block_time, self.total_supply, self.current_phase.toString(),
            self.testnet_duration_hours,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER DATABASE — In-memory block store
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExplorerDB = struct {
    allocator: std.mem.Allocator,
    /// Blocks by height
    blocks: std.ArrayListUnmanaged(BlockInfo),
    /// Block hash -> height index
    block_index: std.StringHashMapUnmanaged(u64),
    /// Transactions by hash
    transactions: std.StringHashMapUnmanaged(TransactionInfo),
    /// Transactions by address (sent/received)
    address_txs: std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8)),
    /// Nodes
    nodes: std.StringHashMapUnmanaged(NodeInfo),
    /// Latest block height
    latest_height: u64,

    pub fn init(allocator: std.mem.Allocator) ExplorerDB {
        return ExplorerDB{
            .allocator = allocator,
            .blocks = .{},
            .block_index = .{},
            .transactions = .{},
            .address_txs = .{},
            .nodes = .{},
            .latest_height = 0,
        };
    }

    pub fn deinit(self: *ExplorerDB) void {
        for (self.blocks.items) |*block| {
            self.allocator.free(block.hash);
            self.allocator.free(block.prev_hash);
            self.allocator.free(block.miner);
        }
        self.blocks.deinit(self.allocator);

        var block_iter = self.block_index.iterator();
        while (block_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.block_index.deinit(self.allocator);

        var tx_iter = self.transactions.iterator();
        while (tx_iter.next()) |entry| {
            // The key (tx.tx_hash) is freed here
            self.allocator.free(entry.key_ptr.*);
            const tx = entry.value_ptr.*;
            // tx.tx_hash points to same allocation as key, already freed above
            // Only free from and to which are owned by the value
            self.allocator.free(tx.from);
            self.allocator.free(tx.to);
        }
        self.transactions.deinit(self.allocator);

        var addr_iter = self.address_txs.iterator();
        while (addr_iter.next()) |entry| {
            // Note: entry.key_ptr is owned by transactions HashMap (tx.from/to)
            // tx_hash pointers are also owned by transactions HashMap
            // We only deinit the ArrayList, not free the pointers
            entry.value_ptr.deinit(self.allocator);
        }
        self.address_txs.deinit(self.allocator);

        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            // The key (node.node_id) is freed here
            self.allocator.free(entry.key_ptr.*);
            const node = entry.value_ptr.*;
            // node.node_id points to same allocation as key, already freed above
            // Only free address and region which are owned by the value
            self.allocator.free(node.address);
            if (node.region) |r| self.allocator.free(r);
        }
        self.nodes.deinit(self.allocator);
    }

    /// Add a block
    pub fn addBlock(self: *ExplorerDB, block: BlockInfo) !void {
        // Make copies for the block (these will be owned by the block)
        const hash_copy = try self.allocator.dupe(u8, block.hash);
        errdefer self.allocator.free(hash_copy);

        const prev_copy = try self.allocator.dupe(u8, block.prev_hash);
        errdefer self.allocator.free(prev_copy);

        const miner_copy = try self.allocator.dupe(u8, block.miner);
        errdefer self.allocator.free(miner_copy);

        const block_copy = BlockInfo{
            .height = block.height,
            .hash = hash_copy,
            .prev_hash = prev_copy,
            .timestamp = block.timestamp,
            .transaction_count = block.transaction_count,
            .total_fees = block.total_fees,
            .reward = block.reward,
            .miner = miner_copy,
            .size = block.size,
        };

        try self.blocks.append(self.allocator, block_copy);
        // For the HashMap key, use a separate allocation to avoid double-free
        const index_key = try self.allocator.dupe(u8, hash_copy);
        try self.block_index.put(self.allocator, index_key, block.height);

        if (block.height > self.latest_height) {
            self.latest_height = block.height;
        }
    }

    /// Get block by height
    pub fn getBlockByHeight(self: *const ExplorerDB, height: u64) ?BlockInfo {
        if (height >= self.blocks.items.len) return null;
        return self.blocks.items[height];
    }

    /// Get block by hash
    pub fn getBlockByHash(self: *const ExplorerDB, hash: []const u8) ?BlockInfo {
        const height = self.block_index.get(hash) orelse return null;
        return self.blocks.items[height];
    }

    /// Get latest block
    pub fn getLatestBlock(self: *const ExplorerDB) ?BlockInfo {
        if (self.blocks.items.len == 0) return null;
        return self.blocks.items[self.blocks.items.len - 1];
    }

    /// Add a transaction
    pub fn addTransaction(self: *ExplorerDB, tx: TransactionInfo) !void {
        const hash_copy = try self.allocator.dupe(u8, tx.tx_hash);
        errdefer self.allocator.free(hash_copy);

        const from_copy = try self.allocator.dupe(u8, tx.from);
        errdefer self.allocator.free(from_copy);

        const to_copy = try self.allocator.dupe(u8, tx.to);
        errdefer self.allocator.free(to_copy);

        const tx_copy = TransactionInfo{
            .tx_hash = hash_copy,
            .block_height = tx.block_height,
            .timestamp = tx.timestamp,
            .from = from_copy,
            .to = to_copy,
            .amount = tx.amount,
            .fee = tx.fee,
            .tx_type = tx.tx_type,
        };

        try self.transactions.put(self.allocator, hash_copy, tx_copy);

        // Index by address
        try self.indexTxByAddress(from_copy, hash_copy);
        try self.indexTxByAddress(to_copy, hash_copy);
    }

    fn indexTxByAddress(self: *ExplorerDB, address: []const u8, tx_hash: []const u8) !void {
        const gop = try self.address_txs.getOrPutValue(self.allocator, address, .{});
        // The address is already duplicated by caller, stored as key by getOrPutValue

        // The tx_hash is already duplicated by caller, just append it
        try gop.value_ptr.append(self.allocator, tx_hash);
    }

    /// Get transaction by hash
    pub fn getTransaction(self: *const ExplorerDB, hash: []const u8) ?TransactionInfo {
        const tx = self.transactions.get(hash) orelse return null;
        return tx;
    }

    /// Get transactions for address
    pub fn getTransactionsForAddress(self: *const ExplorerDB, address: []const u8, limit: usize) ![]TransactionInfo {
        const tx_hashes = self.address_txs.get(address) orelse return &[0]TransactionInfo{};

        var result = try std.ArrayList(TransactionInfo).initCapacity(self.allocator, tx_hashes.items.len);

        const count = @min(limit, tx_hashes.items.len);
        for (tx_hashes.items[0..count]) |hash| {
            if (self.transactions.get(hash)) |tx| {
                try result.append(tx);
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Add or update a node
    pub fn updateNode(self: *ExplorerDB, node: NodeInfo) !void {
        const id_copy = try self.allocator.dupe(u8, node.node_id);
        errdefer self.allocator.free(id_copy);

        const addr_copy = try self.allocator.dupe(u8, node.address);
        errdefer self.allocator.free(addr_copy);

        const region_copy = if (node.region) |r|
            try self.allocator.dupe(u8, r)
        else
            null;

        const node_copy = NodeInfo{
            .node_id = id_copy,
            .address = addr_copy,
            .tier = node.tier,
            .uptime_hours = node.uptime_hours,
            .jobs_completed = node.jobs_completed,
            .earned_tri = node.earned_tri,
            .quality_score = node.quality_score,
            .status = node.status,
            .first_seen = node.first_seen,
            .last_active = node.last_active,
            .region = region_copy,
        };

        const gop = try self.nodes.getOrPut(self.allocator, id_copy);
        if (gop.found_existing) {
            // Cleanup old values
            self.allocator.free(gop.value_ptr.node_id);
            self.allocator.free(gop.value_ptr.address);
            if (gop.value_ptr.region) |r| self.allocator.free(r);
        }

        gop.value_ptr.* = node_copy;
    }

    /// Get node by ID
    pub fn getNode(self: *const ExplorerDB, node_id: []const u8) ?NodeInfo {
        const node = self.nodes.get(node_id) orelse return null;
        return node;
    }

    /// Get all nodes
    pub fn getAllNodes(self: *const ExplorerDB) ![]NodeInfo {
        var result = try std.ArrayList(NodeInfo).initCapacity(self.allocator, 32);

        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            try result.append(self.allocator, entry.value_ptr.*);
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Get statistics
    pub fn getStats(self: *const ExplorerDB) ExplorerStats {
        var active_nodes: usize = 0;
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.status != .offline) {
                active_nodes += 1;
            }
        }

        return ExplorerStats{
            .block_count = self.blocks.items.len,
            .tx_count = self.transactions.count(),
            .active_nodes = active_nodes,
            .total_nodes = self.nodes.count(),
            .hash_rate = 0, // DEFERRED: Calculate from difficulty
            .avg_block_time = 3.0, // DEFERRED: Calculate from blocks
            .total_supply = 0, // DEFERRED: Sum all rewards
            .current_phase = testnet_config.CURRENT_PHASE,
            .testnet_start = 0, // Set when testnet starts
            .testnet_duration_hours = 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLORER API SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExplorerServer = struct {
    allocator: std.mem.Allocator,
    db: ExplorerDB,
    port: u16,
    socket: ?std.posix.socket_t = null,
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator, port: u16) ExplorerServer {
        return ExplorerServer{
            .allocator = allocator,
            .db = ExplorerDB.init(allocator),
            .port = port,
        };
    }

    pub fn deinit(self: *ExplorerServer) void {
        if (self.socket) |s| {
            std.posix.close(s);
        }
        self.db.deinit();
    }

    /// Start the server
    pub fn start(self: *ExplorerServer) !void {
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);

        const reuse_value: u32 = 1;
        _ = std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, @intCast(reuse_value)))) catch |err| {
            std.posix.close(sock);
            return err;
        };

        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        std.posix.bind(sock, &addr.any, addr.getOsSockLen()) catch |err| {
            std.posix.close(sock);
            return err;
        };

        try std.posix.listen(sock, 128);
        self.socket = sock;
        self.running = true;
    }

    /// Handle GET /api/block/:height
    pub fn handleGetBlock(self: *ExplorerServer, height: u64) ![]const u8 {
        const block = self.db.getBlockByHeight(height) orelse {
            return error.BlockNotFound;
        };
        return block.toJson(self.allocator);
    }

    /// Handle GET /api/block/hash/:hash
    pub fn handleGetBlockByHash(self: *ExplorerServer, hash: []const u8) ![]const u8 {
        const block = self.db.getBlockByHash(hash) orelse {
            return error.BlockNotFound;
        };
        return block.toJson(self.allocator);
    }

    /// Handle GET /api/tx/:hash
    pub fn handleGetTx(self: *ExplorerServer, hash: []const u8) ![]const u8 {
        const tx = self.db.getTransaction(hash) orelse {
            return error.TxNotFound;
        };
        return tx.toJson(self.allocator);
    }

    /// Handle GET /api/address/:address
    pub fn handleGetAddress(self: *ExplorerServer, address: []const u8, limit: usize) ![]const u8 {
        const txs = try self.db.getTransactionsForAddress(address, limit);
        defer {
            for (txs) |*tx| {
                self.allocator.free(tx.tx_hash);
                self.allocator.free(tx.from);
                self.allocator.free(tx.to);
            }
            self.allocator.free(txs);
        }

        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        try buffer.appendSlice(self.allocator, "{\"address\":\"");
        try buffer.appendSlice(self.allocator, address);
        try buffer.appendSlice(self.allocator, "\",\"transactions\":[");

        for (txs, 0..) |tx, i| {
            if (i > 0) try buffer.append(self.allocator, ',');
            const json = try tx.toJson(self.allocator);
            defer self.allocator.free(json);
            try buffer.appendSlice(self.allocator, json);
        }

        try buffer.appendSlice(self.allocator, "]}");
        return buffer.toOwnedSlice(self.allocator);
    }

    /// Handle GET /api/nodes
    pub fn handleGetNodes(self: *ExplorerServer) ![]const u8 {
        const nodes = try self.db.getAllNodes();
        defer {
            for (nodes) |*node| {
                self.allocator.free(node.node_id);
                self.allocator.free(node.address);
                if (node.region) |r| self.allocator.free(r);
            }
            self.allocator.free(nodes);
        }

        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        try buffer.appendSlice(self.allocator, "{\"nodes\":[");

        for (nodes, 0..) |node, i| {
            if (i > 0) try buffer.append(self.allocator, ',');
            const json = try node.toJson(self.allocator);
            defer self.allocator.free(json);
            try buffer.appendSlice(self.allocator, json);
        }

        try buffer.appendSlice(self.allocator, "]}");
        return buffer.toOwnedSlice(self.allocator);
    }

    /// Handle GET /api/stats
    pub fn handleGetStats(self: *ExplorerServer) ![]const u8 {
        const stats = self.db.getStats();
        return stats.toJson(self.allocator);
    }

    /// Handle GET /api/leaderboard
    pub fn handleGetLeaderboard(self: *ExplorerServer, limit: usize) ![]const u8 {
        const nodes = try self.db.getAllNodes();
        defer {
            for (nodes) |*node| {
                self.allocator.free(node.node_id);
                self.allocator.free(node.address);
                if (node.region) |r| self.allocator.free(r);
            }
            self.allocator.free(nodes);
        }

        // Sort by earned_tri descending
        std.sort.block(NodeInfo, nodes, {}, compareByEarnedDesc);

        const count = @min(limit, nodes.len);

        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        try buffer.appendSlice(self.allocator, "{\"leaderboard\":[");

        for (nodes[0..count], 0..) |node, i| {
            if (i > 0) try buffer.append(self.allocator, ',');
            try buffer.appendSlice(self.allocator, "{\"node_id\":\"");
            try buffer.appendSlice(self.allocator, node.node_id);
            try buffer.appendSlice(self.allocator, "\",\"address\":\"");
            try buffer.appendSlice(self.allocator, node.address);
            try buffer.appendSlice(self.allocator, "\",\"earned\":");
            try buffer.writer(self.allocator).print("{d}", .{node.earned_tri});
            try buffer.appendSlice(self.allocator, ",\"jobs\":");
            try buffer.writer(self.allocator).print("{d}", .{node.jobs_completed});
            try buffer.appendSlice(self.allocator, ",\"quality\":");
            try buffer.writer(self.allocator).print("{d:.2}", .{node.quality_score});
            try buffer.append(self.allocator, '}');
        }

        try buffer.appendSlice(self.allocator, "]}");
        return buffer.toOwnedSlice(self.allocator);
    }
};

fn compareByEarnedDesc(context: void, a: NodeInfo, b: NodeInfo) bool {
    _ = context;
    return a.earned_tri > b.earned_tri;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ExplorerDB init" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    try std.testing.expectEqual(@as(usize, 0), db.blocks.items.len);
    try std.testing.expectEqual(@as(u64, 0), db.latest_height);
}

test "ExplorerDB addBlock" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const block = BlockInfo{
        .height = 0,
        .hash = "0xabc123",
        .prev_hash = "0x000000",
        .timestamp = 1234567890,
        .transaction_count = 1,
        .total_fees = 100,
        .reward = 1000,
        .miner = "0xminer",
        .size = 1024,
    };

    try db.addBlock(block);
    try std.testing.expectEqual(@as(usize, 1), db.blocks.items.len);
    try std.testing.expectEqual(@as(u64, 0), db.latest_height);
}

test "ExplorerDB getBlockByHeight" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const block = BlockInfo{
        .height = 0,
        .hash = "0xabc123",
        .prev_hash = "0x000000",
        .timestamp = 1234567890,
        .transaction_count = 0,
        .total_fees = 0,
        .reward = 0,
        .miner = "0x",
        .size = 0,
    };

    try db.addBlock(block);

    const found = db.getBlockByHeight(0).?;
    try std.testing.expectEqualStrings("0xabc123", found.hash);
}

test "ExplorerDB addTransaction" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const tx = TransactionInfo{
        .tx_hash = "0xtx123",
        .block_height = 0,
        .timestamp = 1234567890,
        .from = "0xfrom",
        .to = "0xto",
        .amount = 1000,
        .fee = 10,
        .tx_type = .transfer,
    };

    try db.addTransaction(tx);
    try std.testing.expectEqual(@as(usize, 1), db.transactions.count());
}

test "ExplorerDB getTransaction" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const tx = TransactionInfo{
        .tx_hash = "0xtx123",
        .block_height = 0,
        .timestamp = 1234567890,
        .from = "0xfrom",
        .to = "0xto",
        .amount = 1000,
        .fee = 10,
        .tx_type = .transfer,
    };

    try db.addTransaction(tx);

    const found = db.getTransaction("0xtx123").?;
    try std.testing.expectEqual(@as(u64, 1000), found.amount);
}

test "ExplorerDB updateNode" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const node = NodeInfo{
        .node_id = "node-1",
        .address = "0x123",
        .tier = .free,
        .uptime_hours = 10.5,
        .jobs_completed = 5,
        .earned_tri = 500,
        .quality_score = 0.95,
        .status = .online,
        .first_seen = 1234567890,
        .last_active = 1234567890,
    };

    try db.updateNode(node);
    try std.testing.expectEqual(@as(usize, 1), db.nodes.count());

    const found = db.getNode("node-1").?;
    try std.testing.expectEqual(@as(usize, 5), found.jobs_completed);
}

test "ExplorerDB getStats" {
    const allocator = std.testing.allocator;
    var db = ExplorerDB.init(allocator);
    defer db.deinit();

    const node = NodeInfo{
        .node_id = "node-1",
        .address = "0x123",
        .tier = .free,
        .uptime_hours = 10.5,
        .jobs_completed = 5,
        .earned_tri = 500,
        .quality_score = 0.95,
        .status = .online,
        .first_seen = 1234567890,
        .last_active = 1234567890,
    };

    try db.updateNode(node);

    const stats = db.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_nodes);
    try std.testing.expectEqual(@as(usize, 1), stats.active_nodes);
}

test "ExplorerServer init" {
    const allocator = std.testing.allocator;
    var server = ExplorerServer.init(allocator, 8080);
    defer server.deinit();

    try std.testing.expectEqual(@as(u16, 8080), server.port);
    try std.testing.expect(!server.running);
}

test "NodeInfo toJson" {
    const allocator = std.testing.allocator;
    const node = NodeInfo{
        .node_id = "node-1",
        .address = "0x123",
        .tier = .staker,
        .uptime_hours = 10.5,
        .jobs_completed = 5,
        .earned_tri = 500,
        .quality_score = 0.95,
        .status = .online,
        .first_seen = 1234567890,
        .last_active = 1234567890,
        .region = "us-east",
    };

    const json = try node.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"node_id\":\"node-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tier\":\"staker\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"region\":\"us-east\"") != null);
}

test "BlockInfo toJson" {
    const allocator = std.testing.allocator;
    const block = BlockInfo{
        .height = 100,
        .hash = "0xabc123",
        .prev_hash = "0xdef456",
        .timestamp = 1234567890,
        .transaction_count = 5,
        .total_fees = 100,
        .reward = 1000,
        .miner = "0xminer",
        .size = 2048,
    };

    const json = try block.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"height\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"hash\":\"0xabc123\"") != null);
}

test "TransactionInfo toJson" {
    const allocator = std.testing.allocator;
    const tx = TransactionInfo{
        .tx_hash = "0xtx123",
        .block_height = 100,
        .timestamp = 1234567890,
        .from = "0xfrom",
        .to = "0xto",
        .amount = 5000,
        .fee = 50,
        .tx_type = .transfer,
    };

    const json = try tx.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\":\"transfer\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"amount\":5000") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRYPOINT — testnet-explorer executable
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: testnet-explorer <command>", .{});
        std.log.err("Commands:", .{});
        std.log.err("  server <port>     - Start explorer HTTP server (default: 8080)", .{});
        std.log.err("  block <height>     - Get block by height", .{});
        std.log.err("  stats              - Get testnet statistics", .{});
        std.log.err("  nodes              - List all nodes", .{});
        std.log.err("  leaderboard <n>   - Get top n nodes (default: 50)", .{});
        std.process.exit(1);
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "server")) {
        const port = if (args.len > 2)
            try std.fmt.parseInt(u16, args[2], 10)
        else
            8080;
        var server = ExplorerServer.init(allocator, port);
        defer server.deinit();

        try server.start();
        std.log.info("Testnet explorer listening on port {d}", .{port});

        // Main loop - run until interrupted
        server.running = true;
        while (server.running) {
            std.Thread.sleep(1 * std.time.ns_per_s);
        }
    } else if (std.mem.eql(u8, command, "block")) {
        if (args.len < 3) {
            std.log.err("Usage: testnet-explorer block <height>", .{});
            std.process.exit(1);
        }
        const height = try std.fmt.parseInt(u64, args[2], 10);
        var server = ExplorerServer.init(allocator, 8080);
        defer server.deinit();

        const json = try server.handleGetBlock(height);
        defer allocator.free(json);
        std.log.info("{s}", .{json});
    } else if (std.mem.eql(u8, command, "stats")) {
        var server = ExplorerServer.init(allocator, 8080);
        defer server.deinit();

        const json = try server.handleGetStats();
        defer allocator.free(json);
        std.log.info("{s}", .{json});
    } else if (std.mem.eql(u8, command, "nodes")) {
        var server = ExplorerServer.init(allocator, 8080);
        defer server.deinit();

        const json = try server.handleGetNodes();
        defer allocator.free(json);
        std.log.info("{s}", .{json});
    } else if (std.mem.eql(u8, command, "leaderboard")) {
        const limit = if (args.len > 2)
            try std.fmt.parseInt(usize, args[2], 10)
        else
            50;
        var server = ExplorerServer.init(allocator, 8080);
        defer server.deinit();

        const json = try server.handleGetLeaderboard(limit);
        defer allocator.free(json);
        std.log.info("{s}", .{json});
    } else {
        std.log.err("Unknown command: {s}", .{command});
        std.process.exit(1);
    }
}
