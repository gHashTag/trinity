// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE HTTP API — REST Endpoints for DePIN Service
// Trinity Storage Network v2.1
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const token_staking_mod = @import("token_staking.zig");

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
// TIER SYSTEM (Stake-Based Monetization)
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeTier = enum {
    free,
    staker,
    power,
    whale,

    pub fn name(self: NodeTier) []const u8 {
        return switch (self) {
            .free => "free",
            .staker => "staker",
            .power => "power",
            .whale => "whale",
        };
    }

    pub fn rateLimit(self: NodeTier) u32 {
        return switch (self) {
            .free => TierConfig.FREE_RATE_LIMIT,
            .staker => TierConfig.STAKER_RATE_LIMIT,
            .power => TierConfig.POWER_RATE_LIMIT,
            .whale => TierConfig.WHALE_RATE_LIMIT,
        };
    }

    pub fn rewardMultiplier(self: NodeTier) f64 {
        return switch (self) {
            .free => TierConfig.FREE_REWARD_MULTIPLIER,
            .staker => TierConfig.STAKER_REWARD_MULTIPLIER,
            .power => TierConfig.POWER_REWARD_MULTIPLIER,
            .whale => TierConfig.WHALE_REWARD_MULTIPLIER,
        };
    }
};

pub const TierConfig = struct {
    // Rate limits (requests per minute, 0 = unlimited)
    pub const FREE_RATE_LIMIT: u32 = 10;
    pub const STAKER_RATE_LIMIT: u32 = 60;
    pub const POWER_RATE_LIMIT: u32 = 300;
    pub const WHALE_RATE_LIMIT: u32 = 0; // unlimited

    // Staking thresholds (in wei, 1 TRI = 10^18 wei)
    pub const STAKER_MIN_WEI: u128 = 100_000_000_000_000_000_000; // 100 TRI
    pub const POWER_MIN_WEI: u128 = 1_000_000_000_000_000_000_000; // 1,000 TRI
    pub const WHALE_MIN_WEI: u128 = 10_000_000_000_000_000_000_000; // 10,000 TRI

    // Reward multipliers
    pub const FREE_REWARD_MULTIPLIER: f64 = 1.0;
    pub const STAKER_REWARD_MULTIPLIER: f64 = 1.5;
    pub const POWER_REWARD_MULTIPLIER: f64 = 2.0;
    pub const WHALE_REWARD_MULTIPLIER: f64 = 3.0;

    // Rate limit window in seconds
    pub const RATE_LIMIT_WINDOW_SECONDS: i64 = 60;
};

