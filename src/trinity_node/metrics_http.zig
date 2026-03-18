// =============================================================================
// TRINITY METRICS HTTP v1.8 - HTTP Endpoint for Prometheus Scraping
// Serves /metrics in Prometheus exposition format on configurable port
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const prometheus_metrics_mod = @import("prometheus_metrics.zig");
const network_stats_mod = @import("network_stats.zig");

// =============================================================================
// HTTP STATS
// =============================================================================

pub const HttpStats = struct {
    requests_served: u64,
    metrics_requests: u64,
    health_requests: u64,
    not_found_requests: u64,
    errors: u64,
};

// =============================================================================
// METRICS HTTP SERVER
// =============================================================================

pub const MetricsHttpServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    requests_served: u64,
    metrics_requests: u64,
    health_requests: u64,
    not_found_requests: u64,
    errors: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, port: u16) MetricsHttpServer {
        return .{
            .allocator = allocator,
            .port = port,
            .requests_served = 0,
            .metrics_requests = 0,
            .health_requests = 0,
            .not_found_requests = 0,
            .errors = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *MetricsHttpServer) void {
        _ = self;
    }

    /// Format an HTTP 200 response with the given content type and body.
    pub fn formatHttpResponse(self: *MetricsHttpServer, content_type: []const u8, body: []const u8) ![]u8 {
        const response = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}",
            .{ content_type, body.len, body },
        );
        return response;
    }

    /// Format an HTTP 404 response.
    pub fn formatHttp404(self: *MetricsHttpServer) ![]u8 {
        const body = "404 Not Found\n";
        const response = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}",
            .{ body.len, body },
        );
        return response;
    }

    /// Handle a metrics request: generate Prometheus exposition format.
    pub fn handleMetricsRequest(
        self: *MetricsHttpServer,
        report: network_stats_mod.NetworkHealthReport,
    ) ![]u8 {
        var exporter = prometheus_metrics_mod.PrometheusExporter.init(self.allocator);
        const metrics_body = try exporter.exportMetrics(report);
        defer self.allocator.free(metrics_body);

        self.mutex.lock();
        self.metrics_requests += 1;
        self.requests_served += 1;
        self.mutex.unlock();

        return self.formatHttpResponse("text/plain; version=0.0.4; charset=utf-8", metrics_body);
    }

    /// Handle a health request: return JSON health summary.
    pub fn handleHealthRequest(
        self: *MetricsHttpServer,
        report: network_stats_mod.NetworkHealthReport,
    ) ![]u8 {
        const body = try std.fmt.allocPrint(
            self.allocator,
            "{{\"status\":\"ok\",\"nodes\":{d},\"shards\":{d},\"storage_bytes\":{d}}}",
            .{ report.node_count, report.total_shards, report.total_bytes_used },
        );
        defer self.allocator.free(body);

        self.mutex.lock();
        self.health_requests += 1;
        self.requests_served += 1;
        self.mutex.unlock();

        return self.formatHttpResponse("application/json", body);
    }

    /// Route an HTTP request based on path.
    /// Returns the HTTP response as a byte slice.
    pub fn routeRequest(
        self: *MetricsHttpServer,
        path: []const u8,
        report: network_stats_mod.NetworkHealthReport,
    ) ![]u8 {
        if (std.mem.eql(u8, path, "/metrics")) {
            return self.handleMetricsRequest(report);
        } else if (std.mem.eql(u8, path, "/health")) {
            return self.handleHealthRequest(report);
        } else {
            self.mutex.lock();
            self.not_found_requests += 1;
            self.requests_served += 1;
            self.mutex.unlock();
            return self.formatHttp404();
        }
    }

    /// Parse HTTP request line to extract the path.
    /// Input: "GET /metrics HTTP/1.1\r\n..."
    /// Returns: "/metrics"
    pub fn parseRequestPath(request: []const u8) ?[]const u8 {
        // Find first space after method
        var start: usize = 0;
        while (start < request.len and request[start] != ' ') : (start += 1) {}
        if (start >= request.len) return null;
        start += 1; // skip space

        // Find end of path (next space)
        var end = start;
        while (end < request.len and request[end] != ' ' and request[end] != '?') : (end += 1) {}
        if (end <= start) return null;

        return request[start..end];
    }

    /// Get stats
    pub fn getStats(self: *MetricsHttpServer) HttpStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .requests_served = self.requests_served,
            .metrics_requests = self.metrics_requests,
            .health_requests = self.health_requests,
            .not_found_requests = self.not_found_requests,
            .errors = self.errors,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "metrics HTTP: response format is valid" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const response = try server.formatHttpResponse("text/plain", "hello");
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "Content-Type: text/plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Content-Length: 5") != null);
    try std.testing.expect(std.mem.endsWith(u8, response, "hello"));
}

