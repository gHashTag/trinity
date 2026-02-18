// ═══════════════════════════════════════════════════════════════════════════════
// PROMETHEUS HTTP ENDPOINT — Live /metrics Scraping for Grafana Dashboards
// Trinity Storage Network v2.0
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const prometheus_metrics_mod = @import("prometheus_metrics.zig");
const network_stats_mod = @import("network_stats.zig");

pub const HttpConfig = struct {
    /// Port for the /metrics endpoint
    port: u16 = 9090,
    /// Bind address
    bind_address: []const u8 = "0.0.0.0",
    /// Maximum request size (bytes)
    max_request_size: usize = 4096,
    /// Response content type
    content_type: []const u8 = "text/plain; version=0.0.4; charset=utf-8",
    /// Cache duration for metrics (milliseconds)
    cache_ttl_ms: i64 = 5000,
};

pub const EndpointStats = struct {
    total_requests: u64,
    successful_responses: u64,
    error_responses: u64,
    cache_hits: u64,
    cache_misses: u64,
    total_bytes_served: u64,
    last_scrape_timestamp: i64,
};

pub const HttpResponse = struct {
    status_code: u16,
    content_type: []const u8,
    body: []const u8,
    body_len: usize,
};

pub const MetricsCache = struct {
    cached_metrics: ?[]u8,
    cached_at: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MetricsCache {
        return .{
            .cached_metrics = null,
            .cached_at = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MetricsCache) void {
        if (self.cached_metrics) |m| {
            self.allocator.free(m);
            self.cached_metrics = null;
        }
    }

    pub fn isValid(self: *MetricsCache, current_time: i64, ttl_ms: i64) bool {
        if (self.cached_metrics == null) return false;
        return (current_time - self.cached_at) < ttl_ms;
    }

    pub fn update(self: *MetricsCache, metrics: []const u8, current_time: i64) !void {
        if (self.cached_metrics) |old| {
            self.allocator.free(old);
        }
        self.cached_metrics = try self.allocator.dupe(u8, metrics);
        self.cached_at = current_time;
    }

    pub fn get(self: *MetricsCache) ?[]const u8 {
        return self.cached_metrics;
    }
};

pub const PrometheusHttpEndpoint = struct {
    allocator: std.mem.Allocator,
    config: HttpConfig,
    exporter: prometheus_metrics_mod.PrometheusExporter,
    cache: MetricsCache,
    stats: EndpointStats,

    pub fn init(allocator: std.mem.Allocator) PrometheusHttpEndpoint {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: HttpConfig) PrometheusHttpEndpoint {
        return .{
            .allocator = allocator,
            .config = config,
            .exporter = prometheus_metrics_mod.PrometheusExporter.init(allocator),
            .cache = MetricsCache.init(allocator),
            .stats = std.mem.zeroes(EndpointStats),
        };
    }

    pub fn deinit(self: *PrometheusHttpEndpoint) void {
        self.cache.deinit();
        self.exporter.deinit();
    }

    /// Handle an HTTP request and return metrics response
    pub fn handleRequest(self: *PrometheusHttpEndpoint, request_path: []const u8, report: network_stats_mod.NetworkHealthReport, current_time: i64) !HttpResponse {
        self.stats.total_requests += 1;
        self.stats.last_scrape_timestamp = current_time;

        // Only respond to /metrics
        if (!std.mem.eql(u8, request_path, "/metrics") and
            !std.mem.eql(u8, request_path, "/metrics/"))
        {
            self.stats.error_responses += 1;
            return .{
                .status_code = 404,
                .content_type = "text/plain",
                .body = "Not Found. Use /metrics for Prometheus metrics.",
                .body_len = 47,
            };
        }

        // Check cache
        if (self.cache.isValid(current_time, self.config.cache_ttl_ms)) {
            self.stats.cache_hits += 1;
            self.stats.successful_responses += 1;
            const cached = self.cache.get().?;
            self.stats.total_bytes_served += cached.len;
            return .{
                .status_code = 200,
                .content_type = self.config.content_type,
                .body = cached,
                .body_len = cached.len,
            };
        }

        // Generate fresh metrics
        self.stats.cache_misses += 1;
        const metrics = try self.exporter.exportMetrics(report);
        defer self.allocator.free(metrics);

        try self.cache.update(metrics, current_time);
        self.stats.successful_responses += 1;
        self.stats.total_bytes_served += metrics.len;

        return .{
            .status_code = 200,
            .content_type = self.config.content_type,
            .body = self.cache.get().?,
            .body_len = metrics.len,
        };
    }

    /// Format an HTTP response as a raw HTTP response string
    pub fn formatHttpResponse(self: *PrometheusHttpEndpoint, response: HttpResponse) ![]u8 {
        const status_text: []const u8 = switch (response.status_code) {
            200 => "OK",
            404 => "Not Found",
            500 => "Internal Server Error",
            else => "Unknown",
        };

        return try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}",
            .{ response.status_code, status_text, response.content_type, response.body_len, response.body },
        );
    }

    /// Get endpoint stats (for self-monitoring)
    pub fn getEndpointMetrics(self: *PrometheusHttpEndpoint) ![]u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            \\# HELP trinity_metrics_requests_total Total /metrics HTTP requests
            \\# TYPE trinity_metrics_requests_total counter
            \\trinity_metrics_requests_total {d}
            \\# HELP trinity_metrics_cache_hits_total Cache hits for /metrics
            \\# TYPE trinity_metrics_cache_hits_total counter
            \\trinity_metrics_cache_hits_total {d}
            \\# HELP trinity_metrics_cache_misses_total Cache misses for /metrics
            \\# TYPE trinity_metrics_cache_misses_total counter
            \\trinity_metrics_cache_misses_total {d}
            \\# HELP trinity_metrics_bytes_served_total Total bytes served via /metrics
            \\# TYPE trinity_metrics_bytes_served_total counter
            \\trinity_metrics_bytes_served_total {d}
            \\
        , .{
            self.stats.total_requests,
            self.stats.cache_hits,
            self.stats.cache_misses,
            self.stats.total_bytes_served,
        });
    }

    pub fn getStats(self: *PrometheusHttpEndpoint) EndpointStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn makeTestReport() network_stats_mod.NetworkHealthReport {
    return .{
        .node_count = 100,
        .total_shards = 500,
        .total_bytes_used = 1024 * 1024 * 100,
        .total_bytes_available = 1024 * 1024 * 1024,
        .shards_tracked = 500,
        .shards_rebalanced = 50,
        .target_replication = 3,
        .pos_challenges_issued = 1000,
        .pos_challenges_passed = 980,
        .pos_challenges_failed = 20,
        .total_upload = 1024 * 1024 * 500,
        .total_download = 1024 * 1024 * 300,
        .scrub_total = 200,
        .scrub_corruptions = 5,
        .reputation_avg = 0.85,
        .reputation_min = 0.3,
        .reputation_max = 1.0,
        .generated_at = 1700000000,
    };
}

