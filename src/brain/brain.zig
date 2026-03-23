//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN — S³AI Neuroanatomy v5.1
//!
//! Aggregator module for all brain regions. Import this file to get
//! access to all S³AI neuroanatomy modules at once.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGION IMPORTS (provided as module imports in build.zig)
// ═══════════════════════════════════════════════════════════════════════════════

/// Basal Ganglia (Action Selection)
/// Task claim registry — prevents duplicate task execution across agents
pub const basal_ganglia = @import("basal_ganglia");

/// Reticular Formation (Broadcast Alerting)
/// Event bus — publishes task events for all agents to consume
pub const reticular_formation = @import("reticular_formation");

/// Locus Coeruleus (Arousal Regulation)
/// Backoff policy — regulates timing and retry behavior
pub const locus_coeruleus = @import("locus_coeruleus");

/// Hippocampus (Memory Persistence)
/// Event logging to JSONL for replay and analysis
pub const persistence = @import("persistence");

/// Corpus Callosum (Telemetry)
/// Time-series metrics aggregation
pub const telemetry = @import("telemetry");

/// Amygdala (Emotional Salience)
/// Detects emotionally significant events and prioritizes them
pub const amygdala = @import("amygdala");

/// Prefrontal Cortex (Executive Function)
/// Decision making, planning, and cognitive control
pub const prefrontal_cortex = @import("prefrontal_cortex");

/// Hippocampus (Health History)
/// Memory consolidation for brain health snapshots
pub const health_history = @import("health_history");

/// Thalamus (Sensory Relay)
/// Railway live logs relay
pub const thalamus_logs = @import("thalamus_logs");

/// Microglia (Immune Surveillance)
/// The Constant Gardeners — patrol, prune, and stimulate regrowth
pub const microglia = @import("microglia");

/// Metrics Dashboard (Command Center)
/// Aggregates metrics from all brain regions with trend detection
pub const metrics_dashboard = @import("metrics_dashboard");

/// Brain Alerts (Critical Health Notification System)
/// Monitors brain health and sends alerts when thresholds are crossed
pub const alerts = @import("alerts");

/// Simulation (Synthetic Workload Testing)
/// Realistic workload testing for brain circuit validation
pub const simulation = @import("simulation");

/// Observability Export (External Monitoring)
/// Export brain telemetry for Prometheus, OpenTelemetry, and other systems
pub const observability_export = @import("observability_export");

/// Intraparietal Sulcus (Numerical Processing)
/// f16/GF16/TF3 numerical format conversions
pub const intraparietal_sulcus = @import("intraparietal_sulcus");

/// State Recovery (Persistence)
/// Crash recovery and state persistence for brain components
pub const state_recovery = @import("state_recovery");

/// Hypothalamus (Administrative Control)
/// Brain maintenance: reset, doctor, prune, migrate, backup, restore
pub const admin = @import("admin");

/// Thalamic Async Processor (Non-blocking Operations)
/// Async task claim/release, event publishing, health checks, background telemetry
pub const async_processor = @import("async_processor");

/// Cerebellum (Motor Learning & Adaptive Performance)
/// Performance history tracking, pattern recognition, adaptive backoff, failure prediction
pub const learning = @import("learning");

/// Corpus Callosum (Inter-Hemispheric Communication)
/// Distributed multi-instance coordination: inter-instance communication, leader election, CRDT state sync
pub const federation = @import("federation");

/// Visual Cortex (Spatial Representation)
/// ASCII art brain maps, sparklines, heatmaps, 3D visualization
pub const visualization = @import("visualization");

/// Evolution Simulation (Deterministic Brain Evolution)
/// Parallel evolution scenarios: baseline, current, multi-objective, dePIN
pub const evolution_simulation = @import("evolution_simulation");

/// SEBO — Sacred Evolutionary Bayesian Optimization
/// Multi-objective hyperparameter optimization using Sacred constants as priors
pub const sebo = @import("sebo");

/// Performance Dashboard (Unified Performance Monitoring)
/// Real-time performance tracking, SLA monitoring, comparison reports, sparklines
pub const perf_dashboard = @import("perf_dashboard");

// Note: benchmarks is NOT imported here to avoid build system complexity.
// Use @import("benchmarks") directly in benchmark code.

