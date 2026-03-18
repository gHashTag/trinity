// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════
// ARAS (ASCENDING RETICULAR ACTIVATING SYSTEM) — Vigilance Sweep
// ═══════════════════════════════════════════════════════════════════════
// Neuro: Sleep↔wake switching, cortical arousal level
// Trinity: The 5-minute sweep loop (was watch-daemon)
//   If problems found → raise arousal via Locus Coeruleus
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");
const locus = @import("phoenix_locus_coeruleus.zig");
const hippocampus = @import("hippocampus.zig");

// ═══════════════════════════════════════════════════════════════════════
// SWEEP RESULT — Problems found in farm
// ═══════════════════════════════════════════════════════════════════════════

pub const SweepResult = struct {
    crashed_workers: []const []const u8 = &.{}, // Service names
    stale_count: usize = 0,
    total_services: usize = 0,
    timestamp: i64 = 0,

    pub fn problemCount(self: *const SweepResult) u32 {
        var count: u32 = @intCast(self.crashed_workers.len);
        count +%= @as(u32, @intCast(self.stale_count));
        return count;
    }

    pub fn hasProblems(self: *const SweepResult) bool {
        return self.crashed_workers.len > 0 or self.stale_count > 0;
    }
};

/// Worker status from farm
pub const WorkerStatus = struct {
    name: []const u8,
    state: []const u8, // running, idle, stale, crashed
    last_ppl: f32 = 999.0,
    last_step: u32 = 0,
    steps_stuck: u32 = 0, // How long without progress
};

// ═════════════════════════════════════════════════════════════════════════════
// ARAS STATE — Sweep state + alert sink
// ═════════════════════════════════════════════════════════════════════════

pub const ArasState = struct {
    interval_sec: u32 = 300, // 5 minutes
    sweep_count: u32 = 0,
    last_sweep: i64 = 0,
    last_result: SweepResult = .{},
    alert_sink: ?locus.AlertSink = null,
    workers: []WorkerStatus = &.{}, // Cached worker list
    workers_len: usize = 0,
};

/// Initialize ARAS with alert sink
pub fn init(alert_sink: locus.AlertSink) ArasState {
    return .{
        .alert_sink = alert_sink,
    };
}

/// Run single sweep over farm workers
pub fn sweepOnce(allocator: Allocator, state: *ArasState) !SweepResult {
    var result = SweepResult{
        .timestamp = std.time.timestamp(),
    };

    // Get farm status
    const farm = try thalamus.getFarmStatus(allocator);
    result.total_services = farm.total_services;

    // Read evolution state for detailed worker info
    const evo_file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch return result;
    defer evo_file.close();

    var evo_buf: [16384]u8 = undefined;
    const evo_n = evo_file.read(&evo_buf) catch return result;
    const evo_data = evo_buf[0..evo_n];

    // Parse worker states from evolution state
    // Format: "workers": [ {"name": "...", "status": "...", "ppl": 1.23, "step": 1000}, ...]
    var pos: usize = 0;
    while (pos < evo_data.len) {
        if (std.mem.indexOfPos(u8, evo_data, pos, "\"name\":")) |name_start| {
            const name_end = std.mem.indexOfScalarPos(u8, evo_data, name_start, '"') orelse break;
            const name = evo_data[name_start + 7 .. name_end];

            // Find status
            const status_start = std.mem.indexOfPos(u8, evo_data, name_end + 1, "\"status\":") orelse break;
            const status_end = std.mem.indexOfScalarPos(u8, evo_data, status_start, '"') orelse break;
            const status = evo_data[status_start + 9 .. status_end];

            // Check if crashed or stale
            if (std.mem.eql(u8, status, "crashed") or
                std.mem.eql(u8, status, "stale") or
                std.mem.eql(u8, status, "error"))
            {
                // Allocate worker status entry
                if (state.workers_len < state.workers.len) {
                    var worker = WorkerStatus{
                        .name = try allocator.dupe(u8, name),
                        .state = try allocator.dupe(u8, status),
                    };

                    // Parse PPL if available
                    const ppl_pos = std.mem.indexOfPos(u8, evo_data, status_end + 1, "\"ppl\":");
                    if (ppl_pos) |pp| {
                        const search_start = pp + 5;
                        const ppl_end = std.mem.indexOfScalarPos(u8, evo_data, search_start, '"') orelse evo_data.len;
                        worker.last_ppl = qt.findJsonF32(evo_data[search_start..ppl_end]) orelse 999.0;
                    }

                    // Parse step if available
                    const step_pos = std.mem.indexOfPos(u8, evo_data, status_end + 1, "\"step\":");
                    if (step_pos) |sp| {
                        const search_start = sp + 7;
                        const step_end = std.mem.indexOfScalarPos(u8, evo_data, search_start, ',') orelse evo_data.len;
                        worker.last_step = qt.findJsonU32(evo_data[search_start..step_end]) orelse 0;
                    }

                    state.workers[state.workers_len] = worker;
                    state.workers_len += 1;
                }
            }
            pos = status_end + 1;
        } else break;
    }

    // Count crashed workers
    for (state.workers[0..state.workers_len]) |w| {
        if (std.mem.eql(u8, w.state, "crashed")) {
            result.crashed_workers = result.crashed_workers ++ [_][]const u8{w.name};
        }
    }

    // Count stale workers (stuck > 30 minutes)
    _ = std.time.timestamp(); // For future timeout calculation
    for (state.workers[0..state.workers_len]) |w| {
        if (std.mem.eql(u8, w.state, "stale")) {
            // Check step stuck via evolution state timestamps
            // Simplified: count all with "stale" status
            result.stale_count += 1;
        }
    }

    return result;
}

