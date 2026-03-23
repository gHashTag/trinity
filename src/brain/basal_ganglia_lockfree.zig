//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BASAL GANGLIA — v2.0 — Lock-Free Action Selection
//!
//! Sharded HashMap design for lock-free reads and minimal contention writes.
//! Target: > 10k OP/s through horizontal scaling.
//!
//! Design Principles:
//! 1. Sharded HashMap: Partition keys into N shards (default: 16)
//! 2. Each shard has its own RwLock for independent access
//! 3. Read-heavy operations can proceed in parallel across shards
//! 4. Write operations only block their specific shard
//!
//! Expected Performance:
//! - With 16 shards: ~16x reduction in contention
//! - Single-threaded: ~5k OP/s (current baseline)
//! - Multi-threaded: ~50k+ OP/s (theoretical with 16 threads)

const std = @import("std");

const SHARD_COUNT: usize = 16; // Must be power of 2 for fast hash

pub const TaskClaim = struct {
    task_id: []const u8,
    agent_id: []const u8,
    claimed_at: i64,
    ttl_ms: u64,
    status: enum { active, completed, abandoned },
    completed_at: ?i64,
    last_heartbeat: i64,

    pub fn isValid(self: *const TaskClaim) bool {
        if (self.status != .active) return false;
        const now_ms = std.time.timestamp() * 1000;

        // Handle clock skew: if claimed_at is in future, treat as valid
        const age_ms = if (self.claimed_at > now_ms)
            @as(u64, 0)
        else
            @as(u64, @intCast(now_ms - self.claimed_at));

        if (age_ms > self.ttl_ms) return false;

        const heartbeat_age_ms = if (self.last_heartbeat > now_ms)
            @as(u64, 0)
        else
            @as(u64, @intCast(now_ms - self.last_heartbeat));

        if (heartbeat_age_ms > 30000) return false;
        return true;
    }
};

/// A single shard of the HashMap with its own lock
/// This allows concurrent access to different shards
const Shard = struct {
    claims: std.StringHashMap(TaskClaim),
    rwlock: std.Thread.RwLock,

    fn init(allocator: std.mem.Allocator) Shard {
        return Shard{
            .claims = std.StringHashMap(TaskClaim).init(allocator),
            .rwlock = std.Thread.RwLock{},
        };
    }

    fn deinit(self: *Shard) void {
        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.deinit();
    }

    fn count(self: *const Shard) usize {
        return self.claims.count();
    }
};

