//! META-LEARNING INTEGRATION TEST v8.16
//!
//! Tests the complete meta-learning system:
//! - Adaptive μ calculation
//! - FixType strategy optimization
//! - Intelligence curve monotonic growth
//! - Comptime pattern matching

const std = @import("std");

// Import AGENT MU modules
const mu_tracker = @import("mu_tracker.zig");
const meta_learner = @import("meta_learner.zig");
const comptime_embeddings = @import("comptime_embeddings.zig");
const diagnostic = @import("diagnostic.zig");

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 1: Adaptive μ Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNING: Adaptive μ scales with success rate" {
    // Baseline: success_rate = 0.5 → μ = 0.0382
    const mu_baseline = mu_tracker.calculateAdaptiveMu(0.5);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), mu_baseline, 0.001);

    // High success: μ increases
    const mu_high = mu_tracker.calculateAdaptiveMu(0.8);
    try std.testing.expect(mu_high > mu_baseline);

    // Low success: μ decreases
    const mu_low = mu_tracker.calculateAdaptiveMu(0.2);
    try std.testing.expect(mu_low < mu_baseline);

    // Verify ordering
    try std.testing.expect(mu_high > mu_low);
}

test "META-LEARNING: μ clamping prevents instability" {
    // Test lower bound
    const clamped_low = mu_tracker.clampMu(0.001);
    try std.testing.expect(clamped_low >= 0.01);

    // Test upper bound
    const clamped_high = mu_tracker.clampMu(1.0);
    try std.testing.expect(clamped_high <= 0.1);

    // Normal values pass through
    const normal = mu_tracker.clampMu(0.0382);
    try std.testing.expectApproxEqRel(@as(f64, 0.0382), normal, 0.001);
}

test "META-LEARNING: Adaptive μ monotonicity" {
    // μ should increase monotonically with success_rate
    const mu_00 = mu_tracker.calculateAdaptiveMu(0.0);
    const mu_25 = mu_tracker.calculateAdaptiveMu(0.25);
    const mu_50 = mu_tracker.calculateAdaptiveMu(0.5);
    const mu_75 = mu_tracker.calculateAdaptiveMu(0.75);
    const mu_100 = mu_tracker.calculateAdaptiveMu(1.0);

    try std.testing.expect(mu_00 <= mu_25);
    try std.testing.expect(mu_25 <= mu_50);
    try std.testing.expect(mu_50 <= mu_75);
    try std.testing.expect(mu_75 <= mu_100);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 2: Meta-Learner Integration Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNER: FixType strategy optimization" {
    const allocator = std.testing.allocator;
    var learner = try meta_learner.MetaLearner.init(allocator);

    // Record 10 successful TYPE_FIX with μ = 0.05
    for (0..10) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.05, 0.9);
    }

    // Optimal μ should have moved toward 0.05
    const optimal = learner.getOptimalMu(.TYPE_FIX);
    try std.testing.expect(optimal > 0.0382);
    try std.testing.expect(optimal <= 0.05);

    // Recommended μ should be between baseline and optimal
    const recommended = learner.getRecommendedMu(.TYPE_FIX);
    try std.testing.expect(recommended > 0.0382);
    try std.testing.expect(recommended <= optimal);
}

test "META-LEARNER: Multiple FixType tracking" {
    const allocator = std.testing.allocator;
    var learner = try meta_learner.MetaLearner.init(allocator);

    // Track different FixTypes
    learner.recordOutcome(.TYPE_FIX, true, 0.04, 0.9);
    learner.recordOutcome(.TYPE_FIX, true, 0.045, 0.85);
    learner.recordOutcome(.SYNTAX_FIX, false, 0.0382, 0.0);
    learner.recordOutcome(.SYNTAX_FIX, true, 0.05, 0.8);
    learner.recordOutcome(.ALLOCATOR_FIX, true, 0.0382, 0.95);

    // TYPE_FIX: 100% success
    const type_strategy = learner.getStrategy(.TYPE_FIX);
    try std.testing.expectEqual(@as(usize, 2), type_strategy.success_count);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), type_strategy.successRate(), 0.01);

    // SYNTAX_FIX: 50% success
    const syntax_strategy = learner.getStrategy(.SYNTAX_FIX);
    try std.testing.expectEqual(@as(usize, 1), syntax_strategy.success_count);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), syntax_strategy.successRate(), 0.01);

    // ALLOCATOR_FIX: 100% success
    const alloc_strategy = learner.getStrategy(.ALLOCATOR_FIX);
    try std.testing.expectEqual(@as(usize, 1), alloc_strategy.success_count);
}

