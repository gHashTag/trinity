// @origin(spec:depin_observability.tri) @regen(manual-impl)
// ═════════════════════════════════════════════════════════════════════════════════════
// Phase 5: Advanced Monitoring & Observability
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═════════════════════════════════════════════════════════════════════════════════════════
// METRIC TYPES
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const MetricType = enum {
    uptime,
    latency,
    success_rate,
    active_nodes,
    total_staked,
    slashing_events,
    delegation_count,
    counter,
};

pub const MetricValue = union(enum) {
    counter: u64,
    gauge: f64,
    histogram: []const u64,
};

pub const Metric = struct {
    name: []const u8,
    mtype: MetricType,
    value: MetricValue,
    timestamp: i64,
    labels: std.StringHashMapUnmanaged([]const u8),
};

pub const Comparison = enum {
    greater_than,
    less_than,
    equal_to,
};

pub const AlertThreshold = struct {
    metric_name: []const u8,
    warning_threshold: f64,
    critical_threshold: f64,
    comparison: Comparison,
    enabled: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// OBSERVABILITY MANAGER
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

pub const ObservabilityManager = struct {
    allocator: Allocator,
    metrics: std.ArrayListUnmanaged(Metric),
    alert_thresholds: std.ArrayListUnmanaged(AlertThreshold),
    alerts_triggered: u64,

    // Default thresholds
    const UPTIME_WARNING: f64 = 99.5; // %
    const UPTIME_CRITICAL: f64 = 99.0; // %
    const LATENCY_WARNING: f64 = 100.0; // ms
    const LATENCY_CRITICAL: f64 = 500.0; // ms
    const SUCCESS_RATE_WARNING: f64 = 0.95; // 95%
    const SUCCESS_RATE_CRITICAL: f64 = 0.90; // 90%

    pub fn init(allocator: Allocator) ObservabilityManager {
        var manager = ObservabilityManager{
            .allocator = allocator,
            .metrics = .{},
            .alert_thresholds = .{},
            .alerts_triggered = 0,
        };

        // Add default thresholds (ignore errors - these are hardcoded valid values)
        _ = manager.addThreshold("uptime_pct", UPTIME_WARNING, UPTIME_CRITICAL, .less_than, true);
        _ = manager.addThreshold("latency_avg_ms", LATENCY_WARNING, LATENCY_CRITICAL, .greater_than, true);
        _ = manager.addThreshold("success_rate", SUCCESS_RATE_WARNING, SUCCESS_RATE_CRITICAL, .less_than, true);

        return manager;
    }

    /// Record a metric
    pub fn recordMetric(self: *ObservabilityManager, name: []const u8, mtype: MetricType, value: MetricValue) !void {
        const metric = Metric{
            .name = name,
            .mtype = mtype,
            .value = value,
            .timestamp = std.time.timestamp(),
            .labels = .{},
        };
        try self.metrics.append(self.allocator, metric);

        // Check alert thresholds
        self.checkThresholds(metric);
    }

    /// Record a metric with labels
    pub fn recordMetricWithLabels(
        self: *ObservabilityManager,
        name: []const u8,
        mtype: MetricType,
        value: MetricValue,
        labels: []const struct { []const u8, []const u8 },
    ) !void {
        var label_map = std.StringHashMapUnmanaged([]const u8).init(self.allocator);
        for (labels) |label| {
            try label_map.put(self.allocator, label.key, label.value);
        }

        const metric = Metric{
            .name = name,
            .mtype = mtype,
            .value = value,
            .timestamp = std.time.timestamp(),
            .labels = label_map,
        };
        try self.metrics.append(self.allocator, metric);

        self.checkThresholds(metric);
    }

    /// Add alert threshold
    pub fn addThreshold(
        self: *ObservabilityManager,
        metric_name: []const u8,
        warning: f64,
        critical: f64,
        comparison: Comparison,
        enabled: bool,
    ) !void {
        const threshold = AlertThreshold{
            .metric_name = metric_name,
            .warning_threshold = warning,
            .critical_threshold = critical,
            .comparison = comparison,
            .enabled = enabled,
        };
        try self.alert_thresholds.append(self.allocator, threshold);
    }

    /// Check if any threshold is triggered
    fn checkThresholds(self: *ObservabilityManager, metric: Metric) void {
        for (self.alert_thresholds.items) |threshold| {
            if (!threshold.enabled) continue;
            if (!std.mem.eql(u8, threshold.metric_name, metric.name)) continue;

            const value = switch (metric.value) {
                .counter => @as(f64, @floatFromInt(metric.value.counter)),
                .gauge => metric.value.gauge,
                .histogram => return, // Histograms need special handling
            };

            const triggered = switch (threshold.comparison) {
                .greater_than => value > threshold.critical_threshold,
                .less_than => value < threshold.critical_threshold,
                .equal_to => value == threshold.critical_threshold,
            };

            if (triggered) {
                self.alerts_triggered += 1;
                std.log.warn("ALERT: {s} = {d:.2} exceeds threshold {d:.2}", .{
                    metric.name, value, threshold.critical_threshold,
                });
            }
        }
    }

    /// Get metrics by type
    pub fn getMetricsByType(self: *const ObservabilityManager, mtype: MetricType, allocator: Allocator) ![]Metric {
        var result = std.ArrayList(Metric).init(allocator);
        defer result.deinit();
        for (self.metrics.items) |metric| {
            if (metric.mtype == mtype) {
                try result.append(metric);
            }
        }
        return result.toOwnedSlice(allocator);
    }

    /// Get alert count
    pub fn getAlertCount(self: *const ObservabilityManager) u64 {
        return self.alerts_triggered;
    }

    /// Reset alert counter
    pub fn resetAlerts(self: *ObservabilityManager) void {
        self.alerts_triggered = 0;
    }

    /// Export metrics in Prometheus format
    pub fn exportPrometheus(self: *const ObservabilityManager, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);

        for (self.metrics.items) |metric| {
            const value_str = switch (metric.value) {
                .counter => try std.fmt.allocPrint(allocator, "{d}", .{metric.value.counter}),
                .gauge => try std.fmt.allocPrint(allocator, "{d:.2}", .{metric.value.gauge}),
                .histogram => continue, // Skip histograms for now
            };

            try buffer.writer().print(
                "{s}_{d} {s}\n",
                .{ "depin", metric.name, value_str },
            );
        }

        return buffer.toOwnedSlice();
    }

    pub fn deinit(self: *ObservabilityManager) void {
        for (self.metrics.items) |*metric| {
            metric.labels.deinit(self.allocator);
        }
        self.metrics.deinit(self.allocator);

        for (self.alert_thresholds.items) |*threshold| {
            self.allocator.free(threshold.metric_name);
        }
        self.alert_thresholds.deinit(self.allocator);
    }
};

