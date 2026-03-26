// TRI EXPERIENCE — Experience tracking for learning from past actions
//
// Tracks episodes, outcomes, and learnings to enable:
// - Reward/effort ratio calculation (Habenula)
// - Pattern recognition in failures
// - Adaptive strategy selection
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Episode = struct {
    timestamp: i64 = 0,
    command: []const u8 = "",
    detail: []const u8 = "",
    success: bool = false,
    issue: u32 = 0,
    task: [256]u8 = [_]u8{0} ** 256,
    task_len: usize = 0,
    verdict: [256]u8 = [_]u8{0} ** 256,
    verdict_len: usize = 0,
    iterations: u32 = 0,
    learning_count: u32 = 0,
    learnings: [5][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 5,
    learning_lens: [5]usize = [_]usize{0} ** 5,
    mistake_count: u32 = 0,
    mistakes: [5][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 5,
    mistake_lens: [5]usize = [_]usize{0} ** 5,

    /// Calculate effort score based on iterations and complexity
    pub fn effortScore(self: *const Episode) f32 {
        const base_effort: f32 = @floatFromInt(self.iterations);
        const task_complexity: f32 = @floatFromInt(self.task_len);
        const mistake_penalty: f32 = @as(f32, @floatFromInt(self.mistake_count)) * 2.0;
        return base_effort + (task_complexity * 0.1) + mistake_penalty;
    }

    /// Calculate reward score (1.0 for success, 0.0 for failure, with modifiers)
    pub fn rewardScore(self: *const Episode) f32 {
        var reward: f32 = if (self.success) 1.0 else 0.0;

        // Learning bonus: +0.1 per unique learning
        reward += @as(f32, @floatFromInt(self.learning_count)) * 0.1;

        // Efficiency bonus: fewer iterations = higher reward
        if (self.iterations > 0) {
            const efficiency = 10.0 / @min(10.0, @as(f32, @floatFromInt(self.iterations)));
            reward += efficiency * 0.2;
        }

        return @min(2.0, reward); // Cap at 2.0
    }

    /// Get reward/effort ratio (for Habenula unfair detection)
    pub fn rewardEffortRatio(self: *const Episode) f32 {
        const effort = self.effortScore();
        if (effort < 0.01) return 0.0;
        return self.rewardScore() / effort;
    }
};

/// Experience store (in-memory, could be persisted to disk)
pub const ExperienceStore = struct {
    allocator: Allocator,
    episodes: std.ArrayList(Episode),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var episodes_list: std.ArrayList(Episode) = .empty;
        try episodes_list.ensureTotalCapacityPrecise(allocator, 100);
        return .{
            .allocator = allocator,
            .episodes = episodes_list,
        };
    }

    pub fn deinit(self: *Self) void {
        self.episodes.deinit(self.allocator);
    }

    /// Add episode to store
    pub fn addEpisode(self: *Self, episode: Episode) !void {
        try self.episodes.append(self.allocator, episode);
    }

    /// Calculate average reward/effort ratio across recent episodes
    pub fn avgRewardEffortRatio(self: *Self, recent_n: usize) f32 {
        if (self.episodes.items.len == 0) return 1.0;

        const count = @min(recent_n, self.episodes.items.len);
        const start_idx = self.episodes.items.len - count;

        var total: f64 = 0.0;
        for (self.episodes.items[start_idx..]) |ep| {
            total += ep.rewardEffortRatio();
        }

        return @floatCast(total / @as(f64, @floatFromInt(count)));
    }

    /// Find episodes with suspiciously low reward/effort ratio
    pub fn findSuspiciousEpisodes(self: *Self, threshold: f32, allocator: Allocator) ![]const usize {
        var suspicious = std.ArrayList(usize).empty;
        try suspicious.ensureTotalCapacityPrecise(allocator, 16);
        defer suspicious.deinit(allocator);

        for (self.episodes.items, 0..) |ep, i| {
            if (ep.rewardEffortRatio() < threshold) {
                try suspicious.append(allocator, i);
            }
        }

        // Copy to allocated slice
        const result = try allocator.alloc(usize, suspicious.items.len);
        @memcpy(result, suspicious.items);
        return result;
    }

    /// Get statistics across all episodes
    pub fn getStats(self: *const Self) Stats {
        var stats = Stats{
            .total_episodes = self.episodes.items.len,
            .success_count = 0,
            .failure_count = 0,
            .total_iterations = 0,
            .avg_iterations = 0.0,
        };

        if (self.episodes.items.len == 0) return stats;

        for (self.episodes.items) |ep| {
            if (ep.success) stats.success_count += 1 else stats.failure_count += 1;
            stats.total_iterations += ep.iterations;
        }

        stats.avg_iterations = @as(f32, @floatFromInt(stats.total_iterations)) /
            @as(f32, @floatFromInt(stats.total_episodes));

        return stats;
    }
};

/// Statistics across all episodes
pub const Stats = struct {
    total_episodes: usize,
    success_count: usize,
    failure_count: usize,
    total_iterations: u32,
    avg_iterations: f32,

    pub fn successRate(self: *const Stats) f32 {
        if (self.total_episodes == 0) return 0.0;
        return @as(f32, @floatFromInt(self.success_count)) /
            @as(f32, @floatFromInt(self.total_episodes));
    }
};

/// Create default experience store with sample episodes
pub fn createDefaultStore(allocator: Allocator) !ExperienceStore {
    var store = try ExperienceStore.init(allocator);

    // Add sample episodes for testing
    const now = std.time.timestamp();

    // Episode 1: Success with low effort
    var ep1 = Episode{
        .timestamp = now - 3600,
        .command = "tri test",
        .success = true,
        .iterations = 1,
        .learning_count = 1,
    };
    @memcpy(ep1.task, "Run test suite");
    ep1.task_len = 13;
    try store.addEpisode(ep1);

    // Episode 2: Success with high effort
    var ep2 = Episode{
        .timestamp = now - 1800,
        .command = "tri build",
        .success = true,
        .iterations = 50,
        .mistake_count = 2,
    };
    @memcpy(ep2.task, "Build project");
    ep2.task_len = 13;
    try store.addEpisode(ep2);

    // Episode 3: Failure with medium effort
    var ep3 = Episode{
        .timestamp = now - 900,
        .command = "tri deploy",
        .success = false,
        .iterations = 10,
        .mistake_count = 1,
    };
    @memcpy(ep3.task, "Deploy to production");
    ep3.task_len = 20;
    try store.addEpisode(ep3);

    return store;
}

pub fn runExperienceCommand(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    const store = try createDefaultStore(allocator);
    defer store.deinit();

    const stats = store.getStats();
    const avg_ratio = store.avgRewardEffortRatio(10);

    std.debug.print(
        \\Experience Stats:
        \\  Total Episodes: {d}
        \\  Success Rate: {d:.1}%
        \\  Avg Iterations: {d:.1}
        \\  Avg Reward/Effort: {d:.3}
        \\
    , .{
        stats.total_episodes,
        stats.successRate() * 100.0,
        stats.avg_iterations,
        avg_ratio,
    });
}

pub fn copyToFixed(dest: []u8, len_ptr: *usize, source: []const u8) void {
    const copy_len = @min(source.len, dest.len);
    @memcpy(dest[0..copy_len], source[0..copy_len]);
    len_ptr.* = copy_len;
}

pub fn keywordScore(content: []const u8, keywords: []const []const u8) f64 {
    _ = content;
    _ = keywords;
    return 0.0;
}

pub fn saveEpisode(episode: Episode) !void {
    _ = episode;
    // TODO: Implement saveEpisode (persist to .trinity/experience/)
    return error.NotImplemented;
}
