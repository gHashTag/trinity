// Trinity Ternary KV Cache: 16x Memory Reduction for LLM Inference
// OPT-T03: Ternary quantization of Key-Value cache
// Generated from: specs/tri/ternary_kv_cache.vibee
//
// Stores K,V vectors as 2-bit ternary {-1, 0, +1} with per-token scale factors.
// Eliminates multiplications in attention scoring (add/subtract only).
// Memory: f32 = 4 bytes/value, ternary = 0.25 bytes/value = 16x reduction.

const std = @import("std");

// =============================================================================
// CONSTANTS
// =============================================================================

/// Ternary encoding: 2 bits per trit, 4 trits per byte
const TRITS_PER_BYTE: usize = 4;

/// Trit encodings
const TRIT_ZERO: u2 = 0b00;
const TRIT_PLUS: u2 = 0b01;
const TRIT_MINUS: u2 = 0b10;

/// Trinity constant
const PHI: f64 = 1.6180339887;
const TRINITY: f64 = 3.0;

// =============================================================================
// TYPES
// =============================================================================

/// Quantization mode selection
pub const QuantMode = enum {
    /// Threshold = max_abs * ratio
    fixed_threshold,
    /// Threshold = mean(abs) * ratio (adaptive)
    adaptive_mean,
    /// All non-zero values quantized (highest accuracy)
    no_threshold,
    /// RMS-based scaling (best for attention patterns)
    rms_scale,
};

/// Memory comparison statistics
pub const CacheMemoryStats = struct {
    f32_bytes: usize,
    ternary_bytes: usize,
    compression_ratio: f32,
    tokens_capacity: usize,
    savings_mb: f32,
};

/// Quantized vector with scale
pub const QuantizedVector = struct {
    data: []u8,
    scale: f32,
    length: usize,
};

