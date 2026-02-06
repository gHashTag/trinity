// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 FULL LAYERS v2.0 - Complete 30-Layer Transformer for 2B Model
// Wire all layers with KV-cache for coherent autoregressive generation
//
// STABILITY FIXES (from IGLA dogfooding):
// 1. Clamp Q/K/V after projection (max ±32) - prevents attention explosion
// 2. Clamp gate before relu² (max ±10) + output (max ±100) - prevents FFN explosion
// 3. Hidden state guard (max ±200) - prevents cascading instability across layers
//
// Target: Stable 100+ layer forward pass (no NaN/overflow)
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

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
    // Attention projections (U8 packed ternary, 4 trits per byte)
    q_proj: []const u8,
    k_proj: []const u8,
    v_proj: []const u8,
    o_proj: []const u8,

    // FFN projections (U8 packed ternary)
    gate_proj: []const u8,
    up_proj: []const u8,
    down_proj: []const u8,

    // Per-tensor scales
    q_scale: f32,
    k_scale: f32,
    v_scale: f32,
    o_scale: f32,
    gate_scale: f32,
    up_scale: f32,
    down_scale: f32,

    // Norms (F32)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    attn_sub_norm: []f32,
    ffn_sub_norm: []f32,

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

/// SiLU activation (kept for compatibility)
pub fn silu(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

/// ReLU² activation (BitNet b1.58 uses this)
pub fn relu2(x: f32) f32 {
    const r = @max(x, 0.0);
    return r * r;
}

/// 8-bit activation quantization (absmax per-tensor)
pub fn quantizeActivations(input: []f32) f32 {
    var max_abs: f32 = 0.0;
    for (input) |x| {
        const abs_x = @abs(x);
        if (abs_x > max_abs) max_abs = abs_x;
    }
    if (max_abs == 0.0) return 0.0;

    const quant_scale = 127.0 / max_abs;
    const dequant_scale = max_abs / 127.0;

    for (input) |*x| {
        var q = x.* * quant_scale;
        q = @round(q);
        q = @max(-128.0, @min(127.0, q));
        x.* = q * dequant_scale;
    }
    return max_abs;
}

/// RoPE (Rotary Position Embedding) for a single head
pub fn applyRoPESingle(vec: []f32, pos: usize, head_dim: usize, theta: f32) void {
    const half_dim = head_dim / 2;

    for (0..half_dim) |i| {
        const freq = 1.0 / math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
        const angle = @as(f32, @floatFromInt(pos)) * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);

        const v0 = vec[i];
        const v1 = vec[i + half_dim];
        vec[i] = v0 * cos_val - v1 * sin_val;
        vec[i + half_dim] = v0 * sin_val + v1 * cos_val;
    }
}

