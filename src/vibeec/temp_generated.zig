const std = @import("std");

const CacheType = enum {
    LRU,
    LFU,
    RANDOM,
};

const CacheEntry = struct {
    key: u64,
    value: u64,
    access_count: u32,
    last_access: u64,
};

const AdaptiveCache = struct {
    entries: std.AutoHashMap(u64, CacheEntry),
    capacity: usize,
    current_type: CacheType,
    access_patterns: std.ArrayList(u64),
    mutation_threshold: u32,
    access_counter: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !AdaptiveCache {
        const access_patterns = try std.ArrayList(u64).initCapacity(allocator, 1000);
        return AdaptiveCache{
            .entries = std.AutoHashMap(u64, CacheEntry).init(allocator),
            .capacity = capacity,
            .current_type = .LRU,
            .access_patterns = access_patterns,
            .mutation_threshold = 1000,
            .access_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AdaptiveCache) void {
        self.entries.deinit();
        self.access_patterns.deinit();
    }

    pub fn put(self: *AdaptiveCache, key: u64, value: u64) !void {
        self.access_counter += 1;
        try self.access_patterns.append(key);

        if (self.entries.count() >= self.capacity) {
            try self.evolveAndEvict();
        }

        const entry = CacheEntry{
            .key = key,
            .value = value,
            .access_count = 1,
            .last_access = self.access_counter,
        };
        try self.entries.put(key, entry);
    }

    pub fn get(self: *AdaptiveCache, key: u64) ?u64 {
        self.access_counter += 1;
        try self.access_patterns.append(key) catch return null;

        if (self.entries.getPtr(key)) |entry| {
            entry.access_count += 1;
            entry.last_access = self.access_counter;
            return entry.value;
        }
        return null;
    }

    fn evolveAndEvict(self: *AdaptiveCache) !void {
        if (self.access_counter % self.mutation_threshold == 0) {
            try self.mutateStrategy();
        }

        const key_to_evict = switch (self.current_type) {
            .LRU => self.findLruKey(),
            .LFU => self.findLfuKey(),
            .RANDOM => self.findRandomKey(),
        };

        if (key_to_evict) |key| {
            _ = self.entries.remove(key);
        }
    }

    fn findLruKey(self: *AdaptiveCache) ?u64 {
        var oldest_key: ?u64 = null;
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

    fn findLfuKey(self: *AdaptiveCache) ?u64 {
        var least_freq_key: ?u64 = null;
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

    fn findRandomKey(self: *AdaptiveCache) ?u64 {
        var iter = self.entries.iterator();
        const rand_idx = std.crypto.random.intRangeLessThan(usize, 0, self.entries.count());
        var idx: usize = 0;
        while (iter.next()) |entry| {
            if (idx == rand_idx) {
                return entry.key_ptr.*;
            }
            idx += 1;
        }
        return null;
    }

    fn mutateStrategy(self: *AdaptiveCache) !void {
        const hit_rate = self.calculateHitRate();
        if (hit_rate < 0.5) {
            self.current_type = switch (self.current_type) {
                .LRU => .LFU,
                .LFU => .RANDOM,
                .RANDOM => .LRU,
            };
            self.mutation_threshold = @max(100, self.mutation_threshold - 100);
        } else {
            self.mutation_threshold += 200;
        }
    }

    fn calculateHitRate(self: *AdaptiveCache) f32 {
        var hits: u32 = 0;
        const window_size = @min(1000, self.access_patterns.items.len);
        if (window_size == 0) return 0.0;

        var i: usize = self.access_patterns.items.len - window_size;
        while (i < self.access_patterns.items.len) : (i += 1) {
            if (self.entries.contains(self.access_patterns.items[i])) {
                hits += 1;
            }
        }
        return @as(f32, @floatFromInt(hits)) / @as(f32, @floatFromInt(window_size));
    }
};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = AdaptiveCache.init(allocator, 5) catch {
        std.debug.print("Failed to initialize cache\n", .{});
        return;
    };
    defer cache.deinit();

    cache.put(1, 100) catch return;
    cache.put(2, 200) catch return;
    cache.put(3, 300) catch return;
    _ = cache.get(1);
    _ = cache.get(2);
    cache.put(4, 400) catch return;
    cache.put(5, 500) catch return;
    cache.put(6, 600) catch return;

    std.debug.print("Cache type after operations: {}\n", .{cache.current_type});
}