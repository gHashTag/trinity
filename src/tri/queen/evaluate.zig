// Queen Evaluate — Stage 3 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Import types from Observe stage
pub const Context = @import("observe.zig").Context;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;
const Episode = @import("episodes.zig").Episode;

/// Action that can be taken
pub const Action = enum {
    scale_up,
    scale_down,
    trigger,
    wait,
};

/// Candidate action with quality score
pub const Candidate = struct {
    action: Action,
    key: []const u8,
    quality_score: f64,
    reason: []const u8,
};

/// Evaluation result
pub const Evaluation = struct {
    action: Action,
    key: []const u8,
    quality_score: f64,
    reason: []const u8,
};

/// Generate candidates based on context
pub fn generateCandidates(context: Context) ![]Candidate {
    var candidates = try std.ArrayList(Candidate).initCapacity(std.heap.page_allocator, 0);
    defer candidates.deinit(std.heap.page_allocator);

    // 1. Candidate: scale up kill_threshold (if PPL is good)
    if (context.senses.farm_best_ppl < context.policy.kill_threshold) {
        try candidates.append(std.heap.page_allocator, Candidate{
            .action = .scale_up,
            .key = "kill_threshold",
            .quality_score = 0.5,
            .reason = "PPL better than threshold, can increase",
        });
    }

    // 2. Candidate: scale down kill_threshold (if PPL is worse)
    if (context.senses.farm_best_ppl > context.policy.kill_threshold) {
        try candidates.append(std.heap.page_allocator, Candidate{
            .action = .scale_down,
            .key = "kill_threshold",
            .quality_score = -0.3,
            .reason = "PPL worse than threshold, should decrease",
        });
    }

    // 3. Candidate: wait (no action needed)
    try candidates.append(std.heap.page_allocator, Candidate{
        .action = .wait,
        .key = "",
        .quality_score = 0.0,
        .reason = "No clear action, observe more",
    });

    // 4. Candidate: trigger farm status check
    try candidates.append(std.heap.page_allocator, Candidate{
        .action = .trigger,
        .key = "farm_status",
        .quality_score = 0.2,
        .reason = "Check current farm state",
    });

    return try candidates.toOwnedSlice(std.heap.page_allocator);
}

/// Generate candidate actions from context
pub fn generateCandidateActions(context: Context) ![]Candidate {
    return try generateCandidates(context);
}

/// Score a candidate based on context
fn scoreCandidate(candidate: Candidate, context: Context) f64 {
    _ = context;
    return candidate.quality_score;
}

/// Evaluate candidates and return best action
pub fn evaluate(context: Context) !Evaluation {
    const candidates = try generateCandidates(context);

    if (candidates.len == 0) {
        return Evaluation{
            .action = .wait,
            .key = "",
            .quality_score = 0.0,
            .reason = "No candidates generated",
        };
    }

    // Find best candidate by score
    var best_candidate = candidates[0];
    for (candidates[1..]) |cand| {
        if (scoreCandidate(cand, context) > scoreCandidate(best_candidate, context)) {
            best_candidate = cand;
        }
    }

    return Evaluation{
        .action = best_candidate.action,
        .key = best_candidate.key,
        .quality_score = best_candidate.quality_score,
        .reason = best_candidate.reason,
    };
}

test "evaluate: generates valid evaluation" {
    const context = Context{
        .timestamp_ns = 1234567890,
        .policy = .{},
        .senses = .{},
        .active_issues = &[_]u64{},
        .recalled_episodes = &[_]Episode{},
    };

    const result = try evaluate(context);

    try std.testing.expect(result.action == .scale_up or result.action == .wait);
    try std.testing.expect(result.quality_score >= 0.0);
}
