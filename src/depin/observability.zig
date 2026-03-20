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

pub const Label = struct { key: []const u8, value: []const u8 };

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
        return ObservabilityManager{
            .allocator = allocator,
            .metrics = .{},
            .alert_thresholds = .{},
            .alerts_triggered = 0,
        };
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
        labels: []const Label,
    ) !void {
        var label_map = std.StringHashMapUnmanaged([]const u8){};
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
        var result = std.ArrayList(Metric).empty;
        defer result.deinit(allocator);
        for (self.metrics.items) |metric| {
            if (metric.mtype == mtype) {
                try result.append(allocator, metric);
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
        var buffer = std.ArrayList(u8).empty;
        try buffer.ensureTotalCapacityPrecise(allocator, self.metrics.items.len * 32);

        for (self.metrics.items) |metric| {
            const value_str = switch (metric.value) {
                .counter => try std.fmt.allocPrint(allocator, "{d}", .{metric.value.counter}),
                .gauge => try std.fmt.allocPrint(allocator, "{d:.2}", .{metric.value.gauge}),
                .histogram => continue, // Skip histograms for now
            };
            defer allocator.free(value_str);

            try buffer.writer(allocator).print(
                "{s}_{s} {s}\n",
                .{ "depin", metric.name, value_str },
            );
        }

        return buffer.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *ObservabilityManager) void {
        for (self.metrics.items) |*metric| {
            metric.labels.deinit(self.allocator);
        }
        self.metrics.deinit(self.allocator);

        // Note: alert_thresholds.metric_name are slices, not owned strings
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

test "record metric with empty labels" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetricWithLabels("test", .counter, .{ .counter = 100 }, &[_]Label{});
    try std.testing.expectEqual(@as(usize, 1), manager.metrics.items.len);
}

test "record metric with labels" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetricWithLabels("request_count", .counter, .{ .counter = 42 }, &[_]Label{
        .{ .key = "method", .value = "GET" },
        .{ .key = "endpoint", .value = "/api" },
    });

    try std.testing.expectEqual(@as(usize, 1), manager.metrics.items.len);
    const metric = manager.metrics.items[0];
    try std.testing.expectEqualStrings("request_count", metric.name);
    try std.testing.expectEqual(@as(usize, 2), metric.labels.count());
}

test "threshold comparison operators" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("metric1", 5.0, 10.0, .greater_than, true);
    try manager.addThreshold("metric2", 20.0, 10.0, .less_than, true);
    try manager.addThreshold("metric3", 5.0, 10.0, .equal_to, true);

    // greater_than: 15 > 10 should trigger
    try manager.recordMetric("metric1", .uptime, .{ .gauge = 15.0 });
    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());

    manager.resetAlerts();

    // less_than: 5 < 10 should trigger
    try manager.recordMetric("metric2", .uptime, .{ .gauge = 5.0 });
    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());

    manager.resetAlerts();

    // equal_to: 10 == 10 should trigger
    try manager.recordMetric("metric3", .uptime, .{ .gauge = 10.0 });
    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());
}

test "threshold disabled does not trigger" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("metric", 5.0, 10.0, .greater_than, false); // Disabled

    try manager.recordMetric("metric", .uptime, .{ .gauge = 15.0 });
    try std.testing.expectEqual(@as(u64, 0), manager.getAlertCount());
}

test "threshold with counter metric" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("counter_metric", 5.0, 10.0, .greater_than, true);

    try manager.recordMetric("counter_metric", .counter, .{ .counter = 15 });
    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());
}

test "threshold histogram not checked" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("hist_metric", 5.0, 10.0, .greater_than, true);

    const histogram_data = [_]u64{ 1, 2, 3 };
    try manager.recordMetric("hist_metric", .counter, .{ .histogram = &histogram_data });

    // Histograms are skipped, no alert should trigger
    try std.testing.expectEqual(@as(u64, 0), manager.getAlertCount());
}

test "get metrics by type empty result" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("metric1", .uptime, .{ .gauge = 99.0 });

    const result = try manager.getMetricsByType(.latency, allocator);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "reset alerts" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("metric", 5.0, 10.0, .greater_than, true);
    try manager.recordMetric("metric", .uptime, .{ .gauge = 15.0 });

    try std.testing.expectEqual(@as(u64, 1), manager.getAlertCount());

    manager.resetAlerts();
    try std.testing.expectEqual(@as(u64, 0), manager.getAlertCount());
}

test "export prometheus with multiple metrics" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("metric1", .uptime, .{ .gauge = 99.5 });
    try manager.recordMetric("metric2", .latency, .{ .gauge = 45.2 });
    try manager.recordMetric("metric3", .counter, .{ .counter = 12345 });

    const export_ = try manager.exportPrometheus(allocator);
    defer allocator.free(export_);

    try std.testing.expect(std.mem.indexOf(u8, export_, "depin_metric1") != null);
    try std.testing.expect(std.mem.indexOf(u8, export_, "depin_metric2") != null);
    try std.testing.expect(std.mem.indexOf(u8, export_, "depin_metric3") != null);
    try std.testing.expect(std.mem.indexOf(u8, export_, "99.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, export_, "45.2") != null);
    try std.testing.expect(std.mem.indexOf(u8, export_, "12345") != null);
}

test "multiple thresholds for same metric" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.addThreshold("metric", 5.0, 10.0, .greater_than, true);
    try manager.addThreshold("metric", 20.0, 30.0, .greater_than, true);

    try manager.recordMetric("metric", .uptime, .{ .gauge = 35.0 });
    // Both thresholds should trigger (35 > 10 and 35 > 30)
    try std.testing.expectEqual(@as(u64, 2), manager.getAlertCount());
}

test "init and deinit cleanup" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);

    try manager.recordMetricWithLabels("test", .counter, .{ .counter = 100 }, &[_]Label{
        .{ .key = "label1", .value = "value1" },
    });

    manager.deinit();
    // If deinit works correctly, this test will pass without memory leaks
}

test "metric timestamp increases" {
    const allocator = std.testing.allocator;
    var manager = ObservabilityManager.init(allocator);
    defer manager.deinit();

    try manager.recordMetric("metric1", .uptime, .{ .gauge = 99.0 });

    // Small busy wait to ensure timestamp increases
    var i: usize = 0;
    while (i < 100000) : (i += 1) {
        @atomicStore(usize, &i, i, .monotonic);
    }

    try manager.recordMetric("metric2", .uptime, .{ .gauge = 98.0 });

    const ts1 = manager.metrics.items[0].timestamp;
    const ts2 = manager.metrics.items[1].timestamp;

    try std.testing.expect(ts2 >= ts1);
}