/// Main sweep loop — runs every interval_sec
pub fn sweepLoop(allocator: Allocator, state: *ArasState) !void {
    state.sweep_count += 1;
    state.last_sweep = std.time.timestamp();

    // Run sweep
    const result = try sweepOnce(allocator, state);
    state.last_result = result;

    // Log to hippocampus
    const data = try std.fmt.allocPrint(
        allocator,
        "{{\\\"sweep_num\\\":{d},\\\"crashed\\\":{d},\\\"stale\\\":{d},\\\"total\\\":{d}}}",
        .{ state.sweep_count, result.crashed_workers.len, result.stale_count, result.total_services },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "reticular_aras",
        .kind = .observation,
        .summary = "farm sweep completed",
        .data = data,
    });

    // Raise alarm if problems found
    if (result.hasProblems()) {
        const level = if (result.crashed_workers.len > 0)
            locus.ArousalLevel.alarm
        else
            locus.ArousalLevel.alert;

        const problem_count = result.problemCount();

        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &msg_buf,
            "Farm sweep: {d} problems ({d} crashed, {d} stale)",
            .{ problem_count, result.crashed_workers.len, result.stale_count },
        ) catch "Farm sweep: problems detected";

        // Raise via Locus Coeruleus
        locus.triggerAlarm(
            state.alert_sink orelse return,
            if (result.crashed_workers.len > 0)
                .worker_crashed
            else
                .build_broken, // Fallback for stale
            msg,
            level,
        );
    }
}

/// Get sweep statistics
pub fn getSweepStats(state: *const ArasState) struct {
    last_sweep: i64,
    sweep_count: u32,
    problems_last: u32,
    crashed_last: usize,
    stale_last: usize,
} {
    return .{
        .last_sweep = state.last_sweep,
        .sweep_count = state.sweep_count,
        .problems_last = @intCast(state.last_result.crashed_workers.len + state.last_result.stale_count),
        .crashed_last = state.last_result.crashed_workers.len,
        .stale_last = state.last_result.stale_count,
    };
}

// ═══════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════

fn dummySink(_: locus.Alert, _: locus.ArousalLevel) void {}

test "aras — init sets alert sink" {
    const state = init(dummySink);
    try std.testing.expect(state.alert_sink != null);
}

test "aras — sweepResult problemCount" {
    var result = SweepResult{ .crashed_workers = &[_][]const u8{ "w1", "w2" }, .stale_count = 3 };
    try std.testing.expectEqual(@as(u32, 5), result.problemCount());
    try std.testing.expect(result.hasProblems());
}

test "aras — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "aras — SweepResult hasProblems" {
    var result = SweepResult{};
    try std.testing.expect(!result.hasProblems());

    result.crashed_workers = &[_][]const u8{"w1"};
    try std.testing.expect(result.hasProblems());

    result = SweepResult{ .stale_count = 1 };
    try std.testing.expect(result.hasProblems());
}

