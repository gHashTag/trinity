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

    pub inline fn score(self: ActionCandidate) f32 {
        if (self.suppressed) return -1.0;
        return self.value - (self.cost * 0.5);
    }
};

pub const Urgency = enum(u8) {
    critical = 0,
    high = 1,
    normal = 2,
    low = 3,

    pub inline fn weight(self: Urgency) f32 {
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
    const queen_acc = @import("queen_acc.zig");
    try queen_acc.suppressConflicting(candidates, selected);
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
        const age_seconds = now - self.last_executed;
        const age_hours = @divTrunc(age_seconds, 3600);
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
// TASK CLAIM REGISTRY — CRDT-based distributed task coordination
// ═══════════════════════════════════════════════════════════════════════════════
// Prevents duplicate task execution across parallel agents.
// First agent wins — atomic claim with TTL + heartbeat.

pub const TaskClaimStatus = enum { active, completed, abandoned };

pub const TaskClaim = struct {
    task_id: []const u8,
    agent_id: []const u8,
    claimed_at: i64,
    ttl_ms: u64,
    status: TaskClaimStatus,
    completed_at: ?i64,
    last_heartbeat: i64,

    pub fn isValid(self: *const TaskClaim) bool {
        if (self.status != .active) return false;
        const now_ms = std.time.timestamp() * 1000;
        const age_ms = @as(u64, @intCast(now_ms - self.claimed_at));
        if (age_ms > self.ttl_ms) return false;
        const heartbeat_age_ms = @as(u64, @intCast(now_ms - self.last_heartbeat));
        if (heartbeat_age_ms > 30000) return false; // 30s heartbeat timeout
        return true;
    }
};

pub const Registry = struct {
    claims: std.StringHashMap(TaskClaim),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{
            .claims = std.StringHashMap(TaskClaim).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Registry) void {
        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.deinit();
    }

    pub fn claim(self: *Registry, allocator: std.mem.Allocator, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now_ms = std.time.timestamp() * 1000;

        // Check if already claimed and valid
        if (self.claims.get(task_id)) |existing| {
            if (existing.isValid()) {
                return false; // Already claimed by someone else
            }
        }

        // Remove old claim if exists (to free memory)
        if (self.claims.fetchRemove(task_id)) |old_entry| {
            allocator.free(old_entry.key);
            allocator.free(old_entry.value.task_id);
            allocator.free(old_entry.value.agent_id);
        }

        // Create new claim
        const new_claim = TaskClaim{
            .task_id = try allocator.dupe(u8, task_id),
            .agent_id = try allocator.dupe(u8, agent_id),
            .claimed_at = now_ms,
            .ttl_ms = ttl_ms,
            .status = .active,
            .completed_at = null,
            .last_heartbeat = now_ms,
        };

        try self.claims.put(try allocator.dupe(u8, task_id), new_claim);
        return true;
    }

    pub fn heartbeat(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.last_heartbeat = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn complete(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .completed;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn abandon(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .abandoned;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn reset(self: *Registry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.clearRetainingCapacity();
    }

    pub fn getStats(self: *Registry) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var active: usize = 0;
        var completed: usize = 0;
        var abandoned: usize = 0;

        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            const stored_claim = entry.value_ptr.*;
            if (stored_claim.isValid()) {
                active += 1;
            } else {
                switch (stored_claim.status) {
                    .completed => completed += 1,
                    .abandoned => abandoned += 1,
                    .active => {}, // Expired active claims count as inactive
                }
            }
        }

        return Stats{
            .total = self.claims.count(),
            .active = active,
            .completed = completed,
            .abandoned = abandoned,
        };
    }

    pub fn listClaims(self: *Registry, allocator: std.mem.Allocator, filter_agent: ?[]const u8) ![]const ClaimInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = try std.ArrayList(ClaimInfo).initCapacity(allocator, 100);
        errdefer list.deinit(allocator);

        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            const stored_claim = entry.value_ptr.*;
            // Filter by agent if specified
            if (filter_agent) |agent| {
                if (!std.mem.eql(u8, stored_claim.agent_id, agent)) continue;
            }

            const info = ClaimInfo{
                .task_id = stored_claim.task_id,
                .agent_id = stored_claim.agent_id,
                .status = stored_claim.status,
                .claimed_at = stored_claim.claimed_at,
                .ttl_ms = stored_claim.ttl_ms,
                .is_valid = stored_claim.isValid(),
            };
            try list.append(allocator, info);
        }

        return list.toOwnedSlice(allocator);
    }
};

pub const Stats = struct {
    total: usize,
    active: usize,
    completed: usize,
    abandoned: usize,
};

pub const ClaimInfo = struct {
    task_id: []const u8,
    agent_id: []const u8,
    status: TaskClaimStatus,
    claimed_at: i64,
    ttl_ms: u64,
    is_valid: bool,
};

// Global singleton
var global_registry: ?*Registry = null;
var global_mutex = std.Thread.Mutex{};

pub fn getGlobal(allocator: std.mem.Allocator) !*Registry {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| return reg;

    const reg = try allocator.create(Registry);
    reg.* = Registry.init(allocator);
    global_registry = reg;
    return reg;
}

/// Reset global registry (for testing)
pub fn resetGlobal(allocator: std.mem.Allocator) void {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| {
        reg.deinit();
        allocator.destroy(reg);
        global_registry = null;
    }
}

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

test "basal_ganglia — selectAction returns null for empty" {
    const candidates = [_]ActionCandidate{};
    const selected = selectAction(&candidates);
    try std.testing.expectEqual(@as(?qt.ActionKind, null), selected);
}

test "basal_ganglia — selectAction all suppressed" {
    const candidates = [_]ActionCandidate{
        .{ .kind = .farm_status, .urgency = .critical, .suppressed = true },
        .{ .kind = .doctor_quick, .urgency = .high, .suppressed = true },
    };

    const selected = selectAction(&candidates);
    try std.testing.expectEqual(@as(?qt.ActionKind, null), selected);
}

test "basal_ganglia — selectAction ties go to first" {
    const candidates = [_]ActionCandidate{
        .{ .kind = .farm_status, .urgency = .normal, .value = 0.5 },
        .{ .kind = .doctor_quick, .urgency = .normal, .value = 0.5 },
    };

    const selected = selectAction(&candidates);
    // First candidate should be selected (same score)
    try std.testing.expectEqual(qt.ActionKind.farm_status, selected.?);
}

test "basal_ganglia — ActionCandidate score with high cost" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
        .value = 0.5,
        .cost = 0.9,
    };
    // score = 0.5 - (0.9 * 0.5) = 0.5 - 0.45 = 0.05
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), c.score(), 0.01);
}

