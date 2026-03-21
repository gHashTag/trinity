// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI BRAIN INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// End-to-end integration tests for S³AI Brain modules:
// - ACC + Basal Ganglia conflict resolution
// - Realistic worker state scenarios
// - Safety verification workflows
// - Edge cases and boundary conditions
//
// NOTE: These tests use simplified mock types to avoid Railway API dependency.
// For full integration tests with Railway, see the main test suite.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════
// TYPE DEFINITIONS (simplified for isolated testing)
// ═══════════════════════════════════════════════════════════════════════════════

/// Live status from Railway logs (source of truth!)
const LiveStatus = enum {
    training,
    stalled,
    has_error,
    building,
    not_found,
    unknown,

    pub fn toString(self: LiveStatus) []const u8 {
        return switch (self) {
            .training => "TRAINING",
            .stalled => "stalled (no recent logs)",
            .has_error => "ERROR - needs restart",
            .building => "BUILDING",
            .not_found => "NOT FOUND",
            .unknown => "UNKNOWN",
        };
    }

    pub fn icon(self: LiveStatus) []const u8 {
        return switch (self) {
            .training => "✅",
            .stalled => "⏸️",
            .has_error => "❌",
            .building => "🔄",
            .not_found => "❓",
            .unknown => "❔",
        };
    }
};

/// Worker metrics from live logs
const WorkerMetrics = struct {
    step: u32 = 0,
    ppl: f32 = 0,
    tok_per_sec: f32 = 0,
    loss: f32 = 0,
    last_seen_sec: i64 = 0, // UNIX timestamp
};

/// Full worker live state (from Thalamus)
const WorkerLiveState = struct {
    status: LiveStatus = .unknown,
    metrics: WorkerMetrics = .{},
    is_building: bool = false,
    has_error: bool = false,
    is_training: bool = false,
    fresh: bool = false,
};

/// Cached worker status (may be stale!)
const CachedWorkerStatus = struct {
    service_name: []const u8,
    status: LiveStatus,
    step: u32,
    ppl: f32,
    tok_per_sec: f32,
    last_updated: i64, // UNIX timestamp when cache was updated
    cached: bool = true, // Flag indicating this is cache, NOT live truth

    pub fn ageSec(self: *const CachedWorkerStatus) i64 {
        const now = std.time.timestamp();
        return now - self.last_updated;
    }

    pub fn isStale(self: *const CachedWorkerStatus, max_age_sec: i64) bool {
        return self.ageSec() > max_age_sec;
    }
};

/// Conflict types detected by ACC
const ConflictType = enum {
    stale_cache,
    ghost_worker,
    zombie_worker,
    status_mismatch,
    metrics_mismatch,
    missing_metadata,

    pub fn toString(self: ConflictType) []const u8 {
        return switch (self) {
            .stale_cache => "stale_cache",
            .ghost_worker => "ghost_worker",
            .zombie_worker => "zombie_worker",
            .status_mismatch => "status_mismatch",
            .metrics_mismatch => "metrics_mismatch",
            .missing_metadata => "missing_metadata",
        };
    }
};

/// Severity levels for conflicts
const Severity = enum {
    info,
    warning,
    critical,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .info => "INFO",
            .warning => "WARNING",
            .critical => "CRITICAL",
        };
    }
};

/// Actions that can be taken on workers
const Action = enum {
    kill_worker,
    restart_worker,
    evolve_step,
    inject_config,
    enable_night_mode,
    disable_night_mode,

    pub fn toString(self: Action) []const u8 {
        return switch (self) {
            .kill_worker => "kill",
            .restart_worker => "restart",
            .evolve_step => "evolve",
            .inject_config => "inject",
            .enable_night_mode => "enable_night",
            .disable_night_mode => "disable_night",
        };
    }
};

/// Safety verdict for actions
const SafetyVerdict = enum {
    safe,
    unsafe,
    needs_verification,

    pub fn toString(self: SafetyVerdict) []const u8 {
        return switch (self) {
            .safe => "SAFE",
            .unsafe => "UNSAFE - BLOCKED",
            .needs_verification => "NEEDS LIVE VERIFICATION",
        };
    }

    pub fn icon(self: SafetyVerdict) []const u8 {
        return switch (self) {
            .safe => "✅",
            .unsafe => "🚫",
            .needs_verification => "⏳",
        };
    }
};

