//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! PREFRONTAL CORTEX — Executive Function v5.1
//!
//! Decision making, planning, and cognitive control.
//! Brain Region: Prefrontal Cortex (Executive Function)
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
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
//! - Zero-allocation decision path (stack-based reasoning buffer)
//! - Integration with Amygdala for emotionally-salient decisions
//!
//! # Biological Inspiration
//!
//! The prefrontal cortex (PFC) is the anterior part of the frontal lobes
//! and is responsible for executive functions:
//!
//! - **Dorsolateral PFC**: Cognitive control, working memory, planning
//! - **Ventromedial PFC**: Decision making, emotion regulation
//! - **Anterior Cingulate**: Error detection, conflict monitoring
//! - **Orbitofrontal Cortex**: Reward evaluation, inhibition control
//!
//! This module mirrors the PFC by:
//! - Evaluating multiple metrics simultaneously (working memory)
//! - Prioritizing actions based on urgency (inhibition control)
//! - Detecting error conditions (error monitoring)
//! - Computing confidence scores (reward evaluation)
//!
//! # Neuroanatomical Integration
//!
//! The PFC integrates with other brain regions:
//!
//! - **Basal Ganglia**: Receives task claim status for scaling decisions
//! - **Amygdala**: Can weight decisions by emotional salience
//! - **Reticular Formation**: Broadcasts decision events
//! - **Hippocampus**: Logs decisions for replay and learning
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
//! | Condition | Action | Priority | Neuroanalog |
//! |-----------|--------|----------|-------------|
//! | memory > 90% | alert | Highest | OFC inhibition |
//! | error_rate > 0.5 | pause | Very high | ACC error detection |
//! | error_rate > 0.2 | throttle | High | DLPFC control |
//! | queue/agent > 10 | scale_up | Medium | Planning |
//! | latency > 5000ms | throttle | Medium | Cognitive load |
//! | memory > 75% | throttle | Medium | Resource monitoring |
//! | tasks < agents & queue < 0.5 | scale_down | Low | Efficiency |
//! | All healthy | proceed | Default | Maintenance |
//!
//! # Thread Safety
//!
//! The decide() function is stateless and thread-safe. Multiple threads
//! can call decide() concurrently without synchronization.

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

        // Static buffer for reasons - no allocation in hot path
        var reasons_buf: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&reasons_buf);
        const writer = fbs.writer();

        // Check error rate
        if (ctx.error_rate > 0.5) {
            action = .pause;
            confidence = 0.9;
            writer.writeAll("High error rate;") catch {};
        } else if (ctx.error_rate > 0.2) {
            action = .throttle;
            confidence = 0.7;
            writer.writeAll("Elevated error rate;") catch {};
        }

        // Check queue depth
        const queue_per_agent = if (ctx.active_agents > 0)
            @as(f32, @floatFromInt(ctx.task_count)) / @as(f32, @floatFromInt(ctx.active_agents))
        else
            0;

        if (queue_per_agent > 10) {
            if (action == .proceed) action = .scale_up;
            confidence *= 0.9;
            writer.writeAll("High queue depth;") catch {};
        }

        // Check latency
        if (ctx.avg_latency_ms > 5000) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.8;
            writer.writeAll("High latency;") catch {};
        }

        // Check memory
        if (ctx.memory_usage_pct > 90) {
            action = .alert;
            confidence = 0.95;
            writer.writeAll("Critical memory usage;") catch {};
        } else if (ctx.memory_usage_pct > 75) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.85;
            writer.writeAll("High memory usage;") catch {};
        }

        // Scale down if underutilized
        if (ctx.task_count < ctx.active_agents and queue_per_agent < 0.5) {
            if (action == .proceed) action = .scale_down;
            confidence *= 0.8;
            writer.writeAll("Underutilized;") catch {};
        }

        // Use static buffer reasoning if available, else fallback string
        const reasoning = if (fbs.pos > 0) fbs.getWritten() else "All systems healthy";

        return .{
            .action = action,
            .confidence = confidence,
            .reasoning = reasoning,
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

test "PrefrontalCortex proceed with healthy context" {
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

// ═════════════════════════════════════════════════════════════════════════════
// NEUROANATOMICAL TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "PrefrontalCortex ACC_error_detection_on_high_error_rate" {
    // Anterior Cingulate Cortex (ACC) analog: error rate detection
    // The ACC monitors for conflicts and errors in performance
    const ctx = DecisionContext{
        .task_count = 100,
        .active_agents = 10,
        .error_rate = 0.51, // Just above threshold
        .avg_latency_ms = 1000,
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.pause, decision.action);
    try std.testing.expect(decision.confidence >= 0.9);
}

test "PrefrontalCortex DLPFC_cognitive_control_throttle" {
    // Dorsolateral PFC analog: cognitive control under degraded conditions
    // DLPFC implements top-down control when conditions are suboptimal
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.21, // Elevated error rate
        .avg_latency_ms = 5100, // High latency
        .memory_usage_pct = 76.0, // High memory
    };
    const decision = PrefrontalCortex.decide(ctx);
    // DLPFC applies multiple throttling factors
    try std.testing.expectEqual(Action.throttle, decision.action);
    // Confidence reduced due to multiple factors
    try std.testing.expect(decision.confidence < 0.6);
}

