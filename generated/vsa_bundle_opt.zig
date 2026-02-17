// ═══════════════════════════════════════════════════════════════════════════════
// vsa_bundle_opt v1.0.0 - Generated from vsa_optimization.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// Optimized N-way bundle operation for ternary VSA vectors.
// Uses accumulator-based majority voting with SIMD-friendly layout.
// Target: 99.5% recall at N=1000, sub-millisecond for dim=1024.
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// DO NOT EDIT - This file is auto-generated from specs/tri/vsa_optimization.vibee
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const vsa = @import("vsa");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_BUNDLE_N: usize = 1000;
pub const DEFAULT_DIM: usize = 1024;
pub const RECALL_TARGET: f64 = 0.995;
pub const CONVERGENCE_TRIALS: usize = 100;

// φ-constants
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY_CONST: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE ACCUMULATOR — O(N*D) majority-vote bundling
// ═══════════════════════════════════════════════════════════════════════════════
//
// Algorithm:
//   1. Initialize sums[D] = {0}
//   2. For each vector v in 1..N: sums[i] += v[i]
//   3. For each dimension i: result[i] = sign(sums[i])
//   4. SIMD hint: process 32 dimensions at once using i16 accumulators
//   5. Memory: 2*D bytes for i16 accumulators (2KB for D=1024)
//
// ═══════════════════════════════════════════════════════════════════════════════

pub const BundleAccumulator = struct {
    sums: [vsa.MAX_TRITS]i32,
    count: usize,
    dim: usize,

    const Self = @This();

    /// Initialize accumulator for vectors of given dimension
    pub fn init(dim: usize) Self {
        var acc = Self{
            .sums = undefined,
            .count = 0,
            .dim = dim,
        };
        @memset(acc.sums[0..dim], 0);
        return acc;
    }

    /// Add a ternary vector to the accumulator — O(D)
    pub fn accumulate(self: *Self, v: *vsa.HybridBigInt) void {
        v.ensureUnpacked();
        const len = @min(self.dim, v.trit_len);
        for (0..len) |i| {
            self.sums[i] += @as(i32, v.unpacked_cache[i]);
        }
        self.count += 1;
    }

    /// Extract final bundled vector via sign(sums[i]) threshold — O(D)
    pub fn finalize(self: *Self) vsa.HybridBigInt {
        var result = vsa.HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;
        result.trit_len = self.dim;

        for (0..self.dim) |i| {
            if (self.sums[i] > 0) {
                result.unpacked_cache[i] = 1;
            } else if (self.sums[i] < 0) {
                result.unpacked_cache[i] = -1;
            } else {
                result.unpacked_cache[i] = 0;
            }
        }

        return result;
    }
};

/// Bundle N vectors using accumulator approach — O(N*D)
pub fn bundleN(vectors: []vsa.HybridBigInt, dim: usize) vsa.HybridBigInt {
    var acc = BundleAccumulator.init(dim);
    for (vectors) |*v| {
        acc.accumulate(v);
    }
    return acc.finalize();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — Bundle-N Optimization
// ═══════════════════════════════════════════════════════════════════════════════

test "bundleN_accumulator_basic — 3 vectors match bundle3" {
    const dim = 256;
    var v0 = vsa.randomVector(dim, 42);
    var v1 = vsa.randomVector(dim, 43);
    var v2 = vsa.randomVector(dim, 44);

    // BundleN via accumulator
    var acc = BundleAccumulator.init(dim);
    acc.accumulate(&v0);
    acc.accumulate(&v1);
    acc.accumulate(&v2);
    var bundle_n = acc.finalize();

    // Compare with built-in bundle3
    var bundle_ref = vsa.bundle3(&v0, &v1, &v2);

    // They should be very similar (both use majority vote)
    const sim = vsa.cosineSimilarity(&bundle_n, &bundle_ref);
    try std.testing.expect(sim > 0.9);
}

test "bundleN_10_vectors — all inputs have positive recall" {
    const dim = DEFAULT_DIM;
    const n = 10;

    var vectors: [n]vsa.HybridBigInt = undefined;
    for (&vectors, 0..) |*v, i| {
        v.* = vsa.randomVector(dim, 2024 + i);
    }

    var acc = BundleAccumulator.init(dim);
    for (&vectors) |*v| {
        acc.accumulate(v);
    }
    var bundled = acc.finalize();

    var positive_count: usize = 0;
    for (&vectors) |*v| {
        const sim = vsa.cosineSimilarity(&bundled, v);
        if (sim > 0.0) positive_count += 1;
    }

    // At N=10, most inputs should have positive similarity
    try std.testing.expect(positive_count >= 7);
}

test "bundleN_100_vectors — recall above 50 percent" {
    const dim = DEFAULT_DIM;
    const n = 100;

    var vectors: [n]vsa.HybridBigInt = undefined;
    for (&vectors, 0..) |*v, i| {
        v.* = vsa.randomVector(dim, 1234 + i);
    }

    var acc = BundleAccumulator.init(dim);
    for (&vectors) |*v| {
        acc.accumulate(v);
    }
    var bundled = acc.finalize();

    var positive_count: usize = 0;
    for (&vectors) |*v| {
        const sim = vsa.cosineSimilarity(&bundled, v);
        if (sim > 0.0) positive_count += 1;
    }

    const recall = @as(f64, @floatFromInt(positive_count)) / @as(f64, @floatFromInt(n));
    // At N=100, recall should be above 50%
    try std.testing.expect(recall >= 0.50);
}

test "bundleN_function_api — convenience function works" {
    const dim = 256;

    var vectors: [5]vsa.HybridBigInt = undefined;
    for (&vectors, 0..) |*v, i| {
        v.* = vsa.randomVector(dim, 555 + i);
    }

    var bundled = bundleN(&vectors, dim);

    // Should produce a valid vector
    try std.testing.expectEqual(dim, bundled.trit_len);
    try std.testing.expect(bundled.mode == .unpacked_mode);
}

test "bundleN_empty — zero count produces zero vector" {
    const dim = 128;
    var acc = BundleAccumulator.init(dim);
    try std.testing.expectEqual(@as(usize, 0), acc.count);

    var result = acc.finalize();
    // All zeros
    for (0..dim) |i| {
        try std.testing.expectEqual(@as(i8, 0), result.unpacked_cache[i]);
    }
}

test "bundleN_single — single vector returns itself" {
    const dim = 256;
    var v = vsa.randomVector(dim, 7);

    var acc = BundleAccumulator.init(dim);
    acc.accumulate(&v);
    var result = acc.finalize();

    // Single vector bundle should be identical to input
    for (0..dim) |i| {
        const expected: i8 = if (v.unpacked_cache[i] > 0) 1 else if (v.unpacked_cache[i] < 0) @as(i8, -1) else 0;
        try std.testing.expectEqual(expected, result.unpacked_cache[i]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════
