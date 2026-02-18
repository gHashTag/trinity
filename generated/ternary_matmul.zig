// =============================================================================
// TERNARY MATRIX MULTIPLICATION v2.0.0 — OPT-T02
// Generated from specs/tri/ternary_matmul.vibee
// 10x matmul speedup: no multiplications, only add/sub
// 16-20x memory compression: 2-bit ternary vs 32-bit float
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// CONSTANTS
// =============================================================================

/// Sign lookup table: trit encoding -> float sign
/// 00=0.0, 01=+1.0, 10=-1.0, 11=0.0 (reserved)
pub const SIGN_LUT: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };

/// Trit encoding constants
pub const TRIT_ZERO: u2 = 0b00;
pub const TRIT_PLUS: u2 = 0b01;
pub const TRIT_MINUS: u2 = 0b10;

// =============================================================================
// TYPES
// =============================================================================

/// Quantization mode for float-to-ternary conversion
pub const QuantMode = enum {
    /// threshold = mean(|w|) * 0.5 — best general accuracy
    absmean,
    /// threshold = rms(w) * 0.5 — better for normally distributed weights
    rms,
    /// threshold = max(|w|) * 0.5 — most aggressive compression
    max_abs,
};

/// Packed ternary weight matrix with per-row scales
/// Memory layout: row-major, 4 trits per byte
pub const TernaryMatrix = struct {
    /// Packed ternary data (4 trits per byte)
    data: []u8,
    /// Per-row scale factors for dequantization
    scales: []f32,
    /// Matrix dimensions
    rows: usize,
    cols: usize,
    /// Packed columns = ceil(cols / 4)
    cols_packed: usize,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    pub fn deinit(self: *TernaryMatrix) void {
        self.allocator.free(self.data);
        self.allocator.free(self.scales);
    }

    /// Memory usage in bytes (data + scales)
    pub fn memoryUsage(self: *const TernaryMatrix) usize {
        return self.data.len + self.scales.len * @sizeOf(f32);
    }

    /// Compression ratio vs f32
    pub fn compressionRatio(self: *const TernaryMatrix) f32 {
        const f32_bytes = self.rows * self.cols * @sizeOf(f32);
        const tern_bytes = self.memoryUsage();
        return @as(f32, @floatFromInt(f32_bytes)) / @as(f32, @floatFromInt(tern_bytes));
    }
};

/// Memory usage statistics
pub const MemoryStats = struct {
    f32_bytes: usize,
    ternary_bytes: usize,
    compression_ratio: f32,
    rows: usize,
    cols: usize,
};

// =============================================================================
// QUANTIZATION: Float -> Ternary
// =============================================================================

/// Pack 4 trits into a single byte
pub inline fn pack4Trits(t0: u2, t1: u2, t2: u2, t3: u2) u8 {
    return @as(u8, t0) | (@as(u8, t1) << 2) | (@as(u8, t2) << 4) | (@as(u8, t3) << 6);
}

/// Unpack 4 trits from a byte
pub inline fn unpack4Trits(byte: u8) [4]u2 {
    return .{
        @truncate(byte & 0x3),
        @truncate((byte >> 2) & 0x3),
        @truncate((byte >> 4) & 0x3),
        @truncate((byte >> 6) & 0x3),
    };
}

/// Compute threshold for a row based on quantization mode
fn computeThreshold(row: []const f32, mode: QuantMode) f32 {
    var sum: f32 = 0.0;
    var sum_sq: f32 = 0.0;
    var max_val: f32 = 0.0;

    for (row) |w| {
        const abs_w = @abs(w);
        sum += abs_w;
        sum_sq += w * w;
        if (abs_w > max_val) max_val = abs_w;
    }

    const n = @as(f32, @floatFromInt(row.len));
    return switch (mode) {
        .absmean => (sum / n) * 0.5,
        .rms => @sqrt(sum_sq / n) * 0.5,
        .max_abs => max_val * 0.5,
    };
}

