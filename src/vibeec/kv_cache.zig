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
// RING BUFFER KV-CACHE (INF-003 Optimization)
// O(1) append, fixed memory, sliding window support
// ═══════════════════════════════════════════════════════════════════════════════

/// Sliding window configuration for infinite context
pub const SlidingWindowConfig = struct {
    window_size: usize, // Total window size
    sink_tokens: usize, // First N tokens always kept (attention sinks)
    local_tokens: usize, // Last M tokens in sliding window

    pub fn default() SlidingWindowConfig {
        return .{
            .window_size = 2048,
            .sink_tokens = 4, // Keep first 4 tokens as attention sinks
            .local_tokens = 2044, // Rest is sliding window
        };
    }

    pub fn small() SlidingWindowConfig {
        return .{
            .window_size = 512,
            .sink_tokens = 4,
            .local_tokens = 508,
        };
    }
};

/// Ring buffer KV cache with O(1) append and fixed memory
pub const RingKVCache = struct {
    allocator: std.mem.Allocator,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    // Ring buffer storage (aligned for SIMD)
    k_cache: []align(16) f32,
    v_cache: []align(16) f32,

    // Ring buffer state
    write_pos: usize, // Next write position (wraps around)
    total_tokens: usize, // Total tokens seen (can exceed max_seq_len)

    // Sliding window config
    window_config: SlidingWindowConfig,

    // Stats
    evicted_tokens: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        num_kv_heads: usize,
        head_dim: usize,
        max_seq_len: usize,
        window_config: SlidingWindowConfig,
    ) !RingKVCache {
        const cache_size = max_seq_len * num_kv_heads * head_dim;

        const k_cache = try allocator.alignedAlloc(f32, 16, cache_size);
        @memset(k_cache, 0.0);

        const v_cache = try allocator.alignedAlloc(f32, 16, cache_size);
        @memset(v_cache, 0.0);

        return RingKVCache{
            .allocator = allocator,
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .k_cache = k_cache,
            .v_cache = v_cache,
            .write_pos = 0,
            .total_tokens = 0,
            .window_config = window_config,
            .evicted_tokens = 0,
        };
    }

    pub fn deinit(self: *RingKVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }

    /// O(1) append with ring buffer wrap-around
    pub fn append(self: *RingKVCache, k_new: []const f32, v_new: []const f32) void {
        const kv_size = self.num_kv_heads * self.head_dim;
        if (k_new.len != kv_size or v_new.len != kv_size) return;

        // Calculate write position in ring buffer
        const pos = self.write_pos % self.max_seq_len;
        const offset = pos * kv_size;

        // SIMD-optimized copy (8 floats at a time)
        simdCopy(self.k_cache[offset..][0..kv_size], k_new);
        simdCopy(self.v_cache[offset..][0..kv_size], v_new);

        // Update state
        self.write_pos += 1;
        self.total_tokens += 1;

        // Track evictions
        if (self.total_tokens > self.max_seq_len) {
            self.evicted_tokens += 1;
        }
    }

    /// Get effective sequence length (capped at max_seq_len)
    pub fn seqLen(self: *const RingKVCache) usize {
        return @min(self.total_tokens, self.max_seq_len);
    }

    /// Get K vector at logical position (handles ring buffer wrap)
    pub fn getK(self: *const RingKVCache, logical_pos: usize, head_idx: usize) []const f32 {
        const physical_pos = self.logicalToPhysical(logical_pos);
        const kv_size = self.num_kv_heads * self.head_dim;
        const offset = physical_pos * kv_size + head_idx * self.head_dim;
        return self.k_cache[offset..][0..self.head_dim];
    }

    /// Get V vector at logical position (handles ring buffer wrap)
    pub fn getV(self: *const RingKVCache, logical_pos: usize, head_idx: usize) []const f32 {
        const physical_pos = self.logicalToPhysical(logical_pos);
        const kv_size = self.num_kv_heads * self.head_dim;
        const offset = physical_pos * kv_size + head_idx * self.head_dim;
        return self.v_cache[offset..][0..self.head_dim];
    }

    /// Convert logical position to physical ring buffer position
    fn logicalToPhysical(self: *const RingKVCache, logical_pos: usize) usize {
        if (self.total_tokens <= self.max_seq_len) {
            return logical_pos;
        }
        // Ring buffer: oldest token is at (write_pos % max_seq_len)
        const oldest_logical = self.total_tokens - self.max_seq_len;
        const offset_from_oldest = logical_pos - oldest_logical;
        return (self.write_pos - self.max_seq_len + offset_from_oldest) % self.max_seq_len;
    }

    /// Check if position is in sliding window
    pub fn isInWindow(self: *const RingKVCache, logical_pos: usize) bool {
        const cfg = self.window_config;

        // Sink tokens always in window
        if (logical_pos < cfg.sink_tokens) return true;

        // Local window: last N tokens
        if (self.total_tokens <= cfg.window_size) return true;

        const window_start = self.total_tokens - cfg.local_tokens;
        return logical_pos >= window_start;
    }

    /// Get attention mask for sliding window
    pub fn getWindowMask(self: *const RingKVCache, allocator: std.mem.Allocator) ![]bool {
        const seq_len = self.seqLen();
        const mask = try allocator.alloc(bool, seq_len);

        for (0..seq_len) |i| {
            const logical_pos = if (self.total_tokens <= self.max_seq_len)
                i
            else
                self.total_tokens - self.max_seq_len + i;

            mask[i] = self.isInWindow(logical_pos);
        }

        return mask;
    }

    /// Reset cache for new sequence
    pub fn reset(self: *RingKVCache) void {
        self.write_pos = 0;
        self.total_tokens = 0;
        self.evicted_tokens = 0;
    }

    /// Explicit prune: keep only sink tokens + recent window
    /// Useful when switching to shorter context
    pub fn prune(self: *RingKVCache, keep_tokens: usize) void {
        if (keep_tokens >= self.total_tokens) return;

        const cfg = self.window_config;
        const to_keep = @max(keep_tokens, cfg.sink_tokens);

        // If we need to prune, reset to keep only recent tokens
        if (self.total_tokens > to_keep) {
            self.evicted_tokens += self.total_tokens - to_keep;
            self.total_tokens = to_keep;
            self.write_pos = to_keep % self.max_seq_len;
        }
    }

    /// Memory usage in bytes
    pub fn memoryUsage(self: *const RingKVCache) usize {
        return (self.k_cache.len + self.v_cache.len) * @sizeOf(f32);
    }

    /// Cache statistics
    pub fn getStats(self: *const RingKVCache) CacheStats {
        const mem = self.memoryUsage();
        const cached = self.seqLen();
        const hit_rate: f32 = if (self.total_tokens > 0)
            @as(f32, @floatFromInt(cached)) / @as(f32, @floatFromInt(self.total_tokens))
        else
            1.0;

        return CacheStats{
            .total_tokens = self.total_tokens,
            .cached_tokens = cached,
            .evicted_tokens = self.evicted_tokens,
            .hit_rate = hit_rate,
            .memory_bytes = mem,
        };
    }
};

