//! tri/bloom — Probabilistic bloom filter
//! Auto-generated from specs/tri/tri_bloom.tri
//! TTT Dogfood v0.2 Stage 129

const std = @import("std");

/// Bloom filter
pub const BloomFilter = struct {
    bits: std.ArrayList(bool),
    num_hashes: usize,
    size: usize,

    /// Create bloom filter
    pub fn init(size: usize, num_hashes: usize, allocator: std.mem.Allocator) !BloomFilter {
        var bits = try std.ArrayList(bool).initCapacity(allocator, size);
        for (0..size) |_| {
            bits.appendAssumeCapacity(false);
        }

        return .{
            .bits = bits,
            .num_hashes = num_hashes,
            .size = size,
        };
    }

    /// Free resources
    pub fn deinit(self: *BloomFilter, allocator: std.mem.Allocator) void {
        self.bits.deinit(allocator);
    }

    /// Add item to filter
    pub fn add(self: *BloomFilter, item: []const u8) void {
        for (0..self.num_hashes) |i| {
            const h = self.hashValue(item, i);
            const idx = h % self.size;
            if (idx < self.bits.items.len) {
                self.bits.items[idx] = true;
            }
        }
    }

    /// Check if item might exist (false positives possible)
    pub fn contains(self: *const BloomFilter, item: []const u8) bool {
        for (0..self.num_hashes) |i| {
            const h = self.hashValue(item, i);
            const idx = h % self.size;
            if (idx >= self.bits.items.len or !self.bits.items[idx]) {
                return false;
            }
        }
        return true;
    }

    /// Simple hash function with seed
    fn hashValue(self: *const BloomFilter, item: []const u8, seed: usize) usize {
        _ = self;
        var h: usize = seed;
        for (item) |c| {
            h = h *% 31 + c;
        }
        return h;
    }
};

test "bloom filter add contains" {
    var filter = try BloomFilter.init(100, 3, std.testing.allocator);
    defer filter.deinit(std.testing.allocator);

    filter.add("hello");

    try std.testing.expect(filter.contains("hello"));
    try std.testing.expect(!filter.contains("world"));
}

test "bloom filter false positive" {
    var filter = try BloomFilter.init(10, 2, std.testing.allocator);
    defer filter.deinit(std.testing.allocator);

    filter.add("item1");
    filter.add("item2");
    filter.add("item3");

    // False positives possible with small filter
    _ = filter.contains("item4");
    _ = filter.contains("item5");
}

test "bloom filter no false negatives" {
    var filter = try BloomFilter.init(1000, 5, std.testing.allocator);
    defer filter.deinit(std.testing.allocator);

    const items = [_][]const u8{ "apple", "banana", "cherry", "date", "elderberry" };

    for (items) |item| {
        filter.add(item);
    }

    for (items) |item| {
        try std.testing.expect(filter.contains(item));
    }
}
