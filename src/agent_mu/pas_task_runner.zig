//! PAS Task Runner v8.20 — PAS-enhanced task execution with comparison
//!
//! Runs tasks with and without PAS to generate before/after comparison.
//! Tracks metrics: attempts, success rate, time, energy harvested.
//!
//! Features:
//!   - Baseline execution (without PAS)
//!   - PAS-assisted execution (with PAS)
//!   - Comparison report generation
//!   - Sacred constant validation

const std = @import("std");

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS (PAS v8.20)
// ═══════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.6180339887498949;
const PHI_SQ: f64 = 2.6180339887498949;
const PHI_INV_SQ: f64 = 0.3819660112501051;
const TRINITY: f64 = 3.0;
const MU: f64 = 0.0382;
const CHI: f64 = 0.0618;
const SIGMA: f64 = 1.618;
const EPSILON: f64 = 0.333;
const LUCAS_10: u64 = 123;
const PHOENIX: usize = 999;

/// PAS SU3 Core for energy harvesting
pub const SU3Core = struct {
    berry_phase: f64,
    pas_energy: f64,

    pub fn init() SU3Core {
        return SU3Core{
            .berry_phase = 0.0,
            .pas_energy = 0.0,
        };
    }

    /// Harvest entropy from data
    pub fn harvestEntropy(self: *SU3Core, data: []const u8) f64 {
        var entropy: f64 = 0.0;
        for (data) |byte| {
            const trit = @mod(@as(i8, @bitCast(byte)), 3) - 1;
            entropy += @as(f64, @floatFromInt(trit)) * PHI_INV_SQ;
        }
        const pas_gain = entropy * 578.84;
        self.pas_energy += pas_gain;
        return pas_gain;
    }
};

/// Task execution result
pub const TaskResult = struct {
    /// Task identifier
    task_id: []const u8,
    /// Whether PAS was enabled
    pas_enabled: bool,
    /// Number of attempts made
    attempts: usize,
    /// Number of successful attempts
    successes: usize,
    /// Success rate (0-1)
    success_rate: f64,
    /// Total execution time (milliseconds)
    total_time_ms: u64,
    /// Average time per attempt (milliseconds)
    avg_time_ms: f64,
    /// Energy harvested by PAS (0 if PAS disabled)
    energy_harvested: f64,
    /// Berry phase at end
    berry_phase: f64,
    /// Timestamp of completion
    timestamp: i64,
};

/// Comparison between baseline and PAS results
pub const TaskComparison = struct {
    /// Task identifier
    task_id: []const u8,
    /// Baseline result (without PAS)
    baseline: TaskResult,
    /// PAS result (with PAS)
    pas_result: TaskResult,
    /// Improvement in success rate (absolute difference)
    success_rate_improvement: f64,
    /// Speed improvement factor (baseline_time / pas_time)
    speed_improvement: f64,
    /// Whether PAS was better (positive = PAS better)
    pas_better: bool,
    /// Verdict string
    verdict: []const u8,

    /// Format as JSON
    pub fn formatJson(self: *const TaskComparison, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"task_id":"{s}",
            \\"baseline":{{"attempts":{d},"successes":{d},"success_rate":{d:.3},"avg_time_ms":{d:.1}}},
            \\"pas":{{"attempts":{d},"successes":{d},"success_rate":{d:.3},"avg_time_ms":{d:.1},"energy_harvested":{d:.2}}},
            \\"success_rate_improvement":{d:.3},
            \\"speed_improvement":{d:.2},
            \\"pas_better":{s},
            \\"verdict":"{s}"}}
        , .{
            self.task_id,
            self.baseline.attempts, self.baseline.successes, self.baseline.success_rate, self.baseline.avg_time_ms,
            self.pas_result.attempts, self.pas_result.successes, self.pas_result.success_rate, self.pas_result.avg_time_ms, self.pas_result.energy_harvested,
            self.success_rate_improvement,
            self.speed_improvement,
            if (self.pas_better) "true" else "false",
            self.verdict,
        });
    }
};

