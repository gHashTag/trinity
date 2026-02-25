//! AGENT MU HTTP API v8.19
//!
//! HTTP endpoints for AGENT MU dashboard integration:
//! - GET /api/agent-mu/status - Current intelligence metrics
//! - GET /api/agent-mu/history - Intelligence history (curve data)
//! - GET /api/agent-mu/forecast - Predictive intelligence forecasting
//! - GET /api/agent-mu/evolution-tree - Evolution tree data
//! - GET /api/agent-mu/sacred-math - Sacred constants (μ, φ, L(10))
//!
//! Returns JSON for dashboard consumption with mock fallbacks.

const std = @import("std");
const ArrayList = std.array_list.Managed;

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

/// Generate AGENT MU status JSON (mock data)
pub fn generateAgentMuStatus(allocator: Allocator) ![]const u8 {
    const uptime = std.time.timestamp();

    const status = AgentMuStatus{
        .total_fixes = 100,
        .successful_fixes = 95,
        .failed_fixes = 5,
        .current_mu = 3.82, // 100 fixes × 0.0382
        .intelligence_multiplier = 21.24,
        .success_rate = 0.95,
        .adaptive_mu = 0.039,
        .uptime_seconds = uptime,
        .fixes_per_second = 0.028,
        .last_fix_type = "TYPE_FIX",
        .version = "8.19.0",
    };

    return status.toJson(allocator);
}

/// Generate intelligence history JSON (mock data)
pub fn generateIntelligenceHistory(allocator: Allocator, count: usize) ![]const u8 {
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const now = std.time.timestamp();
    var current_mu: f64 = 0.0382;

    for (0..@min(count, 100)) |i| {
        if (i > 0) try buffer.appendSlice(",");

        current_mu += 0.0382;
        const multiplier = std.math.exp(current_mu);

        try buffer.print(
            \\{{"timestamp":{d},"intelligence_multiplier":{d:.6},
            \\"mu_used":{d:.6},"fix_type":"TYPE_FIX"}}
        , .{
            now - @as(i64, @intCast((100 - i) * 3600)),
            multiplier,
            current_mu,
        });
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate forecast JSON (mock data)
pub fn generateForecast(allocator: Allocator, horizon_steps: []const usize) ![]const u8 {
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try buffer.appendSlice("[");

    const current_mult: f64 = 21.24; // From 100 fixes

    for (horizon_steps, 0..) |h, i| {
        if (i > 0) try buffer.appendSlice(",");

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

/// Generate evolution tree JSON (mock data)
pub fn generateEvolutionTree(allocator: Allocator) ![]const u8 {
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try buffer.appendSlice("[");

    const mutations = [_][]const u8{
        "SYNTAX_FIX",
        "TYPE_FIX",
        "META_LEARN",
        "SELF_MOD",
        "PREDICT",
        "COLLAB",
    };

    const now = std.time.timestamp();

    for (0..50) |i| {
        if (i > 0) try buffer.appendSlice(",");

        const mutation = mutations[i % mutations.len];
        const fitness = 0.3 + @as(f64, @floatFromInt(i % 7)) * 0.1;
        const depth = @divFloor(i, 4);

        // Build parent_id string
        const parent_str = if (i > 0)
            try std.fmt.allocPrint(allocator, "\"node_{d}\"", .{i - 1})
        else
            "null";

        try buffer.print(
            \\{{"node_id":"node_{d}","parent_id":{s},"mutation_type":"{s}",
            \\"timestamp":{d},"fitness":{d:.4},"depth":{d}}}
        , .{
            i,
            parent_str,
            mutation,
            now - @as(i64, @intCast((50 - i) * 3600)),
            fitness,
            depth,
        });

        if (i > 0) allocator.free(parent_str);
    }

    try buffer.appendSlice("]");

    return buffer.toOwnedSlice();
}

/// Generate sacred math JSON (mock data)
pub fn generateSacredMath(allocator: Allocator) ![]const u8 {
    const now = std.time.timestamp();
    // Sacred constants
    const phi: f64 = 1.6180339887498948482; // Golden ratio
    const mu: f64 = 0.0382; // 1/φ²/10
    const lucas_10: f64 = 123.0; // 10th Lucas number
    const trinity: f64 = 3.0; // φ² + 1/φ²

    return std.fmt.allocPrint(allocator,
        \\{{"mu":{d:.6},"phi":{d:.15},"lucas_10":{d:.0},"trinity_score":{d:.6},"current_intelligence":21.24,"uptime_seconds":3600,"last_update":{d},"version":"8.19.0"}}
    , .{ mu, phi, lucas_10, trinity, now });
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
    var horizons = ArrayList(usize).init(allocator);
    defer horizons.deinit();

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

/// Handle API request for sacred math
pub fn handleSacredMath(allocator: Allocator) ![]const u8 {
    return generateSacredMath(allocator);
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
        .version = "8.19.0",
    };

    const json = try status.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"total_fixes\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\":\"8.19.0\"") != null);
}

test "generateAgentMuStatus: basic" {
    const allocator = std.testing.allocator;

    const json = try generateAgentMuStatus(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "total_fixes") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "intelligence_multiplier") != null);
}

test "generateForecast: basic" {
    const allocator = std.testing.allocator;

    const horizons = [_]usize{10, 50};
    const json = try generateForecast(allocator, &horizons);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "predicted_multiplier") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "confidence_min") != null);
}

test "generateEvolutionTree: basic" {
    const allocator = std.testing.allocator;

    const json = try generateEvolutionTree(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "node_0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "mutation_type") != null);
}

test "generateSacredMath: basic" {
    const allocator = std.testing.allocator;

    const json = try generateSacredMath(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "mu") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "phi") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "lucas_10") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "trinity_score") != null);
}
