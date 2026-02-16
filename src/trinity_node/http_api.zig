// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE HTTP API — REST Endpoints for DePIN Service
// Trinity Storage Network v2.1
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ApiConfig = struct {
    /// Port for the HTTP API server
    port: u16 = 8080,
    /// Bind address (0.0.0.0 for all interfaces)
    bind_address: []const u8 = "0.0.0.0",
    /// Maximum request size (bytes)
    max_request_size: usize = 8192,
    /// Server version string
    version: []const u8 = "0.1.0",
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP REQUEST/RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    OPTIONS,
    UNKNOWN,
};

pub const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    body: []const u8,
    raw: []const u8,
};

pub const HttpResponse = struct {
    status_code: u16,
    content_type: []const u8,
    body: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REWARD RATE CONSTANTS (mirror of depin.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RewardRates = struct {
    pub const EVOLUTION_GEN: f64 = 0.001;
    pub const NAVIGATION_STEP: f64 = 0.0001;
    pub const CONVERSION: f64 = 0.01;
    pub const BENCHMARK: f64 = 0.005;
    pub const STORAGE_SHARD_HOUR: f64 = 0.00005;
    pub const STORAGE_RETRIEVAL: f64 = 0.0005;
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXTERNAL STATE (wired up by main.zig at initialization)
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeState = struct {
    /// Current node status string (offline, syncing, online, earning)
    status: []const u8 = "earning",
    /// Uptime in seconds since node started
    uptime_seconds: u64 = 0,
    /// Number of connected peers
    peer_count: u32 = 0,
    /// Total operations performed
    operations_count: u64 = 0,
    /// Total earned TRI (formatted)
    earned_tri: f64 = 0.0,
    /// Pending TRI awaiting claim
    pending_tri: f64 = 0.0,
    /// Wallet address (hex string like "0x...")
    wallet_address: []const u8 = "0x0000000000000000000000000000000000000000",
    /// Wallet balance
    wallet_balance: f64 = 0.0,
    /// Number of shards hosted
    shards_hosted: u64 = 0,
    /// Bandwidth used in bytes
    bandwidth_bytes: u64 = 0,
    /// Storage earned TRI
    storage_earned_tri: f64 = 0.0,
};

pub const RewardHistoryEntry = struct {
    op: []const u8,
    amount: f64,
    timestamp: i64,
};

pub const SearchResult = struct {
    id: []const u8,
    title: []const u8,
    score: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// API STATS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ApiStats = struct {
    total_requests: u64,
    successful_responses: u64,
    not_found_responses: u64,
    error_responses: u64,
    total_bytes_served: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP API SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const HttpApiServer = struct {
    allocator: std.mem.Allocator,
    config: ApiConfig,
    stats: ApiStats,
    node_state: NodeState,
    mutex: std.Thread.Mutex,

    /// Delegate for Prometheus metrics — if set, /metrics requests are forwarded
    prometheus_delegate: ?*const fn (allocator: std.mem.Allocator) anyerror![]u8 = null,

    // ─────────────────────────────────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────────

    pub fn init(allocator: std.mem.Allocator) HttpApiServer {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: ApiConfig) HttpApiServer {
        return .{
            .allocator = allocator,
            .config = config,
            .stats = std.mem.zeroes(ApiStats),
            .node_state = .{},
            .mutex = .{},
            .prometheus_delegate = null,
        };
    }

    pub fn deinit(self: *HttpApiServer) void {
        _ = self;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STATE UPDATE
    // ─────────────────────────────────────────────────────────────────────────

    pub fn updateNodeState(self: *HttpApiServer, state: NodeState) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.node_state = state;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP PARSING
    // ─────────────────────────────────────────────────────────────────────────

    /// Parse a raw HTTP request into method, path, and body.
    /// Input: "GET /health HTTP/1.1\r\nHost: ...\r\n\r\n"
    pub fn parseRequest(raw: []const u8) HttpRequest {
        var method = HttpMethod.UNKNOWN;
        var path: []const u8 = "/";
        var body: []const u8 = "";

        if (raw.len == 0) {
            return .{ .method = method, .path = path, .body = body, .raw = raw };
        }

        // Parse method
        if (std.mem.startsWith(u8, raw, "GET ")) {
            method = .GET;
        } else if (std.mem.startsWith(u8, raw, "POST ")) {
            method = .POST;
        } else if (std.mem.startsWith(u8, raw, "PUT ")) {
            method = .PUT;
        } else if (std.mem.startsWith(u8, raw, "DELETE ")) {
            method = .DELETE;
        } else if (std.mem.startsWith(u8, raw, "OPTIONS ")) {
            method = .OPTIONS;
        }

        // Parse path: find first space, then next space
        var start: usize = 0;
        while (start < raw.len and raw[start] != ' ') : (start += 1) {}
        if (start < raw.len) {
            start += 1; // skip space
            var end = start;
            while (end < raw.len and raw[end] != ' ' and raw[end] != '?') : (end += 1) {}
            if (end > start) {
                path = raw[start..end];
            }
        }

        // Parse body: find \r\n\r\n separator
        if (std.mem.indexOf(u8, raw, "\r\n\r\n")) |sep| {
            const body_start = sep + 4;
            if (body_start < raw.len) {
                body = raw[body_start..];
            }
        }

        return .{ .method = method, .path = path, .body = body, .raw = raw };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RESPONSE FORMATTING
    // ─────────────────────────────────────────────────────────────────────────

    /// Format an HTTP 200 JSON response.
    pub fn jsonResponse(self: *HttpApiServer, json_body: []const u8) ![]u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{s}",
            .{ json_body.len, json_body },
        );
    }

    /// Format an HTTP 200 response with custom content type.
    pub fn customResponse(self: *HttpApiServer, status: u16, content_type: []const u8, body: []const u8) ![]u8 {
        const status_text: []const u8 = switch (status) {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            405 => "Method Not Allowed",
            500 => "Internal Server Error",
            else => "Unknown",
        };
        return try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{s}",
            .{ status, status_text, content_type, body.len, body },
        );
    }

    /// Format an HTTP 404 Not Found response.
    pub fn notFoundResponse(self: *HttpApiServer) ![]u8 {
        const body =
            \\{"error":"not_found","message":"Endpoint not found"}
        ;
        return self.customResponse(404, "application/json", body);
    }

    /// Format an HTTP 405 Method Not Allowed response.
    pub fn methodNotAllowedResponse(self: *HttpApiServer) ![]u8 {
        const body =
            \\{"error":"method_not_allowed","message":"HTTP method not supported for this endpoint"}
        ;
        return self.customResponse(405, "application/json", body);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // REQUEST ROUTING
    // ─────────────────────────────────────────────────────────────────────────

    /// Route an HTTP request to the appropriate handler.
    /// Returns the full HTTP response as a byte slice (caller owns memory).
    pub fn handleRequest(self: *HttpApiServer, raw_request: []const u8) ![]u8 {
        const request = parseRequest(raw_request);

        self.mutex.lock();
        self.stats.total_requests += 1;
        self.mutex.unlock();

        const result = if (std.mem.eql(u8, request.path, "/health"))
            try self.handleHealth(request)
        else if (std.mem.eql(u8, request.path, "/node/status"))
            try self.handleNodeStatus(request)
        else if (std.mem.eql(u8, request.path, "/node/stats"))
            try self.handleNodeStats(request)
        else if (std.mem.eql(u8, request.path, "/node/claim"))
            try self.handleNodeClaim(request)
        else if (std.mem.eql(u8, request.path, "/rewards/rates"))
            try self.handleRewardRates(request)
        else if (std.mem.eql(u8, request.path, "/rewards/history"))
            try self.handleRewardHistory(request)
        else if (std.mem.eql(u8, request.path, "/storage/stats"))
            try self.handleStorageStats(request)
        else if (std.mem.eql(u8, request.path, "/search"))
            try self.handleSearch(request)
        else if (std.mem.eql(u8, request.path, "/wallet/balance"))
            try self.handleWalletBalance(request)
        else if (std.mem.eql(u8, request.path, "/metrics"))
            try self.handleMetrics(request)
        else blk: {
            self.mutex.lock();
            self.stats.not_found_responses += 1;
            self.mutex.unlock();
            break :blk try self.notFoundResponse();
        };

        self.mutex.lock();
        self.stats.total_bytes_served += result.len;
        self.mutex.unlock();

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ENDPOINT HANDLERS
    // ─────────────────────────────────────────────────────────────────────────

    /// GET /health -> {"status":"ok","version":"0.1.0"}
    fn handleHealth(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"status":"ok","version":"{s}"}}
        ,
            .{self.config.version},
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /node/status -> {"status":"earning","uptime_hours":12.5,"peers":8}
    fn handleNodeStatus(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        self.mutex.lock();
        const state = self.node_state;
        self.mutex.unlock();

        const uptime_hours = @as(f64, @floatFromInt(state.uptime_seconds)) / 3600.0;

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"status":"{s}","uptime_hours":{d:.1},"peers":{d}}}
        ,
            .{ state.status, uptime_hours, state.peer_count },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /node/stats -> {"operations":1240,"earned_tri":0.124,"pending_tri":0.003}
    fn handleNodeStats(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        self.mutex.lock();
        const state = self.node_state;
        self.mutex.unlock();

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"operations":{d},"earned_tri":{d:.6},"pending_tri":{d:.6}}}
        ,
            .{ state.operations_count, state.earned_tri, state.pending_tri },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// POST /node/claim -> {"claimed_tri":0.003,"tx_hash":"0x..."}
    fn handleNodeClaim(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .POST) return self.methodNotAllowedResponse();

        self.mutex.lock();
        const pending = self.node_state.pending_tri;
        self.mutex.unlock();

        // Generate a mock tx hash from current timestamp
        const now = std.time.timestamp();
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"claimed_tri":{d:.6},"tx_hash":"0x{x:0>16}{x:0>16}{x:0>16}{x:0>16}"}}
        ,
            .{ pending, @as(u64, @intCast(now)), @as(u64, @intCast(now +% 1)), @as(u64, @intCast(now +% 2)), @as(u64, @intCast(now +% 3)) },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /rewards/rates -> all 6 reward rates from depin.zig constants
    fn handleRewardRates(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"evolution_gen":{d:.6},"navigation_step":{d:.6},"conversion":{d:.6},"benchmark":{d:.6},"storage_shard_hour":{d:.6},"storage_retrieval":{d:.6}}}
        ,
            .{
                RewardRates.EVOLUTION_GEN,
                RewardRates.NAVIGATION_STEP,
                RewardRates.CONVERSION,
                RewardRates.BENCHMARK,
                RewardRates.STORAGE_SHARD_HOUR,
                RewardRates.STORAGE_RETRIEVAL,
            },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /rewards/history -> mock reward history entries
    fn handleRewardHistory(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        const now = std.time.timestamp();

        // Return simulated recent reward history
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\[{{"op":"evolution","amount":0.001000,"ts":{d}}},{{"op":"storage_hosting","amount":0.000050,"ts":{d}}},{{"op":"benchmark","amount":0.005000,"ts":{d}}},{{"op":"storage_retrieval","amount":0.000500,"ts":{d}}},{{"op":"conversion","amount":0.010000,"ts":{d}}}]
        ,
            .{ now - 300, now - 240, now - 180, now - 120, now - 60 },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /storage/stats -> {"shards_hosted":42,"bandwidth_gb":1.2,"earned_tri":0.05}
    fn handleStorageStats(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        self.mutex.lock();
        const state = self.node_state;
        self.mutex.unlock();

        const bandwidth_gb = @as(f64, @floatFromInt(state.bandwidth_bytes)) / (1024.0 * 1024.0 * 1024.0);

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"shards_hosted":{d},"bandwidth_gb":{d:.3},"earned_tri":{d:.6}}}
        ,
            .{ state.shards_hosted, bandwidth_gb, state.storage_earned_tri },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// POST /search -> {"query":"...","results":[...]}
    fn handleSearch(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .POST) return self.methodNotAllowedResponse();

        // Extract query from body (simple: look for "query" field)
        // For now, return mock results regardless of body content
        const query = if (request.body.len > 0) request.body else "\"\"";
        _ = query;

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"query":"search","results":[{{"id":"shard_001","title":"Ternary Neural Network Paper","score":0.95}},{{"id":"shard_002","title":"VSA Architecture Overview","score":0.87}},{{"id":"shard_003","title":"DePIN Reward Mechanics","score":0.72}}]}}
        ,
            .{},
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /wallet/balance -> {"address":"0x...","balance":1.234,"pending":0.003}
    fn handleWalletBalance(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        self.mutex.lock();
        const state = self.node_state;
        self.mutex.unlock();

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"address":"{s}","balance":{d:.6},"pending":{d:.6}}}
        ,
            .{ state.wallet_address, state.wallet_balance, state.pending_tri },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.jsonResponse(body);
    }

    /// GET /metrics -> Prometheus format (delegate or fallback)
    fn handleMetrics(self: *HttpApiServer, request: HttpRequest) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        // If a Prometheus delegate is set, forward to it
        if (self.prometheus_delegate) |delegate| {
            const metrics_body = try delegate(self.allocator);
            defer self.allocator.free(metrics_body);

            self.mutex.lock();
            self.stats.successful_responses += 1;
            self.mutex.unlock();

            return self.customResponse(200, "text/plain; version=0.0.4; charset=utf-8", metrics_body);
        }

        // Fallback: generate basic self-metrics
        self.mutex.lock();
        const stats = self.stats;
        self.mutex.unlock();

        const metrics_body = try std.fmt.allocPrint(
            self.allocator,
            \\# HELP trinity_api_requests_total Total HTTP API requests
            \\# TYPE trinity_api_requests_total counter
            \\trinity_api_requests_total {d}
            \\# HELP trinity_api_successful_responses_total Successful API responses
            \\# TYPE trinity_api_successful_responses_total counter
            \\trinity_api_successful_responses_total {d}
            \\# HELP trinity_api_not_found_total 404 responses
            \\# TYPE trinity_api_not_found_total counter
            \\trinity_api_not_found_total {d}
            \\# HELP trinity_api_bytes_served_total Total bytes served
            \\# TYPE trinity_api_bytes_served_total counter
            \\trinity_api_bytes_served_total {d}
            \\
        ,
            .{
                stats.total_requests,
                stats.successful_responses,
                stats.not_found_responses,
                stats.total_bytes_served,
            },
        );
        defer self.allocator.free(metrics_body);

        self.mutex.lock();
        self.stats.successful_responses += 1;
        self.mutex.unlock();

        return self.customResponse(200, "text/plain; version=0.0.4; charset=utf-8", metrics_body);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STATS
    // ─────────────────────────────────────────────────────────────────────────

    pub fn getStats(self: *HttpApiServer) ApiStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "http_api: parse GET request" {
    const request = HttpApiServer.parseRequest("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");

    try std.testing.expectEqual(HttpMethod.GET, request.method);
    try std.testing.expectEqualStrings("/health", request.path);
    try std.testing.expectEqualStrings("", request.body);
}

