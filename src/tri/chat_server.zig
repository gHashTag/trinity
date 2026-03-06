// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT HTTP SERVER v3.0
// POST /chat             — Hybrid Chat endpoint for Cosmic UI
// POST /chat/clear       — Clear conversation context
// GET  /health           — Health check
// GET  /api/files        — Project file listing for Finder
// POST /api/compile      — VIBEE/Zig compilation for Editor
// GET  /api/pas/*        — PAS Daemon endpoints (v8.20)
// WS   /ws/pas           — PAS WebSocket (v8.21) — Real-time PAS updates
// GET  /api/chem/sacred  — Chemistry: molar mass + sacred fit (v11.0)
// GET  /api/chem/element — Chemistry: element info (v11.0)
// GET  /api/chem/balance — Chemistry: balance equation (v11.0)
// GET  /api/chem/predict — Chemistry: predict reaction products (v11.0)
// φ² + 1/φ² = 3 = TRINITY | TRI CHEM v11.0
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const tvc = @import("tvc_corpus");
const pas_orchestrator = @import("pas_orchestrator");
const sacred_formula = @import("math/formula.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// WEBSOCKET SERVER (v8.21)
// ═══════════════════════════════════════════════════════════════════════════════

const WS_OPCODE_CONTINUATION = 0x0;
const WS_OPCODE_TEXT = 0x1;
const WS_OPCODE_BINARY = 0x2;
const WS_OPCODE_CLOSE = 0x8;
const WS_OPCODE_PING = 0x9;
const WS_OPCODE_PONG = 0xA;

const WSFrameHeader = struct {
    fin: bool,
    opcode: u4,
    masked: bool,
    payload_len: u64,
};

const PasWsMessage = struct {
    type: []const u8,
    id: []const u8,
    priority: u8,
    rationale: []const u8,
    impact_estimate: f32,
};

pub const PasWebSocketServer = struct {
    clients: std.ArrayListUnmanaged(std.net.Stream),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .clients = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.clients.items) |client| {
            client.close();
        }
        self.clients.deinit(self.allocator);
    }

    /// Broadcast JSON message to all connected WebSocket clients
    pub fn broadcast(self: *Self, json: []const u8) !void {
        var i: usize = 0;
        while (i < self.clients.items.len) {
            const client = self.clients.items[i];
            if (self.sendWsFrame(client, json)) {
                i += 1;
            } else {
                // Remove disconnected client
                _ = self.clients.orderedRemove(i);
                client.close();
            }
        }
    }

    /// Send WebSocket TEXT frame to client (server-to-client, no masking)
    fn sendWsFrame(self: *Self, stream: std.net.Stream, payload: []const u8) bool {
        _ = self;
        var frame_buf: [16384]u8 = undefined;
        var pos: usize = 0;

        // First byte: FIN + opcode
        frame_buf[pos] = 0x80 | WS_OPCODE_TEXT;
        pos += 1;

        // Second byte: payload length (server-to-client = NOT masked)
        if (payload.len < 126) {
            frame_buf[pos] = @intCast(payload.len);
            pos += 1;
        } else if (payload.len < 65536) {
            frame_buf[pos] = 126;
            pos += 1;
            frame_buf[pos] = @intCast((payload.len >> 8) & 0xFF);
            pos += 1;
            frame_buf[pos] = @intCast(payload.len & 0xFF);
            pos += 1;
        } else {
            frame_buf[pos] = 127;
            pos += 1;
            inline for (0..8) |j| {
                frame_buf[pos] = @intCast((payload.len >> @intCast(56 - j * 8)) & 0xFF);
                pos += 1;
            }
        }

        // Copy payload
        @memcpy(frame_buf[pos .. pos + payload.len], payload);
        pos += payload.len;

        stream.writeAll(frame_buf[0..pos]) catch return false;
        return true;
    }

    /// Generate PAS recommendation JSON message
    pub fn generateRecommendation(
        self: *Self,
        allocator: Allocator,
        action: []const u8,
        priority: u8,
        rationale: []const u8,
    ) ![]const u8 {
        _ = self;
        const uuid = try generateUUID(allocator);
        defer allocator.free(uuid);

        return std.fmt.allocPrint(
            allocator,
            \\{{"type":"recommendation","id":"{s}","action":"{s}","priority":{d},"rationale":"{s}","timestamp":{d}}}
        ,
            .{ uuid, action, priority, rationale, std.time.timestamp() },
        );
    }

    /// Generate PAS task progress JSON message
    pub fn generateProgress(
        self: *Self,
        allocator: Allocator,
        task: []const u8,
        baseline: u32,
        pas: u32,
        attempts: u32,
        energy: f64,
    ) ![]const u8 {
        _ = self;
        return std.fmt.allocPrint(
            allocator,
            \\{{"type":"progress","task":"{s}","baseline":{d},"pas":{d},"attempts":{d},"energy":{d:.2},"timestamp":{d}}}
        ,
            .{ task, baseline, pas, attempts, energy, std.time.timestamp() },
        );
    }

    /// Generate PAS alert JSON message
    pub fn generateAlert(
        self: *Self,
        allocator: Allocator,
        level: []const u8,
        message: []const u8,
    ) ![]const u8 {
        _ = self;
        return std.fmt.allocPrint(
            allocator,
            \\{{"type":"alert","level":"{s}","message":"{s}","timestamp":{d}}}
        ,
            .{ level, message, std.time.timestamp() },
        );
    }
};

