// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// CEREBELLUM — Coordination + Resource Management
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Motor coordination, precision timing, error correction
// Trinity: Coordinate parallel actions, manage compute resources
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// RESOURCE POOL — Track available compute
// ═══════════════════════════════════════════════════════════════════════════════

pub const ResourcePool = struct {
    total_workers: u32 = 0,
    active_workers: u32 = 0,
    idle_workers: u32 = 0,
    crashed_workers: u32 = 0,
    total_ppl: f32 = 0.0,

    pub inline fn utilization(self: *const ResourcePool) f32 {
        if (self.total_workers == 0) return 0.0;
        return @as(f32, @floatFromInt(self.active_workers)) /
            @as(f32, @floatFromInt(self.total_workers));
    }

    pub fn healthScore(self: *const ResourcePool) f32 {
        // Health = utilization - crash penalty
        const util_score = self.utilization();
        const crash_penalty = @as(f32, @floatFromInt(self.crashed_workers)) * 0.1;
        return @max(0.0, util_score - crash_penalty);
    }

    pub inline fn avgPpl(self: *const ResourcePool) f32 {
        if (self.active_workers == 0) return 0.0;
        return self.total_ppl / @as(f32, @floatFromInt(self.active_workers));
    }
};

/// Get current resource pool from farm
pub fn getResourcePool(allocator: Allocator) !ResourcePool {
    // In real implementation, this would query Railway API
    // For now, return mock data
    _ = allocator;
    return ResourcePool{
        .total_workers = 100,
        .active_workers = 85,
        .idle_workers = 10,
        .crashed_workers = 5,
        .total_ppl = 85 * 4.6, // Assume 4.6 avg
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COORDINATION — Schedule parallel actions efficiently
// ═══════════════════════════════════════════════════════════════════════════════

pub const CoordinationPlan = struct {
    parallel_slots: u32 = 4, // Max parallel actions
    queue: []const qt.ActionKind = &.{},
    estimated_duration_sec: u32 = 0,

    pub fn canRunParallel(self: *const CoordinationPlan, count: u32) bool {
        return (self.queue.len + @as(usize, @intCast(count))) <= @as(usize, @intCast(self.parallel_slots));
    }
};

/// Plan coordination of actions
pub fn planCoordination(
    allocator: Allocator,
    actions: []const qt.ActionKind,
) !CoordinationPlan {
    var plan = CoordinationPlan{};

    // Estimate duration based on action types
    var total_sec: u32 = 0;
    for (actions) |a| {
        total_sec += estimateDuration(a);
    }

    plan.estimated_duration_sec = total_sec;

    // In real implementation, would analyze dependencies
    // For now, just copy actions
    plan.queue = try allocator.dupe(qt.ActionKind, actions);

    return plan;
}

fn estimateDuration(action: qt.ActionKind) u32 {
    return switch (action) {
        // Read-only: fast
        .farm_status,
        .arena_status,
        .doctor_scan,
        .train_status,
        .train_diagnose,
        .experiment_chart,
        .patent_status,
        .research_sacred,
        .ouroboros_status,
        .experience_recall,
        .farm_evolve_status,
        .swarm_status,
        .introspection,
        => 5,

        // Soft writes: medium
        .doctor_quick,
        .doctor_heal,
        .git_commit_state,
        .arena_battle,
        .experience_save,
        .fmt,
        => 30,

        // Network writes: slower
        .git_push,
        .issue_comment,
        .notify,
        .ouroboros_cycle,
        => 60,

        // Dangerous: slowest
        .farm_recycle,
        .farm_evolve_step,
        .cloud_spawn,
        .cloud_kill,
        .cloud_cleanup,
        .issue_create,
        .swarm_decompose,
        => 120,
    };
}

/// Feedback loop: write coordination results to Hippocampus
pub fn recordCoordination(
    allocator: Allocator,
    plan: CoordinationPlan,
    success: bool,
) !void {
    const hippocampus = @import("hippocampus.zig");

    const data = try std.fmt.allocPrint(
        allocator,
        "{{\"actions\":{d},\"duration_sec\":{d},\"success\":{s}}}",
        .{ plan.queue.len, plan.estimated_duration_sec, success },
    );
    defer allocator.free(data);

    _ = try hippocampus.write(allocator, .{
        .agent = "cerebellum",
        .kind = .observation,
        .summary = "coordination completed",
        .data = data,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOTOR COORDINATION — Movement sequencing and timing
// ═══════════════════════════════════════════════════════════════════════════════

pub const CoordinationState = enum {
    idle,
    planning,
    executing,
    waiting,
    completed,
    failed,
};

pub const MovementPattern = struct {
    actions: []const qt.ActionKind = &.{},
    timing_multiplier: f32 = 1.0,
    success_count: u32 = 0,
    failure_count: u32 = 0,

    pub inline fn successRate(self: *const MovementPattern) f32 {
        const total = self.success_count + self.failure_count;
        if (total == 0) return 0.5; // Neutral prior
        return @as(f32, @floatFromInt(self.success_count)) / @as(f32, @floatFromInt(total));
    }
};

/// Sequence coordinator for parallel actions
pub const SequenceCoordinator = struct {
    state: CoordinationState = .idle,
    current_index: usize = 0,
    pattern: MovementPattern = .{},
    timing_adjust: f32 = 1.0,

    /// Get next action in sequence
    pub inline fn sequenceNext(self: *SequenceCoordinator) ?qt.ActionKind {
        if (self.state != .executing) return null;
        if (self.current_index >= self.pattern.actions.len) {
            self.state = .completed;
            return null;
        }

        const action = self.pattern.actions[self.current_index];
        self.current_index += 1;
        return action;
    }

    /// Adjust timing based on performance feedback
    pub fn adjustTiming(self: *SequenceCoordinator, actual_duration_sec: u32, expected_duration_sec: u32) void {
        if (expected_duration_sec == 0) return;

        const ratio = @as(f32, @floatFromInt(actual_duration_sec)) /
            @as(f32, @floatFromInt(expected_duration_sec));

        // Adaptive timing: converge toward 1.0 with learning rate 0.1
        const target = 1.0 / ratio;
        self.timing_adjust = 0.9 * self.timing_adjust + 0.1 * target;

        // Clamp to reasonable bounds [0.5, 2.0]
        self.timing_adjust = @max(0.5, @min(2.0, self.timing_adjust));
    }

    /// Learn from pattern execution result
    pub fn learnPattern(self: *SequenceCoordinator, success: bool) void {
        if (success) {
            self.pattern.success_count += 1;
        } else {
            self.pattern.failure_count += 1;
        }

        // Adjust timing multiplier based on success rate
        const rate = self.pattern.successRate();
        if (rate < 0.3) {
            // Poor performance: slow down
            self.pattern.timing_multiplier = @min(2.0, self.pattern.timing_multiplier * 1.2);
        } else if (rate > 0.8) {
            // Excellent performance: speed up
            self.pattern.timing_multiplier = @max(0.5, self.pattern.timing_multiplier * 0.9);
        }
    }

    /// Reset coordinator for new sequence
    pub fn reset(self: *SequenceCoordinator, actions: []const qt.ActionKind) void {
        self.state = .idle;
        self.current_index = 0;
        self.pattern = MovementPattern{
            .actions = actions,
            .timing_multiplier = self.pattern.timing_multiplier, // Preserve learning
            .success_count = 0,
            .failure_count = 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cerebellum — CoordinationState enum" {
    try std.testing.expectEqual(@as(CoordinationState, .idle), CoordinationState.idle);
    try std.testing.expectEqual(@as(CoordinationState, .planning), CoordinationState.planning);
    try std.testing.expectEqual(@as(CoordinationState, .executing), CoordinationState.executing);
    try std.testing.expectEqual(@as(CoordinationState, .waiting), CoordinationState.waiting);
    try std.testing.expectEqual(@as(CoordinationState, .completed), CoordinationState.completed);
    try std.testing.expectEqual(@as(CoordinationState, .failed), CoordinationState.failed);
}

test "cerebellum — MovementPattern successRate" {
    const pattern = MovementPattern{
        .success_count = 7,
        .failure_count = 3,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), pattern.successRate(), 0.01);
}

test "cerebellum — MovementPattern successRate neutral prior" {
    const pattern = MovementPattern{};
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), pattern.successRate(), 0.01);
}

test "cerebellum — SequenceCoordinator sequenceNext" {
    const actions = [_]qt.ActionKind{ .farm_status, .arena_status, .doctor_scan };
    var coord = SequenceCoordinator{
        .state = .executing,
        .pattern = .{ .actions = &actions },
    };

    try std.testing.expectEqual(qt.ActionKind.farm_status, coord.sequenceNext().?);
    try std.testing.expectEqual(qt.ActionKind.arena_status, coord.sequenceNext().?);
    try std.testing.expectEqual(qt.ActionKind.doctor_scan, coord.sequenceNext().?);
    try std.testing.expect(coord.sequenceNext() == null);
    try std.testing.expectEqual(CoordinationState.completed, coord.state);
}

test "cerebellum — SequenceCoordinator sequenceNext returns null when not executing" {
    var coord = SequenceCoordinator{ .state = .idle };
    try std.testing.expect(coord.sequenceNext() == null);

    coord.state = .planning;
    try std.testing.expect(coord.sequenceNext() == null);
}

test "cerebellum — SequenceCoordinator adjustTiming" {
    var coord = SequenceCoordinator{ .timing_adjust = 1.0 };

    // Actual faster than expected -> speed up (> 1.0)
    coord.adjustTiming(50, 100);
    try std.testing.expect(coord.timing_adjust > 1.0);

    // Actual slower than expected -> slow down (< 1.0)
    coord.timing_adjust = 1.0;
    coord.adjustTiming(150, 100);
    try std.testing.expect(coord.timing_adjust < 1.0);
}

test "cerebellum — SequenceCoordinator adjustTiming clamps" {
    var coord = SequenceCoordinator{ .timing_adjust = 1.0 };

    // Extreme case: much faster -> clamp to max 2.0
    coord.adjustTiming(10, 100);
    try std.testing.expect(coord.timing_adjust <= 2.0);

    // Extreme case: much slower -> clamp to min 0.5
    coord.timing_adjust = 1.0;
    coord.adjustTiming(1000, 100);
    try std.testing.expect(coord.timing_adjust >= 0.5);
}

test "cerebellum — SequenceCoordinator learnPattern success" {
    var coord = SequenceCoordinator{
        .pattern = .{ .timing_multiplier = 1.0 },
    };

    // High success rate -> speed up
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        coord.learnPattern(true);
    }

    try std.testing.expectEqual(@as(u32, 10), coord.pattern.success_count);
    try std.testing.expect(coord.pattern.timing_multiplier < 1.0);
    try std.testing.expect(coord.pattern.timing_multiplier >= 0.5);
}

test "cerebellum — SequenceCoordinator learnPattern failure" {
    var coord = SequenceCoordinator{
        .pattern = .{ .timing_multiplier = 1.0 },
    };

    // Low success rate -> slow down
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        coord.learnPattern(false);
    }

    try std.testing.expectEqual(@as(u32, 10), coord.pattern.failure_count);
    try std.testing.expect(coord.pattern.timing_multiplier > 1.0);
    try std.testing.expect(coord.pattern.timing_multiplier <= 2.0);
}

test "cerebellum — SequenceCoordinator reset" {
    const actions = [_]qt.ActionKind{.farm_status};
    var coord = SequenceCoordinator{
        .state = .completed,
        .current_index = 5,
        .pattern = .{
            .actions = &.{.arena_status},
            .timing_multiplier = 1.5,
            .success_count = 3,
            .failure_count = 1,
        },
    };

    coord.reset(&actions);

    try std.testing.expectEqual(CoordinationState.idle, coord.state);
    try std.testing.expectEqual(@as(usize, 0), coord.current_index);
    try std.testing.expectEqual(qt.ActionKind.farm_status, coord.pattern.actions[0]);
    try std.testing.expectEqual(@as(u32, 0), coord.pattern.success_count);
    try std.testing.expectEqual(@as(u32, 0), coord.pattern.failure_count);
    // timing_multiplier is preserved
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), coord.pattern.timing_multiplier, 0.01);
}

