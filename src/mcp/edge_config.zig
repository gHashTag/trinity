//! TRINITY MCP Server v2.2 — Global Edge Network Configuration
//!
//! Anycast routing and health checks for 6-region global deployment.
//! Target latency: <30ms worldwide.
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

/// Edge node information
pub const EdgeNode = struct {
    region: []const u8,
    location: []const u8,
    iata: []const u8, // Airport code
    latitude: f64,
    longitude: f64,
    /// Target latency in ms
    target_latency_ms: u32,
    /// Actual latency (measured)
    actual_latency_ms: ?u32 = null,
    /// Node health status
    health: NodeHealth = .healthy,

    pub const NodeHealth = enum {
        healthy,
        degraded,
        down,
    };

    /// Calculate distance to another node (Haversine formula)
    pub fn distanceTo(self: EdgeNode, other: EdgeNode) f64 {
        const R = 6371.0; // Earth radius in km
        const dLat = toRadians(other.latitude - self.latitude);
        const dLon = toRadians(other.longitude - self.longitude);

        const a = std.math.sin(dLat / 2) * std.math.sin(dLat / 2) +
            std.math.cos(toRadians(self.latitude)) * std.math.cos(toRadians(other.latitude)) *
                std.math.sin(dLon / 2) * std.math.sin(dLon / 2);

        const c = 2 * std.math.asin(std.math.sqrt(a));
        return R * c;
    }

    /// Estimate latency based on distance (speed of light in fiber = ~200km/ms)
    pub fn estimatedLatency(self: EdgeNode, other: EdgeNode) u32 {
        const distance_km = self.distanceTo(other);
        // Add 50% overhead for routing, processing, etc.
        return @as(u32, @intFromFloat((distance_km / 200.0) * 1.5));
    }

    fn toRadians(degrees: f64) f64 {
        return degrees * std.math.pi / 180.0;
    }
};

/// Global edge network topology
pub const EdgeTopology = struct {
    nodes: []const EdgeNode,
    anycast_enabled: bool = true,
    health_check_interval_sec: u32 = 15,
    failover_timeout_sec: u32 = 30,

    /// Get closest healthy node for a client location
    pub fn getClosestNode(self: *const EdgeTopology, client_lat: f64, client_lon: f64) ?*const EdgeNode {
        var closest: ?*const EdgeNode = null;
        var min_distance: f64 = std.math.inf(f64);

        for (self.nodes) |*node| {
            if (node.health == .down) continue;

            const distance = std.math.sqrt(std.math.pow(client_lat - node.latitude, 2) +
                std.math.pow(client_lon - node.longitude, 2));

            if (distance < min_distance) {
                min_distance = distance;
                closest = node;
            }
        }

        return closest;
    }
};

/// Trinity Global Edge Network (6 regions)
pub const TRINITY_EDGE_NETWORK = [_]EdgeNode{
    .{
        .region = "ams",
        .location = "Amsterdam, Netherlands",
        .iata = "AMS",
        .latitude = 52.3100,
        .longitude = 4.7683,
        .target_latency_ms = 20, // Europe
    },
    .{
        .region = "lax",
        .location = "Los Angeles, USA",
        .iata = "LAX",
        .latitude = 33.9425,
        .longitude = -118.4081,
        .target_latency_ms = 25, // US West Coast
    },
    .{
        .region = "nrt",
        .location = "Tokyo, Japan",
        .iata = "NRT",
        .latitude = 35.7720,
        .longitude = 140.3929,
        .target_latency_ms = 30, // East Asia
    },
    .{
        .region = "sin",
        .location = "Singapore",
        .iata = "SIN",
        .latitude = 1.3644,
        .longitude = 103.9915,
        .target_latency_ms = 15, // Southeast Asia (primary)
    },
    .{
        .region = "fra",
        .location = "Frankfurt, Germany",
        .iata = "FRA",
        .latitude = 50.0379,
        .longitude = 8.5622,
        .target_latency_ms = 20, // Central Europe
    },
    .{
        .region = "syd",
        .location = "Sydney, Australia",
        .iata = "SYD",
        .latitude = -33.9399,
        .longitude = 151.1753,
        .target_latency_ms = 35, // Oceania
    },
};

