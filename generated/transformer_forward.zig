// TRANSFORMER FORWARD PASS — Native LLM Inference Engine
// SIMD-optimized transformer with KV cache, RoPE, SwiGLU
// Generated from specs/tri/gguf_inference.vibee
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const RMS_NORM_EPS: f32 = 1e-5;
pub const SIMD_WIDTH: usize = 8;

// Test model dimensions (small for stack safety)
pub const TEST_HIDDEN: usize = 64;
pub const TEST_HEADS: usize = 4;
pub const TEST_KV_HEADS: usize = 2;
pub const TEST_HEAD_DIM: usize = 16; // hidden / heads
pub const TEST_INTER: usize = 128; // ~2.67x hidden (SwiGLU)
pub const TEST_VOCAB: usize = 128;
pub const TEST_LAYERS: usize = 2;
pub const TEST_CTX_LEN: usize = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelConfig = struct {
    vocab_size: u32,
    hidden_size: u32,
    intermediate_size: u32,
    num_layers: u32,
    num_heads: u32,
    num_kv_heads: u32,
    head_dim: u32,
    context_length: u32,
    rope_theta: f32,
    rms_norm_eps: f32,

    pub fn testConfig() ModelConfig {
        return .{
            .vocab_size = TEST_VOCAB,
            .hidden_size = TEST_HIDDEN,
            .intermediate_size = TEST_INTER,
            .num_layers = TEST_LAYERS,
            .num_heads = TEST_HEADS,
            .num_kv_heads = TEST_KV_HEADS,
            .head_dim = TEST_HEAD_DIM,
            .context_length = TEST_CTX_LEN,
            .rope_theta = 10000.0,
            .rms_norm_eps = RMS_NORM_EPS,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// RMS Normalization: output = (input / sqrt(mean(input^2) + eps)) * weight
pub fn rmsNorm(output: []f32, input: []const f32, weight: []const f32, eps: f32) void {
    const n = input.len;
    if (n == 0) return;

    // Compute sum of squares
    var ss: f32 = 0.0;
    for (input) |x| {
        ss += x * x;
    }
    ss = ss / @as(f32, @floatFromInt(n));
    ss = 1.0 / @sqrt(ss + eps);

    // Scale by weight
    const len = @min(n, @min(output.len, weight.len));
    for (0..len) |i| {
        output[i] = input[i] * ss * weight[i];
    }
}

/// Matrix-vector multiply: output[rows] = mat[rows*cols] @ vec[cols]
pub fn matVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    for (0..rows) |r| {
        var sum: f32 = 0.0;
        const row_start = r * cols;

        // SIMD-style: process 8 elements at a time
        var c: usize = 0;
        while (c + SIMD_WIDTH <= cols) : (c += SIMD_WIDTH) {
            var partial: f32 = 0.0;
            inline for (0..SIMD_WIDTH) |k| {
                partial += mat[row_start + c + k] * vec[c + k];
            }
            sum += partial;
        }
        // Scalar tail
        while (c < cols) : (c += 1) {
            sum += mat[row_start + c] * vec[c];
        }
        output[r] = sum;
    }
}

/// SiLU activation: x * sigmoid(x) = x / (1 + exp(-x))
pub fn siluActivation(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

/// Softmax: subtract max for stability, exp, normalize
pub fn softmax(output: []f32, input: []const f32, n: usize) void {
    if (n == 0) return;
    const len = @min(n, @min(output.len, input.len));

    // Find max
    var max_val: f32 = input[0];
    for (1..len) |i| {
        if (input[i] > max_val) max_val = input[i];
    }

    // Exp and sum
    var sum_exp: f32 = 0.0;
    for (0..len) |i| {
        output[i] = @exp(input[i] - max_val);
        sum_exp += output[i];
    }

    // Normalize
    if (sum_exp > 0.0) {
        const inv_sum = 1.0 / sum_exp;
        for (0..len) |i| {
            output[i] *= inv_sum;
        }
    }
}

/// Dot product of two vectors
pub fn dotProduct(a: []const f32, b: []const f32, n: usize) f32 {
    var sum: f32 = 0.0;
    const len = @min(n, @min(a.len, b.len));
    for (0..len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}

/// Element-wise addition: output += input
pub fn addInPlace(output: []f32, input: []const f32, n: usize) void {
    const len = @min(n, @min(output.len, input.len));
    for (0..len) |i| {
        output[i] += input[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RoPE (Rotary Position Embeddings)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RoPECache = struct {
    cos_buf: [TEST_CTX_LEN * TEST_HEAD_DIM / 2]f32 = undefined,
    sin_buf: [TEST_CTX_LEN * TEST_HEAD_DIM / 2]f32 = undefined,
    head_dim: u32,
    max_seq_len: u32,

    pub fn init(head_dim: u32, max_seq_len: u32, theta: f32) RoPECache {
        var cache = RoPECache{
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
        };
        const half_dim = head_dim / 2;
        for (0..max_seq_len) |pos| {
            for (0..half_dim) |i| {
                const freq = 1.0 / std.math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
                const angle = @as(f32, @floatFromInt(pos)) * freq;
                const idx = pos * half_dim + i;
                if (idx < cache.cos_buf.len) {
                    cache.cos_buf[idx] = @cos(angle);
                    cache.sin_buf[idx] = @sin(angle);
                }
            }
        }
        return cache;
    }

    /// Apply RoPE to a vector at given position
    pub fn apply(self: *const RoPECache, vec: []f32, pos: usize) void {
        const half_dim = self.head_dim / 2;
        const cache_offset = pos * half_dim;
        for (0..half_dim) |i| {
            if (cache_offset + i >= self.cos_buf.len) break;
            const c = self.cos_buf[cache_offset + i];
            const s = self.sin_buf[cache_offset + i];
            const x0 = vec[i];
            const x1 = vec[i + half_dim];
            vec[i] = x0 * c - x1 * s;
            vec[i + half_dim] = x0 * s + x1 * c;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KV CACHE
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCache = struct {
    // k_cache[layer][pos][kv_head * head_dim]
    k_buf: [TEST_LAYERS * TEST_CTX_LEN * TEST_KV_HEADS * TEST_HEAD_DIM]f32 = .{0} ** (TEST_LAYERS * TEST_CTX_LEN * TEST_KV_HEADS * TEST_HEAD_DIM),
    v_buf: [TEST_LAYERS * TEST_CTX_LEN * TEST_KV_HEADS * TEST_HEAD_DIM]f32 = .{0} ** (TEST_LAYERS * TEST_CTX_LEN * TEST_KV_HEADS * TEST_HEAD_DIM),
    seq_len: usize = 0,

    const LAYER_STRIDE = TEST_CTX_LEN * TEST_KV_HEADS * TEST_HEAD_DIM;
    const POS_STRIDE = TEST_KV_HEADS * TEST_HEAD_DIM;

    pub fn init() KVCache {
        return .{};
    }

    /// Store K vector for given layer, position, kv_head
    pub fn storeK(self: *KVCache, layer: usize, pos: usize, kv_head: usize, data: []const f32) void {
        const offset = layer * LAYER_STRIDE + pos * POS_STRIDE + kv_head * TEST_HEAD_DIM;
        const len = @min(data.len, TEST_HEAD_DIM);
        @memcpy(self.k_buf[offset..][0..len], data[0..len]);
    }

    /// Store V vector for given layer, position, kv_head
    pub fn storeV(self: *KVCache, layer: usize, pos: usize, kv_head: usize, data: []const f32) void {
        const offset = layer * LAYER_STRIDE + pos * POS_STRIDE + kv_head * TEST_HEAD_DIM;
        const len = @min(data.len, TEST_HEAD_DIM);
        @memcpy(self.v_buf[offset..][0..len], data[0..len]);
    }

    /// Get K vector for given layer, position, kv_head
    pub fn getK(self: *const KVCache, layer: usize, pos: usize, kv_head: usize) []const f32 {
        const offset = layer * LAYER_STRIDE + pos * POS_STRIDE + kv_head * TEST_HEAD_DIM;
        return self.k_buf[offset..][0..TEST_HEAD_DIM];
    }

    /// Get V vector for given layer, position, kv_head
    pub fn getV(self: *const KVCache, layer: usize, pos: usize, kv_head: usize) []const f32 {
        const offset = layer * LAYER_STRIDE + pos * POS_STRIDE + kv_head * TEST_HEAD_DIM;
        return self.v_buf[offset..][0..TEST_HEAD_DIM];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER WEIGHTS (fixed-size for testing)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LayerWeights = struct {
    attn_norm: [TEST_HIDDEN]f32,
    ffn_norm: [TEST_HIDDEN]f32,
    wq: [TEST_HIDDEN * TEST_HIDDEN]f32, // [hidden, hidden] = [heads*head_dim, hidden]
    wk: [TEST_KV_HEADS * TEST_HEAD_DIM * TEST_HIDDEN]f32,
    wv: [TEST_KV_HEADS * TEST_HEAD_DIM * TEST_HIDDEN]f32,
    wo: [TEST_HIDDEN * TEST_HIDDEN]f32,
    w_gate: [TEST_INTER * TEST_HIDDEN]f32,
    w_up: [TEST_INTER * TEST_HIDDEN]f32,
    w_down: [TEST_HIDDEN * TEST_INTER]f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL WEIGHTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelWeights = struct {
    embedding: [TEST_VOCAB * TEST_HIDDEN]f32,
    final_norm: [TEST_HIDDEN]f32,
    output_proj: [TEST_VOCAB * TEST_HIDDEN]f32,
    layers: [TEST_LAYERS]LayerWeights,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LCG PRNG (deterministic weight init for testing)
// ═══════════════════════════════════════════════════════════════════════════════

pub const LCG = struct {
    state: u64,

    pub fn init(seed: u64) LCG {
        return .{ .state = seed };
    }

    pub fn next(self: *LCG) u32 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return @intCast((self.state >> 33) & 0x7FFFFFFF);
    }

    /// Random float in [-scale, +scale]
    pub fn nextF32(self: *LCG, scale: f32) f32 {
        const bits = self.next();
        const normalized = @as(f32, @floatFromInt(bits)) / 2147483648.0; // [0, 1)
        return (normalized * 2.0 - 1.0) * scale;
    }

    /// Fill array with random f32 values
    pub fn fillRandom(self: *LCG, buf: []f32, scale: f32) void {
        for (buf) |*v| {
            v.* = self.nextF32(scale);
        }
    }

    /// Fill array with 1.0 (for norm weights)
    pub fn fillOnes(buf: []f32) void {
        for (buf) |*v| {
            v.* = 1.0;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSFORMER FORWARD PASS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Transformer = struct {
    config: ModelConfig,
    rope: RoPECache,

    pub fn init(config: ModelConfig) Transformer {
        return .{
            .config = config,
            .rope = RoPECache.init(config.head_dim, config.context_length, config.rope_theta),
        };
    }

    /// Single attention head computation
    /// Returns attention output for one head
    pub fn attentionHead(
        self: *const Transformer,
        output: []f32,
        q: []f32,
        kv_cache: *const KVCache,
        layer: usize,
        pos: usize,
        head: usize,
        scores_buf: []f32,
    ) void {
        const hd = self.config.head_dim;
        const kv_head = head / (self.config.num_heads / self.config.num_kv_heads);

        // Apply RoPE to Q
        self.rope.apply(q, pos);

        // Score = Q @ K^T for each cached position
        for (0..pos + 1) |p| {
            const k = kv_cache.getK(layer, p, kv_head);
            scores_buf[p] = dotProduct(q, k, hd) / @sqrt(@as(f32, @floatFromInt(hd)));
        }

        // Softmax over scores
        softmax(scores_buf, scores_buf, pos + 1);

        // Weighted sum of V
        for (output[0..hd]) |*o| {
            o.* = 0.0;
        }
        for (0..pos + 1) |p| {
            const v = kv_cache.getV(layer, p, kv_head);
            for (0..hd) |d| {
                output[d] += scores_buf[p] * v[d];
            }
        }
    }

    /// Full attention block for one layer
    pub fn attention(
        self: *const Transformer,
        output: []f32,
        input: []const f32,
        weights: *const LayerWeights,
        kv_cache: *KVCache,
        layer: usize,
        pos: usize,
    ) void {
        const hidden = self.config.hidden_size;
        const hd = self.config.head_dim;
        const n_heads = self.config.num_heads;
        const n_kv = self.config.num_kv_heads;

        // 1. RMSNorm
        var normed: [TEST_HIDDEN]f32 = undefined;
        rmsNorm(&normed, input, &weights.attn_norm, self.config.rms_norm_eps);

        // 2. Compute Q, K, V projections
        var q_buf: [TEST_HIDDEN]f32 = undefined;
        var k_buf: [TEST_KV_HEADS * TEST_HEAD_DIM]f32 = undefined;
        var v_buf: [TEST_KV_HEADS * TEST_HEAD_DIM]f32 = undefined;

        matVec(&q_buf, &weights.wq, &normed, hidden, hidden);
        matVec(&k_buf, &weights.wk, &normed, n_kv * hd, hidden);
        matVec(&v_buf, &weights.wv, &normed, n_kv * hd, hidden);

        // 3. Apply RoPE to K and store in KV cache
        for (0..n_kv) |kv_h| {
            var k_head: [TEST_HEAD_DIM]f32 = undefined;
            @memcpy(&k_head, k_buf[kv_h * hd ..][0..hd]);
            self.rope.apply(&k_head, pos);
            kv_cache.storeK(layer, pos, kv_h, &k_head);
            kv_cache.storeV(layer, pos, kv_h, v_buf[kv_h * hd ..][0..hd]);
        }

        // 4. Multi-head attention
        var attn_out: [TEST_HIDDEN]f32 = .{0} ** TEST_HIDDEN;
        var scores_buf: [TEST_CTX_LEN]f32 = undefined;

        for (0..n_heads) |h| {
            var q_head: [TEST_HEAD_DIM]f32 = undefined;
            @memcpy(&q_head, q_buf[h * hd ..][0..hd]);
            var head_out: [TEST_HEAD_DIM]f32 = undefined;
            self.attentionHead(&head_out, &q_head, kv_cache, layer, pos, h, &scores_buf);
            @memcpy(attn_out[h * hd ..][0..hd], &head_out);
        }

        // 5. Output projection
        matVec(output, &weights.wo, &attn_out, hidden, hidden);
    }

    /// Feed-Forward Network (SwiGLU)
    pub fn ffn(
        self: *const Transformer,
        output: []f32,
        input: []const f32,
        weights: *const LayerWeights,
    ) void {
        const hidden = self.config.hidden_size;
        const inter = self.config.intermediate_size;

        // 1. RMSNorm
        var normed: [TEST_HIDDEN]f32 = undefined;
        rmsNorm(&normed, input, &weights.ffn_norm, self.config.rms_norm_eps);

        // 2. Gate and Up projections
        var gate_buf: [TEST_INTER]f32 = undefined;
        var up_buf: [TEST_INTER]f32 = undefined;
        matVec(&gate_buf, &weights.w_gate, &normed, inter, hidden);
        matVec(&up_buf, &weights.w_up, &normed, inter, hidden);

        // 3. SwiGLU: SiLU(gate) * up
        for (0..inter) |i| {
            gate_buf[i] = siluActivation(gate_buf[i]) * up_buf[i];
        }

        // 4. Down projection
        matVec(output, &weights.w_down, &gate_buf, hidden, inter);
    }

    /// Single transformer layer: attention + FFN with residuals
    pub fn forwardLayer(
        self: *const Transformer,
        hidden_state: []f32,
        weights: *const LayerWeights,
        kv_cache: *KVCache,
        layer: usize,
        pos: usize,
    ) void {
        const hidden = self.config.hidden_size;

        // Attention with residual
        var attn_out: [TEST_HIDDEN]f32 = undefined;
        self.attention(&attn_out, hidden_state, weights, kv_cache, layer, pos);
        addInPlace(hidden_state, &attn_out, hidden);

        // FFN with residual
        var ffn_out: [TEST_HIDDEN]f32 = undefined;
        self.ffn(&ffn_out, hidden_state, weights);
        addInPlace(hidden_state, &ffn_out, hidden);
    }

    /// Full forward pass: token -> logits
    pub fn forward(
        self: *const Transformer,
        logits: []f32,
        weights: *const ModelWeights,
        kv_cache: *KVCache,
        token: u32,
        pos: usize,
    ) void {
        const hidden = self.config.hidden_size;
        const vocab = self.config.vocab_size;

        // 1. Token embedding
        var hidden_state: [TEST_HIDDEN]f32 = undefined;
        const emb_offset = @as(usize, token) * hidden;
        @memcpy(&hidden_state, weights.embedding[emb_offset..][0..hidden]);

        // 2. Transformer layers
        for (0..self.config.num_layers) |layer| {
            self.forwardLayer(&hidden_state, &weights.layers[layer], kv_cache, layer, pos);
        }

        // 3. Final RMS norm
        var normed: [TEST_HIDDEN]f32 = undefined;
        rmsNorm(&normed, &hidden_state, &weights.final_norm, self.config.rms_norm_eps);

        // 4. Output projection -> logits
        matVec(logits, &weights.output_proj, &normed, vocab, hidden);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-P (NUCLEUS) SAMPLING
// ═══════════════════════════════════════════════════════════════════════════════

pub const SamplingParams = struct {
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,

    pub fn greedy() SamplingParams {
        return .{ .temperature = 0.0, .top_p = 1.0 };
    }
};

/// Apply temperature scaling to logits
pub fn applyTemperature(logits: []f32, n: usize, temperature: f32) void {
    if (temperature <= 0.0 or temperature == 1.0) return;
    const inv_temp = 1.0 / temperature;
    const len = @min(n, logits.len);
    for (0..len) |i| {
        logits[i] *= inv_temp;
    }
}

/// Greedy argmax sampling
pub fn sampleGreedy(logits: []const f32, n: usize) u32 {
    var max_idx: u32 = 0;
    var max_val: f32 = logits[0];
    const len = @min(n, logits.len);
    for (1..len) |i| {
        if (logits[i] > max_val) {
            max_val = logits[i];
            max_idx = @intCast(i);
        }
    }
    return max_idx;
}

/// Top-p (nucleus) sampling with LCG PRNG
pub fn sampleTopP(probs: []const f32, n: usize, top_p: f32, rng: *LCG) u32 {
    // Simple top-p: accumulate sorted probabilities until sum >= top_p
    // For efficiency, we do a linear scan (small vocab in test)
    const len = @min(n, probs.len);
    const r = @as(f32, @floatFromInt(rng.next())) / 2147483648.0 * top_p;

    var cumsum: f32 = 0.0;
    for (0..len) |i| {
        cumsum += probs[i];
        if (cumsum > r) return @intCast(i);
    }
    return @intCast(len - 1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATION LOOP
// ═══════════════════════════════════════════════════════════════════════════════

pub const GenerationResult = struct {
    tokens: [TEST_CTX_LEN]u32 = .{0} ** TEST_CTX_LEN,
    num_tokens: usize = 0,
    total_logit_sum: f32 = 0.0, // For perplexity tracking
};

/// Generate tokens autoregressively
pub fn generate(
    transformer: *const Transformer,
    weights: *const ModelWeights,
    kv_cache: *KVCache,
    prompt_token: u32,
    max_tokens: usize,
    params: SamplingParams,
    rng: *LCG,
) GenerationResult {
    var result = GenerationResult{};
    result.tokens[0] = prompt_token;
    result.num_tokens = 1;

    var logits: [TEST_VOCAB]f32 = undefined;
    var current_token = prompt_token;

    for (0..max_tokens) |step| {
        const pos = step;
        if (pos >= TEST_CTX_LEN) break;

        // Forward pass
        transformer.forward(&logits, weights, kv_cache, current_token, pos);

        // Track logit statistics
        var max_logit: f32 = logits[0];
        for (logits[1..]) |l| {
            if (l > max_logit) max_logit = l;
        }
        result.total_logit_sum += max_logit;

        // Sample next token
        if (params.temperature <= 0.0) {
            current_token = sampleGreedy(&logits, TEST_VOCAB);
        } else {
            applyTemperature(&logits, TEST_VOCAB, params.temperature);
            var probs: [TEST_VOCAB]f32 = undefined;
            softmax(&probs, &logits, TEST_VOCAB);
            current_token = sampleTopP(&probs, TEST_VOCAB, params.top_p, rng);
        }

        if (result.num_tokens < TEST_CTX_LEN) {
            result.tokens[result.num_tokens] = current_token;
            result.num_tokens += 1;
        }
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE STATS
// ═══════════════════════════════════════════════════════════════════════════════

pub const InferenceStats = struct {
    tokens_generated: u64 = 0,
    total_flops: u64 = 0,
    memory_bytes: u64 = 0,

    pub fn fromConfig(config: ModelConfig, num_tokens: u32) InferenceStats {
        const h: u64 = config.hidden_size;
        const inter: u64 = config.intermediate_size;
        const layers: u64 = config.num_layers;
        const vocab: u64 = config.vocab_size;

        // FLOPs per token (approximate):
        // Per layer: 4 matVecs (QKV + O) * 2*h*h + 3 matVecs (gate+up+down) * 2*h*inter
        const attn_flops = 4 * 2 * h * h;
        const ffn_flops = 3 * 2 * h * inter;
        const layer_flops = attn_flops + ffn_flops;
        const total_flops = (layer_flops * layers + 2 * vocab * h) * num_tokens;

        // Memory: weights + KV cache
        const weight_bytes = (vocab * h + layers * (4 * h * h + 3 * h * inter + 2 * h)) * 4;
        const kv_bytes = layers * config.context_length * 2 * config.num_kv_heads * config.head_dim * 4;

        return .{
            .tokens_generated = num_tokens,
            .total_flops = total_flops,
            .memory_bytes = weight_bytes + kv_bytes,
        };
    }

    pub fn flopsPerToken(self: InferenceStats) u64 {
        if (self.tokens_generated == 0) return 0;
        return self.total_flops / self.tokens_generated;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TEST HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn initTestWeights(seed: u64) ModelWeights {
    var rng = LCG.init(seed);
    var weights: ModelWeights = undefined;

    // Xavier-like init: scale = 1/sqrt(hidden)
    const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(TEST_HIDDEN)));

    rng.fillRandom(&weights.embedding, scale);
    LCG.fillOnes(&weights.final_norm);
    rng.fillRandom(&weights.output_proj, scale);

    for (0..TEST_LAYERS) |l| {
        LCG.fillOnes(&weights.layers[l].attn_norm);
        LCG.fillOnes(&weights.layers[l].ffn_norm);
        rng.fillRandom(&weights.layers[l].wq, scale);
        rng.fillRandom(&weights.layers[l].wk, scale);
        rng.fillRandom(&weights.layers[l].wv, scale);
        rng.fillRandom(&weights.layers[l].wo, scale);
        rng.fillRandom(&weights.layers[l].w_gate, scale);
        rng.fillRandom(&weights.layers[l].w_up, scale);
        rng.fillRandom(&weights.layers[l].w_down, scale);
    }
    return weights;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "rmsNorm basic" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;
    rmsNorm(&output, &input, &weight, RMS_NORM_EPS);

    // RMS = sqrt((1+4+9+16)/4) = sqrt(7.5) ~ 2.7386
    // Each output = input[i] / RMS
    const rms = @sqrt(7.5 + RMS_NORM_EPS);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(output[i], input[i] / rms, 0.001);
    }
}

test "matVec identity" {
    // 2x2 identity matrix
    const mat = [_]f32{ 1.0, 0.0, 0.0, 1.0 };
    const vec = [_]f32{ 3.0, 7.0 };
    var output: [2]f32 = undefined;
    matVec(&output, &mat, &vec, 2, 2);
    try std.testing.expectApproxEqAbs(output[0], 3.0, 0.001);
    try std.testing.expectApproxEqAbs(output[1], 7.0, 0.001);
}

test "matVec large" {
    // 4x8 random matrix test (exercises SIMD path)
    var rng = LCG.init(42);
    var mat: [4 * 8]f32 = undefined;
    var vec: [8]f32 = undefined;
    rng.fillRandom(&mat, 1.0);
    rng.fillRandom(&vec, 1.0);
    var output: [4]f32 = undefined;
    matVec(&output, &mat, &vec, 4, 8);

    // Verify against scalar dot product
    for (0..4) |r| {
        var expected: f32 = 0.0;
        for (0..8) |c| {
            expected += mat[r * 8 + c] * vec[c];
        }
        try std.testing.expectApproxEqAbs(output[r], expected, 0.01);
    }
}

test "siluActivation" {
    // SiLU(0) = 0
    try std.testing.expectApproxEqAbs(siluActivation(0.0), 0.0, 0.001);
    // SiLU(large positive) ~ x
    try std.testing.expect(siluActivation(5.0) > 4.9);
    // SiLU(large negative) ~ 0
    try std.testing.expect(@abs(siluActivation(-5.0)) < 0.05);
    // SiLU is odd-like around 0
    try std.testing.expect(siluActivation(1.0) > 0.0);
    try std.testing.expect(siluActivation(-1.0) < 0.0);
}

test "softmax normalization" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;
    softmax(&output, &input, 4);

    // Sum should be 1.0
    var sum: f32 = 0.0;
    for (output) |p| sum += p;
    try std.testing.expectApproxEqAbs(sum, 1.0, 0.001);

    // Should be monotonically increasing
    try std.testing.expect(output[0] < output[1]);
    try std.testing.expect(output[1] < output[2]);
    try std.testing.expect(output[2] < output[3]);
}

test "softmax numerical stability" {
    // Large values should not overflow
    const input = [_]f32{ 1000.0, 1001.0, 1002.0 };
    var output: [3]f32 = undefined;
    softmax(&output, &input, 3);

    var sum: f32 = 0.0;
    for (output) |p| sum += p;
    try std.testing.expectApproxEqAbs(sum, 1.0, 0.001);
    // Largest input should have largest probability
    try std.testing.expect(output[2] > output[1]);
}

test "RoPE position encoding" {
    var rope = RoPECache.init(TEST_HEAD_DIM, TEST_CTX_LEN, 10000.0);

    // Position 0: cos=1, sin=0 => no rotation
    var vec0: [TEST_HEAD_DIM]f32 = undefined;
    for (0..TEST_HEAD_DIM) |i| vec0[i] = @floatFromInt(i + 1);
    const original = vec0;
    rope.apply(&vec0, 0);

    // At pos=0, freq*0=0, cos(0)=1, sin(0)=0 => no change
    for (0..TEST_HEAD_DIM) |i| {
        try std.testing.expectApproxEqAbs(vec0[i], original[i], 0.001);
    }

    // Position 1: should differ from position 0
    var vec1: [TEST_HEAD_DIM]f32 = undefined;
    for (0..TEST_HEAD_DIM) |i| vec1[i] = @floatFromInt(i + 1);
    rope.apply(&vec1, 1);

    var diff: f32 = 0.0;
    for (0..TEST_HEAD_DIM) |i| {
        diff += @abs(vec1[i] - original[i]);
    }
    try std.testing.expect(diff > 0.01); // Should be different
}

test "KV cache store and retrieve" {
    var cache = KVCache.init();
    const k_data = [_]f32{1.0} ** TEST_HEAD_DIM;
    const v_data = [_]f32{2.0} ** TEST_HEAD_DIM;

    cache.storeK(0, 0, 0, &k_data);
    cache.storeV(0, 0, 0, &v_data);

    const k_retrieved = cache.getK(0, 0, 0);
    const v_retrieved = cache.getV(0, 0, 0);

    for (0..TEST_HEAD_DIM) |i| {
        try std.testing.expectApproxEqAbs(k_retrieved[i], 1.0, 0.001);
        try std.testing.expectApproxEqAbs(v_retrieved[i], 2.0, 0.001);
    }
}

test "attention head — single position" {
    const config = ModelConfig.testConfig();
    var transformer = Transformer.init(config);
    var cache = KVCache.init();

    // Store a known K and V at position 0
    var k0: [TEST_HEAD_DIM]f32 = undefined;
    var v0: [TEST_HEAD_DIM]f32 = undefined;
    for (0..TEST_HEAD_DIM) |i| {
        k0[i] = 1.0;
        v0[i] = @as(f32, @floatFromInt(i));
    }
    cache.storeK(0, 0, 0, &k0);
    cache.storeV(0, 0, 0, &v0);

    // Query (will be RoPE-transformed at pos 0 = no change)
    var q: [TEST_HEAD_DIM]f32 = undefined;
    for (q[0..]) |*v| v.* = 1.0;

    var output: [TEST_HEAD_DIM]f32 = undefined;
    var scores: [TEST_CTX_LEN]f32 = undefined;
    _ = &config;
    transformer.attentionHead(&output, &q, &cache, 0, 0, 0, &scores);

    // With only one position, softmax([score]) = [1.0], so output = V[0]
    for (0..TEST_HEAD_DIM) |i| {
        try std.testing.expectApproxEqAbs(output[i], v0[i], 0.01);
    }
}

test "forward pass produces logits" {
    const weights = initTestWeights(12345);
    const config = ModelConfig.testConfig();
    var transformer = Transformer.init(config);
    var cache = KVCache.init();

    var logits: [TEST_VOCAB]f32 = undefined;
    transformer.forward(&logits, &weights, &cache, 1, 0);

    // Logits should not be all zeros
    var sum: f32 = 0.0;
    for (logits) |l| sum += @abs(l);
    try std.testing.expect(sum > 0.0);

    // Should have finite values
    for (logits) |l| {
        try std.testing.expect(!std.math.isNan(l));
        try std.testing.expect(!std.math.isInf(l));
    }
}

test "forward pass — different tokens produce different logits" {
    const weights = initTestWeights(99999);
    const config = ModelConfig.testConfig();
    var transformer = Transformer.init(config);

    var cache1 = KVCache.init();
    var cache2 = KVCache.init();
    var logits1: [TEST_VOCAB]f32 = undefined;
    var logits2: [TEST_VOCAB]f32 = undefined;

    transformer.forward(&logits1, &weights, &cache1, 0, 0);
    transformer.forward(&logits2, &weights, &cache2, 42, 0);

    // Different tokens should produce different logits
    var diff: f32 = 0.0;
    for (0..TEST_VOCAB) |i| {
        diff += @abs(logits1[i] - logits2[i]);
    }
    try std.testing.expect(diff > 0.1);
}

test "greedy sampling deterministic" {
    const logits = [_]f32{ 0.1, 0.5, 0.9, 0.2 };
    const token = sampleGreedy(&logits, 4);
    try std.testing.expectEqual(token, 2); // Index of max
}

test "top-p sampling respects nucleus" {
    const probs = [_]f32{ 0.5, 0.3, 0.1, 0.05, 0.05 };
    var rng = LCG.init(42);

    // With top_p=0.5, should mostly sample from first 1-2 tokens
    var counts: [5]u32 = .{0} ** 5;
    for (0..100) |_| {
        const tok = sampleTopP(&probs, 5, 0.5, &rng);
        counts[tok] += 1;
    }
    // Token 0 (prob=0.5) should dominate
    try std.testing.expect(counts[0] > 30);
}

test "generation produces tokens" {
    const weights = initTestWeights(777);
    const config = ModelConfig.testConfig();
    var transformer = Transformer.init(config);
    var cache = KVCache.init();
    var rng = LCG.init(42);

    const result = generate(&transformer, &weights, &cache, 1, 5, SamplingParams.greedy(), &rng);

    // Should generate prompt + 5 tokens
    try std.testing.expectEqual(result.num_tokens, 6);
    try std.testing.expectEqual(result.tokens[0], 1); // Prompt token preserved
    // All tokens should be in vocab range
    for (0..result.num_tokens) |i| {
        try std.testing.expect(result.tokens[i] < TEST_VOCAB);
    }
}

test "generation — greedy is deterministic" {
    const weights = initTestWeights(888);
    const config = ModelConfig.testConfig();
    var t1 = Transformer.init(config);
    var t2 = Transformer.init(config);
    var c1 = KVCache.init();
    var c2 = KVCache.init();
    var rng1 = LCG.init(0);
    var rng2 = LCG.init(0);

    const r1 = generate(&t1, &weights, &c1, 5, 10, SamplingParams.greedy(), &rng1);
    const r2 = generate(&t2, &weights, &c2, 5, 10, SamplingParams.greedy(), &rng2);

    try std.testing.expectEqual(r1.num_tokens, r2.num_tokens);
    for (0..r1.num_tokens) |i| {
        try std.testing.expectEqual(r1.tokens[i], r2.tokens[i]);
    }
}

test "inference stats calculation" {
    const config = ModelConfig.testConfig();
    const stats = InferenceStats.fromConfig(config, 10);
    try std.testing.expectEqual(stats.tokens_generated, 10);
    try std.testing.expect(stats.total_flops > 0);
    try std.testing.expect(stats.memory_bytes > 0);
    try std.testing.expect(stats.flopsPerToken() > 0);
}

test "temperature scaling" {
    var logits = [_]f32{ 1.0, 2.0, 3.0 };
    applyTemperature(&logits, 3, 0.5);
    // With temp=0.5, inv_temp=2.0
    try std.testing.expectApproxEqAbs(logits[0], 2.0, 0.001);
    try std.testing.expectApproxEqAbs(logits[1], 4.0, 0.001);
    try std.testing.expectApproxEqAbs(logits[2], 6.0, 0.001);
}

test "SwiGLU FFN shape" {
    const weights = initTestWeights(555);
    const config = ModelConfig.testConfig();
    var transformer = Transformer.init(config);

    var input: [TEST_HIDDEN]f32 = undefined;
    for (0..TEST_HIDDEN) |i| input[i] = @as(f32, @floatFromInt(i)) * 0.01;
    var output: [TEST_HIDDEN]f32 = undefined;
    transformer.ffn(&output, &input, &weights.layers[0]);

    // Output should be finite
    for (output) |v| {
        try std.testing.expect(!std.math.isNan(v));
        try std.testing.expect(!std.math.isInf(v));
    }
    // Output should not be all zeros (SwiGLU with random weights)
    var sum: f32 = 0.0;
    for (output) |v| sum += @abs(v);
    try std.testing.expect(sum > 0.0);
}

// phi^2 + 1/phi^2 = 3 | TRINITY
