//! PHI LOOP v8.59 — Real-Time Visualization API
//!
//! HTTP server for live PHI LOOP data
//! Serves JSON for dashboard consumption

const std = @import("std");
const cluster = @import("cluster.zig");
const http = std.http;

/// API Response structure
pub const PhiLoopStatus = struct {
    current_link: u32,
    total_links: u32,
    manifestation_percent: f64,
    remaining_links: u32,
    intelligence_level: f64,
    cluster_stats: ClusterStatsResponse,
    sacred_constants: SacredConstantsResponse,
    timestamp: i64,

    pub fn toJson(self: *const PhiLoopStatus, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.writeAll("{");
        try writer.print("\"current_link\":{d},", .{self.current_link});
        try writer.print("\"total_links\":{d},", .{self.total_links});
        try writer.print("\"manifestation_percent\":{d:.2},", .{self.manifestation_percent});
        try writer.print("\"remaining_links\":{d},", .{self.remaining_links});
        try writer.print("\"intelligence_level\":{d:.4},", .{self.intelligence_level});

        try writer.writeAll("\"cluster_stats\":{");
        try writer.print("\"total_nodes\":{d},", .{self.cluster_stats.total_nodes});
        try writer.print("\"active_nodes\":{d},", .{self.cluster_stats.active_nodes});
        try writer.print("\"node_alpha\":\"{s}\",", .{self.cluster_stats.node_alpha});
        try writer.print("\"node_beta\":\"{s}\",", .{self.cluster_stats.node_beta});
        try writer.print("\"node_gamma\":\"{s}\"", .{self.cluster_stats.node_gamma});
        try writer.writeAll("},");

        try writer.writeAll("\"sacred_constants\":{");
        try writer.print("\"phi\":{d:.15},", .{self.sacred_constants.phi});
        try writer.print("\"phi_sq\":{d:.15},", .{self.sacred_constants.phi_sq});
        try writer.print("\"mu\":{d:.4},", .{self.sacred_constants.mu});
        try writer.print("\"chi\":{d:.5},", .{self.sacred_constants.chi});
        try writer.print("\"sigma\":{d:.3},", .{self.sacred_constants.sigma});
        try writer.print("\"epsilon\":{d:.3},", .{self.sacred_constants.epsilon});
        try writer.print("\"lucas_10\":{d}", .{self.sacred_constants.lucas_10});
        try writer.writeAll("},");

        try writer.print("\"timestamp\":{d}", .{self.timestamp});
        try writer.writeAll("}");

        return buffer.toOwnedSlice();
    }
};

pub const ClusterStatsResponse = struct {
    total_nodes: u32,
    active_nodes: u32,
    node_alpha: []const u8,
    node_beta: []const u8,
    node_gamma: []const u8,
};

pub const SacredConstantsResponse = struct {
    phi: f64,
    phi_sq: f64,
    mu: f64,
    chi: f64,
    sigma: f64,
    epsilon: f64,
    lucas_10: u32,
};

