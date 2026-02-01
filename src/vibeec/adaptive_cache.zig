const std = @import("std");

const CacheType = enum {
    LRU,
    LFU,
    RANDOM,
};

const CacheEntry = struct {
    // Generic binary support
    key: []const u8,
    value: []const u8,
    access_count: u32,
    last_access: u64,
};

pub const AdaptiveCache = struct {
    entries: std.StringHashMap(CacheEntry),
    capacity: usize,
    current_type: CacheType,
    access_patterns: std.ArrayListUnmanaged([]const u8),
    mutation_threshold: u32,
    access_counter: u64,
    allocator: std.mem.Allocator,

    // CPU Load Simulation (0.0 to 1.0)
    simulated_cpu_load: f32,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !AdaptiveCache {
        return AdaptiveCache{
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .capacity = capacity,
            .current_type = .LRU,
            .access_patterns = .{},
            .mutation_threshold = 100, // Frequent checks for demo
            .access_counter = 0,
            .allocator = allocator,
            .simulated_cpu_load = 0.1,
        };
    }

    pub fn deinit(self: *AdaptiveCache) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.entries.deinit();
        for (self.access_patterns.items) |pattern| {
            self.allocator.free(pattern);
        }
        self.access_patterns.deinit(self.allocator);
    }

    pub fn put(self: *AdaptiveCache, key: []const u8, value: []const u8) !void {
        self.access_counter += 1;
        const key_copy = try self.allocator.dupe(u8, key);
        try self.access_patterns.append(self.allocator, key_copy);

        if (self.entries.count() >= self.capacity) {
            try self.evolveCache();
        }

        const val_copy = try self.allocator.dupe(u8, value);

        // We need to dup key for hashmap entry if it's new
        const entry_key = if (self.entries.contains(key)) key else try self.allocator.dupe(u8, key);

        const entry = CacheEntry{
            .key = entry_key,
            .value = val_copy,
            .access_count = 1,
            .last_access = self.access_counter,
        };
        try self.entries.put(entry_key, entry);
    }

    pub fn get(self: *AdaptiveCache, key: []const u8) ?[]const u8 {
        self.access_counter += 1;

        if (self.entries.getPtr(key)) |entry| {
            entry.access_count += 1;
            entry.last_access = self.access_counter;
            return entry.value;
        }
        return null;
    }

    /// The Auto-Optimizer: Adapts based on CPU load and Hit Rate
    pub fn evolveCache(self: *AdaptiveCache) !void {
        // 1. Simulate changing CPU load
        self.updateSimulatedLoad();

        // 2. Decide Strategy
        // High CPU -> Random (Low overhead)
        // Med CPU -> LRU (Standard)
        // Low CPU -> LFU (Compute intensive)

        const old_type = self.current_type;

        if (self.simulated_cpu_load > 0.8) {
            self.current_type = .RANDOM;
        } else if (self.simulated_cpu_load > 0.4) {
            self.current_type = .LRU;
        } else {
            self.current_type = .LFU;
        }

        if (self.current_type != old_type) {
            std.debug.print("⚠️ [Mutation] CPU Load: {d:.2} -> Strategy Shift: {s} -> {s}\n", .{ self.simulated_cpu_load, @tagName(old_type), @tagName(self.current_type) });
        }

        // 3. Evict
        const key_to_evict = switch (self.current_type) {
            .LRU => self.findLruKey(),
            .LFU => self.findLfuKey(),
            .RANDOM => self.findRandomKey(),
        };

        if (key_to_evict) |key| {
            // Free memory
            if (self.entries.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
                self.allocator.free(kv.value.value);
            }
        }
    }

    fn updateSimulatedLoad(self: *AdaptiveCache) void {
        // Random walk for simulation
        const seed: u64 = self.access_counter;
        var r = std.Random.DefaultPrng.init(seed);
        const delta = r.random().float(f32) * 0.4 - 0.2; // -0.2 to +0.2
        self.simulated_cpu_load = @as(f32, @max(0.0, @min(1.0, self.simulated_cpu_load + delta)));
    }

    fn findLruKey(self: *AdaptiveCache) ?[]const u8 {
        var oldest_key: ?[]const u8 = null;
        var oldest_access: u64 = std.math.maxInt(u64);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.last_access < oldest_access) {
                oldest_access = entry.value_ptr.last_access;
                oldest_key = entry.key_ptr.*;
            }
        }
        return oldest_key;
    }

    fn findLfuKey(self: *AdaptiveCache) ?[]const u8 {
        var least_freq_key: ?[]const u8 = null;
        var least_freq: u32 = std.math.maxInt(u32);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.access_count < least_freq) {
                least_freq = entry.value_ptr.access_count;
                least_freq_key = entry.key_ptr.*;
            }
        }
        return least_freq_key;
    }

    fn findRandomKey(self: *AdaptiveCache) ?[]const u8 {
        var iter = self.entries.iterator();
        const count = self.entries.count();
        if (count == 0) return null;

        const seed: u64 = self.access_counter;
        var r = std.Random.DefaultPrng.init(seed);
        const rand_idx = r.random().intRangeLessThan(usize, 0, count);

        var idx: usize = 0;
        while (iter.next()) |entry| {
            if (idx == rand_idx) {
                return entry.key_ptr.*;
            }
            idx += 1;
        }
        return null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = try AdaptiveCache.init(allocator, 5);
    defer cache.deinit();

    const keys = [_][]const u8{ "w1.tri", "w2.tri", "w3.tri", "w4.tri", "w5.tri", "w6.tri" };

    // Simulate high load
    std.debug.print("--- Simulation Start ---\n", .{});

    for (keys, 0..) |k, i| {
        // Fake binary data
        const data = try std.fmt.allocPrint(allocator, "binary_data_{d}", .{i});
        defer allocator.free(data);

        try cache.put(k, data);
        std.debug.print("Put {s}. Load: {d:.2} Type: {s}\n", .{ k, cache.simulated_cpu_load, @tagName(cache.current_type) });

        // Artificial load spike
        if (i == 3) cache.simulated_cpu_load = 0.95;
    }

    std.debug.print("--- Simulation End ---\n", .{});
}