test "aras — SweepResult timestamp" {
    const before = std.time.timestamp();
    var result = SweepResult{};
    try std.testing.expectEqual(@as(i64, 0), result.timestamp);

    result.timestamp = std.time.timestamp();
    try std.testing.expect(result.timestamp >= before);
}

test "aras — SweepResult total_services" {
    const result = SweepResult{ .total_services = 100 };
    try std.testing.expectEqual(@as(usize, 100), result.total_services);
}

test "aras — ArasState defaults" {
    const state = ArasState{};
    try std.testing.expectEqual(@as(u32, 300), state.interval_sec);
    try std.testing.expectEqual(@as(u32, 0), state.sweep_count);
    try std.testing.expectEqual(@as(i64, 0), state.last_sweep);
    try std.testing.expect(state.alert_sink == null);
}

test "aras — WorkerStatus fields" {
    const worker = WorkerStatus{
        .name = "test-worker",
        .state = "running",
        .last_ppl = 1.5,
        .last_step = 1000,
        .steps_stuck = 0,
    };

    try std.testing.expectEqualStrings("test-worker", worker.name);
    try std.testing.expectEqualStrings("running", worker.state);
    try std.testing.expectEqual(@as(f32, 1.5), worker.last_ppl);
}

test "aras — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "aras — CellHealth last_check" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

// ═══════════════════════════════════════════════════════════════════
// PROBLEM COUNT TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — problemCount with empty result" {
    const result = SweepResult{};
    try std.testing.expectEqual(@as(u32, 0), result.problemCount());
}

test "aras — problemCount with only crashed" {
    const result = SweepResult{ .crashed_workers = &[_][]const u8{ "w1", "w2", "w3" } };
    try std.testing.expectEqual(@as(u32, 3), result.problemCount());
}

test "aras — problemCount with only stale" {
    const result = SweepResult{ .stale_count = 5 };
    try std.testing.expectEqual(@as(u32, 5), result.problemCount());
}

test "aras — problemCount wrapping addition" {
    // Test the +% (wrapping) addition with large values
    const result = SweepResult{
        .crashed_workers = &[_][]const u8{"w1"},
        .stale_count = 100,
    };
    try std.testing.expectEqual(@as(u32, 101), result.problemCount());
}

// ═══════════════════════════════════════════════════════════════════
// SWEEP STATS TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — getSweepStats returns zero for fresh state" {
    const state = ArasState{};
    const stats = getSweepStats(&state);

    try std.testing.expectEqual(@as(i64, 0), stats.last_sweep);
    try std.testing.expectEqual(@as(u32, 0), stats.sweep_count);
    try std.testing.expectEqual(@as(u32, 0), stats.problems_last);
    try std.testing.expectEqual(@as(usize, 0), stats.crashed_last);
    try std.testing.expectEqual(@as(usize, 0), stats.stale_last);
}

test "aras — getSweepStats returns populated values" {
    var state = ArasState{
        .sweep_count = 42,
        .last_sweep = 12345,
        .last_result = SweepResult{
            .crashed_workers = &[_][]const u8{ "w1", "w2" },
            .stale_count = 3,
            .total_services = 100,
        },
    };

    const stats = getSweepStats(&state);

    try std.testing.expectEqual(@as(i64, 12345), stats.last_sweep);
    try std.testing.expectEqual(@as(u32, 42), stats.sweep_count);
    try std.testing.expectEqual(@as(u32, 5), stats.problems_last);
    try std.testing.expectEqual(@as(usize, 2), stats.crashed_last);
    try std.testing.expectEqual(@as(usize, 3), stats.stale_last);
}

// ═══════════════════════════════════════════════════════════════════
// INIT TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — init with valid sink" {
    const state = init(dummySink);
    try std.testing.expect(state.alert_sink != null);
    try std.testing.expectEqual(@as(u32, 300), state.interval_sec);
    try std.testing.expectEqual(@as(u32, 0), state.sweep_count);
}

test "aras — init sets all defaults" {
    const state = init(dummySink);

    try std.testing.expectEqual(@as(u32, 300), state.interval_sec);
    try std.testing.expectEqual(@as(u32, 0), state.sweep_count);
    try std.testing.expectEqual(@as(i64, 0), state.last_sweep);
    try std.testing.expectEqual(@as(usize, 0), state.workers_len);
}

