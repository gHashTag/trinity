// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NODE REPUTATION v1.7 - Composite Score + Time-Weighted Decay
// Weighted score: PoS pass rate (40%) + Uptime (30%) + Bandwidth (30%)
// v1.7: Reputation decay — stale scores fade over time (half-life model)
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// REPUTATION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReputationWeights = struct {
    pos_weight: f64 = 0.4,
    uptime_weight: f64 = 0.3,
    bandwidth_weight: f64 = 0.3,
};

pub const NodeReputationEntry = struct {
    pos_passed: u64,
    pos_total: u64,
    uptime_secs: u64,
    window_secs: u64,
    bandwidth_bytes: u64,
    // v1.7: Timestamp of last activity (for decay calculation)
    last_activity_ts: i64 = 0,
};

pub const ReputationScore = struct {
    node_id: [32]u8,
    score: f64, // 0.0 to 1.0
    pos_score: f64,
    uptime_score: f64,
    bandwidth_score: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE REPUTATION SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeReputationSystem = struct {
    allocator: std.mem.Allocator,
    entries: std.AutoHashMap([32]u8, NodeReputationEntry),
    weights: ReputationWeights,
    max_bandwidth_bytes: u64, // Normalization reference for bandwidth score
    mutex: std.Thread.Mutex,
    // v1.7: Decay configuration
    decay_enabled: bool,
    decay_half_life_secs: i64, // Half-life in seconds (default 24h = 86400)

    pub fn init(allocator: std.mem.Allocator) NodeReputationSystem {
        return .{
            .allocator = allocator,
            .entries = std.AutoHashMap([32]u8, NodeReputationEntry).init(allocator),
            .weights = .{},
            .max_bandwidth_bytes = 1, // Avoid division by zero
            .mutex = .{},
            .decay_enabled = false,
            .decay_half_life_secs = 86400, // 24 hours default
        };
    }

    pub fn deinit(self: *NodeReputationSystem) void {
        self.entries.deinit();
    }

    /// Record a Proof-of-Storage result for a node
    pub fn recordPosResult(self: *NodeReputationSystem, node_id: [32]u8, passed: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.entries.getOrPut(node_id) catch return;
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .pos_passed = 0,
                .pos_total = 0,
                .uptime_secs = 0,
                .window_secs = 0,
                .bandwidth_bytes = 0,
            };
        }
        result.value_ptr.pos_total += 1;
        if (passed) result.value_ptr.pos_passed += 1;
        result.value_ptr.last_activity_ts = std.time.timestamp();
    }

    /// Record uptime for a node
    pub fn recordUptime(self: *NodeReputationSystem, node_id: [32]u8, uptime_secs: u64, window_secs: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.entries.getOrPut(node_id) catch return;
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .pos_passed = 0,
                .pos_total = 0,
                .uptime_secs = 0,
                .window_secs = 0,
                .bandwidth_bytes = 0,
            };
        }
        result.value_ptr.uptime_secs = uptime_secs;
        result.value_ptr.window_secs = window_secs;
        result.value_ptr.last_activity_ts = std.time.timestamp();
    }

    /// Record bandwidth contribution for a node
    pub fn recordBandwidth(self: *NodeReputationSystem, node_id: [32]u8, bytes: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.entries.getOrPut(node_id) catch return;
        if (!result.found_existing) {
            result.value_ptr.* = .{
                .pos_passed = 0,
                .pos_total = 0,
                .uptime_secs = 0,
                .window_secs = 0,
                .bandwidth_bytes = 0,
            };
        }
        result.value_ptr.bandwidth_bytes += bytes;
        if (result.value_ptr.bandwidth_bytes > self.max_bandwidth_bytes) {
            self.max_bandwidth_bytes = result.value_ptr.bandwidth_bytes;
        }
        result.value_ptr.last_activity_ts = std.time.timestamp();
    }

    /// Get the composite reputation score for a node
    pub fn getScore(self: *NodeReputationSystem, node_id: [32]u8) ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.getScoreUnlocked(node_id);
    }

    fn getScoreUnlocked(self: *NodeReputationSystem, node_id: [32]u8) ReputationScore {
        const entry = self.entries.get(node_id) orelse return .{
            .node_id = node_id,
            .score = 0.0,
            .pos_score = 0.0,
            .uptime_score = 0.0,
            .bandwidth_score = 0.0,
        };

        const pos_score: f64 = if (entry.pos_total > 0)
            @as(f64, @floatFromInt(entry.pos_passed)) / @as(f64, @floatFromInt(entry.pos_total))
        else
            0.0;

        const uptime_score: f64 = if (entry.window_secs > 0)
            @as(f64, @floatFromInt(entry.uptime_secs)) / @as(f64, @floatFromInt(entry.window_secs))
        else
            0.0;

        const bandwidth_score: f64 = @as(f64, @floatFromInt(entry.bandwidth_bytes)) / @as(f64, @floatFromInt(self.max_bandwidth_bytes));

        var composite = pos_score * self.weights.pos_weight +
            uptime_score * self.weights.uptime_weight +
            bandwidth_score * self.weights.bandwidth_weight;

        // v1.7: Apply decay factor based on time since last activity
        if (self.decay_enabled and entry.last_activity_ts > 0 and self.decay_half_life_secs > 0) {
            const now = std.time.timestamp();
            const elapsed = now - entry.last_activity_ts;
            if (elapsed > 0) {
                // Exponential decay: score * 0.5^(elapsed / half_life)
                // Using: 0.5^x = e^(x * ln(0.5)) = e^(-0.693 * x)
                const elapsed_f: f64 = @floatFromInt(elapsed);
                const half_life_f: f64 = @floatFromInt(self.decay_half_life_secs);
                const decay = @exp(-0.693147 * elapsed_f / half_life_f);
                composite *= decay;
            }
        }

        return .{
            .node_id = node_id,
            .score = composite,
            .pos_score = pos_score,
            .uptime_score = uptime_score,
            .bandwidth_score = bandwidth_score,
        };
    }

    /// v1.7: Enable reputation decay with configurable half-life
    pub fn enableDecay(self: *NodeReputationSystem, half_life_secs: i64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.decay_enabled = true;
        self.decay_half_life_secs = half_life_secs;
    }

    /// v1.7: Disable reputation decay
    pub fn disableDecay(self: *NodeReputationSystem) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.decay_enabled = false;
    }

    /// v1.7: Get decay-adjusted score for a node at a specific timestamp
    pub fn getScoreAtTime(self: *NodeReputationSystem, node_id: [32]u8, at_timestamp: i64) ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.entries.get(node_id) orelse return .{
            .node_id = node_id,
            .score = 0.0,
            .pos_score = 0.0,
            .uptime_score = 0.0,
            .bandwidth_score = 0.0,
        };

        const pos_score: f64 = if (entry.pos_total > 0)
            @as(f64, @floatFromInt(entry.pos_passed)) / @as(f64, @floatFromInt(entry.pos_total))
        else
            0.0;

        const uptime_score: f64 = if (entry.window_secs > 0)
            @as(f64, @floatFromInt(entry.uptime_secs)) / @as(f64, @floatFromInt(entry.window_secs))
        else
            0.0;

        const bandwidth_score: f64 = @as(f64, @floatFromInt(entry.bandwidth_bytes)) / @as(f64, @floatFromInt(self.max_bandwidth_bytes));

        var composite = pos_score * self.weights.pos_weight +
            uptime_score * self.weights.uptime_weight +
            bandwidth_score * self.weights.bandwidth_weight;

        if (self.decay_enabled and entry.last_activity_ts > 0 and self.decay_half_life_secs > 0) {
            const elapsed = at_timestamp - entry.last_activity_ts;
            if (elapsed > 0) {
                const elapsed_f: f64 = @floatFromInt(elapsed);
                const half_life_f: f64 = @floatFromInt(self.decay_half_life_secs);
                const decay = @exp(-0.693147 * elapsed_f / half_life_f);
                composite *= decay;
            }
        }

        return .{
            .node_id = node_id,
            .score = composite,
            .pos_score = pos_score,
            .uptime_score = uptime_score,
            .bandwidth_score = bandwidth_score,
        };
    }

    /// Rank all known nodes by composite score (descending)
    pub fn rankNodes(self: *NodeReputationSystem, allocator: std.mem.Allocator) ![]ReputationScore {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = std.ArrayListUnmanaged(ReputationScore){};
        errdefer result.deinit(allocator);

        var iter = self.entries.keyIterator();
        while (iter.next()) |key| {
            try result.append(allocator, self.getScoreUnlocked(key.*));
        }

        // Sort descending by score
        std.mem.sort(ReputationScore, result.items, {}, struct {
            fn cmp(_: void, a: ReputationScore, b: ReputationScore) bool {
                return a.score > b.score;
            }
        }.cmp);

        return result.toOwnedSlice(allocator);
    }

    /// Select the best N peers by reputation, excluding specified node
    pub fn selectBestPeers(
        self: *NodeReputationSystem,
        count: u32,
        exclude: [32]u8,
        allocator: std.mem.Allocator,
    ) ![][32]u8 {
        const ranked = try self.rankNodes(allocator);
        defer allocator.free(ranked);

        var result = std.ArrayListUnmanaged([32]u8){};
        errdefer result.deinit(allocator);

        for (ranked) |entry| {
            if (result.items.len >= count) break;
            if (std.mem.eql(u8, &entry.node_id, &exclude)) continue;
            try result.append(allocator, entry.node_id);
        }

        return result.toOwnedSlice(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "unknown node returns zero score" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const unknown = [_]u8{0xAA} ** 32;
    const score = system.getScore(unknown);
    try std.testing.expectEqual(@as(f64, 0.0), score.score);
}

test "perfect PoS gives 0.4 score (40% weight)" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x01} ** 32;
    // 10/10 PoS passes
    for (0..10) |_| {
        system.recordPosResult(node, true);
    }

    const score = system.getScore(node);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), score.score, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), score.pos_score, 0.001);
}

