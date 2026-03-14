// @origin(spec:sparse_ternary.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Sparse Ternary Matmul Variants
// 4 implementations: naive_switch (baseline), packed_ternary (2-bit),
// sparse_index (CSR), branchless (bit-manipulation).
// All produce identical results — benchmark to find fastest on M1 Pro.
//
// Weight layout: row-major W[i * out_dim + j], same as simd_ops.zig.
// API matches simd_ops.zig signatures for drop-in replacement.

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// COMMON TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const VEC_SIZE = 8;
const UNROLL = 4;
const BLOCK = VEC_SIZE * UNROLL;
const Vec8 = @Vector(VEC_SIZE, f32);
const Vec8i = @Vector(VEC_SIZE, i8);
const Vec8i16 = @Vector(VEC_SIZE, i16);
const zero_vec: Vec8 = @splat(0.0);

// f16 SIMD types — 16-wide for 2× throughput vs f32 path
const VEC_F16_SIZE = 16;
const Vec16f16 = @Vector(16, f16);
const Vec16i8 = @Vector(16, i8);
const Vec16i16 = @Vector(16, i16);
const Vec16f32 = @Vector(16, f32);
const zero_vec_f16: Vec16f16 = @splat(@as(f16, 0.0));

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 1: PACKED TERNARY (2-bit encoding)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Encoding: 2 bits per weight → 16 weights per u32
//   00 = 0, 01 = +1, 11 = -1 (10 unused)
// Memory: 1.95M params × 2 bits = 488KB (vs 1.95MB for i8)
// Benefit: 4× less memory traffic, better cache utilization

