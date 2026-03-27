//! tri/hash_table — Hash table with chaining
//! Auto-generated from specs/tri/tri_hash_table.tri
//! TTT Dogfood v0.2 Stage 191

const std = @import("std");

/// Hash table entry
pub const Entry = struct {
    key: usize,
    value: i64,
    next: ?*Entry,
};

/// Hash table with chaining
pub const HashTable = struct {
    buckets: []?*Entry,
    capacity: usize,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create hash table
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !HashTable {
        const buckets = try allocator.alloc(?*Entry, capacity);
        @memset(buckets, null);

        return .{
            .buckets = buckets,
            .capacity = capacity,
            .size = 0,
            .allocator = allocator,
        };
    }

    fn hashIndex(ht: *const HashTable, key: usize) usize {
        return key % ht.capacity;
    }

    /// Insert key-value pair
    pub fn put(ht: *HashTable, key: usize, value: i64) !void {
        const idx = ht.hashIndex(key);

        // Check if key exists
        var current = ht.buckets[idx];
        while (current) |entry| {
            if (entry.key == key) {
                entry.value = value;
                return;
            }
            current = entry.next;
        }

        // Create new entry
        const entry = try ht.allocator.create(Entry);
        entry.* = .{
            .key = key,
            .value = value,
            .next = ht.buckets[idx],
        };
        ht.buckets[idx] = entry;
        ht.size += 1;
    }

    /// Get value by key
    pub fn get(ht: *const HashTable, key: usize) i64 {
        const idx = ht.hashIndex(key);
        var current = ht.buckets[idx];

        while (current) |entry| {
            if (entry.key == key) {
                return entry.value;
            }
            current = entry.next;
        }

        return 0;
    }

    /// Remove key
    pub fn remove(ht: *HashTable, key: usize) bool {
        const idx = ht.hashIndex(key);
        var prev: ?*Entry = null;
        var current = ht.buckets[idx];

        while (current) |entry| {
            if (entry.key == key) {
                if (prev) |p| {
                    p.next = entry.next;
                } else {
                    ht.buckets[idx] = entry.next;
                }
                ht.allocator.destroy(entry);
                ht.size -= 1;
                return true;
            }
            prev = current;
            current = entry.next;
        }

        return false;
    }

    /// Free table
    pub fn deinit(ht: *HashTable) void {
        for (ht.buckets) |maybe_entry| {
            var current = maybe_entry;
            while (current) |entry| {
                const next = entry.next;
                ht.allocator.destroy(entry);
                current = next;
            }
        }
        ht.allocator.free(ht.buckets);
    }
};

test "hash table put get" {
    var ht = try HashTable.init(std.testing.allocator, 16);
    defer ht.deinit();

    try ht.put(1, 100);
    try ht.put(2, 200);

    try std.testing.expectEqual(@as(i64, 100), ht.get(1));
    try std.testing.expectEqual(@as(i64, 200), ht.get(2));
    try std.testing.expectEqual(@as(i64, 0), ht.get(99));
}

test "hash table remove" {
    var ht = try HashTable.init(std.testing.allocator, 16);
    defer ht.deinit();

    try ht.put(1, 100);
    try ht.put(2, 200);

    try std.testing.expect(ht.remove(1));
    try std.testing.expect(!ht.remove(99));
    try std.testing.expectEqual(@as(i64, 0), ht.get(1));
}

test "hash table collision" {
    var ht = try HashTable.init(std.testing.allocator, 4);
    defer ht.deinit();

    try ht.put(1, 100);
    try ht.put(5, 500); // Same bucket as 1 in capacity 4

    try std.testing.expectEqual(@as(i64, 100), ht.get(1));
    try std.testing.expectEqual(@as(i64, 500), ht.get(5));
}
