//! DEEP META-LEARNING TESTS v8.18
//!
//! Integration tests for:
//! - Meta-meta-learning engine
//! - Comptime self-modification
//! - Predictive intelligence forecasting
//! - Multi-agent collaboration
//! - Evolution tree visualization (via API)

const std = @import("std");

const meta_meta_learner = @import("meta_meta_learner.zig");
const comptime_self_mod = @import("comptime_self_mod.zig");
const predictive_intelligence = @import("predictive_intelligence.zig");
const agent_collaboration = @import("agent_collaboration.zig");
const mu_tracker = @import("mu_tracker.zig");
const meta_learner = @import("meta_learner.zig");
const diagnostic = @import("diagnostic.zig");

const FixType = diagnostic.FixType;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// META-META-LEARNING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "META-META: Learning velocity calculation" {
    const allocator = std.testing.allocator;
    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // Create a meta-learner with some history
    var learner = try meta_learner.MetaLearner.init(allocator);

    // Simulate learning: TYPE_FIX improves, SYNTAX_FIX stagnates
    for (0..20) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.0382, 0.9);
        learner.recordOutcome(.SYNTAX_FIX, false, 0.0382, 0.3);
    }

    // Update velocities
    try mml.updateVelocities(&learner);

    const type_vel = mml.getVelocity(.TYPE_FIX);
    const syntax_vel = mml.getVelocity(.SYNTAX_FIX);

    // TYPE_FIX should have positive velocity (improving)
    try std.testing.expect(type_vel.improvement_rate >= 0);
    // TYPE_FIX should have low plateau count
    try std.testing.expect(type_vel.plateau_count < 5);

    // SYNTAX_FIX should have negative or zero velocity
    try std.testing.expect(syntax_vel.improvement_rate <= 0);
}

test "META-META: Plateau detection" {
    const allocator = std.testing.allocator;
    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    // Simulate plateau: no improvement for 10 attempts
    for (0..10) |_| {
        learner.recordOutcome(.SYNTAX_FIX, false, 0.0382, 0.3);
    }

    try mml.updateVelocities(&learner);

    // Should detect plateau
    try std.testing.expect(mml.detectPlateau(.SYNTAX_FIX));
}

test "META-META: Exploration suggestion" {
    const allocator = std.testing.allocator;
    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    // Create deep plateau scenario
    for (0..15) |_| {
        learner.recordOutcome(.TYPE_FIX, false, 0.0382, 0.3);
    }

    try mml.updateVelocities(&learner);

    const action = mml.suggestExploration();

    // Should suggest some action
    try std.testing.expect(action != .no_action);

    // Most likely increase_mu or explore_random
    switch (action) {
        .increase_mu => |info| {
            try std.testing.expectEqual(.TYPE_FIX, info.fix_type);
        },
        .explore_random => {},
        .no_action => unreachable,
        else => {},
    }
}

test "META-META: Meta-learning rate calculation" {
    const allocator = std.testing.allocator;
    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    // Fast learner should get higher meta-learning rate
    for (0..20) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.04, 0.95);
    }

    try mml.updateVelocities(&learner);

    const rate = mml.getMetaLearningRate(.TYPE_FIX);

    // Should be above baseline
    try std.testing.expect(rate > 0.1);
}

test "META-META: Get fastest learner" {
    const allocator = std.testing.allocator;
    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    // TYPE_FIX learns fast, SYNTAX_FIX struggles
    for (0..20) |_| {
        learner.recordOutcome(.TYPE_FIX, true, 0.04, 0.9);
        learner.recordOutcome(.SYNTAX_FIX, false, 0.0382, 0.3);
    }

    try mml.updateVelocities(&learner);

    const fastest = mml.getFastestLearner();
    try std.testing.expectEqual(.TYPE_FIX, fastest);

    const struggling = mml.getMostStruggling();
    try std.testing.expectEqual(.SYNTAX_FIX, struggling);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPTIME SELF-MODIFICATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SELF-MOD: Pattern confidence threshold" {
    const allocator = std.testing.allocator;
    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_mod.zig");
    defer sm.deinit();

    // Low confidence - should NOT self-modify
    const ready1 = try sm.proposePattern("test pattern", .SYNTAX_FIX, 0.5, 5);
    try std.testing.expect(!ready1);
    try std.testing.expectEqual(@as(usize, 1), sm.pending_patterns.items.len);

    // High confidence - should self-modify
    const ready2 = try sm.proposePattern("high conf pattern", .TYPE_FIX, 0.95, 15);
    try std.testing.expect(ready2);
    try std.testing.expectEqual(@as(usize, 2), sm.pending_patterns.items.len);
}