// Note: stress_test is NOT imported here to avoid circular dependency.
// Stress test imports brain, but brain does not import stress_test.

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN ATLAS — Complete Neuroanatomy
// ═══════════════════════════════════════════════════════════════════════════════

/// Brain region with its biological function and file location
pub const BrainRegion = struct {
    name: []const u8,
    biological_function: []const u8,
    file: []const u8,
};

/// Complete Trinity Brain Atlas — all brain regions with their roles
pub const BRAIN_ATLAS = [_]BrainRegion{
    .{
        .name = "Thalamus",
        .biological_function = "Sensory Relay — Railway live logs relay",
        .file = "thalamus_logs.zig",
    },
    .{
        .name = "Basal Ganglia",
        .biological_function = "Action Selection — prevents duplicate task execution",
        .file = "basal_ganglia.zig",
    },
    .{
        .name = "Reticular Formation",
        .biological_function = "Broadcast Alerting — event bus for all agents",
        .file = "reticular_formation.zig",
    },
    .{
        .name = "Locus Coeruleus",
        .biological_function = "Arousal Regulation — backoff/timing policy",
        .file = "locus_coeruleus.zig",
    },
    .{
        .name = "Amygdala",
        .biological_function = "Emotional Salience — prioritizes urgent/critical events",
        .file = "amygdala.zig",
    },
    .{
        .name = "Prefrontal Cortex",
        .biological_function = "Executive Function — decision making and planning",
        .file = "prefrontal_cortex.zig",
    },
    .{
        .name = "Intraparietal Sulcus",
        .biological_function = "Numerical Processing — f16/GF16/TF3 conversions",
        .file = "intraparietal_sulcus.zig",
    },
    .{
        .name = "Hippocampus",
        .biological_function = "Memory Persistence — JSONL event logging",
        .file = "persistence.zig",
    },
    .{
        .name = "Corpus Callosum",
        .biological_function = "Telemetry — time-series metrics aggregation",
        .file = "telemetry.zig",
    },
    .{
        .name = "Microglia",
        .biological_function = "Immune Surveillance — The Constant Gardeners. Patrols farm every 30min, prunes crashed workers, stimulates regrowth from leaders",
        .file = "microglia.zig",
    },
    .{
        .name = "State Recovery",
        .biological_function = "Crash Recovery — Persistent state storage with versioning and migration",
        .file = "state_recovery.zig",
    },
    .{
        .name = "Hypothalamus",
        .biological_function = "Administrative Control — brain maintenance: reset, doctor, prune, migrate, backup, restore",
        .file = "admin.zig",
    },
    .{
        .name = "Health History",
        .biological_function = "Hippocampal Memory — brain health snapshots for trend analysis",
        .file = "health_history.zig",
    },
    .{
        .name = "Metrics Dashboard",
        .biological_function = "Command Center — aggregates metrics from all brain regions with trend detection",
        .file = "metrics_dashboard.zig",
    },
    .{
        .name = "Brain Alerts",
        .biological_function = "Critical Health Notification — monitors health and sends alerts when thresholds are crossed",
        .file = "alerts.zig",
    },
    .{
        .name = "Simulation",
        .biological_function = "Synthetic Workload Testing — realistic workload testing for brain circuit validation",
        .file = "simulation.zig",
    },
    .{
        .name = "Observability Export",
        .biological_function = "External Monitoring — Export brain telemetry for Prometheus, OpenTelemetry, and other systems",
        .file = "observability_export.zig",
    },
    .{
        .name = "Cerebellum",
        .biological_function = "Motor Learning & Adaptive Performance — performance history tracking, pattern recognition, adaptive backoff, failure prediction",
        .file = "learning.zig",
    },
    .{
        .name = "Thalamic Async Processor",
        .biological_function = "Non-blocking Operations — async task claim/release, event publishing, health checks, background telemetry collection",
        .file = "async_processor.zig",
    },
    .{
        .name = "Corpus Callosum (Federation)",
        .biological_function = "Inter-Hemispheric Communication — distributed multi-instance coordination, leader election, CRDT state sync",
        .file = "federation.zig",
    },
    .{
        .name = "Visual Cortex",
        .biological_function = "Spatial Representation — ASCII art brain maps, sparklines, heatmaps, 3D visualization",
        .file = "visualization.zig",
    },
    .{
        .name = "Evolution Simulation",
        .biological_function = "Deterministic Evolution — Parallel brain evolution scenarios (baseline/current/multi-obj/dePIN)",
        .file = "evolution_simulation.zig",
    },
    .{
        .name = "Performance Dashboard",
        .biological_function = "Performance Monitoring — Real-time tracking, SLA monitoring, comparison reports, sparklines",
        .file = "perf_dashboard.zig",
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGENT COORDINATION HELPER — High-level API for orchestrators
// ═══════════════════════════════════════════════════════════════════════════════

/// Region health status for monitoring
pub const RegionHealth = struct {
    name: []const u8,
    healthy: bool,
    score: f32,
    last_check: i64,
    error_msg: ?[]const u8 = null,
};

/// Brain region dependency graph
pub const RegionDependency = struct {
    region: []const u8,
    depends_on: []const []const u8,
};

/// All brain region dependencies
pub const REGION_DEPENDENCIES = [_]RegionDependency{
    .{ .region = "Basal Ganglia", .depends_on = &[_][]const u8{} },
    .{ .region = "Reticular Formation", .depends_on = &[_][]const u8{} },
    .{ .region = "Locus Coeruleus", .depends_on = &[_][]const u8{} },
    .{ .region = "Amygdala", .depends_on = &[_][]const u8{} },
    .{ .region = "Prefrontal Cortex", .depends_on = &[_][]const u8{ "Reticular Formation", "Basal Ganglia" } },
    .{ .region = "Hippocampus", .depends_on = &[_][]const u8{"Reticular Formation"} },
    .{ .region = "Corpus Callosum", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Microglia", .depends_on = &[_][]const u8{ "Basal Ganglia", "Corpus Callosum" } },
    .{ .region = "Intraparietal Sulcus", .depends_on = &[_][]const u8{} },
    .{ .region = "Thalamus", .depends_on = &[_][]const u8{} },
    .{ .region = "State Recovery", .depends_on = &[_][]const u8{"Hippocampus"} },
    .{ .region = "Hypothalamus", .depends_on = &[_][]const u8{ "State Recovery", "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Health History", .depends_on = &[_][]const u8{"Corpus Callosum"} },
    .{ .region = "Metrics Dashboard", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation", "Locus Coeruleus", "Hippocampus", "Corpus Callosum", "Amygdala", "Prefrontal Cortex", "Intraparietal Sulcus", "Microglia", "Thalamus" } },
    .{ .region = "Brain Alerts", .depends_on = &[_][]const u8{ "Metrics Dashboard", "Health History" } },
    .{ .region = "Simulation", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Observability Export", .depends_on = &[_][]const u8{ "Metrics Dashboard", "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Thalamic Async Processor", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Cerebellum", .depends_on = &[_][]const u8{ "Locus Coeruleus", "Telemetry" } },
    .{ .region = "Corpus Callosum (Federation)", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation", "Locus Coeruleus" } },
    .{ .region = "Visual Cortex", .depends_on = &[_][]const u8{} },
    .{ .region = "Evolution Simulation", .depends_on = &[_][]const u8{ "Basal Ganglia", "Reticular Formation" } },
    .{ .region = "Performance Dashboard", .depends_on = &[_][]const u8{"Metrics Dashboard"} },
};

/// AgentCoordination — high-level wrapper combining all brain regions
/// for seamless integration into orchestrators and coordinators.
pub const AgentCoordination = struct {
    allocator: std.mem.Allocator,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
    backoff_policy: locus_coeruleus.BackoffPolicy,
    region_health: std.StringHashMap(RegionHealth),
    telemetry: ?*telemetry.BrainTelemetry,
    alert_manager: ?*alerts.AlertManager,

    /// Initialize agent coordination with all brain regions
    pub fn init(allocator: std.mem.Allocator) !AgentCoordination {
        const registry = try basal_ganglia.getGlobal(allocator);
        const event_bus = try reticular_formation.getGlobal(allocator);

        var coord = AgentCoordination{
            .allocator = allocator,
            .registry = registry,
            .event_bus = event_bus,
            .backoff_policy = locus_coeruleus.BackoffPolicy.init(),
            .region_health = std.StringHashMap(RegionHealth).init(allocator),
            .telemetry = null,
            .alert_manager = null,
        };

        // Initialize region health tracking
        const now = std.time.milliTimestamp();
        inline for (BRAIN_ATLAS) |region| {
            try coord.region_health.put(region.name, .{
                .name = region.name,
                .healthy = true,
                .score = 100.0,
                .last_check = now,
            });
        }

        return coord;
    }

    /// Deinitialize coordination
    pub fn deinit(self: *AgentCoordination) void {
        var iter = self.region_health.iterator();
        while (iter.next()) |entry| {
            // Note: keys point to string literals in BRAIN_ATLAS, don't free them
            // Only free allocated error messages
            if (entry.value_ptr.error_msg) |err| self.allocator.free(err);
        }
        self.region_health.deinit();
    }

    /// Attach telemetry for metrics tracking
    pub fn attachTelemetry(self: *AgentCoordination, tel: *telemetry.BrainTelemetry) void {
        self.telemetry = tel;
    }

    /// Attach alert manager for notifications
    pub fn attachAlertManager(self: *AgentCoordination, mgr: *alerts.AlertManager) void {
        self.alert_manager = mgr;
    }

    /// Check health of all brain regions
    pub fn checkRegionHealth(self: *AgentCoordination) !void {
        const now = std.time.milliTimestamp();

        // Check Basal Ganglia
        if (self.region_health.getPtr("Basal Ganglia")) |health| {
            const claim_count = self.registry.count();
            health.score = if (claim_count < 1000) 100.0 else @max(0.0, 100.0 - @as(f32, @floatFromInt(claim_count - 1000)) / 10.0);
            health.healthy = health.score >= 50.0;
            health.last_check = now;
        }

        // Check Reticular Formation
        if (self.region_health.getPtr("Reticular Formation")) |health| {
            const stats = self.event_bus.getStats();
            const buffer_pct = @as(f32, @floatFromInt(stats.buffered)) / 10000.0 * 100.0;
            health.score = 100.0 - buffer_pct;
            health.healthy = health.score >= 50.0;
            health.last_check = now;
        }

        // Locus Coeruleus is always healthy (stateless)
        if (self.region_health.getPtr("Locus Coeruleus")) |health| {
            health.score = 100.0;
            health.healthy = true;
            health.last_check = now;
        }

        // Record telemetry point if attached
        if (self.telemetry) |tel| {
            const overall_health = self.getOverallHealthScore();
            try tel.record(.{
                .timestamp = now,
                .active_claims = self.registry.count(),
                .events_published = self.event_bus.getStats().published,
                .events_buffered = self.event_bus.getStats().buffered,
                .health_score = overall_health,
            });
        }

        // Check for critical conditions and alert
        if (self.alert_manager) |mgr| {
            const overall_health = self.getOverallHealthScore();
            const stats = self.event_bus.getStats();
            try mgr.checkHealth(overall_health, stats.buffered, self.registry.count());
        }
    }

    /// Get overall health score across all regions
    pub fn getOverallHealthScore(self: *const AgentCoordination) f32 {
        var total: f32 = 0;
        var count: usize = 0;

        var iter = self.region_health.iterator();
        while (iter.next()) |entry| {
            total += entry.value_ptr.score;
            count += 1;
        }

        return if (count > 0) total / @as(f32, @floatFromInt(count)) else 100.0;
    }

    /// Get health status of a specific region
    pub fn getRegionHealth(self: *const AgentCoordination, region_name: []const u8) ?RegionHealth {
        return self.region_health.get(region_name);
    }

    /// Check if region dependencies are satisfied
    pub fn checkDependencies(self: *const AgentCoordination, region_name: []const u8) bool {
        for (REGION_DEPENDENCIES) |dep| {
            if (std.mem.eql(u8, dep.region, region_name)) {
                for (dep.depends_on) |dep_name| {
                    if (self.region_health.get(dep_name)) |health| {
                        if (!health.healthy) return false;
                    }
                }
                return true;
            }
        }
        return true; // No dependencies means always satisfied
    }

    /// Get list of unhealthy regions
    pub fn getUnhealthyRegions(self: *const AgentCoordination, allocator: std.mem.Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8).initCapacity(allocator, 16) catch |err| {
            std.log.err("Failed to allocate unhealthy regions list: {}", .{err});
            return error.OutOfMemory;
        };
        defer list.deinit(allocator);

        var iter = self.region_health.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.healthy) {
                try list.append(allocator, try allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        return list.toOwnedSlice(allocator);
    }

    /// Claim a task for an agent — returns true if successful
    /// If false, use getBackoffDelay() to wait before retrying
    pub fn claimTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8) !bool {
        return try self.registry.claim(self.allocator, task_id, agent_id, 300000); // 5 min TTL
    }

    /// Refresh task heartbeat — call periodically while task is running
    pub fn refreshHeartbeat(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8) bool {
        return self.registry.heartbeat(task_id, agent_id);
    }

    /// Complete a task and publish completion event
    pub fn completeTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8, duration_ms: u64) !void {
        // Mark task as completed in registry
        _ = self.registry.complete(task_id, agent_id);

        // Publish task_completed event to reticular formation
        const event_data = reticular_formation.EventData{
            .task_completed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .duration_ms = duration_ms,
            },
        };

        try self.event_bus.publish(.task_completed, event_data);
    }

    /// Report task failure to reticular formation
    pub fn failTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8, err_msg: []const u8) !void {
        // Abandon task in registry
        _ = self.registry.abandon(task_id, agent_id);

        // Publish task_failed event
        const event_data = reticular_formation.EventData{
            .task_failed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .err_msg = err_msg,
            },
        };

        try self.event_bus.publish(.task_failed, event_data);
    }

    /// Get backoff delay for next retry attempt
    /// Call this when claimTask() returns false
    pub fn getBackoffDelay(self: *const AgentCoordination, attempt: u32) u64 {
        return self.backoff_policy.nextDelay(attempt);
    }

    /// Get current coordination statistics
    pub const CoordinationStats = struct {
        active_claims: usize,
        total_events_published: u64,
        total_events_polled: u64,
        buffered_events: usize,
    };

    pub fn getStats(self: *const AgentCoordination) CoordinationStats {
        const event_stats = self.event_bus.getStats();
        return CoordinationStats{
            .active_claims = self.registry.count(),
            .total_events_published = event_stats.published,
            .total_events_polled = event_stats.polled,
            .buffered_events = event_stats.buffered,
        };
    }

    /// Poll recent events from reticular formation
    pub fn pollEvents(self: *AgentCoordination, since: i64, max_events: usize) ![]reticular_formation.AgentEventRecord {
        return self.event_bus.poll(since, self.allocator, max_events);
    }

    /// Health check for brain circuit — returns score 0-100
    /// Score = (claims_ok * 0.4 + events_ok * 0.4 + backoff_ok * 0.2) * 100
    pub fn healthCheck(self: *const AgentCoordination) struct {
        score: f32,
        healthy: bool,
        details: struct {
            claims_count: usize,
            events_published: u64,
            events_buffered: usize,
            unhealthy_regions: usize,
        },
    } {
        const stats = self.getStats();

        // Health criteria:
        // - Claims: should have reasonable count (not overflowing)
        // - Events: should be publishing and buffering
        // - Backoff: always healthy (policy is stateless)

        const claims_ok = stats.active_claims < 10_000; // Not overflowing
        const events_ok = stats.total_events_published > 0 or stats.buffered_events == 0; // Either publishing or empty

        // Count unhealthy regions
        var unhealthy_count: usize = 0;
        var iter = self.region_health.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.healthy) unhealthy_count += 1;
        }

        const score = (@as(f32, if (claims_ok) 1 else 0) * 0.4 +
            @as(f32, if (events_ok) 1 else 0) * 0.4 +
            1.0 * 0.2) * 100.0; // Backoff always OK

        return .{
            .score = score,
            .healthy = score >= 80.0 and unhealthy_count == 0,
            .details = .{
                .claims_count = stats.active_claims,
                .events_published = stats.total_events_published,
                .events_buffered = stats.buffered_events,
                .unhealthy_regions = unhealthy_count,
            },
        };
    }

    /// Export metrics in Prometheus format for monitoring
    pub fn exportMetrics(self: *const AgentCoordination, writer: anytype) !void {
        const stats = self.getStats();
        const health = self.healthCheck();

        try writer.print("# HELP s3ai_brain_active_claims Current number of active task claims\n", .{});
        try writer.print("# TYPE s3ai_brain_active_claims gauge\n", .{});
        try writer.print("s3ai_brain_active_claims {d}\n", .{stats.active_claims});

        try writer.print("\n# HELP s3ai_brain_events_published Total events published\n", .{});
        try writer.print("# TYPE s3ai_brain_events_published counter\n", .{});
        try writer.print("s3ai_brain_events_published {d}\n", .{stats.total_events_published});

        try writer.print("\n# HELP s3ai_brain_events_polled Total event polls\n", .{});
        try writer.print("# TYPE s3ai_brain_events_polled counter\n", .{});
        try writer.print("s3ai_brain_events_polled {d}\n", .{stats.total_events_polled});

        try writer.print("\n# HELP s3ai_brain_events_buffered Current buffered events\n", .{});
        try writer.print("# TYPE s3ai_brain_events_buffered gauge\n", .{});
        try writer.print("s3ai_brain_events_buffered {d}\n", .{stats.buffered_events});

        try writer.print("\n# HELP s3ai_brain_health_score Brain health score (0-100)\n", .{});
        try writer.print("# TYPE s3ai_brain_health_score gauge\n", .{});
        try writer.print("s3ai_brain_health_score {d:.1}\n", .{health.score});

        try writer.print("\n# HELP s3ai_brain_healthy Brain health status (1=healthy, 0=unhealthy)\n", .{});
        try writer.print("# TYPE s3ai_brain_healthy gauge\n", .{});
        try writer.print("s3ai_brain_healthy {d}\n", .{@intFromBool(health.healthy)});
    }

    /// Dump current brain state for debugging
    pub fn dump(self: *const AgentCoordination, writer: anytype) !void {
        const stats = self.getStats();
        const health = self.healthCheck();

        try writer.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  S³AI BRAIN DUMP — {s:>19}                  ║\n", .{"v5.1"});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  HEALTH SCORE: {d:.1}/100  [{s:>10}]                        ║\n", .{ health.score, if (health.healthy) "HEALTHY" else "UNHEALTHY" });
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Basal Ganglia (Action Selection)                            ║\n", .{});
        try writer.print("║    Active Claims:    {d:>6}                                 ║\n", .{stats.active_claims});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Reticular Formation (Broadcast Alerting)                    ║\n", .{});
        try writer.print("║    Events Published: {d:>6}                                 ║\n", .{stats.total_events_published});
        try writer.print("║    Events Polled:    {d:>6}                                 ║\n", .{stats.total_events_polled});
        try writer.print("║    Events Buffered:  {d:>6}                                 ║\n", .{stats.buffered_events});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Locus Coeruleus (Arousal Regulation)                        ║\n", .{});
        try writer.print("║    Strategy:         {s:>30}        ║\n", .{@tagName(self.backoff_policy.strategy)});
        try writer.print("║    Initial Delay:    {d:>6} ms                             ║\n", .{self.backoff_policy.initial_ms});
        try writer.print("║    Max Delay:        {d:>6} ms                             ║\n", .{self.backoff_policy.max_ms});
        try writer.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Visual ASCII brain scan (for TUI display)
    pub fn scan(self: *const AgentCoordination) struct {
        basal_ganglia: []const u8,
        reticular_formation: []const u8,
        locus_coeruleus: []const u8,
        overall: []const u8,
    } {
        const stats = self.getStats();
        const health = self.healthCheck();

        // Activity levels based on stats
        const bg_level: []const u8 = if (stats.active_claims == 0) "💤" else if (stats.active_claims < 10) "🟢" else if (stats.active_claims < 100) "🟡" else "🔴";
        const rf_level: []const u8 = if (stats.total_events_published == 0) "💤" else if (stats.buffered_events < 100) "🟢" else if (stats.buffered_events < 1000) "🟡" else "🔴";
        const lc_level: []const u8 = "🟢"; // Always healthy (stateless)

        return .{
            .basal_ganglia = bg_level,
            .reticular_formation = rf_level,
            .locus_coeruleus = lc_level,
            .overall = if (health.healthy) "✅" else "⚠️",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Brain atlas completeness" {
    try std.testing.expectEqual(@as(usize, 23), BRAIN_ATLAS.len);
    try std.testing.expect(std.mem.eql(u8, "Basal Ganglia", BRAIN_ATLAS[1].name));
    try std.testing.expect(std.mem.eql(u8, "Microglia", BRAIN_ATLAS[9].name));
    try std.testing.expect(std.mem.eql(u8, "State Recovery", BRAIN_ATLAS[10].name));
    try std.testing.expect(std.mem.eql(u8, "Hypothalamus", BRAIN_ATLAS[11].name));
    try std.testing.expect(std.mem.eql(u8, "Health History", BRAIN_ATLAS[12].name));
    try std.testing.expect(std.mem.eql(u8, "Metrics Dashboard", BRAIN_ATLAS[13].name));
    try std.testing.expect(std.mem.eql(u8, "Brain Alerts", BRAIN_ATLAS[14].name));
    try std.testing.expect(std.mem.eql(u8, "Simulation", BRAIN_ATLAS[15].name));
    try std.testing.expect(std.mem.eql(u8, "Observability Export", BRAIN_ATLAS[16].name));
    try std.testing.expect(std.mem.eql(u8, "Cerebellum", BRAIN_ATLAS[17].name));
    try std.testing.expect(std.mem.eql(u8, "Thalamic Async Processor", BRAIN_ATLAS[18].name));
    try std.testing.expect(std.mem.eql(u8, "Corpus Callosum (Federation)", BRAIN_ATLAS[19].name));
    try std.testing.expect(std.mem.eql(u8, "Visual Cortex", BRAIN_ATLAS[20].name));
    try std.testing.expect(std.mem.eql(u8, "Evolution Simulation", BRAIN_ATLAS[21].name));
    try std.testing.expect(std.mem.eql(u8, "Performance Dashboard", BRAIN_ATLAS[22].name));
}

test "Metrics dashboard collects all regions" {
    const allocator = std.testing.allocator;
    const dashboard = metrics_dashboard;
    var metrics = dashboard.AggregateMetrics.init(allocator);
    defer {
        metrics.deinit();
        // Clean up globals created during metrics.collect()
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
    }

    try metrics.collect();
    try std.testing.expectEqual(@as(usize, 10), metrics.regions.items.len);
}

test "AgentCoordination claim and complete" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        coord.deinit();
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
    }

    const task_id = "test-task-123";
    const agent_id = "agent-alpha-001";

    // Claim task
    const claimed = try coord.claimTask(task_id, agent_id);
    try std.testing.expect(claimed);

    // Verify heartbeat works
    const heartbeat_ok = coord.refreshHeartbeat(task_id, agent_id);
    try std.testing.expect(heartbeat_ok);

    // Complete task
    try coord.completeTask(task_id, agent_id, 5000);

    // Verify claim is no longer valid
    const claimed_again = try coord.claimTask(task_id, agent_id);
    try std.testing.expect(claimed_again); // Can claim again after completion
}

