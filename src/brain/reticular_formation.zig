//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! RETICULAR FORMATION — v0.4 — Broadcast Alerting (OPTIMIZED)
//!
//! Event streaming system for Trinity agents.
//! Brain Region: Reticular Formation (Broadcast Alerting)
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//!
//! Biological Analogy:
//! In vertebrate brains, the reticular formation is a diffuse network of neurons
//! that regulates arousal, consciousness, and attention. It filters sensory input
//! and broadcasts alerts to higher brain regions. This module provides similar
//! functionality: filtering events and broadcasting them to agent components.
//!
//! Features:
//! - Thread-safe event publishing and polling
//! - In-memory circular buffer (max 10,000 events)
//! - Timestamp-based filtering
//! - Lock-free atomic statistics tracking
//! - Batch operations for high-throughput scenarios
//! - O(1) trimming via ring buffer head pointer
//!
//! Thread Safety:
//! - Mutex-protected ring buffer (MPSC: multi-producer, single-consumer typical use)
//! - Lock-free atomic counters for stats (published, polled, trim_count, peak_buffered)
//! - Safe for concurrent publish from multiple threads
//! - Poll is thread-safe via mutex

const std = @import("std");

/// Maximum number of events that can be buffered in memory.
/// When exceeded, oldest events are auto-trimmed (FIFO eviction).
const MAX_EVENTS: usize = 10_000;

/// Types of agent events that can be published.
/// Each event type carries relevant metadata for tracking and analysis.
pub const AgentEventType = enum {
    task_claimed,
    task_completed,
    task_failed,
    task_abandoned,
    agent_idle,
    agent_spawned,
};

/// Union of all possible event data structures.
/// The active variant is determined by AgentEventType.
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

/// Event record returned to consumers via poll().
/// Contains type, timestamp, and event-specific data.
/// Slices point to internally-owned memory (valid until next poll or bus deinit).
pub const AgentEventRecord = struct {
    event_type: AgentEventType,
    timestamp: i64,
    data: EventData,
};

