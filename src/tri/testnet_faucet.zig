// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY TESTNET FAUCET — HTTP Faucet for Test $TRI
// Dispenses 10,000 test $TRI per request with 24h rate limiting
// φ² + 1/φ² = 3 | TESTNET PHASE 0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testnet_config = @import("testnet_config.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// FAUCET STATE — Tracks requests per address
// ═══════════════════════════════════════════════════════════════════════════════

pub const FaucetError = error{
    RateLimitExceeded,
    InvalidAddress,
    InsufficientFunds,
    DatabaseError,
    InvalidAmount,
};

pub const FaucetRequest = struct {
    address: []const u8,
    amount: u64,
    timestamp: u64,
    ip: []const u8,
    signature: ?[]const u8 = null, // Optional anti-sybil signature
};

pub const FaucetResponse = struct {
    success: bool,
    amount: u64,
    tx_hash: []const u8,
    message: []const u8,
    next_available_at: ?u64 = null,

    pub fn toJson(self: *const FaucetResponse, allocator: std.mem.Allocator) ![]const u8 {
        const next_str = if (self.next_available_at) |t|
            try std.fmt.allocPrint(allocator, "\"next_available_at\":{d},", .{t})
        else
            "";
        defer if (self.next_available_at != null) allocator.free(next_str);

        return if (next_str.len > 0)
            try std.fmt.allocPrint(allocator,
                \\{{"success":{s},"amount":{d},"tx_hash":"{s}","message":"{s}",{s}}}
            , .{
                if (self.success) "true" else "false",
                self.amount,
                self.tx_hash,
                self.message,
                next_str,
            })
        else
            try std.fmt.allocPrint(allocator,
                \\{{"success":{s},"amount":{d},"tx_hash":"{s}","message":"{s}"}}
            , .{
                if (self.success) "true" else "false",
                self.amount,
                self.tx_hash,
                self.message,
            });
    }
};

