// Trinity Storage Network v2.2 — Dynamic Erasure Coding
// Adaptive RS(k,m) parameters based on real-time network health
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");
const network_stats_mod = @import("network_stats.zig");

/// Health classification for the network
pub const HealthLevel = enum(u8) {
    excellent, // All metrics green — minimal parity
    good, // Minor degradation — standard parity
    degraded, // Notable issues — elevated parity
    critical, // Serious problems — maximum parity

    pub fn label(self: HealthLevel) []const u8 {
        return switch (self) {
            .excellent => "EXCELLENT",
            .good => "GOOD",
            .degraded => "DEGRADED",
            .critical => "CRITICAL",
        };
    }
};

/// Why a particular RS(k,m) was chosen
pub const AdaptiveReason = enum(u8) {
    default_healthy, // Network healthy, using baseline
    pos_failure_elevated, // PoS failures above threshold
    corruption_detected, // Scrub found corrupted shards
    reputation_low, // Average reputation below threshold
    storage_pressure, // Storage nearly full — reduce parity
    churn_detected, // High rebalance activity
    node_count_low, // Too few nodes for high redundancy
    combined_degradation, // Multiple factors degraded
};

/// Recommended RS parameters from the adaptive engine
pub const ErasureRecommendation = struct {
    data_shards: u32, // k
    parity_shards: u32, // m
    parity_ratio: f64, // m / k
    health_level: HealthLevel,
    reason: AdaptiveReason,
    confidence: f64, // 0.0–1.0 how confident in recommendation
    health_score: f64, // 0.0–1.0 composite network health
};

/// Configuration for dynamic erasure policies
pub const DynamicErasureConfig = struct {
    // Baseline RS parameters (used when network is healthy)
    baseline_parity_ratio: f64 = 0.5, // default: 50% parity (e.g., RS(4,2))

    // Parity ratio bounds
    min_parity_ratio: f64 = 0.25, // minimum: 25% parity (storage-pressure mode)
    max_parity_ratio: f64 = 1.0, // maximum: 100% parity (e.g., RS(4,4) for critical)

    // PoS failure thresholds
    pos_failure_threshold_good: f64 = 0.05, // <5% failures = good
    pos_failure_threshold_degraded: f64 = 0.15, // <15% failures = degraded
    // >= 15% = critical

    // Corruption rate thresholds
    corruption_threshold_good: f64 = 0.01, // <1% corruptions = good
    corruption_threshold_degraded: f64 = 0.05, // <5% corruptions = degraded

    // Reputation thresholds
    reputation_threshold_good: f64 = 0.80, // avg rep >0.8 = good
    reputation_threshold_degraded: f64 = 0.60, // avg rep >0.6 = degraded

    // Storage utilization thresholds
    storage_pressure_threshold: f64 = 0.90, // >90% used = pressure
    storage_critical_threshold: f64 = 0.95, // >95% used = critical pressure

    // Churn detection (rebalances per node)
    churn_threshold_good: f64 = 1.0, // <1 rebalance/node = stable
    churn_threshold_degraded: f64 = 5.0, // <5 rebalances/node = moderate

    // Minimum node count for meaningful RS
    min_nodes_for_rs: u32 = 3,

    // Health score weights (must sum to 1.0)
    weight_pos: f64 = 0.30,
    weight_corruption: f64 = 0.25,
    weight_reputation: f64 = 0.25,
    weight_churn: f64 = 0.10,
    weight_storage: f64 = 0.10,
};

/// Intermediate health metrics computed from raw network report
pub const HealthMetrics = struct {
    pos_failure_rate: f64,
    corruption_rate: f64,
    avg_reputation: f64,
    storage_utilization: f64,
    churn_rate: f64, // rebalances per node
    node_count: u32,
};

/// Statistics tracked by the dynamic erasure engine
pub const DynamicErasureStats = struct {
    total_recommendations: u64,
    excellent_count: u64,
    good_count: u64,
    degraded_count: u64,
    critical_count: u64,
    avg_parity_ratio: f64,
    avg_health_score: f64,
    min_health_score: f64,
    max_health_score: f64,
    ratio_sum: f64,
    health_sum: f64,
};

