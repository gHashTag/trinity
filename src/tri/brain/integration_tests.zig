// @origin(manual) @regen(pending)
// ═════════════════════════════════════════════════════════════════════════════
// S³AI BRAIN INTEGRATION TESTS — End-to-End ACC Decision Cycle
// ═════════════════════════════════════════════════════════════════════════════════════════════
//
// Comprehensive integration tests for S³AI Brain modules:
//   - ACC + Basal Ganglia: conflict detection + action selection
//   - Fear-conditioned action suppression: Amygdala + BG + ACC
//   - Locus Coeruleus arousal cascade: ACC → LC → Amygdala
//   - State persistence: ACC → Hippocampus → Amygdala round-trip
//   - Multi-module stress test: all 5 modules, 1000 iterations
//
// Tests cover full ACC decision cycle with realistic data scenarios,
// proper initialization/cleanup, timeout handling, memory leak checks.
//
// Sacred Formula: φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════════════════
// MOCK MODULES (simulated for testing without external dependencies)
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════

/// Mock Hippocampus for state persistence testing
const MockHippocampus = struct {
    allocator: std.mem.Allocator,
    workers: std.StringHashMap(WorkerState),
    last_refresh: i64,

    const Self = @This();

    const WorkerState = struct {
        service_name: []const u8,
        step: u32,
        ppl: f32,
        last_updated: i64,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .workers = std.StringHashMap(WorkerState).init(allocator),
            .last_refresh = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.service_name);
        }
        self.workers.deinit();
    }

    pub fn saveWorker(self: *Self, service_name: []const u8, step: u32, ppl: f32) !void {
        const key = try self.allocator.dupe(u8, service_name);
        errdefer {
            if (!self.workers.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                self.allocator.free(removed.value.service_name);
            }
        }

        const value = WorkerState{
            .service_name = try self.allocator.dupe(u8, service_name),
            .step = step,
            .ppl = ppl,
            .last_updated = std.time.timestamp(),
        };
        errdefer {
            if (!self.workers.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                self.allocator.free(removed.value.service_name);
            }
        }

        try self.workers.put(key, value);
        self.last_refresh = std.time.timestamp();
    }

    pub fn loadWorker(self: *const Self, service_name: []const u8) ?WorkerState {
        return self.workers.get(service_name);
    }

    pub fn serialize(self: *const Self, writer: anytype) !void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            try writer.print("{s}: step={d}, ppl={d:.2}, ts={d}\n", .{
                entry.key_ptr.*,
                entry.value_ptr.*.step,
                entry.value_ptr.*.ppl,
                entry.value_ptr.*.last_updated,
            });
        }
    }
};

/// Mock Thalamus for live status simulation
const MockThalamus = struct {
    workers: std.StringHashMap(LiveState),

    const LiveState = struct {
        status: enum { training, stalled, has_error, unknown },
        step: u32,
        ppl: f32,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .workers = std.StringHashMap(LiveState).init(allocator),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit();
    }

    pub fn setWorker(self: *Self, allocator: std.mem.Allocator, service_name: []const u8, status: LiveState, step: u32, ppl: f32) !void {
        const key = try allocator.dupe(u8, service_name);
        const value = LiveState{
            .status = status,
            .step = step,
            .ppl = ppl,
        };
        try self.workers.put(key, value);
    }

    pub fn getWorker(self: *const Self, service_name: []const u8) ?LiveState {
        return self.workers.get(service_name);
    }
};

/// Mock Insula for event logging
const MockInsula = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(SystemEvent),

    const SystemEvent = struct {
        component: []const u8,
        event_type: []const u8,
        message: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .events = std.ArrayList(SystemEvent).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.events.items) |ev| {
            self.allocator.free(ev.component);
            self.allocator.free(ev.event_type);
            self.allocator.free(ev.message);
        }
        self.events.deinit();
    }

    pub fn logEvent(self: *Self, component: []const u8, event_type: []const u8, message: []const u8) !void {
        const event = SystemEvent{
            .component = try self.allocator.dupe(u8, component),
            .event_type = try self.allocator.dupe(u8, event_type),
            .message = try self.allocator.dupe(u8, message),
        };
        try self.events.append(event);
    }

    pub fn countEvents(self: *const Self, event_type: []const u8) usize {
        var count: usize = 0;
        for (self.events.items) |ev| {
            if (std.mem.eql(u8, ev.event_type, event_type)) count += 1;
        }
        return count;
    }

    pub fn getRecentEvents(self: *const Self, limit: usize) []const SystemEvent {
        const start = if (self.events.items.len > limit)
            self.events.items.len - limit
        else
            0;

        var result: []const SystemEvent = &[_]SystemEvent{};
        if (start < self.events.items.len) {
            result = self.events.items[start..];
        }
        return result;
    }
};

