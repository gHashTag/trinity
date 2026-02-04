// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 FULL FORWARD PASS
// Complete transformer implementation with ternary quantization
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetConfig = struct {
    vocab_size: u32 = 32002,
    hidden_size: u32 = 1536,
    intermediate_size: u32 = 4096,
    num_hidden_layers: u32 = 24,
    num_attention_heads: u32 = 16,
    num_key_value_heads: u32 = 16,
    max_position_embeddings: u32 = 2048,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 10000.0,
    
    pub fn headDim(self: BitNetConfig) u32 {
        return self.hidden_size / self.num_attention_heads;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WEIGHT QUANTIZATION (F32 -> Ternary)
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize F32 weights to ternary {-1, 0, +1}
/// Uses absmean quantization: w_q = round(w / scale), scale = mean(|w|)
pub fn quantizeToTernary(weights: []const f32, output: []i8, scale: *f32) void {
    // Compute absolute mean
    var sum: f32 = 0.0;
    for (weights) |w| {
        sum += @abs(w);
    }
    const absmean = sum / @as(f32, @floatFromInt(weights.len));
    scale.* = absmean;
    
    // Quantize to ternary
    for (weights, 0..) |w, i| {
        const scaled = w / absmean;
        if (scaled > 0.5) {
            output[i] = 1;
        } else if (scaled < -0.5) {
            output[i] = -1;
        } else {
            output[i] = 0;
        }
    }
}

/// Ternary matrix-vector multiplication with scale
pub fn ternaryMatVec(
    weights: []const i8,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
    scale: f32,
) void {
    for (0..rows) |i| {
        var sum: f32 = 0.0;
        const row_start = i * cols;
        
        // SIMD-friendly inner loop
        var j: usize = 0;
        while (j + 8 <= cols) : (j += 8) {
            inline for (0..8) |k| {
                const w = weights[row_start + j + k];
                const x = input[j + k];
                sum += @as(f32, @floatFromInt(w)) * x;
            }
        }
        
        // Handle remainder
        while (j < cols) : (j += 1) {
            const w = weights[row_start + j];
            const x = input[j];
            sum += @as(f32, @floatFromInt(w)) * x;
        }
        
        output[i] = sum * scale;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVATION QUANTIZATION (8-bit per-token absmax)
// BitNet b1.58: activations quantized to 8-bit signed [-127, 127]
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize activations to 8-bit using per-token absmax scaling
/// Returns the scale factor for dequantization
pub fn quantizeActivations8bit(input: []const f32, output: []i8, scale: *f32) void {
    // Find maximum absolute value (absmax)
    var max_abs: f32 = 0.0;
    for (input) |x| {
        const abs_x = @abs(x);
        if (abs_x > max_abs) max_abs = abs_x;
    }
    
    // Avoid division by zero
    if (max_abs < 1e-10) {
        @memset(output, 0);
        scale.* = 1.0;
        return;
    }
    
    // Scale to [-127, 127] range
    const quant_scale = 127.0 / max_abs;
    scale.* = max_abs / 127.0; // Store dequant scale
    
    // Quantize
    for (input, 0..) |x, i| {
        const scaled = x * quant_scale;
        // Clamp and round
        const clamped = @max(-127.0, @min(127.0, scaled));
        output[i] = @intFromFloat(@round(clamped));
    }
}

/// Dequantize 8-bit activations back to f32
pub fn dequantizeActivations8bit(input: []const i8, output: []f32, scale: f32) void {
    for (input, 0..) |x, i| {
        output[i] = @as(f32, @floatFromInt(x)) * scale;
    }
}

// SIMD vector types for optimized quantization
const Vec8f32 = @Vector(8, f32);

/// SIMD-optimized activation quantization in-place
/// Uses 8-wide vectors for finding max and applying quantization
pub fn quantizeActivationsInPlace(input: []f32) f32 {
    if (input.len == 0) return 1.0;
    
    // SIMD find maximum absolute value
    var max_vec: Vec8f32 = @splat(0.0);
    var i: usize = 0;
    
    // Process 8 elements at a time
    while (i + 8 <= input.len) : (i += 8) {
        const v: Vec8f32 = input[i..][0..8].*;
        const abs_v = @abs(v);
        max_vec = @max(max_vec, abs_v);
    }
    
    // Reduce SIMD max to scalar
    var max_abs = @reduce(.Max, max_vec);
    
    // Scalar tail
    while (i < input.len) : (i += 1) {
        const abs_x = @abs(input[i]);
        if (abs_x > max_abs) max_abs = abs_x;
    }
    
    if (max_abs < 1e-10) return 1.0;
    
    // Compute scales
    const quant_scale = 127.0 / max_abs;
    const dequant_scale = max_abs / 127.0;
    const quant_vec: Vec8f32 = @splat(quant_scale);
    const dequant_vec: Vec8f32 = @splat(dequant_scale);
    const min_vec: Vec8f32 = @splat(-127.0);
    const max_clamp: Vec8f32 = @splat(127.0);
    
    // SIMD quantize and dequantize
    i = 0;
    while (i + 8 <= input.len) : (i += 8) {
        var v: Vec8f32 = input[i..][0..8].*;
        // Scale
        v = v * quant_vec;
        // Clamp
        v = @max(min_vec, @min(max_clamp, v));
        // Round (using floor(x + 0.5) trick)
        const half: Vec8f32 = @splat(0.5);
        const sign_mask = v < @as(Vec8f32, @splat(0.0));
        const offset = @select(f32, sign_mask, -half, half);
        v = @floor(v + offset);
        // Dequantize
        v = v * dequant_vec;
        // Store
        input[i..][0..8].* = v;
    }
    
    // Scalar tail
    while (i < input.len) : (i += 1) {
        const scaled = input[i] * quant_scale;
        const clamped = @max(-127.0, @min(127.0, scaled));
        const quantized = @round(clamped);
        input[i] = quantized * dequant_scale;
    }
    
    return dequant_scale;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RMS NORMALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn rmsNorm(input: []const f32, weight: []const f32, output: []f32, eps: f32) void {
    // Compute RMS
    var sum_sq: f32 = 0.0;
    for (input) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(input.len)) + eps);
    
    // Normalize and scale
    for (input, weight, 0..) |x, w, i| {
        output[i] = (x / rms) * w;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROTARY POSITION EMBEDDINGS (RoPE)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn applyRoPE(
    q: []f32,
    k: []f32,
    position: usize,
    head_dim: usize,
    rope_theta: f32,
) void {
    const half_dim = head_dim / 2;
    
    for (0..half_dim) |i| {
        // Compute rotation angle
        const freq = 1.0 / math.pow(f32, rope_theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
        const angle = @as(f32, @floatFromInt(position)) * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);
        
        // Apply rotation to Q
        const q0 = q[i];
        const q1 = q[i + half_dim];
        q[i] = q0 * cos_val - q1 * sin_val;
        q[i + half_dim] = q0 * sin_val + q1 * cos_val;
        
        // Apply rotation to K
        const k0 = k[i];
        const k1 = k[i + half_dim];
        k[i] = k0 * cos_val - k1 * sin_val;
        k[i + half_dim] = k0 * sin_val + k1 * cos_val;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOFTMAX
// ═══════════════════════════════════════════════════════════════════════════════

pub fn softmax(input: []f32) void {
    // Find max for numerical stability
    var max_val: f32 = -math.inf(f32);
    for (input) |x| {
        if (x > max_val) max_val = x;
    }
    
    // Compute exp and sum
    var sum: f32 = 0.0;
    for (input) |*x| {
        x.* = @exp(x.* - max_val);
        sum += x.*;
    }
    
    // Normalize
    for (input) |*x| {
        x.* /= sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SILU ACTIVATION (SwiGLU)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn silu(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSFORMER LAYER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TransformerLayer = struct {
    allocator: std.mem.Allocator,
    config: BitNetConfig,
    
    // Attention weights (ternary)
    q_proj: []i8,
    k_proj: []i8,
    v_proj: []i8,
    o_proj: []i8,
    q_scale: f32,
    k_scale: f32,
    v_scale: f32,
    o_scale: f32,
    
    // FFN weights (ternary)
    gate_proj: []i8,
    up_proj: []i8,
    down_proj: []i8,
    gate_scale: f32,
    up_scale: f32,
    down_scale: f32,
    
    // Norms (F32)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    inner_attn_ln: []f32,
    ffn_layernorm: []f32,
    
    // Buffers
    hidden_buffer: []f32,
    attn_buffer: []f32,
    ffn_buffer: []f32,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNetConfig) !TransformerLayer {
        const hidden = config.hidden_size;
        const inter = config.intermediate_size;
        
        return TransformerLayer{
            .allocator = allocator,
            .config = config,
            
            // Allocate ternary weights
            .q_proj = try allocator.alloc(i8, hidden * hidden),
            .k_proj = try allocator.alloc(i8, hidden * hidden),
            .v_proj = try allocator.alloc(i8, hidden * hidden),
            .o_proj = try allocator.alloc(i8, hidden * hidden),
            .q_scale = 1.0,
            .k_scale = 1.0,
            .v_scale = 1.0,
            .o_scale = 1.0,
            
            .gate_proj = try allocator.alloc(i8, inter * hidden),
            .up_proj = try allocator.alloc(i8, inter * hidden),
            .down_proj = try allocator.alloc(i8, hidden * inter),
            .gate_scale = 1.0,
            .up_scale = 1.0,
            .down_scale = 1.0,
            
            // Allocate norms
            .input_layernorm = try allocator.alloc(f32, hidden),
            .post_attention_layernorm = try allocator.alloc(f32, hidden),
            .inner_attn_ln = try allocator.alloc(f32, hidden),
            .ffn_layernorm = try allocator.alloc(f32, inter),
            
            // Allocate buffers
            .hidden_buffer = try allocator.alloc(f32, hidden),
            .attn_buffer = try allocator.alloc(f32, hidden),
            .ffn_buffer = try allocator.alloc(f32, inter),
        };
    }
    
    pub fn deinit(self: *TransformerLayer) void {
        self.allocator.free(self.q_proj);
        self.allocator.free(self.k_proj);
        self.allocator.free(self.v_proj);
        self.allocator.free(self.o_proj);
        self.allocator.free(self.gate_proj);
        self.allocator.free(self.up_proj);
        self.allocator.free(self.down_proj);
        self.allocator.free(self.input_layernorm);
        self.allocator.free(self.post_attention_layernorm);
        self.allocator.free(self.inner_attn_ln);
        self.allocator.free(self.ffn_layernorm);
        self.allocator.free(self.hidden_buffer);
        self.allocator.free(self.attn_buffer);
        self.allocator.free(self.ffn_buffer);
    }
    
    /// Forward pass through one transformer layer
    pub fn forward(self: *TransformerLayer, input: []f32, position: usize) void {
        const hidden = self.config.hidden_size;
        const inter = self.config.intermediate_size;
        
        // 1. Input LayerNorm
        rmsNorm(input, self.input_layernorm, self.hidden_buffer, self.config.rms_norm_eps);
        
        // 2. Self-Attention
        // Q projection
        var q = self.allocator.alloc(f32, hidden) catch return;
        defer self.allocator.free(q);
        ternaryMatVec(self.q_proj, self.hidden_buffer, q, hidden, hidden, self.q_scale);
        
        // K projection
        const k = self.allocator.alloc(f32, hidden) catch return;
        defer self.allocator.free(k);
        ternaryMatVec(self.k_proj, self.hidden_buffer, k, hidden, hidden, self.k_scale);
        
        // V projection
        const v = self.allocator.alloc(f32, hidden) catch return;
        defer self.allocator.free(v);
        ternaryMatVec(self.v_proj, self.hidden_buffer, v, hidden, hidden, self.v_scale);
        
        // Apply RoPE
        const head_dim = self.config.headDim();
        for (0..self.config.num_attention_heads) |h| {
            const start = h * head_dim;
            const end = start + head_dim;
            applyRoPE(q[start..end], k[start..end], position, head_dim, self.config.rope_theta);
        }
        
        // Inner attention LayerNorm
        rmsNorm(q, self.inner_attn_ln, q, self.config.rms_norm_eps);
        
        // Simplified attention (single position, no KV cache)
        // attn_output = softmax(Q @ K^T / sqrt(d)) @ V
        var attn_scores = self.allocator.alloc(f32, self.config.num_attention_heads) catch return;
        defer self.allocator.free(attn_scores);
        
        for (0..self.config.num_attention_heads) |h| {
            const start = h * head_dim;
            var score: f32 = 0.0;
            for (0..head_dim) |i| {
                score += q[start + i] * k[start + i];
            }
            attn_scores[h] = score / @sqrt(@as(f32, @floatFromInt(head_dim)));
        }
        
        softmax(attn_scores);
        
        // Weighted sum of V
        @memset(self.attn_buffer, 0.0);
        for (0..self.config.num_attention_heads) |h| {
            const start = h * head_dim;
            for (0..head_dim) |i| {
                self.attn_buffer[start + i] += attn_scores[h] * v[start + i];
            }
        }
        
        // O projection
        ternaryMatVec(self.o_proj, self.attn_buffer, self.hidden_buffer, hidden, hidden, self.o_scale);
        
        // Residual connection
        for (input, self.hidden_buffer, 0..) |x, h, i| {
            input[i] = x + h;
        }
        
        // 3. Post-attention LayerNorm
        rmsNorm(input, self.post_attention_layernorm, self.hidden_buffer, self.config.rms_norm_eps);
        
        // 4. FFN (SwiGLU)
        // Gate projection
        ternaryMatVec(self.gate_proj, self.hidden_buffer, self.ffn_buffer, inter, hidden, self.gate_scale);
        
        // Up projection
        const up = self.allocator.alloc(f32, inter) catch return;
        defer self.allocator.free(up);
        ternaryMatVec(self.up_proj, self.hidden_buffer, up, inter, hidden, self.up_scale);
        
        // FFN LayerNorm
        rmsNorm(self.ffn_buffer, self.ffn_layernorm, self.ffn_buffer, self.config.rms_norm_eps);
        
        // SwiGLU: gate * silu(up)
        for (self.ffn_buffer, up, 0..) |g, u, i| {
            self.ffn_buffer[i] = g * silu(u);
        }
        
        // Down projection
        ternaryMatVec(self.down_proj, self.ffn_buffer, self.hidden_buffer, hidden, inter, self.down_scale);
        
        // Residual connection
        for (input, self.hidden_buffer, 0..) |x, h, i| {
            input[i] = x + h;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "quantize to ternary" {
    const weights = [_]f32{ 0.1, -0.2, 0.5, -0.8, 0.01, 0.3 };
    var output: [6]i8 = undefined;
    var scale: f32 = undefined;
    
    quantizeToTernary(&weights, &output, &scale);
    
    try std.testing.expect(scale > 0);
    // Check ternary values
    for (output) |v| {
        try std.testing.expect(v >= -1 and v <= 1);
    }
}

test "rms norm" {
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;
    
    rmsNorm(&input, &weight, &output, 1e-5);
    
    // Check normalized
    var sum_sq: f32 = 0.0;
    for (output) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / 4.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.1);
}

test "softmax" {
    var input = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&input);
    
    // Check sums to 1
    var sum: f32 = 0.0;
    for (input) |x| {
        sum += x;
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 1e-5);
}

test "silu activation" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), silu(0.0), 1e-5);
    try std.testing.expect(silu(1.0) > 0.5);
    try std.testing.expect(silu(-1.0) < 0.0);
}

test "transformer layer init" {
    const allocator = std.testing.allocator;
    const config = BitNetConfig{};
    
    var layer = try TransformerLayer.init(allocator, config);
    defer layer.deinit();
    
    try std.testing.expectEqual(@as(usize, 1536 * 1536), layer.q_proj.len);
    try std.testing.expectEqual(@as(usize, 4096 * 1536), layer.gate_proj.len);
}

test "ternary matvec" {
    const weights = [_]i8{ 1, -1, 0, 1, 0, -1, 1, 1, 0 };
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [3]f32 = undefined;
    
    ternaryMatVec(&weights, &input, &output, 3, 3, 1.0);
    
    // Row 0: 1*1 + (-1)*2 + 0*3 = -1
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[0], 1e-5);
    // Row 1: 1*1 + 0*2 + (-1)*3 = -2
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), output[1], 1e-5);
    // Row 2: 1*1 + 1*2 + 0*3 = 3
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), output[2], 1e-5);
}

test "8-bit activation quantization" {
    const input = [_]f32{ 0.5, -1.0, 0.25, 0.75, -0.5 };
    var output: [5]i8 = undefined;
    var scale: f32 = undefined;
    
    quantizeActivations8bit(&input, &output, &scale);
    
    // Max abs is 1.0, so scale should be 1.0/127.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 127.0), scale, 1e-6);
    
    // Check quantized values
    // 0.5 * 127 = 63.5 -> 64
    try std.testing.expectEqual(@as(i8, 64), output[0]);
    // -1.0 * 127 = -127
    try std.testing.expectEqual(@as(i8, -127), output[1]);
    // 0.25 * 127 = 31.75 -> 32
    try std.testing.expectEqual(@as(i8, 32), output[2]);
}

test "8-bit activation dequantization" {
    const input = [_]i8{ 64, -127, 32, 95, -64 };
    var output: [5]f32 = undefined;
    const scale: f32 = 1.0 / 127.0;
    
    dequantizeActivations8bit(&input, &output, scale);
    
    // Check dequantized values
    try std.testing.expectApproxEqAbs(@as(f32, 64.0 / 127.0), output[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[1], 1e-5);
}

test "in-place activation quantization" {
    var input = [_]f32{ 0.5, -1.0, 0.25, 0.75, -0.5 };
    const original = [_]f32{ 0.5, -1.0, 0.25, 0.75, -0.5 };
    
    const scale = quantizeActivationsInPlace(&input);
    _ = scale;
    
    // Values should be close to original (quantization noise)
    for (input, original) |q, o| {
        try std.testing.expectApproxEqAbs(o, q, 0.01);
    }
}