pub const PackedTernary = struct {
    /// Packed weight data: 16 weights per u32, 2 bits each
    data: []const u32,
    /// Number of u32 words per row
    words_per_row: usize,
    /// Original dimensions
    in_dim: usize,
    out_dim: usize,

    /// Pack i8 ternary weights into 2-bit format.
    /// Caller owns returned slice.
    pub fn pack(allocator: std.mem.Allocator, weights: []const i8, in_dim: usize, out_dim: usize) !PackedTernary {
        const words_per_row = (out_dim + 15) / 16; // ceil(out_dim / 16)
        const total_words = in_dim * words_per_row;
        const data = try allocator.alloc(u32, total_words);

        for (0..in_dim) |i| {
            const row_base = i * out_dim;
            const word_base = i * words_per_row;
            for (0..words_per_row) |w| {
                var word: u32 = 0;
                for (0..16) |b| {
                    const j = w * 16 + b;
                    if (j >= out_dim) break;
                    const wt = weights[row_base + j];
                    const bits: u32 = switch (wt) {
                        1 => 0b01,
                        -1 => 0b11,
                        else => 0b00, // zero
                    };
                    word |= bits << @intCast(b * 2);
                }
                data[word_base + w] = word;
            }
        }

        return .{
            .data = data,
            .words_per_row = words_per_row,
            .in_dim = in_dim,
            .out_dim = out_dim,
        };
    }

    pub fn deinit(self: PackedTernary, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    /// Export packed weights as binary file for FPGA BRAM initialization.
    /// Format matches hslm_ternary_mac.v: 2 bits per weight, 16 per u32, row-major.
    /// Use with Xilinx $readmemh() or BRAM init.
    pub fn exportFpga(self: PackedTernary, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Write header comment
        var buf: [256]u8 = undefined;
        const hdr1 = std.fmt.bufPrint(&buf, "// HSLM weights: {d}x{d}, 2-bit packed, {d} words/row\n", .{
            self.in_dim, self.out_dim, self.words_per_row,
        }) catch unreachable;
        try file.writeAll(hdr1);
        try file.writeAll("// Encoding: 00=0, 01=+1, 11=-1 (matches hslm_ternary_mac.v)\n");

        // Write as hex (for $readmemh)
        for (self.data) |word| {
            var hex_buf: [16]u8 = undefined;
            const hex = std.fmt.bufPrint(&hex_buf, "{x:0>8}\n", .{word}) catch unreachable;
            try file.writeAll(hex);
        }
    }

    /// Memory savings vs i8
    pub fn memorySavings(self: PackedTernary) struct { i8_bytes: usize, packed_bytes: usize, ratio: f32 } {
        const i8_bytes = self.in_dim * self.out_dim;
        const packed_bytes = self.data.len * 4; // u32 = 4 bytes
        return .{
            .i8_bytes = i8_bytes,
            .packed_bytes = packed_bytes,
            .ratio = @as(f32, @floatFromInt(i8_bytes)) / @as(f32, @floatFromInt(packed_bytes)),
        };
    }

    /// Forward: y[j] = Sum_i W[i,j] * x[i]
    pub fn matvec(self: PackedTernary, input: []const f32, output: []f32) void {
        @memset(output[0..self.out_dim], 0.0);

        for (0..self.in_dim) |i| {
            const val = input[i];
            if (val == 0.0) continue;
            const word_base = i * self.words_per_row;

            for (0..self.words_per_row) |w| {
                var word = self.data[word_base + w];
                const j_base = w * 16;
                // Process 16 weights from one u32
                inline for (0..16) |b| {
                    const j = j_base + b;
                    if (j >= self.out_dim) break;
                    const bits: u2 = @truncate(word);
                    word >>= 2;
                    switch (bits) {
                        0b01 => output[j] += val, // +1
                        0b11 => output[j] -= val, // -1
                        else => {}, // 0
                    }
                }
            }
        }
    }

    /// Backward input gradient: g_in[i] = Sum_j W[i,j] * g_out[j]
    pub fn vecmat(self: PackedTernary, grad_output: []const f32, grad_input: []f32) void {
        for (0..self.in_dim) |i| {
            const word_base = i * self.words_per_row;
            var sum: f32 = 0.0;

            for (0..self.words_per_row) |w| {
                var word = self.data[word_base + w];
                const j_base = w * 16;
                inline for (0..16) |b| {
                    const j = j_base + b;
                    if (j >= self.out_dim) break;
                    const bits: u2 = @truncate(word);
                    word >>= 2;
                    switch (bits) {
                        0b01 => sum += grad_output[j],
                        0b11 => sum -= grad_output[j],
                        else => {},
                    }
                }
            }
            grad_input[i] = sum;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 2: SPARSE INDEX (CSR-style)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Separate arrays for positive (+1) and negative (-1) column indices.
// At ~33% sparsity each (typical ternary), stores only 2/3 of weights.
// Skip zeros entirely — pure add/subtract loops.
// CSR: row_offsets[i] → start of row i in col_indices array.

pub const SparseTernary = struct {
    /// Positive weights: column indices per row
    pos_indices: []const u32,
    /// Negative weights: column indices per row
    neg_indices: []const u32,
    /// Row offsets for positive (length = in_dim + 1)
    pos_row_offsets: []const u32,
    /// Row offsets for negative (length = in_dim + 1)
    neg_row_offsets: []const u32,
    in_dim: usize,
    out_dim: usize,

    /// Build CSR from i8 weights. Caller owns returned struct.
    pub fn build(allocator: std.mem.Allocator, weights: []const i8, in_dim: usize, out_dim: usize) !SparseTernary {
        // First pass: count non-zeros per row
        const pos_offsets = try allocator.alloc(u32, in_dim + 1);
        const neg_offsets = try allocator.alloc(u32, in_dim + 1);
        pos_offsets[0] = 0;
        neg_offsets[0] = 0;

        for (0..in_dim) |i| {
            var pc: u32 = 0;
            var nc: u32 = 0;
            const row = i * out_dim;
            for (0..out_dim) |j| {
                switch (weights[row + j]) {
                    1 => pc += 1,
                    -1 => nc += 1,
                    else => {},
                }
            }
            pos_offsets[i + 1] = pos_offsets[i] + pc;
            neg_offsets[i + 1] = neg_offsets[i] + nc;
        }

        const total_pos = pos_offsets[in_dim];
        const total_neg = neg_offsets[in_dim];
        const pos_idx = try allocator.alloc(u32, total_pos);
        const neg_idx = try allocator.alloc(u32, total_neg);

        // Second pass: fill indices
        var pi: u32 = 0;
        var ni: u32 = 0;
        for (0..in_dim) |i| {
            const row = i * out_dim;
            for (0..out_dim) |j| {
                switch (weights[row + j]) {
                    1 => {
                        pos_idx[pi] = @intCast(j);
                        pi += 1;
                    },
                    -1 => {
                        neg_idx[ni] = @intCast(j);
                        ni += 1;
                    },
                    else => {},
                }
            }
        }

        return .{
            .pos_indices = pos_idx,
            .neg_indices = neg_idx,
            .pos_row_offsets = pos_offsets,
            .neg_row_offsets = neg_offsets,
            .in_dim = in_dim,
            .out_dim = out_dim,
        };
    }

    pub fn deinit(self: SparseTernary, allocator: std.mem.Allocator) void {
        allocator.free(self.pos_indices);
        allocator.free(self.neg_indices);
        allocator.free(self.pos_row_offsets);
        allocator.free(self.neg_row_offsets);
    }

    /// Sparsity ratio: fraction of zero weights
    pub fn sparsity(self: SparseTernary) f32 {
        const total: f32 = @floatFromInt(self.in_dim * self.out_dim);
        const nnz: f32 = @floatFromInt(self.pos_indices.len + self.neg_indices.len);
        return 1.0 - nnz / total;
    }

    /// Forward: y[j] = Sum_i W[i,j] * x[i]
    pub fn matvec(self: SparseTernary, input: []const f32, output: []f32) void {
        @memset(output[0..self.out_dim], 0.0);

        for (0..self.in_dim) |i| {
            const val = input[i];
            if (val == 0.0) continue;

            // Add val to all positive columns
            const ps = self.pos_row_offsets[i];
            const pe = self.pos_row_offsets[i + 1];
            for (self.pos_indices[ps..pe]) |j| {
                output[j] += val;
            }

            // Subtract val from all negative columns
            const ns = self.neg_row_offsets[i];
            const ne = self.neg_row_offsets[i + 1];
            for (self.neg_indices[ns..ne]) |j| {
                output[j] -= val;
            }
        }
    }

    /// Backward input gradient: g_in[i] = Sum_j W[i,j] * g_out[j]
    pub fn vecmat(self: SparseTernary, grad_output: []const f32, grad_input: []f32) void {
        for (0..self.in_dim) |i| {
            var sum: f32 = 0.0;

            const ps = self.pos_row_offsets[i];
            const pe = self.pos_row_offsets[i + 1];
            for (self.pos_indices[ps..pe]) |j| {
                sum += grad_output[j];
            }

            const ns = self.neg_row_offsets[i];
            const ne = self.neg_row_offsets[i + 1];
            for (self.neg_indices[ns..ne]) |j| {
                sum -= grad_output[j];
            }

            grad_input[i] = sum;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 3: BRANCHLESS BIT-MANIPULATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Trick: split i8 weight into sign bit + nonzero mask.
//   nonzero = (w != 0) → 1.0 or 0.0
//   sign    = (w >= 0) → +1.0 or -1.0
//   result  = val * nonzero * sign
// No branches at all — pure arithmetic. Good for SIMD/GPU.
// Uses SIMD @Vector for the inner loop.

/// Branchless forward: y[j] = Sum_i W[i,j] * x[i]
/// Uses bit manipulation to avoid branches on weight values.
pub fn branchlessMatvec(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    @memset(output[0..out_dim], 0.0);

    for (0..in_dim) |i| {
        const val = input[i];
        if (val == 0.0) continue;
        const val_vec: Vec8 = @splat(val);
        const w_base = i * out_dim;

        var j: usize = 0;
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;

            // Branchless: convert i8 {-1,0,+1} to f32 via i16
            // This is already branchless — @floatFromInt doesn't branch
            // The key optimization is removing the switch/if in scalar code
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));

            var out_vec: Vec8 = output[j..][0..VEC_SIZE].*;
            out_vec += w_f32 * val_vec;
            output[j..][0..VEC_SIZE].* = out_vec;
        }
        // Scalar tail — also branchless
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            output[j] += w_f32 * val;
        }
    }
}

/// Branchless backward (accumulating): g_in[i] += Sum_j W[i,j] * g_out[j]
/// Same as branchlessVecmat but adds to grad_input instead of overwriting.
pub fn branchlessVecmatAccum(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        var acc0: Vec8 = zero_vec;
        var acc1: Vec8 = zero_vec;

        var j: usize = 0;
        while (j + 2 * VEC_SIZE <= out_dim) : (j += 2 * VEC_SIZE) {
            {
                const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
            }
            {
                const off = j + VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc1 += w_f32 * @as(Vec8, grad_output[off..][0..VEC_SIZE].*);
            }
        }
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
            acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
        }
        const merged = acc0 + acc1;
        var sum: f32 = @reduce(.Add, merged);
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            sum += w_f32 * grad_output[j];
        }
        grad_input[i] += sum;
    }
}

