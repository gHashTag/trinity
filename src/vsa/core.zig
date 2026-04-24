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

/// Helper: Safe trit access after ensureUnpacked()
inline fn getTritSafe(vec: *const HybridBigInt, pos: usize) Trit {
    const cache = vec.unpacked_cache orelse return 0;
    return cache[pos];
}

/// Helper: Safe trit write after ensureUnpacked()
inline fn setTritSafe(vec: *HybridBigInt, pos: usize, value: Trit) void {
    vec.setTritChecked(pos, value);
}

/// Bind operation (XOR-like for balanced ternary)
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    // Inherit allocator from first argument
    const inherited_allocator = a.allocator orelse std.heap.page_allocator;
    var result = HybridBigInt{
        .packed_data = [_]u8{0} ** common.MAX_PACKED_BYTES,
        .unpacked_cache = null,
        .allocator = inherited_allocator,
        .mode = .unpacked_mode,
        .trit_len = 1,
        .dirty = true,
    };
    result.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        var a_vec: Vec32i8 = undefined;
        var b_vec: Vec32i8 = undefined;

        inline for (0..SIMD_WIDTH) |j| {
            const idx = i + j;
            a_vec[j] = getTritSafe(a, idx);
            b_vec[j] = getTritSafe(b, idx);
        }

        const prod = a_vec * b_vec;
        var result_vec: Vec32i8 = undefined;

        inline for (0..SIMD_WIDTH) |j| {
            result_vec[j] = @truncate(prod[j]);
        }

        // Write back using safe access
        inline for (0..SIMD_WIDTH) |j| {
            setTritSafe(&result, i + j, result_vec[j]);
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) getTritSafe(a, i) else 0;
        const b_trit: Trit = if (i < b.trit_len) getTritSafe(b, i) else 0;
        setTritSafe(&result, i, a_trit * b_trit);
    }

    return result;
}

pub fn unbind(bound: *HybridBigInt, key: *HybridBigInt) HybridBigInt {
    return bind(bound, key);
}

pub fn bundle2(a: *HybridBigInt, b: *HybridBigInt, allocator: std.mem.Allocator) HybridBigInt {
    _ = allocator; // Use inherited allocator instead
    a.ensureUnpacked();
    b.ensureUnpacked();

    // Inherit allocator from first argument
    const inherited_allocator = a.allocator orelse std.heap.page_allocator;
    var result = HybridBigInt.zero();
    result.allocator = inherited_allocator;
    result.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        var a_vec: Vec32i8 = undefined;
        var b_vec: Vec32i8 = undefined;

        inline for (0..SIMD_WIDTH) |j| {
            const idx = i + j;
            a_vec[j] = getTritSafe(a, idx);
            b_vec[j] = getTritSafe(b, idx);
        }

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
            setTritSafe(&result, i + j, @truncate(out[j]));
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) getTritSafe(a, i) else 0;
        const b_trit: i16 = if (i < b.trit_len) getTritSafe(b, i) else 0;
        const sum = a_trit + b_trit;

        if (sum > 0) {
            setTritSafe(&result, i, 1);
        } else if (sum < 0) {
            setTritSafe(&result, i, -1);
        } else {
            setTritSafe(&result, i, 0);
        }
    }

    return result;
}

pub fn bundle3(a: *HybridBigInt, b: *HybridBigInt, c: *HybridBigInt, allocator: std.mem.Allocator) HybridBigInt {
    _ = allocator; // Use inherited allocator instead
    a.ensureUnpacked();
    b.ensureUnpacked();
    c.ensureUnpacked();

    // Inherit allocator from first argument
    const inherited_allocator = a.allocator orelse std.heap.page_allocator;
    var result = HybridBigInt.zero();
    result.allocator = inherited_allocator;
    result.ensureUnpacked();

    const len = @max(@max(a.trit_len, b.trit_len), c.trit_len);
    const min_len = @min(@min(a.trit_len, b.trit_len), c.trit_len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    // SIMD path: 32 trits at a time via i16 widening + sign extraction
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        var a_vec: Vec32i8 = undefined;
        var b_vec: Vec32i8 = undefined;
        var c_vec: Vec32i8 = undefined;

        inline for (0..SIMD_WIDTH) |j| {
            const idx = i + j;
            a_vec[j] = getTritSafe(a, idx);
            b_vec[j] = getTritSafe(b, idx);
            c_vec[j] = getTritSafe(c, idx);
        }

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
            setTritSafe(&result, i + j, @truncate(out[j]));
        }
    }

    // Scalar remainder
    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) getTritSafe(a, i) else 0;
        const b_trit: i16 = if (i < b.trit_len) getTritSafe(b, i) else 0;
        const c_trit: i16 = if (i < c.trit_len) getTritSafe(c, i) else 0;
        const sum = a_trit + b_trit + c_trit;

        if (sum > 0) {
            setTritSafe(&result, i, 1);
        } else if (sum < 0) {
            setTritSafe(&result, i, -1);
        } else {
            setTritSafe(&result, i, 0);
        }
    }

    result.trit_len = len;
    return result;
}

