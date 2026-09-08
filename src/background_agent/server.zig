//! Background Agent HTTP Server
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

const Config = @import("config.zig").Config;
const Sessions = @import("db/sessions.zig");
const railway = @import("railway/client.zig");
const RailwayClient = railway.RailwayClient;
const railwayInit = railway.init;
const Jwt = @import("auth/jwt.zig");
const PostgresClient = @import("db/client.zig").PostgresClient;

/// HTTP request context
pub const RequestContext = struct {
    method: []const u8,
    path: []const u8,
    query: []const u8,
    headers: std.ArrayList(Header),
    body: []const u8,
    user_id: ?[]const u8 = null, // From JWT
};

/// HTTP header
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// HTTP response
pub const Response = struct {
    status: u16 = 200,
    content_type: []const u8 = "application/json",
    body: []const u8,
    cors: bool = true,
};

/// HTTP server
pub const Server = struct {
    allocator: Allocator,
    address: net.Address,
    server: net.Server,
    running: bool,

    config: Config,
    db_client: PostgresClient,
    railway_client: ?RailwayClient,
    auth_secret: []const u8,
};

/// Initialize server
    pub fn init(allocator: Allocator, config: Config, db_client: PostgresClient, auth_secret: []const u8) !Server {
        const address = try net.Address.parseIp(config.host, config.port);

        const server = try net.Address.listen(address, .{ .reuse_address = true });

        // Initialize Railway client if not in local mode
        const railway_client = if (config.localMode) null else railwayInit(allocator, config.railwayApiToken, config.railwayProjectId);

        return .{
            .allocator = allocator,
            .address = address,
            .server = server,
            .running = false,
            .config = config,
            .db_client = db_client,
            .railway_client = railway_client,
            .auth_secret = auth_secret,
        };
    }

    /// Start HTTP server
    pub fn start(self: *Server) !void {
        if (self.running) return;

        self.running = true;

        // The address struct printed as a raw dump of its union, which says
        // nothing a reader can use. The configured host and port do.
        std.log.info("Background agent listening on {s}:{d}", .{ self.config.host, self.config.port });

        while (self.running) {
            const connection = self.server.accept() catch |err| {
                std.log.err("Accept error: {}", .{err});
                continue;
            };

            // Handle connection in a thread
            handleConnection(self, connection) catch |err| {
                std.log.err("Connection error: {}", .{err});
            };
        }
    }

    /// Stop server
    pub fn stop(self: *Server) void {
        self.running = false;
    }

    /// Content-Length from a completed header block, 0 when absent or unparsable.
    fn contentLengthOf(headers_raw: []const u8) usize {
        var lines = std.mem.splitSequence(u8, headers_raw, "\r\n");
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const name = std.mem.trim(u8, line[0..colon], " \t");
            if (!std.ascii.eqlIgnoreCase(name, "Content-Length")) continue;
            const value = std.mem.trim(u8, line[colon + 1 ..], " \t\r");
            return std.fmt.parseInt(usize, value, 10) catch 0;
        }
        return 0;
    }

    /// Handle HTTP connection
    fn handleConnection(self: *Server, connection: net.Server.Connection) !void {
        defer connection.stream.close();

        // One read is not one request: TCP may hand over the headers and the
        // body in separate segments, and a single read() then returns a request
        // with nothing after the blank line. Read until the header block is
        // complete, then until Content-Length bytes have followed it.
        var buffer: [8192]u8 = undefined;
        var filled: usize = 0;
        var header_end: ?usize = null;

        while (filled < buffer.len) {
            const n = try connection.stream.read(buffer[filled..]);
            if (n == 0) break;
            filled += n;
            if (header_end == null) {
                if (std.mem.indexOf(u8, buffer[0..filled], "\r\n\r\n")) |cut| header_end = cut + 4;
            }
            if (header_end) |end| {
                const want = contentLengthOf(buffer[0..end]);
                if (filled - end >= want) break;
            }
        }

        // Parse HTTP request
        const request_str = buffer[0..filled];
        var lines = std.mem.splitScalar(u8, request_str, '\n');

        const first_line = if (lines.next()) |line| line else return error.InvalidRequest;
        var parts = std.mem.splitScalar(u8, first_line, ' ');

        // A request line is "METHOD TARGET PROTOCOL", three fields. This skipped
        // the target and then read the URI from a fourth field that does not
        // exist, so path was always empty, no route ever matched, and every
        // request — including the platform's health probe — got nothing back.
        const method = parts.next() orelse return error.InvalidRequest;
        const target = parts.next() orelse return error.InvalidRequest;

        // Parse URI and query string
        var uri_parts = std.mem.splitScalar(u8, target, '?');
        const path = uri_parts.next() orelse return error.InvalidRequest;
        const query = uri_parts.next() orelse "";

        // Parse headers
        var headers = try std.ArrayList(Header).initCapacity(self.allocator, 16);
        errdefer {
            for (headers.items) |*h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            headers.deinit(self.allocator);
        }

        while (lines.next()) |line| {
            if (line.len == 0) break; // Empty line = end of headers
            var header_parts = std.mem.splitScalar(u8, line, ':');
            if (header_parts.next()) |name| {
                if (header_parts.next()) |value| {
                    // Header lines end with CRLF and this splits on \n, so every
                    // value carried a trailing \r. It reached the JWT decoder
                    // inside the token and base64 rejected it as an invalid
                    // character — every authenticated request answered 401.
                    const value_trimmed = std.mem.trim(u8, value, " \t\r");
                    try headers.append(self.allocator, .{
                        .name = try self.allocator.dupe(u8, std.mem.trim(u8, name, " \t\r")),
                        .value = try self.allocator.dupe(u8, value_trimmed),
                    });
                }
            }
        }

        // The body is whatever follows the blank line that ends the headers.
        //
        // The previous walk restarted its offset at zero and reused the line
        // iterator the header loop had already drained, so it never found the
        // break and the body came out empty — every POST reached the handler
        // with nothing to parse and died on UnexpectedEndOfInput.
        const body = if (std.mem.indexOf(u8, request_str, "\r\n\r\n")) |cut|
            request_str[cut + 4 ..]
        else if (std.mem.indexOf(u8, request_str, "\n\n")) |cut|
            request_str[cut + 2 ..]
        else
            request_str[0..0];

        // Verify JWT if Authorization header
        var user_id: ?[]const u8 = null;
        for (headers.items) |*h| {
            if (std.mem.eql(u8, h.name, "Authorization")) {
                var auth_parts = std.mem.splitScalar(u8, h.value, ' ');
                _ = auth_parts.next(); // "Bearer"
                var token: []const u8 = "";
                // Collect remaining bytes as token
                while (auth_parts.next()) |part| {
                    token = part;
                }

                if (token.len > 0) {
                    const payload = Jwt.verifyToken(self.allocator, token, self.auth_secret) catch |err| {
                        std.log.warn("JWT verification failed: {}", .{err});
                        continue;
                    };
                    defer self.allocator.free(payload.sub);

                    user_id = payload.sub;
                }
            }
        }

        const request_context = RequestContext{
            .method = method,
            .path = path,
            .query = query,
            .headers = headers,
            .body = body,
            .user_id = user_id,
        };

        // Route and handle request
        const response = try routeRequest(self, &request_context);

        // One line per request. Without it the container logged four lines at
        // boot and then nothing for the rest of its life, so a service that was
        // answering looked identical to one that was not.
        std.log.info("{s} {s} -> {d}", .{ method, path, response.status });

        // Send response
        try sendResponse(self, connection.stream, response);
    }

    /// Route request to handler
    fn methodNotAllowed() Response {
        return Response{
            .status = 405,
            .content_type = "application/json",
            .body = "{\"error\":\"Method Not Allowed\"}",
        };
    }

    pub fn routeRequest(self: *Server, ctx: *const RequestContext) !Response {
        // GET /health
        if (std.mem.eql(u8, ctx.path, "/health")) {
            return Response{
                .status = 200,
                .content_type = "application/json",
                .body = "{\"status\":\"ok\"}",
            };
        }

        // Require authentication for /api routes
        if (ctx.user_id == null) {
            return Response{
                .status = 401,
                .body = "{\"error\":\"Unauthorized\"}",
            };
        }

        // The collection: list, or open a new session.
        //
        // The GET arm used to carry no method guard, so it answered POST as
        // well and handleCreateSession was unreachable — the same shape of bug
        // hid handleDeleteSession behind the GET for a single session. Between
        // them, nothing could start a bee's work or close it: the two verbs the
        // Queen needs to task one and retire it.
        if (std.mem.eql(u8, ctx.path, "/api/sessions")) {
            if (std.mem.eql(u8, ctx.method, "POST")) return handleCreateSession(self, ctx.body);
            if (std.mem.eql(u8, ctx.method, "GET")) return handleListSessions(self);
            return methodNotAllowed();
        }

        // One session: read it, or end it.
        if (std.mem.startsWith(u8, ctx.path, "/api/sessions/")) {
            const session_id = ctx.path["/api/sessions/".len..];
            if (std.mem.eql(u8, ctx.method, "DELETE")) return handleDeleteSession(self, session_id);
            if (std.mem.eql(u8, ctx.method, "GET")) return handleGetSession(self, session_id);
            return methodNotAllowed();
        }

        // POST /api/containers
        if (std.mem.eql(u8, ctx.path, "/api/containers") and std.mem.eql(u8, ctx.method, "POST")) {
            return handleCreateContainer(self, ctx.body);
        }

        // DELETE /api/containers/:id
        if (std.mem.eql(u8, ctx.method, "DELETE") and std.mem.startsWith(u8, ctx.path, "/api/containers/")) {
            const service_id = ctx.path["/api/containers/".len..];
            return handleDeleteContainer(self, service_id);
        }

        return Response{
            .status = 404,
            .body = "{\"error\":\"Not Found\"}",
        };
    }

    /// Handle GET /api/sessions
    fn handleListSessions(self: *Server) !Response {
        const allocator = self.allocator;

        var sessions = try Sessions.listSessions(allocator, &self.db_client);
        defer {
            for (sessions.items) |*s| {
                allocator.free(s.id);
                allocator.free(s.name);
                allocator.free(s.status);
                allocator.free(s.railway_service_id);
                allocator.free(s.soul_file);
            }
            sessions.deinit(allocator);
        }

        // Build JSON response
        var json = try std.ArrayList(u8).initCapacity(allocator, 512);
        try json.appendSlice(allocator, "{\"sessions\":[");
        for (sessions.items, 0..) |s, i| {
            if (i > 0) try json.append(allocator, ',');
            try json.writer(allocator).print(
                \\{{"id":"{s}","name":"{s}","status":"{s}","railway_service_id":"{s}"}}
            , .{ s.id, s.name, s.status, s.railway_service_id });
        }
        try json.appendSlice(allocator, "]}");

        return Response{
            .status = 200,
            .body = try json.toOwnedSlice(allocator),
        };
    }

    /// Handle POST /api/sessions
    fn handleCreateSession(self: *Server, body: []const u8) !Response {
        const allocator = self.allocator;

        // Parse JSON body
        const parsed = try std.json.parseFromSlice(struct {
            name: []const u8,
            service_id: []const u8,
        }, allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        // Create session
        const session = try Sessions.createSession(allocator, &self.db_client, parsed.value.name, parsed.value.service_id);
        defer {
            allocator.free(session.id);
            allocator.free(session.name);
            allocator.free(session.status);
            allocator.free(session.railway_service_id);
        }

        // Build JSON response
        const json = try std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","name":"{s}","status":"{s}","railway_service_id":"{s}"}}
        , .{ session.id, session.name, session.status, session.railway_service_id });

        return Response{
            .status = 201,
            .body = json,
        };
    }

    /// Handle GET /api/sessions/:id
    fn handleGetSession(self: *Server, session_id: []const u8) !Response {
        const allocator = self.allocator;

        const session = Sessions.getSession(allocator, &self.db_client, session_id) catch |err| {
            return switch (err) {
                error.SessionNotFound => Response{
                    .status = 404,
                    .body = "{\"error\":\"Session not found\"}",
                },
                else => Response{
                    .status = 500,
                    .body = "{\"error\":\"Database error\"}",
                },
            };
        };
        defer {
            allocator.free(session.id);
            allocator.free(session.name);
            allocator.free(session.status);
            allocator.free(session.railway_service_id);
        }

        const json = try std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","name":"{s}","status":"{s}","railway_service_id":"{s}"}}
        , .{ session.id, session.name, session.status, session.railway_service_id });

        return Response{
            .status = 200,
            .body = json,
        };
    }

    /// Handle DELETE /api/sessions/:id
    fn handleDeleteSession(self: *Server, session_id: []const u8) !Response {
        _ = Sessions.deleteSession(&self.db_client, session_id) catch |err| {
            return switch (err) {
                error.InvalidInput => Response{
                    .status = 404,
                    .body = "{\"error\":\"Session not found\"}",
                },
                else => Response{
                    .status = 500,
                    .body = "{\"error\":\"Database error\"}",
                },
            };
        };

        return Response{
            .status = 200,
            .body = "{\"status\":\"deleted\"}",
        };
    }

    /// Handle POST /api/containers
    fn handleCreateContainer(self: *Server, body: []const u8) !Response {
        const allocator = self.allocator;

        // Check Railway client
        if (self.railway_client == null) return Response{
            .status = 503,
            .body = "{\"error\":\"Railway not available in local mode\"}",
        };

        // Parse JSON body
        const parsed = try std.json.parseFromSlice(struct {
            environment_id: []const u8,
            name: []const u8,
            image: []const u8,
        }, allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        // Create Railway service
        const result = railway.createService(&self.railway_client.?, parsed.value.environment_id, parsed.value.name, parsed.value.image) catch |err| {
            return Response{
                .status = 500,
                .body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{@errorName(err)}),
            };
        };
        defer allocator.free(result.id);

        // Create session
        const session = try Sessions.createSession(allocator, &self.db_client, parsed.value.name, result.id);
        defer {
            allocator.free(session.id);
            allocator.free(session.name);
            allocator.free(session.status);
            allocator.free(session.railway_service_id);
        }

        const json = try std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","name":"{s}","status":"{s}","railway_service_id":"{s}"}}
        , .{ session.id, session.name, session.status, session.railway_service_id });

        return Response{
            .status = 201,
            .body = json,
        };
    }

    /// Handle DELETE /api/containers/:id
    fn handleDeleteContainer(self: *Server, service_id: []const u8) !Response {
        const allocator = self.allocator;

        // Check Railway client
        if (self.railway_client == null) return Response{
            .status = 503,
            .body = "{\"error\":\"Railway not available in local mode\"}",
        };

        // Delete Railway service
        _ = railway.deleteService(&self.railway_client.?, service_id) catch |err| {
            return Response{
                .status = 500,
                .body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{@errorName(err)}),
            };
        };

        // Update sessions to remove service_id reference
        _ = Sessions.updateSession(allocator, &self.db_client, service_id, .{
            .status = null,
            .name = null,
            .railway_service_id = null,
        }) catch {
            return Response{
                .status = 500,
                .body = "{\"error\":\"Failed to update sessions\"}",
            };
        };

        return Response{
            .status = 200,
            .body = "{\"status\":\"deleted\"}",
        };
    }

    /// Send HTTP response
    fn sendResponse(self: *Server, stream: net.Stream, response: Response) !void {
        // A multiline literal does not process escapes: "\r" inside one is a
        // backslash and an r, and the lines end with a bare \n. The response
        // therefore had no CRLF anywhere and a single stray character where the
        // blank line between headers and body belongs — not HTTP, which is why
        // the proxy answered 502 while the process sat there healthy.
        var headers = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer headers.deinit(self.allocator);

        try headers.writer(self.allocator).print(
            "HTTP/1.1 {d} OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n",
            .{ response.status, response.content_type, response.body.len },
        );

        if (response.cors) {
            try headers.appendSlice(self.allocator, "Access-Control-Allow-Origin: *\r\n");
            try headers.appendSlice(self.allocator, "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n");
            try headers.appendSlice(self.allocator, "Access-Control-Allow-Headers: Content-Type, Authorization\r\n");
        }

        // The blank line that ends the header block.
        try headers.appendSlice(self.allocator, "\r\n");

        try stream.writeAll(headers.items);
        try stream.writeAll(response.body);
    }

    /// Get error name from error union
    fn errorName(err: anyerror) []const u8 {
        return switch (err) {
            error.ConnectionFailed => "ConnectionFailed",
            error.InvalidResponse => "InvalidResponse",
            error.AuthFailed => "AuthFailed",
            error.GraphQL => "GraphQL",
            error.SessionNotFound => "SessionNotFound",
            error.DatabaseError => "DatabaseError",
            error.InvalidInput => "InvalidInput",
            error.InvalidStatus => "InvalidStatus",
            error.InvalidUrl => "InvalidUrl",
            else => "Unknown",
        };
    }

test "server: parse simple request" {
    const request = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n";

    var lines = std.mem.splitScalar(u8, request, '\n');
    const first_line = if (lines.next()) |line| line else @panic("no first line");
    var parts = std.mem.splitScalar(u8, first_line, ' ');

    const method = if (parts.next()) |m| m else @panic("no method");
    try std.testing.expectEqualStrings(method, "GET");
}

test "server: build health response" {
    const response = Response{
        .status = 200,
        .content_type = "application/json",
        .body = "{\"status\":\"ok\"}",
        .cors = true,
    };

    try std.testing.expect(response.status == 200);
    try std.testing.expectEqualStrings(response.body, "{\"status\":\"ok\"}");
}