/// Branchless backward: g_in[i] = Sum_j W[i,j] * g_out[j]
pub fn branchlessVecmat(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        var acc0: Vec8 = zero_vec;
        var acc1: Vec8 = zero_vec;

        var j: usize = 0;
        while (j + 2 * VEC_SIZE <= out_dim) : (j += 2 * VEC_SIZE) {
            {
                const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
            }
            {
                const off = j + VEC_SIZE;
                const w_i8: Vec8i = weights[w_base + off ..][0..VEC_SIZE].*;
                const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
                acc1 += w_f32 * @as(Vec8, grad_output[off..][0..VEC_SIZE].*);
            }
        }
        while (j + VEC_SIZE <= out_dim) : (j += VEC_SIZE) {
            const w_i8: Vec8i = weights[w_base + j ..][0..VEC_SIZE].*;
            const w_f32: Vec8 = @floatFromInt(@as(Vec8i16, w_i8));
            acc0 += w_f32 * @as(Vec8, grad_output[j..][0..VEC_SIZE].*);
        }
        const merged = acc0 + acc1;
        var sum: f32 = @reduce(.Add, merged);
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            sum += w_f32 * grad_output[j];
        }
        grad_input[i] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 5: LUT MATMUL (no multiply, table lookup)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pre-compute {-val, 0, val} per input element, index by weight+1.
// Zero multiplications — pure addition from lookup table.