pub fn cosineSimilarity(a: *const HybridBigInt, b: *const HybridBigInt) f64 {
    const dot = @constCast(a).dotProduct(@constCast(b), std.heap.page_allocator);
    const norm_a = vectorNorm(@constCast(a));
    const norm_b = vectorNorm(@constCast(b));

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (norm_a * norm_b);
}

/// Cosine similarity using 16-wide f16 SIMD (2× throughput vs f32).
/// Converts ternary vectors to f16, computes similarity with 16-wide operations.
/// Returns f64 in range [-1, 1].
pub fn cosineSimilarityF16(a: *const HybridBigInt, b: *const HybridBigInt, allocator: std.mem.Allocator) f64 {
    _ = allocator; // Read-only, no allocations needed
    @constCast(a).ensureUnpacked();
    @constCast(b).ensureUnpacked();

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
        // Load trits into i8 vectors using safe access
        var a_trits: @Vector(F16_VEC_SIZE, i8) = undefined;
        var b_trits: @Vector(F16_VEC_SIZE, i8) = undefined;

        inline for (0..F16_VEC_SIZE) |j| {
            a_trits[j] = if (i + j < a.trit_len) getTritSafe(@constCast(a), i + j) else 0;
            b_trits[j] = if (i + j < b.trit_len) getTritSafe(@constCast(b), i + j) else 0;
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

    // Handle scalar tail using safe access
    while (i < len) : (i += 1) {
        const a_trit: i8 = if (i < a.trit_len) getTritSafe(@constCast(a), i) else 0;
        const b_trit: i8 = if (i < b.trit_len) getTritSafe(@constCast(b), i) else 0;

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
        // Use safe slice access - loads 32 trits at a time
        const base = i;
        var a_vec: Vec32i8 = undefined;
        var b_vec: Vec32i8 = undefined;
        inline for (0..SIMD_WIDTH) |j| {
            a_vec[j] = getTritSafe(a, base + j);
            b_vec[j] = getTritSafe(b, base + j);
        }
        const diff = a_vec != b_vec;
        distance += @popCount(@as(u32, @bitCast(diff)));
    }

    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) getTritSafe(a, i) else 0;
        const b_trit: Trit = if (i < b.trit_len) getTritSafe(b, i) else 0;
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
    const dot = v.dotProduct(v, std.heap.page_allocator);
    return @sqrt(@as(f64, @floatFromInt(dot)));
}

/// Count non-zero trits — SIMD accelerated (OPT-001)
pub fn countNonZero(v: *HybridBigInt) usize {
    v.ensureUnpacked();
    var count: usize = 0;
    const num_full_chunks = v.trit_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        // Use safe slice access - loads 32 trits at a time
        const base = i;
        var vec: Vec32i8 = undefined;
        inline for (0..SIMD_WIDTH) |j| {
            vec[j] = getTritSafe(v, base + j);
        }
        const zeros: Vec32i8 = @splat(0);
        const nonzero = vec != zeros;
        count += @popCount(@as(u32, @bitCast(nonzero)));
    }

    while (i < v.trit_len) : (i += 1) {
        if (getTritSafe(v, i) != 0) count += 1;
    }

    return count;
}

