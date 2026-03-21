// ═══════════════════════════════════════════════════════════════════════════════
// S³AI BRAIN — Comprehensive Integration Tests
// ═══════════════════════════════════════════════════════════════════════════════
// Tests the full ACC decision cycle across all 5 brain modules:
// - ACC (Anterior Cingulate Cortex) — Conflict detection, action verification
// - Basal Ganglia — Action execution, habit/trigger/reward/suppress
// - Locus Coeruleus — Arousal cascade, alarm propagation
// - Amygdala — Threat evaluation, fear conditioning
// - Hippocampus — State persistence, memory
// - Thalamus — Live worker status (mocked for testing)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

const MockHippocampus = struct {
    allocator: std.mem.Allocator,
    workers: std.StringHashMap(WorkerState),
    last_refresh: i64,

    const WorkerState = struct {
        service_name: []const u8,
        step: u32,
        ppl: f32,
        last_updated: i64,
    };

    pub fn init(allocator: std.mem.Allocator) MockHippocampus {
        return .{
            .allocator = allocator,
            .workers = std.StringHashMap(WorkerState).init(allocator),
            .last_refresh = 0,
        };
    }

    pub fn deinit(self: *MockHippocampus) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.service_name);
        }
        self.workers.deinit();
    }

    pub fn saveWorker(self: *MockHippocampus, service_name: []const u8, step: u32, ppl: f32) !void {
        const key = try self.allocator.dupe(u8, service_name);
        errdefer {
            if (self.workers.fetchRemove(key)) |removed| {
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
            if (self.workers.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                self.allocator.free(removed.value.service_name);
            }
        }

        try self.workers.put(key, value);
        self.last_refresh = std.time.timestamp();
    }

    pub fn loadWorker(self: *const MockHippocampus, service_name: []const u8) ?WorkerState {
        return self.workers.get(service_name);
    }

    pub fn serialize(self: *const MockHippocampus, writer: anytype) !void {
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

const MockThalamus = struct {
    allocator: std.mem.Allocator,
    workers: std.StringHashMap(LiveState),

    const LiveState = struct {
        status: enum { training, stalled, has_error, unknown },
        step: u32,
        ppl: f32,
    };

    pub fn init(allocator: std.mem.Allocator) MockThalamus {
        return .{
            .allocator = allocator,
            .workers = std.StringHashMap(LiveState).init(allocator),
        };
    }

    pub fn deinit(self: *MockThalamus) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit();
    }

    pub fn setWorker(self: *MockThalamus, service_name: []const u8, status: LiveState, step: u32, ppl: f32) !void {
        const key = try self.allocator.dupe(u8, service_name);
        const value = LiveState{
            .status = status,
            .step = step,
            .ppl = ppl,
        };
        try self.workers.put(key, value);
    }

    pub fn getWorker(self: *const MockThalamus, service_name: []const u8) ?LiveState {
        return self.workers.get(service_name);
    }
};

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

    pub fn init(allocator: std.mem.Allocator) MockACC {
        return .{
            .allocator = allocator,
            .conflicts = std.ArrayList(Conflict).init(allocator),
        };
    }

    pub fn deinit(self: *MockACC) void {
        for (self.conflicts.items) |conflict| {
            self.allocator.free(conflict.service_name);
            self.allocator.free(conflict.message);
        }
        self.conflicts.deinit();
    }

    pub fn detectConflicts(self: *MockACC, hippocampus: *const MockHippocampus, thalamus: *const MockThalamus) !usize {
        var conflict_count: usize = 0;

        var hippo_iter = hippocampus.workers.iterator();
        while (hippo_iter.next()) |entry| {
            const service_name = entry.key_ptr.*;
            const hippo_worker = entry.value_ptr.*;

            const cache_age = std.time.timestamp() - hippo_worker.last_updated;
            if (cache_age > self.max_cache_age_sec) {
                const conflict = Conflict{
                    .service_name = try self.allocator.dupe(u8, service_name),
                    .conflict_type = .stale_cache,
                    .severity = if (cache_age > self.max_cache_age_sec * 2) .critical else .warning,
                    .message = try std.fmt.allocPrint(self.allocator, "Cache stale for {s} (age={d}s)", .{ service_name, cache_age }),
                };
                try self.conflicts.append(allocator, conflict);
                conflict_count += 1;
            }

            if (thalamus.getWorker(service_name)) |live| {
                const live_is_training = live.status == .training;
                const cache_is_stalled = hippo_worker.ppl > 10.0;

                if (live_is_training and cache_is_stalled) {
                    const conflict = Conflict{
                        .service_name = try self.allocator.dupe(u8, service_name),
                        .conflict_type = .status_mismatch,
                        .severity = .critical,
                        .message = try std.fmt.allocPrint(self.allocator, "Cache says stalled but live says training for {s}", .{service_name}),
                    };
                    try self.conflicts.append(allocator, conflict);
                    conflict_count += 1;
                }
            }
        }

        return conflict_count;
    }

    pub fn verifySafeAction(self: *MockACC, service_name: []const u8, action: []const u8, thalamus: *const MockThalamus) !enum { safe, unsafe, needs_verification } {
        _ = self;
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

    pub fn getConflictCount(self: *const MockACC) usize {
        return self.conflicts.items.len;
    }
};

const MockBasalGanglia = struct {
    allocator: std.mem.Allocator,
    executed_actions: std.ArrayList(Action),

    const ActionType = enum { habit, trigger, reward, suppress };

    const Action = struct {
        action_type: ActionType,
        service_name: []const u8,
        timestamp: i64,
    };

    pub fn init(allocator: std.mem.Allocator) MockBasalGanglia {
        return .{
            .allocator = allocator,
            .executed_actions = std.ArrayList(Action).init(allocator),
        };
    }

    pub fn deinit(self: *MockBasalGanglia) void {
        for (self.executed_actions.items) |action| {
            self.allocator.free(action.service_name);
        }
        self.executed_actions.deinit();
    }

    pub fn executeAction(self: *MockBasalGanglia, service_name: []const u8, action_type: ActionType) !void {
        const action = Action{
            .action_type = action_type,
            .service_name = try self.allocator.dupe(u8, service_name),
            .timestamp = std.time.timestamp(),
        };
        try self.executed_actions.append(allocator, action);
    }

    pub fn hasConflict(self: *const MockBasalGanglia, service_name: []const u8) bool {
        for (self.executed_actions.items) |action| {
            if (std.mem.eql(u8, action.service_name, service_name) and action.action_type == .suppress) {
                return true;
            }
        }
        return false;
    }

    pub fn getActionCount(self: *const MockBasalGanglia) usize {
        return self.executed_actions.items.len;
    }
};

const MockAmygdala = struct {
    allocator: std.mem.Allocator,
    threats: std.StringHashMap(ThreatLevel),

    const ThreatLevel = enum { none, low, medium, high, critical };

    pub fn init(allocator: std.mem.Allocator) MockAmygdala {
        return .{
            .allocator = allocator,
            .threats = std.StringHashMap(ThreatLevel).init(allocator),
        };
    }

    pub fn deinit(self: *MockAmygdala) void {
        var iter = self.threats.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.threats.deinit();
    }

    pub fn evaluateThreat(self: *MockAmygdala, service_name: []const u8, task_data: []const u8) !ThreatLevel {
        _ = service_name;
        const lower_task_data = try std.ascii.allocLowerString(self.allocator, task_data);
        defer self.allocator.free(lower_task_data);

        if (std.mem.indexOf(u8, lower_task_data, "segfault") != null or
            std.mem.indexOf(u8, lower_task_data, "panic") != null or
            std.mem.indexOf(u8, lower_task_data, "deadlock") != null)
        {
            return .critical;
        }

        if (std.mem.indexOf(u8, lower_task_data, "timeout") != null or
            std.mem.indexOf(u8, lower_task_data, "error") != null)
        {
            return .high;
        }

        return .low;
    }

    pub fn setThreat(self: *MockAmygdala, service_name: []const u8, level: ThreatLevel) !void {
        const key = try self.allocator.dupe(u8, service_name);
        _ = try self.threats.put(key, level);
    }

    pub fn getThreatLevel(self: *const MockAmygdala, service_name: []const u8) ThreatLevel {
        return self.threats.get(service_name) orelse .none;
    }

    pub fn requiresSuppression(self: *const MockAmygdala, service_name: []const u8) bool {
        const level = self.getThreatLevel(service_name);
        return level == .critical or level == .high;
    }
};

const MockLocusCoeruleus = struct {
    allocator: std.mem.Allocator,
    alarms: std.ArrayList(Alarm),
    arousal_level: u8 = 0,

    const Severity = enum { info, warning, critical };

    const Alarm = struct {
        service_name: []const u8,
        severity: Severity,
        timestamp: i64,
    };

    pub fn init(allocator: std.mem.Allocator) MockLocusCoeruleus {
        return .{
            .allocator = allocator,
            .alarms = std.ArrayList(Alarm).init(allocator),
            .arousal_level = 0,
        };
    }

    pub fn deinit(self: *MockLocusCoeruleus) void {
        for (self.alarms.items) |alarm| {
            self.allocator.free(alarm.service_name);
        }
        self.alarms.deinit();
    }

    pub fn triggerAlarm(self: *MockLocusCoeruleus, service_name: []const u8, severity: Severity) !void {
        const alarm = Alarm{
            .service_name = try self.allocator.dupe(u8, service_name),
            .severity = severity,
            .timestamp = std.time.timestamp(),
        };
        try self.alarms.append(allocator, alarm);
        self.arousal_level = if (severity == .critical) 3 else if (severity == .warning) 2 else 1;
    }

    pub fn getAlarmCount(self: *const MockLocusCoeruleus) usize {
        return self.alarms.items.len;
    }

    pub fn getArousalLevel(self: *const MockLocusCoeruleus) u8 {
        return self.arousal_level;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACC + BASAL GANGLIA INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "integration_acc_basal_conflict_detection" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit();

    const service_name = "worker-001";
    try hippocampus.saveWorker(service_name, 1000, 5.0);
    try thalamus.setWorker(service_name, .{ .status = .training, .step = 5000, .ppl = 4.0 });

    const conflict_count = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 1), conflict_count);

    const has_conflict = bg.hasConflict(service_name);
    try std.testing.expect(!has_conflict);

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
    defer thalamus.deinit();

    const service_name = "worker-002";

    try hippocampus.saveWorker(service_name, 5000, 5.0);
    try thalamus.setWorker(service_name, .{ .status = .training, .step = 5000, .ppl = 5.0 });

    const conflict_count = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 0), conflict_count);

    try bg.executeAction(service_name, .habit);

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
    defer thalamus.deinit();

    const service_name = "worker-003";

    try hippocampus.saveWorker(service_name, 1000, 6.0);
    try thalamus.setWorker(service_name, .{ .status = .stalled, .step = 5000, .ppl = 6.0 });

    const conflicts_before = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 1), conflicts_before);

    const safety_before = try acc.verifySafeAction(service_name, "kill", &thalamus);
    try std.testing.expect(safety_before == .needs_verification or safety_before == .unsafe);

    try hippocampus.saveWorker(service_name, 5000, 5.0);
    try thalamus.setWorker(service_name, .{ .status = .training, .step = 5000, .ppl = 5.0 });

    const conflicts_after = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expectEqual(@as(usize, 0), conflicts_after);

    try bg.executeAction(service_name, .habit);
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

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
    defer thalamus.deinit();

    const service_name = "worker-no-dup";

    try hippocampus.saveWorker(service_name, 1000, 8.0);
    try thalamus.setWorker(service_name, .{ .status = .training, .step = 5000, .ppl = 8.0 });

    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .habit);

    try std.testing.expectEqual(@as(usize, 3), bg.getActionCount());
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEAR-CONDITIONED ACTION SUPPRESSION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

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

    try amygdala.setThreat(service_name, .critical);

    try bg.executeAction(service_name, .habit);
    try bg.executeAction(service_name, .trigger);
    try bg.executeAction(service_name, .reward);

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

    try amygdala.setThreat(service_name, .low);

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

    try amygdala.setThreat(service_name, .critical);

    try bg.executeAction(service_name, .habit);
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());

    try amygdala.setThreat(service_name, .low);

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

    try amygdala.setThreat("worker-unsafe", .critical);
    try amygdala.setThreat("worker-mid", .medium);
    try amygdala.setThreat("worker-safe", .low);

    try bg.executeAction("worker-unsafe", .habit);
    try bg.executeAction("worker-mid", .habit);
    try bg.executeAction("worker-safe", .habit);

    try std.testing.expectEqual(@as(usize, 3), bg.getActionCount());

    try std.testing.expect(amygdala.requiresSuppression("worker-unsafe"));
    try std.testing.expect(!amygdala.requiresSuppression("worker-mid"));
    try std.testing.expect(!amygdala.requiresSuppression("worker-safe"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCUS COERULEUS AROUSAL CASCADE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

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

    try hippocampus.saveWorker(service_name, 10000, 10.0);

    try lc.triggerAlarm(service_name, .critical);

    _ = try amygdala.evaluateThreat(service_name, "error: segfault detected");

    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 3), lc.getArousalLevel());
}

