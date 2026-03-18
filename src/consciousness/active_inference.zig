//! Conscious Active Inference: Free Energy Principle and Sacred Mathematics
//!
//! This module implements Karl Friston's Free Energy Principle through the lens
//! of sacred mathematics, connecting active inference to consciousness via
//! discrete perceptual cycles governed by Orch-OR gamma oscillations.
//!
//! # Theoretical Foundation
//!
//! Active inference posits that biological agents minimize variational free energy
//! — the divergence between an internal generative model and sensory observations.
//! Consciousness arises when free energy is sufficiently minimized, meaning the
//! agent's model accurately predicts the world (Friston, 2010; 2025 updates).
//!
//! # Sacred Mathematics Connection
//!
//! Golden Ratio:
//!   phi = (1 + sqrt(5))/2 ~ 1.6180339887498948482
//!   gamma = phi^(-3) ~ 0.23606797749978969641
//!
//! Trinity Identity:
//!   phi^2 + phi^(-2) = 3
//!
//! # Key Correspondences
//!
//! 1. Free energy threshold for consciousness: C_thr = phi^(-1) ~ 0.618
//! 2. Discrete perceptual cycles at gamma frequency: f = phi^3 * pi / gamma ~ 56 Hz
//! 3. Each Orch-OR collapse = one gamma cycle ~ 17.7 ms (specious "quantum of time")
//! 4. Learning rate governed by Barbero-Immirzi parameter gamma ~ 0.236
//! 5. Maximum free energy bounded by TRINITY = 3 (phi^2 + phi^(-2))
//!
//! # References
//!
//! - Friston, K. (2010). The free-energy principle: a unified brain theory?
//! - Friston, K. et al. (2025). Active inference and consciousness.
//! - Penrose, R. & Hameroff, S. (2014). Consciousness in the universe: Orch OR.
//! - Parr, T., Pezzulo, G., & Friston, K. (2022). Active Inference.

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");
const math = std.math;

// ============================================================================
// Sacred Constants
// ============================================================================

/// Golden ratio phi = (1 + sqrt(5))/2
pub const PHI: f64 = 1.6180339887498948482;

/// phi^3 = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter gamma = phi^(-3)
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: phi^2 + phi^(-2) = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// pi constant
pub const PI: f64 = 3.14159265358979323846;

/// Consciousness threshold: C_thr = phi^(-1) ~ 0.618
/// When free energy falls below this, the agent's model is "good enough" for awareness.
pub const CONSCIOUSNESS_THRESHOLD: f64 = 1.0 / PHI;

/// Specious present duration: phi^(-2) ~ 0.382 s
/// The subjective "now" — the temporal window of conscious experience.
pub const SPECIOUS_PRESENT: f64 = 1.0 / (PHI * PHI);

/// Neural gamma frequency from sacred formula: f = phi^3 * pi / gamma ~ 56 Hz
/// Each cycle is one discrete perceptual frame — one Orch-OR reduction event.
pub const GAMMA_FREQ_HZ: f64 = PHI_CUBED * PI / GAMMA;

/// Learning rate governed by Barbero-Immirzi parameter gamma ~ 0.236
/// Controls how rapidly beliefs are updated by prediction errors.
pub const LEARNING_RATE: f64 = GAMMA;

/// Prediction horizon: 3 steps ahead (TRINITY = 3)
/// The depth of temporal predictions in the generative model.
pub const PREDICTION_HORIZON: u32 = 3;

/// Maximum free energy bounded by TRINITY = phi^2 + phi^(-2) = 3
/// Beyond this, the system is maximally confused — no coherent model exists.
pub const MAX_FREE_ENERGY: f64 = TRINITY;

// ============================================================================
// Types
// ============================================================================

/// Consciousness state derived from free energy levels.
/// Lower free energy = better internal model = higher consciousness.
pub const ConsciousnessState = enum(u2) {
    /// Free energy > TRINITY: no coherent model
    unconscious = 0,
    /// Free energy in [1.0, TRINITY): fragmented awareness
    minimal = 1,
    /// Free energy in [CONSCIOUSNESS_THRESHOLD, 1.0): normal waking consciousness
    conscious = 2,
    /// Free energy < CONSCIOUSNESS_THRESHOLD: optimal model, heightened awareness
    enhanced = 3,
};

