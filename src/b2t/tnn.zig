// TNN - Ternary Neural Network
// BitNet b1.58 compatible implementation
// Based on arXiv:2402.17764 "The Era of 1-bit LLMs"
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const trit = @import("trit.zig");
const Trit = trit.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY WEIGHT
// ═══════════════════════════════════════════════════════════════════════════════
//
// BitNet b1.58 uses ternary weights {-1, 0, +1}
// This maps directly to balanced ternary trits {N, Z, P}
//
// Benefits:
// - No multiplication needed: just addition/subtraction based on weight
// - 1.58 bits per weight (log2(3) ≈ 1.58)
// - Significant memory and compute savings
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary weight: {-1, 0, +1} maps to {N, Z, P}
pub const TernaryWeight = Trit;

/// Matrix of ternary weights for a layer
pub const TernaryMatrix = struct {
    rows: usize,
    cols: usize,
    weights: []TernaryWeight,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !TernaryMatrix {
        const weights = try allocator.alloc(TernaryWeight, rows * cols);
        @memset(weights, .Z);
        return TernaryMatrix{
            .rows = rows,
            .cols = cols,
            .weights = weights,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TernaryMatrix) void {
        self.allocator.free(self.weights);
    }

    pub fn get(self: *const TernaryMatrix, row: usize, col: usize) TernaryWeight {
        return self.weights[row * self.cols + col];
    }

    pub fn set(self: *TernaryMatrix, row: usize, col: usize, value: TernaryWeight) void {
        self.weights[row * self.cols + col] = value;
    }

    /// Quantize float weights to ternary using absmean quantization
    /// w_ternary = RoundClip(w / (mean(|w|) + eps))
    pub fn fromFloatWeights(allocator: std.mem.Allocator, float_weights: []const f32, rows: usize, cols: usize) !TernaryMatrix {
        var matrix = try init(allocator, rows, cols);

        // Calculate mean absolute value
        var sum: f32 = 0.0;
        for (float_weights) |w| {
            sum += @abs(w);
        }
        const mean_abs = sum / @as(f32, @floatFromInt(float_weights.len));
        const scale = if (mean_abs > 1e-6) mean_abs else 1.0;

        // Quantize to ternary
        for (float_weights, 0..) |w, i| {
            const scaled = w / scale;
            if (scaled > 0.5) {
                matrix.weights[i] = .P; // +1
            } else if (scaled < -0.5) {
                matrix.weights[i] = .N; // -1
            } else {
                matrix.weights[i] = .Z; // 0
            }
        }

        return matrix;
    }

    /// Matrix-vector multiplication: y = W * x
    /// Uses only addition/subtraction (no multiplication!)
    pub fn matmul(self: *const TernaryMatrix, input: []const f32, output: []f32) void {
        std.debug.assert(input.len == self.cols);
        std.debug.assert(output.len == self.rows);

        for (0..self.rows) |i| {
            var sum: f32 = 0.0;
            for (0..self.cols) |j| {
                const w = self.get(i, j);
                switch (w) {
                    .P => sum += input[j], // +1 * x = x
                    .N => sum -= input[j], // -1 * x = -x
                    .Z => {}, // 0 * x = 0
                }
            }
            output[i] = sum;
        }
    }

    /// Count non-zero weights (sparsity metric)
    pub fn countNonZero(self: *const TernaryMatrix) usize {
        var count: usize = 0;
        for (self.weights) |w| {
            if (w != .Z) count += 1;
        }
        return count;
    }

    /// Calculate sparsity ratio
    pub fn sparsity(self: *const TernaryMatrix) f32 {
        const total = self.rows * self.cols;
        const non_zero = self.countNonZero();
        return 1.0 - @as(f32, @floatFromInt(non_zero)) / @as(f32, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// ReLU activation: max(0, x)
pub fn relu(x: f32) f32 {
    return @max(0.0, x);
}

/// Sign activation: returns -1, 0, or +1
pub fn sign(x: f32) f32 {
    if (x > 0.0) return 1.0;
    if (x < 0.0) return -1.0;
    return 0.0;
}

/// Ternary activation: quantize to {-1, 0, +1}
pub fn ternaryActivation(x: f32, threshold: f32) TernaryWeight {
    if (x > threshold) return .P;
    if (x < -threshold) return .N;
    return .Z;
}

/// Apply ReLU to array in-place
pub fn reluInPlace(data: []f32) void {
    for (data) |*x| {
        x.* = relu(x.*);
    }
}

/// Apply sign to array in-place
pub fn signInPlace(data: []f32) void {
    for (data) |*x| {
        x.* = sign(x.*);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY LINEAR LAYER
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary Linear Layer (BitNet b1.58 style)
/// y = W * x + b (where W is ternary, b is float)
pub const TernaryLinear = struct {
    weights: TernaryMatrix,
    bias: []f32,
    input_size: usize,
    output_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input_size: usize, output_size: usize) !TernaryLinear {
        const bias = try allocator.alloc(f32, output_size);
        @memset(bias, 0.0);
        return TernaryLinear{
            .weights = try TernaryMatrix.init(allocator, output_size, input_size),
            .bias = bias,
            .input_size = input_size,
            .output_size = output_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TernaryLinear) void {
        self.weights.deinit();
        self.allocator.free(self.bias);
    }

    /// Forward pass: y = W * x + b
    pub fn forward(self: *const TernaryLinear, input: []const f32, output: []f32) void {
        std.debug.assert(input.len == self.input_size);
        std.debug.assert(output.len == self.output_size);

        // Matrix multiplication (ternary)
        self.weights.matmul(input, output);

        // Add bias
        for (0..self.output_size) |i| {
            output[i] += self.bias[i];
        }
    }

    /// Initialize weights from float array (quantizes to ternary)
    pub fn setWeightsFromFloat(self: *TernaryLinear, float_weights: []const f32) void {
        std.debug.assert(float_weights.len == self.input_size * self.output_size);

        // Calculate mean absolute value for scaling
        var sum: f32 = 0.0;
        for (float_weights) |w| {
            sum += @abs(w);
        }
        const mean_abs = sum / @as(f32, @floatFromInt(float_weights.len));
        const scale = if (mean_abs > 1e-6) mean_abs else 1.0;

        // Quantize
        for (float_weights, 0..) |w, i| {
            const scaled = w / scale;
            if (scaled > 0.5) {
                self.weights.weights[i] = .P;
            } else if (scaled < -0.5) {
                self.weights.weights[i] = .N;
            } else {
                self.weights.weights[i] = .Z;
            }
        }
    }

    /// Set bias from float array
    pub fn setBias(self: *TernaryLinear, bias: []const f32) void {
        std.debug.assert(bias.len == self.output_size);
        @memcpy(self.bias, bias);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY NEURAL NETWORK
// ═══════════════════════════════════════════════════════════════════════════════

/// Simple feedforward TNN with configurable layers
pub const TernaryNetwork = struct {
    layers: std.ArrayList(TernaryLinear),
    allocator: std.mem.Allocator,
    // Intermediate buffers for forward pass
    buffers: std.ArrayList([]f32),

    pub fn init(allocator: std.mem.Allocator) TernaryNetwork {
        return TernaryNetwork{
            .layers = std.ArrayList(TernaryLinear).init(allocator),
            .allocator = allocator,
            .buffers = std.ArrayList([]f32).init(allocator),
        };
    }

    pub fn deinit(self: *TernaryNetwork) void {
        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.deinit();

        for (self.buffers.items) |buf| {
            self.allocator.free(buf);
        }
        self.buffers.deinit();
    }

    /// Add a layer to the network
    pub fn addLayer(self: *TernaryNetwork, input_size: usize, output_size: usize) !void {
        const layer = try TernaryLinear.init(self.allocator, input_size, output_size);
        try self.layers.append(layer);

        // Allocate buffer for this layer's output
        const buffer = try self.allocator.alloc(f32, output_size);
        try self.buffers.append(buffer);
    }

    /// Forward pass through all layers with ReLU activation
    pub fn forward(self: *TernaryNetwork, input: []const f32, output: []f32) void {
        if (self.layers.items.len == 0) return;

        var current_input = input;

        for (self.layers.items, 0..) |*layer, i| {
            const is_last = (i == self.layers.items.len - 1);
            const out_buf = if (is_last) output else self.buffers.items[i];

            layer.forward(current_input, out_buf);

            // Apply ReLU to all but last layer
            if (!is_last) {
                reluInPlace(out_buf);
            }
            current_input = out_buf;
        }
    }

    /// Get total number of parameters
    pub fn paramCount(self: *const TernaryNetwork) usize {
        var count: usize = 0;
        for (self.layers.items) |layer| {
            count += layer.input_size * layer.output_size; // weights
            count += layer.output_size; // bias
        }
        return count;
    }

    /// Get memory usage in bytes (ternary weights use ~1.58 bits each)
    pub fn memoryUsage(self: *const TernaryNetwork) usize {
        var weight_trits: usize = 0;
        var bias_bytes: usize = 0;

        for (self.layers.items) |layer| {
            weight_trits += layer.input_size * layer.output_size;
            bias_bytes += layer.output_size * @sizeOf(f32);
        }

        // Ternary weights: ceil(weight_trits * 1.58 / 8) bytes
        const weight_bytes = (weight_trits * 2 + 7) / 8; // 2 bits per trit (conservative)
        return weight_bytes + bias_bytes;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BACKWARD PASS AND TRAINING
// ═══════════════════════════════════════════════════════════════════════════════

/// Gradient storage for a layer
pub const LayerGradients = struct {
    weight_grads: []f32, // Gradients for weights (float, before quantization)
    bias_grads: []f32, // Gradients for biases
    input_grads: []f32, // Gradients w.r.t. input (for backprop)
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input_size: usize, output_size: usize) !LayerGradients {
        return LayerGradients{
            .weight_grads = try allocator.alloc(f32, input_size * output_size),
            .bias_grads = try allocator.alloc(f32, output_size),
            .input_grads = try allocator.alloc(f32, input_size),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LayerGradients) void {
        self.allocator.free(self.weight_grads);
        self.allocator.free(self.bias_grads);
        self.allocator.free(self.input_grads);
    }

    pub fn zero(self: *LayerGradients) void {
        @memset(self.weight_grads, 0.0);
        @memset(self.bias_grads, 0.0);
        @memset(self.input_grads, 0.0);
    }
};

/// Trainable TNN with backward pass support
pub const TrainableTNN = struct {
    network: TernaryNetwork,
    gradients: std.ArrayList(LayerGradients),
    // Cached activations for backward pass
    activations: std.ArrayList([]f32),
    // Float shadow weights for gradient accumulation
    shadow_weights: std.ArrayList([]f32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TrainableTNN {
        return TrainableTNN{
            .network = TernaryNetwork.init(allocator),
            .gradients = std.ArrayList(LayerGradients).init(allocator),
            .activations = std.ArrayList([]f32).init(allocator),
            .shadow_weights = std.ArrayList([]f32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TrainableTNN) void {
        self.network.deinit();

        for (self.gradients.items) |*grad| {
            grad.deinit();
        }
        self.gradients.deinit();

        for (self.activations.items) |act| {
            self.allocator.free(act);
        }
        self.activations.deinit();

        for (self.shadow_weights.items) |sw| {
            self.allocator.free(sw);
        }
        self.shadow_weights.deinit();
    }

    /// Add a layer with training support
    pub fn addLayer(self: *TrainableTNN, input_size: usize, output_size: usize) !void {
        try self.network.addLayer(input_size, output_size);

        const grads = try LayerGradients.init(self.allocator, input_size, output_size);
        try self.gradients.append(grads);

        const activation = try self.allocator.alloc(f32, output_size);
        try self.activations.append(activation);

        // Shadow weights for gradient descent
        const shadow = try self.allocator.alloc(f32, input_size * output_size);
        @memset(shadow, 0.0);
        try self.shadow_weights.append(shadow);
    }

    /// Forward pass with activation caching
    pub fn forward(self: *TrainableTNN, input: []const f32, output: []f32) void {
        if (self.network.layers.items.len == 0) return;

        var current_input = input;

        for (self.network.layers.items, 0..) |*layer, i| {
            const is_last = (i == self.network.layers.items.len - 1);
            const out_buf = if (is_last) output else self.activations.items[i];

            layer.forward(current_input, out_buf);

            // Apply ReLU to all but last layer
            if (!is_last) {
                reluInPlace(out_buf);
            }
            current_input = out_buf;
        }
    }

    /// Backward pass - compute gradients
    /// output_grad: gradient of loss w.r.t. network output
    /// input: original input to the network
    pub fn backward(self: *TrainableTNN, input: []const f32, output_grad: []const f32) void {
        if (self.network.layers.items.len == 0) return;

        // Zero gradients
        for (self.gradients.items) |*grad| {
            grad.zero();
        }

        var current_grad = output_grad;
        const num_layers = self.network.layers.items.len;

        // Backward through layers (reverse order)
        var layer_idx: usize = num_layers;
        while (layer_idx > 0) {
            layer_idx -= 1;

            const layer = &self.network.layers.items[layer_idx];
            const grads = &self.gradients.items[layer_idx];

            // Get input to this layer
            const layer_input = if (layer_idx == 0) input else self.activations.items[layer_idx - 1];

            // Compute gradients for this layer
            self.backwardLayer(layer, grads, layer_input, current_grad, layer_idx < num_layers - 1);

            // Propagate gradient to previous layer
            current_grad = grads.input_grads;
        }
    }

    fn backwardLayer(
        self: *TrainableTNN,
        layer: *TernaryLinear,
        grads: *LayerGradients,
        input: []const f32,
        output_grad: []const f32,
        apply_relu_grad: bool,
    ) void {
        _ = self;
        const in_size = layer.input_size;
        const out_size = layer.output_size;

        // Apply ReLU gradient if needed
        var grad_buf: [1024]f32 = undefined;
        var effective_grad = output_grad;

        if (apply_relu_grad) {
            for (0..out_size) |i| {
                // ReLU gradient: 1 if activation > 0, else 0
                // We use the bias as a proxy (should use cached pre-activation)
                grad_buf[i] = if (layer.bias[i] > 0) output_grad[i] else 0.0;
            }
            effective_grad = grad_buf[0..out_size];
        }

        // Compute weight gradients: dL/dW = input^T * output_grad
        for (0..out_size) |o| {
            for (0..in_size) |i| {
                grads.weight_grads[o * in_size + i] += input[i] * effective_grad[o];
            }
        }

        // Compute bias gradients: dL/db = output_grad
        for (0..out_size) |o| {
            grads.bias_grads[o] += effective_grad[o];
        }

        // Compute input gradients: dL/dx = W^T * output_grad
        @memset(grads.input_grads, 0.0);
        for (0..out_size) |o| {
            for (0..in_size) |i| {
                const weight_val: f32 = switch (layer.weights.get(o, i)) {
                    .N => -1.0,
                    .Z => 0.0,
                    .P => 1.0,
                };
                grads.input_grads[i] += weight_val * effective_grad[o];
            }
        }
    }

    /// Apply gradients using SGD with ternary quantization
    pub fn applyGradients(self: *TrainableTNN, learning_rate: f32) void {
        for (self.network.layers.items, 0..) |*layer, layer_idx| {
            const grads = &self.gradients.items[layer_idx];
            const shadow = self.shadow_weights.items[layer_idx];

            // Update shadow weights
            for (0..shadow.len) |i| {
                shadow[i] -= learning_rate * grads.weight_grads[i];
            }

            // Quantize shadow weights to ternary
            quantizeToTernary(shadow, layer.weights.weights);

            // Update biases (keep as float)
            for (0..layer.output_size) |i| {
                layer.bias[i] -= learning_rate * grads.bias_grads[i];
            }
        }
    }
};

/// Quantize float weights to ternary {-1, 0, +1}
fn quantizeToTernary(float_weights: []const f32, ternary_weights: []TernaryWeight) void {
    // Calculate mean absolute value for scaling
    var sum: f32 = 0.0;
    for (float_weights) |w| {
        sum += @abs(w);
    }
    const mean_abs = sum / @as(f32, @floatFromInt(float_weights.len));
    const scale = if (mean_abs > 1e-6) mean_abs else 1.0;

    // Quantize
    for (float_weights, 0..) |w, i| {
        const scaled = w / scale;
        if (scaled > 0.5) {
            ternary_weights[i] = .P;
        } else if (scaled < -0.5) {
            ternary_weights[i] = .N;
        } else {
            ternary_weights[i] = .Z;
        }
    }
}

/// Mean Squared Error loss
pub fn mseLoss(predictions: []const f32, targets: []const f32) f32 {
    var sum: f32 = 0.0;
    for (predictions, targets) |p, t| {
        const diff = p - t;
        sum += diff * diff;
    }
    return sum / @as(f32, @floatFromInt(predictions.len));
}

/// MSE loss gradient
pub fn mseLossGrad(predictions: []const f32, targets: []const f32, grad: []f32) void {
    const n = @as(f32, @floatFromInt(predictions.len));
    for (predictions, targets, 0..) |p, t, i| {
        grad[i] = 2.0 * (p - t) / n;
    }
}

/// Cross-entropy loss for classification
pub fn crossEntropyLoss(predictions: []const f32, target_idx: usize) f32 {
    // Apply softmax and compute loss
    var max_val: f32 = predictions[0];
    for (predictions[1..]) |p| {
        if (p > max_val) max_val = p;
    }

    var sum_exp: f32 = 0.0;
    for (predictions) |p| {
        sum_exp += @exp(p - max_val);
    }

    const log_softmax = predictions[target_idx] - max_val - @log(sum_exp);
    return -log_softmax;
}

/// Cross-entropy loss gradient
pub fn crossEntropyLossGrad(predictions: []const f32, target_idx: usize, grad: []f32) void {
    // Softmax
    var max_val: f32 = predictions[0];
    for (predictions[1..]) |p| {
        if (p > max_val) max_val = p;
    }

    var sum_exp: f32 = 0.0;
    for (predictions) |p| {
        sum_exp += @exp(p - max_val);
    }

    // Gradient: softmax(x) - one_hot(target)
    for (predictions, 0..) |p, i| {
        const softmax = @exp(p - max_val) / sum_exp;
        grad[i] = softmax - (if (i == target_idx) @as(f32, 1.0) else @as(f32, 0.0));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZERS
// ═══════════════════════════════════════════════════════════════════════════════

/// SGD Optimizer with momentum
pub const SGDOptimizer = struct {
    learning_rate: f32,
    momentum: f32,
    velocities: std.ArrayList([]f32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, learning_rate: f32, momentum: f32) SGDOptimizer {
        return SGDOptimizer{
            .learning_rate = learning_rate,
            .momentum = momentum,
            .velocities = std.ArrayList([]f32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SGDOptimizer) void {
        for (self.velocities.items) |v| {
            self.allocator.free(v);
        }
        self.velocities.deinit();
    }

    pub fn initForNetwork(self: *SGDOptimizer, network: *TrainableTNN) !void {
        for (network.shadow_weights.items) |sw| {
            const velocity = try self.allocator.alloc(f32, sw.len);
            @memset(velocity, 0.0);
            try self.velocities.append(velocity);
        }
    }

    pub fn step(self: *SGDOptimizer, network: *TrainableTNN) void {
        for (network.network.layers.items, 0..) |*layer, layer_idx| {
            const grads = &network.gradients.items[layer_idx];
            const shadow = network.shadow_weights.items[layer_idx];
            const velocity = self.velocities.items[layer_idx];

            // Update velocity and weights
            for (0..shadow.len) |i| {
                velocity[i] = self.momentum * velocity[i] - self.learning_rate * grads.weight_grads[i];
                shadow[i] += velocity[i];
            }

            // Quantize to ternary
            quantizeToTernary(shadow, layer.weights.weights);

            // Update biases
            for (0..layer.output_size) |i| {
                layer.bias[i] -= self.learning_rate * grads.bias_grads[i];
            }
        }
    }
};

/// Adam Optimizer
pub const AdamOptimizer = struct {
    learning_rate: f32,
    beta1: f32,
    beta2: f32,
    epsilon: f32,
    t: u32, // timestep

    // First moment (mean)
    m_weights: std.ArrayList([]f32),
    m_biases: std.ArrayList([]f32),
    // Second moment (variance)
    v_weights: std.ArrayList([]f32),
    v_biases: std.ArrayList([]f32),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, learning_rate: f32) AdamOptimizer {
        return AdamOptimizer{
            .learning_rate = learning_rate,
            .beta1 = 0.9,
            .beta2 = 0.999,
            .epsilon = 1e-8,
            .t = 0,
            .m_weights = std.ArrayList([]f32).init(allocator),
            .m_biases = std.ArrayList([]f32).init(allocator),
            .v_weights = std.ArrayList([]f32).init(allocator),
            .v_biases = std.ArrayList([]f32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AdamOptimizer) void {
        for (self.m_weights.items) |m| self.allocator.free(m);
        for (self.m_biases.items) |m| self.allocator.free(m);
        for (self.v_weights.items) |v| self.allocator.free(v);
        for (self.v_biases.items) |v| self.allocator.free(v);
        self.m_weights.deinit();
        self.m_biases.deinit();
        self.v_weights.deinit();
        self.v_biases.deinit();
    }

    pub fn initForNetwork(self: *AdamOptimizer, network: *TrainableTNN) !void {
        for (network.network.layers.items) |layer| {
            const weight_size = layer.input_size * layer.output_size;
            const bias_size = layer.output_size;

            const mw = try self.allocator.alloc(f32, weight_size);
            @memset(mw, 0.0);
            try self.m_weights.append(mw);

            const mb = try self.allocator.alloc(f32, bias_size);
            @memset(mb, 0.0);
            try self.m_biases.append(mb);

            const vw = try self.allocator.alloc(f32, weight_size);
            @memset(vw, 0.0);
            try self.v_weights.append(vw);

            const vb = try self.allocator.alloc(f32, bias_size);
            @memset(vb, 0.0);
            try self.v_biases.append(vb);
        }
    }

    pub fn step(self: *AdamOptimizer, network: *TrainableTNN) void {
        self.t += 1;

        // Bias correction
        const bias_correction1 = 1.0 - std.math.pow(f32, self.beta1, @floatFromInt(self.t));
        const bias_correction2 = 1.0 - std.math.pow(f32, self.beta2, @floatFromInt(self.t));

        for (network.network.layers.items, 0..) |*layer, layer_idx| {
            const grads = &network.gradients.items[layer_idx];
            const shadow = network.shadow_weights.items[layer_idx];

            const mw = self.m_weights.items[layer_idx];
            const vw = self.v_weights.items[layer_idx];
            const mb = self.m_biases.items[layer_idx];
            const vb = self.v_biases.items[layer_idx];

            // Update weights
            for (0..shadow.len) |i| {
                const g = grads.weight_grads[i];

                // Update biased first moment
                mw[i] = self.beta1 * mw[i] + (1.0 - self.beta1) * g;
                // Update biased second moment
                vw[i] = self.beta2 * vw[i] + (1.0 - self.beta2) * g * g;

                // Bias-corrected estimates
                const m_hat = mw[i] / bias_correction1;
                const v_hat = vw[i] / bias_correction2;

                // Update shadow weight
                shadow[i] -= self.learning_rate * m_hat / (@sqrt(v_hat) + self.epsilon);
            }

            // Quantize to ternary
            quantizeToTernary(shadow, layer.weights.weights);

            // Update biases
            for (0..layer.output_size) |i| {
                const g = grads.bias_grads[i];

                mb[i] = self.beta1 * mb[i] + (1.0 - self.beta1) * g;
                vb[i] = self.beta2 * vb[i] + (1.0 - self.beta2) * g * g;

                const m_hat = mb[i] / bias_correction1;
                const v_hat = vb[i] / bias_correction2;

                layer.bias[i] -= self.learning_rate * m_hat / (@sqrt(v_hat) + self.epsilon);
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TernaryMatrix init and set" {
    var matrix = try TernaryMatrix.init(std.testing.allocator, 2, 3);
    defer matrix.deinit();

    try std.testing.expectEqual(@as(usize, 2), matrix.rows);
    try std.testing.expectEqual(@as(usize, 3), matrix.cols);

    matrix.set(0, 0, .P);
    matrix.set(0, 1, .N);
    matrix.set(1, 2, .P);

    try std.testing.expectEqual(TernaryWeight.P, matrix.get(0, 0));
    try std.testing.expectEqual(TernaryWeight.N, matrix.get(0, 1));
    try std.testing.expectEqual(TernaryWeight.Z, matrix.get(0, 2));
    try std.testing.expectEqual(TernaryWeight.P, matrix.get(1, 2));
}

test "TernaryMatrix matmul" {
    var matrix = try TernaryMatrix.init(std.testing.allocator, 2, 3);
    defer matrix.deinit();

    // Set weights: [[1, -1, 0], [0, 1, 1]]
    matrix.set(0, 0, .P); // +1
    matrix.set(0, 1, .N); // -1
    matrix.set(0, 2, .Z); // 0
    matrix.set(1, 0, .Z); // 0
    matrix.set(1, 1, .P); // +1
    matrix.set(1, 2, .P); // +1

    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    matrix.matmul(&input, &output);

    // Row 0: 1*1 + (-1)*2 + 0*3 = 1 - 2 = -1
    // Row 1: 0*1 + 1*2 + 1*3 = 2 + 3 = 5
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), output[1], 0.001);
}

test "TernaryMatrix fromFloatWeights" {
    const float_weights = [_]f32{ 0.8, -0.9, 0.1, -0.1, 0.7, -0.6 };
    var matrix = try TernaryMatrix.fromFloatWeights(std.testing.allocator, &float_weights, 2, 3);
    defer matrix.deinit();

    // After quantization: values > 0.5*mean -> P, < -0.5*mean -> N, else Z
    // Mean abs ≈ 0.53, threshold ≈ 0.27
    // 0.8 -> P, -0.9 -> N, 0.1 -> Z, -0.1 -> Z, 0.7 -> P, -0.6 -> N
    try std.testing.expectEqual(TernaryWeight.P, matrix.get(0, 0));
    try std.testing.expectEqual(TernaryWeight.N, matrix.get(0, 1));
}

test "TernaryLinear forward" {
    var layer = try TernaryLinear.init(std.testing.allocator, 3, 2);
    defer layer.deinit();

    // Set weights manually
    layer.weights.set(0, 0, .P);
    layer.weights.set(0, 1, .N);
    layer.weights.set(0, 2, .Z);
    layer.weights.set(1, 0, .Z);
    layer.weights.set(1, 1, .P);
    layer.weights.set(1, 2, .P);

    // Set bias
    layer.bias[0] = 0.5;
    layer.bias[1] = -0.5;

    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [2]f32 = undefined;

    layer.forward(&input, &output);

    // Row 0: 1 - 2 + 0 + 0.5 = -0.5
    // Row 1: 0 + 2 + 3 - 0.5 = 4.5
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), output[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), output[1], 0.001);
}

test "TernaryNetwork XOR" {
    // XOR network: 2 -> 2 -> 1
    var network = TernaryNetwork.init(std.testing.allocator);
    defer network.deinit();

    try network.addLayer(2, 2); // Hidden layer
    try network.addLayer(2, 1); // Output layer

    // Set weights for XOR
    // Hidden layer: detect (x1 AND NOT x2) and (NOT x1 AND x2)
    network.layers.items[0].weights.set(0, 0, .P); // +1
    network.layers.items[0].weights.set(0, 1, .N); // -1
    network.layers.items[0].weights.set(1, 0, .N); // -1
    network.layers.items[0].weights.set(1, 1, .P); // +1
    network.layers.items[0].bias[0] = 0.0;
    network.layers.items[0].bias[1] = 0.0;

    // Output layer: OR of hidden units
    network.layers.items[1].weights.set(0, 0, .P); // +1
    network.layers.items[1].weights.set(0, 1, .P); // +1
    network.layers.items[1].bias[0] = 0.0;

    // Test XOR truth table
    var output: [1]f32 = undefined;

    // 0 XOR 0 = 0
    network.forward(&[_]f32{ 0.0, 0.0 }, &output);
    try std.testing.expect(output[0] <= 0.5);

    // 0 XOR 1 = 1
    network.forward(&[_]f32{ 0.0, 1.0 }, &output);
    try std.testing.expect(output[0] > 0.0);

    // 1 XOR 0 = 1
    network.forward(&[_]f32{ 1.0, 0.0 }, &output);
    try std.testing.expect(output[0] > 0.0);

    // 1 XOR 1 = 0
    network.forward(&[_]f32{ 1.0, 1.0 }, &output);
    try std.testing.expect(output[0] <= 0.5);
}

test "activation functions" {
    try std.testing.expectEqual(@as(f32, 0.0), relu(-1.0));
    try std.testing.expectEqual(@as(f32, 0.0), relu(0.0));
    try std.testing.expectEqual(@as(f32, 5.0), relu(5.0));

    try std.testing.expectEqual(@as(f32, -1.0), sign(-5.0));
    try std.testing.expectEqual(@as(f32, 0.0), sign(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), sign(5.0));

    try std.testing.expectEqual(TernaryWeight.N, ternaryActivation(-1.0, 0.5));
    try std.testing.expectEqual(TernaryWeight.Z, ternaryActivation(0.3, 0.5));
    try std.testing.expectEqual(TernaryWeight.P, ternaryActivation(1.0, 0.5));
}

test "TernaryMatrix sparsity" {
    var matrix = try TernaryMatrix.init(std.testing.allocator, 2, 2);
    defer matrix.deinit();

    // All zeros = 100% sparsity
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), matrix.sparsity(), 0.001);

    // Set one weight
    matrix.set(0, 0, .P);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), matrix.sparsity(), 0.001);

    // Set all weights
    matrix.set(0, 1, .N);
    matrix.set(1, 0, .P);
    matrix.set(1, 1, .N);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), matrix.sparsity(), 0.001);
}
