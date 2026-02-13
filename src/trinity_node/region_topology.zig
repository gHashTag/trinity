// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-REGION TOPOLOGY — Geo-Aware Shard Placement with Latency Zones
// Trinity Storage Network v2.0
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const peer_latency_mod = @import("peer_latency.zig");

/// Geographic region identifiers
pub const Region = enum(u8) {
    us_east = 0,
    us_west = 1,
    eu_west = 2,
    eu_east = 3,
    asia_east = 4,
    asia_south = 5,
    oceania = 6,
    south_america = 7,
    africa = 8,
    unknown = 255,

    pub fn toString(self: Region) []const u8 {
        return switch (self) {
            .us_east => "us-east",
            .us_west => "us-west",
            .eu_west => "eu-west",
            .eu_east => "eu-east",
            .asia_east => "asia-east",
            .asia_south => "asia-south",
            .oceania => "oceania",
            .south_america => "south-america",
            .africa => "africa",
            .unknown => "unknown",
        };
    }
};

/// Cross-region latency matrix (milliseconds)
/// Approximate real-world latency between regions
pub const INTER_REGION_LATENCY_MS: [9][9]u32 = .{
    // us_e  us_w  eu_w  eu_e  as_e  as_s  oce   sa    af
    .{ 0, 60, 80, 100, 180, 200, 220, 120, 160 }, // us_east
    .{ 60, 0, 140, 160, 120, 180, 140, 160, 200 }, // us_west
    .{ 80, 140, 0, 30, 200, 140, 260, 180, 100 }, // eu_west
    .{ 100, 160, 30, 0, 160, 120, 240, 200, 80 }, // eu_east
    .{ 180, 120, 200, 160, 0, 80, 100, 240, 220 }, // asia_east
    .{ 200, 180, 140, 120, 80, 0, 140, 220, 140 }, // asia_south
    .{ 220, 140, 260, 240, 100, 140, 0, 280, 260 }, // oceania
    .{ 120, 160, 180, 200, 240, 220, 280, 0, 200 }, // south_america
    .{ 160, 200, 100, 80, 220, 140, 260, 200, 0 }, // africa
};

pub const TopologyConfig = struct {
    /// Minimum regions for shard placement (redundancy)
    min_regions_per_shard: u32 = 2,
    /// Maximum replicas per region (avoid concentration)
    max_replicas_per_region: u32 = 3,
    /// Prefer nodes within this latency (nanoseconds) for reads
    local_read_threshold_ns: u64 = 50_000_000, // 50ms
    /// Maximum acceptable cross-region latency for writes (ms)
    max_write_latency_ms: u32 = 300,
};

pub const NodeRegionEntry = struct {
    node_id: [32]u8,
    region: Region,
    latency_zone: u8, // 0=local, 1=near, 2=far
};

pub const RegionStats = struct {
    node_count: u32,
    shard_count: u32,
};

pub const PlacementDecision = struct {
    target_regions: [9]bool,
    region_count: u32,
    cross_region: bool,
};

pub const TopologyStats = struct {
    total_nodes: u64,
    total_regions: u32,
    placement_decisions: u64,
    cross_region_placements: u64,
    local_reads: u64,
    remote_reads: u64,
    region_violations: u64,
};