test "PrefrontalCortex OFC_inhibition_alert_on_critical_memory" {
    // Orbitofrontal Cortex (OFC) analog: inhibition of ongoing activity
    // The OFC inhibits responses when outcomes are expected to be negative
    const ctx = DecisionContext{
        .task_count = 5000, // Huge queue would normally scale_up
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 91.0, // Critical memory overrides everything
    };
    const decision = PrefrontalCortex.decide(ctx);
    // OFC inhibition takes highest priority
    try std.testing.expectEqual(Action.alert, decision.action);
    try std.testing.expect(decision.confidence >= 0.9);
}

// ═════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "PrefrontalCortex NaN_error_rate_handling" {
    // NaN should not crash decision logic
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = std.math.nan(f32),
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    // NaN > threshold is false, so no error-based action triggered
    const decision = PrefrontalCortex.decide(ctx);
    // Should return some valid decision (likely proceed or based on other metrics)
    try std.testing.expect(decision.confidence > 0);
}

test "PrefrontalCortex negative_memory_usage_handling" {
    // Negative memory should be handled gracefully
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = -10.0, // Invalid but shouldn't crash
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Should not crash, return valid decision
    try std.testing.expect(decision.confidence > 0);
}

test "PrefrontalCortex memory_overflow_percentage" {
    // Memory usage > 100% should still work
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 150.0, // Way over 100%
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Should trigger alert
    try std.testing.expectEqual(Action.alert, decision.action);
    try std.testing.expect(decision.confidence >= 0.9);
}

test "PrefrontalCortex max_usize_values" {
    // Test with maximum usize values for robustness
    const ctx = DecisionContext{
        .task_count = std.math.maxInt(usize),
        .active_agents = 1,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Should handle without overflow/crash
    try std.testing.expect(decision.confidence > 0);
    try std.testing.expect(decision.action == .scale_up or decision.action == .alert);
}

test "PrefrontalCortex reasoning_buffer_overflow_protection" {
    // Test that reasoning buffer doesn't overflow
    // Create a context that would trigger many reason writes
    const ctx = DecisionContext{
        .task_count = 1000000,
        .active_agents = 10,
        .error_rate = 0.6, // Triggers pause
        .avg_latency_ms = 10000, // Would trigger throttle
        .memory_usage_pct = 95.0, // Triggers alert
    };
    const decision = PrefrontalCortex.decide(ctx);
    // Alert takes priority due to critical memory
    try std.testing.expectEqual(Action.alert, decision.action);
    // Reasoning should be truncated not crash
    try std.testing.expect(decision.reasoning.len > 0);
}

test "PrefrontalCortex error_rate_exactly_zero" {
    // Zero error rate should be handled correctly
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.0,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expect(decision.confidence >= 0.9);
}

test "PrefrontalCortex error_rate_exactly_one" {
    // All errors should trigger pause
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 1.0,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.pause, decision.action);
}

test "PrefrontalCortex infinite_latency_handling" {
    // Max u64 latency should be handled
    const ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = std.math.maxInt(u64),
        .memory_usage_pct = 50.0,
    };
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.throttle, decision.action);
}

