// @origin(spec:depin_rpc_client.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// Phase 4: Testnet Preparation - Trinity Chain RPC Client
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// JSON-RPC 2.0 TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const JsonRpcRequest = struct {
    jsonrpc: []const u8 = "2.0",
    id: u64,
    method: []const u8,
    params: ?[]const JsonValue = null,
};

pub const JsonRpcResponse = struct {
    jsonrpc: []const u8,
    id: u64,
    result: ?JsonValue,
    rpc_error: ?JsonRpcError,
};

pub const JsonRpcError = struct {
    code: i32,
    message: []const u8,
    data: ?JsonValue = null,
};

pub const JsonValue = union(enum) {
    null,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    array: []const JsonValue,
    object: std.StringHashMapUnmanaged(JsonValue),
};

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCKCHAIN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Address = [20]u8;

pub const Balance = struct {
    amount: u128,
    formatted: f64,

    pub fn formatTRI(amount: u128) f64 {
        return @as(f64, @floatFromInt(amount)) / 1e18;
    }
};

pub const Block = struct {
    number: u64,
    hash: []const u8,
    parent_hash: []const u8,
    timestamp: u64,
    transactions: []Transaction,
    gas_used: u64,
};

pub const Transaction = struct {
    hash: []const u8,
    from: Address,
    to: Address,
    value: u128,
    gas_limit: u64,
    gas_used: u64,
    block_number: u64,
};

pub const LogEntry = struct {
    address: Address,
    topics: []const [32]u8,
    data: []const u8,
    block_number: u64,
    transaction_hash: []const u8,
};

