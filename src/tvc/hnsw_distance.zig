// ═══════════════════════════════════════════════════════════════════════════════
// TVC HNSW DISTANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Distance metrics for HNSW (Hierarchical Navigable Small World) graph.
// Supports cosine similarity, Euclidean distance, and ternary Hamming distance.
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f32 = 1.618033988749;
pub const PHI_SQ: f32 = 2.618033988749;
pub const PHI_INV_SQ: f32 = 0.38196601125;
pub const TRINITY: f32 = 3.0;

pub const EPSILON: f32 = 1e-6;

// ═══════════════════════════════════════════════════════════════════════════════
// DISTANCE METRIC ENUM
// ═══════════════════════════════════════════════════════════════════════════════

/// Distance metric for HNSW similarity search
pub const DistanceMetric = enum {
    /// Cosine similarity distance: 1 - cos(a, b)
    /// Range: [0, 2], where 0 = identical, 2 = opposite
    cosine,

    /// Euclidean (L2) distance
    /// Range: [0, +inf), where 0 = identical
    euclidean,

    /// Dot product (for normalized vectors)
    /// Range: [-1, 1], where 1 = identical direction
    dot_product,

    /// Ternary Hamming distance for TVC trit vectors
    /// Range: [0, dim], where 0 = identical
    ternary_hamming,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISTANCE CALCULATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate distance between two float32 vectors using the specified metric
/// Returns: Distance value (lower = more similar)
pub fn calculateDistance(
    a: []const f32,
    b: []const f32,
    metric: DistanceMetric,
) f32 {
    std.debug.assert(a.len == b.len);

    return switch (metric) {
        .cosine => cosineDistance(a, b),
        .euclidean => euclideanDistance(a, b),
        .dot_product => -dotProduct(a, b), // Negate so lower = more similar
        .ternary_hamming => @panic("Use calculateTernaryDistance for ternary vectors"),
    };
}

/// Cosine distance: 1 - cos(a, b)
/// For normalized vectors, this equals 1 - (a . b)
/// Range: [0, 2]
pub fn cosineDistance(a: []const f32, b: []const f32) f32 {
    const dot_val = dotProduct(a, b);
    const norm_a = vectorNorm(a);
    const norm_b = vectorNorm(b);

    const denominator = norm_a * norm_b;
    if (denominator < EPSILON) return 1.0; // Both zero vectors

    const cosine_sim = dot_val / denominator;
    // Clamp to [-1, 1] to handle numerical errors
    const clamped = @max(-1.0, @min(1.0, cosine_sim));
    return 1.0 - clamped;
}

/// Cosine similarity: cos(a, b)
/// Range: [-1, 1], where 1 = identical direction, -1 = opposite
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    return 1.0 - cosineDistance(a, b);
}

/// Euclidean (L2) distance
/// Range: [0, +inf)
pub fn euclideanDistance(a: []const f32, b: []const f32) f32 {
    var sum_sq: f32 = 0.0;
    for (a, b) |ai, bi| {
        const diff = ai - bi;
        sum_sq += diff * diff;
    }
    return @sqrt(sum_sq);
}

/// Squared Euclidean distance (faster, no sqrt)
/// Useful for comparisons where actual distance not needed
pub fn euclideanDistanceSquared(a: []const f32, b: []const f32) f32 {
    var sum_sq: f32 = 0.0;
    for (a, b) |ai, bi| {
        const diff = ai - bi;
        sum_sq += diff * diff;
    }
    return sum_sq;
}

/// Dot product of two vectors
pub fn dotProduct(a: []const f32, b: []const f32) f32 {
    var sum: f32 = 0.0;
    for (a, b) |ai, bi| {
        sum += ai * bi;
    }
    return sum;
}

/// L2 norm (magnitude) of a vector
pub fn vectorNorm(v: []const f32) f32 {
    var sum_sq: f32 = 0.0;
    for (v) |vi| {
        sum_sq += vi * vi;
    }
    return @sqrt(sum_sq);
}

/// Normalize vector to unit length (L2 normalization)
/// Returns: New normalized vector (caller must free)
pub fn normalize(allocator: std.mem.Allocator, v: []const f32) ![]f32 {
    const result = try allocator.alloc(f32, v.len);
    const norm = vectorNorm(v);

    if (norm < EPSILON) {
        // Zero vector - return as-is
        @memcpy(result, v);
    } else {
        const scale = 1.0 / norm;
        for (v, 0..) |vi, i| {
            result[i] = vi * scale;
        }
    }

    return result;
}

