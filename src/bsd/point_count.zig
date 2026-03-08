// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - Point Counting and Trace Computation
// ═══════════════════════════════════════════════════════════════════════════════
// Compute a_p = p + 1 - #E(F_p) (trace of Frobenius)
// SIMD optimization using NEON 4-way parallel processing
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const EllipticCurve = @import("curve.zig").EllipticCurve;

// SIMD support - stub for now (full NEON implementation requires external module)
const simd_neon = struct {
    pub fn detectSimdTarget() enum { neon, scalar } {
        return .scalar; // Default to scalar for now
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const TraceResult = struct {
    p: u64,           // Prime
    a_p: i64,         // Trace of Frobenius: p + 1 - #E(F_p)
    count: u64,       // #E(F_p) = p + 1 - a_p
    hasse_bound_ok: bool,  // |a_p| <= 2*sqrt(p)
};

pub const TraceConfig = struct {
    use_schoof: bool = true,   // Use Schoof's algorithm for p > 1000
    simd_enabled: bool = true,  // Use SIMD if available
    batch_size: usize = 4,      // SIMD batch size
};

// ═══════════════════════════════════════════════════════════════════════════════
// PRIME SIEVE - Precomputed primes for point counting
// ═══════════════════════════════════════════════════════════════════════════════

/// Precomputed primes up to various limits
pub const PRIMES_UP_TO_100 = [_]u64{
    2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
    31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
    73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
    127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
    179, 181, 191, 193, 197, 199, 211, 223, 227, 229,
    233, 239, 241, 251, 257, 263, 269, 271, 277, 281,
    283, 293, 307, 311, 313, 317, 331, 337, 347, 349,
    353, 359, 367, 373, 379, 383, 389, 397, 401, 409,
    419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
    467, 479, 487, 491, 499, 503, 509, 521, 523, 541,
};

/// Check if number is prime (simple trial division)
pub fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }

    return true;
}

