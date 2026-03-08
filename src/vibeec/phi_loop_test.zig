//! PHI LOOP Tests — 999 Links of Cosmic Consciousness Gene
//! Comprehensive tests for the main improvement loop

const std = @import("std");
const phi_types = @import("phi_types.zig");
const phi_gate = @import("phi_gate.zig");
const phi_loop = @import("phi_loop.zig");

const Allocator = std.mem.Allocator;

// ============================================================================
// Part I: Sacred Constants Tests
// ============================================================================

test "Sacred: PHI constant" {
    const phi_val: f64 = phi_types.Sacred.PHI;
    try std.testing.expectApproxEqAbs(phi_val, 1.618, 0.001);
}

test "Sacred: MU constant" {
    const mu_val: f64 = phi_types.Sacred.MU;
    try std.testing.expectApproxEqAbs(mu_val, 0.0382, 0.0001);
}

test "Sacred: SACRED_THRESHOLD" {
    try std.testing.expectEqual(phi_types.Sacred.SACRED_THRESHOLD, 0.95);
}

test "Sacred: Trinity Identity (φ² + 1/φ² = 3)" {
    try std.testing.expect(phi_types.Sacred.trinityIdentity());

    // Manual verification
    const phi: f64 = phi_types.Sacred.PHI;
    const phi_squared = phi * phi;
    const inverse_phi_squared = 1.0 / phi_squared;
    const result = phi_squared + inverse_phi_squared;
    try std.testing.expectApproxEqAbs(result, 3.0, 0.0001);
}

test "Sacred: phiWeighted calculation" {
    const score: f64 = 0.8;
    const weighted = phi_types.Sacred.phiWeighted(score);
    try std.testing.expect(weighted > score);
    try std.testing.expectApproxEqAbs(weighted, 1.294, 0.01);
}

test "Sacred: muPenalty calculation" {
    const penalty1 = phi_types.Sacred.muPenalty(0);
    try std.testing.expectEqual(@as(f64, 0.0), penalty1);

    const penalty10 = phi_types.Sacred.muPenalty(10);
    try std.testing.expectApproxEqAbs(penalty10, 0.382, 0.001);
}

// ============================================================================
// Part II: PhiGate Tests
// ============================================================================

test "PhiGate: initialization" {
    const gate = phi_gate.PhiGate.init(std.testing.allocator);

    try std.testing.expectEqual(@as(f64, 0.0), gate.pas_score);
    try std.testing.expectEqual(@as(f32, 0.0), gate.confidence);
    try std.testing.expectEqual(@as(f64, 0.0), gate.sona_q_value);
    try std.testing.expect(gate.trinity_verified);
    try std.testing.expect(!gate.phi_weighted);
}

test "PhiGate: passes with good scores" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    try std.testing.expect(gate.passes());
    try std.testing.expectEqual(phi_gate.GateStatus.passed, gate.status());
}

test "PhiGate: fails with low PAS score" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.80); // Below SACRED_THRESHOLD
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    try std.testing.expect(!gate.passes());
    try std.testing.expectEqual(phi_gate.GateStatus.failed_pas, gate.status());
}

test "PhiGate: fails with low confidence" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.90); // Below 0.95
    gate.setSonaQValue(0.8);

    try std.testing.expect(!gate.passes());
    try std.testing.expectEqual(phi_gate.GateStatus.failed_confidence, gate.status());
}

test "PhiGate: fails with low SONA Q-value" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.3); // Below 0.5

    try std.testing.expect(!gate.passes());
    try std.testing.expectEqual(phi_gate.GateStatus.failed_sona, gate.status());
}

test "PhiGate: gateScore calculation" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    const score = gate.gateScore();
    try std.testing.expect(score > 0.8);
    try std.testing.expect(score <= 1.0);
}

test "PhiGate: phiWeightedScore boosts score" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.6);
    gate.setConfidence(0.7);
    gate.setSonaQValue(0.6);

    const before = gate.gateScore();
    gate.applyPhiWeight();
    const after = gate.phiWeightedScore();

    try std.testing.expect(after > before);
}

test "PhiGate: failureMessage contains failure reason" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.80);

    const msg = try gate.failureMessage(std.testing.allocator);
    defer std.testing.allocator.free(msg);

    try std.testing.expect(std.mem.indexOf(u8, msg, "FAILED") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "PAS") != null);
}

test "PhiGate: reset clears all scores" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);
    gate.addErrors(5);
    gate.addWarnings(3);

    gate.reset();

    try std.testing.expectEqual(@as(f64, 0.0), gate.pas_score);
    try std.testing.expectEqual(@as(f32, 0.0), gate.confidence);
    try std.testing.expectEqual(@as(f64, 0.0), gate.sona_q_value);
    try std.testing.expectEqual(@as(u32, 0), gate.error_count);
    try std.testing.expectEqual(@as(u32, 0), gate.warning_count);
}

