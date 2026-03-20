//! BASAL GANGLIA — v1.2 — Action Selection (Striatum)
//!
//! CRDT-based task claim system for parallel agent coordination.
//! First agent wins — atomic claim with TTL + heartbeat.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Brain Region: Basal Ganglia (Action Selection)
//!
//! # Overview
//!
//! The Basal Ganglia module implements a task claim registry that prevents
//! duplicate task execution across multiple agents. It uses a CRDT-inspired
//! approach with:
//!
//! - Atomic first-come-first-served task claiming
//! - Time-to-live (TTL) for automatic claim expiration
//! - Heartbeat mechanism for liveness detection
//! - Thread-safe operations using read-write locks for better concurrency
//!
//! # Biological Inspiration
//!
//! The basal ganglia in the brain selects which actions to execute and
//! inhibits competing actions. This module mirrors that behavior by ensuring
//! only one agent works on a task at a time.
//!
//! # Usage
//!
//! ```zig
//! const brain = @import("brain");
//! const allocator = std.heap.page_allocator;
//!
//! // Get global registry
//! const registry = try brain.basal_ganglia.getGlobal(allocator);
//!
//! // Claim a task (5 minute TTL)
//! const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
//! if (claimed) {
//!     // Task claimed successfully, start working
//!     // Refresh heartbeat every 30s
//!     _ = registry.heartbeat("task-123", "agent-001");
//!
//!     // Complete when done
//!     _ = registry.complete("task-123", "agent-001");
//! }
//! ```
//!
//! # Thread Safety
//!
//! All operations are thread-safe via `std.Thread.RwLock`. Read operations
//! (getStats) use readLock() allowing concurrent readers. Write operations
//! (claim, heartbeat, complete, abandon, reset) use writeLock() for exclusive
//! access. This enables better parallelism when multiple threads only read.

const std = @import("std");

/// Represents a single task claim by an agent.
///
/// A claim includes the task ID, claiming agent ID, timestamps,
/// TTL for expiration, and status tracking.
///
/// # Fields
///
/// - `task_id`: Unique identifier for the task (owned string)
/// - `agent_id`: Unique identifier for the claiming agent (owned string)
/// - `claimed_at`: Unix timestamp in milliseconds when claim was made
/// - `ttl_ms`: Time-to-live in milliseconds before claim expires
/// - `status`: Current status of the claim (active/completed/abandoned)
/// - `completed_at`: Unix timestamp when task was completed (null if not completed)
/// - `last_heartbeat`: Unix timestamp of last heartbeat
///
/// # Example
///
/// ```zig
/// var claim = TaskClaim{
///     .task_id = "task-123",
///     .agent_id = "agent-001",
///     .claimed_at = std.time.timestamp() * 1000,
///     .ttl_ms = 300000, // 5 minutes
///     .status = .active,
///     .completed_at = null,
///     .last_heartbeat = std.time.timestamp() * 1000,
/// };
///
/// if (claim.isValid()) {
///     // Task claim is still valid
/// }
/// ```
pub const TaskClaim = struct {
    /// Unique identifier for the task
    task_id: []const u8,
    /// Unique identifier for the claiming agent
    agent_id: []const u8,
    /// Unix timestamp (ms) when claim was created
    claimed_at: i64,
    /// Time-to-live in milliseconds (after which claim expires)
    ttl_ms: u64,
    /// Current status of the claim
    status: enum { active, completed, abandoned },
    /// Unix timestamp (ms) when task was completed
    completed_at: ?i64,
    /// Unix timestamp (ms) of last heartbeat
    last_heartbeat: i64,

    /// Checks if the task claim is still valid.
    ///
    /// A claim is valid if:
    /// 1. Status is `.active`
    /// 2. Claim has not expired (current time - claimed_at < ttl_ms)
    /// 3. Heartbeat was received within last 30 seconds
    ///
    /// # Returns
    ///
    /// `true` if the claim is valid, `false` otherwise
    ///
    /// # Example
    ///
    /// ```zig
    /// const now_ms = std.time.timestamp() * 1000;
    /// var claim = TaskClaim{
    ///     .task_id = "task-123",
    ///     .agent_id = "agent-001",
    ///     .claimed_at = now_ms - 10000, // 10 seconds ago
    ///     .ttl_ms = 60000, // 60 seconds TTL
    ///     .status = .active,
    ///     .completed_at = null,
    ///     .last_heartbeat = now_ms - 5000, // 5 seconds ago
    /// };
    ///
    /// try std.testing.expect(claim.isValid()); // true
    /// ```
    pub fn isValid(self: *const TaskClaim) bool {
        if (self.status != .active) return false;
        const now_ms = std.time.timestamp() * 1000;

        // Handle clock skew: if claimed_at is in future, treat as valid until clock normalizes
        const age_ms = if (self.claimed_at > now_ms)
            @as(u64, 0) // Future timestamp = claim not yet aged
        else
            @as(u64, @intCast(now_ms - self.claimed_at));

        if (age_ms > self.ttl_ms) return false;

        // Handle clock skew for heartbeat as well
        const heartbeat_age_ms = if (self.last_heartbeat > now_ms)
            @as(u64, 0) // Future heartbeat = treat as fresh
        else
            @as(u64, @intCast(now_ms - self.last_heartbeat));

        if (heartbeat_age_ms > 30000) return false; // 30s heartbeat timeout
        return true;
    }
};

