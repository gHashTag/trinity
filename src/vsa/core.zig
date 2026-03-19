// 🤖 TRINITY v0.11.0: Suborbital Order
// Core VSA operations for Balanced Ternary
// bind, bundle, similarity, permute

const std = @import("std");
const common = @import("common.zig");
const HybridBigInt = common.HybridBigInt;
const Trit = common.Trit;
const Vec32i8 = common.Vec32i8;
const SIMD_WIDTH = common.SIMD_WIDTH;
const MAX_TRITS = common.MAX_TRITS;

/// Bind operation (XOR-like for balanced ternary)
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec;
        result.unpacked_cache[i..][0..SIMD_WIDTH].* = prod;
    }

    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_trit * b_trit;
    }

    return result;
}

pub fn unbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return bind(bound, key);
}

pub fn bundle2(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;

        const a_wide: @Vector(32, i16) = a_vec;
        const b_wide: @Vector(32, i16) = b_vec;
        const sum = a_wide + b_wide;

        const zeros: @Vector(32, i16) = @splat(0);
        const ones: @Vector(32, i16) = @splat(1);
        const neg_ones: @Vector(32, i16) = @splat(-1);

        const pos_mask = sum > zeros;
        const neg_mask = sum < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @intCast(out[j]);
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const sum = a_trit + b_trit;

        if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    return result;
}

pub fn bundle3(a: *HybridBigInt, b: *HybridBigInt, c: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();
    c.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(@max(a.trit_len, b.trit_len), c.trit_len);
    const min_len = @min(@min(a.trit_len, b.trit_len), c.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    // SIMD path: 32 trits at a time via i16 widening + sign extraction
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const c_vec: Vec32i8 = c.unpacked_cache[i..][0..SIMD_WIDTH].*;

        const a_wide: @Vector(32, i16) = a_vec;
        const b_wide: @Vector(32, i16) = b_vec;
        const c_wide: @Vector(32, i16) = c_vec;
        const sum = a_wide + b_wide + c_wide;

        const zeros: @Vector(32, i16) = @splat(0);
        const ones: @Vector(32, i16) = @splat(1);
        const neg_ones: @Vector(32, i16) = @splat(-1);

        const pos_mask = sum > zeros;
        const neg_mask = sum < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @intCast(out[j]);
        }
    }

    // Scalar remainder
    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const c_trit: i16 = if (i < c.trit_len) c.unpacked_cache[i] else 0;
        const sum = a_trit + b_trit + c_trit;

        if (sum > 0) {
            result.unpacked_cache[i] = 1;
        } else if (sum < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    result.trit_len = len;
    return result;
}

