// @origin(spec:backend_server.tri) @regen(manual-impl)
//
// Queen Backend — HTTP/JSON API Server for Container Deployment
// Replaces QueenBridge.swift file I/O with HTTP endpoints
//
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================
// FIXME: resurrect trinity_workspace when queen backend is implemented for CLARA
//
// Import existing queen modules
const episodes = @import("episodes.zig");
const auto_improve = @import("auto_improve.zig");
const episode_handler = @import("episode_handler.zig");
const EpisodeLogger = @import("episode_logger.zig").EpisodeLogger;

// ============================================================================

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

const TRINITY_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3
const DEFAULT_PORT: u16 = 8080;
const IMPROVE_INTERVAL: u32 = 3600; // 1 hour
const MAX_EPISODE_WINDOW: usize = 100;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

pub const BackendConfig = struct {
    port: u16 = DEFAULT_PORT,
    ws_port: u16 = DEFAULT_PORT + 1,
    improve_interval: u32 = IMPROVE_INTERVAL,
    episode_window: usize = MAX_EPISODE_WINDOW,
};

pub const SystemStatus = struct {
    trinity_identity: f64 = TRINITY_IDENTITY,
    env_status: EnvStatus,
    swarm_active: bool = false,
    last_improve: ?LastImprove = null,
};

pub const LastImprove = struct {
    success: bool,
    timestamp: i64,
    message: []const u8,
};

pub const EnvStatus = enum {
    active,
    degraded,
    maintenance,
};

pub const HealthResponse = struct {
    status: []const u8 = "ok",
    trinity_signature: f64 = TRINITY_IDENTITY,
    improve_cycles: u32 = 0,
    uptime_seconds: u64 = 0,
};

pub const ImproveRequest = struct {
    force: bool = false,
    episode_window: ?usize = null,
};

pub const ImproveResponse = struct {
    success: bool,
    message: []const u8,
    applied_deltas: u32 = 0,
    quality_score: f64 = 0.0,
    cycles_analyzed: usize = 0,
    patterns_found: usize = 0,
};

// Placeholder for Tri27Config (self_learning module integration)
pub const Tri27Config = struct {
    auto_adapt: bool = false,
};

// ============================================================================
// BACKEND SERVER
// ============================================================================

