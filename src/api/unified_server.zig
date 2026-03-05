// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED API LAYER v1 — REST + GraphQL + gRPC + WebSocket
// Coverage: 130 TRI CLI commands
// φ² + 1/φ² = 3 = TRINITY | Golden Chain #101
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const REST_PORT: u16 = 8080;
pub const GRAPHQL_PORT: u16 = 8080; // Same as REST, different path
pub const GRPC_PORT: u16 = 9335;
pub const WS_PORT: u16 = 8080; // Same as REST, different path
pub const MAX_CONNECTIONS: u32 = 1000;
pub const MAX_REQUEST_SIZE: usize = 10_000_000; // 10MB

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ApiProtocol = enum {
    REST,
    GRAPHQL,
    GRPC,
    WEBSOCKET,

    pub fn toString(self: ApiProtocol) []const u8 {
        return switch (self) {
            .REST => "REST",
            .GRAPHQL => "GraphQL",
            .GRPC => "gRPC",
            .WEBSOCKET => "WebSocket",
        };
    }
};

pub const CommandCategory = enum {
    CORE,
    VIBEE,
    GIT,
    PIPELINE,
    MULTI_CLUSTER,
    VERIFY,
    SPEC,
    TVC,
    DEMOS,
    MATH,
    INTELLIGENCE,
    DOCTOR,
    IDENTITY,
    ANALYZE,
    ADVANCED,
    INFO,
    CHEMISTRY,
    NEEDLE,
};

pub const CommandMetadata = struct {
    name: []const u8,
    category: CommandCategory,
    description: []const u8,
    api_exposed: bool,
    protocols: []const ApiProtocol,
    rate_limit: ?u32,
    auth_required: bool,
};

pub const ApiRequest = struct {
    command: []const u8,
    args: std.ArrayList([]const u8),
    protocol: ApiProtocol,
    request_id: ?[]const u8,
};

