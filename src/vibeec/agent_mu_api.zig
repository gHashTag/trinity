//! AGENT MU HTTP API v8.18
//!
//! HTTP endpoints for AGENT MU dashboard integration:
//! - GET /api/agent-mu/status - Current intelligence metrics
//! - GET /api/agent-mu/history - Intelligence history (curve data)
//! - GET /api/agent-mu/forecast - Predictive intelligence forecasting
//! - GET /api/agent-mu/evolution-tree - Evolution tree data
//! - GET /api/agent-mu/meta-learner - Meta-learning strategies
//!
//! Returns JSON for dashboard consumption with mock fallbacks.

const std = @import("std");
const mu_tracker = @import("agent_mu/mu_tracker.zig");
const predictive_intelligence = @import("agent_mu/predictive_intelligence.zig");
const meta_learner = @import("agent_mu/meta_learner.zig");
const comptime_self_mod = @import("agent_mu/comptime_self_mod.zig");

const Allocator = std.mem.Allocator;

/// AGENT MU status response
pub const AgentMuStatus = struct {
    total_fixes: usize,
    successful_fixes: usize,
    failed_fixes: usize,
    current_mu: f64,
    intelligence_multiplier: f64,
    success_rate: f64,
    adaptive_mu: f64,
    uptime_seconds: i64,
    fixes_per_second: f64,
    last_fix_type: ?[]const u8,
    version: []const u8,

    /// Serialize to JSON
    pub fn toJson(self: *const AgentMuStatus, allocator: Allocator) ![]const u8 {
        const last_fix_str = if (self.last_fix_type) |fix|
            try std.fmt.allocPrint(allocator, "\"{s}\"", .{fix})
        else
            "null";

        return std.fmt.allocPrint(allocator,
            \\{{"total_fixes":{d},"successful_fixes":{d},"failed_fixes":{d},
            \\"current_mu":{d:.6},"intelligence_multiplier":{d:.4},
            \\"success_rate":{d:.4},"adaptive_mu":{d:.6},
            \\"uptime_seconds":{d},"fixes_per_second":{d:.2},
            \\"last_fix_type":{s},"version":"{s}"}}
        , .{
            self.total_fixes,
            self.successful_fixes,
            self.failed_fixes,
            self.current_mu,
            self.intelligence_multiplier,
            self.success_rate,
            self.adaptive_mu,
            self.uptime_seconds,
            self.fixes_per_second,
            last_fix_str,
            self.version,
        });
    }
};

/// Intelligence history point for curve visualization
pub const IntelligenceHistoryPoint = struct {
    timestamp: i64,
    intelligence_multiplier: f64,
    mu_used: f64,
    fix_type: []const u8,

    /// Serialize to JSON
    pub fn toJson(self: *const IntelligenceHistoryPoint, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"timestamp":{d},"intelligence_multiplier":{d:.6},
            \\"mu_used":{d:.6},"fix_type":"{s}"}}
        , .{
            self.timestamp,
            self.intelligence_multiplier,
            self.mu_used,
            self.fix_type,
        });
    }
};

/// Intelligence forecast data
pub const IntelligenceForecastData = struct {
    predicted_multiplier: f64,
    confidence_min: f64,
    confidence_max: f64,
    time_horizon: usize,
    model_quality: f64,
    growth_rate: f64,

    /// Serialize to JSON
    pub fn toJson(self: *const IntelligenceForecastData, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"predicted_multiplier":{d:.4},"confidence_min":{d:.4},
            \\"confidence_max":{d:.4},"time_horizon":{d},
            \\"model_quality":{d:.4},"growth_rate":{d:.8}}
        , .{
            self.predicted_multiplier,
            self.confidence_min,
            self.confidence_max,
            self.time_horizon,
            self.model_quality,
            self.growth_rate,
        });
    }
};

/// Evolution tree node
pub const EvolutionTreeNode = struct {
    node_id: []const u8,
    parent_id: ?[]const u8,
    mutation_type: []const u8,
    timestamp: i64,
    fitness: f64,
    depth: usize,

    /// Serialize to JSON
    pub fn toJson(self: *const EvolutionTreeNode, allocator: Allocator) ![]const u8 {
        const parent_str = if (self.parent_id) |p|
            try std.fmt.allocPrint(allocator, "\"{s}\"", .{p})
        else
            "null";

        return std.fmt.allocPrint(allocator,
            \\{{"node_id":"{s}","parent_id":{s},"mutation_type":"{s}",
            \\"timestamp":{d},"fitness":{d:.4},"depth":{d}}}
        , .{
            self.node_id,
            parent_str,
            self.mutation_type,
            self.timestamp,
            self.fitness,
            self.depth,
        });
    }
};

