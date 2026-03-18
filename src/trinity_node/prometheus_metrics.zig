// =============================================================================
// TRINITY PROMETHEUS METRICS v1.7 - Machine-Consumable Metrics Export
// Exports network health data in Prometheus exposition format
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const network_stats_mod = @import("network_stats.zig");

// =============================================================================
// PROMETHEUS METRICS EXPORTER
// =============================================================================

pub const PrometheusExporter = struct {
    allocator: std.mem.Allocator,
    namespace: []const u8,

    pub fn init(allocator: std.mem.Allocator) PrometheusExporter {
        return .{
            .allocator = allocator,
            .namespace = "trinity",
        };
    }

    pub fn deinit(self: *PrometheusExporter) void {
        _ = self;
    }

    /// Export a NetworkHealthReport as Prometheus exposition format text
    pub fn exportMetrics(self: *PrometheusExporter, report: network_stats_mod.NetworkHealthReport) ![]u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        errdefer buf.deinit(self.allocator);
        const w = buf.writer(self.allocator);

        const ns = self.namespace;

        // Peers
        try w.print("# HELP {s}_node_count Number of active nodes in the network\n", .{ns});
        try w.print("# TYPE {s}_node_count gauge\n", .{ns});
        try w.print("{s}_node_count {d}\n\n", .{ ns, report.node_count });

        // Storage
        try w.print("# HELP {s}_shards_total Total number of shards stored across all nodes\n", .{ns});
        try w.print("# TYPE {s}_shards_total gauge\n", .{ns});
        try w.print("{s}_shards_total {d}\n\n", .{ ns, report.total_shards });

        try w.print("# HELP {s}_storage_bytes_used Total bytes used across all nodes\n", .{ns});
        try w.print("# TYPE {s}_storage_bytes_used gauge\n", .{ns});
        try w.print("{s}_storage_bytes_used {d}\n\n", .{ ns, report.total_bytes_used });

        try w.print("# HELP {s}_storage_bytes_available Total bytes available across all nodes\n", .{ns});
        try w.print("# TYPE {s}_storage_bytes_available gauge\n", .{ns});
        try w.print("{s}_storage_bytes_available {d}\n\n", .{ ns, report.total_bytes_available });

        // Replication
        try w.print("# HELP {s}_shards_tracked Shards tracked by the rebalancer\n", .{ns});
        try w.print("# TYPE {s}_shards_tracked gauge\n", .{ns});
        try w.print("{s}_shards_tracked {d}\n\n", .{ ns, report.shards_tracked });

        try w.print("# HELP {s}_shards_rebalanced_total Total shards rebalanced\n", .{ns});
        try w.print("# TYPE {s}_shards_rebalanced_total counter\n", .{ns});
        try w.print("{s}_shards_rebalanced_total {d}\n\n", .{ ns, report.shards_rebalanced });

        try w.print("# HELP {s}_replication_target Target replication factor\n", .{ns});
        try w.print("# TYPE {s}_replication_target gauge\n", .{ns});
        try w.print("{s}_replication_target {d}\n\n", .{ ns, report.target_replication });

        // PoS
        try w.print("# HELP {s}_pos_challenges_issued_total Total PoS challenges issued\n", .{ns});
        try w.print("# TYPE {s}_pos_challenges_issued_total counter\n", .{ns});
        try w.print("{s}_pos_challenges_issued_total {d}\n\n", .{ ns, report.pos_challenges_issued });

        try w.print("# HELP {s}_pos_challenges_passed_total Total PoS challenges passed\n", .{ns});
        try w.print("# TYPE {s}_pos_challenges_passed_total counter\n", .{ns});
        try w.print("{s}_pos_challenges_passed_total {d}\n\n", .{ ns, report.pos_challenges_passed });

        try w.print("# HELP {s}_pos_challenges_failed_total Total PoS challenges failed\n", .{ns});
        try w.print("# TYPE {s}_pos_challenges_failed_total counter\n", .{ns});
        try w.print("{s}_pos_challenges_failed_total {d}\n\n", .{ ns, report.pos_challenges_failed });

        // Bandwidth
        try w.print("# HELP {s}_bandwidth_upload_bytes_total Total bytes uploaded\n", .{ns});
        try w.print("# TYPE {s}_bandwidth_upload_bytes_total counter\n", .{ns});
        try w.print("{s}_bandwidth_upload_bytes_total {d}\n\n", .{ ns, report.total_upload });

        try w.print("# HELP {s}_bandwidth_download_bytes_total Total bytes downloaded\n", .{ns});
        try w.print("# TYPE {s}_bandwidth_download_bytes_total counter\n", .{ns});
        try w.print("{s}_bandwidth_download_bytes_total {d}\n\n", .{ ns, report.total_download });

        // Scrubber
        try w.print("# HELP {s}_scrub_rounds_total Total scrub rounds completed\n", .{ns});
        try w.print("# TYPE {s}_scrub_rounds_total counter\n", .{ns});
        try w.print("{s}_scrub_rounds_total {d}\n\n", .{ ns, report.scrub_total });

        try w.print("# HELP {s}_scrub_corruptions_total Total corruptions detected by scrubber\n", .{ns});
        try w.print("# TYPE {s}_scrub_corruptions_total counter\n", .{ns});
        try w.print("{s}_scrub_corruptions_total {d}\n\n", .{ ns, report.scrub_corruptions });

        // Reputation
        try w.print("# HELP {s}_reputation_avg Average reputation score across all nodes\n", .{ns});
        try w.print("# TYPE {s}_reputation_avg gauge\n", .{ns});
        try w.print("{s}_reputation_avg {d:.6}\n\n", .{ ns, report.reputation_avg });

        try w.print("# HELP {s}_reputation_min Minimum reputation score\n", .{ns});
        try w.print("# TYPE {s}_reputation_min gauge\n", .{ns});
        try w.print("{s}_reputation_min {d:.6}\n\n", .{ ns, report.reputation_min });

        try w.print("# HELP {s}_reputation_max Maximum reputation score\n", .{ns});
        try w.print("# TYPE {s}_reputation_max gauge\n", .{ns});
        try w.print("{s}_reputation_max {d:.6}\n\n", .{ ns, report.reputation_max });

        // Timestamp
        try w.print("# HELP {s}_report_generated_timestamp_seconds Timestamp when report was generated\n", .{ns});
        try w.print("# TYPE {s}_report_generated_timestamp_seconds gauge\n", .{ns});
        try w.print("{s}_report_generated_timestamp_seconds {d}\n", .{ ns, report.generated_at });

        return buf.toOwnedSlice(self.allocator);
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "prometheus export contains all metric types" {
    const allocator = std.testing.allocator;

    var exporter = PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 10,
        .total_shards = 500,
        .total_bytes_used = 1024 * 1024 * 100,
        .total_bytes_available = 1024 * 1024 * 900,
        .shards_tracked = 450,
        .shards_rebalanced = 25,
        .target_replication = 3,
        .pos_challenges_issued = 100,
        .pos_challenges_passed = 95,
        .pos_challenges_failed = 5,
        .total_upload = 1024 * 1024 * 50,
        .total_download = 1024 * 1024 * 30,
        .scrub_total = 10,
        .scrub_corruptions = 2,
        .reputation_avg = 0.75,
        .reputation_min = 0.3,
        .reputation_max = 0.95,
        .generated_at = 1700000000,
    };

    const metrics = try exporter.exportMetrics(report);
    defer allocator.free(metrics);

    // Verify HELP and TYPE lines present
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# HELP trinity_node_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_node_count gauge") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_node_count 10") != null);

    // Verify counter types
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_shards_rebalanced_total counter") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_pos_challenges_issued_total counter") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_scrub_corruptions_total counter") != null);

    // Verify gauge types
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_shards_total gauge") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "# TYPE trinity_reputation_avg gauge") != null);

    // Verify specific values
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_shards_total 500") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_pos_challenges_passed_total 95") != null);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_scrub_corruptions_total 2") != null);
}

