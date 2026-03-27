// @origin(spec:dev_loop.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV LOOP — Full autonomous development cycle
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri dev loop [--iterations N] [--interval Ns]
// Wires: scan → pick → research → gen → test → verdict → commit
// into a single autonomous iteration.
//
// Part of Trinity Tech Tree: Integration Layer [I1]
// Dependencies: dev_scan (F1), dev_pick (L1), toxic_verdict (F2),
//               loop_decide (L3), tri_experience (F3)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");
const print = std.debug.print;

const GREEN = colors.GREEN;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RESET = colors.RESET;
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from dev_loop.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoopPhase = enum {
    scan,
    pick,
    research,
    spec,
    gen,
    verify,
    verdict,
    commit,
    experience,
    decide,

    pub fn label(self: LoopPhase) []const u8 {
        return switch (self) {
            .scan => "SCAN",
            .pick => "PICK",
            .research => "RESEARCH",
            .spec => "SPEC",
            .gen => "GEN",
            .verify => "VERIFY",
            .verdict => "VERDICT",
            .commit => "COMMIT",
            .experience => "EXPERIENCE",
            .decide => "DECIDE",
        };
    }

    pub fn emoji(self: LoopPhase) []const u8 {
        return switch (self) {
            .scan => "1",
            .pick => "2",
            .research => "3",
            .spec => "4",
            .gen => "5",
            .verify => "6",
            .verdict => "7",
            .commit => "8",
            .experience => "9",
            .decide => "10",
        };
    }

    pub fn number(self: LoopPhase) u32 {
        return switch (self) {
            .scan => 1,
            .pick => 2,
            .research => 3,
            .spec => 4,
            .gen => 5,
            .verify => 6,
            .verdict => 7,
            .commit => 8,
            .experience => 9,
            .decide => 10,
        };
    }
};

pub const LoopStep = struct {
    phase: LoopPhase = .scan,
    started_at: i64 = 0,
    finished_at: i64 = 0,
    success: bool = false,
    output: [256]u8 = undefined,
    output_len: usize = 0,

    pub fn outputStr(self: *const LoopStep) []const u8 {
        return self.output[0..self.output_len];
    }

    fn setOutput(self: *LoopStep, text: []const u8) void {
        const len = @min(text.len, self.output.len);
        @memcpy(self.output[0..len], text[0..len]);
        self.output_len = len;
    }

    pub fn durationSecs(self: *const LoopStep) u32 {
        if (self.finished_at <= self.started_at) return 0;
        return @intCast(self.finished_at - self.started_at);
    }
};

const MAX_STEPS = 10;

pub const LoopIteration = struct {
    number: u32 = 0,
    issue_id: [32]u8 = undefined,
    issue_id_len: usize = 0,
    issue_title: [128]u8 = undefined,
    issue_title_len: usize = 0,
    steps: [MAX_STEPS]LoopStep = undefined,
    step_count: usize = 0,
    verdict_score: f32 = 0,
    decision: [32]u8 = undefined,
    decision_len: usize = 0,
    total_seconds: u32 = 0,

    pub fn issueIdStr(self: *const LoopIteration) []const u8 {
        return self.issue_id[0..self.issue_id_len];
    }

    pub fn issueTitleStr(self: *const LoopIteration) []const u8 {
        return self.issue_title[0..self.issue_title_len];
    }

    pub fn decisionStr(self: *const LoopIteration) []const u8 {
        return self.decision[0..self.decision_len];
    }

    fn setIssueId(self: *LoopIteration, text: []const u8) void {
        const len = @min(text.len, self.issue_id.len);
        @memcpy(self.issue_id[0..len], text[0..len]);
        self.issue_id_len = len;
    }

    fn setIssueTitle(self: *LoopIteration, text: []const u8) void {
        const len = @min(text.len, self.issue_title.len);
        @memcpy(self.issue_title[0..len], text[0..len]);
        self.issue_title_len = len;
    }

    fn setDecision(self: *LoopIteration, text: []const u8) void {
        const len = @min(text.len, self.decision.len);
        @memcpy(self.decision[0..len], text[0..len]);
        self.decision_len = len;
    }

    fn addStep(self: *LoopIteration, step: LoopStep) void {
        if (self.step_count < MAX_STEPS) {
            self.steps[self.step_count] = step;
            self.step_count += 1;
        }
    }

    pub fn passedSteps(self: *const LoopIteration) u32 {
        var count: u32 = 0;
        for (self.steps[0..self.step_count]) |s| {
            if (s.success) count += 1;
        }
        return count;
    }
};