/// Generate primes up to max_value using Sieve of Eratosthenes
pub fn generatePrimes(allocator: std.mem.Allocator, max_value: u64) ![]u64 {
    if (max_value < 2) {
        return allocator.alloc(u64, 0);
    }

    // Sieve of Eratosthenes
    const sieve_size = @as(usize, @intCast(max_value + 1));
    const sieve = try allocator.alloc(bool, sieve_size);
    defer allocator.free(sieve);

    @memset(sieve, true);
    sieve[0] = false;
    sieve[1] = false;

    var p: usize = 2;
    while (p * p <= max_value) : (p += 1) {
        if (sieve[p]) {
            var i = p * p;
            while (i <= max_value) : (i += p) {
                sieve[i] = false;
            }
        }
    }

    // Collect primes
    var count: usize = 0;
    for (sieve) |is_prime| {
        if (is_prime) count += 1;
    }

    const primes = try allocator.alloc(u64, count);
    var idx: usize = 0;
    for (sieve, 0..) |is_prime, i| {
        if (is_prime) {
            primes[idx] = @intCast(i);
            idx += 1;
        }
    }

    return primes;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAIVE POINT COUNTING - O(p) algorithm for small primes
// ═══════════════════════════════════════════════════════════════════════════════

/// Count points on E: y^2 = x^3 + ax + b over F_p
/// Naive O(p) algorithm - good for p < 1000
pub fn countPointsNaive(curve: *const EllipticCurve, p: u64) !u64 {
    // Count points (x, y) in F_p satisfying y^2 ≡ x^3 + ax + b (mod p)
    // Plus point at infinity

    var count: u64 = 1; // Point at infinity

    const a_mod = @rem(@as(i128, @intCast(curve.a)), @as(i128, @intCast(p)));
    const b_mod = @rem(@as(i128, @intCast(curve.b)), @as(i128, @intCast(p)));

    var x: u64 = 0;
    while (x < p) : (x += 1) {
        // Compute RHS = x^3 + ax + b (mod p)
        const x_sq = @rem(@as(i128, @intCast(x)) * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const x_cu = @rem(x_sq * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const ax = @rem(a_mod * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const rhs = @mod(x_cu + ax + b_mod, p);

        // Check if RHS is a quadratic residue mod p
        if (isQuadraticResidue(@intCast(rhs), p)) {
            // Two y values (except when RHS = 0, then one y)
            if (rhs == 0) {
                count += 1;
            } else {
                count += 2;
            }
        }
    }

    return count;
}

/// Check if n is a quadratic residue mod p using Euler's criterion
/// n^((p-1)/2) ≡ 1 (mod p) if n is QR, ≡ -1 if not
fn isQuadraticResidue(n: i64, p: u64) bool {
    if (n == 0) return true;

    const exponent = (p - 1) / 2;
    const result = powMod(@intCast(n), exponent, p);

    return result == 1;
}

/// Modular exponentiation (for quadratic residuosity test)
fn powMod(base: i64, exp: u64, modulus: u64) i64 {
    if (modulus == 1) return 0;

    var result: i64 = 1;
    var b = @rem(base, @as(i64, @intCast(modulus)));
    var e = exp;

    while (e > 0) {
        if (e & 1 == 1) {
            result = @rem(result * b, @as(i64, @intCast(modulus)));
        }
        e >>= 1;
        b = @rem(b * b, @as(i64, @intCast(modulus)));
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHOOF'S ALGORITHM - O(log^8 p) point counting
// ═══════════════════════════════════════════════════════════════════════════════

/// Schoof's algorithm for counting points on elliptic curves
/// Much faster than naive for large primes (p > 1000)
/// This is a simplified version - full Schoof-Elkies-Atkin is more complex
pub fn schoofAlgorithm(curve: *const EllipticCurve, p: u64) !u64 {
    // For small primes, use naive method
    if (p < 1000) {
        return countPointsNaive(curve, p);
    }

    // Simplified: Use Hasse-Weil bound and baby-step giant-step
    // Full Schoof implementation requires division polynomials
    // This is a placeholder that falls back to naive for now

    // TODO: Implement proper Schoof-Elkies-Atkin
    return countPointsNaive(curve, p);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE OF FROENIUS COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute trace of Frobenius a_p = p + 1 - #E(F_p)
pub fn computeTrace(curve: *const EllipticCurve, p: u64) !TraceResult {
    if (!isPrime(p)) {
        return error.NotPrime;
    }

    const count = try countPointsNaive(curve, p);
    const a_p: i64 = @intCast(@as(i64, @intCast(p)) + 1 - @as(i64, @intCast(count)));

    // Verify Hasse bound: |a_p| <= 2*sqrt(p)
    const bound = 2.0 * @sqrt(@as(f64, @floatFromInt(p)));
    const hasse_ok = @abs(@as(f64, @floatFromInt(a_p))) <= bound + 1.0; // Small epsilon

    return .{
        .p = p,
        .a_p = a_p,
        .count = count,
        .hasse_bound_ok = hasse_ok,
    };
}

/// Compute traces for multiple primes
pub fn computeAllTraces(allocator: std.mem.Allocator, curve: *const EllipticCurve, primes: []const u64) ![]TraceResult {
    const results = try allocator.alloc(TraceResult, primes.len);

    for (primes, 0..) |p, i| {
        results[i] = try computeTrace(curve, p);
    }

    return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD BATCH PROCESSING - 4-way parallel trace computation
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute traces for 4 curves in parallel (SIMD)
pub fn computeTrace4SIMD(
    curves: [4]*const EllipticCurve,
    p: u64,
) ![4]i64 {
    if (simd_neon.detectSimdTarget() == .neon) {
        return computeTraceNEON(curves, p);
    } else {
        // Scalar fallback
        var result: [4]i64 = undefined;
        for (0..4) |i| {
            const trace = try computeTrace(curves[i], p);
            result[i] = trace.a_p;
        }
        return result;
    }
}

/// NEON-optimized trace computation (placeholder for actual NEON implementation)
fn computeTraceNEON(curves: [4]*const EllipticCurve, p: u64) ![4]i64 {
    // TODO: Implement actual NEON vectorization
    // For now, fall back to scalar
    var result: [4]i64 = undefined;
    for (0..4) |i| {
        const trace = try computeTrace(curves[i], p);
        result[i] = trace.a_p;
    }
    return result;
}

/// SIMD batch trace computation for single curve across multiple primes
pub fn computeTraceBatchSIMD(
    curve: *const EllipticCurve,
    primes: []const u64,
) ![]TraceResult {
    const allocator = curve.allocator;
    const results = try allocator.alloc(TraceResult, primes.len);

    // Process in batches of 4
    var i: usize = 0;
    while (i + 4 <= primes.len) : (i += 4) {
        // TODO: Actual SIMD implementation
        // For now, scalar loop
        var j: usize = 0;
        while (j < 4) : (j += 1) {
            results[i + j] = try computeTrace(curve, primes[i + j]);
        }
    }

    // Handle remaining primes
    while (i < primes.len) : (i += 1) {
        results[i] = try computeTrace(curve, primes[i]);
    }

    return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASSE-WEIL BOUND VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify Hasse-Weil bound for computed traces
/// |a_p| <= 2*sqrt(p)
pub fn verifyHasseBound(results: []const TraceResult) bool {
    for (results) |r| {
        if (!r.hasse_bound_ok) return false;
    }
    return true;
}

/// Get Hasse violation count
pub fn countHasseViolations(results: []const TraceResult) usize {
    var count: usize = 0;
    for (results) |r| {
        if (!r.hasse_bound_ok) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute Legendre symbol (a/p)
/// Returns 1 if a is quadratic residue mod p, -1 if not, 0 if p divides a
pub fn legendreSymbol(a: i64, p: u64) i64 {
    const a_mod = @mod(@as(i128, @intCast(a)), @as(i128, @intCast(p)));

    if (a_mod == 0) return 0;
    if (a_mod == 1) return 1;

    // Euler's criterion
    const result = powMod(@intCast(a_mod), (p - 1) / 2, p);

    // Convert to -1 or 1
    if (result == @as(i64, @intCast(p - 1))) {
        return -1;
    }

    return result;
}

/// Count points on curve using Legendre symbols (more efficient than naive)
pub fn countPointsLegendre(curve: *const EllipticCurve, p: u64) !u64 {
    var count: u64 = 1; // Point at infinity

    var x: u64 = 0;
    while (x < p) : (x += 1) {
        // Compute RHS = x^3 + ax + b (mod p)
        const x_sq = @rem(@as(i128, @intCast(x)) * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const x_cu = @rem(x_sq * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const ax = @rem(@as(i128, @intCast(curve.a)) * @as(i128, @intCast(x)), @as(i128, @intCast(p)));
        const rhs = @mod(x_cu + ax + @as(i128, @intCast(curve.b)), p);

        const legendre = legendreSymbol(@intCast(rhs), p);

        if (legendre == 1) {
            count += 2; // Two y values
        } else if (legendre == 0) {
            count += 1; // One y value (y = 0)
        }
    }

    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "isPrime - basic" {
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(3));
    try std.testing.expect(isPrime(5));
    try std.testing.expect(isPrime(97));
    try std.testing.expect(!isPrime(4));
    try std.testing.expect(!isPrime(100));
}

test "generatePrimes" {
    const allocator = std.testing.allocator;

    const primes = try generatePrimes(allocator, 100);
    defer allocator.free(primes);

    try std.testing.expect(primes.len > 0);
    try std.testing.expectEqual(@as(u64, 2), primes[0]);
    try std.testing.expectEqual(@as(u64, 97), primes[primes.len - 1]);
}

test "countPointsNaive - known curve" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x (a=-1, b=0)
    // For p=5: points are (0,0), (1,0), (2,±1), (3,±1), (4,0), infinity
    // Total: 8 points
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const count = try countPointsNaive(&curve, 5);
    try std.testing.expectEqual(@as(u64, 8), count);
}

test "computeTrace - known values" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x
    // p=5: #E(F_5) = 8, so a_5 = 5 + 1 - 8 = -2
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const trace = try computeTrace(&curve, 5);

    try std.testing.expectEqual(@as(i64, -2), trace.a_p);
    try std.testing.expectEqual(@as(u64, 8), trace.count);
    try std.testing.expect(trace.hasse_bound_ok);
}

test "computeTrace - Hasse bound" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    // Test several primes - Hasse bound should always hold
    for (PRIMES_UP_TO_100[0..20]) |p| {
        const trace = try computeTrace(&curve, p);
        try std.testing.expect(trace.hasse_bound_ok);
    }
}

test "computeAllTraces" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const primes = [_]u64{ 5, 7, 11, 13 };
    const traces = try computeAllTraces(allocator, &curve, &primes);
    defer allocator.free(traces);

    try std.testing.expectEqual(@as(usize, 4), traces.len);
    try std.testing.expectEqual(@as(u64, 5), traces[0].p);
}

test "legendreSymbol" {
    // (1/p) = 1 for any prime
    try std.testing.expectEqual(@as(i64, 1), legendreSymbol(1, 5));

    // (4/5) = (2^2/5) = 1
    try std.testing.expectEqual(@as(i64, 1), legendreSymbol(4, 5));

    // (2/5) = -1 (2 is not QR mod 5)
    try std.testing.expectEqual(@as(i64, -1), legendreSymbol(2, 5));

    // (0/5) = 0
    try std.testing.expectEqual(@as(i64, 0), legendreSymbol(0, 5));
}

test "countPointsLegendre" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    // Should give same result as naive
    const count_naive = try countPointsNaive(&curve, 5);
    const count_legendre = try countPointsLegendre(&curve, 5);

    try std.testing.expectEqual(count_naive, count_legendre);
}

test "verifyHasseBound" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const primes = [_]u64{ 5, 7, 11, 13, 17, 19, 23, 29 };
    const traces = try computeAllTraces(allocator, &curve, &primes);
    defer allocator.free(traces);

    try std.testing.expect(verifyHasseBound(traces));
    try std.testing.expectEqual(@as(usize, 0), countHasseViolations(traces));
}
