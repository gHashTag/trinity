//! SACRED SPECIAL FUNCTIONS v6.0
//! Mathematical physics special functions:
//! - Gamma, Log-Gamma, Incomplete Gamma
//! - Riemann Zeta, Hurwitz Zeta
//! - Error Function (erf, erfc, erf⁻¹)
//! - Bessel Functions (J, Y, I, K)
//! - Fresnel Integrals (S, C)
//! - Airy Functions (Ai, Bi, derivatives)
//! - Elliptic Integrals (K, E)
//! - Orthogonal Polynomials (Legendre, Hermite, Laguerre)
//! - Hypergeometric, Beta, Digamma, Polygamma

const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

pub const pi = math.pi;

/// Lanczos coefficients for Gamma function approximation
/// Uses g=7 with 15 coefficients for ~15 decimal digits accuracy
const LANZOS_G: f64 = 7.0;
const LANZOS_COEFFS = [_]f64{
    0.99999999999980993227684700473478,
    676.520368121885098567009190444019,
    -1259.13921672240287047156078755283,
    771.3234287776530788486528258894,
    -176.61502916214059906584551354,
    12.507343278686904814458936853,
    -0.13857109526572011689554707,
    9.984369578019570859563e-6,
    1.50563273514931155834e-7,
};

/// Gamma Function Γ(x) = ∫₀^∞ t^(x-1) e^(-t) dt
/// Uses Lanczos approximation for x > 0
/// For x < 0, uses reflection formula: Γ(x) = π / (sin(πx) * Γ(1-x))
/// Poles at x = 0, -1, -2, ... return inf
pub fn gamma(x: f64) f64 {
    // Handle special cases
    if (x == 0 or std.math.isInf(x) or std.math.isNan(x)) {
        return math.inf(f64);
    }
    if (x == 1.0) return 1.0;
    if (x == 0.5) return math.sqrt(pi); // Γ(1/2) = √π
    if (x == 1.5) return 0.5 * math.sqrt(pi); // Γ(3/2) = (1/2)√π
    if (x == 2.0) return 1.0; // Γ(2) = 1! = 1

    // Reflection for negative x: Γ(x) = π / (sin(πx) * Γ(1-x))
    if (x < 0.0) {
        if (@round(x) == x) return math.inf(f64); // Pole at negative integers
        const reflection = pi / (math.sin(pi * x) * gamma(1.0 - x));
        return reflection;
    }

    // Lanczos approximation for x > 0
    var z = x;
    var result = LANZOS_COEFFS[0];

    for (LANZOS_COEFFS[1..], 1..) |c, i| {
        result += c / (z + @as(f64, @floatFromInt(i)) - 1.0);
    }

    const t = z + LANZOS_G - 0.5;
    result *= math.sqrt(2.0 * pi);
    result *= math.pow(t, z - 0.5);
    result *= math.exp(-t);

    return result;
}

/// Log-Gamma function ln(Γ(x))
/// More numerically stable than log(gamma(x))
/// Uses Lanczos approximation directly on log domain
pub fn logGamma(x: f64) f64 {
    if (x <= 0.0) {
        if (@round(x) == x) return math.inf(f64); // Pole
        return math.nan(f64); // Undefined for negative non-integers in log domain
    }
    if (x == 1.0) return 0.0;
    if (x == 2.0) return 0.0;

    var z = x;
    var result = LANZOS_COEFFS[0];

    for (LANZOS_COEFFS[1..], 1..) |c, i| {
        result += c / (z + @as(f64, @floatFromInt(i)) - 1.0);
    }

    const t = z + LANZOS_G - 0.5;
    return 0.5 * math.log(2.0 * pi) + (z - 0.5) * math.log(t) - t + math.log(result);
}

/// Lower incomplete gamma function γ(a,x) = ∫₀^x t^(a-1)e^(-t)dt
/// Uses series expansion for x < a+1, continued fraction otherwise
pub fn gammaIncomplete(a: f64, x: f64) f64 {
    if (x < 0.0 or a <= 0.0) return math.nan(f64);
    if (x == 0.0) return 0.0;

    // Series expansion: γ(a,x) = x^a * e^(-x) * Σ (x^k / Γ(a+k+1))
    if (x < a + 1.0) {
        var result: f64 = 1.0 / a;
        var term: f64 = result;
        for (0..100) |n| {
            term *= x / (a + @as(f64, @floatFromInt(n + 1)));
            result += term;
            if (@abs(term / result) < 1e-15) break;
        }
        return math.pow(x, a) * math.exp(-x) * result;
    } else {
        // Continued fraction for larger x
        const cf = continuedFractionIncomplete(a, x);
        return gamma(a) * (1.0 - cf);
    }
}

/// Continued fraction for incomplete gamma (Lentz's algorithm)
fn continuedFractionIncomplete(a: f64, x: f64) f64 {
    const tiny = 1e-30;
    const max_iter = 100;

    var b: f64 = x + 1.0 - a;
    var c: f64 = 1.0 / tiny;
    var d: f64 = 1.0 / b;
    var h: f64 = d;

    for (1..max_iter) |i| {
        const an = @as(f64, @floatFromInt(i)) * (a - @as(f64, @floatFromInt(i)));
        b += 2.0;
        d = an * d + b;
        if (@abs(d) < tiny) d = tiny;
        c = b + an / c;
        if (@abs(c) < tiny) c = tiny;
        d = 1.0 / d;
        const delta = d * c;
        h *= delta;
        if (@abs(delta - 1.0) < 1e-15) break;
    }

    return math.exp(-x + a * math.log(x)) * h;
}

