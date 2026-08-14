//! Strand I: Mathematical Foundation
//!
//! Sacred mathematics module for Trinity S³AI.
//!

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — MODULE EXPORT
// ═══════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred = @import("sacred_constants.zig");

// Re-export sacred constants (tri-math migration)
pub const PHI = sacred.PHI;
pub const PHI_SQUARED = sacred.PHI_SQ;
pub const INVERSE_PHI_SQUARED = sacred.PHI_INV_SQ;
pub const TRINITY_SUM = sacred.TRINITY;

// Extended constants (from math_bridge for compatibility)
// Extended constants from sacred_constants.zig
pub const PI = sacred.PI;
pub const E = sacred.E;
pub const TAU = sacred.TAU;
pub const TRANSCENDENTAL = sacred.PI * sacred.PHI;
// Эволюционные константы: commands.zig печатает их в JSON (`mu`,`chi`,`sigma`,
// `epsilon`), но реэкспорта здесь не было — цель `tri` не собиралась.
pub const MU = sacred.MU;
pub const CHI = sacred.CHI;
pub const SIGMA = sacred.SIGMA;
pub const EPSILON = sacred.EPSILON;


pub const format = @import("format.zig");
pub const constants = @import("constants.zig");
pub const eval = @import("eval.zig");
pub const compute = @import("compute.zig");
pub const bench = @import("bench.zig");
pub const identities = @import("identities.zig");
pub const sacred_formula = @import("formula.zig");
pub const gematria_math = @import("gematria.zig");
pub const blind_spots = @import("blind_spots.zig");
pub const gif_generator = @import("gif_generator.zig");

// Fibonacci and Lucas tables
pub const FIBONACCI_TABLE: [20]i64 = .{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181 };
pub const LUCAS_TABLE: [20]i64 = .{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322, 521, 843, 1364, 2207, 3571, 5778, 9349 };

// Compute Fibonacci number
pub fn fibonacci(n: u32) i64 {
    if (n < 20) return FIBONACCI_TABLE[n];

    var a: i64 = FIBONACCI_TABLE[18];
    var b: i64 = FIBONACCI_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// Compute Lucas number
pub fn lucas(n: u32) i64 {
    if (n < 20) return LUCAS_TABLE[n];

    var a: i64 = LUCAS_TABLE[18];
    var b: i64 = LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// φ-spiral
pub const PhiSpiral = struct {
    angle: f64,
    radius: f64,
    x: f64,
    y: f64,
};

pub fn phiSpiral(n: u32) PhiSpiral {
    const nf: f64 = @floatFromInt(n);
    const angle = nf * PHI * PI;
    const radius = 30.0 + nf * 8.0;
    return .{
        .angle = angle,
        .radius = radius,
        .x = radius * @cos(angle),
        .y = radius * @sin(angle),
    };
}

// Golden wrap for tryte arithmetic
pub fn goldenWrap(sum: i16) i8 {
    var result: i16 = sum;
    while (result > 13) result -= 27;
    while (result < -13) result += 27;
    return @intCast(result);
}

// Phi hash
pub fn phiHash(key: u64, shift: u6) u64 {
    const multiplier: u64 = 11400714819323198485; // φ × 2^64
    return (key *% multiplier) >> shift;
}

pub fn phiHashMod(key: u64, table_bits: u6) usize {
    const shift: u6 = @intCast(64 - @as(u7, table_bits));
    return @intCast(phiHash(key, shift));
}

// Version
pub const version = "4.0.0";

// ═════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "module exports" {
    _ = format;
    _ = constants;
    _ = eval;
    _ = compute;
    _ = bench;
    _ = identities;
    _ = sacred_formula;
    _ = gematria_math;
}

test "trinity identity" {
    try std.testing.expectApproxEqAbs(3.0, TRINITY_SUM, 0.001);
}
