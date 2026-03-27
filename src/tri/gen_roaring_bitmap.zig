//! tri/roaring_bitmap — Compressed bitmap for sets
//! TTT Dogfood v0.2 Stage 217

const std = @import("std");

pub const RoaringBitmap = struct {
    containers: std.ArrayList(u64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !RoaringBitmap {
        return .{
            .containers = try std.ArrayList(u64).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn add(rb: *RoaringBitmap, value: u32) !void {
        const container_idx = value / 64;
        const bit_idx = value % 64;

        while (rb.containers.items.len <= container_idx) {
            try rb.containers.append(rb.allocator, 0);
        }

        rb.containers.items[container_idx] |= @as(u64, 1) << bit_idx;
    }

    pub fn contains(rb: *const RoaringBitmap, value: u32) bool {
        const container_idx = value / 64;
        if (container_idx >= rb.containers.items.len) return false;

        const bit_idx = value % 64;
        return (rb.containers.items[container_idx] & (@as(u64, 1) << bit_idx)) != 0;
    }

    pub fn count(rb: *const RoaringBitmap) usize {
        var count: usize = 0;
        for (rb.containers.items) |c| {
            count += @popCount(c);
        }
        return count;
    }

    pub fn deinit(rb: *RoaringBitmap) void {
        rb.containers.deinit(rb.allocator);
    }
};

test "roaring bitmap add contains" {
    var rb = try RoaringBitmap.init(std.testing.allocator);
    defer rb.deinit();

    try rb.add(5);
    try rb.add(100);
    try rb.add(5);

    try std.testing.expect(rb.contains(5));
    try std.testing.expect(rb.contains(100));
    try std.testing.expect(!rb.contains(99));

    try std.testing.expectEqual(@as(usize, 2), rb.count());
}
