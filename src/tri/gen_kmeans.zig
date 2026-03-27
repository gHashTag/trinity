//! tri/kmeans — K-means clustering
//! TTT Dogfood v0.2 Stage 283

const std = @import("std");

pub const KMeans = struct {
    centroids: std.ArrayList([2]f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, k: usize) !KMeans {
        var centroids = try std.ArrayList([2]f64).initCapacity(allocator, k);
        for (0..k) |_| {
            try centroids.append(allocator, .{ 0, 0 });
        }
        return .{
            .centroids = centroids,
            .allocator = allocator,
        };
    }

    pub fn fit(km: *KMeans, points: []const [2]f64, iterations: usize) !void {
        _ = km;
        _ = points;
        _ = iterations;
    }

    pub fn predict(km: *const KMeans, point: [2]f64) usize {
        _ = km;
        _ = point;
        return 0;
    }

    pub fn deinit(km: *KMeans) void {
        km.centroids.deinit(km.allocator);
    }
};

test "kmeans" {
    var km = try KMeans.init(std.testing.allocator, 2);
    defer km.deinit();
    try std.testing.expectEqual(@as(usize, 2), km.centroids.items.len);
}
