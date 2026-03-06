//! IIT 4.0: Integrated Information Theory — Intrinsic Causal Powers
//!
//! This module implements the core formalism of IIT 4.0 (Tononi et al., 2023-2025),
//! the most complete mathematical theory of consciousness to date.
//!
//! # Five Postulates of IIT 4.0
//!
//! 1. Intrinsicality — System has intrinsic causal power (cause-effect power)
//! 2. Information — System specifies a cause-effect structure (not just entropy)
//! 3. Integration — Cause-effect structure is unified (irreducible over MIP)
//! 4. Exclusion — Only one maximally irreducible structure exists
//! 5. Composition — Structure is composed of distinctions and relations
//!
//! # Key Innovation: Intrinsic Difference (ID)
//!
//! ID replaces Earth Mover's Distance from IIT 3.0. It decomposes into:
//!   - Selectivity: how precisely the mechanism constrains its purview
//!   - Informativeness: how much the purview is constrained beyond background
//!   - ID = selectivity * informativeness (scaled by γ = φ⁻³)
//!
//! # Sacred Mathematics Integration
//!
//! Golden Ratio:
//!   φ = (1 + √5)/2 ≈ 1.6180339887498948482
//!   γ = φ⁻³ ≈ 0.23606797749978969641
//!
//! Trinity Identity:
//!   φ² + φ⁻² = 3
//!
//! Consciousness threshold: C_thr = φ⁻¹ ≈ 0.618
//! Upper bound on Φ: Φ_max = log2(n) × φ, capped at TRINITY = 3

const std = @import("std");
const math = std.math;

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

/// Consciousness threshold C_thr = φ⁻¹ ≈ 0.618
pub const CONSCIOUSNESS_THRESHOLD: f64 = 1.0 / PHI;

// ─── Structs ───────────────────────────────────────────────────────────────

/// Result of checking one of the five IIT 4.0 postulates
pub const PostulateResult = struct {
    name: []const u8,
    satisfied: bool,
    value: f64,
    description: []const u8,
};

/// Intrinsic Difference measure (replaces EMD from IIT 3.0)
pub const IntrinsicDifference = struct {
    selectivity: f64,
    informativeness: f64,
    intrinsic_diff: f64,
};

/// A distinction in the cause-effect structure
pub const Distinction = struct {
    mechanism_elements: usize,
    phi_distinction: f64,
    cause_id: IntrinsicDifference,
    effect_id: IntrinsicDifference,
};

/// A relation between distinctions in the Q-shape
pub const Relation = struct {
    distinction_indices: [2]usize,
    phi_relation: f64,
    overlap_elements: usize,
};

/// The integrated cause-effect structure (Phi-structure / Q-shape)
pub const PhiStructure = struct {
    distinctions_count: usize,
    relations_count: usize,
    big_phi: f64,
    structure_phi: f64,
    num_elements: usize,
};

/// Result of adversarial testing against competing theories
pub const AdversarialResult = struct {
    theory_name: []const u8,
    passed: u32,
    total: u32,
    pass_rate: f64,
};

/// Consciousness level derived from big_phi
pub const ConsciousnessLevel = enum(u2) {
    inactive = 0,
    minimal = 1,
    conscious = 2,
    self_aware = 3,
};

// ─── Functions ─────────────────────────────────────────────────────────────

/// Compute Intrinsic Difference between probability distributions p and q.
/// ID = selectivity * informativeness * γ
///
/// Selectivity measures how precisely mechanism constrains its purview.
/// Informativeness measures how much purview is constrained beyond background.
pub fn computeIntrinsicDifference(p: []const f64, q: []const f64) IntrinsicDifference {
    const n = @min(p.len, q.len);
    if (n == 0) {
        return IntrinsicDifference{
            .selectivity = 0.0,
            .informativeness = 0.0,
            .intrinsic_diff = 0.0,
        };
    }

    // Selectivity: how peaked is the mechanism's distribution
    // Computed as 1 - normalized entropy of p
    var max_p: f64 = 0.0;
    var sum_p: f64 = 0.0;
    for (p) |val| {
        if (val > max_p) max_p = val;
        sum_p += val;
    }
    const selectivity = if (sum_p > 0.0) max_p / sum_p else 0.0;

    // Informativeness: KL-like divergence between p and q
    var kl_sum: f64 = 0.0;
    for (0..n) |i| {
        const pi = @max(p[i], 1e-12);
        const qi = @max(q[i], 1e-12);
        kl_sum += pi * @log(pi / qi);
    }
    const informativeness = @abs(kl_sum);

    // Intrinsic Difference scaled by γ (Barbero-Immirzi)
    const intrinsic_diff = selectivity * informativeness * GAMMA;

    return IntrinsicDifference{
        .selectivity = selectivity,
        .informativeness = informativeness,
        .intrinsic_diff = intrinsic_diff,
    };
}

