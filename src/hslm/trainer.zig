// HSLM — Full Training Loop with Autograd
// API defined in specs/tri/hslm_trainer.vibee
// Implementation uses autograd engine for real gradient-based training

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const autograd = @import("autograd.zig");
const tokenizer_mod = @import("tokenizer.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIN CONFIG (from specs/tri/hslm_trainer.vibee)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrainConfig = struct {
    lr: f32 = 3e-4,
    warmup_steps: u32 = 1000,
    total_steps: u32 = 50000,
    batch_size: usize = 9, // 3²
    seq_len: usize = CONTEXT_LEN,
    grad_clip: f32 = 1.0,
    weight_decay: f32 = 0.01,
    checkpoint_every: u32 = 5000,
    log_every: u32 = 100,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIN METRICS (from specs/tri/hslm_trainer.vibee)
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
// FULL TRAINER
// ═══════════════════════════════════════════════════════════════════════════════

pub const FullTrainer = struct {
    model: *model_mod.HSLM,
    dataset: *data_mod.Dataset,
    config: TrainConfig,
    metrics: TrainMetrics,
    optimizer: autograd.AdamW,
    // Output projection tensors for autograd
    output_weight: autograd.Tensor, // [VOCAB_SIZE, EMBED_DIM]
    output_bias: autograd.Tensor, // [1, VOCAB_SIZE]
    logits_tensor: autograd.Tensor, // [1, VOCAB_SIZE]
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        model: *model_mod.HSLM,
        dataset: *data_mod.Dataset,
        config: TrainConfig,
    ) !Self {
        const num_output_params = EMBED_DIM * VOCAB_SIZE + VOCAB_SIZE;
        var opt = try autograd.AdamW.init(allocator, num_output_params, config.lr);
        opt.weight_decay = config.weight_decay;

        const ow = try autograd.Tensor.init(allocator, VOCAB_SIZE, EMBED_DIM, true);
        // Copy model shadow weights into autograd tensor
        @memcpy(ow.data, model.output_shadow);

        const ob = try autograd.Tensor.init(allocator, 1, VOCAB_SIZE, true);
        @memcpy(ob.data, model.output_bias);

        return Self{
            .model = model,
            .dataset = dataset,
            .config = config,
            .metrics = TrainMetrics{},
            .optimizer = opt,
            .output_weight = ow,
            .output_bias = ob,
            .logits_tensor = try autograd.Tensor.init(allocator, 1, VOCAB_SIZE, false),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.optimizer.deinit();
        self.output_weight.deinit();
        self.output_bias.deinit();
        self.logits_tensor.deinit();
    }

    /// One training step with real autograd
    pub fn trainStep(self: *Self, input: []const u16, target: []const u16) f32 {
        const seq_len = @min(input.len, CONTEXT_LEN);

        // Forward pass through model to get hidden representation
        var float_seq: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var trit_seq: [CONTEXT_LEN * constants.VSA_DIM]i8 = undefined;
        self.model.emb.embedSequence(input[0..seq_len], &float_seq, &trit_seq);

        // Get last position hidden state
        const last_off = (seq_len - 1) * EMBED_DIM;
        const hidden = float_seq[last_off .. last_off + EMBED_DIM];

        // Forward: logits = hidden @ W^T + b (using autograd)
        var input_tensor = autograd.Tensor{
            .data = @constCast(hidden),
            .grad = @constCast(&[_]f32{0.0} ** EMBED_DIM),
            .rows = 1,
            .cols = EMBED_DIM,
            .requires_grad = false,
            .allocator = self.allocator,
        };

        autograd.forwardLinear(&input_tensor, &self.output_weight, &self.output_bias, &self.logits_tensor);

        // Compute loss
        const loss = autograd.forwardCrossEntropy(&self.logits_tensor, target[seq_len - 1 ..]);

        // Backward
        self.output_weight.zeroGrad();
        self.output_bias.zeroGrad();
        autograd.backwardCrossEntropy(&self.logits_tensor, target[seq_len - 1 ..]);
        autograd.backwardLinear(&input_tensor, &self.output_weight, &self.output_bias, &self.logits_tensor, false);

        // Clip gradients
        autograd.clipGradNorm(self.output_weight.grad, self.config.grad_clip);
        autograd.clipGradNorm(self.output_bias.grad, self.config.grad_clip);

        // Update learning rate
        self.metrics.lr_current = autograd.lrSchedule(
            self.metrics.step,
            self.config.warmup_steps,
            self.config.total_steps,
            self.config.lr,
        );
        self.optimizer.lr = self.metrics.lr_current;

        // AdamW step on output weights
        self.optimizer.step(self.output_weight.data, self.output_weight.grad);

        // Sync back to model
        @memcpy(self.model.output_shadow, self.output_weight.data);
        @memcpy(self.model.output_bias, self.output_bias.data);
        self.model.requantize();

        // Update metrics
        self.metrics.step += 1;
        self.metrics.record(loss);
        self.metrics.consciousness_ratio = self.model.consciousnessStats().ratio;

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

pub fn saveCheckpoint(model: *model_mod.HSLM, step: u32, loss: f32, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

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
    try std.testing.expectApproxEqAbs(@as(f32, 3e-4), cfg.lr, 1e-7);
    try std.testing.expect(cfg.warmup_steps == 1000);
    try std.testing.expect(cfg.total_steps == 50000);
    try std.testing.expect(cfg.batch_size == 9);
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

    const loss = trainer.trainStep(batch.getInput(0), batch.getTarget(0));
    try std.testing.expect(!std.math.isNan(loss));
    try std.testing.expect(!std.math.isInf(loss));
    try std.testing.expect(loss > 0.0);
    try std.testing.expect(trainer.metrics.step == 1);
}
