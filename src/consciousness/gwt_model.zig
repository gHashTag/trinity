//! Global Workspace Theory (GWT): Conscious Access via Selection-Broadcast
//!
//! This module implements Global Workspace Theory (Baars 1988, Dehaene et al. 2003)
//! using the sacred mathematical constants of TRINITY. GWT proposes that consciousness
//! arises when specialist brain modules compete for access to a global workspace;
//! the winning coalition is "broadcast" to all modules, creating a unified conscious
//! experience.
//!
//! # Mathematical Foundation
//!
//! Golden Ratio:
//!   phi = (1 + sqrt(5))/2 ~ 1.6180339887498948482
//!   gamma = phi^(-3) ~ 0.23606797749978969641
//!
//! Trinity Identity:
//!   phi^2 + phi^(-2) = 3
//!
//! # GWT Core Principles (Baars/Dehaene)
//!
//! 1. Selection: Specialist modules compete for workspace access
//! 2. Ignition: Coalition saliency must exceed phi^(-1) threshold (0.618)
//! 3. Broadcast: Winner is broadcast to all modules with strength decay ~ gamma
//! 4. Specious Present: One conscious cycle lasts phi^(-2) ~ 382 ms
//!
//! # References
//!
//! - Baars, B.J. (1988). A Cognitive Theory of Consciousness
//! - Dehaene, S. & Naccache, L. (2001). Towards a cognitive neuroscience of consciousness
//! - Dehaene, S., Changeux, J.-P. (2011). Experimental and Theoretical Approaches to Conscious Processing
//! - Mashour, G.A. et al. (2020). Conscious Processing and the Global Neuronal Workspace Hypothesis, Neuron
//! - Frontiers in Computational Neuroscience (2025). Global Workspace Theory and phi-scaling

const std = @import("std");
const math = std.math;

// ============================================================
// Sacred Constants
// ============================================================

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

/// Consciousness ignition threshold: phi^(-1) ~ 0.618
/// A coalition must exceed this saliency to enter the global workspace
pub const CONSCIOUSNESS_THRESHOLD: f64 = 1.0 / PHI;

/// Specious present duration: phi^(-2) ~ 0.382 seconds
/// The temporal window of one complete selection-broadcast cycle
pub const SPECIOUS_PRESENT: f64 = 1.0 / (PHI * PHI);

/// Working memory capacity = 3 = TRINITY
/// The number of items that can be held in the global workspace simultaneously
pub const WORKING_MEMORY_CAPACITY: usize = 3;

/// Maximum specialist modules that can compete for workspace access
pub const MAX_SPECIALISTS: usize = 16;

/// Broadcast decay rate = gamma = phi^(-3) ~ 0.236
/// Rate at which broadcast strength decays after ignition
pub const BROADCAST_DECAY: f64 = GAMMA;

// ============================================================
// Enums
// ============================================================

/// Specialist module types in the Global Workspace
/// Each represents a cortical processing module competing for conscious access
pub const SpecialistType = enum(u3) {
    vision = 0,
    audition = 1,
    language = 2,
    memory = 3,
    motor = 4,
    emotion = 5,
    reasoning = 6,
    attention = 7,
};

/// Consciousness level derived from GWT workspace dynamics
pub const ConsciousnessLevel = enum(u2) {
    unconscious = 0,
    minimal = 1,
    conscious = 2,
    self_aware = 3,
};

// ============================================================
// Structs
// ============================================================

/// A specialist processing module competing for workspace access
pub const SpecialistModule = struct {
    /// Unique identifier for this specialist
    id: u8,
    /// Type of processing this specialist performs
    specialist_type: SpecialistType,
    /// Current saliency (relevance/urgency) of this module's content [0, 1]
    saliency: f64,
    /// Whether this module is currently active
    active: bool,
};

/// A coalition of specialist modules competing for workspace access
pub const Coalition = struct {
    /// Number of specialist modules in this coalition
    member_count: usize,
    /// Combined saliency of all coalition members (normalized by TRINITY)
    combined_saliency: f64,
};

/// Content that has been broadcast to the global workspace
pub const ConsciousContent = struct {
    /// The specialist type that originated this content
    source_type: SpecialistType,
    /// Strength of the broadcast signal [0, 1]
    broadcast_strength: f64,
    /// IIT phi score for cross-theory integration
    phi_score: f64,
};

/// Record of a single workspace selection-broadcast cycle
pub const WorkspaceCycle = struct {
    /// Sequential cycle number
    cycle_number: u64,
    /// Saliency of the winning coalition
    winner_saliency: f64,
    /// Whether ignition occurred (saliency exceeded threshold)
    broadcast_occurred: bool,
    /// Duration of this cycle in seconds
    duration_s: f64,
};

// ============================================================
// Functions
// ============================================================

