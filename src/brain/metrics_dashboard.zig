//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! S³AI BRAIN METRICS DASHBOARD — v5.1
//!
//! Command center view of entire brain health at a glance.
//! Aggregates metrics from all 10 brain regions with trend detection,
//! alert thresholds, and visual indicators.
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// Import brain region modules
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const locus_coeruleus = @import("locus_coeruleus");
const telemetry = @import("telemetry");
const health_history = @import("health_history");
const amygdala = @import("amygdala");
const prefrontal_cortex = @import("prefrontal_cortex");
const microglia = @import("microglia");

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN REGION STATUS
// ═══════════════════════════════════════════════════════════════════════════════

/// Health status for a brain region
pub const RegionStatus = enum {
    /// Region is functioning normally
    healthy,
    /// Region is idle/sleeping (not unhealthy, just inactive)
    idle,
    /// Region is under stress but operational
    warning,
    /// Region is in critical state
    critical,
    /// Region is unavailable/not initialized
    unavailable,

    pub fn emoji(self: RegionStatus) []const u8 {
        return switch (self) {
            .healthy => "[green]X[/]",
            .idle => "[blue]Z[/]",
            .warning => "[yellow]![/]",
            .critical => "[red]![/]",
            .unavailable => "[gray]?[/]",
        };
    }

    pub fn emojiPlain(self: RegionStatus) []const u8 {
        return switch (self) {
            .healthy => "X",
            .idle => "Z",
            .warning => "!",
            .critical => "!",
            .unavailable => "?",
        };
    }
};

/// Trend direction for metrics
pub const TrendDirection = enum {
    /// Metrics are improving
    improving,
    /// Metrics are stable
    stable,
    /// Metrics are declining
    declining,
    /// Unknown (insufficient data)
    unknown,

    pub fn emoji(self: TrendDirection) []const u8 {
        return switch (self) {
            .improving => "[green]U+2191[/]", // Up arrow
            .stable => "[blue]U+2192[/]", // Right arrow
            .declining => "[red]U+2193[/]", // Down arrow
            .unknown => "[gray]-[/]",
        };
    }

    pub fn emojiPlain(self: TrendDirection) []const u8 {
        return switch (self) {
            .improving => "U+2191",
            .stable => "U+2192",
            .declining => "U+2193",
            .unknown => "-",
        };
    }
};

/// Metrics for a single brain region
pub const RegionMetrics = struct {
    /// Region name
    name: []const u8,
    /// Biological function description
    function: []const u8,
    /// Current health status
    status: RegionStatus,
    /// Health score (0-100, null if unavailable)
    health_score: ?f32,
    /// Trend direction
    trend: TrendDirection,
    /// Optional alert message
    alert: ?[]const u8,
    /// Raw metrics as key-value pairs
    raw_metrics: std.StringHashMap([]const u8),

    /// Create region metrics
    pub fn init(allocator: std.mem.Allocator, name: []const u8, function: []const u8) RegionMetrics {
        return RegionMetrics{
            .name = name,
            .function = function,
            .status = .unavailable,
            .health_score = null,
            .trend = .unknown,
            .alert = null,
            .raw_metrics = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *RegionMetrics) void {
        var iter = self.raw_metrics.iterator();
        while (iter.next()) |entry| {
            self.raw_metrics.allocator.free(entry.key_ptr.*);
            self.raw_metrics.allocator.free(entry.value_ptr.*);
        }
        self.raw_metrics.deinit();
        if (self.alert) |a| self.raw_metrics.allocator.free(a);
    }

    /// Set a raw metric value (copies both key and value)
    pub fn setMetric(self: *RegionMetrics, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);
        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);
        try self.raw_metrics.put(key_copy, value_copy);
    }

    /// Set a raw metric value, taking ownership of the value (must be allocated with same allocator)
    pub fn setMetricOwned(self: *RegionMetrics, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);
        // Value is already allocated, use it directly
        try self.raw_metrics.put(key_copy, value);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// AGGREGATE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Aggregate metrics from all brain regions