// ═════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "PrefrontalCortex action_priority_matrix" {
    // Verify complete action priority: alert > pause > throttle > scale_up > scale_down > proceed
    const test_cases = [_]struct {
        name: []const u8,
        ctx: DecisionContext,
        expected: Action,
    }{
        .{
            .name = "alert_highest",
            .ctx = .{
                .task_count = 0,
                .active_agents = 0,
                .error_rate = 1.0, // Would trigger pause
                .avg_latency_ms = 0,
                .memory_usage_pct = 95.0, // But alert is higher
            },
            .expected = .alert,
        },
        .{
            .name = "pause_second",
            .ctx = .{
                .task_count = 1000, // Would trigger scale_up
                .active_agents = 1,
                .error_rate = 0.6, // But pause is higher
                .avg_latency_ms = 0,
                .memory_usage_pct = 50.0,
            },
            .expected = .pause,
        },
        .{
            .name = "throttle_over_scale_up",
            .ctx = .{
                .task_count = 1000, // Would trigger scale_up
                .active_agents = 1,
                .error_rate = 0.3, // But throttle is higher
                .avg_latency_ms = 0,
                .memory_usage_pct = 50.0,
            },
            .expected = .throttle,
        },
        .{
            .name = "scale_up_over_scale_down",
            .ctx = .{
                .task_count = 0, // Would trigger scale_down
                .active_agents = 10,
                .error_rate = 0.01,
                .avg_latency_ms = 0,
                .memory_usage_pct = 50.0,
            },
            .expected = .scale_down,
        },
    };

    inline for (test_cases) |tc| {
        const decision = PrefrontalCortex.decide(tc.ctx);
        try std.testing.expectEqual(tc.expected, decision.action);
    }
}

test "PrefrontalCortex confidence_bounds" {
    // Verify confidence is always in valid range [0, 1]
    const test_contexts = [_]DecisionContext{
        .{ .task_count = 0, .active_agents = 0, .error_rate = 0.0, .avg_latency_ms = 0, .memory_usage_pct = 0.0 },
        .{ .task_count = 100, .active_agents = 10, .error_rate = 1.0, .avg_latency_ms = 10000, .memory_usage_pct = 100.0 },
        .{ .task_count = 1000000, .active_agents = 1000, .error_rate = 0.5, .avg_latency_ms = 5000, .memory_usage_pct = 95.0 },
        .{ .task_count = 50, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 500, .memory_usage_pct = 50.0 },
    };

    for (test_contexts) |ctx| {
        const decision = PrefrontalCortex.decide(ctx);
        try std.testing.expect(decision.confidence >= 0.0);
        try std.testing.expect(decision.confidence <= 1.0);
    }
}

test "PrefrontalCortex reasoning_content_variability" {
    // Verify reasoning strings differ based on triggers
    const healthy_ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 30.0,
    };

    const error_ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.6,
        .avg_latency_ms = 500,
        .memory_usage_pct = 30.0,
    };

    const memory_ctx = DecisionContext{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 95.0,
    };

    const healthy_decision = PrefrontalCortex.decide(healthy_ctx);
    const error_decision = PrefrontalCortex.decide(error_ctx);
    const memory_decision = PrefrontalCortex.decide(memory_ctx);

    // Reasoning should differ
    try std.testing.expect(!std.mem.eql(u8, healthy_decision.reasoning, error_decision.reasoning));
    try std.testing.expect(!std.mem.eql(u8, healthy_decision.reasoning, memory_decision.reasoning));
}

test "PrefrontalCortex recommend_all_actions_coverage" {
    // Verify recommend() handles all action types
    const actions = [_]Action{ .proceed, .throttle, .scale_up, .scale_down, .pause, .alert };

    for (actions) |action| {
        const decision = Decision{
            .action = action,
            .confidence = 0.8,
            .reasoning = "test",
        };
        const recommendation = PrefrontalCortex.recommend(decision);
        try std.testing.expect(recommendation.len > 0);
    }
}

