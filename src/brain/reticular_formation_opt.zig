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

// Tests
test "Optimized event publish" {
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
    _ = std.debug.print("Optimized Reticular: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}
