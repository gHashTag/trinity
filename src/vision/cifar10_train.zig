// CIFAR-10 Training Loop
// Adam optimizer with cross-entropy loss
//
// Phase 1: Simple SGD with learning rate decay
// Phase 2+: Adam optimizer with sacred cosine schedule
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// Direct inline imports to avoid Zig 0.15 module conflicts
pub const CIFAR10Model = @import("cifar10_model.zig").CIFAR10Model;
pub const CIFAR10Config = @import("cifar10_model.zig").CIFAR10Config;

pub const CIFAR10Image = @import("cifar10_loader.zig").CIFAR10Image;
pub const CIFAR10Batch = @import("cifar10_loader.zig").CIFAR10Batch;
pub const CIFAR10Dataset = @import("cifar10_loader.zig").CIFAR10Dataset;
pub const normalizePixel = @import("cifar10_loader.zig").normalizePixel;

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const CIFAR10Metrics = struct {
    loss: f32,
    accuracy: f32,
    correct: usize,
    total: usize,

    pub fn init() CIFAR10Metrics {
        return .{
            .loss = 0.0,
            .accuracy = 0.0,
            .correct = 0,
            .total = 0,
        };
    }

    pub fn updateLoss(self: *CIFAR10Metrics, loss: f32) void {
        self.loss = loss;
    }

    pub fn updateAccuracy(self: *CIFAR10Metrics, predicted: usize, target: u8) void {
        self.total += 1;
        if (predicted == target) {
            self.correct += 1;
        }
        self.accuracy = @as(f32, @floatFromInt(self.correct)) / @as(f32, @floatFromInt(self.total));
    }

    pub fn reset(self: *CIFAR10Metrics) void {
        self.* = init();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple SGD optimizer (Phase 1 baseline)
pub const SGDOptimizer = struct {
    learning_rate: f64,
    weight_decay: f64,

    pub fn init(learning_rate: f64, weight_decay: f64) SGDOptimizer {
        return .{
            .learning_rate = learning_rate,
            .weight_decay = weight_decay,
        };
    }

    pub fn step(self: *SGDOptimizer, params: []f32, grads: []f32) void {
        for (params, grads) |*p, *g| {
            // Apply weight decay
            p.* *= @as(f32, @floatCast(1.0 - self.learning_rate * self.weight_decay));

            // Apply gradient
            p.* -= @as(f32, @floatCast(self.learning_rate * g.*));
        }
    }
};

/// Adam optimizer (Phase 2)
pub const AdamOptimizer = struct {
    learning_rate: f64,
    beta1: f64,
    beta2: f64,
    epsilon: f64,
    weight_decay: f64,
    t: usize,

    // State (managed externally for simplicity)
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: CIFAR10Config) !Self {
        _ = config;
        return .{
            .learning_rate = 0.001,
            .beta1 = 0.9,
            .beta2 = 0.999,
            .epsilon = 1e-8,
            .weight_decay = 0.0,
            .t = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    // Note: Full Adam implementation requires moment storage
    // Phase 1 uses simple SGD
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CIFAR10Trainer = struct {
    model: *CIFAR10Model,
    optimizer: SGDOptimizer,
    learning_rate: f64,
    epoch: usize,
    metrics: CIFAR10Metrics,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, model: *CIFAR10Model, config: CIFAR10Config) !Self {
        _ = allocator;
        return .{
            .model = model,
            .optimizer = SGDOptimizer.init(config.learning_rate, config.weight_decay),
            .learning_rate = config.learning_rate,
            .epoch = 0,
            .metrics = CIFAR10Metrics.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Train on single image with backpropagation
    pub fn trainStep(self: *Self, image: CIFAR10Image) !CIFAR10Metrics {
        // Convert image to float tensor (on stack, freed after step)
        var input: [3072]f32 = undefined;
        for (0..3072) |i| {
            input[i] = normalizePixel(image.data[@intCast(i)]);
        }

        // Forward + backward pass with SGD
        const loss = try self.model.backward(&input, image.label, self.optimizer.learning_rate);

        // Update metrics (skip if loss is NaN/0 sentinel from backward)
        if (!std.math.isNan(loss)) {
            self.metrics.updateLoss(loss);
        }

        // Get prediction for accuracy
        var probs: [10]f32 = undefined;
        const pred = try self.model.predict(&input, &probs);

        self.metrics.updateAccuracy(pred, image.label);

        return self.metrics;
    }

    /// Validate on dataset
    pub fn validate(self: *Self, dataset: *CIFAR10Dataset, allocator: std.mem.Allocator) !CIFAR10Metrics {
        _ = allocator;
        const metrics = CIFAR10Metrics.init();

        for (dataset.images.items) |img| {
            // Convert to float (stack allocated)
            var input: [3072]f32 = undefined;
            for (0..3072) |i| {
                input[i] = normalizePixel(img.data[i]);
            }

            // Predict
            var probs: [10]f32 = undefined;
            const prediction = try self.model.predict(&input, &probs);

            metrics.updateAccuracy(prediction, img.label);
        }

        return metrics;
    }

    /// Validate on dataset (mutable version for use cases that need mutability)
    pub fn validateMut(self: *Self, dataset: *CIFAR10Dataset, allocator: std.mem.Allocator) !CIFAR10Metrics {
        const metrics = CIFAR10Metrics.init();
        const input = try allocator.alloc(f32, 3072);
        defer allocator.free(input);

        for (dataset.images.items) |img| {
            // Convert to float
            for (0..3072) |i| {
                input[i] = normalizePixel(img.data[i]);
            }

            // Predict
            var probs: [10]f32 = undefined;
            const prediction = try self.model.predict(input, &probs);

            metrics.updateAccuracy(prediction, img.label);
        }

        return metrics;
    }

    /// Train for one epoch
    pub fn trainEpoch(self: *Self, dataset: *CIFAR10Dataset, batch_size: usize, allocator: std.mem.Allocator) !CIFAR10Metrics {
        self.epoch += 1;

        // Create batches and train
        var start_idx: usize = 0;
        while (start_idx < dataset.images.items.len) {
            var batch = try dataset.createBatch(allocator, start_idx, batch_size);
            defer batch.deinit();

            for (batch.images.items) |img| {
                _ = try self.trainStep(img);
            }

            start_idx += batch_size;
        }

        return self.metrics;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "cifar10_train: metrics init" {
    const metrics = CIFAR10Metrics.init();

    try testing.expect(metrics.loss == 0.0);
    try testing.expect(metrics.accuracy == 0.0);
    try testing.expect(metrics.correct == 0);
    try testing.expect(metrics.total == 0);
}

test "cifar10_train: metrics update accuracy" {
    var metrics = CIFAR10Metrics.init();

    // Add some predictions
    metrics.updateAccuracy(5, 5); // Correct
    metrics.updateAccuracy(3, 5); // Wrong
    metrics.updateAccuracy(5, 5); // Correct

    try testing.expect(metrics.total == 3);
    try testing.expect(metrics.correct == 2);
    try testing.expectApproxEqAbs(metrics.accuracy, 2.0 / 3.0, 0.001);
}

test "cifar10_train: metrics reset" {
    var metrics = CIFAR10Metrics.init();

    metrics.updateAccuracy(5, 5);
    metrics.updateLoss(2.5);

    try testing.expect(metrics.total == 1);
    try testing.expect(metrics.loss == 2.5);

    metrics.reset();

    try testing.expect(metrics.total == 0);
    try testing.expect(metrics.loss == 0.0);
}

test "cifar10_train: sgd optimizer init" {
    const opt = SGDOptimizer.init(0.01, 0.0001);

    try testing.expect(opt.learning_rate == 0.01);
    try testing.expect(opt.weight_decay == 0.0001);
}

test "cifar10_train: sgd optimizer step" {
    var opt = SGDOptimizer.init(0.1, 0.0); // No weight decay

    var params = [_]f32{ 1.0, 2.0, 3.0 };
    var grads = [_]f32{ 0.5, -0.5, 0.25 };

    opt.step(&params, &grads);

    // Expected: new_param = old_param - lr * grad
    try testing.expectApproxEqAbs(params[0], 1.0 - 0.1 * 0.5, 0.001); // 0.95
    try testing.expectApproxEqAbs(params[1], 2.0 - 0.1 * (-0.5), 0.001); // 2.05
    try testing.expectApproxEqAbs(params[2], 3.0 - 0.1 * 0.25, 0.001); // 2.975
}

test "cifar10_train: trainer init" {
    const config = CIFAR10Config.linear();
    var model = try CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    var trainer = try CIFAR10Trainer.init(testing.allocator, &model, config);
    defer trainer.deinit();

    try testing.expect(trainer.model == &model);
    try testing.expect(trainer.epoch == 0);
}

test "cifar10_train: trainer epoch counter" {
    const config = CIFAR10Config.linear();
    var model = try CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    var trainer = try CIFAR10Trainer.init(testing.allocator, &model, config);
    defer trainer.deinit();

    try testing.expect(trainer.epoch == 0);

    // Create minimal dataset
    var dataset = CIFAR10Dataset.init(testing.allocator);
    defer dataset.deinit();
    const img: CIFAR10Image = undefined;
    try dataset.images.append(dataset.allocator, img);

    // Train one epoch (will fail but should increment epoch)
    _ = trainer.trainEpoch(&dataset, 1, testing.allocator) catch {};

    try testing.expect(trainer.epoch == 1);
}