pub const RateLimitEntry = struct {
    request_count: u32,
    window_start: i64,
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
    /// Wallet address from X-Wallet header (empty string if not provided)
    wallet_address: []const u8,
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

    /// Optional staking engine for tier-based access control
    staking_engine: ?*token_staking_mod.TokenStakingEngine = null,

    /// Rate limit tracking per wallet address
    rate_limits: std.StringHashMap(RateLimitEntry),

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
            .staking_engine = null,
            .rate_limits = std.StringHashMap(RateLimitEntry).init(allocator),
        };
    }

    pub fn deinit(self: *HttpApiServer) void {
        self.rate_limits.deinit();
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
    // TIER & RATE LIMITING
    // ─────────────────────────────────────────────────────────────────────────

    /// Determine a wallet's tier from its staked amount.
    /// If no staking engine is connected, all wallets get free tier.
    pub fn determineTier(self: *HttpApiServer, wallet_address: []const u8) NodeTier {
        if (wallet_address.len == 0) return .free;
        if (self.staking_engine == null) return .free;

        // Convert wallet address to [32]u8 node_id for staking lookup
        var node_id: [32]u8 = std.mem.zeroes([32]u8);
        const copy_len = @min(wallet_address.len, 32);
        @memcpy(node_id[0..copy_len], wallet_address[0..copy_len]);

        const staked_wei = self.staking_engine.?.getRemainingStake(node_id);

        if (staked_wei >= TierConfig.WHALE_MIN_WEI) return .whale;
        if (staked_wei >= TierConfig.POWER_MIN_WEI) return .power;
        if (staked_wei >= TierConfig.STAKER_MIN_WEI) return .staker;
        return .free;
    }

    /// Check if a request is rate-limited. Returns true if the request should be rejected.
    pub fn checkRateLimit(self: *HttpApiServer, wallet_key: []const u8, tier: NodeTier) bool {
        const limit = tier.rateLimit();
        if (limit == 0) return false; // unlimited

        const now = std.time.timestamp();

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.rate_limits.getPtr(wallet_key)) |entry| {
            // Check if window has expired
            if (now - entry.window_start >= TierConfig.RATE_LIMIT_WINDOW_SECONDS) {
                entry.window_start = now;
                entry.request_count = 1;
                return false;
            }
            entry.request_count += 1;
            return entry.request_count > limit;
        }

        // New entry
        self.rate_limits.put(wallet_key, .{
            .request_count = 1,
            .window_start = now,
        }) catch return false;

        return false;
    }

    /// Get remaining requests in current rate limit window
    fn getRemainingRequests(self: *HttpApiServer, wallet_key: []const u8, tier: NodeTier) u32 {
        const limit = tier.rateLimit();
        if (limit == 0) return 0; // unlimited means we return 0 (special value)

        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        if (self.rate_limits.get(wallet_key)) |entry| {
            if (now - entry.window_start >= TierConfig.RATE_LIMIT_WINDOW_SECONDS) {
                return limit;
            }
            if (entry.request_count >= limit) return 0;
            return limit - entry.request_count;
        }

        return limit;
    }

    /// Check if a path is allowed for free tier
    fn isFreeTierAllowed(path: []const u8) bool {
        return std.mem.eql(u8, path, "/health") or
            std.mem.eql(u8, path, "/node/status") or
            std.mem.eql(u8, path, "/metrics") or
            std.mem.eql(u8, path, "/node/tier") or
            std.mem.eql(u8, path, "/rewards/rates");
    }

    /// Format an HTTP 429 Too Many Requests response.
    pub fn rateLimitResponse(self: *HttpApiServer, tier: NodeTier) ![]u8 {
        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"error":"rate_limit_exceeded","tier":"{s}","limit":{d},"window_seconds":{d}}}
        ,
            .{ tier.name(), tier.rateLimit(), TierConfig.RATE_LIMIT_WINDOW_SECONDS },
        );
        defer self.allocator.free(body);
        return self.customResponse(429, "application/json", body);
    }

    /// Format an HTTP 403 Forbidden response for tier-gated endpoints.
    pub fn forbiddenResponse(self: *HttpApiServer) ![]u8 {
        const body =
            \\{"error":"tier_required","message":"This endpoint requires staking. Stake 100+ TRI to access.","min_stake":"100 TRI"}
        ;
        return self.customResponse(403, "application/json", body);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP PARSING
    // ─────────────────────────────────────────────────────────────────────────

    /// Parse a raw HTTP request into method, path, body, and wallet address.
    /// Input: "GET /health HTTP/1.1\r\nHost: ...\r\nX-Wallet: 0x...\r\n\r\n"
    pub fn parseRequest(raw: []const u8) HttpRequest {
        var method = HttpMethod.UNKNOWN;
        var path: []const u8 = "/";
        var body: []const u8 = "";
        var wallet_address: []const u8 = "";

        if (raw.len == 0) {
            return .{ .method = method, .path = path, .body = body, .raw = raw, .wallet_address = wallet_address };
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

        // Parse headers: find X-Wallet header (case-sensitive)
        // Headers are between the first \r\n and \r\n\r\n
        if (std.mem.indexOf(u8, raw, "\r\n")) |first_line_end| {
            const headers_start = first_line_end + 2;
            const headers_end = if (std.mem.indexOf(u8, raw, "\r\n\r\n")) |sep| sep else raw.len;
            if (headers_start < headers_end) {
                const headers_section = raw[headers_start..headers_end];
                // Scan for X-Wallet: header
                var pos: usize = 0;
                while (pos < headers_section.len) {
                    // Find end of this header line
                    const line_end = if (std.mem.indexOf(u8, headers_section[pos..], "\r\n")) |le| pos + le else headers_section.len;
                    const line = headers_section[pos..line_end];

                    if (line.len > 10 and (std.mem.startsWith(u8, line, "X-Wallet:") or std.mem.startsWith(u8, line, "x-wallet:"))) {
                        // Extract value after "X-Wallet:" and trim whitespace
                        var val_start: usize = 9; // len("X-Wallet:")
                        while (val_start < line.len and line[val_start] == ' ') : (val_start += 1) {}
                        var val_end: usize = line.len;
                        while (val_end > val_start and line[val_end - 1] == ' ') : (val_end -= 1) {}
                        if (val_end > val_start) {
                            wallet_address = line[val_start..val_end];
                        }
                        break;
                    }

                    if (line_end >= headers_section.len) break;
                    pos = line_end + 2; // skip \r\n
                }
            }
        }

        // Parse body: find \r\n\r\n separator
        if (std.mem.indexOf(u8, raw, "\r\n\r\n")) |sep| {
            const body_start = sep + 4;
            if (body_start < raw.len) {
                body = raw[body_start..];
            }
        }

        return .{ .method = method, .path = path, .body = body, .raw = raw, .wallet_address = wallet_address };
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
            403 => "Forbidden",
            404 => "Not Found",
            405 => "Method Not Allowed",
            429 => "Too Many Requests",
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
    /// Enforces stake-based tier access control and per-wallet rate limiting.
    /// Returns the full HTTP response as a byte slice (caller owns memory).
    pub fn handleRequest(self: *HttpApiServer, raw_request: []const u8) ![]u8 {
        const request = parseRequest(raw_request);

        self.mutex.lock();
        self.stats.total_requests += 1;
        self.mutex.unlock();

        // Determine tier from wallet's staked amount
        const tier = self.determineTier(request.wallet_address);

        // Rate limit key: wallet address or "__anonymous__" for no-wallet requests
        const rate_key = if (request.wallet_address.len > 0) request.wallet_address else "__anonymous__";

        // Check rate limit (only enforced when staking engine is connected)
        if (self.staking_engine != null and self.checkRateLimit(rate_key, tier)) {
            self.mutex.lock();
            self.stats.error_responses += 1;
            self.mutex.unlock();
            return self.rateLimitResponse(tier);
        }

        // Free tier: restrict to allowed endpoints only (only enforced when staking engine is connected)
        if (self.staking_engine != null and tier == .free and !isFreeTierAllowed(request.path)) {
            self.mutex.lock();
            self.stats.error_responses += 1;
            self.mutex.unlock();
            return self.forbiddenResponse();
        }

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
        else if (std.mem.eql(u8, request.path, "/node/tier"))
            try self.handleNodeTier(request, tier)
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

    /// GET /node/tier -> tier info for the requesting wallet
    fn handleNodeTier(self: *HttpApiServer, request: HttpRequest, tier: NodeTier) ![]u8 {
        if (request.method != .GET) return self.methodNotAllowedResponse();

        const wallet_display = if (request.wallet_address.len > 0) request.wallet_address else "anonymous";
        const rate_key = if (request.wallet_address.len > 0) request.wallet_address else "__anonymous__";
        const remaining = self.getRemainingRequests(rate_key, tier);
        const limit = tier.rateLimit();

        const body = try std.fmt.allocPrint(
            self.allocator,
            \\{{"wallet":"{s}","tier":"{s}","rate_limit":{d},"reward_multiplier":{d:.1},"requests_remaining":{d},"unlimited":{s}}}
        ,
            .{
                wallet_display,
                tier.name(),
                limit,
                tier.rewardMultiplier(),
                remaining,
                if (limit == 0) "true" else "false",
            },
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
    try std.testing.expectEqualStrings("", request.wallet_address);
}

test "http_api: parse POST request with body" {
    const raw = "POST /search HTTP/1.1\r\nHost: localhost\r\nContent-Length: 27\r\n\r\n{\"query\":\"machine learning\"}";
    const request = HttpApiServer.parseRequest(raw);

    try std.testing.expectEqual(HttpMethod.POST, request.method);
    try std.testing.expectEqualStrings("/search", request.path);
    try std.testing.expectEqualStrings("{\"query\":\"machine learning\"}", request.body);
    try std.testing.expectEqualStrings("", request.wallet_address);
}

test "http_api: parse unknown method" {
    const request = HttpApiServer.parseRequest("PATCH /foo HTTP/1.1\r\n\r\n");
    try std.testing.expectEqual(HttpMethod.UNKNOWN, request.method);
}

test "http_api: parse X-Wallet header" {
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\nX-Wallet: 0xdeadbeef\r\n\r\n";
    const request = HttpApiServer.parseRequest(raw);

    try std.testing.expectEqual(HttpMethod.GET, request.method);
    try std.testing.expectEqualStrings("/health", request.path);
    try std.testing.expectEqualStrings("0xdeadbeef", request.wallet_address);
}

test "http_api: parse x-wallet header lowercase" {
    const raw = "GET /health HTTP/1.1\r\nx-wallet: 0xABCDEF\r\n\r\n";
    const request = HttpApiServer.parseRequest(raw);

    try std.testing.expectEqualStrings("0xABCDEF", request.wallet_address);
}

test "http_api: missing X-Wallet header defaults to empty" {
    const raw = "GET /health HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\n\r\n";
    const request = HttpApiServer.parseRequest(raw);

    try std.testing.expectEqualStrings("", request.wallet_address);
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

// ═══════════════════════════════════════════════════════════════════════════════
// TIER & RATE LIMITING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "http_api: tier detection from staked amount" {
    const allocator = std.testing.allocator;
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    var server = HttpApiServer.init(allocator);
    defer server.deinit();
    server.staking_engine = &staking;

    // No wallet -> free
    try std.testing.expectEqual(NodeTier.free, server.determineTier(""));

    // Unknown wallet -> free
    try std.testing.expectEqual(NodeTier.free, server.determineTier("0xunknown"));

    // Stake 150 TRI (staker tier: >= 100 TRI)
    var staker_id: [32]u8 = std.mem.zeroes([32]u8);
    const staker_wallet = "0xStakerWallet1234567890";
    @memcpy(staker_id[0..@min(staker_wallet.len, 32)], staker_wallet[0..@min(staker_wallet.len, 32)]);
    _ = staking.stake(staker_id, TierConfig.STAKER_MIN_WEI + 50_000_000_000_000_000_000); // 150 TRI
    try std.testing.expectEqual(NodeTier.staker, server.determineTier(staker_wallet));

    // Stake 2000 TRI (power tier: >= 1000 TRI)
    var power_id: [32]u8 = std.mem.zeroes([32]u8);
    const power_wallet = "0xPowerWallet12345678901";
    @memcpy(power_id[0..@min(power_wallet.len, 32)], power_wallet[0..@min(power_wallet.len, 32)]);
    _ = staking.stake(power_id, TierConfig.POWER_MIN_WEI + 1_000_000_000_000_000_000_000); // 2000 TRI
    try std.testing.expectEqual(NodeTier.power, server.determineTier(power_wallet));

    // Stake 15000 TRI (whale tier: >= 10000 TRI)
    var whale_id: [32]u8 = std.mem.zeroes([32]u8);
    const whale_wallet = "0xWhaleWallet12345678901";
    @memcpy(whale_id[0..@min(whale_wallet.len, 32)], whale_wallet[0..@min(whale_wallet.len, 32)]);
    _ = staking.stake(whale_id, TierConfig.WHALE_MIN_WEI + 5_000_000_000_000_000_000_000); // 15000 TRI
    try std.testing.expectEqual(NodeTier.whale, server.determineTier(whale_wallet));
}

test "http_api: free tier blocked from /node/stats" {
    const allocator = std.testing.allocator;
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    var server = HttpApiServer.init(allocator);
    defer server.deinit();
    server.staking_engine = &staking;

    // No wallet -> free tier -> /node/stats is forbidden
    const response = try server.handleRequest("GET /node/stats HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 403 Forbidden\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"error\":\"tier_required\"") != null);
}

test "http_api: staker tier accesses all endpoints" {
    const allocator = std.testing.allocator;
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    // Register staker
    var staker_id: [32]u8 = std.mem.zeroes([32]u8);
    const staker_wallet = "0xMyStaker12345678901234";
    @memcpy(staker_id[0..@min(staker_wallet.len, 32)], staker_wallet[0..@min(staker_wallet.len, 32)]);
    _ = staking.stake(staker_id, TierConfig.STAKER_MIN_WEI);

    var server = HttpApiServer.init(allocator);
    defer server.deinit();
    server.staking_engine = &staking;

    // Staker can access /node/stats (non-free endpoint)
    const response = try server.handleRequest("GET /node/stats HTTP/1.1\r\nX-Wallet: 0xMyStaker12345678901234\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"operations\"") != null);
}

test "http_api: GET /node/tier returns correct tier info" {
    const allocator = std.testing.allocator;
    var server = HttpApiServer.init(allocator);
    defer server.deinit();

    // Without staking engine, anonymous tier info
    const response = try server.handleRequest("GET /node/tier HTTP/1.1\r\n\r\n");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "\"tier\":\"free\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"wallet\":\"anonymous\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"rate_limit\":10") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"reward_multiplier\":1.0") != null);
}

