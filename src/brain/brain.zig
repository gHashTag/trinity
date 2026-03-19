//! BRAIN — S³AI Neuroanatomy v5.1
//!
//! Aggregator module for all brain regions. Import this file to get
//! access to all S³AI neuroanatomy modules at once.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGION IMPORTS (provided as module imports in build.zig)
// ═══════════════════════════════════════════════════════════════════════════════

/// Basal Ganglia (Action Selection)
/// Task claim registry — prevents duplicate task execution across agents
pub const basal_ganglia = @import("basal_ganglia");

/// Reticular Formation (Broadcast Alerting)
/// Event bus — publishes task events for all agents to consume
pub const reticular_formation = @import("reticular_formation");

/// Locus Coeruleus (Arousal Regulation)
/// Backoff policy — regulates timing and retry behavior
pub const locus_coeruleus = @import("locus_coeruleus");

/// Hippocampus (Memory Persistence)
/// Event logging to JSONL for replay and analysis
pub const persistence = @import("persistence");

/// Corpus Callosum (Telemetry)
/// Time-series metrics aggregation
pub const telemetry = @import("telemetry");

/// Amygdala (Emotional Salience)
/// Detects emotionally significant events and prioritizes them
pub const amygdala = @import("amygdala");

/// Prefrontal Cortex (Executive Function)
/// Decision making, planning, and cognitive control
pub const prefrontal_cortex = @import("prefrontal_cortex");

/// Hippocampus (Health History)
/// Memory consolidation for brain health snapshots
pub const health_history = @import("health_history");

/// Thalamus (Sensory Relay)
/// Railway live logs relay
pub const thalamus_logs = @import("thalamus_logs");

/// Stress Test (Load Testing)
/// Brain load testing and stress testing utilities
pub const stress_test = @import("stress_test");

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN ATLAS — Complete Neuroanatomy
// ═══════════════════════════════════════════════════════════════════════════════

/// Brain region with its biological function and file location
pub const BrainRegion = struct {
    name: []const u8,
    biological_function: []const u8,
    file: []const u8,
};

