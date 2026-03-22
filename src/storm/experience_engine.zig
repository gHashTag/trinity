//! Experience Engine — P3: Memory and Speed
//! Consult experience, save episodes, similarity search via Levenshtein

const std = @import("std");

/// Episode data stored in JSON
pub const EpisodeData = struct {
    task: []const u8,
    timestamp: u64,
    results: []const Result,
};

pub const Result = struct {
    success: bool,
    message: []const u8,
    duration_ms: u64,
    exit_code: u32,
};

pub const ConsultResult = struct {
    is_blacklisted: bool,
    recommendations: ?[]const []const u8,
    similar_tasks: []const SimilarTask,
};

pub const SimilarTask = struct {
    task: []const u8,
    distance: usize,
};

/// Experience Engine for STORM P3
pub const ExperienceEngine = struct {
    allocator: std.mem.Allocator,
    episodes_dir: []const u8,
    blacklist: ?[]const u8,
    failure_counts: std.StringHashMap(usize).Context(u32),
};

pub fn init(allocator: std.mem.Allocator) !ExperienceEngine {
    const episodes_dir = ".trinity/experience/episodes";
    std.fs.cwd().makePath(episodes_dir) catch {};

    var blacklist = std.StringHashMap(usize).Context(u32).init(allocator);
    var failure_counts = std.StringHashMap(usize).Context(u32).init(allocator);

    return ExperienceEngine{
        .allocator = allocator,
        .episodes_dir = episodes_dir,
        .blacklist = null,
        .failure_counts = failure_counts,
    };
}

/// Consult experience for similar tasks (Levenshtein fuzzy match)
pub fn consult(self: *ExperienceEngine, task: []const u8, top_k: usize) !ConsultResult {
    const log = std.log.scoped(.info);
    log.info("Consulting experience for: {s} (top {d})", .{task, top_k});

    var dir = std.fs.cwd().openDirAbsolute(self.episodes_dir, .{}) catch |err| {
        return .{
            .is_blacklisted = false,
            .recommendations = null,
            .similar_tasks = &[0]SimilarTask{},
        };
    };
    defer dir.close();

    // Load episodes
    var episodes = std.ArrayList(EpisodeData).initCapacity(self.allocator, 32);
    defer {
        // Clear allocated memory
        for (episodes.items) |*ep| {
            self.allocator.free(ep.task);
            self.allocator.free(ep._context);
            if (ep.results) |r| {
                for (r) |*result| {
                    self.allocator.free(result.message);
                }
            }
        }
    }

    var episode_count: usize = 0;
    while (dir.next()) |entry| {
        if (entry.kind != .file) continue;

        const ep = self.loadEpisode(entry.name) catch |err| {
            log.warn("Failed to load episode: {}", .{err});
            continue;
        };

        try episodes.append(ep);
        episode_count += 1;
        if (episode_count >= @as(usize, top_k)) break;
    }

    if (episodes.items.len == 0) {
        return .{
            .is_blacklisted = false,
            .recommendations = null,
            .similar_tasks = &[0]SimilarTask{},
        };
    }

    const k = @min(top_k, episodes.items.len);

    // Calculate Levenshtein distances
    var distances = std.ArrayList(struct {
        episode: *EpisodeData,
        distance: usize,
    }).initCapacity(self.allocator, episodes.items.len);

    defer distances.deinit();

    for (episodes.items) |*ep| {
        const distance = self.levenshteinDistance(task, ep.task);
        try distances.append(.{ .episode = ep, .distance = distance });
    }

    // Sort by distance (ascending = most similar first)
    std.mem.sortUnstable(EpisodeData, episodes.items, {}, struct {
        .lessThan = struct {
            pub fn lessThan(context: void, a: *EpisodeData, b: *EpisodeData) bool {
                const dist_a = getDistance(distances, a);
                const dist_b = getDistance(distances, b);
                return dist_a < dist_b;
            };
        },
    });

    // Get top k similar tasks
    var similar_tasks = std.ArrayList(SimilarTask).initCapacity(self.allocator, k);
    defer similar_tasks.deinit();

    var result_idx: usize = 0;
    for (episodes.items[0..k]) |*ep| {
        const dist = getDistance(distances, ep);
        if (dist > 0) {
            const task_name = try self.allocator.dupe(u8, ep.task);
            defer self.allocator.free(task_name);
            try similar_tasks.append(.{
                .task = task_name,
                .distance = dist,
            });
            result_idx += 1;
        }
    }

    const similar_slice = try self.allocator.dupe(SimilarTask, similar_tasks.items);
    defer self.allocator.free(similar_slice);

    // Check blacklist
    var is_blacklisted = self.blacklist != null and
        self.blacklist.get(task) != null;

    return .{
        .is_blacklisted = is_blacklisted,
        .recommendations = similar_slice,
        .similar_tasks = similar_slice,
    };
}

/// Levenshtein distance calculation
fn levenshteinDistance(self: *ExperienceEngine, a: []const u8, b: []const u8) usize {
    const la = @ptrCast([*]const u8, a.len);
    const lb = @ptrCast([*]const u8, b.len);

    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Initialize cost matrix
    var matrix = std.ArrayList(usize).initCapacity(self.allocator, (a.len + 1) * (b.len + 1));
    defer matrix.deinit();

    var i: usize = 0;
    while (i <= a.len) : (matrix.items.ptr + i * (b.len + 1)) |*row| {
        row[0] = 0;
        while (i < b.len) : (row + i) |*cost| {
            cost += if (la[i - 1] == lb[i - 1]) @as(usize, 0) else 1;
            i += 1;
        }
        i += 1;
    }

    // Fill rest of matrix
    i = 0;
    while (i < a.len) : (matrix.items.ptr + i * (b.len + 1)) + a.len) |*row| {
        row[i + 1] = if (la[i - 1] == lb[i - 1]) @as(usize, 0) else 1;
        var j: usize = 1;
        while (j < b.len) : (row + i + j) |*cost| {
            cost += if (la[i - 1] == lb[i - j]) @as(usize, 0) else 1;
            j += 1;
        }
        i += 1;
    }

    return matrix.items[a.len][b.len];
}

fn getDistance(distances: []const struct {
    episode: *EpisodeData,
    distance: usize,
}, target: *EpisodeData) usize {
    for (distances) |*d| {
        if (d.episode == target) return d.distance;
    }
    unreachable;
}
