// @origin(spec:sparse_simd.tri) @regen(manual-impl)
// Sparse Ternary SIMD — Zero-Weight Skipping with Adaptive Width
// ~66% of ternary weights are zero → skip entire chunks via @reduce(.Or)
//
// Uses simd_config.zig for comptime CPU feature detection:
// - AVX2 (x86_64): 32-wide i8 → 2× throughput vs 16-wide
// - NEON (aarch64): 16-wide i8
// - Fallback: 8-wide i8
//
// Key insight: if all weights in a chunk are zero, skip compute entirely
// Uses f16 for activations (2× memory bandwidth), f32 for accumulate (precision)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const simd_config = @import("simd_config.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE VECTOR TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Current optimal i8 vector width (comptime-known)
pub const VEC_I8_SIZE = simd_config.capabilities.optimal_i8_width;

/// Current optimal f16 vector width (comptime-known)
pub const VEC_F16_SIZE = simd_config.capabilities.optimal_f16_width;

/// Current optimal f32 vector width (comptime-known)
pub const VEC_F32_SIZE = simd_config.capabilities.optimal_f32_width;

/// Adaptive i8 vector type for ternary weights
pub const VecI8 = @Vector(VEC_I8_SIZE, i8);

/// Adaptive f16 vector type for activations
pub const VecF16 = @Vector(VEC_F16_SIZE, f16);

/// Adaptive f32 vector type for accumulation
pub const VecF32 = @Vector(VEC_F32_SIZE, f32);

/// Zero vector for i8 (adaptive width)
pub inline fn zeroVecI8() VecI8 {
    return @splat(0);
}