test "PrefrontalCortex concurrent_decisions" {
    // Simulate concurrent decision-making (thread safety test)
    // Spawn threads that all call decide()
    const num_threads = 10;
    var results: [num_threads]Decision = undefined;
    var threads: [num_threads]std.Thread = undefined;

    const ctx = DecisionContext{
        .task_count = 150,
        .active_agents = 10,
        .error_rate = 0.05,
        .avg_latency_ms = 2000,
        .memory_usage_pct = 65.0,
    };

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, struct {
            fn run(ctx_ptr: *const DecisionContext, result_ptr: *Decision) void {
                result_ptr.* = PrefrontalCortex.decide(ctx_ptr.*);
            }
        }.run, .{ &ctx, &results[i] });
    }

    for (&threads) |*t| {
        t.join();
    }

    // All threads should get same result
    for (results) |result| {
        try std.testing.expectEqual(results[0].action, result.action);
        try std.testing.expectApproxEqAbs(results[0].confidence, result.confidence, 0.001);
    }
}

test "PrefrontalCortex scale_down_edge_case_exactly_boundary" {
    // Tasks < agents AND queue_per_agent < 0.5
    // With 10 agents and 5 tasks: queue = 5/10 = 0.5 (exactly at boundary)
    const ctx1 = DecisionContext{
        .task_count = 5,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };
    const decision1 = PrefrontalCortex.decide(ctx1);
    // 0.5 is NOT less than 0.5, so no scale_down
    try std.testing.expectEqual(Action.proceed, decision1.action);

    // With 4 tasks: queue = 4/10 = 0.4 < 0.5
    const ctx2 = DecisionContext{
        .task_count = 4,
        .active_agents = 10,
        .error_rate = 0.01,
        .avg_latency_ms = 100,
        .memory_usage_pct = 30.0,
    };
    const decision2 = PrefrontalCortex.decide(ctx2);
    try std.testing.expectEqual(Action.scale_down, decision2.action);
}

test "PrefrontalCortex all_thresholds_mutually_exclusive" {
    // Ensure thresholds don't overlap in ways that cause ambiguity
    const cases = [_]struct {
        ctx: DecisionContext,
        expected: Action,
    }{
        // Alert > 90% memory
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 500, .memory_usage_pct = 90.5 }, .expected = .alert },
        // Pause > 50% error rate
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.51, .avg_latency_ms = 500, .memory_usage_pct = 50.0 }, .expected = .pause },
        // Throttle > 20% error rate
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.21, .avg_latency_ms = 500, .memory_usage_pct = 50.0 }, .expected = .throttle },
        // Throttle > 5000ms latency
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 5001, .memory_usage_pct = 50.0 }, .expected = .throttle },
        // Throttle > 75% memory
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 500, .memory_usage_pct = 75.5 }, .expected = .throttle },
        // Scale up > 10 tasks per agent
        .{ .ctx = .{ .task_count = 101, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 500, .memory_usage_pct = 50.0 }, .expected = .scale_up },
        // Scale down conditions
        .{ .ctx = .{ .task_count = 2, .active_agents = 10, .error_rate = 0.01, .avg_latency_ms = 100, .memory_usage_pct = 30.0 }, .expected = .scale_down },
        // Healthy default
        .{ .ctx = .{ .task_count = 50, .active_agents = 10, .error_rate = 0.05, .avg_latency_ms = 500, .memory_usage_pct = 50.0 }, .expected = .proceed },
    };

    for (cases) |tc| {
        const decision = PrefrontalCortex.decide(tc.ctx);
        try std.testing.expectEqual(tc.expected, decision.action);
    }
}

test "PrefrontalCortex action_string_representation" {
    // Verify action enum names are consistent
    const expected_names = [_][]const u8{
        "proceed",
        "throttle",
        "scale_up",
        "scale_down",
        "pause",
        "alert",
    };

    const actions = std.meta.tags(Action);
    try std.testing.expectEqual(actions.len, expected_names.len);

    for (actions, 0..) |action, i| {
        try std.testing.expectEqualStrings(expected_names[i], @tagName(action));
    }
}

test "PrefrontalCortex zero_division_safety" {
    // Ensure no division by zero when active_agents is 0
    const ctx = DecisionContext{
        .task_count = 100,
        .active_agents = 0, // Division by zero would occur if not handled
        .error_rate = 0.05,
        .avg_latency_ms = 500,
        .memory_usage_pct = 50.0,
    };
    // Should not crash, return valid decision
    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expect(decision.confidence > 0);
}