/// Get edge topology
pub fn getEdgeTopology() EdgeTopology {
    return .{
        .nodes = &TRINITY_EDGE_NETWORK,
        .anycast_enabled = true,
        .health_check_interval_sec = 15,
        .failover_timeout_sec = 30,
    };
}

/// Health check result
pub const HealthCheckResult = struct {
    node: *const EdgeNode,
    healthy: bool,
    latency_ms: u32,
    timestamp: i64,
    error_msg: ?[]const u8 = null,
};

/// Perform health check on a node
pub fn healthCheck(node: *const EdgeNode, allocator: std.mem.Allocator) !HealthCheckResult {
    _ = allocator;
    _ = node;

    // TODO: Implement actual HTTP health check
    // For now, return simulated result
    return .{
        .node = node,
        .healthy = true,
        .latency_ms = node.target_latency_ms + @as(u32, @intFromFloat(@mod(@as(f64, @floatFromInt(std.time.nanoTimestamp())), 10))),
        .timestamp = std.time.nanoTimestamp(),
    };
}

/// Format global status as ASCII map
pub fn formatGlobalMap(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);

    try output.appendSlice(
        \\═══════════════════════════════════════════════════════════════
        \\  TRINITY MCP v2.2 — Global Edge Network Status
        \\  φ² + 1/φ² = 3 = TRINITY
        \\═══════════════════════════════════════════════════════════════
        \\
        \\         ┌─────────────────────────────────────┐
        \\         │         TRINITY GLOBAL EDGE          │
        \\         │       Anycast: ENABLED              │
        \\         └─────────────────────────────────────┘
        \\
        \\                    [SYD] 35ms
        \\                     │
        \\                     │
        \\              [NRT] 30ms  [SIN] 15ms ◄── PRIMARY
        \\                    │         │
        \\                    │         │
        \\              [LAX] 25ms      │
        \\                    │         │
        \\                    │         │
        \\              [FRA] 20ms [AMS] 20ms
        \\                    │
        \\                    │
        \\              (target: <30ms worldwide)
        \\
    );

    try output.appendSlice("Region Status:\n");
    try output.appendSlice("─────────────────────────────────────────────────────────────\n");

    for (TRINITY_EDGE_NETWORK) |node| {
        const status = switch (node.health) {
            .healthy => "✓ HEALTHY",
            .degraded => "⚠ DEGRADED",
            .down => "✗ DOWN",
        };

        try output.print("{s:3s} ({s:20s}) {s:12s} {s:3d}ms target\n", .{
            node.region,
            node.location,
            status,
            node.target_latency_ms,
        });
    }

    try output.appendSlice(
        \\
        \\═══════════════════════════════════════════════════════════════
        \\  Anycast IP: Auto-assigned by Fly.io
        \\  Primary Region: SIN (Singapore) — Asia Pacific hub
        \\  Failover: Automatic (30s timeout)
        \\═══════════════════════════════════════════════════════════════
        \\
    );

    return output.toOwnedSlice();
}

/// Latency matrix (ms between regions)
pub fn getLatencyMatrix(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);

    try output.appendSlice("Latency Matrix (estimated milliseconds):\n");
    try output.appendSlice("        AMS   FRA   LAX   NRT   SIN   SYD\n");
    try output.appendSlice("       ─────────────────────────────────────\n");

    for (TRINITY_EDGE_NETWORK, 0..) |from, i| {
        try output.print("{s:3s}   ", .{from.region});

        for (TRINITY_EDGE_NETWORK) |to| {
            if (from.region[0] == to.region[0]) {
                try output.appendSlice("  —   ");
            } else {
                const latency = from.estimatedLatency(to);
                try output.print("{d:3d}ms ", .{latency});
            }
        }

        try output.appendSlice("\n");
    }

    return output.toOwnedSlice();
}