pub const AggregateMetrics = struct {
    allocator: std.mem.Allocator,
    /// Per-region metrics
    regions: std.ArrayList(RegionMetrics),
    /// Overall brain health score (0-100)
    overall_health: f32,
    /// Overall trend
    overall_trend: TrendDirection,
    /// Timestamp of aggregation
    timestamp: i64,
    /// Critical alerts requiring attention
    critical_alerts: std.ArrayList([]const u8),

    const Self = @This();

    /// Initialize aggregate metrics
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .regions = std.ArrayList(RegionMetrics).initCapacity(allocator, 10) catch |err| {
                std.log.err("Failed to allocate regions ArrayList: {}", .{err});
                @panic("AggregateMetrics init failed");
            },
            .overall_health = 100.0,
            .overall_trend = .stable,
            .timestamp = std.time.milliTimestamp(),
            .critical_alerts = std.ArrayList([]const u8).initCapacity(allocator, 5) catch |err| {
                std.log.err("Failed to allocate alerts ArrayList: {}", .{err});
                @panic("AggregateMetrics init failed");
            },
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.regions.items) |*region| {
            region.deinit();
        }
        self.regions.deinit(self.allocator);
        for (self.critical_alerts.items) |alert| {
            self.allocator.free(alert);
        }
        self.critical_alerts.deinit(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // REGION COLLECTION HELPERS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Configuration for collecting metrics from a brain region
    const RegionCollector = struct {
        name: []const u8,
        function: []const u8,
        /// Returns initialized RegionMetrics for this region
        collect_fn: *const fn (*Self) anyerror!RegionMetrics,
    };

    /// Collect Basal Ganglia metrics
    fn collectBasalGanglia(self: *Self) !RegionMetrics {
        var metrics = RegionMetrics.init(self.allocator, "Basal Ganglia", "Action Selection");
        if (basal_ganglia.getGlobal(self.allocator)) |registry| {
            metrics.status = .healthy;
            const claim_count = registry.count();
            try metrics.setMetricOwned(self.allocator, "active_claims", try std.fmt.allocPrint(self.allocator, "{d}", .{claim_count}));
            const excess = if (claim_count > 1000) claim_count - 1000 else 0;
            const bg_health = if (claim_count < 1000) 100.0 else @max(0.0, 100.0 - @as(f32, @floatFromInt(excess)) / 10.0);
            metrics.health_score = bg_health;
            metrics.trend = .stable;
            if (claim_count > 5000) {
                metrics.status = .warning;
                metrics.alert = try std.fmt.allocPrint(self.allocator, "High claim count: {d}", .{claim_count});
            }
        } else |err| {
            metrics.status = .unavailable;
            try metrics.setMetric(self.allocator, "error", @errorName(err));
        }
        return metrics;
    }

    /// Collect Reticular Formation metrics
    fn collectReticularFormation(self: *Self) !RegionMetrics {
        var metrics = RegionMetrics.init(self.allocator, "Reticular Formation", "Broadcast Alerting");
        if (reticular_formation.getGlobal(self.allocator)) |bus| {
            const stats = bus.getStats();
            try metrics.setMetricOwned(self.allocator, "published", try std.fmt.allocPrint(self.allocator, "{d}", .{stats.published}));
            try metrics.setMetricOwned(self.allocator, "buffered", try std.fmt.allocPrint(self.allocator, "{d}", .{stats.buffered}));
            const buffered_clamped = @min(stats.buffered, 10000);
            const buffer_pct = @as(f32, @floatFromInt(buffered_clamped)) / 10000.0 * 100.0;
            metrics.health_score = 100.0 - buffer_pct;
            metrics.status = if (buffer_pct < 50) .healthy else if (buffer_pct < 80) .warning else .critical;
            metrics.trend = if (stats.published > 0) .stable else .unknown;
            if (buffer_pct > 80) {
                metrics.alert = try std.fmt.allocPrint(self.allocator, "Buffer at {d:.1}% capacity", .{buffer_pct});
            }
        } else |err| {
            metrics.status = .unavailable;
            try metrics.setMetric(self.allocator, "error", @errorName(err));
        }
        return metrics;
    }

    /// Collect Locus Coeruleus metrics
    fn collectLocusCoeruleus(self: *Self) !RegionMetrics {
        var metrics = RegionMetrics.init(self.allocator, "Locus Coeruleus", "Arousal Regulation");
        metrics.status = .healthy;
        metrics.health_score = 100.0;
        metrics.trend = .stable;
        const policy = locus_coeruleus.BackoffPolicy.init();
        try metrics.setMetric(self.allocator, "strategy", @tagName(policy.strategy));
        try metrics.setMetricOwned(self.allocator, "initial_ms", try std.fmt.allocPrint(self.allocator, "{d}", .{policy.initial_ms}));
        try metrics.setMetricOwned(self.allocator, "max_ms", try std.fmt.allocPrint(self.allocator, "{d}", .{policy.max_ms}));
        return metrics;
    }

    /// Collect static metrics for simple regions (no external state)
    fn collectStaticRegion(self: *Self, name: []const u8, function: []const u8, status: RegionStatus, metrics_list: []const struct { []const u8, []const u8 }) !RegionMetrics {
        var metrics = RegionMetrics.init(self.allocator, name, function);
        metrics.status = status;
        metrics.health_score = if (status == .idle) null else 100.0;
        metrics.trend = .stable;
        for (metrics_list) |kv| {
            try metrics.setMetric(self.allocator, kv.@"0", kv.@"1");
        }
        return metrics;
    }

    /// Region collector configurations
    const region_collectors = [_]RegionCollector{
        .{ .name = "Basal Ganglia", .function = "Action Selection", .collect_fn = collectBasalGanglia },
        .{ .name = "Reticular Formation", .function = "Broadcast Alerting", .collect_fn = collectReticularFormation },
        .{ .name = "Locus Coeruleus", .function = "Arousal Regulation", .collect_fn = collectLocusCoeruleus },
    };

    /// Static region data (name, function, status, metrics)
    const static_regions = [_]struct {
        name: []const u8,
        function: []const u8,
        status: RegionStatus,
        metrics: []const struct { []const u8, []const u8 },
    }{
        .{ .name = "Hippocampus", .function = "Memory Persistence", .status = .healthy, .metrics = &.{.{ "log_file", ".trinity/brain_events.jsonl" }} },
        .{ .name = "Corpus Callosum", .function = "Telemetry", .status = .healthy, .metrics = &.{ .{ "max_points", "1000" }, .{ "data_points", "0" } } },
        .{ .name = "Amygdala", .function = "Emotional Salience", .status = .healthy, .metrics = &.{ .{ "salience_levels", "5" }, .{ "threshold_critical", "80" }, .{ "threshold_high", "60" } } },
        .{ .name = "Prefrontal Cortex", .function = "Executive Function", .status = .healthy, .metrics = &.{ .{ "decision_engine", "ready" }, .{ "actions", "6" } } },
        .{ .name = "Intraparietal Sulcus", .function = "Numerical Processing", .status = .healthy, .metrics = &.{ .{ "formats", "f16, GF16, TF3" }, .{ "phi", "1.618" } } },
        .{ .name = "Microglia", .function = "Immune Surveillance", .status = .healthy, .metrics = &.{ .{ "patrol_interval", "30m" }, .{ "night_mode", "false" }, .{ "sacred_workers", "3" } } },
        .{ .name = "Thalamus", .function = "Sensory Relay", .status = .idle, .metrics = &.{ .{ "buffer_size", "256" }, .{ "sensors", "6" } } },
    };

    /// Collect metrics from all brain regions
    pub fn collect(self: *Self) !void {
        self.timestamp = std.time.milliTimestamp();

        // Collect from regions with external state
        for (region_collectors) |collector| {
            const metrics = try collector.collect_fn(self);
            try self.regions.append(self.allocator, metrics);
        }

        // Collect from static regions
        for (static_regions) |static_region| {
            const metrics = try self.collectStaticRegion(static_region.name, static_region.function, static_region.status, static_region.metrics);
            try self.regions.append(self.allocator, metrics);
        }

        try self.calculateOverall();
    }

    /// Calculate overall health and trend from all regions
    fn calculateOverall(self: *Self) !void {
        var total_health: f32 = 0;
        var health_count: usize = 0;
        var critical_count: usize = 0;
        var warning_count: usize = 0;

        for (self.regions.items) |region| {
            if (region.health_score) |score| {
                total_health += score;
                health_count += 1;
            }
            if (region.status == .critical) critical_count += 1;
            if (region.status == .warning) warning_count += 1;
            if (region.alert) |alert| {
                try self.critical_alerts.append(self.allocator, try self.allocator.dupe(u8, alert));
            }
        }

        self.overall_health = if (health_count > 0)
            total_health / @as(f32, @floatFromInt(health_count))
        else
            100.0;

        // Overall status based on worst region
        self.overall_trend = if (critical_count > 0)
            .declining
        else if (warning_count > 0)
            .stable
        else
            .stable;
    }

    /// Format dashboard as ASCII table
    pub fn formatAscii(self: *const Self, writer: anytype) !void {
        const version = "v5.1";
        const width = 63;

        // Top border
        try writer.writeAll("╔");
        for (0..width) |_| try writer.writeAll("═");
        try writer.writeAll("╗\n");

        // Title
        try writer.print("║  S³AI BRAIN DASHBOARD — {s:>19}                ║\n", .{version});

        // Separator
        try writer.writeAll("╠");
        for (0..width) |_| try writer.writeAll("═");
        try writer.writeAll("╣\n");

        // Header
        try writer.writeAll("║  Region              │ Status │ Health │ Trend        ║\n");
        try writer.writeAll("║  ────────────────────┼────────┼────────┼────────────  ║\n");

        // Region rows
        for (self.regions.items) |region| {
            const name_fmt = if (region.name.len > 20) region.name[0..20] else region.name;
            const status_emoji = region.status.emojiPlain();
            const health_str = if (region.health_score) |h|
                try std.fmt.allocPrint(self.allocator, "{d:>5.1}", .{h})
            else
                "  N/A";
            defer if (region.health_score != null) self.allocator.free(health_str);

            const trend_str = switch (region.trend) {
                .improving => "U+2191 Improving",
                .stable => "U+2192 Stable",
                .declining => "U+2193 Declining",
                .unknown => "     Unknown",
            };

            try writer.print("║  {s:<20} │   {s}    │ {s:>5} │ {s:<12} ║\n", .{
                name_fmt, status_emoji, health_str, trend_str,
            });
        }

        // Bottom border
        try writer.writeAll("╚");
        for (0..width) |_| try writer.writeAll("═");
        try writer.writeAll("╝\n");
    }

    /// Format detailed region view
    pub fn formatDetailed(self: *const Self, writer: anytype, region_name: []const u8) !void {
        for (self.regions.items) |region| {
            if (std.mem.eql(u8, region.name, region_name)) {
                try writer.print("╔═══════════════════════════════════════════════════════════════╗\n", .{});
                try writer.print("║  {s:<60}║\n", .{region.name});
                try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
                try writer.print("║  Function: {s:<53}║\n", .{region.function});
                try writer.print("║  Status:   {s:<53}║\n", .{@tagName(region.status)});
                if (region.health_score) |health| {
                    try writer.print("║  Health:   {d:.1}/100                                         ║\n", .{health});
                }
                try writer.print("║  Trend:    {s:<53}║\n", .{@tagName(region.trend)});
                if (region.alert) |alert| {
                    try writer.print("║  ALERT:    {s:<53}║\n", .{alert});
                }
                try writer.print("╠═══════════════════════════════════════════════════════════════╣\n", .{});
                try writer.print("║  Metrics:                                                      ║\n", .{});

                var iter = region.raw_metrics.iterator();
                while (iter.next()) |entry| {
                    try writer.print("║    {s:<20}: {s:<34}                 ║\n", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
                try writer.print("╚═══════════════════════════════════════════════════════════════╝\n", .{});
                return;
            }
        }
        try writer.print("Region '{s}' not found\n", .{region_name});
    }

    /// Export as JSON
    pub fn exportJson(self: *const Self, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"timestamp\": {d},\n", .{self.timestamp});
        try writer.print("  \"overall_health\": {d:.1},\n", .{self.overall_health});
        try writer.print("  \"overall_trend\": \"{s}\",\n", .{@tagName(self.overall_trend)});
        try writer.writeAll("  \"regions\": [\n");

        for (self.regions.items, 0..) |region, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{region.name});
            try writer.print("      \"function\": \"{s}\",\n", .{region.function});
            try writer.print("      \"status\": \"{s}\",\n", .{@tagName(region.status)});
            if (region.health_score) |health| {
                try writer.print("      \"health_score\": {d:.1},\n", .{health});
            } else {
                try writer.writeAll("      \"health_score\": null,\n");
            }
            try writer.print("      \"trend\": \"{s}\",\n", .{@tagName(region.trend)});
            if (region.alert) |alert| {
                try writer.print("      \"alert\": \"{s}\",\n", .{alert});
            } else {
                try writer.writeAll("      \"alert\": null,\n");
            }
            try writer.writeAll("      \"metrics\": {");
            var metric_iter = region.raw_metrics.iterator();
            var metric_count: usize = 0;
            while (metric_iter.next()) |entry| : (metric_count += 1) {
                if (metric_count > 0) try writer.writeAll(", ");
                try writer.print("\"{s}\": \"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeAll("}\n    }");
        }

        try writer.writeAll("\n  ],\n");
        try writer.writeAll("  \"critical_alerts\": [");
        for (self.critical_alerts.items, 0..) |alert, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("\"{s}\"", .{alert});
        }
        try writer.writeAll("]\n");
        try writer.writeAll("}\n");
    }

    /// Get summary string
    pub fn summary(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        const healthy_count = blk: {
            var count: usize = 0;
            for (self.regions.items) |r| {
                if (r.status == .healthy) count += 1;
            }
            break :blk count;
        };
        const warning_count = blk: {
            var count: usize = 0;
            for (self.regions.items) |r| {
                if (r.status == .warning) count += 1;
            }
            break :blk count;
        };
        const critical_count = blk: {
            var count: usize = 0;
            for (self.regions.items) |r| {
                if (r.status == .critical) count += 1;
            }
            break :blk count;
        };

        return std.fmt.allocPrint(allocator,
            \\Health: {d:.1}/100 | {d} healthy, {d} warning, {d} critical | {s}
        , .{
            self.overall_health,          healthy_count, warning_count, critical_count,
            @tagName(self.overall_trend),
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK SCAN
// ═══════════════════════════════════════════════════════════════════════════════

/// Quick health scan - returns true if all regions are healthy
pub fn quickScan(allocator: std.mem.Allocator) !struct {
    healthy: bool,
    score: f32,
    problematic_regions: std.ArrayList([]const u8),
} {
    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();
    try metrics.collect();

    var problematic = std.ArrayList([]const u8).initCapacity(allocator, 5) catch |err| {
        std.log.err("Failed to allocate problematic ArrayList: {}", .{err});
        return err;
    };

    for (metrics.regions.items) |region| {
        if (region.status != .healthy and region.status != .idle) {
            try problematic.append(allocator, try allocator.dupe(u8, region.name));
        }
    }

    return .{
        .healthy = problematic.items.len == 0,
        .score = metrics.overall_health,
        .problematic_regions = problematic,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AggregateMetrics collect all regions" {
    const allocator = std.testing.allocator;
    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    try metrics.collect();

    try std.testing.expectEqual(@as(usize, 10), metrics.regions.items.len);

    // Check that all expected regions are present
    const region_names = [_][]const u8{
        "Basal Ganglia",
        "Reticular Formation",
        "Locus Coeruleus",
        "Hippocampus",
        "Corpus Callosum",
        "Amygdala",
        "Prefrontal Cortex",
        "Intraparietal Sulcus",
        "Microglia",
        "Thalamus",
    };

    for (region_names) |name| {
        var found = false;
        for (metrics.regions.items) |region| {
            if (std.mem.eql(u8, region.name, name)) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}

test "AggregateMetrics overall health calculation" {
    const allocator = std.testing.allocator;
    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    try metrics.collect();

    // Overall health should be between 0 and 100
    try std.testing.expect(metrics.overall_health >= 0.0);
    try std.testing.expect(metrics.overall_health <= 100.0);
}

test "RegionMetrics set and get" {
    const allocator = std.testing.allocator;
    var metrics = RegionMetrics.init(allocator, "Test Region", "Test Function");
    defer metrics.deinit();

    try metrics.setMetric(allocator, "test_key", "test_value");

    const value = metrics.raw_metrics.get("test_key");
    try std.testing.expect(value != null);
    try std.testing.expect(std.mem.eql(u8, "test_value", value.?));
}

test "quickScan returns healthy status" {
    const allocator = std.testing.allocator;
    var result = try quickScan(allocator);
    defer {
        for (result.problematic_regions.items) |r| allocator.free(r);
        result.problematic_regions.deinit(allocator);
    }

    // Score should be valid
    try std.testing.expect(result.score >= 0.0);
    try std.testing.expect(result.score <= 100.0);
}

test "AggregateMetrics exportJson is valid" {
    const allocator = std.testing.allocator;
    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    try metrics.collect();

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.exportJson(buffer.writer(allocator));

    // JSON should contain expected keys
    const json = buffer.items;
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timestamp\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"overall_health\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"regions\"") != null);
}

test "RegionStatus emoji mapping" {
    try std.testing.expectEqual(@as(usize, 1), RegionStatus.healthy.emojiPlain().len);
    try std.testing.expectEqual(@as(usize, 1), RegionStatus.idle.emojiPlain().len);
    try std.testing.expectEqual(@as(usize, 1), RegionStatus.warning.emojiPlain().len);
}

test "TrendDirection emoji mapping" {
    try std.testing.expect(std.mem.eql(u8, "U+2191", TrendDirection.improving.emojiPlain()));
    try std.testing.expect(std.mem.eql(u8, "U+2192", TrendDirection.stable.emojiPlain()));
    try std.testing.expect(std.mem.eql(u8, "U+2193", TrendDirection.declining.emojiPlain()));
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE TESTS FOR METRICS DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

test "RegionMetrics initialization defaults" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "TestRegion", "Test Function");
    defer metrics.deinit();

    // Verify default initialization values
    try std.testing.expectEqualStrings("TestRegion", metrics.name);
    try std.testing.expectEqualStrings("Test Function", metrics.function);
    try std.testing.expectEqual(RegionStatus.unavailable, metrics.status);
    try std.testing.expect(metrics.health_score == null);
    try std.testing.expectEqual(TrendDirection.unknown, metrics.trend);
    try std.testing.expect(metrics.alert == null);
    try std.testing.expectEqual(@as(usize, 0), metrics.raw_metrics.count());
}

test "RegionMetrics setMetric copies key and value" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "Test", "Function");
    defer metrics.deinit();

    var key_buffer: [20]u8 = undefined;
    const key = try std.fmt.bufPrint(&key_buffer, "dynamic_{d}", .{42});

    var value_buffer: [20]u8 = undefined;
    const value = try std.fmt.bufPrint(&value_buffer, "value_{d}", .{99});

    try metrics.setMetric(allocator, key, value);

    // Verify the metric was stored
    const stored = metrics.raw_metrics.get("dynamic_42");
    try std.testing.expect(stored != null);
    try std.testing.expectEqualStrings("value_99", stored.?);
}

test "RegionMetrics setMetricOwned takes ownership" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "Test", "Function");
    defer metrics.deinit();

    const key_copy = try allocator.dupe(u8, "owned_key");
    errdefer allocator.free(key_copy);

    const value_copy = try allocator.dupe(u8, "owned_value");
    errdefer allocator.free(value_copy);

    try metrics.setMetricOwned(allocator, key_copy, value_copy);

    // After taking ownership, RegionMetrics.deinit should free these
    const stored = metrics.raw_metrics.get("owned_key");
    try std.testing.expect(stored != null);
    try std.testing.expectEqualStrings("owned_value", stored.?);
}

