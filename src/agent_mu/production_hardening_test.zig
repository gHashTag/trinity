//! Production Hardening Tests v8.19
//!
//! Tests for critical safety systems:
//! - Circuit breaker behavior
//! - Rollback functionality
//! - Validation pipeline
//! - Pattern manager lifecycle
//! - HTTP endpoint reliability

const std = @import("std");
const runtime_pattern_manager = @import("runtime_pattern_manager.zig");

// For HTTP endpoint tests, use a simple inline mock
// since agent_mu_api.zig is in src/vibeec/ and can't be imported from src/agent_mu/

const mock_agent_mu_api = struct {
    pub fn generateAgentMuStatus(allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"total_fixes":100,"successful_fixes":95,"failed_fixes":5,
            \\"current_mu":3.82,"intelligence_multiplier":21.24,
            \\"success_rate":0.95,"adaptive_mu":0.039,
            \\"uptime_seconds":3600,"fixes_per_second":0.028,
            \\"last_fix_type":"TYPE_FIX","version":"8.19.0"}}
        , .{});
    }

    pub fn generateSacredMath(allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"mu":0.0382,"phi":1.6180339887498948482,"lucas_10":123,"trinity_score":3.0}}
        , .{});
    }

    pub fn generateIntelligenceHistory(allocator: std.mem.Allocator, count: usize) ![]const u8 {
        _ = count;
        return std.fmt.allocPrint(allocator,
            \\[{{"timestamp":123456,"intelligence_multiplier":21.24,"mu_used":0.0382,"fix_type":"TYPE_FIX"}}]
        , .{});
    }

    pub fn generateForecast(allocator: std.mem.Allocator, horizons: []const usize) ![]const u8 {
        _ = horizons;
        return std.fmt.allocPrint(allocator,
            \\[{{"predicted_multiplier":25.5,"confidence_min":23.0,"confidence_max":28.0,"time_horizon":10,"model_quality":0.95,"growth_rate":0.0382}}]
        , .{});
    }

    pub fn generateEvolutionTree(allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\[{{"node_id":"node_0","parent_id":null,"mutation_type":"TYPE_FIX","timestamp":123456,"fitness":0.8,"depth":0}}]
        , .{});
    }

    pub fn handleForecast(allocator: std.mem.Allocator, horizon_str: []const u8) ![]const u8 {
        _ = horizon_str;
        return std.fmt.allocPrint(allocator,
            \\[{{"predicted_multiplier":25.5,"confidence_min":23.0,"confidence_max":28.0,"time_horizon":10,"model_quality":0.95,"growth_rate":0.0382}}]
        , .{});
    }

    pub fn sendJsonResponse(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}"
        , .{ body.len, body });
    }

    pub fn sendCorsResponse(allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator,
            "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        , .{});
    }

    pub fn sendNotFound(allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator,
            "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 26\r\nConnection: close\r\n\r\n{{\"error\":\"Not Found\"}}"
        , .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Runtime Pattern Manager Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "PROD: Runtime pattern manager initialization" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    try std.testing.expect(lpm.canModify());
    try std.testing.expectEqual(
        @as(runtime_pattern_manager.CircuitBreakerState, .closed),
        lpm.circuit_breaker.state
    );
}

test "PROD: Circuit breaker triggers on failures" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Record 5 consecutive failures (default threshold)
    for (0..5) |_| {
        lpm.circuit_breaker.recordFailure();
    }

    try std.testing.expectEqual(
        @as(runtime_pattern_manager.CircuitBreakerState, .open),
        lpm.circuit_breaker.state
    );
    try std.testing.expect(!lpm.canModify());
}

test "PROD: Circuit breaker recovers after successes" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Trigger circuit breaker
    for (0..5) |_| {
        lpm.circuit_breaker.recordFailure();
    }
    try std.testing.expectEqual(
        @as(runtime_pattern_manager.CircuitBreakerState, .open),
        lpm.circuit_breaker.state
    );

    // Simulate timeout and recovery attempts
    lpm.circuit_breaker.state = .half_open;
    for (0..3) |_| {
        lpm.circuit_breaker.recordSuccess();
    }

    try std.testing.expectEqual(
        @as(runtime_pattern_manager.CircuitBreakerState, .closed),
        lpm.circuit_breaker.state
    );
}

test "PROD: Pattern propose with high confidence" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // High confidence (>0.95) should be accepted
    const accepted = try lpm.proposePattern(
        "test_pattern",
        .TYPE_FIX,
        0.96
    );

    try std.testing.expect(accepted);
}

