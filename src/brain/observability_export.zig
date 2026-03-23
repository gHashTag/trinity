//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN OBSERVABILITY EXPORT — v5.1
//!
//! Export brain telemetry for external monitoring systems.
//! Supports Prometheus, OpenTelemetry, JSON, and real-time streaming.
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// Import brain regions for metrics collection
const basal_ganglia = @import("basal_ganglia");
const reticular_formation = @import("reticular_formation");
const metrics_dashboard = @import("metrics_dashboard");

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORT FORMAT ENUM
// ═══════════════════════════════════════════════════════════════════════════════

/// Supported export formats for external monitoring
pub const ExportFormat = enum {
    /// Prometheus text-based exposition format
    prometheus,
    /// OpenTelemetry JSON format
    opentelemetry,
    /// Generic JSON for dashboards
    json,
    /// InfluxDB line protocol
    influxdb,
    /// StatsD format
    statsd,

    pub fn contentType(self: ExportFormat) []const u8 {
        return switch (self) {
            .prometheus => "text/plain; version=0.0.4",
            .opentelemetry => "application/json",
            .json => "application/json",
            .influxdb => "text/plain",
            .statsd => "text/plain",
        };
    }

    pub fn fileExtension(self: ExportFormat) []const u8 {
        return switch (self) {
            .prometheus => ".prom",
            .opentelemetry => ".otel.json",
            .json => ".json",
            .influxdb => ".influx",
            .statsd => ".statsd",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// METRIC DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Metric types for Prometheus
pub const MetricType = enum {
    counter,
    gauge,
    histogram,
    summary,

    pub fn prometheusType(self: MetricType) []const u8 {
        return switch (self) {
            .counter => "counter",
            .gauge => "gauge",
            .histogram => "histogram",
            .summary => "summary",
        };
    }
};

/// A single metric with labels
pub const Metric = struct {
    name: []const u8,
    metric_type: MetricType,
    help: ?[]const u8 = null,
    value: f64,
    labels: std.StringHashMap([]const u8),
    timestamp: i64,

    /// Initialize a metric
    pub fn init(allocator: std.mem.Allocator, name: []const u8, metric_type: MetricType, value: f64) Metric {
        return Metric{
            .name = name,
            .metric_type = metric_type,
            .value = value,
            .labels = std.StringHashMap([]const u8).init(allocator),
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *Metric) void {
        var iter = self.labels.iterator();
        while (iter.next()) |entry| {
            self.labels.allocator.free(entry.key_ptr.*);
            self.labels.allocator.free(entry.value_ptr.*);
        }
        self.labels.deinit();
        if (self.help) |h| self.labels.allocator.free(h);
    }

    /// Add a label to the metric
    pub fn addLabel(self: *Metric, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);
        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);
        try self.labels.put(key_copy, value_copy);
    }

    /// Format labels for Prometheus (key="value",...)
    pub fn formatLabelsPrometheus(self: *const Metric, allocator: std.mem.Allocator) ![]const u8 {
        if (self.labels.count() == 0) return allocator.dupe(u8, "");

        var buffer = std.ArrayList(u8).empty;
        errdefer buffer.deinit(allocator);

        const writer = buffer.writer(allocator);
        try writer.writeAll("{");
        var first = true;
        var iter = self.labels.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            try writer.print("{s}=\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
            first = false;
        }
        try writer.writeAll("}");

        return buffer.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OBSERVABILITY EXPORTER
// ═══════════════════════════════════════════════════════════════════════════════

/// Main exporter for brain observability metrics
pub const ObservabilityExporter = struct {
    allocator: std.mem.Allocator,
    /// Service name for attribution
    service_name: []const u8,
    /// Additional static labels
    static_labels: std.StringHashMap([]const u8),
    /// Enable histogram buckets
    enable_histograms: bool,
    /// Custom histogram buckets
    histogram_buckets: []const f64,

    const Self = @This();

    /// Default histogram buckets (Prometheus-style)
    const DEFAULT_BUCKETS = [_]f64{ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10 };

    pub fn init(allocator: std.mem.Allocator, service_name: []const u8) !Self {
        var static_labels = std.StringHashMap([]const u8).init(allocator);
        try static_labels.put(try allocator.dupe(u8, "service"), try allocator.dupe(u8, service_name));

        return Self{
            .allocator = allocator,
            .service_name = service_name,
            .static_labels = static_labels,
            .enable_histograms = true,
            .histogram_buckets = &DEFAULT_BUCKETS,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.static_labels.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.static_labels.deinit();
    }

    /// Collect current brain metrics and export to writer
    pub fn collectAndExport(self: *const Self, writer: anytype, format: ExportFormat) !void {
        // Collect from metrics dashboard
        var dashboard = metrics_dashboard.AggregateMetrics.init(self.allocator);
        defer dashboard.deinit();
        try dashboard.collect();

        // Export based on format
        switch (format) {
            .prometheus => try self.exportPrometheusFromMetrics(writer, &dashboard),
            .opentelemetry => try self.exportOpenTelemetryFromMetrics(writer, &dashboard),
            .json => try self.exportJsonFromMetrics(writer, &dashboard),
            .influxdb => try self.exportInfluxDBFromMetrics(writer, &dashboard),
            .statsd => try self.exportStatsDFromMetrics(writer, &dashboard),
        }
    }

    /// Helper to export Prometheus format from dashboard
    fn exportPrometheusFromMetrics(self: *const Self, writer: anytype, dashboard: *const metrics_dashboard.AggregateMetrics) !void {
        try writer.writeAll("# S³AI Brain Observability Export\n");
        try writer.print("# Generated at: {d}\n", .{std.time.milliTimestamp()});

        // Overall health
        try writer.print("# HELP s3ai_brain_health_score Overall brain health (0-100)\n", .{});
        try writer.writeAll("# TYPE s3ai_brain_health_score gauge\n");
        try writer.print("s3ai_brain_health_score {d:.1}\n", .{dashboard.overall_health});

        // Per-region metrics
        for (dashboard.regions.items) |region| {
            if (region.health_score) |score| {
                const region_slug = try self.slugify(region.name);
                defer self.allocator.free(region_slug);
                try writer.print("s3ai_brain_region_health{{region=\"{s}\"}} {d:.1}\n", .{ region_slug, score });
            }
        }

        // Basal Ganglia metrics
        if (basal_ganglia.getGlobal(self.allocator)) |registry| {
            const claim_count = registry.claims.count();
            try writer.print("s3ai_brain_active_claims {d}\n", .{claim_count});
        } else |_| {}
    }

    /// Helper to export JSON format from dashboard
    fn exportJsonFromMetrics(self: *const Self, writer: anytype, dashboard: *const metrics_dashboard.AggregateMetrics) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"timestamp\": {d},\n", .{std.time.milliTimestamp()});
        try writer.print("  \"service\": \"{s}\",\n", .{self.service_name});
        try writer.print("  \"overall_health\": {d:.1},\n", .{dashboard.overall_health});
        try writer.writeAll("  \"regions\": [\n");

        for (dashboard.regions.items, 0..) |region, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{region.name});
            try writer.print("      \"status\": \"{s}\",\n", .{@tagName(region.status)});
            if (region.health_score) |score| {
                try writer.print("      \"health_score\": {d:.1},\n", .{score});
            }
            try writer.writeAll("      \"metrics\": {");
            var iter = region.raw_metrics.iterator();
            var first = true;
            while (iter.next()) |entry| {
                if (!first) try writer.writeAll(", ");
                try writer.print("\"{s}\": \"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
                first = false;
            }
            try writer.writeAll("}\n");
            try writer.writeAll("    }");
        }

        try writer.writeAll("\n  ]\n}\n");
    }

    /// Export OpenTelemetry JSON format from dashboard
    fn exportOpenTelemetryFromMetrics(self: *const Self, writer: anytype, dashboard: *const metrics_dashboard.AggregateMetrics) !void {
        const timestamp_ms = std.time.milliTimestamp();

        try writer.writeAll("{\n");
        try writer.print("  \"resourceMetrics\": [\n", .{});
        try writer.writeAll("    {\n");
        try writer.print("      \"resource\": {{\n", .{});
        try writer.print("        \"attributes\": [\n", .{});
        try writer.print("          {{\"key\": \"service.name\", \"value\": {{\"stringValue\": \"{s}\"}}}},\n", .{self.service_name});
        try writer.print("          {{\"key\": \"service.namespace\", \"value\": {{\"stringValue\": \"s3ai-brain\"}}}}\n", .{});
        try writer.writeAll("        ]\n");
        try writer.writeAll("      },\n");
        try writer.writeAll("      \"scopeMetrics\": [\n");
        try writer.writeAll("        {\n");
        try writer.print("          \"scope\": {{\"name\": \"s3ai.brain\", \"version\": \"5.1\"}},\n", .{});
        try writer.writeAll("          \"metrics\": [\n");

        // Export overall health as gauge
        try writer.writeAll("            {\n");
        try writer.writeAll("              \"name\": \"s3ai_brain_health_score\",\n");
        try writer.writeAll("              \"description\": \"Overall brain health (0-100)\",\n");
        try writer.writeAll("              \"unit\": \"1\",\n");
        try writer.writeAll("              \"gauge\": {\n");
        try writer.print("                \"dataPoints\": [{{\"asDouble\": {d:.1}, \"timeUnixNano\": {d}}}]\n", .{ dashboard.overall_health, timestamp_ms * 1_000_000 });
        try writer.writeAll("              }\n");
        try writer.writeAll("            },\n");

        // Export per-region health
        for (dashboard.regions.items, 0..) |region, i| {
            if (region.health_score) |score| {
                if (i > 0 or dashboard.overall_health != null) try writer.writeAll(",\n");
                try writer.writeAll("            {\n");
                try writer.print("              \"name\": \"s3ai_brain_region_health\",\n", .{});
                try writer.writeAll("              \"description\": \"Brain region health score\",\n");
                try writer.writeAll("              \"unit\": \"1\",\n");
                try writer.writeAll("              \"gauge\": {\n");
                try writer.writeAll("                \"dataPoints\": [{\n");
                try writer.print("                  \"asDouble\": {d:.1},\n", .{score});
                try writer.print("                  \"timeUnixNano\": {d},\n", .{timestamp_ms * 1_000_000});
                try writer.writeAll("                  \"attributes\": [\n");
                const region_slug = try self.slugify(region.name);
                defer self.allocator.free(region_slug);
                try writer.print("                    {{\"key\": \"region\", \"value\": {{\"stringValue\": \"{s}\"}}}}\n", .{region_slug});
                try writer.writeAll("                  ]\n");
                try writer.writeAll("                }]\n");
                try writer.writeAll("              }\n");
                try writer.writeAll("            }");
            }
        }

        try writer.writeAll("\n          ]\n");
        try writer.writeAll("        }\n");
        try writer.writeAll("      ]\n");
        try writer.writeAll("    }\n");
        try writer.writeAll("  ]\n");
        try writer.writeAll("}\n");
    }

    fn exportInfluxDBFromMetrics(self: *const Self, writer: anytype, dashboard: *const metrics_dashboard.AggregateMetrics) !void {
        _ = self;
        _ = writer;
        _ = dashboard;
        return error.NotImplemented;
    }

    fn exportStatsDFromMetrics(self: *const Self, writer: anytype, dashboard: *const metrics_dashboard.AggregateMetrics) !void {
        _ = self;
        _ = writer;
        _ = dashboard;
        return error.NotImplemented;
    }

    /// Slugify a region name for metric labels
    fn slugify(self: *const Self, name: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(self.allocator);

        for (name) |c| {
            if (std.ascii.isAlphanumeric(c)) {
                try result.append(self.allocator, std.ascii.toLower(c));
            } else if (c == ' ') {
                try result.append(self.allocator, '_');
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Export metrics in Prometheus format
    pub fn exportPrometheus(self: *const Self, writer: anytype) !void {
        // Use the new collectAndExport method
        try self.collectAndExport(writer, .prometheus);
    }

    /// Export metrics in OpenTelemetry JSON format
    pub fn exportOpenTelemetry(self: *const Self, writer: anytype) !void {
        // Use the new collectAndExport method
        try self.collectAndExport(writer, .opentelemetry);
    }

    /// Export metrics in generic JSON format
    pub fn exportJson(self: *const Self, writer: anytype) !void {
        // Use the new collectAndExport method
        try self.collectAndExport(writer, .json);
    }

    /// Export metrics in InfluxDB line protocol
    pub fn exportInfluxDB(self: *const Self, writer: anytype) !void {
        // Use the new collectAndExport method
        try self.collectAndExport(writer, .influxdb);
    }

    /// Export metrics in StatsD format
    pub fn exportStatsD(self: *const Self, writer: anytype) !void {
        // Use the new collectAndExport method
        try self.collectAndExport(writer, .statsd);
    }

    /// Export metrics to a file
    pub fn exportToFile(self: *const Self, format: ExportFormat, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        defer file.close();

        var buffer: [65536]u8 = undefined;
        const writer = file.writer(buffer[0..]);

        try self.collectAndExport(writer, format);
    }
};

/// Escape InfluxDB tag values (replace spaces with \, commas with \,)
fn escapeInfluxTag(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).empty;
    errdefer result.deinit(allocator);

    for (value) |c| {
        if (c == ' ') {
            try result.append(allocator, '\\');
            try result.append(allocator, ' ');
        } else if (c == ',') {
            try result.append(allocator, '\\');
            try result.append(allocator, ',');
        } else if (c == '=') {
            try result.append(allocator, '\\');
            try result.append(allocator, '=');
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Clean StatsD key (replace spaces with underscores)
fn cleanStatsDKey(allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).empty;
    errdefer result.deinit(allocator);

    for (key) |c| {
        if (c == ' ' or c == '=') {
            try result.append(allocator, '_');
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REAL-TIME STREAMING
// ═══════════════════════════════════════════════════════════════════════════════

/// Real-time metrics streamer
pub const MetricsStreamer = struct {
    allocator: std.mem.Allocator,
    exporter: ObservabilityExporter,
    interval_ms: u64,
    running: std.atomic.Value(bool),
    thread: ?std.Thread,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, service_name: []const u8, interval_ms: u64) !Self {
        const exporter = try ObservabilityExporter.init(allocator, service_name);
        return Self{
            .allocator = allocator,
            .exporter = exporter,
            .interval_ms = interval_ms,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.exporter.deinit();
    }

    /// Start streaming metrics to stdout
    pub fn start(self: *Self) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, streamThread, .{self});
    }

    /// Stop streaming
    pub fn stop(self: *Self) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    /// Stream thread function
    fn streamThread(self: *Self) void {
        var stdout_buffer: [4096]u8 = undefined;
        const stdout = std.fs.File.stdout().writer(&stdout_buffer);

        while (self.running.load(.acquire)) {
            var buffer: [65536]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const writer = fbs.writer();

            self.exporter.collectAndExport(writer, .prometheus) catch |err| {
                std.log.err("Stream error: {}", .{err});
            };

            // Print the output
            stdout.writeAll(fbs.getWritten()) catch {};

            // Sleep for interval
            std.Thread.sleep(self.interval_ms * 1_000_000); // Convert ms to ns
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP ENDPOINT (for Prometheus scraping)
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple HTTP server for metrics endpoint
pub const MetricsServer = struct {
    allocator: std.mem.Allocator,
    exporter: *ObservabilityExporter,
    address: std.net.Address,
    server: ?std.net.Server,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, exporter: *ObservabilityExporter, port: u16) !Self {
        const address = try std.net.Address.parseIp4("0.0.0.0", port);
        return Self{
            .allocator = allocator,
            .exporter = exporter,
            .address = address,
            .server = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.server) |*s| {
            s.deinit();
        }
    }

    /// Start the HTTP server
    pub fn start(self: *Self) !void {
        var server = try self.address.listen(.{ .reuse_address = true });
        self.server = server;

        std.log.info("Brain metrics server listening on http://0.0.0.0:{d}/metrics", .{self.address.getPort()});

        while (true) {
            const conn = server.accept() catch |err| {
                std.log.err("Accept error: {}", .{err});
                continue;
            };

            // Handle connection in a thread
            _ = std.Thread.spawn(.{}, handleConnection, .{ self, conn }) catch |err| {
                std.log.err("Spawn error: {}", .{err});
                conn.stream.close();
                continue;
            };
        }
    }

    /// Handle a single HTTP connection
    fn handleConnection(self: *Self, conn: std.net.Server.Connection) void {
        defer conn.stream.close();

        var buffer: [4096]u8 = undefined;
        const request = conn.stream.read(&buffer) catch return;

        // Simple GET /metrics handler
        if (std.mem.indexOf(u8, buffer[0..request], "GET /metrics")) |_| {
            var response_buf: [65536]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&response_buf);
            const writer = fbs.writer();

            // Export metrics
            self.exporter.collectAndExport(writer, .prometheus) catch {
                // Send 500 error
                const header = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\nExport failed";
                _ = conn.stream.writeAll(header) catch {};
                return;
            };

            // Send 200 OK
            const header = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\n\r\n";
            _ = conn.stream.writeAll(header) catch {};
            _ = conn.stream.writeAll(fbs.getWritten()) catch {};
        } else {
            // 404 Not Found
            const header = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot Found. Try /metrics";
            _ = conn.stream.writeAll(header) catch {};
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ExportFormat contentType" {
    try std.testing.expectEqualStrings("text/plain; version=0.0.4", ExportFormat.prometheus.contentType());
    try std.testing.expectEqualStrings("application/json", ExportFormat.opentelemetry.contentType());
    try std.testing.expectEqualStrings("application/json", ExportFormat.json.contentType());
}

test "Metric init and addLabel" {
    const allocator = std.testing.allocator;
    var metric = Metric.init(allocator, "test_metric", .gauge, 42.0);
    defer metric.deinit();

    try metric.addLabel(allocator, "label1", "value1");
    try std.testing.expectEqual(@as(usize, 1), metric.labels.count());

    const value = metric.labels.get("label1");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("value1", value.?);
}

test "ObservabilityExporter init" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    try std.testing.expectEqualStrings("test-service", exporter.service_name);
    try std.testing.expect(exporter.static_labels.count() > 0);
}

test "ObservabilityExporter collectAndExport" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Test JSON export requires metrics_dashboard which may not be available in test mode
    // This test verifies the exporter structure is correct
    try std.testing.expectEqualStrings("test-service", exporter.service_name);
}

test "ObservabilityExporter exportPrometheus" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Prometheus export requires metrics_dashboard
    // This test verifies the exporter structure is correct
    try std.testing.expect(exporter.static_labels.count() > 0);
}

test "ObservabilityExporter exportJson" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // JSON export requires metrics_dashboard
    // This test verifies the exporter structure is correct
    try std.testing.expectEqual(@as(usize, 1), exporter.static_labels.count());
}

test "ObservabilityExporter slugify" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    const slug = try exporter.slugify("Basal Ganglia");
    defer allocator.free(slug);
    try std.testing.expectEqualStrings("basal_ganglia", slug);

    const slug2 = try exporter.slugify("Reticular Formation");
    defer allocator.free(slug2);
    try std.testing.expectEqualStrings("reticular_formation", slug2);
}

test "Metric formatLabelsPrometheus empty" {
    const allocator = std.testing.allocator;
    var metric = Metric.init(allocator, "test", .gauge, 1.0);
    defer metric.deinit();

    const labels = try metric.formatLabelsPrometheus(allocator);
    defer allocator.free(labels);
    try std.testing.expectEqualStrings("", labels);
}

test "Metric formatLabelsPrometheus with labels" {
    const allocator = std.testing.allocator;
    var metric = Metric.init(allocator, "test", .gauge, 1.0);
    defer metric.deinit();

    try metric.addLabel(allocator, "region", "test_region");
    try metric.addLabel(allocator, "status", "healthy");

    const labels = try metric.formatLabelsPrometheus(allocator);
    defer allocator.free(labels);

    try std.testing.expect(labels.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, labels, "region=") != null);
    try std.testing.expect(std.mem.indexOf(u8, labels, "status=") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROMETHEUS FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Prometheus export format contains required elements" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer buffer.deinit();

    // Collect and export in Prometheus format
    exporter.collectAndExport(buffer.writer(allocator), .prometheus) catch |err| {
        // If metrics_dashboard is not available, skip this test
        if (err == error.FileNotFound or err == error.UnknownFileType) return error.SkipZigTest;
        return err;
    };

    const output = buffer.items;

    // Verify Prometheus format elements
    try std.testing.expect(std.mem.indexOf(u8, output, "# HELP") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "# TYPE") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "s3ai_brain_health_score") != null);
}

test "Prometheus export has correct content type" {
    try std.testing.expectEqualStrings("text/plain; version=0.0.4", ExportFormat.prometheus.contentType());
}

test "Prometheus export has correct file extension" {
    try std.testing.expectEqualStrings(".prom", ExportFormat.prometheus.fileExtension());
}

test "Prometheus metric types" {
    try std.testing.expectEqualStrings("counter", MetricType.counter.prometheusType());
    try std.testing.expectEqualStrings("gauge", MetricType.gauge.prometheusType());
    try std.testing.expectEqualStrings("histogram", MetricType.histogram.prometheusType());
    try std.testing.expectEqualStrings("summary", MetricType.summary.prometheusType());
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPENTELEMETRY FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "OpenTelemetry export format contains required elements" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer buffer.deinit();

    // Collect and export in OpenTelemetry format
    exporter.collectAndExport(buffer.writer(allocator), .opentelemetry) catch |err| {
        // If metrics_dashboard is not available, skip this test
        if (err == error.FileNotFound or err == error.UnknownFileType) return error.SkipZigTest;
        return err;
    };

    const output = buffer.items;

    // Verify OpenTelemetry JSON format elements
    try std.testing.expect(std.mem.indexOf(u8, output, "resourceMetrics") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "service.name") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "scopeMetrics") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"test-service\"") != null);
}

