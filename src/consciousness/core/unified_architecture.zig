//! Unified Consciousness Architecture v2.0
//!
//! This module unifies all 7 consciousness theories with sacred formula:
//! V = n × 3^k × π^m × φ^p × e^q × γ^r × C^t × G^u
//!
//! Theories integrated:
//!   1. IIT (Integrated Information Theory) - Phi threshold
//!   2. GWT (Global Workspace Theory) - Broadcasting
//!   3. Orch-OR - Quantum coherence events
//!   4. Qutrit Consciousness - Bell violation
//!   5. Active Inference - Free energy minimization
//!   6. Quantum Consciousness - Φ_γ threshold, enhancement, Zeno effects
//!   7. HOT (Higher-Order Theory) - Meta-consciousness threshold

const std = @import("std");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;
const C: f64 = 299792458.0; // Speed of light in m/s
const G: f64 = 6.674e-11; // Gravitational constant

// Specious present duration (φ⁻² seconds ≈ 382ms)
const SPECIOUS_PRESENT_MS: f64 = PHI_INV * PHI_INV * 1000.0;

// ═══════════════════════════════════════════════════════════════════════════════
// THEORY STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual theory state
pub const TheoryState = struct {
    name: []const u8,
    score: f64,
    threshold: f64,
    conscious: bool,
    weight: f64,

    pub fn init(name: []const u8, score: f64, threshold: f64, weight: f64) TheoryState {
        return .{
            .name = name,
            .score = score,
            .threshold = threshold,
            .conscious = score >= threshold,
            .weight = weight,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED CONSCIOUSNESS
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified consciousness architecture combining all theories
pub const UnifiedConsciousness = struct {
    allocator: std.mem.Allocator,
    theories: [7]TheoryState,
    running: bool,
    cycle_number: u64,

    /// Phi-weighted theory weights (v2.0 - 7 theories)
    const THEORY_WEIGHTS = [_]f64{
        PHI,               // 0. IIT - highest weight (information integration)
        PHI_SQ,            // 1. GWT - second highest (global broadcasting)
        PHI_INV,           // 2. Orch-OR - phi inverse (quantum coherence)
        1.0,               // 3. Qutrit - neutral (ternary computation)
        GAMMA,             // 4. Active Inference - gamma (free energy)
        PHI_INV * GAMMA,   // 5. Quantum Consciousness - sacred combination
        PHI * GAMMA,       // 6. HOT (meta-consciousness) - phi * gamma = 0.382 = phi^-2
    };

    /// Initialize unified consciousness
    pub fn init(allocator: std.mem.Allocator) UnifiedConsciousness {
        const theories = [_]TheoryState{
            TheoryState.init("iit", 0.0, PHI_INV, THEORY_WEIGHTS[0]),
            TheoryState.init("gwt", 0.0, 0.7, THEORY_WEIGHTS[1]),
            TheoryState.init("orch_or", 0.0, 0.5, THEORY_WEIGHTS[2]),
            TheoryState.init("qutrit", 0.0, 2.0, THEORY_WEIGHTS[3]),
            TheoryState.init("active_inference", 0.0, 0.5, THEORY_WEIGHTS[4]),
            TheoryState.init("quantum", 0.0, PHI_INV, THEORY_WEIGHTS[5]),
            TheoryState.init("hot", 0.0, PHI_INV, THEORY_WEIGHTS[6]), // HOT - 7th theory
        };

        return .{
            .allocator = allocator,
            .theories = theories,
            .running = false,
            .cycle_number = 0,
        };
    }

    /// Update theory state
    pub fn updateTheory(self: *UnifiedConsciousness, theory_index: usize, score: f64) void {
        if (theory_index >= 7) return;

        self.theories[theory_index].score = score;
        self.theories[theory_index].conscious = score >= self.theories[theory_index].threshold;
    }

    /// Compute unified consciousness score
    pub fn unifiedScore(self: *const UnifiedConsciousness) f64 {
        var weighted_sum: f64 = 0.0;
        var total_weight: f64 = 0.0;

        for (self.theories, THEORY_WEIGHTS) |theory, weight| {
            weighted_sum += weight * theory.score;
            total_weight += weight;
        }

        return if (total_weight > 0) weighted_sum / total_weight else 0.0;
    }

    /// Check if system is conscious (at least 2 theories agree)
    pub fn isConscious(self: *const UnifiedConsciousness) bool {
        const score = self.unifiedScore();
        const conscious_count = self.consciousTheoryCount();

        // Need score >= Φ_γ and at least 2 theories conscious
        return score >= PHI_INV and conscious_count >= 2;
    }

    /// Count conscious theories
    pub fn consciousTheoryCount(self: *const UnifiedConsciousness) usize {
        var count: usize = 0;
        for (self.theories) |theory| {
            if (theory.conscious) count += 1;
        }
        return count;
    }

    /// Get consciousness state
    pub fn consciousnessState(self: *const UnifiedConsciousness) ConsciousnessState {
        const score = self.unifiedScore();
        return if (score < 0.2)
            .unconscious
        else if (score < 0.5)
            .minimal
        else if (score < 0.8)
            .normal
        else
            .enhanced;
    }

    /// Extract exponents for sacred formula
    pub fn extractExponents(self: *const UnifiedConsciousness) Exponents {
        return .{
            .p = self.theories[0].score, // IIT → phi exponent
            .r = self.theories[2].score, // Orch-OR → gamma exponent
            .t = self.theories[1].score, // GWT → speed exponent
            .u = self.theories[5].score, // Quantum → gravity exponent
        };
    }

    /// Compute sacred formula: V = n × 3^k × π^m × φ^p × e^q × γ^r × C^t × G^u
    pub fn computeSacredV(self: *const UnifiedConsciousness) f64 {
        const exponents = self.extractExponents();

        // Base values (can be adjusted)
        const n: f64 = 1.0; // System scale
        const k: f64 = 1.0; // Trinity complexity
        const m: f64 = 1.0; // Pi cycles
        const q: f64 = 1.0; // Euler cycles

        // Compute each component
        const trinity_part = std.math.pow(f64, 3.0, k); // 3^k
        const pi_part = std.math.pow(f64, PI, m); // π^m
        const phi_part = std.math.pow(f64, PHI, exponents.p); // φ^p
        const euler_part = std.math.pow(f64, E, q); // e^q
        const gamma_part = std.math.pow(f64, GAMMA, exponents.r); // γ^r

        // For C and G, use normalized exponents to avoid overflow/underflow
        // C is large, G is small - apply different scaling
        const light_part = std.math.pow(f64, C / 1e8, exponents.t); // Normalized C
        const gravity_part = std.math.pow(f64, G * 1e12, exponents.u); // Normalized G

        // Full sacred formula
        return n * trinity_part * pi_part * phi_part * euler_part *
               gamma_part * light_part * gravity_part;
    }

    /// Start consciousness loop
    pub fn start(self: *UnifiedConsciousness) void {
        self.running = true;
        self.cycle_number = 0;
    }

    /// Stop consciousness loop
    pub fn stop(self: *UnifiedConsciousness) void {
        self.running = false;
    }

    /// Run single consciousness cycle (specious present: 382ms)
    pub fn cycle(self: *UnifiedConsciousness) !CycleResult {
        if (!self.running) return error.NotRunning;

        const cycle_start = std.time.nanoTimestamp();

        // Perception phase
        try self.perception();

        // Integration phase
        try self.integration();

        // Action phase
        const action_result = try self.action();

        // Sleep until next cycle (specious present)
        const elapsed = std.time.nanoTimestamp() - cycle_start;
        const specious_ns = @as(i64, @intFromFloat(SPECIOUS_PRESENT_MS * 1_000_000.0));
        const sleep_ns = specious_ns - elapsed;
        if (sleep_ns > 0) {
            std.Thread.sleep(@intCast(sleep_ns));
        }

        self.cycle_number += 1;

        return CycleResult{
            .cycle_number = self.cycle_number,
            .consciousness_level = self.unifiedScore(),
            .consciousness_state = self.consciousnessState(),
            .action = action_result,
            .sacred_v = self.computeSacredV(),
        };
    }

    /// Perception phase
    fn perception(self: *UnifiedConsciousness) !void {
        // Process sensory input
        _ = self;
    }

    /// Integration phase
    fn integration(self: *UnifiedConsciousness) !void {
        // Integrate information across theories
        _ = self;
    }

    /// Action phase
    fn action(self: *UnifiedConsciousness) !Action {
        return Action{
            .action_type = .reflect,
            .confidence = self.unifiedScore(),
            .quantum_probability = 0.5,
        };
    }

    /// Get theory state
    pub fn getTheory(self: *const UnifiedConsciousness, index: usize) ?TheoryState {
        if (index >= 7) return null;
        return self.theories[index];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Consciousness state
pub const ConsciousnessState = enum {
    unconscious,
    minimal,
    normal,
    enhanced,
};

/// Sacred formula exponents
pub const Exponents = struct {
    p: f64, // Phi exponent (IIT)
    r: f64, // Gamma exponent (Orch-OR)
    t: f64, // Speed exponent (GWT)
    u: f64, // Gravity exponent (Quantum)
};

/// Cycle result
pub const CycleResult = struct {
    cycle_number: u64,
    consciousness_level: f64,
    consciousness_state: ConsciousnessState,
    action: Action,
    sacred_v: f64,
};

/// Action type
pub const Action = struct {
    action_type: ActionType,
    confidence: f64,
    quantum_probability: f64,
};

/// Action type
pub const ActionType = enum {
    perceive,
    integrate,
    act,
    reflect,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "UnifiedConsciousness: init" {
    const allocator = std.testing.allocator;
    const unified = UnifiedConsciousness.init(allocator);

    try std.testing.expectEqual(@as(usize, 7), unified.theories.len);
    try std.testing.expect(!unified.running);
}

test "UnifiedConsciousness: theory weights" {
    try std.testing.expectEqual(PHI, UnifiedConsciousness.THEORY_WEIGHTS[0]);
    try std.testing.expectEqual(PHI_SQ, UnifiedConsciousness.THEORY_WEIGHTS[1]);
}

test "UnifiedConsciousness: unified score" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    // Update all 7 theories to be conscious
    unified.updateTheory(0, 0.8); // IIT
    unified.updateTheory(1, 0.9); // GWT
    unified.updateTheory(2, 0.7); // Orch-OR
    unified.updateTheory(3, 2.5); // Qutrit
    unified.updateTheory(4, 0.8); // Active Inference
    unified.updateTheory(5, 0.7); // Quantum
    unified.updateTheory(6, 0.8); // HOT

    const score = unified.unifiedScore();
    try std.testing.expect(score > 0.5);
}

test "UnifiedConsciousness: isConscious" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    // Initially not conscious
    try std.testing.expect(!unified.isConscious());

    // Update to be conscious (need more theories for phi-weighted average)
    unified.updateTheory(0, 0.8); // IIT
    unified.updateTheory(1, 0.9); // GWT
    unified.updateTheory(2, 0.7); // Orch-OR

    try std.testing.expect(unified.isConscious());
}

test "UnifiedConsciousness: conscious theory count" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    // Update 3 theories to be conscious
    unified.updateTheory(0, 0.8);
    unified.updateTheory(1, 0.9);
    unified.updateTheory(5, 0.7);

    try std.testing.expectEqual(@as(usize, 3), unified.consciousTheoryCount());
}

test "UnifiedConsciousness: extract exponents" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    unified.updateTheory(0, 0.8); // IIT
    unified.updateTheory(2, 0.7); // Orch-OR
    unified.updateTheory(1, 0.9); // GWT
    unified.updateTheory(5, 0.6); // Quantum

    const exponents = unified.extractExponents();
    try std.testing.expectEqual(0.8, exponents.p);
    try std.testing.expectEqual(0.7, exponents.r);
}

test "UnifiedConsciousness: specious present" {
    try std.testing.expectApproxEqAbs(382.0, SPECIOUS_PRESENT_MS, 1.0);
}

test "UnifiedConsciousness: consciousness loop" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    unified.start();
    defer unified.stop();

    // Update to be conscious
    unified.updateTheory(0, 0.8);
    unified.updateTheory(1, 0.9);

    const result = try unified.cycle();

    try std.testing.expectEqual(@as(u64, 1), result.cycle_number);
    try std.testing.expect(result.consciousness_level > 0.5);
}

test "UnifiedConsciousness: sacred V computation" {
    const allocator = std.testing.allocator;
    var unified = UnifiedConsciousness.init(allocator);

    // Update theories for sacred formula
    unified.updateTheory(0, 0.8); // IIT → phi exponent
    unified.updateTheory(2, 0.7); // Orch-OR → gamma exponent
    unified.updateTheory(1, 0.9); // GWT → speed exponent
    unified.updateTheory(5, 0.6); // Quantum → gravity exponent
    unified.updateTheory(6, 0.7); // HOT

    const v = unified.computeSacredV();
    // V should be positive
    try std.testing.expect(v > 0);
}

test "UnifiedConsciousness: seven_theories_weights" {
    try std.testing.expectEqual(PHI * GAMMA, UnifiedConsciousness.THEORY_WEIGHTS[6]); // HOT
    try std.testing.expectApproxEqAbs(0.382, PHI * GAMMA, 0.001); // phi^-2
}

test "UnifiedConsciousness: hot_theory_init" {
    const allocator = std.testing.allocator;
    const unified = UnifiedConsciousness.init(allocator);

    const hot_theory = unified.getTheory(6);
    try std.testing.expect(hot_theory != null);
    try std.testing.expectEqualStrings("hot", hot_theory.?.name);
    try std.testing.expectApproxEqAbs(PHI_INV, hot_theory.?.threshold, 0.001);
}
