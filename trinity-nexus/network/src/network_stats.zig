// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NETWORK STATS v1.6 - Aggregated Health Report Generator
// Collects data from all subsystems into a unified health report (text + JSON)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");
const shard_rebalancer_mod = @import("shard_rebalancer.zig");
const proof_of_storage_mod = @import("proof_of_storage.zig");
const bandwidth_aggregator_mod = @import("bandwidth_aggregator.zig");
const storage_discovery = @import("storage_discovery.zig");
const shard_scrubber_mod = @import("shard_scrubber.zig");
const node_reputation_mod = @import("node_reputation.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK HEALTH REPORT
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkHealthReport = struct {
    // Peers
    node_count: u32,
    // Storage
    total_shards: u32,
    total_bytes_used: u64,
    total_bytes_available: u64,
    // Replication
    shards_tracked: u32,
    shards_rebalanced: u64,
    target_replication: u32,
    // PoS
    pos_challenges_issued: u64,
    pos_challenges_passed: u64,
    pos_challenges_failed: u64,
    // Bandwidth
    total_upload: u64,
    total_download: u64,
    // Scrubber
    scrub_total: u64,
    scrub_corruptions: u64,
    // Reputation
    reputation_avg: f64,
    reputation_min: f64,
    reputation_max: f64,
    // Timestamp
    generated_at: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK STATS REPORTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const NetworkStatsReporter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) NetworkStatsReporter {
        return .{ .allocator = allocator };
    }

    /// Generate a comprehensive network health report
    pub fn generateReport(
        self: *NetworkStatsReporter,
        peers: []const *storage_mod.StorageProvider,
        rebalancer: ?*shard_rebalancer_mod.ShardRebalancer,
        pos: ?*proof_of_storage_mod.ProofOfStorageEngine,
        bw_agg: ?*bandwidth_aggregator_mod.BandwidthAggregator,
        registry: ?*storage_discovery.StoragePeerRegistry,
        scrubber: ?*shard_scrubber_mod.ShardScrubber,
        reputation: ?*node_reputation_mod.NodeReputationSystem,
    ) NetworkHealthReport {
        _ = registry;

        var report = NetworkHealthReport{
            .node_count = @intCast(peers.len),
            .total_shards = 0,
            .total_bytes_used = 0,
            .total_bytes_available = 0,
            .shards_tracked = 0,
            .shards_rebalanced = 0,
            .target_replication = 0,
            .pos_challenges_issued = 0,
            .pos_challenges_passed = 0,
            .pos_challenges_failed = 0,
            .total_upload = 0,
            .total_download = 0,
            .scrub_total = 0,
            .scrub_corruptions = 0,
            .reputation_avg = 0.0,
            .reputation_min = 0.0,
            .reputation_max = 0.0,
            .generated_at = std.time.timestamp(),
        };

        // Aggregate storage stats from all peers
        for (peers) |peer| {
            const stats = peer.getStats();
            report.total_shards += stats.total_shards;
            report.total_bytes_used += stats.used_bytes;
            report.total_bytes_available += stats.available_bytes;
        }

        // Rebalancer stats
        if (rebalancer) |rb| {
            const rb_stats = rb.getStats();
            report.shards_tracked = rb_stats.shards_tracked;
            report.shards_rebalanced = rb_stats.shards_rebalanced;
            report.target_replication = rb_stats.target_replication;
        }

        // PoS stats
        if (pos) |p| {
            const pos_stats = p.getStats();
            report.pos_challenges_issued = pos_stats.challenges_issued;
            report.pos_challenges_passed = pos_stats.challenges_passed;
            report.pos_challenges_failed = pos_stats.challenges_failed;
        }

        // Bandwidth stats
        if (bw_agg) |bw| {
            const summary = bw.aggregate();
            report.total_upload = summary.total_upload;
            report.total_download = summary.total_download;
        }

        // Scrubber stats
        if (scrubber) |sc| {
            const sc_stats = sc.getStats();
            report.scrub_total = sc_stats.total_scrubs;
            report.scrub_corruptions = sc_stats.corruptions_found;
        }

        // Reputation stats
        if (reputation) |rep| {
            const ranked = rep.rankNodes(self.allocator) catch &[0]node_reputation_mod.ReputationScore{};
            defer if (ranked.len > 0) self.allocator.free(ranked);

            if (ranked.len > 0) {
                var sum: f64 = 0;
                report.reputation_min = ranked[ranked.len - 1].score; // Sorted desc, last is min
                report.reputation_max = ranked[0].score;
                for (ranked) |entry| {
                    sum += entry.score;
                }
                report.reputation_avg = sum / @as(f64, @floatFromInt(ranked.len));
            }
        }

        return report;
    }

    /// Format report as human-readable text
    pub fn formatText(self: *NetworkStatsReporter, report: NetworkHealthReport) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        errdefer buf.deinit(self.allocator);
        const w = buf.writer(self.allocator);

        try w.print("=== Trinity Network Health Report ===\n", .{});
        try w.print("Nodes: {d}\n", .{report.node_count});
        try w.print("Shards: {d} ({d} tracked by rebalancer)\n", .{ report.total_shards, report.shards_tracked });
        try w.print("Storage: {d} bytes used, {d} bytes available\n", .{ report.total_bytes_used, report.total_bytes_available });
        try w.print("Replication target: {d}, shards rebalanced: {d}\n", .{ report.target_replication, report.shards_rebalanced });
        try w.print("PoS: {d} issued, {d} passed, {d} failed\n", .{ report.pos_challenges_issued, report.pos_challenges_passed, report.pos_challenges_failed });
        try w.print("Bandwidth: {d} up, {d} down\n", .{ report.total_upload, report.total_download });
        try w.print("Scrubber: {d} rounds, {d} corruptions\n", .{ report.scrub_total, report.scrub_corruptions });
        try w.print("Reputation: avg={d:.3}, min={d:.3}, max={d:.3}\n", .{ report.reputation_avg, report.reputation_min, report.reputation_max });
        try w.print("Generated at: {d}\n", .{report.generated_at});

        return buf.toOwnedSlice(self.allocator);
    }

    /// Format report as JSON
    pub fn formatJson(self: *NetworkStatsReporter, report: NetworkHealthReport) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        errdefer buf.deinit(self.allocator);
        const w = buf.writer(self.allocator);

        try w.print("{{", .{});
        try w.print("\"node_count\":{d},", .{report.node_count});
        try w.print("\"total_shards\":{d},", .{report.total_shards});
        try w.print("\"total_bytes_used\":{d},", .{report.total_bytes_used});
        try w.print("\"total_bytes_available\":{d},", .{report.total_bytes_available});
        try w.print("\"shards_tracked\":{d},", .{report.shards_tracked});
        try w.print("\"shards_rebalanced\":{d},", .{report.shards_rebalanced});
        try w.print("\"target_replication\":{d},", .{report.target_replication});
        try w.print("\"pos_challenges_issued\":{d},", .{report.pos_challenges_issued});
        try w.print("\"pos_challenges_passed\":{d},", .{report.pos_challenges_passed});
        try w.print("\"pos_challenges_failed\":{d},", .{report.pos_challenges_failed});
        try w.print("\"total_upload\":{d},", .{report.total_upload});
        try w.print("\"total_download\":{d},", .{report.total_download});
        try w.print("\"scrub_total\":{d},", .{report.scrub_total});
        try w.print("\"scrub_corruptions\":{d},", .{report.scrub_corruptions});
        try w.print("\"reputation_avg\":{d:.3},", .{report.reputation_avg});
        try w.print("\"reputation_min\":{d:.3},", .{report.reputation_min});
        try w.print("\"reputation_max\":{d:.3},", .{report.reputation_max});
        try w.print("\"generated_at\":{d}", .{report.generated_at});
        try w.print("}}", .{});

        return buf.toOwnedSlice(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "empty network report" {
    const allocator = std.testing.allocator;

    var reporter = NetworkStatsReporter.init(allocator);
    const peers = [0]*storage_mod.StorageProvider{};
    const report = reporter.generateReport(&peers, null, null, null, null, null, null);

    try std.testing.expectEqual(@as(u32, 0), report.node_count);
    try std.testing.expectEqual(@as(u32, 0), report.total_shards);
}

test "5-node network report" {
    const allocator = std.testing.allocator;

    var reporter = NetworkStatsReporter.init(allocator);

    const PEER_COUNT = 5;
    var nodes: [PEER_COUNT]storage_mod.StorageProvider = undefined;
    for (0..PEER_COUNT) |i| {
        nodes[i] = storage_mod.StorageProvider.init(allocator, .{
            .max_bytes = 1024 * 1024,
            .shard_size = 64,
            .replication_factor = 1,
            .rs_parity_ratio = 0,
        });
    }
    defer for (0..PEER_COUNT) |i| nodes[i].deinit();

    var peers: [PEER_COUNT]*storage_mod.StorageProvider = undefined;
    for (0..PEER_COUNT) |i| peers[i] = &nodes[i];

    // Store a shard on each node
    for (0..PEER_COUNT) |i| {
        var data: [64]u8 = undefined;
        @memset(&data, @intCast(i + 1));
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
        _ = try nodes[i].storeShard(hash, &data);
    }

    var rebalancer = shard_rebalancer_mod.ShardRebalancer.init(allocator, 3);
    defer rebalancer.deinit();

    var pos_engine = proof_of_storage_mod.ProofOfStorageEngine.init(allocator);
    defer pos_engine.deinit();

    const report = reporter.generateReport(&peers, &rebalancer, &pos_engine, null, null, null, null);

    try std.testing.expectEqual(@as(u32, 5), report.node_count);
    try std.testing.expectEqual(@as(u32, 5), report.total_shards);
    try std.testing.expectEqual(@as(u32, 3), report.target_replication);
}

test "text format contains expected fields" {
    const allocator = std.testing.allocator;

    var reporter = NetworkStatsReporter.init(allocator);
    const peers = [0]*storage_mod.StorageProvider{};
    const report = reporter.generateReport(&peers, null, null, null, null, null, null);

    const text = try reporter.formatText(report);
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "Trinity Network Health Report") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Nodes: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "PoS:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Bandwidth:") != null);
}

test "JSON format is valid structure" {
    const allocator = std.testing.allocator;

    var reporter = NetworkStatsReporter.init(allocator);
    const peers = [0]*storage_mod.StorageProvider{};
    const report = reporter.generateReport(&peers, null, null, null, null, null, null);

    const json = try reporter.formatJson(report);
    defer allocator.free(json);

    // Verify it starts with { and ends with }
    try std.testing.expect(json[0] == '{');
    try std.testing.expect(json[json.len - 1] == '}');
    // Verify key fields present
    try std.testing.expect(std.mem.indexOf(u8, json, "\"node_count\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"generated_at\":") != null);
}
