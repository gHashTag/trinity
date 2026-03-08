// ═══════════════════════════════════════════════════════════════════════════════
// TRI SERVE COMMAND — Unified API Server Launcher
// Launches REST + GraphQL + gRPC + WebSocket simultaneously
// φ² + 1/φ² = 3 = TRINITY | Golden Chain #102
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const api = @import("api");
const chem = @import("sacred");
const sacred_formula = @import("math/sacred_formula.zig");

pub const YELLOW = "\x1b[38;2;255;215;0m";
pub const GREEN = "\x1b[38;2;0;229;153m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const ServeConfig = struct {
    port: u16 = 8080,
    grpc_port: u16 = 9335,
    protocols: Protocols = .all,
    enable_openapi: bool = true,
    enable_playground: bool = true,
    enable_cors: bool = true,
    max_connections: u32 = 1000,
    log_level: LogLevel = .info,
    daemon: bool = false,

    pub const Protocols = enum {
        all,
        rest_only,
        graphql_only,
        grpc_only,
        ws_only,
        rest_graphql,
        custom,
    };

    pub const LogLevel = enum {
        debug,
        info,
        warn,
        err,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// GRACEFUL SHUTDOWN
// ═══════════════════════════════════════════════════════════════════════════════

var g_running = std.atomic.Value(bool).init(true);

fn signalHandler(_: c_int) callconv(.c) void {
    g_running.store(false, .release);
}

fn installSignalHandlers() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = signalHandler },
        .mask = std.mem.zeroes(std.posix.sigset_t),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.TERM, &act, null);
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVER STATUS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ServerStatus = struct {
    running: bool,
    uptime: i64,
    connections: u32,
    protocols_active: std.ArrayList([]const u8),
    start_time: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ServerStatus {
        const protocols = std.ArrayList([]const u8).initCapacity(allocator, 4) catch return ServerStatus{
            .running = false,
            .uptime = 0,
            .connections = 0,
            .protocols_active = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .start_time = 0,
            .allocator = allocator,
        };
        return ServerStatus{
            .running = false,
            .uptime = 0,
            .connections = 0,
            .protocols_active = protocols,
            .start_time = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ServerStatus) void {
        self.protocols_active.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED API SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedApiServer = struct {
    allocator: std.mem.Allocator,
    config: ServeConfig,
    status: ServerStatus,
    registry: api.CommandRegistry,
    server_socket: ?std.posix.socket_t,

    pub fn init(allocator: std.mem.Allocator, config: ServeConfig) !UnifiedApiServer {
        const server = UnifiedApiServer{
            .allocator = allocator,
            .config = config,
            .status = ServerStatus.init(allocator),
            .registry = api.CommandRegistry.init(allocator),
            .server_socket = null,
        };
        return server;
    }

    pub fn deinit(self: *UnifiedApiServer) void {
        self.stop();
        self.status.deinit();
        self.registry.deinit();
    }

    pub fn start(self: *UnifiedApiServer) !void {
        self.status.running = true;
        self.status.start_time = std.time.milliTimestamp();

        // Show banner
        try self.printBanner();

        // Start actual HTTP server
        try self.startHttpServer();

        // Start enabled protocols (for display)
        try self.startProtocols();

        // Show status
        try self.printStatus();

        // Install signal handlers for graceful shutdown
        installSignalHandlers();

        // Run event loop (always, even in daemon mode)
        if (!self.config.daemon) {
            std.debug.print("\n{s}Press Ctrl+C to stop{s}\n", .{YELLOW, RESET});
        }
        try self.runEventLoop();
    }

    fn startHttpServer(self: *UnifiedApiServer) !void {
        const server_socket = try std.posix.socket(
            std.posix.AF.INET,
            std.posix.SOCK.STREAM,
            std.posix.IPPROTO.TCP
        );

        // Set SO_REUSEADDR
        const reuse_value: u32 = 1;
        _ = std.posix.setsockopt(
            server_socket,
            std.posix.SOL.SOCKET,
            std.posix.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, @intCast(reuse_value)))
        ) catch |err| {
            std.posix.close(server_socket);
            return err;
        };

        const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.config.port);
        try std.posix.bind(server_socket, &addr.any, addr.getOsSockLen());
        try std.posix.listen(server_socket, 128);

        // Set server socket to non-blocking for accept loop
        const srv_flags = std.posix.fcntl(server_socket, std.posix.F.GETFL, 0) catch 0;
        const nonblock: usize = @as(u32, @bitCast(std.posix.O{ .NONBLOCK = true }));
        _ = std.posix.fcntl(server_socket, std.posix.F.SETFL, srv_flags | nonblock) catch {};

        self.server_socket = server_socket;
        std.debug.print("  {s}✓{s} HTTP server listening on port {d}\n", .{GREEN, RESET, self.config.port});
    }

    fn runEventLoop(self: *UnifiedApiServer) !void {
        const socket = self.server_socket orelse return error.ServerNotStarted;

        while (self.status.running and g_running.load(.acquire)) {
            // Accept connection
            var client_addr: std.net.Address = undefined;
            var client_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);
            const client_socket = std.posix.accept(socket, &client_addr.any, &client_addr_len, 0) catch |err| {
                if (err == error.WouldBlock) {
                    std.posix.nanosleep(0, 10_000_000); // 10ms
                    continue;
                }
                return err;
            };

            // Set client socket to non-blocking for read with timeout
            const flags = std.posix.fcntl(client_socket, std.posix.F.GETFL, 0) catch 0;
            const nonblock_flag: usize = @as(u32, @bitCast(std.posix.O{ .NONBLOCK = true }));
            _ = std.posix.fcntl(client_socket, std.posix.F.SETFL, flags | nonblock_flag) catch {};

            // Read request in loop until we get full headers
            var buffer: [4096]u8 = undefined;
            var total_read: usize = 0;
            var headers_complete = false;

            while (total_read < buffer.len and !headers_complete) {
                const bytes_read = std.posix.read(client_socket, buffer[total_read..]) catch |err| {
                    if (err == error.WouldBlock) {
                        // No more data available yet - retry
                        if (total_read > 0) break; // Got some data, process it
                        continue;
                    }
                    break;
                };

                if (bytes_read == 0) break; // Connection closed
                total_read += bytes_read;

                // Check for end of headers (\r\n\r\n)
                if (total_read >= 4) {
                    if (std.mem.indexOf(u8, buffer[0..total_read], "\r\n\r\n")) |end_idx| {
                        headers_complete = true;
                        _ = end_idx;
                    }
                }
            }

            if (total_read > 0 and headers_complete) {
                const request = buffer[0..total_read];

                // Handle OPTIONS preflight request for CORS
                if (std.mem.indexOf(u8, request, "OPTIONS /graphql") != null) {
                    const options_response = try self.corsOptionsResponse();
                    defer self.allocator.free(options_response);
                    _ = std.posix.write(client_socket, options_response) catch {};
                }
                // Check for POST request (GraphQL query)
                else if (std.mem.indexOf(u8, request, "POST /graphql") != null) {
                    // Parse GraphQL query from JSON body
                    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse continue;
                    const body = request[body_start + 4 ..];

                    // Handle empty body (health check from playground)
                    if (body.len == 0 or std.mem.eql(u8, body, "")) {
                        const health_response = try self.healthCheckResponse();
                        defer self.allocator.free(health_response);
                        _ = std.posix.write(client_socket, health_response) catch {};
                        continue;
                    }

                    // Debug: log what we received
                    std.debug.print("DEBUG: Received GraphQL POST, body: {s}\n", .{body});

                    // Simple GraphQL parser for {"query":"..."}
                    const response = try self.handleGraphQLQuery(body);
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                }
                // Parse HTTP GET requests
                else if (std.mem.indexOf(u8, request, "GET /health") != null) {
                    // Health check response (matches both /health and /api/health)
                    const response = try self.healthCheckResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/openapi.json") != null) {
                    // OpenAPI spec response
                    const response = try self.openApiResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/commands") != null) {
                    const response = try self.commandsResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/version") != null) {
                    const response = try self.versionResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/status") != null) {
                    const response = try self.statusResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /graphql") != null) {
                    // GraphQL playground
                    const response = try self.graphqlPlaygroundResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                }
                // Chemistry API endpoints (v10.0)
                else if (std.mem.indexOf(u8, request, "GET /api/chem/mass?") != null) {
                    const response = self.chemMassResponse(request) catch try self.errorResponse("Chemistry mass error");
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/chem/sacred?") != null) {
                    const response = self.chemSacredResponse(request) catch try self.errorResponse("Chemistry sacred error");
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/chem/element?") != null) {
                    const response = self.chemElementResponse(request) catch try self.errorResponse("Chemistry element error");
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else if (std.mem.indexOf(u8, request, "GET /api/chem/balance?") != null) {
                    const response = self.chemBalanceResponse(request) catch try self.errorResponse("Chemistry balance error");
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                } else {
                    // 404 response
                    const response = try self.notFoundResponse();
                    defer self.allocator.free(response);
                    _ = std.posix.write(client_socket, response) catch {};
                }
            }

            std.posix.close(client_socket);
        }
    }

    fn healthCheckResponse(self: *const UnifiedApiServer) ![]const u8 {
        const uptime = std.time.milliTimestamp() - self.status.start_time;
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{{"healthy":true,"uptime":{d},"connections":{d},"commands":{d}}}
        , .{uptime, self.status.connections, self.registry.count()});
    }

    fn commandsResponse(self: *const UnifiedApiServer) ![]const u8 {
        var buf = std.ArrayList(u8).initCapacity(self.allocator, 4096) catch return error.OutOfMemory;
        try buf.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{"commands":[
        );

        var iter = self.registry.commands.iterator();
        var first = true;
        while (iter.next()) |entry| {
            if (!first) try buf.appendSlice(self.allocator, ",");
            first = false;
            const cmd = entry.value_ptr.*;
            const item = try std.fmt.allocPrint(self.allocator,
                \\{{"name":"{s}","category":"{s}","description":"{s}"}}
            , .{cmd.name, @tagName(cmd.category), cmd.description});
            defer self.allocator.free(item);
            try buf.appendSlice(self.allocator, item);
        }

        try buf.appendSlice(self.allocator, "]}");
        return buf.toOwnedSlice(self.allocator);
    }

    fn versionResponse(self: *const UnifiedApiServer) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{{"version":"1.0.0","name":"TRINITY Unified API","protocols":["REST","GraphQL"],"planned":["gRPC","WebSocket"],"phi":"1.618033988749895"}}
        , .{});
    }

    fn statusResponse(self: *const UnifiedApiServer) ![]const u8 {
        const uptime = std.time.milliTimestamp() - self.status.start_time;
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{{"running":true,"uptime_ms":{d},"connections":{d},"commands_registered":{d},"protocols_active":["REST","GraphQL"],"protocols_planned":["gRPC","WebSocket"],"port":{d}}}
        , .{uptime, self.status.connections, self.registry.count(), self.config.port});
    }

    fn openApiResponse(self: *const UnifiedApiServer) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{{"openapi":"3.0.0","info":{{"title":"TRINITY Unified API","version":"1.0.0"}},"paths":{{}}}}
        , .{});
    }

    fn graphqlPlaygroundResponse(self: *const UnifiedApiServer) ![]const u8 {
        // Self-contained GraphQL Playground - NO external dependencies
        // Works 100% because everything is inline - no CDN, no CORS issues
        var buffer = std.ArrayList(u8).initCapacity(self.allocator, 16384) catch return error.OutOfMemory;
        try buffer.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: text/html; charset=utf-8
            \\Access-Control-Allow-Origin: *
            \\
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\ <meta charset="utf-8"/>
            \\ <meta name="viewport" content="width=device-width, initial-scale=1"/>
            \\ <title>TRINITY GraphQL Playground</title>
            \\ <style>
            \\ * { box-sizing: border-box; margin: 0; padding: 0; }
            \\ body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0d1117; color: #c9d1d9; height: 100vh; display: flex; flex-direction: column; }
            \\ .header { background: #161b22; border-bottom: 1px solid #30363d; padding: 12px 20px; display: flex; align-items: center; justify-content: space-between; }
            \\ .header h1 { font-size: 18px; color: #ffd700; }
            \\ .header .url { font-size: 12px; color: #8b949e; }
            \\ .main { flex: 1; display: flex; overflow: hidden; }
            \\ .panel { flex: 1; display: flex; flex-direction: column; border-right: 1px solid #30363d; }
            \\ .panel:last-child { border-right: none; }
            \\ .panel-header { background: #161b22; padding: 8px 16px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; color: #8b949e; border-bottom: 1px solid #30363d; display: flex; align-items: center; justify-content: space-between; }
            \\ .panel-header button { background: #238636; color: white; border: none; padding: 4px 12px; border-radius: 6px; font-size: 11px; cursor: pointer; }
            \\ .panel-header button:hover { background: #2ea043; }
            \\ .editor { flex: 1; overflow: auto; font-family: "SF Mono", Monaco, "Cascadia Code", monospace; font-size: 13px; line-height: 1.6; padding: 16px; }
            \\ textarea { width: 100%; height: 100%; background: transparent; border: none; color: #c9d1d9; font-family: inherit; font-size: inherit; line-height: inherit; resize: none; outline: none; }
            \\ .result { background: #0d1117; }
            \\ .result pre { white-space: pre-wrap; word-wrap: break-word; }
            \\ .error { color: #f85149; }
            \\ .success { color: #3fb950; }
            \\ .loading { color: #8b949e; font-style: italic; }
            \\ .docs { background: #161b22; border-left: 1px solid #30363d; width: 300px; overflow-y: auto; font-size: 12px; }
            \\ .docs h3 { padding: 12px 16px; color: #ffd700; font-size: 12px; border-bottom: 1px solid #30363d; }
            \\ .docs-section { padding: 12px 16px; border-bottom: 1px solid #21262d; }
            \\ .docs-section h4 { color: #58a6ff; margin-bottom: 8px; font-size: 11px; }
            \\ .docs-section p { color: #8b949e; margin: 4px 0; font-size: 11px; }
            \\ .code { background: #0d1117; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 11px; }
            \\ .hidden { display: none; }
            \\ .status { position: fixed; bottom: 20px; right: 20px; padding: 10px 16px; border-radius: 8px; font-size: 13px; font-weight: 500; opacity: 0; transition: opacity 0.3s; }
            \\ .status.show { opacity: 1; }
            \\ .status.error { background: #f85149; color: white; }
            \\ .status.success { background: #3fb950; color: white; }
            \\ </style>
            \\</head>
            \\<body>
            \\ <div class="header">
            \\ <h1>⚡ TRINITY GraphQL Playground</h1>
            \\ <span class="url">φ² + 1/φ² = 3</span>
            \\ </div>
            \\ <div class="main">
            \\ <div class="panel">
            \\ <div class="panel-header">
            \\ <span>Query</span>
            \\ <button onclick="runQuery()">▶ Run (Ctrl+Enter)</button>
            \\ </div>
            \\ <div class="editor">
            \\ <textarea id="query" spellcheck="false"># TRINITY GraphQL API — Press Ctrl+Enter to execute
            \\
            \\{
            \\ commands {
            \\ name
            \\ category
            \\ }
            \\}
            \\
            \\# Available queries:
            \\# { stats { comms_count protocols } }
            \\# { status { healthy uptime } }
            \\# { sacred { phi trinity pi } }
            \\# { docs { title url } }
            \\# { version { build } }</textarea>
            \\ </div>
            \\ </div>
            \\ <div class="panel">
            \\ <div class="panel-header">
            \\ <span>Result</span>
            \\ <button onclick="copyResult()">📋 Copy</button>
            \\ </div>
            \\ <div class="editor result" id="result"><span class="loading">Run a query to see results...</span></div>
            \\ </div>
            \\ <div class="docs" id="docs">
            \\ <h3>📚 Schema Docs</h3>
            \\ <div class="docs-section">
            \\ <h4>commands</h4>
            \\ <p>List all TRI commands</p>
            \\ <p>Returns: <span class="code">[Command]</span></p>
            \\ </div>
            \\ <div class="docs-section">
            \\ <h4>status</h4>
            \\ <p>Server health status</p>
            \\ <p>Returns: <span class="code">Status</span></p>
            \\ </div>
            \\ <div class="docs-section">
            \\ <h4>stats</h4>
            \\ <p>System statistics</p>
            \\ <p>Returns: <span class="code">SystemStats</span></p>
            \\ </div>
            \\ <div class="docs-section">
            \\ <h4>sacred</h4>
            \\ <p>Sacred constants (φ, π, e)</p>
            \\ <p>Returns: <span class="code">SacredConstants</span></p>
            \\ </div>
            \\ <div class="docs-section">
            \\ <h4>docs</h4>
            \\ <p>Documentation links</p>
            \\ <p>Returns: <span class="code">[DocLink]</span></p>
            \\ </div>
            \\ <div class="docs-section">
            \\ <h4>version</h4>
            \\ <p>Version information</p>
            \\ <p>Returns: <span class="code">VersionInfo</span></p>
            \\ </div>
            \\ </div>
            \\ </div>
            \\ </div>
            \\ <div class="status" id="status"></div>
            \\ <script>
            \\ const queryEl = document.getElementById('query');
            \\ const resultEl = document.getElementById('result');
            \\ const statusEl = document.getElementById('status');
            \\
            \\ // Ctrl+Enter to run
            \\ queryEl.addEventListener('keydown', (e) => {
            \\ if (e.ctrlKey && e.key === 'Enter') runQuery();
            \\ });
            \\
            \\ async function runQuery() {
            \\ const query = queryEl.value.trim();
            \\ if (!query) return showError('Enter a query first');
            \\
            \\ showStatus('Running...', 'info');
            \\
            \\ try {
            \\ const response = await fetch('/graphql', {
            \\ method: 'POST',
            \\ headers: { 'Content-Type': 'application/json' },
            \\ body: JSON.stringify({ query })
            \\ });
            \\
            \\ const text = await response.text();
            \\ let data;
            \\ try {
            \\ data = JSON.parse(text);
            \\ } catch {
            \\ // Server returned non-JSON (might be our HTTP response with headers)
            \\ const jsonMatch = text.match(/\{[\s\S]*\}$/);
            \\ if (jsonMatch) {
            \\ data = JSON.parse(jsonMatch[0]);
            \\ } else {
            \\ throw new Error('Invalid response from server');
            \\ }
            \\ }
            \\
            \\ if (data.errors) {
            \\ showError(data.errors[0].message);
            \\ } else if (data.data) {
            \\ showResult(JSON.stringify(data.data, null, 2));
            \\ showStatus('Success!', 'success');
            \\ }
            \\ } catch (err) {
            \\ showError(err.message);
            \\ }
            \\ }
            \\
            \\ function showResult(html) {
            \\ resultEl.innerHTML = '<pre>' + escapeHtml(html) + '</pre>';
            \\ }
            \\
            \\ function showError(msg) {
            \\ resultEl.innerHTML = '<span class="error">Error: ' + escapeHtml(msg) + '</span>';
            \\ showStatus('Error', 'error');
            \\ }
            \\
            \\ function showStatus(msg, type) {
            \\ statusEl.textContent = msg;
            \\ statusEl.className = 'status show ' + type;
            \\ setTimeout(() => statusEl.classList.remove('show'), 3000);
            \\ }
            \\
            \\ function escapeHtml(text) {
            \\ const div = document.createElement('div');
            \\ div.textContent = text;
            \\ return div.innerHTML;
            \\ }
            \\
            \\ function copyResult() {
            \\ const text = resultEl.textContent;
            \\ navigator.clipboard.writeText(text);
            \\ showStatus('Copied!', 'success');
            \\ }
            \\
            \\ // Auto-focus query on load
            \\ queryEl.focus();
            \\ </script>
            \\</body>
            \\</html>
        );
        return buffer.toOwnedSlice(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CHEMISTRY API ENDPOINTS (v10.0)
    // ═══════════════════════════════════════════════════════════════════════

    /// Extract query parameter value from raw HTTP request
    fn extractParam(request: []const u8, prefix: []const u8) ?[]const u8 {
        const idx = std.mem.indexOf(u8, request, prefix) orelse return null;
        const val_start = idx + prefix.len;
        if (val_start >= request.len) return null;
        // Find end: space, &, or \r
        var end = val_start;
        while (end < request.len) : (end += 1) {
            if (request[end] == ' ' or request[end] == '&' or request[end] == '\r' or request[end] == '\n') break;
        }
        if (end == val_start) return null;
        return request[val_start..end];
    }

    /// Minimal URL decode: %2B->+, %28->(, %29->), %3E->>, %3D->=
    fn urlDecode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).initCapacity(allocator, input.len) catch return error.OutOfMemory;
        var i: usize = 0;
        while (i < input.len) {
            if (input[i] == '%' and i + 2 < input.len) {
                const hi = hexVal(input[i + 1]);
                const lo = hexVal(input[i + 2]);
                if (hi != null and lo != null) {
                    try buf.append(allocator, (hi.? << 4) | lo.?);
                    i += 3;
                    continue;
                }
            }
            if (input[i] == '+') {
                try buf.append(allocator, ' ');
            } else {
                try buf.append(allocator, input[i]);
            }
            i += 1;
        }
        return buf.toOwnedSlice(allocator);
    }

    fn hexVal(c: u8) ?u8 {
        if (c >= '0' and c <= '9') return c - '0';
        if (c >= 'A' and c <= 'F') return c - 'A' + 10;
        if (c >= 'a' and c <= 'f') return c - 'a' + 10;
        return null;
    }

    fn errorResponse(self: *const UnifiedApiServer, msg: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 400 Bad Request
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{{"error":"{s}"}}
        , .{msg});
    }

    /// Append a sacred formula fit as JSON object
    fn appendFitJson(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, fit: sacred_formula.SacredFormulaFit) !void {
        const item = try std.fmt.allocPrint(allocator,
            \\{{"n":{d},"k":{d},"m":{d},"p":{d},"q":{d},"computed":{d:.6},"error_pct":{d:.4}}}
        , .{ fit.n, fit.k, fit.m, fit.p, fit.q, fit.computed, fit.error_pct });
        defer allocator.free(item);
        try buf.appendSlice(allocator, item);
    }

    /// GET /api/chem/mass?formula=H2O
    fn chemMassResponse(self: *UnifiedApiServer, request: []const u8) ![]const u8 {
        const raw_formula = extractParam(request, "formula=") orelse return self.errorResponse("Missing formula parameter");
        const formula = try urlDecode(self.allocator, raw_formula);
        defer self.allocator.free(formula);

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        const mass = chem.molarMass(alloc, formula) catch return self.errorResponse("Cannot parse formula");
        const composition = chem.parseFormula(alloc, formula) catch return self.errorResponse("Cannot parse formula");

        var buf = std.ArrayList(u8).initCapacity(self.allocator, 2048) catch return error.OutOfMemory;
        try buf.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{"formula":"
        );
        try buf.appendSlice(self.allocator, formula);
        const mass_str = try std.fmt.allocPrint(self.allocator, "\",\"molar_mass\":{d:.6},\"breakdown\":[", .{mass});
        defer self.allocator.free(mass_str);
        try buf.appendSlice(self.allocator, mass_str);

        var iter = composition.iterator();
        var first = true;
        while (iter.next()) |entry| {
            const sym = entry.key_ptr.*;
            const count = entry.value_ptr.*;
            const el = chem.getElement(sym) orelse continue;
            if (!first) try buf.appendSlice(self.allocator, ",");
            first = false;
            const total = el.mass * @as(f64, @floatFromInt(count));
            const item = try std.fmt.allocPrint(self.allocator,
                \\{{"symbol":"{s}","count":{d},"element_mass":{d:.4},"total":{d:.4}}}
            , .{ sym, count, el.mass, total });
            defer self.allocator.free(item);
            try buf.appendSlice(self.allocator, item);
        }

        try buf.appendSlice(self.allocator, "],\"source\":\"live\"}");
        return buf.toOwnedSlice(self.allocator);
    }

    /// GET /api/chem/sacred?formula=H2O
    fn chemSacredResponse(self: *UnifiedApiServer, request: []const u8) ![]const u8 {
        const raw_formula = extractParam(request, "formula=") orelse return self.errorResponse("Missing formula parameter");
        const formula = try urlDecode(self.allocator, raw_formula);
        defer self.allocator.free(formula);

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        const mass = chem.molarMass(alloc, formula) catch return self.errorResponse("Cannot parse formula");
        const fit = sacred_formula.fitSacredFormula(mass);
        const composition = chem.parseFormula(alloc, formula) catch return self.errorResponse("Cannot parse formula");

        var buf = std.ArrayList(u8).initCapacity(self.allocator, 4096) catch return error.OutOfMemory;
        try buf.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{"formula":"
        );
        try buf.appendSlice(self.allocator, formula);
        const hdr = try std.fmt.allocPrint(self.allocator, "\",\"molar_mass\":{d:.6},\"sacred_fit\":", .{mass});
        defer self.allocator.free(hdr);
        try buf.appendSlice(self.allocator, hdr);
        try appendFitJson(&buf, self.allocator, fit);

        // Elements array
        try buf.appendSlice(self.allocator, ",\"elements\":[");
        var iter = composition.iterator();
        var first = true;
        var total_atoms: u32 = 0;
        var total_electrons: u32 = 0;
        var total_en: f64 = 0;
        var en_count: f64 = 0;
        while (iter.next()) |entry| {
            const sym = entry.key_ptr.*;
            const count = entry.value_ptr.*;
            const el = chem.getElement(sym) orelse continue;
            if (!first) try buf.appendSlice(self.allocator, ",");
            first = false;

            total_atoms += count;
            total_electrons += el.number * count;

            const contrib = el.mass * @as(f64, @floatFromInt(count));
            const pct = (contrib / mass) * 100.0;
            const mass_fit = sacred_formula.fitSacredFormula(el.mass);

            const el_hdr = try std.fmt.allocPrint(self.allocator,
                \\{{"symbol":"{s}","count":{d},"mass":{d:.4},"mass_contrib":{d:.4},"pct":{d:.2},"mass_fit":
            , .{ sym, count, el.mass, contrib, pct });
            defer self.allocator.free(el_hdr);
            try buf.appendSlice(self.allocator, el_hdr);
            try appendFitJson(&buf, self.allocator, mass_fit);

            // Ionization energy fit
            if (el.ionization_energy) |ie| {
                const ie_fit = sacred_formula.fitSacredFormula(ie);
                const ie_str = try std.fmt.allocPrint(self.allocator, ",\"ie\":{d:.4},\"ie_fit\":", .{ie});
                defer self.allocator.free(ie_str);
                try buf.appendSlice(self.allocator, ie_str);
                try appendFitJson(&buf, self.allocator, ie_fit);
            }

            // Electronegativity
            if (el.electronegativity) |en| {
                total_en += en * @as(f64, @floatFromInt(count));
                en_count += @as(f64, @floatFromInt(count));
            }

            try buf.appendSlice(self.allocator, "}");
        }

        const footer = try std.fmt.allocPrint(self.allocator,
            \\],"total_atoms":{d},"total_electrons":{d}
        , .{ total_atoms, total_electrons });
        defer self.allocator.free(footer);
        try buf.appendSlice(self.allocator, footer);

        // Average electronegativity
        if (en_count > 0) {
            const avg_en = total_en / en_count;
            const en_fit = sacred_formula.fitSacredFormula(avg_en);
            const en_str = try std.fmt.allocPrint(self.allocator, ",\"avg_electronegativity\":{d:.4},\"en_fit\":", .{avg_en});
            defer self.allocator.free(en_str);
            try buf.appendSlice(self.allocator, en_str);
            try appendFitJson(&buf, self.allocator, en_fit);
        }

        try buf.appendSlice(self.allocator, ",\"source\":\"live\"}");
        return buf.toOwnedSlice(self.allocator);
    }

    /// GET /api/chem/element?q=Au
    fn chemElementResponse(self: *UnifiedApiServer, request: []const u8) ![]const u8 {
        const raw_q = extractParam(request, "q=") orelse return self.errorResponse("Missing q parameter");
        const query = try urlDecode(self.allocator, raw_q);
        defer self.allocator.free(query);

        const el = chem.getElement(query) orelse return self.errorResponse("Element not found");

        var buf = std.ArrayList(u8).initCapacity(self.allocator, 4096) catch return error.OutOfMemory;
        try buf.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{"element":{
        );

        // Core fields
        const core = try std.fmt.allocPrint(self.allocator,
            \\"number":{d},"symbol":"{s}","name":"{s}","mass":{d:.4},"group":{d},"period":{d}
        , .{ el.number, el.symbol, el.name, el.mass, el.group, el.period });
        defer self.allocator.free(core);
        try buf.appendSlice(self.allocator, core);

        // Optional fields
        if (el.electronegativity) |en| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"electronegativity\":{d:.2}", .{en});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"electronegativity\":null");
        }
        if (el.ionization_energy) |ie| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"ionization_energy\":{d:.4}", .{ie});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"ionization_energy\":null");
        }

        // Extended fields from full Element struct
        const block_ch: u8 = switch (el.block) { 0 => 's', 1 => 'p', 2 => 'd', 3 => 'f', else => '?' };
        const ext = try std.fmt.allocPrint(self.allocator,
            \\,"electron_config":"{s}","block":"{c}","category":"{s}","valence":{d}
        , .{ el.electron_config, block_ch, el.category, el.valence });
        defer self.allocator.free(ext);
        try buf.appendSlice(self.allocator, ext);

        if (el.electron_affinity) |ea| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"electron_affinity\":{d:.2}", .{ea});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"electron_affinity\":null");
        }
        if (el.atomic_radius) |ar| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"atomic_radius\":{d:.1}", .{ar});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"atomic_radius\":null");
        }
        if (el.melting_point) |mp| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"melting_point\":{d:.2}", .{mp});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"melting_point\":null");
        }
        if (el.boiling_point) |bp| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"boiling_point\":{d:.2}", .{bp});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"boiling_point\":null");
        }
        if (el.density) |d| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"density\":{d:.4}", .{d});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"density\":null");
        }

        const disc = try std.fmt.allocPrint(self.allocator,
            \\,"discoverer":"{s}","etymology":"{s}"
        , .{ el.discoverer, el.etymology });
        defer self.allocator.free(disc);
        try buf.appendSlice(self.allocator, disc);

        try buf.appendSlice(self.allocator, "}"); // close element

        // Sacred fits
        try buf.appendSlice(self.allocator, ",\"sacred\":{\"mass_fit\":");
        const mass_fit = sacred_formula.fitSacredFormula(el.mass);
        try appendFitJson(&buf, self.allocator, mass_fit);

        if (el.ionization_energy) |ie| {
            try buf.appendSlice(self.allocator, ",\"ie_fit\":");
            const ie_fit = sacred_formula.fitSacredFormula(ie);
            try appendFitJson(&buf, self.allocator, ie_fit);
        } else {
            try buf.appendSlice(self.allocator, ",\"ie_fit\":null");
        }
        if (el.electronegativity) |en| {
            try buf.appendSlice(self.allocator, ",\"en_fit\":");
            const en_fit = sacred_formula.fitSacredFormula(en);
            try appendFitJson(&buf, self.allocator, en_fit);
        } else {
            try buf.appendSlice(self.allocator, ",\"en_fit\":null");
        }
        try buf.appendSlice(self.allocator, "}"); // close sacred

        // Balanced ternary
        try buf.appendSlice(self.allocator, ",\"ternary\":{\"balanced_ternary\":[");
        var z = @as(i32, @intCast(el.number));
        var trits: [16]i8 = undefined;
        var trit_count: usize = 0;
        if (z == 0) {
            trits[0] = 0;
            trit_count = 1;
        } else {
            while (z > 0) {
                var rem = @mod(z, 3);
                z = @divTrunc(z, 3);
                if (rem == 2) { rem = -1; z += 1; }
                trits[trit_count] = @intCast(rem);
                trit_count += 1;
            }
        }
        // Print in reverse (MSB first)
        var ti: usize = trit_count;
        while (ti > 0) {
            ti -= 1;
            if (ti < trit_count - 1) try buf.appendSlice(self.allocator, ",");
            const ts = try std.fmt.allocPrint(self.allocator, "{d}", .{trits[ti]});
            defer self.allocator.free(ts);
            try buf.appendSlice(self.allocator, ts);
        }
        const tc_str = try std.fmt.allocPrint(self.allocator, "],\"trit_count\":{d}}}", .{trit_count});
        defer self.allocator.free(tc_str);
        try buf.appendSlice(self.allocator, tc_str);

        // Fibonacci / Lucas check
        const fib_seq = [_]u16{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181 };
        const lucas_seq = [_]u16{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322, 521, 843 };
        var fib_idx: ?usize = null;
        var lucas_idx: ?usize = null;
        for (fib_seq, 0..) |f, i| { if (f == el.number) { fib_idx = i; break; } }
        for (lucas_seq, 0..) |l, i| { if (l == el.number) { lucas_idx = i; break; } }

        try buf.appendSlice(self.allocator, ",\"sequences\":{");
        if (fib_idx) |fi| {
            const s = try std.fmt.allocPrint(self.allocator, "\"fibonacci\":true,\"fibonacci_index\":{d}", .{fi});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, "\"fibonacci\":false,\"fibonacci_index\":null");
        }
        if (lucas_idx) |li| {
            const s = try std.fmt.allocPrint(self.allocator, ",\"lucas\":true,\"lucas_index\":{d}", .{li});
            defer self.allocator.free(s);
            try buf.appendSlice(self.allocator, s);
        } else {
            try buf.appendSlice(self.allocator, ",\"lucas\":false,\"lucas_index\":null");
        }
        try buf.appendSlice(self.allocator, "}");

        // Golden angle
        const golden_angle_const: f64 = 137.50776405003785;
        const angle = @mod(@as(f64, @floatFromInt(el.number)) * golden_angle_const, 360.0);
        const sector = @as(u8, @intFromFloat(angle / 45.0)) + 1;
        const ga_str = try std.fmt.allocPrint(self.allocator, ",\"golden\":{{\"angle\":{d:.2},\"sector\":{d}}}", .{ angle, sector });
        defer self.allocator.free(ga_str);
        try buf.appendSlice(self.allocator, ga_str);

        // Coptic glyph
        const coptic_glyphs = [_][]const u8{
            "\xe2\xb2\x80", "\xe2\xb2\x82", "\xe2\xb2\x84", "\xe2\xb2\x86", "\xe2\xb2\x88", "\xe2\xb2\x8a", "\xe2\xb2\x8c", "\xe2\xb2\x8e", "\xe2\xb2\x90",
            "\xe2\xb2\x92", "\xe2\xb2\x94", "\xe2\xb2\x96", "\xe2\xb2\x98", "\xe2\xb2\x9a", "\xe2\xb2\x9c", "\xe2\xb2\x9e", "\xe2\xb2\xa0", "\xe2\xb2\xa2",
            "\xe2\xb2\xa4", "\xe2\xb2\xa6", "\xe2\xb2\xa8", "\xe2\xb2\xaa", "\xe2\xb2\xac", "\xe2\xb2\xae", "\xe2\xb2\xb0", "\xcf\xa2", "\xcf\xa4",
        };
        const glyph_values = [_]u16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 200, 300, 400, 500, 600, 700, 800, 900 };
        const gi = @mod(el.number, 27);
        const kingdom: []const u8 = if (gi < 9) "Matter" else if (gi < 18) "Energy" else "Info";
        const coptic_str = try std.fmt.allocPrint(self.allocator,
            \\,"coptic":{{"glyph":"{s}","value":{d},"kingdom":"{s}"}},"source":"live"}}
        , .{ coptic_glyphs[gi], glyph_values[gi], kingdom });
        defer self.allocator.free(coptic_str);
        try buf.appendSlice(self.allocator, coptic_str);

        return buf.toOwnedSlice(self.allocator);
    }

    /// GET /api/chem/balance?eq=H2+O2->H2O
    fn chemBalanceResponse(self: *UnifiedApiServer, request: []const u8) ![]const u8 {
        const raw_eq = extractParam(request, "eq=") orelse return self.errorResponse("Missing eq parameter");
        const equation = try urlDecode(self.allocator, raw_eq);
        defer self.allocator.free(equation);

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        // Parse equation: split on -> or =
        var reactant_str: []const u8 = "";
        var product_str: []const u8 = "";
        if (std.mem.indexOf(u8, equation, "->")) |idx| {
            reactant_str = std.mem.trim(u8, equation[0..idx], " ");
            product_str = std.mem.trim(u8, equation[idx + 2 ..], " ");
        } else if (std.mem.indexOfScalar(u8, equation, '=')) |idx| {
            reactant_str = std.mem.trim(u8, equation[0..idx], " ");
            product_str = std.mem.trim(u8, equation[idx + 1 ..], " ");
        } else {
            return self.errorResponse("Use -> or = to separate reactants and products");
        }

        // Split each side on '+'
        var reactant_formulas: std.ArrayList([]const u8) = .empty;
        var prod_formulas: std.ArrayList([]const u8) = .empty;
        var r_iter = std.mem.splitScalar(u8, reactant_str, '+');
        while (r_iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len > 0) try reactant_formulas.append(alloc, trimmed);
        }
        var p_iter = std.mem.splitScalar(u8, product_str, '+');
        while (p_iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len > 0) try prod_formulas.append(alloc, trimmed);
        }

        const n_reactants = reactant_formulas.items.len;
        const n_products = prod_formulas.items.len;
        const n_compounds = n_reactants + n_products;
        if (n_compounds < 2) return self.errorResponse("Need at least 2 compounds");

        // Parse all formulas
        var all_compositions: std.ArrayList(std.StringHashMap(u32)) = .empty;
        var all_formulas: std.ArrayList([]const u8) = .empty;
        var element_set = std.StringHashMap(void).init(alloc);

        for (reactant_formulas.items) |f| {
            const comp = chem.parseFormula(alloc, f) catch return self.errorResponse("Cannot parse formula");
            var it = comp.iterator();
            while (it.next()) |entry| try element_set.put(entry.key_ptr.*, {});
            try all_compositions.append(alloc, comp);
            try all_formulas.append(alloc, f);
        }
        for (prod_formulas.items) |f| {
            const comp = chem.parseFormula(alloc, f) catch return self.errorResponse("Cannot parse formula");
            var it = comp.iterator();
            while (it.next()) |entry| try element_set.put(entry.key_ptr.*, {});
            try all_compositions.append(alloc, comp);
            try all_formulas.append(alloc, f);
        }

        var elements: std.ArrayList([]const u8) = .empty;
        var el_iter = element_set.iterator();
        while (el_iter.next()) |entry| try elements.append(alloc, entry.key_ptr.*);
        const n_elements = elements.items.len;
        if (n_elements == 0) return self.errorResponse("No elements found");

        // Build composition matrix
        const matrix = try alloc.alloc([]f64, n_elements);
        for (matrix, 0..) |*row, i| {
            row.* = try alloc.alloc(f64, n_compounds);
            for (row.*, 0..) |*val, j| {
                const comp = all_compositions.items[j];
                const count = comp.get(elements.items[i]) orelse 0;
                const sign: f64 = if (j < n_reactants) 1.0 else -1.0;
                val.* = sign * @as(f64, @floatFromInt(count));
            }
        }

        // Gaussian elimination with partial pivoting
        var pivot_col: usize = 0;
        var pivot_row: usize = 0;
        while (pivot_row < n_elements and pivot_col < n_compounds) {
            var max_val: f64 = 0;
            var max_row: usize = pivot_row;
            for (pivot_row..n_elements) |i| {
                const abs_val = @abs(matrix[i][pivot_col]);
                if (abs_val > max_val) { max_val = abs_val; max_row = i; }
            }
            if (max_val < 1e-10) { pivot_col += 1; continue; }
            if (max_row != pivot_row) {
                const tmp = matrix[pivot_row];
                matrix[pivot_row] = matrix[max_row];
                matrix[max_row] = tmp;
            }
            const piv = matrix[pivot_row][pivot_col];
            for (0..n_compounds) |j| matrix[pivot_row][j] /= piv;
            for (0..n_elements) |i| {
                if (i == pivot_row) continue;
                const factor = matrix[i][pivot_col];
                if (@abs(factor) < 1e-10) continue;
                for (0..n_compounds) |j| matrix[i][j] -= factor * matrix[pivot_row][j];
            }
            pivot_row += 1;
            pivot_col += 1;
        }

        // Back-substitute
        const coeffs = try alloc.alloc(f64, n_compounds);
        coeffs[n_compounds - 1] = 1.0;
        var row_idx: usize = n_elements;
        while (row_idx > 0) {
            row_idx -= 1;
            var pcol: ?usize = null;
            for (0..n_compounds) |j| {
                if (@abs(matrix[row_idx][j] - 1.0) < 1e-10) { pcol = j; break; }
            }
            if (pcol) |pc| {
                var val: f64 = 0;
                for (pc + 1..n_compounds) |j| val += matrix[row_idx][j] * coeffs[j];
                coeffs[pc] = -val;
            }
        }

        // Make all positive
        for (coeffs) |*c| if (c.* < 0) {
            for (coeffs) |*dd| dd.* = -dd.*;
            break;
        };

        // Scale to integers
        var best_mult: f64 = 1.0;
        for (1..101) |m| {
            const mf = @as(f64, @floatFromInt(m));
            var all_int = true;
            for (coeffs) |c| {
                const scaled = c * mf;
                if (@abs(scaled - @round(scaled)) > 0.01) { all_int = false; break; }
            }
            if (all_int) { best_mult = mf; break; }
        }

        const int_coeffs = try alloc.alloc(u32, n_compounds);
        for (coeffs, 0..) |c, i| {
            const rounded = @round(c * best_mult);
            int_coeffs[i] = @intFromFloat(@max(rounded, 1.0));
        }

        // Build JSON response
        var buf = std.ArrayList(u8).initCapacity(self.allocator, 2048) catch return error.OutOfMemory;
        try buf.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: application/json
            \\Access-Control-Allow-Origin: *
            \\
            \\{"input":"
        );
        try buf.appendSlice(self.allocator, equation);
        try buf.appendSlice(self.allocator, "\",\"balanced\":\"");

        // Build balanced equation string
        for (0..n_compounds) |i| {
            if (i == n_reactants) {
                try buf.appendSlice(self.allocator, " -> ");
            } else if (i > 0) {
                try buf.appendSlice(self.allocator, " + ");
            }
            if (int_coeffs[i] != 1) {
                const cs = try std.fmt.allocPrint(alloc, "{d} ", .{int_coeffs[i]});
                try buf.appendSlice(self.allocator, cs);
            }
            try buf.appendSlice(self.allocator, all_formulas.items[i]);
        }

        // Coefficients
        try buf.appendSlice(self.allocator, "\",\"coefficients\":{\"reactants\":[");
        for (0..n_reactants) |i| {
            if (i > 0) try buf.appendSlice(self.allocator, ",");
            const cs = try std.fmt.allocPrint(alloc, "{{\"formula\":\"{s}\",\"coefficient\":{d}}}", .{ all_formulas.items[i], int_coeffs[i] });
            try buf.appendSlice(self.allocator, cs);
        }
        try buf.appendSlice(self.allocator, "],\"products\":[");
        for (n_reactants..n_compounds) |i| {
            if (i > n_reactants) try buf.appendSlice(self.allocator, ",");
            const cs = try std.fmt.allocPrint(alloc, "{{\"formula\":\"{s}\",\"coefficient\":{d}}}", .{ all_formulas.items[i], int_coeffs[i] });
            try buf.appendSlice(self.allocator, cs);
        }

        // Verification
        try buf.appendSlice(self.allocator, "]},\"verification\":{\"elements\":[");
        var balanced = true;
        for (elements.items, 0..) |elem, ei| {
            if (ei > 0) try buf.appendSlice(self.allocator, ",");
            var left: i64 = 0;
            var right: i64 = 0;
            for (0..n_compounds) |j| {
                const comp = all_compositions.items[j];
                const count: i64 = @intCast(comp.get(elem) orelse 0);
                const coeff: i64 = @intCast(int_coeffs[j]);
                if (j < n_reactants) { left += count * coeff; } else { right += count * coeff; }
            }
            const ok = left == right;
            if (!ok) balanced = false;
            const vs = try std.fmt.allocPrint(alloc, "{{\"element\":\"{s}\",\"left\":{d},\"right\":{d},\"ok\":{s}}}", .{ elem, left, right, if (ok) "true" else "false" });
            try buf.appendSlice(self.allocator, vs);
        }

        const tail = try std.fmt.allocPrint(alloc, "],\"balanced\":{s}}},\"source\":\"live\"}}", .{if (balanced) "true" else "false"});
        try buf.appendSlice(self.allocator, tail);

        return buf.toOwnedSlice(self.allocator);
    }

    fn notFoundResponse(self: *const UnifiedApiServer) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 404 Not Found
            \\Content-Type: application/json
            \\
            \\{{"error":"Not Found"}}
        , .{});
    }

    fn corsOptionsResponse(self: *const UnifiedApiServer) ![]const u8 {
        var buffer = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
        try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\nAccess-Control-Allow-Headers: Content-Type, Authorization\nAccess-Control-Max-Age: 86400\nContent-Length: 0\n\n");
        return buffer.toOwnedSlice(self.allocator);
    }

    const GraphQLRequest = struct {
        query: []const u8 = "",
        variables: ?[]const u8 = null,
        operationName: ?[]const u8 = null,
    };

    fn extractGraphQLQuery(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
        const parsed = std.json.parseFromSlice(GraphQLRequest, allocator, body, .{
            .allocate = .alloc_if_needed,
        }) catch return error.MalformedJSON;
        defer parsed.deinit();
        return allocator.dupe(u8, parsed.value.query);
    }

    // Convert CommandCategory enum to string
    fn categoryToString(cat: api.CommandCategory) []const u8 {
        return switch (cat) {
            .CORE => "CORE",
            .VIBEE => "VIBEE",
            .GIT => "GIT",
            .PIPELINE => "PIPELINE",
            .MULTI_CLUSTER => "MULTI_CLUSTER",
            .VERIFY => "VERIFY",
            .SPEC => "SPEC",
            .TVC => "TVC",
            .DEMOS => "DEMOS",
            .MATH => "MATH",
            .INTELLIGENCE => "INTELLIGENCE",
            .DOCTOR => "DOCTOR",
            .IDENTITY => "IDENTITY",
            .ANALYZE => "ANALYZE",
            .ADVANCED => "ADVANCED",
            .INFO => "INFO",
        };
    }

    // Execute GraphQL query against command registry
    fn handleGraphQLQuery(self: *const UnifiedApiServer, body: []const u8) ![]const u8 {
        // Parse query from JSON body
        const query = extractGraphQLQuery(self.allocator, body) catch |err| {
            // Return error response - build manually
            std.debug.print("DEBUG: Failed to parse query: {s}\n", .{@errorName(err)});
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 400 Bad Request\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"errors\":[{\"message\":\"Failed to parse query: ");
            try buffer.appendSlice(self.allocator, @errorName(err));
            try buffer.appendSlice(self.allocator, "\"}]}");
            return buffer.toOwnedSlice(self.allocator);
        };
        defer self.allocator.free(query);

        std.debug.print("DEBUG: Extracted query: {s}\n", .{query});

        // Normalize query: remove all whitespace including newlines
        var normalized = std.ArrayList(u8).initCapacity(self.allocator, query.len) catch return error.OutOfMemory;
        defer normalized.deinit(self.allocator);

        for (query) |c| {
            if (!std.ascii.isWhitespace(c)) {
                try normalized.append(self.allocator, c);
            }
        }
        const normalized_query = normalized.items;

        std.debug.print("DEBUG: Normalized query: {s}\n", .{normalized_query});

        // Handle Introspection queries (GraphQL Playground needs this)
        if (std.mem.indexOf(u8, normalized_query, "__schema") != null or
            std.mem.indexOf(u8, normalized_query, "__type") != null or
            std.mem.indexOf(u8, normalized_query, "IntrospectionQuery") != null) {
            std.debug.print("DEBUG: Introspection query - returning complete schema\n", .{});
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 16384) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");

            // Build full GraphQL-compliant introspection schema
            try buffer.appendSlice(self.allocator, "{\"data\":{\"__schema\":{");
            try buffer.appendSlice(self.allocator, "\"queryType\":{\"name\":\"Query\",\"kind\":\"OBJECT\"},");
            try buffer.appendSlice(self.allocator, "\"mutationType\":null,");
            try buffer.appendSlice(self.allocator, "\"subscriptionType\":null,");
            try buffer.appendSlice(self.allocator, "\"types\":[");

            // Query type with full field metadata
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"Query\",\"description\":null,\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"commands\",\"description\":\"List all commands\",\"args\":[],\"type\":{\"kind\":\"LIST\",\"ofType\":{\"kind\":\"OBJECT\",\"name\":\"Command\",\"ofType\":null}},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"status\",\"description\":\"Server status\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"Status\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"sacred\",\"description\":\"Sacred constants (φ, π, e, etc.)\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"SacredConstants\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"version\",\"description\":\"Version info\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"VersionInfo\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"docs\",\"description\":\"Documentation links\",\"args\":[],\"type\":{\"kind\":\"LIST\",\"ofType\":{\"kind\":\"OBJECT\",\"name\":\"DocLink\",\"ofType\":null}},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"stats\",\"description\":\"System statistics\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"SystemStats\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // Command type with full field metadata
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"Command\",\"description\":\"A command\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"name\",\"description\":\"Command name\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"category\",\"description\":\"Command category\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"description\",\"description\":\"Command description\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // Status type with full field metadata
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"Status\",\"description\":\"Server status\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"healthy\",\"description\":\"Whether server is healthy\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Boolean\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"connections\",\"description\":\"Number of connections\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Int\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"uptime\",\"description\":\"Server uptime in seconds\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Int\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // SacredConstants type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"SacredConstants\",\"description\":\"Sacred mathematical constants\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"phi\",\"description\":\"Golden ratio φ = 1.618...\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"phi_sq\",\"description\":\"φ² = 2.618...\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"trinity\",\"description\":\"φ² + 1/φ² = 3\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"pi\",\"description\":\"π = 3.14159...\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"e\",\"description\":\"e = 2.71828...\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"golden_angle\",\"description\":\"Golden angle = 137.5°\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Float\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // VersionInfo type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"VersionInfo\",\"description\":\"Version information\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"version\",\"description\":\"Version string\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"build\",\"description\":\"Build number\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"zig_version\",\"description\":\"Zig version\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // DocLink type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"DocLink\",\"description\":\"Documentation link\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"title\",\"description\":\"Link title\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"url\",\"description\":\"Link URL\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"category\",\"description\":\"Doc category\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // SystemStats type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"SystemStats\",\"description\":\"System statistics\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"commands_count\",\"description\":\"Total commands\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Int\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"categories_count\",\"description\":\"Total categories\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"Int\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"protocols\",\"description\":\"Active protocols\",\"args\":[],\"type\":{\"kind\":\"LIST\",\"ofType\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null}},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"endpoints\",\"description\":\"API endpoints\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"Endpoints\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // Endpoints type (nested in SystemStats)
            try buffer.appendSlice(self.allocator, "{\"kind\":\"OBJECT\",\"name\":\"Endpoints\",\"description\":\"API endpoints\",\"fields\":[");
            try buffer.appendSlice(self.allocator, "{\"name\":\"rest\",\"description\":\"REST endpoint\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"graphql\",\"description\":\"GraphQL endpoint\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"grpc\",\"description\":\"gRPC endpoint\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null},");
            try buffer.appendSlice(self.allocator, "{\"name\":\"websocket\",\"description\":\"WebSocket endpoint\",\"args\":[],\"type\":{\"kind\":\"SCALAR\",\"name\":\"String\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
            try buffer.appendSlice(self.allocator, "],\"inputFields\":null,\"interfaces\":[],\"enumValues\":null,\"possibleTypes\":null},");

            // Float scalar type (for sacred constants)
            try buffer.appendSlice(self.allocator, "{\"kind\":\"SCALAR\",\"name\":\"Float\",\"description\":\"Built-in Float scalar\",\"fields\":null,\"inputFields\":null,\"interfaces\":null,\"enumValues\":null,\"possibleTypes\":null},");

            // String scalar type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"SCALAR\",\"name\":\"String\",\"description\":\"Built-in String scalar\",\"fields\":null,\"inputFields\":null,\"interfaces\":null,\"enumValues\":null,\"possibleTypes\":null},");

            // Boolean scalar type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"SCALAR\",\"name\":\"Boolean\",\"description\":\"Built-in Boolean scalar\",\"fields\":null,\"inputFields\":null,\"interfaces\":null,\"enumValues\":null,\"possibleTypes\":null},");

            // Int scalar type
            try buffer.appendSlice(self.allocator, "{\"kind\":\"SCALAR\",\"name\":\"Int\",\"description\":\"Built-in Int scalar\",\"fields\":null,\"inputFields\":null,\"interfaces\":null,\"enumValues\":null,\"possibleTypes\":null}");

            try buffer.appendSlice(self.allocator, "],");
            try buffer.appendSlice(self.allocator, "\"directives\":[]}}}");

            return buffer.toOwnedSlice(self.allocator);
        }
        // Check for specific field queries FIRST (using {field pattern to avoid substring matches)
        if (std.mem.indexOf(u8, normalized_query, "{sacred") != null) {
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 512) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"data\":{\"sacred\":{");
            try buffer.appendSlice(self.allocator, "\"phi\":1.618033988749895,");
            try buffer.appendSlice(self.allocator, "\"phi_sq\":2.618033988749895,");
            try buffer.appendSlice(self.allocator, "\"trinity\":3.0,");
            try buffer.appendSlice(self.allocator, "\"pi\":3.141592653589793,");
            try buffer.appendSlice(self.allocator, "\"e\":2.718281828459045,");
            try buffer.appendSlice(self.allocator, "\"golden_angle\":137.50776405003785");
            try buffer.appendSlice(self.allocator, "}}}");
            return buffer.toOwnedSlice(self.allocator);
        }

        if (std.mem.indexOf(u8, normalized_query, "{version") != null) {
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"data\":{\"version\":{");
            try buffer.appendSlice(self.allocator, "\"version\":\"1.0.0\",");
            try buffer.appendSlice(self.allocator, "\"build\":\"Cycle 102\",");
            try buffer.appendSlice(self.allocator, "\"zig_version\":\"0.15.2\"");
            try buffer.appendSlice(self.allocator, "}}}");
            return buffer.toOwnedSlice(self.allocator);
        }

        if (std.mem.indexOf(u8, normalized_query, "{docs") != null) {
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 1024) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"data\":{\"docs\":[");
            try buffer.appendSlice(self.allocator, "{\"title\":\"GraphQL API\",\"url\":\"/graphql\",\"category\":\"API\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"REST API\",\"url\":\"/api/*\",\"category\":\"API\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"OpenAPI Spec\",\"url\":\"/api/openapi.json\",\"category\":\"API\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"TRINITY Docs\",\"url\":\"https://ghashtag.github.io/trinity/docs\",\"category\":\"Documentation\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"Research\",\"url\":\"https://ghashtag.github.io/trinity/docs/research\",\"category\":\"Documentation\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"Benchmarks\",\"url\":\"https://ghashtag.github.io/trinity/docs/benchmarks\",\"category\":\"Documentation\"},");
            try buffer.appendSlice(self.allocator, "{\"title\":\"GitHub\",\"url\":\"https://github.com/ghashtag/trinity\",\"category\":\"Source\"}");
            try buffer.appendSlice(self.allocator, "]}}");
            return buffer.toOwnedSlice(self.allocator);
        }

        if (std.mem.indexOf(u8, normalized_query, "{stats") != null) {
            const cmd_count = self.registry.count();
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 512) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"data\":{\"stats\":{");
            const cmd_str = try std.fmt.allocPrint(self.allocator, "{d}", .{cmd_count});
            defer self.allocator.free(cmd_str);
            try buffer.appendSlice(self.allocator, "\"commands_count\":");
            try buffer.appendSlice(self.allocator, cmd_str);
            try buffer.appendSlice(self.allocator, ",\"categories_count\":17,");
            try buffer.appendSlice(self.allocator, "\"protocols\":[\"REST\",\"GraphQL\",\"gRPC\",\"WebSocket\"],");
            try buffer.appendSlice(self.allocator, "\"endpoints\":{");
            try buffer.appendSlice(self.allocator, "\"rest\":\"http://localhost:8080/api/*\",");
            try buffer.appendSlice(self.allocator, "\"graphql\":\"http://localhost:8080/graphql\",");
            try buffer.appendSlice(self.allocator, "\"grpc\":\"http://localhost:9335\",");
            try buffer.appendSlice(self.allocator, "\"websocket\":\"http://localhost:8080/ws\"");
            try buffer.appendSlice(self.allocator, "}}}}");
            return buffer.toOwnedSlice(self.allocator);
        }

        if (std.mem.indexOf(u8, normalized_query, "{status") != null) {
            const uptime = std.time.milliTimestamp() - self.status.start_time;
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
            try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
            try buffer.appendSlice(self.allocator, "{\"data\":{\"status\":{\"healthy\":true,\"connections\":");
            const conn_str = try std.fmt.allocPrint(self.allocator, "{d}", .{self.status.connections});
            defer self.allocator.free(conn_str);
            try buffer.appendSlice(self.allocator, conn_str);
            try buffer.appendSlice(self.allocator, ",\"uptime\":");
            const uptime_str = try std.fmt.allocPrint(self.allocator, "{d}", .{uptime});
            defer self.allocator.free(uptime_str);
            try buffer.appendSlice(self.allocator, uptime_str);
            try buffer.appendSlice(self.allocator, "}}}}");
            return buffer.toOwnedSlice(self.allocator);
        }

        // Commands query - check LAST (most specific pattern)
        if (std.mem.indexOf(u8, normalized_query, "{commands") != null or
            std.mem.indexOf(u8, normalized_query, "commands") != null) {
            std.debug.print("DEBUG: Matched commands query!\n", .{});

            // Build JSON response with all commands
            var response_buffer = std.ArrayList(u8).initCapacity(self.allocator, 8192) catch return error.OutOfMemory;
            errdefer response_buffer.deinit(self.allocator);

            try response_buffer.appendSlice(self.allocator,
                \\HTTP/1.1 200 OK
                \\Content-Type: application/json
                \\Access-Control-Allow-Origin: *
                \\
                \\"data":{"commands":[
            );

            var iter = self.registry.commands.iterator();
            var first = true;
            while (iter.next()) |entry| {
                if (!first) try response_buffer.append(self.allocator, ',');
                first = false;

                const cmd = entry.value_ptr.*;
                const cat_str = categoryToString(cmd.category);

                try response_buffer.appendSlice(self.allocator, "{\"name\":\"");
                try response_buffer.appendSlice(self.allocator, cmd.name);
                try response_buffer.appendSlice(self.allocator, "\",\"category\":\"");
                try response_buffer.appendSlice(self.allocator, cat_str);
                try response_buffer.appendSlice(self.allocator, "\",\"description\":\"");
                try response_buffer.appendSlice(self.allocator, cmd.description);
                try response_buffer.appendSlice(self.allocator, "\"}");
            }

            try response_buffer.appendSlice(self.allocator, "]}");

            const result = response_buffer.toOwnedSlice(self.allocator);
            std.debug.print("DEBUG: Returning response\n", .{});
            return result;
        }

        // Unknown query - return error
        var buffer = std.ArrayList(u8).initCapacity(self.allocator, 256) catch return error.OutOfMemory;
        try buffer.appendSlice(self.allocator, "HTTP/1.1 200 OK\nContent-Type: application/json\nAccess-Control-Allow-Origin: *\n\n");
        try buffer.appendSlice(self.allocator, "{\"data\":null,\"errors\":[{\"message\":\"Cannot query field: unknown\"}]}");
        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn stop(self: *UnifiedApiServer) void {
        self.status.running = false;
        if (self.server_socket) |sock| {
            std.posix.close(sock);
            self.server_socket = null;
        }
        const uptime = std.time.milliTimestamp() - self.status.start_time;
        std.debug.print("\n{s}►{s} Server stopped. Uptime: {d:.1}s{s}\n", .{CYAN, RESET, @as(f64, @floatFromInt(uptime)) / 1000.0, RESET});
    }

    fn printBanner(self: *const UnifiedApiServer) !void {
        _ = self;
        std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{YELLOW, RESET});
        std.debug.print("{s}║     TRINITY UNIFIED API SERVER v1.0 — REST + GraphQL           ║{s}\n", .{GREEN, RESET});
        std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n", .{YELLOW, RESET});
        std.debug.print("\n", .{});
    }

    fn startProtocols(self: *UnifiedApiServer) !void {
        const protocols = switch (self.config.protocols) {
            .all => &[_][]const u8{"REST", "GraphQL", "gRPC", "WebSocket"},
            .rest_only => &[_][]const u8{"REST"},
            .graphql_only => &[_][]const u8{"GraphQL"},
            .grpc_only => &[_][]const u8{"gRPC"},
            .ws_only => &[_][]const u8{"WebSocket"},
            .rest_graphql => &[_][]const u8{"REST", "GraphQL"},
            .custom => &[_][]const u8{},
        };

        for (protocols) |proto| {
            try self.status.protocols_active.append(self.allocator, proto);
        }
    }

    fn printStatus(self: *const UnifiedApiServer) !void {
        std.debug.print("  {s}►{s} Server Status:\n\n", .{CYAN, RESET});

        for (self.status.protocols_active.items) |proto| {
            const port = if (std.mem.eql(u8, proto, "gRPC"))
                self.config.grpc_port
            else
                self.config.port;

            const path = if (std.mem.eql(u8, proto, "REST"))
                "/api/*"
            else if (std.mem.eql(u8, proto, "GraphQL"))
                "/graphql"
            else if (std.mem.eql(u8, proto, "WebSocket"))
                "/ws"
            else
                "";

            const is_planned = std.mem.eql(u8, proto, "gRPC") or std.mem.eql(u8, proto, "WebSocket");
            if (is_planned) {
                std.debug.print("    {s}○{s} {s:<10} → http://localhost:{d}{s} (planned)\n", .{YELLOW, RESET, proto, port, path});
            } else {
                std.debug.print("    {s}✓{s} {s:<10} → http://localhost:{d}{s}\n", .{GREEN, RESET, proto, port, path});
            }
        }

        std.debug.print("\n", .{});
        std.debug.print("  {s}►{s} Endpoints: {d} commands registered\n", .{CYAN, RESET, self.registry.count()});
        std.debug.print("  {s}►{s} OpenAPI:  http://localhost:{d}/api/openapi.json\n", .{CYAN, RESET, self.config.port});
        std.debug.print("  {s}►{s} GraphQL:  http://localhost:{d}/graphql\n", .{CYAN, RESET, self.config.port});
        std.debug.print("\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY | Press Ctrl+C to stop{s}\n\n", .{YELLOW, RESET});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var config = ServeConfig{};

    // Parse flags
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--port") or std.mem.eql(u8, arg, "-p")) {
            if (i + 1 < args.len) {
                i += 1;
                config.port = try std.fmt.parseInt(u16, args[i], 10);
            }
        } else if (std.mem.eql(u8, arg, "--grpc-port")) {
            if (i + 1 < args.len) {
                i += 1;
                config.grpc_port = try std.fmt.parseInt(u16, args[i], 10);
            }
        } else if (std.mem.eql(u8, arg, "--protocols")) {
            if (i + 1 < args.len) {
                i += 1;
                const protos = args[i];
                if (std.mem.eql(u8, protos, "all")) {
                    config.protocols = .all;
                } else if (std.mem.eql(u8, protos, "rest,graphql")) {
                    config.protocols = .rest_graphql;
                }
            }
        } else if (std.mem.eql(u8, arg, "--no-openapi")) {
            config.enable_openapi = false;
        } else if (std.mem.eql(u8, arg, "--no-playground")) {
            config.enable_playground = false;
        } else if (std.mem.eql(u8, arg, "--daemon")) {
            config.daemon = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
    }

    // Start server
    var server = try UnifiedApiServer.init(allocator, config);
    defer server.deinit();

    try server.start();
    // Event loop runs inside server.start() → runEventLoop()
    // Server blocks until Ctrl+C or signal
}

