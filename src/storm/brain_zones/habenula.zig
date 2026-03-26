//! HABENULA (Reticular Formation) — Reward/Effort Ratio
//! Detects unfair reward (effort >> reward) -> SUSPICIOUS

const std = @import("std");
const tri_experience = @import("../../farm/tri_experience.zig");

pub const Reason = struct {
    reward_ratio: f32,
    message: []const u8,
};

pub fn cmdUnfairDetect(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    _ = args;

    const MIN_RATIO: f32 = 0.3; // reward < 0.3 × effort = SUSPICIOUS
    const RECENT_EPISODES: usize = 10;

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