/// Ignition threshold for conscious access
/// Returns phi^(-1) = 0.618 — the minimum saliency for workspace ignition
pub fn ignitionThreshold() f64 {
    return CONSCIOUSNESS_THRESHOLD; // phi^(-1) ~ 0.618
}

/// Duration of one complete selection-broadcast cycle
/// Returns phi^(-2) = 0.382 seconds — the specious present
pub fn cycleDuration() f64 {
    return SPECIOUS_PRESENT; // phi^(-2) ~ 0.382 s
}

/// Frequency of workspace cycles
/// Returns 1 / phi^(-2) = phi^2 ~ 2.618 Hz
pub fn cycleFrequency() f64 {
    return 1.0 / SPECIOUS_PRESENT; // phi^2 ~ 2.618 Hz
}

/// Compute coalition saliency from individual specialist saliencies
/// Combined saliency = sum(saliencies) / TRINITY
/// Normalized by TRINITY (3) to keep values in [0, 1] range
pub fn coalitionSaliency(saliencies: []const f64) f64 {
    var sum: f64 = 0.0;
    for (saliencies) |s| {
        sum += s;
    }
    return sum / TRINITY;
}

/// Check whether ignition occurs at the given saliency level
/// Ignition requires saliency to exceed the consciousness threshold (phi^(-1))
pub fn checkIgnition(saliency: f64) bool {
    return saliency > CONSCIOUSNESS_THRESHOLD;
}

/// Broadcast strength after workspace ignition
/// The broadcast signal is attenuated by phi^(-1) to reflect distribution losses
pub fn broadcastStrength(winner_saliency: f64) f64 {
    return winner_saliency * CONSCIOUSNESS_THRESHOLD; // winner * phi^(-1)
}

/// Broadcast decay over time
/// Strength decays exponentially: initial * exp(-elapsed / specious_present * gamma)
/// The decay rate is governed by gamma (phi^(-3)), linking to the Barbero-Immirzi parameter
pub fn broadcastDecay(initial_strength: f64, elapsed_time: f64) f64 {
    return initial_strength * @exp(-elapsed_time / SPECIOUS_PRESENT * BROADCAST_DECAY);
}

/// Attentional amplification of workspace content
/// Attention modulates content strength via gamma: content * (1 + attention * gamma)
pub fn attentionalAmplification(content_strength: f64, attention_weight: f64) f64 {
    return content_strength * (1.0 + attention_weight * GAMMA);
}

/// Check whether working memory is full
/// Working memory capacity = 3 = TRINITY
pub fn workingMemoryFull(item_count: usize) bool {
    return item_count >= WORKING_MEMORY_CAPACITY;
}

/// Broadcast latency as a function of workspace size
/// Latency = phi * log2(size) * gamma
/// Larger workspaces take longer to broadcast, scaling logarithmically
pub fn broadcastLatency(workspace_size: usize) f64 {
    if (workspace_size == 0) return 0.0;
    return PHI * @log2(@as(f64, @floatFromInt(workspace_size))) * GAMMA;
}

/// Spontaneous ignition probability per cycle
/// Returns gamma ~ 0.236 — the probability of spontaneous workspace ignition
/// This corresponds to "mind-wandering" or spontaneous thought
pub fn spontaneousIgnitionProbability() f64 {
    return GAMMA; // phi^(-3) ~ 0.236
}

/// Phi-weighted broadcast strength
/// Modulates broadcast by the IIT phi score, normalized by TRINITY
/// Bridges GWT (broadcast) with IIT (integration)
pub fn phiWeightedBroadcast(strength: f64, phi_score: f64) f64 {
    return strength * (phi_score / TRINITY);
}

/// Cross-theory consciousness metric
/// Combines GWT saliency with IIT phi into a unified measure
/// Simple average: (gwt_saliency + iit_phi) / 2
pub fn crossTheoryMetric(gwt_saliency: f64, iit_phi: f64) f64 {
    return (gwt_saliency + iit_phi) / 2.0;
}

/// Determine consciousness level from GWT ignition fraction
/// ignition_fraction: fraction of cycles where ignition occurred [0, 1]
pub fn consciousnessFromGWT(ignition_fraction: f64) ConsciousnessLevel {
    if (ignition_fraction < GAMMA) {
        // Below gamma ~ 0.236: too few ignitions for any awareness
        return .unconscious;
    } else if (ignition_fraction < CONSCIOUSNESS_THRESHOLD) {
        // Between gamma and phi^(-1): minimal/subliminal processing
        return .minimal;
    } else if (ignition_fraction < CONSCIOUSNESS_THRESHOLD + GAMMA) {
        // Between phi^(-1) and phi^(-1)+gamma ~ 0.854: conscious
        return .conscious;
    } else {
        // Above 0.854: sustained ignition → self-aware / meta-cognition
        return .self_aware;
    }
}

