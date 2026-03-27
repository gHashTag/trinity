//! tri/tanh — Hyperbolic tangent
//! TTT Dogfood v0.2 Stage 288

const std = @import("std");

pub fn tanh(x: f64) f64 {
    const e2x = @exp(2 * x);
    return (e2x - 1) / (e2x + 1);
}

pub fn tanhDerivative(x: f64) f64 {
    const t = tanh(x);
    return 1 - t * t;
}

test "tanh" {
    const result = tanh(0);
    try std.testing.expectApproxEqAbs(@as(f64, 0), result, 0.001);
}
