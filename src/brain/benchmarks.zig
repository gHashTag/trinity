//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN BENCHMARKS — v1.1 — Performance Measurement for S³AI Neuroanatomy
//!
//! Comprehensive benchmarking suite for all brain regions.
//! Measures throughput, latency, and overhead for critical operations.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Brain Region: Corpus Callosum (Aggregation & Analysis)

const std = @import("std");
const array_list = std.array_list;
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");
const telemetry = @import("telemetry.zig");
const amygdala = @import("amygdala.zig");
const brain = @import("brain.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    avg_ns: f64,
    ops_per_sec: f64,

    // Percentiles (in nanoseconds)
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
    p999_ns: u64,

    pub fn formatOps(self: *const BenchmarkResult, writer: anytype) !void {
        if (self.ops_per_sec >= 1_000_000_000) {
            try writer.print("{d:.2} GOP/s", .{self.ops_per_sec / 1_000_000_000.0});
        } else if (self.ops_per_sec >= 1_000_000) {
            try writer.print("{d:.2} MOP/s", .{self.ops_per_sec / 1_000_000.0});
        } else if (self.ops_per_sec >= 1_000) {
            try writer.print("{d:.2} kOP/s", .{self.ops_per_sec / 1_000.0});
        } else {
            try writer.print("{d:.2} OP/s", .{self.ops_per_sec});
        }
    }

    pub fn formatLatency(self: *const BenchmarkResult, writer: anytype) !void {
        if (self.avg_ns >= 1_000_000) {
            try writer.print("{d:.2} ms", .{self.avg_ns / 1_000_000.0});
        } else if (self.avg_ns >= 1_000) {
            try writer.print("{d:.2} μs", .{self.avg_ns / 1_000.0});
        } else {
            try writer.print("{d:.2} ns", .{self.avg_ns});
        }
    }
};

