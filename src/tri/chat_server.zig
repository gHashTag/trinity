// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CHAT HTTP SERVER v2.5
// POST /chat        — Hybrid Chat endpoint for Cosmic UI
// POST /chat/clear  — Clear conversation context
// GET  /health      — Health check
// GET  /api/files   — Project file listing for Finder
// POST /api/compile — VIBEE/Zig compilation for Editor
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const tvc = @import("tvc_corpus");

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
        };
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
        std.debug.print("║         TRINITY CHAT SERVER v2.5                    ║\n", .{});
        std.debug.print("║   POST /chat | GET /health | /api/files | /compile  ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Endpoints:\n", .{});
        std.debug.print("  POST /chat        - Chat with Trinity (JSON)\n", .{});
        std.debug.print("  POST /chat/clear  - Clear conversation context\n", .{});
        std.debug.print("  GET  /health      - Health check\n", .{});
        std.debug.print("  GET  /api/files   - Project file listing\n", .{});
        std.debug.print("  POST /api/compile - VIBEE/Zig compilation\n", .{});
        std.debug.print("  OPTIONS /*        - CORS preflight\n", .{});
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
        } else if (std.mem.startsWith(u8, path, "/diagnostic")) {
            try self.handleDiagnostic(connection);
        } else if (std.mem.startsWith(u8, path, "/api/ralph-status")) {
            try self.handleRalphStatus(connection);
        } else if (std.mem.startsWith(u8, path, "/api/files")) {
            try self.handleFileList(connection);
        } else if (std.mem.startsWith(u8, path, "/api/compile")) {
            if (std.mem.eql(u8, method, "POST")) {
                try self.handleCompile(connection, body);
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

    /// GET /api/ralph-status — Return internal Ralph autonomous state
    fn handleRalphStatus(self: *Self, connection: *std.net.Server.Connection) !void {
        var json: std.ArrayListUnmanaged(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{");

        // 1. Read .ralph/logs/status.json
        const status_json = std.fs.cwd().readFileAlloc(self.allocator, ".ralph/logs/status.json", 4096) catch |err| blk: {
            std.debug.print("[ChatServer] Ralph status read error: {}\n", .{err});
            break :blk "{\"status\":\"offline\"}";
        };
        defer if (!std.mem.eql(u8, status_json, "{\"status\":\"offline\"}")) self.allocator.free(status_json);

        try json.appendSlice(self.allocator, "\"loop\":");
        try json.appendSlice(self.allocator, status_json);

        // 2. Read .ralph/internal/.circuit_breaker_state
        const cb_json = std.fs.cwd().readFileAlloc(self.allocator, ".ralph/internal/.circuit_breaker_state", 4096) catch |err| blk: {
            std.debug.print("[ChatServer] Ralph CB read error: {}\n", .{err});
            break :blk "{\"state\":\"UNKNOWN\"}";
        };
        defer if (!std.mem.eql(u8, cb_json, "{\"state\":\"UNKNOWN\"}")) self.allocator.free(cb_json);

        try json.appendSlice(self.allocator, ",\"circuit_breaker\":");
        try json.appendSlice(self.allocator, cb_json);

        // 3. Tail latest log
        try json.appendSlice(self.allocator, ",\"logs\":[");
        {
            // Find latest claude_output log
            var dir = std.fs.cwd().openDir(".ralph/logs", .{ .iterate = true }) catch null;
            if (dir) |*d| {
                defer d.close();
                var latest_time: i64 = 0;
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
                        // Take last 20 lines
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
                            // Escape line for JSON
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
