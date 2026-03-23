//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! S³AI BRAIN PERFORMANCE DASHBOARD — v1.0
//!
//! Unified performance monitoring dashboard for all brain regions.
//! Provides real-time metrics tracking, performance baselines, SLA monitoring,
//! and visual indicators (sparklines, heatmaps) for entire S³AI brain.
//!
//! Features:
//! - Real-time performance tracking (latency, throughput, memory usage)
//! - Performance comparison reports (before/after optimization)
//! - Visual performance indicators (sparklines, heatmaps)
//! - Performance baselines and SLA targets
//! - Historical performance data with trend analysis
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// Import brain region modules for metric collection
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");
const visualization = @import("visualization.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Performance metric snapshot for a single operation
pub const PerformanceSnapshot = struct {
    /// Timestamp of snapshot (nanoseconds since epoch)
    timestamp: i64,
    /// Operation name (e.g., "task_claim", "event_publish")
    operation: []const u8,
    /// Brain region name
    region: []const u8,
    /// Latency in nanoseconds
    latency_ns: u64,
    /// Memory usage in bytes (optional)
    memory_bytes: ?u64,
    /// Success/failure status
    success: bool,
    /// Additional metadata
    metadata: std.StringHashMap([]const u8),

    /// Initialize a new snapshot
    pub fn init(allocator: std.mem.Allocator, operation: []const u8, region: []const u8) PerformanceSnapshot {
        return PerformanceSnapshot{
            .timestamp = std.time.nanoTimestamp(),
            .operation = operation,
            .region = region,
            .latency_ns = 0,
            .memory_bytes = null,
            .success = true,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *PerformanceSnapshot) void {
        var iter = self.metadata.iterator();
        while (iter.next()) |entry| {
            self.metadata.allocator.free(entry.key_ptr.*);
            self.metadata.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }
};

/// Aggregated performance statistics for a metric
pub const PerformanceStats = struct {
    /// Metric name
    name: []const u8,
    /// Brain region
    region: []const u8,
    /// Total operations measured
    total_ops: u64,
    /// Successful operations
    success_count: u64,
    /// Failed operations
    failure_count: u64,
    /// Total latency (sum of all latencies)
    total_latency_ns: u64,
    /// Minimum latency
    min_latency_ns: u64,
    /// Maximum latency
    max_latency_ns: u64,
    /// Last update timestamp
    last_update: i64,
    /// P50, P95, P99 latencies
    p50_ns: u64,
    p95_ns: u64,
    p99_ns: u64,
    /// Throughput (ops/sec)
    throughput_ops_per_sec: f64,
    /// Error rate (0-1)
    error_rate: f32,

    /// Create empty stats
    pub fn empty(name: []const u8, region: []const u8) PerformanceStats {
        return PerformanceStats{
            .name = name,
            .region = region,
            .total_ops = 0,
            .success_count = 0,
            .failure_count = 0,
            .total_latency_ns = 0,
            .min_latency_ns = std.math.maxInt(u64),
            .max_latency_ns = 0,
            .last_update = std.time.milliTimestamp(),
            .p50_ns = 0,
            .p95_ns = 0,
            .p99_ns = 0,
            .throughput_ops_per_sec = 0,
            .error_rate = 0,
        };
    }

    /// Get average latency in nanoseconds
    pub fn avgLatency(self: *const PerformanceStats) f64 {
        if (self.total_ops == 0) return 0;
        return @as(f64, @floatFromInt(self.total_latency_ns)) / @as(f64, @floatFromInt(self.total_ops));
    }

    /// Format latency with appropriate unit
    pub fn formatLatency(self: *const PerformanceStats, writer: anytype) !void {
        const avg = self.avgLatency();
        if (avg >= 1_000_000) {
            try writer.print("{d:.2} ms", .{avg / 1_000_000.0});
        } else if (avg >= 1_000) {
            try writer.print("{d:.2} us", .{avg / 1_000.0});
        } else {
            try writer.print("{d:.2} ns", .{avg});
        }
    }

    /// Format throughput with appropriate unit
    pub fn formatThroughput(self: *const PerformanceStats, writer: anytype) !void {
        if (self.throughput_ops_per_sec >= 1_000_000) {
            try writer.print("{d:.2} MOP/s", .{self.throughput_ops_per_sec / 1_000_000.0});
        } else if (self.throughput_ops_per_sec >= 1_000) {
            try writer.print("{d:.2} kOP/s", .{self.throughput_ops_per_sec / 1_000.0});
        } else {
            try writer.print("{d:.2} OP/s", .{self.throughput_ops_per_sec});
        }
    }

    /// Check if stats meet SLA target
    pub fn meetsSLA(self: *const PerformanceStats, sla: SLATarget) bool {
        // Check latency SLA
        if (sla.max_latency_ns) |max_lat| {
            if (self.p99_ns > max_lat) return false;
        }

        // Check throughput SLA
        if (sla.min_throughput_ops_per_sec) |min_throughput| {
            if (self.throughput_ops_per_sec < min_throughput) return false;
        }

        // Check error rate SLA
        if (sla.max_error_rate) |max_err| {
            if (self.error_rate > max_err) return false;
        }

        return true;
    }
};

/// SLA (Service Level Agreement) target for a metric
pub const SLATarget = struct {
    /// Maximum allowed P99 latency (nanoseconds)
    max_latency_ns: ?u64 = null,
    /// Minimum required throughput (ops/sec)
    min_throughput_ops_per_sec: ?f64 = null,
    /// Maximum allowed error rate (0-1)
    max_error_rate: ?f32 = null,
    /// Description of SLA
    description: []const u8 = "",

    /// Create SLA target
    pub fn init() SLATarget {
        return SLATarget{};
    }

    /// Set latency target
    pub fn withLatency(self: SLATarget, ns: u64) SLATarget {
        var copy = self;
        copy.max_latency_ns = ns;
        return copy;
    }

    /// Set throughput target
    pub fn withThroughput(self: SLATarget, ops: f64) SLATarget {
        var copy = self;
        copy.min_throughput_ops_per_sec = ops;
        return copy;
    }

    /// Set error rate target
    pub fn withErrorRate(self: SLATarget, rate: f32) SLATarget {
        var copy = self;
        copy.max_error_rate = rate;
        return copy;
    }
};

/// Predefined SLA targets for common brain operations
pub const SLA_PRESETS = struct {
    pub const TASK_CLAIM = SLATarget.init()
        .withLatency(1_000_000) // 1ms P99
        .withThroughput(10_000) // 10k OP/s
        .withErrorRate(0.01); // 1% max error rate

    pub const EVENT_PUBLISH = SLATarget.init()
        .withLatency(500_000) // 500us P99
        .withThroughput(100_000) // 100k OP/s
        .withErrorRate(0.001); // 0.1% max error rate

    pub const HEALTH_CHECK = SLATarget.init()
        .withLatency(100_000) // 100us P99
        .withThroughput(1_000) // 1k OP/s
        .withErrorRate(0.0); // 0% error rate for health checks

    pub const TELEMETRY_RECORD = SLATarget.init()
        .withLatency(200_000) // 200us P99
        .withThroughput(50_000) // 50k OP/s
        .withErrorRate(0.01); // 1% max error rate
};

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Circular buffer for performance history
pub const PerformanceHistory = struct {
    allocator: std.mem.Allocator,
    /// Metric name
    name: []const u8,
    /// Region name
    region: []const u8,
    /// Latency history (circular buffer)
    latencies: std.array_list.Managed(u64),
    /// Timestamp for each latency
    timestamps: std.array_list.Managed(i64),
    /// Maximum history size
    max_size: usize,
    /// Current index in circular buffer
    current_idx: usize,
    /// SLA target for this metric
    sla: SLATarget,

    /// Initialize history buffer
    pub fn init(allocator: std.mem.Allocator, name: []const u8, region: []const u8, max_size: usize) PerformanceHistory {
        // Use Managed ArrayList for proper allocator handling
        return PerformanceHistory{
            .allocator = allocator,
            .name = name,
            .region = region,
            .latencies = std.array_list.Managed(u64).init(allocator),
            .timestamps = std.array_list.Managed(i64).init(allocator),
            .max_size = max_size,
            .current_idx = 0,
            .sla = SLATarget.init(),
        };
    }

    pub fn deinit(self: *PerformanceHistory) void {
        self.latencies.deinit();
        self.timestamps.deinit();
    }

    /// Record a latency value
    pub fn record(self: *PerformanceHistory, latency_ns: u64) !void {
        const now = std.time.milliTimestamp();

        if (self.latencies.items.len < self.max_size) {
            // Buffer not full, just append
            try self.latencies.append(latency_ns);
            try self.timestamps.append(now);
        } else {
            // Buffer full, overwrite oldest (circular)
            self.latencies.items[self.current_idx] = latency_ns;
            self.timestamps.items[self.current_idx] = now;
            self.current_idx = (self.current_idx + 1) % self.max_size;
        }
    }

    /// Get current statistics
    pub fn getStats(self: *const PerformanceHistory) PerformanceStats {
        var stats = PerformanceStats.empty(self.name, self.region);

        if (self.latencies.items.len == 0) {
            return stats;
        }

        // Sort latencies for percentile calculation
        const sorted = self.allocator.alloc(u64, self.latencies.items.len) catch return stats;
        defer self.allocator.free(sorted);
        @memcpy(sorted, self.latencies.items);
        std.mem.sort(u64, sorted, {}, comptime std.sort.asc(u64));

        stats.total_ops = sorted.len;
        stats.total_latency_ns = 0;
        stats.min_latency_ns = sorted[0];
        stats.max_latency_ns = sorted[sorted.len - 1];

        for (sorted) |lat| {
            stats.total_latency_ns += lat;
        }

        // Calculate percentiles
        stats.p50_ns = percentile(sorted, 50.0);
        stats.p95_ns = percentile(sorted, 95.0);
        stats.p99_ns = percentile(sorted, 99.0);

        // Calculate throughput (using time window)
        if (self.timestamps.items.len >= 2) {
            const duration_ms = self.timestamps.items[self.timestamps.items.len - 1] - self.timestamps.items[0];
            if (duration_ms > 0) {
                const duration_sec = @as(f64, @floatFromInt(duration_ms)) / 1000.0;
                stats.throughput_ops_per_sec = @as(f64, @floatFromInt(sorted.len)) / duration_sec;
            }
        }

        return stats;
    }

    /// Get latencies as f32 array for visualization
    pub fn getLatenciesF32(self: *PerformanceHistory, allocator: std.mem.Allocator) ![]f32 {
        const result = try allocator.alloc(f32, self.latencies.items.len);
        for (self.latencies.items, 0..) |lat, i| {
            result[i] = @as(f32, @floatFromInt(lat));
        }
        return result;
    }

    /// Generate sparkline for this metric
    pub fn sparkline(self: *PerformanceHistory, allocator: std.mem.Allocator) ![]const u8 {
        if (self.latencies.items.len == 0) {
            return allocator.dupe(u8, "no data");
        }

        const data = try self.getLatenciesF32(allocator);
        defer allocator.free(data);

        return visualization.sparkline(allocator, data, .{
            .width = @min(40, self.latencies.items.len),
            .show_min_max = true,
            .color = false,
        });
    }
};

/// Calculate percentile from sorted array
fn percentile(sorted: []const u64, p: f64) u64 {
    if (sorted.len == 0) return 0;
    const idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(sorted.len - 1)) * p / 100.0));
    return sorted[@min(idx, sorted.len - 1)];
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

/// Main performance dashboard aggregating all brain region metrics
pub const PerformanceDashboard = struct {
    allocator: std.mem.Allocator,
    /// Metric histories indexed by "region:operation" key
    histories: std.StringHashMap(PerformanceHistory),
    /// Current stats snapshot
    current_stats: std.StringHashMap(PerformanceStats),
    /// Baseline stats for comparison
    baseline_stats: std.StringHashMap(PerformanceStats),
    /// SLA targets indexed by metric name
    slas: std.StringHashMap(SLATarget),
    /// Dashboard start time
    start_time: i64,
    /// Last update time
    last_update: i64,

    /// Initialize dashboard
    pub fn init(allocator: std.mem.Allocator) PerformanceDashboard {
        return PerformanceDashboard{
            .allocator = allocator,
            .histories = std.StringHashMap(PerformanceHistory).init(allocator),
            .current_stats = std.StringHashMap(PerformanceStats).init(allocator),
            .baseline_stats = std.StringHashMap(PerformanceStats).init(allocator),
            .slas = std.StringHashMap(SLATarget).init(allocator),
            .start_time = std.time.milliTimestamp(),
            .last_update = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *PerformanceDashboard) void {
        var hist_iter = self.histories.iterator();
        while (hist_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.histories.deinit();

        var stats_iter = self.current_stats.iterator();
        while (stats_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.region);
        }
        self.current_stats.deinit();

        var base_iter = self.baseline_stats.iterator();
        while (base_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.region);
        }
        self.baseline_stats.deinit();

        var sla_iter = self.slas.iterator();
        while (sla_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.slas.deinit();
    }

    /// Register a metric for tracking
    pub fn registerMetric(self: *PerformanceDashboard, region: []const u8, operation: []const u8, history_size: usize) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ region, operation });
        errdefer self.allocator.free(key);

        const history = PerformanceHistory.init(self.allocator, operation, region, history_size);
        try self.histories.put(key, history);
    }

    /// Set SLA for a metric
    pub fn setSLA(self: *PerformanceDashboard, metric_name: []const u8, sla: SLATarget) !void {
        const key = try self.allocator.dupe(u8, metric_name);
        try self.slas.put(key, sla);
    }

    /// Record a performance measurement
    pub fn record(self: *PerformanceDashboard, region: []const u8, operation: []const u8, latency_ns: u64) !void {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ region, operation });
        defer self.allocator.free(key);

        if (self.histories.getPtr(key)) |history| {
            try history.record(latency_ns);
        }

        self.last_update = std.time.milliTimestamp();
    }

    /// Get current stats for a metric
    pub fn getStats(self: *PerformanceDashboard, region: []const u8, operation: []const u8) !PerformanceStats {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ region, operation });
        defer self.allocator.free(key);

        if (self.histories.get(key)) |history| {
            return history.getStats();
        }

        return PerformanceStats.empty(operation, region);
    }

    /// Collect metrics from all brain regions
    pub fn collectFromBrain(self: *PerformanceDashboard) !void {
        const now = std.time.milliTimestamp();
        _ = now;

        // Collect Basal Ganglia metrics
        if (basal_ganglia.getGlobal(self.allocator)) |registry| {
            const claim_count = registry.claims.count();
            _ = claim_count;
            // Record mock claim latency (in real implementation, measure actual operation)
            // For now, we use a placeholder
        } else |_| {}

        // Collect Reticular Formation metrics
        if (reticular_formation.getGlobal(self.allocator)) |bus| {
            const stats = bus.getStats();
            _ = stats;
        } else |_| {}

        self.last_update = std.time.milliTimestamp();
    }

    /// Save current stats as baseline
    pub fn saveBaseline(self: *PerformanceDashboard) !void {
        var iter = self.histories.iterator();
        while (iter.next()) |entry| {
            const stats = entry.value_ptr.getStats();
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);

            const baseline = PerformanceStats{
                .name = try self.allocator.dupe(u8, stats.name),
                .region = try self.allocator.dupe(u8, stats.region),
                .total_ops = stats.total_ops,
                .success_count = stats.success_count,
                .failure_count = stats.failure_count,
                .total_latency_ns = stats.total_latency_ns,
                .min_latency_ns = stats.min_latency_ns,
                .max_latency_ns = stats.max_latency_ns,
                .last_update = stats.last_update,
                .p50_ns = stats.p50_ns,
                .p95_ns = stats.p95_ns,
                .p99_ns = stats.p99_ns,
                .throughput_ops_per_sec = stats.throughput_ops_per_sec,
                .error_rate = stats.error_rate,
            };

            try self.baseline_stats.put(key, baseline);
        }
    }

    /// Compare current stats with baseline
    pub const ComparisonResult = struct {
        metric_name: []const u8,
        region: []const u8,
        before_latency_ns: u64,
        after_latency_ns: u64,
        change_percent: f32,
        improved: bool,
        sla_met: bool,
    };

    pub fn compareWithBaseline(self: *PerformanceDashboard, allocator: std.mem.Allocator) ![]ComparisonResult {
        var results = std.array_list.Managed(ComparisonResult).init(allocator);

        var iter = self.histories.iterator();
        while (iter.next()) |entry| {
            const current = entry.value_ptr.getStats();

            if (self.baseline_stats.get(entry.key_ptr.*)) |baseline| {
                const change_pct: f32 = if (baseline.p99_ns > 0)
                    @as(f32, @floatFromInt(@as(i64, @intCast(current.p99_ns)) - @as(i64, @intCast(baseline.p99_ns)))) /
                        @as(f32, @floatFromInt(baseline.p99_ns)) * 100.0
                else
                    0;

                const improved = change_pct < 0; // Lower latency is better

                // Check SLA
                const sla = self.slas.get(entry.value_ptr.name);
                const sla_met = if (sla) |s| current.meetsSLA(s) else true;

                try results.append(ComparisonResult{
                    .metric_name = try allocator.dupe(u8, entry.value_ptr.name),
                    .region = try allocator.dupe(u8, entry.value_ptr.region),
                    .before_latency_ns = baseline.p99_ns,
                    .after_latency_ns = current.p99_ns,
                    .change_percent = change_pct,
                    .improved = improved,
                    .sla_met = sla_met,
                });
            }
        }

        return results.toOwnedSlice();
    }

    /// Format dashboard as ASCII table
    pub fn formatAscii(self: *const PerformanceDashboard, writer: anytype) !void {
        try writer.writeAll("\n\n");
        try writer.writeAll("S³AI PERFORMANCE DASHBOARD — v1.0\n");
        try writer.writeAll("═══════════════════════════════════════════════════\n\n");

        const uptime_ms = self.last_update - self.start_time;
        const uptime_sec = @as(f64, @floatFromInt(uptime_ms)) / 1000.0;

        try writer.print("Uptime: {d:.1}s  |  Metrics: {d:>3}  |  SLAs: {d:>3}\n", .{
            uptime_sec,
            self.histories.count(),
            self.slas.count(),
        });

        try writer.writeAll("═══════════════════════════════════════════════════\n\n");
        try writer.writeAll("Region              | Operation    | P99 Latency | Throughput  | SLA\n");
        try writer.writeAll("─────────────────────────────────────────────────────────────────────────\n");

        var iter = self.histories.iterator();
        while (iter.next()) |entry| {
            const stats = entry.value_ptr.getStats();
            if (stats.total_ops == 0) continue;

            const region_fmt = if (entry.value_ptr.region.len > 20) entry.value_ptr.region[0..20] else entry.value_ptr.region;
            const op_fmt = if (stats.name.len > 12) stats.name[0..12] else stats.name;

            try writer.print("{s:<20} | {s:<12} | ", .{ region_fmt, op_fmt });

            // Format P99 latency
            if (stats.p99_ns >= 1_000_000) {
                try writer.print("{d:>6.2} ms | ", .{@as(f64, @floatFromInt(stats.p99_ns)) / 1_000_000.0});
            } else if (stats.p99_ns >= 1_000) {
                try writer.print("{d:>6.2} us | ", .{@as(f64, @floatFromInt(stats.p99_ns)) / 1_000.0});
            } else {
                try writer.print("{d:>7} ns | ", .{stats.p99_ns});
            }

            // Format throughput
            try stats.formatThroughput(writer);

            try writer.writeAll(" | ");

            // Check SLA
            const sla = self.slas.get(stats.name);
            const sla_met = if (sla) |s| stats.meetsSLA(s) else true;
            try writer.print("{s}\n", .{if (sla_met) "PASS" else "FAIL"});
        }

        try writer.writeAll("═══════════════════════════════════════════════════\n\n");
        try writer.writeAll("phi^2 + 1/phi^2 = 3 = TRINITY\n\n");
    }

    /// Format comparison report
    pub fn formatComparison(self: *PerformanceDashboard, writer: anytype) !void {
        const results = try self.compareWithBaseline(self.allocator);
        defer {
            for (results) |r| {
                self.allocator.free(r.metric_name);
                self.allocator.free(r.region);
            }
            self.allocator.free(results);
        }

        if (results.len == 0) {
            try writer.writeAll("No baseline data available for comparison.\n");
            return;
        }

        try writer.writeAll("\n\n");
        try writer.writeAll("PERFORMANCE COMPARISON REPORT\n");
        try writer.writeAll("═══════════════════════════════════════════════════\n\n");
        try writer.writeAll("Metric              | Before   | After    | Change  | SLA\n");
        try writer.writeAll("─────────────────────────────────────────────────────────────────────────\n");

        for (results) |r| {
            const arrow = if (r.improved) "down" else "  up";

            try writer.print("{s:<20} | ", .{r.metric_name});

            if (r.before_latency_ns >= 1_000_000) {
                try writer.print("{d:>6.2} ms | ", .{r.before_latency_ns / 1_000_000.0});
            } else if (r.before_latency_ns >= 1_000) {
                try writer.print("{d:>6.2} us | ", .{r.before_latency_ns / 1_000.0});
            } else {
                try writer.print("{d:>7} ns | ", .{r.before_latency_ns});
            }

            if (r.after_latency_ns >= 1_000_000) {
                try writer.print("{d:>6.2} ms | ", .{r.after_latency_ns / 1_000_000.0});
            } else if (r.after_latency_ns >= 1_000) {
                try writer.print("{d:>6.2} us | ", .{r.after_latency_ns / 1_000.0});
            } else {
                try writer.print("{d:>7} ns | ", .{r.after_latency_ns});
            }

            try writer.print("{s}{s:>6.1}% | ", .{ arrow, r.change_percent });

            try writer.print("{s}\n", .{if (r.sla_met) "PASS" else "FAIL"});
        }

        try writer.writeAll("═══════════════════════════════════════════════════\n\n");
    }

    /// Generate sparklines for all metrics
    pub fn formatSparklines(self: *PerformanceDashboard, writer: anytype) !void {
        try writer.writeAll("\n");
        try writer.writeAll("PERFORMANCE TRENDS (last N measurements)\n");
        try writer.writeAll("─────────────────────────────────────────────\n\n");

        var iter = self.histories.iterator();
        while (iter.next()) |entry| {
            const spark = try entry.value_ptr.sparkline(self.allocator);
            defer self.allocator.free(spark);

            try writer.print("{s:<20} {s}\n", .{ entry.value_ptr.name, spark });
        }
        try writer.writeAll("\n");
    }

    /// Export dashboard as JSON
    pub fn exportJson(self: *const PerformanceDashboard, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"start_time\": {d},\n", .{self.start_time});
        try writer.print("  \"last_update\": {d},\n", .{self.last_update});
        try writer.writeAll("  \"metrics\": [\n");

        var first = true;
        var iter = self.histories.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            const stats = entry.value_ptr.getStats();

            try writer.writeAll("    {\n");
            try writer.print("      \"region\": \"{s}\",\n", .{entry.value_ptr.region});
            try writer.print("      \"operation\": \"{s}\",\n", .{entry.value_ptr.name});
            try writer.print("      \"total_ops\": {d},\n", .{stats.total_ops});
            try writer.print("      \"p50_ns\": {d},\n", .{stats.p50_ns});
            try writer.print("      \"p95_ns\": {d},\n", .{stats.p95_ns});
            try writer.print("      \"p99_ns\": {d},\n", .{stats.p99_ns});
            try writer.print("      \"throughput_ops_per_sec\": {d:.2},\n", .{stats.throughput_ops_per_sec});
            try writer.print("      \"error_rate\": {d:.4}\n", .{stats.error_rate});
            try writer.writeAll("    }");
        }

        try writer.writeAll("\n  ]\n");
        try writer.writeAll("}\n");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY USAGE TRACKING
