//! MCP HTTP/SSE Transport Module
//!
//! HTTP transport with Server-Sent Events for real-time updates.
//! Enables Claude Desktop, Cursor, and other MCP clients to connect via HTTP.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const net = std.net;
const posix = std.posix;

/// SSE (Server-Sent Events) message
pub const SSEMessage = struct {
    event: []const u8,
    data: []const u8,
    id: ?[]const u8 = null,
    retry: ?u32 = null,
};

/// HTTP Server for MCP transport
pub const MCPServer = struct {
    allocator: std.mem.Allocator,
    address: []const u8 = "127.0.0.1",
    port: u16 = 8899,
    server_socket: ?posix.socket_t = null,
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator) MCPServer {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MCPServer) void {
        if (self.server_socket) |sock| {
            posix.close(sock);
        }
    }

    /// Start the HTTP server
    pub fn start(self: *MCPServer) !void {
        // Create TCP socket
        const sock = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, posix.IPPROTO.TCP);
        errdefer posix.close(sock);

        // Set socket options
        try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try posix.setsockopt(sock, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));

        // Bind to address
        const sockaddr = try std.net.Address.parseIp4(self.address, self.port);
        try posix.bind(sock, &sockaddr.any, sockaddr.getOsSockLen());

        // Listen
        try posix.listen(sock, 128);

        self.server_socket = sock;
        self.running = true;

        std.debug.print("TRINITY MCP Server v2.1 listening on http://{s}:{d}\n", .{ self.address, self.port });
        std.debug.print("SSE endpoint: http://{s}:{d}/sse\n", .{ self.address, self.port });
        std.debug.print("MCP endpoint: http://{s}:{d}/mcp\n", .{ self.address, self.port });
    }

    /// Accept incoming connection
    pub fn accept(self: *MCPServer) !Connection {
        if (self.server_socket == null) return error.ServerNotStarted;

        var addr: std.net.Address = undefined;
        var addr_len: posix.socklen_t = @sizeOf(std.net.Address);
        const sock = try posix.accept(self.server_socket.?, &addr.any, &addr_len);

        return Connection{
            .allocator = self.allocator,
            .socket = sock,
            .address = addr,
        };
    }
};

/// HTTP connection
pub const Connection = struct {
    allocator: std.mem.Allocator,
    socket: posix.socket_t,
    address: std.net.Address,

    pub fn deinit(self: *Connection) void {
        posix.close(self.socket);
    }

    /// Read HTTP request
    pub fn readRequest(self: *Connection) !Request {
        var buffer: [8192]u8 = undefined;
        var n: usize = 0;

        // Read until \r\n\r\n
        while (n < buffer.len) {
            const bytes_read = posix.read(self.socket, buffer[n..]) catch |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(10 * std.time.ns_per_ms);
                    continue;
                }
                return err;
            };

            if (bytes_read == 0) return error.ConnectionClosed;
            n += bytes_read;

            // Check for end of headers
            if (n >= 4 and std.mem.eql(u8, buffer[n - 4 .. n], "\r\n\r\n")) {
                break;
            }
        }

        return parseRequest(self.allocator, buffer[0..n]) catch |err| {
            std.debug.print("Failed to parse request: {}\n", .{@errorName(err)});
            return err;
        };
    }

    /// Write HTTP response
    pub fn writeResponse(self: *Connection, status: u16, headers: []const u8, body: []const u8) !void {
        var buffer: [1024]u8 = undefined;

        // Status line
        const status_line = try std.fmt.bufPrint(&buffer, "HTTP/1.1 {d} {s}\r\n", .{ status, getStatusText(status) });
        try self.writeAll(status_line);

        // Headers
        try self.writeAll(headers);
        try self.writeAll("\r\n");

        // Body
        try self.writeAll(body);
    }

    /// Write SSE message
    pub fn writeSSE(self: *Connection, msg: SSEMessage) !void {
        if (msg.id) |id| {
            try self.writeAll("id: ");
            try self.writeAll(id);
            try self.writeAll("\r\n");
        }

        if (msg.event) |event| {
            try self.writeAll("event: ");
            try self.writeAll(event);
            try self.writeAll("\r\n");
        }

        if (msg.retry) |retry| {
            const retry_str = try std.fmt.allocPrint(self.allocator, "retry: {d}\r\n", .{retry});
            defer self.allocator.free(retry_str);
            try self.writeAll(retry_str);
        }

        try self.writeAll("data: ");
        try self.writeAll(msg.data);
        try self.writeAll("\r\n\r\n");
    }

    fn writeAll(self: *Connection, data: []const u8) !void {
        var offset: usize = 0;
        while (offset < data.len) {
            const written = posix.write(self.socket, data[offset..]) catch |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(10 * std.time.ns_per_ms);
                    continue;
                }
                return err;
            };
            offset += written;
        }
    }
};

