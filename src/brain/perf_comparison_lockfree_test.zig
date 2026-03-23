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

const Baseline = @import("basal_ganglia.zig").Registry;
const Optimized = @import("basal_ganglia_opt.zig").Registry;
const LockFree = @import("basal_ganglia_lockfree.zig").Registry;

test "perf.comparison.all: baseline vs optimized vs lockfree" {
    const iterations = 100_000;
    const allocator = std.testing.allocator;

    // Baseline
    var baseline = Baseline.init(allocator);
    defer baseline.deinit();
    const baseline_ns = benchmarkClaim(&baseline, iterations, allocator);
    const baseline_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(baseline_ns));

    // Optimized
    var optimized = Optimized.init(allocator);
    defer optimized.deinit();
    const optimized_ns = benchmarkClaim(&optimized, iterations, allocator);
    const optimized_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(optimized_ns));

    // Lock-Free
    var lockfree = LockFree.init(allocator);
    defer lockfree.deinit();
    const lockfree_ns = benchmarkClaim(&lockfree, iterations, allocator);
    const lockfree_ops = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(lockfree_ns));

    _ = std.debug.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
    _ = std.debug.print("║  Basal Ganglia Performance Comparison                          ║\n", .{});
    _ = std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    _ = std.debug.print("║  Implementation  │ Throughput   │ Latency     │ vs Baseline  ║\n", .{});
    _ = std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});

    _ = std.debug.print("║  Baseline        │ ", .{});
    formatThroughput(baseline_ops);
    _ = std.debug.print(" │ ", .{});
    formatLatency(baseline_ns, iterations);
    _ = std.debug.print(" │      1.00x   ║\n", .{});

    _ = std.debug.print("║  Optimized       │ ", .{});
    formatThroughput(optimized_ops);
    _ = std.debug.print(" │ ", .{});
    formatLatency(optimized_ns, iterations);
    const speedup_opt = optimized_ops / baseline_ops;
    _ = std.debug.print(" │ ", .{});
    formatSpeedup(speedup_opt);
    _ = std.debug.print("   ║\n", .{});

    _ = std.debug.print("║  Lock-Free       │ ", .{});
    formatThroughput(lockfree_ops);
    _ = std.debug.print(" │ ", .{});
    formatLatency(lockfree_ns, iterations);
    const speedup_lf = lockfree_ops / baseline_ops;
    _ = std.debug.print(" │ ", .{});
    formatSpeedup(speedup_lf);
    _ = std.debug.print("   ║\n", .{});

    _ = std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n", .{});

    _ = std.debug.print("\nKey Insights:\n", .{});
    _ = std.debug.print("  - Lock-Free sharding: {d:.1}x faster than baseline\n", .{speedup_lf});
    _ = std.debug.print("  - {d:.1}x faster than optimized (single mutex)\n", .{lockfree_ops / optimized_ops});
    _ = std.debug.print("  - Target >10k OP/s: ", .{});
    if (lockfree_ops > 10_000.0) {
        _ = std.debug.print("✓ ACHIEVED\n", .{});
    } else {
        _ = std.debug.print("✗ NOT ACHIEVED\n", .{});
    }
    _ = std.debug.print("\n", .{});
}

fn benchmarkClaim(registry: anytype, iterations: u64, allocator: std.mem.Allocator) u64 {
    var task_buf: [32]u8 = undefined;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch unreachable;
        _ = registry.claim(allocator, task_id, "agent-001", 300000) catch {};
    }
    const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));

    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed));
    std.debug.print("Benchmark: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations)) });

    return elapsed;
}

fn formatThroughput(ops: f64) void {
    if (ops >= 1_000_000) {
        std.debug.print("{d:.2} MOP/s", .{ops / 1_000_000.0});
    } else if (ops >= 1_000) {
        std.debug.print("{d:.2} kOP/s", .{ops / 1_000.0});
    } else {
        std.debug.print("{d:.0} OP/s", .{ops});
    }
}

fn formatLatency(total_ns: u64, iterations: u64) void {
    const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iterations));
    std.debug.print("{d:.2} ns/op", .{avg_ns});
}

fn formatSpeedup(speedup: f64) void {
    std.debug.print("{d:.2}x", .{speedup});
}