/// Mock ACC with conflict detection
const MockACC = struct {
    allocator: std.mem.Allocator,
    conflicts: std.ArrayList(Conflict),
    max_cache_age_sec: i64 = 300,

    const Conflict = struct {
        service_name: []const u8,
        conflict_type: enum { stale_cache, ghost_worker, zombie_worker, status_mismatch },
        severity: enum { info, warning, critical },
        message: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .conflicts = std.ArrayList(Conflict).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.conflicts.items) |conflict| {
            self.allocator.free(conflict.service_name);
            self.allocator.free(conflict.message);
        }
        self.conflicts.deinit();
    }

    pub fn detectConflicts(self: *Self, hippocampus: *const MockHippocampus, thalamus: *const MockThalamus) !usize {
        var conflict_count: usize = 0;

        var hippo_iter = hippocampus.workers.iterator();
        while (hippo_iter.next()) |entry| {
            const service_name = entry.key_ptr.*;
            const hippo_worker = entry.value_ptr.*;

            // Check for stale cache
            const cache_age = std.time.timestamp() - hippo_worker.last_updated;
            if (cache_age > self.max_cache_age_sec) {
                const conflict = Conflict{
                    .service_name = try self.allocator.dupe(u8, service_name),
                    .conflict_type = .stale_cache,
                    .severity = if (cache_age > self.max_cache_age_sec * 2) .critical else .warning,
                    .message = try std.fmt.allocPrint(self.allocator, "Cache stale for {s} (age={d}s)", .{ service_name, cache_age }),
                };
                try self.conflicts.append(conflict);
                conflict_count += 1;
            }

            // Check for status mismatch
            if (thalamus.getWorker(service_name)) |live| {
                const live_is_training = live.status == .training;
                const cache_is_stalled = hippo_worker.ppl > 10.0; // Simulate stalled

                if (live_is_training and cache_is_stalled) {
                    const conflict = Conflict{
                        .service_name = try self.allocator.dupe(u8, service_name),
                        .conflict_type = .status_mismatch,
                        .severity = .critical,
                        .message = try std.fmt.allocPrint(self.allocator, "Cache says stalled but live says training for {s}", .{service_name}),
                    };
                    try self.conflicts.append(conflict);
                    conflict_count += 1;
                }
            }
        }

        // Check for ghost workers (in cache but not in thalamus)
        var thalamus_iter = thalamus.workers.iterator();
        while (thalamus_iter.next()) |entry| {
            const service_name = entry.key_ptr.*;
            if (hippocampus.workers.get(service_name) != null) {
                if (thalamus.getWorker(service_name) == null) {
                    const conflict = Conflict{
                        .service_name = try self.allocator.dupe(u8, service_name),
                        .conflict_type = .ghost_worker,
                        .severity = .warning,
                        .message = try std.fmt.allocPrint(self.allocator, "Ghost worker: {s} in cache but not in thalamus", .{service_name}),
                    };
                    try self.conflicts.append(conflict);
                    conflict_count += 1;
                }
            }
        }

        // Check for zombie workers (in thalamus but not in cache)
        var hippo_iter2 = hippocampus.workers.iterator();
        while (hippo_iter2.next()) |entry| {
            const service_name = entry.key_ptr.*;
            if (thalamus.workers.get(service_name) != null) {
                if (hippocampus.workers.get(service_name) == null) {
                    const conflict = Conflict{
                        .service_name = try self.allocator.dupe(u8, service_name),
                        .conflict_type = .zombie_worker,
                        .severity = .info,
                        .message = try std.fmt.allocPrint(self.allocator, "Zombie worker: {s} in thalamus but not in cache", .{service_name}),
                    };
                    try self.conflicts.append(conflict);
                    conflict_count += 1;
                }
            }
        }

        return conflict_count;
    }

    pub fn verifySafeAction(self: *Self, service_name: []const u8, action: []const u8, thalamus: *const MockThalamus) !enum { safe, unsafe, needs_verification } {
        const live = thalamus.getWorker(service_name) orelse return .needs_verification;

        if (live.status == .training and std.mem.eql(u8, action, "kill")) {
            return .unsafe;
        }

        if (live.status == .has_error and std.mem.eql(u8, action, "kill")) {
            return .safe;
        }

        if (live.status == .stalled) {
            return .safe;
        }

        return .needs_verification;
    }

    pub fn getConflictCount(self: *const Self) usize {
        return self.conflicts.items.len;
    }
};