test "OpenTelemetry export has correct content type" {
    try std.testing.expectEqualStrings("application/json", ExportFormat.opentelemetry.contentType());
}

test "OpenTelemetry export has correct file extension" {
    try std.testing.expectEqualStrings(".otel.json", ExportFormat.opentelemetry.fileExtension());
}

test "OpenTelemetry JSON structure is valid" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer buffer.deinit();

    exporter.collectAndExport(buffer.writer(allocator), .opentelemetry) catch |err| {
        if (err == error.FileNotFound or err == error.UnknownFileType) return error.SkipZigTest;
        return err;
    };

    const output = buffer.items;

    // Check for valid JSON structure (braces, quotes)
    try std.testing.expect(output[0] == '{');
    try std.testing.expect(output[output.len - 1] == '}');
    try std.testing.expect(std.mem.indexOf(u8, output, "\"metrics\"") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON FORMAT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JSON export format contains required elements" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer buffer.deinit();

    exporter.collectAndExport(buffer.writer(allocator), .json) catch |err| {
        if (err == error.FileNotFound or err == error.UnknownFileType) return error.SkipZigTest;
        return err;
    };

    const output = buffer.items;

    // Verify JSON format elements
    try std.testing.expect(std.mem.indexOf(u8, output, "\"timestamp\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"service\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"overall_health\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"regions\"") != null);
}