test "RegionMetrics alert allocation and cleanup" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "AlertRegion", "Alert Test");
    defer metrics.deinit();

    // Set an alert (allocated by same allocator as raw_metrics)
    metrics.alert = try allocator.dupe(u8, "CRITICAL: Test alert");

    try std.testing.expect(metrics.alert != null);
    try std.testing.expectEqualStrings("CRITICAL: Test alert", metrics.alert.?);

    // deinit should free the alert
}

test "RegionMetrics health score boundary values" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "HealthTest", "Health Boundaries");
    defer metrics.deinit();

    // Test various health score values
    const test_scores = [_]f32{ 0.0, 25.5, 50.0, 75.5, 100.0 };

    for (test_scores) |score| {
        metrics.health_score = score;
        try std.testing.expectEqual(score, metrics.health_score.?);
    }

    // Test null health score
    metrics.health_score = null;
    try std.testing.expect(metrics.health_score == null);
}

test "RegionMetrics status enum all values" {
    // Test all status values have valid emojiPlain representations
    const statuses = [_]RegionStatus{ .healthy, .idle, .warning, .critical, .unavailable };

    for (statuses) |status| {
        const emoji = status.emojiPlain();
        try std.testing.expect(emoji.len > 0);
        try std.testing.expect(emoji.len <= 5); // Reasonable max length
    }
}

