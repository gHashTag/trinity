// @origin(manual) @regen(pending)
// T-JEPA — Training Loop with JEPA Objective
// Two optimizers: encoder (online HSLM) + predictor (2x LR)
// EMA update after each step, collapse monitoring via repr variance
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const autograd = @import("autograd.zig");
const tjepa_mod = @import("tjepa.zig");
const mse_loss = @import("mse_loss.zig");
const ema_mod = @import("ema.zig");
const trainer_mod = @import("trainer.zig");
const ste_mod = @import("ste.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VOCAB_SIZE = constants.VOCAB_SIZE;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// Per block: TNN + attention params
const TNN_PARAMS_PER_BLOCK: usize = EMBED_DIM * HIDDEN_DIM + HIDDEN_DIM * EMBED_DIM + HIDDEN_DIM + EMBED_DIM;
const ATTN_PARAMS_PER_BLOCK: usize = EMBED_DIM * EMBED_DIM * 4 + EMBED_DIM;
const PARAMS_PER_BLOCK: usize = TNN_PARAMS_PER_BLOCK + ATTN_PARAMS_PER_BLOCK;
const OUTPUT_PARAMS: usize = EMBED_DIM * VOCAB_SIZE + VOCAB_SIZE;
// Default encoder params (for compile-time sizing, runtime uses model.blocks.len)
const ENCODER_TRAINABLE_PARAMS: usize = PARAMS_PER_BLOCK * constants.DEFAULT_BLOCKS + OUTPUT_PARAMS;

// Predictor trainable params
const PREDICTOR_TRAINABLE_PARAMS: usize = tjepa_mod.Predictor.paramCount();

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const TJepaConfig = struct {
    // Inherited from TrainConfig
    lr: f32 = 1e-3,
    lr_min: f32 = 1e-6,
    warmup_steps: u32 = 5000,
    total_steps: u32 = 100000,
    batch_size: usize = 66,
    grad_clip: f32 = 1.0,
    weight_decay: f32 = 0.01,
    // JEPA-specific
    ema_decay_start: f32 = constants.JEPA_EMA_DECAY_START,
    ema_decay_end: f32 = constants.JEPA_EMA_DECAY_END,
    mask_ratio: f32 = constants.JEPA_MASK_RATIO,
    min_span: usize = constants.JEPA_MIN_SPAN,
    max_span: usize = constants.JEPA_MAX_SPAN,
    num_spans: usize = constants.JEPA_NUM_SPANS,
    predictor_lr_mult: f32 = 2.0, // Predictor learns 2x faster (I-JEPA pattern)
    checkpoint_every: u32 = 10000,
    log_every: u32 = 100,
};

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const TJepaMetrics = struct {
    step: u32 = 0,
    mse_loss: f32 = 0.0,
    repr_variance: f32 = 0.0,
    ema_decay: f32 = 0.0,
    best_loss: f32 = std.math.inf(f32),
    best_step: u32 = 0,
    reprvar_at_best: f32 = 0.0,
    total_loss: f64 = 0.0,
    loss_count: u64 = 0,
    lr_current: f32 = 0.0,

    pub fn record(self: *TJepaMetrics, loss: f32, repr_var: f32, decay: f32) void {
        self.mse_loss = loss;
        self.repr_variance = repr_var;
        self.ema_decay = decay;
        self.total_loss += loss;
        self.loss_count += 1;
        if (loss < self.best_loss) {
            self.best_loss = loss;
            self.best_step = self.step;
            self.reprvar_at_best = repr_var;
        }
    }

    pub fn avgLoss(self: *const TJepaMetrics) f32 {
        if (self.loss_count == 0) return 0.0;
        return @floatCast(self.total_loss / @as(f64, @floatFromInt(self.loss_count)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// T-JEPA TRAINER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TJepaTrainer = struct {
    tjepa: *tjepa_mod.TJepa,
    dataset: *data_mod.Dataset,
    config: TJepaConfig,
    metrics: TJepaMetrics,
    // Two optimizers: one for online encoder, one for predictor
    encoder_optimizer: autograd.Lamb,
    predictor_optimizer: autograd.Lamb,
    prng: std.Random.DefaultPrng,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        tjepa: *tjepa_mod.TJepa,
        dataset: *data_mod.Dataset,
        config: TJepaConfig,
    ) !Self {
        var enc_opt = try autograd.Lamb.init(allocator, ENCODER_TRAINABLE_PARAMS, config.lr);
        enc_opt.weight_decay = config.weight_decay;

        var pred_opt = try autograd.Lamb.init(allocator, PREDICTOR_TRAINABLE_PARAMS, config.lr * config.predictor_lr_mult);
        pred_opt.weight_decay = config.weight_decay;

        return Self{
            .tjepa = tjepa,
            .dataset = dataset,
            .config = config,
            .metrics = .{},
            .encoder_optimizer = enc_opt,
            .predictor_optimizer = pred_opt,
            .prng = std.Random.DefaultPrng.init(0xBEFA_5EED),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.encoder_optimizer.deinit();
        self.predictor_optimizer.deinit();
    }

    /// Execute one training step (forward + backward + optimizer + EMA)
    pub fn trainStep(self: *Self, tokens: []const u16) f32 {
        // 1. Zero gradients
        self.tjepa.online.zeroGrad();
        self.tjepa.predictor.zeroGrad();

        // 2. Forward pass (mask + encode + predict + MSE)
        const result = self.tjepa.forward(tokens, self.prng.random());
        if (result.num_masked == 0) return 0.0;

        // 3. Backward pass (MSE → predictor → encoder)
        self.tjepa.backward();

        // 4. LR schedule (cosine)
        self.metrics.lr_current = autograd.lrSchedule(
            self.metrics.step,
            self.config.warmup_steps,
            self.config.total_steps,
            self.config.lr,
        );
        self.encoder_optimizer.lr = self.metrics.lr_current;
        self.encoder_optimizer.t += 1;
        self.predictor_optimizer.lr = self.metrics.lr_current * self.config.predictor_lr_mult;
        self.predictor_optimizer.t += 1;

        // 5. Grad clip + optimizer step: encoder
        self.encoderOptimizerStep();

        // 6. Grad clip + optimizer step: predictor
        self.predictorOptimizerStep();

        // 7. EMA update (target = EMA of online)
        self.tjepa.emaStep(self.metrics.step, self.config.total_steps);

        // 8. Requantize online encoder + predictor block
        self.tjepa.online.requantize();
        self.tjepa.predictor.block.tnn.requantize();
        _ = ste_mod.quantizeAbsMean(self.tjepa.predictor.proj_shadow, self.tjepa.predictor.proj_weights);

        // 9. Update metrics
        const decay = self.tjepa.ema.currentDecay(self.metrics.step, self.config.total_steps);
        self.metrics.record(result.loss, result.repr_variance, decay);
        self.metrics.step += 1;

        return result.loss;
    }

    /// Apply LAMB optimizer to online encoder parameters
    fn encoderOptimizerStep(self: *Self) void {
        const clip = self.config.grad_clip;
        var offset: usize = 0;
        const online = self.tjepa.online;

        // Output projection (grads will be ~zero for JEPA, only weight decay applies)
        autograd.clipGradNorm(online.grad_output_shadow, clip);
        autograd.lambStepSlice(&self.encoder_optimizer, online.output_shadow, online.grad_output_shadow, offset);
        offset += EMBED_DIM * VOCAB_SIZE;
        autograd.lambStepSlice(&self.encoder_optimizer, online.output_bias, online.grad_output_bias, offset);
        offset += VOCAB_SIZE;

        // Block parameters
        for (&online.blocks) |*block| {
            // TNN
            autograd.clipGradNorm(block.tnn.grad_shadow_up, clip);
            autograd.clipGradNorm(block.tnn.grad_shadow_down, clip);
            autograd.lambStepSlice(&self.encoder_optimizer, block.tnn.shadow_up, block.tnn.grad_shadow_up, offset);
            offset += EMBED_DIM * HIDDEN_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.tnn.shadow_down, block.tnn.grad_shadow_down, offset);
            offset += HIDDEN_DIM * EMBED_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.tnn.bias_up, block.tnn.grad_bias_up, offset);
            offset += HIDDEN_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.tnn.bias_down, block.tnn.grad_bias_down, offset);
            offset += EMBED_DIM;

            // Sacred Attention
            autograd.clipGradNorm(block.sacred_attn.grad_q, clip);
            autograd.clipGradNorm(block.sacred_attn.grad_k, clip);
            autograd.clipGradNorm(block.sacred_attn.grad_v, clip);
            autograd.clipGradNorm(block.sacred_attn.grad_o, clip);
            autograd.lambStepSlice(&self.encoder_optimizer, block.sacred_attn.shadow_q, block.sacred_attn.grad_q, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.sacred_attn.shadow_k, block.sacred_attn.grad_k, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.sacred_attn.shadow_v, block.sacred_attn.grad_v, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.sacred_attn.shadow_o, block.sacred_attn.grad_o, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.lambStepSlice(&self.encoder_optimizer, block.sacred_attn.rms_gamma, block.sacred_attn.grad_rms_gamma, offset);
            offset += EMBED_DIM;
        }
        std.debug.assert(offset == ENCODER_TRAINABLE_PARAMS);
    }

    /// Apply LAMB optimizer to predictor parameters
    fn predictorOptimizerStep(self: *Self) void {
        const clip = self.config.grad_clip;
        var offset: usize = 0;
        const pred = &self.tjepa.predictor;

        // Projection
        autograd.clipGradNorm(pred.grad_proj_shadow, clip);
        autograd.lambStepSlice(&self.predictor_optimizer, pred.proj_shadow, pred.grad_proj_shadow, offset);
        offset += EMBED_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.proj_bias, pred.grad_proj_bias, offset);
        offset += EMBED_DIM;

        // Mask token
        autograd.clipGradNorm(&pred.grad_mask_token, clip);
        autograd.lambStepSlice(&self.predictor_optimizer, &pred.mask_token, &pred.grad_mask_token, offset);
        offset += EMBED_DIM;

        // Predictor block: TNN
        autograd.clipGradNorm(pred.block.tnn.grad_shadow_up, clip);
        autograd.clipGradNorm(pred.block.tnn.grad_shadow_down, clip);
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.tnn.shadow_up, pred.block.tnn.grad_shadow_up, offset);
        offset += EMBED_DIM * HIDDEN_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.tnn.shadow_down, pred.block.tnn.grad_shadow_down, offset);
        offset += HIDDEN_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.tnn.bias_up, pred.block.tnn.grad_bias_up, offset);
        offset += HIDDEN_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.tnn.bias_down, pred.block.tnn.grad_bias_down, offset);
        offset += EMBED_DIM;

        // Predictor block: Sacred Attention
        autograd.clipGradNorm(pred.block.sacred_attn.grad_q, clip);
        autograd.clipGradNorm(pred.block.sacred_attn.grad_k, clip);
        autograd.clipGradNorm(pred.block.sacred_attn.grad_v, clip);
        autograd.clipGradNorm(pred.block.sacred_attn.grad_o, clip);
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.sacred_attn.shadow_q, pred.block.sacred_attn.grad_q, offset);
        offset += EMBED_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.sacred_attn.shadow_k, pred.block.sacred_attn.grad_k, offset);
        offset += EMBED_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.sacred_attn.shadow_v, pred.block.sacred_attn.grad_v, offset);
        offset += EMBED_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.sacred_attn.shadow_o, pred.block.sacred_attn.grad_o, offset);
        offset += EMBED_DIM * EMBED_DIM;
        autograd.lambStepSlice(&self.predictor_optimizer, pred.block.sacred_attn.rms_gamma, pred.block.sacred_attn.grad_rms_gamma, offset);
        offset += EMBED_DIM;

        std.debug.assert(offset == PREDICTOR_TRAINABLE_PARAMS);
    }

    /// Check if collapse is happening (repr variance too low)
    pub fn isCollapsing(self: *const Self) bool {
        return self.metrics.repr_variance < 0.01 and self.metrics.step > 100;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tjepa trainer one step" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();

    var tjepa = try tjepa_mod.TJepa.init(allocator, &online);
    defer tjepa.deinit();

    var ds = try data_mod.Dataset.init(allocator, 27);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many times today in the park.");

    var trainer = try TJepaTrainer.init(allocator, &tjepa, &ds, .{});
    defer trainer.deinit();

    const tokens = [_]u16{ 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130 };
    const loss = trainer.trainStep(&tokens);

    try std.testing.expect(!std.math.isNan(loss));
    try std.testing.expect(!std.math.isInf(loss));
    try std.testing.expectEqual(@as(u32, 1), trainer.metrics.step);
}

