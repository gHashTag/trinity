//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN TELEMETRY — v0.2 — Time-series Health Monitoring
//!
//! Tracks brain metrics over time for analysis and alerting.
//! Brain Region: Interosceptive Network (Internal State Monitoring)
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//!
//! # Biological Analogy
//!
//! In the mammalian brain, the interosceptive network (including insular cortex
//! and anterior cingulate) monitors internal bodily signals such as heart rate,
//! temperature, hunger, and hormonal states. This information is continuously
//! aggregated to maintain homeostasis and trigger responses to deviations.
//!
//! The Telemetry module provides similar functionality for the S³AI Brain:
//! - Continuous collection of health metrics (claims, events, health score)
//! - Time-series aggregation for trend analysis
//! - Alert triggering based on threshold violations
//! - Historical data export for post-hoc analysis
//!
//! # Features
//!
//! - Thread-safe metrics collection (mutex-protected)
//! - Configurable max points with automatic FIFO trimming
//! - Average health score over sliding window
//! - Trend detection (improving, stable, declining)
//! - Percentile calculation for distribution analysis
//! - Health range (min/max) for volatility assessment
//! - Per-metric averaging for custom analytics
//! - JSON export for external visualization
//!
//! # Thread Safety
//!
//! - All public methods are thread-safe via mutex
//! - Mutex protects the points ArrayList
//! - Multiple threads can record, query, and export concurrently
//!
//! # Memory Management
//!
//! - Pre-allocation of max_points capacity on init (best effort)
//! - Falls back to dynamic growth if pre-allocation fails
//! - FIFO eviction when max_points exceeded (oldest data dropped)
//!
//! # Performance Characteristics
//!
//! - record(): O(1) amortized, O(n) worst-case when trimming
//! - avgHealth(): O(n) where n = last_n
//! - trend(): O(n) where n = last_n
//! - percentile(): O(n log n) due to sorting, limited to 256 points
//! - exportJson(): O(n)
//!
//! # Usage Example
//!
//! ```zig
//! const allocator = std.testing.allocator;
//! var tel = telemetry.BrainTelemetry.init(allocator, 1000);
//! defer tel.deinit();
//!
//! // Record metrics
//! try tel.record(.{
//!     .timestamp = std.time.nanoTimestamp(),
//!     .active_claims = 5,
//!     .events_published = 1000,
//!     .events_buffered = 10,
//!     .health_score = 92.5,
//! });
//!
//! // Query health
//! const avg_health = tel.avgHealth(100);
//! std.log.info("Average health: {d:.1}", .{avg_health});
//!
//! // Check trend
//! const trend = tel.trend(50);
//! switch (trend) {
//!     .improving => std.log.info("System health improving"),
//!     .stable => std.log.info("System health stable"),
//!     .declining => std.log.info("System health declining - attention needed"),
//! }
//!
//! // Get percentiles
//! const p50 = tel.percentile(50.0, 100); // median
//! const p95 = tel.percentile(95.0, 100); // 95th percentile
//!
//! // Export to JSON
//! var buffer: [4096]u8 = undefined;
//! var fbs = std.io.fixedBufferStream(&buffer);
//! try tel.exportJson(fbs.writer());
//! const json = fbs.getWritten();
//! ```

const std = @import("std");

pub const TelemetryPoint = struct {
    timestamp: i64,
    active_claims: usize,
    events_published: u64,
    events_buffered: usize,
    health_score: f32,
};

