// @origin(spec:issue_planner.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// ISSUE PLANNER — GitHub Issues → Farm Task Parser
// ═══════════════════════════════════════════════════════════════════════════════
//
// Parses GitHub Issues labeled with `farm-task` into FarmTask configurations.
// Supports label-based configuration (MVP) and YAML body parsing (Phase 2).
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const github_client = @import("github_client.zig");
const GitHubClient = github_client.GitHubClient;
const IssueInfo = github_client.IssueInfo;

pub const FarmTask = struct {
    issue_number: u32,
    issue_title: []const u8,
    objective: []const u8, // "ntp", "nca", "jepa", "hybrid"
    count: u32, // number of workers to inject
    context: u32, // 27, 54, 81, 243 (sacred dimensions)
    lr_schedule: []const u8, // "cosine", "wsd", "phi_restart", "d2z"
    sacred: bool, // use sacred mutations
    priority: u8, // 1=P1, 2=P2, 3=P3 (lower is higher priority)
    status: []const u8, // "pending", "in-progress", "done"

    /// Parse FarmTask from GitHub Issue using labels
    pub fn fromIssue(allocator: Allocator, issue: IssueInfo) !?FarmTask {
        // Check for farm-task label
        var has_farm_task = false;
        for (issue.labels) |label| {
            if (std.mem.eql(u8, label, "farm-task")) {
                has_farm_task = true;
                break;
            }
        }
        if (!has_farm_task) return null;

        // Skip if already done
        for (issue.labels) |label| {
            if (std.mem.eql(u8, label, "status:done")) return null;
        };

        var task = FarmTask{
            .issue_number = issue.number,
            .issue_title = try allocator.dupe(u8, issue.title),
            .objective = "ntp",
            .count = 5,
            .context = 81,
            .lr_schedule = "cosine",
            .sacred = false,
            .priority = 2, // P2 default
            .status = "pending",
        };

        // Parse labels for configuration
        for (issue.labels) |label| {
            if (std.mem.startsWith(u8, label, "objective:")) {
                const obj = label["objective:".len..];
                if (std.mem.eql(u8, obj, "ntp") or std.mem.eql(u8, obj, "nca") or
                    std.mem.eql(u8, obj, "jepa") or std.mem.eql(u8, obj, "hybrid"))
                {
                    task.objective = obj;
                }
            } else if (std.mem.startsWith(u8, label, "count:")) {
                const count_str = label["count:".len..];
                const count_val = std.fmt.parseInt(u32, count_str, 10) catch 5;
                task.count = @min(count_val, 25); // Max 25 workers per task
            } else if (std.mem.startsWith(u8, label, "context:")) {
                const ctx_str = label["context:".len..];
                const ctx_val = std.fmt.parseInt(u32, ctx_str, 10) catch 81;
                if (ctx_val == 27 or ctx_val == 54 or ctx_val == 81 or ctx_val == 243) {
                    task.context = ctx_val;
                }
            } else if (std.mem.startsWith(u8, label, "schedule:")) {
                const sched = label["schedule:".len..];
                if (std.mem.eql(u8, sched, "cosine") or std.mem.eql(u8, sched, "wsd") or
                    std.mem.eql(u8, sched, "phi_restart") or std.mem.eql(u8, sched, "d2z"))
                {
                    task.lr_schedule = sched;
                }
            } else if (std.mem.eql(u8, label, "sacred")) {
                task.sacred = true;
            } else if (std.mem.eql(u8, label, "priority:P1")) {
                task.priority = 1;
            } else if (std.mem.eql(u8, label, "priority:P2")) {
                task.priority = 2;
            } else if (std.mem.eql(u8, label, "priority:P3")) {
                task.priority = 3;
            } else if (std.mem.eql(u8, label, "status:in-progress")) {
                task.status = "in-progress";
            }
        }

        return task;
    }

    /// Free allocated memory
    pub fn deinit(self: *const FarmTask, allocator: Allocator) void {
        allocator.free(self.issue_title);
    }

    /// Compare tasks by priority (lower first), then by issue number
    fn compareAsc(context: void, a: FarmTask, b: FarmTask) bool {
        _ = context;
        if (a.priority != b.priority) return a.priority < b.priority;
        return a.issue_number < b.issue_number;
    }
};

/// List all farm tasks from open GitHub issues
pub fn listFarmTasks(allocator: Allocator, client: *GitHubClient) ![]FarmTask {
    var tasks = std.ArrayList(FarmTask).init(allocator);

    // List open issues
    const issues = try client.listIssues(allocator, "open");
    defer {
        for (issues) |*issue| {
            allocator.free(issue.title);
            allocator.free(issue.body);
            for (issue.labels) |l| allocator.free(l);
            allocator.free(issue.labels);
        }
        allocator.free(issues);
    }

    // Parse each issue
    for (issues) |issue| {
        if (try FarmTask.fromIssue(allocator, issue)) |task| {
            try tasks.append(task);
        }
    }

    // Sort by priority
    std.sort.insertion(FarmTask, tasks.items, {}, FarmTask.compareAsc);

    return tasks.toOwnedSlice();
}

/// Save tasks to .trinity/tasks/ directory as JSON
pub fn saveTasksToDir(allocator: Allocator, tasks: []const FarmTask) !void {
    const tasks_dir = ".trinity/tasks";
    try std.fs.cwd().makePath(tasks_dir);

    for (tasks) |task| {
        const filename = try std.fmt.allocPrint(allocator, "{s}/farm-{d}.json", .{ tasks_dir, task.issue_number });
        defer allocator.free(filename);

        const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
        defer file.close();

        const writer = file.writer();
        try std.json.stringify(task, .{ .whitespace = .indent_2 }, writer);
    }
}

/// Load all task files from .trinity/tasks/
pub fn loadTasksFromDir(allocator: Allocator) ![]FarmTask {
    const tasks_dir = ".trinity/tasks";
    var tasks = std.ArrayList(FarmTask).init(allocator);

    const dir = try std.fs.cwd().openDir(tasks_dir, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const file = try dir.openFile(entry.name, .{});
        defer file.close();

        const stat = try file.stat();
        const content = try allocator.alloc(u8, stat.size);
        defer allocator.free(content);

        _ = try file.readAll(content);

        const parsed = try std.json.parseFromSlice(FarmTask, allocator, content, .{
            .ignore_unknown_fields = true,
        });
        try tasks.append(parsed.value);
    }

    return tasks.toOwnedSlice();
}

/// Delete task file by issue number
pub fn deleteTaskFile(allocator: Allocator, issue_number: u32) !void {
    const filename = try std.fmt.allocPrint(allocator, ".trinity/tasks/farm-{d}.json", .{issue_number});
    defer allocator.free(filename);

    std.fs.cwd().deleteFile(filename) catch |err| {
        if (err == error.FileNotFound) return; // Already deleted
        return err;
    };
}