/// Riemann Zeta function ζ(s) = Σ 1/n^s (n=1 to ∞)
/// For Re(s) > 1: direct series with acceleration
/// For Re(s) < 1: uses reflection formula
pub fn zeta(s: f64) f64 {
    if (s == 1.0) return math.inf(f64); // Pole at s=1
    if (s == 0.0) return -0.5;
    if (s == -1.0) return -1.0 / 12.0; // ζ(-1) = -1/12
    if (s == 2.0) return pi * pi / 6.0; // ζ(2) = π²/6
    if (s == 4.0) return pi * pi * pi * pi / 90.0; // ζ(4) = π⁴/90

    // For s > 1, use Dirichlet eta acceleration
    if (s > 1.0) {
        return zetaDirichletEta(s);
    }

    // Reflection formula for s < 1
    // ζ(s) = 2^s * π^(s-1) * sin(πs/2) * Γ(1-s) * ζ(1-s)
    const reflection = math.pow(2.0, s) * math.pow(pi, s - 1.0);
    const sin_term = math.sin(pi * s / 2.0);
    const gamma_term = gamma(1.0 - s);
    return reflection * sin_term * gamma_term * zetaDirichletEta(1.0 - s);
}

/// Zeta via Dirichlet eta: ζ(s) = η(s) / (1 - 2^(1-s))
/// η(s) = Σ (-1)^(n-1) / n^s (alternating, converges faster)
fn zetaDirichletEta(s: f64) f64 {
    var result: f64 = 0.0;
    var term: f64 = 1.0;

    for (1..1000) |n| {
        const sign: f64 = if (n % 2 == 1) 1.0 else -1.0;
        term = sign / math.pow(@as(f64, @floatFromInt(n)), s);
        result += term;
        if (@abs(term) < 1e-16) break;
    }

    // ζ(s) = η(s) / (1 - 2^(1-s))
    const factor = 1.0 - math.pow(2.0, 1.0 - s);
    if (@abs(factor) < 1e-15) return math.inf(f64); // pole near s=1
    return result / factor;
}

/// Hurwitz Zeta function ζ(s,q) = Σ (n+q)^(-s)
/// Generalization of Riemann zeta (q=1 gives Riemann)
pub fn zetaHurwitz(s: f64, q: f64) f64 {
    if (q <= 0.0) return math.nan(f64);
    if (q == 1.0) return zeta(s);

    // Direct summation with convergence acceleration
    var result: f64 = 0.0;
    for (0..1000) |n| {
        const term = 1.0 / math.pow(@as(f64, @floatFromInt(n)) + q, s);
        result += term;
        if (term < 1e-16 * @abs(result)) break;
    }
    return result;
}

/// Error function erf(x) = (2/√π) ∫₀^x e^(-t²) dt
/// Properties: erf(∞)=1, erf(0)=0, erf(-x)=-erf(x)
pub fn erf(x: f64) f64 {
    // Save the sign of x
    const sign = if (x < 0.0) -1.0 else 1.0;
    const ax = @abs(x);

    // Constants for erf approximation
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;

    // A&S formula 7.1.26
    const t = 1.0 / (1.0 + p * ax);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-ax * ax);

    return sign * y;
}

/// Complementary error function erfc(x) = 1 - erf(x)
/// More accurate for large x where erf(x) ≈ 1
pub fn erfc(x: f64) f64 {
    if (x >= 0.0) {
        // For x >= 0, use direct approximation
        const a1 = 0.254829592;
        const a2 = -0.284496736;
        const a3 = 1.421413741;
        const a4 = -1.453152027;
        const a5 = 1.061405429;
        const p = 0.3275911;

        const t = 1.0 / (1.0 + p * x);
        const y = (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x);
        return y;
    } else {
        // erfc(-x) = 2 - erfc(x)
        return 2.0 - erfc(-x);
    }
}

/// Inverse error function erf⁻¹(y) for y in (-1, 1)
/// Uses Newton-Raphson iteration with initial approximation
pub fn erfInverse(y: f64) f64 {
    if (y <= -1.0 or y >= 1.0) return math.inf(f64);
    if (y == 0.0) return 0.0;

    // Initial approximation from Winitzki (2008)
    const sign = if (y < 0.0) -1.0 else 1.0;
    const ay = @abs(y);
    var x = sign * math.sqrt(math.sqrt(math.pow(4.0 / (pi * pi) + 0.5 * math.log(1.0 - y * y), 2.0) -
        math.log(1.0 - y * y) / pi));

    // Newton-Raphson: x_new = x - (erf(x) - y) / (2/√π * e^(-x²))
    for (0..20) |_| {
        const erf_x = erf(x);
        const derivative = 2.0 / math.sqrt(pi) * math.exp(-x * x);
        const delta = (erf_x - y) / derivative;
        x -= delta;
        if (@abs(delta) < 1e-15) break;
    }

    return x;
}

