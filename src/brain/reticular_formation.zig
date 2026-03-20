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
var global_allocator: ?std.mem.Allocator = null;
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
    global_allocator = allocator;
    return bus;
}

/// Reset global event bus (for testing)
pub fn resetGlobal(allocator: std.mem.Allocator) void {
    _ = allocator; // Use stored allocator instead
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_event_bus) |bus| {
        bus.deinit();
        if (global_allocator) |alloc| {
            alloc.destroy(bus);
        }
        global_event_bus = null;
        global_allocator = null;
    }
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
        try self.events.append(self.allocator, stored);
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

test "EventBus all event types" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Test task_claimed
    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    // Test task_completed
    try bus.publish(.task_completed, .{
        .task_completed = .{
            .task_id = "task-2",
            .agent_id = "agent-2",
            .duration_ms = 5000,
        },
    });

    // Test task_failed
    try bus.publish(.task_failed, .{
        .task_failed = .{
            .task_id = "task-3",
            .agent_id = "agent-3",
            .err_msg = "Something went wrong",
        },
    });

    // Test task_abandoned
    try bus.publish(.task_abandoned, .{
        .task_abandoned = .{
            .task_id = "task-4",
            .agent_id = "agent-4",
            .reason = "Timeout",
        },
    });

    // Test agent_idle
    try bus.publish(.agent_idle, .{
        .agent_idle = .{
            .agent_id = "agent-5",
            .idle_ms = 30000,
        },
    });

    // Test agent_spawned
    try bus.publish(.agent_spawned, .{
        .agent_spawned = .{
            .agent_id = "agent-6",
        },
    });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 6), stats.published);
    try std.testing.expectEqual(@as(usize, 6), stats.buffered);
}

test "EventBus poll with timestamp filter" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish first event
    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    // Get current time
    const mid_time = std.time.milliTimestamp();

    // Publish second event
    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-2",
            .agent_id = "agent-2",
        },
    });

    // Poll since mid_time should only return second event
    const events = try bus.poll(mid_time, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(@as(usize, 6), events[0].data.task_claimed.task_id.len); // "task-2"
}

test "EventBus poll with max_events limit" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish 5 events
    for (0..5) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    // Poll with max_events=2
    const events = try bus.poll(0, allocator, 2);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 2), events.len);
}

test "EventBus poll returns empty when no events" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "EventBus auto-trim at MAX_EVENTS" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish more than MAX_EVENTS events
    for (0..10050) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    const stats = bus.getStats();
    try std.testing.expect(stats.buffered <= 10000); // Should be trimmed
}

test "EventBus multiple polls increment counter" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    _ = try bus.poll(0, allocator, 100);
    allocator.free(try bus.poll(0, allocator, 100));
    allocator.free(try bus.poll(0, allocator, 100));

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.polled);
}

test "EventBus task_failed includes error message" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const err_msg = "Connection timeout after 30 seconds";
    try bus.publish(.task_failed, .{
        .task_failed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
            .err_msg = err_msg,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_failed, events[0].event_type);
    try std.testing.expectEqualStrings(err_msg, events[0].data.task_failed.err_msg);
}

test "EventBus task_abandoned includes reason" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const reason = "Agent crash detected";
    try bus.publish(.task_abandoned, .{
        .task_abandoned = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
            .reason = reason,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_abandoned, events[0].event_type);
    try std.testing.expectEqualStrings(reason, events[0].data.task_abandoned.reason);
}

test "EventBus task_completed includes duration" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const duration_ms: u64 = 12345;
    try bus.publish(.task_completed, .{
        .task_completed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
            .duration_ms = duration_ms,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_completed, events[0].event_type);
    try std.testing.expectEqual(duration_ms, events[0].data.task_completed.duration_ms);
}

test "EventBus agent_idle includes idle time" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const idle_ms: u64 = 60000;
    try bus.publish(.agent_idle, .{
        .agent_idle = .{
            .agent_id = "agent-1",
            .idle_ms = idle_ms,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.agent_idle, events[0].event_type);
    try std.testing.expectEqual(idle_ms, events[0].data.agent_idle.idle_ms);
}

test "EventBus trim to zero" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    try std.testing.expectEqual(@as(usize, 1), bus.getStats().buffered);

    bus.trim(0);
    try std.testing.expectEqual(@as(usize, 0), bus.getStats().buffered);
}

test "EventBus trim more than available" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    // Trim to more events than exist
    bus.trim(100);
    try std.testing.expectEqual(@as(usize, 1), bus.getStats().buffered);
}
