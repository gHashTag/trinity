// ═══════════════════════════════════════════════════════════════════════════════
// AUTOSCALING & MONITORING - DEP-003
// ═══════════════════════════════════════════════════════════════════════════════
// Trinity Production Deployment Infrastructure
// Fly.io integration + Prometheus metrics + Health checks
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const time = std.time;
const http = std.http;
const net = std.net;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScalingConfig = struct {
    min_instances: u32 = 1,
    max_instances: u32 = 10,
    target_cpu_percent: f64 = 70.0,
    target_queue_depth: u32 = 50,
    target_ttft_ms: f64 = 100.0,
    scale_up_threshold: f64 = 0.8,
    scale_down_threshold: f64 = 0.3,
    cooldown_seconds: u32 = 60,
};

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const InstanceMetrics = struct {
    instance_id: []const u8 = "",
    cpu_percent: f64 = 0,
    memory_percent: f64 = 0,
    queue_depth: u32 = 0,
    active_requests: u32 = 0,
    ttft_p50_ms: f64 = 0,
    ttft_p99_ms: f64 = 0,
    throughput_tps: f64 = 0,
    uptime_seconds: u64 = 0,
};

pub const ClusterMetrics = struct {
    total_instances: u32 = 0,
    healthy_instances: u32 = 0,
    total_requests: u64 = 0,
    total_tokens: u64 = 0,
    avg_cpu_percent: f64 = 0,
    avg_memory_percent: f64 = 0,
    avg_queue_depth: f64 = 0,
    avg_ttft_ms: f64 = 0,
    total_throughput_tps: f64 = 0,
};