/// Simple UUID v4 generator
fn generateUUID(allocator: Allocator) ![]const u8 {
    const hex_chars = "0123456789abcdef";
    var uuid: [36]u8 = undefined;

    var i: usize = 0;
    var rand_buf: [16]u8 = undefined;
    std.crypto.random.bytes(&rand_buf);

    // Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    uuid[i] = hex_chars[(rand_buf[0] >> 4) & 0xF];
    uuid[i + 1] = hex_chars[rand_buf[0] & 0xF];
    uuid[i + 2] = hex_chars[(rand_buf[1] >> 4) & 0xF];
    uuid[i + 3] = hex_chars[rand_buf[1] & 0xF];
    uuid[i + 4] = hex_chars[(rand_buf[2] >> 4) & 0xF];
    uuid[i + 5] = hex_chars[rand_buf[2] & 0xF];
    uuid[i + 6] = hex_chars[(rand_buf[3] >> 4) & 0xF];
    uuid[i + 7] = hex_chars[rand_buf[3] & 0xF];
    i += 8;

    uuid[i] = '-';
    i += 1;

    uuid[i] = hex_chars[(rand_buf[4] >> 4) & 0xF];
    uuid[i + 1] = hex_chars[rand_buf[4] & 0xF];
    uuid[i + 2] = hex_chars[(rand_buf[5] >> 4) & 0xF];
    uuid[i + 3] = hex_chars[rand_buf[5] & 0xF];
    i += 4;

    uuid[i] = '-';
    i += 1;

    uuid[i] = '4'; // Version 4
    uuid[i + 1] = hex_chars[rand_buf[6] & 0xF];
    uuid[i + 2] = hex_chars[(rand_buf[7] >> 4) & 0xF];
    uuid[i + 3] = hex_chars[rand_buf[7] & 0xF];
    i += 4;

    uuid[i] = '-';
    i += 1;

    uuid[i] = hex_chars[((rand_buf[8] >> 4) & 0x3) | 0x8]; // Variant
    uuid[i + 1] = hex_chars[rand_buf[8] & 0xF];
    uuid[i + 2] = hex_chars[(rand_buf[9] >> 4) & 0xF];
    uuid[i + 3] = hex_chars[rand_buf[9] & 0xF];
    i += 4;

    uuid[i] = '-';
    i += 1;

    for (10..16) |j| {
        uuid[i] = hex_chars[(rand_buf[j] >> 4) & 0xF];
        uuid[i + 1] = hex_chars[rand_buf[j] & 0xF];
        i += 2;
    }

    return allocator.dupe(u8, &uuid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS (PAS v8.20)
// ═══════════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.6180339887498949; // Golden ratio
const PHI_SQ: f64 = 2.6180339887498949; // φ²
const PHI_INV_SQ: f64 = 0.3819660112501051; // 1/φ²
const TRINITY: f64 = 3.0; // φ² + 1/φ² = 3
const MU: f64 = 0.0382; // Mutation = 1/φ²/10
const CHI: f64 = 0.0618; // Crossover = 1/φ/10
const SIGMA: f64 = 1.618; // Selection = φ
const EPSILON: f64 = 0.333; // Elitism = 1/3
const LUCAS_10: u64 = 123; // L(10) = φ¹⁰ + 1/φ¹⁰
const PHOENIX: usize = 999; // Sacred rebirth number

const Allocator = std.mem.Allocator;

/// Recent query log entry for Mirror dashboard
const LogEntry = struct {
    timestamp: i64,
    source: []const u8,
    query_preview: [64]u8,
    query_len: usize,
    confidence: f32,
    latency_us: u64,
    learned: bool,
};

/// Ring buffer for recent query logs (last 20)
const MAX_LOG_ENTRIES = 20;

pub const ChatServer = struct {
    allocator: Allocator,
    port: u16,
    chat_engine: ?igla_hybrid_chat.IglaHybridChat,
    corpus: ?*tvc.TVCCorpus,
    startup_time: i64,
    log_ring: [MAX_LOG_ENTRIES]LogEntry,
    log_count: usize,
    log_index: usize,

    // PAS v8.20 state
    pas_active: bool,
    pas_analyses: usize,
    pas_energy: f64,
    pas_berry_phase: f64,

    // PAS v8.21 WebSocket server
    ws_server: PasWebSocketServer,

    // PAS v8.22 Orchestrator connection
    pas_orchestrator: pas_orchestrator.PasOrchestrator,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) Self {
        return Self{
            .allocator = allocator,
            .port = port,
            .chat_engine = null,
            .corpus = null,
            .startup_time = std.time.timestamp(),
            .log_ring = [_]LogEntry{LogEntry{
                .timestamp = 0,
                .source = "none",
                .query_preview = [_]u8{0} ** 64,
                .query_len = 0,
                .confidence = 0,
                .latency_us = 0,
                .learned = false,
            }} ** MAX_LOG_ENTRIES,
            .log_count = 0,
            .log_index = 0,
            // PAS v8.20 initialization
            .pas_active = false,
            .pas_analyses = 0,
            .pas_energy = 0.0,
            .pas_berry_phase = 0.0,
            // PAS v8.21 WebSocket server
            .ws_server = PasWebSocketServer.init(allocator),
            // PAS v8.22 Orchestrator
            .pas_orchestrator = pas_orchestrator.PasOrchestrator.init(allocator),
        };
    }

    /// Activate PAS daemon
    fn activatePas(self: *Self) void {
        if (!self.pas_active) {
            self.pas_active = true;
            std.debug.print("[ChatServer] PAS Daemon v8.20 activated\n", .{});
            std.debug.print("[ChatServer] φ² + 1/φ² = {d:.10} ≈ {d:.1}\n", .{ PHI_SQ + PHI_INV_SQ, TRINITY });
            std.debug.print("[ChatServer] μ = {d:.4} (1/φ²/10)\n", .{MU});
        }
    }

    fn addLogEntry(self: *Self, source: []const u8, query: []const u8, confidence: f32, latency_us: u64, learned: bool) void {
        var entry = &self.log_ring[self.log_index];
        entry.timestamp = std.time.timestamp();
        entry.source = source;
        const copy_len = @min(query.len, 64);
        @memcpy(entry.query_preview[0..copy_len], query[0..copy_len]);
        entry.query_len = copy_len;
        entry.confidence = confidence;
        entry.latency_us = latency_us;
        entry.learned = learned;
        self.log_index = (self.log_index + 1) % MAX_LOG_ENTRIES;
        if (self.log_count < MAX_LOG_ENTRIES) self.log_count += 1;
    }

    pub fn deinit(self: *Self) void {
        if (self.chat_engine != null) {
            self.chat_engine.?.deinit();
        }
        if (self.corpus) |c| {
            self.allocator.destroy(c);
        }
        // Cleanup WebSocket server (v8.21)
        self.ws_server.deinit();
    }

    /// Lazy-init the IglaHybridChat engine on first request
    fn ensureEngine(self: *Self) !*igla_hybrid_chat.IglaHybridChat {
        if (self.chat_engine != null) {
            return &self.chat_engine.?;
        }

        // Create TVC corpus
        const corpus = try self.allocator.create(tvc.TVCCorpus);
        corpus.initInPlace();
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
        std.debug.print("║         TRINITY CHAT SERVER v2.7                    ║\n", .{});
        std.debug.print("║  PAS FULL PRODUCTION v8.21 | φ²+1/φ²=3             ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /chat          - Chat with Trinity (JSON)\n", .{});
        std.debug.print("  POST /chat/clear    - Clear conversation context\n", .{});
        std.debug.print("  GET  /health        - Health check\n", .{});
        std.debug.print("  GET  /api/files     - Project file listing\n", .{});
        std.debug.print("  POST /api/compile   - VIBEE/Zig compilation\n", .{});
        std.debug.print("  GET  /api/pas/status - PAS daemon status (v8.20)\n", .{});
        std.debug.print("  GET  /api/pas/recs   - PAS recommendations (v8.20)\n", .{});
        std.debug.print("  GET  /api/pas/analyze- Current PAS analysis (v8.20)\n", .{});
        std.debug.print("  WS   /ws/pas        - PAS WebSocket (v8.21) Real-time\n", .{});
        std.debug.print("  OPTIONS /*          - CORS preflight\n", .{});
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
        } else if (std.mem.startsWith(u8, path, "/ws/pas")) {
            // WebSocket upgrade (v8.21)
            if (std.mem.eql(u8, method, "GET")) {
                try self.handleWebSocketUpgrade(connection, request);
            } else {
                try self.sendMethodNotAllowed(connection);
            }
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
        } else if (std.mem.startsWith(u8, path, "/diagnostic")) {
            try self.handleDiagnostic(connection);
        } else if (std.mem.startsWith(u8, path, "/api/ralph-status")) {
            try self.handleRalphStatus(connection, path);
        } else if (std.mem.startsWith(u8, path, "/api/files")) {
            try self.handleFileList(connection);
        } else if (std.mem.startsWith(u8, path, "/api/compile")) {
            if (std.mem.eql(u8, method, "POST")) {
                try self.handleCompile(connection, body);
            } else {
                try self.sendMethodNotAllowed(connection);
            }
        } else if (std.mem.startsWith(u8, path, "/api/pas/status")) {
            try self.handlePasStatus(connection);
        } else if (std.mem.startsWith(u8, path, "/api/pas/recs")) {
            try self.handlePasRecommendations(connection);
        } else if (std.mem.startsWith(u8, path, "/api/pas/analyze")) {
            try self.handlePasAnalyze(connection);
        } else if (std.mem.startsWith(u8, path, "/api/chem/predict")) {
            try self.handleChemPredict(connection, path);
        } else if (std.mem.startsWith(u8, path, "/api/chem/balance")) {
            try self.handleChemBalance(connection, path);
        } else if (std.mem.startsWith(u8, path, "/api/chem/element")) {
            try self.handleChemElement(connection, path);
        } else if (std.mem.startsWith(u8, path, "/api/chem/sacred")) {
            try self.handleChemSacred(connection, path);
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

        // Record to log ring buffer for Mirror dashboard
        self.addLogEntry(
            source_name,
            message,
            result.confidence,
            elapsed,
            result.reflection.wasLearned(),
        );

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
    // v2.5: FILE LIST & COMPILE HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// GET /api/files — Return project file listing for Finder panel
    fn handleFileList(self: *Self, connection: *std.net.Server.Connection) !void {
        std.debug.print("[ChatServer] Serving file list\n", .{});

        // Project file listing — curated list matching frontend FILE_INDEX
        // Each entry: {"path":"...","category":"...","icon":"...","color":"..."}
        const file_list =
            "[" ++
            // Core VSA
            "{\"path\":\"src/vsa.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/vm.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/hybrid.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/trinity.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/sdk.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/packed_trit.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/vsa.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/firebird/cli.zig\",\"category\":\"core\",\"icon\":\"\\ud83d\\udd25\",\"color\":\"#ff8800\"}," ++
            "{\"path\":\"src/firebird/depin.zig\",\"category\":\"core\",\"icon\":\"\\ud83d\\udd25\",\"color\":\"#ff8800\"}," ++
            "{\"path\":\"src/tvc/tvc_corpus.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"build.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/tri/main.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/tri/tri_commands.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/tri/tri_utils.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            "{\"path\":\"src/tri/chat_server.zig\",\"category\":\"core\",\"icon\":\"\\u25b2\",\"color\":\"#00ff88\"}," ++
            // VIBEE Compiler
            "{\"path\":\"src/vibeec/vibee_parser.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/zig_codegen.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/verilog_codegen.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/http_server.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/anthropic_client.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/http_client.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/igla_hybrid_chat.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            "{\"path\":\"src/vibeec/json_parser.zig\",\"category\":\"compiler\",\"icon\":\"\\u26a1\",\"color\":\"#ffd700\"}," ++
            // Trinity Node
            "{\"path\":\"src/trinity_node/network.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/storage.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/protocol.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/main.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/config.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/discovery.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/integration_test.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/reed_solomon.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/shard_manager.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/galois.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/proof_of_storage.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/token_staking.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/wal_disk.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/transaction_wal.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/parallel_saga.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/saga_coordinator.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/cross_shard_tx.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/dynamic_erasure.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            "{\"path\":\"src/trinity_node/prometheus_http.zig\",\"category\":\"node\",\"icon\":\"\\ud83c\\udf10\",\"color\":\"#00ccff\"}," ++
            // Specs
            "{\"path\":\"specs/tri/storage_network_v2_6.vibee\",\"category\":\"spec\",\"icon\":\"\\ud83d\\udccb\",\"color\":\"#aa66ff\"}," ++
            "{\"path\":\"specs/tri/storage_network_v2_5.vibee\",\"category\":\"spec\",\"icon\":\"\\ud83d\\udccb\",\"color\":\"#aa66ff\"}," ++
            "{\"path\":\"specs/tri/trinity_chat_v2.vibee\",\"category\":\"spec\",\"icon\":\"\\ud83d\\udccb\",\"color\":\"#aa66ff\"}," ++
            "{\"path\":\"specs/tri/trinity_chat_v2_3.vibee\",\"category\":\"spec\",\"icon\":\"\\ud83d\\udccb\",\"color\":\"#aa66ff\"}," ++
            // Web Frontend
            "{\"path\":\"website/src/pages/TrinityCanvas.tsx\",\"category\":\"web\",\"icon\":\"\\ud83c\\udf0a\",\"color\":\"#ff66aa\"}," ++
            "{\"path\":\"website/src/components/QuantumCanvas.tsx\",\"category\":\"web\",\"icon\":\"\\ud83c\\udf0a\",\"color\":\"#ff66aa\"}," ++
            "{\"path\":\"website/src/services/chatApi.ts\",\"category\":\"web\",\"icon\":\"\\ud83c\\udf0a\",\"color\":\"#ff66aa\"}," ++
            "{\"path\":\"website/src/main.tsx\",\"category\":\"web\",\"icon\":\"\\ud83c\\udf0a\",\"color\":\"#ff66aa\"}," ++
            // Documentation
            "{\"path\":\"CLAUDE.md\",\"category\":\"doc\",\"icon\":\"\\ud83d\\udcc4\",\"color\":\"#888\"}," ++
            "{\"path\":\"docsite/docs/research/trinity-storage-network-v2.6-report.md\",\"category\":\"doc\",\"icon\":\"\\ud83d\\udcc4\",\"color\":\"#888\"}," ++
            "{\"path\":\"docsite/docs/research/trinity_canvas_v2.3_report.md\",\"category\":\"doc\",\"icon\":\"\\ud83d\\udcc4\",\"color\":\"#888\"}" ++
            "]";

        try self.sendJsonResponse(connection, file_list);
    }

    /// GET /api/ralph-status?agent=N — Return internal Ralph autonomous state for agent N (0-3)
    fn handleRalphStatus(self: *Self, connection: *std.net.Server.Connection, path: []const u8) !void {
        // Parse ?agent=N from path (default to 0 = main worktree)
        const worktree_paths = [_][]const u8{
            "/Users/playra/trinity",
            "/Users/playra/trinity-w1",
            "/Users/playra/trinity-w2",
            "/Users/playra/trinity-w3",
        };
        const agent_idx: usize = blk: {
            if (std.mem.indexOf(u8, path, "agent=")) |idx| {
                const start = idx + 6;
                if (start < path.len and path[start] >= '0' and path[start] <= '3') {
                    break :blk path[start] - '0';
                }
            }
            break :blk 0;
        };
        const base_path = worktree_paths[@min(agent_idx, 3)];

        // Open worktree directory (absolute path)
        var base_dir = std.fs.openDirAbsolute(base_path, .{}) catch {
            try self.sendJsonResponse(connection, "{\"loop\":{\"status\":\"offline\"},\"circuit_breaker\":{\"state\":\"UNKNOWN\"},\"logs\":[],\"agent\":" ++ "0" ++ ",\"reachable\":false}");
            return;
        };
        defer base_dir.close();

        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"agent\":");
        var agent_buf: [4]u8 = undefined;
        _ = std.fmt.bufPrint(&agent_buf, "{d}", .{agent_idx}) catch {};
        const agent_str_len = std.mem.indexOfScalar(u8, &agent_buf, 0) orelse 1;
        try json.appendSlice(self.allocator, agent_buf[0..agent_str_len]);

        // 1. Read .ralph/logs/status.json
        const status_json = base_dir.readFileAlloc(self.allocator, ".ralph/logs/status.json", 4096) catch |err| s_blk: {
            std.debug.print("[ChatServer] Ralph agent {d} status read error: {}\n", .{ agent_idx, err });
            break :s_blk "{\"status\":\"offline\"}";
        };
        const status_is_fallback = std.mem.eql(u8, status_json, "{\"status\":\"offline\"}");
        defer if (!status_is_fallback) self.allocator.free(status_json);

        try json.appendSlice(self.allocator, ",\"reachable\":");
        try json.appendSlice(self.allocator, if (status_is_fallback) "false" else "true");
        try json.appendSlice(self.allocator, ",\"loop\":");
        try json.appendSlice(self.allocator, status_json);

        // 2. Read .ralph/internal/.circuit_breaker_state
        const cb_json = base_dir.readFileAlloc(self.allocator, ".ralph/internal/.circuit_breaker_state", 4096) catch |err| cb_blk: {
            std.debug.print("[ChatServer] Ralph agent {d} CB read error: {}\n", .{ agent_idx, err });
            break :cb_blk "{\"state\":\"UNKNOWN\"}";
        };
        const cb_is_fallback = std.mem.eql(u8, cb_json, "{\"state\":\"UNKNOWN\"}");
        defer if (!cb_is_fallback) self.allocator.free(cb_json);

        try json.appendSlice(self.allocator, ",\"circuit_breaker\":");
        try json.appendSlice(self.allocator, cb_json);

        // 3. Tail latest log
        try json.appendSlice(self.allocator, ",\"logs\":[");
        {
            var dir = base_dir.openDir(".ralph/logs", .{ .iterate = true }) catch null;
            if (dir) |*d| {
                defer d.close();
                var latest_time: i128 = 0;
                var latest_name: [128]u8 = undefined;
                var latest_len: usize = 0;
                var it = d.iterate();
                while (it.next() catch null) |entry| {
                    if (std.mem.startsWith(u8, entry.name, "claude_output_")) {
                        const stat = d.statFile(entry.name) catch continue;
                        if (stat.mtime > latest_time) {
                            latest_time = stat.mtime;
                            @memcpy(latest_name[0..entry.name.len], entry.name);
                            latest_len = entry.name.len;
                        }
                    }
                }

                if (latest_len > 0) {
                    const log_content = d.readFileAlloc(self.allocator, latest_name[0..latest_len], 16384) catch null;
                    if (log_content) |content| {
                        defer self.allocator.free(content);
                        var line_it = std.mem.splitBackwardsScalar(u8, content, '\n');
                        var count: usize = 0;
                        var lines_buf: [20][]const u8 = undefined;
                        while (line_it.next()) |line| {
                            if (line.len == 0) continue;
                            lines_buf[count] = line;
                            count += 1;
                            if (count >= 20) break;
                        }

                        var i: usize = 0;
                        while (i < count) : (i += 1) {
                            const line = lines_buf[count - 1 - i];
                            if (i > 0) try json.appendSlice(self.allocator, ",");
                            try json.appendSlice(self.allocator, "\"");
                            for (line) |c| {
                                switch (c) {
                                    '"' => try json.appendSlice(self.allocator, "\\\""),
                                    '\\' => try json.appendSlice(self.allocator, "\\\\"),
                                    else => if (c >= 32) try json.append(self.allocator, c) else try json.append(self.allocator, ' '),
                                }
                            }
                            try json.appendSlice(self.allocator, "\"");
                        }
                    }
                }
            }
        }
        try json.appendSlice(self.allocator, "]}");

        try self.sendJsonResponse(connection, json.items);
    }

    /// POST /api/compile — Compile VIBEE spec or analyze Zig code
    fn handleCompile(self: *Self, connection: *std.net.Server.Connection, body: []const u8) !void {
        const code = extractJsonString(body, "code") orelse {
            try self.sendError(connection, "Missing 'code' field in JSON body");
            return;
        };
        const language = extractJsonString(body, "language") orelse "vibee";

        std.debug.print("[ChatServer] Compile request: {s} ({d} bytes)\n", .{ language, code.len });

        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        if (std.mem.eql(u8, language, "vibee")) {
            // Parse VIBEE spec — deep analysis
            var name: []const u8 = "unknown";
            var version: []const u8 = "?";
            var lang: []const u8 = "?";
            var module: []const u8 = "?";
            var types: usize = 0;
            var fields: usize = 0;
            var behaviors: usize = 0;
            var lines_count: usize = 1;
            var has_name = false;
            var has_version = false;
            var in_types = false;
            var in_behaviors = false;

            // Line-by-line analysis
            var line_iter = std.mem.splitScalar(u8, code, '\n');
            while (line_iter.next()) |line| {
                lines_count += 1;
                const trimmed = std.mem.trim(u8, line, " \t\r");
                if (trimmed.len == 0 or trimmed[0] == '#') continue;

                // Top-level keys
                if (std.mem.startsWith(u8, trimmed, "name:")) {
                    name = std.mem.trim(u8, trimmed[5..], " \t");
                    has_name = true;
                    in_types = false;
                    in_behaviors = false;
                } else if (std.mem.startsWith(u8, trimmed, "version:")) {
                    const v = std.mem.trim(u8, trimmed[8..], " \t\"");
                    if (v.len > 0) version = v;
                    has_version = true;
                    in_types = false;
                    in_behaviors = false;
                } else if (std.mem.startsWith(u8, trimmed, "language:")) {
                    lang = std.mem.trim(u8, trimmed[9..], " \t");
                    in_types = false;
                    in_behaviors = false;
                } else if (std.mem.startsWith(u8, trimmed, "module:")) {
                    module = std.mem.trim(u8, trimmed[7..], " \t");
                    in_types = false;
                    in_behaviors = false;
                } else if (std.mem.eql(u8, trimmed, "types:")) {
                    in_types = true;
                    in_behaviors = false;
                } else if (std.mem.eql(u8, trimmed, "behaviors:")) {
                    in_behaviors = true;
                    in_types = false;
                } else if (in_types) {
                    // Count type definitions (2-space indent + name + colon)
                    if (line.len >= 3 and line[0] == ' ' and line[1] == ' ' and line[2] != ' ') {
                        if (std.mem.endsWith(u8, trimmed, ":") and !std.mem.eql(u8, trimmed, "fields:") and !std.mem.eql(u8, trimmed, "values:")) {
                            types += 1;
                        }
                    }
                    // Count fields (6-space indent)
                    if (line.len >= 7 and line[0] == ' ' and line[1] == ' ' and line[2] == ' ' and line[3] == ' ' and line[4] == ' ' and line[5] == ' ' and line[6] != ' ') {
                        if (std.mem.indexOf(u8, trimmed, ":") != null) {
                            fields += 1;
                        }
                    }
                } else if (in_behaviors) {
                    if (std.mem.startsWith(u8, trimmed, "- name:")) {
                        behaviors += 1;
                    }
                }
            }

            // Build response
            try json.appendSlice(self.allocator, "{\"success\":true,\"language\":\"vibee\",\"output\":\"");

            // VIBEE Compiler v2.5 output
            const output = std.fmt.allocPrint(
                self.allocator,
                "VIBEE Compiler v2.5 \\u2014 Real Parse\\n" ++
                    "\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\n" ++
                    "Spec:       {s} v{s}\\n" ++
                    "Language:   {s}\\n" ++
                    "Module:     {s}\\n" ++
                    "Types:      {d} defined\\n" ++
                    "Fields:     {d} total\\n" ++
                    "Behaviors:  {d} found\\n" ++
                    "Lines:      {d}\\n" ++
                    "\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\u2501\\n" ++
                    "Status:     {s}\\n" ++
                    "Output:     trinity/output/{s}.zig\\n" ++
                    "Target:     {s}",
                .{
                    name,
                    version,
                    lang,
                    module,
                    types,
                    fields,
                    behaviors,
                    lines_count,
                    if (has_name and has_version) "Parsed successfully" else "Warning: missing name or version",
                    module,
                    if (std.mem.eql(u8, lang, "varlog")) "Verilog (FPGA)" else "Zig (native)",
                },
            ) catch "Parse error";
            defer if (output.len > 0) self.allocator.free(output);
            try json.appendSlice(self.allocator, output);

            try json.appendSlice(self.allocator, "\"");

            // Metrics
            var mbuf: [64]u8 = undefined;
            const types_str = std.fmt.bufPrint(&mbuf, ",\"types\":{d}", .{types}) catch ",\"types\":0";
            try json.appendSlice(self.allocator, types_str);
            var mbuf2: [64]u8 = undefined;
            const beh_str = std.fmt.bufPrint(&mbuf2, ",\"behaviors\":{d}", .{behaviors}) catch ",\"behaviors\":0";
            try json.appendSlice(self.allocator, beh_str);
            var mbuf3: [64]u8 = undefined;
            const fields_str = std.fmt.bufPrint(&mbuf3, ",\"fields\":{d}", .{fields}) catch ",\"fields\":0";
            try json.appendSlice(self.allocator, fields_str);
            var mbuf4: [64]u8 = undefined;
            const lines_str = std.fmt.bufPrint(&mbuf4, ",\"lines\":{d}", .{lines_count}) catch ",\"lines\":0";
            try json.appendSlice(self.allocator, lines_str);

            try json.appendSlice(self.allocator, ",\"errors\":[]}");
        } else if (std.mem.eql(u8, language, "zig")) {
            // Zig code analysis — route through IglaHybridChat
            const engine = self.ensureEngine() catch {
                try json.appendSlice(self.allocator, "{\"success\":false,\"language\":\"zig\",\"output\":\"Engine initialization failed\",\"errors\":[\"Cannot initialize IglaHybridChat\"]}");
                try self.sendJsonResponse(connection, json.items);
                return;
            };

            const prompt_prefix = "Analyze this Zig code. List the functions, types, and any issues:\\n\\n";
            const analysis_query = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ prompt_prefix, code }) catch {
                try json.appendSlice(self.allocator, "{\"success\":false,\"language\":\"zig\",\"output\":\"Memory allocation failed\",\"errors\":[]}");
                try self.sendJsonResponse(connection, json.items);
                return;
            };
            defer self.allocator.free(analysis_query);

            const result = engine.respond(analysis_query) catch {
                try json.appendSlice(self.allocator, "{\"success\":true,\"language\":\"zig\",\"output\":\"Zig code received (");
                var sbuf: [32]u8 = undefined;
                const sz = std.fmt.bufPrint(&sbuf, "{d}", .{code.len}) catch "?";
                try json.appendSlice(self.allocator, sz);
                try json.appendSlice(self.allocator, " bytes). Backend analysis unavailable.\",\"errors\":[]}");
                try self.sendJsonResponse(connection, json.items);
                return;
            };

            try json.appendSlice(self.allocator, "{\"success\":true,\"language\":\"zig\",\"output\":\"");
            // Escape result response
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
            try json.appendSlice(self.allocator, "\",\"errors\":[]}");
        } else {
            // JavaScript or unknown — runs client-side
            try json.appendSlice(self.allocator, "{\"success\":true,\"language\":\"");
            try json.appendSlice(self.allocator, language);
            try json.appendSlice(self.allocator, "\",\"output\":\"JavaScript runs client-side in the browser.\",\"errors\":[]}");
        }

        try self.sendJsonResponse(connection, json.items);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HTTP HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn sendJsonResponse(self: *Self, connection: *std.net.Server.Connection, json_body: []const u8) !void {
        const header = std.fmt.allocPrint(
            self.allocator,
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

        const header = std.fmt.allocPrint(
            self.allocator,
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
        const now = std.time.timestamp();
        const uptime = now - self.startup_time;

        // Build JSON using ArrayList for flexibility
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"status\":\"ok\"");

        // Uptime
        var buf: [64]u8 = undefined;
        const uptime_str = std.fmt.bufPrint(&buf, ",\"uptime_s\":{d}", .{uptime}) catch ",\"uptime_s\":0";
        try json.appendSlice(self.allocator, uptime_str);

        if (self.chat_engine != null) {
            const engine = &self.chat_engine.?;
            const stats = engine.getStats();

            // ── RAZUM (Mind) ──
            try json.appendSlice(self.allocator, ",\"razum\":{");
            {
                const r = std.fmt.allocPrint(
                    self.allocator,
                    "\"symbolic_hits\":{d}," ++
                        "\"symbolic_hit_rate\":{d:.4}," ++
                        "\"memory_entries\":{d}," ++
                        "\"memory_hit_rate\":{d:.4}," ++
                        "\"memory_evictions\":{d}," ++
                        "\"kg_hits\":{d}," ++
                        "\"kg_hit_rate\":{d:.4}," ++
                        "\"kg_facts_loaded\":{d}," ++
                        "\"llm_loaded\":{s}," ++
                        "\"last_routing\":\"{s}\"",
                    .{
                        stats.symbolic_hits,
                        stats.symbolic_hit_rate,
                        stats.memory_entries,
                        stats.memory_hit_rate,
                        stats.memory_evictions,
                        stats.kg_hits,
                        stats.kg_hit_rate,
                        stats.kg_facts_loaded,
                        if (stats.llm_loaded) "true" else "false",
                        stats.last_routing,
                    },
                ) catch "";
                if (r.len > 0) {
                    defer self.allocator.free(r);
                    try json.appendSlice(self.allocator, r);
                }
            }
            try json.appendSlice(self.allocator, "}");

            // ── MATERIYA (Matter) ──
            try json.appendSlice(self.allocator, ",\"materiya\":{");
            {
                const m = std.fmt.allocPrint(
                    self.allocator,
                    "\"tvc_enabled\":{s}," ++
                        "\"tvc_corpus_size\":{d}," ++
                        "\"tvc_hits\":{d}," ++
                        "\"tvc_hit_rate\":{d:.4}," ++
                        "\"cache_hit_rate\":{d:.4}",
                    .{
                        if (stats.tvc_enabled) "true" else "false",
                        stats.tvc_corpus_size,
                        stats.tvc_hits,
                        stats.tvc_hit_rate,
                        stats.cache_hit_rate,
                    },
                ) catch "";
                if (m.len > 0) {
                    defer self.allocator.free(m);
                    try json.appendSlice(self.allocator, m);
                }
            }
            try json.appendSlice(self.allocator, "}");

            // ── DUKH (Spirit) ──
            try json.appendSlice(self.allocator, ",\"dukh\":{");
            {
                const d = std.fmt.allocPrint(
                    self.allocator,
                    "\"total_queries\":{d}," ++
                        "\"energy_saved_wh\":{d:.6}," ++
                        "\"groq_calls\":{d}," ++
                        "\"claude_calls\":{d}," ++
                        "\"tool_hits\":{d}," ++
                        "\"vision_calls\":{d}," ++
                        "\"whisper_calls\":{d}," ++
                        "\"groq_success_rate\":{d:.4}," ++
                        "\"claude_success_rate\":{d:.4}," ++
                        "\"context_enabled\":{s}," ++
                        "\"context_messages\":{d}," ++
                        "\"context_key_facts\":{d}",
                    .{
                        stats.total_queries,
                        stats.energy_saved_wh,
                        stats.groq_calls,
                        stats.claude_calls,
                        stats.tool_hits,
                        stats.vision_calls,
                        stats.whisper_calls,
                        stats.groq_success_rate,
                        stats.claude_success_rate,
                        if (stats.context_enabled) "true" else "false",
                        stats.context_total_messages,
                        stats.context_key_facts,
                    },
                ) catch "";
                if (d.len > 0) {
                    defer self.allocator.free(d);
                    try json.appendSlice(self.allocator, d);
                }
            }
            try json.appendSlice(self.allocator, "}");
        }

        // ── LOGS (recent query ring buffer) ──
        try json.appendSlice(self.allocator, ",\"logs\":[");
        if (self.log_count > 0) {
            // Iterate from oldest to newest
            const start_idx = if (self.log_count < MAX_LOG_ENTRIES) 0 else self.log_index;
            var i: usize = 0;
            while (i < self.log_count) : (i += 1) {
                const idx = (start_idx + i) % MAX_LOG_ENTRIES;
                const entry = &self.log_ring[idx];
                if (i > 0) try json.appendSlice(self.allocator, ",");
                try json.appendSlice(self.allocator, "{\"ts\":");
                const ts_str = std.fmt.allocPrint(self.allocator, "{d}", .{entry.timestamp}) catch "0";
                defer self.allocator.free(ts_str);
                try json.appendSlice(self.allocator, ts_str);
                try json.appendSlice(self.allocator, ",\"src\":\"");
                try json.appendSlice(self.allocator, entry.source);
                try json.appendSlice(self.allocator, "\",\"q\":\"");
                // Escape query preview for JSON
                for (entry.query_preview[0..entry.query_len]) |c| {
                    switch (c) {
                        '"' => try json.appendSlice(self.allocator, "\\\""),
                        '\\' => try json.appendSlice(self.allocator, "\\\\"),
                        '\n' => try json.appendSlice(self.allocator, " "),
                        '\r' => {},
                        else => try json.append(self.allocator, c),
                    }
                }
                try json.appendSlice(self.allocator, "\",\"conf\":");
                const conf_str = std.fmt.allocPrint(self.allocator, "{d:.4}", .{entry.confidence}) catch "0";
                defer self.allocator.free(conf_str);
                try json.appendSlice(self.allocator, conf_str);
                const lat_str = std.fmt.allocPrint(self.allocator, ",\"lat\":{d}", .{entry.latency_us}) catch ",\"lat\":0";
                defer self.allocator.free(lat_str);
                try json.appendSlice(self.allocator, lat_str);
                try json.appendSlice(self.allocator, if (entry.learned) ",\"learned\":true}" else "}");
            }
        }
        try json.appendSlice(self.allocator, "]");

        try json.appendSlice(self.allocator, "}");

        try self.sendJsonResponse(connection, json.items);
    }

    fn handleDiagnostic(self: *Self, connection: *std.net.Server.Connection) !void {
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"routing_stats\":{");

        if (self.chat_engine) |engine| {
            const energy = engine.energy;
            try json.writer(self.allocator).print(
                "\"tool_hits\":{d},\"symbolic_hits\":{d},\"kg_hits\":{d},\"tvc_hits\":{d},\"llm_calls\":{d},\"error_fallbacks\":{d},\"total_queries\":{d}",
                .{ energy.tool_hits, energy.symbolic_hits, energy.kg_hits, energy.tvc_hits, engine.llm_calls, engine.error_fallbacks, energy.total_queries },
            );
        } else {
            try json.appendSlice(self.allocator, "\"total_queries\":0");
        }

        try json.appendSlice(self.allocator, "},\"llm_status\":{");

        if (self.chat_engine) |engine| {
            try json.writer(self.allocator).print(
                "\"groq_key\":{s},\"claude_key\":{s},\"local_model\":{s}",
                .{
                    if (engine.config.groq_api_key != null) "true" else "false",
                    if (engine.config.claude_api_key != null) "true" else "false",
                    if (engine.model_path != null) "true" else "false",
                },
            );
        } else {
            try json.appendSlice(self.allocator, "\"groq_key\":false,\"claude_key\":false,\"local_model\":false");
        }

        try json.appendSlice(self.allocator, "},\"capabilities\":[\"math\",\"time\",\"date\",\"greetings_ru\",\"greetings_en\",\"kg_geography\",\"kg_science\",\"kg_history\"]");

        // Recent query log
        try json.appendSlice(self.allocator, ",\"recent_queries\":[");
        if (self.chat_engine) |engine| {
            const log = engine.getQueryLog();
            const count = @min(log.len, 10);
            for (0..count) |i| {
                const idx = if (log.len > count) log.len - count + i else i;
                const entry = log[idx];
                if (entry.query_len == 0) continue;
                if (i > 0) try json.appendSlice(self.allocator, ",");
                try json.appendSlice(self.allocator, "{\"q\":\"");
                const qlen = @min(entry.query_len, 64);
                try json.appendSlice(self.allocator, entry.query[0..qlen]);
                try json.writer(self.allocator).print("\",\"src\":\"{s}\",\"conf\":{d:.2},\"lat\":{d}}}", .{
                    @tagName(entry.source),
                    entry.confidence,
                    entry.latency_us,
                });
            }
        }
        try json.appendSlice(self.allocator, "]}");

        try self.sendJsonResponse(connection, json.items);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WEBSOCKET HANDLER (v8.21)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Handle WebSocket upgrade request for /ws/pas
    fn handleWebSocketUpgrade(self: *Self, connection: *std.net.Server.Connection, request: []const u8) !void {
        // Check for required WebSocket upgrade headers
        const has_upgrade = std.mem.indexOf(u8, request, "Upgrade: websocket") != null;
        const has_connection = std.mem.indexOf(u8, request, "Connection: Upgrade") != null or
            std.mem.indexOf(u8, request, "connection: Upgrade") != null or
            std.mem.indexOf(u8, request, "Connection: upgrade") != null or
            std.mem.indexOf(u8, request, "connection: upgrade") != null;

        if (!has_upgrade or !has_connection) {
            try self.sendError(connection, "Missing WebSocket upgrade headers");
            return;
        }

        // Extract Sec-WebSocket-Key
        const ws_key = extractHeaderValue(request, "Sec-WebSocket-Key") orelse {
            try self.sendError(connection, "Missing Sec-WebSocket-Key");
            return;
        };

        // Compute Sec-WebSocket-Accept: base64(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
        const ws_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        const hash_buf = try self.allocator.alloc(u8, ws_key.len + ws_guid.len);
        defer self.allocator.free(hash_buf);
        @memcpy(hash_buf[0..ws_key.len], ws_key);
        @memcpy(hash_buf[ws_key.len..], ws_guid);

        var hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(hash_buf, &hash, .{});

        var accept_b64: [32]u8 = undefined;
        const accept_slice = std.base64.standard.Encoder.encode(&accept_b64, &hash);

        // Send 101 Switching Protocols response
        const response = std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 101 Switching Protocols\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Accept: {s}\r\n" ++
                "\r\n",
            .{accept_slice},
        ) catch return;
        defer self.allocator.free(response);

        _ = try connection.stream.writeAll(response);

        std.debug.print("[ChatServer] WebSocket /ws/pas connection established\n", .{});

        // Add client to WebSocket server
        try self.ws_server.clients.append(self.allocator, connection.stream);

        // Send initial welcome message
        const welcome = try std.fmt.allocPrint(
            self.allocator,
            \\{{"type":"connected","endpoint":"/ws/pas","timestamp":{d},"message":"PAS WebSocket connected"}}
        ,
            .{std.time.timestamp()},
        );
        defer self.allocator.free(welcome);
        _ = self.ws_server.sendWsFrame(connection.stream, welcome);

        // Send initial PAS status
        const status_msg = try std.fmt.allocPrint(
            self.allocator,
            \\{{"type":"status","pas_active":{s},"analyses":{d},"energy":{d:.2},"berry_phase":{d:.5}}}
        ,
            .{ if (self.pas_active) "true" else "false", self.pas_analyses, self.pas_energy, self.pas_berry_phase },
        );
        defer self.allocator.free(status_msg);
        _ = self.ws_server.sendWsFrame(connection.stream, status_msg);

        // Note: This is a simple implementation that doesn't handle persistent connections
        // In production, you'd want a separate thread/event loop for each WebSocket
    }

    /// Extract header value from HTTP request
    fn extractHeaderValue(request: []const u8, header_name: []const u8) ?[]const u8 {
        var i: usize = 0;
        while (i < request.len) : (i += 1) {
            if (i + header_name.len + 2 <= request.len and
                std.mem.eql(u8, request[i .. i + header_name.len], header_name) and
                request[i + header_name.len] == ':' and
                request[i + header_name.len + 1] == ' ')
            {
                const start = i + header_name.len + 2;
                var end = start;
                while (end < request.len and request[end] != '\r') : (end += 1) {}
                return std.mem.trimRight(u8, request[start..end], " \t");
            }
        }
        return null;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PAS HANDLERS (v8.20)
    // ═══════════════════════════════════════════════════════════════════════════

    /// GET /api/pas/status - Returns PAS daemon status
    fn handlePasStatus(self: *Self, connection: *std.net.Server.Connection) !void {
        self.activatePas();

        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"active\":");
        try json.appendSlice(self.allocator, if (self.pas_active) "true" else "false");
        try json.appendSlice(self.allocator, ",\"analyses_performed\":");

        var buf1: [32]u8 = undefined;
        const analyses_str = std.fmt.bufPrint(&buf1, "{d}", .{self.pas_analyses}) catch "0";
        try json.appendSlice(self.allocator, analyses_str);

        try json.appendSlice(self.allocator, ",\"energy_harvested\":");
        var buf2: [64]u8 = undefined;
        const energy_str = std.fmt.bufPrint(&buf2, "{d:.2}", .{self.pas_energy}) catch "0";
        try json.appendSlice(self.allocator, energy_str);

        try json.appendSlice(self.allocator, ",\"berry_phase\":");
        var buf3: [64]u8 = undefined;
        const berry_str = std.fmt.bufPrint(&buf3, "{d:.5}", .{self.pas_berry_phase}) catch "0";
        try json.appendSlice(self.allocator, berry_str);

        try json.appendSlice(self.allocator, ",\"pas_energy\":");
        try json.appendSlice(self.allocator, energy_str);

        // Sacred validation
        const sacred_valid = std.math.approxEqRel(f64, PHI_SQ + PHI_INV_SQ, TRINITY, 0.001);
        try json.appendSlice(self.allocator, ",\"sacred_valid\":");
        try json.appendSlice(self.allocator, if (sacred_valid) "true" else "false");

        try json.appendSlice(self.allocator, ",\"pending_recommendations\":0");
        try json.appendSlice(self.allocator, ",\"pas_version\":\"8.20\"");
        try json.appendSlice(self.allocator, ",\"trinity_identity\":\"φ² + 1/φ² = 3\"}");

        try self.sendJsonResponse(connection, json.items);
    }

    /// GET /api/pas/recs - Returns current PAS recommendations
    fn handlePasRecommendations(self: *Self, connection: *std.net.Server.Connection) !void {
        self.activatePas();

        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"active\":");
        try json.appendSlice(self.allocator, if (self.pas_active) "true" else "false");

        try json.appendSlice(self.allocator, ",\"analyses_performed\":");
        var buf1: [32]u8 = undefined;
        const analyses_str = std.fmt.bufPrint(&buf1, "{d}", .{self.pas_analyses}) catch "0";
        try json.appendSlice(self.allocator, analyses_str);

        try json.appendSlice(self.allocator, ",\"energy_harvested\":");
        var buf2: [64]u8 = undefined;
        const energy_str = std.fmt.bufPrint(&buf2, "{d:.2}", .{self.pas_energy}) catch "0";
        try json.appendSlice(self.allocator, energy_str);

        try json.appendSlice(self.allocator, ",\"berry_phase\":");
        var buf3: [64]u8 = undefined;
        const berry_str = std.fmt.bufPrint(&buf3, "{d:.5}", .{self.pas_berry_phase}) catch "0";
        try json.appendSlice(self.allocator, berry_str);

        try json.appendSlice(self.allocator, ",\"pas_energy\":");
        try json.appendSlice(self.allocator, energy_str);

        const sacred_valid = std.math.approxEqRel(f64, PHI_SQ + PHI_INV_SQ, TRINITY, 0.001);
        try json.appendSlice(self.allocator, ",\"sacred_validation_rate\":");
        try json.appendSlice(self.allocator, if (sacred_valid) "1.0" else "0.0");

        try json.appendSlice(self.allocator, ",\"pending_recommendations\":0");
        try json.appendSlice(self.allocator, ",\"recommendations\":[]}");

        try self.sendJsonResponse(connection, json.items);
    }

    /// GET /api/pas/analyze - Returns current PAS analysis
    fn handlePasAnalyze(self: *Self, connection: *std.net.Server.Connection) !void {
        self.activatePas();

        // Increment analysis count
        self.pas_analyses += 1;

        // Update Berry phase (mod 2π)
        self.pas_berry_phase += PHI * 0.1;
        self.pas_berry_phase = @mod(self.pas_berry_phase, 2.0 * std.math.pi);

        // Harvest some energy
        self.pas_energy += PHI_INV_SQ * 578.84;

        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"daemon_active\":");
        try json.appendSlice(self.allocator, if (self.pas_active) "true" else "false");

        // Sacred constants
        try json.appendSlice(self.allocator, ",\"sacred_constants\":{");
        try json.appendSlice(self.allocator, "\"phi\":1.6180339887498949,");
        try json.appendSlice(self.allocator, "\"phi_sq\":2.6180339887498949,");
        try json.appendSlice(self.allocator, "\"phi_inv_sq\":0.3819660112501051,");
        try json.appendSlice(self.allocator, "\"trinity\":3.0,");
        try json.appendSlice(self.allocator, "\"mu\":0.0382,");
        try json.appendSlice(self.allocator, "\"chi\":0.0618,");
        try json.appendSlice(self.allocator, "\"sigma\":1.618,");
        try json.appendSlice(self.allocator, "\"epsilon\":0.333,");
        try json.appendSlice(self.allocator, "\"lucas_10\":123,");
        try json.appendSlice(self.allocator, "\"phoenix\":999");

        try json.appendSlice(self.allocator, "},\"current_metrics\":{");

        try json.appendSlice(self.allocator, "\"berry_phase\":");
        var buf3: [64]u8 = undefined;
        const berry_str = std.fmt.bufPrint(&buf3, "{d:.5}", .{self.pas_berry_phase}) catch "0";
        try json.appendSlice(self.allocator, berry_str);

        try json.appendSlice(self.allocator, ",\"pas_energy\":");
        var buf4: [64]u8 = undefined;
        const pas_energy_str = std.fmt.bufPrint(&buf4, "{d:.2}", .{self.pas_energy}) catch "0";
        try json.appendSlice(self.allocator, pas_energy_str);

        const sacred_valid = std.math.approxEqRel(f64, PHI_SQ + PHI_INV_SQ, TRINITY, 0.001);
        try json.appendSlice(self.allocator, ",\"sacred_validation_rate\":");
        try json.appendSlice(self.allocator, if (sacred_valid) "1.0" else "0.0");

        try json.appendSlice(self.allocator, "}}");

        try self.sendJsonResponse(connection, json.items);
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

    // ═════════════════════════════════════════════════════════════════════════
    // CHEMISTRY API HANDLERS (v11.0)
    // ═════════════════════════════════════════════════════════════════════════

    /// GET /api/chem/sacred?formula=H2O — Molar mass + sacred formula fit
    fn handleChemSacred(self: *Self, connection: *std.net.Server.Connection, path: []const u8) !void {
        const formula_str = extractQueryParam(path, "formula") orelse {
            try self.sendError(connection, "Missing ?formula= parameter");
            return;
        };
        const mass = chemMolarMass(formula_str);
        if (mass <= 0.0) {
            try self.sendError(connection, "Unknown formula");
            return;
        }
        const fit = sacred_formula.fitSacredFormula(mass);
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);
        const body = std.fmt.allocPrint(self.allocator,
            "{{\"formula\":\"{s}\",\"mass\":{d:.4},\"sacred_fit\":{{\"n\":{d},\"k\":{d},\"m\":{d},\"p\":{d},\"q\":{d}}},\"computed\":{d:.6},\"error_pct\":{d:.4},\"source\":\"live\"}}",
            .{ formula_str, mass, fit.n, fit.k, fit.m, fit.p, fit.q, fit.computed, fit.error_pct },
        ) catch return;
        defer self.allocator.free(body);
        try self.sendJsonResponse(connection, body);
    }

    /// GET /api/chem/element?q=Fe — Element info with extended data
    fn handleChemElement(self: *Self, connection: *std.net.Server.Connection, path: []const u8) !void {
        const query = extractQueryParam(path, "q") orelse {
            try self.sendError(connection, "Missing ?q= parameter");
            return;
        };
        // Look up element by symbol or atomic number
        const el = chemLookupElement(query) orelse {
            try self.sendError(connection, "Element not found");
            return;
        };
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);
        const body = std.fmt.allocPrint(self.allocator,
            "{{\"element\":{{\"symbol\":\"{s}\",\"name\":\"{s}\",\"number\":{d},\"mass\":{d:.4}," ++
            "\"block\":\"{s}\",\"category\":\"{s}\",\"valence\":{d}," ++
            "\"electron_config\":\"{s}\"," ++
            "\"density\":{d:.4},\"melting_point\":{d:.2},\"boiling_point\":{d:.2}," ++
            "\"discoverer\":\"{s}\",\"etymology\":\"{s}\"}},\"source\":\"live\"}}",
            .{
                el.symbol, el.name, el.number, el.mass,
                el.block, el.category, el.valence,
                el.electron_config,
                el.density, el.melting_point, el.boiling_point,
                el.discoverer, el.etymology,
            },
        ) catch return;
        defer self.allocator.free(body);
        try self.sendJsonResponse(connection, body);
    }

    /// GET /api/chem/balance?eq=H2%2BO2-%3EH2O — Balance chemical equation
    fn handleChemBalance(self: *Self, connection: *std.net.Server.Connection, path: []const u8) !void {
        const eq_raw = extractQueryParam(path, "eq") orelse {
            try self.sendError(connection, "Missing ?eq= parameter");
            return;
        };
        // URL-decode the equation
        var decoded_buf: [512]u8 = undefined;
        const eq = urlDecodeInto(eq_raw, &decoded_buf);

        // Split on -> or =>
        var lhs: []const u8 = "";
        var rhs: []const u8 = "";
        if (std.mem.indexOf(u8, eq, "->")) |arrow| {
            lhs = std.mem.trim(u8, eq[0..arrow], " ");
            rhs = std.mem.trim(u8, eq[arrow + 2 ..], " ");
        } else if (std.mem.indexOf(u8, eq, "=>")) |arrow| {
            lhs = std.mem.trim(u8, eq[0..arrow], " ");
            rhs = std.mem.trim(u8, eq[arrow + 2 ..], " ");
        } else {
            try self.sendError(connection, "Use -> or => to separate reactants and products");
            return;
        }

        // Split each side on +
        var r_formulas: [8][]const u8 = undefined;
        var r_count: usize = 0;
        var p_formulas: [8][]const u8 = undefined;
        var p_count: usize = 0;
        {
            var it = std.mem.splitScalar(u8, lhs, '+');
            while (it.next()) |seg| {
                if (r_count < 8) {
                    r_formulas[r_count] = std.mem.trim(u8, seg, " ");
                    r_count += 1;
                }
            }
        }
        {
            var it = std.mem.splitScalar(u8, rhs, '+');
            while (it.next()) |seg| {
                if (p_count < 8) {
                    p_formulas[p_count] = std.mem.trim(u8, seg, " ");
                    p_count += 1;
                }
            }
        }
        if (r_count == 0 or p_count == 0) {
            try self.sendError(connection, "Need at least one reactant and one product");
            return;
        }

        // Collect unique elements and build composition matrix
        var elements: [16][]const u8 = undefined;
        var elem_count: usize = 0;
        const total = r_count + p_count;
        // Composition: comp[species][element]
        var comp: [16][16]i32 = std.mem.zeroes([16][16]i32);

        for (0..r_count) |i| {
            chemCollectElements(r_formulas[i], &elements, &elem_count, &comp, i);
        }
        for (0..p_count) |i| {
            chemCollectElements(p_formulas[i], &elements, &elem_count, &comp, r_count + i);
        }

        // Try brute-force balancing (coefficients 1-6)
        var best_coeffs: [16]i32 = undefined;
        for (0..total) |i| best_coeffs[i] = 1;
        var found = false;
        const max_coeff: i32 = 6;

        // For 2 species: iterate all coeff combos
        // For >2: iterate all combos (limited to 4 species for perf)
        if (total <= 4) {
            found = bruteForceBalance(&comp, elem_count, total, r_count, max_coeff, &best_coeffs);
        } else {
            // For larger equations, use simple heuristic: try small coefficients
            found = bruteForceBalance(&comp, elem_count, total, r_count, 4, &best_coeffs);
        }

        if (!found) {
            // Fallback: return coefficients of 1
            for (0..total) |i| best_coeffs[i] = 1;
        }

        // Build response JSON
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);
        // Balanced equation string
        try json.appendSlice(self.allocator, "{\"balanced\":\"");
        for (0..r_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, " + ");
            if (best_coeffs[i] > 1) {
                var cbuf: [8]u8 = undefined;
                const cs = std.fmt.bufPrint(&cbuf, "{d} ", .{best_coeffs[i]}) catch "1 ";
                try json.appendSlice(self.allocator, cs);
            }
            try json.appendSlice(self.allocator, r_formulas[i]);
        }
        try json.appendSlice(self.allocator, " -> ");
        for (0..p_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, " + ");
            if (best_coeffs[r_count + i] > 1) {
                var cbuf: [8]u8 = undefined;
                const cs = std.fmt.bufPrint(&cbuf, "{d} ", .{best_coeffs[r_count + i]}) catch "1 ";
                try json.appendSlice(self.allocator, cs);
            }
            try json.appendSlice(self.allocator, p_formulas[i]);
        }
        try json.appendSlice(self.allocator, "\",\"coefficients\":{\"reactants\":[");
        for (0..r_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, ",");
            var cbuf: [64]u8 = undefined;
            const cs = std.fmt.bufPrint(&cbuf, "{{\"formula\":\"{s}\",\"coefficient\":{d}}}", .{ r_formulas[i], best_coeffs[i] }) catch "{}";
            try json.appendSlice(self.allocator, cs);
        }
        try json.appendSlice(self.allocator, "],\"products\":[");
        for (0..p_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, ",");
            var cbuf: [64]u8 = undefined;
            const cs = std.fmt.bufPrint(&cbuf, "{{\"formula\":\"{s}\",\"coefficient\":{d}}}", .{ p_formulas[i], best_coeffs[r_count + i] }) catch "{}";
            try json.appendSlice(self.allocator, cs);
        }
        // Verification
        try json.appendSlice(self.allocator, "]},\"verification\":{\"elements\":[");
        var all_balanced = true;
        for (0..elem_count) |e| {
            if (e > 0) try json.appendSlice(self.allocator, ",");
            var left_total: i32 = 0;
            var right_total: i32 = 0;
            for (0..r_count) |s| left_total += best_coeffs[s] * comp[s][e];
            for (0..p_count) |s| right_total += best_coeffs[r_count + s] * comp[r_count + s][e];
            const ok = left_total == right_total;
            if (!ok) all_balanced = false;
            var vbuf: [128]u8 = undefined;
            const vs = std.fmt.bufPrint(&vbuf, "{{\"element\":\"{s}\",\"left\":{d},\"right\":{d},\"ok\":{s}}}", .{
                elements[e], left_total, right_total, if (ok) "true" else "false",
            }) catch "{}";
            try json.appendSlice(self.allocator, vs);
        }
        try json.appendSlice(self.allocator, "],\"balanced\":");
        try json.appendSlice(self.allocator, if (all_balanced) "true" else "false");
        try json.appendSlice(self.allocator, "},\"source\":\"live\"}");

        try self.sendJsonResponse(connection, json.items);
    }

    /// GET /api/chem/predict?reactants=Fe%2BHCl — Predict reaction products
    fn handleChemPredict(self: *Self, connection: *std.net.Server.Connection, path: []const u8) !void {
        const raw = extractQueryParam(path, "reactants") orelse {
            try self.sendError(connection, "Missing ?reactants= parameter");
            return;
        };
        // URL-decode
        var decoded_buf: [512]u8 = undefined;
        const decoded = urlDecodeInto(raw, &decoded_buf);

        // Split on + to get reactant formulas
        var reactants: [4][]const u8 = undefined;
        var r_count: usize = 0;
        {
            var it = std.mem.splitScalar(u8, decoded, '+');
            while (it.next()) |seg| {
                const trimmed = std.mem.trim(u8, seg, " ");
                if (trimmed.len > 0 and r_count < 4) {
                    reactants[r_count] = trimmed;
                    r_count += 1;
                }
            }
        }
        if (r_count == 0) {
            try self.sendError(connection, "No reactants provided");
            return;
        }

        // Classify and predict
        var reaction_type: []const u8 = "unknown";
        var products: [4][]const u8 = undefined;
        var p_count: usize = 0;
        var confidence: f64 = 0.0;
        var explanation: []const u8 = "Could not classify reaction";

        // Product formula storage (static buffers)
        var prod_buf1: [32]u8 = undefined;
        var prod_len1: usize = 0;

        if (r_count == 2) {
            const a = reactants[0];
            const b = reactants[1];

            // 1. Combustion: organic (C+H) + O2
            if (isCombustion(a, b)) {
                reaction_type = "combustion";
                products[0] = "CO2";
                products[1] = "H2O";
                p_count = 2;
                confidence = 0.95;
                explanation = "Hydrocarbon combustion: CxHy + O2 -> CO2 + H2O";
            }
            // 2. Acid-Base: acid + base -> salt + H2O
            else if (findAcidIndex(a) != null and findBaseIndex(b) != null) {
                const acid_i = findAcidIndex(a).?;
                const base_i = findBaseIndex(b).?;
                prod_len1 = buildSaltFormula(COMMON_BASES[base_i].cation, COMMON_BASES[base_i].cation_charge, COMMON_ACIDS[acid_i].anion, COMMON_ACIDS[acid_i].anion_charge, &prod_buf1);
                products[0] = prod_buf1[0..prod_len1];
                products[1] = "H2O";
                p_count = 2;
                reaction_type = "acid_base";
                confidence = 0.90;
                explanation = "Acid-base neutralization: acid + base -> salt + water";
            } else if (findAcidIndex(b) != null and findBaseIndex(a) != null) {
                const acid_i = findAcidIndex(b).?;
                const base_i = findBaseIndex(a).?;
                prod_len1 = buildSaltFormula(COMMON_BASES[base_i].cation, COMMON_BASES[base_i].cation_charge, COMMON_ACIDS[acid_i].anion, COMMON_ACIDS[acid_i].anion_charge, &prod_buf1);
                products[0] = prod_buf1[0..prod_len1];
                products[1] = "H2O";
                p_count = 2;
                reaction_type = "acid_base";
                confidence = 0.90;
                explanation = "Acid-base neutralization: acid + base -> salt + water";
            }
            // 3. Single displacement: metal + acid -> salt + H2
            else if (isSingleElement(a) and findAcidIndex(b) != null) {
                const metal = extractSymbol(a);
                const acid_i = findAcidIndex(b).?;
                const m_rank = activityRank(metal);
                const h_rank = activityRank("H");
                if (m_rank != null and h_rank != null and m_rank.? < h_rank.?) {
                    const mc = metalCharge(metal);
                    prod_len1 = buildSaltFormula(metal, mc, COMMON_ACIDS[acid_i].anion, COMMON_ACIDS[acid_i].anion_charge, &prod_buf1);
                    products[0] = prod_buf1[0..prod_len1];
                    products[1] = "H2";
                    p_count = 2;
                    reaction_type = "single_displacement";
                    confidence = 0.85;
                    explanation = "Metal displaces H from acid (metal is above H in activity series)";
                } else {
                    reaction_type = "no_reaction";
                    confidence = 0.80;
                    explanation = "Metal is below H in activity series - no reaction expected";
                }
            }
            // 4. Synthesis: two elements -> binary compound
            else if (isSingleElement(a) and isSingleElement(b)) {
                const sym_a = extractSymbol(a);
                const sym_b = extractSymbol(b);
                const charge_a = metalCharge(sym_a);
                const charge_b = nonmetalCharge(sym_b);
                if (charge_a != 0 and charge_b != 0) {
                    prod_len1 = buildSaltFormula(sym_a, charge_a, sym_b, charge_b, &prod_buf1);
                    products[0] = prod_buf1[0..prod_len1];
                    p_count = 1;
                    reaction_type = "synthesis";
                    confidence = 0.75;
                    explanation = "Direct combination of two elements";
                }
            }
        } else if (r_count == 1) {
            // Decomposition: known patterns
            const f = reactants[0];
            if (strEql(f, "CaCO3")) {
                products[0] = "CaO";
                products[1] = "CO2";
                p_count = 2;
                reaction_type = "decomposition";
                confidence = 0.80;
                explanation = "Thermal decomposition of calcium carbonate";
            } else if (strEql(f, "H2O2")) {
                products[0] = "H2O";
                products[1] = "O2";
                p_count = 2;
                reaction_type = "decomposition";
                confidence = 0.85;
                explanation = "Decomposition of hydrogen peroxide";
            } else if (strEql(f, "KClO3")) {
                products[0] = "KCl";
                products[1] = "O2";
                p_count = 2;
                reaction_type = "decomposition";
                confidence = 0.80;
                explanation = "Thermal decomposition of potassium chlorate";
            } else if (strEql(f, "NaHCO3")) {
                products[0] = "Na2CO3";
                products[1] = "H2O";
                p_count = 2;
                reaction_type = "decomposition";
                confidence = 0.75;
                explanation = "Thermal decomposition of sodium bicarbonate";
            } else {
                reaction_type = "decomposition";
                confidence = 0.40;
                explanation = "Single compound detected — possible decomposition, but products unknown";
            }
        }

        // Build balanced equation string
        var eq_buf: [256]u8 = undefined;
        var eq_len: usize = 0;
        for (0..r_count) |i| {
            if (i > 0) {
                @memcpy(eq_buf[eq_len .. eq_len + 3], " + ");
                eq_len += 3;
            }
            @memcpy(eq_buf[eq_len .. eq_len + reactants[i].len], reactants[i]);
            eq_len += reactants[i].len;
        }
        @memcpy(eq_buf[eq_len .. eq_len + 4], " -> ");
        eq_len += 4;
        for (0..p_count) |i| {
            if (i > 0) {
                @memcpy(eq_buf[eq_len .. eq_len + 3], " + ");
                eq_len += 3;
            }
            @memcpy(eq_buf[eq_len .. eq_len + products[i].len], products[i]);
            eq_len += products[i].len;
        }
        if (p_count == 0) {
            const no_prod = "(no products predicted)";
            @memcpy(eq_buf[eq_len .. eq_len + no_prod.len], no_prod);
            eq_len += no_prod.len;
        }

        // Build JSON response
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"reactants\":[");
        for (0..r_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, ",");
            try json.appendSlice(self.allocator, "\"");
            try json.appendSlice(self.allocator, reactants[i]);
            try json.appendSlice(self.allocator, "\"");
        }
        try json.appendSlice(self.allocator, "],\"reaction_type\":\"");
        try json.appendSlice(self.allocator, reaction_type);
        try json.appendSlice(self.allocator, "\",\"products\":[");
        for (0..p_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, ",");
            try json.appendSlice(self.allocator, "\"");
            try json.appendSlice(self.allocator, products[i]);
            try json.appendSlice(self.allocator, "\"");
        }
        try json.appendSlice(self.allocator, "],\"balanced\":\"");
        try json.appendSlice(self.allocator, eq_buf[0..eq_len]);
        // Confidence
        var conf_buf: [16]u8 = undefined;
        const conf_str = std.fmt.bufPrint(&conf_buf, "{d:.2}", .{confidence}) catch "0.00";
        try json.appendSlice(self.allocator, "\",\"confidence\":");
        try json.appendSlice(self.allocator, conf_str);
        try json.appendSlice(self.allocator, ",\"explanation\":\"");
        try json.appendSlice(self.allocator, explanation);
        // Product details with sacred fits
        try json.appendSlice(self.allocator, "\",\"product_details\":[");
        for (0..p_count) |i| {
            if (i > 0) try json.appendSlice(self.allocator, ",");
            const pmass = chemMolarMass(products[i]);
            const pfit = sacred_formula.fitSacredFormula(if (pmass > 0) pmass else 1.0);
            var pbuf: [256]u8 = undefined;
            const ps = std.fmt.bufPrint(&pbuf,
                "{{\"formula\":\"{s}\",\"mass\":{d:.3},\"sacred_fit\":{{\"n\":{d},\"k\":{d},\"m\":{d},\"p\":{d},\"q\":{d}}},\"computed\":{d:.6},\"error_pct\":{d:.4}}}",
                .{ products[i], pmass, pfit.n, pfit.k, pfit.m, pfit.p, pfit.q, pfit.computed, pfit.error_pct },
            ) catch "{}";
            try json.appendSlice(self.allocator, ps);
        }
        try json.appendSlice(self.allocator, "],\"source\":\"live\"}");

        try self.sendJsonResponse(connection, json.items);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHEMISTRY ENGINE v11.0 — Static Data + Helpers