pub const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    results: array_list.Managed(BenchmarkResult),
    comparisons: array_list.Managed(Comparison),

    pub const Comparison = struct {
        name: []const u8,
        before: f64,
        after: f64,
        change_percent: f32,
        improved: bool,
    };

    pub fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return BenchmarkSuite{
            .allocator = allocator,
            .results = array_list.Managed(BenchmarkResult).init(allocator),
            .comparisons = array_list.Managed(Comparison).init(allocator),
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        for (self.results.items) |*r| {
            self.allocator.free(r.name);
        }
        self.results.deinit();
        for (self.comparisons.items) |*c| {
            self.allocator.free(c.name);
        }
        self.comparisons.deinit();
    }

    /// Run all brain benchmarks
    pub fn runAll(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        try self.benchmarkTaskClaimThroughput(config);
        try self.benchmarkTaskReleaseThroughput(config);
        try self.benchmarkEventBusPublish(config);
        try self.benchmarkEventBusPoll(config);
        try self.benchmarkBackoffCalculation(config);
        try self.benchmarkHealthCheck(config);
        try self.benchmarkTelemetryRecord(config);
        try self.benchmarkTelemetryAggregation(config);
        try self.benchmarkAgentCoordination(config);
        try self.benchmarkAmygdalaSalience(config);
    }

    /// Benchmark: Task claim throughput (operations per second)
    pub fn benchmarkTaskClaimThroughput(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var registry = basal_ganglia.Registry.init(allocator);
        defer registry.deinit();

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);

            const start = std.time.nanoTimestamp();
            _ = try registry.claim(allocator, task_id, "agent-001", 300000);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            self.allocator,
            "Task Claim Throughput",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Task release throughput (complete operations)
    pub fn benchmarkTaskReleaseThroughput(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var registry = basal_ganglia.Registry.init(allocator);
        defer registry.deinit();

        // Pre-populate with claims
        const num_tasks = config.iterations;
        var i: u64 = 0;
        while (i < num_tasks) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);
            _ = try registry.claim(allocator, task_id, "agent-001", 300000);
        }

        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(num_tasks, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        i = 0;
        while (i < num_tasks) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);

            const start = std.time.nanoTimestamp();
            _ = registry.complete(task_id, "agent-001");
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Task Release Throughput",
            num_tasks,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Event bus publish latency
    pub fn benchmarkEventBusPublish(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var bus = reticular_formation.EventBus.init(allocator);
        defer bus.deinit();

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);

            const event_data = reticular_formation.EventData{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-001",
                },
            };

            const start = std.time.nanoTimestamp();
            try bus.publish(.task_claimed, event_data);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Event Bus Publish",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Event bus poll latency
    pub fn benchmarkEventBusPoll(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var bus = reticular_formation.EventBus.init(allocator);
        defer bus.deinit();

        // Pre-populate with events
        const num_events = @min(config.iterations, 1_000);
        var i: u64 = 0;
        while (i < num_events) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);

            const event_data = reticular_formation.EventData{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-001",
                },
            };
            try bus.publish(.task_claimed, event_data);
        }

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            const events = try bus.poll(0, allocator, 100);
            defer {
                allocator.free(events);
            }
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Event Bus Poll",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Backoff calculation speed
    pub fn benchmarkBackoffCalculation(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        const policy = locus_coeruleus.BackoffPolicy.init();
        const iterations = config.iterations * 10; // More iterations since it's fast
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const attempt = @as(u32, @intCast(i % 100));

            const start = std.time.nanoTimestamp();
            _ = policy.nextDelay(attempt);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Backoff Calculation",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Health check overhead
    pub fn benchmarkHealthCheck(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var coord = try brain.AgentCoordination.init(allocator);
        defer {
            reticular_formation.resetGlobal(allocator);
            basal_ganglia.resetGlobal(allocator);
            coord.deinit();
        }

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = coord.healthCheck();
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Health Check",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Telemetry record overhead
    pub fn benchmarkTelemetryRecord(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var tel = telemetry.BrainTelemetry.init(allocator, 10_000);
        defer tel.deinit();

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const point = telemetry.TelemetryPoint{
                .timestamp = std.time.milliTimestamp(),
                .active_claims = @as(usize, @intCast(i % 100)),
                .events_published = i * 10,
                .events_buffered = @as(usize, @intCast(i % 1000)),
                .health_score = 90.0,
            };

            const start = std.time.nanoTimestamp();
            try tel.record(point);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Telemetry Record",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Telemetry aggregation (avg health, trend)
    pub fn benchmarkTelemetryAggregation(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var tel = telemetry.BrainTelemetry.init(allocator, 10_000);
        defer tel.deinit();

        // Pre-populate with telemetry points
        const num_points = 1000;
        var i: u64 = 0;
        while (i < num_points) : (i += 1) {
            const point = telemetry.TelemetryPoint{
                .timestamp = @as(i64, @intCast(i)),
                .active_claims = @as(usize, @intCast(i % 100)),
                .events_published = i * 10,
                .events_buffered = @as(usize, @intCast(i % 1000)),
                .health_score = 90.0 + @as(f32, @floatFromInt(i % 20)),
            };
            try tel.record(point);
        }

        const iterations = config.iterations;
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        i = 0;
        while (i < iterations) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = tel.avgHealth(100);
            _ = tel.trend(100);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Telemetry Aggregation",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Full agent coordination cycle
    pub fn benchmarkAgentCoordination(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;
        var coord = try brain.AgentCoordination.init(allocator);
        defer {
            reticular_formation.resetGlobal(allocator);
            basal_ganglia.resetGlobal(allocator);
            coord.deinit();
        }

        const iterations = @min(config.iterations, 10_000); // Fewer since it's slower
        var latencies = try array_list.Managed(u64).initCapacity(allocator, iterations);
        defer latencies.deinit();

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "coord-task-{d}", .{i});
            defer allocator.free(task_id);

            const start = std.time.nanoTimestamp();

            // Full coordination cycle: claim -> heartbeat -> complete
            _ = try coord.claimTask(task_id, "agent-coord-bench");
            _ = coord.refreshHeartbeat(task_id, "agent-coord-bench");
            try coord.completeTask(task_id, "agent-coord-bench", 100);

            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            try latencies.append(latency);
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Agent Coordination Cycle",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Benchmark: Amygdala salience calculation speed
    pub fn benchmarkAmygdalaSalience(self: *BenchmarkSuite, config: BenchmarkConfig) !void {
        const allocator = self.allocator;

        const iterations = config.iterations * 100; // More iterations since it's fast
        var latencies = try array_list.Managed(u64).initCapacity(allocator, @min(iterations, 100_000));
        defer latencies.deinit();

        // Test data for different salience scenarios
        const test_cases = [_]struct {
            task_id: []const u8,
            realm: []const u8,
            priority: []const u8,
        }{
            .{ .task_id = "urgent-critical-security-fix", .realm = "dukh", .priority = "critical" },
            .{ .task_id = "regular-maintenance-task", .realm = "sattva", .priority = "low" },
            .{ .task_id = "performance-optimization", .realm = "razum", .priority = "high" },
            .{ .task_id = "bugfix-ui-issue", .realm = "sattva", .priority = "medium" },
            .{ .task_id = "critical-data-corruption", .realm = "dukh", .priority = "high" },
        };

        const start_total = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const test_case = test_cases[i % test_cases.len];

            const start = std.time.nanoTimestamp();
            _ = amygdala.Amygdala.analyzeTask(test_case.task_id, test_case.realm, test_case.priority);
            const end = std.time.nanoTimestamp();

            const latency = @as(u64, @intCast(end - start));
            if (latencies.items.len < 100_000) {
                try latencies.append(latency);
            }
        }

        const end_total = std.time.nanoTimestamp();
        const total_ns = @as(u64, @intCast(end_total - start_total));

        const result = try BenchmarkSuite.computeResult(
            allocator,
            "Amygdala Salience",
            iterations,
            total_ns,
            latencies.items,
        );
        try self.results.append(result);
    }

    /// Compute benchmark statistics from raw latency samples
    pub fn computeResult(
        allocator: std.mem.Allocator,
        name: []const u8,
        iterations: u64,
        total_ns: u64,
        latencies: []const u64,
    ) !BenchmarkResult {
        if (latencies.len == 0) {
            return BenchmarkResult{
                .name = try allocator.dupe(u8, name),
                .iterations = iterations,
                .total_ns = total_ns,
                .min_ns = 0,
                .max_ns = 0,
                .avg_ns = 0,
                .ops_per_sec = if (total_ns > 0) @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0) else 0,
                .p50_ns = 0,
                .p95_ns = 0,
                .p99_ns = 0,
                .p999_ns = 0,
            };
        }

        // Sort for percentile calculation
        const sorted = try allocator.dupe(u64, latencies);
        defer allocator.free(sorted);
        std.mem.sort(u64, sorted, {}, comptime std.sort.asc(u64));

        const min_ns = sorted[0];
        const max_ns = sorted[sorted.len - 1];

        var sum: u64 = 0;
        for (sorted) |lat| sum += lat;
        const avg_ns = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(sorted.len));

        const p50_ns = percentile(sorted, 50.0);
        const p95_ns = percentile(sorted, 95.0);
        const p99_ns = percentile(sorted, 99.0);
        const p999_ns = percentile(sorted, 99.9);

        const ops_per_sec = if (total_ns > 0)
            @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0)
        else
            0;

        return BenchmarkResult{
            .name = try allocator.dupe(u8, name),
            .iterations = iterations,
            .total_ns = total_ns,
            .min_ns = min_ns,
            .max_ns = max_ns,
            .avg_ns = avg_ns,
            .ops_per_sec = ops_per_sec,
            .p50_ns = p50_ns,
            .p95_ns = p95_ns,
            .p99_ns = p99_ns,
            .p999_ns = p999_ns,
        };
    }

    /// Print benchmark results in a formatted table
    pub fn printReport(self: *const BenchmarkSuite, writer: anytype) !void {
        try writer.writeAll("\n╔════════════════════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║  S³AI BRAIN BENCHMARK RESULTS — v1.0                                    ║\n");
        try writer.writeAll("╠════════════════════════════════════════════════════════════════════════════╣\n");
        try writer.writeAll("║  Benchmark                    │ Throughput  │ Latency (avg) │ P99      ║\n");
        try writer.writeAll("╠════════════════════════════════════════════════════════════════════════════╣\n");

        for (self.results.items) |result| {
            try writer.print("║  %-28s │ ", .{result.name});
            try result.formatOps(writer);
            try writer.print(" │ ", .{});
            try result.formatLatency(writer);
            try writer.print(" │ ", .{});
            if (result.p99_ns >= 1_000) {
                try writer.print("{d:.2} μs", .{result.p99_ns / 1_000.0});
            } else {
                try writer.print("{d} ns", .{result.p99_ns});
            }
            try writer.writeAll(" ║\n");
        }

        try writer.writeAll("╚════════════════════════════════════════════════════════════════════════════╝\n\n");
        try writer.writeAll("φ² + 1/φ² = 3 = TRINITY\n\n");
    }

    /// Print detailed percentiles for a specific benchmark
    pub fn printPercentiles(self: *const BenchmarkSuite, writer: anytype, benchmark_name: []const u8) !void {
        for (self.results.items) |result| {
            if (std.mem.eql(u8, result.name, benchmark_name)) {
                try writer.print("\n{s} — Detailed Percentiles{s}\n", .{ result.name, "─" ** 40 });
                try writer.print("  Min:     ", .{});
                try self.formatNs(writer, result.min_ns);
                try writer.print("\n", .{});

                try writer.print("  P50:     ", .{});
                try self.formatNs(writer, result.p50_ns);
                try writer.print("\n", .{});

                try writer.print("  P95:     ", .{});
                try self.formatNs(writer, result.p95_ns);
                try writer.print("\n", .{});

                try writer.print("  P99:     ", .{});
                try self.formatNs(writer, result.p99_ns);
                try writer.print("\n", .{});

                try writer.print("  P99.9:   ", .{});
                try self.formatNs(writer, result.p999_ns);
                try writer.print("\n", .{});

                try writer.print("  Max:     ", .{});
                try self.formatNs(writer, result.max_ns);
                try writer.print("\n", .{});

                try writer.print("\nIterations: {d}\n", .{result.iterations});
                try writer.print("Total time: ", .{});
                try self.formatDuration(writer, result.total_ns);
                try writer.print("\n", .{});
                return;
            }
        }
        try writer.print("Benchmark '{s}' not found\n", .{benchmark_name});
    }

    fn formatNs(self: *const BenchmarkSuite, writer: anytype, ns: u64) !void {
        _ = self;
        if (ns >= 1_000_000) {
            try writer.print("{d:.2} ms", .{ns / 1_000_000.0});
        } else if (ns >= 1_000) {
            try writer.print("{d:.2} μs", .{ns / 1_000.0});
        } else {
            try writer.print("{d} ns", .{ns});
        }
    }

    fn formatDuration(self: *const BenchmarkSuite, writer: anytype, ns: u64) !void {
        _ = self;
        if (ns >= 1_000_000_000) {
            try writer.print("{d:.2} s", .{ns / 1_000_000_000.0});
        } else if (ns >= 1_000_000) {
            try writer.print("{d:.2} ms", .{ns / 1_000_000.0});
        } else {
            try writer.print("{d} μs", .{ns / 1_000});
        }
    }

    /// Save results to JSON file
    pub fn saveJson(self: *const BenchmarkSuite, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Build JSON string in memory first (simpler than dealing with new Writer API)
        var json_buffer = array_list.Managed(u8).init(self.allocator);
        defer json_buffer.deinit();

        try json_buffer.appendSlice("{\"brain_benchmarks\":[\n");

        for (self.results.items, 0..) |result, i| {
            if (i > 0) try json_buffer.appendSlice(",\n");
            const json_line = try std.fmt.allocPrint(self.allocator, "  {{\"name\":\"{s}\",\"iterations\":{d},\"total_ns\":{d},\"min_ns\":{d},\"max_ns\":{d},\"avg_ns\":{d:.2},\"ops_per_sec\":{d:.2},\"p50_ns\":{d},\"p95_ns\":{d},\"p99_ns\":{d},\"p999_ns\":{d}}}", .{
                result.name,
                result.iterations,
                result.total_ns,
                result.min_ns,
                result.max_ns,
                result.avg_ns,
                result.ops_per_sec,
                result.p50_ns,
                result.p95_ns,
                result.p99_ns,
                result.p999_ns,
            });
            defer self.allocator.free(json_line);
            try json_buffer.appendSlice(json_line);
        }

        try json_buffer.appendSlice("\n]}\n");
        try file.writeAll(json_buffer.items);
    }

    /// Load previous results for comparison
    pub fn loadBaseline(allocator: std.mem.Allocator, path: []const u8) !?*BenchmarkSuite {
        const file = std.fs.cwd().openFile(path, .{}) catch return null;
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_000_000);
        defer allocator.free(content);

        // Parse JSON (simplified)
        const suite = try allocator.create(BenchmarkSuite);
        suite.* = BenchmarkSuite.init(allocator);
        errdefer {
            suite.deinit();
            allocator.destroy(suite);
        }

        // Extract benchmark data from JSON
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "\"name\":")) |_| {
                // Parse line (simplified - in production use proper JSON parser)
                var iter = std.mem.splitScalar(u8, line, '"');
                _ = iter.next(); // skip {
                _ = iter.next(); // skip name:
                const name = iter.next() orelse continue;
                _ = iter.next(); // skip ",
                _ = iter.next(); // skip iterations:
                const iter_start = iter.rest();
                const iter_end = std.mem.indexOf(u8, iter_start, ",") orelse iter_start.len;
                const iterations_str = iter_start[0..iter_end];
                const iterations = try std.fmt.parseInt(u64, iterations_str, 10);

                // Create a minimal result for comparison
                const result = BenchmarkResult{
                    .name = try allocator.dupe(u8, name),
                    .iterations = iterations,
                    .total_ns = 0,
                    .min_ns = 0,
                    .max_ns = 0,
                    .avg_ns = 0,
                    .ops_per_sec = 0,
                    .p50_ns = 0,
                    .p95_ns = 0,
                    .p99_ns = 0,
                    .p999_ns = 0,
                };
                try suite.results.append(result);
            }
        }

        return suite;
    }

    /// Compare current results with baseline
    pub fn compareWithBaseline(self: *BenchmarkSuite, baseline: *const BenchmarkSuite) !void {
        for (self.results.items) |current| {
            for (baseline.results.items) |prev| {
                if (std.mem.eql(u8, current.name, prev.name)) {
                    const change_percent = if (prev.ops_per_sec > 0)
                        @as(f32, @floatCast((current.ops_per_sec - prev.ops_per_sec) / prev.ops_per_sec * 100.0))
                    else
                        0;

                    try self.comparisons.append(.{
                        .name = try self.allocator.dupe(u8, current.name),
                        .before = prev.ops_per_sec,
                        .after = current.ops_per_sec,
                        .change_percent = change_percent,
                        .improved = change_percent > 0,
                    });
                }
            }
        }
    }

    /// Print comparison report
    pub fn printComparison(self: *const BenchmarkSuite, writer: anytype) !void {
        if (self.comparisons.items.len == 0) {
            try writer.writeAll("No baseline data available for comparison.\n");
            return;
        }

        try writer.writeAll("\n╔════════════════════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║  BRAIN BENCHMARK COMPARISON REPORT                                      ║\n");
        try writer.writeAll("╠════════════════════════════════════════════════════════════════════════════╣\n");
        try writer.writeAll("║  Benchmark                    │ Before       │ After        │ Change  ║\n");
        try writer.writeAll("╠════════════════════════════════════════════════════════════════════════════╣\n");

        for (self.comparisons.items) |comp| {
            const color = if (comp.improved) "↑" else "↓";

            try writer.print("║  %-28s │ ", .{comp.name});
            if (comp.before >= 1_000_000) {
                try writer.print("{d:.2} MOP/s │ ", .{comp.before / 1_000_000.0});
            } else {
                try writer.print("{d:.2} kOP/s │ ", .{comp.before / 1_000.0});
            }

            if (comp.after >= 1_000_000) {
                try writer.print("{d:.2} MOP/s │ ", .{comp.after / 1_000_000.0});
            } else {
                try writer.print("{d:.2} kOP/s │ ", .{comp.after / 1_000.0});
            }

            try writer.print("{s}{s}{d:.1}%{s} ║\n", .{
                if (comp.improved) "\x1b[32m" else "\x1b[31m",
                color,
                comp.change_percent,
                "\x1b[0m",
            });
        }

        try writer.writeAll("╚════════════════════════════════════════════════════════════════════════════╝\n\n");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate percentile from sorted array
fn percentile(sorted: []const u64, p: f64) u64 {
    if (sorted.len == 0) return 0;
    const idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * p / 100.0));
    return sorted[@min(idx, sorted.len - 1)];
}