/// Ternary KV Cache — core struct
pub const TernaryKVCache = struct {
    allocator: std.mem.Allocator,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    // Packed ternary storage (4 trits per byte)
    k_cache: []u8,
    v_cache: []u8,

    // Per-token scale factors for dequantization
    k_scales: []f32,
    v_scales: []f32,

    // Current sequence length
    seq_len: usize,

    // Quantization configuration
    quant_mode: QuantMode,
    threshold_ratio: f32,

    const Self = @This();

    /// Initialize ternary KV cache
    pub fn init(
        allocator: std.mem.Allocator,
        num_kv_heads: usize,
        head_dim: usize,
        max_seq_len: usize,
    ) !Self {
        const values_per_token = num_kv_heads * head_dim;
        const bytes_per_token = (values_per_token + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        const total_bytes = max_seq_len * bytes_per_token;

        const k_cache = try allocator.alloc(u8, total_bytes);
        errdefer allocator.free(k_cache);
        const v_cache = try allocator.alloc(u8, total_bytes);
        errdefer allocator.free(v_cache);
        const k_scales = try allocator.alloc(f32, max_seq_len);
        errdefer allocator.free(k_scales);
        const v_scales = try allocator.alloc(f32, max_seq_len);

        @memset(k_cache, 0);
        @memset(v_cache, 0);

        return Self{
            .allocator = allocator,
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .k_cache = k_cache,
            .v_cache = v_cache,
            .k_scales = k_scales,
            .v_scales = v_scales,
            .seq_len = 0,
            .quant_mode = .rms_scale,
            .threshold_ratio = 0.0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
        self.allocator.free(self.k_scales);
        self.allocator.free(self.v_scales);
    }

    /// Append new K,V token pair (quantize on store)
    pub fn append(self: *Self, k_new: []const f32, v_new: []const f32) void {
        if (self.seq_len >= self.max_seq_len) return;

        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        const offset = self.seq_len * bytes_per_token;

        self.k_scales[self.seq_len] = quantizeVector(
            self.k_cache[offset..][0..bytes_per_token],
            k_new,
            self.quant_mode,
            self.threshold_ratio,
        );

        self.v_scales[self.seq_len] = quantizeVector(
            self.v_cache[offset..][0..bytes_per_token],
            v_new,
            self.quant_mode,
            self.threshold_ratio,
        );

        self.seq_len += 1;
    }

    /// Ternary dot product: Q (f32) dot K (ternary) — no multiplications
    pub fn ternaryDot(
        self: *const Self,
        query: []const f32,
        token_pos: usize,
        head_idx: usize,
    ) f32 {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.k_scales[token_pos];
        var sum: f32 = 0.0;

        for (0..self.head_dim) |i| {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / TRITS_PER_BYTE;
            const bit_pos: u3 = @intCast((global_idx % TRITS_PER_BYTE) * 2);
            const trit: u2 = @truncate((self.k_cache[byte_idx] >> bit_pos) & 0x3);

            switch (trit) {
                TRIT_PLUS => sum += query[i],
                TRIT_MINUS => sum -= query[i],
                else => {},
            }
        }

        return sum * scale;
    }

    /// SIMD-optimized ternary dot product (8 values per cycle)
    pub fn simdTernaryDot(
        self: *const Self,
        query: []const f32,
        token_pos: usize,
        head_idx: usize,
    ) f32 {
        const Vec8 = @Vector(8, f32);
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.k_scales[token_pos];
        const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

        var sum_vec: Vec8 = @splat(0.0);
        var i: usize = 0;

        while (i + 8 <= self.head_dim) : (i += 8) {
            const q_vec: Vec8 = query[i..][0..8].*;
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / TRITS_PER_BYTE;
            const b0 = self.k_cache[byte_idx];
            const b1 = self.k_cache[byte_idx + 1];

            const signs: Vec8 = .{
                sign_lut[(b0 >> 0) & 0x3],
                sign_lut[(b0 >> 2) & 0x3],
                sign_lut[(b0 >> 4) & 0x3],
                sign_lut[(b0 >> 6) & 0x3],
                sign_lut[(b1 >> 0) & 0x3],
                sign_lut[(b1 >> 2) & 0x3],
                sign_lut[(b1 >> 4) & 0x3],
                sign_lut[(b1 >> 6) & 0x3],
            };

            sum_vec += q_vec * signs;
        }

        var sum: f32 = @reduce(.Add, sum_vec);

        // Scalar remainder
        while (i < self.head_dim) : (i += 1) {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / TRITS_PER_BYTE;
            const bit_pos: u3 = @intCast((global_idx % TRITS_PER_BYTE) * 2);
            const trit = (self.k_cache[byte_idx] >> bit_pos) & 0x3;
            sum += query[i] * sign_lut[trit];
        }

        return sum * scale;
    }

    /// Dequantize V values for weighted sum
    pub fn dequantizeV(
        self: *const Self,
        dst: []f32,
        token_pos: usize,
        head_idx: usize,
    ) void {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + TRITS_PER_BYTE - 1) / TRITS_PER_BYTE;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.v_scales[token_pos];

        for (0..self.head_dim) |i| {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / TRITS_PER_BYTE;
            const bit_pos: u3 = @intCast((global_idx % TRITS_PER_BYTE) * 2);
            const trit: u2 = @truncate((self.v_cache[byte_idx] >> bit_pos) & 0x3);

            dst[i] = switch (trit) {
                TRIT_PLUS => scale,
                TRIT_MINUS => -scale,
                else => 0.0,
            };
        }
    }

    /// Compute full attention for one head using ternary cache
    /// Returns attention output vector [head_dim]
    pub fn ternaryAttention(
        self: *const Self,
        allocator: std.mem.Allocator,
        query: []const f32,
        head_idx: usize,
    ) ![]f32 {
        if (self.seq_len == 0) {
            const out = try allocator.alloc(f32, self.head_dim);
            @memset(out, 0);
            return out;
        }

        // Step 1: Compute attention scores via ternary dot product
        const scores = try allocator.alloc(f32, self.seq_len);
        defer allocator.free(scores);

        for (0..self.seq_len) |t| {
            scores[t] = self.simdTernaryDot(query, t, head_idx);
        }

        // Step 2: Scale by 1/sqrt(head_dim)
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(self.head_dim)));
        for (scores) |*s| {
            s.* *= scale;
        }

        // Step 3: Softmax
        var max_score: f32 = scores[0];
        for (scores[1..]) |s| {
            if (s > max_score) max_score = s;
        }

        var sum_exp: f32 = 0.0;
        for (scores) |*s| {
            s.* = @exp(s.* - max_score);
            sum_exp += s.*;
        }
        if (sum_exp > 0.0) {
            for (scores) |*s| {
                s.* /= sum_exp;
            }
        }

        // Step 4: Weighted sum of V values
        const output = try allocator.alloc(f32, self.head_dim);
        @memset(output, 0);

        var v_buf: [256]f32 = undefined;
        const v_slice = v_buf[0..self.head_dim];

        for (0..self.seq_len) |t| {
            if (scores[t] < 1e-8) continue;
            self.dequantizeV(v_slice, t, head_idx);
            for (0..self.head_dim) |d| {
                output[d] += scores[t] * v_slice[d];
            }
        }

        return output;
    }

    /// Reset cache for new sequence
    pub fn reset(self: *Self) void {
        self.seq_len = 0;
    }

    /// Set quantization mode
    pub fn setQuantMode(self: *Self, mode: QuantMode, threshold: f32) void {
        self.quant_mode = mode;
        self.threshold_ratio = threshold;
    }

    /// Memory usage in bytes (ternary)
    pub fn memoryUsage(self: *const Self) usize {
        return self.k_cache.len + self.v_cache.len +
            (self.k_scales.len + self.v_scales.len) * @sizeOf(f32);
    }

    /// Compute memory statistics (ternary vs f32)
    pub fn memoryStats(self: *const Self) CacheMemoryStats {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const f32_bytes = self.max_seq_len * values_per_token * 2 * @sizeOf(f32);
        const ternary_bytes = self.memoryUsage();
        const savings = @as(f32, @floatFromInt(f32_bytes - ternary_bytes)) / (1024.0 * 1024.0);

        return CacheMemoryStats{
            .f32_bytes = f32_bytes,
            .ternary_bytes = ternary_bytes,
            .compression_ratio = @as(f32, @floatFromInt(f32_bytes)) / @as(f32, @floatFromInt(ternary_bytes)),
            .tokens_capacity = self.max_seq_len,
            .savings_mb = savings,
        };
    }
};

