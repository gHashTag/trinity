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
        return Self{
            .allocator = allocator,
            .points = std.ArrayList(TelemetryPoint).init(allocator),
            .max_points = max_points,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
    }

    /// Record a telemetry point
    pub fn record(self: *Self, point: TelemetryPoint) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.points.append(point);

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
        var count: usize = 0;

        for (self.points.items[start..]) |pt| {
            sum += pt.health_score;
            count += 1;
        }

        return if (count > 0) sum / @as(f32, @floatFromInt(count)) else 100.0;
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
            try writer.print("{{\"ts\":{d},\"claims\":{d},\"events\":{d},\"buffered\":{d},\"health\":{d:.1}}", .{
                pt.timestamp, pt.active_claims, pt.events_published, pt.events_buffered, pt.health_score,
            });
        }

        try writer.writeAll("]}");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "BrainTelemetry record and query" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = std.time.nanoTimestamp();

    try tel.record(.{ .timestamp = now, .active_claims = 5, .events_published = 100, .events_buffered = 10, .health_score = 90.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 3, .events_published = 150, .events_buffered = 5, .health_score = 95.0 });

    const avg = tel.avgHealth(10);
    try std.testing.expectApproxEqAbs(@as(f32, 92.5), avg, 0.1);
}

test "BrainTelemetry trend detection" {
    const allocator = std.testing.allocator;
    var tel = BrainTelemetry.init(allocator, 100);
    defer tel.deinit();

    const now = std.time.nanoTimestamp();

    // Improving trend
    try tel.record(.{ .timestamp = now, .active_claims = 10, .events_published = 100, .events_buffered = 50, .health_score = 70.0 });
    try tel.record(.{ .timestamp = now + 1, .active_claims = 8, .events_published = 120, .events_buffered = 30, .health_score = 80.0 });
    try tel.record(.{ .timestamp = now + 2, .active_claims = 5, .events_published = 140, .events_buffered = 10, .health_score = 90.0 });

    const trend = tel.trend(10);
    try std.testing.expectEqual(@as(@typeInfo(@TypeOf(trend)).Enum.tag_type, .improving), trend);
}