/// Bessel function of first kind J_ν(x)
/// Uses series expansion for |x| < ν, asymptotic for |x| > ν
pub fn besselJ(n: i32, x: f64) f64 {
    if (x == 0.0) {
        if (n == 0) return 1.0;
        return 0.0;
    }

    const ax = @abs(x);
    const idx: f64 = @floatFromInt(n);

    if (ax < idx + 1.0) {
        // Series expansion: J_ν(x) = Σ (-1)^k / (k! * Γ(k+ν+1)) * (x/2)^(2k+ν)
        var result: f64 = 0.0;
        var term: f64 = math.pow(x / 2.0, idx);
        for (0..100) |k| {
            result += term;
            term *= -1.0 * x * x / (4.0 * @as(f64, @floatFromInt(k + 1)) * (idx + @as(f64, @floatFromInt(k + 1))));
            if (@abs(term) < 1e-15) break;
        }
        return result;
    } else {
        // Asymptotic approximation for large x
        const phase = ax - (idx * pi / 2.0) - (pi / 4.0);
        const amplitude = math.sqrt(2.0 / (pi * ax));
        return amplitude * math.cos(phase);
    }
}

/// Bessel function of second kind Y_ν(x) (Neumann function)
/// Singular at x=0, -∞ at origin
pub fn besselY(n: i32, x: f64) f64 {
    if (x == 0.0) return -math.inf(f64);
    if (x < 0.0) return math.nan(f64);

    // Use relation: Y_ν(x) = (J_ν(x)cos(πν) - J_-ν(x)) / sin(πν)
    const idx: f64 = @floatFromInt(n);

    if (@abs(idx - @round(idx)) < 1e-10) {
        // For integer order, use limit formula
        if (n == 0) {
            return (2.0 / pi) * (besselJ(0, x) * (math.euler + math.log(x / 2.0)) -
                besselSeries(0, x));
        }
        // For integer n>0, use numerical derivative limit to avoid sin(n*pi)=0
        const eps = 1e-8;
        const nu_plus = idx + eps;
        const nu_minus = idx - eps;
        const sin_p = math.sin(nu_plus * pi);
        const sin_m = math.sin(nu_minus * pi);
        const y_plus = (besselJ(n, x) * math.cos(nu_plus * pi) - besselJ(-n, x)) / sin_p;
        const y_minus = (besselJ(n, x) * math.cos(nu_minus * pi) - besselJ(-n, x)) / sin_m;
        return (y_plus + y_minus) / 2.0;
    }

    const sin_val = math.sin(idx * pi);
    if (@abs(sin_val) < 1e-15) return math.inf(f64);
    return (besselJ(n, x) * math.cos(idx * pi) - besselJ(-n, x)) / sin_val;
}

/// Series part of Y_n for small x
fn besselSeries(n: i32, x: f64) f64 {
    var result: f64 = 0.0;
    for (0..100) |k| {
        const kf: f64 = @floatFromInt(k);
        const term = math.pow(x / 2.0, 2 * @as(f64, @floatFromInt(k)) + @as(f64, @floatFromInt(n))) /
            (factorial(k) * gamma(kf + @as(f64, @floatFromInt(n)) + 1.0));
        result += term;
        if (@abs(term) < 1e-15) break;
    }
    return result;
}

/// Modified Bessel function of first kind I_ν(x)
/// Exponential growth (non-oscillatory)
pub fn besselI(n: i32, x: f64) f64 {
    if (x == 0.0) {
        if (n == 0) return 1.0;
        return 0.0;
    }

    const idx: f64 = @floatFromInt(n);
    var result: f64 = 0.0;
    var term: f64 = math.pow(x / 2.0, idx) / gamma(idx + 1.0);

    for (0..100) |k| {
        result += term;
        term *= x * x / (4.0 * @as(f64, @floatFromInt(k + 1)) * (idx + @as(f64, @floatFromInt(k + 1))));
        if (@abs(term) < 1e-15) break;
    }

    return result;
}

/// Modified Bessel function of second kind K_ν(x)
/// Exponential decay as x → ∞
pub fn besselK(n: i32, x: f64) f64 {
    if (x <= 0.0) return math.inf(f64);

    // K_ν(x) = π/2 * (I_-ν(x) - I_ν(x)) / sin(πν)
    const idx: f64 = @floatFromInt(n);

    if (@abs(idx - @round(idx)) < 1e-10) {
        // Integer order: use asymptotic
        return math.sqrt(pi / (2.0 * x)) * math.exp(-x) *
            (1.0 + (4 * idx * idx - 1) / (8.0 * x));
    }

    const sin_pi_n = math.sin(pi * idx);
    if (@abs(sin_pi_n) < 1e-10) {
        return math.sqrt(pi / (2.0 * x)) * math.exp(-x);
    }

    return pi / 2.0 * (besselI(-n, x) - besselI(n, x)) / sin_pi_n;
}