/// LUT forward: y[j] = Sum_i W[i,j] * x[i] via table lookup (no multiply)
pub fn lutMatvec(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    @memset(output[0..out_dim], 0.0);

    for (0..in_dim) |i| {
        const val = input[i];
        if (val == 0.0) continue;
        const lut = [_]f32{ -val, 0.0, val }; // index: weight+1
        const w_base = i * out_dim;

        for (0..out_dim) |j| {
            const w: usize = @intCast(@as(i16, weights[w_base + j]) + 1);
            output[j] += lut[w];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 4: NAIVE SWITCH (baseline reference)
// ═══════════════════════════════════════════════════════════════════════════════

/// Naive switch-based forward (baseline for benchmarking)
pub fn naiveMatvec(
    input: []const f32,
    weights: []const i8,
    output: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..out_dim) |j| {
        var sum: f32 = 0.0;
        for (0..in_dim) |i| {
            const w = weights[i * out_dim + j];
            switch (w) {
                1 => sum += input[i],
                -1 => sum -= input[i],
                else => {},
            }
        }
        output[j] = sum;
    }
}

/// Naive switch-based backward (baseline for benchmarking)
pub fn naiveVecmat(
    grad_output: []const f32,
    weights: []const i8,
    grad_input: []f32,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        var sum: f32 = 0.0;
        for (0..out_dim) |j| {
            const w = weights[i * out_dim + j];
            switch (w) {
                1 => sum += grad_output[j],
                -1 => sum -= grad_output[j],
                else => {},
            }
        }
        grad_input[i] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPARSITY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SparsityStats = struct {
    total: usize,
    zeros: usize,
    positives: usize,
    negatives: usize,

    pub fn sparsity(self: SparsityStats) f32 {
        return @as(f32, @floatFromInt(self.zeros)) / @as(f32, @floatFromInt(self.total));
    }

    pub fn print(self: SparsityStats) void {
        std.debug.print(
            \\  Weights: {d} total
            \\  +1: {d} ({d:.1}%)  -1: {d} ({d:.1}%)  0: {d} ({d:.1}%)
            \\  Sparsity: {d:.1}%
            \\
        , .{
            self.total,
            self.positives,
            @as(f32, @floatFromInt(self.positives)) / @as(f32, @floatFromInt(self.total)) * 100.0,
            self.negatives,
            @as(f32, @floatFromInt(self.negatives)) / @as(f32, @floatFromInt(self.total)) * 100.0,
            self.zeros,
            @as(f32, @floatFromInt(self.zeros)) / @as(f32, @floatFromInt(self.total)) * 100.0,
            self.sparsity() * 100.0,
        });
    }
};

pub fn analyzeSparsity(weights: []const i8) SparsityStats {
    var stats = SparsityStats{
        .total = weights.len,
        .zeros = 0,
        .positives = 0,
        .negatives = 0,
    };
    for (weights) |w| {
        switch (w) {
            1 => stats.positives += 1,
            -1 => stats.negatives += 1,
            else => stats.zeros += 1,
        }
    }
    return stats;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VARIANT 6: BRANCHLESS f16 SIMD (16-wide, 2× elements per register)
// ═══════════════════════════════════════════════════════════════════════════════
//
// f16 I/O with f32 compute internal. 16 elements per SIMD register vs 8 for f32.
// Input/output in f16 → @floatCast → f32 compute → @floatCast → f16 output.
// 2× memory bandwidth savings, same numerical accuracy for ternary ops.

/// Branchless f16 forward: y[j] = Sum_i W[i,j] * x[i]
/// Input/output in f16, compute in f32 internally via 16-wide SIMD.
pub fn branchlessMatvecF16(
    input: []const f16,
    weights: []const i8,
    output: []f16,
    in_dim: usize,
    out_dim: usize,
) void {
    // Zero output
    for (output[0..out_dim]) |*o| o.* = 0.0;

    for (0..in_dim) |i| {
        const val_f16 = input[i];
        if (val_f16 == 0.0) continue;
        const val_f32: f32 = @floatCast(val_f16);
        const val_vec: Vec16f32 = @splat(val_f32);
        const w_base = i * out_dim;

        var j: usize = 0;
        while (j + VEC_F16_SIZE <= out_dim) : (j += VEC_F16_SIZE) {
            const w_i8: Vec16i8 = weights[w_base + j ..][0..VEC_F16_SIZE].*;
            const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));

            // Read output as f16, convert to f32 for accumulation
            const out_f16: Vec16f16 = output[j..][0..VEC_F16_SIZE].*;
            var out_f32: Vec16f32 = @floatCast(out_f16);
            out_f32 += w_f32 * val_vec;
            const result_f16: Vec16f16 = @floatCast(out_f32);
            output[j..][0..VEC_F16_SIZE].* = @as([VEC_F16_SIZE]f16, result_f16);
        }
        // Scalar tail
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            const cur: f32 = @floatCast(output[j]);
            output[j] = @floatCast(cur + w_f32 * val_f32);
        }
    }
}

/// Branchless f16 backward: g_in[i] = Sum_j W[i,j] * g_out[j]
pub fn branchlessVecmatF16(
    grad_output: []const f16,
    weights: []const i8,
    grad_input: []f16,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        var acc0: Vec16f32 = @splat(@as(f32, 0.0));
        var acc1: Vec16f32 = @splat(@as(f32, 0.0));

        var j: usize = 0;
        while (j + 2 * VEC_F16_SIZE <= out_dim) : (j += 2 * VEC_F16_SIZE) {
            {
                const w_i8: Vec16i8 = weights[w_base + j ..][0..VEC_F16_SIZE].*;
                const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
                const g_f16: Vec16f16 = grad_output[j..][0..VEC_F16_SIZE].*;
                acc0 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
            }
            {
                const off = j + VEC_F16_SIZE;
                const w_i8: Vec16i8 = weights[w_base + off ..][0..VEC_F16_SIZE].*;
                const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
                const g_f16: Vec16f16 = grad_output[off..][0..VEC_F16_SIZE].*;
                acc1 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
            }
        }
        while (j + VEC_F16_SIZE <= out_dim) : (j += VEC_F16_SIZE) {
            const w_i8: Vec16i8 = weights[w_base + j ..][0..VEC_F16_SIZE].*;
            const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
            const g_f16: Vec16f16 = grad_output[j..][0..VEC_F16_SIZE].*;
            acc0 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
        }
        const merged = acc0 + acc1;
        var sum: f32 = @reduce(.Add, merged);
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            sum += w_f32 * @as(f32, @floatCast(grad_output[j]));
        }
        grad_input[i] = @floatCast(sum);
    }
}

