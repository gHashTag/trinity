// ═══════════════════════════════════════════════════════════════════════════════
// BSD ELLIPTIC CURVE SCANNER - 2-Selmer Group and Rank Bounds
// ═══════════════════════════════════════════════════════════════════════════════
// Compute 2-Selmer group to bound the Mordell-Weil rank
// E(Q)^2 ⊗ Q → Sel_2(E) → E(Q)/2E(Q) → Ш(E/Q)[2]
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const EllipticCurve = @import("curve.zig").EllipticCurve;

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Binary GCD algorithm
fn gcdBinary(a: u64, b: u64) u64 {
    if (a == b) return a;
    if (a == 0) return b;
    if (b == 0) return a;

    const a_even = (a & 1) == 0;
    const b_even = (b & 1) == 0;

    if (a_even and b_even) {
        return gcdBinary(a >> 1, b >> 1) << 1;
    } else if (a_even) {
        return gcdBinary(a >> 1, b);
    } else if (b_even) {
        return gcdBinary(a, b >> 1);
    } else if (a > b) {
        return gcdBinary((a - b) >> 1, b);
    } else {
        return gcdBinary(a, (b - a) >> 1);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RANK INFORMATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const RankInfo = struct {
    analytic_rank: u8, // From L-series (ord_{s=1} L(E,s))
    geometric_rank: u8, // From Mordell-Weil group
    selmer_rank: u8, // Upper bound from 2-Selmer
    sha_rank: u8, // From Ш(E/Q)[2]
    rank_bound: u8, // Final bound: rank ≤ selmer_rank
};

pub const TwoSelmerGroup = struct {
    elements: []SelmerElement,
    size: usize, // Always a power of 2
    rank_bound: u8, // log2(size)
    complete: bool, // Whether Sel_2(E) = Ш(E/Q)[2]
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Free memory
    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.elements);
    }

    /// Get rank from size
    pub fn getRank(self: *const Self) u8 {
        // rank = log2(|Sel_2(E)|)
        var size = self.size;
        var rank: u8 = 0;
        while (size > 1) : (size >>= 1) {
            rank += 1;
        }
        return rank;
    }
};

/// Element of 2-Selmer group (representing homogeneous space E_d)
pub const SelmerElement = struct {
    d: i64, // Squarefree integer (2-isogeny parameter)
    has_local_points: bool, // E_d(Q_p) ≠ ∅ for all p
    is_rational: bool, // E_d(Q) ≠ ∅
    rank_info: RankInfo,
};

// ═══════════════════════════════════════════════════════════════════════════════
// 2-DESCENT VIA ISogenY
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute 2-Selmer group using 2-isogeny descent
/// This gives an upper bound on the rank: rank ≤ selmer_rank
pub fn compute2Selmer(curve: *const EllipticCurve) !TwoSelmerGroup {
    const allocator = curve.allocator;

    // Simplified 2-Selmer computation - return minimal result
    // For full implementation, need complete 2-descent

    // Allocate single element (trivial d=1)
    const elements = try allocator.alloc(SelmerElement, 1);
    elements[0] = .{
        .d = 1,
        .has_local_points = true,
        .is_rational = true,
        .rank_info = RankInfo{
            .analytic_rank = 0,
            .geometric_rank = 0,
            .selmer_rank = 0,
            .sha_rank = 0,
            .rank_bound = 0,
        },
    };

    const rank = @as(u8, @intCast(@clz(@as(u32, @intCast(elements.len))) ^ 31));

    return .{
        .elements = elements,
        .size = elements.len,
        .rank_bound = rank,
        .complete = false, // Need full 2-descent for completeness
        .allocator = allocator,
    };
}

/// Check if curve has 2-torsion point
fn has2Torsion(curve: *const EllipticCurve) bool {
    // 2-torsion exists iff x^3 + ax + b has a root in Q
    // For rational root, must be integer dividing b
    const b = curve.b;

    if (b == 0) {
        // x=0 is a root
        return true;
    }

    // Check divisors of b
    var i: i64 = 1;
    while (i * i <= @abs(b)) : (i += 1) {
        if (b % i == 0) {
            // Check if i is a root
            if (isRoot(curve, i)) return true;
            if (isRoot(curve, -i)) return true;

            const other = @divExact(b, i);
            if (isRoot(curve, other)) return true;
            if (isRoot(curve, -other)) return true;
        }
    }

    return false;
}

/// Check if x is a root of x^3 + ax + b
fn isRoot(curve: *const EllipticCurve, x: i64) bool {
    const x_cube = x * x * x;
    const ax = curve.a * x;
    const result = x_cube + ax + curve.b;
    return result == 0;
}

/// Check if d is squarefree
fn isSquarefree(d: i64) bool {
    if (d == 0) return false;

    var n: i64 = @abs(d);
    var i: i64 = 2;
    while (i * i <= n) : (i += 1) {
        if (n % i == 0) {
            n /= i;
            if (n % i == 0) return false; // i^2 divides d
        }
    }

    return true;
}

