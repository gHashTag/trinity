//! PREFRONTAL CORTEX — Executive Function v1.0
//!
//! Decision making, planning, and cognitive control.
//! Brain Region: Prefrontal Cortex (Executive Function)

const std = @import("std");

pub const DecisionContext = struct {
    task_count: usize,
    active_agents: usize,
    error_rate: f32,
    avg_latency_ms: u64,
    memory_usage_pct: f32,
};

pub const Decision = struct {
    action: Action,
    confidence: f32,
    reasoning: []const u8,
};

pub const Action = enum {
    proceed,
    throttle,
    scale_up,
    scale_down,
    pause,
    alert,
};

pub const PrefrontalCortex = struct {
    const Self = @This();

    /// Make executive decision based on context
    pub fn decide(ctx: DecisionContext) Decision {
        var confidence: f32 = 1.0;
        var action: Action = .proceed;
        var reasons = std.ArrayList(u8).initCapacity(std.heap.page_allocator, 128) catch |err| {
            std.log.err("Failed to allocate reasons: {}", .{err});
            return Decision{
                .action = .proceed,
                .confidence = 0.5,
                .reasoning = "Allocation failed",
            };
        };
        defer reasons.deinit(std.heap.page_allocator);

        // Check error rate
        if (ctx.error_rate > 0.5) {
            action = .pause;
            confidence = 0.9;
            reasons.appendSlice(std.heap.page_allocator, "High error rate;") catch {};
        } else if (ctx.error_rate > 0.2) {
            action = .throttle;
            confidence = 0.7;
            reasons.appendSlice(std.heap.page_allocator, "Elevated error rate;") catch {};
        }

        // Check queue depth
        const queue_per_agent = if (ctx.active_agents > 0)
            @as(f32, @floatFromInt(ctx.task_count)) / @as(f32, @floatFromInt(ctx.active_agents))
        else
            0;

        if (queue_per_agent > 10) {
            if (action == .proceed) action = .scale_up;
            confidence *= 0.9;
            reasons.appendSlice(std.heap.page_allocator, "High queue depth;") catch {};
        }

        // Check latency
        if (ctx.avg_latency_ms > 5000) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.8;
            reasons.appendSlice(std.heap.page_allocator, "High latency;") catch {};
        }

        // Check memory
        if (ctx.memory_usage_pct > 90) {
            action = .alert;
            confidence = 0.95;
            reasons.appendSlice(std.heap.page_allocator, "Critical memory usage;") catch {};
        } else if (ctx.memory_usage_pct > 75) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.85;
            reasons.appendSlice(std.heap.page_allocator, "High memory usage;") catch {};
        }

        // Scale down if underutilized
        if (ctx.task_count < ctx.active_agents and queue_per_agent < 0.5) {
            if (action == .proceed) action = .scale_down;
            confidence *= 0.8;
            reasons.appendSlice(std.heap.page_allocator, "Underutilized;") catch {};
        }

        return .{
            .action = action,
            .confidence = confidence,
            .reasoning = "Executive decision based on context",
        };
    }

    /// Get recommendation as human-readable string
    pub fn recommend(decision: Decision) []const u8 {
        return switch (decision.action) {
            .proceed => "Continue normal operations",
            .throttle => "Reduce task acceptance rate",
            .scale_up => "Spawn more agents",
            .scale_down => "Reduce agent count",
            .pause => "Pause new task acceptance",
            .alert => "Immediate intervention required",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PrefrontalCortex decides to pause on high error rate" {
    const ctx = DecisionContext{
        .task_count = 100,
        .active_agents = 10,
        .error_rate = 0.6,
        .avg_latency_ms = 1000,
        .memory_usage_pct = 50.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.pause, decision.action);
}

test "PrefrontalCortex scales up on high queue depth" {
    const ctx = DecisionContext{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 40.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.scale_up, decision.action);
}

test "PrefrontalCortex throttles on high latency" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 60.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.throttle, decision.action);
}

