// HSLM — Trinity Block
// One block = TNN Dense (System 1) + VSA Attention + VSA Reasoning (System 2)
// System 2 activates only when consciousness gate fires (similarity > φ⁻¹)

const std = @import("std");
const constants = @import("constants.zig");
const attention = @import("attention.zig");
const reasoning = @import("reasoning.zig");
const consciousness = @import("consciousness.zig");
const embedding = @import("embedding.zig");
const sacred_attention_mod = @import("sacred_attention.zig");
const simd_ops = @import("simd_ops.zig");
const ste = @import("ste.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VSA_DIM = constants.VSA_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY DENSE LAYER (TNN)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TernaryDense = struct {
    // Weights stored as ternary {-1, 0, +1}
    // Forward pass: output[j] = sum_i(input[i] * weight[i][j]) + bias[j]
    // No multiplication needed — just add, subtract, or skip
    weights_up: []i8, // EMBED_DIM × HIDDEN_DIM
    bias_up: []f32, // HIDDEN_DIM
    weights_down: []i8, // HIDDEN_DIM × EMBED_DIM
    bias_down: []f32, // EMBED_DIM
    // Shadow float weights for training
    shadow_up: []f32,
    shadow_down: []f32,
    // Gradient buffers for STE backprop
    grad_shadow_up: []f32, // EMBED_DIM × HIDDEN_DIM
    grad_shadow_down: []f32, // HIDDEN_DIM × EMBED_DIM
    grad_bias_up: []f32, // HIDDEN_DIM
    grad_bias_down: []f32, // EMBED_DIM
    // Activation cache for backward pass (last position only)
    cache_input: []f32, // EMBED_DIM
    cache_hidden: []f32, // HIDDEN_DIM (post-ReLU)
    // TWN alpha scale factors (per-layer, computed during requantize)
    alpha_up: f32 = 1.0,
    alpha_down: f32 = 1.0,
    is_worker: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const w_up = try allocator.alloc(i8, EMBED_DIM * HIDDEN_DIM);
        const b_up = try allocator.alloc(f32, HIDDEN_DIM);
        const w_dn = try allocator.alloc(i8, HIDDEN_DIM * EMBED_DIM);
        const b_dn = try allocator.alloc(f32, EMBED_DIM);
        const s_up = try allocator.alloc(f32, EMBED_DIM * HIDDEN_DIM);
        const s_dn = try allocator.alloc(f32, HIDDEN_DIM * EMBED_DIM);

        // Gradient buffers
        const g_up = try allocator.alloc(f32, EMBED_DIM * HIDDEN_DIM);
        const g_dn = try allocator.alloc(f32, HIDDEN_DIM * EMBED_DIM);
        const gb_up = try allocator.alloc(f32, HIDDEN_DIM);
        const gb_dn = try allocator.alloc(f32, EMBED_DIM);
        @memset(g_up, 0.0);
        @memset(g_dn, 0.0);
        @memset(gb_up, 0.0);
        @memset(gb_dn, 0.0);

        // Activation cache
        const c_in = try allocator.alloc(f32, EMBED_DIM);
        const c_hid = try allocator.alloc(f32, HIDDEN_DIM);
        @memset(c_in, 0.0);
        @memset(c_hid, 0.0);

        // Xavier init for shadow weights
        const scale_up = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
        const scale_dn = 1.0 / @sqrt(@as(f32, @floatFromInt(HIDDEN_DIM)));
        var prng = std.Random.DefaultPrng.init(0xB10C_1234);
        const rng = prng.random();

        for (0..EMBED_DIM * HIDDEN_DIM) |i| {
            s_up[i] = (rng.float(f32) * 2.0 - 1.0) * scale_up;
        }
        for (0..HIDDEN_DIM * EMBED_DIM) |i| {
            s_dn[i] = (rng.float(f32) * 2.0 - 1.0) * scale_dn;
        }

        // Quantize shadow → ternary
        quantizeAbsMean(s_up, w_up);
        quantizeAbsMean(s_dn, w_dn);

        @memset(b_up, 0.0);
        @memset(b_dn, 0.0);

        return Self{
            .weights_up = w_up,
            .bias_up = b_up,
            .weights_down = w_dn,
            .bias_down = b_dn,
            .shadow_up = s_up,
            .shadow_down = s_dn,
            .grad_shadow_up = g_up,
            .grad_shadow_down = g_dn,
            .grad_bias_up = gb_up,
            .grad_bias_down = gb_dn,
            .cache_input = c_in,
            .cache_hidden = c_hid,
            .is_worker = false,
            .allocator = allocator,
        };
    }

    /// Worker-light init: allocates weights + bias + grads + caches, skips shadow weights.
    /// Saves ~1.35MB per TernaryDense instance.
    pub fn initWorker(allocator: std.mem.Allocator) !Self {
        const w_up = try allocator.alloc(i8, EMBED_DIM * HIDDEN_DIM);
        const b_up = try allocator.alloc(f32, HIDDEN_DIM);
        const w_dn = try allocator.alloc(i8, HIDDEN_DIM * EMBED_DIM);
        const b_dn = try allocator.alloc(f32, EMBED_DIM);
        @memset(w_up, 0);
        @memset(b_up, 0.0);
        @memset(w_dn, 0);
        @memset(b_dn, 0.0);

        // Gradient buffers
        const g_up = try allocator.alloc(f32, EMBED_DIM * HIDDEN_DIM);
        const g_dn = try allocator.alloc(f32, HIDDEN_DIM * EMBED_DIM);
        const gb_up = try allocator.alloc(f32, HIDDEN_DIM);
        const gb_dn = try allocator.alloc(f32, EMBED_DIM);
        @memset(g_up, 0.0);
        @memset(g_dn, 0.0);
        @memset(gb_up, 0.0);
        @memset(gb_dn, 0.0);

        // Activation cache
        const c_in = try allocator.alloc(f32, EMBED_DIM);
        const c_hid = try allocator.alloc(f32, HIDDEN_DIM);
        @memset(c_in, 0.0);
        @memset(c_hid, 0.0);

        return Self{
            .weights_up = w_up,
            .bias_up = b_up,
            .weights_down = w_dn,
            .bias_down = b_dn,
            .shadow_up = &.{},
            .shadow_down = &.{},
            .grad_shadow_up = g_up,
            .grad_shadow_down = g_dn,
            .grad_bias_up = gb_up,
            .grad_bias_down = gb_dn,
            .cache_input = c_in,
            .cache_hidden = c_hid,
            .is_worker = true,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.weights_up);
        self.allocator.free(self.bias_up);
        self.allocator.free(self.weights_down);
        self.allocator.free(self.bias_down);
        if (!self.is_worker) {
            self.allocator.free(self.shadow_up);
            self.allocator.free(self.shadow_down);
        }
        self.allocator.free(self.grad_shadow_up);
        self.allocator.free(self.grad_shadow_down);
        self.allocator.free(self.grad_bias_up);
        self.allocator.free(self.grad_bias_down);
        self.allocator.free(self.cache_input);
        self.allocator.free(self.cache_hidden);
    }

    /// Forward: input(EMBED_DIM) → hidden(HIDDEN_DIM) → output(EMBED_DIM)
    /// Uses ternary matmul (no multiply, just add/sub/skip)
    pub fn forward(self: *const Self, input: []const f32, output: []f32) void {
        // Up projection: EMBED_DIM → HIDDEN_DIM
        var hidden: [HIDDEN_DIM]f32 = undefined;
        simd_ops.ternaryMatvecSimd(input, self.weights_up, &hidden, EMBED_DIM, HIDDEN_DIM);
        ste.applyAlpha(&hidden, self.alpha_up); // TWN scaling
        for (0..HIDDEN_DIM) |j| {
            hidden[j] += self.bias_up[j];
            // ReLU activation
            hidden[j] = @max(0.0, hidden[j]);
        }

        // Down projection: HIDDEN_DIM → EMBED_DIM
        simd_ops.ternaryMatvecSimd(&hidden, self.weights_down, output, HIDDEN_DIM, EMBED_DIM);
        ste.applyAlpha(output[0..EMBED_DIM], self.alpha_down); // TWN scaling
        for (0..EMBED_DIM) |j| {
            output[j] += self.bias_down[j] + input[j]; // Residual connection
        }
    }

    /// Re-quantize shadow weights to ternary (call after gradient update)
    pub fn requantize(self: *Self) void {
        quantizeAbsMean(self.shadow_up, self.weights_up);
        quantizeAbsMean(self.shadow_down, self.weights_down);
    }

    /// STE-aware requantize: uses configured mode, stores alpha for TWN
    pub fn requantizeSte(self: *Self, config: ste.SteConfig, current_step: u32) void {
        self.alpha_up = ste.quantizeForMode(self.shadow_up, self.weights_up, config, current_step);
        self.alpha_down = ste.quantizeForMode(self.shadow_down, self.weights_down, config, current_step);
    }

    /// Forward with activation caching (for training backward pass)
    pub fn forwardCached(self: *Self, input: []const f32, output: []f32) void {
        // Cache input for backward
        @memcpy(self.cache_input, input[0..EMBED_DIM]);

        // Up projection: EMBED_DIM → HIDDEN_DIM
        var hidden: [HIDDEN_DIM]f32 = undefined;
        simd_ops.ternaryMatvecSimd(input, self.weights_up, &hidden, EMBED_DIM, HIDDEN_DIM);
        ste.applyAlpha(&hidden, self.alpha_up); // TWN scaling
        for (0..HIDDEN_DIM) |j| {
            hidden[j] += self.bias_up[j];
            // ReLU activation
            hidden[j] = @max(0.0, hidden[j]);
        }

        // Cache post-ReLU hidden for backward
        @memcpy(self.cache_hidden, &hidden);

        // Down projection: HIDDEN_DIM → EMBED_DIM
        simd_ops.ternaryMatvecSimd(&hidden, self.weights_down, output, HIDDEN_DIM, EMBED_DIM);
        ste.applyAlpha(output[0..EMBED_DIM], self.alpha_down); // TWN scaling
        for (0..EMBED_DIM) |j| {
            output[j] += self.bias_down[j] + input[j]; // Residual connection
        }
    }

    /// STE backward through: residual → down proj → ReLU → up proj
    pub fn backward(self: *Self, grad_output: []const f32, grad_input: []f32) void {
        // Step 1: Residual — copy through
        @memcpy(grad_input[0..EMBED_DIM], grad_output[0..EMBED_DIM]);

        // Step 2: Down projection backward
        // Input grad: ∂L/∂hidden[i] = sum_j(∂L/∂output[j] * W_down[i*EMBED+j])
        var grad_hidden: [HIDDEN_DIM]f32 = undefined;
        simd_ops.ternaryVecmatSimd(grad_output, self.weights_down, &grad_hidden, HIDDEN_DIM, EMBED_DIM);
        // Weight grad: ∂L/∂W_down[i*EMBED+j] += ∂L/∂output[j] * cache_hidden[i]
        simd_ops.outerProductAccumSimd(self.grad_shadow_down, grad_output, self.cache_hidden, HIDDEN_DIM, EMBED_DIM);
        // Bias grad down
        for (0..EMBED_DIM) |j| {
            self.grad_bias_down[j] += grad_output[j];
        }

        // Step 3: ReLU backward — zero where cache_hidden == 0 (pre-relu was <= 0)
        for (0..HIDDEN_DIM) |i| {
            if (self.cache_hidden[i] == 0.0) grad_hidden[i] = 0.0;
        }

        // Step 4: Up projection backward
        // Input grad: ∂L/∂input[i] += sum_j(∂L/∂hidden[j] * W_up[i*HIDDEN+j])
        simd_ops.ternaryVecmatSimdAccum(&grad_hidden, self.weights_up, grad_input, EMBED_DIM, HIDDEN_DIM);
        // Weight grad: ∂L/∂W_up[i*HIDDEN+j] += ∂L/∂hidden[j] * cache_input[i]
        simd_ops.outerProductAccumSimd(self.grad_shadow_up, &grad_hidden, self.cache_input, EMBED_DIM, HIDDEN_DIM);
        // Bias grad up
        for (0..HIDDEN_DIM) |j| {
            self.grad_bias_up[j] += grad_hidden[j];
        }
    }

    /// Zero all gradient buffers
    pub fn zeroGrad(self: *Self) void {
        @memset(self.grad_shadow_up, 0.0);
        @memset(self.grad_shadow_down, 0.0);
        @memset(self.grad_bias_up, 0.0);
        @memset(self.grad_bias_down, 0.0);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityBlock = struct {
    sacred_attn: sacred_attention_mod.SacredAttention,
    tnn: TernaryDense,
    attn: attention.VSAAttention,
    reason: reasoning.Reasoning,
    gate: consciousness.ConsciousnessGate,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .sacred_attn = try sacred_attention_mod.SacredAttention.init(allocator),
            .tnn = try TernaryDense.init(allocator),
            .attn = attention.VSAAttention.init(allocator),
            .reason = reasoning.Reasoning.init(),
            .gate = consciousness.ConsciousnessGate.initDefault(),
            .allocator = allocator,
        };
    }

    /// Worker-light init: skips shadow weights in TNN and SacredAttention.
    pub fn initWorker(allocator: std.mem.Allocator) !Self {
        return Self{
            .sacred_attn = try sacred_attention_mod.SacredAttention.initWorker(allocator),
            .tnn = try TernaryDense.initWorker(allocator),
            .attn = attention.VSAAttention.init(allocator),
            .reason = reasoning.Reasoning.init(),
            .gate = consciousness.ConsciousnessGate.initDefault(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.sacred_attn.deinit();
        self.tnn.deinit();
    }

    /// Process one position in a sequence
    /// Inputs: float embedding (EMBED_DIM) + trit sequence (positions × VSA_DIM)
    /// Outputs: updated float embedding (EMBED_DIM) + updated trit vector (VSA_DIM)
    pub fn forward(
        self: *Self,
        position: usize,
        float_in: []const f32, // EMBED_DIM
        trit_sequence: []const i8, // (position+1) × VSA_DIM
        float_out: []f32, // EMBED_DIM
        trit_out: []i8, // VSA_DIM
    ) void {
        // ─── Sacred Attention (includes RMSNorm + residual) ───
        var attn_out: [EMBED_DIM]f32 = undefined;
        self.sacred_attn.processPosition(float_in, position, &attn_out);

        // ─── System 1: TNN Dense FFN (includes residual) ───
        self.tnn.forward(&attn_out, float_out);

        // ─── VSA Attention ───
        var context: [VSA_DIM]i8 = undefined;
        const max_sim = self.attn.forwardCausal(position, trit_sequence, &context);

        // ─── Consciousness Gate ───
        if (self.gate.isConscious(max_sim)) {
            // ─── System 2: VSA Reasoning (activated) ───
            const pos_offset = position * VSA_DIM;
            const current_trit = trit_sequence[pos_offset .. pos_offset + VSA_DIM];
            var reasoned: [VSA_DIM]i8 = undefined;
            self.reason.forward(current_trit, &context, &reasoned);

            // Blend reasoned VSA with TNN output
            // Convert reasoned VSA to float and add to TNN output
            var vsa_float: [EMBED_DIM]f32 = undefined;
            // Project VSA_DIM → EMBED_DIM by simple averaging chunks
            projectVsaToEmbed(&reasoned, &vsa_float);
            for (0..EMBED_DIM) |i| {
                float_out[i] += vsa_float[i] * 0.1; // Small VSA contribution
            }

            @memcpy(trit_out[0..VSA_DIM], &reasoned);
        } else {
            // System 1 only: just use attention context
            @memcpy(trit_out[0..VSA_DIM], &context);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// AbsMean quantization: w_ternary = RoundClip(w / mean(|w|))
fn quantizeAbsMean(float_weights: []const f32, ternary_weights: []i8) void {
    var sum: f64 = 0.0;
    for (float_weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(float_weights.len));
    const scale: f32 = if (mean_abs > 1e-6) @floatCast(mean_abs) else 1.0;

    for (float_weights, 0..) |w, i| {
        const scaled = w / scale;
        if (scaled > 0.5) {
            ternary_weights[i] = 1;
        } else if (scaled < -0.5) {
            ternary_weights[i] = -1;
        } else {
            ternary_weights[i] = 0;
        }
    }
}

/// Project VSA_DIM trit vector → EMBED_DIM float vector
/// Groups of (VSA_DIM/EMBED_DIM) ≈ 4 trits are averaged
pub fn projectVsaToEmbed(vsa_vec: []const i8, embed_vec: []f32) void {
    const ratio = VSA_DIM / EMBED_DIM; // 1024/243 ≈ 4
    for (0..EMBED_DIM) |i| {
        var sum: f32 = 0.0;
        const start = i * ratio;
        const end = @min(start + ratio, VSA_DIM);
        for (start..end) |j| {
            sum += @floatFromInt(vsa_vec[j]);
        }
        embed_vec[i] = sum / @as(f32, @floatFromInt(end - start));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternary matmul basic" {
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    const weights = [_]i8{
        1,  -1,
        0,  1,
        -1, 1,
    }; // 3×2 matrix
    var output: [2]f32 = undefined;
    simd_ops.ternaryMatvecSimd(&input, &weights, &output, 3, 2);

    // output[0] = 1*1 + 2*0 + 3*(-1) = -2
    // output[1] = 1*(-1) + 2*1 + 3*1 = 4
    try std.testing.expectApproxEqAbs(-2.0, output[0], 1e-6);
    try std.testing.expectApproxEqAbs(4.0, output[1], 1e-6);
}

test "quantize absmean" {
    const floats = [_]f32{ 0.8, -0.9, 0.1, 0.0, -0.3, 1.0, -1.0, 0.5 };
    var ternary: [8]i8 = undefined;
    quantizeAbsMean(&floats, &ternary);

    for (ternary) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}

test "ternary dense forward" {
    const allocator = std.testing.allocator;
    var dense = try TernaryDense.init(allocator);
    defer dense.deinit();

    var input: [EMBED_DIM]f32 = undefined;
    for (&input) |*v| v.* = 0.1;

    var output: [EMBED_DIM]f32 = undefined;
    dense.forward(&input, &output);

    // Output should have values (not all zero because of bias + residual)
    var any_nonzero = false;
    for (output) |v| {
        if (v != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);
}

test "trinity block init/deinit" {
    const allocator = std.testing.allocator;
    var block = try TrinityBlock.init(allocator);
    defer block.deinit();

    // Should be initialized
    try std.testing.expectApproxEqAbs(
        constants.PHI_INV,
        block.gate.threshold,
        1e-10,
    );
}

test "trinity block forward" {
    const allocator = std.testing.allocator;
    var block = try TrinityBlock.init(allocator);
    defer block.deinit();

    // Create input
    var float_in: [EMBED_DIM]f32 = undefined;
    for (&float_in) |*v| v.* = 0.05;

    // Create a trit sequence (3 positions)
    const seq_len = 3;
    var trit_seq: [seq_len * VSA_DIM]i8 = undefined;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    for (&trit_seq) |*v| v.* = rng.intRangeAtMost(i8, -1, 1);

    var float_out: [EMBED_DIM]f32 = undefined;
    var trit_out: [VSA_DIM]i8 = undefined;

    block.forward(2, &float_in, &trit_seq, &float_out, &trit_out);

    // Output should be valid
    for (trit_out) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}

test "ternary dense forwardCached matches forward" {
    const allocator = std.testing.allocator;
    var dense = try TernaryDense.init(allocator);
    defer dense.deinit();

    var input: [EMBED_DIM]f32 = undefined;
    for (&input, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 7)) * 0.02 - 0.06;

    var output1: [EMBED_DIM]f32 = undefined;
    var output2: [EMBED_DIM]f32 = undefined;
    dense.forward(&input, &output1);
    dense.forwardCached(&input, &output2);

    for (0..EMBED_DIM) |i| {
        try std.testing.expectApproxEqAbs(output1[i], output2[i], 1e-6);
    }
}

test "ternary dense backward produces gradients" {
    const allocator = std.testing.allocator;
    var dense = try TernaryDense.init(allocator);
    defer dense.deinit();

    var input: [EMBED_DIM]f32 = undefined;
    for (&input) |*v| v.* = 0.1;

    var output: [EMBED_DIM]f32 = undefined;
    dense.forwardCached(&input, &output);

    // Fake gradient from above
    var grad_output: [EMBED_DIM]f32 = undefined;
    for (&grad_output) |*v| v.* = 0.01;

    var grad_input: [EMBED_DIM]f32 = undefined;
    dense.zeroGrad();
    dense.backward(&grad_output, &grad_input);

    // Gradient should flow through
    var any_nonzero_input = false;
    for (grad_input) |g| {
        if (g != 0.0) {
            any_nonzero_input = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero_input);

    var any_nonzero_grad = false;
    for (dense.grad_shadow_up) |g| {
        if (g != 0.0) {
            any_nonzero_grad = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero_grad);
}