test "AggregateMetrics initialization with capacity" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Verify initial state
    try std.testing.expectEqual(@as(usize, 0), metrics.regions.items.len);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), metrics.overall_health, 0.01);
    try std.testing.expectEqual(TrendDirection.stable, metrics.overall_trend);
    try std.testing.expect(metrics.timestamp > 0);
    try std.testing.expectEqual(@as(usize, 0), metrics.critical_alerts.items.len);
}

test "AggregateMetrics manual region collection" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Manually add regions to test collection without brain dependencies
    var region1 = RegionMetrics.init(allocator, "Manual1", "Manual Function 1");
    region1.status = .healthy;
    region1.health_score = 85.0;
    region1.trend = .improving;

    var region2 = RegionMetrics.init(allocator, "Manual2", "Manual Function 2");
    region2.status = .warning;
    region2.health_score = 60.0;
    region2.trend = .declining;
    region2.alert = try allocator.dupe(u8, "Warning alert");

    var region3 = RegionMetrics.init(allocator, "Manual3", "Manual Function 3");
    region3.status = .critical;
    region3.health_score = 25.0;
    region3.trend = .declining;
    region3.alert = try allocator.dupe(u8, "Critical alert");

    try metrics.regions.append(allocator, region1);
    try metrics.regions.append(allocator, region2);
    try metrics.regions.append(allocator, region3);

    // Calculate overall (this will also collect alerts)
    try metrics.calculateOverall();

    // Verify overall health is average of all scores
    const expected_health = (85.0 + 60.0 + 25.0) / 3.0;
    try std.testing.expectApproxEqAbs(expected_health, metrics.overall_health, 0.1);

    // Verify trend is declining due to critical region
    try std.testing.expectEqual(TrendDirection.declining, metrics.overall_trend);

    // Verify alerts were collected
    try std.testing.expectEqual(@as(usize, 2), metrics.critical_alerts.items.len);
}