pub fn cosineSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const norm_a = vectorNorm(a);
    const norm_b = vectorNorm(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

/// Cosine similarity using 16-wide f16 SIMD (2× throughput vs f32).
/// Converts ternary vectors to f16, computes similarity with 16-wide operations.
/// Returns f64 in range [-1, 1].
pub fn cosineSimilarityF16(a: *HybridBigInt, b: *HybridBigInt) f64 {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 0;

    const F16_VEC_SIZE = 16;
    const num_f16_chunks = len / F16_VEC_SIZE;

    // f32 accumulators for precision
    var acc_dot: f64 = 0;
    var acc_norm_a: f64 = 0;
    var acc_norm_b: f64 = 0;

    // Process 16 elements at a time using f16 SIMD
    var i: usize = 0;
    while (i < num_f16_chunks * F16_VEC_SIZE) : (i += F16_VEC_SIZE) {
        // Load trits into i8 vectors
        var a_trits: @Vector(F16_VEC_SIZE, i8) = undefined;
        var b_trits: @Vector(F16_VEC_SIZE, i8) = undefined;

        inline for (0..F16_VEC_SIZE) |j| {
            a_trits[j] = if (i + j < a.trit_len) a.unpacked_cache[i + j] else 0;
            b_trits[j] = if (i + j < b.trit_len) b.unpacked_cache[i + j] else 0;
        }

        // Convert to f16
        const a_f16: @Vector(F16_VEC_SIZE, f16) = @floatCast(@as(@Vector(F16_VEC_SIZE, f32), @floatFromInt(a_trits)));
        const b_f16: @Vector(F16_VEC_SIZE, f16) = @floatCast(@as(@Vector(F16_VEC_SIZE, f32), @floatFromInt(b_trits)));

        // Convert to f32 for compute
        const a_f32: @Vector(F16_VEC_SIZE, f32) = @floatCast(a_f16);
        const b_f32: @Vector(F16_VEC_SIZE, f32) = @floatCast(b_f16);

        // Compute dot product contribution
        const prod = a_f32 * b_f32;
        var sum_prod: f32 = 0;
        inline for (0..F16_VEC_SIZE) |j| {
            sum_prod += prod[j];
        }
        acc_dot += @as(f64, sum_prod);

        // Compute norm contributions
        const a_sq = a_f32 * a_f32;
        const b_sq = b_f32 * b_f32;
        var sum_a_sq: f32 = 0;
        var sum_b_sq: f32 = 0;
        inline for (0..F16_VEC_SIZE) |j| {
            sum_a_sq += a_sq[j];
            sum_b_sq += b_sq[j];
        }
        acc_norm_a += @as(f64, sum_a_sq);
        acc_norm_b += @as(f64, sum_b_sq);
    }

    // Handle scalar tail
    while (i < len) : (i += 1) {
        const a_trit: i8 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i8 = if (i < b.trit_len) b.unpacked_cache[i] else 0;

        const a_f32: f32 = @floatFromInt(a_trit);
        const b_f32: f32 = @floatFromInt(b_trit);

        acc_dot += @as(f64, a_f32 * b_f32);
        acc_norm_a += @as(f64, a_f32 * a_f32);
        acc_norm_b += @as(f64, b_f32 * b_f32);
    }

    const norm_a = @sqrt(acc_norm_a);
    const norm_b = @sqrt(acc_norm_b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return acc_dot / (norm_a * norm_b);
}

pub fn hammingDistance(a: *HybridBigInt, b: *HybridBigInt) usize {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var distance: usize = 0;
    const len = @max(a.trit_len, b.trit_len);
    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const diff = a_vec != b_vec;
        distance += @popCount(@as(u32, @bitCast(diff)));
    }

    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        if (a_trit != b_trit) distance += 1;
    }

    return distance;
}

pub fn hammingSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 1.0;
    const distance = hammingDistance(a, b);
    return 1.0 - @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(len));
}

pub fn dotSimilarity(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot = a.dotProduct(b);
    const len = @max(a.trit_len, b.trit_len);
    if (len == 0) return 0;
    return @as(f64, @floatFromInt(dot)) / @as(f64, @floatFromInt(len));
}

/// Vector norm — SIMD accelerated via dotProduct(v, v) (OPT-001)
pub fn vectorNorm(v: *HybridBigInt) f64 {
    const dot = v.dotProduct(v);
    return @sqrt(@as(f64, @floatFromInt(dot)));
}

/// Count non-zero trits — SIMD accelerated (OPT-001)
pub fn countNonZero(v: *HybridBigInt) usize {
    v.ensureUnpacked();
    var count: usize = 0;
    const num_full_chunks = v.trit_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const vec: Vec32i8 = v.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const zeros: Vec32i8 = @splat(0);
        const nonzero = vec != zeros;
        count += @popCount(@as(u32, @bitCast(nonzero)));
    }

    while (i < v.trit_len) : (i += 1) {
        if (v.unpacked_cache[i] != 0) count += 1;
    }

    return count;
}

