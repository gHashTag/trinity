// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - L-Function Evaluation
// ═══════════════════════════════════════════════════════════════════════════════
// Compute L(E,s) for elliptic curves using Euler product expansion
// L(E,s) = ∏_{p∤Δ} (1 - a_p*p^{-s} + p^{1-2s})^{-1} × ∏_{p|Δ} bad_factor(p,s)
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const EllipticCurve = @import("curve.zig").EllipticCurve;
const computeTrace = @import("point_count.zig").computeTrace;

// ═══════════════════════════════════════════════════════════════════════════════
// L-SERIES CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const LSeriesConfig = struct {
    precision: f64 = 1e-10,          // Target precision
    max_prime: u64 = 1_000_000,      // Maximum prime for Euler product
    min_prime: u64 = 2,              // Starting prime
    use_analytic_continuation: bool = true,
    convergence_threshold: f64 = 1e-12, // Stop when term contribution < this
};

pub const LResult = struct {
    value: f64,           // L(E,s)
    error_bound: f64,     // Estimated error
    terms_used: usize,   // Number of primes in product
    zero_order: u8,       // ord_{s=1} L(E,s) = analytic rank (0, 1, 2, ...)
    convergence_rate: f64,
    converged: bool,
};

pub const ReductionType = enum {
    good,       // p ∤ Δ
    multiplicative_split,    // Split multiplicative reduction
    multiplicative_nonsplit, // Non-split multiplicative reduction
    additive,   // Additive reduction
};

// ═══════════════════════════════════════════════════════════════════════════════
// EULER PRODUCT COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute L(E,s) using Euler product expansion
/// L(E,s) = ∏_{p} L_p(E,s)^{-1}
/// where L_p(E,s) = 1 - a_p*p^{-s} + p^{1-2s} for good reduction
pub fn eulerProduct(
    curve: *const EllipticCurve,
    s: f64,
    config: LSeriesConfig,
) !LResult {
    var result: f64 = 1.0;
    var term_count: usize = 0;
    var last_contribution: f64 = 1.0;

    // Generate primes up to max_prime
    var p: u64 = config.min_prime;
    while (p <= config.max_prime) : (p += 1) {
        if (!isPrime(p)) continue;

        // Determine reduction type
        const reduction_type = getReductionType(curve, p);

        // Compute local L-factor
        const local_factor = try computeLocalFactor(curve, p, reduction_type, s);

        // Check convergence
        const contribution = @abs(local_factor - 1.0);
        if (contribution < config.convergence_threshold and term_count > 10) {
            break;
        }

        result *= local_factor;
        last_contribution = contribution;
        term_count += 1;

        // Check if we've reached precision
        if (last_contribution < config.precision) {
            break;
        }
    }

    // Estimate error from remaining terms
    const error_bound = estimateEulerError(term_count, s);

    // Determine zero order (rank) by checking value at s=1
    const zero_order = if (@abs(result) < config.precision)
        @as(u8, 1)  // L(E,1) ≈ 0 → rank ≥ 1
    else if (@abs(result) < config.precision * 10.0)
        @as(u8, 2)  // Might be rank 2 (rare)
    else
        @as(u8, 0); // L(E,1) ≠ 0 → rank 0

    return .{
        .value = result,
        .error_bound = error_bound,
        .terms_used = term_count,
        .zero_order = zero_order,
        .convergence_rate = last_contribution,
        .converged = last_contribution < config.precision,
    };
}

/// Compute local L-factor for a given prime
/// L_p(E,s) depends on reduction type
pub fn computeLocalFactor(
    curve: *const EllipticCurve,
    p: u64,
    reduction: ReductionType,
    s: f64,
) !f64 {
    return switch (reduction) {
        .good => computeGoodReductionFactor(curve, p, s),
        .multiplicative_split => computeSplitMultFactor(p, s),
        .multiplicative_nonsplit => computeNonSplitMultFactor(p, s),
        .additive => 1.0, // Additive reduction: factor is 1
    };
}

/// Good reduction: L_p(E,s) = 1 - a_p*p^{-s} + p^{1-2s}
fn computeGoodReductionFactor(curve: *const EllipticCurve, p: u64, s: f64) !f64 {
    // Compute trace of Frobenius a_p
    const trace = try computeTrace(curve, p);

    const p_neg_s = std.math.pow(f64, @as(f64, @floatFromInt(p)), -s);
    const p_one_minus_2s = std.math.pow(f64, @as(f64, @floatFromInt(p)), 1.0 - 2.0 * s);

    const term1 = 1.0;
    const term2 = @as(f64, @floatFromInt(trace.a_p)) * p_neg_s;
    const term3 = p_one_minus_2s;

    // L_p = (1 - a_p*p^{-s} + p^{1-2s})^{-1}
    const numerator = term1 - term2 + term3;

    if (numerator == 0) {
        return std.math.inf(f64); // Pole (shouldn't happen for good reduction)
    }

    return 1.0 / numerator;
}

