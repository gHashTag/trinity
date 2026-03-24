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
    tri27,
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
    tri27_op: struct {
        operation: Tri27Operation,
        input_file: []const u8,
        output_file: []const u8,
        cycles: u32,
        instructions: u32,
    },
};

pub const Tri27Operation = enum(u8) {
    assemble,
    disassemble,
    run,
    @"test",
    validate,
    flash,
    dump,
};

pub const Tri27Status = enum(u8) {
    queued,
    running,
    success,
    failed,
    timeout,
    cancelled,
};

pub const Tri27Event = struct {
    timestamp: i64,
    operation: Tri27Operation,
    input_file: []const u8,
    output_file: []const u8,
    status: Tri27Status,
    cycles: u32,
    instructions: u32,
    error_msg: []const u8,
    has_error: bool,

    pub fn inputFile(self: Tri27Event) []const u8 {
        return self.input_file;
    }

    pub fn outputFile(self: Tri27Event) []const u8 {
        return self.output_file;
    }

    pub fn errorMsg(self: Tri27Event) []const u8 {
        if (!self.has_error) return "";
        return self.error_msg;
    }
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
    /// For TRI-27 operations: input file path
    input_file: []const u8 = "",
    /// For TRI-27 operations: operation type
    tri27_operation: []const u8 = "",
};

/// Parse TRI-27 operation string to enum
fn parseTri27Operation(str: []const u8) Tri27Operation {
    if (std.mem.eql(u8, str, "assemble")) return .assemble;
    if (std.mem.eql(u8, str, "disassemble")) return .disassemble;
    if (std.mem.eql(u8, str, "run")) return .run;
    if (std.mem.eql(u8, str, "test")) return .@"test";
    if (std.mem.eql(u8, str, "validate")) return .validate;
    if (std.mem.eql(u8, str, "flash")) return .flash;
    if (std.mem.eql(u8, str, "dump")) return .dump;
    return .assemble; // Default
}

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

/// Record TRI-27 operation as Episode
pub fn recordTri27Episode(allocator: std.mem.Allocator, tri27_event: Tri27Event) !EpisodeSummary {
    const now_ns = std.time.nanoTimestamp();

    // Create minimal context
    const context = Context{
        .timestamp_ns = now_ns,
        .policy = .{},
        .senses = .{},
        .active_issues = &[_]u64{},
        .recalled_episodes = &[_]Episode{},
    };

    // Map Tri27Status to Outcome
    const outcome: Outcome = switch (tri27_event.status) {
        .success => .success,
        .failed => if (tri27_event.has_error) .failure_learned else .failure_unknown,
        .timeout => .blocked,
        .cancelled => .blocked,
        .queued, .running => .partial,
    };

    // Create result
    const result = Result{
        .success = tri27_event.status == .success,
        .@"error" = if (tri27_event.has_error)
            try allocator.dupe(u8, tri27_event.errorMsg())
        else
            null,
        .timing = .{
            .start_ns = now_ns,
            .end_ns = now_ns + tri27_event.cycles * 1000,
            .duration_ms = tri27_event.cycles / 1000,
        },
        .output = if (tri27_event.status == .success)
            try allocator.dupe(u8, tri27_event.outputFile())
        else
            null,
        .new_senses = .{},
    };

    // Create Episode with tri27_op action
    const episode = Episode{
        .id = @as(u64, @intCast(now_ns)),
        .timestamp = @as(u64, @intCast(now_ns)),
        .source = .tri27,
        .context = context,
        .action = .{
            .tri27_op = .{
                .operation = tri27_event.operation,
                .input_file = try allocator.dupe(u8, tri27_event.inputFile()),
                .output_file = try allocator.dupe(u8, tri27_event.outputFile()),
                .cycles = tri27_event.cycles,
                .instructions = tri27_event.instructions,
            },
        },
        .result = result,
        .outcome = outcome,
    };

    // Convert to EpisodeSummary for JSONL persistence
    const summary = EpisodeSummary{
        .id = episode.id,
        .timestamp = episode.timestamp,
        .source = episode.source,
        .action_type = "tri27_op",
        .key = tri27_event.inputFile(),
        .outcome = episode.outcome,
        .success = episode.result.success,
        .duration_ms = episode.result.timing.duration_ms,
        .input_file = tri27_event.inputFile(),
        .tri27_operation = @tagName(tri27_event.operation),
    };

    _ = try appendEpisode(episode, allocator);

    return summary;
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
    var input_file: []const u8 = "";
    var tri27_operation: []const u8 = "";
    const key = switch (episode.action) {
        .scale_up => |a| a.key,
        .scale_down => |a| a.key,
        .trigger => |a| a.key,
        .set => |a| a.key,
        .wait => "",
        .tri27_op => |t| blk: {
            input_file = t.input_file;
            tri27_operation = @tagName(t.operation);
            break :blk t.input_file;
        },
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
        .input_file = input_file,
        .tri27_operation = tri27_operation,
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
        else if (std.mem.eql(u8, summary.action_type, "tri27_op"))
            Action{
                .tri27_op = .{
                    .operation = parseTri27Operation(summary.tri27_operation),
                    .input_file = summary.input_file,
                    .output_file = "",
                    .cycles = 0,
                    .instructions = 0,
                },
            }
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
    by_source: [5]u32, // Updated to include tri27
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
        .by_source = [_]u32{0} ** 5,
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
        .recalled_episodes = &[_]Episode{},
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

test "episodes: parseTri27Operation" {
    try std.testing.expectEqual(Tri27Operation.assemble, parseTri27Operation("assemble"));
    try std.testing.expectEqual(Tri27Operation.disassemble, parseTri27Operation("disassemble"));
    try std.testing.expectEqual(Tri27Operation.run, parseTri27Operation("run"));
    try std.testing.expectEqual(Tri27Operation.@"test", parseTri27Operation("test"));
    try std.testing.expectEqual(Tri27Operation.validate, parseTri27Operation("validate"));
    try std.testing.expectEqual(Tri27Operation.flash, parseTri27Operation("flash"));
    try std.testing.expectEqual(Tri27Operation.dump, parseTri27Operation("dump"));
    try std.testing.expectEqual(Tri27Operation.assemble, parseTri27Operation("unknown")); // Default
}
