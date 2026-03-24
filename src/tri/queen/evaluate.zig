// Queen Evaluate — Stage 3 of Lotus Cycle
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Import types from Observe stage
pub const Context = @import("observe.zig").Context;
pub const PolicySnapshot = @import("observe.zig").PolicySnapshot;
pub const SensorsSnapshot = @import("observe.zig").SensorsSnapshot;
const Episode = @import("episodes.zig").Episode;
const createTestEpisode = @import("episodes.zig").createTestEpisode;
pub const Outcome = @import("act.zig").Outcome;

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

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 3: Episode Window Evaluation
// ═══════════════════════════════════════════════════════════════════════════════

/// Quality rating based on success rate
pub const Quality = enum {
    unknown,
    good, // success_rate >= 0.95
    unstable, // 0.70 < success_rate < 0.95
    bad, // success_rate <= 0.70
};

/// Window evaluation result
pub const WindowEvaluation = struct {
    quality: Quality,
    success_rate: f64,
    failure_count: u32,
    window_size: u32,
};

/// Evaluate a window of episodes to determine quality
pub fn evaluateWindow(episodes: []const Episode) WindowEvaluation {
    if (episodes.len == 0) {
        return WindowEvaluation{
            .quality = .unknown,
            .success_rate = 0.0,
            .failure_count = 0,
            .window_size = 0,
        };
    }

    var success_count: u32 = 0;
    var failure_count: u32 = 0;

    for (episodes) |ep| {
        switch (ep.outcome) {
            .success => success_count += 1,
            .partial => failure_count += 1,
            .failure_learned, .failure_unknown, .blocked => failure_count += 1,
        }
    }

    const total: u32 = @intCast(episodes.len);
    const success_rate = if (total > 0)
        @as(f64, @floatFromInt(success_count)) / @as(f64, @floatFromInt(total))
    else
        0.0;

    const quality: Quality = if (success_rate >= 0.95)
        .good
    else if (success_rate <= 0.70)
        .bad
    else
        .unstable;

    return WindowEvaluation{
        .quality = quality,
        .success_rate = success_rate,
        .failure_count = failure_count,
        .window_size = total,
    };
}

test "evaluate: evaluateWindow empty episodes" {
    const episodes = &[_]Episode{};
    const result = evaluateWindow(episodes);

    try std.testing.expectEqual(Quality.unknown, result.quality);
    try std.testing.expectEqual(@as(u32, 0), result.window_size);
}

test "evaluate: evaluateWindow all success" {
    const allocator = std.testing.allocator;
    const episode1 = try createTestEpisode(allocator, .success);
    const episode2 = try createTestEpisode(allocator, .success);
    const episodes = &[_]Episode{ episode1, episode2 };
    const result = evaluateWindow(episodes);

    try std.testing.expectEqual(Quality.good, result.quality);
    try std.testing.expectEqual(@as(f64, 1.0), result.success_rate);
}

test "evaluate: evaluateWindow mixed outcomes" {
    const allocator = std.testing.allocator;
    const episode1 = try createTestEpisode(allocator, .success);
    const episode2 = try createTestEpisode(allocator, .success);
    const episode3 = try createTestEpisode(allocator, .failure_learned);
    const episode4 = try createTestEpisode(allocator, .success);
    const episodes = &[_]Episode{ episode1, episode2, episode3, episode4 };
    const result = evaluateWindow(episodes);

    try std.testing.expectEqual(Quality.unstable, result.quality); // 0.75
    try std.testing.expectEqual(@as(u32, 1), result.failure_count);
}

test "evaluate: evaluateWindow high failure rate" {
    const allocator = std.testing.allocator;
    const episode1 = try createTestEpisode(allocator, .success);
    const episode2 = try createTestEpisode(allocator, .failure_learned);
    const episode3 = try createTestEpisode(allocator, .failure_learned);
    const episode4 = try createTestEpisode(allocator, .blocked);
    const episodes = &[_]Episode{ episode1, episode2, episode3, episode4 };
    const result = evaluateWindow(episodes);

    try std.testing.expectEqual(Quality.bad, result.quality);
    try std.testing.expectEqual(@as(u32, 3), result.failure_count);
}
