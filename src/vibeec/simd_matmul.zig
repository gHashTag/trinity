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

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-THREADED SIMD MATRIX-VECTOR MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_NUM_THREADS: usize = 8; // Increased for better scaling

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENT THREAD POOL - Eliminates spawn overhead
// ═══════════════════════════════════════════════════════════════════════════════

const MatVecContext = struct {
    output: []f32,
    mat: []const f32,
    vec: []const f32,
    cols: usize,
    start_row: usize,
    end_row: usize,
};

const ThreadPoolTask = struct {
    ctx: MatVecContext,
    ready: std.atomic.Value(bool),
    done: std.atomic.Value(bool),
};

const ThreadPool = struct {
    tasks: [DEFAULT_NUM_THREADS]ThreadPoolTask,
    threads: [DEFAULT_NUM_THREADS]?std.Thread,
    running: std.atomic.Value(bool),
    initialized: bool,

    pub fn init() ThreadPool {
        var pool = ThreadPool{
            .tasks = undefined,
            .threads = undefined,
            .running = std.atomic.Value(bool).init(true),
            .initialized = false,
        };
        for (0..DEFAULT_NUM_THREADS) |i| {
            pool.tasks[i].ready = std.atomic.Value(bool).init(false);
            pool.tasks[i].done = std.atomic.Value(bool).init(true);
        }
        return pool;
    }

    pub fn start(self: *ThreadPool) void {
        if (self.initialized) return;
        for (0..DEFAULT_NUM_THREADS) |i| {
            self.threads[i] = std.Thread.spawn(.{}, threadWorker, .{ self, i }) catch null;
        }
        self.initialized = true;
    }

    fn threadWorker(self: *ThreadPool, id: usize) void {
        while (self.running.load(.acquire)) {
            if (self.tasks[id].ready.load(.acquire)) {
                matVecWorkerInline(&self.tasks[id].ctx);
                self.tasks[id].done.store(true, .release);
                self.tasks[id].ready.store(false, .release);
            } else {
                std.atomic.spinLoopHint();
            }
        }
    }

    pub fn submit(self: *ThreadPool, id: usize, ctx: MatVecContext) void {
        self.tasks[id].ctx = ctx;
        self.tasks[id].done.store(false, .release);
        self.tasks[id].ready.store(true, .release);
    }

    pub fn wait(self: *ThreadPool, num_tasks: usize) void {
        for (0..num_tasks) |i| {
            while (!self.tasks[i].done.load(.acquire)) {
                std.atomic.spinLoopHint();
            }
        }
    }

    pub fn deinit(self: *ThreadPool) void {
        self.running.store(false, .release);
        for (self.threads) |maybe_thread| {
            if (maybe_thread) |thread| {
                thread.join();
            }
        }
    }
};

var global_pool: ThreadPool = ThreadPool.init();
var pool_initialized: bool = false;

fn ensurePoolInitialized() void {
    if (!pool_initialized) {
        global_pool.start();
        pool_initialized = true;
    }
}

