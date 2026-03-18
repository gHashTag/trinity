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

    pub fn utilization(self: *const ResourcePool) f32 {
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

    pub fn avgPpl(self: *const ResourcePool) f32 {
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
    _ = allocator;

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
