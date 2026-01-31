// Trinity Science - Mathematical API for Researchers
// Advanced operations for scientific computing with hyperdimensional vectors
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const trinity = @import("trinity.zig");
const vsa = @import("vsa.zig");
const sdk = @import("sdk.zig");

pub const HybridBigInt = trinity.HybridBigInt;
pub const Trit = trinity.Trit;
pub const Hypervector = sdk.Hypervector;
pub const MAX_TRITS = vsa.MAX_TRITS;

// Mathematical constants
pub const PHI: f64 = 1.6180339887498948482; // Golden ratio
pub const PHI_SQUARED: f64 = 2.6180339887498948482; // φ²
pub const GOLDEN_IDENTITY: f64 = 3.0; // φ² + 1/φ² = 3

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICAL ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Statistical properties of a hypervector
pub const VectorStats = struct {
    dimension: usize,
    positive_count: usize,
    negative_count: usize,
    zero_count: usize,
    density: f64,
    balance: f64, // (positive - negative) / dimension
    entropy: f64,
    mean: f64,
    variance: f64,
    std_dev: f64,
};

/// Compute comprehensive statistics for a hypervector
pub fn computeStats(hv: *Hypervector) VectorStats {
    hv.data.ensureUnpacked();

    var positive: usize = 0;
    var negative: usize = 0;
    var zero: usize = 0;
    var sum: i64 = 0;
    var sum_sq: i64 = 0;

    for (0..hv.data.trit_len) |i| {
        const t = hv.data.unpacked_cache[i];
        if (t > 0) {
            positive += 1;
        } else if (t < 0) {
            negative += 1;
        } else {
            zero += 1;
        }
        sum += t;
        sum_sq += @as(i64, t) * @as(i64, t);
    }

    const n = hv.data.trit_len;
    const n_f: f64 = @floatFromInt(n);

    const mean = @as(f64, @floatFromInt(sum)) / n_f;
    const variance = @as(f64, @floatFromInt(sum_sq)) / n_f - mean * mean;
    const std_dev = @sqrt(@max(0, variance));

    // Entropy calculation (ternary)
    const p_pos = @as(f64, @floatFromInt(positive)) / n_f;
    const p_neg = @as(f64, @floatFromInt(negative)) / n_f;
    const p_zero = @as(f64, @floatFromInt(zero)) / n_f;

    var entropy: f64 = 0;
    if (p_pos > 0) entropy -= p_pos * @log(p_pos) / @log(3.0);
    if (p_neg > 0) entropy -= p_neg * @log(p_neg) / @log(3.0);
    if (p_zero > 0) entropy -= p_zero * @log(p_zero) / @log(3.0);

    return VectorStats{
        .dimension = n,
        .positive_count = positive,
        .negative_count = negative,
        .zero_count = zero,
        .density = @as(f64, @floatFromInt(positive + negative)) / n_f,
        .balance = @as(f64, @floatFromInt(@as(i64, @intCast(positive)) - @as(i64, @intCast(negative)))) / n_f,
        .entropy = entropy,
        .mean = mean,
        .variance = variance,
        .std_dev = std_dev,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTANCE METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Distance metric types
pub const DistanceMetric = enum {
    hamming,
    cosine,
    euclidean,
    manhattan,
    jaccard,
    dice,
};

/// Compute distance between two hypervectors
pub fn distance(a: *Hypervector, b: *Hypervector, metric: DistanceMetric) f64 {
    return switch (metric) {
        .hamming => hammingDistance(a, b),
        .cosine => cosineDistance(a, b),
        .euclidean => euclideanDistance(a, b),
        .manhattan => manhattanDistance(a, b),
        .jaccard => jaccardDistance(a, b),
        .dice => diceDistance(a, b),
    };
}

/// Hamming distance (normalized)
pub fn hammingDistance(a: *Hypervector, b: *Hypervector) f64 {
    return 1.0 - vsa.hammingSimilarity(&a.data, &b.data);
}

/// Cosine distance
pub fn cosineDistance(a: *Hypervector, b: *Hypervector) f64 {
    return 1.0 - vsa.cosineSimilarity(&a.data, &b.data);
}

/// Euclidean distance (L2)
pub fn euclideanDistance(a: *Hypervector, b: *Hypervector) f64 {
    a.data.ensureUnpacked();
    b.data.ensureUnpacked();

    var sum_sq: i64 = 0;
    const len = @max(a.data.trit_len, b.data.trit_len);

    for (0..len) |i| {
        const a_t: i64 = if (i < a.data.trit_len) a.data.unpacked_cache[i] else 0;
        const b_t: i64 = if (i < b.data.trit_len) b.data.unpacked_cache[i] else 0;
        const diff = a_t - b_t;
        sum_sq += diff * diff;
    }

    return @sqrt(@as(f64, @floatFromInt(sum_sq)));
}

/// Manhattan distance (L1)
pub fn manhattanDistance(a: *Hypervector, b: *Hypervector) f64 {
    a.data.ensureUnpacked();
    b.data.ensureUnpacked();

    var sum: u64 = 0;
    const len = @max(a.data.trit_len, b.data.trit_len);

    for (0..len) |i| {
        const a_t: i64 = if (i < a.data.trit_len) a.data.unpacked_cache[i] else 0;
        const b_t: i64 = if (i < b.data.trit_len) b.data.unpacked_cache[i] else 0;
        sum += @abs(a_t - b_t);
    }

    return @as(f64, @floatFromInt(sum));
}

/// Jaccard distance (for binary interpretation)
pub fn jaccardDistance(a: *Hypervector, b: *Hypervector) f64 {
    a.data.ensureUnpacked();
    b.data.ensureUnpacked();

    var intersection: usize = 0;
    var union_count: usize = 0;
    const len = @max(a.data.trit_len, b.data.trit_len);

    for (0..len) |i| {
        const a_t = if (i < a.data.trit_len) a.data.unpacked_cache[i] else 0;
        const b_t = if (i < b.data.trit_len) b.data.unpacked_cache[i] else 0;

        const a_nz = a_t != 0;
        const b_nz = b_t != 0;

        if (a_nz and b_nz and a_t == b_t) intersection += 1;
        if (a_nz or b_nz) union_count += 1;
    }

    if (union_count == 0) return 0;
    return 1.0 - @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_count));
}

