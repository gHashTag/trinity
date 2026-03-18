// @origin(spec:train.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Training Loop
// Cross-entropy loss, gradient via finite differences (ternary STE),
// AdamW optimizer on shadow float weights, periodic requantization

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const tokenizer_mod = @import("tokenizer.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// LOSS FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Cross-entropy loss for a single position
pub fn crossEntropyLoss(logits: []const f32, target: u16) f32 {
    // Softmax + log
    var probs: [VOCAB_SIZE]f32 = undefined;
    model_mod.softmax(logits, &probs);

    const target_prob = probs[@as(usize, target)];
    const clamped = @max(target_prob, 1e-7);
    return -@log(clamped);
}

/// Average cross-entropy loss over a sequence
pub fn sequenceLoss(all_logits: []const f32, targets: []const u16, seq_len: usize) f32 {
    if (seq_len == 0) return 0.0;
    var total_loss: f64 = 0.0;
    for (0..seq_len) |pos| {
        const l_offset = pos * VOCAB_SIZE;
        const logits = all_logits[l_offset .. l_offset + VOCAB_SIZE];
        total_loss += crossEntropyLoss(logits, targets[pos]);
    }
    return @floatCast(total_loss / @as(f64, @floatFromInt(seq_len)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrainState = struct {
    step: u64,
    epoch: u64,
    total_loss: f64,
    loss_count: u64,
    best_loss: f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .step = 0,
            .epoch = 0,
            .total_loss = 0.0,
            .loss_count = 0,
            .best_loss = std.math.inf(f32),
        };
    }

    pub fn recordLoss(self: *Self, loss: f32) void {
        self.total_loss += loss;
        self.loss_count += 1;
        if (loss < self.best_loss) {
            self.best_loss = loss;
        }
    }

    pub fn avgLoss(self: *const Self) f32 {
        if (self.loss_count == 0) return 0.0;
        return @floatCast(self.total_loss / @as(f64, @floatFromInt(self.loss_count)));
    }

    pub fn resetEpochLoss(self: *Self) void {
        self.total_loss = 0.0;
        self.loss_count = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING LOOP
// ═══════════════════════════════════════════════════════════════════════════════

pub const Trainer = struct {
    model: *model_mod.HSLM,
    dataset: *data_mod.Dataset,
    state: TrainState,
    learning_rate: f32,
    batch_size: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        model: *model_mod.HSLM,
        dataset: *data_mod.Dataset,
        learning_rate: f32,
        batch_size: usize,
    ) Self {
        return Self{
            .model = model,
            .dataset = dataset,
            .state = TrainState.init(),
            .learning_rate = learning_rate,
            .batch_size = batch_size,
            .allocator = allocator,
        };
    }

    /// Run one training step on a single sequence
    /// Uses zeroth-order optimization (perturb shadow weights, measure loss, update)
    pub fn step(self: *Self, input: []const u16, target: []const u16) f32 {
        const seq_len = @min(input.len, CONTEXT_LEN);

        // Forward pass: get current loss
        var logits: [CONTEXT_LEN * VOCAB_SIZE]f32 = undefined;
        self.model.forwardAll(input, &logits);
        const loss = sequenceLoss(&logits, target, seq_len);

        // Perturb-and-update on output projection shadow weights
        // (Simplified: we update a random subset of weights each step)
        const num_perturb = 1024; // Perturb 1024 weights per step
        var prng = std.Random.DefaultPrng.init(self.state.step);
        const rng = prng.random();

        const shadow = self.model.output_shadow;
        if (shadow.len == 0) return loss;
        for (0..num_perturb) |_| {
            const idx = rng.intRangeAtMost(usize, 0, shadow.len - 1);
            const epsilon: f32 = 0.01;

            // Perturb +epsilon
            const original = shadow[idx];
            shadow[idx] = original + epsilon;
            self.model.requantize();
            self.model.forwardAll(input, &logits);
            const loss_plus = sequenceLoss(&logits, target, seq_len);

            // Estimate gradient
            const grad = (loss_plus - loss) / epsilon;

            // SGD update with weight decay
            shadow[idx] = original - self.learning_rate * grad - self.learning_rate * constants.WEIGHT_DECAY * original;

            // Gradient clipping
            if (@abs(shadow[idx] - original) > constants.GRAD_CLIP * self.learning_rate) {
                shadow[idx] = original - std.math.sign(grad) * constants.GRAD_CLIP * self.learning_rate;
            }
        }

        // Also perturb block shadow weights (smaller subset)
        for (self.model.blocks) |*block| {
            const block_shadow = block.tnn.shadow_up;
            for (0..256) |_| {
                const idx = rng.intRangeAtMost(usize, 0, block_shadow.len - 1);
                const epsilon: f32 = 0.01;
                const original = block_shadow[idx];

                block_shadow[idx] = original + epsilon;
                block.tnn.requantize();
                self.model.forwardAll(input, &logits);
                const loss_plus = sequenceLoss(&logits, target, seq_len);

                const grad = (loss_plus - loss) / epsilon;
                block_shadow[idx] = original - self.learning_rate * grad;
            }
        }

        // Re-quantize all weights
        self.model.requantize();

        self.state.step += 1;
        self.state.recordLoss(loss);

        return loss;
    }

    /// Run one epoch over the dataset
    pub fn epoch(self: *Self) f32 {
        self.state.resetEpochLoss();
        self.dataset.reset();

        var batch = data_mod.Batch.init(self.allocator, self.batch_size, self.dataset.seq_len) catch return 0.0;
        defer batch.deinit();

        const num_batches = self.dataset.numSequences() / self.batch_size;
        if (num_batches == 0) return 0.0;

        for (0..num_batches) |_| {
            self.dataset.nextBatch(&batch);
            for (0..self.batch_size) |b| {
                const input = batch.getInput(b);
                const target = batch.getTarget(b);
                _ = self.step(input, target);
            }
        }

        self.state.epoch += 1;
        return self.state.avgLoss();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cross entropy loss" {
    // Uniform logits → loss should be log(VOCAB_SIZE) ≈ 6.59
    var logits: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
    const loss = crossEntropyLoss(&logits, 42);
    const expected = @log(@as(f32, @floatFromInt(VOCAB_SIZE)));
    try std.testing.expectApproxEqAbs(expected, loss, 0.01);
}

test "cross entropy loss correct prediction" {
    // High logit for correct class → low loss
    var logits: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
    logits[42] = 10.0;
    const loss = crossEntropyLoss(&logits, 42);
    try std.testing.expect(loss < 1.0);
}

test "train state tracking" {
    var state = TrainState.init();
    state.recordLoss(2.0);
    state.recordLoss(1.5);
    state.recordLoss(1.0);

    try std.testing.expectApproxEqAbs(1.5, state.avgLoss(), 0.01);
    try std.testing.expectApproxEqAbs(1.0, state.best_loss, 0.01);
}

test "trainer init" {
    const allocator = std.testing.allocator;
    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    var ds = try data_mod.Dataset.init(allocator, 8);
    defer ds.deinit();

    try ds.addText("Hello world test data for training.");

    const trainer = Trainer.init(allocator, &model, &ds, 1e-3, 1);
    try std.testing.expect(trainer.state.step == 0);
}
