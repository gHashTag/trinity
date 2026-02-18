// ═══════════════════════════════════════════════════════════════════════════════
// REGION-AWARE ROUTER — Topology + Reputation + Latency Routing
// Trinity Storage Network v2.1
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const region_topology_mod = @import("region_topology.zig");
const peer_latency_mod = @import("peer_latency.zig");
const node_reputation_mod = @import("node_reputation.zig");

pub const RouterConfig = struct {
    /// Weight for latency score in routing decision [0, 1]
    latency_weight: f64 = 0.4,
    /// Weight for reputation score in routing decision [0, 1]
    reputation_weight: f64 = 0.4,
    /// Weight for region locality in routing decision [0, 1]
    locality_weight: f64 = 0.2,
    /// Maximum candidates to evaluate per routing decision
    max_candidates: u32 = 20,
    /// Minimum reputation score to be routable
    min_reputation: f64 = 0.3,
};

pub const RouteCandidate = struct {
    node_id: [32]u8,
    region: region_topology_mod.Region,
    latency_score: f64, // 0=slow, 1=fast (inverted latency)
    reputation_score: f64, // 0=bad, 1=good
    locality_score: f64, // 0=far, 0.5=near, 1=local
    composite_score: f64, // Weighted sum
};

pub const RouteDecision = struct {
    selected_node: [32]u8,
    selected_region: region_topology_mod.Region,
    composite_score: f64,
    candidates_evaluated: u32,
    is_local: bool,
};

pub const RouterStats = struct {
    total_route_decisions: u64,
    local_routes: u64,
    near_routes: u64,
    far_routes: u64,
    route_failures: u64,
    avg_composite_score: f64,
};