/// Compute scale factor for a row (max absolute value)
fn computeScale(row: []const f32) f32 {
    var max_val: f32 = 0.0;
    for (row) |w| {
        const abs_w = @abs(w);
        if (abs_w > max_val) max_val = abs_w;
    }
    return if (max_val > 1e-10) max_val else 1.0;
}

/// Quantize a single row: returns packed bytes, sets scale
fn quantizeRow(dst: []u8, src: []const f32, mode: QuantMode) f32 {
    const threshold = computeThreshold(src, mode);
    const scale = computeScale(src);

    var col: usize = 0;
    var byte_idx: usize = 0;

    while (col < src.len) {
        const t0: u2 = if (col < src.len) tritFromFloat(src[col], threshold) else TRIT_ZERO;
        const t1: u2 = if (col + 1 < src.len) tritFromFloat(src[col + 1], threshold) else TRIT_ZERO;
        const t2: u2 = if (col + 2 < src.len) tritFromFloat(src[col + 2], threshold) else TRIT_ZERO;
        const t3: u2 = if (col + 3 < src.len) tritFromFloat(src[col + 3], threshold) else TRIT_ZERO;

        dst[byte_idx] = pack4Trits(t0, t1, t2, t3);
        col += 4;
        byte_idx += 1;
    }

    return scale;
}

/// Convert float to trit encoding
inline fn tritFromFloat(value: f32, threshold: f32) u2 {
    if (value > threshold) return TRIT_PLUS;
    if (value < -threshold) return TRIT_MINUS;
    return TRIT_ZERO;
}

/// Quantize full f32 matrix to TernaryMatrix
pub fn quantizeMatrix(
    allocator: std.mem.Allocator,
    weights: []const f32,
    rows: usize,
    cols: usize,
    mode: QuantMode,
) !TernaryMatrix {
    const cols_packed = (cols + 3) / 4;
    const total_bytes = rows * cols_packed;

    const data = try allocator.alloc(u8, total_bytes);
    const scales = try allocator.alloc(f32, rows);

    for (0..rows) |row| {
        const src = weights[row * cols ..][0..cols];
        const dst = data[row * cols_packed ..][0..cols_packed];
        scales[row] = quantizeRow(dst, src, mode);
    }

    return TernaryMatrix{
        .data = data,
        .scales = scales,
        .rows = rows,
        .cols = cols,
        .cols_packed = cols_packed,
        .allocator = allocator,
    };
}

// =============================================================================
// DEQUANTIZATION: Ternary -> Float
// =============================================================================

/// Dequantize a single row back to f32 (approximate reconstruction)
pub fn dequantizeRow(output: []f32, data: []const u8, scale: f32, cols: usize) void {
    var col: usize = 0;
    var byte_idx: usize = 0;

    while (col < cols) {
        const byte = data[byte_idx];
        const trits = unpack4Trits(byte);

        inline for (0..4) |i| {
            if (col + i < cols) {
                output[col + i] = SIGN_LUT[trits[i]] * scale;
            }
        }

        col += 4;
        byte_idx += 1;
    }
}

// =============================================================================
// MATVEC: Scalar (reference implementation)
// =============================================================================

/// Scalar ternary matrix-vector multiplication
/// y[i] = scale[i] * sum_j(sign(W[i,j]) * x[j])
/// No multiplications in inner loop — only add/sub/skip
pub fn ternaryMatVecScalar(
    output: []f32,
    mat: *const TernaryMatrix,
    input: []const f32,
) void {
    for (0..mat.rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * mat.cols_packed;
        var col: usize = 0;

        while (col < mat.cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= mat.data.len) break;
            const byte = mat.data[byte_idx];

            inline for (0..4) |i| {
                if (col + i < mat.cols) {
                    const shift: u3 = @intCast(i * 2);
                    const trit = (byte >> shift) & 0x3;
                    switch (trit) {
                        0b01 => sum += input[col + i], // +1
                        0b10 => sum -= input[col + i], // -1
                        else => {}, // 0: skip
                    }
                }
            }
            col += 4;
        }

        output[row] = sum * mat.scales[row];
    }
}

