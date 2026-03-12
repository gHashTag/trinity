// HSLM — Straight-Through Estimator (STE) for True Ternary Training
//
// Quantization modes for training with ternary {-1, 0, +1} weights:
//   none:        Standard training (current behavior, quantizeAbsMean)
//   vanilla:     Fixed threshold STE: |w| > threshold → ±1, else 0
//   twn:         Ternary Weight Networks (Li et al. 2016): α * ternary(w)
//   progressive: Float warmup → gradual transition → full ternary
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// STE CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const SteMode = enum {
    none, // Standard quantizeAbsMean (current behavior)
    vanilla, // Fixed threshold STE
    twn, // Ternary Weight Networks with per-layer alpha
    progressive, // Float → transition → ternary
};

pub const SteConfig = struct {
    mode: SteMode = .none,
    threshold: f32 = 0.5, // Quantization threshold for vanilla
    warmup_steps: u32 = 10000, // Progressive: steps in pure float mode
    transition_steps: u32 = 10000, // Progressive: steps for float→ternary blend
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZATION FUNCTIONS
// Each returns alpha (scale factor). For vanilla/none, alpha = 1.0.
// For TWN, alpha = mean(|w_i|) for non-zero entries — preserves magnitude.
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard quantization (current behavior): threshold = mean(|w|), then scale + round
/// Returns alpha = mean(|w|) for compatibility, but currently NOT applied in forward.
pub fn quantizeAbsMean(float_weights: []const f32, ternary_weights: []i8) f32 {
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

    return scale;
}

/// Vanilla STE: fixed threshold, no scaling. Simple {-1, 0, +1}.
/// Returns alpha = 1.0 (no scaling applied in forward pass).
pub fn quantizeVanilla(float_weights: []const f32, ternary_weights: []i8, threshold: f32) f32 {
    for (float_weights, 0..) |w, i| {
        if (w > threshold) {
            ternary_weights[i] = 1;
        } else if (w < -threshold) {
            ternary_weights[i] = -1;
        } else {
            ternary_weights[i] = 0;
        }
    }
    return 1.0;
}

/// TWN (Ternary Weight Networks, Li et al. 2016):
/// 1. Compute optimal threshold Δ = 0.7 * mean(|w|) (from paper)
/// 2. Quantize: w > Δ → +1, w < -Δ → -1, else → 0
/// 3. Compute alpha = mean(|w_i|) for w_i where |w_i| > Δ
/// Forward pass: output = alpha * ternary_matvec(input, ternary_weights)
pub fn quantizeTwn(float_weights: []const f32, ternary_weights: []i8) f32 {
    // Step 1: Compute optimal threshold Δ = 0.7 * mean(|w|)
    var abs_sum: f64 = 0.0;
    for (float_weights) |w| {
        abs_sum += @abs(@as(f64, w));
    }
    const mean_abs: f32 = @floatCast(abs_sum / @as(f64, @floatFromInt(float_weights.len)));
    const delta: f32 = 0.7 * mean_abs;

    // Step 2: Quantize with threshold delta
    var alpha_sum: f64 = 0.0;
    var alpha_count: u32 = 0;

    for (float_weights, 0..) |w, i| {
        if (w > delta) {
            ternary_weights[i] = 1;
            alpha_sum += @abs(@as(f64, w));
            alpha_count += 1;
        } else if (w < -delta) {
            ternary_weights[i] = -1;
            alpha_sum += @abs(@as(f64, w));
            alpha_count += 1;
        } else {
            ternary_weights[i] = 0;
        }
    }

    // Step 3: alpha = mean(|w_i|) for non-zero entries
    const alpha: f32 = if (alpha_count > 0)
        @floatCast(alpha_sum / @as(f64, @floatFromInt(alpha_count)))
    else
        1.0;

    return alpha;
}

/// Progressive STE: blend between standard and ternary quantization.
/// During warmup: returns alpha=1.0 with standard quantization (permissive threshold).
/// During transition: threshold tightens linearly.
/// After transition: full ternary with tight threshold.
pub fn quantizeProgressive(
    float_weights: []const f32,
    ternary_weights: []i8,
    current_step: u32,
    config: SteConfig,
) f32 {
    if (current_step < config.warmup_steps) {
        // Warmup phase: very permissive quantization (like standard)
        return quantizeAbsMean(float_weights, ternary_weights);
    } else if (current_step < config.warmup_steps + config.transition_steps) {
        // Transition: blend between abs-mean threshold and TWN
        const progress = @as(f32, @floatFromInt(current_step - config.warmup_steps)) /
            @as(f32, @floatFromInt(config.transition_steps));

        // As progress → 1.0, transition from abs-mean to TWN
        if (progress > 0.5) {
            return quantizeTwn(float_weights, ternary_weights);
        } else {
            return quantizeAbsMean(float_weights, ternary_weights);
        }
    } else {
        // Full ternary: TWN quantization
        return quantizeTwn(float_weights, ternary_weights);
    }
}

/// Dispatch quantization based on STE mode.
/// Returns alpha (scale factor to apply in forward pass).
pub fn quantizeForMode(
    float_weights: []const f32,
    ternary_weights: []i8,
    config: SteConfig,
    current_step: u32,
) f32 {
    return switch (config.mode) {
        .none => quantizeAbsMean(float_weights, ternary_weights),
        .vanilla => quantizeVanilla(float_weights, ternary_weights, config.threshold),
        .twn => quantizeTwn(float_weights, ternary_weights),
        .progressive => quantizeProgressive(float_weights, ternary_weights, current_step, config),
    };
}

/// Apply alpha scaling to a vector (post ternary-matvec)
pub fn applyAlpha(output: []f32, alpha: f32) void {
    if (alpha == 1.0) return; // No-op for non-TWN modes
    for (output) |*v| v.* *= alpha;
}

/// Compute STE metrics for logging
pub const SteMetrics = struct {
    sparsity: f32, // % of weights == 0
    alpha_avg: f32, // Average alpha across layers
    ternary_ratio: f32, // % of weights in {-1, 0, +1}
};

pub fn computeMetrics(ternary_weights: []const i8, alpha: f32) SteMetrics {
    var zeros: u32 = 0;
    for (ternary_weights) |t| {
        if (t == 0) zeros += 1;
    }
    const total = @as(f32, @floatFromInt(ternary_weights.len));
    return SteMetrics{
        .sparsity = @as(f32, @floatFromInt(zeros)) / total * 100.0,
        .alpha_avg = alpha,
        .ternary_ratio = 100.0, // All weights are ternary by definition
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// STE BACKWARD PASS — Gradient Estimator
// ═══════════════════════════════════════════════════════════════════════════════

/// STE backward: pure identity passthrough
/// During backward pass, gradients pass through quantization unchanged.
/// This is the core STE approximation: ∂L/∂w_float ≈ ∂L/∂w_ternary
pub fn steBackwardIdentity(grad_ternary: []const f32, grad_float: []f32) void {
    const n = @min(grad_ternary.len, grad_float.len);
    for (0..n) |i| {
        grad_float[i] = grad_ternary[i];
    }
}

/// STE backward with gradient clipping for saturated weights
/// For weights far from quantization boundaries (|w| >> 1), attenuate gradients.
/// This prevents extreme weight values from receiving large updates.
pub fn steBackwardClipped(
    float_weights: []const f32,
    grad_ternary: []const f32,
    grad_float: []f32,
    threshold: f32,
) void {
    const n = @min(@min(float_weights.len, grad_float.len), grad_ternary.len);
    for (0..n) |i| {
        const g = grad_ternary[i];
        const abs_w = @abs(float_weights[i]);
        if (abs_w > threshold * 2.0) {
            // Weight is far from zero region, attenuate gradient
            const scale = @max(0.1, 1.0 - (abs_w - threshold * 2.0) * 0.1);
            grad_float[i] = g * scale;
        } else {
            // Normal STE: pass gradient through unchanged
            grad_float[i] = g;
        }
    }
}

/// STE backward with TWN-specific gradient handling
/// For TWN mode, account for the alpha scaling factor in the gradient.
/// ∂L/∂w = α * ∂L/∂w_ternary (scaled by alpha for magnitude preservation)
pub fn steBackwardTwn(
    grad_ternary: []const f32,
    grad_float: []f32,
    alpha: f32,
) void {
    const n = @min(grad_ternary.len, grad_float.len);
    for (0..n) |i| {
        grad_float[i] = grad_ternary[i] * alpha;
    }
}

/// STE backward with progressive transition
/// During warmup: full gradient passthrough
/// During transition: blend between identity and clipped
/// After transition: apply clipped STE
pub fn steBackwardProgressive(
    float_weights: []const f32,
    grad_ternary: []const f32,
    grad_float: []f32,
    current_step: u32,
    config: SteConfig,
) void {
    if (current_step < config.warmup_steps) {
        // Warmup: pure identity passthrough
        steBackwardIdentity(grad_ternary, grad_float);
    } else if (current_step < config.warmup_steps + config.transition_steps) {
        // Transition: blend identity → clipped
        const progress = @as(f32, @floatFromInt(current_step - config.warmup_steps)) /
            @as(f32, @floatFromInt(config.transition_steps));
        // Gradually increase clipping threshold
        const blended_threshold = config.threshold * (1.0 + progress);
        steBackwardClipped(float_weights, grad_ternary, grad_float, blended_threshold);
    } else {
        // Full ternary: standard clipped STE
        steBackwardClipped(float_weights, grad_ternary, grad_float, config.threshold);
    }
}

/// Dispatch STE backward based on mode
pub fn steBackwardForMode(
    float_weights: []const f32,
    grad_ternary: []const f32,
    grad_float: []f32,
    config: SteConfig,
    current_step: u32,
    alpha: f32,
) void {
    switch (config.mode) {
        .none => steBackwardIdentity(grad_ternary, grad_float),
        .vanilla => steBackwardClipped(float_weights, grad_ternary, grad_float, config.threshold),
        .twn => steBackwardTwn(grad_ternary, grad_float, alpha),
        .progressive => steBackwardProgressive(float_weights, grad_ternary, grad_float, current_step, config),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "vanilla STE quantization" {
    const weights = [_]f32{ 0.7, -0.8, 0.3, -0.2, 0.0, 1.5, -1.5 };
    var output: [7]i8 = undefined;
    const alpha = quantizeVanilla(&weights, &output, 0.5);

    try std.testing.expectEqual(@as(f32, 1.0), alpha);
    try std.testing.expectEqual(@as(i8, 1), output[0]); // 0.7 > 0.5
    try std.testing.expectEqual(@as(i8, -1), output[1]); // -0.8 < -0.5
    try std.testing.expectEqual(@as(i8, 0), output[2]); // 0.3 in deadzone
    try std.testing.expectEqual(@as(i8, 0), output[3]); // -0.2 in deadzone
    try std.testing.expectEqual(@as(i8, 0), output[4]); // 0.0 in deadzone
    try std.testing.expectEqual(@as(i8, 1), output[5]); // 1.5 > 0.5
    try std.testing.expectEqual(@as(i8, -1), output[6]); // -1.5 < -0.5
}

test "TWN quantization with alpha" {
    const weights = [_]f32{ 0.7, -0.8, 0.1, -0.05, 0.9, -1.2 };
    var output: [6]i8 = undefined;
    const alpha = quantizeTwn(&weights, &output);

    // alpha = mean of |non-zero| entries
    try std.testing.expect(alpha > 0.5);
    try std.testing.expect(alpha < 1.5);

    // Non-zero entries should be ±1
    try std.testing.expectEqual(@as(i8, 1), output[0]); // 0.7 > Δ
    try std.testing.expectEqual(@as(i8, -1), output[1]); // -0.8 < -Δ
    try std.testing.expectEqual(@as(i8, 1), output[4]); // 0.9 > Δ
    try std.testing.expectEqual(@as(i8, -1), output[5]); // -1.2 < -Δ
}

test "progressive STE phases" {
    const config = SteConfig{
        .mode = .progressive,
        .threshold = 0.5,
        .warmup_steps = 100,
        .transition_steps = 100,
    };
    const weights = [_]f32{ 0.7, -0.8, 0.3, -0.1 };
    var output: [4]i8 = undefined;

    // Step 50: warmup (standard quantization)
    const alpha1 = quantizeProgressive(&weights, &output, 50, config);
    try std.testing.expect(alpha1 > 0.0);
    // Should still quantize
    try std.testing.expect(output[0] == 1 or output[0] == 0);

    // Step 250: full ternary (TWN)
    const alpha3 = quantizeProgressive(&weights, &output, 250, config);
    try std.testing.expect(alpha3 > 0.0);
}

test "quantizeForMode dispatch" {
    const weights = [_]f32{ 0.5, -0.5, 0.0 };
    var output: [3]i8 = undefined;

    // None mode
    _ = quantizeForMode(&weights, &output, SteConfig{ .mode = .none }, 0);
    // Should not crash

    // TWN mode
    const alpha = quantizeForMode(&weights, &output, SteConfig{ .mode = .twn }, 0);
    try std.testing.expect(alpha > 0.0);
}

test "applyAlpha scaling" {
    var data = [_]f32{ 1.0, -2.0, 3.0, 0.0 };
    applyAlpha(&data, 0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), data[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.5), data[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.25), data[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), data[3], 0.001);
}

test "applyAlpha noop for 1.0" {
    var data = [_]f32{ 1.0, -2.0, 3.0 };
    applyAlpha(&data, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), data[0]);
    try std.testing.expectEqual(@as(f32, -2.0), data[1]);
}

test "STE metrics" {
    const ternary = [_]i8{ 1, 0, -1, 0, 1, 0 };
    const metrics = computeMetrics(&ternary, 0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), metrics.sparsity, 0.1);
    try std.testing.expectEqual(@as(f32, 0.75), metrics.alpha_avg);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STE BACKWARD TESTS — Gradient Passthrough Verification
// ═══════════════════════════════════════════════════════════════════════════════

test "STE backward identity passthrough" {
    // Gradient should pass through unchanged
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.0 };
    var grad_float: [5]f32 = undefined;

    steBackwardIdentity(&grad_ternary, &grad_float);

    // Gradients should be identical (STE identity)
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i], grad_float[i], 1e-6);
    }
}

