// Queen Lotus Cycle — Full 5-Stage Integration
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from all 5 stages
pub const Context = @import("observe.zig").Context;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;
pub const Evaluation = @import("evaluate.zig").Evaluation;
pub const Plan = @import("plan.zig").Plan;
pub const Result = @import("act.zig").Result;
pub const CycleResult = @import("act.zig").CycleResult;
pub const Outcome = @import("act.zig").Outcome;
const observe = @import("observe.zig").observe;
const evaluate = @import("evaluate.zig").evaluate;
const planFn = @import("plan.zig").plan;
const act = @import("act.zig").act;
const recordEpisode = @import("episodes.zig").recordEpisode;
const appendEpisode = @import("episodes.zig").appendEpisode;

/// Run complete Lotus Cycle: Observe → Record Episode → Evaluate → Plan → Act
pub fn runFullCycle(allocator: std.mem.Allocator) !CycleResult {
    // Stage 1: Observe
    const context = try observe(allocator);

    // Stage 2: Record Episode (pre-action trace)
    // Note: Episode will be updated after action completes
    // This stage is for audit trail and crash recovery

    // Stage 3: Evaluate
    const evaluation = try evaluate(context);

    // Stage 4: Plan
    const execution_plan = try planFn(evaluation, context.policy);

    // Stage 5: Act
    const result = try act(execution_plan);

    // Derive outcome
    const outcome = deriveOutcome(result);

    // Record final episode to persistent storage
    const episode = try recordEpisode(allocator, context, execution_plan, result, outcome);
    try appendEpisode(episode, allocator);

    return CycleResult{
        .context = context,
        .evaluation = evaluation,
        .plan = execution_plan,
        .result = result,
        .outcome = outcome,
    };
}

/// Derive outcome from result
fn deriveOutcome(result: Result) Outcome {
    if (!result.success) return .failure_learned;
    if (result.timing.duration_ms < 100) return .success;
    return .partial;
}

test "lotus_cycle: full cycle executes successfully" {
    const allocator = std.testing.allocator;

    const result = try runFullCycle(allocator);
    defer allocator.free(result.context.active_issues);
    defer allocator.free(result.context.recalled_episodes);

    try std.testing.expect(result.result.success);
    try std.testing.expect(result.outcome != .failure_unknown);
}