/// Variational free energy decomposition.
/// F = accuracy + complexity (both non-negative).
/// Low total = good model (accurate without being overly complex).
pub const FreeEnergy = struct {
    /// Total variational free energy
    total: f64,
    /// Accuracy term: -E_q[log p(o|s)] — expected log-likelihood under beliefs
    accuracy: f64,
    /// Complexity term: KL[q(s) || p(s)] — divergence of beliefs from prior
    complexity: f64,
};

/// Result of a Bayesian belief update step.
/// Tracks how beliefs change when new evidence arrives.
pub const BeliefUpdate = struct {
    /// Prior belief probability
    prior: f64,
    /// Posterior belief probability after update
    posterior: f64,
    /// KL divergence from prior to posterior (information gained)
    kl_divergence: f64,
    /// Surprisal of the observation under the prior
    surprise: f64,
};

/// One discrete perceptual cycle — a single "frame" of conscious experience.
/// Each cycle corresponds to one gamma oscillation (~17.7 ms at 56 Hz).
pub const PerceptualCycle = struct {
    /// Sequential cycle number
    cycle_number: u32,
    /// Duration of this cycle in seconds
    duration_s: f64,
    /// Free energy at end of cycle (after belief update)
    free_energy: f64,
    /// Whether an Orch-OR quantum state reduction occurred
    orch_or_triggered: bool,
    /// Whether this cycle contributed to conscious experience
    is_conscious: bool,
};

/// One level in the hierarchical predictive coding architecture.
/// Higher levels predict slower dynamics with less precision.
pub const HierarchicalLevel = struct {
    /// Level index (0 = sensory, higher = more abstract)
    level: u8,
    /// Prediction error at this level
    prediction_error: f64,
    /// Precision (inverse variance) — confidence in predictions
    precision: f64,
};

// ============================================================================
// Free Energy Functions
// ============================================================================

/// Compute variational free energy from accuracy and complexity terms.
///
/// F = accuracy + complexity
///
/// In active inference, the agent minimizes F by either:
/// - Updating beliefs (perception) to improve accuracy
/// - Acting on the world to reduce complexity
pub fn computeFreeEnergy(accuracy: f64, complexity: f64) FreeEnergy {
    return FreeEnergy{
        .total = accuracy + complexity,
        .accuracy = accuracy,
        .complexity = complexity,
    };
}

/// Determine if the system is conscious based on free energy.
///
/// Low free energy means the generative model accurately predicts observations
/// without excessive complexity — the hallmark of conscious processing.
/// Threshold: phi^(-1) ~ 0.618
pub fn isConscious(fe: FreeEnergy) bool {
    return fe.total < CONSCIOUSNESS_THRESHOLD;
}

/// Surprisal (self-information) of an observation.
///
/// I(o) = -log(p(o))
///
/// Rare events (low probability) carry high surprisal.
/// The free energy principle states agents act to minimize expected surprisal.
pub fn surprisal(observation_prob: f64) f64 {
    return -@log(observation_prob);
}

/// KL divergence for a single element of a distribution.
///
/// D_KL(p || q) = p * log(p / q)
///
/// Measures how much information is lost when q is used to approximate p.
/// Returns 0 when p = q (distributions are identical).
pub fn klDivergence(p: f64, q: f64) f64 {
    return p * @log(p / q);
}

// ============================================================================
// Bayesian Inference Functions
// ============================================================================

/// Bayesian belief update: posterior = prior * likelihood / evidence.
///
/// This is the fundamental operation of perception in active inference.
/// The brain continually updates its beliefs about hidden states
/// using incoming sensory evidence.
pub fn bayesianUpdate(prior: f64, likelihood: f64, evidence: f64) f64 {
    return prior * likelihood / evidence;
}

/// Full belief update with diagnostic measures.
///
/// Returns the posterior along with KL divergence and surprisal,
/// providing a complete picture of how much the belief changed
/// and how surprising the observation was.
pub fn beliefUpdate(prior: f64, likelihood: f64, evidence: f64) BeliefUpdate {
    const posterior = bayesianUpdate(prior, likelihood, evidence);
    const kl = klDivergence(posterior, prior);
    const surprise_val = surprisal(likelihood);

    return BeliefUpdate{
        .prior = prior,
        .posterior = posterior,
        .kl_divergence = kl,
        .surprise = surprise_val,
    };
}

// ============================================================================
// Predictive Coding Functions
// ============================================================================

