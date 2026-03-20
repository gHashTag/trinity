//! BRAIN TELEMETRY — Time-series metrics aggregation
//!
//! Tracks brain metrics over time for analysis and alerting.

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
        points.ensureTotalCapacity(allocator, max_points) catch {};
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
    pub fn percentile(self: *Self, p: f32, last_n: usize) f32 {
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
        const idx_f = @as(f32, @floatFromInt(scores.len - 1)) * (p / 100.0);
        const idx = @as(usize, @intFromFloat(idx_f));
        const frac = idx_f - @as(f32, @floatFromInt(idx));

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
            .events_published = @as(u64, @intCast(i * 10)),
            .events_buffered = i,
            .health_score = @as(f32, @floatFromInt(i * 10)),
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
