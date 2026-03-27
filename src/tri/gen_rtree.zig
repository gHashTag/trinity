//! tri/rtree — R-tree spatial index
//! TTT Dogfood v0.2 Stage 201

const std = @import("std");

pub const Rect = struct {
    x_min: f64,
    y_min: f64,
    x_max: f64,
    y_max: f64,

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x_min <= other.x_max and self.x_max >= other.x_min and
            self.y_min <= other.y_max and self.y_max >= other.y_min;
    }
};

pub const RTree = struct {
    rects: std.ArrayList(Rect),
    data: std.ArrayList(?*const anyopaque),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !RTree {
        return .{
            .rects = try std.ArrayList(Rect).initCapacity(allocator, 16),
            .data = try std.ArrayList(?*const anyopaque).initCapacity(allocator, 16),
            .allocator = allocator,
        };
    }

    pub fn insert(rt: *RTree, rect: Rect, datum: ?*const anyopaque) !void {
        try rt.rects.append(rt.allocator, rect);
        try rt.data.append(rt.allocator, datum);
    }

    pub fn search(rt: *const RTree, query: Rect, allocator: std.mem.Allocator) ![]?*const anyopaque {
        var result = try std.ArrayList(?*const anyopaque).initCapacity(allocator, 4);
        defer result.deinit(allocator);

        for (rt.rects.items, rt.data.items) |rect, datum| {
            if (rect.intersects(query)) {
                try result.append(allocator, datum);
            }
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn deinit(rt: *RTree) void {
        rt.rects.deinit(rt.allocator);
        rt.data.deinit(rt.allocator);
    }
};

test "rtree insert search" {
    var rt = try RTree.init(std.testing.allocator);
    defer rt.deinit();

    const d1: i64 = 1;
    const d2: i64 = 2;

    try rt.insert(.{ .x_min = 0, .y_min = 0, .x_max = 10, .y_max = 10 }, &d1);
    try rt.insert(.{ .x_min = 20, .y_min = 20, .x_max = 30, .y_max = 30 }, &d2);

    const results = try rt.search(.{ .x_min = 5, .y_min = 5, .x_max = 15, .y_max = 15 }, std.testing.allocator);
    defer std.testing.allocator.free(results);

    try std.testing.expect(results.len == 1);
}
