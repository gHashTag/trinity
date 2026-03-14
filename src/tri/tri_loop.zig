// @origin(manual) @regen(pending)
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

fn printHelp() void {
    print("\n{s}TRI LOOP — Autonomous Development Loop (Ralph Pattern){s}\n\n", .{ BOLD, RESET });
    print("  {s}tri loop{s}                  Run one iteration\n", .{ CYAN, RESET });
    print("  {s}tri loop once{s}             Same as above\n", .{ CYAN, RESET });
    print("  {s}tri loop status{s}           Show last loop state\n", .{ CYAN, RESET });
    print("  {s}tri loop continuous{s}       Run continuously (5min default)\n", .{ CYAN, RESET });
    print("  {s}tri loop continuous -i 60{s} Custom interval (seconds)\n\n", .{ CYAN, RESET });
    print("  {s}Steps per iteration:{s}\n", .{ DIM, RESET });
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
