// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL INFERENCE - Multi-threaded LLM Inference
// 4-8x speedup via CPU parallelization
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ternary = @import("ternary_weights.zig");
const flash = @import("flash_attention.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Number of threads - set via environment or default to CPU count
/// On Fly.io performance-16x: 16 cores available
pub const NUM_THREADS: usize = 16;
pub const MIN_ROWS_PER_THREAD: usize = 32;
pub const CACHE_LINE_SIZE: usize = 64;

// Golden ratio constants
pub const PHI: f32 = 1.618033988749895;
pub const TRINITY: f32 = 3.0; // φ² + 1/φ² = 3

// ═══════════════════════════════════════════════════════════════════════════════
// WORK CHUNK
// ═══════════════════════════════════════════════════════════════════════════════

pub const WorkChunk = struct {
    start_row: usize,
    end_row: usize,
    thread_id: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL MATMUL CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ParallelMatmulContext = struct {
    output: []f32,
    weights: []const f32,
    input: []const f32,
    rows: usize,
    cols: usize,
};

pub const ParallelTernaryContext = struct {
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
    scale: f32,
};

pub const ParallelAttentionContext = struct {
    output: []f32,
    q: []const f32,
    k_cache: []const f32,
    v_cache: []const f32,
    num_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
    seq_len: usize,
    scale: f32,
    allocator: std.mem.Allocator,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIVIDE WORK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn divideWork(total_rows: usize, num_threads: usize) [NUM_THREADS]WorkChunk {
    var chunks: [NUM_THREADS]WorkChunk = undefined;
    const rows_per_thread = @max((total_rows + num_threads - 1) / num_threads, MIN_ROWS_PER_THREAD);

    for (0..num_threads) |t| {
        const start = t * rows_per_thread;
        const end = @min(start + rows_per_thread, total_rows);
        chunks[t] = WorkChunk{
            .start_row = if (start < total_rows) start else total_rows,
            .end_row = if (start < total_rows) end else total_rows,
            .thread_id = t,
        };
    }

    return chunks;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL MATMUL (f32)
// ═══════════════════════════════════════════════════════════════════════════════

fn matmulWorker(ctx: *const ParallelMatmulContext, chunk: WorkChunk) void {
    const Vec8f = @Vector(8, f32);
    const cols = ctx.cols;
    const aligned_cols = cols & ~@as(usize, 7);

    for (chunk.start_row..chunk.end_row) |row| {
        var sum_vec: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_offset = row * cols;

        var j: usize = 0;
        while (j < aligned_cols) : (j += 8) {
            const w_vec: Vec8f = ctx.weights[row_offset + j ..][0..8].*;
            const i_vec: Vec8f = ctx.input[j..][0..8].*;
            sum_vec += w_vec * i_vec;
        }

        sum_scalar = @reduce(.Add, sum_vec);

        while (j < cols) : (j += 1) {
            sum_scalar += ctx.weights[row_offset + j] * ctx.input[j];
        }

        ctx.output[row] = sum_scalar;
    }
}

pub fn parallelMatmul(
    output: []f32,
    weights: []const f32,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const ctx = ParallelMatmulContext{
        .output = output,
        .weights = weights,
        .input = input,
        .rows = rows,
        .cols = cols,
    };

    const chunks = divideWork(rows, NUM_THREADS);

    var threads: [NUM_THREADS]?std.Thread = undefined;

    // Spawn worker threads
    for (0..NUM_THREADS) |t| {
        if (chunks[t].start_row < chunks[t].end_row) {
            threads[t] = std.Thread.spawn(.{}, matmulWorker, .{ &ctx, chunks[t] }) catch null;
        } else {
            threads[t] = null;
        }
    }

    // Join all threads
    for (threads) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL TERNARY MATMUL
// ═══════════════════════════════════════════════════════════════════════════════

fn ternaryWorker(ctx: *const ParallelTernaryContext, chunk: WorkChunk) void {
    const Vec8f = @Vector(8, f32);
    const cols = ctx.cols;
    const cols_packed = (cols + 3) / 4;
    const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

    const num_rows = chunk.end_row - chunk.start_row;
    var row = chunk.start_row;

    // Process 4 rows at a time (batch optimization)
    while (row + 4 <= chunk.end_row) {
        var sum0: Vec8f = @splat(0.0);
        var sum1: Vec8f = @splat(0.0);
        var sum2: Vec8f = @splat(0.0);
        var sum3: Vec8f = @splat(0.0);

        var col: usize = 0;
        while (col + 8 <= cols) {
            const in_vec: Vec8f = ctx.input[col..][0..8].*;
            const col_byte = col / 4;

            // Row 0
            const r0_start = row * cols_packed;
            if (r0_start + col_byte + 1 < ctx.weights.len) {
                const b0 = ctx.weights[r0_start + col_byte];
                const b1 = ctx.weights[r0_start + col_byte + 1];
                const s0: Vec8f = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum0 += in_vec * s0;
            }

            // Row 1
            const r1_start = (row + 1) * cols_packed;
            if (r1_start + col_byte + 1 < ctx.weights.len) {
                const b0 = ctx.weights[r1_start + col_byte];
                const b1 = ctx.weights[r1_start + col_byte + 1];
                const s1: Vec8f = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum1 += in_vec * s1;
            }

            // Row 2
            const r2_start = (row + 2) * cols_packed;
            if (r2_start + col_byte + 1 < ctx.weights.len) {
                const b0 = ctx.weights[r2_start + col_byte];
                const b1 = ctx.weights[r2_start + col_byte + 1];
                const s2: Vec8f = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum2 += in_vec * s2;
            }

            // Row 3
            const r3_start = (row + 3) * cols_packed;
            if (r3_start + col_byte + 1 < ctx.weights.len) {
                const b0 = ctx.weights[r3_start + col_byte];
                const b1 = ctx.weights[r3_start + col_byte + 1];
                const s3: Vec8f = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum3 += in_vec * s3;
            }

            col += 8;
        }

        ctx.output[row + 0] = @reduce(.Add, sum0) * ctx.scale;
        ctx.output[row + 1] = @reduce(.Add, sum1) * ctx.scale;
        ctx.output[row + 2] = @reduce(.Add, sum2) * ctx.scale;
        ctx.output[row + 3] = @reduce(.Add, sum3) * ctx.scale;

        row += 4;
    }

    // Handle remaining rows
    while (row < chunk.end_row) : (row += 1) {
        var sum_vec: Vec8f = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        while (col + 8 <= cols and row_start + col / 4 + 1 < ctx.weights.len) {
            const in_vec: Vec8f = ctx.input[col..][0..8].*;
            const byte0 = ctx.weights[row_start + col / 4];
            const byte1 = ctx.weights[row_start + col / 4 + 1];
            const signs: Vec8f = .{
                sign_lut[(byte0 >> 0) & 0x3], sign_lut[(byte0 >> 2) & 0x3],
                sign_lut[(byte0 >> 4) & 0x3], sign_lut[(byte0 >> 6) & 0x3],
                sign_lut[(byte1 >> 0) & 0x3], sign_lut[(byte1 >> 2) & 0x3],
                sign_lut[(byte1 >> 4) & 0x3], sign_lut[(byte1 >> 6) & 0x3],
            };
            sum_vec += in_vec * signs;
            col += 8;
        }

        sum_scalar = @reduce(.Add, sum_vec);

        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= ctx.weights.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (ctx.weights[byte_idx] >> shift) & 0x3;
            sum_scalar += ctx.input[col] * sign_lut[trit];
        }

        ctx.output[row] = sum_scalar * ctx.scale;
    }

    _ = num_rows;
}

/// Minimum rows to justify parallelization overhead
/// On 16-core: parallelize medium and large matrices
pub const MIN_PARALLEL_ROWS: usize = 512;

pub fn parallelTernaryMatmul(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
    scale: f32,
) void {
    // For small matrices, use single-threaded batch SIMD (fastest)
    if (rows < MIN_PARALLEL_ROWS) {
        ternary.batchTernaryMatVec(output, weights, input, rows, cols);
        for (output) |*o| o.* *= scale;
        return;
    }

    const ctx = ParallelTernaryContext{
        .output = output,
        .weights = weights,
        .input = input,
        .rows = rows,
        .cols = cols,
        .scale = scale,
    };

    const chunks = divideWork(rows, NUM_THREADS);

    var threads: [NUM_THREADS]?std.Thread = undefined;

    for (0..NUM_THREADS) |t| {
        if (chunks[t].start_row < chunks[t].end_row) {
            threads[t] = std.Thread.spawn(.{}, ternaryWorker, .{ &ctx, chunks[t] }) catch null;
        } else {
            threads[t] = null;
        }
    }

    for (threads) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL ATTENTION (by heads)
// ═══════════════════════════════════════════════════════════════════════════════

fn attentionHeadWorker(ctx: *const ParallelAttentionContext, head_start: usize, head_end: usize) void {
    const kv_group_size = ctx.num_heads / ctx.num_kv_heads;
    const head_dim = ctx.head_dim;
    const seq_len = ctx.seq_len;
    const scale = ctx.scale;

    // Thread-local score buffer (stack allocated for small seq_len)
    var scores_buf: [2048]f32 = undefined;
    const scores = scores_buf[0..seq_len];

    for (head_start..head_end) |h| {
        const kv_h = h / kv_group_size;
        const q_head = ctx.q[h * head_dim ..][0..head_dim];
        const out_head = ctx.output[h * head_dim ..][0..head_dim];

        // Compute attention scores
        for (0..seq_len) |t| {
            const k_offset = t * ctx.num_kv_heads * head_dim + kv_h * head_dim;
            const k_vec = ctx.k_cache[k_offset..][0..head_dim];
            scores[t] = flash.simdDot(q_head, k_vec) * scale;
        }

        // Softmax
        var max_val: f32 = scores[0];
        for (scores[1..]) |s| {
            if (s > max_val) max_val = s;
        }

        var sum: f32 = 0.0;
        for (scores) |*s| {
            s.* = @exp(s.* - max_val);
            sum += s.*;
        }
        for (scores) |*s| {
            s.* /= sum;
        }

        // Weighted sum
        @memset(out_head, 0.0);
        for (0..seq_len) |t| {
            const v_offset = t * ctx.num_kv_heads * head_dim + kv_h * head_dim;
            const v_vec = ctx.v_cache[v_offset..][0..head_dim];
            const weight = scores[t];

            for (0..head_dim) |i| {
                out_head[i] += weight * v_vec[i];
            }
        }
    }
}

pub fn parallelAttention(
    allocator: std.mem.Allocator,
    output: []f32,
    q: []const f32,
    k_cache: []const f32,
    v_cache: []const f32,
    num_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
    seq_len: usize,
    scale: f32,
) !void {
    const ctx = ParallelAttentionContext{
        .output = output,
        .q = q,
        .k_cache = k_cache,
        .v_cache = v_cache,
        .num_heads = num_heads,
        .num_kv_heads = num_kv_heads,
        .head_dim = head_dim,
        .seq_len = seq_len,
        .scale = scale,
        .allocator = allocator,
    };

    // Divide heads across threads
    const heads_per_thread = (num_heads + NUM_THREADS - 1) / NUM_THREADS;

    var threads: [NUM_THREADS]?std.Thread = undefined;

    for (0..NUM_THREADS) |t| {
        const head_start = t * heads_per_thread;
        const head_end = @min(head_start + heads_per_thread, num_heads);

        if (head_start < num_heads) {
            threads[t] = std.Thread.spawn(.{}, attentionHeadWorker, .{ &ctx, head_start, head_end }) catch null;
        } else {
            threads[t] = null;
        }
    }

    for (threads) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parallel_matmul_correctness" {
    const allocator = std.testing.allocator;

    const rows: usize = 256;
    const cols: usize = 128;

    const weights = try allocator.alloc(f32, rows * cols);
    defer allocator.free(weights);
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    const output_parallel = try allocator.alloc(f32, rows);
    defer allocator.free(output_parallel);
    const output_serial = try allocator.alloc(f32, rows);
    defer allocator.free(output_serial);

    // Initialize
    for (weights, 0..) |*w, i| w.* = @sin(@as(f32, @floatFromInt(i)) * 0.01);
    for (input, 0..) |*v, i| v.* = @cos(@as(f32, @floatFromInt(i)) * 0.01);

    // Parallel
    parallelMatmul(output_parallel, weights, input, rows, cols);

    // Serial (reference)
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        for (0..cols) |col| {
            sum += weights[row * cols + col] * input[col];
        }
        output_serial[row] = sum;
    }

    // Compare
    for (output_parallel, output_serial) |p, s| {
        try std.testing.expectApproxEqAbs(p, s, 0.001);
    }
}

test "divide_work" {
    const chunks = divideWork(100, 4);

    try std.testing.expectEqual(@as(usize, 0), chunks[0].start_row);
    try std.testing.expectEqual(@as(usize, 32), chunks[0].end_row);
    try std.testing.expectEqual(@as(usize, 32), chunks[1].start_row);
    try std.testing.expectEqual(@as(usize, 64), chunks[1].end_row);
}