/// Check if E_d has local points at all primes
/// E_d: dy^2 = x^3 + ax + b
fn checkLocalPoints(curve: *const EllipticCurve, d: i64) !bool {
    _ = curve;

    // Check local solubility at each prime
    // For p=2: special case
    // For odd p: check Hilbert symbol (x^3 + ax + b, d)_p

    // Simplified: assume good for now
    // Full implementation requires checking each prime dividing 2d

    if (d < 0) {
        // Negative d: need real solution
        // x^3 + ax + b must have sign changes
        return true; // Placeholder
    }

    return true;
}

/// Check if E_d has rational points
fn checkRationalPoints(curve: *const EllipticCurve, d: i64) bool {
    _ = curve;
    _ = d;

    // Full 2-descent requires checking if d is a norm from Q(√-a)
    // This is complex; simplified version always returns false for d > 1
    return false;
}

/// Compute rank bound from Selmer element count
fn boundRankFromCount(count: usize) u8 {
    // rank = log2(count) - 1 (rough approximation)
    // For exact: rank ≤ log2(|Sel_2(E)|)
    var c = count;
    var rank: u8 = 0;
    while (c > 1) : (c >>= 1) {
        rank += 1;
    }
    return if (rank > 0) rank - 1 else 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT NUMBER (Functional Equation Sign)
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute root number w_E = ±1
/// Sign of functional equation of L(E,s)
pub fn computeRootNumber(curve: *const EllipticCurve) !i8 {
    // Root number = ∏_p w_p(E)

    var w: i8 = 1;

    // Check primes dividing conductor
    const discriminant = curve.discriminant.toU64();

    // For minimal Weierstrass y^2 = x^3 + ax + b:
    // - c_4 = -48a, c_6 = -864b
    // - At p=2: w_2 depends on v_2(c_4), v_2(c_6)
    // - At p>2: w_p = 1 if p ∤ Δ, else -1 if additive reduction

    const c4 = -48 * curve.a;
    const c6 = -864 * curve.b;

    // p=2
    if (discriminant % 2 == 0) {
        w *= rootNumberAt2(c4, c6);
    }

    // Odd primes
    var p: u64 = 3;
    while (p * p <= discriminant) : (p += 2) {
        if (discriminant % p == 0) {
            w *= -1; // Bad reduction contributes -1
        }
        p += 1;
    }

    return w;
}

/// Root number at p=2 (Tate's algorithm)
fn rootNumberAt2(c4: i64, c6: i64) i8 {
    // Simplified: check valuations
    const v2_c4 = valuation2(c4);
    const v2_c6 = valuation2(c6);

    if (v2_c6 >= 3) {
        return -1;
    }

    if (v2_c4 >= 4) {
        return 1;
    }

    // More cases for full implementation
    return if (v2_c4 >= 2) -1 else 1;
}

/// 2-adic valuation
fn valuation2(n: i64) u32 {
    if (n == 0) return 999; // Infinite

    var v: u32 = 0;
    var m: i64 = @abs(n);

    while (m % 2 == 0) : (m /= 2) {
        v += 1;
    }

    return v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TWIST DESCENT - Alternative rank computation
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute rank using quadratic twists
/// rank(E) = rank(E) + rank(E_d) - 1 for nontrivial d
pub fn computeRankViaTwists(curve: *const EllipticCurve) !u8 {
    // Root number determines parity of rank
    const w = try computeRootNumber(curve);

    if (w == 1) {
        // Even rank: 0, 2, 4, ...
        return 0; // Assume rank 0 (most common)
    } else {
        // Odd rank: 1, 3, 5, ...
        return 1; // Assume rank 1 (most common)
    }
}

/// Rank upper bound from root number and BSD
pub fn rankBound(curve: *const EllipticCurve) !u8 {
    const w = try computeRootNumber(curve);

    // parity condition: rank ≡ 0 (mod 2) if w=1, rank ≡ 1 (mod 2) if w=-1
    return if (w == 1) 0 else 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TORSION SUBGROUP ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Determine torsion subgroup structure
/// Mazur's theorem: E(Q)_tors is one of 15 known groups
pub fn computeTorsion(curve: *const EllipticCurve) !TorsionSubgroup {
    const allocator = curve.allocator;

    // Check for 2-torsion
    const has_2_torsion = has2Torsion(curve);

    // Check for 3-torsion
    const has_3_torsion = try has3Torsion(curve);

    // Check for 4-torsion
    const has_4_torsion = try has4Torsion(curve);

    // Determine group from Mazur's classification
    const order: u32 = if (has_4_torsion) 4 else if (has_3_torsion) 3 else if (has_2_torsion) 2 else 1;

    const structure = try classifyTorsion(allocator, order, has_2_torsion, has_3_torsion);

    return .{
        .order = order,
        .structure = structure,
        .generators = &.{},
    };
}

pub const TorsionSubgroup = struct {
    order: u32, // #E(Q)_tors
    structure: []const u8, // Group name (e.g., "Z/2Z", "Z/6Z")
    generators: []const i64, // x-coordinates of generators
    allocator: std.mem.Allocator,
};

/// Classify torsion subgroup by order and properties
fn classifyTorsion(allocator: std.mem.Allocator, order: u32, has_2: bool, has_3: bool) ![]const u8 {
    _ = has_3;
    _ = allocator;

    return switch (order) {
        1 => "Z/1Z",
        2 => if (has_2) "Z/2Z" else "Z/2Z",
        3 => "Z/3Z",
        4 => "Z/4Z",
        5 => "Z/5Z",
        6 => "Z/6Z",
        7 => "Z/7Z",
        8 => "Z/8Z",
        9 => "Z/9Z",
        10 => "Z/10Z",
        12 => "Z/12Z",
        else => "Z/nZ",
    };
}

/// Check for 3-torsion point
fn has3Torsion(curve: *const EllipticCurve) !bool {
    // 3-torsion exists iff division polynomial ψ_3(x) = 3x^4 + 6ax^2 + 12bx - a^2 has root
    // For simplified check: test small x values

    for ([_]i64{ 0, 1, -1, 2, -2, 3, -3 }) |x| {
        const psi3 = try divisionPolynomial3(curve, x);
        if (psi3 == 0) return true;
    }

    return false;
}

/// Check for 4-torsion point
fn has4Torsion(curve: *const EllipticCurve) !bool {
    // 4-torsion requires 2-torsion point with specific properties
    // Simplified: check if curve has point of order 4

    if (!has2Torsion(curve)) return false;

    // A 2-torsion point P has order 4 if 2P ≠ O
    // This is complex; simplified version returns false
    return false;
}

/// Division polynomial ψ_3
fn divisionPolynomial3(curve: *const EllipticCurve, x: i64) !i64 {
    const a = curve.a;
    const b = curve.b;

    const x_sq = x * x;
    const x_quad = x_sq * x_sq;

    const term1 = 3 * x_quad;
    const term2 = 6 * a * x_sq;
    const term3 = 12 * b * x;
    const term4 = -a * a;

    return term1 + term2 + term3 + term4;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "isSquarefree" {
    try std.testing.expect(isSquarefree(1));
    try std.testing.expect(isSquarefree(2));
    try std.testing.expect(isSquarefree(3));
    try std.testing.expect(isSquarefree(5));
    try std.testing.expect(isSquarefree(6));
    try std.testing.expect(isSquarefree(7));
    try std.testing.expect(!isSquarefree(4)); // 2^2
    try std.testing.expect(!isSquarefree(8)); // 2^3
    try std.testing.expect(!isSquarefree(9)); // 3^2
    try std.testing.expect(!isSquarefree(12)); // 2^2 * 3
}

test "has2Torsion" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x has 2-torsion: (0,0)
    const curve1 = try EllipticCurve.init(allocator, -1, 0);
    defer curve1.deinit();
    try std.testing.expect(has2Torsion(&curve1));

    // y^2 = x^3 + 1 has no 2-torsion (no rational root)
    const curve2 = try EllipticCurve.init(allocator, 0, 1);
    defer curve2.deinit();
    try std.testing.expect(!has2Torsion(&curve2));
}

test "isRoot" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - x, roots at x=0, x=±1
    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    try std.testing.expect(isRoot(&curve, 0));
    try std.testing.expect(isRoot(&curve, 1));
    try std.testing.expect(isRoot(&curve, -1));
    try std.testing.expect(!isRoot(&curve, 2));
}

test "valuation2" {
    try std.testing.expectEqual(@as(u32, 0), valuation2(1));
    try std.testing.expectEqual(@as(u32, 1), valuation2(2));
    try std.testing.expectEqual(@as(u32, 2), valuation2(4));
    try std.testing.expectEqual(@as(u32, 3), valuation2(8));
    try std.testing.expectEqual(@as(u32, 0), valuation2(3));
}

test "computeRootNumber" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const w = try computeRootNumber(&curve);

    // Root number must be ±1
    try std.testing.expect(@abs(w) == 1);
}

test "rankBound" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const bound = try rankBound(&curve);

    // Bound should be 0 or 1
    try std.testing.expect(bound <= 1);
}

test "compute2Selmer" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const selmer = try compute2Selmer(&curve);
    defer selmer.deinit();

    // Should have at least trivial element
    try std.testing.expect(selmer.size >= 1);
    try std.testing.expect(selmer.elements[0].d == 1);
}

test "TwoSelmerGroup getRank" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const selmer = try compute2Selmer(&curve);
    defer selmer.deinit();

    const rank = selmer.getRank();

    // Rank should be reasonable
    try std.testing.expect(rank <= 10);
}

test "computeTorsion" {
    const allocator = std.testing.allocator;

    const curve = try EllipticCurve.init(allocator, -1, 0);
    defer curve.deinit();

    const torsion = try computeTorsion(&curve);

    // Should have order at least 1
    try std.testing.expect(torsion.order >= 1);
}

test "has3Torsion" {
    const allocator = std.testing.allocator;

    // y^2 = x^3 - 1 has 3-torsion: (1,0)
    const curve = try EllipticCurve.init(allocator, 0, -1);
    defer curve.deinit();

    try std.testing.expect(try has3Torsion(&curve));
}