pub const QueenBackend = struct {
    allocator: std.mem.Allocator,
    config: BackendConfig,
    server: ?std.net.Server,
    logger: EpisodeLogger,
    health: struct {
        started_at: i64,
        improve_cycles: u32,
        last_improve_time: i64,
    },

    /// Initialize backend with default config
    pub fn init(allocator: std.mem.Allocator) QueenBackend {
        return QueenBackend{
            .allocator = allocator,
            .config = BackendConfig{},
            .server = null,
            .logger = EpisodeLogger.init(".trinity/logs"),
            .health = .{
                .started_at = @intCast(std.time.nanoTimestamp()),
                .improve_cycles = 0,
                .last_improve_time = 0,
            },
        };
    }

    /// Initialize with custom config
    pub fn initWithConfig(allocator: std.mem.Allocator, config: BackendConfig) QueenBackend {
        const backend = QueenBackend{
            .allocator = allocator,
            .config = config,
            .server = null,
            .logger = EpisodeLogger.init(".trinity/logs"),
            .health = .{
                .started_at = @intCast(std.time.nanoTimestamp()),
                .improve_cycles = 0,
                .last_improve_time = 0,
            },
        };
        return backend;
    }

    /// Start HTTP server
    pub fn start(self: *QueenBackend) !void {
        const address = try std.net.Address.parseIp("0.0.0.0", self.config.port);
        self.server = try address.listen(.{
            .reuse_address = true,
        });

        std.debug.print("\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m╔════════════════════════════════════════════════════╗\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║      🎯 Queen Backend Server Started              ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m╠════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  HTTP API:  http://0.0.0.0:{d:4}                   ║\x1b[0m\n", .{self.config.port});
        std.debug.print("\x1b[38;2;255;215;0m║  Health:    GET /health                          ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  Status:    GET /api/status                        ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  Episodes: GET /api/episodes                      ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  Improve:  POST /api/improve                      ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  TRI-Spec:  GET /api/tri-spec                     ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  Pipeline:  GET /api/pipeline                      ║\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m╠════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  Auto-improve: {d:4}s interval                  ║\x1b[0m\n", .{self.config.improve_interval});
        std.debug.print("\x1b[38;2;255;215;0m║  Episode window: {d:3}                        ║\x1b[0m\n", .{self.config.episode_window});
        std.debug.print("\x1b[38;2;255;215;0m╠════════════════════════════════════════════════════╣\x1b[0m\n", .{});
        std.debug.print("\x1b[38;2;255;215;0m║  φ² + 1/φ² = {d:.1} = TRINITY                    ║\x1b[0m\n", .{TRINITY_IDENTITY});
        std.debug.print("\x1b[38;2;255;215;0m╚════════════════════════════════════════════════════╝\x1b[0m\n", .{});
        std.debug.print("\n", .{});

        // Main server loop
        var server = self.server.?;
        while (true) {
            const connection = server.accept() catch |err| {
                std.debug.print("Accept failed: {}\n", .{err});
                continue;
            };

            // Handle connection in blocking mode for simplicity
            self.handleConnection(connection.stream) catch |err| {
                std.debug.print("Connection error: {}\n", .{err});
            };
        }
    }

    /// Handle single HTTP connection
    fn handleConnection(self: *QueenBackend, stream: std.net.Stream) !void {
        var buffer: [4096]u8 = undefined;
        const request_data = stream.read(&buffer) catch |err| {
            std.debug.print("Read failed: {}\n", .{err});
            return;
        };

        if (request_data == 0) return;

        // Parse HTTP request
        const request_text = buffer[0..request_data];
        var lines = std.mem.splitScalar(u8, request_text, '\n');

        const request_line = lines.next() orelse return;
        var parts = std.mem.splitScalar(u8, request_line, ' ');

        const method = parts.next() orelse return;
        const path = parts.next() orelse return;

        // Route request (pass path with query string for /api/episodes filtering)
        const response = try self.routeRequest(method, path, request_text);

        // Send response
        _ = try stream.writeAll(response);
    }

    /// Route HTTP request to handler
    fn routeRequest(self: *QueenBackend, method: []const u8, path: []const u8, body: []const u8) ![]const u8 {
        // Strip query string if present
        const clean_path = if (std.mem.indexOfScalar(u8, path, '?')) |idx|
            path[0..idx]
        else
            path;

        // Health check endpoint (for Railway)
        if (std.mem.eql(u8, clean_path, "/health")) {
            return try self.handleHealth();
        }

        // API endpoints
        if (std.mem.startsWith(u8, clean_path, "/api/")) {
            const endpoint = clean_path["/api/".len..];

            if (std.mem.eql(u8, endpoint, "status")) {
                return try self.handleStatus();
            } else if (std.mem.eql(u8, endpoint, "episodes")) {
                if (std.mem.eql(u8, method, "POST")) {
                    return try self.handleEpisodesPost(body);
                } else {
                    return try self.handleEpisodes(path);
                }
            } else if (std.mem.eql(u8, endpoint, "improve")) {
                if (std.mem.eql(u8, method, "POST")) {
                    return try self.handleImprove(body);
                } else {
                    return try self.errorResponse("Method not allowed", 405);
                }
            } else if (std.mem.eql(u8, endpoint, "tri-spec")) {
                return try self.handleTriSpec();
            } else if (std.mem.eql(u8, endpoint, "pipeline")) {
                return try self.handlePipeline();
            } else {
                return try self.errorResponse("Not found", 404);
            }
        }

        // Root endpoint
        if (std.mem.eql(u8, clean_path, "/")) {
            return try self.handleRoot();
        }

        return try self.errorResponse("Not found", 404);
    }

    /// Handle GET / - Root endpoint with API info
    fn handleRoot(self: *const QueenBackend) ![]const u8 {
        const uptime = std.time.nanoTimestamp() - self.health.started_at;
        const uptime_s = @as(u64, @intCast(@divTrunc(uptime, 1_000_000_000)));

        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"name":"Queen Backend","version":"1.0.0","trinity_signature":{d:.6},
            \\"endpoints":["/health","/api/status","/api/episodes","/api/improve","/api/pipeline"],
            \\"uptime_seconds":{d}}}
        , .{ TRINITY_IDENTITY, uptime_s });

        return try self.httpResponse("application/json", body);
    }

    /// Handle GET /health - Health check for Railway
    fn handleHealth(self: *const QueenBackend) ![]const u8 {
        const uptime = std.time.nanoTimestamp() - self.health.started_at;
        const uptime_s = @as(u64, @intCast(@divTrunc(uptime, 1_000_000_000)));

        const health = HealthResponse{
            .status = "ok",
            .trinity_signature = TRINITY_IDENTITY,
            .improve_cycles = self.health.improve_cycles,
            .uptime_seconds = uptime_s,
        };

        const body = try std.json.Stringify.valueAlloc(self.allocator, health, .{});

        return try self.httpResponse("application/json", body);
    }

    /// Handle GET /api/status - System status
    fn handleStatus(self: *const QueenBackend) ![]const u8 {
        // Load tri27 config (not implemented - use placeholder)
        const tri27_config = Tri27Config{
            .auto_adapt = false,
        };

        const status = SystemStatus{
            .trinity_identity = TRINITY_IDENTITY,
            .env_status = if (tri27_config.auto_adapt) .active else .maintenance,
            .swarm_active = false,
            .last_improve = null,
        };

        const body = try std.json.Stringify.valueAlloc(self.allocator, status, .{});

        return try self.httpResponse("application/json", body);
    }

    /// Handle GET /api/episodes - Recent episodes with optional filters
    /// Query params: ?agent={name}&type={task|observation|action|error}
    fn handleEpisodes(self: *const QueenBackend, path_with_query: []const u8) ![]const u8 {
        // Import jsonl_reader for loading JSONL episodes
        const jsonl_reader = @import("jsonl_reader.zig");
        const EpisodeType = @import("episode_handler.zig").EpisodeType;

        // Parse query parameters
        var agent_filter: ?[]const u8 = null;
        var type_filter: ?EpisodeType = null;

        if (std.mem.indexOfScalar(u8, path_with_query, '?')) |query_start| {
            const query_str = path_with_query[query_start + 1 ..];
            var params = std.mem.splitScalar(u8, query_str, '&');

            while (params.next()) |param| {
                var kv = std.mem.splitScalar(u8, param, '=');
                const key = kv.next() orelse continue;
                const value = kv.next() orelse continue;

                if (std.mem.eql(u8, key, "agent")) {
                    agent_filter = value;
                } else if (std.mem.eql(u8, key, "type")) {
                    // Map string to EpisodeType
                    type_filter = std.meta.stringToEnum(EpisodeType, value) orelse continue;
                }
            }
        }

        std.debug.print("📊 GET /api/episodes agent={s} type={s}\n", .{
            if (agent_filter) |a| a else "(all)",
            if (type_filter) |t| @tagName(t) else "(all)",
        });

        std.debug.print("🔍 Loading from JSONL files with filters\n", .{});

        // Load episodes from JSONL with filters
        const jsonl_config = jsonl_reader.JsonlEpisodesConfig{
            .logs_dir = ".trinity/logs",
            .agent_filter = agent_filter,
            .type_filter = type_filter,
            .max_count = self.config.episode_window,
        };

        const loaded_episodes = jsonl_reader.loadJsonlEpisodes(self.allocator, jsonl_config) catch |err| {
            std.debug.print("Failed to load JSONL episodes: {}\n", .{err});
            return try self.errorResponse("Failed to load episodes", 500);
        };
        defer {
            for (loaded_episodes) |ep| {
                if (ep.context.active_issues.len > 0)
                    self.allocator.free(ep.context.active_issues);
            }
            self.allocator.free(loaded_episodes);
        }

        // Create simplified response for debugging
        var summaries = try std.ArrayList(struct {
            id: u64,
            timestamp: u64,
            source: episodes.Source,
            success: bool,
        }).initCapacity(self.allocator, loaded_episodes.len);

        for (loaded_episodes) |ep| {
            try summaries.append(self.allocator, .{
                .id = ep.id,
                .timestamp = ep.timestamp,
                .source = ep.source,
                .success = ep.result.success,
            });
        }

        const response_body = try std.json.Stringify.valueAlloc(self.allocator, summaries.items, .{});
        return try self.httpResponse("application/json", response_body);
    }

    /// Handle POST /api/episodes - Log new episode from JSON body
    fn handleEpisodesPost(self: *QueenBackend, body: []const u8) ![]const u8 {
        // Extract JSON body from HTTP request
        const json_body = if (std.mem.indexOf(u8, body, "\r\n\r\n")) |idx|
            body[idx + 4 ..]
        else if (std.mem.indexOf(u8, body, "\n\n")) |idx|
            body[idx + 2 ..]
        else
            body;

        // Parse JSON into EpisodeRequest
        const parsed = episode_handler.parseEpisode(self.allocator, json_body) catch |err| {
            std.debug.print("Failed to parse episode JSON: {}\n", .{err});
            return try self.errorResponse("Invalid JSON body", 400);
        };
        defer parsed.deinit();

        const episode = parsed.value;

        // Log episode to JSONL file
        self.logger.log(self.allocator, episode) catch |err| {
            std.debug.print("Failed to log episode: {}\n", .{err});
            return try self.errorResponse("Failed to log episode", 500);
        };

        std.debug.print("✅ Episode logged: {s} (agent={s}, type={s})\n", .{
            episode.episode_id, episode.agent, @tagName(episode.episode_type),
        });

        // Return success response
        const response_body = try std.fmt.allocPrint(self.allocator,
            \\{{"success":true,"episode_id":"{s}","trinity_signature":{d:.6}}}
        , .{ episode.episode_id, TRINITY_IDENTITY });

        return try self.httpResponse("application/json", response_body);
    }

    /// Handle POST /api/improve - Trigger self-improvement
    fn handleImprove(self: *QueenBackend, body: []const u8) ![]const u8 {
        _ = body;

        std.debug.print("🔄 Self-improvement cycle triggered\n", .{});

        // Use AutoImprove for self-improvement cycle
        var engine = auto_improve.init(self.allocator);
        const result = try engine.runCycle();

        std.debug.print("✅ Applied {d} deltas, {d} patterns found\n", .{ result.applied_deltas, result.patterns_found });

        // Update health stats
        self.health.improve_cycles += 1;
        self.health.last_improve_time = @truncate(std.time.nanoTimestamp());

        const response = ImproveResponse{
            .success = result.success,
            .message = result.message,
            .applied_deltas = result.applied_deltas,
            .quality_score = result.quality_score,
            .patterns_found = result.patterns_found,
            .cycles_analyzed = result.cycles_analyzed,
        };

        const body_json = try std.json.Stringify.valueAlloc(self.allocator, response, .{});
        return try self.httpResponse("application/json", body_json);
    }

    /// Handle GET /api/tri-spec - Episode to .tri spec conversion
    fn handleTriSpec(self: *const QueenBackend) ![]const u8 {
        std.debug.print("📋 Generating .tri spec from episodes\n", .{});

        // Import jsonl_reader for loading JSONL episodes
        const jsonl_reader = @import("jsonl_reader.zig");

        // Load episodes from JSONL
        const jsonl_config = jsonl_reader.JsonlEpisodesConfig{
            .logs_dir = ".trinity/logs",
            .agent_filter = null,
            .type_filter = null,
            .max_count = self.config.episode_window,
        };

        const recent_episodes = jsonl_reader.loadJsonlEpisodes(self.allocator, jsonl_config) catch |err| {
            std.debug.print("Failed to load JSONL episodes: {}\n", .{err});
            return try self.errorResponse("Failed to load episodes", 500);
        };
        defer {
            for (recent_episodes) |ep| {
                if (ep.context.active_issues.len > 0)
                    self.allocator.free(ep.context.active_issues);
            }
            self.allocator.free(recent_episodes);
        }

        std.debug.print("📊 Loaded {d} episodes for spec generation\n", .{recent_episodes.len});

        // Initialize AutoImprove to analyze episodes
        var engine = auto_improve.init(self.allocator);

        // Calculate quality score from loaded episodes
        var success_count: usize = 0;
        var total_count: usize = 0;

        for (recent_episodes) |ep| {
            if (ep.result.success) {
                success_count += 1;
            }
            total_count += 1;
        }

        const quality_score: f64 = if (total_count > 0)
            @as(f64, @floatFromInt(success_count)) / @as(f64, @floatFromInt(total_count))
        else
            0.0;

        std.debug.print("📈 Quality score: {d:.3} ({d}/{d})\n", .{
            quality_score, success_count, total_count,
        });

        // Analyze patterns from episodes
        const patterns = try engine.analyzePatterns(recent_episodes);
        defer self.allocator.free(patterns);

        // Generate .tri spec based on quality score and patterns
        const spec = try engine.generateTriSpec(quality_score, patterns);

        std.debug.print("✅ Generated .tri spec: {d} bytes\n", .{spec.len});

        return try self.httpResponse("text/x-yaml", spec);
    }

    /// Handle GET /api/pipeline - Pipeline status
    fn handlePipeline(self: *const QueenBackend) ![]const u8 {
        const pipeline_status = try std.fmt.allocPrint(self.allocator,
            \\{{"status":"ready","trinity_signature":{d:.6},
            \\"golden_chain_links":22,
            \\"last_run":null,
            \\"auto_improve_enabled":true}}
        , .{TRINITY_IDENTITY});

        return try self.httpResponse("application/json", pipeline_status);
    }

    /// Create HTTP response
    fn httpResponse(self: *const QueenBackend, content_type: []const u8, body: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "X-Trinity-Signature: {d:.6}\r\n" ++
            "\r\n" ++
            "{s}", .{ content_type, body.len, TRINITY_IDENTITY, body });
    }

    /// Create error response
    fn errorResponse(self: *const QueenBackend, message: []const u8, status: u16) ![]const u8 {
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"error":"{s}","trinity_signature":{d:.6}}}
        , .{ message, TRINITY_IDENTITY });

        const status_line = if (status == 404) "404 Not Found" else if (status == 405) "405 Method Not Allowed" else if (status == 500) "500 Internal Server Error" else "500 Internal Server Error";

        return try std.fmt.allocPrint(self.allocator, "HTTP/1.1 {s}\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "X-Trinity-Signature: {d:.6}\r\n" ++
            "\r\n" ++
            "{s}", .{ status_line, body.len, TRINITY_IDENTITY, body });
    }
};