test "prometheus export with zero values" {
    const allocator = std.testing.allocator;

    var exporter = PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 0,
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
        .generated_at = 0,
    };

    const metrics = try exporter.exportMetrics(report);
    defer allocator.free(metrics);

    try std.testing.expect(metrics.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, metrics, "trinity_node_count 0") != null);
}

test "prometheus export format validity" {
    const allocator = std.testing.allocator;

    var exporter = PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 5,
        .total_shards = 100,
        .total_bytes_used = 12345,
        .total_bytes_available = 67890,
        .shards_tracked = 90,
        .shards_rebalanced = 10,
        .target_replication = 3,
        .pos_challenges_issued = 50,
        .pos_challenges_passed = 48,
        .pos_challenges_failed = 2,
        .total_upload = 1000,
        .total_download = 500,
        .scrub_total = 5,
        .scrub_corruptions = 1,
        .reputation_avg = 0.85,
        .reputation_min = 0.5,
        .reputation_max = 0.99,
        .generated_at = 1700000000,
    };

    const metrics = try exporter.exportMetrics(report);
    defer allocator.free(metrics);

    // Each metric line should NOT start with '#' (data lines)
    // and HELP/TYPE lines should start with '#'
    var line_iter = std.mem.splitScalar(u8, metrics, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        // Line is either a comment (#) or a metric (no #)
        if (line[0] == '#') {
            // Should be HELP or TYPE
            try std.testing.expect(
                std.mem.startsWith(u8, line, "# HELP") or
                    std.mem.startsWith(u8, line, "# TYPE"),
            );
        } else {
            // Should contain metric name and value separated by space
            try std.testing.expect(std.mem.indexOf(u8, line, " ") != null);
        }
    }
}

test "prometheus metrics count" {
    const allocator = std.testing.allocator;

    var exporter = PrometheusExporter.init(allocator);
    defer exporter.deinit();

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 1,
        .total_shards = 1,
        .total_bytes_used = 1,
        .total_bytes_available = 1,
        .shards_tracked = 1,
        .shards_rebalanced = 1,
        .target_replication = 1,
        .pos_challenges_issued = 1,
        .pos_challenges_passed = 1,
        .pos_challenges_failed = 1,
        .total_upload = 1,
        .total_download = 1,
        .scrub_total = 1,
        .scrub_corruptions = 1,
        .reputation_avg = 0.5,
        .reputation_min = 0.5,
        .reputation_max = 0.5,
        .generated_at = 1,
    };

    const metrics = try exporter.exportMetrics(report);
    defer allocator.free(metrics);

    // Count # HELP lines = number of distinct metrics
    var help_count: usize = 0;
    var iter = std.mem.splitScalar(u8, metrics, '\n');
    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "# HELP")) help_count += 1;
    }

    // Should have 18 distinct metrics
    try std.testing.expectEqual(@as(usize, 18), help_count);
}