test "cerebellum — ResourcePool utilization" {
    const pool = ResourcePool{
        .total_workers = 100,
        .active_workers = 75,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), pool.utilization(), 0.01);
}

test "cerebellum — ResourcePool healthScore" {
    const pool = ResourcePool{
        .total_workers = 100,
        .active_workers = 75,
        .crashed_workers = 10,
    };
    // 0.75 - (10 * 0.1) = 0.75 - 1.0 = 0 (clamped)
    try std.testing.expectEqual(@as(f32, 0.0), pool.healthScore());
}

test "cerebellum — ResourcePool avgPpl" {
    const pool = ResourcePool{
        .active_workers = 10,
        .total_ppl = 46.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 4.6), pool.avgPpl(), 0.01);
}

test "cerebellum — estimateDuration" {
    try std.testing.expectEqual(@as(u32, 5), estimateDuration(.farm_status));
    try std.testing.expectEqual(@as(u32, 30), estimateDuration(.doctor_quick));
    try std.testing.expectEqual(@as(u32, 120), estimateDuration(.farm_recycle));
}

test "cerebellum — CoordinationPlan canRunParallel" {
    var plan = CoordinationPlan{
        .parallel_slots = 4,
        .queue = &[_]qt.ActionKind{ .farm_status, .arena_status },
    };

    try std.testing.expect(plan.canRunParallel(2)); // 2 + 2 = 4, fits
    try std.testing.expect(!plan.canRunParallel(3)); // 2 + 3 = 5, doesn't fit
}

