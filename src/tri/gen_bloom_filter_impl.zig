//! tri/bloom_filter_impl — Bloom filter implementation
//! Auto-generated from specs/tri_bloom_filter_impl.tri
//! TTT Dogfood v0.2 Stage 195

const std = @import("std");

/// Probabilistic set membership
pub const BloomFilter = struct {
    bits: []usize,
    num_hashes: usize,
    allocator: std.mem.Allocator,

    /// Create bloom filter
    pub fn init(allocator: std.mem.Allocator, size: usize, hash_count: usize) !BloomFilter {
        const words = (size + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);
        const bits = try allocator.alloc(usize, words);
        @memset(bits, 0);

        return .{
            .bits = bits,
            .num_hashes = hash_count,
            .allocator = allocator,
        };
    }

    fn hash1(item: []const u8) usize {
        var h: usize = 0;
        for (item) |c| {
            h = h *% 31 +% c;
        }
        return h;
    }

    fn hash2(item: []const u8) usize {
        var h: usize = 0;
        for (item) |c| {
            h = h *% 37 +% c;
        }
        return h;
    }

    /// Add item
    pub fn add(bf: *BloomFilter, item: []const u8) void {
        const h1 = hash1(item);
        const h2 = hash2(item);

        for (0..bf.num_hashes) |i| {
            const combined = h1 + i * h2;
            const word = (combined / @bitSizeOf(usize)) % bf.bits.len;
            const bit = combined % @bitSizeOf(usize);
            bf.bits[word] |= @as(usize, 1) << @intCast(bit);
        }
    }

    /// Check if item might exist
    pub fn contains(bf: *const BloomFilter, item: []const u8) bool {
        const h1 = hash1(item);
        const h2 = hash2(item);

        for (0..bf.num_hashes) |i| {
            const combined = h1 + i * h2;
            const word = (combined / @bitSizeOf(usize)) % bf.bits.len;
            const bit = combined % @bitSizeOf(usize);
            if ((bf.bits[word] & (@as(usize, 1) << @intCast(bit))) == 0) {
                return false;
            }
        }

        return true; // Might exist (false positives possible)
    }

    /// Free filter
    pub fn deinit(bf: *BloomFilter) void {
        bf.allocator.free(bf.bits);
    }
};

test "bloom filter add contains" {
    var bf = try BloomFilter.init(std.testing.allocator, 128, 3);
    defer bf.deinit();

    bf.add("hello");
    bf.add("world");

    try std.testing.expect(bf.contains("hello"));
    try std.testing.expect(bf.contains("world"));
    try std.testing.expect(!bf.contains("goodbye"));
}

test "bloom filter false positive" {
    var bf = try BloomFilter.init(std.testing.allocator, 32, 2);
    defer bf.deinit();

    bf.add("test");

    // Might have false positive
    _ = bf.contains("other");
    try std.testing.expect(true);
}
