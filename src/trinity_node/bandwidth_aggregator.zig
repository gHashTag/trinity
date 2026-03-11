// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY BANDWIDTH AGGREGATOR v1.5 - Network-Wide Bandwidth Metrics
// Collects per-node bandwidth reports, aggregates totals, computes reward shares
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const storage_mod = @import("storage.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// BANDWIDTH REPORT
// ═══════════════════════════════════════════════════════════════════════════════

pub const BandwidthReport = struct {
    node_id: [32]u8,
    bytes_uploaded: u64,
    bytes_downloaded: u64,
    shards_hosted: u64,
    period_start: i64,
    period_end: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BANDWIDTH SUMMARY
// ═══════════════════════════════════════════════════════════════════════════════

pub const BandwidthSummary = struct {
    total_upload: u64,
    total_download: u64,
    node_count: u32,
    timestamp: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// BANDWIDTH AGGREGATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const BandwidthAggregator = struct {
    allocator: std.mem.Allocator,
    reports: std.AutoHashMap([32]u8, BandwidthReport),
    aggregation_interval_secs: i64,
    last_aggregation_time: i64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) BandwidthAggregator {
        return .{
            .allocator = allocator,
            .reports = std.AutoHashMap([32]u8, BandwidthReport).init(allocator),
            .aggregation_interval_secs = 60,
            .last_aggregation_time = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *BandwidthAggregator) void {
        self.reports.deinit();
    }

    /// Record a bandwidth report from a peer
    pub fn recordReport(self: *BandwidthAggregator, report: BandwidthReport) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.reports.put(report.node_id, report) catch |err| {
            std.log.debug("bandwidth_aggregator: report storage failed: {}", .{err});
        };
    }

    /// Generate a local bandwidth report from a RewardTracker
    pub fn generateLocalReport(
        tracker: *const storage_mod.RewardTracker,
        local_node_id: [32]u8,
    ) BandwidthReport {
        const now = std.time.timestamp();
        return .{
            .node_id = local_node_id,
            .bytes_uploaded = tracker.bytes_uploaded,
            .bytes_downloaded = tracker.bytes_downloaded,
            .shards_hosted = tracker.shards_hosted,
            .period_start = tracker.hosting_start,
            .period_end = now,
        };
    }

    /// Aggregate all reports into a summary
    pub fn aggregate(self: *BandwidthAggregator) BandwidthSummary {
        self.mutex.lock();
        defer self.mutex.unlock();

        var total_upload: u64 = 0;
        var total_download: u64 = 0;
        var count: u32 = 0;

        var iter = self.reports.valueIterator();
        while (iter.next()) |report| {
            total_upload += report.bytes_uploaded;
            total_download += report.bytes_downloaded;
            count += 1;
        }

        self.last_aggregation_time = std.time.timestamp();

        return .{
            .total_upload = total_upload,
            .total_download = total_download,
            .node_count = count,
            .timestamp = self.last_aggregation_time,
        };
    }

    /// Get reward share for a node (proportional to its bandwidth contribution)
    /// Returns a value between 0.0 and 1.0
    pub fn getRewardShare(self: *BandwidthAggregator, node_id: [32]u8) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const report = self.reports.get(node_id) orelse return 0.0;
        const node_bandwidth: u64 = report.bytes_uploaded + report.bytes_downloaded;
        if (node_bandwidth == 0) return 0.0;

        var total_bandwidth: u64 = 0;
        var iter = self.reports.valueIterator();
        while (iter.next()) |r| {
            total_bandwidth += r.bytes_uploaded + r.bytes_downloaded;
        }

        if (total_bandwidth == 0) return 0.0;
        return @as(f64, @floatFromInt(node_bandwidth)) / @as(f64, @floatFromInt(total_bandwidth));
    }

    /// Check if it's time to aggregate
    pub fn shouldAggregate(self: *BandwidthAggregator) bool {
        const now = std.time.timestamp();
        return (now - self.last_aggregation_time) >= self.aggregation_interval_secs;
    }

    /// Get total throughput across all nodes
    pub fn getTotalThroughput(self: *BandwidthAggregator) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var total: u64 = 0;
        var iter = self.reports.valueIterator();
        while (iter.next()) |report| {
            total += report.bytes_uploaded + report.bytes_downloaded;
        }
        return total;
    }

    /// Get number of reporting nodes
    pub fn getReportCount(self: *BandwidthAggregator) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return @intCast(self.reports.count());
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "record and aggregate bandwidth reports" {
    const allocator = std.testing.allocator;

    var aggregator = BandwidthAggregator.init(allocator);
    defer aggregator.deinit();

    const now = std.time.timestamp();

    // 5 nodes with different bandwidth
    for (0..5) |i| {
        var node_id: [32]u8 = undefined;
        @memset(&node_id, @intCast(i + 1));
        aggregator.recordReport(.{
            .node_id = node_id,
            .bytes_uploaded = @as(u64, (i + 1)) * 1024 * 1024,
            .bytes_downloaded = @as(u64, (i + 1)) * 512 * 1024,
            .shards_hosted = @as(u64, (i + 1)) * 10,
            .period_start = now - 3600,
            .period_end = now,
        });
    }

    const summary = aggregator.aggregate();
    try std.testing.expectEqual(@as(u32, 5), summary.node_count);

    // Total upload = (1+2+3+4+5) * 1MB = 15 MB
    try std.testing.expectEqual(@as(u64, 15 * 1024 * 1024), summary.total_upload);
    // Total download = (1+2+3+4+5) * 512KB = 7.5 MB
    try std.testing.expectEqual(@as(u64, 15 * 512 * 1024), summary.total_download);
}