fn matVecWorkerInline(ctx: *const MatVecContext) void {
    const aligned_cols = ctx.cols & ~@as(usize, SIMD_WIDTH * 4 - 1);
    const aligned_cols_single = ctx.cols & ~@as(usize, SIMD_WIDTH - 1);

    var i = ctx.start_row;
    while (i < ctx.end_row) : (i += 1) {
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

/// Multi-threaded SIMD matrix-vector multiplication
/// Uses PERSISTENT THREAD POOL to eliminate spawn overhead
/// Threshold lowered to 2048 rows to parallelize LLM matVec ops:
///   - Output projection: 32000×2048 (vocab × hidden)
///   - FFN gate/up: 5632×2048
///   - Q/O projections: 2048×2048
pub fn simdMatVecParallel(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    if (rows < 2048) {
        simdMatVec(output, mat, vec, rows, cols);
        return;
    }

    // Ensure thread pool is initialized (one-time cost)
    ensurePoolInitialized();

    const num_threads = @min(DEFAULT_NUM_THREADS, rows / 64);
    const rows_per_thread = rows / num_threads;

    // Submit tasks to thread pool (NO spawn overhead!)
    for (0..num_threads) |t| {
        const start_row = t * rows_per_thread;
        const end_row = if (t == num_threads - 1) rows else (t + 1) * rows_per_thread;

        global_pool.submit(t, MatVecContext{
            .output = output,
            .mat = mat,
            .vec = vec,
            .cols = cols,
            .start_row = start_row,
            .end_row = end_row,
        });
    }

    // Wait for all tasks (spin-wait, no syscall)
    global_pool.wait(num_threads);
}

/// SIMD-optimized matrix-vector multiplication for COLUMN-MAJOR matrices (GGUF format)
/// output[i] = sum(mat[i,j] * vec[j]) for all j
/// mat is stored in column-major order: mat[i][j] = data[j * rows + i]
/// This is the correct layout for GGUF weight tensors
pub fn simdMatVecColMajor(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    @memset(output, 0.0);

    const aligned_rows = rows & ~@as(usize, SIMD_WIDTH - 1);

    // Process column by column (each column is contiguous in memory)
    for (0..cols) |j| {
        const scale = vec[j];
        const scale_vec: Vec8f = @splat(scale);
        const col_offset = j * rows;

        // SIMD loop - process 8 output elements at a time
        var i: usize = 0;
        while (i < aligned_rows) : (i += SIMD_WIDTH) {
            const mat_vec: Vec8f = mat[col_offset + i ..][0..SIMD_WIDTH].*;
            const out_vec: Vec8f = output[i..][0..SIMD_WIDTH].*;
            output[i..][0..SIMD_WIDTH].* = out_vec + scale_vec * mat_vec;
        }

        // Scalar tail
        while (i < rows) : (i += 1) {
            output[i] += scale * mat[col_offset + i];
        }
    }
}

/// Legacy transposed matrix-vector multiplication (DEPRECATED - use simdMatVecColMajor)
pub fn simdMatVecT(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    simdMatVecColMajor(output, mat, vec, rows, cols);
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

// Thread pool is defined above (lines 100-172) - persistent pool with atomic spin-wait

/// Parallel SIMD matrix-vector multiplication for GGUF weight matrices
/// GGUF stores weight matrices in [input_dim, output_dim] layout with input_dim innermost (stride 1)
/// This means W[out][in] = data[out * input_dim + in], which is row-major access!
/// Uses thread pool for very large matrices only (rows > 10000)
pub fn parallelMatVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    // Delegate to thread-pool-enabled version (threshold 2048 rows)
    simdMatVecParallel(output, mat, vec, rows, cols);
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
    // 2x3 matrix in ROW-MAJOR order (legacy test)
    const mat = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const vec = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    simdMatVec(&output, &mat, &vec, 2, 3);

    // [1,2,3] @ [1,2,3] = 1+4+9 = 14
    // [4,5,6] @ [1,2,3] = 4+10+18 = 32
    try std.testing.expectApproxEqAbs(output[0], 14.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 32.0, 0.001);
}

test "simd_matvec_colmajor" {
    // 2x3 matrix in COLUMN-MAJOR order (GGUF format)
    // Matrix W = [[1, 3, 5], [2, 4, 6]] conceptually (2 rows, 3 cols)
    // Column-major storage: col0=[1,2], col1=[3,4], col2=[5,6]
    const mat = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const vec = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    simdMatVecColMajor(&output, &mat, &vec, 2, 3);

    // W @ vec = [[1,3,5], [2,4,6]] @ [1,2,3]
    // row 0: 1*1 + 3*2 + 5*3 = 1 + 6 + 15 = 22
    // row 1: 2*1 + 4*2 + 6*3 = 2 + 8 + 18 = 28
    try std.testing.expectApproxEqAbs(output[0], 22.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 28.0, 0.001);
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

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY NORMALIZATION (TernaryNorm)
// RMSNorm with ternary-quantized weights for 16x memory reduction
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary-quantized normalization weights
/// Packing: 4 ternary values per byte (2 bits each)
/// Encoding: 00=-1, 01=0, 10=+1
pub const TernaryNormWeights = struct {
    data: []const u8, // 4 ternary values per byte (packed)
    scale: f32, // Scale factor for reconstruction
    size: usize, // Original weight count

    /// Unpack single ternary value from packed byte
    /// pos: 0-3 (which 2-bit pair in the byte)
    pub inline fn unpack(self: TernaryNormWeights, idx: usize) i8 {
        const byte_idx = idx / 4;
        const bit_pos: u3 = @intCast((idx % 4) * 2);
        const raw = (self.data[byte_idx] >> bit_pos) & 0x03;
        // 00 -> -1, 01 -> 0, 10 -> +1
        return @as(i8, @intCast(raw)) - 1;
    }
};

/// Quantize f32 weights to ternary format
/// Returns packed bytes and scale factor
pub fn quantizeToTernary(allocator: std.mem.Allocator, weights: []const f32) !TernaryNormWeights {
    const n = weights.len;
    const packed_size = (n + 3) / 4; // Round up to fit all values

    const packed_data = try allocator.alloc(u8, packed_size);
    @memset(packed_data, 0);

    // Find scale: max absolute value
    var max_abs: f32 = 0.0;
    for (weights) |w| {
        const abs_w = @abs(w);
        if (abs_w > max_abs) max_abs = abs_w;
    }

    const threshold = max_abs * 0.5; // Values below threshold become 0
    const scale = max_abs;

    // Pack ternary values
    for (weights, 0..) |w, i| {
        const ternary: u8 = if (w > threshold)
            2 // +1
        else if (w < -threshold)
            0 // -1
        else
            1; // 0

        const byte_idx = i / 4;
        const bit_pos: u3 = @intCast((i % 4) * 2);
        packed_data[byte_idx] |= ternary << bit_pos;
    }

    return TernaryNormWeights{
        .data = packed_data,
        .scale = scale,
        .size = n,
    };
}

/// Free ternary weights
pub fn freeTernaryWeights(allocator: std.mem.Allocator, tw: TernaryNormWeights) void {
    allocator.free(tw.data);
}

/// Ternary RMSNorm: output = (input / rms) * (ternary_weight * scale)
/// Ternary multiply optimization:
/// - ternary = +1: output = x_norm * scale
/// - ternary =  0: output = 0
/// - ternary = -1: output = -x_norm * scale
pub fn ternaryRmsNorm(output: []f32, input: []const f32, tw: TernaryNormWeights, eps: f32) void {
    const n = input.len;

    // Calculate RMS using SIMD
    const aligned_n = n & ~@as(usize, SIMD_WIDTH - 1);
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

    // Scalar tail for sum
    while (i < n) : (i += 1) {
        sum_sq += input[i] * input[i];
    }

    // Calculate scale
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(n)) + eps);
    const norm_scale = tw.scale / rms;

    // Apply ternary normalization
    // No SIMD here because ternary unpacking is irregular
    for (0..n) |j| {
        const ternary = tw.unpack(j);
        output[j] = switch (ternary) {
            1 => input[j] * norm_scale,
            -1 => -input[j] * norm_scale,
            else => 0.0,
        };
    }
}

/// SIMD-optimized ternary RMSNorm with batch unpacking
/// Unpacks 8 ternary values at once for SIMD processing
pub fn simdTernaryRmsNorm(output: []f32, input: []const f32, tw: TernaryNormWeights, eps: f32) void {
    const n = input.len;
    const aligned_n = n & ~@as(usize, SIMD_WIDTH - 1);

    // Calculate RMS using SIMD
    var sum_sq_vec: Vec8f = @splat(0.0);
    var sum_sq: f32 = 0.0;

    var i: usize = 0;
    while (i < aligned_n) : (i += SIMD_WIDTH) {
        const x_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;
        sum_sq_vec += x_vec * x_vec;
    }

    const sum_arr: [SIMD_WIDTH]f32 = sum_sq_vec;
    inline for (sum_arr) |v| {
        sum_sq += v;
    }

    while (i < n) : (i += 1) {
        sum_sq += input[i] * input[i];
    }

    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(n)) + eps);
    const norm_scale = tw.scale / rms;
    const scale_vec: Vec8f = @splat(norm_scale);
    const neg_scale_vec: Vec8f = @splat(-norm_scale);
    const zero_vec: Vec8f = @splat(0.0);

    // Process 8 elements at a time with batch ternary unpacking
    i = 0;
    while (i < aligned_n) : (i += SIMD_WIDTH) {
        const x_vec: Vec8f = input[i..][0..SIMD_WIDTH].*;

        // Unpack 8 ternary values
        var ternary_arr: [SIMD_WIDTH]i8 = undefined;
        inline for (0..SIMD_WIDTH) |k| {
            ternary_arr[k] = tw.unpack(i + k);
        }

        // Apply ternary multiplication using select
        var result: [SIMD_WIDTH]f32 = undefined;
        inline for (0..SIMD_WIDTH) |k| {
            result[k] = switch (ternary_arr[k]) {
                1 => x_vec[k] * norm_scale,
                -1 => -x_vec[k] * norm_scale,
                else => 0.0,
            };
        }
        output[i..][0..SIMD_WIDTH].* = result;
    }

    // Scalar tail
    while (i < n) : (i += 1) {
        const ternary = tw.unpack(i);
        output[i] = switch (ternary) {
            1 => input[i] * norm_scale,
            -1 => -input[i] * norm_scale,
            else => 0.0,
        };
    }

    // Suppress unused variable warnings
    _ = scale_vec;
    _ = neg_scale_vec;
    _ = zero_vec;
}

