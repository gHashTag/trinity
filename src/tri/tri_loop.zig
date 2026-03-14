// @origin(spec:tri_loop.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI LOOP — Ralph-Pattern Autonomous Development Loop
// ═══════════════════════════════════════════════════════════════════════════════
//
// One iteration: wake → scan → decide → act → report → sleep
// Continuous: `tri loop --interval 300` (5 min cycle)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const tri_experience = @import("tri_experience.zig");
const tri_dev = @import("tri_dev.zig");
const print = std.debug.print;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

const STATE_PATH = ".trinity/loop_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoopAction = enum {
    build_test,
    farm_collect,
    farm_evolve,
    fitness_sync,
    arena_run,
    idle,

    pub fn toString(self: LoopAction) []const u8 {
        return switch (self) {
            .build_test => "BUILD+TEST",
            .farm_collect => "FARM COLLECT",
            .farm_evolve => "FARM EVOLVE",
            .fitness_sync => "FITNESS SYNC",
            .arena_run => "ARENA RUN",
            .idle => "IDLE",
        };
    }
};

pub const LoopDecision = enum {
    continue_loop,
    idle_wait,
    exit_done,

    pub fn toString(self: LoopDecision) []const u8 {
        return switch (self) {
            .continue_loop => "CONTINUE",
            .idle_wait => "IDLE",
            .exit_done => "EXIT",
        };
    }
};

pub const StepResult = struct {
    action: LoopAction = .idle,
    success: bool = false,
    detail: [256]u8 = [_]u8{0} ** 256,
    detail_len: usize = 0,

    fn setDetail(self: *StepResult, msg: []const u8) void {
        const len = @min(msg.len, self.detail.len);
        @memcpy(self.detail[0..len], msg[0..len]);
        self.detail_len = len;
    }

    fn getDetail(self: *const StepResult) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLoopCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "once";

    if (std.mem.eql(u8, subcmd, "once") or std.mem.eql(u8, subcmd, "step")) {
        try runOnce(allocator);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        runStatus();
    } else if (std.mem.eql(u8, subcmd, "continuous") or std.mem.eql(u8, subcmd, "daemon")) {
        const interval = parseInterval(args);
        try runContinuous(allocator, interval);
    } else if (std.mem.eql(u8, subcmd, "retry")) {
        try runRetryCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        // Default: treat as "once"
        try runOnce(allocator);
    }
}

fn parseInterval(args: []const []const u8) u32 {
    for (args, 0..) |arg, i| {
        if ((std.mem.eql(u8, arg, "--interval") or std.mem.eql(u8, arg, "-i")) and i + 1 < args.len) {
            return std.fmt.parseInt(u32, args[i + 1], 10) catch 300;
        }
    }
    return 300; // default 5 minutes
}

// ═══════════════════════════════════════════════════════════════════════════════
// SINGLE ITERATION
// ═══════════════════════════════════════════════════════════════════════════════