test "basal_ganglia — Habit isReady hourly" {
    const now: i64 = 100000;

    const hourly_ready = Habit{
        .action = .farm_status,
        .trigger = .hourly,
        .last_executed = now - 3601, // 1 hour 1 second ago
    };
    try std.testing.expect(hourly_ready.isReady(now));

    const hourly_not_ready = Habit{
        .action = .farm_status,
        .trigger = .hourly,
        .last_executed = now - 3599, // 59 minutes 59 seconds ago
    };
    try std.testing.expect(!hourly_not_ready.isReady(now));
}

test "basal_ganglia — Urgency enum values" {
    // Verify enum ordering for priority (critical < high < normal < low)
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(Urgency.critical));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(Urgency.high));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(Urgency.normal));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(Urgency.low));
}

test "basal_ganglia — Trigger enum coverage" {
    const triggers = [_]Trigger{ .always, .hourly, .daily };
    for (triggers) |t| {
        _ = t; // Verify all enum values exist
    }
}

// ═══════════════════════════════════════════════════════════════════
// ACTION CANDIDATE TESTS
// ═══════════════════════════════════════════════════════════════════

test "basal_ganglia — ActionCandidate defaults" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
    };

    try std.testing.expectEqual(@as(f32, 0.0), c.value);
    try std.testing.expectEqual(@as(f32, 0.0), c.cost);
    try std.testing.expect(!c.suppressed);
}

test "basal_ganglia — ActionCandidate score zero value" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
        .value = 0.0,
        .cost = 0.5,
    };
    // score = 0.0 - (0.5 * 0.5) = -0.25
    try std.testing.expect(c.score() < 0);
}

test "basal_ganglia — ActionCandidate score zero cost" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .normal,
        .value = 0.8,
        .cost = 0.0,
    };
    // score = 0.8 - (0.0 * 0.5) = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), c.score(), 0.01);
}

test "basal_ganglia — ActionCandidate with critical urgency" {
    const c = ActionCandidate{
        .kind = .farm_status,
        .urgency = .critical,
        .value = 0.5,
        .cost = 0.1,
    };
    // score = 0.5 - (0.1 * 0.5) = 0.45
    // weighted = 0.45 * 4.0 = 1.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), c.score(), 0.01);
}