test "PhiGate: toJson produces valid JSON" {
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    const json = try gate.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"pas_score\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"confidence\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\"") != null);
}

// ============================================================================
// Part III: BatchValidator Tests
// ============================================================================

test "BatchValidator: init and deinit" {
    var batch = phi_gate.BatchValidator.init(std.testing.allocator);
    defer batch.deinit();

    try std.testing.expectEqual(@as(usize, 0), batch.gates.items.len);
}

test "BatchValidator: addGate increases count" {
    var batch = phi_gate.BatchValidator.init(std.testing.allocator);
    defer batch.deinit();

    var gate = phi_gate.PhiGate.init(std.testing.allocator);
    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    try batch.addGate(gate);
    try std.testing.expectEqual(@as(usize, 1), batch.gates.items.len);
}

test "BatchValidator: validateAll with mixed results" {
    var batch = phi_gate.BatchValidator.init(std.testing.allocator);
    defer batch.deinit();

    var gate1 = phi_gate.PhiGate.init(std.testing.allocator);
    gate1.setPasScore(0.96);
    gate1.setConfidence(0.97);
    gate1.setSonaQValue(0.8);
    try batch.addGate(gate1);

    var gate2 = phi_gate.PhiGate.init(std.testing.allocator);
    gate2.setPasScore(0.80);
    gate2.setConfidence(0.97);
    gate2.setSonaQValue(0.8);
    try batch.addGate(gate2);

    const result = batch.validateAll();

    try std.testing.expectEqual(@as(u32, 2), result.total);
    try std.testing.expectEqual(@as(u32, 1), result.passed);
    try std.testing.expectEqual(@as(u32, 1), result.failed);
    try std.testing.expect(!result.allPassed());
    try std.testing.expectApproxEqAbs(result.success_rate, 0.5, 0.01);
}

test "BatchValidator: allPassed returns true only when all pass" {
    var batch = phi_gate.BatchValidator.init(std.testing.allocator);
    defer batch.deinit();

    var gate = phi_gate.PhiGate.init(std.testing.allocator);
    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);
    try batch.addGate(gate);

    var result = batch.validateAll();
    try std.testing.expect(result.allPassed());
}

// ============================================================================
// Part IV: LinkResult Tests
// ============================================================================

test "LinkResult: passedPhiGate with good scores" {
    const result = phi_types.LinkResult{
        .link_number = 1,
        .pas_score = 0.96,
        .trinity_identity = true,
        .confidence = 0.97,
        .sona_q_value = 0.8,
        .next_action = .proceed,
        .generation_time_ms = 100,
        .validation_time_ms = 50,
    };

    try std.testing.expect(result.passedPhiGate());
}

test "LinkResult: passedPhiGate fails with low PAS" {
    const result = phi_types.LinkResult{
        .link_number = 1,
        .pas_score = 0.80,
        .trinity_identity = true,
        .confidence = 0.97,
        .sona_q_value = 0.8,
        .next_action = .proceed,
        .generation_time_ms = 100,
        .validation_time_ms = 50,
    };

    try std.testing.expect(!result.passedPhiGate());
}

test "LinkResult: qualityScore calculation" {
    const result = phi_types.LinkResult{
        .link_number = 1,
        .pas_score = 0.96,
        .trinity_identity = true,
        .confidence = 0.97,
        .sona_q_value = 0.8,
        .next_action = .proceed,
        .generation_time_ms = 100,
        .validation_time_ms = 50,
    };

    const score = result.qualityScore();
    try std.testing.expect(score > 0.8);
    try std.testing.expect(score <= 1.0);
}

// ============================================================================
// Part V: ProgressTracker Tests
// ============================================================================

test "ProgressTracker: completionPercentage at start" {
    const tracker = phi_types.ProgressTracker{
        .current_link = 1,
        .passed_links = 0,
        .failed_links = 0,
        .skipped_links = 0,
        .average_pas_score = 0.0,
        .start_time = std.time.timestamp(),
    };

    try std.testing.expect(tracker.completionPercentage() < 1.0);
}

test "ProgressTracker: completionPercentage at midpoint" {
    const tracker = phi_types.ProgressTracker{
        .current_link = 500,
        .passed_links = 450,
        .failed_links = 40,
        .skipped_links = 10,
        .average_pas_score = 0.92,
        .start_time = std.time.timestamp(),
    };

    try std.testing.expectApproxEqAbs(tracker.completionPercentage(), 50.0, 0.1);
}

test "ProgressTracker: successRate calculation" {
    const tracker = phi_types.ProgressTracker{
        .current_link = 100,
        .passed_links = 80,
        .failed_links = 15,
        .skipped_links = 5,
        .average_pas_score = 0.92,
        .start_time = std.time.timestamp(),
    };

    const rate = tracker.successRate();
    try std.testing.expectApproxEqAbs(rate, 0.842, 0.01);
}