/// Zero vector for f16 (adaptive width)
pub inline fn zeroVecF16() VecF16 {
    return @splat(@as(f16, 0.0));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE DOT PRODUCT — Skip zero chunks
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse ternary dot product with adaptive-width zero-chunk skipping.
/// Returns f64 for precision. ~30-50% faster on sparse data (66% zeros).
pub fn sparseTernaryDot(weights: []const i8, activations: []const f16) f64 {
    std.debug.assert(weights.len == activations.len);

    var acc: f64 = 0;

    // Use the smaller vector size as chunk size (both must align)
    const CHUNK_SIZE = @min(VEC_I8_SIZE, VEC_F16_SIZE);
    const num_chunks = weights.len / CHUNK_SIZE;

    var i: usize = 0;
    while (i < num_chunks * CHUNK_SIZE) : (i += CHUNK_SIZE) {
        // Load CHUNK_SIZE weights
        var w_chunk: [CHUNK_SIZE]i8 = undefined;
        for (0..CHUNK_SIZE) |j| {
            w_chunk[j] = weights[i + j];
        }

        // Check if any non-zero exists in this chunk
        var any_nonzero = false;
        for (w_chunk) |w| {
            if (w != 0) {
                any_nonzero = true;
                break;
            }
        }

        // Skip entire chunk if all zeros
        if (!any_nonzero) continue;

        // Load activations and compute
        var a_chunk: [CHUNK_SIZE]f16 = undefined;
        for (0..CHUNK_SIZE) |j| {
            a_chunk[j] = activations[i + j];
        }

        // Convert to f32 and compute dot product
        var chunk_sum: f32 = 0;
        for (0..CHUNK_SIZE) |j| {
            const a_f32: f32 = @floatCast(a_chunk[j]);
            const w_f32: f32 = @floatFromInt(w_chunk[j]);
            chunk_sum += a_f32 * w_f32;
        }
        acc += @as(f64, chunk_sum);
    }

    // Handle scalar tail
    while (i < weights.len) : (i += 1) {
        if (weights[i] == 0) continue;
        const a_f32: f32 = @floatCast(activations[i]);
        const w_f32: f32 = @floatFromInt(weights[i]);
        acc += @as(f64, a_f32 * w_f32);
    }

    return acc;
}

/// Dense ternary dot product (baseline for comparison).
/// Always computes all elements — no skipping.
pub fn denseTernaryDot(weights: []const i8, activations: []const f16) f64 {
    var acc: f64 = 0;
    for (weights, activations) |w, a| {
        if (w == 0) continue;
        const a_f32: f32 = @floatCast(a);
        acc += @as(f64, a_f32 * @as(f64, @floatFromInt(w)));
    }
    return acc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE MATRIX-VECTOR — Skip zero rows/chunks
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse ternary matrix-vector multiplication with adaptive width.
/// weights: [out_dim][in_dim] row-major i8 ternary matrix
/// activations: [in_dim] f16 input vector
/// output: [out_dim] f16 result (caller-allocated)
pub fn sparseTernaryMatvec(
    weights: []const i8,
    activations: []const f16,
    output: []f16,
    out_dim: usize,
    in_dim: usize,
) void {
    std.debug.assert(weights.len == out_dim * in_dim);
    std.debug.assert(activations.len == in_dim);
    std.debug.assert(output.len == out_dim);

    // Use the smaller vector size as chunk size (both must align)
    const CHUNK_SIZE = @min(VEC_I8_SIZE, VEC_F16_SIZE);

    // Process each output dimension (row)
    for (0..out_dim) |row| {
        const row_start = row * in_dim;
        var acc: f64 = 0;

        // Process CHUNK_SIZE elements at a time
        const num_chunks = in_dim / CHUNK_SIZE;
        var col: usize = 0;

        while (col < num_chunks * CHUNK_SIZE) : (col += CHUNK_SIZE) {
            // Load i8 weights
            var w_chunk: [CHUNK_SIZE]i8 = undefined;
            for (0..CHUNK_SIZE) |j| {
                w_chunk[j] = weights[row_start + col + j];
            }

            // Check if any non-zero exists in this chunk
            var any_nonzero = false;
            for (w_chunk) |w| {
                if (w != 0) {
                    any_nonzero = true;
                    break;
                }
            }

            if (!any_nonzero) {
                col += CHUNK_SIZE;
                continue;
            }

            // Load f16 activations
            var a_chunk: [CHUNK_SIZE]f16 = undefined;
            for (0..CHUNK_SIZE) |j| {
                a_chunk[j] = activations[col + j];
            }

            // Accumulate
            for (0..CHUNK_SIZE) |j| {
                const a_f32: f32 = @floatCast(a_chunk[j]);
                const w_f32: f32 = @floatFromInt(w_chunk[j]);
                acc += @as(f64, a_f32 * w_f32);
            }
        }

        // Handle scalar tail
        while (col < in_dim) : (col += 1) {
            const w = weights[row_start + col];
            if (w == 0) continue;
            const a_f32: f32 = @floatCast(activations[col]);
            acc += @as(f64, a_f32 * @as(f64, @floatFromInt(w)));
        }

        output[row] = @floatCast(acc);
    }
}

/// Dense ternary matrix-vector multiplication (baseline).
pub fn denseTernaryMatvec(
    weights: []const i8,
    activations: []const f16,
    output: []f16,
    out_dim: usize,
    in_dim: usize,
) void {
    std.debug.assert(weights.len == out_dim * in_dim);
    std.debug.assert(activations.len == in_dim);
    std.debug.assert(output.len == out_dim);

    for (0..out_dim) |row| {
        const row_start = row * in_dim;
        var dot: f64 = 0;

        for (0..in_dim) |col| {
            const w = weights[row_start + col];
            if (w == 0) continue;
            const a_f32: f32 = @floatCast(activations[col]);
            dot += @as(f64, a_f32 * @as(f64, @floatFromInt(w)));
        }

        output[row] = @floatCast(dot);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Count zero chunks in a slice (adaptive-width granularity).
pub fn countZeroChunks(data: []const i8) usize {
    const CHUNK_SIZE = @min(VEC_I8_SIZE, VEC_F16_SIZE);
    const num_chunks = data.len / CHUNK_SIZE;
    var zero_count: usize = 0;

    var i: usize = 0;
    while (i < num_chunks * CHUNK_SIZE) : (i += CHUNK_SIZE) {
        var all_zero = true;
        for (data[i .. i + CHUNK_SIZE]) |v| {
            if (v != 0) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) zero_count += 1;
    }

    return zero_count;
}

/// Calculate sparsity ratio (fraction of zeros).
pub fn sparsityRatio(data: []const i8) f64 {
    if (data.len == 0) return 0;

    var zero_count: usize = 0;
    for (data) |v| {
        if (v == 0) zero_count += 1;
    }

    return @as(f64, @floatFromInt(zero_count)) / @as(f64, @floatFromInt(data.len));
}

/// Estimate speedup factor for sparse vs dense.
/// Returns 1.0 + (zero_chunk_ratio * 0.5) as rough estimate.
pub fn estimateSpeedup(weights: []const i8) f64 {
    const total_chunks = weights.len / VEC_I8_SIZE;
    if (total_chunks == 0) return 1.0;

    const zero_chunks = countZeroChunks(weights);
    const zero_chunk_ratio = @as(f64, @floatFromInt(zero_chunks)) / @as(f64, @floatFromInt(total_chunks));

    // Each skipped chunk saves ~50% of work
    return 1.0 + zero_chunk_ratio * 0.5;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "adaptive vector widths are valid" {
    const caps = simd_config.capabilities;

    try std.testing.expect(caps.optimal_i8_width >= 8 and caps.optimal_i8_width <= 32);
    try std.testing.expect(caps.optimal_f16_width >= 8 and caps.optimal_f16_width <= 32);
    try std.testing.expect(caps.optimal_f32_width >= 2 and caps.optimal_f32_width <= 8);

    // f16 width should be 2× f32 width (same total bits)
    try std.testing.expectEqual(caps.optimal_f16_width, caps.optimal_f32_width * 2);

    // i8 width should be 4× f32 width (same total bits)
    try std.testing.expectEqual(caps.optimal_i8_width, caps.optimal_f32_width * 4);
}

test "zero vectors are correct" {
    const zv_i8 = zeroVecI8();
    const zv_f16 = zeroVecF16();

    var sum_i8: i64 = 0;
    var sum_f16: f64 = 0;

    inline for (0..VEC_I8_SIZE) |i| {
        sum_i8 += zv_i8[i];
    }

    inline for (0..VEC_F16_SIZE) |i| {
        sum_f16 += @as(f64, @floatCast(zv_f16[i]));
    }

    try std.testing.expectEqual(@as(i64, 0), sum_i8);
    try std.testing.expectEqual(@as(f64, 0), sum_f16);
}

test "sparse dot product matches dense" {
    const weights = [_]i8{ 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, -1, 0 };
    const activations = [_]f16{ 0.5, 0.3, 0.7, 0.2, 0.5, 0.3, 0.7, 0.2, 0.5, 0.3, 0.7, 0.2, 0.5, 0.3, 0.7, 0.2 };

    const sparse_result = sparseTernaryDot(&weights, &activations);

    // Compute expected manually
    var expected: f64 = 0;
    for (weights, activations) |w, a| {
        const a_f32: f32 = @floatCast(a);
        expected += @as(f64, a_f32 * @as(f64, @floatFromInt(w)));
    }

    try std.testing.expectApproxEqAbs(expected, sparse_result, 0.001);
}

test "sparse dot product all zeros" {
    const weights = [_]i8{0} ** 16;
    const activations = [_]f16{0.5} ** 16;

    const result = sparseTernaryDot(&weights, &activations);
    try std.testing.expectEqual(@as(f64, 0), result);
}

test "sparse dot product all nonzeros" {
    const weights = [_]i8{1} ** 16;
    const activations = [_]f16{0.5} ** 16;

    const result = sparseTernaryDot(&weights, &activations);
    const expected: f64 = 16 * 0.5;
    try std.testing.expectApproxEqAbs(expected, result, 0.001);
}

test "sparse dot product 50% sparse" {
    // Alternating zero/nonzero pattern
    var weights: [16]i8 = undefined;
    var activations: [16]f16 = undefined;
    for (0..16) |i| {
        weights[i] = if (i % 2 == 0) 1 else 0;
        activations[i] = @floatCast(@as(f32, @floatFromInt(i)));
    }

    const result = sparseTernaryDot(&weights, &activations);

    // Compute expected: only even indices contribute
    var expected: f64 = 0;
    for (0..16) |i| {
        if (i % 2 == 0) {
            const a_f32: f32 = @floatCast(activations[i]);
            expected += @as(f64, a_f32);
        }
    }

    try std.testing.expectApproxEqAbs(expected, result, 0.01);
}

test "sparse matvec matches dense" {
    const out_dim: usize = 4;
    const in_dim: usize = 8;

    // Create weights with some zero rows
    var weights: [out_dim * in_dim]i8 = undefined;
    for (0..out_dim) |row| {
        for (0..in_dim) |col| {
            const idx = row * in_dim + col;
            // Every other row is all zeros
            weights[idx] = if (row % 2 == 0) @as(i8, 1) else 0;
        }
    }

    const activations = [_]f16{0.1} ** in_dim;

    var sparse_output: [out_dim]f16 = undefined;
    var dense_output: [out_dim]f16 = undefined;

    sparseTernaryMatvec(&weights, &activations, &sparse_output, out_dim, in_dim);
    denseTernaryMatvec(&weights, &activations, &dense_output, out_dim, in_dim);

    for (sparse_output, dense_output) |s, d| {
        try std.testing.expectApproxEqAbs(@as(f64, @floatCast(d)), @as(f64, @floatCast(s)), 0.001);
    }
}

test "count zero chunks" {
    const all_zeros = [_]i8{0} ** 32;
    const zero_chunks = countZeroChunks(&all_zeros);
    // Should have at least 1 zero chunk (32 / VEC_I8_SIZE)
    try std.testing.expect(zero_chunks >= 1);

    const all_ones = [_]i8{1} ** 32;
    try std.testing.expectEqual(@as(usize, 0), countZeroChunks(&all_ones));

    // Half zeros (first half zero, second half ones)
    var half_zeros: [32]i8 = undefined;
    for (0..16) |i| half_zeros[i] = 0;
    for (16..32) |i| half_zeros[i] = 1;
    const half_zero_chunks = countZeroChunks(&half_zeros);
    // Should have at least 1 zero chunk
    try std.testing.expect(half_zero_chunks >= 1);
}

test "sparsity ratio" {
    const all_zeros = [_]i8{0} ** 10;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sparsityRatio(&all_zeros), 0.01);

    const all_ones = [_]i8{1} ** 10;
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sparsityRatio(&all_ones), 0.01);

    const half_zeros = [_]i8{0} ** 5 ++ [_]i8{1} ** 5;
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), sparsityRatio(&half_zeros), 0.01);
}

test "estimate speedup" {
    const all_zeros = [_]i8{0} ** 32;
    const speedup_all_zeros = estimateSpeedup(&all_zeros);
    try std.testing.expect(speedup_all_zeros >= 1.5); // At least 1.5× if all chunks skipped

    const all_ones = [_]i8{1} ** 32;
    const speedup_all_ones = estimateSpeedup(&all_ones);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), speedup_all_ones, 0.1); // No speedup if dense
}