/// Complete Trinity Brain Atlas — all brain regions with their roles
pub const BRAIN_ATLAS = [_]BrainRegion{
    .{
        .name = "Thalamus",
        .biological_function = "Sensory Relay — Railway live logs relay",
        .file = "thalamus_logs.zig",
    },
    .{
        .name = "Basal Ganglia",
        .biological_function = "Action Selection — prevents duplicate task execution",
        .file = "basal_ganglia.zig",
    },
    .{
        .name = "Reticular Formation",
        .biological_function = "Broadcast Alerting — event bus for all agents",
        .file = "reticular_formation.zig",
    },
    .{
        .name = "Locus Coeruleus",
        .biological_function = "Arousal Regulation — backoff/timing policy",
        .file = "locus_coeruleus.zig",
    },
    .{
        .name = "Amygdala",
        .biological_function = "Emotional Salience — prioritizes urgent/critical events",
        .file = "amygdala.zig",
    },
    .{
        .name = "Prefrontal Cortex",
        .biological_function = "Executive Function — decision making and planning",
        .file = "prefrontal_cortex.zig",
    },
    .{
        .name = "Intraparietal Sulcus",
        .biological_function = "Numerical Processing — f16/GF16/TF3 conversions",
        .file = "intraparietal_sulcus.zig",
    },
    .{
        .name = "Hippocampus",
        .biological_function = "Memory Persistence — JSONL event logging",
        .file = "persistence.zig",
    },
    .{
        .name = "Corpus Callosum",
        .biological_function = "Telemetry — time-series metrics aggregation",
        .file = "telemetry.zig",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT COORDINATION HELPER — High-level API for orchestrators
// ═══════════════════════════════════════════════════════════════════════════════

/// AgentCoordination — high-level wrapper combining all brain regions
/// for seamless integration into orchestrators and coordinators.
pub const AgentCoordination = struct {
    allocator: std.mem.Allocator,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
    backoff_policy: locus_coeruleus.BackoffPolicy,

    /// Initialize agent coordination with all brain regions
    pub fn init(allocator: std.mem.Allocator) !AgentCoordination {
        const registry = try basal_ganglia.getGlobal(allocator);
        const event_bus = try reticular_formation.getGlobal(allocator);
        return AgentCoordination{
            .allocator = allocator,
            .registry = registry,
            .event_bus = event_bus,
            .backoff_policy = locus_coeruleus.BackoffPolicy.init(),
        };
    }

    /// Claim a task for an agent — returns true if successful
    /// If false, use getBackoffDelay() to wait before retrying
    pub fn claimTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8) !bool {
        return try self.registry.claim(self.allocator, task_id, agent_id, 300000); // 5 min TTL
    }

    /// Refresh task heartbeat — call periodically while task is running
    pub fn refreshHeartbeat(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8) bool {
        return self.registry.heartbeat(task_id, agent_id);
    }

    /// Complete a task and publish completion event
    pub fn completeTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8, duration_ms: u64) !void {
        // Mark task as completed in registry
        _ = self.registry.complete(task_id, agent_id);

        // Publish task_completed event to reticular formation
        const event_data = reticular_formation.EventData{
            .task_completed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .duration_ms = duration_ms,
            },
        };

        _ = self.event_bus.publish(.task_completed, event_data);
    }

    /// Report task failure to reticular formation
    pub fn failTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8, err_msg: []const u8) !void {
        // Abandon task in registry
        _ = self.registry.abandon(task_id, agent_id);

        // Publish task_failed event
        const event_data = reticular_formation.EventData{
            .task_failed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .err_msg = err_msg,
            },
        };

        _ = self.event_bus.publish(.task_failed, event_data);
    }

    /// Get backoff delay for next retry attempt
    /// Call this when claimTask() returns false
    pub fn getBackoffDelay(self: *const AgentCoordination, attempt: u32) u64 {
        return self.backoff_policy.nextDelay(attempt);
    }

    /// Get current coordination statistics
    pub const CoordinationStats = struct {
        active_claims: usize,
        total_events_published: u64,
        total_events_polled: u64,
        buffered_events: usize,
    };

    pub fn getStats(self: *const AgentCoordination) CoordinationStats {
        const event_stats = self.event_bus.getStats();
        return CoordinationStats{
            .active_claims = self.registry.claims.count(),
            .total_events_published = event_stats.published,
            .total_events_polled = event_stats.polled,
            .buffered_events = event_stats.buffered,
        };
    }

    /// Poll recent events from reticular formation
    pub fn pollEvents(self: *AgentCoordination, since: i64, max_events: usize) ![]reticular_formation.AgentEventRecord {
        return self.event_bus.poll(since, self.allocator, max_events);
    }

    /// Health check for brain circuit — returns score 0-100
    /// Score = (claims_ok * 0.4 + events_ok * 0.4 + backoff_ok * 0.2) * 100
    pub fn healthCheck(self: *const AgentCoordination) struct {
        score: f32,
        healthy: bool,
        details: struct {
            claims_count: usize,
            events_published: u64,
            events_buffered: usize,
        },
    } {
        const stats = self.getStats();

        // Health criteria:
        // - Claims: should have reasonable count (not overflowing)
        // - Events: should be publishing and buffering
        // - Backoff: always healthy (policy is stateless)

        const claims_ok = stats.active_claims < 10_000; // Not overflowing
        const events_ok = stats.total_events_published > 0 or stats.buffered_events == 0; // Either publishing or empty

        const score = (@as(f32, if (claims_ok) 1 else 0) * 0.4 +
            @as(f32, if (events_ok) 1 else 0) * 0.4 +
            1.0 * 0.2) * 100.0; // Backoff always OK

        return .{
            .score = score,
            .healthy = score >= 80.0,
            .details = .{
                .claims_count = stats.active_claims,
                .events_published = stats.total_events_published,
                .events_buffered = stats.buffered_events,
            },
        };
    }

    /// Export metrics in Prometheus format for monitoring
    pub fn exportMetrics(self: *const AgentCoordination, writer: anytype) !void {
        const stats = self.getStats();
        const health = self.healthCheck();

        try writer.print("# HELP s3ai_brain_active_claims Current number of active task claims\n", .{});
        try writer.print("# TYPE s3ai_brain_active_claims gauge\n", .{});
        try writer.print("s3ai_brain_active_claims {d}\n", .{stats.active_claims});

        try writer.print("\n# HELP s3ai_brain_events_published Total events published\n", .{});
        try writer.print("# TYPE s3ai_brain_events_published counter\n", .{});
        try writer.print("s3ai_brain_events_published {d}\n", .{stats.total_events_published});

        try writer.print("\n# HELP s3ai_brain_events_polled Total event polls\n", .{});
        try writer.print("# TYPE s3ai_brain_events_polled counter\n", .{});
        try writer.print("s3ai_brain_events_polled {d}\n", .{stats.total_events_polled});

        try writer.print("\n# HELP s3ai_brain_events_buffered Current buffered events\n", .{});
        try writer.print("# TYPE s3ai_brain_events_buffered gauge\n", .{});
        try writer.print("s3ai_brain_events_buffered {d}\n", .{stats.buffered_events});

        try writer.print("\n# HELP s3ai_brain_health_score Brain health score (0-100)\n", .{});
        try writer.print("# TYPE s3ai_brain_health_score gauge\n", .{});
        try writer.print("s3ai_brain_health_score {d:.1}\n", .{health.score});

        try writer.print("\n# HELP s3ai_brain_healthy Brain health status (1=healthy, 0=unhealthy)\n", .{});
        try writer.print("# TYPE s3ai_brain_healthy gauge\n", .{});
        try writer.print("s3ai_brain_healthy {d}\n", .{@intFromBool(health.healthy)});
    }

    /// Dump current brain state for debugging
    pub fn dump(self: *const AgentCoordination, writer: anytype) !void {
        const stats = self.getStats();
        const health = self.healthCheck();

        try writer.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  S³AI BRAIN DUMP — {s:>19}                  ║\n", .{"v5.1"});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  HEALTH SCORE: {d:.1}/100  [{s:>10}]                        ║\n", .{ health.score, if (health.healthy) "HEALTHY" else "UNHEALTHY" });
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Basal Ganglia (Action Selection)                            ║\n", .{});
        try writer.print("║    Active Claims:    {d:>6}                                 ║\n", .{stats.active_claims});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Reticular Formation (Broadcast Alerting)                    ║\n", .{});
        try writer.print("║    Events Published: {d:>6}                                 ║\n", .{stats.total_events_published});
        try writer.print("║    Events Polled:    {d:>6}                                 ║\n", .{stats.total_events_polled});
        try writer.print("║    Events Buffered:  {d:>6}                                 ║\n", .{stats.buffered_events});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Locus Coeruleus (Arousal Regulation)                        ║\n", .{});
        try writer.print("║    Strategy:         {s:>30}        ║\n", .{@tagName(self.backoff_policy.strategy)});
        try writer.print("║    Initial Delay:    {d:>6} ms                             ║\n", .{self.backoff_policy.initial_ms});
        try writer.print("║    Max Delay:        {d:>6} ms                             ║\n", .{self.backoff_policy.max_ms});
        try writer.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Visual ASCII brain scan (for TUI display)
    pub fn scan(self: *const AgentCoordination) struct {
        basal_ganglia: []const u8,
        reticular_formation: []const u8,
        locus_coeruleus: []const u8,
        overall: []const u8,
    } {
        const stats = self.getStats();
        const health = self.healthCheck();

        // Activity levels based on stats
        const bg_level: []const u8 = if (stats.active_claims == 0) "💤" else if (stats.active_claims < 10) "🟢" else if (stats.active_claims < 100) "🟡" else "🔴";
        const rf_level: []const u8 = if (stats.total_events_published == 0) "💤" else if (stats.buffered_events < 100) "🟢" else if (stats.buffered_events < 1000) "🟡" else "🔴";
        const lc_level: []const u8 = "🟢"; // Always healthy (stateless)

        return .{
            .basal_ganglia = bg_level,
            .reticular_formation = rf_level,
            .locus_coeruleus = lc_level,
            .overall = if (health.healthy) "✅" else "⚠️",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Brain atlas completeness" {
    try std.testing.expectEqual(@as(usize, 9), BRAIN_ATLAS.len);
    try std.testing.expect(std.mem.eql(u8, "Basal Ganglia", BRAIN_ATLAS[1].name));
}

test "AgentCoordination claim and complete" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        // coord.deinit() would go here when implemented
    }

    const task_id = "test-task-123";
    const agent_id = "agent-alpha-001";

    // Claim task
    const claimed = try coord.claimTask(task_id, agent_id);
    try std.testing.expect(claimed);

    // Verify heartbeat works
    const heartbeat_ok = coord.refreshHeartbeat(task_id, agent_id);
    try std.testing.expect(heartbeat_ok);

    // Complete task
    try coord.completeTask(task_id, agent_id, 5000);

    // Verify claim is no longer valid
    const claimed_again = try coord.claimTask(task_id, agent_id);
    try std.testing.expect(claimed_again); // Can claim again after completion
}

test "AgentCoordination health check" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        // coord.deinit() would go here when implemented
    }

    const health = coord.healthCheck();
    try std.testing.expect(health.healthy);
    try std.testing.expect(health.score >= 80.0);
}