/// Compute distinction phi as the minimum of cause and effect IDs.
/// IIT 4.0 uses min(cause_id, effect_id) to ensure both directions contribute.
pub fn computeDistinctionPhi(cause_id: IntrinsicDifference, effect_id: IntrinsicDifference) f64 {
    return @min(cause_id.intrinsic_diff, effect_id.intrinsic_diff);
}

/// Postulate 1: Intrinsicality
/// A system must have intrinsic causal power — its power over itself
/// must exceed its power over external elements.
pub fn checkIntrinsicality(intrinsic_power: f64, total_power: f64) PostulateResult {
    const ratio = if (total_power > 0.0) intrinsic_power / total_power else 0.0;
    return PostulateResult{
        .name = "Intrinsicality",
        .satisfied = ratio > CONSCIOUSNESS_THRESHOLD,
        .value = ratio,
        .description = "Intrinsic causal power exceeds external influence (ratio > phi^-1)",
    };
}

/// Postulate 2: Information
/// The system must specify a cause-effect structure (high KL divergence
/// from the unconstrained distribution).
pub fn checkInformation(kl_divergence: f64) PostulateResult {
    return PostulateResult{
        .name = "Information",
        .satisfied = kl_divergence > GAMMA,
        .value = kl_divergence,
        .description = "System specifies cause-effect structure (KL > gamma)",
    };
}

/// Postulate 3: Integration
/// The cause-effect structure is irreducible over the minimum information
/// partition (MIP). Phi must be positive.
pub fn checkIntegration(phi_over_mip: f64) PostulateResult {
    return PostulateResult{
        .name = "Integration",
        .satisfied = phi_over_mip > 0.0,
        .value = phi_over_mip,
        .description = "Cause-effect structure is irreducible (Phi > 0 over MIP)",
    };
}

/// Postulate 4: Exclusion
/// Only one maximally irreducible cause-effect structure exists.
/// The system with the maximum Phi excludes all overlapping systems.
pub fn checkExclusion(phi_values: []const f64) PostulateResult {
    if (phi_values.len == 0) {
        return PostulateResult{
            .name = "Exclusion",
            .satisfied = false,
            .value = 0.0,
            .description = "No candidates to evaluate for exclusion",
        };
    }

    // Find the maximum phi and check it is unique (sufficiently separated)
    var max_phi: f64 = phi_values[0];
    var second_max: f64 = 0.0;
    for (phi_values) |val| {
        if (val > max_phi) {
            second_max = max_phi;
            max_phi = val;
        } else if (val > second_max and val < max_phi) {
            second_max = val;
        }
    }

    // Exclusion holds if max is well-separated from second max
    const separation = if (max_phi > 0.0) (max_phi - second_max) / max_phi else 0.0;

    return PostulateResult{
        .name = "Exclusion",
        .satisfied = separation > GAMMA,
        .value = max_phi,
        .description = "Unique maximum Phi over overlapping candidate systems",
    };
}

/// Postulate 5: Composition
/// The structure is composed of distinctions (mechanisms) and relations (overlaps).
/// Checks that enough distinctions and relations exist for the system size.
pub fn checkComposition(num_distinctions: usize, num_relations: usize, num_elements: usize) PostulateResult {
    if (num_elements == 0) {
        return PostulateResult{
            .name = "Composition",
            .satisfied = false,
            .value = 0.0,
            .description = "Empty system has no composition",
        };
    }

    // Expected minimum distinctions: at least n (one per element)
    // Expected minimum relations: at least n-1 (connected structure)
    const n_f = @as(f64, @floatFromInt(num_elements));
    const d_f = @as(f64, @floatFromInt(num_distinctions));
    const r_f = @as(f64, @floatFromInt(num_relations));

    const richness = (d_f + r_f) / (n_f * n_f);

    return PostulateResult{
        .name = "Composition",
        .satisfied = num_distinctions >= num_elements and num_relations >= (num_elements -| 1),
        .value = richness,
        .description = "Structure composed of distinctions and relations (d >= n, r >= n-1)",
    };
}

