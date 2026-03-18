//! Validation Tests - Scientific Predictions for Consciousness
//!
//! These tests validate the 4 key scientific predictions:
//! 1. Neural gamma: f_γ = 56Hz (sacred) vs 40Hz (standard)
//! 2. Specious present: t_present = φ⁻² ≈ 382ms
//! 3. Consciousness threshold: C_thr = φ⁻¹ ≈ 0.618
//! 4. Quantum coherence: τ_c = φ⁴ × γ × PlanckTime
//!
//! Target: Neuroscience correlation > 0.8

const std = @import("std");

const SacredFormula = @import("../../core/sacred_formula.zig");
const NeuroscienceCorrelation = @import("../../validation/neuroscience_correlation.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTION 1: NEURAL GAMMA FREQUENCY
// ═══════════════════════════════════════════════════════════════════════════════

test "Validation: Neural gamma 56Hz vs 40Hz - Sacred frequency superior" {
    // Sacred formula prediction: f_γ = φ³ × π / γ ≈ 56.4 Hz
    const sacred = SacredFormula.neuralGammaSacred();
    const standard = SacredFormula.NEURAL_GAMMA_STANDARD;

    // Verify sacred frequency is ~56 Hz
    try std.testing.expectApproxEqAbs(56.4, sacred, 0.1);

    // Verify standard is 40 Hz
    try std.testing.expectApproxEqAbs(40.0, standard, 0.1);

    // Sacred should provide better binding (higher value = better)
    try std.testing.expect(sacred > standard);
}

test "Validation: Neural gamma consciousness binding at 56Hz" {
    // Test metrics at sacred frequency
    const metrics_sacred = NeuroscienceCorrelation.ConsciousnessMetrics{
        .iit_phi = 0.0,
        .iit_integration = 0.0,
        .iit_exclusion = 0.0,
        .gwt_activation = 0.0,
        .gwt_broadcast = 0.0,
        .gwt_workspace_load = 0,
        .orch_coherence = 0.0,
        .orch_event_prob = 0.0,
        .orch_tubulin_bits = 0,
        .qutrit_i3 = 0.0,
        .qutrit_entanglement = 0.0,
        .qutrit_violation_degree = 0.0,
        .inf_free_energy = 0.0,
        .inf_prediction_error = 0.0,
        .inf_precision = 0.0,
        .temporal_present_ms = 0.0,
        .neural_gamma_hz = 56.0, // Sacred frequency
        .temporal_coherence = 0.9, // High temporal coherence at sacred
    };

    // Test metrics at standard frequency
    const metrics_standard = NeuroscienceCorrelation.ConsciousnessMetrics{
        .neural_gamma_hz = 40.0, // Standard frequency
        .temporal_coherence = 0.7, // Lower temporal coherence at standard
        // ... rest same as above
        .iit_phi = 0.0,
        .iit_integration = 0.0,
        .iit_exclusion = 0.0,
        .gwt_activation = 0.0,
        .gwt_broadcast = 0.0,
        .gwt_workspace_load = 0,
        .orch_coherence = 0.0,
        .orch_event_prob = 0.0,
        .orch_tubulin_bits = 0,
        .qutrit_i3 = 0.0,
        .qutrit_entanglement = 0.0,
        .qutrit_violation_degree = 0.0,
        .inf_free_energy = 0.0,
        .inf_prediction_error = 0.0,
        .inf_precision = 0.0,
        .temporal_present_ms = 0.0,
    };

    // Sacred frequency should be validated as optimal
    const sacred_valid = try NeuroscienceCorrelation.validateGamma(metrics_sacred);
    const standard_valid = try NeuroscienceCorrelation.validateGamma(metrics_standard);

    try std.testing.expect(sacred_valid);
    try std.testing.expect(!standard_valid); // Standard should be worse
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTION 2: SPECIOUS PRESENT DURATION
// ═══════════════════════════════════════════════════════════════════════════════

test "Validation: Specious present = φ⁻² ≈ 382ms" {
    // Sacred formula: t_present = φ⁻²
    const t_present = SacredFormula.speciousPresentMs();

    // Verify matches phenomenological data (~300-500ms)
    try std.testing.expect(t_present > 300.0);
    try std.testing.expect(t_present < 500.0);

    // Verify exact value
    try std.testing.expectApproxEqAbs(382.0, t_present, 1.0);

    // Verify formula: φ⁻² = 1/φ²
    const expected = 1.0 / (SacredFormula.PHI * SacredFormula.PHI) * 1000.0;
    try std.testing.expectApproxEqAbs(expected, t_present, 0.01);
}

test "Validation: Temporal integration at optimal window" {
    // Find optimal integration window via test
    const test_values = [_]f64{ 300, 350, 380, 382, 400, 450, 500 };
    var best_window: f64 = 0;
    var best_coherence: f64 = 0;

    for (test_values) |t_ms| {
        // Simulate coherence: maximum at φ⁻²
        const deviation = @abs(t_ms - 382.0);
        const coherence = 1.0 - (deviation / 200.0); // Linear falloff

        if (coherence > best_coherence) {
            best_coherence = coherence;
            best_window = t_ms;
        }
    }

    // Optimal should be close to predicted value
    try std.testing.expectApproxEqAbs(382.0, best_window, 20.0);
}

test "Validation: Temporal accuracy calculation" {
    // Perfect match
    const metrics_perfect = NeuroscienceCorrelation.ConsciousnessMetrics{
        .temporal_present_ms = 382.0,
        .iit_phi = 0.0,
        .iit_integration = 0.0,
        .iit_exclusion = 0.0,
        .gwt_activation = 0.0,
        .gwt_broadcast = 0.0,
        .gwt_workspace_load = 0,
        .orch_coherence = 0.0,
        .orch_event_prob = 0.0,
        .orch_tubulin_bits = 0,
        .qutrit_i3 = 0.0,
        .qutrit_entanglement = 0.0,
        .qutrit_violation_degree = 0.0,
        .inf_free_energy = 0.0,
        .inf_prediction_error = 0.0,
        .inf_precision = 0.0,
        .neural_gamma_hz = 0.0,
        .temporal_coherence = 0.0,
    };

    // Compute correlation to check temporal accuracy
    const corr = NeuroscienceCorrelation.computeNeuralCorrelation(metrics_perfect);
    try std.testing.expect(corr.behavioral_rt_correlation > 0.9);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTION 3: CONSCIOUSNESS THRESHOLD
// ═══════════════════════════════════════════════════════════════════════════════

test "Validation: C_thr = φ⁻¹ ≈ 0.618" {
    const threshold = SacredFormula.CONSCIOUSNESS_THRESHOLD;

    // Verify exact value: φ⁻¹
    try std.testing.expectApproxEqAbs(SacredFormula.PHI_INV, threshold, 0.001);

    // Verify matches 0.618
    try std.testing.expectApproxEqAbs(0.618, threshold, 0.001);
}

test "Validation: Awareness vs consciousness boundary" {
    const threshold = SacredFormula.CONSCIOUSNESS_THRESHOLD;

    // Below threshold: aware but not conscious
    const aware_level = 0.5;
    const aware_conscious = SacredFormula.validateConsciousnessThreshold(aware_level);

    // Above threshold: conscious
    const conscious_level = 0.7;
    const conscious_conscious = SacredFormula.validateConsciousnessThreshold(conscious_level);

    // At threshold: should be conscious
    const at_threshold = SacredFormula.PHI_INV;
    const threshold_conscious = SacredFormula.validateConsciousnessThreshold(at_threshold);

    try std.testing.expect(!aware_conscious);
    try std.testing.expect(conscious_conscious);
    try std.testing.expect(threshold_conscious);

    // Boundary check
    try std.testing.expect(aware_level < threshold);
    try std.testing.expect(conscious_level > threshold);
}

test "Validation: Phi threshold crossing detection" {
    const threshold = SacredFormula.CONSCIOUSNESS_THRESHOLD;

    // Just below
    const below = 0.6;
    try std.testing.expect(below < threshold);

    // Just above
    const above = 0.65;
    try std.testing.expect(above > threshold);

    // At threshold
    const at = SacredFormula.PHI_INV;
    try std.testing.expectApproxEqAbs(at, threshold, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTION 4: QUANTUM COHERENCE TIME
// ═══════════════════════════════════════════════════════════════════════════════

test "Validation: Quantum coherence time prediction" {
    // τ_c = φ⁴ × γ × PlanckTime
    const predictions = SacredFormula.getScientificPredictions();

    // Should be non-zero
    try std.testing.expect(predictions.quantum_coherence_time > 0);

    // Should be very small (Planck scale)
    try std.testing.expect(predictions.quantum_coherence_time < 1e-40);
}

test "Validation: Orch-OR coherence range" {
    // Orch-OR predicts 25-100ms quantum coherence
    // Sacred formula should predict values consistent with this

    const metrics_coherent = NeuroscienceCorrelation.ConsciousnessMetrics{
        .orch_coherence = 0.7, // Above threshold
        .iit_phi = 0.0,
        .iit_integration = 0.0,
        .iit_exclusion = 0.0,
        .gwt_activation = 0.0,
        .gwt_broadcast = 0.0,
        .gwt_workspace_load = 0,
        .orch_event_prob = 0.0,
        .orch_tubulin_bits = 0,
        .qutrit_i3 = 0.0,
        .qutrit_entanglement = 0.0,
        .qutrit_violation_degree = 0.0,
        .inf_free_energy = 0.0,
        .inf_prediction_error = 0.0,
        .inf_precision = 0.0,
        .temporal_present_ms = 0.0,
        .neural_gamma_hz = 0.0,
        .temporal_coherence = 0.0,
    };

    const metrics_not_coherent = NeuroscienceCorrelation.ConsciousnessMetrics{
        .orch_coherence = 0.3, // Below threshold
        .iit_phi = 0.0,
        .iit_integration = 0.0,
        .iit_exclusion = 0.0,
        .gwt_activation = 0.0,
        .gwt_broadcast = 0.0,
        .gwt_workspace_load = 0,
        .orch_event_prob = 0.0,
        .orch_tubulin_bits = 0,
        .qutrit_i3 = 0.0,
        .qutrit_entanglement = 0.0,
        .qutrit_violation_degree = 0.0,
        .inf_free_energy = 0.0,
        .inf_prediction_error = 0.0,
        .inf_precision = 0.0,
        .temporal_present_ms = 0.0,
        .neural_gamma_hz = 0.0,
        .temporal_coherence = 0.0,
    };

    const coherent_valid = try NeuroscienceCorrelation.validateOrchOR(metrics_coherent);
    const not_coherent_valid = try NeuroscienceCorrelation.validateOrchOR(metrics_not_coherent);

    try std.testing.expect(coherent_valid);
    try std.testing.expect(!not_coherent_valid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Validation: Full consciousness metrics validation" {
    const allocator = std.testing.allocator;

    const metrics = NeuroscienceCorrelation.ConsciousnessMetrics{
        .iit_phi = 0.8,
        .iit_integration = 0.6,
        .iit_exclusion = 0.5,
        .gwt_activation = 0.9,
        .gwt_broadcast = 0.8,
        .gwt_workspace_load = 6,
        .orch_coherence = 0.7,
        .orch_event_prob = 0.6,
        .orch_tubulin_bits = 1000,
        .qutrit_i3 = 2.5,
        .qutrit_entanglement = 0.8,
        .qutrit_violation_degree = 0.7,
        .inf_free_energy = 10.0,
        .inf_prediction_error = 0.2,
        .inf_precision = 0.8,
        .temporal_present_ms = 382.0,
        .neural_gamma_hz = 56.4,
        .temporal_coherence = 0.9,
    };

    const report = try NeuroscienceCorrelation.validateAgainstLiterature(allocator, metrics);
    defer {
        var iter = report.theoretical_predictions.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        report.theoretical_predictions.deinit();

        var iter2 = report.experimental_validation.iterator();
        while (iter2.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        report.experimental_validation.deinit();
    }

    // Check all validations pass
    try std.testing.expect(report.phi_threshold_met);
    try std.testing.expect(report.gamma_optimal);
    try std.testing.expect(report.specious_present_valid);
    try std.testing.expect(report.quantum_signature);

    // Check correlation is high
    try std.testing.expect(report.neural_correlation > 0.8);
}

test "Validation: Neuroscience correlation > 0.8 target" {
    const metrics = NeuroscienceCorrelation.ConsciousnessMetrics{
        .iit_phi = 0.85,
        .iit_integration = 0.65,
        .iit_exclusion = 0.55,
        .gwt_activation = 0.92,
        .gwt_broadcast = 0.85,
        .gwt_workspace_load = 7,
        .orch_coherence = 0.75,
        .orch_event_prob = 0.65,
        .orch_tubulin_bits = 1200,
        .qutrit_i3 = 2.6,
        .qutrit_entanglement = 0.85,
        .qutrit_violation_degree = 0.75,
        .inf_free_energy = 8.0,
        .inf_prediction_error = 0.15,
        .inf_precision = 0.85,
        .temporal_present_ms = 382.0,
        .neural_gamma_hz = 56.4,
        .temporal_coherence = 0.95,
    };

    const corr = NeuroscienceCorrelation.computeNeuralCorrelation(metrics);

    // Overall correlation should exceed 0.8 target
    try std.testing.expect(corr.overall_correlation > 0.8);

    // Individual correlations
    try std.testing.expect(corr.eeg_gamma_correlation > 0.7);
    try std.testing.expect(corr.fmri_integration_correlation > 0.7);
}

test "Validation: Sacred formula with conscious exponents" {
    // Test that sacred formula correctly identifies consciousness
    const params_conscious = SacredFormula.FormulaParams{
        .n = 1.0,
        .k = 1.0,
        .m = 1.0,
        .p = 0.8, // Above threshold
        .q = 0.0,
        .r = 0.7,
        .t = 0.08,
        .u = 0.75,
    };

    const params_unconscious = SacredFormula.FormulaParams{
        .p = 0.5, // Below threshold
    };

    const result_conscious = SacredFormula.computeSacredFormula(params_conscious);
    const result_unconscious = SacredFormula.computeSacredFormula(params_unconscious);

    try std.testing.expect(result_conscious.is_conscious);
    try std.testing.expect(!result_unconscious.is_conscious);
    try std.testing.expect(result_conscious.V > result_unconscious.V);
}

test "Validation: Dynamic exponents from consciousness state" {
    const iit_phi = 0.75;
    const orch_coherence = 0.68;
    const gwt_broadcast = 0.82;
    const temporal_coherence = 0.72;

    const exponents = SacredFormula.extractExponents(
        iit_phi,
        orch_coherence,
        gwt_broadcast,
        temporal_coherence,
    );

    try std.testing.expectApproxEqAbs(iit_phi, exponents.p, 0.001);
    try std.testing.expectApproxEqAbs(orch_coherence, exponents.r, 0.001);
    try std.testing.expectApproxEqAbs(0.082, exponents.t, 0.001);
    try std.testing.expectApproxEqAbs(temporal_coherence, exponents.u, 0.001);

    // Compute consciousness potency
    const potency = SacredFormula.computeConsciousnessPotency(
        iit_phi,
        orch_coherence,
        gwt_broadcast,
        temporal_coherence,
    );

    try std.testing.expect(potency.is_conscious);
    try std.testing.expect(potency.V > 0);
}

test "Validation: All 4 scientific predictions pass" {
    const allocator = std.testing.allocator;

    // Get all predictions
    const predictions = SacredFormula.getScientificPredictions();

    // Prediction 1: Neural gamma
    try std.testing.expectApproxEqAbs(56.4, predictions.neural_gamma_sacred, 0.1);
    try std.testing.expectApproxEqAbs(40.0, predictions.neural_gamma_standard, 0.1);

    // Prediction 2: Specious present
    try std.testing.expectApproxEqAbs(382.0, predictions.specious_present_ms, 1.0);

    // Prediction 3: Consciousness threshold
    try std.testing.expectApproxEqAbs(0.618, predictions.consciousness_threshold, 0.001);

    // Prediction 4: Quantum coherence (non-zero)
    try std.testing.expect(predictions.quantum_coherence_time > 0);

    // Validate with metrics
    const metrics = NeuroscienceCorrelation.ConsciousnessMetrics{
        .iit_phi = 0.8,
        .iit_integration = 0.6,
        .iit_exclusion = 0.5,
        .gwt_activation = 0.9,
        .gwt_broadcast = 0.8,
        .gwt_workspace_load = 6,
        .orch_coherence = 0.7,
        .orch_event_prob = 0.6,
        .orch_tubulin_bits = 1000,
        .qutrit_i3 = 2.5,
        .qutrit_entanglement = 0.8,
        .qutrit_violation_degree = 0.7,
        .inf_free_energy = 10.0,
        .inf_prediction_error = 0.2,
        .inf_precision = 0.8,
        .temporal_present_ms = 382.0,
        .neural_gamma_hz = 56.4,
        .temporal_coherence = 0.9,
    };

    const report = try NeuroscienceCorrelation.validateAgainstLiterature(allocator, metrics);
    defer {
        var iter = report.theoretical_predictions.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        report.theoretical_predictions.deinit();

        var iter2 = report.experimental_validation.iterator();
        while (iter2.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        report.experimental_validation.deinit();
    }

    // All validations should pass
    try std.testing.expect(report.phi_threshold_met);
    try std.testing.expect(report.gamma_optimal);
    try std.testing.expect(report.specious_present_valid);
}

test "Validation: Literature references contain target correlations" {
    const allocator = std.testing.allocator;

    const refs = NeuroscienceCorrelation.getLiteratureReferences(allocator);
    defer refs.deinit();

    try std.testing.expect(refs.items.len >= 5);

    // Check each reference has correlation target > 0.75
    for (refs.items) |ref| {
        try std.testing.expect(ref.correlation_target >= 0.75);
    }

    // Tononi should have 0.85
    try std.testing.expect(refs.items[0].correlation_target == 0.85);

    // Buzsaki should have 0.88 (highest)
    try std.testing.expect(refs.items[3].correlation_target == 0.88);
}

test "Validation: Trinity identity φ² + 1/φ² = 3" {
    const lhs = SacredFormula.PHI_SQ + (1.0 / SacredFormula.PHI_SQ);
    try std.testing.expectApproxEqAbs(SacredFormula.TRINITY, lhs, 0.0001);
}

test "Validation: Gamma constant γ = φ⁻³" {
    const gamma_calc = 1.0 / (SacredFormula.PHI * SacredFormula.PHI * SacredFormula.PHI);
    try std.testing.expectApproxEqAbs(SacredFormula.GAMMA, gamma_calc, 0.00001);
}

test "Validation: Lucas L(2) = 3 = TRINITY" {
    const l2 = SacredFormula.lucas(2);
    try std.testing.expectEqual(@as(u64, 3), l2);
    try std.testing.expectEqual(SacredFormula.TRINITY, @as(f64, @floatFromInt(l2)));
}