test "mixed PoS 7/10 gives correct score" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x02} ** 32;
    for (0..10) |i| {
        system.recordPosResult(node, i < 7); // 7 pass, 3 fail
    }

    const score = system.getScore(node);
    // pos_score = 0.7, weighted = 0.7 * 0.4 = 0.28
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), score.pos_score, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.28), score.score, 0.001);
}

test "uptime fraction contributes correctly" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x03} ** 32;
    system.recordUptime(node, 3600, 7200); // 50% uptime

    const score = system.getScore(node);
    // uptime_score = 0.5, weighted = 0.5 * 0.3 = 0.15
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), score.uptime_score, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.15), score.score, 0.001);
}

test "rankNodes returns sorted descending" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node_a = [_]u8{0x01} ** 32;
    const node_b = [_]u8{0x02} ** 32;
    const node_c = [_]u8{0x03} ** 32;

    // node_a: 10/10 PoS (best)
    for (0..10) |_| system.recordPosResult(node_a, true);

    // node_b: 5/10 PoS (middle)
    for (0..10) |i| system.recordPosResult(node_b, i < 5);

    // node_c: 2/10 PoS (worst)
    for (0..10) |i| system.recordPosResult(node_c, i < 2);

    const ranked = try system.rankNodes(allocator);
    defer allocator.free(ranked);

    try std.testing.expectEqual(@as(usize, 3), ranked.len);
    try std.testing.expectEqualSlices(u8, &node_a, &ranked[0].node_id);
    try std.testing.expectEqualSlices(u8, &node_b, &ranked[1].node_id);
    try std.testing.expectEqualSlices(u8, &node_c, &ranked[2].node_id);
    try std.testing.expect(ranked[0].score >= ranked[1].score);
    try std.testing.expect(ranked[1].score >= ranked[2].score);
}