// ═══════════════════════════════════════════════════════════════════════════════

const ACTIVITY_SERIES = [_][]const u8{
    "Li", "K", "Ba", "Ca", "Na", "Mg", "Al", "Zn", "Fe", "Ni", "Sn", "Pb",
    "H", "Cu", "Hg", "Ag", "Pt", "Au",
};

const AcidInfo = struct { formula: []const u8, anion: []const u8, anion_charge: i8, name: []const u8 };
const COMMON_ACIDS = [_]AcidInfo{
    .{ .formula = "HCl", .anion = "Cl", .anion_charge = -1, .name = "hydrochloric" },
    .{ .formula = "HBr", .anion = "Br", .anion_charge = -1, .name = "hydrobromic" },
    .{ .formula = "HI", .anion = "I", .anion_charge = -1, .name = "hydroiodic" },
    .{ .formula = "HF", .anion = "F", .anion_charge = -1, .name = "hydrofluoric" },
    .{ .formula = "HNO3", .anion = "NO3", .anion_charge = -1, .name = "nitric" },
    .{ .formula = "H2SO4", .anion = "SO4", .anion_charge = -2, .name = "sulfuric" },
    .{ .formula = "H3PO4", .anion = "PO4", .anion_charge = -3, .name = "phosphoric" },
};

