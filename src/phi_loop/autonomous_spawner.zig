//! PHI LOOP v8.59 — Autonomous Sub-Agent Spawner
//!
//! Gives Agent MU the ability to independently create sub-agents
//! on request from TRI COMMANDER
//!
//! Integration points:
//! - TRI COMMANDER → requests sub-agent
//! - Agent MU → validates and spawns via MCP
//! - PHI LOOP → tracks spawn events in consciousness chain

const std = @import("std");
const cluster = @import("cluster.zig");
const mcp_nexus = @import("../agent_mu/mcp_nexus.zig");
const sub_agent_orchestrator = @import("../agent_mu/sub_agent_orchestrator.zig");

/// Spawn Request from TRI COMMANDER
pub const SpawnRequest = struct {
    request_id: []const u8,
    task_description: []const u8,
    agent_type: sub_agent_orchestrator.AgentType,
    model: mcp_nexus.ModelType,
    priority: Priority,
    timeout_ms: u64,
    requested_by: []const u8, // "TRI_COMMANDER", "NODE_ALPHA", etc.

    pub fn deinit(self: *const SpawnRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.request_id);
        allocator.free(self.task_description);
        allocator.free(self.requested_by);
    }
};

/// Priority for spawn requests
pub const Priority = enum {
    low,
    normal,
    high,
    critical,

    pub fn weight(p: Priority) f64 {
        return switch (p) {
            .low => 0.5,
            .normal => 1.0,
            .high => cluster.PHI,
            .critical => cluster.PHI_SQ,
        };
    }
};

/// Spawn Result
pub const SpawnResult = struct {
    request_id: []const u8,
    agent_id: []const u8,
    success: bool,
    spawn_time_ms: u64,
    error_message: []const u8,

    pub fn deinit(self: *const SpawnResult, allocator: std.mem.Allocator) void {
        allocator.free(self.request_id);
        allocator.free(self.agent_id);
        allocator.free(self.error_message);
    }
};