test "STE backward clipped for normal weights" {
    // Weights within normal range should get full gradient
    const float_weights = [_]f32{ 0.3, -0.5, 0.8, -0.2, 0.1 };
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.5 };
    var grad_float: [5]f32 = undefined;

    steBackwardClipped(&float_weights, &grad_ternary, &grad_float, 0.5);

    // For weights |w| < threshold*2, gradient passes through unchanged
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i], grad_float[i], 1e-6);
    }
}

test "STE backward clipped for saturated weights" {
    // Weights far from zero should have attenuated gradients
    const float_weights = [_]f32{ 3.0, -4.0, 0.5, -0.3, 2.5 }; // 3.0, -4.0, 2.5 are saturated
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.5 };
    var grad_float: [5]f32 = undefined;

    steBackwardClipped(&float_weights, &grad_ternary, &grad_float, 0.5);

    // Middle weights should have full gradient
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), grad_float[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -0.4), grad_float[3], 1e-6);

    // Saturated weights should have attenuated gradients
    try std.testing.expect(grad_float[0] < grad_ternary[0]); // 3.0 is saturated
    try std.testing.expect(@abs(grad_float[1]) < @abs(grad_ternary[1])); // -4.0 is saturated
    try std.testing.expect(grad_float[4] < grad_ternary[4]); // 2.5 is saturated
}

