// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// ACC (Anterior Cingulate Cortex) — Conflict & Anomaly Detection
// ═════════════════════════════════════════════════════════════════════════════
//
// PROBLEM: Conflicts between cache (Hippocampus) and live truth (Thalamus)
// SOLUTION: ACC as watchdog detecting mismatches and blocking dangerous actions
//
// ACC detects conflicts between cached state and live reality.
// Blocks dangerous operations (kill sacred worker) when conflict detected.
//
// NEUROANATOMY: ACC = Anterior cingulate cortex, conflict monitoring
//     Error detection, conflict resolution, cognitive control. Here: cache/live mismatch detection.
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const thalamus_logs = @import("thalamus_logs.zig");
const LiveStatus = thalamus_logs.LiveStatus;
const hippocampus_training = @import("hippocampus_training.zig");
const CachedWorkerStatus = hippocampus_training.CachedWorkerStatus;
const insula_system = @import("insula_system.zig");
const SystemEvent = insula_system.SystemEvent;
const EventType = insula_system.EventType;
const LogLevel = insula_system.LogLevel;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═════════════════════════════════════════════════════════════════════════════

pub const ConflictType = enum {
    stale_cache, // evolution_state.json outdated (cache age > threshold)
    ghost_worker, // cached service doesn't exist in Thalamus
    zombie_worker, // live service not in Hippocampus cache
    status_mismatch, // cached says stalled, live says training
    metrics_mismatch, // step/PPL differ significantly between cache and live
    missing_metadata, // worker in cache but missing critical data

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

    pub fn description(self: ConflictType) []const u8 {
        return switch (self) {
            .stale_cache => "Cache is stale (outdated by >threshold seconds)",
            .ghost_worker => "Worker in cache but not found in live Thalamus",
            .zombie_worker => "Worker live but not in Hippocampus cache",
            .status_mismatch => "Cache status != live status",
            .metrics_mismatch => "Step/PPL differ significantly",
            .missing_metadata => "Critical data missing from cache",
        };
    }
};

pub const Severity = enum {
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

    pub fn icon(self: Severity) []const u8 {
        return switch (self) {
            .info => "ℹ️",
            .warning => "⚠️",
            .critical => "🚨",
        };
    }
};

pub const Conflict = struct {
    service_name: []const u8,
    conflict_type: ConflictType,
    cached_status: ?LiveStatus,
    live_status: LiveStatus,
    cached_step: u32,
    live_step: u32,
    severity: Severity,
    age_seconds: i64, // Cache age at time of detection
    message: []const u8,

    const Self = @This();

    /// Create conflict from mismatch detection
    pub fn create(
        allocator: Allocator,
        service_name: []const u8,
        conflict_type: ConflictType,
        cached_status: ?LiveStatus,
        live_status: LiveStatus,
        cached_step: u32,
        live_step: u32,
        severity: Severity,
    ) !Conflict {
        return .{
            .service_name = try allocator.dupe(u8, service_name),
            .conflict_type = conflict_type,
            .cached_status = cached_status,
            .live_status = live_status,
            .cached_step = cached_step,
            .live_step = live_step,
            .severity = severity,
            .age_seconds = 0,
            .message = try buildMessage(allocator, service_name, conflict_type, cached_step, live_step),
        };
    }

    /// Build human-readable conflict message
    fn buildMessage(allocator: Allocator, service_name: []const u8, conflict_type: ConflictType, cached_step: u32, live_step: u32) ![]const u8 {
        return switch (conflict_type) {
            .stale_cache => try std.fmt.allocPrint(allocator, "{s}: Cache is stale for {s}", .{ service_name, service_name }),
            .ghost_worker => try std.fmt.allocPrint(allocator, "{s}: In cache but not found live", .{service_name}),
            .zombie_worker => try std.fmt.allocPrint(allocator, "{s}: Live but not in cache", .{service_name}),
            .status_mismatch => try std.fmt.allocPrint(allocator, "{s}: Status mismatch (cache={any}, live={d})", .{
                service_name,
                if (cached_step > 0) "any" else "null",
                live_step,
            }),
            .metrics_mismatch => try std.fmt.allocPrint(allocator, "{s}: Step mismatch (cache={d}, live={d})", .{ service_name, cached_step, live_step }),
            .missing_metadata => try std.fmt.allocPrint(allocator, "{s}: Missing critical metadata", .{service_name}),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.service_name);
        allocator.free(self.message);
    }
};

