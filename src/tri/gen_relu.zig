//! tri/relu — ReLU activation
//! TTT Dogfood v0.2 Stage 287

const std = @import("std");

pub fn relu(x: f64) f64 {
    return if (x > 0) x else 0;
}

pub fn reluDerivative(x: f64) f64 {
    return if (x > 0) 1 else 0;
}

test "relu" {
    try std.testing.expectEqual(@as(f64, 5), relu(5));
    try std.testing.expectEqual(@as(f64, 0), relu(-5));
}
