// @origin(spec:experience_engine.tri) @regen(manual-impl)
// MNL (Mistake Never Again) Pattern + Experience System
const std = @import("std");

const MemAllocator = std.mem.Allocator;

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
        // Simple stub for P10 - TODO: implement VSA vector search
        var similar_tasks_slice = [_]SimilarTask{};

        const recommendation = if (blacklisted)
            "TASK BLACKLISTED: 3+ failures detected. Skip or investigate."
        else
            "No similar tasks found. Proceed with caution.";

        return TaskContext{
            .task = try ee.allocator.dupe(u8, task),
            .similar_tasks = &similar_tasks_slice,
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

        defer {
            // Manual cleanup for var blacklist
            for (blacklist.entries) |entry| {
                ee.allocator.free(entry.task);
                if (entry.last_error.len > 0) ee.allocator.free(entry.last_error);
            }
            ee.allocator.free(blacklist.entries);
        }

        // Exact match check
        for (blacklist.entries) |entry| {
            if (std.mem.eql(u8, entry.task, task) and entry.count >= 3) {
                return true;
            }
        }

        // TODO: Fuzzy match for similar tasks
        return false;
    }

    /// Record failure → blacklist after 3rd (P11: Full implementation)
    pub fn recordFailure(ee: *ExperienceEngine, task: []const u8, error_msg: []const u8) !void {
        // Load current blacklist
        var blacklist = try ee.loadBlacklist();
        defer {
            // Cleanup old entries
            for (blacklist.entries) |entry| {
                ee.allocator.free(entry.task);
                if (entry.last_error.len > 0) ee.allocator.free(entry.last_error);
            }
            ee.allocator.free(blacklist.entries);
        }

        // Find existing entry or create new one
        var found_index: ?usize = null;
        for (blacklist.entries, 0..) |entry, i| {
            if (std.mem.eql(u8, entry.task, task)) {
                found_index = i;
                break;
            }
        }

        const timestamp = std.time.timestamp();

        if (found_index) |idx| {
            // Update existing entry
            blacklist.entries[idx].count +|= 1; // Saturation add
            blacklist.entries[idx].timestamp = timestamp;
            // Free old error message
            if (blacklist.entries[idx].last_error.len > 0) {
                ee.allocator.free(blacklist.entries[idx].last_error);
            }
            blacklist.entries[idx].last_error = try ee.allocator.dupe(u8, error_msg);
        } else {
            // Create new entry
            const new_entry = FailureRecord{
                .task = try ee.allocator.dupe(u8, task),
                .count = 1,
                .last_error = try ee.allocator.dupe(u8, error_msg),
                .timestamp = timestamp,
            };

            // Allocate new array with one more element
            const new_entries = try ee.allocator.alloc(FailureRecord, blacklist.entries.len + 1);
            @memcpy(new_entries[0..blacklist.entries.len], blacklist.entries);
            new_entries[blacklist.entries.len] = new_entry;
            blacklist.entries = new_entries;
        }

        blacklist.last_updated = timestamp;

        // Save updated blacklist
        try ee.saveBlacklist(&blacklist);

        // Log warning/blacklist status
        const entry_count = if (found_index) |idx| blacklist.entries[idx].count else 1;
        if (entry_count >= 3) {
            std.log.warn("🚫 MNL: Task '{s}' BLACKLISTED (3+ failures)", .{task});
        } else {
            std.log.warn("⚠️ MNL: Task '{s}' failure #{d}: {s}", .{ task, entry_count, error_msg });
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

        // Serialize episode to JSON using std.json.Stringify.valueAlloc (Zig 0.15 API)
        const json_str = try std.json.Stringify.valueAlloc(ee.allocator, episode, .{});
        defer ee.allocator.free(json_str);

        // Write to file
        try file.writeAll(json_str.items);

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
        const parsed = try std.json.parseFromSlice(Blacklist, ee.allocator, content, .{});
        defer parsed.deinit();

        return parsed.value;
    }

    /// Save blacklist to JSON
    fn saveBlacklist(ee: *ExperienceEngine, blacklist: *const Blacklist) !void {
        // Ensure directory exists
        std.fs.cwd().makePath(".trinity/mistakes") catch {};

        const file = try std.fs.cwd().createFile(ee.blacklist_file, .{ .read = true });
        defer file.close();

        // Serialize to JSON using std.json.Stringify.valueAlloc (Zig 0.15 API)
        const json_str = try std.json.Stringify.valueAlloc(ee.allocator, blacklist, .{});
        defer ee.allocator.free(json_str);

        // Write to file
        try file.writeAll(json_str.items);

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
    defer ctx.deinit(ee.allocator);

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
    var ee = ExperienceEngine.init(allocator);

    const RESET = "\x1b[0m";
    const CYAN = "\x1b[36m";
    const YELLOW = "\x1b[33m";
    const RED = "\x1b[31m";
    const GREEN = "\x1b[32m";

    std.debug.print("\n{s}🧠 BLACKLIST STATUS{s}\n", .{ CYAN, RESET });
    std.debug.print("  File: .trinity/mistakes/blacklist.json\n\n", .{});

    const blacklist = ee.loadBlacklist() catch |err| {
        std.debug.print("  {s}Error loading blacklist: {}{s}\n\n", .{ RED, err, RESET });
        return 1;
    };
    defer {
        for (blacklist.entries) |entry| {
            allocator.free(entry.task);
            if (entry.last_error.len > 0) allocator.free(entry.last_error);
        }
        allocator.free(blacklist.entries);
    }

    if (blacklist.entries.len == 0) {
        std.debug.print("  {s}✓ No blacklisted tasks (yet).{s}\n\n", .{ GREEN, RESET });
        return 0;
    }

    std.debug.print("  Total entries: {d}\n", .{blacklist.entries.len});
    std.debug.print("  Last updated: {d}\n\n", .{blacklist.last_updated});

    std.debug.print("  {s}┌─────────────────────────────────────────────────────────────┐{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}│ Task                              Count  Last Error         │{s}\n", .{ YELLOW, RESET });
    std.debug.print("  {s}├─────────────────────────────────────────────────────────────┤{s}\n", .{ YELLOW, RESET });

    for (blacklist.entries) |entry| {
        const status_color = if (entry.count >= 3) RED else GREEN;
        std.debug.print("  {s}│ {s:<32} {d:>2}x   {s:<15} │{s}\n", .{
            status_color,
            entry.task[0..@min(entry.task.len, 32)],
            entry.count,
            if (entry.last_error.len > 0)
                entry.last_error[0..@min(entry.last_error.len, 15)]
            else
                "(none)",
            RESET,
        });
    }

    std.debug.print("  {s}└─────────────────────────────────────────────────────────────┘{s}\n\n", .{ YELLOW, RESET });

    // Count blacklisted (3+ failures)
    var blacklisted_count: usize = 0;
    for (blacklist.entries) |entry| {
        if (entry.count >= 3) blacklisted_count += 1;
    }

    if (blacklisted_count > 0) {
        std.debug.print("  {s}⛔ {d} task(s) BLACKLISTED (auto-skipped){s}\n\n", .{ RED, blacklisted_count, RESET });
    }

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