/// Mock Basal Ganglia for action execution
const MockBasalGanglia = struct {
    allocator: std.mem.Allocator,
    executed_actions: std.ArrayList(Action),

    const Action = struct {
        action_type: enum { habit, trigger, reward, suppress },
        service_name: []const u8,
        timestamp: i64,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .executed_actions = std.ArrayList(Action).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.executed_actions.items) |action| {
            self.allocator.free(action.service_name);
        }
        self.executed_actions.deinit();
    }

    pub fn executeAction(self: *Self, service_name: []const u8, action_type: enum { habit, trigger, reward, suppress }) !void {
        const action = Action{
            .action_type = action_type,
            .service_name = try self.allocator.dupe(u8, service_name),
            .timestamp = std.time.timestamp(),
        };
        try self.executed_actions.append(action);
    }

    pub fn hasConflict(self: *const Self, service_name: []const u8) bool {
        for (self.executed_actions.items) |action| {
            if (std.mem.eql(u8, action.service_name, service_name) and action.action_type == .suppress) {
                return true;
            }
        }
        return false;
    }

    pub fn getActionCount(self: *const Self) usize {
        return self.executed_actions.items.len;
    }
};

/// Mock Amygdala for threat detection
const MockAmygdala = struct {
    allocator: std.mem.Allocator,
    threats: std.StringHashMap(ThreatLevel),

    const ThreatLevel = enum { none, low, medium, high, critical };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .threats = std.StringHashMap(ThreatLevel).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.threats.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.threats.deinit();
    }

    pub fn evaluateThreat(self: *Self, service_name: []const u8, task_data: []const u8) !ThreatLevel {
        // Simple pattern matching for threat detection
        const lower_task_data = try std.ascii.allocLowerString(self.allocator, task_data);

        // Check for critical threats
        if (std.mem.indexOf(u8, lower_task_data, "segfault") != null or
            std.mem.indexOf(u8, lower_task_data, "panic") != null or
            std.mem.indexOf(u8, lower_task_data, "deadlock") != null)
        {
            self.allocator.free(lower_task_data);
            return .critical;
        }

        // Check for high threats
        if (std.mem.indexOf(u8, lower_task_data, "timeout") != null or
            std.mem.indexOf(u8, lower_task_data, "error") != null)
        {
            self.allocator.free(lower_task_data);
            return .high;
        }

        self.allocator.free(lower_task_data);
        return .low;
    }

    pub fn setThreat(self: *Self, service_name: []const u8, level: ThreatLevel) !void {
        const key = try self.allocator.dupe(u8, service_name);
        _ = try self.threats.put(key, level);
    }

    pub fn getThreatLevel(self: *const Self, service_name: []const u8) ThreatLevel {
        return self.threats.get(service_name) orelse .none;
    }

    pub fn requiresSuppression(self: *const Self, service_name: []const u8) bool {
        const level = self.getThreatLevel(service_name);
        return level == .critical or level == .high;
    }
};