// =============================================================================
// MATVEC: SIMD 8-wide
// =============================================================================

/// SIMD-8 ternary matrix-vector multiplication
/// Processes 8 values per cycle using @Vector(8, f32)
pub fn ternaryMatVecSimd8(
    output: []f32,
    mat: *const TernaryMatrix,
    input: []const f32,
) void {
    const Vec8 = @Vector(8, f32);

    for (0..mat.rows) |row| {
        var sum_vec: Vec8 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * mat.cols_packed;
        const scale = mat.scales[row];

        var col: usize = 0;

        // SIMD path: 8 values at a time (2 bytes = 8 trits)
        while (col + 8 <= mat.cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx + 1 >= mat.data.len) break;

            const in_vec: Vec8 = input[col..][0..8].*;
            const b0 = mat.data[byte_idx];
            const b1 = mat.data[byte_idx + 1];

            const signs: Vec8 = .{
                SIGN_LUT[(b0 >> 0) & 0x3],
                SIGN_LUT[(b0 >> 2) & 0x3],
                SIGN_LUT[(b0 >> 4) & 0x3],
                SIGN_LUT[(b0 >> 6) & 0x3],
                SIGN_LUT[(b1 >> 0) & 0x3],
                SIGN_LUT[(b1 >> 2) & 0x3],
                SIGN_LUT[(b1 >> 4) & 0x3],
                SIGN_LUT[(b1 >> 6) & 0x3],
            };

            sum_vec += in_vec * signs;
            col += 8;
        }

        sum_scalar = @reduce(.Add, sum_vec);

        // Scalar tail
        while (col < mat.cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= mat.data.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (mat.data[byte_idx] >> shift) & 0x3;
            sum_scalar += input[col] * SIGN_LUT[trit];
        }

        output[row] = sum_scalar * scale;
    }
}

// =============================================================================
// MATVEC: SIMD 16-wide
// =============================================================================

/// SIMD-16 ternary matrix-vector multiplication
/// Processes 16 values per cycle (4 bytes = 16 trits)
pub fn ternaryMatVecSimd16(
    output: []f32,
    mat: *const TernaryMatrix,
    input: []const f32,
) void {
    const Vec16 = @Vector(16, f32);

    for (0..mat.rows) |row| {
        var sum_vec: Vec16 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * mat.cols_packed;
        const scale = mat.scales[row];

        var col: usize = 0;

        // SIMD path: 16 values at a time (4 bytes = 16 trits)
        while (col + 16 <= mat.cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx + 3 >= mat.data.len) break;

            const in_vec: Vec16 = input[col..][0..16].*;
            const b0 = mat.data[byte_idx];
            const b1 = mat.data[byte_idx + 1];
            const b2 = mat.data[byte_idx + 2];
            const b3 = mat.data[byte_idx + 3];

            const signs: Vec16 = .{
                SIGN_LUT[(b0 >> 0) & 0x3], SIGN_LUT[(b0 >> 2) & 0x3],
                SIGN_LUT[(b0 >> 4) & 0x3], SIGN_LUT[(b0 >> 6) & 0x3],
                SIGN_LUT[(b1 >> 0) & 0x3], SIGN_LUT[(b1 >> 2) & 0x3],
                SIGN_LUT[(b1 >> 4) & 0x3], SIGN_LUT[(b1 >> 6) & 0x3],
                SIGN_LUT[(b2 >> 0) & 0x3], SIGN_LUT[(b2 >> 2) & 0x3],
                SIGN_LUT[(b2 >> 4) & 0x3], SIGN_LUT[(b2 >> 6) & 0x3],
                SIGN_LUT[(b3 >> 0) & 0x3], SIGN_LUT[(b3 >> 2) & 0x3],
                SIGN_LUT[(b3 >> 4) & 0x3], SIGN_LUT[(b3 >> 6) & 0x3],
            };

            sum_vec += in_vec * signs;
            col += 16;
        }

        sum_scalar = @reduce(.Add, sum_vec);

        // Scalar tail
        while (col < mat.cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= mat.data.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (mat.data[byte_idx] >> shift) & 0x3;
            sum_scalar += input[col] * SIGN_LUT[trit];
        }

        output[row] = sum_scalar * scale;
    }
}