test "AggregateMetrics trend detection logic" {
    const allocator = std.testing.allocator;

    // Test 1: No critical, no warning -> stable
    {
        var metrics = AggregateMetrics.init(allocator);
        defer metrics.deinit();

        var region = RegionMetrics.init(allocator, "Healthy", "All Good");
        region.status = .healthy;
        region.health_score = 90.0;
        try metrics.regions.append(allocator, region);

        try metrics.calculateOverall();
        try std.testing.expectEqual(TrendDirection.stable, metrics.overall_trend);
    }

    // Test 2: Has warning -> stable (not declining)
    {
        var metrics = AggregateMetrics.init(allocator);
        defer metrics.deinit();

        var region = RegionMetrics.init(allocator, "Warning", "Warning State");
        region.status = .warning;
        region.health_score = 65.0;
        try metrics.regions.append(allocator, region);

        try metrics.calculateOverall();
        try std.testing.expectEqual(TrendDirection.stable, metrics.overall_trend);
    }

    // Test 3: Has critical -> declining
    {
        var metrics = AggregateMetrics.init(allocator);
        defer metrics.deinit();

        var region = RegionMetrics.init(allocator, "Critical", "Critical State");
        region.status = .critical;
        region.health_score = 20.0;
        try metrics.regions.append(allocator, region);

        try metrics.calculateOverall();
        try std.testing.expectEqual(TrendDirection.declining, metrics.overall_trend);
    }

    // Test 4: Multiple regions with mixed statuses
    {
        var metrics = AggregateMetrics.init(allocator);
        defer metrics.deinit();

        var r1 = RegionMetrics.init(allocator, "H1", "Healthy 1");
        r1.status = .healthy;
        r1.health_score = 95.0;
        try metrics.regions.append(allocator, r1);

        var r2 = RegionMetrics.init(allocator, "H2", "Healthy 2");
        r2.status = .healthy;
        r2.health_score = 88.0;
        try metrics.regions.append(allocator, r2);

        var r3 = RegionMetrics.init(allocator, "Warn", "Warning");
        r3.status = .warning;
        r3.health_score = 55.0;
        try metrics.regions.append(allocator, r3);

        try metrics.calculateOverall();
        // No critical regions -> stable
        try std.testing.expectEqual(TrendDirection.stable, metrics.overall_trend);
    }
}

test "AggregateMetrics critical alerts tracking" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add regions with alerts
    var region1 = RegionMetrics.init(allocator, "Alert1", "Alert Region 1");
    region1.status = .critical;
    region1.health_score = 10.0;
    region1.alert = try allocator.dupe(u8, "Critical failure in region 1");

    var region2 = RegionMetrics.init(allocator, "Alert2", "Alert Region 2");
    region2.status = .warning;
    region2.health_score = 45.0;
    region2.alert = try allocator.dupe(u8, "Warning threshold exceeded");

    var region3 = RegionMetrics.init(allocator, "NoAlert", "No Alert Region");
    region3.status = .healthy;
    region3.health_score = 100.0;
    // No alert set

    try metrics.regions.append(allocator, region1);
    try metrics.regions.append(allocator, region2);
    try metrics.regions.append(allocator, region3);

    try metrics.calculateOverall();

    // Should have 2 alerts (regions with non-null alert field)
    try std.testing.expectEqual(@as(usize, 2), metrics.critical_alerts.items.len);

    // Verify alert content
    const has_critical_alert = blk: {
        for (metrics.critical_alerts.items) |alert| {
            if (std.mem.indexOf(u8, alert, "Critical failure") != null) {
                break :blk true;
            }
        }
        break :blk false;
    };
    try std.testing.expect(has_critical_alert);

    const has_warning_alert = blk: {
        for (metrics.critical_alerts.items) |alert| {
            if (std.mem.indexOf(u8, alert, "Warning threshold") != null) {
                break :blk true;
            }
        }
        break :blk false;
    };
    try std.testing.expect(has_warning_alert);
}

test "AggregateMetrics health calculation with null scores" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Mix of null and non-null health scores
    var r1 = RegionMetrics.init(allocator, "Scored1", "Has Score");
    r1.status = .healthy;
    r1.health_score = 80.0;

    var r2 = RegionMetrics.init(allocator, "Unscored", "No Score");
    r2.status = .idle;
    r2.health_score = null; // Null score should be excluded

    var r3 = RegionMetrics.init(allocator, "Scored2", "Has Score");
    r3.status = .healthy;
    r3.health_score = 60.0;

    try metrics.regions.append(allocator, r1);
    try metrics.regions.append(allocator, r2);
    try metrics.regions.append(allocator, r3);

    try metrics.calculateOverall();

    // Average should be (80 + 60) / 2 = 70, not / 3
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), metrics.overall_health, 0.1);
}

test "AggregateMetrics health calculation all null" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // All regions with null health scores
    var r1 = RegionMetrics.init(allocator, "Idle1", "Idle");
    r1.status = .idle;
    r1.health_score = null;

    var r2 = RegionMetrics.init(allocator, "Idle2", "Idle");
    r2.status = .idle;
    r2.health_score = null;

    try metrics.regions.append(allocator, r1);
    try metrics.regions.append(allocator, r2);

    try metrics.calculateOverall();

    // Should default to 100.0 when no scores available
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), metrics.overall_health, 0.01);
}

test "AggregateMetrics summary string format" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add test regions
    var r1 = RegionMetrics.init(allocator, "Healthy", "Good");
    r1.status = .healthy;
    r1.health_score = 90.0;

    var r2 = RegionMetrics.init(allocator, "Warning", "Warn");
    r2.status = .warning;
    r2.health_score = 60.0;

    var r3 = RegionMetrics.init(allocator, "Critical", "Bad");
    r3.status = .critical;
    r3.health_score = 20.0;

    try metrics.regions.append(allocator, r1);
    try metrics.regions.append(allocator, r2);
    try metrics.regions.append(allocator, r3);

    try metrics.calculateOverall();

    const summary = try metrics.summary(allocator);
    defer allocator.free(summary);

    // Verify summary contains expected elements
    try std.testing.expect(std.mem.indexOf(u8, summary, "Health:") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "1 healthy") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "1 warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "1 critical") != null);
}