// ============================================================================
// CLI ENTRY POINT
// ============================================================================

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Skip program name
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cmd_args = if (args.len > 1) args[1..] else &[_][]const u8{};
    try runBackendCommand(allocator, cmd_args);
}

pub fn runBackendCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var config = BackendConfig{};

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--port") and i + 1 < args.len) {
            i += 1;
            config.port = try std.fmt.parseUnsigned(u16, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--interval") and i + 1 < args.len) {
            i += 1;
            config.improve_interval = try std.fmt.parseUnsigned(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--window") and i + 1 < args.len) {
            i += 1;
            config.episode_window = try std.fmt.parseUnsigned(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printBackendHelp();
            return;
        }
    }

    // Start server
    var backend = QueenBackend.initWithConfig(allocator, config);
    try backend.start();
}

fn printBackendHelp() void {
    std.debug.print(
        \\╔══════════════════════════════════════════════════════════════╗
        \\║  Queen Backend Server — HTTP/JSON API for Container       ║
        \\╠══════════════════════════════════════════════════════════════╣
        \\║  Usage: tri queen backend [OPTIONS]                       ║
        \\║  Options:                                                ║
        \\║    --port <PORT>        HTTP port (default: 8080)          ║
        \\║    --interval <SEC>     Auto-improve interval (default: 3600)║
        \\║    --window <N>         Episode window size (default: 100)   ║
        \\║    --help, -h           Show this help                       ║
        \\║  Endpoints:                                               ║
        \\║    GET  /health          Health check (Railway)            ║
        \\║    GET  /api/status      System status                      ║
        \\║    GET  /api/episodes    Recent episodes                    ║
        \\║    POST /api/improve     Trigger self-improvement           ║
        \\║    GET  /api/pipeline    Pipeline status                    ║
        \\║  φ² + 1/φ² = 3 = TRINITY                                  ║
        \\╚══════════════════════════════════════════════════════════════╝
    , .{});
}