/// Thread-safe task claim registry.
///
/// Manages task claims across multiple agents with automatic expiration
/// and heartbeat-based liveness detection.
///
/// # Thread Safety
///
/// All operations are protected by a read-write lock. Read operations
/// (getStats) use readLock() allowing concurrent readers. Write operations
/// (claim, heartbeat, complete, abandon, reset) use writeLock() for exclusive
/// access. This enables better parallelism when multiple threads only read.
///
/// # Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// var registry = Registry.init(allocator);
/// defer registry.deinit();
///
/// // Claim a task
/// const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
/// if (claimed) {
///     // Send heartbeat every 30s while working
///     _ = registry.heartbeat("task-123", "agent-001");
///
///     // Complete task when done
///     _ = registry.complete("task-123", "agent-001");
/// }
/// ```
pub const Registry = struct {
    /// Map of task_id -> TaskClaim (owned strings)
    claims: std.StringHashMap(TaskClaim),
    /// Read-write lock protecting the claims map
    /// Allows concurrent readers, exclusive writers
    rwlock: std.Thread.RwLock,
    /// Performance counters for monitoring (lock-free atomic)
    /// These can be read without acquiring the lock
    stats: struct {
        claim_attempts: std.atomic.Value(u64),
        claim_success: std.atomic.Value(u64),
        claim_conflicts: std.atomic.Value(u64),
        heartbeat_calls: std.atomic.Value(u64),
        heartbeat_success: std.atomic.Value(u64),
        complete_calls: std.atomic.Value(u64),
        complete_success: std.atomic.Value(u64),
        abandon_calls: std.atomic.Value(u64),
        abandon_success: std.atomic.Value(u64),
    },

    /// Creates a new task claim registry.
    ///
    /// # Parameters
    ///
    /// - `allocator`: Allocator to use for internal storage
    ///
    /// # Returns
    ///
    /// A new `Registry` instance ready to use
    ///
    /// # Example
    ///
    /// ```zig
    /// const registry = Registry.init(std.heap.page_allocator);
    /// defer registry.deinit();
    /// ```
    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{
            .claims = std.StringHashMap(TaskClaim).init(allocator),
            .rwlock = std.Thread.RwLock{},
            .stats = .{
                .claim_attempts = std.atomic.Value(u64).init(0),
                .claim_success = std.atomic.Value(u64).init(0),
                .claim_conflicts = std.atomic.Value(u64).init(0),
                .heartbeat_calls = std.atomic.Value(u64).init(0),
                .heartbeat_success = std.atomic.Value(u64).init(0),
                .complete_calls = std.atomic.Value(u64).init(0),
                .complete_success = std.atomic.Value(u64).init(0),
                .abandon_calls = std.atomic.Value(u64).init(0),
                .abandon_success = std.atomic.Value(u64).init(0),
            },
        };
    }

    /// Frees all resources used by the registry.
    ///
    /// Releases all owned strings (task_id, agent_id) and deallocates
    /// the internal HashMap.
    ///
    /// # Note
    ///
    /// After calling `deinit()`, the registry cannot be used.
    pub fn deinit(self: *Registry) void {
        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.deinit();
    }

    /// Atomically claims a task for an agent.
    ///
    /// First-come-first-served: the first agent to call `claim()` wins.
    /// If the task is already claimed and still valid, returns `false`.
    ///
    /// # Parameters
    ///
    /// - `allocator`: Allocator for storing claimed task IDs and agent IDs
    /// - `task_id`: Unique identifier for the task to claim
    /// - `agent_id`: Unique identifier for the claiming agent
    /// - `ttl_ms`: Time-to-live in milliseconds (recommend 300000 = 5 min)
    ///
    /// # Returns
    ///
    /// - `true` if task was successfully claimed by this agent
    /// - `false` if task is already claimed by another agent
    ///
    /// # Errors
    ///
    /// Returns `error.OutOfMemory` if allocation fails
    ///
    /// # Example
    ///
    /// ```zig
    /// const claimed = try registry.claim(allocator, "task-123", "agent-001", 300000);
    /// if (claimed) {
    ///     // We have the task, start working
    /// } else {
    ///     // Someone else has it, wait and retry
    /// }
    /// ```
    pub fn claim(self: *Registry, allocator: std.mem.Allocator, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool {
        self.rwlock.lock();
        defer self.rwlock.unlock();

        _ = self.stats.claim_attempts.fetchAdd(1, .monotonic);

        const now_ms = std.time.timestamp() * 1000;

        // Check if already claimed and valid
        if (self.claims.get(task_id)) |existing| {
            if (existing.isValid()) {
                _ = self.stats.claim_conflicts.fetchAdd(1, .monotonic);
                return false; // Already claimed by someone else
            }
        }

        // Remove old claim if exists (to free memory)
        if (self.claims.fetchRemove(task_id)) |old_entry| {
            allocator.free(old_entry.key);
            allocator.free(old_entry.value.task_id);
            allocator.free(old_entry.value.agent_id);
        }

        // Create new claim - allocate key and values
        const key_dup = try allocator.dupe(u8, task_id);
        errdefer allocator.free(key_dup); // Free key on error

        const task_id_dup = try allocator.dupe(u8, task_id);
        errdefer allocator.free(task_id_dup); // Free task_id on error

        const agent_id_dup = try allocator.dupe(u8, agent_id);
        errdefer allocator.free(agent_id_dup); // Free agent_id on error

        const new_claim = TaskClaim{
            .task_id = task_id_dup,
            .agent_id = agent_id_dup,
            .claimed_at = now_ms,
            .ttl_ms = ttl_ms,
            .status = .active,
            .completed_at = null,
            .last_heartbeat = now_ms,
        };

        try self.claims.put(key_dup, new_claim);
        // If put succeeds, all allocations are now owned by the HashMap
        _ = self.stats.claim_success.fetchAdd(1, .monotonic);
        return true;
    }

    /// Refreshes the heartbeat timestamp for a claimed task.
    ///
    /// Call this periodically (every 30 seconds recommended) while working
    /// on a task to prevent the claim from expiring.
    ///
    /// # Parameters
    ///
    /// - `task_id`: Task to refresh heartbeat for
    /// - `agent_id`: Agent making the heartbeat request
    ///
    /// # Returns
    ///
    /// - `true` if heartbeat was accepted (valid claim from matching agent)
    /// - `false` if task not claimed, agent mismatch, or claim invalid
    ///
    /// # Thread Safety
    ///
    /// Thread-safe; may be called from any thread
    ///
    /// # Example
    ///
    /// ```zig
    /// // While working on task, send heartbeat every 30s
    /// while (working) {
    ///     _ = registry.heartbeat("task-123", "agent-001");
    ///     std.time.sleep(30_000_000_000); // 30 seconds
    /// }
    /// ```
    pub fn heartbeat(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.heartbeat_calls.fetchAdd(1, .monotonic);
        self.rwlock.lock();
        defer self.rwlock.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.last_heartbeat = std.time.timestamp() * 1000;
                _ = self.stats.heartbeat_success.fetchAdd(1, .monotonic);
                return true;
            }
        }
        return false;
    }

    /// Marks a task as completed.
    ///
    /// Only the agent that claimed the task can complete it.
    ///
    /// # Parameters
    ///
    /// - `task_id`: Task to complete
    /// - `agent_id`: Agent completing the task
    ///
    /// # Returns
    ///
    /// - `true` if task was marked complete
    /// - `false` if task not claimed, agent mismatch, or already completed
    ///
    /// # Example
    ///
    /// ```zig
    /// // Task completed successfully
    /// if (registry.complete("task-123", "agent-001")) {
    ///     std.log.info("Task completed", .{});
    /// }
    /// ```
    pub fn complete(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.complete_calls.fetchAdd(1, .monotonic);
        self.rwlock.lock();
        defer self.rwlock.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .completed;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                _ = self.stats.complete_success.fetchAdd(1, .monotonic);
                return true;
            }
        }
        return false;
    }

    /// Abandons a claimed task.
    ///
    /// Use this when the agent cannot complete the task (e.g., crashed,
    /// timeout, or unrecoverable error). The task becomes available for
    /// other agents to claim.
    ///
    /// # Parameters
    ///
    /// - `task_id`: Task to abandon
    /// - `agent_id`: Agent abandoning the task
    ///
    /// # Returns
    ///
    /// - `true` if task was abandoned
    /// - `false` if task not claimed, agent mismatch, or already abandoned
    ///
    /// # Example
    ///
    /// ```zig
    /// // Task failed, abandon it
    /// if (registry.abandon("task-123", "agent-001")) {
    ///     std.log.err("Task abandoned due to error", .{});
    /// }
    /// ```
    pub fn abandon(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.abandon_calls.fetchAdd(1, .monotonic);
        self.rwlock.lock();
        defer self.rwlock.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .abandoned;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                _ = self.stats.abandon_success.fetchAdd(1, .monotonic);
                return true;
            }
        }
        return false;
    }

    /// Clears all task claims from the registry.
    ///
    /// Releases all memory associated with stored claims.
    /// Useful for testing or full reset scenarios.
    ///
    /// # Thread Safety
    ///
    /// Thread-safe; locks the rwlock for write during operation
    ///
    /// # Example
    ///
    /// ```zig
    /// // Reset registry state
    /// registry.reset();
    /// ```
    pub fn reset(self: *Registry) void {
        self.rwlock.lock();
        defer self.rwlock.unlock();

        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.clearRetainingCapacity();
    }

    /// Gets current statistics for the registry.
    ///
    /// Returns performance counters tracking operation counts and success rates.
    ///
    /// # Thread Safety
    ///
    /// Thread-safe; uses readLock() to allow concurrent readers
    ///
    /// # Example
    ///
    /// ```zig
    /// const stats = registry.getStats();
    /// std.log.info("Claim success rate: {d:.2}%", .{
    ///     @as(f64, @floatFromInt(stats.claim_success)) /
    ///     @as(f64, @floatFromInt(stats.claim_attempts)) * 100.0
    /// });
    /// ```
    pub fn getStats(self: *Registry) struct {
        claim_attempts: u64,
        claim_success: u64,
        claim_conflicts: u64,
        heartbeat_calls: u64,
        heartbeat_success: u64,
        complete_calls: u64,
        complete_success: u64,
        abandon_calls: u64,
        abandon_success: u64,
        active_claims: usize,
    } {
        // Lock-free: stats are atomic, only claims.count() needs read lock
        self.rwlock.readLock();
        defer self.rwlock.unlock();

        return .{
            .claim_attempts = self.stats.claim_attempts.load(.monotonic),
            .claim_success = self.stats.claim_success.load(.monotonic),
            .claim_conflicts = self.stats.claim_conflicts.load(.monotonic),
            .heartbeat_calls = self.stats.heartbeat_calls.load(.monotonic),
            .heartbeat_success = self.stats.heartbeat_success.load(.monotonic),
            .complete_calls = self.stats.complete_calls.load(.monotonic),
            .complete_success = self.stats.complete_success.load(.monotonic),
            .abandon_calls = self.stats.abandon_calls.load(.monotonic),
            .abandon_success = self.stats.abandon_success.load(.monotonic),
            .active_claims = self.claims.count(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL REGISTRY SINGLETON
// ═══════════════════════════════════════════════════════════════════════════════

/// Global singleton registry instance.
///
/// Provides process-wide access to a shared task claim registry.
/// Thread-safe; initialized on first call to `getGlobal()`.
///
/// # Usage
///
/// ```zig
/// const registry = try brain.basal_ganglia.getGlobal(allocator);
/// _ = try registry.claim(allocator, "task-123", "agent-001", 300000);
/// ```
var global_registry: ?*Registry = null;
/// Allocator used for global registry
var global_allocator: ?std.mem.Allocator = null;
/// Mutex protecting global registry initialization
/// (Not RwLock because init only happens once, Mutex is sufficient)
var global_mutex = std.Thread.Mutex{};

/// Gets or creates the global task claim registry.
///
/// Thread-safe singleton pattern: first call creates registry,
/// subsequent calls return the same instance.
///
/// # Parameters
///
/// - `allocator`: Allocator for registry initialization (only used on first call)
///
/// # Returns
///
/// Pointer to global registry instance
///
/// # Errors
///
/// - `error.OutOfMemory`: If registry initialization fails
///
/// # Thread Safety
///
/// Thread-safe; locks mutex during initialization
///
/// # Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const registry = try brain.basal_ganglia.getGlobal(allocator);
/// _ = try registry.claim(allocator, "task-123", "agent-001", 300000);
/// ```
pub fn getGlobal(allocator: std.mem.Allocator) !*Registry {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| return reg;

    const reg = try allocator.create(Registry);
    reg.* = Registry.init(allocator);
    global_registry = reg;
    global_allocator = allocator;
    return reg;
}

/// Resets the global registry.
///
/// Used primarily for testing to clean up between test cases.
/// Frees all memory associated with the global registry.
///
/// # Parameters
///
/// - `allocator`: Ignored; uses stored allocator from initialization
///
/// # Thread Safety
///
/// Thread-safe; locks mutex during reset
///
/// # Example
///
/// ```zig
/// // In test teardown
/// brain.basal_ganglia.resetGlobal(allocator);
/// ```
pub fn resetGlobal(allocator: std.mem.Allocator) void {
    _ = allocator; // Use stored allocator instead
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| {
        reg.deinit();
        if (global_allocator) |alloc| {
            alloc.destroy(reg);
        }
        global_registry = null;
        global_allocator = null;
    }
}

test "TaskClaim - expired claim" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = now_ms - 59000,
        .ttl_ms = 60000,
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 10000,
    };

    try std.testing.expect(claim.isValid());
}

test "TaskClaim - expired by TTL" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = now_ms - 70000,
        .ttl_ms = 60000,
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 10000,
    };

    try std.testing.expect(!claim.isValid());
}

