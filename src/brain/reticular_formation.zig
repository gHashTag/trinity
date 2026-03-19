//! RETICULAR FORMATION — v0.2 — Broadcast Alerting
//!
//! Event streaming system for Trinity agents.
//! Brain Region: Reticular Formation (Broadcast Alerting)
//!
//! Features:
//! - Thread-safe event publishing and polling
//! - In-memory circular buffer (max 10,000 events)
//! - Timestamp-based filtering
//! - Statistics tracking

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

/// Stored event with owned memory
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

/// Global event bus singleton
var global_event_bus: ?*EventBus = null;
var global_mutex = std.Thread.Mutex{};

/// Get or create global event bus
pub fn getGlobal(allocator: std.mem.Allocator) !*EventBus {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_event_bus) |existing| {
        return existing;
    }

    const bus = try allocator.create(EventBus);
    bus.* = EventBus.init(allocator);
    global_event_bus = bus;
    return bus;
}

pub const EventBus = struct {
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,
    events: std.ArrayList(StoredEvent),
    stats: struct {
        published: u64,
        polled: u64,
    },

    pub fn init(allocator: std.mem.Allocator) EventBus {
        return EventBus{
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
            .events = std.ArrayList(StoredEvent).initCapacity(allocator, 256) catch |err| {
                std.log.err("Failed to allocate EventBus: {}", .{err});
                @panic("EventBus init failed");
            },
            .stats = .{ .published = 0, .polled = 0 },
        };
    }

    pub fn deinit(self: *EventBus) void {
        for (self.events.items) |ev| {
            ev.deinit(self.allocator);
        }
        self.events.deinit(self.allocator);
    }

    /// Publish an event to the bus
    pub fn publish(self: *EventBus, event_type: AgentEventType, data: EventData) !void {
        const timestamp = std.time.milliTimestamp();

        // Extract data based on event type
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

        // Create stored event
        const stored = StoredEvent{
            .event_type = event_type,
            .timestamp = timestamp,
            .task_id = task_id,
            .agent_id = agent_id,
            .aux_string = aux_string,
            .duration_ms = duration_ms,
        };

        self.mutex.lock();
        defer self.mutex.unlock();

        // Add to buffer, trim if necessary
        try self.events.append(stored);
        if (self.events.items.len > MAX_EVENTS) {
            // Remove oldest event
            const removed = self.events.orderedRemove(0);
            removed.deinit(self.allocator);
        }

        self.stats.published += 1;
    }

    /// Poll events since given timestamp
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

        self.stats.polled += 1;
        return results.toOwnedSlice(allocator);
    }

    /// Get current statistics
    pub fn getStats(self: *EventBus) struct { published: u64, polled: u64, buffered: usize } {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .published = self.stats.published,
            .polled = self.stats.polled,
            .buffered = self.events.items.len,
        };
    }

    /// Trim oldest events, keeping only the most recent `count`
    pub fn trim(self: *EventBus, count: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.events.items.len > count) {
            const removed = self.events.orderedRemove(0);
            removed.deinit(self.allocator);
        }
    }

    /// Clear all events
    pub fn clear(self: *EventBus) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.events.items) |ev| {
            ev.deinit(self.allocator);
        }
        self.events.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "EventBus publish and poll" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish an event
    const event_data = EventData{
        .task_claimed = .{
            .task_id = "task-123",
            .agent_id = "agent-001",
        },
    };
    try bus.publish(.task_claimed, event_data);

    // Poll should return the event
    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_claimed, events[0].event_type);
}

test "EventBus statistics" {
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
    _ = try bus.poll(0, allocator, 100);
    allocator.free(try bus.poll(0, allocator, 100));

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.published);
    try std.testing.expectEqual(@as(u64, 2), stats.polled);
}

test "EventBus trim and clear" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Add multiple events
    for (0..10) |i| {
        const event_data = EventData{
            .task_claimed = .{
                .task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i}),
                .agent_id = "agent-001",
            },
        };
        try bus.publish(.task_claimed, event_data);
    }

    var stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 10), stats.buffered);

    // Trim to 5
    bus.trim(5);
    stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 5), stats.buffered);

    // Clear all
    bus.clear();
    stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.buffered);
}