/// Autonomous Spawner
pub const AutonomousSpawner = struct {
    allocator: std.mem.Allocator,
    nexus: *mcp_nexus.McpNexus,
    orchestrator: *sub_agent_orchestrator.SubAgentOrchestrator,
    cluster_state: *cluster.ClusterState,
    active_spawns: std.StringHashMap(SpawnResult),
    spawn_history: std.ArrayListUnmanaged(SpawnResult),
    total_spawns: u32,
    successful_spawns: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        nexus: *mcp_nexus.McpNexus,
        orchestrator: *sub_agent_orchestrator.SubAgentOrchestrator,
        cluster_state: *cluster.ClusterState,
    ) AutonomousSpawner {
        return AutonomousSpawner{
            .allocator = allocator,
            .nexus = nexus,
            .orchestrator = orchestrator,
            .cluster_state = cluster_state,
            .active_spawns = std.StringHashMap(SpawnResult).init(allocator),
            .spawn_history = std.ArrayListUnmanaged(SpawnResult){},
            .total_spawns = 0,
            .successful_spawns = 0,
        };
    }

    pub fn deinit(self: *AutonomousSpawner) void {
        {
            var it = self.active_spawns.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            self.active_spawns.deinit();
        }

        for (self.spawn_history.items) |*result| {
            result.deinit(self.allocator);
        }
        self.spawn_history.deinit(self.allocator);
    }

    /// Handle spawn request from TRI COMMANDER
    pub fn handleSpawnRequest(self: *AutonomousSpawner, request: SpawnRequest) !SpawnResult {
        self.total_spawns += 1;

        const start_time = std.time.nanoTimestamp();

        // Validate request
        if (!self.validateRequest(&request)) {
            return SpawnResult{
                .request_id = try self.allocator.dupe(u8, request.request_id),
                .agent_id = "",
                .success = false,
                .spawn_time_ms = 0,
                .error_message = try self.allocator.dupe(u8, "Request validation failed"),
            };
        }

        // Check if we're at max capacity
        if (self.active_spawns.count() >= cluster.MAX_SUB_AGENTS) {
            return SpawnResult{
                .request_id = try self.allocator.dupe(u8, request.request_id),
                .agent_id = "",
                .success = false,
                .spawn_time_ms = 0,
                .error_message = try self.allocator.dupe(u8, "Maximum sub-agent capacity reached"),
            };
        }

        // Spawn the sub-agent via MCP
        const agent_id = try self.spawnViaMCP(&request);

        const end_time = std.time.nanoTimestamp();
        const spawn_time_ms = @as(u64, @intCast((end_time - start_time) / 1_000_000));

        const result = SpawnResult{
            .request_id = try self.allocator.dupe(u8, request.request_id),
            .agent_id = try self.allocator.dupe(u8, agent_id),
            .success = true,
            .spawn_time_ms = spawn_time_ms,
            .error_message = try self.allocator.dupe(u8, ""),
        };

        self.successful_spawns += 1;

        // Track in active spawns
        const key = try self.allocator.dupe(u8, agent_id);
        try self.active_spawns.put(key, result);

        // Add to history
        try self.spawn_history.append(self.allocator, result);

        // Propagate intelligence to cluster
        try self.cluster_state.propagateIntelligence(cluster.MU);

        std.log.info("Sub-agent spawned: {s} for request {s}", .{ agent_id, request.request_id });

        return result;
    }

    /// Validate spawn request
    fn validateRequest(self: *AutonomousSpawner, request: *const SpawnRequest) bool {
        // Check for empty task description
        if (request.task_description.len == 0) return false;

        // Check for reasonable timeout
        if (request.timeout_ms > 300000) return false; // 5 minutes max

        // Check if requested_by is a valid source
        // Valid sources: TRI_COMMANDER, NODE_ALPHA, NODE_BETA, NODE_GAMMA
        const valid_sources = [_][]const u8{
            "TRI_COMMANDER",
            "NODE_ALPHA",
            "NODE_BETA",
            "NODE_GAMMA",
        };

        var valid_source = false;
        for (valid_sources) |source| {
            if (std.mem.eql(u8, request.requested_by, source)) {
                valid_source = true;
                break;
            }
        }

        _ = self;
        return valid_source;
    }

    /// Spawn sub-agent via MCP Nexus
    fn spawnViaMCP(self: *AutonomousSpawner, request: *const SpawnRequest) ![]const u8 {
        // Create sub-agent config
        const agent_type_name = try self.allocator.dupe(u8, @tagName(request.agent_type));
        defer self.allocator.free(agent_type_name);

        const task_desc = try self.allocator.dupe(u8, request.task_description);
        defer self.allocator.free(task_desc);

        const config = mcp_nexus.SubAgentConfig{
            .agent_type = agent_type_name,
            .task_description = task_desc,
            .timeout_ms = request.timeout_ms,
            .model = request.model,
        };
        defer config.deinit(self.allocator);

        // Call MCP to spawn
        const result = try self.nexus.spawnSubAgent(config);

        // Generate agent ID from result
        const agent_id = try std.fmt.allocPrint(
            self.allocator,
            "agent-{d}",
            .{std.time.nanoTimestamp()},
        );

        return agent_id;
    }

    /// Complete a spawn (agent finished task)
    pub fn completeSpawn(self: *AutonomousSpawner, agent_id: []const u8) !void {
        if (self.active_spawns.fetchRemove(agent_id)) |entry| {
            entry.value.deinit(self.allocator);
        }

        std.log.info("Sub-agent completed: {s}", .{agent_id});
    }

    /// Get spawn statistics
    pub fn getSpawnStats(self: *const AutonomousSpawner) struct {
        total_spawns: u32,
        successful_spawns: u32,
        active_spawns: u32,
        success_rate: f64,
    } {
        const success_rate = if (self.total_spawns > 0)
            @as(f64, @floatFromInt(self.successful_spawns)) / @as(f64, @floatFromInt(self.total_spawns))
        else
            0.0;

        return .{
            .total_spawns = self.total_spawns,
            .successful_spawns = self.successful_spawns,
            .active_spawns = @intCast(self.active_spawns.count()),
            .success_rate = success_rate,
        };
    }

    /// Batch spawn multiple agents
    pub fn batchSpawn(self: *AutonomousSpawner, requests: []const SpawnRequest) ![]SpawnResult {
        var results = std.ArrayList(SpawnResult).init(self.allocator);

        for (requests) |request| {
            // Clone request for ownership
            const req_copy = SpawnRequest{
                .request_id = try self.allocator.dupe(u8, request.request_id),
                .task_description = try self.allocator.dupe(u8, request.task_description),
                .agent_type = request.agent_type,
                .model = request.model,
                .priority = request.priority,
                .timeout_ms = request.timeout_ms,
                .requested_by = try self.allocator.dupe(u8, request.requested_by),
            };

            const result = try self.handleSpawnRequest(req_copy);
            try results.append(result);

            // Cleanup cloned request
            self.allocator.free(req_copy.request_id);
            self.allocator.free(req_copy.task_description);
            self.allocator.free(req_copy.requested_by);
        }

        return results.toOwnedSlice();
    }

    /// Create autonomous spawn request for Agent MU
    pub fn createAgentMuRequest(
        allocator: std.mem.Allocator,
        task_description: []const u8,
    ) !SpawnRequest {
        const request_id = try std.fmt.allocPrint(allocator, "mu-auto-{d}", .{std.time.nanoTimestamp()});

        return SpawnRequest{
            .request_id = request_id,
            .task_description = try allocator.dupe(u8, task_description),
            .agent_type = .general_purpose,
            .model = .inherit,
            .priority = .normal,
            .timeout_ms = 30000,
            .requested_by = try allocator.dupe(u8, "TRI_COMMANDER"),
        };
    }
};

test "Autonomous Spawner - initialization" {
    const allocator = std.testing.allocator;

    var nexus = mcp_nexus.McpNexus.init(allocator);
    var cluster_state = cluster.ClusterState.init(allocator);
    try cluster_state.initializeCluster();
    defer cluster_state.deinit();

    var orchestrator = sub_agent_orchestrator.SubAgentOrchestrator.init(
        allocator,
        10,
        &nexus,
    );
    defer orchestrator.deinit();

    var spawner = AutonomousSpawner.init(allocator, &nexus, &orchestrator, &cluster_state);
    defer spawner.deinit();

    const stats = spawner.getSpawnStats();
    try std.testing.expectEqual(@as(u32, 0), stats.total_spawns);
}

test "Validate spawn request" {
    const allocator = std.testing.allocator;

    var nexus = mcp_nexus.McpNexus.init(allocator);
    var cluster_state = cluster.ClusterState.init(allocator);
    defer cluster_state.deinit();

    var orchestrator = sub_agent_orchestrator.SubAgentOrchestrator.init(
        allocator,
        10,
        &nexus,
    );
    defer orchestrator.deinit();

    var spawner = AutonomousSpawner.init(allocator, &nexus, &orchestrator, &cluster_state);
    defer spawner.deinit();

    const valid_request = SpawnRequest{
        .request_id = "test-req",
        .task_description = "Do something",
        .agent_type = .general_purpose,
        .model = .haiku,
        .priority = .normal,
        .timeout_ms = 10000,
        .requested_by = "TRI_COMMANDER",
    };

    try std.testing.expect(spawner.validateRequest(&valid_request));
}