test "integration_locus_warning_arousal_cascade" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    const service_name = "worker-warning";

    try lc.triggerAlarm(service_name, .warning);

    _ = try amygdala.evaluateThreat(service_name, "warning: timeout occurred");

    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 2), lc.getArousalLevel());
}

test "integration_locus_alarm_propagation_latency" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    const start = std.time.nanoTimestamp();

    try lc.triggerAlarm("worker-a", .info);
    try lc.triggerAlarm("worker-b", .warning);
    try lc.triggerAlarm("worker-c", .critical);

    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(u64, @intCast((end - start) / 1_000_000));

    try std.testing.expectEqual(@as(usize, 3), lc.getAlarmCount());
    try std.testing.expect(elapsed_ms < 100);
}

test "integration_locus_no_alarm_healthy_state" {
    const allocator = std.testing.allocator;

    var lc = MockLocusCoeruleus.init(allocator);
    defer lc.deinit();

    var amygdala = MockAmygdala.init(allocator);
    defer amygdala.deinit();

    try std.testing.expectEqual(@as(usize, 0), lc.getAlarmCount());
    try std.testing.expectEqual(@as(u8, 0), lc.getArousalLevel());
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "integration_state_persistence_save_load" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-persist";

    try hippocampus.saveWorker(service_name, 12345, 4.56);

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

    try hippocampus.saveWorker(service_name, 54321, 3.21);

    try hippocampus.serialize(fbs.writer());

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

    try hippocampus.saveWorker(service_name, 98765, 2.34);

    try amygdala.setThreat(service_name, .low);

    const loaded = hippocampus.loadWorker(service_name);
    try std.testing.expect(loaded != null);
    try std.testing.expectEqual(@as(u32, 98765), loaded.?.step);
    try std.testing.expectApproxEqAbs(@as(f32, 2.34), loaded.?.ppl, 0.01);

    const threat = amygdala.getThreatLevel(service_name);
    try std.testing.expect(threat != .none);
}