// ============================================================================
// TESTS
// ============================================================================

test "backend: QueenBackend init" {
    const allocator = std.testing.allocator;
    const backend = QueenBackend.init(allocator);

    try std.testing.expectEqual(TRINITY_IDENTITY, 3.0);
    try std.testing.expectEqual(DEFAULT_PORT, backend.config.port);
    try std.testing.expectEqual(IMPROVE_INTERVAL, backend.config.improve_interval);
}

test "backend: httpResponse creates valid HTTP" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.httpResponse("application/json", "{\"test\":true}");

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Content-Type: application/json") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "X-Trinity-Signature: 3.000000") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "{\"test\":true}") != null);

    allocator.free(response);
}

test "backend: errorResponse creates valid error" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.errorResponse("Test error", 404);

    try std.testing.expect(std.mem.indexOf(u8, response, "404 Not Found") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"error\":\"Test error\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "X-Trinity-Signature: 3.000000") != null);

    allocator.free(response);
}

test "backend: routeRequest /health" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/health", "");

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"status\":\"ok\"") != null);

    allocator.free(response);
}

test "backend: routeRequest /api/status" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/api/status", "");

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "trinity_identity") != null);

    allocator.free(response);
}

test "backend: routeRequest unknown path returns 404" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/unknown", "");

    try std.testing.expect(std.mem.indexOf(u8, response, "404 Not Found") != null);

    allocator.free(response);
}
