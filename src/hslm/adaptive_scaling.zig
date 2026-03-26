// HSLM — Adaptive Sacred Scaling
// Implements dynamic attention scaling based on training progress
// Interpolates between sacred scale (early) and standard scale (late)

const std = @import("std");
const math = std.math;
const constants = @import("constants.zig");

const HEAD_DIM = constants.HEAD_DIM; // 81
const PHI: f64 = constants.PHI;
const SACRED_GAMMA: f64 = constants.SACRED_GAMMA; // φ⁻³ ≈ 0.2360679

// Base scales
const SACRED_BASE: f64 = 1.0 / math.pow(f64, @as(f64, HEAD_DIM), SACRED_GAMMA); // ≈ 0.354
const STANDARD_SCALE: f64 = 1.0 / math.sqrt(@as(f64, HEAD_DIM)); // ≈ 0.111

/// Adaptive sacred scaling configuration
pub const AdaptiveConfig = struct {
    /// Use adaptive scaling (vs fixed)
    enabled: bool = false,

    /// Progress point to start transitioning from sacred to standard
    /// 0.0 = immediate transition, 1.0 = never transition
    transition_start: f32 = 0.5,

    /// Shape of transition curve
    /// "cosine" = smooth cosine interpolation
    /// "linear" = linear interpolation
    /// "exponential" = exponential decay
    curve_shape: CurveShape = .cosine,
};

pub const CurveShape = enum {
    cosine,
    linear,
    exponential,
};

/// Compute adaptive sacred attention scale based on training progress
///
/// Arguments:
///   - step: Current training step
///   - total_steps: Total training steps
///   - config: Adaptive scaling configuration
///
/// Returns: Scale factor for attention scores
///
/// The scale interpolates between:
///   - Early training: SACRED_BASE (0.354) — stronger gradients
///   - Late training: STANDARD_SCALE (0.111) — stable convergence
///
pub fn adaptiveSacredScale(step: u32, total_steps: u32, config: AdaptiveConfig) f32 {
    if (!config.enabled) {
        // Fixed sacred scale (original behavior)
        return @floatCast(SACRED_BASE);
    }

    if (total_steps == 0) return @floatCast(SACRED_BASE);

    const progress = @min(1.0, @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(total_steps)));

    // Compute interpolation factor based on curve shape
    const factor = switch (config.curve_shape) {
        .cosine => cosineFactor(progress, config.transition_start),
        .linear => linearFactor(progress, config.transition_start),
        .exponential => expFactor(progress, config.transition_start),
    };

    // Interpolate between sacred and standard scale
    const scale = SACRED_BASE * factor + STANDARD_SCALE * (1.0 - factor);

    return @floatCast(scale);
}

/// Cosine interpolation factor
/// Follows cosine learning rate schedule pattern
fn cosineFactor(progress: f64, transition_start: f64) f64 {
    if (progress < transition_start) {
        return 1.0; // Pure sacred scale before transition
    }

    // Map [transition_start, 1.0] to [0, π]
    const adjusted_progress = (progress - transition_start) / (1.0 - transition_start);
    const factor = 0.5 * (1.0 + math.cos(math.pi * adjusted_progress));

    return factor;
}

/// Linear interpolation factor
fn linearFactor(progress: f64, transition_start: f64) f64 {
    if (progress < transition_start) {
        return 1.0;
    }

    return 1.0 - (progress - transition_start) / (1.0 - transition_start);
}

/// Exponential decay factor
fn expFactor(progress: f64, transition_start: f64) f64 {
    if (progress < transition_start) {
        return 1.0;
    }

    // Decay from 1.0 to 0.0 with rate = -ln(0.1) for 90% decay at end
    const decay_rate = 2.302585; // -ln(0.1)
    const adjusted_progress = (progress - transition_start) / (1.0 - transition_start);

    return math.exp(-decay_rate * adjusted_progress);
}