test "http_api: parse POST request with body" {
    const raw = "POST /search HTTP/1.1\r\nHost: localhost\r\nContent-Length: 27\r\n\r\n{\"query\":\"machine learning\"}";
    const request = HttpApiServer.parseRequest(raw);

    try std.testing.expectEqual(HttpMethod.POST, request.method);
    try std.testing.expectEqualStrings("/search", request.path);
    try std.testing.expectEqualStrings("{\"query\":\"machine learning\"}", request.body);
}

test "http_api: parse unknown method" {
    const request = HttpApiServer.parseRequest("PATCH /foo HTTP/1.1\r\n\r\n");
    try std.testing.expectEqual(HttpMethod.UNKNOWN, request.method);
}

test "http_api: GET /health returns 200 with status ok" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "application/json") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"status\":\"ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"version\":\"0.1.0\"") != null);
}

test "http_api: GET /node/status returns node status" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.initWithConfig(allocator, .{});
    defer server.deinit();

    server.updateNodeState(.{
        .status = "earning",
        .uptime_seconds = 45000,
        .peer_count = 8,
    });

    const response = try server.handleRequest("GET /node/status HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"status\":\"earning\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"uptime_hours\":12.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"peers\":8") != null);
}

test "http_api: GET /node/stats returns operations and earnings" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    server.updateNodeState(.{
        .operations_count = 1240,
        .earned_tri = 0.124,
        .pending_tri = 0.003,
    });

    const response = try server.handleRequest("GET /node/stats HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"operations\":1240") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"earned_tri\":0.124") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"pending_tri\":0.003") != null);
}

