// =============================================================================
// TRINITY PEER LATENCY v1.8 - Latency-Aware Peer Selection
// Track peer response times, prefer low-latency peers for shard operations
// V = n * 3^k * pi^m * phi^p * e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// LATENCY CONFIGURATION
// =============================================================================

pub const LatencyConfig = struct {
    /// Maximum samples to keep per peer (sliding window)
    max_samples: u32 = 100,
    /// Latency threshold (ns) above which peer is considered "slow"
    slow_threshold_ns: u64 = 500_000_000, // 500ms
    /// Weight for exponential moving average (0 to 1, higher = more recent)
    ema_alpha: f64 = 0.3,
};

pub const LatencyEntry = struct {
    avg_latency_ns: u64,
    min_latency_ns: u64,
    max_latency_ns: u64,
    ema_latency_ns: f64,
    sample_count: u64,
    last_sample_time: i64,
};

pub const PeerLatencyScore = struct {
    node_id: [32]u8,
    avg_latency_ns: u64,
    ema_latency_ns: f64,
    sample_count: u64,
    is_slow: bool,
};

pub const LatencyStats = struct {
    total_samples: u64,
    peers_tracked: u32,
    slow_peers: u32,
    avg_network_latency_ns: u64,
};

// =============================================================================
// PEER LATENCY TRACKER
// =============================================================================

