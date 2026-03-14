// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV FARM EVOLVE — ASHA+PBT Evolution for SWE Agents
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generated from: specs/tri/dev_evolve.tri
// Reuses: tri_farm_evolve.zig (ASHA+PBT pattern)
//
// Fitness = 0.4*test_pass + 0.3*spec_compliance + 0.2*(1/time) + 0.1*pr_merged
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

pub const FitnessMetrics = struct {
    test_pass_rate: f32 = 0.0,
    spec_compliance: f32 = 0.0,
    time_hours: f32 = 0.0,
    pr_merged: bool = false,
    lines_changed: u32 = 0,
    build_success: bool = false,

    pub fn totalScore(self: FitnessMetrics) f32 {
        const time_score: f32 = if (self.time_hours > 0.0) @min(1.0, 1.0 / self.time_hours) else 0.0;
        const merged: f32 = if (self.pr_merged) 1.0 else 0.0;
        return 0.4 * self.test_pass_rate + 0.3 * self.spec_compliance + 0.2 * time_score + 0.1 * merged;
    }
};

pub const EvolutionRung = struct {
    time_threshold_hours: f32,
    kill_ratio: f32,
    min_fitness: f32,
};

// Default rungs for dev agent evolution (ASHA successive halving)
const DEFAULT_RUNGS = [_]EvolutionRung{
    .{ .time_threshold_hours = 0.5, .kill_ratio = 0.5, .min_fitness = 0.2 },
    .{ .time_threshold_hours = 1.0, .kill_ratio = 0.33, .min_fitness = 0.4 },
    .{ .time_threshold_hours = 2.0, .kill_ratio = 0.25, .min_fitness = 0.6 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDevEvolveCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "init")) {
        return runInit(allocator);
    } else if (std.mem.eql(u8, subcmd, "step")) {
        return runStep(allocator);
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatus(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown evolve subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT — scan accounts, build initial population
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator) !void {
    _ = allocator;
    print("\n{s}🧬 DEV EVOLUTION — INIT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Rungs:\n", .{});
    for (DEFAULT_RUNGS, 0..) |rung, i| {
        print("    Rung {d}: threshold={d:.1}h kill={d:.0}% min_fitness={d:.1}\n", .{
            i, rung.time_threshold_hours, rung.kill_ratio * 100, rung.min_fitness,
        });
    }
    print("\n  {s}Scanning accounts for swe-agent-* services...{s}\n", .{ DIM, RESET });
    print("  {s}State will be saved to .trinity/dev_evolution.json{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP — evaluate fitness, kill worst, mutate best
// ═══════════════════════════════════════════════════════════════════════════════

fn runStep(allocator: Allocator) !void {
    _ = allocator;
    print("\n{s}🧬 DEV EVOLUTION — STEP{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}No agents to evolve yet. Run `tri dev spawn` first.{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — show leaderboard with fitness breakdown
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator) !void {
    _ = allocator;
    print("\n{s}🧬 DEV EVOLUTION — STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Generation: 0\n", .{});
    print("  Population: 0 agents\n", .{});
    print("  {s}RANK  SERVICE             FITNESS  TEST   SPEC   TIME    MERGED{s}\n", .{ DIM, RESET });
    print("  {s}──────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    print("  {s}(empty — no completed runs){s}\n\n", .{ DIM, RESET });
}

fn printHelp() void {
    print("\n{s}TRI DEV EVOLVE — ASHA+PBT Evolution for SWE Agents{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev evolve init{s}     Scan accounts, build initial state\n", .{ CYAN, RESET });
    print("  {s}tri dev evolve step{s}     Execute one evolution cycle\n", .{ CYAN, RESET });
    print("  {s}tri dev evolve status{s}   Show leaderboard + rung progress\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FitnessMetrics.totalScore" {
    const f = FitnessMetrics{
        .test_pass_rate = 1.0,
        .spec_compliance = 0.8,
        .time_hours = 0.5,
        .pr_merged = true,
    };
    const score = f.totalScore();
    // 0.4*1.0 + 0.3*0.8 + 0.2*min(1.0, 1/0.5) + 0.1*1.0 = 0.4 + 0.24 + 0.2 + 0.1 = 0.94
    try std.testing.expect(score > 0.9 and score < 1.0);
}

test "FitnessMetrics.totalScore zero" {
    const f = FitnessMetrics{};
    try std.testing.expectEqual(@as(f32, 0.0), f.totalScore());
}

test "EvolutionRung defaults" {
    try std.testing.expectEqual(@as(usize, 3), DEFAULT_RUNGS.len);
    try std.testing.expect(DEFAULT_RUNGS[0].kill_ratio == 0.5);
}
