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
        count += self.stale_count;
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
    const now = std.time.timestamp();
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
        .problems_last = state.last_result.crashed_workers.len + state.last_result.stale_count,
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