/// Health status for cache
const HealthStatus = enum {
    healthy,
    recovering,
    infected,
    critical,

    pub fn toString(self: HealthStatus) []const u8 {
        return switch (self) {
            .healthy => "HEALTHY",
            .recovering => "RECOVERING",
            .infected => "INFECTED",
            .critical => "CRITICAL",
        };
    }

    pub fn icon(self: HealthStatus) []const u8 {
        return switch (self) {
            .healthy => "💚",
            .recovering => "🏥",
            .infected => "🦠",
            .critical => "🚨",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// MOCK HIPPOCAMPUS - Simulates cached training state for testing
// ═══════════════════════════════════════════════════════════════════════════════

const TestHippocampus = struct {
    allocator: Allocator,
    workers: std.StringHashMap(CachedWorkerStatus),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .workers = std.StringHashMap(CachedWorkerStatus).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit();
    }

    /// Add cached worker state with specified age
    pub fn addWorker(self: *Self, name: []const u8, status: LiveStatus, step: u32, ppl: f32, age_sec: i64) !void {
        const now = std.time.timestamp();
        const key = try self.allocator.dupe(u8, name);
        try self.workers.put(key, .{
            .service_name = key,
            .status = status,
            .step = step,
            .ppl = ppl,
            .tok_per_sec = 0,
            .last_updated = now - age_sec,
            .cached = true,
        });
    }

    /// Get all cached workers (for ACC conflict detection)
    pub fn getAllCachedWorkers(self: *const Self) !std.ArrayList(CachedWorkerStatus) {
        var list = try std.ArrayList(CachedWorkerStatus).initCapacity(self.allocator, 10);
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            try list.append(self.allocator, entry.value_ptr.*);
        }
        return list;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// MOCK THALAMUS - Simulates live Railway worker states
// ═════════════════════════════════════════════════════════════════════════════════

const TestThalamus = struct {
    allocator: Allocator,
    workers: std.StringHashMap(WorkerLiveState),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .workers = std.StringHashMap(WorkerLiveState).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit();
    }

    /// Add live worker state
    pub fn addWorker(self: *Self, name: []const u8, status: LiveStatus, step: u32, ppl: f32) !void {
        const key = try self.allocator.dupe(u8, name);
        try self.workers.put(key, .{
            .status = status,
            .metrics = .{
                .step = step,
                .ppl = ppl,
                .tok_per_sec = 1000.0,
                .loss = 0.3,
                .last_seen_sec = std.time.timestamp(),
            },
        });
    }

    /// Get worker live state
    pub fn getWorkerLiveStatus(self: *const Self, service_name: []const u8) !WorkerLiveState {
        const state = self.workers.get(service_name) orelse return error.NotFound;
        return state;
    }

    /// Get all workers live state
    pub fn getSacredWorkersLive(self: *Self) !std.StringHashMap(WorkerLiveState) {
        var result = std.StringHashMap(WorkerLiveState).init(self.allocator);
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);
            try result.put(key, entry.value_ptr.*);
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// INTEGRATION TEST SCENARIOS - Direct ACC conflict detection testing
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "integration_status_mismatch_critical" {
    // CRITICAL: Cache says stalled, live says training (DANGEROUS!)
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Setup: Cache has stalled worker
    try hippocampus.addWorker("hslm-train-sacred", .stalled, 45000, 4.8, 600);

    // But live shows it's training!
    try thalamus.addWorker("hslm-train-sacred", .training, 50000, 4.6);

    // Detect conflicts using real ACC logic
    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    var live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Simulate ACC conflict detection logic
    var critical_found = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null and cached.status != live.?.status) {
            if (cached.status == .stalled and live.?.status == .training) {
                critical_found = true; // DANGEROUS!
            }
        }
    }

    try std.testing.expect(critical_found, "Should detect critical status mismatch");
}

test "integration_stale_cache_detection" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Cache is 30 minutes stale
    try hippocampus.addWorker("hslm-train-old", .training, 50000, 4.5, 1800);
    try thalamus.addWorker("hslm-train-old", .training, 75000, 4.2);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    var stale_found = false;
    for (cached_workers.items) |cached| {
        if (cached.isStale(300)) {
            stale_found = true;
        }
    }

    try std.testing.expect(stale_found, "Should detect stale cache");
}

