//! tri/bezier — Bezier curve interpolation
//! Auto-generated from specs/tri/tri_bezier.tri
//! TTT Dogfood v0.2 Stage 160

const std = @import("std");

/// 2D point
pub const Point = struct {
    x: f64,
    y: f64,

    /// Create point
    pub fn init(x: f64, y: f64) Point {
        return .{ .x = x, .y = y };
    }
};

/// Bezier curve
pub const BezierCurve = struct {
    control: []Point,
    degree: usize,
    allocator: std.mem.Allocator,

    /// Free resources
    pub fn deinit(self: *BezierCurve) void {
        self.allocator.free(self.control);
    }

    /// Evaluate curve at parameter t in [0,1]
    pub fn evaluate(curve: *const BezierCurve, t: f64) Point {
        if (t < 0 or t > 1) return .{ .x = 0, .y = 0 };

        var points = curve.control;
        const n = curve.control.len;

        // De Casteljau algorithm
        while (n > 1) : (n -= 1) {
            for (0..n - 1) |i| {
                points[i].x = (1 - t) * points[i].x + t * points[i + 1].x;
                points[i].y = (1 - t) * points[i].y + t * points[i + 1].y;
            }
        }

        return points[0];
    }
};

test "bezier linear" {
    const control = [_]Point{
        Point.init(0, 0),
        Point.init(10, 10),
    };

    var curve = BezierCurve{
        .control = &control,
        .degree = 1,
        .allocator = std.testing.allocator,
    };

    const p0 = curve.evaluate(0);
    const p1 = curve.evaluate(1);
    const p05 = curve.evaluate(0.5);

    try std.testing.expectApproxEqAbs(@as(f64, 0), p0.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), p1.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5), p05.x, 0.001);
}

test "bezier quadratic" {
    const control = [_]Point{
        Point.init(0, 0),
        Point.init(5, 10),
        Point.init(10, 0),
    };

    var curve = BezierCurve{
        .control = &control,
        .degree = 2,
        .allocator = std.testing.allocator,
    };

    const p0 = curve.evaluate(0);
    const p1 = curve.evaluate(1);

    try std.testing.expectApproxEqAbs(@as(f64, 0), p0.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0), p1.y, 0.001);
}

test "bezier cubic" {
    const control = [_]Point{
        Point.init(0, 0),
        Point.init(2.5, 10),
        Point.init(7.5, -10),
        Point.init(10, 0),
    };

    var curve = BezierCurve{
        .control = &control,
        .degree = 3,
        .allocator = std.testing.allocator,
    };

    const p05 = curve.evaluate(0.5);

    // Should be near y=0 at midpoint
    try std.testing.expectApproxEqAbs(@as(f64, 0), p05.y, 1.0);
}
