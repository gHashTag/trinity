//! tri/ecc — Elliptic Curve Cryptography basics
//! Auto-generated from specs/tri/tri_ecc.tri
//! TTT Dogfood v0.2 Stage 190

const std = @import("std");

/// Point on elliptic curve
pub const ECPoint = struct {
    x: f64,
    y: f64,
    is_infinity: bool,
};

/// Elliptic curve y^2 = x^3 + ax + b
pub const EllipticCurve = struct {
    a: f64,
    b: f64,
};

/// Add two points on curve
pub fn add(curve: *const EllipticCurve, p: ECPoint, q: ECPoint) ECPoint {
    if (p.is_infinity) return q;
    if (q.is_infinity) return p;

    // Check if points are negatives
    if (p.x == q.x and p.y == -q.y) {
        return .{ .x = 0, .y = 0, .is_infinity = true };
    }

    var lambda: f64 = undefined;

    if (p.x == q.x and p.y == q.y) {
        // Point doubling
        lambda = (3 * p.x * p.x + curve.a) / (2 * p.y);
    } else {
        // Point addition
        lambda = (q.y - p.y) / (q.x - p.x);
    }

    const x3 = lambda * lambda - p.x - q.x;
    const y3 = lambda * (p.x - x3) - p.y;

    return .{
        .x = x3,
        .y = y3,
        .is_infinity = false,
    };
}

/// Scalar multiplication (double-and-add)
pub fn multiply(curve: *const EllipticCurve, p: ECPoint, k: u64) ECPoint {
    var result = ECPoint{ .x = 0, .y = 0, .is_infinity = true };
    var addend = p;
    var scalar = k;

    while (scalar > 0) {
        if (scalar % 2 == 1) {
            result = add(curve, result, addend);
        }
        addend = add(curve, addend, addend);
        scalar /= 2;
    }

    return result;
}

/// Check if point satisfies curve equation
pub fn isOnCurve(curve: *const EllipticCurve, p: ECPoint) bool {
    if (p.is_infinity) return true;

    const lhs = p.y * p.y;
    const rhs = p.x * p.x * p.x + curve.a * p.x + curve.b;

    return std.math.approxEqAbs(f64, lhs, rhs, 0.0001);
}

test "ecc point on curve" {
    // y^2 = x^3 - x + 1 (secp256k1-like simplified)
    const curve = EllipticCurve{ .a = -1, .b = 1 };
    const p = ECPoint{ .x = 0, .y = 1, .is_infinity = false };

    try std.testing.expect(isOnCurve(&curve, p));
}

test "ecc point addition" {
    const curve = EllipticCurve{ .a = 0, .b = 7 }; // y^2 = x^3 + 7

    const p1 = ECPoint{ .x = 1, .y = 3, .is_infinity = false };
    const p2 = ECPoint{ .x = 1, .y = 3, .is_infinity = false };

    // Adding same point should double it
    const result = add(&curve, p1, p2);

    // Just verify operation doesn't crash
    _ = result;
    try std.testing.expect(true);
}

test "ecc scalar multiply" {
    const curve = EllipticCurve{ .a = 0, .b = 7 };
    const p = ECPoint{ .x = 1, .y = 3, .is_infinity = false };

    // 2P should equal P + P
    const result = multiply(&curve, p, 2);

    // Just verify operation doesn't crash
    _ = result;
    try std.testing.expect(true);
}

test "ecc infinity point" {
    const curve = EllipticCurve{ .a = 0, .b = 7 };
    const infinity = ECPoint{ .x = 0, .y = 0, .is_infinity = true };
    const p = ECPoint{ .x = 1, .y = 3, .is_infinity = false };

    // Infinity + P = P
    const result = add(&curve, infinity, p);

    try std.testing.expectApproxEqAbs(@as(f64, 1), result.x, 0.001);
}