/// Dice distance
pub fn diceDistance(a: *Hypervector, b: *Hypervector) f64 {
    a.data.ensureUnpacked();
    b.data.ensureUnpacked();

    var intersection: usize = 0;
    var a_count: usize = 0;
    var b_count: usize = 0;
    const len = @max(a.data.trit_len, b.data.trit_len);

    for (0..len) |i| {
        const a_t = if (i < a.data.trit_len) a.data.unpacked_cache[i] else 0;
        const b_t = if (i < b.data.trit_len) b.data.unpacked_cache[i] else 0;

        if (a_t != 0) a_count += 1;
        if (b_t != 0) b_count += 1;
        if (a_t != 0 and b_t != 0 and a_t == b_t) intersection += 1;
    }

    if (a_count + b_count == 0) return 0;
    return 1.0 - 2.0 * @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(a_count + b_count));
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFORMATION THEORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Mutual information between two hypervectors
pub fn mutualInformation(a: *Hypervector, b: *Hypervector) f64 {
    a.data.ensureUnpacked();
    b.data.ensureUnpacked();

    const len = @min(a.data.trit_len, b.data.trit_len);
    if (len == 0) return 0;

    // Count joint occurrences (3x3 matrix for ternary)
    var joint: [3][3]usize = .{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };
    var marginal_a: [3]usize = .{ 0, 0, 0 };
    var marginal_b: [3]usize = .{ 0, 0, 0 };

    for (0..len) |i| {
        const a_idx: usize = @intCast(@as(i8, a.data.unpacked_cache[i]) + 1);
        const b_idx: usize = @intCast(@as(i8, b.data.unpacked_cache[i]) + 1);

        joint[a_idx][b_idx] += 1;
        marginal_a[a_idx] += 1;
        marginal_b[b_idx] += 1;
    }

    const n: f64 = @floatFromInt(len);
    var mi: f64 = 0;

    for (0..3) |i| {
        for (0..3) |j| {
            if (joint[i][j] > 0 and marginal_a[i] > 0 and marginal_b[j] > 0) {
                const p_joint = @as(f64, @floatFromInt(joint[i][j])) / n;
                const p_a = @as(f64, @floatFromInt(marginal_a[i])) / n;
                const p_b = @as(f64, @floatFromInt(marginal_b[j])) / n;
                mi += p_joint * @log(p_joint / (p_a * p_b));
            }
        }
    }

    return mi;
}