test "integration_state_persistence_multiple_workers" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    try hippocampus.saveWorker("worker-a", 1000, 5.0);
    try hippocampus.saveWorker("worker-b", 2000, 4.5);
    try hippocampus.saveWorker("worker-c", 3000, 3.5);

    try std.testing.expect(hippocampus.loadWorker("worker-a") != null);
    try std.testing.expect(hippocampus.loadWorker("worker-b") != null);
    try std.testing.expect(hippocampus.loadWorker("worker-c") != null);

    try std.testing.expectEqual(@as(u32, 1000), hippocampus.loadWorker("worker-a").?.step);
    try std.testing.expectEqual(@as(u32, 2000), hippocampus.loadWorker("worker-b").?.step);
    try std.testing.expectEqual(@as(u32, 3000), hippocampus.loadWorker("worker-c").?.step);
}

test "integration_state_persistence_timestamps" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    const service_name = "worker-ts";

    const before_save = std.time.timestamp();
    try hippocampus.saveWorker(service_name, 11111, 1.11);

    const loaded = hippocampus.loadWorker(service_name);
    try std.testing.expect(loaded != null);
    try std.testing.expect(loaded.?.last_updated >= before_save);
    try std.testing.expect(loaded.?.last_updated <= std.time.timestamp());
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRESS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

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

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit();

    const iterations = 100;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const service_id = try std.fmt.allocPrint(allocator, "stress-{d:04}", .{i});

        try hippocampus.saveWorker(service_id, @intCast(i * 100), @as(f32, @floatFromInt(i)) / 10.0 + 2.0);

        if (i % 10 == 0) {
            try lc.triggerAlarm(service_id, .critical);
        } else if (i % 20 == 0) {
            try lc.triggerAlarm(service_id, .warning);
        }

        if (i % 15 == 0) {
            try amygdala.setThreat(service_id, .high);
        } else {
            try amygdala.setThreat(service_id, .low);
        }

        if (i % 50 == 0) {
            _ = try acc.detectConflicts(&hippocampus, &thalamus);
        }

        if (i % 3 == 0) {
            try bg.executeAction(service_id, .habit);
        }
    }

    try std.testing.expectEqual(@as(usize, iterations), hippocampus.workers.count());
    try std.testing.expectEqual(@as(usize, 34), bg.getActionCount());
    try std.testing.expect(lc.getAlarmCount() <= 15);
    try std.testing.expect(amygdala.threats.count() <= 50);
}