pub const PeerLatencyTracker = struct {
    allocator: std.mem.Allocator,
    config: LatencyConfig,
    entries: std.AutoHashMap([32]u8, LatencyEntry),
    total_samples: u64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) PeerLatencyTracker {
        return initWithConfig(allocator, .{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: LatencyConfig) PeerLatencyTracker {
        return .{
            .allocator = allocator,
            .config = config,
            .entries = std.AutoHashMap([32]u8, LatencyEntry).init(allocator),
            .total_samples = 0,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *PeerLatencyTracker) void {
        self.entries.deinit();
    }

    /// Record a latency sample for a peer (in nanoseconds)
    pub fn recordLatency(self: *PeerLatencyTracker, node_id: [32]u8, latency_ns: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.entries.getOrPut(node_id) catch return;
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .avg_latency_ns = latency_ns,
                .min_latency_ns = latency_ns,
                .max_latency_ns = latency_ns,
                .ema_latency_ns = @floatFromInt(latency_ns),
                .sample_count = 1,
                .last_sample_time = std.time.timestamp(),
            };
        } else {
            const entry = result.value_ptr;
            entry.sample_count += 1;

            // Update min/max
            if (latency_ns < entry.min_latency_ns) entry.min_latency_ns = latency_ns;
            if (latency_ns > entry.max_latency_ns) entry.max_latency_ns = latency_ns;

            // Update running average
            const old_avg = entry.avg_latency_ns;
            const count = entry.sample_count;
            entry.avg_latency_ns = old_avg - old_avg / count + latency_ns / count;

            // Update EMA
            const lat_f: f64 = @floatFromInt(latency_ns);
            entry.ema_latency_ns = self.config.ema_alpha * lat_f + (1.0 - self.config.ema_alpha) * entry.ema_latency_ns;

            entry.last_sample_time = std.time.timestamp();
        }

        self.total_samples += 1;
    }

    /// Get latency score for a peer
    pub fn getScore(self: *PeerLatencyTracker, node_id: [32]u8) PeerLatencyScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.entries.get(node_id) orelse return .{
            .node_id = node_id,
            .avg_latency_ns = 0,
            .ema_latency_ns = 0,
            .sample_count = 0,
            .is_slow = false,
        };

        return .{
            .node_id = node_id,
            .avg_latency_ns = entry.avg_latency_ns,
            .ema_latency_ns = entry.ema_latency_ns,
            .sample_count = entry.sample_count,
            .is_slow = entry.avg_latency_ns > self.config.slow_threshold_ns,
        };
    }

    /// Rank peers by latency (lowest first)
    pub fn rankByLatency(self: *PeerLatencyTracker, allocator: std.mem.Allocator) ![]PeerLatencyScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        var scores = std.ArrayListUnmanaged(PeerLatencyScore){};
        var iter = self.entries.iterator();
        while (iter.next()) |kv| {
            try scores.append(allocator, .{
                .node_id = kv.key_ptr.*,
                .avg_latency_ns = kv.value_ptr.avg_latency_ns,
                .ema_latency_ns = kv.value_ptr.ema_latency_ns,
                .sample_count = kv.value_ptr.sample_count,
                .is_slow = kv.value_ptr.avg_latency_ns > self.config.slow_threshold_ns,
            });
        }

        const items = try scores.toOwnedSlice(allocator);

        // Sort by EMA latency (ascending = fastest first)
        std.mem.sort(PeerLatencyScore, items, {}, struct {
            fn lessThan(_: void, a: PeerLatencyScore, b: PeerLatencyScore) bool {
                return a.ema_latency_ns < b.ema_latency_ns;
            }
        }.lessThan);

        return items;
    }

    /// Select N fastest peers, optionally excluding one
    pub fn selectFastestPeers(
        self: *PeerLatencyTracker,
        count: usize,
        exclude_id: ?[32]u8,
        allocator: std.mem.Allocator,
    ) ![][32]u8 {
        const ranked = try self.rankByLatency(allocator);
        defer allocator.free(ranked);

        var result = std.ArrayListUnmanaged([32]u8){};
        for (ranked) |score| {
            if (result.items.len >= count) break;
            if (exclude_id) |excl| {
                if (std.mem.eql(u8, &score.node_id, &excl)) continue;
            }
            try result.append(allocator, score.node_id);
        }

        return result.toOwnedSlice(allocator);
    }

    /// Get stats
    pub fn getStats(self: *PeerLatencyTracker) LatencyStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var slow_count: u32 = 0;
        var total_latency: u128 = 0;
        var count: u32 = 0;
        var iter = self.entries.valueIterator();
        while (iter.next()) |entry| {
            count += 1;
            total_latency += entry.avg_latency_ns;
            if (entry.avg_latency_ns > self.config.slow_threshold_ns) {
                slow_count += 1;
            }
        }

        return .{
            .total_samples = self.total_samples,
            .peers_tracked = count,
            .slow_peers = slow_count,
            .avg_network_latency_ns = if (count > 0) @intCast(total_latency / count) else 0,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "record and retrieve latency" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.init(allocator);
    defer tracker.deinit();

    const node = [_]u8{0x01} ** 32;

    tracker.recordLatency(node, 100_000); // 100us
    tracker.recordLatency(node, 200_000); // 200us
    tracker.recordLatency(node, 300_000); // 300us

    const score = tracker.getScore(node);
    try std.testing.expectEqual(@as(u64, 3), score.sample_count);
    try std.testing.expect(score.avg_latency_ns > 0);
    try std.testing.expect(!score.is_slow);
}

test "slow peer detection" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.initWithConfig(allocator, .{
        .max_samples = 100,
        .slow_threshold_ns = 1_000_000, // 1ms
        .ema_alpha = 0.3,
    });
    defer tracker.deinit();

    const fast_node = [_]u8{0x01} ** 32;
    const slow_node = [_]u8{0x02} ** 32;

    tracker.recordLatency(fast_node, 500_000); // 500us - fast
    tracker.recordLatency(slow_node, 5_000_000); // 5ms - slow

    const fast_score = tracker.getScore(fast_node);
    const slow_score = tracker.getScore(slow_node);

    try std.testing.expect(!fast_score.is_slow);
    try std.testing.expect(slow_score.is_slow);
}

