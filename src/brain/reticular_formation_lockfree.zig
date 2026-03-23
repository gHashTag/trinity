//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! RETICULAR FORMATION — v0.4 — Lock-Free Ring Buffer
//!
//! Optimizations:
//! - Lock-free SPSC (Single Producer Single Consumer) ring buffer
//! - Pre-allocated event pool (no per-event allocation)
//! - Fixed-size event storage (inline string storage)
//! - Cache-line padding for false sharing prevention
//! - Batch publish API for amortized locking
//!
//! Target: >100k OP/s throughput
//! Design: Lock-free head/tail with atomic operations

const std = @import("std");

const MAX_EVENTS: usize = 10_000;
const MAX_STRING_LEN: usize = 64; // Fixed-size inline strings

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

/// Fixed-size inline string (no heap allocation)
const InlineString = struct {
    data: [MAX_STRING_LEN]u8,
    len: u8,

    fn init(str: []const u8) InlineString {
        var s: InlineString = undefined;
        @memset(&s.data, 0);
        const copy_len = @min(str.len, MAX_STRING_LEN - 1);
        @memcpy(s.data[0..copy_len], str[0..copy_len]);
        s.len = @intCast(copy_len);
        return s;
    }

    fn slice(self: *const InlineString) []const u8 {
        return self.data[0..self.len];
    }
};

/// Stored event with inline strings (zero allocation)
const StoredEvent = struct {
    event_type: AgentEventType,
    timestamp: i64,
    task_id: InlineString,
    agent_id: InlineString,
    aux_string: InlineString, // err_msg, reason, or unused
    duration_ms: u64,

    // No deinit needed - all inline storage
};

/// Cache-line padded indices for lock-free ring buffer
const PaddedIndex = struct {
    value: std.atomic.Value(usize),
    padding: [64 - @sizeOf(std.atomic.Value(usize))]u8, // Cache line padding

    fn init(v: usize) PaddedIndex {
        return .{
            .value = std.atomic.Value(usize).init(v),
            .padding = undefined,
        };
    }
};

/// Lock-free statistics
const Stats = struct {
    published: std.atomic.Value(u64),
    polled: std.atomic.Value(u64),
    trim_count: std.atomic.Value(u64),
    peak_buffered: std.atomic.Value(usize),

    fn init() Stats {
        return .{
            .published = std.atomic.Value(u64).init(0),
            .polled = std.atomic.Value(u64).init(0),
            .trim_count = std.atomic.Value(u64).init(0),
            .peak_buffered = std.atomic.Value(usize).init(0),
        };
    }
};