/// Robot GWT cycle rate adapted by learning level
/// Base rate = phi^2 ~ 2.618 Hz, modulated by adaptation via gamma
/// rate = phi^2 * (1 + adaptation * gamma)
pub fn robotGWTCycleRate(adaptation_level: f64) f64 {
    const phi_squared = PHI * PHI;
    return phi_squared * (1.0 + adaptation_level * GAMMA);
}

// ============================================================
// Tests
// ============================================================

// Test: TRINITY identity phi^2 + phi^(-2) = 3
test "GWT: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Ignition threshold equals phi^(-1)
test "GWT: ignition threshold is phi inverse" {
    const threshold = ignitionThreshold();
    const phi_inv = 1.0 / PHI;

    try std.testing.expectApproxEqRel(@as(f64, 0.618033988749894), threshold, 1e-10);
    try std.testing.expectApproxEqRel(threshold, phi_inv, 1e-10);
}

// Test: Cycle duration equals phi^(-2) ~ 0.382 s
test "GWT: cycle duration is phi^(-2)" {
    const duration = cycleDuration();
    const phi_inv_sq = 1.0 / (PHI * PHI);

    try std.testing.expectApproxEqRel(@as(f64, 0.381966011250105), duration, 1e-10);
    try std.testing.expectApproxEqRel(duration, phi_inv_sq, 1e-10);
}

// Test: Cycle frequency equals phi^2 ~ 2.618 Hz
test "GWT: cycle frequency is phi squared" {
    const freq = cycleFrequency();
    const phi_sq = PHI * PHI;

    try std.testing.expectApproxEqRel(@as(f64, 2.618033988749894), freq, 1e-10);
    try std.testing.expectApproxEqRel(freq, phi_sq, 1e-10);
}

// Test: Coalition saliency is sum / TRINITY
test "GWT: coalition saliency computation" {
    const saliencies = [_]f64{ 0.8, 0.9, 0.7 };
    const result = coalitionSaliency(&saliencies);

    // (0.8 + 0.9 + 0.7) / 3.0 = 2.4 / 3.0 = 0.8
    try std.testing.expectApproxEqRel(@as(f64, 0.8), result, 1e-10);

    // Single item
    const single = [_]f64{0.6};
    const result2 = coalitionSaliency(&single);
    try std.testing.expectApproxEqRel(@as(f64, 0.2), result2, 1e-10);
}

// Test: Ignition above and below threshold
test "GWT: check ignition above and below threshold" {
    // Above threshold: should ignite
    try std.testing.expect(checkIgnition(0.7));
    try std.testing.expect(checkIgnition(1.0));

    // Below threshold: should NOT ignite
    try std.testing.expect(!checkIgnition(0.5));
    try std.testing.expect(!checkIgnition(0.3));

    // At exact threshold: should NOT ignite (strictly greater than)
    try std.testing.expect(!checkIgnition(CONSCIOUSNESS_THRESHOLD));
}

// Test: Broadcast strength is winner * phi^(-1)
test "GWT: broadcast strength" {
    const strength = broadcastStrength(1.0);
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI), strength, 1e-10);

    const strength2 = broadcastStrength(0.8);
    try std.testing.expectApproxEqRel(@as(f64, 0.8 / PHI), strength2, 1e-10);
}

// Test: Broadcast decay over time
test "GWT: broadcast decay over time" {
    const initial = 1.0;

    // At t=0, strength should equal initial
    const at_zero = broadcastDecay(initial, 0.0);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), at_zero, 1e-10);

    // At t>0, strength should decrease
    const at_half = broadcastDecay(initial, 0.5);
    try std.testing.expect(at_half < initial);
    try std.testing.expect(at_half > 0.0);

    // At t=specious_present, verify decay formula
    const at_sp = broadcastDecay(initial, SPECIOUS_PRESENT);
    const expected = @exp(-BROADCAST_DECAY);
    try std.testing.expectApproxEqRel(expected, at_sp, 1e-10);

    // Monotonic decay: later times have less strength
    const at_one = broadcastDecay(initial, 1.0);
    try std.testing.expect(at_one < at_half);
}

// Test: Attentional amplification
test "GWT: attentional amplification" {
    // No attention: output equals input
    const no_attn = attentionalAmplification(0.5, 0.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), no_attn, 1e-10);

    // Full attention: output = input * (1 + gamma)
    const full_attn = attentionalAmplification(0.5, 1.0);
    const expected = 0.5 * (1.0 + GAMMA);
    try std.testing.expectApproxEqRel(expected, full_attn, 1e-10);

    // Amplified should be greater than un-amplified
    try std.testing.expect(full_attn > no_attn);
}