pub const BrainTelemetry = struct {
    allocator: std.mem.Allocator,
    points: std.ArrayList(TelemetryPoint),
    max_points: usize,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_points: usize) Self {
        var points: std.ArrayList(TelemetryPoint) = .empty;
        points.ensureTotalCapacity(allocator, max_points) catch |err| {
            std.log.warn("Failed to pre-allocate telemetry points: {}. Will grow dynamically.", .{err});
        };
        return Self{
            .allocator = allocator,
            .points = points,
            .max_points = max_points,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit(self.allocator);
    }

    /// Record a telemetry point
    pub fn record(self: *Self, point: TelemetryPoint) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.points.append(self.allocator, point);

        // Trim if over limit
        while (self.points.items.len > self.max_points) {
            _ = self.points.orderedRemove(0);
        }
    }

    /// Get average health score over last N points
    pub fn avgHealth(self: *Self, last_n: usize) f32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.points.items.len == 0) return 100.0;

        const start = if (last_n >= self.points.items.len) 0 else self.points.items.len - last_n;
        var sum: f32 = 0;
        var n: usize = 0;

        for (self.points.items[start..]) |pt| {
            sum += pt.health_score;
            n += 1;
        }

        return if (n > 0) sum / @as(f32, @floatFromInt(n)) else 100.0;
    }

    /// Get trend direction (improving, stable, declining)
    pub fn trend(self: *Self, last_n: usize) enum { improving, stable, declining } {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.points.items.len < 3) return .stable;

        const start = if (last_n >= self.points.items.len) 0 else self.points.items.len - last_n;
        const slice = self.points.items[start..];

        // Compare first and last thirds
        const third = slice.len / 3;
        if (third < 2) return .stable;

        var early_sum: f32 = 0;
        var late_sum: f32 = 0;

        for (slice[0..third]) |pt| early_sum += pt.health_score;
        for (slice[slice.len - third ..]) |pt| late_sum += pt.health_score;

        const early_avg = early_sum / @as(f32, @floatFromInt(third));
        const late_avg = late_sum / @as(f32, @floatFromInt(third));

        const diff = late_avg - early_avg;
        return if (diff > 5.0) .improving else if (diff < -5.0) .declining else .stable;
    }

    /// Export as JSON
    pub fn exportJson(self: *Self, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.writeAll("{\"telemetry\":[");

        for (self.points.items, 0..) |pt, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{\"ts\":");
            try writer.print("{d}", .{pt.timestamp});
            try writer.writeAll(",\"claims\":");
            try writer.print("{d}", .{pt.active_claims});
            try writer.writeAll(",\"events\":");
            try writer.print("{d}", .{pt.events_published});
            try writer.writeAll(",\"buffered\":");
            try writer.print("{d}", .{pt.events_buffered});
            try writer.writeAll(",\"health\":");
            try writer.print("{d:.1}", .{pt.health_score});
            try writer.writeAll("}");
        }

        try writer.writeAll("]}");
    }

    /// Get percentile of health scores (0-100)
    ///
    /// Returns the p-th percentile of health scores over the last N points.
    /// Uses linear interpolation between adjacent sorted values for accuracy.
    ///
    /// # Parameters
    /// - p: Percentile value in range [0, 100]. Values outside range are clamped.
    /// - last_n: Number of recent points to consider. If > available, uses all.
    ///
    /// # Returns
    /// - The percentile value, or 100.0 for empty data
    /// - Returns 100.0 if >256 points (stack buffer limitation)
    ///
    /// # Performance
    /// - O(n log n) due to sorting, limited to 256 points max
    /// - Uses stack-allocated buffer for sorting (no heap allocation)
    pub fn percentile(self: *Self, p: f32, last_n: usize) f32 {
        // Clamp p to [0, 100] for robustness against invalid input
        const clamped_p = if (p < 0.0) 0.0 else if (p > 100.0) 100.0 else p;

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.points.items.len == 0) return 100.0;

        const start = if (last_n >= self.points.items.len) 0 else self.points.items.len - last_n;
        const slice = self.points.items[start..];

        if (slice.len == 1) return slice[0].health_score;

        // Copy health scores to stack buffer for sorting
        var buffer: [256]f32 = undefined;
        if (slice.len > buffer.len) return 100.0;

        const scores = buffer[0..slice.len];
        for (scores, slice) |*score, pt| score.* = pt.health_score;

        // Simple insertion sort (small arrays)
        for (1..scores.len) |i| {
            const key = scores[i];
            var j = i;
            while (j > 0 and scores[j - 1] > key) : (j -= 1) {
                scores[j] = scores[j - 1];
            }
            scores[j] = key;
        }

        // Linear interpolation for percentile
        // p is in [0, 100], so idx_f is in [0, scores.len - 1]
        const idx_f = @as(f32, @floatFromInt(scores.len - 1)) * (clamped_p / 100.0);
        // Clamp to valid range [0, scores.len - 1] to handle floating point errors
        const clamped_idx_f = @max(0.0, @min(idx_f, @as(f32, @floatFromInt(scores.len - 1))));
        const idx = @as(usize, @intFromFloat(clamped_idx_f));
        const frac = clamped_idx_f - @as(f32, @floatFromInt(idx));

        if (idx + 1 >= scores.len) return scores[scores.len - 1];
        return scores[idx] * (1.0 - frac) + scores[idx + 1] * frac;
    }

    /// Get current point count
    pub fn count(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.points.items.len;
    }

    /// Get latest point (if any)
    pub fn latest(self: *Self) ?TelemetryPoint {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.points.items.len == 0) return null;
        return self.points.items[self.points.items.len - 1];
    }

    /// Get average of a metric over last N points
    ///
    /// Computes the average value of a specific metric field over the last N points.
    ///
    /// # Parameters
    /// - field: One of "active_claims", "events_published", "events_buffered", "health_score"
    /// - last_n: Number of recent points to consider. If > available, uses all.
    ///
    /// # Returns
    /// - The average value, or 0.0 for empty data or invalid field name
    ///
    /// # Note
    /// Invalid field names are silently ignored and return 0.0.
    /// This is by design to avoid panicking from comptime string comparisons.
    pub fn avgMetric(self: *Self, comptime field: []const u8, last_n: usize) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.points.items.len == 0) return 0.0;

        const start = if (last_n >= self.points.items.len) 0 else self.points.items.len - last_n;
        var sum: f64 = 0;
        var n: usize = 0;

        for (self.points.items[start..]) |pt| {
            const value: f64 = if (std.mem.eql(u8, field, "active_claims"))
                @floatFromInt(pt.active_claims)
            else if (std.mem.eql(u8, field, "events_published"))
                @floatFromInt(pt.events_published)
            else if (std.mem.eql(u8, field, "events_buffered"))
                @floatFromInt(pt.events_buffered)
            else if (std.mem.eql(u8, field, "health_score"))
                pt.health_score
            else
                // Invalid field: silently return 0.0
                0.0;
            sum += value;
            n += 1;
        }

        return if (n > 0) sum / @as(f64, @floatFromInt(n)) else 0.0;
    }

    /// Get min/max health scores
    pub fn healthRange(self: *Self, last_n: usize) struct { min: f32, max: f32 } {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.points.items.len == 0) return .{ .min = 100.0, .max = 100.0 };

        const start = if (last_n >= self.points.items.len) 0 else self.points.items.len - last_n;
        const slice = self.points.items[start..];

        var min_val = slice[0].health_score;
        var max_val = slice[0].health_score;

        for (slice[1..]) |pt| {
            if (pt.health_score < min_val) min_val = pt.health_score;
            if (pt.health_score > max_val) max_val = pt.health_score;
        }

        return .{ .min = min_val, .max = max_val };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainTelemetry record and query" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 90.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 3, .events_published = 150, .events_buffered = 5, .health_score = 95.0 });

    const avg = tel.avgHealth(10);
    try std.testing.expectApproxEqAbs(@as(f32, 92.5), avg, 0.1);
}

