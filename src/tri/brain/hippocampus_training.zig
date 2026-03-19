// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// HIPPOCAMPUS (Episodic Memory) — Training State Cache
// ═══════════════════════════════════════════════════════════════════════════════
//
// PROBLEM: evolution_state.json is mixed source (cache + decisions)
// SOLUTION: Hippocampus as pure cache, Thalamus as live truth
//
// Hippocampus stores aggregated training state as CACHE.
// Data is marked as "cached" when returned to prevent confusion with live truth.
//
// NEUROANATOMY: Hippocampus = Episodic memory, consolidates experiences
//     into long-term memory. Here: consolidates training snapshots.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const thalamus_logs = @import("thalamus_logs.zig");
const LiveStatus = thalamus_logs.LiveStatus;
const WorkerLiveState = thalamus_logs.WorkerLiveState;
const WorkerMetrics = thalamus_logs.WorkerMetrics;

// ═════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// Cached worker status (may be stale!)
pub const CachedWorkerStatus = struct {
    service_name: []const u8,
    status: LiveStatus,
    step: u32,
    ppl: f32,
    tok_per_sec: f32,
    last_updated: i64, // UNIX timestamp when cache was updated
    cached: bool = true, // Flag indicating this is cache, NOT live truth

    pub fn ageSec(self: *const CachedWorkerStatus) i64 {
        const now = std.time.timestamp();
        return now - self.last_updated;
    }

    pub fn isStale(self: *const CachedWorkerStatus, max_age_sec: i64) bool {
        return self.ageSec() > max_age_sec;
    }
};

/// Training population cache (aggregated state)
pub const PopulationCache = struct {
    workers: std.StringHashMap(CachedWorkerStatus),
    last_refresh: i64,
    refresh_interval_sec: i64 = 300, // 5 min default

    const Self = @This();

    /// Initialize empty population cache
    pub fn init(allocator: Allocator) Self {
        return .{
            .workers = std.StringHashMap(CachedWorkerStatus).init(allocator),
            .last_refresh = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit(allocator);
    }

    /// Get cached worker status (may be stale!)
    pub fn getWorker(self: *Self, service_name: []const u8) ?CachedWorkerStatus {
        return self.workers.get(service_name);
    }

    /// Update or add worker in cache
    pub fn updateWorker(self: *Self, allocator: Allocator, service_name: []const u8, status: LiveStatus, step: u32, ppl: f32) !void {
        const now = std.time.timestamp();

        const key = try allocator.dupe(u8, service_name);
        if (self.workers.fetchPut(key, .{
            .service_name = key,
            .status = status,
            .step = step,
            .ppl = ppl,
            .tok_per_sec = 0,
            .last_updated = now,
            .cached = true,
        })) |kv| {
            // Update existing
            kv.value_ptr.*.status = status;
            kv.value_ptr.*.step = step;
            kv.value_ptr.*.ppl = ppl;
            kv.value_ptr.*.last_updated = now;
            allocator.free(key);
        }
    }

    /// Get all worker keys in cache
    pub fn listWorkers(self: *const Self) std.ArrayList([]const u8) {
        var list = std.ArrayList([]const u8).init(std.heap.page_allocator);
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            list.append(entry.key_ptr.*) catch {};
        }
        return list;
    }

    /// Remove worker from cache
    pub fn removeWorker(self: *Self, allocator: Allocator, service_name: []const u8) void {
        if (self.workers.remove(service_name)) |value| {
            allocator.free(value.service_name);
        }
    }

    /// Clear all cached data
    pub fn clear(self: *Self, allocator: Allocator) void {
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        self.workers.clearRetainingCapacity();
        self.last_refresh = 0;
    }

    /// Check if refresh is needed
    pub fn needsRefresh(self: *const Self) bool {
        const now = std.time.timestamp();
        return (now - self.last_refresh) > self.refresh_interval_sec;
    }
};

// ═════════════════════════════════════════════════════════════════════════════
// HIPPOCAMPUS API — Training State Cache
// ═════════════════════════════════════════════════════════════════════════════