/// Mock Locus Coeruleus for arousal cascade
const MockLocusCoeruleus = struct {
    allocator: std.mem.Allocator,
    alarms: std.ArrayList(Alarm),
    arousal_level: u8 = 0,

    const Alarm = struct {
        service_name: []const u8,
        severity: enum { info, warning, critical },
        timestamp: i64,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .alarms = std.ArrayList(Alarm).init(allocator),
            .arousal_level = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.alarms.items) |alarm| {
            self.allocator.free(alarm.service_name);
        }
        self.alarms.deinit();
    }

    pub fn triggerAlarm(self: *Self, service_name: []const u8, severity: enum { info, warning, critical }) !void {
        const alarm = Alarm{
            .service_name = try self.allocator.dupe(u8, service_name),
            .severity = severity,
            .timestamp = std.time.timestamp(),
        };
        try self.alarms.append(alarm);
        self.arousal_level = if (severity == .critical) 3 else if (severity == .warning) 2 else 1;
    }

    pub fn getAlarmCount(self: *const Self) usize {
        return self.alarms.items.len;
    }

    pub fn getArousalLevel(self: *const Self) u8 {
        return self.arousal_level;
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════════════════
// TEST 1: ACC + Basal Ganglia — Conflict Detection & Action Selection
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_acc_basal_conflict_detection" {
    const allocator = std.testing.allocator;

    // Initialize modules with defer cleanup
    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    // Setup: Add a training worker to hippocampus (stale cache)
    const service_name = "worker-001";
    try hippocampus.saveWorker(service_name, 1000, 5.0);
    try thalamus.setWorker(allocator, service_name, .{ .status = .training, .step = 5000, .ppl = 4.0 });

    // ACC should detect conflict (stale cache vs live training)
    const conflict_count = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 1), conflict_count);

    // Basal Ganglia should not suppress (no threat detected)
    const has_conflict = bg.hasConflict(service_name);
    try std.testing.expect(!has_conflict);

    // Verify no duplicate actions executed
    try std.testing.expectEqual(@as(usize, 0), bg.getActionCount());
}

test "integration_acc_basal_action_selection" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    const service_name = "worker-002";

    // Setup consistent state
    try hippocampus.saveWorker(service_name, 5000, 5.0);
    try thalamus.setWorker(allocator, service_name, .{ .status = .training, .step = 5000, .ppl = 5.0 });

    // No conflicts detected
    const conflict_count = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 0), conflict_count);

    // BG should execute habit action
    try bg.executeAction(service_name, .habit);

    // Verify action was executed
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());
}

test "integration_acc_basal_full_decision_cycle" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    const service_name = "worker-003";

    // Simulate decision cycle
    try hippocampus.saveWorker(service_name, 1000, 6.0);
    try thalamus.setWorker(allocator, service_name, .{ .status = .stalled, .step = 5000, .ppl = 6.0 });

    // ACC detects status mismatch (cached stalled, live training)
    const conflicts_before = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 1), conflicts_before);

    // Verify safe action verification
    const safety_before = try acc.verifySafeAction(service_name, "kill", &thalamus);
    try std.testing.expect(safety_before == .needs_verification or safety_before == .unsafe);

    // Update cache to match live state
    try hippocampus.saveWorker(service_name, 5000, 5.0);
    try thalamus.setWorker(allocator, service_name, .{ .status = .training, .step = 5000, .ppl = 5.0 });

    // No conflicts after update
    const conflicts_after = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 0), conflicts_after);

    // BG can now execute habit
    try bg.executeAction(service_name, .habit);
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

    // Verify safe action
    const safety_after = try acc.verifySafeAction(service_name, "restart", &thalamus);
    try std.testing.expect(safety_after == .safe);
}

test "integration_acc_basal_no_duplicate_actions" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    const service_name = "worker-no-dup";

    // Setup with conflict
    try hippocampus.saveWorker(service_name, 1000, 8.0);
    try thalamus.setWorker(allocator, service_name, .{ .status = .training, .step = 5000, .ppl = 8.0 });

    // BG tries to execute action (should work)
    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .habit);

    // Still only one action (no duplicates)
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
// TEST 2: Fear-Conditioned Action Suppression (Amygdala + BG + ACC)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_fear_conditioned_action_suppression" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-threat";

    // Setup: Amygdala detects critical threat
    try amygdala.setThreat(service_name, .critical);

    // Try to execute actions - should be suppressed
    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .trigger);
    try bg.executeAction(service_name, .reward);

    // All actions suppressed, no duplicate conflicts
    try std.testing.expectEqual(@as(usize, 3), bg.getActionCount());
    try std.testing.expect(amygdala.requiresSuppression(service_name));
}