test "BrainTelemetry trend detection" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Improving trend - need at least 6 points for third=2
    try tel.record(.{ .timestamp = now, .active_claims = 10, .events_published = 100, .events_buffered = 50, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 9, .events_published = 105, .events_buffered = 45, .health_score = 65.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 8, .events_published = 110, .events_buffered = 40, .health_score = 70.0 });
    try tel.record(.{ .timestamp = now + 3, .active_claims = 7, .events_published = 115, .events_buffered = 35, .health_score = 75.0 });
    try tel.record(.{ .timestamp = now + 4, .active_claims = 6, .events_published = 120, .events_buffered = 30, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 5, .active_claims = 5, .events_published = 140, .events_buffered = 10, .health_score = 90.0 });

    const trend = tel.trend(10);
    try std.testing.expect(trend == .improving);
}

test "BrainTelemetry trend: declining" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Declining trend - need at least 6 points
    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 140, .events_buffered = 10, .health_score = 95.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 6, .events_published = 135, .events_buffered = 15, .health_score = 90.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 7, .events_published = 130, .events_buffered = 20, .health_score = 85.0 });
    try tel.record(.{ .timestamp = now + 3, .active_claims = 8, .events_published = 125, .events_buffered = 25, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 4, .active_claims = 9, .events_published = 120, .events_buffered = 30, .health_score = 75.0 });
    try tel.record(.{ .timestamp = now + 5, .active_claims = 10, .events_published = 100, .events_buffered = 50, .health_score = 65.0 });

    const trend = tel.trend(10);
    try std.testing.expect(trend == .declining);
}

test "BrainTelemetry trend: stable" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 5, .events_published = 105, .events_buffered = 12, .health_score = 81.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 5, .events_published = 110, .events_buffered = 11, .health_score = 80.5 });

    const trend = tel.trend(10);
    try std.testing.expect(trend == .stable);
}

test "BrainTelemetry trend: insufficient data" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 3, .events_published = 150, .events_buffered = 5, .health_score = 85.0 });

    // Less than 3 points returns stable
    const trend = tel.trend(10);
    try std.testing.expect(trend == .stable);
}

test "BrainTelemetry avgHealth: empty" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const avg = tel.avgHealth(10);
    try std.testing.expectEqual(@as(f32, 100.0), avg);
}