test "META-LEARNER: Propose new FixType innovation" {
    const allocator = std.testing.allocator;
    var learner = try meta_learner.MetaLearner.init(allocator);

    // With no history, should return UNKNOWN or null
    const proposed = learner.proposeNewFixType("some unknown error");
    try std.testing.expect(proposed != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 3: Intelligence Curve Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNING: Intelligence curve monotonic growth" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    const start_mult = tracker.getIntelligenceMultiplier();

    // Record successful fixes
    for (0..10) |_| {
        try tracker.recordFix("TYPE_FIX", true, "Test error", 100, 0.9);
    }

    const end_mult = tracker.getIntelligenceMultiplier();
    try std.testing.expect(end_mult > start_mult);

    // Intelligence should be > 1.0
    try std.testing.expect(end_mult > 1.0);
}

test "META-LEARNING: Intelligence history ordering" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Create 5 snapshots
    for (0..5) |i| {
        _ = i;
        try tracker.recordFix("TYPE_FIX", true, "test", 100, 0.9);
        // Note: Timestamps will be very close but sequential due to loop ordering
    }

    // Get last 3 snapshots
    const history = try tracker.getIntelligenceHistory(allocator, 3);
    defer allocator.free(history);

    try std.testing.expectEqual(@as(usize, 3), history.len);

    // Should be in newest-first order
    for (0..history.len - 1) |i| {
        try std.testing.expect(history[i].timestamp >= history[i + 1].timestamp);
    }
}

test "META-LEARNING: Intelligence projection accuracy" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Start with 10 successful fixes
    for (0..10) |_| {
        try tracker.recordFix("TYPE_FIX", true, "test", 100, 1.0);
    }

    const current = tracker.getIntelligenceMultiplier();

    // Project 10 more successful fixes
    const proj = tracker.projectIntelligence(10);

    // Projected should be higher than current
    try std.testing.expect(proj.projected_multiplier > current);

    // Gain should be significant (> 1.4× for 10 fixes)
    try std.testing.expect(proj.gain_from_current > 1.4);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 4: Comptime Pattern Matching Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNING: Comptime pattern matching" {
    // Syntax error should match SYNTAX_FIX
    const syntax_result = comptime_embeddings.findPattern(
        \\error: expected ';', found '}'
    );
    try std.testing.expect(syntax_result != null);
    try std.testing.expectEqual(diagnostic.FixType.SYNTAX_FIX, syntax_result.?.pattern.fix_type);

    // Type error should match TYPE_FIX
    const type_result = comptime_embeddings.findPattern(
        \\error: type mismatch: expected 'u32', found 'i32'
    );
    try std.testing.expect(type_result != null);
    try std.testing.expectEqual(diagnostic.FixType.TYPE_FIX, type_result.?.pattern.fix_type);

    // Allocator error should match ALLOCATOR_FIX (note: test with missing parameter)
    const alloc_result = comptime_embeddings.findPattern(
        \\error: missing parameter: allocator
    );
    try std.testing.expect(alloc_result != null);
    try std.testing.expectEqual(diagnostic.FixType.ALLOCATOR_FIX, alloc_result.?.pattern.fix_type);
}

test "META-LEARNING: No pattern returns null" {
    const result = comptime_embeddings.findPattern(
        \\this error message doesn't match any known pattern
    );
    try std.testing.expect(result == null);
}