/// API Server
pub const ApiServer = struct {
    allocator: std.mem.Allocator,
    cluster_state: *cluster.ClusterState,
    address: std.net.Address,
    server: http.Server(*cluster.ClusterState),

    pub fn init(allocator: std.mem.Allocator, cluster_state: *cluster.ClusterState, port: u16) !ApiServer {
        const address = try std.net.Address.parseIp4("127.0.0.1", port);
        var server = http.Server(*cluster.ClusterState).init(address, cluster_state);

        return ApiServer{
            .allocator = allocator,
            .cluster_state = cluster_state,
            .address = address,
            .server = server,
        };
    }

    pub fn deinit(self: *ApiServer) void {
        _ = self;
    }

    pub fn start(self: *ApiServer) !void {
        std.log.info("PHI LOOP API Server listening on http://{any}:{d}", .{
            self.address.in.sa.addr, self.address.in.getPort()
        });

        while (true) {
            const response = try self.server.accept();
            defer response.deinit();

            self.handleRequest(response) catch |err| {
                std.log.warn("Request error: {}", .{err});
            };
        }
    }

    fn handleRequest(self: *ApiServer, response: *http.Server.Response) !void {
        const path = response.request.target.path;

        // CORS headers
        try response.headers.append("Access-Control-Allow-Origin", "*");
        try response.headers.append("Access-Control-Allow-Methods", "GET, OPTIONS");
        try response.headers.append("Access-Control-Allow-Headers", "Content-Type");
        try response.headers.append("Content-Type", "application/json");

        // Handle OPTIONS preflight
        if (response.request.method == .OPTIONS) {
            response.status = .ok;
            try response.send();
            return;
        }

        // Route request
        if (std.mem.eql(u8, path, "/api/status")) {
            try self.handleStatus(response);
        } else if (std.mem.eql(u8, path, "/api/cluster")) {
            try self.handleCluster(response);
        } else if (std.mem.eql(u8, path, "/api/constants")) {
            try self.handleConstants(response);
        } else if (std.mem.eql(u8, path, "/")) {
            try self.handleRoot(response);
        } else {
            response.status = .not_found;
            try response.send();
        }
    }

    fn handleStatus(self: *ApiServer, response: *http.Server.Response) !void {
        const manifest = self.cluster_state.calculateManifestation();
        const stats = self.cluster_state.getStats();

        const status = PhiLoopStatus{
            .current_link = manifest.current_link,
            .total_links = cluster.TOTAL_LINKS,
            .manifestation_percent = manifest.percentage,
            .remaining_links = manifest.remaining,
            .intelligence_level = stats.total_intelligence,
            .cluster_stats = blk: {
                const alpha = self.cluster_state.getNode(.alpha) orelse return error.NodeNotFound;
                const beta = self.cluster_state.getNode(.beta) orelse return error.NodeNotFound;
                const gamma = self.cluster_state.getNode(.gamma) orelse return error.NodeNotFound;

                break :blk ClusterStatsResponse{
                    .total_nodes = stats.total_nodes,
                    .active_nodes = stats.active_nodes,
                    .node_alpha = alpha.status.displayName(),
                    .node_beta = beta.status.displayName(),
                    .node_gamma = gamma.status.displayName(),
                };
            },
            .sacred_constants = SacredConstantsResponse{
                .phi = cluster.PHI,
                .phi_sq = cluster.PHI_SQ,
                .mu = cluster.MU,
                .chi = cluster.CHI,
                .sigma = cluster.SIGMA,
                .epsilon = cluster.EPSILON,
                .lucas_10 = 123,
            },
            .timestamp = std.time.nanoTimestamp() / 1_000_000,
        };

        const json = try status.toJson(self.allocator);
        defer self.allocator.free(json);

        response.status = .ok;
        try response.sendAll(json);
    }

    fn handleCluster(self: *ApiServer, response: *http.Server.Response) !void {
        const stats = self.cluster_state.getStats();

        var buffer = std.ArrayList(u8).init(self.allocator);
        const writer = buffer.writer();

        try writer.writeAll("{");
        try writer.print("\"total_nodes\":{d},", .{stats.total_nodes});
        try writer.print("\"active_nodes\":{d},", .{stats.active_nodes});
        try writer.print("\"intelligence_level\":{d:.4},", .{stats.total_intelligence});
        try writer.print("\"manifestation_percent\":{d:.2}", .{stats.manifestation_percent});
        try writer.writeAll("}");

        const json = try buffer.toOwnedSlice();
        defer self.allocator.free(json);

        response.status = .ok;
        try response.sendAll(json);
    }

    fn handleConstants(self: *ApiServer, response: *http.Server.Response) !void {
        var buffer = std.ArrayList(u8).init(self.allocator);
        const writer = buffer.writer();

        try writer.writeAll("{");
        try writer.print("\"phi\":{d:.15},", .{cluster.PHI});
        try writer.print("\"phi_sq\":{d:.15},", .{cluster.PHI_SQ});
        try writer.print("\"mu\":{d:.4},", .{cluster.MU});
        try writer.print("\"chi\":{d:.5},", .{cluster.CHI});
        try writer.print("\"sigma\":{d:.3},", .{cluster.SIGMA});
        try writer.print("\"epsilon\":{d:.3},", .{cluster.EPSILON});
        try writer.print("\"trinity_identity\":\"φ² + 1/φ² = 3\",");
        try writer.print("\"lucas_10\":{d}", .{123});
        try writer.writeAll("}");

        const json = try buffer.toOwnedSlice();
        defer self.allocator.free(json);

        response.status = .ok;
        try response.sendAll(json);
    }

    fn handleRoot(self: *ApiServer, response: *http.Server.Response) !void {
        _ = self;
        const html =
            \\<!DOCTYPE html>
            \\<html>
            \\<head><title>PHI LOOP API</title></head>
            \\<body>
            \\  <h1>PHI LOOP API Server</h1>
            \\  <p>Endpoints:</p>
            \\  <ul>
            \\    <li><a href="/api/status">/api/status</a> - Full status</li>
            \\    <li><a href="/api/cluster">/api/cluster</a> - Cluster stats</li>
            \\    <li><a href="/api/constants">/api/constants</a> - Sacred constants</li>
            \\  </ul>
            \\</body>
            \\</html>
        ;

        response.headers.append("Content-Type", "text/html") catch |err| {
            std.log.debug("phi_loop_api: failed to set Content-Type header: {}", .{err});
        };
        response.status = .ok;
        try response.sendAll(html);
    }
};