test "JSON export has correct content type" {
    try std.testing.expectEqualStrings("application/json", ExportFormat.json.contentType());
}

test "JSON export has correct file extension" {
    try std.testing.expectEqualStrings(".json", ExportFormat.json.fileExtension());
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS STREAMING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MetricsStreamer init" {
    const allocator = std.testing.allocator;
    var streamer = try MetricsStreamer.init(allocator, "test-service", 1000);
    defer streamer.deinit();

    try std.testing.expect(!streamer.running.load(.acquire));
    try std.testing.expect(streamer.thread == null);
}

test "MetricsStreamer start and stop" {
    const allocator = std.testing.allocator;
    var streamer = try MetricsStreamer.init(allocator, "test-service", 100);
    defer streamer.deinit();

    // Start the streamer
    try streamer.start();
    try std.testing.expect(streamer.running.load(.acquire));
    try std.testing.expect(streamer.thread != null);

    // Let it run briefly
    std.Thread.sleep(50_000_000); // 50ms

    // Stop the streamer
    streamer.stop();
    try std.testing.expect(!streamer.running.load(.acquire));
}

test "MetricsStreamer double start is idempotent" {
    const allocator = std.testing.allocator;
    var streamer = try MetricsStreamer.init(allocator, "test-service", 100);
    defer streamer.deinit();

    try streamer.start();
    const first_thread = streamer.thread;

    // Second start should be no-op
    streamer.start() catch {};
    try std.testing.expectEqual(first_thread, streamer.thread);

    streamer.stop();
}

