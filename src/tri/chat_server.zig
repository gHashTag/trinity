// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT HTTP SERVER v2.4
// POST /chat — Hybrid Chat endpoint for Cosmic UI
// POST /chat/clear — Clear conversation context
// GET  /health — Health check
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const tvc = @import("tvc_corpus");

const Allocator = std.mem.Allocator;

pub const ChatServer = struct {
    allocator: Allocator,
    port: u16,
    chat_engine: ?igla_hybrid_chat.IglaHybridChat,
    corpus: ?*tvc.TVCCorpus,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) Self {
        return Self{
            .allocator = allocator,
            .port = port,
            .chat_engine = null,
            .corpus = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.chat_engine != null) {
            self.chat_engine.?.deinit();
        }
        if (self.corpus) |c| {
            self.allocator.destroy(c);
        }
    }

    /// Lazy-init the IglaHybridChat engine on first request
    fn ensureEngine(self: *Self) !*igla_hybrid_chat.IglaHybridChat {
        if (self.chat_engine != null) {
            return &self.chat_engine.?;
        }

        // Create TVC corpus
        const corpus = try self.allocator.create(tvc.TVCCorpus);
        corpus.* = tvc.TVCCorpus.init();
        self.corpus = corpus;

        // Create hybrid chat engine with env API keys
        var config = igla_hybrid_chat.HybridConfig{};

        // Read API keys from environment
        config.groq_api_key = std.posix.getenv("GROQ_API_KEY");
        config.claude_api_key = std.posix.getenv("ANTHROPIC_API_KEY");
        config.openai_api_key = std.posix.getenv("OPENAI_API_KEY");
        config.enable_context = true;
        config.system_prompt = "You are Trinity, a helpful AI assistant with multi-modal capabilities. Be concise and insightful.";

        self.chat_engine = try igla_hybrid_chat.IglaHybridChat.initWithConfig(self.allocator, null, config);
        self.chat_engine.?.corpus = corpus;

        std.debug.print("[ChatServer] Engine initialized (context: ON, TVC: ON)\n", .{});
        return &self.chat_engine.?;
    }

    pub fn run(self: *Self) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         TRINITY CHAT SERVER v2.4                    ║\n", .{});
        std.debug.print("║         POST /chat | GET /health                    ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /chat       - Chat with Trinity (JSON)\n", .{});
        std.debug.print("  POST /chat/clear - Clear conversation context\n", .{});
        std.debug.print("  GET  /health     - Health check\n", .{});
        std.debug.print("  OPTIONS /*       - CORS preflight\n", .{});
        std.debug.print("\n", .{});

        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();

        std.debug.print("Server ready on http://0.0.0.0:{d}\n\n", .{self.port});

        while (true) {
            var connection = server.accept() catch |err| {
                std.debug.print("[ChatServer] Accept error: {}\n", .{err});
                continue;
            };

            self.handleConnection(&connection) catch |err| {
                std.debug.print("[ChatServer] Request error: {}\n", .{err});
            };

            connection.stream.close();
        }
    }

    fn handleConnection(self: *Self, connection: *std.net.Server.Connection) !void {
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
        for (request, 0..) |c, i| {
            if (i >= 3 and request[i - 3] == '\r' and request[i - 2] == '\n' and request[i - 1] == '\r' and c == '\n') {
                if (i + 1 < n) {
                    body = request[i + 1 ..];
                }
                break;
            }
        }

        std.debug.print("[ChatServer] {s} {s}\n", .{ method, path });

        // Route
        if (std.mem.eql(u8, method, "OPTIONS")) {
            try self.sendCors(connection);
        } else if (std.mem.startsWith(u8, path, "/health")) {
            try self.sendHealth(connection);
        } else if (std.mem.startsWith(u8, path, "/chat/clear")) {
            if (std.mem.eql(u8, method, "POST")) {
                try self.handleClearContext(connection);
            } else {
                try self.sendMethodNotAllowed(connection);
            }
        } else if (std.mem.startsWith(u8, path, "/chat")) {
            if (std.mem.eql(u8, method, "POST")) {
                try self.handleChat(connection, body);
            } else {
                try self.sendMethodNotAllowed(connection);
            }
        } else {
            try self.sendNotFound(connection);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn handleChat(self: *Self, connection: *std.net.Server.Connection, body: []const u8) !void {
        const start = std.time.microTimestamp();

        // Lazy-init engine
        const engine = self.ensureEngine() catch {
            try self.sendError(connection, "Failed to initialize chat engine");
            return;
        };

        // Extract "message" from JSON body
        const message = extractJsonString(body, "message") orelse {
            try self.sendError(connection, "Missing 'message' field in JSON body");
            return;
        };

        const image_path = extractJsonString(body, "image_path");
        const audio_path = extractJsonString(body, "audio_path");

        std.debug.print("[ChatServer] Message: {s}\n", .{message});

        // Route by modality
        const result = if (audio_path) |audio|
            engine.respondWithAudio(audio) catch |err| blk: {
                std.debug.print("[ChatServer] Audio error: {}\n", .{err});
                break :blk igla_hybrid_chat.HybridResponse{
                    .response = "Error processing audio",
                    .source = .Error,
                    .language = .English,
                    .confidence = 0.0,
                    .latency_us = 0,
                };
            }
        else if (image_path) |image|
            engine.respondWithImage(message, image) catch |err| blk: {
                std.debug.print("[ChatServer] Image error: {}\n", .{err});
                break :blk igla_hybrid_chat.HybridResponse{
                    .response = "Error processing image",
                    .source = .Error,
                    .language = .English,
                    .confidence = 0.0,
                    .latency_us = 0,
                };
            }
        else
            engine.respond(message) catch |err| blk: {
                std.debug.print("[ChatServer] Chat error: {}\n", .{err});
                break :blk igla_hybrid_chat.HybridResponse{
                    .response = "Error processing message",
                    .source = .Error,
                    .language = .English,
                    .confidence = 0.0,
                    .latency_us = 0,
                };
            };

        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        const source_name = @tagName(result.source);

        std.debug.print("[ChatServer] Source: {s} | Confidence: {d:.2} | Latency: {d}μs\n", .{ source_name, result.confidence, elapsed });

        // Build JSON response
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"response\":\"");
        // Escape response text
        for (result.response) |c| {
            switch (c) {
                '"' => try json.appendSlice(self.allocator, "\\\""),
                '\\' => try json.appendSlice(self.allocator, "\\\\"),
                '\n' => try json.appendSlice(self.allocator, "\\n"),
                '\r' => try json.appendSlice(self.allocator, "\\r"),
                '\t' => try json.appendSlice(self.allocator, "\\t"),
                else => try json.append(self.allocator, c),
            }
        }
        try json.appendSlice(self.allocator, "\",\"source\":\"");
        try json.appendSlice(self.allocator, source_name);

        // Confidence
        var conf_buf: [32]u8 = undefined;
        const conf_str = std.fmt.bufPrint(&conf_buf, "\",\"confidence\":{d:.4}", .{result.confidence}) catch "\",\"confidence\":0";
        try json.appendSlice(self.allocator, conf_str);

        // Latency
        var lat_buf: [32]u8 = undefined;
        const lat_str = std.fmt.bufPrint(&lat_buf, ",\"latency_us\":{d}", .{elapsed}) catch ",\"latency_us\":0";
        try json.appendSlice(self.allocator, lat_str);

        // v2.4: Tool name
        if (result.tool_name) |tn| {
            try json.appendSlice(self.allocator, ",\"tool_name\":\"");
            try json.appendSlice(self.allocator, tn);
            try json.appendSlice(self.allocator, "\"");
        } else {
            try json.appendSlice(self.allocator, ",\"tool_name\":null");
        }

        // v2.4: Reflection status
        try json.appendSlice(self.allocator, ",\"reflection\":\"");
        try json.appendSlice(self.allocator, result.reflection.getName());
        try json.appendSlice(self.allocator, "\"");

        // v2.4: Learned flag
        if (result.reflection.wasLearned()) {
            try json.appendSlice(self.allocator, ",\"learned\":true");
        } else {
            try json.appendSlice(self.allocator, ",\"learned\":false");
        }

        try json.appendSlice(self.allocator, "}");

        try self.sendJsonResponse(connection, json.items);
    }

    fn handleClearContext(self: *Self, connection: *std.net.Server.Connection) !void {
        if (self.chat_engine != null) {
            self.chat_engine.?.clearContext();
            std.debug.print("[ChatServer] Context cleared\n", .{});
        }
        try self.sendJsonResponse(connection, "{\"status\":\"cleared\"}");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HTTP HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn sendJsonResponse(self: *Self, connection: *std.net.Server.Connection, json_body: []const u8) !void {
        const header = std.fmt.allocPrint(self.allocator,
            "HTTP/1.1 200 OK\r\n" ++
                "Content-Type: application/json\r\n" ++
                "Access-Control-Allow-Origin: *\r\n" ++
                "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" ++
                "Access-Control-Allow-Headers: Content-Type\r\n" ++
                "Content-Length: {d}\r\n" ++
                "Connection: close\r\n\r\n",
            .{json_body.len},
        ) catch return;
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(json_body);
    }

    fn sendError(self: *Self, connection: *std.net.Server.Connection, message: []const u8) !void {
        const body = std.fmt.allocPrint(self.allocator, "{{\"error\":\"{s}\"}}", .{message}) catch return;
        defer self.allocator.free(body);

        const header = std.fmt.allocPrint(self.allocator,
            "HTTP/1.1 500 Internal Server Error\r\n" ++
                "Content-Type: application/json\r\n" ++
                "Access-Control-Allow-Origin: *\r\n" ++
                "Content-Length: {d}\r\n" ++
                "Connection: close\r\n\r\n",
            .{body.len},
        ) catch return;
        defer self.allocator.free(header);

        try connection.stream.writeAll(header);
        try connection.stream.writeAll(body);
    }

    fn sendHealth(self: *Self, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response =
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Content-Length: 15\r\n" ++
            "Connection: close\r\n\r\n" ++
            "{\"status\":\"ok\"}";
        try connection.stream.writeAll(response);
    }

    fn sendCors(self: *Self, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response =
            "HTTP/1.1 200 OK\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: Content-Type\r\n" ++
            "Content-Length: 0\r\n" ++
            "Connection: close\r\n\r\n";
        try connection.stream.writeAll(response);
    }

    fn sendNotFound(self: *Self, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response =
            "HTTP/1.1 404 Not Found\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: 20\r\n" ++
            "Connection: close\r\n\r\n" ++
            "{\"error\":\"Not Found\"}";
        try connection.stream.writeAll(response);
    }

    fn sendMethodNotAllowed(self: *Self, connection: *std.net.Server.Connection) !void {
        _ = self;
        const response =
            "HTTP/1.1 405 Method Not Allowed\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: 30\r\n" ++
            "Connection: close\r\n\r\n" ++
            "{\"error\":\"Method Not Allowed\"}";
        try connection.stream.writeAll(response);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract a string value from JSON body: "key":"value" or "key": "value"
fn extractJsonString(body: []const u8, key: []const u8) ?[]const u8 {
    // Search for "key" pattern
    var pos: usize = 0;
    while (pos + key.len + 3 < body.len) {
        if (body[pos] == '"') {
            const key_start = pos + 1;
            if (key_start + key.len < body.len and
                std.mem.eql(u8, body[key_start .. key_start + key.len], key) and
                body[key_start + key.len] == '"')
            {
                // Found key, skip to colon then value
                var vpos = key_start + key.len + 1;
                // Skip whitespace and colon
                while (vpos < body.len and (body[vpos] == ' ' or body[vpos] == ':' or body[vpos] == '\t')) {
                    vpos += 1;
                }
                // Check for null
                if (vpos + 4 <= body.len and std.mem.eql(u8, body[vpos .. vpos + 4], "null")) {
                    return null;
                }
                // Expect opening quote
                if (vpos < body.len and body[vpos] == '"') {
                    const val_start = vpos + 1;
                    var val_end = val_start;
                    var escaped = false;
                    while (val_end < body.len) {
                        if (escaped) {
                            escaped = false;
                            val_end += 1;
                            continue;
                        }
                        if (body[val_end] == '\\') {
                            escaped = true;
                            val_end += 1;
                            continue;
                        }
                        if (body[val_end] == '"') break;
                        val_end += 1;
                    }
                    return body[val_start..val_end];
                }
            }
        }
        pos += 1;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runChatServer(allocator: Allocator, port: u16) !void {
    var server = ChatServer.init(allocator, port);
    defer server.deinit();
    try server.run();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "extractJsonString basic" {
    const body = "{\"message\":\"hello world\",\"image_path\":null}";
    const msg = extractJsonString(body, "message");
    try std.testing.expect(msg != null);
    try std.testing.expect(std.mem.eql(u8, msg.?, "hello world"));

    const img = extractJsonString(body, "image_path");
    try std.testing.expect(img == null);
}

test "extractJsonString with spaces" {
    const body = "{ \"message\" : \"hi there\" }";
    const msg = extractJsonString(body, "message");
    try std.testing.expect(msg != null);
    try std.testing.expect(std.mem.eql(u8, msg.?, "hi there"));
}

test "extractJsonString missing key" {
    const body = "{\"message\":\"hello\"}";
    const missing = extractJsonString(body, "nonexistent");
    try std.testing.expect(missing == null);
}