/// Stored event with owned memory in the ring buffer.
/// Strings are allocated copies of input data to ensure ownership.
const StoredEvent = struct {
    event_type: AgentEventType,
    timestamp: i64,

    // Owned strings (copied from input)
    task_id: []const u8,
    agent_id: []const u8,
    aux_string: []const u8, // err_msg, reason, or unused
    duration_ms: u64,

    /// Free all owned string allocations.
    /// Empty strings (length 0) are skipped to avoid freeing string literals.
    fn deinit(self: StoredEvent, allocator: std.mem.Allocator) void {
        if (self.task_id.len > 0) allocator.free(self.task_id);
        if (self.agent_id.len > 0) allocator.free(self.agent_id);
        if (self.aux_string.len > 0) allocator.free(self.aux_string);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL SINGLETON
// ═══════════════════════════════════════════════════════════════════════════════

/// Global event bus singleton for cross-module access.
/// Protected by mutex to ensure thread-safe initialization.
var global_event_bus: ?*EventBus = null;
var global_allocator: ?std.mem.Allocator = null;
var global_mutex = std.Thread.Mutex{};

/// Get or create the global event bus singleton.
/// Thread-safe: uses double-checked locking pattern.
/// Returns pointer to the singleton EventBus instance.
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

/// Reset the global event bus singleton (primarily for testing).
/// Frees all buffered events and destroys the singleton.
pub fn resetGlobal(allocator: std.mem.Allocator) void {
    _ = allocator; // Use stored allocator instead
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_event_bus) |bus| {
        bus.deinit();
        // IMPORTANT: Use global_allocator (saved from getGlobal) for destroy()
        // NOT bus.allocator, because in tests these may be different instances
        if (global_allocator) |alloc| {
            alloc.destroy(bus);
        }
        global_event_bus = null;
        global_allocator = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT BUS
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread-safe ring buffer for event streaming.
///
/// Implementation Details:
/// - Fixed-size circular buffer with head/tail indices
/// - head_idx: points to oldest event (for eviction/iteration)
/// - tail_idx: points to next write position
/// - count: current number of valid events (0 to MAX_EVENTS)
///
/// Lock Strategy:
/// - Mutex protects buffer state (head, tail, count, buffer contents)
/// - Atomic operations for statistics (published, polled, trim_count, peak_buffered)
/// - Stats can be read without holding mutex (for monitoring dashboards)
///
/// Memory Management:
/// - Event strings are allocated on publish and freed on eviction/deinit
/// - Auto-trim when buffer full: oldest event freed to make room
pub const EventBus = struct {
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,
    /// Ring buffer: fixed size array with head/tail indices
    buffer: [MAX_EVENTS]StoredEvent,
    /// Index of oldest event (next to be evicted when trimming)
    head_idx: usize,
    /// Index where next event will be written
    tail_idx: usize,
    /// Number of events currently stored (0 to MAX_EVENTS)
    count: usize,
    /// Lock-free atomic stats for high-performance monitoring
    stats: struct {
        /// Total events published (incremented atomically)
        published: std.atomic.Value(u64),
        /// Total poll operations performed (incremented atomically)
        polled: std.atomic.Value(u64),
        /// Number of times auto-trim or manual trim occurred
        trim_count: std.atomic.Value(u64),
        /// Peak number of events buffered (high-water mark)
        peak_buffered: std.atomic.Value(usize),
    },

    /// Initialize a new EventBus instance.
    /// Buffer starts empty; all stats at zero.
    pub fn init(allocator: std.mem.Allocator) EventBus {
        return EventBus{
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
            .buffer = undefined,
            .head_idx = 0,
            .tail_idx = 0,
            .count = 0,
            .stats = .{
                .published = std.atomic.Value(u64).init(0),
                .polled = std.atomic.Value(u64).init(0),
                .trim_count = std.atomic.Value(u64).init(0),
                .peak_buffered = std.atomic.Value(usize).init(0),
            },
        };
    }

    /// Free all owned memory (event strings).
    /// Does NOT free the EventBus struct itself (use allocator.destroy()).
    pub fn deinit(self: *EventBus) void {
        // Free all events in the ring buffer
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const idx = (self.head_idx + i) % MAX_EVENTS;
            self.buffer[idx].deinit(self.allocator);
        }
    }

    /// Publish a single event to the bus.
    ///
    /// Thread-safe: locks mutex for buffer operations.
    /// Auto-trim: evicts oldest event when buffer full.
    /// Strings are duplicated (allocated) to ensure ownership.
    ///
    /// Returns: error.OutOfMemory if string allocation fails.
    ///
    /// # Performance v2.2
    /// - Reduced lock scope (only for buffer ops)
    /// - Early error propagation on alloc failure
    pub fn publish(self: *EventBus, event_type: AgentEventType, data: EventData) !void {
        const timestamp = std.time.milliTimestamp();

        // Extract and duplicate strings based on event type
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

        // Build stored event outside lock
        const stored = StoredEvent{
            .event_type = event_type,
            .timestamp = timestamp,
            .task_id = task_id,
            .agent_id = agent_id,
            .aux_string = aux_string,
            .duration_ms = duration_ms,
        };

        // Lock only for buffer operations (reduced scope)
        self.mutex.lock();

        // Auto-trim: evict oldest event if buffer full
        if (self.count >= MAX_EVENTS) {
            self.buffer[self.head_idx].deinit(self.allocator);
            self.head_idx = (self.head_idx + 1) % MAX_EVENTS;
            _ = self.stats.trim_count.fetchAdd(1, .monotonic);
        } else {
            // Track peak buffer size only when growing
            const new_count = self.count + 1;
            const current_peak = self.stats.peak_buffered.load(.monotonic);
            if (new_count > current_peak) {
                _ = self.stats.peak_buffered.fetchMax(new_count, .monotonic);
            }
        }

        // Write new event at tail position
        self.buffer[self.tail_idx] = stored;
        self.tail_idx = (self.tail_idx + 1) % MAX_EVENTS;
        if (self.count < MAX_EVENTS) {
            self.count += 1;
        }

        self.mutex.unlock();
        _ = self.stats.published.fetchAdd(1, .monotonic);
    }

    /// Batch event descriptor for publishBatch.
    pub const BatchEvent = struct {
        event_type: AgentEventType,
        data: EventData,
    };

    /// Publish multiple events in a single operation (optimized).
    ///
    /// Reduces mutex contention by acquiring lock once for all events.
    /// Useful for batched event collection or replay scenarios.
    ///
    /// Returns: error.OutOfMemory if any string allocation fails.
    pub fn publishBatch(self: *EventBus, events: []const BatchEvent) !void {
        if (events.len == 0) return;

        // Pre-allocate all events' strings outside lock
        var batch = try self.allocator.alloc(StoredEvent, events.len);
        errdefer {
            // Free any allocations that succeeded
            for (batch) |*event| {
                if (event.task_id.len > 0) self.allocator.free(event.task_id);
                if (event.agent_id.len > 0) self.allocator.free(event.agent_id);
                if (event.aux_string.len > 0) self.allocator.free(event.aux_string);
            }
            self.allocator.free(batch);
        }

        const timestamp = std.time.milliTimestamp();

        // Prepare all events outside lock
        for (events, 0..) |evt, i| {
            var task_id: []const u8 = "";
            var agent_id: []const u8 = "";
            var aux_string: []const u8 = "";
            var duration_ms: u64 = 0;

            switch (evt.data) {
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
                    duration_ms = d.idle_ms;
                },
                .agent_spawned => |d| {
                    agent_id = try self.allocator.dupe(u8, d.agent_id);
                },
            }

            batch[i] = StoredEvent{
                .event_type = evt.event_type,
                .timestamp = timestamp,
                .task_id = task_id,
                .agent_id = agent_id,
                .aux_string = aux_string,
                .duration_ms = duration_ms,
            };
        }

        // Single lock for all writes
        self.mutex.lock();
        defer self.mutex.unlock();

        var trim_count_local: usize = 0;

        for (batch) |stored| {
            // Auto-trim if buffer full
            if (self.count >= MAX_EVENTS) {
                self.buffer[self.head_idx].deinit(self.allocator);
                self.head_idx = (self.head_idx + 1) % MAX_EVENTS;
                trim_count_local += 1;
            } else {
                const new_count = self.count + 1;
                const current_peak = self.stats.peak_buffered.load(.monotonic);
                if (new_count > current_peak) {
                    _ = self.stats.peak_buffered.fetchMax(new_count, .monotonic);
                }
            }

            self.buffer[self.tail_idx] = stored;
            self.tail_idx = (self.tail_idx + 1) % MAX_EVENTS;
            if (self.count < MAX_EVENTS) {
                self.count += 1;
            }
        }

        // Free the temporary batch array (strings now owned by ring buffer)
        self.allocator.free(batch);

        // Update stats
        _ = self.stats.published.fetchAdd(@intCast(events.len), .monotonic);
        if (trim_count_local > 0) {
            _ = self.stats.trim_count.fetchAdd(@intCast(trim_count_local), .monotonic);
        }
    }

    /// Poll events since given timestamp.
    ///
    /// Returns events with timestamp > `since` in chronological order.
    /// Limited by `max_events` to prevent excessive memory allocation.
    ///
    /// Parameters:
    /// - since: Only return events after this timestamp (ms since epoch)
    /// - allocator: Used for result slice allocation
    /// - max_events: Maximum number of events to return (0 = no limit)
    ///
    /// Returns: Caller-owned slice of AgentEventRecord.
    ///   Slices point to internally-owned strings (valid until next poll/deinit).
    ///
    /// Thread-safe: locks mutex for buffer iteration.
    ///
    /// # Performance v2.2
    /// - Pre-count matching events to allocate exact capacity
    /// - Reduced switch statement overhead
    pub fn poll(self: *EventBus, since: i64, allocator: std.mem.Allocator, max_events: usize) ![]AgentEventRecord {
        self.mutex.lock();

        // First pass: count matching events for exact capacity
        const limit = if (max_events == 0) self.count else @min(self.count, max_events);
        var match_count: usize = 0;
        var i: usize = 0;
        while (i < limit) : (i += 1) {
            const idx = (self.head_idx + i) % MAX_EVENTS;
            if (self.buffer[idx].timestamp > since) {
                match_count += 1;
                if (max_events > 0 and match_count >= max_events) break;
            }
        }

        // Allocate with exact capacity
        var results = try std.ArrayList(AgentEventRecord).initCapacity(allocator, match_count);
        errdefer results.deinit(allocator);

        // Second pass: collect events
        i = 0;
        while (i < limit) : (i += 1) {
            if (max_events > 0 and results.items.len >= max_events) break;

            const idx = (self.head_idx + i) % MAX_EVENTS;
            const stored = &self.buffer[idx];

            if (stored.timestamp > since) {
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

                results.appendAssumeCapacity(AgentEventRecord{
                    .event_type = stored.event_type,
                    .timestamp = stored.timestamp,
                    .data = data,
                });
            }
        }

        self.mutex.unlock();
        _ = self.stats.polled.fetchAdd(1, .monotonic);
        return results.toOwnedSlice(allocator);
    }

    /// Get current statistics.
    ///
    /// Returns a snapshot of event bus metrics:
    /// - published: Total events published since init
    /// - polled: Total poll operations performed
    /// - buffered: Current number of events in buffer
    /// - trim_count: Total trim operations (auto + manual)
    /// - peak_buffered: High-water mark of buffered events
    ///
    /// Thread-safety: atomic loads for stats, mutex for count.
    pub fn getStats(self: *EventBus) struct {
        published: u64,
        polled: u64,
        buffered: usize,
        trim_count: u64,
        peak_buffered: usize,
    } {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .published = self.stats.published.load(.monotonic),
            .polled = self.stats.polled.load(.monotonic),
            .buffered = self.count,
            .trim_count = self.stats.trim_count.load(.monotonic),
            .peak_buffered = self.stats.peak_buffered.load(.monotonic),
        };
    }

    /// Trim oldest events, keeping only the most recent `target_count`.
    ///
    /// O(1) operation: simply advances the head pointer.
    /// Freed events have their strings deallocated.
    ///
    /// Thread-safe: locks mutex.
    pub fn trim(self: *EventBus, target_count: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Keep at most target_count (or all if we have fewer)
        const to_keep = @min(target_count, self.count);
        const to_remove = self.count - to_keep;

        // Free evicted events
        var i: usize = 0;
        while (i < to_remove) : (i += 1) {
            const idx = (self.head_idx + i) % MAX_EVENTS;
            self.buffer[idx].deinit(self.allocator);
        }

        // Advance head pointer past removed events
        self.head_idx = (self.head_idx + to_remove) % MAX_EVENTS;
        self.count = to_keep;

        if (to_remove > 0) {
            _ = self.stats.trim_count.fetchAdd(1, .monotonic);
        }
    }

    /// Clear all events from the buffer.
    ///
    /// Deallocates all string allocations and resets indices to zero.
    /// Buffer is empty after this call.
    ///
    /// Thread-safe: locks mutex.
    pub fn clear(self: *EventBus) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Free all events
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const idx = (self.head_idx + i) % MAX_EVENTS;
            self.buffer[idx].deinit(self.allocator);
        }

        self.head_idx = 0;
        self.tail_idx = 0;
        self.count = 0;
    }

    /// Get current buffer capacity utilization as a percentage.
    ///
    /// Returns 0.0 to 100.0 representing how full the buffer is.
    /// Useful for monitoring and auto-scaling decisions.
    pub fn utilization(self: *EventBus) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (MAX_EVENTS == 0) return 0.0;
        return @as(f64, @floatFromInt(self.count)) / @as(f64, @floatFromInt(MAX_EVENTS)) * 100.0;
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
    allocator.free(try bus.poll(0, allocator, 100));
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
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        const event_data = EventData{
            .task_claimed = .{
                .task_id = task_id,
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

    // Sleep to ensure timestamp advances (milliseconds may not be enough for time resolution)
    std.Thread.sleep(10 * std.time.ns_per_ms);

    // Get current time before second event
    const mid_time = std.time.milliTimestamp();

    // Small sleep to ensure next event has strictly greater timestamp
    std.Thread.sleep(5 * std.time.ns_per_ms);

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
        defer allocator.free(task_id);
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
        defer allocator.free(task_id);
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

    allocator.free(try bus.poll(0, allocator, 100));
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

test "EventBus agent_idle empty task_id handling" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // agent_idle and agent_spawned have empty task_id (not allocated)
    // This tests that StoredEvent.deinit doesn't crash on empty strings
    try bus.publish(.agent_idle, .{
        .agent_idle = .{
            .agent_id = "agent-1",
            .idle_ms = 30000,
        },
    });

    try bus.publish(.agent_spawned, .{
        .agent_spawned = .{
            .agent_id = "agent-2",
        },
    });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.buffered);

    // Deinit should handle empty task_id correctly
    bus.clear();
    try std.testing.expectEqual(@as(usize, 0), bus.getStats().buffered);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW TESTS: Edge Cases, Concurrency, Batch Operations, Utilization
// ═══════════════════════════════════════════════════════════════════════════════

test "EventBus batch publish reduces lock contention" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Prepare batch of events
    const events = try allocator.alloc(EventBus.BatchEvent, 100);
    defer allocator.free(events);

    for (events, 0..) |*evt, i| {
        evt.* = .{
            .event_type = .task_claimed,
            .data = .{
                .task_claimed = .{
                    .task_id = "batch-task",
                    .agent_id = "agent-1",
                },
            },
        };
        _ = i;
    }

    // Publish all in one batch operation
    try bus.publishBatch(events);

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 100), stats.published);
    try std.testing.expectEqual(@as(usize, 100), stats.buffered);

    // Verify events are accessible
    const polled = try bus.poll(0, allocator, 1000);
    defer allocator.free(polled);
    try std.testing.expectEqual(@as(usize, 100), polled.len);
}

