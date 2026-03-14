// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV FARM EVOLVE — ASHA+PBT Evolution for SWE Agents
// ═══════════════════════════════════════════════════════════════════════════════
//
// Generated from: specs/tri/dev_evolve.tri
// Reads shared state from .trinity/dev_agents.json (via tri_dev.zig)
//
// Fitness = 0.4*test_pass + 0.3*spec_compliance + 0.2*(1/time) + 0.1*pr_merged
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const tri_dev = @import("tri_dev.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";

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
pub const DEFAULT_RUNGS = [_]EvolutionRung{
    .{ .time_threshold_hours = 0.5, .kill_ratio = 0.5, .min_fitness = 0.2 },
    .{ .time_threshold_hours = 1.0, .kill_ratio = 0.33, .min_fitness = 0.4 },
    .{ .time_threshold_hours = 2.0, .kill_ratio = 0.25, .min_fitness = 0.6 },
};

const MAX_AGENTS = tri_dev.MAX_DEV_AGENTS;

// ═══════════════════════════════════════════════════════════════════════════════
// RUNG EVALUATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Find current rung based on elapsed hours of the oldest agent
pub fn findCurrentRung(elapsed_hours: f32) ?usize {
    var best: ?usize = null;
    for (DEFAULT_RUNGS, 0..) |rung, i| {
        if (elapsed_hours >= rung.time_threshold_hours) {
            best = i;
        }
    }
    return best;
}

/// Determine which agents to kill at a given rung
pub fn evaluateKills(
    agents: []const tri_dev.DevAgentEntry,
    rung: EvolutionRung,
) struct { kill_count: usize, survivors: usize } {
    var with_fitness: usize = 0;
    var below_min: usize = 0;

    for (agents) |*a| {
        if (a.has_fitness) {
            with_fitness += 1;
            if (a.fitness.totalScore() < rung.min_fitness) {
                below_min += 1;
            }
        }
    }

    if (with_fitness == 0) return .{ .kill_count = 0, .survivors = 0 };

    // Kill either by ratio or by min_fitness threshold, whichever kills more
    const ratio_kills = @as(usize, @intFromFloat(@floor(@as(f32, @floatFromInt(with_fitness)) * rung.kill_ratio)));
    const kill_count = @max(ratio_kills, below_min);

    // Never kill all — keep at least 1
    const safe_kills = @min(kill_count, if (with_fitness > 1) with_fitness - 1 else 0);

    return .{ .kill_count = safe_kills, .survivors = with_fitness - safe_kills };
}

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
// INIT — display population from shared state
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator) !void {
    print("\n{s}🧬 DEV EVOLUTION — INIT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    const state = tri_dev.loadState(allocator);

    print("  Population: {s}{d} agents{s}\n", .{ BOLD, state.agent_count, RESET });

    var with_fitness: usize = 0;
    for (state.agents[0..state.agent_count]) |*a| {
        if (a.has_fitness) with_fitness += 1;
    }
    print("  With fitness: {d}\n", .{with_fitness});

    print("\n  {s}ASHA Rungs:{s}\n", .{ CYAN, RESET });
    for (DEFAULT_RUNGS, 0..) |rung, i| {
        print("    Rung {d}: after {d:.1}h → kill {d:.0}% below {d:.1} fitness\n", .{
            i, rung.time_threshold_hours, rung.kill_ratio * 100, rung.min_fitness,
        });
    }

    if (state.agent_count == 0) {
        print("\n  {s}No agents tracked. Run `tri dev spawn <issue>` first.{s}\n\n", .{ YELLOW, RESET });
    } else {
        print("\n  {s}Ready. Run `tri dev evolve step` to evaluate.{s}\n\n", .{ GREEN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP — evaluate fitness, identify kills, suggest mutations
// ═══════════════════════════════════════════════════════════════════════════════

fn runStep(allocator: Allocator) !void {
    print("\n{s}🧬 DEV EVOLUTION — STEP{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    const state = tri_dev.loadState(allocator);

    if (state.agent_count == 0) {
        print("  {s}No agents to evolve. Run `tri dev spawn` first.{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Find oldest agent to determine elapsed time
    var oldest_start: u64 = std.math.maxInt(u64);
    var with_fitness: usize = 0;

    for (state.agents[0..state.agent_count]) |*a| {
        if (a.started_at > 0 and a.started_at < oldest_start) {
            oldest_start = a.started_at;
        }
        if (a.has_fitness) with_fitness += 1;
    }

    const now: u64 = @intCast(std.time.timestamp());
    const elapsed_secs = if (now > oldest_start) now - oldest_start else 0;
    const elapsed_hours: f32 = @as(f32, @floatFromInt(elapsed_secs)) / 3600.0;

    print("  Elapsed: {d:.1}h | Agents: {d} | With fitness: {d}\n", .{ elapsed_hours, state.agent_count, with_fitness });

    // Find current rung
    const rung_idx = findCurrentRung(elapsed_hours);
    if (rung_idx == null) {
        print("  {s}Too early for evaluation (min threshold: {d:.1}h){s}\n\n", .{
            YELLOW, DEFAULT_RUNGS[0].time_threshold_hours, RESET,
        });
        return;
    }

    const rung = DEFAULT_RUNGS[rung_idx.?];
    print("  Current rung: {d} (threshold: {d:.1}h, kill: {d:.0}%, min_fitness: {d:.1})\n\n", .{
        rung_idx.?, rung.time_threshold_hours, rung.kill_ratio * 100, rung.min_fitness,
    });

    if (with_fitness == 0) {
        print("  {s}No agents have fitness data yet. Wait for pipeline completion.{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    // Sort agents by fitness for display
    var sorted: [MAX_AGENTS]struct { idx: usize, score: f32 } = undefined;
    var sorted_count: usize = 0;

    for (state.agents[0..state.agent_count], 0..) |*a, i| {
        if (a.has_fitness) {
            sorted[sorted_count] = .{ .idx = i, .score = a.fitness.totalScore() };
            sorted_count += 1;
        }
    }

    // Insertion sort descending
    for (1..sorted_count) |si| {
        var j = si;
        while (j > 0 and sorted[j].score > sorted[j - 1].score) {
            const tmp = sorted[j];
            sorted[j] = sorted[j - 1];
            sorted[j - 1] = tmp;
            j -= 1;
        }
    }

    // Evaluate kills
    const eval = evaluateKills(state.agents[0..state.agent_count], rung);

    print("  {s}AGENT          ISSUE   FITNESS  VERDICT{s}\n", .{ DIM, RESET });
    print("  {s}──────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (sorted[0..sorted_count], 0..) |s, rank| {
        const a = &state.agents[s.idx];
        const is_kill = rank >= sorted_count - eval.kill_count;
        const verdict_icon = if (is_kill) "💀 KILL" else "✅ SURVIVE";
        const color = if (is_kill) RED else GREEN;

        print("  {s}{s}{s}", .{ color, a.svcName(), RESET });
        tri_dev.padTo(a.svcName().len, 15);
        print("#{d}", .{a.issue_number});
        tri_dev.padTo(tri_dev.digitCount(a.issue_number) + 1, 8);
        print("{d:.3}    {s}{s}{s}\n", .{ s.score, color, verdict_icon, RESET });
    }

    print("\n  {s}Kill: {d} | Survive: {d}{s}\n", .{ BOLD, eval.kill_count, eval.survivors, RESET });

    if (eval.kill_count > 0) {
        print("\n  {s}To execute kills:{s}\n", .{ YELLOW, RESET });
        var kill_start = sorted_count - eval.kill_count;
        while (kill_start < sorted_count) : (kill_start += 1) {
            const a = &state.agents[sorted[kill_start].idx];
            print("    tri dev kill {d}  {s}# {s} (fitness={d:.3}){s}\n", .{
                a.issue_number, DIM, a.svcName(), sorted[kill_start].score, RESET,
            });
        }
    }

    // Suggest mutations from best performer
    if (eval.kill_count > 0 and sorted_count > 0) {
        const best = &state.agents[sorted[0].idx];
        print("\n  {s}Mutation suggestions (PBT exploit from #{d}):{s}\n", .{ CYAN, best.issue_number, RESET });
        print("    tri dev spawn <new-issue> --role reviewer  {s}# try different role{s}\n", .{ DIM, RESET });
        print("    tri dev spawn <new-issue> --model glm-5    {s}# try cheaper model{s}\n", .{ DIM, RESET });
    }

    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — leaderboard from shared state
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator) !void {
    print("\n{s}🧬 DEV EVOLUTION — STATUS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    const state = tri_dev.loadState(allocator);

    print("  Population: {d} agents\n", .{state.agent_count});

    if (state.agent_count == 0) {
        print("  {s}(empty — run `tri dev spawn` to start){s}\n\n", .{ DIM, RESET });
        return;
    }

    // Compute elapsed time from oldest agent
    var oldest_start: u64 = std.math.maxInt(u64);
    var with_fitness: usize = 0;
    var total_fitness: f32 = 0.0;
    var best_fitness: f32 = 0.0;

    for (state.agents[0..state.agent_count]) |*a| {
        if (a.started_at > 0 and a.started_at < oldest_start) {
            oldest_start = a.started_at;
        }
        if (a.has_fitness) {
            with_fitness += 1;
            const score = a.fitness.totalScore();
            total_fitness += score;
            if (score > best_fitness) best_fitness = score;
        }
    }

    const now: u64 = @intCast(std.time.timestamp());
    const elapsed_secs = if (now > oldest_start and oldest_start < std.math.maxInt(u64)) now - oldest_start else 0;
    const elapsed_hours: f32 = @as(f32, @floatFromInt(elapsed_secs)) / 3600.0;

    print("  With fitness: {d}/{d}\n", .{ with_fitness, state.agent_count });
    print("  Elapsed: {d:.1}h\n", .{elapsed_hours});

    if (with_fitness > 0) {
        print("  Best fitness: {s}{d:.3}{s}\n", .{ GREEN, best_fitness, RESET });
        print("  Avg fitness:  {d:.3}\n", .{total_fitness / @as(f32, @floatFromInt(with_fitness))});
    }

    // Rung progress
    const rung_idx = findCurrentRung(elapsed_hours);
    print("\n  {s}Rung Progress:{s}\n", .{ CYAN, RESET });
    for (DEFAULT_RUNGS, 0..) |rung, i| {
        const reached = if (rung_idx) |ri| i <= ri else false;
        const icon = if (reached) "✅" else "⏳";
        print("    {s} Rung {d}: {d:.1}h — kill {d:.0}%, min {d:.1}\n", .{
            icon, i, rung.time_threshold_hours, rung.kill_ratio * 100, rung.min_fitness,
        });
    }

    // Leaderboard
    if (with_fitness > 0) {
        print("\n  {s}RANK  SERVICE             FITNESS  TEST   SPEC   TIME    PR{s}\n", .{ DIM, RESET });
        print("  {s}──────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

        // Sort
        var sorted: [MAX_AGENTS]struct { idx: usize, score: f32 } = undefined;
        var sorted_count: usize = 0;
        for (state.agents[0..state.agent_count], 0..) |*a, i| {
            if (a.has_fitness) {
                sorted[sorted_count] = .{ .idx = i, .score = a.fitness.totalScore() };
                sorted_count += 1;
            }
        }
        for (1..sorted_count) |si| {
            var j = si;
            while (j > 0 and sorted[j].score > sorted[j - 1].score) {
                const tmp = sorted[j];
                sorted[j] = sorted[j - 1];
                sorted[j - 1] = tmp;
                j -= 1;
            }
        }

        for (sorted[0..sorted_count], 0..) |s, rank| {
            const a = &state.agents[s.idx];
            const medal = if (rank == 0) "🥇" else if (rank == 1) "🥈" else if (rank == 2) "🥉" else "  ";
            const pr_str = if (a.fitness.pr_merged) "YES" else "no";

            print("  {s} {d}", .{ medal, rank + 1 });
            tri_dev.padTo(tri_dev.digitCount(@intCast(rank + 1)), 6);
            print("{s}", .{a.svcName()});
            tri_dev.padTo(a.svcName().len, 20);
            print("{s}{d:.3}{s}", .{ BOLD, s.score, RESET });
            tri_dev.padTo(5, 9);
            print("{d:.1}   {d:.1}   {d:.1}h    {s}\n", .{
                a.fitness.test_pass_rate,
                a.fitness.spec_compliance,
                a.fitness.time_hours,
                pr_str,
            });
        }
    }

    print("\n", .{});
}

fn printHelp() void {
    print("\n{s}TRI DEV EVOLVE — ASHA+PBT Evolution for SWE Agents{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev evolve init{s}     Show population + rung config\n", .{ CYAN, RESET });
    print("  {s}tri dev evolve step{s}     Evaluate fitness, identify kills\n", .{ CYAN, RESET });
    print("  {s}tri dev evolve status{s}   Leaderboard + rung progress\n\n", .{ CYAN, RESET });
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

test "findCurrentRung" {
    try std.testing.expect(findCurrentRung(0.1) == null);
    try std.testing.expectEqual(@as(usize, 0), findCurrentRung(0.5).?);
    try std.testing.expectEqual(@as(usize, 1), findCurrentRung(1.5).?);
    try std.testing.expectEqual(@as(usize, 2), findCurrentRung(3.0).?);
}

test "evaluateKills no fitness" {
    var agents: [2]tri_dev.DevAgentEntry = undefined;
    agents[0] = .{};
    agents[0].has_fitness = false;
    agents[1] = .{};
    agents[1].has_fitness = false;
    const result = evaluateKills(&agents, DEFAULT_RUNGS[0]);
    try std.testing.expectEqual(@as(usize, 0), result.kill_count);
}

test "evaluateKills with fitness" {
    var agents: [4]tri_dev.DevAgentEntry = undefined;
    for (&agents, 0..) |*a, i| {
        a.* = .{};
        a.has_fitness = true;
        a.fitness.test_pass_rate = @as(f32, @floatFromInt(i)) * 0.25; // 0.0, 0.25, 0.5, 0.75
        a.fitness.spec_compliance = 0.5;
    }
    // Rung 0: kill_ratio=0.5, min_fitness=0.2
    const result = evaluateKills(&agents, DEFAULT_RUNGS[0]);
    // 4 agents * 0.5 = 2 ratio kills; agents[0] fitness ~0.15 < 0.2 = 1 below min
    // max(2, 1) = 2, but keep at least 1, so kill min(2, 3) = 2
    try std.testing.expectEqual(@as(usize, 2), result.kill_count);
    try std.testing.expectEqual(@as(usize, 2), result.survivors);
}

test "evaluateKills never kills all" {
    var agents: [1]tri_dev.DevAgentEntry = undefined;
    agents[0] = .{};
    agents[0].has_fitness = true;
    agents[0].fitness.test_pass_rate = 0.0; // terrible fitness
    const result = evaluateKills(&agents, DEFAULT_RUNGS[0]);
    try std.testing.expectEqual(@as(usize, 0), result.kill_count); // can't kill the only one
    try std.testing.expectEqual(@as(usize, 1), result.survivors);
}
