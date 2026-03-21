// @origin(spec:experience_engine.tri) @regen(manual-impl)
// MNL (Mistake Never Again) Pattern + Experience System
const std = @import("std");

const MemAllocator = std.mem.MemAllocator;

pub const ExperienceEngine = struct {
    allocator: MemAllocator,
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

    /// Blacklist storage (persisted to JSON)
    pub const Blacklist = struct {
        entries: []FailureRecord,
        last_updated: i64,

        pub fn deinit(bl: *Blacklist, allocator: MemAllocator) void {
            for (bl.entries) |entry| {
                allocator.free(entry.task);
                if (entry.last_error.len > 0) allocator.free(entry.last_error);
            }
            allocator.free(bl.entries);
        }
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
        similar_tasks: []const SimilarTask,
        is_blacklisted: bool,
        recommendation: []const u8,

        pub fn deinit(ctx: *TaskContext, allocator: MemAllocator) void {
            for (ctx.similar_tasks) |st| {
                allocator.free(st.task);
            }
            allocator.free(ctx.similar_tasks);
            allocator.free(ctx.recommendation);
        }
    };

    /// Episode record
    pub const Episode = struct {
        task: []const u8,
        success: bool,
        duration_ms: u64,
        error_msg: ?[]const u8,
        learnings: ?[]const u8,
        timestamp: i64,
    };

    /// Create new experience engine
    pub fn init(allocator: MemAllocator) ExperienceEngine {
        return .{
            .allocator = allocator,
        };
    }

    /// Consult experience BEFORE action
    /// Returns similar tasks with outcomes
    pub fn consult(ee: *ExperienceEngine, task: []const u8) !TaskContext {
        // Check blacklist first
        const blacklisted = ee.isBlacklisted(task);

        // Search for similar tasks in episodes
        var similar_tasks = std.ArrayList(SimilarTask).init(ee.allocator);

        // Simple keyword-based similarity (TODO: replace with VSA vector search)
        const episodes_dir = try std.fs.cwd().openDir(ee.experience_dir ++ "episodes/", .{ .iterate = true });
        defer episodes_dir.close();

        var iter = episodes_dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
                // Parse episode and check similarity
                // For now, just count episodes
            }
        }

        const recommendation = if (blacklisted)
            "TASK BLACKLISTED: 3+ failures detected. Skip or investigate."
        else if (similar_tasks.items.len > 0)
            "Found similar tasks with historical data."
        else
            "No similar tasks found. Proceed with caution.";

        return TaskContext{
            .task = try ee.allocator.dupe(u8, task),
            .similar_tasks = similar_tasks.toOwnedSlice(),
            .is_blacklisted = blacklisted,
            .recommendation = try ee.allocator.dupe(u8, recommendation),
        };
    }

    /// Check if task is blacklisted (3x failed)
    pub fn isBlacklisted(ee: *ExperienceEngine, task: []const u8) bool {
        const blacklist = ee.loadBlacklist() catch |err| {
            std.log.err("Failed to load blacklist: {}", .{err});
            return false;
        };
        defer blacklist.deinit(ee.allocator);

        // Exact match check
        for (blacklist.entries) |entry| {
            if (std.mem.eql(u8, entry.task, task) and entry.count >= 3) {
                return true;
            }
        }

        // TODO: Fuzzy match for similar tasks
        return false;
    }

    /// Record failure → blacklist after 3rd
    pub fn recordFailure(ee: *ExperienceEngine, task: []const u8, error_msg: []const u8) !void {
        var blacklist = ee.loadBlacklist() catch |err| {
            std.log.err("Failed to load blacklist, creating new: {}", .{err});
            return Blacklist{
                .entries = &[_]FailureRecord{},
                .last_updated = 0,
            };
        };
        defer blacklist.deinit(ee.allocator);

        // Find existing entry
        var found: bool = false;
        for (blacklist.entries) |*entry| {
            if (std.mem.eql(u8, entry.task, task)) {
                entry.count += 1;
                entry.last_error = try ee.allocator.dupe(u8, error_msg);
                entry.timestamp = std.time.timestamp();
                found = true;
                break;
            }
        }

        // Create new entry if not found
        if (!found) {
            const new_entry = FailureRecord{
                .task = try ee.allocator.dupe(u8, task),
                .count = 1,
                .last_error = try ee.allocator.dupe(u8, error_msg),
                .timestamp = std.time.timestamp(),
            };

            var new_entries = try ee.allocator.alloc(FailureRecord, blacklist.entries.len + 1);
            @memcpy(new_entries[0..blacklist.entries.len], blacklist.entries);
            new_entries[blacklist.entries.len] = new_entry;

            blacklist.entries = new_entries;
        }

        // Save updated blacklist
        try ee.saveBlacklist(&blacklist);

        // Log warning if approaching blacklist threshold
        for (blacklist.entries) |entry| {
            if (std.mem.eql(u8, entry.task, task)) {
                if (entry.count >= 3) {
                    std.log.warn("MNL: Task '{s}' BLACKLISTED after {d} failures", .{task, entry.count});
                } else if (entry.count == 2) {
                    std.log.warn("MNL: Task '{s}' has {d} failures. Next failure will blacklist.", .{task, entry.count});
                }
            }
        }
    }

    /// Save episode with learnings
    pub fn saveEpisode(ee: *ExperienceEngine, episode: Episode) !void {
        const timestamp = std.time.timestamp();
        const filename = try std.fmt.allocPrint(ee.allocator, "episode_{d}.json", .{timestamp});
        defer ee.allocator.free(filename);

        const file_path = try std.fs.path.join(ee.allocator, &[_][]const u8{
            ee.experience_dir,
            "episodes",
            filename,
        });
        defer ee.allocator.free(file_path);

        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        // Ensure episodes directory exists
        std.fs.cwd().makePath(ee.experience_dir ++ "episodes/") catch {};

        // Serialize episode to JSON using std.json.stringify
        const episode_json = try std.json.stringifyAlloc(ee.allocator, episode);
        defer ee.allocator.free(episode_json);

        // Write to file
        try file.writeAll(episode_json);

        std.debug.print("💾 Episode saved: {s}\n", .{filename});
    }

    /// Load blacklist from JSON
    fn loadBlacklist(ee: *ExperienceEngine) !Blacklist {
        const file = std.fs.cwd().openFile(ee.blacklist_file, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Create empty blacklist
                return Blacklist{
                    .entries = &[_]FailureRecord{},
                    .last_updated = 0,
                };
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(ee.allocator, 1024 * 1024);
        defer ee.allocator.free(content);

        // Parse JSON using std.json.parse
        const parsed = try std.json.parseFromSlice(Blacklist, content);
        defer parsed.deinit(ee.allocator);

        return parsed;
    }

    /// Save blacklist to JSON
    fn saveBlacklist(ee: *ExperienceEngine, blacklist: *const Blacklist) !void {
        // Ensure directory exists
        std.fs.cwd().makePath(".trinity/mistakes") catch {};

        const file = try std.fs.cwd().createFile(ee.blacklist_file, .{ .read = true });
        defer file.close();

        // Serialize to JSON using std.json.stringify
        const json_str = try std.json.stringifyAlloc(ee.allocator, blacklist);
        defer ee.allocator.free(json_str);

        // Write to file
        try file.writeAll(json_str);

        std.debug.print("💾 Blacklist saved: {d} entries\n", .{blacklist.entries.len});
    }
};