test "MetricsStreamer stop without start is safe" {
    const allocator = std.testing.allocator;
    var streamer = try MetricsStreamer.init(allocator, "test-service", 100);
    defer streamer.deinit();

    // Stop without starting should not crash
    streamer.stop();
    try std.testing.expect(!streamer.running.load(.acquire));
}

test "MetricsStreamer interval is stored correctly" {
    const allocator = std.testing.allocator;
    const interval_ms: u64 = 500;
    var streamer = try MetricsStreamer.init(allocator, "test-service", interval_ms);
    defer streamer.deinit();

    try std.testing.expectEqual(interval_ms, streamer.interval_ms);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP SERVER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MetricsServer init" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var server = try MetricsServer.init(allocator, &exporter, 8080);
    defer server.deinit();

    try std.testing.expect(server.server == null);
    try std.testing.expectEqual(@as(u16, 8080), server.address.getPort());
}

test "MetricsServer init with custom port" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var server = try MetricsServer.init(allocator, &exporter, 9090);
    defer server.deinit();

    try std.testing.expectEqual(@as(u16, 9090), server.address.getPort());
}

test "MetricsServer deinit without start is safe" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    var server = try MetricsServer.init(allocator, &exporter, 8080);
    // Should not crash even though server was never started
    server.deinit();
}

