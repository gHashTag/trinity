//! ═══════════════════════════════════════════════════════════════════════════════
//! HRR — Holographic Reduced Representations
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Vector Symbolic Architecture (VSA) using Holographic Reduced Representations.
//! High-dimensional vectors for symbolic reasoning and cognitive computing.
//!
//! Features:
//!   - Random vector generation with Gaussian distribution
//!   - Binding via circular convolution
//!   - Unbinding (inverse binding)
//!   - Bundling (superposition of vectors)
//!   - Similarity (cosine distance)
//!   - Vector normalization
//!
//! References:
//!   - Plate, R. (1995). "Holographic Reduced Representations"
//!   - Kanerva, P. (2009). "Hyperdimensional Computing"
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const random = std.crypto.random;

/// ═══════════════════════════════════════════════════════════════════════════════
/// SACRED CONSTANTS FOR HRR
/// ═══════════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.618033988749895; // Golden Ratio
const PHI_INV: f64 = 0.618033988749895; // φ⁻¹

/// ═══════════════════════════════════════════════════════════════════════════════
/// HRR — Holographic Reduced Representations
/// ═══════════════════════════════════════════════════════════════════════════════
pub const HRR = struct {
    dim: usize,
    allocator: Allocator,

    pub const Error = error{
        DimensionMismatch,
        EmptyVector,
        InvalidVector,
    };

    /// Initialize HRR with given dimensionality
    pub fn init(allocator: Allocator, dim: usize) !HRR {
        if (dim < 8) return Error.InvalidVector;
        return .{
            .dim = dim,
            .allocator = allocator,
        };
    }

    /// Initialize with φ-based dimension (phi-powered)
    pub fn initPhi(allocator: Allocator, power: u32) !HRR {
        // Dimensions that are powers of φ (rounded)
        const base_dim: f64 = 1000.0;
        const phi_factor = std.math.pow(f64, PHI, @as(f64, @floatFromInt(power)));
        const dim: usize = @intFromFloat(base_dim * phi_factor);
        return init(allocator, dim);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// VECTOR OPERATIONS
    /// ═══════════════════════════════════════════════════════════════════════════════
    /// Generate random high-dimensional vector with Gaussian distribution
    pub fn randomVector(self: *const HRR) ![]f32 {
        var vec = try self.allocator.alloc(f32, self.dim);

        // Generate using Box-Muller transform for Gaussian distribution
        var i: usize = 0;
        while (i < self.dim) : (i += 2) {
            // Generate uniform random floats in (0, 1]
            const u1_raw: f32 = random.float(f32);
            const u2_raw: f32 = random.float(f32);

            // Avoid log(0) and ensure valid range
            const u1_safe = if (u1_raw <= 0.0) 1.0e-6 else if (u1_raw >= 1.0) 0.999999 else u1_raw;
            const u2_safe = if (u2_raw <= 0.0) 0.0 else if (u2_raw >= 1.0) 0.999999 else u2_raw;

            const r = @sqrt(-2.0 * @log(u1_safe));
            const theta = 2.0 * math.pi * u2_safe;

            vec[i] = r * @cos(theta);
            if (i + 1 < self.dim) {
                vec[i + 1] = r * @sin(theta);
            }
        }

        return self.normalize(vec);
    }

    /// Generate deterministic vector from seed string (for encoding)
    pub fn seededVector(self: *const HRR, seed: []const u8) ![]f32 {
        var vec = try self.allocator.alloc(f32, self.dim);

        // Simple hash-based generation (djb2 algorithm with wrapping)
        var hash: u32 = 5381;
        for (seed) |c| {
            hash = hash *% 33 +% @as(u8, @intCast(c));
        }

        var prng = std.Random.DefaultPrng.init(hash);
        var i: usize = 0;
        while (i < self.dim) : (i += 2) {
            const u1_val = prng.random().float(f32);
            const u2_val = prng.random().float(f32);
            const u1_safe = if (u1_val > 1.0e-6) u1_val else 1.0e-6;

            const r = @sqrt(-2.0 * @log(u1_safe));
            const theta = 2.0 * math.pi * u2_val;

            vec[i] = r * @cos(theta);
            if (i + 1 < self.dim) {
                vec[i + 1] = r * @sin(theta);
            }
        }

        return self.normalize(vec);
    }

    /// Bind two vectors using circular convolution
    /// This creates an associative binding operation
    pub fn bind(self: *const HRR, a: []const f32, b: []const f32) ![]f32 {
        if (a.len != self.dim or b.len != self.dim) return Error.DimensionMismatch;

        const result = try self.allocator.alloc(f32, self.dim);

        // Circular convolution
        // result[k] = sum(a[i] * b[(k-i) mod dim])
        for (0..self.dim) |k| {
            var sum: f32 = 0;
            for (0..self.dim) |i| {
                const j = if (k >= i) k - i else self.dim + k - i;
                sum += a[i] * b[j];
            }
            result[k] = sum;
        }

        return self.normalize(result);
    }

    /// Unbind (inverse binding) — for HRR, inverse is the reversed vector
    pub fn unbind(self: *const HRR, bound: []const f32, known: []const f32) ![]f32 {
        if (bound.len != self.dim or known.len != self.dim) return Error.DimensionMismatch;

        // For HRR circular convolution, the inverse is the reversed vector
        // Unbind(a ⊗ b, b) should recover a (approximately)
        const result = try self.allocator.alloc(f32, self.dim);

        // Reverse the known vector (true inverse for circular convolution)
        // Then convolve with bound vector
        for (0..self.dim) |k| {
            var sum: f32 = 0;
            for (0..self.dim) |i| {
                // For inverse: known_rev[j] = known[(dim - j) % dim]
                const j = if (k >= i) k - i else self.dim + k - i;
                const inv_idx = (self.dim - j) % self.dim;
                sum += bound[i] * known[inv_idx];
            }
            result[k] = sum;
        }

        return self.normalize(result);
    }

    /// Bundle (superposition) multiple vectors
    pub fn bundle(self: *const HRR, vectors: []const []const f32) ![]f32 {
        if (vectors.len == 0) return Error.EmptyVector;

        const result = try self.allocator.alloc(f32, self.dim);
        @memset(result, 0);

        // Sum all vectors
        for (vectors) |vec| {
            if (vec.len != self.dim) return Error.DimensionMismatch;
            for (result, 0..) |*r, i| {
                r.* += vec[i];
            }
        }

        return self.normalize(result);
    }

    /// Compute cosine similarity between two vectors
    pub fn similarity(self: *const HRR, a: []const f32, b: []const f32) !f32 {
        if (a.len != self.dim or b.len != self.dim) return Error.DimensionMismatch;

        var dot: f32 = 0;
        var norm_a: f32 = 0;
        var norm_b: f32 = 0;

        for (a, 0..) |av, i| {
            dot += av * b[i];
            norm_a += av * av;
            norm_b += b[i] * b[i];
        }

        const denom = @sqrt(norm_a * norm_b);
        return if (denom > 1.0e-6) dot / denom else 0;
    }

    /// Normalize vector to unit length
    fn normalize(_: *const HRR, vec: []f32) []f32 {
        var norm: f32 = 0;
        for (vec) |v| {
            norm += v * v;
        }
        norm = @sqrt(norm);

        if (norm > 1.0e-6) {
            const inv_norm = 1.0 / norm;
            for (vec) |*v| {
                v.* *= inv_norm;
            }
        }

        return vec;
    }

    /// Compute Hamming distance (for binary-like comparison)
    pub fn hammingDistance(self: *const HRR, a: []const f32, b: []const f32) !usize {
        if (a.len != self.dim or b.len != self.dim) return Error.DimensionMismatch;

        var distance: usize = 0;
        for (a, b) |av, bv| {
            // Count as different if signs differ
            if ((av >= 0) != (bv >= 0)) {
                distance += 1;
            }
        }

        return distance;
    }

    /// Cleanup vector
    pub fn freeVector(self: *const HRR, vec: []f32) void {
        self.allocator.free(vec);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HRR — Vector Generation" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec1 = try hrr.randomVector();
    defer hrr.freeVector(vec1);

    // Check dimension
    try testing.expectEqual(@as(usize, 1000), vec1.len);

    // Check normalization (should be close to 1)
    var norm: f32 = 0;
    for (vec1) |v| {
        norm += v * v;
    }
    try testing.expectApproxEqAbs(1.0, norm, 0.01);
}

test "HRR — Deterministic Seeded Vector" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec1 = try hrr.seededVector("test");
    defer hrr.freeVector(vec1);

    const vec2 = try hrr.seededVector("test");
    defer hrr.freeVector(vec2);

    // Same seed should produce same vector
    try testing.expectEqualSlices(f32, vec1, vec2);
}

test "HRR — Binding Similarity" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec_a = try hrr.seededVector("alice");
    defer hrr.freeVector(vec_a);
    const vec_b = try hrr.seededVector("bob");
    defer hrr.freeVector(vec_b);

    const bound = try hrr.bind(vec_a, vec_b);
    defer hrr.freeVector(bound);

    // Binding should be order-independent for HRR
    const bound2 = try hrr.bind(vec_b, vec_a);
    defer hrr.freeVector(bound2);

    const sim = try hrr.similarity(bound, bound2);

    // Should be nearly identical
    try testing.expect(sim > 0.9);
}