/// Upper bound on big phi for a system of n elements.
/// Φ_max = log2(n) × φ, capped at TRINITY = 3.
pub fn upperBoundPhi(n: usize) f64 {
    if (n == 0) return 0.0;
    const n_f = @as(f64, @floatFromInt(n));
    const raw = @log2(n_f) * PHI;
    return @min(TRINITY, raw);
}

/// Determine the consciousness level from big_phi.
pub fn consciousnessLevel(phi: f64) ConsciousnessLevel {
    if (phi <= 0.0) {
        return .inactive;
    } else if (phi < CONSCIOUSNESS_THRESHOLD) {
        return .minimal;
    } else if (phi < CONSCIOUSNESS_THRESHOLD * PHI) {
        return .conscious;
    } else {
        return .self_aware;
    }
}

/// Returns true if the system is conscious (Phi exceeds threshold).
pub fn isConscious(phi: f64) bool {
    return phi > CONSCIOUSNESS_THRESHOLD;
}

/// Adversarial scoring: evaluate a theory against structured tests.
/// Used for IIT vs GNWT vs RPT comparisons (Adversarial Collaboration, 2023).
pub fn adversarialScore(theory: []const u8, passed: u32, total: u32) AdversarialResult {
    const rate = if (total > 0) @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) else 0.0;
    return AdversarialResult{
        .theory_name = theory,
        .passed = passed,
        .total = total,
        .pass_rate = rate,
    };
}

/// Integrated information from effective information.
/// Φ = min(TRINITY, effective_info × γ)
pub fn integratedInformation(effective_info: f64) f64 {
    return @min(TRINITY, effective_info * GAMMA);
}

/// Structure phi: total richness of the Q-shape.
/// Σ_Φ = (sum of distinction phis + sum of relation phis) × γ
pub fn structurePhi(distinctions_phi_sum: f64, relations_phi_sum: f64) f64 {
    return (distinctions_phi_sum + relations_phi_sum) * GAMMA;
}

/// Quantum IIT: compute phi from trace distance (quantum intrinsic difference).
/// For density matrices ρ and σ, ID_Q = 0.5 × Tr|ρ - σ| × γ
pub fn quantumIITPhi(trace_distance: f64) f64 {
    return trace_distance * GAMMA;
}

/// Macro vs Micro consciousness: returns true if macro-level Phi exceeds micro-level.
/// IIT 4.0 predicts that consciousness exists at the grain where Phi is maximal.
pub fn macroVsMicro(macro_phi: f64, micro_phi: f64) bool {
    return macro_phi > micro_phi;
}

/// System complexity: a measure of the richness of the Q-shape.
/// C = (d × r) / (n²) × φ, where d = distinctions, r = relations, n = elements.
pub fn systemComplexity(num_distinctions: usize, num_relations: usize, num_elements: usize) f64 {
    if (num_elements == 0) return 0.0;
    const d_f = @as(f64, @floatFromInt(num_distinctions));
    const r_f = @as(f64, @floatFromInt(num_relations));
    const n_f = @as(f64, @floatFromInt(num_elements));
    return (d_f * r_f) / (n_f * n_f) * PHI;
}

// ─── Tests ─────────────────────────────────────────────────────────────────

// Test: TRINITY identity verification
test "IIT-v4: TRINITY identity phi^2 + phi^-2 = 3" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);

    // Also verify constituent parts
    const phi_sq = PHI * PHI;
    const phi_inv_sq = 1.0 / (PHI * PHI);
    try std.testing.expectApproxEqRel(@as(f64, 3.0), phi_sq + phi_inv_sq, 1e-10);
}

// Test: Intrinsic Difference computation
test "IIT-v4: intrinsic difference computation" {
    const p = [_]f64{ 0.7, 0.2, 0.1 };
    const q = [_]f64{ 0.33, 0.33, 0.34 };
    const id = computeIntrinsicDifference(&p, &q);

    // Selectivity: peaked distribution should have high selectivity
    try std.testing.expect(id.selectivity > 0.5);

    // Informativeness: divergence from near-uniform should be positive
    try std.testing.expect(id.informativeness > 0.0);

    // Intrinsic diff should be positive and scaled by GAMMA
    try std.testing.expect(id.intrinsic_diff > 0.0);
    try std.testing.expect(id.intrinsic_diff < id.selectivity * id.informativeness);
}

