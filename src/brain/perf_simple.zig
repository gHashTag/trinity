//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN PERFORMANCE BENCHMARK — Simple print-based
const std = @import("std");
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");

test "perf.basal" {
    const allocator = std.testing.allocator;
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    const iterations = 100_000;
    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 300000);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("Basal Ganglia: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "perf.reticular" {
    const allocator = std.testing.allocator;
    var bus = reticular_formation.EventBus.init(allocator);
    defer bus.deinit();

    const iterations = 100_000;
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
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("Reticular Formation: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "perf.locus" {
    const policy = locus_coeruleus.BackoffPolicy.init();
    const iterations = 1_000_000;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const attempt = @as(u32, @intCast(i % 100));
        _ = policy.nextDelay(attempt);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("Locus Coeruleus: {d:.0} OP/s ({d:.3} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "perf.string_alloc" {
    const allocator = std.testing.allocator;
    const iterations = 100_000;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const s = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        allocator.free(s);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("String Alloc+Free: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}
