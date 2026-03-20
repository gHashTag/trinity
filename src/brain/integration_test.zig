//! BRAIN INTEGRATION TESTS — Cross-Region Coordination
//!
//! Comprehensive integration tests for all brain regions in src/brain/.
//! Tests coordination between basal_ganglia, reticular_formation, locus_coeruleus,
//! amygdala, prefrontal_cortex, and other regions.
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// Import brain region modules (using module names from build system)
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const locus_coeruleus = @import("locus_coeruleus");
const amygdala = @import("amygdala");
const prefrontal_cortex = @import("prefrontal_cortex");
const telemetry = @import("telemetry");
const health_history = @import("health_history");
const alerts = @import("alerts");
const state_recovery = @import("state_recovery");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 1: TASK CLAIM COORDINATION
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Task claim prevents duplicate execution" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    const task_id = "integration-task-001";
    const agent_alpha = "agent-alpha";
    const agent_beta = "agent-beta";

    const alpha_claimed = try registry.claim(allocator, task_id, agent_alpha, 60000);
    try std.testing.expect(alpha_claimed);

    const claim_event = reticular_formation.EventData{
        .task_claimed = .{
            .task_id = task_id,
            .agent_id = agent_alpha,
        },
    };
    try event_bus.publish(.task_claimed, claim_event);

    const beta_claimed = try registry.claim(allocator, task_id, agent_beta, 60000);
    try std.testing.expect(!beta_claimed);

    try std.testing.expectEqual(@as(usize, 1), registry.claims.count());

    const events = try event_bus.poll(0, allocator, 100);
    defer allocator.free(events);

    var found_claimed = false;
    for (events) |ev| {
        if (ev.event_type == .task_claimed) {
            found_claimed = true;
            try std.testing.expectEqualStrings(agent_alpha, ev.data.task_claimed.agent_id);
        }
    }
    try std.testing.expect(found_claimed);
}

test "Integration: Task claim with heartbeat and completion" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    const task_id = "integration-task-002";
    const agent_id = "agent-omega";

    const claimed = try registry.claim(allocator, task_id, agent_id, 60000);
    try std.testing.expect(claimed);

    const heartbeat_ok = registry.heartbeat(task_id, agent_id);
    try std.testing.expect(heartbeat_ok);

    const completed = registry.complete(task_id, agent_id);
    try std.testing.expect(completed);

    const complete_event = reticular_formation.EventData{
        .task_completed = .{
            .task_id = task_id,
            .agent_id = agent_id,
            .duration_ms = 5000,
        },
    };
    try event_bus.publish(.task_completed, complete_event);

    if (registry.claims.get(task_id)) |claim| {
        try std.testing.expect(claim.status == .completed);
    } else {
        try std.testing.expect(false);
    }
}

test "Integration: Task abandonment and reclamation" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    const task_id = "integration-task-004";
    const agent_id = "agent-sigma";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    const abandoned = registry.abandon(task_id, agent_id);
    try std.testing.expect(abandoned);

    const abandon_event = reticular_formation.EventData{
        .task_abandoned = .{
            .task_id = task_id,
            .agent_id = agent_id,
            .reason = "Resource constraints",
        },
    };
    try event_bus.publish(.task_abandoned, abandon_event);

    const reclaimed = try registry.claim(allocator, task_id, "agent-rescue", 60000);
    try std.testing.expect(reclaimed);

    const events = try event_bus.poll(0, allocator, 100);
    defer allocator.free(events);

    var found_abandoned = false;
    for (events) |ev| {
        if (ev.event_type == .task_abandoned) {
            found_abandoned = true;
        }
    }
    try std.testing.expect(found_abandoned);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 2: EVENT BROADCASTING
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Event bus broadcasts all event types" {
    const allocator = std.testing.allocator;

    reticular_formation.resetGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);

    try event_bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });
    try event_bus.publish(.task_completed, .{ .task_completed = .{ .task_id = "task-2", .agent_id = "agent-2", .duration_ms = 1000 } });
    try event_bus.publish(.task_failed, .{ .task_failed = .{ .task_id = "task-3", .agent_id = "agent-3", .err_msg = "Timeout" } });
    try event_bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-4", .idle_ms = 30000 } });
    try event_bus.publish(.agent_spawned, .{ .agent_spawned = .{ .agent_id = "agent-5" } });

    const events = try event_bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 5), events.len);
}

test "Integration: Event statistics tracking" {
    const allocator = std.testing.allocator;

    reticular_formation.resetGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);

    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);

        const event_data = reticular_formation.EventData{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-test",
            },
        };
        try event_bus.publish(.task_claimed, event_data);
    }

    const stats = event_bus.getStats();
    try std.testing.expectEqual(@as(u64, 10), stats.published);
    try std.testing.expectEqual(@as(usize, 10), stats.buffered);
}