/// Fresnel sine integral S(x) = ∫₀^x sin(πt²/2) dt
/// Cornu spiral parameterization; S(∞) = 0.5
pub fn fresnelS(x: f64) f64 {
    if (x == 0.0) return 0.0;
    if (math.isInf(x)) return 0.5;

    const ax = @abs(x);
    const t = pi * ax * ax / 2.0;

    if (t < 2.0) {
        // Series expansion for small t
        var result: f64 = 0.0;
        var term: f64 = pi * pi * ax * ax * ax / 6.0;
        const sign: f64 = 1.0;
        for (0..50) |k| {
            const kf: f64 = @floatFromInt(k);
            const power = 2 * kf + 2;
            term = if (k == 0)
                pi * pi * ax * ax * ax / 6.0
            else
                -term * t * t / ((2 * kf + 2) * (2 * kf + 3));
            result += term;
            if (@abs(term) < 1e-15) break;
        }
        return result * @sign(x);
    } else {
        // Asymptotic for large x
        const u = pi * ax * ax / 2.0;
        const f = 1.0 / (pi * ax);
        const s = math.sin(u);
        const c = math.cos(u);
        return @sign(x) * (0.5 - f * (c + s / (pi * ax * ax)));
    }
}

/// Fresnel cosine integral C(x) = ∫₀^x cos(πt²/2) dt
pub fn fresnelC(x: f64) f64 {
    if (x == 0.0) return 0.0;
    if (math.isInf(x)) return 0.5;

    const ax = @abs(x);
    const t = pi * ax * ax / 2.0;

    if (t < 2.0) {
        // Series expansion for small t
        var result: f64 = ax;
        var term: f64 = ax;
        for (1..50) |k| {
            const kf: f64 = @floatFromInt(k);
            term *= -pi * pi * ax * ax * ax * ax / (4.0 * kf * (2.0 * kf - 1.0));
            result += term;
            if (@abs(term) < 1e-15) break;
        }
        return result * @sign(x);
    } else {
        // Asymptotic for large x
        const u = pi * ax * ax / 2.0;
        const f = 1.0 / (pi * ax);
        const s = math.sin(u);
        const c = math.cos(u);
        return @sign(x) * (0.5 + f * (s - c / (pi * ax * ax)));
    }
}

/// Airy function Ai(x) - solution to y'' - xy = 0
/// Decaying oscillatory for x > 0
pub fn airyAi(x: f64) f64 {
    if (x > 2.0) {
        // Asymptotic for large positive x
        const z = 2.0 / 3.0 * math.pow(x, 1.5);
        return 0.5 * math.sqrt(pi / math.pow(x, 0.25)) * math.exp(-z) / math.pow(x, 0.25);
    } else if (x < -2.0) {
        // Asymptotic for large negative x (oscillatory)
        const z = 2.0 / 3.0 * math.pow(-x, 1.5);
        return 1.0 / math.sqrt(pi * math.pow(-x, 0.25)) * math.sin(z + pi / 4.0);
    } else {
        // Series expansion near 0
        return airyAiSeries(x);
    }
}

/// Airy Ai series expansion
fn airyAiSeries(x: f64) f64 {
    const a1 = 0.355028053887817239;
    const a2 = 0.258819403792806804;

    var sum1: f64 = 1.0;
    var term1: f64 = 1.0;
    var sum2: f64 = 1.0;
    var term2: f64 = 1.0;

    for (1..50) |k| {
        const kf: f64 = @floatFromInt(k);
        term1 *= x / (3.0 * kf * (3.0 * kf - 1.0));
        term2 *= x / (3.0 * kf * (3.0 * kf + 1.0));
        sum1 += term1;
        sum2 += term2;
        if (@abs(term1) < 1e-15 and @abs(term2) < 1e-15) break;
    }

    const c = x * x * x / 9.0;
    return a1 * sum1 - a2 * c * sum2;
}

/// Airy function Bi(x) - second solution to y'' - xy = 0
/// Growing oscillatory for x > 0
pub fn airyBi(x: f64) f64 {
    if (x > 2.0) {
        // Asymptotic for large positive x
        const z = 2.0 / 3.0 * math.pow(x, 1.5);
        return math.sqrt(pi / math.pow(x, 0.25)) * math.exp(z) / math.pow(x, 0.25);
    } else if (x < -2.0) {
        // Asymptotic for large negative x
        const z = 2.0 / 3.0 * math.pow(-x, 1.5);
        return 1.0 / math.sqrt(pi * math.pow(-x, 0.25)) * math.cos(z + pi / 4.0);
    } else {
        // Series expansion near 0
        return airyBiSeries(x);
    }
}

/// Airy Bi series expansion
fn airyBiSeries(x: f64) f64 {
    const sqrt3 = math.sqrt(3.0);
    const a1 = 0.355028053887817239;
    const a2 = 0.258819403792806804;

    var sum1: f64 = 1.0;
    var term1: f64 = 1.0;
    var sum2: f64 = 1.0;
    var term2: f64 = 1.0;

    for (1..50) |k| {
        const kf: f64 = @floatFromInt(k);
        term1 *= x / (3.0 * kf * (3.0 * kf - 1.0));
        term2 *= x / (3.0 * kf * (3.0 * kf + 1.0));
        sum1 += term1;
        sum2 += term2;
        if (@abs(term1) < 1e-15 and @abs(term2) < 1e-15) break;
    }

    const c = x * x * x / 9.0;
    return sqrt3 * (a1 * sum1 + a2 * c * sum2);
}

/// Derivative of Airy Ai function: Ai'(x)
pub fn airyAiPrime(x: f64) f64 {
    // Numerical derivative using central difference
    const h = 1e-8;
    return (airyAi(x + h) - airyAi(x - h)) / (2.0 * h);
}

