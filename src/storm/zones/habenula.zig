//! HABENULA - Anti-Corruption Sensor
//! Detects unfair reward/effort ratios via experience episodes

const std = @import("std");

pub const EpisodeSummary = struct {
    task: []const u8,
    avg_reward: f64,
    total_effort: f64,
    episode_count: usize,
};

pub const FairnessResult = struct {
    is_suspicious: bool,
    ratio: f64,
    median_reward: f64,
    reason: []const u8,
};

pub const HABENULA = struct {
    allocator: std.mem.Allocator,
    experience_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator) !HABENULA {
        const experience_dir = try allocator.dupe(u8, ".trinity/experience/episodes");
        errdefer allocator.free(experience_dir);

        return .{
            .allocator = allocator,
            .experience_dir = experience_dir,
        };
    }

    pub fn deinit(self: *HABENULA) void {
        self.allocator.free(self.experience_dir);
    }

    /// Detect unfair reward/effort ratio for a task
    pub fn detectUnfair(self: *HABENULA, task: []const u8) !FairnessResult {
        const log = std.log.scoped("habenula");
        log.info("🔍 HABENULA: Checking fairness for task '{s}'", .{task});

        // Find all episodes for this task
        var episodes = std.ArrayList(EpisodeSummary).init(self.allocator);
        defer episodes.deinit();

        var dir = std.fs.cwd().openIterableDir(.{
            .sub_path = self.experience_dir,
        }) catch |err| {
            return .{
                .is_suspicious = false,
                .ratio = 1.0,
                .median_reward = 0.0,
                .reason = try std.fmt.allocPrint(self.allocator, "No experience episodes found: {}", .{err}),
            };
        };
        defer dir.close();

        // Collect episode statistics
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            const filename = entry.name;
            if (!std.mem.startsWith(u8, filename, task)) continue;

            const content = self.readFile(filename) catch |err| {
                log.warn("Failed to read episode file: {}", .{err});
                continue;
            };

            // Parse episode JSON
            const parsed = std.json.parseFromSlice(
                EpisodeData,
                self.allocator,
                content,
                .{ .ignore_unknown_fields = true },
            ) catch |err| {
                log.warn("Failed to parse episode JSON: {}", .{err});
                continue;
            };
            defer parsed.deinit();

            // Accumulate statistics
            if (parsed.value.reward) |r| {
                if (parsed.value.effort) |e| {
                    try episodes.append(.{
                        .task = try self.allocator.dupe(u8, task),
                        .avg_reward = @floatCast(r.avg_reward),
                        .total_effort = e.total_effort,
                        .episode_count = r.episode_count,
                    });
                }
            }
        }

        if (episodes.items.len < 3) {
            return .{
                .is_suspicious = false,
                .ratio = 1.0,
                .median_reward = 0.0,
                .reason = try std.fmt.allocPrint(self.allocator, "Insufficient data ({d} episodes) - requires minimum 3", .{episodes.items.len}),
            };
        }

        // Calculate median reward
        var rewards = std.ArrayList(f64).init(self.allocator);
        defer rewards.deinit();

        for (episodes.items) |ep| {
            try rewards.append(ep.avg_reward);
        }

        std.sort.sort(f64, rewards.items, {}, struct {
            pub fn lessThan(_: void, a: f64, b: f64) bool {
                return a < b;
            }
        });

        const median_reward = if (rewards.items.len > 0)
            rewards.items[rewards.items.len / 2]
        else
            0.0;

        // Calculate effort-weighted average reward
        var total_weighted_reward: f64 = 0.0;
        var total_weight: f64 = 0.0;

        for (episodes.items) |ep| {
            const weight = ep.total_effort;
            total_weighted_reward += ep.avg_reward * weight;
            total_weight += weight;
        }

        const weighted_avg_reward = if (total_weight > 0.0)
            total_weighted_reward / total_weight
        else
            0.0;

        // Calculate ratio
        const ratio = if (weighted_avg_reward > 0.0)
            median_reward / weighted_avg_reward
        else
            1.0;

        log.info("Median reward: {d:.2}, Weighted avg: {d:.2}, Ratio: {d:.2}", .{ median_reward, weighted_avg_reward, ratio });

        // Determine suspiciousness
        const is_suspicious = ratio > 2.0;

        var reason = try std.fmt.allocPrint(self.allocator, "Reward/Effort ratio: {d:.2}x (median: {d:.2})", .{ ratio, median_reward });

        if (is_suspicious) {
            reason = try std.fmt.allocPrint(self.allocator, "{s} - SUSPICIOUS (2× threshold exceeded)", .{reason});
        } else {
            reason = try std.fmt.allocPrint(self.allocator, "{s} - within normal range", .{reason});
        }

        return .{
            .is_suspicious = is_suspicious,
            .ratio = ratio,
            .median_reward = median_reward,
            .reason = reason,
        };
    }

    fn readFile(self: *HABENULA, filename: []const u8) ![]const u8 {
        const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.experience_dir, filename });
        const file = try std.fs.cwd().openFile(full_path, .{});
        defer file.close();

        return file.readToEndAlloc(self.allocator, 1024 * 1024);
    }
};

const EpisodeData = struct {
    reward: ?struct {
        avg_reward: f64,
        episode_count: usize,
    },
    effort: ?struct {
        total_effort: f64,
    },
};