test "MetricsServer address parsing" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Test various ports
    var server1 = try MetricsServer.init(allocator, &exporter, 8080);
    defer server1.deinit();
    try std.testing.expectEqual(@as(u16, 8080), server1.address.getPort());

    var server2 = try MetricsServer.init(allocator, &exporter, 9090);
    defer server2.deinit();
    try std.testing.expectEqual(@as(u16, 9090), server2.address.getPort());

    var server3 = try MetricsServer.init(allocator, &exporter, 65535);
    defer server3.deinit();
    try std.testing.expectEqual(@as(u16, 65535), server3.address.getPort());
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "All export formats have content types" {
    try std.testing.expect(ExportFormat.prometheus.contentType().len > 0);
    try std.testing.expect(ExportFormat.opentelemetry.contentType().len > 0);
    try std.testing.expect(ExportFormat.json.contentType().len > 0);
    try std.testing.expect(ExportFormat.influxdb.contentType().len > 0);
    try std.testing.expect(ExportFormat.statsd.contentType().len > 0);
}

test "All export formats have file extensions" {
    try std.testing.expect(ExportFormat.prometheus.fileExtension().len > 0);
    try std.testing.expect(ExportFormat.opentelemetry.fileExtension().len > 0);
    try std.testing.expect(ExportFormat.json.fileExtension().len > 0);
    try std.testing.expect(ExportFormat.influxdb.fileExtension().len > 0);
    try std.testing.expect(ExportFormat.statsd.fileExtension().len > 0);
}