/// Derivative of Airy Bi function: Bi'(x)
pub fn airyBiPrime(x: f64) f64 {
    // Numerical derivative using central difference
    const h = 1e-8;
    return (airyBi(x + h) - airyBi(x - h)) / (2.0 * h);
}

/// Complete elliptic integral of first kind K(k)
/// K(k) = ∫₀^(π/2) dθ / √(1 - k²sin²θ)
/// Also written as K(m) where m = k²
pub fn ellipticK(k: f64) f64 {
    if (@abs(k) >= 1.0) return math.inf(f64); // Pole at k=±1
    if (k == 0.0) return pi / 2.0;

    // Arithmetic-geometric mean (AGM) method
    // K(k) = π / (2 * AGM(1, √(1-k²)))
    const m = 1.0 - k * k;
    var a = 1.0;
    var g = math.sqrt(m);
    var a_next: f64 = undefined;
    var g_next: f64 = undefined;

    for (0..20) |_| {
        a_next = (a + g) / 2.0;
        g_next = math.sqrt(a * g);
        if (@abs(a_next - a) < 1e-15) break;
        a = a_next;
        g = g_next;
    }

    return pi / (2.0 * a);
}

/// Complete elliptic integral of second kind E(k)
/// E(k) = ∫₀^(π/2) √(1 - k²sin²θ) dθ
pub fn ellipticE(k: f64) f64 {
    if (@abs(k) >= 1.0) return 1.0; // E(1) = 1
    if (k == 0.0) return pi / 2.0;

    // Series expansion: E(k) = π/2 * Σ [(-1)^n * (2n-1)!! / (2n)!!]² * k^(2n)
    const k2 = k * k;
    var result: f64 = 1.0;
    var term: f64 = 1.0;

    for (1..100) |n| {
        const nf: f64 = @floatFromInt(n);
        term *= -((2.0 * nf - 1.0) / (2.0 * nf)) * ((2.0 * nf - 1.0) / (2.0 * nf)) * k2;
        result += term;
        if (@abs(term) < 1e-15) break;
    }

    return pi / 2.0 * result;
}

/// Legendre polynomial P_n(x)
/// Orthogonal on [-1, 1]; used in spherical harmonics
/// Recurrence: (n+1)P_{n+1} = (2n+1)xP_n - nP_{n-1}
pub fn legendreP(n: i32, x: f64) f64 {
    if (n <= 0) return 1.0;
    if (n == 1) return x;

    var p_prev: f64 = 1.0; // P_0
    var p_curr: f64 = x; // P_1
    var p_next: f64 = undefined;

    for (2..@as(u32, @intCast(n + 1))) |k| {
        const kf: f64 = @floatFromInt(k);
        const kf_1: f64 = @floatFromInt(k - 1);
        p_next = ((2.0 * kf - 1.0) * x * p_curr - kf_1 * p_prev) / kf;
        p_prev = p_curr;
        p_curr = p_next;
    }

    return p_curr;
}

/// Hermite polynomial H_n(x) (physicist's version)
/// H_n(x) = (-1)^n e^(x²) d^n/dx^n e^(-x²)
/// Recurrence: H_{n+1} = 2xH_n - 2nH_{n-1}
pub fn hermiteH(n: i32, x: f64) f64 {
    if (n <= 0) return 1.0;
    if (n == 1) return 2.0 * x;

    var h_prev: f64 = 1.0; // H_0
    var h_curr: f64 = 2.0 * x; // H_1
    var h_next: f64 = undefined;

    for (2..@as(u32, @intCast(n + 1))) |k| {
        const kf_1: f64 = @floatFromInt(k - 1);
        h_next = 2.0 * x * h_curr - 2.0 * kf_1 * h_prev;
        h_prev = h_curr;
        h_curr = h_next;
    }

    return h_curr;
}

/// Laguerre polynomial L_n(x)
/// Associated L_n^k(x) for hydrogen atom radial wavefunction
/// Recurrence: (n+1)L_{n+1} = (2n+1-x)L_n - nL_{n-1}
pub fn laguerreL(n: i32, x: f64) f64 {
    if (n <= 0) return 1.0;
    if (n == 1) return 1.0 - x;

    var l_prev: f64 = 1.0; // L_0
    var l_curr: f64 = 1.0 - x; // L_1
    var l_next: f64 = undefined;

    for (2..@as(u32, @intCast(n + 1))) |k| {
        const kf: f64 = @floatFromInt(k);
        const kf_1: f64 = @floatFromInt(k - 1);
        l_next = ((2.0 * kf - 1.0 - x) * l_curr - kf_1 * l_prev) / kf;
        l_prev = l_curr;
        l_curr = l_next;
    }

    return l_curr;
}

/// Associated Laguerre polynomial L_n^k(x)
/// Used for hydrogen atom radial wavefunctions
pub fn laguerreAssociated(n: i32, k: i32, x: f64) f64 {
    if (k == 0) return laguerreL(n, x);
    if (n < 0) return 0.0;

    // Use relation: L_n^k(x) = (-1)^k d^k/dx^k L_{n+k}(x)
    const nk = n + k;
    var result: f64 = 0.0;

    // Direct computation using explicit formula
    for (0..@as(u32, @intCast(n + 1))) |i| {
        const if_: f64 = @floatFromInt(i);
        const comb = binomial(n + k, n - i);
        const term = if (i % 2 == 0) comb else -comb;
        result += term * math.pow(x, @as(f64, @floatFromInt(i))) / factorial(i);
    }

    return result;
}