/// Branchless f16 backward (accumulating): g_in[i] += Sum_j W[i,j] * g_out[j]
pub fn branchlessVecmatAccumF16(
    grad_output: []const f16,
    weights: []const i8,
    grad_input: []f16,
    in_dim: usize,
    out_dim: usize,
) void {
    for (0..in_dim) |i| {
        const w_base = i * out_dim;
        var acc0: Vec16f32 = @splat(@as(f32, 0.0));
        var acc1: Vec16f32 = @splat(@as(f32, 0.0));

        var j: usize = 0;
        while (j + 2 * VEC_F16_SIZE <= out_dim) : (j += 2 * VEC_F16_SIZE) {
            {
                const w_i8: Vec16i8 = weights[w_base + j ..][0..VEC_F16_SIZE].*;
                const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
                const g_f16: Vec16f16 = grad_output[j..][0..VEC_F16_SIZE].*;
                acc0 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
            }
            {
                const off = j + VEC_F16_SIZE;
                const w_i8: Vec16i8 = weights[w_base + off ..][0..VEC_F16_SIZE].*;
                const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
                const g_f16: Vec16f16 = grad_output[off..][0..VEC_F16_SIZE].*;
                acc1 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
            }
        }
        while (j + VEC_F16_SIZE <= out_dim) : (j += VEC_F16_SIZE) {
            const w_i8: Vec16i8 = weights[w_base + j ..][0..VEC_F16_SIZE].*;
            const w_f32: Vec16f32 = @floatFromInt(@as(Vec16i16, w_i8));
            const g_f16: Vec16f16 = grad_output[j..][0..VEC_F16_SIZE].*;
            acc0 += w_f32 * @as(Vec16f32, @floatCast(g_f16));
        }
        const merged = acc0 + acc1;
        var sum: f32 = @reduce(.Add, merged);
        while (j < out_dim) : (j += 1) {
            const w_f32: f32 = @floatFromInt(weights[w_base + j]);
            sum += w_f32 * @as(f32, @floatCast(grad_output[j]));
        }
        grad_input[i] = @floatCast(@as(f32, @floatCast(grad_input[i])) + sum);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — Correctness
// ═══════════════════════════════════════════════════════════════════════════════

const TOLERANCE: f32 = 1e-5;

fn approxEqual(a: f32, b: f32) bool {
    return @abs(a - b) < TOLERANCE;
}

fn fillRandom(buf: []f32, seed: u64, range: f32) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*v| {
        v.* = (random.float(f32) * 2.0 - 1.0) * range;
    }
}

fn fillTernaryWeights(buf: []i8, seed: u64) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*w| {
        w.* = random.intRangeAtMost(i8, -1, 1);
    }
}

/// Fill with controlled sparsity: p(zero) = sparsity_pct/100
fn fillTernaryWithSparsity(buf: []i8, seed: u64, sparsity_pct: u8) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*w| {
        if (random.intRangeAtMost(u8, 0, 99) < sparsity_pct) {
            w.* = 0;
        } else {
            w.* = if (random.boolean()) @as(i8, 1) else @as(i8, -1);
        }
    }
}

test "packed ternary matches naive — 243x243" {
    const in_dim = 243;
    const out_dim = 243;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_naive: [out_dim]f32 = undefined;
    var out_packed: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA101, 1.0);
    fillTernaryWeights(&weights, 0xB101);

    const pk = try PackedTernary.pack(std.testing.allocator, &weights, in_dim, out_dim);
    defer pk.deinit(std.testing.allocator);

    naiveMatvec(&input, &weights, &out_naive, in_dim, out_dim);
    pk.matvec(&input, &out_packed);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(out_naive[j], out_packed[j]));
    }
}

test "packed ternary vecmat matches naive — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_naive: [in_dim]f32 = undefined;
    var grad_packed: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC101, 1.0);
    fillTernaryWeights(&weights, 0xD101);

    const pk = try PackedTernary.pack(std.testing.allocator, &weights, in_dim, out_dim);
    defer pk.deinit(std.testing.allocator);

    naiveVecmat(&grad_output, &weights, &grad_naive, in_dim, out_dim);
    pk.vecmat(&grad_output, &grad_packed);

    for (0..in_dim) |i| {
        try std.testing.expect(approxEqual(grad_naive[i], grad_packed[i]));
    }
}

test "sparse index matches naive — 243x243" {
    const in_dim = 243;
    const out_dim = 243;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_naive: [out_dim]f32 = undefined;
    var out_sparse: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA201, 1.0);
    fillTernaryWeights(&weights, 0xB201);

    const sparse = try SparseTernary.build(std.testing.allocator, &weights, in_dim, out_dim);
    defer sparse.deinit(std.testing.allocator);

    naiveMatvec(&input, &weights, &out_naive, in_dim, out_dim);
    sparse.matvec(&input, &out_sparse);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(out_naive[j], out_sparse[j]));
    }
}

test "sparse index vecmat matches naive — 729x243" {
    const in_dim = 729;
    const out_dim = 243;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_naive: [in_dim]f32 = undefined;
    var grad_sparse: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC201, 1.0);
    fillTernaryWeights(&weights, 0xD201);

    const sparse = try SparseTernary.build(std.testing.allocator, &weights, in_dim, out_dim);
    defer sparse.deinit(std.testing.allocator);

    naiveVecmat(&grad_output, &weights, &grad_naive, in_dim, out_dim);
    sparse.vecmat(&grad_output, &grad_sparse);

    for (0..in_dim) |i| {
        try std.testing.expect(approxEqual(grad_naive[i], grad_sparse[i]));
    }
}

