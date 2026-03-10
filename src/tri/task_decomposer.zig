// ============================================================================
// TASK DECOMPOSER — Swarm Parallel Task Execution Engine
// Fetches sub-issues from GitHub, executes each via pipeline, reports results.
// Phase 1: Sequential execution with GitHub coordination.
// Phase 2 (future): git worktree isolation + std.process.Child parallelism.
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// COLORS
// ============================================================================

const RESET = "\x1b[0m";
const GREEN = "\x1b[38;2;0;229;153m";
const RED = "\x1b[38;2;239;68;68m";
const GOLDEN = "\x1b[38;2;255;215;0m";
const CYAN = "\x1b[38;2;0;255;255m";
const GRAY = "\x1b[38;2;156;156;160m";
const WHITE = "\x1b[38;2;255;255;255m";
const PURPLE = "\x1b[38;2;111;66;193m";

// ============================================================================
// TYPES
// ============================================================================

pub const SubTask = struct {
    number: u32,
    title: [256]u8 = [_]u8{0} ** 256,
    title_len: usize = 0,
    phase: Phase = .unknown,
    status: Status = .queued,
    agent: [32]u8 = [_]u8{0} ** 32,
    agent_len: usize = 0,
};

pub const Phase = enum {
    research,
    plan,
    implement,
    test_phase,
    verify,
    unknown,

    pub fn order(self: Phase) u8 {
        return switch (self) {
            .research => 0,
            .plan => 1,
            .implement => 2,
            .test_phase => 3,
            .verify => 4,
            .unknown => 5,
        };
    }

    pub fn name(self: Phase) []const u8 {
        return switch (self) {
            .research => "RESEARCH",
            .plan => "PLAN",
            .implement => "IMPLEMENT",
            .test_phase => "TEST",
            .verify => "VERIFY",
            .unknown => "UNKNOWN",
        };
    }

    pub fn emoji(self: Phase) []const u8 {
        return switch (self) {
            .research => "\xf0\x9f\x94\xac", // microscope
            .plan => "\xf0\x9f\x93\x90", // compass
            .implement => "\xf0\x9f\x94\xa7", // wrench
            .test_phase => "\xf0\x9f\xa7\xaa", // test tube
            .verify => "\xe2\x9c\x85", // check mark
            .unknown => "\xe2\x9d\x93", // question
        };
    }

    pub fn fromTitle(title: []const u8) Phase {
        const upper = blk: {
            var buf: [256]u8 = undefined;
            const len = @min(title.len, 256);
            for (0..len) |i| {
                buf[i] = std.ascii.toUpper(title[i]);
            }
            break :blk buf[0..len];
        };
        if (std.mem.indexOf(u8, upper, "RESEARCH") != null) return .research;
        if (std.mem.indexOf(u8, upper, "PLAN") != null) return .plan;
        if (std.mem.indexOf(u8, upper, "IMPLEMENT") != null) return .implement;
        if (std.mem.indexOf(u8, upper, "TEST") != null) return .test_phase;
        if (std.mem.indexOf(u8, upper, "VERIFY") != null) return .verify;
        return .unknown;
    }
};

pub const Status = enum {
    queued,
    running,
    done,
    failed,
    skipped,

    pub fn label(self: Status) []const u8 {
        return switch (self) {
            .queued => "status:queued",
            .running => "status:in-progress",
            .done => "status:done",
            .failed => "status:failed",
            .skipped => "status:skipped",
        };
    }

    pub fn fromLabel(label_str: []const u8) Status {
        if (std.mem.indexOf(u8, label_str, "queued") != null) return .queued;
        if (std.mem.indexOf(u8, label_str, "in-progress") != null) return .running;
        if (std.mem.indexOf(u8, label_str, "done") != null) return .done;
        if (std.mem.indexOf(u8, label_str, "failed") != null) return .failed;
        return .queued;
    }
};

pub const TaskResult = struct {
    task: SubTask,
    success: bool,
    output: [1024]u8 = [_]u8{0} ** 1024,
    output_len: usize = 0,
    duration_ms: u64 = 0,
};

// ============================================================================
// SWARM RUN — Main entry point
// ============================================================================

