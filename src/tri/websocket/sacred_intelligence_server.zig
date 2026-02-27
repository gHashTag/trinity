//! Sacred Intelligence WebSocket Server
//!
//! Real-time dashboard updates for sacred intelligence metrics,
//! patches, gematria calculations, and evolution progress.

const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

/// Message types for WebSocket communication
pub const MessageType = enum {
    METRICS,
    PATCH,
    GEMATRIA,
    EVOLUTION,
    CONSTANT,
    ERROR,
};

/// WebSocket message structure
pub const WSMessage = struct {
    type: MessageType,
    timestamp: i64,
    data: []const u8,

    /// Serialize message to JSON
    pub fn toJson(msg: WSMessage, allocator: Allocator) ![]u8 {
        const type_str = switch (msg.type) {
            .METRICS => "METRICS",
            .PATCH => "PATCH",
            .GEMATRIA => "GEMATRIA",
            .EVOLUTION => "EVOLUTION",
            .CONSTANT => "CONSTANT",
            .ERROR => "ERROR",
        };

        return std.fmt.allocPrint(
            allocator,
            "{{\"type\":\"{s}\",\"timestamp\":{d},\"data\":{s}}}",
            .{ type_str, msg.timestamp, msg.data },
        );
    }
};

/// Sacred intelligence metrics
pub const SacredMetrics = struct {
    total_commands: u64 = 0,
    sacred_analyses: u64 = 0,
    patches_applied: u64 = 0,
    patches_pending: u64 = 0,
    patches_rolled_back: u64 = 0,
    active_evolutions: u32 = 0,
    symbols_indexed: u32 = 0,
    sacred_percentage: f64 = 0.0,
    trinity_alignment: f64 = 0.0,

    /// Serialize metrics to JSON
    pub fn toJson(metrics: SacredMetrics, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{{\"total_commands\":{d},\"sacred_analyses\":{d},\"patches_applied\":{d},\"patches_pending\":{d},\"patches_rolled_back\":{d},\"active_evolutions\":{d},\"symbols_indexed\":{d},\"sacred_percentage\":{d:.2},\"trinity_alignment\":{d:.2}}}",
            .{
                metrics.total_commands,
                metrics.sacred_analyses,
                metrics.patches_applied,
                metrics.patches_pending,
                metrics.patches_rolled_back,
                metrics.active_evolutions,
                metrics.symbols_indexed,
                metrics.sacred_percentage,
                metrics.trinity_alignment,
            },
        );
    }
};

/// Auto-code patch information
pub const AutoCodePatch = struct {
    id: []const u8,
    file: []const u8,
    line: u32,
    description: []const u8,
    status: PatchStatus,
    sacred_score: f64,
    applied_at: i64,

    pub const PatchStatus = enum {
        PENDING,
        APPLIED,
        ROLLED_BACK,
        FAILED,
    };

    /// Serialize patch to JSON
    pub fn toJson(patch: AutoCodePatch, allocator: Allocator) ![]u8 {
        const status_str = switch (patch.status) {
            .PENDING => "PENDING",
            .APPLIED => "APPLIED",
            .ROLLED_BACK => "ROLLED_BACK",
            .FAILED => "FAILED",
        };

        return std.fmt.allocPrint(
            allocator,
            "{{\"id\":\"{s}\",\"file\":\"{s}\",\"line\":{d},\"description\":\"{s}\",\"status\":\"{s}\",\"sacred_score\":{d:.2},\"applied_at\":{d}}}",
            .{
                patch.id,
                patch.file,
                patch.line,
                patch.description,
                status_str,
                patch.sacred_score,
                patch.applied_at,
            },
        );
    }
};

/// Multi-language gematria result
pub const MultiLanguageGematria = struct {
    input: []const u8,
    results: []const GematriaResult,

    pub const GematriaResult = struct {
        language: []const u8,
        value: u64,
        is_sacred: bool,
        matches: []const []const u8,
    };

    /// Serialize gematria to JSON
    pub fn toJson(gem: MultiLanguageGematria, allocator: Allocator) ![]u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "{\"input\":\"");
        try buffer.appendSlice(allocator, gem.input);
        try buffer.appendSlice(allocator, "\",\"results\":[");

        for (gem.results, 0..) |result, i| {
            if (i > 0) try buffer.append(allocator, ',');
            try buffer.writer().print("{{\"language\":\"{s}\",\"value\":{d},\"is_sacred\":{},\"matches\":[", .{
                result.language, result.value, result.is_sacred,
            });

            for (result.matches, 0..) |match, j| {
                if (j > 0) try buffer.append(allocator, ',');
                try buffer.writer().print("\"{s}\"", .{match});
            }

            try buffer.appendSlice(allocator, "]}");
        }

        try buffer.appendSlice(allocator, "]}");
        return buffer.toOwnedSlice(allocator);
    }
};