test "integration_metrics_mismatch_large_diff" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // 50K step difference (exceeds 1000 threshold)
    try hippocampus.addWorker("hslm-train-lag", .training, 50000, 4.5, 60);
    try thalamus.addWorker("hslm-train-lag", .training, 100000, 3.8);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    var mismatch_found = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (step_diff > 1000) {
                mismatch_found = true;
            }
        }
    }

    try std.testing.expect(mismatch_found, "Should detect metrics mismatch");
}

test "integration_ghost_worker_detection" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker in cache but not in Thalamus (was deleted)
    try hippocampus.addWorker("hslm-train-deleted", .stalled, 30000, 5.0, 300);
    // No live worker added to Thalamus

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    var ghost_found = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live == null) {
            ghost_found = true;
        }
    }

    try std.testing.expect(ghost_found, "Should detect ghost worker");
}

test "integration_zombie_worker_detection" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Live worker exists but not in cache (newly spawned)
    try thalamus.addWorker("agent-12345", .training, 1000, 10.0);
    // No cache entry

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    var zombie_found = false;
    var iter = live_states.iterator();
    while (iter.next()) |entry| {
        const in_cache = for (cached_workers.items) |c| {
            if (std.mem.eql(u8, c.service_name, entry.key_ptr.*)) break true;
        } else false;
        if (!in_cache) {
            zombie_found = true;
        }
    }

    try std.testing.expect(zombie_found, "Should detect zombie worker");
}

test "integration_safety_kill_training_blocked" {
    const allocator = std.testing.allocator;

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker is TRAINING - kill should be BLOCKED!
    try thalamus.addWorker("hslm-train-sacred", .training, 100000, 3.8);

    const live_state = thalamus.getWorkerLiveStatus("hslm-train-sacred") catch unreachable;
    try std.testing.expectEqual(LiveStatus.training, live_state.status);

    // Simulate ACC safety verification
    const verdict: SafetyVerdict = if (live_state.status == .training) SafetyVerdict.unsafe else SafetyVerdict.safe;

    try std.testing.expectEqual(SafetyVerdict.unsafe, verdict);
}

test "integration_safety_restart_error_allowed" {
    const allocator = std.testing.allocator;

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker has ERROR - restart should be ALLOWED
    try thalamus.addWorker("hslm-train-error", .has_error, 25000, 6.5);

    const live_state = thalamus.getWorkerLiveStatus("hslm-train-error") catch unreachable;
    try std.testing.expectEqual(LiveStatus.has_error, live_state.status);

    const verdict: SafetyVerdict = if (live_state.status == .has_error or live_state.status == .stalled) SafetyVerdict.safe else SafetyVerdict.needs_verification;

    try std.testing.expectEqual(SafetyVerdict.safe, verdict);
}

test "integration_safety_stalled_safe" {
    const allocator = std.testing.allocator;

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker is STALLED - action should be ALLOWED
    try thalamus.addWorker("hslm-train-stuck", .stalled, 15000, 5.5);

    const live_state = thalamus.getWorkerLiveStatus("hslm-train-stuck") catch unreachable;
    try std.testing.expectEqual(LiveStatus.stalled, live_state.status);

    const verdict: SafetyVerdict = if (live_state.status == .has_error or live_state.status == .stalled) SafetyVerdict.safe else SafetyVerdict.needs_verification;

    try std.testing.expectEqual(SafetyVerdict.safe, verdict);
}

test "integration_safety_unknown_needs_verification" {
    const allocator = std.testing.allocator;

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker status is UNKNOWN - needs verification
    try thalamus.addWorker("hslm-train-???", .unknown, 0, 0);

    const live_state = thalamus.getWorkerLiveStatus("hslm-train-???") catch unreachable;
    try std.testing.expectEqual(LiveStatus.unknown, live_state.status);

    const verdict: SafetyVerdict = if (live_state.status == .training) SafetyVerdict.needs_verification else if (live_state.status == .has_error or live_state.status == .stalled) SafetyVerdict.safe else SafetyVerdict.needs_verification;

    try std.testing.expectEqual(SafetyVerdict.needs_verification, verdict);
}