test "http_api: free tier allows /health and /metrics" {
    const allocator = std.testing.allocator;
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    var server = HttpApiServer.init(allocator);
    defer server.deinit();
    server.staking_engine = &staking;

    // Free tier can access /health
    const r1 = try server.handleRequest("GET /health HTTP/1.1\r\n\r\n");
    defer allocator.free(r1);
    try std.testing.expect(std.mem.startsWith(u8, r1, "HTTP/1.1 200 OK\r\n"));

    // Free tier can access /metrics
    const r2 = try server.handleRequest("GET /metrics HTTP/1.1\r\n\r\n");
    defer allocator.free(r2);
    try std.testing.expect(std.mem.indexOf(u8, r2, "200 OK") != null);

    // Free tier can access /node/status
    const r3 = try server.handleRequest("GET /node/status HTTP/1.1\r\n\r\n");
    defer allocator.free(r3);
    try std.testing.expect(std.mem.startsWith(u8, r3, "HTTP/1.1 200 OK\r\n"));

    // Free tier can access /rewards/rates
    const r4 = try server.handleRequest("GET /rewards/rates HTTP/1.1\r\n\r\n");
    defer allocator.free(r4);
    try std.testing.expect(std.mem.startsWith(u8, r4, "HTTP/1.1 200 OK\r\n"));
}

