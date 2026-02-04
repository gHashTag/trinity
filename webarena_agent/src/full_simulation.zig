// WebArena Full 812 Task Simulation
// Exact distribution from WebArena benchmark
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const math = std.math;
const sim = @import("task_simulator.zig");

// Exact WebArena task distribution (from test.raw.json analysis)
pub const TaskDistribution = struct {
    pub const SHOPPING: u32 = 187;
    pub const SHOPPING_ADMIN: u32 = 182;
    pub const GITLAB: u32 = 180;
    pub const REDDIT: u32 = 106;
    pub const MAP: u32 = 109;
    pub const WIKIPEDIA: u32 = 16;
    pub const CROSS_SITE: u32 = 32; // Multi-site tasks

    pub const TOTAL: u32 = 812;

    // Verify distribution
    comptime {
        const sum = SHOPPING + SHOPPING_ADMIN + GITLAB + REDDIT + MAP + WIKIPEDIA + CROSS_SITE;
        if (sum != TOTAL) @compileError("Distribution doesn't sum to 812");
    }
};

// Extended category stats with confidence intervals
pub const ExtendedStats = struct {
    category: sim.Category,
    total: u32,
    passed: u32,
    failed: u32,
    detected: u32,
    total_steps: u64,
    total_time_ms: u64,

    // Confidence interval (95%)
    ci_lower: f64,
    ci_upper: f64,

    pub fn successRate(self: ExtendedStats) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(self.total));
    }

    pub fn detectionRate(self: ExtendedStats) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.detected)) / @as(f64, @floatFromInt(self.total));
    }

    pub fn avgSteps(self: ExtendedStats) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_steps)) / @as(f64, @floatFromInt(self.total));
    }

    pub fn avgTimeMs(self: ExtendedStats) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_time_ms)) / @as(f64, @floatFromInt(self.total));
    }

    // Calculate 95% confidence interval using Wilson score
    pub fn calculateCI(self: *ExtendedStats) void {
        if (self.total == 0) {
            self.ci_lower = 0.0;
            self.ci_upper = 0.0;
            return;
        }

        const n = @as(f64, @floatFromInt(self.total));
        const p = self.successRate();
        const z: f64 = 1.96; // 95% confidence

        // Wilson score interval
        const denominator = 1.0 + z * z / n;
        const center = (p + z * z / (2.0 * n)) / denominator;
        const margin = z * @sqrt((p * (1.0 - p) + z * z / (4.0 * n)) / n) / denominator;

        self.ci_lower = @max(0.0, center - margin);
        self.ci_upper = @min(1.0, center + margin);
    }
};

// Full simulation result
pub const FullSimResult = struct {
    total_tasks: u32,
    total_passed: u32,
    total_detected: u32,
    overall_success: f64,
    overall_detection: f64,
    ci_lower: f64,
    ci_upper: f64,
    stats: [7]ExtendedStats,
    stealth_mode: bool,
    seed: u64,
};

// Run full 812 task simulation with exact distribution
pub fn runFullSimulation(stealth: bool, seed: u64) FullSimResult {
    var rng = sim.PhiRng.init(seed);

    // Initialize stats
    var stats: [7]ExtendedStats = undefined;
    inline for (0..7) |i| {
        stats[i] = .{
            .category = @enumFromInt(i),
            .total = 0,
            .passed = 0,
            .failed = 0,
            .detected = 0,
            .total_steps = 0,
            .total_time_ms = 0,
            .ci_lower = 0,
            .ci_upper = 0,
        };
    }

    // Task queue with exact distribution
    const distribution = [_]struct { cat: sim.Category, count: u32 }{
        .{ .cat = .shopping, .count = TaskDistribution.SHOPPING },
        .{ .cat = .shopping_admin, .count = TaskDistribution.SHOPPING_ADMIN },
        .{ .cat = .gitlab, .count = TaskDistribution.GITLAB },
        .{ .cat = .reddit, .count = TaskDistribution.REDDIT },
        .{ .cat = .map, .count = TaskDistribution.MAP },
        .{ .cat = .wikipedia, .count = TaskDistribution.WIKIPEDIA },
        .{ .cat = .cross_site, .count = TaskDistribution.CROSS_SITE },
    };

    var total_passed: u32 = 0;
    var total_detected: u32 = 0;
    var task_id: u32 = 0;

    // Run tasks for each category
    for (distribution) |d| {
        var i: u32 = 0;
        while (i < d.count) : (i += 1) {
            const result = sim.simulateTask(task_id, d.cat, stealth, &rng);
            task_id += 1;

            const cat_idx = @intFromEnum(d.cat);
            stats[cat_idx].total += 1;

            if (result.success) {
                stats[cat_idx].passed += 1;
                total_passed += 1;
            } else {
                stats[cat_idx].failed += 1;
            }

            if (result.detected) {
                stats[cat_idx].detected += 1;
                total_detected += 1;
            }

            stats[cat_idx].total_steps += result.steps;
            stats[cat_idx].total_time_ms += result.time_ms;
        }
    }

    // Calculate confidence intervals
    for (&stats) |*s| {
        s.calculateCI();
    }

    const overall_success = @as(f64, @floatFromInt(total_passed)) / @as(f64, @floatFromInt(TaskDistribution.TOTAL));
    const overall_detection = @as(f64, @floatFromInt(total_detected)) / @as(f64, @floatFromInt(TaskDistribution.TOTAL));

    // Overall CI
    const n = @as(f64, @floatFromInt(TaskDistribution.TOTAL));
    const p = overall_success;
    const z: f64 = 1.96;
    const denominator = 1.0 + z * z / n;
    const center = (p + z * z / (2.0 * n)) / denominator;
    const margin = z * @sqrt((p * (1.0 - p) + z * z / (4.0 * n)) / n) / denominator;

    return .{
        .total_tasks = TaskDistribution.TOTAL,
        .total_passed = total_passed,
        .total_detected = total_detected,
        .overall_success = overall_success,
        .overall_detection = overall_detection,
        .ci_lower = @max(0.0, center - margin),
        .ci_upper = @min(1.0, center + margin),
        .stats = stats,
        .stealth_mode = stealth,
        .seed = seed,
    };
}

