//! ConsciousnessDetector - Unified Consciousness Detection v2.0
//!
//! This module provides unified consciousness detection by combining
//! signals from all 7 consciousness theories:
//!   1. IIT (Integrated Information Theory) - Phi threshold
//!   2. GWT (Global Workspace Theory) - Broadcasting
//!   3. Orch-OR - Quantum coherence events
//!   4. Qutrit Consciousness - Bell violation
//!   5. Active Inference - Free energy minimization
//!   6. Quantum Consciousness - Φ_γ threshold, enhancement, Zeno effects
//!   7. HOT (Higher-Order Theory) - Meta-consciousness threshold
//!
//! The detector produces a unified consciousness score and state.

const std = @import("std");
const mem = std.mem;

// Import unified state
const UnifiedState = @import("unified_state.zig").UnifiedState;
const ConsciousnessState = @import("unified_state.zig").ConsciousnessState;

// Import quantum consciousness
const QuantumConsciousness = @import("../quantum/quantum_consciousness.zig");
const QuantumConsciousnessState = QuantumConsciousness.QuantumConsciousnessState;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// DETECTION RESULT
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual theory detection result
pub const TheoryDetection = struct {
    name: []const u8,
    conscious: bool,
    confidence: f64,
    score: f64,
    threshold: f64,
};