/// Dynamic Erasure Coding Engine
/// Monitors network health and recommends adaptive RS(k,m) parameters
pub const DynamicErasureEngine = struct {
    config: DynamicErasureConfig,
    stats: DynamicErasureStats,

    const Self = @This();

    pub fn init(config: DynamicErasureConfig) Self {
        return .{
            .config = config,
            .stats = .{
                .total_recommendations = 0,
                .excellent_count = 0,
                .good_count = 0,
                .degraded_count = 0,
                .critical_count = 0,
                .avg_parity_ratio = 0,
                .avg_health_score = 0,
                .min_health_score = 1.0,
                .max_health_score = 0.0,
                .ratio_sum = 0,
                .health_sum = 0,
            },
        };
    }

    /// Extract health metrics from a raw NetworkHealthReport
    pub fn computeHealthMetrics(self: *const Self, report: network_stats_mod.NetworkHealthReport) HealthMetrics {
        _ = self;
        // PoS failure rate
        const pos_total = report.pos_challenges_issued;
        const pos_failure_rate: f64 = if (pos_total > 0)
            @as(f64, @floatFromInt(report.pos_challenges_failed)) / @as(f64, @floatFromInt(pos_total))
        else
            0.0;

        // Corruption rate
        const scrub_total = report.scrub_total;
        const corruption_rate: f64 = if (scrub_total > 0)
            @as(f64, @floatFromInt(report.scrub_corruptions)) / @as(f64, @floatFromInt(scrub_total))
        else
            0.0;

        // Storage utilization
        const storage_utilization: f64 = if (report.total_bytes_available > 0)
            @as(f64, @floatFromInt(report.total_bytes_used)) / @as(f64, @floatFromInt(report.total_bytes_available))
        else
            0.0;

        // Churn rate (rebalances per node)
        const churn_rate: f64 = if (report.node_count > 0)
            @as(f64, @floatFromInt(report.shards_rebalanced)) / @as(f64, @floatFromInt(report.node_count))
        else
            0.0;

        return .{
            .pos_failure_rate = pos_failure_rate,
            .corruption_rate = corruption_rate,
            .avg_reputation = report.reputation_avg,
            .storage_utilization = storage_utilization,
            .churn_rate = churn_rate,
            .node_count = report.node_count,
        };
    }

    /// Compute composite health score (0.0 = critical, 1.0 = excellent)
    pub fn computeHealthScore(self: *const Self, metrics: HealthMetrics) f64 {
        const cfg = self.config;

        // PoS health (1.0 = no failures, 0.0 = 100% failures)
        const pos_health = 1.0 - @min(metrics.pos_failure_rate / cfg.pos_failure_threshold_degraded, 1.0);

        // Corruption health
        const corruption_health = 1.0 - @min(metrics.corruption_rate / cfg.corruption_threshold_degraded, 1.0);

        // Reputation health (normalize to 0-1 range using thresholds)
        const rep_health = @min(@max((metrics.avg_reputation - cfg.reputation_threshold_degraded) / (1.0 - cfg.reputation_threshold_degraded), 0.0), 1.0);

        // Churn health (inverse — high churn = low health)
        const churn_health = 1.0 - @min(metrics.churn_rate / cfg.churn_threshold_degraded, 1.0);

        // Storage health (inverse — high utilization = low health)
        const storage_health = 1.0 - @min(metrics.storage_utilization / cfg.storage_critical_threshold, 1.0);

        // Weighted composite
        const score = pos_health * cfg.weight_pos +
            corruption_health * cfg.weight_corruption +
            rep_health * cfg.weight_reputation +
            churn_health * cfg.weight_churn +
            storage_health * cfg.weight_storage;

        return @min(@max(score, 0.0), 1.0);
    }

    /// Classify health score into a level
    pub fn classifyHealth(self: *const Self, health_score: f64) HealthLevel {
        _ = self;
        if (health_score >= 0.85) return .excellent;
        if (health_score >= 0.65) return .good;
        if (health_score >= 0.40) return .degraded;
        return .critical;
    }

    /// Determine the primary reason for the recommendation
    pub fn determineReason(self: *const Self, metrics: HealthMetrics) AdaptiveReason {
        const cfg = self.config;

        // Count how many factors are degraded
        var degraded_count: u32 = 0;

        if (metrics.pos_failure_rate >= cfg.pos_failure_threshold_good) degraded_count += 1;
        if (metrics.corruption_rate >= cfg.corruption_threshold_good) degraded_count += 1;
        if (metrics.avg_reputation < cfg.reputation_threshold_good) degraded_count += 1;
        if (metrics.churn_rate >= cfg.churn_threshold_good) degraded_count += 1;

        if (degraded_count >= 3) return .combined_degradation;

        // Find the worst single factor
        if (metrics.node_count < cfg.min_nodes_for_rs) return .node_count_low;
        if (metrics.storage_utilization >= cfg.storage_pressure_threshold) return .storage_pressure;
        if (metrics.pos_failure_rate >= cfg.pos_failure_threshold_good) return .pos_failure_elevated;
        if (metrics.corruption_rate >= cfg.corruption_threshold_good) return .corruption_detected;
        if (metrics.avg_reputation < cfg.reputation_threshold_good) return .reputation_low;
        if (metrics.churn_rate >= cfg.churn_threshold_good) return .churn_detected;

        return .default_healthy;
    }

    /// Compute adaptive parity ratio based on health level and metrics
    pub fn computeParityRatio(self: *const Self, health_level: HealthLevel, metrics: HealthMetrics) f64 {
        const cfg = self.config;

        // Storage pressure overrides — reduce parity to save space
        if (metrics.storage_utilization >= cfg.storage_critical_threshold) {
            return cfg.min_parity_ratio;
        }

        // Base ratio depends on health level
        var ratio: f64 = switch (health_level) {
            .excellent => cfg.baseline_parity_ratio * 0.75, // 25% less parity
            .good => cfg.baseline_parity_ratio, // standard
            .degraded => cfg.baseline_parity_ratio * 1.5, // 50% more parity
            .critical => cfg.max_parity_ratio, // maximum parity
        };

        // Additional adjustment: if PoS failures are very high, add more
        if (metrics.pos_failure_rate >= cfg.pos_failure_threshold_degraded) {
            ratio = @min(ratio * 1.25, cfg.max_parity_ratio);
        }

        // Clamp to bounds
        return @min(@max(ratio, cfg.min_parity_ratio), cfg.max_parity_ratio);
    }

    /// Compute confidence in the recommendation (more data = higher confidence)
    pub fn computeConfidence(self: *const Self, report: network_stats_mod.NetworkHealthReport) f64 {
        _ = self;
        var confidence: f64 = 0.0;

        // More PoS challenges = more confident in failure rate
        if (report.pos_challenges_issued >= 100) {
            confidence += 0.3;
        } else if (report.pos_challenges_issued >= 10) {
            confidence += 0.15;
        }

        // More scrubs = more confident in corruption rate
        if (report.scrub_total >= 100) {
            confidence += 0.3;
        } else if (report.scrub_total >= 10) {
            confidence += 0.15;
        }

        // More nodes = more confident in reputation stats
        if (report.node_count >= 50) {
            confidence += 0.2;
        } else if (report.node_count >= 10) {
            confidence += 0.1;
        }

        // Having reputation data
        if (report.reputation_avg > 0) {
            confidence += 0.2;
        }

        return @min(confidence, 1.0);
    }

    /// Main entry point: recommend RS parameters for new file storage
    pub fn recommend(self: *Self, report: network_stats_mod.NetworkHealthReport, data_shards: u32) ErasureRecommendation {
        const metrics = self.computeHealthMetrics(report);
        const health_score = self.computeHealthScore(metrics);
        const health_level = self.classifyHealth(health_score);
        const reason = self.determineReason(metrics);
        const parity_ratio = self.computeParityRatio(health_level, metrics);
        const confidence = self.computeConfidence(report);

        // Compute actual parity shard count from ratio
        const parity_f: f64 = @as(f64, @floatFromInt(data_shards)) * parity_ratio;
        const parity_shards: u32 = @max(1, @as(u32, @intFromFloat(@ceil(parity_f))));

        // Update statistics
        self.stats.total_recommendations += 1;
        self.stats.ratio_sum += parity_ratio;
        self.stats.health_sum += health_score;
        self.stats.avg_parity_ratio = self.stats.ratio_sum / @as(f64, @floatFromInt(self.stats.total_recommendations));
        self.stats.avg_health_score = self.stats.health_sum / @as(f64, @floatFromInt(self.stats.total_recommendations));
        if (health_score < self.stats.min_health_score) self.stats.min_health_score = health_score;
        if (health_score > self.stats.max_health_score) self.stats.max_health_score = health_score;

        switch (health_level) {
            .excellent => self.stats.excellent_count += 1,
            .good => self.stats.good_count += 1,
            .degraded => self.stats.degraded_count += 1,
            .critical => self.stats.critical_count += 1,
        }

        return .{
            .data_shards = data_shards,
            .parity_shards = parity_shards,
            .parity_ratio = parity_ratio,
            .health_level = health_level,
            .reason = reason,
            .confidence = confidence,
            .health_score = health_score,
        };
    }

    /// Recommend based on pre-computed health metrics (for testing/external use)
    pub fn recommendFromMetrics(self: *Self, metrics: HealthMetrics, data_shards: u32) ErasureRecommendation {
        const health_score = self.computeHealthScore(metrics);
        const health_level = self.classifyHealth(health_score);
        const reason = self.determineReason(metrics);
        const parity_ratio = self.computeParityRatio(health_level, metrics);

        const parity_f: f64 = @as(f64, @floatFromInt(data_shards)) * parity_ratio;
        const parity_shards: u32 = @max(1, @as(u32, @intFromFloat(@ceil(parity_f))));

        // Confidence is lower without raw report
        const confidence: f64 = if (metrics.node_count >= 50) 0.5 else 0.3;

        self.stats.total_recommendations += 1;
        self.stats.ratio_sum += parity_ratio;
        self.stats.health_sum += health_score;
        self.stats.avg_parity_ratio = self.stats.ratio_sum / @as(f64, @floatFromInt(self.stats.total_recommendations));
        self.stats.avg_health_score = self.stats.health_sum / @as(f64, @floatFromInt(self.stats.total_recommendations));
        if (health_score < self.stats.min_health_score) self.stats.min_health_score = health_score;
        if (health_score > self.stats.max_health_score) self.stats.max_health_score = health_score;

        switch (health_level) {
            .excellent => self.stats.excellent_count += 1,
            .good => self.stats.good_count += 1,
            .degraded => self.stats.degraded_count += 1,
            .critical => self.stats.critical_count += 1,
        }

        return .{
            .data_shards = data_shards,
            .parity_shards = parity_shards,
            .parity_ratio = parity_ratio,
            .health_level = health_level,
            .reason = reason,
            .confidence = confidence,
            .health_score = health_score,
        };
    }

    pub fn getStats(self: *const Self) DynamicErasureStats {
        return self.stats;
    }
};