test "EventBus batch publish handles empty array" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish empty batch should be no-op
    try bus.publishBatch(&[_]EventBus.BatchEvent{});

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.published);
}

test "EventBus batch publish with mixed event types" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const batch = &[_]EventBus.BatchEvent{
        .{ .event_type = .task_claimed, .data = .{
            .task_claimed = .{ .task_id = "task-1", .agent_id = "agent-1" },
        } },
        .{ .event_type = .task_completed, .data = .{
            .task_completed = .{ .task_id = "task-1", .agent_id = "agent-1", .duration_ms = 1000 },
        } },
        .{ .event_type = .task_failed, .data = .{
            .task_failed = .{ .task_id = "task-2", .agent_id = "agent-2", .err_msg = "error" },
        } },
        .{ .event_type = .agent_idle, .data = .{
            .agent_idle = .{ .agent_id = "agent-3", .idle_ms = 5000 },
        } },
    };

    try bus.publishBatch(batch);

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 4), stats.published);

    const polled = try bus.poll(0, allocator, 100);
    defer allocator.free(polled);
    try std.testing.expectEqual(@as(usize, 4), polled.len);
    try std.testing.expectEqual(.task_claimed, polled[0].event_type);
    try std.testing.expectEqual(.task_completed, polled[1].event_type);
    try std.testing.expectEqual(.task_failed, polled[2].event_type);
    try std.testing.expectEqual(.agent_idle, polled[3].event_type);
}