pub const RegionTopology = struct {
    allocator: std.mem.Allocator,
    config: TopologyConfig,
    node_regions: std.AutoHashMap([32]u8, Region),
    region_nodes: [9]std.ArrayList([32]u8),
    stats: TopologyStats,

    pub fn init(allocator: std.mem.Allocator) RegionTopology {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: TopologyConfig) RegionTopology {
        var region_nodes: [9]std.ArrayList([32]u8) = undefined;
        for (0..9) |i| {
            region_nodes[i] = .empty;
        }
        return .{
            .allocator = allocator,
            .config = config,
            .node_regions = std.AutoHashMap([32]u8, Region).init(allocator),
            .region_nodes = region_nodes,
            .stats = std.mem.zeroes(TopologyStats),
        };
    }

    pub fn deinit(self: *RegionTopology) void {
        self.node_regions.deinit();
        for (0..9) |i| {
            self.region_nodes[i].deinit(self.allocator);
        }
    }

    /// Register a node in a specific region
    pub fn registerNode(self: *RegionTopology, node_id: [32]u8, region: Region) !void {
        const region_idx = @intFromEnum(region);
        if (region_idx >= 9) return; // Skip unknown region

        const existing = self.node_regions.get(node_id);
        if (existing == null) {
            self.stats.total_nodes += 1;
        } else {
            // Remove from old region
            const old_idx = @intFromEnum(existing.?);
            if (old_idx < 9) {
                var i: usize = 0;
                while (i < self.region_nodes[old_idx].items.len) {
                    if (std.mem.eql(u8, &self.region_nodes[old_idx].items[i], &node_id)) {
                        _ = self.region_nodes[old_idx].swapRemove(i);
                        break;
                    }
                    i += 1;
                }
            }
        }

        try self.node_regions.put(node_id, region);
        try self.region_nodes[region_idx].append(self.allocator, node_id);

        // Recount active regions
        var active: u32 = 0;
        for (0..9) |r| {
            if (self.region_nodes[r].items.len > 0) active += 1;
        }
        self.stats.total_regions = active;
    }

    /// Get region for a node
    pub fn getRegion(self: *RegionTopology, node_id: [32]u8) Region {
        return self.node_regions.get(node_id) orelse .unknown;
    }

    /// Get all nodes in a region
    pub fn getNodesInRegion(self: *RegionTopology, region: Region) []const [32]u8 {
        const idx = @intFromEnum(region);
        if (idx >= 9) return &[_][32]u8{};
        return self.region_nodes[idx].items;
    }

    /// Compute optimal placement for a shard across regions
    pub fn computePlacement(self: *RegionTopology, requester_region: Region) PlacementDecision {
        var decision: PlacementDecision = .{
            .target_regions = [_]bool{false} ** 9,
            .region_count = 0,
            .cross_region = false,
        };

        const req_idx = @intFromEnum(requester_region);
        if (req_idx >= 9) return decision;

        // Always include requester's region first
        if (self.region_nodes[req_idx].items.len > 0) {
            decision.target_regions[req_idx] = true;
            decision.region_count = 1;
        }

        // Add nearest regions until min_regions_per_shard met
        if (decision.region_count < self.config.min_regions_per_shard) {
            // Sort other regions by latency from requester
            var region_latencies: [9]struct { idx: usize, latency: u32 } = undefined;
            for (0..9) |r| {
                region_latencies[r] = .{
                    .idx = r,
                    .latency = INTER_REGION_LATENCY_MS[req_idx][r],
                };
            }
            // Simple selection sort by latency
            for (0..9) |i| {
                var min_j = i;
                for (i + 1..9) |j| {
                    if (region_latencies[j].latency < region_latencies[min_j].latency) {
                        min_j = j;
                    }
                }
                if (min_j != i) {
                    const tmp = region_latencies[i];
                    region_latencies[i] = region_latencies[min_j];
                    region_latencies[min_j] = tmp;
                }
            }

            for (region_latencies) |rl| {
                if (decision.region_count >= self.config.min_regions_per_shard) break;
                if (rl.latency > self.config.max_write_latency_ms) continue;
                if (decision.target_regions[rl.idx]) continue;
                if (self.region_nodes[rl.idx].items.len == 0) continue;

                decision.target_regions[rl.idx] = true;
                decision.region_count += 1;
                if (rl.idx != req_idx) decision.cross_region = true;
            }
        }

        self.stats.placement_decisions += 1;
        if (decision.cross_region) self.stats.cross_region_placements += 1;

        return decision;
    }

    /// Select best node for read from a region, preferring local
    pub fn selectReadNode(self: *RegionTopology, requester_region: Region, latency_tracker: *peer_latency_mod.PeerLatencyTracker) ?[32]u8 {
        const req_idx = @intFromEnum(requester_region);
        if (req_idx >= 9) return null;

        // Try local region first
        const local_nodes = self.region_nodes[req_idx].items;
        if (local_nodes.len > 0) {
            var best_node: [32]u8 = local_nodes[0];
            var best_latency: f64 = latency_tracker.getScore(local_nodes[0]).ema_latency_ns;

            for (local_nodes[1..]) |node| {
                const lat = latency_tracker.getScore(node).ema_latency_ns;
                if (lat < best_latency) {
                    best_latency = lat;
                    best_node = node;
                }
            }

            if (best_latency <= @as(f64, @floatFromInt(self.config.local_read_threshold_ns))) {
                self.stats.local_reads += 1;
                return best_node;
            }
        }

        // Fall back to nearest region
        var best_region: ?usize = null;
        var best_lat: u32 = std.math.maxInt(u32);
        for (0..9) |r| {
            if (r == req_idx) continue;
            if (self.region_nodes[r].items.len == 0) continue;
            if (INTER_REGION_LATENCY_MS[req_idx][r] < best_lat) {
                best_lat = INTER_REGION_LATENCY_MS[req_idx][r];
                best_region = r;
            }
        }

        if (best_region) |br| {
            self.stats.remote_reads += 1;
            return self.region_nodes[br].items[0];
        }

        return null;
    }

    /// Get latency zone (0=local, 1=near <100ms, 2=far) for a node relative to a region
    pub fn getLatencyZone(requester_region: Region, target_region: Region) u8 {
        if (requester_region == target_region) return 0;
        const req_idx = @intFromEnum(requester_region);
        const tgt_idx = @intFromEnum(target_region);
        if (req_idx >= 9 or tgt_idx >= 9) return 2;
        const latency = INTER_REGION_LATENCY_MS[req_idx][tgt_idx];
        if (latency <= 100) return 1; // near
        return 2; // far
    }

    /// Get per-region statistics
    pub fn getRegionStats(self: *RegionTopology, region: Region) RegionStats {
        const idx = @intFromEnum(region);
        if (idx >= 9) return .{ .node_count = 0, .shard_count = 0 };
        return .{
            .node_count = @intCast(self.region_nodes[idx].items.len),
            .shard_count = 0, // tracked externally
        };
    }

    /// Check if placement violates concentration limits
    pub fn checkConcentrationViolation(self: *RegionTopology, _: Region, current_replicas: u32) bool {
        return current_replicas >= self.config.max_replicas_per_region;
    }

    pub fn getStats(self: *RegionTopology) TopologyStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "register nodes across regions" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.init(allocator);
    defer topo.deinit();

    var n1: [32]u8 = undefined;
    @memset(&n1, 1);
    var n2: [32]u8 = undefined;
    @memset(&n2, 2);
    var n3: [32]u8 = undefined;
    @memset(&n3, 3);

    try topo.registerNode(n1, .us_east);
    try topo.registerNode(n2, .eu_west);
    try topo.registerNode(n3, .asia_east);

    try std.testing.expectEqual(Region.us_east, topo.getRegion(n1));
    try std.testing.expectEqual(Region.eu_west, topo.getRegion(n2));
    try std.testing.expectEqual(Region.asia_east, topo.getRegion(n3));
    try std.testing.expectEqual(@as(u32, 3), topo.getStats().total_regions);
    try std.testing.expectEqual(@as(u64, 3), topo.getStats().total_nodes);
}