test "cerebellum — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

// ═══════════════════════════════════════════════════════════════════
// RESOURCE POOL TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — ResourcePool defaults" {
    const pool = ResourcePool{};
    try std.testing.expectEqual(@as(u32, 0), pool.total_workers);
    try std.testing.expectEqual(@as(u32, 0), pool.active_workers);
    try std.testing.expectEqual(@as(u32, 0), pool.idle_workers);
    try std.testing.expectEqual(@as(u32, 0), pool.crashed_workers);
    try std.testing.expectEqual(@as(f32, 0.0), pool.total_ppl);
}

test "cerebellum — ResourcePool utilization zero total" {
    const pool = ResourcePool{
        .total_workers = 0,
        .active_workers = 0,
    };
    try std.testing.expectEqual(@as(f32, 0.0), pool.utilization());
}

test "cerebellum — ResourcePool utilization full" {
    const pool = ResourcePool{
        .total_workers = 100,
        .active_workers = 100,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pool.utilization(), 0.01);
}

test "cerebellum — ResourcePool healthScore positive" {
    const pool = ResourcePool{
        .total_workers = 100,
        .active_workers = 80,
        .crashed_workers = 2,
    };
    // 0.8 - (2 * 0.1) = 0.8 - 0.2 = 0.6
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), pool.healthScore(), 0.01);
}

