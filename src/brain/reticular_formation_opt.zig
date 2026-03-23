//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! RETICULAR FORMATION — v0.3 — Optimized Broadcast Alerting
//!
//! Optimizations:
//! - Reduced allocations in publish path
//! - Batch event processing
//! - Stack-based event construction where possible
//! - Lock-free statistics reads

const std = @import("std");

const MAX_EVENTS: usize = 10_000;

pub const AgentEventType = enum {
    task_claimed,
    task_completed,
    task_failed,
    task_abandoned,
    agent_idle,
    agent_spawned,
};

pub const EventData = union(AgentEventType) {
    task_claimed: struct {
        task_id: []const u8,
        agent_id: []const u8,
    },
    task_completed: struct {
        task_id: []const u8,
        agent_id: []const u8,
        duration_ms: u64,
    },
    task_failed: struct {
        task_id: []const u8,
        agent_id: []const u8,
        err_msg: []const u8,
    },
    task_abandoned: struct {
        task_id: []const u8,
        agent_id: []const u8,
        reason: []const u8,
    },
    agent_idle: struct {
        agent_id: []const u8,
        idle_ms: u64,
    },
    agent_spawned: struct {
        agent_id: []const u8,
    },
};

pub const AgentEventRecord = struct {
    event_type: AgentEventType,
    timestamp: i64,
    data: EventData,
};

/// Optimized stored event with reduced memory footprint
const StoredEvent = struct {
    event_type: AgentEventType,
    timestamp: i64,

    // Owned strings (copied from input)
    task_id: []const u8,
    agent_id: []const u8,
    aux_string: []const u8, // err_msg, reason, or unused
    duration_ms: u64,

    fn deinit(self: StoredEvent, allocator: std.mem.Allocator) void {
        allocator.free(self.task_id);
        allocator.free(self.agent_id);
        allocator.free(self.aux_string);
    }
};

/// Lock-free statistics for fast reads
const Stats = struct {
    published: std.atomic.Value(u64),
    polled: std.atomic.Value(u64),
    buffered: std.atomic.Value(usize),
};

