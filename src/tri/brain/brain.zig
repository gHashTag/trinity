// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN — S³AI Root Module
// ═══════════════════════════════════════════════════════════════════════════════
//
// S³AI Neuroanatomy Implementation:
//   - Thalamus: Sensory relay (source of live truth from Railway logs)
//   - Hippocampus: Episodic memory (training state cache)
//   - Insula: Interoception (system event logging)
//   - ACC: Anterior cingulate (conflict detection & safety)
//
// Each brain region has distinct responsibility and boundaries.
// All modules must go through brain.zig to access brain regions.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Brain regions
pub const Thalamus = @import("thalamus_logs.zig").Thalamus;
pub const Hippocampus = @import("hippocampus_training.zig").Hippocampus;
pub const Insula = @import("insula_system.zig").Insula;
pub const ACC = @import("anterior_cingulate.zig").ACC;

// Re-export commonly used types
pub const LiveStatus = @import("thalamus_logs.zig").LiveStatus;
pub const WorkerLiveState = @import("thalamus_logs.zig").WorkerLiveState;
pub const WorkerMetrics = @import("thalamus_logs.zig").WorkerMetrics;
pub const CachedWorkerStatus = @import("hippocampus_training.zig").CachedWorkerStatus;
pub const Conflict = @import("anterior_cingulate.zig").Conflict;
pub const SafetyVerdict = @import("anterior_cingulate.zig").SafetyVerdict;
pub const SystemEvent = @import("insula_system.zig").SystemEvent;
pub const LogLevel = @import("insula_system.zig").LogLevel;
pub const EventType = @import("insula_system.zig").EventType;

// ═════════════════════════════════════════════════════════════════════════════════════════
// BRAIN AGGREGATE — Unified Brain Context
// ═════════════════════════════════════════════════════════════════════════════════════════