test "cerebellum — ResourcePool avgPpl zero workers" {
    const pool = ResourcePool{
        .active_workers = 0,
        .total_ppl = 0.0,
    };
    try std.testing.expectEqual(@as(f32, 0.0), pool.avgPpl());
}

test "cerebellum — ResourcePool avgPpl with values" {
    const pool = ResourcePool{
        .active_workers = 5,
        .total_ppl = 25.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), pool.avgPpl(), 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// COORDINATION PLAN TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — CoordinationPlan defaults" {
    const plan = CoordinationPlan{};
    try std.testing.expectEqual(@as(u32, 4), plan.parallel_slots);
    try std.testing.expectEqual(@as(usize, 0), plan.queue.len);
    try std.testing.expectEqual(@as(u32, 0), plan.estimated_duration_sec);
}

test "cerebellum — CoordinationPlan canRunParallel empty queue" {
    const plan = CoordinationPlan{
        .parallel_slots = 4,
        .queue = &.{},
    };
    try std.testing.expect(plan.canRunParallel(4));
    try std.testing.expect(!plan.canRunParallel(5));
}

test "cerebellum — CoordinationPlan canRunParallel at limit" {
    const plan = CoordinationPlan{
        .parallel_slots = 4,
        .queue = &[_]qt.ActionKind{ .farm_status, .arena_status, .doctor_scan, .introspection },
    };
    try std.testing.expect(!plan.canRunParallel(1)); // 4 + 1 = 5 > 4
    try std.testing.expect(plan.canRunParallel(0)); // 4 + 0 = 4 <= 4
}

