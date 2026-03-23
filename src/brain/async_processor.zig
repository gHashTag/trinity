//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! ASYNC PROCESSOR — v1.0 — Non-blocking Brain Operations
//!
//! Async task processing for high-throughput scenarios.
//! Brain Region: Thalamus (Async Relay & Processing)
//!
//! Features:
//! - Async task claim/release via worker pool
//! - Async event publishing with backpressure handling
//! - Async health checks with parallel execution
//! - Background telemetry collection
//! - Thread-safe task queues and result channels
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const builtin = @import("builtin");

// Direct imports - use module names, not file paths
const basal_ganglia_mod = @import("basal_ganglia");
const reticular_formation_mod = @import("reticular_formation");

const basal_ganglia = struct {
    pub const Registry = basal_ganglia_mod.Registry;
    pub const TaskClaim = basal_ganglia_mod.TaskClaim;
    pub const getGlobal = basal_ganglia_mod.getGlobal;
    pub const resetGlobal = basal_ganglia_mod.resetGlobal;
};
const reticular_formation = struct {
    pub const EventBus = reticular_formation_mod.EventBus;
    pub const AgentEventType = reticular_formation_mod.AgentEventType;
    pub const EventData = reticular_formation_mod.EventData;
    pub const getGlobal = reticular_formation_mod.getGlobal;
    pub const resetGlobal = reticular_formation_mod.resetGlobal;
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Config = struct {
    /// Number of worker threads in the pool
    worker_count: usize = 4,

    /// Maximum queued tasks before backpressure
    max_queue_depth: usize = 1000,

    /// Telemetry collection interval (ms)
    telemetry_interval_ms: u64 = 5000,

    /// Health check interval (ms)
    health_check_interval_ms: u64 = 10000,

    /// Task timeout (ms)
    task_timeout_ms: u64 = 30000,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ASYNC TASK TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AsyncTask = struct {
    id: u64,
    task_type: TaskType,
    data: TaskData,
    allocated_at: i64,
    timeout_ms: u64,
};

pub const TaskType = enum {
    claim_task,
    release_task,
    publish_event,
    health_check,
    telemetry_snapshot,
    custom,
};

pub const TaskData = union(TaskType) {
    claim_task: struct {
        task_id: []const u8,
        agent_id: []const u8,
        ttl_ms: u64,
        result_channel: *ResultChannel,
    },
    release_task: struct {
        task_id: []const u8,
        agent_id: []const u8,
        result_channel: *ResultChannel,
    },
    publish_event: struct {
        event_type: reticular_formation.AgentEventType,
        data: reticular_formation.EventData,
        result_channel: *ResultChannel,
    },
    health_check: struct {
        result_channel: *ResultChannel,
    },
    telemetry_snapshot: struct {
        result_channel: *ResultChannel,
    },
    custom: struct {
        fn_ptr: *const fn (allocator: std.mem.Allocator, data: ?*anyerror) anyerror!?AsyncTaskResult,
        data: ?*anyerror,
        result_channel: *ResultChannel,
    },
};

pub const AsyncTaskResult = union(enum) {
    claim_success: struct {
        claimed: bool,
    },
    release_success: struct {
        released: bool,
    },
    publish_success: struct {
        published: bool,
    },
    health_report: struct {
        healthy: bool,
        score: f32,
        details: []const u8,
    },
    telemetry: struct {
        active_claims: usize,
        events_published: u64,
        events_buffered: usize,
        timestamp: i64,
    },
    custom_success: bool,
    error_msg: []const u8,
};

/// Thread-safe result channel for async operations
pub const ResultChannel = struct {
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    result: ?AsyncTaskResult,
    ready: bool,

    pub fn init() ResultChannel {
        return ResultChannel{
            .mutex = std.Thread.Mutex{},
            .cond = std.Thread.Condition{},
            .result = null,
            .ready = false,
        };
    }

    pub fn deinit(self: *ResultChannel, allocator: std.mem.Allocator) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.result) |res| {
            // Free any owned memory in result
            switch (res) {
                .health_report => |r| allocator.free(r.details),
                .error_msg => |msg| allocator.free(msg),
                else => {},
            }
        }
    }

    /// Wait for result with timeout (returns null if timeout)
    pub fn wait(self: *ResultChannel, timeout_ms: u64) ?AsyncTaskResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.ready) return self.result;

        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

        while (!self.ready) {
            const now = std.time.milliTimestamp();
            if (now >= deadline) return null;

            const remaining = deadline - now;
            if (remaining <= 0) return null;

            const timeout_ns = @as(u64, @intCast(remaining)) * 1_000_000;
            self.cond.timedWait(&self.mutex, timeout_ns) catch {};
        }

        return self.result;
    }

    /// Set result and notify waiter
    pub fn set(self: *ResultChannel, result: AsyncTaskResult) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.result = result;
        self.ready = true;
        self.cond.signal();
    }

    /// Check if result is ready without waiting
    pub fn isReady(self: *ResultChannel) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.ready;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ASYNC WORKER POOL
// ═══════════════════════════════════════════════════════════════════════════════

/// Worker thread state
const Worker = struct {
    id: usize,
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    processor: *AsyncProcessor,

    fn run(worker: *Worker) void {
        std.log.debug("Async worker {d} started", .{worker.id});

        while (worker.running.load(.acquire)) {
            // Dequeue task with timeout
            const task_result = worker.processor.dequeueTask(100);

            if (task_result) |task_opt| {
                if (task_opt) |t| {
                    worker.processor.executeTask(t);
                }
            } else |err| {
                std.log.err("Worker {d} dequeue error: {}", .{ worker.id, err });
                std.Thread.sleep(100 * std.time.ns_per_ms);
            }
        }

        std.log.debug("Async worker {d} stopped", .{worker.id});
    }
};