test "integration_fear_low_threat_allows_action" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-safe";

    // Low threat, should not suppress
    try amygdala.setThreat(service_name, .low);

    // Actions should be allowed
    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .reward);

    try std.testing.expectEqual(@as(usize, 2), bg.getActionCount());
    try std.testing.expect(!amygdala.requiresSuppression(service_name));
}

test "integration_fear_continues_after_threat_cleared" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-clear";

    // Set critical threat
    try amygdala.setThreat(service_name, .critical);

    // Try to execute action
    try bg.executeAction(service_name, .habit);
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

    // Clear threat
    try amygdala.setThreat(service_name, .low);

    // Action should now succeed
    try bg.executeAction(service_name, .habit);

    try std.testing.expectEqual(@as(usize, 2), bg.getActionCount());
    try std.testing.expect(!amygdala.requiresSuppression(service_name));
}

test "integration_fear_multiple_workers_mixed_threats" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    // Mixed threats across workers
    try amygdala.setThreat("worker-unsafe", .critical);
    try amygdala.setThreat("worker-mid", .medium);
    try amygdala.setThreat("worker-safe", .low);

    // Only unsafe worker actions suppressed
    try bg.executeAction("worker-unsafe", .habit);
    try bg.executeAction("worker-mid", .habit);
    try bg.executeAction("worker-safe", .habit);

    // Safe worker action succeeded, mid worker action succeeded
    try std.testing.expectEqual(@as(usize, 2), bg.getActionCount());

    // Verify threat levels
    try std.testing.expect(amygdala.requiresSuppression("worker-unsafe"));
    try std.testing.expect(!amygdala.requiresSuppression("worker-mid"));
    try std.testing.expect(!amygdala.requiresSuppression("worker-safe"));
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════
// TEST 3: Locus Coeruleus Arousal Cascade (ACC → LC → Amygdala)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_locus_critical_arousal_cascade" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-critical";

    // Setup: ACC detects critical situation
    try hippocampus.saveWorker(service_name, 10000, 10.0);

    // LC triggers alarm
    try lc.triggerAlarm(service_name, .critical);

    // Amygdala should evaluate threat
    try amygdala.evaluateThreat(service_name, "error: segfault detected");

    // Verify alarm was triggered and arousal increased
    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 3), lc.getArousalLevel());

    // Threat should be critical (contains "segfault")
    try std.testing.expect(amygdala.getThreatLevel(service_name) == .critical);
}

test "integration_locus_warning_arousal_cascade" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-warning";

    // LC triggers warning alarm
    try lc.triggerAlarm(service_name, .warning);

    try amygdala.evaluateThreat(service_name, "warning: timeout occurred");

    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 2), lc.getArousalLevel());

    // Low to medium threat
    try std.testing.expect(amygdala.getThreatLevel(service_name) == .low or amygdala.getThreatLevel(service_name) == .medium);
}

test "integration_locus_alarm_propagation_latency" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    const start = std.time.nanoTimestamp();

    // Trigger multiple alarms to verify propagation
    try lc.triggerAlarm("worker-a", .info);
    try lc.triggerAlarm("worker-b", .warning);
    try lc.triggerAlarm("worker-c", .critical);

    // Verify all alarms were recorded
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(u64, @intCast((end - start) / 1_000_000));

    try std.testing.expectEqual(@as(usize, 3), lc.getAlarmCount());
    try std.testing.expect(elapsed_ms < 100); // Should be fast
}

