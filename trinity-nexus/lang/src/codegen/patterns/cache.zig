// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN CACHE - Memoization for pattern matching results
// ═══════════════════════════════════════════════════════════════════════════════
//
// Caches pattern lookup results to eliminate repeated matching for same behaviors.
// Useful when generating multiple files with similar behavior names.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const registry = @import("registry.zig");

const Category = registry.Category;

/// Cached match result
pub const CacheEntry = struct {
    category: Category,
    matched: bool,
    prefix: ?[]const u8,
    hit_count: u32 = 1,
};

/// Pattern cache with LRU eviction
pub const PatternCache = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(CacheEntry),
    max_entries: usize,
    hits: u64 = 0,
    misses: u64 = 0,
    evictions: u64 = 0,

    const Self = @This();
    const DEFAULT_MAX_ENTRIES = 1024;

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .max_entries = DEFAULT_MAX_ENTRIES,
        };
    }

    pub fn initWithCapacity(allocator: std.mem.Allocator, max_entries: usize) Self {
        return Self{
            .allocator = allocator,
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .max_entries = max_entries,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all stored keys
        var it = self.entries.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entries.deinit();
    }

    /// Look up cached result
    pub fn get(self: *Self, name: []const u8) ?CacheEntry {
        if (self.entries.getPtr(name)) |entry| {
            self.hits += 1;
            entry.hit_count += 1;
            return entry.*;
        }
        self.misses += 1;
        return null;
    }

    /// Store result in cache
    pub fn put(self: *Self, name: []const u8, entry: CacheEntry) !void {
        // Check capacity
        if (self.entries.count() >= self.max_entries) {
            try self.evictLRU();
        }

        // Allocate key copy
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);

        try self.entries.put(key, entry);
    }

    /// Evict least-recently-used entry
    fn evictLRU(self: *Self) !void {
        var min_hits: u32 = std.math.maxInt(u32);
        var victim_key: ?[]const u8 = null;

        var it = self.entries.iterator();
        while (it.next()) |kv| {
            if (kv.value_ptr.hit_count < min_hits) {
                min_hits = kv.value_ptr.hit_count;
                victim_key = kv.key_ptr.*;
            }
        }

        if (victim_key) |key| {
            _ = self.entries.remove(key);
            self.allocator.free(key);
            self.evictions += 1;
        }
    }

    /// Clear all entries
    pub fn clear(self: *Self) void {
        var it = self.entries.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entries.clearAndFree();
        self.hits = 0;
        self.misses = 0;
        self.evictions = 0;
    }

    /// Get cache statistics
    pub fn getStats(self: *const Self) CacheStats {
        const total = self.hits + self.misses;
        return CacheStats{
            .entries = self.entries.count(),
            .max_entries = self.max_entries,
            .hits = self.hits,
            .misses = self.misses,
            .evictions = self.evictions,
            .hit_rate = if (total > 0) @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total)) else 0.0,
        };
    }
};

/// Cache statistics
pub const CacheStats = struct {
    entries: usize,
    max_entries: usize,
    hits: u64,
    misses: u64,
    evictions: u64,
    hit_rate: f64,

    pub fn format(
        self: CacheStats,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "CacheStats{{ entries: {}/{}, hits: {}, misses: {}, evictions: {}, hit_rate: {d:.2}% }}",
            .{ self.entries, self.max_entries, self.hits, self.misses, self.evictions, self.hit_rate * 100 },
        );
    }
};

/// Global cache instance (for simple usage)
var global_cache: ?PatternCache = null;

pub fn getGlobalCache() *PatternCache {
    if (global_cache == null) {
        global_cache = PatternCache.init(std.heap.page_allocator);
    }
    return &global_cache.?;
}

pub fn resetGlobalCache() void {
    if (global_cache) |*cache| {
        cache.deinit();
        global_cache = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CACHED PATTERN LOOKUP
// ═══════════════════════════════════════════════════════════════════════════════

/// Cached version of quickCategoryLookup
pub fn cachedCategoryLookup(name: []const u8) Category {
    var cache = getGlobalCache();

    // Check cache first
    if (cache.get(name)) |entry| {
        return entry.category;
    }

    // Compute category
    const category = registry.quickCategoryLookup(name);
    const prefix = registry.findMatchingPrefix(name);

    // Store in cache
    cache.put(name, .{
        .category = category,
        .matched = category != .unknown,
        .prefix = prefix,
    }) catch {};

    return category;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PatternCache basic" {
    const testing = std.testing;
    var cache = PatternCache.init(testing.allocator);
    defer cache.deinit();

    // Miss
    try testing.expect(cache.get("getValue") == null);
    try testing.expectEqual(@as(u64, 0), cache.hits);
    try testing.expectEqual(@as(u64, 1), cache.misses);

    // Put
    try cache.put("getValue", .{
        .category = .generic,
        .matched = true,
        .prefix = "get",
    });

    // Hit
    const entry = cache.get("getValue");
    try testing.expect(entry != null);
    try testing.expectEqual(Category.generic, entry.?.category);
    try testing.expectEqual(@as(u64, 1), cache.hits);
}

test "PatternCache eviction" {
    const testing = std.testing;
    var cache = PatternCache.initWithCapacity(testing.allocator, 3);
    defer cache.deinit();

    // Fill cache
    try cache.put("a", .{ .category = .generic, .matched = true, .prefix = null });
    try cache.put("b", .{ .category = .lifecycle, .matched = true, .prefix = null });
    try cache.put("c", .{ .category = .io, .matched = true, .prefix = null });

    // Access "a" to increase hit count
    _ = cache.get("a");
    _ = cache.get("a");

    // Add new entry (should evict "b" or "c" with lowest hit count)
    try cache.put("d", .{ .category = .data, .matched = true, .prefix = null });

    try testing.expectEqual(@as(usize, 3), cache.entries.count());
    try testing.expectEqual(@as(u64, 1), cache.evictions);
}

test "PatternCache stats" {
    const testing = std.testing;
    var cache = PatternCache.init(testing.allocator);
    defer cache.deinit();

    _ = cache.get("foo");
    _ = cache.get("bar");
    try cache.put("foo", .{ .category = .unknown, .matched = false, .prefix = null });
    _ = cache.get("foo");

    const stats = cache.getStats();
    try testing.expectEqual(@as(usize, 1), stats.entries);
    try testing.expectEqual(@as(u64, 1), stats.hits);
    try testing.expectEqual(@as(u64, 2), stats.misses);
}
