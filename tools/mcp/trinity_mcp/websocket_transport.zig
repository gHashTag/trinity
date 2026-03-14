// @origin(spec:websocket_transport.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// WEBSOCKET TRANSPORT FOR MCP SERVER
// RFC 6455 WebSocket protocol - Server-side implementation
// Adapted from src/vibeec/websocket.zig (client) for server use
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

pub const WebSocketError = error{
    ConnectionFailed,
    HandshakeFailed,
    InvalidFrame,
    ConnectionClosed,
    Timeout,
    OutOfMemory,
};

pub const Opcode = enum(u4) {
    continuation = 0,
    text = 1,
    binary = 2,
    close = 8,
    ping = 9,
    pong = 10,
};

pub const Frame = struct {
    fin: bool,
    opcode: Opcode,
    payload: []const u8,
    /// True if payload was allocated and must be freed by caller
    allocated: bool,
};

/// WebSocket Server for MCP protocol
pub const WebSocketServer = struct {
    allocator: Allocator,
    server_socket: ?std.posix.socket_t,
    port: u16,
    host: []const u8,
    on_message: *const fn (allocator: Allocator, payload: []const u8) anyerror![]const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16, on_message: *const fn (Allocator, []const u8) anyerror![]const u8) Self {
        return Self{
            .allocator = allocator,
            .server_socket = null,
            .port = port,
            .host = "0.0.0.0",
            .on_message = on_message,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.server_socket) |s| {
            std.posix.close(s);
        }
    }

    /// Start the WebSocket server
    pub fn run(self: *Self) !void {
        // Create TCP socket
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
        errdefer std.posix.close(socket);
        self.server_socket = socket;

        // Set socket options
        try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try std.posix.setsockopt(socket, std.posix.IPPROTO.TCP, std.posix.TCP.NODELAY, &std.mem.toBytes(@as(c_int, 1)));

        // Bind to address
        const address = std.net.Address.parseIp4(self.host, self.port) catch return WebSocketError.ConnectionFailed;
        try std.posix.bind(socket, &address.any, address.getOsSockLen());

        // Listen for connections
        try std.posix.listen(socket, 128);

        std.log.info("WebSocket MCP server listening on ws://{s}:{d}/ws", .{ self.host, self.port });

        // Accept loop
        while (true) {
            var client_address: std.net.Address = undefined;
            var client_address_len: std.posix.socklen_t = @sizeOf(std.net.Address);
            const client_socket = std.posix.accept(socket, &client_address.any, &client_address_len, 0) catch |err| {
                std.log.err("Accept failed: {}", .{err});
                continue;
            };

            // Handle connection in a new task/goroutine equivalent
            // For now, handle synchronously (can be made async later)
            self.handleConnection(client_socket) catch |err| {
                std.log.err("Connection handler error: {}", .{err});
            };
        }
    }

    /// Handle a single WebSocket connection
    fn handleConnection(self: *Self, client_socket: std.posix.socket_t) !void {
        defer std.posix.close(client_socket);

        std.log.info("New connection accepted", .{});

        // Perform WebSocket handshake
        if (!try self.performServerHandshake(client_socket)) {
            return;
        }

        std.log.info("WebSocket handshake successful", .{});

        // Message loop
        var buffer: [65536]u8 = undefined;
        while (true) {
            const n = std.posix.read(client_socket, &buffer) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.info("Client closed connection", .{});
                    return;
                }
                std.log.err("Read error: {}", .{err});
                return;
            };

            if (n == 0) {
                std.log.info("Connection closed by client", .{});
                return;
            }

            // Parse WebSocket frame
            const frame = self.parseFrame(buffer[0..n]) catch |err| {
                std.log.err("Frame parse error: {}", .{err});
                continue;
            };
            // Free allocated payload after processing (prevents memory leak on masked frames)
            defer if (frame.allocated) self.allocator.free(frame.payload);

            // Handle different opcodes
            switch (frame.opcode) {
                .text => {
                    // Process MCP message
                    const response = self.on_message(self.allocator, frame.payload) catch |err| {
                        std.log.err("Message handler error: {}", .{err});
                        // Send error response
                        const error_msg = try std.fmt.allocPrint(self.allocator, "{{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{{\"code\":-32603,\"message\":\"{s}\"}}}}", .{@errorName(err)});
                        defer self.allocator.free(error_msg);
                        try self.sendFrame(client_socket, .text, error_msg);
                        continue;
                    };
                    defer self.allocator.free(response);

                    // Send response
                    try self.sendFrame(client_socket, .text, response);
                },
                .binary => {
                    std.log.warn("Binary frames not supported", .{});
                },
                .ping => {
                    // Respond with pong
                    try self.sendFrame(client_socket, .pong, frame.payload);
                },
                .pong => {
                    // Ignore pong frames
                },
                .close => {
                    std.log.info("Close frame received", .{});
                    try self.sendFrame(client_socket, .close, "");
                    return;
                },
                else => {},
            }
        }
    }

    /// Perform server-side WebSocket handshake
    fn performServerHandshake(self: *Self, client_socket: std.posix.socket_t) !bool {
        var buffer: [2048]u8 = undefined;
        const n = std.posix.read(client_socket, &buffer) catch return false;

        const request = buffer[0..n];

        // Validate WebSocket upgrade request
        if (!std.mem.startsWith(u8, request, "GET ")) {
            return false;
        }

        // Extract Sec-WebSocket-Key
        const key_line = std.mem.indexOf(u8, request, "Sec-WebSocket-Key:") orelse return false;
        const key_start = key_line + 19; // "Sec-WebSocket-Key:".len
        const key_end = std.mem.indexOfScalarPos(u8, request, key_start, '\r') orelse return false;
        const client_key = std.mem.trim(u8, request[key_start..key_end], " \t");

        // Generate Sec-WebSocket-Accept
        const accept_key = try generateWebSocketAccept(self.allocator, client_key);
        defer self.allocator.free(accept_key);

        // Build 101 Switching Protocols response
        var response_buf: [512]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf,
            \\HTTP/1.1 101 Switching Protocols\r
            \\Upgrade: websocket\r
            \\Connection: Upgrade\r
            \\Sec-WebSocket-Accept: {s}\r
            \\Sec-WebSocket-Version: 13\r
            \\\r
        , .{accept_key}) catch return false;

        // Send response
        _ = try std.posix.write(client_socket, response);
        return true;
    }

    /// Parse incoming WebSocket frame
    fn parseFrame(self: *Self, data: []const u8) !Frame {
        if (data.len < 2) return WebSocketError.InvalidFrame;

        const byte0 = data[0];
        const byte1 = data[1];

        const fin = (byte0 & 0x80) != 0;
        const opcode = @as(Opcode, @enumFromInt(byte0 & 0x0F));
        const masked = (byte1 & 0x80) != 0;
        var payload_len: usize = byte1 & 0x7F;

        var offset: usize = 2;

        // Extended payload length
        if (payload_len == 126) {
            if (data.len < 4) return WebSocketError.InvalidFrame;
            payload_len = std.mem.readInt(u16, data[2..4], .big);
            offset = 4;
        } else if (payload_len == 127) {
            if (data.len < 10) return WebSocketError.InvalidFrame;
            payload_len = std.mem.readInt(u64, data[2..10], .big);
            offset = 10;
        }

        // Masking key (client frames must be masked)
        var masking_key: [4]u8 = undefined;
        if (masked) {
            if (data.len < offset + 4) return WebSocketError.InvalidFrame;
            @memcpy(masking_key[0..], data[offset .. offset + 4]);
            offset += 4;
        }

        // Payload
        if (data.len < offset + payload_len) return WebSocketError.InvalidFrame;
        const payload_data = data[offset .. offset + payload_len];

        // Unmask payload if needed
        var payload: []const u8 = payload_data;
        var allocated = false;
        if (masked) {
            const unmasked = try self.allocator.alloc(u8, payload_len);
            for (0..payload_len) |i| {
                unmasked[i] = payload_data[i] ^ masking_key[i % 4];
            }
            payload = unmasked;
            allocated = true;
        }

        return Frame{
            .fin = fin,
            .opcode = opcode,
            .payload = payload,
            .allocated = allocated,
        };
    }

    /// Send a WebSocket frame
    fn sendFrame(self: *Self, socket: std.posix.socket_t, opcode: Opcode, payload: []const u8) !void {
        _ = self;
        const payload_len = payload.len;
        var frame_buf: [65536 + 10]u8 = undefined;
        var offset: usize = 0;

        // Frame header
        frame_buf[0] = 0x80 | @as(u8, @intFromEnum(opcode)); // FIN + opcode
        offset += 1;

        // Payload length
        if (payload_len < 126) {
            frame_buf[offset] = @intCast(payload_len);
            offset += 1;
        } else if (payload_len < 65536) {
            frame_buf[offset] = 126;
            offset += 1;
            std.mem.writeInt(u16, frame_buf[offset..][0..2], @intCast(payload_len), .big);
            offset += 2;
        } else {
            frame_buf[offset] = 127;
            offset += 1;
            std.mem.writeInt(u64, frame_buf[offset..][0..8], payload_len, .big);
            offset += 8;
        }

        // Payload — bounds check to prevent buffer overflow
        if (offset + payload_len > frame_buf.len) return WebSocketError.InvalidFrame;
        @memcpy(frame_buf[offset .. offset + payload_len], payload);
        offset += payload_len;

        // Send frame
        _ = try std.posix.write(socket, frame_buf[0..offset]);
    }

    /// Generate Sec-WebSocket-Accept value
    fn generateWebSocketAccept(allocator: Allocator, client_key: []const u8) ![]const u8 {
        const magic_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

        // Concatenate client key + magic guid
        const combined = try std.fmt.allocPrint(allocator, "{s}{s}", .{ client_key, magic_guid });
        defer allocator.free(combined);

        // SHA-1 hash
        var hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(combined, &hash, .{});

        // Base64 encode
        const accept_key = try base64Encode(allocator, &hash);
        return accept_key;
    }
};