test "branchless matches naive — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_naive: [out_dim]f32 = undefined;
    var out_branchless: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA301, 1.0);
    fillTernaryWeights(&weights, 0xB301);

    naiveMatvec(&input, &weights, &out_naive, in_dim, out_dim);
    branchlessMatvec(&input, &weights, &out_branchless, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(out_naive[j], out_branchless[j]));
    }
}

test "branchless vecmat matches naive — 729x243" {
    const in_dim = 729;
    const out_dim = 243;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_naive: [in_dim]f32 = undefined;
    var grad_branchless: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC301, 1.0);
    fillTernaryWeights(&weights, 0xD301);

    naiveVecmat(&grad_output, &weights, &grad_naive, in_dim, out_dim);
    branchlessVecmat(&grad_output, &weights, &grad_branchless, in_dim, out_dim);

    for (0..in_dim) |i| {
        try std.testing.expect(approxEqual(grad_naive[i], grad_branchless[i]));
    }
}

test "branchless vecmat accum accumulates correctly" {
    const in_dim = 243;
    const out_dim = 729;
    var grad_output: [out_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var grad_naive: [in_dim]f32 = undefined;
    var grad_accum: [in_dim]f32 = undefined;

    fillRandom(&grad_output, 0xC401, 1.0);
    fillTernaryWeights(&weights, 0xD401);

    naiveVecmat(&grad_output, &weights, &grad_naive, in_dim, out_dim);

    // Pre-fill with 1.0, then accumulate — result should be naive + 1.0
    @memset(&grad_accum, 1.0);
    branchlessVecmatAccum(&grad_output, &weights, &grad_accum, in_dim, out_dim);

    for (0..in_dim) |i| {
        // Use relative tolerance for large values
        try std.testing.expectApproxEqAbs(grad_naive[i] + 1.0, grad_accum[i], 1e-3);
    }
}

test "lut matches naive — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_naive: [out_dim]f32 = undefined;
    var out_lut: [out_dim]f32 = undefined;

    fillRandom(&input, 0xA501, 1.0);
    fillTernaryWeights(&weights, 0xB501);

    naiveMatvec(&input, &weights, &out_naive, in_dim, out_dim);
    lutMatvec(&input, &weights, &out_lut, in_dim, out_dim);

    for (0..out_dim) |j| {
        try std.testing.expect(approxEqual(out_naive[j], out_lut[j]));
    }
}

test "sparsity analysis" {
    var weights: [1000]i8 = undefined;
    fillTernaryWithSparsity(&weights, 0x5001, 50);

    const stats = analyzeSparsity(&weights);
    // With 50% target sparsity, actual should be roughly 40-60%
    try std.testing.expect(stats.sparsity() > 0.3);
    try std.testing.expect(stats.sparsity() < 0.7);
    try std.testing.expect(stats.total == 1000);
    try std.testing.expect(stats.positives + stats.negatives + stats.zeros == 1000);
}

test "sparse index sparsity at 70%" {
    const in_dim = 64;
    const out_dim = 64;
    var weights: [in_dim * out_dim]i8 = undefined;
    fillTernaryWithSparsity(&weights, 0x5002, 70);

    const sparse = try SparseTernary.build(std.testing.allocator, &weights, in_dim, out_dim);
    defer sparse.deinit(std.testing.allocator);

    const sp = sparse.sparsity();
    try std.testing.expect(sp > 0.5);
    try std.testing.expect(sp < 0.9);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — f16 SIMD Correctness
// ═══════════════════════════════════════════════════════════════════════════════

fn fillRandomF16(buf: []f16, seed: u64, range: f32) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    for (buf) |*v| {
        v.* = @floatCast((random.float(f32) * 2.0 - 1.0) * range);
    }
}

test "f16 branchless matvec matches f32 — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    var input_f32: [in_dim]f32 = undefined;
    var input_f16: [in_dim]f16 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_f32: [out_dim]f32 = undefined;
    var out_f16: [out_dim]f16 = undefined;

    fillRandom(&input_f32, 0xF16A, 1.0);
    for (0..in_dim) |i| input_f16[i] = @floatCast(input_f32[i]);
    fillTernaryWeights(&weights, 0xF16B);

    branchlessMatvec(&input_f32, &weights, &out_f32, in_dim, out_dim);
    branchlessMatvecF16(&input_f16, &weights, &out_f16, in_dim, out_dim);

    for (0..out_dim) |j| {
        // f16 has lower precision, use wider tolerance
        try std.testing.expectApproxEqAbs(out_f32[j], @as(f32, @floatCast(out_f16[j])), 0.5);
    }
}

test "f16 branchless vecmat matches f32 — 729x243" {
    const in_dim = 729;
    const out_dim = 243;
    var grad_f32: [out_dim]f32 = undefined;
    var grad_f16: [out_dim]f16 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var out_f32: [in_dim]f32 = undefined;
    var out_f16: [in_dim]f16 = undefined;

    fillRandom(&grad_f32, 0xF16C, 1.0);
    for (0..out_dim) |i| grad_f16[i] = @floatCast(grad_f32[i]);
    fillTernaryWeights(&weights, 0xF16D);

    branchlessVecmat(&grad_f32, &weights, &out_f32, in_dim, out_dim);
    branchlessVecmatF16(&grad_f16, &weights, &out_f16, in_dim, out_dim);

    for (0..in_dim) |i| {
        try std.testing.expectApproxEqAbs(out_f32[i], @as(f32, @floatCast(out_f16[i])), 0.5);
    }
}

