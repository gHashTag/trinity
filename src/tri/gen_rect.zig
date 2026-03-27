//! tri/rect — Rectangle
//! TTT Dogfood v0.2 Stage 383

const std = @import("std");

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,

    pub fn init(x: f64, y: f64, width: f64, height: f64) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn contains(rect: *const Rect, point: Point) bool {
        return point.x >= rect.x and point.x <= rect.x + rect.width and
            point.y >= rect.y and point.y <= rect.y + rect.height;
    }

    pub fn area(rect: *const Rect) f64 {
        return rect.width * rect.height;
    }
};

test "rect" {
    const rect = Rect.init(0, 0, 10, 10);
    const p = Point{ .x = 5, .y = 5 };
    try std.testing.expect(rect.contains(p));
    try std.testing.expectEqual(@as(f64, 100), rect.area());
}