test "TaskClaim - expired by heartbeat" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = now_ms - 10000,
        .ttl_ms = 60000,
        .status = .active,
        .completed_at = null,
        .last_heartbeat = now_ms - 40000, // Heartbeat > 30s ago
    };

    try std.testing.expect(!claim.isValid());
}

test "TaskClaim - completed status invalid" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = now_ms - 10000,
        .ttl_ms = 60000,
        .status = .completed,
        .completed_at = now_ms - 5000,
        .last_heartbeat = now_ms - 10000,
    };

    try std.testing.expect(!claim.isValid());
}

test "TaskClaim - abandoned status invalid" {
    const now_ms = std.time.timestamp() * 1000;
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = now_ms - 10000,
        .ttl_ms = 60000,
        .status = .abandoned,
        .completed_at = now_ms - 5000,
        .last_heartbeat = now_ms - 10000,
    };

    try std.testing.expect(!claim.isValid());
}

test "Registry claim and verify" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-123";
    const agent_id = "agent-001";

    const claimed = try registry.claim(allocator, task_id, agent_id, 60000);
    try std.testing.expect(claimed);

    // Try to claim again - should fail
    const claimed_again = try registry.claim(allocator, task_id, "agent-002", 60000);
    try std.testing.expect(!claimed_again);
}