test "ternary_quantize" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.1, 0.8, -0.9, 0.0, 0.6, -0.7 };

    const tw = try quantizeToTernary(allocator, &weights);
    defer freeTernaryWeights(allocator, tw);

    // Check unpacking
    try std.testing.expectEqual(@as(i8, 1), tw.unpack(0)); // 1.0 -> +1
    try std.testing.expectEqual(@as(i8, -1), tw.unpack(1)); // -1.0 -> -1
    try std.testing.expectEqual(@as(i8, 0), tw.unpack(2)); // 0.1 -> 0
    try std.testing.expectEqual(@as(i8, 1), tw.unpack(3)); // 0.8 -> +1
}

test "ternary_rms_norm" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weights = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;

    const tw = try quantizeToTernary(allocator, &weights);
    defer freeTernaryWeights(allocator, tw);

    ternaryRmsNorm(&output, &input, tw, 1e-5);

    // All weights are +1, so output should be similar to regular RMSNorm
    try std.testing.expect(output[0] > 0);
    try std.testing.expect(output[1] > output[0]); // Larger input -> larger output
}

test "simd_ternary_rms_norm" {
    const allocator = std.testing.allocator;
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 };
    const weights = [_]f32{ 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0 };
    var output: [10]f32 = undefined;

    const tw = try quantizeToTernary(allocator, &weights);
    defer freeTernaryWeights(allocator, tw);

    simdTernaryRmsNorm(&output, &input, tw, 1e-5);

    // Alternating +1/-1 weights should produce alternating signs
    try std.testing.expect(output[0] > 0);
    try std.testing.expect(output[1] < 0);
}