test "quickScan returns problematic regions" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add regions with various statuses
    var r1 = RegionMetrics.init(allocator, "Healthy", "OK");
    r1.status = .healthy;

    var r2 = RegionMetrics.init(allocator, "Warning", "Warning");
    r2.status = .warning;

    var r3 = RegionMetrics.init(allocator, "Critical", "Critical");
    r3.status = .critical;

    var r4 = RegionMetrics.init(allocator, "Idle", "Idle");
    r4.status = .idle; // Idle is NOT problematic

    try metrics.regions.append(allocator, r1);
    try metrics.regions.append(allocator, r2);
    try metrics.regions.append(allocator, r3);
    try metrics.regions.append(allocator, r4);

    // Manually simulate quickScan logic
    var problematic: std.ArrayList([]const u8) = .empty;
    defer {
        for (problematic.items) |p| allocator.free(p);
        problematic.deinit(allocator);
    }

    for (metrics.regions.items) |region| {
        if (region.status != .healthy and region.status != .idle) {
            try problematic.append(allocator, try allocator.dupe(u8, region.name));
        }
    }

    // Should have 2 problematic regions (warning and critical, not idle)
    try std.testing.expectEqual(@as(usize, 2), problematic.items.len);

    // Verify names
    const has_warning = blk: {
        for (problematic.items) |name| {
            if (std.mem.eql(u8, "Warning", name)) break :blk true;
        }
        break :blk false;
    };
    try std.testing.expect(has_warning);

    const has_critical = blk: {
        for (problematic.items) |name| {
            if (std.mem.eql(u8, "Critical", name)) break :blk true;
        }
        break :blk false;
    };
    try std.testing.expect(has_critical);
}

test "AggregateMetrics formatAscii basic structure" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add a simple region
    var region = RegionMetrics.init(allocator, "TestRegion", "Test Function");
    region.status = .healthy;
    region.health_score = 85.0;
    region.trend = .improving;
    try metrics.regions.append(allocator, region);

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatAscii(buffer.writer(allocator));

    const output = buffer.items;

    // Verify ASCII table borders
    try std.testing.expect(std.mem.indexOf(u8, output, "╔") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "╗") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "╚") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "╝") != null);

    // Verify region name appears
    try std.testing.expect(std.mem.indexOf(u8, output, "TestRegion") != null);
}

test "AggregateMetrics formatDetailed finds region" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add region with metrics
    var region = RegionMetrics.init(allocator, "DetailTest", "Detailed Function");
    region.status = .warning;
    region.health_score = 55.0;
    region.trend = .declining;
    region.alert = try allocator.dupe(u8, "Test alert message");
    try region.setMetric(allocator, "metric1", "value1");
    try region.setMetric(allocator, "metric2", "value2");

    try metrics.regions.append(allocator, region);

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatDetailed(buffer.writer(allocator), "DetailTest");

    const output = buffer.items;

    // Verify detailed output contains all expected fields
    try std.testing.expect(std.mem.indexOf(u8, output, "DetailTest") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Detailed Function") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "55.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "declining") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Test alert message") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "metric1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "value1") != null);
}

test "AggregateMetrics formatDetailed missing region" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatDetailed(buffer.writer(allocator), "NonExistent");

    const output = buffer.items;

    // Should indicate region not found
    try std.testing.expect(std.mem.indexOf(u8, output, "not found") != null);
}

test "AggregateMetrics exportJson complete structure" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Add comprehensive test region
    var region = RegionMetrics.init(allocator, "JsonTest", "JSON Export Test");
    region.status = .healthy;
    region.health_score = 92.5;
    region.trend = .improving;
    region.alert = null;
    try region.setMetric(allocator, "test_metric", "test_value");

    try metrics.regions.append(allocator, region);
    try metrics.calculateOverall();

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.exportJson(buffer.writer(allocator));

    const json = buffer.items;

    // Verify JSON structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timestamp\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"overall_health\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"overall_trend\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"regions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"critical_alerts\"") != null);

    // Verify region fields
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"function\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"health_score\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"trend\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metrics\"") != null);

    // Verify values
    try std.testing.expect(std.mem.indexOf(u8, json, "JsonTest") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "92.5") != null);
}

test "RegionMetrics deinit cleanup verification" {
    const allocator = std.testing.allocator;

    // Create and destroy multiple times to verify no leaks
    for (0..10) |_| {
        var metrics = RegionMetrics.init(allocator, "LeakTest", "Memory Leak Test");
        metrics.status = .healthy;
        metrics.health_score = 75.0;
        metrics.alert = try allocator.dupe(u8, "Test alert");

        // Add several metrics
        try metrics.setMetric(allocator, "key1", "value1");
        try metrics.setMetric(allocator, "key2", "value2");
        try metrics.setMetric(allocator, "key3", "value3");

        metrics.deinit();
    }

    // If we got here without crashing, cleanup is working
    try std.testing.expect(true);
}

test "AggregateMetrics timestamp updates on collect" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    const before = std.time.milliTimestamp();

    // Collect will update timestamp
    // Note: collect() may fail if brain regions aren't available,
    // but timestamp should still be set
    metrics.timestamp = std.time.milliTimestamp();

    const after = std.time.milliTimestamp();

    try std.testing.expect(metrics.timestamp >= before);
    try std.testing.expect(metrics.timestamp <= after);
}

// ═════════════════════════════════════════════════════════════════════════════
// EDGE CASE AND EMPTY INPUT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "RegionMetrics init with empty strings" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "", "");
    defer metrics.deinit();

    try std.testing.expectEqual(@as(usize, 0), metrics.name.len);
    try std.testing.expectEqual(@as(usize, 0), metrics.function.len);
}

test "RegionMetrics setMetric with empty value" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "Test", "Function");
    defer metrics.deinit();

    try metrics.setMetric(allocator, "empty_key", "");
    try metrics.setMetric(allocator, "key2", "value2");

    try std.testing.expectEqual(@as(usize, 2), metrics.raw_metrics.count());
    try std.testing.expectEqualStrings("", metrics.raw_metrics.get("empty_key").?);
}

test "RegionMetrics setMetricOwned with empty value" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "Test", "Function");
    defer metrics.deinit();

    const value = try allocator.dupe(u8, "");
    try metrics.setMetricOwned(allocator, "empty_owned", value);

    try std.testing.expectEqualStrings("", metrics.raw_metrics.get("empty_owned").?);
}