/// Normalize vector in place (must be writable)
pub fn normalizeInPlace(v: []f32) void {
    const norm = vectorNorm(v);
    if (norm > EPSILON) {
        const scale = 1.0 / norm;
        for (v) |*vi| {
            vi.* *= scale;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY VECTOR DISTANCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit value (-1, 0, +1) represented as i2
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,
};

/// Hamming distance between two ternary vectors
/// Counts positions where trits differ
pub fn ternaryHammingDistance(a: []const Trit, b: []const Trit) usize {
    std.debug.assert(a.len == b.len);

    var count: usize = 0;
    for (a, b) |ai, bi| {
        if (ai != bi) count += 1;
    }
    return count;
}

/// Convert float32 vector to ternary representation
/// Uses ternary quantization: positive -> +1, negative -> -1, near-zero -> 0
pub fn floatToTernary(v: []const f32, threshold: f32) ![]Trit {
    const result = try std.heap.page_allocator.alloc(Trit, v.len);
    for (v, 0..) |vi, i| {
        result[i] = if (vi > threshold)
            Trit.pos
        else if (vi < -threshold)
            Trit.neg
        else
            Trit.zero;
    }
    return result;
}

/// Ternary distance for packed trit representations
pub fn ternaryPackedDistance(a: u64, b: u64, trit_count: usize) usize {
    // Each trit stored in 2 bits
    var diff: usize = 0;
    var i: usize = 0;
    while (i < trit_count) : (i += 1) {
        const shift = @as(u6, @intCast(i * 2));
        const trit_a: i2 = @bitCast(@as(i2, @truncate((a >> shift) & 0x3)));
        const trit_b: i2 = @bitCast(@as(i2, @truncate((b >> shift) & 0x3)));
        // Convert from packed (0,1,2) to trit (-1,0,1)
        const val_a = if (trit_a == 0) -1 else if (trit_a == 1) 0 else 1;
        const val_b = if (trit_b == 0) -1 else if (trit_b == 1) 0 else 1;
        if (val_a != val_b) diff += 1;
    }
    return diff;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMILARITY CONVERSIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Convert distance to similarity score
/// For cosine distance: similarity = 1 - distance
/// For Euclidean: uses exponential decay: similarity = e^(-distance)
pub fn distanceToSimilarity(distance: f32, metric: DistanceMetric) f32 {
    return switch (metric) {
        .cosine => 1.0 - distance,
        .euclidean => @exp(-distance / PHI), // PHI-normalized decay
        .dot_product => -distance,
        .ternary_hamming => 1.0 - (distance / 256.0),
    };
}

/// Convert similarity to distance (inverse of above)
pub fn similarityToDistance(similarity: f32, metric: DistanceMetric) f32 {
    return switch (metric) {
        .cosine => 1.0 - similarity,
        .euclidean => -PHI * @log(similarity),
        .dot_product => -similarity,
        .ternary_hamming => (1.0 - similarity) * 256.0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED BONUS CALCULATIONS (PAS SCORING)
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate sacred bonus for PAS (Phi-Augmented Scoring)
/// Bonus based on trinity-aligned patterns
pub fn sacredBonus(
    similarity: f32,
    symbol_name_hash: u64,
    timestamp_ms: i64,
) f32 {
    // Base bonus from PHI
    var bonus = similarity * PHI_INV_SQ;

    // Name-based bonus (hash-derived phi alignment)
    const name_factor = @as(f32, @floatFromInt(symbol_name_hash % 100)) / 100.0;
    bonus += name_factor * 0.1;

    // Recency bonus (exponential decay)
    const age_ms = @as(f32, @floatFromInt(std.time.timestamp() * 1000 - timestamp_ms));
    const recency_factor = @exp(-age_ms / (1000.0 * 60.0 * PHI_SQ * 60.0)); // Hours
    bonus += recency_factor * 0.1;

    return @min(1.0, bonus);
}

/// Weighted scoring combining semantic similarity and sacred bonus
pub fn weightedScore(
    semantic_sim: f32,
    name_match: f32,
    recency: f32,
) f32 {
    return semantic_sim * 0.6 + name_match * 0.3 + recency * 0.1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cosine distance - identical vectors" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 1.0, 2.0, 3.0 };
    const dist = cosineDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dist, EPSILON);
}

test "cosine distance - orthogonal vectors" {
    const a = [_]f32{ 1.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0 };
    const dist = cosineDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dist, EPSILON);
}

test "cosine distance - opposite vectors" {
    const a = [_]f32{ 1.0, 1.0 };
    const b = [_]f32{ -1.0, -1.0 };
    const dist = cosineDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), dist, EPSILON);
}

test "euclidean distance" {
    const a = [_]f32{ 0.0, 0.0 };
    const b = [_]f32{ 3.0, 4.0 };
    const dist = euclideanDistance(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, EPSILON);
}

test "dot product" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    const dot = dotProduct(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), dot, EPSILON); // 1*4 + 2*5 + 3*6 = 32
}

test "ternary hamming distance" {
    const a = [_]Trit{ .pos, .neg, .zero, .pos };
    const b = [_]Trit{ .pos, .pos, .zero, .neg };
    const dist = ternaryHammingDistance(&a, &b);
    try std.testing.expectEqual(@as(usize, 2), dist); // 2 positions differ
}

test "normalize in place" {
    var v = [_]f32{ 3.0, 4.0 };
    normalizeInPlace(&v);
    const norm = vectorNorm(&v);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), norm, EPSILON);
}

test "distance to similarity conversion" {
    const sim = distanceToSimilarity(0.5, .cosine);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), sim, EPSILON);

    const dist = similarityToDistance(0.5, .cosine);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), dist, EPSILON);
}

test "sacred bonus non-negative" {
    const bonus = sacredBonus(0.5, 42, 0);
    try std.testing.expect(bonus >= 0.0);
    try std.testing.expect(bonus <= 1.0);
}

test "weighted score sums to components" {
    const score = weightedScore(0.8, 0.5, 0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.66), score, EPSILON); // 0.8*0.6 + 0.5*0.3 + 0.3*0.1
}
