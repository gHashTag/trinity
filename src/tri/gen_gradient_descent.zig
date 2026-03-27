//! tri/gradient_descent — Optimization
//! TTT Dogfood v0.2 Stage 290

const std = @import("std");

pub const GradientDescent = struct {
    learning_rate: f64,

    pub fn init(lr: f64) GradientDescent {
        return .{ .learning_rate = lr };
    }

    pub fn step(gd: *const GradientDescent, params: []f64, gradients: []const f64) void {
        const n = @min(params.len, gradients.len);
        for (0..n) |i| {
            params[i] -= gd.learning_rate * gradients[i];
        }
    }
};

test "gradient descent" {
    var gd = GradientDescent.init(0.1);
    var params = [_]f64{ 1, 2 };
    const grads = [_]f64{ 0.1, 0.2 };
    gd.step(&params, &grads);
    try std.testing.expect(params[0] < 1);
}
