//! tri/bloom_filter — Probabilistic set membership
//! Auto-generated from specs/tri/tri_bloom_filter.tri
//! TTT Dogfood v0.2 Stage 141

const std = @import("std");

/// Bloom filter
pub const BloomFilter = struct {
    bits: []bool,
    hash_count: usize,
    size: usize,
    allocator: std.mem.Allocator,

    /// Create bloom filter
    pub fn init(size: usize, hash_count: usize, allocator: std.mem.Allocator) !BloomFilter {
        const bits = try allocator.alloc(bool, size);
        @memset(bits, false);

        return .{
            .bits = bits,
            .hash_count = hash_count,
            .size = size,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *BloomFilter) void {
        self.allocator.free(self.bits);
    }

    /// Hash function for bloom filter
    fn hash(data: []const u8, seed: u32) u32 {
        var h: u32 = seed;
        for (data) |b| {
            h = h *% 31 +% @as(u32, @intCast(b));
        }
        return h;
    }

    /// Get bit indices for item
    fn getIndices(self: *const BloomFilter, item: []const u8, indices: []usize) void {
        for (0..self.hash_count) |i| {
            const h = hash(item, @intCast(i));
            indices[i] = @as(usize, @intCast(h)) % self.size;
        }
    }

    /// Add item to filter
    pub fn add(self: *BloomFilter, item: []const u8) void {
        var indices: [8]usize = undefined;
        const count = @min(self.hash_count, 8);
        self.getIndices(item, indices[0..count]);

        for (indices[0..count]) |idx| {
            self.bits[idx] = true;
        }
    }

    /// Check if item possibly in filter
    pub fn contains(self: *const BloomFilter, item: []const u8) bool {
        var indices: [8]usize = undefined;
        const count = @min(self.hash_count, 8);
        self.getIndices(item, indices[0..count]);

        for (indices[0..count]) |idx| {
            if (!self.bits[idx]) return false;
        }
        return true;
    }
};

test "bloom filter init" {
    var bf = try BloomFilter.init(100, 3, std.testing.allocator);
    defer bf.deinit();

    try std.testing.expectEqual(@as(usize, 100), bf.size);
    try std.testing.expectEqual(@as(usize, 3), bf.hash_count);
}

test "bloom filter add contains" {
    var bf = try BloomFilter.init(100, 3, std.testing.allocator);
    defer bf.deinit();

    try std.testing.expect(!bf.contains("hello"));

    bf.add("hello");
    try std.testing.expect(bf.contains("hello"));
}

test "bloom filter false positive possible" {
    var bf = try BloomFilter.init(10, 2, std.testing.allocator);
    defer bf.deinit();

    bf.add("item1");
    bf.add("item2");

    // item3 not added but might show as present (false positive)
    // or might not show as present (true negative)
    _ = bf.contains("item3");
}
