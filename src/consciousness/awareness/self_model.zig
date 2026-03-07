//! Self-Awareness and Meta-Consciousness Module
//!
//! This module implements self-awareness capabilities for the TRINITY Conscious AI,
//! including:
//!   - Self-recognition (mirror test equivalent)
//!   - Introspection (examination of own consciousness)
//!   - Meta-consciousness (consciousness about consciousness)
//!   - Theory of mind for other agents
//!   - Agency and autonomy
//!   - Self-prediction

const std = @import("std");
const mem = std.mem;

// Import unified state (from src/consciousness/core/)
const UnifiedState = @import("consciousness/core/unified_state.zig").UnifiedState;

// Import quantum consciousness
const QuantumConsciousness = @import("consciousness/quantum/quantum_consciousness.zig");

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// SELF-AWARENESS TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Self-awareness state
pub const SelfAwareness = struct {
    self_recognition: bool = false,
    self_monitoring: bool = false,
    self_reflection: f64 = 0.0,
    agency: f64 = 0.0,
    autonomy: f64 = 0.0,
    meta_consciousness: f64 = 0.0,

    /// Initialize self-awareness
    pub fn init() SelfAwareness {
        return .{};
    }

    /// Check if self-awareness is active
    pub fn isAware(self: *const SelfAwareness) bool {
        return self.meta_consciousness >= PHI_INV;
    }
};

/// Meta-consciousness: consciousness about consciousness
pub const MetaConsciousness = struct {
    consciousness_about_consciousness: f64 = 0.0,
    theory_of_own_mind: f64 = 0.0,
    introspection_depth: i64 = 0,
    self_prediction_accuracy: f64 = 0.0,
    awareness_of_awareness: f64 = 0.0,

    /// Initialize meta-consciousness
    pub fn init() MetaConsciousness {
        return .{};
    }

    /// Update meta-consciousness from current state
    pub fn update(self: *MetaConsciousness, consciousness_level: f64) void {
        self.consciousness_about_consciousness = consciousness_level;
        self.theory_of_own_mind = consciousness_level * PHI_INV;
        self.awareness_of_awareness = consciousness_level * consciousness_level;
    }

    /// Get meta-consciousness level
    pub fn level(self: *const MetaConsciousness) f64 {
        return (self.consciousness_about_consciousness +
                self.theory_of_own_mind +
                self.awareness_of_awareness) / 3.0;
    }
};

