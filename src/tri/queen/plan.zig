// Queen Plan — Stage 4 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from Evaluate stage
pub const Evaluation = @import("evaluate.zig").Evaluation;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const Action = @import("evaluate.zig").Action;
pub const Context = @import("observe.zig").Context;
pub const WindowEvaluation = @import("evaluate.zig").WindowEvaluation;
pub const Quality = @import("evaluate.zig").Quality;

/// Policy delta — action to modify policy
pub const PolicyDelta = union(enum) {
    scale_up: struct { key: []const u8, factor: f64 },
    scale_down: struct { key: []const u8, factor: f64 },
    set: struct { key: []const u8, value: f64 },
    wait: void,
};

/// Plan step
pub const Step = struct {
    name: []const u8,
    command: []const u8,
};

/// Rollback plan
pub const Rollback = struct {
    action: Action,
    key: []const u8,
    reason: []const u8,
};

/// Plan generated from evaluation
pub const Plan = struct {
    action: Action,
    key: []const u8,
    quality_score: f64,
    steps: []const Step,
    rollback: ?Rollback,
};

/// Generate execution plan
pub fn plan(eval: Evaluation, policy: PolicySnapshot) !Plan {
    _ = policy;

    var steps = try std.ArrayList(Step).initCapacity(std.heap.page_allocator, 0);
    defer steps.deinit(std.heap.page_allocator);

    // Build execution plan based on action type
    switch (eval.action) {
        .scale_up => {
            // Step 1: Read current policy
            try steps.append(std.heap.page_allocator, Step{
                .name = "Read current policy.json",
                .command = "read_policy",
            });

            // Step 2: Calculate new value
            try steps.append(std.heap.page_allocator, Step{
                .name = "Calculate scaled threshold",
                .command = "calculate_scale",
            });

            // Step 3: Update policy.json
            try steps.append(std.heap.page_allocator, Step{
                .name = "Update policy.json",
                .command = "update_policy",
            });

            // Step 4: Validate change
            try steps.append(std.heap.page_allocator, Step{
                .name = "Validate policy change",
                .command = "validate",
            });
        },

        .scale_down => {
            try steps.append(std.heap.page_allocator, Step{
                .name = "Read current policy.json",
                .command = "read_policy",
            });

            try steps.append(std.heap.page_allocator, Step{
                .name = "Calculate scaled threshold",
                .command = "calculate_scale",
            });

            try steps.append(std.heap.page_allocator, Step{
                .name = "Update policy.json",
                .command = "update_policy",
            });
        },

        .trigger => {
            try steps.append(std.heap.page_allocator, Step{
                .name = "Execute trigger command",
                .command = eval.key,
            });
        },

        .wait => {
            try steps.append(std.heap.page_allocator, Step{
                .name = "Wait and observe",
                .command = "wait",
            });
        },
    }

    // Build rollback plan
    const rollback = if (eval.action == .scale_up or eval.action == .scale_down)
        Rollback{
            .action = .scale_down,
            .key = eval.key,
            .reason = "Reverse policy change if needed",
        }
    else
        null;

    return Plan{
        .action = eval.action,
        .key = eval.key,
        .quality_score = eval.quality_score,
        .steps = try steps.toOwnedSlice(std.heap.page_allocator),
        .rollback = rollback,
    };
}

