// ═══════════════════════════════════════════════════════════════════════════════
// SACRED SEQUENCES — Number Theory Extensions v6.0
// Pell, Tribonacci, Padovan, Perrin, Catalan, Bernoulli, Euler, Motzkin, Narayana
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// PELL NUMBERS: P(n) = 2P(n-1) + P(n-2), P(0)=0, P(1)=1
// Sequence: 0, 1, 2, 5, 12, 29, 70, 169, 408, 985, 2378, 5741...
// Related to √2 approximation: P(n)/P(n-1) → 1+√2
// ═══════════════════════════════════════════════════════════════════════════════

pub const PELL_TABLE: [20]i64 = .{
    0,    1,    2,     5,     12,    29,     70,     169,     408,     985,
    2378, 5741, 13860, 33461, 80782, 195025, 470832, 1136689, 2744210, 6625109,
};

pub fn pell(n: u32) i64 {
    if (n < 20) return PELL_TABLE[n];
    var a: i64 = PELL_TABLE[18];
    var b: i64 = PELL_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| (b * 2);
        a = b;
        b = temp;
    }
    return b;
}

// Pell-Lucas: Q(n) = 2Q(n-1) + Q(n-2), Q(0)=Q(1)=2
pub const PELL_LUCAS_TABLE: [20]i64 = .{
    2,    2,     6,     14,    34,     82,     198,     478,     1154,    2786,
    6726, 16238, 39202, 94642, 228486, 551614, 1331714, 3215042, 7761798, 18748638,
};

pub fn pellLucas(n: u32) i64 {
    if (n < 20) return PELL_LUCAS_TABLE[n];
    var a: i64 = PELL_LUCAS_TABLE[18];
    var b: i64 = PELL_LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| (b * 2);
        a = b;
        b = temp;
    }
    return b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIBONACCI: T(n) = T(n-1) + T(n-2) + T(n-3), T(0)=T(1)=0, T(2)=1
// Sequence: 0, 0, 1, 1, 2, 4, 7, 13, 24, 44, 81, 149, 274, 504, 927...
// Tetranratio → 1.839286 (cubic analog of golden ratio)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRIBONACCI_TABLE: [20]i64 = .{
    0,  0,   1,   1,   2,   4,    7,    13,   24,    44,
    81, 149, 274, 504, 927, 1705, 3136, 5768, 10609, 19513,
};

pub fn tribonacci(n: u32) i64 {
    if (n < 20) return TRIBONACCI_TABLE[n];
    var a: i64 = TRIBONACCI_TABLE[17];
    var b: i64 = TRIBONACCI_TABLE[18];
    var c: i64 = TRIBONACCI_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| b +| c;
        a = b;
        b = c;
        c = temp;
    }
    return c;
}

// Tetranratio (tribonacci constant) ≈ 1.8392867552141612
pub const TETRARATIO: f64 = 1.8392867552141612;

// ═══════════════════════════════════════════════════════════════════════════════
// PADOVAN: P(n) = P(n-2) + P(n-3), P(0)=P(1)=P(2)=1
// Sequence: 1, 1, 1, 2, 2, 3, 4, 5, 7, 9, 12, 16, 21, 28, 37, 49, 65, 86, 114, 151...
// Plastic number ≈ 1.3247 (P(n+1)/P(n) → plastic constant)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PADOVAN_TABLE: [20]i64 = .{
    1,  1,  1,  2,  2,  3,  4,  5,  7,   9,
    12, 16, 21, 28, 37, 49, 65, 86, 114, 151,
};

pub fn padovan(n: u32) i64 {
    if (n < 20) return PADOVAN_TABLE[n];
    var a: i64 = PADOVAN_TABLE[17];
    var b: i64 = PADOVAN_TABLE[18];
    var c: i64 = PADOVAN_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + c; // P(n-2) + P(n-3)
        a = b;
        b = c;
        c = temp;
    }
    return c;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERRIN: P(n) = P(n-2) + P(n-3), P(0)=3, P(1)=0, P(2)=2
// Sequence: 3, 0, 2, 3, 2, 5, 5, 7, 10, 12, 17, 22, 29, 39, 51...
// If n is prime, P(n) is divisible by n (primality test property)
// ═══════════════════════════════════════════════════════════════════════════════

pub const PERRIN_TABLE: [20]i64 = .{
    3,  0,  2,  3,  2,  5,  5,  7,   10,  12,
    17, 22, 29, 39, 51, 68, 90, 119, 158, 209,
};

pub fn perrin(n: u32) i64 {
    if (n < 20) return PERRIN_TABLE[n];
    var a: i64 = PERRIN_TABLE[17];
    var b: i64 = PERRIN_TABLE[18];
    var c: i64 = PERRIN_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a + c; // P(n-2) + P(n-3)
        a = b;
        b = c;
        c = temp;
    }
    return c;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATALAN: C(n) = (2n)! / ((n+1)! n!)
