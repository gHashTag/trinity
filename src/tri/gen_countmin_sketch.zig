//! tri/countmin_sketch — Probabilistic frequency counting
//! TTT Dogfood v0.2 Stage 211

const std = @import("std");

pub const CountMinSketch = struct {
    table: []std.ArrayList(u64),
    depth: usize,
    width: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, depth: usize, width: usize) !CountMinSketch {
        const table = try allocator.alloc(std.ArrayList(u64), depth);
        for (0..depth) |i| {
            table[i] = try std.ArrayList(u64).initCapacity(allocator, width);
            var j: usize = 0;
            while (j < width) : (j += 1) {
                try table[i].append(allocator, 0);
            }
        }

        return .{
            .table = table,
            .depth = depth,
            .width = width,
            .allocator = allocator,
        };
    }

    fn hash(key: []const u8, seed: u64) u64 {
        var h: u64 = seed;
        for (key) |c| {
            h = h *% 31 +% @as(u64, @intCast(c));
        }
        return h;
    }

    pub fn increment(cms: *CountMinSketch, key: []const u8) !void {
        for (0..cms.depth) |i| {
            const h = hash(key, @as(u64, @intCast(i)));
            const idx = @as(usize, @intCast(h % @as(u64, @intCast(cms.width))));
            cms.table[i].items[idx] += 1;
        }
    }

    pub fn count(cms: *const CountMinSketch, key: []const u8) u64 {
        var min_val: u64 = std.math.maxInt(u64);
        for (0..cms.depth) |i| {
            const h = hash(key, @as(u64, @intCast(i)));
            const idx = @as(usize, @intCast(h % @as(u64, @intCast(cms.width))));
            min_val = @min(min_val, cms.table[i].items[idx]);
        }
        return min_val;
    }

    pub fn deinit(cms: *CountMinSketch) void {
        for (0..cms.depth) |i| {
            cms.table[i].deinit(cms.allocator);
        }
        cms.allocator.free(cms.table);
    }
};

test "countmin sketch increment count" {
    var cms = try CountMinSketch.init(std.testing.allocator, 3, 100);
    defer cms.deinit();

    try cms.increment("hello");
    try cms.increment("hello");
    try cms.increment("hello");

    const count = cms.count("hello");
    try std.testing.expect(count >= 3);
}
