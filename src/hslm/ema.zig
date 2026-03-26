// @origin(manual) @regen(pending)
// T-JEPA — EMA (Exponential Moving Average) Weight Synchronization
// Target encoder = EMA of online encoder shadow floats
// After EMA update, target requantizes ternary weights from updated shadows
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VOCAB_SIZE = constants.VOCAB_SIZE;
const NUM_BLOCKS = constants.NUM_BLOCKS;

// ═══════════════════════════════════════════════════════════════════════════════
// EMA SYNC
// ═══════════════════════════════════════════════════════════════════════════════

pub const EmaSync = struct {
    decay_start: f32, // 0.996 — initial decay (more online influence)
    decay_end: f32, // 1.0 — final decay (target freezes)

    /// Update target shadow floats via EMA: target[i] = decay * target[i] + (1-decay) * online[i]
    pub fn updateShadows(target_shadow: []f32, online_shadow: []const f32, decay: f32) void {
        std.debug.assert(target_shadow.len == online_shadow.len);
        const one_minus_decay = 1.0 - decay;
        for (target_shadow, online_shadow) |*t, o| {
            t.* = decay * t.* + one_minus_decay * o;
        }
    }

    /// Sync all shadow weights from online encoder to target encoder
    /// Operates on: output_shadow, per-block TNN shadows + biases, sacred attention shadows + rms_gamma
    pub fn syncModels(self: *const EmaSync, target: *model_mod.HSLM, online: *const model_mod.HSLM, step: u32, total_steps: u32) void {
        const decay = scheduledDecay(step, total_steps, self.decay_start, self.decay_end);

        // Output projection shadows
        updateShadows(target.output_shadow, online.output_shadow, decay);

        // Per-block params
        for (&target.blocks, &online.blocks) |*t_block, *o_block| {
            // TNN dense shadows
            updateShadows(t_block.tnn.shadow_up, o_block.tnn.shadow_up, decay);
            updateShadows(t_block.tnn.shadow_down, o_block.tnn.shadow_down, decay);
            updateShadows(t_block.tnn.bias_up, o_block.tnn.bias_up, decay);
            updateShadows(t_block.tnn.bias_down, o_block.tnn.bias_down, decay);

            // Sacred attention shadows
            updateShadows(t_block.sacred_attn.shadow_q, o_block.sacred_attn.shadow_q, decay);
            updateShadows(t_block.sacred_attn.shadow_k, o_block.sacred_attn.shadow_k, decay);
            updateShadows(t_block.sacred_attn.shadow_v, o_block.sacred_attn.shadow_v, decay);
            updateShadows(t_block.sacred_attn.shadow_o, o_block.sacred_attn.shadow_o, decay);

            // RMS gamma
            updateShadows(t_block.sacred_attn.rms_gamma, o_block.sacred_attn.rms_gamma, decay);
        }

        // Embedding float table
        updateShadows(target.emb.float_table, online.emb.float_table, decay);
    }

    /// Current decay value at given step
    pub fn currentDecay(self: *const EmaSync, step: u32, total_steps: u32) f32 {
        return scheduledDecay(step, total_steps, self.decay_start, self.decay_end);
    }
};