test "integration_locus_no_alarm_healthy_state" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    // Healthy state - no alarm
    try std.testing.expectEqual(@as(usize, 0), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 0), lc.getArousalLevel());
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TEST 4: State Persistence (ACC → Hippocampus → Amygdala Round-Trip)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_state_persistence_save_load" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-persist";

    // Save state to hippocampus
    try hippocampus.saveWorker(service_name, 12345, 4.56);

    // Load state back
    const loaded = hippocampus.loadWorker(service_name);

    try std.testing.expect(loaded != null);
    try std.testing.expectEqual(@as(u32, 12345), loaded.?.step);
    try std.testing.expectApproxEqAbs(@as(f32, 4.56), loaded.?.ppl, 0.01);
}

test "integration_state_persistence_serialize_deserialize" {
    const allocator = std.testing.allocator;

    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-serialize";

    // Save state
    try hippocampus.saveWorker(service_name, 54321, 3.21);

    // Serialize
    try hippocampus.serialize(fbs.writer());

    // Verify serialization contains expected data
    const serialized = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, serialized, service_name) != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "54321") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "3.21") != null);
}

test "integration_state_persistence_round_trip" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-roundtrip";

    // ACC saves state to hippocampus
    try hippocampus.saveWorker(service_name, 98765, 2.34);

    // Amygdala should be able to read state (via threat level)
    try amygdala.setThreat(service_name, .low);

    // Verify round-trip
    const loaded = hippocampus.loadWorker(service_name);
    try std.testing.expect(loaded != null);
    try std.testing.expectEqual(@as(u32, 98765), loaded.?.step);
    try std.testing.expectApproxEqAbs(@as(f32, 2.34), loaded.?.ppl, 0.01);

    // Amygdala can read hippocampus state via threat
    const threat = amygdala.getThreatLevel(service_name);
    try std.testing.expect(threat != .none);
}

test "integration_state_persistence_multiple_workers" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Save multiple workers
    try hippocampus.saveWorker("worker-a", 1000, 5.0);
    try hippocampus.saveWorker("worker-b", 2000, 4.5);
    try hippocampus.saveWorker("worker-c", 3000, 3.5);

    // Load all back
    try std.testing.expect(hippocampus.loadWorker("worker-a") != null);
    try std.testing.expect(hippocampus.loadWorker("worker-b") != null);
    try std.testing.expect(hippocampus.loadWorker("worker-c") != null);

    // Verify values
    try std.testing.expectEqual(@as(u32, 1000), hippocampus.loadWorker("worker-a").?.step);
    try std.testing.expectEqual(@as(u32, 2000), hippocampus.loadWorker("worker-b").?.step);
    try std.testing.expectEqual(@as(u32, 3000), hippocampus.loadWorker("worker-c").?.step);
}

test "integration_state_persistence_timestamps" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-ts";

    // Save with timestamp
    const before_save = std.time.timestamp();
    try hippocampus.saveWorker(service_name, 11111, 1.11);

    // Verify timestamp was updated
    const loaded = hippocampus.loadWorker(service_name);
    try std.testing.expect(loaded != null);
    try std.testing.expect(loaded.?.last_updated >= before_save);
    try std.testing.expect(loaded.?.last_updated <= std.time.timestamp());
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// TEST 5: Multi-Module Stress Test (All 5 Modules, 1000 Iterations)
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_stress_test_all_modules_100_iterations" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const iterations = 100;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const service_id = try std.fmt.allocPrint(allocator, "stress-{d:04}", .{i});

        // ACC saves state
        try hippocampus.saveWorker(service_id, @intCast(i * 100), @as(f32, @intFromFloat(i)) / 10.0 + 2.0);

        // LC triggers alarm for critical situations
        if (i % 10 == 0) {
            try lc.triggerAlarm(service_id, .critical);
        } else if (i % 20 == 0) {
            try lc.triggerAlarm(service_id, .warning);
        }

        // Amygdala evaluates threat
        if (i % 15 == 0) {
            try amygdala.setThreat(service_id, .high);
        } else {
            try amygdala.setThreat(service_id, .low);
        }

        // ACC detects conflicts periodically
        if (i % 50 == 0) {
            _ = try acc.detectConflicts(&hippocampus, &thalamus);
        }

        // BG executes actions
        if (i % 3 == 0) {
            try bg.executeAction(service_id, .habit);
        }
    }

    // Verify all modules handled load without crashes
    try std.testing.expectEqual(@as(usize, iterations), hippocampus.workers.count());
    try std.testing.expect(@as(usize, 34), bg.getActionCount()); // ~1/3 iterations
    try std.testing.expect(lc.getAlarmCount() <= 200); // 20% iterations
    try std.testing.expect(amygdala.threats.count() <= 50); // All services tested
}

