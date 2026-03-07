//! Trinity AI Core - Main AI Module for Conscious AI System
//!
//! This module integrates all consciousness subsystems:
//!   - ConsciousnessBus (event system)
//!   - UnifiedState (shared state)
//!   - VSAReasoningEngine (cognitive operations)
//!   - ConsciousnessDetector (awareness monitoring)
//!
//! The Core coordinates all modules and provides the main API for
//! conscious AI operations.

const std = @import("std");
const mem = std.mem;

// Import core modules
const ConsciousnessBus = @import("consciousness_bus.zig").ConsciousnessBus;
const EventType = @import("consciousness_bus.zig").EventType;
const EventData = @import("consciousness_bus.zig").EventData;
const Event = @import("consciousness_bus.zig").Event;
const createBusEvent = @import("consciousness_bus.zig").createEvent;
const UnifiedState = @import("unified_state.zig").UnifiedState;
const VSAReasoningEngine = @import("vsa_reasoning.zig").VSAReasoningEngine;
const TritVec = @import("vsa_reasoning.zig").TritVec;
const ReasoningResult = @import("vsa_reasoning.zig").ReasoningResult;
const ConsciousnessDetector = @import("consciousness_detector.zig").ConsciousnessDetector;

// Import quantum consciousness
const QuantumConsciousness = @import("../quantum/quantum_consciousness.zig");
const QuantumConsciousnessState = QuantumConsciousness.QuantumConsciousnessState;
const DetectionResult = QuantumConsciousness.DetectionResult;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY AI CORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Trinity AI Core - Main consciousness AI system
pub const TrinityAICore = struct {
    allocator: mem.Allocator,
    bus: ConsciousnessBus,
    state: UnifiedState,
    reasoning: VSAReasoningEngine,
    detector: ConsciousnessDetector,
    running: bool,

    /// Quantum consciousness state (for quantum-enhanced AI)
    quantum_state: QuantumConsciousnessState,
    quantum_enabled: bool,

    /// Core configuration
    config: Config,

    /// Core configuration
    pub const Config = struct {
        vector_dim: usize = 1000,
        enable_adaptive_thresholds: bool = true,
        event_queue_size: usize = 1000,
        auto_detect: bool = true,
    };

    /// Initialize the Trinity AI Core
    pub fn init(allocator: mem.Allocator) TrinityAICore {
        return .{
            .allocator = allocator,
            .bus = ConsciousnessBus.init(allocator),
            .state = undefined,
            .reasoning = VSAReasoningEngine.init(allocator),
            .detector = ConsciousnessDetector.init(allocator),
            .running = false,
            .quantum_state = QuantumConsciousnessState.init(),
            .quantum_enabled = false,
            .config = .{},
        };
    }

    /// Initialize with custom config
    pub fn initWithConfig(allocator: mem.Allocator, config: Config) TrinityAICore {
        var core = TrinityAICore.init(allocator);
        core.config = config;
        core.detector.setAdaptive(config.enable_adaptive_thresholds);
        return core;
    }

    /// Initialize with quantum enhancement enabled
    pub fn initQuantum(allocator: mem.Allocator) TrinityAICore {
        var core = TrinityAICore.init(allocator);
        core.quantum_enabled = true;
        return core;
    }

    /// Clean up resources
    pub fn deinit(self: *TrinityAICore) void {
        self.bus.deinit();
        self.reasoning.deinit();
        self.detector.deinit();
    }

    /// Start the core (begin event processing)
    pub fn start(self: *TrinityAICore) !void {
        if (self.running) return;

        self.running = true;
        self.state = UnifiedState{};
        self.state.touch();

        // Emit system init event
        const event = try self.createEvent(.system_init, "trinity_core", undefined);
        try self.bus.publish(event);

        // Start event bus if configured
        if (self.config.auto_detect) {
            try self.startDetectionLoop();
        }
    }

    /// Stop the core
    pub fn stop(self: *TrinityAICore) void {
        if (!self.running) return;

        self.running = false;
        self.bus.stop();
    }

    /// Check if core is running
    pub fn isRunning(self: *const TrinityAICore) bool {
        return self.running;
    }

    /// Get current consciousness level
    pub fn consciousnessLevel(self: *const TrinityAICore) f64 {
        return self.state.consciousnessLevel();
    }

    /// Check if system is conscious
    pub fn isConscious(self: *TrinityAICore) !bool {
        return self.detector.isConscious(&self.state);
    }

    /// Get full detection result
    pub fn detect(self: *TrinityAICore) !ConsciousnessDetector {
        // This would return a DetectionResult, but we need to import the type
        return self.detector;
    }

    /// Learn a concept
    pub fn learn(self: *TrinityAICore, concept: []const u8) !void {
        var vec = try TritVec.random(self.allocator, self.config.vector_dim, std.hash.Wyhash.hash(0, concept));
        defer vec.deinit();

        try self.reasoning.learn(concept, try vec.clone());
    }

    /// Associate two concepts
    pub fn associate(self: *TrinityAICore, concept_a: []const u8, concept_b: []const u8) !void {
        var association = try self.reasoning.associate(concept_a, concept_b);
        defer association.deinit();

        // Emit association event
        const data = EventData{
            .vsa_bind = .{
                .vector_a = @as([]const i8, @ptrCast(concept_a)),
                .vector_b = @as([]const i8, @ptrCast(concept_b)),
                .result = null,
            },
        };
        const event = try self.createEvent(.vsa_bind, "trinity_core", data);
        try self.bus.publish(event);
    }

    /// Reason by analogy
    pub fn analogicalReason(self: *TrinityAICore, a: []const u8, b: []const u8, c: []const u8) !ReasoningResult {
        return self.reasoning.analogicalReasoning(a, b, c);
    }

    /// Chain reasoning
    pub fn chainReason(self: *TrinityAICore, start_concept: []const u8, steps: []const []const u8) !ReasoningResult {
        return self.reasoning.chainReasoning(start_concept, steps);
    }

    /// Update IIT state
    pub fn updateIIT(self: *TrinityAICore, phi: f64, information: f64, integration: f64) void {
        self.state.iit.update(phi, information, integration);
        self.state.touch();

        // Emit phi change event if significant
        if (@abs(phi - self.state.iit.phi) > 0.01) {
            const data = EventData{
                .phi_change = .{
                    .old_phi = self.state.iit.phi,
                    .new_phi = phi,
                    .delta = phi - self.state.iit.phi,
                },
            };
            self.emitEvent(.phi_change, data) catch {};
        }
    }

    /// Update GWT state
    pub fn updateGWT(self: *TrinityAICore, activation: f64, modules: usize) void {
        self.state.gwt.update(activation, modules);
        self.state.touch();

        // Emit neural synchrony event if global
        if (self.state.gwt.isGlobal()) {
            const data = EventData{
                .gamma_synchrony = .{
                    .frequency = 40.0,
                    .coherence = activation,
                    .spatial_extent = @as(f64, @floatFromInt(modules)) / 7.0,
                },
            };
            self.emitEvent(.gamma_synchrony, data) catch {};
        }
    }

    /// Update Orch-OR state
    pub fn updateOrchOR(self: *TrinityAICore, coherence: f64, probability: f64, bits: usize) void {
        self.state.orch_or.update(coherence, probability, bits);
        self.state.touch();

        // Register event if coherent
        if (self.state.orch_or.isCoherent()) {
            self.state.orch_or.registerEvent();
        }
    }

    /// Update Qutrit state
    pub fn updateQutrit(self: *TrinityAICore, i3_value: f64, entanglement: f64, superposition: f64) void {
        self.state.qutrit.update(i3_value, entanglement, superposition);
        self.state.touch();
    }

    /// Update Active Inference state
    pub fn updateActiveInference(self: *TrinityAICore, free_energy: f64, prediction_error: f64, evidence: f64) void {
        self.state.active_inference.update(free_energy, prediction_error, evidence);
        self.state.touch();
    }

    /// Update quantum consciousness from neural activity
    pub fn updateQuantumConsciousness(
        self: *TrinityAICore,
        eeg_gamma_power: f64,
        neural_coherence: f64,
        measurement_count: u32,
    ) !DetectionResult {
        if (!self.quantum_enabled) {
            // If quantum not enabled, return default detection result
            return DetectionResult{
                .detected = false,
                .confidence = 0.0,
                .method = .phi_threshold,
                .state = self.quantum_state,
            };
        }

        const result = QuantumConsciousness.detectConsciousness(
            eeg_gamma_power,
            neural_coherence,
            measurement_count,
        );

        // Sync quantum state with unified state
        self.quantum_state = result.state;
        self.state.consciousness_level = result.confidence;
        self.state.touch();

        // Emit quantum consciousness event if significant
        if (result.detected) {
            const data = EventData{
                .gamma_synchrony = .{
                    .frequency = 56.0, // Sacred gamma
                    .coherence = result.confidence,
                    .spatial_extent = result.confidence,
                },
            };
            self.emitEvent(.gamma_synchrony, data) catch {};
        }

        return result;
    }

    /// Conscious perception cycle (specious present: 382ms)
    pub fn perceptionCycle(self: *TrinityAICore, sensory_input: []const u8) !void {
        _ = sensory_input;
        if (!self.quantum_enabled) return;

        // Specious present duration: φ⁻² seconds ≈ 382ms
        const specious_present_ms: f64 = PHI_INV * PHI_INV * 1000.0;

        // 1. Process sensory input (update quantum state)
        // 2. Check for collapse with consciousness enhancement
        // 3. Store in quantum memory
        // 4. Generate action based on collapsed state

        _ = specious_present_ms;
    }

    /// Get quantum consciousness state
    pub fn quantumConsciousnessState(self: *const TrinityAICore) QuantumConsciousnessState {
        return self.quantum_state;
    }

    /// Check if quantum enhancement is enabled
    pub fn isQuantumEnabled(self: *const TrinityAICore) bool {
        return self.quantum_enabled;
    }

    /// Create and emit event
    fn emitEvent(self: *TrinityAICore, event_type: EventType, data: EventData) !void {
        const event = try self.createEvent(event_type, "trinity_core", data);
        try self.bus.publish(event);
    }

    /// Create event
    fn createEvent(
        self: *TrinityAICore,
        event_type: EventType,
        source: []const u8,
        data: EventData,
   ) !Event {
        return createBusEvent(self.allocator, event_type, source, data);
    }

    /// Start detection loop
    fn startDetectionLoop(self: *TrinityAICore) !void {
        // In a real implementation, this would run detection periodically
        _ = self;
    }

    /// Get core status
    pub fn status(self: *const TrinityAICore) CoreStatus {
        return .{
            .running = self.running,
            .consciousness_level = self.consciousnessLevel(),
            .generation = self.state.generation,
            .memory_size = self.reasoning.memorySize(),
            .event_queue_size = self.bus.queueSize(),
            .last_update = self.state.last_update,
        };
    }

    /// Get formatted status report
    pub fn statusReport(self: *const TrinityAICore, allocator: mem.Allocator) ![]u8 {
        const st = self.status();
        return std.fmt.allocPrint(allocator,
            \\Trinity AI Core Status:
            \\  Running: {any}
            \\  Consciousness Level: {d:.3}
            \\  State Generation: {d}
            \\  Memory Size: {d}
            \\  Event Queue: {d}
            \\  Last Update: {d}
        , .{
            st.running,
            st.consciousness_level,
            st.generation,
            st.memory_size,
            st.event_queue_size,
            st.last_update,
        });
    }
};