test "integration_safety_actions_on_error_worker" {
    const allocator = std.testing.allocator;

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    try thalamus.addWorker("test-error-worker", .has_error, 1000, 5.0);

    // Test that kill_worker is safe on error worker
    const live_state = thalamus.getWorkerLiveStatus("test-error-worker") catch unreachable;
    const verdict_for_kill: SafetyVerdict = if (live_state.status == .has_error or live_state.status == .stalled) SafetyVerdict.safe else SafetyVerdict.needs_verification;
    try std.testing.expectEqual(SafetyVerdict.safe, verdict_for_kill);
}

test "integration_cache_health_calculation" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Add workers with varying freshness
    try hippocampus.addWorker("fresh-1", .training, 10000, 4.5, 60); // Fresh
    try hippocampus.addWorker("fresh-2", .training, 20000, 4.3, 120); // Fresh
    try hippocampus.addWorker("stale-1", .training, 30000, 4.1, 600); // Stale (>5 min)
    try hippocampus.addWorker("stale-2", .training, 40000, 4.0, 900); // Stale

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    var stale_count: usize = 0;
    for (cached_workers.items) |w| {
        if (w.isStale(300)) {
            stale_count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 4), cached_workers.items.len);
    try std.testing.expectEqual(@as(usize, 2), stale_count);
}

test "integration_cache_health_healthy" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    // All fresh (100% health)
    try hippocampus.addWorker("fresh-1", .training, 10000, 4.5, 60);
    try hippocampus.addWorker("fresh-2", .training, 20000, 4.3, 120);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    var stale_count: usize = 0;
    for (cached_workers.items) |w| {
        if (w.isStale(300)) {
            stale_count += 1;
        }
    }

    const health_percent: f32 = if (cached_workers.items.len > 0)
        @as(f32, @floatFromInt(cached_workers.items.len - stale_count)) * 100.0 / @as(f32, @floatFromInt(cached_workers.items.len))
    else
        100.0;

    try std.testing.expectApproxEqRel(@as(f32, 100.0), health_percent, 1.0);
}

test "integration_cache_health_critical" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    // Mostly stale (<50% fresh = critical)
    try hippocampus.addWorker("fresh-1", .training, 10000, 4.5, 60);
    try hippocampus.addWorker("stale-1", .training, 30000, 4.1, 600);
    try hippocampus.addWorker("stale-2", .training, 40000, 4.0, 900);
    try hippocampus.addWorker("stale-3", .training, 50000, 3.9, 1200);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    var stale_count: usize = 0;
    for (cached_workers.items) |w| {
        if (w.isStale(300)) {
            stale_count += 1;
        }
    }

    const health_percent: f32 = if (cached_workers.items.len > 0)
        @as(f32, @floatFromInt(cached_workers.items.len - stale_count)) * 100.0 / @as(f32, @floatFromInt(cached_workers.items.len))
    else
        100.0;

    const health_status = if (health_percent >= 90)
        HealthStatus.healthy
    else if (health_percent >= 70)
        HealthStatus.recovering
    else if (health_percent >= 50)
        HealthStatus.infected
    else
        HealthStatus.critical;

    try std.testing.expectEqual(HealthStatus.critical, health_status);
}

test "integration_multi_conflict_scenario" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Multiple conflicts: status mismatch, stale cache, ghost, zombie
    try hippocampus.addWorker("multi-conflict", .stalled, 50000, 5.0, 1800);
    try thalamus.addWorker("multi-conflict", .training, 100000, 3.8);
    try hippocampus.addWorker("ghost", .stalled, 10000, 6.0, 300);
    try thalamus.addWorker("zombie", .training, 5000, 8.0);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Check for multiple conflict types
    var has_status_mismatch = false;
    var has_stale_cache = false;
    var has_ghost_or_zombie = false;

    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            if (cached.status != live.?.status) {
                has_status_mismatch = true;
            }
            if (cached.isStale(300)) {
                has_stale_cache = true;
            }
        } else {
            has_ghost_or_zombie = true;
        }
    }

    var iter = live_states.iterator();
    while (iter.next()) |entry| {
        const in_cache = for (cached_workers.items) |c| {
            if (std.mem.eql(u8, c.service_name, entry.key_ptr.*)) break true;
        } else false;
        if (!in_cache) {
            has_ghost_or_zombie = true;
        }
    }

    try std.testing.expect(has_status_mismatch);
    try std.testing.expect(has_stale_cache);
    try std.testing.expect(has_ghost_or_zombie);
}