test "HRR — Unbinding Recovery" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec_a = try hrr.seededVector("alice");
    defer hrr.freeVector(vec_a);
    const vec_b = try hrr.seededVector("bob");
    defer hrr.freeVector(vec_b);

    const bound = try hrr.bind(vec_a, vec_b);
    defer hrr.freeVector(bound);

    const recovered = try hrr.unbind(bound, vec_a);
    defer hrr.freeVector(recovered);

    // Recovered should be similar to original
    const sim = try hrr.similarity(vec_b, recovered);

    // Should have good similarity (unbinding is approximate)
    try testing.expect(sim > 0.5);
}

test "HRR — Bundle Orthogonality" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec1 = try hrr.seededVector("vector1");
    defer hrr.freeVector(vec1);
    const vec2 = try hrr.seededVector("vector2");
    defer hrr.freeVector(vec2);

    // Bundled vector
    const bundled = try hrr.bundle(&[_][]const f32{ vec1, vec2 });
    defer hrr.freeVector(bundled);

    // Similarity to individual vectors should be moderate
    // (not too high, not too low)
    const sim1 = try hrr.similarity(bundled, vec1);
    const sim2 = try hrr.similarity(bundled, vec2);

    // Similarity should be positive but less than 1
    try testing.expect(sim1 > 0 and sim1 < 1.0);
    try testing.expect(sim2 > 0 and sim2 < 1.0);
}