test "PrefrontalCortex alerts on critical memory" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 95.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.alert, decision.action);
}

test "PrefrontalCortex proceeds with healthy context" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 40.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.proceed, decision.action);
}

test "PrefrontalCortex scales down when underutilized" {
    const ctx = DecisionContext{
        .task_count = 2, // 2/10 = 0.2 < 0.5 threshold
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.scale_down, decision.action);
}

test "PrefrontalCortex combines multiple factors" {
    const ctx = DecisionContext{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.3,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 80.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    // Should throttle due to elevated error rate + high latency + high memory
    try std.testing.expectEqual(Action.throttle, decision.action);
}

test "PrefrontalCortex confidence calculation" {
    const healthy_ctx: DecisionContext = .{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 200,
        .memory_usage_pct = 30.0,
    };
    const decision1 = PrefrontalCortex.decide(healthy_ctx);
    try std.testing.expect(decision1.confidence > 0.8);

    const degraded_ctx: DecisionContext = .{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.3,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 80.0,
    };
    const decision2 = PrefrontalCortex.decide(degraded_ctx);
    try std.testing.expect(decision2.confidence < 1.0);
}

test "PrefrontalCortex zero agents edge case" {
    const ctx = DecisionContext{
        .task_count = 100,
        .active_agents = 0,
        .error_rate = 0.1,
        .avg_latency_ms = 1000,
        .memory_usage_pct = 50.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    // Should not crash, should produce valid decision
    try std.testing.expect(decision.confidence > 0);
}

test "PrefrontalCortex recommend all actions" {
    try std.testing.expectEqual(@as([]const u8, "Continue normal operations"), PrefrontalCortex.recommend(.{
        .action = .proceed,
        .confidence = 1.0,
        .reasoning = "All systems nominal",
    }));

    try std.testing.expectEqual(@as([]const u8, "Reduce task acceptance rate"), PrefrontalCortex.recommend(.{
        .action = .throttle,
        .confidence = 0.8,
        .reasoning = "Elevated latency",
    }));

    try std.testing.expectEqual(@as([]const u8, "Spawn more agents"), PrefrontalCortex.recommend(.{
        .action = .scale_up,
        .confidence = 0.9,
        .reasoning = "High queue depth",
    }));

    try std.testing.expectEqual(@as([]const u8, "Reduce agent count"), PrefrontalCortex.recommend(.{
        .action = .scale_down,
        .confidence = 0.8,
        .reasoning = "Underutilized",
    }));

    try std.testing.expectEqual(@as([]const u8, "Pause new task acceptance"), PrefrontalCortex.recommend(.{
        .action = .pause,
        .confidence = 0.9,
        .reasoning = "High error rate",
    }));

    try std.testing.expectEqual(@as([]const u8, "Immediate intervention required"), PrefrontalCortex.recommend(.{
        .action = .alert,
        .confidence = 0.95,
        .reasoning = "Critical memory",
    }));
}

test "PrefrontalCortex threshold boundaries" {
    // Test exact boundary at error_rate = 0.5
    const ctx1: DecisionContext = .{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.5,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    try std.testing.expectEqual(Action.throttle, decision1.action);

    // Test exact boundary at error_rate = 0.51
    const ctx2: DecisionContext = .{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.51,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.pause, decision2.action);
}

test "PrefrontalCortex extreme latency edge case" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 100000, // 100 seconds
        .memory_usage_pct = 50.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.throttle, decision.action);
    try std.testing.expect(decision.confidence < 1.0);
}

test "PrefrontalCortex queue depth scale up threshold" {
    // Above threshold (11 tasks per agent triggers scale_up)
    const ctx1 = DecisionContext{
        .task_count = 110,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    try std.testing.expectEqual(Action.scale_up, decision1.action);

    // Exactly at threshold (10 tasks per agent does NOT trigger scale_up)
    const ctx2 = DecisionContext{
        .task_count = 100,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.proceed, decision2.action);
}

test "PrefrontalCortex memory threshold boundaries" {
    // Critical memory threshold at >90%
    const ctx1 = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 90.1,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    try std.testing.expectEqual(Action.alert, decision1.action);

    // Exactly 90% should NOT trigger alert (uses > comparison)
    const ctx2 = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 90.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.throttle, decision2.action);

    // High memory threshold at >75%
    const ctx3 = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 75.1,
    };
    const decision3 = PrefrontalCortex.decide(ctx3);
    try std.testing.expectEqual(Action.throttle, decision3.action);
}

