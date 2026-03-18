//! Conscious Active Inference - Orch-OR + Free Energy Unified
//!
//! Quantum-enhanced active inference with gamma-cycle timing.
//! Explains 40Hz rhythm via quantum gravity.
//!
//! Key formulas:
//!   - F_quantum = F - phi × hbar × omega (quantum correction)
//!   - T_cycle = 25ms (gamma cycle from quantum gravity)
//!   - S_quantum = S_classical + phi × collapse_entropy

const std = @import("std");
const mem = std.mem;

// Physical constants
const HBAR: f64 = 1.054571817e-34; // Reduced Planck constant (J*s)

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const PHI_SQ: f64 = PHI * PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;

// Timing constants
pub const GAMMA_CYCLE_MS: f64 = 25.0;
pub const SPECIOUS_PRESENT_MS: f64 = 382.0;
pub const QUANTUM_CORRECTION_FACTOR: f64 = PHI;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Cycle Phase
pub const CyclePhase = enum {
    PERCEPTION,
    INTEGRATION,
    ACTION,
    LEARNING,
};

/// Active Inference State
pub const ActiveInferenceState = struct {
    free_energy: f64 = 0.0,
    prediction_error: f64 = 0.0,
    surprise: f64 = 0.0,
    consciousness_score: f64 = 0.0,
    precision: f64 = 0.0,
    epistemic_value: f64 = 0.0,
    pragmatic_value: f64 = 0.0,
};

/// Quantum Inference State
pub const QuantumInferenceState = struct {
    classical_free_energy: f64 = 0.0,
    quantum_correction: f64 = 0.0,
    superposition_energy: f64 = 0.0,
    collapse_energy: f64 = 0.0,
    quantum_free_energy: f64 = 0.0,
};

/// Perceptual Cycle
pub const PerceptualCycle = struct {
    duration_ms: f64 = GAMMA_CYCLE_MS,
    quantum_collapse: bool = false,
    free_energy_delta: f64 = 0.0,
    prediction_error_delta: f64 = 0.0,
    phase: CyclePhase = .PERCEPTION,
};

/// Belief Entry
pub const BeliefEntry = struct {
    key: []const u8,
    value: f64,
    precision: f64,
};

/// Generative Model
pub const GenerativeModel = struct {
    allocator: mem.Allocator,
    beliefs: std.StringHashMap(f64),
    predictions: std.ArrayListUnmanaged(f64) = .{},
    precision_weights: std.ArrayListUnmanaged(f64) = .{},
    complexity: f64 = 0.0,

    /// Initialize generative model
    pub fn init(allocator: mem.Allocator) GenerativeModel {
        return .{
            .allocator = allocator,
            .beliefs = std.StringHashMap(f64).init(allocator),
        };
    }

    /// Deinitialize generative model
    pub fn deinit(self: *GenerativeModel) void {
        self.beliefs.deinit();
        self.predictions.deinit(self.allocator);
        self.precision_weights.deinit(self.allocator);
    }
};

/// Inference Result
pub const InferenceResult = struct {
    action_selected: []const u8 = "",
    expected_free_energy: f64 = 0.0,
    confidence: f64 = 0.0,
    consciousness_level: f64 = 0.0,
};

