//! BRAIN PERFORMANCE BENCHMARK — Test-based
const std = @import("std");
const basal_ganglia = @import("basal_ganglia.zig");
const reticular_formation = @import("reticular_formation.zig");
const locus_coeruleus = @import("locus_coeruleus.zig");

test "benchmark: claim throughput 100k" {
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
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.log.info("Claim: {d} ops in {d:.2}ms = {d:.0} OP/s", .{ iterations, elapsed_ms, ops_per_sec });
    try std.testing.expect(ops_per_sec > 10_000);
}

test "benchmark: event publish 100k" {
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
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.log.info("Event: {d} ops in {d:.2}ms = {d:.0} OP/s", .{ iterations, elapsed_ms, ops_per_sec });
    try std.testing.expect(ops_per_sec > 10_000);
}

test "benchmark: backoff 1M" {
    const policy = locus_coeruleus.BackoffPolicy.init();
    const iterations = 1_000_000;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const attempt = @as(u32, @intCast(i % 100));
        _ = policy.nextDelay(attempt);
    }
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.log.info("Backoff: {d} ops in {d:.2}ms = {d:.0} OP/s", .{ iterations, elapsed_ms, ops_per_sec });
    try std.testing.expect(ops_per_sec > 1_000_000);
}

test "benchmark: string alloc 100k" {
    const allocator = std.testing.allocator;
    const iterations = 100_000;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const s = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        allocator.free(s);
    }
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.log.info("String: {d} ops in {d:.2}ms = {d:.0} OP/s", .{ iterations, elapsed_ms, ops_per_sec });
    try std.testing.expect(ops_per_sec > 100_000);
}

test "benchmark: optimized claim with stack buffer" {
    const allocator = std.testing.allocator;
    var registry = basal_ganglia.Registry.init(allocator);
    defer registry.deinit();

    const iterations = 100_000;
    const start = std.time.nanoTimestamp();

    // Use stack buffer for task IDs to avoid alloc
    var task_id_buf: [32]u8 = undefined;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_id_buf, "task-{d}", .{i});
        _ = try registry.claim(allocator, task_id, "agent-001", 300000);
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(end - start)) / 1_000_000_000.0);

    std.log.info("Optimized Claim: {d} ops in {d:.2}ms = {d:.0} OP/s", .{ iterations, elapsed_ms, ops_per_sec });
    try std.testing.expect(ops_per_sec > 100_000);
}