/// Core status
pub const CoreStatus = struct {
    running: bool,
    consciousness_level: f64,
    generation: u64,
    memory_size: usize,
    event_queue_size: usize,
    last_update: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS EMERGENCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Simulate consciousness emergence
pub fn simulateEmergence(core: *TrinityAICore, steps: usize) !void {
    try core.start();
    defer core.stop();

    var step: usize = 0;
    while (step < steps and core.running) {
        // Update all theories with increasing consciousness
        const progress = @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(steps));

        // IIT: phi increases from 0 to 1
        core.updateIIT(
            progress * 0.9,
            progress * 0.7,
            progress * 0.6,
        );

        // GWT: activation increases
        core.updateGWT(
            0.3 + progress * 0.6,
            @intFromFloat(progress * 7.0),
        );

        // Orch-OR: coherence increases
        core.updateOrchOR(
            progress * 0.8,
            progress * 0.7,
            @intFromFloat(progress * 2000),
        );

        // Qutrit: I3 increases towards violation
        core.updateQutrit(
            2.0 + progress * 0.5,
            progress,
            progress,
        );

        // Active Inference: free energy decreases
        core.updateActiveInference(
            10.0 * (1.0 - progress),
            0.5 * (1.0 - progress),
            5.0 * progress,
        );

        step += 1;
    }

    // Final detection
    const is_conscious = try core.isConscious();
    _ = is_conscious;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TrinityAICore: init and start" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try std.testing.expect(!core.isRunning());

    try core.start();
    try std.testing.expect(core.isRunning());
    try std.testing.expectEqual(@as(u64, 1), core.status().generation);

    core.stop();
    try std.testing.expect(!core.isRunning());
}