// ═══════════════════════════════════════════════════════════════════════════════

/// Memory usage statistics
pub const MemoryUsage = struct {
    /// Total allocated bytes
    total_bytes: u64,
    /// Active allocations count
    allocation_count: usize,
    /// Peak memory usage
    peak_bytes: u64,
    /// Region name
    region: []const u8,

    /// Format with appropriate unit
    pub fn format(self: *const MemoryUsage, writer: anytype) !void {
        if (self.total_bytes >= 1_000_000_000) {
            try writer.print("{d:.2} GB", .{@as(f64, @floatFromInt(self.total_bytes)) / 1_000_000_000.0});
        } else if (self.total_bytes >= 1_000_000) {
            try writer.print("{d:.2} MB", .{@as(f64, @floatFromInt(self.total_bytes)) / 1_000_000.0});
        } else if (self.total_bytes >= 1_000) {
            try writer.print("{d:.2} KB", .{@as(f64, @floatFromInt(self.total_bytes)) / 1_000.0});
        } else {
            try writer.print("{d} B", .{self.total_bytes});
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PerformanceHistory records and retrieves" {
    const allocator = std.testing.allocator;
    var history = PerformanceHistory.init(allocator, "test_op", "test_region", 10);
    defer history.deinit();

    try history.record(100);
    try history.record(200);
    try history.record(300);

    try std.testing.expectEqual(@as(usize, 3), history.latencies.items.len);

    const stats = history.getStats();
    try std.testing.expectEqual(@as(u64, 100), stats.min_latency_ns);
    try std.testing.expectEqual(@as(u64, 300), stats.max_latency_ns);
}

test "PerformanceHistory circular buffer" {
    const allocator = std.testing.allocator;
    var history = PerformanceHistory.init(allocator, "test_op", "test_region", 3);
    defer history.deinit();

    try history.record(1);
    try history.record(2);
    try history.record(3);
    try history.record(4); // Overwrites items[0]=1 → [4, 2, 3], current_idx=1
    try history.record(5); // Overwrites items[1]=2 → [4, 5, 3], current_idx=2

    try std.testing.expectEqual(@as(usize, 3), history.latencies.items.len);
    try std.testing.expectEqual(@as(u64, 4), history.latencies.items[0]);
    try std.testing.expectEqual(@as(u64, 5), history.latencies.items[1]);
    try std.testing.expectEqual(@as(u64, 3), history.latencies.items[2]);
}

test "PerformanceStats meets SLA" {
    const stats = PerformanceStats{
        .name = "test",
        .region = "test_region",
        .total_ops = 1000,
        .success_count = 995,
        .failure_count = 5,
        .total_latency_ns = 500_000_000,
        .min_latency_ns = 100_000,
        .max_latency_ns = 1_000_000,
        .last_update = 0,
        .p50_ns = 500_000,
        .p95_ns = 800_000,
        .p99_ns = 950_000,
        .throughput_ops_per_sec = 10_000,
        .error_rate = 0.005,
    };

    const sla = SLATarget.init()
        .withLatency(1_000_000)
        .withThroughput(5_000)
        .withErrorRate(0.01);

    try std.testing.expect(stats.meetsSLA(sla));
}

test "PerformanceStats fails SLA" {
    const stats = PerformanceStats{
        .name = "test",
        .region = "test_region",
        .total_ops = 1000,
        .success_count = 900,
        .failure_count = 100,
        .total_latency_ns = 5_000_000_000,
        .min_latency_ns = 1_000_000,
        .max_latency_ns = 10_000_000,
        .last_update = 0,
        .p50_ns = 5_000_000,
        .p95_ns = 8_000_000,
        .p99_ns = 9_500_000,
        .throughput_ops_per_sec = 1_000,
        .error_rate = 0.1,
    };

    const sla = SLATarget.init()
        .withLatency(1_000_000)
        .withThroughput(5_000)
        .withErrorRate(0.01);

    try std.testing.expect(!stats.meetsSLA(sla));
}

test "PerformanceDashboard register and record" {
    const allocator = std.testing.allocator;
    var dashboard = PerformanceDashboard.init(allocator);
    defer dashboard.deinit();

    try dashboard.registerMetric("test_region", "test_op", 100);
    try dashboard.record("test_region", "test_op", 1000);
    try dashboard.record("test_region", "test_op", 2000);

    const stats = try dashboard.getStats("test_region", "test_op");
    try std.testing.expectEqual(@as(u64, 2), stats.total_ops);
}

test "PerformanceDashboard baseline comparison" {
    const allocator = std.testing.allocator;
    var dashboard = PerformanceDashboard.init(allocator);
    defer dashboard.deinit();

    try dashboard.registerMetric("test_region", "test_op", 100);

    // Record initial data (high latency)
    try dashboard.record("test_region", "test_op", 1000);
    try dashboard.record("test_region", "test_op", 1000);
    try dashboard.record("test_region", "test_op", 1000);

    // Save baseline (P99 = 1000)
    try dashboard.saveBaseline();

    // Get current stats before adding more data
    const current_stats = try dashboard.getStats("test_region", "test_op");
    const baseline_p99 = current_stats.p99_ns;

    // Add many more improved values to shift P99 below 1000
    // Need enough 500s to make 1000s represent less than 1% of data
    // With 3x1000s, we need ~300 values for 1000s to be ~1%
    var i: usize = 0;
    while (i < 400) : (i += 1) {
        try dashboard.record("test_region", "test_op", 500);
    }

    // Now compare
    const new_stats = try dashboard.getStats("test_region", "test_op");
    const improved = new_stats.p99_ns < baseline_p99;

    try std.testing.expect(improved); // Lower P99 latency is better

    // Also test comparison function
    const results = try dashboard.compareWithBaseline(allocator);
    defer {
        for (results) |r| {
            allocator.free(r.metric_name);
            allocator.free(r.region);
        }
        allocator.free(results);
    }

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expect(results[0].improved); // Lower P99 latency is better
}

test "percentile calculation" {
    const data = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    try std.testing.expectEqual(@as(u64, 5), percentile(&data, 50.0));
    try std.testing.expectEqual(@as(u64, 9), percentile(&data, 90.0));
    try std.testing.expectEqual(@as(u64, 9), percentile(&data, 99.0)); // P99 of 10 elements is index 8 = value 9
}

test "SLATarget chained methods" {
    const sla = SLATarget.init()
        .withLatency(1000)
        .withThroughput(100.0)
        .withErrorRate(0.01);

    try std.testing.expectEqual(@as(u64, 1000), sla.max_latency_ns.?);
    try std.testing.expectEqual(@as(f64, 100.0), sla.min_throughput_ops_per_sec.?);
    try std.testing.expectEqual(@as(f32, 0.01), sla.max_error_rate.?);
}

test "PerformanceHistory empty stats" {
    const allocator = std.testing.allocator;
    var history = PerformanceHistory.init(allocator, "test_op", "test_region", 10);
    defer history.deinit();

    const stats = history.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.total_ops);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), stats.min_latency_ns);
}

