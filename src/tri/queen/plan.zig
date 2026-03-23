// Queen Plan — Stage 4 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from Evaluate stage
pub const Evaluation = @import("evaluate.zig").Evaluation;

/// ═════════════════════════════════════════════════════════════════════════════════════
// ACTION TYPES — What can be done in Lotus Cycle
/// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ approval check
4. Build execution plan (substeps, dependencies, rollback)
5. Generate PolicyDelta if action modifies policy

// Plan generation with validation
pub fn plan(eval: Evaluation, policy: PolicySnapshot) !Plan {
    var steps = std.ArrayList(Step).init(std.heap.page_allocator);
    defer steps.deinit();

    // Build execution plan based on action type
    switch (eval.action) {
        .scale_up => {
            // Step 1: Read current policy
            try steps.append(Step{
                .name = "Read current policy.json",
                .command = "read_policy",
            });

            // Step 2: Calculate new value
            try steps.append(Step{
                .name = "Calculate scaled threshold",
                .command = "calculate_scale",
            });

            // Step 3: Update policy.json
            try steps.append(Step{
                .name = "Update policy.json",
                .command = "update_policy",
            });

            // Step 4: Validate change
            try steps.append(Step{
                .name = "Validate policy change",
                .command = "validate",
            });
        },

        .scale_down => {
            try steps.append(Step{
                .name = "Read current policy.json",
                .command = "read_policy",
            });

            try steps.append(Step{
                .name = "Calculate scaled threshold",
                .command = "calculate_scale",
            });

            try steps.append(Step{
                .name = "Update policy.json",
                .command = "update_policy",
            });
        },

        .trigger => {
            try steps.append(Step{
                .name = "Execute trigger command",
                .command = eval.key,
            });
        },

        .wait => {
            try steps.append(Step{
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
        .steps = try steps.toOwnedSlice(),
        .rollback = rollback,
    };
}

/// Generate PolicyDelta from Plan
pub fn generatePolicyDelta(plan: Plan) !PolicyDelta {
    const old_value = getPolicyValue(plan.key);

    const new_value = switch (plan.action) {
        .scale_up => union { f64: plan.quality_score * 1.1 },
        .scale_down => union { f64: plan.quality_score * 0.9 },
        else => return PolicyDelta{},
    };

    return PolicyDelta{
        .operation = .scale,
        .key = plan.key,
        .old_value = old_value,
        .new_value = new_value,
        .reason = plan.reason,
        .expected_quality_delta = plan.quality_score,
    };
}

/// Get current policy value by key
fn getPolicyValue(key: []const u8) union { bool: bool, f64: f64 } {
    if (std.mem.eql(u8, key, "kill_threshold")) return .{ .f64 = 4.0 };
    if (std.mem.eql(u8, key, "crash_rate_limit")) return .{ .f64 = 0.2 };
    if (std.mem.eql(u8, key, "byzantine_rate_limit")) return .{ .f64 = 0.15 };
    if (std.mem.eql(u8, key, "god_mode")) return .{ .bool = true };
    if (std.mem.eql(u8, key, "max_auto_level")) return .{ .f64 = 2.0 };

    return .{ .f64 = 0.0 };
}

test "plan: generates valid plan for scale_up" {
    const allocator = std.testing.allocator;

    const eval = Evaluation{
        .action = .scale_up,
        .key = "kill_threshold",
        .quality_score = 0.7,
        .reason = "PPL improved, increase threshold",
    };

    const policy = PolicySnapshot{ .kill_threshold = 4.0 };

    const plan = try plan(eval, policy);

    try std.testing.expect(plan.action == .scale_up);
    try std.testing.expect(plan.steps.len > 0);
    try std.testing.expect(plan.rollback != null);
}