/// Ternary MatVec for packed U8 format from safetensors
/// Format: packed_weights[packed_row, col] has 4 trits for output neurons
///         packed_row*4+0 .. packed_row*4+3 at input column col
/// Encoding: 00=0, 01=+1, 10=-1
/// output[i] = scale * sum_j(trit[i,j] * input[j])
pub fn ternaryMatVecPacked(
    packed_weights: []const u8,
    input: []const f32,
    output: []f32,
    packed_rows: usize,
    in_features: usize,
    scale: f32,
) void {
    for (0..packed_rows) |pr| {
        var sums: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 };
        const row_offset = pr * in_features;

        for (0..in_features) |j| {
            if (row_offset + j >= packed_weights.len) break;
            const byte = packed_weights[row_offset + j];
            const inp = input[j];

            // Extract 4 trits from byte
            inline for (0..4) |k| {
                const shift: u3 = @intCast(k * 2);
                const trit = (byte >> shift) & 0x3;
                switch (trit) {
                    0b01 => sums[k] += inp, // +1
                    0b10 => sums[k] -= inp, // -1
                    else => {}, // 0
                }
            }
        }

        // Write 4 output values
        const out_base = pr * 4;
        inline for (0..4) |k| {
            if (out_base + k < output.len) {
                output[out_base + k] = sums[k] * scale;
            }
        }
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

    // Output weight (F32) - separate LM head or tied to embeddings
    output_weight: []f32,

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
            .output_weight = &[_]f32{},
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
        if (self.output_weight.len > 0 and self.output_weight.ptr != self.embed_tokens.ptr)
            self.allocator.free(self.output_weight);
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
        const hidden: usize = self.config.hidden_size;
        const head_dim: usize = self.config.headDim();
        const num_heads: usize = self.config.num_attention_heads;
        const num_kv_heads: usize = self.config.num_key_value_heads;
        const gqa_groups: usize = self.config.gqaGroups();
        const inter: usize = self.config.intermediate_size;
        const kv_dim: usize = self.config.kvDim();

        // 1. Embedding lookup
        const embed_start = @as(usize, token_id) * hidden;
        if (embed_start + hidden <= self.embed_tokens.len) {
            @memcpy(self.hidden_state, self.embed_tokens[embed_start..embed_start + hidden]);
        } else {
            @memset(self.hidden_state, 0.0);
            return;
        }

        // 2. Process all layers
        for (self.layers, 0..) |layer, layer_idx| {
            if (layer.input_layernorm.len == 0) continue;

            var normed: [2560]f32 = undefined;
            const normed_slice = normed[0..hidden];

            // ═══════════════════════════════════════════════════════════════
            // ATTENTION BLOCK
            // ═══════════════════════════════════════════════════════════════

            // Input LayerNorm → Q/K/V projections (NO activation quant - causes instability!)
            rmsNorm(self.hidden_state, layer.input_layernorm, normed_slice, self.config.rms_norm_eps);

            ternaryMatVecPacked(layer.q_proj, normed_slice, self.q_buf, hidden / 4, hidden, layer.q_scale);
            ternaryMatVecPacked(layer.k_proj, normed_slice, self.k_buf, kv_dim / 4, hidden, layer.k_scale);
            ternaryMatVecPacked(layer.v_proj, normed_slice, self.v_buf, kv_dim / 4, hidden, layer.v_scale);

            // STABILITY FIX 1: Clamp Q/K/V after projection (prevents attention explosion)
            const clamp_qkv: f32 = 32.0;
            for (self.q_buf) |*v| v.* = math.clamp(v.*, -clamp_qkv, clamp_qkv);
            for (self.k_buf) |*v| v.* = math.clamp(v.*, -clamp_qkv, clamp_qkv);
            for (self.v_buf) |*v| v.* = math.clamp(v.*, -clamp_qkv, clamp_qkv);

            // Apply RoPE: Q heads individually, K heads once each
            for (0..num_heads) |h| {
                const q_start = h * head_dim;
                applyRoPESingle(self.q_buf[q_start .. q_start + head_dim], position, head_dim, self.config.rope_theta);
            }
            for (0..num_kv_heads) |kh| {
                const k_start = kh * head_dim;
                applyRoPESingle(self.k_buf[k_start .. k_start + head_dim], position, head_dim, self.config.rope_theta);
            }

            // Store K, V in cache
            if (self.kv_cache) |*cache| {
                cache.storeKV(layer_idx, self.k_buf, self.v_buf);
            }

            // Compute attention (GQA)
            @memset(self.attn_output, 0.0);
            const seq_len = if (self.kv_cache) |cache| cache.current_len + 1 else 1;

            for (0..num_heads) |h| {
                const q_start = h * head_dim;
                const kv_head = h / gqa_groups;

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

                softmax(scores);

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

            // attn_sub_norm → O projection (NO activation quant)
            if (layer.attn_sub_norm.len > 0) {
                rmsNorm(self.attn_output, layer.attn_sub_norm, self.attn_output, self.config.rms_norm_eps);
            }
            var o_out: [2560]f32 = undefined;
            ternaryMatVecPacked(layer.o_proj, self.attn_output, o_out[0..hidden], hidden / 4, hidden, layer.o_scale);

            // Residual connection
            for (self.hidden_state, o_out[0..hidden]) |*hs, o| {
                hs.* += o;
            }

            // ═══════════════════════════════════════════════════════════════
            // FFN BLOCK (Gated MLP with ReLU²)
            // ═══════════════════════════════════════════════════════════════

            // Post-attention LayerNorm (NO activation quant)
            rmsNorm(self.hidden_state, layer.post_attention_layernorm, normed_slice, self.config.rms_norm_eps);

            // Gate and Up projections
            ternaryMatVecPacked(layer.gate_proj, normed_slice, self.ffn_gate, inter / 4, hidden, layer.gate_scale);
            ternaryMatVecPacked(layer.up_proj, normed_slice, self.ffn_up, inter / 4, hidden, layer.up_scale);

            // STABILITY FIX 2: Clamp gate before relu² (prevents explosion)
            const clamp_gate: f32 = 10.0;
            for (self.ffn_gate) |*g| g.* = math.clamp(g.*, -clamp_gate, clamp_gate);

            // Gated MLP: relu²(gate) * up
            for (self.ffn_gate, self.ffn_up) |*g, u| {
                g.* = relu2(g.*) * u;
            }

            // STABILITY FIX 2b: Clamp output after relu²*up (prevents FFN explosion)
            const clamp_ffn: f32 = 100.0;
            for (self.ffn_gate) |*v| v.* = math.clamp(v.*, -clamp_ffn, clamp_ffn);

            // FFN sub-norm → down projection (NO activation quant)
            if (layer.ffn_sub_norm.len > 0) {
                rmsNorm(self.ffn_gate, layer.ffn_sub_norm, self.ffn_gate, self.config.rms_norm_eps);
            }

            var down_out: [2560]f32 = undefined;
            ternaryMatVecPacked(layer.down_proj, self.ffn_gate, down_out[0..hidden], hidden / 4, inter, layer.down_scale);

            // Residual connection
            for (self.hidden_state, down_out[0..hidden]) |*hs, d| {
                hs.* += d;
            }

            // STABILITY FIX 3: Hidden state guard (prevents cascading instability across layers)
            const clamp_hidden: f32 = 200.0;
            for (self.hidden_state) |*h| {
                h.* = math.clamp(h.*, -clamp_hidden, clamp_hidden);
            }
        }

        // 3. Final LayerNorm
        rmsNorm(self.hidden_state, self.norm, self.hidden_state, self.config.rms_norm_eps);

        // 4. LM Head
        const lm_weight = if (self.output_weight.len > 0) self.output_weight else self.embed_tokens;
        const vocab: usize = self.config.vocab_size;
        for (0..vocab) |v| {
            const w_start = v * hidden;
            if (w_start + hidden > lm_weight.len) {
                self.logits[v] = -1000.0;
                continue;
            }

            var dot: f32 = 0.0;
            for (0..hidden) |d| {
                dot += self.hidden_state[d] * lm_weight[w_start + d];
            }
            self.logits[v] = dot;
        }
    }

    /// Sample next token with temperature
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
        var generated: std.ArrayList(u32) = .empty;

        if (self.kv_cache == null) {
            try self.initKVCache(prompt_tokens.len + max_new_tokens + 10);
        }
        self.resetKVCache();

        // Prefill
        for (prompt_tokens, 0..) |token, pos| {
            self.forward(token, pos);
            try generated.append(self.allocator, token);
            if (self.kv_cache) |*cache| cache.advance();
        }

        // Decode
        var pos = prompt_tokens.len;
        for (0..max_new_tokens) |_| {
            const next_token = self.sampleToken(temperature, &rng);

            if (next_token >= 128000) break; // Any special token = stop

            try generated.append(self.allocator, next_token);
            self.forward(next_token, pos);
            if (self.kv_cache) |*cache| cache.advance();
            pos += 1;
        }

        return generated.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BINARY FORMAT LOADER (.bin from convert_safetensors.py)
// ═══════════════════════════════════════════════════════════════════════════════

fn readF32Array(file: std.fs.File, allocator: std.mem.Allocator, count: usize) ![]f32 {
    const buf = try allocator.alloc(f32, count);
    const bytes = std.mem.sliceAsBytes(buf);
    const bytes_read = try file.readAll(bytes);
    if (bytes_read != bytes.len) return error.UnexpectedEOF;
    return buf;
}

fn readU8Array(file: std.fs.File, allocator: std.mem.Allocator, count: usize) ![]u8 {
    const buf = try allocator.alloc(u8, count);
    const bytes_read = try file.readAll(buf);
    if (bytes_read != buf.len) return error.UnexpectedEOF;
    return buf;
}

fn readU32(file: std.fs.File) !u32 {
    var buf: [4]u8 = undefined;
    const n = try file.readAll(&buf);
    if (n != 4) return error.UnexpectedEOF;
    return std.mem.readInt(u32, &buf, .little);
}

fn readF32(file: std.fs.File) !f32 {
    var buf: [4]u8 = undefined;
    const n = try file.readAll(&buf);
    if (n != 4) return error.UnexpectedEOF;
    return @bitCast(std.mem.readInt(u32, &buf, .little));
}

pub fn loadFromBin(allocator: std.mem.Allocator, model_path: []const u8) !BitNetFullModel {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET b1.58 2B — SAFETENSORS LOADER                    ║\n", .{});
    std.debug.print("║     30 Layers | GQA | ReLU² | Per-Tensor Scale              ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    const file = try std.fs.cwd().openFile(model_path, .{});
    defer file.close();

    // Read header
    const magic = try readU32(file);
    if (magic != 0x544E5442) return error.InvalidMagic;

    var config = BitNet2BConfig{};
    config.hidden_size = try readU32(file);
    config.intermediate_size = try readU32(file);
    config.num_hidden_layers = try readU32(file);
    config.num_attention_heads = try readU32(file);
    config.num_key_value_heads = try readU32(file);
    config.vocab_size = try readU32(file);
    config.rope_theta = try readF32(file);
    config.rms_norm_eps = try readF32(file);

    const hidden: usize = config.hidden_size;
    const inter: usize = config.intermediate_size;
    const kv_dim: usize = config.kvDim();
    const vocab: usize = config.vocab_size;

    std.debug.print("Config:\n", .{});
    std.debug.print("  vocab={d} hidden={d} inter={d} layers={d}\n", .{ vocab, hidden, inter, config.num_hidden_layers });
    std.debug.print("  heads={d} kv_heads={d} kv_dim={d}\n", .{ config.num_attention_heads, config.num_key_value_heads, kv_dim });
    std.debug.print("  rope_theta={d:.1} rms_norm_eps={e}\n", .{ config.rope_theta, config.rms_norm_eps });

    var model = try BitNetFullModel.init(allocator, config);

    // Load embed_tokens
    std.debug.print("\nLoading embed_tokens [{d}x{d}]...\n", .{ vocab, hidden });
    model.embed_tokens = try readF32Array(file, allocator, vocab * hidden);

    // Load output norm
    std.debug.print("Loading output_norm [{d}]...\n", .{hidden});
    model.norm = try readF32Array(file, allocator, hidden);

    // Load output weight (tied or separate)
    std.debug.print("Loading output_weight [{d}x{d}]...\n", .{ vocab, hidden });
    model.output_weight = try readF32Array(file, allocator, vocab * hidden);

    // Load layers
    std.debug.print("\nLoading {d} layers...\n", .{config.num_hidden_layers});

    for (0..config.num_hidden_layers) |layer_idx| {
        var layer = &model.layers[layer_idx];

        // Norms
        layer.input_layernorm = try readF32Array(file, allocator, hidden);
        layer.post_attention_layernorm = try readF32Array(file, allocator, hidden);
        layer.attn_sub_norm = try readF32Array(file, allocator, hidden);
        layer.ffn_sub_norm = try readF32Array(file, allocator, inter);

        // Scales
        layer.q_scale = try readF32(file);
        layer.k_scale = try readF32(file);
        layer.v_scale = try readF32(file);
        layer.o_scale = try readF32(file);
        layer.gate_scale = try readF32(file);
        layer.up_scale = try readF32(file);
        layer.down_scale = try readF32(file);

        // Weight tensors (U8 packed trits)
        layer.q_proj = try readU8Array(file, allocator, (hidden / 4) * hidden);
        layer.k_proj = try readU8Array(file, allocator, (kv_dim / 4) * hidden);
        layer.v_proj = try readU8Array(file, allocator, (kv_dim / 4) * hidden);
        layer.o_proj = try readU8Array(file, allocator, (hidden / 4) * hidden);
        layer.gate_proj = try readU8Array(file, allocator, (inter / 4) * hidden);
        layer.up_proj = try readU8Array(file, allocator, (inter / 4) * hidden);
        layer.down_proj = try readU8Array(file, allocator, (hidden / 4) * inter);

        layer.hidden_size = hidden;
        layer.intermediate_size = inter;
        layer.kv_dim = kv_dim;

        if (layer_idx == 0 or layer_idx == 29) {
            std.debug.print("  Layer {d}: scales=[{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4}]\n", .{
                layer_idx,
                layer.q_scale, layer.k_scale, layer.v_scale, layer.o_scale,
                layer.gate_scale, layer.up_scale, layer.down_scale,
            });
        } else if (layer_idx == 1) {
            std.debug.print("  ...\n", .{});
        }
    }

    std.debug.print("\nModel loaded! Ready for inference.\n", .{});
    return model;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER (JSON-based BPE from HuggingFace)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tokenizer = @import("sentencepiece_tokenizer.zig").SentencePieceTokenizer;

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Coherent Generation with Tokenizer
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const model_path = if (args.len > 1) args[1] else "models/bitnet-2b.bin";
    const tokenizer_path = if (args.len > 2) args[2] else "models/microsoft-bitnet-2b/tokenizer.json";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     BITNET b1.58 2B — COHERENT GENERATION TEST              ║\n", .{});
    std.debug.print("║     30 Layers | GQA | ReLU² | Per-Tensor Scale              ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    std.debug.print("\nLoading model: {s}\n", .{model_path});
    var model = loadFromBin(allocator, model_path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    std.debug.print("Loading tokenizer: {s}\n", .{tokenizer_path});
    var tokenizer = Tokenizer.load(allocator, tokenizer_path) catch |err| {
        std.debug.print("Error loading tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    std.debug.print("Tokenizer ready: {d} tokens (BOS={d}, EOS={d})\n", .{
        tokenizer.vocab.count(), tokenizer.bos_token_id, tokenizer.eos_token_id,
    });

    // ═══════════════════════════════════════════════════════════════
    // COHERENT GENERATION TESTS
    // ═══════════════════════════════════════════════════════════════

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     COHERENT GENERATION RESULTS                              \n", .{});
    std.debug.print("     Fixes: Safetensors U8 trits + Per-Tensor Scale           \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    const prompts = [_][]const u8{
        "Hello, my name is",
        "The capital of France is",
        "Water boils at a temperature of",
        "The meaning of life is",
        "In machine learning, a neural network",
        "The quick brown fox",
        "Once upon a time in a land far away",
        "Python is a programming language that",
        "The largest planet in our solar system is",
        "To be or not to be, that is",
        "Artificial intelligence will change",
        "The best way to learn programming is",
    };

    const max_tokens: usize = 50;
    const temperature: f32 = 0.7;

    for (prompts, 0..) |prompt_text, test_idx| {
        std.debug.print("\n[Test {d}] Prompt: \"{s}\"\n", .{ test_idx + 1, prompt_text });

        // Encode prompt
        const prompt_tokens = tokenizer.encode(prompt_text) catch |err| {
            std.debug.print("  Encode error: {}\n", .{err});
            continue;
        };
        defer allocator.free(prompt_tokens);

        std.debug.print("  Prompt tokens ({d}): ", .{prompt_tokens.len});
        for (prompt_tokens) |t| std.debug.print("{d} ", .{t});
        std.debug.print("\n", .{});

        // Generate
        var timer = try std.time.Timer.start();
        const generated = model.generate(prompt_tokens, max_tokens, temperature) catch |err| {
            std.debug.print("  Generate error: {}\n", .{err});
            continue;
        };
        defer allocator.free(generated);
        const gen_ns = timer.read();

        // Decode
        const new_tokens = generated[prompt_tokens.len..];
        const gen_ms = @as(f64, @floatFromInt(gen_ns)) / 1e6;
        const tok_per_sec = if (gen_ns > 0)
            @as(f64, @floatFromInt(new_tokens.len)) / (@as(f64, @floatFromInt(gen_ns)) / 1e9)
        else
            0.0;

        // Decode full text
        const full_text = tokenizer.decode(generated) catch "?decode error?";
        defer if (full_text.len > 0 and !std.mem.eql(u8, full_text, "?decode error?"))
            allocator.free(full_text);

        std.debug.print("  Generated ({d} tokens in {d:.0}ms = {d:.1} tok/s):\n", .{
            new_tokens.len, gen_ms, tok_per_sec,
        });
        std.debug.print("  \"{s}\"\n", .{full_text});

        // Show first few token IDs
        std.debug.print("  Tokens: ", .{});
        const show_count = @min(new_tokens.len, 15);
        for (new_tokens[0..show_count]) |t| std.debug.print("{d} ", .{t});
        if (new_tokens.len > 15) std.debug.print("...", .{});
        std.debug.print("\n", .{});
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
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

test "relu2" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), relu2(0.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), relu2(-5.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), relu2(2.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), relu2(3.0), 0.001);
}

test "ternaryMatVecPacked basic" {
    // Test simple 2x4 ternary matrix (packed_rows=1, in_features=4)
    // Output should be 4 values (1 packed row * 4 trits)
    //
    // Byte 0: trits for outputs [0,1,2,3] at input col 0
    // Byte 1: trits for outputs [0,1,2,3] at input col 1
    // etc.

    // 4 input features, 4 output features (1 packed row)
    // byte[0] = 0b00_10_01_01 = trits: out0=+1, out1=+1, out2=-1, out3=0
    // byte[1] = 0b01_00_01_10 = trits: out0=-1, out1=+1, out2=0, out3=+1
    // byte[2] = 0b00_00_00_01 = trits: out0=+1, out1=0, out2=0, out3=0
    // byte[3] = 0b00_01_10_00 = trits: out0=0, out1=-1, out2=+1, out3=0

    const weights = [_]u8{
        0b00100101, // col 0: out0=+1, out1=+1, out2=-1, out3=0
        0b01000110, // col 1: out0=-1, out1=+1, out2=0, out3=+1
        0b00000001, // col 2: out0=+1, out1=0, out2=0, out3=0
        0b00011000, // col 3: out0=0, out1=-1, out2=+1, out3=0
    };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;

    ternaryMatVecPacked(&weights, &input, &output, 1, 4, 1.0);

    // out0 = (+1)*1 + (-1)*2 + (+1)*3 + 0*4 = 1 - 2 + 3 = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[0], 0.001);
    // out1 = (+1)*1 + (+1)*2 + 0*3 + (-1)*4 = 1 + 2 - 4 = -1.0
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[1], 0.001);
    // out2 = (-1)*1 + 0*2 + 0*3 + (+1)*4 = -1 + 4 = 3.0
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), output[2], 0.001);
    // out3 = 0*1 + (+1)*2 + 0*3 + 0*4 = 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[3], 0.001);
}

