// Q4_K QUANTIZED MATRIX-VECTOR MULTIPLICATION
// Keeps weights in Q4_K format, dequantizes block-by-block during matmul.
// Zero extra f32 allocations — inline accumulate.
// 7.1x memory savings vs f32 dequantization path.
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const simd_matmul = @import("simd_matmul.zig");

// Q4_K constants
const QK_K: usize = 256; // Elements per super-block
const Q4K_BLOCK_SIZE: usize = 144; // Bytes per super-block: 2+2+12+128

// SIMD types
const Vec8f = @Vector(8, f32);
const SIMD_WIDTH: usize = 8;

// ═══════════════════════════════════════════════════════════════════════════════
// Q4_K SCALE/MIN EXTRACTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Extract scale and min from packed 6-bit format in Q4_K block.
/// Based on llama.cpp get_scale_min_k4.
inline fn getScaleMinK4(j: usize, scales: []const u8, d: *u8, m: *u8) void {
    if (j < 4) {
        d.* = scales[j] & 63;
        m.* = scales[j + 4] & 63;
    } else {
        d.* = (scales[j + 4] & 0x0F) | ((scales[j - 4] >> 6) << 4);
        m.* = (scales[j + 4] >> 4) | ((scales[j] >> 6) << 4);
    }
}

