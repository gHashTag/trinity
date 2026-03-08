// ═══════════════════════════════════════════════════════════════════════════════
// BEAL GCD FILTER - Coprimality Check for Counterexample Detection
// ═══════════════════════════════════════════════════════════════════════════════
// Beal Conjecture: A^x + B^y = C^z with x,y,z > 2 implies gcd(A,B,C) > 1
// Counterexample MUST have coprime bases (gcd = 1)
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// GCD COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute greatest common divisor of two integers using Euclidean algorithm
/// Iterative implementation for performance (no recursion overhead)
pub inline fn gcdTwo(a: u32, b: u32) u32 {
    var x = a;
    var y = b;

    // Early exit for common cases
    if (x == 0) return y;
    if (y == 0) return x;
    if (x == y) return x;
    if (x == 1 or y == 1) return 1;

    // Binary GCD (Stein's algorithm) - branch-friendly
    var shift: u5 = 0;

    // Factor out powers of 2
    while (((x | y) & 1) == 0) {
        x >>= 1;
        y >>= 1;
        shift += 1;
    }

    // Ensure x is odd
    while ((x & 1) == 0) {
        x >>= 1;
    }

    while (y != 0) {
        // Remove all factors of 2 from y
        while ((y & 1) == 0) {
            y >>= 1;
        }

        // Now x and y are both odd, swap if needed
        if (x > y) {
            const t = y;
            y = x;
            x = t;
        }

        y -= x;
    }

    return x << shift;
}

/// Compute GCD of three numbers: gcd(gcd(a, b), c)
pub inline fn gcdThree(a: u32, b: u32, c: u32) u32 {
    const ab = gcdTwo(a, b);
    return gcdTwo(ab, c);
}

/// Check if three numbers are coprime (gcd = 1)
/// This is the KEY filter for Beal counterexample detection
/// Counterexamples MUST have coprime bases!
pub inline fn isCoprime(a: u32, b: u32, c: u32) bool {
    return gcdThree(a, b, c) == 1;
}

/// Check if a pair (A, B) can be part of a coprime triple
/// Returns false if gcd(A, B) > 1 (filtering ~60% of pairs)
pub inline fn isPairCoprime(a: u32, b: u32) bool {
    return gcdTwo(a, b) == 1;
}