test "ternaryMatVecPacked with scale" {
    const weights = [_]u8{
        0b00000101, // col 0: out0=+1, out1=+1, out2=0, out3=0
        0b00001001, // col 1: out0=+1, out1=-1, out2=0, out3=0
    };
    const input = [_]f32{ 3.0, 5.0 };
    var output: [4]f32 = undefined;

    ternaryMatVecPacked(&weights, &input, &output, 1, 2, 2.0);

    // out0 = 2.0 * ((+1)*3 + (+1)*5) = 2.0 * 8 = 16.0
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), output[0], 0.001);
    // out1 = 2.0 * ((+1)*3 + (-1)*5) = 2.0 * (-2) = -4.0
    try std.testing.expectApproxEqAbs(@as(f32, -4.0), output[1], 0.001);
}

test "quantizeActivations" {
    var x = [_]f32{ -4.0, 0.0, 2.0, 4.0 };
    const max_abs = quantizeActivations(&x);

    try std.testing.expectApproxEqAbs(@as(f32, 4.0), max_abs, 0.001);
    // After quantize+dequantize, values should be close to originals
    try std.testing.expect(@abs(x[0] - (-4.0)) < 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), x[1], 0.1);
}

// Debug test for comparing Zig vs Python computation
pub fn debugForwardTest() void {
    const allocator = std.heap.page_allocator;
    
    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     DEBUG FORWARD TEST - Token 9906 (Hello)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n\n", .{});
    
    var model = loadFromBin(allocator, "models/bitnet-2b.bin") catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();
    
    const token_id: u32 = 9906;  // "Hello"
    const hidden: usize = model.config.hidden_size;
    
    // Step 1: Embedding lookup
    const embed_start = @as(usize, token_id) * hidden;
    @memcpy(model.hidden_state, model.embed_tokens[embed_start..embed_start + hidden]);
    
    var norm: f32 = 0.0;
    for (model.hidden_state) |x| norm += x * x;
    norm = @sqrt(norm);
    std.debug.print("1. Embedding: norm={d:.4}, first 5=[", .{norm});
    for (model.hidden_state[0..5], 0..) |x, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d:.6}", .{x});
    }
    std.debug.print("]\n", .{});
    
    // Step 2: RMS Norm
    const layer = model.layers[0];
    var normed: [2560]f32 = undefined;
    rmsNorm(model.hidden_state, layer.input_layernorm, normed[0..hidden], model.config.rms_norm_eps);
    
    norm = 0.0;
    for (normed[0..hidden]) |x| norm += x * x;
    norm = @sqrt(norm);
    std.debug.print("2. After RMS norm: norm={d:.4}, first 5=[", .{norm});
    for (normed[0..5], 0..) |x, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d:.8}", .{x});
    }
    std.debug.print("]\n", .{});
    
    // Step 3: Activation quantization
    const max_abs = quantizeActivations(normed[0..hidden]);
    
    norm = 0.0;
    for (normed[0..hidden]) |x| norm += x * x;
    norm = @sqrt(norm);
    std.debug.print("3. After quant: max_abs={d:.4}, norm={d:.4}, first 5=[", .{max_abs, norm});
    for (normed[0..5], 0..) |x, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d:.8}", .{x});
    }
    std.debug.print("]\n", .{});
    
    // Step 4: Ternary matmul Q
    ternaryMatVecPacked(layer.q_proj, normed[0..hidden], model.q_buf, hidden / 4, hidden, layer.q_scale);
    
    norm = 0.0;
    for (model.q_buf) |x| norm += x * x;
    norm = @sqrt(norm);
    std.debug.print("4. Q output: scale={d:.4}, norm={d:.4}, first 5=[", .{layer.q_scale, norm});
    for (model.q_buf[0..5], 0..) |x, i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d:.6}", .{x});
    }
    std.debug.print("]\n", .{});
    
    // Compare with Python reference:
    std.debug.print("\n--- Python Reference ---\n", .{});
    std.debug.print("1. Embedding: norm=40.0737\n", .{});
    std.debug.print("4. Q output: norm=51.7531\n", .{});

    // Now test K, V, and attention
    const kv_dim: usize = model.config.kvDim();
    ternaryMatVecPacked(layer.k_proj, normed[0..hidden], model.k_buf, kv_dim / 4, hidden, layer.k_scale);
    ternaryMatVecPacked(layer.v_proj, normed[0..hidden], model.v_buf, kv_dim / 4, hidden, layer.v_scale);

    var k_norm: f32 = 0.0;
    var v_norm: f32 = 0.0;
    for (model.k_buf) |x| k_norm += x * x;
    for (model.v_buf) |x| v_norm += x * x;
    k_norm = @sqrt(k_norm);
    v_norm = @sqrt(v_norm);

    std.debug.print("\n5. K output: norm={d:.4} (Python: 43.3129)\n", .{k_norm});
    std.debug.print("6. V output: norm={d:.4} (Python: 71.7362)\n", .{v_norm});

    // Apply RoPE at position 0
    const head_dim: usize = model.config.headDim();
    const num_heads: usize = model.config.num_attention_heads;
    const num_kv_heads: usize = model.config.num_key_value_heads;

    for (0..num_heads) |h| {
        const q_start = h * head_dim;
        applyRoPESingle(model.q_buf[q_start .. q_start + head_dim], 0, head_dim, model.config.rope_theta);
    }
    for (0..num_kv_heads) |kh| {
        const k_start = kh * head_dim;
        applyRoPESingle(model.k_buf[k_start .. k_start + head_dim], 0, head_dim, model.config.rope_theta);
    }

    // Compute GQA attention for single position
    @memset(model.attn_output, 0.0);
    const gqa_groups: usize = model.config.gqaGroups();

    for (0..num_heads) |h| {
        const q_start = h * head_dim;
        const kv_head = h / gqa_groups;
        const kv_start = kv_head * head_dim;

        for (0..head_dim) |d| {
            model.attn_output[q_start + d] = model.v_buf[kv_start + d];
        }
    }

    var attn_norm: f32 = 0.0;
    for (model.attn_output) |x| attn_norm += x * x;
    attn_norm = @sqrt(attn_norm);
    std.debug.print("7. Attention output: norm={d:.4} (Python: 143.4725)\n", .{attn_norm});

    // attn_sub_norm
    if (layer.attn_sub_norm.len > 0) {
        rmsNorm(model.attn_output, layer.attn_sub_norm, model.attn_output, model.config.rms_norm_eps);
        attn_norm = 0.0;
        for (model.attn_output) |x| attn_norm += x * x;
        attn_norm = @sqrt(attn_norm);
        std.debug.print("8. After attn_sub_norm: norm={d:.4} (Python: 1.1815)\n", .{attn_norm});
    }

    // Quant + O projection
    _ = quantizeActivations(model.attn_output);
    var o_out: [2560]f32 = undefined;
    ternaryMatVecPacked(layer.o_proj, model.attn_output, o_out[0..hidden], hidden / 4, hidden, layer.o_scale);

    var o_norm: f32 = 0.0;
    for (o_out[0..hidden]) |x| o_norm += x * x;
    o_norm = @sqrt(o_norm);
    std.debug.print("9. O output: norm={d:.4} (Python: 49.3613)\n", .{o_norm});

    // Residual
    for (model.hidden_state, o_out[0..hidden]) |*hs, o| {
        hs.* += o;
    }

    var res_norm: f32 = 0.0;
    for (model.hidden_state) |x| res_norm += x * x;
    res_norm = @sqrt(res_norm);
    std.debug.print("10. After attn residual: norm={d:.4} (Python: 63.0571)\n", .{res_norm});

    // === FFN BLOCK ===
    const inter: usize = model.config.intermediate_size;

    // Post-attention LayerNorm + quant
    var ffn_normed: [2560]f32 = undefined;
    rmsNorm(model.hidden_state, layer.post_attention_layernorm, ffn_normed[0..hidden], model.config.rms_norm_eps);
    _ = quantizeActivations(ffn_normed[0..hidden]);

    var ffn_in_norm: f32 = 0.0;
    for (ffn_normed[0..hidden]) |x| ffn_in_norm += x * x;
    ffn_in_norm = @sqrt(ffn_in_norm);
    std.debug.print("\n11. FFN input norm: {d:.4} (Python: 65.3038)\n", .{ffn_in_norm});

    // Gate and Up projections
    ternaryMatVecPacked(layer.gate_proj, ffn_normed[0..hidden], model.ffn_gate, inter / 4, hidden, layer.gate_scale);
    ternaryMatVecPacked(layer.up_proj, ffn_normed[0..hidden], model.ffn_up, inter / 4, hidden, layer.up_scale);

    var gate_norm: f32 = 0.0;
    var up_norm: f32 = 0.0;
    for (model.ffn_gate) |x| gate_norm += x * x;
    for (model.ffn_up) |x| up_norm += x * x;
    gate_norm = @sqrt(gate_norm);
    up_norm = @sqrt(up_norm);
    std.debug.print("12. Gate norm: {d:.4} (Python: 14203.2)\n", .{gate_norm});
    std.debug.print("13. Up norm: {d:.4} (Python: 16733.9)\n", .{up_norm});

    // ReLU²(gate) * up
    for (model.ffn_gate, model.ffn_up) |*g, u| {
        g.* = relu2(g.*) * u;
    }

    var relu_norm: f32 = 0.0;
    for (model.ffn_gate) |x| relu_norm += x * x;
    relu_norm = @sqrt(relu_norm);
    std.debug.print("14. After relu2*up norm: {e:.4} (Python: 6.34e9)\n", .{relu_norm});

    // FFN sub-norm + quant
    if (layer.ffn_sub_norm.len > 0) {
        rmsNorm(model.ffn_gate, layer.ffn_sub_norm, model.ffn_gate, model.config.rms_norm_eps);
    }
    _ = quantizeActivations(model.ffn_gate);

    var sub_norm: f32 = 0.0;
    for (model.ffn_gate) |x| sub_norm += x * x;
    sub_norm = @sqrt(sub_norm);
    std.debug.print("15. After ffn_sub_norm norm: {d:.4} (Python: 114.44)\n", .{sub_norm});

    // Down projection
    var down_out: [2560]f32 = undefined;
    ternaryMatVecPacked(layer.down_proj, model.ffn_gate, down_out[0..hidden], hidden / 4, inter, layer.down_scale);

    var down_norm: f32 = 0.0;
    for (down_out[0..hidden]) |x| down_norm += x * x;
    down_norm = @sqrt(down_norm);
    std.debug.print("16. Down norm: {d:.4} (Python: 16251.4)\n", .{down_norm});

    // FFN residual
    for (model.hidden_state, down_out[0..hidden]) |*hs, d| {
        hs.* += d;
    }

    var final_norm: f32 = 0.0;
    for (model.hidden_state) |x| final_norm += x * x;
    final_norm = @sqrt(final_norm);
    std.debug.print("17. Layer 0 done: norm={d:.4} (Python: 16255.6)\n", .{final_norm});

    // Now run full forward pass and check logits
    std.debug.print("\n=== FULL FORWARD PASS ===\n", .{});

    // Reset and run full forward
    const embed_start_full = @as(usize, 9906) * hidden;
    @memcpy(model.hidden_state, model.embed_tokens[embed_start_full..embed_start_full + hidden]);

    // Process all 30 layers
    for (model.layers, 0..) |lyr, layer_idx| {
        if (lyr.input_layernorm.len == 0) continue;

        var layer_normed: [2560]f32 = undefined;

        // Attention block
        rmsNorm(model.hidden_state, lyr.input_layernorm, layer_normed[0..hidden], model.config.rms_norm_eps);
        _ = quantizeActivations(layer_normed[0..hidden]);

        ternaryMatVecPacked(lyr.q_proj, layer_normed[0..hidden], model.q_buf, hidden / 4, hidden, lyr.q_scale);
        ternaryMatVecPacked(lyr.k_proj, layer_normed[0..hidden], model.k_buf, kv_dim / 4, hidden, lyr.k_scale);
        ternaryMatVecPacked(lyr.v_proj, layer_normed[0..hidden], model.v_buf, kv_dim / 4, hidden, lyr.v_scale);

        const head_dim_loop: usize = model.config.headDim();
        const num_heads_loop: usize = model.config.num_attention_heads;
        const num_kv_heads_loop: usize = model.config.num_key_value_heads;

        for (0..num_heads_loop) |h| {
            const q_start_l = h * head_dim_loop;
            applyRoPESingle(model.q_buf[q_start_l .. q_start_l + head_dim_loop], 0, head_dim_loop, model.config.rope_theta);
        }
        for (0..num_kv_heads_loop) |kh| {
            const k_start_l = kh * head_dim_loop;
            applyRoPESingle(model.k_buf[k_start_l .. k_start_l + head_dim_loop], 0, head_dim_loop, model.config.rope_theta);
        }

        // Single-position attention
        @memset(model.attn_output, 0.0);
        const gqa_g: usize = model.config.gqaGroups();
        for (0..num_heads_loop) |h| {
            const q_start_l = h * head_dim_loop;
            const kv_head_l = h / gqa_g;
            const kv_start_l = kv_head_l * head_dim_loop;
            for (0..head_dim_loop) |d| {
                model.attn_output[q_start_l + d] = model.v_buf[kv_start_l + d];
            }
        }

        // attn_sub_norm + O
        if (lyr.attn_sub_norm.len > 0) {
            rmsNorm(model.attn_output, lyr.attn_sub_norm, model.attn_output, model.config.rms_norm_eps);
        }
        _ = quantizeActivations(model.attn_output);
        var o_out_l: [2560]f32 = undefined;
        ternaryMatVecPacked(lyr.o_proj, model.attn_output, o_out_l[0..hidden], hidden / 4, hidden, lyr.o_scale);

        for (model.hidden_state, o_out_l[0..hidden]) |*hs, o| hs.* += o;

        // FFN block
        rmsNorm(model.hidden_state, lyr.post_attention_layernorm, layer_normed[0..hidden], model.config.rms_norm_eps);
        _ = quantizeActivations(layer_normed[0..hidden]);

        ternaryMatVecPacked(lyr.gate_proj, layer_normed[0..hidden], model.ffn_gate, inter / 4, hidden, lyr.gate_scale);
        ternaryMatVecPacked(lyr.up_proj, layer_normed[0..hidden], model.ffn_up, inter / 4, hidden, lyr.up_scale);

        for (model.ffn_gate, model.ffn_up) |*g, u| g.* = relu2(g.*) * u;

        if (lyr.ffn_sub_norm.len > 0) {
            rmsNorm(model.ffn_gate, lyr.ffn_sub_norm, model.ffn_gate, model.config.rms_norm_eps);
        }
        _ = quantizeActivations(model.ffn_gate);

        var down_out_l: [2560]f32 = undefined;
        ternaryMatVecPacked(lyr.down_proj, model.ffn_gate, down_out_l[0..hidden], hidden / 4, inter, lyr.down_scale);

        for (model.hidden_state, down_out_l[0..hidden]) |*hs, d| hs.* += d;

        if (layer_idx % 10 == 0 or layer_idx == 29) {
            var ln: f32 = 0.0;
            for (model.hidden_state) |x| ln += x * x;
            ln = @sqrt(ln);
            std.debug.print("Layer {d}: hidden norm = {d:.4}\n", .{layer_idx, ln});
        }
    }

    // Final norm
    rmsNorm(model.hidden_state, model.norm, model.hidden_state, model.config.rms_norm_eps);

    var h_norm: f32 = 0.0;
    for (model.hidden_state) |x| h_norm += x * x;
    h_norm = @sqrt(h_norm);
    std.debug.print("\nAfter final norm: {d:.4}\n", .{h_norm});

    // LM head
    const vocab: usize = model.config.vocab_size;
    const lm_weight = if (model.output_weight.len > 0) model.output_weight else model.embed_tokens;

    var min_logit: f32 = 1e9;
    var max_logit: f32 = -1e9;
    var sum_logit: f32 = 0.0;

    for (0..vocab) |v| {
        const w_start = v * hidden;
        var dot: f32 = 0.0;
        for (0..hidden) |d| {
            dot += model.hidden_state[d] * lm_weight[w_start + d];
        }
        model.logits[v] = dot;
        if (dot < min_logit) min_logit = dot;
        if (dot > max_logit) max_logit = dot;
        sum_logit += dot;
    }

    std.debug.print("Logits: min={d:.2}, max={d:.2}, mean={d:.2}\n", .{min_logit, max_logit, sum_logit / @as(f32, @floatFromInt(vocab))});

    // Find top 10
    var top_idx: [10]usize = undefined;
    var top_val: [10]f32 = .{-1e9} ** 10;

    for (model.logits, 0..) |logit, v| {
        for (0..10) |i| {
            if (logit > top_val[i]) {
                // Shift down
                var j: usize = 9;
                while (j > i) : (j -= 1) {
                    top_val[j] = top_val[j - 1];
                    top_idx[j] = top_idx[j - 1];
                }
                top_val[i] = logit;
                top_idx[i] = v;
                break;
            }
        }
    }

    std.debug.print("\nTop 10 tokens:\n", .{});
    for (0..10) |i| {
        std.debug.print("  {d}. Token {d}: logit={d:.2}\n", .{i + 1, top_idx[i], top_val[i]});
    }
}

pub fn main2() void {
    debugForwardTest();
}
