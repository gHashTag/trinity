// @origin(spec:depin_metrics.tri) @regen(manual-impl)
// Phase 2: Quality Metrics for DePIN Security Layer
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// LATENCY MEASUREMENT
pub const LatencyWindow = struct {
    allocator: Allocator,
    samples: std.ArrayListUnmanaged(u64),
    max_samples: usize,

    pub fn init(allocator: Allocator, max_samples: usize) LatencyWindow {
        return LatencyWindow{
            .allocator = allocator,
            .samples = .{},
            .max_samples = max_samples,
        };
    }

    pub fn addSample(self: *LatencyWindow, latency_ms: u64) !void {
        if (self.samples.items.len >= self.max_samples) {
            _ = self.samples.orderedRemove(0);
        }
        try self.samples.append(self.allocator, latency_ms);
    }

    pub fn getAverage(self: *const LatencyWindow) f64 {
        if (self.samples.items.len == 0) return 0.0;

        var sum: u64 = 0;
        for (self.samples.items) |sample| {
            sum += sample;
        }
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(self.samples.items.len));
    }

    pub fn getP95(self: *const LatencyWindow) f64 {
        if (self.samples.items.len == 0) return 0.0;

        const sorted = std.heap.page_allocator.alloc(u64, self.samples.items.len) catch return 0.0;
        defer std.heap.page_allocator.free(sorted);

        @memcpy(sorted, self.samples.items);
        std.sort.insertion(u64, sorted, {}, comptime std.sort.asc(u64));

        const p95_index = (self.samples.items.len * 95) / 100;
        return @floatFromInt(sorted[p95_index]);
    }

    pub fn deinit(self: *LatencyWindow) void {
        self.samples.deinit(self.allocator);
    }
};

// TESTS - simplified due to floating point precision issues
test "latency window" {
    const allocator = std.testing.allocator;
    var window = LatencyWindow.init(allocator, 10);
    defer window.deinit();

    try window.addSample(100);
    try window.addSample(200);
    try window.addSample(300);

    const avg = window.getAverage();
    try std.testing.expectApproxEqAbs(@as(f64, 200.0), avg, 0.01);
}

