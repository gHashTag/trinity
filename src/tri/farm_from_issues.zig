// @origin(spec:farm_from_issues.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// FARM FROM ISSUES — Execute GitHub Issues as Farm Tasks
// ═══════════════════════════════════════════════════════════════════════════════
//
// Executes farm tasks parsed from GitHub Issues.
// Reuses evolution.zig:runInjectBatch() for actual worker injection.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const github_client = @import("github_client.zig");
const GitHubClient = github_client.GitHubClient;
const farm_telegram = @import("farm_telegram.zig");
const issue_planner = @import("issue_planner.zig");
const FarmTask = issue_planner.FarmTask;
const evolution_mod = @import("evolution.zig");

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";

pub const ExecutionResult = struct {
    tasks_executed: usize,
    tasks_failed: usize,
    workers_injected: usize,
    errors: []const u8,

    pub fn deinit(self: *const ExecutionResult, allocator: Allocator) void {
        if (self.errors.len > 0) allocator.free(self.errors);
    }
};

/// Main entry point: `tri farm from-issues [--dry-run] [--max-count N]`
pub fn runFromIssues(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var max_count: ?usize = null;
    var use_github = false; // Fetch from GitHub vs local cache

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--max-count") and i + 1 < args.len) {
            i += 1;
            max_count = std.fmt.parseInt(usize, args[i], 10) catch null;
        } else if (std.mem.eql(u8, args[i], "--github")) {
            use_github = true;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            printHelp();
            return;
        }
    }

    print("\n{s}📋 FARM FROM ISSUES{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    if (dry_run) print("  {s}DRY RUN — no actual injection{s}\n", .{ YELLOW, RESET });
    print("\n", .{});

    // Load tasks (from GitHub or local cache)
    var tasks: []FarmTask = undefined;
    if (use_github) {
        var client = try GitHubClient.init(allocator, dry_run);
        defer client.deinit();

        print("  🔍 Fetching issues from GitHub...\n", .{});
        const json_response = try client.listIssues("open");
        defer allocator.free(json_response);
        tasks = try issue_planner.listFarmTasks(allocator, json_response);
    } else {
        print("  📂 Loading tasks from .trinity/tasks/...\n", .{});
        tasks = try issue_planner.loadTasksFromDir(allocator);
    }
    defer {
        for (tasks) |*t| t.deinit(allocator);
        allocator.free(tasks);
    }

    if (tasks.len == 0) {
        print("  {s}⚠️  No farm tasks found.{s}\n", .{ YELLOW, RESET });
        print("  Create an issue with label 'farm-task' to get started.\n", .{});
        print("  See: tri farm from-issues --help\n\n", .{});
        return;
    }

    print("  {s}✅ Found {d} task(s){s}\n\n", .{ GREEN, tasks.len, RESET });

    // Execute tasks
    const result = try executeTasks(allocator, tasks, dry_run, max_count);
    defer result.deinit(allocator);

    // Summary
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    print("{s}SUMMARY:{s}\n", .{ BOLD, RESET });
    print("  Tasks executed: {d}\n", .{result.tasks_executed});
    print("  Workers injected: {d}\n", .{result.workers_injected});
    if (result.tasks_failed > 0) {
        print("  {s}Failed: {d}{s}\n", .{ RED, result.tasks_failed, RESET });
    }
    if (result.errors.len > 0) {
        print("  Errors: {s}\n", .{result.errors});
    }
    print("\n", .{});
}