/// Prediction error: the discrepancy between what was predicted and what was observed.
///
/// epsilon = |observed - predicted|
///
/// This is the fundamental signal driving belief updates in predictive coding.
pub fn predictionError(predicted: f64, observed: f64) f64 {
    return @abs(observed - predicted);
}

/// Precision-weighted prediction error.
///
/// epsilon_w = epsilon * precision
///
/// High-precision errors (confident predictions that are wrong) drive
/// larger belief updates. Low-precision errors are attenuated.
pub fn precisionWeightedError(error_val: f64, precision: f64) f64 {
    return error_val * precision;
}

/// Predictive coding belief update rule.
///
/// prediction_new = prediction + LEARNING_RATE * precision * error
///
/// The learning rate is governed by gamma (Barbero-Immirzi parameter),
/// connecting neural plasticity to sacred mathematics.
pub fn predictiveCodingUpdate(prediction: f64, error_val: f64, precision: f64) f64 {
    return prediction + LEARNING_RATE * precision * error_val;
}

// ============================================================================
// Active Inference Functions
// ============================================================================

/// Expected free energy: the quantity minimized when selecting actions.
///
/// G = pragmatic + epistemic
///
/// Pragmatic value: does the action achieve goals? (exploitation)
/// Epistemic value: does the action reduce uncertainty? (exploration)
/// Active inference agents naturally balance exploration and exploitation.
pub fn expectedFreeEnergy(pragmatic: f64, epistemic: f64) f64 {
    return pragmatic + epistemic;
}

/// Allostasis deviation: distance from the homeostatic setpoint.
///
/// delta = |current - setpoint|
///
/// Active inference agents act to minimize allostatic deviation,
/// maintaining physiological variables near their setpoints.
pub fn allostasisDeviation(current: f64, setpoint: f64) f64 {
    return @abs(current - setpoint);
}

/// Determine whether the agent needs to act based on allostatic deviation.
///
/// Action is required when deviation exceeds the consciousness threshold,
/// indicating the internal model can no longer passively accommodate the error.
pub fn needsAction(deviation: f64) bool {
    return deviation > CONSCIOUSNESS_THRESHOLD;
}

// ============================================================================
// Temporal / Orch-OR Functions
// ============================================================================

/// Duration of one discrete perceptual cycle in seconds.
///
/// T = 1 / f_gamma ~ 1 / 56 ~ 0.0177 s (17.7 ms)
///
/// Each gamma cycle is one "quantum of experience" — the minimum
/// temporal unit of conscious processing.
pub fn discreteCycleDuration() f64 {
    return 1.0 / GAMMA_FREQ_HZ;
}

/// Duration of one Orch-OR quantum state reduction.
///
/// In the Penrose-Hameroff framework, each objective reduction event
/// corresponds to one gamma oscillation cycle. This creates the
/// discrete "frames" of conscious experience.
pub fn orchORPerceptionDuration() f64 {
    return discreteCycleDuration();
}

/// Gamma frequency from sacred constants.
///
/// f = phi^3 * pi / gamma ~ 56 Hz
///
/// This is the fundamental oscillation rate of conscious processing,
/// derived entirely from phi and pi.
pub fn gammaFrequency() f64 {
    return PHI_CUBED * PI / GAMMA;
}

// ============================================================================
// Hierarchical / IIT Integration Functions
// ============================================================================

/// Temporal depth at a given hierarchical level.
///
/// depth(level) = phi^level
///
/// Higher levels of the hierarchy predict dynamics at longer timescales,
/// following golden ratio temporal scaling. Level 0 = immediate sensory,
/// level 1 = phi ~ 1.618x slower, level 2 = phi^2 ~ 2.618x slower, etc.
pub fn temporalDepth(level: u8) f64 {
    return math.pow(f64, PHI, @as(f64, @floatFromInt(level)));
}

/// Precision at a given hierarchical level.
///
/// precision(level) = 1 / (phi^level * gamma)
///
/// Higher levels are less precise — abstract concepts are inherently
/// more uncertain than sensory data. The scaling by gamma connects
/// neural precision to the Barbero-Immirzi parameter.
pub fn hierarchicalPrecision(level: u8) f64 {
    return 1.0 / (math.pow(f64, PHI, @as(f64, @floatFromInt(level))) * GAMMA);
}