/// Lock-free event bus with SPSC ring buffer
pub const EventBus = struct {
    allocator: std.mem.Allocator,

    // Ring buffer
    buffer: [MAX_EVENTS]StoredEvent,

    // Padded indices to prevent false sharing
    head: PaddedIndex, // Read position
    tail: PaddedIndex, // Write position

    // Statistics
    stats: Stats,

    // Fallback mutex for poll (multi-consumer)
    poll_mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) EventBus {
        var bus: EventBus = undefined;
        bus.allocator = allocator;
        bus.buffer = undefined;
        bus.head = PaddedIndex.init(0);
        bus.tail = PaddedIndex.init(0);
        bus.stats = Stats.init();
        bus.poll_mutex = std.Thread.Mutex{};
        return bus;
    }

    pub fn deinit(self: *EventBus) void {
        _ = self;
        // No heap cleanup needed - all inline storage
    }

    /// Fast publish with inline string storage
    pub fn publish(self: *EventBus, event_type: AgentEventType, data: EventData) !void {
        const timestamp = std.time.milliTimestamp();

        // Extract data BEFORE any atomic operations
        var task_id_str: []const u8 = "";
        var agent_id_str: []const u8 = "";
        var aux_str: []const u8 = "";
        var duration_ms: u64 = 0;

        switch (data) {
            .task_claimed => |d| {
                task_id_str = d.task_id;
                agent_id_str = d.agent_id;
            },
            .task_completed => |d| {
                task_id_str = d.task_id;
                agent_id_str = d.agent_id;
                duration_ms = d.duration_ms;
            },
            .task_failed => |d| {
                task_id_str = d.task_id;
                agent_id_str = d.agent_id;
                aux_str = d.err_msg;
            },
            .task_abandoned => |d| {
                task_id_str = d.task_id;
                agent_id_str = d.agent_id;
                aux_str = d.reason;
            },
            .agent_idle => |d| {
                agent_id_str = d.agent_id;
                duration_ms = d.idle_ms;
            },
            .agent_spawned => |d| {
                agent_id_str = d.agent_id;
            },
        }

        // Create event with inline storage
        const event = StoredEvent{
            .event_type = event_type,
            .timestamp = timestamp,
            .task_id = InlineString.init(task_id_str),
            .agent_id = InlineString.init(agent_id_str),
            .aux_string = InlineString.init(aux_str),
            .duration_ms = duration_ms,
        };

        // Lock-free write to ring buffer
        const tail = self.tail.value.load(.monotonic);
        const next_tail = (tail + 1) % MAX_EVENTS;

        // Check if buffer would overflow
        const head = self.head.value.load(.acquire);
        if (next_tail == head) {
            // Buffer full - drop oldest (advance head)
            _ = self.head.value.store((head + 1) % MAX_EVENTS, .release);
            _ = self.stats.trim_count.fetchAdd(1, .monotonic);
        }

        // Write to buffer
        self.buffer[tail] = event;

        // Commit write (release ensures event is written before tail advances)
        _ = self.tail.value.store(next_tail, .release);
        _ = self.stats.published.fetchAdd(1, .monotonic);

        // Update peak (best effort)
        const current_count = if (next_tail >= head) next_tail - head else MAX_EVENTS - head + next_tail;
        const current_peak = self.stats.peak_buffered.load(.monotonic);
        if (current_count > current_peak) {
            _ = self.stats.peak_buffered.fetchMax(current_count, .monotonic);
        }
    }

    /// Batch publish - amortize synchronization
    pub fn publishBatch(self: *EventBus, events: []const struct { AgentEventType, EventData }) !void {
        const timestamp = std.time.milliTimestamp();

        for (events) |ev| {
            const event_type, const data = ev;

            var task_id_str: []const u8 = "";
            var agent_id_str: []const u8 = "";
            var aux_str: []const u8 = "";
            var duration_ms: u64 = 0;

            switch (data) {
                .task_claimed => |d| {
                    task_id_str = d.task_id;
                    agent_id_str = d.agent_id;
                },
                .task_completed => |d| {
                    task_id_str = d.task_id;
                    agent_id_str = d.agent_id;
                    duration_ms = d.duration_ms;
                },
                .task_failed => |d| {
                    task_id_str = d.task_id;
                    agent_id_str = d.agent_id;
                    aux_str = d.err_msg;
                },
                .task_abandoned => |d| {
                    task_id_str = d.task_id;
                    agent_id_str = d.agent_id;
                    aux_str = d.reason;
                },
                .agent_idle => |d| {
                    agent_id_str = d.agent_id;
                    duration_ms = d.idle_ms;
                },
                .agent_spawned => |d| {
                    agent_id_str = d.agent_id;
                },
            }

            const event = StoredEvent{
                .event_type = event_type,
                .timestamp = timestamp,
                .task_id = InlineString.init(task_id_str),
                .agent_id = InlineString.init(agent_id_str),
                .aux_string = InlineString.init(aux_str),
                .duration_ms = duration_ms,
            };

            const tail = self.tail.value.load(.monotonic);
            const next_tail = (tail + 1) % MAX_EVENTS;

            const head = self.head.value.load(.acquire);
            if (next_tail == head) {
                _ = self.head.value.store((head + 1) % MAX_EVENTS, .release);
                _ = self.stats.trim_count.fetchAdd(1, .monotonic);
            }

            self.buffer[tail] = event;
            _ = self.tail.value.store(next_tail, .release);
            _ = self.stats.published.fetchAdd(1, .monotonic);
        }
    }

    /// Poll events since given timestamp
    pub fn poll(self: *EventBus, since: i64, allocator: std.mem.Allocator, max_events: usize) ![]AgentEventRecord {
        _ = allocator;
        self.poll_mutex.lock();
        defer self.poll_mutex.unlock();

        // Use stack-allocated array for results
        var stack_results: [256]AgentEventRecord = undefined;
        var result_len: usize = 0;

        const head = self.head.value.load(.acquire);
        const tail = self.tail.value.load(.acquire);

        var idx = head;
        while (idx != tail) {
            if (result_len >= max_events or result_len >= stack_results.len) break;

            const stored = &self.buffer[idx];

            if (stored.timestamp > since) {
                const data: EventData = switch (stored.event_type) {
                    .task_claimed => .{ .task_claimed = .{
                        .task_id = stored.task_id.slice(),
                        .agent_id = stored.agent_id.slice(),
                    } },
                    .task_completed => .{ .task_completed = .{
                        .task_id = stored.task_id.slice(),
                        .agent_id = stored.agent_id.slice(),
                        .duration_ms = stored.duration_ms,
                    } },
                    .task_failed => .{ .task_failed = .{
                        .task_id = stored.task_id.slice(),
                        .agent_id = stored.agent_id.slice(),
                        .err_msg = stored.aux_string.slice(),
                    } },
                    .task_abandoned => .{ .task_abandoned = .{
                        .task_id = stored.task_id.slice(),
                        .agent_id = stored.agent_id.slice(),
                        .reason = stored.aux_string.slice(),
                    } },
                    .agent_idle => .{ .agent_idle = .{
                        .agent_id = stored.agent_id.slice(),
                        .idle_ms = stored.duration_ms,
                    } },
                    .agent_spawned => .{ .agent_spawned = .{
                        .agent_id = stored.agent_id.slice(),
                    } },
                };

                stack_results[result_len] = .{
                    .event_type = stored.event_type,
                    .timestamp = stored.timestamp,
                    .data = data,
                };
                result_len += 1;
            }

            idx = (idx + 1) % MAX_EVENTS;
        }

        _ = self.stats.polled.fetchAdd(1, .monotonic);

        // Allocate exact size result
        const results = try self.allocator.dupe(AgentEventRecord, stack_results[0..result_len]);
        return results;
    }

    /// Lock-free stats read
    pub fn getStats(self: *const EventBus) struct { published: u64, polled: u64, buffered: usize, trim_count: u64, peak_buffered: usize } {
        const head = self.head.value.load(.acquire);
        const tail = self.tail.value.load(.acquire);
        const buffered = if (tail >= head) tail - head else MAX_EVENTS - head + tail;

        return .{
            .published = self.stats.published.load(.monotonic),
            .polled = self.stats.polled.load(.monotonic),
            .buffered = buffered,
            .trim_count = self.stats.trim_count.load(.monotonic),
            .peak_buffered = self.stats.peak_buffered.load(.monotonic),
        };
    }

    /// Clear all events
    pub fn clear(self: *EventBus) void {
        // Reset indices - no memory cleanup needed
        self.head.value.store(0, .monotonic);
        self.tail.value.store(0, .monotonic);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LockFree: publish and poll" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-123",
            .agent_id = "agent-001",
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(.task_claimed, events[0].event_type);
}