test "metrics endpoint returns 200 for /metrics" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.init(allocator);
    defer endpoint.deinit();

    const report = makeTestReport();
    const response = try endpoint.handleRequest("/metrics", report, 1000);

    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(response.body_len > 0);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "trinity_node_count") != null);
}

test "metrics endpoint returns 404 for unknown path" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.init(allocator);
    defer endpoint.deinit();

    const report = makeTestReport();
    const response = try endpoint.handleRequest("/unknown", report, 1000);

    try std.testing.expectEqual(@as(u16, 404), response.status_code);
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().error_responses);
}

test "metrics cache avoids regeneration" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.initWithConfig(allocator, .{
        .cache_ttl_ms = 5000,
    });
    defer endpoint.deinit();

    const report = makeTestReport();

    // First request: cache miss
    _ = try endpoint.handleRequest("/metrics", report, 1000);
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().cache_misses);
    try std.testing.expectEqual(@as(u64, 0), endpoint.getStats().cache_hits);

    // Second request within TTL: cache hit
    _ = try endpoint.handleRequest("/metrics", report, 2000);
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().cache_misses);
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().cache_hits);

    // Third request after TTL: cache miss again
    _ = try endpoint.handleRequest("/metrics", report, 7000);
    try std.testing.expectEqual(@as(u64, 2), endpoint.getStats().cache_misses);
    try std.testing.expectEqual(@as(u64, 1), endpoint.getStats().cache_hits);
}

test "format HTTP response" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.init(allocator);
    defer endpoint.deinit();

    const report = makeTestReport();
    const response = try endpoint.handleRequest("/metrics", report, 1000);
    const http_bytes = try endpoint.formatHttpResponse(response);
    defer allocator.free(http_bytes);

    try std.testing.expect(std.mem.startsWith(u8, http_bytes, "HTTP/1.1 200 OK"));
    try std.testing.expect(std.mem.indexOf(u8, http_bytes, "Content-Type: text/plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, http_bytes, "trinity_node_count") != null);
}

test "endpoint self-monitoring metrics" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.init(allocator);
    defer endpoint.deinit();

    const report = makeTestReport();
    _ = try endpoint.handleRequest("/metrics", report, 1000);
    _ = try endpoint.handleRequest("/metrics", report, 2000);
    _ = try endpoint.handleRequest("/bad", report, 3000);

    const self_metrics = try endpoint.getEndpointMetrics();
    defer allocator.free(self_metrics);

    try std.testing.expect(std.mem.indexOf(u8, self_metrics, "trinity_metrics_requests_total 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, self_metrics, "trinity_metrics_cache_hits_total 1") != null);
}

test "metrics cache lifecycle" {
    const allocator = std.testing.allocator;
    var cache = MetricsCache.init(allocator);
    defer cache.deinit();

    // Initially empty
    try std.testing.expect(!cache.isValid(1000, 5000));
    try std.testing.expect(cache.get() == null);

    // Update
    try cache.update("test_metrics", 1000);
    try std.testing.expect(cache.isValid(2000, 5000));
    try std.testing.expect(cache.get() != null);
    try std.testing.expect(std.mem.eql(u8, cache.get().?, "test_metrics"));

    // Expired
    try std.testing.expect(!cache.isValid(7000, 5000));

    // Update with new data
    try cache.update("new_metrics", 7000);
    try std.testing.expect(cache.isValid(8000, 5000));
    try std.testing.expect(std.mem.eql(u8, cache.get().?, "new_metrics"));
}

test "endpoint stats accumulate" {
    const allocator = std.testing.allocator;
    var endpoint = PrometheusHttpEndpoint.init(allocator);
    defer endpoint.deinit();

    const report = makeTestReport();

    for (0..5) |i| {
        _ = try endpoint.handleRequest("/metrics", report, @intCast(i * 10_000));
    }

    const stats = endpoint.getStats();
    try std.testing.expectEqual(@as(u64, 5), stats.total_requests);
    try std.testing.expectEqual(@as(u64, 5), stats.successful_responses);
    try std.testing.expect(stats.total_bytes_served > 0);
}