pub fn runSwarmExecute(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri swarm run <parent-issue-number>{s}\n", .{ GRAY, RESET });
        return;
    }

    const issue_str = args[0];
    const issue_num = std.fmt.parseInt(u32, issue_str, 10) catch {
        std.debug.print("{s}Invalid issue number: {s}{s}\n", .{ RED, issue_str, RESET });
        return;
    };

    // Check for --dry-run flag
    var dry_run = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        }
    }

    std.debug.print("\n{s}\xe2\x9a\xa1 SWARM RUN \xe2\x80\x94 Issue #{d}{s}\n", .{ GOLDEN, issue_num, RESET });
    std.debug.print("{s}\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90\xe2\x95\x90{s}\n\n", .{ GOLDEN, RESET });

    // 1. Fetch sub-issues
    std.debug.print("  {s}[1/4]{s} Fetching sub-issues...\n", .{ CYAN, RESET });
    var tasks: [16]SubTask = undefined;
    const task_count = try fetchSubIssues(allocator, issue_num, &tasks);

    if (task_count == 0) {
        std.debug.print("  {s}No sub-issues found for #{d}. Run 'tri swarm decompose {d}' first.{s}\n", .{ RED, issue_num, issue_num, RESET });
        return;
    }

    // 2. Sort by phase order
    sortByPhase(tasks[0..task_count]);

    std.debug.print("  {s}Found {d} sub-tasks:{s}\n\n", .{ GREEN, task_count, RESET });
    for (tasks[0..task_count]) |task| {
        const title_slice = task.title[0..task.title_len];
        std.debug.print("    {s} #{d} {s}\n", .{ task.phase.emoji(), task.number, title_slice });
    }
    std.debug.print("\n", .{});

    if (dry_run) {
        std.debug.print("  {s}--dry-run: would execute {d} tasks sequentially{s}\n\n", .{ GRAY, task_count, RESET });
        return;
    }

    // 3. Execute each task sequentially (Phase 1 — MVP)
    std.debug.print("  {s}[2/4]{s} Executing tasks sequentially...\n\n", .{ CYAN, RESET });
    var results: [16]TaskResult = undefined;
    var completed: u32 = 0;
    var failed: u32 = 0;

    for (tasks[0..task_count], 0..) |*task, i| {
        std.debug.print("  {s}[{d}/{d}]{s} {s} #{d} {s}...\n", .{
            CYAN,       i + 1, task_count, RESET,
            task.phase.emoji(), task.number,
            task.title[0..task.title_len],
        });

        // Skip already-done tasks
        if (task.status == .done) {
            std.debug.print("    {s}Already done, skipping{s}\n", .{ GREEN, RESET });
            results[i] = .{ .task = task.*, .success = true };
            completed += 1;
            continue;
        }

        // Mark as running
        updateLabel(allocator, task.number, "status:queued", "status:in-progress");

        // Comment on sub-issue
        commentOnIssue(allocator, task.number, std.fmt.comptimePrint(
            "\xf0\x9f\x90\x9d **Swarm Executor** | auto\n\xf0\x9f\x94\x84 **Status**: ACTING\n**Action**: Executing via `tri swarm run`\n**Phase**: Sequential execution (MVP)",
            .{},
        ));

        // Execute the task
        const result = executeTask(allocator, task);
        results[i] = result;

        if (result.success) {
            completed += 1;
            task.status = .done;
            updateLabel(allocator, task.number, "status:in-progress", "status:done");
            std.debug.print("    {s}\xe2\x9c\x85 Done ({d}ms){s}\n", .{ GREEN, result.duration_ms, RESET });
        } else {
            failed += 1;
            task.status = .failed;
            updateLabel(allocator, task.number, "status:in-progress", "status:failed");
            std.debug.print("    {s}\xe2\x9d\x8c Failed{s}\n", .{ RED, RESET });
        }
    }

    // 4. Report results
    std.debug.print("\n  {s}[3/4]{s} Results summary\n\n", .{ CYAN, RESET });
    std.debug.print("    {s}Completed: {d}/{d}{s}\n", .{ GREEN, completed, task_count, RESET });
    if (failed > 0) {
        std.debug.print("    {s}Failed:    {d}/{d}{s}\n", .{ RED, failed, task_count, RESET });
    }

    // 5. Comment on parent issue
    std.debug.print("\n  {s}[4/4]{s} Updating parent issue #{d}...\n", .{ CYAN, RESET, issue_num });
    var summary_buf: [1024]u8 = undefined;
    const summary = std.fmt.bufPrint(&summary_buf, "\xf0\x9f\x90\x9d **Swarm Run Complete**\n\n| Phase | Status |\n|-------|--------|\n| Tasks | {d}/{d} done |\n| Failed | {d} |\n\n_\xcf\x86\xc2\xb2 + 1/\xcf\x86\xc2\xb2 = 3 \xe2\x80\x94 The Trinity executes._", .{ completed, task_count, failed }) catch "Swarm run complete.";

    commentOnIssue(allocator, issue_num, summary);

    // Close parent if all done
    if (failed == 0 and completed == task_count) {
        std.debug.print("\n  {s}\xe2\x9c\x85 All sub-tasks done! Closing #{d}{s}\n", .{ GREEN, issue_num, RESET });
        closeIssue(allocator, issue_num);
    }

    std.debug.print("\n{s}\xf0\x9f\x94\xb1 \xcf\x86\xc2\xb2 + 1/\xcf\x86\xc2\xb2 = 3{s}\n\n", .{ GOLDEN, RESET });
}