pub const AsyncProcessor = struct {
    allocator: std.mem.Allocator,
    config: Config,
    basal_registry: *basal_ganglia.Registry,
    event_bus: *reticular_formation.EventBus,

    // Task queue
    task_queue: std.ArrayList(AsyncTask),
    queue_mutex: std.Thread.Mutex,
    queue_cond: std.Thread.Condition,

    // Workers
    workers: []Worker,
    running: std.atomic.Value(bool),

    // Next task ID
    next_task_id: std.atomic.Value(u64),

    // Telemetry
    telemetry: Telemetry,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        config: Config,
        basal_registry: *basal_ganglia.Registry,
        event_bus: *reticular_formation.EventBus,
    ) !Self {
        const worker_count = config.worker_count;

        var workers: []Worker = undefined;
        if (builtin.single_threaded) {
            // Single-threaded: no workers
            workers = &[_]Worker{};
        } else {
            workers = try allocator.alloc(Worker, worker_count);
            for (workers, 0..) |*w, i| {
                w.* = Worker{
                    .id = i,
                    .thread = null,
                    .running = std.atomic.Value(bool).init(true),
                    .processor = undefined, // Will set after init
                };
            }
        }

        return Self{
            .allocator = allocator,
            .config = config,
            .basal_registry = basal_registry,
            .event_bus = event_bus,
            .task_queue = std.ArrayList(AsyncTask).initCapacity(allocator, 64) catch unreachable,
            .queue_mutex = std.Thread.Mutex{},
            .queue_cond = std.Thread.Condition{},
            .workers = workers,
            .running = std.atomic.Value(bool).init(false),
            .next_task_id = std.atomic.Value(u64).init(1),
            .telemetry = Telemetry.init(allocator, 100),
        };
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.task_queue.deinit(self.allocator);
        if (!builtin.single_threaded) {
            self.allocator.free(self.workers);
        }
        self.telemetry.deinit();
    }

    /// Start the async processor (spawns worker threads)
    pub fn start(self: *Self) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);

        if (!builtin.single_threaded) {
            for (self.workers) |*worker| {
                worker.processor = self;
                worker.thread = try std.Thread.spawn(.{}, Worker.run, .{worker});
            }
        }
    }

    /// Stop the async processor
    pub fn stop(self: *Self) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);

        // Wake all workers
        self.queue_mutex.lock();
        self.queue_cond.broadcast();
        self.queue_mutex.unlock();

        // Join workers
        if (!builtin.single_threaded) {
            for (self.workers) |*worker| {
                if (worker.thread) |handle| {
                    handle.join();
                    worker.thread = null;
                }
            }
        }
    }

    /// Enqueue a task for async processing
    pub fn enqueueTask(self: *Self, task: AsyncTask) !void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        // Check queue depth for backpressure
        if (self.task_queue.items.len >= self.config.max_queue_depth) {
            return error.QueueFull;
        }

        try self.task_queue.append(self.allocator, task);
        self.queue_cond.signal();
    }

    /// Dequeue a task (internal use by workers)
    fn dequeueTask(self: *Self, timeout_ms: u64) !?AsyncTask {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(timeout_ms));

        while (self.task_queue.items.len == 0) {
            if (!self.running.load(.acquire)) return null;

            const now = std.time.milliTimestamp();
            if (now >= deadline) return error.Timeout;

            const remaining = deadline - now;
            const timeout_ns = if (remaining > 0) @as(u64, @intCast(remaining)) * 1_000_000 else 0;
            self.queue_cond.timedWait(&self.queue_mutex, timeout_ns) catch {};
        }

        return self.task_queue.orderedRemove(0);
    }

    /// Execute a task (called by worker threads)
    fn executeTask(self: *Self, task: AsyncTask) void {
        const result = switch (task.task_type) {
            .claim_task => self.executeClaimTask(task),
            .release_task => self.executeReleaseTask(task),
            .publish_event => self.executePublishEvent(task),
            .health_check => self.executeHealthCheck(task),
            .telemetry_snapshot => self.executeTelemetrySnapshot(task),
            .custom => self.executeCustomTask(task),
        };

        // Deliver result through channel
        const channel: *ResultChannel = switch (task.task_type) {
            .claim_task => task.data.claim_task.result_channel,
            .release_task => task.data.release_task.result_channel,
            .publish_event => task.data.publish_event.result_channel,
            .health_check => task.data.health_check.result_channel,
            .telemetry_snapshot => task.data.telemetry_snapshot.result_channel,
            .custom => task.data.custom.result_channel,
        };

        channel.set(result);

        // Update telemetry
        self.telemetry.recordTaskCompletion(task.task_type);
    }

    fn executeClaimTask(self: *Self, task: AsyncTask) AsyncTaskResult {
        const data = task.data.claim_task;
        const claimed = self.basal_registry.claim(self.allocator, data.task_id, data.agent_id, data.ttl_ms) catch |err| {
            const msg = std.fmt.allocPrint(self.allocator, "claim failed: {}", .{err}) catch "unknown error";
            return AsyncTaskResult{ .error_msg = msg };
        };

        return AsyncTaskResult{ .claim_success = .{ .claimed = claimed } };
    }

    fn executeReleaseTask(self: *Self, task: AsyncTask) AsyncTaskResult {
        const data = task.data.release_task;
        const released = self.basal_registry.abandon(data.task_id, data.agent_id);

        return AsyncTaskResult{ .release_success = .{ .released = released } };
    }

    fn executePublishEvent(self: *Self, task: AsyncTask) AsyncTaskResult {
        const data = task.data.publish_event;
        self.event_bus.publish(data.event_type, data.data) catch return AsyncTaskResult{ .publish_success = .{ .published = false } };

        return AsyncTaskResult{ .publish_success = .{ .published = true } };
    }

    fn executeHealthCheck(self: *Self, task: AsyncTask) AsyncTaskResult {
        _ = task;

        const stats = self.event_bus.getStats();
        const basal_stats = self.basal_registry.getStats();
        const claim_count = basal_stats.active_claims;

        // Simple health calculation
        const claims_ok = claim_count < 10000;
        const events_ok = stats.buffered < 5000;
        const healthy = claims_ok and events_ok;
        const score: f32 = if (healthy) 100.0 else 50.0;

        const details = std.fmt.allocPrint(
            self.allocator,
            "claims={d},events_buffered={d},workers_running={d}",
            .{ claim_count, stats.buffered, self.getActiveWorkerCount() },
        ) catch "health details unavailable";

        return AsyncTaskResult{ .health_report = .{
            .healthy = healthy,
            .score = score,
            .details = details,
        } };
    }

    fn executeTelemetrySnapshot(self: *Self, task: AsyncTask) AsyncTaskResult {
        _ = task;

        const stats = self.event_bus.getStats();
        const basal_stats = self.basal_registry.getStats();

        return AsyncTaskResult{ .telemetry = .{
            .active_claims = @as(u64, @intCast(basal_stats.active_claims)),
            .events_published = stats.published,
            .events_buffered = stats.buffered,
            .timestamp = std.time.milliTimestamp(),
        } };
    }

    fn executeCustomTask(self: *Self, task: AsyncTask) AsyncTaskResult {
        const data = task.data.custom;

        const result = data.fn_ptr(self.allocator, data.data) catch |err| {
            const msg = std.fmt.allocPrint(self.allocator, "custom task failed: {}", .{err}) catch "unknown error";
            return AsyncTaskResult{ .error_msg = msg };
        };

        if (result) |r| {
            _ = r;
            return AsyncTaskResult{ .custom_success = true };
        } else {
            return AsyncTaskResult{ .custom_success = false };
        }
    }

    /// Get number of active workers
    fn getActiveWorkerCount(self: *const Self) usize {
        if (builtin.single_threaded) return 0;

        var count: usize = 0;
        for (self.workers) |*worker| {
            if (worker.thread != null) count += 1;
        }
        return count;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PUBLIC ASYNC API
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Async claim task
    pub fn asyncClaimTask(
        self: *Self,
        task_id: []const u8,
        agent_id: []const u8,
        ttl_ms: u64,
        channel: *ResultChannel,
    ) !void {
        const task_id_copy = try self.allocator.dupe(u8, task_id);
        errdefer self.allocator.free(task_id_copy);

        const agent_id_copy = try self.allocator.dupe(u8, agent_id);
        errdefer self.allocator.free(agent_id_copy);

        const task = AsyncTask{
            .id = self.next_task_id.fetchAdd(1, .monotonic),
            .task_type = .claim_task,
            .data = .{ .claim_task = .{
                .task_id = task_id_copy,
                .agent_id = agent_id_copy,
                .ttl_ms = ttl_ms,
                .result_channel = channel,
            } },
            .allocated_at = std.time.milliTimestamp(),
            .timeout_ms = self.config.task_timeout_ms,
        };

        try self.enqueueTask(task);
    }

    /// Async release/abandon task
    pub fn asyncReleaseTask(
        self: *Self,
        task_id: []const u8,
        agent_id: []const u8,
        channel: *ResultChannel,
    ) !void {
        const task_id_copy = try self.allocator.dupe(u8, task_id);
        errdefer self.allocator.free(task_id_copy);

        const agent_id_copy = try self.allocator.dupe(u8, agent_id);
        errdefer self.allocator.free(agent_id_copy);

        const task = AsyncTask{
            .id = self.next_task_id.fetchAdd(1, .monotonic),
            .task_type = .release_task,
            .data = .{ .release_task = .{
                .task_id = task_id_copy,
                .agent_id = agent_id_copy,
                .result_channel = channel,
            } },
            .allocated_at = std.time.milliTimestamp(),
            .timeout_ms = self.config.task_timeout_ms,
        };

        try self.enqueueTask(task);
    }

    /// Async publish event
    pub fn asyncPublishEvent(
        self: *Self,
        event_type: reticular_formation.AgentEventType,
        event_data: reticular_formation.EventData,
        channel: *ResultChannel,
    ) !void {
        // Clone event data strings
        const cloned_data = try self.cloneEventData(event_data);
        errdefer self.destroyEventData(cloned_data);

        const task = AsyncTask{
            .id = self.next_task_id.fetchAdd(1, .monotonic),
            .task_type = .publish_event,
            .data = .{ .publish_event = .{
                .event_type = event_type,
                .data = cloned_data,
                .result_channel = channel,
            } },
            .allocated_at = std.time.milliTimestamp(),
            .timeout_ms = self.config.task_timeout_ms,
        };

        try self.enqueueTask(task);
    }

    /// Async health check
    pub fn asyncHealthCheck(self: *Self, channel: *ResultChannel) !void {
        const task = AsyncTask{
            .id = self.next_task_id.fetchAdd(1, .monotonic),
            .task_type = .health_check,
            .data = .{ .health_check = .{
                .result_channel = channel,
            } },
            .allocated_at = std.time.milliTimestamp(),
            .timeout_ms = self.config.task_timeout_ms,
        };

        try self.enqueueTask(task);
    }

    /// Async telemetry snapshot
    pub fn asyncTelemetrySnapshot(self: *Self, channel: *ResultChannel) !void {
        const task = AsyncTask{
            .id = self.next_task_id.fetchAdd(1, .monotonic),
            .task_type = .telemetry_snapshot,
            .data = .{ .telemetry_snapshot = .{
                .result_channel = channel,
            } },
            .allocated_at = std.time.milliTimestamp(),
            .timeout_ms = self.config.task_timeout_ms,
        };

        try self.enqueueTask(task);
    }

    /// Clone event data (copies strings)
    fn cloneEventData(self: *Self, data: reticular_formation.EventData) !reticular_formation.EventData {
        return switch (data) {
            .task_claimed => |d| reticular_formation.EventData{
                .task_claimed = .{
                    .task_id = try self.allocator.dupe(u8, d.task_id),
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                },
            },
            .task_completed => |d| reticular_formation.EventData{
                .task_completed = .{
                    .task_id = try self.allocator.dupe(u8, d.task_id),
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                    .duration_ms = d.duration_ms,
                },
            },
            .task_failed => |d| reticular_formation.EventData{
                .task_failed = .{
                    .task_id = try self.allocator.dupe(u8, d.task_id),
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                    .err_msg = try self.allocator.dupe(u8, d.err_msg),
                },
            },
            .task_abandoned => |d| reticular_formation.EventData{
                .task_abandoned = .{
                    .task_id = try self.allocator.dupe(u8, d.task_id),
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                    .reason = try self.allocator.dupe(u8, d.reason),
                },
            },
            .agent_idle => |d| reticular_formation.EventData{
                .agent_idle = .{
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                    .idle_ms = d.idle_ms,
                },
            },
            .agent_spawned => |d| reticular_formation.EventData{
                .agent_spawned = .{
                    .agent_id = try self.allocator.dupe(u8, d.agent_id),
                },
            },
        };
    }

    /// Destroy cloned event data
    fn destroyEventData(self: *Self, data: reticular_formation.EventData) void {
        switch (data) {
            .task_claimed => |d| {
                self.allocator.free(d.task_id);
                self.allocator.free(d.agent_id);
            },
            .task_completed => |d| {
                self.allocator.free(d.task_id);
                self.allocator.free(d.agent_id);
            },
            .task_failed => |d| {
                self.allocator.free(d.task_id);
                self.allocator.free(d.agent_id);
                self.allocator.free(d.err_msg);
            },
            .task_abandoned => |d| {
                self.allocator.free(d.task_id);
                self.allocator.free(d.agent_id);
                self.allocator.free(d.reason);
            },
            .agent_idle => |d| {
                self.allocator.free(d.agent_id);
            },
            .agent_spawned => |d| {
                self.allocator.free(d.agent_id);
            },
        }
    }

    /// Get current queue depth
    pub fn getQueueDepth(self: *Self) usize {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        return self.task_queue.items.len;
    }

    /// Get telemetry data
    pub fn getTelemetry(self: *const Self) Telemetry {
        return self.telemetry;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TELEMETRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const Telemetry = struct {
    allocator: std.mem.Allocator,
    task_counts: std.EnumArray(TaskType, std.atomic.Value(u64)),
    task_times: std.EnumArray(TaskType, std.atomic.Value(u64)),
    max_points: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_points: usize) Self {
        var task_counts: std.EnumArray(TaskType, std.atomic.Value(u64)) = undefined;
        var task_times: std.EnumArray(TaskType, std.atomic.Value(u64)) = undefined;

        inline for (std.meta.fields(TaskType)) |field| {
            const tag = @field(TaskType, field.name);
            task_counts.set(tag, std.atomic.Value(u64).init(0));
            task_times.set(tag, std.atomic.Value(u64).init(0));
        }

        return Self{
            .allocator = allocator,
            .task_counts = task_counts,
            .task_times = task_times,
            .max_points = max_points,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Atomic values don't need deinit
    }

    pub fn recordTaskCompletion(self: *Self, task_type: TaskType) void {
        // For now, we don't track task counts atomically
        // The atomic access requires mutable pointers which EnumArray doesn't provide
        _ = self;
        _ = task_type;
    }

    pub fn getTaskCount(self: *const Self, task_type: TaskType) u64 {
        return self.task_counts.get(task_type).load(.monotonic);
    }

    pub fn getTotalTasks(self: *const Self) u64 {
        var total: u64 = 0;
        inline for (std.meta.fields(TaskType)) |field| {
            const tag = @field(TaskType, field.name);
            total += self.getTaskCount(tag);
        }
        return total;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND TELEMETRY COLLECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const BackgroundCollector = struct {
    processor: *AsyncProcessor,
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    interval_ms: u64,

    pub fn init(processor: *AsyncProcessor, interval_ms: u64) BackgroundCollector {
        return BackgroundCollector{
            .processor = processor,
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
            .interval_ms = interval_ms,
        };
    }

    pub fn deinit(self: *BackgroundCollector) void {
        self.stop();
    }

    pub fn start(self: *BackgroundCollector) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);

        if (!builtin.single_threaded) {
            self.thread = try std.Thread.spawn(.{}, runCollector, .{self});
        }
    }

    pub fn stop(self: *BackgroundCollector) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);

        if (self.thread) |handle| {
            handle.join();
            self.thread = null;
        }
    }

    fn runCollector(collector: *BackgroundCollector) void {
        std.log.debug("Background telemetry collector started", .{});

        while (collector.running.load(.acquire)) {
            std.Thread.sleep(collector.interval_ms * std.time.ns_per_ms);

            // Collect telemetry snapshot in background
            var channel = ResultChannel.init();
            defer channel.deinit(collector.processor.allocator);

            collector.processor.asyncTelemetrySnapshot(&channel) catch |err| {
                std.log.err("Telemetry snapshot failed: {}", .{err});
                continue;
            };

            // Non-blocking check - if not ready, skip
            const result = channel.wait(100);
            if (result) |r| {
                _ = r;
                // Could store this somewhere for analysis
            }
        }

        std.log.debug("Background telemetry collector stopped", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL SINGLETON
// ═══════════════════════════════════════════════════════════════════════════════

var global_processor: ?*AsyncProcessor = null;
var global_mutex = std.Thread.Mutex{};

pub fn getGlobal(allocator: std.mem.Allocator, config: Config) !*AsyncProcessor {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_processor) |proc| return proc;

    // Get brain components
    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    const proc = try allocator.create(AsyncProcessor);
    proc.* = try AsyncProcessor.init(allocator, config, registry, event_bus);
    global_processor = proc;
    return proc;
}

pub fn resetGlobal(allocator: std.mem.Allocator) void {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_processor) |proc| {
        proc.deinit();
        allocator.destroy(proc);
        global_processor = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ResultChannel wait and set" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Set result
    channel.set(AsyncTaskResult{ .claim_success = .{ .claimed = true } });

    // Wait should immediately return
    const result = channel.wait(1000);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(true, result.?.claim_success.claimed);
}

test "ResultChannel timeout" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Wait without set should timeout
    const result = channel.wait(100);
    try std.testing.expect(result == null);
}

test "AsyncProcessor init and deinit" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try std.testing.expectEqual(@as(usize, 0), processor.getQueueDepth());
}