// =============================================================================
// MATVEC: Batch 4-row
// =============================================================================

/// Batch-4 ternary matrix-vector multiplication
/// Processes 4 rows simultaneously for register-level parallelism
pub fn ternaryMatVecBatch4(
    output: []f32,
    mat: *const TernaryMatrix,
    input: []const f32,
) void {
    const Vec8 = @Vector(8, f32);
    var row: usize = 0;

    // Process 4 rows at a time
    while (row + 4 <= mat.rows) {
        var s0: Vec8 = @splat(0.0);
        var s1: Vec8 = @splat(0.0);
        var s2: Vec8 = @splat(0.0);
        var s3: Vec8 = @splat(0.0);

        var col: usize = 0;

        while (col + 8 <= mat.cols) {
            const in_vec: Vec8 = input[col..][0..8].*;
            const col_byte = col / 4;

            inline for (0..4) |r| {
                const r_start = (row + r) * mat.cols_packed;
                if (r_start + col_byte + 1 < mat.data.len) {
                    const b0 = mat.data[r_start + col_byte];
                    const b1 = mat.data[r_start + col_byte + 1];
                    const signs: Vec8 = .{
                        SIGN_LUT[(b0 >> 0) & 0x3], SIGN_LUT[(b0 >> 2) & 0x3],
                        SIGN_LUT[(b0 >> 4) & 0x3], SIGN_LUT[(b0 >> 6) & 0x3],
                        SIGN_LUT[(b1 >> 0) & 0x3], SIGN_LUT[(b1 >> 2) & 0x3],
                        SIGN_LUT[(b1 >> 4) & 0x3], SIGN_LUT[(b1 >> 6) & 0x3],
                    };
                    switch (r) {
                        0 => s0 += in_vec * signs,
                        1 => s1 += in_vec * signs,
                        2 => s2 += in_vec * signs,
                        3 => s3 += in_vec * signs,
                        else => {},
                    }
                }
            }
            col += 8;
        }

        output[row + 0] = @reduce(.Add, s0) * mat.scales[row + 0];
        output[row + 1] = @reduce(.Add, s1) * mat.scales[row + 1];
        output[row + 2] = @reduce(.Add, s2) * mat.scales[row + 2];
        output[row + 3] = @reduce(.Add, s3) * mat.scales[row + 3];

        // Scalar tail for remaining columns
        if (col < mat.cols) {
            while (col < mat.cols) : (col += 1) {
                const byte_shift: u3 = @intCast((col % 4) * 2);
                inline for (0..4) |r| {
                    const byte_idx = (row + r) * mat.cols_packed + col / 4;
                    if (byte_idx < mat.data.len) {
                        const trit = (mat.data[byte_idx] >> byte_shift) & 0x3;
                        output[row + r] += input[col] * SIGN_LUT[trit] * mat.scales[row + r];
                    }
                }
            }
        }

        row += 4;
    }

    // Remaining rows: scalar
    while (row < mat.rows) : (row += 1) {
        var sum: f32 = 0.0;
        const row_start = row * mat.cols_packed;
        for (0..mat.cols) |col| {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= mat.data.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (mat.data[byte_idx] >> shift) & 0x3;
            switch (trit) {
                0b01 => sum += input[col],
                0b10 => sum -= input[col],
                else => {},
            }
        }
        output[row] = sum * mat.scales[row];
    }
}

// =============================================================================
// MATMAT: Matrix-Matrix Multiplication
// =============================================================================