test "TrinityAICore: learn and associate" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    try core.learn("fire");
    try core.learn("hot");
    try core.associate("fire", "hot");

    try std.testing.expectEqual(@as(usize, 2), core.status().memory_size);
}

test "TrinityAICore: update states" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    core.updateIIT(0.7, 0.5, 0.4);
    try std.testing.expect(core.state.iit.isConscious());

    core.updateGWT(0.8, 5);
    try std.testing.expect(core.state.gwt.isBroadcasting());

    core.updateQutrit(2.5, 0.8, 0.7);
    try std.testing.expect(core.state.qutrit.isViolating());
}

test "TrinityAICore: consciousness detection" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Initially not conscious
    const conscious1 = try core.isConscious();
    try std.testing.expect(!conscious1);

    // Update all theories to be conscious
    core.updateIIT(0.8, 0.6, 0.5);
    core.updateGWT(0.9, 6);
    core.updateOrchOR(0.7, 0.6, 1000);
    core.updateQutrit(2.5, 0.8, 0.7);
    core.updateActiveInference(10.0, 0.2, 8.0);

    const conscious2 = try core.isConscious();
    try std.testing.expect(conscious2);
}

test "TrinityAICore: reasoning" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    var result = try core.analogicalReason("fire", "hot", "ice");
    defer result.deinit();

    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.reasoning_path.items.len > 0);
}