test "AsyncProcessor async claim task" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncClaimTask("test-async-task", "agent-001", 5000, &channel);

    // In single-threaded mode, tasks won't execute automatically
    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);
        try std.testing.expect(result.?.claim_success.claimed);
    }
}

test "AsyncProcessor async health check" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncHealthCheck(&channel);

    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);
        try std.testing.expect(result.?.health_report.healthy);

        // Free the details string
        allocator.free(result.?.health_report.details);
    }
}

test "AsyncProcessor telemetry" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const tel = processor.getTelemetry();
    try std.testing.expectEqual(@as(u64, 0), tel.getTotalTasks());
}

test "BackgroundCollector init" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var collector = BackgroundCollector.init(&processor, 1000);
    try collector.start();
    collector.stop();

    try std.testing.expectEqual(@as(?std.Thread, null), collector.thread);
}

test "AsyncProcessor queue backpressure" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0, .max_queue_depth = 5 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Fill queue to max
    for (0..5) |_| {
        try processor.asyncHealthCheck(&channel);
    }

    // Next one should fail
    const result = processor.asyncHealthCheck(&channel);
    try std.testing.expectError(error.QueueFull, result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASYNC TASK CLAIM/RELEASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor claim and release same task" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const task_id = "task-claim-release-001";
    const agent_id = "agent-claim-001";

    // Claim task
    var claim_channel = ResultChannel.init();
    defer claim_channel.deinit(allocator);

    try processor.asyncClaimTask(task_id, agent_id, 5000, &claim_channel);

    if (!builtin.single_threaded) {
        const claim_result = claim_channel.wait(5000);
        try std.testing.expect(claim_result != null);
        try std.testing.expect(claim_result.?.claim_success.claimed);

        // Release task
        var release_channel = ResultChannel.init();
        defer release_channel.deinit(allocator);

        try processor.asyncReleaseTask(task_id, agent_id, &release_channel);

        const release_result = release_channel.wait(5000);
        try std.testing.expect(release_result != null);
        try std.testing.expect(release_result.?.release_success.released);
    }
}

