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
