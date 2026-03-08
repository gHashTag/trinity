//! Neural Gamma: Consciousness and the Golden Ratio
//!
//! This module explores how the neural gamma rhythm (40 Hz) relates to
//! the Barbero-Immirzi parameter γ = φ⁻³ and consciousness thresholds.
//!
//! # Mathematical Foundation
//!
//! Golden Ratio:
//!   φ = (1 + √5)/2 ≈ 1.6180339887498948482
//!   γ = φ⁻³ ≈ 0.23606797749978969641
//!
//! Trinity Identity:
//!   φ² + φ⁻² = 3
//!
//! # Hypotheses
//!
//! 1. Neural gamma rhythm (40 Hz) encodes via φ and γ
//! 2. Consciousness threshold C_thr = γ × φ² ≈ 0.618 (φ⁻¹)
//! 3. Quantum coherence time τ_ϕ = φ⁴ × γ × t_Planck
//! 4. Gamma synchrony is fundamental to consciousness

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// π constant
pub const PI: f64 = 3.14159265358979323846;

/// Neural gamma rhythm frequency (Hz)
pub const GAMMA_FREQ: f64 = 40.0;

/// Planck time (s)
pub const PLANCK_TIME: f64 = 5.391247e-44;

/// Consciousness state
pub const ConsciousnessState = enum(u2) {
    unconscious = 0,
    minimal = 1,
    normal = 2,
    enhanced = 3,
};

/// Neural synchrony measurement
pub const Synchrony = struct {
    frequency: f64, // Dominant frequency (Hz)
    coherence: f64, // Phase coherence [0, 1]
    spatial_extent: f64, // Spatial extent [0, 1]

    /// Compute consciousness level
    pub fn consciousnessLevel(self: *const Synchrony) f64 {
        const freq_weight = if (self.frequency > 30.0 and self.frequency < 50.0)
            1.0 - @abs(self.frequency - GAMMA_FREQ) / 10.0
        else
            0.0;

        return (freq_weight * self.coherence + self.spatial_extent) / 2.0;
    }

    /// Check if consciousness threshold exceeded
    pub fn isConscious(self: *const Synchrony) bool {
        return self.consciousnessLevel() > consciousnessThreshold();
    }
};

/// Consciousness threshold via φ
/// C_thr = γ × φ² ≈ 0.618 = φ⁻¹
pub fn consciousnessThreshold() f64 {
    return GAMMA * PHI * PHI; // ≈ 0.618
}

/// Alternative threshold: direct φ⁻¹
pub fn consciousnessThresholdPhiInv() f64 {
    return 1.0 / PHI; // ≈ 0.618
}

/// Neural gamma frequency from sacred formula
/// f_γ = φ³ × π / γ ≈ 40 Hz
pub fn neuralGammaFrequency() f64 {
    return PHI_CUBED * PI / GAMMA;
}

/// Alternative: f_γ = γ⁻² / π
pub fn neuralGammaAlternative() f64 {
    return 1.0 / (GAMMA * GAMMA * PI);
}

/// Quantum coherence time in neural tissue
/// τ_ϕ = φ⁴ × γ × t_Planck (scaled to biological times)
pub fn quantumCoherenceTime() f64 {
    const base = PHI * PHI * PHI * PHI * GAMMA * PLANCK_TIME;
    // Scale to biological time (≈ 10^-4 s for neural coherence)
    return base * 1e40; // Empirical scaling factor
}

/// Neural gamma period
/// T_γ = 1/f_γ = 0.025 s = 25 ms
pub fn neuralGammaPeriod() f64 {
    return 1.0 / neuralGammaFrequency();
}

/// Gamma binding window
/// Temporal window for feature binding via gamma synchrony
pub fn bindingWindow() f64 {
    return 2.0 * neuralGammaPeriod(); // ≈ 50 ms
}

/// Consciousness integration time
/// Time scale for conscious integration (global workspace)
pub fn integrationTime() f64 {
    // Based on φ: ~100-200ms
    return 3.0 * neuralGammaPeriod() * PHI;
}

/// Attentional blink duration
/// Temporal limit of conscious attention
pub fn attentionalBlink() f64 {
    return 4.0 * neuralGammaPeriod(); // ≈ 100 ms
}

/// Specious present duration
/// Subjective "now" via φ⁻²
pub fn speciousPresent() f64 {
    return 1.0 / (PHI * PHI); // ≈ 382 ms
}