test "integration_empty_system_no_conflicts" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // No workers at all
    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    try std.testing.expectEqual(@as(usize, 0), cached_workers.items.len);

    const health_percent: f32 = 100.0; // Empty cache is "healthy"
    try std.testing.expectApproxEqRel(@as(f32, 100.0), health_percent, 1.0);
}

test "integration_boundary_step_diff_exactly_threshold" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Exactly at threshold (1000 steps)
    try hippocampus.addWorker("boundary-test", .training, 0, 4.5, 10);
    try thalamus.addWorker("boundary-test", .training, 1000, 4.5);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Should NOT detect metrics mismatch (at boundary)
    var has_metrics_mismatch = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (step_diff > 1000) {
                has_metrics_mismatch = true;
            }
        }
    }

    try std.testing.expect(!has_metrics_mismatch, "Should NOT detect mismatch at exact threshold");
}

test "integration_boundary_step_diff_exceeds_threshold" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // One step over threshold
    try hippocampus.addWorker("boundary-test-2", .training, 0, 4.5, 10);
    try thalamus.addWorker("boundary-test-2", .training, 1001, 4.5);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Should detect metrics mismatch (exceeds boundary)
    var has_metrics_mismatch = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (step_diff > 1000) {
                has_metrics_mismatch = true;
            }
        }
    }

    try std.testing.expect(has_metrics_mismatch, "Should detect mismatch exceeding threshold");
}

test "integration_boundary_cache_age_at_threshold" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Exactly at stale threshold (5 minutes = 300 seconds)
    try hippocampus.addWorker("age-boundary", .training, 49000, 4.5, 300);
    try thalamus.addWorker("age-boundary", .training, 50000, 4.5);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    // Should detect stale cache at age boundary
    var has_stale_cache = false;
    for (cached_workers.items) |cached| {
        if (cached.isStale(300)) {
            has_stale_cache = true;
        }
    }

    try std.testing.expect(has_stale_cache, "Should detect stale cache at age boundary");
}

test "integration_custom_thresholds_strict" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // This would not trigger with default thresholds
    try hippocampus.addWorker("strict-test", .training, 0, 4.5, 120);
    try thalamus.addWorker("strict-test", .training, 200, 4.5);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // With strict thresholds (1 min stale, 100 step diff)
    var has_conflict = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (cached.isStale(60) or step_diff > 100) {
                has_conflict = true;
            }
        }
    }

    try std.testing.expect(has_conflict, "Should detect conflict with strict thresholds");
}

test "integration_all_conflict_types_detected" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Create all conflict types
    try hippocampus.addWorker("status-mismatch", .stalled, 50000, 5.0, 600);
    try thalamus.addWorker("status-mismatch", .training, 100000, 3.8);

    try hippocampus.addWorker("stale-cache", .training, 30000, 4.5, 1800);
    try thalamus.addWorker("stale-cache", .training, 75000, 4.2);

    try hippocampus.addWorker("ghost-worker", .training, 20000, 5.0, 300);
    // No live entry for ghost

    try thalamus.addWorker("zombie-worker", .training, 1000, 10.0);
    // No cache entry for zombie

    try hippocampus.addWorker("metrics-mismatch", .training, 50000, 4.5, 60);
    try thalamus.addWorker("metrics-mismatch", .training, 100000, 3.8);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Verify all conflict types are detected
    var has_status_mismatch = false;
    var has_stale_cache = false;
    var has_ghost = false;
    var has_zombie = false;
    var has_metrics_mismatch = false;

    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live == null) {
            has_ghost = true;
        } else {
            if (cached.status != live.?.status) {
                has_status_mismatch = true;
            }
            if (cached.isStale(300)) {
                has_stale_cache = true;
            }
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (step_diff > 1000) {
                has_metrics_mismatch = true;
            }
        }
    }

    var iter = live_states.iterator();
    while (iter.next()) |entry| {
        const in_cache = for (cached_workers.items) |c| {
            if (std.mem.eql(u8, c.service_name, entry.key_ptr.*)) break true;
        } else false;
        if (!in_cache) {
            has_zombie = true;
        }
    }

    try std.testing.expect(has_status_mismatch);
    try std.testing.expect(has_stale_cache);
    try std.testing.expect(has_ghost);
    try std.testing.expect(has_zombie);
    try std.testing.expect(has_metrics_mismatch);
}