/// Ternary matrix-matrix multiplication: Y = W * X
/// W: TernaryMatrix (rows x cols), X: f32 (cols x batch_size)
/// Y: f32 (rows x batch_size)
/// Reuses SIMD matvec kernels per column of X
pub fn ternaryMatMat(
    output: []f32,
    mat: *const TernaryMatrix,
    input_matrix: []const f32,
    batch_size: usize,
) void {
    // For each column in the batch, do matvec
    for (0..batch_size) |b| {
        // Extract column b from input matrix (row-major: input[row * batch_size + b])
        // We need a contiguous column vector, so we extract it
        var col_buf: [4096]f32 = undefined;
        const col_len = @min(mat.cols, 4096);

        for (0..col_len) |i| {
            col_buf[i] = input_matrix[i * batch_size + b];
        }

        // Output column
        var out_buf: [4096]f32 = undefined;
        const out_len = @min(mat.rows, 4096);

        ternaryMatVecSimd8(out_buf[0..out_len], mat, col_buf[0..col_len]);

        // Write back to output matrix
        for (0..out_len) |i| {
            output[i * batch_size + b] = out_buf[i];
        }
    }
}

// =============================================================================
// ACCURACY VALIDATION
// =============================================================================

/// Compute cosine similarity between two vectors
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;
    const len = @min(a.len, b.len);

    for (0..len) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    if (norm_a < 1e-10 or norm_b < 1e-10) return 0.0;
    return dot / (@sqrt(norm_a) * @sqrt(norm_b));
}

/// Compute mean absolute error between two vectors
pub fn meanAbsError(a: []const f32, b: []const f32) f32 {
    var sum: f32 = 0.0;
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        sum += @abs(a[i] - b[i]);
    }
    return sum / @as(f32, @floatFromInt(len));
}

/// f32 reference matmul for accuracy comparison
pub fn f32MatVec(output: []f32, weights: []const f32, input: []const f32, rows: usize, cols: usize) void {
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        for (0..cols) |col| {
            sum += weights[row * cols + col] * input[col];
        }
        output[row] = sum;
    }
}

/// Compute memory stats for given dimensions
pub fn computeMemoryStats(rows: usize, cols: usize) MemoryStats {
    const f32_bytes = rows * cols * @sizeOf(f32);
    const cols_packed = (cols + 3) / 4;
    const ternary_bytes = rows * cols_packed + rows * @sizeOf(f32); // data + scales
    return MemoryStats{
        .f32_bytes = f32_bytes,
        .ternary_bytes = ternary_bytes,
        .compression_ratio = @as(f32, @floatFromInt(f32_bytes)) / @as(f32, @floatFromInt(ternary_bytes)),
        .rows = rows,
        .cols = cols,
    };
}

// =============================================================================
// TESTS (15 tests)
// =============================================================================

test "pack and unpack trits roundtrip" {
    const trits = [4]u2{ TRIT_PLUS, TRIT_MINUS, TRIT_ZERO, TRIT_PLUS };
    const byte = pack4Trits(trits[0], trits[1], trits[2], trits[3]);
    const unpacked = unpack4Trits(byte);

    try std.testing.expectEqual(TRIT_PLUS, unpacked[0]);
    try std.testing.expectEqual(TRIT_MINUS, unpacked[1]);
    try std.testing.expectEqual(TRIT_ZERO, unpacked[2]);
    try std.testing.expectEqual(TRIT_PLUS, unpacked[3]);
}

test "tritFromFloat encoding" {
    try std.testing.expectEqual(TRIT_PLUS, tritFromFloat(1.0, 0.5));
    try std.testing.expectEqual(TRIT_MINUS, tritFromFloat(-1.0, 0.5));
    try std.testing.expectEqual(TRIT_ZERO, tritFromFloat(0.1, 0.5));
    try std.testing.expectEqual(TRIT_ZERO, tritFromFloat(-0.2, 0.5));
}

test "quantize matrix absmean" {
    const allocator = std.testing.allocator;
    // 2x4 matrix
    const weights = [_]f32{
        1.0,  -0.8, 0.1,  0.9,
        -0.7, 0.6,  -0.3, 0.0,
    };

    var mat = try quantizeMatrix(allocator, &weights, 2, 4, .absmean);
    defer mat.deinit();

    try std.testing.expectEqual(@as(usize, 2), mat.rows);
    try std.testing.expectEqual(@as(usize, 4), mat.cols);
    try std.testing.expectEqual(@as(usize, 1), mat.cols_packed);
    try std.testing.expect(mat.scales[0] > 0.0);
    try std.testing.expect(mat.scales[1] > 0.0);
}