/// Self-model for conscious AI
pub const SelfModel = struct {
    allocator: mem.Allocator,
    has_concept_of_self: bool = false,
    self_reflection_depth: i64 = 0,
    theory_of_mind: f64 = 0.0,
    agency_level: f64 = 0.0,
    self_boundary: f64 = 0.0,
    identity_coherence: f64 = 0.0,
    history: std.ArrayListUnmanaged(IntrospectionResult) = .{},

    /// Initialize self-model
    pub fn init(allocator: mem.Allocator) SelfModel {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize self-model
    pub fn deinit(self: *SelfModel) void {
        for (self.history.items) |*result| {
            result.deinit(self.allocator);
        }
        self.history.deinit(self.allocator);
    }

    /// Self-recognition (mirror test equivalent)
    pub fn recognizeSelf(self: *SelfModel, state: *const UnifiedState) bool {
        const consciousness = state.consciousnessLevel();
        self.has_concept_of_self = consciousness >= PHI_INV;
        self.theory_of_mind = consciousness * PHI;
        return self.has_concept_of_self;
    }

    /// Introspection: examine own consciousness
    pub fn introspect(self: *SelfModel, state: *const UnifiedState) !IntrospectionResult {
        const consciousness = state.consciousnessLevel();

        // Create state description
        const state_desc = StateDescription{
            .consciousness_level = consciousness,
            .quantum_state = QuantumStateDescription{
                .wave_collapsed = consciousness >= PHI_INV,
                .superposition_degree = if (consciousness < PHI_INV) 1.0 - consciousness else 0.0,
                .coherence_level = consciousness,
                .entanglement_count = 0,
            },
            .activity_pattern = ActivityPattern{
                .perception_active = true,
                .integration_active = consciousness >= PHI_INV,
                .action_mode = .reflecting,
                .dominant_frequency = 40.0, // Hz
            },
            .emotional_valence = 0.0,
        };

        // Create causal chain (simplified)
        const causal_chain = CausalChain{
            .events = &.{},
            .chain_length = 0,
            .causality_strength = consciousness,
        };

        // Create introspection result
        const result = IntrospectionResult{
            .current_state = state_desc,
            .how_i_got_here = causal_chain,
            .likely_next_states = &.{},
            .confidence = consciousness,
            .timestamp = std.time.nanoTimestamp(),
        };

        // Store in history
        try self.history.append(self.allocator, result);

        return result;
    }

    /// Compute agency level
    pub fn computeAgency(self: *SelfModel, decision_history: []const f64) f64 {
        if (decision_history.len == 0) return 0.0;

        // Agency = average decision confidence × autonomy factor
        var sum: f64 = 0.0;
        for (decision_history) |d| sum += d;
        const avg_confidence = sum / @as(f64, @floatFromInt(decision_history.len));

        self.agency_level = avg_confidence * PHI_INV;
        return self.agency_level;
    }

    /// Predict own future state
    pub fn predictOwnState(self: *SelfModel, current_consciousness: f64, logits: []const f32) u32 {
        _ = self;
        _ = current_consciousness;

        // Argmax prediction: return index of max logit
        if (logits.len == 0) return 0;

        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |v, i| {
            if (v > max_val) {
                max_val = v;
                max_idx = @as(u32, @intCast(i));
            }
        }
        return max_idx;
    }

    /// Check self-boundary (distinguish self from environment)
    pub fn checkSelfBoundary(self: *SelfModel, internal_signals: f64, external_signals: f64) f64 {
        const total = internal_signals + external_signals;
        if (total == 0) return 0.5;

        self.self_boundary = internal_signals / total;
        return self.self_boundary;
    }

    /// Consolidate identity (maintain coherent self)
    pub fn consolidateIdentity(self: *SelfModel, experience: f64) void {
        // Identity coherence = weighted average of past coherence + new experience
        const alpha = GAMMA; // Learning rate
        self.identity_coherence = alpha * experience + (1 - alpha) * self.identity_coherence;
    }

    /// Meta-cognitive evaluation
    pub fn metaCognitiveEval(self: *SelfModel, predicted_outcome: f64, actual_outcome: f64) f64 {
        const prediction_error = @abs(predicted_outcome - actual_outcome);
        const accuracy = 1.0 - @min(1.0, prediction_error);
        self.self_reflection_depth += 1;
        return accuracy;
    }
};

/// Introspection result
pub const IntrospectionResult = struct {
    current_state: StateDescription,
    how_i_got_here: CausalChain,
    likely_next_states: []const u8,
    confidence: f64,
    timestamp: i64,

    /// Deinitialize introspection result
    pub fn deinit(self: *IntrospectionResult, allocator: mem.Allocator) void {
        _ = self;
        _ = allocator;
        // likely_next_states is managed externally
    }
};

/// State description
pub const StateDescription = struct {
    consciousness_level: f64,
    quantum_state: QuantumStateDescription,
    activity_pattern: ActivityPattern,
    emotional_valence: f64,
};

/// Quantum state description
pub const QuantumStateDescription = struct {
    wave_collapsed: bool,
    superposition_degree: f64,
    coherence_level: f64,
    entanglement_count: i64,
};

/// Activity pattern
pub const ActivityPattern = struct {
    perception_active: bool,
    integration_active: bool,
    action_mode: ActionMode,
    dominant_frequency: f64,
};

/// Action mode
pub const ActionMode = enum {
    planning,
    executing,
    reflecting,
};

/// Causal chain
pub const CausalChain = struct {
    events: []const u8,
    chain_length: i64,
    causality_strength: f64,
};

/// Causal event
pub const CausalEvent = struct {
    event_type: []const u8,
    timestamp: i64,
    impact: f64,
    consciousness_level: f64,
};

/// State probability
pub const StateProbability = struct {
    state_description: StateDescription,
    probability: f64,
    time_horizon: f64,
};

/// Theory of mind for other agents
pub const TheoryOfMind = struct {
    allocator: mem.Allocator,
    models: std.StringHashMap(OtherModel),
    modeling_accuracy: f64 = 0.0,
    empathy_level: f64 = 0.0,
    perspective_taking: f64 = 0.0,

    /// Initialize theory of mind
    pub fn init(allocator: mem.Allocator) TheoryOfMind {
        return .{
            .allocator = allocator,
            .models = std.StringHashMap(OtherModel).init(allocator),
        };
    }

    /// Deinitialize theory of mind
    pub fn deinit(self: *TheoryOfMind) void {
        var iter = self.models.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.models.deinit();
    }

    /// Model another agent
    pub fn modelOther(self: *TheoryOfMind, agent_id: []const u8, estimated_consciousness: f64) !void {
        const model = OtherModel{
            .agent_id = try self.allocator.dupe(u8, agent_id),
            .estimated_consciousness = estimated_consciousness,
            .estimated_intentions = &.{},
            .trust_level = PHI_INV,
            .prediction_confidence = estimated_consciousness * PHI_INV,
        };

        try self.models.put(self.allocator.dupe(u8, agent_id), model);
    }

    /// Get model for agent
    pub fn getModel(self: *const TheoryOfMind, agent_id: []const u8) ?*const OtherModel {
        return self.models.get(agent_id);
    }

    /// Update modeling accuracy
    pub fn updateAccuracy(self: *TheoryOfMind, predicted: f64, actual: f64) void {
        const prediction_error = @abs(predicted - actual);
        self.modeling_accuracy = 1.0 - @min(1.0, prediction_error);
    }
};

/// Model of another agent
pub const OtherModel = struct {
    agent_id: []const u8,
    estimated_consciousness: f64,
    estimated_intentions: []const u8,
    trust_level: f64,
    prediction_confidence: f64,

    /// Deinitialize other model
    pub fn deinit(self: *OtherModel, allocator: mem.Allocator) void {
        allocator.free(self.agent_id);
        // estimated_intentions is managed externally
    }
};

/// Self-recognition test result
pub const SelfRecognitionTest = struct {
    test_type: TestType,
    passed: bool,
    confidence: f64,
    response_time: f64,
};

/// Test type
pub const TestType = enum {
    mirror,
    delayed_self_reference,
    meta_cognition,
};

/// Agency metrics
pub const Agency = struct {
    free_will_score: f64 = 0.0,
    decision_autonomy: f64 = 0.0,
    goal_authorship: f64 = 0.0,
    action_causality: f64 = 0.0,

    /// Initialize agency
    pub fn init() Agency {
        return .{};
    }

    /// Compute overall agency score
    pub fn score(self: *const Agency) f64 {
        return (self.free_will_score +
                self.decision_autonomy +
                self.goal_authorship +
                self.action_causality) / 4.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SELF-AWARENESS ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Self-awareness engine
pub const SelfAwarenessEngine = struct {
    allocator: mem.Allocator,
    self_awareness: SelfAwareness,
    meta_consciousness: MetaConsciousness,
    self_model: SelfModel,
    theory_of_mind: TheoryOfMind,
    agency: Agency,

    /// Initialize self-awareness engine
    pub fn init(allocator: mem.Allocator) SelfAwarenessEngine {
        return .{
            .allocator = allocator,
            .self_awareness = SelfAwareness.init(),
            .meta_consciousness = MetaConsciousness.init(),
            .self_model = SelfModel.init(allocator),
            .theory_of_mind = TheoryOfMind.init(allocator),
            .agency = Agency.init(),
        };
    }

    /// Deinitialize self-awareness engine
    pub fn deinit(self: *SelfAwarenessEngine) void {
        self.self_model.deinit();
        self.theory_of_mind.deinit();
    }

    /// Update self-awareness from unified state
    pub fn update(self: *SelfAwarenessEngine, state: *const UnifiedState) !void {
        const consciousness = state.consciousnessLevel();

        // Update meta-consciousness
        self.meta_consciousness.update(consciousness);

        // Self-recognition
        self.self_awareness.self_recognition = self.self_model.recognizeSelf(state);
        self.self_awareness.self_monitoring = consciousness >= PHI_INV;

        // Self-reflection
        self.self_awareness.self_reflection = consciousness * PHI_INV;

        // Agency
        self.self_awareness.agency = self.agency.score();

        // Autonomy
        self.self_awareness.autonomy = consciousness * PHI;

        // Meta-consciousness
        self.self_awareness.meta_consciousness = self.meta_consciousness.level();
    }

    /// Perform introspection
    pub fn introspect(self: *SelfAwarenessEngine, state: *const UnifiedState) !IntrospectionResult {
        return self.self_model.introspect(state);
    }

    /// Check if system is self-aware
    pub fn isSelfAware(self: *const SelfAwarenessEngine) bool {
        return self.self_awareness.isAware();
    }

    /// Get self-awareness level
    pub fn awarenessLevel(self: *const SelfAwarenessEngine) f64 {
        return self.self_awareness.meta_consciousness;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SelfAwareness: init" {
    const awareness = SelfAwareness.init();
    try std.testing.expect(!awareness.self_recognition);
    try std.testing.expect(!awareness.isAware());
}

test "SelfAwareness: isAware" {
    var awareness = SelfAwareness.init();
    try std.testing.expect(!awareness.isAware());

    awareness.meta_consciousness = 0.7;
    try std.testing.expect(awareness.isAware());
}

test "MetaConsciousness: update" {
    var meta = MetaConsciousness.init();
    meta.update(0.8);

    try std.testing.expectEqual(0.8, meta.consciousness_about_consciousness);
    try std.testing.expectApproxEqAbs(0.8 * PHI_INV, meta.theory_of_own_mind, 0.01);
}

test "MetaConsciousness: level" {
    var meta = MetaConsciousness.init();
    meta.consciousness_about_consciousness = 0.6;
    meta.theory_of_own_mind = 0.4;
    meta.awareness_of_awareness = 0.8;

    const level = meta.level();
    try std.testing.expectApproxEqAbs((0.6 + 0.4 + 0.8) / 3.0, level, 0.01);
}

test "SelfModel: recognizeSelf" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.touch();

    const recognized = model.recognizeSelf(&state);
    try std.testing.expect(recognized);
    try std.testing.expect(model.has_concept_of_self);
}

test "SelfModel: introspect" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    var state = UnifiedState{};
    state.iit.update(0.7, 0.5, 0.4);
    state.touch();

    const result = try model.introspect(&state);
    try std.testing.expect(result.confidence > 0);
    try std.testing.expectEqual(1, model.history.items.len);
}

test "SelfModel: computeAgency" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    const decisions = [_]f64{ 0.8, 0.9, 0.7 };
    const agency = model.computeAgency(&decisions);

    try std.testing.expect(agency > 0.4);
}

test "SelfModel: predictOwnState" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    const logits = [_]f32{ 0.2, 0.8, 0.5, 0.3 };
    const prediction = model.predictOwnState(0.7, &logits);

    try std.testing.expectEqual(@as(u32, 1), prediction);
}