/// Benchmark configuration
pub const BenchmarkConfig = struct {
    iterations: u64 = 10_000,
    warmup_iterations: u64 = 1_000,
    verbose: bool = false,

    pub fn parse(args: []const []const u8) BenchmarkConfig {
        var config = BenchmarkConfig{};
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--iterations") and i + 1 < args.len) {
                config.iterations = std.fmt.parseInt(u64, args[i + 1], 10) catch 10_000;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--verbose") or std.mem.eql(u8, args[i], "-v")) {
                config.verbose = true;
            }
        }
        return config;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BenchmarkSuite initialization" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    try std.testing.expectEqual(@as(usize, 0), suite.results.items.len);
    try std.testing.expectEqual(@as(usize, 0), suite.comparisons.items.len);
}

test "percentile calculation" {
    const data = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    try std.testing.expectEqual(@as(u64, 5), percentile(&data, 50.0));
    try std.testing.expectEqual(@as(u64, 9), percentile(&data, 90.0));
    try std.testing.expectEqual(@as(u64, 10), percentile(&data, 99.0));
}

test "benchmark task claim throughput" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{ .iterations = 100 };
    try suite.benchmarkTaskClaimThroughput(config);

    try std.testing.expectEqual(@as(usize, 1), suite.results.items.len);
    const result = suite.results.items[0];
    try std.testing.expect(result.ops_per_sec > 0);
    try std.testing.expect(result.iterations == 100);
}