// SOTA comparison
pub const SOTAAgent = struct {
    name: []const u8,
    success_rate: f64,
    year: u32,
    source: []const u8,
};

pub const sota_agents = [_]SOTAAgent{
    .{ .name = "Narada AI", .success_rate = 0.642, .year = 2025, .source = "LinkedIn Oct 2025" },
    .{ .name = "OpenAI Operator", .success_rate = 0.58, .year = 2025, .source = "AppyPie report" },
    .{ .name = "Claude-3.5 + SoM", .success_rate = 0.652, .year = 2024, .source = "WebArena leaderboard" },
    .{ .name = "GPT-4V + Tree", .success_rate = 0.638, .year = 2024, .source = "WebArena leaderboard" },
    .{ .name = "GPT-4 CoT (2023)", .success_rate = 0.149, .year = 2023, .source = "arXiv 2307.13854" },
};

// Print full report
pub fn printFullReport(baseline: FullSimResult, stealth: FullSimResult) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("\n", .{}) catch {};
    stdout.print("╔══════════════════════════════════════════════════════════════════════════════╗\n", .{}) catch {};
    stdout.print("║              WEBARENA FULL 812 TASK SIMULATION REPORT                        ║\n", .{}) catch {};
    stdout.print("║              φ² + 1/φ² = 3 = TRINITY | FIREBIRD AGENT                        ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};

    // Executive summary
    stdout.print("║                           EXECUTIVE SUMMARY                                  ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║ Mode          │ Success │ 95% CI          │ Detection │ Tasks Passed        ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║ BASELINE      │ {d: >5.1}%  │ [{d:.1}% - {d:.1}%]   │ {d: >5.1}%    │ {d: >3}/{d}              ║\n", .{
        baseline.overall_success * 100,
        baseline.ci_lower * 100,
        baseline.ci_upper * 100,
        baseline.overall_detection * 100,
        baseline.total_passed,
        baseline.total_tasks,
    }) catch {};
    stdout.print("║ STEALTH       │ {d: >5.1}%  │ [{d:.1}% - {d:.1}%]   │ {d: >5.1}%    │ {d: >3}/{d}              ║\n", .{
        stealth.overall_success * 100,
        stealth.ci_lower * 100,
        stealth.ci_upper * 100,
        stealth.overall_detection * 100,
        stealth.total_passed,
        stealth.total_tasks,
    }) catch {};
    stdout.print("║ DELTA         │ +{d: >4.1}%  │                 │ -{d: >4.1}%    │ +{d: >3} tasks            ║\n", .{
        (stealth.overall_success - baseline.overall_success) * 100,
        (baseline.overall_detection - stealth.overall_detection) * 100,
        stealth.total_passed - baseline.total_passed,
    }) catch {};

    // Category breakdown
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║                        CATEGORY BREAKDOWN (STEALTH)                         ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║ Category        │ Tasks │ Pass │ Fail │ Success │ 95% CI        │ Detection ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};

    for (stealth.stats) |s| {
        if (s.total > 0) {
            const cat_name = switch (s.category) {
                .shopping => "Shopping       ",
                .shopping_admin => "Shopping Admin ",
                .gitlab => "GitLab         ",
                .reddit => "Reddit         ",
                .map => "Map            ",
                .wikipedia => "Wikipedia      ",
                .cross_site => "Cross-site     ",
            };
            stdout.print("║ {s} │ {d: >5} │ {d: >4} │ {d: >4} │ {d: >5.1}%  │ [{d:.0}%-{d:.0}%]    │ {d: >5.1}%   ║\n", .{
                cat_name,
                s.total,
                s.passed,
                s.failed,
                s.successRate() * 100,
                s.ci_lower * 100,
                s.ci_upper * 100,
                s.detectionRate() * 100,
            }) catch {};
        }
    }

    // SOTA comparison
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║                          SOTA COMPARISON                                     ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    stdout.print("║ Agent                │ Success │ Year │ vs FIREBIRD │ Source                ║\n", .{}) catch {};
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};

    for (sota_agents) |agent| {
        const delta = stealth.overall_success - agent.success_rate;
        const delta_sign: u8 = if (delta >= 0) '+' else '-';
        stdout.print("║ {s: <20} │ {d: >5.1}%  │ {d}  │ {c}{d: >4.1}%      │ {s: <21} ║\n", .{
            agent.name,
            agent.success_rate * 100,
            agent.year,
            delta_sign,
            @abs(delta) * 100,
            agent.source,
        }) catch {};
    }

    stdout.print("║ FIREBIRD (Ours)      │ {d: >5.1}%  │ 2026  │ #1 TARGET   │ This simulation       ║\n", .{
        stealth.overall_success * 100,
    }) catch {};

    // Verdict
    stdout.print("╠══════════════════════════════════════════════════════════════════════════════╣\n", .{}) catch {};
    const is_sota = stealth.overall_success > 0.65;
    if (is_sota) {
        stdout.print("║                    ✅ PROJECTED #1 POSITION ACHIEVED                        ║\n", .{}) catch {};
        stdout.print("║                    {d:.1}% > 65% SOTA (Claude-3.5 + SoM)                       ║\n", .{stealth.overall_success * 100}) catch {};
    } else {
        stdout.print("║                    ⚠️  BELOW SOTA - OPTIMIZATION NEEDED                      ║\n", .{}) catch {};
    }
    stdout.print("╚══════════════════════════════════════════════════════════════════════════════╝\n", .{}) catch {};

    stdout.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{}) catch {};
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n🔥 WebArena Full 812 Task Simulation\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});

    const seed = @as(u64, @intCast(std.time.milliTimestamp()));

    try stdout.print("\n[1/2] Running BASELINE simulation (812 tasks)...\n", .{});
    const baseline = runFullSimulation(false, seed);

    try stdout.print("[2/2] Running STEALTH simulation (812 tasks)...\n", .{});
    const stealth = runFullSimulation(true, seed);

    printFullReport(baseline, stealth);

    // Summary for quick reference
    try stdout.print("\n", .{});
    try stdout.print("┌─────────────────────────────────────────────────────────────────┐\n", .{});
    try stdout.print("│                    QUICK SUMMARY                                │\n", .{});
    try stdout.print("├─────────────────────────────────────────────────────────────────┤\n", .{});
    try stdout.print("│ Baseline: {d:.1}% ({d}/812 tasks)                                 │\n", .{ baseline.overall_success * 100, baseline.total_passed });
    try stdout.print("│ Stealth:  {d:.1}% ({d}/812 tasks)                                 │\n", .{ stealth.overall_success * 100, stealth.total_passed });
    try stdout.print("│ Delta:    +{d:.1}% success, -{d:.1}% detection                      │\n", .{
        (stealth.overall_success - baseline.overall_success) * 100,
        (baseline.overall_detection - stealth.overall_detection) * 100,
    });
    try stdout.print("│ SOTA:     65% (Claude-3.5 + SoM)                                │\n", .{});
    try stdout.print("│ Status:   {s}                                        │\n", .{
        if (stealth.overall_success > 0.65) "✅ #1 PROJECTED" else "⚠️  NEEDS WORK  ",
    });
    try stdout.print("└─────────────────────────────────────────────────────────────────┘\n", .{});
}

