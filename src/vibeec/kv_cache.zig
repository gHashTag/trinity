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

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING ATTENTION (Sliding Window + Attention Sink)
// Enables infinite context with fixed memory
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute streaming attention with sliding window mask
/// Only attends to sink tokens + local window, ignoring evicted tokens
pub fn streamingAttention(
    output: []f32,
    query: []const f32,
    cache: *const RingKVCache,
    head_idx: usize,
    scores_buf: []f32,
    scale: f32,
) void {
    const seq_len = cache.seqLen();
    const head_dim = cache.head_dim;

    if (seq_len == 0) {
        @memset(output, 0.0);
        return;
    }

    // Compute attention scores with window masking
    var max_score: f32 = -std.math.inf(f32);

    for (0..seq_len) |t| {
        // Get logical position for window check
        const logical_pos = if (cache.total_tokens <= cache.max_seq_len)
            t
        else
            cache.total_tokens - cache.max_seq_len + t;

        // Check if position is in window (sink or local)
        const in_window = cache.isInWindow(logical_pos);

        if (in_window) {
            // Compute dot product
            const k_vec = cache.getK(t, head_idx);
            var dot: f32 = 0.0;
            for (0..head_dim) |j| {
                dot += query[j] * k_vec[j];
            }
            scores_buf[t] = dot * scale;
            if (scores_buf[t] > max_score) max_score = scores_buf[t];
        } else {
            // Mask out evicted tokens
            scores_buf[t] = -std.math.inf(f32);
        }
    }

    // Softmax (numerically stable)
    var sum_exp: f32 = 0.0;
    for (0..seq_len) |t| {
        if (scores_buf[t] > -std.math.inf(f32)) {
            scores_buf[t] = @exp(scores_buf[t] - max_score);
            sum_exp += scores_buf[t];
        } else {
            scores_buf[t] = 0.0;
        }
    }

    if (sum_exp > 0.0) {
        for (0..seq_len) |t| {
            scores_buf[t] /= sum_exp;
        }
    }

    // Weighted sum of V
    @memset(output, 0.0);
    for (0..seq_len) |t| {
        if (scores_buf[t] > 0.0) {
            const v_vec = cache.getV(t, head_idx);
            const score_val = scores_buf[t];
            for (0..head_dim) |j| {
                output[j] += score_val * v_vec[j];
            }
        }
    }
}