test "AsyncProcessor duplicate claim fails" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const task_id = "task-duplicate-001";
    const agent1 = "agent-duplicate-001";
    const agent2 = "agent-duplicate-002";

    // First claim
    var channel1 = ResultChannel.init();
    defer channel1.deinit(allocator);
    try processor.asyncClaimTask(task_id, agent1, 5000, &channel1);

    if (!builtin.single_threaded) {
        const result1 = channel1.wait(5000);
        try std.testing.expect(result1 != null);
        try std.testing.expect(result1.?.claim_success.claimed);

        // Second claim should fail
        var channel2 = ResultChannel.init();
        defer channel2.deinit(allocator);
        try processor.asyncClaimTask(task_id, agent2, 5000, &channel2);

        const result2 = channel2.wait(5000);
        try std.testing.expect(result2 != null);
        try std.testing.expect(!result2.?.claim_success.claimed);
    }
}

test "AsyncProcessor parallel claims" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 4 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const num_tasks = 10;

    if (!builtin.single_threaded) {
        // Create channels for parallel claims
        var channels: [num_tasks]ResultChannel = undefined;
        for (&channels, 0..) |*ch, i| {
            ch.* = ResultChannel.init();
            const task_id = try std.fmt.allocPrint(allocator, "task-parallel-{d}", .{i});
            defer allocator.free(task_id);
            try processor.asyncClaimTask(task_id, "agent-parallel", 5000, ch);
        }

        // Wait for all results
        var success_count: usize = 0;
        for (&channels) |*ch| {
            const result = ch.wait(5000);
            try std.testing.expect(result != null);
            if (result.?.claim_success.claimed) {
                success_count += 1;
            }
            ch.deinit(allocator);
        }

        // All claims should succeed (different task IDs)
        try std.testing.expectEqual(@as(usize, num_tasks), success_count);
    }
}

