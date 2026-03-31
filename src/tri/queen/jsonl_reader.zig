// JSONL Reader — Load agent episodes from .trinity/logs/agent-*.jsonl
// Converts EpisodeRequest format to Episode format for AutoImprove
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// Import episode types
const EpisodeRequest = @import("episode_handler.zig").EpisodeRequest;
const EpisodeType = @import("episode_handler.zig").EpisodeType;
const episodes = @import("episodes.zig");

const Allocator = std.mem.Allocator;
const logs_dir = ".trinity/logs";

pub const JsonlEpisodesConfig = struct {
    logs_dir: []const u8 = logs_dir,
    agent_filter: ?[]const u8 = null,
    type_filter: ?EpisodeType = null,
    max_count: usize = 100,
};

pub const AgentStats = struct {
    agent: []const u8,
    total_episodes: usize,
    success_episodes: usize,
    quality_score: f64,
};

/// Load all episodes from JSONL files, optionally filtered by agent/type
pub fn loadJsonlEpisodes(allocator: Allocator, config: JsonlEpisodesConfig) ![]episodes.Episode {
    var dir = std.fs.cwd().openDir(config.logs_dir, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            return try allocator.alloc(episodes.Episode, 0);
        }
        return err;
    };
    defer dir.close();

    var all_episodes = try std.ArrayList(episodes.Episode).initCapacity(allocator, 0);
    defer {
        for (all_episodes.items) |ep| {
            if (ep.context.active_issues.len > 0)
                allocator.free(ep.context.active_issues);
        }
        all_episodes.deinit(allocator);
    }

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        // Skip directories and non-.jsonl files
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".jsonl")) continue;

        // Extract agent name from filename: agent-{name}.jsonl
        const agent_name = extractAgentName(entry.basename) orelse continue;

        // Apply agent filter if specified
        if (config.agent_filter) |filter| {
            if (!std.mem.eql(u8, agent_name, filter)) continue;
        }

        // Read and parse JSONL file
        const file_episodes = try loadJsonlFile(allocator, dir, entry.basename, agent_name, config);
        defer allocator.free(file_episodes);

        // Add to all episodes
        for (file_episodes) |ep| {
            try all_episodes.append(allocator, ep);
        }

        // Stop if we've reached max_count
        if (all_episodes.items.len >= config.max_count) break;
    }

    return try all_episodes.toOwnedSlice(allocator);
}

/// Load episodes from a single JSONL file
fn loadJsonlFile(
    allocator: Allocator,
    dir: std.fs.Dir,
    filename: []const u8,
    agent_name: []const u8,
    config: JsonlEpisodesConfig,
) ![]episodes.Episode {
    const file = dir.openFile(filename, .{}) catch {
        return try allocator.alloc(episodes.Episode, 0);
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return try allocator.alloc(episodes.Episode, 0);
    };
    defer allocator.free(contents);

    var episodes_list = try std.ArrayList(episodes.Episode).initCapacity(allocator, 0);
    defer {
        for (episodes_list.items) |ep| {
            if (ep.context.active_issues.len > 0)
                allocator.free(ep.context.active_issues);
        }
        episodes_list.deinit(allocator);
    }

    var line_iter = std.mem.splitScalar(u8, contents, '\n');

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        // Parse EpisodeRequest from JSON
        const parsed = std.json.parseFromSlice(EpisodeRequest, allocator, line, .{
            .ignore_unknown_fields = true,
        }) catch {
            // Skip malformed lines
            continue;
        };
        defer parsed.deinit();

        const req = parsed.value;

        // Apply type filter if specified
        if (config.type_filter) |filter| {
            if (req.episode_type != filter) continue;
        }

        // Convert EpisodeRequest to Episode
        const ep = try convertToEpisode(allocator, req, agent_name);
        try episodes_list.append(allocator, ep);
    }

    return try episodes_list.toOwnedSlice(allocator);
}

/// Convert EpisodeRequest to Episode
fn convertToEpisode(allocator: Allocator, req: EpisodeRequest, agent_name: []const u8) !episodes.Episode {
    // Parse episode_id as timestamp (or use current time if not numeric)
    const timestamp = std.fmt.parseInt(i64, req.episode_id, 10) catch std.time.timestamp();

    // Map EpisodeType to Source
    const source: episodes.Source = switch (req.episode_type) {
        .task => .external,
        .observation => .experience_recall,
        .action => .lotus_cycle,
        .@"error" => .tri27,
    };

    // Create minimal context
    const context = episodes.Context{
        .timestamp_ns = @as(u64, @intCast(@abs(timestamp))) * 1_000_000,
        .policy = .{},
        .senses = .{},
        .active_issues = try allocator.alloc(u64, 0),
        .recalled_episodes = &[_]episodes.Episode{},
    };

    // Map to Action (simplified - most episodes become .wait or .set)
    const action: episodes.Action = .{
        .set = .{
            .key = try std.fmt.allocPrint(allocator, "{s}_task", .{agent_name}),
            .value = .{ .f64 = 1.0 },
        },
    };

    // Determine success based on episode_type
    // task = pending (unknown), observation = true, action = success depends, error = false
    const success: bool = switch (req.episode_type) {
        .task => true, // Tasks are potential, not failures
        .observation => true,
        .action => true,
        .@"error" => false,
    };

    // Map episode_type to outcome
    const outcome: episodes.Outcome = switch (req.episode_type) {
        .task => .partial, // Task started, not completed
        .observation => .success,
        .action => .success,
        .@"error" => .failure_learned,
    };

    const timestamp_u64: u64 = @intCast(timestamp);

    const result = episodes.Result{
        .success = success,
        .@"error" = null,
        .timing = .{
            .start_ns = timestamp_u64 * 1_000_000,
            .end_ns = timestamp_u64 * 1_000_000,
            .duration_ms = 0,
        },
        .output = null,
        .new_senses = .{},
    };

    return episodes.Episode{
        .id = timestamp_u64,
        .timestamp = timestamp_u64,
        .source = source,
        .context = context,
        .action = action,
        .result = result,
        .outcome = outcome,
    };
}