const BaseInfo = struct { formula: []const u8, cation: []const u8, cation_charge: i8, name: []const u8 };
const COMMON_BASES = [_]BaseInfo{
    .{ .formula = "NaOH", .cation = "Na", .cation_charge = 1, .name = "sodium hydroxide" },
    .{ .formula = "KOH", .cation = "K", .cation_charge = 1, .name = "potassium hydroxide" },
    .{ .formula = "Ca(OH)2", .cation = "Ca", .cation_charge = 2, .name = "calcium hydroxide" },
};

const MetalValence = struct { sym: []const u8, charge: i8 };
const METAL_VALENCES = [_]MetalValence{
    .{ .sym = "Li", .charge = 1 }, .{ .sym = "Na", .charge = 1 }, .{ .sym = "K", .charge = 1 },
    .{ .sym = "Ca", .charge = 2 }, .{ .sym = "Mg", .charge = 2 }, .{ .sym = "Ba", .charge = 2 },
    .{ .sym = "Al", .charge = 3 }, .{ .sym = "Fe", .charge = 2 }, .{ .sym = "Zn", .charge = 2 },
    .{ .sym = "Cu", .charge = 2 }, .{ .sym = "Ag", .charge = 1 }, .{ .sym = "Pb", .charge = 2 },
    .{ .sym = "Sn", .charge = 2 }, .{ .sym = "Ni", .charge = 2 },
};