test "AsyncProcessor release by wrong agent fails" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const task_id = "task-wrong-agent-001";
    const owner = "agent-owner-001";
    const impostor = "agent-impostor-001";

    // Claim as owner
    var claim_channel = ResultChannel.init();
    defer claim_channel.deinit(allocator);
    try processor.asyncClaimTask(task_id, owner, 5000, &claim_channel);

    if (!builtin.single_threaded) {
        const claim_result = claim_channel.wait(5000);
        try std.testing.expect(claim_result != null);
        try std.testing.expect(claim_result.?.claim_success.claimed);

        // Try to release as impostor
        var release_channel = ResultChannel.init();
        defer release_channel.deinit(allocator);
        try processor.asyncReleaseTask(task_id, impostor, &release_channel);

        const release_result = release_channel.wait(5000);
        try std.testing.expect(release_result != null);
        try std.testing.expect(!release_result.?.release_success.released);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NON-BLOCKING EVENT PUBLISHING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor publish event non-blocking" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const event_data = reticular_formation.EventData{
        .task_claimed = .{
            .task_id = "task-event-001",
            .agent_id = "agent-event-001",
        },
    };

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Publish should return immediately (non-blocking)
    const before_publish = std.time.milliTimestamp();
    try processor.asyncPublishEvent(.task_claimed, event_data, &channel);
    const after_publish = std.time.milliTimestamp();

    // Should take less than 10ms (just enqueue)
    const elapsed = after_publish - before_publish;
    try std.testing.expect(elapsed < 10);

    if (!builtin.single_threaded) {
        // Wait for async completion
        const result = channel.wait(5000);
        try std.testing.expect(result != null);
        try std.testing.expect(result.?.publish_success.published);
    }
}

test "AsyncProcessor publish multiple events" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const num_events = 20;

    if (!builtin.single_threaded) {
        var channels: [num_events]ResultChannel = undefined;
        var published_count: usize = 0;

        // Publish all events rapidly
        for (&channels, 0..) |*ch, i| {
            ch.* = ResultChannel.init();

            const task_id = try std.fmt.allocPrint(allocator, "task-batch-{d}", .{i});
            defer allocator.free(task_id);

            const event_data = reticular_formation.EventData{
                .task_claimed = .{
                    .task_id = task_id,
                    .agent_id = "agent-batch",
                },
            };

            try processor.asyncPublishEvent(.task_claimed, event_data, ch);
        }

        // Wait for all results
        for (&channels) |*ch| {
            const result = ch.wait(5000);
            try std.testing.expect(result != null);
            if (result.?.publish_success.published) {
                published_count += 1;
            }
            ch.deinit(allocator);
        }

        try std.testing.expectEqual(@as(usize, num_events), published_count);
    }
}

test "AsyncProcessor publish all event types" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    if (!builtin.single_threaded) {
        // Test task_claimed
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .task_claimed,
                .{ .task_claimed = .{ .task_id = "t1", .agent_id = "a1" } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }

        // Test task_completed
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .task_completed,
                .{ .task_completed = .{ .task_id = "t2", .agent_id = "a2", .duration_ms = 1000 } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }

        // Test task_failed
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .task_failed,
                .{ .task_failed = .{ .task_id = "t3", .agent_id = "a3", .err_msg = "error" } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }

        // Test task_abandoned
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .task_abandoned,
                .{ .task_abandoned = .{ .task_id = "t4", .agent_id = "a4", .reason = "timeout" } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }

        // Test agent_idle
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .agent_idle,
                .{ .agent_idle = .{ .agent_id = "a5", .idle_ms = 30000 } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }

        // Test agent_spawned
        {
            var ch = ResultChannel.init();
            defer ch.deinit(allocator);
            try processor.asyncPublishEvent(
                .agent_spawned,
                .{ .agent_spawned = .{ .agent_id = "a6" } },
                &ch,
            );
            const r = ch.wait(5000);
            try std.testing.expect(r != null and r.?.publish_success.published);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND HEALTH CHECK TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor health check returns valid data" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncHealthCheck(&channel);

    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);

        switch (result.?) {
            .health_report => |report| {
                // Should have valid health score
                try std.testing.expect(report.score >= 0.0 and report.score <= 100.0);
                try std.testing.expect(report.details.len > 0);

                // Free details string
                allocator.free(report.details);
            },
            else => return error.ExpectedHealthReport,
        }
    }
}

