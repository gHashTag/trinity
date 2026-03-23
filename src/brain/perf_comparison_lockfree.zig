//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! Performance Comparison: Lock-Free Sharded HashMap vs Baseline
//!
//! Compares three implementations:
//! 1. Baseline: Original RwLock on entire HashMap
//! 2. Optimized: Mutex-only with stack-based task IDs
//! 3. Lock-Free: Sharded HashMap with per-shard RwLock

const std = @import("std");
const builtin = @import("builtin");

const Baseline = @import("basal_ganglia.zig").Registry;
const Optimized = @import("basal_ganglia_opt.zig").Registry;
const LockFree = @import("basal_ganglia_lockfree.zig").Registry;

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();

    const iterations = 100_000;

    // Baseline
    var baseline = Baseline.init(std.heap.page_allocator);
    defer baseline.deinit();
    const baseline_ns = benchmarkClaim(&baseline, iterations, "Baseline");
    const baseline_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(baseline_ns));

    // Optimized
    var optimized = Optimized.init(std.heap.page_allocator);
    defer optimized.deinit();
    const optimized_ns = benchmarkClaim(&optimized, iterations, "Optimized");
    const optimized_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(optimized_ns));

    // Lock-Free
    var lockfree = LockFree.init(std.heap.page_allocator);
    defer lockfree.deinit();
    const lockfree_ns = benchmarkClaim(&lockfree, iterations, "Lock-Free");
    const lockfree_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(lockfree_ns));

    try stdout.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║  Basal Ganglia Performance Comparison                          ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  Implementation  │ Throughput   │ Latency     │ vs Baseline  ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  Baseline        │ ", .{});
    try formatThroughput(stdout, baseline_ops);
    try stdout.print(" │ ", .{});
    try formatLatency(stdout, baseline_ns, iterations);
    try stdout.print(" │      1.00x   ║\n", .{});

    try stdout.print("║  Optimized       │ ", .{});
    try formatThroughput(stdout, optimized_ops);
    try stdout.print(" │ ", .{});
    try formatLatency(stdout, optimized_ns, iterations);
    const speedup_opt = optimized_ops / baseline_ops;
    try stdout.print(" │ ", .{});
    try formatSpeedup(stdout, speedup_opt);
    try stdout.print("   ║\n", .{});

    try stdout.print("║  Lock-Free       │ ", .{});
    try formatThroughput(stdout, lockfree_ops);
    try stdout.print(" │ ", .{});
    try formatLatency(stdout, lockfree_ns, iterations);
    const speedup_lf = lockfree_ops / baseline_ops;
    try stdout.print(" │ ", .{});
    try formatSpeedup(stdout, speedup_lf);
    try stdout.print("   ║\n", .{});

    try stdout.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});

    try stdout.print("\nKey Insights:\n", .{});
    try stdout.print("  - Lock-Free sharding: {d:.1}x faster than baseline\n", .{speedup_lf});
    try stdout.print("  - {d:.1}x faster than optimized (single mutex)\n", .{lockfree_ops / optimized_ops});
    try stdout.print("  - Target >10k OP/s: ", .{});
    if (lockfree_ops > 10_000.0) {
        try stdout.writeAll("✓ ACHIEVED\n");
    } else {
        try stdout.writeAll("✗ NOT ACHIEVED\n");
    }
    try stdout.print("\n", .{});
}

fn benchmarkClaim(registry: anytype, iterations: u64, name: []const u8) u64 {
    var task_buf: [32]u8 = undefined;
    const allocator = std.heap.page_allocator;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch unreachable;
        _ = registry.claim(allocator, task_id, "agent-001", 300000) catch {};
    }
    const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));

    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed));
    std.debug.print("{s}: {d:.0} OP/s ({d:.2} ns/op)\n", .{ name, ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations)) });

    return elapsed;
}

fn formatThroughput(writer: anytype, ops: f64) !void {
    if (ops >= 1_000_000) {
        try writer.print("{d:.2} MOP/s", .{ops / 1_000_000.0});
    } else if (ops >= 1_000) {
        try writer.print("{d:.2} kOP/s", .{ops / 1_000.0});
    } else {
        try writer.print("{d:.0} OP/s", .{ops});
    }
}

fn formatLatency(writer: anytype, total_ns: u64, iterations: u64) !void {
    const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iterations));
    try writer.print("{d:.2} ns/op", .{avg_ns});
}

fn formatSpeedup(writer: anytype, speedup: f64) !void {
    try writer.print("{d:.2}x", .{speedup});
}