/// Generate policy deltas from window evaluation
/// Phase 3 function: analyzes quality and recommends policy changes
pub fn generatePlan(eval: WindowEvaluation, allocator: std.mem.Allocator) ![]PolicyDelta {
    var deltas = try std.ArrayList(PolicyDelta).initCapacity(allocator, 0);
    defer deltas.deinit(allocator);

    switch (eval.quality) {
        .good => {
            // Quality is good - consider scaling up
            try deltas.append(allocator, PolicyDelta{
                .scale_up = .{
                    .key = "kill_threshold",
                    .factor = 1.1, // 10% increase
                },
            });

            // Also set higher PPL target
            try deltas.append(allocator, PolicyDelta{
                .set = .{
                    .key = "target_ppl",
                    .value = eval.success_rate * 0.95, // Slightly better
                },
            });
        },

        .unstable => {
            // Quality is unstable - wait and observe
            try deltas.append(allocator, PolicyDelta{
                .scale_down = .{
                    .key = "kill_threshold",
                    .factor = 0.95, // 5% decrease
                },
            });

            try deltas.append(allocator, PolicyDelta{
                .wait = {},
            });
        },

        .bad => {
            // Quality is bad - aggressive scaling down
            try deltas.append(allocator, PolicyDelta{
                .scale_down = .{
                    .key = "kill_threshold",
                    .factor = 0.8, // 20% decrease
                },
            });

            try deltas.append(allocator, PolicyDelta{
                .set = .{
                    .key = "target_ppl",
                    .value = 0.0, // Reset target
                },
            });
        },

        .unknown => {
            // No data - wait
            try deltas.append(allocator, PolicyDelta{
                .wait = {},
            });
        },
    }

    return try deltas.toOwnedSlice(allocator);
}

test "plan: generates valid plan for scale_up" {
    const eval = Evaluation{
        .action = .scale_up,
        .key = "kill_threshold",
        .quality_score = 0.7,
        .reason = "PPL improved, increase threshold",
    };

    const policy = PolicySnapshot{ .kill_threshold = 4.0 };

    const plan_result = try plan(eval, policy);

    try std.testing.expect(plan_result.action == .scale_up);
    try std.testing.expect(plan_result.steps.len > 0);
    try std.testing.expect(plan_result.rollback != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 3: generatePlan() Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "plan: generatePlan good quality scales up" {
    const allocator = std.testing.allocator;

    const eval = WindowEvaluation{
        .quality = .good,
        .success_rate = 0.98,
        .failure_count = 1,
        .window_size = 50,
    };

    const deltas = try generatePlan(eval, allocator);
    defer allocator.free(deltas);

    try std.testing.expect(deltas.len >= 1);
    try std.testing.expect(deltas[0] == .scale_up);
    try std.testing.expectEqual(@as(f64, 1.1), deltas[0].scale_up.factor);
}

test "plan: generatePlan unstable quality scales down slightly" {
    const allocator = std.testing.allocator;

    const eval = WindowEvaluation{
        .quality = .unstable,
        .success_rate = 0.85,
        .failure_count = 8,
        .window_size = 50,
    };

    const deltas = try generatePlan(eval, allocator);
    defer allocator.free(deltas);

    try std.testing.expect(deltas.len >= 2);
    try std.testing.expect(deltas[0] == .scale_down);
    try std.testing.expectEqual(@as(f64, 0.95), deltas[0].scale_down.factor);
    try std.testing.expect(deltas[1] == .wait);
}

test "plan: generatePlan bad quality scales down aggressively" {
    const allocator = std.testing.allocator;

    const eval = WindowEvaluation{
        .quality = .bad,
        .success_rate = 0.65,
        .failure_count = 18,
        .window_size = 50,
    };

    const deltas = try generatePlan(eval, allocator);
    defer allocator.free(deltas);

    try std.testing.expect(deltas.len >= 2);
    try std.testing.expect(deltas[0] == .scale_down);
    try std.testing.expectEqual(@as(f64, 0.8), deltas[0].scale_down.factor);
    try std.testing.expect(deltas[1] == .set);
    try std.testing.expectEqual(@as(f64, 0.0), deltas[1].set.value);
}

test "plan: generatePlan unknown quality waits" {
    const allocator = std.testing.allocator;

    const eval = WindowEvaluation{
        .quality = .unknown,
        .success_rate = 0.0,
        .failure_count = 0,
        .window_size = 0,
    };

    const deltas = try generatePlan(eval, allocator);
    defer allocator.free(deltas);

    try std.testing.expectEqual(@as(usize, 1), deltas.len);
    try std.testing.expect(deltas[0] == .wait);
}
