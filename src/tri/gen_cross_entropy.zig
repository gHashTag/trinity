//! tri/cross_entropy — Cross-entropy loss
//! TTT Dogfood v0.2 Stage 289

const std = @import("std");

pub fn crossEntropy(predictions: []const f64, targets: []const f64) f64 {
    var loss: f64 = 0;
    for (predictions, targets) |p, t| {
        loss -= t * @log(p + 1e-10);
    }
    return loss;
}

test "cross entropy" {
    const preds = &[_]f64{ 0.5, 0.5 };
    const targets = &[_]f64{ 1, 0 };
    const loss = crossEntropy(preds, targets);
    try std.testing.expect(loss > 0);
}
