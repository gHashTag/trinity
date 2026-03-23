// Queen Plan — Stage 4 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from Evaluate stage
pub const Evaluation = @import("evaluate.zig").Evaluation;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const Action = @import("evaluate.zig").Action;
pub const Context = @import("observe.zig").Context;

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