test "http_api: rate limiting free tier" {
    const allocator = std.testing.allocator;
    var staking = token_staking_mod.TokenStakingEngine.initWithConfig(allocator, .{
        .min_stake_wei = 100,
        .pos_failure_slash_rate = 0.01,
        .corruption_slash_rate = 0.05,
        .min_reputation_for_staking = 0.2,
    });
    defer staking.deinit();

    var server = HttpApiServer.init(allocator);
    defer server.deinit();
    server.staking_engine = &staking;

    // Free tier limit is 10 req/min — make 10 requests then check 11th is rejected
    var responses: [11][]u8 = undefined;
    var count: usize = 0;
    defer {
        for (0..count) |i| allocator.free(responses[i]);
    }

    for (0..11) |_| {
        responses[count] = try server.handleRequest("GET /health HTTP/1.1\r\n\r\n");
        count += 1;
    }

    // First 10 should be 200 OK
    for (0..10) |i| {
        try std.testing.expect(std.mem.startsWith(u8, responses[i], "HTTP/1.1 200 OK\r\n"));
    }
    // 11th should be 429
    try std.testing.expect(std.mem.indexOf(u8, responses[10], "429 Too Many Requests") != null);
    try std.testing.expect(std.mem.indexOf(u8, responses[10], "\"error\":\"rate_limit_exceeded\"") != null);
}