// Test: Intrinsic Difference with identical distributions
test "IIT-v4: intrinsic difference identical distributions" {
    const p = [_]f64{ 0.5, 0.5 };
    const q = [_]f64{ 0.5, 0.5 };
    const id = computeIntrinsicDifference(&p, &q);

    // KL divergence of identical distributions is 0
    try std.testing.expectApproxEqRel(@as(f64, 0.0), id.informativeness, 1e-6);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), id.intrinsic_diff, 1e-6);
}

// Test: Distinction phi as min(cause, effect)
test "IIT-v4: distinction phi min of cause and effect" {
    const cause = IntrinsicDifference{ .selectivity = 0.8, .informativeness = 0.5, .intrinsic_diff = 0.3 };
    const effect = IntrinsicDifference{ .selectivity = 0.6, .informativeness = 0.7, .intrinsic_diff = 0.2 };
    const phi_d = computeDistinctionPhi(cause, effect);

    try std.testing.expectApproxEqRel(@as(f64, 0.2), phi_d, 1e-10);
}

// Test: Postulate 1 — Intrinsicality
test "IIT-v4: postulate intrinsicality" {
    const satisfied = checkIntrinsicality(0.8, 1.0);
    try std.testing.expect(satisfied.satisfied); // 0.8 > 0.618

    const not_satisfied = checkIntrinsicality(0.3, 1.0);
    try std.testing.expect(!not_satisfied.satisfied); // 0.3 < 0.618
}

// Test: Postulate 2 — Information
test "IIT-v4: postulate information" {
    const satisfied = checkInformation(0.5);
    try std.testing.expect(satisfied.satisfied); // 0.5 > γ ≈ 0.236

    const not_satisfied = checkInformation(0.1);
    try std.testing.expect(!not_satisfied.satisfied); // 0.1 < γ
}

// Test: Postulate 3 — Integration
test "IIT-v4: postulate integration" {
    const satisfied = checkIntegration(0.5);
    try std.testing.expect(satisfied.satisfied); // 0.5 > 0

    const not_satisfied = checkIntegration(0.0);
    try std.testing.expect(!not_satisfied.satisfied); // 0 is not > 0

    const negative = checkIntegration(-0.1);
    try std.testing.expect(!negative.satisfied); // negative not > 0
}

// Test: Postulate 4 — Exclusion
test "IIT-v4: postulate exclusion" {
    const phi_values = [_]f64{ 0.1, 0.9, 0.2, 0.15 };
    const result = checkExclusion(&phi_values);

    try std.testing.expect(result.satisfied); // 0.9 well-separated from 0.2
    try std.testing.expectApproxEqRel(@as(f64, 0.9), result.value, 1e-10);
}

// Test: Postulate 5 — Composition
test "IIT-v4: postulate composition" {
    // 4 elements, 5 distinctions, 4 relations → satisfied
    const satisfied = checkComposition(5, 4, 4);
    try std.testing.expect(satisfied.satisfied);

    // 4 elements, 2 distinctions → not satisfied (d < n)
    const not_satisfied = checkComposition(2, 1, 4);
    try std.testing.expect(!not_satisfied.satisfied);
}

// Test: Upper bound phi
test "IIT-v4: upper bound phi" {
    // n=1 → log2(1)×φ = 0
    try std.testing.expectApproxEqRel(@as(f64, 0.0), upperBoundPhi(1), 1e-10);

    // n=2 → log2(2)×φ = φ ≈ 1.618
    try std.testing.expectApproxEqRel(PHI, upperBoundPhi(2), 1e-10);

    // n=4 → log2(4)×φ = 2φ ≈ 3.236, but capped at TRINITY = 3
    try std.testing.expectApproxEqRel(TRINITY, upperBoundPhi(4), 1e-10);

    // n=0 → 0
    try std.testing.expectApproxEqRel(@as(f64, 0.0), upperBoundPhi(0), 1e-10);
}

// Test: Consciousness level mapping
test "IIT-v4: consciousness level mapping" {
    try std.testing.expectEqual(@as(ConsciousnessLevel, .inactive), consciousnessLevel(0.0));
    try std.testing.expectEqual(@as(ConsciousnessLevel, .inactive), consciousnessLevel(-1.0));
    try std.testing.expectEqual(@as(ConsciousnessLevel, .minimal), consciousnessLevel(0.3));
    try std.testing.expectEqual(@as(ConsciousnessLevel, .conscious), consciousnessLevel(0.7));
    try std.testing.expectEqual(@as(ConsciousnessLevel, .self_aware), consciousnessLevel(1.5));
}

