//! tri/cuckoo_filter — Alternative to Bloom filter
//! TTT Dogfood v0.2 Stage 218

const std = @import("std");

pub const CuckooFilter = struct {
    buckets: []u64,
    fingerprint_bits: u8,
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize, fingerprint_bits: u8) !CuckooFilter {
        const buckets = try allocator.alloc(u64, size * 4);
        @memset(buckets, 0);

        return .{
            .buckets = buckets,
            .fingerprint_bits = fingerprint_bits,
            .size = size,
            .allocator = allocator,
        };
    }

    fn fingerprint(cf: *const CuckooFilter, data: []const u8) u64 {
        var h: u64 = 5381;
        for (data) |c| {
            h = (h << 5) +% h +% @as(u64, @intCast(c));
        }
        const mask = (@as(u64, 1) << cf.fingerprint_bits) - 1;
        return h & mask;
    }

    fn indexOf(cf: *const Cuckoo, fingerprint: u64, index: u64) u64 {
        const alt = (index >> 1) ^ (index << 1);
        return (index + alt) % cf.size;
    }

    pub fn insert(cf: *CuckooFilter, data: []const u8) !bool {
        const fp = cf.fingerprint(data);
        var i1 = cf.indexOf(fp, 0);
        var i2 = cf.indexOf(fp, 1);

        if (cf.buckets[i1 * 4] == 0 or cf.buckets[i1 * 4 + 1] == 0) {
            cf.buckets[i1 * 4] = fp;
            return true;
        }

        if (cf.buckets[i2 * 4 + 2] == 0 or cf.buckets[i2 * 4 + 3] == 0) {
            cf.buckets[i2 * 4 + 2] = fp;
            return true;
        }

        return false; // Simplified: no kickout
    }

    pub fn lookup(cf: *const CuckooFilter, data: []const u8) bool {
        const fp = cf.fingerprint(data);
        var i1 = cf.indexOf(fp, 0);
        var i2 = cf.indexOf(fp, 1);

        return cf.buckets[i1 * 4] == fp or
               cf.buckets[i1 * 4 + 1] == fp or
               cf.buckets[i2 * 4 + 2] == fp or
               cf.buckets[i2 * 4 + 3] == fp;
    }

    pub fn deinit(cf: *CuckooFilter) void {
        cf.allocator.free(cf.buckets);
    }
};

test "cuckoo filter insert lookup" {
    var cf = try CuckooFilter.init(std.testing.allocator, 16, 8);
    defer cf.deinit();

    try std.testing.expect(try cf.insert("hello"));
    try std.testing.expect(try cf.insert("world"));

    try std.testing.expect(cf.lookup("hello"));
    try std.testing.expect(!cf.lookup("xyz"));
}