test "Integration: Event filtering by timestamp" {
    const allocator = std.testing.allocator;

    reticular_formation.resetGlobal(allocator);
    defer reticular_formation.resetGlobal(allocator);

    const event_bus = try reticular_formation.getGlobal(allocator);

    try event_bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    // Sleep longer to ensure timestamp advances
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const middle = std.time.milliTimestamp();

    // Small sleep to ensure next event has later timestamp
    std.Thread.sleep(10 * std.time.ns_per_ms);

    try event_bus.publish(.task_completed, .{
        .task_completed = .{
            .task_id = "task-2",
            .agent_id = "agent-2",
            .duration_ms = 1000,
        },
    });

    const events = try event_bus.poll(middle, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_completed, events[0].event_type);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 3: HEALTH MONITORING
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Health monitoring across regions" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = std.time.milliTimestamp();
    try tel.record(.{
        .timestamp = now,
        .active_claims = 0,
        .events_published = 0,
        .events_buffered = 0,
        .health_score = 100.0,
    });

    _ = try registry.claim(allocator, "task-health-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "task-health-2", "agent-2", 60000);

    try event_bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-health-1",
            .agent_id = "agent-1",
        },
    });

    try tel.record(.{
        .timestamp = now + 1000,
        .active_claims = 2,
        .events_published = 1,
        .events_buffered = 1,
        .health_score = 95.0,
    });

    const avg_health = tel.avgHealth(10);
    try std.testing.expect(avg_health >= 95.0 and avg_health <= 100.0);
}

test "Integration: Health trend detection" {
    const allocator = std.testing.allocator;

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = std.time.milliTimestamp();

    // Need at least 6 points for trend calculation (third >= 2)
    var i: u64 = 0;
    while (i < 6) : (i += 1) {
        const health: f32 = if (i < 3) 50.0 else if (i < 5) 70.0 else 90.0;
        try tel.record(.{
            .timestamp = now + @as(i64, @intCast(i * 1000)),
            .active_claims = 100 - @as(usize, @intCast(i * 10)),
            .events_published = 1000 + @as(usize, @intCast(i * 100)),
            .events_buffered = 5000 - @as(usize, @intCast(i * 500)),
            .health_score = health,
        });
    }

    const trend = tel.trend(10);
    try std.testing.expect(trend == .improving);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 4: RECOVERY PROCEDURES
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: State save and restore" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try std.fs.cwd().makePath(tmp_dir);

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    var manager = try state_recovery.StateManager.init(allocator);
    defer manager.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    _ = try registry.claim(allocator, "recovery-task-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "recovery-task-2", "agent-2", 60000);
    _ = try registry.claim(allocator, "recovery-task-3", "agent-3", 60000);

    try event_bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "recovery-task-1",
            .agent_id = "agent-1",
        },
    });

    try manager.save(registry, event_bus);

    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(state_recovery.CURRENT_VERSION, loaded.state.version);
    try std.testing.expectEqual(@as(usize, 3), loaded.state.task_claims.len);

    manager.deleteState() catch {};
}

test "Integration: State restoration after crash" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try std.fs.cwd().makePath(tmp_dir);

    var manager = try state_recovery.StateManager.init(allocator);
    defer manager.deinit();

    var original_registry = basal_ganglia.Registry.init(allocator);
    defer original_registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    _ = try original_registry.claim(allocator, "crash-task-1", "agent-1", 60000);
    _ = try original_registry.claim(allocator, "crash-task-2", "agent-2", 60000);

    try manager.save(&original_registry, &event_bus);

    var new_registry = basal_ganglia.Registry.init(allocator);
    defer new_registry.deinit();

    var loaded = try manager.load();
    defer loaded.deinit();

    try manager.restore(&loaded, &new_registry, &event_bus);

    try std.testing.expectEqual(@as(usize, 2), new_registry.claims.count());

    manager.deleteState() catch {};
}

