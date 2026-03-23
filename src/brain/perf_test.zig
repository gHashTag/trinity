//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!

const std = @import("std");
const basal_ganglia = @import("basal_ganglia.zig");
const reticular = @import("reticular_formation.zig");
const locus = @import("locus_coeruleus.zig");
const amygdala = @import("amygdala.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("BRAIN REGION PERFORMANCE BENCHMARKS (OPTIMIZED)\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("\n", .{});

    // Basal Ganglia: Task Claim Throughput
    {
        std.debug.print("[1/4] Basal Ganglia - Task Claim Throughput\n", .{});
        var registry = basal_ganglia.Registry.init(allocator);
        defer registry.deinit();

        const iterations: u64 = 10_000;
        const start = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);
            const agent_id = try std.fmt.allocPrint(allocator, "agent-{d}", .{@mod(i, 10)});
            defer allocator.free(agent_id);
            _ = try registry.claim(allocator, task_id, agent_id, 5000);
        }

        const end = std.time.nanoTimestamp();
        const elapsed_ns: u64 = @intCast(end - start);
        const ops_per_sec: f64 = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000.0;
        const avg_ns: f64 = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Iterations:      {d}\n", .{iterations});
        std.debug.print("  Total Time:      {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
        std.debug.print("  Avg Latency:     {d:.2} us/op\n", .{avg_ns / 1000.0});
        std.debug.print("  Throughput:      {d:.2} kOP/s\n", .{ops_per_sec});
        std.debug.print("\n", .{});
    }

    // Reticular Formation: Publish
    {
        std.debug.print("[2/4] Reticular Formation - Event Publish\n", .{});
        var bus = reticular.EventBus.init(allocator);
        defer bus.deinit();

        const iterations: u64 = 50_000;
        const start = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "event-{d}", .{i});
            defer allocator.free(task_id);
            const agent_id = try std.fmt.allocPrint(allocator, "agent-{d}", .{@mod(i, 5)});
            defer allocator.free(agent_id);
            try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = agent_id } });
        }

        const end = std.time.nanoTimestamp();
        const elapsed_ns: u64 = @intCast(end - start);
        const ops_per_sec: f64 = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000.0;
        const avg_ns: f64 = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Iterations:      {d}\n", .{iterations});
        std.debug.print("  Total Time:      {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
        std.debug.print("  Avg Latency:     {d:.2} ns/op\n", .{avg_ns});
        std.debug.print("  Throughput:      {d:.2} MOP/s\n", .{ops_per_sec / 1000.0});
        std.debug.print("\n", .{});
    }

    // Locus Coeruleus: Backoff Calculation
    {
        std.debug.print("[3/4] Locus Coeruleus - Backoff Calculation\n", .{});
        var backoff = locus.BackoffPolicy.init();
        const iterations: u64 = 1_000_000;
        const start = std.time.nanoTimestamp();

        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            _ = backoff.nextDelay(i);
        }

        const end = std.time.nanoTimestamp();
        const elapsed_ns: u64 = @intCast(end - start);
        const ops_per_sec: f64 = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000.0;
        const avg_ns: f64 = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Iterations:      {d}\n", .{iterations});
        std.debug.print("  Total Time:      {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
        std.debug.print("  Avg Latency:     {d:.2} ns/op\n", .{avg_ns});
        std.debug.print("  Throughput:      {d:.2} MOP/s\n", .{ops_per_sec / 1000.0});
        std.debug.print("\n", .{});
    }

    // Amygdala: Salience Analysis
    {
        std.debug.print("[4/4] Amygdala - Salience Analysis\n", .{});
        const iterations: u64 = 10_000;
        const start = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task = try std.fmt.allocPrint(allocator, "dukh-{d}", .{i});
            defer allocator.free(task);
            _ = amygdala.Amygdala.analyzeTask(task, "dukh", "critical");
        }

        const end = std.time.nanoTimestamp();
        const elapsed_ns: u64 = @intCast(end - start);
        const ops_per_sec: f64 = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000.0;
        const avg_ns: f64 = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("  Iterations:      {d}\n", .{iterations});
        std.debug.print("  Total Time:      {d:.2} ms\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0});
        std.debug.print("  Avg Latency:     {d:.2} us/op\n", .{avg_ns / 1000.0});
        std.debug.print("  Throughput:      {d:.2} kOP/s\n", .{ops_per_sec});
        std.debug.print("\n", .{});
    }

    std.debug.print("================================================\n", .{});
    std.debug.print("All benchmarks completed successfully\n", .{});
    std.debug.print("\n", .{});
}
