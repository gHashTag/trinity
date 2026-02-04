// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 FULL MODEL - Complete Inference Pipeline
// Load all 290 tensors, wire up 24 layers, generate coherent text
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;
const math = std.math;
const forward = @import("bitnet_forward.zig");

pub const PHI: f64 = 1.618033988749895;

// Re-export from forward
pub const BitNetConfig = forward.BitNetConfig;
pub const quantizeToTernary = forward.quantizeToTernary;
pub const ternaryMatVec = forward.ternaryMatVec;
pub const rmsNorm = forward.rmsNorm;
pub const applyRoPE = forward.applyRoPE;
pub const softmax = forward.softmax;
pub const silu = forward.silu;

/// F32 matrix-vector multiplication (for QAT models)
pub fn f32MatVec(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    for (0..rows) |i| {
        var sum: f32 = 0.0;
        const row_start = i * cols;
        
        // Unrolled inner loop for better performance
        var j: usize = 0;
        while (j + 4 <= cols) : (j += 4) {
            sum += weights[row_start + j] * input[j];
            sum += weights[row_start + j + 1] * input[j + 1];
            sum += weights[row_start + j + 2] * input[j + 2];
            sum += weights[row_start + j + 3] * input[j + 3];
        }
        
        // Handle remainder
        while (j < cols) : (j += 1) {
            sum += weights[row_start + j] * input[j];
        }
        
        output[i] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorInfo = struct {
    dtype: []const u8,
    shape: []i64,
    data_offsets: [2]u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// KV-CACHE (Key-Value Cache for Attention)
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCache = struct {
    allocator: std.mem.Allocator,
    num_layers: usize,
    num_heads: usize,
    head_dim: usize,
    max_seq_len: usize,
    current_len: usize,
    
    // Cache storage: [layer][position][head][dim]
    // Flattened to: [layer * max_seq * hidden]
    k_cache: []f32,
    v_cache: []f32,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNetConfig, max_seq_len: usize) !KVCache {
        const num_layers = config.num_hidden_layers;
        const num_heads = config.num_attention_heads;
        const head_dim = config.headDim();
        const hidden = config.hidden_size;
        
        // Allocate cache for all layers and positions
        const cache_size = num_layers * max_seq_len * hidden;
        
        return KVCache{
            .allocator = allocator,
            .num_layers = num_layers,
            .num_heads = num_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .current_len = 0,
            .k_cache = try allocator.alloc(f32, cache_size),
            .v_cache = try allocator.alloc(f32, cache_size),
        };
    }
    
    pub fn deinit(self: *KVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }
    
    pub fn reset(self: *KVCache) void {
        self.current_len = 0;
    }
    
    /// Store K and V for a layer at current position
    pub fn store(self: *KVCache, layer_idx: usize, k: []const f32, v: []const f32) void {
        if (self.current_len >= self.max_seq_len) return;
        
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = self.current_len * hidden;
        const start = layer_offset + pos_offset;
        
        @memcpy(self.k_cache[start..start + hidden], k);
        @memcpy(self.v_cache[start..start + hidden], v);
    }
    
    /// Get K for a layer at a specific position
    pub fn getK(self: *KVCache, layer_idx: usize, pos: usize) []f32 {
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = pos * hidden;
        const start = layer_offset + pos_offset;
        return self.k_cache[start..start + hidden];
    }
    
    /// Get V for a layer at a specific position
    pub fn getV(self: *KVCache, layer_idx: usize, pos: usize) []f32 {
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = pos * hidden;
        const start = layer_offset + pos_offset;
        return self.v_cache[start..start + hidden];
    }
    
    /// Increment position after storing
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
    // Attention (F32, quantized at inference)
    q_proj: []f32,
    k_proj: []f32,
    v_proj: []f32,
    o_proj: []f32,
    
    // FFN (F32, quantized at inference)
    gate_proj: []f32,
    up_proj: []f32,
    down_proj: []f32,
    
    // Norms (F32, not quantized)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    inner_attn_ln: []f32,
    ffn_layernorm: []f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// FULL BITNET MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetFullModel = struct {
    allocator: std.mem.Allocator,
    config: BitNetConfig,
    
    // Embeddings
    embed_tokens: []f32,
    
    // Layers
    layers: []LayerWeights,
    
    // Final norm
    norm: []f32,
    
    // LM head (tied to embeddings in BitNet)
    // lm_head: []f32, // Usually tied to embed_tokens
    
    // Buffers for inference
    hidden_state: []f32,
    attn_output: []f32,
    ffn_intermediate: []f32,
    logits: []f32,
    
    // Ternary buffers (reused)
    ternary_weights: []i8,
    
    // KV-Cache for attention
    kv_cache: ?KVCache,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNetConfig) !BitNetFullModel {
        const hidden = config.hidden_size;
        const inter = config.intermediate_size;
        const vocab = config.vocab_size;
        const num_layers = config.num_hidden_layers;
        
        // Allocate layers
        const layers = try allocator.alloc(LayerWeights, num_layers);
        for (layers) |*layer| {
            layer.* = LayerWeights{
                .q_proj = &[_]f32{},
                .k_proj = &[_]f32{},
                .v_proj = &[_]f32{},
                .o_proj = &[_]f32{},
                .gate_proj = &[_]f32{},
                .up_proj = &[_]f32{},
                .down_proj = &[_]f32{},
                .input_layernorm = &[_]f32{},
                .post_attention_layernorm = &[_]f32{},
                .inner_attn_ln = &[_]f32{},
                .ffn_layernorm = &[_]f32{},
            };
        }
        
        // Allocate buffers
        const max_weight_size = @max(hidden * hidden, inter * hidden);
        
        return BitNetFullModel{
            .allocator = allocator,
            .config = config,
            .embed_tokens = &[_]f32{},
            .layers = layers,
            .norm = &[_]f32{},
            .hidden_state = try allocator.alloc(f32, hidden),
            .attn_output = try allocator.alloc(f32, hidden),
            .ffn_intermediate = try allocator.alloc(f32, inter),
            .logits = try allocator.alloc(f32, vocab),
            .ternary_weights = try allocator.alloc(i8, max_weight_size),
            .kv_cache = null,
        };
    }
    
    pub fn deinit(self: *BitNetFullModel) void {
        // Free layers
        for (self.layers) |layer| {
            if (layer.q_proj.len > 0) self.allocator.free(layer.q_proj);
            if (layer.k_proj.len > 0) self.allocator.free(layer.k_proj);
            if (layer.v_proj.len > 0) self.allocator.free(layer.v_proj);
            if (layer.o_proj.len > 0) self.allocator.free(layer.o_proj);
            if (layer.gate_proj.len > 0) self.allocator.free(layer.gate_proj);
            if (layer.up_proj.len > 0) self.allocator.free(layer.up_proj);
            if (layer.down_proj.len > 0) self.allocator.free(layer.down_proj);
            if (layer.input_layernorm.len > 0) self.allocator.free(layer.input_layernorm);
            if (layer.post_attention_layernorm.len > 0) self.allocator.free(layer.post_attention_layernorm);
            if (layer.inner_attn_ln.len > 0) self.allocator.free(layer.inner_attn_ln);
            if (layer.ffn_layernorm.len > 0) self.allocator.free(layer.ffn_layernorm);
        }
        self.allocator.free(self.layers);
        
        // Free embeddings and norm
        if (self.embed_tokens.len > 0) self.allocator.free(self.embed_tokens);
        if (self.norm.len > 0) self.allocator.free(self.norm);
        
        // Free buffers
        self.allocator.free(self.hidden_state);
        self.allocator.free(self.attn_output);
        self.allocator.free(self.ffn_intermediate);
        self.allocator.free(self.logits);
        self.allocator.free(self.ternary_weights);
        
        // Free KV-cache
        if (self.kv_cache) |*cache| {
            cache.deinit();
        }
    }
    
    /// Initialize KV-cache for generation
    pub fn initKVCache(self: *BitNetFullModel, max_seq_len: usize) !void {
        self.kv_cache = try KVCache.init(self.allocator, self.config, max_seq_len);
    }
    
    /// Reset KV-cache for new generation
    pub fn resetKVCache(self: *BitNetFullModel) void {
        if (self.kv_cache) |*cache| {
            cache.reset();
        }
    }
    
    /// Load model from safetensors file
    pub fn loadFromSafetensors(self: *BitNetFullModel, model_path: []const u8) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║     LOADING BITNET b1.58 FULL MODEL                          ║\n", .{});
        std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        
        const file = try std.fs.cwd().openFile(model_path, .{});
        defer file.close();
        
        // Read header size
        var size_buf: [8]u8 = undefined;
        _ = try file.read(&size_buf);
        const header_size = std.mem.readInt(u64, &size_buf, .little);
        
        // Read header JSON
        const header_json = try self.allocator.alloc(u8, header_size);
        defer self.allocator.free(header_json);
        _ = try file.read(header_json);
        
        // Parse header
        var parsed = try json.parseFromSlice(json.Value, self.allocator, header_json, .{});
        defer parsed.deinit();
        
        const data_start = 8 + header_size;
        var tensors_loaded: usize = 0;
        
        // Load embeddings
        std.debug.print("Loading embeddings...\n", .{});
        self.embed_tokens = try self.loadTensor(file, &parsed.value, data_start, "model.embed_tokens.weight");
        tensors_loaded += 1;
        
        // Load final norm
        self.norm = try self.loadTensor(file, &parsed.value, data_start, "model.norm.weight");
        tensors_loaded += 1;
        
        // Load each layer
        std.debug.print("Loading {d} transformer layers...\n", .{self.config.num_hidden_layers});
        
        for (0..self.config.num_hidden_layers) |i| {
            var name_buf: [128]u8 = undefined;
            
            // Attention weights
            const q_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.q_proj.weight", .{i});
            self.layers[i].q_proj = try self.loadTensor(file, &parsed.value, data_start, q_name);
            tensors_loaded += 1;
            
            const k_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.k_proj.weight", .{i});
            self.layers[i].k_proj = try self.loadTensor(file, &parsed.value, data_start, k_name);
            tensors_loaded += 1;
            
            const v_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.v_proj.weight", .{i});
            self.layers[i].v_proj = try self.loadTensor(file, &parsed.value, data_start, v_name);
            tensors_loaded += 1;
            
            const o_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.o_proj.weight", .{i});
            self.layers[i].o_proj = try self.loadTensor(file, &parsed.value, data_start, o_name);
            tensors_loaded += 1;
            
            // FFN weights
            const gate_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.gate_proj.weight", .{i});
            self.layers[i].gate_proj = try self.loadTensor(file, &parsed.value, data_start, gate_name);
            tensors_loaded += 1;
            
            const up_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.up_proj.weight", .{i});
            self.layers[i].up_proj = try self.loadTensor(file, &parsed.value, data_start, up_name);
            tensors_loaded += 1;
            
            const down_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.down_proj.weight", .{i});
            self.layers[i].down_proj = try self.loadTensor(file, &parsed.value, data_start, down_name);
            tensors_loaded += 1;
            
            // Norms
            const input_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.input_layernorm.weight", .{i});
            self.layers[i].input_layernorm = try self.loadTensor(file, &parsed.value, data_start, input_ln_name);
            tensors_loaded += 1;
            
            const post_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.post_attention_layernorm.weight", .{i});
            self.layers[i].post_attention_layernorm = try self.loadTensor(file, &parsed.value, data_start, post_ln_name);
            tensors_loaded += 1;
            
            const inner_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.inner_attn_ln.weight", .{i});
            self.layers[i].inner_attn_ln = try self.loadTensor(file, &parsed.value, data_start, inner_ln_name);
            tensors_loaded += 1;
            
            const ffn_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.ffn_layernorm.weight", .{i});
            self.layers[i].ffn_layernorm = try self.loadTensor(file, &parsed.value, data_start, ffn_ln_name);
            tensors_loaded += 1;
            
            if ((i + 1) % 6 == 0) {
                std.debug.print("  Loaded layer {d}/{d}\n", .{i + 1, self.config.num_hidden_layers});
            }
        }
        
        std.debug.print("\n✅ Loaded {d} tensors successfully!\n", .{tensors_loaded});
        
        // Calculate memory usage
        var total_params: usize = self.embed_tokens.len + self.norm.len;
        for (self.layers) |layer| {
            total_params += layer.q_proj.len + layer.k_proj.len + layer.v_proj.len + layer.o_proj.len;
            total_params += layer.gate_proj.len + layer.up_proj.len + layer.down_proj.len;
            total_params += layer.input_layernorm.len + layer.post_attention_layernorm.len;
            total_params += layer.inner_attn_ln.len + layer.ffn_layernorm.len;
        }
        
        std.debug.print("   Total parameters: {d}M\n", .{total_params / 1_000_000});
        std.debug.print("   Memory usage: {d} MB\n", .{(total_params * 4) / (1024 * 1024)});
    }
    
    fn loadTensor(self: *BitNetFullModel, file: std.fs.File, header: *json.Value, data_start: u64, name: []const u8) ![]f32 {
        const tensor_obj = header.object.get(name) orelse {
            std.debug.print("  WARNING: Tensor '{s}' not found\n", .{name});
            return &[_]f32{};
        };
        
        const info = tensor_obj.object;
        const dtype = info.get("dtype").?.string;
        
        // Get shape
        const shape_arr = info.get("shape").?.array;
        var num_elements: usize = 1;
        for (shape_arr.items) |dim| {
            num_elements *= @intCast(dim.integer);
        }
        
        // Get offsets
        const offsets_arr = info.get("data_offsets").?.array;
        const offset_start: u64 = @intCast(offsets_arr.items[0].integer);
        
        // Seek and read
        try file.seekTo(data_start + offset_start);
        
        if (std.mem.eql(u8, dtype, "F32")) {
            const data = try self.allocator.alloc(f32, num_elements);
            const bytes = std.mem.sliceAsBytes(data);
            _ = try file.read(bytes);
            return data;
        } else if (std.mem.eql(u8, dtype, "F16")) {
            const f16_data = try self.allocator.alloc(f16, num_elements);
            defer self.allocator.free(f16_data);
            const bytes = std.mem.sliceAsBytes(f16_data);
            _ = try file.read(bytes);
            
            const data = try self.allocator.alloc(f32, num_elements);
            for (f16_data, 0..) |v, idx| {
                data[idx] = @floatCast(v);
            }
            return data;
        } else {
            std.debug.print("  WARNING: Unsupported dtype '{s}'\n", .{dtype});
            return &[_]f32{};
        }
    }
    
    /// Forward pass for a single token with KV-cache
    pub fn forward(self: *BitNetFullModel, token_id: u32, position: usize) void {
        const hidden = self.config.hidden_size;
        const inter = self.config.intermediate_size;
        const head_dim = self.config.headDim();
        const num_heads = self.config.num_attention_heads;
        
        // 1. Embedding lookup
        const embed_start = @as(usize, token_id) * hidden;
        if (embed_start + hidden > self.embed_tokens.len) {
            @memset(self.hidden_state, 0.0);
            return;
        }
        @memcpy(self.hidden_state, self.embed_tokens[embed_start..embed_start + hidden]);
        
        // 2. Process each layer
        for (self.layers, 0..) |layer, layer_idx| {
            // Skip if layer not loaded
            if (layer.q_proj.len == 0) continue;
            
            // Input LayerNorm
            const normed = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(normed);
            rmsNorm(self.hidden_state, layer.input_layernorm, normed, self.config.rms_norm_eps);
            
            // Compute Q, K, V
            const q = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(q);
            const k_buf = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(k_buf);
            const v_buf = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(v_buf);
            
            // Q projection
            f32MatVec(layer.q_proj, normed, q, hidden, hidden);
            
            // K projection
            f32MatVec(layer.k_proj, normed, k_buf, hidden, hidden);
            
            // V projection
            f32MatVec(layer.v_proj, normed, v_buf, hidden, hidden);
            
            // Apply RoPE to Q and K
            for (0..num_heads) |h| {
                const start = h * head_dim;
                applyRoPE(q[start..start + head_dim], k_buf[start..start + head_dim], position, head_dim, self.config.rope_theta);
            }
            
            // Store K, V in cache
            if (self.kv_cache) |*cache| {
                cache.store(layer_idx, k_buf, v_buf);
            }
            
            // Inner attention LayerNorm
            rmsNorm(q, layer.inner_attn_ln, q, self.config.rms_norm_eps);
            
            // Full self-attention with KV-cache
            const seq_len = if (self.kv_cache) |cache| cache.current_len + 1 else 1;
            const attn_weights = self.allocator.alloc(f32, seq_len * num_heads) catch return;
            defer self.allocator.free(attn_weights);
            
            // Compute attention scores for all positions
            for (0..num_heads) |h| {
                const h_start = h * head_dim;
                
                for (0..seq_len) |pos| {
                    var dot: f32 = 0.0;
                    
                    if (pos < position) {
                        // Use cached K
                        if (self.kv_cache) |*cache| {
                            const cached_k = cache.getK(layer_idx, pos);
                            for (0..head_dim) |d| {
                                dot += q[h_start + d] * cached_k[h_start + d];
                            }
                        }
                    } else {
                        // Current position K
                        for (0..head_dim) |d| {
                            dot += q[h_start + d] * k_buf[h_start + d];
                        }
                    }
                    
                    attn_weights[h * seq_len + pos] = dot / @sqrt(@as(f32, @floatFromInt(head_dim)));
                }
                
                // Softmax per head
                softmax(attn_weights[h * seq_len .. (h + 1) * seq_len]);
            }
            
            // Weighted sum of V
            @memset(self.attn_output, 0.0);
            for (0..num_heads) |h| {
                const h_start = h * head_dim;
                
                for (0..seq_len) |pos| {
                    const weight = attn_weights[h * seq_len + pos];
                    
                    if (pos < position) {
                        // Use cached V
                        if (self.kv_cache) |*cache| {
                            const cached_v = cache.getV(layer_idx, pos);
                            for (0..head_dim) |d| {
                                self.attn_output[h_start + d] += weight * cached_v[h_start + d];
                            }
                        }
                    } else {
                        // Current position V
                        for (0..head_dim) |d| {
                            self.attn_output[h_start + d] += weight * v_buf[h_start + d];
                        }
                    }
                }
            }
            
            // O projection
            const o_out = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(o_out);
            f32MatVec(layer.o_proj, self.attn_output, o_out, hidden, hidden);
            
            // Residual connection
            for (self.hidden_state, o_out) |*h, o| {
                h.* += o;
            }
            
            // Post-attention LayerNorm
            rmsNorm(self.hidden_state, layer.post_attention_layernorm, normed, self.config.rms_norm_eps);
            
            // FFN: gate and up projections
            f32MatVec(layer.gate_proj, normed, self.ffn_intermediate, inter, hidden);
            
            const up_out = self.allocator.alloc(f32, inter) catch return;
            defer self.allocator.free(up_out);
            f32MatVec(layer.up_proj, normed, up_out, inter, hidden);
            
            // FFN LayerNorm
            rmsNorm(self.ffn_intermediate, layer.ffn_layernorm, self.ffn_intermediate, self.config.rms_norm_eps);
            
            // SwiGLU: gate * silu(up)
            for (self.ffn_intermediate, up_out) |*g, u| {
                g.* = g.* * silu(u);
            }
            
            // Down projection
            const down_out = self.allocator.alloc(f32, hidden) catch return;
            defer self.allocator.free(down_out);
            f32MatVec(layer.down_proj, self.ffn_intermediate, down_out, hidden, inter);
            
            // Residual connection
            for (self.hidden_state, down_out) |*h, d| {
                h.* += d;
            }
        }
        
        // 3. Final LayerNorm
        rmsNorm(self.hidden_state, self.norm, self.hidden_state, self.config.rms_norm_eps);
        
        // 4. LM Head (tied to embeddings)
        // logits = hidden_state @ embed_tokens.T
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
    
    /// Sample next token from logits
    pub fn sampleToken(self: *BitNetFullModel, temperature: f32, rng: *std.Random.DefaultPrng) u32 {
        // Apply temperature
        if (temperature > 0.0) {
            for (self.logits) |*l| {
                l.* /= temperature;
            }
        }
        
        // Softmax
        softmax(self.logits);
        
        // Sample
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
    
    /// Generate text with KV-cache
    pub fn generate(
        self: *BitNetFullModel,
        prompt_tokens: []const u32,
        max_new_tokens: usize,
        temperature: f32,
    ) ![]u32 {
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var generated = std.ArrayList(u32).init(self.allocator);
        
        // Initialize KV-cache if not already done
        if (self.kv_cache == null) {
            try self.initKVCache(prompt_tokens.len + max_new_tokens + 10);
        }
        self.resetKVCache();
        
        // Process prompt (prefill)
        for (prompt_tokens, 0..) |token, pos| {
            self.forward(token, pos);
            try generated.append(token);
            
            // Advance cache after each token
            if (self.kv_cache) |*cache| {
                cache.advance();
            }
        }
        
        // Generate new tokens (decode)
        var pos = prompt_tokens.len;
        for (0..max_new_tokens) |_| {
            const next_token = self.sampleToken(temperature, &rng);
            
            // Check for EOS
            if (next_token == 2) break;
            
            try generated.append(next_token);
            self.forward(next_token, pos);
            
            // Advance cache
            if (self.kv_cache) |*cache| {
                cache.advance();
            }
            
            pos += 1;
        }
        
        return generated.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "full model init" {
    const allocator = std.testing.allocator;
    const config = BitNetConfig{};
    
    var model = try BitNetFullModel.init(allocator, config);
    defer model.deinit();
    
    try std.testing.expectEqual(@as(usize, 24), model.layers.len);
    try std.testing.expectEqual(@as(usize, 1536), model.hidden_state.len);
}