// ============================================================================
// FETCH SUB-ISSUES — find child issues via GitHub search
// ============================================================================

fn fetchSubIssues(allocator: Allocator, parent_number: u32, out: *[16]SubTask) !usize {
    // Use gh with jq to filter and format sub-issues cleanly
    var parent_buf: [32]u8 = undefined;
    const parent_str = std.fmt.bufPrint(&parent_buf, "Parent: #{d}", .{parent_number}) catch return 0;

    var jq_buf: [256]u8 = undefined;
    const jq_filter = std.fmt.bufPrint(&jq_buf, ".[] | select(.body != null and (.body | contains(\"{s}\"))) | \"\\(.number)\\t\\(.title)\\t\\(.labels | map(.name) | join(\",\"))\"", .{parent_str}) catch return 0;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",      "issue", "list",
            "--state", "open",  "--limit",
            "20",      "--json", "number,title,body,labels",
            "--jq",    jq_filter,
        },
        .max_output_bytes = 65536,
    }) catch return 0;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Parse tab-separated lines: number\ttitle\tlabels
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (count >= 16) break;

        var fields = std.mem.splitScalar(u8, line, '\t');
        const num_str = fields.next() orelse continue;
        const title = fields.next() orelse continue;
        const labels = fields.next() orelse "";

        const issue_number = std.fmt.parseInt(u32, num_str, 10) catch continue;
        if (issue_number == parent_number) continue;

        var task = SubTask{
            .number = issue_number,
            .phase = Phase.fromTitle(title),
        };
        const len = @min(title.len, 256);
        @memcpy(task.title[0..len], title[0..len]);
        task.title_len = len;

        // Check status from labels
        if (std.mem.indexOf(u8, labels, "status:done") != null) {
            task.status = .done;
        } else if (std.mem.indexOf(u8, labels, "status:in-progress") != null) {
            task.status = .running;
        }

        out[count] = task;
        count += 1;
    }

    return count;
}

// ============================================================================
// EXECUTE TASK — run pipeline for a sub-issue
// ============================================================================

fn executeTask(allocator: Allocator, task: *const SubTask) TaskResult {
    const timer = std.time.milliTimestamp();
    const title = task.title[0..task.title_len];

    // Extract task description from title (remove "[Sub] Phase: " prefix)
    const task_desc = blk: {
        if (std.mem.indexOf(u8, title, ": ")) |colon_pos| {
            break :blk title[colon_pos + 2 ..];
        }
        break :blk title;
    };

    // For RESEARCH and PLAN phases, just mark as done (they're documentation)
    if (task.phase == .research or task.phase == .plan) {
        const elapsed: u64 = @intCast(std.time.milliTimestamp() - timer);
        return .{
            .task = task.*,
            .success = true,
            .duration_ms = elapsed,
        };
    }

    // For IMPLEMENT/TEST/VERIFY — try running the pipeline
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "zig-out/bin/tri",
            "pipeline",
            "run",
            task_desc,
        },
        .max_output_bytes = 65536,
    }) catch {
        const elapsed: u64 = @intCast(std.time.milliTimestamp() - timer);
        return .{
            .task = task.*,
            .success = false,
            .duration_ms = elapsed,
        };
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const success = result.term.Exited == 0;
    const elapsed: u64 = @intCast(std.time.milliTimestamp() - timer);

    var res = TaskResult{
        .task = task.*,
        .success = success,
        .duration_ms = elapsed,
    };

    // Copy output snippet
    const out = if (success) result.stdout else result.stderr;
    const out_len = @min(out.len, 1024);
    @memcpy(res.output[0..out_len], out[0..out_len]);
    res.output_len = out_len;

    return res;
}

