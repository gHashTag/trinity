//! MCP Metrics Module
//!
//! Prometheus + OpenTelemetry metrics for enterprise monitoring.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const atomic = std.atomic;

/// Metric types
pub const MetricType = enum {
    counter,
    gauge,
    histogram,
    summary,
};

/// Metric label
pub const Label = struct {
    name: []const u8,
    value: []const u8,
};

/// Metric interface
pub const Metric = struct {
    name: []const u8,
    description: []const u8,
    metric_type: MetricType,
    labels: []const Label,

    pub fn formatPrometheus(self: *const Metric, writer: anytype) !void {
        // Help comment
        try writer.print("# HELP {s} {s}\n", .{ self.name, self.description });

        // Type comment
        const type_str = switch (self.metric_type) {
            .counter => "counter",
            .gauge => "gauge",
            .histogram => "histogram",
            .summary => "summary",
        };
        try writer.print("# TYPE {s} {s}\n", .{ self.name, type_str });

        // Metric with labels
        try writer.print("{s}", .{self.name});
        if (self.labels.len > 0) {
            try writer.writeAll("{");
            for (self.labels, 0..) |label, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.print("{s}=\"{s}\"", .{ label.name, label.value });
            }
            try writer.writeAll("}");
        }
    }
};

/// Counter metric (monotonically increasing)
pub const Counter = struct {
    name: []const u8,
    description: []const u8,
    value: atomic.Value(u64),
    labels: []const Label,

    pub fn init(name: []const u8, description: []const u8) Counter {
        return .{
            .name = name,
            .description = description,
            .value = atomic.Value(u64).init(0),
            .labels = &.{},
        };
    }

    pub fn inc(self: *Counter) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn incBy(self: *Counter, amount: u64) void {
        _ = self.value.fetchAdd(amount, .monotonic);
    }

    pub fn get(self: *Counter) u64 {
        return self.value.load(.monotonic);
    }

    pub fn format(self: *const Counter, writer: anytype) !void {
        const base = Metric{
            .name = self.name,
            .description = self.description,
            .metric_type = .counter,
            .labels = self.labels,
        };
        try base.formatPrometheus(writer);
        try writer.print(" {d}\n", .{self.get()});
    }
};

/// Gauge metric (can go up or down)
pub const Gauge = struct {
    name: []const u8,
    description: []const u8,
    value: atomic.Value(f64),
    labels: []const Label,

    pub fn init(name: []const u8, description: []const u8) Gauge {
        return .{
            .name = name,
            .description = description,
            .value = atomic.Value(f64).init(0),
            .labels = &.{},
        };
    }

    pub fn set(self: *Gauge, value: f64) void {
        self.value.store(value, .monotonic);
    }

    pub fn inc(self: *Gauge, delta: f64) void {
        _ = self.value.fetchAdd(delta, .monotonic);
    }

    pub fn dec(self: *Gauge, delta: f64) void {
        _ = self.value.fetchSub(delta, .monotonic);
    }

    pub fn get(self: *Gauge) f64 {
        return self.value.load(.monotonic);
    }

    pub fn format(self: *const Gauge, writer: anytype) !void {
        const base = Metric{
            .name = self.name,
            .description = self.description,
            .metric_type = .gauge,
            .labels = self.labels,
        };
        try base.formatPrometheus(writer);
        try writer.print(" {d:.2}\n", .{self.get()});
    }
};

/// Histogram metric (distribution)
pub const Histogram = struct {
    name: []const u8,
    description: []const u8,
    buckets: []const f64,
    counts: []atomic.Value(u64),
    sum: atomic.Value(f64),
    count: atomic.Value(u64),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, description: []const u8) !Histogram {
        const default_buckets = [_]f64{ 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 };
        const buckets = try allocator.dupe(f64, &default_buckets);

        var counts = try allocator.alloc(atomic.Value(u64), buckets.len + 1);
        for (&counts) |*c| {
            c.* = atomic.Value(u64).init(0);
        }

        return .{
            .name = name,
            .description = description,
            .buckets = buckets,
            .counts = counts,
            .sum = atomic.Value(f64).init(0),
            .count = atomic.Value(u64).init(0),
        };
    }

    pub fn observe(self: *Histogram, value: f64) void {
        _ = self.sum.fetchAdd(value, .monotonic);
        _ = self.count.fetchAdd(1, .monotonic);

        for (self.buckets, 0..) |bucket, i| {
            if (value <= bucket) {
                _ = self.counts[i].fetchAdd(1, .monotonic);
                break;
            }
        }
        // Last bucket is +Inf
        _ = self.counts[self.counts.len - 1].fetchAdd(1, .monotonic);
    }

    pub fn format(self: *const Histogram, writer: anytype) !void {
        // Print bucket definitions
        try writer.print("# HELP {s} {s}\n", .{ self.name, self.description });
        try writer.print("# TYPE {s} histogram\n", .{self.name});

        // Print buckets
        for (self.buckets, 0..) |bucket, i| {
            try writer.print("{s}_bucket{{le=\"{d:.3}\"}} {d}\n", .{ self.name, bucket, self.counts[i].load(.monotonic) });
        }
        // +Inf bucket
        try writer.print("{s}_bucket{{le=\"+Inf\"}} {d}\n", .{ self.name, self.counts[self.counts.len - 1].load(.monotonic) });

        // Print sum and count
        try writer.print("{s}_sum {d:.6}\n", .{ self.name, self.sum.load(.monotonic) });
        try writer.print("{s}_count {d}\n", .{ self.name, self.count.load(.monotonic) });
    }
};