test "benchmark backoff calculation" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{ .iterations = 1000 };
    try suite.benchmarkBackoffCalculation(config);

    const result = suite.results.items[0];
    try std.testing.expect(result.ops_per_sec > 1_000_000); // Should be very fast
}

test "BenchmarkResult formatting" {
    const allocator = std.testing.allocator;
    const result = BenchmarkResult{
        .name = "test",
        .iterations = 1000,
        .total_ns = 1_000_000_000,
        .min_ns = 100,
        .max_ns = 10_000,
        .avg_ns = 1_000,
        .ops_per_sec = 1_000_000,
        .p50_ns = 800,
        .p95_ns = 2_000,
        .p99_ns = 5_000,
        .p999_ns = 8_000,
    };
    defer allocator.free(result.name);

    var buffer: [100]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try result.formatOps(stream.writer());
    try std.testing.expect(std.mem.indexOf(u8, &buffer, "MOP/s") != null);
}

test "BenchmarkConfig parse" {
    const args = [_][]const u8{ "--iterations", "50000", "--verbose" };
    const config = BenchmarkConfig.parse(&args);

    try std.testing.expectEqual(@as(u64, 50000), config.iterations);
    try std.testing.expect(config.verbose);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK ACCURACY TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "benchmark accuracy: nanoTimestamp precision" {
    // Verify that std.time.nanoTimestamp() provides nanosecond precision
    const t1 = std.time.nanoTimestamp();
    std.Thread.sleep(1_000_000); // Sleep 1ms
    const t2 = std.time.nanoTimestamp();

    const elapsed_ns = t2 - t1;
    // Should be at least 1ms (1,000,000 ns) with some tolerance for scheduler
    try std.testing.expect(elapsed_ns >= 900_000);
    try std.testing.expect(elapsed_ns <= 10_000_000); // But not too long
}

test "benchmark accuracy: percentile edge cases" {
    // Test percentile with edge cases
    const empty = [_]u64{};
    try std.testing.expectEqual(@as(u64, 0), percentile(&empty, 50.0));

    const single = [_]u64{100};
    try std.testing.expectEqual(@as(u64, 100), percentile(&single, 0.0));
    try std.testing.expectEqual(@as(u64, 100), percentile(&single, 50.0));
    try std.testing.expectEqual(@as(u64, 100), percentile(&single, 100.0));

    const two = [_]u64{ 10, 20 };
    try std.testing.expectEqual(@as(u64, 10), percentile(&two, 50.0)); // First element at P50
    try std.testing.expectEqual(@as(u64, 20), percentile(&two, 100.0)); // Last at P100
}

test "benchmark accuracy: percentile interpolation" {
    // Test that percentiles are correctly calculated
    const data = [_]u64{ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 };

    // P50 should be around the middle (500-600 range for 10 elements)
    const p50 = percentile(&data, 50.0);
    try std.testing.expect(p50 >= 500 and p50 <= 600);

    // P90 should be near the end (900-1000)
    const p90 = percentile(&data, 90.0);
    try std.testing.expect(p90 >= 900);

    // P99 should be the max
    const p99 = percentile(&data, 99.0);
    try std.testing.expectEqual(@as(u64, 1000), p99);
}

test "benchmark accuracy: operations per second calculation" {
    const allocator = std.testing.allocator;

    // Simulate a benchmark that took exactly 1 second for 1000 operations
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const result = try BenchmarkSuite.computeResult(
        allocator,
        "test-ops",
        1000,
        1_000_000_000, // Exactly 1 second
        &[_]u64{ 1000, 2000, 3000, 4000, 5000 },
    );

    // Should be very close to 1000 ops/sec
    try std.testing.expectApproxEqRel(@as(f64, 1000.0), result.ops_per_sec, 0.01);

    allocator.free(result.name);
}

test "benchmark accuracy: latency percentiles match sorted data" {
    const allocator = std.testing.allocator;

    const latencies = [_]u64{ 100, 250, 500, 750, 1000, 2000, 5000 };
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const result = try BenchmarkSuite.computeResult(
        allocator,
        "test-percentiles",
        100,
        10_000_000,
        &latencies,
    );

    // Verify percentiles match the sorted data
    try std.testing.expectEqual(@as(u64, 100), result.min_ns);
    try std.testing.expectEqual(@as(u64, 5000), result.max_ns);
    try std.testing.expectEqual(@as(u64, 750), result.p50_ns); // P50 = median

    allocator.free(result.name);
}

test "benchmark accuracy: event bus publish throughput is measurable" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{ .iterations = 1000 };
    try suite.benchmarkEventBusPublish(config);

    const result = suite.results.items[0];

    // Should have measured at least some operations
    try std.testing.expect(result.iterations == 1000);

    // Total time should be reasonable (between 1ms and 10 seconds)
    try std.testing.expect(result.total_ns >= 1_000_000);
    try std.testing.expect(result.total_ns <= 10_000_000_000);

    // Should have captured latencies
    try std.testing.expect(result.min_ns > 0);
    try std.testing.expect(result.max_ns >= result.min_ns);
}