pub const Brain = struct {
    allocator: Allocator,
    thalamus: Thalamus,
    hippocampus: Hippocampus,
    insula: Insula,
    acc: ACC,

    const Self = @This();

    /// Initialize complete brain with all regions
    pub fn init(allocator: Allocator, railway_suffix: []const u8) !Self {
        // Initialize regions
        var thalamus = try Thalamus.init(allocator, railway_suffix);
        errdefer thalamus.deinit();

        var hippocampus = try Hippocampus.init(allocator);
        errdefer hippocampus.deinit(allocator);

        var insula = Insula.init(allocator);

        var acc = ACC.initDefault(allocator);
        acc.setInsula(&insula);

        return .{
            .allocator = allocator,
            .thalamus = thalamus,
            .hippocampus = hippocampus,
            .insula = insula,
            .acc = acc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.thalamus.deinit();
        self.hippocampus.deinit(self.allocator);
    }

    /// Refresh brain state: update Hippocampus from Thalamus
    pub fn refresh(self: *Self) !void {
        try self.hippocampus.refreshFromThalamus(&self.thalamus);

        // Log refresh event to Insula
        const event = try SystemEvent.create(
            self.allocator,
            .info,
            "brain",
            .state_change,
            "Brain refreshed: Hippocampus updated from Thalamus",
        );
        defer event.deinit(self.allocator);
        try self.insula.logEvent(&event);
    }

    /// Get live worker status (source: Thalamus)
    pub fn getWorkerLive(self: *Self, service_name: []const u8) !WorkerLiveState {
        return self.thalamus.getWorkerLiveStatus(service_name);
    }

    /// Get cached worker status (source: Hippocampus, may be stale)
    pub fn getWorkerCached(self: *const Self, service_name: []const u8) ?CachedWorkerStatus {
        return self.hippocampus.getCachedStatus(service_name);
    }

    /// Detect conflicts between cache and live truth
    pub fn detectConflicts(self: *Self) !std.ArrayList(Conflict) {
        return self.acc.detectConflicts(self.allocator, &self.hippocampus, &self.thalamus);
    }

    /// Verify action is safe before executing (ACC safety check)
    pub fn verifySafe(
        self: *Self,
        service_name: []const u8,
        action: @import("anterior_cingulate.zig").Action,
    ) !@import("anterior_cingulate.zig").VerificationResult {
        return self.acc.verifySafeToAction(
            self.allocator,
            service_name,
            action,
            &self.thalamus,
        );
    }

    /// Log a decision to Insula
    pub fn logDecision(
        self: *Self,
        level: LogLevel,
        component: []const u8,
        message: []const u8,
    ) !void {
        const event = try SystemEvent.create(
            self.allocator,
            level,
            component,
            .decision_made,
            message,
        );
        defer event.deinit(self.allocator);
        try self.insula.logEvent(&event);
    }

    /// Log an error to Insula
    pub fn logError(
        self: *Self,
        component: []const u8,
        message: []const u8,
    ) !void {
        const event = try SystemEvent.create(
            self.allocator,
            .warn, // Temporarily use .warn to test
            component,
            .error_occurred,
            message,
        );
        defer event.deinit(self.allocator);
        try self.insula.logEvent(&event);
    }

    /// Log a conflict to Insula
    pub fn logConflict(self: *Self, conflict: *const Conflict) !void {
        const event = try SystemEvent.create(
            self.allocator,
            if (conflict.severity == .critical) .critical else .warn,
            "acc",
            .conflict_detected,
            conflict.message,
        );
        defer event.deinit(self.allocator);
        try self.insula.logEvent(&event);
    }

    /// Get recent system events from Insula
    pub fn getRecentEvents(self: *Self, limit: usize) !std.ArrayList(SystemEvent) {
        return self.insula.getRecentEvents(limit);
    }

    /// Get cache health status
    pub fn getCacheHealth(self: *Self) !@import("anterior_cingulate.zig").CacheHealth {
        return self.acc.checkCacheHealth(self.allocator, &self.hippocampus);
    }

    /// Get brain summary (all regions status)
    pub fn getSummary(self: *Self) !BrainSummary {
        const cache_age = self.hippocampus.getCacheAge();
        const cache_health = try self.acc.checkCacheHealth(self.allocator, &self.hippocampus);
        const conflicts = try self.acc.detectConflicts(self.allocator, &self.hippocampus, &self.thalamus);
        defer {
            for (conflicts.items) |c| {
                c.deinit(self.allocator);
            }
            conflicts.deinit();
        }

        return .{
            .cache_age_seconds = cache_age,
            .cache_health_percent = cache_health.health_percent,
            .total_cached_workers = cache_health.total_workers,
            .stale_cached_workers = cache_health.stale_workers,
            .active_conflicts = conflicts.items.len,
            .brain_status = if (cache_health.health_percent >= 90 and conflicts.items.len == 0)
                .healthy
            else if (cache_health.health_percent >= 70)
                .recovering
            else if (conflicts.items.len > 0)
                .conflicted
            else
                .critical,
        };
    }
};

pub const BrainSummary = struct {
    cache_age_seconds: i64,
    cache_health_percent: f32,
    total_cached_workers: usize,
    stale_cached_workers: usize,
    active_conflicts: usize,
    brain_status: BrainStatus,
};

pub const BrainStatus = enum {
    healthy,       // Cache fresh, no conflicts
    recovering,    // Cache aging, minor conflicts
    conflicted,   // Significant conflicts between cache and live
    critical,      // Cache stale, many conflicts

    pub fn toString(self: BrainStatus) []const u8 {
        return switch (self) {
            .healthy => "HEALTHY",
            .recovering => "RECOVERING",
            .conflicted => "CONFLICTED",
            .critical => "CRITICAL",
        };
    }

    pub fn icon(self: BrainStatus) []const u8 {
        return switch (self) {
            .healthy => "🧠",
            .recovering => "🏥",
            .conflicted => "⚔",
            .critical => "🚨",
        };
    }
};

test "brain_init" {
    const allocator = std.testing.allocator;
    const brain = try Brain.init(allocator, "");
    defer brain.deinit();

    // Should initialize all regions
}

test "brain_refresh" {
    const allocator = std.testing.allocator;
    const brain = try Brain.init(allocator, "");
    defer brain.deinit();

    // Refresh should update cache from Thalamus
    // (In real test, would have mock Thalamus)
}