const NonmetalValence = struct { sym: []const u8, charge: i8 };
const NONMETAL_VALENCES = [_]NonmetalValence{
    .{ .sym = "F", .charge = -1 }, .{ .sym = "Cl", .charge = -1 }, .{ .sym = "Br", .charge = -1 },
    .{ .sym = "I", .charge = -1 }, .{ .sym = "O", .charge = -2 }, .{ .sym = "S", .charge = -2 },
    .{ .sym = "N", .charge = -3 },
};

const ElementInfo = struct {
    symbol: []const u8,
    name: []const u8,
    number: u8,
    mass: f64,
    block: []const u8,
    category: []const u8,
    valence: i8,
    electron_config: []const u8,
    density: f64,
    melting_point: f64,
    boiling_point: f64,
    discoverer: []const u8,
    etymology: []const u8,
};

const ELEMENTS = [_]ElementInfo{
    .{ .symbol = "H", .name = "Hydrogen", .number = 1, .mass = 1.008, .block = "s", .category = "nonmetal", .valence = 1, .electron_config = "1s1", .density = 0.00008988, .melting_point = 14.01, .boiling_point = 20.28, .discoverer = "Cavendish", .etymology = "Greek: hydro + genes (water forming)" },
    .{ .symbol = "He", .name = "Helium", .number = 2, .mass = 4.003, .block = "s", .category = "noble gas", .valence = 0, .electron_config = "1s2", .density = 0.0001785, .melting_point = 0.95, .boiling_point = 4.22, .discoverer = "Janssen/Lockyer", .etymology = "Greek: helios (sun)" },
    .{ .symbol = "Li", .name = "Lithium", .number = 3, .mass = 6.941, .block = "s", .category = "alkali metal", .valence = 1, .electron_config = "[He]2s1", .density = 0.534, .melting_point = 453.65, .boiling_point = 1615.0, .discoverer = "Arfwedson", .etymology = "Greek: lithos (stone)" },
    .{ .symbol = "C", .name = "Carbon", .number = 6, .mass = 12.011, .block = "p", .category = "nonmetal", .valence = 4, .electron_config = "[He]2s2 2p2", .density = 2.267, .melting_point = 3823.0, .boiling_point = 4098.0, .discoverer = "Ancient", .etymology = "Latin: carbo (charcoal)" },
    .{ .symbol = "N", .name = "Nitrogen", .number = 7, .mass = 14.007, .block = "p", .category = "nonmetal", .valence = 3, .electron_config = "[He]2s2 2p3", .density = 0.0012506, .melting_point = 63.15, .boiling_point = 77.36, .discoverer = "Rutherford", .etymology = "Greek: nitron + genes (niter forming)" },
    .{ .symbol = "O", .name = "Oxygen", .number = 8, .mass = 15.999, .block = "p", .category = "nonmetal", .valence = 2, .electron_config = "[He]2s2 2p4", .density = 0.001429, .melting_point = 54.36, .boiling_point = 90.20, .discoverer = "Priestley/Scheele", .etymology = "Greek: oxy + genes (acid forming)" },
    .{ .symbol = "F", .name = "Fluorine", .number = 9, .mass = 18.998, .block = "p", .category = "halogen", .valence = 1, .electron_config = "[He]2s2 2p5", .density = 0.001696, .melting_point = 53.53, .boiling_point = 85.03, .discoverer = "Moissan", .etymology = "Latin: fluere (to flow)" },
    .{ .symbol = "Na", .name = "Sodium", .number = 11, .mass = 22.990, .block = "s", .category = "alkali metal", .valence = 1, .electron_config = "[Ne]3s1", .density = 0.971, .melting_point = 370.95, .boiling_point = 1156.0, .discoverer = "Davy", .etymology = "Latin: natrium (soda)" },
    .{ .symbol = "Mg", .name = "Magnesium", .number = 12, .mass = 24.305, .block = "s", .category = "alkaline earth", .valence = 2, .electron_config = "[Ne]3s2", .density = 1.738, .melting_point = 923.0, .boiling_point = 1363.0, .discoverer = "Black/Davy", .etymology = "Greek: Magnesia (district)" },
    .{ .symbol = "Al", .name = "Aluminum", .number = 13, .mass = 26.982, .block = "p", .category = "metal", .valence = 3, .electron_config = "[Ne]3s2 3p1", .density = 2.698, .melting_point = 933.47, .boiling_point = 2792.0, .discoverer = "Oersted", .etymology = "Latin: alumen (alum)" },
    .{ .symbol = "Si", .name = "Silicon", .number = 14, .mass = 28.085, .block = "p", .category = "metalloid", .valence = 4, .electron_config = "[Ne]3s2 3p2", .density = 2.329, .melting_point = 1687.0, .boiling_point = 3538.0, .discoverer = "Berzelius", .etymology = "Latin: silex (flint)" },
    .{ .symbol = "P", .name = "Phosphorus", .number = 15, .mass = 30.974, .block = "p", .category = "nonmetal", .valence = 3, .electron_config = "[Ne]3s2 3p3", .density = 1.82, .melting_point = 317.3, .boiling_point = 553.65, .discoverer = "Brand", .etymology = "Greek: phosphoros (light-bearing)" },
    .{ .symbol = "S", .name = "Sulfur", .number = 16, .mass = 32.065, .block = "p", .category = "nonmetal", .valence = 2, .electron_config = "[Ne]3s2 3p4", .density = 2.067, .melting_point = 388.36, .boiling_point = 717.87, .discoverer = "Ancient", .etymology = "Latin: sulphur" },
    .{ .symbol = "Cl", .name = "Chlorine", .number = 17, .mass = 35.453, .block = "p", .category = "halogen", .valence = 1, .electron_config = "[Ne]3s2 3p5", .density = 0.003214, .melting_point = 171.65, .boiling_point = 239.11, .discoverer = "Scheele", .etymology = "Greek: chloros (yellow-green)" },
    .{ .symbol = "K", .name = "Potassium", .number = 19, .mass = 39.098, .block = "s", .category = "alkali metal", .valence = 1, .electron_config = "[Ar]4s1", .density = 0.862, .melting_point = 336.53, .boiling_point = 1032.0, .discoverer = "Davy", .etymology = "English: potash / Latin: kalium" },
    .{ .symbol = "Ca", .name = "Calcium", .number = 20, .mass = 40.078, .block = "s", .category = "alkaline earth", .valence = 2, .electron_config = "[Ar]4s2", .density = 1.55, .melting_point = 1115.0, .boiling_point = 1757.0, .discoverer = "Davy", .etymology = "Latin: calx (lime)" },
    .{ .symbol = "Fe", .name = "Iron", .number = 26, .mass = 55.845, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Ar]3d6 4s2", .density = 7.874, .melting_point = 1811.0, .boiling_point = 3134.0, .discoverer = "Ancient", .etymology = "Anglo-Saxon: iron / Latin: ferrum" },
    .{ .symbol = "Ni", .name = "Nickel", .number = 28, .mass = 58.693, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Ar]3d8 4s2", .density = 8.912, .melting_point = 1728.0, .boiling_point = 3186.0, .discoverer = "Cronstedt", .etymology = "German: Kupfernickel (false copper)" },
    .{ .symbol = "Cu", .name = "Copper", .number = 29, .mass = 63.546, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Ar]3d10 4s1", .density = 8.96, .melting_point = 1357.77, .boiling_point = 2835.0, .discoverer = "Ancient", .etymology = "Latin: cuprum (Cyprus)" },
    .{ .symbol = "Zn", .name = "Zinc", .number = 30, .mass = 65.38, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Ar]3d10 4s2", .density = 7.134, .melting_point = 692.68, .boiling_point = 1180.0, .discoverer = "Ancient", .etymology = "German: Zinke (prong)" },
    .{ .symbol = "Br", .name = "Bromine", .number = 35, .mass = 79.904, .block = "p", .category = "halogen", .valence = 1, .electron_config = "[Ar]3d10 4s2 4p5", .density = 3.122, .melting_point = 265.95, .boiling_point = 332.0, .discoverer = "Balard", .etymology = "Greek: bromos (stench)" },
    .{ .symbol = "Ag", .name = "Silver", .number = 47, .mass = 107.868, .block = "d", .category = "transition metal", .valence = 1, .electron_config = "[Kr]4d10 5s1", .density = 10.501, .melting_point = 1234.93, .boiling_point = 2435.0, .discoverer = "Ancient", .etymology = "Anglo-Saxon: seolfor / Latin: argentum" },
    .{ .symbol = "Sn", .name = "Tin", .number = 50, .mass = 118.710, .block = "p", .category = "metal", .valence = 2, .electron_config = "[Kr]4d10 5s2 5p2", .density = 7.287, .melting_point = 505.08, .boiling_point = 2875.0, .discoverer = "Ancient", .etymology = "Anglo-Saxon: tin / Latin: stannum" },
    .{ .symbol = "I", .name = "Iodine", .number = 53, .mass = 126.904, .block = "p", .category = "halogen", .valence = 1, .electron_config = "[Kr]4d10 5s2 5p5", .density = 4.933, .melting_point = 386.85, .boiling_point = 457.55, .discoverer = "Courtois", .etymology = "Greek: iodes (violet)" },
    .{ .symbol = "Ba", .name = "Barium", .number = 56, .mass = 137.327, .block = "s", .category = "alkaline earth", .valence = 2, .electron_config = "[Xe]6s2", .density = 3.594, .melting_point = 1000.0, .boiling_point = 2170.0, .discoverer = "Davy", .etymology = "Greek: barys (heavy)" },
    .{ .symbol = "Pb", .name = "Lead", .number = 82, .mass = 207.2, .block = "p", .category = "metal", .valence = 2, .electron_config = "[Xe]4f14 5d10 6s2 6p2", .density = 11.342, .melting_point = 600.61, .boiling_point = 2022.0, .discoverer = "Ancient", .etymology = "Anglo-Saxon: lead / Latin: plumbum" },
    .{ .symbol = "Hg", .name = "Mercury", .number = 80, .mass = 200.592, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Xe]4f14 5d10 6s2", .density = 13.5336, .melting_point = 234.32, .boiling_point = 629.88, .discoverer = "Ancient", .etymology = "Named after planet Mercury" },
    .{ .symbol = "Pt", .name = "Platinum", .number = 78, .mass = 195.084, .block = "d", .category = "transition metal", .valence = 2, .electron_config = "[Xe]4f14 5d9 6s1", .density = 21.46, .melting_point = 2041.4, .boiling_point = 4098.0, .discoverer = "Ulloa", .etymology = "Spanish: platina (little silver)" },
    .{ .symbol = "Au", .name = "Gold", .number = 79, .mass = 196.967, .block = "d", .category = "transition metal", .valence = 3, .electron_config = "[Xe]4f14 5d10 6s1", .density = 19.282, .melting_point = 1337.33, .boiling_point = 3129.0, .discoverer = "Ancient", .etymology = "Anglo-Saxon: gold / Latin: aurum" },
};

fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn activityRank(sym: []const u8) ?usize {
    for (ACTIVITY_SERIES, 0..) |s, i| {
        if (strEql(s, sym)) return i;
    }
    return null;
}

fn findAcidIndex(formula: []const u8) ?usize {
    for (COMMON_ACIDS, 0..) |a, i| {
        if (strEql(a.formula, formula)) return i;
    }
    return null;
}

fn findBaseIndex(formula: []const u8) ?usize {
    for (COMMON_BASES, 0..) |b, i| {
        if (strEql(b.formula, formula)) return i;
    }
    return null;
}

fn metalCharge(sym: []const u8) i8 {
    for (METAL_VALENCES) |v| {
        if (strEql(v.sym, sym)) return v.charge;
    }
    return 0;
}

fn nonmetalCharge(sym: []const u8) i8 {
    for (NONMETAL_VALENCES) |v| {
        if (strEql(v.sym, sym)) return v.charge;
    }
    return 0;
}

fn chemLookupElement(query: []const u8) ?ElementInfo {
    // Try by symbol first
    for (ELEMENTS) |el| {
        if (strEql(el.symbol, query)) return el;
    }
    // Try by atomic number
    const num = std.fmt.parseInt(u8, query, 10) catch return null;
    for (ELEMENTS) |el| {
        if (el.number == num) return el;
    }
    return null;
}

