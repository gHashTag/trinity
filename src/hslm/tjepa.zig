// @origin(manual) @regen(pending)
// T-JEPA — Ternary Joint-Embedding Predictive Architecture
// First ternary world model: prediction of representations, not tokens
// Online encoder (gradient) + Target encoder (EMA) + Predictor
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const trinity_block = @import("trinity_block.zig");
const ema_mod = @import("ema.zig");
const mask_mod = @import("mask.zig");
const mse_loss = @import("mse_loss.zig");
const sparse_ternary = @import("sparse_ternary.zig");
const simd_ops = @import("simd_ops.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VOCAB_SIZE = constants.VOCAB_SIZE;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const NUM_BLOCKS = constants.NUM_BLOCKS;

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTOR — predicts target representations from context
// ═══════════════════════════════════════════════════════════════════════════════

pub const Predictor = struct {
    // Learned mask embedding (replaces masked positions)
    mask_token: [EMBED_DIM]f32,
    grad_mask_token: [EMBED_DIM]f32,
    shadow_mask_token: [EMBED_DIM]f32,

    // 1 TrinityBlock for prediction (~591K params)
    block: trinity_block.TrinityBlock,

    // Linear projection EMBED_DIM → EMBED_DIM
    proj_weights: []i8,
    proj_shadow: []f32,
    proj_bias: []f32,
    grad_proj_shadow: []f32,
    grad_proj_bias: []f32,

    // Workspace buffers
    assembled_seq: []f32, // CONTEXT_LEN × EMBED_DIM
    pred_output: []f32, // CONTEXT_LEN × EMBED_DIM (block output)

    allocator: std.mem.Allocator,

    const Self = @This();
    pub const PROJ_SIZE = EMBED_DIM * EMBED_DIM;

    pub fn init(allocator: std.mem.Allocator) !Self {
        const block = try trinity_block.TrinityBlock.init(allocator);

        const proj_w = try allocator.alloc(i8, PROJ_SIZE);
        const proj_s = try allocator.alloc(f32, PROJ_SIZE);
        const proj_b = try allocator.alloc(f32, EMBED_DIM);
        const g_proj_s = try allocator.alloc(f32, PROJ_SIZE);
        const g_proj_b = try allocator.alloc(f32, EMBED_DIM);

        const assembled = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const pred_out = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);

        // Xavier init for projection
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
        var prng = std.Random.DefaultPrng.init(0xBEFA_1234);
        const rng = prng.random();
        for (proj_s) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;
        quantizeAbsMean(proj_s, proj_w);

        @memset(proj_b, 0.0);
        @memset(g_proj_s, 0.0);
        @memset(g_proj_b, 0.0);
        @memset(assembled, 0.0);
        @memset(pred_out, 0.0);

        // Init mask token
        var mask_tok: [EMBED_DIM]f32 = undefined;
        for (&mask_tok) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;

        return Self{
            .mask_token = mask_tok,
            .grad_mask_token = [_]f32{0.0} ** EMBED_DIM,
            .shadow_mask_token = mask_tok,
            .block = block,
            .proj_weights = proj_w,
            .proj_shadow = proj_s,
            .proj_bias = proj_b,
            .grad_proj_shadow = g_proj_s,
            .grad_proj_bias = g_proj_b,
            .assembled_seq = assembled,
            .pred_output = pred_out,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.block.deinit();
        self.allocator.free(self.proj_weights);
        self.allocator.free(self.proj_shadow);
        self.allocator.free(self.proj_bias);
        self.allocator.free(self.grad_proj_shadow);
        self.allocator.free(self.grad_proj_bias);
        self.allocator.free(self.assembled_seq);
        self.allocator.free(self.pred_output);
    }

    /// Forward: assemble sequence (context at visible + mask_token at masked),
    /// run through block, project masked positions → predicted representations
    pub fn forward(
        self: *Self,
        context_hidden: []const f32, // online encoder hidden states (seq_len × EMBED_DIM)
        mask_result: *const mask_mod.MaskResult,
        seq_len: usize,
        predicted_out: []f32, // num_masked × EMBED_DIM output
    ) void {
        // 1. Assemble: visible positions get context, masked get mask_token
        for (0..seq_len) |pos| {
            const off = pos * EMBED_DIM;
            if (mask_result.visible[pos]) {
                @memcpy(self.assembled_seq[off .. off + EMBED_DIM], context_hidden[off .. off + EMBED_DIM]);
            } else {
                @memcpy(self.assembled_seq[off .. off + EMBED_DIM], &self.mask_token);
            }
        }

        // 2. Process through predictor block (position by position)
        self.block.sacred_attn.resetCache();
        for (0..seq_len) |pos| {
            const f_off = pos * EMBED_DIM;
            // Use block's forward_float (TNN + sacred attention only, no VSA)
            self.block.sacred_attn.processPosition(
                self.assembled_seq[f_off .. f_off + EMBED_DIM],
                pos,
                self.pred_output[f_off .. f_off + EMBED_DIM],
            );
            // TNN FFN
            var tnn_out: [EMBED_DIM]f32 = undefined;
            self.block.tnn.forward(
                self.pred_output[f_off .. f_off + EMBED_DIM],
                &tnn_out,
            );
            @memcpy(self.pred_output[f_off .. f_off + EMBED_DIM], &tnn_out);
        }

        // 3. Extract + project masked positions
        for (0..mask_result.num_masked) |mi| {
            const pos = mask_result.masked_positions[mi];
            const src_off = pos * EMBED_DIM;
            const dst_off = mi * EMBED_DIM;

            // Linear projection: out = W * hidden + bias
            sparse_ternary.branchlessMatvec(
                self.pred_output[src_off .. src_off + EMBED_DIM],
                self.proj_weights,
                predicted_out[dst_off .. dst_off + EMBED_DIM],
                EMBED_DIM,
                EMBED_DIM,
            );
            for (0..EMBED_DIM) |j| {
                predicted_out[dst_off + j] += self.proj_bias[j];
            }
        }
    }

    /// Backward through predictor: projection → block → assembly
    /// Computes gradients for proj weights, mask_token, and returns grad on context_hidden
    pub fn backward(
        self: *Self,
        grad_predicted: []const f32, // num_masked × EMBED_DIM
        mask_result: *const mask_mod.MaskResult,
        seq_len: usize,
        grad_context_hidden: []f32, // seq_len × EMBED_DIM output (grads for online encoder)
    ) void {
        @memset(grad_context_hidden[0 .. seq_len * EMBED_DIM], 0.0);

        // Step 1: Projection backward at each masked position
        var grad_block_output: [CONTEXT_LEN * EMBED_DIM]f32 = [_]f32{0.0} ** (CONTEXT_LEN * EMBED_DIM);

        for (0..mask_result.num_masked) |mi| {
            const pos = mask_result.masked_positions[mi];
            const mi_off = mi * EMBED_DIM;
            const pos_off = pos * EMBED_DIM;

            // grad_pred_output = W_proj * grad_predicted (vecmat = transpose multiply)
            sparse_ternary.branchlessVecmatAccum(
                grad_predicted[mi_off .. mi_off + EMBED_DIM],
                self.proj_weights,
                grad_block_output[pos_off .. pos_off + EMBED_DIM],
                EMBED_DIM,
                EMBED_DIM,
            );

            // Weight gradient: ∂L/∂W[i][j] += grad_predicted[j] * pred_output[i]
            simd_ops.outerProductAccumSimd(
                self.grad_proj_shadow,
                grad_predicted[mi_off .. mi_off + EMBED_DIM],
                self.pred_output[pos_off .. pos_off + EMBED_DIM],
                EMBED_DIM,
                EMBED_DIM,
            );

            // Bias gradient
            for (0..EMBED_DIM) |j| {
                self.grad_proj_bias[j] += grad_predicted[mi_off + j];
            }
        }

        // Step 2: Block backward (approximate — uses last position's cached state)
        // Sum all position gradients for a single backward pass through TNN
        var grad_sum: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM;
        for (0..seq_len) |pos| {
            const off = pos * EMBED_DIM;
            for (0..EMBED_DIM) |j| {
                grad_sum[j] += grad_block_output[off + j];
            }
        }

        var grad_assembled_sum: [EMBED_DIM]f32 = undefined;
        self.block.tnn.backward(&grad_sum, &grad_assembled_sum);

        // Step 3: Scatter averaged gradient to context_hidden and mask_token
        const inv_seq: f32 = 1.0 / @as(f32, @floatFromInt(@max(seq_len, 1)));
        for (0..seq_len) |pos| {
            const off = pos * EMBED_DIM;
            if (mask_result.visible[pos]) {
                for (0..EMBED_DIM) |j| {
                    grad_context_hidden[off + j] = grad_assembled_sum[j] * inv_seq;
                }
            } else {
                for (0..EMBED_DIM) |j| {
                    self.grad_mask_token[j] += grad_assembled_sum[j] * inv_seq;
                }
            }
        }
    }

    /// Zero all gradient buffers
    pub fn zeroGrad(self: *Self) void {
        @memset(&self.grad_mask_token, 0.0);
        @memset(self.grad_proj_shadow, 0.0);
        @memset(self.grad_proj_bias, 0.0);
        self.block.tnn.zeroGrad();
        self.block.sacred_attn.zeroGrad();
    }

    /// Parameter count for predictor
    pub fn paramCount() usize {
        const tnn_params = EMBED_DIM * HIDDEN_DIM + HIDDEN_DIM * EMBED_DIM + HIDDEN_DIM + EMBED_DIM;
        const attn_params = EMBED_DIM * EMBED_DIM * 4 + EMBED_DIM;
        const proj_params = EMBED_DIM * EMBED_DIM + EMBED_DIM;
        const mask_params = EMBED_DIM;
        return tnn_params + attn_params + proj_params + mask_params;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// T-JEPA MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const JepaForwardResult = struct {
    loss: f32,
    repr_variance: f32,
    num_masked: usize,
};

pub const TJepa = struct {
    online: *model_mod.HSLM, // Trained via gradients
    target: model_mod.HSLM, // EMA copy (no grad updates)
    predictor: Predictor,
    ema: ema_mod.EmaSync,
    mask_config: mask_mod.MaskConfig,

    // Workspace buffers
    online_hidden: []f32, // CONTEXT_LEN × EMBED_DIM
    target_hidden: []f32, // CONTEXT_LEN × EMBED_DIM
    predicted: []f32, // CONTEXT_LEN × EMBED_DIM (max masked)
    target_masked: []f32, // CONTEXT_LEN × EMBED_DIM (extracted target reps)
    grad_predicted: []f32, // CONTEXT_LEN × EMBED_DIM (MSE backward output)
    grad_context: []f32, // CONTEXT_LEN × EMBED_DIM (predictor backward output)

    // Cached from forward for backward
    cached_mask_result: mask_mod.MaskResult,
    cached_seq_len: usize,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, online: *model_mod.HSLM) !Self {
        var target = try model_mod.HSLM.init(allocator);

        // Initialize target as copy of online (via EMA with decay=0)
        const ema = ema_mod.EmaSync{
            .decay_start = constants.JEPA_EMA_DECAY_START,
            .decay_end = constants.JEPA_EMA_DECAY_END,
        };
        // Copy online → target
        ema_mod.EmaSync.updateShadows(target.output_shadow, online.output_shadow, 0.0);
        for (&target.blocks, &online.blocks) |*tb, *ob| {
            ema_mod.EmaSync.updateShadows(tb.tnn.shadow_up, ob.tnn.shadow_up, 0.0);
            ema_mod.EmaSync.updateShadows(tb.tnn.shadow_down, ob.tnn.shadow_down, 0.0);
            ema_mod.EmaSync.updateShadows(tb.tnn.bias_up, ob.tnn.bias_up, 0.0);
            ema_mod.EmaSync.updateShadows(tb.tnn.bias_down, ob.tnn.bias_down, 0.0);
            ema_mod.EmaSync.updateShadows(tb.sacred_attn.shadow_q, ob.sacred_attn.shadow_q, 0.0);
            ema_mod.EmaSync.updateShadows(tb.sacred_attn.shadow_k, ob.sacred_attn.shadow_k, 0.0);
            ema_mod.EmaSync.updateShadows(tb.sacred_attn.shadow_v, ob.sacred_attn.shadow_v, 0.0);
            ema_mod.EmaSync.updateShadows(tb.sacred_attn.shadow_o, ob.sacred_attn.shadow_o, 0.0);
            ema_mod.EmaSync.updateShadows(tb.sacred_attn.rms_gamma, ob.sacred_attn.rms_gamma, 0.0);
        }
        ema_mod.EmaSync.updateShadows(target.emb.float_table, online.emb.float_table, 0.0);
        target.requantize();

        const predictor = try Predictor.init(allocator);

        const online_h = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const target_h = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const pred = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const tgt_m = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const grad_pred = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        const grad_ctx = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);
        @memset(online_h, 0.0);
        @memset(target_h, 0.0);
        @memset(pred, 0.0);
        @memset(tgt_m, 0.0);
        @memset(grad_pred, 0.0);
        @memset(grad_ctx, 0.0);

        return Self{
            .online = online,
            .target = target,
            .predictor = predictor,
            .ema = ema,
            .mask_config = .{
                .mask_ratio = constants.JEPA_MASK_RATIO,
                .min_span = constants.JEPA_MIN_SPAN,
                .max_span = constants.JEPA_MAX_SPAN,
                .num_spans = constants.JEPA_NUM_SPANS,
            },
            .online_hidden = online_h,
            .target_hidden = target_h,
            .predicted = pred,
            .target_masked = tgt_m,
            .grad_predicted = grad_pred,
            .grad_context = grad_ctx,
            .cached_mask_result = undefined,
            .cached_seq_len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.target.deinit();
        self.predictor.deinit();
        self.allocator.free(self.online_hidden);
        self.allocator.free(self.target_hidden);
        self.allocator.free(self.predicted);
        self.allocator.free(self.target_masked);
        self.allocator.free(self.grad_predicted);
        self.allocator.free(self.grad_context);
    }

    /// Forward pass: mask → encode → predict → MSE loss
    /// Caches mask_result and seq_len for backward()
    pub fn forward(self: *Self, tokens: []const u16, rng: std.Random) JepaForwardResult {
        const seq_len = @min(tokens.len, CONTEXT_LEN);
        self.cached_seq_len = seq_len;

        // 1. Generate mask
        var mask_result = mask_mod.generateMask(seq_len, self.mask_config, rng);
        if (mask_result.num_masked == 0) {
            self.cached_mask_result = mask_result;
            return .{ .loss = 0.0, .repr_variance = 0.0, .num_masked = 0 };
        }

        // 2. Online encoder: get hidden states at all positions
        self.online.forwardHidden(tokens, self.online_hidden);

        // 3. Target encoder: get hidden states (no gradient)
        self.target.forwardHidden(tokens, self.target_hidden);

        // 4. Predictor: predict target representations at masked positions
        self.predictor.forward(self.online_hidden, &mask_result, seq_len, self.predicted);

        // 5. Extract target representations at masked positions
        for (0..mask_result.num_masked) |mi| {
            const pos = mask_result.masked_positions[mi];
            const src_off = pos * EMBED_DIM;
            const dst_off = mi * EMBED_DIM;
            @memcpy(self.target_masked[dst_off .. dst_off + EMBED_DIM], self.target_hidden[src_off .. src_off + EMBED_DIM]);
        }

        // 6. L2-normalize both (CRITICAL anti-collapse)
        for (0..mask_result.num_masked) |mi| {
            const off = mi * EMBED_DIM;
            mse_loss.l2Normalize(self.predicted[off .. off + EMBED_DIM], EMBED_DIM);
            mse_loss.l2Normalize(self.target_masked[off .. off + EMBED_DIM], EMBED_DIM);
        }

        // 7. MSE loss
        const loss = mse_loss.forwardMse(
            self.predicted[0 .. mask_result.num_masked * EMBED_DIM],
            self.target_masked[0 .. mask_result.num_masked * EMBED_DIM],
            mask_result.num_masked,
            EMBED_DIM,
        );

        // 8. Representation variance (collapse monitoring)
        const repr_var = mse_loss.representationVariance(
            self.target_hidden[0 .. seq_len * EMBED_DIM],
            seq_len,
            EMBED_DIM,
        );

        self.cached_mask_result = mask_result;

        return .{
            .loss = loss,
            .repr_variance = repr_var,
            .num_masked = mask_result.num_masked,
        };
    }

    /// Backward pass: MSE grad → predictor backward → encoder backward
    /// Must be called after forward(). Accumulates gradients in:
    ///   - predictor.grad_proj_shadow, grad_proj_bias, grad_mask_token, block grads
    ///   - online.blocks[*].tnn.grad_*, online.blocks[*].sacred_attn.grad_*
    pub fn backward(self: *Self) void {
        if (self.cached_mask_result.num_masked == 0) return;
        const seq_len = self.cached_seq_len;
        const num_masked = self.cached_mask_result.num_masked;

        // 1. MSE backward: dL/d(pred) = 2*(pred - target) / N
        mse_loss.backwardMse(
            self.predicted[0 .. num_masked * EMBED_DIM],
            self.target_masked[0 .. num_masked * EMBED_DIM],
            self.grad_predicted[0 .. num_masked * EMBED_DIM],
            num_masked,
            EMBED_DIM,
        );

        // 2. Predictor backward: projection → block → assembly
        self.predictor.backward(
            self.grad_predicted[0 .. num_masked * EMBED_DIM],
            &self.cached_mask_result,
            seq_len,
            self.grad_context[0 .. seq_len * EMBED_DIM],
        );

        // 3. Online encoder backward: average visible position gradients
        var avg_grad: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM;
        var visible_count: usize = 0;
        for (0..seq_len) |pos| {
            if (self.cached_mask_result.visible[pos]) {
                const off = pos * EMBED_DIM;
                for (0..EMBED_DIM) |j| {
                    avg_grad[j] += self.grad_context[off + j];
                }
                visible_count += 1;
            }
        }
        if (visible_count > 0) {
            const scale = 1.0 / @as(f32, @floatFromInt(visible_count));
            for (&avg_grad) |*g| g.* *= scale;
        }
        self.online.backwardHidden(&avg_grad);
    }

    /// EMA update: sync target from online, then requantize target
    pub fn emaStep(self: *Self, step: u32, total_steps: u32) void {
        self.ema.syncModels(&self.target, self.online, step, total_steps);
        self.target.requantize();
    }

    /// Total parameter count (online encoder + predictor)
    pub fn totalParams() usize {
        const encoder_params = (constants.Config{}).paramCount();
        return encoder_params + Predictor.paramCount();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn quantizeAbsMean(float_weights: []const f32, ternary_weights: []i8) void {
    var sum: f64 = 0.0;
    for (float_weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(float_weights.len));
    const s: f32 = if (mean_abs > 1e-6) @floatCast(mean_abs) else 1.0;

    for (float_weights, 0..) |w, i| {
        const scaled = w / s;
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

test "predictor dimensions" {
    const allocator = std.testing.allocator;
    var pred = try Predictor.init(allocator);
    defer pred.deinit();

    // Param count should be reasonable (~650K)
    const params = Predictor.paramCount();
    try std.testing.expect(params > 500_000);
    try std.testing.expect(params < 800_000);
}

test "tjepa forward finite loss" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();

    var tjepa = try TJepa.init(allocator, &online);
    defer tjepa.deinit();

    const tokens = [_]u16{ 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130 };
    var prng = std.Random.DefaultPrng.init(42);
    const result = tjepa.forward(&tokens, prng.random());

    try std.testing.expect(!std.math.isNan(result.loss));
    try std.testing.expect(!std.math.isInf(result.loss));
    try std.testing.expect(result.loss >= 0.0);
}

test "target no gradients" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();

    var tjepa = try TJepa.init(allocator, &online);
    defer tjepa.deinit();

    // Target grad buffers should be zero
    for (tjepa.target.grad_output_shadow) |g| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), g, 1e-10);
    }
    for (tjepa.target.blocks[0].tnn.grad_shadow_up) |g| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), g, 1e-10);
    }
}

test "tjepa init deinit no leak" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();

    var tjepa = try TJepa.init(allocator, &online);
    tjepa.deinit();
    // If we reach here without allocator error, no leak
}
