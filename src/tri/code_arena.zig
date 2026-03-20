// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// CODE ARENA — Self-Referential Code Battle Platform
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pits vanilla Claude Code against the tri pipeline on real Trinity tasks.
// Automatic judging: build, tests, diff size, speed, toxic verdict.
// Results → JSONL, ELO tracked per contestant.
//
// Commands:
//   tri code arena battle "task"      Run one battle
//   tri code arena leaderboard        Show ELO + win/loss
//   tri code arena tasks              List pilot task catalog
//   tri code arena history            Recent battle outcomes
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");
const toxic_verdict = @import("pathology.zig");

const print = std.debug.print;

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;
const YELLOW = "\x1b[33m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

const RESULTS_PATH = ".trinity/code_arena/results.jsonl";
const ELO_PATH = ".trinity/code_arena/elo.json";
const DEFAULT_TIMEOUT_MS: u64 = 300_000; // 5 minutes

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Contestant = enum {
    baseline,
    gladiator,

    pub fn label(self: Contestant) []const u8 {
        return switch (self) {
            .baseline => "Baseline",
            .gladiator => "Gladiator",
        };
    }

    pub fn key(self: Contestant) []const u8 {
        return switch (self) {
            .baseline => "baseline",
            .gladiator => "gladiator",
        };
    }
};

pub const BattleResult = struct {
    build_ok: bool = false,
    test_ok: bool = false,
    test_count: u32 = 0,
    diff_lines: u32 = 0,
    elapsed_ms: u64 = 0,
    toxic_score: f32 = 0.0,
    total_score: f32 = 0.0,
};

pub const Winner = enum {
    baseline,
    gladiator,
    tie,

    pub fn label(self: Winner) []const u8 {
        return switch (self) {
            .baseline => "BASELINE",
            .gladiator => "GLADIATOR",
            .tie => "TIE",
        };
    }
};

pub const BattleOutcome = struct {
    task: []const u8,
    baseline: BattleResult,
    gladiator: BattleResult,
    winner: Winner,
    timestamp: i64,
};

pub const Difficulty = enum {
    easy,
    medium,
    hard,

    pub fn label(self: Difficulty) []const u8 {
        return switch (self) {
            .easy => "Easy",
            .medium => "Medium",
            .hard => "Hard",
        };
    }
};

pub const CodeArenaTask = struct {
    id: []const u8,
    task: []const u8,
    difficulty: Difficulty,
};

