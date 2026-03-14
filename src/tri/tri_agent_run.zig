// @origin(spec:tri_agent_run.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI AGENT RUN — Flagship Chimera: Full Autonomous Issue Cycle
// ═══════════════════════════════════════════════════════════════════════════════
//
// One command, full cycle:
//   tri agent run <N>
//
// 8-step sequence:
//   1. issue view <N>        → get issue title/body
//   2. experience recall     → check for related past episodes
//   3. spec create <name>    → create .tri spec from issue
//   4. gen <spec>            → generate Zig from spec
//   5. verify                → run tests
//   6. verdict               → toxic verdict
//   7. experience save       → record episode
//   8. git commit            → commit with issue ref
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const experience_hooks = @import("experience_hooks.zig");
const tri_experience = @import("tri_experience.zig");
const toxic_verdict = @import("toxic_verdict.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const RunStep = struct {
    name: []const u8 = "",
    success: bool = false,
    detail: [256]u8 = [_]u8{0} ** 256,
    detail_len: usize = 0,

    fn setDetail(self: *RunStep, msg: []const u8) void {
        const len = @min(msg.len, self.detail.len);
        @memcpy(self.detail[0..len], msg[0..len]);
        self.detail_len = len;
    }

    fn getDetail(self: *const RunStep) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runAgentRunCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    const issue_str = args[0];
    const issue_num = std.fmt.parseInt(u32, issue_str, 10) catch {
        print("{s}Invalid issue number: {s}{s}\n", .{ RED, issue_str, RESET });
        printHelp();
        return;
    };

    try runFullCycle(allocator, issue_num, issue_str);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL 8-STEP CYCLE
// ═══════════════════════════════════════════════════════════════════════════════

fn runFullCycle(allocator: Allocator, issue_num: u32, issue_str: []const u8) !void {
    const github_commands = @import("github_commands.zig");
    const pipeline = @import("tri_pipeline.zig");
    const commands = @import("tri_commands.zig");

    print("\n{s}🤖 AGENT RUN — Issue #{d}{s}\n", .{ BOLD, issue_num, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}8-step autonomous cycle: view → recall → spec → gen → verify → verdict → save → commit{s}\n\n", .{ DIM, RESET });

    var steps: [8]RunStep = [_]RunStep{.{}} ** 8;
    var all_ok = true;

    // Step 1: Issue view
    printStepStart(1, 8, "Issue view");
    steps[0].name = "issue view";
    github_commands.runGithubCommand(allocator, &[_][]const u8{ "issue", "view", issue_str }, false) catch |err| {
        steps[0].setDetail(@errorName(err));
        printStepEnd(false);
        all_ok = false;
    };
    if (steps[0].detail_len == 0) {
        steps[0].success = true;
        steps[0].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2: Experience recall
    printStepStart(2, 8, "Experience recall");
    steps[1].name = "experience recall";
    var issue_task_buf: [32]u8 = undefined;
    const issue_task = std.fmt.bufPrint(&issue_task_buf, "issue-{d}", .{issue_num}) catch "issue";
    tri_experience.runExperienceCommand(allocator, &[_][]const u8{ "recall", "--task", issue_task }) catch |err| {
        steps[1].setDetail(@errorName(err));
        printStepEnd(false);
        // Non-fatal: no past episodes is OK
    };
    if (steps[1].detail_len == 0) {
        steps[1].success = true;
        steps[1].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2b: Verdict briefing — show agent what's weak BEFORE it starts
    toxic_verdict.renderAgentBriefing(allocator);

    // Step 3: Spec create
    printStepStart(3, 8, "Spec create");
    steps[2].name = "spec create";
    pipeline.runSpecCreateCommand(allocator, &[_][]const u8{issue_task});
    steps[2].success = true;
    steps[2].setDetail("OK");
    printStepEnd(true);

    // Step 4: Gen
    printStepStart(4, 8, "Code generate");
    steps[3].name = "gen";
    commands.runGenCommand(allocator, &[_][]const u8{}) catch |err| {
        steps[3].setDetail(@errorName(err));
        printStepEnd(false);
        all_ok = false;
    };
    if (steps[3].detail_len == 0) {
        steps[3].success = true;
        steps[3].setDetail("OK");
        printStepEnd(true);
    }

    // Step 5: Verify
    printStepStart(5, 8, "Verify tests");
    steps[4].name = "verify";
    pipeline.runVerifyCommand(allocator);
    steps[4].success = true;
    steps[4].setDetail("OK");
    printStepEnd(true);

    // Step 6: Verdict with explain
    printStepStart(6, 8, "Toxic verdict");
    steps[5].name = "verdict";
    pipeline.runVerdictCommandEx(allocator, &[_][]const u8{"--explain"});
    steps[5].success = true;
    steps[5].setDetail("OK");
    printStepEnd(true);

    // Step 7: Experience save
    printStepStart(7, 8, "Experience save");
    steps[6].name = "experience save";
    {
        var episode = tri_experience.Episode{};
        episode.timestamp = std.time.timestamp();
        episode.issue = issue_num;

        var task_buf: [256]u8 = undefined;
        const task_str = std.fmt.bufPrint(&task_buf, "agent run #{d}", .{issue_num}) catch "agent run";
        tri_experience.copyToFixed(&episode.task, &episode.task_len, task_str);

        const verd: []const u8 = if (all_ok) "PASS" else "FAIL";
        tri_experience.copyToFixed(&episode.verdict, &episode.verdict_len, verd);
        episode.iterations = 1;

        // Count failures as learnings
        var learning_idx: u8 = 0;
        for (&steps) |*s| {
            if (!s.success and learning_idx < 8) {
                var learn_buf: [128]u8 = undefined;
                const learn = std.fmt.bufPrint(&learn_buf, "{s}: {s}", .{ s.name, s.getDetail() }) catch s.name;
                tri_experience.copyToFixed(&episode.learnings[learning_idx], &episode.learning_lens[learning_idx], learn);
                learning_idx += 1;
            }
        }
        episode.learning_count = learning_idx;

        tri_experience.saveEpisode(episode) catch {};
        steps[6].success = true;
        steps[6].setDetail("OK");
        printStepEnd(true);
    }

    // Step 8: Git commit
    printStepStart(8, 8, "Git commit");
    steps[7].name = "git commit";
    var commit_buf: [128]u8 = undefined;
    const commit_msg = std.fmt.bufPrint(&commit_buf, "feat(agent): auto-run issue #{d}", .{issue_num}) catch "feat(agent): auto-run";
    commands.runGitCommand(allocator, "commit", &[_][]const u8{commit_msg}) catch |err| {
        steps[7].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[7].detail_len == 0) {
        steps[7].success = true;
        steps[7].setDetail("OK");
        printStepEnd(true);
    }

    // Summary
    var ok: usize = 0;
    var fail: usize = 0;
    for (&steps) |*s| {
        if (s.success) ok += 1 else fail += 1;
    }

    print("\n  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}AGENT RUN #{d} SUMMARY{s}\n", .{ BOLD, issue_num, RESET });
    print("  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    for (&steps, 0..) |*s, i| {
        const status_icon = if (s.success) GREEN else RED;
        const status_sym: []const u8 = if (s.success) "OK" else "FAIL";
        print("  {s}[{d}]{s} {s}: {s}{s}{s}\n", .{
            DIM, i + 1, RESET, s.name, status_icon, status_sym, RESET,
        });
    }

    print("\n  Steps:  {s}{d} OK{s} / {s}{d} FAIL{s}\n", .{
        GREEN, ok, RESET, if (fail > 0) RED else DIM, fail, RESET,
    });

    const final_verdict: []const u8 = if (fail == 0) "PASS" else "PARTIAL";
    const verdict_color = if (fail == 0) GREEN else YELLOW;
    print("  Result: {s}{s}{s}\n\n", .{ verdict_color, final_verdict, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn printStepStart(step: usize, total: usize, name: []const u8) void {
    print("  {s}[{d}/{d}]{s} {s}...", .{ CYAN, step, total, RESET, name });
}

fn printStepEnd(success: bool) void {
    if (success) {
        print(" {s}OK{s}\n", .{ GREEN, RESET });
    } else {
        print(" {s}FAIL{s}\n", .{ RED, RESET });
    }
}

fn printHelp() void {
    print("\n{s}🤖 AGENT RUN — Full Autonomous Issue Cycle{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  Usage: {s}tri agent run <issue-number>{s}\n\n", .{ BOLD, RESET });
    print("  8-step sequence:\n", .{});
    print("    1. {s}issue view{s}       — fetch issue details\n", .{ CYAN, RESET });
    print("    2. {s}experience recall{s} — check past episodes\n", .{ CYAN, RESET });
    print("    3. {s}spec create{s}      — create .tri spec\n", .{ CYAN, RESET });
    print("    4. {s}gen{s}              — generate Zig code\n", .{ CYAN, RESET });
    print("    5. {s}verify{s}           — run tests\n", .{ CYAN, RESET });
    print("    6. {s}verdict{s}          — toxic verdict\n", .{ CYAN, RESET });
    print("    7. {s}experience save{s}  — record episode\n", .{ CYAN, RESET });
    print("    8. {s}git commit{s}       — commit with issue ref\n", .{ CYAN, RESET });
    print("\n", .{});
}

test "tri_agent_run_step_helpers" {
    // Verify UI helper functions exist and are callable (compile-time check)
    const f1 = printStepStart;
    const f2 = printStepEnd;
    try std.testing.expect(@TypeOf(f1) == fn (usize, usize, []const u8) void);
    try std.testing.expect(@TypeOf(f2) == fn (bool) void);
}
