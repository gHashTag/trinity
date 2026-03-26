//! HABENULA (Reticular Formation) — Reward/Effort Ratio
//! Detects unfair reward (effort >> reward) -> SUSPICIOUS

const std = @import("std");

pub const Reason = struct {
    reward_ratio: f32,
    message: []const u8,
};

pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    _ = args;

    const MIN_RATIO: f32 = 0.3; // reward < 0.3 × effort = SUSPICIOUS
    const RECENT_EPISODES: usize = 10;

    // Import experience module (inline to avoid path issues in test)
    const ExperienceStore = struct {
        episodes: []const struct {
            timestamp: i64,
            success: bool,
            iterations: u32,
            learning_count: u32,
            mistake_count: u32,
        },
    };

    // Mock experience data (in production, load from .trinity/experience/)
    const mock_episodes = [_]struct {
        timestamp: i64,
        success: bool,
        iterations: u32,
        learning_count: u32,
        mistake_count: u32,
    }{
        .{ .timestamp = -3600, .success = true, .iterations = 1, .learning_count = 1, .mistake_count = 0 },
        .{ .timestamp = -1800, .success = true, .iterations = 50, .learning_count = 0, .mistake_count = 2 },
        .{ .timestamp = -900, .success = false, .iterations = 10, .learning_count = 0, .mistake_count = 1 },
    };

    var total_reward: f32 = 0.0;
    var total_effort: f32 = 0.0;

    for (mock_episodes) |ep| {
        const reward: f32 = if (ep.success) 1.0 else 0.0;
        const effort: f32 = @as(f32, @floatFromInt(ep.iterations)) +
            @as(f32, @floatFromInt(ep.mistake_count)) * 2.0;
        total_reward += reward;
        total_effort += effort;
    };

    const avg_ratio = if (total_effort > 0) total_reward / total_effort else 1.0;
    const is_suspicious = avg_ratio < MIN_RATIO;

    // Create experience store and calculate ratio
    var store = try tri_experience.createDefaultStore(allocator);
    defer store.deinit();

    const avg_ratio = store.avgRewardEffortRatio(RECENT_EPISODES);
    const stats = store.getStats();

    // Find suspicious episodes
    const suspicious_indices = try store.findSuspiciousEpisodes(MIN_RATIO, allocator);
    defer allocator.free(suspicious_indices);

    const is_suspicious = avg_ratio < MIN_RATIO or suspicious_indices.len > 0;

    var message: []const u8 = undefined;
    if (is_suspicious) {
        message = try std.fmt.allocPrint(allocator,
            \\🧠 HABENULA: SUSPICIOUS reward/effort ratio detected!
            \\
            \\  Ratio: {d:.3} (threshold: {d:.1})
            \\  Total episodes: {d}
            \\  Success rate: {d:.1}%
            \\  Suspicious episodes: {d}
            \\
            \\  Analysis: High effort with low reward indicates possible:
            \\  - Suboptimal tool selection
            \\  - Missing prerequisite information
            \\  - Environment/configuration issues
            \\  - Overly complex approach for simple task
        , .{
            avg_ratio,              MIN_RATIO,
            stats.total_episodes,   stats.successRate() * 100.0,
            suspicious_indices.len,
        });
    } else {
        message = try std.fmt.allocPrint(allocator,
            \\🧠 HABENULA: reward/effort ratio healthy
            \\
            \\  Ratio: {d:.3} (threshold: {d:.1})
            \\  Total episodes: {d}
            \\  Success rate: {d:.1}%
            \\  Status: NORMAL
        , .{
            avg_ratio,            MIN_RATIO,
            stats.total_episodes, stats.successRate() * 100.0,
        });
    }

    return message;
}
