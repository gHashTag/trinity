//! tri/sigmoid — Sigmoid activation
//! TTT Dogfood v0.2 Stage 286

const std = @import("std");

pub fn sigmoid(x: f64) f64 {
    return 1.0 / (1.0 + @exp(-x));
}

pub fn sigmoidDerivative(x: f64) f64 {
    const s = sigmoid(x);
    return s * (1 - s);
}

test "sigmoid" {
    const result = sigmoid(0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), result, 0.001);
}