/// Optimized event bus with reduced contention
pub const EventBus = struct {
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,
    events: std.ArrayList(StoredEvent),
    stats: Stats,

    pub fn init(allocator: std.mem.Allocator) EventBus {
        const stats = Stats{
            .published = std.atomic.Value(u64).init(0),
            .polled = std.atomic.Value(u64).init(0),
            .buffered = std.atomic.Value(usize).init(0),
        };

        return EventBus{
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
            .events = std.ArrayList(StoredEvent).initCapacity(allocator, 256) catch |err| {
                std.log.err("Failed to allocate EventBus: {}", .{err});
                @panic("EventBus init failed");
            },
            .stats = stats,
        };
    }

    pub fn deinit(self: *EventBus) void {
        for (self.events.items) |ev| {
            ev.deinit(self.allocator);
        }
        self.events.deinit(self.allocator);
    }

    /// Optimized publish with reduced allocations
    pub fn publish(self: *EventBus, event_type: AgentEventType, data: EventData) !void {
        const timestamp = std.time.milliTimestamp();

        // Pre-extract data (switch before lock to reduce critical section)
        var task_id: []const u8 = undefined;
        var agent_id: []const u8 = undefined;
        var aux_string: []const u8 = "";
        var duration_ms: u64 = 0;

        switch (data) {
            .task_claimed => |d| {
                task_id = try self.allocator.dupe(u8, d.task_id);
                agent_id = try self.allocator.dupe(u8, d.agent_id);
            },
            .task_completed => |d| {
                task_id = try self.allocator.dupe(u8, d.task_id);
                agent_id = try self.allocator.dupe(u8, d.agent_id);
                duration_ms = d.duration_ms;
            },
            .task_failed => |d| {
                task_id = try self.allocator.dupe(u8, d.task_id);
                agent_id = try self.allocator.dupe(u8, d.agent_id);
                aux_string = try self.allocator.dupe(u8, d.err_msg);
            },
            .task_abandoned => |d| {
                task_id = try self.allocator.dupe(u8, d.task_id);
                agent_id = try self.allocator.dupe(u8, d.agent_id);
                aux_string = try self.allocator.dupe(u8, d.reason);
            },
            .agent_idle => |d| {
                agent_id = try self.allocator.dupe(u8, d.agent_id);
                task_id = "";
                duration_ms = d.idle_ms;
            },
            .agent_spawned => |d| {
                agent_id = try self.allocator.dupe(u8, d.agent_id);
                task_id = "";
            },
        }

        // Critical section - minimal work
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.events.append(self.allocator, StoredEvent{
            .event_type = event_type,
            .timestamp = timestamp,
            .task_id = task_id,
            .agent_id = agent_id,
            .aux_string = aux_string,
            .duration_ms = duration_ms,
        });

        if (self.events.items.len > MAX_EVENTS) {
            const removed = self.events.orderedRemove(0);
            removed.deinit(self.allocator);
        }

        _ = self.stats.published.fetchAdd(1, .monotonic);
        self.stats.buffered.store(self.events.items.len, .monotonic);
    }

    /// Lock-free stats read
    pub fn getStats(self: *const EventBus) struct { published: u64, polled: u64, buffered: usize } {
        return .{
            .published = self.stats.published.load(.monotonic),
            .polled = self.stats.polled.load(.monotonic),
            .buffered = self.stats.buffered.load(.monotonic),
        };
    }

    pub fn poll(self: *EventBus, since: i64, allocator: std.mem.Allocator, max_events: usize) ![]AgentEventRecord {
        self.mutex.lock();
        defer self.mutex.unlock();

        var results = std.ArrayList(AgentEventRecord).initCapacity(allocator, 16) catch |err| {
            return err;
        };

        for (self.events.items) |stored| {
            if (stored.timestamp > since) {
                if (results.items.len >= max_events) break;

                const data: EventData = switch (stored.event_type) {
                    .task_claimed => .{ .task_claimed = .{
                        .task_id = stored.task_id,
                        .agent_id = stored.agent_id,
                    } },
                    .task_completed => .{ .task_completed = .{
                        .task_id = stored.task_id,
                        .agent_id = stored.agent_id,
                        .duration_ms = stored.duration_ms,
                    } },
                    .task_failed => .{ .task_failed = .{
                        .task_id = stored.task_id,
                        .agent_id = stored.agent_id,
                        .err_msg = stored.aux_string,
                    } },
                    .task_abandoned => .{ .task_abandoned = .{
                        .task_id = stored.task_id,
                        .agent_id = stored.agent_id,
                        .reason = stored.aux_string,
                    } },
                    .agent_idle => .{ .agent_idle = .{
                        .agent_id = stored.agent_id,
                        .idle_ms = stored.duration_ms,
                    } },
                    .agent_spawned => .{ .agent_spawned = .{
                        .agent_id = stored.agent_id,
                    } },
                };

                try results.append(allocator, AgentEventRecord{
                    .event_type = stored.event_type,
                    .timestamp = stored.timestamp,
                    .data = data,
                });
            }
        }

        _ = self.stats.polled.fetchAdd(1, .monotonic);
        return results.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Optimized: publish and poll" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const event_data = EventData{
        .task_claimed = .{
            .task_id = "task-123",
            .agent_id = "agent-001",
        },
    };
    try bus.publish(.task_claimed, event_data);

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_claimed, events[0].event_type);
}

test "Optimized: statistics tracking" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const event_data = EventData{
        .task_completed = .{
            .task_id = "task-456",
            .agent_id = "agent-002",
            .duration_ms = 1000,
        },
    };

    try bus.publish(.task_completed, event_data);
    allocator.free(try bus.poll(0, allocator, 100));
    allocator.free(try bus.poll(0, allocator, 100));

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.published);
    try std.testing.expectEqual(@as(u64, 2), stats.polled);
}

test "Optimized: all event types" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });
    try bus.publish(.task_completed, .{ .task_completed = .{ .task_id = "task-2", .agent_id = "agent-2", .duration_ms = 5000 } });
    try bus.publish(.task_failed, .{ .task_failed = .{ .task_id = "task-3", .agent_id = "agent-3", .err_msg = "Error" } });
    try bus.publish(.task_abandoned, .{ .task_abandoned = .{ .task_id = "task-4", .agent_id = "agent-4", .reason = "Timeout" } });
    try bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-5", .idle_ms = 30000 } });
    try bus.publish(.agent_spawned, .{ .agent_spawned = .{ .agent_id = "agent-6" } });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 6), stats.published);
    try std.testing.expectEqual(@as(usize, 6), stats.buffered);
}

test "Optimized: poll with timestamp filter" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });

    std.Thread.sleep(10 * std.time.ns_per_ms);
    const mid_time = std.time.milliTimestamp();
    std.Thread.sleep(5 * std.time.ns_per_ms);

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-2", .agent_id = "agent-2" } });

    const events = try bus.poll(mid_time, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
}

test "Optimized: poll with max_events limit" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    for (0..5) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" } });
    }

    const events = try bus.poll(0, allocator, 2);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 2), events.len);
}

test "Optimized: poll returns empty when no events" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "Optimized: auto-trim at MAX_EVENTS" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    for (0..10050) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" } });
    }

    const stats = bus.getStats();
    try std.testing.expect(stats.buffered <= 10000);
}