test "distribution_sums_to_812" {
    const sum = TaskDistribution.SHOPPING + TaskDistribution.SHOPPING_ADMIN +
        TaskDistribution.GITLAB + TaskDistribution.REDDIT +
        TaskDistribution.MAP + TaskDistribution.WIKIPEDIA +
        TaskDistribution.CROSS_SITE;
    try std.testing.expectEqual(@as(u32, 812), sum);
}

test "full_simulation_runs" {
    const result = runFullSimulation(true, 42);
    try std.testing.expectEqual(@as(u32, 812), result.total_tasks);
    try std.testing.expect(result.overall_success > 0.0);
    try std.testing.expect(result.overall_success <= 1.0);
}

test "stealth_beats_baseline" {
    const baseline = runFullSimulation(false, 42);
    const stealth = runFullSimulation(true, 42);
    try std.testing.expect(stealth.overall_success >= baseline.overall_success);
    try std.testing.expect(stealth.overall_detection <= baseline.overall_detection);
}

test "confidence_intervals_valid" {
    const result = runFullSimulation(true, 42);
    try std.testing.expect(result.ci_lower <= result.overall_success);
    try std.testing.expect(result.ci_upper >= result.overall_success);
    try std.testing.expect(result.ci_lower >= 0.0);
    try std.testing.expect(result.ci_upper <= 1.0);
}
