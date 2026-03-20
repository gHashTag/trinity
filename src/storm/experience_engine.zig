// @origin(spec:experience_engine.tri) @regen(manual-impl)
// MNL (Mistake Never Again) Pattern + Experience System
const std = @import("std");

const Allocator = std.mem.Allocator;

pub const ExperienceEngine = struct {
    allocator: Allocator,
    experience_dir: []const u8 = ".trinity/experience/",
    blacklist_file: []const u8 = ".trinity/mistakes/blacklist.json",
    similar_tasks_file: []const u8 = ".trinity/experience/similar_tasks.json",

    /// Task failure count for blacklist enforcement
    pub const FailureRecord = struct {
        task: []const u8,
        count: u3, // 0-7 failures tracked
        last_error: []const u8,
        timestamp: i64,
    };

    /// Similar task with success rate
    pub const SimilarTask = struct {
        task: []const u8,
        similarity: f32, // 0.0 - 1.0
        success_rate: f32, // 0.0 - 1.0
        attempts: u16,
    };

    /// Task context from consultation
    pub const TaskContext = struct {
        task: []const u8,
        similar_tasks: []SimilarTask,
        is_blacklisted: bool,
        recommendation: []const u8,
    };

    /// Create new experience engine
    pub fn init(allocator: Allocator) ExperienceEngine {
        return .{
            .allocator = allocator,
        };
    }

    /// Consult experience BEFORE action
    /// Returns similar tasks with outcomes
    pub fn consult(ee: *ExperienceEngine, task: []const u8) !TaskContext {
        _ = ee;
        _ = task;

        // TODO: Vector search in episodes/
        // TODO: Return top 3 similar with outcomes
        return TaskContext{
            .task = task,
            .similar_tasks = &[_]SimilarTask{},
            .is_blacklisted = false,
            .recommendation = "No similar tasks found",
        };
    }

    /// Check if task is blacklisted (3x failed)
    pub fn isBlacklisted(ee: *ExperienceEngine, task: []const u8) bool {
        _ = ee;
        _ = task;

        // TODO: Load blacklist.json
        // TODO: Check exact match + fuzzy match
        return false;
    }

    /// Record failure → blacklist after 3rd
    pub fn recordFailure(ee: *ExperienceEngine, task: []const u8, error_msg: []const u8) !void {
        _ = ee;
        _ = task;
        _ = error_msg;

        // TODO: Increment failure count
        // TODO: If count == 3, add to blacklist
    }

    /// Save episode with learnings
    pub fn saveEpisode(ee: *ExperienceEngine, episode: Episode) !void {
        _ = ee;
        _ = episode;

        // TODO: Append to .trinity/experience/episodes/
        // TODO: Update similar_tasks.json index
    }

    pub const Episode = struct {
        task: []const u8,
        success: bool,
        duration_ms: u64,
        error: ?[]const u8,
        learnings: ?[]const u8,
        timestamp: i64,
    };
};

// CLI wrapper for experience commands
pub fn runExperienceCommand(allocator: Allocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        std.debug.print("Usage: tri experience <subcommand>\n", .{});
        std.debug.print("Subcommands:\n", .{});
        std.debug.print("  consult <task>     Check similar past tasks\n", .{});
        std.debug.print("  blacklist          Show blacklisted tasks\n", .{});
        std.debug.print("  record <task>      Record failure\n", .{});
        return 1;
    }

    const subcommand = args[0];
    if (std.mem.eql(u8, subcommand, "consult")) {
        if (args.len < 2) {
            std.debug.print("Error: consult requires a task name\n", .{});
            return 1;
        }
        return cmdConsult(allocator, args[1]);
    } else if (std.mem.eql(u8, subcommand, "blacklist")) {
        return cmdBlacklist(allocator);
    } else if (std.mem.eql(u8, subcommand, "record")) {
        if (args.len < 2) {
            std.debug.print("Error: record requires a task name\n", .{});
            return 1;
        }
        return cmdRecord(allocator, args[1]);
    }

    std.debug.print("Unknown experience subcommand: {s}\n", .{subcommand});
    return 1;
}

fn cmdConsult(allocator: Allocator, task: []const u8) !u8 {
    _ = allocator;
    _ = task;

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";
    const GREEN = "\x1b[32m";

    std.debug.print("\n{s}🧠 EXPERIENCE CONSULT{s}\n", .{ CYAN, RESET });
    std.debug.print("  Task: {s}\n", .{task});
    std.debug.print("\n  {s}STATUS: P2 implementation in progress{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}TODO:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    • Vector search in .trinity/experience/\n", .{});
    std.debug.print("    • Return similar tasks with success rate\n", .{});
    std.debug.print("    • Check blacklist before action\n\n", .{});
    return 0;
}

fn cmdBlacklist(allocator: Allocator) !u8 {
    _ = allocator;

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";

    std.debug.print("\n{s}🧠 BLACKLIST STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  File: .trinity/mistakes/blacklist.json\n", .{});
    std.debug.print("\n  {s}STATUS: P2 implementation in progress{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}TODO:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    • Load and parse blacklist.json\n", .{});
    std.debug.print("    • Show tasks with 3+ failures\n", .{});
    std.debug.print("    • MNL: 3× failed = auto-skip\n\n", .{});
    return 0;
}

fn cmdRecord(allocator: Allocator, task: []const u8) !u8 {
    _ = allocator;
    _ = task;

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";

    std.debug.print("\n{s}🧠 RECORD FAILURE{s}\n", .{ CYAN, RESET });
    std.debug.print("  Task: {s}\n", .{task});
    std.debug.print("\n  {s}STATUS: P2 implementation in progress{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}TODO:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    • Increment failure count\n", .{});
    std.debug.print("    • If count == 3, add to blacklist\n", .{});
    std.debug.print("    • Persist to .trinity/mistakes/\n\n", .{});
    return 0;
}
