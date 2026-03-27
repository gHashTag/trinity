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

        const control_len = curve.control.len;

        // De Casteljau algorithm - work with values directly
        var x_vals: [10]f64 = undefined;
        var y_vals: [10]f64 = undefined;

        for (curve.control, 0..) |p, i| {
            x_vals[i] = p.x;
            y_vals[i] = p.y;
        }

        var n = control_len;

        while (n > 1) {
            for (0..n - 1) |i| {
                x_vals[i] = (1 - t) * x_vals[i] + t * x_vals[i + 1];
                y_vals[i] = (1 - t) * y_vals[i] + t * y_vals[i + 1];
            }
            n -= 1;
        }

        return .{ .x = x_vals[0], .y = y_vals[0] };
    }
};

test "bezier linear" {
    var control_buf = [_]Point{
        Point.init(0, 0),
        Point.init(10, 10),
    };

    var curve1 = BezierCurve{
        .control = &control_buf,
        .degree = 1,
        .allocator = std.testing.allocator,
    };

    const p0 = curve1.evaluate(0);
    const p1 = curve1.evaluate(1);
    const p05_1 = curve1.evaluate(0.5);

    try std.testing.expectApproxEqAbs(@as(f64, 0), p0.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), p1.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 5), p05_1.x, 0.001);

    // Second evaluation with fresh curve
    var curve2 = BezierCurve{
        .control = &control_buf,
        .degree = 1,
        .allocator = std.testing.allocator,
    };

    const p05_2 = curve2.evaluate(0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 5), p05_2.x, 0.001);
}

test "bezier quadratic" {
    var control_buf = [_]Point{
        Point.init(0, 0),
        Point.init(5, 10),
        Point.init(10, 0),
    };

    var curve = BezierCurve{
        .control = &control_buf,
        .degree = 2,
        .allocator = std.testing.allocator,
    };

    const p0 = curve.evaluate(0);
    const p1 = curve.evaluate(1);

    try std.testing.expectApproxEqAbs(@as(f64, 0), p0.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0), p1.y, 0.001);
}

test "bezier cubic" {
    var control_buf = [_]Point{
        Point.init(0, 0),
        Point.init(2.5, 10),
        Point.init(7.5, -10),
        Point.init(10, 0),
    };

    var curve = BezierCurve{
        .control = &control_buf,
        .degree = 3,
        .allocator = std.testing.allocator,
    };

    const p05 = curve.evaluate(0.5);

    // Should be near y=0 at midpoint
    try std.testing.expectApproxEqAbs(@as(f64, 0), p05.y, 1.0);
}