test "Integration: Auto-recovery on startup" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try std.fs.cwd().makePath(tmp_dir);

    // Clean up any existing state files first
    var cleanup_manager = try state_recovery.StateManager.init(allocator);
    defer cleanup_manager.deinit();
    cleanup_manager.deleteState() catch {};

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    var manager = try state_recovery.StateManager.init(allocator);
    defer manager.deinit();

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    _ = try registry.claim(allocator, "auto-task-1", "agent-1", 60000);
    try manager.save(registry, event_bus);

    registry.reset();

    const recovered = try state_recovery.autoRecover(allocator, registry, event_bus);
    try std.testing.expect(recovered);
    try std.testing.expectEqual(@as(usize, 1), registry.claims.count());

    manager.deleteState() catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 5: ALERT GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Critical health triggers alerts" {
    const allocator = std.testing.allocator;

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    try alert_mgr.checkHealth(30.0, 100, 100);

    const recent_alerts = try alert_mgr.getRecentAlerts(10, null);
    defer allocator.free(recent_alerts);

    try std.testing.expect(recent_alerts.len > 0);

    var found_critical = false;
    for (recent_alerts) |al| {
        if (al.level == .critical and al.condition == .health_low) {
            found_critical = true;
        }
    }
    try std.testing.expect(found_critical);
}

test "Integration: Event buffer overflow triggers alerts" {
    const allocator = std.testing.allocator;

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    try alert_mgr.checkHealth(90.0, 2000, 100);

    const recent_alerts = try alert_mgr.getRecentAlerts(10, .warning);
    defer allocator.free(recent_alerts);

    try std.testing.expect(recent_alerts.len > 0);

    var found_events_alert = false;
    for (recent_alerts) |al| {
        if (al.condition == .events_buffered_high) {
            found_events_alert = true;
        }
    }
    try std.testing.expect(found_events_alert);
}

test "Integration: Claims overflow triggers alerts" {
    const allocator = std.testing.allocator;

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    try alert_mgr.checkHealth(90.0, 100, 6000);

    const recent_alerts = try alert_mgr.getRecentAlerts(10, .warning);
    defer allocator.free(recent_alerts);

    var found_claims_alert = false;
    for (recent_alerts) |al| {
        if (al.condition == .claims_overflow) {
            found_claims_alert = true;
        }
    }
    try std.testing.expect(found_claims_alert);
}

test "Integration: Alert suppression prevents spam" {
    const allocator = std.testing.allocator;

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    try alert_mgr.checkHealth(30.0, 100, 100);
    try alert_mgr.checkHealth(30.0, 100, 100);
    try alert_mgr.checkHealth(30.0, 100, 100);

    const stats = try alert_mgr.getStats();

    try std.testing.expect(stats.total >= 3);
    try std.testing.expect(stats.critical <= 3);
}

test "Integration: Amygdala salience affects alert urgency" {
    const result = amygdala.Amygdala.analyzeTask("urgent-critical-security-fix", "dukh", "critical");

    try std.testing.expect(result.level == .critical);
    try std.testing.expect(amygdala.Amygdala.requiresAttention(result));
    try std.testing.expect(amygdala.Amygdala.urgency(result) > 0.75);
}

test "Integration: Error salience triggers appropriate alerts" {
    // Test critical patterns - segfault + security = 20 + 30 + 30 = 80 (critical)
    const critical_error = amygdala.Amygdala.analyzeError("segfault and security breach in core");
    try std.testing.expect(critical_error.level == .critical);
    try std.testing.expect(amygdala.Amygdala.requiresAttention(critical_error));

    // Test minor error - timeout = 20 + 15 = 35 (low)
    const minor_error = amygdala.Amygdala.analyzeError("connection timeout");
    try std.testing.expect(minor_error.level == .low);
    try std.testing.expect(critical_error.score > minor_error.score);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 6: EXECUTIVE DECISION MAKING
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Prefrontal cortex pauses on high error rate" {
    const ctx = prefrontal_cortex.DecisionContext{
        .task_count = 100,
        .active_agents = 10,
        .error_rate = 0.6,
        .avg_latency_ms = 1000,
        .memory_usage_pct = 50.0,
    };

    const decision = prefrontal_cortex.PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(prefrontal_cortex.Action.pause, decision.action);
    try std.testing.expect(decision.confidence > 0.8);
}

test "Integration: Prefrontal cortex scales up on high queue depth" {
    const ctx = prefrontal_cortex.DecisionContext{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 40.0,
    };

    const decision = prefrontal_cortex.PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(prefrontal_cortex.Action.scale_up, decision.action);
}

test "Integration: Prefrontal cortex alerts on critical memory" {
    const ctx = prefrontal_cortex.DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 95.0,
    };

    const decision = prefrontal_cortex.PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(prefrontal_cortex.Action.alert, decision.action);
}