test "metrics HTTP: 404 response" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const response = try server.formatHttp404();
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 404 Not Found\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "404 Not Found") != null);
}

test "metrics HTTP: route /metrics returns prometheus format" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 5,
        .total_shards = 100,
        .total_bytes_used = 1024 * 1024,
        .total_bytes_available = 10 * 1024 * 1024,
        .shards_tracked = 80,
        .shards_rebalanced = 10,
        .target_replication = 3,
        .pos_challenges_issued = 20,
        .pos_challenges_passed = 18,
        .pos_challenges_failed = 2,
        .total_upload = 5000,
        .total_download = 8000,
        .scrub_total = 3,
        .scrub_corruptions = 1,
        .reputation_avg = 0.85,
        .reputation_min = 0.3,
        .reputation_max = 1.0,
        .generated_at = 1700000000,
    };

    const response = try server.routeRequest("/metrics", report);
    defer allocator.free(response);

    // Should be HTTP 200 with Prometheus content
    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, response, "text/plain; version=0.0.4") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "trinity_node_count") != null);

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.metrics_requests);
}

test "metrics HTTP: route /health returns JSON" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 10,
        .total_shards = 200,
        .total_bytes_used = 2048,
        .total_bytes_available = 0,
        .shards_tracked = 0,
        .shards_rebalanced = 0,
        .target_replication = 0,
        .pos_challenges_issued = 0,
        .pos_challenges_passed = 0,
        .pos_challenges_failed = 0,
        .total_upload = 0,
        .total_download = 0,
        .scrub_total = 0,
        .scrub_corruptions = 0,
        .reputation_avg = 0,
        .reputation_min = 0,
        .reputation_max = 0,
        .generated_at = 0,
    };

    const response = try server.routeRequest("/health", report);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "application/json") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"status\":\"ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"nodes\":10") != null);

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.health_requests);
}

test "metrics HTTP: route unknown returns 404" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const report = std.mem.zeroes(network_stats_mod.NetworkHealthReport);

    const response = try server.routeRequest("/unknown", report);
    defer allocator.free(response);

    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 404 Not Found\r\n"));

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.not_found_requests);
}

test "metrics HTTP: parse request path" {
    const path1 = MetricsHttpServer.parseRequestPath("GET /metrics HTTP/1.1\r\n");
    try std.testing.expect(path1 != null);
    try std.testing.expectEqualStrings("/metrics", path1.?);

    const path2 = MetricsHttpServer.parseRequestPath("GET /health?foo=bar HTTP/1.1\r\n");
    try std.testing.expect(path2 != null);
    try std.testing.expectEqualStrings("/health", path2.?);

    const path3 = MetricsHttpServer.parseRequestPath("INVALID");
    try std.testing.expect(path3 == null);
}

test "metrics HTTP: stats accumulate" {
    const allocator = std.testing.allocator;

    var server = MetricsHttpServer.init(allocator, 9100);
    defer server.deinit();

    const report = std.mem.zeroes(network_stats_mod.NetworkHealthReport);

    // Make 3 requests of different types
    const r1 = try server.routeRequest("/metrics", report);
    defer allocator.free(r1);
    const r2 = try server.routeRequest("/health", report);
    defer allocator.free(r2);
    const r3 = try server.routeRequest("/unknown", report);
    defer allocator.free(r3);

    const stats = server.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.requests_served);
    try std.testing.expectEqual(@as(u64, 1), stats.metrics_requests);
    try std.testing.expectEqual(@as(u64, 1), stats.health_requests);
    try std.testing.expectEqual(@as(u64, 1), stats.not_found_requests);
}
