// HSLM — Sacred Ternary Multi-Head Attention
// 3 heads × 81 dim (TRINITY × 3⁴), sacred scale 1/81^φ⁻³ ≈ 0.354
// Ternary Q,K,V,O projections (add/sub only), float32 attention scores
// φ-RoPE: rotary position encoding with golden-ratio frequencies
// Pre-LN pattern: RMSNorm → Attention → +residual

const std = @import("std");
const math = std.math;
const constants = @import("constants.zig");
const simd_ops = @import("simd_ops.zig");
const ste_mod = @import("ste.zig");

const EMBED_DIM = constants.EMBED_DIM; // 243
const NUM_HEADS = constants.NUM_HEADS; // 3
const HEAD_DIM = constants.HEAD_DIM; // 81
const CONTEXT_LEN = constants.CONTEXT_LEN; // 81
const PHI: f64 = constants.PHI;
const SACRED_GAMMA: f64 = constants.SACRED_GAMMA; // φ⁻³ ≈ 0.2360679

// Sacred attention scale: 1/HEAD_DIM^φ⁻³ ≈ 0.354 (not standard 1/√81 = 0.111)
pub const SACRED_ATTN_SCALE: f32 = @floatCast(1.0 / math.pow(f64, @as(f64, HEAD_DIM), SACRED_GAMMA));

