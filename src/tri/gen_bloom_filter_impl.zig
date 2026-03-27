//! tri/bloom_filter — Probabilistic set membership
//! TTT Dogfood v0.2 Stage 195

const std = @import("std");

pub const BloomFilter = struct {
    bits: []bool,
    m: usize,
    k: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, m: usize, k: usize) !BloomFilter {
        const bits = try allocator.alloc(bool, m);
        @memset(bits, false);
        return .{
            .bits = bits,
            .m = m,
            .k = k,
            .allocator = allocator,
        };
    }

    fn hash1(item: []const u8) u64 {
        var h: u64 = 5381;
        for (item) |c| {
            h = h *% 33 +% @as(u64, @intCast(c));
        }
        return h;
    }

    fn hash2(item: []const u8) u64 {
        var h: u64 = 0;
        for (item) |c| {
            h = (h << 5) ^ (h >> 63) ^ @as(u64, @intCast(c));
        }
        return h;
    }

    pub fn add(bf: *BloomFilter, item: []const u8) void {
        const h1 = hash1(item);
        const h2 = hash2(item);
        for (0..bf.k) |i| {
            const idx = @as(usize, @intCast((h1 +% @as(u64, @intCast(i)) *% h2) % @as(u64, @intCast(bf.m))));
            bf.bits[idx] = true;
        }
    }

    pub fn contains(bf: *const BloomFilter, item: []const u8) bool {
        const h1 = hash1(item);
        const h2 = hash2(item);
        for (0..bf.k) |i| {
            const idx = @as(usize, @intCast((h1 +% @as(u64, @intCast(i)) *% h2) % @as(u64, @intCast(bf.m))));
            if (!bf.bits[idx]) return false;
        }
        return true;
    }

    pub fn deinit(bf: *BloomFilter) void {
        bf.allocator.free(bf.bits);
    }
};

test "bloom filter add contains" {
    var bf = try BloomFilter.init(std.testing.allocator, 100, 3);
    defer bf.deinit();

    bf.add("hello");
    try std.testing.expect(bf.contains("hello"));
    try std.testing.expect(!bf.contains("world"));
}

test "bloom filter false positive" {
    var bf = try BloomFilter.init(std.testing.allocator, 50, 2);
    defer bf.deinit();

    bf.add("a");
    bf.add("b");
    bf.add("c");

    // No false positives guaranteed, but all added should be found
    try std.testing.expect(bf.contains("a"));
}
