// CIFAR-10 Model Architecture
// Ternary neural network for image classification
//
// Phase 1: Simplified linear baseline (1.7M params)
// Phase 2+: HSLM backbone with patch embedding
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const CIFAR10Config = struct {
    // Model architecture
    patch_size: usize = 8, // 8×8 patches → 4×4 grid over 32×32
    num_patches: usize = 16, // 4×4 = 16 patches
    embed_dim: usize = 192, // Reduced from 243 for vision (3×64)
    num_blocks: usize = 4, // Reduced from 6 for faster training
    num_heads: usize = 3, // Sacred attention heads
    num_classes: usize = 10, // CIFAR-10 classes

    // Training configuration
    learning_rate: f64 = 0.001, // Adam default
    weight_decay: f64 = 0.0001, // L2 regularization
    dropout: f64 = 0.1, // Dropout rate

    /// Create config for simplified linear model (baseline)
    pub fn linear() CIFAR10Config {
        return .{
            .patch_size = 32, // Full image as single patch
            .num_patches = 1,
            .embed_dim = 512,
            .num_blocks = 0, // No HSLM blocks
            .num_heads = 0,
            .num_classes = 10,
        };
    }

    /// Create config for HSLM backbone model
    pub fn hslm() CIFAR10Config {
        return .{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple linear layer with ternary weights
pub const LinearLayer = struct {
    weights: []f32,
    bias: []f32,
    in_dim: usize,
    out_dim: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, in_dim: usize, out_dim: usize) !Self {
        const weights = try allocator.alloc(f32, in_dim * out_dim);
        errdefer allocator.free(weights);

        const bias = try allocator.alloc(f32, out_dim);
        errdefer allocator.free(bias);

        // Initialize with Xavier/Glorot scaling
        const scale_f32: f32 = @floatCast(std.math.sqrt(2.0 / @as(f64, @floatFromInt(in_dim + out_dim))));
        var rng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.timestamp())));
        const random = rng.random();

        for (weights) |*w| {
            w.* = scale_f32 * (std.Random.float(random, f32) * 2.0 - 1.0);
        }

        @memset(bias, 0.0);

        return .{
            .weights = weights,
            .bias = bias,
            .in_dim = in_dim,
            .out_dim = out_dim,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.weights);
        self.allocator.free(self.bias);
    }

    pub fn forward(self: *const Self, input: []const f32, output: []f32) void {
        // y = xW + b
        for (0..self.out_dim) |j| {
            var sum: f32 = self.bias[j];
            for (0..self.in_dim) |i| {
                sum += input[i] * self.weights[j * self.in_dim + i];
            }
            output[j] = sum;
        }
    }

    pub fn paramCount(self: *const Self) usize {
        return self.in_dim * self.out_dim + self.out_dim;
    }
};

/// ReLU activation
pub inline fn relu(x: f32) f32 {
    return if (x < 0.0) 0.0 else x;
}

/// CIFAR-10 classifier (Phase 1: Linear baseline)
pub const CIFAR10Model = struct {
    layer1: LinearLayer,
    layer2: LinearLayer,
    layer3: LinearLayer,
    config: CIFAR10Config,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: CIFAR10Config) !Self {
        // Input: 3072 (flattened 32×32×3)
        // L1: 3072 → 512
        var layer1 = try LinearLayer.init(allocator, 3072, 512);
        errdefer layer1.deinit();

        // L2: 512 → 256
        var layer2 = try LinearLayer.init(allocator, 512, 256);
        errdefer layer2.deinit();

        // L3: 256 → 10 (class logits)
        var layer3 = try LinearLayer.init(allocator, 256, 10);
        errdefer layer3.deinit();

        return .{
            .layer1 = layer1,
            .layer2 = layer2,
            .layer3 = layer3,
            .config = config,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.layer1.deinit();
        self.layer2.deinit();
        self.layer3.deinit();
    }

    /// Forward pass through model
    pub fn forward(self: *Self, input: []const f32, output: []f32) !void {
        const buffer1 = try self.allocator.alloc(f32, 512);
        defer self.allocator.free(buffer1);

        const buffer2 = try self.allocator.alloc(f32, 256);
        defer self.allocator.free(buffer2);

        // L1: 3072 → 512 + ReLU
        self.layer1.forward(input, buffer1);
        for (buffer1) |*x| x.* = relu(x.*);

        // L2: 512 → 256 + ReLU
        self.layer2.forward(buffer1, buffer2);
        for (buffer2) |*x| x.* = relu(x.*);

        // L3: 256 → 10 (logits, no activation)
        self.layer3.forward(buffer2, output);
    }

    /// Forward with softmax for prediction
    pub fn predict(self: *Self, input: []const f32, probabilities: []f32) !usize {
        // Forward to get logits
        try self.forward(input, probabilities);

        // Apply softmax
        softmax(probabilities);

        // Find argmax
        var max_idx: usize = 0;
        var max_val: f32 = probabilities[0];
        for (1..probabilities.len) |i| {
            if (probabilities[i] > max_val) {
                max_val = probabilities[i];
                max_idx = i;
            }
        }

        return max_idx;
    }

    /// Count total parameters
    pub fn paramCount(self: *const Self) usize {
        return self.layer1.paramCount() +
            self.layer2.paramCount() +
            self.layer3.paramCount();
    }
};

/// Softmax activation (in-place)
pub inline fn softmax(logits: []f32) void {
    // Find max for numerical stability
    var max_logit: f32 = logits[0];
    for (logits[1..]) |l| {
        if (l > max_logit) max_logit = l;
    }

    // Compute exp and sum
    var sum: f32 = 0.0;
    for (logits) |*l| {
        l.* = std.math.exp(l.* - max_logit);
        sum += l.*;
    }

    // Normalize
    for (logits) |*l| {
        l.* /= sum;
    }
}