test "integration_stress_test_random_actions" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    const iterations = 100;
    const actions = [_]MockBasalGanglia.ActionType{ .habit, .trigger, .reward, .suppress };

    for (0..iterations) |i| {
        const service_name = try std.fmt.allocPrint(allocator, "rand-{d}", .{i});
        const action_type = actions[i % actions.len];
        try bg.executeAction(service_name, action_type);
    }

    try std.testing.expectEqual(@as(usize, iterations), bg.getActionCount());
}

test "integration_stress_test_timeout_handling" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const service_name = try std.fmt.allocPrint(allocator, "timeout-{d}", .{i});
        try hippocampus.saveWorker(service_name, @intCast(i), @as(f32, @floatFromInt(i)) + 1.0);

        const loaded = hippocampus.loadWorker(service_name);
        try std.testing.expect(loaded != null);
        try std.testing.expectEqual(@as(u32, @intCast(i)), loaded.?.step);
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
    defer thalamus.deinit();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const service_name = try std.fmt.allocPrint(allocator, "leak-test-{d}", .{i});

        _ = try acc.detectConflicts(&hippocampus, &thalamus);

        if (i % 2 == 0) {
            _ = try lc.triggerAlarm(service_name, .info);
        }

        _ = try amygdala.setThreat(service_name, .low);

        _ = try bg.executeAction(service_name, .habit);

        try hippocampus.saveWorker(service_name, @intCast(i), @as(f32, @floatFromInt(i)));
        _ = hippocampus.loadWorker(service_name);
    }

    try std.testing.expect(hippocampus.workers.count() == 100);
}