// Sequence: 1, 1, 2, 5, 14, 42, 132, 429, 1430, 4862, 16796, 58786...
// Binary trees, Dyck paths, valid parentheses count
// Formula: C(n) = binomial(2n, n) / (n+1)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CATALAN_TABLE: [20]i64 = .{
    1,     1,     2,      5,      14,      42,      132,      429,       1430,      4862,
    16796, 58786, 208012, 742900, 2674440, 9694845, 35357670, 129644790, 477638700, 1767263190,
};

pub fn catalan(n: u32) i64 {
    if (n < 20) return CATALAN_TABLE[n];
    // Use recurrence: C(n+1) = C(n) * 2(2n+1)/(n+2)
    var result: f64 = @floatFromInt(CATALAN_TABLE[19]);
    var i: u32 = 19;
    while (i < n) : (i += 1) {
        result = result * 2.0 * @as(f64, @floatFromInt(2 * i + 1)) / @as(f64, @floatFromInt(i + 2));
    }
    return @intFromFloat(@round(result));
}

// ═══════════════════════════════════════════════════════════════════════════════
// JACOBSTHAL: J(n) = J(n-1) + 2J(n-2), J(0)=0, J(1)=1
// Sequence: 0, 1, 1, 3, 5, 11, 21, 43, 85, 171, 341, 683, 1365, 2731...
// Formula: J(n) = (2^n - (-1)^n) / 3
// ═══════════════════════════════════════════════════════════════════════════════

pub const JACOBSTHAL_TABLE: [20]i64 = .{
    0,   1,   1,    3,    5,    11,    21,    43,    85,    171,
    341, 683, 1365, 2731, 5461, 10923, 21845, 43691, 87381, 174763,
};

pub fn jacobsthal(n: u32) i64 {
    if (n < 20) return JACOBSTHAL_TABLE[n];
    var a: i64 = JACOBSTHAL_TABLE[18];
    var b: i64 = JACOBSTHAL_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = b + (a * 2);
        a = b;
        b = temp;
    }
    return b;
}

// Jacobsthal-Lucas: j(n) = j(n-1) + 2j(n-2), j(0)=j(1)=2
pub const JACOBSTHAL_LUCAS_TABLE: [20]i64 = .{
    2,    1,    5,    7,    17,    31,    65,    127,    257,    511,
    1025, 2047, 4097, 8191, 16385, 32767, 65537, 131071, 262145, 524287,
};

pub fn jacobsthalLucas(n: u32) i64 {
    if (n < 20) return JACOBSTHAL_LUCAS_TABLE[n];
    var a: i64 = JACOBSTHAL_LUCAS_TABLE[18];
    var b: i64 = JACOBSTHAL_LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = b + (a * 2);
        a = b;
        b = temp;
    }
    return b;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NARAYANA: N(n,k) = (1/n) * C(n,k) * C(n,k-1)
// Catalan decomposition: C(n) = Σ_k N(n,k)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn narayana(n: u32, k: u32) !i64 {
    if (k < 1 or k > n) return error.InvalidK;
    if (n == 0) return 0;
    // N(n,k) = C(n,k) * C(n,k-1) / n
    const c1 = binomial(n, k);
    const c2 = binomial(n, k - 1);
    return c1 * c2 / @as(i64, @intCast(n));
}

// Helper: binomial coefficient nCk
fn binomial(n: u32, k: u32) i64 {
    if (k > n) return 0;
    if (k == 0 or k == n) return 1;
    if (k > n - k) k = n - k;

    var result: i64 = 1;
    var i: u32 = 1;
    while (i <= k) : (i += 1) {
        result = result * (@as(i64, n + 1 - @as(i32, i)) - @as(i64, i + 1)) / @as(i64, i);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOTZKIN: M(n) = M(n-1) + Σ M(i)M(n-2-i)
// Sequence: 1, 1, 2, 4, 9, 21, 51, 127, 323, 835, 2188, 5798...
// Path counting on integer lattice (non-crossing, non-descending)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MOTZKIN_TABLE: [15]i64 = .{
    1, 1, 2, 4, 9, 21, 51, 127, 323, 835, 2188, 5798, 15511, 41835, 113634,
};

pub fn motzkin(n: u32) i64 {
    if (n < 15) return MOTZKIN_TABLE[n];
    // Dynamic programming for larger n
    var dp: [100]i64 = undefined;
    dp[0] = 1;
    dp[1] = 1;
    for (2..@min(n + 1, 100)) |i| {
        var sum: i64 = 0;
        for (0..i - 1) |j| {
            sum += dp[j] * dp[i - 2 - j];
        }
        dp[i] = dp[i - 1] + sum;
    }
    return dp[n];
}

// ═══════════════════════════════════════════════════════════════════════════════
// BERNOULLI NUMBERS B_n (rational)
// B_0=1, B_1=-1/2, B_2=1/6, B_4=-1/30, B_6=1/42, B_8=-1/30, B_10=5/66...
// All odd B_n (n>1) = 0
// Used in sum of powers: Σk^p = B_{p+1}(n+1)/(p+1)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn bernoulli(n: u32) f64 {
    // Direct values for small n
    const values = [_]f64{
        1.0, // B_0
        -0.5, // B_1
        0.1666666667, // B_2 = 1/6
        0.0, // B_3 = 0
        -0.0333333333, // B_4 = -1/30
        0.0, // B_5 = 0
        0.0238095238, // B_6 = 1/42
        0.0, // B_7 = 0
        -0.0333333333, // B_8 = -1/30
        0.0, // B_9 = 0
        0.0757575758, // B_10 = 5/66
    };
    if (n < values.len) return values[n];
    // For larger n, return 0 (odd) or approximate (even)
    if (n % 2 == 1) return 0.0;
    return 0.0; // Simplified for now
}