test "http_api: POST /node/claim returns claimed amount" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    server.updateNodeState(.{ .pending_tri = 0.003 });

    const response = try server.handleRequest("POST /node/claim HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"claimed_tri\":0.003") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"tx_hash\":\"0x") != null);
}

test "http_api: GET /rewards/rates returns all 6 rates" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("GET /rewards/rates HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"evolution_gen\":0.001") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"navigation_step\":0.0001") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"conversion\":0.01") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"benchmark\":0.005") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"storage_shard_hour\":0.00005") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"storage_retrieval\":0.0005") != null);
}

test "http_api: GET /wallet/balance returns wallet info" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    server.updateNodeState(.{
        .wallet_address = "0xdeadbeef01234567890123456789012345678901",
        .wallet_balance = 1.234,
        .pending_tri = 0.003,
    });

    const response = try server.handleRequest("GET /wallet/balance HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"address\":\"0xdeadbeef01234567890123456789012345678901\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"balance\":1.234") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"pending\":0.003") != null);
}

test "http_api: unknown path returns 404" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("GET /nonexistent HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 404 Not Found\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"error\":\"not_found\"") != null);

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.not_found_responses);
}

test "http_api: wrong method returns 405" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    // POST to a GET-only endpoint
    const response = try server.handleRequest("POST /health HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 405 Method Not Allowed\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"error\":\"method_not_allowed\"") != null);
}