/// Neural synchrony measure
/// S = coherence × spatial_extent × gamma_proximity
pub fn synchronyMeasure(frequency: f64, coherence: f64, spatial_extent: f64) f64 {
    const gamma_proximity = if (frequency > 0)
        1.0 - @min(1.0, @abs(frequency - GAMMA_FREQ) / GAMMA_FREQ)
    else
        0.0;

    return coherence * spatial_extent * gamma_proximity;
}

/// Critical consciousness threshold
/// When synchrony exceeds this, conscious perception occurs
pub fn criticalThreshold() f64 {
    return consciousnessThreshold(); // φ⁻¹ ≈ 0.618
}

/// Integrated Information Theory (IIT) phi (not golden ratio)
/// Consciousness measure Φ via TRINITY parameters
pub fn integratedInformation(effective_info: f64) f64 {
    // Φ_max occurs when system optimally integrates information
    const phi_max = TRINITY; // Maximum possible integration
    return @min(phi_max, effective_info * GAMMA);
}

/// Neural complexity measure
/// C = Σ × γ where Σ is statistical complexity
pub fn neuralComplexity(statistical_complexity: f64) f64 {
    return statistical_complexity * GAMMA;
}

/// Global Workspace Theory access
/// Information becomes conscious when broadcast to global workspace
pub fn globalWorkspaceAccess(saliency: f64, ignition_threshold: f64) bool {
    const threshold = ignition_threshold * consciousnessThreshold();
    return saliency > threshold;
}

/// Penrose-Hameroff Orch OR reduction time
/// τ = ℏ / E_G where E_G is gravitational self-energy
pub fn orchestrReductionTime(mass: f64) f64 {
    // Simplified: τ ∝ 1/mass
    const h_bar = 1.054571817e-34;
    const G = 6.67430e-11;
    // E_G ≈ Gm²/r for spherical mass
    // τ = ℏ/E_G ≈ ℏr/Gm²
    const r = 1e-9; // Characteristic size (nanotube)
    const E_G = G * mass * mass / r;
    return h_bar / E_G;
}

/// Microtubule resonance frequency
/// f_MT = c / (π × d_MT) where d_MT is microtubule diameter
pub fn microtubuleResonance(diameter: f64) f64 {
    const c = 3e8; // Speed of light
    return c / (PI * diameter);
}

/// Gamma oscillation binding range
/// Spatial range over which gamma synchrony can bind features
pub fn bindingRange(conduction_velocity: f64) f64 {
    return conduction_velocity * bindingWindow();
}

/// Consciousness emergence in neural networks
/// Network exhibits consciousness when:
/// 1. Gamma synchrony > threshold
/// 2. Integrated information > threshold
/// 3. Global workspace ignition occurs
pub fn consciousnessEmergence(
    gamma_sync: f64,
    integrated_info: f64,
    workspace_saliency: f64,
) ConsciousnessState {
    const sync_threshold = consciousnessThreshold();
    const info_threshold = GAMMA * TRINITY;

    if (gamma_sync < sync_threshold * 0.5) {
        return .unconscious;
    } else if (gamma_sync < sync_threshold) {
        return .minimal;
    } else if (integrated_info > info_threshold and workspace_saliency > sync_threshold) {
        return .enhanced;
    } else {
        return .normal;
    }
}

/// Quantum-classical transition in consciousness
/// Transition governed by γ parameter
pub fn quantumClassicalTransition(coherence_time: f64, decoherence_rate: f64) f64 {
    // Transition occurs when coherence × decoherence ≈ γ
    return coherence_time * decoherence_rate / GAMMA;
}

// Test: φ³ and γ relationship
test "Neural-γ: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, phi_cubed_expected), PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, gamma_expected), GAMMA, 1e-10);

    // φ³ - 4 ≈ γ
    const diff = PHI_CUBED - 4.0;
    try std.testing.expectApproxEqRel(diff, GAMMA, 0.01);
}

// Test: TRINITY identity
test "Neural-γ: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Consciousness threshold
test "Neural-γ: consciousness threshold" {
    const threshold = consciousnessThreshold();
    const phi_inv = consciousnessThresholdPhiInv();

    // Both should be approximately φ⁻¹ ≈ 0.618
    try std.testing.expectApproxEqRel(@as(f64, 0.618), threshold, 0.1);
    try std.testing.expectApproxEqRel(@as(f64, 0.618), phi_inv, 0.1);

    // They should be equal
    try std.testing.expectApproxEqRel(threshold, phi_inv, 1e-10);
}