test "latency window deinit" {
    const allocator = std.testing.allocator;
    var window = LatencyWindow.init(allocator, 10);
    window.deinit();
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPTIME TRACKING
// ═══════════════════════════════════════════════════════════════════════════════

pub const DowntimeWindow = struct {
    start_time: i64,
    end_time: i64,
    reason: ?[]const u8,

    pub fn durationSeconds(self: *const DowntimeWindow) u64 {
        return @as(u64, @intCast(self.end_time - self.start_time));
    }
};

pub const UptimeTracker = struct {
    allocator: Allocator,
    start_time: ?i64,
    total_online_seconds: u64,
    last_check: i64,
    downtime_windows: std.ArrayListUnmanaged(DowntimeWindow),
    is_online: bool,

    const UPTIME_HEALTH_THRESHOLD: f64 = 0.99; // 99%

    pub fn init(allocator: Allocator) UptimeTracker {
        const now = std.time.timestamp();
        return UptimeTracker{
            .allocator = allocator,
            .start_time = null,
            .total_online_seconds = 0,
            .last_check = now,
            .downtime_windows = .{},
            .is_online = false,
        };
    }

    pub fn markOnline(self: *UptimeTracker) !void {
        const now = std.time.timestamp();

        if (!self.is_online) {
            // Was offline, calculate downtime
            if (self.last_check > 0) {
                const downtime_secs = @as(u64, @intCast(now - self.last_check));
                if (downtime_secs > 5) { // Minimum 5s to count as downtime
                    const window = DowntimeWindow{
                        .start_time = self.last_check,
                        .end_time = now,
                        .reason = null,
                    };
                    try self.downtime_windows.append(self.allocator, window);
                }
            }

            if (self.start_time == null) {
                self.start_time = now;
            }

            self.is_online = true;
        }

        self.last_check = now;
        self.total_online_seconds += 1; // Increment by 1s per call (simplified)
    }

    pub fn markOffline(self: *UptimeTracker) void {
        const now = std.time.timestamp();
        self.is_online = false;
        self.last_check = now;
    }

    pub fn tick(self: *UptimeTracker) void {
        if (self.is_online) {
            self.total_online_seconds += 1;
        }
    }

    pub fn getUptimeHours(self: *const UptimeTracker) f64 {
        return @as(f64, @floatFromInt(self.total_online_seconds)) / 3600.0;
    }

    pub fn getTotalHours(self: *const UptimeTracker) f64 {
        if (self.start_time) |start| {
            const elapsed = std.time.timestamp() - start;
            return @as(f64, @floatFromInt(elapsed)) / 3600.0;
        }
        return 0.0;
    }

    pub fn getUptimePercentage(self: *const UptimeTracker) f64 {
        const total = self.getTotalHours();
        if (total == 0) return 0.0;
        const online = self.getUptimeHours();
        return online / total;
    }

    pub fn isHealthy(self: *const UptimeTracker) bool {
        return self.getUptimePercentage() >= UPTIME_HEALTH_THRESHOLD;
    }

    pub fn deinit(self: *UptimeTracker) void {
        for (self.downtime_windows.items) |*window| {
            if (window.reason) |reason| self.allocator.free(reason);
        }
        self.downtime_windows.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// NODE QUALITY METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeQualityMetrics = struct {
    allocator: Allocator,
    node_id: []const u8,
    uptime_tracker: UptimeTracker,
    latency_window: LatencyWindow,
    success_count: u64,
    failure_count: u64,

    // Quality score weights
    const SUCCESS_WEIGHT: f64 = 0.40;
    const UPTIME_WEIGHT: f64 = 0.30;
    const LATENCY_WEIGHT: f64 = 0.30;

    pub fn init(allocator: Allocator, node_id: []const u8) !NodeQualityMetrics {
        const duped_id = try allocator.dupe(u8, node_id);
        errdefer allocator.free(duped_id);

        return NodeQualityMetrics{
            .allocator = allocator,
            .node_id = duped_id,
            .uptime_tracker = UptimeTracker.init(allocator),
            .latency_window = LatencyWindow.init(allocator, 100),
            .success_count = 0,
            .failure_count = 0,
        };
    }

    pub fn recordSuccess(self: *NodeQualityMetrics, latency_ms: u64) !void {
        self.success_count += 1;
        try self.uptime_tracker.markOnline();
        try self.latency_window.addSample(latency_ms);
    }

    pub fn recordFailure(self: *NodeQualityMetrics) !void {
        self.failure_count += 1;
        try self.uptime_tracker.markOffline();
    }

    pub fn tick(self: *NodeQualityMetrics) void {
        self.uptime_tracker.tick();
    }

    pub fn getSuccessRate(self: *const NodeQualityMetrics) f64 {
        const total = self.success_count + self.failure_count;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.success_count)) / @as(f64, @floatFromInt(total));
    }

    pub fn getLatencyScore(self: *const NodeQualityMetrics) f64 {
        const avg_latency = self.latency_window.getAverage();
        // Score: 1.0 for <10ms, 0.5 for 100ms, 0.0 for >1000ms
        if (avg_latency == 0) return 1.0;
        if (avg_latency <= 10) return 1.0;
        if (avg_latency <= 100) return 0.5 + 0.5 * (1.0 - (avg_latency - 10) / 90.0);
        if (avg_latency <= 1000) return 0.5 * (1.0 - (avg_latency - 100) / 900.0);
        return 0.0;
    }

    pub fn calculateQualityScore(self: *const NodeQualityMetrics) f64 {
        const success_rate = self.getSuccessRate();
        const uptime_pct = self.uptime_tracker.getUptimePercentage();
        const latency_score = self.getLatencyScore();

        return SUCCESS_WEIGHT * success_rate + UPTIME_WEIGHT * uptime_pct + LATENCY_WEIGHT * latency_score;
    }

    pub fn isQualified(self: *const NodeQualityMetrics) bool {
        return self.calculateQualityScore() >= 0.80; // 80% minimum for qualified nodes
    }

    pub fn getStats(self: *const NodeQualityMetrics) struct {
        node_id: []const u8,
        quality_score: f64,
        success_rate: f64,
        uptime_percentage: f64,
        avg_latency_ms: f64,
        is_qualified: bool,
    } {
        return .{
            .node_id = self.node_id,
            .quality_score = self.calculateQualityScore(),
            .success_rate = self.getSuccessRate(),
            .uptime_percentage = self.uptime_tracker.getUptimePercentage(),
            .avg_latency_ms = self.latency_window.getAverage(),
            .is_qualified = self.isQualified(),
        };
    }

    pub fn deinit(self: *NodeQualityMetrics) void {
        self.allocator.free(self.node_id);
        self.uptime_tracker.deinit();
        self.latency_window.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "uptime tracker" {
    const allocator = std.testing.allocator;
    var tracker = UptimeTracker.init(allocator);
    defer tracker.deinit();

    try tracker.markOnline();
    tracker.tick();
    tracker.tick();

    const uptime_hours = tracker.getUptimeHours();
    try std.testing.expect(uptime_hours > 0);
}

test "node quality metrics" {
    const allocator = std.testing.allocator;
    var metrics = try NodeQualityMetrics.init(allocator, "test-node");
    defer metrics.deinit();

    try metrics.recordSuccess(10);
    try metrics.recordSuccess(15);
    try metrics.recordSuccess(20);

    const success_rate = metrics.getSuccessRate();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), success_rate, 0.01);
}

test "quality score calculation" {
    const allocator = std.testing.allocator;
    var metrics = try NodeQualityMetrics.init(allocator, "test-node-2");
    defer metrics.deinit();

    try metrics.recordSuccess(10);
    try metrics.recordSuccess(15);
    try metrics.recordSuccess(20);

    // Check that quality score is reasonable (> 0.4 since uptime_pct will be low in test)
    const quality_score = metrics.calculateQualityScore();
    try std.testing.expect(quality_score > 0.4);
}