/// Linear ramp from start to end over total_steps
pub fn scheduledDecay(step: u32, total_steps: u32, start: f32, end: f32) f32 {
    if (total_steps == 0) return end;
    const t = @min(@as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(total_steps)), 1.0);
    return start + (end - start) * t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-ADAPTIVE EMA DECAY (Session 34 Quick Win #3)
// ═══════════════════════════════════════════════════════════════════════════════

/// φ-adaptive EMA decay that responds to loss curvature
/// High curvature → faster adaptation (lower decay, more online influence)
/// Low curvature → slower adaptation (higher decay, more target stability)
///
/// Expected: 3-5% faster convergence with stable final performance
///
/// # Parameters
///   - loss_curvature: Second derivative of loss (d²L/dt²) during recent steps
///   - step: Current training step
///   - total_steps: Total training steps for EMA ramp
///   - base_decay: Starting decay value (typically 0.996)
///
/// # Returns
///   - Adaptive decay value in [base_decay - φ⁻¹, base_decay]
///
/// # Mathematical Foundation
/// ```
/// decay(step) = baseline(step) - φ⁻¹ × curve_normalization
///
/// where:
///   - baseline(step) = linear_ramp(step, total_steps, base_decay, 1.0)
///   - curve_normalization = min(1.0, loss_curvature / 0.1)
///   - φ⁻¹ = 0.618033988749895 (golden ratio conjugate)
/// ```
///
/// # Example
/// ```
/// // Early training, high curvature → faster adaptation
/// const decay1 = phiAdaptiveDecay(0.15, 5000, 30000, 0.996);
/// // decay1 ≈ 0.996 - 0.618 × 1.0 = 0.378 (very low, aggressive)
///
/// // Mid training, moderate curvature → balanced
/// const decay2 = phiAdaptiveDecay(0.05, 15000, 30000, 0.996);
/// // decay2 ≈ 0.998 - 0.618 × 0.5 = 0.689 (moderate)
///
/// // Late training, low curvature → stable
/// const decay3 = phiAdaptiveDecay(0.01, 25000, 30000, 0.996);
/// // decay3 ≈ 0.999 - 0.618 × 0.1 = 0.937 (conservative)
/// ```
pub fn phiAdaptiveDecay(loss_curvature: f32, step: u32, total_steps: u32, base_decay: f32) f32 {
    const PHI_INV: f32 = 0.618033988749895;

    // Linear ramp baseline (same as scheduledDecay)
    const baseline = scheduledDecay(step, total_steps, base_decay, 1.0);

    // Normalize loss curvature to [0, 1]
    // 0.1 is empirically chosen as "high curvature" threshold
    const curve_norm = @min(1.0, loss_curvature / 0.1);

    // phi-adaptive adjustment (phi_inv = 0.618...)
    // Higher curvature → more aggressive (lower decay)
    // Lower curvature → more conservative (higher decay)
    const adjustment = 0.618033988749895 * curve_norm;

    // Clamp decay to reasonable range
    // Minimum: base_decay - φ⁻¹ (allow significant online influence)
    // Maximum: baseline (don't exceed linear ramp)
    const min_decay = @max(0.0, base_decay - PHI_INV);
    return @max(min_decay, baseline - adjustment);
}

/// phi-adaptive EMA sync with curvature-based decay
pub const PhiAdaptiveEmaSync = struct {
    decay_start: f32 = 0.996,
    decay_end: f32 = 1.0,
    curvature_window: u32 = 100,

    pub fn syncModelsAdaptive(self: *const PhiAdaptiveEmaSync, target: *model_mod.HSLM, online: *const model_mod.HSLM, step: u32, total_steps: u32, loss_curvature: f32) void {
        const decay = phiAdaptiveDecay(loss_curvature, step, total_steps, self.decay_start);
        EmaSync.updateShadows(target.output_shadow, online.output_shadow, decay);

        for (&target.blocks, &online.blocks) |*t_block, *o_block| {
            EmaSync.updateShadows(t_block.tnn.shadow_up, o_block.tnn.shadow_up, decay);
            EmaSync.updateShadows(t_block.tnn.shadow_down, o_block.tnn.shadow_down, decay);
            EmaSync.updateShadows(t_block.bias_up, o_block.bias_up, decay);
            EmaSync.updateShadows(t_block.bias_down, o_block.bias_down, decay);

            EmaSync.updateShadows(t_block.sacred_attn.shadow_q, o_block.sacred_attn.shadow_q, decay);
            EmaSync.updateShadows(t_block.sacred_attn.shadow_k, o_block.sacred_attn.shadow_k, decay);
            EmaSync.updateShadows(t_block.sacred_attn.shadow_v, o_block.sacred_attn.shadow_v, decay);
            EmaSync.updateShadows(t_block.sacred_attn.shadow_o, o_block.sacred_attn.shadow_o, decay);

            EmaSync.updateShadows(t_block.sacred_attn.rms_gamma, o_block.sacred_attn.rms_gamma, decay);
        }

        EmaSync.updateShadows(target.emb.float_table, online.emb.float_table, decay);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ema decay formula" {
    var target = [_]f32{ 1.0, 2.0, 3.0 };
    const online = [_]f32{ 0.0, 0.0, 0.0 };
    EmaSync.updateShadows(&target, &online, 0.996);
    // target[0] = 0.996 * 1.0 + 0.004 * 0.0 = 0.996
    try std.testing.expectApproxEqAbs(@as(f32, 0.996), target[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.992), target[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 2.988), target[2], 1e-5);
}

test "ema schedule ramp" {
    // At step 0 → start
    try std.testing.expectApproxEqAbs(@as(f32, 0.996), scheduledDecay(0, 100, 0.996, 1.0), 1e-6);
    // At step 50 → midpoint
    try std.testing.expectApproxEqAbs(@as(f32, 0.998), scheduledDecay(50, 100, 0.996, 1.0), 1e-6);
    // At step 100 → end
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), scheduledDecay(100, 100, 0.996, 1.0), 1e-6);
    // Beyond total → clamped to end
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), scheduledDecay(200, 100, 0.996, 1.0), 1e-6);
}