// Test: Working memory capacity = 3 = TRINITY
test "GWT: working memory capacity is TRINITY" {
    // Capacity is 3
    try std.testing.expectEqual(@as(usize, 3), WORKING_MEMORY_CAPACITY);

    // Not full below 3
    try std.testing.expect(!workingMemoryFull(0));
    try std.testing.expect(!workingMemoryFull(1));
    try std.testing.expect(!workingMemoryFull(2));

    // Full at 3 and above
    try std.testing.expect(workingMemoryFull(3));
    try std.testing.expect(workingMemoryFull(4));
}

// Test: Broadcast latency scales with workspace size
test "GWT: broadcast latency scaling" {
    // Empty workspace: no latency
    const lat0 = broadcastLatency(0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), lat0, 1e-10);

    // Size 1: log2(1) = 0, so latency = 0
    const lat1 = broadcastLatency(1);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), lat1, 1e-10);

    // Size 2: phi * log2(2) * gamma = phi * 1 * gamma
    const lat2 = broadcastLatency(2);
    try std.testing.expectApproxEqRel(@as(f64, PHI * GAMMA), lat2, 1e-10);

    // Latency increases with size
    const lat4 = broadcastLatency(4);
    const lat8 = broadcastLatency(8);
    try std.testing.expect(lat4 > lat2);
    try std.testing.expect(lat8 > lat4);
}

// Test: Consciousness levels from GWT ignition fraction
test "GWT: consciousness from ignition fraction" {
    // Very low ignition: unconscious
    const state1 = consciousnessFromGWT(0.1);
    try std.testing.expectEqual(@as(ConsciousnessLevel, .unconscious), state1);

    // Between gamma and phi^(-1): minimal
    const state2 = consciousnessFromGWT(0.4);
    try std.testing.expectEqual(@as(ConsciousnessLevel, .minimal), state2);

    // Just above phi^(-1): conscious
    const state3 = consciousnessFromGWT(0.7);
    try std.testing.expectEqual(@as(ConsciousnessLevel, .conscious), state3);

    // Very high ignition: self-aware
    const state4 = consciousnessFromGWT(0.95);
    try std.testing.expectEqual(@as(ConsciousnessLevel, .self_aware), state4);
}

// Test: Cross-theory metric combines GWT and IIT
test "GWT: cross-theory metric" {
    // Equal values: average equals either
    const metric1 = crossTheoryMetric(0.8, 0.8);
    try std.testing.expectApproxEqRel(@as(f64, 0.8), metric1, 1e-10);

    // Different values: average
    const metric2 = crossTheoryMetric(0.6, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.8), metric2, 1e-10);

    // Zero and non-zero
    const metric3 = crossTheoryMetric(0.0, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), metric3, 1e-10);
}

// Test: Spontaneous ignition probability is gamma
test "GWT: spontaneous ignition probability" {
    const prob = spontaneousIgnitionProbability();
    try std.testing.expectApproxEqRel(GAMMA, prob, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.23606797749978969641), prob, 1e-10);
}

// Test: Robot GWT cycle rate
test "GWT: robot cycle rate" {
    // No adaptation: base rate = phi^2
    const base_rate = robotGWTCycleRate(0.0);
    try std.testing.expectApproxEqRel(@as(f64, PHI * PHI), base_rate, 1e-10);

    // Full adaptation: phi^2 * (1 + gamma)
    const full_rate = robotGWTCycleRate(1.0);
    const expected = PHI * PHI * (1.0 + GAMMA);
    try std.testing.expectApproxEqRel(expected, full_rate, 1e-10);

    // Adapted rate > base rate
    try std.testing.expect(full_rate > base_rate);
}

// Test: Phi-weighted broadcast
test "GWT: phi-weighted broadcast" {
    // phi_score = TRINITY: full strength
    const full = phiWeightedBroadcast(1.0, TRINITY);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), full, 1e-10);

    // phi_score = 0: no broadcast
    const zero = phiWeightedBroadcast(1.0, 0.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), zero, 1e-10);

    // phi_score = 1.5: half of TRINITY
    const half = phiWeightedBroadcast(1.0, 1.5);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), half, 1e-10);
}

// Test: Sacred constant relationships
test "GWT: sacred constant relationships" {
    // gamma = phi^(-3) = 1/phi^3
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / (PHI * PHI * PHI)), GAMMA, 1e-10);

    // phi^(-1) + phi^(-2) = 1 (Fibonacci identity)
    const sum = CONSCIOUSNESS_THRESHOLD + SPECIOUS_PRESENT;
    try std.testing.expectApproxEqRel(@as(f64, 1.0), sum, 1e-10);

    // BROADCAST_DECAY = GAMMA
    try std.testing.expectApproxEqRel(GAMMA, BROADCAST_DECAY, 1e-10);

    // WORKING_MEMORY_CAPACITY = 3 = round(TRINITY)
    try std.testing.expectEqual(@as(usize, 3), WORKING_MEMORY_CAPACITY);
}