/// Cross-entropy loss
pub fn crossEntropyLoss(logits: []const f32, target: usize) f32 {
    // Apply softmax (without modifying input)
    var max_logit: f32 = logits[0];
    for (logits[1..]) |l| {
        if (l > max_logit) max_logit = l;
    }

    var sum: f32 = 0.0;
    var exps: [10]f32 = undefined;
    for (logits, 0..) |l, i| {
        exps[i] = std.math.exp(l - max_logit);
        sum += exps[i];
    }

    const log_sum = std.math.log(f32, std.math.e, sum);

    // Loss = -log(softmax[target])
    const loss = -(logits[target] - max_logit) + log_sum;

    return loss;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "cifar10_model: linear layer init" {
    var layer = try LinearLayer.init(testing.allocator, 10, 5);
    defer layer.deinit();

    try testing.expect(layer.in_dim == 10);
    try testing.expect(layer.out_dim == 5);
    try testing.expect(layer.weights.len == 50); // 10×5
    try testing.expect(layer.bias.len == 5);

    // Check weights are initialized (not all zero)
    var non_zero: bool = false;
    for (layer.weights) |w| {
        if (w != 0.0) {
            non_zero = true;
            break;
        }
    }
    try testing.expect(non_zero);
}

test "cifar10_model: linear layer param count" {
    var layer = try LinearLayer.init(testing.allocator, 10, 5);
    defer layer.deinit();

    try testing.expect(layer.paramCount() == 55); // 10×5 + 5 bias
}

test "cifar10_model: linear layer forward" {
    var layer = try LinearLayer.init(testing.allocator, 3, 2);
    defer layer.deinit();

    // Set deterministic weights and bias
    layer.weights[0] = 1.0;
    layer.weights[1] = 0.5;
    layer.weights[2] = 0.25;
    layer.weights[3] = 2.0;
    layer.weights[4] = 1.0;
    layer.weights[5] = 0.5;
    layer.bias[0] = 1.0;
    layer.bias[1] = -1.0;

    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    layer.forward(&input, &output);

    // Expected:
    // y[0] = 1.0*1 + 0.5*2 + 0.25*3 + 1.0 = 1 + 1 + 0.75 + 1 = 3.75
    // y[1] = 2.0*1 + 1.0*2 + 0.5*3 - 1.0 = 2 + 2 + 1.5 - 1 = 4.5
    try testing.expectApproxEqAbs(output[0], 3.75, 0.001);
    try testing.expectApproxEqAbs(output[1], 4.5, 0.001);
}

test "cifar10_model: relu" {
    try testing.expect(relu(-5.0) == 0.0);
    try testing.expect(relu(0.0) == 0.0);
    try testing.expect(relu(5.0) == 5.0);
}

test "cifar10_model: softmax" {
    var logits = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&logits);

    // All values should be positive and sum to ~1.0
    var sum: f32 = 0.0;
    for (logits) |l| {
        try testing.expect(l > 0.0);
        try testing.expect(l < 1.0);
        sum += l;
    }

    try testing.expectApproxEqAbs(sum, 1.0, 0.001);

    // Higher logit should have higher probability
    try testing.expect(logits[0] < logits[1]);
    try testing.expect(logits[1] < logits[2]);
}

test "cifar10_model: cross entropy loss" {
    // Perfect prediction (high logit at target)
    const logits_perfect = [_]f32{ -10.0, -10.0, 100.0 };
    const loss_perfect = crossEntropyLoss(&logits_perfect, 2);
    try testing.expect(loss_perfect < 0.01); // Near zero loss

    // Wrong prediction (low logit at target)
    const logits_wrong = [_]f32{ 100.0, -10.0, -10.0 };
    const loss_wrong = crossEntropyLoss(&logits_wrong, 2);
    try testing.expect(loss_wrong > 100.0); // High loss
}

test "cifar10_model: cifar10 model init" {
    const config = CIFAR10Config.linear();
    var model = try CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    try testing.expect(model.config.num_classes == 10);

    // Check param count (~1.7M for linear baseline)
    const params = model.paramCount();
    try testing.expect(params > 1_500_000);
    try testing.expect(params < 2_000_000);
}

test "cifar10_model: cifar10 model forward" {
    const config = CIFAR10Config.linear();
    var model = try CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    // Input: flattened 32×32×3 = 3072 values
    const input = try testing.allocator.alloc(f32, 3072);
    defer testing.allocator.free(input);
    @memset(input, 0.5); // All pixels = 0.5

    var output: [10]f32 = undefined;
    try model.forward(input, &output);

    // Output should have 10 class logits
    for (output) |l| {
        try testing.expect(!std.math.isNan(l));
        try testing.expect(!std.math.isInf(l));
    }
}

test "cifar10_model: cifar10 model predict" {
    const config = CIFAR10Config.linear();
    var model = try CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    const input = try testing.allocator.alloc(f32, 3072);
    defer testing.allocator.free(input);
    @memset(input, 0.5);

    var probs: [10]f32 = undefined;
    const prediction = try model.predict(input, &probs);

    try testing.expect(prediction < 10);

    // Probabilities should sum to ~1.0
    var sum: f32 = 0.0;
    for (probs) |p| {
        try testing.expect(p >= 0.0);
        try testing.expect(p <= 1.0);
        sum += p;
    }
    try testing.expectApproxEqAbs(sum, 1.0, 0.001);
}