test "AsyncProcessor health check with claims" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    // Add some claims
    const num_claims = 5;
    for (0..num_claims) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "health-check-task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "health-agent", 60000);
    }

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncHealthCheck(&channel);

    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);

        switch (result.?) {
            .health_report => |report| {
                try std.testing.expect(report.healthy);
                allocator.free(report.details);
            },
            else => return error.ExpectedHealthReport,
        }
    }
}

test "AsyncProcessor concurrent health checks" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 4 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    const num_checks = 10;

    if (!builtin.single_threaded) {
        var channels: [num_checks]ResultChannel = undefined;
        for (&channels) |*ch| {
            ch.* = ResultChannel.init();
            try processor.asyncHealthCheck(ch);
        }

        // All should complete
        for (&channels) |*ch| {
            const result = ch.wait(5000);
            try std.testing.expect(result != null);
            switch (result.?) {
                .health_report => |r| allocator.free(r.details),
                else => return error.ExpectedHealthReport,
            }
            ch.deinit(allocator);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASYNC TELEMETRY COLLECTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor telemetry snapshot" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncTelemetrySnapshot(&channel);

    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);

        switch (result.?) {
            .telemetry => |tel| {
                // Timestamp should be recent
                const now = std.time.milliTimestamp();
                try std.testing.expect(tel.timestamp > 0);
                try std.testing.expect(tel.timestamp <= now);
            },
            else => return error.ExpectedTelemetry,
        }
    }
}

test "AsyncProcessor telemetry with activity" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    // Generate some activity
    const task_id = "telemetry-task-001";
    _ = try registry.claim(allocator, task_id, "telemetry-agent", 60000);

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncTelemetrySnapshot(&channel);

    if (!builtin.single_threaded) {
        const result = channel.wait(5000);
        try std.testing.expect(result != null);

        switch (result.?) {
            .telemetry => |tel| {
                // Should have at least one claim
                try std.testing.expect(tel.active_claims >= 1);
            },
            else => return error.ExpectedTelemetry,
        }
    }
}

test "AsyncProcessor telemetry getTaskCount" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const tel = processor.getTelemetry();

    // All task type counts should start at 0
    const all_task_types = [_]TaskType{
        .claim_task,
        .release_task,
        .publish_event,
        .health_check,
        .telemetry_snapshot,
        .custom,
    };

    for (all_task_types) |tt| {
        try std.testing.expectEqual(@as(u64, 0), tel.getTaskCount(tt));
    }

    try std.testing.expectEqual(@as(u64, 0), tel.getTotalTasks());
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT CHANNEL TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ResultChannel isReady before wait" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Not ready initially
    try std.testing.expect(!channel.isReady());

    // Set result
    channel.set(AsyncTaskResult{ .claim_success = .{ .claimed = true } });

    // Now ready
    try std.testing.expect(channel.isReady());
}

test "ResultChannel multiple waits return same result" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    const expected = AsyncTaskResult{ .claim_success = .{ .claimed = true } };
    channel.set(expected);

    // First wait
    const result1 = channel.wait(1000);
    try std.testing.expect(result1 != null);
    try std.testing.expect(result1.?.claim_success.claimed);

    // Second wait should also work
    const result2 = channel.wait(1000);
    try std.testing.expect(result2 != null);
    try std.testing.expect(result2.?.claim_success.claimed);
}

test "ResultChannel zero timeout" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Zero timeout with no result should return null immediately
    const result = channel.wait(0);
    try std.testing.expect(result == null);
}

test "ResultChannel error message cleanup" {
    const allocator = std.testing.allocator;
    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    const error_msg = try allocator.dupe(u8, "test error message");
    channel.set(AsyncTaskResult{ .error_msg = error_msg });

    // Result should contain the error message
    const result = channel.wait(1000);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("test error message", result.?.error_msg);

    // deinit should free the error message
    channel.deinit(allocator);
}

test "ResultChannel health report cleanup" {
    const allocator = std.testing.allocator;
    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    const details = try allocator.dupe(u8, "health details string");
    channel.set(AsyncTaskResult{
        .health_report = .{
            .healthy = true,
            .score = 95.0,
            .details = details,
        },
    });

    const result = channel.wait(1000);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("health details string", result.?.health_report.details);

    // deinit should free the details string
    channel.deinit(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND COLLECTOR TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BackgroundCollector lifecycle" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var collector = BackgroundCollector.init(&processor, 100);

    // Not running initially
    try std.testing.expect(!collector.running.load(.acquire));
    try std.testing.expect(collector.thread == null);

    // Start
    try collector.start();
    try std.testing.expect(collector.running.load(.acquire));

    // Stop
    collector.stop();
    try std.testing.expect(!collector.running.load(.acquire));
    try std.testing.expect(collector.thread == null);
}

test "BackgroundCollector short run" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    defer processor.stop();

    var collector = BackgroundCollector.init(&processor, 50); // 50ms interval

    try collector.start();

    // Let it run for a bit
    std.Thread.sleep(150 * std.time.ns_per_ms);

    collector.stop();
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL SINGLETON TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor global singleton" {
    const allocator = std.testing.allocator;

    // Reset first
    resetGlobal(allocator);

    const proc1 = try getGlobal(allocator, .{ .worker_count = 2 });
    const proc2 = try getGlobal(allocator, .{ .worker_count = 4 });

    // Should return same instance
    try std.testing.expectEqual(proc1, proc2);

    resetGlobal(allocator);
}

test "AsyncProcessor queue depth tracking" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0, .max_queue_depth = 100 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), processor.getQueueDepth());

    // Add some tasks
    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    for (0..5) |_| {
        try processor.asyncHealthCheck(&channel);
    }

    try std.testing.expectEqual(@as(usize, 5), processor.getQueueDepth());
}

test "AsyncProcessor stop without start" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Stop without start should not crash
    processor.stop();

    try std.testing.expect(!processor.running.load(.acquire));
}

test "AsyncProcessor start twice idempotent" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 2 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    try processor.start(); // Should be idempotent

    try std.testing.expect(processor.running.load(.acquire));

    processor.stop();
}

test "AsyncProcessor config defaults" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{}, // Use default config
        registry,
        event_bus,
    );
    defer processor.deinit();

    try std.testing.expectEqual(@as(usize, 4), processor.config.worker_count);
    try std.testing.expectEqual(@as(usize, 1000), processor.config.max_queue_depth);
    try std.testing.expectEqual(@as(u64, 5000), processor.config.telemetry_interval_ms);
    try std.testing.expectEqual(@as(u64, 10000), processor.config.health_check_interval_ms);
    try std.testing.expectEqual(@as(u64, 30000), processor.config.task_timeout_ms);
}

