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

/// Thalamus (Sensory Relay)
/// Railway live logs relay
// NOTE: Temporarily disabled due to pre-existing compilation errors
// pub const thalamus_logs = @import("thalamus_logs");

/// Stress Test (Load Testing)
/// Brain load testing and stress testing utilities
// NOTE: Temporarily disabled due to pre-existing compilation errors
// pub const stress_test = @import("stress_test.zig");

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
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT COORDINATION HELPER — High-level API for orchestrators
// ═══════════════════════════════════════════════════════════════════════════════

/// AgentCoordination — high-level wrapper combining all brain regions
/// for seamless integration into orchestrators and coordinators.
pub const AgentCoordination = struct {
    allocator: std.mem.Allocator,
    registry: *basal_ganglia.Registry,
    event_bus: reticular_formation.EventBus,
    backoff_policy: locus_coeruleus.BackoffPolicy,

    /// Initialize agent coordination with all brain regions
    pub fn init(allocator: std.mem.Allocator) !AgentCoordination {
        const registry = try basal_ganglia.getGlobal(allocator);
        return AgentCoordination{
            .allocator = allocator,
            .registry = registry,
            .event_bus = reticular_formation.EventBus.init(),
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

        // Event bus stub — TODO: implement actual publishing
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
    };

    pub fn getStats(self: *const AgentCoordination) CoordinationStats {
        const event_stats = self.event_bus.getStats();
        return CoordinationStats{
            .active_claims = self.registry.claims.count(),
            .total_events_published = event_stats.published,
            .total_events_polled = event_stats.polled,
        };
    }

    /// Poll recent events from reticular formation
    pub fn pollEvents(self: *AgentCoordination, since: i64, max_events: usize) ![]reticular_formation.AgentEventRecord {
        return self.event_bus.poll(since, self.allocator, max_events);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Brain atlas completeness" {
    try std.testing.expectEqual(@as(usize, 4), BRAIN_ATLAS.len);
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
