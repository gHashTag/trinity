// ═══════════════════════════════════════════════════════════════════════════════
// ML PATTERNS - Machine Learning & Statistics (MLS: 6%)
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Match ML/Stats patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    // Pattern: predict* -> ML prediction
    if (std.mem.startsWith(u8, b.name, "predict")) {
        try builder.writeFmt("pub fn {s}(logits: []const f32) u32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Argmax prediction: return index of max logit");
        try builder.writeLine("var max_idx: u32 = 0;");
        try builder.writeLine("var max_val: f32 = logits[0];");
        try builder.writeLine("for (logits[1..], 1..) |v, i| {");
        builder.incIndent();
        try builder.writeLine("if (v > max_val) { max_val = v; max_idx = @as(u32, @intCast(i)); }");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return max_idx;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: train* -> training operation
    if (std.mem.startsWith(u8, b.name, "train")) {
        try builder.writeFmt("pub fn {s}(weights: []f32, grad: []const f32, learning_rate: f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// SGD update: w -= lr * gradient");
        try builder.writeLine("for (weights, 0..) |*w, i| {");
        builder.incIndent();
        try builder.writeLine("w.* -= learning_rate * grad[i];");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: evaluate* -> evaluation (MSE calculation)
    if (std.mem.startsWith(u8, b.name, "evaluate")) {
        try builder.writeFmt("pub fn {s}(model: anytype, data: anytype) EvalResult {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate MSE (Mean Squared Error) on dataset");
        try builder.writeLine("var total_error: f32 = 0.0;");
        try builder.writeLine("var count: usize = 0;");
        try builder.writeLine("for (data.inputs, data.targets) |input, target| {");
        builder.incIndent();
        try builder.writeLine("const pred = model.forward(input);");
        try builder.writeLine("const diff = pred - target;");
        try builder.writeLine("total_error += diff * diff;");
        try builder.writeLine("count += 1;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return EvalResult{ .mse = total_error / @as(f32, @floatFromInt(count)), .samples = count };");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: learn* -> learning (Hebbian update)
    if (std.mem.startsWith(u8, b.name, "learn")) {
        try builder.writeFmt("pub fn {s}(model: anytype, sample: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Hebbian learning: update weights based on prediction error");
        try builder.writeLine("const prediction = model.forward(sample.input);");
        try builder.writeLine("const error = sample.target - prediction;");
        try builder.writeLine("// Update weights with learning rate 0.01");
        try builder.writeLine("model.updateWeights(sample.input, error * 0.01);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: adapt* -> adaptation (moving average)
    if (std.mem.startsWith(u8, b.name, "adapt")) {
        try builder.writeFmt("pub fn {s}(model: anytype, new_data: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Adapt model using exponential moving average");
        try builder.writeLine("const alpha = 0.1;  // Smoothing factor");
        try builder.writeLine("const new_mean = computeMean(new_data);");
        try builder.writeLine("model.mean = alpha * new_mean + (1 - alpha) * model.mean;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: fit* -> fitting (gradient descent loop)
    if (std.mem.startsWith(u8, b.name, "fit")) {
        try builder.writeFmt("pub fn {s}(model: anytype, x: anytype, y: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Train model using gradient descent");
        try builder.writeLine("const epochs = 100;");
        try builder.writeLine("const lr = 0.01;  // Learning rate");
        try builder.writeLine("var epoch: usize = 0;");
        try builder.writeLine("while (epoch < epochs) : (epoch += 1) {");
        builder.incIndent();
        try builder.writeLine("for (x, y) |input, target| {");
        builder.incIndent();
        try builder.writeLine("const pred = model.forward(input);");
        try builder.writeLine("const grad = 2 * (pred - target);");
        try builder.writeLine("model.backward(grad, lr);");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: infer* -> inference
    if (std.mem.startsWith(u8, b.name, "infer")) {
        try builder.writeFmt("pub fn {s}(model: anytype, input: anytype) @TypeOf(input) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Run inference");
        try builder.writeLine("_ = model;");
        try builder.writeLine("return input;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: calibrate* -> calibration
    if (std.mem.startsWith(u8, b.name, "calibrate")) {
        try builder.writeFmt("pub fn {s}(model: anytype, data: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calibrate model parameters");
        try builder.writeLine("_ = model; _ = data;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: accuracy* -> accuracy measurement
    if (std.mem.startsWith(u8, b.name, "accuracy")) {
        try builder.writeFmt("pub fn {s}(predictions: []const u32, labels: []const u32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Calculate accuracy: correct / total");
        try builder.writeLine("var correct: u32 = 0;");
        try builder.writeLine("for (predictions, labels) |p, l| { if (p == l) correct += 1; }");
        try builder.writeLine("return @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(predictions.len));");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: loss* -> cross-entropy loss
    if (std.mem.startsWith(u8, b.name, "loss")) {
        try builder.writeFmt("pub fn {s}(predictions: []const f32, targets: []const f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Cross-entropy loss: -sum(target * log(pred))");
        try builder.writeLine("var total: f32 = 0.0;");
        try builder.writeLine("const epsilon: f32 = 1e-7;");
        try builder.writeLine("for (predictions, targets) |p, t| {");
        builder.incIndent();
        try builder.writeLine("const clamped = if (p < epsilon) epsilon else if (p > 1.0 - epsilon) 1.0 - epsilon else p;");
        try builder.writeLine("total -= t * @log(clamped);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return total;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: gradient* -> gradient computation
    if (std.mem.startsWith(u8, b.name, "gradient")) {
        try builder.writeFmt("pub fn {s}(loss_fn: *const fn (f32) f32, param: f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Finite difference gradient: (f(x+h) - f(x-h)) / 2h");
        try builder.writeLine("const h: f32 = 1e-5;");
        try builder.writeLine("const f_plus = loss_fn(param + h);");
        try builder.writeLine("const f_minus = loss_fn(param - h);");
        try builder.writeLine("return (f_plus - f_minus) / (2.0 * h);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: backward* -> backward pass
    if (std.mem.startsWith(u8, b.name, "backward")) {
        try builder.writeFmt("pub fn {s}(grad_output: []const f32, weights: []const f32, grad_input: []f32, grad_weights: []f32, in_dim: u32, out_dim: u32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Backward pass: compute gradients w.r.t. input and weights");
        try builder.writeLine("// grad_input = grad_output @ weights^T");
        try builder.writeLine("for (0..in_dim) |i| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = 0;");
        try builder.writeLine("for (0..out_dim) |o| { sum += grad_output[o] * weights[o * in_dim + i]; }");
        try builder.writeLine("grad_input[i] = sum;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("// grad_weights = input^T @ grad_output (outer product)");
        try builder.writeLine("for (0..out_dim) |o| {");
        builder.incIndent();
        try builder.writeLine("for (0..in_dim) |i| { grad_weights[o * in_dim + i] = grad_output[o]; }");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: forward* -> forward pass
    if (std.mem.startsWith(u8, b.name, "forward")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, weights: []const f32, bias: []const f32, output: []f32, in_dim: u32, out_dim: u32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Dense layer forward pass: output = activation(input @ weights + bias)");
        try builder.writeLine("for (0..out_dim) |o| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = bias[o];");
        try builder.writeLine("for (0..in_dim) |i| { sum += input[i] * weights[o * in_dim + i]; }");
        try builder.writeLine("// ReLU activation");
        try builder.writeLine("output[o] = if (sum > 0) sum else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: weight* -> weight operations
    if (std.mem.startsWith(u8, b.name, "weight")) {
        try builder.writeFmt("pub fn {s}(all_weights: []const f32, layer_idx: usize, layer_size: usize) []const f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Slice weights for a specific layer");
        try builder.writeLine("const start = layer_idx * layer_size;");
        try builder.writeLine("return all_weights[start..start + layer_size];");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: evolve* -> evolution
    if (std.mem.startsWith(u8, b.name, "evolve")) {
        try builder.writeFmt("pub fn {s}(population: anytype) @TypeOf(population) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Evolve population");
        try builder.writeLine("return population;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: mutate* -> mutation
    if (std.mem.startsWith(u8, b.name, "mutate")) {
        try builder.writeFmt("pub fn {s}(genome: anytype, rate: f32) @TypeOf(genome) {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Mutate with given rate");
        try builder.writeLine("_ = rate;");
        try builder.writeLine("return genome;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: llm* -> LLM operations
    if (std.mem.startsWith(u8, b.name, "llm")) {
        try builder.writeFmt("pub fn {s}(model: anytype, tokens: []const u32, max_tokens: u32, output: []u32) usize {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Autoregressive token generation");
        try builder.writeLine("_ = model;");
        try builder.writeLine("var generated: usize = 0;");
        try builder.writeLine("for (0..@min(max_tokens, output.len)) |_| {");
        builder.incIndent();
        try builder.writeLine("// DEFERRED (v12): sample from model distribution");
        try builder.writeLine("output[generated] = 0; // placeholder token");
        try builder.writeLine("generated += 1;");
        try builder.writeLine("// if (output[generated - 1] == EOS_TOKEN) break;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return generated;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: layer_norm* -> layer normalization, layer* -> dense layer
    if (std.mem.startsWith(u8, b.name, "layer_norm")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, output: []f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Layer normalization: (x - mean) / sqrt(var + eps)");
        try builder.writeLine("const n = input.len;");
        try builder.writeLine("var mean: f32 = 0.0;");
        try builder.writeLine("for (input) |v| { mean += v; }");
        try builder.writeLine("mean /= @as(f32, @floatFromInt(n));");
        try builder.writeLine("var variance: f32 = 0.0;");
        try builder.writeLine("for (input) |v| { const d = v - mean; variance += d * d; }");
        try builder.writeLine("variance /= @as(f32, @floatFromInt(n));");
        try builder.writeLine("const inv_std = 1.0 / @sqrt(variance + 1e-5);");
        try builder.writeLine("for (input, 0..) |v, i| { output[i] = (v - mean) * inv_std; }");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    } else if (std.mem.startsWith(u8, b.name, "layer")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, weights: []const f32, bias: []const f32, output: []f32, in_dim: u32, out_dim: u32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Dense layer: output = input @ weights + bias");
        try builder.writeLine("for (0..out_dim) |o| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = bias[o];");
        try builder.writeLine("for (0..in_dim) |i| { sum += input[i] * weights[o * in_dim + i]; }");
        try builder.writeLine("output[o] = sum;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: softmax* -> numerically stable softmax
    if (std.mem.startsWith(u8, b.name, "softmax")) {
        try builder.writeFmt("pub fn {s}(logits: []const f32, output: []f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Numerically stable softmax: exp(x - max) / sum(exp(x - max))");
        try builder.writeLine("var max_val: f32 = logits[0];");
        try builder.writeLine("for (logits[1..]) |v| { if (v > max_val) max_val = v; }");
        try builder.writeLine("var sum: f32 = 0.0;");
        try builder.writeLine("for (logits, 0..) |v, i| {");
        builder.incIndent();
        try builder.writeLine("output[i] = @exp(v - max_val);");
        try builder.writeLine("sum += output[i];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("for (output) |*o| { o.* /= sum; }");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: relu* -> ReLU activation
    if (std.mem.startsWith(u8, b.name, "relu")) {
        try builder.writeFmt("pub fn {s}(x: f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// ReLU activation: max(0, x)");
        try builder.writeLine("return if (x > 0) x else 0;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: gelu* -> GELU activation
    if (std.mem.startsWith(u8, b.name, "gelu")) {
        try builder.writeFmt("pub fn {s}(x: f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// GELU activation");
        try builder.writeLine("return x * 0.5 * (1.0 + @tanh(0.7978845608 * (x + 0.044715 * x * x * x)));");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: embed* -> embedding table lookup
    if (std.mem.startsWith(u8, b.name, "embed")) {
        try builder.writeFmt("pub fn {s}(token_id: u32, table: []const f32, dim: u32, output: []f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Embedding lookup: table[token_id * dim .. (token_id+1) * dim]");
        try builder.writeLine("const start = token_id * dim;");
        try builder.writeLine("const end = start + dim;");
        try builder.writeLine("@memcpy(output, table[start..end]);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: flash* / attention* -> scaled dot-product attention
    if (std.mem.startsWith(u8, b.name, "flash") or std.mem.startsWith(u8, b.name, "attention")) {
        try builder.writeFmt("pub fn {s}(q: []const f32, k: []const f32, v: []const f32, output: []f32, seq_len: u32, d_k: u32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Scaled dot-product attention: softmax(Q*K^T / sqrt(d_k)) * V");
        try builder.writeLine("const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(d_k)));");
        try builder.writeLine("for (0..seq_len) |i| {");
        builder.incIndent();
        try builder.writeLine("// Compute attention scores for row i");
        try builder.writeLine("var max_score: f32 = -1e9;");
        try builder.writeLine("for (0..seq_len) |j| {");
        builder.incIndent();
        try builder.writeLine("var score: f32 = 0;");
        try builder.writeLine("for (0..d_k) |dk| { score += q[i * d_k + dk] * k[j * d_k + dk]; }");
        try builder.writeLine("score *= scale;");
        try builder.writeLine("if (score > max_score) max_score = score;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("// Softmax + weighted sum");
        try builder.writeLine("var sum_exp: f32 = 0;");
        try builder.writeLine("for (0..d_k) |dk| { output[i * d_k + dk] = 0; }");
        try builder.writeLine("for (0..seq_len) |j| {");
        builder.incIndent();
        try builder.writeLine("var score: f32 = 0;");
        try builder.writeLine("for (0..d_k) |dk| { score += q[i * d_k + dk] * k[j * d_k + dk]; }");
        try builder.writeLine("const w = @exp(score * scale - max_score);");
        try builder.writeLine("sum_exp += w;");
        try builder.writeLine("for (0..d_k) |dk| { output[i * d_k + dk] += w * v[j * d_k + dk]; }");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("for (0..d_k) |dk| { output[i * d_k + dk] /= sum_exp; }");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: prune* -> pruning
    if (std.mem.startsWith(u8, b.name, "prune")) {
        try builder.writeFmt("pub fn {s}(weights: []f32, threshold: f32) usize {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Prune weights below threshold, return count of pruned weights");
        try builder.writeLine("var pruned: usize = 0;");
        try builder.writeLine("for (weights) |*w| {");
        builder.incIndent();
        try builder.writeLine("if (@abs(w.*) < threshold) { w.* = 0; pruned += 1; }");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("return pruned;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: online* -> online/streaming update
    if (std.mem.startsWith(u8, b.name, "online")) {
        try builder.writeFmt("pub fn {s}(self: *@This(), sample: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Online update with new sample");
        try builder.writeLine("_ = self; _ = sample;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // V4 NEW PATTERNS (5 new patterns for 76% coverage)
    // ═══════════════════════════════════════════════════════════════════════════════

    // Pattern: optimizer_step — Adam/SGD optimizer step
    if (std.mem.eql(u8, b.name, "optimizer_step")) {
        try builder.writeFmt("pub fn {s}(weights: []f32, gradients: []const f32, m: []f32, v: []f32, t: usize, learning_rate: f32, beta1: f32, beta2: f32, epsilon: f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Adam optimizer step with bias correction");
        try builder.writeLine("// m = β₁·m + (1-β₁)·grad  (first moment)");
        try builder.writeLine("// v = β₂·v + (1-β₂)·grad² (second moment)");
        try builder.writeLine("// m_hat = m / (1-β₁^t), v_hat = v / (1-β₂^t)");
        try builder.writeLine("// w -= lr · m_hat / (sqrt(v_hat) + ε)");
        try builder.writeLine("const one_minus_beta1 = 1.0 - beta1;");
        try builder.writeLine("const one_minus_beta2 = 1.0 - beta2;");
        try builder.writeLine("for (weights, gradients, m, v) |*w, g, *mm, *vv| {");
        builder.incIndent();
        try builder.writeLine("mm.* = beta1 * mm.* + one_minus_beta1 * g;");
        try builder.writeLine("vv.* = beta2 * vv.* + one_minus_beta2 * g * g;");
        try builder.writeLine("const m_hat = mm.* / (1.0 - std.math.pow(f32, beta1, @floatFromInt(t)));");
        try builder.writeLine("const v_hat = vv.* / (1.0 - std.math.pow(f32, beta2, @floatFromInt(t)));");
        try builder.writeLine("w.* -= learning_rate * m_hat / (@sqrt(v_hat) + epsilon);");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: kv_cache — KV cache for autoregressive generation
    if (std.mem.startsWith(u8, b.name, "kv_cache")) {
        try builder.writeFmt("pub fn {s}(k_cache: []f32, v_cache: []f32, new_k: []const f32, new_v: []const f32, pos: usize, num_heads: usize, head_dim: usize) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Update KV cache with new keys and values at position pos");
        try builder.writeLine("// Each head has its own cache segment");
        try builder.writeLine("const cache_per_head = head_dim;");
        try builder.writeLine("for (0..num_heads) |h| {");
        builder.incIndent();
        try builder.writeLine("const h_offset = h * cache_per_head;");
        try builder.writeLine("const pos_offset = pos * cache_per_head;");
        try builder.writeLine("// Cache new_k at position pos");
        try builder.writeLine("for (0..head_dim) |i| {");
        try builder.writeLine("    k_cache[h_offset + pos_offset + i] = new_k[h * head_dim + i];");
        try builder.writeLine("}");
        try builder.writeLine("// Cache new_v at position pos");
        try builder.writeLine("for (0..head_dim) |i| {");
        try builder.writeLine("    v_cache[h_offset + pos_offset + i] = new_v[h * head_dim + i];");
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: rotary_embedding — RoPE position encoding
    if (std.mem.startsWith(u8, b.name, "rotary_embedding")) {
        try builder.writeFmt("pub fn {s}(x: []f32, y: []f32, dim: usize, pos: usize) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Rotary Position Embedding (RoPE)");
        try builder.writeLine("// Apply rotation based on position to x and y");
        try builder.writeLine("// θ = pos^(-2/dim), 2/dim) for i in 0..dim/2");
        try builder.writeLine("for (0..dim / 2) |i| {");
        builder.incIndent();
        try builder.writeLine("const theta = @as(f32, @floatFromInt(pos)) / std.math.pow(f32, @as(f32, @floatFromInt(i)), 2.0 / @as(f32, @floatFromInt(dim / 2)));");
        try builder.writeLine("const cos_theta = @cos(theta);");
        try builder.writeLine("const sin_theta = @sin(theta);");
        try builder.writeLine("// x[i] = x[i] * cos(θ) - x[i + dim/2] * sin(θ)");
        try builder.writeLine("// x[i + dim/2] = x[i] * sin(θ) + x[i + dim/2] * cos(θ)");
        try builder.writeLine("const x_val = x[i];");
        try builder.writeLine("x[i] = x_val * cos_theta - x[i + dim / 2] * sin_theta;");
        try builder.writeLine("x[i + dim / 2] = x_val * sin_theta + x[i + dim / 2] * cos_theta;");
        try builder.writeLine("// Apply same rotation to y");
        try builder.writeLine("const y_val = y[i];");
        try builder.writeLine("y[i] = y_val * cos_theta - y[i + dim / 2] * sin_theta;");
        try builder.writeLine("y[i + dim / 2] = y_val * sin_theta + y[i + dim / 2] * cos_theta;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: rms_norm — Root Mean Square normalization
    if (std.mem.startsWith(u8, b.name, "rms_norm")) {
        try builder.writeFmt("pub fn {s}(input: []const f32, weight: []const f32, output: []f32, epsilon: f32) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// RMSNorm: output = input / sqrt(mean(x²) + ε) * weight");
        try builder.writeLine("var sum_squares: f32 = 0.0;");
        try builder.writeLine("for (input) |v| { sum_squares += v * v; }");
        try builder.writeLine("const rms = @sqrt(sum_squares / @as(f32, @floatFromInt(input.len)) + epsilon);");
        try builder.writeLine("for (input, weight, 0..) |i, w, o| {");
        try builder.writeLine("    o.* = (i / rms) * w.*;");
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: scheduler — Learning rate scheduler
    if (std.mem.startsWith(u8, b.name, "scheduler")) {
        try builder.writeFmt("pub fn {s}(initial_lr: f32, step: usize, warmup_steps: usize, total_steps: usize, min_lr: f32) f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Cosine learning rate scheduler with warmup");
        try builder.writeLine("// lr = min_lr + 0.5 * (1 - cos(π * progress)) * (initial_lr - min_lr)");
        try builder.writeLine("if (step < warmup_steps) {");
        builder.incIndent();
        try builder.writeLine("// Warmup phase: linear increase");
        try builder.writeLine("return min_lr + (initial_lr - min_lr) * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(warmup_steps));");
        builder.decIndent();
        try builder.writeLine("} else {");
        builder.incIndent();
        try builder.writeLine("// Decay phase: cosine annealing");
        try builder.writeLine("const progress = @as(f32, @floatFromInt(step - warmup_step)) / @as(f32, @floatFromInt(total_steps - warmup_steps));");
        try builder.writeLine("return min_lr + 0.5 * (initial_lr - min_lr) * (1.0 - @cos(std.pi * progress));");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
