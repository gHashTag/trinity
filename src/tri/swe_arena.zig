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
    _ = allocator;
    const target = if (args.len > 0) args[0] else "all";

    print("\n{s}🏟️  SWE ARENA — RUN{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Target: {s}{s}{s}\n\n", .{ CYAN, target, RESET });

    if (std.mem.eql(u8, target, "all")) {
        print("  Running all {d} benchmark tasks...\n", .{BUILTIN_TASKS.len});
        for (BUILTIN_TASKS) |task| {
            print("  {s}[ ]{s} {s}: {s}\n", .{ DIM, RESET, task.id, task.title });
        }
    } else {
        print("  {s}Task {s} — will spawn dev agent{s}\n", .{ DIM, target, RESET });
    }
    print("\n  {s}(Benchmark execution not yet connected to Railway){s}\n\n", .{ DIM, RESET });
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