test "EventBus utilization tracking" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Empty bus
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), bus.utilization(), 0.001);

    // 50% full
    for (0..5000) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" },
        });
    }
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), bus.utilization(), 0.01);

    // Clear back to empty
    bus.clear();
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), bus.utilization(), 0.001);
}

test "EventBus peak_buffered tracking" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish some events
    for (0..100) |_| {
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = "task", .agent_id = "agent" },
        });
    }

    const stats1 = bus.getStats();
    try std.testing.expectEqual(@as(usize, 100), stats1.peak_buffered);

    // Trim to 50
    bus.trim(50);

    const stats2 = bus.getStats();
    // Peak should still be 100, not 50
    try std.testing.expectEqual(@as(usize, 100), stats2.peak_buffered);
}

test "EventBus trim increments trim_count" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Add 10 events
    for (0..10) |_| {
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = "task", .agent_id = "agent" },
        });
    }

    var stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.trim_count);

    // Trim to 5
    bus.trim(5);

    stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.trim_count);

    // Trim again
    bus.trim(2);

    stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.trim_count);
}

test "EventBus ring buffer wrap-around correctness" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Fill and exceed MAX_EVENTS to force wrap-around
    for (0..10050) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" },
        });
    }

    const stats = bus.getStats();
    try std.testing.expect(stats.buffered <= 10000);

    // Verify trim_count incremented due to auto-trim
    try std.testing.expect(stats.trim_count >= 50);

    // Verify we can still poll events
    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    // Events should exist after wrap-around
    try std.testing.expect(events.len > 0);
}