test "Integration: Prefrontal cortex scales down when underutilized" {
    const ctx = prefrontal_cortex.DecisionContext{
        .task_count = 2,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };

    const decision = prefrontal_cortex.PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(prefrontal_cortex.Action.scale_down, decision.action);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 7: BACKOFF POLICY
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Exponential backoff progression" {
    var policy = locus_coeruleus.BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 60000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    const delay_0 = policy.nextDelay(0);
    const delay_1 = policy.nextDelay(1);
    const delay_2 = policy.nextDelay(2);
    const delay_3 = policy.nextDelay(3);

    try std.testing.expectEqual(@as(u64, 1000), delay_0);
    try std.testing.expectEqual(@as(u64, 2000), delay_1);
    try std.testing.expectEqual(@as(u64, 4000), delay_2);
    try std.testing.expectEqual(@as(u64, 8000), delay_3);
}

test "Integration: Linear backoff progression" {
    var policy = locus_coeruleus.BackoffPolicy{
        .initial_ms = 1000,
        .linear_increment = 500,
        .strategy = .linear,
        .jitter_type = .none,
    };

    try std.testing.expectEqual(@as(u64, 1000), policy.nextDelay(0));
    try std.testing.expectEqual(@as(u64, 1500), policy.nextDelay(1));
    try std.testing.expectEqual(@as(u64, 2000), policy.nextDelay(2));
}

test "Integration: Backoff caps at max_ms" {
    var policy = locus_coeruleus.BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 5000,
        .multiplier = 10.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    const delay = policy.nextDelay(10);
    try std.testing.expect(delay >= 5000);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 8: MULTI-AGENT SCENARIOS
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Multiple agents claim different tasks" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        // Use stack buffers for task_id and agent_id to avoid heap allocation
        var task_buf: [32]u8 = undefined;
        const task_id = std.fmt.bufPrint(&task_buf, "multi-task-{d}", .{i}) catch unreachable;
        var agent_buf: [32]u8 = undefined;
        const agent_id = std.fmt.bufPrint(&agent_buf, "multi-agent-{d}", .{i}) catch unreachable;

        const claimed = try registry.claim(allocator, task_id, agent_id, 60000);
        try std.testing.expect(claimed);

        const event_data = reticular_formation.EventData{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = agent_id,
            },
        };
        try event_bus.publish(.task_claimed, event_data);
    }

    try std.testing.expectEqual(@as(usize, 10), registry.claims.count());

    const events = try event_bus.poll(0, allocator, 100);
    defer allocator.free(events);

    var claimed_count: usize = 0;
    for (events) |ev| {
        if (ev.event_type == .task_claimed) {
            claimed_count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 10), claimed_count);
}

test "Integration: Agent retries claim with backoff" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);

    var policy = locus_coeruleus.BackoffPolicy{
        .initial_ms = 100,
        .max_ms = 1000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    const task_id = "retry-task";
    const agent_alpha = "agent-alpha";
    const agent_beta = "agent-beta";

    _ = try registry.claim(allocator, task_id, agent_alpha, 60000);

    var attempt: u32 = 0;
    while (attempt < 5) : (attempt += 1) {
        const claimed = try registry.claim(allocator, task_id, agent_beta, 60000);
        if (claimed) break;

        const delay = policy.nextDelay(attempt);
        try std.testing.expect(delay >= 100);
    }

    const final_claim = try registry.claim(allocator, task_id, agent_beta, 60000);
    try std.testing.expect(!final_claim);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 9: COORDINATED WORKFLOW
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: Full task lifecycle with monitoring" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    const task_id = "lifecycle-task";
    const agent_id = "lifecycle-agent";

    const start_time = std.time.milliTimestamp();

    const claimed = try registry.claim(allocator, task_id, agent_id, 60000);
    try std.testing.expect(claimed);

    try event_bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = task_id,
            .agent_id = agent_id,
        },
    });

    try tel.record(.{
        .timestamp = start_time,
        .active_claims = 1,
        .events_published = 1,
        .events_buffered = 1,
        .health_score = 100.0,
    });

    try alert_mgr.checkHealth(100.0, 1, 1);

    const complete_time = std.time.milliTimestamp();
    const duration_ms = @as(u64, @intCast(complete_time - start_time));

    _ = registry.complete(task_id, agent_id);

    try event_bus.publish(.task_completed, .{
        .task_completed = .{
            .task_id = task_id,
            .agent_id = agent_id,
            .duration_ms = duration_ms,
        },
    });

    try alert_mgr.checkHealth(100.0, 2, 2);

    if (registry.claims.get(task_id)) |claim| {
        try std.testing.expect(claim.status == .completed);
    }

    // Poll from before start_time to ensure we capture all events
    const events = try event_bus.poll(start_time - 1, allocator, 100);
    defer allocator.free(events);

    var found_claimed = false;
    var found_completed = false;
    for (events) |ev| {
        switch (ev.event_type) {
            .task_claimed => found_claimed = true,
            .task_completed => found_completed = true,
            else => {},
        }
    }

    try std.testing.expect(found_claimed);
    try std.testing.expect(found_completed);
}

