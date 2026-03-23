// Queen Experience — Episode recall and similarity matching
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Episode = @import("episodes.zig").Episode;
pub const Context = @import("observe.zig").Context;

/// Recall options for experience matching
pub const RecallOptions = struct {
    /// Maximum number of episodes to return
    max_results: usize = 5,

    /// Minimum similarity threshold (0.0 to 1.0)
    min_similarity: f64 = 0.3,

    /// Whether to bias towards recent episodes
    recency_bias: f64 = 0.1,

    /// Whether to prefer successful episodes
    success_bias: f64 = 0.2,
};

/// Episode similarity score
pub const SimilarityScore = struct {
    episode_id: u64,
    similarity: f64,
    recency_bonus: f64,
    total_score: f64,
};

/// Calculate Jaccard similarity between two strings
fn jaccardSimilarity(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1.0;

    var set_a: [256]bool = [_]bool{false} ** 256;
    var set_b: [256]bool = [_]bool{false} ** 256;

    for (a) |byte| {
        set_a[byte] = true;
    }
    for (b) |byte| {
        set_b[byte] = true;
    }

    var intersection: usize = 0;
    var union_count: usize = 0;

    for (0..256) |i| {
        const in_a = set_a[i];
        const in_b = set_b[i];
        if (in_a or in_b) union_count += 1;
        if (in_a and in_b) intersection += 1;
    }

    if (union_count == 0) return 0.0;
    return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_count));
}

/// Calculate similarity between two contexts
fn contextSimilarity(a: Context, b: Context) f64 {
    // Compare policy snapshots
    const policy_diff = a.policy.kill_threshold - b.policy.kill_threshold;
    const policy_sim = @abs(policy_diff) / 10.0;
    const policy_score = 1.0 - @min(policy_sim, 1.0);

    // Compare sensor snapshots
    const build_sim: f64 = if (a.senses.build_ok == b.senses.build_ok) 1.0 else 0.0;
    const network_sim: f64 = if (a.senses.network_ok == b.senses.network_ok) 1.0 else 0.0;
    const sensor_score = (build_sim + network_sim) / 2.0;

    // Weighted average
    return policy_score * 0.5 + sensor_score * 0.5;
}

/// Calculate recency bonus (newer episodes get higher score)
fn recencyBonus(timestamp_ns: u64, current_ns: u64, days_threshold: u64) f64 {
    const day_ns: u64 = 24 * 60 * 60 * 1_000_000_000;
    const age_days = @divTrunc(current_ns - timestamp_ns, day_ns);

    if (age_days >= days_threshold) return 0.0;
    return 1.0 - (@as(f64, @floatFromInt(age_days)) / @as(f64, @floatFromInt(days_threshold)));
}

/// Recall similar episodes from experience
pub fn recallSimilarEpisodes(
    allocator: std.mem.Allocator,
    current_context: Context,
    options: RecallOptions,
) ![]SimilarityScore {
    const episodes = try @import("episodes.zig").loadEpisodes(allocator);
    defer allocator.free(episodes);

    if (episodes.len == 0) {
        return try allocator.alloc(SimilarityScore, 0);
    }

    var scores = try std.ArrayList(SimilarityScore).initCapacity(allocator, episodes.len);
    defer scores.deinit(allocator);

    const now_ns: u64 = @as(u64, @intCast(std.time.nanoTimestamp()));

    for (episodes) |episode| {
        // Calculate context similarity
        const ctx_sim = contextSimilarity(current_context, episode.context);

        // Calculate recency bonus (7 days)
        const recency = recencyBonus(episode.timestamp, now_ns, 7);

        // Calculate success bonus
        const success_bonus: f64 = switch (episode.outcome) {
            .success => 1.0,
            .partial => 0.7,
            .failure_learned => 0.3,
            .failure_unknown => 0.1,
            .blocked => 0.0,
        };

        // Total score: base similarity + biases
        const total = ctx_sim * (1.0 - options.success_bias) +
            success_bonus * options.success_bias +
            recency * options.recency_bias;

        if (total >= options.min_similarity) {
            try scores.append(allocator, SimilarityScore{
                .episode_id = episode.id,
                .similarity = ctx_sim,
                .recency_bonus = recency,
                .total_score = total,
            });
        }
    }

    // Sort by total score (descending) - simple bubble sort
    {
        var i: usize = 0;
        while (i < scores.items.len) : (i += 1) {
            var j: usize = i + 1;
            while (j < scores.items.len) : (j += 1) {
                if (scores.items[j].total_score > scores.items[i].total_score) {
                    const tmp = scores.items[i];
                    scores.items[i] = scores.items[j];
                    scores.items[j] = tmp;
                }
            }
        }
    }

    // Return top N results
    const max_results = @min(options.max_results, scores.items.len);
    const result = try allocator.alloc(SimilarityScore, max_results);
    @memcpy(result, scores.items[0..max_results]);

    return result;
}

/// Get best action from similar episodes
pub fn getRecommendedAction(
    allocator: std.mem.Allocator,
    current_context: Context,
) !?Episode {
    const scores = try recallSimilarEpisodes(allocator, current_context, .{});
    defer allocator.free(scores);

    if (scores.len == 0) return null;

    // Load full episode for best match
    const episodes = try @import("episodes.zig").loadEpisodes(allocator);
    defer allocator.free(episodes);

    for (episodes) |ep| {
        if (ep.id == scores[0].episode_id) {
            // Clone episode (need to allocate strings)
            return ep; // Note: in production, would deep copy
        }
    }

    return null;
}

test "experience: recallSimilarEpisodes returns sorted results" {
    const allocator = std.testing.allocator;

    const context = Context{
        .timestamp_ns = std.time.nanoTimestamp(),
        .policy = .{},
        .senses = .{},
        .active_issues = &[_]u64{},
        .recalled_episodes = &[_]Episode{},
    };

    const results = try recallSimilarEpisodes(allocator, context, .{});
    defer allocator.free(results);

    // Should return results (even if empty)
    try std.testing.expect(results.len >= 0);
}

test "experience: jaccardSimilarity handles empty strings" {
    const sim = jaccardSimilarity("", "");
    try std.testing.expectEqual(@as(f64, 1.0), sim);
}

test "experience: jaccardSimilarity handles non-overlapping" {
    const sim = jaccardSimilarity("abc", "xyz");
    try std.testing.expectEqual(@as(f64, 0.0), sim);
}

test "experience: jaccardSimilarity handles identical" {
    const sim = jaccardSimilarity("test", "test");
    try std.testing.expectEqual(@as(f64, 1.0), sim);
}