/// Evolution progress
pub const EvolutionProgress = struct {
    id: []const u8,
    generation: u32,
    fitness: f64,
    target_fitness: f64,
    status: EvolutionStatus,

    pub const EvolutionStatus = enum {
        RUNNING,
        CONVERGED,
        STALLED,
        FAILED,
    };

    /// Serialize evolution to JSON
    pub fn toJson(evol: EvolutionProgress, allocator: Allocator) ![]u8 {
        const status_str = switch (evol.status) {
            .RUNNING => "RUNNING",
            .CONVERGED => "CONVERGED",
            .STALLED => "STALLED",
            .FAILED => "FAILED",
        };

        return std.fmt.allocPrint(
            allocator,
            "{{\"id\":\"{s}\",\"generation\":{d},\"fitness\":{d:.4},\"target_fitness\":{d:.4},\"status\":\"{s}\"}}",
            .{
                evol.id,
                evol.generation,
                evol.fitness,
                evol.target_fitness,
                status_str,
            },
        );
    }
};

/// WebSocket client connection
pub const WSClient = struct {
    allocator: Allocator,
    stream: net.Stream,
    address: net.Address,
    connected: bool,

    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator, stream: net.Stream) WSClient {
        return .{
            .allocator = allocator,
            .stream = stream,
            .address = stream.address catch unreachable,
            .connected = true,
            .mutex = std.Thread.Mutex{},
        };
    }

    /// Send message to this client
    pub fn send(client: *WSClient, data: []const u8) !void {
        client.mutex.lock();
        defer client.mutex.unlock();

        if (!client.connected) return error.Disconnected;

        // Create WebSocket frame
        var frame = std.ArrayList(u8){};
        defer frame.deinit(client.allocator);

        // FIN + text frame
        try frame.append(client.allocator, 0x81);

        // Payload length
        const len = data.len;
        if (len < 126) {
            try frame.append(client.allocator, @intCast(len | 0x80));
        } else if (len < 65536) {
            try frame.append(client.allocator, 126 | 0x80);
            try frame.append(client.allocator, @intCast((len >> 8) & 0xFF));
            try frame.append(client.allocator, @intCast(len & 0xFF));
        } else {
            try frame.append(client.allocator, 127 | 0x80);
            var i: u4 = 0;
            while (i < 8) : (i += 1) {
                try frame.append(client.allocator, @intCast((len >> (8 * (7 - i))) & 0xFF));
            }
        }

        // Masking key (server -> client is not masked, but we include for compatibility)
        try frame.append(client.allocator, 0);
        try frame.append(client.allocator, 0);
        try frame.append(client.allocator, 0);
        try frame.append(client.allocator, 0);

        // Payload
        try frame.appendSlice(client.allocator, data);

        _ = try client.stream.writeAll(frame.items);
    }

    /// Close connection
    pub fn close(client: *WSClient) !void {
        client.mutex.lock();
        defer client.mutex.unlock();

        if (!client.connected) return;

        // Send close frame
        const close_frame = [_]u8{ 0x88, 0x00 }; // FIN + close, no payload
        _ = try client.stream.writeAll(&close_frame);

        client.stream.close();
        client.connected = false;
    }
};

