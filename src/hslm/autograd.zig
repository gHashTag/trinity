// @origin(manual) @regen(pending)
// HSLM — Autograd Engine
// Compute graph with reverse-mode automatic differentiation
// STE (Straight-Through Estimator) for ternary quantization gradients
// Generated API from specs/tri/hslm_autograd.tri

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

/// Default label smoothing parameter: prevents mode collapse by distributing
/// 10% of probability mass uniformly across vocabulary
pub const DEFAULT_LABEL_SMOOTHING: f32 = 0.1;

/// Configurable label smoothing (thread-local, set by trainer)
pub var label_smoothing: f32 = DEFAULT_LABEL_SMOOTHING;

/// Forward cross-entropy with label smoothing:
/// smoothed = (1-ε) × one_hot(target) + ε/V
/// loss = -sum(smoothed × log_softmax(logits))
pub fn forwardCrossEntropy(logits: *const Tensor, targets: []const u16) f32 {
    const batch = logits.rows;
    const vocab = logits.cols;
    const eps = label_smoothing;
    const vocab_f: f64 = @floatFromInt(vocab);
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

        const log_sum_exp: f64 = @log(sum_exp) + @as(f64, max_val);

        // Label smoothing: loss = (1-ε) × CE(target) + ε × uniform_CE
        // CE(target) = log_sum_exp - logits[target]
        const ce_target: f64 = log_sum_exp - @as(f64, row[@as(usize, target)]);
        // uniform_CE = log_sum_exp - mean(logits) = log_sum_exp - sum(logits)/V
        var sum_logits: f64 = 0.0;
        for (row) |v| sum_logits += @as(f64, v);
        const uniform_ce: f64 = log_sum_exp - sum_logits / vocab_f;

        total_loss += (1.0 - eps) * ce_target + eps * uniform_ce;
    }

    return @floatCast(total_loss / @as(f64, @floatFromInt(batch)));
}