test "rank by latency returns fastest first" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.init(allocator);
    defer tracker.deinit();

    var node_ids: [5][32]u8 = undefined;
    const latencies = [_]u64{ 300_000, 100_000, 500_000, 50_000, 200_000 };

    for (0..5) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
        tracker.recordLatency(node_ids[i], latencies[i]);
    }

    const ranked = try tracker.rankByLatency(allocator);
    defer allocator.free(ranked);

    try std.testing.expectEqual(@as(usize, 5), ranked.len);
    // Fastest should be node 3 (50_000ns)
    try std.testing.expectEqualSlices(u8, &node_ids[3], &ranked[0].node_id);
    // Second fastest: node 1 (100_000ns)
    try std.testing.expectEqualSlices(u8, &node_ids[1], &ranked[1].node_id);
}

test "select fastest peers with exclusion" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.init(allocator);
    defer tracker.deinit();

    var node_ids: [4][32]u8 = undefined;
    const latencies = [_]u64{ 100_000, 200_000, 300_000, 400_000 };

    for (0..4) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
        tracker.recordLatency(node_ids[i], latencies[i]);
    }

    // Select top 2, excluding fastest (node 0)
    const peers = try tracker.selectFastestPeers(2, node_ids[0], allocator);
    defer allocator.free(peers);

    try std.testing.expectEqual(@as(usize, 2), peers.len);
    // Should be node 1 and node 2 (fastest after excluding node 0)
    try std.testing.expectEqualSlices(u8, &node_ids[1], &peers[0]);
    try std.testing.expectEqualSlices(u8, &node_ids[2], &peers[1]);
}

test "EMA tracks recent latency changes" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.initWithConfig(allocator, .{
        .max_samples = 100,
        .slow_threshold_ns = 1_000_000_000,
        .ema_alpha = 0.5, // High alpha = fast adaptation
    });
    defer tracker.deinit();

    const node = [_]u8{0x01} ** 32;

    // Start with fast latency
    for (0..10) |_| tracker.recordLatency(node, 100_000);

    const fast_ema = tracker.getScore(node).ema_latency_ns;

    // Suddenly slow
    for (0..10) |_| tracker.recordLatency(node, 10_000_000);

    const slow_ema = tracker.getScore(node).ema_latency_ns;

    // EMA should have increased significantly
    try std.testing.expect(slow_ema > fast_ema * 2.0);
}

test "unknown peer returns zero score" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.init(allocator);
    defer tracker.deinit();

    const unknown = [_]u8{0xFF} ** 32;
    const score = tracker.getScore(unknown);
    try std.testing.expectEqual(@as(u64, 0), score.sample_count);
    try std.testing.expectEqual(@as(u64, 0), score.avg_latency_ns);
}

test "latency stats" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.initWithConfig(allocator, .{
        .max_samples = 100,
        .slow_threshold_ns = 1_000_000,
        .ema_alpha = 0.3,
    });
    defer tracker.deinit();

    var node_ids: [3][32]u8 = undefined;
    for (0..3) |i| {
        @memset(&node_ids[i], @intCast(i + 1));
    }

    // Node 0: fast, Node 1: fast, Node 2: slow
    tracker.recordLatency(node_ids[0], 500_000);
    tracker.recordLatency(node_ids[1], 800_000);
    tracker.recordLatency(node_ids[2], 5_000_000);

    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.total_samples);
    try std.testing.expectEqual(@as(u32, 3), stats.peers_tracked);
    try std.testing.expectEqual(@as(u32, 1), stats.slow_peers);
    try std.testing.expect(stats.avg_network_latency_ns > 0);
}

test "multiple samples improve accuracy" {
    const allocator = std.testing.allocator;

    var tracker = PeerLatencyTracker.init(allocator);
    defer tracker.deinit();

    const node = [_]u8{0x01} ** 32;

    // Record varied latencies
    tracker.recordLatency(node, 100_000);
    tracker.recordLatency(node, 200_000);
    tracker.recordLatency(node, 150_000);
    tracker.recordLatency(node, 180_000);
    tracker.recordLatency(node, 120_000);

    const score = tracker.getScore(node);
    try std.testing.expectEqual(@as(u64, 5), score.sample_count);
    // Average should be around 150_000
    try std.testing.expect(score.avg_latency_ns >= 100_000);
    try std.testing.expect(score.avg_latency_ns <= 200_000);
}
