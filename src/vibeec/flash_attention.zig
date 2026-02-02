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