/// Backward cross-entropy with label smoothing:
/// dL/d(logits) = softmax(logits) - smoothed_target
/// where smoothed_target = (1-ε) × one_hot(target) + ε/V
pub fn backwardCrossEntropy(logits: *Tensor, targets: []const u16) void {
    const batch = logits.rows;
    const vocab = logits.cols;
    const batch_f: f32 = @floatFromInt(batch);
    const eps = label_smoothing;
    const eps_per_v: f32 = eps / @as(f32, @floatFromInt(vocab));

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
            // Subtract smoothed target: (1-ε)×one_hot + ε/V
            const target_val: f32 = if (i == target) (1.0 - eps) + eps_per_v else eps_per_v;
            grad_row[i] -= target_val;
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

/// RMS normalization backward
/// Given: grad_output (∂L/∂normalized), normalized (x/rms), rms_scale
/// Compute: grad_input (∂L/∂x)
/// ∂L/∂x_i = (1/rms) * (∂L/∂y_i - y_i * mean(∂L/∂y * y))
pub fn rmsNormBackward(grad_output: []const f32, normalized: []const f32, rms_scale: f32, grad_input: []f32) void {
    const d = grad_output.len;
    // Compute dot product: sum(grad_output * normalized) / d
    var dot: f64 = 0.0;
    for (0..d) |i| {
        dot += @as(f64, grad_output[i]) * @as(f64, normalized[i]);
    }
    const mean_dot: f32 = @floatCast(dot / @as(f64, @floatFromInt(d)));
    const inv_rms = 1.0 / rms_scale;
    for (0..d) |i| {
        grad_input[i] = inv_rms * (grad_output[i] - normalized[i] * mean_dot);
    }
}

/// AdamW step for a slice of parameters (for per-layer stepping)
pub fn adamwStepSlice(
    opt: *AdamW,
    params: []f32,
    grads: []const f32,
    offset: usize,
) void {
    // Use the optimizer's current t (must call beginStep first)
    const t_f: f32 = @floatFromInt(opt.t);
    const bias_correction1 = 1.0 - std.math.pow(f32, opt.beta1, t_f);
    const bias_correction2 = 1.0 - std.math.pow(f32, opt.beta2, t_f);

    const n = @min(params.len, grads.len);
    for (0..n) |i| {
        const mi = offset + i;
        if (mi >= opt.m.len) break;
        const g = grads[i];
        opt.m[mi] = opt.beta1 * opt.m[mi] + (1.0 - opt.beta1) * g;
        opt.v[mi] = opt.beta2 * opt.v[mi] + (1.0 - opt.beta2) * g * g;
        const m_hat = opt.m[mi] / bias_correction1;
        const v_hat = opt.v[mi] / bias_correction2;
        params[i] -= opt.lr * (m_hat / (@sqrt(v_hat) + opt.epsilon) + opt.weight_decay * params[i]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LAMB OPTIMIZER — Layer-wise Adaptive Moments for Batch training
// Trust ratio φ = ‖w‖ / ‖adam_step‖ stabilizes ternary weight updates
// For ternary weights {-1,0,+1}: ‖w‖ = √N_nonzero = const after STE
// Reference: https://arxiv.org/abs/1904.00962
// ═══════════════════════════════════════════════════════════════════════════════

pub const Lamb = struct {
    m: []f32, // First moment
    v: []f32, // Second moment
    t: u32, // Timestep
    lr: f32,
    beta1: f32,
    beta2: f32,
    epsilon: f32,
    weight_decay: f32,
    clamp_value: f32, // Max trust ratio (prevents explosion)
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
            .epsilon = 1e-6, // LAMB uses 1e-6 (not 1e-8 like AdamW)
            .weight_decay = constants.WEIGHT_DECAY,
            .clamp_value = 10.0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.m);
        self.allocator.free(self.v);
    }
};

/// L2 norm of a float slice
fn l2norm(data: []const f32) f32 {
    var sum: f64 = 0.0;
    for (data) |x| {
        sum += @as(f64, x) * @as(f64, x);
    }
    return @floatCast(@sqrt(sum));
}

/// LAMB step for a layer slice — computes trust ratio per-layer
/// This is the core difference from AdamW: per-layer scaling via φ = ‖w‖/‖update‖
pub fn lambStepSlice(
    opt: *Lamb,
    params: []f32,
    grads: []const f32,
    offset: usize,
) void {
    const t_f: f32 = @floatFromInt(opt.t);
    const bias_correction1 = 1.0 - std.math.pow(f32, opt.beta1, t_f);
    const bias_correction2 = 1.0 - std.math.pow(f32, opt.beta2, t_f);

    const n = @min(params.len, grads.len);

    // 1. Update moments + compute adam update per element
    // We need the full update vector to compute its norm, so two passes
    var update_norm_sq: f64 = 0.0;
    for (0..n) |i| {
        const mi = offset + i;
        if (mi >= opt.m.len) break;
        const g = grads[i];
        opt.m[mi] = opt.beta1 * opt.m[mi] + (1.0 - opt.beta1) * g;
        opt.v[mi] = opt.beta2 * opt.v[mi] + (1.0 - opt.beta2) * g * g;
        const m_hat = opt.m[mi] / bias_correction1;
        const v_hat = opt.v[mi] / bias_correction2;
        // Adam step + decoupled weight decay
        const update_i = m_hat / (@sqrt(v_hat) + opt.epsilon) + opt.weight_decay * params[i];
        update_norm_sq += @as(f64, update_i) * @as(f64, update_i);
    }

    // 2. Trust ratio: φ = clamp(‖w‖ / ‖update‖, 0, clamp_value)
    const w_norm = l2norm(params[0..n]);
    const update_norm: f32 = @floatCast(@sqrt(update_norm_sq));
    const trust_ratio = if (w_norm == 0.0 or update_norm == 0.0)
        1.0
    else
        @min(w_norm / update_norm, opt.clamp_value);

    // 3. Apply update with trust ratio scaling
    for (0..n) |i| {
        const mi = offset + i;
        if (mi >= opt.m.len) break;
        const m_hat = opt.m[mi] / bias_correction1;
        const v_hat = opt.v[mi] / bias_correction2;
        const update_i = m_hat / (@sqrt(v_hat) + opt.epsilon) + opt.weight_decay * params[i];
        params[i] -= opt.lr * trust_ratio * update_i;
    }
}

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

/// Sacred two-phase LR schedule with warmup:
/// Phase 0: Linear warmup 0 → base_lr over warmup_steps
/// Phase 1: φ-cosine decay base_lr → 10% of base_lr (first 50% of decay)
/// Phase 2: Cosine cooldown 10% → lr_min (last 50% of decay)
/// lr_min = lr_cooldown / φ² (always below cooldown)
pub fn sacredLrSchedule(step: u32, warmup_steps: u32, total_steps: u32, base_lr: f32, min_lr: f32) f32 {
    // Phase 0: Linear warmup
    if (warmup_steps > 0 and step < warmup_steps) {
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }

    const PHI: f64 = 1.6180339887498948482;
    const lr_max: f64 = @as(f64, base_lr);
    const lr_cooldown: f64 = lr_max * 0.1; // 10% of peak
    const lr_min: f64 = @as(f64, min_lr); // Configurable minimum LR

    const decay_steps = total_steps - warmup_steps;
    if (decay_steps == 0) return base_lr;
    const progress = @as(f64, @floatFromInt(step - warmup_steps)) /
        @as(f64, @floatFromInt(decay_steps));

    if (progress <= 0.5) {
        // Phase 1: φ-cosine decay from lr_max → lr_cooldown
        const p1 = progress / 0.5;
        const phi_p1 = std.math.pow(f64, p1, 1.0 / PHI);
        const cosine = (1.0 + @cos(std.math.pi * phi_p1)) / 2.0;
        return @floatCast(lr_cooldown + (lr_max - lr_cooldown) * cosine);
    } else {
        // Phase 2: Cosine cooldown from lr_cooldown → lr_min
        const p2 = (progress - 0.5) / 0.5;
        const cosine = (1.0 + @cos(std.math.pi * p2)) / 2.0;
        return @floatCast(lr_min + (lr_cooldown - lr_min) * cosine);
    }
}

/// Cosine annealing with warm restarts (SGDR / Loshchilov & Hutter 2016)
/// Each restart period: cosine decay from base_lr → lr_min, then snap back
/// T_i = restart_period × mult^i (period grows each restart)
pub fn cosineRestartsLrSchedule(
    step: u32,
    warmup_steps: u32,
    total_steps: u32,
    base_lr: f32,
    min_lr: f32,
    restart_period: u32,
    restart_mult: f32,
) f32 {
    // Phase 0: Linear warmup
    if (warmup_steps > 0 and step < warmup_steps) {
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }

    _ = total_steps; // not used, restarts are periodic

    const decay_step = step - warmup_steps;
    var period: f32 = @floatFromInt(restart_period);
    var elapsed: f32 = @floatFromInt(decay_step);

    // Find which restart cycle we're in
    while (elapsed >= period and period > 1e-6) {
        elapsed -= period;
        period *= restart_mult;
    }

    // Progress within current cycle [0, 1)
    const progress = elapsed / period;
    const cosine = (1.0 + @cos(std.math.pi * progress)) / 2.0;
    return min_lr + (base_lr - min_lr) * cosine;
}

/// WSD (Warmup-Stable-Decay) schedule — MiniCPM-style
/// Phase 0: Linear warmup 0 → base_lr over warmup_steps
/// Phase 1: Stable at base_lr for stable_ratio of decay steps
/// Phase 2: Cosine decay base_lr → min_lr for remaining steps
pub fn wsdLrSchedule(step: u32, warmup_steps: u32, total_steps: u32, base_lr: f32, min_lr: f32, stable_ratio: f32) f32 {
    if (warmup_steps > 0 and step < warmup_steps) {
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }
    const decay_steps = total_steps - warmup_steps;
    if (decay_steps == 0) return base_lr;
    const stable_steps: u32 = @intFromFloat(@as(f32, @floatFromInt(decay_steps)) * stable_ratio);
    const elapsed = step - warmup_steps;
    if (elapsed < stable_steps) return base_lr;
    const decay_remaining = decay_steps - stable_steps;
    if (decay_remaining == 0) return base_lr;
    const progress = @as(f32, @floatFromInt(elapsed - stable_steps)) / @as(f32, @floatFromInt(decay_remaining));
    const cosine = (1.0 + @cos(std.math.pi * progress)) / 2.0;
    return min_lr + (base_lr - min_lr) * cosine;
}

/// D2Z (Decay-to-Zero) schedule — linear decay from peak to 0
/// Phase 0: Linear warmup 0 → base_lr over warmup_steps
/// Phase 1: Linear decay base_lr → 0 over remaining steps
pub fn d2zLrSchedule(step: u32, warmup_steps: u32, total_steps: u32, base_lr: f32) f32 {
    if (warmup_steps > 0 and step < warmup_steps) {
        return base_lr * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));
    }
    const decay_steps = total_steps - warmup_steps;
    if (decay_steps == 0) return base_lr;
    const progress = @as(f32, @floatFromInt(step - warmup_steps)) / @as(f32, @floatFromInt(decay_steps));
    return base_lr * (1.0 - progress);
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
    // With label smoothing ε=0.1: min loss ≈ ε × uniform_ce ≈ 0.1 × log(V) ≈ 0.66
    // Full loss ≈ 0.9 × ~0 + 0.1 × ~10 ≈ 1.0 for extreme logits
    try std.testing.expect(loss < 1.5); // Higher bound due to label smoothing
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

test "lamb step — trust ratio scaling" {
    const allocator = std.testing.allocator;
    var opt = try Lamb.init(allocator, 4, 0.001);
    defer opt.deinit();

    var params = [_]f32{ 1.0, -1.0, 0.5, -0.5 };
    const grads = [_]f32{ 0.1, -0.1, 0.05, -0.05 };

    const original_0 = params[0];
    opt.t = 1;
    lambStepSlice(&opt, &params, &grads, 0);

    // Params should have changed
    try std.testing.expect(params[0] != original_0);
    // Trust ratio should be finite (not NaN)
    try std.testing.expect(!std.math.isNan(params[0]));
    try std.testing.expect(!std.math.isNan(params[1]));
}

test "lamb — zero weights give trust ratio 1.0" {
    const allocator = std.testing.allocator;
    var opt = try Lamb.init(allocator, 2, 0.01);
    defer opt.deinit();

    // Zero weights → trust ratio defaults to 1.0 (no explosion)
    var params = [_]f32{ 0.0, 0.0 };
    const grads = [_]f32{ 1.0, 1.0 };

    opt.t = 1;
    lambStepSlice(&opt, &params, &grads, 0);

    // Should update without NaN
    try std.testing.expect(!std.math.isNan(params[0]));
    try std.testing.expect(params[0] != 0.0);
}

test "lamb — trust ratio clamped to max" {
    const allocator = std.testing.allocator;
    var opt = try Lamb.init(allocator, 2, 0.01);
    defer opt.deinit();
    opt.clamp_value = 2.0; // Low clamp for test

    // Large weights, tiny grads → trust ratio would be huge without clamp
    var params = [_]f32{ 100.0, 100.0 };
    const grads = [_]f32{ 1e-6, 1e-6 };

    opt.t = 1;
    lambStepSlice(&opt, &params, &grads, 0);

    // Should not explode — clamped trust ratio prevents huge update
    try std.testing.expect(@abs(params[0] - 100.0) < 1.0);
}

test "l2norm" {
    const data = [_]f32{ 3.0, 4.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), l2norm(&data), 1e-5);

    const zeros = [_]f32{ 0.0, 0.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), l2norm(&zeros), 1e-7);
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

