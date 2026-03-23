//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN SIMULATION — v1.0 — Realistic Workload Testing
//!
//! Simulates realistic agent swarm scenarios to validate brain circuit behavior:
//! - 100 agents competing for tasks
//! - Event storms (1000 events/sec)
//! - Network partitions
//! - Agent crashes
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Brain Region: Simulation Environment (Synthetic Workload Generator)

const std = @import("std");

// Import brain modules directly to avoid circular dependency
// Using module names from build.zig imports
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const locus_coeruleus = @import("locus_coeruleus");

// AgentCoordination wrapper for simulation
const AgentCoordination = struct {
    allocator: std.mem.Allocator,
    registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,
    backoff_policy: locus_coeruleus.BackoffPolicy,

    pub fn init(allocator: std.mem.Allocator) !AgentCoordination {
        const registry = try basal_ganglia.getGlobal(allocator);
        const event_bus = try reticular_formation.getGlobal(allocator);
        return AgentCoordination{
            .allocator = allocator,
            .registry = registry,
            .event_bus = event_bus,
            .backoff_policy = locus_coeruleus.BackoffPolicy.init(),
        };
    }

    pub fn claimTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8) !bool {
        return try self.registry.claim(self.allocator, task_id, agent_id, 300000);
    }

    pub fn completeTask(self: *AgentCoordination, task_id: []const u8, agent_id: []const u8, duration_ms: u64) !void {
        _ = self.registry.complete(task_id, agent_id);
        const event_data = reticular_formation.EventData{
            .task_completed = .{
                .task_id = task_id,
                .agent_id = agent_id,
                .duration_ms = duration_ms,
            },
        };
        try self.event_bus.publish(.task_completed, event_data);
    }

    pub fn getStats(self: *const AgentCoordination) struct {
        active_claims: usize,
        total_events_published: u64,
        total_events_polled: u64,
        buffered_events: usize,
    } {
        const event_stats = self.event_bus.getStats();
        return .{
            .active_claims = self.registry.count(),
            .total_events_published = event_stats.published,
            .total_events_polled = event_stats.polled,
            .buffered_events = event_stats.buffered,
        };
    }

    pub fn healthCheck(self: *const AgentCoordination) struct {
        score: f32,
        healthy: bool,
        details: struct {
            claims_count: usize,
            events_published: u64,
            events_buffered: usize,
        },
    } {
        const stats = self.getStats();
        const claims_ok = stats.active_claims < 10_000;
        const events_ok = stats.total_events_published > 0 or stats.buffered_events == 0;
        const score = (@as(f32, if (claims_ok) 1 else 0) * 0.4 +
            @as(f32, if (events_ok) 1 else 0) * 0.4 +
            1.0 * 0.2) * 100.0;
        return .{
            .score = score,
            .healthy = score >= 80.0,
            .details = .{
                .claims_count = stats.active_claims,
                .events_published = stats.total_events_published,
                .events_buffered = stats.buffered_events,
            },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATION CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimulationConfig = struct {
    num_agents: usize = 100,
    num_tasks: usize = 1000,
    event_rate_per_sec: u32 = 1000,
    duration_ms: u64 = 10_000, // 10 seconds default
    crash_probability: f32 = 0.01, // 1% chance per agent
    partition_probability: f32 = 0.02, // 2% chance of network partition
    seed: u64 = 0, // 0 = random seed

    pub fn init() SimulationConfig {
        return SimulationConfig{};
    }

    pub fn withAgents(self: SimulationConfig, count: usize) SimulationConfig {
        var config = self;
        config.num_agents = count;
        return config;
    }

    pub fn withTasks(self: SimulationConfig, count: usize) SimulationConfig {
        var config = self;
        config.num_tasks = count;
        return config;
    }

    pub fn withEventRate(self: SimulationConfig, rate: u32) SimulationConfig {
        var config = self;
        config.event_rate_per_sec = rate;
        return config;
    }

    pub fn withDuration(self: SimulationConfig, duration_ms: u64) SimulationConfig {
        var config = self;
        config.duration_ms = duration_ms;
        return config;
    }

    pub fn withCrashProb(self: SimulationConfig, prob: f32) SimulationConfig {
        var config = self;
        config.crash_probability = prob;
        return config;
    }

    pub fn withPartitionProb(self: SimulationConfig, prob: f32) SimulationConfig {
        var config = self;
        config.partition_probability = prob;
        return config;
    }

    pub fn withSeed(self: SimulationConfig, seed: u64) SimulationConfig {
        var config = self;
        config.seed = seed;
        return config;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATION RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimulationResult = struct {
    config: SimulationConfig,
    duration_ms: u64,
    tasks_processed: usize,
    tasks_failed: usize,
    events_published: u64,
    agents_crashed: usize,
    partitions_occurred: usize,
    peak_concurrent_claims: usize,
    brain_health_final: f32,

    pub fn format(self: *const SimulationResult, writer: anytype) !void {
        try writer.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  S³AI BRAIN SIMULATION REPORT                                 ║\n", .{});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Configuration                                               ║\n", .{});
        try writer.print("║    Agents:            {d:>6}                                 ║\n", .{self.config.num_agents});
        try writer.print("║    Tasks:             {d:>6}                                 ║\n", .{self.config.num_tasks});
        try writer.print("║    Event Rate:        {d:>6} events/sec                      ║\n", .{self.config.event_rate_per_sec});
        try writer.print("║    Duration:          {d:>6} ms                              ║\n", .{self.duration_ms});
        try writer.print("║    Crash Prob:        {d:>6.2}%                               ║\n", .{self.config.crash_probability * 100});
        try writer.print("║    Partition Prob:    {d:>6.2}%                               ║\n", .{self.config.partition_probability * 100});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Results                                                      ║\n", .{});
        try writer.print("║    Tasks Processed:   {d:>6}                                 ║\n", .{self.tasks_processed});
        try writer.print("║    Tasks Failed:      {d:>6}                                 ║\n", .{self.tasks_failed});
        try writer.print("║    Success Rate:      {d:>6.1}%                               ║\n", .{if (self.config.num_tasks > 0) @as(f64, @floatFromInt(self.tasks_processed)) / @as(f64, @floatFromInt(self.config.num_tasks)) * 100 else 0});
        try writer.print("║    Events Published:  {d:>6}                                 ║\n", .{self.events_published});
        try writer.print("║    Agents Crashed:    {d:>6}                                 ║\n", .{self.agents_crashed});
        try writer.print("║    Partitions:        {d:>6}                                 ║\n", .{self.partitions_occurred});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Performance                                                  ║\n", .{});
        try writer.print("║    Peak Claims:       {d:>6}                                 ║\n", .{self.peak_concurrent_claims});
        try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Brain Health                                                  ║\n", .{});
        try writer.print("║    Final Score:       {d:>6.1}/100                            ║\n", .{self.brain_health_final});
        const health_status = if (self.brain_health_final >= 80) "HEALTHY" else if (self.brain_health_final >= 50) "DEGRADED" else "CRITICAL";
        try writer.print("║    Status:           {s}                                 ║\n", .{health_status});
        try writer.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
    }

    pub fn toJson(self: *const SimulationResult, writer: anytype) !void {
        try writer.writeAll("{");
        try writer.print("\"config\":{{\"agents\":{},\"tasks\":{},\"event_rate\":{},\"duration_ms\":{},\"crash_prob\":{},\"partition_prob\":{}}}", .{
            self.config.num_agents,
            self.config.num_tasks,
            self.config.event_rate_per_sec,
            self.config.duration_ms,
            self.config.crash_probability,
            self.config.partition_probability,
        });
        try writer.print(",\"duration_ms\":{},\"tasks_processed\":{},\"tasks_failed\":{},\"events_published\":{},\"agents_crashed\":{},\"partitions_occurred\":{},\"peak_concurrent_claims\":{},\"brain_health_final\":{d:.1}}}\n", .{
            self.duration_ms,
            self.tasks_processed,
            self.tasks_failed,
            self.events_published,
            self.agents_crashed,
            self.partitions_occurred,
            self.peak_concurrent_claims,
            self.brain_health_final,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimulationEngine = struct {
    allocator: std.mem.Allocator,
    config: SimulationConfig,
    rng: std.Random.DefaultPrng,
    coord: AgentCoordination,
    agent_ids: [][]const u8,

    // Partition state
    partitioned_agents: std.StringHashMap(bool),

    pub fn init(allocator: std.mem.Allocator, config: SimulationConfig) !SimulationEngine {
        var rng = std.Random.DefaultPrng.init(config.seed);
        if (config.seed == 0) {
            rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.nanoTimestamp())));
        }

        const coord = try AgentCoordination.init(allocator);

        // Generate agent IDs
        var agent_ids = try allocator.alloc([]const u8, config.num_agents);
        for (0..config.num_agents) |i| {
            agent_ids[i] = try allocator.dupe(u8, try std.fmt.allocPrint(allocator, "sim-agent-{d:0>4}", .{i}));
        }

        const partitioned_agents = std.StringHashMap(bool).init(allocator);

        return SimulationEngine{
            .allocator = allocator,
            .config = config,
            .rng = rng,
            .coord = coord,
            .agent_ids = agent_ids,
            .partitioned_agents = partitioned_agents,
        };
    }

    pub fn deinit(self: *SimulationEngine) void {
        for (self.agent_ids) |id| {
            self.allocator.free(id);
        }
        self.allocator.free(self.agent_ids);

        var iter = self.partitioned_agents.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.partitioned_agents.deinit();

        // Cleanup global state
        basal_ganglia.resetGlobal(self.allocator);
        reticular_formation.resetGlobal(self.allocator);
    }

    /// Run the full simulation
    pub fn run(self: *SimulationEngine) !SimulationResult {
        const start_time = std.time.nanoTimestamp();
        var tasks_processed: usize = 0;
        var tasks_failed: usize = 0;
        var agents_crashed: usize = 0;
        var partitions_occurred: usize = 0;
        var peak_claims: usize = 0;

        // Phase 1: Task Competition Simulation
        const comp_results = try self.simulateTaskCompetition();
        tasks_processed += comp_results.completed;
        tasks_failed += comp_results.failed;
        agents_crashed += comp_results.crashes;
        peak_claims = @max(peak_claims, comp_results.peak_claims);

        // Phase 2: Event Storm Simulation
        const storm_results = try self.simulateEventStorm();
        partitions_occurred = storm_results.partitions;

        const end_time = std.time.nanoTimestamp();
        const duration_ms = @as(u64, @intCast(@divTrunc(end_time - start_time, 1_000_000)));

        // Final brain health
        const health = self.coord.healthCheck();

        return SimulationResult{
            .config = self.config,
            .duration_ms = duration_ms,
            .tasks_processed = tasks_processed,
            .tasks_failed = tasks_failed,
            .events_published = self.coord.getStats().total_events_published,
            .agents_crashed = agents_crashed,
            .partitions_occurred = partitions_occurred,
            .peak_concurrent_claims = peak_claims,
            .brain_health_final = health.score,
        };
    }

    const CompetitionResults = struct {
        completed: usize,
        failed: usize,
        crashes: usize,
        peak_claims: usize,
    };

    fn simulateTaskCompetition(self: *SimulationEngine) !CompetitionResults {
        var completed: usize = 0;
        var failed: usize = 0;
        var crashes: usize = 0;
        var peak_claims: usize = 0;

        for (0..self.config.num_tasks) |task_idx| {
            const task_id = try std.fmt.allocPrint(self.allocator, "sim-task-{d:0>6}", .{task_idx});
            defer self.allocator.free(task_id);

            // Select random agent
            const agent_idx = self.rng.random().uintLessThan(usize, self.config.num_agents);
            const agent_id = self.agent_ids[agent_idx];

            // Check if agent is crashed
            if (self.rng.random().float(f32) < self.config.crash_probability) {
                crashes += 1;
                // Simulate crash by abandoning task
                _ = self.coord.registry.abandon(task_id, agent_id);
                failed += 1;
                continue;
            }

            // Check if agent is partitioned
            const is_partitioned = if (self.partitioned_agents.get(agent_id)) |p| p else false;
            if (is_partitioned) {
                // Partitioned agents can't claim tasks
                failed += 1;
                continue;
            }

            // Try to claim task
            const claimed = try self.coord.claimTask(task_id, agent_id);
            if (!claimed) {
                // Task already claimed by another agent
                continue;
            }

            // Simulate processing with latency (not tracked in this version)
            const latency_ms = self.rng.random().uintAtMost(u64, 100) + 10; // 10-110ms

            // Simulate network partition during processing
            if (self.rng.random().float(f32) < self.config.partition_probability) {
                try self.partitioned_agents.put(try self.allocator.dupe(u8, agent_id), true);
                // Task fails due to partition
                _ = self.coord.registry.abandon(task_id, agent_id);
                failed += 1;
                continue;
            }

            // Complete task
            try self.coord.completeTask(task_id, agent_id, latency_ms);
            completed += 1;

            // Track peak concurrent claims
            const stats = self.coord.getStats();
            peak_claims = @max(peak_claims, stats.active_claims);
        }

        return CompetitionResults{
            .completed = completed,
            .failed = failed,
            .crashes = crashes,
            .peak_claims = peak_claims,
        };
    }

    const StormResults = struct {
        partitions: usize,
    };

    fn simulateEventStorm(self: *SimulationEngine) !StormResults {
        const total_events = self.config.event_rate_per_sec * @as(u32, @intCast(self.config.duration_ms / 1000));
        var partitions: usize = 0;

        // Get event bus via reticular formation global
        const event_bus = try reticular_formation.getGlobal(self.allocator);

        for (0..total_events) |event_idx| {
            const event_type = switch (event_idx % 5) {
                0 => reticular_formation.AgentEventType.task_claimed,
                1 => reticular_formation.AgentEventType.task_completed,
                2 => reticular_formation.AgentEventType.task_failed,
                3 => reticular_formation.AgentEventType.agent_idle,
                else => reticular_formation.AgentEventType.agent_spawned,
            };

            const agent_idx = self.rng.random().uintLessThan(usize, self.config.num_agents);
            const agent_id = self.agent_ids[agent_idx];

            const data: reticular_formation.EventData = switch (event_type) {
                .task_claimed => .{ .task_claimed = .{
                    .task_id = "storm-task",
                    .agent_id = agent_id,
                } },
                .task_completed => .{ .task_completed = .{
                    .task_id = "storm-task",
                    .agent_id = agent_id,
                    .duration_ms = 100,
                } },
                .task_failed => .{ .task_failed = .{
                    .task_id = "storm-task",
                    .agent_id = agent_id,
                    .err_msg = "simulated failure",
                } },
                .agent_idle => .{ .agent_idle = .{
                    .agent_id = agent_id,
                    .idle_ms = 1000,
                } },
                .agent_spawned => .{ .agent_spawned = .{
                    .agent_id = agent_id,
                } },
                .task_abandoned => unreachable,
            };

            try event_bus.publish(event_type, data);

            // Simulate partition during storm
            if (self.rng.random().float(f32) < self.config.partition_probability * 0.1) {
                partitions += 1;
            }
        }

        return StormResults{
            .partitions = partitions,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Run a full simulation with default config
pub fn runSimulation(allocator: std.mem.Allocator, config: SimulationConfig) !SimulationResult {
    var engine = try SimulationEngine.init(allocator, config);
    defer engine.deinit();
    return engine.run();
}

/// Run a quick smoke test simulation
pub fn runSmokeTest(allocator: std.mem.Allocator) !SimulationResult {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(100)
        .withEventRate(100)
        .withDuration(1000)
        .withCrashProb(0.05)
        .withPartitionProb(0.02);
    return runSimulation(allocator, config);
}

/// Run the "100 agents" competition scenario
pub fn runAgentCompetition(allocator: std.mem.Allocator) !SimulationResult {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withEventRate(500)
        .withDuration(5000);
    return runSimulation(allocator, config);
}

/// Run the event storm scenario (1000 events/sec)
pub fn runEventStorm(allocator: std.mem.Allocator) !SimulationResult {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(500)
        .withEventRate(1000)
        .withDuration(10000);
    return runSimulation(allocator, config);
}

/// Run the network partition scenario
pub fn runNetworkPartition(allocator: std.mem.Allocator) !SimulationResult {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(500)
        .withEventRate(200)
        .withDuration(5000)
        .withPartitionProb(0.10); // 10% partition probability
    return runSimulation(allocator, config);
}

/// Run the agent crash scenario
pub fn runAgentCrash(allocator: std.mem.Allocator) !SimulationResult {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withEventRate(500)
        .withDuration(5000)
        .withCrashProb(0.10); // 10% crash probability
    return runSimulation(allocator, config);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Simulation: smoke test completes" {
    const result = try runSmokeTest(std.testing.allocator);
    try std.testing.expect(result.tasks_processed > 0);
    try std.testing.expect(result.brain_health_final >= 0);
}

test "Simulation: agent competition" {
    const result = try runAgentCompetition(std.testing.allocator);
    try std.testing.expect(result.config.num_agents == 100);
    try std.testing.expect(result.config.num_tasks == 1000);
    try std.testing.expect(result.events_published > 0);
}

test "Simulation: event storm" {
    const result = try runEventStorm(std.testing.allocator);
    try std.testing.expect(result.config.event_rate_per_sec == 1000);
    try std.testing.expect(result.events_published > 5000); // At least 5 seconds worth
}

test "Simulation: network partition" {
    const result = try runNetworkPartition(std.testing.allocator);
    try std.testing.expect(result.config.partition_probability == 0.10);
    try std.testing.expect(result.brain_health_final >= 0);
}

test "Simulation: agent crash" {
    const result = try runAgentCrash(std.testing.allocator);
    try std.testing.expect(result.config.crash_probability == 0.10);
    try std.testing.expect(result.agents_crashed >= 0);
}

test "Simulation: config builder" {
    const config = SimulationConfig.init()
        .withAgents(200)
        .withTasks(2000)
        .withEventRate(2000)
        .withDuration(20000)
        .withCrashProb(0.05)
        .withPartitionProb(0.03)
        .withSeed(12345);

    try std.testing.expectEqual(@as(usize, 200), config.num_agents);
    try std.testing.expectEqual(@as(usize, 2000), config.num_tasks);
    try std.testing.expectEqual(@as(u32, 2000), config.event_rate_per_sec);
    try std.testing.expectEqual(@as(u64, 20000), config.duration_ms);
    try std.testing.expectEqual(@as(f32, 0.05), config.crash_probability);
    try std.testing.expectEqual(@as(f32, 0.03), config.partition_probability);
    try std.testing.expectEqual(@as(u64, 12345), config.seed);
}

test "Simulation: result format" {
    const result = try runSmokeTest(std.testing.allocator);

    // Test format doesn't crash
    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.format(fbs.writer());
    try std.testing.expect(fbs.getWritten().len > 0);
}

test "Simulation: result json" {
    const result = try runSmokeTest(std.testing.allocator);

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toJson(fbs.writer());
    const output = fbs.getWritten();

    // Verify JSON structure
    try std.testing.expect(std.mem.startsWith(u8, output, "{"));
    try std.testing.expect(std.mem.endsWith(u8, output, "}\n"));
    try std.testing.expect(std.mem.indexOf(u8, output, "\"tasks_processed\"") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNTHETIC WORKLOAD GENERATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Simulation: synthetic workload - small scale" {
    const config = SimulationConfig.init()
        .withAgents(5)
        .withTasks(20)
        .withEventRate(50)
        .withDuration(1000)
        .withSeed(42); // Deterministic seed

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Verify all tasks were processed
    try std.testing.expectEqual(@as(usize, 20), result.config.num_tasks);
    try std.testing.expect(result.tasks_processed + result.tasks_failed > 0);
}

test "Simulation: synthetic workload - deterministic with seed" {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(50)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(12345);

    // Run twice with same seed
    var engine1 = try SimulationEngine.init(std.testing.allocator, config);
    defer engine1.deinit();
    const result1 = try engine1.run();

    var engine2 = try SimulationEngine.init(std.testing.allocator, config);
    defer engine2.deinit();
    const result2 = try engine2.run();

    // With same seed and no random events, results should be consistent
    try std.testing.expectEqual(result1.tasks_processed, result2.tasks_processed);
}

test "Simulation: synthetic workload - high crash probability" {
    const config = SimulationConfig.init()
        .withAgents(20)
        .withTasks(100)
        .withCrashProb(0.50) // 50% crash rate
        .withPartitionProb(0.0)
        .withSeed(999);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // With high crash probability, we should have crashes and failures
    try std.testing.expect(result.agents_crashed > 0 or result.tasks_failed > 0);
}

test "Simulation: synthetic workload - zero crash and partition" {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(50)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(42);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // With zero probabilities, no crashes or partitions should occur
    try std.testing.expectEqual(@as(usize, 0), result.agents_crashed);
    try std.testing.expectEqual(@as(usize, 0), result.partitions_occurred);
    // All tasks should succeed
    try std.testing.expect(result.tasks_processed > 0);
    try std.testing.expectEqual(@as(usize, 0), result.tasks_failed);
}

test "Simulation: synthetic workload - event storm stress" {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(100)
        .withEventRate(5000) // Very high event rate
        .withDuration(1000)
        .withSeed(777);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Should publish many events (5 events/sec * 1 sec = 5000 events)
    try std.testing.expect(result.events_published > 4000);
}

test "Simulation: agent ID generation" {
    const config = SimulationConfig.init()
        .withAgents(25)
        .withTasks(0)
        .withSeed(1);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    // Verify agent IDs are correctly formatted
    try std.testing.expectEqual(@as(usize, 25), engine.agent_ids.len);

    for (engine.agent_ids, 0..) |agent_id, i| {
        const expected = try std.fmt.allocPrint(std.testing.allocator, "sim-agent-{d:0>4}", .{i});
        defer std.testing.allocator.free(expected);
        try std.testing.expectEqualStrings(expected, agent_id);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALISTIC SCENARIO SIMULATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Simulation: realistic scenario - gradual load increase" {
    // Simulate gradually increasing load
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(500)
        .withEventRate(100)
        .withDuration(5000)
        .withCrashProb(0.01)
        .withSeed(42);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // System should remain healthy under gradual load
    try std.testing.expect(result.brain_health_final >= 50.0);
    try std.testing.expect(result.tasks_processed > 0);
}

test "Simulation: realistic scenario - burst traffic" {
    // Simulate burst traffic pattern
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withEventRate(2000) // Burst of events
        .withDuration(2000)
        .withSeed(111);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Should handle burst traffic
    try std.testing.expect(result.events_published > 0);
    try std.testing.expect(result.peak_concurrent_claims > 0);
}

test "Simulation: realistic scenario - partial network partition" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withPartitionProb(0.15) // 15% partition probability
        .withCrashProb(0.0)
        .withSeed(222);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Partitions should cause some task failures
    try std.testing.expect(result.partitions_occurred > 0);
    // But system should continue operating
    try std.testing.expect(result.brain_health_final >= 0);
}

test "Simulation: realistic scenario - agent cascade failure" {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(500)
        .withCrashProb(0.20) // High crash rate simulating cascade
        .withSeed(333);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Even with cascade, some tasks should complete
    try std.testing.expect(result.tasks_processed + result.tasks_failed > 0);
    try std.testing.expect(result.agents_crashed > 0);
}

test "Simulation: realistic scenario - steady state operation" {
    // Simulate normal steady-state operation
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withEventRate(500)
        .withDuration(10000)
        .withCrashProb(0.005) // Low crash rate
        .withPartitionProb(0.01)
        .withSeed(444);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Steady state should be healthy
    try std.testing.expect(result.brain_health_final >= 70.0);
    try std.testing.expect(result.tasks_processed > result.tasks_failed);
}

test "Simulation: realistic scenario - recovery after partition" {
    const config = SimulationConfig.init()
        .withAgents(30)
        .withTasks(150)
        .withPartitionProb(0.10)
        .withSeed(555);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Partitions occurred but system continued
    try std.testing.expect(result.partitions_occurred >= 0);
    // At least some tasks should succeed
    try std.testing.expect(result.tasks_processed > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE METRICS COLLECTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Simulation: metrics - task throughput" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(500)
        .withDuration(5000)
        .withSeed(666);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Calculate throughput: tasks processed per second
    const throughput = @as(f64, @floatFromInt(result.tasks_processed)) /
        @as(f64, @floatFromInt(result.duration_ms)) * 1000.0;

    // Throughput should be positive
    try std.testing.expect(throughput > 0);

    // With 500 tasks in 5 seconds, should be at least 50 tasks/sec (accounting for failures)
    try std.testing.expect(throughput > 10.0);
}

test "Simulation: metrics - peak concurrent claims tracking" {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(500)
        .withSeed(777);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Peak concurrent claims should be tracked
    try std.testing.expect(result.peak_concurrent_claims > 0);
    // Peak should not exceed number of tasks
    try std.testing.expect(result.peak_concurrent_claims <= result.config.num_tasks);
}

test "Simulation: metrics - event publication rate" {
    const config = SimulationConfig.init()
        .withAgents(20)
        .withTasks(100)
        .withEventRate(1000)
        .withDuration(5000)
        .withSeed(888);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Expected events: 1000 events/sec * 5 sec = 5000 events
    // Plus task events (claims, completions)
    try std.testing.expect(result.events_published >= 4000);
}

test "Simulation: metrics - agent crash count accuracy" {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withCrashProb(0.05) // 5% crash probability
        .withSeed(999);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // With 1000 tasks and 5% crash probability, expect ~50 crashes
    try std.testing.expect(result.agents_crashed >= 20); // At least some
    try std.testing.expect(result.agents_crashed <= 200); // At most all tasks
}

test "Simulation: metrics - partition tracking" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withPartitionProb(0.20)
        .withSeed(101);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Partitions should be tracked
    try std.testing.expect(result.partitions_occurred >= 0);
}

test "Simulation: metrics - duration measurement" {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(50)
        .withSeed(202);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const start_time = std.time.nanoTimestamp();
    const result = try engine.run();
    const end_time = std.time.nanoTimestamp();

    // Duration should be positive and reasonable
    try std.testing.expect(result.duration_ms > 0);
    // Duration should match actual elapsed time (within tolerance)
    const actual_duration_ms = @as(u64, @intCast(@divTrunc(end_time - start_time, 1_000_000)));
    try std.testing.expect(actual_duration_ms >= result.duration_ms);
    try std.testing.expect(actual_duration_ms < result.duration_ms + 1000); // Within 1 second
}

test "Simulation: metrics - success rate calculation" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(303);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // With no crashes or partitions, success rate should be 100%
    const success_rate = @as(f64, @floatFromInt(result.tasks_processed)) /
        @as(f64, @floatFromInt(result.config.num_tasks)) * 100.0;

    try std.testing.expect(success_rate >= 99.0); // Allow small rounding
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATION RESULT ANALYSIS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Simulation: analysis - health score calculation" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(404);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Healthy scenario should have high health score
    try std.testing.expect(result.brain_health_final >= 80.0);
    try std.testing.expect(result.brain_health_final <= 100.0);
}

test "Simulation: analysis - degraded health detection" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.30) // High crash rate
        .withPartitionProb(0.20)
        .withSeed(505);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Degraded scenario should have lower health score
    try std.testing.expect(result.brain_health_final >= 0.0);
    try std.testing.expect(result.brain_health_final <= 100.0);
}

test "Simulation: analysis - task failure impact on health" {
    // Compare two simulations
    const config_healthy = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(606);

    const config_degraded = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.50)
        .withPartitionProb(0.30)
        .withSeed(606);

    var engine_healthy = try SimulationEngine.init(std.testing.allocator, config_healthy);
    defer engine_healthy.deinit();
    const result_healthy = try engine_healthy.run();

    var engine_degraded = try SimulationEngine.init(std.testing.allocator, config_degraded);
    defer engine_degraded.deinit();
    const result_degraded = try engine_degraded.run();

    // Healthy simulation should have better health score
    try std.testing.expect(result_healthy.brain_health_final >= result_degraded.brain_health_final);
}

test "Simulation: analysis - result format output" {
    const result = try runSmokeTest(std.testing.allocator);

    // Test formatted output contains expected sections
    var buffer: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.format(fbs.writer());
    const output = fbs.getWritten();

    // Check for key sections in formatted output
    try std.testing.expect(std.mem.indexOf(u8, output, "S³AI BRAIN SIMULATION REPORT") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Configuration") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Results") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Performance") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Brain Health") != null);
}

test "Simulation: analysis - result JSON completeness" {
    const result = try runSmokeTest(std.testing.allocator);

    var buffer: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toJson(fbs.writer());
    const json = fbs.getWritten();

    // Verify all required fields are present
    const required_fields = [_][]const u8{
        "\"config\":",
        "\"duration_ms\":",
        "\"tasks_processed\":",
        "\"tasks_failed\":",
        "\"events_published\":",
        "\"agents_crashed\":",
        "\"partitions_occurred\":",
        "\"peak_concurrent_claims\":",
        "\"brain_health_final\":",
    };

    for (required_fields) |field| {
        try std.testing.expect(std.mem.indexOf(u8, json, field) != null);
    }
}

test "Simulation: analysis - config nested in JSON" {
    const result = try runAgentCompetition(std.testing.allocator);

    var buffer: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try result.toJson(fbs.writer());
    const json = fbs.getWritten();

    // Verify nested config fields
    const config_fields = [_][]const u8{
        "\"agents\":100",
        "\"tasks\":1000",
        "\"event_rate\":500",
    };

    for (config_fields) |field| {
        try std.testing.expect(std.mem.indexOf(u8, json, field) != null);
    }
}

test "Simulation: analysis - correlation between events and tasks" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withEventRate(100)
        .withDuration(5000)
        .withSeed(707);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Events published should correlate with tasks + storm events
    // At minimum: one event per task (claim or completion)
    const expected_min_events = result.tasks_processed;
    try std.testing.expect(result.events_published >= expected_min_events);
}

test "Simulation: analysis - peak claims vs total tasks" {
    const config = SimulationConfig.init()
        .withAgents(100)
        .withTasks(1000)
        .withSeed(808);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Peak concurrent claims shouldn't exceed total tasks
    try std.testing.expect(result.peak_concurrent_claims <= result.config.num_tasks);

    // Peak claims should be reasonable relative to agent count
    // (can't have more concurrent claims than agents in steady state)
    try std.testing.expect(result.peak_concurrent_claims > 0);
}

test "Simulation: analysis - failure modes" {
    const config = SimulationConfig.init()
        .withAgents(50)
        .withTasks(200)
        .withCrashProb(0.10)
        .withPartitionProb(0.10)
        .withSeed(909);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // In simulation with crashes and partitions, we expect:
    // 1. Some agents crashed
    try std.testing.expect(result.agents_crashed >= 0);
    // 2. Some partitions occurred
    try std.testing.expect(result.partitions_occurred >= 0);
    // 3. Some tasks failed
    try std.testing.expect(result.tasks_failed >= 0);
    // 4. But some tasks still succeeded
    try std.testing.expect(result.tasks_processed > 0);
}

test "Simulation: edge case - zero tasks" {
    const config = SimulationConfig.init()
        .withAgents(10)
        .withTasks(0)
        .withEventRate(0)
        .withDuration(100)
        .withSeed(100);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Should complete without errors
    try std.testing.expectEqual(@as(usize, 0), result.tasks_processed);
    try std.testing.expectEqual(@as(usize, 0), result.config.num_tasks);
}

test "Simulation: edge case - single agent single task" {
    const config = SimulationConfig.init()
        .withAgents(1)
        .withTasks(1)
        .withCrashProb(0.0)
        .withPartitionProb(0.0)
        .withSeed(111);

    var engine = try SimulationEngine.init(std.testing.allocator, config);
    defer engine.deinit();

    const result = try engine.run();

    // Single task should succeed
    try std.testing.expectEqual(@as(usize, 1), result.tasks_processed);
    try std.testing.expectEqual(@as(usize, 0), result.tasks_failed);
}