/// Lock-free (sharded) task claim registry
///
/// Uses sharding to reduce contention:
/// - Keys are hashed to determine which shard they belong to
/// - Each shard has its own RwLock
/// - Operations on different shards can proceed in parallel
///
/// Performance characteristics:
/// - Reads: Lock-free per shard (RwLock.readLock)
/// - Writes: Only block one shard (RwLock.lock)
/// - Contention: Reduced by factor of SHARD_COUNT
pub const Registry = struct {
    shards: [SHARD_COUNT]Shard,
    allocator: std.mem.Allocator,
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

    /// Creates a new sharded task claim registry
    pub fn init(allocator: std.mem.Allocator) Registry {
        var shards: [SHARD_COUNT]Shard = undefined;
        for (&shards, 0..) |*shard, i| {
            shard.* = Shard.init(allocator);
            _ = i;
        }

        return Registry{
            .shards = shards,
            .allocator = allocator,
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

    /// Frees all resources used by the registry
    pub fn deinit(self: *Registry) void {
        for (&self.shards) |*shard| {
            shard.deinit();
        }
    }

    /// Computes which shard a key belongs to
    /// Uses fast hash + bitmask (SHARD_COUNT must be power of 2)
    inline fn getShardIndex(task_id: []const u8) usize {
        const hash = std.hash.Wyhash.hash(0, task_id);
        return hash & (SHARD_COUNT - 1);
    }

    /// Gets the shard for a given task_id
    inline fn getShard(self: *Registry, task_id: []const u8) *Shard {
        const idx = getShardIndex(task_id);
        return &self.shards[idx];
    }

    /// Atomically claims a task for an agent
    ///
    /// Only locks the specific shard for this task_id,
    /// allowing other tasks to be claimed concurrently.
    ///
    /// # Parameters
    ///
    /// - `allocator`: Allocator for storing claimed task IDs and agent IDs
    /// - `task_id`: Unique identifier for the task to claim
    /// - `agent_id`: Unique identifier for the claiming agent
    /// - `ttl_ms`: Time-to-live in milliseconds
    ///
    /// # Returns
    ///
    /// - `true` if task was successfully claimed by this agent
    /// - `false` if task is already claimed by another agent
    ///
    /// # Errors
    ///
    /// Returns `error.OutOfMemory` if allocation fails
    pub fn claim(self: *Registry, allocator: std.mem.Allocator, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool {
        _ = self.stats.claim_attempts.fetchAdd(1, .monotonic);

        const shard = self.getShard(task_id);
        shard.rwlock.lock();
        defer shard.rwlock.unlock();

        const now_ms = std.time.timestamp() * 1000;

        // Check if already claimed and valid
        if (shard.claims.get(task_id)) |existing| {
            if (existing.isValid()) {
                _ = self.stats.claim_conflicts.fetchAdd(1, .monotonic);
                return false; // Already claimed
            }
        }

        // Remove old claim if exists
        if (shard.claims.fetchRemove(task_id)) |old_entry| {
            allocator.free(old_entry.key);
            allocator.free(old_entry.value.task_id);
            allocator.free(old_entry.value.agent_id);
        }

        // Create new claim
        const key_dup = try allocator.dupe(u8, task_id);
        errdefer allocator.free(key_dup);

        const task_id_dup = try allocator.dupe(u8, task_id);
        errdefer allocator.free(task_id_dup);

        const agent_id_dup = try allocator.dupe(u8, agent_id);
        errdefer allocator.free(agent_id_dup);

        const new_claim = TaskClaim{
            .task_id = task_id_dup,
            .agent_id = agent_id_dup,
            .claimed_at = now_ms,
            .ttl_ms = ttl_ms,
            .status = .active,
            .completed_at = null,
            .last_heartbeat = now_ms,
        };

        try shard.claims.put(key_dup, new_claim);
        _ = self.stats.claim_success.fetchAdd(1, .monotonic);
        return true;
    }

    /// Refreshes the heartbeat timestamp for a claimed task
    ///
    /// Only locks the specific shard for this task_id.
    pub fn heartbeat(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.heartbeat_calls.fetchAdd(1, .monotonic);

        const shard = self.getShard(task_id);
        shard.rwlock.lock();
        defer shard.rwlock.unlock();

        if (shard.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.last_heartbeat = std.time.timestamp() * 1000;
                _ = self.stats.heartbeat_success.fetchAdd(1, .monotonic);
                return true;
            }
        }
        return false;
    }

    /// Marks a task as completed
    ///
    /// Only locks the specific shard for this task_id.
    pub fn complete(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.complete_calls.fetchAdd(1, .monotonic);

        const shard = self.getShard(task_id);
        shard.rwlock.lock();
        defer shard.rwlock.unlock();

        if (shard.claims.getEntry(task_id)) |entry| {
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

    /// Abandons a claimed task
    ///
    /// Only locks the specific shard for this task_id.
    pub fn abandon(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        _ = self.stats.abandon_calls.fetchAdd(1, .monotonic);

        const shard = self.getShard(task_id);
        shard.rwlock.lock();
        defer shard.rwlock.unlock();

        if (shard.claims.getEntry(task_id)) |entry| {
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

    /// Clears all task claims from the registry
    ///
    /// Locks all shards sequentially.
    pub fn reset(self: *Registry) void {
        for (&self.shards) |*shard| {
            shard.rwlock.lock();
            var iter = shard.claims.iterator();
            while (iter.next()) |entry| {
                shard.claims.allocator.free(entry.key_ptr.*);
                shard.claims.allocator.free(entry.value_ptr.task_id);
                shard.claims.allocator.free(entry.value_ptr.agent_id);
            }
            shard.claims.clearRetainingCapacity();
            shard.rwlock.unlock();
        }
    }

    /// Gets current statistics for the registry
    ///
    /// Thread-safe; uses atomic counters
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
        // Count active claims (requires read locks on all shards)
        var total_claims: usize = 0;
        for (&self.shards) |*shard| {
            shard.rwlock.lockShared();
            total_claims += shard.count();
            shard.rwlock.unlockShared();
        }

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
            .active_claims = total_claims,
        };
    }

    /// Gets shard distribution stats for monitoring
    pub fn getShardStats(self: *Registry) [SHARD_COUNT]usize {
        var stats: [SHARD_COUNT]usize = undefined;
        for (&self.shards, 0..) |*shard, i| {
            shard.rwlock.lockShared();
            stats[i] = shard.count();
            shard.rwlock.unlockShared();
        }
        return stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL REGISTRY SINGLETON
// ═══════════════════════════════════════════════════════════════════════════════

var global_registry: ?*Registry = null;
var global_allocator: ?std.mem.Allocator = null;
var global_mutex = std.Thread.Mutex{};

/// Gets or creates the global task claim registry
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

/// Resets the global registry
pub fn resetGlobal(allocator: std.mem.Allocator) void {
    _ = allocator;
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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LockFree: basic claim success" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const claimed = try registry.claim(allocator, "task-123", "agent-001", 60000);
    try std.testing.expect(claimed);
}

test "LockFree: duplicate claim fails" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-duplicate";
    _ = try registry.claim(allocator, task_id, "agent-001", 60000);

    const claimed_again = try registry.claim(allocator, task_id, "agent-002", 60000);
    try std.testing.expect(!claimed_again);
}

test "LockFree: heartbeat success" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-heartbeat";
    const agent_id = "agent-heartbeat";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    const heartbeat_ok = registry.heartbeat(task_id, agent_id);
    try std.testing.expect(heartbeat_ok);

    const heartbeat_wrong = registry.heartbeat(task_id, "wrong-agent");
    try std.testing.expect(!heartbeat_wrong);
}

test "LockFree: complete task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-complete";
    const agent_id = "agent-complete";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    const completed = registry.complete(task_id, agent_id);
    try std.testing.expect(completed);

    const completed_again = registry.complete(task_id, agent_id);
    try std.testing.expect(!completed_again);
}

test "LockFree: abandon task" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-abandon";
    const agent_id = "agent-abandon";

    _ = try registry.claim(allocator, task_id, agent_id, 60000);

    const abandoned = registry.abandon(task_id, agent_id);
    try std.testing.expect(abandoned);

    const abandoned_again = registry.abandon(task_id, agent_id);
    try std.testing.expect(!abandoned_again);
}

test "LockFree: re-claim after completion" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const task_id = "task-reclaim";
    const agent1 = "agent-001";
    const agent2 = "agent-002";

    _ = try registry.claim(allocator, task_id, agent1, 60000);
    try std.testing.expect(registry.complete(task_id, agent1));

    const claimed = try registry.claim(allocator, task_id, agent2, 60000);
    try std.testing.expect(claimed);
}

test "LockFree: reset clears all" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    for (0..10) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
    }

    const stats = registry.getStats();
    try std.testing.expectEqual(@as(usize, 10), stats.active_claims);

    registry.reset();

    const stats_after = registry.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats_after.active_claims);
}