// ═════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "record metric" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("test_counter", .uptime, .{ .counter = 42 });
    try manager.recordMetric("test_gauge", .uptime, .{ .gauge = 99.9 });

    try std.testing.expectEqual(@as(usize, 2), manager.metrics.items.len);
}

test "threshold warning" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    // Set threshold to trigger on value > 10
    try manager.addThreshold("test_metric", 5.0, 10.0, .greater_than, true);

    // Record value 15 - should trigger alert
    try manager.recordMetric("test_metric", .uptime, .{ .gauge = 15.0 });

    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());
}

test "export prometheus" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("node1_uptime", .uptime, .{ .gauge = 99.5 });
    try manager.recordMetric("node1_latency", .latency, .{ .gauge = 45.2 });

    const export_ = try manager.exportPrometheus(allocator);
    defer allocator.free(export_);

    try std.testing.expect(std.mem.indexOf(u8, export_, "depin_node1_uptime") != null);
}

test "get metrics by type" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("uptime1", .uptime, .{ .gauge = 99.0 });
    try manager.recordMetric("latency1", .latency, .{ .gauge = 50.0 });

    const uptime_metrics = try manager.getMetricsByType(.uptime, allocator);
    defer allocator.free(uptime_metrics);

    try std.testing.expectEqual(@as(usize, 1), uptime_metrics.len);
}