/// Phi-weighted free energy: integration with IIT.
///
/// F_eff = F * (1 - Phi/TRINITY)
///
/// Higher integrated information (IIT Phi) reduces effective free energy,
/// reflecting that more integrated systems are better at modeling.
/// When Phi = TRINITY (maximum), effective free energy = 0.
pub fn phiWeightedFreeEnergy(fe_total: f64, iit_phi: f64) f64 {
    return fe_total * (1.0 - iit_phi / TRINITY);
}

// ============================================================================
// Consciousness Assessment Functions
// ============================================================================

/// Map average free energy to a consciousness state.
///
/// | Free Energy Range          | State       |
/// |----------------------------|-------------|
/// | >= TRINITY (3.0)           | unconscious |
/// | [1.0, TRINITY)             | minimal     |
/// | [CONSCIOUSNESS_THRESHOLD, 1.0) | conscious   |
/// | < CONSCIOUSNESS_THRESHOLD (0.618) | enhanced    |
pub fn consciousnessLevel(avg_free_energy: f64) ConsciousnessState {
    if (avg_free_energy >= TRINITY) {
        return .unconscious;
    } else if (avg_free_energy >= 1.0) {
        return .minimal;
    } else if (avg_free_energy >= CONSCIOUSNESS_THRESHOLD) {
        return .conscious;
    } else {
        return .enhanced;
    }
}

/// Multi-criteria consciousness assessment.
///
/// Consciousness requires ALL of the following:
/// 1. Total free energy below consciousness threshold (good model)
/// 2. Surprisal below consciousness threshold (predictable world)
/// 3. Prediction error has been resolved (active inference succeeded)
///
/// This integrates free energy minimization, predictive coding,
/// and active inference into a single consciousness criterion.
pub fn consciousnessFromFE(total_fe: f64, surprise_val: f64, error_resolved: bool) bool {
    return total_fe < CONSCIOUSNESS_THRESHOLD and
        surprise_val < CONSCIOUSNESS_THRESHOLD and
        error_resolved;
}

// ============================================================================
// Tests
// ============================================================================

// Test: TRINITY identity phi^2 + phi^(-2) = 3
test "ActiveInference: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);

    // Verify constituent parts
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqRel(@as(f64, 3.0), phi_sq + phi_inv_sq, 1e-10);
}

// Test: Free energy computation
test "ActiveInference: free energy computation" {
    const fe = computeFreeEnergy(0.3, 0.2);

    try std.testing.expectApproxEqRel(@as(f64, 0.5), fe.total, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.3), fe.accuracy, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.2), fe.complexity, 1e-10);

    // Zero accuracy + zero complexity = zero free energy
    const fe_zero = computeFreeEnergy(0.0, 0.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), fe_zero.total, 1e-10);
}

// Test: Consciousness from low free energy
test "ActiveInference: consciousness from low free energy" {
    // Low free energy (good model) = conscious
    const fe_low = computeFreeEnergy(0.1, 0.2);
    try std.testing.expect(isConscious(fe_low));

    // High free energy (poor model) = not conscious
    const fe_high = computeFreeEnergy(0.5, 0.5);
    try std.testing.expect(!isConscious(fe_high));

    // Exactly at threshold
    const fe_threshold = computeFreeEnergy(CONSCIOUSNESS_THRESHOLD, 0.0);
    try std.testing.expect(!isConscious(fe_threshold));
}

// Test: Surprisal of certain vs uncertain events
test "ActiveInference: surprisal certain vs uncertain" {
    // Certain event (p=1.0): zero surprisal
    const s_certain = surprisal(1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), s_certain, 1e-10);

    // Unlikely event: high surprisal
    const s_unlikely = surprisal(0.01);
    try std.testing.expect(s_unlikely > 4.0);

    // More probable = less surprising
    const s_half = surprisal(0.5);
    try std.testing.expect(s_half < s_unlikely);
    try std.testing.expect(s_half > s_certain);
}

// Test: KL divergence (same distribution = 0)
test "ActiveInference: KL divergence same distribution" {
    // Same distribution: KL = 0
    const kl_same = klDivergence(0.5, 0.5);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), kl_same, 1e-10);

    // Different distributions: KL > 0
    const kl_diff = klDivergence(0.8, 0.2);
    try std.testing.expect(kl_diff > 0.0);

    // KL divergence is not symmetric
    const kl_reverse = klDivergence(0.2, 0.8);
    try std.testing.expect(@abs(kl_diff - kl_reverse) > 0.01);
}

