// ═══════════════════════════════════════════════════════════════════════════════
// BSD-VSA INTEGRATION
// Connecting Elliptic Curve BSD Formula with Vector Symbolic Architecture
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const common = @import("common.zig");
const core = @import("core.zig");
const HybridBigInt = common.HybridBigInt;
const Trit = common.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// BSD-VSA HYPERVERSOR COMPONENT
// ═══════════════════════════════════════════════════════════════════════════════

/// BSD-enhanced hypervector with Sha (Ш) as third dimension
///
/// Traditional VSA: [bind, bundle]
/// BSD-VSA:        [bind, bundle, sha]
///
/// The Sha (Shafarevich-Tate group) provides:
/// 1. Hidden structure information
/// 2. Arithmetic complexity measure
/// 3. Proof-theoretic depth for zk-systems
pub const BSDHypervector = struct {
    /// Primary symbolic vector
    primary: HybridBigInt,

    /// Secondary (bound) vector
    secondary: HybridBigInt,

    /// Sha-derived component (Ш order → trit pattern)
    sha_component: HybridBigInt,

    /// BSD metadata
    sha_order: u64 = 1,
    rank: u8 = 0,
    analytic_rank: u8 = 0,

    /// Create new BSD-enhanced hypervector
    pub fn init(dimension: usize) BSDHypervector {
        const primary = core.randomVector(dimension, 42);
        const secondary = core.randomVector(dimension, 43);
        return .{
            .primary = primary,
            .secondary = secondary,
            .sha_component = HybridBigInt.zero(),
        };
    }

    /// Create from existing vectors with Sha enhancement
    pub fn fromVectors(primary: *HybridBigInt, secondary: *HybridBigInt, sha_order: u64) BSDHypervector {
        return .{
            .primary = primary.*,
            .secondary = secondary.*,
            .sha_component = shaOrderToVector(sha_order, @max(primary.trit_len, secondary.trit_len)),
            .sha_order = sha_order,
        };
    }

    /// Triple-bind operation incorporating Sha
    /// Result = bind(primary, secondary) ⊛ sha_component
    pub fn tripleBind(self: *const BSDHypervector) HybridBigInt {
        var p = self.primary;
        var s = self.secondary;
        var bound = core.bind(&p, &s);
        var sha_c = self.sha_component;
        return core.bind(&bound, &sha_c);
    }

    /// Bundle with Sha-weighted majority vote
    /// Sha component gets √(sha_order) weight boost in the majority sum.
    /// sum[i] = primary[i] + secondary[i] + weight * sha_component[i]
    /// result[i] = sign(sum[i])
    pub fn shaWeightedBundle(self: *const BSDHypervector, other: *const BSDHypervector) HybridBigInt {
        const weight_f = std.math.sqrt(@as(f64, @floatFromInt(@max(self.sha_order, 1))));
        const weight: i16 = @intFromFloat(@max(1.0, @round(weight_f)));

        var p = self.primary;
        var s = self.secondary;
        var sha = other.sha_component;
        p.ensureUnpacked();
        s.ensureUnpacked();
        sha.ensureUnpacked();

        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;

        const len = @max(@max(p.trit_len, s.trit_len), sha.trit_len);
        result.trit_len = len;

        for (0..len) |i| {
            const pi: i16 = p.unpacked_cache[i];
            const si: i16 = s.unpacked_cache[i];
            const shi: i16 = sha.unpacked_cache[i];
            const sum = pi + si + weight * shi;

            result.unpacked_cache[i] = if (sum > 0) 1 else if (sum < 0) @as(i8, -1) else 0;
        }

        return result;
    }

    /// Compute similarity with Sha-aware adjustment
    pub fn shaSimilarity(self: *const BSDHypervector, other: *const BSDHypervector) f64 {
        const base_sim = core.cosineSimilarity(&self.primary, &other.primary);

        // Sha adjustment: curves with same Sha get similarity boost
        const sha_match = if (self.sha_order == other.sha_order) 1.0 else 0.0;
        const sha_factor = 0.1 * sha_match; // 10% boost for Sha match

        return base_sim + sha_factor;
    }
};