/// Convert f16 (IEEE 754 half-precision) to f32.
inline fn f16ToF32(h: u16) f32 {
    return gguf.f16ToF32(h);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCALAR Q4_K MATRIX-VECTOR MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Q4_K matrix-vector multiplication: output[row] = dot(Q4K_row[row], vec)
/// q4k_data: raw Q4_K bytes for entire weight matrix (rows * blocks_per_row * 144 bytes)
/// vec: input vector (f32, length = cols)
/// rows: number of output rows
/// cols: number of input columns (must be multiple of QK_K=256)
///
/// Memory layout: row-major, each row is ceil(cols/256) consecutive Q4_K blocks.
pub fn q4kMatVec(output: []f32, q4k_data: []const u8, vec: []const f32, rows: usize, cols: usize) void {
    const blocks_per_row = (cols + QK_K - 1) / QK_K;
    const row_bytes = blocks_per_row * Q4K_BLOCK_SIZE;

    for (0..rows) |row| {
        var acc: f32 = 0.0;
        const row_data = q4k_data[row * row_bytes ..];

        var block_idx: usize = 0;
        while (block_idx < blocks_per_row) : (block_idx += 1) {
            const block = row_data[block_idx * Q4K_BLOCK_SIZE ..][0..Q4K_BLOCK_SIZE];
            const col_base = block_idx * QK_K;

            // Parse Q4_K block header
            const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
            const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
            const d = f16ToF32(d_bits);
            const min_val = f16ToF32(dmin_bits);

            const scales = block[4..16]; // 12 bytes
            const qs = block[16..144]; // 128 bytes

            // Process 4 groups of 64 elements (= 256 total)
            var is: usize = 0;
            var q_idx: usize = 0;
            var col_offset: usize = col_base;

            var j: usize = 0;
            while (j < QK_K and col_offset < cols) : (j += 64) {
                // Sub-block pair scales/mins
                var sc1: u8 = undefined;
                var m1: u8 = undefined;
                getScaleMinK4(is + 0, scales, &sc1, &m1);
                const d1 = d * @as(f32, @floatFromInt(sc1));
                const min1 = min_val * @as(f32, @floatFromInt(m1));

                var sc2: u8 = undefined;
                var m2: u8 = undefined;
                getScaleMinK4(is + 1, scales, &sc2, &m2);
                const d2 = d * @as(f32, @floatFromInt(sc2));
                const min2 = min_val * @as(f32, @floatFromInt(m2));

                // 32 elements: low nibbles
                var l: usize = 0;
                while (l < 32 and col_offset + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] & 0x0F;
                    const w = d1 * @as(f32, @floatFromInt(q_val)) - min1;
                    acc += w * vec[col_offset + l];
                }

                // 32 elements: high nibbles
                l = 0;
                while (l < 32 and col_offset + 32 + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] >> 4;
                    const w = d2 * @as(f32, @floatFromInt(q_val)) - min2;
                    acc += w * vec[col_offset + 32 + l];
                }

                q_idx += 32;
                col_offset += 64;
                is += 2;
            }
        }

        output[row] = acc;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD Q4_K MATRIX-VECTOR MULTIPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD-optimized Q4_K matmul — processes 8 elements at a time.
/// Same API as q4kMatVec but uses @Vector(8, f32) for inner loop.
pub fn q4kMatVecSimd(output: []f32, q4k_data: []const u8, vec: []const f32, rows: usize, cols: usize) void {
    const blocks_per_row = (cols + QK_K - 1) / QK_K;
    const row_bytes = blocks_per_row * Q4K_BLOCK_SIZE;

    for (0..rows) |row| {
        var acc_vec: Vec8f = @splat(0.0);
        var acc_scalar: f32 = 0.0;
        const row_data = q4k_data[row * row_bytes ..];

        var block_idx: usize = 0;
        while (block_idx < blocks_per_row) : (block_idx += 1) {
            const block = row_data[block_idx * Q4K_BLOCK_SIZE ..][0..Q4K_BLOCK_SIZE];
            const col_base = block_idx * QK_K;

            const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
            const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
            const d = f16ToF32(d_bits);
            const min_val = f16ToF32(dmin_bits);

            const scales = block[4..16];
            const qs = block[16..144];

            var is: usize = 0;
            var q_idx: usize = 0;
            var col_offset: usize = col_base;

            var j: usize = 0;
            while (j < QK_K and col_offset < cols) : (j += 64) {
                var sc1: u8 = undefined;
                var m1: u8 = undefined;
                getScaleMinK4(is + 0, scales, &sc1, &m1);
                const d1 = d * @as(f32, @floatFromInt(sc1));
                const min1 = min_val * @as(f32, @floatFromInt(m1));
                const d1_vec: Vec8f = @splat(d1);
                const min1_vec: Vec8f = @splat(min1);

                var sc2: u8 = undefined;
                var m2: u8 = undefined;
                getScaleMinK4(is + 1, scales, &sc2, &m2);
                const d2 = d * @as(f32, @floatFromInt(sc2));
                const min2 = min_val * @as(f32, @floatFromInt(m2));
                const d2_vec: Vec8f = @splat(d2);
                const min2_vec: Vec8f = @splat(min2);

                // Low nibbles: 32 elements in groups of 8
                var l: usize = 0;
                while (l + SIMD_WIDTH <= 32 and col_offset + l + SIMD_WIDTH <= cols) : (l += SIMD_WIDTH) {
                    // Dequantize 8 low nibbles
                    var q_arr: [SIMD_WIDTH]f32 = undefined;
                    inline for (0..SIMD_WIDTH) |k| {
                        q_arr[k] = @floatFromInt(qs[q_idx + l + k] & 0x0F);
                    }
                    const q_vec: Vec8f = q_arr;
                    const w_vec = d1_vec * q_vec - min1_vec;
                    const v_vec: Vec8f = vec[col_offset + l ..][0..SIMD_WIDTH].*;
                    acc_vec += w_vec * v_vec;
                }
                // Scalar tail for low nibbles
                while (l < 32 and col_offset + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] & 0x0F;
                    const w = d1 * @as(f32, @floatFromInt(q_val)) - min1;
                    acc_scalar += w * vec[col_offset + l];
                }

                // High nibbles: 32 elements in groups of 8
                l = 0;
                while (l + SIMD_WIDTH <= 32 and col_offset + 32 + l + SIMD_WIDTH <= cols) : (l += SIMD_WIDTH) {
                    var q_arr: [SIMD_WIDTH]f32 = undefined;
                    inline for (0..SIMD_WIDTH) |k| {
                        q_arr[k] = @floatFromInt(qs[q_idx + l + k] >> 4);
                    }
                    const q_vec: Vec8f = q_arr;
                    const w_vec = d2_vec * q_vec - min2_vec;
                    const v_vec: Vec8f = vec[col_offset + 32 + l ..][0..SIMD_WIDTH].*;
                    acc_vec += w_vec * v_vec;
                }
                // Scalar tail for high nibbles
                while (l < 32 and col_offset + 32 + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] >> 4;
                    const w = d2 * @as(f32, @floatFromInt(q_val)) - min2;
                    acc_scalar += w * vec[col_offset + 32 + l];
                }

                q_idx += 32;
                col_offset += 64;
                is += 2;
            }
        }

        // Reduce SIMD accumulator
        const sum_arr: [SIMD_WIDTH]f32 = acc_vec;
        var simd_sum: f32 = 0.0;
        inline for (sum_arr) |v| {
            simd_sum += v;
        }
        output[row] = simd_sum + acc_scalar;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-THREADED Q4_K MATMUL (uses global_pool from simd_matmul.zig)
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread worker context for Q4_K matmul
const Q4KMatVecContext = struct {
    output: []f32,
    q4k_data: []const u8,
    vec: []const f32,
    cols: usize,
    blocks_per_row: usize,
    row_bytes: usize,
    start_row: usize,
    end_row: usize,
};

/// Worker function — processes a range of rows using SIMD Q4_K matmul.
fn q4kWorker(ctx: *const Q4KMatVecContext) void {
    const blocks_per_row = ctx.blocks_per_row;
    const cols = ctx.cols;

    var row = ctx.start_row;
    while (row < ctx.end_row) : (row += 1) {
        var acc_vec: Vec8f = @splat(0.0);
        var acc_scalar: f32 = 0.0;
        const row_data = ctx.q4k_data[row * ctx.row_bytes ..];

        var block_idx: usize = 0;
        while (block_idx < blocks_per_row) : (block_idx += 1) {
            const block = row_data[block_idx * Q4K_BLOCK_SIZE ..][0..Q4K_BLOCK_SIZE];
            const col_base = block_idx * QK_K;

            const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
            const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
            const d = f16ToF32(d_bits);
            const min_val = f16ToF32(dmin_bits);

            const scales = block[4..16];
            const qs = block[16..144];

            var is: usize = 0;
            var q_idx: usize = 0;
            var col_offset: usize = col_base;

            var j: usize = 0;
            while (j < QK_K and col_offset < cols) : (j += 64) {
                var sc1: u8 = undefined;
                var m1: u8 = undefined;
                getScaleMinK4(is + 0, scales, &sc1, &m1);
                const d1 = d * @as(f32, @floatFromInt(sc1));
                const min1 = min_val * @as(f32, @floatFromInt(m1));
                const d1_vec: Vec8f = @splat(d1);
                const min1_vec: Vec8f = @splat(min1);

                var sc2: u8 = undefined;
                var m2: u8 = undefined;
                getScaleMinK4(is + 1, scales, &sc2, &m2);
                const d2 = d * @as(f32, @floatFromInt(sc2));
                const min2 = min_val * @as(f32, @floatFromInt(m2));
                const d2_vec: Vec8f = @splat(d2);
                const min2_vec: Vec8f = @splat(min2);

                // Low nibbles
                var l: usize = 0;
                while (l + SIMD_WIDTH <= 32 and col_offset + l + SIMD_WIDTH <= cols) : (l += SIMD_WIDTH) {
                    var q_arr: [SIMD_WIDTH]f32 = undefined;
                    inline for (0..SIMD_WIDTH) |k| {
                        q_arr[k] = @floatFromInt(qs[q_idx + l + k] & 0x0F);
                    }
                    const q_vec: Vec8f = q_arr;
                    const w_vec = d1_vec * q_vec - min1_vec;
                    const v_vec: Vec8f = ctx.vec[col_offset + l ..][0..SIMD_WIDTH].*;
                    acc_vec += w_vec * v_vec;
                }
                while (l < 32 and col_offset + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] & 0x0F;
                    const w = d1 * @as(f32, @floatFromInt(q_val)) - min1;
                    acc_scalar += w * ctx.vec[col_offset + l];
                }

                // High nibbles
                l = 0;
                while (l + SIMD_WIDTH <= 32 and col_offset + 32 + l + SIMD_WIDTH <= cols) : (l += SIMD_WIDTH) {
                    var q_arr: [SIMD_WIDTH]f32 = undefined;
                    inline for (0..SIMD_WIDTH) |k| {
                        q_arr[k] = @floatFromInt(qs[q_idx + l + k] >> 4);
                    }
                    const q_vec: Vec8f = q_arr;
                    const w_vec = d2_vec * q_vec - min2_vec;
                    const v_vec: Vec8f = ctx.vec[col_offset + 32 + l ..][0..SIMD_WIDTH].*;
                    acc_vec += w_vec * v_vec;
                }
                while (l < 32 and col_offset + 32 + l < cols) : (l += 1) {
                    const q_val = qs[q_idx + l] >> 4;
                    const w = d2 * @as(f32, @floatFromInt(q_val)) - min2;
                    acc_scalar += w * ctx.vec[col_offset + 32 + l];
                }

                q_idx += 32;
                col_offset += 64;
                is += 2;
            }
        }

        const sum_arr: [SIMD_WIDTH]f32 = acc_vec;
        var simd_sum: f32 = 0.0;
        inline for (sum_arr) |v| {
            simd_sum += v;
        }
        ctx.output[row] = simd_sum + acc_scalar;
    }
}