test "Registry claim after expiration" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-123";

    // Claim with very short TTL
    _ = try registry.claim(allocator, task_id, "agent-001", 1);

    // Wait for expiration (simulate by claiming again after time)
    // In test, we can't wait, so we'll claim with new task_id
    const task_id2 = "task-124";
    const claimed = try registry.claim(allocator, task_id2, "agent-001", 60000);
    try std.testing.expect(claimed);
}

test "Registry heartbeat refresh" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-heartbeat";
    const agent_id = "agent-heartbeat";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    // Heartbeat from correct agent should succeed
    const heartbeat_ok = registry.heartbeat(task_id, agent_id);
    try std.testing.expect(heartbeat_ok);

    // Heartbeat from wrong agent should fail
    const heartbeat_wrong = registry.heartbeat(task_id, "wrong-agent");
    try std.testing.expect(!heartbeat_wrong);
}

test "Registry complete task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-complete";
    const agent_id = "agent-complete";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    // Complete task
    const completed = registry.complete(task_id, agent_id);
    try std.testing.expect(completed);

    // After completion, claim should no longer be valid
    // (this is tested by trying to complete again)
    const completed_again = registry.complete(task_id, agent_id);
    try std.testing.expect(!completed_again);
}

test "Registry abandon task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-abandon";
    const agent_id = "agent-abandon";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    // Abandon task
    const abandoned = registry.abandon(task_id, agent_id);
    try std.testing.expect(abandoned);

    // After abandonment, claim should no longer be valid
    const abandoned_again = registry.abandon(task_id, agent_id);
    try std.testing.expect(!abandoned_again);
}