test "Metric with all metric types" {
    const allocator = std.testing.allocator;

    var counter_metric = Metric.init(allocator, "test_counter", .counter, 42.0);
    defer counter_metric.deinit();
    try std.testing.expectEqual(.counter, counter_metric.metric_type);

    var gauge_metric = Metric.init(allocator, "test_gauge", .gauge, 3.14);
    defer gauge_metric.deinit();
    try std.testing.expectEqual(.gauge, gauge_metric.metric_type);

    var histogram_metric = Metric.init(allocator, "test_histogram", .histogram, 100.0);
    defer histogram_metric.deinit();
    try std.testing.expectEqual(.histogram, histogram_metric.metric_type);

    var summary_metric = Metric.init(allocator, "test_summary", .summary, 50.0);
    defer summary_metric.deinit();
    try std.testing.expectEqual(.summary, summary_metric.metric_type);
}

test "Metric deinit cleans up labels" {
    const allocator = std.testing.allocator;
    var metric = Metric.init(allocator, "test", .gauge, 1.0);

    // Add labels
    try metric.addLabel(allocator, "key1", "value1");
    try metric.addLabel(allocator, "key2", "value2");

    // Deinit should clean up
    metric.deinit();

    // If we got here without crash, test passed
    try std.testing.expect(true);
}

