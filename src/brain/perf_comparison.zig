//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN PERFORMANCE COMPARISON — Baseline vs Optimized
const std = @import("std");

const baseline_basal = @import("basal_ganglia.zig");
const baseline_reticular = @import("reticular_formation.zig");
const opt_basal = @import("basal_ganglia_opt.zig");
const opt_reticular = @import("reticular_formation_opt.zig");

test "perf.comparison.basal" {
    const allocator = std.testing.allocator;
    const iterations = 100_000;

    // Baseline
    {
        var registry = baseline_basal.Registry.init(allocator);
        defer registry.deinit();

        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);
            _ = try registry.claim(allocator, task_id, "agent-001", 300000);
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
        _ = std.debug.print("  Baseline Basal: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
    }

    // Optimized
    {
        var registry = opt_basal.Registry.init(allocator);
        defer registry.deinit();

        var task_buf: [32]u8 = undefined;
        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});
            _ = try registry.claimStack(allocator, task_id, "agent-001", 300000);
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
        _ = std.debug.print("  Optimized Basal: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
    }
}

test "perf.comparison.reticular" {
    const allocator = std.testing.allocator;
    const iterations = 100_000;

    // Baseline
    {
        var bus = baseline_reticular.EventBus.init(allocator);
        defer bus.deinit();

        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);

            const event_data = baseline_reticular.EventData{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-001",
                },
            };
            try bus.publish(.task_claimed, event_data);
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
        _ = std.debug.print("  Baseline Reticular: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
    }

    // Optimized
    {
        var bus = opt_reticular.EventBus.init(allocator);
        defer bus.deinit();

        var task_buf: [32]u8 = undefined;
        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});

            const event_data = opt_reticular.EventData{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-001",
                },
            };
            try bus.publish(.task_claimed, event_data);
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
        _ = std.debug.print("  Optimized Reticular: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
    }
}