test "PrefrontalCortex multi-factor priority error_rate" {
    // Error rate should override queue depth for pause
    const ctx = DecisionContext{
        .task_count = 500, // Very high queue
        .active_agents = 10,
        .error_rate = 0.6, // Critical error rate
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.pause, decision.action);
}

test "PrefrontalCortex multi-factor priority memory" {
    // Critical memory should override everything
    const ctx = DecisionContext{
        .task_count = 500,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 95.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.alert, decision.action);
}

test "PrefrontalCortex confidence healthy baseline" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 200,
        .memory_usage_pct = 30.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), decision.confidence, 0.01);
}

test "PrefrontalCortex confidence degraded_by_latency" {
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 30.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expect(decision.confidence < 1.0);
    try std.testing.expect(decision.confidence >= 0.7);
}

test "PrefrontalCortex confidence degraded_by_queue" {
    const ctx = DecisionContext{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 500,
        .memory_usage_pct = 30.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expect(decision.confidence < 1.0);
}

test "PrefrontalCortex confidence multiple_degradation_factors" {
    const ctx = DecisionContext{
        .task_count = 200,
        .active_agents = 10,
        .error_rate = 0.25,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 80.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Multiple factors compound to reduce confidence significantly
    try std.testing.expect(decision.confidence < 0.5);
}

test "PrefrontalCortex zero agents zero_tasks" {
    const ctx = DecisionContext{
        .task_count = 0,
        .active_agents = 0,
        .error_rate = 0.0,
        .avg_latency_ms = 0,
        .memory_usage_pct = 10.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Should handle gracefully without panic
    try std.testing.expect(decision.confidence > 0);
}

test "PrefrontalCortex extreme_values" {
    const ctx = DecisionContext{
        .task_count = 1000000,
        .active_agents = 1000,
        .error_rate = 0.0,
        .avg_latency_ms = 0,
        .memory_usage_pct = 0.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Should scale up with huge queue
    try std.testing.expectEqual(Action.scale_up, decision.action);
}

test "PrefrontalCortex action_prioritization_pause_over_throttle" {
    // High error rate triggers pause, but other factors would suggest throttle
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.55,
        .avg_latency_ms = 6000,
        .memory_usage_pct = 85.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Pause has highest priority
    try std.testing.expectEqual(Action.pause, decision.action);
}

test "PrefrontalCortex action_prioritization_alert_over_all" {
    // Critical memory should trigger alert regardless of other factors
    const ctx = DecisionContext{
        .task_count = 5,
        .active_agents = 10,
        .error_rate = 0.6,
        .avg_latency_ms = 10000,
        .memory_usage_pct = 95.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.alert, decision.action);
}

test "PrefrontalCortex scale_down_conditions" {
    // Tasks < agents AND low queue depth
    const ctx1 = DecisionContext{
        .task_count = 3,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    try std.testing.expectEqual(Action.scale_down, decision1.action);

    // Tasks == agents should not scale down
    const ctx2 = DecisionContext{
        .task_count = 10,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.proceed, decision2.action);
}

test "PrefrontalCortex latency_threshold_exact" {
    // Exactly 5000ms should NOT trigger throttle (uses > comparison)
    const ctx1 = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 5000,
        .memory_usage_pct = 50.0,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    try std.testing.expectEqual(Action.proceed, decision1.action);

    // Above threshold
    const ctx2 = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 5001,
        .memory_usage_pct = 50.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.throttle, decision2.action);
}