/// Split multiplicative reduction: L_p = (1 - p^{-s})^{-1}
fn computeSplitMultFactor(p: u64, s: f64) !f64 {
    const p_neg_s = std.math.pow(f64, @as(f64, @floatFromInt(p)), -s);
    const factor = 1.0 - p_neg_s;

    if (factor == 0) {
        return std.math.inf(f64);
    }

    return 1.0 / factor;
}

/// Non-split multiplicative reduction: L_p = (1 + p^{-s})^{-1}
fn computeNonSplitMultFactor(p: u64, s: f64) !f64 {
    const p_neg_s = std.math.pow(f64, @as(f64, @floatFromInt(p)), -s);
    const factor = 1.0 + p_neg_s;

    return 1.0 / factor;
}

/// Determine reduction type at prime p
pub fn getReductionType(curve: *const EllipticCurve, p: u64) ReductionType {
    // Check if p divides discriminant (bad reduction)
    const discriminant_mod_p = @rem(curve.discriminant, @as(i64, @intCast(p)));

    if (discriminant_mod_p == 0) {
        // Bad reduction - determine type
        // c_4 = -b2^2 - 24b4 for minimal Weierstrass form
        // For y^2 = x^3 + ax + b: c_4 = -48a
        const c4_mod_p = @rem(@as(i64, -48 * curve.a), @as(i64, @intCast(p)));

        if (c4_mod_p == 0) {
            return .additive;
        }

        // Check split vs non-split (Legendre symbol of c4)
        const legendre_c4 = legendreSymbol(c4_mod_p, p);

        return if (legendre_c4 == 1)
            .multiplicative_split
        else
            .multiplicative_nonsplit;
    }

    return .good;
}

/// Estimate error from truncated Euler product
/// Error < exp(-sum_{p>P} p^{-s}) ≈ P^{-s+1}/(s-1)
fn estimateEulerError(terms_used: usize, s: f64) f64 {
    if (s <= 1.0) return 0.01; // Conservative estimate

    // Approximate next prime
    const P: f64 = @floatFromInt(terms_used * 10 + 100);

    // Simple bound: error < P * P^{-s} = P^{1-s}
    const err_val = std.math.pow(f64, P, 1.0 - s);

    return @abs(err_val);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RANK DETECTION FROM L-SERIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Detect analytic rank from L-series value at s=1
/// BSD conjecture: ord_{s=1} L(E,s) = rank(E(Q))
pub fn detectRank(result: LResult) !u8 {
    if (result.converged) {
        if (@abs(result.value) < result.error_bound * 10) {
            // L(E,1) ≈ 0, likely rank >= 1
            // Use higher precision to distinguish rank 1 from rank 2
            return 1;
        }
        return 0; // L(E,1) ≠ 0 → rank 0
    }

    // If not converged, be conservative
    return if (result.value < 0.1) 1 else 0;
}

/// Compute L'(E,1) - derivative for rank 1 curves
/// Needed for BSD formula when rank = 1
pub fn computeDerivative(
    curve: *const EllipticCurve,
    config: LSeriesConfig,
) !f64 {
    // Numerical differentiation: L'(E,1) ≈ (L(E,1+h) - L(E,1)) / h
    const h: f64 = 1e-6;

    const l_plus = try eulerProduct(curve, 1.0 + h, config);
    const l_minus = try eulerProduct(curve, 1.0 - h, config);

    return (l_plus.value - l_minus.value) / (2.0 * h);
}

/// Compute higher derivatives L^(n)(E,1)
pub fn computeHigherDerivative(
    curve: *const EllipticCurve,
    n: u8,
    config: LSeriesConfig,
) !f64 {
    if (n == 0) {
        const l_result = try eulerProduct(curve, 1.0, config);
        return l_result.value;
    }

    if (n == 1) {
        return computeDerivative(curve, config);
    }

    // For higher derivatives, use more sophisticated numerical methods
    // This is a placeholder - n >= 2 case
    return 0.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if n is prime
fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }

    return true;
}