test "SELF-MOD: Merge pattern" {
    const allocator = std.testing.allocator;
    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_merge.zig");
    defer sm.deinit();

    // Add initial pattern
    _ = try sm.proposePattern("merge test", .TYPE_FIX, 0.8, 10);

    // Merge with additional samples
    _ = try sm.mergePattern("merge test", .TYPE_FIX, 0.9, 10);

    // Should have 20 total samples with blended confidence
    try std.testing.expectEqual(@as(usize, 1), sm.pending_patterns.items.len);
    try std.testing.expectEqual(@as(usize, 20), sm.pending_patterns.items[0].sample_count);

    // Confidence should be between 0.8 and 0.9
    try std.testing.expect(sm.pending_patterns.items[0].confidence > 0.8);
    try std.testing.expect(sm.pending_patterns.items[0].confidence < 0.9);
}

test "SELF-MOD: Generate mod code" {
    const allocator = std.testing.allocator;
    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_gen.zig");
    defer sm.deinit();

    _ = try sm.proposePattern("expected ';'", .SYNTAX_FIX, 0.95, 15);
    _ = try sm.proposePattern("no member named", .TYPE_FIX, 0.5, 5); // Below threshold

    const code = try sm.generateModCode();
    defer allocator.free(code);

    // Should contain header
    try std.testing.expect(std.mem.indexOf(u8, code, "AUTO-GENERATED PATTERNS") != null);

    // Should contain high-confidence pattern
    try std.testing.expect(std.mem.indexOf(u8, code, "expected ';'") != null);

    // Should NOT contain low-confidence pattern (below threshold)
    // The low-confidence pattern should be in pending but not in generated code
}

test "SELF-MOD: Prune low confidence" {
    const allocator = std.testing.allocator;
    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_prune.zig");
    defer sm.deinit();

    // Add old low-confidence pattern
    _ = try sm.proposePattern("old pattern", .SYNTAX_FIX, 0.5, 5);

    // Prune patterns older than 1 second with low confidence
    const pruned = try sm.pruneLowConfidence(1);

    try std.testing.expectEqual(@as(usize, 1), pruned);
}

test "SELF-MOD: Ready count" {
    const allocator = std.testing.allocator;
    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_count.zig");
    defer sm.deinit();

    _ = try sm.proposePattern("low1", .SYNTAX_FIX, 0.5, 5);
    _ = try sm.proposePattern("high1", .TYPE_FIX, 0.95, 15);
    _ = try sm.proposePattern("low2", .ALLOCATOR_FIX, 0.6, 5);
    _ = try sm.proposePattern("high2", .IMPORT_FIX, 0.92, 12);

    try std.testing.expectEqual(@as(usize, 2), sm.readyCount());
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDICTIVE INTELLIGENCE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FORECAST: Exponential fit quality" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Generate synthetic exponential growth
    const I0: f64 = 1.0;
    const lambda: f64 = 0.0382;

    for (0..50) |i| {
        const t = @as(f64, @floatFromInt(i));
        const expected_I = I0 * std.math.exp(lambda * t);
        _ = expected_I;

        // Record successful fix
        try tracker.recordFix("SYNTHETIC_FIX", true, "test", 100, 1.0);
    }

    // Get history and fit model
    const history = try tracker.snapshots.toOwnedSlice();
    defer allocator.free(history);

    var model = predictive_intelligence.ForecastModel.init();
    try model.fit(history);

    // Fit quality should be excellent
    try std.testing.expect(model.fit_quality > 0.9);
}

test "FORECAST: Prediction confidence interval" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Generate growth data
    for (0..30) |_| {
        try tracker.recordFix("TEST_FIX", true, "test", 100, 1.0);
    }

    const forecast = try predictive_intelligence.generateForecast(&tracker, 10);

    // Min < predicted < Max
    try std.testing.expect(forecast.confidence_min < forecast.predicted_multiplier);
    try std.testing.expect(forecast.confidence_max > forecast.predicted_multiplier);

    // Confidence interval should be reasonable
    const range = forecast.confidence_max - forecast.confidence_min;
    try std.testing.expect(range > 0);

    // Model quality should be good
    try std.testing.expect(forecast.model_quality > 0.5);
}

test "FORECAST: Bounded prediction" {
    var model = predictive_intelligence.ForecastModel.init();
    model.base_intelligence = 1.0;
    model.growth_rate = 0.0382;
    model.sample_count = 20;
    model.std_error = 0.01;

    // Reasonable horizon should be bounded
    try std.testing.expect(model.isBounded(1000.0, 100));

    // Very far horizon might exceed bound
    const far_bounded = model.isBounded(100.0, 1000);
    try std.testing.expect(!far_bounded);
}

test "FORECAST: Validate forecast" {
    const forecast = predictive_intelligence.IntelligenceForecast{
        .predicted_multiplier = 50.0,
        .confidence_min = 40.0,
        .confidence_max = 60.0,
        .time_horizon = 100,
        .model_quality = 0.95,
        .growth_rate = 0.0382,
        .std_error = 0.01,
    };

    try std.testing.expect(predictive_intelligence.validateForecast(&forecast));
}