// ============================================================
// Unit Tests
// ============================================================

test "dynamic erasure — init default config" {
    var engine = DynamicErasureEngine.init(.{});
    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.total_recommendations);
    try std.testing.expectEqual(@as(f64, 1.0), stats.min_health_score);
    try std.testing.expectEqual(@as(f64, 0.0), stats.max_health_score);
}

test "dynamic erasure — excellent health (all metrics green)" {
    var engine = DynamicErasureEngine.init(.{});

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 100,
        .total_shards = 500,
        .total_bytes_used = 1_000_000,
        .total_bytes_available = 10_000_000,
        .shards_tracked = 500,
        .shards_rebalanced = 10,
        .target_replication = 3,
        .pos_challenges_issued = 1000,
        .pos_challenges_passed = 990,
        .pos_challenges_failed = 10, // 1% — excellent
        .total_upload = 50_000_000,
        .total_download = 100_000_000,
        .scrub_total = 500,
        .scrub_corruptions = 1, // 0.2% — excellent
        .reputation_avg = 0.92, // high
        .reputation_min = 0.70,
        .reputation_max = 0.99,
        .generated_at = 1000000,
    };

    const rec = engine.recommend(report, 8);
    try std.testing.expectEqual(HealthLevel.excellent, rec.health_level);
    try std.testing.expectEqual(AdaptiveReason.default_healthy, rec.reason);
    // Excellent health → 75% of baseline (0.375)
    try std.testing.expect(rec.parity_ratio < 0.5);
    try std.testing.expect(rec.parity_shards >= 1);
    try std.testing.expect(rec.health_score >= 0.85);
    try std.testing.expect(rec.confidence >= 0.5);
}