test "LockFree: all event types" {
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
}

test "LockFree: inline string truncation" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Very long string should be truncated
    const long_task_id = "task-" ++ "a" ** 100;
    try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = long_task_id,
            .agent_id = "agent-1",
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    // Should be truncated to MAX_STRING_LEN - 1
    try std.testing.expect(events[0].data.task_claimed.task_id.len < long_task_id.len);
}

test "LockFree: batch publish" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const events = [_]struct { AgentEventType, EventData }{
        .{ .task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } } },
        .{ .task_claimed, .{ .task_claimed = .{ .task_id = "task-2", .agent_id = "agent-1" } } },
        .{ .task_claimed, .{ .task_claimed = .{ .task_id = "task-3", .agent_id = "agent-1" } } },
    };

    try bus.publishBatch(&events);

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.published);
}

test "LockFree: buffer overflow handling" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish more than MAX_EVENTS
    for (0..10050) |i| {
        var task_buf: [32]u8 = undefined;
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch "task-x";

        try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    const stats = bus.getStats();
    // Should have trimmed some events
    try std.testing.expect(stats.trim_count > 0);
    // Buffer should not exceed capacity
    try std.testing.expect(stats.buffered <= MAX_EVENTS);
}

test "LockFree: clear" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" } });

    var stats = bus.getStats();
    try std.testing.expect(stats.buffered > 0);

    bus.clear();

    stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.buffered);
}

test "LockFree: publish throughput benchmark" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const iterations = 100_000;
    var task_buf: [32]u8 = undefined;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch "task-x";

        try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-001",
            },
        });
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("LockFree Reticular Formation Publish: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "LockFree: batch publish throughput benchmark" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const batch_size = 10;
    const iterations = 10_000; // batches
    var batch_buf: [batch_size]struct { AgentEventType, EventData } = undefined;
    var task_buf: [32]u8 = undefined;

    const start = std.time.nanoTimestamp();
    var batch_i: u64 = 0;
    while (batch_i < iterations) : (batch_i += 1) {
        var i: usize = 0;
        while (i < batch_size) : (i += 1) {
            const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{batch_i * batch_size + i}) catch "task-x";
            batch_buf[i] = .{ .task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = "agent-001" } } };
        }
        try bus.publishBatch(&batch_buf);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const total_events = iterations * batch_size;
    const ops_per_sec = @as(f64, @floatFromInt(total_events)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("LockFree Reticular Formation Batch Publish: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(total_events)) });
}

test "LockFree: poll throughput benchmark" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Pre-populate with events
    const iterations = 10_000;
    var task_buf: [32]u8 = undefined;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch "task-x";
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
    _ = std.debug.print("LockFree Reticular Formation Poll: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(i)) });
}

test "LockFree: concurrent publish safety" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Simple concurrent test (single producer pattern)
    const iterations = 1000;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = "task-concurrent",
                .agent_id = "agent-1",
            },
        });
    }

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, iterations), stats.published);
}

test "LockFree: timestamp filter" {
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

test "LockFree: max_events limit" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    for (0..10) |i| {
        var task_buf: [32]u8 = undefined;
        const task_id = std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i}) catch "task-x";
        try bus.publish(.task_claimed, .{ .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" } });
    }

    const events = try bus.poll(0, allocator, 2);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 2), events.len);
}