test "EventBus concurrent publish is thread-safe" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const num_threads = 4;
    const events_per_thread = 100;

    var threads: [num_threads]std.Thread = undefined;

    // Spawn multiple threads publishing concurrently
    for (&threads, 0..) |*t, tid| {
        t.* = try std.Thread.spawn(.{}, struct {
            fn run(bus_ptr: *EventBus, thread_id: usize) !void {
                for (0..events_per_thread) |i| {
                    const task_id = try std.fmt.allocPrint(std.testing.allocator, "t{d}-task-{d}", .{ thread_id, i });
                    defer std.testing.allocator.free(task_id);
                    try bus_ptr.publish(.task_claimed, .{
                        .task_claimed = .{
                            .task_id = task_id,
                            .agent_id = "agent-1",
                        },
                    });
                }
            }
        }.run, .{ &bus, tid });
    }

    // Join all threads
    for (&threads) |t| {
        t.join();
    }

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, num_threads * events_per_thread), stats.published);
}

test "EventBus poll with zero max_events returns all" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish 10 events
    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" },
        });
    }

    // Poll with max_events=0 should return all events
    const events = try bus.poll(0, allocator, 0);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 10), events.len);
}

test "EventBus chronological order after wrap-around" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Verify chronological order in normal case
    for (0..100) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = task_id, .agent_id = "agent-1" },
        });
    }

    const events = try bus.poll(0, allocator, 1000);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 100), events.len);

    // Verify timestamps are non-decreasing (comparing adjacent pairs)
    var i: usize = 0;
    while (i < events.len - 1) : (i += 1) {
        try std.testing.expect(events[i + 1].timestamp >= events[i].timestamp);
    }
}