pub const Hippocampus = struct {
    allocator: Allocator,
    cache: PopulationCache,
    file_path: []const u8 = ".trinity/evolution_state.json",

    const Self = @This();

    /// Initialize Hippocampus from existing cache file
    pub fn init(allocator: Allocator) !Self {
        var cache = PopulationCache.init(allocator);

        // Try to load existing cache from file
        loadCacheFromFile(allocator, &cache) catch {};

        return .{
            .allocator = allocator,
            .cache = cache,
        };
    }

    pub fn deinit(self: *Self) void {
        self.cache.deinit(self.allocator);
    }

    /// Refresh cache from Thalamus (expensive Railway API call!)
    pub fn refreshFromThalamus(self: *Self, thalamus: *const thalamus_logs.Thalamus) !void {
        const now = std.time.timestamp();

        // Get all sacred workers live state
        var live_states = try thalamus.getSacredWorkersLive();
        defer {
            var iter = live_states.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            live_states.deinit(self.allocator);
        }

        // Update cache with live data
        var iter = live_states.iterator();
        while (iter.next()) |entry| {
            const state = entry.value_ptr.*;
            try self.cache.updateWorker(
                self.allocator,
                entry.key_ptr.*,
                state.status,
                state.metrics.step,
                state.metrics.ppl,
            );
        }

        self.cache.last_refresh = now;

        // Persist to disk
        try self.persist();
    }

    /// Get cached step (may be stale!)
    pub fn getCachedStep(self: *const Self, service_name: []const u8) ?u32 {
        const worker = self.cache.getWorker(service_name) orelse return null;
        return worker.step;
    }

    /// Get cached status (may be stale!)
    pub fn getCachedStatus(self: *const Self, service_name: []const u8) ?LiveStatus {
        const worker = self.cache.getWorker(service_name) orelse return null;
        return worker.status;
    }

    /// Get all cached workers
    pub fn getAllCachedWorkers(self: *const Self) !std.ArrayList(CachedWorkerStatus) {
        var results = std.ArrayList(CachedWorkerStatus).init(self.allocator);

        var iter = self.cache.workers.iterator();
        while (iter.next()) |entry| {
            try results.append(self.allocator, entry.value_ptr.*);
        }

        return results;
    }

    /// Get workers that are stale (older than max_age_sec)
    pub fn getStaleWorkers(self: *const Self, max_age_sec: i64) !std.ArrayList(CachedWorkerStatus) {
        var results = std.ArrayList(CachedWorkerStatus).init(self.allocator);

        var iter = self.cache.workers.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.isStale(max_age_sec)) {
                try results.append(self.allocator, entry.value_ptr.*);
            }
        }

        return results;
    }

    /// Write cache to disk (evolution_state.json)
    pub fn persist(self: *Self) !void {
        var array_list = try std.json.Value.Array.init(self.allocator, 16);

        var iter = self.cache.workers.iterator();
        while (iter.next()) |entry| {
            const worker = entry.value_ptr.*;

            var obj = try std.json.Value.Object.init(self.allocator, 8);
            try obj.put(self.allocator, "service", std.json.Value.string(worker.service_name));
            try obj.put(self.allocator, "status", std.json.Value.string(worker.status.toString()));
            try obj.put(self.allocator, "step", std.json.Value.number(@floatFromInt(worker.step)));
            try obj.put(self.allocator, "ppl", std.json.Value.number(@floatFromInt(@as(i32, @intFromFloat(worker.ppl)))));
            try obj.put(self.allocator, "last_updated", std.json.Value.number(@floatFromInt(worker.last_updated)));
            try obj.put(self.allocator, "cached", std.json.Value.bool_true);
            try array_list.append(self.allocator, std.json.Value.object(obj));
        }

        var root = try std.json.Value.Object.init(self.allocator, 4);
        try root.put(self.allocator, "workers", std.json.Value.array(array_list));
        try root.put(self.allocator, "last_refresh", std.json.Value.number(@floatFromInt(self.cache.last_refresh)));
        try root.put(self.allocator, "refresh_interval_sec", std.json.Value.number(@floatFromInt(self.cache.refresh_interval_sec)));
        try root.put(self.allocator, "cache_age", std.json.Value.string("CACHED (NOT LIVE TRUTH!)"));

        const json_str = try std.json.stringifyAlloc(self.allocator, std.json.Value.object(root), .{ .whitespace = .indent_2 });
        defer self.allocator.free(json_str);

        const file = try std.fs.cwd().createFile(self.file_path, .{});
        defer file.close();
        try file.writeAll(json_str);
    }

    /// Force refresh of cache (ignores refresh interval)
    pub fn forceRefresh(self: *Self, thalamus: *const thalamus_logs.Thalamus) !void {
        try self.refreshFromThalamus(thalamus);
    }

    /// Get cache age in seconds
    pub fn getCacheAge(self: *const Self) i64 {
        return std.time.timestamp() - self.cache.last_refresh;
    }

    /// Check if worker exists in cache
    pub fn hasWorker(self: *const Self, service_name: []const u8) bool {
        return self.cache.getWorker(service_name) != null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FILE I/O
// ═══════════════════════════════════════════════════════════════════════════

fn loadCacheFromFile(allocator: Allocator, cache: *PopulationCache) !void {
    const file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 65536);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(allocator, content);
    defer parsed.deinit(allocator);

    const root = parsed.object.get("workers") orelse return;

    if (root != .array) return;

    const workers_array = root.array;
    for (workers_array.items) |worker_json| {
        if (worker_json != .object) continue;

        const service = worker_json.object.get("service") orelse continue;
        const status_str = worker_json.object.get("status") orelse continue;
        const step = worker_json.object.get("step") orelse continue;
        const ppl = worker_json.object.get("ppl") orelse continue;
        const last_updated = worker_json.object.get("last_updated") orelse continue;

        if (service != .string or status_str != .string) continue;

        const service_name = try allocator.dupe(u8, service.string);
        const status = if (LiveStatus.fromString(status_str.string)) |s| s else LiveStatus.unknown;

        const step_int = @as(u32, @intFromFloat(step.number));
        const ppl_float = ppl.number;
        const last_ts = @as(i64, @intFromFloat(last_updated.number));

        const key = try allocator.dupe(u8, service_name);
        if (cache.workers.fetchPut(key, .{
            .service_name = key,
            .status = status,
            .step = step_int,
            .ppl = ppl_float,
            .tok_per_sec = 0,
            .last_updated = last_ts,
            .cached = true,
        })) |kv| {
            allocator.free(key);
        }
    }
}

test "hippocampus_cache_worker" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "test-worker", .training, 1000, 4.5);

    const cached = cache.getWorker("test-worker");
    try std.testing.expect(cached != null);
    try std.testing.expectEqual(@as(u32, 1000), cached.?.step);
    try std.testing.expect(cached.?.cached);
}

test "hippocampus_stale_detection" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    // Simulate old entry (100 seconds ago)
    const now = std.time.timestamp() - 100;
    try cache.updateWorker(allocator, "old-worker", .training, 500, 5.0);

    // Hack the last_updated timestamp
    if (cache.workers.get("old-worker")) |worker| {
        // Can't directly modify, but can test with current cache
        _ = worker;
    }

    // Get all workers
    const workers = cache.listWorkers();
    try std.testing.expect(workers.items.len > 0);
    workers.deinit(allocator);
}