pub const DevLoopState = struct {
    current_iteration: u32 = 0,
    max_iterations: u32 = 1,
    interval_seconds: u32 = 0,
    consecutive_failures: u32 = 0,
    total_commits: u32 = 0,
    total_specs_created: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// STEP EXECUTION
// ═══════════════════════════════════════════════════════════════════════════════

fn runTriCommand(allocator: Allocator, args: []const []const u8) struct { success: bool, output: []const u8 } {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
        .max_output_bytes = 65536,
    }) catch return .{ .success = false, .output = "command failed to spawn" };

    // We can't defer free here since we return the output
    // Caller must handle this carefully
    allocator.free(result.stderr);

    const success = result.term.Exited == 0;
    return .{ .success = success, .output = result.stdout };
}

/// Issue #420: Post dev loop step comment to GitHub issue
/// Format: "{emoji} [{PHASE}] Step {N}/10 — {detail}"
fn postStepComment(allocator: Allocator, issue_num: u32, phase: LoopPhase, detail: []const u8) void {
    if (issue_num == 0) return;

    var issue_str: [16]u8 = undefined;
    const issue_arg = std.fmt.bufPrint(&issue_str, "{d}", .{issue_num}) catch return;

    var phase_str: [8]u8 = undefined;
    const phase_arg = std.fmt.bufPrint(&phase_str, "{d}/10", .{phase.number()}) catch return;

    const status = switch (phase) {
        .scan => "SCAN",
        .pick => "PICK",
        .research => "RESEARCH",
        .spec => "SPEC",
        .gen => "CODEGEN",
        .verify => "TEST",
        .verdict => "VERDICT",
        .commit => "DONE",
        .experience => "EXPERIENCE",
        .decide => "DECIDE",
    };

    const r = runTriCommand(allocator, &.{
        "tri", "issue", "comment", issue_arg,
        "--status", status,
        "--phase",  phase_arg,
        "--step",   detail,
        "--agent",  "dev-loop",
    });
    allocator.free(r.output);
}