/// WebSocket server for sacred intelligence updates
pub const WSServer = struct {
    allocator: Allocator,
    address: []const u8,
    port: u16,
    running: bool,
    server: ?net.Server,
    clients: std.ArrayList(*WSClient),
    metrics: SacredMetrics,
    mutex: std.Thread.Mutex,
    listener_thread: ?Thread,

    /// Initialize WebSocket server
    pub fn init(allocator: Allocator, address: []const u8, port: u16) !WSServer {
        return .{
            .allocator = allocator,
            .address = try allocator.dupe(u8, address),
            .port = port,
            .running = false,
            .server = null,
            .clients = std.ArrayList(*WSClient){},
            .metrics = SacredMetrics{},
            .mutex = std.Thread.Mutex{},
            .listener_thread = null,
        };
    }

    /// Start the server
    pub fn start(server: *WSServer) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        if (server.running) return error.AlreadyRunning;

        // Parse address
        const listen_addr = try std.net.Address.parseIp(server.address, server.port);

        // Create server
        server.server = try listen_addr.listen(.{
            .reuse_address = true,
            .reuse_port = true,
        });

        server.running = true;

        // Start listener thread
        server.listener_thread = try Thread.spawn(.{}, listenerLoop, .{server});
    }

    /// Stop the server
    pub fn stop(server: *WSServer) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        if (!server.running) return;

        server.running = false;

        // Close all clients
        for (server.clients.items) |client| {
            client.close() catch {};
            server.allocator.destroy(client);
        }
        server.clients.clearRetainingCapacity();

        // Close server
        if (server.server) |*s| {
            s.close();
            server.server = null;
        }

        // Wait for listener thread
        if (server.listener_thread) |thread| {
            thread.join();
            server.listener_thread = null;
        }
    }

    /// Listener loop for accepting connections
    fn listenerLoop(server: *WSServer) void {
        const stdout = std.io.getStdOut().writer();

        while (server.running) {
            if (server.server) |*srv| {
                // Accept connection with timeout
                const stream = srv.accept() catch |err| {
                    if (server.running) {
                        stdout.print("Accept error: {}\n", .{err}) catch {};
                    }
                    std.time.sleep(100 * std.time.ns_per_ms);
                    continue;
                };

                // Handle connection in new thread
                const client_ptr = server.allocator.create(WSClient) catch {
                    stream.close();
                    continue;
                };
                client_ptr.* = WSClient.init(server.allocator, stream);

                server.mutex.lock();
                server.clients.append(server.allocator, client_ptr) catch {
                    server.allocator.destroy(client_ptr);
                    stream.close();
                    server.mutex.unlock();
                    continue;
                };
                server.mutex.unlock();

                stdout.print("Client connected: {}\n", .{client_ptr.address}) catch {};

                // Spawn handler thread
                _ = Thread.spawn(.{}, handleConnection, .{ server, client_ptr }) catch |err| {
                    stdout.print("Failed to spawn handler: {}\n", .{err}) catch {};
                };
            }
        }
    }

    /// Handle WebSocket connection
    fn handleConnection(server: *WSServer, client: *WSClient) void {
        const stdout = std.io.getStdOut().writer();

        // Perform WebSocket handshake
        server.handshake(client) catch |err| {
            stdout.print("Handshake failed: {}\n", .{err}) catch {};
            client.close() catch {};
            return;
        };

        // Send initial metrics
        server.broadcastMetrics(server.metrics) catch {};

        // Handle messages (ping/pong)
        var buffer: [1024]u8 = undefined;
        while (client.connected and server.running) {
            const n = client.stream.read(&buffer) catch |err| {
                if (err != error.EndOfStream) {
                    stdout.print("Read error: {}\n", .{err}) catch {};
                }
                break;
            };

            if (n == 0) break;

            // Parse WebSocket frame
            if (n > 0) {
                const opcode = buffer[0] & 0x0F;
                if (opcode == 0x8) {
                    // Close frame
                    break;
                } else if (opcode == 0x9) {
                    // Ping frame - send pong
                    const pong_frame = [_]u8{ 0x8A, 0x00 };
                    _ = client.stream.writeAll(&pong_frame) catch break;
                }
            }
        }

        // Clean up
        client.close() catch {};

        server.mutex.lock();
        for (server.clients.items, 0..) |c, i| {
            if (c == client) {
                _ = server.clients.orderedRemove(i);
                break;
            }
        }
        server.mutex.unlock();

        server.allocator.destroy(client);
        stdout.print("Client disconnected\n", .{}) catch {};
    }

    /// Perform WebSocket handshake
    fn handshake(server: *WSServer, client: *WSClient) !void {
        _ = server;
        var buffer: [4096]u8 = undefined;

        // Read HTTP request
        const request = client.stream.read(&buffer) catch return error.HandshakeFailed;
        if (request == 0) return error.HandshakeFailed;

        const request_str = buffer[0..request];

        // Check for WebSocket upgrade request
        if (std.mem.indexOf(u8, request_str, "Upgrade: websocket") == null) {
            return error.NotAWebSocket;
        }

        // Extract Sec-WebSocket-Key
        const key_line = std.mem.indexOf(u8, request_str, "Sec-WebSocket-Key:") orelse return error.MissingWebSocketKey;
        const key_start = key_line + "Sec-WebSocket-Key:".len;
        const key_end = std.mem.indexOfScalar(u8, request_str[key_start..], '\r') orelse return error.InvalidWebSocketKey;
        const key = std.mem.trim(u8, request_str[key_start..][0..key_end], " \r\n");

        // Create accept key
        const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        const concat = try std.fmt.allocPrint(client.allocator, "{s}{s}", .{ key, magic });
        defer client.allocator.free(concat);

        const hash = std.crypto.hash.Sha1.hash(concat);
        const accept_key = std.base64.standard.encodeWithAlphabet(
            &hash,
            std.base64.standard.alphabet_chars,
        );

        // Send handshake response
        const response = try std.fmt.allocPrint(
            client.allocator,
            "HTTP/1.1 101 Switching Protocols\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Accept: {s}\r\n" ++
                "\r\n",
            .{accept_key},
        );
        defer client.allocator.free(response);

        _ = try client.stream.writeAll(response);
    }

    /// Broadcast metrics to all clients
    pub fn broadcastMetrics(server: *WSServer, metrics: SacredMetrics) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        server.metrics = metrics;

        const data = try metrics.toJson(server.allocator);
        defer server.allocator.free(data);

        const msg = WSMessage{
            .type = .METRICS,
            .timestamp = std.time.timestamp(),
            .data = data,
        };

        const json = try msg.toJson(server.allocator);
        defer server.allocator.free(json);

        for (server.clients.items) |client| {
            client.send(json) catch {};
        }
    }

    /// Broadcast patch to all clients
    pub fn broadcastPatch(server: *WSServer, patch: AutoCodePatch) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        const data = try patch.toJson(server.allocator);
        defer server.allocator.free(data);

        const msg = WSMessage{
            .type = .PATCH,
            .timestamp = std.time.timestamp(),
            .data = data,
        };

        const json = try msg.toJson(server.allocator);
        defer server.allocator.free(json);

        for (server.clients.items) |client| {
            client.send(json) catch {};
        }
    }

    /// Broadcast gematria result to all clients
    pub fn broadcastGematria(server: *WSServer, gem: MultiLanguageGematria) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        const data = try gem.toJson(server.allocator);
        defer server.allocator.free(data);

        const msg = WSMessage{
            .type = .GEMATRIA,
            .timestamp = std.time.timestamp(),
            .data = data,
        };

        const json = try msg.toJson(server.allocator);
        defer server.allocator.free(json);

        for (server.clients.items) |client| {
            client.send(json) catch {};
        }
    }

    /// Broadcast evolution progress to all clients
    pub fn broadcastEvolution(server: *WSServer, evol: EvolutionProgress) !void {
        server.mutex.lock();
        defer server.mutex.unlock();

        const data = try evol.toJson(server.allocator);
        defer server.allocator.free(data);

        const msg = WSMessage{
            .type = .EVOLUTION,
            .timestamp = std.time.timestamp(),
            .data = data,
        };

        const json = try msg.toJson(server.allocator);
        defer server.allocator.free(json);

        for (server.clients.items) |client| {
            client.send(json) catch {};
        }
    }

    /// Get current number of connected clients
    pub fn getClientCount(server: *WSServer) usize {
        server.mutex.lock();
        defer server.mutex.unlock();
        return server.clients.items.len;
    }
};