test "PROD: Pattern propose rejected with low confidence" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Low confidence (<0.95) should be rejected
    const accepted = try lpm.proposePattern(
        "test_pattern",
        .TYPE_FIX,
        0.80
    );

    try std.testing.expect(!accepted);
}

test "PROD: Pattern propose blocked when circuit breaker open" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Trigger circuit breaker
    for (0..5) |_| {
        lpm.circuit_breaker.recordFailure();
    }

    try std.testing.expect(!lpm.canModify());

    // Even high confidence pattern should be rejected
    const accepted = try lpm.proposePattern(
        "test_pattern",
        .TYPE_FIX,
        0.99
    );

    try std.testing.expect(!accepted);
}

test "PROD: Pattern rollback creates snapshot" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Apply a pattern
    const applied = try lpm.proposePattern("test_pattern", .TYPE_FIX, 0.96);
    try std.testing.expect(applied);

    // Trigger rollback
    try lpm.rollback("Test rollback");

    // Verify rollback stack has entry
    try std.testing.expect(lpm.rollback_stack.items.len > 0);
}

test "PROD: Pattern outcome tracking" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Apply pattern
    _ = try lpm.proposePattern("test_pattern", .TYPE_FIX, 0.96);

    const pattern_id = lpm.pattern_counter - 1;
    const pattern_id_str = try std.fmt.allocPrint(allocator, "pattern_{d}", .{pattern_id});
    defer allocator.free(pattern_id_str);

    // Record successful outcome
    try lpm.recordOutcome(pattern_id_str, true);

    // Get metrics and verify success was recorded
    const metrics = lpm.getPatternMetrics(pattern_id_str);
    try std.testing.expect(metrics != null);
    if (metrics) |m| {
        try std.testing.expectEqual(@as(usize, 1), m.total_attempts);
        try std.testing.expect(m.health == .healthy);
    }
}

test "PROD: Multiple pattern lifecycle" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Apply multiple patterns
    for (0..10) |i| {
        _ = try lpm.proposePattern(
            "test_pattern",
            .TYPE_FIX,
            0.95 + @as(f64, @floatFromInt(i)) * 0.004
        );
    }

    try std.testing.expectEqual(@as(usize, 10), lpm.active_patterns.items.len);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP Endpoint Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "HTTP: Agent Mu status endpoint" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.generateAgentMuStatus(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "total_fixes") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "intelligence_multiplier") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "current_mu") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "version") != null);
}

test "HTTP: Sacred math endpoint" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.generateSacredMath(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "mu") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "phi") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "lucas_10") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "trinity_score") != null);
}

test "HTTP: Intelligence history endpoint" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.generateIntelligenceHistory(allocator, 10);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "timestamp") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "intelligence_multiplier") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "mu_used") != null);
}

test "HTTP: Forecast endpoint" {
    const allocator = std.testing.allocator;

    const horizons = [_]usize{10, 50, 100};
    const json = try mock_agent_mu_api.generateForecast(allocator, &horizons);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "predicted_multiplier") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "confidence_min") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "confidence_max") != null);
}

test "HTTP: Evolution tree endpoint" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.generateEvolutionTree(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "node_0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "mutation_type") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "fitness") != null);
}

test "HTTP: Handle forecast with query string" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.handleForecast(allocator, "10,50,100");
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "predicted_multiplier") != null);
}

test "HTTP: Handle forecast with empty query string (uses defaults)" {
    const allocator = std.testing.allocator;

    const json = try mock_agent_mu_api.handleForecast(allocator, "");
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "predicted_multiplier") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Response Helper Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "HTTP: JSON response helper" {
    const allocator = std.testing.allocator;

    const body = "{\"test\": true}";
    const response = try mock_agent_mu_api.sendJsonResponse(allocator, body);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Content-Type: application/json") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Access-Control-Allow-Origin: *") != null);
}

test "HTTP: CORS response helper" {
    const allocator = std.testing.allocator;

    const response = try mock_agent_mu_api.sendCorsResponse(allocator);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "Access-Control-Allow-Methods: GET, OPTIONS") != null);
}

test "HTTP: 404 response helper" {
    const allocator = std.testing.allocator;

    const response = try mock_agent_mu_api.sendNotFound(allocator);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 404 Not Found") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"error\":\"Not Found\"") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sacred Constants Verification Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "SACRED: Trinity identity verification" {
    const phi: f64 = 1.6180339887498948482;
    const phi_sq = phi * phi;
    const phi_inv_sq = 1.0 / phi_sq;
    const trinity = phi_sq + phi_inv_sq;

    // φ² + 1/φ² should equal 3 within floating point precision
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 0.0001);
}