test "reward share proportional to contribution" {
    const allocator = std.testing.allocator;

    var aggregator = BandwidthAggregator.init(allocator);
    defer aggregator.deinit();

    const now = std.time.timestamp();

    // Node 1: 100 MB total
    var id1: [32]u8 = undefined;
    @memset(&id1, 0x01);
    aggregator.recordReport(.{
        .node_id = id1,
        .bytes_uploaded = 60 * 1024 * 1024,
        .bytes_downloaded = 40 * 1024 * 1024,
        .shards_hosted = 10,
        .period_start = now - 3600,
        .period_end = now,
    });

    // Node 2: 200 MB total
    var id2: [32]u8 = undefined;
    @memset(&id2, 0x02);
    aggregator.recordReport(.{
        .node_id = id2,
        .bytes_uploaded = 120 * 1024 * 1024,
        .bytes_downloaded = 80 * 1024 * 1024,
        .shards_hosted = 20,
        .period_start = now - 3600,
        .period_end = now,
    });

    // Node 3: 300 MB total
    var id3: [32]u8 = undefined;
    @memset(&id3, 0x03);
    aggregator.recordReport(.{
        .node_id = id3,
        .bytes_uploaded = 180 * 1024 * 1024,
        .bytes_downloaded = 120 * 1024 * 1024,
        .shards_hosted = 30,
        .period_start = now - 3600,
        .period_end = now,
    });

    // Total = 600 MB. Shares: 100/600 ≈ 0.1667, 200/600 ≈ 0.3333, 300/600 = 0.5
    const share1 = aggregator.getRewardShare(id1);
    const share2 = aggregator.getRewardShare(id2);
    const share3 = aggregator.getRewardShare(id3);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 6.0), share1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0 / 6.0), share2, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0 / 6.0), share3, 0.001);

    // Shares should sum to 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), share1 + share2 + share3, 0.001);

    // Unknown node returns 0
    var unknown: [32]u8 = undefined;
    @memset(&unknown, 0xFF);
    try std.testing.expectEqual(@as(f64, 0.0), aggregator.getRewardShare(unknown));
}

test "generate local report from RewardTracker" {
    var tracker = storage_mod.RewardTracker{
        .shards_hosted = 42,
        .retrievals_served = 10,
        .hosting_start = std.time.timestamp() - 7200,
        .bytes_uploaded = 500 * 1024 * 1024,
        .bytes_downloaded = 300 * 1024 * 1024,
    };

    const node_id = [_]u8{0xAA} ** 32;
    const report = BandwidthAggregator.generateLocalReport(&tracker, node_id);

    try std.testing.expectEqual(@as(u64, 42), report.shards_hosted);
    try std.testing.expectEqual(@as(u64, 500 * 1024 * 1024), report.bytes_uploaded);
    try std.testing.expectEqual(@as(u64, 300 * 1024 * 1024), report.bytes_downloaded);
    try std.testing.expectEqualSlices(u8, &node_id, &report.node_id);
    try std.testing.expectEqual(tracker.hosting_start, report.period_start);
    try std.testing.expect(report.period_end >= report.period_start);
}

test "empty aggregation returns zeros" {
    const allocator = std.testing.allocator;

    var aggregator = BandwidthAggregator.init(allocator);
    defer aggregator.deinit();

    const summary = aggregator.aggregate();
    try std.testing.expectEqual(@as(u64, 0), summary.total_upload);
    try std.testing.expectEqual(@as(u64, 0), summary.total_download);
    try std.testing.expectEqual(@as(u32, 0), summary.node_count);
}

test "aggregation timing respects interval" {
    const allocator = std.testing.allocator;

    var aggregator = BandwidthAggregator.init(allocator);
    defer aggregator.deinit();
    aggregator.aggregation_interval_secs = 60;

    // Initially should aggregate (last_aggregation_time = 0)
    try std.testing.expect(aggregator.shouldAggregate());

    // After aggregating, should not aggregate again immediately
    _ = aggregator.aggregate();
    try std.testing.expect(!aggregator.shouldAggregate());
}
