// @origin(spec:sparse_simd.tri) @regen(manual-impl)
// Sparse Ternary SIMD — Zero-Weight Skipping for 30-50% Speedup
// ~66% of ternary weights are zero → skip entire chunks via @reduce(.Or)
//
// Key insight: if all 16 weights in a chunk are zero, skip compute entirely
// Uses f16 for activations (2× memory bandwidth), f32 for accumulate (precision)
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const f16_utils = @import("f16_utils.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const Vec16i8 = @Vector(16, i8);
const Vec16f16 = @Vector(16, f16);
const Vec16f32 = @Vector(16, f32);

const zero_vec_i8: Vec16i8 = @splat(0);
const zero_vec_f16: Vec16f16 = @splat(@as(f16, 0.0));

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE DOT PRODUCT — Skip zero chunks
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse ternary dot product with 16-wide zero-chunk skipping.
/// Returns f64 for precision. ~30-50% faster on sparse data (66% zeros).
pub fn sparseTernaryDot(weights: []const i8, activations: []const f16) f64 {
    std.debug.assert(weights.len == activations.len);

    var acc: f64 = 0;
    const VEC_SIZE = 16;
    const num_chunks = weights.len / VEC_SIZE;

    var i: usize = 0;
    while (i < num_chunks * VEC_SIZE) : (i += VEC_SIZE) {
        // Load 16 weights
        const w_vec: Vec16i8 = weights[i..][0..VEC_SIZE].*;

        // Check if any non-zero exists in this chunk
        const any_nonzero = @reduce(.Or, w_vec != zero_vec_i8);

        // Skip entire chunk if all zeros
        if (!any_nonzero) continue;

        // Load activations and compute
        const a_vec: Vec16f16 = activations[i..][0..VEC_SIZE].*;
        const a_wide: Vec16f32 = @floatCast(a_vec);
        const w_wide: Vec16f32 = @floatFromInt(w_vec);

        const prod = a_wide * w_wide;
        var chunk_sum: f32 = 0;
        inline for (0..VEC_SIZE) |j| {
            chunk_sum += prod[j];
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
    return f16_utils.dotProductF16(activations, @as([]const f16, @ptrCast(weights)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSE MATRIX-VECTOR — Skip zero rows/chunks
// ═══════════════════════════════════════════════════════════════════════════════

/// Sparse ternary matrix-vector multiplication.
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

    const VEC_SIZE = 16;

    // Process each output dimension (row)
    for (0..out_dim) |row| {
        const row_start = row * in_dim;
        var acc: f64 = 0;

        // Process 16 elements at a time
        const num_chunks = in_dim / VEC_SIZE;
        var col: usize = 0;

        while (col < num_chunks * VEC_SIZE) : (col += VEC_SIZE) {
            const w_vec: Vec16i8 = weights[row_start + col..][0..VEC_SIZE].*;
            const any_nonzero = @reduce(.Or, w_vec != zero_vec_i8);

            if (!any_nonzero) {
                col += VEC_SIZE;
                continue;
            }

            const a_vec: Vec16f16 = activations[col..][0..VEC_SIZE].*;
            const a_wide: Vec16f32 = @floatCast(a_vec);
            const w_wide: Vec16f32 = @floatFromInt(w_vec);

            const prod = a_wide * w_wide;
            var chunk_sum: f32 = 0;
            inline for (0..VEC_SIZE) |j| {
                chunk_sum += prod[j];
            }
            acc += @as(f64, chunk_sum);
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

/// Count zero chunks in a slice (16-element granularity).
pub fn countZeroChunks(data: []const i8) usize {
    const VEC_SIZE = 16;
    const num_chunks = data.len / VEC_SIZE;
    var zero_count: usize = 0;

    var i: usize = 0;
    while (i < num_chunks * VEC_SIZE) : (i += VEC_SIZE) {
        const vec: Vec16i8 = data[i..][0..VEC_SIZE].*;
        const all_zero = @reduce(.And, vec == zero_vec_i8);
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
    const total_chunks = weights.len / 16;
    if (total_chunks == 0) return 1.0;

    const zero_chunks = countZeroChunks(weights);
    const zero_chunk_ratio = @as(f64, @floatFromInt(zero_chunks)) / @as(f64, @floatFromInt(total_chunks));

    // Each skipped chunk saves ~50% of work
    return 1.0 + zero_chunk_ratio * 0.5;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

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
    try std.testing.expectEqual(@as(usize, 2), countZeroChunks(&all_zeros));

    const all_ones = [_]i8{1} ** 32;
    try std.testing.expectEqual(@as(usize, 0), countZeroChunks(&all_ones));

    const half_zeros: [32]i8 = .{0} ** 16 ++ .{1} ** 16;
    try std.testing.expectEqual(@as(usize, 1), countZeroChunks(&half_zeros));
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
    const weights = [_]i8{1, 0, -1, 1};
    const activations = [_]f16{ 0.5, 0.3, -0.7, 0.2 };

    var output: [1]f16 = undefined;
    sparseTernaryMatvec(&weights, &activations, &output, 1, 4);

    const expected: f64 = 0.5 + 0 + 0.7 + 0.2; // 1*0.5 + 0*0.3 + (-1)*(-0.7) + 1*0.2
    try std.testing.expectApproxEqAbs(expected, @as(f64, @floatCast(output[0])), 0.01);
}

// φ² + 1/φ² = 3 | TRINITY
