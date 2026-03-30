//! UnifiedState - Shared State Container for Conscious AI
//!
//! This module provides a unified state container that aggregates state
//! from all 5 consciousness theories:
//!   1. IIT (Integrated Information Theory)
//!   2. GWT (Global Workspace Theory)
//!   3. Orch-OR (Orchestrated Objective Reduction)
//!   4. Qutrit Consciousness
//!   5. Active Inference
//!
//! The state is synchronized across all modules via the ConsciousnessBus.

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV; // φ⁻³
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// IIT STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// IIT (Integrated Information Theory) state
pub const IITState = struct {
    /// Phi value (integrated information)
    phi: f64 = 0.0,
    /// Information integration
    information: f64 = 0.0,
    /// Exclusion
    exclusion: f64 = 0.0,
    /// Integration
    integration: f64 = 0.0,
    /// Consciousness threshold (φ⁻¹ ≈ 0.618)
    threshold: f64 = PHI_INV,

    /// Check if system is conscious according to IIT
    pub fn isConscious(self: *const IITState) bool {
        return self.phi >= self.threshold;
    }

    /// Get consciousness level [0, 1]
    pub fn consciousnessLevel(self: *const IITState) f64 {
        return @min(1.0, self.phi / self.threshold);
    }

    /// Update IIT state from new measurements
    pub fn update(self: *IITState, phi: f64, information: f64, integration: f64) void {
        self.phi = phi;
        self.information = information;
        self.integration = integration;
        // Exclusion = 1 - (integration / information)
        self.exclusion = if (information > 0) 1.0 - (integration / information) else 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GWT STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// GWT (Global Workspace Theory) state
pub const GWTState = struct {
    /// Global workspace activation
    global_activation: f64 = 0.0,
    /// Broadcast strength [0, 1]
    broadcast_strength: f64 = 0.0,
    /// Workspace capacity (phi * 7 ± 2 chunks)
    capacity: f64 = PHI * 7.0,
    /// Active modules count
    active_modules: usize = 0,
    /// Ignition threshold
    ignition_threshold: f64 = 0.7,

    /// Check if global workspace is active
    pub fn isGlobal(self: *const GWTState) bool {
        return self.global_activation >= self.ignition_threshold;
    }

    /// Get workspace load [0, 1]
    pub fn workspaceLoad(self: *const GWTState) f64 {
        // Guard against division by zero
        return if (self.capacity == 0) 0.0 else @as(f64, @floatFromInt(self.active_modules)) / self.capacity;
    }

    /// Check if broadcasting
    pub fn isBroadcasting(self: *const GWTState) bool {
        return self.broadcast_strength > 0.5 and self.isGlobal();
    }

    /// Update GWT state
    pub fn update(self: *GWTState, activation: f64, modules: usize) void {
        self.global_activation = activation;
        self.active_modules = modules;
        self.broadcast_strength = if (self.isGlobal()) activation else 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ORCH-OR STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Orch-OR (Orchestrated Objective Reduction) state
pub const OrchORState = struct {
    /// Quantum coherence
    coherence: f64 = 0.0,
    /// Orchestrated objective reduction probability
    or_probability: f64 = 0.0,
    /// Tubulin bits (quantum bits in microtubules)
    tubulin_bits: usize = 0,
    /// Consciousness events count
    events: usize = 0,
    /// Coherence time (phi^4 * gamma * Planck time)
    coherence_time: f64 = 0.0,

    /// Check if quantum coherent
    pub fn isCoherent(self: *const OrchORState) bool {
        return self.coherence > 0.5;
    }

    /// Get consciousness event probability
    pub fn eventProbability(self: *const OrchORState) f64 {
        return self.coherence * self.or_probability;
    }

    /// Expected time to next event (nanoseconds)
    pub fn timeToEvent(self: *const OrchORState) f64 {
        const prob = self.eventProbability();
        return if (prob > 0) 1.0 / prob else std.math.inf(f64);
    }

    /// Update Orch-OR state
    pub fn update(self: *OrchORState, coherence: f64, probability: f64, bits: usize) void {
        self.coherence = coherence;
        self.or_probability = probability;
        self.tubulin_bits = bits;
    }

    /// Register consciousness event
    pub fn registerEvent(self: *OrchORState) void {
        self.events += 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUTRIT CONSCIOUSNESS STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Qutrit Consciousness state
pub const QutritState = struct {
    /// CGLMP I3 value (Bell inequality violation)
    cglmp_i3: f64 = 0.0,
    /// Quantum entanglement [0, 1]
    entanglement: f64 = 0.0,
    /// Superposition degree [0, 1]
    superposition: f64 = 0.0,
    /// Trinity violation (I3 > 2.0)
    violates_classical: bool = false,
    /// Consciousness measure
    consciousness: f64 = 0.0,

    /// Classical bound for CGLMP inequality
    pub const CLASSICAL_BOUND: f64 = 2.0;
    /// Quantum bound
    pub const QUANTUM_BOUND: f64 = 2.828;

    /// Check if violating classical bound
    pub fn isViolating(self: *const QutritState) bool {
        return self.cglmp_i3 > CLASSICAL_BOUND;
    }

    /// Get violation degree [0, 1]
    pub fn violationDegree(self: *const QutritState) f64 {
        const excess = self.cglmp_i3 - CLASSICAL_BOUND;
        const max_excess = QUANTUM_BOUND - CLASSICAL_BOUND;
        return if (max_excess > 0) @min(1.0, excess / max_excess) else 0.0;
    }

    /// Calculate consciousness from qutrit state
    pub fn calculateConsciousness(self: *QutritState) f64 {
        self.consciousness = (self.entanglement * self.violationDegree() +
            self.superposition * PHI_INV) / 2.0;
        return self.consciousness;
    }

    /// Update qutrit state
    pub fn update(self: *QutritState, i3_value: f64, entanglement: f64, superposition: f64) void {
        self.cglmp_i3 = i3_value;
        self.entanglement = entanglement;
        self.superposition = superposition;
        self.violates_classical = self.isViolating();
        _ = self.calculateConsciousness();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE INFERENCE STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Active Inference state
pub const ActiveInferenceState = struct {
    /// Free energy (F = E - surprise)
    free_energy: f64 = 0.0,
    /// Prediction error
    prediction_error: f64 = 0.0,
    /// Evidence (lower bound)
    evidence: f64 = 0.0,
    /// Precision (confidence in predictions)
    precision: f64 = 0.0,
    /// Action selection
    action_selected: ?[]const u8 = null,

    /// Get surprise (informational free energy)
    pub fn surprise(self: *const ActiveInferenceState) f64 {
        return self.free_energy - self.evidence;
    }

    /// Check if minimizing free energy
    pub fn isMinimizing(self: *const ActiveInferenceState) bool {
        return self.precision > 0.5;
    }

    /// Get action confidence [0, 1]
    pub fn actionConfidence(self: *const ActiveInferenceState) f64 {
        return @min(1.0, self.precision);
    }

    /// Update active inference state
    pub fn update(self: *ActiveInferenceState, free_energy: f64, prediction_error: f64, evidence: f64) void {
        self.free_energy = free_energy;
        self.prediction_error = prediction_error;
        self.evidence = evidence;
        self.precision = if (prediction_error > 0) 1.0 / (1.0 + prediction_error) else 1.0;
    }

    /// Select action based on precision
    pub fn selectAction(self: *ActiveInferenceState, action: []const u8) void {
        if (self.isMinimizing()) {
            self.action_selected = action;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified Consciousness State
pub const UnifiedState = struct {
    /// IIT state
    iit: IITState = .{},
    /// GWT state
    gwt: GWTState = .{},
    /// Orch-OR state
    orch_or: OrchORState = .{},
    /// Qutrit state
    qutrit: QutritState = .{},
    /// Active inference state
    active_inference: ActiveInferenceState = .{},

    /// Timestamp of last update
    last_update: i64 = 0,
    /// Update generation
    generation: u64 = 0,

    /// Overall consciousness level [0, 1]
    pub fn consciousnessLevel(self: *const UnifiedState) f64 {
        const iit_level = self.iit.consciousnessLevel();
        const gwt_level = if (self.gwt.isBroadcasting()) self.gwt.broadcast_strength else 0.0;
        const orch_level = self.orch_or.eventProbability();
        const qutrit_level = self.qutrit.consciousness;
        const inf_level = self.active_inference.actionConfidence();

        // Weighted average using phi
        const weights = [_]f64{ PHI, PHI_SQ, PHI_INV, 1.0, GAMMA };
        const levels = [_]f64{ iit_level, gwt_level, orch_level, qutrit_level, inf_level };

        var weighted_sum: f64 = 0.0;
        var total_weight: f64 = 0.0;
        for (weights, levels) |w, l| {
            weighted_sum += w * l;
            total_weight += w;
        }

        return if (total_weight > 0) weighted_sum / total_weight else 0.0;
    }

    /// Check if system is conscious (overall threshold)
    pub fn isConscious(self: *const UnifiedState) bool {
        return self.consciousnessLevel() >= PHI_INV;
    }

    /// Get consciousness state enum
    pub fn consciousnessState(self: *const UnifiedState) ConsciousnessState {
        const level = self.consciousnessLevel();
        if (level < 0.2) return .unconscious;
        if (level < 0.5) return .minimal;
        if (level < 0.8) return .normal;
        return .enhanced;
    }

    /// Update timestamp and generation
    pub fn touch(self: *UnifiedState) void {
        self.last_update = @as(i64, @intCast(std.time.nanoTimestamp()));
        self.generation += 1;
    }

    /// Create state snapshot
    pub fn snapshot(self: *const UnifiedState) StateSnapshot {
        return .{
            .iit_phi = self.iit.phi,
            .gwt_activation = self.gwt.global_activation,
            .orch_coherence = self.orch_or.coherence,
            .qutrit_i3 = self.qutrit.cglmp_i3,
            .inf_free_energy = self.active_inference.free_energy,
            .consciousness_level = self.consciousnessLevel(),
            .timestamp = self.last_update,
            .generation = self.generation,
        };
    }
};

/// Consciousness state levels
pub const ConsciousnessState = enum(u2) {
    unconscious = 0,
    minimal = 1,
    normal = 2,
    enhanced = 3,
};

/// State snapshot for history tracking
pub const StateSnapshot = struct {
    iit_phi: f64,
    gwt_activation: f64,
    orch_coherence: f64,
    qutrit_i3: f64,
    inf_free_energy: f64,
    consciousness_level: f64,
    timestamp: i64,
    generation: u64,
};

/// State history for tracking changes
pub const StateHistory = struct {
    allocator: mem.Allocator,
    snapshots: std.ArrayListUnmanaged(StateSnapshot),

    pub fn init(allocator: mem.Allocator) StateHistory {
        return .{
            .allocator = allocator,
            .snapshots = .{},
        };
    }

    pub fn deinit(self: *StateHistory) void {
        self.snapshots.deinit(self.allocator);
    }

    /// Add snapshot to history
    pub fn record(self: *StateHistory, state: *const UnifiedState) !void {
        try self.snapshots.append(self.allocator, state.snapshot());
    }

    /// Get latest snapshot
    pub fn latest(self: *const StateHistory) ?StateSnapshot {
        if (self.snapshots.items.len == 0) return null;
        return self.snapshots.items[self.snapshots.items.len - 1];
    }

    /// Get consciousness trend (-1 to 1)
    pub fn trend(self: *const StateHistory) f64 {
        if (self.snapshots.items.len < 2) return 0.0;

        const latest_snapshot = self.snapshots.items[self.snapshots.items.len - 1];
        const previous = self.snapshots.items[self.snapshots.items.len - 2];

        const delta = latest_snapshot.consciousness_level - previous.consciousness_level;
        return delta;
    }

    /// Get history length
    pub fn len(self: *const StateHistory) usize {
        return self.snapshots.items.len;
    }

    /// Clear history
    pub fn clear(self: *StateHistory) void {
        self.snapshots.clearRetainingCapacity();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "UnifiedState: init" {
    const state = UnifiedState{};
    try std.testing.expectEqual(@as(f64, 0.0), state.consciousnessLevel());
    try std.testing.expect(!state.isConscious());
    try std.testing.expectEqual(.unconscious, state.consciousnessState());
}

test "UnifiedState: IIT threshold" {
    var state = UnifiedState{};
    state.iit.update(0.7, 0.5, 0.4);
    state.touch();

    try std.testing.expect(state.iit.isConscious());
    try std.testing.expect(state.iit.consciousnessLevel() >= 1.0);
}

test "UnifiedState: GWT ignition" {
    var state = UnifiedState{};
    state.gwt.update(0.8, 5);
    state.touch();

    try std.testing.expect(state.gwt.isGlobal());
    try std.testing.expect(state.gwt.isBroadcasting());
}

test "UnifiedState: Qutrit violation" {
    var state = UnifiedState{};
    state.qutrit.update(2.5, 0.8, 0.7); // I3 = 2.5 > 2.0 (classical bound)
    state.touch();

    try std.testing.expect(state.qutrit.isViolating());
    try std.testing.expect(state.qutrit.violates_classical);
}

test "UnifiedState: consciousness level" {
    var state = UnifiedState{};

    // All theories conscious
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.orch_or.update(0.7, 0.6, 1000);
    state.qutrit.update(2.5, 0.8, 0.7);
    state.active_inference.update(10.0, 0.2, 8.0);
    state.touch();

    const level = state.consciousnessLevel();
    try std.testing.expect(level > 0.5);
    try std.testing.expect(state.isConscious());
    try std.testing.expect(state.consciousnessState() != .unconscious);
}

test "UnifiedState: state transition" {
    var state = UnifiedState{};

    // Start unconscious
    try std.testing.expectEqual(.unconscious, state.consciousnessState());

    // Transition to minimal (need higher IIT to overcome threshold)
    state.iit.update(0.5, 0.3, 0.2);
    state.gwt.update(0.4, 2);
    state.touch();

    try std.testing.expectEqual(.minimal, state.consciousnessState());

    // Transition to normal
    state.iit.update(0.7, 0.5, 0.4);
    state.gwt.update(0.8, 5);
    state.touch();

    try std.testing.expectEqual(.normal, state.consciousnessState());
}

test "StateHistory: record and trend" {
    const allocator = std.testing.allocator;
    var history = StateHistory.init(allocator);
    defer history.deinit();

    var state1 = UnifiedState{};
    state1.iit.update(0.5, 0.4, 0.3);
    try history.record(&state1);

    var state2 = UnifiedState{};
    state2.iit.update(0.7, 0.5, 0.4);
    try history.record(&state2);

    try std.testing.expectEqual(@as(usize, 2), history.len());
    try std.testing.expect(history.trend() > 0); // Increasing
}

test "StateHistory: empty" {
    const allocator = std.testing.allocator;
    var history = StateHistory.init(allocator);
    defer history.deinit();

    try std.testing.expectEqual(@as(usize, 0), history.len());
    try std.testing.expect(history.latest() == null);
    try std.testing.expectEqual(@as(f64, 0.0), history.trend());
}