test "http_api: tier config constants are correct" {
    // Verify tier thresholds match expected values
    try std.testing.expectEqual(@as(u128, 100_000_000_000_000_000_000), TierConfig.STAKER_MIN_WEI); // 100 TRI
    try std.testing.expectEqual(@as(u128, 1_000_000_000_000_000_000_000), TierConfig.POWER_MIN_WEI); // 1,000 TRI
    try std.testing.expectEqual(@as(u128, 10_000_000_000_000_000_000_000), TierConfig.WHALE_MIN_WEI); // 10,000 TRI

    // Rate limits
    try std.testing.expectEqual(@as(u32, 10), TierConfig.FREE_RATE_LIMIT);
    try std.testing.expectEqual(@as(u32, 60), TierConfig.STAKER_RATE_LIMIT);
    try std.testing.expectEqual(@as(u32, 300), TierConfig.POWER_RATE_LIMIT);
    try std.testing.expectEqual(@as(u32, 0), TierConfig.WHALE_RATE_LIMIT);

    // Reward multipliers
    try std.testing.expectEqual(@as(f64, 1.0), TierConfig.FREE_REWARD_MULTIPLIER);
    try std.testing.expectEqual(@as(f64, 1.5), TierConfig.STAKER_REWARD_MULTIPLIER);
    try std.testing.expectEqual(@as(f64, 2.0), TierConfig.POWER_REWARD_MULTIPLIER);
    try std.testing.expectEqual(@as(f64, 3.0), TierConfig.WHALE_REWARD_MULTIPLIER);
}

test "http_api: NodeTier methods" {
    try std.testing.expectEqualStrings("free", NodeTier.free.name());
    try std.testing.expectEqualStrings("staker", NodeTier.staker.name());
    try std.testing.expectEqualStrings("power", NodeTier.power.name());
    try std.testing.expectEqualStrings("whale", NodeTier.whale.name());

    try std.testing.expectEqual(@as(u32, 10), NodeTier.free.rateLimit());
    try std.testing.expectEqual(@as(u32, 60), NodeTier.staker.rateLimit());
    try std.testing.expectEqual(@as(u32, 300), NodeTier.power.rateLimit());
    try std.testing.expectEqual(@as(u32, 0), NodeTier.whale.rateLimit());

    try std.testing.expectEqual(@as(f64, 1.0), NodeTier.free.rewardMultiplier());
    try std.testing.expectEqual(@as(f64, 1.5), NodeTier.staker.rewardMultiplier());
    try std.testing.expectEqual(@as(f64, 2.0), NodeTier.power.rewardMultiplier());
    try std.testing.expectEqual(@as(f64, 3.0), NodeTier.whale.rewardMultiplier());
}
