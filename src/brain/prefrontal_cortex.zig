//! PREFRONTAL CORTEX — Executive Function v1.0
//!
//! Decision making, planning, and cognitive control.
//! Brain Region: Prefrontal Cortex (Executive Function)
//!
//! # Overview
//!
//! The Prefrontal Cortex module provides executive decision-making
//! based on system state. It evaluates metrics and recommends
//! actions like proceeding, throttling, scaling, or pausing.
//!
//! # Features
//!
//! - Multi-factor decision making (error rate, latency, memory, queue depth)
//! - Confidence scoring for decision reliability
//! - Six actions: proceed, throttle, scale_up, scale_down, pause, alert
//! - Priority-based action selection (alert > pause > throttle > ...)
//!
//! # Biological Inspiration
//!
//! The prefrontal cortex in the brain handles executive functions:
//! decision making, planning, and cognitive control. This module
//! mirrors that by making high-level decisions about system behavior.
//!
//! # Usage
//!
//! ```zig
//! const ctx = brain.prefrontal_cortex.DecisionContext{
//!     .task_count = 150,
//!     .active_agents = 10,
//!     .error_rate = 0.05,
//!     .avg_latency_ms = 2000,
//!     .memory_usage_pct = 65.0,
//! };
//!
//! const decision = brain.prefrontal_cortex.PrefrontalCortex.decide(ctx);
//! std.log.info("Decision: {s} (confidence: {d:.2})", .{
//!     @tagName(decision.action),
//!     decision.confidence
//! });
//! ```
//!
//! # Decision Thresholds
//!
//! | Condition | Action | Priority |
//! |-----------|--------|----------|
//! | memory > 90% | alert | Highest |
//! | error_rate > 0.5 | pause | Very high |
//! | error_rate > 0.2 | throttle | High |
//! | queue/agent > 10 | scale_up | Medium |
//! | latency > 5000ms | throttle | Medium |
//! | memory > 75% | throttle | Medium |
//! | tasks < agents & queue < 0.5 | scale_down | Low |
//! | All healthy | proceed | Default |

const std = @import("std");

/// Context for executive decision-making.
///
/// Contains metrics about current system state that inform
/// the decision-making process.
///
/// # Fields
///
/// - `task_count`: Number of tasks pending
/// - `active_agents`: Number of active agents
/// - `error_rate`: Fraction of failed operations (0.0 to 1.0)
/// - `avg_latency_ms`: Average operation latency in milliseconds
/// - `memory_usage_pct`: Memory usage as percentage (0.0 to 100.0)
///
/// # Example
///
/// ```zig
/// const ctx = DecisionContext{
///     .task_count = 150,
///     .active_agents = 10,
///     .error_rate = 0.05,
///     .avg_latency_ms = 2000,
///     .memory_usage_pct = 65.0,
/// };
/// ```
pub const DecisionContext = struct {
    /// Number of tasks currently pending
    task_count: usize,
    /// Number of active agents
    active_agents: usize,
    /// Error rate (0.0 = no errors, 1.0 = all errors)
    error_rate: f32,
    /// Average operation latency in milliseconds
    avg_latency_ms: u64,
    /// Memory usage percentage
    memory_usage_pct: f32,
};

/// Executive decision result.
///
/// Contains the recommended action, confidence score,
/// and reasoning.
///
/// # Fields
///
/// - `action`: Recommended action to take
/// - `confidence`: Confidence in decision (0.0 to 1.0)
/// - `reasoning`: Human-readable explanation
pub const Decision = struct {
    /// Recommended action
    action: Action,
    /// Confidence score (higher = more certain)
    confidence: f32,
    /// Explanation for this decision
    reasoning: []const u8,
};

/// Executive actions for system control.
///
/// Represents possible actions the brain can take based on
/// system state evaluation.
///
/// # Actions
///
/// - `proceed`: Continue normal operations (healthy state)
/// - `throttle`: Reduce task acceptance rate (degraded state)
/// - `scale_up`: Spawn more agents (overwhelmed state)
/// - `scale_down`: Reduce agent count (underutilized state)
/// - `pause`: Stop accepting new tasks (severe degradation)
/// - `alert`: Immediate intervention required (critical state)
///
/// # Priority
///
/// When multiple conditions are true, higher priority actions win:
/// alert > pause > throttle > scale_up > scale_down > proceed
pub const Action = enum {
    /// Continue normal operations
    proceed,
    /// Reduce task acceptance rate
    throttle,
    /// Spawn more agents
    scale_up,
    /// Reduce agent count
    scale_down,
    /// Stop accepting new tasks
    pause,
    /// Immediate intervention required
    alert,
};

/// Prefrontal Cortex executive decision engine.
///
/// Evaluates system state and recommends executive actions.
pub const PrefrontalCortex = struct {
    const Self = @This();

    /// Makes executive decision based on system context.
    ///
    /// Evaluates multiple metrics and returns the most appropriate
    /// action with a confidence score.
    ///
    /// # Parameters
    ///
    /// - `ctx`: System state context to evaluate
    ///
    /// # Returns
    ///
    /// `Decision` with action, confidence, and reasoning
    ///
    /// # Decision Logic
    ///
    /// 1. **Alert**: memory > 90% (highest priority)
    /// 2. **Pause**: error_rate > 0.5
    /// 3. **Throttle**: error_rate > 0.2 OR latency > 5000 OR memory > 75%
    /// 4. **Scale Up**: queue_per_agent > 10
    /// 5. **Scale Down**: tasks < agents AND queue_per_agent < 0.5
    /// 6. **Proceed**: All systems healthy (default)
    ///
    /// # Confidence
    ///
    /// - Starts at 1.0 (confident)
    /// - Reduced by 0.1-0.2 for each degradation factor
    ///
    /// # Example
    ///
    /// ```zig
    /// const ctx = DecisionContext{
    ///     .task_count = 200,
    ///     .active_agents = 10,
    ///     .error_rate = 0.05,
    ///     .avg_latency_ms = 500,
    ///     .memory_usage_pct = 40.0,
    /// };
    ///
    /// const decision = PrefrontalCortex.decide(ctx);
    /// // decision.action == .scale_up (queue per agent = 20 > 10)
    /// ```
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