// RoPE: HEAD_DIM=81 is odd → 40 rotation pairs, 1 un-rotated dimension
const ROPE_PAIRS: usize = HEAD_DIM / 2; // 40

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED ATTENTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredAttention = struct {
    // Ternary weight matrices: 243×243 = 59,049 each
    w_q: []i8,
    w_k: []i8,
    w_v: []i8,
    w_o: []i8,
    // Float shadow weights for STE training
    shadow_q: []f32,
    shadow_k: []f32,
    shadow_v: []f32,
    shadow_o: []f32,
    // Gradient accumulators
    grad_q: []f32,
    grad_k: []f32,
    grad_v: []f32,
    grad_o: []f32,

    // RMSNorm: pre-attention, learnable scale
    rms_gamma: []f32, // [EMBED_DIM], init to 1.0
    grad_rms_gamma: []f32, // [EMBED_DIM]

    // φ-RoPE tables (precomputed): CONTEXT_LEN × ROPE_PAIRS
    rope_cos: []f32,
    rope_sin: []f32,

    // Caches for backward (all positions needed since last pos attends to all)
    cache_normed: []f32, // CONTEXT_LEN × EMBED_DIM
    cache_k_rope: []f32, // CONTEXT_LEN × EMBED_DIM (K after RoPE)
    cache_v: []f32, // CONTEXT_LEN × EMBED_DIM
    cache_q_last: [EMBED_DIM]f32, // Q at last position (after RoPE)
    cache_attn_weights: [NUM_HEADS * CONTEXT_LEN]f32, // softmax output at last pos
    cache_concat: [EMBED_DIM]f32, // concatenated heads before W_O
    cache_rms_input: []f32, // CONTEXT_LEN × EMBED_DIM (pre-norm input)
    cache_rms_scale: []f32, // CONTEXT_LEN (rms values per position)
    seq_len: usize,

    // TWN alpha scale factors (per Q/K/V/O, computed during requantize)
    alpha_q: f32 = 1.0,
    alpha_k: f32 = 1.0,
    alpha_v: f32 = 1.0,
    alpha_o: f32 = 1.0,

    is_worker: bool,
    allocator: std.mem.Allocator,

    const Self = @This();
    const WEIGHT_SIZE = EMBED_DIM * EMBED_DIM; // 59,049

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Ternary weights
        const w_q = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_k = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_v = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_o = try allocator.alloc(i8, WEIGHT_SIZE);
        // Shadow floats
        const s_q = try allocator.alloc(f32, WEIGHT_SIZE);
        const s_k = try allocator.alloc(f32, WEIGHT_SIZE);
        const s_v = try allocator.alloc(f32, WEIGHT_SIZE);
        const s_o = try allocator.alloc(f32, WEIGHT_SIZE);
        // Gradients
        const g_q = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_k = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_v = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_o = try allocator.alloc(f32, WEIGHT_SIZE);
        @memset(g_q, 0.0);
        @memset(g_k, 0.0);
        @memset(g_v, 0.0);
        @memset(g_o, 0.0);

        // RMSNorm gamma
        const rms_g = try allocator.alloc(f32, EMBED_DIM);
        const grad_rms_g = try allocator.alloc(f32, EMBED_DIM);
        @memset(rms_g, 1.0);
        @memset(grad_rms_g, 0.0);

        // RoPE tables
        const rope_cos = try allocator.alloc(f32, CONTEXT_LEN * ROPE_PAIRS);
        const rope_sin = try allocator.alloc(f32, CONTEXT_LEN * ROPE_PAIRS);

        // Caches
        const cache_normed = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_k_rope = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_v = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_rms_input = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_rms_scale = try allocator.alloc(f32, CONTEXT_LEN);
        @memset(cache_normed, 0.0);
        @memset(cache_k_rope, 0.0);
        @memset(cache_v, 0.0);
        @memset(cache_rms_input, 0.0);
        @memset(cache_rms_scale, 1.0);

        var self = Self{
            .w_q = w_q,
            .w_k = w_k,
            .w_v = w_v,
            .w_o = w_o,
            .shadow_q = s_q,
            .shadow_k = s_k,
            .shadow_v = s_v,
            .shadow_o = s_o,
            .grad_q = g_q,
            .grad_k = g_k,
            .grad_v = g_v,
            .grad_o = g_o,
            .rms_gamma = rms_g,
            .grad_rms_gamma = grad_rms_g,
            .rope_cos = rope_cos,
            .rope_sin = rope_sin,
            .cache_normed = cache_normed,
            .cache_k_rope = cache_k_rope,
            .cache_v = cache_v,
            .cache_q_last = [_]f32{0.0} ** EMBED_DIM,
            .cache_attn_weights = [_]f32{0.0} ** (NUM_HEADS * CONTEXT_LEN),
            .cache_concat = [_]f32{0.0} ** EMBED_DIM,
            .cache_rms_input = cache_rms_input,
            .cache_rms_scale = cache_rms_scale,
            .seq_len = 0,
            .is_worker = false,
            .allocator = allocator,
        };

        self.initWeights();
        self.initRoPETables();

        return self;
    }

    /// Worker-light init: allocates weights + grads + caches, skips shadow weights.
    /// Workers process forward/backward but never call requantize() or optimizerStep().
    /// Shadow weights are NOT allocated — saves ~0.9MB per SacredAttention instance.
    pub fn initWorker(allocator: std.mem.Allocator) !Self {
        // Ternary weights (will be copied from master via syncWeights)
        const w_q = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_k = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_v = try allocator.alloc(i8, WEIGHT_SIZE);
        const w_o = try allocator.alloc(i8, WEIGHT_SIZE);
        @memset(w_q, 0);
        @memset(w_k, 0);
        @memset(w_v, 0);
        @memset(w_o, 0);
        // Gradients (own copy per worker)
        const g_q = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_k = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_v = try allocator.alloc(f32, WEIGHT_SIZE);
        const g_o = try allocator.alloc(f32, WEIGHT_SIZE);
        @memset(g_q, 0.0);
        @memset(g_k, 0.0);
        @memset(g_v, 0.0);
        @memset(g_o, 0.0);
        // RMSNorm gamma (will be copied from master)
        const rms_g = try allocator.alloc(f32, EMBED_DIM);
        const grad_rms_g = try allocator.alloc(f32, EMBED_DIM);
        @memset(rms_g, 1.0);
        @memset(grad_rms_g, 0.0);
        // RoPE tables
        const rope_cos = try allocator.alloc(f32, CONTEXT_LEN * ROPE_PAIRS);
        const rope_sin = try allocator.alloc(f32, CONTEXT_LEN * ROPE_PAIRS);
        // Caches
        const cache_normed = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_k_rope = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_v = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_rms_input = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const cache_rms_scale = try allocator.alloc(f32, CONTEXT_LEN);
        @memset(cache_normed, 0.0);
        @memset(cache_k_rope, 0.0);
        @memset(cache_v, 0.0);
        @memset(cache_rms_input, 0.0);
        @memset(cache_rms_scale, 1.0);

        var self = Self{
            .w_q = w_q,
            .w_k = w_k,
            .w_v = w_v,
            .w_o = w_o,
            .shadow_q = &.{},
            .shadow_k = &.{},
            .shadow_v = &.{},
            .shadow_o = &.{},
            .grad_q = g_q,
            .grad_k = g_k,
            .grad_v = g_v,
            .grad_o = g_o,
            .rms_gamma = rms_g,
            .grad_rms_gamma = grad_rms_g,
            .rope_cos = rope_cos,
            .rope_sin = rope_sin,
            .cache_normed = cache_normed,
            .cache_k_rope = cache_k_rope,
            .cache_v = cache_v,
            .cache_q_last = [_]f32{0.0} ** EMBED_DIM,
            .cache_attn_weights = [_]f32{0.0} ** (NUM_HEADS * CONTEXT_LEN),
            .cache_concat = [_]f32{0.0} ** EMBED_DIM,
            .cache_rms_input = cache_rms_input,
            .cache_rms_scale = cache_rms_scale,
            .seq_len = 0,
            .is_worker = true,
            .allocator = allocator,
        };

        self.initRoPETables();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.w_q);
        self.allocator.free(self.w_k);
        self.allocator.free(self.w_v);
        self.allocator.free(self.w_o);
        if (!self.is_worker) {
            self.allocator.free(self.shadow_q);
            self.allocator.free(self.shadow_k);
            self.allocator.free(self.shadow_v);
            self.allocator.free(self.shadow_o);
        }
        self.allocator.free(self.grad_q);
        self.allocator.free(self.grad_k);
        self.allocator.free(self.grad_v);
        self.allocator.free(self.grad_o);
        self.allocator.free(self.rms_gamma);
        self.allocator.free(self.grad_rms_gamma);
        self.allocator.free(self.rope_cos);
        self.allocator.free(self.rope_sin);
        self.allocator.free(self.cache_normed);
        self.allocator.free(self.cache_k_rope);
        self.allocator.free(self.cache_v);
        self.allocator.free(self.cache_rms_input);
        self.allocator.free(self.cache_rms_scale);
    }

    pub fn zeroGrad(self: *Self) void {
        @memset(self.grad_q, 0.0);
        @memset(self.grad_k, 0.0);
        @memset(self.grad_v, 0.0);
        @memset(self.grad_o, 0.0);
        @memset(self.grad_rms_gamma, 0.0);
    }

    pub fn requantize(self: *Self) void {
        quantizeAbsMean(self.shadow_q, self.w_q);
        quantizeAbsMean(self.shadow_k, self.w_k);
        quantizeAbsMean(self.shadow_v, self.w_v);
        quantizeAbsMean(self.shadow_o, self.w_o);
    }

    /// STE-aware requantize: uses configured mode, stores alpha for TWN
    pub fn requantizeSte(self: *Self, config: ste_mod.SteConfig, current_step: u32) void {
        self.alpha_q = ste_mod.quantizeForMode(self.shadow_q, self.w_q, config, current_step);
        self.alpha_k = ste_mod.quantizeForMode(self.shadow_k, self.w_k, config, current_step);
        self.alpha_v = ste_mod.quantizeForMode(self.shadow_v, self.w_v, config, current_step);
        self.alpha_o = ste_mod.quantizeForMode(self.shadow_o, self.w_o, config, current_step);
    }

    pub fn resetCache(self: *Self) void {
        self.seq_len = 0;
    }

    /// Process one position (inference or non-last training position).
    /// Caches K_rope and V for attention, but not full backward caches.
    pub fn processPosition(self: *Self, input: []const f32, position: usize, output: []f32) void {
        self.processPositionInner(input, position, output, false);
    }

    /// Process position with full caching for backward (call for last position).
    pub fn processPositionCached(self: *Self, input: []const f32, position: usize, output: []f32) void {
        self.processPositionInner(input, position, output, true);
    }

    fn processPositionInner(self: *Self, input: []const f32, position: usize, output: []f32, cache_for_backward: bool) void {
        const pos = @min(position, CONTEXT_LEN - 1);

        // 1. RMSNorm
        var normed: [EMBED_DIM]f32 = undefined;
        const rms = rmsNormForward(input, self.rms_gamma, &normed);

        // Cache for backward
        const pos_off = pos * EMBED_DIM;
        @memcpy(self.cache_rms_input[pos_off .. pos_off + EMBED_DIM], input[0..EMBED_DIM]);
        self.cache_rms_scale[pos] = rms;
        @memcpy(self.cache_normed[pos_off .. pos_off + EMBED_DIM], &normed);

        // 2. Project Q, K, V via ternary matmul
        var q: [EMBED_DIM]f32 = undefined;
        var k: [EMBED_DIM]f32 = undefined;
        var v: [EMBED_DIM]f32 = undefined;
        simd_ops.ternaryMatvecSimd(&normed, self.w_q, &q, EMBED_DIM, EMBED_DIM);
        simd_ops.ternaryMatvecSimd(&normed, self.w_k, &k, EMBED_DIM, EMBED_DIM);
        simd_ops.ternaryMatvecSimd(&normed, self.w_v, &v, EMBED_DIM, EMBED_DIM);
        ste_mod.applyAlpha(&q, self.alpha_q); // TWN scaling
        ste_mod.applyAlpha(&k, self.alpha_k);
        ste_mod.applyAlpha(&v, self.alpha_v);

        // Cache V
        @memcpy(self.cache_v[pos_off .. pos_off + EMBED_DIM], &v);

        // 3. Apply φ-RoPE to Q and K
        self.applyRoPE(&q, pos);
        self.applyRoPE(&k, pos);

        // Cache K after RoPE
        @memcpy(self.cache_k_rope[pos_off .. pos_off + EMBED_DIM], &k);

        // Cache Q for last pos backward
        if (cache_for_backward) {
            self.cache_q_last = q;
        }

        // Update seq_len
        if (pos + 1 > self.seq_len) {
            self.seq_len = pos + 1;
        }

        // 4. Compute causal attention (per head)
        var concat: [EMBED_DIM]f32 = undefined;
        for (0..NUM_HEADS) |h| {
            const h_start = h * HEAD_DIM;
            const h_end = h_start + HEAD_DIM;

            // Compute scores: Q_h · K_h[j] * SACRED_ATTN_SCALE for j=0..pos
            var scores: [CONTEXT_LEN]f32 = undefined;
            for (0..pos + 1) |j| {
                const j_off = j * EMBED_DIM;
                var dot: f32 = 0.0;
                for (h_start..h_end) |d| {
                    dot += q[d] * self.cache_k_rope[j_off + d];
                }
                scores[j] = dot * SACRED_ATTN_SCALE;
            }

            // Softmax over [0..pos]
            var weights: [CONTEXT_LEN]f32 = undefined;
            softmaxSlice(scores[0 .. pos + 1], weights[0 .. pos + 1]);

            // Cache attention weights for backward
            if (cache_for_backward) {
                @memcpy(
                    self.cache_attn_weights[h * CONTEXT_LEN .. h * CONTEXT_LEN + pos + 1],
                    weights[0 .. pos + 1],
                );
                // Zero out positions beyond pos
                if (pos + 1 < CONTEXT_LEN) {
                    @memset(self.cache_attn_weights[h * CONTEXT_LEN + pos + 1 .. (h + 1) * CONTEXT_LEN], 0.0);
                }
            }

            // 5. Value aggregation
            for (h_start..h_end) |d| {
                var sum: f32 = 0.0;
                for (0..pos + 1) |j| {
                    sum += weights[j] * self.cache_v[j * EMBED_DIM + d];
                }
                concat[d] = sum;
            }
        }

        // Cache concat for backward
        if (cache_for_backward) {
            self.cache_concat = concat;
        }

        // 6. Output projection + residual
        var projected: [EMBED_DIM]f32 = undefined;
        simd_ops.ternaryMatvecSimd(&concat, self.w_o, &projected, EMBED_DIM, EMBED_DIM);
        ste_mod.applyAlpha(&projected, self.alpha_o); // TWN scaling
        for (0..EMBED_DIM) |i| {
            output[i] = input[i] + projected[i]; // residual around attention+norm
        }
    }

    /// Backward from last position. Accumulates grads into grad_q/k/v/o/rms_gamma.
    /// Writes gradient w.r.t. input into grad_input.
    pub fn backward(self: *Self, grad_output: []const f32, grad_input: []f32) void {
        const last_pos = self.seq_len - 1;

        // 1. Residual split: gradient flows to both residual and attention paths
        // grad_residual = grad_output (passed straight through)
        // grad_projected = grad_output (same gradient)

        // 2. Output projection backward: grad_concat from grad_projected through W_O
        var grad_concat: [EMBED_DIM]f32 = undefined;
        simd_ops.ternaryVecmatSimd(grad_output, self.w_o, &grad_concat, EMBED_DIM, EMBED_DIM);
        // W_O weight grad: grad_o[i][j] += grad_output[j] * cache_concat[i]
        simd_ops.outerProductAccumSimd(self.grad_o, grad_output, &self.cache_concat, EMBED_DIM, EMBED_DIM);

        // 3-4. Per-head: value aggregation backward + attention score backward
        var grad_v_all: [CONTEXT_LEN * EMBED_DIM]f32 = [_]f32{0.0} ** (CONTEXT_LEN * EMBED_DIM);
        var grad_q_full: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM;
        var grad_k_all: [CONTEXT_LEN * EMBED_DIM]f32 = [_]f32{0.0} ** (CONTEXT_LEN * EMBED_DIM);

        for (0..NUM_HEADS) |h| {
            const h_start = h * HEAD_DIM;
            const h_end = h_start + HEAD_DIM;
            const aw_off = h * CONTEXT_LEN;

            // Value aggregation backward
            var grad_attn_weight: [CONTEXT_LEN]f32 = [_]f32{0.0} ** CONTEXT_LEN;
            for (0..self.seq_len) |j| {
                const j_off = j * EMBED_DIM;
                for (h_start..h_end) |d| {
                    // grad_v_j[d] += attn_weights[j] * grad_head[d]
                    grad_v_all[j_off + d] += self.cache_attn_weights[aw_off + j] * grad_concat[d];
                    // grad_attn_weight[j] += grad_head[d] * V[j][d]
                    grad_attn_weight[j] += grad_concat[d] * self.cache_v[j_off + d];
                }
            }

            // 5. Softmax backward
            var dot_product: f32 = 0.0;
            for (0..self.seq_len) |j| {
                dot_product += self.cache_attn_weights[aw_off + j] * grad_attn_weight[j];
            }
            var grad_score: [CONTEXT_LEN]f32 = undefined;
            for (0..self.seq_len) |j| {
                grad_score[j] = self.cache_attn_weights[aw_off + j] * (grad_attn_weight[j] - dot_product);
            }

            // 6. Q/K score backward (with sacred scale)
            for (0..self.seq_len) |j| {
                const j_off = j * EMBED_DIM;
                for (h_start..h_end) |d| {
                    grad_q_full[d] += grad_score[j] * self.cache_k_rope[j_off + d] * SACRED_ATTN_SCALE;
                    grad_k_all[j_off + d] += grad_score[j] * self.cache_q_last[d] * SACRED_ATTN_SCALE;
                }
            }
        }

        // 7. RoPE backward (inverse rotation — negate sin, keep cos)
        self.applyRoPEInverse(&grad_q_full, last_pos);
        for (0..self.seq_len) |j| {
            const j_off = j * EMBED_DIM;
            var slice: [EMBED_DIM]f32 = undefined;
            @memcpy(&slice, grad_k_all[j_off .. j_off + EMBED_DIM]);
            self.applyRoPEInverse(&slice, j);
            @memcpy(grad_k_all[j_off .. j_off + EMBED_DIM], &slice);
        }

        // 8. Projection backward
        // Q: grad only from last position
        var grad_normed: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM;
        const last_normed_off = last_pos * EMBED_DIM;

        // grad_normed += grad_q_pre_rope @ W_Q^T (ternary STE)
        simd_ops.ternaryVecmatSimdAccum(&grad_q_full, self.w_q, &grad_normed, EMBED_DIM, EMBED_DIM);
        // W_Q weight grad: from last position only
        simd_ops.outerProductAccumSimd(self.grad_q, &grad_q_full, self.cache_normed[last_normed_off .. last_normed_off + EMBED_DIM], EMBED_DIM, EMBED_DIM);

        // K: weight grads from ALL positions
        for (0..self.seq_len) |pos| {
            const n_off = pos * EMBED_DIM;
            simd_ops.outerProductAccumSimd(self.grad_k, grad_k_all[pos * EMBED_DIM .. pos * EMBED_DIM + EMBED_DIM], self.cache_normed[n_off .. n_off + EMBED_DIM], EMBED_DIM, EMBED_DIM);
        }
        // K: input grad from last position through W_K
        simd_ops.ternaryVecmatSimdAccum(grad_k_all[last_pos * EMBED_DIM .. last_pos * EMBED_DIM + EMBED_DIM], self.w_k, &grad_normed, EMBED_DIM, EMBED_DIM);

        // V: weight grads from ALL positions
        for (0..self.seq_len) |pos| {
            const n_off = pos * EMBED_DIM;
            simd_ops.outerProductAccumSimd(self.grad_v, grad_v_all[pos * EMBED_DIM .. pos * EMBED_DIM + EMBED_DIM], self.cache_normed[n_off .. n_off + EMBED_DIM], EMBED_DIM, EMBED_DIM);
        }
        // V: input grad from last position through W_V
        simd_ops.ternaryVecmatSimdAccum(grad_v_all[last_pos * EMBED_DIM .. last_pos * EMBED_DIM + EMBED_DIM], self.w_v, &grad_normed, EMBED_DIM, EMBED_DIM);

        // 9. RMSNorm backward (last position only)
        const last_input = self.cache_rms_input[last_normed_off .. last_normed_off + EMBED_DIM];
        const last_rms = self.cache_rms_scale[last_pos];

        // grad_gamma[i] += grad_normed[i] * (input[i] / rms)
        for (0..EMBED_DIM) |i| {
            self.grad_rms_gamma[i] += grad_normed[i] * (last_input[i] / last_rms);
        }

        // RMS norm backward → grad_input
        var normalized: [EMBED_DIM]f32 = undefined;
        for (0..EMBED_DIM) |i| {
            normalized[i] = last_input[i] / last_rms;
        }

        var grad_pre_rms: [EMBED_DIM]f32 = undefined;
        // Apply gamma to grad_normed before RMS backward
        var grad_normed_scaled: [EMBED_DIM]f32 = undefined;
        for (0..EMBED_DIM) |i| {
            grad_normed_scaled[i] = grad_normed[i] * self.rms_gamma[i];
        }
        rmsNormBackwardFn(&grad_normed_scaled, &normalized, last_rms, &grad_pre_rms);

        // grad_input = grad_residual + grad_pre_rms
        for (0..EMBED_DIM) |i| {
            grad_input[i] = grad_output[i] + grad_pre_rms[i]; // residual + attention path
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PRIVATE
    // ═══════════════════════════════════════════════════════════════════════════

    fn initWeights(self: *Self) void {
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
        var prng = std.Random.DefaultPrng.init(0x5AC8_ED_A77E);
        const rng = prng.random();

        for (self.shadow_q) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;
        for (self.shadow_k) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;
        for (self.shadow_v) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;
        for (self.shadow_o) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;

        quantizeAbsMean(self.shadow_q, self.w_q);
        quantizeAbsMean(self.shadow_k, self.w_k);
        quantizeAbsMean(self.shadow_v, self.w_v);
        quantizeAbsMean(self.shadow_o, self.w_o);
    }

    fn initRoPETables(self: *Self) void {
        // φ-RoPE: θ_i = φ^(-2i/HEAD_DIM) for i=0..ROPE_PAIRS-1
        for (0..CONTEXT_LEN) |pos| {
            const p: f64 = @floatFromInt(pos);
            for (0..ROPE_PAIRS) |i| {
                const freq = math.pow(f64, PHI, -2.0 * @as(f64, @floatFromInt(i)) / @as(f64, HEAD_DIM));
                const angle = p * freq;
                const idx = pos * ROPE_PAIRS + i;
                self.rope_cos[idx] = @floatCast(@cos(angle));
                self.rope_sin[idx] = @floatCast(@sin(angle));
            }
        }
    }

    /// Apply φ-RoPE: rotate pairs of dimensions
    fn applyRoPE(self: *const Self, vec: []f32, position: usize) void {
        const pos = @min(position, CONTEXT_LEN - 1);
        const table_off = pos * ROPE_PAIRS;

        for (0..NUM_HEADS) |h| {
            const h_off = h * HEAD_DIM;
            for (0..ROPE_PAIRS) |i| {
                const idx0 = h_off + i;
                const idx1 = h_off + i + ROPE_PAIRS;
                // idx1 = h_off + i + 40; max = h_off + 79 < h_off + HEAD_DIM
                if (idx1 >= h_off + HEAD_DIM) break;

                const cos_val = self.rope_cos[table_off + i];
                const sin_val = self.rope_sin[table_off + i];

                const x0 = vec[idx0];
                const x1 = vec[idx1];
                vec[idx0] = x0 * cos_val - x1 * sin_val;
                vec[idx1] = x0 * sin_val + x1 * cos_val;
            }
            // Last dim (index h_off + 80 = h_off + HEAD_DIM - 1) is un-rotated
        }
    }

    /// Inverse RoPE: negate sin for backward
    fn applyRoPEInverse(self: *const Self, vec: []f32, position: usize) void {
        const pos = @min(position, CONTEXT_LEN - 1);
        const table_off = pos * ROPE_PAIRS;

        for (0..NUM_HEADS) |h| {
            const h_off = h * HEAD_DIM;
            for (0..ROPE_PAIRS) |i| {
                const idx0 = h_off + i;
                const idx1 = h_off + i + ROPE_PAIRS;
                if (idx1 >= h_off + HEAD_DIM) break;

                const cos_val = self.rope_cos[table_off + i];
                const sin_val = self.rope_sin[table_off + i]; // negate for inverse

                const x0 = vec[idx0];
                const x1 = vec[idx1];
                vec[idx0] = x0 * cos_val + x1 * sin_val; // +sin (negated)
                vec[idx1] = -x0 * sin_val + x1 * cos_val; // -sin (negated)
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// RMSNorm forward: normed = (input / sqrt(mean(input²) + eps)) * gamma
fn rmsNormForward(input: []const f32, gamma: []const f32, normed: []f32) f32 {
    var rms_sq: f64 = 0.0;
    for (0..EMBED_DIM) |i| {
        rms_sq += @as(f64, input[i]) * @as(f64, input[i]);
    }
    const rms: f32 = @floatCast(@sqrt(rms_sq / @as(f64, EMBED_DIM) + 1e-6));
    for (0..EMBED_DIM) |i| {
        normed[i] = (input[i] / rms) * gamma[i];
    }
    return rms;
}

/// RMS norm backward (same as autograd.rmsNormBackward)
fn rmsNormBackwardFn(grad_output: []const f32, normalized: []const f32, rms_scale: f32, grad_input: []f32) void {
    const d = grad_output.len;
    var dot: f64 = 0.0;
    for (0..d) |i| {
        dot += @as(f64, grad_output[i]) * @as(f64, normalized[i]);
    }
    const mean_dot: f32 = @floatCast(dot / @as(f64, @floatFromInt(d)));
    const inv_rms = 1.0 / rms_scale;
    for (0..d) |i| {
        grad_input[i] = inv_rms * (grad_output[i] - normalized[i] * mean_dot);
    }
}

/// Softmax over a slice
fn softmaxSlice(logits: []const f32, probs: []f32) void {
    var max_val: f32 = logits[0];
    for (logits[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    var sum: f64 = 0.0;
    for (logits, 0..) |v, i| {
        const e: f32 = @floatCast(@exp(@as(f64, v - max_val)));
        probs[i] = e;
        sum += e;
    }
    const inv_sum: f32 = @floatCast(1.0 / sum);
    for (probs[0..logits.len]) |*p| {
        p.* *= inv_sum;
    }
}

/// AbsMean quantization: ternary = RoundClip(float / mean(|float|))
fn quantizeAbsMean(float_weights: []const f32, ternary_weights: []i8) void {
    var sum: f64 = 0.0;
    for (float_weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(float_weights.len));
    const scale: f32 = if (mean_abs > 1e-6) @floatCast(mean_abs) else 1.0;

    for (float_weights, 0..) |w, i| {
        const scaled = w / scale;
        if (scaled > 0.5) {
            ternary_weights[i] = 1;
        } else if (scaled < -0.5) {
            ternary_weights[i] = -1;
        } else {
            ternary_weights[i] = 0;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "sacred attn scale value" {
    // 1/81^φ⁻³ ≈ 0.354
    try std.testing.expect(SACRED_ATTN_SCALE > 0.34);
    try std.testing.expect(SACRED_ATTN_SCALE < 0.36);
    // Verify it's ~3× larger than standard 1/√81 = 0.111
    const standard = 1.0 / @sqrt(@as(f32, 81.0));
    try std.testing.expect(SACRED_ATTN_SCALE > standard * 2.5);
}

test "rope rotation reversible" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    // Create test vector
    var vec: [EMBED_DIM]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(12345);
    const rng = prng.random();
    for (&vec) |*v| v.* = rng.float(f32) * 2.0 - 1.0;

    var original: [EMBED_DIM]f32 = vec;
    _ = &original;

    // Apply RoPE then inverse
    attn.applyRoPE(&vec, 5);
    attn.applyRoPEInverse(&vec, 5);

    for (0..EMBED_DIM) |i| {
        try std.testing.expectApproxEqAbs(original[i], vec[i], 1e-5);
    }
}

test "phi-rope frequencies" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    // At position 1, pair 0: freq = φ^0 = 1.0
    // cos(1.0), sin(1.0)
    const cos_0 = attn.rope_cos[1 * ROPE_PAIRS + 0]; // pos=1, pair=0
    const sin_0 = attn.rope_sin[1 * ROPE_PAIRS + 0];
    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(@cos(1.0))), cos_0, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(@sin(1.0))), sin_0, 1e-5);

    // pair 1: freq = φ^(-2/81)
    const freq1: f64 = std.math.pow(f64, constants.PHI, -2.0 / @as(f64, HEAD_DIM));
    const cos_1 = attn.rope_cos[1 * ROPE_PAIRS + 1];
    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(@cos(freq1))), cos_1, 1e-5);
}

test "causal mask" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    // Process 3 positions
    var input: [EMBED_DIM]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 0.1;

    var output: [EMBED_DIM]f32 = undefined;

    attn.resetCache();
    // Position 0: should only see itself
    attn.processPosition(&input, 0, &output);
    try std.testing.expect(attn.seq_len == 1);

    // Position 1: sees 0,1
    attn.processPosition(&input, 1, &output);
    try std.testing.expect(attn.seq_len == 2);

    // Position 2: sees 0,1,2
    attn.processPosition(&input, 2, &output);
    try std.testing.expect(attn.seq_len == 3);
}

test "attention weights sum to 1" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    var input: [EMBED_DIM]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(77);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 0.1;

    var output: [EMBED_DIM]f32 = undefined;

    attn.resetCache();
    // Process 5 positions, cache on last
    for (0..4) |p| {
        attn.processPosition(&input, p, &output);
    }
    attn.processPositionCached(&input, 4, &output);

    // Check per-head attention weights sum to 1
    for (0..NUM_HEADS) |h| {
        var sum: f64 = 0.0;
        for (0..5) |j| {
            sum += attn.cache_attn_weights[h * CONTEXT_LEN + j];
        }
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), @as(f32, @floatCast(sum)), 1e-5);
    }
}