/// Metrics registry
pub const MetricsRegistry = struct {
    allocator: std.mem.Allocator,
    counters: std.StringHashMap(*Counter),
    gauges: std.StringHashMap(*Gauge),
    histograms: std.StringHashMap(*Histogram),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) MetricsRegistry {
        return .{
            .allocator = allocator,
            .counters = std.StringHashMap(*Counter).init(allocator),
            .gauges = std.StringHashMap(*Gauge).init(allocator),
            .histograms = std.StringHashMap(*Histogram).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn registerCounter(self: *MetricsRegistry, name: []const u8, description: []const u8) !*Counter {
        self.mutex.lock();
        defer self.mutex.unlock();

        const counter = try self.allocator.create(Counter);
        counter.* = Counter.init(name, description);
        try self.counters.put(name, counter);
        return counter;
    }

    pub fn registerGauge(self: *MetricsRegistry, name: []const u8, description: []const u8) !*Gauge {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gauge = try self.allocator.create(Gauge);
        gauge.* = Gauge.init(name, description);
        try self.gauges.put(name, gauge);
        return gauge;
    }

    pub fn registerHistogram(self: *MetricsRegistry, name: []const u8, description: []const u8) !*Histogram {
        self.mutex.lock();
        defer self.mutex.unlock();

        const histogram = try self.allocator.create(Histogram);
        histogram.* = try Histogram.init(self.allocator, name, description);
        try self.histograms.put(name, histogram);
        return histogram;
    }

    /// Export all metrics in Prometheus format
    pub fn exportPrometheus(self: *MetricsRegistry, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Counters
        var counter_iter = self.counters.iterator();
        while (counter_iter.next()) |entry| {
            try entry.value_ptr.*.format(writer);
        }

        // Gauges
        var gauge_iter = self.gauges.iterator();
        while (gauge_iter.next()) |entry| {
            try entry.value_ptr.*.format(writer);
        }

        // Histograms
        var hist_iter = self.histograms.iterator();
        while (hist_iter.next()) |entry| {
            try entry.value_ptr.*.format(writer);
        }
    }
};

// Global metrics registry
var global_registry: ?MetricsRegistry = null;
var registry_init = std.Thread.Once{};

/// Get global metrics registry
pub fn getRegistry() !*MetricsRegistry {
    const init_fn = struct {
        fn init_() void {
            global_registry = MetricsRegistry.init(std.heap.page_allocator);
        }
    };

    registry_init.call(init_fn.init_);
    return &global_registry orelse error.RegistryNotInitialized;
}

/// Pre-defined MCP metrics
pub const Metrics = struct {
    pub var mcp_requests_total: *Counter = undefined;
    pub var mcp_requests_duration: *Histogram = undefined;
    pub var mcp_active_connections: *Gauge = undefined;
    pub var mcp_tools_executed: *Counter = undefined;
    pub var mcp_errors_total: *Counter = undefined;

    /// Initialize all metrics
    pub fn init(allocator: std.mem.Allocator) !void {
        _ = &allocator;
        const registry = try getRegistry();

        Metrics.mcp_requests_total = try registry.registerCounter("mcp_requests_total", "Total number of MCP requests received");

        Metrics.mcp_requests_duration = try registry.registerHistogram("mcp_requests_duration_seconds", "MCP request duration in seconds");

        Metrics.mcp_active_connections = try registry.registerGauge("mcp_active_connections", "Number of active MCP connections");

        Metrics.mcp_tools_executed = try registry.registerCounter("mcp_tools_executed_total", "Total number of MCP tools executed");

        Metrics.mcp_errors_total = try registry.registerCounter("mcp_errors_total", "Total number of MCP errors");
    }
};