test "EventBus stats accuracy under load" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish 500 events
    for (0..500) |_| {
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = "task", .agent_id = "agent" },
        });
    }

    // Poll 10 times
    for (0..10) |_| {
        const events = try bus.poll(0, allocator, 1000);
        allocator.free(events);
    }

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 500), stats.published);
    try std.testing.expectEqual(@as(u64, 10), stats.polled);
    try std.testing.expectEqual(@as(usize, 500), stats.buffered);
}

test "EventBus clear resets indices correctly" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Fill some events
    for (0..10) |_| {
        try bus.publish(.task_claimed, .{
            .task_claimed = .{ .task_id = "task", .agent_id = "agent" },
        });
    }

    bus.clear();

    try std.testing.expectEqual(@as(usize, 0), bus.getStats().buffered);

    // Publish again after clear
    try bus.publish(.task_claimed, .{
        .task_claimed = .{ .task_id = "new-task", .agent_id = "agent" },
    });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.buffered);

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqualStrings("new-task", events[0].data.task_claimed.task_id);
}

test "EventBus global singleton functionality" {
    const allocator = std.testing.allocator;

    // Reset global first
    resetGlobal(allocator);

    // Get global
    const bus = try getGlobal(allocator);
    try bus.publish(.task_claimed, .{
        .task_claimed = .{ .task_id = "global-task", .agent_id = "agent" },
    });

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.published);

    // Get global again should return same instance
    const bus2 = try getGlobal(allocator);
    try std.testing.expectEqual(bus, bus2);

    const stats2 = bus2.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats2.published);

    // Cleanup
    resetGlobal(allocator);
}