/// Legendre symbol (a/p)
fn legendreSymbol(a: i64, p: u64) i64 {
    const a_mod = @mod(@as(i128, @intCast(a)), @as(i128, @intCast(p)));

    if (a_mod == 0) return 0;
    if (a_mod == 1) return 1;

    // Euler's criterion
    const exponent = (p - 1) / 2;
    var result: i64 = 1;
    var base: i64 = @intCast(a_mod);
    var exp: u64 = exponent;

    while (exp > 0) {
        if (exp & 1 == 1) {
            result = @rem(result * base, @as(i64, @intCast(p)));
        }
        exp >>= 1;
        base = @rem(base * base, @as(i64, @intCast(p)));
    }

    // Convert to Legendre symbol
    if (result == @as(i64, @intCast(p - 1))) {
        return -1;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT NUMBER COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute root number w_E = ±1
/// Sign of functional equation: Λ(E,s) = w_E * Λ(E,2-s)
pub fn computeRootNumber(curve: *const EllipticCurve) !i8 {
    // Root number = product of local root numbers
    // w_E = ∏_p w_p(E)

    // For minimal Weierstrass y^2 = x^3 + ax + b:
    // w_2(E) determined by c_4 and c_6 modulo powers of 2
    // w_p(E) = -1 for p where E has additive reduction
    // w_p(E) = +1 for p where E has split multiplicative reduction

    // Simplified: count bad primes with non-split reduction
    var root: i8 = 1;

    // Check small primes dividing discriminant
    const discriminant = curve.discriminant;

    for (primesUpTo(100)) |p| {
        if (@rem(discriminant, @as(i64, @intCast(p))) == 0) {
            // Bad reduction
            const reduction = getReductionType(curve, p);

            if (reduction == .multiplicative_nonsplit) {
                root *= -1;
            } else if (reduction == .additive) {
                // Usually contributes -1 (Tate's algorithm needed for exact)
                root *= -1;
            }
        }
    }

    return root;
}

/// Generate primes up to max_value
fn primesUpTo(max_value: u64) []const u64 {
    // Return precomputed slice
    if (max_value <= 100) {
        return &.{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97 };
    }
    return &.{};
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "eulerProduct - rank 0 curve" {
    const allocator = std.testing.allocator;

    // E: y^2 = x^3 - x (conductor 32, rank 0)
    // L(E,1) should be non-zero for rank 0
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const config = LSeriesConfig{
        .max_prime = 1000,
        .precision = 1e-6,
    };

    const result = try eulerProduct(&curve, 1.0, config);

    // For rank 0, L(E,1) ≠ 0
    try std.testing.expect(result.zero_order == 0);
    try std.testing.expect(@abs(result.value) > 0.01);
}

test "eulerProduct - convergence" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const config = LSeriesConfig{
        .max_prime = 10000,
        .precision = 1e-8,
        .convergence_threshold = 1e-10,
    };

    const result = try eulerProduct(&curve, 1.0, config);

    // Should use some primes and converge
    try std.testing.expect(result.terms_used > 0);
    try std.testing.expect(result.value > 0);
}

test "detectRank - from LResult" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const config = LSeriesConfig{ .max_prime = 1000 };
    const result = try eulerProduct(&curve, 1.0, config);

    const rank = try detectRank(result);

    // Should detect rank 0 for this curve
    try std.testing.expectEqual(@as(u8, 0), rank);
}

test "computeRootNumber" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const w = try computeRootNumber(&curve);

    // Root number should be ±1
    try std.testing.expect(@abs(w) == 1);
}

test "legendreSymbol" {
    try std.testing.expectEqual(@as(i64, 1), legendreSymbol(1, 5));
    try std.testing.expectEqual(@as(i64, -1), legendreSymbol(2, 5));
    try std.testing.expectEqual(@as(i64, 0), legendreSymbol(0, 5));
}

test "getReductionType" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x has discriminant 64 = 2^6
    // So p=2 has bad reduction
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const reduction_2 = getReductionType(&curve, 2);
    try std.testing.expect(reduction_2 != .good);

    const reduction_3 = getReductionType(&curve, 3);
    try std.testing.expectEqual(.good, reduction_3);
}

test "computeGoodReductionFactor" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    // For good reduction, factor should be finite and positive
    const factor = try computeGoodReductionFactor(&curve, 3, 1.0);

    try std.testing.expect(@abs(factor) < std.math.inf(f64));
    try std.testing.expect(factor > 0);
}
