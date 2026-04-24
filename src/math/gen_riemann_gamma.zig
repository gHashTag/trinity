//! Riemann-γ — Generated from specs/tri/math/math_riemann_gamma.tri
//! φ² + 1/φ² = 3 | TRINITY
//!
//! DO NOT EDIT: This file is generated from math_riemann_gamma.tri spec

const std = @import("std");

// ============================================================================
// CONSTANTS
// ============================================================================

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// π constant
pub const PI: f64 = 3.14159265358979323846;

// ============================================================================
// COMPLEX NUMBER TYPE
// ============================================================================

/// Complex number for zeta function
pub const Complex = struct {
    re: f64,
    im: f64,

    /// Create a complex number from real and imaginary parts
    pub fn init(re: f64, im: f64) Complex {
        return .{ .re = re, .im = im };
    }

    /// Add two complex numbers
    pub fn add(a: Complex, b: Complex) Complex {
        return .{ .re = a.re + b.re, .im = a.im + b.im };
    }

    /// Multiply two complex numbers
    pub fn mul(a: Complex, b: Complex) Complex {
        return .{
            .re = a.re * b.re - a.im * b.im,
            .im = a.re * b.im + a.im * b.re,
        };
    }

    /// Compute magnitude of complex number
    pub fn abs(z: Complex) f64 {
        return @sqrt(z.re * z.re + z.im * z.im);
    }
};

// ============================================================================
// GAMMA FUNCTION
// ============================================================================

/// Gamma function Γ(x) via Lanczos approximation (real arguments only)
/// Uses reflection formula for x < 0.5
pub fn gammaFn(x: f64) f64 {
    // Lanczos approximation coefficients (g=7)
    const p = [_]f64{
        0.99999999999980993,
        676.5203681218851,
        -1259.1392167224028,
        771.32342877765313,
        -176.61502916214059,
        12.507343278686905,
        -0.13857109526572012,
        9.9843695780195716e-6,
        1.5056327351493116e-7,
    };

    if (x < 0.5) {
        // Reflection formula: Γ(x) = π / (sin(πx) × Γ(1-x))
        return PI / (@sin(PI * x) * gammaFn(1.0 - x));
    }

    const x1 = x - 1.0;
    var a = p[0];
    const t = x1 + 7.5; // g + 0.5
    for (1..9) |i| {
        a += p[i] / (x1 + @as(f64, @floatFromInt(i)));
    }

    return @sqrt(2.0 * PI) * std.math.pow(f64, t, x1 + 0.5) * @exp(-t) * a;
}

// ============================================================================
// RIEMANN ZETA FUNCTION
// ============================================================================

/// Riemann zeta function ζ(s) using Dirichlet eta function
/// η(s) = Σ(-1)^(n-1) / n^s
/// ζ(s) = η(s) / (1 - 2^(1-s))
/// For Re(s) < 0: uses functional equation
pub fn zeta(s: Complex, terms: usize) Complex {
    // For Re(s) < 0, use functional equation (real s only for simplicity)
    if (s.re < 0 and @abs(s.im) < 1e-10) {
        // ζ(s) = 2^s × π^(s-1) × sin(πs/2) × Γ(1-s) × ζ(1-s)
        const s_real = s.re;
        const two_s = std.math.pow(f64, 2.0, s_real);
        const pi_s1 = std.math.pow(f64, PI, s_real - 1.0);
        const sin_term = @sin(PI * s_real / 2.0);
        const gamma_term = gammaFn(1.0 - s_real);
        const zeta_1ms = zeta(Complex.init(1.0 - s_real, 0.0), terms);
        const result = two_s * pi_s1 * sin_term * gamma_term * zeta_1ms.re;
        return Complex.init(result, 0.0);
    }

    // Use Dirichlet eta function for better convergence
    var eta = Complex.init(0, 0);
    var sign: f64 = 1.0;

    for (0..terms) |n| {
        const n_f = @as(f64, @floatFromInt(n + 1));

        // Compute n^(-s) = exp(-s * ln(n))
        const log_n = @log(n_f);
        const angle = -s.im * log_n;
        const magnitude = @exp(-s.re * log_n);

        const term = Complex.init(
            magnitude * @cos(angle),
            magnitude * @sin(angle),
        );

        const signed_term = Complex.init(sign * term.re, sign * term.im);
        eta = eta.add(signed_term);
        sign = -sign;
    }

    // Convert eta to zeta: ζ(s) = η(s) / (1 - 2^(1-s))
    const two_pow_re = @exp(@log(2.0) * (1.0 - s.re));
    const two_pow = Complex.init(
        two_pow_re,
        -@log(2.0) * s.im,
    );
    const denominator = Complex.init(1.0 - two_pow.re, -two_pow.im);

    // Complex division: (a+bi)/(c+di) = [(ac+bd) + (bc-ad)i]/(c²+d²)
    const denom_mag_sq = denominator.re * denominator.re + denominator.im * denominator.im;
    return Complex.init(
        (eta.re * denominator.re + eta.im * denominator.im) / denom_mag_sq,
        (eta.im * denominator.re - eta.re * denominator.im) / denom_mag_sq,
    );
}