test "dynamic erasure — good health (minor pos failures)" {
    var engine = DynamicErasureEngine.init(.{});

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 50,
        .total_shards = 200,
        .total_bytes_used = 3_000_000,
        .total_bytes_available = 10_000_000,
        .shards_tracked = 200,
        .shards_rebalanced = 50,
        .target_replication = 3,
        .pos_challenges_issued = 200,
        .pos_challenges_passed = 180,
        .pos_challenges_failed = 20, // 10% — between good/degraded
        .total_upload = 30_000_000,
        .total_download = 60_000_000,
        .scrub_total = 200,
        .scrub_corruptions = 3, // 1.5% — mild
        .reputation_avg = 0.82, // above good threshold
        .reputation_min = 0.50,
        .reputation_max = 0.95,
        .generated_at = 1000000,
    };

    const rec = engine.recommend(report, 8);
    try std.testing.expect(rec.health_level == .good or rec.health_level == .degraded);
    try std.testing.expect(rec.parity_ratio >= 0.25);
    try std.testing.expect(rec.parity_shards >= 1);
}

test "dynamic erasure — degraded health (high corruption)" {
    var engine = DynamicErasureEngine.init(.{});

    const report = network_stats_mod.NetworkHealthReport{
        .node_count = 30,
        .total_shards = 100,
        .total_bytes_used = 5_000_000,
        .total_bytes_available = 10_000_000,
        .shards_tracked = 100,
        .shards_rebalanced = 100,
        .target_replication = 3,
        .pos_challenges_issued = 100,
        .pos_challenges_passed = 85,
        .pos_challenges_failed = 15, // 15% — degraded/critical boundary
        .total_upload = 10_000_000,
        .total_download = 20_000_000,
        .scrub_total = 100,
        .scrub_corruptions = 8, // 8% — degraded
        .reputation_avg = 0.65, // low
        .reputation_min = 0.30,
        .reputation_max = 0.90,
        .generated_at = 1000000,
    };

    const rec = engine.recommend(report, 6);
    try std.testing.expect(rec.health_level == .degraded or rec.health_level == .critical);
    // Degraded/critical → higher parity
    try std.testing.expect(rec.parity_ratio >= 0.5);
    try std.testing.expect(rec.parity_shards >= 3);
}

