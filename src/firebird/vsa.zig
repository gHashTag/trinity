// ═══════════════════════════════════════════════════════════════════════════════
// FIREBIRD VSA - Vector Symbolic Architecture for ЖАР ПТИЦА
// High-dimensional ternary vector operations for virtual space navigation
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DIM: usize = 10000;
pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_INV: f64 = 0.6180339887498948482;
pub const TRINITY: f64 = 3.0;
pub const SIMILARITY_THRESHOLD: f64 = 0.7;
pub const ORTHOGONALITY_THRESHOLD: f64 = 0.1;
pub const SPARSITY: f64 = 0.333;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Trit = i8; // -1, 0, +1

pub const TritVec = struct {
    allocator: std.mem.Allocator,
    data: []Trit,
    len: usize,

    const Self = @This();

    /// Create zero vector
    pub fn zero(allocator: std.mem.Allocator, dim: usize) !Self {
        const data = try allocator.alloc(Trit, dim);
        @memset(data, 0);
        return Self{
            .allocator = allocator,
            .data = data,
            .len = dim,
        };
    }

    /// Create random vector with uniform distribution {-1, 0, +1}
    pub fn random(allocator: std.mem.Allocator, dim: usize, seed: u64) !Self {
        const data = try allocator.alloc(Trit, dim);
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();

        for (data) |*trit| {
            const r = rand.float(f32);
            if (r < 0.333) {
                trit.* = -1;
            } else if (r < 0.666) {
                trit.* = 0;
            } else {
                trit.* = 1;
            }
        }

        return Self{
            .allocator = allocator,
            .data = data,
            .len = dim,
        };
    }

    /// Create sparse random vector with specified sparsity (proportion of zeros)
    pub fn sparse(allocator: std.mem.Allocator, dim: usize, seed: u64, sparsity: f32) !Self {
        const data = try allocator.alloc(Trit, dim);
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();

        const non_zero_prob = (1.0 - sparsity) / 2.0;

        for (data) |*trit| {
            const r = rand.float(f32);
            if (r < non_zero_prob) {
                trit.* = -1;
            } else if (r < non_zero_prob * 2.0) {
                trit.* = 1;
            } else {
                trit.* = 0;
            }
        }

        return Self{
            .allocator = allocator,
            .data = data,
            .len = dim,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    /// Clone vector
    pub fn clone(self: *const Self) !Self {
        const data = try self.allocator.alloc(Trit, self.len);
        @memcpy(data, self.data);
        return Self{
            .allocator = self.allocator,
            .data = data,
            .len = self.len,
        };
    }
};

pub const SimilarityMetrics = struct {
    cosine: f64,
    hamming: usize,
    dot: i64,
    normalized_hamming: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BIND OPERATION (Element-wise multiplication)
// Creates associations between vectors
// Properties:
// - bind(a, a) = all +1 for non-zero elements (self-inverse)
// - bind(a, bind(a, b)) = b (unbind)
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind two vectors (element-wise multiplication)
pub fn bind(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        // Balanced ternary multiplication: result is always in {-1, 0, 1}
        data[i] = a.data[i] * b.data[i];
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };
}

/// Unbind (same as bind for balanced ternary - self-inverse)
pub fn unbind(allocator: std.mem.Allocator, bound: *const TritVec, key: *const TritVec) !TritVec {
    return bind(allocator, bound, key);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE OPERATION (Majority voting)
// Combines multiple vectors into one that is similar to all inputs
// ═══════════════════════════════════════════════════════════════════════════════

/// Bundle two vectors (majority voting with tie-breaker)
pub fn bundle2(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec) !TritVec {
    const len = @min(a.len, b.len);
    const data = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const sum: i16 = @as(i16, a.data[i]) + @as(i16, b.data[i]);
        if (sum > 0) {
            data[i] = 1;
        } else if (sum < 0) {
            data[i] = -1;
        } else {
            data[i] = 0; // Tie: default to 0
        }
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };
}

/// Bundle three vectors (true majority voting)
pub fn bundle3(allocator: std.mem.Allocator, a: *const TritVec, b: *const TritVec, c: *const TritVec) !TritVec {
    const len = @min(@min(a.len, b.len), c.len);
    const data = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const sum: i16 = @as(i16, a.data[i]) + @as(i16, b.data[i]) + @as(i16, c.data[i]);
        // Majority: 2 out of 3
        if (sum >= 2) {
            data[i] = 1;
        } else if (sum <= -2) {
            data[i] = -1;
        } else if (sum > 0) {
            data[i] = 1;
        } else if (sum < 0) {
            data[i] = -1;
        } else {
            data[i] = 0;
        }
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = len,
    };
}

/// Bundle N vectors (weighted majority voting)
pub fn bundleN(allocator: std.mem.Allocator, vectors: []const *const TritVec) !TritVec {
    if (vectors.len == 0) return error.EmptyInput;

    var min_len: usize = vectors[0].len;
    for (vectors) |v| {
        min_len = @min(min_len, v.len);
    }

    const data = try allocator.alloc(Trit, min_len);
    const sums = try allocator.alloc(i32, min_len);
    defer allocator.free(sums);
    @memset(sums, 0);

    // Sum all vectors
    for (vectors) |v| {
        for (0..min_len) |i| {
            sums[i] += v.data[i];
        }
    }

    // Threshold to ternary
    for (0..min_len) |i| {
        if (sums[i] > 0) {
            data[i] = 1;
        } else if (sums[i] < 0) {
            data[i] = -1;
        } else {
            data[i] = 0;
        }
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = min_len,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMUTE OPERATION (Cyclic shift)
// Used for encoding sequences: sequence(a, b, c) = a + permute(b, 1) + permute(c, 2)
// ═══════════════════════════════════════════════════════════════════════════════

/// Permute (cyclic shift right by k positions)
pub fn permute(allocator: std.mem.Allocator, v: *const TritVec, k: usize) !TritVec {
    const data = try allocator.alloc(Trit, v.len);

    if (v.len == 0) {
        return TritVec{
            .allocator = allocator,
            .data = data,
            .len = 0,
        };
    }

    const shift = k % v.len;

    for (0..v.len) |i| {
        const new_pos = (i + shift) % v.len;
        data[new_pos] = v.data[i];
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = v.len,
    };
}

/// Inverse permute (cyclic shift left by k positions)
pub fn inversePermute(allocator: std.mem.Allocator, v: *const TritVec, k: usize) !TritVec {
    const data = try allocator.alloc(Trit, v.len);

    if (v.len == 0) {
        return TritVec{
            .allocator = allocator,
            .data = data,
            .len = 0,
        };
    }

    const shift = k % v.len;

    for (0..v.len) |i| {
        const new_pos = (i + v.len - shift) % v.len;
        data[new_pos] = v.data[i];
    }

    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = v.len,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMILARITY OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Dot product of two vectors
pub fn dotProduct(a: *const TritVec, b: *const TritVec) i64 {
    const len = @min(a.len, b.len);
    var sum: i64 = 0;

    for (0..len) |i| {
        sum += @as(i64, a.data[i]) * @as(i64, b.data[i]);
    }

    return sum;
}

/// Vector L2 norm (sqrt of sum of squares)
fn vectorNorm(v: *const TritVec) f64 {
    var sum_sq: i64 = 0;
    for (v.data) |trit| {
        sum_sq += @as(i64, trit) * @as(i64, trit);
    }
    return @sqrt(@as(f64, @floatFromInt(sum_sq)));
}

/// Cosine similarity between two vectors (range [-1, 1])
pub fn cosineSimilarity(a: *const TritVec, b: *const TritVec) f64 {
    const dot = dotProduct(a, b);
    const norm_a = vectorNorm(a);
    const norm_b = vectorNorm(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

/// Hamming distance (number of differing positions)
pub fn hammingDistance(a: *const TritVec, b: *const TritVec) usize {
    const len = @min(a.len, b.len);
    var distance: usize = 0;

    for (0..len) |i| {
        if (a.data[i] != b.data[i]) {
            distance += 1;
        }
    }

    // Add difference in lengths
    distance += @max(a.len, b.len) - len;

    return distance;
}

/// Normalized Hamming similarity (1 - hamming_distance / len)
pub fn hammingSimilarity(a: *const TritVec, b: *const TritVec) f64 {
    const len = @max(a.len, b.len);
    if (len == 0) return 1.0;

    const distance = hammingDistance(a, b);
    return 1.0 - @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(len));
}

/// Compute all similarity metrics
pub fn computeAllMetrics(a: *const TritVec, b: *const TritVec) SimilarityMetrics {
    const dot = dotProduct(a, b);
    const hamming = hammingDistance(a, b);
    const len = @max(a.len, b.len);

    return SimilarityMetrics{
        .cosine = cosineSimilarity(a, b),
        .hamming = hamming,
        .dot = dot,
        .normalized_hamming = if (len > 0) 1.0 - @as(f64, @floatFromInt(hamming)) / @as(f64, @floatFromInt(len)) else 1.0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCE ENCODING
// ═══════════════════════════════════════════════════════════════════════════════

/// Encode sequence: sequence(items) = items[0] + permute(items[1], 1) + ...
pub fn encodeSequence(allocator: std.mem.Allocator, items: []const *const TritVec) !TritVec {
    if (items.len == 0) return TritVec.zero(allocator, DIM);

    var result = try items[0].clone();
    errdefer result.deinit();

    for (1..items.len) |i| {
        var permuted = try permute(allocator, items[i], i);
        defer permuted.deinit();

        // Add permuted to result
        for (0..@min(result.len, permuted.len)) |j| {
            const sum: i16 = @as(i16, result.data[j]) + @as(i16, permuted.data[j]);
            if (sum > 0) {
                result.data[j] = 1;
            } else if (sum < 0) {
                result.data[j] = -1;
            } else {
                result.data[j] = 0;
            }
        }
    }

    return result;
}

/// Probe sequence for element at position
pub fn probeSequence(sequence: *const TritVec, candidate: *const TritVec, position: usize, allocator: std.mem.Allocator) !f64 {
    var permuted = try permute(allocator, candidate, position);
    defer permuted.deinit();
    return cosineSimilarity(sequence, &permuted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Count non-zero elements
pub fn countNonZero(v: *const TritVec) usize {
    var count: usize = 0;
    for (v.data) |trit| {
        if (trit != 0) count += 1;
    }
    return count;
}

/// Compute sparsity (proportion of zeros)
pub fn computeSparsity(v: *const TritVec) f64 {
    if (v.len == 0) return 1.0;
    const non_zero = countNonZero(v);
    return 1.0 - @as(f64, @floatFromInt(non_zero)) / @as(f64, @floatFromInt(v.len));
}

/// Negate vector (element-wise negation)
pub fn negate(allocator: std.mem.Allocator, v: *const TritVec) !TritVec {
    const data = try allocator.alloc(Trit, v.len);
    for (0..v.len) |i| {
        data[i] = -v.data[i];
    }
    return TritVec{
        .allocator = allocator,
        .data = data,
        .len = v.len,
    };
}

/// Check if two vectors are orthogonal (|similarity| < threshold)
pub fn isOrthogonal(a: *const TritVec, b: *const TritVec, threshold: f64) bool {
    const sim = cosineSimilarity(a, b);
    return @abs(sim) < threshold;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "bind self-inverse" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 100, 12345);
    defer a.deinit();

    var bound = try bind(allocator, &a, &a);
    defer bound.deinit();

    // bind(a, a) should produce +1 for non-zero elements, 0 for zeros
    for (0..a.len) |i| {
        const expected: Trit = if (a.data[i] == 0) 0 else 1;
        try std.testing.expectEqual(expected, bound.data[i]);
    }
}

test "bind unbind roundtrip" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 100, 11111);
    defer a.deinit();
    var b = try TritVec.random(allocator, 100, 22222);
    defer b.deinit();

    var bound = try bind(allocator, &a, &b);
    defer bound.deinit();

    var recovered = try unbind(allocator, &bound, &b);
    defer recovered.deinit();

    // unbind(bind(a, b), b) should return a where b != 0
    // When b[i] = 0, bind produces 0, and unbind cannot recover a[i]
    for (0..a.len) |i| {
        if (b.data[i] != 0) {
            try std.testing.expectEqual(a.data[i], recovered.data[i]);
        }
    }
}

test "bundle preserves similarity" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 100, 33333);
    defer a.deinit();
    var b = try TritVec.random(allocator, 100, 44444);
    defer b.deinit();

    var bundled = try bundle2(allocator, &a, &b);
    defer bundled.deinit();

    const sim_a = cosineSimilarity(&bundled, &a);
    const sim_b = cosineSimilarity(&bundled, &b);

    // Bundle should be somewhat similar to both inputs
    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "permute inverse roundtrip" {
    const allocator = std.testing.allocator;

    var v = try TritVec.random(allocator, 100, 55555);
    defer v.deinit();

    var permuted = try permute(allocator, &v, 7);
    defer permuted.deinit();

    var recovered = try inversePermute(allocator, &permuted, 7);
    defer recovered.deinit();

    for (0..v.len) |i| {
        try std.testing.expectEqual(v.data[i], recovered.data[i]);
    }
}

test "random vectors nearly orthogonal" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 1000, 66666);
    defer a.deinit();
    var b = try TritVec.random(allocator, 1000, 77777);
    defer b.deinit();

    const sim = cosineSimilarity(&a, &b);

    // Random high-dim vectors should be nearly orthogonal
    try std.testing.expect(@abs(sim) < 0.2);
}

test "sequence encoding retrieval" {
    const allocator = std.testing.allocator;

    var a = try TritVec.random(allocator, 100, 88888);
    defer a.deinit();
    var b = try TritVec.random(allocator, 100, 99999);
    defer b.deinit();

    const items = [_]*const TritVec{ &a, &b };
    var seq = try encodeSequence(allocator, &items);
    defer seq.deinit();

    // Probe for first element (position 0)
    const sim_a = try probeSequence(&seq, &a, 0, allocator);
    // Probe for second element (position 1)
    const sim_b = try probeSequence(&seq, &b, 1, allocator);

    // Should have positive similarity at correct positions
    try std.testing.expect(sim_a > 0.3);
    try std.testing.expect(sim_b > 0.3);
}

test "verify trinity identity" {
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / phi_sq;
    const trinity = phi_sq + phi_inv_sq;

    try std.testing.expectApproxEqAbs(TRINITY, trinity, 1e-10);
}