/// HTTP Request
pub const Request = struct {
    method: []const u8,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn deinit(self: *Request, allocator: std.mem.Allocator) void {
        self.headers.deinit();
        if (self.body.len > 0) {
            allocator.free(self.body);
        }
    }
};

/// Parse HTTP request
fn parseRequest(allocator: std.mem.Allocator, data: []const u8) !Request {
    var lines = std.mem.splitSequence(u8, data, "\r\n");

    // Request line
    const request_line = lines.first() orelse return error.MalformedRequest;
    var request_parts = std.mem.splitSequence(u8, request_line, " ");

    const method = request_parts.first() orelse return error.MalformedRequest;
    _ = request_parts.next(); // Skip the path (or handle it)
    const path_with_query = request_parts.next() orelse return error.MalformedRequest;

    // Parse path (remove query string if present)
    const path = if (std.mem.indexOf(u8, path_with_query, "?")) |idx|
        path_with_query[0..idx]
    else
        path_with_query;

    var headers = std.StringHashMap([]const u8).init(allocator);

    // Parse headers
    while (lines.next()) |line| {
        if (line.len == 0) break; // End of headers

        if (std.mem.indexOf(u8, line, ":")) |colon_idx| {
            const key = line[0..colon_idx];
            var value = line[colon_idx + 1 ..];
            // Trim leading space
            if (value.len > 0 and value[0] == ' ') value = value[1..];
            try headers.put(key, try allocator.dupe(u8, value));
        }
    }

    return Request{
        .method = try allocator.dupe(u8, method),
        .path = try allocator.dupe(u8, path),
        .headers = headers,
        .body = &.{},
    };
}

/// Get HTTP status text
fn getStatusText(status: u16) []const u8 {
    return switch (status) {
        100 => "Continue",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        204 => "No Content",
        400 => "Bad Request",
        404 => "Not Found",
        500 => "Internal Server Error",
        503 => "Service Unavailable",
        else => "Unknown",
    };
}

/// Route handler type
pub const RouteHandler = *const fn (conn: *Connection, req: Request) anyerror!void;

/// HTTP Router
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.StringHashMap(RouteHandler),

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .routes = std.StringHashMap(RouteHandler).init(allocator),
        };
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit();
    }

    pub fn addRoute(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.routes.put(path, handler);
    }

    pub fn handle(self: *Router, conn: *Connection, req: Request) !bool {
        if (self.routes.get(req.path)) |handler| {
            try handler(conn, req);
            return true;
        }
        return false;
    }
};

/// SSE Keep-alive message
pub fn sseKeepAlive(allocator: std.mem.Allocator) !SSEMessage {
    return .{
        .event = "keepalive",
        .data = ":ping",
        .id = try allocator.dupe(u8, "keepalive"),
        .retry = 5000,
    };
}

/// Create SSE response headers
pub fn sseHeaders(allocator: std.mem.Allocator) ![]const u8 {
    return try allocator.dupe(u8,
        \\Content-Type: text/event-stream
        \\Cache-Control: no-cache
        \\Connection: keep-alive
        \\Access-Control-Allow-Origin: *
    );
}