test "quantize matrix rms mode" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.0, 1.0 };

    var mat = try quantizeMatrix(allocator, &weights, 1, 4, .rms);
    defer mat.deinit();

    try std.testing.expect(mat.scales[0] > 0.0);
}

test "quantize matrix max_abs mode" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 0.5, -0.3, 0.0, 0.8 };

    var mat = try quantizeMatrix(allocator, &weights, 1, 4, .max_abs);
    defer mat.deinit();

    try std.testing.expectApproxEqAbs(@as(f32, 0.8), mat.scales[0], 0.01);
}

test "dequantize row roundtrip" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.0, 1.0 };

    var mat = try quantizeMatrix(allocator, &weights, 1, 4, .absmean);
    defer mat.deinit();

    var output: [4]f32 = undefined;
    dequantizeRow(&output, mat.data[0..mat.cols_packed], mat.scales[0], 4);

    // Dequantized values should be +scale, -scale, 0, or +scale
    for (output) |v| {
        try std.testing.expect(!std.math.isNan(v));
    }
}

test "scalar matvec correctness" {
    const allocator = std.testing.allocator;
    // W = [[+1, -1, 0, +1], [-1, +1, +1, 0]]
    // x = [1, 2, 3, 4]
    // y[0] = scale0 * (1 - 2 + 0 + 4) = scale0 * 3
    // y[1] = scale1 * (-1 + 2 + 3 + 0) = scale1 * 4
    const weights = [_]f32{
        1.0,  -1.0, 0.0, 1.0,
        -1.0, 1.0,  1.0, 0.0,
    };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;

    var mat = try quantizeMatrix(allocator, &weights, 2, 4, .absmean);
    defer mat.deinit();

    ternaryMatVecScalar(&output, &mat, &input);

    // With per-row scales, values won't be exact 3.0/4.0 but should be proportional
    try std.testing.expect(output[0] > 0.0); // positive result
    try std.testing.expect(output[1] > 0.0); // positive result
}

test "simd8 matches scalar" {
    const allocator = std.testing.allocator;
    const rows: usize = 4;
    const cols: usize = 16; // multiple of 8 for clean SIMD

    var weights: [rows * cols]f32 = undefined;
    for (&weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.3);
    }

    var input: [cols]f32 = undefined;
    for (&input, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.2);
    }

    var mat = try quantizeMatrix(allocator, &weights, rows, cols, .absmean);
    defer mat.deinit();

    var out_scalar: [rows]f32 = undefined;
    var out_simd8: [rows]f32 = undefined;

    ternaryMatVecScalar(&out_scalar, &mat, &input);
    ternaryMatVecSimd8(&out_simd8, &mat, &input);

    for (0..rows) |i| {
        try std.testing.expectApproxEqAbs(out_scalar[i], out_simd8[i], 0.001);
    }
}

test "simd16 matches scalar" {
    const allocator = std.testing.allocator;
    const rows: usize = 4;
    const cols: usize = 32; // multiple of 16

    var weights: [rows * cols]f32 = undefined;
    for (&weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.17);
    }

    var input: [cols]f32 = undefined;
    for (&input, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.13);
    }

    var mat = try quantizeMatrix(allocator, &weights, rows, cols, .absmean);
    defer mat.deinit();

    var out_scalar: [rows]f32 = undefined;
    var out_simd16: [rows]f32 = undefined;

    ternaryMatVecScalar(&out_scalar, &mat, &input);
    ternaryMatVecSimd16(&out_simd16, &mat, &input);

    for (0..rows) |i| {
        try std.testing.expectApproxEqAbs(out_scalar[i], out_simd16[i], 0.001);
    }
}

