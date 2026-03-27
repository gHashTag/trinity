//! tri/linear_regression — Linear regression model
//! TTT Dogfood v0.2 Stage 283

const std = @import("std");

pub const LinearRegression = struct {
    slope: f64,
    intercept: f64,

    pub fn init() LinearRegression {
        return .{ .slope = 0, .intercept = 0 };
    }

    pub fn fit(lr: *LinearRegression, x: []const f64, y: []const f64) void {
        if (x.len != y.len) return;

        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_x2: f64 = 0;

        for (x, y) |xi, yi| {
            sum_x += xi;
            sum_y += yi;
            sum_xy += xi * yi;
            sum_x2 += xi * xi;
        }

        const n = @as(f64, @floatFromInt(x.len));
        const slope_num = n * sum_xy - sum_x * sum_y;
        const slope_den = n * sum_x2 - sum_x * sum_x;

        if (slope_den != 0) {
            lr.slope = slope_num / slope_den;
        }

        lr.intercept = (sum_y - lr.slope * sum_x) / n;
    }

    pub fn predict(lr: *const LinearRegression, x: f64) f64 {
        return lr.slope * x + lr.intercept;
    }
};

test "linear regression" {
    var lr = LinearRegression.init();
    lr.fit(&[_]f64{ 1, 2, 3 }, &[_]f64{ 2, 4, 6 });
    try std.testing.expectApproxEqAbs(@as(f64, 2), lr.predict(1), 0.01);
}