// ═══════════════════════════════════════════════════════════════════
// MOVEMENT PATTERN TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — MovementPattern defaults" {
    const pattern = MovementPattern{};
    try std.testing.expectEqual(@as(usize, 0), pattern.actions.len);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pattern.timing_multiplier, 0.01);
    try std.testing.expectEqual(@as(u32, 0), pattern.success_count);
    try std.testing.expectEqual(@as(u32, 0), pattern.failure_count);
}

test "cerebellum — MovementPattern successRate all success" {
    const pattern = MovementPattern{
        .success_count = 10,
        .failure_count = 0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pattern.successRate(), 0.01);
}

test "cerebellum — MovementPattern successRate all failure" {
    const pattern = MovementPattern{
        .success_count = 0,
        .failure_count = 10,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), pattern.successRate(), 0.01);
}

test "cerebellum — MovementPattern successRate mixed" {
    const pattern = MovementPattern{
        .success_count = 3,
        .failure_count = 7,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), pattern.successRate(), 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// SEQUENCE COORDINATOR TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — SequenceCoordinator defaults" {
    const coord = SequenceCoordinator{};
    try std.testing.expectEqual(CoordinationState.idle, coord.state);
    try std.testing.expectEqual(@as(usize, 0), coord.current_index);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), coord.timing_adjust, 0.01);
}

test "cerebellum — SequenceCoordinator learnPattern mid success" {
    var coord = SequenceCoordinator{
        .pattern = .{ .timing_multiplier = 1.0 },
    };

    // Mixed success/failure -> no timing change after initial state
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        coord.learnPattern(true);
        coord.learnPattern(false);
    }

    // First success (rate=1.0) reduces timing to 0.9, then rate stays ~0.5
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), coord.pattern.timing_multiplier, 0.01);
}

test "cerebellum — SequenceCoordinator adjustTiming zero expected" {
    var coord = SequenceCoordinator{ .timing_adjust = 1.0 };
    coord.adjustTiming(100, 0); // Should return early, no change
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), coord.timing_adjust, 0.01);
}

test "cerebellum — SequenceCoordinator adjustTiming exact match" {
    var coord = SequenceCoordinator{ .timing_adjust = 1.0 };
    coord.adjustTiming(100, 100);
    // ratio = 1.0, target = 1.0, new = 0.9 * 1.0 + 0.1 * 1.0 = 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), coord.timing_adjust, 0.01);
}

test "cerebellum — SequenceCoordinator reset preserves timing" {
    const actions = [_]qt.ActionKind{.farm_status};
    var coord = SequenceCoordinator{
        .state = .executing,
        .current_index = 10,
        .timing_adjust = 1.8,
        .pattern = .{
            .actions = &.{.arena_status},
            .timing_multiplier = 0.6,
        },
    };

    coord.reset(&actions);

    try std.testing.expectEqual(CoordinationState.idle, coord.state);
    try std.testing.expectEqual(@as(usize, 0), coord.current_index);
    // Preserves pattern timing_multiplier
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), coord.pattern.timing_multiplier, 0.01);
    // timing_adjust field is separate, not reset
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), coord.timing_adjust, 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// COORDINATION STATE TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — CoordinationState all values" {
    const states = [_]CoordinationState{
        .idle, .planning, .executing, .waiting, .completed, .failed,
    };
    for (states) |s| {
        _ = s; // Verify all enum values exist
    }
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "cerebellum — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "cerebellum — CellHealth defaults" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "cerebellum — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "cerebellum — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .broken;
    h.cycle = 7;
    h.last_check = 99999;

    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
    try std.testing.expectEqual(@as(u32, 7), h.cycle);
    try std.testing.expectEqual(@as(i64, 99999), h.last_check);
}