test "PerformanceHistory sparkline" {
    const allocator = std.testing.allocator;
    var history = PerformanceHistory.init(allocator, "test_op", "test_region", 10);
    defer history.deinit();

    try history.record(100);
    try history.record(200);
    try history.record(300);

    const spark = try history.sparkline(allocator);
    defer allocator.free(spark);

    try std.testing.expect(spark.len > 0);
}

test "percentile empty array" {
    const data = [_]u64{};
    try std.testing.expectEqual(@as(u64, 0), percentile(&data, 50.0));
}

test "percentile single element" {
    const data = [_]u64{42};
    try std.testing.expectEqual(@as(u64, 42), percentile(&data, 0.0));
    try std.testing.expectEqual(@as(u64, 42), percentile(&data, 50.0));
    try std.testing.expectEqual(@as(u64, 42), percentile(&data, 100.0));
}

test "PerformanceDashboard formatAscii" {
    const allocator = std.testing.allocator;
    var dashboard = PerformanceDashboard.init(allocator);
    defer dashboard.deinit();

    try dashboard.registerMetric("test_region", "test_op", 100);
    try dashboard.record("test_region", "test_op", 1000);

    var buffer = std.array_list.Managed(u8).init(allocator);
    defer buffer.deinit();

    try dashboard.formatAscii(buffer.writer());
    try std.testing.expect(buffer.items.len > 0);
}

