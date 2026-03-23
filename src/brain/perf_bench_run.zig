//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN PERFORMANCE BENCHMARK — v1.0 — Hot Path Profiling
//!
//! Direct benchmark of core brain operations.

const std = @import("std");
const builtin = @import("builtin");
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");

pub fn main() !void {
    std.debug.print(
        \\S3AI BRAIN PERFORMANCE BENCHMARKS
        \\=================================
        \\
    , .{});

    const allocator = std.heap.page_allocator;

    // Basal Ganglia: Task Claim Throughput
    try benchmarkClaimThroughput(allocator, 100_000);

    // Reticular Formation: Event Publish Throughput
    try benchmarkEventPublish(allocator, 100_000);

    // Locus Coeruleus: Backoff Calculation
    try benchmarkBackoff(allocator, 1_000_000);

    // Memory allocation overhead
    try benchmarkStringAlloc(allocator, 100_000);

    std.debug.print("All benchmarks completed\n", .{});
}

fn benchmarkClaimThroughput(allocator: std.mem.Allocator, iterations: u64) !void {
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 300000);
    }
    const end = std.time.nanoTimestamp();

    const elapsed_ns = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Basal Ganglia Claim Throughput:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total: {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
    std.debug.print("  Avg: {d:.2} ns/op\n", .{avg_ns});
    std.debug.print("  Throughput: {d:.0} OP/s\n\n", .{ops_per_sec});
}

fn benchmarkEventPublish(allocator: std.mem.Allocator, iterations: u64) !void {
    var bus = reticular_formation.EventBus.init(allocator);
    defer bus.deinit();

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);

        const event_data = reticular_formation.EventData{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-001",
            },
        };
        try bus.publish(.task_claimed, event_data);
    }
    const end = std.time.nanoTimestamp();

    const elapsed_ns = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Reticular Formation Event Publish:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total: {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
    std.debug.print("  Avg: {d:.2} ns/op\n", .{avg_ns});
    std.debug.print("  Throughput: {d:.0} OP/s\n\n", .{ops_per_sec});
}

fn benchmarkBackoff(allocator: std.mem.Allocator, iterations: u64) !void {
    _ = allocator;
    const policy = locus_coeruleus.BackoffPolicy.init();

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const attempt = @as(u32, @intCast(i % 100));
        _ = policy.nextDelay(attempt);
    }
    const end = std.time.nanoTimestamp();

    const elapsed_ns = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Locus Coeruleus Backoff Calc:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total: {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
    std.debug.print("  Avg: {d:.3} ns/op\n", .{avg_ns});
    std.debug.print("  Throughput: {d:.0} OP/s\n\n", .{ops_per_sec});
}

fn benchmarkStringAlloc(allocator: std.mem.Allocator, iterations: u64) !void {
    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const s = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        allocator.free(s);
    }
    const end = std.time.nanoTimestamp();

    const elapsed_ns = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("String Allocation Overhead:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total: {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
    std.debug.print("  Avg: {d:.2} ns/op\n", .{avg_ns});
    std.debug.print("  Throughput: {d:.0} alloc+free/s\n\n", .{ops_per_sec});
}