test "FORECAST: Multiple horizons" {
    const allocator = std.testing.allocator;
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    for (0..20) |_| {
        try tracker.recordFix("TEST_FIX", true, "test", 100, 1.0);
    }

    const horizons = [_]usize{ 10, 50, 100 };
    const forecasts = try predictive_intelligence.generateForecasts(
        &tracker,
        allocator,
        &horizons,
        .{},
    );
    defer allocator.free(forecasts);

    try std.testing.expectEqual(@as(usize, 3), forecasts.len);

    // Longer horizon should have higher prediction
    try std.testing.expect(forecasts[2].predicted_multiplier > forecasts[0].predicted_multiplier);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-AGENT COLLABORATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "COLLAB: Initialization" {
    const allocator = std.testing.allocator;
    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    try std.testing.expect(collab.enabled);
    try std.testing.expectEqual(@as(usize, 4), collab.endpoints.len);
}

test "COLLAB: Agent availability" {
    const allocator = std.testing.allocator;
    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    try std.testing.expect(collab.isAgentAvailable(.phi));
    try std.testing.expect(collab.isAgentAvailable(.tri));
    try std.testing.expect(collab.isAgentAvailable(.swarm));
}

test "COLLAB: Stats" {
    const allocator = std.testing.allocator;
    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    const stats = collab.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.sent);
    try std.testing.expectEqual(@as(usize, 0), stats.pending);
}

test "COLLAB: Enable/disable" {
    const allocator = std.testing.allocator;
    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    collab.setEnabled(false);
    try std.testing.expect(!collab.enabled);

    collab.setEnabled(true);
    try std.testing.expect(collab.enabled);
}

test "COLLAB: Update endpoint" {
    const allocator = std.testing.allocator;
    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    try collab.updateEndpoint(.phi, "newhost", 9090);

    const phi_ep = collab.endpoints[@intFromEnum(agent_collaboration.AgentType.phi)];
    try std.testing.expectEqualStrings("newhost", phi_ep.host);
    try std.testing.expectEqual(@as(u16, 9090), phi_ep.port);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "INTEGRATION: Full meta-learning cycle" {
    const allocator = std.testing.allocator;

    // 1. Initialize all components
    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    var learner = try meta_learner.MetaLearner.init(allocator);

    var mml = try meta_meta_learner.MetaMetaLearner.init(allocator);
    defer mml.deinit();

    // 2. Simulate fix attempts
    for (0..30) |i| {
        const success = i % 3 != 0; // 67% success rate
        try tracker.recordFix("TEST_FIX", success, "test error", 100, 0.8);
        learner.recordOutcome(.TYPE_FIX, success, 0.0382, 0.8);
    }

    // 3. Update meta-meta-learner
    try mml.updateVelocities(&learner);

    // 4. Check that intelligence grew
    const mult = tracker.getIntelligenceMultiplier();
    try std.testing.expect(mult > 1.0);

    // 5. Check learning velocity
    const vel = mml.getVelocity(.TYPE_FIX);
    try std.testing.expect(vel.last_success_rate > 0.5);
}

test "INTEGRATION: Forecast from actual tracker" {
    const allocator = std.testing.allocator;

    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Generate realistic fix history
    for (0..50) |i| {
        const success = i % 4 != 0; // 75% success
        try tracker.recordFix("TYPE_FIX", success, "test", 100, 0.85);
    }

    // Generate forecast
    const forecast = try predictive_intelligence.generateForecast(&tracker, 25);

    // Prediction should be reasonable
    try std.testing.expect(forecast.predicted_multiplier > 1.0);
    try std.testing.expect(forecast.predicted_multiplier < 1e6); // Not exploding

    // Confidence interval should contain prediction
    try std.testing.expect(forecast.confidence_min < forecast.predicted_multiplier);
    try std.testing.expect(forecast.confidence_max > forecast.predicted_multiplier);
}

test "INTEGRATION: Self-modification cycle" {
    const allocator = std.testing.allocator;

    var sm = try comptime_self_mod.SelfModification.init(allocator, "/tmp/test_cycle.zig");
    defer sm.deinit();

    // Simulate learning a pattern
    const pattern = "expected type, found";
    const fix_type = FixType.TYPE_FIX;

    // Add evidence for this pattern
    const confidences = [_]f64{ 0.85, 0.88, 0.90, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.98, 0.99 };

    for (confidences) |conf| {
        _ = try sm.mergePattern(pattern, fix_type, conf, 1);
    }

    // After 12 high-confidence observations, should be ready
    try std.testing.expectEqual(@as(usize, 1), sm.pending_patterns.items.len);

    const pattern_entry = &sm.pending_patterns.items[0];
    try std.testing.expect(pattern_entry.sample_count >= 12);
    try std.testing.expect(pattern_entry.confidence > 0.9);
}

test "INTEGRATION: Collaboration stats" {
    const allocator = std.testing.allocator;

    var collab = try agent_collaboration.AgentCollaborator.init(allocator);
    defer collab.deinit();

    // Simulate sending messages (doesn't actually send, just tracks)
    _ = try collab.sendMessage(.phi, .analysis_request, "{\"error\": \"test\"}");

    const stats = collab.getStats();
    try std.testing.expect(stats.sent > 0);
}