/// Conditional entropy H(A|B)
pub fn conditionalEntropy(a: *Hypervector, b: *Hypervector) f64 {
    const stats_a = computeStats(a);
    const mi = mutualInformation(a, b);
    return stats_a.entropy - mi;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIMENSIONALITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Estimate intrinsic dimensionality using correlation dimension
pub fn estimateIntrinsicDimension(vectors: []Hypervector, sample_size: usize) f64 {
    if (vectors.len < 2) return 0;

    const n = @min(sample_size, vectors.len);
    var distances = std.ArrayList(f64).init(std.heap.page_allocator);
    defer distances.deinit();

    // Compute pairwise distances
    for (0..n) |i| {
        for (i + 1..n) |j| {
            const d = euclideanDistance(&vectors[i], &vectors[j]);
            distances.append(d) catch continue;
        }
    }

    if (distances.items.len < 10) return 0;

    // Sort distances
    std.mem.sort(f64, distances.items, {}, std.sort.asc(f64));

    // Estimate dimension using correlation integral
    // C(r) ~ r^d for small r
    const r1_idx = distances.items.len / 10;
    const r2_idx = distances.items.len / 5;

    const r1 = distances.items[r1_idx];
    const r2 = distances.items[r2_idx];

    if (r1 <= 0 or r2 <= r1) return 0;

    const c1 = @as(f64, @floatFromInt(r1_idx)) / @as(f64, @floatFromInt(distances.items.len));
    const c2 = @as(f64, @floatFromInt(r2_idx)) / @as(f64, @floatFromInt(distances.items.len));

    return @log(c2 / c1) / @log(r2 / r1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESONATOR NETWORK
// ═══════════════════════════════════════════════════════════════════════════════

/// Resonator network for factorization
pub const ResonatorNetwork = struct {
    factors: []Hypervector,
    codebooks: [][]Hypervector,
    dimension: usize,
    max_iterations: usize,
    convergence_threshold: f64,

    const Self = @This();

    pub fn init(
        dimension: usize,
        num_factors: usize,
        codebook_size: usize,
        allocator: std.mem.Allocator,
    ) !Self {
        var factors = try allocator.alloc(Hypervector, num_factors);
        var codebooks = try allocator.alloc([]Hypervector, num_factors);

        // Initialize random codebooks
        for (0..num_factors) |f| {
            codebooks[f] = try allocator.alloc(Hypervector, codebook_size);
            for (0..codebook_size) |c| {
                const seed = @as(u64, f * 1000 + c);
                codebooks[f][c] = Hypervector.random(dimension, seed);
            }
            factors[f] = Hypervector.random(dimension, @as(u64, f + 10000));
        }

        return Self{
            .factors = factors,
            .codebooks = codebooks,
            .dimension = dimension,
            .max_iterations = 100,
            .convergence_threshold = 0.001,
        };
    }

    /// Factorize composite vector into components
    pub fn factorize(self: *Self, composite: *Hypervector) ![]usize {
        var result = try std.heap.page_allocator.alloc(usize, self.factors.len);

        // Initialize factors randomly
        for (0..self.factors.len) |f| {
            self.factors[f] = Hypervector.random(self.dimension, @as(u64, f));
        }

        var prev_energy: f64 = -1000;

        for (0..self.max_iterations) |_| {
            // Update each factor
            for (0..self.factors.len) |f| {
                // Compute estimate without factor f
                var estimate = composite.clone();
                for (0..self.factors.len) |g| {
                    if (g != f) {
                        estimate = estimate.unbind(&self.factors[g]);
                    }
                }

                // Find best match in codebook
                var best_idx: usize = 0;
                var best_sim: f64 = -2;

                for (0..self.codebooks[f].len) |c| {
                    const sim = estimate.similarity(&self.codebooks[f][c]);
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_idx = c;
                    }
                }

                self.factors[f] = self.codebooks[f][best_idx].clone();
                result[f] = best_idx;
            }

            // Check convergence
            var reconstructed = self.factors[0].clone();
            for (1..self.factors.len) |f| {
                reconstructed = reconstructed.bind(&self.factors[f]);
            }

            const energy = composite.similarity(&reconstructed);
            if (@abs(energy - prev_energy) < self.convergence_threshold) {
                break;
            }
            prev_energy = energy;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse hypervector representation
pub const SparseHypervector = struct {
    indices: std.ArrayList(usize),
    values: std.ArrayList(Trit),
    dimension: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, dimension: usize) Self {
        return Self{
            .indices = std.ArrayList(usize).init(allocator),
            .values = std.ArrayList(Trit).init(allocator),
            .dimension = dimension,
        };
    }

    pub fn deinit(self: *Self) void {
        self.indices.deinit();
        self.values.deinit();
    }

    /// Convert from dense hypervector
    pub fn fromDense(allocator: std.mem.Allocator, hv: *Hypervector) !Self {
        hv.data.ensureUnpacked();

        var sparse = Self.init(allocator, hv.data.trit_len);

        for (0..hv.data.trit_len) |i| {
            const t = hv.data.unpacked_cache[i];
            if (t != 0) {
                try sparse.indices.append(i);
                try sparse.values.append(t);
            }
        }

        return sparse;
    }

    /// Convert to dense hypervector
    pub fn toDense(self: *Self) Hypervector {
        var hv = Hypervector.init(self.dimension);

        for (0..self.indices.items.len) |i| {
            const idx = self.indices.items[i];
            const val = self.values.items[i];
            hv.data.unpacked_cache[idx] = val;
        }

        hv.data.dirty = true;
        return hv;
    }

    /// Sparsity ratio
    pub fn sparsity(self: *Self) f64 {
        if (self.dimension == 0) return 1.0;
        return 1.0 - @as(f64, @floatFromInt(self.indices.items.len)) /
            @as(f64, @floatFromInt(self.dimension));
    }

    /// Memory efficiency (compared to dense)
    pub fn memoryEfficiency(self: *Self) f64 {
        const sparse_size = self.indices.items.len * (@sizeOf(usize) + @sizeOf(Trit));
        const dense_size = self.dimension * @sizeOf(Trit);
        if (dense_size == 0) return 1.0;
        return 1.0 - @as(f64, @floatFromInt(sparse_size)) / @as(f64, @floatFromInt(dense_size));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch similarity computation (returns similarity matrix)
pub fn batchSimilarity(vectors: []Hypervector, allocator: std.mem.Allocator) ![][]f64 {
    const n = vectors.len;
    var matrix = try allocator.alloc([]f64, n);

    for (0..n) |i| {
        matrix[i] = try allocator.alloc(f64, n);
        for (0..n) |j| {
            if (i == j) {
                matrix[i][j] = 1.0;
            } else if (i < j) {
                matrix[i][j] = vectors[i].similarity(&vectors[j]);
            } else {
                matrix[i][j] = matrix[j][i];
            }
        }
    }

    return matrix;
}

/// Batch bundle (majority voting over many vectors)
pub fn batchBundle(vectors: []Hypervector) Hypervector {
    if (vectors.len == 0) return Hypervector.init(0);
    if (vectors.len == 1) return vectors[0].clone();

    const dim = vectors[0].data.trit_len;
    var result = Hypervector.init(dim);

    for (0..dim) |i| {
        var sum: i64 = 0;
        for (vectors) |*v| {
            v.data.ensureUnpacked();
            if (i < v.data.trit_len) {
                sum += v.data.unpacked_cache[i];
            }
        }

        // Majority voting
        if (sum > 0) {
            result.data.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.data.unpacked_cache[i] = -1;
        } else {
            result.data.unpacked_cache[i] = 0;
        }
    }

    result.data.dirty = true;
    return result;
}

/// Weighted bundle
pub fn weightedBundle(vectors: []Hypervector, weights: []f64) Hypervector {
    if (vectors.len == 0) return Hypervector.init(0);
    if (vectors.len != weights.len) return Hypervector.init(0);

    const dim = vectors[0].data.trit_len;
    var result = Hypervector.init(dim);

    for (0..dim) |i| {
        var weighted_sum: f64 = 0;
        for (0..vectors.len) |v| {
            vectors[v].data.ensureUnpacked();
            if (i < vectors[v].data.trit_len) {
                weighted_sum += @as(f64, @floatFromInt(vectors[v].data.unpacked_cache[i])) * weights[v];
            }
        }

        // Threshold
        if (weighted_sum > 0.5) {
            result.data.unpacked_cache[i] = 1;
        } else if (weighted_sum < -0.5) {
            result.data.unpacked_cache[i] = -1;
        } else {
            result.data.unpacked_cache[i] = 0;
        }
    }

    result.data.dirty = true;
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "computeStats" {
    var hv = Hypervector.random(256, 12345);
    const stats = computeStats(&hv);

    try std.testing.expect(stats.dimension == 256);
    try std.testing.expect(stats.positive_count + stats.negative_count + stats.zero_count == 256);
    try std.testing.expect(stats.entropy >= 0);
    try std.testing.expect(stats.entropy <= 1.0);
}

test "distance metrics" {
    var a = Hypervector.random(256, 11111);
    var b = Hypervector.random(256, 22222);

    const hamming = distance(&a, &b, .hamming);
    const cosine = distance(&a, &b, .cosine);
    const euclidean = distance(&a, &b, .euclidean);

    try std.testing.expect(hamming >= 0 and hamming <= 1);
    try std.testing.expect(cosine >= 0 and cosine <= 2);
    try std.testing.expect(euclidean >= 0);
}

test "mutual information" {
    var a = Hypervector.random(256, 33333);
    var b = a.clone(); // Identical vectors

    const mi_same = mutualInformation(&a, &b);
    const mi_self = mutualInformation(&a, &a);

    // MI with itself should be maximum
    try std.testing.expect(mi_self >= mi_same - 0.01);
}

test "batch bundle" {
    var vectors: [5]Hypervector = undefined;
    for (0..5) |i| {
        vectors[i] = Hypervector.random(256, @as(u64, i * 1000));
    }

    var bundled = batchBundle(&vectors);

    // Bundled should be similar to all inputs
    for (&vectors) |*v| {
        const sim = bundled.similarity(v);
        try std.testing.expect(sim > 0.1);
    }
}

test "golden identity" {
    // Verify φ² + 1/φ² = 3
    const result = PHI_SQUARED + 1.0 / PHI_SQUARED;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}