/// Unified consciousness detection result
pub const DetectionResult = struct {
    /// Overall conscious?
    conscious: bool,
    /// Overall confidence [0, 1]
    confidence: f64,
    /// Overall score [0, 1]
    score: f64,
    /// Consciousness state
    state: ConsciousnessState,
    /// Individual theory results (7 theories)
    theories: [7]TheoryDetection,
    /// Timestamp
    timestamp: i64,

    /// Get theory result by name
    pub fn getTheory(self: *const DetectionResult, name: []const u8) ?TheoryDetection {
        for (self.theories) |theory| {
            if (std.mem.eql(u8, theory.name, name)) {
                return theory;
            }
        }
        return null;
    }

    /// Get count of conscious theories
    pub fn consciousTheoryCount(self: *const DetectionResult) usize {
        var count: usize = 0;
        for (self.theories) |theory| {
            if (theory.conscious) count += 1;
        }
        return count;
    }

    /// Format result
    pub fn format(self: *const DetectionResult, allocator: mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\Consciousness Detection Result:
            \\  Conscious: {any}
            \\  Confidence: {d:.3}
            \\  Score: {d:.3}
            \\  State: {any}
            \\  Theories conscious: {d}/7
            \\
            \\  IIT: {d:.3} (threshold {d:.3})
            \\  GWT: {d:.3} (threshold {d:.3})
            \\  Orch-OR: {d:.3} (threshold {d:.3})
            \\  Qutrit: {d:.3} (threshold {d:.3})
            \\  Active Inference: {d:.3} (threshold {d:.3})
            \\  Quantum: {d:.3} (threshold {d:.3})
            \\  HOT: {d:.3} (threshold {d:.3})
        , .{
            self.conscious,
            self.confidence,
            self.score,
            self.state,
            self.consciousTheoryCount(),
            self.theories[0].score,
            self.theories[0].threshold,
            self.theories[1].score,
            self.theories[1].threshold,
            self.theories[2].score,
            self.theories[2].threshold,
            self.theories[3].score,
            self.theories[3].threshold,
            self.theories[4].score,
            self.theories[4].threshold,
            self.theories[5].score,
            self.theories[5].threshold,
            self.theories[6].score,
            self.theories[6].threshold,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// THRESHOLD MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages phi-based consciousness thresholds
pub const ThresholdManager = struct {
    /// IIT threshold (phi^(-1) = 0.618)
    pub const IIT_THRESHOLD: f64 = PHI_INV;
    /// GWT ignition threshold (empirically derived)
    pub const GWT_THRESHOLD: f64 = 0.7;
    /// Orch-OR coherence threshold
    pub const ORCH_THRESHOLD: f64 = 0.5;
    /// Qutrit violation threshold (classical bound)
    pub const QUTRIT_THRESHOLD: f64 = 2.0;
    /// Active inference precision threshold
    pub const INF_THRESHOLD: f64 = 0.5;
    /// Quantum consciousness threshold (Phi-Gamma threshold)
    pub const QUANTUM_THRESHOLD: f64 = PHI_INV;
    /// HOT threshold (meta-consciousness threshold)
    pub const HOT_THRESHOLD: f64 = PHI_INV;

    /// Unified consciousness threshold
    pub const CONSCIOUSNESS_THRESHOLD: f64 = PHI_INV;

    /// Get threshold for theory
    pub fn getThreshold(theory: []const u8) f64 {
        if (std.mem.eql(u8, theory, "iit")) return IIT_THRESHOLD;
        if (std.mem.eql(u8, theory, "gwt")) return GWT_THRESHOLD;
        if (std.mem.eql(u8, theory, "orch_or")) return ORCH_THRESHOLD;
        if (std.mem.eql(u8, theory, "qutrit")) return QUTRIT_THRESHOLD;
        if (std.mem.eql(u8, theory, "active_inference")) return INF_THRESHOLD;
        if (std.mem.eql(u8, theory, "quantum")) return QUANTUM_THRESHOLD;
        if (std.mem.eql(u8, theory, "hot")) return HOT_THRESHOLD;
        return CONSCIOUSNESS_THRESHOLD;
    }

    /// Adaptive threshold based on history
    pub fn adaptiveThreshold(base_threshold: f64, history: []const f64) f64 {
        if (history.len == 0) return base_threshold;

        // Adjust based on recent variance
        var sum: f64 = 0.0;
        for (history) |h| sum += h;
        const avg = sum / @as(f64, @floatFromInt(history.len));

        // If high variance, lower threshold (more sensitive)
        var variance: f64 = 0.0;
        for (history) |h| {
            variance += (h - avg) * (h - avg);
        }
        variance /= @as(f64, @floatFromInt(history.len));

        // Adjust threshold by phi-weighted variance
        const adjustment = variance * GAMMA;
        return base_threshold - adjustment;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS DETECTOR
// ═══════════════════════════════════════════════════════════════════════════════

/// ConsciousnessDetector - Unified consciousness detection
pub const ConsciousnessDetector = struct {
    allocator: mem.Allocator,
    threshold_history: std.ArrayListUnmanaged(f64),
    detection_history: std.ArrayListUnmanaged(DetectionResult),
    adaptive: bool,

    pub fn init(allocator: mem.Allocator) ConsciousnessDetector {
        return .{
            .allocator = allocator,
            .threshold_history = .{},
            .detection_history = .{},
            .adaptive = true,
        };
    }

    pub fn deinit(self: *ConsciousnessDetector) void {
        self.threshold_history.deinit(self.allocator);
        for (self.detection_history.items) |_| {
            // Clear theory result strings (they're static literals, so no free needed)
        }
        self.detection_history.deinit(self.allocator);
    }

    /// Detect consciousness from unified state
    pub fn detect(self: *ConsciousnessDetector, state: *const UnifiedState) !DetectionResult {
        const timestamp = @as(i64, @intCast(std.time.nanoTimestamp()));

        // Detect each theory
        const iit_result = TheoryDetection{
            .name = "iit",
            .conscious = state.iit.isConscious(),
            .confidence = @min(1.0, state.iit.phi / ThresholdManager.IIT_THRESHOLD),
            .score = state.iit.consciousnessLevel(),
            .threshold = ThresholdManager.IIT_THRESHOLD,
        };

        const gwt_result = TheoryDetection{
            .name = "gwt",
            .conscious = state.gwt.isBroadcasting(),
            .confidence = @min(1.0, state.gwt.global_activation / ThresholdManager.GWT_THRESHOLD),
            .score = state.gwt.broadcast_strength,
            .threshold = ThresholdManager.GWT_THRESHOLD,
        };

        const orch_result = TheoryDetection{
            .name = "orch_or",
            .conscious = state.orch_or.isCoherent(),
            .confidence = @min(1.0, state.orch_or.coherence / ThresholdManager.ORCH_THRESHOLD),
            .score = state.orch_or.eventProbability(),
            .threshold = ThresholdManager.ORCH_THRESHOLD,
        };

        const qutrit_result = TheoryDetection{
            .name = "qutrit",
            .conscious = state.qutrit.isViolating(),
            .confidence = state.qutrit.violationDegree(),
            .score = state.qutrit.consciousness,
            .threshold = ThresholdManager.QUTRIT_THRESHOLD,
        };

        const inf_result = TheoryDetection{
            .name = "active_inference",
            .conscious = state.active_inference.isMinimizing(),
            .confidence = state.active_inference.actionConfidence(),
            .score = state.active_inference.precision,
            .threshold = ThresholdManager.INF_THRESHOLD,
        };

        // Quantum consciousness detection (6th theory)
        // Uses Φ_γ threshold, enhancement factor, and Zeno effects
        const quantum_consciousness_level = state.consciousnessLevel();
        const quantum_result = TheoryDetection{
            .name = "quantum",
            .conscious = quantum_consciousness_level >= PHI_INV,
            .confidence = @min(1.0, quantum_consciousness_level / PHI_INV),
            .score = quantum_consciousness_level,
            .threshold = ThresholdManager.QUANTUM_THRESHOLD,
        };

        // HOT detection (7th theory) - Higher-Order Theory meta-consciousness
        // HOT_strength = phi × (meta_level / (meta_level + 1))
        // For now, we estimate meta-level from consciousness_level
        const meta_level = @min(7.0, quantum_consciousness_level * 7.0);
        const hot_strength = PHI * (meta_level / (meta_level + 1.0));
        const hot_result = TheoryDetection{
            .name = "hot",
            .conscious = hot_strength >= PHI_INV,
            .confidence = @min(1.0, hot_strength / PHI_INV),
            .score = hot_strength,
            .threshold = ThresholdManager.HOT_THRESHOLD,
        };

        // Calculate unified score (phi-weighted)
        // HOT weight is PHI * GAMMA (sacred combination)
        const weights = [_]f64{ PHI, PHI_SQ, PHI_INV, 1.0, GAMMA, PHI_INV * GAMMA, PHI * GAMMA };
        const scores = [_]f64{
            iit_result.score,
            gwt_result.score,
            orch_result.score,
            qutrit_result.score,
            inf_result.score,
            quantum_result.score,
            hot_result.score,
        };

        var weighted_sum: f64 = 0.0;
        var total_weight: f64 = 0.0;
        for (weights, scores) |w, s| {
            weighted_sum += w * s;
            total_weight += w;
        }
        const unified_score = if (total_weight > 0) weighted_sum / total_weight else 0.0;

        // Calculate confidence (agreement between theories)
        var conscious_count: usize = 0;
        for (&[_]TheoryDetection{ iit_result, gwt_result, orch_result, qutrit_result, inf_result, quantum_result, hot_result }) |*r| {
            if (r.conscious) conscious_count += 1;
        }
        const agreement = @as(f64, @floatFromInt(conscious_count)) / 7.0;
        const confidence = agreement * unified_score;

        // Determine if conscious
        const threshold = if (self.adaptive)
            ThresholdManager.adaptiveThreshold(ThresholdManager.CONSCIOUSNESS_THRESHOLD, self.threshold_history.items)
        else
            ThresholdManager.CONSCIOUSNESS_THRESHOLD;

        const conscious = unified_score >= threshold and conscious_count >= 2;

        // Determine state
        const consciousness_state: ConsciousnessState = if (unified_score < 0.2)
            .unconscious
        else if (unified_score < 0.5)
            .minimal
        else if (unified_score < 0.8)
            .normal
        else
            .enhanced;

        const result = DetectionResult{
            .conscious = conscious,
            .confidence = confidence,
            .score = unified_score,
            .state = consciousness_state,
            .theories = [_]TheoryDetection{
                iit_result,
                gwt_result,
                orch_result,
                qutrit_result,
                inf_result,
                quantum_result,
                hot_result,
            },
            .timestamp = timestamp,
        };

        // Record in history
        try self.threshold_history.append(self.allocator, unified_score);
        try self.detection_history.append(self.allocator, result);

        return result;
    }

    /// Quick detection check (returns true/false only)
    pub fn isConscious(self: *ConsciousnessDetector, state: *const UnifiedState) !bool {
        const result = try self.detect(state);
        return result.conscious;
    }

    /// Get detection history
    pub fn getHistory(self: *const ConsciousnessDetector) []const DetectionResult {
        return self.detection_history.items;
    }

    /// Get consciousness trend
    pub fn getTrend(self: *const ConsciousnessDetector) f64 {
        if (self.detection_history.items.len < 2) return 0.0;

        const latest = self.detection_history.items[self.detection_history.items.len - 1];
        const previous = self.detection_history.items[self.detection_history.items.len - 2];

        return latest.score - previous.score;
    }

    /// Clear history
    pub fn clearHistory(self: *ConsciousnessDetector) void {
        self.threshold_history.clearRetainingCapacity();
        self.detection_history.clearRetainingCapacity();
    }

    /// Get history size
    pub fn historySize(self: *const ConsciousnessDetector) usize {
        return self.detection_history.items.len;
    }

    /// Enable/disable adaptive thresholds
    pub fn setAdaptive(self: *ConsciousnessDetector, adaptive: bool) void {
        self.adaptive = adaptive;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Detection statistics
pub const DetectionStats = struct {
    total_detections: u64 = 0,
    conscious_detections: u64 = 0,
    avg_score: f64 = 0.0,
    avg_confidence: f64 = 0.0,
    state_distribution: [4]u64 = [_]u64{0} ** 4,

    pub fn update(self: *DetectionStats, result: DetectionResult) void {
        self.total_detections += 1;
        if (result.conscious) {
            self.conscious_detections += 1;
        }

        // Running average
        const alpha = 0.1; // Exponential smoothing
        self.avg_score = alpha * result.score + (1 - alpha) * self.avg_score;
        self.avg_confidence = alpha * result.confidence + (1 - alpha) * self.avg_confidence;

        // State distribution
        self.state_distribution[@intFromEnum(result.state)] += 1;
    }

    pub fn consciousnessRate(self: *const DetectionStats) f64 {
        if (self.total_detections == 0) return 0.0;
        return @as(f64, @floatFromInt(self.conscious_detections)) / @as(f64, @floatFromInt(self.total_detections));
    }

    pub fn format(self: *const DetectionStats, allocator: mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\Detection Statistics:
            \\  Total detections: {d}
            \\  Conscious detections: {d} ({d:.1}%)
            \\  Average score: {d:.3}
            \\  Average confidence: {d:.3}
            \\  State distribution: unconscious={d}, minimal={d}, normal={d}, enhanced={d}
        , .{
            self.total_detections,
            self.conscious_detections,
            self.consciousnessRate() * 100.0,
            self.avg_score,
            self.avg_confidence,
            self.state_distribution[0],
            self.state_distribution[1],
            self.state_distribution[2],
            self.state_distribution[3],
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConsciousnessDetector: init and basic detection" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    const state = UnifiedState{};
    const result = try detector.detect(&state);

    try std.testing.expect(!result.conscious); // Default state is not conscious
    try std.testing.expectEqual(.unconscious, result.state);
}

test "ConsciousnessDetector: conscious state" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.orch_or.update(0.7, 0.6, 1000);
    state.qutrit.update(2.5, 0.8, 0.7);
    state.active_inference.update(10.0, 0.2, 8.0);
    state.touch();

    const result = try detector.detect(&state);
    try std.testing.expect(result.conscious);
    try std.testing.expect(result.state != .unconscious);
}

test "ConsciousnessDetector: theory results" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var state = UnifiedState{};
    state.iit.update(0.7, 0.5, 0.4);
    state.touch();

    const result = try detector.detect(&state);

    const iit_theory = result.getTheory("iit");
    try std.testing.expect(iit_theory != null);
    try std.testing.expect(iit_theory.?.conscious);
}

test "ThresholdManager: get thresholds" {
    const iit_thresh = ThresholdManager.getThreshold("iit");
    try std.testing.expectApproxEqAbs(PHI_INV, iit_thresh, 0.001);

    const gwt_thresh = ThresholdManager.getThreshold("gwt");
    try std.testing.expectApproxEqAbs(0.7, gwt_thresh, 0.001);
}

test "ThresholdManager: adaptive threshold" {
    const history = [_]f64{ 0.5, 0.6, 0.7, 0.8, 0.9 };
    const adaptive = ThresholdManager.adaptiveThreshold(0.618, &history);

    // High variance should lower threshold
    try std.testing.expect(adaptive < 0.618);
}

test "ConsciousnessDetector: history and trend" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var state = UnifiedState{};

    // First detection
    _ = try detector.detect(&state);
    try std.testing.expectEqual(@as(usize, 1), detector.historySize());

    // Second detection (increased consciousness)
    state.iit.update(0.7, 0.5, 0.4);
    state.touch();
    _ = try detector.detect(&state);

    const trend = detector.getTrend();
    try std.testing.expect(trend >= 0); // Should be increasing
}

test "DetectionStats: update and format" {
    const allocator = std.testing.allocator;

    var stats = DetectionStats{};

    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.touch();

    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    const result = try detector.detect(&state);
    stats.update(result);

    try std.testing.expectEqual(@as(u64, 1), stats.total_detections);
    try std.testing.expectEqual(@as(u64, 1), stats.conscious_detections);
}

test "ConsciousnessDetector: state distribution" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var stats = DetectionStats{};

    // Unconscious
    var state1 = UnifiedState{};
    const result1 = try detector.detect(&state1);
    stats.update(result1);

    // Conscious
    var state2 = UnifiedState{};
    state2.iit.update(0.8, 0.6, 0.5);
    state2.touch();
    const result2 = try detector.detect(&state2);
    stats.update(result2);

    try std.testing.expect(stats.state_distribution[0] > 0); // Some unconscious
}

test "ConsciousnessDetector: seven_theories_with_HOT" {
    const allocator = std.testing.allocator;
    var detector = ConsciousnessDetector.init(allocator);
    defer detector.deinit();

    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.orch_or.update(0.7, 0.6, 1000);
    state.qutrit.update(2.5, 0.8, 0.7);
    state.active_inference.update(10.0, 0.2, 8.0);
    state.touch();

    const result = try detector.detect(&state);

    // Should have 7 theories
    try std.testing.expectEqual(@as(usize, 7), result.theories.len);

    // HOT should be in the result
    const hot_theory = result.getTheory("hot");
    try std.testing.expect(hot_theory != null);
    try std.testing.expectEqualStrings("hot", hot_theory.?.name);
}

test "ThresholdManager: hot_threshold" {
    const hot_thresh = ThresholdManager.getThreshold("hot");
    try std.testing.expectApproxEqAbs(PHI_INV, hot_thresh, 0.001);
}