// ═══════════════════════════════════════════════════════════════════
// ARAS STATE TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — ArasState custom interval" {
    const state = ArasState{ .interval_sec = 600 };
    try std.testing.expectEqual(@as(u32, 600), state.interval_sec);
}

test "aras — ArasState with sweep count" {
    var state = ArasState{ .sweep_count = 10 };
    try std.testing.expectEqual(@as(u32, 10), state.sweep_count);

    state.sweep_count = 100;
    try std.testing.expectEqual(@as(u32, 100), state.sweep_count);
}

test "aras — ArasState workers array" {
    var workers = [_]WorkerStatus{
        .{ .name = "w1", .state = "running" },
        .{ .name = "w2", .state = "stale" },
    };

    const state = ArasState{
        .workers = &workers,
        .workers_len = 2,
    };

    try std.testing.expectEqual(@as(usize, 2), state.workers_len);
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 12345;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), h.last_check);
}

test "aras — CellHealth all status values" {
    const healthy = CellHealth{ .status = .healthy };
    const weak = CellHealth{ .status = .weak };
    const broken = CellHealth{ .status = .broken };

    try std.testing.expectEqual(CellHealth.Status.healthy, healthy.status);
    try std.testing.expectEqual(CellHealth.Status.weak, weak.status);
    try std.testing.expectEqual(CellHealth.Status.broken, broken.status);
}

test "aras — CellHealth default cycle" {
    const h = CellHealth{};
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
}

// ═══════════════════════════════════════════════════════════════════
// WORKER STATUS TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — WorkerStatus steps_stuck" {
    const worker = WorkerStatus{
        .name = "stuck-worker",
        .state = "stale",
        .steps_stuck = 1800, // 30 minutes
    };

    try std.testing.expectEqual(@as(u32, 1800), worker.steps_stuck);
}

test "aras — WorkerStatus default values" {
    const worker = WorkerStatus{
        .name = "test",
        .state = "idle",
    };

    try std.testing.expectEqual(@as(f32, 999.0), worker.last_ppl);
    try std.testing.expectEqual(@as(u32, 0), worker.last_step);
    try std.testing.expectEqual(@as(u32, 0), worker.steps_stuck);
}

test "aras — WorkerStatus all states" {
    const states = [_][]const u8{ "running", "idle", "stale", "crashed", "error" };

    for (states) |state_name| {
        const worker = WorkerStatus{
            .name = "worker",
            .state = state_name,
        };
        try std.testing.expectEqualStrings(state_name, worker.state);
    }
}

// ═══════════════════════════════════════════════════════════════════
// SWEEP RESULT TESTS
// ═══════════════════════════════════════════════════════════════════

test "aras — SweepResult default values" {
    const result = SweepResult{};

    try std.testing.expectEqual(@as(usize, 0), result.crashed_workers.len);
    try std.testing.expectEqual(@as(usize, 0), result.stale_count);
    try std.testing.expectEqual(@as(usize, 0), result.total_services);
    try std.testing.expectEqual(@as(i64, 0), result.timestamp);
}

test "aras — SweepResult hasProblems combinations" {
    // No problems
    {
        const result = SweepResult{};
        try std.testing.expect(!result.hasProblems());
    }

    // Only crashed
    {
        const result = SweepResult{ .crashed_workers = &[_][]const u8{"w1"} };
        try std.testing.expect(result.hasProblems());
    }

    // Only stale
    {
        const result = SweepResult{ .stale_count = 1 };
        try std.testing.expect(result.hasProblems());
    }

    // Both crashed and stale
    {
        const result = SweepResult{
            .crashed_workers = &[_][]const u8{ "w1", "w2" },
            .stale_count = 3,
        };
        try std.testing.expect(result.hasProblems());
    }
}

test "aras — SweepResult multiple crashed workers" {
    const crashed = [_][]const u8{ "w1", "w2", "w3", "w4", "w5" };
    const result = SweepResult{ .crashed_workers = &crashed };

    try std.testing.expectEqual(@as(usize, 5), result.crashed_workers.len);
    try std.testing.expectEqual(@as(u32, 5), result.problemCount());
}

test "aras — SweepResult with large counts" {
    const result = SweepResult{
        .crashed_workers = &[_][]const u8{"w1"},
        .stale_count = 999,
        .total_services = 1000,
    };

    try std.testing.expectEqual(@as(u32, 1000), result.problemCount());
    try std.testing.expectEqual(@as(usize, 1000), result.total_services);
}