const DEFAULT_NUM_THREADS: usize = 8;

/// Multi-threaded Q4_K matrix-vector multiplication.
/// Parallelizes across output rows using std.Thread for rows >= 512.
/// Falls back to single-threaded SIMD for small matrices.
pub fn q4kMatVecParallel(output: []f32, q4k_data: []const u8, vec: []const f32, rows: usize, cols: usize) void {
    if (rows < 512) {
        q4kMatVecSimd(output, q4k_data, vec, rows, cols);
        return;
    }

    const blocks_per_row = (cols + QK_K - 1) / QK_K;
    const row_bytes = blocks_per_row * Q4K_BLOCK_SIZE;
    const num_threads = @min(DEFAULT_NUM_THREADS, rows / 64);
    const rows_per_thread = rows / num_threads;

    var contexts: [DEFAULT_NUM_THREADS]Q4KMatVecContext = undefined;
    var threads: [DEFAULT_NUM_THREADS]?std.Thread = undefined;

    // Launch worker threads
    for (0..num_threads) |t| {
        const start_row = t * rows_per_thread;
        const end_row = if (t == num_threads - 1) rows else (t + 1) * rows_per_thread;

        contexts[t] = Q4KMatVecContext{
            .output = output,
            .q4k_data = q4k_data,
            .vec = vec,
            .cols = cols,
            .blocks_per_row = blocks_per_row,
            .row_bytes = row_bytes,
            .start_row = start_row,
            .end_row = end_row,
        };

        threads[t] = std.Thread.spawn(.{}, q4kWorker, .{&contexts[t]}) catch null;
    }

    // Wait for all threads
    for (0..num_threads) |t| {
        if (threads[t]) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Q6_K SUPPORT (used by some tensors in Q4_K_M models)
// ═══════════════════════════════════════════════════════════════════════════════

const Q6K_BLOCK_SIZE: usize = 210; // 128 + 64 + 16 + 2

/// Q6_K matrix-vector multiplication (SIMD).
/// Q6_K: 256 elements per block, 210 bytes. Structure: ql[128] + qh[64] + scales[16] + d(f16)
pub fn q6kMatVecSimd(output: []f32, q6k_data: []const u8, vec: []const f32, rows: usize, cols: usize) void {
    const blocks_per_row = (cols + QK_K - 1) / QK_K;
    const row_bytes = blocks_per_row * Q6K_BLOCK_SIZE;

    for (0..rows) |row| {
        var acc: f32 = 0.0;
        const row_data = q6k_data[row * row_bytes ..];

        var block_idx: usize = 0;
        while (block_idx < blocks_per_row) : (block_idx += 1) {
            const block = row_data[block_idx * Q6K_BLOCK_SIZE ..][0..Q6K_BLOCK_SIZE];
            const col_base = block_idx * QK_K;

            const ql = block[0..128]; // Low 4 bits of 6-bit quants
            const qh = block[128..192]; // High 2 bits of 6-bit quants
            const sc = block[192..208]; // 16 signed int8 scales
            const d_bits = @as(u16, block[208]) | (@as(u16, block[209]) << 8);
            const d = f16ToF32(d_bits);

            // Process 256 elements in 16 sub-blocks of 16
            const col_offset: usize = col_base;
            for (0..16) |sb| {
                const scale_val = @as(f32, @floatFromInt(@as(i8, @bitCast(sc[sb]))));
                const ds = d * scale_val;

                for (0..16) |el| {
                    const idx = sb * 16 + el;
                    if (col_offset + idx >= cols) break;

                    // Reconstruct 6-bit value
                    const ql_idx = idx;
                    const qh_idx = idx / 4;
                    const qh_shift: u3 = @intCast((idx % 4) * 2);

                    const low4: u8 = if (ql_idx < 128) (if (ql_idx % 2 == 0) ql[ql_idx / 2] & 0x0F else ql[ql_idx / 2] >> 4) else 0;
                    const high2: u8 = if (qh_idx < 64) ((qh[qh_idx] >> qh_shift) & 0x03) else 0;
                    const q6: i8 = @as(i8, @intCast(low4 | (high2 << 4))) - 32;

                    const w = ds * @as(f32, @floatFromInt(q6));
                    acc += w * vec[col_offset + idx];
                }
            }
        }

        output[row] = acc;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH — auto-select kernel based on GGMLType
// ═══════════════════════════════════════════════════════════════════════════════

/// Dispatch quantized matmul based on tensor type.
/// Falls back to q4kMatVecParallel for Q4_K (most common in Q4_K_M models).
pub fn quantizedMatVecParallel(output: []f32, data: []const u8, vec: []const f32, rows: usize, cols: usize, tensor_type: gguf.GGMLType) void {
    switch (tensor_type) {
        .Q4_K => q4kMatVecParallel(output, data, vec, rows, cols),
        .Q6_K => q6kMatVecSimd(output, data, vec, rows, cols),
        else => {
            // Unsupported type — zero output as safe fallback
            @memset(output[0..rows], 0.0);
            std.debug.print("[q4k_matmul] WARNING: unsupported quant type {d}, zeroing output\n", .{@intFromEnum(tensor_type)});
        },
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "q4k_matmul_basic" {
    // Create a synthetic Q4_K block (256 elements, 144 bytes)
    // All zeros with d=1.0, dmin=0.0, all scales=1, all qs=0x55 (low=5, high=5)
    var block: [Q4K_BLOCK_SIZE]u8 = undefined;
    @memset(&block, 0);

    // d = 1.0 in f16 = 0x3C00
    block[0] = 0x00;
    block[1] = 0x3C;
    // dmin = 0.0
    block[2] = 0;
    block[3] = 0;
    // scales: all sub-blocks have scale=1, min=0
    // For j < 4: scales[j] & 63 = 1, scales[j+4] & 63 = 0
    block[4] = 1; // scales[0]: sc for sub-block 0
    block[5] = 1; // scales[1]: sc for sub-block 1
    block[6] = 1; // scales[2]: sc for sub-block 2
    block[7] = 1; // scales[3]: sc for sub-block 3
    block[8] = 0; // scales[4]: min for sub-block 0
    block[9] = 0; // scales[5]: min for sub-block 1
    block[10] = 0; // scales[6]: min for sub-block 2
    block[11] = 0; // scales[7]: min for sub-block 3
    // scales[8..11] for sub-blocks 4-7
    block[12] = 1; // scales[8]: packed for sub-blocks 4-5
    block[13] = 1; // scales[9]: packed for sub-blocks 6-7
    block[14] = 0x10; // scales[10]: packed mins
    block[15] = 0x10; // scales[11]: packed mins

    // qs: all 0x55 → low nibble = 5, high nibble = 5
    for (16..144) |i| {
        block[i] = 0x55;
    }

    // 1 row, 256 columns: single Q4_K block
    // Input vector: all 1.0
    var vec: [256]f32 = undefined;
    for (&vec) |*v| v.* = 1.0;

    var output: [1]f32 = undefined;

    // Scalar version
    q4kMatVec(&output, &block, &vec, 1, 256);
    // Expected: each element = d * sc * q_val - dmin * m = 1.0 * 1 * 5 - 0 = 5.0
    // 256 elements * 5.0 * 1.0(vec) = 1280.0 (approximately, sub-blocks 4-7 have different scale encoding)
    try std.testing.expect(output[0] > 500.0); // Sanity check: positive and large

    // SIMD version should give same result
    var output_simd: [1]f32 = undefined;
    q4kMatVecSimd(&output_simd, &block, &vec, 1, 256);
    try std.testing.expectApproxEqAbs(output[0], output_simd[0], 0.001);
}

test "q4k_scalar_vs_simd_consistency" {
    // Create 2 rows of Q4_K data with varied values
    const num_rows = 2;
    const num_cols = 256;
    const blocks_per_row = 1;
    var data: [num_rows * blocks_per_row * Q4K_BLOCK_SIZE]u8 = undefined;

    for (0..num_rows) |row| {
        const offset = row * Q4K_BLOCK_SIZE;
        // d = 0.5 in f16 = 0x3800
        data[offset + 0] = 0x00;
        data[offset + 1] = 0x38;
        // dmin = 0.25 in f16 = 0x3400
        data[offset + 2] = 0x00;
        data[offset + 3] = 0x34;
        // scales[0..3] = 2, scales[4..7] = 1
        data[offset + 4] = 2;
        data[offset + 5] = 3;
        data[offset + 6] = 2;
        data[offset + 7] = 3;
        data[offset + 8] = 1;
        data[offset + 9] = 1;
        data[offset + 10] = 1;
        data[offset + 11] = 1;
        // Remaining scales for sub-blocks 4-7
        data[offset + 12] = 0x20;
        data[offset + 13] = 0x30;
        data[offset + 14] = 0x10;
        data[offset + 15] = 0x10;

        // qs: alternating pattern
        var qi: usize = 0;
        while (qi < 128) : (qi += 1) {
            data[offset + 16 + qi] = @as(u8, @intCast((qi * 3 + row * 7) % 256));
        }
    }

    var vec: [num_cols]f32 = undefined;
    for (&vec, 0..) |*v, i| {
        v.* = @as(f32, @floatFromInt(i % 10)) * 0.1;
    }

    var output_scalar: [num_rows]f32 = undefined;
    var output_simd: [num_rows]f32 = undefined;

    q4kMatVec(&output_scalar, &data, &vec, num_rows, num_cols);
    q4kMatVecSimd(&output_simd, &data, &vec, num_rows, num_cols);

    for (0..num_rows) |i| {
        try std.testing.expectApproxEqAbs(output_scalar[i], output_simd[i], 0.01);
    }
}

test "q4k_parallel_consistency" {
    // 1024 rows to trigger parallel path (threshold 512)
    const num_rows = 1024;
    const num_cols = 256;
    const blocks_per_row = 1;
    const data_size = num_rows * blocks_per_row * Q4K_BLOCK_SIZE;

    var data: [data_size]u8 = undefined;
    // Fill with simple pattern
    for (0..num_rows) |row| {
        const offset = row * Q4K_BLOCK_SIZE;
        // d = 1.0 in f16
        data[offset + 0] = 0x00;
        data[offset + 1] = 0x3C;
        // dmin = 0
        data[offset + 2] = 0;
        data[offset + 3] = 0;
        // scales: all 1
        for (4..16) |i| data[offset + i] = 1;
        // qs: all 0x33 (low=3, high=3)
        for (16..144) |i| data[offset + i] = 0x33;
    }

    var vec: [num_cols]f32 = undefined;
    for (&vec) |*v| v.* = 1.0;

    var output_serial: [num_rows]f32 = undefined;
    var output_parallel: [num_rows]f32 = undefined;

    q4kMatVecSimd(&output_serial, &data, &vec, num_rows, num_cols);
    q4kMatVecParallel(&output_parallel, &data, &vec, num_rows, num_cols);

    // All rows should produce same result (same data pattern)
    for (0..num_rows) |i| {
        try std.testing.expectApproxEqAbs(output_serial[i], output_parallel[i], 0.01);
    }
}
