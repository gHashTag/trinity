// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 FULL LAYERS - Complete 30-Layer Transformer for 2B Model
// Wire all layers with KV-cache for coherent autoregressive generation
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const gguf = @import("gguf_reader.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET 2B CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNet2BConfig = struct {
    vocab_size: u32 = 128256,
    hidden_size: u32 = 2560,
    intermediate_size: u32 = 6912,
    num_hidden_layers: u32 = 30,
    num_attention_heads: u32 = 20,
    num_key_value_heads: u32 = 5,
    max_position_embeddings: u32 = 4096,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 500000.0,
    
    pub fn headDim(self: BitNet2BConfig) u32 {
        return self.hidden_size / self.num_attention_heads;
    }
    
    pub fn kvDim(self: BitNet2BConfig) u32 {
        return self.hidden_size / self.num_attention_heads * self.num_key_value_heads;
    }
    
    pub fn gqaGroups(self: BitNet2BConfig) u32 {
        return self.num_attention_heads / self.num_key_value_heads;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KV-CACHE FOR AUTOREGRESSIVE GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCache = struct {
    allocator: std.mem.Allocator,
    num_layers: usize,
    num_kv_heads: usize,
    head_dim: usize,
    max_seq_len: usize,
    current_len: usize,
    
    // Cache: [layer][seq_pos][kv_head][head_dim]
    k_cache: []f32,
    v_cache: []f32,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNet2BConfig, max_seq_len: usize) !KVCache {
        const num_layers = config.num_hidden_layers;
        const num_kv_heads = config.num_key_value_heads;
        const head_dim = config.headDim();
        
        const cache_size = num_layers * max_seq_len * num_kv_heads * head_dim;
        
        const k_cache = try allocator.alloc(f32, cache_size);
        @memset(k_cache, 0.0);
        
        const v_cache = try allocator.alloc(f32, cache_size);
        @memset(v_cache, 0.0);
        
        return KVCache{
            .allocator = allocator,
            .num_layers = num_layers,
            .num_kv_heads = num_kv_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .current_len = 0,
            .k_cache = k_cache,
            .v_cache = v_cache,
        };
    }
    
    pub fn deinit(self: *KVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }
    
    pub fn reset(self: *KVCache) void {
        self.current_len = 0;
        @memset(self.k_cache, 0.0);
        @memset(self.v_cache, 0.0);
    }
    
    fn getOffset(self: *const KVCache, layer: usize, pos: usize) usize {
        return (layer * self.max_seq_len + pos) * self.num_kv_heads * self.head_dim;
    }
    
    pub fn storeKV(self: *KVCache, layer: usize, k: []const f32, v: []const f32) void {
        if (self.current_len >= self.max_seq_len) return;
        
        const offset = self.getOffset(layer, self.current_len);
        const size = self.num_kv_heads * self.head_dim;
        
        @memcpy(self.k_cache[offset..offset + size], k[0..size]);
        @memcpy(self.v_cache[offset..offset + size], v[0..size]);
    }
    
    pub fn getK(self: *const KVCache, layer: usize, pos: usize) []const f32 {
        const offset = self.getOffset(layer, pos);
        const size = self.num_kv_heads * self.head_dim;
        return self.k_cache[offset..offset + size];
    }
    
    pub fn getV(self: *const KVCache, layer: usize, pos: usize) []const f32 {
        const offset = self.getOffset(layer, pos);
        const size = self.num_kv_heads * self.head_dim;
        return self.v_cache[offset..offset + size];
    }
    
    pub fn advance(self: *KVCache) void {
        if (self.current_len < self.max_seq_len) {
            self.current_len += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER WEIGHTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LayerWeights = struct {
    // Attention projections (I2_S quantized)
    q_proj: []const u8,
    k_proj: []const u8,
    v_proj: []const u8,
    o_proj: []const u8,
    
    // FFN projections (I2_S quantized)
    gate_proj: []const u8,
    up_proj: []const u8,
    down_proj: []const u8,
    
    // Norms (F32)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    
    // Dimensions
    hidden_size: usize,
    intermediate_size: usize,
    kv_dim: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// RMS Normalization
pub fn rmsNorm(input: []const f32, weight: []const f32, output: []f32, eps: f32) void {
    var sum_sq: f32 = 0.0;
    for (input) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(input.len)) + eps);
    const inv_rms = 1.0 / rms;
    
    for (input, weight, 0..) |x, w, i| {
        output[i] = x * inv_rms * w;
    }
}

/// Softmax
pub fn softmax(x: []f32) void {
    var max_val: f32 = x[0];
    for (x[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    
    var sum: f32 = 0.0;
    for (x) |*v| {
        v.* = @exp(v.* - max_val);
        sum += v.*;
    }
    
    const inv_sum = 1.0 / sum;
    for (x) |*v| {
        v.* *= inv_sum;
    }
}

/// SiLU activation
pub fn silu(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

/// RoPE (Rotary Position Embedding)
pub fn applyRoPE(q: []f32, k: []f32, pos: usize, head_dim: usize, theta: f32) void {
    const half_dim = head_dim / 2;
    
    for (0..half_dim) |i| {
        const freq = 1.0 / math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
        const angle = @as(f32, @floatFromInt(pos)) * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);
        
        // Rotate Q
        const q0 = q[i];
        const q1 = q[i + half_dim];
        q[i] = q0 * cos_val - q1 * sin_val;
        q[i + half_dim] = q0 * sin_val + q1 * cos_val;
        
        // Rotate K
        const k0 = k[i];
        const k1 = k[i + half_dim];
        k[i] = k0 * cos_val - k1 * sin_val;
        k[i + half_dim] = k0 * sin_val + k1 * cos_val;
    }
}

/// I2_S Ternary MatVec (no multiplication - only add/sub)
pub fn ternaryMatVecI2S(
    packed_weights: []const u8,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    const BLOCK_SIZE: usize = 256;
    const blocks_per_row = (cols + BLOCK_SIZE - 1) / BLOCK_SIZE;
    const bytes_per_block = 2 + (BLOCK_SIZE + 3) / 4;
    const bytes_per_row = blocks_per_row * bytes_per_block;
    
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * bytes_per_row;
        var col: usize = 0;
        var data_idx = row_start;
        
        for (0..blocks_per_row) |_| {
            if (data_idx + 2 > packed_weights.len) break;
            
            // Read f16 scale
            const scale_bits = @as(u16, packed_weights[data_idx]) |
                              (@as(u16, packed_weights[data_idx + 1]) << 8);
            const scale: f32 = @floatCast(@as(f16, @bitCast(scale_bits)));
            data_idx += 2;
            
            const block_cols = @min(BLOCK_SIZE, cols - col);
            const packed_bytes = (block_cols + 3) / 4;
            
            for (0..packed_bytes) |_| {
                if (data_idx >= packed_weights.len or col >= cols) break;
                const byte = packed_weights[data_idx];
                data_idx += 1;
                
                // Unroll 4 trits - NO MULTIPLICATION!
                inline for (0..4) |shift_idx| {
                    if (col >= cols) break;
                    const shift: u3 = @intCast(shift_idx * 2);
                    const trit = (byte >> shift) & 0x3;
                    
                    switch (trit) {
                        0b01 => sum += input[col] * scale, // +1
                        0b10 => sum -= input[col] * scale, // -1
                        else => {}, // 0: skip
                    }
                    col += 1;
                }
            }
        }
        
        output[row] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetFullModel = struct {
    allocator: std.mem.Allocator,
    config: BitNet2BConfig,
    
    // Embeddings (F32)
    embed_tokens: []f32,
    
    // Layers
    layers: []LayerWeights,
    
    // Final norm (F32)
    norm: []f32,
    
    // KV-Cache
    kv_cache: ?KVCache,
    
    // Inference buffers
    hidden_state: []f32,
    q_buf: []f32,
    k_buf: []f32,
    v_buf: []f32,
    attn_output: []f32,
    ffn_gate: []f32,
    ffn_up: []f32,
    logits: []f32,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNet2BConfig) !BitNetFullModel {
        const hidden = config.hidden_size;
        const inter = config.intermediate_size;
        const vocab = config.vocab_size;
        const kv_dim = config.kvDim();
        
        return BitNetFullModel{
            .allocator = allocator,
            .config = config,
            .embed_tokens = &[_]f32{},
            .layers = try allocator.alloc(LayerWeights, config.num_hidden_layers),
            .norm = &[_]f32{},
            .kv_cache = null,
            .hidden_state = try allocator.alloc(f32, hidden),
            .q_buf = try allocator.alloc(f32, hidden),
            .k_buf = try allocator.alloc(f32, kv_dim),
            .v_buf = try allocator.alloc(f32, kv_dim),
            .attn_output = try allocator.alloc(f32, hidden),
            .ffn_gate = try allocator.alloc(f32, inter),
            .ffn_up = try allocator.alloc(f32, inter),
            .logits = try allocator.alloc(f32, vocab),
        };
    }
    
    pub fn deinit(self: *BitNetFullModel) void {
        if (self.embed_tokens.len > 0) self.allocator.free(self.embed_tokens);
        if (self.norm.len > 0) self.allocator.free(self.norm);
        self.allocator.free(self.layers);
        self.allocator.free(self.hidden_state);
        self.allocator.free(self.q_buf);
        self.allocator.free(self.k_buf);
        self.allocator.free(self.v_buf);
        self.allocator.free(self.attn_output);
        self.allocator.free(self.ffn_gate);
        self.allocator.free(self.ffn_up);
        self.allocator.free(self.logits);
        if (self.kv_cache) |*cache| cache.deinit();
    }
    
    pub fn initKVCache(self: *BitNetFullModel, max_seq_len: usize) !void {
        self.kv_cache = try KVCache.init(self.allocator, self.config, max_seq_len);
    }
    
    pub fn resetKVCache(self: *BitNetFullModel) void {
        if (self.kv_cache) |*cache| cache.reset();
    }
    
    /// Full forward pass for single token
    pub fn forward(self: *BitNetFullModel, token_id: u32, position: usize) void {
        const hidden = self.config.hidden_size;
        const head_dim = self.config.headDim();
        const num_heads = self.config.num_attention_heads;
        const num_kv_heads = self.config.num_key_value_heads;
        const gqa_groups = self.config.gqaGroups();
        const inter = self.config.intermediate_size;
        
        // 1. Embedding lookup
        const embed_start = @as(usize, token_id) * hidden;
        if (embed_start + hidden <= self.embed_tokens.len) {
            @memcpy(self.hidden_state, self.embed_tokens[embed_start..embed_start + hidden]);
        } else {
            @memset(self.hidden_state, 0.0);
            return;
        }
        
        // 2. Process all 30 layers
        for (self.layers, 0..) |layer, layer_idx| {
            // Skip unloaded layers
            if (layer.input_layernorm.len == 0) continue;
            
            // Temporary buffer for normalized input
            var normed: [2560]f32 = undefined;
            const normed_slice = normed[0..hidden];
            
            // ═══════════════════════════════════════════════════════════════
            // ATTENTION BLOCK
            // ═══════════════════════════════════════════════════════════════
            
            // Input LayerNorm
            rmsNorm(self.hidden_state, layer.input_layernorm, normed_slice, self.config.rms_norm_eps);
            
            // Q, K, V projections (ternary matmul)
            ternaryMatVecI2S(layer.q_proj, normed_slice, self.q_buf, hidden, hidden);
            ternaryMatVecI2S(layer.k_proj, normed_slice, self.k_buf, self.config.kvDim(), hidden);
            ternaryMatVecI2S(layer.v_proj, normed_slice, self.v_buf, self.config.kvDim(), hidden);
            
            // Apply RoPE to Q and K
            for (0..num_heads) |h| {
                const q_start = h * head_dim;
                const kv_head = h / gqa_groups;
                const k_start = kv_head * head_dim;
                
                applyRoPE(
                    self.q_buf[q_start..q_start + head_dim],
                    self.k_buf[k_start..k_start + head_dim],
                    position,
                    head_dim,
                    self.config.rope_theta
                );
            }
            
            // Store K, V in cache
            if (self.kv_cache) |*cache| {
                cache.storeKV(layer_idx, self.k_buf, self.v_buf);
            }
            
            // Compute attention (GQA - Grouped Query Attention)
            @memset(self.attn_output, 0.0);
            const seq_len = if (self.kv_cache) |cache| cache.current_len + 1 else 1;
            
            for (0..num_heads) |h| {
                const q_start = h * head_dim;
                const kv_head = h / gqa_groups;
                
                // Compute attention scores for this head
                var attn_scores: [4096]f32 = undefined;
                const scores = attn_scores[0..seq_len];
                
                for (0..seq_len) |pos| {
                    var dot: f32 = 0.0;
                    
                    const k_slice = if (pos < position and self.kv_cache != null)
                        self.kv_cache.?.getK(layer_idx, pos)
                    else
                        self.k_buf;
                    
                    const k_start = kv_head * head_dim;
                    for (0..head_dim) |d| {
                        dot += self.q_buf[q_start + d] * k_slice[k_start + d];
                    }
                    
                    scores[pos] = dot / @sqrt(@as(f32, @floatFromInt(head_dim)));
                }
                
                // Softmax
                softmax(scores);
                
                // Weighted sum of V
                for (0..seq_len) |pos| {
                    const weight = scores[pos];
                    
                    const v_slice = if (pos < position and self.kv_cache != null)
                        self.kv_cache.?.getV(layer_idx, pos)
                    else
                        self.v_buf;
                    
                    const v_start = kv_head * head_dim;
                    for (0..head_dim) |d| {
                        self.attn_output[q_start + d] += weight * v_slice[v_start + d];
                    }
                }
            }
            
            // O projection
            var o_out: [2560]f32 = undefined;
            ternaryMatVecI2S(layer.o_proj, self.attn_output, o_out[0..hidden], hidden, hidden);
            
            // Residual connection
            for (self.hidden_state, o_out[0..hidden]) |*h, o| {
                h.* += o;
            }
            
            // ═══════════════════════════════════════════════════════════════
            // FFN BLOCK (SwiGLU)
            // ═══════════════════════════════════════════════════════════════
            
            // Post-attention LayerNorm
            rmsNorm(self.hidden_state, layer.post_attention_layernorm, normed_slice, self.config.rms_norm_eps);
            
            // Gate and Up projections
            ternaryMatVecI2S(layer.gate_proj, normed_slice, self.ffn_gate, inter, hidden);
            ternaryMatVecI2S(layer.up_proj, normed_slice, self.ffn_up, inter, hidden);
            
            // SwiGLU: gate * silu(up)
            for (self.ffn_gate, self.ffn_up) |*g, u| {
                g.* = g.* * silu(u);
            }
            
            // Down projection
            var down_out: [2560]f32 = undefined;
            ternaryMatVecI2S(layer.down_proj, self.ffn_gate, down_out[0..hidden], hidden, inter);
            
            // Residual connection
            for (self.hidden_state, down_out[0..hidden]) |*h, d| {
                h.* += d;
            }
        }
        
        // 3. Final LayerNorm
        rmsNorm(self.hidden_state, self.norm, self.hidden_state, self.config.rms_norm_eps);
        
        // 4. LM Head (tied to embeddings)
        const vocab = self.config.vocab_size;
        for (0..vocab) |v| {
            const embed_start_v = v * hidden;
            if (embed_start_v + hidden > self.embed_tokens.len) {
                self.logits[v] = -1000.0;
                continue;
            }
            
            var dot: f32 = 0.0;
            for (0..hidden) |d| {
                dot += self.hidden_state[d] * self.embed_tokens[embed_start_v + d];
            }
            self.logits[v] = dot;
        }
    }
    
    /// Sample next token
    pub fn sampleToken(self: *BitNetFullModel, temperature: f32, rng: *std.Random.DefaultPrng) u32 {
        if (temperature > 0.0) {
            for (self.logits) |*l| {
                l.* /= temperature;
            }
        }
        
        softmax(self.logits);
        
        const r = rng.random().float(f32);
        var cumsum: f32 = 0.0;
        
        for (self.logits, 0..) |p, i| {
            cumsum += p;
            if (cumsum >= r) {
                return @intCast(i);
            }
        }
        
        return 0;
    }
    
    /// Generate tokens autoregressively
    pub fn generate(
        self: *BitNetFullModel,
        prompt_tokens: []const u32,
        max_new_tokens: usize,
        temperature: f32,
    ) ![]u32 {
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var generated = std.ArrayList(u32).init(self.allocator);
        
        // Initialize KV-cache
        if (self.kv_cache == null) {
            try self.initKVCache(prompt_tokens.len + max_new_tokens + 10);
        }
        self.resetKVCache();
        
        // Prefill: process prompt
        for (prompt_tokens, 0..) |token, pos| {
            self.forward(token, pos);
            try generated.append(token);
            if (self.kv_cache) |*cache| cache.advance();
        }
        
        // Decode: generate new tokens
        var pos = prompt_tokens.len;
        for (0..max_new_tokens) |_| {
            const next_token = self.sampleToken(temperature, &rng);
            
            // Check EOS (128001 for Llama-style, 2 for others)
            if (next_token == 128001 or next_token == 2) break;
            
            try generated.append(next_token);
            self.forward(next_token, pos);
            if (self.kv_cache) |*cache| cache.advance();
            pos += 1;
        }
        
        return generated.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GGUF LOADER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadFromGGUF(allocator: std.mem.Allocator, model_path: []const u8) !BitNetFullModel {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET FULL LAYERS - GGUF LOADER                         ║\n", .{});
    std.debug.print("║     30 Layers | 2.4B Parameters | I2_S Quantization          ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    var reader = try gguf.GGUFReader.init(allocator, model_path);
    defer reader.deinit();
    
    // Extract config from metadata
    var config = BitNet2BConfig{};
    
    if (reader.metadata.get("bitnet-b1.58.vocab_size")) |v| {
        if (v == .uint32) config.vocab_size = v.uint32;
    }
    if (reader.metadata.get("bitnet-b1.58.embedding_length")) |v| {
        if (v == .uint32) config.hidden_size = v.uint32;
    }
    if (reader.metadata.get("bitnet-b1.58.feed_forward_length")) |v| {
        if (v == .uint32) config.intermediate_size = v.uint32;
    }
    if (reader.metadata.get("bitnet-b1.58.block_count")) |v| {
        if (v == .uint32) config.num_hidden_layers = v.uint32;
    }
    if (reader.metadata.get("bitnet-b1.58.attention.head_count")) |v| {
        if (v == .uint32) config.num_attention_heads = v.uint32;
    }
    if (reader.metadata.get("bitnet-b1.58.attention.head_count_kv")) |v| {
        if (v == .uint32) config.num_key_value_heads = v.uint32;
    }
    
    std.debug.print("Config loaded:\n", .{});
    std.debug.print("  vocab_size: {d}\n", .{config.vocab_size});
    std.debug.print("  hidden_size: {d}\n", .{config.hidden_size});
    std.debug.print("  num_layers: {d}\n", .{config.num_hidden_layers});
    std.debug.print("  num_heads: {d}\n", .{config.num_attention_heads});
    std.debug.print("  num_kv_heads: {d}\n", .{config.num_key_value_heads});
    
    var model = try BitNetFullModel.init(allocator, config);
    
    // Load embeddings
    std.debug.print("\nLoading tensors...\n", .{});
    var tensors_loaded: usize = 0;
    
    for (reader.tensors.items) |tensor| {
        if (std.mem.eql(u8, tensor.name, "token_embd.weight")) {
            const num_elements = tensor.numElements();
            model.embed_tokens = try allocator.alloc(f32, num_elements);
            
            try reader.file.seekTo(reader.data_offset + tensor.offset);
            
            if (tensor.tensor_type == .F32) {
                const bytes = std.mem.sliceAsBytes(model.embed_tokens);
                _ = try reader.file.read(bytes);
            } else if (tensor.tensor_type == .F16) {
                const f16_data = try allocator.alloc(f16, num_elements);
                defer allocator.free(f16_data);
                const bytes = std.mem.sliceAsBytes(f16_data);
                _ = try reader.file.read(bytes);
                for (f16_data, 0..) |v, i| {
                    model.embed_tokens[i] = @floatCast(v);
                }
            }
            
            tensors_loaded += 1;
            std.debug.print("  [✓] token_embd.weight ({d} elements)\n", .{num_elements});
        }
        
        if (std.mem.eql(u8, tensor.name, "output_norm.weight")) {
            const num_elements = tensor.numElements();
            model.norm = try allocator.alloc(f32, num_elements);
            
            try reader.file.seekTo(reader.data_offset + tensor.offset);
            const bytes = std.mem.sliceAsBytes(model.norm);
            _ = try reader.file.read(bytes);
            
            tensors_loaded += 1;
            std.debug.print("  [✓] output_norm.weight ({d} elements)\n", .{num_elements});
        }
    }
    
    // Load layer weights
    for (0..config.num_hidden_layers) |layer_idx| {
        var layer = &model.layers[layer_idx];
        
        // Initialize empty slices
        layer.* = LayerWeights{
            .q_proj = &[_]u8{},
            .k_proj = &[_]u8{},
            .v_proj = &[_]u8{},
            .o_proj = &[_]u8{},
            .gate_proj = &[_]u8{},
            .up_proj = &[_]u8{},
            .down_proj = &[_]u8{},
            .input_layernorm = &[_]f32{},
            .post_attention_layernorm = &[_]f32{},
            .hidden_size = config.hidden_size,
            .intermediate_size = config.intermediate_size,
            .kv_dim = config.kvDim(),
        };
        
        // Find and load layer tensors
        var layer_name_buf: [64]u8 = undefined;
        
        for (reader.tensors.items) |tensor| {
            // Check if tensor belongs to this layer
            const prefix = std.fmt.bufPrint(&layer_name_buf, "blk.{d}.", .{layer_idx}) catch continue;
            
            if (std.mem.startsWith(u8, tensor.name, prefix)) {
                const suffix = tensor.name[prefix.len..];
                
                // Load norm weights (F32)
                if (std.mem.eql(u8, suffix, "attn_norm.weight")) {
                    const num_elements = tensor.numElements();
                    const norm_buf = try allocator.alloc(f32, num_elements);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(std.mem.sliceAsBytes(norm_buf));
                    layer.input_layernorm = norm_buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "ffn_norm.weight")) {
                    const num_elements = tensor.numElements();
                    const norm_buf = try allocator.alloc(f32, num_elements);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(std.mem.sliceAsBytes(norm_buf));
                    layer.post_attention_layernorm = norm_buf;
                    tensors_loaded += 1;
                }
                
                // Load I2_S quantized weights
                if (std.mem.eql(u8, suffix, "attn_q.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.q_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "attn_k.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.k_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "attn_v.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.v_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "attn_output.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.o_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "ffn_gate.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.gate_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "ffn_up.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.up_proj = buf;
                    tensors_loaded += 1;
                }
                
                if (std.mem.eql(u8, suffix, "ffn_down.weight")) {
                    const size = tensor.size();
                    const buf = try allocator.alloc(u8, size);
                    try reader.file.seekTo(reader.data_offset + tensor.offset);
                    _ = try reader.file.read(buf);
                    layer.down_proj = buf;
                    tensors_loaded += 1;
                }
            }
        }
    }
    
    std.debug.print("\nLoaded {d} tensors total\n", .{tensors_loaded});
    std.debug.print("Model ready for inference!\n", .{});
    
    return model;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Coherent Generation Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const model_path = if (args.len > 1) args[1] else "models/bitnet-gguf/ggml-model-i2_s.gguf";
    
    std.debug.print("Loading model: {s}\n", .{model_path});
    
    var model = loadFromGGUF(allocator, model_path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();
    
    // Generate text
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("COHERENT TEXT GENERATION - Full 30 Layers\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    
    // Start with BOS token
    const prompt_tokens = [_]u32{ 128000 }; // BOS
    const temperature: f32 = 0.7;
    const max_tokens: usize = 100;
    
    std.debug.print("\nGenerating {d} tokens (temp={d:.1})...\n", .{max_tokens, temperature});
    
    var timer = try std.time.Timer.start();
    const generated = try model.generate(&prompt_tokens, max_tokens, temperature);
    defer allocator.free(generated);
    const gen_time = timer.read();
    
    std.debug.print("\nGenerated {d} tokens\n", .{generated.len});
    
    // Stats
    const tokens_per_sec = @as(f64, @floatFromInt(generated.len)) / (@as(f64, @floatFromInt(gen_time)) / 1e9);
    std.debug.print("\nStats:\n", .{});
    std.debug.print("  Time: {d:.2} ms\n", .{@as(f64, @floatFromInt(gen_time)) / 1e6});
    std.debug.print("  Speed: {d:.2} tok/s\n", .{tokens_per_sec});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "config dimensions" {
    const config = BitNet2BConfig{};
    try std.testing.expectEqual(@as(u32, 128), config.headDim());
    try std.testing.expectEqual(@as(u32, 640), config.kvDim());
    try std.testing.expectEqual(@as(u32, 4), config.gqaGroups());
}

test "kv cache init" {
    const allocator = std.testing.allocator;
    const config = BitNet2BConfig{};
    
    var cache = try KVCache.init(allocator, config, 512);
    defer cache.deinit();
    
    try std.testing.expectEqual(@as(usize, 30), cache.num_layers);
    try std.testing.expectEqual(@as(usize, 5), cache.num_kv_heads);
    try std.testing.expectEqual(@as(usize, 128), cache.head_dim);
}

test "rms norm" {
    var input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;
    
    rmsNorm(&input, &weight, &output, 1e-5);
    
    // Check normalized values are reasonable
    try std.testing.expect(output[0] > 0.3 and output[0] < 0.4);
    try std.testing.expect(output[3] > 1.4 and output[3] < 1.5);
}

test "softmax" {
    var x = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&x);
    
    var sum: f32 = 0.0;
    for (x) |v| sum += v;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
}

test "silu" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), silu(0.0), 0.001);
    try std.testing.expect(silu(1.0) > 0.7);
    try std.testing.expect(silu(-1.0) < -0.2);
}
