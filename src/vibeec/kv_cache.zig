// KV-CACHE - Key-Value Cache for Autoregressive Generation
// Кэширование K,V тензоров для ускорения генерации
// Без KV-cache: O(N²) операций, с KV-cache: O(N) операций
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const simd = @import("simd_trit_ops.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// KV-CACHE CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCacheConfig = struct {
    num_layers: usize,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    pub fn cacheSize(self: *const KVCacheConfig) usize {
        // Per layer: 2 (K + V) * num_kv_heads * max_seq_len * head_dim
        return 2 * self.num_kv_heads * self.max_seq_len * self.head_dim;
    }

    pub fn totalSize(self: *const KVCacheConfig) usize {
        return self.num_layers * self.cacheSize();
    }

    /// Qwen2.5-Coder-7B config
    pub fn qwen7b() KVCacheConfig {
        return KVCacheConfig{
            .num_layers = 28,
            .num_kv_heads = 4,
            .head_dim = 128, // 3584 / 28 = 128
            .max_seq_len = 2048, // Reasonable default
        };
    }

    /// Mistral-7B config
    pub fn mistral7b() KVCacheConfig {
        return KVCacheConfig{
            .num_layers = 32,
            .num_kv_heads = 8,
            .head_dim = 128, // 4096 / 32 = 128
            .max_seq_len = 2048,
        };
    }

    /// Mini config for testing
    pub fn mini() KVCacheConfig {
        return KVCacheConfig{
            .num_layers = 2,
            .num_kv_heads = 2,
            .head_dim = 16,
            .max_seq_len = 64,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER KV-CACHE
// ═══════════════════════════════════════════════════════════════════════════════

/// KV-cache for a single transformer layer
pub const LayerKVCache = struct {
    allocator: std.mem.Allocator,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    // Cache storage: [num_kv_heads][max_seq_len][head_dim]
    k_cache: []f32,
    v_cache: []f32,

    // Current sequence length (number of cached tokens)
    seq_len: usize,

    pub fn init(allocator: std.mem.Allocator, config: KVCacheConfig) !LayerKVCache {
        const cache_size = config.num_kv_heads * config.max_seq_len * config.head_dim;

        const k_cache = try allocator.alloc(f32, cache_size);
        @memset(k_cache, 0.0);

        const v_cache = try allocator.alloc(f32, cache_size);
        @memset(v_cache, 0.0);

        return LayerKVCache{
            .allocator = allocator,
            .num_kv_heads = config.num_kv_heads,
            .head_dim = config.head_dim,
            .max_seq_len = config.max_seq_len,
            .k_cache = k_cache,
            .v_cache = v_cache,
            .seq_len = 0,
        };
    }

    pub fn deinit(self: *LayerKVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }

    /// Reset cache (start new sequence)
    pub fn reset(self: *LayerKVCache) void {
        self.seq_len = 0;
    }

    /// Append new K,V vectors for current token
    /// k_new, v_new: [num_kv_heads * head_dim]
    pub fn append(self: *LayerKVCache, k_new: []const f32, v_new: []const f32) !void {
        if (self.seq_len >= self.max_seq_len) {
            return error.CacheFull;
        }

        const kv_size = self.num_kv_heads * self.head_dim;
        if (k_new.len != kv_size or v_new.len != kv_size) {
            return error.InvalidSize;
        }

        // Copy to cache at position seq_len
        for (0..self.num_kv_heads) |h| {
            const head_offset = h * self.max_seq_len * self.head_dim;
            const pos_offset = self.seq_len * self.head_dim;
            const src_offset = h * self.head_dim;

            @memcpy(
                self.k_cache[head_offset + pos_offset ..][0..self.head_dim],
                k_new[src_offset..][0..self.head_dim],
            );
            @memcpy(
                self.v_cache[head_offset + pos_offset ..][0..self.head_dim],
                v_new[src_offset..][0..self.head_dim],
            );
        }

        self.seq_len += 1;
    }

    /// Get cached K for a specific head: [seq_len][head_dim]
    pub fn getK(self: *const LayerKVCache, head_idx: usize) []const f32 {
        const head_offset = head_idx * self.max_seq_len * self.head_dim;
        return self.k_cache[head_offset..][0 .. self.seq_len * self.head_dim];
    }

    /// Get cached V for a specific head: [seq_len][head_dim]
    pub fn getV(self: *const LayerKVCache, head_idx: usize) []const f32 {
        const head_offset = head_idx * self.max_seq_len * self.head_dim;
        return self.v_cache[head_offset..][0 .. self.seq_len * self.head_dim];
    }

    /// Memory usage in bytes
    pub fn memoryUsage(self: *const LayerKVCache) usize {
        return (self.k_cache.len + self.v_cache.len) * @sizeOf(f32);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FULL MODEL KV-CACHE
// ═══════════════════════════════════════════════════════════════════════════════

/// KV-cache for entire model (all layers)
pub const KVCache = struct {
    allocator: std.mem.Allocator,
    config: KVCacheConfig,
    layers: []LayerKVCache,

    pub fn init(allocator: std.mem.Allocator, config: KVCacheConfig) !KVCache {
        const layers = try allocator.alloc(LayerKVCache, config.num_layers);

        for (layers) |*layer| {
            layer.* = try LayerKVCache.init(allocator, config);
        }

        return KVCache{
            .allocator = allocator,
            .config = config,
            .layers = layers,
        };
    }

    pub fn deinit(self: *KVCache) void {
        for (self.layers) |*layer| {
            layer.deinit();
        }
        self.allocator.free(self.layers);
    }

    /// Reset all layers (start new sequence)
    pub fn reset(self: *KVCache) void {
        for (self.layers) |*layer| {
            layer.reset();
        }
    }

    /// Get layer cache
    pub fn getLayer(self: *KVCache, layer_idx: usize) *LayerKVCache {
        return &self.layers[layer_idx];
    }

    /// Current sequence length
    pub fn seqLen(self: *const KVCache) usize {
        if (self.layers.len == 0) return 0;
        return self.layers[0].seq_len;
    }

    /// Total memory usage in bytes
    pub fn memoryUsage(self: *const KVCache) usize {
        var total: usize = 0;
        for (self.layers) |*layer| {
            total += layer.memoryUsage();
        }
        return total;
    }

    /// Print cache info
    pub fn printInfo(self: *const KVCache) void {
        const mem_mb = @as(f64, @floatFromInt(self.memoryUsage())) / (1024.0 * 1024.0);

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           KV-CACHE INFO                                      ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Layers:           {d:>10}                               ║\n", .{self.config.num_layers});
        std.debug.print("║ KV heads:         {d:>10}                               ║\n", .{self.config.num_kv_heads});
        std.debug.print("║ Head dim:         {d:>10}                               ║\n", .{self.config.head_dim});
        std.debug.print("║ Max seq len:      {d:>10}                               ║\n", .{self.config.max_seq_len});
        std.debug.print("║ Current seq len:  {d:>10}                               ║\n", .{self.seqLen()});
        std.debug.print("║ Memory usage:     {d:>10.2} MB                           ║\n", .{mem_mb});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CACHED ATTENTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute attention with KV-cache
/// q: [num_heads * head_dim] - query for current token only
/// layer_cache: KV-cache for this layer
/// Returns: [num_heads * head_dim] - attention output
pub fn cachedAttention(
    allocator: std.mem.Allocator,
    q: []const f32,
    layer_cache: *const LayerKVCache,
    num_q_heads: usize,
    num_kv_heads: usize,
    head_dim: usize,
) ![]f32 {
    const seq_len = layer_cache.seq_len;
    if (seq_len == 0) {
        return error.EmptyCache;
    }

    const output = try allocator.alloc(f32, num_q_heads * head_dim);
    @memset(output, 0.0);

    // GQA: each KV head serves multiple Q heads
    const q_per_kv = num_q_heads / num_kv_heads;

    // For each Q head
    for (0..num_q_heads) |q_head| {
        const kv_head = q_head / q_per_kv;
        const q_offset = q_head * head_dim;
        const out_offset = q_head * head_dim;

        // Get cached K, V for this KV head
        const k_cached = layer_cache.getK(kv_head);
        const v_cached = layer_cache.getV(kv_head);

        // Compute attention scores: Q @ K^T
        const scores = try allocator.alloc(f32, seq_len);
        defer allocator.free(scores);

        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

        for (0..seq_len) |pos| {
            var dot: f32 = 0.0;
            const k_offset = pos * head_dim;

            // Dot product Q[q_head] @ K[pos]
            for (0..head_dim) |d| {
                dot += q[q_offset + d] * k_cached[k_offset + d];
            }

            scores[pos] = dot * scale;
        }

        // Softmax
        var max_score: f32 = scores[0];
        for (scores[1..]) |s| {
            if (s > max_score) max_score = s;
        }

        var sum_exp: f32 = 0.0;
        for (scores) |*s| {
            s.* = @exp(s.* - max_score);
            sum_exp += s.*;
        }

        for (scores) |*s| {
            s.* /= sum_exp;
        }

        // Weighted sum of V
        for (0..seq_len) |pos| {
            const v_offset = pos * head_dim;
            const weight = scores[pos];

            for (0..head_dim) |d| {
                output[out_offset + d] += weight * v_cached[v_offset + d];
            }
        }
    }

    return output;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "kv cache config" {
    const config = KVCacheConfig.qwen7b();
    try std.testing.expectEqual(@as(usize, 28), config.num_layers);
    try std.testing.expectEqual(@as(usize, 4), config.num_kv_heads);

    // Cache size per layer: 2 * 4 * 2048 * 128 * 4 bytes = 8MB
    const size_per_layer = config.cacheSize() * @sizeOf(f32);
    try std.testing.expect(size_per_layer > 0);
}

test "layer kv cache" {
    const allocator = std.testing.allocator;
    const config = KVCacheConfig.mini();

    var cache = try LayerKVCache.init(allocator, config);
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 0), cache.seq_len);

    // Append first token
    const kv_size = config.num_kv_heads * config.head_dim;
    const k1 = try allocator.alloc(f32, kv_size);
    defer allocator.free(k1);
    const v1 = try allocator.alloc(f32, kv_size);
    defer allocator.free(v1);

    for (k1) |*x| x.* = 1.0;
    for (v1) |*x| x.* = 2.0;

    try cache.append(k1, v1);
    try std.testing.expectEqual(@as(usize, 1), cache.seq_len);

    // Append second token
    for (k1) |*x| x.* = 3.0;
    for (v1) |*x| x.* = 4.0;

    try cache.append(k1, v1);
    try std.testing.expectEqual(@as(usize, 2), cache.seq_len);

    // Check cached values
    const k_head0 = cache.getK(0);
    try std.testing.expectEqual(@as(usize, 2 * config.head_dim), k_head0.len);
}

test "full kv cache" {
    const allocator = std.testing.allocator;
    const config = KVCacheConfig.mini();

    var cache = try KVCache.init(allocator, config);
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 2), cache.layers.len);
    try std.testing.expectEqual(@as(usize, 0), cache.seqLen());

    cache.reset();
    try std.testing.expectEqual(@as(usize, 0), cache.seqLen());
}

test "cached attention" {
    const allocator = std.testing.allocator;
    const config = KVCacheConfig.mini();

    var layer_cache = try LayerKVCache.init(allocator, config);
    defer layer_cache.deinit();

    const kv_size = config.num_kv_heads * config.head_dim;

    // Add some cached K, V
    const k = try allocator.alloc(f32, kv_size);
    defer allocator.free(k);
    const v = try allocator.alloc(f32, kv_size);
    defer allocator.free(v);

    for (k, 0..) |*x, i| x.* = @as(f32, @floatFromInt(i)) * 0.1;
    for (v, 0..) |*x, i| x.* = @as(f32, @floatFromInt(i)) * 0.2;

    try layer_cache.append(k, v);
    try layer_cache.append(k, v);

    // Query
    const num_q_heads = 4; // 2x KV heads for GQA
    const q = try allocator.alloc(f32, num_q_heads * config.head_dim);
    defer allocator.free(q);
    for (q) |*x| x.* = 1.0;

    // Compute attention
    const output = try cachedAttention(
        allocator,
        q,
        &layer_cache,
        num_q_heads,
        config.num_kv_heads,
        config.head_dim,
    );
    defer allocator.free(output);

    try std.testing.expectEqual(@as(usize, num_q_heads * config.head_dim), output.len);
}
