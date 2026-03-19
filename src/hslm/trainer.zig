// HSLM — Full Training Loop with Autograd
// API defined in specs/tri/hslm_trainer.tri
// Implementation uses autograd engine for real gradient-based training

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const autograd = @import("autograd.zig");
const tokenizer_mod = @import("tokenizer.zig");
const ste_mod = @import("ste.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIN CONFIG (from specs/tri/hslm_trainer.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrainConfig = struct {
    lr: f32 = 3e-4, // Peak LR (after warmup)
    lr_min: f32 = 1e-6, // Minimum LR at end of cosine decay
    warmup_steps: u32 = 5000,
    total_steps: u32 = 300000,
    batch_size: usize = 64,
    seq_len: usize = CONTEXT_LEN,
    grad_clip: f32 = 1.0, // BitNet-style: max_norm=1.0
    weight_decay: f32 = 0.1,
    checkpoint_every: u32 = 10000,
    log_every: u32 = 100,
    // STE (Straight-Through Estimator) for true ternary training
    ste: ste_mod.SteConfig = .{},
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIN METRICS (from specs/tri/hslm_trainer.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrainMetrics = struct {
    step: u32 = 0,
    loss: f32 = 0.0,
    perplexity: f32 = 0.0,
    lr_current: f32 = 0.0,
    consciousness_ratio: f64 = 0.0,
    tokens_per_sec: f64 = 0.0,
    total_loss: f64 = 0.0,
    loss_count: u64 = 0,
    best_loss: f32 = std.math.inf(f32),

    pub fn record(self: *TrainMetrics, loss: f32) void {
        self.loss = loss;
        self.perplexity = @exp(loss);
        self.total_loss += loss;
        self.loss_count += 1;
        if (loss < self.best_loss) self.best_loss = loss;
    }

    pub fn avgLoss(self: *const TrainMetrics) f32 {
        if (self.loss_count == 0) return 0.0;
        return @floatCast(self.total_loss / @as(f64, @floatFromInt(self.loss_count)));
    }

    pub fn resetEpoch(self: *TrainMetrics) void {
        self.total_loss = 0.0;
        self.loss_count = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINABLE LAYER — wraps shadow floats + ternary weights + autograd tensors
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrainableLayer = struct {
    weight: autograd.Tensor, // [out_dim, in_dim] — shadow float weights
    bias: autograd.Tensor, // [1, out_dim]
    output: autograd.Tensor, // [batch, out_dim]
    hidden: autograd.Tensor, // [batch, hidden_dim] — for relu intermediate

    pub fn init(allocator: std.mem.Allocator, batch: usize, in_dim: usize, hid_dim: usize, out_dim: usize) !TrainableLayer {
        const w = try autograd.Tensor.init(allocator, hid_dim, in_dim, true);
        const b = try autograd.Tensor.init(allocator, 1, hid_dim, true);

        // Xavier init
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(in_dim)));
        var prng = std.Random.DefaultPrng.init(0xADAD_1234);
        const rng = prng.random();
        for (w.data) |*v| v.* = (rng.float(f32) * 2.0 - 1.0) * scale;

        _ = out_dim;

        return TrainableLayer{
            .weight = w,
            .bias = b,
            .output = try autograd.Tensor.init(allocator, batch, hid_dim, false),
            .hidden = try autograd.Tensor.init(allocator, batch, hid_dim, false),
        };
    }

    pub fn deinit(self: *TrainableLayer) void {
        self.weight.deinit();
        self.bias.deinit();
        self.output.deinit();
        self.hidden.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARAMETER BUDGET
// ═══════════════════════════════════════════════════════════════════════════════

// Per block TNN: up_weights(243×729) + down_weights(729×243) + bias_up(729) + bias_down(243) = 355,266
const TNN_PARAMS_PER_BLOCK: usize = EMBED_DIM * HIDDEN_DIM + HIDDEN_DIM * EMBED_DIM + HIDDEN_DIM + EMBED_DIM;
// Per block Attention: Q(243×243) + K(243×243) + V(243×243) + O(243×243) + rms_gamma(243) = 236,439
const ATTN_PARAMS_PER_BLOCK: usize = EMBED_DIM * EMBED_DIM * 4 + EMBED_DIM;
const PARAMS_PER_BLOCK: usize = TNN_PARAMS_PER_BLOCK + ATTN_PARAMS_PER_BLOCK;
const TOTAL_BLOCK_PARAMS: usize = PARAMS_PER_BLOCK * constants.NUM_BLOCKS;
// Output projection: weights(243×729) + bias(729) = 177,876
const OUTPUT_PARAMS: usize = EMBED_DIM * VOCAB_SIZE + VOCAB_SIZE;
const TOTAL_TRAINABLE_PARAMS: usize = TOTAL_BLOCK_PARAMS + OUTPUT_PARAMS;

// ═══════════════════════════════════════════════════════════════════════════════
// FULL TRAINER — STE backprop through all blocks
// ═══════════════════════════════════════════════════════════════════════════════

pub const FullTrainer = struct {
    model: *model_mod.HSLM,
    dataset: *data_mod.Dataset,
    config: TrainConfig,
    metrics: TrainMetrics,
    optimizer: autograd.AdamW,
    // Batch accumulation
    accum_count: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        model: *model_mod.HSLM,
        dataset: *data_mod.Dataset,
        config: TrainConfig,
    ) !Self {
        var opt = try autograd.AdamW.init(allocator, TOTAL_TRAINABLE_PARAMS, config.lr);
        opt.weight_decay = config.weight_decay;

        // Apply STE config to model
        model.ste_config = config.ste;

        return Self{
            .model = model,
            .dataset = dataset,
            .config = config,
            .metrics = TrainMetrics{},
            .optimizer = opt,
            .accum_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.optimizer.deinit();
    }

    /// Accumulate gradients for one sample (call batch_size times, then optimizerStep)
    pub fn accumulateGrad(self: *Self, input: []const u16, target: []const u16) f32 {
        const seq_len = @min(input.len, CONTEXT_LEN);

        // Full forward through blocks with caching
        var logits: [VOCAB_SIZE]f32 = undefined;
        self.model.forwardTrain(input[0..seq_len], &logits);

        // Compute loss (grad buffer on stack)
        var grad_buf: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
        var logits_tensor = autograd.Tensor{
            .data = &logits,
            .grad = &grad_buf,
            .rows = 1,
            .cols = VOCAB_SIZE,
            .requires_grad = false,
            .allocator = self.allocator,
        };
        const loss = autograd.forwardCrossEntropy(&logits_tensor, target[seq_len - 1 ..]);

        // Backward through cross-entropy → output projection → RMS norm → blocks
        autograd.backwardCrossEntropy(&logits_tensor, target[seq_len - 1 ..]);
        self.model.backward(&grad_buf);

        self.accum_count += 1;
        return loss;
    }

    /// Apply accumulated gradients: average → clip → AdamW step → requantize
    pub fn optimizerStep(self: *Self) void {
        if (self.accum_count == 0) return;
        const scale = 1.0 / @as(f32, @floatFromInt(self.accum_count));

        // Sacred φ-cosine LR: warmup → φ-asymmetric decay → lr_min
        self.metrics.lr_current = autograd.sacredLrSchedule(
            self.metrics.step,
            self.config.warmup_steps,
            self.config.total_steps,
            self.config.lr,
            self.config.lr_min,
        );
        self.optimizer.lr = self.metrics.lr_current;
        self.optimizer.t += 1;

        // --- Output projection ---
        // Average + clip output shadow grads
        for (self.model.grad_output_shadow) |*g| g.* *= scale;
        for (self.model.grad_output_bias) |*g| g.* *= scale;
        autograd.clipGradNorm(self.model.grad_output_shadow, self.config.grad_clip);
        autograd.clipGradNorm(self.model.grad_output_bias, self.config.grad_clip);

        // AdamW step on output projection
        var offset: usize = 0;
        autograd.adamwStepSlice(&self.optimizer, self.model.output_shadow, self.model.grad_output_shadow, offset);
        offset += EMBED_DIM * VOCAB_SIZE;
        autograd.adamwStepSlice(&self.optimizer, self.model.output_bias, self.model.grad_output_bias, offset);
        offset += VOCAB_SIZE;

        // --- Block parameters ---
        for (&self.model.blocks) |*block| {
            // --- TNN params ---
            // Average + clip per-block gradients
            for (block.tnn.grad_shadow_up) |*g| g.* *= scale;
            for (block.tnn.grad_shadow_down) |*g| g.* *= scale;
            for (block.tnn.grad_bias_up) |*g| g.* *= scale;
            for (block.tnn.grad_bias_down) |*g| g.* *= scale;

            autograd.clipGradNorm(block.tnn.grad_shadow_up, self.config.grad_clip);
            autograd.clipGradNorm(block.tnn.grad_shadow_down, self.config.grad_clip);

            // AdamW step on TNN params
            autograd.adamwStepSlice(&self.optimizer, block.tnn.shadow_up, block.tnn.grad_shadow_up, offset);
            offset += EMBED_DIM * HIDDEN_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.tnn.shadow_down, block.tnn.grad_shadow_down, offset);
            offset += HIDDEN_DIM * EMBED_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.tnn.bias_up, block.tnn.grad_bias_up, offset);
            offset += HIDDEN_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.tnn.bias_down, block.tnn.grad_bias_down, offset);
            offset += EMBED_DIM;

            // --- Sacred Attention params ---
            for (block.sacred_attn.grad_q) |*g| g.* *= scale;
            for (block.sacred_attn.grad_k) |*g| g.* *= scale;
            for (block.sacred_attn.grad_v) |*g| g.* *= scale;
            for (block.sacred_attn.grad_o) |*g| g.* *= scale;
            for (block.sacred_attn.grad_rms_gamma) |*g| g.* *= scale;

            autograd.clipGradNorm(block.sacred_attn.grad_q, self.config.grad_clip);
            autograd.clipGradNorm(block.sacred_attn.grad_k, self.config.grad_clip);
            autograd.clipGradNorm(block.sacred_attn.grad_v, self.config.grad_clip);
            autograd.clipGradNorm(block.sacred_attn.grad_o, self.config.grad_clip);

            // AdamW step on attention params
            autograd.adamwStepSlice(&self.optimizer, block.sacred_attn.shadow_q, block.sacred_attn.grad_q, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.sacred_attn.shadow_k, block.sacred_attn.grad_k, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.sacred_attn.shadow_v, block.sacred_attn.grad_v, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.sacred_attn.shadow_o, block.sacred_attn.grad_o, offset);
            offset += EMBED_DIM * EMBED_DIM;
            autograd.adamwStepSlice(&self.optimizer, block.sacred_attn.rms_gamma, block.sacred_attn.grad_rms_gamma, offset);
            offset += EMBED_DIM;
        }

        // Verify offset matches total param count (watch point #2)
        std.debug.assert(offset == TOTAL_TRAINABLE_PARAMS);

        // Requantize all ternary weights (STE-aware if mode != none)
        if (self.config.ste.mode != .none) {
            self.model.requantizeSte(self.metrics.step);
        } else {
            self.model.requantize();
        }

        // Zero all grads for next accumulation
        self.model.zeroGrad();
        self.accum_count = 0;

        // Update metrics
        self.metrics.step += 1;
        self.metrics.consciousness_ratio = self.model.consciousnessStats().ratio;
    }

    /// One training step: accumulate one sample and step (for backward compat)
    pub fn trainStep(self: *Self, input: []const u16, target: []const u16) f32 {
        const loss = self.accumulateGrad(input, target);
        self.metrics.record(loss);
        self.optimizerStep();
        return loss;
    }

    /// Train one epoch
    pub fn trainEpoch(self: *Self) f32 {
        self.metrics.resetEpoch();
        self.dataset.reset();

        var batch = data_mod.Batch.init(self.allocator, self.config.batch_size, self.dataset.seq_len) catch return 0.0;
        defer batch.deinit();

        const num_batches = self.dataset.numSequences() / self.config.batch_size;
        if (num_batches == 0) return 0.0;

        for (0..num_batches) |_| {
            self.dataset.nextBatch(&batch);
            for (0..self.config.batch_size) |b| {
                _ = self.trainStep(batch.getInput(b), batch.getTarget(b));
            }
        }

        return self.metrics.avgLoss();
    }

    /// Evaluate on validation data (no gradients)
    pub fn evaluate(self: *Self, val_data: *data_mod.Dataset) f32 {
        val_data.reset();
        var total_loss: f64 = 0.0;
        var count: u64 = 0;

        var batch = data_mod.Batch.init(self.allocator, 1, val_data.seq_len) catch return 0.0;
        defer batch.deinit();

        const num_batches = @min(val_data.numSequences(), 100); // Cap at 100 eval batches
        for (0..num_batches) |_| {
            val_data.nextBatch(&batch);
            const input = batch.getInput(0);
            const target = batch.getTarget(0);

            var logits: [VOCAB_SIZE]f32 = undefined;
            self.model.forward(input, &logits);

            const seq_len = @min(input.len, CONTEXT_LEN);
            const loss = autograd.forwardCrossEntropy(
                &autograd.Tensor{
                    .data = &logits,
                    .grad = @constCast(&[_]f32{0.0} ** VOCAB_SIZE),
                    .rows = 1,
                    .cols = VOCAB_SIZE,
                    .requires_grad = false,
                    .allocator = self.allocator,
                },
                target[seq_len - 1 ..],
            );
            total_loss += loss;
            count += 1;
        }

        if (count == 0) return 0.0;
        return @floatCast(total_loss / @as(f64, @floatFromInt(count)));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT (binary format)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CHECKPOINT_MAGIC: u32 = 0x484C534D; // "HSLM"
pub const CHECKPOINT_VERSION: u32 = 1;

pub fn loadCheckpoint(model: *model_mod.HSLM, path: []const u8) !u32 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.deprecatedReader();

    // Header
    const magic = try reader.readInt(u32, .little);
    if (magic != CHECKPOINT_MAGIC) return error.InvalidCheckpoint;
    const version = try reader.readInt(u32, .little);
    if (version != CHECKPOINT_VERSION) return error.UnsupportedVersion;
    const step = try reader.readInt(u32, .little);
    var loss_bytes: [4]u8 = undefined;
    _ = try reader.readAll(&loss_bytes);

    // Shadow weights (output projection)
    _ = try reader.readAll(std.mem.sliceAsBytes(model.output_shadow));

    // Block shadow weights
    for (&model.blocks) |*block| {
        _ = try reader.readAll(std.mem.sliceAsBytes(block.tnn.shadow_up));
        _ = try reader.readAll(std.mem.sliceAsBytes(block.tnn.shadow_down));
        _ = try reader.readAll(std.mem.sliceAsBytes(block.tnn.bias_up));
        _ = try reader.readAll(std.mem.sliceAsBytes(block.tnn.bias_down));
    }

    // Requantize ternary weights from shadow
    model.requantize();

    return step;
}

pub fn saveCheckpoint(model: *model_mod.HSLM, step: u32, loss: f32, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.deprecatedWriter();

    // Header
    try writer.writeInt(u32, CHECKPOINT_MAGIC, .little);
    try writer.writeInt(u32, CHECKPOINT_VERSION, .little);
    try writer.writeInt(u32, step, .little);
    try writer.writeAll(std.mem.asBytes(&loss));

    // Shadow weights (output projection)
    try writer.writeAll(std.mem.sliceAsBytes(model.output_shadow));

    // Block shadow weights
    for (&model.blocks) |*block| {
        try writer.writeAll(std.mem.sliceAsBytes(block.tnn.shadow_up));
        try writer.writeAll(std.mem.sliceAsBytes(block.tnn.shadow_down));
        try writer.writeAll(std.mem.sliceAsBytes(block.tnn.bias_up));
        try writer.writeAll(std.mem.sliceAsBytes(block.tnn.bias_down));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "train config defaults" {
    const cfg = TrainConfig{};
    try std.testing.expectApproxEqAbs(@as(f32, 3e-4), cfg.lr, 1e-8);
    try std.testing.expectApproxEqAbs(@as(f32, 1e-6), cfg.lr_min, 1e-10);
    try std.testing.expect(cfg.warmup_steps == 5000);
    try std.testing.expect(cfg.total_steps == 300000);
    try std.testing.expect(cfg.batch_size == 64);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cfg.grad_clip, 1e-6);
}

test "train metrics tracking" {
    var m = TrainMetrics{};
    m.record(2.0);
    m.record(1.5);
    m.record(1.0);

    try std.testing.expectApproxEqAbs(1.5, m.avgLoss(), 0.01);
    try std.testing.expectApproxEqAbs(1.0, m.best_loss, 0.01);
    try std.testing.expect(m.perplexity > 0.0);
}

test "full trainer init" {
    const allocator = std.testing.allocator;
    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    var ds = try data_mod.Dataset.init(allocator, 8);
    defer ds.deinit();
    try ds.addText("Hello world test data for training the HSLM model.");

    var trainer = try FullTrainer.init(allocator, &model, &ds, TrainConfig{});
    defer trainer.deinit();

    try std.testing.expect(trainer.metrics.step == 0);
}

test "full trainer one step" {
    const allocator = std.testing.allocator;
    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    var ds = try data_mod.Dataset.init(allocator, 8);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many many times today.");

    var trainer = try FullTrainer.init(allocator, &model, &ds, TrainConfig{});
    defer trainer.deinit();

    var batch = try data_mod.Batch.init(allocator, 1, 8);
    defer batch.deinit();
    ds.nextBatch(&batch);

    // accumulate + step
    const loss = trainer.accumulateGrad(batch.getInput(0), batch.getTarget(0));
    trainer.metrics.record(loss);
    trainer.optimizerStep();

    try std.testing.expect(!std.math.isNan(loss));
    try std.testing.expect(!std.math.isInf(loss));
    try std.testing.expect(loss > 0.0);
    try std.testing.expect(trainer.metrics.step == 1);
}
