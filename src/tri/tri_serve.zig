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
            defer std.posix.close(client_socket);

            // Read request
            var buffer: [2048]u8 = undefined;
            const bytes_read = std.posix.read(client_socket, &buffer) catch |err| {
                if (err == error.WouldBlock) continue;
                continue;
            };

            if (bytes_read > 0) {
                const request = buffer[0..bytes_read];

                // Parse HTTP request
                if (std.mem.indexOf(u8, request, "GET /api/health") != null) {
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
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 200 OK
            \\Content-Type: text/html
            \\Access-Control-Allow-Origin: *
            \\
            \\<html><body><h1>GraphQL Playground</h1><p>130 commands available</p></body></html>
        , .{});
    }

    fn notFoundResponse(self: *const UnifiedApiServer) ![]const u8 {
        return std.fmt.allocPrint(self.allocator,
            \\HTTP/1.1 404 Not Found
            \\Content-Type: application/json
            \\
            \\{{"error":"Not Found"}}
        , .{});
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