pub const RegionRouter = struct {
    allocator: std.mem.Allocator,
    config: RouterConfig,
    stats: RouterStats,

    pub fn init(allocator: std.mem.Allocator) RegionRouter {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: RouterConfig) RegionRouter {
        return .{
            .allocator = allocator,
            .config = config,
            .stats = std.mem.zeroes(RouterStats),
        };
    }

    pub fn deinit(self: *RegionRouter) void {
        _ = self;
    }

    /// Route a request to the best node given topology, latency, and reputation
    pub fn routeRequest(
        self: *RegionRouter,
        requester_region: region_topology_mod.Region,
        topology: *region_topology_mod.RegionTopology,
        latency: *peer_latency_mod.PeerLatencyTracker,
        reputation: *node_reputation_mod.NodeReputationSystem,
    ) ?RouteDecision {
        var best: ?RouteCandidate = null;
        var evaluated: u32 = 0;

        // Evaluate nodes from all regions, prioritizing local
        const req_idx = @intFromEnum(requester_region);
        if (req_idx >= 9) {
            self.stats.route_failures += 1;
            return null;
        }

        // Order regions by latency from requester
        var region_order: [9]usize = undefined;
        var region_latencies: [9]u32 = undefined;
        for (0..9) |r| {
            region_order[r] = r;
            region_latencies[r] = region_topology_mod.INTER_REGION_LATENCY_MS[req_idx][r];
        }
        // Sort by latency
        for (0..9) |i| {
            var min_j = i;
            for (i + 1..9) |j| {
                if (region_latencies[region_order[j]] < region_latencies[region_order[min_j]]) {
                    min_j = j;
                }
            }
            if (min_j != i) {
                const tmp = region_order[i];
                region_order[i] = region_order[min_j];
                region_order[min_j] = tmp;
            }
        }

        for (region_order) |r_idx| {
            if (evaluated >= self.config.max_candidates) break;
            const region: region_topology_mod.Region = @enumFromInt(@as(u8, @intCast(r_idx)));
            const nodes_in_region = topology.getNodesInRegion(region);

            for (nodes_in_region) |node_id| {
                if (evaluated >= self.config.max_candidates) break;

                // Check minimum reputation
                const rep_score = reputation.getScore(node_id);
                if (rep_score.score < self.config.min_reputation) continue;

                // Compute latency score (inverse of EMA latency, normalized)
                const lat_score_raw = latency.getScore(node_id);
                const latency_score = if (lat_score_raw.ema_latency_ns > 0)
                    1.0 / (1.0 + lat_score_raw.ema_latency_ns / 100_000_000.0)
                else
                    0.5; // Unknown latency gets neutral score

                // Compute locality score
                const zone = region_topology_mod.RegionTopology.getLatencyZone(requester_region, region);
                const locality_score: f64 = switch (zone) {
                    0 => 1.0, // local
                    1 => 0.5, // near
                    else => 0.1, // far
                };

                // Weighted composite
                const composite = latency_score * self.config.latency_weight +
                    rep_score.score * self.config.reputation_weight +
                    locality_score * self.config.locality_weight;

                const candidate = RouteCandidate{
                    .node_id = node_id,
                    .region = region,
                    .latency_score = latency_score,
                    .reputation_score = rep_score.score,
                    .locality_score = locality_score,
                    .composite_score = composite,
                };

                if (best == null or composite > best.?.composite_score) {
                    best = candidate;
                }

                evaluated += 1;
            }
        }

        if (best) |b| {
            self.stats.total_route_decisions += 1;
            const zone = region_topology_mod.RegionTopology.getLatencyZone(requester_region, b.region);
            switch (zone) {
                0 => self.stats.local_routes += 1,
                1 => self.stats.near_routes += 1,
                else => self.stats.far_routes += 1,
            }
            self.updateAvgScore(b.composite_score);

            return .{
                .selected_node = b.node_id,
                .selected_region = b.region,
                .composite_score = b.composite_score,
                .candidates_evaluated = evaluated,
                .is_local = zone == 0,
            };
        }

        self.stats.route_failures += 1;
        return null;
    }

    /// Route for cross-shard transaction: select best node per region for multi-region placement
    pub fn routeForTransaction(
        self: *RegionRouter,
        requester_region: region_topology_mod.Region,
        target_regions: [9]bool,
        topology: *region_topology_mod.RegionTopology,
        latency: *peer_latency_mod.PeerLatencyTracker,
        reputation: *node_reputation_mod.NodeReputationSystem,
    ) ![]RouteDecision {
        var decisions = std.ArrayList(RouteDecision).empty;

        for (0..9) |r| {
            if (!target_regions[r]) continue;
            const region: region_topology_mod.Region = @enumFromInt(@as(u8, @intCast(r)));
            const nodes = topology.getNodesInRegion(region);

            var best_node: ?[32]u8 = null;
            var best_score: f64 = 0;

            for (nodes) |node_id| {
                const rep = reputation.getScore(node_id);
                if (rep.score < self.config.min_reputation) continue;

                const lat = latency.getScore(node_id);
                const lat_s = if (lat.ema_latency_ns > 0)
                    1.0 / (1.0 + lat.ema_latency_ns / 100_000_000.0)
                else
                    0.5;

                const zone = region_topology_mod.RegionTopology.getLatencyZone(requester_region, region);
                const loc_s: f64 = switch (zone) {
                    0 => 1.0,
                    1 => 0.5,
                    else => 0.1,
                };

                const score = lat_s * self.config.latency_weight +
                    rep.score * self.config.reputation_weight +
                    loc_s * self.config.locality_weight;

                if (score > best_score) {
                    best_score = score;
                    best_node = node_id;
                }
            }

            if (best_node) |node| {
                const zone = region_topology_mod.RegionTopology.getLatencyZone(requester_region, region);
                try decisions.append(self.allocator, .{
                    .selected_node = node,
                    .selected_region = region,
                    .composite_score = best_score,
                    .candidates_evaluated = @intCast(nodes.len),
                    .is_local = zone == 0,
                });
                self.stats.total_route_decisions += 1;
                switch (zone) {
                    0 => self.stats.local_routes += 1,
                    1 => self.stats.near_routes += 1,
                    else => self.stats.far_routes += 1,
                }
            }
        }

        return decisions.toOwnedSlice(self.allocator);
    }

    pub fn getStats(self: *RegionRouter) RouterStats {
        return self.stats;
    }

    fn updateAvgScore(self: *RegionRouter, score: f64) void {
        const n = self.stats.total_route_decisions;
        if (n == 1) {
            self.stats.avg_composite_score = score;
        } else {
            const prev = self.stats.avg_composite_score;
            self.stats.avg_composite_score = prev + (score - prev) / @as(f64, @floatFromInt(n));
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "route to local node" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var local_node: [32]u8 = undefined;
    @memset(&local_node, 1);
    var remote_node: [32]u8 = undefined;
    @memset(&remote_node, 2);

    try topo.registerNode(local_node, .us_east);
    try topo.registerNode(remote_node, .asia_east);

    latency.recordLatency(local_node, 5_000_000); // 5ms
    latency.recordLatency(remote_node, 200_000_000); // 200ms

    reputation.recordPosResult(local_node, true);
    reputation.recordUptime(local_node, 3600, 3600);
    reputation.recordPosResult(remote_node, true);
    reputation.recordUptime(remote_node, 3600, 3600);

    var router = RegionRouter.init(allocator);
    defer router.deinit();

    const decision = router.routeRequest(.us_east, &topo, &latency, &reputation);
    try std.testing.expect(decision != null);
    try std.testing.expect(decision.?.is_local);
    try std.testing.expect(std.mem.eql(u8, &decision.?.selected_node, &local_node));
    try std.testing.expectEqual(@as(u64, 1), router.getStats().local_routes);
}

test "route skips low reputation nodes" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var bad_node: [32]u8 = undefined;
    @memset(&bad_node, 1);
    var good_node: [32]u8 = undefined;
    @memset(&good_node, 2);

    try topo.registerNode(bad_node, .us_east);
    try topo.registerNode(good_node, .us_east);

    latency.recordLatency(bad_node, 1_000_000);
    latency.recordLatency(good_node, 10_000_000);

    // bad_node: 0 PoS passed, low reputation
    reputation.recordPosResult(bad_node, false);
    reputation.recordUptime(bad_node, 100, 3600);
    // good_node: high reputation
    reputation.recordPosResult(good_node, true);
    reputation.recordUptime(good_node, 3600, 3600);

    var router = RegionRouter.initWithConfig(allocator, .{
        .min_reputation = 0.3,
    });
    defer router.deinit();

    const decision = router.routeRequest(.us_east, &topo, &latency, &reputation);
    try std.testing.expect(decision != null);
    try std.testing.expect(std.mem.eql(u8, &decision.?.selected_node, &good_node));
}

test "route for cross-shard transaction selects per-region" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    // 3 nodes in 3 different regions
    var n1: [32]u8 = undefined;
    @memset(&n1, 1);
    var n2: [32]u8 = undefined;
    @memset(&n2, 2);
    var n3: [32]u8 = undefined;
    @memset(&n3, 3);

    try topo.registerNode(n1, .us_east);
    try topo.registerNode(n2, .eu_west);
    try topo.registerNode(n3, .asia_east);

    for ([_][32]u8{ n1, n2, n3 }) |node| {
        latency.recordLatency(node, 10_000_000);
        reputation.recordPosResult(node, true);
        reputation.recordUptime(node, 3600, 3600);
    }

    var router = RegionRouter.init(allocator);
    defer router.deinit();

    var target_regions = [_]bool{false} ** 9;
    target_regions[0] = true; // us_east
    target_regions[2] = true; // eu_west
    target_regions[4] = true; // asia_east

    const decisions = try router.routeForTransaction(.us_east, target_regions, &topo, &latency, &reputation);
    defer allocator.free(decisions);

    try std.testing.expectEqual(@as(usize, 3), decisions.len);
    try std.testing.expectEqual(@as(u64, 3), router.getStats().total_route_decisions);
}

