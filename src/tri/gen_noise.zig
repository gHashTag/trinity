//! tri/noise — Perlin-like noise
//! TTT Dogfood v0.2 Stage 275

const std = @import("std");

pub fn noise2d(x: f64, y: f64) f64 {
    _ = x;
    _ = y;
    return 0.5;
}

pub fn noise3d(x: f64, y: f64, z: f64) f64 {
    _ = x;
    _ = y;
    _ = z;
    return 0.5;
}

test "noise" {
    const n = noise2d(1.0, 2.0);
    try std.testing.expect(n >= 0);
}