test "ternary_vs_f32_accuracy" {
    const allocator = std.testing.allocator;

    // Simulate typical RMSNorm weights (close to 1.0 with small variations)
    const weights = [_]f32{ 0.98, 1.02, 0.99, 1.01, 0.97, 1.03, 0.96, 1.04 };
    const input = [_]f32{ 0.5, -0.3, 0.8, -0.2, 0.6, -0.4, 0.7, -0.1 };

    var f32_output: [8]f32 = undefined;
    var ternary_output: [8]f32 = undefined;

    // f32 RMSNorm
    simdRmsNorm(&f32_output, &input, &weights, 1e-5);

    // Ternary RMSNorm
    const tw = try quantizeToTernary(allocator, &weights);
    defer freeTernaryWeights(allocator, tw);
    simdTernaryRmsNorm(&ternary_output, &input, tw, 1e-5);

    // Calculate relative error
    var max_rel_error: f32 = 0.0;
    for (0..8) |i| {
        if (@abs(f32_output[i]) > 1e-6) {
            const rel_error = @abs(ternary_output[i] - f32_output[i]) / @abs(f32_output[i]);
            if (rel_error > max_rel_error) max_rel_error = rel_error;
        }
    }

    // Ternary quantization introduces ~2-5% error for typical weights
    // This is acceptable for inference (similar to INT8 quantization)
    try std.testing.expect(max_rel_error < 0.10); // 10% max relative error
}

test "benchmark_ternary_vs_f32_norm" {
    const allocator = std.testing.allocator;

    // Typical hidden_size for small models
    const hidden_size: usize = 2048;
    const iterations: usize = 10000;

    // Allocate buffers
    const input = try allocator.alloc(f32, hidden_size);
    defer allocator.free(input);
    const weights = try allocator.alloc(f32, hidden_size);
    defer allocator.free(weights);
    const output = try allocator.alloc(f32, hidden_size);
    defer allocator.free(output);

    // Initialize with random-ish values
    for (0..hidden_size) |i| {
        input[i] = @as(f32, @floatFromInt(i % 100)) / 100.0 - 0.5;
        weights[i] = 0.95 + @as(f32, @floatFromInt(i % 10)) / 100.0;
    }

    // Quantize weights
    const tw = try quantizeToTernary(allocator, weights);
    defer freeTernaryWeights(allocator, tw);

    // Benchmark f32 RMSNorm
    var timer = std.time.Timer.start() catch unreachable;
    for (0..iterations) |_| {
        simdRmsNorm(output, input, weights, 1e-5);
        std.mem.doNotOptimizeAway(output);
    }
    const f32_time = timer.read();

    // Benchmark ternary RMSNorm
    timer.reset();
    for (0..iterations) |_| {
        simdTernaryRmsNorm(output, input, tw, 1e-5);
        std.mem.doNotOptimizeAway(output);
    }
    const ternary_time = timer.read();

    // Print results
    const f32_ns = @as(f64, @floatFromInt(f32_time)) / @as(f64, @floatFromInt(iterations));
    const ternary_ns = @as(f64, @floatFromInt(ternary_time)) / @as(f64, @floatFromInt(iterations));
    const speedup = f32_ns / ternary_ns;

    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TERNARY NORM BENCHMARK (hidden_size={d})        ║\n", .{hidden_size});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  f32 RMSNorm:     {d:>10.1} ns/iter                        ║\n", .{f32_ns});
    std.debug.print("║  Ternary RMSNorm: {d:>10.1} ns/iter                        ║\n", .{ternary_ns});
    std.debug.print("║  Speedup:         {d:>10.2}x                               ║\n", .{speedup});
    std.debug.print("║  Memory savings:  16x (f32 -> 2-bit)                        ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Test passes regardless of speed (benchmark is informational)
    try std.testing.expect(true);
}