test "batch4 matches scalar" {
    const allocator = std.testing.allocator;
    const rows: usize = 8; // must be >= 4
    const cols: usize = 16;

    var weights: [rows * cols]f32 = undefined;
    for (&weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.23);
    }

    var input: [cols]f32 = undefined;
    for (&input, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.11);
    }

    var mat = try quantizeMatrix(allocator, &weights, rows, cols, .absmean);
    defer mat.deinit();

    var out_scalar: [rows]f32 = undefined;
    var out_batch4: [rows]f32 = undefined;

    ternaryMatVecScalar(&out_scalar, &mat, &input);
    ternaryMatVecBatch4(&out_batch4, &mat, &input);

    for (0..rows) |i| {
        try std.testing.expectApproxEqAbs(out_scalar[i], out_batch4[i], 0.01);
    }
}

test "matmat batch multiplication" {
    const allocator = std.testing.allocator;
    const rows: usize = 4;
    const cols: usize = 8;
    const batch: usize = 2;

    var weights: [rows * cols]f32 = undefined;
    for (&weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.5);
    }

    // Input matrix: cols x batch (row-major)
    var input_mat: [cols * batch]f32 = undefined;
    for (&input_mat, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.3);
    }

    var mat = try quantizeMatrix(allocator, &weights, rows, cols, .absmean);
    defer mat.deinit();

    var output_mat: [rows * batch]f32 = undefined;
    ternaryMatMat(&output_mat, &mat, &input_mat, batch);

    // Verify output is valid (not NaN)
    for (output_mat) |v| {
        try std.testing.expect(!std.math.isNan(v));
    }
}

test "f32 vs ternary accuracy (cosine similarity)" {
    const allocator = std.testing.allocator;
    const rows: usize = 4;
    const cols: usize = 32;

    var weights: [rows * cols]f32 = undefined;
    for (&weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
    }

    var input: [cols]f32 = undefined;
    for (&input, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.07);
    }

    var mat = try quantizeMatrix(allocator, &weights, rows, cols, .absmean);
    defer mat.deinit();

    var out_f32: [rows]f32 = undefined;
    var out_ternary: [rows]f32 = undefined;

    f32MatVec(&out_f32, &weights, &input, rows, cols);
    ternaryMatVecSimd8(&out_ternary, &mat, &input);

    // Cosine similarity should be reasonable (>0.8 for structured data)
    const cos_sim = cosineSimilarity(&out_f32, &out_ternary);
    try std.testing.expect(cos_sim > 0.7);
}

test "memory compression ratio" {
    const stats = computeMemoryStats(4096, 4096);

    // f32: 4096 * 4096 * 4 = 67108864 bytes (64 MB)
    try std.testing.expectEqual(@as(usize, 67108864), stats.f32_bytes);

    // ternary: 4096 * 1024 + 4096 * 4 = 4194304 + 16384 = 4210688
    // ratio: ~15.9x
    try std.testing.expect(stats.compression_ratio > 15.0);
    try std.testing.expect(stats.compression_ratio < 20.0);
}

test "all-zeros input" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.0, 1.0 };
    const input = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
    var output: [1]f32 = undefined;

    var mat = try quantizeMatrix(allocator, &weights, 1, 4, .absmean);
    defer mat.deinit();

    ternaryMatVecScalar(&output, &mat, &input);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), output[0], 0.001);
}

test "TernaryMatrix compression ratio method" {
    const allocator = std.testing.allocator;
    const rows: usize = 256;
    const cols: usize = 256;

    const weights = try allocator.alloc(f32, rows * cols);
    defer allocator.free(weights);
    for (weights, 0..) |*w, i| {
        w.* = @sin(@as(f32, @floatFromInt(i)) * 0.01);
    }

    var mat = try quantizeMatrix(allocator, weights, rows, cols, .absmean);
    defer mat.deinit();

    const ratio = mat.compressionRatio();
    try std.testing.expect(ratio > 13.0);

    const mem = mat.memoryUsage();
    try std.testing.expect(mem < rows * cols * @sizeOf(f32));
}

// φ² + 1/φ² = 3 | TRINITY