// ═════════════════════════════════════════════════════════════════════════════════════════════════
// ADDITIONAL TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

test "Event: publish throughput" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Use static strings to avoid allocation
    const task_id = "test-task";
    const agent_id = "test-agent";

    // Publish 1000 events
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        const data = EventData{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = agent_id,
            },
        };
        _ = try bus.publish(.task_claimed, data);
    }

    const stats = bus.getStats();
    try std.testing.expect(stats.published >= 1000);
}

// φ² + 1/φ² = 3 | TRINITY

// ═════════════════════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE EDGE CASE TESTS
// ═════════════════════════════════════════════════════════════════════════════════════

test "Reticular: buffer overflow - exactly MAX_EVENTS" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish exactly MAX_EVENTS events
    for (0..MAX_EVENTS) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-001",
            },
        });
    }

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, MAX_EVENTS), stats.buffered);
    try std.testing.expect(stats.published >= MAX_EVENTS);
    // No trim yet (exactly at capacity)
    try std.testing.expectEqual(@as(u64, 0), stats.trim_count);
}

test "Reticular: buffer overflow - one over MAX_EVENTS" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish one more than MAX_EVENTS
    for (0..MAX_EVENTS + 1) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-001",
            },
        });
    }

    const stats = bus.getStats();
    // Should still be at MAX_EVENTS (oldest trimmed)
    try std.testing.expectEqual(@as(usize, MAX_EVENTS), stats.buffered);
    try std.testing.expect(stats.published >= MAX_EVENTS + 1);
    // Should have trimmed at least once
    try std.testing.expect(stats.trim_count >= 1);
}

test "Reticular: empty poll returns empty slice" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "Reticular: poll with future timestamp returns empty" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish an event
    _ = try bus.publish(.task_claimed, .{
        .task_claimed = .{
            .task_id = "task-1",
            .agent_id = "agent-1",
        },
    });

    // Poll with future timestamp (events are in the past)
    const future_time = std.time.milliTimestamp() + 1000000; // 1000 seconds in future
    const events = try bus.poll(future_time, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "Reticular: poll with negative timestamp returns all" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish some events
    for (0..5) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    // Poll with negative timestamp (should return all events)
    const events = try bus.poll(-1000000, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 5), events.len);
}

test "Reticular: batch publish causes buffer overflow" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Fill to near capacity
    for (0..MAX_EVENTS - 50) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    const stats_before = bus.getStats();

    // Publish batch that will overflow
    const batch_size = 200;
    const batch = try allocator.alloc(EventBus.BatchEvent, batch_size);
    defer allocator.free(batch);

    for (batch, 0..) |*evt, i| {
        const task_id = try std.fmt.allocPrint(allocator, "batch-task-{d}", .{i});
        defer allocator.free(task_id);
        evt.* = .{
            .event_type = .task_claimed,
            .data = .{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-2",
                },
            },
        };
    }

    _ = try bus.publishBatch(batch);

    const stats_after = bus.getStats();

    // Should be at MAX_EVENTS
    try std.testing.expectEqual(@as(usize, MAX_EVENTS), stats_after.buffered);
    // Should have trimmed old events
    try std.testing.expect(stats_after.trim_count > stats_before.trim_count);
}

test "Reticular: trim on empty buffer" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Trim on empty buffer should be no-op
    bus.trim(100);

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.buffered);
    try std.testing.expectEqual(@as(u64, 0), stats.trim_count);
}

test "Reticular: clear on empty buffer" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Clear on empty buffer should be no-op
    bus.clear();

    const stats = bus.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.buffered);
}