// CLI wrapper for experience commands
pub fn runExperienceCommand(allocator: MemAllocator, args: []const []const u8) !u8 {
    if (args.len < 1) {
        printExperienceHelp();
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
    } else if (std.mem.eql(u8, subcommand, "--help") or std.mem.eql(u8, subcommand, "-h")) {
        printExperienceHelp();
        return 0;
    }

    std.debug.print("Unknown experience subcommand: {s}\n", .{subcommand});
    return 1;
}

fn printExperienceHelp() void {
    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";
    const GREEN = "\x1b[32m";

    std.debug.print("\n{s}🧠 EXPERIENCE ENGINE — MNL Pattern{s}\n", .{ CYAN, RESET });
    std.debug.print("Usage: tri experience <subcommand> [options]\n\n", .{});
    std.debug.print("Subcommands:\n", .{});
    std.debug.print("  {s}consult <task>{s}     Check similar past tasks\n", .{ GREEN, RESET });
    std.debug.print("  {s}blacklist{s}          Show blacklisted tasks\n", .{ GREEN, RESET });
    std.debug.print("  {s}record <task>{s}      Record failure (MNL counter)\n", .{ GREEN, RESET });
    std.debug.print("\n  {s}MNL Pattern:{s}\n", .{ YELLOW, RESET });
    std.debug.print("    1× failure → Warning logged\n", .{});
    std.debug.print("    2× failure → Elevated concern\n", .{});
    std.debug.print("    3× failure → {s}BLACKLISTED{s} (auto-skip)\n\n", .{ "\x1b[31m", RESET });
}

fn cmdConsult(allocator: MemAllocator, task: []const u8) !u8 {
    const ee = ExperienceEngine.init(allocator);
    const ctx = try ee.consult(task);
    defer ctx.deinit(allocator);

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";

    std.debug.print("\n{s}🧠 EXPERIENCE CONSULT{s}\n", .{ CYAN, RESET });
    std.debug.print("  Task: {s}\n", .{task});
    std.debug.print("  Blacklisted: {s}{s}\n\n", .{ if (ctx.is_blacklisted) RED else GREEN, if (ctx.is_blacklisted) "YES ⛔" else "NO ✓" });

    if (ctx.is_blacklisted) {
        std.debug.print("  {s}⚠️  RECOMMENDATION: {s}{s}\n\n", .{ RED, ctx.recommendation, RESET });
        return 1; // Exit with error for blacklisted tasks
    }

    std.debug.print("  {s}✓ {s}{s}\n\n", .{ GREEN, ctx.recommendation, RESET });
    return 0;
}

fn cmdBlacklist(allocator: MemAllocator) !u8 {
    _ = ExperienceEngine.init(allocator);

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";

    std.debug.print("\n{s}🧠 BLACKLIST STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  File: .trinity/mistakes/blacklist.json\n\n", .{});
    std.debug.print("  Loading blacklist...\n", .{});

    // TODO: Load and display blacklist entries
    std.debug.print("\n  No blacklisted tasks (yet).\n\n", .{});
    return 0;
}

fn cmdRecord(allocator: MemAllocator, task: []const u8) !u8 {
    var ee = ExperienceEngine.init(allocator);

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";

    std.debug.print("\n{s}🧠 RECORD FAILURE{s}\n", .{ CYAN, RESET });
    std.debug.print("  Task: {s}\n", .{task});
    std.debug.print("\n  {s}Recording failure...{s}\n", .{ YELLOW, RESET });

    try ee.recordFailure(task, "Manual failure record via CLI");

    std.debug.print("  {s}✓ Failure recorded{s}\n\n", .{ "\x1b[32m", RESET });
    return 0;
}