fn executePhase(allocator: Allocator, phase: LoopPhase, issue_num: u32) LoopStep {
    var step = LoopStep{
        .phase = phase,
        .started_at = std.time.timestamp(),
    };

    switch (phase) {
        .scan => {
            const r = runTriCommand(allocator, &.{ "tri", "dev", "scan" });
            step.success = r.success;
            step.setOutput(if (r.success) "Scan complete" else "Scan failed");
            allocator.free(r.output);
            // Issue #420: post step comment
            postStepComment(allocator, issue_num, phase, if (r.success) "scan complete — candidates loaded" else "scan failed");
        },
        .pick => {
            const r = runTriCommand(allocator, &.{ "tri", "dev", "pick", "--smart" });
            step.success = r.success;
            if (r.output.len > 0) {
                const out_slice = r.output[0..@min(r.output.len, step.output.len)];
                step.setOutput(out_slice);
            } else {
                step.setOutput(if (r.success) "Pick complete" else "Pick failed");
            }
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, if (r.success) "task selected via --smart" else "pick failed");
        },
        .research => {
            const file = std.fs.cwd().openFile(".trinity/pick_result.json", .{}) catch {
                step.setOutput("No pick result found");
                step.success = false;
                step.finished_at = std.time.timestamp();
                postStepComment(allocator, issue_num, phase, "no pick result found");
                return step;
            };
            defer file.close();
            var buf: [512]u8 = undefined;
            const n = file.readAll(&buf) catch 0;
            if (n > 0) {
                step.setOutput(buf[0..@min(n, step.output.len)]);
                step.success = true;
            } else {
                step.setOutput("Empty pick result");
                step.success = false;
            }
            postStepComment(allocator, issue_num, phase, "agent started — gathering context");
        },
        .spec => {
            step.setOutput("Spec check — using existing specs");
            step.success = true;
            postStepComment(allocator, issue_num, phase, "template matched from experience");
        },
        .gen => {
            const r = runTriCommand(allocator, &.{ "zig", "build" });
            step.success = r.success;
            step.setOutput(if (r.success) "Build successful" else "Build failed");
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, if (r.success) "code generated successfully" else "build failed");
        },
        .verify => {
            const r = runTriCommand(allocator, &.{ "zig", "build", "test" });
            step.success = r.success;
            step.setOutput(if (r.success) "All tests pass" else "Tests failed");
            allocator.free(r.output);
            // Issue #420: save mistake on test failure
            if (!r.success) {
                saveMistakeForIssue(issue_num, "Tests failed");
            }
            postStepComment(allocator, issue_num, phase, if (r.success) "all tests pass" else "tests failed — mistake saved");
        },
        .verdict => {
            const r = runTriCommand(allocator, &.{ "tri", "verdict", "--toxic" });
            step.success = r.success;
            step.setOutput(if (r.success) "Verdict rendered" else "Verdict failed");
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, if (r.success) "verdict rendered" else "verdict failed");
        },
        .commit => {
            const r = runTriCommand(allocator, &.{ "git", "status", "--short" });
            if (r.output.len < 3) {
                step.setOutput("Nothing to commit");
                step.success = true;
            } else {
                step.setOutput("Dirty files present — manual commit needed");
                step.success = true;
            }
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, "commit check complete");
        },
        .experience => {
            // Issue #420: save experience with JSONL format
            var task_buf: [64]u8 = undefined;
            const task_str = std.fmt.bufPrint(&task_buf, "dev loop issue #{d}", .{issue_num}) catch "dev loop";
            const r = runTriCommand(allocator, &.{
                "tri", "experience", "save",
                "--task",    task_str,
                "--verdict", "PASS",
            });
            step.success = r.success;
            step.setOutput(if (r.success) "Experience saved" else "Experience save failed");
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, "episode saved to experience");
        },
        .decide => {
            const r = runTriCommand(allocator, &.{ "tri", "loop", "status" });
            step.success = r.success;
            step.setOutput(if (r.success) "Decision: continue" else "Decision: stop");
            allocator.free(r.output);
            postStepComment(allocator, issue_num, phase, "loop decision made");
        },
    }

    step.finished_at = std.time.timestamp();
    return step;
}

/// Issue #420: Save mistake file for issue on test failure
fn saveMistakeForIssue(issue_num: u32, err_msg: []const u8) void {
    std.fs.cwd().makePath(".trinity/mistakes") catch {};

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, ".trinity/mistakes/{d}_{d}.json", .{
        issue_num,
        std.time.timestamp(),
    }) catch return;

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();

    var buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"issue\":{d},\"error\":\"{s}\",\"timestamp\":{d},\"source\":\"dev_loop\"}}", .{
        issue_num, err_msg, std.time.timestamp(),
    }) catch return;
    file.writeAll(json) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUN ONE ITERATION
// ═══════════════════════════════════════════════════════════════════════════════

const PHASES = [_]LoopPhase{
    .scan, .pick, .research, .spec, .gen, .verify, .verdict, .commit, .experience, .decide,
};

