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
        var reasons = std.ArrayList(u8).init(std.heap.page_allocator);
        defer reasons.deinit();

        // Check error rate
        if (ctx.error_rate > 0.5) {
            action = .pause;
            confidence = 0.9;
            reasons.appendSlice("High error rate;") catch {};
        } else if (ctx.error_rate > 0.2) {
            action = .throttle;
            confidence = 0.7;
            reasons.appendSlice("Elevated error rate;") catch {};
        }

        // Check queue depth
        const queue_per_agent = if (ctx.active_agents > 0)
            @as(f32, @floatFromInt(ctx.task_count)) / @as(f32, @floatFromInt(ctx.active_agents))
        else 0;

        if (queue_per_agent > 10) {
            if (action == .proceed) action = .scale_up;
            confidence *= 0.9;
            reasons.appendSlice("High queue depth;") catch {};
        }

        // Check latency
        if (ctx.avg_latency_ms > 5000) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.8;
            reasons.appendSlice("High latency;") catch {};
        }

        // Check memory
        if (ctx.memory_usage_pct > 90) {
            action = .alert;
            confidence = 0.95;
            reasons.appendSlice("Critical memory usage;") catch {};
        } else if (ctx.memory_usage_pct > 75) {
            if (action == .proceed) action = .throttle;
            confidence *= 0.85;
            reasons.appendSlice("High memory usage;") catch {};
        }

        // Scale down if underutilized
        if (ctx.task_count < ctx.active_agents and queue_per_agent < 0.5) {
            if (action == .proceed) action = .scale_down;
            confidence *= 0.8;
            reasons.appendSlice("Underutilized;") catch {};
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
    const ctx = .{
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
    const ctx = .{
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
    const ctx = .{
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
    const ctx = .{
        .task_count = 50,
        .active_agents = 10,
        .error_rate = 0.1,
        .avg_latency_ms = 500,
        .memory_usage_pct = 95.0,
    };

    const decision = PrefrontalCortex.decide(ctx);
    try std.testing.expectEqual(Action.alert, decision.action);
}