pub fn printHelp() void {
    std.debug.print("\n{s}USAGE:{s}\n", .{GREEN, RESET});
    std.debug.print("  tri serve [OPTIONS]\n\n", .{});
    std.debug.print("{s}OPTIONS:{s}\n", .{YELLOW, RESET});
    std.debug.print("  -p, --port <port>           Main port for REST/GraphQL/WS (default: 8080)\n", .{});
    std.debug.print("  --grpc-port <port>         Port for gRPC server (default: 9335)\n", .{});
    std.debug.print("  --protocols <list>         Protocols: all, rest, graphql, grpc, ws (default: all)\n", .{});
    std.debug.print("  --no-openapi               Disable OpenAPI spec generation\n", .{});
    std.debug.print("  --no-playground             Disable GraphQL Playground\n", .{});
    std.debug.print("  --daemon                   Run as background daemon\n", .{});
    std.debug.print("  -h, --help                  Show this help message\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{s}EXAMPLES:{s}\n", .{YELLOW, RESET});
    std.debug.print("  tri serve\n", .{});
    std.debug.print("  tri serve --port 3000 --protocols rest,graphql\n", .{});
    std.debug.print("  tri serve --grpc-port 50051 --daemon\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ServeConfig defaults" {
    const config = ServeConfig{};
    try std.testing.expectEqual(@as(u16, 8080), config.port);
    try std.testing.expectEqual(@as(u16, 9335), config.grpc_port);
    try std.testing.expectEqual(ServeConfig.Protocols.all, config.protocols);
}

test "ServerStatus init" {
    var status = ServerStatus.init(std.testing.allocator);
    defer status.deinit();

    try std.testing.expect(!status.running);
    try std.testing.expectEqual(@as(u32, 0), status.connections);
}

test "UnifiedApiServer init" {
    var server = try UnifiedApiServer.init(std.testing.allocator, .{});
    defer server.deinit();

    try std.testing.expect(!server.status.running);
    try std.testing.expect(server.registry.count() > 50);
}