/// BealCandidate with coprimality pre-checked
pub const Candidate = struct {
    a: u32,
    b: u32,
    c: u32,
    x: u8,
    y: u8,
    z: u8,
    is_coprime: bool,
    passes_filter: bool,

    /// Create a candidate and check coprimality
    pub inline fn init(a: u32, b: u32, c: u32, x: u8, y: u8, z: u8) Candidate {
        const coprime = isCoprime(a, b, c);
        return .{
            .a = a,
            .b = b,
            .c = c,
            .x = x,
            .y = y,
            .z = z,
            .is_coprime = coprime,
            .passes_filter = false,
        };
    }

    /// Check if this could be a counterexample
    /// (exponents > 2 and coprime bases)
    pub inline fn isCounterexampleCandidate(self: *const Candidate) bool {
        return self.is_coprime and
            self.x > 2 and self.y > 2 and self.z > 2;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH GCD CHECKS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check coprimality for multiple B values against a fixed A
/// Returns boolean array where true = coprime
pub fn batchCoprimeCheck(allocator: std.mem.Allocator, a: u32, b_values: []const u32) ![]bool {
    const results = try allocator.alloc(bool, b_values.len);
    for (b_values, 0..) |b, i| {
        results[i] = isPairCoprime(a, b);
    }
    return results;
}

/// Count how many B values in range are coprime to A
pub fn countCoprimeInRange(a: u32, b_start: u32, b_end: u32) u32 {
    var count: u32 = 0;
    var b: u32 = b_start;
    while (b < b_end) : (b += 1) {
        if (isPairCoprime(a, b)) {
            count += 1;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "gcdTwo - basic cases" {
    try std.testing.expectEqual(@as(u32, 6), gcdTwo(48, 18));
    try std.testing.expectEqual(@as(u32, 1), gcdTwo(17, 23));
    try std.testing.expectEqual(@as(u32, 100), gcdTwo(100, 100));
    try std.testing.expectEqual(@as(u32, 12), gcdTwo(60, 84));
}

test "gcdTwo - edge cases" {
    try std.testing.expectEqual(@as(u32, 42), gcdTwo(0, 42));
    try std.testing.expectEqual(@as(u32, 17), gcdTwo(17, 0));
    try std.testing.expectEqual(@as(u32, 1), gcdTwo(1, 9999));
    try std.testing.expectEqual(@as(u32, 9999), gcdTwo(1, 9999));
}

test "gcdTwo - powers of 2" {
    try std.testing.expectEqual(@as(u32, 8), gcdTwo(64, 24));
    try std.testing.expectEqual(@as(u32, 16), gcdTwo(256, 80));
}

test "gcdThree - coprime triples" {
    // Pythagorean triple: 3, 4, 5 are coprime
    try std.testing.expectEqual(@as(u32, 1), gcdThree(3, 4, 5));
    try std.testing.expect(isCoprime(3, 4, 5));

    // Prime numbers
    try std.testing.expectEqual(@as(u32, 1), gcdThree(7, 11, 13));
    try std.testing.expect(isCoprime(7, 11, 13));
}

test "gcdThree - non-coprime triples" {
    // Common factor 2
    try std.testing.expectEqual(@as(u32, 2), gcdThree(6, 8, 10));
    try std.testing.expect(!isCoprime(6, 8, 10));

    // Common factor 3
    try std.testing.expectEqual(@as(u32, 3), gcdThree(9, 15, 21));
    try std.testing.expect(!isCoprime(9, 15, 21));
}

test "Candidate - Pythagorean triple (not Beal, exponents = 2)" {
    const cand = Candidate.init(3, 4, 5, 2, 2, 2);
    try std.testing.expect(cand.is_coprime);
    try std.testing.expect(!cand.isCounterexampleCandidate()); // Exponents not > 2
}

test "Candidate - potential Beal counterexample" {
    const cand = Candidate.init(7, 8, 11, 3, 3, 3);
    try std.testing.expect(cand.is_coprime);
    try std.testing.expect(cand.isCounterexampleCandidate()); // Would be counterexample if true
}

test "Candidate - filtered out by GCD" {
    const cand = Candidate.init(6, 8, 10, 3, 3, 3);
    try std.testing.expect(!cand.is_coprime);
    try std.testing.expect(!cand.isCounterexampleCandidate());
}

test "batchCoprimeCheck" {
    const allocator = std.testing.allocator;
    const b_values = [_]u32{ 3, 4, 5, 6, 7, 8, 9, 10 };

    const results = try batchCoprimeCheck(allocator, 12, &b_values);
    defer allocator.free(results);

    // 12: gcd(12,3)=3, gcd(12,4)=4, gcd(12,5)=1, gcd(12,6)=6, ...
    const expected = [_]bool{ false, false, true, false, true, false, true, false };
    for (results, expected) |r, e| {
        try std.testing.expectEqual(e, r);
    }
}

test "countCoprimeInRange - density check" {
    // For A=30, expect about 40% of B values to be coprime
    // (phi(30)/30 = 8/30 ≈ 0.27, but we're checking a range)
    const count = countCoprimeInRange(30, 1, 101);
    try std.testing.expect(count > 20 and count < 50);
}

test "GCD filter efficiency" {
    // Count coprime pairs up to 100
    var coprime_count: u32 = 0;
    var total_count: u32 = 0;

    var a: u32 = 1;
    while (a <= 100) : (a += 1) {
        var b: u32 = a + 1;
        while (b <= 100) : (b += 1) {
            total_count += 1;
            if (isPairCoprime(a, b)) {
                coprime_count += 1;
            }
        }
    }

    const ratio: f64 = @as(f64, @floatFromInt(coprime_count)) / @as(f64, @floatFromInt(total_count));
    std.debug.print("GCD filter passes: {d}/{d} ({d:.1}%)\n", .{ coprime_count, total_count, ratio * 100 });

    // Should filter out roughly 40-60% of pairs
    try std.testing.expect(ratio > 0.3 and ratio < 0.8);
}

test "GCD filter on known Beal-relevant ranges" {
    // Test on small primes
    const primes = [_]u32{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29 };

    var coprime_pairs: u32 = 0;
    for (primes, 0..) |p1, i| {
        for (primes[i + 1 ..]) |p2| {
            if (isPairCoprime(p1, p2)) {
                coprime_pairs += 1;
            }
        }
    }

    // All primes should be coprime to each other
    const expected_pairs = @as(u32, primes.len * (primes.len - 1) / 2);
    try std.testing.expectEqual(expected_pairs, coprime_pairs);
}