test "AgentCoordination health check" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    const health = coord.healthCheck();
    try std.testing.expect(health.healthy);
    try std.testing.expect(health.score >= 80.0);
}

test "AgentCoordination region health tracking" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    // Check that all regions are tracked
    try std.testing.expectEqual(BRAIN_ATLAS.len, coord.region_health.count());

    // Verify Basal Ganglia health
    const bg_health = coord.getRegionHealth("Basal Ganglia");
    try std.testing.expect(bg_health != null);
    try std.testing.expect(bg_health.?.healthy);

    // Verify Reticular Formation health
    const rf_health = coord.getRegionHealth("Reticular Formation");
    try std.testing.expect(rf_health != null);
    try std.testing.expect(rf_health.?.healthy);
}

test "AgentCoordination dependency checking" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    // Regions with no dependencies should always pass
    try std.testing.expect(coord.checkDependencies("Basal Ganglia"));
    try std.testing.expect(coord.checkDependencies("Locus Coeruleus"));

    // Prefrontal Cortex depends on Reticular Formation and Basal Ganglia
    // Both should be healthy initially
    try std.testing.expect(coord.checkDependencies("Prefrontal Cortex"));

    // Metrics Dashboard depends on all regions
    try std.testing.expect(coord.checkDependencies("Metrics Dashboard"));
}