test "selectBestPeers excludes specified node" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node_a = [_]u8{0x01} ** 32;
    const node_b = [_]u8{0x02} ** 32;
    const node_c = [_]u8{0x03} ** 32;

    for (0..10) |_| system.recordPosResult(node_a, true);
    for (0..10) |_| system.recordPosResult(node_b, true);
    for (0..10) |_| system.recordPosResult(node_c, true);

    // Select 2 best, excluding node_a
    const peers = try system.selectBestPeers(2, node_a, allocator);
    defer allocator.free(peers);

    try std.testing.expectEqual(@as(usize, 2), peers.len);
    // node_a should not be in results
    for (peers) |peer| {
        try std.testing.expect(!std.mem.eql(u8, &peer, &node_a));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.7 TESTS - Reputation Decay
// ═══════════════════════════════════════════════════════════════════════════════

test "v1.7: decay disabled gives same score as v1.6" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    // Decay disabled by default
    try std.testing.expect(!system.decay_enabled);

    const node = [_]u8{0x01} ** 32;
    for (0..10) |_| system.recordPosResult(node, true);

    const score = system.getScore(node);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), score.score, 0.001);
}

test "v1.7: decay halves score after one half-life" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x01} ** 32;
    for (0..10) |_| system.recordPosResult(node, true);
    system.recordUptime(node, 3600, 3600); // 100% uptime
    system.recordBandwidth(node, 1024 * 1024); // 1 MB

    // Get undecayed score
    const undecayed = system.getScore(node);

    // Enable decay with 1-hour half-life
    system.enableDecay(3600);

    // Manually set last_activity_ts to 1 hour ago
    if (system.entries.getPtr(node)) |entry| {
        entry.last_activity_ts = std.time.timestamp() - 3600;
    }

    const decayed = system.getScore(node);

    // Score should be approximately half after one half-life
    try std.testing.expectApproxEqAbs(undecayed.score * 0.5, decayed.score, 0.02);
}