test "f16 branchless vecmat accum accumulates correctly" {
    const in_dim = 243;
    const out_dim = 729;
    var grad_f16: [out_dim]f16 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var result_f16: [in_dim]f16 = undefined;
    var base_f16: [in_dim]f16 = undefined;

    fillRandomF16(&grad_f16, 0xF16E, 1.0);
    fillTernaryWeights(&weights, 0xF16F);

    // Get base result
    branchlessVecmatF16(&grad_f16, &weights, &base_f16, in_dim, out_dim);

    // Accumulate on top of 1.0
    for (&result_f16) |*v| v.* = 1.0;
    branchlessVecmatAccumF16(&grad_f16, &weights, &result_f16, in_dim, out_dim);

    for (0..in_dim) |i| {
        const expected: f32 = @as(f32, @floatCast(base_f16[i])) + 1.0;
        try std.testing.expectApproxEqAbs(expected, @as(f32, @floatCast(result_f16[i])), 0.5);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

const simd_ops = @import("simd_ops.zig");

test "benchmark all variants — 243x729 forward (1000 iters)" {
    const in_dim = 243;
    const out_dim = 729;
    const ITERS = 1000;

    var input: [in_dim]f32 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output: [out_dim]f32 = undefined;

    fillRandom(&input, 0xBE01, 1.0);
    fillTernaryWeights(&weights, 0xCA01);

    // Analyze sparsity
    const stats = analyzeSparsity(&weights);

    // Build sparse structures
    const pk = try PackedTernary.pack(std.testing.allocator, &weights, in_dim, out_dim);
    defer pk.deinit(std.testing.allocator);
    const sparse = try SparseTernary.build(std.testing.allocator, &weights, in_dim, out_dim);
    defer sparse.deinit(std.testing.allocator);

    // 1. Naive (baseline)
    var t_naive = std.time.Timer.start() catch return;
    for (0..ITERS) |_| naiveMatvec(&input, &weights, &output, in_dim, out_dim);
    const ns_naive = t_naive.read();

    // 2. SIMD 4x (current production — simd_ops.zig)
    var t_simd = std.time.Timer.start() catch return;
    for (0..ITERS) |_| simd_ops.ternaryMatvecSimd(&input, &weights, &output, in_dim, out_dim);
    const ns_simd = t_simd.read();

    // 3. Packed ternary (2-bit)
    var t_packed = std.time.Timer.start() catch return;
    for (0..ITERS) |_| pk.matvec(&input, &output);
    const ns_packed = t_packed.read();

    // 4. Sparse index (CSR)
    var t_sparse = std.time.Timer.start() catch return;
    for (0..ITERS) |_| sparse.matvec(&input, &output);
    const ns_sparse = t_sparse.read();

    // 5. Branchless SIMD
    var t_branchless = std.time.Timer.start() catch return;
    for (0..ITERS) |_| branchlessMatvec(&input, &weights, &output, in_dim, out_dim);
    const ns_branchless = t_branchless.read();

    // 6. LUT (table lookup, no multiply)
    var t_lut = std.time.Timer.start() catch return;
    for (0..ITERS) |_| lutMatvec(&input, &weights, &output, in_dim, out_dim);
    const ns_lut = t_lut.read();

    const base = @as(f64, @floatFromInt(ns_naive));

    std.debug.print(
        \\
        \\  ═══════════════════════════════════════════════════════════════
        \\  SPARSE TERNARY MATMUL BENCHMARK — {d}×{d}, {d} iters
        \\  Sparsity: {d:.1}% zero, {d:.1}% +1, {d:.1}% -1
        \\  ═══════════════════════════════════════════════════════════════
        \\
        \\  Variant          |   Total µs  | µs/iter | Speedup
        \\  -----------------|-------------|---------|--------
        \\  1. Naive switch  | {d:>9} µs | {d:>5.1} µs | 1.00x (baseline)
        \\  2. SIMD 4x (cur) | {d:>9} µs | {d:>5.1} µs | {d:.2}x
        \\  3. Packed 2-bit  | {d:>9} µs | {d:>5.1} µs | {d:.2}x
        \\  4. Sparse CSR    | {d:>9} µs | {d:>5.1} µs | {d:.2}x
        \\  5. Branchless    | {d:>9} µs | {d:>5.1} µs | {d:.2}x
        \\  6. LUT (no mul)  | {d:>9} µs | {d:>5.1} µs | {d:.2}x
        \\
    , .{
        in_dim,                                                out_dim,                                                                                 ITERS,
        stats.sparsity() * 100.0,                              @as(f32, @floatFromInt(stats.positives)) / @as(f32, @floatFromInt(stats.total)) * 100.0, @as(f32, @floatFromInt(stats.negatives)) / @as(f32, @floatFromInt(stats.total)) * 100.0,
        // Naive
        ns_naive / 1000,                                       @as(f64, @floatFromInt(ns_naive / 1000)) / ITERS,
        // SIMD
                                               ns_simd / 1000,
        @as(f64, @floatFromInt(ns_simd / 1000)) / ITERS,       base / @as(f64, @floatFromInt(ns_simd)),
        // Packed
                                                        ns_packed / 1000,
        @as(f64, @floatFromInt(ns_packed / 1000)) / ITERS,     base / @as(f64, @floatFromInt(ns_packed)),
        // Sparse
                                                      ns_sparse / 1000,
        @as(f64, @floatFromInt(ns_sparse / 1000)) / ITERS,     base / @as(f64, @floatFromInt(ns_sparse)),
        // Branchless
                                                      ns_branchless / 1000,
        @as(f64, @floatFromInt(ns_branchless / 1000)) / ITERS, base / @as(f64, @floatFromInt(ns_branchless)),
        // LUT
                                                  ns_lut / 1000,
        @as(f64, @floatFromInt(ns_lut / 1000)) / ITERS,        base / @as(f64, @floatFromInt(ns_lut)),
    });
}

test "benchmark sparse at different sparsity levels — 243x729" {
    const in_dim = 243;
    const out_dim = 729;
    const ITERS = 500;

    var input: [in_dim]f32 = undefined;
    fillRandom(&input, 0xBE02, 1.0);

    std.debug.print(
        \\
        \\  ═══════════════════════════════════════════════════════════════
        \\  SPARSITY SWEEP — {d}×{d}, {d} iters
        \\  ═══════════════════════════════════════════════════════════════
        \\
        \\  Sparsity | Naive µs | SIMD µs | Sparse µs | Sparse speedup
        \\  ---------|----------|---------|-----------|---------------
        \\
    , .{ in_dim, out_dim, ITERS });

    for ([_]u8{ 0, 20, 33, 50, 70, 85, 95 }) |sparsity_pct| {
        var weights: [in_dim * out_dim]i8 = undefined;
        var output: [out_dim]f32 = undefined;
        fillTernaryWithSparsity(&weights, 0x5700 + @as(u64, sparsity_pct), sparsity_pct);

        const sparse = try SparseTernary.build(std.testing.allocator, &weights, in_dim, out_dim);
        defer sparse.deinit(std.testing.allocator);

        var t_naive = std.time.Timer.start() catch return;
        for (0..ITERS) |_| naiveMatvec(&input, &weights, &output, in_dim, out_dim);
        const ns_naive = t_naive.read();

        var t_simd = std.time.Timer.start() catch return;
        for (0..ITERS) |_| simd_ops.ternaryMatvecSimd(&input, &weights, &output, in_dim, out_dim);
        const ns_simd = t_simd.read();

        var t_sparse = std.time.Timer.start() catch return;
        for (0..ITERS) |_| sparse.matvec(&input, &output);
        const ns_sparse = t_sparse.read();

        std.debug.print(
            \\  {d:>6}%  | {d:>6} µs | {d:>5} µs | {d:>7} µs | {d:.2}x vs naive
            \\
        , .{
            sparsity_pct,
            ns_naive / 1000,
            ns_simd / 1000,
            ns_sparse / 1000,
            @as(f64, @floatFromInt(ns_naive)) / @as(f64, @floatFromInt(ns_sparse)),
        });
    }
}

test "benchmark f16 vs f32 branchless — 243x729 forward (1000 iters)" {
    const in_dim = 243;
    const out_dim = 729;
    const ITERS = 1000;

    var input_f32: [in_dim]f32 = undefined;
    var input_f16: [in_dim]f16 = undefined;
    var weights: [in_dim * out_dim]i8 = undefined;
    var output_f32: [out_dim]f32 = undefined;
    var output_f16: [out_dim]f16 = undefined;

    fillRandom(&input_f32, 0xF600, 1.0);
    for (0..in_dim) |i| input_f16[i] = @floatCast(input_f32[i]);
    fillTernaryWeights(&weights, 0xF601);

    // f32 branchless (8-wide)
    var t_f32 = std.time.Timer.start() catch return;
    for (0..ITERS) |_| branchlessMatvec(&input_f32, &weights, &output_f32, in_dim, out_dim);
    const ns_f32 = t_f32.read();

    // f16 branchless (16-wide)
    var t_f16 = std.time.Timer.start() catch return;
    for (0..ITERS) |_| branchlessMatvecF16(&input_f16, &weights, &output_f16, in_dim, out_dim);
    const ns_f16 = t_f16.read();

    const f32_mem = in_dim * 4 + out_dim * 4; // bytes
    const f16_mem = in_dim * 2 + out_dim * 2;

    std.debug.print(
        \\
        \\  ═══════════════════════════════════════════════════════════════
        \\  f16 vs f32 BRANCHLESS BENCHMARK — {d}×{d}, {d} iters
        \\  ═══════════════════════════════════════════════════════════════
        \\
        \\  Variant          |   Total µs  | µs/iter | Memory I/O
        \\  -----------------|-------------|---------|----------
        \\  f32 (8-wide)     | {d:>9} µs | {d:>5.1} µs | {d} bytes
        \\  f16 (16-wide)    | {d:>9} µs | {d:>5.1} µs | {d} bytes
        \\  Speedup: {d:.2}x, Memory savings: {d:.1}%
        \\
    , .{
        in_dim,
        out_dim,
        ITERS,
        ns_f32 / 1000,
        @as(f64, @floatFromInt(ns_f32 / 1000)) / ITERS,
        f32_mem,
        ns_f16 / 1000,
        @as(f64, @floatFromInt(ns_f16 / 1000)) / ITERS,
        f16_mem,
        @as(f64, @floatFromInt(ns_f32)) / @as(f64, @floatFromInt(ns_f16)),
        (1.0 - @as(f64, @floatFromInt(f16_mem)) / @as(f64, @floatFromInt(f32_mem))) * 100.0,
    });
}