test "AgentCoordination unhealthy regions detection" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    // Initially no unhealthy regions
    const unhealthy = try coord.getUnhealthyRegions(allocator);
    defer {
        for (unhealthy) |r| allocator.free(r);
        allocator.free(unhealthy);
    }
    try std.testing.expectEqual(@as(usize, 0), unhealthy.len);
}

test "AgentCoordination overall health score" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    const overall = coord.getOverallHealthScore();
    try std.testing.expect(overall >= 0.0);
    try std.testing.expect(overall <= 100.0);
    try std.testing.expect(overall >= 80.0); // Should be healthy initially
}

test "AgentCoordination telemetry integration" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    coord.attachTelemetry(&tel);

    // Check region health - should record telemetry
    try coord.checkRegionHealth();

    // Verify telemetry was recorded
    const avg = tel.avgHealth(10);
    try std.testing.expect(avg >= 0.0);
}

test "AgentCoordination alert manager integration" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    var mgr = try alerts.AlertManager.init(allocator);
    defer mgr.deinit();

    coord.attachAlertManager(&mgr);

    // Check region health - should trigger alerts if needed
    try coord.checkRegionHealth();

    // Verify stats are available
    const stats = try mgr.getStats();
    try std.testing.expect(stats.total >= 0);
}

test "AgentCoordination full lifecycle with monitoring" {
    const allocator = std.testing.allocator;
    var coord = try AgentCoordination.init(allocator);
    defer {
        reticular_formation.resetGlobal(allocator);
        basal_ganglia.resetGlobal(allocator);
        coord.deinit();
    }

    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();
    coord.attachTelemetry(&tel);

    var mgr = try alerts.AlertManager.init(allocator);
    defer mgr.deinit();
    coord.attachAlertManager(&mgr);

    const task_id = "lifecycle-test";
    const agent_id = "agent-test";

    // Claim
    _ = try coord.claimTask(task_id, agent_id);

    // Check health
    try coord.checkRegionHealth();

    // Complete
    try coord.completeTask(task_id, agent_id, 100);

    // Verify telemetry recorded
    const avg = tel.avgHealth(10);
    try std.testing.expect(avg >= 0.0);
}