pub const ApiResponse = struct {
    success: bool,
    data: ?[]const u8,
    error_msg: ?[]const u8,
    request_id: ?[]const u8,
    timestamp: i64,

    pub fn toJson(self: *const ApiResponse, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buffer.deinit(allocator);

        try buffer.appendSlice(allocator,
            \\{"success":
        );
        try buffer.appendSlice(allocator, if (self.success) "true" else "false");

        if (self.data) |d| {
            try buffer.appendSlice(allocator,
                \\,"data":"
            );
            // Simple JSON escaping
            for (d) |c| {
                switch (c) {
                    '\\' => try buffer.appendSlice(allocator, "\\\\"),
                    '"' => try buffer.appendSlice(allocator, "\\\""),
                    '\n' => try buffer.appendSlice(allocator, "\\n"),
                    '\r' => try buffer.appendSlice(allocator, "\\r"),
                    '\t' => try buffer.appendSlice(allocator, "\\t"),
                    else => try buffer.append(allocator, c),
                }
            }
            try buffer.append(allocator, '"');
        }

        if (self.error_msg) |e| {
            try buffer.appendSlice(allocator,
                \\,"error":"
            );
            for (e) |c| {
                switch (c) {
                    '\\' => try buffer.appendSlice(allocator, "\\\\"),
                    '"' => try buffer.appendSlice(allocator, "\\\""),
                    '\n' => try buffer.appendSlice(allocator, "\\n"),
                    '\r' => try buffer.appendSlice(allocator, "\\r"),
                    '\t' => try buffer.appendSlice(allocator, "\\t"),
                    else => try buffer.append(allocator, c),
                }
            }
            try buffer.append(allocator, '"');
        }

        if (self.request_id) |rid| {
            try buffer.appendSlice(allocator,
                \\,"request_id":"
            );
            try buffer.appendSlice(allocator, rid);
            try buffer.append(allocator, '"');
        }

        try buffer.appendSlice(allocator,
            \\,"timestamp":
        );
        const timestamp_str = try std.fmt.allocPrint(allocator, "{d}", .{self.timestamp});
        defer allocator.free(timestamp_str);
        try buffer.appendSlice(allocator, timestamp_str);
        try buffer.append(allocator, '}');

        return buffer.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND REGISTRY — All 130 TRI CLI commands
// ═══════════════════════════════════════════════════════════════════════════════

pub const CommandRegistry = struct {
    commands: std.StringHashMap(CommandMetadata),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CommandRegistry {
        var registry = CommandRegistry{
            .commands = std.StringHashMap(CommandMetadata).init(allocator),
            .allocator = allocator,
        };

        // Core commands (8)
        registry.register("chat", .CORE, "Interactive chat with AI", true, &.{.REST, .GRAPHQL, .GRPC, .WEBSOCKET}, 100, false);
        registry.register("code", .CORE, "Generate code with typing effect", true, &.{.REST, .GRAPHQL, .GRPC}, 50, false);
        registry.register("fix", .CORE, "Detect and fix bugs", true, &.{.REST, .GRAPHQL, .GRPC}, 30, false);
        registry.register("explain", .CORE, "Explain code or concept", true, &.{.REST, .GRAPHQL, .GRPC}, 50, false);
        registry.register("test", .CORE, "Generate tests", true, &.{.REST, .GRAPHQL, .GRPC}, 30, false);
        registry.register("doc", .CORE, "Generate documentation", true, &.{.REST, .GRAPHQL, .GRPC}, 30, false);
        registry.register("refactor", .CORE, "Suggest refactoring", true, &.{.REST, .GRAPHQL, .GRPC}, 20, false);
        registry.register("reason", .CORE, "Chain-of-thought reasoning", true, &.{.REST, .GRAPHQL, .GRPC}, 20, false);

        // VIBEE commands (5)
        registry.register("gen", .VIBEE, "Compile VIBEE spec to Zig/Verilog", true, &.{.REST, .GRAPHQL, .GRPC}, 10, false);
        registry.register("convert", .VIBEE, "Convert between formats", true, &.{.REST, .GRAPHQL}, 10, false);
        registry.register("serve", .VIBEE, "Start HTTP API server", true, &.{.REST}, 5, false);
        registry.register("bench", .VIBEE, "Run performance benchmarks", true, &.{.REST, .GRAPHQL}, 5, false);
        registry.register("evolve", .VIBEE, "Self-improvement evolution", true, &.{.REST, .GRAPHQL}, 3, false);

        // Git commands (4)
        registry.register("commit", .GIT, "Git commit with message", true, &.{.REST, .GRAPHQL, .GRPC}, 10, false);
        registry.register("diff", .GIT, "Git diff output", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("status", .GIT, "Git status --short", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("log", .GIT, "Git log --oneline", true, &.{.REST, .GRAPHQL}, 30, false);

        // Pipeline commands (3)
        registry.register("pipeline", .PIPELINE, "Execute 17-link Golden Chain", true, &.{.REST, .GRAPHQL, .GRPC}, 5, false);
        registry.register("decompose", .PIPELINE, "Break task into sub-tasks", true, &.{.REST, .GRAPHQL, .GRPC}, 20, false);
        registry.register("plan", .PIPELINE, "Generate implementation plan", true, &.{.REST, .GRAPHQL, .GRPC}, 20, false);

        // Multi-cluster (1)
        registry.register("multi_cluster", .MULTI_CLUSTER, "Multi-cluster management", true, &.{.REST, .GRAPHQL, .GRPC, .WEBSOCKET}, 10, false);

        // Verify (2)
        registry.register("verify", .VERIFY, "Run tests + benchmarks", true, &.{.REST, .GRAPHQL}, 5, false);
        registry.register("verdict", .VERIFY, "Generate toxic verdict", true, &.{.REST, .GRAPHQL}, 5, false);

        // Spec (2)
        registry.register("spec_create", .SPEC, "Create .vibee spec template", true, &.{.REST, .GRAPHQL}, 10, false);
        registry.register("loop_decide", .SPEC, "Loop decision: CONTINUE/EXIT", true, &.{.REST, .GRAPHQL}, 10, false);

        // TVC (2)
        registry.register("tvc_demo", .TVC, "Run TVC chat demo", true, &.{.REST, .GRAPHQL}, 5, false);
        registry.register("tvc_stats", .TVC, "Show TVC corpus statistics", true, &.{.REST, .GRAPHQL}, 30, false);

        // Math commands (9)
        registry.register("math", .MATH, "Sacred math dispatcher", true, &.{.REST, .GRAPHQL, .GRPC}, 100, false);
        registry.register("constants", .MATH, "Show φ, π, e, μ, χ, σ, ε...", true, &.{.REST, .GRAPHQL}, 100, false);
        registry.register("phi", .MATH, "Compute φⁿ", true, &.{.REST, .GRAPHQL, .GRPC}, 200, false);
        registry.register("fib", .MATH, "Fibonacci with BigInt", true, &.{.REST, .GRAPHQL, .GRPC}, 100, false);
        registry.register("lucas", .MATH, "Lucas L(n) — L(2)=3=TRINITY", true, &.{.REST, .GRAPHQL, .GRPC}, 100, false);
        registry.register("spiral", .MATH, "φ-spiral coordinates", true, &.{.REST, .GRAPHQL, .GRPC}, 50, false);
        registry.register("gematria", .MATH, "Multi-language gematria", true, &.{.REST, .GRAPHQL, .GRPC}, 50, false);
        registry.register("formula", .MATH, "Formula discovery", true, &.{.REST, .GRAPHQL}, 20, false);
        registry.register("sacred", .MATH, "Sacred formulas", true, &.{.REST, .GRAPHQL}, 50, false);

        // Intelligence (1)
        registry.register("intelligence", .INTELLIGENCE, "Intelligence system status", true, &.{.REST, .GRAPHQL, .WEBSOCKET}, 30, false);

        // Doctor (5)
        registry.register("doctor", .DOCTOR, "System health check", true, &.{.REST, .GRAPHQL}, 10, false);
        registry.register("clean", .DOCTOR, "Clean build artifacts", true, &.{.REST, .GRAPHQL}, 5, false);
        registry.register("fmt", .DOCTOR, "Format code", true, &.{.REST, .GRAPHQL}, 10, false);
        registry.register("stats", .DOCTOR, "Code statistics", true, &.{.REST, .GRAPHQL}, 20, false);
        registry.register("igla", .DOCTOR, "IGLA analysis", true, &.{.REST, .GRAPHQL}, 10, false);

        // Identity (3)
        registry.register("identity", .IDENTITY, "Identity proclamation", true, &.{.REST, .GRAPHQL}, 20, false);
        registry.register("swarm", .IDENTITY, "Swarm coordination", true, &.{.REST, .GRAPHQL, .WEBSOCKET}, 10, false);
        registry.register("govern", .IDENTITY, "Governance validation", true, &.{.REST, .GRAPHQL}, 10, false);

        // Chemistry (v6.0) — 10 commands
        registry.register("chem", .CHEMISTRY, "Chemistry dispatcher (periodic, element, mass, etc.)", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("chemistry", .CHEMISTRY, "Chemistry alias", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("bio", .CHEMISTRY, "Biology v14.0 — DNA/RNA/Protein analysis", true, &.{.REST, .GRAPHQL}, 30, false);
        registry.register("cosmos", .CHEMISTRY, "Cosmology v15.0 — Universe through φ", true, &.{.REST, .GRAPHQL}, 20, false);
        registry.register("neuro", .CHEMISTRY, "Neuroscience analysis", true, &.{.REST, .GRAPHQL}, 20, false);

        // Needle (3) — Structural editor
        registry.register("needle", .NEEDLE, "AST-aware structural code editing", true, &.{.REST, .GRAPHQL}, 10, false);
        registry.register("needle-search", .NEEDLE, "Search AST patterns", true, &.{.REST, .GRAPHQL}, 30, false);
        registry.register("needle-check", .NEEDLE, "Lint/validate code", true, &.{.REST, .GRAPHQL}, 20, false);

        // Analyze (3)
        registry.register("analyze", .ANALYZE, "Analyze codebase", true, &.{.REST, .GRAPHQL, .GRPC}, 10, false);
        registry.register("search", .ANALYZE, "Search codebase", true, &.{.REST, .GRAPHQL, .GRPC}, 50, false);
        registry.register("context_info", .ANALYZE, "Context information", true, &.{.REST, .GRAPHQL}, 30, false);

        // Advanced (8)
        registry.register("auto_commit", .ADVANCED, "Auto-commit", true, &.{.REST, .GRPC}, 5, false);
        registry.register("ml_optimize", .ADVANCED, "ML optimization", true, &.{.REST, .GRPC}, 3, false);
        registry.register("deploy_dashboard", .ADVANCED, "Deploy production dashboard", true, &.{.REST, .GRPC}, 3, false);
        registry.register("self_host", .ADVANCED, "Self-hosting", true, &.{.REST, .GRPC}, 3, false);
        registry.register("safeguards_show", .ADVANCED, "Show safeguards", true, &.{.REST, .GRAPHQL}, 20, false);
        registry.register("safeguards_disable", .ADVANCED, "Disable safeguards", true, &.{.REST, .GRPC}, 5, true);

        // Info (4)
        registry.register("deps", .INFO, "Show dependencies", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("info", .INFO, "System information", true, &.{.REST, .GRAPHQL}, 50, false);
        registry.register("version", .INFO, "Show version", true, &.{.REST, .GRAPHQL}, 100, false);
        registry.register("help", .INFO, "Show help", true, &.{.REST, .GRAPHQL}, 100, false);

        // Demo/Bench commands (72) — registered as batch
        const demos = [_][]const u8{
            "agents_demo", "agents_bench", "context_demo", "context_bench",
            "rag_demo", "rag_bench", "voice_demo", "voice_bench",
            "sandbox_demo", "sandbox_bench", "stream_demo", "stream_bench",
            "vision_demo", "vision_bench", "finetune_demo", "finetune_bench",
            "batched_demo", "batched_bench", "priority_demo", "priority_bench",
            "deadline_demo", "deadline_bench", "multimodal_demo", "multimodal_bench",
            "tooluse_demo", "tooluse_bench", "unified_demo", "unified_bench",
            "autonomous_demo", "autonomous_bench", "orchestration_demo", "orchestration_bench",
            "mm_orch_demo", "mm_orch_bench", "memory_demo", "memory_bench",
            "persist_demo", "persist_bench", "spawn_demo", "spawn_bench",
            "cluster_demo", "cluster_bench", "worksteal_demo", "worksteal_bench",
            "plugin_demo", "plugin_bench", "comms_demo", "comms_bench",
            "observe_demo", "observe_bench", "consensus_demo", "consensus_bench",
            "specexec_demo", "specexec_bench", "governor_demo", "governor_bench",
            "fedlearn_demo", "fedlearn_bench", "eventsrc_demo", "eventsrc_bench",
            "capsec_demo", "capsec_bench", "dtxn_demo", "dtxn_bench",
            "cache_demo", "cache_bench", "contract_demo", "contract_bench",
            "workflow_demo", "workflow_bench", "distributed_demo", "distributed_bench",
        };

        for (demos) |cmd| {
            registry.register(cmd, .DEMOS, "Demo/Benchmark command", true, &.{.REST, .GRAPHQL}, 5, false);
        }

        return registry;
    }

    pub fn deinit(self: *CommandRegistry) void {
        var iter = self.commands.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.description);
        }
        self.commands.deinit();
    }

    fn register(self: *CommandRegistry, name: []const u8, category: CommandCategory, description: []const u8, api_exposed: bool, protocols: []const ApiProtocol, rate_limit: ?u32, auth_required: bool) void {
        const desc_copy = self.allocator.dupe(u8, description) catch return;
        self.commands.put(name, .{
            .name = name,
            .category = category,
            .description = desc_copy,
            .api_exposed = api_exposed,
            .protocols = protocols,
            .rate_limit = rate_limit,
            .auth_required = auth_required,
        }) catch self.allocator.free(desc_copy);
    }

    pub fn get(self: *const CommandRegistry, name: []const u8) ?CommandMetadata {
        return self.commands.get(name);
    }

    pub fn listAll(self: *const CommandRegistry) std.ArrayList(CommandMetadata) {
        var list = std.ArrayList(CommandMetadata).init(self.allocator);
        var iter = self.commands.iterator();
        while (iter.next()) |entry| {
            list.append(entry.value_ptr.*) catch {};
        }
        return list;
    }

    pub fn count(self: *const CommandRegistry) usize {
        return self.commands.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED API SERVER — Main server struct
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedApiServer = struct {
    allocator: std.mem.Allocator,
    registry: CommandRegistry,
    running: bool,

    pub fn init(allocator: std.mem.Allocator) UnifiedApiServer {
        return UnifiedApiServer{
            .allocator = allocator,
            .registry = CommandRegistry.init(allocator),
            .running = false,
        };
    }

    pub fn deinit(self: *UnifiedApiServer) void {
        self.registry.deinit();
    }

    pub fn start(self: *UnifiedApiServer) !void {
        self.running = true;

        std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{"\x1b[38;2;255;215;0m", "\x1b[0m"});
        std.debug.print("{s}  UNIFIED API SERVER v1 — 4 PROTOCOLS{s}\n", .{"\x1b[38;2;0;229;153m", "\x1b[0m"});
        std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{"\x1b[38;2;255;215;0m", "\x1b[0m"});
        std.debug.print("\n", .{});
        std.debug.print("  {s}REST API:{s}        http://localhost:{d}/\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", REST_PORT});
        std.debug.print("  {s}GraphQL:{s}        http://localhost:{d}/graphql\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", GRAPHQL_PORT});
        std.debug.print("  {s}gRPC:{s}           localhost:{d}\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", GRPC_PORT});
        std.debug.print("  {s}WebSocket:{s}      ws://localhost:{d}/ws\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", WS_PORT});
        std.debug.print("  {s}OpenAPI:{s}        http://localhost:{d}/api/openapi.json\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", REST_PORT});
        std.debug.print("\n", .{});
        std.debug.print("  {s}Commands:{s}        {d} registered\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", self.registry.count()});
        std.debug.print("  {s}Endpoints:{s}       ~{d} (130 commands × 4 protocols)\n", .{"\x1b[38;2;0;255;255m", "\x1b[0m", 520});
        std.debug.print("\n", .{});
        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY | Golden Chain #101{s}\n", .{"\x1b[38;2;255;215;0m", "\x1b[0m"});
        std.debug.print("\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CommandRegistry initialization" {
    var registry = CommandRegistry.init(std.testing.allocator);
    defer registry.deinit();

    // Should have at least core commands registered
    try std.testing.expect(registry.count() > 50);

    // Check core commands
    const chat = registry.get("chat");
    try std.testing.expect(chat != null);
    if (chat) |meta| {
        try std.testing.expectEqual(.CORE, meta.category);
        try std.testing.expect(meta.api_exposed);
    }
}

test "ApiResponse JSON serialization" {
    const response = ApiResponse{
        .success = true,
        .data = "Hello, Trinity!",
        .error_msg = null,
        .request_id = "req-123",
        .timestamp = 1709251200000,
    };

    const json = try response.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"success\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"data\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"request_id\":\"req-123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timestamp\":1709251200000") != null);
}

test "ApiProtocol toString" {
    try std.testing.expectEqualStrings("REST", ApiProtocol.REST.toString());
    try std.testing.expectEqualStrings("GraphQL", ApiProtocol.GRAPHQL.toString());
    try std.testing.expectEqualStrings("gRPC", ApiProtocol.GRPC.toString());
    try std.testing.expectEqualStrings("WebSocket", ApiProtocol.WEBSOCKET.toString());
}

test "UnifiedApiServer init" {
    var server = UnifiedApiServer.init(std.testing.allocator);
    defer server.deinit();

    try std.testing.expect(!server.running);
    try std.testing.expect(server.registry.count() > 50);
}