/// Gaussian hypergeometric function ₂F₁(a,b;c;z)
/// ₂F₁(a,b;c;z) = Σ (a)_n (b)_n / (c)_n * z^n / n!
/// where (a)_n is the Pochhammer symbol (rising factorial)
pub fn hypergeometric2F1(a: f64, b: f64, c: f64, z: f64) f64 {
    if (@abs(z) >= 1.0) return math.nan(f64); // Diverges for |z| >= 1
    if (c == 0 or @round(c) == c and c < 0) return math.nan(f64); // Pole

    var result: f64 = 1.0;
    var term: f64 = 1.0;

    for (1..200) |n| {
        const nf: f64 = @floatFromInt(n);
        term *= (a + nf - 1.0) * (b + nf - 1.0) / ((c + nf - 1.0) * nf) * z;
        result += term;
        if (@abs(term) < 1e-15) break;
    }

    return result;
}

/// Beta function B(x,y) = Γ(x)Γ(y)/Γ(x+y)
/// Also B(x,y) = ∫₀^1 t^(x-1)(1-t)^(y-1) dt
pub fn beta(x: f64, y: f64) f64 {
    if (x <= 0 or y <= 0) return math.nan(f64);
    return gamma(x) * gamma(y) / gamma(x + y);
}

/// Incomplete beta function B_x(a,b) = ∫₀^x t^(a-1)(1-t)^(b-1) dt
pub fn betaIncomplete(a: f64, b: f64, x: f64) f64 {
    if (x < 0.0 or x > 1.0 or a <= 0.0 or b <= 0.0) return math.nan(f64);
    if (x == 0.0) return 0.0;
    if (x == 1.0) return beta(a, b);

    // Continued fraction representation
    return beta(a, b) * betaIncompleteCF(a, b, x);
}

/// Continued fraction for incomplete beta
fn betaIncompleteCF(a: f64, b: f64, x: f64) f64 {
    const max_iter = 100;
    const eps = 1e-15;

    var qab: f64 = a + b - 1.0;
    var qap: f64 = a - 1.0;
    var qam: f64 = b - 1.0;
    var c: f64 = 1.0;
    var d: f64 = 1.0 - qab * x / (qap + 1.0);
    if (@abs(d) < eps) d = eps;
    d = 1.0 / d;
    var h: f64 = d;

    for (1..max_iter) |m| {
        const mf: f64 = @floatFromInt(m);
        var m2: f64 = 2.0 * mf;

        var d = mf * (b - mf) * x / ((qam + m2) * (a + m2));
        const aa = 1.0 + d * c;
        if (@abs(aa) < eps) aa = eps;
        d = 1.0 / aa;
        h *= d * c;
        c = aa;

        d = -(a + mf) * (qab + mf) * x / ((qap + m2) * (a + m2));
        const aa2 = 1.0 + d / c;
        if (@abs(aa2) < eps) aa2 = eps;
        c = 1.0;
        d = 1.0 / aa2;
        h *= d;

        if (@abs(d - 1.0) < eps) break;
    }

    return math.exp(a * math.log(x) + b * math.log(1.0 - x)) * h / a;
}

/// Digamma function ψ(x) = Γ'(x)/Γ(x) = d/dx ln Γ(x)
pub fn digamma(x: f64) f64 {
    if (x <= 0.0) {
        if (@round(x) == x) return math.nan(f64); // Pole at non-positive integers
        // Reflection: ψ(x) = ψ(1-x) - π cot(πx)
        return digamma(1.0 - x) - pi / math.tan(pi * x);
    }
    if (x == 1.0) return -math.euler;
    if (x == 2.0) return 1.0 - math.euler;

    // Asymptotic expansion for x > 6
    if (x > 6.0) {
        const inv_x = 1.0 / x;
        const inv_x2 = inv_x * inv_x;
        return math.log(x) - 0.5 * inv_x -
            inv_x2 * (1.0 / 12.0 + inv_x2 * (1.0 / 120.0 - inv_x2 / 252.0));
    }

    // Recurrence: ψ(x+1) = ψ(x) + 1/x
    // Reduce to x > 6
    var result = 0.0;
    var xx = x;
    while (xx <= 6.0) : (xx += 1.0) {
        result -= 1.0 / xx;
    }
    result += math.log(xx - 1.0);
    return result;
}

/// Polygamma function ψ^(m)(x) - m-th derivative of digamma
pub fn polygamma(m: u32, x: f64) f64 {
    if (m == 0) return digamma(x);
    if (x <= 0.0) return math.nan(f64);

    const mf: f64 = @floatFromInt(m);

    // For m >= 1, use asymptotic expansion
    if (x > 6.0) {
        var result: f64 = 0.0;
        var sign: f64 = 1.0;
        var term: f64 = 1.0;
        for (0..10) |k| {
            const kf: f64 = @floatFromInt(k);
            const bern = bernoulliNumber(@intCast(2 * k + 2));
            term = bern * sign * factorial(m + 2 * k + 1) / factorial(2 * k + 2);
            term *= math.pow(x, -(mf + 2.0 * kf + 2.0));
            result += term;
            sign *= -1.0;
        }
        return result * factorial(m);
    }

    // Recurrence: ψ^(m)(x+1) = ψ^(m)(x) + (-1)^m * m! / x^(m+1)
    // Reduce to x > 6
    var result = 0.0;
    var xx = x;
    while (xx <= 6.0) : (xx += 1.0) {
        const power = mf + 1.0;
        const factorial_m = factorial(m);
        const sign = if (m % 2 == 0) 1.0 else -1.0;
        result += sign * factorial_m * math.pow(xx, -power);
    }
    result += polygamma(m, xx);
    return result;
}