test "benchmark accuracy: task claim contention handling" {
    const allocator = std.testing.allocator;

    // Test that duplicate claims are properly rejected
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    const task_id = "contention-test-task";
    const agent1 = "agent-001";
    const agent2 = "agent-002";

    // First claim should succeed
    const claim1 = try registry.claim(allocator, task_id, agent1, 300000);
    try std.testing.expect(claim1);

    // Second claim should fail
    const claim2 = try registry.claim(allocator, task_id, agent2, 300000);
    try std.testing.expect(!claim2);

    // Heartbeat from first agent should succeed
    const heartbeat1 = registry.heartbeat(task_id, agent1);
    try std.testing.expect(heartbeat1);

    // Heartbeat from second agent should fail
    const heartbeat2 = registry.heartbeat(task_id, agent2);
    try std.testing.expect(!heartbeat2);
}

test "benchmark accuracy: backoff calculation produces valid sequence" {
    const policy = locus_coeruleus.BackoffPolicy{
        .initial_ms = 1000,
        .max_ms = 60000,
        .multiplier = 2.0,
        .strategy = .exponential,
        .jitter_type = .none,
    };

    // Test exponential backoff sequence
    const d0 = policy.nextDelay(0);
    const d1 = policy.nextDelay(1);
    const d2 = policy.nextDelay(2);
    const d3 = policy.nextDelay(3);

    try std.testing.expectEqual(@as(u64, 1000), d0);
    try std.testing.expectEqual(@as(u64, 2000), d1);
    try std.testing.expectEqual(@as(u64, 4000), d2);
    try std.testing.expectEqual(@as(u64, 8000), d3);

    // Each should be double the previous
    try std.testing.expectEqual(d1, d0 * 2);
    try std.testing.expectEqual(d2, d1 * 2);
    try std.testing.expectEqual(d3, d2 * 2);
}

