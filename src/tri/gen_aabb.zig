//! tri/aabb — Axis-aligned bounding box
//! TTT Dogfood v0.2 Stage 279

const std = @import("std");

pub const AABB = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,

    pub fn init(min_x: f64, min_y: f64, max_x: f64, max_y: f64) AABB {
        return .{
            .min_x = min_x,
            .min_y = min_y,
            .max_x = max_x,
            .max_y = max_y,
        };
    }

    pub fn contains(aabb: *const AABB, x: f64, y: f64) bool {
        return x >= aabb.min_x and x <= aabb.max_x and
            y >= aabb.min_y and y <= aabb.max_y;
    }

    pub fn intersects(a: AABB, b: AABB) bool {
        return a.min_x <= b.max_x and a.max_x >= b.min_x and
            a.min_y <= b.max_y and a.max_y >= b.min_y;
    }
};

test "aabb" {
    const aabb = AABB.init(0, 0, 10, 10);
    try std.testing.expect(aabb.contains(5, 5));
}
