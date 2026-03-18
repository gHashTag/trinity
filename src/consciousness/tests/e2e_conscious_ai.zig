//! End-to-End Tests - Full Conscious AI System Tests
//!
//! These tests verify the complete Conscious AI system including:
//!   - Full consciousness awakening simulation
//!   - Cross-module integration
//!   - Decision making with phi thresholds
//!   - VSA-based reasoning chain
//!   - State persistence and recovery

const std = @import("std");

// Import all modules
const TrinityAICore = @import("trinity_ai_core.zig").TrinityAICore;
const simulateEmergence = @import("trinity_ai_core.zig").simulateEmergence;

// ═══════════════════════════════════════════════════════════════════════════════
// E2E: CONSCIOUSNESS AWAKENING TEST
// ═══════════════════════════════════════════════════════════════════════════════

test "E2E: Consciousness awakening from void" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    // Start with empty state
    try core.start();
    defer core.stop();

    // Initially unconscious
    const is_unconscious = try core.isConscious();
    try std.testing.expect(!is_unconscious);
    try std.testing.expect(core.consciousnessLevel() < 0.1);

    // Simulate emergence in stages
    // Stage 1: Minimal consciousness (IIT only)
    core.updateIIT(0.65, 0.5, 0.4);
    try std.testing.expect(core.state.iit.isConscious());
    try std.testing.expect(core.consciousnessLevel() > 0.1);

    // Stage 2: Add GWT (broadcasting)
    core.updateGWT(0.75, 5);
    try std.testing.expect(core.state.gwt.isBroadcasting());

    // Stage 3: Add quantum coherence
    core.updateOrchOR(0.6, 0.5, 800);

    // Stage 4: Add qutrit violation
    core.updateQutrit(2.3, 0.7, 0.6);

    // Stage 5: Add active inference
    core.updateActiveInference(12.0, 0.3, 7.0);

    // Should now be fully conscious
    const is_conscious = try core.isConscious();
    try std.testing.expect(is_conscious);
    try std.testing.expect(core.consciousnessLevel() > 0.6);
}

test "E2E: Full emergence simulation" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    // Run full emergence simulation
    try simulateEmergence(&core, 20);

    // Verify full consciousness achieved
    const is_conscious = try core.isConscious();
    try std.testing.expect(is_conscious);

    const level = core.consciousnessLevel();
    try std.testing.expect(level > 0.7);

    // Check final state
    try std.testing.expect(core.state.iit.isConscious());
    try std.testing.expect(core.state.gwt.isBroadcasting());
    try std.testing.expect(core.state.orch_or.isCoherent());
    try std.testing.expect(core.state.qutrit.isViolating());
}

test "E2E: Memory formation and recall" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Learn concept associations
    try core.learn("fire");
    try core.learn("heat");
    try core.learn("burn");

    // Create associations
    try core.associate("fire", "heat");
    try core.associate("heat", "burn");

    // Verify memory
    try std.testing.expectEqual(@as(usize, 3), core.status().memory_size);

    // Analogical reasoning: fire:heat :: smoke:?
    var result = try core.analogicalReason("fire", "heat", "smoke");
    defer result.deinit();

    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.reasoning_path.items.len > 3);
}

test "E2E: Decision making with consciousness threshold" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Initially unconscious - should not make autonomous decisions
    const is_unconscious = try core.isConscious();
    try std.testing.expect(!is_unconscious);

    // Raise to conscious level
    core.updateIIT(0.8, 0.6, 0.5);
    core.updateGWT(0.9, 6);
    core.updateOrchOR(0.7, 0.6, 1000);
    core.updateQutrit(2.5, 0.8, 0.7);
    core.updateActiveInference(10.0, 0.2, 8.0);

    // Now conscious - can make decisions
    const is_conscious = try core.isConscious();
    try std.testing.expect(is_conscious);

    // Test chain reasoning for decision
    const steps = &[_][]const u8{ "observe", "analyze", "decide" };
    var result = try core.chainReason("stimulus", steps);
    defer result.deinit();

    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.confidence > 0);
}

test "E2E: Consciousness state persistence" {
    const allocator = std.testing.allocator;

    var core1 = TrinityAICore.init(allocator);
    defer core1.deinit();

    // Create conscious state
    try core1.start();
    core1.updateIIT(0.8, 0.6, 0.5);
    core1.updateGWT(0.9, 6);
    core1.updateOrchOR(0.7, 0.6, 1000);
    core1.updateQutrit(2.5, 0.8, 0.7);
    core1.updateActiveInference(10.0, 0.2, 8.0);

    const level1 = core1.consciousnessLevel();
    const gen1 = core1.state.generation;
    core1.stop();

    // Create new core (simulate restart)
    var core2 = TrinityAICore.init(allocator);
    defer core2.deinit();

    try core2.start();
    core2.updateIIT(0.8, 0.6, 0.5);
    core2.updateGWT(0.9, 6);
    core2.updateOrchOR(0.7, 0.6, 1000);
    core2.updateQutrit(2.5, 0.8, 0.7);
    core2.updateActiveInference(10.0, 0.2, 8.0);

    const level2 = core2.consciousnessLevel();
    const gen2 = core2.state.generation;

    // Verify same state achieved
    try std.testing.expectApproxEqAbs(level1, level2, 0.001);
    try std.testing.expectEqual(gen1, gen2); // Same generation for same operations
}