test "MemoryUsage formatting" {
    const mem_gb = MemoryUsage{
        .total_bytes = 2_000_000_000,
        .allocation_count = 1000,
        .peak_bytes = 3_000_000_000,
        .region = "test",
    };

    var buffer: [50]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try mem_gb.format(stream.writer());
    try std.testing.expect(std.mem.indexOf(u8, &buffer, "GB") != null);
}

test "PerformanceDashboard exportJson" {
    const allocator = std.testing.allocator;
    var dashboard = PerformanceDashboard.init(allocator);
    defer dashboard.deinit();

    try dashboard.registerMetric("test_region", "test_op", 100);
    try dashboard.record("test_region", "test_op", 1000);

    var buffer = std.array_list.Managed(u8).init(allocator);
    defer buffer.deinit();

    try dashboard.exportJson(buffer.writer());

    const json = buffer.items;
    try std.testing.expect(std.mem.indexOf(u8, json, "\"start_time\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metrics\"") != null);
}

test "SLA_PRESETS are valid" {
    try std.testing.expect(SLA_PRESETS.TASK_CLAIM.max_latency_ns != null);
    try std.testing.expect(SLA_PRESETS.EVENT_PUBLISH.min_throughput_ops_per_sec != null);
    try std.testing.expect(SLA_PRESETS.HEALTH_CHECK.max_error_rate != null);
}

test "PerformanceHistory getLatenciesF32" {
    const allocator = std.testing.allocator;
    var history = PerformanceHistory.init(allocator, "test_op", "test_region", 10);
    defer history.deinit();

    try history.record(100);
    try history.record(200);
    try history.record(300);

    const data = try history.getLatenciesF32(allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 3), data.len);
    try std.testing.expectEqual(@as(f32, 100.0), data[0]);
    try std.testing.expectEqual(@as(f32, 300.0), data[2]);
}