/// PAS Task Runner
pub const PasTaskRunner = struct {
    allocator: Allocator,
    /// PAS core for energy harvesting
    pas_core: SU3Core,
    /// Task results storage
    results: std.StringHashMap(TaskResult),

    /// Initialize PAS Task Runner
    pub fn init(allocator: Allocator) PasTaskRunner {
        return PasTaskRunner{
            .allocator = allocator,
            .pas_core = SU3Core.init(),
            .results = std.StringHashMap(TaskResult).init(allocator),
        };
    }

    /// Deinitialize
    pub fn deinit(self: *PasTaskRunner) void {
        var iter = self.results.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.results.deinit();
    }

    /// Run a simulated task WITHOUT PAS (baseline)
    pub fn runBaseline(self: *PasTaskRunner, task_id: []const u8, simulate_fn: *const fn (usize) bool) !TaskResult {
        const start_time = std.time.nanoTimestamp();
        var attempts: usize = 0;
        var successes: usize = 0;

        // Run up to 100 attempts or until 10 successes
        while (attempts < 100 and successes < 10) : (attempts += 1) {
            if (simulate_fn(attempts)) {
                successes += 1;
            }
        }

        const end_time = std.time.nanoTimestamp();
        const elapsed_ns = end_time - start_time;
        const total_time_ms = @as(u64, @intCast(@divTrunc(elapsed_ns, 1_000_000)));
        const avg_time_ms = @as(f64, @floatFromInt(total_time_ms)) / @as(f64, @floatFromInt(attempts));
        const success_rate = @as(f64, @floatFromInt(successes)) / @as(f64, @floatFromInt(attempts));

        const result = TaskResult{
            .task_id = try self.allocator.dupe(u8, task_id),
            .pas_enabled = false,
            .attempts = attempts,
            .successes = successes,
            .success_rate = success_rate,
            .total_time_ms = total_time_ms,
            .avg_time_ms = avg_time_ms,
            .energy_harvested = 0.0,
            .berry_phase = 0.0,
            .timestamp = @as(i64, @intCast(std.time.nanoTimestamp())),
        };

        try self.results.put(try std.fmt.allocPrint(self.allocator, "{s}_baseline", .{task_id}), result);
        return result;
    }

    /// Run a simulated task WITH PAS
    pub fn runWithPas(self: *PasTaskRunner, task_id: []const u8, simulate_fn: *const fn (usize, bool) bool) !TaskResult {
        const start_time = std.time.nanoTimestamp();
        var attempts: usize = 0;
        var successes: usize = 0;

        // Run up to 100 attempts or until 10 successes
        while (attempts < 100 and successes < 10) : (attempts += 1) {
            // Harvest entropy from attempt number
            var buf: [32]u8 = undefined;
            const attempt_str = try std.fmt.bufPrint(&buf, "attempt_{d}", .{attempts});
            _ = self.pas_core.harvestEntropy(attempt_str);

            // Run simulation with PAS hint
            if (simulate_fn(attempts, true)) {
                successes += 1;
            }
        }

        const end_time = std.time.nanoTimestamp();
        const elapsed_ns = end_time - start_time;
        const total_time_ms = @as(u64, @intCast(@divTrunc(elapsed_ns, 1_000_000)));
        const avg_time_ms = @as(f64, @floatFromInt(total_time_ms)) / @as(f64, @floatFromInt(attempts));
        const success_rate = @as(f64, @floatFromInt(successes)) / @as(f64, @floatFromInt(attempts));

        const result = TaskResult{
            .task_id = try self.allocator.dupe(u8, task_id),
            .pas_enabled = true,
            .attempts = attempts,
            .successes = successes,
            .success_rate = success_rate,
            .total_time_ms = total_time_ms,
            .avg_time_ms = avg_time_ms,
            .energy_harvested = self.pas_core.pas_energy,
            .berry_phase = self.pas_core.berry_phase,
            .timestamp = @as(i64, @intCast(std.time.nanoTimestamp())),
        };

        try self.results.put(try std.fmt.allocPrint(self.allocator, "{s}_pas", .{task_id}), result);
        return result;
    }

    /// Run task with both baseline and PAS, return comparison
    pub fn runComparison(
        self: *PasTaskRunner,
        task_id: []const u8,
        baseline_fn: *const fn (usize) bool,
        pas_fn: *const fn (usize, bool) bool,
    ) !TaskComparison {
        // Run baseline first
        const baseline = try self.runBaseline(task_id, baseline_fn);

        // Reset PAS core for PAS run
        self.pas_core = SU3Core.init();

        // Run with PAS
        const pas_result = try self.runWithPas(task_id, pas_fn);

        // Calculate improvements
        const success_rate_improvement = pas_result.success_rate - baseline.success_rate;
        const speed_improvement = if (pas_result.avg_time_ms > 0)
            baseline.avg_time_ms / pas_result.avg_time_ms
        else
            1.0;

        // Determine verdict
        const pas_better = success_rate_improvement > 0 or speed_improvement > 1.0;
        const verdict = if (success_rate_improvement > 0.1)
            "PAS significantly improved success rate"
        else if (speed_improvement > 1.2)
            "PAS significantly improved speed"
        else if (pas_better)
            "PAS showed marginal improvement"
        else
            "Baseline was better or equal";

        return TaskComparison{
            .task_id = try self.allocator.dupe(u8, task_id),
            .baseline = baseline,
            .pas_result = pas_result,
            .success_rate_improvement = success_rate_improvement,
            .speed_improvement = speed_improvement,
            .pas_better = pas_better,
            .verdict = verdict,
        };
    }

    /// Get stored result
    pub fn getResult(self: *const PasTaskRunner, key: []const u8) ?TaskResult {
        return self.results.get(key);
    }

    /// Get all results
    pub fn getAllResults(self: *const PasTaskRunner) []const struct { []const u8, TaskResult } {
        return self.results.entries();
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════

/// Simulated task: 30% success rate, PAS improves to 50%
fn simulatedTask(attempt: usize) bool {
    _ = attempt;
    const rand = @as(u32, @truncate(@as(u64, @intCast(@rem(std.time.nanoTimestamp(), 1000)))));
    return rand % 10 < 3; // 30% success
}

/// Simulated task with PAS hint: 50% success rate
fn simulatedTaskWithPas(attempt: usize, pas_hint: bool) bool {
    _ = attempt;
    _ = pas_hint;
    const rand = @as(u32, @truncate(@as(u64, @intCast(@rem(std.time.nanoTimestamp(), 1000)))));
    return rand % 10 < 5; // 50% success with PAS
}

test "PasTaskRunner: baseline execution" {
    var runner = PasTaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const result = try runner.runBaseline("test_task", simulatedTask);

    try std.testing.expect(result.attempts > 0);
    try std.testing.expect(!result.pas_enabled);
    try std.testing.expectEqual(@as(f64, 0.0), result.energy_harvested);
}

test "PasTaskRunner: PAS execution" {
    var runner = PasTaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const result = try runner.runWithPas("test_task", simulatedTaskWithPas);

    try std.testing.expect(result.attempts > 0);
    try std.testing.expect(result.pas_enabled);
    try std.testing.expect(result.energy_harvested > 0);
}

test "PasTaskRunner: comparison" {
    var runner = PasTaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const comparison = try runner.runComparison("test_task", simulatedTask, simulatedTaskWithPas);

    try std.testing.expect(comparison.baseline.attempts > 0);
    try std.testing.expect(comparison.pas_result.attempts > 0);
    try std.testing.expect(comparison.pas_result.pas_enabled);
    try std.testing.expect(!comparison.baseline.pas_enabled);
}