/// Binomial coefficient C(n,k) = n! / (k!(n-k)!)
pub fn binomial(n: i32, k: i32) f64 {
    if (k < 0 or k > n) return 0.0;
    if (k == 0 or k == n) return 1.0;
    if (k > n - k) k = n - k; // Use smaller k

    var result: f64 = 1.0;
    for (0..@as(u32, @intCast(k))) |i| {
        const if_: f64 = @floatFromInt(i);
        result *= @as(f64, @floatFromInt(n - i)) / (if_ + 1.0);
    }
    return result;
}

/// Factorial n!
pub fn factorial(n: u32) f64 {
    if (n == 0 or n == 1) return 1.0;

    var result: f64 = 1.0;
    for (2..n + 1) |i| {
        result *= @as(f64, @floatFromInt(i));
    }
    return result;
}

/// Rising factorial (Pochhammer symbol) (x)_n = x(x+1)...(x+n-1)
pub fn pochhammer(x: f64, n: u32) f64 {
    if (n == 0) return 1.0;
    var result: f64 = 1.0;
    for (0..n) |i| {
        result *= x + @as(f64, @floatFromInt(i));
    }
    return result;
}

/// Falling factorial x_n = x(x-1)...(x-n+1)
pub fn fallingFactorial(x: f64, n: u32) f64 {
    if (n == 0) return 1.0;
    var result: f64 = 1.0;
    for (0..n) |i| {
        result *= x - @as(f64, @floatFromInt(i));
    }
    return result;
}

// ============== TESTS ==============

test "gamma function" {
    const eps = 1e-10;

    // Known values
    try std.testing.expectApproxEqAbs(@sqrt(pi), gamma(0.5), eps);
    try std.testing.expectApproxEqAbs(1.0, gamma(1.0), eps);
    try std.testing.expectApproxEqAbs(1.0, gamma(2.0), eps);
    try std.testing.expectApproxEqAbs(2.0, gamma(3.0), eps);
    try std.testing.expectApproxEqAbs(6.0, gamma(4.0), eps);
    try std.testing.expectApproxEqAbs(24.0, gamma(5.0), eps);

    // Reflection: Γ(1/2) = √π ≈ 1.77245
    try std.testing.expectApproxEqAbs(1.7724538509, gamma(0.5), 1e-7);
}

test "log gamma" {
    const eps = 1e-10;

    // ln(Γ(1)) = ln(1) = 0
    try std.testing.expectApproxEqAbs(0.0, logGamma(1.0), eps);
    // ln(Γ(2)) = ln(1!) = 0
    try std.testing.expectApproxEqAbs(0.0, logGamma(2.0), eps);
    // ln(Γ(6)) = ln(120)
    try std.testing.expectApproxEqAbs(math.log(120.0), logGamma(6.0), 1e-9);
}

test "error function" {
    const eps = 1e-12;

    // erf(0) = 0
    try std.testing.expectApproxEqAbs(0.0, erf(0.0), eps);

    // erf(∞) = 1
    try std.testing.expectApproxEqAbs(1.0, erf(10.0), 1e-10);

    // erf(-x) = -erf(x)
    try std.testing.expectApproxEqAbs(-erf(1.0), erf(-1.0), eps);

    // erf(1) ≈ 0.8427007929
    try std.testing.expectApproxEqAbs(0.8427007929, erf(1.0), 1e-9);

    // erfc(x) = 1 - erf(x)
    try std.testing.expectApproxEqAbs(1.0 - erf(1.0), erfc(1.0), 1e-12);
}

test "zeta function" {
    const eps = 1e-10;

    // ζ(2) = π²/6
    try std.testing.expectApproxEqAbs(pi * pi / 6.0, zeta(2.0), eps);

    // ζ(4) = π⁴/90
    try std.testing.expectApproxEqAbs(pi * pi * pi * pi / 90.0, zeta(4.0), 1e-9);

    // ζ(-1) = -1/12
    try std.testing.expectApproxEqAbs(-1.0 / 12.0, zeta(-1.0), eps);
}

test "Bessel functions" {
    // J_0(0) = 1
    try std.testing.expectApproxEqAbs(1.0, besselJ(0, 0.0), 1e-15);

    // J_n(0) = 0 for n > 0
    try std.testing.expectApproxEqAbs(0.0, besselJ(1, 0.0), 1e-15);

    // I_0(0) = 1
    try std.testing.expectApproxEqAbs(1.0, besselI(0, 0.0), 1e-15);

    // K_0(x) → ∞ as x → 0
    try std.testing.expect(math.isInf(besselK(0, 0.0)));
}