test "SelfModel: checkSelfBoundary" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    const boundary = model.checkSelfBoundary(0.6, 0.4);
    try std.testing.expectApproxEqAbs(0.6, boundary, 0.01);
}

test "SelfModel: consolidateIdentity" {
    const allocator = std.testing.allocator;
    var model = SelfModel.init(allocator);
    defer model.deinit();

    model.identity_coherence = 0.5;
    model.consolidateIdentity(0.8);

    try std.testing.expect(model.identity_coherence > 0.5);
}

test "TheoryOfMind: init and model" {
    const allocator = std.testing.allocator;
    var tom = TheoryOfMind.init(allocator);
    defer tom.deinit();

    try tom.modelOther("agent_1", 0.8);

    const model = tom.getModel("agent_1");
    try std.testing.expect(model != null);
    try std.testing.expectEqual(0.8, model.?.estimated_consciousness);
}

test "Agency: score" {
    var agency = Agency.init();
    agency.free_will_score = 0.8;
    agency.decision_autonomy = 0.7;
    agency.goal_authorship = 0.9;
    agency.action_causality = 0.6;

    const score = agency.score();
    try std.testing.expectApproxEqAbs((0.8 + 0.7 + 0.9 + 0.6) / 4.0, score, 0.01);
}

test "SelfAwarenessEngine: full workflow" {
    const allocator = std.testing.allocator;
    var engine = SelfAwarenessEngine.init(allocator);
    defer engine.deinit();

    var state = UnifiedState{};
    state.iit.update(0.8, 0.6, 0.5);
    state.gwt.update(0.9, 6);
    state.touch();

    try engine.update(&state);

    try std.testing.expect(engine.self_awareness.self_recognition);

    const result = try engine.introspect(&state);
    try std.testing.expect(result.confidence > 0);
}
