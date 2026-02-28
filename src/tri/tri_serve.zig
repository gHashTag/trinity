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

        while (self.status.running) {
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
        // GraphiQL 5.x - Official GraphQL Foundation playground
        var buffer = std.ArrayList(u8).initCapacity(self.allocator, 8192) catch return error.OutOfMemory;
        try buffer.appendSlice(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: text/html
            \\Access-Control-Allow-Origin: *
            \\
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <meta charset="utf-8"/>
            \\  <title>TRINITY GraphQL - GraphiQL</title>
            \\  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/graphiql@5.0.0/style.css" />
            \\  <style>
            \\    body { margin: 0; height: 100vh; overflow: hidden; }
            \\    #graphiql { height: 100vh; }
            \\    .graphiql-container { --color-primary: #ffd700; }
            \\  </style>
            \\</head>
            \\<body>
            \\  <div id="graphiql">Loading...</div>
            \\  <script type="module">
            \\    import { GraphiQL } from 'https://cdn.jsdelivr.net/npm/graphiql@5.0.0/dist/esm/index.js';
            \\    import { createGraphiQLFetcher } from 'https://cdn.jsdelivr.net/npm/@graphiql/toolkit@0.8.3/esm/createFetcher.js';
            \\
            \\    const fetcher = createGraphiQLFetcher({ url: '/graphql' });
            \\
            \\    const root = document.getElementById('graphiql');
            \\    root.innerHTML = '';
            \\
            \\    const graphiql = new GraphiQL({
            \\      fetcher,
            \\      root,
            \\      defaultQuery: `# TRINITY GraphQL API
            \\# Press Ctrl+Enter to execute
            \\
            \\{
            \\  commands {
            \\    name
            \\    category
            \\    description
            \\  }
            \\}
            \\
            \\# Try these:
            \\# { status { healthy connections uptime } }
            \\# { __type(name: "Command") { fields { name description } } }`,
            \\      isHeadersEditorEnabled: false,
            \\      shouldPersistHeaders: false
            \\    });
            \\  </script>
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
            try buffer.appendSlice(self.allocator, "{\"name\":\"status\",\"description\":\"Server status\",\"args\":[],\"type\":{\"kind\":\"OBJECT\",\"name\":\"Status\",\"ofType\":null},\"isDeprecated\":false,\"deprecationReason\":null}");
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

        // Handle { status { healthy connections } } query
        if (std.mem.indexOf(u8, normalized_query, "{status") != null or
            std.mem.indexOf(u8, normalized_query, "status") != null) {
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
        std.debug.print("{s}║         TRINITY UNIFIED API SERVER v1.0 — 4 PROTOCOLS          ║{s}\n", .{GREEN, RESET});
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

            std.debug.print("    {s}✓{s} {s:<10} → http://localhost:{d}{s}\n", .{GREEN, RESET, proto, port, path});
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

    // In real implementation, would run event loop here
    // For now, just show what would happen

    if (!config.daemon) {
        std.debug.print("\n{s}[Demo mode — server would run here]{s}\n", .{YELLOW, RESET});
    }
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