pub const HealthStatus = struct {
    healthy: bool = false,
    ready: bool = false,
    live: bool = true,
    last_check: i64 = 0,
    error_message: ?[]const u8 = null,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROMETHEUS METRICS REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetricsRegistry = struct {
    allocator: Allocator,
    
    // Counters
    total_requests: u64 = 0,
    total_tokens: u64 = 0,
    total_errors: u64 = 0,
    
    // Gauges
    cpu_percent: f64 = 0,
    memory_percent: f64 = 0,
    queue_depth: u32 = 0,
    active_requests: u32 = 0,
    instance_count: u32 = 1,
    healthy_instances: u32 = 1,
    
    // Histograms (simplified - just track p50/p99)
    ttft_p50_ms: f64 = 0,
    ttft_p99_ms: f64 = 0,
    throughput_tps: f64 = 0,
    
    pub fn init(allocator: Allocator) MetricsRegistry {
        return .{ .allocator = allocator };
    }
    
    pub fn incRequests(self: *MetricsRegistry) void {
        self.total_requests += 1;
    }
    
    pub fn addTokens(self: *MetricsRegistry, count: u64) void {
        self.total_tokens += count;
    }
    
    pub fn incErrors(self: *MetricsRegistry) void {
        self.total_errors += 1;
    }
    
    pub fn setGauges(self: *MetricsRegistry, cpu: f64, mem: f64, queue: u32, active: u32) void {
        self.cpu_percent = cpu;
        self.memory_percent = mem;
        self.queue_depth = queue;
        self.active_requests = active;
    }
    
    pub fn setLatency(self: *MetricsRegistry, p50: f64, p99: f64) void {
        self.ttft_p50_ms = p50;
        self.ttft_p99_ms = p99;
    }
    
    pub fn setThroughput(self: *MetricsRegistry, tps: f64) void {
        self.throughput_tps = tps;
    }
    
    /// Export metrics in Prometheus format
    pub fn exportPrometheus(self: *const MetricsRegistry, writer: anytype) !void {
        // Counters
        try writer.writeAll("# HELP trinity_total_requests Total inference requests\n");
        try writer.writeAll("# TYPE trinity_total_requests counter\n");
        try writer.print("trinity_total_requests {d}\n\n", .{self.total_requests});
        
        try writer.writeAll("# HELP trinity_total_tokens Total tokens generated\n");
        try writer.writeAll("# TYPE trinity_total_tokens counter\n");
        try writer.print("trinity_total_tokens {d}\n\n", .{self.total_tokens});
        
        try writer.writeAll("# HELP trinity_total_errors Total errors\n");
        try writer.writeAll("# TYPE trinity_total_errors counter\n");
        try writer.print("trinity_total_errors {d}\n\n", .{self.total_errors});
        
        // Gauges
        try writer.writeAll("# HELP trinity_cpu_usage_percent CPU usage percentage\n");
        try writer.writeAll("# TYPE trinity_cpu_usage_percent gauge\n");
        try writer.print("trinity_cpu_usage_percent {d:.2}\n\n", .{self.cpu_percent});
        
        try writer.writeAll("# HELP trinity_memory_usage_percent Memory usage percentage\n");
        try writer.writeAll("# TYPE trinity_memory_usage_percent gauge\n");
        try writer.print("trinity_memory_usage_percent {d:.2}\n\n", .{self.memory_percent});
        
        try writer.writeAll("# HELP trinity_queue_depth Current queue depth\n");
        try writer.writeAll("# TYPE trinity_queue_depth gauge\n");
        try writer.print("trinity_queue_depth {d}\n\n", .{self.queue_depth});
        
        try writer.writeAll("# HELP trinity_active_requests Active requests\n");
        try writer.writeAll("# TYPE trinity_active_requests gauge\n");
        try writer.print("trinity_active_requests {d}\n\n", .{self.active_requests});
        
        try writer.writeAll("# HELP trinity_instance_count Total instances\n");
        try writer.writeAll("# TYPE trinity_instance_count gauge\n");
        try writer.print("trinity_instance_count {d}\n\n", .{self.instance_count});
        
        try writer.writeAll("# HELP trinity_healthy_instances Healthy instances\n");
        try writer.writeAll("# TYPE trinity_healthy_instances gauge\n");
        try writer.print("trinity_healthy_instances {d}\n\n", .{self.healthy_instances});
        
        // Latency
        try writer.writeAll("# HELP trinity_ttft_seconds Time to first token\n");
        try writer.writeAll("# TYPE trinity_ttft_seconds gauge\n");
        try writer.print("trinity_ttft_seconds{{quantile=\"0.5\"}} {d:.6}\n", .{self.ttft_p50_ms / 1000.0});
        try writer.print("trinity_ttft_seconds{{quantile=\"0.99\"}} {d:.6}\n\n", .{self.ttft_p99_ms / 1000.0});
        
        // Throughput
        try writer.writeAll("# HELP trinity_throughput_tokens_per_second Tokens per second\n");
        try writer.writeAll("# TYPE trinity_throughput_tokens_per_second gauge\n");
        try writer.print("trinity_throughput_tokens_per_second {d:.2}\n", .{self.throughput_tps});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HEALTH CHECK SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const HealthServer = struct {
    allocator: Allocator,
    metrics: *MetricsRegistry,
    health: HealthStatus,
    config: ScalingConfig,
    
    pub fn init(allocator: Allocator, metrics: *MetricsRegistry, config: ScalingConfig) HealthServer {
        return .{
            .allocator = allocator,
            .metrics = metrics,
            .health = HealthStatus{ .live = true },
            .config = config,
        };
    }
    
    pub fn setReady(self: *HealthServer, ready: bool) void {
        self.health.ready = ready;
        self.health.healthy = ready;
        self.health.last_check = time.timestamp();
    }
    
    pub fn handleRequest(self: *HealthServer, path: []const u8, writer: anytype) !void {
        if (std.mem.eql(u8, path, "/health/live")) {
            try self.handleLiveness(writer);
        } else if (std.mem.eql(u8, path, "/health/ready")) {
            try self.handleReadiness(writer);
        } else if (std.mem.eql(u8, path, "/health/startup")) {
            try self.handleStartup(writer);
        } else if (std.mem.eql(u8, path, "/metrics")) {
            try self.handleMetrics(writer);
        } else if (std.mem.eql(u8, path, "/status")) {
            try self.handleStatus(writer);
        } else {
            try writer.writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
        }
    }
    
    fn handleLiveness(self: *HealthServer, writer: anytype) !void {
        if (self.health.live) {
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK");
        } else {
            try writer.writeAll("HTTP/1.1 503 Service Unavailable\r\n\r\nNot Live");
        }
    }
    
    fn handleReadiness(self: *HealthServer, writer: anytype) !void {
        if (self.health.ready) {
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nReady");
        } else {
            try writer.writeAll("HTTP/1.1 503 Service Unavailable\r\n\r\nNot Ready");
        }
    }
    
    fn handleStartup(self: *HealthServer, writer: anytype) !void {
        if (self.health.healthy) {
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nStarted");
        } else {
            try writer.writeAll("HTTP/1.1 503 Service Unavailable\r\n\r\nStarting");
        }
    }
    
    fn handleMetrics(self: *HealthServer, writer: anytype) !void {
        try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n");
        try self.metrics.exportPrometheus(writer);
    }
    
    fn handleStatus(self: *HealthServer, writer: anytype) !void {
        try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n");
        try writer.print(
            \\{{"healthy":{s},"ready":{s},"live":{s},"requests":{d},"tokens":{d},"cpu":{d:.1},"memory":{d:.1},"ttft_p50_ms":{d:.2},"throughput_tps":{d:.1},"queue_depth":{d},"active_requests":{d},"instances":{d},"healthy_instances":{d}}}
        , .{
            if (self.health.healthy) "true" else "false",
            if (self.health.ready) "true" else "false",
            if (self.health.live) "true" else "false",
            self.metrics.total_requests,
            self.metrics.total_tokens,
            self.metrics.cpu_percent,
            self.metrics.memory_percent,
            self.metrics.ttft_p50_ms,
            self.metrics.throughput_tps,
            self.metrics.queue_depth,
            self.metrics.active_requests,
            self.metrics.instance_count,
            self.metrics.healthy_instances,
        });
    }
    
    /// Dashboard endpoint - returns JSON for frontend consumption
    pub fn handleDashboard(self: *HealthServer, writer: anytype) !void {
        try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n");
        try writer.writeAll("{\n");
        try writer.writeAll("  \"service\": \"Trinity Inference\",\n");
        try writer.writeAll("  \"version\": \"1.0.0\",\n");
        try writer.print("  \"uptime_seconds\": {d},\n", .{time.timestamp() - self.health.last_check});
        try writer.writeAll("  \"health\": {\n");
        try writer.print("    \"healthy\": {s},\n", .{if (self.health.healthy) "true" else "false"});
        try writer.print("    \"ready\": {s},\n", .{if (self.health.ready) "true" else "false"});
        try writer.print("    \"live\": {s}\n", .{if (self.health.live) "true" else "false"});
        try writer.writeAll("  },\n");
        try writer.writeAll("  \"metrics\": {\n");
        try writer.print("    \"total_requests\": {d},\n", .{self.metrics.total_requests});
        try writer.print("    \"total_tokens\": {d},\n", .{self.metrics.total_tokens});
        try writer.print("    \"total_errors\": {d},\n", .{self.metrics.total_errors});
        try writer.print("    \"cpu_percent\": {d:.2},\n", .{self.metrics.cpu_percent});
        try writer.print("    \"memory_percent\": {d:.2},\n", .{self.metrics.memory_percent});
        try writer.print("    \"queue_depth\": {d},\n", .{self.metrics.queue_depth});
        try writer.print("    \"active_requests\": {d},\n", .{self.metrics.active_requests});
        try writer.print("    \"ttft_p50_ms\": {d:.2},\n", .{self.metrics.ttft_p50_ms});
        try writer.print("    \"ttft_p99_ms\": {d:.2},\n", .{self.metrics.ttft_p99_ms});
        try writer.print("    \"throughput_tps\": {d:.2}\n", .{self.metrics.throughput_tps});
        try writer.writeAll("  },\n");
        try writer.writeAll("  \"scaling\": {\n");
        try writer.print("    \"current_instances\": {d},\n", .{self.metrics.instance_count});
        try writer.print("    \"healthy_instances\": {d},\n", .{self.metrics.healthy_instances});
        try writer.print("    \"min_instances\": {d},\n", .{self.config.min_instances});
        try writer.print("    \"max_instances\": {d}\n", .{self.config.max_instances});
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCALING DECISION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScalingDecision = struct {
    action: Action,
    current_instances: u32,
    target_instances: u32,
    reason: []const u8,
    timestamp: i64,
    
    pub const Action = enum { none, scale_up, scale_down };
};

pub fn evaluateScaling(metrics: *const MetricsRegistry, config: ScalingConfig) ScalingDecision {
    const current = metrics.instance_count;
    var decision = ScalingDecision{
        .action = .none,
        .current_instances = current,
        .target_instances = current,
        .reason = "No scaling needed",
        .timestamp = time.timestamp(),
    };
    
    // Scale up conditions
    if (metrics.cpu_percent > config.target_cpu_percent * config.scale_up_threshold) {
        if (current < config.max_instances) {
            decision.action = .scale_up;
            decision.target_instances = @min(current + 1, config.max_instances);
            decision.reason = "CPU above threshold";
            return decision;
        }
    }
    
    if (metrics.queue_depth > config.target_queue_depth) {
        if (current < config.max_instances) {
            decision.action = .scale_up;
            decision.target_instances = @min(current + 2, config.max_instances);
            decision.reason = "Queue depth exceeded";
            return decision;
        }
    }
    
    if (metrics.ttft_p50_ms > config.target_ttft_ms) {
        if (current < config.max_instances) {
            decision.action = .scale_up;
            decision.target_instances = @min(current + 1, config.max_instances);
            decision.reason = "TTFT above target";
            return decision;
        }
    }
    
    // Scale down conditions
    if (metrics.cpu_percent < config.target_cpu_percent * config.scale_down_threshold and
        metrics.queue_depth < 10 and
        current > config.min_instances)
    {
        decision.action = .scale_down;
        decision.target_instances = @max(current - 1, config.min_instances);
        decision.reason = "Low utilization";
    }
    
    return decision;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "metrics registry" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    
    registry.incRequests();
    registry.incRequests();
    registry.addTokens(100);
    registry.setGauges(50.0, 40.0, 10, 5);
    registry.setLatency(25.0, 100.0);
    registry.setThroughput(300.0);
    
    try std.testing.expectEqual(@as(u64, 2), registry.total_requests);
    try std.testing.expectEqual(@as(u64, 100), registry.total_tokens);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), registry.cpu_percent, 0.01);
}

test "scaling decision - scale up on high CPU" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    registry.cpu_percent = 90.0;
    registry.instance_count = 2;
    
    const config = ScalingConfig{};
    const decision = evaluateScaling(&registry, config);
    
    try std.testing.expectEqual(ScalingDecision.Action.scale_up, decision.action);
    try std.testing.expectEqual(@as(u32, 3), decision.target_instances);
}

test "scaling decision - scale down on low utilization" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    registry.cpu_percent = 10.0;
    registry.queue_depth = 5;
    registry.instance_count = 3;
    
    const config = ScalingConfig{};
    const decision = evaluateScaling(&registry, config);
    
    try std.testing.expectEqual(ScalingDecision.Action.scale_down, decision.action);
    try std.testing.expectEqual(@as(u32, 2), decision.target_instances);
}

test "scaling decision - no scaling at min instances" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    registry.cpu_percent = 10.0;
    registry.queue_depth = 5;
    registry.instance_count = 1;
    
    const config = ScalingConfig{};
    const decision = evaluateScaling(&registry, config);
    
    try std.testing.expectEqual(ScalingDecision.Action.none, decision.action);
}

test "prometheus export" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    registry.total_requests = 1000;
    registry.total_tokens = 50000;
    registry.cpu_percent = 45.5;
    registry.ttft_p50_ms = 25.0;
    
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try registry.exportPrometheus(stream.writer());
    
    const output = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_total_requests 1000") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "trinity_cpu_usage_percent 45.50") != null);
}

test "health status" {
    var registry = MetricsRegistry.init(std.testing.allocator);
    var server = HealthServer.init(std.testing.allocator, &registry, ScalingConfig{});
    
    try std.testing.expect(server.health.live);
    try std.testing.expect(!server.health.ready);
    
    server.setReady(true);
    try std.testing.expect(server.health.ready);
    try std.testing.expect(server.health.healthy);
}
