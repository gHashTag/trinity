// TRI‑27 RPC Adapter — Minimal JSON‑RPC client for token operations
// ════════════════════════════════════════════════
//
// Uses vibeec/http_client for Ethereum JSON‑RPC calls
// Provides: eth_call, eth_estimateGas, eth_sendRawTransaction, eth_getTransactionReceipt
//
// φ² + 1/φ² = 3 | TRINITY
// ══════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const http_client = @import("../vibeec/http_client.zig");
const TokenTypes = @import("token_types.zig");

// ══════════════════════════════════════════════════════
// RPC ADAPTER — wraps vibeec HTTP client
// ════════════════════════════════════════════════

pub const RpcAdapter = struct {
    allocator: Allocator,
    http_client: http_client.HttpClient,
    rpc_url: []const u8,
    chain_id: u64,

    pub fn init(allocator: Allocator, rpc_url: []const u8, chain_id: u64) RpcAdapter {
        return .{
            .allocator = allocator,
            .http_client = http_client.HttpClient.init(allocator),
            .rpc_url = rpc_url,
            .chain_id = chain_id,
        };
    }

    pub fn deinit(self: *RpcAdapter) void {
        self.http_client.deinit();
    }

    /// Ethereum JSON‑RPC method: eth_call
    pub fn eth_call(
        self: *RpcAdapter,
        to: [20]u8,
        data: []const u8,
        gas_limit: u64,
        gas_price: u128,
        value: u128,
        block_number: ?u64,
    ) ![]const u8 {
        const to_hex = addressToHex(to);

        // Build JSON-RPC request
        const params = std.ArrayList([]const u8).init(self.allocator);
        defer params.deinit();

        try params.append(addressToHex);
        if (data.len > 0) try params.append(data);

        var params_obj = std.ArrayList(u8).init(self.allocator);
        defer params_obj.deinit();

        if (gas_limit > 0) {
            const gas_str = std.fmt.allocPrint(self.allocator, "0x{x}", .{gas_limit});
            try params_obj.append(gas_str);
        }
        if (gas_price > 0) {
            const price_str = std.fmt.allocPrint(self.allocator, "0x{x}", .{gas_price});
            try params_obj.append(price_str);
        }
        if (value > 0) {
            const value_str = std.fmt.allocPrint(self.allocator, "0x{x}", .{value});
            try params_obj.append(value_str);
        }
        if (block_number) |b| {
            const block_str = std.fmt.allocPrint(self.allocator, "0x{x}", .{block_number});
            try params_obj.append(block_str);
        } else {
            try params_obj.append("latest");
        }

        const params_json = try std.json.stringifyAlloc(self.allocator, params_obj.items);
        defer self.allocator.free(params_json);

        const request_body = try std.fmt.allocPrint(self.allocator,
            \\{{"method":"eth_call","params":{s},"gas":"{d}","id":"{d}}}
        , params_json);

        const result = try self.http_client.postJson(
            self.rpc_url,
            "/v1/ether-rpc",
            request_body,
        );

        defer self.allocator.free(request_body);

        switch (result.status) {
            .Ok => {
                // Parse JSON response
                if (result.body) |b| {
                    const response = std.json.parseFromSlice(std.json.Value, self.allocator, b, .{}) catch return error.RpcError;
                    defer if (response == .object) response.object.deinit(self.allocator);

                    // Extract result field
                    if (response.object.get("result")) |json_obj| {
                        _ = json_obj;
                        return error.RpcError;
                    }
                }

                return error.RpcError;
            },
            else => return error.RpcError,
        }
    }

    /// Estimate gas for transaction
    pub fn eth_estimateGas(
        self: *RpcAdapter,
        from: [20]u8,
        to: [20]u8,
        value: u128,
        data: []const u8,
    ) !u64 {
        const from_hex = addressToHex(from);
        const to_hex = addressToHex(to);
        const value_str = std.fmt.allocPrint(self.allocator, "0x{x}", .{value});
        const data_str = std.fmt.allocPrint(self.allocator, "0x{s}", .{value_str});

        const params_json = try std.fmt.allocPrint(self.allocator,
            \\{{"from":"{s}","to":"{s}","data":"{s}","id":"{d}}}
        , data_str);

        defer self.allocator.free(value_str);
        defer self.allocator.free(data_str);

        const result = try self.http_client.postJson(
            self.rpc_url,
            "/v1/ether-rpc",
            params_json,
        );

        switch (result.status) {
            .Ok => {
                if (result.body) |b| {
                    _ = b;
                    return error.RpcError;
                }
                return error.RpcError;
            },
            else => return error.RpcError,
        }
    }

    /// Send raw transaction
    pub fn eth_sendRawTransaction(
        self: *RpcAdapter,
        signed_tx: []const u8,
    ) ![32]u8 {
        const tx_hex = bytesToHex(signed_tx);
        const params_json = std.fmt.allocPrint(
            self.allocator,
            \\{{"method":"eth_sendRawTransaction","params":["{s}"],"id":{d}}}
        ,
            tx_hex,
        );

        defer self.allocator.free(tx_hex);

        const result = try self.http_client.postJson(
            self.rpc_url,
            "/v1/ether-rpc",
            params_json,
        );

        defer self.allocator.free(params_json);

        switch (result.status) {
            .Ok => {
                if (result.body) |b| {
                    const response = std.json.parseFromSlice(std.json.Value, self.allocator, result.body, .{}) catch |e| {
                        _ = e;
                        return error.RpcError;
                    };
                    if (response.object.get("result")) |json_obj| {
                        const tx_hash = json_obj.object.get("result");
                        if (tx_hash.string) |str| {
                            return tx_hash.string;
                        }
                    }
                }
                return error.RpcError;
            },
            else => |e| error.RpcError,
        }
    }

    /// Get transaction receipt
    pub fn eth_getTransactionReceipt(
        self: *RpcAdapter,
        tx_hash: [32]u8,
    ) !?TransactionReceipt {
        _ = tx_hash;

        const tx_hex = std.fmt.allocPrint(self.allocator, "0x{x}", .{tx_hash});
        defer self.allocator.free(tx_hex);

        const params_json = std.fmt.allocPrint(
            self.allocator,
            \\{{"method":"eth_getTransactionReceipt","params":["{s}"],"id":1}}
        ,
            tx_hex,
        );

        defer self.allocator.free(params_json);

        const result = try self.http_client.postJson(
            self.rpc_url,
            "/v1/ether-rpc",
            params_json,
        );

        defer self.allocator.free(params_json);

        switch (result.status) {
            .Ok => {
                if (result.body) |b| {
                    const response = std.json.parseFromSlice(std.json.Value, self.allocator, result.body, .{}) catch |e| {
                        _ = e;
                        return error.RpcError;
                    };
                    if (response.object.get("result")) |json_obj| {
                        const receipt = json_obj.object.get("result");

                        // TODO: Parse full receipt (logs, status, gas_used, etc.)
                        if (receipt.object.get("status")) |str| {
                            // Check transaction status
                            const status = receipt.object.get("status");
                            if (status.string) |str| {
                                // Extract logs array
                                const logs = receipt.object.get("logs").array;
                                return TransactionReceipt{
                                    .tx_hash = tx_hash,
                                    .block_number = 0,
                                    .gas_used = 0,
                                    .logs = logs,
                                };
                            }
                        }
                    }
                }
                return error.RpcError;
            },
            else => |e| error.RpcError,
        }
    }

    /// Helper: address to hex
    fn addressToHex(address: [20]u8) ![]u8 {
        const hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{address});
        defer self.allocator.free(hex);
        return hex;
    }

    /// Helper: bytes to hex
    fn bytesToHex(bytes: []const u8) ![]u8 {
        const hex = try std.fmt.allocPrint(self.allocator, "0x{s}", .{bytes});
        defer self.allocator.free(hex);
        return hex;
    }

    /// Transaction receipt (simplified)
    pub const TransactionReceipt = struct {
        tx_hash: [32]u8,
        block_number: u64,
        gas_used: u64,
        logs: []const JsonRpcLog,
    };

    pub const JsonRpcLog = struct {
        address: [20]u8,
        topics: []const [32]u8,
        data: []const u8,
        block_number: u64,
        transaction_hash: [32]u8,
    };
};