pub const RateLimitEntry = struct {
    address: []const u8,
    last_request: u64,
    request_count: u32,

    pub fn canRequest(self: RateLimitEntry, current_time: u64) bool {
        const elapsed = current_time - self.last_request;
        return elapsed >= testnet_config.FAUCET_RATE_LIMIT_SECONDS;
    }

    pub fn timeUntilNextRequest(self: RateLimitEntry, current_time: u64) u64 {
        const elapsed = current_time - self.last_request;
        if (elapsed >= testnet_config.FAUCET_RATE_LIMIT_SECONDS) return 0;
        return testnet_config.FAUCET_RATE_LIMIT_SECONDS - elapsed;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FAUCET STATE MANAGER — In-memory + persistent storage
// ═══════════════════════════════════════════════════════════════════════════════

pub const FaucetState = struct {
    allocator: std.mem.Allocator,
    /// Map: address -> RateLimitEntry
    rate_limits: std.StringHashMapUnmanaged(RateLimitEntry),
    /// Total dispensed
    total_dispensed: u64,
    /// Dispense limit (50M test $TRI pool)
    dispense_limit: u64,
    /// State file path
    state_file: []const u8,

    pub fn init(allocator: std.mem.Allocator, state_file: []const u8) FaucetState {
        return FaucetState{
            .allocator = allocator,
            .rate_limits = .{},
            .total_dispensed = 0,
            .dispense_limit = testnet_config.REWARD_ALLOCATION,
            .state_file = state_file,
        };
    }

    pub fn deinit(self: *FaucetState) void {
        var iter = self.rate_limits.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.rate_limits.deinit(self.allocator);
    }

    /// Check if address can request funds
    pub fn canRequest(self: *const FaucetState, address: []const u8) !bool {
        const entry = self.rate_limits.get(address) orelse return true;
        const now = @as(u64, @intCast(std.time.timestamp()));
        return entry.canRequest(now);
    }

    /// Get time until next request for address
    pub fn timeUntilNext(self: *const FaucetState, address: []const u8) ?u64 {
        const entry = self.rate_limits.get(address) orelse return 0;
        const now = @as(u64, @intCast(std.time.timestamp()));
        const wait = entry.timeUntilNextRequest(now);
        return if (wait > 0) wait else null;
    }

    /// Record a faucet request
    pub fn recordRequest(self: *FaucetState, address: []const u8) !void {
        const now = @as(u64, @intCast(std.time.timestamp()));
        const address_copy = try self.allocator.dupe(u8, address);
        errdefer self.allocator.free(address_copy);

        const gop = try self.rate_limits.getOrPut(self.allocator, address_copy);
        if (!gop.found_existing) {
            gop.value_ptr.* = RateLimitEntry{
                .address = address_copy,
                .last_request = now,
                .request_count = 1,
            };
        } else {
            self.allocator.free(address_copy);
            gop.value_ptr.last_request = now;
            gop.value_ptr.request_count += 1;
        }
    }

    /// Check if faucet has funds remaining
    pub fn hasFunds(self: *const FaucetState, amount: u64) bool {
        return self.total_dispensed + amount <= self.dispense_limit;
    }

    /// Record a dispense
    pub fn recordDispense(self: *FaucetState, amount: u64) !void {
        if (!self.hasFunds(amount)) return error.InsufficientFunds;
        self.total_dispensed += amount;
    }

    /// Save state to file
    pub fn save(self: *const FaucetState) !void {
        // DEFERRED: Implement JSON persistence
        _ = self;
        return error.NotImplemented;
    }

    /// Load state from file
    pub fn load(self: *FaucetState) !void {
        // DEFERRED: Implement JSON persistence
        _ = self;
        return error.NotImplemented;
    }

    /// Get statistics
    pub fn getStats(self: *const FaucetState) FaucetStats {
        return FaucetStats{
            .total_dispensed = self.total_dispensed,
            .remaining = self.dispense_limit - self.total_dispensed,
            .unique_addresses = self.rate_limits.count(),
            .utilization_percent = @as(f64, @floatFromInt(self.total_dispensed)) * 100.0 / @as(f64, @floatFromInt(self.dispense_limit)),
        };
    }
};

pub const FaucetStats = struct {
    total_dispensed: u64,
    remaining: u64,
    unique_addresses: usize,
    utilization_percent: f64,

    pub fn toJson(self: *const FaucetStats, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"total_dispensed":{d},"remaining":{d},"unique_addresses":{d},"utilization_percent":{d:.2}}}
        , .{
            self.total_dispensed,
            self.remaining,
            self.unique_addresses,
            self.utilization_percent,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FAUCET SERVER — HTTP API
// ═══════════════════════════════════════════════════════════════════════════════

pub const FaucetServer = struct {
    allocator: std.mem.Allocator,
    state: FaucetState,
    port: u16,
    socket: ?std.posix.socket_t = null,
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator, port: u16, state_file: []const u8) FaucetServer {
        return FaucetServer{
            .allocator = allocator,
            .state = FaucetState.init(allocator, state_file),
            .port = port,
        };
    }

    pub fn deinit(self: *FaucetServer) void {
        if (self.socket) |s| {
            std.posix.close(s);
        }
        self.state.deinit();
    }

    /// Start the faucet server
    pub fn start(self: *FaucetServer) !void {
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

    /// Stop the faucet server
    pub fn stop(self: *FaucetServer) void {
        self.running = false;
    }

    /// Process a faucet request
    pub fn processRequest(self: *FaucetServer, request: FaucetRequest) !FaucetResponse {
        // Validate amount
        if (request.amount == 0 or request.amount > testnet_config.FAUCET_DRIP_AMOUNT) {
            return FaucetResponse{
                .success = false,
                .amount = 0,
                .tx_hash = "",
                .message = "Invalid amount. Must be between 1 and 10,000.",
            };
        }

        // Validate address format (basic check)
        if (request.address.len < 26 or request.address.len > 42) {
            return FaucetResponse{
                .success = false,
                .amount = 0,
                .tx_hash = "",
                .message = "Invalid address format.",
            };
        }

        // Check rate limit
        if (!try self.state.canRequest(request.address)) {
            const wait = self.state.timeUntilNext(request.address) orelse 0;
            return FaucetResponse{
                .success = false,
                .amount = 0,
                .tx_hash = "",
                .message = "Rate limit exceeded. Please try again later.",
                .next_available_at = if (wait > 0) @as(u64, @intCast(std.time.timestamp())) + wait else null,
            };
        }

        // Check funds
        if (!self.state.hasFunds(request.amount)) {
            return FaucetResponse{
                .success = false,
                .amount = 0,
                .tx_hash = "",
                .message = "Faucet out of funds.",
            };
        }

        // Record request and dispense
        try self.state.recordRequest(request.address);
        try self.state.recordDispense(request.amount);

        // Generate mock transaction hash
        const tx_hash = try self.generateTxHash();

        return FaucetResponse{
            .success = true,
            .amount = request.amount,
            .tx_hash = tx_hash,
            .message = "Successfully dispensed test $TRI.",
        };
    }

    /// Generate a mock transaction hash
    fn generateTxHash(self: *FaucetServer) ![]const u8 {
        const timestamp = std.time.timestamp();
        const random = @as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
        return std.fmt.allocPrint(self.allocator, "0x{x}{x}", .{ timestamp, random });
    }

    /// Handle HTTP POST /faucet/drip
    pub fn handleDrip(self: *FaucetServer, body: []const u8) ![]const u8 {
        // Parse JSON body (simplified)
        // Expected: {"address":"0x...","amount":10000}

        const addr_start = std.mem.indexOf(u8, body, "\"address\":\"") orelse return error.InvalidRequest;
        const addr_end = std.mem.indexOf(u8, body[addr_start + 11 ..], "\"") orelse return error.InvalidRequest;
        const address = body[addr_start + 11 .. addr_start + 11 + addr_end];

        const amount_start = std.mem.indexOf(u8, body, "\"amount\":") orelse return error.InvalidRequest;
        const amount_end = std.mem.indexOf(u8, body[amount_start + 9 ..], "}") orelse return error.InvalidRequest;
        const amount_str = body[amount_start + 9 .. amount_start + 9 + amount_end];
        const amount = std.fmt.parseInt(u64, amount_str, 10) catch testnet_config.FAUCET_DRIP_AMOUNT;

        const request = FaucetRequest{
            .address = address,
            .amount = amount,
            .timestamp = @as(u64, @intCast(std.time.timestamp())),
            .ip = "unknown",
        };

        const response = try self.processRequest(request);
        return response.toJson(self.allocator);
    }

    /// Handle HTTP GET /faucet/stats
    pub fn handleStats(self: *FaucetServer) ![]const u8 {
        const stats = self.state.getStats();
        return stats.toJson(self.allocator);
    }

    /// Handle HTTP GET /faucet/status/:address
    pub fn handleStatus(self: *FaucetServer, address: []const u8) ![]const u8 {
        const can = try self.state.canRequest(address);
        const wait = self.state.timeUntilNext(address);

        if (can) {
            return std.fmt.allocPrint(self.allocator,
                \\{{"address":"{s}","can_request":true,"message":"You can request funds now."}}
            , .{address});
        } else {
            const wait_secs = wait orelse 0;
            const next = @as(u64, @intCast(std.time.timestamp())) + wait_secs;
            return std.fmt.allocPrint(self.allocator,
                \\{{"address":"{s}","can_request":false,"next_available_at":{d},"wait_seconds":{d}}}
            , .{ address, next, wait_secs });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRYPOINT — tri testnet faucet
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFaucetServer(allocator: std.mem.Allocator, port: u16) !void {
    const state_file = ".trinity/testnet_faucet.json";
    var server = FaucetServer.init(allocator, port, state_file);
    defer server.deinit();

    try server.start();
    std.log.info("Testnet faucet listening on port {d}", .{port});

    // Main loop
    while (server.running) {
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

pub fn runFaucetCli(allocator: std.mem.Allocator, address: []const u8, amount: u64) !void {
    // Direct CLI faucet request
    const state_file = ".trinity/testnet_faucet.json";
    var server = FaucetServer.init(allocator, 8080, state_file);
    defer server.deinit();

    const request = FaucetRequest{
        .address = address,
        .amount = amount,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "cli",
    };

    const response = try server.processRequest(request);
    const json = try response.toJson(allocator);
    defer allocator.free(json);

    std.log.info("{s}", .{json});

    if (!response.success) {
        std.process.exit(1);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FaucetState init" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 0), state.rate_limits.count());
    try std.testing.expectEqual(@as(u64, 0), state.total_dispensed);
    try std.testing.expectEqual(testnet_config.REWARD_ALLOCATION, state.dispense_limit);
}

test "FaucetState first request allowed" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    const addr = "0x1234567890abcdef";
    try std.testing.expect(state.canRequest(addr) catch false);
}

test "FaucetState record request" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    const addr = "0x1234567890abcdef";
    try state.recordRequest(addr);

    const entry = state.rate_limits.get(addr).?;
    try std.testing.expectEqual(@as(u32, 1), entry.request_count);
}

test "FaucetState rate limit enforcement" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    const addr = "0x1234567890abcdef";

    // Record request
    try state.recordRequest(addr);

    // Check rate limit (should be blocked since we just requested)
    const can = state.canRequest(addr) catch false;
    try std.testing.expect(!can);
}

test "FaucetState has funds" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    try std.testing.expect(state.hasFunds(10_000));
    try std.testing.expect(state.hasFunds(testnet_config.REWARD_ALLOCATION));
    try std.testing.expect(!state.hasFunds(testnet_config.REWARD_ALLOCATION + 1));
}

test "FaucetState record dispense" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    try state.recordDispense(10_000);
    try std.testing.expectEqual(@as(u64, 10_000), state.total_dispensed);

    try state.recordDispense(5_000);
    try std.testing.expectEqual(@as(u64, 15_000), state.total_dispensed);
}

test "FaucetState stats" {
    const allocator = std.testing.allocator;
    var state = FaucetState.init(allocator, "test.json");
    defer state.deinit();

    try state.recordRequest("0xAAA");
    try state.recordRequest("0xBBB");
    try state.recordRequest("0xCCC");
    try state.recordDispense(30_000);

    const stats = state.getStats();
    try std.testing.expectEqual(@as(u64, 30_000), stats.total_dispensed);
    try std.testing.expectEqual(@as(usize, 3), stats.unique_addresses);
    try std.testing.expect(stats.remaining > 0);
}

test "FaucetServer init" {
    const allocator = std.testing.allocator;
    var server = FaucetServer.init(allocator, 8080, "test.json");
    defer server.deinit();

    try std.testing.expectEqual(@as(u16, 8080), server.port);
    try std.testing.expect(!server.running);
}

test "FaucetServer process valid request" {
    const allocator = std.testing.allocator;
    var server = FaucetServer.init(allocator, 8080, "test.json");
    defer server.deinit();

    const request = FaucetRequest{
        .address = "0x1234567890abcdef1234567890abcdef12345678",
        .amount = 10_000,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "127.0.0.1",
    };

    const response = try server.processRequest(request);
    try std.testing.expect(response.success);
    try std.testing.expectEqual(@as(u64, 10_000), response.amount);
    allocator.free(response.tx_hash);
}

test "FaucetServer process invalid amount" {
    const allocator = std.testing.allocator;
    var server = FaucetServer.init(allocator, 8080, "test.json");
    defer server.deinit();

    const request = FaucetRequest{
        .address = "0x1234567890abcdef1234567890abcdef12345678",
        .amount = 100_000, // Too much
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "127.0.0.1",
    };

    const response = try server.processRequest(request);
    try std.testing.expect(!response.success);
}

test "FaucetServer process invalid address" {
    const allocator = std.testing.allocator;
    var server = FaucetServer.init(allocator, 8080, "test.json");
    defer server.deinit();

    const request = FaucetRequest{
        .address = "short",
        .amount = 10_000,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "127.0.0.1",
    };

    const response = try server.processRequest(request);
    try std.testing.expect(!response.success);
}

test "FaucetServer rate limit" {
    const allocator = std.testing.allocator;
    var server = FaucetServer.init(allocator, 8080, "test.json");
    defer server.deinit();

    const addr = "0x1234567890abcdef1234567890abcdef12345678";

    const request1 = FaucetRequest{
        .address = addr,
        .amount = 10_000,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "127.0.0.1",
    };

    // First request succeeds
    const response1 = try server.processRequest(request1);
    defer allocator.free(response1.tx_hash);
    try std.testing.expect(response1.success);

    const request2 = FaucetRequest{
        .address = addr,
        .amount = 10_000,
        .timestamp = @as(u64, @intCast(std.time.timestamp())),
        .ip = "127.0.0.1",
    };

    // Second request fails (rate limited)
    const response2 = try server.processRequest(request2);
    try std.testing.expect(!response2.success);
}

test "FaucetStats JSON" {
    const allocator = std.testing.allocator;
    const stats = FaucetStats{
        .total_dispensed = 1_000_000,
        .remaining = 49_000_000,
        .unique_addresses = 100,
        .utilization_percent = 2.0,
    };

    const json = try stats.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"total_dispensed\":1000000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"unique_addresses\":100") != null);
}

test "FaucetResponse JSON success" {
    const allocator = std.testing.allocator;
    var response = FaucetResponse{
        .success = true,
        .amount = 10_000,
        .tx_hash = "0xabc123",
        .message = "Success",
    };

    const json = try response.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"success\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"amount\":10000") != null);
}

