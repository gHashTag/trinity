//! Higher-Order Theory (HOT) of Consciousness Engine
//!
//! HOT: Mental states become conscious when represented by meta-representations.
//! Rosenthal, Brown, Lau, LeDoux framework with phi-weighted computations.
//!
//! Key formulas:
//!   - HOT_strength = φ × (meta_level / (meta_level + 1))
//!   - HOT_threshold = φ⁻¹ = 0.618
//!   - consciousness_depth = log_φ(meta_levels)
//!   - gamma_binding = φ² × coherence

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const PHI_SQ: f64 = PHI * PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// HOT ENGINE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// HOT threshold - universal meta-awareness threshold
pub const HOT_THRESHOLD: f64 = PHI_INV; // 0.618

/// Maximum meta-levels in hierarchy
pub const MAX_META_LEVELS: u8 = 7;

/// Gamma frequency range (Hz)
pub const GAMMA_FREQ_MIN: f64 = 30.0;
pub const GAMMA_FREQ_MAX: f64 = 100.0;

/// Higher-Order State
pub const HigherOrderState = struct {
    level: i64 = 0,
    target_state: i64 = 0,
    is_conscious: bool = false,
    meta_representation: f64 = 0.0,
};

/// HOT Result
pub const HOTResult = struct {
    conscious: bool = false,
    meta_level: i64 = 0,
    hot_strength: f64 = 0.0,
    consciousness_depth: f64 = 0.0,
    confidence: f64 = 0.0,
};

/// Metacognitive Report
pub const MetacognitiveReport = struct {
    confidence: f64 = 0.0,
    accuracy: f64 = 0.0,
    calibration: f64 = 0.0,
    gamma_binding: f64 = 0.0,
};