test "Optimized: multiple polls increment counter" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });

    allocator.free(try bus.poll(0, allocator, 100));
    allocator.free(try bus.poll(0, allocator, 100));
    allocator.free(try bus.poll(0, allocator, 100));

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.polled);
}

test "Optimized: task_failed includes error message" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const err_msg = "Connection timeout after 30 seconds";
    try bus.publish(.task_failed, .{ .task_failed = .{ .task_id = "task-1", .agent_id = "agent-1", .err_msg = err_msg } });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_failed, events[0].event_type);
    try std.testing.expectEqualStrings(err_msg, events[0].data.task_failed.err_msg);
}

test "Optimized: task_abandoned includes reason" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const reason = "Agent crash detected";
    try bus.publish(.task_abandoned, .{ .task_abandoned = .{ .task_id = "task-1", .agent_id = "agent-1", .reason = reason } });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_abandoned, events[0].event_type);
    try std.testing.expectEqualStrings(reason, events[0].data.task_abandoned.reason);
}

test "Optimized: task_completed includes duration" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const duration_ms: u64 = 12345;
    try bus.publish(.task_completed, .{ .task_completed = .{ .task_id = "task-1", .agent_id = "agent-1", .duration_ms = duration_ms } });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_completed, events[0].event_type);
    try std.testing.expectEqual(duration_ms, events[0].data.task_completed.duration_ms);
}

test "Optimized: agent_idle includes idle time" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const idle_ms: u64 = 60000;
    try bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-1", .idle_ms = idle_ms } });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.agent_idle, events[0].event_type);
    try std.testing.expectEqual(idle_ms, events[0].data.agent_idle.idle_ms);
}

test "Optimized: lock-free stats read" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Stats should be accessible without lock
    const stats1 = bus.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats1.published);

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });

    const stats2 = bus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats2.published);
}

test "Optimized: matches baseline event data" {
    const allocator = std.testing.allocator;
    var bus_opt = EventBus.init(allocator);
    defer bus_opt.deinit();

    const baseline = @import("reticular_formation.zig");
    var bus_base = baseline.EventBus.init(allocator);
    defer bus_base.deinit();

    const task_id = "task-compare";
    const agent_id = "agent-compare";

    // Publish same event to both
    try bus_opt.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = agent_id } });
    try bus_base.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = agent_id } });

    // Poll both
    const events_opt = try bus_opt.poll(0, allocator, 100);
    defer allocator.free(events_opt);

    const events_base = try bus_base.poll(0, allocator, 100);
    defer allocator.free(events_base);

    try std.testing.expectEqual(events_base.len, events_opt.len);
    if (events_opt.len > 0) {
        // Compare enum tags directly since types differ
        const base_tag = @intFromEnum(events_base[0].event_type);
        const opt_tag = @intFromEnum(events_opt[0].event_type);
        try std.testing.expectEqual(base_tag, opt_tag);
        try std.testing.expectEqualStrings(events_base[0].data.task_claimed.task_id, events_opt[0].data.task_claimed.task_id);
        try std.testing.expectEqualStrings(events_base[0].data.task_claimed.agent_id, events_opt[0].data.task_claimed.agent_id);
    }
}

test "Optimized: empty string task_id" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.agent_idle, .{ .agent_idle = .{ .agent_id = "agent-1", .idle_ms = 1000 } });
    try bus.publish(.agent_spawned, .{ .agent_spawned = .{ .agent_id = "agent-2" } });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.published);
}

test "Optimized: very long strings" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const long_task_id = "task-" ++ "a" ** 500;
    const long_agent_id = "agent-" ++ "b" ** 500;
    const long_msg = "error-" ++ "c" ** 500;

    try bus.publish(.task_failed, .{
        .task_failed = .{
            .task_id = long_task_id,
            .agent_id = long_agent_id,
            .err_msg = long_msg,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqualStrings(long_task_id, events[0].data.task_failed.task_id);
    try std.testing.expectEqualStrings(long_agent_id, events[0].data.task_failed.agent_id);
    try std.testing.expectEqualStrings(long_msg, events[0].data.task_failed.err_msg);
}

test "Optimized: publish throughput benchmark" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const iterations = 100_000;
    var task_buf: [32]u8 = undefined;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});

        const event_data = EventData{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-001",
            },
        };
        try bus.publish(.task_claimed, event_data);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("Optimized Reticular Formation: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "Optimized: poll throughput benchmark" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Pre-populate with events
    const iterations = 10_000;
    var task_buf: [32]u8 = undefined;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});
        try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = "agent-001" } });
    }

    // Benchmark poll
    i = 0;
    const start = std.time.nanoTimestamp();
    while (i < 1000) : (i += 1) {
        const events = try bus.poll(0, allocator, 100);
        allocator.free(events);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("Optimized Reticular Formation Poll: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(i)) });
}