test "LockFree: shard distribution" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    // Add many tasks - should distribute across shards
    for (0..100) |i| {
        const task_id = try std.fmt.allocPrint(allocator, "task-{d}", .{i});
        defer allocator.free(task_id);
        _ = try registry.claim(allocator, task_id, "agent-001", 60000);
    }

    const shard_stats = registry.getShardStats();
    var total: usize = 0;
    for (shard_stats) |count| {
        total += count;
    }
    try std.testing.expectEqual(@as(usize, 100), total);

    // Check distribution is roughly even (no shard should be empty with 100 tasks)
    for (shard_stats) |count| {
        try std.testing.expect(count > 0);
    }
}

test "LockFree: concurrent shard access" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    // Tasks that hash to different shards can be claimed concurrently
    // (in single-threaded test, we just verify they go to different shards)
    const task1 = "task-000";
    const task2 = "task-001";

    _ = try registry.claim(allocator, task1, "agent-001", 60000);
    _ = try registry.claim(allocator, task2, "agent-002", 60000);

    const shard_stats = registry.getShardStats();
    var shards_with_claims: usize = 0;
    for (shard_stats) |count| {
        if (count > 0) shards_with_claims += 1;
    }

    // Should have at least 2 shards with claims
    try std.testing.expect(shards_with_claims >= 2);
}

test "LockFree: claim throughput benchmark" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const iterations = 100_000;
    var task_buf: [32]u8 = undefined;

    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});
        _ = try registry.claim(allocator, task_id, "agent-001", 300000);
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("LockFree Sharded Basal Ganglia: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "LockFree: heartbeat throughput benchmark" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    const iterations = 100_000;
    var task_buf: [32]u8 = undefined;

    // Pre-populate
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});
        _ = try registry.claim(allocator, task_id, "agent-001", 300000);
    }

    // Benchmark heartbeat
    i = 0;
    const start = std.time.nanoTimestamp();
    while (i < iterations) : (i += 1) {
        const task_id = try std.fmt.bufPrintZ(&task_buf, "task-{d}", .{i});
        _ = registry.heartbeat(task_id, "agent-001");
    }
    const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start));
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed_ns));
    _ = std.debug.print("LockFree Sharded Basal Ganglia Heartbeat: {d:.0} OP/s ({d:.2} ns/op)\n", .{ ops_per_sec * 1_000_000_000.0, @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) });
}

test "LockFree: matches baseline behavior" {
    const allocator = std.testing.allocator;
    var registry_lf = Registry.init(allocator);
    defer registry_lf.deinit();

    const baseline = @import("basal_ganglia.zig");
    var registry_base = baseline.Registry.init(allocator);
    defer registry_base.deinit();

    const task_id = "task-compare";
    const agent_id = "agent-compare";

    const claimed_lf = try registry_lf.claim(allocator, task_id, agent_id, 60000);
    const claimed_base = try registry_base.claim(allocator, task_id, agent_id, 60000);
    try std.testing.expectEqual(claimed_base, claimed_lf);

    const dup_lf = try registry_lf.claim(allocator, task_id, "agent-002", 60000);
    const dup_base = try registry_base.claim(allocator, task_id, "agent-002", 60000);
    try std.testing.expectEqual(dup_base, dup_lf);
}