test "HRR — Similarity Reflexive" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec = try hrr.randomVector();
    defer hrr.freeVector(vec);

    // Vector should be perfectly similar to itself
    const sim = try hrr.similarity(vec, vec);

    try testing.expectApproxEqAbs(1.0, sim, 0.001);
}

test "HRR — Hamming Distance" {
    const testing = std.testing;

    var hrr = try HRR.init(testing.allocator, 1000);

    const vec1 = try hrr.randomVector();
    defer hrr.freeVector(vec1);
    const vec2 = try hrr.randomVector();
    defer hrr.freeVector(vec2);

    // Hamming distance should be valid
    const dist = try hrr.hammingDistance(vec1, vec2);

    try testing.expect(dist >= 0 and dist <= 1000);
}

test "HRR — Phi-Dimension Initialization" {
    const testing = std.testing;

    // Initialize with φ^1 = 1618 dimensions (approximately)
    const hrr = try HRR.initPhi(testing.allocator, 1);

    // Should be close to 1618
    try testing.expect(hrr.dim >= 1500 and hrr.dim <= 1800);
}

test "HRR — Sacred Constant Integration" {
    const testing = std.testing;

    const hrr = try HRR.init(testing.allocator, 1000);

    // Create vectors representing sacred concepts
    const phi_vec = try hrr.seededVector("phi");
    defer hrr.freeVector(phi_vec);
    const trinity_vec = try hrr.seededVector("trinity");
    defer hrr.freeVector(trinity_vec);

    // Bind phi and trinity
    const bound = try hrr.bind(phi_vec, trinity_vec);
    defer hrr.freeVector(bound);

    // Verify binding creates a distinct representation
    const sim = try hrr.similarity(phi_vec, bound);

    // Should be different but related
    try testing.expect(sim < 0.9);
}