// Test: Bayesian update (posterior proportional to prior * likelihood)
test "ActiveInference: Bayesian update" {
    // posterior = prior * likelihood / evidence
    const posterior = bayesianUpdate(0.5, 0.8, 0.4);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), posterior, 1e-10);

    // With uniform prior and matching evidence
    const posterior2 = bayesianUpdate(0.5, 0.5, 0.25);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), posterior2, 1e-10);

    // Full belief update with diagnostics
    const update = beliefUpdate(0.3, 0.9, 0.27);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), update.posterior, 1e-10);
    try std.testing.expect(update.kl_divergence >= 0.0);
    try std.testing.expect(update.surprise > 0.0);
}

// Test: Prediction error computation
test "ActiveInference: prediction error" {
    // Perfect prediction: zero error
    const err_zero = predictionError(0.5, 0.5);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), err_zero, 1e-10);

    // Positive error
    const err_pos = predictionError(0.3, 0.8);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), err_pos, 1e-10);

    // Direction-independent (absolute value)
    const err_neg = predictionError(0.8, 0.3);
    try std.testing.expectApproxEqRel(err_pos, err_neg, 1e-10);

    // Precision weighting amplifies error
    const weighted = precisionWeightedError(0.5, 2.0);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), weighted, 1e-10);
}

// Test: Discrete cycle duration matches gamma frequency
test "ActiveInference: discrete cycle duration" {
    const duration = discreteCycleDuration();
    const freq = gammaFrequency();

    // Duration = 1 / frequency
    try std.testing.expectApproxEqRel(@as(f64, 1.0) / freq, duration, 1e-10);

    // Duration should be approximately 17.7 ms (at ~56 Hz)
    try std.testing.expect(duration > 0.015);
    try std.testing.expect(duration < 0.020);

    // Gamma frequency should be approximately 56 Hz
    try std.testing.expect(freq > 50.0);
    try std.testing.expect(freq < 60.0);
}

// Test: Orch-OR perception = discrete cycle
test "ActiveInference: Orch-OR perception equals discrete cycle" {
    const orch_or = orchORPerceptionDuration();
    const discrete = discreteCycleDuration();

    // They must be identical — each Orch-OR collapse IS one gamma cycle
    try std.testing.expectApproxEqRel(orch_or, discrete, 1e-15);

    // Both derived from same sacred constants
    const expected = 1.0 / (PHI_CUBED * PI / GAMMA);
    try std.testing.expectApproxEqRel(expected, orch_or, 1e-15);
}

// Test: Temporal depth golden ratio scaling
test "ActiveInference: temporal depth golden ratio scaling" {
    // Level 0: depth = phi^0 = 1.0
    const depth_0 = temporalDepth(0);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), depth_0, 1e-10);

    // Level 1: depth = phi^1 = phi
    const depth_1 = temporalDepth(1);
    try std.testing.expectApproxEqRel(PHI, depth_1, 1e-10);

    // Level 2: depth = phi^2
    const depth_2 = temporalDepth(2);
    try std.testing.expectApproxEqRel(PHI * PHI, depth_2, 1e-10);

    // Ratio between consecutive levels = phi (golden ratio scaling)
    const ratio = depth_2 / depth_1;
    try std.testing.expectApproxEqRel(PHI, ratio, 1e-10);

    // Precision decreases at higher levels
    const prec_0 = hierarchicalPrecision(0);
    const prec_1 = hierarchicalPrecision(1);
    try std.testing.expect(prec_0 > prec_1);
}

// Test: Phi-weighted free energy (higher phi = lower effective FE)
test "ActiveInference: phi-weighted free energy" {
    const fe_total: f64 = 1.0;

    // Zero IIT phi: no reduction
    const eff_0 = phiWeightedFreeEnergy(fe_total, 0.0);
    try std.testing.expectApproxEqRel(fe_total, eff_0, 1e-10);

    // Maximum IIT phi (= TRINITY): effective FE = 0
    const eff_max = phiWeightedFreeEnergy(fe_total, TRINITY);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), eff_max, 1e-10);

    // Intermediate phi: partial reduction
    const eff_half = phiWeightedFreeEnergy(fe_total, TRINITY / 2.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), eff_half, 1e-10);

    // Higher phi always gives lower effective free energy
    const eff_low = phiWeightedFreeEnergy(fe_total, 1.0);
    const eff_high = phiWeightedFreeEnergy(fe_total, 2.0);
    try std.testing.expect(eff_high < eff_low);
}