test "sacred lr schedule two-phase BitNet decay" {
    const base_lr: f32 = 3e-4;
    const min_lr: f32 = 1e-6;
    const total: u32 = 1000;
    const warmup: u32 = 100;

    // Warmup: step 0 → 0, step 50 → half, step 100 → peak
    const lr_w0 = sacredLrSchedule(0, warmup, total, base_lr, min_lr);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lr_w0, 1e-9);
    const lr_w50 = sacredLrSchedule(50, warmup, total, base_lr, min_lr);
    try std.testing.expectApproxEqAbs(base_lr * 0.5, lr_w50, 1e-7);
    const lr_peak = sacredLrSchedule(warmup, warmup, total, base_lr, min_lr);
    try std.testing.expectApproxEqAbs(base_lr, lr_peak, 1e-6);

    // Phase boundary: at 50% of decay steps, lr ≈ cooldown (10% of peak)
    const mid_step = warmup + (total - warmup) / 2; // step 550
    const lr_mid = sacredLrSchedule(mid_step, warmup, total, base_lr, min_lr);
    const lr_cooldown: f32 = base_lr * 0.1;
    try std.testing.expectApproxEqAbs(lr_cooldown, lr_mid, lr_cooldown * 0.1);

    // End: lr ≈ lr_min
    const lr_end = sacredLrSchedule(total, warmup, total, base_lr, min_lr);
    try std.testing.expectApproxEqAbs(min_lr, lr_end, min_lr * 0.5);

    // Monotonically decreasing after warmup
    var prev_lr2 = lr_peak;
    for ((warmup + 1)..(total + 1)) |s| {
        const cur_lr = sacredLrSchedule(@intCast(s), warmup, total, base_lr, min_lr);
        try std.testing.expect(cur_lr <= prev_lr2 + 1e-7);
        prev_lr2 = cur_lr;
    }

    // No warmup: step 0 = peak immediately
    const lr_no_warmup = sacredLrSchedule(0, 0, total, base_lr, min_lr);
    try std.testing.expectApproxEqAbs(base_lr, lr_no_warmup, 1e-6);
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