// ========================
// Tests
// ========================

const testing = std.testing;

test "SacredMetrics JSON serialization" {
    const metrics = SacredMetrics{
        .total_commands = 1234,
        .sacred_analyses = 567,
        .patches_applied = 42,
        .patches_pending = 5,
        .patches_rolled_back = 1,
        .active_evolutions = 2,
        .symbols_indexed = 50000,
        .sacred_percentage = 95.5,
        .trinity_alignment = 99.99,
    };

    const json = try metrics.toJson(testing.allocator);
    defer testing.allocator.free(json);

    try expectStringContains(json, "total_commands");
    try expectStringContains(json, "1234");
    try expectStringContains(json, "95.50");
    try expectStringContains(json, "99.99");
}

test "AutoCodePatch JSON serialization" {
    const patch = AutoCodePatch{
        .id = "patch-001",
        .file = "test.zig",
        .line = 42,
        .description = "Fix sacred constant calculation",
        .status = .APPLIED,
        .sacred_score = 99.5,
        .applied_at = 1740608400,
    };

    const json = try patch.toJson(testing.allocator);
    defer testing.allocator.free(json);

    try expectStringContains(json, "patch-001");
    try expectStringContains(json, "test.zig");
    try expectStringContains(json, "APPLIED");
    try expectStringContains(json, "99.50");
}

