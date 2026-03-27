//! tri/bezier — Bézier curve
//! TTT Dogfood v0.2 Stage 274

const std = @import("std");

pub const BezierCurve = struct {
    p0: [2]f64,
    p1: [2]f64,
    p2: [2]f64,
    p3: [2]f64,

    pub fn eval(curve: BezierCurve, t: f64) [2]f64 {
        const u = 1 - t;
        return .{
            (u * u * u * curve.p0[0] + 3 * u * u * t * curve.p1[0] + 3 * u * t * t * curve.p2[0] + t * t * t * curve.p3[0]),
            (u * u * u * curve.p0[1] + 3 * u * u * t * curve.p1[1] + 3 * u * t * t * curve.p2[1] + t * t * t * curve.p3[1]),
        };
    }
};

test "bezier" {
    const curve = BezierCurve{
        .p0 = .{ 0, 0 },
        .p1 = .{ 1, 0 },
        .p2 = .{ 0, 1 },
        .p3 = .{ 1, 1 },
    };
    const p = curve.eval(0.5);
    try std.testing.expect(p[0] >= 0 and p[0] <= 1);
}
