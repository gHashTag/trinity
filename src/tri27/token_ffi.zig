// ═══════════════════════════════════════════════════════════════════════════════
// token_ffi.zig — Web3 Contract Calls and Blockchain Interaction
// ═══════════════════════════════════════════════════════════════════════════════
//
// Issue #442: Token FFI for TRI-27
//
// ERC20 interface + Web3 RPC calls for token operations
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const token_types = @import("token_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Web3 RPC and transaction errors
pub const Web3Error = enum(u8) {
    /// RPC call failed
    NetworkError = 0,
    /// Malformed RPC response
    InvalidResponse = 1,
    /// Contract call reverted
    TransactionReverted = 2,
    /// Transaction ran out of gas
    OutOfGas = 3,
    /// Account nonce too low
    NonceTooLow = 4,
    /// Insufficient ETH for gas
    InsufficientFunds = 5,
    /// Contract does not exist
    ContractNotFound = 6,
    /// Invalid private key format
    InvalidKey = 7,
    /// Signature verification failed
    InvalidSignature = 8,

    /// Convert error to description string
    pub fn description(self: Web3Error) []const u8 {
        return switch (self) {
            .NetworkError => "RPC call failed",
            .InvalidResponse => "Malformed RPC response",
            .TransactionReverted => "Contract call reverted",
            .OutOfGas => "Transaction ran out of gas",
            .NonceTooLow => "Account nonce too low",
            .InsufficientFunds => "Insufficient ETH for gas",
            .ContractNotFound => "Contract does not exist",
            .InvalidKey => "Invalid private key format",
            .InvalidSignature => "Signature verification failed",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// ERC20 token contract interface
pub const TokenContract = struct {
    /// Contract address (20 bytes)
    address: [20]u8,
    /// Web3 RPC endpoint URL
    rpc_url: []const u8,
    /// Chain ID for EIP-155 signing
    chain_id: u64,

    /// Create a new token contract reference
    pub fn init(address: [20]u8, rpc_url: []const u8, chain_id: u64) TokenContract {
        return .{
            .address = address,
            .rpc_url = rpc_url,
            .chain_id = chain_id,
        };
    }

    /// Format address as hex string (0x prefix)
    pub fn addressHex(self: *const TokenContract, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 42);
        defer result.deinit(allocator); // We'll use toOwnedSlice

        try result.appendSlice(allocator, "0x");
        for (self.address) |byte| {
            try std.fmt.formatInt(result.writer(allocator), byte, 16, .lower, .{ .width = 2, .fill = '0' });
        }
        return result.toOwnedSlice(allocator);
    }
};

/// Receipt of a blockchain transaction
pub const TransactionReceipt = struct {
    /// Transaction hash
    tx_hash: [32]u8,
    /// True if successful
    status: bool,
    /// Gas consumed by transaction
    gas_used: u64,
    /// Block number of transaction
    block_number: u64,
    /// Contract address (if contract creation)
    contract_address: ?[20]u8 = null,
    /// Logs bloom filter
    logs_bloom: [256]u8 = [_]u8{0} ** 256,

    /// Create receipt from raw data
    pub fn fromRaw(
        tx_hash: [32]u8,
        status: bool,
        gas_used: u64,
        block_number: u64,
    ) TransactionReceipt {
        return .{
            .tx_hash = tx_hash,
            .status = status,
            .gas_used = gas_used,
            .block_number = block_number,
        };
    }

    /// Format transaction hash as hex string
    pub fn txHashHex(self: *const TransactionReceipt, allocator: std.mem.Allocator) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 66);
        defer result.deinit(allocator);

        try result.appendSlice(allocator, "0x");
        for (self.tx_hash) |byte| {
            try std.fmt.formatInt(result.writer(allocator), byte, 16, .lower, .{ .width = 2, .fill = '0' });
        }
        return result.toOwnedSlice(allocator);
    }
};

/// Encoded contract method call
pub const ContractCall = struct {
    /// Target contract address
    to_address: [20]u8,
    /// Encoded function call data
    data: []const u8,
    /// ETH value to send (wei)
    value: u128 = 0,
    /// Gas limit (0 = estimate)
    gas_limit: u64 = 0,

    /// Create a new contract call
    pub fn init(to_address: [20]u8, data: []const u8) ContractCall {
        return .{
            .to_address = to_address,
            .data = data,
            .value = 0,
            .gas_limit = 0,
        };
    }

    /// Create a call with ETH value
    pub fn withValue(to_address: [20]u8, data: []const u8, value: u128) ContractCall {
        return .{
            .to_address = to_address,
            .data = data,
            .value = value,
            .gas_limit = 0,
        };
    }
};

/// Signed transaction ready for broadcast
pub const SignedTransaction = struct {
    /// Recipient address
    to_address: [20]u8,
    /// ETH value in wei
    value: u128,
    /// Transaction data
    data: []const u8,
    /// Gas limit
    gas_limit: u64,
    /// Gas price (or maxFeePerGas for EIP-1559)
    gas_price: u128,
    /// Account nonce
    nonce: u64,
    /// Chain ID
    chain_id: u64,
    /// ECDSA signature (r, s, v)
    signature: [65]u8,

    /// RLP encode the transaction for broadcast
    pub fn rlpEncode(self: *const SignedTransaction, alloc: std.mem.Allocator) ![]u8 {
        _ = alloc;
        // TODO: Implement RLP encoding
        return error.NotImplemented;
    }

    /// Get transaction hash (Keccak256 of RLP encoded)
    pub fn hash(self: *const SignedTransaction) [32]u8 {
        _ = self;
        // TODO: Implement Keccak256 hash
        return [_]u8{0} ** 32;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ABI ENCODING
// ═══════════════════════════════════════════════════════════════════════════════

/// ABI Encoder for Ethereum contract calls
pub const AbiEncoder = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) AbiEncoder {
        return .{
            .allocator = allocator,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *AbiEncoder) void {
        self.buffer.deinit(self.allocator);
    }

    /// Get encoded data (transfers ownership)
    pub fn toOwnedSlice(self: *AbiEncoder) ![]u8 {
        return self.buffer.toOwnedSlice(self.allocator);
    }

    /// Encode a function call with selector and parameters
    pub fn encodeCall(self: *AbiEncoder, func_name: []const u8, params: []const AbiValue) !void {
        // Generate function selector (first 4 bytes of Keccak256)
        const selector = try self.functionSelector(func_name);

        // Write selector
        try self.buffer.appendSlice(self.allocator, &selector);

        // Encode parameters
        for (params) |param| {
            try self.encodeValue(param);
        }
    }

    /// Generate function selector from function name
    fn functionSelector(self: *AbiEncoder, func_name: []const u8) ![4]u8 {
        // Simplified: use first 4 bytes of function name hash
        // In production, use full Keccak256(function_name + "()") signature
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(func_name, &hash, .{});

        // Take first 4 bytes
        return [4]u8{ hash[0], hash[1], hash[2], hash[3] };
    }

    /// Encode a single ABI value
    fn encodeValue(self: *AbiEncoder, value: AbiValue) !void {
        switch (value) {
            .address => |addr| {
                // Address is 20 bytes, left-padded to 32 bytes
                try self.buffer.appendNTimes(self.allocator, 0, 12);
                try self.buffer.appendSlice(self.allocator, &addr);
            },
            .uint => |n| {
                // uint256 as big-endian 32 bytes
                var buf: [32]u8 = undefined;
                std.mem.writeInt(u256, std.mem.bytesAsValue(u256, &buf), n, .big);
                try self.buffer.appendSlice(self.allocator, &buf);
            },
            .int => |n| {
                // int256 as two's complement big-endian 32 bytes
                var buf: [32]u8 = undefined;
                std.mem.writeInt(i256, std.mem.bytesAsValue(i256, &buf), n, .big);
                try self.buffer.appendSlice(self.allocator, &buf);
            },
            .bool => |b| {
                // bool as uint256 (0 or 1)
                try self.buffer.appendNTimes(self.allocator, 0, 31);
                try self.buffer.append(if (b) 1 else 0);
            },
            .bytes => |bytes| {
                // Dynamic bytes: length + data
                // Offset would be calculated for multiple params
                var buf: [32]u8 = undefined;
                std.mem.writeInt(u256, std.mem.bytesAsValue(u256, &buf), bytes.len, .big);
                try self.buffer.appendSlice(self.allocator, &buf);

                // Pad data to 32-byte boundary
                try self.buffer.appendSlice(self.allocator, bytes);
                const padding = (32 - (bytes.len % 32)) % 32;
                try self.buffer.appendNTimes(self.allocator, 0, padding);
            },
        }
    }
};

/// ABI value types
pub const AbiValue = union(enum) {
    address: [20]u8,
    uint: u256,
    int: i256,
    bool: bool,
    bytes: []const u8,
};

/// Compute Keccak256 hash (simplified - uses SHA256 as placeholder)
pub fn keccak256(data: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &result, .{});
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RPC CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

/// Web3 RPC client for blockchain interaction
pub const RpcClient = struct {
    allocator: std.mem.Allocator,
    rpc_url: []const u8,
    request_id: u64,

    pub fn init(allocator: std.mem.Allocator, rpc_url: []const u8) RpcClient {
        return .{
            .allocator = allocator,
            .rpc_url = rpc_url,
            .request_id = 0,
        };
    }

    /// Get current transaction count (nonce) for an address
    pub fn getNonce(self: *RpcClient, address: [20]u8) !u64 {
        _ = self;
        _ = address;
        // TODO: Implement eth_getTransactionCount RPC call
        return error.NotImplemented;
    }

    /// Estimate gas for a transaction
    pub fn estimateGas(self: *RpcClient, to: [20]u8, data: []const u8, value: u128) !u64 {
        _ = self;
        _ = to;
        _ = data;
        _ = value;
        // TODO: Implement eth_estimateGas RPC call
        return error.NotImplemented;
    }

    /// Send raw transaction
    pub fn sendRawTransaction(self: *RpcClient, signed_tx: []const u8) ![32]u8 {
        _ = self;
        _ = signed_tx;
        // TODO: Implement eth_sendRawTransaction RPC call
        return error.NotImplemented;
    }

    /// Get transaction receipt
    pub fn getTransactionReceipt(self: *RpcClient, tx_hash: [32]u8) !?TransactionReceipt {
        _ = self;
        _ = tx_hash;
        // TODO: Implement eth_getTransactionReceipt RPC call
        return error.NotImplemented;
    }

    /// Call contract (read-only, no gas cost)
    pub fn call(self: *RpcClient, to: [20]u8, data: []const u8) ![]u8 {
        _ = self;
        _ = to;
        _ = data;
        // TODO: Implement eth_call RPC call
        return error.NotImplemented;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL CONTRACT FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// ERC20 token operations
pub const Erc20Ops = struct {
    allocator: std.mem.Allocator,
    contract: TokenContract,
    rpc: RpcClient,

    pub fn init(allocator: std.mem.Allocator, contract: TokenContract) Erc20Ops {
        return .{
            .allocator = allocator,
            .contract = contract,
            .rpc = RpcClient.init(allocator, contract.rpc_url),
        };
    }

    /// Read token balance for an address
    pub fn balanceOf(self: *Erc20Ops, address: [20]u8) !u128 {
        // Encode balanceOf(address) call
        var encoder = AbiEncoder.init(self.allocator);
        defer encoder.deinit();

        // balanceOf selector: 0x70a08231
        const selector = [4]u8{ 0x70, 0xa0, 0x82, 0x31 };
        try encoder.buffer.appendSlice(self.allocator, &selector);

        // Encode address parameter
        try encoder.encodeValue(.{ .address = address });

        const call_data = try encoder.toOwnedSlice();
        defer self.allocator.free(call_data);

        // Execute call
        const result = try self.rpc.call(self.contract.address, call_data);
        defer self.allocator.free(result);

        // Decode u128 from result (last 16 bytes of 32-byte word)
        if (result.len < 32) return error.InvalidResponse;
        const balance_bytes = result[result.len - 16 ..];
        return std.mem.readInt(u128, balance_bytes[0..16], .big);
    }

    /// Encode transfer(to, amount) call
    pub fn encodeTransfer(self: *Erc20Ops, to: [20]u8, amount: u128) ![]u8 {
        var encoder = AbiEncoder.init(self.allocator);
        defer encoder.deinit();

        // transfer selector: 0xa9059cbb
        const selector = [4]u8{ 0xa9, 0x90, 0x59, 0xcb };
        try encoder.buffer.appendSlice(self.allocator, &selector);

        // Encode to address
        try encoder.encodeValue(.{ .address = to });

        // Encode amount
        try encoder.encodeValue(.{ .uint = @intCast(amount) });

        return encoder.toOwnedSlice();
    }

    /// Encode approve(spender, amount) call
    pub fn encodeApprove(self: *Erc20Ops, spender: [20]u8, amount: u128) ![]u8 {
        var encoder = AbiEncoder.init(self.allocator);
        defer encoder.deinit();

        // approve selector: 0x095ea7b3
        const selector = [4]u8{ 0x09, 0x5e, 0xa7, 0xb3 };
        try encoder.buffer.appendSlice(self.allocator, &selector);

        // Encode spender address
        try encoder.encodeValue(.{ .address = spender });

        // Encode amount
        try encoder.encodeValue(.{ .uint = @intCast(amount) });

        return encoder.toOwnedSlice();
    }
};

/// TRI-27 specific contract operations (staking, rewards)
pub const Tri27Ops = struct {
    allocator: std.mem.Allocator,
    contract: TokenContract,
    rpc: RpcClient,

    pub fn init(allocator: std.mem.Allocator, contract: TokenContract) Tri27Ops {
        return .{
            .allocator = allocator,
            .contract = contract,
            .rpc = RpcClient.init(allocator, contract.rpc_url),
        };
    }

    /// Encode stake(amount, lock_period_days) call
    pub fn encodeStake(self: *Tri27Ops, amount: u128, lock_period_days: u64) ![]u8 {
        var encoder = AbiEncoder.init(self.allocator);
        defer encoder.deinit();

        // Custom selector (would be from actual contract)
        const selector = [4]u8{ 0x00, 0x00, 0x00, 0x01 };
        try encoder.buffer.appendSlice(self.allocator, &selector);

        // Encode amount
        try encoder.encodeValue(.{ .uint = @intCast(amount) });

        // Encode lock period
        try encoder.encodeValue(.{ .uint = @intCast(lock_period_days) });

        return encoder.toOwnedSlice();
    }

    /// Encode unstake() call
    pub fn encodeUnstake(self: *Tri27Ops) ![]u8 {
        const allocator = self.allocator;
        var result = try std.ArrayList(u8).initCapacity(allocator, 4);
        defer result.deinit(allocator);

        // Custom selector
        const selector = [4]u8{ 0x00, 0x00, 0x00, 0x02 };
        try result.appendSlice(allocator, &selector);

        return result.toOwnedSlice();
    }

    /// Encode claimRewards() call
    pub fn encodeClaimRewards(self: *Tri27Ops) ![]u8 {
        const allocator = self.allocator;
        var result = try std.ArrayList(u8).initCapacity(allocator, 4);
        defer result.deinit(allocator);

        // Custom selector
        const selector = [4]u8{ 0x00, 0x00, 0x00, 0x03 };
        try result.appendSlice(allocator, &selector);

        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADDRESS UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse hex address string to [20]u8
pub fn parseAddress(hex: []const u8) ![20]u8 {
    var result: [20]u8 = undefined;

    const clean_hex = if (std.mem.startsWith(u8, hex, "0x")) hex[2..] else hex;

    if (clean_hex.len != 40) return error.InvalidAddressLength;

    for (0..20) |i| {
        const byte_hex = clean_hex[i * 2 .. i * 2 + 2];
        result[i] = try std.fmt.parseInt(u8, byte_hex, 16);
    }

    return result;
}

/// Format [20]u8 address as hex string with 0x prefix
pub fn formatAddress(address: [20]u8, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 42);
    defer result.deinit(allocator);

    try result.appendSlice(allocator, "0x");
    for (address) |byte| {
        try std.fmt.formatInt(result.writer(allocator), byte, 16, .lower, .{ .width = 2, .fill = '0' });
    }

    return result.toOwnedSlice(allocator);
}

/// Check if address is valid (20 bytes, non-zero)
pub fn isValidAddress(address: [20]u8) bool {
    // Check if address is all zeros
    var is_zero = true;
    for (address) |byte| {
        if (byte != 0) {
            is_zero = false;
            break;
        }
    }
    return !is_zero;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE KEY AND SIGNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Wallet for signing transactions
pub const Wallet = struct {
    private_key: [32]u8,
    address: [20]u8,

    /// Create wallet from private key
    pub fn fromPrivateKey(private_key: [32]u8) !Wallet {
        // Derive address from private key
        const address = try privateKeyToAddress(private_key);
        return .{
            .private_key = private_key,
            .address = address,
        };
    }

    /// Derive address from private key (simplified)
    fn privateKeyToAddress(private_key: [32]u8) ![20]u8 {
        _ = private_key;
        // TODO: Implement ECDSA public key derivation + Keccak256
        return error.NotImplemented;
    }

    /// Sign a transaction
    pub fn signTransaction(self: *const Wallet, tx: ContractCall, chain_id: u64, nonce: u64, gas_limit: u64, gas_price: u128) !SignedTransaction {
        _ = self;
        _ = tx;
        _ = chain_id;
        _ = nonce;
        _ = gas_limit;
        _ = gas_price;
        // TODO: Implement ECDSA signing
        return error.NotImplemented;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Common function selectors for ERC20
pub const Erc20Selectors = struct {
    pub const balanceOf = [4]u8{ 0x70, 0xa0, 0x82, 0x31 };
    pub const transfer = [4]u8{ 0xa9, 0x05, 0x9c, 0xbb };
    pub const approve = [4]u8{ 0x09, 0x5e, 0xa7, 0xb3 };
    pub const allowance = [4]u8{ 0xdd, 0xf2, 0x52, 0xad };
    pub const totalSupply = [4]u8{ 0x18, 0x16, 0x0d, 0xdd };
    pub const transferFrom = [4]u8{ 0x23, 0xb8, 0x72, 0xdd };
};

/// Gas limits for common operations
pub const GasLimits = struct {
    pub const transfer: u64 = 65_000;
    pub const approve: u64 = 46_000;
    pub const stake: u64 = 100_000;
    pub const unstake: u64 = 80_000;
    pub const claim_rewards: u64 = 70_000;
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Web3Error description returns correct string" {
    const err = Web3Error.NetworkError;
    try std.testing.expectEqualStrings("RPC call failed", err.description());
}

test "parseAddress parses valid hex" {
    const hex = "0x1234567890123456789012345678901234567890";
    const result = try parseAddress(hex);
    try std.testing.expectEqual(@as(u8, 0x12), result[0]);
    try std.testing.expectEqual(@as(u8, 0x34), result[1]);
    try std.testing.expectEqual(@as(u8, 0x90), result[19]);
}

test "parseAddress rejects wrong length" {
    const hex = "0x1234";
    try std.testing.expectError(error.InvalidAddressLength, parseAddress(hex));
}

test "parseAddress works without 0x prefix" {
    const hex = "1234567890123456789012345678901234567890";
    const result = try parseAddress(hex);
    try std.testing.expectEqual(@as(u8, 0x12), result[0]);
}

test "formatAddress formats with 0x prefix" {
    const addr = [_]u8{0x12} ++ [_]u8{0x34} ** 19;
    const result = try formatAddress(addr, std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("0x1234343434343434343434343434343434343434", result);
}

test "isValidAddress rejects zero address" {
    const zero_addr = [20]u8{0} ** 20;
    try std.testing.expect(!isValidAddress(zero_addr));
}

test "isValidAddress accepts non-zero address" {
    const addr = [20]u8{0x12} ++ [19]u8{0x34};
    try std.testing.expect(isValidAddress(addr));
}

test "TokenContract init creates contract" {
    const addr = [20]u8{0x12} ++ [19]u8{0x34};
    const contract = TokenContract.init(addr, "https://eth.sepia.io", 11155111);
    try std.testing.expectEqual(addr, contract.address);
    try std.testing.expectEqualStrings("https://eth.sepia.io", contract.rpc_url);
    try std.testing.expectEqual(@as(u64, 11155111), contract.chain_id);
}

test "TokenContract addressHex formats correctly" {
    const addr = [20]u8{0x00} ++ [19]u8{0xAB};
    const contract = TokenContract.init(addr, "https://eth.sepia.io", 1);
    const result = try contract.addressHex(std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 42), result.len);
    try std.testing.expectEqualStrings("0x00", result[0..2]);
}

test "TransactionReceipt fromRaw creates receipt" {
    const tx_hash = [32]u8{0x01} ** 32;
    const receipt = TransactionReceipt.fromRaw(tx_hash, true, 50_000, 12345);
    try std.testing.expectEqual(tx_hash, receipt.tx_hash);
    try std.testing.expect(receipt.status);
    try std.testing.expectEqual(@as(u64, 50_000), receipt.gas_used);
    try std.testing.expectEqual(@as(u64, 12345), receipt.block_number);
}

test "ContractCall init creates call" {
    const addr = [20]u8{0x12} ** 20;
    const data = "test_data";
    const call = ContractCall.init(addr, data);
    try std.testing.expectEqual(addr, call.to_address);
    try std.testing.expectEqualStrings(data, call.data);
    try std.testing.expectEqual(@as(u128, 0), call.value);
}

test "ContractCall withValue creates call with ETH" {
    const addr = [20]u8{0x12} ** 20;
    const data = "test_data";
    const call = ContractCall.withValue(addr, data, 1_000_000_000);
    try std.testing.expectEqual(@as(u128, 1_000_000_000), call.value);
}

test "keccak256 returns 32 bytes" {
    const data = "test";
    const hash = keccak256(data);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
    // Non-zero hash (SHA256 in this simplified version)
    var has_non_zero = false;
    for (hash) |byte| {
        if (byte != 0) {
            has_non_zero = true;
            break;
        }
    }
    try std.testing.expect(has_non_zero);
}

test "Erc20Ops encodeTransfer generates correct selector" {
    const allocator = std.testing.allocator;
    const addr = [20]u8{0x12} ** 20;
    const contract = TokenContract.init(addr, "https://test.rpc", 1);
    var ops = Erc20Ops.init(allocator, contract);

    const to = [20]u8{0xAB} ** 20;
    const amount: u128 = 1_000_000_000;
    const encoded = try ops.encodeTransfer(to, amount);
    defer allocator.free(encoded);

    // Should start with transfer selector
    try std.testing.expectEqual(@as(u8, 0xa9), encoded[0]);
    try std.testing.expectEqual(@as(u8, 0x90), encoded[1]);
    try std.testing.expectEqual(@as(u8, 0x59), encoded[2]);
    try std.testing.expectEqual(@as(u8, 0xcb), encoded[3]);
}

test "Erc20Ops encodeApprove generates correct selector" {
    const allocator = std.testing.allocator;
    const addr = [20]u8{0x12} ** 20;
    const contract = TokenContract.init(addr, "https://test.rpc", 1);
    var ops = Erc20Ops.init(allocator, contract);

    const spender = [20]u8{0xAB} ** 20;
    const amount: u128 = 1_000_000_000;
    const encoded = try ops.encodeApprove(spender, amount);
    defer allocator.free(encoded);

    // Should start with approve selector
    try std.testing.expectEqual(@as(u8, 0x09), encoded[0]);
    try std.testing.expectEqual(@as(u8, 0x5e), encoded[1]);
    try std.testing.expectEqual(@as(u8, 0xa7), encoded[2]);
    try std.testing.expectEqual(@as(u8, 0xb3), encoded[3]);
}

test "Tri27Ops encodeStake generates correct format" {
    const allocator = std.testing.allocator;
    const addr = [20]u8{0x12} ** 20;
    const contract = TokenContract.init(addr, "https://test.rpc", 1);
    var ops = Tri27Ops.init(allocator, contract);

    const amount: u128 = 100_000_000_000_000_000_000;
    const lock_days: u64 = 30;
    const encoded = try ops.encodeStake(amount, lock_days);
    defer allocator.free(encoded);

    // Should have selector + 2 x 32-byte parameters
    try std.testing.expectEqual(@as(usize, 68), encoded.len);
}

test "Tri27Ops encodeUnstake generates selector only" {
    const allocator = std.testing.allocator;
    const addr = [20]u8{0x12} ** 20;
    const contract = TokenContract.init(addr, "https://test.rpc", 1);
    var ops = Tri27Ops.init(allocator, contract);

    const encoded = try ops.encodeUnstake();
    defer allocator.free(encoded);

    // Should just be 4-byte selector
    try std.testing.expectEqual(@as(usize, 4), encoded.len);
}

test "Tri27Ops encodeClaimRewards generates selector only" {
    const allocator = std.testing.allocator;
    const addr = [20]u8{0x12} ** 20;
    const contract = TokenContract.init(addr, "https://test.rpc", 1);
    var ops = Tri27Ops.init(allocator, contract);

    const encoded = try ops.encodeClaimRewards();
    defer allocator.free(encoded);

    // Should just be 4-byte selector
    try std.testing.expectEqual(@as(usize, 4), encoded.len);
}

test "GasLimits have sensible values" {
    try std.testing.expect(GasLimits.transfer < 100_000);
    try std.testing.expect(GasLimits.approve < 100_000);
    try std.testing.expect(GasLimits.stake >= 100_000);
    try std.testing.expect(GasLimits.unstake >= 80_000);
    try std.testing.expect(GasLimits.claim_rewards >= 70_000);
}