test "v1.7: decay disabled after enable restores original score" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x01} ** 32;
    for (0..10) |_| system.recordPosResult(node, true);

    const original = system.getScore(node);

    // Enable decay, then disable
    system.enableDecay(3600);
    system.disableDecay();

    const restored = system.getScore(node);
    try std.testing.expectApproxEqAbs(original.score, restored.score, 0.001);
}

test "v1.7: getScoreAtTime with future timestamp shows more decay" {
    const allocator = std.testing.allocator;

    var system = NodeReputationSystem.init(allocator);
    defer system.deinit();

    const node = [_]u8{0x01} ** 32;
    for (0..10) |_| system.recordPosResult(node, true);
    system.recordUptime(node, 3600, 3600);

    system.enableDecay(3600); // 1-hour half-life

    const now = std.time.timestamp();

    // Set last_activity to now
    if (system.entries.getPtr(node)) |entry| {
        entry.last_activity_ts = now;
    }

    const score_now = system.getScoreAtTime(node, now);
    const score_1h = system.getScoreAtTime(node, now + 3600);
    const score_2h = system.getScoreAtTime(node, now + 7200);

    // Score decreases over time
    try std.testing.expect(score_now.score > score_1h.score);
    try std.testing.expect(score_1h.score > score_2h.score);

    // After 1 half-life, ~50% remains
    try std.testing.expectApproxEqAbs(score_now.score * 0.5, score_1h.score, 0.02);

    // After 2 half-lives, ~25% remains
    try std.testing.expectApproxEqAbs(score_now.score * 0.25, score_2h.score, 0.02);
}