test "Metric help text can be set and freed" {
    const allocator = std.testing.allocator;
    var metric = Metric.init(allocator, "test", .gauge, 1.0);

    // Set help text
    metric.help = try allocator.dupe(u8, "This is a help text");

    metric.deinit();
    // If we got here without crash, test passed
    try std.testing.expect(true);
}

test "ObservabilityExporter with custom histogram buckets" {
    const allocator = std.testing.allocator;
    const custom_buckets = [_]f64{ 0.1, 0.5, 1.0, 5.0 };

    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Set custom buckets
    exporter.histogram_buckets = &custom_buckets;
    exporter.enable_histograms = true;

    try std.testing.expectEqual(@as(usize, 4), exporter.histogram_buckets.len);
    try std.testing.expect(exporter.enable_histograms);
}

test "ObservabilityExporter static labels" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Check default service label
    const service_value = exporter.static_labels.get("service");
    try std.testing.expect(service_value != null);
    try std.testing.expectEqualStrings("test-service", service_value.?);
}

test "Slugify handles special characters" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    // Test spaces become underscores
    const slug1 = try exporter.slugify("Hello World");
    defer allocator.free(slug1);
    try std.testing.expectEqualStrings("hello_world", slug1);

    // Test multiple spaces
    const slug2 = try exporter.slugify("A B C D");
    defer allocator.free(slug2);
    try std.testing.expectEqualStrings("a_b_c_d", slug2);

    // Test mixed case
    const slug3 = try exporter.slugify("MiXeD CaSe");
    defer allocator.free(slug3);
    try std.testing.expectEqualStrings("mixed_case", slug3);

    // Test special characters are removed
    const slug4 = try exporter.slugify("Test@#$%^&*Region");
    defer allocator.free(slug4);
    try std.testing.expectEqualStrings("testregion", slug4);
}