test "Reticular: multiple clear operations" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish some events
    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    try std.testing.expectEqual(@as(usize, 10), bus.getStats().buffered);

    // Clear multiple times
    bus.clear();
    bus.clear();
    bus.clear();

    try std.testing.expectEqual(@as(usize, 0), bus.getStats().buffered);
}

test "Reticular: utilization at capacity" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Fill to capacity
    for (0..MAX_EVENTS) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    const util = bus.utilization();
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), util, 0.01);
}

test "Reticular: utilization half full" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Fill to half capacity
    for (0..MAX_EVENTS / 2) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    const util = bus.utilization();
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), util, 1.0);
}

test "Reticular: poll max_events larger than available" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish 5 events
    for (0..5) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    // Poll for more events than available
    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    // Should return all available events (not more)
    try std.testing.expectEqual(@as(usize, 5), events.len);
}

test "Reticular: timestamp ordering after overflow" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Publish more than MAX_EVENTS to force overflow
    for (0..MAX_EVENTS + 100) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = task_id,
                .agent_id = "agent-1",
            },
        });
    }

    // Get all events
    const events = try bus.poll(0, allocator, 0);
    defer allocator.free(events);

    // Verify timestamps are in chronological order
    var i: usize = 0;
    while (i < events.len - 1) : (i += 1) {
        try std.testing.expect(events[i + 1].timestamp >= events[i].timestamp);
    }
}

test "Reticular: zero duration_ms in task_completed" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    _ = try bus.publish(.task_completed, .{
        .task_completed = .{
            .task_id = "task-zero-duration",
            .agent_id = "agent-1",
            .duration_ms = 0,
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(@as(u64, 0), events[0].data.task_completed.duration_ms);
}

test "Reticular: very long strings in events" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Create very long strings
    const long_task_id = try allocator.alloc(u8, 10000);
    defer allocator.free(long_task_id);
    @memset(long_task_id, 'X');

    const long_agent_id = try allocator.alloc(u8, 1000);
    defer allocator.free(long_agent_id);
    @memset(long_agent_id, 'Y');

    _ = try bus.publish(.task_failed, .{
        .task_failed = .{
            .task_id = long_task_id,
            .agent_id = long_agent_id,
            .err_msg = "This is a very long error message that should still work",
        },
    });

    const events = try bus.poll(0, allocator, 100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(@as(usize, 10000), events[0].data.task_failed.task_id.len);
    try std.testing.expectEqual(@as(usize, 1000), events[0].data.task_failed.agent_id.len);
}

test "Reticular: peak_buffered never decreases" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Add events
    for (0..100) |_| {
        _ = try bus.publish(.task_claimed, .{
            .task_claimed = .{
                .task_id = "task",
                .agent_id = "agent",
            },
        });
    }

    const stats1 = bus.getStats();
    try std.testing.expectEqual(@as(usize, 100), stats1.peak_buffered);

    // Trim to 50
    bus.trim(50);

    const stats2 = bus.getStats();
    // Peak should still be 100 (never decreases)
    try std.testing.expectEqual(@as(usize, 100), stats2.peak_buffered);
}

test "Reticular: utilization calculation precision" {
    const allocator = std.testing.allocator;
    var bus = EventBus.init(allocator);
    defer bus.deinit();

    // Test exact fractions
    const tests = [_]struct { count: usize, expected: f64 }{
        .{ .count = 0, .expected = 0.0 },
        .{ .count = 1, .expected = 100.0 / @as(f64, @floatFromInt(MAX_EVENTS)) },
        .{ .count = MAX_EVENTS / 2, .expected = 50.0 },
        .{ .count = MAX_EVENTS / 4, .expected = 25.0 },
        .{ .count = MAX_EVENTS * 3 / 4, .expected = 75.0 },
    };

    for (tests) |t| {
        // Clear and add t.count events
        bus.clear();
        for (0..t.count) |i| {
            const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
            defer allocator.free(task_id);
            _ = try bus.publish(.task_claimed, .{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent",
                },
            });
        }

        const util = bus.utilization();
        try std.testing.expectApproxEqAbs(t.expected, util, 0.5);
    }
}
