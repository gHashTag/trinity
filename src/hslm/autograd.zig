// HSLM — Autograd Engine
// Compute graph with reverse-mode automatic differentiation
// STE (Straight-Through Estimator) for ternary quantization gradients
// Generated API from specs/tri/hslm_autograd.vibee

const std = @import("std");
const constants = @import("constants.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VOCAB_SIZE = constants.VOCAB_SIZE;

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const Tensor = struct {
    data: []f32,
    grad: []f32,
    rows: usize,
    cols: usize,
    requires_grad: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize, requires_grad: bool) !Self {
        const total = rows * cols;
        const data = try allocator.alloc(f32, total);
        const grad = try allocator.alloc(f32, total);
        @memset(data, 0.0);
        @memset(grad, 0.0);
        return Self{
            .data = data,
            .grad = grad,
            .rows = rows,
            .cols = cols,
            .requires_grad = requires_grad,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.allocator.free(self.grad);
    }

    pub fn size(self: *const Self) usize {
        return self.rows * self.cols;
    }

    pub fn zeroGrad(self: *Self) void {
        @memset(self.grad, 0.0);
    }

    pub fn get(self: *const Self, r: usize, c: usize) f32 {
        return self.data[r * self.cols + c];
    }

    pub fn set(self: *Self, r: usize, c: usize, val: f32) void {
        self.data[r * self.cols + c] = val;
    }

    pub fn fill(self: *Self, val: f32) void {
        @memset(self.data, val);
    }

    pub fn copyFrom(self: *Self, src: []const f32) void {
        const n = @min(self.data.len, src.len);
        @memcpy(self.data[0..n], src[0..n]);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPERATIONS (Forward + Backward)
// ═══════════════════════════════════════════════════════════════════════════════

/// y = x * W^T + b  (linear layer)
/// Forward: output[i,j] = sum_k(input[i,k] * weight[j,k]) + bias[j]
pub fn forwardLinear(
    input: *const Tensor, // [batch, in_dim]
    weight: *const Tensor, // [out_dim, in_dim]
    bias: *const Tensor, // [1, out_dim]
    output: *Tensor, // [batch, out_dim]
) void {
    const batch = input.rows;
    const in_dim = input.cols;
    const out_dim = weight.rows;

    for (0..batch) |b| {
        for (0..out_dim) |j| {
            var sum: f32 = bias.data[j];
            for (0..in_dim) |k| {
                sum += input.data[b * in_dim + k] * weight.data[j * in_dim + k];
            }
            output.data[b * out_dim + j] = sum;
        }
    }
}

/// Backward for linear: computes gradients for input, weight, and bias
pub fn backwardLinear(
    input: *const Tensor,
    weight: *const Tensor,
    bias: *Tensor,
    output: *const Tensor,
    input_grad: bool,
) void {
    const batch = input.rows;
    const in_dim = input.cols;
    const out_dim = weight.rows;
    const batch_f: f32 = @floatFromInt(batch);

    // dL/dW += dL/dY * X^T
    if (weight.requires_grad) {
        for (0..out_dim) |j| {
            for (0..in_dim) |k| {
                var sum: f32 = 0.0;
                for (0..batch) |b| {
                    sum += output.grad[b * out_dim + j] * input.data[b * in_dim + k];
                }
                @constCast(weight).grad[j * in_dim + k] += sum / batch_f;
            }
        }
    }

    // dL/db += sum_batch(dL/dY)
    if (bias.requires_grad) {
        for (0..out_dim) |j| {
            var sum: f32 = 0.0;
            for (0..batch) |b| {
                sum += output.grad[b * out_dim + j];
            }
            bias.grad[j] += sum / batch_f;
        }
    }

    // dL/dX += dL/dY * W
    if (input_grad) {
        for (0..batch) |b| {
            for (0..in_dim) |k| {
                var sum: f32 = 0.0;
                for (0..out_dim) |j| {
                    sum += output.grad[b * out_dim + j] * weight.data[j * in_dim + k];
                }
                @constCast(input).grad[b * in_dim + k] += sum;
            }
        }
    }
}

/// Forward ReLU: y = max(0, x)
pub fn forwardRelu(input: *const Tensor, output: *Tensor) void {
    for (0..input.data.len) |i| {
        output.data[i] = @max(0.0, input.data[i]);
    }
}

/// Backward ReLU: dL/dx = dL/dy * (x > 0 ? 1 : 0)
pub fn backwardRelu(input: *const Tensor, output: *const Tensor) void {
    for (0..input.data.len) |i| {
        const mask: f32 = if (input.data[i] > 0.0) 1.0 else 0.0;
        @constCast(input).grad[i] += output.grad[i] * mask;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-ENTROPY LOSS
// ═══════════════════════════════════════════════════════════════════════════════

/// Forward cross-entropy: loss = -log(softmax(logits)[target])
/// Returns scalar loss value
pub fn forwardCrossEntropy(logits: *const Tensor, targets: []const u16) f32 {
    const batch = logits.rows;
    const vocab = logits.cols;
    var total_loss: f64 = 0.0;

    for (0..batch) |b| {
        const row = logits.data[b * vocab .. (b + 1) * vocab];
        const target = targets[b];

        // LogSumExp for numerical stability
        var max_val: f32 = row[0];
        for (row[1..]) |v| {
            if (v > max_val) max_val = v;
        }

        var sum_exp: f64 = 0.0;
        for (row) |v| {
            sum_exp += @exp(@as(f64, v - max_val));
        }

        const log_sum_exp = @as(f32, @floatCast(@log(sum_exp))) + max_val;
        const loss = log_sum_exp - row[@as(usize, target)];
        total_loss += loss;
    }

    return @floatCast(total_loss / @as(f64, @floatFromInt(batch)));
}

/// Backward cross-entropy: dL/d(logits) = softmax(logits) - one_hot(target)
pub fn backwardCrossEntropy(logits: *Tensor, targets: []const u16) void {
    const batch = logits.rows;
    const vocab = logits.cols;
    const batch_f: f32 = @floatFromInt(batch);

    for (0..batch) |b| {
        const row = logits.data[b * vocab .. (b + 1) * vocab];
        const grad_row = logits.grad[b * vocab .. (b + 1) * vocab];
        const target = @as(usize, targets[b]);

        // Compute softmax
        var max_val: f32 = row[0];
        for (row[1..]) |v| {
            if (v > max_val) max_val = v;
        }

        var sum_exp: f64 = 0.0;
        for (row, 0..) |v, i| {
            const e: f32 = @floatCast(@exp(@as(f64, v - max_val)));
            grad_row[i] = e;
            sum_exp += e;
        }

        const inv_sum: f32 = @floatCast(1.0 / sum_exp);
        for (0..vocab) |i| {
            grad_row[i] *= inv_sum; // Now softmax probabilities
            grad_row[i] -= if (i == target) @as(f32, 1.0) else @as(f32, 0.0);
            grad_row[i] /= batch_f; // Average over batch
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STE — STRAIGHT-THROUGH ESTIMATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize float weights to ternary {-1, 0, +1} via AbsMean
/// Forward: w_q = RoundClip(w / (mean|w| + eps))
/// Backward (STE): dL/dw = dL/dw_q (pass gradient straight through)
pub fn steQuantize(float_weights: []const f32, ternary_out: []i8) f32 {
    var sum: f64 = 0.0;
    for (float_weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(float_weights.len));
    const scale: f32 = if (mean_abs > 1e-6) @floatCast(mean_abs) else 1.0;

    for (float_weights, 0..) |w, i| {
        if (i >= ternary_out.len) break;
        const scaled = w / scale;
        if (scaled > 0.5) {
            ternary_out[i] = 1;
        } else if (scaled < -0.5) {
            ternary_out[i] = -1;
        } else {
            ternary_out[i] = 0;
        }
    }

    return scale;
}

/// STE backward: gradient passes through quantization unchanged
/// But clips gradient for weights that are far from quantization boundary
pub fn steBackward(float_weights: []const f32, grad_out: []f32, scale: f32) void {
    for (float_weights, 0..) |w, i| {
        if (i >= grad_out.len) break;
        const scaled = @abs(w / scale);
        // Clip gradients for weights far from boundaries
        if (scaled > 1.5) {
            grad_out[i] *= 0.1; // Attenuate for saturated weights
        }
        // Within [-1.5, 1.5] × scale: full gradient passthrough (STE)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAMW OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdamW = struct {
    m: []f32, // First moment
    v: []f32, // Second moment
    t: u32, // Timestep
    lr: f32,
    beta1: f32,
    beta2: f32,
    epsilon: f32,
    weight_decay: f32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, num_params: usize, lr: f32) !Self {
        const m = try allocator.alloc(f32, num_params);
        const v = try allocator.alloc(f32, num_params);
        @memset(m, 0.0);
        @memset(v, 0.0);
        return Self{
            .m = m,
            .v = v,
            .t = 0,
            .lr = lr,
            .beta1 = constants.ADAM_BETA1,
            .beta2 = constants.ADAM_BETA2,
            .epsilon = constants.ADAM_EPSILON,
            .weight_decay = constants.WEIGHT_DECAY,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.m);
        self.allocator.free(self.v);
    }

    /// One optimization step: update params using gradients
    pub fn step(self: *Self, params: []f32, grads: []const f32) void {
        self.t += 1;
        const t_f: f32 = @floatFromInt(self.t);
        const bias_correction1 = 1.0 - std.math.pow(f32, self.beta1, t_f);
        const bias_correction2 = 1.0 - std.math.pow(f32, self.beta2, t_f);

        const n = @min(@min(params.len, grads.len), self.m.len);
        for (0..n) |i| {
            const g = grads[i];

            // Update moments
            self.m[i] = self.beta1 * self.m[i] + (1.0 - self.beta1) * g;
            self.v[i] = self.beta2 * self.v[i] + (1.0 - self.beta2) * g * g;

            // Bias-corrected moments
            const m_hat = self.m[i] / bias_correction1;
            const v_hat = self.v[i] / bias_correction2;

            // AdamW update: param -= lr * (m_hat / (sqrt(v_hat) + eps) + wd * param)
            params[i] -= self.lr * (m_hat / (@sqrt(v_hat) + self.epsilon) + self.weight_decay * params[i]);
        }
    }

    /// Apply gradient clipping before step
    pub fn stepWithClip(self: *Self, params: []f32, grads: []f32, max_norm: f32) void {
        clipGradNorm(grads, max_norm);
        self.step(params, grads);
    }
};

/// Gradient clipping by global norm
pub fn clipGradNorm(grads: []f32, max_norm: f32) void {
    var norm_sq: f64 = 0.0;
    for (grads) |g| {
        norm_sq += @as(f64, g) * @as(f64, g);
    }
    const norm: f32 = @floatCast(@sqrt(norm_sq));
    if (norm > max_norm) {
        const scale = max_norm / norm;
        for (grads) |*g| {
            g.* *= scale;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEARNING RATE SCHEDULE
// ═══════════════════════════════════════════════════════════════════════════════

/// Linear warmup then cosine decay
pub fn lrSchedule(step: u32, warmup_steps: u32, total_steps: u32, base_lr: f32) f32 {
    if (step < warmup_steps) {
        // Linear warmup
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }

    // Cosine decay
    const progress = @as(f32, @floatFromInt(step - warmup_steps)) / @as(f32, @floatFromInt(total_steps - warmup_steps));
    const cosine = (1.0 + @cos(std.math.pi * progress)) / 2.0;
    return base_lr * 0.1 + (base_lr - base_lr * 0.1) * cosine; // Decay to 10% of base
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tensor init/deinit" {
    const allocator = std.testing.allocator;
    var t = try Tensor.init(allocator, 3, 4, true);
    defer t.deinit();

    try std.testing.expect(t.size() == 12);
    try std.testing.expect(t.requires_grad);
    try std.testing.expect(t.data[0] == 0.0);
    try std.testing.expect(t.grad[0] == 0.0);
}

test "forward linear" {
    const allocator = std.testing.allocator;

    // Input: 1×3
    var input = try Tensor.init(allocator, 1, 3, false);
    defer input.deinit();
    input.data[0] = 1.0;
    input.data[1] = 2.0;
    input.data[2] = 3.0;

    // Weight: 2×3 (out_dim=2, in_dim=3)
    var weight = try Tensor.init(allocator, 2, 3, true);
    defer weight.deinit();
    // W = [[1, 0, -1], [0, 1, 0]]
    weight.data[0] = 1.0;
    weight.data[1] = 0.0;
    weight.data[2] = -1.0;
    weight.data[3] = 0.0;
    weight.data[4] = 1.0;
    weight.data[5] = 0.0;

    // Bias: 1×2
    var bias = try Tensor.init(allocator, 1, 2, true);
    defer bias.deinit();
    bias.data[0] = 0.5;
    bias.data[1] = -0.5;

    // Output: 1×2
    var output = try Tensor.init(allocator, 1, 2, false);
    defer output.deinit();

    forwardLinear(&input, &weight, &bias, &output);

    // y[0] = 1*1 + 2*0 + 3*(-1) + 0.5 = -1.5
    // y[1] = 1*0 + 2*1 + 3*0 + (-0.5) = 1.5
    try std.testing.expectApproxEqAbs(-1.5, output.data[0], 1e-5);
    try std.testing.expectApproxEqAbs(1.5, output.data[1], 1e-5);
}

test "forward relu" {
    const allocator = std.testing.allocator;
    var input = try Tensor.init(allocator, 1, 4, false);
    defer input.deinit();
    input.data[0] = -1.0;
    input.data[1] = 0.0;
    input.data[2] = 0.5;
    input.data[3] = 2.0;

    var output = try Tensor.init(allocator, 1, 4, false);
    defer output.deinit();

    forwardRelu(&input, &output);

    try std.testing.expectApproxEqAbs(0.0, output.data[0], 1e-5);
    try std.testing.expectApproxEqAbs(0.0, output.data[1], 1e-5);
    try std.testing.expectApproxEqAbs(0.5, output.data[2], 1e-5);
    try std.testing.expectApproxEqAbs(2.0, output.data[3], 1e-5);
}

test "cross entropy loss uniform" {
    const allocator = std.testing.allocator;
    // Uniform logits → loss ≈ log(VOCAB_SIZE)
    var logits = try Tensor.init(allocator, 1, VOCAB_SIZE, false);
    defer logits.deinit();
    logits.fill(0.0);

    const targets = [_]u16{42};
    const loss = forwardCrossEntropy(&logits, &targets);
    const expected = @log(@as(f32, @floatFromInt(VOCAB_SIZE)));
    try std.testing.expectApproxEqAbs(expected, loss, 0.01);
}

test "cross entropy loss correct prediction low" {
    const allocator = std.testing.allocator;
    var logits = try Tensor.init(allocator, 1, VOCAB_SIZE, false);
    defer logits.deinit();
    logits.fill(0.0);
    logits.data[42] = 10.0; // High confidence on correct class

    const targets = [_]u16{42};
    const loss = forwardCrossEntropy(&logits, &targets);
    try std.testing.expect(loss < 1.0); // Should be low
}

test "cross entropy backward sums near zero" {
    const allocator = std.testing.allocator;
    var logits = try Tensor.init(allocator, 1, 10, false);
    defer logits.deinit();
    for (0..10) |i| {
        logits.data[i] = @as(f32, @floatFromInt(i)) * 0.5;
    }

    const targets = [_]u16{5};
    backwardCrossEntropy(&logits, &targets);

    // Gradient should sum to ~0 (softmax - one_hot)
    var sum: f64 = 0.0;
    for (0..10) |i| {
        sum += logits.grad[i];
    }
    try std.testing.expectApproxEqAbs(0.0, @as(f32, @floatCast(sum)), 1e-5);
}

test "ste quantize" {
    const floats = [_]f32{ 0.8, -0.9, 0.1, 0.0, -0.3, 1.0, -1.0, 0.5 };
    var ternary: [8]i8 = undefined;
    const scale = steQuantize(&floats, &ternary);

    try std.testing.expect(scale > 0.0);
    for (ternary) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}

test "adamw step" {
    const allocator = std.testing.allocator;
    var opt = try AdamW.init(allocator, 4, 0.001);
    defer opt.deinit();

    var params = [_]f32{ 1.0, -1.0, 0.5, -0.5 };
    const grads = [_]f32{ 0.1, -0.1, 0.05, -0.05 };

    const original_0 = params[0];
    opt.step(&params, &grads);

    // Params should have changed
    try std.testing.expect(params[0] != original_0);
    try std.testing.expect(opt.t == 1);
}

test "gradient clipping" {
    var grads = [_]f32{ 3.0, 4.0 }; // norm = 5
    clipGradNorm(&grads, 1.0);

    // After clipping, norm should be <= 1.0
    const norm = @sqrt(grads[0] * grads[0] + grads[1] * grads[1]);
    try std.testing.expectApproxEqAbs(1.0, norm, 1e-5);
}

test "lr schedule warmup and decay" {
    const base_lr: f32 = 3e-4;

    // Step 0: lr should be 0
    try std.testing.expectApproxEqAbs(0.0, lrSchedule(0, 1000, 50000, base_lr), 1e-7);

    // Step 500 (mid warmup): lr should be half base
    try std.testing.expectApproxEqAbs(base_lr * 0.5, lrSchedule(500, 1000, 50000, base_lr), 1e-7);

    // Step 1000 (end warmup): lr should be base
    try std.testing.expectApproxEqAbs(base_lr, lrSchedule(1000, 1000, 50000, base_lr), 1e-6);

    // Step 50000 (end): lr should be 10% of base
    const end_lr = lrSchedule(50000, 1000, 50000, base_lr);
    try std.testing.expect(end_lr < base_lr * 0.2);
    try std.testing.expect(end_lr > 0.0);
}

test "backward linear gradient flow" {
    const allocator = std.testing.allocator;

    var input = try Tensor.init(allocator, 1, 2, true);
    defer input.deinit();
    input.data[0] = 1.0;
    input.data[1] = 2.0;

    var weight = try Tensor.init(allocator, 2, 2, true);
    defer weight.deinit();
    weight.data[0] = 1.0;
    weight.data[1] = 0.0;
    weight.data[2] = 0.0;
    weight.data[3] = 1.0;

    var bias = try Tensor.init(allocator, 1, 2, true);
    defer bias.deinit();

    var output = try Tensor.init(allocator, 1, 2, false);
    defer output.deinit();

    forwardLinear(&input, &weight, &bias, &output);

    // Set output gradient (as if loss told us)
    output.grad[0] = 1.0;
    output.grad[1] = 1.0;

    backwardLinear(&input, &weight, &bias, &output, true);

    // Weight grads should be non-zero
    var any_nonzero = false;
    for (weight.grad) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);

    // Input grads should be non-zero (gradient flows back)
    any_nonzero = false;
    for (input.grad) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);
}