test "META-LEARNING: Comptime embeddings are deterministic" {
    const emb1 = comptime_embeddings.comptimeEmbedding("test pattern");
    const emb2 = comptime_embeddings.comptimeEmbedding("test pattern");

    try std.testing.expectEqualSlices(f64, &emb1, &emb2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 5: Full System Integration Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNING: End-to-end adaptive evolution" {
    const allocator = std.testing.allocator;

    // Initialize both tracker and learner
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    // Simulate 20 fixes with varying success
    var type_successes: usize = 0;
    var syntax_successes: usize = 0;

    for (0..20) |i| {
        const is_type_fix = i % 2 == 0;
        const success = i % 3 != 0; // ~67% success rate

        if (is_type_fix) {
            try tracker.recordFix("TYPE_FIX", success, "test error", 100, 0.8);
            learner.recordOutcome(.TYPE_FIX, success, 0.04, 0.8);
            if (success) type_successes += 1;
        } else {
            try tracker.recordFix("SYNTAX_FIX", success, "test error", 100, 0.75);
            learner.recordOutcome(.SYNTAX_FIX, success, 0.035, 0.75);
            if (success) syntax_successes += 1;
        }
    }

    // Verify tracker recorded all fixes
    try std.testing.expectEqual(@as(usize, 20), tracker.total_fixes);

    // Verify intelligence grew
    const final_mult = tracker.getIntelligenceMultiplier();
    try std.testing.expect(final_mult > 1.0);

    // Verify learner has statistics
    const type_strategy = learner.getStrategy(.TYPE_FIX);
    try std.testing.expect(type_strategy.attempt_count > 0);

    const syntax_strategy = learner.getStrategy(.SYNTAX_FIX);
    try std.testing.expect(syntax_strategy.attempt_count > 0);
}

test "META-LEARNING: Sacred math consistency" {
    // Verify φ² + 1/φ² = 3 (Trinity Identity)
    const phi = mu_tracker.PHI;
    const phi_squared = phi * phi;
    const inv_phi_squared = 1.0 / (phi * phi);
    try std.testing.expectApproxEqRel(@as(f64, 3.0), phi_squared + inv_phi_squared, 0.0001);

    // Verify L(10) = 123
    try std.testing.expectApproxEqRel(@as(f64, 123.0), mu_tracker.LUCAS_10, 0.001);

    // Verify μ = 1/φ²/10
    const expected_mu = 1.0 / (phi * phi) / 10.0;
    try std.testing.expectApproxEqRel(mu_tracker.SACRED_MU, expected_mu, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Benchmark: Meta-Learning Performance
// ═══════════════════════════════════════════════════════════════════════════════

test "META-LEARNING benchmark: 100 fixes intelligence curve" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    const start_time = std.time.nanoTimestamp();

    // Simulate 100 successful fixes (80% success rate)
    for (0..100) |i| {
        const success = i % 5 != 0; // 80% success
        try tracker.recordFix("TYPE_FIX", success, "test", 50, 0.85);
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    const final_mult = tracker.getIntelligenceMultiplier();
    const final_mu = tracker.getCurrentMu();

    std.debug.print(
        \\META-LEARNING Benchmark Results:
        \\  Total fixes:        {d}
        \\  Successful:         {d}
        \\  Failed:             {d}
        \\  Success rate:       {d:.1}%
        \\  Final μ:            {d:.4}
        \\  Intelligence:       {d:.2}×
        \\  Time:               {d:.2} ms
        \\
    , .{
        tracker.total_fixes,
        tracker.successful_fixes,
        tracker.failed_fixes,
        tracker.getSuccessRate() * 100.0,
        final_mu,
        final_mult,
        elapsed_ms,
    });

    // Verify reasonable growth
    try std.testing.expect(final_mult > 1.0);
    try std.testing.expect(final_mult < 100.0); // Should be < 100× for 80 fixes
}