test "BrainTelemetry avgHealth: last_n respects bound" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 60.0 });

    // last_n=2 should average only last 2: (80+60)/2 = 70
    const avg = tel.avgHealth(2);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), avg, 0.1);
}

test "BrainTelemetry max_points trimming" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 5);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Add 10 points, should keep only last 5
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try tel.record(.{
            .timestamp = now + @as(i64, @intCast(i)),
            .active_claims = i,
            .events_published = @as(u64, @intCast(i)) * 10,
            .events_buffered = i,
            .health_score = @as(f32, @floatFromInt(i)) * 10.0,
        });
    }

    try std.testing.expectEqual(@as(usize, 5), tel.count());

    // First point should be 5 (not 0)
    const latest_opt = tel.latest();
    try std.testing.expect(latest_opt != null);
    try std.testing.expectEqual(@as(usize, 9), latest_opt.?.active_claims);
}

test "BrainTelemetry count and latest" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    try std.testing.expectEqual(@as(usize, 0), tel.count());
    try std.testing.expect(tel.latest() == null);

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 42, .events_published = 100, .events_buffered = 10, .health_score = 88.5 });

    try std.testing.expectEqual(@as(usize, 1), tel.count());
    const latest = tel.latest();
    try std.testing.expect(latest != null);
    try std.testing.expectEqual(@as(usize, 42), latest.?.active_claims);
    try std.testing.expectEqual(@as(f32, 88.5), latest.?.health_score);
}

test "BrainTelemetry percentile: basic" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 50.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });
    try tel.record(.{ .timestamp = now + 3, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 4, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 90.0 });

    // p50 (median) should be around 70
    const p50 = tel.percentile(50.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), p50, 1.0);

    // p90 should be near 90
    const p90 = tel.percentile(90.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 88.0), p90, 2.0);

    // p10 should be near 50
    const p10 = tel.percentile(10.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 52.0), p10, 2.0);
}

test "BrainTelemetry percentile: empty" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const p = tel.percentile(50.0, 10);
    try std.testing.expectEqual(@as(f32, 100.0), p);
}

test "BrainTelemetry percentile: single point" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 75.5 });

    const p = tel.percentile(50.0, 10);
    try std.testing.expectEqual(@as(f32, 75.5), p);
}

test "BrainTelemetry healthRange" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 50.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 95.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });

    const range = tel.healthRange(10);
    try std.testing.expectEqual(@as(f32, 50.0), range.min);
    try std.testing.expectEqual(@as(f32, 95.0), range.max);
}

test "BrainTelemetry healthRange: empty" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const range = tel.healthRange(10);
    try std.testing.expectEqual(@as(f32, 100.0), range.min);
    try std.testing.expectEqual(@as(f32, 100.0), range.max);
}

test "BrainTelemetry avgMetric: active_claims" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 10, .events_published = 100, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 20, .events_published = 100, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 30, .events_published = 100, .events_buffered = 0, .health_score = 100.0 });

    const avg = tel.avgMetric("active_claims", 10);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), avg, 0.01);
}

test "BrainTelemetry avgMetric: events_published" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 0, .events_published = 100, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 0, .events_published = 200, .events_buffered = 0, .health_score = 100.0 });

    const avg = tel.avgMetric("events_published", 10);
    try std.testing.expectApproxEqAbs(@as(f64, 150.0), avg, 0.01);
}

test "BrainTelemetry avgMetric: empty" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const avg = tel.avgMetric("active_claims", 10);
    try std.testing.expectEqual(@as(f64, 0.0), avg);
}

test "BrainTelemetry exportJson" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1234567890;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 90.5 });

    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try tel.exportJson(fbs.writer());

    const output = fbs.getWritten();
    try std.testing.expectEqual(@as(usize, 85), output.len);
    try std.testing.expectEqualStrings("{\"telemetry\":[{\"ts\":1234567890,\"claims\":5,\"events\":100,\"buffered\":10,\"health\":90.5}]}", output);
}

test "BrainTelemetry exportJson: multiple points" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = 1234567890;

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 90.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 3, .events_published = 150, .events_buffered = 5, .health_score = 95.0 });

    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try tel.exportJson(fbs.writer());

    const output = fbs.getWritten();
    try std.testing.expect(output.len > 80);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"claims\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"claims\":3") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS (v0.2 additions)
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainTelemetry percentile: p < 0 clamps to 0" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 50.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });

    // p < 0 should clamp to 0 (minimum value)
    const p = tel.percentile(-10.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), p, 1.0);
}

test "BrainTelemetry percentile: p > 100 clamps to 100" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 50.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });

    // p > 100 should clamp to 100 (maximum value)
    const p = tel.percentile(150.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), p, 1.0);
}