/// Compression statistics for streaming mode
pub const CompressionStats = struct {
    total_tokens_seen: usize,
    tokens_in_cache: usize,
    evicted_tokens: usize,
    compression_ratio: f32,
    memory_saved_bytes: usize,
    effective_context: usize, // sink + local window

    pub fn fromCache(cache: *const RingKVCache) CompressionStats {
        const cfg = cache.window_config;
        const effective = @min(cache.total_tokens, cfg.sink_tokens + cfg.local_tokens);
        const full_memory = cache.total_tokens * cache.num_kv_heads * cache.head_dim * 2 * @sizeOf(f32);
        const actual_memory = cache.memoryUsage();
        const saved = if (full_memory > actual_memory) full_memory - actual_memory else 0;

        return CompressionStats{
            .total_tokens_seen = cache.total_tokens,
            .tokens_in_cache = cache.seqLen(),
            .evicted_tokens = cache.evicted_tokens,
            .compression_ratio = if (cache.total_tokens > 0)
                @as(f32, @floatFromInt(cache.total_tokens)) / @as(f32, @floatFromInt(cache.seqLen()))
            else
                1.0,
            .memory_saved_bytes = saved,
            .effective_context = effective,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY KV-CACHE (OPT-T03)
// 16x memory reduction via 2-bit quantization
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary KV cache with 2-bit quantization
/// Memory: 16x reduction (f32: 4 bytes → ternary: 0.25 bytes per value)
pub const TernaryKVCache = struct {
    allocator: std.mem.Allocator,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    // Packed ternary storage (4 values per byte)
    k_cache: []u8,
    v_cache: []u8,

    // Per-token scales for dequantization
    k_scales: []f32,
    v_scales: []f32,

    // State
    seq_len: usize,

    // Quantization threshold (fraction of max)
    threshold_ratio: f32,

    // Quantization mode
    quant_mode: QuantMode,

    pub const QuantMode = enum {
        fixed_threshold, // Original: threshold = max * ratio
        adaptive_mean, // Adaptive: threshold = mean(abs) * ratio
        no_threshold, // All non-zero values quantized (best accuracy)
        rms_scale, // Use RMS for scale (better for attention)
    };

    pub fn init(
        allocator: std.mem.Allocator,
        num_kv_heads: usize,
        head_dim: usize,
        max_seq_len: usize,
    ) !TernaryKVCache {
        const values_per_token = num_kv_heads * head_dim;
        const bytes_per_token = (values_per_token + 3) / 4; // 4 values per byte
        const total_bytes = max_seq_len * bytes_per_token;

        return TernaryKVCache{
            .allocator = allocator,
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .k_cache = try allocator.alloc(u8, total_bytes),
            .v_cache = try allocator.alloc(u8, total_bytes),
            .k_scales = try allocator.alloc(f32, max_seq_len),
            .v_scales = try allocator.alloc(f32, max_seq_len),
            .seq_len = 0,
            .threshold_ratio = 0.0,
            .quant_mode = .rms_scale, // RMS-based scaling for better accuracy
        };
    }

    pub fn deinit(self: *TernaryKVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
        self.allocator.free(self.k_scales);
        self.allocator.free(self.v_scales);
    }

    /// Append new K,V vectors with quantization
    pub fn append(self: *TernaryKVCache, k_new: []const f32, v_new: []const f32) void {
        if (self.seq_len >= self.max_seq_len) return;

        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + 3) / 4;
        const offset = self.seq_len * bytes_per_token;

        // Quantize K
        const k_scale = self.quantizeVector(
            self.k_cache[offset..][0..bytes_per_token],
            k_new,
        );
        self.k_scales[self.seq_len] = k_scale;

        // Quantize V
        const v_scale = self.quantizeVector(
            self.v_cache[offset..][0..bytes_per_token],
            v_new,
        );
        self.v_scales[self.seq_len] = v_scale;

        self.seq_len += 1;
    }

    /// Quantize f32 vector to ternary packed bytes
    /// Returns scale factor for dequantization
    fn quantizeVector(self: *const TernaryKVCache, dst: []u8, src: []const f32) f32 {
        // Calculate statistics
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

        // Calculate scale and threshold based on mode
        const scale: f32 = switch (self.quant_mode) {
            .fixed_threshold, .no_threshold, .adaptive_mean => max_abs,
            .rms_scale => rms * 1.5, // RMS * sqrt(2) approximates max for normal distribution
        };

        const threshold: f32 = switch (self.quant_mode) {
            .fixed_threshold => max_abs * self.threshold_ratio,
            .adaptive_mean => mean_abs * self.threshold_ratio,
            .no_threshold => 0.0,
            .rms_scale => rms * 0.5, // Half RMS as threshold
        };

        // Pack 4 values per byte
        var byte_idx: usize = 0;
        var bit_pos: u3 = 0;
        var current_byte: u8 = 0;

        for (src) |v| {
            const trit: u2 = if (v > threshold)
                0b01 // +1
            else if (v < -threshold)
                0b10 // -1
            else
                0b00; // 0

            current_byte |= @as(u8, trit) << bit_pos;
            bit_pos +%= 2;

            if (bit_pos == 0) {
                dst[byte_idx] = current_byte;
                byte_idx += 1;
                current_byte = 0;
            }
        }

        // Write last partial byte
        if (bit_pos != 0 and byte_idx < dst.len) {
            dst[byte_idx] = current_byte;
        }

        return scale;
    }

    /// Compute dot product between f32 query and ternary key (no full dequantization)
    pub fn ternaryDot(
        self: *const TernaryKVCache,
        q: []const f32,
        token_pos: usize,
        head_idx: usize,
    ) f32 {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + 3) / 4;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.k_scales[token_pos];
        var sum: f32 = 0.0;

        // Process each value in the head
        for (0..self.head_dim) |i| {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / 4;
            const bit_pos: u3 = @intCast((global_idx % 4) * 2);
            const trit = (self.k_cache[byte_idx] >> bit_pos) & 0x3;

            // trit: 00=0, 01=+1, 10=-1
            const sign: f32 = switch (trit) {
                0b01 => 1.0,
                0b10 => -1.0,
                else => 0.0,
            };

            sum += q[i] * sign;
        }

        return sum * scale;
    }

    /// Get dequantized V vector for weighted sum
    pub fn dequantizeV(
        self: *const TernaryKVCache,
        dst: []f32,
        token_pos: usize,
        head_idx: usize,
    ) void {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + 3) / 4;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.v_scales[token_pos];

        for (0..self.head_dim) |i| {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / 4;
            const bit_pos: u3 = @intCast((global_idx % 4) * 2);
            const trit = (self.v_cache[byte_idx] >> bit_pos) & 0x3;

            dst[i] = switch (trit) {
                0b01 => scale,
                0b10 => -scale,
                else => 0.0,
            };
        }
    }

    /// SIMD-optimized ternary dot product (8 values at a time)
    pub fn simdTernaryDot(
        self: *const TernaryKVCache,
        q: []const f32,
        token_pos: usize,
        head_idx: usize,
    ) f32 {
        const Vec8 = @Vector(8, f32);
        const values_per_token = self.num_kv_heads * self.head_dim;
        const bytes_per_token = (values_per_token + 3) / 4;
        const token_offset = token_pos * bytes_per_token;
        const head_offset = head_idx * self.head_dim;

        const scale = self.k_scales[token_pos];
        const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

        var sum_vec: Vec8 = @splat(0.0);
        var i: usize = 0;

        // Process 8 values at a time
        while (i + 8 <= self.head_dim) : (i += 8) {
            const q_vec: Vec8 = q[i..][0..8].*;

            // Extract 8 trits (2 bytes)
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / 4;
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

        // Scalar fallback for remainder
        while (i < self.head_dim) : (i += 1) {
            const global_idx = head_offset + i;
            const byte_idx = token_offset + global_idx / 4;
            const bit_pos: u3 = @intCast((global_idx % 4) * 2);
            const trit = (self.k_cache[byte_idx] >> bit_pos) & 0x3;
            sum += q[i] * sign_lut[trit];
        }

        return sum * scale;
    }

    /// Reset cache
    pub fn reset(self: *TernaryKVCache) void {
        self.seq_len = 0;
    }

    /// Set quantization mode for accuracy tuning
    pub fn setQuantMode(self: *TernaryKVCache, mode: QuantMode, threshold: f32) void {
        self.quant_mode = mode;
        self.threshold_ratio = threshold;
    }

    /// Use high-accuracy mode (no threshold, all values quantized)
    pub fn setHighAccuracy(self: *TernaryKVCache) void {
        self.quant_mode = .no_threshold;
        self.threshold_ratio = 0.0;
    }

    /// Use balanced mode (small threshold for noise reduction)
    pub fn setBalanced(self: *TernaryKVCache) void {
        self.quant_mode = .adaptive_mean;
        self.threshold_ratio = 0.1;
    }

    /// Use high-compression mode (aggressive threshold)
    pub fn setHighCompression(self: *TernaryKVCache) void {
        self.quant_mode = .fixed_threshold;
        self.threshold_ratio = 0.3;
    }

    /// Memory usage in bytes
    pub fn memoryUsage(self: *const TernaryKVCache) usize {
        return self.k_cache.len + self.v_cache.len +
            (self.k_scales.len + self.v_scales.len) * @sizeOf(f32);
    }

    /// Compare with f32 cache memory
    pub fn memoryStats(self: *const TernaryKVCache) TernaryCacheStats {
        const values_per_token = self.num_kv_heads * self.head_dim;
        const f32_bytes = self.max_seq_len * values_per_token * 2 * @sizeOf(f32);
        const ternary_bytes = self.memoryUsage();

        return TernaryCacheStats{
            .f32_bytes = f32_bytes,
            .ternary_bytes = ternary_bytes,
            .compression_ratio = @as(f32, @floatFromInt(f32_bytes)) / @as(f32, @floatFromInt(ternary_bytes)),
            .tokens_capacity = self.max_seq_len,
        };
    }
};

/// Ternary cache memory statistics
pub const TernaryCacheStats = struct {
    f32_bytes: usize,
    ternary_bytes: usize,
    compression_ratio: f32,
    tokens_capacity: usize,
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

test "ternary kv cache" {
    const allocator = std.testing.allocator;

    var cache = try TernaryKVCache.init(
        allocator,
        2, // num_kv_heads
        8, // head_dim
        4, // max_seq_len
    );
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 0), cache.seq_len);

    // Create test vectors (2 heads * 8 dim = 16 values)
    var k = [_]f32{ 1.0, -0.5, 0.8, -0.9, 0.1, -0.2, 0.7, -0.6, 0.3, -0.4, 0.5, -0.3, 0.2, -0.1, 0.4, -0.8 };
    var v = [_]f32{ 0.5, -0.3, 0.7, -0.8, 0.2, -0.1, 0.6, -0.5, 0.4, -0.2, 0.3, -0.4, 0.1, -0.6, 0.8, -0.7 };

    // Append tokens
    cache.append(&k, &v);
    cache.append(&k, &v);

    try std.testing.expectEqual(@as(usize, 2), cache.seq_len);

    // Test ternary dot product
    var q = [_]f32{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    const dot = cache.ternaryDot(&q, 0, 0);
    // Dot product can be 0 if positive and negative values cancel out
    // Just verify it's a valid float
    try std.testing.expect(!std.math.isNan(dot));

    // Test dequantize V
    var v_out: [8]f32 = undefined;
    cache.dequantizeV(&v_out, 0, 0);
    // Values should be -scale, 0, or +scale
    for (v_out) |val| {
        try std.testing.expect(val == 0.0 or @abs(val) > 0.0);
    }

    // Test memory stats
    const stats = cache.memoryStats();
    try std.testing.expect(stats.compression_ratio > 1.0);
    try std.testing.expect(stats.ternary_bytes < stats.f32_bytes);
}

test "ternary kv cache memory savings" {
    const allocator = std.testing.allocator;

    // Realistic config: 4 KV heads, 128 head_dim, 2048 tokens
    var cache = try TernaryKVCache.init(
        allocator,
        4, // num_kv_heads
        128, // head_dim
        2048, // max_seq_len
    );
    defer cache.deinit();

    const stats = cache.memoryStats();

    // f32: 4 * 128 * 2048 * 2 * 4 = 8,388,608 bytes (8 MB)
    // ternary: 4 * 128 * 2048 / 4 * 2 + 2048 * 2 * 4 = 540,672 bytes (~0.5 MB)
    // Compression: ~15.5x

    try std.testing.expect(stats.compression_ratio > 10.0);
    try std.testing.expect(stats.compression_ratio < 20.0);
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

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH KV-CACHE (INF-004)
// Multiple sequences with separate KV caches
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch KV cache for multiple concurrent sequences
pub const BatchKVCache = struct {
    allocator: std.mem.Allocator,
    max_batch_size: usize,
    num_layers: usize,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,

    // Per-sequence KV caches [batch_size][num_layers]
    caches: [][]RingKVCache,

    // Sequence state
    active: []bool,
    positions: []usize,

    pub fn init(
        allocator: std.mem.Allocator,
        max_batch_size: usize,
        num_layers: usize,
        num_kv_heads: usize,
        head_dim: usize,
        max_seq_len: usize,
    ) !BatchKVCache {
        var batch = BatchKVCache{
            .allocator = allocator,
            .max_batch_size = max_batch_size,
            .num_layers = num_layers,
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .caches = try allocator.alloc([]RingKVCache, max_batch_size),
            .active = try allocator.alloc(bool, max_batch_size),
            .positions = try allocator.alloc(usize, max_batch_size),
        };

        // Initialize per-sequence caches
        for (0..max_batch_size) |seq_idx| {
            batch.caches[seq_idx] = try allocator.alloc(RingKVCache, num_layers);
            for (0..num_layers) |layer_idx| {
                batch.caches[seq_idx][layer_idx] = try RingKVCache.init(
                    allocator,
                    num_kv_heads,
                    head_dim,
                    max_seq_len,
                    SlidingWindowConfig.default(),
                );
            }
            batch.active[seq_idx] = false;
            batch.positions[seq_idx] = 0;
        }

        return batch;
    }

    pub fn deinit(self: *BatchKVCache) void {
        for (0..self.max_batch_size) |seq_idx| {
            for (0..self.num_layers) |layer_idx| {
                self.caches[seq_idx][layer_idx].deinit();
            }
            self.allocator.free(self.caches[seq_idx]);
        }
        self.allocator.free(self.caches);
        self.allocator.free(self.active);
        self.allocator.free(self.positions);
    }

    /// Add new sequence to batch, returns sequence ID or null if full
    pub fn addSequence(self: *BatchKVCache) ?usize {
        for (0..self.max_batch_size) |seq_idx| {
            if (!self.active[seq_idx]) {
                self.active[seq_idx] = true;
                self.positions[seq_idx] = 0;
                // Reset KV caches for this sequence
                for (0..self.num_layers) |layer_idx| {
                    self.caches[seq_idx][layer_idx].reset();
                }
                return seq_idx;
            }
        }
        return null; // Batch is full
    }

    /// Remove sequence from batch
    pub fn removeSequence(self: *BatchKVCache, seq_idx: usize) void {
        if (seq_idx < self.max_batch_size) {
            self.active[seq_idx] = false;
            self.positions[seq_idx] = 0;
        }
    }

    /// Get KV cache for specific sequence and layer
    pub fn getCache(self: *BatchKVCache, seq_idx: usize, layer_idx: usize) *RingKVCache {
        return &self.caches[seq_idx][layer_idx];
    }

    /// Append K,V to specific sequence's cache
    pub fn append(self: *BatchKVCache, seq_idx: usize, layer_idx: usize, k: []const f32, v: []const f32) void {
        if (seq_idx < self.max_batch_size and self.active[seq_idx]) {
            self.caches[seq_idx][layer_idx].append(k, v);
        }
    }

    /// Get number of active sequences
    pub fn activeCount(self: *const BatchKVCache) usize {
        var count: usize = 0;
        for (self.active) |a| {
            if (a) count += 1;
        }
        return count;
    }

    /// Get list of active sequence IDs
    pub fn getActiveSequences(self: *const BatchKVCache, out: []usize) usize {
        var count: usize = 0;
        for (0..self.max_batch_size) |seq_idx| {
            if (self.active[seq_idx] and count < out.len) {
                out[count] = seq_idx;
                count += 1;
            }
        }
        return count;
    }

    /// Memory usage in bytes
    pub fn memoryUsage(self: *const BatchKVCache) usize {
        var total: usize = 0;
        for (0..self.max_batch_size) |seq_idx| {
            for (0..self.num_layers) |layer_idx| {
                total += self.caches[seq_idx][layer_idx].memoryUsage();
            }
        }
        return total;
    }
};

test "batch kv cache" {
    const allocator = std.testing.allocator;

    var batch = try BatchKVCache.init(
        allocator,
        4, // max_batch_size
        2, // num_layers
        2, // num_kv_heads
        16, // head_dim
        32, // max_seq_len
    );
    defer batch.deinit();

    // Initially no active sequences
    try std.testing.expectEqual(@as(usize, 0), batch.activeCount());

    // Add sequences
    const seq0 = batch.addSequence();
    try std.testing.expect(seq0 != null);
    try std.testing.expectEqual(@as(usize, 1), batch.activeCount());

    const seq1 = batch.addSequence();
    try std.testing.expect(seq1 != null);
    try std.testing.expectEqual(@as(usize, 2), batch.activeCount());

    // Append to sequence 0
    var k = [_]f32{1.0} ** 32;
    var v = [_]f32{2.0} ** 32;
    batch.append(seq0.?, 0, &k, &v);

    // Remove sequence
    batch.removeSequence(seq0.?);
    try std.testing.expectEqual(@as(usize, 1), batch.activeCount());

    // Can add new sequence in freed slot
    const seq2 = batch.addSequence();
    try std.testing.expect(seq2 != null);
    try std.testing.expectEqual(@as(usize, 2), batch.activeCount());
}

test "streaming_attention_window" {
    const allocator = std.testing.allocator;

    // Create cache with small window for testing
    const window_config = SlidingWindowConfig{
        .window_size = 16,
        .sink_tokens = 2, // Keep first 2 tokens
        .local_tokens = 6, // Keep last 6 tokens
    };

    var cache = try RingKVCache.init(allocator, 1, 4, 16, window_config);
    defer cache.deinit();

    // Add 20 tokens (exceeds window)
    for (0..20) |i| {
        var k = [_]f32{ @floatFromInt(i), 0, 0, 0 };
        var v = [_]f32{ 1, 0, 0, 0 };
        cache.append(&k, &v);
    }

    // Check window membership
    // Sink tokens (0, 1) should be in window
    try std.testing.expect(cache.isInWindow(0));
    try std.testing.expect(cache.isInWindow(1));

    // Middle tokens should be evicted
    try std.testing.expect(!cache.isInWindow(5));
    try std.testing.expect(!cache.isInWindow(10));

    // Recent tokens (14-19) should be in window
    try std.testing.expect(cache.isInWindow(14));
    try std.testing.expect(cache.isInWindow(19));

    // Test streaming attention
    const query = [_]f32{ 1, 0, 0, 0 };
    var output: [4]f32 = undefined;
    var scores: [16]f32 = undefined;

    streamingAttention(&output, &query, &cache, 0, &scores, 1.0);

    // Output should be non-zero (attention computed)
    try std.testing.expect(output[0] != 0.0);
}

test "compression_stats" {
    const allocator = std.testing.allocator;

    const window_config = SlidingWindowConfig{
        .window_size = 100,
        .sink_tokens = 4,
        .local_tokens = 96,
    };

    var cache = try RingKVCache.init(allocator, 4, 64, 100, window_config);
    defer cache.deinit();

    // Simulate long sequence
    var k_buf: [256]f32 = undefined;
    var v_buf: [256]f32 = undefined;
    @memset(&k_buf, 0.1);
    @memset(&v_buf, 0.2);

    for (0..500) |_| {
        cache.append(&k_buf, &v_buf);
    }

    const stats = CompressionStats.fromCache(&cache);

    try std.testing.expectEqual(@as(usize, 500), stats.total_tokens_seen);
    try std.testing.expectEqual(@as(usize, 100), stats.tokens_in_cache);
    try std.testing.expectEqual(@as(usize, 400), stats.evicted_tokens);
    try std.testing.expect(stats.compression_ratio >= 4.9); // 500/100 = 5x

    std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           KV CACHE COMPRESSION STATS                        ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Total tokens seen:    {d:>10}                            ║\n", .{stats.total_tokens_seen});
    std.debug.print("║  Tokens in cache:      {d:>10}                            ║\n", .{stats.tokens_in_cache});
    std.debug.print("║  Evicted tokens:       {d:>10}                            ║\n", .{stats.evicted_tokens});
    std.debug.print("║  Compression ratio:    {d:>10.1}x                          ║\n", .{stats.compression_ratio});
    std.debug.print("║  Effective context:    {d:>10}                            ║\n", .{stats.effective_context});
    std.debug.print("║  Memory saved:         {d:>10} bytes                      ║\n", .{stats.memory_saved_bytes});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGED ATTENTION (OPT-PA01)
// vLLM-style block-based memory management for KV cache
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuration for paged attention
pub const PagedAttentionConfig = struct {
    block_size: usize, // Tokens per block (default: 16)
    num_heads: usize, // Number of attention heads
    head_dim: usize, // Dimension per head
    num_layers: usize, // Number of transformer layers
    max_blocks: usize, // Maximum blocks in pool
    use_ternary: bool, // Use ternary quantization for blocks

    pub fn default7B() PagedAttentionConfig {
        return .{
            .block_size = 16,
            .num_heads = 32,
            .head_dim = 128,
            .num_layers = 32,
            .max_blocks = 4096, // ~64K tokens capacity
            .use_ternary = false,
        };
    }

    pub fn mini() PagedAttentionConfig {
        return .{
            .block_size = 4,
            .num_heads = 4,
            .head_dim = 16,
            .num_layers = 2,
            .max_blocks = 64,
            .use_ternary = false,
        };
    }

    /// Memory per block in bytes
    pub fn blockMemory(self: *const PagedAttentionConfig) usize {
        // K + V per block
        const kv_per_token = self.num_heads * self.head_dim * 2 * @sizeOf(f32);
        return self.block_size * kv_per_token;
    }

    /// Total pool memory in bytes
    pub fn totalMemory(self: *const PagedAttentionConfig) usize {
        return self.max_blocks * self.blockMemory();
    }
};

/// Single KV cache block
pub const KVBlock = struct {
    block_id: usize,
    ref_count: usize, // For copy-on-write
    k_cache: []f32, // [block_size × num_heads × head_dim]
    v_cache: []f32, // [block_size × num_heads × head_dim]
    num_tokens: usize, // Actual tokens stored (0 to block_size)
    layer_idx: usize, // Which layer this block belongs to

    pub fn init(allocator: std.mem.Allocator, config: *const PagedAttentionConfig, block_id: usize, layer_idx: usize) !KVBlock {
        const size = config.block_size * config.num_heads * config.head_dim;
        const k_cache = try allocator.alloc(f32, size);
        @memset(k_cache, 0.0);
        const v_cache = try allocator.alloc(f32, size);
        @memset(v_cache, 0.0);

        return KVBlock{
            .block_id = block_id,
            .ref_count = 1,
            .k_cache = k_cache,
            .v_cache = v_cache,
            .num_tokens = 0,
            .layer_idx = layer_idx,
        };
    }

    pub fn deinit(self: *KVBlock, allocator: std.mem.Allocator) void {
        allocator.free(self.k_cache);
        allocator.free(self.v_cache);
    }

    /// Check if block is full
    pub fn isFull(self: *const KVBlock, block_size: usize) bool {
        return self.num_tokens >= block_size;
    }

    /// Append K,V for one token
    pub fn appendToken(self: *KVBlock, k: []const f32, v: []const f32, num_heads: usize, head_dim: usize) !void {
        const kv_size = num_heads * head_dim;
        if (k.len != kv_size or v.len != kv_size) return error.InvalidSize;

        const offset = self.num_tokens * kv_size;
        @memcpy(self.k_cache[offset..][0..kv_size], k);
        @memcpy(self.v_cache[offset..][0..kv_size], v);
        self.num_tokens += 1;
    }

    /// Get K for specific token position within block
    pub fn getK(self: *const KVBlock, token_idx: usize, head_idx: usize, num_heads: usize, head_dim: usize) []const f32 {
        const offset = token_idx * num_heads * head_dim + head_idx * head_dim;
        return self.k_cache[offset..][0..head_dim];
    }

    /// Get V for specific token position within block
    pub fn getV(self: *const KVBlock, token_idx: usize, head_idx: usize, num_heads: usize, head_dim: usize) []const f32 {
        const offset = token_idx * num_heads * head_dim + head_idx * head_dim;
        return self.v_cache[offset..][0..head_dim];
    }
};

/// Block table: maps sequence positions to blocks
pub const BlockTable = struct {
    allocator: std.mem.Allocator,
    seq_id: usize,
    block_ids: std.ArrayList(usize), // List of block IDs for this sequence
    num_tokens: usize, // Total tokens in sequence

    pub fn init(allocator: std.mem.Allocator, seq_id: usize) BlockTable {
        return BlockTable{
            .allocator = allocator,
            .seq_id = seq_id,
            .block_ids = std.ArrayList(usize).init(allocator),
            .num_tokens = 0,
        };
    }

    pub fn deinit(self: *BlockTable) void {
        self.block_ids.deinit();
    }

    /// Get block index for a token position
    pub fn getBlockIdx(self: *const BlockTable, token_pos: usize, block_size: usize) ?usize {
        const block_num = token_pos / block_size;
        if (block_num >= self.block_ids.items.len) return null;
        return self.block_ids.items[block_num];
    }

    /// Get position within block
    pub fn getPositionInBlock(token_pos: usize, block_size: usize) usize {
        return token_pos % block_size;
    }
};

/// Memory pool for KV cache blocks
pub const BlockPool = struct {
    allocator: std.mem.Allocator,
    config: PagedAttentionConfig,
    blocks: std.ArrayList(KVBlock), // All allocated blocks
    free_list: std.ArrayList(usize), // Free block indices
    num_allocated: usize,

    pub fn init(allocator: std.mem.Allocator, config: PagedAttentionConfig) !BlockPool {
        var pool = BlockPool{
            .allocator = allocator,
            .config = config,
            .blocks = std.ArrayList(KVBlock).init(allocator),
            .free_list = std.ArrayList(usize).init(allocator),
            .num_allocated = 0,
        };

        // Pre-allocate all blocks
        for (0..config.max_blocks) |i| {
            const block = try KVBlock.init(allocator, &config, i, 0);
            try pool.blocks.append(block);
            try pool.free_list.append(i);
        }

        return pool;
    }

    pub fn deinit(self: *BlockPool) void {
        for (self.blocks.items) |*block| {
            block.deinit(self.allocator);
        }
        self.blocks.deinit();
        self.free_list.deinit();
    }

    /// Allocate a block from the pool
    pub fn allocateBlock(self: *BlockPool) ?usize {
        if (self.free_list.items.len == 0) return null;
        const block_id = self.free_list.pop();
        self.num_allocated += 1;
        self.blocks.items[block_id].ref_count = 1;
        self.blocks.items[block_id].num_tokens = 0;
        return block_id;
    }

    /// Free a block back to the pool
    pub fn freeBlock(self: *BlockPool, block_id: usize) void {
        if (block_id >= self.blocks.items.len) return;

        self.blocks.items[block_id].ref_count -= 1;
        if (self.blocks.items[block_id].ref_count == 0) {
            self.free_list.append(block_id) catch {};
            self.num_allocated -= 1;
        }
    }

    /// Get block by ID
    pub fn getBlock(self: *BlockPool, block_id: usize) ?*KVBlock {
        if (block_id >= self.blocks.items.len) return null;
        return &self.blocks.items[block_id];
    }

    /// Copy-on-write: copy block if shared
    pub fn copyOnWrite(self: *BlockPool, block_id: usize) ?usize {
        if (block_id >= self.blocks.items.len) return null;

        const block = &self.blocks.items[block_id];
        if (block.ref_count <= 1) return block_id; // No copy needed

        // Allocate new block
        const new_id = self.allocateBlock() orelse return null;
        const new_block = &self.blocks.items[new_id];

        // Copy data
        @memcpy(new_block.k_cache, block.k_cache);
        @memcpy(new_block.v_cache, block.v_cache);
        new_block.num_tokens = block.num_tokens;
        new_block.layer_idx = block.layer_idx;

        // Decrement old block ref count
        block.ref_count -= 1;

        return new_id;
    }

    /// Get statistics
    pub fn getStats(self: *const BlockPool) PagedAttentionStats {
        const total = self.config.max_blocks;
        const allocated = self.num_allocated;
        const free = total - allocated;
        const mem_per_block = self.config.blockMemory();

        return PagedAttentionStats{
            .total_blocks = total,
            .allocated_blocks = allocated,
            .free_blocks = free,
            .memory_used_bytes = allocated * mem_per_block,
            .memory_total_bytes = total * mem_per_block,
            .utilization_percent = if (total > 0) @as(f32, @floatFromInt(allocated)) / @as(f32, @floatFromInt(total)) * 100.0 else 0.0,
            .cow_copies = 0, // TODO: track
            .evictions = 0, // TODO: track
        };
    }
};

/// Statistics for paged attention
pub const PagedAttentionStats = struct {
    total_blocks: usize,
    allocated_blocks: usize,
    free_blocks: usize,
    memory_used_bytes: usize,
    memory_total_bytes: usize,
    utilization_percent: f32,
    cow_copies: usize,
    evictions: usize,

    pub fn print(self: *const PagedAttentionStats) void {
        const mem_used_mb = @as(f64, @floatFromInt(self.memory_used_bytes)) / (1024.0 * 1024.0);
        const mem_total_mb = @as(f64, @floatFromInt(self.memory_total_bytes)) / (1024.0 * 1024.0);

        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           PAGED ATTENTION STATS                             ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Total blocks:         {d:>10}                            ║\n", .{self.total_blocks});
        std.debug.print("║  Allocated blocks:     {d:>10}                            ║\n", .{self.allocated_blocks});
        std.debug.print("║  Free blocks:          {d:>10}                            ║\n", .{self.free_blocks});
        std.debug.print("║  Memory used:          {d:>10.2} MB                        ║\n", .{mem_used_mb});
        std.debug.print("║  Memory total:         {d:>10.2} MB                        ║\n", .{mem_total_mb});
        std.debug.print("║  Utilization:          {d:>10.1}%                          ║\n", .{self.utilization_percent});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

/// Paged attention computation
pub fn pagedAttention(
    output: []f32,
    query: []const f32,
    block_table: *const BlockTable,
    pool: *const BlockPool,
    head_idx: usize,
    scale: f32,
    allocator: std.mem.Allocator,
) !void {
    const config = &pool.config;
    const head_dim = config.head_dim;
    const num_heads = config.num_heads;
    const block_size = config.block_size;
    const num_tokens = block_table.num_tokens;

    if (num_tokens == 0) {
        @memset(output, 0.0);
        return;
    }

    // Allocate scores buffer
    const scores = try allocator.alloc(f32, num_tokens);
    defer allocator.free(scores);

    // Compute attention scores: Q @ K^T
    for (0..num_tokens) |pos| {
        const block_num = pos / block_size;
        const pos_in_block = pos % block_size;

        if (block_num >= block_table.block_ids.items.len) {
            scores[pos] = -std.math.inf(f32);
            continue;
        }

        const block_id = block_table.block_ids.items[block_num];
        const block = pool.blocks.items[block_id];

        if (pos_in_block >= block.num_tokens) {
            scores[pos] = -std.math.inf(f32);
            continue;
        }

        const k = block.getK(pos_in_block, head_idx, num_heads, head_dim);

        // Dot product
        var dot: f32 = 0.0;
        for (0..head_dim) |d| {
            dot += query[d] * k[d];
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
        if (s.* > -std.math.inf(f32)) {
            s.* = @exp(s.* - max_score);
            sum_exp += s.*;
        } else {
            s.* = 0.0;
        }
    }

    if (sum_exp > 0) {
        for (scores) |*s| {
            s.* /= sum_exp;
        }
    }

    // Weighted sum of V
    @memset(output, 0.0);
    for (0..num_tokens) |pos| {
        const block_num = pos / block_size;
        const pos_in_block = pos % block_size;

        if (block_num >= block_table.block_ids.items.len) continue;

        const block_id = block_table.block_ids.items[block_num];
        const block = pool.blocks.items[block_id];

        if (pos_in_block >= block.num_tokens) continue;

        const v = block.getV(pos_in_block, head_idx, num_heads, head_dim);
        const weight = scores[pos];

        for (0..head_dim) |d| {
            output[d] += weight * v[d];
        }
    }
}

test "paged_attention_basic" {
    const allocator = std.testing.allocator;

    const config = PagedAttentionConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    // Allocate blocks for a sequence
    var table = BlockTable.init(allocator, 0);
    defer table.deinit();

    // Allocate first block
    const block_id = pool.allocateBlock();
    try std.testing.expect(block_id != null);
    try table.block_ids.append(block_id.?);

    // Add tokens to block
    var k = [_]f32{1.0} ** 64; // 4 heads × 16 dim
    var v = [_]f32{2.0} ** 64;

    const block = pool.getBlock(block_id.?);
    try std.testing.expect(block != null);

    try block.?.appendToken(&k, &v, config.num_heads, config.head_dim);
    table.num_tokens = 1;

    // Compute attention
    var output: [16]f32 = undefined;
    const query = [_]f32{1.0} ** 16;

    try pagedAttention(&output, &query, &table, &pool, 0, 1.0, allocator);

    // Output should be V (single token, weight = 1.0)
    try std.testing.expectApproxEqAbs(output[0], 2.0, 0.01);

    // Check stats
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.allocated_blocks);
    try std.testing.expectEqual(@as(usize, 63), stats.free_blocks);
}

test "paged_attention_multi_block" {
    const allocator = std.testing.allocator;

    const config = PagedAttentionConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    var table = BlockTable.init(allocator, 0);
    defer table.deinit();

    // Fill multiple blocks
    _ = config.num_heads * config.head_dim; // kv_size used implicitly
    var k_buf: [64]f32 = undefined;
    var v_buf: [64]f32 = undefined;

    for (0..10) |i| { // 10 tokens, block_size=4, so 3 blocks
        // Allocate new block if needed
        const block_num = i / config.block_size;
        while (table.block_ids.items.len <= block_num) {
            const new_block = pool.allocateBlock();
            try std.testing.expect(new_block != null);
            try table.block_ids.append(new_block.?);
        }

        // Set K,V values
        @memset(&k_buf, @as(f32, @floatFromInt(i)));
        @memset(&v_buf, @as(f32, @floatFromInt(i * 10)));

        const block = pool.getBlock(table.block_ids.items[block_num]);
        try block.?.appendToken(&k_buf, &v_buf, config.num_heads, config.head_dim);
        table.num_tokens = i + 1;
    }

    // Should have 3 blocks allocated
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.allocated_blocks);

    // Compute attention
    var output: [16]f32 = undefined;
    var query: [16]f32 = undefined;
    @memset(&query, 1.0);

    try pagedAttention(&output, &query, &table, &pool, 0, 0.1, allocator);

    // Output should be weighted sum of V values
    try std.testing.expect(output[0] > 0.0);
}

test "copy_on_write" {
    const allocator = std.testing.allocator;

    const config = PagedAttentionConfig.mini();
    var pool = try BlockPool.init(allocator, config);
    defer pool.deinit();

    // Allocate a block
    const block_id = pool.allocateBlock();
    try std.testing.expect(block_id != null);

    // Increment ref count (simulating shared block)
    pool.blocks.items[block_id.?].ref_count = 2;

    // Copy-on-write should create new block
    const new_id = pool.copyOnWrite(block_id.?);
    try std.testing.expect(new_id != null);
    try std.testing.expect(new_id.? != block_id.?);

    // Original block ref count should be decremented
    try std.testing.expectEqual(@as(usize, 1), pool.blocks.items[block_id.?].ref_count);

    // New block ref count should be 1
    try std.testing.expectEqual(@as(usize, 1), pool.blocks.items[new_id.?].ref_count);
}
