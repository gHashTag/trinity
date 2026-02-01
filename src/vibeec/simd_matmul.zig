// SIMD MATMUL - Optimized matrix-vector multiplication
// AVX2/NEON vectorized operations for LLM inference
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// SIMD vector types
pub const Vec8f = @Vector(8, f32);
pub const Vec4f = @Vector(4, f32);
pub const SIMD_WIDTH: usize = 8;

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD MATRIX-VECTOR MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized matrix-vector multiplication
/// output[i] = sum(mat[i,j] * vec[j]) for all j
/// mat is [rows, cols] in row-major order
pub fn simdMatVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    const aligned_cols = cols & ~@as(usize, SIMD_WIDTH - 1);

    for (0..rows) |i| {
        var sum_vec: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_offset = i * cols;

        // SIMD loop - process 8 elements at a time
        var j: usize = 0;
        while (j < aligned_cols) : (j += SIMD_WIDTH) {
            const mat_vec: Vec8f = mat[row_offset + j ..][0..SIMD_WIDTH].*;
            const vec_vec: Vec8f = vec[j..][0..SIMD_WIDTH].*;
            sum_vec += mat_vec * vec_vec;
        }

        // Horizontal sum of SIMD vector
        const sum_arr: [SIMD_WIDTH]f32 = sum_vec;
        inline for (sum_arr) |v| {
            sum_scalar += v;
        }

        // Scalar tail
        while (j < cols) : (j += 1) {
            sum_scalar += mat[row_offset + j] * vec[j];
        }

        output[i] = sum_scalar;
    }
}

/// SIMD-optimized matrix-vector multiplication with transposed matrix
/// output[i] = sum(mat[j,i] * vec[j]) for all j
/// mat is [cols, rows] but we want mat^T @ vec
pub fn simdMatVecT(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    @memset(output, 0.0);

    const aligned_cols = cols & ~@as(usize, SIMD_WIDTH - 1);

    // Process in blocks for better cache utilization
    var j: usize = 0;
    while (j < aligned_cols) : (j += SIMD_WIDTH) {
        const vec_vec: Vec8f = vec[j..][0..SIMD_WIDTH].*;

        for (0..rows) |i| {
            const mat_vec: Vec8f = mat[j * rows + i ..][0..SIMD_WIDTH].*;
            const prod: Vec8f = mat_vec * vec_vec;

            // Horizontal sum
            const prod_arr: [SIMD_WIDTH]f32 = prod;
            var sum: f32 = 0.0;
            inline for (prod_arr) |v| {
                sum += v;
            }
            output[i] += sum;
        }
    }

    // Scalar tail
    while (j < cols) : (j += 1) {
        const v = vec[j];
        for (0..rows) |i| {
            output[i] += mat[j * rows + i] * v;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD DOT PRODUCT
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized dot product
pub fn simdDot(a: []const f32, b: []const f32) f32 {
    const len = @min(a.len, b.len);
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    var sum_vec: Vec8f = @splat(0.0);
    var sum_scalar: f32 = 0.0;

    // SIMD loop
    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const a_vec: Vec8f = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec8f = b[i..][0..SIMD_WIDTH].*;
        sum_vec += a_vec * b_vec;
    }

    // Horizontal sum
    const sum_arr: [SIMD_WIDTH]f32 = sum_vec;
    inline for (sum_arr) |v| {
        sum_scalar += v;
    }

    // Scalar tail
    while (i < len) : (i += 1) {
        sum_scalar += a[i] * b[i];
    }

    return sum_scalar;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ELEMENT-WISE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD element-wise addition: output = a + b
pub fn simdAdd(output: []f32, a: []const f32, b: []const f32) void {
    const len = @min(a.len, b.len);
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const a_vec: Vec8f = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec8f = b[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = a_vec + b_vec;
    }

    while (i < len) : (i += 1) {
        output[i] = a[i] + b[i];
    }
}

/// SIMD element-wise multiplication: output = a * b
pub fn simdMul(output: []f32, a: []const f32, b: []const f32) void {
    const len = @min(a.len, b.len);
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const a_vec: Vec8f = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec8f = b[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = a_vec * b_vec;
    }

    while (i < len) : (i += 1) {
        output[i] = a[i] * b[i];
    }
}

/// SIMD scale: output = a * scalar
pub fn simdScale(output: []f32, a: []const f32, scalar: f32) void {
    const aligned_len = a.len & ~@as(usize, SIMD_WIDTH - 1);
    const scalar_vec: Vec8f = @splat(scalar);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const a_vec: Vec8f = a[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = a_vec * scalar_vec;
    }

    while (i < a.len) : (i += 1) {
        output[i] = a[i] * scalar;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD RMS NORM
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized RMS normalization
pub fn simdRmsNorm(output: []f32, input: []const f32, weight: []const f32, eps: f32) void {
    const n = input.len;
    const aligned_n = n & ~@as(usize, SIMD_WIDTH - 1);

    // Calculate sum of squares using SIMD
    var sum_sq_vec: Vec8f = @splat(0.0);
    var sum_sq: f32 = 0.0;

    var i: usize = 0;
    while (i < aligned_n) : (i += SIMD_WIDTH) {
        const x_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;
        sum_sq_vec += x_vec * x_vec;
    }

    // Horizontal sum
    const sum_arr: [SIMD_WIDTH]f32 = sum_sq_vec;
    inline for (sum_arr) |v| {
        sum_sq += v;
    }

    // Scalar tail
    while (i < n) : (i += 1) {
        sum_sq += input[i] * input[i];
    }

    // Calculate scale
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(n)) + eps);
    const scale = 1.0 / rms;
    const scale_vec: Vec8f = @splat(scale);

    // Apply normalization with SIMD
    i = 0;
    while (i < aligned_n) : (i += SIMD_WIDTH) {
        const x_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;
        const w_vec: Vec8f = weight[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = x_vec * scale_vec * w_vec;
    }

    // Scalar tail
    while (i < n) : (i += 1) {
        output[i] = input[i] * scale * weight[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD SOFTMAX
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized softmax (partial - exp and sum)
pub fn simdSoftmax(output: []f32, input: []const f32) void {
    _ = input.len; // Used implicitly via slice iteration

    // Find max (for numerical stability)
    var max_val: f32 = input[0];
    for (input[1..]) |x| {
        if (x > max_val) max_val = x;
    }

    // Compute exp(x - max) and sum
    var sum: f32 = 0.0;
    for (input, 0..) |x, i| {
        output[i] = @exp(x - max_val);
        sum += output[i];
    }

    // Normalize
    const inv_sum = 1.0 / sum;
    simdScale(output, output, inv_sum);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "simd_dot" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 };
    const b = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    const result = simdDot(&a, &b);
    try std.testing.expectApproxEqAbs(result, 55.0, 0.001);
}

test "simd_matvec" {
    // 2x3 matrix
    const mat = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const vec = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    simdMatVec(&output, &mat, &vec, 2, 3);

    // [1,2,3] @ [1,2,3] = 1+4+9 = 14
    // [4,5,6] @ [1,2,3] = 4+10+18 = 32
    try std.testing.expectApproxEqAbs(output[0], 14.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 32.0, 0.001);
}

test "simd_rms_norm" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;

    simdRmsNorm(&output, &input, &weight, 1e-5);

    // RMS norm should produce non-zero output
    try std.testing.expect(output[0] > 0);
}