test "compute placement selects multiple regions" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.initWithConfig(allocator, .{
        .min_regions_per_shard = 2,
        .max_replicas_per_region = 3,
        .local_read_threshold_ns = 50_000_000,
        .max_write_latency_ms = 300,
    });
    defer topo.deinit();

    // Add nodes to 3 regions
    for (0..5) |i| {
        var nid: [32]u8 = undefined;
        @memset(&nid, @intCast(i + 1));
        const region: Region = switch (i % 3) {
            0 => .us_east,
            1 => .eu_west,
            2 => .us_west,
            else => unreachable,
        };
        try topo.registerNode(nid, region);
    }

    const decision = topo.computePlacement(.us_east);
    try std.testing.expect(decision.region_count >= 2);
    try std.testing.expect(decision.target_regions[0]); // us_east (requester)
    try std.testing.expect(decision.cross_region);
}

test "select read node prefers local region" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.initWithConfig(allocator, .{
        .local_read_threshold_ns = 100_000_000, // 100ms
    });
    defer topo.deinit();

    var latency = peer_latency_mod.PeerLatencyTracker.init(allocator);
    defer latency.deinit();

    var local: [32]u8 = undefined;
    @memset(&local, 1);
    var remote: [32]u8 = undefined;
    @memset(&remote, 2);

    try topo.registerNode(local, .us_east);
    try topo.registerNode(remote, .asia_east);

    // Local node has low latency
    latency.recordLatency(local, 10_000_000); // 10ms
    latency.recordLatency(remote, 200_000_000); // 200ms

    const selected = topo.selectReadNode(.us_east, &latency);
    try std.testing.expect(selected != null);
    try std.testing.expect(std.mem.eql(u8, &selected.?, &local));
    try std.testing.expectEqual(@as(u64, 1), topo.getStats().local_reads);
}