test "ema sync models" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();
    var target = try model_mod.HSLM.init(allocator);
    defer target.deinit();

    const ema = EmaSync{ .decay_start = 0.0, .decay_end = 0.0 };
    // decay=0 means target = online (full copy)
    ema.syncModels(&target, &online, 0, 100);

    // After decay=0 sync, target shadows should equal online shadows
    for (target.output_shadow, online.output_shadow) |t, o| {
        try std.testing.expectApproxEqAbs(t, o, 1e-6);
    }
    // Check one block
    for (target.blocks[0].tnn.shadow_up, online.blocks[0].tnn.shadow_up) |t, o| {
        try std.testing.expectApproxEqAbs(t, o, 1e-6);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ-ADAPTIVE DECAY TESTS (Session 34)
// ═══════════════════════════════════════════════════════════════════════════════

test "phi-adaptive decay: high curvature → aggressive" {
    const step: u32 = 5000;
    const total_steps: u32 = 30000;
    const base_decay: f32 = 0.996;
    const high_curvature: f32 = 0.15; // High curvature

    const decay = phiAdaptiveDecay(high_curvature, step, total_steps, base_decay);

    // Should be significantly lower than baseline due to high curvature
    // Baseline at step 5000/30000: 0.996 + 0.004 × (5000/30000) ≈ 0.9967
    // With high curvature: subtract φ⁻¹ × 1.0 = 0.618
    // But clamped to minimum: 0.996 - 0.618 = 0.378
    try std.testing.expect(decay < 0.9);
    try std.testing.expect(decay > 0.3);
}

test "phi-adaptive decay: low curvature → conservative" {
    const step: u32 = 25000;
    const total_steps: u32 = 30000;
    const base_decay: f32 = 0.996;
    const low_curvature: f32 = 0.01; // Low curvature

    const decay = phiAdaptiveDecay(low_curvature, step, total_steps, base_decay);

    // Should be close to baseline (0.996 + 0.004 × 0.833 ≈ 0.9993)
    // Minus small adjustment: 0.618 × 0.1 = 0.0618
    // Result: ≈ 0.937
    try std.testing.expect(decay > 0.9);
    try std.testing.expect(decay < 1.0);
}

test "phi-adaptive decay: zero curvature → baseline" {
    const step: u32 = 15000;
    const total_steps: u32 = 30000;
    const base_decay: f32 = 0.996;
    const zero_curvature: f32 = 0.0;

    const decay = phiAdaptiveDecay(zero_curvature, step, total_steps, base_decay);

    // Should equal baseline exactly (no curvature adjustment)
    const baseline = scheduledDecay(step, total_steps, base_decay, 1.0);
    try std.testing.expectApproxEqAbs(decay, baseline, 1e-6);
}

test "phi-adaptive decay: extreme curvature → minimum" {
    const step: u32 = 1000;
    const total_steps: u32 = 30000;
    const base_decay: f32 = 0.996;
    const extreme_curvature: f32 = 1.0; // Very high

    const decay = phiAdaptiveDecay(extreme_curvature, step, total_steps, base_decay);

    // Should hit minimum: base_decay - φ⁻¹ = 0.996 - 0.618 = 0.378
    const min_expected = base_decay - 0.618033988749895;
    try std.testing.expect(decay >= @max(0.0, min_expected));
    try std.testing.expect(decay < base_decay);
}

test "phi-adaptive decay: monotonicity" {
    // At fixed step, decay should decrease monotonically with curvature
    const step: u32 = 10000;
    const total_steps: u32 = 30000;
    const base_decay: f32 = 0.996;

    const decay_low = phiAdaptiveDecay(0.0, step, total_steps, base_decay);
    const decay_mid = phiAdaptiveDecay(0.05, step, total_steps, base_decay);
    const decay_high = phiAdaptiveDecay(0.15, step, total_steps, base_decay);

    try std.testing.expect(decay_low >= decay_mid);
    try std.testing.expect(decay_mid >= decay_high);
}