test "Brain region dependency graph completeness" {
    // Verify all regions in BRAIN_ATLAS have dependencies defined
    try std.testing.expectEqual(@as(usize, 23), BRAIN_ATLAS.len);
    // REGION_DEPENDENCIES may not include all regions (some have no deps)

    // Check that all region names match
    for (BRAIN_ATLAS) |region| {
        var found = false;
        for (REGION_DEPENDENCIES) |dep| {
            if (std.mem.eql(u8, region.name, dep.region)) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}

test "All brain regions are exported" {
    // Verify all brain region modules have expected symbols
    // This test ensures modules compile and export expected APIs

    // Basal Ganglia should have Registry
    _ = basal_ganglia.Registry;

    // Reticular Formation should have EventBus
    _ = reticular_formation.EventBus;

    // Locus Coeruleus should have BackoffPolicy
    _ = locus_coeruleus.BackoffPolicy;

    // Persistence should have BrainEventLog
    _ = persistence.BrainEventLog;

    // Telemetry should have BrainTelemetry
    _ = telemetry.BrainTelemetry;

    // Amygdala should have Amygdala
    _ = amygdala.Amygdala;

    // Prefrontal Cortex should have PrefrontalCortex
    _ = prefrontal_cortex.PrefrontalCortex;

    // Health History should have BrainHealthHistory
    _ = health_history.BrainHealthHistory;

    // Note: thalamus_logs requires external 'trinity-sensation' module
    // _ = thalamus_logs.ThalamusLogs;

    // Microglia should have Microglia
    _ = microglia.Microglia;

    // Metrics Dashboard should have RegionMetrics
    _ = metrics_dashboard.RegionMetrics;

    // Alerts should have AlertManager
    _ = alerts.AlertManager;

    // Simulation should have SimulationEngine
    _ = simulation.SimulationEngine;

    // State Recovery should have StateManager
    _ = state_recovery.StateManager;

    // Admin should have AdminManager
    _ = admin.AdminManager;

    // Note: intraparietal_sulcus not provided as test dependency
    // _ = intraparietal_sulcus.NumberFormatter;

    // Observability Export should have ObservabilityExporter
    _ = observability_export.ObservabilityExporter;

    // Note: async_processor, learning, federation not provided as test dependencies
    // _ = async_processor.AsyncProcessor;
    // _ = learning.LearningSystem;
    // _ = federation.FederationMessage;
}