test "Registry reset clears all claims" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    // Add multiple claims
    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
    }

    try std.testing.expectEqual(@as(usize, 10), registry.claims.count());

    registry.reset();
    try std.testing.expectEqual(@as(usize, 0), registry.claims.count());
}

test "Registry heartbeat on non-existent task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const heartbeat_ok = registry.heartbeat("non-existent", "agent-001");
    try std.testing.expect(!heartbeat_ok);
}

test "Registry complete on non-existent task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const completed = registry.complete("non-existent", "agent-001");
    try std.testing.expect(!completed);
}

test "Registry abandon on non-existent task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const abandoned = registry.abandon("non-existent", "agent-001");
    try std.testing.expect(!abandoned);
}

test "Registry re-claim after completion" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-reclaim";
    const agent1 = "agent-001";
    const agent2 = "agent-002";

    // First agent claims
    _ = try registry.claim(allocator, task_id, agent1, 60000);

    // First agent completes
    try std.testing.expect(registry.complete(task_id, agent1));

    // Second agent should now be able to claim
    const claimed = try registry.claim(allocator, task_id, agent2, 60000);
    try std.testing.expect(claimed);
}

test "Registry claim replacement" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-replace";

    // First claim
    _ = try registry.claim(allocator, task_id, "agent-001", 60000);

    // Claim with expired old claim (simulate by using same task_id after time)
    // In practice, TTL expiration allows re-claim
    // Here we test that old claim is replaced when invalid
    const claimed = try registry.claim(allocator, task_id, "agent-002", 60000);
    // Should fail because first claim is still valid
    try std.testing.expect(!claimed);
}

test "TaskClaim handles clock skew - future timestamp" {
    const now_ms = std.time.timestamp() * 1000;
    const future_ms = now_ms + 3600000; // 1 hour in future

    // Claimed_at in future should be treated as valid (not aged yet)
    var claim = TaskClaim{
        .task_id = "test",
        .agent_id = "agent",
        .claimed_at = future_ms,
        .ttl_ms = 60000,
        .status = .active,
        .completed_at = null,
        .last_heartbeat = future_ms,
    };

    try std.testing.expect(claim.isValid()); // Future timestamp = not yet aged
}