/// Generate AGENT MU status JSON
pub fn generateAgentMuStatus(allocator: Allocator) ![]const u8 {
    const tracker = try mu_tracker.getGlobalTracker();

    const last_fix_type: ?[]const u8 = if (tracker.fixes.items.len > 0)
        tracker.fixes.items[tracker.fixes.items.len - 1].fix_type
    else
        null;

    const status = AgentMuStatus{
        .total_fixes = tracker.total_fixes,
        .successful_fixes = tracker.successful_fixes,
        .failed_fixes = tracker.failed_fixes,
        .current_mu = tracker.getCurrentMu(),
        .intelligence_multiplier = tracker.getIntelligenceMultiplier(),
        .success_rate = tracker.getSuccessRate(),
        .adaptive_mu = mu_tracker.calculateAdaptiveMu(tracker.getSuccessRate()),
        .uptime_seconds = tracker.getUptimeSeconds(),
        .fixes_per_second = tracker.getFixesPerSecond(),
        .last_fix_type = last_fix_type,
        .version = "8.18.0",
    };

    return status.toJson(allocator);
}

/// Generate intelligence history JSON
pub fn generateIntelligenceHistory(allocator: Allocator, count: usize) ![]const u8 {
    const tracker = try mu_tracker.getGlobalTracker();
    const snapshots = try tracker.getIntelligenceHistory(allocator, count);
    defer allocator.free(snapshots);

    var buffer = std.ArrayList(u8).init(allocator);

    try buffer.appendSlice("[");

    for (snapshots, 0..) |snap, i| {
        if (i > 0) try buffer.append(",");
        try buffer.appendSlice("{\"timestamp\":");
        try buffer.print("{d}", .{snap.timestamp});
        try buffer.appendSlice(",\"intelligence_multiplier\":");
        try buffer.print("{d:.6}", .{snap.intelligence_multiplier});
        try buffer.appendSlice(",\"mu_used\":");
        try buffer.print("{d:.6}", .{snap.current_mu});
        try buffer.appendSlice(",\"fix_type\":\"");

        // Get fix type from this snapshot's index
        const fix_index = tracker.snapshots.items.len - snapshots.len + i;
        if (fix_index > 0 and fix_index <= tracker.fixes.items.len) {
            try buffer.appendSlice(tracker.fixes.items[fix_index - 1].fix_type);
        } else {
            try buffer.appendSlice("UNKNOWN");
        }

        try buffer.appendSlice("\"}");
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate forecast JSON
pub fn generateForecast(allocator: Allocator, horizon_steps: []const usize) ![]const u8 {
    const tracker = try mu_tracker.getGlobalTracker();
    const forecasts = try predictive_intelligence.generateForecasts(
        tracker,
        allocator,
        horizon_steps,
        .{},
    );
    defer allocator.free(forecasts);

    var buffer = std.ArrayList(u8).init(allocator);

    try buffer.appendSlice("[");

    for (forecasts, 0..) |fc, i| {
        if (i > 0) try buffer.append(",");
        try buffer.appendSlice("{\"predicted_multiplier\":");
        try buffer.print("{d:.4}", .{fc.predicted_multiplier});
        try buffer.appendSlice(",\"confidence_min\":");
        try buffer.print("{d:.4}", .{fc.confidence_min});
        try buffer.appendSlice(",\"confidence_max\":");
        try buffer.print("{d:.4}", .{fc.confidence_max});
        try buffer.print(",\"time_horizon\":{d}", .{fc.time_horizon});
        try buffer.print(",\"model_quality\":{d:.4}", .{fc.model_quality});
        try buffer.print(",\"growth_rate\":{d:.8}", .{fc.growth_rate});
        try buffer.append("}");
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate evolution tree JSON
pub fn generateEvolutionTree(allocator: Allocator) ![]const u8 {
    const tracker = try mu_tracker.getGlobalTracker();

    var buffer = std.ArrayList(u8).init(allocator);

    try buffer.appendSlice("[");

    for (tracker.fixes.items, 0..) |fix, i| {
        if (i > 0) try buffer.append(",");

        const fitness = if (fix.success) 0.5 + @as(f64, @floatFromInt(fix.confidence)) * 0.5 else 0.3;
        const depth = @divFloor(i, 5);

        try buffer.appendSlice("{\"node_id\":\"");
        try buffer.print("node_{d}", .{i});
        try buffer.append("\",\"parent_id\":");
        if (i > 0) {
            try buffer.print("\"node_{d}\"", .{i - 1});
        } else {
            try buffer.append("null");
        }
        try buffer.appendSlice(",\"mutation_type\":\"");
        try buffer.appendSlice(fix.fix_type);
        try buffer.print("\",\"timestamp\":{d},\"fitness\":{d:.4},\"depth\":{d}}", .{
            fix.timestamp,
            fitness,
            depth,
        });
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate mock evolution tree for testing
pub fn generateMockEvolutionTree(allocator: Allocator, count: usize) ![]const u8 {
    _ = allocator;

    var buffer = std.ArrayList(u8).init(std.heap.page_allocator);

    try buffer.appendSlice("[");

    const mutations = [_][]const u8{
        "SYNTAX_FIX",
        "TYPE_FIX",
        "META_LEARN",
        "SELF_MOD",
        "PREDICT",
        "COLLAB",
    };

    for (0..count) |i| {
        if (i > 0) try buffer.append(",");

        const mutation = mutations[i % mutations.len];
        const fitness = 0.3 + @as(f64, @floatFromInt(i % 7)) * 0.1;
        const depth = @divFloor(i, 4);

        try buffer.print(
            \\{{"node_id":"node_{d}","parent_id":{s},"mutation_type":"{s}",
            \\"timestamp":{d},"fitness":{d:.4},"depth":{d}}}
        , .{
            i,
            if (i > 0) "\"node_" ++ else "null",
            if (i > 0) try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i - 1}) else "null",
            mutation,
            std.time.timestamp() - (count - i) * 3600,
            fitness,
            depth,
        },
        // fallthrough for null case
        else "",
        );
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate mock forecast for offline dashboard
pub fn generateMockForecast(allocator: Allocator, horizons: []const usize) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);

    try buffer.appendSlice("[");

    const current_mult: f64 = 21.24; // From 100 fixes

    for (horizons, 0..) |h, i| {
        if (i > 0) try buffer.append(",");

        // I(t) = I₀ × e^(μt) where μ = 0.0382
        const predicted = current_mult * std.math.exp(0.0382 * @as(f64, @floatFromInt(h)));
        const margin = predicted * 0.1; // 10% confidence interval

        try buffer.print(
            \\{{"predicted_multiplier":{d:.4},"confidence_min":{d:.4},
            \\"confidence_max":{d:.4},"time_horizon":{d},
            \\"model_quality":0.95,"growth_rate":0.0382}}
        , .{ predicted, predicted - margin, predicted + margin, h });
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Handle API request for AGENT MU status
pub fn handleAgentMuStatus(allocator: Allocator) ![]const u8 {
    return generateAgentMuStatus(allocator);
}

/// Handle API request for intelligence history
pub fn handleIntelligenceHistory(allocator: Allocator, count: usize) ![]const u8 {
    return generateIntelligenceHistory(allocator, count);
}

/// Handle API request for forecast
pub fn handleForecast(allocator: Allocator, horizon_str: []const u8) ![]const u8 {
    // Parse horizon parameter (comma-separated values)
    var horizons = std.ArrayList(usize).init(allocator);

    var iter = std.mem.splitScalar(u8, horizon_str, ',');
    while (iter.next()) |h_str| {
        const h = try std.fmt.parseInt(usize, std.mem.trim(u8, h_str, &std.ascii.whitespace), 10);
        try horizons.append(h);
    }

    if (horizons.items.len == 0) {
        try horizons.append(10);
        try horizons.append(50);
        try horizons.append(100);
    }

    return generateForecast(allocator, horizons.items);
}

/// Handle API request for evolution tree
pub fn handleEvolutionTree(allocator: Allocator) ![]const u8 {
    return generateEvolutionTree(allocator);
}

/// HTTP response helpers
pub fn sendJsonResponse(allocator: Allocator, body: []const u8) ![]const u8 {
    const header = try std.fmt.allocPrint(allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n"
    , .{body.len});

    const response = try std.fmt.allocPrint(allocator, "{s}{s}", .{ header, body });
    allocator.free(header);

    return response;
}

pub fn sendCorsResponse(allocator: Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
    , .{});
}

pub fn sendNotFound(allocator: Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: 26\r\nConnection: close\r\n\r\n{{\"error\":\"Not Found\"}}"
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "AgentMuStatus: JSON serialization" {
    const allocator = std.testing.allocator;

    const status = AgentMuStatus{
        .total_fixes = 100,
        .successful_fixes = 95,
        .failed_fixes = 5,
        .current_mu = 3.8,
        .intelligence_multiplier = 44.7,
        .success_rate = 0.95,
        .adaptive_mu = 0.04,
        .uptime_seconds = 3600,
        .fixes_per_second = 0.028,
        .last_fix_type = "TYPE_FIX",
        .version = "8.18.0",
    };

    const json = try status.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"total_fixes\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\":\"8.18.0\"") != null);
}

test "generateMockForecast: basic" {
    const allocator = std.testing.allocator;

    const horizons = [_]usize{10, 50};
    const json = try generateMockForecast(allocator, &horizons);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "predicted_multiplier") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "confidence_min") != null);
}

test "generateMockEvolutionTree: basic" {
    const allocator = std.testing.allocator;

    const json = try generateMockEvolutionTree(allocator, 5);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "node_0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "mutation_type") != null);
}