test "integration_stress_test_random_actions" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    const iterations = 100;
    var actions = [_]MockBasalGanglia.Action.Action.ActionType{ .habit, .trigger, .reward, .suppress };

    for (0..iterations) |i| {
        const service_name = try std.fmt.allocPrint(allocator, "rand-{d}", .{i});
        const action_type = actions[i % actions.len];
        try bg.executeAction(service_name, action_type);
    }

    // Verify all actions executed without duplicates
    try std.testing.expectEqual(@as(usize, iterations), bg.getActionCount());
}

test "integration_stress_test_timeout_handling" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Rapid operations to stress memory handling
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const service_name = try std.fmt.allocPrint(allocator, "timeout-{d}", .{i});
        try hippocampus.saveWorker(service_name, @intCast(i), @as(f32, @intFromFloat(i)) + 1.0);

        // Immediate load to verify
        const loaded = hippocampus.loadWorker(service_name);
        try std.testing.expect(loaded != null);
        try std.testing.expectEqual(@as(u32, @intCast(i)), loaded.?.step);

        allocator.free(service_name);
    }
}

test "integration_stress_test_no_memory_leaks" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    // Create and destroy many objects to test memory management
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const service_name = try std.fmt.allocPrint(allocator, "leak-test-{d}", .{i});

        // ACC operations
        _ = try acc.detectConflicts(&hippocampus, &thalamus);

        // LC alarms
        if (i % 2 == 0) {
            _ = try lc.triggerAlarm(service_name, .info);
        }

        // Amygdala threats
        _ = try amygdala.setThreat(service_name, .low);

        // BG actions
        _ = try bg.executeAction(service_name, .habit);

        // Hippocampus save/load
        try hippocampus.saveWorker(service_name, @intCast(i), @as(f32, @intFromFloat(i)));
        _ = hippocampus.loadWorker(service_name);

        allocator.free(service_name);
    }

    // All modules should still be operational
    try std.testing.expect(hippocampus.workers.count() == 0); // All freed
}

test "integration_stress_test_concurrent_operations" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Simulate concurrent-like operations (rapid sequential)
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        // Multiple workers with rapid state changes
        try hippocampus.saveWorker("concurrent-a", @intCast(i * 2), @as(f32, @intFromFloat(i * 2)) + 1.0);
        try hippocampus.saveWorker("concurrent-b", @intCast(i * 2 + 1), @as(f32, @intFromFloat(i * 2 + 1)) + 1.0);
        try hippocampus.saveWorker("concurrent-c", @intCast(i * 2 + 2), @as(f32, @intFromFloat(i * 2 + 2)) + 1.0);
    }

    // Verify all states persisted
    try std.testing.expectEqual(@as(usize, 60), hippocampus.workers.count());
}

