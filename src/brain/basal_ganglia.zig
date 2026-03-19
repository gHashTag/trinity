//! BASAL GANGLIA — v1.1 — Action Selection (Striatum)
//!
//! CRDT-based task claim system for parallel agent coordination.
//! First agent wins — atomic claim with TTL + heartbeat.
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//! Brain Region: Basal Ganglia (Action Selection)

const std = @import("std");

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
        const age_ms = @as(u64, @intCast(now_ms - self.claimed_at));
        if (age_ms > self.ttl_ms) return false;
        const heartbeat_age_ms = @as(u64, @intCast(now_ms - self.last_heartbeat));
        if (heartbeat_age_ms > 30000) return false; // 30s heartbeat timeout
        return true;
    }
};

pub const Registry = struct {
    claims: std.StringHashMap(TaskClaim),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{
            .claims = std.StringHashMap(TaskClaim).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Registry) void {
        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.deinit();
    }

    pub fn claim(self: *Registry, allocator: std.mem.Allocator, task_id: []const u8, agent_id: []const u8, ttl_ms: u64) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now_ms = std.time.timestamp() * 1000;

        // Check if already claimed and valid
        if (self.claims.get(task_id)) |existing| {
            if (existing.isValid()) {
                return false; // Already claimed by someone else
            }
        }

        // Create new claim
        const new_claim = TaskClaim{
            .task_id = try allocator.dupe(u8, task_id),
            .agent_id = try allocator.dupe(u8, agent_id),
            .claimed_at = now_ms,
            .ttl_ms = ttl_ms,
            .status = .active,
            .completed_at = null,
            .last_heartbeat = now_ms,
        };

        try self.claims.put(try allocator.dupe(u8, task_id), new_claim);
        return true;
    }

    pub fn heartbeat(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.last_heartbeat = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn complete(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .completed;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn abandon(self: *Registry, task_id: []const u8, agent_id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.claims.getEntry(task_id)) |entry| {
            const entry_claim = &entry.value_ptr.*;
            if (std.mem.eql(u8, entry_claim.agent_id, agent_id) and entry_claim.isValid()) {
                entry_claim.status = .abandoned;
                entry_claim.completed_at = std.time.timestamp() * 1000;
                return true;
            }
        }
        return false;
    }

    pub fn reset(self: *Registry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.claims.iterator();
        while (iter.next()) |entry| {
            self.claims.allocator.free(entry.key_ptr.*);
            self.claims.allocator.free(entry.value_ptr.task_id);
            self.claims.allocator.free(entry.value_ptr.agent_id);
        }
        self.claims.clearRetainingCapacity();
    }
};

// Global singleton
var global_registry: ?*Registry = null;
var global_mutex = std.Thread.Mutex{};

pub fn getGlobal(allocator: std.mem.Allocator) !*Registry {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_registry) |reg| return reg;

    const reg = try allocator.create(Registry);
    reg.* = Registry.init(allocator);
    global_registry = reg;
    return reg;
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