fn chemMolarMass(formula: []const u8) f64 {
    var mass: f64 = 0.0;
    var i: usize = 0;
    while (i < formula.len) {
        // Expect uppercase letter
        if (i < formula.len and formula[i] >= 'A' and formula[i] <= 'Z') {
            var sym_end = i + 1;
            // Lowercase continuation
            while (sym_end < formula.len and formula[sym_end] >= 'a' and formula[sym_end] <= 'z') {
                sym_end += 1;
            }
            const sym = formula[i..sym_end];
            // Parse subscript
            var count: f64 = 1.0;
            var num_start = sym_end;
            while (num_start < formula.len and formula[num_start] >= '0' and formula[num_start] <= '9') {
                num_start += 1;
            }
            if (num_start > sym_end) {
                count = @floatFromInt(std.fmt.parseInt(u32, formula[sym_end..num_start], 10) catch 1);
            }
            // Look up element mass
            var found = false;
            for (ELEMENTS) |el| {
                if (strEql(el.symbol, sym)) {
                    mass += el.mass * count;
                    found = true;
                    break;
                }
            }
            if (!found) return 0.0;
            i = num_start;
        } else {
            i += 1; // skip unknown chars like parentheses for now
        }
    }
    return mass;
}

fn isSingleElement(formula: []const u8) bool {
    if (formula.len == 0) return false;
    if (!(formula[0] >= 'A' and formula[0] <= 'Z')) return false;
    var i: usize = 1;
    // Skip lowercase
    while (i < formula.len and formula[i] >= 'a' and formula[i] <= 'z') i += 1;
    // Skip digits
    while (i < formula.len and formula[i] >= '0' and formula[i] <= '9') i += 1;
    return i == formula.len;
}

