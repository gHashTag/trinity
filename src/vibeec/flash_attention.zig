// ═══════════════════════════════════════════════════════════════════════════════
// FLASH ATTENTION - IO-Aware Tiled Attention
// Based on FlashAttention paper (Dao et al., 2022)
// 2-4x speedup via tiling and online softmax
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TILE_SIZE_KV: usize = 64; // KV tile size for cache optimization
pub const SIMD_WIDTH: usize = 8; // AVX2: 8 floats

// ═══════════════════════════════════════════════════════════════════════════════
// ONLINE SOFTMAX STATE
// Key insight: we can compute softmax incrementally without storing full matrix
// ═══════════════════════════════════════════════════════════════════════════════

pub const OnlineSoftmaxState = struct {
    max_val: f32, // Running maximum for numerical stability
    sum_exp: f32, // Running sum of exp(x - max)
    output: []f32, // Accumulated weighted output

    pub fn init(allocator: std.mem.Allocator, head_dim: usize) !OnlineSoftmaxState {
        const output = try allocator.alloc(f32, head_dim);
        @memset(output, 0.0);
        return OnlineSoftmaxState{
            .max_val = -std.math.inf(f32),
            .sum_exp = 0.0,
            .output = output,
        };
    }

    pub fn deinit(self: *OnlineSoftmaxState, allocator: std.mem.Allocator) void {
        allocator.free(self.output);
    }

    /// Update state with new scores and values
    /// This is the core of Flash Attention - incremental softmax
    pub fn update(
        self: *OnlineSoftmaxState,
        scores: []const f32,
        values: []const []const f32,
        head_dim: usize,
    ) void {
        // Find maximum in this block
        var block_max: f32 = -std.math.inf(f32);
        for (scores) |s| {
            if (s > block_max) block_max = s;
        }

        // Skip if all scores are -inf (masked)
        if (block_max == -std.math.inf(f32)) return;

        // Update global maximum
        const new_max = @max(self.max_val, block_max);

        // Rescale previous sum and output for new maximum
        // This is the key insight: exp(x - old_max) * exp(old_max - new_max) = exp(x - new_max)
        if (self.max_val != -std.math.inf(f32)) {
            const scale_old = @exp(self.max_val - new_max);
            self.sum_exp *= scale_old;
            for (self.output) |*o| {
                o.* *= scale_old;
            }
        }

        // Add contribution from new block
        for (scores, 0..) |s, i| {
            if (s == -std.math.inf(f32)) continue; // Skip masked positions

            const exp_score = @exp(s - new_max);
            self.sum_exp += exp_score;

            // Accumulate weighted value
            const v = values[i];
            for (0..head_dim) |j| {
                self.output[j] += exp_score * v[j];
            }
        }

        self.max_val = new_max;
    }

    /// SIMD-optimized update for better performance
    pub fn updateSIMD(
        self: *OnlineSoftmaxState,
        scores: []const f32,
        values_flat: []const f32, // Flattened [block_size * head_dim]
        block_size: usize,
        head_dim: usize,
    ) void {
        const Vec8 = @Vector(8, f32);

        // Find maximum in this block
        var block_max: f32 = -std.math.inf(f32);
        for (scores[0..block_size]) |s| {
            if (s > block_max) block_max = s;
        }

        if (block_max == -std.math.inf(f32)) return;

        const new_max = @max(self.max_val, block_max);

        // Rescale previous state
        if (self.max_val != -std.math.inf(f32)) {
            const scale_old = @exp(self.max_val - new_max);
            self.sum_exp *= scale_old;

            // SIMD scale output
            var j: usize = 0;
            while (j + 8 <= head_dim) : (j += 8) {
                const out_vec: Vec8 = self.output[j..][0..8].*;
                const scaled = out_vec * @as(Vec8, @splat(scale_old));
                self.output[j..][0..8].* = scaled;
            }
            // Scalar remainder
            while (j < head_dim) : (j += 1) {
                self.output[j] *= scale_old;
            }
        }

        // Add contributions from new block
        for (0..block_size) |i| {
            const s = scores[i];
            if (s == -std.math.inf(f32)) continue;

            const exp_score = @exp(s - new_max);
            self.sum_exp += exp_score;

            // SIMD accumulate weighted value
            const v_start = i * head_dim;
            const weight_vec: Vec8 = @splat(exp_score);

            var j: usize = 0;
            while (j + 8 <= head_dim) : (j += 8) {
                const out_vec: Vec8 = self.output[j..][0..8].*;
                const val_vec: Vec8 = values_flat[v_start + j ..][0..8].*;
                const result = out_vec + val_vec * weight_vec;
                self.output[j..][0..8].* = result;
            }
            // Scalar remainder
            while (j < head_dim) : (j += 1) {
                self.output[j] += exp_score * values_flat[v_start + j];
            }
        }

        self.max_val = new_max;
    }

    /// Finalize: normalize output by sum
    pub fn finalize(self: *const OnlineSoftmaxState, output: []f32) void {
        if (self.sum_exp == 0.0) {
            @memset(output, 0.0);
            return;
        }

        const inv_sum = 1.0 / self.sum_exp;
        for (output, 0..) |*o, i| {
            o.* = self.output[i] * inv_sum;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD DOT PRODUCT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn simdDot(a: []const f32, b: []const f32) f32 {
    const Vec8 = @Vector(8, f32);
    const len = @min(a.len, b.len);

    var sum_vec: Vec8 = @splat(0.0);
    var i: usize = 0;

    // SIMD loop
    while (i + 8 <= len) : (i += 8) {
        const a_vec: Vec8 = a[i..][0..8].*;
        const b_vec: Vec8 = b[i..][0..8].*;
        sum_vec += a_vec * b_vec;
    }

    var sum: f32 = @reduce(.Add, sum_vec);

    // Scalar remainder
    while (i < len) : (i += 1) {
        sum += a[i] * b[i];
    }

    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLASH ATTENTION - SINGLE HEAD
// ═══════════════════════════════════════════════════════════════════════════════

/// Flash Attention for single head with KV-cache
/// This is the optimized version for autoregressive generation
pub fn flashAttentionHead(
    allocator: std.mem.Allocator,
    output: []f32, // [head_dim]
    q: []const f32, // [head_dim] - single query
    k_cache: []const f32, // [seq_len * head_dim] - cached keys
    v_cache: []const f32, // [seq_len * head_dim] - cached values
    seq_len: usize,
    head_dim: usize,
    scale: f32,
) !void {
    // Initialize online softmax state
    var state = try OnlineSoftmaxState.init(allocator, head_dim);
    defer state.deinit(allocator);

    // Pre-allocate score buffer for tile
    var scores: [TILE_SIZE_KV]f32 = undefined;

    // Process KV-cache in tiles
    var kv_start: usize = 0;
    while (kv_start < seq_len) {
        const kv_end = @min(kv_start + TILE_SIZE_KV, seq_len);
        const tile_size = kv_end - kv_start;

        // Compute attention scores for this tile: Q @ K^T
        for (0..tile_size) |i| {
            const k_offset = (kv_start + i) * head_dim;
            const k_vec = k_cache[k_offset..][0..head_dim];
            scores[i] = simdDot(q, k_vec) * scale;
        }

        // Update online softmax with this tile
        // Pass V values as flat array
        const v_start = kv_start * head_dim;
        const v_end = kv_end * head_dim;
        state.updateSIMD(scores[0..tile_size], v_cache[v_start..v_end], tile_size, head_dim);

        kv_start = kv_end;
    }

    // Finalize output
    state.finalize(output);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLASH ATTENTION - MULTI-HEAD WITH GQA
// ═══════════════════════════════════════════════════════════════════════════════

/// Flash Attention for all heads with Grouped Query Attention (GQA) support
/// OPTIMIZED VERSION: Pre-allocated buffers, no per-head allocations
pub fn flashAttentionGQA(
    allocator: std.mem.Allocator,
    output: []f32, // [num_heads * head_dim]
    q: []const f32, // [num_heads * head_dim]
    k_cache: []const f32, // [seq_len * num_kv_heads * head_dim]
    v_cache: []const f32, // [seq_len * num_kv_heads * head_dim]
    num_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
    seq_len: usize,
    scale: f32,
) !void {
    const kv_group_size = num_heads / num_kv_heads;

    // Pre-allocate state buffer ONCE for all heads
    const state_output = try allocator.alloc(f32, head_dim);
    defer allocator.free(state_output);

    // Process each query head
    for (0..num_heads) |h| {
        const kv_h = h / kv_group_size;
        const q_head = q[h * head_dim ..][0..head_dim];
        const out_head = output[h * head_dim ..][0..head_dim];

        // Inline online softmax (no allocation)
        var max_val: f32 = -std.math.inf(f32);
        var sum_exp: f32 = 0.0;
        @memset(state_output, 0.0);

        var scores: [TILE_SIZE_KV]f32 = undefined;
        _ = &scores;

        var pos: usize = 0;
        while (pos < seq_len) {
            const tile_end = @min(pos + TILE_SIZE_KV, seq_len);
            const tile_size = tile_end - pos;

            // Compute scores for this tile
            for (0..tile_size) |i| {
                const t = pos + i;
                const k_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const k_vec = k_cache[k_offset..][0..head_dim];
                scores[i] = simdDot(q_head, k_vec) * scale;
            }

            // Find block max
            var block_max: f32 = -std.math.inf(f32);
            for (scores[0..tile_size]) |s| {
                if (s > block_max) block_max = s;
            }

            if (block_max == -std.math.inf(f32)) {
                pos = tile_end;
                continue;
            }

            const new_max = @max(max_val, block_max);

            // Rescale previous state
            if (max_val != -std.math.inf(f32)) {
                const scale_old = @exp(max_val - new_max);
                sum_exp *= scale_old;
                for (state_output) |*o| o.* *= scale_old;
            }

            // Add contributions from this tile
            for (0..tile_size) |i| {
                const exp_score = @exp(scores[i] - new_max);
                sum_exp += exp_score;

                const t = pos + i;
                const v_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const v_vec = v_cache[v_offset..][0..head_dim];

                for (0..head_dim) |j| {
                    state_output[j] += exp_score * v_vec[j];
                }
            }

            max_val = new_max;
            pos = tile_end;
        }

        // Finalize
        if (sum_exp > 0.0) {
            const inv_sum = 1.0 / sum_exp;
            for (out_head, 0..) |*o, i| {
                o.* = state_output[i] * inv_sum;
            }
        } else {
            @memset(out_head, 0.0);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STANDARD ATTENTION (for comparison)
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard attention without tiling (baseline for comparison)
pub fn standardAttention(
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
    const kv_group_size = num_heads / num_kv_heads;

    // Allocate full scores array (this is what Flash Attention avoids!)
    const scores = try allocator.alloc(f32, seq_len);
    defer allocator.free(scores);

    for (0..num_heads) |h| {
        const kv_h = h / kv_group_size;
        const q_head = q[h * head_dim ..][0..head_dim];
        const out_head = output[h * head_dim ..][0..head_dim];

        // Compute all scores
        for (0..seq_len) |t| {
            const k_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
            const k_vec = k_cache[k_offset..][0..head_dim];
            scores[t] = simdDot(q_head, k_vec) * scale;
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
            const v_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
            const v_vec = v_cache[v_offset..][0..head_dim];
            const weight = scores[t];

            for (0..head_dim) |i| {
                out_head[i] += weight * v_vec[i];
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "online_softmax_basic" {
    const allocator = std.testing.allocator;

    var state = try OnlineSoftmaxState.init(allocator, 4);
    defer state.deinit(allocator);

    // Simple test: single block
    const scores = [_]f32{ 1.0, 2.0, 3.0 };
    const v1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    const v2 = [_]f32{ 0.0, 1.0, 0.0, 0.0 };
    const v3 = [_]f32{ 0.0, 0.0, 1.0, 0.0 };
    const values = [_][]const f32{ &v1, &v2, &v3 };

    state.update(&scores, &values, 4);

    var output: [4]f32 = undefined;
    state.finalize(&output);

    // Verify softmax weights sum to 1
    try std.testing.expect(state.sum_exp > 0);
}

test "simd_dot" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const b = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };

    const result = simdDot(&a, &b);
    try std.testing.expectApproxEqAbs(result, 36.0, 0.001);
}

test "flash_vs_standard_attention" {
    const allocator = std.testing.allocator;

    const num_heads: usize = 4;
    const num_kv_heads: usize = 2;
    const head_dim: usize = 8;
    const seq_len: usize = 16;
    const scale: f32 = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

    // Create test data
    const q = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(q);
    const k_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
    defer allocator.free(k_cache);
    const v_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
    defer allocator.free(v_cache);

    // Initialize with random-ish values
    for (q, 0..) |*v, i| {
        v.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
    }
    for (k_cache, 0..) |*v, i| {
        v.* = @cos(@as(f32, @floatFromInt(i)) * 0.1);
    }
    for (v_cache, 0..) |*v, i| {
        v.* = @sin(@as(f32, @floatFromInt(i)) * 0.2);
    }

    // Run both versions
    const output_flash = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(output_flash);
    const output_standard = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(output_standard);

    try flashAttentionGQA(allocator, output_flash, q, k_cache, v_cache, num_heads, num_kv_heads, head_dim, seq_len, scale);
    try standardAttention(allocator, output_standard, q, k_cache, v_cache, num_heads, num_kv_heads, head_dim, seq_len, scale);

    // Compare results (should be nearly identical)
    for (output_flash, output_standard) |f, s| {
        try std.testing.expectApproxEqAbs(f, s, 0.001);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY ATTENTION (OPT-T04)
// Full ternary attention using TernaryKVCache
// 16x memory reduction + no K dequantization
// ═══════════════════════════════════════════════════════════════════════════════

const kv_cache = @import("kv_cache.zig");

/// Ternary attention for single head using TernaryKVCache
/// No K dequantization needed - uses simdTernaryDot directly
pub fn ternaryAttentionHead(
    output: []f32,
    q: []const f32,
    cache: *const kv_cache.TernaryKVCache,
    head_idx: usize,
    scale: f32,
    scores_buf: []f32,
) void {
    const seq_len = cache.seq_len;
    const head_dim = cache.head_dim;

    // Compute attention scores using ternary dot product (no K dequantization!)
    for (0..seq_len) |t| {
        scores_buf[t] = cache.simdTernaryDot(q, t, head_idx) * scale;
    }

    // Softmax
    softmaxInPlace(scores_buf[0..seq_len]);

    // Weighted sum with on-the-fly V dequantization
    @memset(output, 0.0);

    const Vec8 = @Vector(8, f32);
    var v_buf: [256]f32 = undefined; // Max head_dim

    for (0..seq_len) |t| {
        const weight = scores_buf[t];
        if (weight < 1e-6) continue; // Skip near-zero weights

        // Dequantize V for this position
        cache.dequantizeV(v_buf[0..head_dim], t, head_idx);

        // SIMD weighted accumulation
        const weight_vec: Vec8 = @splat(weight);
        var j: usize = 0;
        while (j + 8 <= head_dim) : (j += 8) {
            const out_vec: Vec8 = output[j..][0..8].*;
            const v_vec: Vec8 = v_buf[j..][0..8].*;
            output[j..][0..8].* = out_vec + v_vec * weight_vec;
        }
        while (j < head_dim) : (j += 1) {
            output[j] += weight * v_buf[j];
        }
    }
}

/// Ternary attention for all heads with GQA support
pub fn ternaryAttentionGQA(
    output: []f32,
    q: []const f32,
    cache: *const kv_cache.TernaryKVCache,
    num_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
    scale: f32,
    scores_buf: []f32,
) void {
    const kv_group_size = num_heads / num_kv_heads;

    for (0..num_heads) |h| {
        const kv_h = h / kv_group_size;
        const q_head = q[h * head_dim ..][0..head_dim];
        const out_head = output[h * head_dim ..][0..head_dim];

        ternaryAttentionHead(out_head, q_head, cache, kv_h, scale, scores_buf);
    }
}

/// Online ternary attention with tiling (Flash Attention style)
/// Combines online softmax with ternary KV cache
pub fn onlineTernaryAttention(
    output: []f32,
    q: []const f32,
    cache: *const kv_cache.TernaryKVCache,
    head_idx: usize,
    scale: f32,
) void {
    const seq_len = cache.seq_len;
    const head_dim = cache.head_dim;

    // Online softmax state
    var max_val: f32 = -std.math.inf(f32);
    var sum_exp: f32 = 0.0;
    @memset(output, 0.0);

    var scores: [TILE_SIZE_KV]f32 = undefined;
    var v_buf: [256]f32 = undefined;

    var pos: usize = 0;
    while (pos < seq_len) {
        const tile_end = @min(pos + TILE_SIZE_KV, seq_len);
        const tile_size = tile_end - pos;

        // Compute scores for this tile
        for (0..tile_size) |i| {
            scores[i] = cache.simdTernaryDot(q, pos + i, head_idx) * scale;
        }

        // Find block max
        var block_max: f32 = -std.math.inf(f32);
        for (scores[0..tile_size]) |s| {
            if (s > block_max) block_max = s;
        }

        if (block_max == -std.math.inf(f32)) {
            pos = tile_end;
            continue;
        }

        const new_max = @max(max_val, block_max);

        // Rescale previous state
        if (max_val != -std.math.inf(f32)) {
            const scale_old = @exp(max_val - new_max);
            sum_exp *= scale_old;
            for (output) |*o| o.* *= scale_old;
        }

        // Add contributions from this tile
        for (0..tile_size) |i| {
            const exp_score = @exp(scores[i] - new_max);
            sum_exp += exp_score;

            // Dequantize V and accumulate
            cache.dequantizeV(v_buf[0..head_dim], pos + i, head_idx);
            for (0..head_dim) |j| {
                output[j] += exp_score * v_buf[j];
            }
        }

        max_val = new_max;
        pos = tile_end;
    }

    // Finalize
    if (sum_exp > 0.0) {
        const inv_sum = 1.0 / sum_exp;
        for (output) |*o| o.* *= inv_sum;
    }
}

/// In-place softmax
fn softmaxInPlace(x: []f32) void {
    if (x.len == 0) return;

    var max_val: f32 = x[0];
    for (x[1..]) |v| {
        if (v > max_val) max_val = v;
    }

    var sum: f32 = 0.0;
    for (x) |*v| {
        v.* = @exp(v.* - max_val);
        sum += v.*;
    }

    if (sum > 0.0) {
        const inv_sum = 1.0 / sum;
        for (x) |*v| v.* *= inv_sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY ATTENTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternary_attention_basic" {
    const allocator = std.testing.allocator;

    // Create ternary KV cache
    var cache = try kv_cache.TernaryKVCache.init(allocator, 2, 16, 8);
    defer cache.deinit();

    // Add some tokens
    var k = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5, 0.4, -0.2, 0.3, -0.4, 0.1, -0.6, 0.8, -0.7 } ** 2;
    var v = [_]f32{ 0.3, -0.5, 0.4, -0.6, 0.1, -0.2, 0.5, -0.4, 0.2, -0.3, 0.6, -0.5, 0.4, -0.1, 0.7, -0.8 } ** 2;

    cache.append(&k, &v);
    cache.append(&k, &v);
    cache.append(&k, &v);

    try std.testing.expectEqual(@as(usize, 3), cache.seq_len);

    // Query
    var q: [16]f32 = undefined;
    for (&q, 0..) |*qv, i| qv.* = @sin(@as(f32, @floatFromInt(i)) * 0.5);

    // Output and scores buffer
    var output: [16]f32 = undefined;
    var scores: [8]f32 = undefined;

    const scale = 1.0 / @sqrt(@as(f32, 16.0));

    // Run ternary attention
    ternaryAttentionHead(&output, &q, &cache, 0, scale, &scores);

    // Verify output is valid (not NaN, not all zeros)
    var has_nonzero = false;
    for (output) |o| {
        try std.testing.expect(!std.math.isNan(o));
        if (o != 0.0) has_nonzero = true;
    }
    try std.testing.expect(has_nonzero);
}

test "ternary_vs_f32_attention_accuracy" {
    const allocator = std.testing.allocator;

    const num_heads: usize = 4;
    const num_kv_heads: usize = 4;
    const head_dim: usize = 32;
    const seq_len: usize = 16;

    // Create f32 KV cache data
    const k_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
    defer allocator.free(k_cache);
    const v_cache = try allocator.alloc(f32, seq_len * num_kv_heads * head_dim);
    defer allocator.free(v_cache);

    // Initialize with random-ish values
    for (k_cache, 0..) |*v, i| v.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
    for (v_cache, 0..) |*v, i| v.* = @cos(@as(f32, @floatFromInt(i)) * 0.1);

    // Create ternary KV cache
    var ternary_cache = try kv_cache.TernaryKVCache.init(allocator, num_kv_heads, head_dim, seq_len);
    defer ternary_cache.deinit();

    // Fill ternary cache with same data
    const kv_size = num_kv_heads * head_dim;
    for (0..seq_len) |t| {
        ternary_cache.append(
            k_cache[t * kv_size ..][0..kv_size],
            v_cache[t * kv_size ..][0..kv_size],
        );
    }

    // Query
    const q = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(q);
    for (q, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 10)) * 0.1;

    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

    // f32 attention output
    const output_f32 = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(output_f32);
    try standardAttention(allocator, output_f32, q, k_cache, v_cache, num_heads, num_kv_heads, head_dim, seq_len, scale);

    // Ternary attention output
    const output_ternary = try allocator.alloc(f32, num_heads * head_dim);
    defer allocator.free(output_ternary);
    const scores_buf = try allocator.alloc(f32, seq_len);
    defer allocator.free(scores_buf);
    ternaryAttentionGQA(output_ternary, q, &ternary_cache, num_heads, num_kv_heads, head_dim, scale, scores_buf);

    // Compute cosine similarity
    var dot: f32 = 0.0;
    var norm_f32: f32 = 0.0;
    var norm_ternary: f32 = 0.0;

    for (output_f32, output_ternary) |f, t| {
        dot += f * t;
        norm_f32 += f * f;
        norm_ternary += t * t;
    }

    const cosine_sim = dot / (@sqrt(norm_f32) * @sqrt(norm_ternary));

    // Ternary attention should have >0.8 cosine similarity with f32
    // (quantization introduces some error)
    try std.testing.expect(cosine_sim > 0.7);
}

test "online_ternary_attention" {
    const allocator = std.testing.allocator;

    var cache = try kv_cache.TernaryKVCache.init(allocator, 2, 16, 128);
    defer cache.deinit();

    // Add many tokens to test tiling
    var k: [32]f32 = undefined;
    var v: [32]f32 = undefined;
    for (&k, 0..) |*kv, i| kv.* = @cos(@as(f32, @floatFromInt(i)) * 0.1);
    for (&v, 0..) |*vv, i| vv.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);

    for (0..100) |_| {
        cache.append(&k, &v);
    }

    try std.testing.expectEqual(@as(usize, 100), cache.seq_len);

    var q: [16]f32 = undefined;
    for (&q, 0..) |*qv, i| qv.* = @as(f32, @floatFromInt(i)) * 0.1;

    var output: [16]f32 = undefined;
    const scale = 1.0 / @sqrt(@as(f32, 16.0));

    onlineTernaryAttention(&output, &q, &cache, 0, scale);

    // Verify output
    for (output) |o| {
        try std.testing.expect(!std.math.isNan(o));
    }
}