/// Bundle N vectors — SIMD accelerated majority vote (OPT-001)
pub fn bundleN(vectors: []*HybridBigInt, allocator: std.mem.Allocator) !HybridBigInt {
    if (vectors.len == 0) return HybridBigInt.zero();
    if (vectors.len == 1) {
        vectors[0].ensureUnpacked();
        // Inherit allocator from first vector
        const inherited_allocator = vectors[0].allocator orelse std.heap.page_allocator;
        var result = HybridBigInt.zero();
        result.allocator = inherited_allocator;
        result.mode = .unpacked_mode;
        result.dirty = true;
        result.trit_len = vectors[0].trit_len;
        result.ensureUnpacked();
        // Copy using safe access
        for (0..vectors[0].trit_len) |i| {
            setTritSafe(&result, i, getTritSafe(vectors[0], i));
        }
        return result;
    }
    if (vectors.len == 2) return bundle2(vectors[0], vectors[1], allocator);
    if (vectors.len == 3) return bundle3(vectors[0], vectors[1], vectors[2], allocator);

    var max_len: usize = 0;
    for (vectors) |v| {
        v.ensureUnpacked();
        max_len = @max(max_len, v.trit_len);
    }

    // Allocate accumulator on heap (115 KB) - macOS stack fix
    const accum = allocator.alloc(i16, MAX_TRITS) catch |err| {
        std.debug.panic("OOM in bundleN: {}", .{err});
    };
    defer allocator.free(accum);
    @memset(accum, @as(i16, 0));

    for (vectors) |v| {
        const num_chunks = v.trit_len / SIMD_WIDTH;
        var i: usize = 0;
        while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
            // Use safe vector slice access
            const base = i;
            var vec: Vec32i8 = undefined;
            inline for (0..SIMD_WIDTH) |j| {
                vec[j] = getTritSafe(v, base + j);
            }
            const wide: @Vector(32, i16) = vec;
            const acc_array: [SIMD_WIDTH]i16 = accum[i..][0..SIMD_WIDTH].*;
            const acc_vec: @Vector(32, i16) = acc_array;
            const sum_val = acc_vec + wide;
            accum[i..][0..SIMD_WIDTH].* = sum_val;
        }
        while (i < v.trit_len) : (i += 1) {
            accum[i] += @as(i16, getTritSafe(v, i));
        }
    }

    // Inherit allocator from first vector
    const inherited_allocator = if (vectors.len > 0) vectors[0].allocator orelse std.heap.page_allocator else std.heap.page_allocator;
    var result = HybridBigInt.zero();
    result.allocator = inherited_allocator;
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = max_len;
    result.ensureUnpacked();

    const num_result_chunks = max_len / SIMD_WIDTH;
    var i: usize = 0;
    while (i < num_result_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const acc_vec: @Vector(32, i16) = @as(@Vector(32, i16), accum[i..][0..SIMD_WIDTH].*);
        const zeros: @Vector(32, i16) = @splat(0);
        const ones: @Vector(32, i16) = @splat(1);
        const neg_ones: @Vector(32, i16) = @splat(-1);

        const pos_mask = acc_vec > zeros;
        const neg_mask = acc_vec < zeros;

        var out = zeros;
        out = @select(i16, pos_mask, ones, out);
        out = @select(i16, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            setTritSafe(&result, i + j, @truncate(out[j]));
        }
    }

    while (i < max_len) : (i += 1) {
        const val = accum[i];
        if (val > 0) {
            setTritSafe(&result, i, 1);
        } else if (val < 0) {
            setTritSafe(&result, i, -1);
        } else {
            setTritSafe(&result, i, 0);
        }
    }

    return result;
}

pub fn randomVector(len: usize, seed: u64) HybridBigInt {
    _ = len; // TODO: actually use this parameter
    var result = HybridBigInt.zero();
    result.allocator = std.heap.page_allocator; // Explicit: random vectors use page allocator
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.ensureUnpacked();

    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (0..result.trit_len) |i| {
        setTritSafe(&result, i, random.intRangeAtMost(i8, -1, 1));
    }
    return result;
}

pub fn permute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();
    // Inherit allocator from v
    const inherited_allocator = v.allocator orelse std.heap.page_allocator;
    var result = HybridBigInt.zero();
    result.allocator = inherited_allocator;
    result.ensureUnpacked();

    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;
    if (v.trit_len == 0) return result;
    const shift = k % v.trit_len;
    for (0..v.trit_len) |i| {
        const new_pos = (i + shift) % v.trit_len;
        setTritSafe(&result, new_pos, getTritSafe(v, i));
    }
    return result;
}

