//! tri/transform — 2D transforms
//! TTT Dogfood v0.2 Stage 387

const std = @import("std");

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Transform = struct {
    a: f64,
    b: f64,
    c: f64,
    d: f64,
    tx: f64,
    ty: f64,

    pub fn identity() Transform {
        return .{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 0, .ty = 0 };
    }

    pub fn translate(tx: f64, ty: f64) Transform {
        return .{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = tx, .ty = ty };
    }

    pub fn scale(sx: f64, sy: f64) Transform {
        return .{ .a = sx, .b = 0, .c = 0, .d = sy, .tx = 0, .ty = 0 };
    }

    pub fn rotate(angle: f64) Transform {
        const c = std.math.cos(angle);
        const s = std.math.sin(angle);
        return .{ .a = c, .b = s, .c = -s, .d = c, .tx = 0, .ty = 0 };
    }

    pub fn transformPoint(t: *const Transform, p: Point) Point {
        return .{
            .x = t.a * p.x + t.c * p.y + t.tx,
            .y = t.b * p.x + t.d * p.y + t.ty,
        };
    }
};

test "transform" {
    const t = Transform.translate(10, 20);
    const p = Point{ .x = 0, .y = 0 };
    const tp = t.transformPoint(p);
    try std.testing.expectEqual(@as(f64, 10), tp.x);
}