// Test: Consciousness level mapping
test "ActiveInference: consciousness level mapping" {
    // Very high FE: unconscious
    const state_unc = consciousnessLevel(4.0);
    try std.testing.expectEqual(@as(ConsciousnessState, .unconscious), state_unc);

    // Moderate FE: minimal
    const state_min = consciousnessLevel(2.0);
    try std.testing.expectEqual(@as(ConsciousnessState, .minimal), state_min);

    // Low FE: conscious
    const state_con = consciousnessLevel(0.8);
    try std.testing.expectEqual(@as(ConsciousnessState, .conscious), state_con);

    // Very low FE: enhanced
    const state_enh = consciousnessLevel(0.3);
    try std.testing.expectEqual(@as(ConsciousnessState, .enhanced), state_enh);

    // Boundary: exactly TRINITY = unconscious
    const state_boundary = consciousnessLevel(TRINITY);
    try std.testing.expectEqual(@as(ConsciousnessState, .unconscious), state_boundary);
}

// Test: Multi-criteria consciousness assessment
test "ActiveInference: multi-criteria consciousness" {
    // All conditions met: conscious
    try std.testing.expect(consciousnessFromFE(0.3, 0.4, true));

    // FE too high: not conscious
    try std.testing.expect(!consciousnessFromFE(0.7, 0.4, true));

    // Surprise too high: not conscious
    try std.testing.expect(!consciousnessFromFE(0.3, 0.7, true));

    // Error not resolved: not conscious
    try std.testing.expect(!consciousnessFromFE(0.3, 0.4, false));
}

// Test: Predictive coding update rule
test "ActiveInference: predictive coding update" {
    // No error: prediction unchanged
    const unchanged = predictiveCodingUpdate(0.5, 0.0, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), unchanged, 1e-10);

    // Positive error with unit precision: prediction increases by LEARNING_RATE * error
    const updated = predictiveCodingUpdate(0.5, 1.0, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.5 + LEARNING_RATE), updated, 1e-10);

    // Higher precision = larger update
    const high_prec = predictiveCodingUpdate(0.5, 1.0, 2.0);
    const low_prec = predictiveCodingUpdate(0.5, 1.0, 0.5);
    try std.testing.expect(high_prec > low_prec);
}

// Test: Expected free energy and allostasis
test "ActiveInference: expected free energy and allostasis" {
    // Expected free energy = pragmatic + epistemic
    const efe = expectedFreeEnergy(0.3, 0.2);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), efe, 1e-10);

    // At setpoint: zero deviation, no action needed
    const dev_zero = allostasisDeviation(1.0, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), dev_zero, 1e-10);
    try std.testing.expect(!needsAction(dev_zero));

    // Far from setpoint: high deviation, action needed
    const dev_high = allostasisDeviation(2.0, 0.5);
    try std.testing.expectApproxEqRel(@as(f64, 1.5), dev_high, 1e-10);
    try std.testing.expect(needsAction(dev_high));
}

// Test: Sacred constants consistency
test "ActiveInference: sacred constants consistency" {
    // CONSCIOUSNESS_THRESHOLD = 1/PHI
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI), CONSCIOUSNESS_THRESHOLD, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.618), CONSCIOUSNESS_THRESHOLD, 0.01);

    // SPECIOUS_PRESENT = 1/(PHI*PHI) ~ 0.382
    try std.testing.expectApproxEqRel(@as(f64, 0.382), SPECIOUS_PRESENT, 0.01);

    // GAMMA = 1/PHI_CUBED
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI_CUBED), GAMMA, 1e-10);

    // LEARNING_RATE = GAMMA
    try std.testing.expectApproxEqRel(GAMMA, LEARNING_RATE, 1e-15);

    // MAX_FREE_ENERGY = TRINITY = 3
    try std.testing.expectApproxEqRel(TRINITY, MAX_FREE_ENERGY, 1e-15);
    try std.testing.expectApproxEqRel(@as(f64, 3.0), MAX_FREE_ENERGY, 1e-10);

    // GAMMA_FREQ_HZ ~ 56 Hz
    try std.testing.expectApproxEqRel(GAMMA_FREQ_HZ, gammaFrequency(), 1e-15);
}