test "BrainTelemetry percentile: p=0 returns minimum" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 40.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 80.0 });

    const p = tel.percentile(0.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), p, 0.1);
}

test "BrainTelemetry percentile: p=100 returns maximum" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 40.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 80.0 });

    const p = tel.percentile(100.0, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), p, 0.1);
}

test "BrainTelemetry percentile: volatile data" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Highly oscillating data
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        const score: f32 = if (i % 2 == 0) 100.0 else 0.0;
        try tel.record(.{ .timestamp = now + @as(i64, @intCast(i)), .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = score });
    }

    const p50 = tel.percentile(50.0, 10);
    // With 5x 100 and 5x 0, median should be around 50
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), p50, 10.0);
}

test "BrainTelemetry trend: exactly 3 points" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Exactly 3 points (edge case for trend detection)
    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 90.0 });

    const trend = tel.trend(10);
    // third = 3/3 = 1, which is < 2, so returns .stable
    // The function requires at least 6 points (third >= 2) for trend detection
    try std.testing.expect(trend == .stable);
}

test "BrainTelemetry trend: oscillating data" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Oscillating data: high-low-high-low
    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        const score: f32 = if (i % 2 == 0) 90.0 else 70.0;
        try tel.record(.{ .timestamp = now + @as(i64, @intCast(i)), .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = score });
    }

    const trend = tel.trend(12);
    // With oscillating data, trend should be stable (no clear direction)
    try std.testing.expect(trend == .stable);
}

test "BrainTelemetry exportJson: empty" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    var buffer: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try tel.exportJson(fbs.writer());

    const output = fbs.getWritten();
    try std.testing.expectEqualStrings("{\"telemetry\":[]}", output);
}

test "BrainTelemetry avgMetric: events_buffered" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 0, .events_published = 0, .events_buffered = 10, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 0, .events_published = 0, .events_buffered = 20, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 0, .events_published = 0, .events_buffered = 30, .health_score = 100.0 });

    const avg = tel.avgMetric("events_buffered", 10);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), avg, 0.01);
}

test "BrainTelemetry avgMetric: health_score" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 0, .events_published = 0, .events_buffered = 0, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 0, .events_published = 0, .events_buffered = 0, .health_score = 90.0 });

    const avg = tel.avgMetric("health_score", 10);
    try std.testing.expectApproxEqAbs(@as(f64, 85.0), avg, 0.01);
}

test "BrainTelemetry avgMetric: respects last_n" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 100, .events_published = 0, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 10, .events_published = 0, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 20, .events_published = 0, .events_buffered = 0, .health_score = 100.0 });

    // last_n=2 should average only last 2: (10+20)/2 = 15
    const avg = tel.avgMetric("active_claims", 2);
    try std.testing.expectApproxEqAbs(@as(f64, 15.0), avg, 0.01);
}

test "BrainTelemetry healthRange: respects last_n" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 10.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 50.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 100.0 });
    try tel.record(.{ .timestamp = now + 3, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 60.0 });
    try tel.record(.{ .timestamp = now + 4, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 70.0 });

    // last_n=2 should only consider last 2 points
    const range = tel.healthRange(2);
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), range.min, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), range.max, 0.1);
}

test "BrainTelemetry record: zero max_points still works" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 0);
    defer tel.deinit();

    const now: i64 = 1000000;

    // Should be able to record even with max_points=0
    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 90.0 });

    // But it will be trimmed immediately, so count should be 0
    try std.testing.expectEqual(@as(usize, 0), tel.count());
}

test "BrainTelemetry latest: returns copy not reference" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 42, .events_published = 100, .events_buffered = 10, .health_score = 88.5 });

    const latest = tel.latest();
    try std.testing.expect(latest != null);
    // The returned value is a copy, so we can safely compare
    try std.testing.expectEqual(@as(usize, 42), latest.?.active_claims);
    try std.testing.expectEqual(@as(i64, now), latest.?.timestamp);
}

test "BrainTelemetry avgHealth: all zeros" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 0, .events_published = 0, .events_buffered = 0, .health_score = 0.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 0, .events_published = 0, .events_buffered = 0, .health_score = 0.0 });

    const avg = tel.avgHealth(10);
    try std.testing.expectEqual(@as(f32, 0.0), avg);
}

test "BrainTelemetry avgHealth: single point" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now: i64 = 1000000;

    try tel.record(.{ .timestamp = now, .active_claims = 1, .events_published = 0, .events_buffered = 0, .health_score = 75.5 });

    const avg = tel.avgHealth(10);
    try std.testing.expectEqual(@as(f32, 75.5), avg);
}