/// Execute farm tasks in priority order
fn executeTasks(allocator: Allocator, tasks: []const FarmTask, dry_run: bool, max_count: ?usize) !ExecutionResult {
    var result = ExecutionResult{
        .tasks_executed = 0,
        .tasks_failed = 0,
        .workers_injected = 0,
        .errors = "",
    };

    var total_to_inject: usize = 0;
    if (max_count) |mc| {
        total_to_inject = mc;
    } else {
        // Sum all task counts
        for (tasks) |task| {
            total_to_inject += task.count;
        }
    }

    var remaining = total_to_inject;
    var errors_list = std.ArrayList(u8).init(allocator);

    for (tasks) |task| {
        if (remaining == 0) break;

        // Skip if already in-progress (from local cache)
        if (std.mem.eql(u8, task.status, "in-progress")) {
            print("  ⏭️  Issue #{d}: {s} (already in-progress)\n", .{ task.issue_number, task.issue_title });
            continue;
        }

        const count_for_task = @min(task.count, remaining);
        print("\n{s}📋 Issue #{d}: {s}{s}\n", .{ BOLD, task.issue_number, task.issue_title, RESET });
        print("   Objective: {s}  Count: {d}  Context: {d}  Schedule: {s}\n", .{
            task.objective, count_for_task, task.context, task.lr_schedule,
        });

        if (dry_run) {
            print("   {s}[DRY] Would inject {d} {s} workers{s}\n", .{ DIM, count_for_task, task.objective, RESET });
            result.tasks_executed += 1;
            result.workers_injected += count_for_task;
            remaining -= count_for_task;
            continue;
        }

        // Notify Telegram: task start
        farm_telegram.notifyTaskStart(allocator, task) catch |err| {
            print("   {s}⚠️  Telegram notification failed: {}{s}\n", .{ YELLOW, err, RESET });
        };

        // Execute via evolution.zig runInjectBatch
        const injected = executeTask(allocator, task, count_for_task) catch |err| {
            print("   {s}❌ Failed: {}{s}\n", .{ RED, err, RESET });
            result.tasks_failed += 1;
            try errors_list.writer().print("#{d}: {} | ", .{ task.issue_number, err });
            continue;
        };

        print("   {s}✅ Injected {d}/{d} workers{s}\n", .{ GREEN, injected, count_for_task, RESET });

        // Notify Telegram: task progress
        farm_telegram.notifyTaskProgress(allocator, task, injected, count_for_task) catch |err| {
            print("   {s}⚠️  Telegram notification failed: {}{s}\n", .{ YELLOW, err, RESET });
        };

        result.tasks_executed += 1;
        result.workers_injected += injected;
        remaining -= injected;

        // Update task status to in-progress (local cache only)
        try updateTaskStatus(allocator, task.issue_number, "in-progress");
    }

    if (errors_list.items.len > 0) {
        result.errors = try errors_list.toOwnedSlice();
    }

    return result;
}

/// Execute a single task by calling runInjectBatch
fn executeTask(allocator: Allocator, task: FarmTask, count: u32) !u32 {
    // Build args for runInjectBatch
    // Signature: runInjectBatch(allocator, count, sacred, dry_run, force_recycle, objective, ...)
    var arg_list = std.ArrayList([]const u8).init(allocator);
    defer arg_list.deinit();

    // Call runInjectBatch from evolution.zig
    // This will select worst performers and recycle them
    const sacred = task.sacred;
    const dry_run = false;
    const force_recycle = true; // Auto-recycle for batch mode
    const objective = task.objective;
    const nca_steps: u32 = 15000;
    const nca_entropy_min = "1.5";
    const nca_entropy_max = "2.8";
    const override_context = task.context;
    const override_sched = evolution_mod.LrSchedule.fromStr(task.lr_schedule);
    const force_fresh = false;
    const use_quotas = false;

    // runInjectBatch returns void, so we estimate injected = count
    // In real implementation, we'd need to modify runInjectBatch to return injected count
    evolution_mod.runInjectBatch(
        allocator,
        @intCast(count),
        sacred,
        dry_run,
        force_recycle,
        objective,
        nca_steps,
        nca_entropy_min,
        nca_entropy_max,
        override_context,
        override_sched,
        force_fresh,
        use_quotas,
    ) catch |err| {
        return err;
    };

    return count; // Assume all injected (runInjectBatch doesn't return count)
}

/// Update task status in local cache file
fn updateTaskStatus(allocator: Allocator, issue_number: u32, new_status: []const u8) !void {
    const filename = try std.fmt.allocPrint(allocator, ".trinity/tasks/farm-{d}.json", .{issue_number});
    defer allocator.free(filename);

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, stat.size);
    defer allocator.free(content);

    _ = try file.readAll(content);

    var parsed = try std.json.parseFromSlice(FarmTask, allocator, content, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    parsed.value.status = new_status;

    // Write back
    const out_file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
    defer out_file.close();

    try std.json.stringify(parsed.value, .{ .whitespace = .indent_2 }, out_file.writer());
}

fn printHelp() void {
    print(
        \\Usage: tri farm from-issues [options]
        \\
        \\Execute farm tasks from GitHub Issues labeled 'farm-task'.
        \\
        \\Options:
        \\  --dry-run          Show what would be done without executing
        \\  --max-count N      Maximum total workers to inject (default: sum of all tasks)
        \\  --github           Fetch tasks from GitHub (default: use .trinity/tasks/ cache)
        \\  --help, -h         Show this help
        \\
        \\Issue Label Format:
        \\  farm-task          Required marker label
        \\  objective:ntp|nca|jepa|hybrid  Training objective (default: ntp)
        \\  count:N            Number of workers (default: 5, max: 25)
        \\  context:27|54|81|243      Sacred dimension (default: 81)
        \\  schedule:cosine|wsd|phi_restart   LR schedule (default: cosine)
        \\  sacred             Use sacred mutations
        \\  priority:P1|P2|P3  Task priority (default: P2)
        \\  status:pending|in-progress|done  Task status
        \\
        \\Example Issue:
        \\  Title: "Farm Task: NTP Exploration Wave 9"
        \\  Labels: farm-task, objective:ntp, count:15, context:81, priority:P1
        \\
    , .{});
}