test "dynamic erasure — critical health (combined degradation)" {
    var engine = DynamicErasureEngine.init(.{});

    const metrics = HealthMetrics{
        .pos_failure_rate = 0.25, // 25% failures
        .corruption_rate = 0.10, // 10% corruption
        .avg_reputation = 0.45, // very low
        .storage_utilization = 0.60,
        .churn_rate = 8.0, // high churn
        .node_count = 20,
    };

    const rec = engine.recommendFromMetrics(metrics, 4);
    try std.testing.expectEqual(HealthLevel.critical, rec.health_level);
    try std.testing.expectEqual(AdaptiveReason.combined_degradation, rec.reason);
    try std.testing.expectEqual(rec.parity_ratio, 1.0); // max parity
    try std.testing.expectEqual(@as(u32, 4), rec.parity_shards); // RS(4,4)
}

test "dynamic erasure — storage pressure reduces parity" {
    var engine = DynamicErasureEngine.init(.{});

    const metrics = HealthMetrics{
        .pos_failure_rate = 0.02,
        .corruption_rate = 0.005,
        .avg_reputation = 0.90,
        .storage_utilization = 0.96, // >95% critical pressure
        .churn_rate = 0.5,
        .node_count = 100,
    };

    const rec = engine.recommendFromMetrics(metrics, 8);
    try std.testing.expectEqual(AdaptiveReason.storage_pressure, rec.reason);
    // Storage pressure → minimum parity ratio
    try std.testing.expectEqual(rec.parity_ratio, 0.25);
    try std.testing.expectEqual(@as(u32, 2), rec.parity_shards); // RS(8,2) = minimum
}

test "dynamic erasure — health score computation" {
    var engine = DynamicErasureEngine.init(.{});

    // Perfect health
    const perfect = HealthMetrics{
        .pos_failure_rate = 0.0,
        .corruption_rate = 0.0,
        .avg_reputation = 1.0,
        .storage_utilization = 0.0,
        .churn_rate = 0.0,
        .node_count = 100,
    };
    const perfect_score = engine.computeHealthScore(perfect);
    try std.testing.expect(perfect_score >= 0.95);

    // Terrible health
    const terrible = HealthMetrics{
        .pos_failure_rate = 0.30,
        .corruption_rate = 0.10,
        .avg_reputation = 0.40,
        .storage_utilization = 0.99,
        .churn_rate = 10.0,
        .node_count = 5,
    };
    const terrible_score = engine.computeHealthScore(terrible);
    try std.testing.expect(terrible_score <= 0.15);

    // Score ordering
    try std.testing.expect(perfect_score > terrible_score);
}