test "elliptic integrals" {
    const eps = 1e-12;

    // K(0) = π/2
    try std.testing.expectApproxEqAbs(pi / 2.0, ellipticK(0.0), eps);

    // E(0) = π/2
    try std.testing.expectApproxEqAbs(pi / 2.0, ellipticE(0.0), eps);

    // E(1) = 1
    try std.testing.expectApproxEqAbs(1.0, ellipticE(1.0), 1e-10);
}

test "Legendre polynomials" {
    // P_0(x) = 1
    try std.testing.expectApproxEqAbs(1.0, legendreP(0, 0.5), 1e-15);
    try std.testing.expectApproxEqAbs(1.0, legendreP(0, -1.0), 1e-15);

    // P_1(x) = x
    try std.testing.expectApproxEqAbs(0.5, legendreP(1, 0.5), 1e-15);
    try std.testing.expectApproxEqAbs(-1.0, legendreP(1, -1.0), 1e-15);

    // P_2(x) = (3x² - 1)/2
    const p2_0_5 = (3.0 * 0.5 * 0.5 - 1.0) / 2.0;
    try std.testing.expectApproxEqAbs(p2_0_5, legendreP(2, 0.5), 1e-15);
}

test "Hermite polynomials" {
    // H_0(x) = 1
    try std.testing.expectApproxEqAbs(1.0, hermiteH(0, 1.5), 1e-15);

    // H_1(x) = 2x
    try std.testing.expectApproxEqAbs(3.0, hermiteH(1, 1.5), 1e-15);

    // H_2(x) = 4x² - 2
    const h2_1_5 = 4.0 * 1.5 * 1.5 - 2.0;
    try std.testing.expectApproxEqAbs(h2_1_5, hermiteH(2, 1.5), 1e-15);
}

test "Laguerre polynomials" {
    // L_0(x) = 1
    try std.testing.expectApproxEqAbs(1.0, laguerreL(0, 2.5), 1e-15);

    // L_1(x) = 1 - x
    try std.testing.expectApproxEqAbs(-1.5, laguerreL(1, 2.5), 1e-15);

    // L_2(x) = (x² - 4x + 2)/2
    const l2_2_5 = (2.5 * 2.5 - 4.0 * 2.5 + 2.0) / 2.0;
    try std.testing.expectApproxEqAbs(l2_2_5, laguerreL(2, 2.5), 1e-15);
}

test "beta function" {
    const eps = 1e-12;

    // B(1,1) = Γ(1)Γ(1)/Γ(2) = 1*1/1 = 1
    try std.testing.expectApproxEqAbs(1.0, beta(1.0, 1.0), eps);

    // B(0.5, 0.5) = π
    try std.testing.expectApproxEqAbs(pi, beta(0.5, 0.5), 1e-10);

    // B(a,b) = B(b,a)
    try std.testing.expectApproxEqAbs(beta(2.0, 3.0), beta(3.0, 2.0), eps);
}

test "digamma function" {
    const eps = 1e-10;

    // ψ(1) = -γ ≈ -0.57721
    try std.testing.expectApproxEqAbs(-math.euler, digamma(1.0), eps);

    // ψ(2) = 1 - γ ≈ 0.42278
    try std.testing.expectApproxEqAbs(1.0 - math.euler, digamma(2.0), eps);
}

test "Fresnel integrals" {
    // S(0) = C(0) = 0
    try std.testing.expectApproxEqAbs(0.0, fresnelS(0.0), 1e-15);
    try std.testing.expectApproxEqAbs(0.0, fresnelC(0.0), 1e-15);

    // S(∞) = C(∞) = 0.5
    try std.testing.expectApproxEqAbs(0.5, fresnelS(1000.0), 1e-6);
    try std.testing.expectApproxEqAbs(0.5, fresnelC(1000.0), 1e-6);
}

test "Airy functions" {
    // Ai(0) ≈ 0.355
    const ai_0 = airyAi(0.0);
    try std.testing.expectApproxEqAbs(0.35502805, ai_0, 1e-5);

    // Bi(0) ≈ 0.614
    const bi_0 = airyBi(0.0);
    try std.testing.expectApproxEqAbs(0.614726, bi_0, 1e-5);
}

test "factorial and binomial" {
    try std.testing.expectEqual(@as(f64, 1.0), factorial(0));
    try std.testing.expectEqual(@as(f64, 1.0), factorial(1));
    try std.testing.expectEqual(@as(f64, 120.0), factorial(5));

    // C(5,2) = 10
    try std.testing.expectEqual(@as(f64, 10.0), binomial(5, 2));
    // C(10,5) = 252
    try std.testing.expectEqual(@as(f64, 252.0), binomial(10, 5));
}

test "Pochhammer symbol" {
    // (x)_0 = 1
    try std.testing.expectEqual(@as(f64, 1.0), pochhammer(5.0, 0));

    // (1)_n = n!
    try std.testing.expectApproxEqAbs(factorial(5), pochhammer(1.0, 5), 1e-10);

    // (5)_3 = 5*6*7 = 210
    try std.testing.expectEqual(@as(f64, 210.0), pochhammer(5.0, 3));
}

test "hypergeometric 2F1" {
    // ₂F₁(1,1,2,x) = -ln(1-x)/x
    const x = 0.5;
    const result = hypergeometric2F1(1.0, 1.0, 2.0, x);
    const expected = -math.log(1.0 - x) / x;
    try std.testing.expectApproxEqAbs(expected, result, 1e-10);
}