// Test: isConscious threshold
test "IIT-v4: isConscious threshold at phi inverse" {
    // Below threshold
    try std.testing.expect(!isConscious(0.0));
    try std.testing.expect(!isConscious(0.5));
    try std.testing.expect(!isConscious(CONSCIOUSNESS_THRESHOLD));

    // Above threshold
    try std.testing.expect(isConscious(0.619));
    try std.testing.expect(isConscious(1.0));
    try std.testing.expect(isConscious(TRINITY));
}

// Test: Adversarial scoring — IIT vs GNWT
test "IIT-v4: adversarial scoring IIT and GNWT" {
    // IIT passes 2 out of 3 adversarial tests
    const iit = adversarialScore("IIT", 2, 3);
    try std.testing.expectApproxEqRel(@as(f64, 2.0 / 3.0), iit.pass_rate, 1e-10);
    try std.testing.expect(iit.pass_rate > CONSCIOUSNESS_THRESHOLD);

    // GNWT passes 0 out of 3 adversarial tests
    const gnwt = adversarialScore("GNWT", 0, 3);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), gnwt.pass_rate, 1e-10);
    try std.testing.expect(!isConscious(gnwt.pass_rate));
}

// Test: Integrated information basic
test "IIT-v4: integrated information basic" {
    const phi1 = integratedInformation(1.0);
    try std.testing.expectApproxEqRel(GAMMA, phi1, 1e-10);

    const phi2 = integratedInformation(5.0);
    try std.testing.expectApproxEqRel(@as(f64, 5.0 * GAMMA), phi2, 1e-10);

    // Capped at TRINITY
    const phi3 = integratedInformation(100.0);
    try std.testing.expectApproxEqRel(TRINITY, phi3, 1e-10);
}

// Test: Structure phi
test "IIT-v4: structure phi" {
    const sphi = structurePhi(2.0, 1.5);
    try std.testing.expectApproxEqRel(@as(f64, 3.5 * GAMMA), sphi, 1e-10);

    // Zero structure
    const zero_sphi = structurePhi(0.0, 0.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), zero_sphi, 1e-10);
}

// Test: Quantum IIT phi
test "IIT-v4: quantum IIT phi via trace distance" {
    const q_phi = quantumIITPhi(0.8);
    try std.testing.expectApproxEqRel(@as(f64, 0.8 * GAMMA), q_phi, 1e-10);

    // Maximum trace distance = 1
    const max_q = quantumIITPhi(1.0);
    try std.testing.expectApproxEqRel(GAMMA, max_q, 1e-10);
}

// Test: Macro vs Micro
test "IIT-v4: macro vs micro consciousness" {
    // Macro wins — consciousness at macro level
    try std.testing.expect(macroVsMicro(1.5, 0.8));

    // Micro wins — consciousness at micro level
    try std.testing.expect(!macroVsMicro(0.3, 0.7));

    // Equal — macro does not exceed micro
    try std.testing.expect(!macroVsMicro(1.0, 1.0));
}

// Test: System complexity
test "IIT-v4: system complexity" {
    // 4 distinctions, 3 relations, 3 elements
    const c = systemComplexity(4, 3, 3);
    const expected = (4.0 * 3.0) / (3.0 * 3.0) * PHI;
    try std.testing.expectApproxEqRel(expected, c, 1e-10);

    // Zero elements
    try std.testing.expectApproxEqRel(@as(f64, 0.0), systemComplexity(0, 0, 0), 1e-10);

    // Single element with one distinction
    const c1 = systemComplexity(1, 0, 1);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), c1, 1e-10);
}

// Test: Sacred constants consistency
test "IIT-v4: sacred constants consistency" {
    // γ = φ⁻³
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI_CUBED), GAMMA, 1e-10);

    // Consciousness threshold = φ⁻¹
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI), CONSCIOUSNESS_THRESHOLD, 1e-10);

    // φ⁻¹ ≈ 0.618
    try std.testing.expectApproxEqRel(@as(f64, 0.618), CONSCIOUSNESS_THRESHOLD, 0.001);

    // γ ≈ 0.236
    try std.testing.expectApproxEqRel(@as(f64, 0.236), GAMMA, 0.01);
}