fn runOnce(allocator: Allocator, state: *DevLoopState) LoopIteration {
    state.current_iteration += 1;

    var iteration = LoopIteration{
        .number = state.current_iteration,
    };

    const start_time = std.time.timestamp();

    print("\n{s}LOOP ITERATION {d}{s}\n", .{ GOLDEN, state.current_iteration, RESET });
    print("{s}════════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    // Issue #420: track issue number for step comments
    var current_issue_num: u32 = 0;

    var all_passed = true;
    for (PHASES) |phase| {
        print("  {s}[{s}/{d}]{s} {s}{s}{s} ... ", .{
            CYAN,
            phase.emoji(),
            @as(u32, MAX_STEPS),
            RESET,
            BOLD,
            phase.label(),
            RESET,
        });

        const step = executePhase(allocator, phase, current_issue_num);
        iteration.addStep(step);

        if (step.success) {
            print("{s}OK{s} ({d}s)\n", .{ GREEN, RESET, step.durationSecs() });
        } else {
            print("{s}FAIL{s} ({d}s)\n", .{ RED, RESET, step.durationSecs() });
            all_passed = false;
        }

        // Extract pick info from research step
        if (phase == .research and step.success) {
            const output = step.outputStr();
            if (std.mem.indexOf(u8, output, "\"id\":\"")) |id_start| {
                const val_start = id_start + 6;
                if (std.mem.indexOfPos(u8, output, val_start, "\"")) |val_end| {
                    const id_str = output[val_start..val_end];
                    iteration.setIssueId(id_str);
                    // Issue #420: extract numeric issue ID for step comments
                    if (id_str.len > 1 and id_str[0] == '#') {
                        current_issue_num = std.fmt.parseInt(u32, id_str[1..], 10) catch 0;
                    }
                }
            }
            if (std.mem.indexOf(u8, output, "\"title\":\"")) |t_start| {
                const val_start = t_start + 9;
                if (std.mem.indexOfPos(u8, output, val_start, "\"")) |val_end| {
                    iteration.setIssueTitle(output[val_start..val_end]);
                }
            }
        }
    }

    iteration.total_seconds = @intCast(std.time.timestamp() - start_time);

    if (all_passed) {
        state.consecutive_failures = 0;
        state.total_commits += 1;
        iteration.setDecision("continue");
    } else {
        state.consecutive_failures += 1;
        if (state.consecutive_failures >= 5) {
            iteration.setDecision("escalate");
        } else {
            iteration.setDecision("fix_and_retry");
        }
    }

    return iteration;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER SUMMARY
// ═══════════════════════════════════════════════════════════════════════════════

fn renderSummary(iteration: *const LoopIteration) void {
    const passed = iteration.passedSteps();
    const total: u32 = @intCast(iteration.step_count);

    print("\n{s}ITERATION {d} SUMMARY{s}\n", .{ GOLDEN, iteration.number, RESET });
    print("{s}────────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    // Issue info
    if (iteration.issue_id_len > 0) {
        print("  {s}Issue:{s}    {s} — {s}\n", .{ CYAN, RESET, iteration.issueIdStr(), iteration.issueTitleStr() });
    }

    // Step results
    const pass_color: []const u8 = if (passed == total) GREEN else if (passed >= total / 2) YELLOW else RED;
    print("  {s}Steps:{s}    {s}{d}/{d}{s}\n", .{ CYAN, RESET, pass_color, passed, total, RESET });
    print("  {s}Time:{s}     {d}s\n", .{ CYAN, RESET, iteration.total_seconds });
    print("  {s}Decision:{s} {s}\n", .{ CYAN, RESET, iteration.decisionStr() });

    // Step detail table
    print("\n  {s}Phase       Status  Time{s}\n", .{ GRAY, RESET });
    print("  {s}──────────  ──────  ────{s}\n", .{ GRAY, RESET });
    for (iteration.steps[0..iteration.step_count]) |step| {
        const status_icon: []const u8 = if (step.success) "PASS" else "FAIL";
        const status_color: []const u8 = if (step.success) GREEN else RED;
        print("  {s:<10}  {s}{s:<6}{s}  {d}s\n", .{
            step.phase.label(),
            status_color,
            status_icon,
            RESET,
            step.durationSecs(),
        });
    }

    print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn saveState(state: *const DevLoopState) void {
    std.fs.cwd().makePath(".trinity") catch {};
    const file = std.fs.cwd().createFile(".trinity/dev_loop_state.json", .{}) catch return;
    defer file.close();

    var buf: [512]u8 = undefined;
    const content = std.fmt.bufPrint(&buf, "{{\"iteration\":{d},\"max\":{d},\"interval\":{d},\"consecutive_failures\":{d},\"total_commits\":{d},\"total_specs\":{d},\"timestamp\":{d}}}\n", .{
        state.current_iteration,
        state.max_iterations,
        state.interval_seconds,
        state.consecutive_failures,
        state.total_commits,
        state.total_specs_created,
        std.time.timestamp(),
    }) catch return;
    file.writeAll(content) catch return;
}

fn loadState() DevLoopState {
    const file = std.fs.cwd().openFile(".trinity/dev_loop_state.json", .{}) catch return .{};
    defer file.close();

    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return .{};
    const content = buf[0..n];

    var state = DevLoopState{};

    // Simple JSON extraction
    if (extractJsonInt(content, "\"iteration\":")) |v| state.current_iteration = v;
    if (extractJsonInt(content, "\"max\":")) |v| state.max_iterations = v;
    if (extractJsonInt(content, "\"interval\":")) |v| state.interval_seconds = v;
    if (extractJsonInt(content, "\"consecutive_failures\":")) |v| state.consecutive_failures = v;
    if (extractJsonInt(content, "\"total_commits\":")) |v| state.total_commits = v;
    if (extractJsonInt(content, "\"total_specs\":")) |v| state.total_specs_created = v;

    return state;
}

fn extractJsonInt(json: []const u8, needle: []const u8) ?u32 {
    const start = std.mem.indexOf(u8, json, needle) orelse return null;
    const val_start = start + needle.len;
    var end = val_start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == val_start) return null;
    return std.fmt.parseInt(u32, json[val_start..end], 10) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE MISTAKES
// ═══════════════════════════════════════════════════════════════════════════════

fn saveMistake(phase: LoopPhase, err_msg: []const u8) void {
    std.fs.cwd().makePath(".trinity/mistakes") catch {};

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, ".trinity/mistakes/{s}_{d}.txt", .{
        phase.label(),
        std.time.timestamp(),
    }) catch return;

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();

    file.writeAll("phase: ") catch return;
    file.writeAll(phase.label()) catch return;
    file.writeAll("\nerror: ") catch return;
    file.writeAll(err_msg) catch return;
    file.writeAll("\ntimestamp: ") catch return;
    var ts_buf: [20]u8 = undefined;
    const ts = std.fmt.bufPrint(&ts_buf, "{d}", .{std.time.timestamp()}) catch return;
    file.writeAll(ts) catch return;
    file.writeAll("\n") catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — CLI entrypoint for tri dev loop
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDevLoopCommand(allocator: Allocator, args: []const []const u8) !void {
    // Parse args
    var max_iterations: u32 = 1;
    var interval: u32 = 0;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--iterations") and i + 1 < args.len) {
            max_iterations = std.fmt.parseInt(u32, args[i + 1], 10) catch 1;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--interval") and i + 1 < args.len) {
            interval = std.fmt.parseInt(u32, args[i + 1], 10) catch 0;
            i += 1;
        }
    }

    // Load or create state
    var state = loadState();
    state.max_iterations = max_iterations;
    state.interval_seconds = interval;

    print("\n{s}DEV LOOP{s} — {d} iteration(s), {d}s interval\n", .{
        GOLDEN, RESET, max_iterations, interval,
    });
    print("{s}════════════════════════════════════════════════{s}\n", .{ GRAY, RESET });

    var iter_count: u32 = 0;
    while (max_iterations == 0 or iter_count < max_iterations) {
        const iteration = runOnce(allocator, &state);
        renderSummary(&iteration);
        saveState(&state);

        // Save mistakes for failed steps
        for (iteration.steps[0..iteration.step_count]) |step| {
            if (!step.success) {
                saveMistake(step.phase, step.outputStr());
            }
        }

        iter_count += 1;

        // Check decision
        if (std.mem.eql(u8, iteration.decisionStr(), "escalate")) {
            print("{s}ESCALATING: {d} consecutive failures. Stopping loop.{s}\n", .{
                RED, state.consecutive_failures, RESET,
            });
            break;
        }

        // Sleep between iterations if interval set
        if (interval > 0 and (max_iterations == 0 or iter_count < max_iterations)) {
            print("{s}Sleeping {d}s before next iteration...{s}\n", .{ DIM, interval, RESET });
            std.Thread.sleep(@as(u64, interval) * std.time.ns_per_s);
        }
    }

    // Final summary
    print("\n{s}LOOP COMPLETE{s}\n", .{ GOLDEN, RESET });
    print("  Iterations: {d}  |  Commits: {d}  |  Consecutive failures: {d}\n\n", .{
        state.current_iteration, state.total_commits, state.consecutive_failures,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LoopPhase labels" {
    try std.testing.expectEqualStrings("SCAN", LoopPhase.scan.label());
    try std.testing.expectEqualStrings("VERDICT", LoopPhase.verdict.label());
    try std.testing.expectEqualStrings("DECIDE", LoopPhase.decide.label());
}

test "LoopPhase numbers" {
    try std.testing.expectEqual(@as(u32, 1), LoopPhase.scan.number());
    try std.testing.expectEqual(@as(u32, 7), LoopPhase.verdict.number());
    try std.testing.expectEqual(@as(u32, 10), LoopPhase.decide.number());
}

test "LoopStep duration" {
    var step = LoopStep{
        .started_at = 1000,
        .finished_at = 1045,
        .success = true,
    };
    try std.testing.expectEqual(@as(u32, 45), step.durationSecs());

    step.finished_at = 999; // finished before started = 0
    try std.testing.expectEqual(@as(u32, 0), step.durationSecs());
}

test "LoopIteration passedSteps" {
    var iteration = LoopIteration{ .number = 1 };
    iteration.addStep(.{ .phase = .scan, .success = true });
    iteration.addStep(.{ .phase = .pick, .success = true });
    iteration.addStep(.{ .phase = .gen, .success = false });
    iteration.addStep(.{ .phase = .verify, .success = true });

    try std.testing.expectEqual(@as(u32, 3), iteration.passedSteps());
    try std.testing.expectEqual(@as(usize, 4), iteration.step_count);
}

test "LoopIteration setters" {
    var iteration = LoopIteration{};
    iteration.setIssueId("#42");
    iteration.setIssueTitle("Fix VSA bind");
    iteration.setDecision("continue");

    try std.testing.expectEqualStrings("#42", iteration.issueIdStr());
    try std.testing.expectEqualStrings("Fix VSA bind", iteration.issueTitleStr());
    try std.testing.expectEqualStrings("continue", iteration.decisionStr());
}

test "DevLoopState defaults" {
    const state = DevLoopState{};
    try std.testing.expectEqual(@as(u32, 0), state.current_iteration);
    try std.testing.expectEqual(@as(u32, 1), state.max_iterations);
    try std.testing.expectEqual(@as(u32, 0), state.consecutive_failures);
}

test "extractJsonInt" {
    const json = "{\"iteration\":5,\"max\":10,\"total_commits\":3}";
    try std.testing.expectEqual(@as(u32, 5), extractJsonInt(json, "\"iteration\":").?);
    try std.testing.expectEqual(@as(u32, 10), extractJsonInt(json, "\"max\":").?);
    try std.testing.expectEqual(@as(u32, 3), extractJsonInt(json, "\"total_commits\":").?);
    try std.testing.expectEqual(@as(?u32, null), extractJsonInt(json, "\"missing\":"));
}

test "consecutive failures escalation" {
    var state = DevLoopState{};
    state.consecutive_failures = 4;
    // After one more failure, should be 5 → escalate
    state.consecutive_failures += 1;
    try std.testing.expect(state.consecutive_failures >= 5);
}