/// Extract agent name from filename: agent-{name}.jsonl -> {name}
fn extractAgentName(filename: []const u8) ?[]const u8 {
    const prefix = "agent-";
    const suffix = ".jsonl";

    if (!std.mem.startsWith(u8, filename, prefix)) return null;
    if (!std.mem.endsWith(u8, filename, suffix)) return null;

    const name_start = prefix.len;
    const name_end = filename.len - suffix.len;

    if (name_end <= name_start) return null;

    return filename[name_start..name_end];
}

/// Get statistics for all agents from JSONL files
pub fn getAgentStats(allocator: Allocator) ![]AgentStats {
    var dir = std.fs.cwd().openDir(logs_dir, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            return try allocator.alloc(AgentStats, 0);
        }
        return err;
    };
    defer dir.close();

    var stats_map = std.StringHashMap(AgentStatsData).init(allocator);
    defer {
        var iter = stats_map.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        stats_map.deinit();
    }

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".jsonl")) continue;

        const agent_name = extractAgentName(entry.basename) orelse continue;

        // Count episodes in this file
        const file = dir.openFile(entry.basename, .{}) catch continue;
        defer file.close();

        const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch continue;
        defer allocator.free(contents);

        var total: usize = 0;
        var success: usize = 0;

        var line_iter = std.mem.splitScalar(u8, contents, '\n');
        while (line_iter.next()) |line| {
            if (line.len == 0) continue;

            const parsed = std.json.parseFromSlice(EpisodeRequest, allocator, line, .{
                .ignore_unknown_fields = true,
            }) catch continue;
            defer parsed.deinit();

            total += 1;
            if (parsed.value.episode_type != .@"error") {
                success += 1;
            }
        }

        // Store stats for this agent
        const gop = try stats_map.getOrPut(allocator, agent_name);
        if (!gop.found_existing) {
            gop.key_ptr.* = try allocator.dupe(u8, agent_name);
            gop.value_ptr.* = .{
                .total_episodes = 0,
                .success_episodes = 0,
            };
        }
        gop.value_ptr.total_episodes += total;
        gop.value_ptr.success_episodes += success;
    }

    // Convert map to slice
    var result = try std.ArrayList(AgentStats).initCapacity(allocator, stats_map.count());
    var iter = stats_map.iterator();
    while (iter.next()) |entry| {
        const data = entry.value_ptr.*;
        const quality_score = if (data.total_episodes > 0)
            @as(f64, @floatFromInt(data.success_episodes)) / @as(f64, @floatFromInt(data.total_episodes))
        else
            0.0;

        try result.append(allocator, .{
            .agent = try allocator.dupe(u8, entry.key_ptr.*),
            .total_episodes = data.total_episodes,
            .success_episodes = data.success_episodes,
            .quality_score = quality_score,
        });
    }

    return try result.toOwnedSlice(allocator);
}

const AgentStatsData = struct {
    total_episodes: usize = 0,
    success_episodes: usize = 0,
};

/// Find agents below quality threshold
pub fn findUnderperformingAgents(
    allocator: Allocator,
    threshold: f64,
) ![]AgentStats {
    const all_stats = try getAgentStats(allocator);
    defer {
        for (all_stats) |stat| {
            allocator.free(stat.agent);
        }
        allocator.free(all_stats);
    }

    var underperformers = try std.ArrayList(AgentStats).initCapacity(allocator, 0);

    for (all_stats) |stat| {
        if (stat.quality_score < threshold) {
            try underperformers.append(allocator, .{
                .agent = try allocator.dupe(u8, stat.agent),
                .total_episodes = stat.total_episodes,
                .success_episodes = stat.success_episodes,
                .quality_score = stat.quality_score,
            });
        }
    }

    return try underperformers.toOwnedSlice(allocator);
}

// ============================================================================
// TESTS
// ============================================================================

test "jsonl_reader: extractAgentName" {
    try std.testing.expectEqualStrings("gamma", extractAgentName("agent-gamma.jsonl").?);
    try std.testing.expectEqualStrings("alpha", extractAgentName("agent-alpha.jsonl").?);
    try std.testing.expectEqualStrings("test-agent-123", extractAgentName("agent-test-agent-123.jsonl").?);
    try std.testing.expect(extractAgentName("other.jsonl") == null);
    try std.testing.expect(extractAgentName("agent-test.txt") == null);
}

test "jsonl_reader: loadJsonlEpisodes with missing directory" {
    const allocator = std.testing.allocator;
    const config = JsonlEpisodesConfig{
        .logs_dir = "/nonexistent/path",
        .agent_filter = null,
        .type_filter = null,
        .max_count = 100,
    };

    const result_episodes = try loadJsonlEpisodes(allocator, config);
    defer allocator.free(result_episodes);

    try std.testing.expectEqual(@as(usize, 0), result_episodes.len);
}