pub const Action = enum {
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

pub const SafetyVerdict = enum {
    safe, // Action allowed (no conflicts or acceptable risk)
    unsafe, // Action blocked (would kill training worker!)
    needs_verification, // Check live status before proceeding

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

pub const VerificationResult = struct {
    verdict: SafetyVerdict,
    conflicts: []Conflict,
    reason: []const u8,
};

// ═════════════════════════════════════════════════════════════════════════════
// ACC API — Conflict Detection & Safety Verification
// ═════════════════════════════════════════════════════════════════════════════

pub const ACC = struct {
    allocator: Allocator,
    max_cache_age_sec: i64 = 300, // 5 minutes = stale cache threshold
    max_step_diff: u32 = 1000, // Max acceptable step difference
    insula: ?*insula_system.Insula = null, // Optional: log conflicts to Insula

    const Self = @This();

    /// Initialize ACC with configurable thresholds
    pub fn init(allocator: Allocator, max_cache_age_sec: i64, max_step_diff: u32) Self {
        return .{
            .allocator = allocator,
            .max_cache_age_sec = max_cache_age_sec,
            .max_step_diff = max_step_diff,
        };
    }

    /// Initialize with default thresholds (5 min stale, 1000 step diff)
    pub fn initDefault(allocator: Allocator) Self {
        return init(allocator, 300, 1000);
    }

    /// Set Insula reference for conflict logging
    pub fn setInsula(self: *Self, insula: *insula_system.Insula) void {
        self.insula = insula;
    }

    /// Check if cached state matches live reality
    pub fn detectConflicts(
        self: *Self,
        allocator: Allocator,
        hippocampus: *const hippocampus_training.Hippocampus,
        thalamus: *const thalamus_logs.Thalamus,
    ) !std.ArrayList(Conflict) {
        var conflicts = std.ArrayList(Conflict).init(allocator);

        // Get all sacred workers from Hippocampus
        const cached_workers = try hippocampus.getAllCachedWorkers();
        defer {
            for (cached_workers.items) |w| {
                allocator.free(w.service_name);
            }
            cached_workers.deinit();
        }

        // Get live states from Thalamus
        var live_states = try thalamus.getSacredWorkersLive();
        defer {
            var iter = live_states.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
            }
            live_states.deinit(allocator);
        }

        // Check for ghosts (in cache but not live)
        for (cached_workers.items) |cached| {
            const live = live_states.get(cached.service_name);
            if (live == null) {
                // Ghost worker
                const conflict = try Conflict.create(
                    allocator,
                    cached.service_name,
                    .ghost_worker,
                    cached.status,
                    .not_found,
                    cached.step,
                    0,
                    .warning,
                );
                conflict.age_seconds = cached.ageSec();
                try conflicts.append(allocator, conflict);
            } else {
                // Check for status mismatch
                if (cached.status != live.?.status) {
                    const severity = if (cached.status == .stalled and live.?.status == .training)
                        .critical // Cache says stalled, live says training = DANGEROUS!
                    else
                        .warning;

                    const conflict = try Conflict.create(
                        allocator,
                        cached.service_name,
                        .status_mismatch,
                        cached.status,
                        live.?.status,
                        cached.step,
                        live.?.metrics.step,
                        severity,
                    );
                    conflict.age_seconds = cached.ageSec();
                    try conflicts.append(allocator, conflict);
                }

                // Check for metrics mismatch
                const step_diff = if (cached.step > live.?.metrics.step)
                    cached.step - live.?.metrics.step
                else
                    live.?.metrics.step - cached.step;
                if (step_diff > self.max_step_diff) {
                    const conflict = try Conflict.create(
                        allocator,
                        cached.service_name,
                        .metrics_mismatch,
                        cached.status,
                        live.?.status,
                        cached.step,
                        live.?.metrics.step,
                        .warning,
                    );
                    conflict.age_seconds = cached.ageSec();
                    try conflicts.append(allocator, conflict);
                }
            }

            // Check for stale cache
            if (cached.isStale(self.max_cache_age_sec)) {
                const conflict = try Conflict.create(
                    allocator,
                    cached.service_name,
                    .stale_cache,
                    cached.status,
                    if (live) |l| l.status else .not_found,
                    cached.step,
                    if (live) |l| l.metrics.step else 0,
                    if (cached.isStale(self.max_cache_age_sec * 2)) .critical else .warning,
                );
                conflict.age_seconds = cached.ageSec();
                try conflicts.append(allocator, conflict);
            }
        }

        // Check for zombies (live but not in cache)
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            const live_state = entry.value_ptr.*;
            const in_cache = for (cached_workers.items) |c| {
                if (std.mem.eql(u8, c.service_name, entry.key_ptr.*)) break true;
            } else false;

            if (!in_cache) {
                const conflict = try Conflict.create(
                    allocator,
                    entry.key_ptr.*,
                    .zombie_worker,
                    null,
                    live_state.status,
                    0,
                    live_state.metrics.step,
                    .info,
                );
                try conflicts.append(allocator, conflict);
            }
        }

        return conflicts;
    }

    /// Verify worker is safe to action upon (before kill/restart)
    pub fn verifySafeToAction(
        allocator: Allocator,
        service_name: []const u8,
        action: Action,
        thalamus: *const thalamus_logs.Thalamus,
    ) !VerificationResult {
        var conflicts = std.ArrayList(Conflict).init(allocator);
        defer {
            for (conflicts.items) |c| {
                c.deinit(allocator);
            }
            conflicts.deinit();
        }

        // Get live state from Thalamus (source of truth!)
        const live_state = thalamus.getWorkerLiveStatus(service_name) catch |err| {
            // Error getting live state - needs verification
            const reason = try std.fmt.allocPrint(
                allocator,
                "Cannot verify {s}: Thalamus error: {any}",
                .{ service_name, err },
            );
            return .{
                .verdict = .needs_verification,
                .conflicts = &.{},
                .reason = reason,
            };
        };

        // DANGEROUS: Check if worker is actually training (not stalled!)
        if (live_state.status == .training) {
            const verdict: SafetyVerdict = switch (action) {
                .kill_worker => .unsafe, // NEVER kill training worker!
                .restart_worker => .needs_verification, // Restart only if confirmed
                .inject_config => .needs_verification, // Inject only if safe
                else => .safe,
            };

            const reason = try std.fmt.allocPrint(
                allocator,
                "Worker {s} is TRAINING (step={d}). Action '{s}' {s}",
                .{ service_name, live_state.metrics.step, action.toString(), verdict.toString() },
            );

            return .{
                .verdict = verdict,
                .conflicts = &.{},
                .reason = reason,
            };
        }

        // Safe: worker has error or is stalled
        if (live_state.status == .has_error or live_state.status == .stalled) {
            const reason = try std.fmt.allocPrint(
                allocator,
                "Worker {s} status: {s}. Action '{s}' allowed",
                .{ service_name, live_state.status.toString(), action.toString() },
            );

            return .{
                .verdict = .safe,
                .conflicts = &.{},
                .reason = reason,
            };
        }

        // Unknown status - needs verification
        const reason = try std.fmt.allocPrint(
            allocator,
            "Worker {s} status: {s}. Action '{s}' needs verification",
            .{ service_name, live_state.status.toString(), action.toString() },
        );

        return .{
            .verdict = .needs_verification,
            .conflicts = &.{},
            .reason = reason,
        };
    }

    /// Check cache health metrics
    pub fn checkCacheHealth(
        self: *Self,
        allocator: Allocator,
        hippocampus: *const hippocampus_training.Hippocampus,
    ) !CacheHealth {
        const cache_age = hippocampus.getCacheAge();
        const workers = try hippocampus.getAllCachedWorkers();
        defer {
            for (workers.items) |w| {
                allocator.free(w.service_name);
            }
            workers.deinit();
        }

        var stale_count: usize = 0;
        for (workers.items) |w| {
            if (w.isStale(self.max_cache_age_sec)) {
                stale_count += 1;
            }
        }

        const health_percent: f32 = if (workers.items.len > 0)
            @as(f32, @floatFromInt(workers.items.len - stale_count)) * 100.0 / @as(f32, @floatFromInt(workers.items.len))
        else
            100.0;

        const health = if (health_percent >= 90)
            .healthy
        else if (health_percent >= 70)
            .recovering
        else if (health_percent >= 50)
            .infected
        else
            .critical;

        return .{
            .cache_age_seconds = cache_age,
            .total_workers = workers.items.len,
            .stale_workers = stale_count,
            .health_percent = health_percent,
            .health_status = health,
        };
    }
};