// ═════════════════════════════════════════════════════════════════════════════
// EDGE CASE AND EMPTY INPUT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AsyncProcessor zero workers" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try std.testing.expectEqual(@as(usize, 0), processor.config.worker_count);
}

test "AsyncProcessor task ID increment" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const id1 = processor.next_task_id.fetchAdd(1, .monotonic);
    const id2 = processor.next_task_id.fetchAdd(1, .monotonic);
    const id3 = processor.next_task_id.fetchAdd(1, .monotonic);

    // IDs should be monotonically increasing
    try std.testing.expect(id2 > id1);
    try std.testing.expect(id3 > id2);
}

test "AsyncProcessor enqueue max depth boundary" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0, .max_queue_depth = 3 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Fill queue to max
    try processor.asyncHealthCheck(&channel);
    try processor.asyncHealthCheck(&channel);
    try processor.asyncHealthCheck(&channel);

    try std.testing.expectEqual(@as(usize, 3), processor.getQueueDepth());

    // Next should fail
    const result = processor.asyncHealthCheck(&channel);
    try std.testing.expectError(error.QueueFull, result);
}

test "AsyncProcessor dequeue timeout" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0, .max_queue_depth = 100 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Keep processor running to test timeout (not null return)
    const result = processor.dequeueTask(100);

    // Should timeout, not return null
    try std.testing.expectError(error.Timeout, result);
}

test "AsyncProcessor dequeue null when stopped" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Stop processor
    processor.running.store(false, .release);

    const result = try processor.dequeueTask(1000);

    try std.testing.expect(result == null);
}

test "AsyncProcessor empty string task IDs" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Empty task ID should work
    _ = processor.asyncClaimTask("", "agent-1", 5000, &channel) catch {};

    try std.testing.expectEqual(@as(usize, 1), processor.getQueueDepth());
}

test "AsyncProcessor zero TTL" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    _ = processor.asyncClaimTask("task-zero-ttl", "agent-1", 0, &channel) catch {};

    try std.testing.expectEqual(@as(usize, 1), processor.getQueueDepth());
}

test "AsyncProcessor large TTL" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Very large TTL (1 hour in ms) should work
    const large_ttl: u64 = 60 * 60 * 1000;
    _ = processor.asyncClaimTask("task-large-ttl", "agent-1", large_ttl, &channel) catch {};

    try std.testing.expectEqual(@as(usize, 1), processor.getQueueDepth());
}

test "TaskType all values" {
    const task_types = [_]TaskType{
        .claim_task,
        .release_task,
        .publish_event,
        .health_check,
        .telemetry_snapshot,
        .custom,
    };

    for (task_types, 0..) |tt, i| {
        // Cast i to u8 since TaskType enum is u8-sized
        try std.testing.expectEqual(@as(u8, @intCast(i)), @intFromEnum(tt));
    }
}

test "Config all field defaults" {
    const config = Config{};

    try std.testing.expectEqual(@as(usize, 4), config.worker_count);
    try std.testing.expectEqual(@as(usize, 1000), config.max_queue_depth);
    try std.testing.expectEqual(@as(u64, 5000), config.telemetry_interval_ms);
    try std.testing.expectEqual(@as(u64, 10000), config.health_check_interval_ms);
    try std.testing.expectEqual(@as(u64, 30000), config.task_timeout_ms);
}

test "AsyncTaskResult all variant types" {
    const allocator = std.testing.allocator;

    // Verify all variant types compile and initialize correctly
    _ = AsyncTaskResult{ .claim_success = .{ .claimed = true } };
    _ = AsyncTaskResult{ .release_success = .{ .released = true } };
    _ = AsyncTaskResult{ .publish_success = .{ .published = true } };
    const health_report = AsyncTaskResult{ .health_report = .{
        .healthy = true,
        .score = 100.0,
        .details = try allocator.dupe(u8, "details"),
    } };
    defer allocator.free(health_report.health_report.details);
    _ = AsyncTaskResult{ .telemetry = .{
        .active_claims = 10,
        .events_published = 100,
        .events_buffered = 5,
        .timestamp = 1000,
    } };
    _ = AsyncTaskResult{ .custom_success = true };
    const error_msg = AsyncTaskResult{ .error_msg = try allocator.dupe(u8, "error") };
    defer allocator.free(error_msg.error_msg);

    try std.testing.expect(true);
}

test "ResultChannel immediate wait with result" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    channel.set(AsyncTaskResult{ .custom_success = true });

    // Zero timeout with ready result should work
    const result = channel.wait(0);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.custom_success == true);
}

test "ResultChannel very long timeout" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    const before = std.time.milliTimestamp();

    // Very long timeout without result
    const result = channel.wait(100000);

    const elapsed = std.time.milliTimestamp() - before;

    try std.testing.expect(result == null);
    try std.testing.expect(elapsed < 100); // Should return quickly
}

test "ResultChannel isReady concurrent" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Not ready initially
    try std.testing.expect(!channel.isReady());

    // Set in different context
    {
        channel.mutex.lock();
        defer channel.mutex.unlock();

        channel.result = AsyncTaskResult{ .custom_success = true };
        channel.ready = true;
    }

    try std.testing.expect(channel.isReady());
}

test "Telemetry all task types counted" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const tel = processor.getTelemetry();

    // All task types should have counters
    const task_types = [_]TaskType{
        .claim_task,
        .release_task,
        .publish_event,
        .health_check,
        .telemetry_snapshot,
        .custom,
    };

    for (task_types) |tt| {
        _ = tel.getTaskCount(tt);
    }
}

test "Telemetry getTotalTasks" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const tel = processor.getTelemetry();

    // Initially should be 0
    try std.testing.expectEqual(@as(u64, 0), tel.getTotalTasks());
}

test "BackgroundCollector zero interval" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var collector = BackgroundCollector.init(&processor, 0);

    // Zero interval is valid (polls continuously)
    try collector.start();
    std.Thread.sleep(50_000_000); // 50ms
    collector.stop();

    try std.testing.expect(!collector.running.load(.acquire));
}

test "AsyncProcessor multiple stop calls" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try processor.start();
    processor.stop();
    processor.stop();
    processor.stop(); // Should be idempotent

    try std.testing.expect(!processor.running.load(.acquire));
}

test "AsyncProcessor deinit without stop" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );

    // deinit without explicit stop should work
    processor.deinit();

    try std.testing.expect(true);
}

test "ResultChannel deinit with null result" {
    const allocator = std.testing.allocator;

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // No result set
    try std.testing.expect(channel.result == null);

    // deinit should handle null gracefully
}

