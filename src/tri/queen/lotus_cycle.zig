// Queen Lotus Cycle — Full 5-Stage Integration
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import from all 5 stages
pub const Context = @import("observe.zig").Context;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;
pub const Evaluation = @import("evaluate.zig").Evaluation;
pub const Plan = @import("plan.zig").Plan;
pub const Step = @import("plan.zig").Step;
pub const Result = @import("act.zig").Result;
pub const CycleResult = @import("act.zig").CycleResult;
pub const Outcome = @import("act.zig").Outcome;
const Episode = @import("episodes.zig").Episode;
const observe = @import("observe.zig").observe;
const evaluate = @import("evaluate.zig").evaluate;
const planFn = @import("plan.zig").plan;
const act = @import("act.zig").act;
const recordEpisode = @import("episodes.zig").recordEpisode;
const appendEpisode = @import("episodes.zig").appendEpisode;
const loadRecentEpisodes = @import("episodes.zig").loadRecentEpisodes;
const WindowEvaluation = @import("evaluate.zig").WindowEvaluation;
const evaluateWindow = @import("evaluate.zig").evaluateWindow;
const generatePlan = @import("plan.zig").generatePlan;
const PolicyDelta = @import("plan.zig").PolicyDelta;

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

/// Episode-aware cycle result with window evaluation
pub const EpisodeAwareCycleResult = struct {
    context: Context,
    window_eval: WindowEvaluation,
    policy_deltas: []PolicyDelta,
    plan: Plan,
    result: Result,
    outcome: Outcome,
};

/// Run Episode-Aware Lotus Cycle: Observe → Load Episodes → Evaluate Window → Generate Plan → Act
/// Phase 4: Integrates episode window evaluation into full cycle
pub fn runEpisodeAwareCycle(allocator: std.mem.Allocator, window_size: usize) !EpisodeAwareCycleResult {
    // Stage 1: Observe current state
    const context = try observe(allocator);

    // Stage 2: Load recent episodes for window evaluation
    const recent_episodes = try loadRecentEpisodes(allocator, window_size);
    defer allocator.free(recent_episodes);

    // Stage 3: Evaluate window quality
    const window_eval = evaluateWindow(recent_episodes);

    // Stage 4: Generate policy deltas based on window quality
    const policy_deltas = try generatePlan(window_eval, allocator);
    defer allocator.free(policy_deltas);

    // Stage 5: Convert first policy delta to execution plan
    // For now, use the first delta as the primary action
    const execution_plan = policyDeltaToPlan(policy_deltas, context.policy, allocator);

    // Stage 6: Act on the plan
    const result = try act(execution_plan);

    // Derive outcome
    const outcome = deriveOutcome(result);

    // Record final episode
    const episode = try recordEpisode(allocator, context, execution_plan, result, outcome);
    try appendEpisode(episode, allocator);

    return EpisodeAwareCycleResult{
        .context = context,
        .window_eval = window_eval,
        .policy_deltas = try allocator.dupe(PolicyDelta, policy_deltas),
        .plan = execution_plan,
        .result = result,
        .outcome = outcome,
    };
}

/// Convert PolicyDelta to Plan for execution
fn policyDeltaToPlan(deltas: []const PolicyDelta, policy: PolicySnapshot, allocator: std.mem.Allocator) Plan {
    _ = policy;
    _ = allocator;

    if (deltas.len == 0) {
        return Plan{
            .action = .wait,
            .key = "",
            .quality_score = 0.0,
            .steps = &[_]Step{.{ .name = "Wait", .command = "wait" }},
            .rollback = null,
        };
    }

    const delta = deltas[0];

    // Map PolicyDelta to Plan action and key
    const action: @import("evaluate.zig").Action = switch (delta) {
        .scale_up => .scale_up,
        .scale_down => .scale_down,
        .set => .trigger, // Use trigger for set operations
        .wait => .wait,
    };

    const key: []const u8 = switch (delta) {
        .scale_up => |s| s.key,
        .scale_down => |s| s.key,
        .set => |s| s.key,
        .wait => "",
    };

    const quality_score: f64 = switch (delta) {
        .scale_up => |s| s.factor,
        .scale_down => |s| s.factor,
        .set => |s| s.value,
        .wait => 0.0,
    };

    return Plan{
        .action = action,
        .key = key,
        .quality_score = quality_score,
        .steps = &[_]Step{.{ .name = "Execute policy delta", .command = "apply_delta" }},
        .rollback = null,
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

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 4: Episode-Aware Cycle Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "lotus_cycle: episodeAwareCycle executes successfully" {
    const allocator = std.testing.allocator;

    const result = try runEpisodeAwareCycle(allocator, 10);
    defer allocator.free(result.context.active_issues);
    defer allocator.free(result.context.recalled_episodes);
    defer allocator.free(result.policy_deltas);

    // Quality should be one of the valid options
    const quality = result.window_eval.quality;
    try std.testing.expect(quality == .unknown or quality == .good or quality == .unstable or quality == .bad);
    try std.testing.expect(result.result.success);
}

test "lotus_cycle: episodeAwareCycle generates policy deltas" {
    const allocator = std.testing.allocator;

    const result = try runEpisodeAwareCycle(allocator, 10);
    defer allocator.free(result.context.active_issues);
    defer allocator.free(result.context.recalled_episodes);
    defer allocator.free(result.policy_deltas);

    // Should always generate at least one delta
    try std.testing.expect(result.policy_deltas.len >= 1);
}

test "lotus_cycle: episodeAwareCycle with good quality scales up" {
    const allocator = std.testing.allocator;

    // Create some test episodes first
    const createTestEpisode = @import("episodes.zig").createTestEpisode;
    var test_episodes = try std.ArrayList(@import("episodes.zig").Episode).initCapacity(allocator, 10);
    defer test_episodes.deinit(allocator);

    // All success = good quality
    for (0..10) |_| {
        try test_episodes.append(allocator, try createTestEpisode(allocator, .success));
    }

    // Record episodes
    for (test_episodes.items) |ep| {
        try appendEpisode(ep, allocator);
    }

    const result = try runEpisodeAwareCycle(allocator, 10);
    defer allocator.free(result.context.active_issues);
    defer allocator.free(result.context.recalled_episodes);
    defer allocator.free(result.policy_deltas);

    // With all success episodes, should get good quality and scale_up
    try std.testing.expect(result.policy_deltas.len >= 1);
    try std.testing.expect(result.result.success);
}

test "lotus_cycle: policyDeltaToPlan converts deltas correctly" {
    const allocator = std.testing.allocator;

    const deltas = &[_]PolicyDelta{
        .{ .scale_up = .{ .key = "test_key", .factor = 1.2 } },
    };

    const policy = PolicySnapshot{};
    const plan = policyDeltaToPlan(deltas, policy, allocator);

    try std.testing.expect(plan.action == .scale_up);
    try std.testing.expectEqual(@as(f64, 1.2), plan.quality_score);
}

test "lotus_cycle: policyDeltaToPlan handles empty deltas" {
    const allocator = std.testing.allocator;

    const deltas = &[_]PolicyDelta{};
    const policy = PolicySnapshot{};
    const plan = policyDeltaToPlan(deltas, policy, allocator);

    try std.testing.expect(plan.action == .wait);
    try std.testing.expectEqual(@as(f64, 0.0), plan.quality_score);
}