test "ternary matmul 243x243" {
    // Small known test
    var input: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM;
    input[0] = 1.0;
    input[1] = -1.0;

    var weights: [EMBED_DIM * EMBED_DIM]i8 = [_]i8{0} ** (EMBED_DIM * EMBED_DIM);
    // W[0][0] = 1, W[1][0] = -1 → output[0] = 1*1 + (-1)*(-1) = 2
    weights[0 * EMBED_DIM + 0] = 1;
    weights[1 * EMBED_DIM + 0] = -1;

    var output: [EMBED_DIM]f32 = undefined;
    simd_ops.ternaryMatvecSimd(&input, &weights, &output, EMBED_DIM, EMBED_DIM);

    try std.testing.expectApproxEqAbs(@as(f32, 2.0), output[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), output[1], 1e-6);
}

test "forward produces finite output" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    var input: [EMBED_DIM]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(99);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 0.5 - 0.25;

    var output: [EMBED_DIM]f32 = undefined;

    attn.resetCache();
    for (0..5) |p| {
        attn.processPosition(&input, p, &output);
    }

    for (output) |v| {
        try std.testing.expect(!std.math.isNan(v));
        try std.testing.expect(!std.math.isInf(v));
    }
}

test "backward produces non-zero grads" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    var prng = std.Random.DefaultPrng.init(55);
    const rng = prng.random();

    var output: [EMBED_DIM]f32 = undefined;

    attn.resetCache();
    attn.zeroGrad();

    // Use different inputs per position to create non-degenerate attention
    for (0..4) |p| {
        var input: [EMBED_DIM]f32 = undefined;
        for (&input) |*v| v.* = rng.float(f32) * 2.0 - 1.0;
        if (p < 3) {
            attn.processPosition(&input, p, &output);
        } else {
            attn.processPositionCached(&input, p, &output);
        }
    }

    // Fake gradient (varied for better signal)
    var grad_out: [EMBED_DIM]f32 = undefined;
    for (&grad_out, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 7)) * 0.01 - 0.03;

    var grad_in: [EMBED_DIM]f32 = undefined;
    attn.backward(&grad_out, &grad_in);

    // All 4 projection grads should be non-zero
    const grad_slices = [_][]const f32{ attn.grad_q, attn.grad_k, attn.grad_v, attn.grad_o };
    for (grad_slices) |gs| {
        var any_nonzero = false;
        for (gs) |g| {
            if (g != 0.0) {
                any_nonzero = true;
                break;
            }
        }
        try std.testing.expect(any_nonzero);
    }

    // RMSNorm gamma grad should also be non-zero
    var gamma_nz = false;
    for (attn.grad_rms_gamma) |g| {
        if (g != 0.0) {
            gamma_nz = true;
            break;
        }
    }
    try std.testing.expect(gamma_nz);
}

