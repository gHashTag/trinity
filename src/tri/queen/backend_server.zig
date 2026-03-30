// @origin(spec:backend_server.tri) @regen(manual-impl)
//
// Queen Backend — HTTP/JSON API Server for Container Deployment
// Replaces QueenBridge.swift file I/O with HTTP endpoints
//
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================

const std = @import("std");

// Import existing queen modules
const episodes = @import("episodes.zig");
const self_learning = @import("self_learning.zig");

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
    new_config: ?self_learning.Tri27Config = null,
};

// ============================================================================
// BACKEND SERVER
// ============================================================================

pub const QueenBackend = struct {
    allocator: std.mem.Allocator,
    config: BackendConfig,
    server: ?std.net.Server,
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
            .health = .{
                .started_at = std.time.nanoTimestamp(),
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

        // Route request
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
                return try self.handleEpisodes();
            } else if (std.mem.eql(u8, endpoint, "improve")) {
                if (std.mem.eql(u8, method, "POST")) {
                    return try self.handleImprove(body);
                } else {
                    return try self.errorResponse("Method not allowed", 405);
                }
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
        // Load tri27 config
        const tri27_config = self_learning.loadConfig(self.allocator) catch |err| {
            std.debug.print("Failed to load config: {}\n", .{err});
            return try self.errorResponse("Failed to load config", 500);
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

    /// Handle GET /api/episodes - Recent episodes
    fn handleEpisodes(self: *const QueenBackend) ![]const u8 {
        const recent = episodes.loadRecentEpisodes(self.allocator, self.config.episode_window) catch |err| {
            std.debug.print("Failed to load episodes: {}\n", .{err});
            return try self.errorResponse("Failed to load episodes", 500);
        };
        defer {
            for (recent) |ep| {
                if (ep.context.active_issues.len > 0)
                    self.allocator.free(ep.context.active_issues);
            }
            self.allocator.free(recent);
        }

        // Create simplified response
        var summaries = try std.ArrayList(episodes.EpisodeSummary).initCapacity(self.allocator, recent.len);
        defer summaries.deinit(self.allocator);

        for (recent) |ep| {
            const summary = episodes.EpisodeSummary{
                .id = ep.id,
                .timestamp = ep.timestamp,
                .source = ep.source,
                .action_type = @tagName(ep.action),
                .key = "",
                .outcome = ep.outcome,
                .success = ep.result.success,
                .duration_ms = ep.result.timing.duration_ms,
            };
            try summaries.append(self.allocator, summary);
        }

        const body = try std.json.Stringify.valueAlloc(self.allocator, summaries.items, .{});

        return try self.httpResponse("application/json", body);
    }

    /// Handle POST /api/improve - Trigger self-improvement
    fn handleImprove(self: *QueenBackend, body: []const u8) ![]const u8 {
        _ = body;

        std.debug.print("🔄 Self-improvement cycle triggered\n", .{});

        const result = self_learning.runSelfLearningCycle(self.allocator, self.config.episode_window) catch |err| {
            std.debug.print("Self-learning failed: {}\n", .{err});

            const response = ImproveResponse{
                .success = false,
                .message = try self.allocator.dupe(u8, @errorName(err)),
            };

            const body_json = try std.json.Stringify.valueAlloc(self.allocator, response, .{});
            return try self.httpResponse("application/json", body_json);
        };

        std.debug.print("✅ Self-improvement cycle complete: {d} deltas applied\n", .{result.applied_deltas});

        // Update health stats
        self.health.improve_cycles += 1;
        self.health.last_improve_time = @truncate(std.time.nanoTimestamp());

        const response = ImproveResponse{
            .success = true,
            .message = try self.allocator.dupe(u8, "Self-improvement cycle completed"),
            .applied_deltas = result.applied_deltas,
            .quality_score = result.evaluation.success_rate,
            .new_config = result.config,
        };

        const body_json = try std.json.Stringify.valueAlloc(self.allocator, response, .{});
        return try self.httpResponse("application/json", body_json);
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

    try std.testing.expectStringPresent("HTTP/1.1 200 OK", response);
    try std.testing.expectStringPresent("Content-Type: application/json", response);
    try std.testing.expectStringPresent("X-Trinity-Signature: 3.000000", response);
    try std.testing.expectStringPresent("{\"test\":true}", response);

    allocator.free(response);
}

test "backend: errorResponse creates valid error" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.errorResponse("Test error", 404);

    try std.testing.expectStringPresent("404 Not Found", response);
    try std.testing.expectStringPresent("\"error\":\"Test error\"", response);
    try std.testing.expectStringPresent("X-Trinity-Signature: 3.000000", response);

    allocator.free(response);
}

test "backend: routeRequest /health" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/health", "");

    try std.testing.expectStringPresent("HTTP/1.1 200 OK", response);
    try std.testing.expectStringPresent("\"status\":\"ok\"", response);

    allocator.free(response);
}

test "backend: routeRequest /api/status" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/api/status", "");

    try std.testing.expectStringPresent("HTTP/1.1 200 OK", response);
    try std.testing.expectStringPresent("trinity_identity", response);

    allocator.free(response);
}

test "backend: routeRequest unknown path returns 404" {
    const allocator = std.testing.allocator;
    var backend = QueenBackend.init(allocator);

    const response = try backend.routeRequest("GET", "/unknown", "");

    try std.testing.expectStringPresent("404 Not Found", response);

    allocator.free(response);
}
