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

/// SIMD-optimized matrix-vector multiplication with 4-way unrolling
/// output[i] = sum(mat[i,j] * vec[j]) for all j
/// mat is [rows, cols] in row-major order
pub fn simdMatVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    const aligned_cols = cols & ~@as(usize, SIMD_WIDTH * 4 - 1);
    const aligned_cols_single = cols & ~@as(usize, SIMD_WIDTH - 1);

    for (0..rows) |i| {
        var sum_vec0: Vec8f = @splat(0.0);
        var sum_vec1: Vec8f = @splat(0.0);
        var sum_vec2: Vec8f = @splat(0.0);
        var sum_vec3: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_offset = i * cols;

        // 4-way unrolled SIMD loop - process 32 elements at a time
        var j: usize = 0;
        while (j < aligned_cols) : (j += SIMD_WIDTH * 4) {
            const mat_vec0: Vec8f = mat[row_offset + j ..][0..SIMD_WIDTH].*;
            const mat_vec1: Vec8f = mat[row_offset + j + SIMD_WIDTH ..][0..SIMD_WIDTH].*;
            const mat_vec2: Vec8f = mat[row_offset + j + SIMD_WIDTH * 2 ..][0..SIMD_WIDTH].*;
            const mat_vec3: Vec8f = mat[row_offset + j + SIMD_WIDTH * 3 ..][0..SIMD_WIDTH].*;
            const vec_vec0: Vec8f = vec[j..][0..SIMD_WIDTH].*;
            const vec_vec1: Vec8f = vec[j + SIMD_WIDTH ..][0..SIMD_WIDTH].*;
            const vec_vec2: Vec8f = vec[j + SIMD_WIDTH * 2 ..][0..SIMD_WIDTH].*;
            const vec_vec3: Vec8f = vec[j + SIMD_WIDTH * 3 ..][0..SIMD_WIDTH].*;
            sum_vec0 += mat_vec0 * vec_vec0;
            sum_vec1 += mat_vec1 * vec_vec1;
            sum_vec2 += mat_vec2 * vec_vec2;
            sum_vec3 += mat_vec3 * vec_vec3;
        }

        // Combine partial sums
        sum_vec0 += sum_vec1;
        sum_vec2 += sum_vec3;
        sum_vec0 += sum_vec2;

        // Single SIMD loop for remainder
        while (j < aligned_cols_single) : (j += SIMD_WIDTH) {
            const mat_vec: Vec8f = mat[row_offset + j ..][0..SIMD_WIDTH].*;
            const vec_vec: Vec8f = vec[j..][0..SIMD_WIDTH].*;
            sum_vec0 += mat_vec * vec_vec;
        }

        // Horizontal sum of SIMD vector
        const sum_arr: [SIMD_WIDTH]f32 = sum_vec0;
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
// PARALLEL MATRIX-VECTOR MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread-local context for parallel matVec
const ParallelMatVecContext = struct {
    output: []f32,
    mat: []const f32,
    vec: []const f32,
    cols: usize,
    start_row: usize,
    end_row: usize,
};

/// Worker function for parallel matVec
fn parallelMatVecWorker(ctx: *ParallelMatVecContext, wg: *std.Thread.WaitGroup) void {
    defer wg.finish();
    
    const aligned_cols = ctx.cols & ~@as(usize, SIMD_WIDTH * 4 - 1);
    const aligned_cols_single = ctx.cols & ~@as(usize, SIMD_WIDTH - 1);

    for (ctx.start_row..ctx.end_row) |i| {
        var sum_vec0: Vec8f = @splat(0.0);
        var sum_vec1: Vec8f = @splat(0.0);
        var sum_vec2: Vec8f = @splat(0.0);
        var sum_vec3: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_offset = i * ctx.cols;

        var j: usize = 0;
        while (j < aligned_cols) : (j += SIMD_WIDTH * 4) {
            const mat_vec0: Vec8f = ctx.mat[row_offset + j ..][0..SIMD_WIDTH].*;
            const mat_vec1: Vec8f = ctx.mat[row_offset + j + SIMD_WIDTH ..][0..SIMD_WIDTH].*;
            const mat_vec2: Vec8f = ctx.mat[row_offset + j + SIMD_WIDTH * 2 ..][0..SIMD_WIDTH].*;
            const mat_vec3: Vec8f = ctx.mat[row_offset + j + SIMD_WIDTH * 3 ..][0..SIMD_WIDTH].*;
            const vec_vec0: Vec8f = ctx.vec[j..][0..SIMD_WIDTH].*;
            const vec_vec1: Vec8f = ctx.vec[j + SIMD_WIDTH ..][0..SIMD_WIDTH].*;
            const vec_vec2: Vec8f = ctx.vec[j + SIMD_WIDTH * 2 ..][0..SIMD_WIDTH].*;
            const vec_vec3: Vec8f = ctx.vec[j + SIMD_WIDTH * 3 ..][0..SIMD_WIDTH].*;
            sum_vec0 += mat_vec0 * vec_vec0;
            sum_vec1 += mat_vec1 * vec_vec1;
            sum_vec2 += mat_vec2 * vec_vec2;
            sum_vec3 += mat_vec3 * vec_vec3;
        }

        sum_vec0 += sum_vec1;
        sum_vec2 += sum_vec3;
        sum_vec0 += sum_vec2;

        while (j < aligned_cols_single) : (j += SIMD_WIDTH) {
            const mat_vec: Vec8f = ctx.mat[row_offset + j ..][0..SIMD_WIDTH].*;
            const vec_vec: Vec8f = ctx.vec[j..][0..SIMD_WIDTH].*;
            sum_vec0 += mat_vec * vec_vec;
        }

        const sum_arr: [SIMD_WIDTH]f32 = sum_vec0;
        inline for (sum_arr) |v| {
            sum_scalar += v;
        }

        while (j < ctx.cols) : (j += 1) {
            sum_scalar += ctx.mat[row_offset + j] * ctx.vec[j];
        }

        ctx.output[i] = sum_scalar;
    }
}

/// Global thread pool for parallel operations
var global_pool: std.Thread.Pool = undefined;
var pool_initialized: bool = false;

/// Initialize global thread pool
pub fn initThreadPool(allocator: std.mem.Allocator) !void {
    if (!pool_initialized) {
        try global_pool.init(.{ .allocator = allocator });
        pool_initialized = true;
    }
}

/// Deinitialize global thread pool
pub fn deinitThreadPool() void {
    if (pool_initialized) {
        global_pool.deinit();
        pool_initialized = false;
    }
}

/// Parallel SIMD matrix-vector multiplication
/// Uses thread pool for very large matrices only (rows > 10000)
/// On 2-core systems, threading overhead often exceeds benefit
pub fn parallelMatVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    // For most matrices, single-threaded SIMD is faster on 2 cores
    // Only use threading for vocab projection (32000 rows)
    if (rows < 10000 or !pool_initialized) {
        simdMatVec(output, mat, vec, rows, cols);
        return;
    }

    const num_threads: usize = 2; // Match CPU cores
    const rows_per_thread = rows / num_threads;
    
    var contexts: [2]ParallelMatVecContext = undefined;
    var wg = std.Thread.WaitGroup{};

    for (0..num_threads) |t| {
        const start = t * rows_per_thread;
        const end = if (t == num_threads - 1) rows else (t + 1) * rows_per_thread;
        
        contexts[t] = ParallelMatVecContext{
            .output = output,
            .mat = mat,
            .vec = vec,
            .cols = cols,
            .start_row = start,
            .end_row = end,
        };
        
        wg.start();
        global_pool.spawn(parallelMatVecWorker, .{&contexts[t], &wg}) catch {
            // Fallback to single-threaded
            wg.finish();
            simdMatVec(output[start..end], mat[start * cols ..], vec, end - start, cols);
        };
    }

    wg.wait();
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

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD ATTENTION WEIGHTED SUM (OPT-001 Enhancement)
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized attention weighted sum
/// output[i] = sum(scores[t] * v_cache[t][i]) for all t
/// This is the inner loop of attention computation
pub fn simdAttentionWeightedSum(output: []f32, scores: []const f32, v_cache: []const f32, seq_len: usize, head_dim: usize, kv_stride: usize) void {
    const aligned_dim = head_dim & ~@as(usize, SIMD_WIDTH - 1);

    // Zero output
    @memset(output, 0.0);

    // Process each timestep
    for (0..seq_len) |t| {
        const score = scores[t];
        const score_vec: Vec8f = @splat(score);
        const v_offset = t * kv_stride;

        // SIMD loop
        var i: usize = 0;
        while (i < aligned_dim) : (i += SIMD_WIDTH) {
            const v_vec: Vec8f = v_cache[v_offset + i ..][0..SIMD_WIDTH].*;
            const out_vec: Vec8f = output[i..][0..SIMD_WIDTH].*;
            output[i..][0..SIMD_WIDTH].* = out_vec + score_vec * v_vec;
        }

        // Scalar tail
        while (i < head_dim) : (i += 1) {
            output[i] += score * v_cache[v_offset + i];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD SwiGLU ACTIVATION (OPT-002 Enhancement)
// ═══════════════════════════════════════════════════════════════════════════════

/// Fast SiLU approximation using polynomial
/// silu(x) ≈ x * sigmoid(x) ≈ x * (0.5 + 0.5 * tanh(x * 0.7978845608))
/// For better accuracy, we use: x / (1 + exp(-x))
fn siluApprox(x: f32) f32 {
    // Fast sigmoid approximation
    const neg_x = -x;
    const exp_neg = @exp(neg_x);
    return x / (1.0 + exp_neg);
}

/// SIMD-optimized SwiGLU activation
/// output[i] = silu(gate[i]) * up[i]
pub fn simdSwiGLU(output: []f32, gate: []const f32, up: []const f32) void {
    const len = @min(gate.len, up.len);
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    // SIMD loop - process 8 elements at a time
    // Note: @exp is not vectorized in Zig, so we process element-wise but with better cache usage
    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        // Load gate and up values
        const gate_vec: Vec8f = gate[i..][0..SIMD_WIDTH].*;
        const up_vec: Vec8f = up[i..][0..SIMD_WIDTH].*;

        // Apply SiLU to gate (element-wise due to exp)
        var silu_arr: [SIMD_WIDTH]f32 = undefined;
        const gate_arr: [SIMD_WIDTH]f32 = gate_vec;
        inline for (0..SIMD_WIDTH) |j| {
            silu_arr[j] = siluApprox(gate_arr[j]);
        }
        const silu_vec: Vec8f = silu_arr;

        // Multiply with up
        output[i..][0..SIMD_WIDTH].* = silu_vec * up_vec;
    }

    // Scalar tail
    while (i < len) : (i += 1) {
        output[i] = siluApprox(gate[i]) * up[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD RESIDUAL ADD (Common operation)
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized residual addition: output[i] = a[i] + b[i]
/// In-place version: a[i] += b[i]
pub fn simdResidualAdd(output: []f32, residual: []const f32) void {
    const len = @min(output.len, residual.len);
    const aligned_len = len & ~@as(usize, SIMD_WIDTH - 1);

    var i: usize = 0;
    while (i < aligned_len) : (i += SIMD_WIDTH) {
        const out_vec: Vec8f = output[i..][0..SIMD_WIDTH].*;
        const res_vec: Vec8f = residual[i..][0..SIMD_WIDTH].*;
        output[i..][0..SIMD_WIDTH].* = out_vec + res_vec;
    }

    while (i < len) : (i += 1) {
        output[i] += residual[i];
    }
}

test "simd_swiglu" {
    const gate = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const up = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    var output: [8]f32 = undefined;

    simdSwiGLU(&output, &gate, &up);

    // silu(1) * 1 ≈ 0.731
    try std.testing.expect(output[0] > 0.7 and output[0] < 0.8);
}

test "simd_attention_weighted_sum" {
    const scores = [_]f32{ 0.5, 0.5 };
    const v_cache = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 }; // 2 timesteps, 4 dim
    var output: [4]f32 = undefined;

    simdAttentionWeightedSum(&output, &scores, &v_cache, 2, 4, 4);

    // output[0] = 0.5 * 1.0 + 0.5 * 5.0 = 3.0
    try std.testing.expectApproxEqAbs(output[0], 3.0, 0.001);
}