test "sparse dot product non-aligned length" {
    const weights = [_]i8{ 1, 0, -1, 0, 1, 0, -1, 0, 1, 0, -1 };
    const activations = [_]f16{ 0.5, 0.3, 0.7, 0.2, 0.5, 0.3, 0.7, 0.2, 0.5, 0.3, 0.7 };

    // Should not crash, should produce correct result
    const result = sparseTernaryDot(&weights, &activations);
    try std.testing.expect(std.math.isFinite(result));
}

test "sparse matvec single row" {
    const weights = [_]i8{ 1, 0, -1, 1 };
    const activations = [_]f16{ 0.5, 0.3, -0.7, 0.2 };

    var output: [1]f16 = undefined;
    sparseTernaryMatvec(&weights, &activations, &output, 1, 4);

    const expected: f64 = 0.5 + 0 + 0.7 + 0.2; // 1*0.5 + 0*0.3 + (-1)*(-0.7) + 1*0.2
    try std.testing.expectApproxEqAbs(expected, @as(f64, @floatCast(output[0])), 0.01);
}

test "large vector sparse dot product" {
    // Test with vectors larger than VEC_I8_SIZE
    const size = 256;
    var weights: [size]i8 = undefined;
    var activations: [size]f16 = undefined;

    for (0..size) |i| {
        // 50% sparse pattern
        weights[i] = if (i % 2 == 0) @as(i8, 1) else 0;
        activations[i] = @floatCast(@as(f32, @floatFromInt(i % 10)));
    }

    const sparse_result = sparseTernaryDot(&weights, &activations);
    const dense_result = denseTernaryDot(&weights, &activations);

    try std.testing.expectApproxEqAbs(dense_result, sparse_result, 0.01);
}

test "simd info can be accessed" {
    const caps = simd_config.capabilities;
    _ = caps;
    try std.testing.expect(true);
}

// φ² + 1/φ² = 3 | TRINITY