test "benchmark accuracy: telemetry aggregation correctness" {
    const allocator = std.testing.allocator;
    var tel = telemetry.BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = std.time.milliTimestamp();

    // Record known health scores
    try tel.record(.{ .timestamp = now, .active_claims = 10, .events_published = 100, .events_buffered = 5, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 8, .events_published = 120, .events_buffered = 3, .health_score = 90.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 5, .events_published = 140, .events_buffered = 1, .health_score = 100.0 });

    // Average should be exactly 90.0
    const avg = tel.avgHealth(10);
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), avg, 0.01);

    // Trend should be improving (70 -> 90 -> 100)
    const trend = tel.trend(10);
    try std.testing.expectEqual(trend, .improving);
}

test "benchmark accuracy: full suite completes without errors" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{
        .iterations = 100, // Small number for test speed
        .verbose = false,
    };

    // Run all benchmarks - should complete without errors
    try suite.runAll(config);

    // Should have results for all benchmarks (including Amygdala)
    try std.testing.expect(suite.results.items.len >= 9);

    // All results should have valid metrics
    for (suite.results.items) |result| {
        try std.testing.expect(result.iterations > 0);
        try std.testing.expect(result.ops_per_sec > 0);
        try std.testing.expect(result.avg_ns >= 0);
    }
}

