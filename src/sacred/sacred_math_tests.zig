//! SACRED MATH VERIFICATION TESTS
//!
//! Tests for Sacred mathematical constants and operations defined in sacred_types.zig:
//! - Golden ratio (φ = 1.618...)
//! - Sacred identity (φ² + 1/φ² = 3)
//! - Sacred powers (3^k for k = 0, 1, 2...)
//! - Format conversions (GF16 ↔ f32, TF3 ↔ f32)
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const sacred = @import("sacred_types.zig");

// ═════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════ constant and format conversions (GF16 ↔ f32, TF3 ↔ f32) across all Sacred formats

test "Golden ratio: phi value" {
    const phi = sacred.PHI;
    try std.testing.expect(phi > 1.6 and phi < 1.62);
}

test "Golden ratio: phi squared" {
    const phi_sq = sacred.PHI * sacred.PHI;
    const one_over_phi_sq = 1.0 / (sacred.PHI * sacred.PHI);

    // φ² ≈ 2.618 and 1/φ² ≈ 0.382
    try std.testing.expectApproxEqAbs(@as(f32, 2.618), @as(f32, phi_sq), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.382), @as(f32, one_over_phi_sq), 0.001);
}

test "Sacred identity: phi² + 1/phi² = 3" {
    const phi_sq = sacred.PHI * sacred.PHI;
    const one_over_phi_sq = 1.0 / (sacred.PHI * sacred.PHI);
    const identity = phi_sq + one_over_phi_sq;

    // φ² + 1/φ² = 2.618 + 0.382 = 3.0 = TRINITY
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), @as(f32, identity), 0.0001);
}

test "Sacred powers: 3^k" {
    const results = [_]f32{ 1.0, 3.0, 9.0, 27.0, 81.0, 243.0, 729.0 };

    for (0..7) |k| {
        const expected = std.math.pow(f32, 3.0, @floatFromInt(k));
        try std.testing.expectApproxEqAbs(@as(f32, results[k]), @as(f32, expected), 0.01);
    }
}

test "GF16 phi-optimal bit distribution" {
    // GF16: [sign:1][exp:6][mant:9] -> 1/6 exp bias, 0.618 distance
    const expected_distance = @abs(@as(f32, 6.0) / 9.0 - 1.0 / sacred.PHI);
    try std.testing.expectApproxEqAbs(@as(f32, sacred.GF16.phi_distance), @as(f32, expected_distance), 0.01);
}

test "GF16 zero and one" {
    const zero = sacred.GF16.zero();
    const one = sacred.GF16.one();

    try std.testing.expectEqual(@as(f32, 0), zero.toF32());
    try std.testing.expectEqual(@as(f32, 1), one.toF32());
}

test "TF3 zero and one" {
    const zero = sacred.TF3.zero();
    const one = sacred.TF3.one();

    try std.testing.expectEqual(@as(f32, 0), zero.toF32());
    // TF3 has limited precision, use approximate equality
    try std.testing.expectApproxEqAbs(@as(f32, 1), one.toF32(), 0.001);
}

test "TF3 sign encoding" {
    // TF3 getSign: -1 for negative, 0 for zero, +1 for positive

    const minus = sacred.TF3.fromF32(-1.0);
    const zero = sacred.TF3.zero();
    const plus = sacred.TF3.fromF32(1.0);

    try std.testing.expectEqual(@as(i8, -1), minus.getSign());
    try std.testing.expectEqual(@as(i8, 0), zero.getSign());
    try std.testing.expectEqual(@as(i8, 1), plus.getSign());
}

test "Format roundtrip: GF16 f32" {
    const values = [_]f32{ 0.0, 1.0, -1.0, 2.0, 3.14, 100.0, -1000.0 };
    const tolerance = @as(f32, 0.05);

    for (values) |v| {
        const gf = sacred.GF16.fromF32(v);
        const roundtrip = gf.toF32();
        const err = @abs(v - roundtrip) / @abs(v + 0.001);
        try std.testing.expect(err < tolerance);
    }
}

test "Format roundtrip: TF3 f32" {
    const values = [_]f32{ 0.0, 1.0, -1.0, 2.0, 3.14, 100.0, -1000.0 };
    const tolerance = @as(f32, 0.05);

    for (values) |v| {
        const tf = sacred.TF3.fromF32(v);
        const roundtrip = tf.toF32();
        const err = @abs(v - roundtrip) / @abs(v + 0.001);
        try std.testing.expect(err < tolerance);
    }
}

test "GF16 negation" {
    const gf = sacred.GF16.fromF32(-1.5);
    const neg = gf.neg();
    const result = neg.toF32();
    // neg(-1.5) should be 1.5
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), @as(f32, result), 0.1);
}

test "TRINITY constant verification" {
    // Verify TRINITY = 3.0
    try std.testing.expectApproxEqAbs(@as(f32, sacred.TRINITY), @as(f32, 3.0), 0.0001);
}

test "TF3 ternary sign extraction" {
    // TF3 getSign: -1 for negative, 0 for zero, +1 for positive
    const minus_tf = sacred.TF3.fromF32(-1.0);
    const zero_tf = sacred.TF3.zero();
    const plus_tf = sacred.TF3.fromF32(1.0);

    try std.testing.expectEqual(@as(i8, -1), minus_tf.getSign());
    try std.testing.expectEqual(@as(i8, 0), zero_tf.getSign());
    try std.testing.expectEqual(@as(i8, 1), plus_tf.getSign());
}

// φ² + 1/φ² = 3 | TRINITY
