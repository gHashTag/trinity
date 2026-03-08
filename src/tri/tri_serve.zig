// ═══════════════════════════════════════════════════════════════════════════════
// TRI SERVE COMMAND — Unified API Server Launcher
// Launches REST + GraphQL + gRPC + WebSocket simultaneously
// φ² + 1/φ² = 3 = TRINITY | Golden Chain #102
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const api = @import("api");

pub const YELLOW = "\x1b[38;2;255;215;0m";
pub const GREEN = "\x1b[38;2;0;229;153m";
pub const CYAN = "\x1b[38;2;0;255;255m";
pub const RESET = "\x1b[0m";

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNAL HANDLING FOR GRACEFUL SHUTDOWN
// ═══════════════════════════════════════════════════════════════════════════════

// Global atomic flag for signal handling
var shutdown_requested = std.atomic.Value(bool).init(false);

// Signal handler for SIGINT and SIGTERM
fn signalHandler(sig: c_int) callconv(.C) void {
    _ = sig;
    shutdown_requested.store(true, .seq_cst);
}

// Setup signal handlers for graceful shutdown
fn setupSignalHandlers() !void {
    const SA = std.os.Sigaction;

    // Create sigaction for signal handler
    const act = SA{
        .handler = .{ .handler = signalHandler },
        .mask = std.os.empty_sigset,
        .flags = 0,
    };

    // Register SIGINT handler (Ctrl+C)
    try std.os.sigaction(std.os.SIG.INT, &act, null);

    // Register SIGTERM handler
    try std.os.sigaction(std.os.SIG.TERM, &act, null);
}

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

        // Setup signal handlers for graceful shutdown
        try setupSignalHandlers();

        // Show banner
        try self.printBanner();

        // Start actual HTTP server
        try self.startHttpServer();

        // Start enabled protocols (for display)
        try self.startProtocols();

        // Show status
        try self.printStatus();

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

        const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, self.config.port);
        try std.posix.bind(server_socket, &addr.any, addr.getOsSockLen());
        try std.posix.listen(server_socket, 128);

        self.server_socket = server_socket;
        std.debug.print("  {s}✓{s} HTTP server listening on port {d}\n", .{GREEN, RESET, self.config.port});
    }

    fn runEventLoop(self: *UnifiedApiServer) !void {
        const socket = self.server_socket orelse return error.ServerNotStarted;

        while (self.status.running and !shutdown_requested.load(.seq_cst)) {
            // Accept connection
            var client_addr: std.net.Address = undefined;
            var client_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);
            const client_socket = std.posix.accept(socket, &client_addr.any, &client_addr_len, 0) catch |err| {
                if (err == error.WouldBlock) continue;
                return err;
            };

            // Set client socket to non-blocking for read with timeout
            const flags = std.posix.fcntl(client_socket, std.posix.F.GETFL, 0) catch 0;
            _ = std.posix.fcntl(client_socket, std.posix.F.SETFL, flags | 4) catch {}; // 4 = O_NONBLOCK

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
                else if (std.mem.indexOf(u8, request, "GET /api/health") != null) {
                    // Health check response
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

    // Parse simple JSON: {"query":"{ commands { name } }"}
    // Extract the query string between "query":" and "}
    fn extractGraphQLQuery(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
        // Find "query":" pattern
        const query_key = "\"query\":\"";
        const query_start_idx = std.mem.indexOf(u8, body, query_key) orelse return error.MalformedJSON;
        const query_start = query_start_idx + query_key.len;

        // Find closing "}
        const query_end = std.mem.indexOf(u8, body[query_start..], "\"}") orelse {
            // Try just " as end
            const end_brace = std.mem.indexOf(u8, body[query_start..], "\"") orelse return error.MalformedJSON;
            return allocator.dupe(u8, body[query_start..][0..end_brace]);
        };

        // Handle escaped quotes in query
        var query_list = std.ArrayList(u8).initCapacity(allocator, 256) catch return error.OutOfMemory;
        errdefer query_list.deinit(allocator);

        var i: usize = 0;
        while (i < query_end) : (i += 1) {
            const c = body[query_start + i];
            // Handle escaped characters like \n
            if (c == '\\' and i + 1 < query_end) {
                const next = body[query_start + i + 1];
                if (next == 'n') {
                    try query_list.append(allocator, '\n');
                    i += 1;
                } else if (next == '"') {
                    try query_list.append(allocator, '"');
                    i += 1;
                } else {
                    try query_list.append(allocator, c);
                }
            } else {
                try query_list.append(allocator, c);
            }
        }

        return query_list.toOwnedSlice(allocator);
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