pub const CacheHealth = struct {
    cache_age_seconds: i64,
    total_workers: usize,
    stale_workers: usize,
    health_percent: f32,
    health_status: HealthStatus,
};

pub const HealthStatus = enum {
    healthy, // 90%+ fresh
    recovering, // 70-89% fresh
    infected, // 50-69% fresh
    critical, // <50% fresh

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

// ═══════════════════════════════════════════════════════════════════════════════
// LOGGING HELPERS
// ═══════════════════════════════════════════════════════════════════════════

fn logConflict(self: *ACC, conflict: *const Conflict, insula: *insula_system.Insula) !void {
    if (self.insula == null) return;

    const level = switch (conflict.severity) {
        .critical => .critical,
        .warning => .warn,
        .info => .info,
    };

    const event = try SystemEvent.create(
        self.allocator,
        level,
        "acc",
        .conflict_detected,
        conflict.message,
    );
    defer event.deinit(self.allocator);

    try insula.logEvent(&event);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACC TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "acc_conflict_type_toString" {
    try std.testing.expectEqualStrings("stale_cache", ConflictType.stale_cache.toString());
    try std.testing.expectEqualStrings("ghost_worker", ConflictType.ghost_worker.toString());
    try std.testing.expectEqualStrings("zombie_worker", ConflictType.zombie_worker.toString());
    try std.testing.expectEqualStrings("status_mismatch", ConflictType.status_mismatch.toString());
    try std.testing.expectEqualStrings("metrics_mismatch", ConflictType.metrics_mismatch.toString());
    try std.testing.expectEqualStrings("missing_metadata", ConflictType.missing_metadata.toString());
}

test "acc_conflict_type_description" {
    const desc = ConflictType.stale_cache.description();
    try std.testing.expect(std.mem.indexOf(u8, desc, "stale") != null);

    const desc2 = ConflictType.ghost_worker.description();
    try std.testing.expect(std.mem.indexOf(u8, desc2, "not found") != null);
}

test "acc_severity_enum" {
    try std.testing.expectEqualStrings("INFO", Severity.info.toString());
    try std.testing.expectEqualStrings("WARNING", Severity.warning.toString());
    try std.testing.expectEqualStrings("CRITICAL", Severity.critical.toString());

    try std.testing.expectEqualStrings("ℹ️", Severity.info.icon());
    try std.testing.expectEqualStrings("⚠️", Severity.warning.icon());
    try std.testing.expectEqualStrings("🚨", Severity.critical.icon());
}

test "acc_action_toString" {
    try std.testing.expectEqualStrings("kill", Action.kill_worker.toString());
    try std.testing.expectEqualStrings("restart", Action.restart_worker.toString());
    try std.testing.expectEqualStrings("evolve", Action.evolve_step.toString());
    try std.testing.expectEqualStrings("inject", Action.inject_config.toString());
    try std.testing.expectEqualStrings("enable_night", Action.enable_night_mode.toString());
    try std.testing.expectEqualStrings("disable_night", Action.disable_night_mode.toString());
}

test "acc_safety_verdict_enum" {
    try std.testing.expectEqualStrings("SAFE", SafetyVerdict.safe.toString());
    try std.testing.expectEqualStrings("UNSAFE - BLOCKED", SafetyVerdict.unsafe.toString());
    try std.testing.expectEqualStrings("NEEDS LIVE VERIFICATION", SafetyVerdict.needs_verification.toString());

    try std.testing.expectEqualStrings("✅", SafetyVerdict.safe.icon());
    try std.testing.expectEqualStrings("🚫", SafetyVerdict.unsafe.icon());
    try std.testing.expectEqualStrings("⏳", SafetyVerdict.needs_verification.icon());
}

test "acc_conflict_create_stale_cache" {
    const allocator = std.testing.allocator;
    const conflict = try Conflict.create(
        allocator,
        "test-worker",
        .stale_cache,
        .training,
        .training,
        1000,
        2000,
        .warning,
    );
    defer conflict.deinit(allocator);

    try std.testing.expectEqualStrings("test-worker", conflict.service_name);
    try std.testing.expectEqual(ConflictType.stale_cache, conflict.conflict_type);
    try std.testing.expectEqual(@as(u32, 1000), conflict.cached_step);
    try std.testing.expectEqual(@as(u32, 2000), conflict.live_step);
    try std.testing.expectEqual(Severity.warning, conflict.severity);
    try std.testing.expect(std.mem.indexOf(u8, conflict.message, "stale") != null);
}

test "acc_conflict_create_ghost_worker" {
    const allocator = std.testing.allocator;
    const conflict = try Conflict.create(
        allocator,
        "ghost-worker",
        .ghost_worker,
        .training,
        .unknown,
        500,
        0,
        .critical,
    );
    defer conflict.deinit(allocator);

    try std.testing.expectEqual(ConflictType.ghost_worker, conflict.conflict_type);
    try std.testing.expect(std.mem.indexOf(u8, conflict.message, "not found") != null);
}

test "acc_conflict_create_zombie_worker" {
    const allocator = std.testing.allocator;
    const conflict = try Conflict.create(
        allocator,
        "zombie-worker",
        .zombie_worker,
        null,
        .training,
        0,
        100,
        .info,
    );
    defer conflict.deinit(allocator);

    try std.testing.expectEqual(ConflictType.zombie_worker, conflict.conflict_type);
    try std.testing.expect(conflict.cached_status == null);
}

test "acc_conflict_create_metrics_mismatch" {
    const allocator = std.testing.allocator;
    const conflict = try Conflict.create(
        allocator,
        "metrics-worker",
        .metrics_mismatch,
        .training,
        .training,
        5000,
        7000,
        .warning,
    );
    defer conflict.deinit(allocator);

    try std.testing.expectEqual(ConflictType.metrics_mismatch, conflict.conflict_type);
    try std.testing.expect(std.mem.indexOf(u8, conflict.message, "Step mismatch") != null);
    try std.testing.expect(std.mem.indexOf(u8, conflict.message, "5000") != null);
    try std.testing.expect(std.mem.indexOf(u8, conflict.message, "7000") != null);
}

test "acc_init_default" {
    const allocator = std.testing.allocator;
    const acc = ACC.initDefault(allocator);

    try std.testing.expectEqual(@as(i64, 300), acc.max_cache_age_sec);
    try std.testing.expectEqual(@as(u32, 1000), acc.max_step_diff);
    try std.testing.expect(acc.insula == null);
}

test "acc_init_custom_thresholds" {
    const allocator = std.testing.allocator;
    const acc = ACC.init(allocator, 600, 2000);

    try std.testing.expectEqual(@as(i64, 600), acc.max_cache_age_sec);
    try std.testing.expectEqual(@as(u32, 2000), acc.max_step_diff);
}

test "acc_conflict_deinit" {
    const allocator = std.testing.allocator;
    var conflict = try Conflict.create(
        allocator,
        "deinit-test",
        .stale_cache,
        .training,
        .training,
        100,
        200,
        .info,
    );

    // Store pointers to verify they're valid before deinit
    const service_ptr = conflict.service_name.ptr;
    const message_ptr = conflict.message.ptr;

    conflict.deinit(allocator);

    // After deinit, memory is freed - can't access but should not crash
    _ = service_ptr;
    _ = message_ptr;
}

test "acc_all_conflict_types_covered" {
    // Ensure all conflict types are testable
    const allocator = std.testing.allocator;

    const conflict_types = [_]ConflictType{
        .stale_cache,
        .ghost_worker,
        .zombie_worker,
        .status_mismatch,
        .metrics_mismatch,
        .missing_metadata,
    };

    for (conflict_types) |ct| {
        const desc = ct.description();
        try std.testing.expect(desc.len > 0);

        const str = ct.toString();
        try std.testing.expect(str.len > 0);
    }

    // Test creating conflicts for each type
    const conflict = try Conflict.create(
        allocator,
        "all-types-test",
        .missing_metadata,
        null,
        .unknown,
        0,
        0,
        .critical,
    );
    defer conflict.deinit(allocator);

    try std.testing.expectEqual(ConflictType.missing_metadata, conflict.conflict_type);
}

pub fn copyToFixed(comptime N: usize, dest: *[N]u8, len_ptr: anytype, src: []const u8) void {
    const copy_len = @min(src.len, N);
    @memcpy(dest[0..copy_len], src[0..copy_len]);
    len_ptr.* = @intCast(copy_len);
}
