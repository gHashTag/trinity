// Queen Evaluate — Stage 3 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import types from Observe stage
pub const Context = @import("observe.zig").Context;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;

/// ═════════════════════════════════════════════════════════════════════════════════════
// ACTION CANDIDATES — Possible actions to evaluate
/// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════∎(_T)─

/// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════generates possible actions and ranks them by quality score
pub fn generateCandidates(context: Context) ![]Candidate {
    var candidates = std.ArrayList(Candidate).init(std.heap.page_allocator);
    defer candidates.deinit();

    // 1. Candidate: scale up kill_threshold (if PPL is good)
    if (context.senses.farm_best_ppl < context.policy.kill_threshold) {
        try candidates.append(Candidate{
            .action = .scale_up,
            .key = "kill_threshold",
            .quality_score = 0.5,
            .reason = "PPL better than threshold, can increase",
        });
    }

    // 2. Candidate: scale down kill_threshold (if PPL is worse)
    if (context.senses.farm_best_ppl > context.policy.kill_threshold) {
        try candidates.append(Candidate{
            .action = .scale_down,
            .key = "kill_threshold",
            .quality_score = -0.3,
            .reason = "PPL worse than threshold, should decrease",
        });
    }

    // 3. Candidate: wait (no action needed)
    try candidates.append(Candidate{
        .action = .wait,
        .key = "",
        .quality_score = 0.0,
        .reason = "No clear action, observe more",
    });

    // 4. Candidate: trigger farm status check
    try candidates.append(Candidate{
        .action = .trigger,
        .key = "farm_status",
        .quality_score = 0.2,
        .reason = "Check current farm state",
    });

    return candidates.toOwnedSlice();
}

/// Evaluate candidates and return best action
pub fn evaluate(context: Context) !Evaluation {
    const candidates = try generateCandidates(context);

    if (candidates.len == 0) {
        return Evaluation{
            .action = .wait,
            .quality_score = 0.0,
            .reason = "No candidates generated",
        };
    }

    // Find best candidate (highest quality_score)
    var best_idx: usize = 0;
    var best_score: f64 = candidates[0].quality_score;

    for (candidates[1..], 1..) |candidate, i| {
        if (candidate.quality_score > best_score) {
            best_score = candidate.quality_score;
            best_idx = i;
        }
    }

    return Evaluation{
        .action = candidates[best_idx].action,
        .quality_score = best_score,
        .reason = candidates[best_idx].reason,
    };
}

/// Generate actions based on heuristics
pub fn generateCandidateActions(context: Context) ![]Candidate {
    var candidates = std.ArrayList(Candidate).init(std.heap.page_allocator);
    defer candidates.deinit();

    // 1. Farm optimization: adjust kill_threshold based on PPL
    const ppl_diff = context.senses.farm_best_ppl - context.policy.kill_threshold;

    if (ppl_diff < -0.5) {
        // PPL is better, can increase threshold
        try candidates.append(Candidate{
            .action = .scale_up,
            .key = "kill_threshold",
            .quality_score = 0.7,
            .reason = "PPL improved, increase kill threshold",
        });
    } else if (ppl_diff > 0.5) {
        // PPL is worse, should decrease threshold
        try candidates.append(Candidate{
            .action = .scale_down,
            .key = "kill_threshold",
            .quality_score = 0.6,
            .reason = "PPL degraded, decrease kill threshold",
        });
    }

    // 2. Check if dirty files need cleanup
    if (context.senses.dirty_files > 20) {
        try candidates.append(Candidate{
            .action = .trigger,
            .key = "doctor_scan",
            .quality_score = 0.4,
            .reason = "High dirty file count, trigger doctor scan",
        });
    }

    // 3. Wait if everything looks stable
    if (candidates.items.len == 0) {
        try candidates.append(Candidate{
            .action = .wait,
            .key = "",
            .quality_score = 0.0,
            .reason = "System stable, no action needed",
        });
    }

    return candidates.toOwnedSlice();
}

/// Score a candidate action based on context
fn scoreCandidate(candidate: Candidate, context: Context) f64 {
    var score: f64 = candidate.quality_score;

    // Bonus for actions that improve metrics
    if (candidate.action == .scale_up and context.senses.farm_best_ppl < 3.0) {
        score += 0.2;
    }

    // Penalty for actions that might degrade metrics
    if (candidate.action == .scale_down and context.senses.farm_best_ppl > 5.0) {
        score -= 0.3;
    }

    return score;
}

test "evaluate: returns valid evaluation" {
    const allocator = std.testing.allocator;

    // Create a test context
    const context = Context{
        .timestamp_ns = std.time.nanoTimestamp(),
        .policy = PolicySnapshot{ .kill_threshold = 4.0 },
        .senses = SensorsSnapshot{
            .farm_best_ppl = 3.5,
            .dirty_files = 25,
        },
        .active_issues = &[_]u64{},
    };

    const eval = try evaluate(context);

    // Should recommend action (not wait)
    try std.testing.expect(eval.action != .wait);
    try std.testing.expect(eval.quality_score >= 0.0);
}

test "generateCandidateActions: with PPL improvement" {
    const allocator = std.testing.allocator;

    const context = Context{
        .timestamp_ns = std.time.nanoTimestamp(),
        .policy = PolicySnapshot{ .kill_threshold = 4.0 },
        .senses = SensorsSnapshot{
            .farm_best_ppl = 3.0, // Better than threshold
            .dirty_files = 5,
        },
        .active_issues = &[_]u64{},
    };

    const candidates = try generateCandidateActions(context);
    defer allocator.free(candidates);

    // Should have at least one candidate
    try std.testing.expect(candidates.len > 0);
}
