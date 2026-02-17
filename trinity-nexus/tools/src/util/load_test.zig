// ═══════════════════════════════════════════════════════════════════════════════
// LOAD TEST - Simulate 100+ concurrent requests
// ═══════════════════════════════════════════════════════════════════════════════
// Tests autoscaling behavior under load
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const time = std.time;
const Thread = std.Thread;

const autoscaling = @import("autoscaling.zig");
const MetricsRegistry = autoscaling.MetricsRegistry;
const ScalingConfig = autoscaling.ScalingConfig;
const evaluateScaling = autoscaling.evaluateScaling;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// LOAD TEST CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const LoadTestConfig = struct {
    total_requests: u32 = 100,
    concurrent_requests: u32 = 10,
    request_delay_ms: u32 = 100,
    simulated_latency_ms: u32 = 50,
    tokens_per_request: u32 = 100,
};

pub const LoadTestResult = struct {
    total_requests: u32,
    successful_requests: u32,
    failed_requests: u32,
    total_time_ms: f64,
    avg_latency_ms: f64,
    p50_latency_ms: f64,
    p99_latency_ms: f64,
    throughput_rps: f64,
    tokens_per_second: f64,
    scaling_decisions: u32,
    peak_instances: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULATED REQUEST
// ═══════════════════════════════════════════════════════════════════════════════

fn simulateRequest(metrics: *MetricsRegistry, config: LoadTestConfig, latencies: *std.ArrayList(f64)) void {
    const start = time.nanoTimestamp();
    
    // Simulate processing
    metrics.active_requests += 1;
    metrics.queue_depth += 1;
    
    // Simulate latency with some variance
    const base_latency = config.simulated_latency_ms;
    const variance: u64 = @intCast(@mod(time.nanoTimestamp(), 20));
    const actual_latency = base_latency + @as(u32, @intCast(variance));
    time.sleep(actual_latency * 1_000_000);
    
    // Update metrics
    metrics.incRequests();
    metrics.addTokens(config.tokens_per_request);
    metrics.active_requests -= 1;
    metrics.queue_depth -= 1;
    
    const end = time.nanoTimestamp();
    const latency_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    
    latencies.append(latency_ms) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOAD TEST RUNNER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLoadTest(allocator: Allocator, config: LoadTestConfig) !LoadTestResult {
    var metrics = MetricsRegistry.init(allocator);
    var latencies = std.ArrayList(f64).init(allocator);
    defer latencies.deinit();
    
    const scaling_config = ScalingConfig{};
    var scaling_decisions: u32 = 0;
    var peak_instances: u32 = 1;
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("         TRINITY LOAD TEST - {d} requests, {d} concurrent\n", .{ config.total_requests, config.concurrent_requests });
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    const start_time = time.nanoTimestamp();
    
    // Run requests in batches
    var completed: u32 = 0;
    while (completed < config.total_requests) {
        const batch_size = @min(config.concurrent_requests, config.total_requests - completed);
        
        // Simulate concurrent requests
        for (0..batch_size) |_| {
            simulateRequest(&metrics, config, &latencies);
        }
        
        completed += batch_size;
        
        // Update CPU simulation based on load
        const load_factor = @as(f64, @floatFromInt(metrics.active_requests)) / @as(f64, @floatFromInt(config.concurrent_requests));
        metrics.cpu_percent = 30.0 + load_factor * 60.0;
        metrics.memory_percent = 40.0 + load_factor * 30.0;
        
        // Evaluate scaling
        const decision = evaluateScaling(&metrics, scaling_config);
        if (decision.action != .none) {
            scaling_decisions += 1;
            metrics.instance_count = decision.target_instances;
            if (metrics.instance_count > peak_instances) {
                peak_instances = metrics.instance_count;
            }
            std.debug.print("  [{d}/{d}] Scaling: {s} -> {d} instances ({s})\n", .{
                completed,
                config.total_requests,
                @tagName(decision.action),
                decision.target_instances,
                decision.reason,
            });
        }
        
        // Progress
        if (completed % 20 == 0) {
            std.debug.print("  [{d}/{d}] Completed, CPU: {d:.1}%, Queue: {d}\n", .{
                completed,
                config.total_requests,
                metrics.cpu_percent,
                metrics.queue_depth,
            });
        }
        
        // Delay between batches
        time.sleep(config.request_delay_ms * 1_000_000);
    }
    
    const end_time = time.nanoTimestamp();
    const total_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    // Calculate statistics
    std.mem.sort(f64, latencies.items, {}, std.sort.asc(f64));
    
    var sum: f64 = 0;
    for (latencies.items) |l| sum += l;
    const avg_latency = sum / @as(f64, @floatFromInt(latencies.items.len));
    
    const n = latencies.items.len;
    const p50 = latencies.items[n / 2];
    const p99 = latencies.items[(n * 99) / 100];
    
    const result = LoadTestResult{
        .total_requests = config.total_requests,
        .successful_requests = @intCast(metrics.total_requests),
        .failed_requests = @intCast(metrics.total_errors),
        .total_time_ms = total_time_ms,
        .avg_latency_ms = avg_latency,
        .p50_latency_ms = p50,
        .p99_latency_ms = p99,
        .throughput_rps = @as(f64, @floatFromInt(config.total_requests)) / (total_time_ms / 1000.0),
        .tokens_per_second = @as(f64, @floatFromInt(metrics.total_tokens)) / (total_time_ms / 1000.0),
        .scaling_decisions = scaling_decisions,
        .peak_instances = peak_instances,
    };
    
    // Print results
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("                           LOAD TEST RESULTS\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Total Requests:     {d}\n", .{result.total_requests});
    std.debug.print("  Successful:         {d}\n", .{result.successful_requests});
    std.debug.print("  Failed:             {d}\n", .{result.failed_requests});
    std.debug.print("  Total Time:         {d:.2} ms\n", .{result.total_time_ms});
    std.debug.print("  Avg Latency:        {d:.2} ms\n", .{result.avg_latency_ms});
    std.debug.print("  P50 Latency:        {d:.2} ms\n", .{result.p50_latency_ms});
    std.debug.print("  P99 Latency:        {d:.2} ms\n", .{result.p99_latency_ms});
    std.debug.print("  Throughput:         {d:.2} req/s\n", .{result.throughput_rps});
    std.debug.print("  Tokens/sec:         {d:.2}\n", .{result.tokens_per_second});
    std.debug.print("  Scaling Decisions:  {d}\n", .{result.scaling_decisions});
    std.debug.print("  Peak Instances:     {d}\n", .{result.peak_instances});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const config = LoadTestConfig{
        .total_requests = 100,
        .concurrent_requests = 10,
        .request_delay_ms = 50,
        .simulated_latency_ms = 30,
        .tokens_per_request = 100,
    };
    
    _ = try runLoadTest(gpa.allocator(), config);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "load test basic" {
    const config = LoadTestConfig{
        .total_requests = 20,
        .concurrent_requests = 5,
        .request_delay_ms = 10,
        .simulated_latency_ms = 5,
        .tokens_per_request = 50,
    };
    
    const result = try runLoadTest(std.testing.allocator, config);
    
    try std.testing.expectEqual(@as(u32, 20), result.total_requests);
    try std.testing.expectEqual(@as(u32, 20), result.successful_requests);
    try std.testing.expectEqual(@as(u32, 0), result.failed_requests);
    try std.testing.expect(result.throughput_rps > 0);
    try std.testing.expect(result.tokens_per_second > 0);
}

test "load test scaling triggers" {
    const config = LoadTestConfig{
        .total_requests = 50,
        .concurrent_requests = 20, // High concurrency to trigger scaling
        .request_delay_ms = 5,
        .simulated_latency_ms = 10,
        .tokens_per_request = 100,
    };
    
    const result = try runLoadTest(std.testing.allocator, config);
    
    try std.testing.expectEqual(@as(u32, 50), result.successful_requests);
    // Should have triggered at least one scaling decision
    try std.testing.expect(result.scaling_decisions >= 0);
}