fn extractSymbol(formula: []const u8) []const u8 {
    if (formula.len == 0) return formula;
    var end: usize = 1;
    while (end < formula.len and formula[end] >= 'a' and formula[end] <= 'z') end += 1;
    return formula[0..end];
}

fn isCombustion(a: []const u8, b: []const u8) bool {
    // One must be O2, other must contain C
    const has_o2 = strEql(a, "O2") or strEql(b, "O2");
    if (!has_o2) return false;
    const other = if (strEql(a, "O2")) b else a;
    var has_c = false;
    var has_h = false;
    var i: usize = 0;
    while (i < other.len) {
        if (other[i] == 'C' and (i + 1 >= other.len or !(other[i + 1] >= 'a' and other[i + 1] <= 'z') or (i + 1 < other.len and other[i + 1] == 'l') == false)) {
            // Check it's C not Cl, Ca, Cu, Co, Cr
            if (i + 1 >= other.len or other[i + 1] == 'H' or (other[i + 1] >= '0' and other[i + 1] <= '9') or other[i + 1] == 'O') {
                has_c = true;
            } else if (i + 1 < other.len and other[i + 1] >= 'a' and other[i + 1] <= 'z') {
                // It's a two-letter element starting with C (Ca, Cl, etc.) — not carbon
                i += 2;
                continue;
            }
        }
        if (other[i] == 'H' and (i + 1 >= other.len or !(other[i + 1] >= 'a' and other[i + 1] <= 'z'))) {
            has_h = true;
        }
        i += 1;
    }
    return has_c and has_h;
}

fn gcd8(a: i8, b: i8) i8 {
    var x = if (a < 0) -a else a;
    var y = if (b < 0) -b else b;
    while (y != 0) {
        const t = @mod(x, y);
        x = y;
        y = t;
    }
    return if (x == 0) 1 else x;
}

fn buildSaltFormula(cation: []const u8, cation_charge: i8, anion: []const u8, anion_charge: i8, buf: *[32]u8) usize {
    const abs_cat = if (cation_charge < 0) -cation_charge else cation_charge;
    const abs_an = if (anion_charge < 0) -anion_charge else anion_charge;
    const g = gcd8(abs_cat, abs_an);
    const cat_sub: u8 = @intCast(@divTrunc(abs_an, g));
    const an_sub: u8 = @intCast(@divTrunc(abs_cat, g));

    var len: usize = 0;
    @memcpy(buf[len .. len + cation.len], cation);
    len += cation.len;
    if (cat_sub > 1) {
        buf[len] = '0' + cat_sub;
        len += 1;
    }
    @memcpy(buf[len .. len + anion.len], anion);
    len += anion.len;
    if (an_sub > 1) {
        buf[len] = '0' + an_sub;
        len += 1;
    }
    return len;
}

/// Extract element symbols and counts from a formula, populating unique element list and composition matrix
fn chemCollectElements(formula: []const u8, elements: *[16][]const u8, elem_count: *usize, comp: *[16][16]i32, species_idx: usize) void {
    var i: usize = 0;
    while (i < formula.len) {
        if (formula[i] >= 'A' and formula[i] <= 'Z') {
            var sym_end = i + 1;
            while (sym_end < formula.len and formula[sym_end] >= 'a' and formula[sym_end] <= 'z') sym_end += 1;
            const sym = formula[i..sym_end];
            var count: i32 = 1;
            var num_end = sym_end;
            while (num_end < formula.len and formula[num_end] >= '0' and formula[num_end] <= '9') num_end += 1;
            if (num_end > sym_end) {
                count = std.fmt.parseInt(i32, formula[sym_end..num_end], 10) catch 1;
            }
            // Find or add element
            var ei: usize = 0;
            var found = false;
            while (ei < elem_count.*) : (ei += 1) {
                if (strEql(elements[ei], sym)) { found = true; break; }
            }
            if (!found) {
                if (elem_count.* < 16) {
                    elements[elem_count.*] = sym;
                    ei = elem_count.*;
                    elem_count.* += 1;
                } else {
                    i = num_end;
                    continue;
                }
            }
            comp[species_idx][ei] += count;
            i = num_end;
        } else {
            i += 1;
        }
    }
}

/// Brute-force balance checker for small equations
fn bruteForceBalance(comp: *[16][16]i32, elem_count: usize, total: usize, r_count: usize, max_c: i32, best: *[16]i32) bool {
    // Recursively try coefficients 1..max_c for each species
    return bruteForceRec(comp, elem_count, total, r_count, max_c, best, 0);
}

fn bruteForceRec(comp: *[16][16]i32, elem_count: usize, total: usize, r_count: usize, max_c: i32, coeffs: *[16]i32, idx: usize) bool {
    if (idx == total) {
        // Check if balanced
        for (0..elem_count) |e| {
            var left: i32 = 0;
            var right: i32 = 0;
            for (0..r_count) |s| left += coeffs[s] * comp[s][e];
            for (r_count..total) |s| right += coeffs[s] * comp[s][e];
            if (left != right or left == 0) return false;
        }
        return true;
    }
    var c: i32 = 1;
    while (c <= max_c) : (c += 1) {
        coeffs[idx] = c;
        if (bruteForceRec(comp, elem_count, total, r_count, max_c, coeffs, idx + 1)) return true;
    }
    return false;
}

fn extractQueryParam(path: []const u8, key: []const u8) ?[]const u8 {
    // Find ?key= or &key= in path
    const search_patterns = [_][]const u8{ "?", "&" };
    for (search_patterns) |prefix| {
        // Build search string: prefix + key + "="
        var search_buf: [64]u8 = undefined;
        if (prefix.len + key.len + 1 > search_buf.len) continue;
        @memcpy(search_buf[0..prefix.len], prefix);
        @memcpy(search_buf[prefix.len .. prefix.len + key.len], key);
        search_buf[prefix.len + key.len] = '=';
        const search = search_buf[0 .. prefix.len + key.len + 1];

        if (std.mem.indexOf(u8, path, search)) |pos| {
            const val_start = pos + search.len;
            // Find end: next & or end of path (or space for HTTP)
            var val_end = val_start;
            while (val_end < path.len and path[val_end] != '&' and path[val_end] != ' ' and path[val_end] != '#') {
                val_end += 1;
            }
            return path[val_start..val_end];
        }
    }
    return null;
}

fn urlDecodeInto(input: []const u8, buf: *[512]u8) []const u8 {
    var out: usize = 0;
    var i: usize = 0;
    while (i < input.len and out < buf.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hi = hexVal(input[i + 1]);
            const lo = hexVal(input[i + 2]);
            if (hi != null and lo != null) {
                buf[out] = hi.? * 16 + lo.?;
                out += 1;
                i += 3;
                continue;
            }
        }
        if (input[i] == '+') {
            buf[out] = ' ';
        } else {
            buf[out] = input[i];
        }
        out += 1;
        i += 1;
    }
    return buf[0..out];
}

fn hexVal(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

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
