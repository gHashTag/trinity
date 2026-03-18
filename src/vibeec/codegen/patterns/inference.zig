// ═══════════════════════════════════════════════════════════════════════════════
// INFERENCE PATTERNS - Neural network forward/backward pass operations
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

/// Match inference operation patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    const when_text = b.when;

    // Pattern: forward_pass* -> neural network forward pass
    if (std.mem.startsWith(u8, b.name, "forward_pass") or
        (std.mem.indexOf(u8, when_text, "forward") != null and std.mem.indexOf(u8, when_text, "pass") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, input: []const f32, weights: []const Layer) ![]const f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Forward pass through neural network layers");
        try builder.writeLine("var activations = try allocator.dupe(f32, input);");
        try builder.writeLine("defer allocator.free(activations);");
        try builder.writeLine("");
        try builder.writeLine("for (weights) |layer| {");
        builder.incIndent();
        try builder.writeLine("const next_size = layer.output_size;");
        try builder.writeLine("const next_activations = try allocator.alloc(f32, next_size);");
        try builder.writeLine("errdefer allocator.free(next_activations);");
        try builder.writeLine("");
        try builder.writeLine("// Dense layer: y = activation(Wx + b)");
        try builder.writeLine("for (0..next_size) |j| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = layer.biases[j];");
        try builder.writeLine("for (0..activations.len) |i| {");
        builder.incIndent();
        try builder.writeLine("sum += activations[i] * layer.weights[i * next_size + j];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("next_activations[j] = layer.activation_fn(sum);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("allocator.free(activations);");
        try builder.writeLine("activations = next_activations;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return allocator.dupe(f32, activations);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: backward_pass* -> backpropagation
    if (std.mem.startsWith(u8, b.name, "backward_pass") or
        (std.mem.indexOf(u8, when_text, "backward") != null and std.mem.indexOf(u8, when_text, "pass") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, loss_grad: []const f32, weights: []Layer, cached_inputs: []const []f32) ![][]f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Backward pass: compute gradients via backpropagation");
        try builder.writeLine("// Returns gradients for each layer");
        try builder.writeLine("");
        try builder.writeLine("const num_layers = weights.len;");
        try builder.writeLine("const gradients = try allocator.alloc([]f32, num_layers);");
        try builder.writeLine("errdefer {");
        builder.incIndent();
        try builder.writeLine("for (gradients) |grad| { if (grad.len > 0) allocator.free(grad); }");
        try builder.writeLine("allocator.free(gradients);");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.writeLine("");
        try builder.writeLine("var upstream_grad = loss_grad;");
        try builder.writeLine("");
        try builder.writeLine("// Iterate backwards through layers");
        try builder.writeLine("for (0..num_layers) |layer_idx| {");
        builder.incIndent();
        try builder.writeLine("const i = num_layers - 1 - layer_idx;");
        try builder.writeLine("const layer = &weights[i];");
        try builder.writeLine("const inputs = cached_inputs[i];");
        try builder.writeLine("");
        try builder.writeLine("const grad_size = layer.weights.len;");
        try builder.writeLine("const layer_grad = try allocator.alloc(f32, grad_size);");
        try builder.writeLine("gradients[i] = layer_grad;");
        try builder.writeLine("");
        try builder.writeLine("// Gradient w.r.t. weights: dL/dW = input * dL/doutput");
        try builder.writeLine("for (0..inputs.len) |in_idx| {");
        builder.incIndent();
        try builder.writeLine("for (0..layer.output_size) |out_idx| {");
        builder.incIndent();
        try builder.writeLine("const w_idx = in_idx * layer.output_size + out_idx;");
        try builder.writeLine("layer_grad[w_idx] = inputs[in_idx] * upstream_grad[out_idx];");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Propagate gradient to previous layer");
        try builder.writeLine("// dL/dinput = W^T * dL/doutput");
        try builder.writeLine("if (i > 0) {");
        builder.incIndent();
        try builder.writeLine("const prev_grad = try allocator.alloc(f32, inputs.len);");
        try builder.writeLine("// Matrix transpose multiply");
        try builder.writeLine("for (0..inputs.len) |in_idx| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = 0;");
        try builder.writeLine("for (0..layer.output_size) |out_idx| {");
        builder.incIndent();
        try builder.writeLine("sum += layer.weights[in_idx * layer.output_size + out_idx] * upstream_grad[out_idx];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("prev_grad[in_idx] = sum;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("if (layer_idx > 0) allocator.free(upstream_grad);");
        try builder.writeLine("upstream_grad = prev_grad;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return gradients;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: attention* -> scaled dot-product attention
    if (std.mem.startsWith(u8, b.name, "attention") or
        (std.mem.indexOf(u8, when_text, "attention") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, q: []const f32, k: []const f32, v: []const f32, seq_len: usize, head_dim: usize) ![]f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Scaled dot-product attention: softmax(QK^T / √d) V");
        try builder.writeLine("// q, k, v shape: (seq_len, head_dim)");
        try builder.writeLine("");
        try builder.writeLine("const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));");
        try builder.writeLine("");
        try builder.writeLine("// Compute QK^T scores");
        try builder.writeLine("const scores = try allocator.alloc(f32, seq_len * seq_len);");
        try builder.writeLine("defer allocator.free(scores);");
        try builder.writeLine("");
        try builder.writeLine("for (0..seq_len) |i| {");
        builder.incIndent();
        try builder.writeLine("for (0..seq_len) |j| {");
        builder.incIndent();
        try builder.writeLine("var dot: f32 = 0;");
        try builder.writeLine("for (0..head_dim) |d| {");
        builder.incIndent();
        try builder.writeLine("dot += q[i * head_dim + d] * k[j * head_dim + d];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("scores[i * seq_len + j] = dot * scale;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Apply softmax to each row");
        try builder.writeLine("for (0..seq_len) |i| {");
        builder.incIndent();
        try builder.writeLine("const row_start = i * seq_len;");
        try builder.writeLine("const row = scores[row_start .. row_start + seq_len];");
        try builder.writeLine("");
        try builder.writeLine("// Find max for numerical stability");
        try builder.writeLine("var max_val = row[0];");
        try builder.writeLine("for (row[1..]) |val| { if (val > max_val) max_val = val; }");
        try builder.writeLine("");
        try builder.writeLine("// Compute exp and sum");
        try builder.writeLine("var exp_sum: f32 = 0;");
        try builder.writeLine("for (row) |*val| {");
        builder.incIndent();
        try builder.writeLine("val.* = @exp(val.* - max_val);");
        try builder.writeLine("exp_sum += val.*;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Normalize");
        try builder.writeLine("for (row) |*val| { val.* /= exp_sum; }");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Compute output: attention_weights @ V");
        try builder.writeLine("const output = try allocator.alloc(f32, seq_len * head_dim);");
        try builder.writeLine("@memset(output, 0);");
        try builder.writeLine("");
        try builder.writeLine("for (0..seq_len) |i| {");
        builder.incIndent();
        try builder.writeLine("for (0..seq_len) |j| {");
        builder.incIndent();
        try builder.writeLine("const weight = scores[i * seq_len + j];");
        try builder.writeLine("for (0..head_dim) |d| {");
        builder.incIndent();
        try builder.writeLine("output[i * head_dim + d] += weight * v[j * head_dim + d];");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return output;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: feedforward* -> feedforward network layer (MLP)
    if (std.mem.startsWith(u8, b.name, "feedforward") or
        (std.mem.indexOf(u8, when_text, "feedforward") != null or std.mem.indexOf(u8, when_text, "mlp") != null))
    {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, input: []const f32, w1: []const f32, b1: []const f32, w2: []const f32, b2: []const f32) ![]f32 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Feedforward layer: FFN(x) = GELU(xW1 + b1)W2 + b2");
        try builder.writeLine("// Hidden dim typically 4x input dim");
        try builder.writeLine("");
        try builder.writeLine("const input_dim = input.len;");
        try builder.writeLine("const hidden_dim = b1.len;");
        try builder.writeLine("const output_dim = b2.len;");
        try builder.writeLine("");
        try builder.writeLine("// First linear: xW1 + b1");
        try builder.writeLine("const hidden = try allocator.alloc(f32, hidden_dim);");
        try builder.writeLine("defer allocator.free(hidden);");
        try builder.writeLine("");
        try builder.writeLine("for (0..hidden_dim) |j| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = b1[j];");
        try builder.writeLine("for (0..input_dim) |i| {");
        builder.incIndent();
        try builder.writeLine("sum += input[i] * w1[i * hidden_dim + j];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("// GELU activation: x * Φ(x)");
        try builder.writeLine("hidden[j] = sum * 0.5 * (1.0 + @erf(sum / @sqrt(2.0)));");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("// Second linear: hidden @ W2 + b2");
        try builder.writeLine("const output = try allocator.alloc(f32, output_dim);");
        try builder.writeLine("");
        try builder.writeLine("for (0..output_dim) |j| {");
        builder.incIndent();
        try builder.writeLine("var sum: f32 = b2[j];");
        try builder.writeLine("for (0..hidden_dim) |i| {");
        builder.incIndent();
        try builder.writeLine("sum += hidden[i] * w2[i * output_dim + j];");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("output[j] = sum;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return output;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER TYPE DEFINITION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Layer = struct {
    weights: []f32,
    biases: []f32,
    output_size: usize,
    activation_fn: fn (f32) f32,
};