test "latency zone classification" {
    // Same region = local (0)
    try std.testing.expectEqual(@as(u8, 0), RegionTopology.getLatencyZone(.us_east, .us_east));
    // Near region <100ms (1)
    try std.testing.expectEqual(@as(u8, 1), RegionTopology.getLatencyZone(.us_east, .us_west)); // 60ms
    try std.testing.expectEqual(@as(u8, 1), RegionTopology.getLatencyZone(.us_east, .eu_west)); // 80ms
    try std.testing.expectEqual(@as(u8, 1), RegionTopology.getLatencyZone(.eu_west, .eu_east)); // 30ms
    // Far region >100ms (2)
    try std.testing.expectEqual(@as(u8, 2), RegionTopology.getLatencyZone(.us_east, .asia_east)); // 180ms
    try std.testing.expectEqual(@as(u8, 2), RegionTopology.getLatencyZone(.us_east, .oceania)); // 220ms
}

test "node re-registration moves between regions" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.init(allocator);
    defer topo.deinit();

    var node: [32]u8 = undefined;
    @memset(&node, 1);

    try topo.registerNode(node, .us_east);
    try std.testing.expectEqual(Region.us_east, topo.getRegion(node));
    try std.testing.expectEqual(@as(usize, 1), topo.getNodesInRegion(.us_east).len);

    // Move to eu_west
    try topo.registerNode(node, .eu_west);
    try std.testing.expectEqual(Region.eu_west, topo.getRegion(node));
    try std.testing.expectEqual(@as(usize, 0), topo.getNodesInRegion(.us_east).len);
    try std.testing.expectEqual(@as(usize, 1), topo.getNodesInRegion(.eu_west).len);
    // Node count stays 1 (no double-count)
    try std.testing.expectEqual(@as(u64, 1), topo.getStats().total_nodes);
}

test "concentration violation detection" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.init(allocator);
    defer topo.deinit();

    try std.testing.expect(!topo.checkConcentrationViolation(.us_east, 2));
    try std.testing.expect(topo.checkConcentrationViolation(.us_east, 3));
    try std.testing.expect(topo.checkConcentrationViolation(.us_east, 5));
}

test "topology stats accumulate" {
    const allocator = std.testing.allocator;
    var topo = RegionTopology.init(allocator);
    defer topo.deinit();

    for (0..9) |r| {
        var nid: [32]u8 = undefined;
        @memset(&nid, @intCast(r + 1));
        try topo.registerNode(nid, @enumFromInt(@as(u8, @intCast(r))));
    }

    try std.testing.expectEqual(@as(u64, 9), topo.getStats().total_nodes);
    try std.testing.expectEqual(@as(u32, 9), topo.getStats().total_regions);

    _ = topo.computePlacement(.us_east);
    _ = topo.computePlacement(.eu_west);
    _ = topo.computePlacement(.asia_east);

    try std.testing.expectEqual(@as(u64, 3), topo.getStats().placement_decisions);
    try std.testing.expect(topo.getStats().cross_region_placements >= 2);
}