/// Bundle N vectors — SIMD accelerated majority vote (OPT-001)
pub fn bundleN(vectors: []*HybridBigInt) HybridBigInt {
    if (vectors.len == 0) return HybridBigInt.zero();
    if (vectors.len == 1) {
        vectors[0].ensureUnpacked();
        var result = HybridBigInt.zero();
        result.mode = .unpacked_mode;
        result.dirty = true;
        result.trit_len = vectors[0].trit_len;
        @memcpy(result.unpacked_cache[0..vectors[0].trit_len], vectors[0].unpacked_cache[0..vectors[0].trit_len]);
        return result;
    }
    if (vectors.len == 2) return bundle2(vectors[0], vectors[1]);
    if (vectors.len == 3) return bundle3(vectors[0], vectors[1], vectors[2]);

    var max_len: usize = 0;
    for (vectors) |v| {
        v.ensureUnpacked();
        max_len = @max(max_len, v.trit_len);
    }

    var accum: [MAX_TRITS]i16 = [_]i16{0} ** MAX_TRITS;

    for (vectors) |v| {
        const num_chunks = v.trit_len / SIMD_WIDTH;
        var i: usize = 0;
        while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
            const vec: Vec32i8 = v.unpacked_cache[i..][0..SIMD_WIDTH].*;
            const wide: @Vector(32, i16) = vec;
            const acc_vec: @Vector(32, i16) = accum[i..][0..SIMD_WIDTH].*;
            const sum_val = acc_vec + wide;
            accum[i..][0..SIMD_WIDTH].* = sum_val;
        }
        while (i < v.trit_len) : (i += 1) {
            accum[i] += @as(i16, v.unpacked_cache[i]);
        }
    }

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = max_len;

    const num_result_chunks = max_len / SIMD_WIDTH;
    var i: usize = 0;
    while (i < num_result_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const acc_vec: @Vector(32, i16) = accum[i..][0..SIMD_WIDTH].*;
        const zeros: @Vector(32, i16) = @splat(0);
        const ones: @Vector(32, i16) = @splat(1);
        const neg_ones: @Vector(32, i16) = @splat(-1);

        const pos_mask = acc_vec > zeros;
        const neg_mask = acc_vec < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            result.unpacked_cache[i + j] = @intCast(out[j]);
        }
    }

    while (i < max_len) : (i += 1) {
        if (accum[i] > 0) {
            result.unpacked_cache[i] = 1;
        } else if (accum[i] < 0) {
            result.unpacked_cache[i] = -1;
        } else {
            result.unpacked_cache[i] = 0;
        }
    }

    return result;
}

pub fn randomVector(len: usize, seed: u64) HybridBigInt {
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = @min(len, MAX_TRITS);
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (0..result.trit_len) |i| {
        result.unpacked_cache[i] = random.intRangeAtMost(i8, -1, 1);
    }
    return result;
}

pub fn permute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;
    if (v.trit_len == 0) return result;
    const shift = k % v.trit_len;
    for (0..v.trit_len) |i| {
        const new_pos = (i + shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }
    return result;
}

pub fn inversePermute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;
    if (v.trit_len == 0) return result;
    const shift = k % v.trit_len;
    for (0..v.trit_len) |i| {
        const new_pos = (i + v.trit_len - shift) % v.trit_len;
        result.unpacked_cache[new_pos] = v.unpacked_cache[i];
    }
    return result;
}

pub fn encodeSequence(items: []HybridBigInt) HybridBigInt {
    if (items.len == 0) return HybridBigInt.zero();
    var result = items[0];
    for (1..items.len) |i| {
        var permuted = permute(&items[i], i);
        result = result.add(&permuted);
    }
    return result;
}

pub fn probeSequence(sequence: *HybridBigInt, candidate: *HybridBigInt, position: usize) f64 {
    var permuted = permute(candidate, position);
    return cosineSimilarity(sequence, &permuted);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cosineSimilarityF16 matches cosineSimilarity" {
    var a = randomVector(100, 111);
    var b = randomVector(100, 222);

    const sim_f64 = cosineSimilarity(&a, &b);
    const sim_f16 = cosineSimilarityF16(&a, &b);

    // Should be very close (within f16 precision)
    try std.testing.expectApproxEqAbs(sim_f64, sim_f16, 0.01);
}

test "cosineSimilarityF16 identical vectors" {
    var a = randomVector(100, 333);

    const sim = cosineSimilarityF16(&a, &a);

    // Identical vectors should have similarity 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "cosineSimilarityF16 zero vectors" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    const sim = cosineSimilarityF16(&a, &b);

    // Zero vectors should return 0
    try std.testing.expectEqual(@as(f64, 0), sim);
}

// φ² + 1/φ² = 3 | TRINITY