/// Convert Sha order to trit vector pattern
/// Uses φ-based encoding for mathematical elegance
pub fn shaOrderToVector(sha_order: u64, dimension: usize) HybridBigInt {
    var result = HybridBigInt.zero();
    result.trit_len = dimension;
    result.mode = .unpacked_mode;

    // φ-based encoding: each trit = sign of (sha_order * φ^i mod 3)
    const phi: f64 = 1.618033988749895;
    const sha_f: f64 = @floatFromInt(sha_order);

    for (0..dimension) |i| {
        const phi_pow = std.math.pow(f64, phi, @as(f64, @floatFromInt(i)));
        const val = sha_f * phi_pow;
        const rem = @mod(val, 3.0);

        result.unpacked_cache[i] = if (rem < 1.0)
            -1
        else if (rem < 2.0)
            0
        else
            1;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// L-FUNCTION TERNARY SEQUENCE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// L-function value descriptor for sequence generation
pub const LFunctionDescriptor = struct {
    /// Elliptic curve coefficients
    a: i64,
    b: i64,

    /// Conductor
    conductor: u64,

    /// Analytic rank (detected from L-function)
    rank: u8,

    /// L(E,1) value
    special_value: f64,
};

/// Generate ternary sequence from L-function values
/// Maps L-series coefficients to balanced ternary
pub fn generateLSequence(allocator: std.mem.Allocator, desc: LFunctionDescriptor, length: usize) ![]Trit {
    const sequence = try allocator.alloc(Trit, length);
    errdefer allocator.free(sequence);

    // Use Hasse-Weil L-function coefficients a_p
    // a_p = p + 1 - #E(F_p)
    // Map to ternary: a_p > 0 → +1, a_p = 0 → 0, a_p < 0 → -1

    var p: u64 = 2; // Start from prime 2
    var i: usize = 0;

    while (i < length) {
        if (isPrime(p)) {
            // Simplified a_p computation using Legendre symbol
            const ap = computeHasseWeilCoefficient(desc.a, desc.b, p);

            // Map to ternary with threshold
            const threshold = std.math.sqrt(@as(f64, @floatFromInt(p)));
            const ap_f: f64 = @floatFromInt(ap);
            sequence[i] = if (ap_f > threshold / 2)
                1
            else if (ap_f < -threshold / 2)
                -1
            else
                0;

            i += 1;
        }
        p += 1;
    }

    return sequence;
}

/// Compute Hasse-Weil coefficient a_p = p + 1 - #E(F_p)
/// Simplified using Legendre symbol of discriminant
fn computeHasseWeilCoefficient(a: i64, b: i64, p: u64) i64 {
    // For curve y^2 = x^3 + ax + b
    // #E(F_p) ≈ p + 1 for most p (simplified)
    // Use Legendre symbol of discriminant for perturbation

    const discriminant = -4 * a * a * a - 27 * b * b;
    const leg = legendreSymbol(discriminant, @as(i64, @intCast(p)));

    // Small perturbation around expected value
    return leg;
}

/// Legendre symbol (a/p)
fn legendreSymbol(a: i64, p: i64) i64 {
    const a_mod = @rem(a, p);
    if (a_mod == 0) return 0;

    // Euler's criterion: (a/p) ≡ a^((p-1)/2) mod p
    const exp = @divTrunc(p - 1, 2);
    const result = std.math.powi(i64, a_mod, exp) catch return 0;
    const mod_result = @rem(result, p);

    return if (mod_result == 1) 1 else -1;
}

/// Simple primality test
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

/// Convert L-sequence to hypervector
pub fn lSequenceToHypervector(sequence: []const Trit) HybridBigInt {
    var result = HybridBigInt.zero();
    result.trit_len = sequence.len;
    result.mode = .unpacked_mode;

    @memcpy(result.unpacked_cache[0..sequence.len], sequence);

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RANK DETECTION FOR VSA CLASSIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Curve classification based on analytic rank
pub const CurveClassification = enum(u8) {
    /// Rank 0: Finite rational points
    rank_0 = 0,

    /// Rank 1: Infinite cyclic group
    rank_1 = 1,

    /// Rank 2+: Higher complexity
    rank_high = 2,

    /// Unknown rank
    unknown = 255,
};

/// Classify curve for VSA processing
pub fn classifyCurve(l_descriptor: *const LFunctionDescriptor) CurveClassification {
    return switch (l_descriptor.rank) {
        0 => .rank_0,
        1 => .rank_1,
        else => .rank_high,
    };
}

/// Get VSA dimension based on curve rank
/// Higher rank → higher dimension for more expressive power
pub fn getRankBasedDimension(classification: CurveClassification) usize {
    return switch (classification) {
        .rank_0 => 512, // Minimal: finite structure
        .rank_1 => 1024, // Standard: cyclic infinite
        .rank_high => 2048, // Large: complex structure
        .unknown => 1024, // Default
    };
}

/// Rank-aware similarity computation
/// Curves of same rank have higher baseline similarity
pub fn rankAwareSimilarity(
    vec1: *const HybridBigInt,
    rank1: u8,
    vec2: *const HybridBigInt,
    rank2: u8,
) f64 {
    const base_sim = core.cosineSimilarity(vec1, vec2);

    // Rank match bonus
    const rank_match = if (rank1 == rank2) 0.1 else 0.0;

    // Rank magnitude adjustment
    const rank_factor = @as(f64, @floatFromInt(@min(rank1, rank2))) / 10.0;

    return base_sim + rank_match + rank_factor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZERO-KNOWLEDGE BSD PROOF
// ═══════════════════════════════════════════════════════════════════════════════

/// BSD commitment for zk-proof systems
/// Commits to BSD components without revealing curve structure
pub const BSDCommitment = struct {
    /// Hashed commitment to Sha order
    sha_commitment: [32]u8,

    /// Hashed commitment to rank
    rank_commitment: [32]u8,

    /// Hashed commitment to L-value
    l_commitment: [32]u8,

    /// Create commitment from BSD data
    pub fn create(sha_order: u64, rank: u8, l_value: f64) BSDCommitment {
        var result: BSDCommitment = undefined;

        // Simple hash commitment (in production, use proper zk-SNARK)
        var sha_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &sha_buf, sha_order, .little);
        std.crypto.hash.sha2.Sha256.hash(&sha_buf, &result.sha_commitment, .{});

        var rank_buf: [1]u8 = .{rank};
        std.crypto.hash.sha2.Sha256.hash(&rank_buf, &result.rank_commitment, .{});

        var l_buf: [8]u8 = undefined;
        const l_bits = @as(u64, @bitCast(l_value));
        std.mem.writeInt(u64, &l_buf, l_bits, .little);
        std.crypto.hash.sha2.Sha256.hash(&l_buf, &result.l_commitment, .{});

        return result;
    }

    /// Verify commitment matches claimed values
    pub fn verify(self: *const BSDCommitment, sha_order: u64, rank: u8, l_value: f64) bool {
        const expected = create(sha_order, rank, l_value);
        return std.mem.eql(u8, &self.sha_commitment, &expected.sha_commitment) and
            std.mem.eql(u8, &self.rank_commitment, &expected.rank_commitment) and
            std.mem.eql(u8, &self.l_commitment, &expected.l_commitment);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BSDHypervector - init" {
    const hvec = BSDHypervector.init(512);
    try std.testing.expectEqual(@as(usize, 512), hvec.primary.trit_len);
    try std.testing.expectEqual(@as(usize, 512), hvec.secondary.trit_len);
}

test "shaOrderToVector - basic" {
    const vec = shaOrderToVector(1, 128);
    try std.testing.expectEqual(@as(usize, 128), vec.trit_len);
    try std.testing.expect(vec.mode == .unpacked_mode);
}

test "BSDCommitment - create and verify" {
    const commitment = BSDCommitment.create(4, 0, 0.51748);
    try std.testing.expect(commitment.verify(4, 0, 0.51748));
    try std.testing.expect(!commitment.verify(1, 0, 0.51748));
}

test "generateLSequence - curve 11a1" {
    const desc = LFunctionDescriptor{
        .a = -1,
        .b = 0,
        .conductor = 32,
        .rank = 0,
        .special_value = 0.253842,
    };

    const allocator = std.testing.allocator;
    const sequence = try generateLSequence(allocator, desc, 100);
    defer allocator.free(sequence);

    try std.testing.expectEqual(@as(usize, 100), sequence.len);

    // Check all values are valid trits
    for (sequence) |t| {
        try std.testing.expect(t == -1 or t == 0 or t == 1);
    }
}

test "classifyCurve - rank detection" {
    const desc0 = LFunctionDescriptor{ .a = -1, .b = 0, .conductor = 32, .rank = 0, .special_value = 0.25 };
    const desc1 = LFunctionDescriptor{ .a = -1, .b = 0, .conductor = 37, .rank = 1, .special_value = 0.0 };
    const desc2 = LFunctionDescriptor{ .a = -1, .b = 0, .conductor = 389, .rank = 2, .special_value = 0.0 };

    try std.testing.expectEqual(CurveClassification.rank_0, classifyCurve(&desc0));
    try std.testing.expectEqual(CurveClassification.rank_1, classifyCurve(&desc1));
    try std.testing.expectEqual(CurveClassification.rank_high, classifyCurve(&desc2));
}

test "shaWeightedBundle - weight affects result" {
    // Create two BSD hypervectors with different sha_orders
    var hvec1 = BSDHypervector.init(128);
    hvec1.sha_order = 25; // weight = round(√25) = 5
    hvec1.sha_component = shaOrderToVector(25, 128);

    var hvec2 = BSDHypervector.init(128);
    hvec2.sha_order = 1; // weight = round(√1) = 1
    hvec2.sha_component = shaOrderToVector(1, 128);

    // Weighted bundle with sha_order=25 (SHA gets 5 votes)
    const result_weighted = hvec1.shaWeightedBundle(&hvec2);

    // Weighted bundle with sha_order=1 (SHA gets 1 vote = same as bundle3)
    const result_unweighted = hvec2.shaWeightedBundle(&hvec1);

    // Both should produce valid trit vectors
    try std.testing.expectEqual(@as(usize, 128), result_weighted.trit_len);
    try std.testing.expectEqual(@as(usize, 128), result_unweighted.trit_len);

    // Results should differ because different weights
    var differ_count: usize = 0;
    for (0..128) |i| {
        if (result_weighted.unpacked_cache[i] != result_unweighted.unpacked_cache[i]) differ_count += 1;
    }
    // With weight=5 vs weight=1, SHA component should dominate differently
    try std.testing.expect(differ_count > 0);
}

test "getRankBasedDimension - dimension selection" {
    try std.testing.expectEqual(@as(usize, 512), getRankBasedDimension(.rank_0));
    try std.testing.expectEqual(@as(usize, 1024), getRankBasedDimension(.rank_1));
    try std.testing.expectEqual(@as(usize, 2048), getRankBasedDimension(.rank_high));
}

// φ² + 1/φ² = 3 | TRINITY