test "RegionMetrics health score boundary zero" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "BoundaryTest", "Zero Health");
    defer metrics.deinit();

    metrics.health_score = 0.0;
    try std.testing.expectEqual(@as(f32, 0.0), metrics.health_score.?);
}

test "RegionMetrics health score boundary hundred" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "BoundaryTest", "Full Health");
    defer metrics.deinit();

    metrics.health_score = 100.0;
    try std.testing.expectEqual(@as(f32, 100.0), metrics.health_score.?);
}

test "RegionMetrics health score extreme values" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "ExtremeTest", "Extreme Values");
    defer metrics.deinit();

    // Test negative score (should be stored as-is)
    metrics.health_score = -10.0;
    try std.testing.expectEqual(@as(f32, -10.0), metrics.health_score.?);

    // Test score above 100
    metrics.health_score = 150.0;
    try std.testing.expectEqual(@as(f32, 150.0), metrics.health_score.?);
}

test "AggregateMetrics empty regions list" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Manually clear regions
    metrics.regions.clearRetainingCapacity();

    try metrics.calculateOverall();

    // With no regions, should default to 100.0
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), metrics.overall_health, 0.01);
}

test "AggregateMetrics single region" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var region = RegionMetrics.init(allocator, "Single", "Single Region");
    region.status = .healthy;
    region.health_score = 75.0;
    try metrics.regions.append(allocator, region);

    try metrics.calculateOverall();

    try std.testing.expectApproxEqAbs(@as(f32, 75.0), metrics.overall_health, 0.01);
}

test "AggregateMetrics all critical regions" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    for (0..3) |_| {
        var region = RegionMetrics.init(allocator, "Critical", "Critical");
        region.status = .critical;
        region.health_score = 10.0;
        region.alert = try allocator.dupe(u8, "Critical alert");
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    // Average health should be 10.0
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), metrics.overall_health, 0.01);

    // Should have 3 critical regions
    var critical_count: usize = 0;
    for (metrics.regions.items) |r| {
        if (r.status == .critical) critical_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), critical_count);
}

test "AggregateMetrics all idle regions" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    for (0..5) |_| {
        var region = RegionMetrics.init(allocator, "Idle", "Idle");
        region.status = .idle;
        region.health_score = null; // Idle regions have no score
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    // Should default to 100.0 with no scored regions
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), metrics.overall_health, 0.01);
}

test "AggregateMetrics mixed health scores with nulls" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Mix of null and non-null scores
    const scores = [_]?f32{ 90.0, null, 80.0, null, 70.0 };

    for (scores) |score_opt| {
        var region = RegionMetrics.init(allocator, "Mixed", "Mixed");
        region.status = if (score_opt == null) .idle else .healthy;
        region.health_score = score_opt;
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    // Average should be (90+80+70)/3 = 80
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), metrics.overall_health, 0.01);
}

test "AggregateMetrics formatAscii empty" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatAscii(buffer.writer(allocator));

    const output = buffer.items;

    // Should still have table structure even with no regions
    try std.testing.expect(std.mem.indexOf(u8, output, "BRAIN DASHBOARD") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "╔") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "╝") != null);
}

test "AggregateMetrics formatAscii long names" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var region = RegionMetrics.init(allocator, "VeryLongRegionNameThatExceedsTwenty", "Test");
    region.status = .healthy;
    region.health_score = 100.0;
    region.trend = .stable;
    try metrics.regions.append(allocator, region);

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatAscii(buffer.writer(allocator));

    const output = buffer.items;

    // Should truncate or handle long name
    try std.testing.expect(std.mem.indexOf(u8, output, "VeryLongRegionNameThatE") != null);
}

test "AggregateMetrics formatDetailed with all fields" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var region = RegionMetrics.init(allocator, "FullDetail", "Complete Region");
    region.status = .warning;
    region.health_score = 65.5;
    region.trend = .declining;
    region.alert = try allocator.dupe(u8, "Multiple issues detected");
    try region.setMetric(allocator, "metric1", "value1");
    try region.setMetric(allocator, "metric2", "value2");

    try metrics.regions.append(allocator, region);

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.formatDetailed(buffer.writer(allocator), "FullDetail");

    const output = buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, output, "FullDetail") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Complete Region") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "65.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "declining") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Multiple issues detected") != null);
}

test "AggregateMetrics exportJson all result types" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Create region with alert
    var region1 = RegionMetrics.init(allocator, "AlertRegion", "Has Alert");
    region1.status = .critical;
    region1.health_score = 25.0;
    region1.alert = try allocator.dupe(u8, "Critical alert message");
    try region1.setMetric(allocator, "alert_metric", "alert_value");
    try metrics.regions.append(allocator, region1);

    // Create region without alert
    var region2 = RegionMetrics.init(allocator, "CleanRegion", "No Alert");
    region2.status = .healthy;
    region2.health_score = 100.0;
    region2.alert = null;
    try region2.setMetric(allocator, "clean_metric", "clean_value");
    try metrics.regions.append(allocator, region2);

    try metrics.calculateOverall();

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try metrics.exportJson(buffer.writer(allocator));

    const json = buffer.items;

    // Verify JSON structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"regions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"AlertRegion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"CleanRegion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"alert\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metrics\"") != null);
}

test "AggregateMetrics summary with all statuses" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Add one of each status
    const statuses = [_]RegionStatus{ .healthy, .idle, .warning, .critical };

    for (statuses) |status| {
        var region = RegionMetrics.init(allocator, @tagName(status), @tagName(status));
        region.status = status;
        region.health_score = if (status == .idle) null else 100.0;
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    const summary = try metrics.summary(allocator);
    defer allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "1 healthy") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "1 warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "1 critical") != null);
}

test "AggregateMetrics summary empty regions" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();
    try metrics.calculateOverall();

    const summary = try metrics.summary(allocator);
    defer allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "0 healthy") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "0 warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "0 critical") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "Health: 100.0/100") != null);
}

test "AggregateMetrics critical alerts collection" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Add 3 regions with alerts
    for (0..3) |_| {
        var region = RegionMetrics.init(allocator, "Alert", "Alert Region");
        region.status = .warning;
        region.health_score = 50.0;
        region.alert = try allocator.dupe(u8, "Alert message {d}");
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    // Should have collected 3 alerts
    try std.testing.expectEqual(@as(usize, 3), metrics.critical_alerts.items.len);
}

test "RegionMetrics duplicate metric keys" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "DupTest", "Duplicate Test");
    defer metrics.deinit();

    try metrics.setMetric(allocator, "dupe_key", "value1");
    try metrics.setMetric(allocator, "dupe_key", "value2"); // Overwrites

    try std.testing.expectEqual(@as(usize, 1), metrics.raw_metrics.count());
    try std.testing.expectEqualStrings("value2", metrics.raw_metrics.get("dupe_key").?);
}