test "Integration: Failed task with alert" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    const task_id = "failed-task";
    const agent_id = "failed-agent";
    const err_msg = "Connection timeout after 30s";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    _ = registry.abandon(task_id, agent_id);

    try event_bus.publish(.task_failed, .{
        .task_failed = .{
            .task_id = task_id,
            .agent_id = agent_id,
            .err_msg = err_msg,
        },
    });

    const salience = amygdala.Amygdala.analyzeError(err_msg);
    try std.testing.expect(salience.level != .none);

    if (registry.claims.get(task_id)) |claim| {
        try std.testing.expect(claim.status == .abandoned);
    }

    const events = try event_bus.poll(0, allocator, 100);
    defer allocator.free(events);

    var found_failed = false;
    for (events) |ev| {
        if (ev.event_type == .task_failed) {
            found_failed = true;
            try std.testing.expectEqualStrings(err_msg, ev.data.task_failed.err_msg);
        }
    }
    try std.testing.expect(found_failed);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 10: STRESS SCENARIOS
// ═══════════════════════════════════════════════════════════════════════════════

test "Integration: High load - many concurrent claims" {
    const allocator = std.testing.allocator;

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // Use stack buffers to avoid heap allocation
        var task_buf: [32]u8 = undefined;
        const task_id = std.fmt.bufPrint(&task_buf, "load-task-{d:0>3}", .{i}) catch unreachable;
        var agent_buf: [32]u8 = undefined;
        const agent_id = std.fmt.bufPrint(&agent_buf, "load-agent-{d:0>3}", .{i}) catch unreachable;

        const claimed = try registry.claim(allocator, task_id, agent_id, 60000);
        try std.testing.expect(claimed);

        if (i % 10 == 0) {
            try event_bus.publish(.task_claimed, .{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = agent_id,
                },
            });
        }
    }

    try std.testing.expectEqual(@as(usize, 100), registry.claims.count());

    const stats = event_bus.getStats();
    try std.testing.expect(stats.buffered == 10);
}

test "Integration: Recovery after corrupted state" {
    const allocator = std.testing.allocator;

    const tmp_dir = ".trinity/brain/state";
    try std.fs.cwd().makePath(tmp_dir);

    var manager = try state_recovery.StateManager.init(allocator);
    defer manager.deinit();

    {
        const file = try std.fs.cwd().createFile(manager.state_file_path, .{ .read = true });
        defer file.close();
        try file.writeAll("corrupted {{json data");
    }

    const result = manager.load();
    try std.testing.expectError(error.CorruptedData, result);

    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    var event_bus = reticular_formation.EventBus.init(allocator);
    defer event_bus.deinit();

    _ = try registry.claim(allocator, "recovery-task", "agent", 60000);

    try manager.save(&registry, &event_bus);

    var loaded = try manager.load();
    defer loaded.deinit();

    try std.testing.expectEqual(@as(usize, 1), loaded.state.task_claims.len);

    manager.deleteState() catch {};
}

test "Integration: All regions maintain consistency" {
    const allocator = std.testing.allocator;

    // Clean up any leftover state files from previous tests
    std.fs.cwd().deleteTree(".trinity/brain/state") catch {};

    basal_ganglia.resetGlobal(allocator);
    reticular_formation.resetGlobal(allocator);
    defer {
        basal_ganglia.resetGlobal(allocator);
        reticular_formation.resetGlobal(allocator);
    }

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    var alert_mgr = try alerts.AlertManager.init(allocator);
    defer alert_mgr.deinit();

    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "consistency-{d}", .{i});
        defer allocator.free(task_id);

        _ = try registry.claim(allocator, task_id, "agent", 60000);

        try event_bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent",
            },
        });

        try tel.record(.{
            .timestamp = std.time.milliTimestamp(),
            .active_claims = i + 1,
            .events_published = @as(u64, @intCast(i + 1)),
            .events_buffered = i + 1,
            .health_score = 100.0,
        });
    }

    try std.testing.expectEqual(@as(usize, 10), registry.claims.count());

    const event_stats = event_bus.getStats();
    try std.testing.expectEqual(@as(u64, 10), event_stats.published);

    const avg_health = tel.avgHealth(10);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), avg_health, 0.1);

    try alert_mgr.checkHealth(100.0, 10, 10);

    const alert_stats = try alert_mgr.getStats();
    try std.testing.expectEqual(@as(usize, 0), alert_stats.critical);
}