pub const TransactionReceipt = struct {
    tx_hash: []const u8,
    block_number: u64,
    gas_used: u64,
    status: bool, // true = success, false = failure
    contract_address: ?Address,
    logs: []LogEntry,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RPC CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const RpcClient = struct {
    allocator: Allocator,
    url: []const u8,
    request_id: u64,
    chain_id: u64,

    const TRI_DECIMALS: u8 = 18;
    const REQUEST_TIMEOUT_MS: u64 = 10000;

    pub fn init(allocator: Allocator, url: []const u8, chain_id: u64) RpcClient {
        return RpcClient{
            .allocator = allocator,
            .url = url,
            .request_id = 0,
            .chain_id = chain_id,
        };
    }

    /// Get balance of an address
    pub fn getBalance(self: *RpcClient, address: Address) !Balance {
        const address_hex = try self.addressToHex(address);
        defer self.allocator.free(address_hex);

        const result = try self.call("eth_getBalance", &.{
            JsonValue{ .string = address_hex },
            JsonValue{ .string = "latest" },
        });

        const balance_hex = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        const amount = try std.fmt.parseInt(u128, balance_hex[2..], 16);
        return Balance{
            .amount = amount,
            .formatted = Balance.formatTRI(amount),
        };
    }

    /// Get block by number
    pub fn getBlock(self: *RpcClient, block_number: u64) !Block {
        const block_hex = try std.fmt.allocPrint(self.allocator, "0x{x}", .{block_number});
        defer self.allocator.free(block_hex);

        _ = try self.call("eth_getBlockByNumber", &.{
            JsonValue{ .string = block_hex },
            JsonValue{ .boolean = true }, // Include transactions
        });

        // Simplified parsing - in production, proper JSON parsing needed
        return Block{
            .number = block_number,
            .hash = "",
            .parent_hash = "",
            .timestamp = 0,
            .transactions = &.{},
            .gas_used = 0,
        };
    }

    /// Get transaction count (nonce)
    pub fn getTransactionCount(self: *RpcClient, address: Address) !u64 {
        const address_hex = try self.addressToHex(address);
        defer self.allocator.free(address_hex);

        const result = try self.call("eth_getTransactionCount", &.{
            JsonValue{ .string = address_hex },
            JsonValue{ .string = "latest" },
        });

        const nonce_hex = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        return std.fmt.parseInt(u64, nonce_hex[2..], 16);
    }

    /// Get latest block number
    pub fn getBlockNumber(self: *RpcClient) !u64 {
        const result = try self.call("eth_blockNumber", &.{});

        const block_hex = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        return std.fmt.parseInt(u64, block_hex[2..], 16);
    }

    /// Call contract method (simplified)
    pub fn callContract(
        self: *RpcClient,
        contract_address: Address,
        data: []const u8,
    ) ![]const u8 {
        const address_hex = try self.addressToHex(contract_address);
        defer self.allocator.free(address_hex);

        const data_hex = try self.bytesToHex(data);
        defer self.allocator.free(data_hex);

        const result = try self.call("eth_call", &.{
            JsonValue{ .object = try self.createCallObject(self.allocator, address_hex, data_hex) },
            JsonValue{ .string = "latest" },
        });

        const return_data = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        return self.hexToBytes(return_data);
    }

    /// Get logs for an event
    pub fn getLogs(
        self: *RpcClient,
        contract_address: Address,
        from_block: u64,
        to_block: u64,
    ) ![]LogEntry {
        const address_hex = try self.addressToHex(contract_address);
        defer self.allocator.free(address_hex);

        const from_hex = try std.fmt.allocPrint(self.allocator, "0x{x}", .{from_block});
        defer self.allocator.free(from_hex);

        const to_hex = try std.fmt.allocPrint(self.allocator, "0x{x}", .{to_block});
        defer self.allocator.free(to_hex);

        _ = try self.call("eth_getLogs", &.{
            JsonValue{ .object = try self.createFilterObject(self.allocator, address_hex, from_hex, to_hex) },
        });

        // Simplified - return empty array for now
        return &.{};
    }

    /// Verify stake on-chain
    pub fn verifyStake(self: *RpcClient, staker_address: Address) !bool {
        // In production, call actual staking contract
        // For now, return true if balance > 100 TRI
        const balance = try self.getBalance(staker_address);
        return balance.amount >= 100 * std.math.pow(u128, 10, TRI_DECIMALS);
    }

    /// Get chain ID
    pub fn getChainId(self: *RpcClient) !u64 {
        const result = try self.call("eth_chainId", &.{});

        const chain_hex = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        return std.fmt.parseInt(u64, chain_hex[2..], 16);
    }

    /// Send raw transaction
    pub fn sendRawTransaction(self: *RpcClient, raw_tx: []const u8) ![]const u8 {
        const tx_hex = try self.bytesToHex(raw_tx);
        defer self.allocator.free(tx_hex);

        const result = try self.call("eth_sendRawTransaction", &.{
            JsonValue{ .string = tx_hex },
        });

        const tx_hash = switch (result) {
            .string => |s| try self.allocator.dupe(u8, s),
            else => return error.InvalidResponseType,
        };

        return tx_hash;
    }

    /// Estimate gas for transaction
    pub fn estimateGas(
        self: *RpcClient,
        from: Address,
        to: Address,
        value: u128,
        data: []const u8,
    ) !u64 {
        _ = value;
        _ = data;

        const from_hex = try self.addressToHex(from);
        defer self.allocator.free(from_hex);

        const to_hex = try self.addressToHex(to);
        defer self.allocator.free(to_hex);

        const result = try self.call("eth_estimateGas", &.{
            JsonValue{ .object = try self.createTxObject(self.allocator, from_hex, to_hex) },
        });

        const gas_hex = switch (result) {
            .string => |s| s,
            else => return error.InvalidResponseType,
        };

        return std.fmt.parseInt(u64, gas_hex[2..], 16);
    }

    /// Get transaction receipt
    pub fn getTransactionReceipt(self: *RpcClient, tx_hash: []const u8) !?TransactionReceipt {
        _ = tx_hash;

        // Call eth_getTransactionReceipt
        const result = try self.call("eth_getTransactionReceipt", &.{});

        // For mock implementation: return null (pending)
        // In production: parse JSON response
        return null;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ═════════════════════════════════════════════════════════════════════════

    fn call(self: *RpcClient, method: []const u8, params: []const JsonValue) !JsonValue {
        _ = params;
        _ = method;
        _ = self;

        // In production: actual HTTP request to RPC endpoint
        // For now: return mock response
        return JsonValue{ .string = "0x0" };
    }

    fn addressToHex(self: *RpcClient, address: Address) ![]const u8 {
        var hex = try self.allocator.alloc(u8, 42);
        hex[0] = '0';
        hex[1] = 'x';
        for (address, 0..) |byte, i| {
            const high = byte >> 4;
            const low = byte & 0x0F;
            hex[2 + i * 2] = if (high < 10) '0' + high else 'a' + high - 10;
            hex[3 + i * 2] = if (low < 10) '0' + low else 'a' + low - 10;
        }
        return hex;
    }

    fn bytesToHex(self: *RpcClient, bytes: []const u8) ![]const u8 {
        var hex = try self.allocator.alloc(u8, bytes.len * 2 + 2);
        hex[0] = '0';
        hex[1] = 'x';
        for (bytes, 0..) |byte, i| {
            const high = byte >> 4;
            const low = byte & 0x0F;
            hex[2 + i * 2] = if (high < 10) '0' + high else 'a' + high - 10;
            hex[3 + i * 2] = if (low < 10) '0' + low else 'a' + low - 10;
        }
        return hex;
    }

    fn hexToBytes(self: *RpcClient, hex: []const u8) ![]const u8 {
        const has_prefix = hex.len >= 2 and hex[0] == '0' and hex[1] == 'x';
        const start = if (has_prefix) @as(usize, 2) else 0;
        const byte_count = (hex.len - start) / 2;

        var bytes = try self.allocator.alloc(u8, byte_count);
        for (0..byte_count) |i| {
            const high = std.fmt.charToDigit(hex[start + i * 2], 16) catch return error.InvalidHex;
            const low = std.fmt.charToDigit(hex[start + i * 2 + 1], 16) catch return error.InvalidHex;
            bytes[i] = @as(u8, @intCast(high * 16 + low));
        }
        return bytes;
    }

    fn createCallObject(
        allocator: Allocator,
        to: []const u8,
        data: []const u8,
    ) !std.StringHashMapUnmanaged(JsonValue) {
        var obj = std.StringHashMapUnmanaged(JsonValue){};
        try obj.put(allocator, "to", JsonValue{ .string = to });
        try obj.put(allocator, "data", JsonValue{ .string = data });
        return obj;
    }

    fn createFilterObject(
        allocator: Allocator,
        address: []const u8,
        from_block: []const u8,
        to_block: []const u8,
    ) !std.StringHashMapUnmanaged(JsonValue) {
        var obj = std.StringHashMapUnmanaged(JsonValue){};
        try obj.put(allocator, "address", JsonValue{ .string = address });
        try obj.put(allocator, "fromBlock", JsonValue{ .string = from_block });
        try obj.put(allocator, "toBlock", JsonValue{ .string = to_block });
        return obj;
    }

    fn createTxObject(
        allocator: Allocator,
        from: []const u8,
        to: []const u8,
    ) !std.StringHashMapUnmanaged(JsonValue) {
        var obj = std.StringHashMapUnmanaged(JsonValue){};
        try obj.put(allocator, "from", JsonValue{ .string = from });
        try obj.put(allocator, "to", JsonValue{ .string = to });
        return obj;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RpcClient init" {
    const allocator = std.testing.allocator;
    const client = RpcClient.init(allocator, "http://localhost:8545", 1337);
    try std.testing.expectEqual(@as(u64, 1337), client.chain_id);
    try std.testing.expectEqual(@as(usize, 21), client.url.len);
}

test "RpcClient addressToHex" {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, "http://localhost:8545", 1337);

    var address: Address = undefined;
    @memset(&address, 0);

    const hex = try client.addressToHex(address);
    defer allocator.free(hex);

    try std.testing.expectEqual(@as(usize, 42), hex.len);
    try std.testing.expectEqualStrings("0x0000000000000000000000000000000000000000", hex);
}

test "RpcClient hexToBytes" {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, "http://localhost:8545", 1337);

    const bytes = try client.hexToBytes("0x0102abcd");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
    try std.testing.expectEqual(@as(u8, 0x01), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0x02), bytes[1]);
    try std.testing.expectEqual(@as(u8, 0xab), bytes[2]);
    try std.testing.expectEqual(@as(u8, 0xcd), bytes[3]);
}

test "Balance formatTRI" {
    const amount: u128 = 1_000_000_000_000_000_000; // 1 TRI
    const formatted = Balance.formatTRI(amount);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), formatted, 0.0001);
}

test "RpcClient getTransactionCount" {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, "http://localhost:8545", 1337);

    var address: Address = undefined;
    @memset(&address, 0);

    // Returns 0 for mock implementation
    const nonce = try client.getTransactionCount(address);
    try std.testing.expectEqual(@as(u64, 0), nonce);
}
