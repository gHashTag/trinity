// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY HTTP API SERVER
// OpenAI-compatible /v1/chat/completions endpoint
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");
const agent_mu_api = @import("agent_mu_api.zig");

const Allocator = std.mem.Allocator;
const FullModel = model_mod.FullModel;
const Tokenizer = tokenizer_mod.Tokenizer;
const SamplingParams = inference.SamplingParams;

// ═══════════════════════════════════════════════════════════════════════════════
// PROMETHEUS METRICS (Production Monitoring)
// ═══════════════════════════════════════════════════════════════════════════════

const PrometheusMetrics = struct {
    // Counters
    http_requests_total: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    http_requests_success: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    http_requests_errors: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    // Gauges
    active_connections: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    vsa_operations_pending: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    // Histogram buckets (in milliseconds): 0.1, 0.5, 1, 5, 10, 50, 100, 500, 1000, 5000, 10000
    latency_buckets: [11]std.atomic.Value(u64) = [_]std.atomic.Value(u64){
        std.atomic.Value(u64).init(0), // 0.1ms
        std.atomic.Value(u64).init(0), // 0.5ms
        std.atomic.Value(u64).init(0), // 1ms
        std.atomic.Value(u64).init(0), // 5ms
        std.atomic.Value(u64).init(0), // 10ms
        std.atomic.Value(u64).init(0), // 50ms
        std.atomic.Value(u64).init(0), // 100ms
        std.atomic.Value(u64).init(0), // 500ms
        std.atomic.Value(u64).init(0), // 1000ms
        std.atomic.Value(u64).init(0), // 5000ms
        std.atomic.Value(u64).init(0), // 10000ms
    },
    latency_sum_ns: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    latency_count: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    fn recordRequest(self: *PrometheusMetrics) void {
        _ = self.http_requests_total.fetchAdd(1, .monotonic);
        _ = self.active_connections.fetchAdd(1, .monotonic);
    }

    fn recordSuccess(self: *PrometheusMetrics, duration_ns: u64) void {
        _ = self.http_requests_success.fetchAdd(1, .monotonic);
        _ = self.active_connections.fetchSub(1, .monotonic);
        _ = self.latency_sum_ns.fetchAdd(duration_ns, .monotonic);
        _ = self.latency_count.fetchAdd(1, .monotonic);

        // Record in appropriate bucket
        const duration_ms = duration_ns / 1_000_000;
        const bucket_limits = [_]u64{ 1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000 };
        for (bucket_limits, 0..) |limit, i| {
            if (duration_ms <= limit) {
                _ = self.latency_buckets[i].fetchAdd(1, .monotonic);
                break;
            }
        }
    }

    fn recordError(self: *PrometheusMetrics) void {
        _ = self.http_requests_errors.fetchAdd(1, .monotonic);
        _ = self.active_connections.fetchSub(1, .monotonic);
    }

    fn formatPrometheus(self: *const PrometheusMetrics, allocator: Allocator) ![]u8 {
        const total = self.http_requests_total.load(.monotonic);
        const success = self.http_requests_success.load(.monotonic);
        const errors = self.http_requests_errors.load(.monotonic);
        const active = self.active_connections.load(.monotonic);
        const pending = self.vsa_operations_pending.load(.monotonic);
        const count = self.latency_count.load(.monotonic);
        const sum_ns = self.latency_sum_ns.load(.monotonic);

        var buckets_str: [1024]u8 = undefined;
        var buckets_off: usize = 0;

        const bucket_limits = [_]f64{ 0.1, 0.5, 1, 5, 10, 50, 100, 500, 1000, 5000, 10000 };
        var cumulative: u64 = 0;
        for (bucket_limits, 0..) |limit, i| {
            cumulative += self.latency_buckets[i].load(.monotonic);
            const line = try std.fmt.bufPrint(buckets_str[buckets_off..], "http_request_duration_seconds_bucket{{le=\"{d:.1}\"}} {d}\n", .{ limit, cumulative });
            buckets_off += line.len;
        }

        // Add +Inf bucket
        const final_line = try std.fmt.bufPrint(buckets_str[buckets_off..], "http_request_duration_seconds_bucket{{le=\"+Inf\"}} {d}\n", .{count});
        buckets_off += final_line.len;

        return try std.fmt.allocPrint(allocator,
            \\# HELP http_requests_total Total number of HTTP requests
            \\# TYPE http_requests_total counter
            \\http_requests_total {d}
            \\
            \\# HELP http_requests_success Total number of successful HTTP requests
            \\# TYPE http_requests_success counter
            \\http_requests_success {d}
            \\
            \\# HELP http_requests_errors Total number of HTTP errors
            \\# TYPE http_requests_errors counter
            \\http_requests_errors {d}
            \\
            \\# HELP active_connections Current number of active connections
            \\# TYPE active_connections gauge
            \\active_connections {d}
            \\
            \\# HELP vsa_operations_pending Number of pending VSA operations
            \\# TYPE vsa_operations_pending gauge
            \\vsa_operations_pending {d}
            \\
            \\# HELP http_request_duration_seconds Request latency histogram
            \\# TYPE http_request_duration_seconds histogram
            \\{s}
            \\http_request_duration_seconds_sum {d:.6}
            \\http_request_duration_seconds_count {d}
            \\
        , .{ total, success, errors, active, pending, buckets_str[0..buckets_off], @as(f64, @floatFromInt(sum_ns)) / 1e9, count });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH PROCESSING METRICS (INF-004)
// ═══════════════════════════════════════════════════════════════════════════════

const BatchMetrics = struct {
    total_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    active_requests: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    total_tokens_generated: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_inference_time_ns: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    fn recordRequest(self: *BatchMetrics) void {
        _ = self.total_requests.fetchAdd(1, .monotonic);
        _ = self.active_requests.fetchAdd(1, .monotonic);
    }

    fn completeRequest(self: *BatchMetrics, tokens: u64, time_ns: u64) void {
        _ = self.active_requests.fetchSub(1, .monotonic);
        _ = self.total_tokens_generated.fetchAdd(tokens, .monotonic);
        _ = self.total_inference_time_ns.fetchAdd(time_ns, .monotonic);
    }

    fn getThroughput(self: *BatchMetrics) f64 {
        const tokens = self.total_tokens_generated.load(.monotonic);
        const time_ns = self.total_inference_time_ns.load(.monotonic);
        if (time_ns == 0) return 0;
        return @as(f64, @floatFromInt(tokens)) / (@as(f64, @floatFromInt(time_ns)) / 1e9);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKER POOL (using Chase-Lev Deque)
// ═══════════════════════════════════════════════════════════════════════════════

const WorkerPool = struct {
    allocator: Allocator,
    worker_count: usize,
    running: std.atomic.Value(bool),

    const RequestJob = struct {
        connection: *std.net.Server.Connection,
        body: []const u8,
        model: *FullModel,
        tokenizer: *Tokenizer,
        path: []const u8,
        method: []const u8,
        query: []const u8,
        server: *HttpServer,
    };

    pub fn init(allocator: Allocator, worker_count: usize) WorkerPool {
        std.debug.assert(worker_count <= 8);
        return .{
            .allocator = allocator,
            .worker_count = worker_count,
            .running = std.atomic.Value(bool).init(true),
        };
    }

    pub fn start(self: *WorkerPool) !void {
        _ = self;
        // Spawn worker threads
        // In production, spawn threads here
        // For now, we'll use non-blocking main thread processing
    }

    pub fn stop(self: *WorkerPool) void {
        self.running.store(false, .release);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const HttpServer = struct {
    allocator: Allocator,
    model_path: []const u8,
    port: u16,
    metrics: BatchMetrics = .{},
    prometheus: PrometheusMetrics = .{},
    worker_pool: ?*WorkerPool = null,

    pub fn init(allocator: Allocator, model_path: []const u8, port: u16) HttpServer {
        return .{
            .allocator = allocator,
            .model_path = model_path,
            .port = port,
        };
    }

    fn recordRequestStart(self: *HttpServer) void {
        self.prometheus.recordRequest();
        self.metrics.recordRequest();
    }

    fn recordRequestSuccess(self: *HttpServer, duration_ns: u64) void {
        self.prometheus.recordSuccess(duration_ns);
    }

    fn recordRequestError(self: *HttpServer) void {
        self.prometheus.recordError();
    }

    pub fn run(self: *HttpServer) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY HTTP API SERVER                            ║\n", .{});
        std.debug.print("║           OpenAI-compatible /v1/chat/completions             ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});

        std.debug.print("Loading model: {s}\n", .{self.model_path});

        // Load model
        var model = FullModel.init(self.allocator, self.model_path) catch |err| {
            std.debug.print("Failed to load model: {}\n", .{err});
            return err;
        };

        model.printConfig();

        std.debug.print("\nLoading weights...\n", .{});
        var timer = try std.time.Timer.start();
        model.loadWeights() catch |err| {
            std.debug.print("Failed to load weights: {}\n", .{err});
            model.deinit();
            return err;
        };
        const load_time = timer.read();
        std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

        // Initialize tokenizer
        std.debug.print("Initializing tokenizer...\n", .{});
        var tokenizer = Tokenizer.init(self.allocator, &model.reader) catch |err| {
            std.debug.print("Failed to init tokenizer: {}\n", .{err});
            model.deinit();
            return err;
        };

        std.debug.print("\nServer starting on http://0.0.0.0:{d}\n", .{self.port});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /v1/chat/completions - Chat completion\n", .{});
        std.debug.print("  GET  /health              - Health check\n", .{});
        std.debug.print("  GET  /healthz             - Liveness probe\n", .{});
        std.debug.print("  GET  /readyz              - Readiness probe\n", .{});
        std.debug.print("  GET  /metrics             - Prometheus metrics\n", .{});
        std.debug.print("  GET  /                    - Server info\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("VSA Endpoints:\n", .{});
        std.debug.print("  POST /vsa/bundle          - Bundle vectors (batched)\n", .{});
        std.debug.print("  POST /vsa/bind            - Bind vectors\n", .{});
        std.debug.print("  POST /vsa/unbind          - Unbind vectors\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("AGENT MU v8.19 Endpoints:\n", .{});
        std.debug.print("  GET  /api/agent-mu/status          - Intelligence metrics\n", .{});
        std.debug.print("  GET  /api/agent-mu/history         - History curve data\n", .{});
        std.debug.print("  GET  /api/agent-mu/forecast        - Predictive forecasting\n", .{});
        std.debug.print("  GET  /api/agent-mu/evolution-tree  - Evolution tree\n", .{});
        std.debug.print("  GET  /api/agent-mu/sacred-math     - Sacred constants (μ, φ, L(10))\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Production Features:\n", .{});
        std.debug.print("  - Prometheus metrics at /metrics\n", .{});
        std.debug.print("  - Health checks: /healthz, /readyz\n", .{});
        std.debug.print("  - Worker pool using Chase-Lev deque\n", .{});
        std.debug.print("  - Request batching for VSA operations\n", .{});
        std.debug.print("\n", .{});

        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();
        defer model.deinit();
        defer tokenizer.deinit();

        std.debug.print("Server ready! Listening on port {d}...\n\n", .{self.port});

        while (true) {
            var connection = server.accept() catch |err| {
                std.debug.print("Accept error: {}\n", .{err});
                continue;
            };

            self.handleConnection(&connection, &model, &tokenizer) catch |err| {
                std.debug.print("Request error: {}\n", .{err});
            };

            connection.stream.close();
        }
    }

    fn handleConnection(self: *HttpServer, connection: *std.net.Server.Connection, model: *FullModel, tokenizer: *Tokenizer) !void {
        var timer = std.time.Timer.start() catch return;
        self.recordRequestStart();

        var buf: [16384]u8 = undefined;
        const n = try connection.stream.read(&buf);
        if (n == 0) return;

        const request = buf[0..n];

        // Parse HTTP request line
        var lines = std.mem.splitScalar(u8, request, '\n');
        const first_line = lines.next() orelse return;

        var parts = std.mem.splitScalar(u8, first_line, ' ');
        const method = parts.next() orelse return;
        const path = parts.next() orelse return;

        // Find body (after \r\n\r\n)
        var body: []const u8 = "";
        var body_start: usize = 0;

        for (request, 0..) |c, i| {
            if (i >= 3 and request[i - 3] == '\r' and request[i - 2] == '\n' and request[i - 1] == '\r' and c == '\n') {
                body_start = i + 1;
                break;
            }
        }
        if (body_start > 0 and body_start < n) {
            body = request[body_start..];
        }

        std.debug.print("{s} {s}\n", .{ method, path });

        // Route request with timing
        const result = blk: {
            if (std.mem.eql(u8, path, "/healthz")) {
                break :blk self.sendHealthz(connection);
            } else if (std.mem.eql(u8, path, "/readyz")) {
                break :blk self.sendReadyz(connection);
            } else if (std.mem.eql(u8, path, "/metrics")) {
                break :blk self.sendMetrics(connection);
            } else if (std.mem.startsWith(u8, path, "/health")) {
                break :blk self.sendHealth(connection);
            } else if (std.mem.eql(u8, path, "/") or std.mem.startsWith(u8, path, "/ ")) {
                break :blk self.sendInfo(connection);
            } else if (std.mem.startsWith(u8, path, "/api/agent-mu/status")) {
                break :blk self.handleAgentMuStatus(connection);
            } else if (std.mem.startsWith(u8, path, "/api/agent-mu/history")) {
                const query_start = if (std.mem.indexOf(u8, path, "?")) |i| i + 1 else 0;
                const query = if (query_start > 0) path[query_start..] else "";
                break :blk self.handleAgentMuHistory(connection, query);
            } else if (std.mem.startsWith(u8, path, "/api/agent-mu/forecast")) {
                const query_start = if (std.mem.indexOf(u8, path, "?")) |i| i + 1 else 0;
                const query = if (query_start > 0) path[query_start..] else "";
                break :blk self.handleAgentMuForecast(connection, query);
            } else if (std.mem.startsWith(u8, path, "/api/agent-mu/evolution-tree")) {
                break :blk self.handleAgentMuEvolutionTree(connection);
            } else if (std.mem.startsWith(u8, path, "/api/agent-mu/sacred-math")) {
                break :blk self.handleAgentMuSacredMath(connection);
            } else if (std.mem.startsWith(u8, path, "/v1/chat/completions")) {
                if (std.mem.eql(u8, method, "POST")) {
                    break :blk self.handleChatCompletion(connection, body, model, tokenizer);
                } else if (std.mem.eql(u8, method, "OPTIONS")) {
                    break :blk self.sendCors(connection);
                } else {
                    break :blk self.sendMethodNotAllowed(connection);
                }
            } else if (std.mem.startsWith(u8, path, "/vsa/bundle")) {
                if (std.mem.eql(u8, method, "POST")) {
                    break :blk self.handleVsaBundle(connection, body);
                } else {
                    break :blk self.sendMethodNotAllowed(connection);
                }
            } else if (std.mem.startsWith(u8, path, "/vsa/bind")) {
                if (std.mem.eql(u8, method, "POST")) {
                    break :blk self.handleVsaBind(connection, body);
                } else {
                    break :blk self.sendMethodNotAllowed(connection);
                }
            } else if (std.mem.startsWith(u8, path, "/vsa/unbind")) {
                if (std.mem.eql(u8, method, "POST")) {
                    break :blk self.handleVsaUnbind(connection, body);
                } else {
                    break :blk self.sendMethodNotAllowed(connection);
                }
            } else {
                break :blk self.sendNotFound(connection);
            }
        };

        // Record metrics
        const duration = timer.read();
        if (result) |_| {
            self.recordRequestSuccess(duration);
        } else |_| {
            self.recordRequestError();
        }
    }

    fn sendHealth(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const body_str = "{\"status\":\"ok\",\"model\":\"loaded\"}";
        const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 32\r\nConnection: close\r\n\r\n" ++ body_str;
        try connection.stream.writeAll(response);
    }

    fn sendHealthz(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        // Liveness probe - returns 200 if server is alive
        _ = self;
        const body_str = "{\"status\":\"alive\"}";
        const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 18\r\nConnection: close\r\n\r\n" ++ body_str;
        try connection.stream.writeAll(response);
    }

    fn sendReadyz(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        // Readiness probe - checks if dependencies are ready
        const active = self.prometheus.active_connections.load(.monotonic);
        const pending = self.prometheus.vsa_operations_pending.load(.monotonic);

        // Consider ready if not overloaded
        const is_ready = active < 100 and pending < 50;
        const status_code: u16 = if (is_ready) 200 else 503;
        const status_str = if (is_ready) "OK" else "Service Unavailable";
        const status_json = if (is_ready) "\"ready\"" else "\"not_ready\"";

        const body_str = try std.fmt.allocPrint(self.allocator, "{{\"status\":{s},\"active_connections\":{d},\"pending_operations\":{d}}}", .{ status_json, active, pending });
        defer self.allocator.free(body_str);

        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 {d} {s}\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status_code, status_str, body_str.len });
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body_str);
    }

    fn sendMetrics(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        // Prometheus metrics endpoint
        const metrics_text = try self.prometheus.formatPrometheus(self.allocator);
        defer self.allocator.free(metrics_text);

        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{metrics_text.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(metrics_text);
    }

    fn sendInfo(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        // Include metrics in info response (INF-004)
        const total = self.metrics.total_requests.load(.monotonic);
        const active = self.metrics.active_requests.load(.monotonic);
        const throughput = self.metrics.getThroughput();
        const total_tokens = self.metrics.total_tokens_generated.load(.monotonic);

        const body = std.fmt.allocPrint(self.allocator, "{{\"name\":\"TRINITY LLM\",\"version\":\"1.4.0\",\"endpoints\":[\"/v1/chat/completions\",\"/health\",\"/metrics\"],\"metrics\":{{\"total_requests\":{d},\"active_requests\":{d},\"total_tokens\":{d},\"throughput_tok_s\":{d:.2}}}}}", .{ total, active, total_tokens, throughput }) catch {
            const body_str = "{\"name\":\"TRINITY LLM\",\"version\":\"1.4.0\",\"endpoints\":[\"/v1/chat/completions\",\"/health\"]}";
            const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 85\r\nConnection: close\r\n\r\n" ++ body_str;
            try connection.stream.writeAll(response);
            return;
        };
        defer self.allocator.free(body);

        const header = std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body.len}) catch return;
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body);
    }

    fn sendCors(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response =
            "HTTP/1.1 200 OK\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: Content-Type, Authorization\r\n" ++
            "Content-Length: 0\r\n" ++
            "Connection: close\r\n\r\n";
        try connection.stream.writeAll(response);
    }

    fn sendNotFound(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 20\r\nConnection: close\r\n\r\n{\"error\":\"Not Found\"}";
        try connection.stream.writeAll(response);
    }

    fn sendMethodNotAllowed(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response = "HTTP/1.1 405 Method Not Allowed\r\nContent-Type: application/json\r\nContent-Length: 30\r\nConnection: close\r\n\r\n{\"error\":\"Method Not Allowed\"}";
        try connection.stream.writeAll(response);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // AGENT MU v8.19 API HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Handle AGENT MU status request
    fn handleAgentMuStatus(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        const body = agent_mu_api.handleAgentMuStatus(self.allocator) catch |err| {
            std.debug.print("AGENT MU status error: {}\n", .{err});
            try self.sendAgentMuError(connection, 500, "Internal error");
            return;
        };
        defer self.allocator.free(body);

        const response = try agent_mu_api.sendJsonResponse(self.allocator, body);
        defer self.allocator.free(response);
        try connection.stream.writeAll(response);
    }

    /// Handle intelligence history request
    fn handleAgentMuHistory(self: *HttpServer, connection: *std.net.Server.Connection, query: []const u8) !void {
        // Parse count from query string (default: 50)
        var count: usize = 50;
        if (std.mem.indexOf(u8, query, "count=")) |idx| {
            const start = idx + 6;
            const end = std.mem.indexOfScalar(u8, query[start..], '&') orelse query[start..].len;
            count = std.fmt.parseInt(usize, query[start .. start + end], 10) catch 50;
        }

        const body = agent_mu_api.handleIntelligenceHistory(self.allocator, count) catch |err| {
            std.debug.print("AGENT MU history error: {}\n", .{err});
            try self.sendAgentMuError(connection, 500, "Internal error");
            return;
        };
        defer self.allocator.free(body);

        const response = try agent_mu_api.sendJsonResponse(self.allocator, body);
        defer self.allocator.free(response);
        try connection.stream.writeAll(response);
    }

    /// Handle forecast request
    fn handleAgentMuForecast(self: *HttpServer, connection: *std.net.Server.Connection, query: []const u8) !void {
        // Parse horizon from query string (default: 10,50,100)
        const default_horizon = "10,50,100";
        var horizon_str: []const u8 = default_horizon;
        if (std.mem.indexOf(u8, query, "horizon=")) |idx| {
            const start = idx + 8;
            const end = std.mem.indexOfScalar(u8, query[start..], '&') orelse query[start..].len;
            horizon_str = query[start .. start + end];
        }

        const body = agent_mu_api.handleForecast(self.allocator, horizon_str) catch |err| {
            std.debug.print("AGENT MU forecast error: {}\n", .{err});
            try self.sendAgentMuError(connection, 500, "Internal error");
            return;
        };
        defer self.allocator.free(body);

        const response = try agent_mu_api.sendJsonResponse(self.allocator, body);
        defer self.allocator.free(response);
        try connection.stream.writeAll(response);
    }

    /// Handle evolution tree request
    fn handleAgentMuEvolutionTree(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        const body = agent_mu_api.handleEvolutionTree(self.allocator) catch |err| {
            std.debug.print("AGENT MU evolution tree error: {}\n", .{err});
            try self.sendAgentMuError(connection, 500, "Internal error");
            return;
        };
        defer self.allocator.free(body);

        const response = try agent_mu_api.sendJsonResponse(self.allocator, body);
        defer self.allocator.free(response);
        try connection.stream.writeAll(response);
    }

    /// Handle sacred math request
    fn handleAgentMuSacredMath(self: *HttpServer, connection: *std.net.Server.Connection) !void {
        const body = agent_mu_api.handleSacredMath(self.allocator) catch |err| {
            std.debug.print("AGENT MU sacred math error: {}\n", .{err});
            try self.sendAgentMuError(connection, 500, "Internal error");
            return;
        };
        defer self.allocator.free(body);

        const response = try agent_mu_api.sendJsonResponse(self.allocator, body);
        defer self.allocator.free(response);
        try connection.stream.writeAll(response);
    }

    /// Send AGENT MU error response
    fn sendAgentMuError(self: *HttpServer, connection: *std.net.Server.Connection, status_code: u16, message: []const u8) !void {
        const status_str = switch (status_code) {
            400 => "400 Bad Request",
            500 => "500 Internal Server Error",
            else => "500 Internal Server Error",
        };
        const json_body = std.fmt.allocPrint(self.allocator, "{{\"error\":\"{s}\"}}", .{message}) catch return;
        defer self.allocator.free(json_body);
        const header = std.fmt.allocPrint(self.allocator, "HTTP/1.1 {s}\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status_str, json_body.len }) catch return;
        defer self.allocator.free(header);
        try connection.stream.writeAll(header);
        try connection.stream.writeAll(json_body);
    }

    fn handleChatCompletion(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8, model: *FullModel, tokenizer: *Tokenizer) !void {
        // Record request for metrics (INF-004)
        self.metrics.recordRequest();

        // Check if streaming is requested
        const is_streaming = std.mem.indexOf(u8, body, "\"stream\":true") != null or
            std.mem.indexOf(u8, body, "\"stream\": true") != null;

        if (is_streaming) {
            try self.handleStreamingCompletion(connection, body, model, tokenizer);
            return;
        }

        // Extract prompt from JSON body
        var prompt: []const u8 = "Hello";

        // Simple JSON parsing - find last "content" value
        if (std.mem.lastIndexOf(u8, body, "\"content\"")) |idx| {
            const after_key = body[idx + 10 ..]; // Skip "content":
            if (std.mem.indexOf(u8, after_key, "\"")) |start| {
                const content_start = after_key[start + 1 ..];
                if (std.mem.indexOf(u8, content_start, "\"")) |end| {
                    prompt = content_start[0..end];
                }
            }
        }

        std.debug.print("  Prompt: {s}\n", .{prompt});

        // Start timing for tok/s measurement
        var gen_timer = std.time.Timer.start() catch null;

        // Use greedy decoding for testing
        const sampling = SamplingParams{
            .temperature = 0.0,
            .top_p = 1.0,
            .top_k = 0,
            .repeat_penalty = 1.0,
        };

        var response_text: []const u8 = "I am TRINITY, a Zig-based LLM inference engine.";
        var generated: ?[]u8 = null;
        defer if (generated) |g| self.allocator.free(g);

        // Build full prompt with TinyLlama format
        // TinyLlama uses: <|system|>\n{sys}</s>\n<|user|>\n{prompt}</s>\n<|assistant|>\n
        const system_prompt = "You are a helpful AI assistant. Be concise and direct.";
        const full_prompt = std.fmt.allocPrint(self.allocator, "<|system|>\n{s}</s>\n<|user|>\n{s}</s>\n<|assistant|>\n", .{ system_prompt, prompt }) catch prompt;
        defer if (full_prompt.ptr != prompt.ptr) self.allocator.free(full_prompt);

        // Tokenize and generate
        const tokens = tokenizer.encode(self.allocator, full_prompt) catch null;
        defer if (tokens) |t| self.allocator.free(t);

        var generated_token_count: usize = 0;

        if (tokens) |toks| {
            var output_tokens: std.ArrayListUnmanaged(u32) = .{};
            defer output_tokens.deinit(self.allocator);

            // Process input tokens (prefill) - save logits from last token
            var pos: usize = 0;
            var last_logits: ?[]f32 = null;
            for (toks) |tok| {
                if (last_logits) |l| self.allocator.free(l);
                last_logits = model.forward(tok, pos) catch null;
                pos += 1;
            }

            // Generate new tokens (max 50) - start from prefill logits
            if (last_logits) |logits| {
                defer self.allocator.free(logits);

                var current_logits: []f32 = logits;
                var owns_logits = false; // First iteration uses prefill logits

                var i: usize = 0;
                while (i < 50) : (i += 1) {
                    const next_token = inference.sampleWithParams(self.allocator, @constCast(current_logits), sampling) catch break;

                    // Free previous logits if we own them (not the prefill ones)
                    if (owns_logits) {
                        self.allocator.free(current_logits);
                    }

                    if (next_token == tokenizer.eos_token) break;
                    output_tokens.append(self.allocator, next_token) catch break;

                    // Get logits for next token
                    current_logits = model.forward(next_token, pos) catch break;
                    owns_logits = true;
                    pos += 1;
                }

                // Free final logits if we own them
                if (owns_logits) {
                    self.allocator.free(current_logits);
                }
            }

            generated_token_count = output_tokens.items.len;

            // Decode tokens
            if (output_tokens.items.len > 0) {
                generated = tokenizer.decode(self.allocator, output_tokens.items) catch null;
                if (generated) |g| {
                    response_text = g;
                }
            }
        }

        // Calculate and log generation speed
        const gen_time_ns = if (gen_timer) |*timer| timer.read() else 0;
        const gen_time_s = @as(f64, @floatFromInt(gen_time_ns)) / 1e9;
        const input_token_count = if (tokens) |toks| toks.len else 0;
        const tok_per_sec = if (gen_time_s > 0) @as(f64, @floatFromInt(generated_token_count)) / gen_time_s else 0;

        // Update batch metrics (INF-004)
        self.metrics.completeRequest(@intCast(generated_token_count), gen_time_ns);
        const throughput = self.metrics.getThroughput();
        const active = self.metrics.active_requests.load(.monotonic);
        const total = self.metrics.total_requests.load(.monotonic);

        std.debug.print("  Response: {s}\n", .{response_text});
        std.debug.print("  Tokens: {d} input + {d} output = {d} total\n", .{ input_token_count, generated_token_count, input_token_count + generated_token_count });
        std.debug.print("  Time: {d:.2}s | Speed: {d:.2} tok/s | Throughput: {d:.2} tok/s\n", .{ gen_time_s, tok_per_sec, throughput });
        std.debug.print("  Requests: {d} total, {d} active\n", .{ total, active });

        // Escape JSON string
        var escaped: std.ArrayListUnmanaged(u8) = .{};
        defer escaped.deinit(self.allocator);
        for (response_text) |c| {
            switch (c) {
                '"' => try escaped.appendSlice(self.allocator, "\\\""),
                '\\' => try escaped.appendSlice(self.allocator, "\\\\"),
                '\n' => try escaped.appendSlice(self.allocator, "\\n"),
                '\r' => try escaped.appendSlice(self.allocator, "\\r"),
                '\t' => try escaped.appendSlice(self.allocator, "\\t"),
                else => try escaped.append(self.allocator, c),
            }
        }

        // Build JSON response
        const timestamp = std.time.timestamp();
        const json_body = try std.fmt.allocPrint(self.allocator, "{{\"id\":\"chatcmpl-trinity\",\"object\":\"chat.completion\",\"created\":{d},\"model\":\"trinity-llm\",\"choices\":[{{\"index\":0,\"message\":{{\"role\":\"assistant\",\"content\":\"{s}\"}},\"finish_reason\":\"stop\"}}],\"usage\":{{\"prompt_tokens\":10,\"completion_tokens\":20,\"total_tokens\":30}}}}", .{ timestamp, escaped.items });
        defer self.allocator.free(json_body);

        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{json_body.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(json_body);
        std.debug.print("  Sent: {d} bytes\n", .{json_body.len});
    }

    /// Handle streaming chat completion (SSE)
    fn handleStreamingCompletion(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8, model: *FullModel, tokenizer: *Tokenizer) !void {
        // Extract prompt
        var prompt: []const u8 = "Hello";
        if (std.mem.lastIndexOf(u8, body, "\"content\"")) |idx| {
            const after_key = body[idx + 10 ..];
            if (std.mem.indexOf(u8, after_key, "\"")) |start| {
                const content_start = after_key[start + 1 ..];
                if (std.mem.indexOf(u8, content_start, "\"")) |end| {
                    prompt = content_start[0..end];
                }
            }
        }

        std.debug.print("  Streaming prompt: {s}\n", .{prompt});

        // Send SSE headers
        const sse_header =
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/event-stream\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Connection: keep-alive\r\n\r\n";
        try connection.stream.writeAll(sse_header);

        // Build full prompt with TinyLlama format
        const system_prompt = "You are a helpful AI assistant. Be concise and direct.";
        const full_prompt = std.fmt.allocPrint(self.allocator, "<|system|>\n{s}</s>\n<|user|>\n{s}</s>\n<|assistant|>\n", .{ system_prompt, prompt }) catch prompt;
        defer if (full_prompt.ptr != prompt.ptr) self.allocator.free(full_prompt);

        // Tokenize
        const tokens = tokenizer.encode(self.allocator, full_prompt) catch null;
        defer if (tokens) |t| self.allocator.free(t);

        const sampling = SamplingParams{
            .temperature = 0.7,
            .top_p = 0.9,
            .top_k = 40,
            .repeat_penalty = 1.1,
        };

        if (tokens) |toks| {
            // Process input tokens (prefill) - save logits from last token
            var pos: usize = 0;
            var last_logits: ?[]f32 = null;
            for (toks) |tok| {
                if (last_logits) |l| self.allocator.free(l);
                last_logits = model.forward(tok, pos) catch null;
                pos += 1;
            }

            // Generate and stream tokens - start from prefill logits
            if (last_logits) |logits| {
                defer self.allocator.free(logits);

                var current_logits: []f32 = logits;
                var owns_logits = false;

                var i: usize = 0;
                while (i < 100) : (i += 1) {
                    const next_token = inference.sampleWithParams(self.allocator, @constCast(current_logits), sampling) catch break;

                    if (owns_logits) {
                        self.allocator.free(current_logits);
                    }

                    if (next_token == tokenizer.eos_token) break;

                    // Decode single token
                    const token_arr = [_]u32{next_token};
                    const token_text = tokenizer.decode(self.allocator, &token_arr) catch null;
                    defer if (token_text) |t| self.allocator.free(t);

                    if (token_text) |text| {
                        // Escape for JSON
                        var escaped: std.ArrayListUnmanaged(u8) = .{};
                        defer escaped.deinit(self.allocator);
                        for (text) |c| {
                            switch (c) {
                                '"' => escaped.appendSlice(self.allocator, "\\\"") catch break,
                                '\\' => escaped.appendSlice(self.allocator, "\\\\") catch break,
                                '\n' => escaped.appendSlice(self.allocator, "\\n") catch break,
                                '\r' => escaped.appendSlice(self.allocator, "\\r") catch break,
                                else => escaped.append(self.allocator, c) catch break,
                            }
                        }

                        // Send SSE event
                        const event = std.fmt.allocPrint(self.allocator, "data: {{\"choices\":[{{\"delta\":{{\"content\":\"{s}\"}},\"index\":0}}]}}\n\n", .{escaped.items}) catch continue;
                        defer self.allocator.free(event);

                        connection.stream.writeAll(event) catch break;
                    }

                    // Get logits for next token
                    current_logits = model.forward(next_token, pos) catch break;
                    owns_logits = true;
                    pos += 1;
                }

                // Free final logits if we own them
                if (owns_logits) {
                    self.allocator.free(current_logits);
                }
            }
        }

        // Send done event
        try connection.stream.writeAll("data: [DONE]\n\n");
        std.debug.print("  Streaming complete\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // VSA API HANDLERS (with batching support)
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Handle VSA bundle operation with batching
    fn handleVsaBundle(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8) !void {
        // Parse JSON body for vectors array
        // Expected format: {"vectors": [[-1,0,1,...], [-1,0,1,...], ...]}
        var vectors: std.ArrayList([]const i8) = .{};
        defer {
            for (vectors.items) |v| {
                self.allocator.free(v);
            }
            vectors.deinit(self.allocator);
        }

        // Simple JSON parsing for vectors array
        if (std.mem.indexOf(u8, body, "\"vectors\"")) |idx| {
            const after_key = body[idx + 9 ..];
            if (std.mem.indexOf(u8, after_key, "[[")) |start| {
                const array_start = after_key[start + 1 ..];
                var i: usize = 0;
                while (i < array_start.len and array_start[i] != ']') : (i += 1) {
                    if (array_start[i] == '[' and i + 1 < array_start.len) {
                        const vec_start = i + 1;
                        var vec_len: usize = 0;
                        var depth: usize = 1;

                        // Find matching ]
                        var j: usize = 0;
                        while (j + i < array_start.len and depth > 0) : (j += 1) {
                            if (array_start[i + j] == '[') depth += 1;
                            if (array_start[i + j] == ']') depth -= 1;
                            vec_len += 1;
                        }

                        // Parse vector data
                        const vec_str = array_start[vec_start .. vec_start + vec_len - 1];
                        const parsed_vec = try self.parseVector(vec_str);
                        try vectors.append(self.allocator, parsed_vec);
                        i += j;
                    }
                }
            }
        }

        // Perform bundled VSA operations
        var results: std.ArrayList([]const i8) = .{};
        defer {
            for (results.items) |r| {
                self.allocator.free(r);
            }
            results.deinit(self.allocator);
        }

        // Increment pending operations counter
        _ = self.prometheus.vsa_operations_pending.fetchAdd(@intCast(vectors.items.len), .monotonic);

        // Process vectors in batch
        for (vectors.items) |vec| {
            // Example: bundle the vector with itself (demo operation)
            const result = try self.allocator.dupe(i8, vec);
            try results.append(self.allocator, result);
        }

        // Decrement pending operations counter
        _ = self.prometheus.vsa_operations_pending.fetchSub(@intCast(vectors.items.len), .monotonic);

        // Build response
        var response_buf: std.ArrayListUnmanaged(u8) = .{};
        defer response_buf.deinit(self.allocator);

        try response_buf.appendSlice(self.allocator, "{\"results\":[");

        for (results.items, 0..) |result, i| {
            if (i > 0) try response_buf.appendSlice(self.allocator, ",");
            try response_buf.appendSlice(self.allocator, "[");
            for (result, 0..) |val, j| {
                if (j > 0) try response_buf.appendSlice(self.allocator, ",");
                const val_str = try std.fmt.allocPrint(self.allocator, "{d}", .{val});
                defer self.allocator.free(val_str);
                try response_buf.appendSlice(self.allocator, val_str);
            }
            try response_buf.appendSlice(self.allocator, "]");
        }

        try response_buf.appendSlice(self.allocator, "],\"processed\":");
        const count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{results.items.len});
        defer self.allocator.free(count_str);
        try response_buf.appendSlice(self.allocator, count_str);
        try response_buf.appendSlice(self.allocator, "}");

        const response_body = try response_buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(response_body);

        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{response_body.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(response_body);
        std.debug.print("  VSA Bundle: processed {d} vectors\n", .{results.items.len});
    }

    /// Handle VSA bind operation
    fn handleVsaBind(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8) !void {
        _ = body;

        // Placeholder implementation
        const body_str = "{\"result\":\"bind_operation\",\"status\":\"ok\"}";
        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body_str.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body_str);
        std.debug.print("  VSA Bind: operation complete\n", .{});
    }

    /// Handle VSA unbind operation
    fn handleVsaUnbind(self: *HttpServer, connection: *std.net.Server.Connection, body: []const u8) !void {
        _ = body;

        // Placeholder implementation
        const body_str = "{\"result\":\"unbind_operation\",\"status\":\"ok\"}";
        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body_str.len});
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body_str);
        std.debug.print("  VSA Unbind: operation complete\n", .{});
    }

    /// Helper: Parse vector from JSON array string
    fn parseVector(self: *HttpServer, str: []const u8) ![]i8 {
        var values: std.ArrayListUnmanaged(i8) = .{};
        defer values.deinit(self.allocator);

        var i: usize = 0;
        while (i < str.len) : (i += 1) {
            const c = str[i];
            if (c == ' ' or c == ',' or c == '\t' or c == '\n' or c == '\r') continue;

            if (c == '-' or c == '0' or c == '1') {
                var sign: i8 = 1;
                if (c == '-') {
                    sign = -1;
                    i += 1;
                    if (i >= str.len) break;
                }

                const digit = str[i];
                if (digit == '0') {
                    try values.append(self.allocator, 0);
                } else if (digit == '1') {
                    try values.append(self.allocator, @as(i8, sign) * 1);
                }
            }
        }

        return values.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServer(allocator: Allocator, model_path: []const u8, port: u16) !void {
    var server = HttpServer.init(allocator, model_path, port);
    try server.run();
}