test "STE backward TWN with alpha scaling" {
    // TWN mode should scale gradients by alpha
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.5 };
    var grad_float: [5]f32 = undefined;
    const alpha: f32 = 0.75;

    steBackwardTwn(&grad_ternary, &grad_float, alpha);

    // Gradients should be scaled by alpha
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i] * alpha, grad_float[i], 1e-6);
    }
}

test "STE backward progressive warmup phase" {
    // During warmup, should use identity passthrough
    const float_weights = [_]f32{ 3.0, -4.0, 0.5, -0.3, 2.5 };
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.5 };
    var grad_float: [5]f32 = undefined;

    const config = SteConfig{
        .mode = .progressive,
        .threshold = 0.5,
        .warmup_steps = 100,
        .transition_steps = 100,
    };

    // During warmup (step 50 < 100)
    steBackwardProgressive(&float_weights, &grad_ternary, &grad_float, 50, config);

    // Should be identity passthrough even for saturated weights
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i], grad_float[i], 1e-6);
    }
}

test "STE backward for mode dispatch" {
    const float_weights = [_]f32{ 0.5, -0.5, 0.3, -0.3, 0.1 };
    const grad_ternary = [_]f32{ 0.1, -0.2, 0.3, -0.4, 0.5 };
    var grad_float: [5]f32 = undefined;

    // Test none mode (identity)
    var config = SteConfig{ .mode = .none };
    steBackwardForMode(&float_weights, &grad_ternary, &grad_float, config, 0, 1.0);
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i], grad_float[i], 1e-6);
    }

    // Test TWN mode (scaled by alpha)
    config = SteConfig{ .mode = .twn };
    steBackwardForMode(&float_weights, &grad_ternary, &grad_float, config, 0, 0.5);
    for (0..5) |i| {
        try std.testing.expectApproxEqAbs(grad_ternary[i] * 0.5, grad_float[i], 1e-6);
    }
}

test "STE gradient passthrough preserves sign" {
    // Gradients should preserve sign through STE
    const grad_ternary = [_]f32{ 1.0, -1.0, 2.0, -2.0, 0.0 };
    var grad_float: [5]f32 = undefined;

    steBackwardIdentity(&grad_ternary, &grad_float);

    for (0..5) |i| {
        if (grad_ternary[i] > 0) {
            try std.testing.expect(grad_float[i] > 0);
        } else if (grad_ternary[i] < 0) {
            try std.testing.expect(grad_float[i] < 0);
        } else {
            try std.testing.expectApproxEqAbs(@as(f32, 0.0), grad_float[i], 1e-6);
        }
    }
}
