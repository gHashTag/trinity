//! tri/xor_filter — Compressed Bloom filter
//! TTT Dogfood v0.2 Stage 219

const std = @import("std");

pub const XorFilter = struct {
    fingerprints: std.ArrayList(u64),
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) !XorFilter {
        return .{
            .fingerprints = try std.ArrayList(u64).initCapacity(allocator, size),
            .size = size,
            .allocator = allocator,
        };
    }

    fn hash(data: []const u8) u64 {
        var h: u64 = 5381;
        for (data) |c| {
            h = (h << 5) +% h +% @as(u64, @intCast(c));
        }
        return h;
    }

    pub fn add(xf: *XorFilter, data: []const u8) !void {
        const fp = hash(data);
        try xf.fingerprints.append(xf.allocator, fp);
    }

    pub fn lookup(xf: *const XorFilter, data: []const u8) bool {
        const fp = hash(data);

        var result: u64 = 0;
        for (xf.fingerprints.items) |f| {
            result ^= f;
        }

        return result == fp;
    }

    pub fn deinit(xf: *XorFilter) void {
        xf.fingerprints.deinit();
    }
};

test "xor filter add lookup" {
    var xf = try XorFilter.init(std.testing.allocator, 10);
    defer xf.deinit();

    try xf.add("hello");
    try xf.add("world");

    try std.testing.expect(xf.lookup("hello"));
}