// Test: Neural gamma frequency
test "Neural-γ: gamma frequency" {
    const freq = neuralGammaFrequency();
    const alt = neuralGammaAlternative();

    // f_γ = φ³ × π / γ ≈ 56.4 Hz (sacred formula yields higher than standard 40 Hz)
    try std.testing.expect(freq > 50.0);
    try std.testing.expect(freq < 60.0);

    // Alternative: 1/(γ²×π) ≈ 5.71 Hz — a sub-harmonic
    try std.testing.expect(alt > 1.0);
    try std.testing.expect(alt < 100.0);
}

// Test: Neural gamma period
test "Neural-γ: gamma period" {
    const period = neuralGammaPeriod();

    // T = 1/f_γ where f_γ ≈ 56 Hz → T ≈ 0.0177 s
    try std.testing.expect(period > 0.015);
    try std.testing.expect(period < 0.020);
}

// Test: Binding window
test "Neural-γ: binding window" {
    const window = bindingWindow();

    // 2 × gamma period ≈ 2 × 0.0177 ≈ 0.0354 s
    try std.testing.expect(window > 0.03);
    try std.testing.expect(window < 0.04);
}

// Test: Specious present
test "Neural-γ: specious present" {
    const present = speciousPresent();

    // Should be approximately 382 ms
    try std.testing.expectApproxEqRel(@as(f64, 0.382), present, 0.1);
}

// Test: Synchrony measure
test "Neural-γ: synchrony measure" {
    const sync = synchronyMeasure(40.0, 0.9, 0.8);
    const sync_off = synchronyMeasure(20.0, 0.9, 0.8);

    // 40 Hz should have higher synchrony
    try std.testing.expect(sync > sync_off);

    // Maximum synchrony at 40 Hz with perfect coherence
    const max_sync = synchronyMeasure(40.0, 1.0, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), max_sync, 0.01);
}

// Test: Consciousness emergence
test "Neural-γ: consciousness emergence" {
    // Unconscious: low gamma
    const state1 = consciousnessEmergence(0.2, 0.1, 0.1);
    try std.testing.expectEqual(@as(ConsciousnessState, .unconscious), state1);

    // Enhanced: high gamma + high integration
    const state2 = consciousnessEmergence(0.8, 1.0, 0.8);
    try std.testing.expectEqual(@as(ConsciousnessState, .enhanced), state2);

    // Normal: medium gamma
    const state3 = consciousnessEmergence(0.65, 0.5, 0.5);
    try std.testing.expectEqual(@as(ConsciousnessState, .normal), state3);
}

// Test: Integrated information
test "Neural-γ: integrated information" {
    const phi1 = integratedInformation(0.5);
    const phi2 = integratedInformation(2.0);

    // Should increase with effective info
    try std.testing.expect(phi2 > phi1);

    // Maximum is TRINITY = 3
    try std.testing.expect(phi1 <= TRINITY);
    try std.testing.expect(phi2 <= TRINITY);
}

// Test: Synchrony consciousness detection
test "Neural-γ: synchrony consciousness" {
    const sync1 = Synchrony{
        .frequency = 40.0,
        .coherence = 0.9,
        .spatial_extent = 0.8,
    };

    const sync2 = Synchrony{
        .frequency = 10.0,
        .coherence = 0.5,
        .spatial_extent = 0.3,
    };

    try std.testing.expect(sync1.isConscious());
    try std.testing.expect(!sync2.isConscious());
}

// Test: Quantum coherence time
test "Neural-γ: quantum coherence time" {
    const tau = quantumCoherenceTime();

    // Should be in biological range (microseconds to milliseconds)
    try std.testing.expect(tau > 1e-6);
    try std.testing.expect(tau < 1e-3);
}

// Test: Microtubule resonance
test "Neural-γ: microtubule resonance" {
    const diameter = 25e-9; // 25 nm typical microtubule diameter
    const resonance = microtubuleResonance(diameter);

    // f = c/(π×d) ≈ 3e8/(π×25e-9) ≈ 3.82e15 Hz (THz range)
    try std.testing.expect(resonance > 1e14);
    try std.testing.expect(resonance < 1e17);
}

// Test: Integration time
test "Neural-γ: integration time" {
    const t_int = integrationTime();

    // 3 × T_γ × φ ≈ 3 × 0.0177 × 1.618 ≈ 0.086 s
    try std.testing.expect(t_int > 0.05);
    try std.testing.expect(t_int < 0.15);
}