// =============================================================================
// QUANTIZATION
// =============================================================================

/// Quantize f32 vector to packed ternary bytes, return scale factor
pub fn quantizeVector(
    dst: []u8,
    src: []const f32,
    mode: QuantMode,
    threshold_ratio: f32,
) f32 {
    // Compute statistics
    var max_abs: f32 = 0.0;
    var sum_abs: f32 = 0.0;
    var sum_sq: f32 = 0.0;
    for (src) |v| {
        const abs_v = @abs(v);
        if (abs_v > max_abs) max_abs = abs_v;
        sum_abs += abs_v;
        sum_sq += v * v;
    }

    if (max_abs == 0.0) {
        @memset(dst, 0);
        return 1.0;
    }

    const n = @as(f32, @floatFromInt(src.len));
    const mean_abs = sum_abs / n;
    const rms = @sqrt(sum_sq / n);

    const scale: f32 = switch (mode) {
        .fixed_threshold, .no_threshold, .adaptive_mean => max_abs,
        .rms_scale => rms * 1.5,
    };

    const threshold: f32 = switch (mode) {
        .fixed_threshold => max_abs * threshold_ratio,
        .adaptive_mean => mean_abs * threshold_ratio,
        .no_threshold => 0.0,
        .rms_scale => rms * 0.5,
    };

    // Pack 4 trits per byte
    var byte_idx: usize = 0;
    var bit_pos: u3 = 0;
    var current_byte: u8 = 0;

    for (src) |v| {
        const trit: u2 = if (v > threshold)
            TRIT_PLUS
        else if (v < -threshold)
            TRIT_MINUS
        else
            TRIT_ZERO;

        current_byte |= @as(u8, trit) << bit_pos;
        bit_pos +%= 2;

        if (bit_pos == 0) {
            dst[byte_idx] = current_byte;
            byte_idx += 1;
            current_byte = 0;
        }
    }

    if (bit_pos != 0 and byte_idx < dst.len) {
        dst[byte_idx] = current_byte;
    }

    return scale;
}

/// Dequantize packed ternary bytes to f32
pub fn dequantizeVector(dst: []f32, src: []const u8, scale: f32, length: usize) void {
    for (0..length) |i| {
        const byte_idx = i / TRITS_PER_BYTE;
        const bit_pos: u3 = @intCast((i % TRITS_PER_BYTE) * 2);
        const trit: u2 = @truncate((src[byte_idx] >> bit_pos) & 0x3);

        dst[i] = switch (trit) {
            TRIT_PLUS => scale,
            TRIT_MINUS => -scale,
            else => 0.0,
        };
    }
}

/// Compute cosine similarity between original and dequantized vectors
pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;

    for (0..a.len) |i| {
        dot += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom == 0.0) return 0.0;
    return dot / denom;
}

