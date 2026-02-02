// GGUF TRANSFORMER - Full Transformer Layer Implementation
// RoPE + Multi-Head Attention + SwiGLU FFN
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const inference = @import("gguf_inference.zig");
const kv_cache_mod = @import("kv_cache.zig");

// Re-export optimized KV cache types
pub const RingKVCache = kv_cache_mod.RingKVCache;
pub const SlidingWindowConfig = kv_cache_mod.SlidingWindowConfig;
pub const CacheStats = kv_cache_mod.CacheStats;

// Re-export ternary KV cache (OPT-T03)
pub const TernaryKVCache = kv_cache_mod.TernaryKVCache;
pub const TernaryCacheStats = kv_cache_mod.TernaryCacheStats;

// ═══════════════════════════════════════════════════════════════════════════════
// RoPE - Rotary Position Embedding
// ═══════════════════════════════════════════════════════════════════════════════

pub const RoPE = struct {
    cos_cache: []f32,
    sin_cache: []f32,
    head_dim: usize,
    max_seq_len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, head_dim: usize, max_seq_len: usize, theta: f32) !RoPE {
        const cache_size = max_seq_len * head_dim;
        const cos_cache = try allocator.alloc(f32, cache_size);
        const sin_cache = try allocator.alloc(f32, cache_size);

        // Precompute cos/sin for all positions
        for (0..max_seq_len) |pos| {
            for (0..head_dim / 2) |i| {
                const freq = 1.0 / std.math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
                const angle = @as(f32, @floatFromInt(pos)) * freq;
                const idx = pos * head_dim + i * 2;
                cos_cache[idx] = @cos(angle);
                cos_cache[idx + 1] = @cos(angle);
                sin_cache[idx] = @sin(angle);
                sin_cache[idx + 1] = @sin(angle);
            }
        }

        return RoPE{
            .cos_cache = cos_cache,
            .sin_cache = sin_cache,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RoPE) void {
        self.allocator.free(self.cos_cache);
        self.allocator.free(self.sin_cache);
    }

    // Apply RoPE to query/key vectors
    pub fn apply(self: *const RoPE, x: []f32, pos: usize) void {
        if (pos >= self.max_seq_len) return;

        const cache_offset = pos * self.head_dim;
        var i: usize = 0;
        while (i < self.head_dim) : (i += 2) {
            const x0 = x[i];
            const x1 = x[i + 1];
            const cos_val = self.cos_cache[cache_offset + i];
            const sin_val = self.sin_cache[cache_offset + i];

            x[i] = x0 * cos_val - x1 * sin_val;
            x[i + 1] = x0 * sin_val + x1 * cos_val;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KV-Cache for efficient autoregressive generation
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCache = struct {
    k_cache: []f32, // [max_seq_len, num_kv_heads, head_dim]
    v_cache: []f32,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,
    seq_len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_kv_heads: usize, head_dim: usize, max_seq_len: usize) !KVCache {
        const cache_size = max_seq_len * num_kv_heads * head_dim;
        return KVCache{
            .k_cache = try allocator.alloc(f32, cache_size),
            .v_cache = try allocator.alloc(f32, cache_size),
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .seq_len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }

    pub fn append(self: *KVCache, k: []const f32, v: []const f32) void {
        if (self.seq_len >= self.max_seq_len) return;

        const offset = self.seq_len * self.num_kv_heads * self.head_dim;
        const size = self.num_kv_heads * self.head_dim;
        @memcpy(self.k_cache[offset..][0..size], k[0..size]);
        @memcpy(self.v_cache[offset..][0..size], v[0..size]);
        self.seq_len += 1;
    }

    pub fn reset(self: *KVCache) void {
        self.seq_len = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Multi-Head Attention with Grouped Query Attention (GQA)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Attention = struct {
    allocator: std.mem.Allocator,
    num_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
    hidden_size: usize,

    // Weights (dequantized)
    wq: []f32, // [hidden_size, num_heads * head_dim]
    wk: []f32, // [hidden_size, num_kv_heads * head_dim]
    wv: []f32, // [hidden_size, num_kv_heads * head_dim]
    wo: []f32, // [num_heads * head_dim, hidden_size]

    pub fn forward(
        self: *const Attention,
        output: []f32,
        input: []const f32,
        kv_cache: *KVCache,
        rope: *const RoPE,
        pos: usize,
    ) !void {
        const allocator = self.allocator;

        // Allocate temporary buffers
        const q = try allocator.alloc(f32, self.num_heads * self.head_dim);
        defer allocator.free(q);
        const k = try allocator.alloc(f32, self.num_kv_heads * self.head_dim);
        defer allocator.free(k);
        const v = try allocator.alloc(f32, self.num_kv_heads * self.head_dim);
        defer allocator.free(v);

        // Q = input @ Wq
        inference.matVec(q, self.wq, input, self.num_heads * self.head_dim, self.hidden_size);
        // K = input @ Wk
        inference.matVec(k, self.wk, input, self.num_kv_heads * self.head_dim, self.hidden_size);
        // V = input @ Wv
        inference.matVec(v, self.wv, input, self.num_kv_heads * self.head_dim, self.hidden_size);

        // Apply RoPE to Q and K
        for (0..self.num_heads) |h| {
            rope.apply(q[h * self.head_dim ..][0..self.head_dim], pos);
        }
        for (0..self.num_kv_heads) |h| {
            rope.apply(k[h * self.head_dim ..][0..self.head_dim], pos);
        }

        // Update KV cache
        kv_cache.append(k, v);

        // Compute attention for each head
        const attn_out = try allocator.alloc(f32, self.num_heads * self.head_dim);
        defer allocator.free(attn_out);

        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(self.head_dim)));
        const kv_group_size = self.num_heads / self.num_kv_heads;

        for (0..self.num_heads) |h| {
            const kv_h = h / kv_group_size; // GQA: multiple Q heads share same KV head
            const q_head = q[h * self.head_dim ..][0..self.head_dim];

            // Compute attention scores for all cached positions
            const scores = try allocator.alloc(f32, kv_cache.seq_len);
            defer allocator.free(scores);

            for (0..kv_cache.seq_len) |t| {
                const k_offset = t * self.num_kv_heads * self.head_dim + kv_h * self.head_dim;
                const k_vec = kv_cache.k_cache[k_offset..][0..self.head_dim];

                var dot: f32 = 0.0;
                for (0..self.head_dim) |i| {
                    dot += q_head[i] * k_vec[i];
                }
                scores[t] = dot * scale;
            }

            // Softmax
            inference.softmax(scores, scores);

            // Weighted sum of values
            const out_head = attn_out[h * self.head_dim ..][0..self.head_dim];
            @memset(out_head, 0.0);

            for (0..kv_cache.seq_len) |t| {
                const v_offset = t * self.num_kv_heads * self.head_dim + kv_h * self.head_dim;
                const v_vec = kv_cache.v_cache[v_offset..][0..self.head_dim];
                const score = scores[t];

                for (0..self.head_dim) |i| {
                    out_head[i] += score * v_vec[i];
                }
            }
        }

        // Output projection: output = attn_out @ Wo
        inference.matVec(output, self.wo, attn_out, self.hidden_size, self.num_heads * self.head_dim);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Feed-Forward Network with SwiGLU activation
// ═══════════════════════════════════════════════════════════════════════════════

pub const FFN = struct {
    allocator: std.mem.Allocator,
    hidden_size: usize,
    intermediate_size: usize,

    // Weights
    w_gate: []f32, // [hidden_size, intermediate_size]
    w_up: []f32, // [hidden_size, intermediate_size]
    w_down: []f32, // [intermediate_size, hidden_size]

    pub fn forward(self: *const FFN, output: []f32, input: []const f32) !void {
        const allocator = self.allocator;

        // gate = input @ w_gate
        const gate = try allocator.alloc(f32, self.intermediate_size);
        defer allocator.free(gate);
        inference.matVec(gate, self.w_gate, input, self.intermediate_size, self.hidden_size);

        // up = input @ w_up
        const up = try allocator.alloc(f32, self.intermediate_size);
        defer allocator.free(up);
        inference.matVec(up, self.w_up, input, self.intermediate_size, self.hidden_size);

        // SwiGLU: hidden = silu(gate) * up
        for (0..self.intermediate_size) |i| {
            gate[i] = inference.silu(gate[i]) * up[i];
        }

        // output = hidden @ w_down
        inference.matVec(output, self.w_down, gate, self.hidden_size, self.intermediate_size);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Transformer Block = Attention + FFN with residual connections
// ═══════════════════════════════════════════════════════════════════════════════

pub const TransformerBlock = struct {
    allocator: std.mem.Allocator,
    hidden_size: usize,

    // Components
    attention: Attention,
    ffn: FFN,

    // Normalization weights
    attn_norm: []f32,
    ffn_norm: []f32,
    rms_eps: f32,

    pub fn forward(
        self: *const TransformerBlock,
        output: []f32,
        input: []const f32,
        kv_cache: *KVCache,
        rope: *const RoPE,
        pos: usize,
    ) !void {
        const allocator = self.allocator;

        // Pre-attention RMS norm
        const normed = try allocator.alloc(f32, self.hidden_size);
        defer allocator.free(normed);
        inference.rmsNorm(normed, input, self.attn_norm, self.rms_eps);

        // Attention
        const attn_out = try allocator.alloc(f32, self.hidden_size);
        defer allocator.free(attn_out);
        try self.attention.forward(attn_out, normed, kv_cache, rope, pos);

        // Residual connection
        for (0..self.hidden_size) |i| {
            output[i] = input[i] + attn_out[i];
        }

        // Pre-FFN RMS norm
        inference.rmsNorm(normed, output, self.ffn_norm, self.rms_eps);

        // FFN
        const ffn_out = try allocator.alloc(f32, self.hidden_size);
        defer allocator.free(ffn_out);
        try self.ffn.forward(ffn_out, normed);

        // Residual connection
        for (0..self.hidden_size) |i| {
            output[i] += ffn_out[i];
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "rope_init" {
    const allocator = std.testing.allocator;
    var rope = try RoPE.init(allocator, 64, 128, 10000.0);
    defer rope.deinit();

    try std.testing.expectEqual(rope.head_dim, 64);
    try std.testing.expectEqual(rope.max_seq_len, 128);
}

test "rope_apply" {
    const allocator = std.testing.allocator;
    var rope = try RoPE.init(allocator, 4, 10, 10000.0);
    defer rope.deinit();

    var x = [_]f32{ 1.0, 0.0, 1.0, 0.0 };
    rope.apply(&x, 0);

    // At position 0, cos=1, sin=0, so x should be unchanged
    try std.testing.expectApproxEqAbs(x[0], 1.0, 0.01);
    try std.testing.expectApproxEqAbs(x[1], 0.0, 0.01);
}

test "kv_cache" {
    const allocator = std.testing.allocator;
    var cache = try KVCache.init(allocator, 4, 64, 128);
    defer cache.deinit();

    var k = [_]f32{1.0} ** 256;
    var v = [_]f32{2.0} ** 256;

    cache.append(&k, &v);
    try std.testing.expectEqual(cache.seq_len, 1);

    cache.append(&k, &v);
    try std.testing.expectEqual(cache.seq_len, 2);

    cache.reset();
    try std.testing.expectEqual(cache.seq_len, 0);
}