// ═══════════════════════════════════════════════════════════════════════════════
// EULER NUMBERS E_n (secant/tangent numbers)
// E_0=1, E_2=-1, E_4=5, E_6=-61, E_8=1385, E_10=-50521...
// All odd E_n = 0
// Alternating permutations, sec(x) expansion
// ═══════════════════════════════════════════════════════════════════════════════

pub fn euler(n: u32) i64 {
    if (n % 2 == 1) return 0;
    const values = [_]i64{
        1, // E_0
        0, // E_1 = 0
        -1, // E_2
        0, // E_3 = 0
        5, // E_4
        0, // E_5 = 0
        -61, // E_6
        0, // E_7 = 0
        1385, // E_8
        0, // E_9 = 0
        -50521, // E_10
    };
    if (n < values.len) return values[n];
    return 0; // Simplified
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "pell numbers" {
    try std.testing.expectEqual(@as(i64, 0), pell(0));
    try std.testing.expectEqual(@as(i64, 1), pell(1));
    try std.testing.expectEqual(@as(i64, 2), pell(2));
    try std.testing.expectEqual(@as(i64, 5), pell(3));
    try std.testing.expectEqual(@as(i64, 12), pell(4));
    try std.testing.expectEqual(@as(i64, 29), pell(5));
}

test "tribonacci" {
    try std.testing.expectEqual(@as(i64, 0), tribonacci(0));
    try std.testing.expectEqual(@as(i64, 0), tribonacci(1));
    try std.testing.expectEqual(@as(i64, 1), tribonacci(2));
    try std.testing.expectEqual(@as(i64, 1), tribonacci(3));
    try std.testing.expectEqual(@as(i64, 2), tribonacci(4));
    try std.testing.expectEqual(@as(i64, 4), tribonacci(5));
}

test "padovan" {
    try std.testing.expectEqual(@as(i64, 1), padovan(0));
    try std.testing.expectEqual(@as(i64, 1), padovan(1));
    try std.testing.expectEqual(@as(i64, 1), padovan(2));
    try std.testing.expectEqual(@as(i64, 2), padovan(3));
    try std.testing.expectEqual(@as(i64, 2), padovan(4));
}

test "perrin" {
    try std.testing.expectEqual(@as(i64, 3), perrin(0));
    try std.testing.expectEqual(@as(i64, 0), perrin(1));
    try std.testing.expectEqual(@as(i64, 2), perrin(2));
    try std.testing.expectEqual(@as(i64, 3), perrin(3));
    try std.testing.expectEqual(@as(i64, 2), perrin(4));
}

test "catalan" {
    try std.testing.expectEqual(@as(i64, 1), catalan(0));
    try std.testing.expectEqual(@as(i64, 1), catalan(1));
    try std.testing.expectEqual(@as(i64, 2), catalan(2));
    try std.testing.expectEqual(@as(i64, 5), catalan(3));
    try std.testing.expectEqual(@as(i64, 14), catalan(4));
}

test "jacobsthal" {
    try std.testing.expectEqual(@as(i64, 0), jacobsthal(0));
    try std.testing.expectEqual(@as(i64, 1), jacobsthal(1));
    try std.testing.expectEqual(@as(i64, 1), jacobsthal(2));
    try std.testing.expectEqual(@as(i64, 3), jacobsthal(3));
    try std.testing.expectEqual(@as(i64, 5), jacobsthal(4));
}

test "narayana" {
    try std.testing.expectEqual(@as(i64, 1), try narayana(1, 1));
    try std.testing.expectEqual(@as(i64, 1), try narayana(2, 1));
    try std.testing.expectEqual(@as(i64, 1), try narayana(2, 2));
    try std.testing.expectEqual(@as(i64, 2), try narayana(3, 1));
}

test "motzkin" {
    try std.testing.expectEqual(@as(i64, 1), motzkin(0));
    try std.testing.expectEqual(@as(i64, 1), motzkin(1));
    try std.testing.expectEqual(@as(i64, 2), motzkin(2));
    try std.testing.expectEqual(@as(i64, 4), motzkin(3));
}

test "bernoulli" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), bernoulli(0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, -0.5), bernoulli(1), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 6.0), bernoulli(2), 0.001);
}

test "euler" {
    try std.testing.expectEqual(@as(i64, 1), euler(0));
    try std.testing.expectEqual(@as(i64, -1), euler(2));
    try std.testing.expectEqual(@as(i64, 5), euler(4));
}