test "http_api: GET /storage/stats returns storage info" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    server.updateNodeState(.{
        .shards_hosted = 42,
        .bandwidth_bytes = 1288490188, // ~1.2 GB
        .storage_earned_tri = 0.05,
    });

    const response = try server.handleRequest("GET /storage/stats HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"shards_hosted\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"earned_tri\":0.05") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"bandwidth_gb\":") != null);
}

test "http_api: POST /search returns mock results" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("POST /search HTTP/1.1\r\nContent-Length: 30\r\n\r\n{\"query\":\"machine learning\"}");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"results\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"score\":0.95") != null);
}

test "http_api: GET /metrics returns Prometheus format" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    // Make some requests first to accumulate stats
    const r1 = try server.handleRequest("GET /health HTTP/1.1\r\n\r\n");
    defer allocator.free(r1);
    const r2 = try server.handleRequest("GET /nonexistent HTTP/1.1\r\n\r\n");
    defer allocator.free(r2);

    const response = try server.handleRequest("GET /metrics HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "text/plain; version=0.0.4") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "trinity_api_requests_total") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "trinity_api_successful_responses_total") != null);
}

test "http_api: GET /rewards/history returns entries" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("GET /rewards/history HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"op\":\"evolution\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"op\":\"storage_hosting\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"op\":\"benchmark\"") != null);
}

test "http_api: stats accumulate across requests" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const r1 = try server.handleRequest("GET /health HTTP/1.1\r\n\r\n");
    defer allocator.free(r1);
    const r2 = try server.handleRequest("GET /node/status HTTP/1.1\r\n\r\n");
    defer allocator.free(r2);
    const r3 = try server.handleRequest("GET /nonexistent HTTP/1.1\r\n\r\n");
    defer allocator.free(r3);

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total_requests);
    try std.testing.expectEqual(@as(u64, 2), stats.successful_responses);
    try std.testing.expectEqual(@as(u64, 1), stats.not_found_responses);
    try std.testing.expect(stats.total_bytes_served > 0);
}

test "http_api: config defaults are correct" {
    const config = ApiConfig{};
    try std.testing.expectEqual(@as(u16, 8080), config.port);
    try std.testing.expectEqualStrings("0.0.0.0", config.bind_address);
    try std.testing.expectEqual(@as(usize, 8192), config.max_request_size);
    try std.testing.expectEqualStrings("0.1.0", config.version);
}

test "http_api: CORS header present" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest("GET /health HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "Access-Control-Allow-Origin: *") != null);
}
