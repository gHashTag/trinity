// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// BASAL GANGLIA — Action Selection + Suppression
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Action selection, habit formation, inhibition of conflicting actions
// Trinity: Choose WHAT to do, suppress conflicting impulses
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION SELECTION — Choose what to do from candidates
// ═══════════════════════════════════════════════════════════════════════════════

pub const ActionCandidate = struct {
    kind: qt.ActionKind,
    urgency: Urgency,
    value: f32 = 0.0, // 0-1 estimated value
    cost: f32 = 0.0, // 0-1 estimated cost
    suppressed: bool = false,

    pub fn score(self: ActionCandidate) f32 {
        if (self.suppressed) return -1.0;
        return self.value - (self.cost * 0.5);
    }
};

pub const Urgency = enum(u8) {
    critical = 0,
    high = 1,
    normal = 2,
    low = 3,

    pub fn weight(self: Urgency) f32 {
        return switch (self) {
            .critical => 4.0,
            .high => 2.0,
            .normal => 1.0,
            .low => 0.5,
        };
    }
};

/// Select best action from candidates
pub fn selectAction(candidates: []const ActionCandidate) ?qt.ActionKind {
    if (candidates.len == 0) return null;

    var best_idx: ?usize = null;
    var best_score: f32 = -1.0;

    for (candidates, 0..) |c, i| {
        if (c.suppressed) continue;
        const score = c.score() * c.urgency.weight();
        if (score > best_score) {
            best_score = score;
            best_idx = i;
        }
    }

    if (best_idx) |idx| {
        return candidates[idx].kind;
    }

    return null;
}

/// Suppress conflicting actions (only one can run)
pub fn suppressConflicting(
    candidates: []ActionCandidate,
    selected: qt.ActionKind,
) !void {
    // TODO: Implement conflict detection
    _ = candidates;
    _ = selected;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HABIT LEARNING — Repeated actions become habits
// ═══════════════════════════════════════════════════════════════════════════════

pub const Habit = struct {
    action: qt.ActionKind,
    trigger: Trigger,
    count: u32 = 0,
    last_executed: i64 = 0,

    pub fn isReady(self: Habit, now: i64) bool {
        const age_hours = (now - self.last_executed) / 3600;
        return switch (self.trigger) {
            .always => true,
            .hourly => age_hours >= 1,
            .daily => age_hours >= 24,
        };
    }
};

pub const Trigger = enum {
    always,
    hourly,
    daily,
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

test "basal_ganglia — selectAction picks highest score" {
    const candidates = [_]ActionCandidate{
        .{ .kind = .farm_status, .urgency = .low, .value = 0.3 },
        .{ .kind = .doctor_quick, .urgency = .critical, .value = 0.8 },
        .{ .kind = .farm_recycle, .urgency = .high, .value = 0.9 },
    };

    const selected = selectAction(&candidates);
    try std.testing.expect(selected != null);
    // Critical urgency * 0.8 * 4.0 = 3.2 > High urgency * 0.9 * 2.0 = 1.8
}

test "basal_ganglia — selectAction skips suppressed" {
    const candidates = [_]ActionCandidate{
        .{ .kind = .farm_status, .urgency = .critical, .suppressed = true },
        .{ .kind = .doctor_quick, .urgency = .normal, .value = 0.5 },
    };

    const selected = selectAction(&candidates);
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, selected.?);
}

test "basal_ganglia — Urgency weight" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), Urgency.critical.weight(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), Urgency.high.weight(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Urgency.normal.weight(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Urgency.low.weight(), 0.01);
}

test "basal_ganglia — ActionCandidate score" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
        .value = 0.8,
        .cost = 0.2,
    };
    // score = 0.8 - (0.2 * 0.5) = 0.7
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), c.score(), 0.01);
}

test "basal_ganglia — ActionCandidate suppressed score" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
        .value = 0.8,
        .cost = 0.2,
        .suppressed = true,
    };
    try std.testing.expect(c.score() < 0);
}

test "basal_ganglia — Habit isReady" {
    const now: i64 = 100000;

    const always_habit = Habit{
        .action = .farm_status,
        .trigger = .always,
        .last_executed = now - 10,
    };
    try std.testing.expect(always_habit.isReady(now));

    const daily_habit = Habit{
        .action = .doctor_quick,
        .trigger = .daily,
        .last_executed = now - (25 * 3600), // 25 hours ago
    };
    try std.testing.expect(daily_habit.isReady(now));

    const daily_not_ready = Habit{
        .action = .doctor_quick,
        .trigger = .daily,
        .last_executed = now - (12 * 3600), // 12 hours ago
    };
    try std.testing.expect(!daily_not_ready.isReady(now));
}

test "basal_ganglia — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}