test "WSMessage JSON serialization" {
    const msg = WSMessage{
        .type = .METRICS,
        .timestamp = 1740608400,
        .data = "{\"test\": true}",
    };

    const json = try msg.toJson(testing.allocator);
    defer testing.allocator.free(json);

    try expectStringContains(json, "METRICS");
    try expectStringContains(json, "1740608400");
    try expectStringContains(json, "test");
}

test "WSServer initialization" {
    const server = try WSServer.init(testing.allocator, "127.0.0.1", 8080);
    defer {
        testing.allocator.free(server.address);
        if (server.listener_thread) |t| t.join();
    }

    try testing.expectEqualStrings("127.0.0.1", server.address);
    try testing.expectEqual(@as(u16, 8080), server.port);
    try testing.expect(!server.running);
    try testing.expectEqual(@as(usize, 0), server.clients.items.len);
}

test "WSServer getClientCount" {
    var server = try WSServer.init(testing.allocator, "127.0.0.1", 8081);
    defer {
        testing.allocator.free(server.address);
        if (server.listener_thread) |t| t.join();
    }

    const count = server.getClientCount();
    try testing.expectEqual(@as(usize, 0), count);
}

test "SacredMetrics default values" {
    const metrics = SacredMetrics{};

    try testing.expectEqual(@as(u64, 0), metrics.total_commands);
    try testing.expectEqual(@as(u64, 0), metrics.sacred_analyses);
    try testing.expectEqual(@as(u64, 0), metrics.patches_applied);
    try testing.expectEqual(@as(u32, 0), metrics.active_evolutions);
    try testing.expectEqual(@as(f64, 0.0), metrics.sacred_percentage);
}

fn expectStringContains(haystack: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        std.debug.print("\nExpected to find '{s}' in:\n{s}\n", .{ needle, haystack });
        return error.StringNotFound;
    }
}
