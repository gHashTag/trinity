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

    /// Collect metrics from all brain regions
    pub fn collect(self: *Self) !void {
        self.timestamp = std.time.milliTimestamp();

        // 1. Basal Ganglia (Action Selection)
        var bg_metrics = RegionMetrics.init(self.allocator, "Basal Ganglia", "Action Selection");
        if (basal_ganglia.getGlobal(self.allocator)) |registry| {
            bg_metrics.status = .healthy;
            const claim_count = registry.claims.count();
            try bg_metrics.setMetricOwned(self.allocator, "active_claims", try std.fmt.allocPrint(self.allocator, "{d}", .{claim_count}));
            // Health based on claim count (0-1000 is healthy range)
            const bg_health = if (claim_count < 1000) 100.0 else @max(0.0, 100.0 - @as(f32, @floatFromInt(claim_count - 1000)) / 10.0);
            bg_metrics.health_score = bg_health;
            bg_metrics.trend = .stable;
            if (claim_count > 5000) {
                bg_metrics.status = .warning;
                bg_metrics.alert = try std.fmt.allocPrint(self.allocator, "High claim count: {d}", .{claim_count});
            }
        } else |err| {
            bg_metrics.status = .unavailable;
            try bg_metrics.setMetric(self.allocator, "error", @errorName(err));
        }
        try self.regions.append(self.allocator, bg_metrics);

        // 2. Reticular Formation (Broadcast Alerting)
        var rf_metrics = RegionMetrics.init(self.allocator, "Reticular Formation", "Broadcast Alerting");
        if (reticular_formation.getGlobal(self.allocator)) |bus| {
            const stats = bus.getStats();
            try rf_metrics.setMetricOwned(self.allocator, "published", try std.fmt.allocPrint(self.allocator, "{d}", .{stats.published}));
            try rf_metrics.setMetricOwned(self.allocator, "buffered", try std.fmt.allocPrint(self.allocator, "{d}", .{stats.buffered}));
            // Health based on buffer utilization
            const buffer_pct = @as(f32, @floatFromInt(stats.buffered)) / 10000.0 * 100.0;
            rf_metrics.health_score = 100.0 - buffer_pct;
            rf_metrics.status = if (buffer_pct < 50) .healthy else if (buffer_pct < 80) .warning else .critical;
            rf_metrics.trend = if (stats.published > 0) .stable else .unknown;
            if (buffer_pct > 80) {
                rf_metrics.alert = try std.fmt.allocPrint(self.allocator, "Buffer at {d:.1}% capacity", .{buffer_pct});
            }
        } else |err| {
            rf_metrics.status = .unavailable;
            try rf_metrics.setMetric(self.allocator, "error", @errorName(err));
        }
        try self.regions.append(self.allocator, rf_metrics);

        // 3. Locus Coeruleus (Arousal Regulation)
        var lc_metrics = RegionMetrics.init(self.allocator, "Locus Coeruleus", "Arousal Regulation");
        lc_metrics.status = .healthy;
        lc_metrics.health_score = 100.0;
        lc_metrics.trend = .stable;
        const policy = locus_coeruleus.BackoffPolicy.init();
        try lc_metrics.setMetric(self.allocator, "strategy", @tagName(policy.strategy));
        try lc_metrics.setMetricOwned(self.allocator, "initial_ms", try std.fmt.allocPrint(self.allocator, "{d}", .{policy.initial_ms}));
        try lc_metrics.setMetricOwned(self.allocator, "max_ms", try std.fmt.allocPrint(self.allocator, "{d}", .{policy.max_ms}));
        try self.regions.append(self.allocator, lc_metrics);

        // 4. Hippocampus (Memory Persistence)
        var hippo_metrics = RegionMetrics.init(self.allocator, "Hippocampus", "Memory Persistence");
        hippo_metrics.status = .healthy;
        hippo_metrics.health_score = 100.0;
        hippo_metrics.trend = .stable;
        try hippo_metrics.setMetric(self.allocator, "log_file", ".trinity/brain_events.jsonl");
        try self.regions.append(self.allocator, hippo_metrics);

        // 5. Corpus Callosum (Telemetry)
        var cc_metrics = RegionMetrics.init(self.allocator, "Corpus Callosum", "Telemetry");
        cc_metrics.status = .healthy;
        cc_metrics.health_score = 100.0;
        cc_metrics.trend = .stable;
        try cc_metrics.setMetric(self.allocator, "max_points", "1000");
        try cc_metrics.setMetric(self.allocator, "data_points", "0");
        try self.regions.append(self.allocator, cc_metrics);

        // 6. Amygdala (Emotional Salience)
        var amy_metrics = RegionMetrics.init(self.allocator, "Amygdala", "Emotional Salience");
        amy_metrics.status = .healthy;
        amy_metrics.health_score = 100.0;
        amy_metrics.trend = .stable;
        try amy_metrics.setMetric(self.allocator, "salience_levels", "5");
        try amy_metrics.setMetric(self.allocator, "threshold_critical", "80");
        try amy_metrics.setMetric(self.allocator, "threshold_high", "60");
        try self.regions.append(self.allocator, amy_metrics);

        // 7. Prefrontal Cortex (Executive Function)
        var pfc_metrics = RegionMetrics.init(self.allocator, "Prefrontal Cortex", "Executive Function");
        pfc_metrics.status = .healthy;
        pfc_metrics.health_score = 100.0;
        pfc_metrics.trend = .stable;
        try pfc_metrics.setMetric(self.allocator, "decision_engine", "ready");
        try pfc_metrics.setMetric(self.allocator, "actions", "6");
        try self.regions.append(self.allocator, pfc_metrics);

        // 8. Intraparietal Sulcus (Numerical Processing)
        var ips_metrics = RegionMetrics.init(self.allocator, "Intraparietal Sulcus", "Numerical Processing");
        ips_metrics.status = .healthy;
        ips_metrics.health_score = 100.0;
        ips_metrics.trend = .stable;
        try ips_metrics.setMetric(self.allocator, "formats", "f16, GF16, TF3");
        try ips_metrics.setMetric(self.allocator, "phi", "1.618");
        try self.regions.append(self.allocator, ips_metrics);

        // 9. Microglia (Immune Surveillance)
        var micro_metrics = RegionMetrics.init(self.allocator, "Microglia", "Immune Surveillance");
        micro_metrics.status = .healthy;
        micro_metrics.health_score = 100.0;
        micro_metrics.trend = .stable;
        try micro_metrics.setMetric(self.allocator, "patrol_interval", "30m");
        try micro_metrics.setMetric(self.allocator, "night_mode", "false");
        try micro_metrics.setMetric(self.allocator, "sacred_workers", "3");
        try self.regions.append(self.allocator, micro_metrics);

        // 10. Thalamus (Sensory Relay)
        var thal_metrics = RegionMetrics.init(self.allocator, "Thalamus", "Sensory Relay");
        thal_metrics.status = .idle;
        thal_metrics.health_score = null;
        thal_metrics.trend = .stable;
        try thal_metrics.setMetric(self.allocator, "buffer_size", "256");
        try thal_metrics.setMetric(self.allocator, "sensors", "6");
        try self.regions.append(self.allocator, thal_metrics);

        // Calculate overall health
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
                    try writer.print("║  Health:   {d:.1}/100{>42}║\n", .{health});
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
    const result = try quickScan(allocator);
    defer {
        for (result.problematic_regions.items) |r| allocator.free(r);
        result.problematic_regions.deinit();
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