test "route fails with no nodes" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var router = RegionRouter.init(allocator);
    defer router.deinit();

    const decision = router.routeRequest(.us_east, &topo, &latency, &reputation);
    try std.testing.expect(decision == null);
    try std.testing.expectEqual(@as(u64, 1), router.getStats().route_failures);
}

test "composite score favors local + fast + reputable" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var fast_local: [32]u8 = undefined;
    @memset(&fast_local, 1);
    var slow_remote: [32]u8 = undefined;
    @memset(&slow_remote, 2);

    try topo.registerNode(fast_local, .us_east);
    try topo.registerNode(slow_remote, .africa);

    latency.recordLatency(fast_local, 2_000_000); // 2ms
    latency.recordLatency(slow_remote, 300_000_000); // 300ms

    reputation.recordPosResult(fast_local, true);
    reputation.recordUptime(fast_local, 3600, 3600);
    reputation.recordBandwidth(fast_local, 1024 * 1024);
    reputation.recordPosResult(slow_remote, true);
    reputation.recordUptime(slow_remote, 1800, 3600);

    var router = RegionRouter.init(allocator);
    defer router.deinit();

    const decision = router.routeRequest(.us_east, &topo, &latency, &reputation);
    try std.testing.expect(decision != null);
    try std.testing.expect(decision.?.composite_score > 0.5);
    try std.testing.expect(decision.?.is_local);
}

test "router stats accumulate" {
    const allocator = std.testing.allocator;

    var topo = region_topology_mod.RegionTopology.init(allocator);
    defer topo.deinit();
    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();
    var reputation = node_reputation_mod.NodeReputationSystem.init(allocator);
    defer reputation.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);
    try topo.registerNode(node, .eu_west);
    latency.recordLatency(node, 10_000_000);
    reputation.recordPosResult(node, true);
    reputation.recordUptime(node, 3600, 3600);

    var router = RegionRouter.init(allocator);
    defer router.deinit();

    _ = router.routeRequest(.eu_west, &topo, &latency, &reputation);
    _ = router.routeRequest(.us_east, &topo, &latency, &reputation);
    _ = router.routeRequest(.asia_east, &topo, &latency, &reputation);

    const stats = router.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total_route_decisions);
    try std.testing.expect(stats.local_routes >= 1);
    try std.testing.expect(stats.avg_composite_score > 0);
}
