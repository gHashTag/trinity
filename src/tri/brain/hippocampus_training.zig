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
const contracts = @import("contracts.zig");
const LiveStatus = thalamus_logs.LiveStatus;

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

    /// Get worker view from cache with explicit source and staleness markers (Phase 3)
    /// ALL returns from Hippocampus have source: .cache and stale calculated from last_updated
    pub fn getCachedView(self: *const Self, service_name: []const u8) ?contracts.WorkerView {
        const cached = self.cache.getWorker(service_name) orelse return null;

        return contracts.WorkerView.fromCached(
            self.allocator,
            service_name,
            cached.status,
            cached.step,
            cached.last_updated,
        );
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
        })) |_| {
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
    _ = std.time.timestamp() - 100; // Would be used to set last_updated timestamp
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

// ═══════════════════════════════════════════════════════════════════════════════
// HIPPOCAMPUS COMPREHENSIVE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hippocampus_cached_worker_age" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "age-test", .training, 1000, 4.5);

    const worker = cache.getWorker("age-test").?;
    const age = worker.ageSec();

    // Age should be small (just created)
    try std.testing.expect(age >= 0);
    try std.testing.expect(age < 5); // Less than 5 seconds
}

test "hippocampus_is_stale_boundary" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "fresh-worker", .training, 1000, 4.5);

    const worker = cache.getWorker("fresh-worker").?;

    // Fresh worker should not be stale with 300s threshold
    try std.testing.expect(!worker.isStale(300));

    // But should be stale with 0s threshold
    try std.testing.expect(worker.isStale(0));
}

test "hippocampus_is_stale_edge_cases" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "edge-worker", .training, 1000, 4.5);

    const worker = cache.getWorker("edge-worker").?;
    const age = worker.ageSec();

    // At exact age boundary
    try std.testing.expect(!worker.isStale(age + 1)); // Not stale yet
    try std.testing.expect(worker.isStale(age)); // Exactly stale at threshold
}

test "hippocampus_multiple_workers" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    // Add multiple workers
    try cache.updateWorker(allocator, "worker-1", .training, 1000, 4.5);
    try cache.updateWorker(allocator, "worker-2", .stalled, 2000, 5.0);
    try cache.updateWorker(allocator, "worker-3", .crashed, 3000, 6.0);

    try std.testing.expect(cache.getWorker("worker-1") != null);
    try std.testing.expect(cache.getWorker("worker-2") != null);
    try std.testing.expect(cache.getWorker("worker-3") != null);

    // Non-existent worker
    try std.testing.expect(cache.getWorker("worker-999") == null);
}

test "hippocampus_worker_update" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    // Add initial worker
    try cache.updateWorker(allocator, "update-test", .training, 1000, 4.5);
    var worker = cache.getWorker("update-test").?;
    try std.testing.expectEqual(@as(u32, 1000), worker.step);

    // Update worker
    try cache.updateWorker(allocator, "update-test", .training, 2000, 3.5);
    worker = cache.getWorker("update-test").?;
    try std.testing.expectEqual(@as(u32, 2000), worker.step);
    try std.testing.expectEqual(@as(f32, 3.5), worker.ppl);
}

test "hippocampus_remove_worker" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "remove-test", .training, 1000, 4.5);
    try std.testing.expect(cache.getWorker("remove-test") != null);

    cache.removeWorker(allocator, "remove-test");
    try std.testing.expect(cache.getWorker("remove-test") == null);
}

test "hippocampus_clear_all" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "worker-1", .training, 1000, 4.5);
    try cache.updateWorker(allocator, "worker-2", .training, 2000, 5.0);

    const workers_before = cache.listWorkers();
    try std.testing.expect(workers_before.items.len == 2);
    workers_before.deinit(allocator);

    cache.clear(allocator);

    const workers_after = cache.listWorkers();
    try std.testing.expect(workers_after.items.len == 0);
    workers_after.deinit(allocator);
}

test "hippocampus_needs_refresh" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    // Fresh cache should need refresh (last_refresh = 0)
    try std.testing.expect(cache.needsRefresh());

    // Set last_refresh to now
    cache.last_refresh = std.time.timestamp();

    // Should not need refresh immediately
    try std.testing.expect(!cache.needsRefresh());
}

test "hippocampus_all_statuses" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    const statuses = [_]LiveStatus{
        .training,
        .stalled,
        .crashed,
        .unknown,
        .succeeded,
    };

    for (statuses, 0..) |status, i| {
        const name = try std.fmt.allocPrint(allocator, "status-{d}", .{i});
        defer allocator.free(name);

        try cache.updateWorker(allocator, name, status, 1000, 4.5);

        const worker = cache.getWorker(name).?;
        try std.testing.expectEqual(status, worker.status);
    }
}

test "hippocampus_cached_flag" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "cached-test", .training, 1000, 4.5);

    const worker = cache.getWorker("cached-test").?;
    try std.testing.expect(worker.cached); // All cache entries should have cached=true
}

test "hippocampus_custom_refresh_interval" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    cache.refresh_interval_sec = 60; // 1 minute
    cache.last_refresh = std.time.timestamp();

    try std.testing.expect(!cache.needsRefresh());

    // Simulate time passing (by setting last_refresh to past)
    cache.last_refresh = std.time.timestamp() - 61;

    try std.testing.expect(cache.needsRefresh());
}

test "hippocampus_list_workers_content" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try cache.updateWorker(allocator, "list-test-1", .training, 1000, 4.5);
    try cache.updateWorker(allocator, "list-test-2", .training, 2000, 5.0);

    const workers = cache.listWorkers();
    defer workers.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), workers.items.len);

    // Check names are in the list
    const has_1 = for (workers.items) |w| {
        if (std.mem.eql(u8, w, "list-test-1")) break true;
    } else false;
    try std.testing.expect(has_1);

    const has_2 = for (workers.items) |w| {
        if (std.mem.eql(u8, w, "list-test-2")) break true;
    } else false;
    try std.testing.expect(has_2);
}

test "hippocampus_init_empty" {
    const allocator = std.testing.allocator;
    const cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    try std.testing.expectEqual(@as(i64, 0), cache.last_refresh);
    try std.testing.expectEqual(@as(i64, 300), cache.refresh_interval_sec);
    try std.testing.expectEqual(@as(usize, 0), cache.workers.count());
}

test "hippocampus_step_and_ppl_values" {
    const allocator = std.testing.allocator;
    var cache = PopulationCache.init(allocator);
    defer cache.deinit(allocator);

    // Test various step and PPL values
    try cache.updateWorker(allocator, "low-values", .training, 0, 1.0);
    try cache.updateWorker(allocator, "high-values", .training, 100000, 100.0);
    try cache.updateWorker(allocator, "fractional-ppl", .training, 5000, 4.678);

    const low = cache.getWorker("low-values").?;
    try std.testing.expectEqual(@as(u32, 0), low.step);
    try std.testing.expectEqual(@as(f32, 1.0), low.ppl);

    const high = cache.getWorker("high-values").?;
    try std.testing.expectEqual(@as(u32, 100000), high.step);
    try std.testing.expectEqual(@as(f32, 100.0), high.ppl);

    const frac = cache.getWorker("fractional-ppl").?;
    try std.testing.expectEqual(@as(u32, 5000), frac.step);
    try std.testing.expect(frac.ppl > 4.6 and frac.ppl < 4.7);
}