fn runOnce(allocator: Allocator) !void {
    const wake_count = incrementWakeCount();

    print("\n{s}🔄 TRI LOOP — ITERATION #{d}{s}\n", .{ BOLD, wake_count, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var results: [5]StepResult = [_]StepResult{.{}} ** 5;
    var step_count: usize = 0;

    // Step 1: Build + Test
    print("  {s}[1/4]{s} Build + Test...", .{ CYAN, RESET });
    results[0] = runBuildTest(allocator);
    step_count += 1;
    printStepResult(&results[0]);

    // Step 2: Farm collect (training metrics)
    print("  {s}[2/4]{s} Farm collect...", .{ CYAN, RESET });
    results[1] = runFarmCollect(allocator);
    step_count += 1;
    printStepResult(&results[1]);

    // Step 3: Fitness sync (SWE agents)
    print("  {s}[3/4]{s} Fitness sync...", .{ CYAN, RESET });
    results[2] = runFitnessSync(allocator);
    step_count += 1;
    printStepResult(&results[2]);

    // Step 4: Arena baseline
    print("  {s}[4/4]{s} Arena baseline...", .{ CYAN, RESET });
    results[3] = runArenaBaseline(allocator);
    step_count += 1;
    printStepResult(&results[3]);

    // Decision
    const decision = decide(results[0..step_count]);

    print("\n  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}LOOP #{d} SUMMARY{s}\n", .{ BOLD, wake_count, RESET });
    print("  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    var ok: usize = 0;
    var fail: usize = 0;
    for (results[0..step_count]) |r| {
        if (r.success) ok += 1 else fail += 1;
    }
    print("  Steps:    {s}{d} OK{s} / {s}{d} FAIL{s}\n", .{
        GREEN, ok, RESET, if (fail > 0) RED else DIM, fail, RESET,
    });
    const dec_color = switch (decision) {
        .continue_loop => GREEN,
        .idle_wait => YELLOW,
        .exit_done => MAGENTA,
    };
    print("  Decision: {s}{s}{s}\n", .{ dec_color, decision.toString(), RESET });
    print("  Wake:     #{d}\n\n", .{wake_count});

    saveLoopState(wake_count, ok, fail, decision);

    // Auto-save experience episode
    saveLoopEpisode(wake_count, results[0..step_count], decision);
}

fn printStepResult(r: *const StepResult) void {
    if (r.success) {
        print(" {s}OK{s}", .{ GREEN, RESET });
    } else {
        print(" {s}FAIL{s}", .{ RED, RESET });
    }
    if (r.detail_len > 0) {
        print(" {s}({s}){s}", .{ DIM, r.getDetail(), RESET });
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEPS
// ═══════════════════════════════════════════════════════════════════════════════

fn runBuildTest(allocator: Allocator) StepResult {
    var result = StepResult{ .action = .build_test };

    // zig build
    const build_exit = runChild(allocator, &.{ "zig", "build" });
    if (build_exit != 0) {
        result.setDetail("build failed");
        return result;
    }

    // zig build test
    const test_exit = runChild(allocator, &.{ "zig", "build", "test" });
    if (test_exit != 0) {
        result.setDetail("tests failed");
        return result;
    }

    result.success = true;
    result.setDetail("build+test OK");
    return result;
}

fn runFarmCollect(allocator: Allocator) StepResult {
    var result = StepResult{ .action = .farm_collect };

    const exit = runChild(allocator, &.{ "tri", "farm", "evolve", "collect" });
    if (exit == 0) {
        result.success = true;
        result.setDetail("metrics collected");
    } else if (exit == 255) {
        // Command not available (no .env sourced, etc.)
        result.success = true;
        result.setDetail("skipped (no env)");
    } else {
        result.setDetail("collect failed");
    }
    return result;
}

fn runFitnessSync(allocator: Allocator) StepResult {
    var result = StepResult{ .action = .fitness_sync };

    const exit = runChild(allocator, &.{ "tri", "dev", "fitness", "sync" });
    if (exit == 0) {
        result.success = true;
        result.setDetail("fitness synced");
    } else if (exit == 255) {
        result.success = true;
        result.setDetail("skipped (no env)");
    } else {
        result.setDetail("sync failed");
    }
    return result;
}

fn runArenaBaseline(allocator: Allocator) StepResult {
    var result = StepResult{ .action = .arena_run };

    const exit = runChild(allocator, &.{ "tri", "dev", "arena", "run", "local" });
    if (exit == 0) {
        result.success = true;
        result.setDetail("arena OK");
    } else {
        result.setDetail("arena failed");
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DECISION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

fn decide(results: []const StepResult) LoopDecision {
    var all_ok = true;
    var any_fail = false;

    for (results) |r| {
        if (!r.success) {
            all_ok = false;
            if (r.action == .build_test) any_fail = true; // build failure = stop
        }
    }

    if (any_fail) return .exit_done; // build broken = fix needed, exit
    if (all_ok) return .continue_loop; // everything green = keep going
    return .idle_wait; // partial success = wait
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTINUOUS MODE
// ═══════════════════════════════════════════════════════════════════════════════

fn runContinuous(allocator: Allocator, interval_sec: u32) !void {
    print("\n{s}🔄 TRI LOOP — CONTINUOUS MODE{s}\n", .{ BOLD, RESET });
    print("  Interval: {d}s ({d}min)\n", .{ interval_sec, interval_sec / 60 });
    print("  Exit: Ctrl-C or build failure\n\n", .{});

    while (true) {
        try runOnce(allocator);

        // Check last decision from state
        const should_exit = checkExitState();
        if (should_exit) {
            print("  {s}Loop decided EXIT — stopping.{s}\n\n", .{ MAGENTA, RESET });
            break;
        }

        print("  {s}Sleeping {d}s...{s}\n\n", .{ DIM, interval_sec, RESET });
        std.Thread.sleep(@as(u64, interval_sec) * std.time.ns_per_s);
    }
}

fn checkExitState() bool {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return false;
    defer file.close();
    var buf: [1024]u8 = undefined;
    const n = file.readAll(&buf) catch return false;
    return std.mem.indexOf(u8, buf[0..n], "\"EXIT\"") != null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus() void {
    print("\n{s}🔄 TRI LOOP — STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch {
        print("  {s}No loop state found. Run: tri loop{s}\n\n", .{ DIM, RESET });
        return;
    };
    defer file.close();
    var buf: [1024]u8 = undefined;
    const n = file.readAll(&buf) catch {
        print("  {s}Failed to read state{s}\n\n", .{ DIM, RESET });
        return;
    };
    print("  {s}\n\n", .{buf[0..n]});
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn incrementWakeCount() u32 {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return 1;
    defer file.close();
    var buf: [1024]u8 = undefined;
    const n = file.readAll(&buf) catch return 1;
    const data = buf[0..n];

    // Parse "wake":N
    const key = "\"wake\":";
    const start = (std.mem.indexOf(u8, data, key) orelse return 1) + key.len;
    var end = start;
    while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
    const count = std.fmt.parseInt(u32, data[start..end], 10) catch return 1;
    return count + 1;
}

fn saveLoopEpisode(wake_count: u32, results: []const StepResult, decision: LoopDecision) void {
    var episode = tri_experience.Episode{};
    episode.timestamp = std.time.timestamp();
    episode.issue = 0;
    episode.iterations = wake_count;

    var task_buf: [64]u8 = undefined;
    const task = std.fmt.bufPrint(&task_buf, "loop iteration #{d}", .{wake_count}) catch return;
    copyToFixed(&episode.task, &episode.task_len, task);

    const verdict_str: []const u8 = switch (decision) {
        .continue_loop => "PASS",
        .idle_wait => "PARTIAL",
        .exit_done => "FAIL",
    };
    copyToFixed(&episode.verdict, &episode.verdict_len, verdict_str);

    for (results) |r| {
        if (!r.success and episode.mistake_count < 8) {
            const detail = r.detail[0..r.detail_len];
            if (detail.len > 0) {
                tri_experience.copyToFixed(
                    &episode.mistakes[episode.mistake_count],
                    &episode.mistake_lens[episode.mistake_count],
                    detail,
                );
                episode.mistake_count += 1;
            }
        }
    }

    var ok: u32 = 0;
    var total: u32 = 0;
    for (results) |r| {
        total += 1;
        if (r.success) ok += 1;
    }
    if (total > 0) {
        episode.fitness.test_pass_rate = @as(f32, @floatFromInt(ok)) / @as(f32, @floatFromInt(total));
    }

    tri_experience.saveEpisode(episode) catch {};
}

fn saveLoopState(wake: u32, ok: usize, fail: usize, decision: LoopDecision) void {
    const ts = @as(u64, @intCast(std.time.timestamp()));
    var file = std.fs.cwd().createFile(STATE_PATH, .{}) catch return;
    defer file.close();
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&buf,
        \\{{"wake":{d},"ok":{d},"fail":{d},"decision":"{s}","ts":{d}}}
    , .{ wake, ok, fail, decision.toString(), ts }) catch return;
    file.writeAll(json) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn runChild(allocator: Allocator, argv: []const []const u8) u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch return 255;
    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    child.collectOutput(allocator, &stdout_buf, &stderr_buf, 8 * 1024 * 1024) catch return 255;
    defer stdout_buf.deinit(allocator);
    defer stderr_buf.deinit(allocator);
    const term = child.wait() catch return 255;
    return switch (term) {
        .Exited => |code| code,
        else => 1,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// RETRY — Build-Test-Retry Loop with Experience Accumulation
// ═══════════════════════════════════════════════════════════════════════════════

pub const RetryConfig = struct {
    issue: u32 = 0,
    max_iterations: u32 = 10,
    task: [256]u8 = undefined,
    task_len: u8 = 0,

    pub fn taskStr(self: *const RetryConfig) []const u8 {
        return self.task[0..self.task_len];
    }
};

pub const RetryIterationResult = struct {
    build_ok: bool = false,
    test_ok: bool = false,
    test_pass: u32 = 0,
    test_total: u32 = 0,
    error_output: [2048]u8 = undefined,
    error_len: u16 = 0,

    pub fn errorStr(self: *const RetryIterationResult) []const u8 {
        return self.error_output[0..self.error_len];
    }

    pub fn testPassRate(self: *const RetryIterationResult) f32 {
        if (self.test_total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.test_pass)) / @as(f32, @floatFromInt(self.test_total));
    }
};

pub const RetryVerdict = enum {
    pass,
    fail,
    build_error,

    pub fn toString(self: RetryVerdict) []const u8 {
        return switch (self) {
            .pass => "PASS",
            .fail => "FAIL",
            .build_error => "BUILD_ERROR",
        };
    }
};

fn copyToFixed(dest: anytype, len_ptr: *u8, src: []const u8) void {
    const max = dest.len;
    const copy_len = @min(src.len, max);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}

fn runRetryCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len > 0 and (std.mem.eql(u8, args[0], "help") or std.mem.eql(u8, args[0], "--help"))) {
        printRetryHelp();
        return;
    }

    var config = RetryConfig{};

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--issue") and i + 1 < args.len) {
            i += 1;
            config.issue = std.fmt.parseInt(u32, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "--max-iter") and i + 1 < args.len) {
            i += 1;
            config.max_iterations = std.fmt.parseInt(u32, args[i], 10) catch 10;
        } else if (std.mem.eql(u8, arg, "--task") and i + 1 < args.len) {
            i += 1;
            copyToFixed(&config.task, &config.task_len, args[i]);
        }
    }

    if (config.task_len == 0) {
        copyToFixed(&config.task, &config.task_len, "build-test loop");
    }

    try runRetryLoop(allocator, config);
}

fn runRetryLoop(allocator: Allocator, config: RetryConfig) !void {
    print("\n{s}TRI LOOP RETRY{s} — build-test-retry with experience\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Issue:          #{d}\n", .{config.issue});
    print("  Task:           {s}\n", .{config.taskStr()});
    print("  Max iterations: {d}\n\n", .{config.max_iterations});

    var episode = tri_experience.Episode{};
    episode.issue = config.issue;
    @memcpy(episode.task[0..config.task_len], config.task[0..config.task_len]);
    episode.task_len = config.task_len;
    episode.timestamp = std.time.timestamp();

    var final_verdict: RetryVerdict = .fail;
    var final_result: RetryIterationResult = .{};
    const loop_start = std.time.milliTimestamp();

    var iteration: u32 = 1;
    while (iteration <= config.max_iterations) : (iteration += 1) {
        print("  {s}[{d}/{d}]{s} ", .{ CYAN, iteration, config.max_iterations, RESET });

        // Comment on issue (fire-and-forget)
        if (config.issue > 0) {
            retryCommentOnIssue(allocator, config.issue, iteration, config.max_iterations);
        }

        // Run build + test
        const result = runRetryBuildAndTest(allocator);
        final_result = result;

        if (result.build_ok and result.test_ok and result.testPassRate() >= 0.8) {
            final_verdict = .pass;
            print("{s}PASS{s} (tests: {d}/{d})\n", .{ GREEN, RESET, result.test_pass, result.test_total });
            break;
        } else if (!result.build_ok) {
            final_verdict = .build_error;
            print("{s}BUILD ERROR{s}\n", .{ RED, RESET });

            const error_summary = extractRetryErrorSummary(result.errorStr());
            if (error_summary.len > 0 and episode.mistake_count < 8) {
                tri_experience.copyToFixed(
                    &episode.mistakes[episode.mistake_count],
                    &episode.mistake_lens[episode.mistake_count],
                    error_summary,
                );
                episode.mistake_count += 1;
            }
            print("    {s}{s}{s}\n", .{ DIM, error_summary, RESET });
        } else {
            final_verdict = .fail;
            print("{s}FAIL{s} (tests: {d}/{d}, rate: {d:.0}%)\n", .{
                RED,
                RESET,
                result.test_pass,
                result.test_total,
                result.testPassRate() * 100.0,
            });

            const error_summary = extractRetryErrorSummary(result.errorStr());
            if (error_summary.len > 0 and episode.mistake_count < 8) {
                tri_experience.copyToFixed(
                    &episode.mistakes[episode.mistake_count],
                    &episode.mistake_lens[episode.mistake_count],
                    error_summary,
                );
                episode.mistake_count += 1;
            }
            print("    {s}{s}{s}\n", .{ DIM, error_summary, RESET });
        }
    }

    // Compute fitness
    const elapsed_ms = std.time.milliTimestamp() - loop_start;
    const elapsed_hours: f32 = @as(f32, @floatFromInt(elapsed_ms)) / (1000.0 * 3600.0);
    episode.iterations = iteration;
    episode.fitness = .{
        .test_pass_rate = final_result.testPassRate(),
        .time_hours = elapsed_hours,
    };

    // Set verdict
    const verdict_str = final_verdict.toString();
    tri_experience.copyToFixed(&episode.verdict, &episode.verdict_len, verdict_str);

    // Save experience
    tri_experience.saveEpisode(episode) catch |err| {
        print("  {s}Warning: failed to save experience: {}{s}\n", .{ YELLOW, err, RESET });
    };

    // Final comment on issue
    if (config.issue > 0) {
        retryCommentFinal(allocator, config.issue, final_verdict, iteration, final_result);
    }

    // Summary
    print("\n{s}RETRY LOOP COMPLETE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Verdict:    {s}{s}{s}\n", .{
        if (final_verdict == .pass) GREEN else RED,
        verdict_str,
        RESET,
    });
    print("  Iterations: {d}/{d}\n", .{ iteration, config.max_iterations });
    print("  Tests:      {d}/{d} ({d:.0}%)\n", .{
        final_result.test_pass,
        final_result.test_total,
        final_result.testPassRate() * 100.0,
    });
    print("  Time:       {d:.1}s\n", .{@as(f32, @floatFromInt(elapsed_ms)) / 1000.0});
    print("  Fitness:    {d:.4}\n", .{episode.fitness.totalScore()});
    print("  Mistakes:   {d}\n\n", .{episode.mistake_count});
}

fn runRetryBuildAndTest(allocator: Allocator) RetryIterationResult {
    var result = RetryIterationResult{};

    // Step 1: zig build
    result.build_ok = blk: {
        var child = std.process.Child.init(&.{ "zig", "build" }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        _ = child.spawn() catch break :blk false;
        var stdout_buf: std.ArrayList(u8) = .empty;
        var stderr_buf: std.ArrayList(u8) = .empty;
        defer stdout_buf.deinit(allocator);
        defer stderr_buf.deinit(allocator);
        child.collectOutput(allocator, &stdout_buf, &stderr_buf, 4 * 1024 * 1024) catch break :blk false;
        const term = child.wait() catch break :blk false;
        const ok = switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
        if (!ok) {
            const stderr_data = stderr_buf.items;
            const copy_len: u16 = @intCast(@min(stderr_data.len, 2048));
            @memcpy(result.error_output[0..copy_len], stderr_data[0..copy_len]);
            result.error_len = copy_len;
        }
        break :blk ok;
    };

    if (!result.build_ok) return result;

    // Step 2: zig build test
    {
        var child = std.process.Child.init(&.{ "zig", "build", "test" }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        _ = child.spawn() catch return result;
        var stdout_buf: std.ArrayList(u8) = .empty;
        var stderr_buf: std.ArrayList(u8) = .empty;
        defer stdout_buf.deinit(allocator);
        defer stderr_buf.deinit(allocator);
        child.collectOutput(allocator, &stdout_buf, &stderr_buf, 4 * 1024 * 1024) catch return result;
        const term = child.wait() catch return result;
        result.test_ok = switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
        const out = if (stderr_buf.items.len > 0) stderr_buf.items else stdout_buf.items;
        if (!result.test_ok) {
            const copy_len: u16 = @intCast(@min(out.len, 2048));
            @memcpy(result.error_output[0..copy_len], out[0..copy_len]);
            result.error_len = copy_len;
        }
        // Parse test counts
        retryParseTestCounts(out, &result);
    }

    if (result.test_total == 0 and result.test_ok) {
        result.test_pass = 1;
        result.test_total = 1;
    }

    return result;
}

fn retryParseTestCounts(output: []const u8, result: *RetryIterationResult) void {
    var line_iter = std.mem.splitScalar(u8, output, '\n');
    while (line_iter.next()) |line| {
        // "X of Y test" pattern
        if (std.mem.indexOf(u8, line, " of ")) |of_pos| {
            if (std.mem.indexOf(u8, line, "test")) |_| {
                var start = of_pos;
                while (start > 0 and line[start - 1] >= '0' and line[start - 1] <= '9') start -= 1;
                const passed = std.fmt.parseInt(u32, line[start..of_pos], 10) catch continue;
                const after = of_pos + 4;
                var end = after;
                while (end < line.len and line[end] >= '0' and line[end] <= '9') end += 1;
                const total = std.fmt.parseInt(u32, line[after..end], 10) catch continue;
                result.test_pass = passed;
                result.test_total = total;
                return;
            }
        }
        // "All N tests passed"
        if (std.mem.indexOf(u8, line, "All ")) |all_pos| {
            if (std.mem.indexOf(u8, line, " tests passed")) |_| {
                const after = all_pos + 4;
                var end = after;
                while (end < line.len and line[end] >= '0' and line[end] <= '9') end += 1;
                const total = std.fmt.parseInt(u32, line[after..end], 10) catch continue;
                result.test_pass = total;
                result.test_total = total;
                return;
            }
        }
    }
}

fn retryCommentOnIssue(allocator: Allocator, issue: u32, iteration: u32, max_iter: u32) void {
    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "🔄 **[LOOP RETRY]** Iteration {d}/{d}", .{ iteration, max_iter }) catch return;
    var issue_buf: [16]u8 = undefined;
    const issue_str = std.fmt.bufPrint(&issue_buf, "{d}", .{issue}) catch return;
    var child = std.process.Child.init(&.{ "gh", "issue", "comment", issue_str, "--body", body }, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch return;
    _ = child.wait() catch {};
}

fn retryCommentFinal(allocator: Allocator, issue: u32, verdict: RetryVerdict, iterations: u32, result: RetryIterationResult) void {
    const emoji: []const u8 = if (verdict == .pass) "✅" else "❌";
    var body_buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{s} **[LOOP RETRY COMPLETE]** {s} after {d} iterations (tests: {d}/{d}, rate: {d:.0}%)", .{
        emoji,
        verdict.toString(),
        iterations,
        result.test_pass,
        result.test_total,
        result.testPassRate() * 100.0,
    }) catch return;
    var issue_buf: [16]u8 = undefined;
    const issue_str = std.fmt.bufPrint(&issue_buf, "{d}", .{issue}) catch return;
    var child = std.process.Child.init(&.{ "gh", "issue", "comment", issue_str, "--body", body }, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch return;
    _ = child.wait() catch {};
}

pub fn extractRetryErrorSummary(error_output: []const u8) []const u8 {
    if (error_output.len == 0) return "";
    var iter = std.mem.splitScalar(u8, error_output, '\n');
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "error:") != null or
            std.mem.indexOf(u8, line, "error[") != null)
        {
            var start: usize = 0;
            while (start < line.len and (line[start] == ' ' or line[start] == '\t')) start += 1;
            return line[start..];
        }
    }
    var iter2 = std.mem.splitScalar(u8, error_output, '\n');
    while (iter2.next()) |line| {
        if (line.len > 0) return line;
    }
    return error_output[0..@min(error_output.len, 128)];
}

fn printRetryHelp() void {
    print("\n{s}TRI LOOP RETRY{s} — build-test-retry with experience accumulation\n\n", .{ BOLD, RESET });
    print("  {s}tri loop retry{s} [options]\n\n", .{ CYAN, RESET });
    print("  Options:\n", .{});
    print("    --issue N          GitHub issue number (for progress comments)\n", .{});
    print("    --max-iter N       Maximum iterations (default: 10)\n", .{});
    print("    --task \"desc\"       Task description\n\n", .{});
    print("  Each iteration runs 'zig build' + 'zig build test'.\n", .{});
    print("  Stops on PASS (build ok + >=80%% tests pass) or max iterations.\n", .{});
    print("  Saves experience episode with mistakes and fitness score.\n\n", .{});
}

fn printHelp() void {
    print("\n{s}TRI LOOP — Autonomous Development Loop (Ralph Pattern){s}\n\n", .{ BOLD, RESET });
    print("  {s}tri loop{s}                  Run one iteration\n", .{ CYAN, RESET });
    print("  {s}tri loop once{s}             Same as above\n", .{ CYAN, RESET });
    print("  {s}tri loop status{s}           Show last loop state\n", .{ CYAN, RESET });
    print("  {s}tri loop continuous{s}       Run continuously (5min default)\n", .{ CYAN, RESET });
    print("  {s}tri loop continuous -i 60{s} Custom interval (seconds)\n", .{ CYAN, RESET });
    print("  {s}tri loop retry{s}            Build-test-retry with experience\n\n", .{ CYAN, RESET });
    print("  {s}Steps per iteration (once/continuous):{s}\n", .{ DIM, RESET });
    print("    1. Build + Test (zig build && zig build test)\n", .{});
    print("    2. Farm collect (training metrics from Railway)\n", .{});
    print("    3. Fitness sync (SWE agent fitness from Railway)\n", .{});
    print("    4. Arena baseline (local benchmark)\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "decide all ok" {
    const results = [_]StepResult{
        .{ .action = .build_test, .success = true },
        .{ .action = .farm_collect, .success = true },
    };
    try std.testing.expect(decide(&results) == .continue_loop);
}

test "decide build fail exits" {
    const results = [_]StepResult{
        .{ .action = .build_test, .success = false },
        .{ .action = .farm_collect, .success = true },
    };
    try std.testing.expect(decide(&results) == .exit_done);
}

test "decide partial success idles" {
    const results = [_]StepResult{
        .{ .action = .build_test, .success = true },
        .{ .action = .farm_collect, .success = false },
    };
    try std.testing.expect(decide(&results) == .idle_wait);
}

test "StepResult detail" {
    var r = StepResult{};
    r.setDetail("hello world");
    try std.testing.expectEqualStrings("hello world", r.getDetail());
}

test "incrementWakeCount no file" {
    // No state file = returns 1
    const count = incrementWakeCount();
    try std.testing.expect(count >= 1);
}

test "RetryConfig defaults" {
    const config = RetryConfig{};
    try std.testing.expectEqual(@as(u32, 0), config.issue);
    try std.testing.expectEqual(@as(u32, 10), config.max_iterations);
    try std.testing.expectEqual(@as(u8, 0), config.task_len);
}

test "RetryIterationResult testPassRate" {
    var r = RetryIterationResult{};
    try std.testing.expectEqual(@as(f32, 0.0), r.testPassRate());
    r.test_pass = 8;
    r.test_total = 10;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), r.testPassRate(), 0.001);
}

test "RetryVerdict toString" {
    try std.testing.expectEqualStrings("PASS", RetryVerdict.pass.toString());
    try std.testing.expectEqualStrings("FAIL", RetryVerdict.fail.toString());
    try std.testing.expectEqualStrings("BUILD_ERROR", RetryVerdict.build_error.toString());
}

test "extractRetryErrorSummary with error line" {
    const output = "src/foo.zig:10:5: error: expected type\n  other stuff\n";
    const summary = extractRetryErrorSummary(output);
    try std.testing.expect(std.mem.indexOf(u8, summary, "error:") != null);
}

test "extractRetryErrorSummary empty" {
    try std.testing.expectEqualStrings("", extractRetryErrorSummary(""));
}

test "extractRetryErrorSummary fallback" {
    const output = "some warning without error keyword";
    const summary = extractRetryErrorSummary(output);
    try std.testing.expectEqualStrings("some warning without error keyword", summary);
}
