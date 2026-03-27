//! tri/vector2d — 2D vector operations
//! TTT Dogfood v0.2 Stage 271

const std = @import("std");

pub const Vec2 = struct {
    x: f64,
    y: f64,

    pub fn add(v1: Vec2, v2: Vec2) Vec2 {
        return .{
            .x = v1.x + v2.x,
            .y = v1.y + v2.y,
        };
    }

    pub fn sub(v1: Vec2, v2: Vec2) Vec2 {
        return .{
            .x = v1.x - v2.x,
            .y = v1.y - v2.y,
        };
    }

    pub fn dot(v1: Vec2, v2: Vec2) f64 {
        return v1.x * v2.x + v1.y * v2.y;
    }

    pub fn length(v: Vec2) f64 {
        return @sqrt(v.x * v.x + v.y * v.y);
    }
};

test "vec2 add" {
    const v1 = Vec2{ .x = 1, .y = 2 };
    const v2 = Vec2{ .x = 3, .y = 4 };
    const result = Vec2.add(v1, v2);
    try std.testing.expectEqual(@as(f64, 4), result.x);
}