test "dynamic erasure — health classification" {
    const engine = DynamicErasureEngine.init(.{});

    try std.testing.expectEqual(HealthLevel.excellent, engine.classifyHealth(0.90));
    try std.testing.expectEqual(HealthLevel.good, engine.classifyHealth(0.70));
    try std.testing.expectEqual(HealthLevel.degraded, engine.classifyHealth(0.50));
    try std.testing.expectEqual(HealthLevel.critical, engine.classifyHealth(0.20));
}

test "dynamic erasure — stats tracking" {
    var engine = DynamicErasureEngine.init(.{});

    // Excellent recommendation
    const good_metrics = HealthMetrics{
        .pos_failure_rate = 0.01,
        .corruption_rate = 0.001,
        .avg_reputation = 0.95,
        .storage_utilization = 0.30,
        .churn_rate = 0.2,
        .node_count = 100,
    };
    _ = engine.recommendFromMetrics(good_metrics, 8);

    // Critical recommendation
    const bad_metrics = HealthMetrics{
        .pos_failure_rate = 0.25,
        .corruption_rate = 0.10,
        .avg_reputation = 0.40,
        .storage_utilization = 0.50,
        .churn_rate = 8.0,
        .node_count = 20,
    };
    _ = engine.recommendFromMetrics(bad_metrics, 4);

    const stats = engine.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_recommendations);
    try std.testing.expectEqual(@as(u64, 1), stats.excellent_count);
    try std.testing.expectEqual(@as(u64, 1), stats.critical_count);
    try std.testing.expect(stats.min_health_score < stats.max_health_score);
    try std.testing.expect(stats.avg_parity_ratio > 0);
}

test "dynamic erasure — minimum parity always 1" {
    var engine = DynamicErasureEngine.init(.{});

    // Even with excellent health, parity should be at least 1
    const metrics = HealthMetrics{
        .pos_failure_rate = 0.0,
        .corruption_rate = 0.0,
        .avg_reputation = 1.0,
        .storage_utilization = 0.1,
        .churn_rate = 0.0,
        .node_count = 100,
    };

    const rec = engine.recommendFromMetrics(metrics, 1); // 1 data shard
    try std.testing.expect(rec.parity_shards >= 1);
}

test "dynamic erasure — confidence scales with data" {
    var engine = DynamicErasureEngine.init(.{});

    // Low data report
    const low_data = network_stats_mod.NetworkHealthReport{
        .node_count = 3,
        .total_shards = 5,
        .total_bytes_used = 100,
        .total_bytes_available = 1000,
        .shards_tracked = 5,
        .shards_rebalanced = 0,
        .target_replication = 3,
        .pos_challenges_issued = 5,
        .pos_challenges_passed = 5,
        .pos_challenges_failed = 0,
        .total_upload = 1000,
        .total_download = 2000,
        .scrub_total = 2,
        .scrub_corruptions = 0,
        .reputation_avg = 0.90,
        .reputation_min = 0.85,
        .reputation_max = 0.95,
        .generated_at = 1000000,
    };

    const low_rec = engine.recommend(low_data, 4);

    // High data report
    const high_data = network_stats_mod.NetworkHealthReport{
        .node_count = 200,
        .total_shards = 2000,
        .total_bytes_used = 100_000_000,
        .total_bytes_available = 1_000_000_000,
        .shards_tracked = 2000,
        .shards_rebalanced = 50,
        .target_replication = 3,
        .pos_challenges_issued = 5000,
        .pos_challenges_passed = 4950,
        .pos_challenges_failed = 50,
        .total_upload = 50_000_000,
        .total_download = 100_000_000,
        .scrub_total = 1000,
        .scrub_corruptions = 5,
        .reputation_avg = 0.90,
        .reputation_min = 0.70,
        .reputation_max = 0.99,
        .generated_at = 1000000,
    };

    const high_rec = engine.recommend(high_data, 4);

    try std.testing.expect(high_rec.confidence > low_rec.confidence);
}