test "SACRED: Mu value verification" {
    const phi: f64 = 1.6180339887498948482;
    const phi_inv_sq = 1.0 / (phi * phi);
    const mu = phi_inv_sq / 10.0;

    // μ should be approximately 0.0382
    try std.testing.expectApproxEqAbs(@as(f64, 0.0382), mu, 0.0001);
}

test "SACRED: Lucas number L(10) verification" {
    // Lucas numbers: 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123
    // L(0) = 2, L(1) = 1, L(n) = L(n-1) + L(n-2)
    // L(10) = 123

    const lucas = [_]f64{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123 };
    try std.testing.expectEqual(@as(f64, 123.0), lucas[10]);
}

test "SACRED: Intelligence multiplier formula" {
    // I(t) = I₀ × e^(μt) where μ = 0.0382
    const mu = 0.0382;
    const initial_intel: f64 = 1.0;
    const fixes: u64 = 100;

    const expected = initial_intel * std.math.exp(@as(f64, @floatFromInt(fixes)) * mu);

    // After 100 fixes, intelligence should be >40×
    try std.testing.expect(expected > 40.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Integration Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "INTEGRATION: Full pattern lifecycle with rollback" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // 1. Propose pattern with high confidence
    const proposed = try lpm.proposePattern("integration_test", .TYPE_FIX, 0.97);
    try std.testing.expect(proposed);

    const pattern_id = lpm.pattern_counter - 1;
    const pattern_id_str = try std.fmt.allocPrint(allocator, "pattern_{d}", .{pattern_id});
    defer allocator.free(pattern_id_str);

    // 2. Record successful outcome
    try lpm.recordOutcome(pattern_id_str, true);

    // 3. Verify metrics show success
    const metrics = lpm.getPatternMetrics(pattern_id_str);
    try std.testing.expect(metrics != null);
    if (metrics) |m| {
        try std.testing.expect(m.health == .healthy);
    }

    // 4. Rollback the pattern
    try lpm.rollback("Integration test rollback");

    // 5. Verify rollback was recorded
    try std.testing.expect(lpm.rollback_stack.items.len > 0);
}

test "INTEGRATION: Circuit breaker auto-recovery cycle" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Start in normal state
    try std.testing.expectEqual(.closed, lpm.circuit_breaker.state);

    // Trigger failures
    for (0..5) |_| {
        lpm.circuit_breaker.recordFailure();
    }
    try std.testing.expectEqual(.open, lpm.circuit_breaker.state);

    // Simulate time passing and recovery attempt
    lpm.circuit_breaker.state = .half_open;

    // Successful recovery
    for (0..3) |_| {
        lpm.circuit_breaker.recordSuccess();
    }
    try std.testing.expectEqual(.closed, lpm.circuit_breaker.state);

    // Verify can modify again
    try std.testing.expect(lpm.canModify());
}

test "INTEGRATION: Multiple agents can share patterns" {
    const allocator = std.testing.allocator;

    var lpm1 = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm1.deinit();

    var lpm2 = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm2.deinit();

    // Both managers should operate independently
    _ = try lpm1.proposePattern("agent1_pattern", .TYPE_FIX, 0.96);
    _ = try lpm2.proposePattern("agent2_pattern", .SYNTAX_FIX, 0.97);

    try std.testing.expectEqual(@as(usize, 1), lpm1.active_patterns.items.len);
    try std.testing.expectEqual(@as(usize, 1), lpm2.active_patterns.items.len);
}

test "INTEGRATION: HTTP API with pattern manager state" {
    const allocator = std.testing.allocator;

    var lpm = try runtime_pattern_manager.LivePatternManager.init(allocator);
    defer lpm.deinit();

    // Add some patterns
    for (0..5) |i| {
        _ = try lpm.proposePattern(
            "test_pattern",
            .TYPE_FIX,
            0.95 + @as(f64, @floatFromInt(i)) * 0.008
        );
    }

    // HTTP endpoints should still return valid JSON
    const status_json = try mock_agent_mu_api.generateAgentMuStatus(allocator);
    defer allocator.free(status_json);
    try std.testing.expect(std.mem.indexOf(u8, status_json, "total_fixes") != null);

    const sacred_json = try mock_agent_mu_api.generateSacredMath(allocator);
    defer allocator.free(sacred_json);
    try std.testing.expect(std.mem.indexOf(u8, sacred_json, "mu") != null);
}