pub const EloState = struct {
    baseline: f64 = 1000.0,
    gladiator: f64 = 1000.0,
    total_battles: u32 = 0,
    baseline_wins: u32 = 0,
    gladiator_wins: u32 = 0,
    ties: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PILOT TASKS
// ═══════════════════════════════════════════════════════════════════════════════

const PILOT_TASKS = [_]CodeArenaTask{
    .{ .id = "CA-01", .task = "Add --json output to tri train dashboard", .difficulty = .medium },
    .{ .id = "CA-02", .task = "Implement tri farm evolve resume --top-k N", .difficulty = .medium },
    .{ .id = "CA-03", .task = "Add diversity quota config to SEVO inject", .difficulty = .medium },
    .{ .id = "CA-04", .task = "Fix: dashboard should show phi_restart and wsd in Schedule column", .difficulty = .easy },
    .{ .id = "CA-05", .task = "Add SEVO method section to papers/sevo-method.md", .difficulty = .hard },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCodeArenaCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "battle")) {
        return runBattleCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "leaderboard")) {
        return showLeaderboard();
    } else if (std.mem.eql(u8, subcmd, "tasks")) {
        return showTasks();
    } else if (std.mem.eql(u8, subcmd, "history")) {
        return showHistory(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn printHelp() void {
    print("\n{s}{s}CODE ARENA{s} — Self-Referential Code Battle Platform\n\n", .{ BOLD, GOLDEN, RESET });
    print("  {s}tri code arena battle \"task\"{s}    Run one battle\n", .{ CYAN, RESET });
    print("  {s}tri code arena battle CA-01{s}      Run pilot task by ID\n", .{ CYAN, RESET });
    print("  {s}tri code arena leaderboard{s}       Show ELO + win/loss\n", .{ CYAN, RESET });
    print("  {s}tri code arena tasks{s}             List pilot task catalog\n", .{ CYAN, RESET });
    print("  {s}tri code arena history{s}           Recent battle outcomes\n", .{ CYAN, RESET });
    print("\n  Options:\n", .{});
    print("    {s}--dry-run{s}     Show plan without executing\n", .{ DIM, RESET });
    print("    {s}--timeout N{s}   Timeout in seconds (default: 300)\n", .{ DIM, RESET });
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TASKS CATALOG
// ═══════════════════════════════════════════════════════════════════════════════

fn showTasks() void {
    print("\n{s}{s}CODE ARENA — Pilot Tasks{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("\n", .{});
    for (PILOT_TASKS) |task| {
        const diff_color = switch (task.difficulty) {
            .easy => GREEN,
            .medium => YELLOW,
            .hard => RED,
        };
        print("  {s}{s}{s}  [{s}{s}{s}]  {s}\n", .{
            CYAN,       task.id,                 RESET,
            diff_color, task.difficulty.label(), RESET,
            task.task,
        });
    }
    print("\n  {s}Run: tri code arena battle CA-01{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATTLE ORCHESTRATION
// ═══════════════════════════════════════════════════════════════════════════════

fn runBattleCommand(allocator: Allocator, args: []const []const u8) !void {
    var task_desc: ?[]const u8 = null;
    var timeout_ms: u64 = DEFAULT_TIMEOUT_MS;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--timeout")) {
            i += 1;
            if (i < args.len) {
                const secs = std.fmt.parseInt(u64, args[i], 10) catch 300;
                timeout_ms = secs * 1000;
            }
        } else if (task_desc == null) {
            // Check if it's a pilot task ID
            task_desc = resolvePilotTask(args[i]) orelse args[i];
        }
    }

    if (task_desc == null) {
        print("{s}Error: no task description provided{s}\n", .{ RED, RESET });
        print("Usage: tri code arena battle \"task description\"\n", .{});
        return;
    }

    if (dry_run) {
        printDryRun(task_desc.?);
        return;
    }

    try runBattle(allocator, task_desc.?, timeout_ms);
}

fn resolvePilotTask(id: []const u8) ?[]const u8 {
    for (PILOT_TASKS) |task| {
        if (std.mem.eql(u8, id, task.id)) return task.task;
    }
    return null;
}

fn printDryRun(task: []const u8) void {
    print("\n{s}{s}CODE ARENA — Dry Run{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("\n  {s}Task:{s} {s}\n", .{ BOLD, RESET, task });
    print("\n  {s}Plan:{s}\n", .{ BOLD, RESET });
    print("    1. Stash uncommitted changes\n", .{});
    print("    2. Create branch {s}arena-<ts>-baseline{s} from main\n", .{ CYAN, RESET });
    print("    3. Run: {s}claude --dangerously-skip-permissions \"{s}\"{s}\n", .{ DIM, task, RESET });
    print("    4. Judge baseline (build/test/diff/toxic)\n", .{});
    print("    5. Create branch {s}arena-<ts>-gladiator{s} from main\n", .{ CYAN, RESET });
    print("    6. Run: {s}tri pipeline run \"{s}\"{s}\n", .{ DIM, task, RESET });
    print("    7. Judge gladiator (build/test/diff/toxic)\n", .{});
    print("    8. Compare scores, update ELO\n", .{});
    print("    9. Append result to {s}{s}{s}\n", .{ DIM, RESULTS_PATH, RESET });
    print("   10. Restore original branch + stash\n", .{});
    print("\n  {s}No actions taken.{s}\n\n", .{ GRAY, RESET });
}

fn runBattle(allocator: Allocator, task: []const u8, timeout_ms: u64) !void {
    const timestamp = std.time.timestamp();

    // Format branch names
    var base_branch_buf: [64]u8 = undefined;
    const base_branch = std.fmt.bufPrint(&base_branch_buf, "arena-{d}-baseline", .{timestamp}) catch "arena-baseline";
    var glad_branch_buf: [64]u8 = undefined;
    const glad_branch = std.fmt.bufPrint(&glad_branch_buf, "arena-{d}-gladiator", .{timestamp}) catch "arena-gladiator";

    print("\n{s}{s}CODE ARENA — Battle Starting{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("  {s}Task:{s} {s}\n", .{ BOLD, RESET, task });
    print("  {s}Timeout:{s} {d}s\n\n", .{ BOLD, RESET, timeout_ms / 1000 });

    // Save current branch
    const orig_branch = getCurrentBranch(allocator) orelse "main";

    // Stash uncommitted changes
    _ = runGitCommand(allocator, &.{ "git", "stash", "push", "-m", "code-arena-save" });

    // === BASELINE ===
    print("  {s}[1/4]{s} Running {s}BASELINE{s} (claude)...\n", .{ CYAN, RESET, BOLD, RESET });
    _ = runGitCommand(allocator, &.{ "git", "checkout", "-b", base_branch, "main" });
    const base_elapsed = spawnContestant(allocator, .baseline, task, timeout_ms);
    const base_result = judgeContestant(allocator, base_branch, base_elapsed, timeout_ms);

    // === GLADIATOR ===
    print("  {s}[2/4]{s} Running {s}GLADIATOR{s} (tri pipeline)...\n", .{ CYAN, RESET, BOLD, RESET });
    _ = runGitCommand(allocator, &.{ "git", "checkout", "main" });
    _ = runGitCommand(allocator, &.{ "git", "checkout", "-b", glad_branch, "main" });
    const glad_elapsed = spawnContestant(allocator, .gladiator, task, timeout_ms);
    const glad_result = judgeContestant(allocator, glad_branch, glad_elapsed, timeout_ms);

    // === JUDGE ===
    print("  {s}[3/4]{s} Judging...\n", .{ CYAN, RESET });
    const winner: Winner = if (base_result.total_score > glad_result.total_score + 0.01)
        .baseline
    else if (glad_result.total_score > base_result.total_score + 0.01)
        .gladiator
    else
        .tie;

    const outcome = BattleOutcome{
        .task = task,
        .baseline = base_result,
        .gladiator = glad_result,
        .winner = winner,
        .timestamp = timestamp,
    };

    // Update ELO
    var elo = readEloState();
    const elo_result = updateElo(elo.baseline, elo.gladiator, winner);
    elo.baseline = elo_result[0];
    elo.gladiator = elo_result[1];
    elo.total_battles += 1;
    switch (winner) {
        .baseline => elo.baseline_wins += 1,
        .gladiator => elo.gladiator_wins += 1,
        .tie => elo.ties += 1,
    }
    writeEloState(elo);

    // Persist result
    appendResult(outcome);

    // === CLEANUP ===
    print("  {s}[4/4]{s} Cleaning up...\n", .{ CYAN, RESET });
    _ = runGitCommand(allocator, &.{ "git", "checkout", orig_branch });
    _ = runGitCommand(allocator, &.{ "git", "branch", "-D", base_branch });
    _ = runGitCommand(allocator, &.{ "git", "branch", "-D", glad_branch });
    _ = runGitCommand(allocator, &.{ "git", "stash", "pop" });

    // === VERDICT ===
    printVerdict(outcome, elo);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTESTANT SPAWNING
// ═══════════════════════════════════════════════════════════════════════════════

fn spawnContestant(allocator: Allocator, contestant: Contestant, task: []const u8, timeout_ms: u64) u64 {
    const start = std.time.milliTimestamp();

    const argv: []const []const u8 = switch (contestant) {
        .baseline => &.{ "claude", "--dangerously-skip-permissions", "-p", task },
        .gladiator => &.{ "zig-out/bin/tri-api", "--task", task },
    };

    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = child.spawn() catch {
        print("    {s}Failed to spawn {s}{s}\n", .{ RED, contestant.label(), RESET });
        return 0;
    };

    // Wait for completion (timeout enforced externally if needed)
    _ = timeout_ms;
    const term = child.wait() catch {
        print("    {s}{s} wait failed{s}\n", .{ YELLOW, contestant.label(), RESET });
        return 0;
    };

    const ok = switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
    if (!ok) {
        print("    {s}{s} exited with error{s}\n", .{ YELLOW, contestant.label(), RESET });
    }

    const elapsed: u64 = @intCast(@max(0, std.time.milliTimestamp() - start));
    return elapsed;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JUDGING
// ═══════════════════════════════════════════════════════════════════════════════

fn judgeContestant(allocator: Allocator, branch: []const u8, elapsed_ms: u64, timeout_ms: u64) BattleResult {
    // Ensure we're on the right branch
    _ = runGitCommand(allocator, &.{ "git", "checkout", branch });

    // Build check
    const build_ok = runCheck(allocator, &.{ "zig", "build" });

    // Test check
    var test_ok = false;
    var test_count: u32 = 0;
    if (build_ok) {
        const test_result = runCheckWithOutput(allocator, &.{ "zig", "build", "test" });
        test_ok = test_result.ok;
        test_count = countTestPasses(test_result.output);
    }

    // Diff size
    const diff_lines = getDiffLines(allocator);

    // Toxic verdict score
    const toxic_input = toxic_verdict.collectInputs(allocator);
    const toxic_score_val = toxic_verdict.computeScore(toxic_input);
    const toxic_total = toxic_score_val.total;

    // Compute total
    const result = BattleResult{
        .build_ok = build_ok,
        .test_ok = test_ok,
        .test_count = test_count,
        .diff_lines = diff_lines,
        .elapsed_ms = elapsed_ms,
        .toxic_score = toxic_total,
        .total_score = computeScore(build_ok, test_ok, test_count, diff_lines, elapsed_ms, timeout_ms, toxic_total),
    };

    return result;
}

fn computeScore(build_ok: bool, test_ok: bool, test_count: u32, diff_lines: u32, elapsed_ms: u64, timeout_ms: u64, toxic_total: f32) f32 {
    const build_score: f32 = if (build_ok) 1.0 else 0.0;
    const test_score: f32 = if (test_ok) @min(1.0, @as(f32, @floatFromInt(test_count)) / 5.0) else 0.0;

    const diff_f: f32 = @floatFromInt(diff_lines + 1);
    const brevity: f32 = 1.0 / (1.0 + @log(diff_f) / @log(@as(f32, 1000.0)));

    const elapsed_f: f32 = @floatFromInt(elapsed_ms);
    const timeout_f: f32 = @floatFromInt(timeout_ms);
    const speed: f32 = 1.0 / (1.0 + elapsed_f / timeout_f);

    const health: f32 = toxic_total / 100.0;

    return 0.30 * build_score + 0.25 * test_score + 0.10 * brevity + 0.10 * speed + 0.25 * health;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GIT + PROCESS HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn getCurrentBranch(allocator: Allocator) ?[]const u8 {
    var child = std.process.Child.init(&.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    _ = child.spawn() catch return null;

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stdout_buf.deinit(allocator);
    defer stderr_buf.deinit(allocator);
    child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1024) catch return null;
    const term = child.wait() catch return null;
    switch (term) {
        .Exited => |code| if (code != 0) return null,
        else => return null,
    }

    const out = stdout_buf.items;
    if (out.len > 0 and out[out.len - 1] == '\n') {
        return out[0 .. out.len - 1];
    }
    return if (out.len > 0) out else null;
}

pub fn runGitCommand(allocator: Allocator, argv: []const []const u8) bool {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch return false;
    const term = child.wait() catch return false;
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn runCheck(allocator: Allocator, argv: []const []const u8) bool {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch return false;
    const term = child.wait() catch return false;
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

const CheckOutput = struct {
    ok: bool,
    output: []const u8,
};

fn runCheckWithOutput(allocator: Allocator, argv: []const []const u8) CheckOutput {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    _ = child.spawn() catch return .{ .ok = false, .output = "" };

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    child.collectOutput(allocator, &stdout_buf, &stderr_buf, 4 * 1024 * 1024) catch return .{ .ok = false, .output = "" };
    const term = child.wait() catch return .{ .ok = false, .output = "" };

    const ok = switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };

    // Combine stdout+stderr for test output parsing
    const output = if (stdout_buf.items.len > 0) stdout_buf.items else stderr_buf.items;
    return .{ .ok = ok, .output = output };
}

fn countTestPasses(output: []const u8) u32 {
    var count: u32 = 0;
    var it = std.mem.splitScalar(u8, output, '\n');
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, "pass") != null or
            std.mem.indexOf(u8, line, "PASS") != null or
            std.mem.indexOf(u8, line, "1/1") != null)
        {
            count += 1;
        }
    }
    return if (count == 0 and output.len > 0) 1 else count;
}

fn getDiffLines(allocator: Allocator) u32 {
    var child = std.process.Child.init(&.{ "git", "diff", "main", "--stat" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    _ = child.spawn() catch return 0;

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf2: std.ArrayList(u8) = .empty;
    defer stderr_buf2.deinit(allocator);
    child.collectOutput(allocator, &stdout_buf, &stderr_buf2, 64 * 1024) catch return 0;
    _ = child.wait() catch return 0;

    // Parse last line: " N files changed, X insertions(+), Y deletions(-)"
    const out = stdout_buf.items;
    if (out.len == 0) return 0;

    var total: u32 = 0;
    var it = std.mem.splitScalar(u8, out, '\n');
    while (it.next()) |line| {
        // Count lines with "|" which show per-file changes
        if (std.mem.indexOf(u8, line, "|") != null) {
            total += 1;
        }
    }
    // Use number of changed files as proxy; each typically has multiple lines
    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ELO
// ═══════════════════════════════════════════════════════════════════════════════

const K_FACTOR: f64 = 32.0;

fn expectedScore(rating_a: f64, rating_b: f64) f64 {
    return 1.0 / (1.0 + std.math.pow(f64, 10.0, (rating_b - rating_a) / 400.0));
}

fn updateElo(baseline_elo: f64, gladiator_elo: f64, winner: Winner) struct { f64, f64 } {
    const ea = expectedScore(baseline_elo, gladiator_elo);
    const eb = 1.0 - ea;

    const sa: f64 = switch (winner) {
        .baseline => 1.0,
        .gladiator => 0.0,
        .tie => 0.5,
    };
    const sb: f64 = 1.0 - sa;

    return .{
        baseline_elo + K_FACTOR * (sa - ea),
        gladiator_elo + K_FACTOR * (sb - eb),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn readEloState() EloState {
    const file = std.fs.cwd().openFile(ELO_PATH, .{}) catch return EloState{};
    defer file.close();

    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return EloState{};
    const content = buf[0..n];

    // Minimal JSON parse for our known fields
    var state = EloState{};
    state.baseline = parseJsonFloat(content, "\"baseline\":") orelse 1000.0;
    state.gladiator = parseJsonFloat(content, "\"gladiator\":") orelse 1000.0;
    state.total_battles = parseJsonU32(content, "\"total_battles\":") orelse 0;
    state.baseline_wins = parseJsonU32(content, "\"baseline_wins\":") orelse 0;
    state.gladiator_wins = parseJsonU32(content, "\"gladiator_wins\":") orelse 0;
    state.ties = parseJsonU32(content, "\"ties\":") orelse 0;
    return state;
}

fn writeEloState(state: EloState) void {
    std.fs.cwd().makePath(".trinity/code_arena") catch {};
    const file = std.fs.cwd().createFile(ELO_PATH, .{}) catch return;
    defer file.close();

    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&buf,
        \\{{"baseline":{d:.1},"gladiator":{d:.1},"total_battles":{d},"baseline_wins":{d},"gladiator_wins":{d},"ties":{d}}}
    , .{
        state.baseline,
        state.gladiator,
        state.total_battles,
        state.baseline_wins,
        state.gladiator_wins,
        state.ties,
    }) catch return;

    file.writeAll(json) catch {};
    file.writeAll("\n") catch {};
}

fn appendResult(outcome: BattleOutcome) void {
    std.fs.cwd().makePath(".trinity/code_arena") catch {};

    const file = std.fs.cwd().openFile(RESULTS_PATH, .{ .mode = .read_write }) catch
        std.fs.cwd().createFile(RESULTS_PATH, .{}) catch return;
    defer file.close();

    const stat = file.stat() catch return;
    file.seekTo(stat.size) catch {};

    var buf: [2048]u8 = undefined;
    const line = std.fmt.bufPrint(&buf,
        \\{{"task":"{s}","winner":"{s}","timestamp":{d},"baseline":{{"build":{s},"test":{s},"test_count":{d},"diff":{d},"ms":{d},"toxic":{d:.1},"score":{d:.3}}},"gladiator":{{"build":{s},"test":{s},"test_count":{d},"diff":{d},"ms":{d},"toxic":{d:.1},"score":{d:.3}}}}}
    , .{
        outcome.task,
        outcome.winner.label(),
        outcome.timestamp,
        if (outcome.baseline.build_ok) "true" else "false",
        if (outcome.baseline.test_ok) "true" else "false",
        outcome.baseline.test_count,
        outcome.baseline.diff_lines,
        outcome.baseline.elapsed_ms,
        outcome.baseline.toxic_score,
        outcome.baseline.total_score,
        if (outcome.gladiator.build_ok) "true" else "false",
        if (outcome.gladiator.test_ok) "true" else "false",
        outcome.gladiator.test_count,
        outcome.gladiator.diff_lines,
        outcome.gladiator.elapsed_ms,
        outcome.gladiator.toxic_score,
        outcome.gladiator.total_score,
    }) catch return;

    file.writeAll(line) catch {};
    file.writeAll("\n") catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISPLAY
// ═══════════════════════════════════════════════════════════════════════════════

fn printVerdict(outcome: BattleOutcome, elo: EloState) void {
    const battle_num = elo.total_battles;

    print("\n{s}{s}CODE ARENA — Battle #{d}{s}\n", .{ BOLD, GOLDEN, battle_num, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("  {s}Task:{s} {s}\n\n", .{ BOLD, RESET, outcome.task });

    // Header
    print("  {s}Metric       {s}| {s}Baseline{s} | {s}Gladiator{s}\n", .{ BOLD, RESET, CYAN, RESET, GREEN, RESET });
    print("  {s}─────────────┼──────────┼──────────{s}\n", .{ DIM, RESET });

    // Build
    const b_build = if (outcome.baseline.build_ok) GREEN ++ "   OK   " ++ RESET else RED ++ "  FAIL  " ++ RESET;
    const g_build = if (outcome.gladiator.build_ok) GREEN ++ "   OK   " ++ RESET else RED ++ "  FAIL  " ++ RESET;
    print("  Build        | {s} | {s}\n", .{ b_build, g_build });

    // Tests
    print("  Tests        |   {d:>4}   |   {d:>4}\n", .{ outcome.baseline.test_count, outcome.gladiator.test_count });

    // Diff
    print("  Diff lines   |   {d:>4}   |   {d:>4}\n", .{ outcome.baseline.diff_lines, outcome.gladiator.diff_lines });

    // Time
    print("  Time (s)     |   {d:>4}   |   {d:>4}\n", .{ outcome.baseline.elapsed_ms / 1000, outcome.gladiator.elapsed_ms / 1000 });

    // Toxic
    print("  Health       | {d:>6.1}  | {d:>6.1}\n", .{ outcome.baseline.toxic_score, outcome.gladiator.toxic_score });

    print("  {s}─────────────┼──────────┼──────────{s}\n", .{ DIM, RESET });
    print("  {s}TOTAL{s}        | {d:>6.3}  | {d:>6.3}\n", .{ BOLD, RESET, outcome.baseline.total_score, outcome.gladiator.total_score });

    // Winner
    const delta = if (outcome.gladiator.total_score > outcome.baseline.total_score)
        outcome.gladiator.total_score - outcome.baseline.total_score
    else
        outcome.baseline.total_score - outcome.gladiator.total_score;

    const winner_color = switch (outcome.winner) {
        .baseline => CYAN,
        .gladiator => GREEN,
        .tie => YELLOW,
    };
    print("\n  {s}{s}WINNER: {s} (+{d:.3}){s}\n", .{ BOLD, winner_color, outcome.winner.label(), delta, RESET });

    // ELO
    var base_elo_buf: [16]u8 = undefined;
    var glad_elo_buf: [16]u8 = undefined;
    const base_elo_str = std.fmt.bufPrint(&base_elo_buf, "{d:.0}", .{elo.baseline}) catch "???";
    const glad_elo_str = std.fmt.bufPrint(&glad_elo_buf, "{d:.0}", .{elo.gladiator}) catch "???";
    print("  ELO: Baseline {s} | Gladiator {s}\n\n", .{ base_elo_str, glad_elo_str });
}

fn showLeaderboard() void {
    const elo = readEloState();

    print("\n{s}{s}CODE ARENA — Leaderboard{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });

    if (elo.total_battles == 0) {
        print("\n  {s}No battles yet. Run: tri code arena battle \"task\"{s}\n\n", .{ GRAY, RESET });
        return;
    }

    print("\n  {s}Contestant{s}  | {s}ELO{s}  | {s}W{s} | {s}L{s} | {s}T{s} | {s}Total{s}\n", .{
        BOLD,   RESET, BOLD, RESET,
        GREEN,  RESET, RED,  RESET,
        YELLOW, RESET, DIM,  RESET,
    });
    print("  {s}────────────┼───────┼───┼───┼───┼──────{s}\n", .{ DIM, RESET });

    var base_buf: [16]u8 = undefined;
    var glad_buf: [16]u8 = undefined;
    const base_elo = std.fmt.bufPrint(&base_buf, "{d:.0}", .{elo.baseline}) catch "???";
    const glad_elo = std.fmt.bufPrint(&glad_buf, "{d:.0}", .{elo.gladiator}) catch "???";

    const base_losses = elo.gladiator_wins;
    const glad_losses = elo.baseline_wins;
    const base_total = elo.baseline_wins + base_losses + elo.ties;
    const glad_total = elo.gladiator_wins + glad_losses + elo.ties;

    print("  {s}Baseline{s}    | {s:>5} | {d:<1} | {d:<1} | {d:<1} | {d}\n", .{
        CYAN, RESET, base_elo, elo.baseline_wins, base_losses, elo.ties, base_total,
    });
    print("  {s}Gladiator{s}   | {s:>5} | {d:<1} | {d:<1} | {d:<1} | {d}\n", .{
        GREEN, RESET, glad_elo, elo.gladiator_wins, glad_losses, elo.ties, glad_total,
    });
    print("\n  {s}Total battles: {d}{s}\n\n", .{ DIM, elo.total_battles, RESET });
}

fn showHistory(allocator: Allocator) void {
    const file = std.fs.cwd().openFile(RESULTS_PATH, .{}) catch {
        print("\n  {s}No battle history. Run: tri code arena battle \"task\"{s}\n\n", .{ GRAY, RESET });
        return;
    };
    defer file.close();

    var buf: [16384]u8 = undefined;
    const n = file.readAll(&buf) catch return;
    const content = buf[0..n];

    print("\n{s}{s}CODE ARENA — Battle History{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    var line_num: u32 = 0;
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        if (line.len < 10) continue;
        line_num += 1;

        // Extract winner and task from JSON line
        const winner_str = extractJsonStr(line, "\"winner\":\"") orelse "???";
        const task_str = extractJsonStr(line, "\"task\":\"") orelse "???";

        const icon = if (std.mem.eql(u8, winner_str, "GLADIATOR"))
            GREEN ++ "G" ++ RESET
        else if (std.mem.eql(u8, winner_str, "BASELINE"))
            CYAN ++ "B" ++ RESET
        else
            YELLOW ++ "T" ++ RESET;

        // Truncate task to 50 chars
        const task_display = if (task_str.len > 50) task_str[0..50] else task_str;
        _ = allocator;

        print("  #{d:<3} [{s}] {s}\n", .{ line_num, icon, task_display });
    }

    if (line_num == 0) {
        print("  {s}No battles recorded.{s}\n", .{ GRAY, RESET });
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS (minimal, no allocations)
// ═══════════════════════════════════════════════════════════════════════════════

fn parseJsonFloat(content: []const u8, key: []const u8) ?f64 {
    const idx = std.mem.indexOf(u8, content, key) orelse return null;
    const start = idx + key.len;
    var end = start;
    while (end < content.len and content[end] != ',' and content[end] != '}') : (end += 1) {}
    return std.fmt.parseFloat(f64, content[start..end]) catch null;
}

fn parseJsonU32(content: []const u8, key: []const u8) ?u32 {
    const idx = std.mem.indexOf(u8, content, key) orelse return null;
    const start = idx + key.len;
    var end = start;
    while (end < content.len and content[end] != ',' and content[end] != '}') : (end += 1) {}
    return std.fmt.parseInt(u32, content[start..end], 10) catch null;
}

fn extractJsonStr(content: []const u8, prefix: []const u8) ?[]const u8 {
    const idx = std.mem.indexOf(u8, content, prefix) orelse return null;
    const start = idx + prefix.len;
    const end_quote = std.mem.indexOfScalarPos(u8, content, start, '"') orelse return null;
    return content[start..end_quote];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "compute score perfect build and tests" {
    const score = computeScore(true, true, 5, 50, 30_000, 300_000, 80.0);
    // build=0.30, test=0.25, brevity~0.10*0.63, speed~0.10*0.91, health=0.25*0.80
    try std.testing.expect(score > 0.7);
    try std.testing.expect(score <= 1.0);
}

test "compute score failed build" {
    const score = computeScore(false, false, 0, 0, 300_000, 300_000, 0.0);
    // build=0, test=0, brevity=0.10*1.0 (no diff), speed=0.10*0.5, health=0
    // total = 0.10 + 0.05 = 0.15
    try std.testing.expect(score < 0.20);
    try std.testing.expect(score > 0.0);
}

test "elo update baseline wins" {
    const result = updateElo(1000.0, 1000.0, .baseline);
    try std.testing.expect(result[0] > 1000.0);
    try std.testing.expect(result[1] < 1000.0);
    // Total conserved
    try std.testing.expectApproxEqAbs(@as(f64, 2000.0), result[0] + result[1], 0.001);
}

test "elo update tie no change" {
    const result = updateElo(1000.0, 1000.0, .tie);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), result[0], 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), result[1], 0.1);
}

test "pilot task resolve" {
    const task = resolvePilotTask("CA-01");
    try std.testing.expect(task != null);
    try std.testing.expect(std.mem.indexOf(u8, task.?, "json") != null);

    const unknown = resolvePilotTask("XX-99");
    try std.testing.expect(unknown == null);
}

test "extract json string" {
    const json = "{\"winner\":\"GLADIATOR\",\"task\":\"add feature\"}";
    const winner = extractJsonStr(json, "\"winner\":\"");
    try std.testing.expect(winner != null);
    try std.testing.expectEqualStrings("GLADIATOR", winner.?);
}

test "count test passes" {
    const output = "test 1/1 pass\ntest 2/2 PASS\nother line\n";
    const count = countTestPasses(output);
    try std.testing.expect(count >= 2);
}

test "Contestant all values" {
    // Verify both enum values exist and can be referenced
    const baseline = Contestant.baseline;
    const gladiator = Contestant.gladiator;
    _ = baseline;
    _ = gladiator;
}

test "Contestant label all values" {
    try std.testing.expectEqualStrings("Baseline", Contestant.baseline.label());
    try std.testing.expectEqualStrings("Gladiator", Contestant.gladiator.label());
}

test "Contestant key all values" {
    try std.testing.expectEqualStrings("baseline", Contestant.baseline.key());
    try std.testing.expectEqualStrings("gladiator", Contestant.gladiator.key());
}

test "Winner all values" {
    const winners = [_]Winner{ .baseline, .gladiator, .tie };
    for (winners) |w| {
        _ = w; // Verify all exist
    }
}

test "Winner label all values" {
    try std.testing.expectEqualStrings("BASELINE", Winner.baseline.label());
    try std.testing.expectEqualStrings("GLADIATOR", Winner.gladiator.label());
    try std.testing.expectEqualStrings("TIE", Winner.tie.label());
}

test "Difficulty all values" {
    const difficulties = [_]Difficulty{ .easy, .medium, .hard };
    for (difficulties) |d| {
        _ = d; // Verify all exist
    }
}

test "Difficulty label all values" {
    try std.testing.expectEqualStrings("Easy", Difficulty.easy.label());
    try std.testing.expectEqualStrings("Medium", Difficulty.medium.label());
    try std.testing.expectEqualStrings("Hard", Difficulty.hard.label());
}

test "BattleResult default values" {
    const result = BattleResult{};
    try std.testing.expect(!result.build_ok);
    try std.testing.expect(!result.test_ok);
    try std.testing.expectEqual(@as(u32, 0), result.test_count);
    try std.testing.expectEqual(@as(u32, 0), result.diff_lines);
    try std.testing.expectEqual(@as(u64, 0), result.elapsed_ms);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.toxic_score, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.total_score, 0.01);
}

test "BattleResult with values" {
    const result = BattleResult{
        .build_ok = true,
        .test_ok = true,
        .test_count = 10,
        .diff_lines = 5,
        .elapsed_ms = 1000,
        .toxic_score = 0.5,
        .total_score = 0.8,
    };
    try std.testing.expect(result.build_ok);
    try std.testing.expect(result.test_ok);
    try std.testing.expectEqual(@as(u32, 10), result.test_count);
}

test "EloState default values" {
    const state = EloState{};
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), state.baseline, 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), state.gladiator, 0.01);
    try std.testing.expectEqual(@as(u32, 0), state.total_battles);
    try std.testing.expectEqual(@as(u32, 0), state.baseline_wins);
    try std.testing.expectEqual(@as(u32, 0), state.gladiator_wins);
    try std.testing.expectEqual(@as(u32, 0), state.ties);
}

test "PILOT_TASKS count" {
    try std.testing.expect(PILOT_TASKS.len >= 5);
}

test "PILOT_TASKS have valid IDs" {
    for (PILOT_TASKS) |task| {
        try std.testing.expect(task.id.len > 0);
        try std.testing.expect(task.task.len > 0);
    }
}

test "PILOT_TASKS difficulties" {
    const has_easy = for (PILOT_TASKS) |task| {
        if (task.difficulty == .easy) break true;
    } else false;
    try std.testing.expect(has_easy);

    const has_medium = for (PILOT_TASKS) |task| {
        if (task.difficulty == .medium) break true;
    } else false;
    try std.testing.expect(has_medium);

    const has_hard = for (PILOT_TASKS) |task| {
        if (task.difficulty == .hard) break true;
    } else false;
    try std.testing.expect(has_hard);
}

test "extractJsonStr with missing key returns null" {
    const json = "{\"winner\":\"GLADIATOR\"}";
    const result = extractJsonStr(json, "\"task\":\"");
    try std.testing.expect(result == null);
}

test "extractJsonStr with empty input returns null" {
    const result = extractJsonStr("", "\"winner\":\"");
    try std.testing.expect(result == null);
}

test "elo update gladiator wins" {
    const result = updateElo(1000.0, 1000.0, .gladiator);
    try std.testing.expect(result[0] < 1000.0); // baseline loses
    try std.testing.expect(result[1] > 1000.0); // gladiator gains
}

test "computeScore with zero tests" {
    const score = computeScore(true, true, 0, 10, 30_000, 300_000, 100.0);
    try std.testing.expect(score > 0.0);
    try std.testing.expect(score < 1.0);
}

test "computeScore with very slow execution" {
    const score = computeScore(true, true, 5, 50, 600_000, 300_000, 90.0);
    // 2x timeout should still pass but be lower than perfect score
    try std.testing.expect(score < 0.95);
}