/// Layer-wise sacred scaling (depth-dependent)
///
/// Lower layers use stronger sacred scaling for better feature extraction
/// Upper layers use standard scaling for semantic abstraction
///
/// Arguments:
///   - layer_idx: Layer index (0 to num_layers-1)
///   - num_layers: Total number of layers
///   - step: Current training step
///   - total_steps: Total training steps
///   - config: Adaptive scaling configuration
///
pub fn layerSacredScale(layer_idx: usize, num_layers: usize, step: u32, total_steps: u32, config: AdaptiveConfig) f32 {
    const base_scale = adaptiveSacredScale(step, total_steps, config);

    if (num_layers <= 1) return base_scale;

    // Layer-dependent modifier
    // Layer 0: 1.5× base scale
    // Layer N: 1.0× base scale
    const layer_factor = 1.0 + 0.5 * (1.0 - @as(f64, @floatFromInt(layer_idx)) /
        @as(f64, @floatFromInt(num_layers - 1)));

    return @floatCast(@as(f64, base_scale) * layer_factor);
}

/// Get scale statistics for logging/analysis
pub const ScaleStats = struct {
    current: f32,
    base_sacred: f32,
    standard: f32,
    factor: f32,
    progress: f32,
};

pub fn getScaleStats(step: u32, total_steps: u32, config: AdaptiveConfig) ScaleStats {
    const current = adaptiveSacredScale(step, total_steps, config);
    const progress = if (total_steps > 0)
        @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(total_steps))
    else
        0.0;

    const factor = switch (config.curve_shape) {
        .cosine => cosineFactor(progress, config.transition_start),
        .linear => linearFactor(progress, config.transition_start),
        .exponential => expFactor(progress, config.transition_start),
    };

    return ScaleStats{
        .current = current,
        .base_sacred = @floatCast(SACRED_BASE),
        .standard = @floatCast(STANDARD_SCALE),
        .factor = @floatCast(factor),
        .progress = progress,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "adaptive scale: disabled returns sacred base" {
    const config = AdaptiveConfig{ .enabled = false };
    const scale = adaptiveSacredScale(1000, 30000, config);

    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(SACRED_BASE)), scale, 1e-6);
}

test "adaptive scale: early training uses sacred" {
    const config = AdaptiveConfig{ .enabled = true, .transition_start = 0.5 };
    // At step 0 of 30000, progress = 0 < 0.5
    const scale = adaptiveSacredScale(0, 30000, config);

    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(SACRED_BASE)), scale, 1e-6);
}

test "adaptive scale: late training approaches standard" {
    const config = AdaptiveConfig{ .enabled = true, .transition_start = 0.5 };
    // At final step, should be close to standard
    const scale = adaptiveSacredScale(30000, 30000, config);

    // Should be close to standard scale (within 1%)
    try std.testing.expectApproxEqAbs(@as(f32, @floatCast(STANDARD_SCALE)), scale, @as(f32, @floatCast(STANDARD_SCALE)) * 0.01);
}

test "adaptive scale: mid training interpolates" {
    const config = AdaptiveConfig{ .enabled = true, .transition_start = 0.5, .curve_shape = .cosine };
    // At 75% progress (22500/30000), should be between sacred and standard
    const scale = adaptiveSacredScale(22500, 30000, config);

    try std.testing.expect(scale < @as(f32, @floatCast(SACRED_BASE)));
    try std.testing.expect(scale > @as(f32, @floatCast(STANDARD_SCALE)));
}

test "layer scale: first layer amplified" {
    const config = AdaptiveConfig{ .enabled = false };
    const scale_0 = layerSacredScale(0, 9, 1000, 30000, config);
    const scale_8 = layerSacredScale(8, 9, 1000, 30000, config);

    // Layer 0 should have 1.5× scale of layer 8
    try std.testing.expect(scale_0 > scale_8);
    try std.testing.expectApproxEqAbs(scale_0, scale_8 * 1.5, 0.01);
}

test "scale stats contain all fields" {
    const config = AdaptiveConfig{ .enabled = true, .transition_start = 0.5 };
    const stats = getScaleStats(15000, 30000, config);

    try std.testing.expect(stats.progress > 0.4);
    try std.testing.expect(stats.progress < 0.6);
    try std.testing.expect(stats.current > 0);
    try std.testing.expect(stats.factor > 0);
    try std.testing.expect(stats.factor <= 1.0);
}

test "linear curve shape" {
    const config = AdaptiveConfig{ .enabled = true, .transition_start = 0.0, .curve_shape = .linear };
    // At 50% progress, should be exactly midpoint
    const scale = adaptiveSacredScale(15000, 30000, config);
    const expected: f32 = @floatCast((SACRED_BASE + STANDARD_SCALE) / 2.0);

    try std.testing.expectApproxEqAbs(expected, scale, 1e-5);
}
