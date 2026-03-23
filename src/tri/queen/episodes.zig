// Queen Episodes — Episode Management & JSONL Persistence
const std = @import("std");

pub const Context = @import("observe.zig").Context;
pub const Plan = @import("plan.zig").Plan;
pub const Step = @import("plan.zig").Step;
pub const Result = @import("act.zig").Result;
pub const Outcome = @import("act.zig").Outcome;

pub const Source = enum {
    lotus_cycle,
    external,
    scheduled,
    experience_recall,
};

pub const Action = union(enum) {
    scale_up: struct {
        key: []const u8,
        quality_score: f64,
    },
    scale_down: struct {
        key: []const u8,
        quality_score: f64,
    },
    trigger: struct {
        key: []const u8,
    },
    set: struct {
        key: []const u8,
        value: union {
            bool: bool,
            f64: f64,
        },
    },
    wait: void,
};

pub const Episode = struct {
    id: u64,
    timestamp: u64,
    source: Source,
    context: Context,
    action: Action,
    result: Result,
    outcome: Outcome,
};

/// Simplified episode summary for JSONL persistence
/// (Full Episode struct has unions that Zig 0.15 JSON cannot serialize)
pub const EpisodeSummary = struct {
    id: u64,
    timestamp: u64,
    source: Source,
    action_type: []const u8,
    key: []const u8,
    outcome: Outcome,
    success: bool,
    duration_ms: u64,
};

pub fn recordEpisode(allocator: std.mem.Allocator, context: Context, plan: Plan, result: Result, outcome: Outcome) !Episode {
    _ = allocator;
    return Episode{
        .id = @as(u64, @intCast(std.time.nanoTimestamp())),
        .timestamp = @as(u64, @intCast(std.time.nanoTimestamp())),
        .source = .lotus_cycle,
        .context = context,
        .action = if (plan.action == .scale_up)
            Action{ .scale_up = .{ .key = plan.key, .quality_score = plan.quality_score } }
        else if (plan.action == .scale_down)
            Action{ .scale_down = .{ .key = plan.key, .quality_score = plan.quality_score } }
        else if (plan.action == .trigger)
            Action{ .trigger = .{ .key = plan.key } }
        else
            Action{ .wait = {} },
        .result = result,
        .outcome = outcome,
    };
}

pub fn appendEpisode(episode: Episode, allocator: std.mem.Allocator) !void {
    const episodes_dir = ".trinity/queen";
    std.fs.cwd().makePath(episodes_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const file_path = try std.fmt.allocPrint(allocator, "{s}/episodes.jsonl", .{episodes_dir});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    try file.seekFromEnd(0);

    // Create simplified summary for JSONL
    const action_name = @tagName(episode.action);
    const key = switch (episode.action) {
        .scale_up => |a| a.key,
        .scale_down => |a| a.key,
        .trigger => |a| a.key,
        .set => |a| a.key,
        .wait => "",
    };

    const summary = EpisodeSummary{
        .id = episode.id,
        .timestamp = episode.timestamp,
        .source = episode.source,
        .action_type = action_name,
        .key = key,
        .outcome = episode.outcome,
        .success = episode.result.success,
        .duration_ms = episode.result.timing.duration_ms,
    };

    const json = try std.json.Stringify.valueAlloc(allocator, summary, .{ .whitespace = .minified });
    defer allocator.free(json);

    const line = try std.fmt.allocPrint(allocator, "{s}\n", .{json});
    defer allocator.free(line);

    try file.writeAll(line);
}

pub fn loadEpisodes(allocator: std.mem.Allocator) ![]Episode {
    const file_path = ".trinity/queen/episodes.jsonl";

    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        return try allocator.alloc(Episode, 0);
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return try allocator.alloc(Episode, 0);
    };
    defer allocator.free(contents);

    var episodes = try std.ArrayList(Episode).initCapacity(allocator, 0);
    defer episodes.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, contents, '\n');

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        // Parse EpisodeSummary instead of full Episode
        const parsed = std.json.parseFromSlice(EpisodeSummary, allocator, line, .{}) catch {
            continue;
        };
        defer parsed.deinit();

        // Create minimal Episode from summary
        // Note: This loses context and result details - suitable for stats only
        const summary = parsed.value;
        const action: Action = if (std.mem.eql(u8, summary.action_type, "scale_up"))
            Action{ .scale_up = .{ .key = summary.key, .quality_score = 0.0 } }
        else if (std.mem.eql(u8, summary.action_type, "scale_down"))
            Action{ .scale_down = .{ .key = summary.key, .quality_score = 0.0 } }
        else if (std.mem.eql(u8, summary.action_type, "trigger"))
            Action{ .trigger = .{ .key = summary.key } }
        else
            Action{ .wait = {} };

        const ep = Episode{
            .id = summary.id,
            .timestamp = summary.timestamp,
            .source = summary.source,
            .context = undefined, // Not preserved in summary
            .action = action,
            .result = undefined, // Not preserved in summary
            .outcome = summary.outcome,
        };

        try episodes.append(allocator, ep);
    }

    return try episodes.toOwnedSlice(allocator);
}

pub fn getLastEpisode(allocator: std.mem.Allocator) !?Episode {
    const episodes = try loadEpisodes(allocator);
    defer allocator.free(episodes);

    if (episodes.len == 0) return null;
    return episodes[episodes.len - 1];
}

pub const EpisodeStats = struct {
    total: u32,
    by_source: [4]u32,
    by_outcome: [5]u32,
    last_24h: u32,
};

pub fn getEpisodeStats(allocator: std.mem.Allocator) !EpisodeStats {
    const episodes = try loadEpisodes(allocator);
    defer allocator.free(episodes);

    const now_ns = std.time.nanoTimestamp();
    const day_ns: u64 = 24 * 60 * 60 * 1_000_000_000;

    var stats = EpisodeStats{
        .total = @intCast(episodes.len),
        .by_source = [_]u32{0} ** 4,
        .by_outcome = [_]u32{0} ** 5,
        .last_24h = 0,
    };

    for (episodes) |ep| {
        const source_idx: u3 = @intFromEnum(ep.source);
        stats.by_source[source_idx] += 1;

        const outcome_idx: u3 = @intFromEnum(ep.outcome);
        stats.by_outcome[outcome_idx] += 1;

        if (now_ns - ep.timestamp < day_ns) {
            stats.last_24h += 1;
        }
    }

    return stats;
}

test "episodes: recordEpisode creates valid episode" {
    const allocator = std.testing.allocator;

    const context = Context{
        .timestamp_ns = 1234567890,
        .policy = .{},
        .senses = .{},
        .active_issues = try allocator.alloc(u64, 0),
    };
    defer allocator.free(context.active_issues);

    const plan = Plan{
        .action = .scale_up,
        .key = "kill_threshold",
        .quality_score = 0.7,
        .steps = &[_]Step{},
        .rollback = null,
    };

    const result = Result{
        .success = true,
        .@"error" = null,
        .timing = .{
            .start_ns = 1234567890,
            .end_ns = 1234567990,
            .duration_ms = 100,
        },
        .output = null,
        .new_senses = .{},
    };

    const episode = try recordEpisode(allocator, context, plan, result, .success);

    try std.testing.expect(episode.timestamp != 0);
    try std.testing.expect(episode.source == .lotus_cycle);
    try std.testing.expect(episode.context.timestamp_ns == 1234567890);
}