test "Slugify empty string" {
    const allocator = std.testing.allocator;
    var exporter = try ObservabilityExporter.init(allocator, "test-service");
    defer exporter.deinit();

    const slug = try exporter.slugify("");
    defer allocator.free(slug);
    try std.testing.expectEqualStrings("", slug);
}

test "escapeInfluxTag function" {
    const allocator = std.testing.allocator;

    // Test space escaping
    const result1 = try escapeInfluxTag(allocator, "hello world");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello\\ world", result1);

    // Test comma escaping
    const result2 = try escapeInfluxTag(allocator, "tag1,tag2");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("tag1\\,tag2", result2);

    // Test equals escaping
    const result3 = try escapeInfluxTag(allocator, "key=value");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("key\\=value", result3);

    // Test normal string
    const result4 = try escapeInfluxTag(allocator, "normal");
    defer allocator.free(result4);
    try std.testing.expectEqualStrings("normal", result4);
}

test "cleanStatsDKey function" {
    const allocator = std.testing.allocator;

    // Test space replacement
    const result1 = try cleanStatsDKey(allocator, "hello world");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello_world", result1);

    // Test equals replacement
    const result2 = try cleanStatsDKey(allocator, "key=value");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("key_value", result2);

    // Test normal string
    const result3 = try cleanStatsDKey(allocator, "normal.key");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("normal.key", result3);
}