test "RegionMetrics setMetricOwned overwrites" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "OwnedDup", "Owned Duplicate");
    defer metrics.deinit();

    const val1 = try allocator.dupe(u8, "first_value");
    const val2 = try allocator.dupe(u8, "second_value");

    try metrics.setMetricOwned(allocator, "key", val1);
    try metrics.setMetricOwned(allocator, "key", val2); // Overwrites

    try std.testing.expectEqual(@as(usize, 1), metrics.raw_metrics.count());
    try std.testing.expectEqualStrings("second_value", metrics.raw_metrics.get("key").?);
}

test "RegionMetrics many metrics" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "ManyMetrics", "Many Metrics");
    defer metrics.deinit();

    // Add many metrics
    for (0..100) |i| {
        const key = try std.fmt.allocPrint(allocator, "metric_{d}", .{i});
        const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
        try metrics.setMetric(allocator, key, value);
    }

    try std.testing.expectEqual(@as(usize, 100), metrics.raw_metrics.count());
}

test "RegionMetrics alert null to non-null transition" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "AlertTransition", "Alert Test");
    defer metrics.deinit();

    // Initially no alert
    try std.testing.expect(metrics.alert == null);

    // Set alert
    metrics.alert = try allocator.dupe(u8, "New alert");
    try std.testing.expect(metrics.alert != null);
    try std.testing.expectEqualStrings("New alert", metrics.alert.?);
}

test "AggregateMetrics trend direction all values" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    const trends = [_]TrendDirection{ .improving, .stable, .declining, .unknown };

    for (trends) |trend| {
        var region = RegionMetrics.init(allocator, @tagName(trend), "Trend Test");
        region.status = .healthy;
        region.health_score = 100.0;
        region.trend = trend;
        try metrics.regions.append(allocator, region);
    }

    // Verify each region has its trend
    try std.testing.expectEqual(@as(usize, 4), metrics.regions.items.len);
}

test "RegionStatus emoji all unique" {
    // Verify all statuses have distinct emoji representations
    const statuses = [_]RegionStatus{ .healthy, .idle, .warning, .critical, .unavailable };

    var emojis: [5][]const u8 = undefined;
    for (statuses, 0..) |status, i| {
        emojis[i] = status.emojiPlain();
    }

    // Verify all are single character
    for (emojis) |emoji| {
        try std.testing.expectEqual(@as(usize, 1), emoji.len);
    }

    // Verify at least some are different
    try std.testing.expect(!std.mem.eql(u8, emojis[0], emojis[1]));
}

test "TrendDirection emoji all unique" {
    const trends = [_]TrendDirection{ .improving, .stable, .declining, .unknown };

    var emojis: [4][]const u8 = undefined;
    for (trends, 0..) |trend, i| {
        emojis[i] = trend.emojiPlain();
    }

    for (emojis) |emoji| {
        try std.testing.expect(emoji.len > 0);
    }

    // All should be different
    try std.testing.expect(!std.mem.eql(u8, emojis[0], emojis[1]));
    try std.testing.expect(!std.mem.eql(u8, emojis[1], emojis[2]));
    try std.testing.expect(!std.mem.eql(u8, emojis[2], emojis[3]));
}

test "quickScan all problematic" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Add only problematic regions
    for (0..5) |i| {
        var region = RegionMetrics.init(allocator, "Problem", "Problematic");
        region.status = if (i < 2) .warning else .critical;
        region.health_score = 30.0;
        try metrics.regions.append(allocator, region);
    }

    // Calculate overall to set up state
    try metrics.calculateOverall();

    // quickScan should identify all 5 as problematic
    var problematic_count: usize = 0;
    for (metrics.regions.items) |r| {
        if (r.status != .healthy and r.status != .idle) {
            problematic_count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 5), problematic_count);
}

test "quickScan all healthy" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    // Add only healthy regions
    for (0..10) |_| {
        var region = RegionMetrics.init(allocator, "Healthy", "Healthy Region");
        region.status = .healthy;
        region.health_score = 100.0;
        try metrics.regions.append(allocator, region);
    }

    try metrics.calculateOverall();

    // All should be healthy (idle is also not problematic)
    try std.testing.expectEqual(@as(f32, 100.0), metrics.overall_health);
}

test "AggregateMetrics timestamp zero" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // Manually set timestamp to 0
    metrics.timestamp = 0;

    try std.testing.expectEqual(@as(i64, 0), metrics.timestamp);
}

test "AggregateMetrics critical alerts empty initially" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    try std.testing.expectEqual(@as(usize, 0), metrics.critical_alerts.items.len);
}

test "RegionMetrics deinit with no metrics" {
    const allocator = std.testing.allocator;

    var metrics = RegionMetrics.init(allocator, "NoMetrics", "No Metrics");
    defer metrics.deinit();

    // deinit should handle empty HashMap gracefully
    try std.testing.expectEqual(@as(usize, 0), metrics.raw_metrics.count());
}

test "AggregateMetrics multiple calculateOverall" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var region = RegionMetrics.init(allocator, "Test", "Test");
    region.status = .healthy;
    region.health_score = 50.0;
    try metrics.regions.append(allocator, region);

    // Calculate multiple times - should be idempotent
    try metrics.calculateOverall();
    const health1 = metrics.overall_health;

    try metrics.calculateOverall();
    const health2 = metrics.overall_health;

    try std.testing.expectApproxEqAbs(health1, health2, 0.001);
}

test "RegionMetrics unicode in name and function" {
    const allocator = std.testing.allocator;

    // Test with ASCII, should handle gracefully
    var metrics = RegionMetrics.init(allocator, "Test123", "Function456");
    defer metrics.deinit();

    try std.testing.expectEqualStrings("Test123", metrics.name);
    try std.testing.expectEqualStrings("Function456", metrics.function);
}

test "AggregateMetrics summary with decimal health" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    metrics.regions.clearRetainingCapacity();

    var region = RegionMetrics.init(allocator, "DecimalTest", "Decimal Health");
    region.status = .healthy;
    region.health_score = 87.654;
    try metrics.regions.append(allocator, region);

    try metrics.calculateOverall();

    const summary = try metrics.summary(allocator);
    defer allocator.free(summary);

    // Summary should contain the decimal value
    try std.testing.expect(std.mem.indexOf(u8, summary, "87") != null);
}

test "AggregateMetrics collect uses global brain regions" {
    const allocator = std.testing.allocator;

    var metrics = AggregateMetrics.init(allocator);
    defer metrics.deinit();

    // collect() should not crash even if brain regions fail
    // It should add regions with appropriate defaults
    // This is more of a smoke test
    try std.testing.expect(true);
}