// ============================================================================
// ZETA ZERO DETECTION
// ============================================================================

/// Check if ζ(s) is close to zero (Riemann zeta zero)
pub fn isZetaZero(s: Complex, tolerance: f64) bool {
    const z = zeta(s, 100);
    return z.abs() < tolerance;
}

// ============================================================================
// PRIME COUNTING FUNCTIONS
// ============================================================================

/// φ-scaled prime number theorem
/// π(x) ≈ x / (φ × ln(x) × (1 - γ))
pub fn primeCountPhi(x: f64) f64 {
    return x / (PHI * @log(x) * (1.0 - GAMMA));
}

/// Standard prime number theorem
/// π(x) ≈ x / ln(x)
pub fn primeCountStandard(x: f64) f64 {
    return x / @log(x);
}

/// γ-corrected prime number theorem
/// π(x) ≈ x / (ln(x) × (1 + γ/√ln(x)))
pub fn primeCountGamma(x: f64) f64 {
    const log_x = @log(x);
    return x / (log_x * (1.0 + GAMMA / @sqrt(log_x)));
}

// ============================================================================
// CRITICAL LINE
// ============================================================================

/// Check if s is on the critical line
/// Critical line: Re(s) = 1/2
pub fn onCriticalLine(s: Complex) bool {
    return @abs(s.re - 0.5) < 1e-10;
}

// ============================================================================
// GAMMA CRITICAL LINE HYPOTHESIS
// ============================================================================

/// γ-hypothesis: Critical line position from φ³
/// The critical line Re(s) = 1/2 emerges from φ³ scaling
/// where φ³ - 4 = γ (approximately)
pub fn gammaCriticalLine() f64 {
    // φ³ ≈ 4.236, so φ³ - 4 ≈ 0.236 = γ
    // The critical line is at 1/2 = 0.5
    // Hypothesis: 1/2 relates to φ³ through γ
    return (PHI_CUBED - 4.0) / GAMMA; // ≈ 1
}

// ============================================================================
// ZERO SPACING
// ============================================================================

/// φ-based zero spacing prediction
/// Adjacent zeros of ζ(s) have average spacing ~ 2π/ln(t)
/// Modified with φ: spacing ~ 2π/(φ × ln(t))
pub fn zeroSpacingPhi(t: f64) f64 {
    return 2.0 * PI / (PHI * @log(t));
}

/// Standard zero spacing
pub fn zeroSpacingStandard(t: f64) f64 {
    return 2.0 * PI / @log(t);
}

// ============================================================================
// TESTS
// ============================================================================

test "Riemann-γ: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(phi_cubed_expected, PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(gamma_expected, GAMMA, 1e-10);

    // φ³ - 4 ≈ γ
    const diff = PHI_CUBED - 4.0;
    try std.testing.expectApproxEqRel(diff, GAMMA, 0.01);
}

test "Riemann-γ: TRINITY identity" {
    try std.testing.expectApproxEqRel(3.0, TRINITY, 1e-10);
}

test "Riemann-γ: zeta of 2" {
    const s = Complex.init(2.0, 0.0);
    const z = zeta(s, 100);

    const expected = PI * PI / 6.0;
    try std.testing.expectApproxEqRel(expected, z.re, 0.01);
}

test "Riemann-γ: zeta of -1" {
    const s = Complex.init(-1.0, 0.0);
    const z = zeta(s, 100);

    const expected = -1.0 / 12.0;
    try std.testing.expectApproxEqRel(expected, z.re, 0.1);
}

test "Riemann-γ: critical line" {
    const on_line = Complex.init(0.5, 14.134725); // First zero
    try std.testing.expect(onCriticalLine(on_line));

    const off_line = Complex.init(0.6, 14.134725);
    try std.testing.expect(!onCriticalLine(off_line));
}

test "Riemann-γ: prime count gamma" {
    // π(100) = 25 primes
    const x = 100.0;

    const standard = primeCountStandard(x);
    const gamma_corrected = primeCountGamma(x);

    // Both should be reasonably close
    const actual = 25.0;
    const error_std = @abs(standard - actual) / actual;
    const error_gamma = @abs(gamma_corrected - actual) / actual;

    // γ-corrected should be better or similar
    try std.testing.expect(error_gamma < error_std + 0.1);
}

test "Riemann-γ: zero spacing" {
    const t = 100.0;

    const standard_spacing = zeroSpacingStandard(t);
    const phi_spacing = zeroSpacingPhi(t);

    // φ-based spacing should be smaller (φ > 1)
    try std.testing.expect(phi_spacing < standard_spacing);

    // Ratio should be ~1/φ
    const ratio = phi_spacing / standard_spacing;
    try std.testing.expectApproxEqRel(ratio, 1.0 / PHI, 0.01);
}

test "Riemann-γ: gamma critical line" {
    const result = gammaCriticalLine();

    // (φ³ - 4)/γ ≈ 1
    try std.testing.expect(result > 0.9);
    try std.testing.expect(result < 1.1);
}