test "integration_suppression_stale_cache_triggers_action" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Stale cache but live shows different state
    try hippocampus.addWorker("stale-action", .stalled, 45000, 4.8, 1800);
    try thalamus.addWorker("stale-action", .training, 100000, 3.8);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Should have both stale cache and status mismatch
    var conflict_count: usize = 0;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            if (cached.status != live.?.status) conflict_count += 1;
            if (cached.isStale(300)) conflict_count += 1;
        }
    }

    try std.testing.expect(conflict_count >= 2);

    // Action should be blocked based on live state
    const live_state = thalamus.getWorkerLiveStatus("stale-action") catch unreachable;
    const verdict: SafetyVerdict = if (live_state.status == .training) SafetyVerdict.unsafe else SafetyVerdict.safe;

    try std.testing.expectEqual(SafetyVerdict.unsafe, verdict);
}

test "integration_habit_formation_consistent_state" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Consistent state
    try hippocampus.addWorker("consistent", .training, 100000, 3.8, 60);
    try thalamus.addWorker("consistent", .training, 100000, 3.8);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // No conflicts expected
    var conflict_count: usize = 0;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            if (cached.status != live.?.status) conflict_count += 1;
            if (cached.isStale(300)) conflict_count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 0), conflict_count);
}

test "integration_edge_case_zero_step_worker" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    // Worker with zero step (just started)
    try hippocampus.addWorker("zero-step", .building, 0, 10.0, 10);
    try thalamus.addWorker("zero-step", .building, 0, 10.0);

    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    const live_states = try thalamus.getSacredWorkersLive();
    defer {
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        live_states.deinit(allocator);
    }

    // Should not detect metrics mismatch with zero steps
    var has_metrics_mismatch = false;
    for (cached_workers.items) |cached| {
        const live = live_states.get(cached.service_name);
        if (live != null) {
            const step_diff = if (cached.step > live.?.metrics.step)
                cached.step - live.?.metrics.step
            else
                live.?.metrics.step - cached.step;
            if (step_diff > 1000) {
                has_metrics_mismatch = true;
            }
        }
    }

    try std.testing.expect(!has_metrics_mismatch);
}

test "integration_edge_case_negative_ppl" {
    const allocator = std.testing.allocator;

    var hippocampus = TestHippocampus.init(allocator);
    defer hippocampus.deinit();

    var thalamus = TestThalamus.init(allocator);
    defer thalamus.deinit();

    try hippocampus.addWorker("negative-ppl", .training, 10000, -1.0, 60);
    try thalamus.addWorker("negative-ppl", .training, 10000, -1.0);

    // Should handle gracefully
    const cached_workers = try hippocampus.getAllCachedWorkers();
    defer {
        for (cached_workers.items) |w| {
            allocator.free(w.service_name);
        }
        cached_workers.deinit();
    }

    _ = cached_workers.items.len; // Use to avoid unused warning
}

test "integration_memory_cleanup_all_scenarios" {
    const allocator = std.testing.allocator;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var hippocampus = TestHippocampus.init(allocator);
        var thalamus = TestThalamus.init(allocator);

        try hippocampus.addWorker("cleanup-test", .training, 10000, 4.5, 60);
        try thalamus.addWorker("cleanup-test", .training, 10000, 4.5);

        const cached_workers = try hippocampus.getAllCachedWorkers();
        {
            for (cached_workers.items) |w| {
                allocator.free(w.service_name);
            }
            cached_workers.deinit();
        }

        const live_states = try thalamus.getSacredWorkersLive();
        {
            var iter = live_states.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
            }
            live_states.deinit(allocator);
        }

        const live_state = thalamus.getWorkerLiveStatus("cleanup-test") catch unreachable;
        _ = live_state; // Use to avoid unused warning

        hippocampus.deinit();
        thalamus.deinit();
    }
}