test "benchmark amygdala salience calculation" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{ .iterations = 1000 };
    try suite.benchmarkAmygdalaSalience(config);

    const result = suite.results.items[0];
    try std.testing.expect(result.ops_per_sec > 0); // Should be very fast
    try std.testing.expect(std.mem.eql(u8, "Amygdala Salience", result.name));
}

test "benchmark accuracy: save and load baseline preserves data" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{ .iterations = 50 };
    try suite.benchmarkBackoffCalculation(config);

    // Save to temp file
    const tmp_path = "test_baseline.json";
    defer {
        std.fs.cwd().deleteFile(tmp_path) catch {};
    }

    try suite.saveJson(tmp_path);

    // Load and verify
    const loaded = try BenchmarkSuite.loadBaseline(allocator, tmp_path);
    if (loaded) |baseline| {
        defer {
            baseline.deinit();
            allocator.destroy(baseline);
        }
        try std.testing.expect(baseline.results.items.len > 0);
    } else {
        try std.testing.expect(false); // Should have loaded something
    }
}

test "benchmark accuracy: comparison calculates correct percentage" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    var baseline = BenchmarkSuite.init(allocator);
    defer baseline.deinit();

    // Create baseline result
    const baseline_result = try BenchmarkSuite.computeResult(
        allocator,
        "test-comparison",
        1000,
        1_000_000_000,
        &[_]u64{1000},
    );
    try baseline.results.append(baseline_result);

    // Create current result (2x faster)
    const current_result = try BenchmarkSuite.computeResult(
        allocator,
        "test-comparison",
        1000,
        500_000_000, // Half the time = 2x throughput
        &[_]u64{500},
    );
    try suite.results.append(current_result);

    // Compare
    try suite.compareWithBaseline(&baseline);

    try std.testing.expectEqual(@as(usize, 1), suite.comparisons.items.len);
    const comp = suite.comparisons.items[0];

    // Should show ~100% improvement
    try std.testing.expect(comp.improved);
    try std.testing.expect(comp.change_percent > 90 and comp.change_percent < 110);

    allocator.free(baseline_result.name);
    allocator.free(current_result.name);
}

test "benchmark amygdala salience included in suite" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const config = BenchmarkConfig{
        .iterations = 10, // Very small for quick test
        .verbose = false,
    };

    try suite.runAll(config);

    // Check that Amygdala benchmark was run
    var found_amygdala = false;
    for (suite.results.items) |result| {
        if (std.mem.eql(u8, "Amygdala Salience", result.name)) {
            found_amygdala = true;
            try std.testing.expect(result.ops_per_sec > 0);
        }
    }
    try std.testing.expect(found_amygdala);
}