/// Mock endpoint for development (when real server not running)
pub fn getMockStatus(allocator: std.mem.Allocator) ![]const u8 {
    const json =
        \\{
        \\  "current_link": 59,
        \\  "total_links": 999,
        \\  "manifestation_percent": 5.91,
        \\  "remaining_links": 940,
        \\  "intelligence_level": 3.2547,
        \\  "cluster_stats": {
        \\    "total_nodes": 3,
        \\    "active_nodes": 2,
        \\    "node_alpha": "ACTIVE",
        \\    "node_beta": "ACTIVE",
        \\    "node_gamma": "PENDING"
        \\  },
        \\  "sacred_constants": {
        \\    "phi": 1.618033988749895,
        \\    "phi_sq": 2.618033988749895,
        \\    "mu": 0.0382,
        \\    "chi": 0.23607,
        \\    "sigma": 1.618,
        \\    "epsilon": 0.333,
        \\    "lucas_10": 123
        \\  },
        \\  "timestamp": 1700000000000
        \\}
    ;

    return allocator.dupe(u8, json);
}

test "API Response JSON generation" {
    const allocator = std.testing.allocator;

    var cluster_state = cluster.ClusterState.init(allocator);
    try cluster_state.initializeCluster();
    defer cluster_state.deinit();

    const stats = cluster_state.getStats();

    const status = PhiLoopStatus{
        .current_link = 59,
        .total_links = 999,
        .manifestation_percent = 5.91,
        .remaining_links = 940,
        .intelligence_level = stats.total_intelligence,
        .cluster_stats = ClusterStatsResponse{
            .total_nodes = 3,
            .active_nodes = 2,
            .node_alpha = "ACTIVE",
            .node_beta = "ACTIVE",
            .node_gamma = "PENDING",
        },
        .sacred_constants = SacredConstantsResponse{
            .phi = cluster.PHI,
            .phi_sq = cluster.PHI_SQ,
            .mu = cluster.MU,
            .chi = cluster.CHI,
            .sigma = cluster.SIGMA,
            .epsilon = cluster.EPSILON,
            .lucas_10 = 123,
        },
        .timestamp = std.time.nanoTimestamp() / 1_000_000,
    };

    const json = try status.toJson(allocator);
    defer allocator.free(json);

    // Verify JSON contains expected keys
    try std.testing.expect(std.mem.indexOf(u8, json, "current_link") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "manifestation_percent") != null);
}