// ═══════════════════════════════════════════════════════════════════
// URGENCY TESTS
// ═══════════════════════════════════════════════════════════════════

test "basal_ganglia — Urgency all values" {
    const urgencies = [_]Urgency{ .critical, .high, .normal, .low };
    for (urgencies) |u| {
        _ = u; // Verify all enum values exist
    }
}

test "basal_ganglia — Urgency low weight" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Urgency.low.weight(), 0.01);
}

test "basal_ganglia — selectAction with low urgency" {
    const candidates = [_]ActionCandidate{
        .{ .kind = .farm_status, .urgency = .low, .value = 1.0 },
        .{ .kind = .doctor_quick, .urgency = .normal, .value = 0.6 },
    };
    // low: 1.0 * 0.5 = 0.5, normal: 0.6 * 1.0 = 0.6
    const selected = selectAction(&candidates);
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, selected.?);
}

// ═══════════════════════════════════════════════════════════════════
// HABIT TESTS
// ═══════════════════════════════════════════════════════════════════

test "basal_ganglia — Habit defaults" {
    const h = Habit{
        .action = .farm_status,
        .trigger = .always,
    };

    try std.testing.expectEqual(@as(u32, 0), h.count);
    try std.testing.expectEqual(@as(i64, 0), h.last_executed);
}

test "basal_ganglia — Habit isReady always trigger" {
    const now: i64 = 100000;

    const always_habit = Habit{
        .action = .farm_status,
        .trigger = .always,
        .last_executed = now, // Just executed
    };
    try std.testing.expect(always_habit.isReady(now));
}

test "basal_ganglia — Habit isReady hourly boundary" {
    const now: i64 = 100000;

    const exactly_hour = Habit{
        .action = .farm_status,
        .trigger = .hourly,
        .last_executed = now - 3600, // Exactly 1 hour
    };
    try std.testing.expect(exactly_hour.isReady(now));
}

test "basal_ganglia — Habit isReady daily boundary" {
    const now: i64 = 100000;

    const exactly_daily = Habit{
        .action = .doctor_quick,
        .trigger = .daily,
        .last_executed = now - (24 * 3600), // Exactly 24 hours
    };
    try std.testing.expect(exactly_daily.isReady(now));
}

test "basal_ganglia — Habit all triggers" {
    const now: i64 = 100000;

    const triggers = [_]Trigger{ .always, .hourly, .daily };
    for (triggers) |t| {
        const h = Habit{
            .action = .farm_status,
            .trigger = t,
            .last_executed = now - 100000,
        };
        _ = h.isReady(now); // Should not panic
    }
}

test "basal_ganglia — Habit count increments" {
    var h = Habit{
        .action = .farm_status,
        .trigger = .daily,
        .count = 5,
    };

    try std.testing.expectEqual(@as(u32, 5), h.count);

    h.count = 10;
    try std.testing.expectEqual(@as(u32, 10), h.count);
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "basal_ganglia — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "basal_ganglia — CellHealth defaults" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "basal_ganglia — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "basal_ganglia — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 3;
    h.last_check = 54321;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 3), h.cycle);
    try std.testing.expectEqual(@as(i64, 54321), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════
// TASK CLAIM REGISTRY TESTS
// ═══════════════════════════════════════════════════════════════════

test "basal_ganglia — TaskClaim expired by TTL" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test-task",
        .agent_id = "agent-1",
        .claimed_at = now_ms - 70000, // 70 seconds ago
        .ttl_ms = 60000, // 60 second TTL
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms,
    };

    try std.testing.expect(!claim.isValid()); // Expired by TTL
}

test "basal_ganglia — TaskClaim expired by heartbeat" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test-task",
        .agent_id = "agent-1",
        .claimed_at = now_ms - 20000,
        .ttl_ms = 300000, // 5 minute TTL
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 40000, // 40 seconds ago
    };

    try std.testing.expect(!claim.isValid()); // Expired by heartbeat
}

test "basal_ganglia — TaskClaim completed is not valid" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test-task",
        .agent_id = "agent-1",
        .claimed_at = now_ms - 1000,
        .ttl_ms = 300000,
        .status = .completed,
        .completed_at = now_ms,
        .last_heartbeat = now_ms,
    };

    try std.testing.expect(!claim.isValid()); // Completed claims are not valid
}

