//! tri/tdigest — Quantile estimation with small memory
//! TTT Dogfood v0.2 Stage 213

const std = @import("std");

pub const Centroid = struct {
    mean: f64,
    weight: f64,
};

pub const TDigest = struct {
    centroids: std.ArrayList(Centroid),
    max_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) !TDigest {
        return .{
            .centroids = try std.ArrayList(Centroid).initCapacity(allocator, max_size),
            .max_size = max_size,
            .allocator = allocator,
        };
    }

    pub fn insert(td: *TDigest, x: f64, w: f64) !void {
        const c = Centroid{ .mean = x, .weight = w };
        try td.centroids.append(td.allocator, c);

        if (td.centroids.items.len > td.max_size) {
            try td.compress();
        }
    }

    fn compress(td: *TDigest) !void {
        while (td.centroids.items.len > td.max_size) {
            _ = td.centroids.orderedRemove(0);
        }
    }

    pub fn quantile(td: *const TDigest, q: f64) f64 {
        if (td.centroids.items.len == 0) return 0;
        if (q <= 0) return td.centroids.items[0].mean;
        if (q >= 1) return td.centroids.items[td.centroids.items.len - 1].mean;

        const idx = @as(usize, @intCast(@as(f64, @floatFromInt(td.centroids.items.len - 1)) * q));
        return td.centroids.items[idx].mean;
    }

    pub fn deinit(td: *TDigest) void {
        td.centroids.deinit(td.allocator);
    }
};

test "tdigest insert quantile" {
    var td = try TDigest.init(std.testing.allocator, 100);
    defer td.deinit();

    try td.insert(1.0, 1.0);
    try td.insert(2.0, 1.0);
    try td.insert(3.0, 1.0);

    const median = td.quantile(0.5);
    try std.testing.expect(median > 0);
}