test "rms norm forward" {
    var input: [EMBED_DIM]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(33);
    const rng = prng.random();
    for (&input) |*v| v.* = rng.float(f32) * 2.0 - 1.0;

    var gamma: [EMBED_DIM]f32 = [_]f32{1.0} ** EMBED_DIM;
    var normed: [EMBED_DIM]f32 = undefined;
    _ = rmsNormForward(&input, &gamma, &normed);

    // RMS of normed should be approximately 1
    var rms_sq: f64 = 0.0;
    for (normed) |v| {
        rms_sq += @as(f64, v) * @as(f64, v);
    }
    const rms: f32 = @floatCast(@sqrt(rms_sq / @as(f64, EMBED_DIM)));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.01);

    _ = &gamma;
}

test "residual gradient flow" {
    const allocator = std.testing.allocator;
    var attn = try SacredAttention.init(allocator);
    defer attn.deinit();

    var input: [EMBED_DIM]f32 = [_]f32{0.1} ** EMBED_DIM;
    var output: [EMBED_DIM]f32 = undefined;

    attn.resetCache();
    attn.zeroGrad();
    attn.processPositionCached(&input, 0, &output);

    var grad_out: [EMBED_DIM]f32 = [_]f32{1.0} ** EMBED_DIM;
    var grad_in: [EMBED_DIM]f32 = undefined;
    attn.backward(&grad_out, &grad_in);

    // grad_input should have both residual (1.0) and attention components
    // So it should NOT be exactly 1.0 everywhere
    var any_diff = false;
    for (grad_in) |g| {
        if (@abs(g - 1.0) > 1e-6) {
            any_diff = true;
            break;
        }
    }
    try std.testing.expect(any_diff);

    // But residual ensures gradient magnitude >= 1.0 in at least some dims
    var has_large_grad = false;
    for (grad_in) |g| {
        if (@abs(g) > 0.5) {
            has_large_grad = true;
            break;
        }
    }
    try std.testing.expect(has_large_grad);
}