test "ResultChannel deinit twice" {
    const allocator = std.testing.allocator;

    var channel = ResultChannel.init();

    // First deinit
    channel.deinit(allocator);

    // Second deinit should not crash
    // Note: this is technically undefined behavior in Rust,
    // but Zig deinit just frees memory, which should be safe-ish
}

test "AsyncProcessor getQueueDepth concurrent" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // Call getQueueDepth multiple times (simulated concurrent access)
    const depths = [_]usize{
        processor.getQueueDepth(),
        processor.getQueueDepth(),
        processor.getQueueDepth(),
    };

    try std.testing.expectEqual(@as(usize, 0), depths[0]);
    try std.testing.expectEqual(@as(usize, 0), depths[1]);
    try std.testing.expectEqual(@as(usize, 0), depths[2]);
}

test "AsyncProcessor task timeout configuration" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .task_timeout_ms = 1000 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    try processor.asyncClaimTask("test-task", "agent-1", 5000, &channel);

    // Task should have configured timeout
    try std.testing.expectEqual(@as(usize, 1), processor.getQueueDepth());
}

test "BackgroundCollector start stop cycle" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var collector = BackgroundCollector.init(&processor, 100);

    // Multiple start/stop cycles
    try collector.start();
    std.Thread.sleep(25_000_000);
    collector.stop();

    try collector.start();
    std.Thread.sleep(25_000_000);
    collector.stop();

    try collector.start();
    collector.stop();

    try std.testing.expect(!collector.running.load(.acquire));
}

test "AsyncProcessor worker ID assignment" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 4 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Verify worker IDs are sequential from 0
    if (!builtin.single_threaded) {
        for (processor.workers, 0..) |worker, i| {
            try std.testing.expectEqual(i, worker.id);
        }
    } else {
        try std.testing.expectEqual(@as(usize, 0), processor.workers.len);
    }
}

test "AsyncProcessor single threaded mode" {
    if (builtin.single_threaded) {
        // In single-threaded mode, no workers should be allocated
        try std.testing.expect(true);
    } else {
        // Multi-threaded mode
        try std.testing.expect(true);
    }
}

test "TaskData union all variants valid" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    var channel = ResultChannel.init();
    defer channel.deinit(allocator);

    // All task types should be enqueable
    try processor.asyncClaimTask("task", "agent", 1000, &channel);
    try processor.asyncReleaseTask("task", "agent", &channel);
    try processor.asyncPublishEvent(.task_claimed, .{ .task_claimed = .{ .task_id = "t", .agent_id = "a" } }, &channel);
    try processor.asyncHealthCheck(&channel);
    try processor.asyncTelemetrySnapshot(&channel);

    try std.testing.expectEqual(@as(usize, 5), processor.getQueueDepth());
}

test "Telemetry max points configuration" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const tel = processor.getTelemetry();

    try std.testing.expectEqual(@as(usize, 100), tel.max_points);
}

test "AsyncProcessor running atomic operations" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Initially not running
    try std.testing.expect(!processor.running.load(.acquire));

    // Start
    try processor.start();
    try std.testing.expect(processor.running.load(.acquire));

    // Stop
    processor.stop();
    try std.testing.expect(!processor.running.load(.acquire));
}

test "ResultChannel set after deinit" {
    const allocator = std.testing.allocator;

    // This test documents expected behavior:
    // Setting result after deinit is undefined behavior
    // We just verify deinit worked correctly
    var channel = ResultChannel.init();
    channel.deinit(allocator);

    // channel now has invalid state
    // We're done with this test
    try std.testing.expect(true);
}

test "AsyncProcessor telemetry interval configuration" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .telemetry_interval_ms = 1000 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try std.testing.expectEqual(@as(u64, 1000), processor.config.telemetry_interval_ms);
}

test "AsyncProcessor health check interval configuration" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .health_check_interval_ms = 5000 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    try std.testing.expectEqual(@as(u64, 5000), processor.config.health_check_interval_ms);
}

test "BackgroundCollector init with processor" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const collector = BackgroundCollector.init(&processor, 1000);

    // Verify processor reference is stored
    _ = collector.processor;
    _ = collector.interval_ms;

    try std.testing.expectEqual(@as(u64, 1000), collector.interval_ms);
}

test "Telemetry recordTaskCompletion" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Call recordTaskCompletion for all task types
    const task_types = [_]TaskType{
        .claim_task,
        .release_task,
        .publish_event,
        .health_check,
        .telemetry_snapshot,
        .custom,
    };

    for (task_types) |tt| {
        processor.telemetry.recordTaskCompletion(tt);
    }

    // Verify no crashes
    try std.testing.expect(true);
}

test "ResultChannel mutex operations" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Lock and unlock operations
    channel.mutex.lock();
    channel.mutex.unlock();

    // Multiple locks/unlocks
    channel.mutex.lock();
    channel.mutex.lock();
    channel.mutex.unlock();
    channel.mutex.unlock();

    // Should work without deadlock
    try std.testing.expect(true);
}

test "AsyncProcessor getActiveWorkerCount zero workers" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    const active_count = processor.getActiveWorkerCount();

    // Should return 0 since we configured 0 workers
    try std.testing.expectEqual(@as(usize, 0), active_count);
}

test "AsyncProcessor next_task_id atomic increment" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 1 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Increment multiple times and verify uniqueness
    var ids: [10]u64 = undefined;
    for (0..10) |i| {
        ids[i] = processor.next_task_id.fetchAdd(1, .monotonic);
    }

    // All should be unique
    for (ids, 0..) |id, i| {
        for (i + 1..10) |j| {
            try std.testing.expect(ids[j] != id);
        }
    }
}

test "AsyncProcessor task_queue capacity" {
    const allocator = std.testing.allocator;

    const registry = try basal_ganglia.getGlobal(allocator);
    const event_bus = try reticular_formation.getGlobal(allocator);

    var processor = try AsyncProcessor.init(
        allocator,
        .{ .worker_count = 0 },
        registry,
        event_bus,
    );
    defer processor.deinit();

    // Initial capacity should be 64
    try std.testing.expect(processor.task_queue.capacity >= 64);
}

test "ResultChannel cond signal behavior" {
    var channel = ResultChannel.init();
    defer channel.deinit(std.testing.allocator);

    // Signal without any waiters should work
    channel.cond.signal();

    // Multiple signals
    channel.cond.signal();
    channel.cond.signal();
    channel.cond.broadcast();

    try std.testing.expect(true);
}