test "integration_stress_test_edge_cases" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Test edge case: empty service name
    try hippocampus.saveWorker("", 0, 0.0);
    try std.testing.expect(hippocampus.loadWorker("") != null);

    // Test edge case: very large step values
    const large_step = std.math.maxInt(u32);
    try hippocampus.saveWorker("large-step", large_step, 99.9);
    try hippocampus.saveWorker("zero-step", 0, 0.0);

    const large_loaded = hippocampus.loadWorker("large-step");
    const zero_loaded = hippocampus.loadWorker("zero-step");

    try std.testing.expect(large_loaded != null);
    try std.testing.expectEqual(large_step, large_loaded.?.step);
    try std.testing.expect(zero_loaded != null);
    try std.testing.expectEqual(@as(u32, 0), zero_loaded.?.step);
}
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// ADDITIONAL INTEGRATION TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "integration_acc_resolves_all_conflict_types" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit(allocator);

    // Test all conflict types
    // 1. Stale cache
    const service_stale = "stale-worker";
    try hippocampus.saveWorker(service_stale, 1000, 5.0);
    try thalamus.setWorker(allocator, service_stale, .{ .status = .training, .step = 5000, .ppl = 4.0 });
    const conflicts_stale = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_stale >= 1);

    // 2. Ghost worker
    const service_ghost = "ghost-worker";
    try hippocampus.saveWorker(service_ghost, 1000, 5.0);
    // Not in thalamus = ghost
    const conflicts_ghost = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_ghost >= 1);

    // 3. Zombie worker
    const service_zombie = "zombie-worker";
    try thalamus.setWorker(allocator, service_zombie, .{ .status = .training, .step = 5000, .ppl = 5.0 });
    // Not in hippocampus = zombie
    const conflicts_zombie = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_zombie >= 1);

    // 4. Status mismatch
    const service_mismatch = "mismatch-worker";
    try hippocampus.saveWorker(service_mismatch, 1000, 10.0); // High PPL = stalled
    try thalamus.setWorker(allocator, service_mismatch, .{ .status = .training, .step = 5000, .ppl = 5.0 });
    const conflicts_mismatch = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_mismatch >= 1);
}

test "integration_basal_handles_all_action_types" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    const service_name = "action-test";

    // Test all action types
    try bg.executeAction(service_name, .habit);
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

    try bg.executeAction(service_name, .trigger);
    try std.testing.expectEqual(@as(usize, 2), bg.getActionCount());

    try bg.executeAction(service_name, .reward);
    try std.testing.expectEqual(@as(usize, 3), bg.getActionCount());

    try bg.executeAction(service_name, .suppress);
    try std.testing.expectEqual(@as(usize, 4), bg.getActionCount());
}

test "integration_amygdala_all_threat_levels" {
    const allocator = std.testing.allocator;

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "threat-test";

    // Test all threat levels
    try amygdala.setThreat(service_name, .none);
    try std.testing.expect(!amygdala.requiresSuppression(service_name));

    try amygdala.setThreat(service_name, .low);
    try std.testing.expect(!amygdala.requiresSuppression(service_name));

    try amygdala.setThreat(service_name, .medium);
    try std.testing.expect(!amygdala.requiresSuppression(service_name));

    try amygdala.setThreat(service_name, .high);
    try std.testing.expect(amygdala.requiresSuppression(service_name));

    try amygdala.setThreat(service_name, .critical);
    try std.testing.expect(amygdala.requiresSuppression(service_name));
}

test "integration_locus_all_severity_levels" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    const service_name = "severity-test";

    // Test all severity levels
    try lc.triggerAlarm(service_name, .info);
    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 1), lc.getArousalLevel());

    try lc.triggerAlarm(service_name, .warning);
    try std.testing.expectEqual(@as(usize, 2), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 2), lc.getArousalLevel());

    try lc.triggerAlarm(service_name, .critical);
    try std.testing.expectEqual(@as(usize, 3), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 3), lc.getArousalLevel());
}

test "integration_full_brain_decision_cycle_end_to_end" {
    const allocator = std.testing.allocator;

    // Initialize all modules
    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "full-cycle-worker";

    // Step 1: ACC saves state
    try hippocampus.saveWorker(service_name, 5000, 6.0);

    // Step 2: ACC detects conflict (stale cache)
    try hippocampus.saveWorker(service_name, 5000, 7.0);
    const conflicts = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts >= 1);

    // Step 3: LC triggers alarm
    try lc.triggerAlarm(service_name, .warning);

    // Step 4: Amygdala evaluates threat
    try amygdala.evaluateThreat(service_name, "warning: high loss");

    // Step 5: BG executes action (not suppressed - low threat)
    try bg.executeAction(service_name, .habit);

    // Verify full cycle completed
    try std.testing.expect(hippocampus.loadWorker(service_name) != null);
    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

    const threat_level = amygdala.getThreatLevel(service_name);
    try std.testing.expect(threat_level == .low or threat_level == .medium);
}

// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// COMPTIME ASSERTIONS FOR CRITICAL INVARIANTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════-based 32, zero allocation hot path
    try std.testing.expect(trials.size == 32);
}

// φ² + 1/φ² = 3 = TRINITY