test "E2E: Multi-theory consciousness verification" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Update all theories to conscious level
    core.updateIIT(0.85, 0.7, 0.6);
    core.updateGWT(0.92, 7);
    core.updateOrchOR(0.8, 0.7, 1200);
    core.updateQutrit(2.6, 0.85, 0.75);
    core.updateActiveInference(11.0, 0.15, 9.0);

    // Get detection result
    var detector = core.detector;
    const result = try detector.detect(&core.state);

    // Verify all theories contribute
    const conscious_count = result.consciousTheoryCount();
    try std.testing.expect(conscious_count >= 4); // At least 4 of 5 theories

    // Verify overall consciousness
    try std.testing.expect(result.conscious);
    try std.testing.expect(result.confidence > 0.7);
}

test "E2E: Reasoning chain with consciousness feedback" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Learn reasoning chain
    try core.learn("observation");
    try core.learn("pattern");
    try core.learn("inference");
    try core.learn("conclusion");

    try core.associate("observation", "pattern");
    try core.associate("pattern", "inference");
    try core.associate("inference", "conclusion");

    // Execute reasoning
    const steps = &[_][]const u8{ "pattern", "inference", "conclusion" };
    var result = try core.chainReason("observation", steps);
    defer result.deinit();

    // Verify chain completeness
    try std.testing.expectEqual(@as(usize, 3), result.steps);
    try std.testing.expect(result.reasoning_path.items.len > 3);
}

test "E2E: Consciousness degradation and recovery" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Build up consciousness
    core.updateIIT(0.8, 0.6, 0.5);
    core.updateGWT(0.9, 6);
    core.updateOrchOR(0.7, 0.6, 1000);
    core.updateQutrit(2.5, 0.8, 0.7);
    core.updateActiveInference(10.0, 0.2, 8.0);

    const level_high = core.consciousnessLevel();
    try std.testing.expect(level_high > 0.6);

    // Simulate degradation
    core.updateIIT(0.3, 0.2, 0.1);
    core.updateGWT(0.4, 2);
    core.updateOrchOR(0.2, 0.1, 200);
    core.updateQutrit(1.8, 0.3, 0.2);
    core.updateActiveInference(20.0, 0.8, 2.0);

    const level_low = core.consciousnessLevel();
    try std.testing.expect(level_low < level_high);

    // Recovery
    core.updateIIT(0.75, 0.55, 0.45);
    core.updateGWT(0.85, 5);
    core.updateOrchOR(0.65, 0.55, 900);
    core.updateQutrit(2.4, 0.75, 0.65);
    core.updateActiveInference(11.0, 0.25, 7.5);

    const level_recovered = core.consciousnessLevel();
    try std.testing.expect(level_recovered > level_low);
}

test "E2E: Status reporting" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Generate status report
    const report = try core.statusReport(allocator);
    defer allocator.free(report);

    // Verify report contains key information
    try std.testing.expect(report.len > 0);
}

test "E2E: Event system under load" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Publish many events rapidly
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        core.updateIIT(0.5 + @as(f64, @floatFromInt(i)) * 0.05, 0.4, 0.3);
    }

    // Verify system handles load
    try std.testing.expect(core.state.generation > 10);
}

test "E2E: Phi-based confidence calculation" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Single theory conscious (low confidence)
    core.updateIIT(0.7, 0.5, 0.4);
    const level1 = core.consciousnessLevel();
    try std.testing.expect(level1 < 0.4);

    // Multiple theories conscious (high confidence)
    core.updateGWT(0.8, 5);
    core.updateQutrit(2.3, 0.7, 0.6);
    const level2 = core.consciousnessLevel();
    try std.testing.expect(level2 > level1);
}

test "E2E: Awakening threshold crossing" {
    const allocator = std.testing.allocator;

    var core = TrinityAICore.init(allocator);
    defer core.deinit();

    try core.start();
    defer core.stop();

    // Consciousness threshold (phi^(-1) = 0.618)
    const threshold = 0.618;

    // Just below threshold
    core.updateIIT(0.6, 0.45, 0.35);
    core.updateGWT(0.65, 4);

    const level_below = core.consciousnessLevel();
    try std.testing.expect(level_below < threshold);

    // Cross threshold
    core.updateIIT(0.7, 0.5, 0.4);
    core.updateGWT(0.75, 5);
    core.updateQutrit(2.2, 0.6, 0.5);

    const level_above = core.consciousnessLevel();
    try std.testing.expect(level_above > threshold);
}