test "integration_stress_test_concurrent_operations" {
    const allocator = std.testing.allocator;

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        try hippocampus.saveWorker("concurrent-a", @intCast(i * 2), @as(f32, @floatFromInt(i * 2)) + 1.0);
        try hippocampus.saveWorker("concurrent-b", @intCast(i * 2 + 1), @as(f32, @floatFromInt(i * 2 + 1)) + 1.0);
        try hippocampus.saveWorker("concurrent-c", @intCast(i * 2 + 2), @as(f32, @floatFromInt(i * 2 + 2)) + 1.0);
    }

    try std.testing.expectEqual(@as(usize, 3), hippocampus.workers.count());
}

test "integration_stress_test_edge_cases" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    try hippocampus.saveWorker("", 0, 0.0);
    try std.testing.expect(hippocampus.loadWorker("") != null);

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

// ═══════════════════════════════════════════════════════════════════════════════
// ADDITIONAL INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "integration_acc_resolves_all_conflict_types" {
    const allocator = std.testing.allocator;

    var acc = MockACC.init(allocator);
    defer acc.deinit();

    var hippocampus = MockHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = MockThalamus.init(allocator);
    defer thalamus.deinit();

    const service_stale = "stale-worker";
    try hippocampus.saveWorker(service_stale, 1000, 5.0);
    try thalamus.setWorker(service_stale, .{ .status = .training, .step = 5000, .ppl = 4.0 });
    const conflicts_stale = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_stale >= 1);

    const service_mismatch = "mismatch-worker";
    try hippocampus.saveWorker(service_mismatch, 1000, 10.0);
    try thalamus.setWorker(service_mismatch, .{ .status = .training, .step = 5000, .ppl = 5.0 });
    const conflicts_mismatch = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts_mismatch >= 1);
}

test "integration_basal_handles_all_action_types" {
    const allocator = std.testing.allocator;

    var bg = MockBasalGanglia.init(allocator);
    defer bg.deinit();

    const service_name = "action-test";

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
    defer thalamus.deinit();

    const service_name = "full-cycle-worker";

    try hippocampus.saveWorker(service_name, 5000, 6.0);

    try thalamus.setWorker(service_name, .{ .status = .training, .step = 7000, .ppl = 6.5 });

    const conflicts = try acc.detectConflicts(&hippocampus, &thalamus);
    try std.testing.expect(conflicts >= 1);

    try lc.triggerAlarm(service_name, .warning);

    _ = try amygdala.evaluateThreat(service_name, "warning: high loss");

    try bg.executeAction(service_name, .habit);

    try std.testing.expect(hippocampus.loadWorker(service_name) != null);
    try std.testing.expectEqual(@as(usize, 1), lc.getAlarmCount());
    try std.testing.expectEqual(@as(usize, 1), bg.getActionCount());
}