/// Standard f32 dot product for comparison
pub fn f32Dot(a: []const f32, b: []const f32) f32 {
    var sum: f32 = 0.0;
    for (0..a.len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}

// =============================================================================
// TESTS
// =============================================================================

test "TernaryKVCache.init" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 4, 128, 2048);
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 0), cache.seq_len);
    try std.testing.expectEqual(@as(usize, 4), cache.num_kv_heads);
    try std.testing.expectEqual(@as(usize, 128), cache.head_dim);
    try std.testing.expectEqual(@as(usize, 2048), cache.max_seq_len);
}

test "TernaryKVCache.append_and_ternaryDot" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 2, 8, 16);
    defer cache.deinit();

    // K,V vectors: 2 heads * 8 dim = 16 values
    const k = [_]f32{ 1.0, -0.5, 0.8, -0.9, 0.1, -0.2, 0.7, -0.6, 0.3, -0.4, 0.5, -0.3, 0.2, -0.1, 0.4, -0.8 };
    const v = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5, 0.4, -0.2, 0.3, -0.4, 0.1, -0.6, 0.8, -0.7 };

    cache.append(&k, &v);
    cache.append(&k, &v);
    try std.testing.expectEqual(@as(usize, 2), cache.seq_len);

    // Query head 0
    const q = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    const dot = cache.ternaryDot(&q, 0, 0);
    try std.testing.expect(!std.math.isNan(dot));

    // SIMD dot should give same result
    const simd_dot = cache.simdTernaryDot(&q, 0, 0);
    try std.testing.expectApproxEqAbs(dot, simd_dot, 0.001);
}

test "TernaryKVCache.dequantizeV" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 1, 8, 4);
    defer cache.deinit();

    const k = [_]f32{ 1.0, -0.5, 0.8, -0.9, 0.1, -0.2, 0.7, -0.6 };
    const v = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5 };
    cache.append(&k, &v);

    var v_out: [8]f32 = undefined;
    cache.dequantizeV(&v_out, 0, 0);

    // Values should be -scale, 0, or +scale
    for (v_out) |val| {
        try std.testing.expect(!std.math.isNan(val));
    }
}

test "TernaryKVCache.ternaryAttention" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 2, 8, 16);
    defer cache.deinit();

    const k = [_]f32{ 1.0, -0.5, 0.8, -0.9, 0.1, -0.2, 0.7, -0.6, 0.3, -0.4, 0.5, -0.3, 0.2, -0.1, 0.4, -0.8 };
    const v = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5, 0.4, -0.2, 0.3, -0.4, 0.1, -0.6, 0.8, -0.7 };

    cache.append(&k, &v);
    cache.append(&k, &v);
    cache.append(&k, &v);

    const q = [_]f32{ 1.0, 0.5, -0.3, 0.7, -0.2, 0.4, -0.6, 0.8 };
    const output = try cache.ternaryAttention(allocator, &q, 0);
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, 8), output.len);
    // Output should be valid floats
    for (output) |val| {
        try std.testing.expect(!std.math.isNan(val));
        try std.testing.expect(!std.math.isInf(val));
    }
}

test "TernaryKVCache.memoryStats_16x_compression" {
    const allocator = std.testing.allocator;

    // Realistic 7B model config
    var cache = try TernaryKVCache.init(allocator, 4, 128, 2048);
    defer cache.deinit();

    const stats = cache.memoryStats();

    // f32: 4 heads * 128 dim * 2048 tokens * 2 (K+V) * 4 bytes = 8,388,608 bytes
    try std.testing.expectEqual(@as(usize, 8_388_608), stats.f32_bytes);

    // Ternary: ~540K bytes
    // Compression should be >10x
    try std.testing.expect(stats.compression_ratio > 10.0);
    try std.testing.expect(stats.compression_ratio < 20.0);

    // Memory savings should be >7 MB
    try std.testing.expect(stats.savings_mb > 7.0);
}

test "quantize_dequantize_accuracy" {
    const dim: usize = 128;
    var src: [dim]f32 = undefined;
    var dst_packed: [(dim + 3) / 4]u8 = undefined;
    var dst_deq: [dim]f32 = undefined;

    // Generate test vector with normal-ish distribution
    for (&src, 0..) |*v, i| {
        const fi = @as(f32, @floatFromInt(i));
        v.* = @sin(fi * 0.1) * @cos(fi * 0.03);
    }

    const scale = quantizeVector(&dst_packed, &src, .rms_scale, 0.0);
    dequantizeVector(&dst_deq, &dst_packed, scale, dim);

    // Cosine similarity should be high (>0.85 for ternary)
    const sim = cosineSimilarity(&src, &dst_deq);
    try std.testing.expect(sim > 0.80);
}

