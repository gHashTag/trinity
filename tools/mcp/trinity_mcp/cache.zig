//! MCP Cache Module
//!
//! LRU cache for pure function results.
//! Eliminates redundant computations for math commands.
//! φ² + 1/φ² = 3 = TRINITY
// @origin(manual) @regen(pending)

const std = @import("std");

/// LRU cache entry
const CacheEntry = struct {
    value: []const u8,
    timestamp: i64,
    access_count: usize,
    key: []const u8,
};

/// LRU cache for command results
pub const CommandCache = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(CacheEntry),
    max_entries: usize,
    mutex: std.Thread.Mutex,

    /// Initialize cache with specified maximum entries
    pub fn init(allocator: std.mem.Allocator, max_entries: usize) CommandCache {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .max_entries = max_entries,
            .mutex = std.Thread.Mutex{},
        };
    }

    /// Deinitialize cache and free all entries
    pub fn deinit(self: *CommandCache) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.value);
        }
        self.entries.deinit();
    }

    /// Get value from cache (thread-safe)
    pub fn get(self: *CommandCache, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.entries.getPtr(key)) |entry| {
            entry.access_count += 1;
            return entry.value;
        }
        return null;
    }

    /// Put value into cache (thread-safe, with LRU eviction)
    pub fn put(self: *CommandCache, key: []const u8, value: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // If key already exists, update it (must use getPtr to mutate in-place)
        if (self.entries.getPtr(key)) |entry| {
            self.allocator.free(entry.value);
            entry.value = try self.allocator.dupe(u8, value);
            entry.timestamp = std.time.nanoTimestamp();
            return;
        }

        // Evict LRU entry if at capacity
        if (self.entries.count() >= self.max_entries) {
            var lru_key: ?[]const u8 = null;
            var lru_count: usize = std.math.maxInt(usize);
            var lru_timestamp: i64 = std.math.maxInt(i64);

            var iter = self.entries.iterator();
            while (iter.next()) |entry| {
                const ent = entry.value_ptr.*;
                // Prioritize: low access count, then old timestamp
                if (ent.access_count < lru_count or
                    (ent.access_count == lru_count and ent.timestamp < lru_timestamp))
                {
                    lru_count = ent.access_count;
                    lru_timestamp = ent.timestamp;
                    lru_key = entry.key_ptr.*;
                }
            }

            if (lru_key) |k| {
                const removed = self.entries.fetchRemove(k);
                if (removed) |removed_entry| {
                    self.allocator.free(removed_entry.value.key);
                    self.allocator.free(removed_entry.value.value);
                }
            }
        }

        // Add new entry
        const entry = CacheEntry{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
            .timestamp = std.time.nanoTimestamp(),
            .access_count = 0,
        };
        try self.entries.put(entry.key, entry);
    }

    /// Generate cache key from command and arguments
    pub fn makeKey(allocator: std.mem.Allocator, cmd: []const u8, args: []const []const u8) ![]const u8 {
        var key = std.ArrayList(u8).init(allocator);
        try key.appendSlice(cmd);
        for (args) |arg| {
            try key.append(':');
            try key.appendSlice(arg);
        }
        return key.toOwnedSlice();
    }

    /// Clear all cache entries
    pub fn clear(self: *CommandCache) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.value);
        }
        self.entries.clearRetainingCapacity();
    }

    /// Get cache statistics
    pub const Stats = struct {
        entries: usize,
        max_entries: usize,
        total_accesses: usize,
        hits: usize,
    };

    pub fn stats(self: *CommandCache) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var total_accesses: usize = 0;
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            total_accesses += entry.value_ptr.access_count;
        }

        return .{
            .entries = self.entries.count(),
            .max_entries = self.max_entries,
            .total_accesses = total_accesses,
            .hits = total_accesses, // Approximate
        };
    }
};

/// Global cache instance
var global_cache: ?CommandCache = null;
var cache_init = std.Thread.Once{};

/// Get or create global cache
pub fn getGlobalCache() *CommandCache {
    cache_init.call(struct {
        fn init_(ctx: *std.Thread.Once) void {
            _ = ctx;
            global_cache = CommandCache.init(std.heap.page_allocator, 100);
        }
    }.init_);
    return &global_cache.?;
}