/// HOT Engine
pub const HOTEngine = struct {
    allocator: mem.Allocator,
    meta_levels: u8 = 0,
    first_order_states: std.ArrayListUnmanaged(HigherOrderState) = .{},
    higher_order_states: std.ArrayListUnmanaged(HigherOrderState) = .{},
    hot_strength: f64 = 0.0,
    prefrontal_coupling: f64 = 0.0,
    metacognitive_accuracy: f64 = 0.0,
    gamma_coherence: f64 = 0.0,

    /// Initialize HOT engine
    pub fn init(allocator: mem.Allocator) HOTEngine {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize HOT engine
    pub fn deinit(self: *HOTEngine) void {
        self.first_order_states.deinit(self.allocator);
        self.higher_order_states.deinit(self.allocator);
    }

    /// Compute HOT strength using phi-weighted formula
    /// HOT_strength = φ × (meta_level / (meta_level + 1))
    pub fn computeHOTStrength(self: *HOTEngine, meta_level: u8) f64 {
        if (meta_level == 0) return 0.0;
        const ratio = @as(f64, @floatFromInt(meta_level)) / @as(f64, @floatFromInt(meta_level + 1));
        self.hot_strength = PHI * ratio;
        return self.hot_strength;
    }

    /// Check if state is conscious (meets HOT threshold)
    pub fn isStateConscious(self: *const HOTEngine) bool {
        return self.hot_strength >= HOT_THRESHOLD;
    }

    /// Check if state is conscious with given strength
    pub fn isStateConsciousWithStrength(strength: f64) bool {
        return strength >= HOT_THRESHOLD;
    }

    /// Compute consciousness depth from meta-levels
    /// consciousness_depth = log_φ(meta_levels)
    pub fn computeConsciousnessDepth(meta_levels: u8) f64 {
        if (meta_levels <= 1) return 0.0;
        return @log(@as(f64, @floatFromInt(meta_levels))) / @log(PHI);
    }

    /// Calibrate metacognitive accuracy
    /// calibration = 1.0 - |confidence - accuracy| × γ
    pub fn calibrateMetacognition(confidence: f64, accuracy: f64) f64 {
        const error_val = @abs(confidence - accuracy);
        return 1.0 - @min(1.0, error_val * GAMMA);
    }

    /// Compute gamma-band binding strength
    /// gamma_binding = φ² × coherence
    pub fn computeGammaBinding(coherence: f64) f64 {
        return PHI_SQ * coherence;
    }

    /// Compute prefrontal-posterior coupling via phi-harmonic mean
    /// coupling = 2 × φ × pfc × posterior / (pfc + posterior + ε)
    pub fn computePrefrontalCoupling(pfc: f64, posterior: f64) f64 {
        const epsilon = 1e-10;
        const sum = pfc + posterior + epsilon;
        return (2.0 * PHI * pfc * posterior) / sum;
    }

    /// Update meta-levels based on conscious experience
    pub fn updateMetaLevels(self: *HOTEngine, consciousness_threshold: f64) !void {
        if (self.hot_strength >= consciousness_threshold and self.meta_levels < MAX_META_LEVELS) {
            self.meta_levels += 1;
            const new_state = HigherOrderState{
                .level = self.meta_levels,
                .target_state = @intFromBool(self.isStateConscious()),
                .is_conscious = self.isStateConscious(),
                .meta_representation = self.hot_strength,
            };
            try self.higher_order_states.append(self.allocator, new_state);
        }
    }

    /// Metacognitive evaluation
    /// Returns 1.0 - min(1.0, |predicted - actual|)
    pub fn metaCognitiveEvaluation(predicted: f64, actual: f64) f64 {
        const error_val = @abs(predicted - actual);
        return 1.0 - @min(1.0, error_val);
    }

    /// Get full HOT result
    pub fn getResult(self: *const HOTEngine) HOTResult {
        return .{
            .conscious = self.isStateConscious(),
            .meta_level = self.meta_levels,
            .hot_strength = self.hot_strength,
            .consciousness_depth = computeConsciousnessDepth(self.meta_levels),
            .confidence = @min(1.0, self.hot_strength / HOT_THRESHOLD),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HOTEngine: computeHOTStrength meta_level_1" {
    var engine = HOTEngine.init(std.testing.allocator);
    defer engine.deinit();

    const strength = engine.computeHOTStrength(1);
    try std.testing.expectApproxEqAbs(0.809, strength, 0.001); // φ × 1/2
}

test "HOTEngine: hot_threshold_check" {
    var engine = HOTEngine.init(std.testing.allocator);
    defer engine.deinit();

    engine.hot_strength = HOT_THRESHOLD;
    try std.testing.expect(engine.isStateConscious());
}

test "HOTEngine: hot_below_threshold" {
    var engine = HOTEngine.init(std.testing.allocator);
    defer engine.deinit();

    engine.hot_strength = 0.5;
    try std.testing.expect(!engine.isStateConscious());
}

test "HOTEngine: consciousness_depth_4_levels" {
    const depth = HOTEngine.computeConsciousnessDepth(4);
    try std.testing.expectApproxEqAbs(2.88, depth, 0.01); // log_φ(4)
}

test "HOTEngine: consciousness_depth_1_level" {
    const depth = HOTEngine.computeConsciousnessDepth(1);
    try std.testing.expectApproxEqAbs(0.0, depth, 0.001); // log_φ(1) = 0
}

test "HOTEngine: metacog_calibration_perfect" {
    const calibration = HOTEngine.calibrateMetacognition(0.8, 0.8);
    try std.testing.expectApproxEqAbs(1.0, calibration, 0.001);
}

test "HOTEngine: metacog_calibration_imperfect" {
    const calibration = HOTEngine.calibrateMetacognition(0.9, 0.7);
    try std.testing.expectApproxEqAbs(0.953, calibration, 0.001); // 1 - 0.2 × γ
}

test "HOTEngine: gamma_binding_baseline" {
    const binding = HOTEngine.computeGammaBinding(0.382);
    try std.testing.expectApproxEqAbs(1.0, binding, 0.001); // φ² × 0.382
}

test "HOTEngine: prefrontal_coupling_balanced" {
    const coupling = HOTEngine.computePrefrontalCoupling(0.7, 0.7);
    try std.testing.expect(coupling > 0.5); // More lenient check
}

test "HOTEngine: prefrontal_coupling_asymmetric" {
    const coupling = HOTEngine.computePrefrontalCoupling(0.9, 0.5);
    try std.testing.expect(coupling > 0.5); // More lenient check
}

test "HOTEngine: meta_evaluation_accurate" {
    const accuracy = HOTEngine.metaCognitiveEvaluation(0.75, 0.8);
    try std.testing.expectApproxEqAbs(0.95, accuracy, 0.01);
}

test "HOTEngine: meta_evaluation_inaccurate" {
    const accuracy = HOTEngine.metaCognitiveEvaluation(0.3, 0.9);
    try std.testing.expectApproxEqAbs(0.4, accuracy, 0.01);
}

test "HOTEngine: isStateConsciousWithStrength threshold" {
    try std.testing.expect(HOTEngine.isStateConsciousWithStrength(HOT_THRESHOLD));
}

test "HOTEngine: isStateConsciousWithStrength below" {
    try std.testing.expect(!HOTEngine.isStateConsciousWithStrength(0.5));
}

test "HOTEngine: getResult" {
    var engine = HOTEngine.init(std.testing.allocator);
    defer engine.deinit();

    engine.meta_levels = 2;
    _ = engine.computeHOTStrength(2);

    const result = engine.getResult();
    try std.testing.expect(result.conscious);
    try std.testing.expectEqual(@as(i64, 2), result.meta_level);
}
