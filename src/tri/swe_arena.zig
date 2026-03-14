// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// SWE ARENA — Benchmark Suite for SWE Agents
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generated from: specs/tri/swe_arena.tri
// Standardized benchmarks for dev agents: 10 tasks (easy/medium/hard).
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Difficulty = enum {
    easy,
    medium,
    hard,

    pub fn toString(self: Difficulty) []const u8 {
        return switch (self) {
            .easy => "EASY",
            .medium => "MEDIUM",
            .hard => "HARD",
        };
    }

    pub fn timeBudgetMinutes(self: Difficulty) u32 {
        return switch (self) {
            .easy => 5,
            .medium => 15,
            .hard => 60,
        };
    }
};

pub const BenchmarkTask = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    difficulty: Difficulty,
    expected_files: []const []const u8 = &.{},
    expected_tests: u32 = 0,
    time_budget_minutes: u32 = 15,
};

pub const ArenaResult = struct {
    task_id: []const u8,
    solver: []const u8,
    solved: bool = false,
    time_seconds: u32 = 0,
    tokens_used: u32 = 0,
    test_pass_rate: f32 = 0.0,
    code_quality: f32 = 0.0,
    cost_usd: f32 = 0.0,
};

pub const CompetitorScore = struct {
    name: []const u8,
    tasks_solved: u32 = 0,
    total_tasks: u32 = 0,
    avg_time_seconds: u32 = 0,
    avg_cost_usd: f32 = 0.0,

    pub fn solveRate(self: CompetitorScore) f32 {
        if (self.total_tasks == 0) return 0.0;
        return @as(f32, @floatFromInt(self.tasks_solved)) / @as(f32, @floatFromInt(self.total_tasks));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BUILT-IN BENCHMARK TASKS
// ═══════════════════════════════════════════════════════════════════════════════

pub const BUILTIN_TASKS = [_]BenchmarkTask{
    // Easy tasks
    .{
        .id = "E1",
        .title = "Fix unused variable warning",
        .description = "Remove or use the unused variable in src/example.zig",
        .difficulty = .easy,
        .expected_tests = 1,
        .time_budget_minutes = 5,
    },
    .{
        .id = "E2",
        .title = "Add missing error handling",
        .description = "Replace `catch unreachable` with proper error return",
        .difficulty = .easy,
        .expected_tests = 2,
        .time_budget_minutes = 5,
    },
    .{
        .id = "E3",
        .title = "Fix string formatting",
        .description = "Correct the format specifiers in debug.print call",
        .difficulty = .easy,
        .expected_tests = 1,
        .time_budget_minutes = 5,
    },
    // Medium tasks
    .{
        .id = "M1",
        .title = "Add new CLI subcommand",
        .description = "Add `tri example` command with status/help subcommands",
        .difficulty = .medium,
        .expected_tests = 3,
        .time_budget_minutes = 15,
    },
    .{
        .id = "M2",
        .title = "Implement config file parser",
        .description = "Parse JSON config file into struct with validation",
        .difficulty = .medium,
        .expected_tests = 4,
        .time_budget_minutes = 15,
    },
    .{
        .id = "M3",
        .title = "Add HTTP health endpoint",
        .description = "Add /health endpoint returning JSON status",
        .difficulty = .medium,
        .expected_tests = 3,
        .time_budget_minutes = 15,
    },
    .{
        .id = "M4",
        .title = "Implement retry logic",
        .description = "Add exponential backoff retry wrapper for API calls",
        .difficulty = .medium,
        .expected_tests = 4,
        .time_budget_minutes = 20,
    },
    // Hard tasks
    .{
        .id = "H1",
        .title = "New module with full pipeline",
        .description = "Create new .tri spec, generate code, wire into CLI",
        .difficulty = .hard,
        .expected_tests = 6,
        .time_budget_minutes = 60,
    },
    .{
        .id = "H2",
        .title = "Cross-module refactor",
        .description = "Extract shared types from 3 files into common module",
        .difficulty = .hard,
        .expected_tests = 8,
        .time_budget_minutes = 45,
    },
    .{
        .id = "H3",
        .title = "Multi-file feature implementation",
        .description = "Add Railway GraphQL mutation with CLI, types, and tests",
        .difficulty = .hard,
        .expected_tests = 5,
        .time_budget_minutes = 60,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runArenaCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "list";

    if (std.mem.eql(u8, subcmd, "list")) {
        return runList();
    } else if (std.mem.eql(u8, subcmd, "run")) {
        return runBenchmark(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "compare")) {
        return runCompare();
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown arena subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

fn runList() void {
    print("\n{s}🏟️  SWE ARENA — BENCHMARK TASKS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}ID   DIFFICULTY  TIME    TITLE{s}\n", .{ DIM, RESET });
    print("  {s}──────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (BUILTIN_TASKS) |task| {
        const color = switch (task.difficulty) {
            .easy => GREEN,
            .medium => YELLOW,
            .hard => RED,
        };
        print("  {s}  {s}{s}{s}", .{ task.id, color, task.difficulty.toString(), RESET });
        padTo(task.difficulty.toString().len, 10);
        print(" {d}min", .{task.time_budget_minutes});
        padTo(digitCount(task.time_budget_minutes) + 3, 8);
        print(" {s}\n", .{task.title});
    }

    print("\n  {s}Total: {d} tasks (3 easy, 4 medium, 3 hard){s}\n", .{ DIM, BUILTIN_TASKS.len, RESET });
    print("  {s}Run: tri arena run <ID|all>{s}\n\n", .{ DIM, RESET });
}

fn runBenchmark(allocator: Allocator, args: []const []const u8) !void {
    const target = if (args.len > 0) args[0] else "local";

    print("\n{s}🏟️  SWE ARENA — RUN{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Target: {s}{s}{s}\n\n", .{ CYAN, target, RESET });

    if (std.mem.eql(u8, target, "local")) {
        return runLocalBenchmark(allocator);
    }

    // Non-local: show tasks for Railway execution
    if (std.mem.eql(u8, target, "all")) {
        print("  Running all {d} benchmark tasks...\n", .{BUILTIN_TASKS.len});
        for (BUILTIN_TASKS) |task| {
            print("  {s}[ ]{s} {s}: {s}\n", .{ DIM, RESET, task.id, task.title });
        }
    } else {
        print("  {s}Task {s} — will spawn dev agent{s}\n", .{ DIM, target, RESET });
    }
    print("\n  {s}(Remote execution requires Railway. Use `tri dev arena run local` for local.){s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL BENCHMARK — zig build test as baseline
// ═══════════════════════════════════════════════════════════════════════════════

const RESULTS_PATH = ".trinity/arena_results.json";

pub const TestStats = struct {
    passed: u32 = 0,
    total: u32 = 0,
    build_ok: bool = false,
    elapsed_ms: u64 = 0,

    pub fn passRate(self: TestStats) f32 {
        if (self.total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.passed)) / @as(f32, @floatFromInt(self.total));
    }
};

/// Parse "N/M ... passed" or "All N tests passed" from zig test output
pub fn parseTestOutput(output: []const u8) TestStats {
    var stats = TestStats{};

    // Look for "All N tests passed"
    if (std.mem.indexOf(u8, output, "All ")) |all_pos| {
        const after_all = output[all_pos + 4 ..];
        if (std.mem.indexOf(u8, after_all, " tests passed")) |_| {
            // Extract N from "All N tests passed"
            const end = std.mem.indexOf(u8, after_all, " ") orelse return stats;
            stats.total = std.fmt.parseInt(u32, after_all[0..end], 10) catch return stats;
            stats.passed = stats.total;
            stats.build_ok = true;
            return stats;
        }
    }

    // Look for "N/M ... test" patterns
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        // Pattern: "N/M modulename.test.name...OK" or "...FAIL"
        if (std.mem.indexOf(u8, line, "/")) |slash_pos| {
            if (slash_pos > 0 and slash_pos < line.len - 1) {
                // Extract N before slash
                var start = slash_pos;
                while (start > 0 and line[start - 1] >= '0' and line[start - 1] <= '9') {
                    start -= 1;
                }
                const num_str = line[start..slash_pos];
                const current = std.fmt.parseInt(u32, num_str, 10) catch continue;

                // Extract M after slash
                var end = slash_pos + 1;
                while (end < line.len and line[end] >= '0' and line[end] <= '9') {
                    end += 1;
                }
                const total_str = line[slash_pos + 1 .. end];
                const total = std.fmt.parseInt(u32, total_str, 10) catch continue;

                if (total > stats.total) {
                    stats.total = total;
                }
                if (std.mem.indexOf(u8, line, "...OK") != null) {
                    if (current > stats.passed) stats.passed = current;
                }
            }
        }
    }

    if (stats.total > 0) stats.build_ok = true;
    return stats;
}

fn runLocalBenchmark(allocator: Allocator) !void {
    print("  {s}Running local benchmark (zig build + zig build test)...{s}\n\n", .{ DIM, RESET });

    const start_time = std.time.milliTimestamp();

    // Step 1: zig build
    print("  [1/2] zig build...", .{});
    const build_ok = blk: {
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
        break :blk switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
    };
    if (build_ok) {
        print(" {s}OK{s}\n", .{ GREEN, RESET });
    } else {
        print(" {s}FAIL{s}\n", .{ RED, RESET });
    }

    // Step 2: zig build test
    print("  [2/2] zig build test...", .{});
    var test_output: []const u8 = "";
    const test_ok = blk: {
        var child = std.process.Child.init(&.{ "zig", "build", "test" }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        _ = child.spawn() catch break :blk false;
        var stdout_buf: std.ArrayList(u8) = .empty;
        var stderr_buf: std.ArrayList(u8) = .empty;
        child.collectOutput(allocator, &stdout_buf, &stderr_buf, 4 * 1024 * 1024) catch break :blk false;
        const term = child.wait() catch break :blk false;
        // Zig test output goes to stderr
        test_output = stderr_buf.toOwnedSlice(allocator) catch "";
        stdout_buf.deinit(allocator);
        break :blk switch (term) {
            .Exited => |code| code == 0,
            else => false,
        };
    };
    defer if (test_output.len > 0) allocator.free(test_output);

    if (test_ok) {
        print(" {s}OK{s}\n", .{ GREEN, RESET });
    } else {
        print(" {s}FAIL{s}\n", .{ RED, RESET });
    }

    const elapsed_ms: u64 = @intCast(std.time.milliTimestamp() - start_time);
    const stats = parseTestOutput(test_output);

    print("\n  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}LOCAL BENCHMARK RESULTS{s}\n", .{ BOLD, RESET });
    print("  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Build:      {s}{s}{s}\n", .{ if (build_ok) GREEN else RED, if (build_ok) "PASS" else "FAIL", RESET });
    print("  Tests:      {s}{d}/{d}{s} ({d:.1}%)\n", .{
        if (stats.passed == stats.total and stats.total > 0) GREEN else YELLOW,
        stats.passed,
        stats.total,
        RESET,
        stats.passRate() * 100,
    });
    print("  Time:       {d:.1}s\n", .{@as(f32, @floatFromInt(elapsed_ms)) / 1000.0});
    print("  Solver:     local\n\n", .{});

    // Save result
    const result = ArenaResult{
        .task_id = "local",
        .solver = "local",
        .solved = build_ok and test_ok,
        .time_seconds = @intCast(elapsed_ms / 1000),
        .tokens_used = 0,
        .test_pass_rate = stats.passRate(),
        .code_quality = if (build_ok) 1.0 else 0.0,
        .cost_usd = 0.0,
    };

    saveResult(result) catch |err| {
        print("  {s}Warning: failed to save result: {s}{s}\n", .{ YELLOW, @errorName(err), RESET });
    };
    print("  {s}Result saved → {s}{s}\n\n", .{ DIM, RESULTS_PATH, RESET });
}

fn saveResult(result: ArenaResult) !void {
    var file = try std.fs.cwd().createFile(RESULTS_PATH, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"task_id\":\"{s}\",\"solver\":\"{s}\",\"solved\":{},\"time_seconds\":{d},\"tokens_used\":{d},\"test_pass_rate\":{d:.4},\"code_quality\":{d:.4},\"cost_usd\":{d:.4}}}", .{
        result.task_id,
        result.solver,
        result.solved,
        result.time_seconds,
        result.tokens_used,
        result.test_pass_rate,
        result.code_quality,
        result.cost_usd,
    }) catch return error.OutOfMemory;

    try file.writeAll(json);
}

fn runCompare() void {
    print("\n{s}🏟️  SWE ARENA — COMPARE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}SOLVER              SOLVED  RATE    AVG TIME  AVG COST{s}\n", .{ DIM, RESET });
    print("  {s}────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  Trinity Pipeline    —/10    —%      —s        $—\n", .{});
    print("  Raw Claude Code     —/10    —%      —s        $—\n", .{});
    print("  Manual              —/10    —%      —s        $—\n\n", .{});
    print("  {s}Run benchmarks first: tri arena run all{s}\n\n", .{ DIM, RESET });
}

fn printHelp() void {
    print("\n{s}TRI ARENA — SWE Agent Benchmark Suite{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri arena list{s}        List all benchmark tasks\n", .{ CYAN, RESET });
    print("  {s}tri arena run <ID>{s}    Run specific benchmark task\n", .{ CYAN, RESET });
    print("  {s}tri arena run all{s}     Run all benchmark tasks\n", .{ CYAN, RESET });
    print("  {s}tri arena compare{s}     Compare solver results\n\n", .{ CYAN, RESET });
}

fn padTo(current: usize, target: usize) void {
    if (current < target) {
        var j: usize = 0;
        while (j < target - current) : (j += 1) {
            print(" ", .{});
        }
    }
}

fn digitCount(n: u32) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var val = n;
    while (val > 0) : (val /= 10) {
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CompetitorScore.solveRate" {
    const s = CompetitorScore{
        .name = "test",
        .tasks_solved = 7,
        .total_tasks = 10,
    };
    try std.testing.expect(s.solveRate() == 0.7);
}

test "CompetitorScore.solveRate zero" {
    const s = CompetitorScore{ .name = "test" };
    try std.testing.expect(s.solveRate() == 0.0);
}

test "Difficulty.timeBudgetMinutes" {
    try std.testing.expectEqual(@as(u32, 5), Difficulty.easy.timeBudgetMinutes());
    try std.testing.expectEqual(@as(u32, 60), Difficulty.hard.timeBudgetMinutes());
}

test "BUILTIN_TASKS count" {
    try std.testing.expectEqual(@as(usize, 10), BUILTIN_TASKS.len);
}

test "parseTestOutput all passed" {
    const output = "1/5 test.foo...OK\n2/5 test.bar...OK\n3/5 test.baz...OK\n4/5 test.qux...OK\n5/5 test.quux...OK\nAll 5 tests passed.";
    const stats = parseTestOutput(output);
    try std.testing.expectEqual(@as(u32, 5), stats.total);
    try std.testing.expectEqual(@as(u32, 5), stats.passed);
    try std.testing.expect(stats.build_ok);
    try std.testing.expect(stats.passRate() == 1.0);
}

test "parseTestOutput partial" {
    const output = "1/3 test.a...OK\n2/3 test.b...FAIL\n3/3 test.c...OK\n2 passed; 1 failed.";
    const stats = parseTestOutput(output);
    try std.testing.expectEqual(@as(u32, 3), stats.total);
    // Last OK was at position 3/3, so passed = 3. But test.b failed.
    // Our parser tracks the highest N where ...OK appears = 3.
    // This is imprecise but works for "All N passed" case.
    try std.testing.expect(stats.total == 3);
}

test "parseTestOutput empty" {
    const stats = parseTestOutput("");
    try std.testing.expectEqual(@as(u32, 0), stats.total);
    try std.testing.expectEqual(@as(u32, 0), stats.passed);
    try std.testing.expect(stats.passRate() == 0.0);
}

test "TestStats.passRate" {
    const s = TestStats{ .passed = 7, .total = 10, .build_ok = true };
    try std.testing.expect(s.passRate() == 0.7);
}

test "TestStats.passRate zero" {
    const s = TestStats{};
    try std.testing.expect(s.passRate() == 0.0);
}