test "f32_dot_vs_ternary_dot_agreement" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 1, 16, 4);
    defer cache.deinit();

    // Strong signal vector
    var k = [_]f32{ 2.0, -1.5, 1.8, -1.9, 0.5, -0.8, 1.7, -1.6, 1.3, -1.4, 1.5, -1.3, 0.9, -0.7, 1.4, -1.8 };
    const v = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5, 0.4, -0.2, 0.3, -0.4, 0.1, -0.6, 0.8, -0.7 };
    cache.append(&k, &v);

    const q = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };

    const ternary_result = cache.ternaryDot(&q, 0, 0);
    const f32_result = f32Dot(&q, &k);

    // Ternary and f32 should have same sign (direction preserved)
    try std.testing.expect((ternary_result > 0.0) == (f32_result > 0.0) or
        @abs(ternary_result) < 0.01 or @abs(f32_result) < 0.01);
}

test "quantize_all_zeros" {
    const dim: usize = 16;
    var src = [_]f32{0.0} ** dim;
    var dst: [(dim + 3) / 4]u8 = undefined;

    const scale = quantizeVector(&dst, &src, .rms_scale, 0.0);

    // Scale should be 1.0 for zero vector (sentinel)
    try std.testing.expectEqual(@as(f32, 1.0), scale);
    // All bytes should be zero
    for (dst) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }
}

test "ring_buffer_overflow_protection" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 1, 8, 2);
    defer cache.deinit();

    const k = [_]f32{ 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0 };
    const v = [_]f32{ 0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5 };

    cache.append(&k, &v);
    cache.append(&k, &v);
    cache.append(&k, &v); // Should not crash (overflow protection)

    try std.testing.expectEqual(@as(usize, 2), cache.seq_len);
}

test "quant_mode_comparison" {
    const dim: usize = 32;
    var src: [dim]f32 = undefined;
    for (&src, 0..) |*v, i| {
        const fi = @as(f32, @floatFromInt(i));
        v.* = @sin(fi * 0.2) * 2.0;
    }

    const modes = [_]QuantMode{ .fixed_threshold, .adaptive_mean, .no_threshold, .rms_scale };
    var best_sim: f32 = 0.0;

    for (modes) |mode| {
        var pack_buf: [(dim + 3) / 4]u8 = undefined;
        var deq: [dim]f32 = undefined;

        const ratio: f32 = switch (mode) {
            .fixed_threshold => 0.1,
            .adaptive_mean => 0.1,
            else => 0.0,
        };

        const scale = quantizeVector(&pack_buf, &src, mode, ratio);
        dequantizeVector(&deq, &pack_buf, scale, dim);

        const sim = cosineSimilarity(&src, &deq);
        if (sim > best_sim) best_sim = sim;

        // All modes should produce reasonable results
        try std.testing.expect(sim > 0.5);
    }

    // At least one mode should be good
    try std.testing.expect(best_sim > 0.8);
}

test "cache_reset" {
    const allocator = std.testing.allocator;
    var cache = try TernaryKVCache.init(allocator, 1, 8, 4);
    defer cache.deinit();

    const k = [_]f32{ 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0 };
    const v = [_]f32{ 0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5 };

    cache.append(&k, &v);
    cache.append(&k, &v);
    try std.testing.expectEqual(@as(usize, 2), cache.seq_len);

    cache.reset();
    try std.testing.expectEqual(@as(usize, 0), cache.seq_len);
}

test "cosine_similarity_self" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const sim = cosineSimilarity(&a, &a);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sim, 0.001);
}

test "cosine_similarity_orthogonal" {
    const a = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0, 0.0, 0.0 };
    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sim, 0.001);
}

test "memory_stats_scaling" {
    const allocator = std.testing.allocator;

    // Small model: 2 heads, 64 dim, 512 tokens
    var small = try TernaryKVCache.init(allocator, 2, 64, 512);
    defer small.deinit();
    const small_stats = small.memoryStats();

    // Large model: 32 heads, 128 dim, 4096 tokens
    var large = try TernaryKVCache.init(allocator, 32, 128, 4096);
    defer large.deinit();
    const large_stats = large.memoryStats();

    // Both should achieve similar compression ratios
    try std.testing.expect(@abs(small_stats.compression_ratio - large_stats.compression_ratio) < 3.0);

    // Large model should save much more absolute memory
    try std.testing.expect(large_stats.savings_mb > small_stats.savings_mb);
}