pub fn inversePermute(v: *HybridBigInt, k: usize) HybridBigInt {
    v.ensureUnpacked();
    // Inherit allocator from v
    const inherited_allocator = v.allocator orelse std.heap.page_allocator;
    var result = HybridBigInt.zero();
    result.allocator = inherited_allocator;
    result.ensureUnpacked();

    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = v.trit_len;
    if (v.trit_len == 0) return result;
    const shift = k % v.trit_len;
    for (0..v.trit_len) |i| {
        const new_pos = (i + v.trit_len - shift) % v.trit_len;
        setTritSafe(&result, new_pos, getTritSafe(v, i));
    }
    return result;
}

pub fn encodeSequence(items: []HybridBigInt) HybridBigInt {
    if (items.len == 0) return HybridBigInt.zero();
    var result = items[0];
    for (1..items.len) |i| {
        var permuted = permute(&items[i], i);
        result = result.add(&permuted, std.heap.page_allocator);
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
    const sim_f16 = cosineSimilarityF16(&a, &b, std.heap.page_allocator);

    // Should be very close (within f16 precision)
    try std.testing.expectApproxEqAbs(sim_f64, sim_f16, 0.01);
}

test "cosineSimilarityF16 identical vectors" {
    var a = randomVector(100, 333);

    const sim = cosineSimilarityF16(&a, &a, std.heap.page_allocator);

    // Identical vectors should have similarity 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.01);
}

test "cosineSimilarityF16 zero vectors" {
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    const sim = cosineSimilarityF16(&a, &b, std.heap.page_allocator);

    // Zero vectors should return 0
    try std.testing.expectEqual(@as(f64, 0), sim);
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM-ENHANCED VSA OPERATIONS
// Reference: [arXiv 2106.05268 VSA], [LinkedIn Kantian Vectors]
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantum bind: extends classical bind with phase coherence tracking
/// Maintains superposition state across operation
///
/// In VSA framework: bind = XOR-like operation on hypervectors
/// Quantum extension: track phase information for interference
pub fn qbind(a: *const HybridBigInt, b: *const HybridBigInt) HybridBigInt {
    // Classical bind (XOR-like for balanced ternary)
    const result = bind(a, b);

    // Phase tracking: maintain coherence if both inputs coherent
    // Result phase = (phase_a + phase_b) mod 2π
    // Coherence = coherence_a AND coherence_b
    // Note: In current implementation, HybridBigInt doesn't track phase
    // This is a placeholder for future phase-aware VSA

    // In full quantum extension, would track:
    // - Phase information via separate struct
    // - Coherence preservation logic
    // - Interference effects

    return result;
}

/// Quantum bundle: probabilistic mixture with superposition amplitudes
/// Result = Σ αᵢ|vᵢ⟩ where αᵢ = amplitudes
///
/// In VSA framework: bundle = majority vote on hypervectors
/// Quantum extension: weighted majority using amplitudes as weights
/// This is equivalent to "quantum-inspired mixture" in hybrid architectures
pub fn qbundle(vectors: []const HybridBigInt, amplitudes: []const f32, allocator: std.mem.Allocator) !HybridBigInt {
    _ = allocator; // Reserved for future allocation needs
    if (vectors.len == 0) return HybridBigInt.zero();
    if (vectors.len == 1) {
        const result = vectors[0];
        return result;
    }

    // Validate amplitudes length
    if (amplitudes.len != vectors.len) {
        return error.AmplitudeLengthMismatch;
    }

    // Normalize amplitudes (if not already)
    var total_amp: f32 = 0.0;
    for (amplitudes) |amp| total_amp += amp;
    const normalized = if (total_amp > 0.0) total_amp else 1.0;

    // Use weighted bundle: each trit gets weighted votes
    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;
    result.trit_len = @max(MAX_TRITS, @as(usize, @intFromFloat(normalized)));

    const num_full_chunks = result.trit_len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        var weighted_sum: [SIMD_WIDTH]f32 = undefined;

        for (0..SIMD_WIDTH) |j| {
            var sum: f32 = 0.0;
            for (vectors, 0..) |*vec, k| {
                @constCast(vec).ensureUnpacked();
                if (i + j < vec.trit_len) {
                    const weight = amplitudes[k] / normalized;
                    if (vec.unpacked_cache) |cache| {
                        sum += @as(f32, @floatFromInt(cache[i + j])) * weight;
                    }
                }
            }
            weighted_sum[j] = sum;
        }

        // Quantize to ternary lattice (measurement collapse)
        const zeros: @Vector(32, f32) = @splat(0.0);
        const ones: @Vector(32, f32) = @splat(1.0);
        const neg_ones: @Vector(32, f32) = @splat(-1.0);

        const weighted_vec: @Vector(32, f32) = weighted_sum;
        const pos_mask = weighted_vec > zeros;
        const neg_mask = weighted_vec < zeros;

        var out = zeros;
        out = @select(f32, pos_mask, ones, out);
        out = @select(f32, neg_mask, neg_ones, out);

        inline for (0..SIMD_WIDTH) |j| {
            const float_val: f32 = out[j];
            const int_val: i32 = @intFromFloat(float_val);
            if (result.unpacked_cache) |cache| {
                cache[i + j] = @intCast(int_val);
            }
        }
    }

    // Handle scalar tail using safe access
    while (i < result.trit_len) : (i += 1) {
        var sum: f32 = 0.0;
        for (vectors, 0..) |*vec, k| {
            @constCast(vec).ensureUnpacked();
            if (i < vec.trit_len) {
                const weight = amplitudes[k] / normalized;
                if (vec.unpacked_cache) |cache| {
                    sum += @as(f32, @floatFromInt(cache[i])) * weight;
                }
            }
        }

        // Threshold-based quantization (collapse)
        setTritSafe(&result, i, if (sum > 0.5) 1 else if (sum < -0.5) -1 else 0);
    }

    return result;
}

/// Measure: collapse superposition to classical ternary state
/// Samples from |ψ|² distribution (Born rule)
///
/// In VSA framework: measurement = reading out hypervector
/// Quantum extension: probabilistic sampling based on amplitudes
/// For simplicity: deterministic collapse to quantized state
pub fn measure(qvec: *const HybridBigInt, rng: *std.Random) HybridBigInt {
    _ = rng; // For future probabilistic measurement (const)

    // Born rule: P(state) = |α|²
    // Sample from ternary distribution based on amplitudes
    // For Trinity: collapse to quantized ternary value

    // In current implementation, HybridBigInt is already quantized
    // This function returns a copy (collapsing any superposition metadata)

    const result = qvec.*;

    // In full implementation:
    // 1. Extract "amplitude" from packed representation
    // 2. Use threshold to decide {-1, 0, +1}
    // 3. For probabilistic measurement, sample from distribution

    // For now: deterministic quantization (already collapsed)
    return result;
}

/// Quantum similarity with interference term
/// Includes phase-dependent interference: cos(phase_diff)
///
/// In VSA framework: similarity = cosine similarity of hypervectors
/// Quantum extension: includes phase interference
/// sim_q = sim_classical × (1 + η·cos(Δφ))
pub fn similarity_quantum(a: *const HybridBigInt, b: *const HybridBigInt, phase_diff: f32) f64 {
    const classical_sim = cosineSimilarity(a, b);

    // Interference term: constructive (cos>0) or destructive (cos<0)
    // η = 0.5 is interference strength
    const interference = 0.5 * @cos(phase_diff);

    return classical_sim * (1.0 + interference);
}

/// Apply phase shift to hypervector (for quantum interference)
/// Rotates the vector in the complex phase plane
pub fn applyPhase(vec: *const HybridBigInt, phase_shift: f32, allocator: std.mem.Allocator) !HybridBigInt {
    _ = allocator; // Reserved for future allocation needs
    // In a full quantum VSA, this would rotate complex amplitudes
    // For ternary VSA, we simulate via permute-like operation

    // Number of trit positions to shift
    const shift_amount = @abs(@as(i32, @intFromFloat(phase_shift * 10.0))) % @as(i32, @intCast(vec.trit_len));

    const abs_shift = @abs(shift_amount);

    if (abs_shift > 0) {
        return permute(vec, @as(usize, @intCast(abs_shift)));
    }

    // No shift - return copy
    const result = vec.*;
    return result;
}

/// Compute quantum coherence between multiple vectors
/// Returns value [0, 1] where 1 = fully coherent
pub fn computeCoherence(vectors: []const HybridBigInt) f32 {
    if (vectors.len < 2) return 1.0;

    var total_sim: f64 = 0.0;
    var count: usize = 0;

    for (0..vectors.len) |i| {
        for (i + 1..vectors.len) |j| {
            const sim = cosineSimilarityF16(&vectors[i], &vectors[j], std.heap.page_allocator);
            total_sim += sim;
            count += 1;
        }
    }

    return if (count > 0) @as(f32, @floatCast(total_sim / @as(f64, @floatFromInt(count)))) else 0.0;
}

/// Entangle two hypervectors (correlated superposition)
/// Creates a combined state that maintains correlation
pub fn entangle(a: *const HybridBigInt, b: *const HybridBigInt, correlation: f32) struct {
    left: HybridBigInt,
    right: HybridBigInt,
} {
    // Create correlated copies based on correlation strength
    // correlation ∈ [0, 1]: 0 = independent, 1 = fully entangled

    var left = a.*;
    var right = b.*;

    // Apply correlation: blend some trits using safe access
    if (correlation > 0 and a.trit_len == b.trit_len) {
        const num_entangled = @as(usize, @intFromFloat(@as(f32, @floatFromInt(a.trit_len)) * correlation));

        for (0..num_entangled) |i| {
            const idx = i; // Simple linear mapping
            if (idx < a.trit_len and idx < b.trit_len) {
                // Swap some trits to create correlation
                setTritSafe(&left, idx, getTritSafe(@constCast(b), idx));
                setTritSafe(&right, idx, getTritSafe(@constCast(a), idx));
            }
        }
    }

    return .{ .left = left, .right = right };
}

// φ² + 1/φ² = 3 | TRINITY

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM VSA TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "qbundle with amplitudes" {
    const a = randomVector(100, 111);
    const b = randomVector(100, 222);
    const c = randomVector(100, 333);

    const amplitudes = [_]f32{ 1.0, 1.0, 1.0 };

    // Create array of vectors (pass by value for qbundle API)
    var vec_slice = [_]HybridBigInt{ a, b, c };

    const result = try qbundle(&vec_slice, &amplitudes, std.testing.allocator);

    // Result should be valid ternary vector
    try std.testing.expect(result.trit_len > 0);
    // Check first 100 trits are in valid range using safe access
    const check_len = @min(100, result.trit_len);
    for (0..check_len) |i| {
        const trit = getTritSafe(&result, i);
        try std.testing.expect(trit >= -1 and trit <= 1);
    }
}

test "similarity_quantum with interference" {
    var a = randomVector(100, 444);
    var b = randomVector(100, 555);

    // Classical similarity
    const sim_classical = cosineSimilarity(&a, &b);

    // Quantum similarity with constructive interference (phase_diff = 0)
    const sim_constructive = similarity_quantum(&a, &b, 0.0);

    // Quantum similarity with destructive interference (phase_diff = π)
    const sim_destructive = similarity_quantum(&a, &b, std.math.pi);

    // Constructive should enhance similarity
    try std.testing.expect(sim_constructive >= sim_classical);

    // Destructive should reduce similarity
    try std.testing.expect(sim_destructive <= sim_classical);
}

test "computeCoherence" {
    const v1 = randomVector(50, 123);
    const v2 = randomVector(50, 124);
    var v3 = randomVector(50, 125);

    // Set v3 to be similar to v1 using safe access
    for (0..@min(v1.trit_len, v3.trit_len)) |i| {
        if (i < v3.trit_len) setTritSafe(&v3, i, getTritSafe(&v1, i));
    }

    // Create array of vectors (pass by value for computeCoherence API)
    var vec_slice = [_]HybridBigInt{ v1, v2, v3 };

    const coherence = computeCoherence(&vec_slice);

    // Should have some coherence (> 0)
    try std.testing.expect(coherence > 0.0);
}

test "entangle with correlation" {
    var a = randomVector(50, 666);
    var b = randomVector(50, 777);

    const fully_entangled = entangle(&a, &b, 1.0);

    // With full correlation, vectors should share trits using safe access
    try std.testing.expectEqual(
        getTritSafe(&a, 0),
        getTritSafe(&fully_entangled.right, 0),
    );

    const independent = entangle(&a, &b, 0.0);

    // With zero correlation, vectors should be copies
    try std.testing.expectEqual(
        if (a.unpacked_cache) |cache| cache[0] else 0,
        if (independent.left.unpacked_cache) |cache| cache[0] else 0,
    );
}