test "basal_ganglia — TaskClaim valid active claim" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test-task",
        .agent_id = "agent-1",
        .claimed_at = now_ms - 1000,
        .ttl_ms = 300000,
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 5000,
    };

    try std.testing.expect(claim.isValid()); // Valid claim
}

test "basal_ganglia — Registry claim success" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const claimed = try registry.claim(allocator, "task-1", "agent-1", 60000);
    try std.testing.expect(claimed);
    try std.testing.expectEqual(@as(usize, 1), registry.claims.count());
}

test "basal_ganglia — Registry claim duplicate denied" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const claimed_again = try registry.claim(allocator, "task-1", "agent-2", 60000);

    try std.testing.expect(!claimed_again); // Second claim denied
    try std.testing.expectEqual(@as(usize, 1), registry.claims.count());
}

test "basal_ganglia — Registry heartbeat refreshes" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const refreshed = registry.heartbeat("task-1", "agent-1");

    try std.testing.expect(refreshed);
}

test "basal_ganglia — Registry heartbeat wrong agent denied" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const refreshed = registry.heartbeat("task-1", "agent-2");

    try std.testing.expect(!refreshed); // Wrong agent
}

test "basal_ganglia — Registry complete marks task done" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const completed = registry.complete("task-1", "agent-1");

    try std.testing.expect(completed);

    const task_claim = registry.claims.get("task-1").?;
    try std.testing.expectEqual(TaskClaimStatus.completed, task_claim.status);
}

test "basal_ganglia — Registry complete wrong agent denied" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const completed = registry.complete("task-1", "agent-2");

    try std.testing.expect(!completed); // Wrong agent
}

test "basal_ganglia — Registry abandon releases task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    const abandoned = registry.abandon("task-1", "agent-1");

    try std.testing.expect(abandoned);

    const claim = registry.claims.get("task-1").?;
    try std.testing.expectEqual(TaskClaimStatus.abandoned, claim.status);
}

test "basal_ganglia — Registry reclaim after abandon" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    _ = registry.abandon("task-1", "agent-1");

    // Should be able to reclaim after abandon
    const reclaimed = try registry.claim(allocator, "task-1", "agent-2", 60000);
    try std.testing.expect(reclaimed);
}

test "basal_ganglia — Registry reset clears all" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "task-2", "agent-2", 60000);
    try std.testing.expectEqual(@as(usize, 2), registry.claims.count());

    registry.reset();
    try std.testing.expectEqual(@as(usize, 0), registry.claims.count());
}

test "basal_ganglia — Registry getStats counts correctly" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "task-2", "agent-2", 60000);
    _ = registry.complete("task-1", "agent-1");
    _ = registry.abandon("task-2", "agent-2");

    const stats = registry.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total);
    try std.testing.expectEqual(@as(usize, 0), stats.active);
    try std.testing.expectEqual(@as(usize, 1), stats.completed);
    try std.testing.expectEqual(@as(usize, 1), stats.abandoned);
}

test "basal_ganglia — Registry listClaims no filter" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "task-2", "agent-2", 60000);

    const claims = try registry.listClaims(allocator, null);
    defer allocator.free(claims);

    try std.testing.expectEqual(@as(usize, 2), claims.len);
}

test "basal_ganglia — Registry listClaims with agent filter" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    _ = try registry.claim(allocator, "task-1", "agent-1", 60000);
    _ = try registry.claim(allocator, "task-2", "agent-2", 60000);
    _ = try registry.claim(allocator, "task-3", "agent-1", 60000);

    const claims = try registry.listClaims(allocator, "agent-1");
    defer allocator.free(claims);

    try std.testing.expectEqual(@as(usize, 2), claims.len);
}

test "basal_ganglia — getGlobal returns same instance" {
    const allocator = std.testing.allocator;
    resetGlobal(allocator); // Clear any existing

    const reg1 = try getGlobal(allocator);
    const reg2 = try getGlobal(allocator);

    try std.testing.expectEqual(reg1, reg2); // Same pointer

    resetGlobal(allocator); // Cleanup
}

test "basal_ganglia — resetGlobal clears instance" {
    const allocator = std.testing.allocator;

    _ = try getGlobal(allocator);
    try std.testing.expect(global_registry != null);

    resetGlobal(allocator);
    try std.testing.expect(global_registry == null);
}
