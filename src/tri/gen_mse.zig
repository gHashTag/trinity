//! tri/mse — Mean squared error
//! TTT Dogfood v0.2 Stage 290

const std = @import("std");

pub fn mse(predictions: []const f64, targets: []const f64) f64 {
    var sum: f64 = 0;
    for (predictions, targets) |p, t| {
        const diff = p - t;
        sum += diff * diff;
    }
    return sum / @as(f64, @floatFromInt(predictions.len));
}

test "mse" {
    const preds = &[_]f64{ 1, 2, 3 };
    const targets = &[_]f64{ 1, 3, 3 };
    const loss = mse(preds, targets);
    try std.testing.expectApproxEqAbs(@as(f64, 0.333), loss, 0.01);
}