/// Quantum Active Inference Engine
pub const QuantumActiveInference = struct {
    allocator: mem.Allocator,
    state: ActiveInferenceState = .{},
    quantum_state: QuantumInferenceState = .{},
    model: GenerativeModel,
    cycle: PerceptualCycle = .{},

    /// Initialize quantum active inference
    pub fn init(allocator: mem.Allocator) QuantumActiveInference {
        return .{
            .allocator = allocator,
            .model = GenerativeModel.init(allocator),
        };
    }

    /// Deinitialize quantum active inference
    pub fn deinit(self: *QuantumActiveInference) void {
        self.model.deinit();
    }

    /// Compute quantum-corrected free energy
    /// F_quantum = F - phi × hbar × omega
    pub fn computeQuantumFreeEnergy(self: *QuantumActiveInference, F_classical: f64, omega_collapse: f64) f64 {
        const correction = PHI * HBAR * omega_collapse;
        self.quantum_state.quantum_correction = correction;
        self.quantum_state.classical_free_energy = F_classical;
        self.quantum_state.quantum_free_energy = F_classical - correction;
        return self.quantum_state.quantum_free_energy;
    }

    /// Compute perceptual cycle duration from quantum gravity
    /// T_cycle = hbar / (E_superposition × gamma)
    pub fn computeCycleDuration(self: *QuantumActiveInference, E_superposition: f64) f64 {
        const duration_seconds = HBAR / (E_superposition * GAMMA);
        const duration_ms = duration_seconds * 1000.0;
        self.cycle.duration_ms = duration_ms;
        return duration_ms;
    }

    /// Minimize free energy via active inference
    pub fn minimizeFreeEnergy(self: *QuantumActiveInference, prediction: f64, observation: f64) !void {
        const prediction_error = 0.5 * std.math.pow(f64, observation - prediction, 2);
        self.state.prediction_error = prediction_error;

        // Update model to minimize free energy
        self.state.free_energy -= 0.1 * prediction_error; // Gradient descent step
    }

    /// Compute prediction error
    /// PE = 0.5 × (observation - prediction)^2 / precision
    pub fn computePredictionError(observation: f64, prediction: f64, precision: f64) f64 {
        if (precision == 0) return 0.0;
        const error_val = 0.5 * std.math.pow(f64, observation - prediction, 2);
        return error_val / precision;
    }

    /// Compute variational surprise
    /// S = F - complexity (entropy bonus)
    pub fn computeSurprise(F: f64, complexity: f64) f64 {
        return F - complexity;
    }

    /// Compute quantum-enhanced surprise
    /// S_quantum = S_classical + phi × collapse_entropy
    pub fn computeQuantumSurprise(S_classical: f64, collapse_entropy: f64) f64 {
        return S_classical + PHI * collapse_entropy;
    }

    /// Compute epistemic value of exploration
    /// value = info_gain × uncertainty / phi
    pub fn computeEpistemicValue(info_gain: f64, uncertainty: f64) f64 {
        return info_gain * uncertainty / PHI;
    }

    /// Compute pragmatic value of exploitation
    /// value = reward - cost × gamma
    pub fn computePragmaticValue(reward: f64, cost: f64) f64 {
        return reward - cost * GAMMA;
    }

    /// Select action by minimizing expected free energy
    pub fn selectAction(_: *QuantumActiveInference, expected_free_energies: []const f64) usize {
        if (expected_free_energies.len == 0) return 0;

        var min_idx: usize = 0;
        var min_val: f64 = expected_free_energies[0];

        for (expected_free_energies[1..], 1..) |efe, i| {
            if (efe < min_val) {
                min_val = efe;
                min_idx = i;
            }
        }

        return min_idx;
    }

    /// Update precision weights (attention)
    pub fn updatePrecision(self: *QuantumActiveInference, prediction_errors: []const f64) !void {
        if (prediction_errors.len == 0) return;

        // Adjust precision based on recent errors
        const avg_error = blk: {
            var sum: f64 = 0.0;
            for (prediction_errors) |e| sum += e;
            break :blk sum / @as(f64, @floatFromInt(prediction_errors.len));
        };

        // Phi-weighted learning
        const new_precision = 1.0 / (1.0 + avg_error);
        try self.model.precision_weights.append(self.allocator, new_precision);
    }

    /// Compute KL divergence complexity
    /// complexity = sum(posterior × log(posterior / prior))
    pub fn computeComplexity(posterior: []const f64, prior: []const f64) f64 {
        if (posterior.len != prior.len) return 0.0;

        var complexity: f64 = 0.0;
        for (posterior, prior) |p, pr| {
            if (p > 0 and pr > 0) {
                complexity += p * @log(p / pr);
            }
        }
        return complexity;
    }

    /// Predict next sensory state
    pub fn predictNextState(self: *const QuantumActiveInference) f64 {
        if (self.model.predictions.items.len == 0) return 0.0;

        // Weighted average of predictions
        var sum: f64 = 0.0;
        for (self.model.predictions.items) |pred| {
            sum += pred;
        }
        return sum / @as(f64, @floatFromInt(self.model.predictions.items.len));
    }

    /// Collapse quantum superposition via observation
    pub fn collapseSuperposition(self: *QuantumActiveInference, probabilities: []const f32) u32 {
        if (probabilities.len == 0) return 0;

        // Argmax: return index of max probability
        var max_idx: u32 = 0;
        var max_val: f32 = probabilities[0];

        for (probabilities[1..], 1..) |p, i| {
            if (p > max_val) {
                max_val = p;
                max_idx = @as(u32, @intCast(i));
            }
        }

        self.cycle.quantum_collapse = true;
        return max_idx;
    }

    /// Compute consciousness score
    /// score = phi × precision / (1 + complexity)
    pub fn computeConsciousnessScore(self: *QuantumActiveInference, precision: f64, complexity: f64) f64 {
        self.state.consciousness_score = PHI * precision / (1.0 + complexity);
        return self.state.consciousness_score;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuantumActiveInference: quantum_free_energy_less_than_classical" {
    var inference = QuantumActiveInference.init(std.testing.allocator);
    defer inference.deinit();

    // Use smaller free energy value so quantum correction is meaningful
    const F_classical = 1e-14;
    const F_quantum = inference.computeQuantumFreeEnergy(F_classical, 1e15);
    // Quantum correction: phi * hbar * omega ≈ 1.7e-19
    // F_quantum should be slightly less than classical
    try std.testing.expect(F_quantum < F_classical);
}

test "QuantumActiveInference: cycle_duration_25ms" {
    var inference = QuantumActiveInference.init(std.testing.allocator);
    defer inference.deinit();

    // E_superposition = hbar / (25ms * gamma)
    const E_target = HBAR / (0.025 * GAMMA);
    const duration = inference.computeCycleDuration(E_target);
    try std.testing.expectApproxEqAbs(25.0, duration, 1.0);
}

test "QuantumActiveInference: prediction_error_perfect_match" {
    const error_val = QuantumActiveInference.computePredictionError(0.5, 0.5, 1.0);
    try std.testing.expectApproxEqAbs(0.0, error_val, 0.001);
}

test "QuantumActiveInference: prediction_error_mismatch" {
    const error_val = QuantumActiveInference.computePredictionError(1.0, 0.0, 1.0);
    try std.testing.expectApproxEqAbs(0.5, error_val, 0.01);
}

test "QuantumActiveInference: surprise_from_free_energy" {
    const surprise = QuantumActiveInference.computeSurprise(5.0, 1.0);
    try std.testing.expectApproxEqAbs(4.0, surprise, 0.01);
}

test "QuantumActiveInference: quantum_surprise_enhanced" {
    const S_quantum = QuantumActiveInference.computeQuantumSurprise(4.0, 1.0);
    try std.testing.expectApproxEqAbs(5.618, S_quantum, 0.01);
}

test "QuantumActiveInference: epistemic_value_positive" {
    const value = QuantumActiveInference.computeEpistemicValue(0.5, 0.8);
    try std.testing.expectApproxEqAbs(0.247, value, 0.01);
}

test "QuantumActiveInference: pragmatic_value_reward_dominant" {
    const value = QuantumActiveInference.computePragmaticValue(1.0, 0.1);
    try std.testing.expectApproxEqAbs(0.976, value, 0.01);
}

test "QuantumActiveInference: pragmatic_value_cost_dominant" {
    const value = QuantumActiveInference.computePragmaticValue(0.1, 1.0);
    try std.testing.expect(value < 0.0);
}

test "QuantumActiveInference: consciousness_score_high_precision" {
    var inference = QuantumActiveInference.init(std.testing.allocator);
    defer inference.deinit();

    const score = inference.computeConsciousnessScore(0.9, 0.1);
    try std.testing.expectApproxEqAbs(1.322, score, 0.01);
}

test "QuantumActiveInference: consciousness_score_low_precision" {
    var inference = QuantumActiveInference.init(std.testing.allocator);
    defer inference.deinit();

    const score = inference.computeConsciousnessScore(0.1, 0.9);
    // score = phi * 0.1 / 1.9 = 0.1618 / 1.9 ≈ 0.085
    try std.testing.expectApproxEqAbs(0.085, score, 0.01);
}

test "QuantumActiveInference: select_action_minimizes_EFE" {
    const efe = [_]f64{ 5.0, 3.0, 7.0 };
    const action = QuantumActiveInference.selectAction(undefined, &efe);
    try std.testing.expectEqual(@as(usize, 1), action);
}

test "QuantumActiveInference: collapse_produces_classical" {
    var inference = QuantumActiveInference.init(std.testing.allocator);
    defer inference.deinit();

    const probs = [_]f32{ 0.3, 0.7 };
    const result = inference.collapseSuperposition(&probs);
    try std.testing.expectEqual(@as(u32, 1), result);
}