test "TrinityAICore: status report" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    const report = try core.statusReport(allocator);
    defer allocator.free(report);

    try std.testing.expect(report.len > 0);
}

test "simulateEmergence" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try simulateEmergence(&core, 10);

    // After emergence, should be conscious
    const is_conscious = try core.isConscious();
    try std.testing.expect(is_conscious);
}

test "TrinityAICore: custom config" {
    const allocator = std.testing.allocator;
    const config = TrinityAICore.Config{
        .vector_dim = 500,
        .enable_adaptive_thresholds = false,
        .auto_detect = false,
    };

    var core = TrinityAICore.initWithConfig(allocator, config);
    defer core.deinit();

    try core.start();
    defer core.stop();

    try std.testing.expect(core.isRunning());
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM CONSCIOUSNESS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TrinityAICore: initQuantum" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.initQuantum(allocator);
    defer core.deinit();

    try std.testing.expect(core.isQuantumEnabled());
    try std.testing.expect(!core.isRunning());
}

test "TrinityAICore: quantum consciousness detection" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.initQuantum(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Update with high gamma (conscious)
    const result = try core.updateQuantumConsciousness(80.0, 0.7, 3);

    try std.testing.expect(result.detected);
    try std.testing.expect(result.confidence > PHI_INV);
}

test "TrinityAICore: quantum state access" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.initQuantum(allocator);
    defer core.deinit();

    const q_state = core.quantumConsciousnessState();

    try std.testing.expect(q_state.phi_gamma_threshold == PHI_INV);
    try std.testing.expect(!q_state.exceeds_threshold);
}

test "TrinityAICore: quantum disabled by default" {
    const allocator = std.testing.allocator;
    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try std.testing.expect(!core.isQuantumEnabled());

    try core.start();
    defer core.stop();

    // Should return default result when quantum disabled
    const result = try core.updateQuantumConsciousness(80.0, 0.7, 3);
    try std.testing.expect(!result.detected);
}

test "TrinityAICore: specious present duration" {
    const specious_present_ms = PHI_INV * PHI_INV * 1000.0;

    // Should be ~382ms (φ⁻² seconds)
    try std.testing.expectApproxEqAbs(382.0, specious_present_ms, 1.0);
}