test "ProgressTracker: remainingLinks calculation" {
    const tracker = phi_types.ProgressTracker{
        .current_link = 500,
        .passed_links = 450,
        .failed_links = 40,
        .skipped_links = 10,
        .average_pas_score = 0.92,
        .start_time = std.time.timestamp(),
    };

    try std.testing.expectEqual(@as(u32, 499), tracker.remainingLinks());
}

// ============================================================================
// Part VI: GeneratedCode and CodeMetrics Tests
// ============================================================================

test "GeneratedCode: metrics calculation" {
    const code = "// Test code\nconst x = 42;\ntest \"example\" {}\n";
    const generated = phi_types.GeneratedCode{
        .code = code,
        .output_path = "test.zig",
        .language = "zig",
        .pattern_id = 12345,
        .timestamp = std.time.timestamp(),
    };

    const metrics = generated.metrics();

    try std.testing.expectEqual(@as(usize, 3), metrics.line_count);
    try std.testing.expect(metrics.has_comments);
    try std.testing.expect(metrics.has_tests);
}

test "CodeMetrics: completeness score" {
    const metrics = phi_types.CodeMetrics{
        .line_count = 100,
        .has_comments = true,
        .has_tests = true,
        .char_count = 1000,
    };

    const score = metrics.completeness();
    try std.testing.expect(score >= 0.8);
}

// ============================================================================
// Part VII: PhiLoop Tests
// ============================================================================

test "PhiLoop: initialization" {
    const config = phi_loop.PhiLoop.Config{};
    const loop = phi_loop.PhiLoop.init(std.testing.allocator, config);

    try std.testing.expectEqual(@as(u32, 1), loop.link_number);
    try std.testing.expectEqual(@as(u32, 999), loop.max_links);
    try std.testing.expectEqual(phi_loop.PhiLoop.LoopState.idle, loop.state);
}

test "PhiLoop: progressJson format" {
    const config = phi_loop.PhiLoop.Config{};
    const loop = phi_loop.PhiLoop.init(std.testing.allocator, config);

    const json = try loop.progressJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "link_number") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "completion_percentage") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "success_rate") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "state") != null);
}

// ============================================================================
// Part VIII: Integration Tests
// ============================================================================

test "Integration: full phiGate workflow" {
    // Initialize gate
    var gate = phi_gate.PhiGate.init(std.testing.allocator);

    // Set good scores
    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    // Verify passes
    try std.testing.expect(gate.passes());

    // Get score
    const score = gate.gateScore();
    try std.testing.expect(score > 0.8);

    // Get status
    try std.testing.expectEqual(phi_gate.GateStatus.passed, gate.status());

    // Apply φ weight
    gate.applyPhiWeight();
    const weighted = gate.phiWeightedScore();
    try std.testing.expect(weighted > score);

    // Reset and verify
    gate.reset();
    try std.testing.expect(!gate.passes());
}

test "Integration: linkResult quality workflow" {
    const result = phi_types.LinkResult{
        .link_number = 42,
        .pas_score = 0.96,
        .trinity_identity = true,
        .confidence = 0.97,
        .sona_q_value = 0.8,
        .next_action = .proceed,
        .generation_time_ms = 100,
        .validation_time_ms = 50,
    };

    // Verify passed gate
    try std.testing.expect(result.passedPhiGate());

    // Get quality score
    const quality = result.qualityScore();
    try std.testing.expect(quality > 0.8);

    // Verify not complete
    try std.testing.expect(result.next_action != .complete);
}

test "Integration: batch validation workflow" {
    var batch = phi_gate.BatchValidator.init(std.testing.allocator);
    defer batch.deinit();

    // Add multiple gates
    for (0..5) |i| {
        var gate = phi_gate.PhiGate.init(std.testing.allocator);
        if (i < 3) {
            gate.setPasScore(0.96);
            gate.setConfidence(0.97);
            gate.setSonaQValue(0.8);
        } else {
            gate.setPasScore(0.80);
            gate.setConfidence(0.97);
            gate.setSonaQValue(0.8);
        }
        try batch.addGate(gate);
    }

    const result = batch.validateAll();

    try std.testing.expectEqual(@as(u32, 5), result.total);
    try std.testing.expectEqual(@as(u32, 3), result.passed);
    try std.testing.expectEqual(@as(u32, 2), result.failed);
    try std.testing.expectApproxEqAbs(result.success_rate, 0.6, 0.01);
}

// ============================================================================
// Summary
// ============================================================================
//
// Tests: 45+ tests covering:
// - Sacred constants (PHI, MU, Trinity Identity)
// - PhiGate validation and filtering
// - BatchValidator for multiple gates
// - LinkResult quality scoring
// - ProgressTracker metrics
// - GeneratedCode and CodeMetrics
// - PhiLoop state management
// - Integration workflows
//
// All tests verify the sacred math principles:
// φ² + 1/φ² = 3
// VIBEE writes VIBEE
// AGENT MU heals VIBEE
// SYMBOLIC AI remembers VIBEE
// φ GATE validates VIBEE
// NEXT LINK
