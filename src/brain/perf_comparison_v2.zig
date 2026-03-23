//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN PERFORMANCE COMPARISON v2 — Baseline vs Optimized (Comprehensive)
//!
//! Compares performance across all brain regions with detailed metrics.
const std = @import("std");

const baseline_basal = @import("basal_ganglia.zig");
const baseline_reticular = @import("reticular_formation.zig");
const baseline_amygdala = @import("amygdala.zig");
const opt_basal = @import("basal_ganglia_opt.zig");
const opt_reticular = @import("reticular_formation_opt.zig");
const opt_amygdala = @import("amygdala_opt.zig");

/// Print performance summary table
fn printSummary() void {
    _ = std.debug.print("\n╔══════════════════════════════════════════════════════════════════╗\n", .{});
    _ = std.debug.print("║  S³AI BRAIN PERFORMANCE OPTIMIZATION RESULTS                    ║\n", .{});
    _ = std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
    _ = std.debug.print("║  Region          │ Baseline    │ Optimized   │ Improvement  ║\n", .{});
    _ = std.debug.print("╠══════════════════════════════════════════════════════════════════╣\n", .{});
}

test "perf.comparison.basal" {
    const allocator = std.testing.allocator;
    const iterations = 100_000;

    printSummary();

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
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Basal Ganglia   │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ ops_per_sec, 0.0, "-" });
        _ = std.debug.print("║                  │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ ns_per_op, 0.0 });
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
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Basal Ganglia   │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ 0.0, ops_per_sec, "-" });
        _ = std.debug.print("║                  │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ 0.0, ns_per_op });
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
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Reticular       │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ ops_per_sec, 0.0, "-" });
        _ = std.debug.print("║  Formation       │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ ns_per_op, 0.0 });
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
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Reticular       │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ 0.0, ops_per_sec, "-" });
        _ = std.debug.print("║  Formation       │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ 0.0, ns_per_op });
    }
}

test "perf.comparison.amygdala" {
    const iterations = 1_000_000;

    // Baseline
    {
        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            _ = baseline_amygdala.Amygdala.analyzeTask("task-urgent", "dukh", "critical");
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Amygdala        │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ ops_per_sec, 0.0, "-" });
        _ = std.debug.print("║  (Salience)      │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ ns_per_op, 0.0 });
    }

    // Optimized
    {
        const start = std.time.nanoTimestamp();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            _ = opt_amygdala.Amygdala.analyzeTask("task-urgent", "dukh", "critical");
        }
        const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
        const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns)) * 1_000_000_000.0;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        _ = std.debug.print("║  Amygdala        │ {d:>9.0}/s │ {d:>9.0}/s │ {s:>9.2}%  ║\n", .{ 0.0, ops_per_sec, "-" });
        _ = std.debug.print("║  (Salience)      │ {d:>8.1}ns/op │ {d:>8.1}ns/op │             ║\n", .{ 0.0, ns_per_op });
    }

    _ = std.debug.print("╚══════════════════════════════════════════════════════════════════╝\n\n", .{});
}