/// Cache statistics
pub const CacheStats = struct {
    total_tokens: usize,
    cached_tokens: usize,
    evicted_tokens: usize,
    hit_rate: f32,
    memory_bytes: usize,
};

/// SIMD-optimized copy (8 floats at a time)
fn simdCopy(dst: []f32, src: []const f32) void {
    const Vec8 = @Vector(8, f32);
    var i: usize = 0;

    // SIMD copy 8 floats at a time
    while (i + 8 <= src.len) : (i += 8) {
        const v: Vec8 = src[i..][0..8].*;
        dst[i..][0..8].* = v;
    }

    // Scalar fallback for remainder
    while (i < src.len) : (i += 1) {
        dst[i] = src[i];
    }
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

test "ring kv cache" {
    const allocator = std.testing.allocator;

    var cache = try RingKVCache.init(
        allocator,
        2, // num_kv_heads
        16, // head_dim
        4, // max_seq_len (small for testing)
        SlidingWindowConfig.default(),
    );
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 0), cache.seqLen());
    try std.testing.expectEqual(@as(usize, 0), cache.total_tokens);

    // Create test vectors
    const kv_size = 2 * 16;
    var k = [_]f32{1.0} ** kv_size;
    var v = [_]f32{2.0} ** kv_size;

    // Append 3 tokens
    cache.append(&k, &v);
    cache.append(&k, &v);
    cache.append(&k, &v);

    try std.testing.expectEqual(@as(usize, 3), cache.seqLen());
    try std.testing.expectEqual(@as(usize, 3), cache.total_tokens);

    // Append 3 more (should wrap around, max_seq_len=4)
    cache.append(&k, &v);
    cache.append(&k, &v);
    cache.append(&k, &v);

    try std.testing.expectEqual(@as(usize, 4), cache.seqLen()); // Capped at max
    try std.testing.expectEqual(@as(usize, 6), cache.total_tokens);
    try std.testing.expectEqual(@as(usize, 2), cache.evicted_tokens);

    // Check stats
    const stats = cache.getStats();
    try std.testing.expectEqual(@as(usize, 6), stats.total_tokens);
    try std.testing.expectEqual(@as(usize, 4), stats.cached_tokens);
    try std.testing.expect(stats.hit_rate < 1.0);
}

test "ring kv cache reset" {
    const allocator = std.testing.allocator;

    var cache = try RingKVCache.init(
        allocator,
        2,
        16,
        8,
        SlidingWindowConfig.default(),
    );
    defer cache.deinit();

    const kv_size = 2 * 16;
    var k = [_]f32{1.0} ** kv_size;
    var v = [_]f32{2.0} ** kv_size;

    cache.append(&k, &v);
    cache.append(&k, &v);

    try std.testing.expectEqual(@as(usize, 2), cache.seqLen());

    cache.reset();

    try std.testing.expectEqual(@as(usize, 0), cache.seqLen());
    try std.testing.expectEqual(@as(usize, 0), cache.total_tokens);
}

test "simd copy" {
    var dst = [_]f32{0.0} ** 32;
    const src = [_]f32{1.0} ** 32;

    simdCopy(&dst, &src);

    for (dst) |v| {
        try std.testing.expectEqual(@as(f32, 1.0), v);
    }
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