// ============================================================================
// SORT — order tasks by phase
// ============================================================================

fn sortByPhase(tasks: []SubTask) void {
    // Simple insertion sort (max 16 elements)
    for (1..tasks.len) |i| {
        var j = i;
        while (j > 0 and tasks[j].phase.order() < tasks[j - 1].phase.order()) {
            const tmp = tasks[j];
            tasks[j] = tasks[j - 1];
            tasks[j - 1] = tmp;
            j -= 1;
        }
    }
}

// ============================================================================
// GITHUB HELPERS
// ============================================================================

fn updateLabel(allocator: Allocator, issue_number: u32, remove: []const u8, add: []const u8) void {
    var num_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{issue_number}) catch return;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",              "issue",  "edit",
            num_str,           "--remove-label", remove,
            "--add-label", add,
        },
        .max_output_bytes = 4096,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

fn commentOnIssue(allocator: Allocator, issue_number: u32, body: []const u8) void {
    var num_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{issue_number}) catch return;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",     "issue",  "comment",
            num_str, "--body", body,
        },
        .max_output_bytes = 4096,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

fn closeIssue(allocator: Allocator, issue_number: u32) void {
    var num_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{issue_number}) catch return;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",     "issue", "close",
            num_str,
        },
        .max_output_bytes = 4096,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

fn ghGetIssueTitle(allocator: Allocator, issue_str: []const u8, buf: *[512]u8) ![]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh",        "issue",  "view",
            issue_str,   "--json", "title",
            "--jq",      ".title",
        },
        .max_output_bytes = 4096,
    }) catch return "Unknown";
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const title = std.mem.trimRight(u8, result.stdout, "\n\r ");
    const len = @min(title.len, 512);
    @memcpy(buf[0..len], title[0..len]);
    return buf[0..len];
}

// ============================================================================
// TESTS
// ============================================================================

test "Phase.fromTitle" {
    try std.testing.expectEqual(Phase.research, Phase.fromTitle("1/5 — RESEARCH"));
    try std.testing.expectEqual(Phase.plan, Phase.fromTitle("2/5 — PLAN"));
    try std.testing.expectEqual(Phase.implement, Phase.fromTitle("3/5 — IMPLEMENT"));
    try std.testing.expectEqual(Phase.test_phase, Phase.fromTitle("4/5 — TEST"));
    try std.testing.expectEqual(Phase.verify, Phase.fromTitle("5/5 — VERIFY"));
    try std.testing.expectEqual(Phase.unknown, Phase.fromTitle("Random title"));
}

test "Phase.order" {
    try std.testing.expect(Phase.research.order() < Phase.plan.order());
    try std.testing.expect(Phase.plan.order() < Phase.implement.order());
    try std.testing.expect(Phase.implement.order() < Phase.test_phase.order());
    try std.testing.expect(Phase.test_phase.order() < Phase.verify.order());
}

test "Status.fromLabel" {
    try std.testing.expectEqual(Status.queued, Status.fromLabel("status:queued"));
    try std.testing.expectEqual(Status.running, Status.fromLabel("status:in-progress"));
    try std.testing.expectEqual(Status.done, Status.fromLabel("status:done"));
}

test "sortByPhase" {
    var tasks = [_]SubTask{
        .{ .number = 3, .phase = .implement },
        .{ .number = 1, .phase = .research },
        .{ .number = 5, .phase = .verify },
        .{ .number = 2, .phase = .plan },
    };
    sortByPhase(&tasks);
    try std.testing.expectEqual(@as(u32, 1), tasks[0].number);
    try std.testing.expectEqual(@as(u32, 2), tasks[1].number);
    try std.testing.expectEqual(@as(u32, 3), tasks[2].number);
    try std.testing.expectEqual(@as(u32, 5), tasks[3].number);
}