test "FaucetResponse JSON failure" {
    const allocator = std.testing.allocator;
    var response = FaucetResponse{
        .success = false,
        .amount = 0,
        .tx_hash = "",
        .message = "Rate limited",
        .next_available_at = 1234567890,
    };

    const json = try response.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"success\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"next_available_at\":1234567890") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN ENTRYPOINT — testnet-faucet executable
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: testnet-faucet <command>", .{});
        std.log.err("Commands:", .{});
        std.log.err("  server <port>    - Start faucet HTTP server (default: 8080)", .{});
        std.log.err("  drip <address>    - Request test $TRI for address", .{});
        std.log.err("  status <address>  - Check faucet status for address", .{});
        std.process.exit(1);
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "server")) {
        const port = if (args.len > 2)
            try std.fmt.parseInt(u16, args[2], 10)
        else
            8080;
        try runFaucetServer(allocator, port);
    } else if (std.mem.eql(u8, command, "drip")) {
        if (args.len < 3) {
            std.log.err("Usage: testnet-faucet drip <address> [amount]", .{});
            std.process.exit(1);
        }
        const address = args[2];
        const amount = if (args.len > 3)
            try std.fmt.parseInt(u64, args[3], 10)
        else
            testnet_config.FAUCET_DRIP_AMOUNT;
        try runFaucetCli(allocator, address, amount);
    } else if (std.mem.eql(u8, command, "status")) {
        if (args.len < 3) {
            std.log.err("Usage: testnet-faucet status <address>", .{});
            std.process.exit(1);
        }
        const address = args[2];
        const state_file = ".trinity/testnet_faucet.json";
        var server = FaucetServer.init(allocator, 8080, state_file);
        defer server.deinit();

        const json = try server.handleStatus(address);
        defer allocator.free(json);
        std.log.info("{s}", .{json});
    } else {
        std.log.err("Unknown command: {s}", .{command});
        std.process.exit(1);
    }
}