/// Simple base64 encoder
fn base64Encode(allocator: Allocator, data: []const u8) ![]const u8 {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    const output_len = ((data.len + 2) / 3) * 4;
    const result = try allocator.alloc(u8, output_len);

    var i: usize = 0;
    var out_idx: usize = 0;

    while (i + 3 <= data.len) : (i += 3) {
        const val = (@as(u32, data[i]) << 16) | (@as(u32, data[i + 1]) << 8) | data[i + 2];
        result[out_idx] = alphabet[(val >> 18) & 0x3F];
        result[out_idx + 1] = alphabet[(val >> 12) & 0x3F];
        result[out_idx + 2] = alphabet[(val >> 6) & 0x3F];
        result[out_idx + 3] = alphabet[val & 0x3F];
        out_idx += 4;
    }

    if (i < data.len) {
        const remaining = data.len - i;
        var val: u32 = @as(u32, data[i]) << 16;
        if (remaining == 2) {
            val |= @as(u32, data[i + 1]) << 8;
        }

        result[out_idx] = alphabet[(val >> 18) & 0x3F];
        result[out_idx + 1] = alphabet[(val >> 12) & 0x3F];
        result[out_idx + 2] = if (remaining == 2) alphabet[(val >> 6) & 0x3F] else '=';
        result[out_idx + 3] = '=';
    }

    return result;
}