test "tjepa trainer loss trend" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();

    var tjepa = try tjepa_mod.TJepa.init(allocator, &online);
    defer tjepa.deinit();

    var ds = try data_mod.Dataset.init(allocator, 27);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many times today in the park.");

    var trainer = try TJepaTrainer.init(allocator, &tjepa, &ds, .{});
    defer trainer.deinit();

    const tokens = [_]u16{ 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130 };

    var losses: [10]f32 = undefined;
    for (0..10) |i| {
        losses[i] = trainer.trainStep(&tokens);
    }

    // All losses should be finite
    for (losses) |l| {
        try std.testing.expect(!std.math.isNan(l));
        try std.testing.expect(!std.math.isInf(l));
    }
    // Step should be 10
    try std.testing.expectEqual(@as(u32, 10), trainer.metrics.step);
}

test "tjepa metrics record" {
    var metrics = TJepaMetrics{};
    metrics.record(1.5, 0.3, 0.996);
    metrics.record(1.2, 0.25, 0.997);

    try std.testing.expectApproxEqAbs(@as(f32, 1.2), metrics.mse_loss, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), metrics.best_loss, 1e-5);
    try std.testing.expectEqual(@as(u64, 2), metrics.loss_count);
    // best_step should be 0 (step was 0 when 1.2 was recorded as second call, but step field isn't incremented by record)
    // reprvar_at_best should be 0.25 (from the 1.2 loss record)
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), metrics.reprvar_at_best, 1e-5);

    const avg = metrics.avgLoss();
    try std.testing.expectApproxEqAbs(@as(f32, 1.35), avg, 1e-5);
}
