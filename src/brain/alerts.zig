//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! BRAIN ALERTS — Critical Health State Notification System
//!
//! Monitors brain health and sends alerts when thresholds are crossed.
//! Integrates with Telegram for notifications and includes suppression
//! to prevent spam.
//!
//! Sacred Formula: phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");

const ALERTS_LOG = ".trinity/brain_alerts.jsonl";

/// Alert manager errors
pub const AlertError = error{
    HttpFailed,
    TelegramDisabled,
    JsonWriteFailed,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert severity levels
pub const AlertLevel = enum {
    /// Informational - system is working as expected
    info,
    /// Warning - attention needed but system is functional
    warning,
    /// Critical - immediate action required
    critical,

    pub fn emoji(self: AlertLevel) []const u8 {
        return switch (self) {
            .info => "[blue]INFO[/]",
            .warning => "[yellow]WARN[/]",
            .critical => "[red]CRIT[/]",
        };
    }

    pub fn emojiPlain(self: AlertLevel) []const u8 {
        return switch (self) {
            .info => "[INFO]",
            .warning => "[WARN]",
            .critical => "[CRIT]",
        };
    }

    pub fn telegramIcon(self: AlertLevel) []const u8 {
        return switch (self) {
            .info => "\xe2\x84\xb9\xef\xb8\x8f", // i
            .warning => "\xe2\x9a\xa0\xef\xb8\x8f", // warning
            .critical => "\xf0\x9f\x9a\xa8", // siren
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT CONDITIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert condition types
pub const AlertCondition = enum {
    /// Overall health score dropped below threshold
    health_low,
    /// Event buffer is filling up
    events_buffered_high,
    /// Too many active task claims
    claims_overflow,
    /// Brain region is unavailable
    region_unavailable,
    /// Health score is declining rapidly
    health_declining,
    /// Custom alert condition
    custom,

    pub fn label(self: AlertCondition) []const u8 {
        return switch (self) {
            .health_low => "Health Low",
            .events_buffered_high => "Events Buffered",
            .claims_overflow => "Claims Overflow",
            .region_unavailable => "Region Unavailable",
            .health_declining => "Health Declining",
            .custom => "Custom",
        };
    }
};

/// Threshold configuration for alert conditions
pub const AlertThresholds = struct {
    health_warning: f32 = 80.0,
    health_critical: f32 = 50.0,
    events_buffered_warning: usize = 1000,
    events_buffered_critical: usize = 5000,
    claims_overflow_warning: usize = 5000,
    claims_overflow_critical: usize = 10000,
    health_decline_rate: f32 = 20.0, // Points per check interval

    pub fn init() AlertThresholds {
        return .{};
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT RECORD
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual alert record
pub const Alert = struct {
    timestamp: i64,
    level: AlertLevel,
    condition: AlertCondition,
    message: []const u8,
    region_name: ?[]const u8 = null,
    health_score: ?f32 = null,
    resolved: bool = false,
    resolved_at: ?i64 = null,

    /// Format alert as log line
    pub fn formatLog(self: *const Alert, allocator: std.mem.Allocator) ![]const u8 {
        const resolved_str = if (self.resolved) " -> RESOLVED" else "";
        const region_str = if (self.region_name) |r|
            try std.fmt.allocPrint(allocator, " [{s}]", .{r})
        else
            "";

        // Format the final string, incorporating region_str
        const result = try std.fmt.allocPrint(allocator, "{{\"ts\":{d},\"level\":\"{s}\",\"condition\":\"{s}\",\"message\":\"{s}\",\"health\":{d:.1}{s}{s}}}\n", .{
            self.timestamp,
            @tagName(self.level),
            @tagName(self.condition),
            self.message,
            self.health_score orelse 0.0,
            region_str,
            resolved_str,
        });

        // Free region_str now that we've incorporated it into result
        if (self.region_name != null) allocator.free(region_str);

        return result;
    }

    /// Format alert for Telegram
    pub fn formatTelegram(self: *const Alert, allocator: std.mem.Allocator) ![]const u8 {
        const region_str = if (self.region_name) |r|
            try std.fmt.allocPrint(allocator, "\nRegion: {s}", .{r})
        else
            "";

        const health_str = if (self.health_score) |h|
            try std.fmt.allocPrint(allocator, "\nHealth: {d:.1}/100", .{h})
        else
            "";

        // Format the final string, incorporating both region_str and health_str
        const result = try std.fmt.allocPrint(allocator, "{s} {s}: {s}{s}{s}", .{
            self.level.telegramIcon(),
            self.condition.label(),
            self.message,
            region_str,
            health_str,
        });

        // Free intermediate strings now that we've incorporated them into result
        if (self.region_name != null) allocator.free(region_str);
        if (self.health_score != null) allocator.free(health_str);

        return result;
    }

    /// Check if this alert is a duplicate of another (for suppression)
    pub fn isDuplicateOf(self: *const Alert, other: Alert) bool {
        if (self.condition != other.condition) return false;
        if (self.level != other.level) return false;
        if (self.region_name) |r| {
            if (other.region_name) |or_r| {
                if (!std.mem.eql(u8, r, or_r)) return false;
            } else return false;
        } else if (other.region_name != null) return false;
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT SUPPRESSION
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert suppression state to prevent spam
pub const SuppressionState = struct {
    last_alert_time: i64 = 0,
    last_alert_condition: AlertCondition = .health_low,
    last_alert_region: ?[]const u8 = null,
    alert_count: u32 = 0,

    /// Check if an alert should be suppressed
    pub fn shouldSuppress(self: *const SuppressionState, alert: Alert, now: i64, min_interval_ms: i64) bool {
        // First alert always goes through
        if (self.last_alert_time == 0) return false;

        // Check time since last alert
        const time_since = now - self.last_alert_time;
        if (time_since < min_interval_ms) {
            // Same condition and region? Suppress
            if (alert.condition == self.last_alert_condition) {
                if (alert.region_name) |r| {
                    if (self.last_alert_region) |lr| {
                        if (std.mem.eql(u8, r, lr)) return true;
                    }
                } else if (self.last_alert_region == null) {
                    return true;
                }
            }
        }

        return false;
    }

    /// Update suppression state after sending alert
    pub fn recordAlert(self: *SuppressionState, alert: Alert, now: i64) void {
        self.last_alert_time = now;
        self.last_alert_condition = alert.condition;
        self.alert_count += 1;
        // Note: we don't copy region_name here as it's a borrowed slice
        // The caller should manage region name lifetime
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert history tracker
pub const AlertHistory = struct {
    allocator: std.mem.Allocator,
    alerts: std.ArrayList(Alert),
    max_alerts: usize = 1000,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_alerts: usize) Self {
        // Initialize with .empty - ArrayList will allocate on first append
        // deinit will properly free any allocations
        return Self{
            .allocator = allocator,
            .alerts = .empty,
            .max_alerts = max_alerts,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.alerts.items) |*alert| {
            if (alert.region_name) |r| self.allocator.free(r);
            self.allocator.free(alert.message);
        }
        self.alerts.deinit(self.allocator);
    }

    /// Add an alert to history
    pub fn add(self: *Self, alert: Alert) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Copy message for storage
        const msg_copy = try self.allocator.dupe(u8, alert.message);
        errdefer self.allocator.free(msg_copy);

        var stored_alert = alert;
        stored_alert.message = msg_copy;

        var region_copy: ?[]const u8 = null;
        if (alert.region_name) |r| {
            region_copy = try self.allocator.dupe(u8, r);
            errdefer if (region_copy) |rc| self.allocator.free(rc);
            stored_alert.region_name = region_copy;
        }

        try self.alerts.append(self.allocator, stored_alert);

        // Trim if over limit
        while (self.alerts.items.len > self.max_alerts) {
            const removed = self.alerts.orderedRemove(0);
            if (removed.region_name) |r| self.allocator.free(r);
            self.allocator.free(removed.message);
        }

        // Persist to log file (use original alert, not stored_alert with owned pointers)
        // Note: persist may fail in tests due to file system, don't let it break alert tracking
        self.persist(alert) catch |err| {
            std.log.warn("Failed to persist alert to log: {}", .{err});
        };
    }

    /// Persist alert to log file
    fn persist(self: *Self, alert: Alert) !void {
        const file = try std.fs.cwd().createFile(ALERTS_LOG, .{ .read = true });
        defer file.close();

        try file.seekFromEnd(0);

        const log_line = try alert.formatLog(self.allocator);
        defer self.allocator.free(log_line);

        try file.writeAll(log_line);
    }

    /// Get recent alerts (last N)
    ///
    /// Note: The returned alerts contain borrowed pointers to message and region_name.
    /// Only the returned slice itself should be freed by the caller. The borrowed
    /// pointers remain valid as long as the AlertHistory is not modified.
    pub fn recent(self: *Self, n: usize, level: ?AlertLevel) ![]const Alert {
        self.mutex.lock();
        defer self.mutex.unlock();

        const start = if (n >= self.alerts.items.len) 0 else self.alerts.items.len - n;

        if (level) |lvl| {
            // For filtered results, we need to copy the Alert structs
            // but the pointers (message, region_name) remain borrowed
            var filtered = std.ArrayList(Alert).initCapacity(self.allocator, self.alerts.items.len - start) catch {
                std.log.warn("Failed to allocate filtered alerts list", .{});
                return error.OutOfMemory;
            };
            errdefer filtered.deinit(self.allocator);

            for (self.alerts.items[start..]) |alert| {
                if (alert.level == lvl) {
                    try filtered.append(self.allocator, alert);
                }
            }
            return filtered.toOwnedSlice(self.allocator);
        }

        // Return copy of Alert structs with borrowed pointers
        const result = try self.allocator.alloc(Alert, self.alerts.items.len - start);
        @memcpy(result, self.alerts.items[start..]);
        return result;
    }

    /// Get alert statistics
    pub const Stats = struct {
        total: usize,
        info: usize,
        warning: usize,
        critical: usize,
        unresolved: usize,
        last_24h: usize,
    };

    pub fn stats(self: *Self) !Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        const day_ago = now - (24 * 60 * 60 * 1000);

        var result: Stats = .{
            .total = self.alerts.items.len,
            .info = 0,
            .warning = 0,
            .critical = 0,
            .unresolved = 0,
            .last_24h = 0,
        };

        for (self.alerts.items) |alert| {
            switch (alert.level) {
                .info => result.info += 1,
                .warning => result.warning += 1,
                .critical => result.critical += 1,
            }
            if (!alert.resolved) result.unresolved += 1;
            if (alert.timestamp > day_ago) result.last_24h += 1;
        }

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// Alert manager coordinates alert detection, suppression, and notification
pub const AlertManager = struct {
    allocator: std.mem.Allocator,
    history: AlertHistory,
    suppression: SuppressionState,
    thresholds: AlertThresholds,
    telegram_enabled: bool,
    telegram_token: []const u8 = "",
    telegram_chat_id: []const u8 = "",
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const history = AlertHistory.init(allocator, 1000);

        return Self{
            .allocator = allocator,
            .history = history,
            .suppression = .{},
            .thresholds = AlertThresholds.init(),
            .telegram_enabled = false,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
    }

    /// Configure Telegram notifications
    pub fn configureTelegram(self: *Self, token: []const u8, chat_id: []const u8) void {
        self.telegram_token = token;
        self.telegram_chat_id = chat_id;
        self.telegram_enabled = true;
    }

    /// Check health conditions and generate alerts
    pub fn checkHealth(self: *Self, health_score: f32, events_buffered: usize, claims_count: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();

        // Check health score
        if (health_score < self.thresholds.health_critical) {
            const msg = try std.fmt.allocPrint(self.allocator, "Critical health: {d:.1}/100", .{health_score});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .critical,
                .condition = .health_low,
                .message = msg,
                .health_score = health_score,
            });
        } else if (health_score < self.thresholds.health_warning) {
            const msg = try std.fmt.allocPrint(self.allocator, "Low health: {d:.1}/100", .{health_score});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .warning,
                .condition = .health_low,
                .message = msg,
                .health_score = health_score,
            });
        }

        // Check event buffer
        if (events_buffered > self.thresholds.events_buffered_critical) {
            const msg = try std.fmt.allocPrint(self.allocator, "Event buffer critical: {d} events", .{events_buffered});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .critical,
                .condition = .events_buffered_high,
                .message = msg,
            });
        } else if (events_buffered > self.thresholds.events_buffered_warning) {
            const msg = try std.fmt.allocPrint(self.allocator, "Event buffer high: {d} events", .{events_buffered});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .warning,
                .condition = .events_buffered_high,
                .message = msg,
            });
        }

        // Check claims overflow
        if (claims_count > self.thresholds.claims_overflow_critical) {
            const msg = try std.fmt.allocPrint(self.allocator, "Claims overflow: {d} active", .{claims_count});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .critical,
                .condition = .claims_overflow,
                .message = msg,
            });
        } else if (claims_count > self.thresholds.claims_overflow_warning) {
            const msg = try std.fmt.allocPrint(self.allocator, "High claim count: {d} active", .{claims_count});
            defer self.allocator.free(msg);
            try self.processAlert(.{
                .timestamp = now,
                .level = .warning,
                .condition = .claims_overflow,
                .message = msg,
            });
        }
    }

    /// Alert on unavailable region
    pub fn alertRegionUnavailable(self: *Self, region_name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        const msg = try std.fmt.allocPrint(self.allocator, "Region unavailable", .{});
        defer self.allocator.free(msg);
        try self.processAlert(.{
            .timestamp = now,
            .level = .critical,
            .condition = .region_unavailable,
            .message = msg,
            .region_name = region_name,
        });
    }

    /// Alert on declining health
    pub fn alertHealthDeclining(self: *Self, current: f32, previous: f32, rate: f32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        const msg = try std.fmt.allocPrint(self.allocator, "Health declining: {d:.1} -> {d:.1} ({d:.1}/interval)", .{ previous, current, rate });
        defer self.allocator.free(msg);
        try self.processAlert(.{
            .timestamp = now,
            .level = .warning,
            .condition = .health_declining,
            .message = msg,
            .health_score = current,
        });
    }

    /// Process an alert (check suppression, send notification, record)
    fn processAlert(self: *Self, alert_param: Alert) !void {
        const now = std.time.milliTimestamp();

        // Check suppression (5 min for warnings, 1 min for critical)
        const min_interval: i64 = switch (alert_param.level) {
            .info => 60 * 1000,
            .warning => 5 * 60 * 1000,
            .critical => 1 * 60 * 1000,
        };

        if (self.suppression.shouldSuppress(alert_param, now, min_interval)) {
            // Still record but don't notify
            try self.history.add(alert_param);
            return;
        }

        // Send notification
        if (self.telegram_enabled) {
            self.sendTelegram(alert_param) catch |err| {
                std.log.err("Failed to send Telegram alert: {}", .{err});
            };
        }

        // Record in history
        try self.history.add(alert_param);

        // Update suppression state
        self.suppression.recordAlert(alert_param, now);
    }

    /// Send alert to Telegram
    fn sendTelegram(self: *const Self, alert_param: Alert) !void {
        if (!self.telegram_enabled) return error.TelegramDisabled;

        const message = try alert_param.formatTelegram(self.allocator);
        defer self.allocator.free(message);

        // Simple HTTP POST to Telegram API
        var url_buf: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{self.telegram_token});

        var body_buf: [4096]u8 = undefined;
        const body = try std.fmt.bufPrint(&body_buf, "{{\"chat_id\":\"{s}\",\"text\":\"{s}\",\"parse_mode\":\"HTML\"}}", .{ self.telegram_chat_id, message });

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();

        const result = client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
            .response_writer = &aw.writer,
        }) catch |err| {
            std.log.err("Telegram HTTP request failed: {}", .{err});
            return error.HttpFailed;
        };

        if (result.status != .ok) {
            std.log.err("Telegram API returned status: {}", .{result.status});
            return error.HttpFailed;
        }
    }

    /// Get alert statistics
    pub fn getStats(self: *Self) !AlertHistory.Stats {
        return self.history.stats();
    }

    /// Get recent alerts
    pub fn getRecentAlerts(self: *Self, n: usize, level: ?AlertLevel) ![]const Alert {
        return self.history.recent(n, level);
    }

    /// Format summary for display
    pub fn formatSummary(self: *Self, writer: anytype) !void {
        const stats = try self.getStats();

        try writer.writeAll("╔═══════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║  BRAIN ALERTS SUMMARY                                           ║\n");
        try writer.writeAll("╠═══════════════════════════════════════════════════════════════╣\n");
        try writer.print("║  Total Alerts:    {d:>6}                                       ║\n", .{stats.total});
        try writer.print("║  Info:            {d:>6}                                       ║\n", .{stats.info});
        try writer.print("║  Warnings:        {d:>6}                                       ║\n", .{stats.warning});
        try writer.print("║  Critical:        {d:>6}                                       ║\n", .{stats.critical});
        try writer.print("║  Unresolved:      {d:>6}                                       ║\n", .{stats.unresolved});
        try writer.print("║  Last 24h:        {d:>6}                                       ║\n", .{stats.last_24h});
        try writer.writeAll("╚═══════════════════════════════════════════════════════════════╝\n");

        if (stats.unresolved > 0) {
            try writer.print("\n{s}! {d} unresolved alert(s){s}\n", .{ if (stats.critical > 0) "[red]CRIT[/]" else "[yellow]WARN[/]", stats.unresolved, "[]" });
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AlertLevel emoji mapping" {
    try std.testing.expectEqual(@as(usize, 6), AlertLevel.info.emojiPlain().len); // [INFO]
    try std.testing.expect(std.mem.startsWith(u8, AlertLevel.warning.emojiPlain(), "["));
    try std.testing.expect(std.mem.endsWith(u8, AlertLevel.critical.emojiPlain(), "]"));
}

test "AlertCondition label" {
    try std.testing.expect(std.mem.eql(u8, "Health Low", AlertCondition.health_low.label()));
    try std.testing.expect(std.mem.eql(u8, "Events Buffered", AlertCondition.events_buffered_high.label()));
}

test "SuppressionState first alert not suppressed" {
    var state = SuppressionState{};
    const alert = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    try std.testing.expect(!state.shouldSuppress(alert, 1000, 60000));
}

test "SuppressionState suppresses duplicate within interval" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };
    const alert2 = Alert{
        .timestamp = 2000, // Only 1 second later
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    state.recordAlert(alert1, 1000);
    try std.testing.expect(state.shouldSuppress(alert2, 2000, 60000)); // 60 min interval
}

test "SuppressionState allows after interval" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };
    const alert2 = Alert{
        .timestamp = 400000, // 6.5 minutes later
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    state.recordAlert(alert1, 1000);
    try std.testing.expect(!state.shouldSuppress(alert2, 400000, 300000)); // 5 min interval
}

test "AlertHistory add and retrieve" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 10);
    defer history.deinit();

    const alert = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test alert",
    };

    try history.add(alert);

    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 1), recent.len);
    try std.testing.expectEqual(.warning, recent[0].level);
}

test "AlertHistory stats" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 10);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "Info" });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "Warn" });
    try history.add(.{ .timestamp = 3000, .level = .critical, .condition = .health_low, .message = "Crit", .resolved = true });

    const stats = try history.stats();
    try std.testing.expectEqual(@as(usize, 3), stats.total);
    try std.testing.expectEqual(@as(usize, 1), stats.info);
    try std.testing.expectEqual(@as(usize, 1), stats.warning);
    try std.testing.expectEqual(@as(usize, 1), stats.critical);
    try std.testing.expectEqual(@as(usize, 2), stats.unresolved); // Only crit is resolved
}

test "AlertManager checkHealth generates alerts" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Trigger critical health alert
    try manager.checkHealth(30.0, 100, 100);

    const recent = try manager.getRecentAlerts(10, null);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
}

test "AlertManager checkHealth with high events" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Trigger events buffered warning
    try manager.checkHealth(90.0, 2000, 100);

    const recent = try manager.getRecentAlerts(10, .warning);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
}

test "Alert formatTelegram" {
    const allocator = std.testing.allocator;
    const alert = Alert{
        .timestamp = 1000,
        .level = .critical,
        .condition = .health_low,
        .message = "Test critical",
        .health_score = 25.0,
    };

    const msg = try alert.formatTelegram(allocator);
    defer allocator.free(msg);

    try std.testing.expect(msg.len > 0);
}

test "Alert isDuplicateOf" {
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
        .region_name = "Basal Ganglia",
    };

    const alert2 = Alert{
        .timestamp = 2000,
        .level = .warning,
        .condition = .health_low,
        .message = "Different message",
        .region_name = "Basal Ganglia",
    };

    try std.testing.expect(alert1.isDuplicateOf(alert2));
}

test "Alert isDuplicateOf different region" {
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
        .region_name = "Basal Ganglia",
    };

    const alert2 = Alert{
        .timestamp = 2000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
        .region_name = "Reticular Formation",
    };

    try std.testing.expect(!alert1.isDuplicateOf(alert2));
}

test "AlertHistory filters by level" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 10);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "Info" });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "Warn" });
    try history.add(.{ .timestamp = 3000, .level = .warning, .condition = .health_low, .message = "Warn2" });

    const warnings = try history.recent(10, .warning);
    defer allocator.free(warnings);
    try std.testing.expectEqual(@as(usize, 2), warnings.len);
}

test "AlertHistory trim when over limit" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 3); // Small limit
    defer history.deinit();

    // Add 5 alerts
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try history.add(.{
            .timestamp = i * 1000,
            .level = .info,
            .condition = .health_low,
            .message = "Test",
        });
    }

    // Should only have last 3
    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 3), recent.len);
    try std.testing.expectEqual(@as(i64, 4000), recent[2].timestamp); // Last alert
}

test "AlertThresholds default values" {
    const thresholds = AlertThresholds.init();
    try std.testing.expectEqual(@as(f32, 80.0), thresholds.health_warning);
    try std.testing.expectEqual(@as(f32, 50.0), thresholds.health_critical);
    try std.testing.expectEqual(@as(usize, 1000), thresholds.events_buffered_warning);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT LEVEL THRESHOLD TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AlertLevel thresholds - info level boundaries" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Health above warning threshold = no alerts
    try manager.checkHealth(100.0, 100, 100);
    const stats = try manager.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.total);
}

test "AlertLevel thresholds - warning level triggers" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Health at warning threshold (80.0) should trigger warning
    try manager.checkHealth(79.9, 100, 100);

    const recent = try manager.getRecentAlerts(10, .warning);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.warning, recent[0].level);
    try std.testing.expectEqual(.health_low, recent[0].condition);
}

test "AlertLevel thresholds - critical level triggers" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Health below critical threshold (50.0) should trigger critical
    try manager.checkHealth(30.0, 100, 100);

    const recent = try manager.getRecentAlerts(10, .critical);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.critical, recent[0].level);
}

test "AlertLevel thresholds - events buffered warning" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Events at warning threshold (1000)
    try manager.checkHealth(100.0, 1500, 100);

    const recent = try manager.getRecentAlerts(10, .warning);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.events_buffered_high, recent[0].condition);
}

test "AlertLevel thresholds - events buffered critical" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Events at critical threshold (5000)
    try manager.checkHealth(100.0, 6000, 100);

    const recent = try manager.getRecentAlerts(10, .critical);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.events_buffered_high, recent[0].condition);
}

test "AlertLevel thresholds - claims overflow warning" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Claims at warning threshold (5000)
    try manager.checkHealth(100.0, 100, 6000);

    const recent = try manager.getRecentAlerts(10, .warning);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.claims_overflow, recent[0].condition);
}

test "AlertLevel thresholds - claims overflow critical" {
    const allocator = std.testing.allocator;
    var manager = try AlertManager.init(allocator);
    defer manager.deinit();

    // Claims at critical threshold (10000)
    try manager.checkHealth(100.0, 100, 12000);

    const recent = try manager.getRecentAlerts(10, .critical);
    defer allocator.free(recent);
    try std.testing.expect(recent.len > 0);
    try std.testing.expectEqual(.claims_overflow, recent[0].condition);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT CONDITION MATCHING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AlertCondition matching - health_low with score" {
    const alert = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Low health",
        .health_score = 65.0,
    };

    try std.testing.expect(alert.health_score != null);
    try std.testing.expectEqual(@as(f32, 65.0), alert.health_score.?);
}

test "AlertCondition matching - region_unavailable has region" {
    const alert = Alert{
        .timestamp = 1000,
        .level = .critical,
        .condition = .region_unavailable,
        .message = "Region down",
        .region_name = "Basal Ganglia",
    };

    try std.testing.expect(alert.region_name != null);
    try std.testing.expect(std.mem.eql(u8, "Basal Ganglia", alert.region_name.?));
}

test "AlertCondition matching - all condition types" {
    const conditions = [_]AlertCondition{
        .health_low,
        .events_buffered_high,
        .claims_overflow,
        .region_unavailable,
        .health_declining,
        .custom,
    };

    for (conditions) |cond| {
        const label = cond.label();
        try std.testing.expect(label.len > 0);
    }
}

test "AlertCondition matching - isDuplicateOf same condition different level" {
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    const alert2 = Alert{
        .timestamp = 2000,
        .level = .critical, // Different level
        .condition = .health_low,
        .message = "Test",
    };

    try std.testing.expect(!alert1.isDuplicateOf(alert2));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUPPRESSION STATE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SuppressionState - alert count increments" {
    var state = SuppressionState{};
    const alert = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    try std.testing.expectEqual(@as(u32, 0), state.alert_count);
    state.recordAlert(alert, 1000);
    try std.testing.expectEqual(@as(u32, 1), state.alert_count);
    state.recordAlert(alert, 2000);
    try std.testing.expectEqual(@as(u32, 2), state.alert_count);
}

test "SuppressionState - different condition not suppressed" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };
    const alert2 = Alert{
        .timestamp = 2000,
        .level = .warning,
        .condition = .events_buffered_high, // Different condition
        .message = "Test",
    };

    state.recordAlert(alert1, 1000);
    try std.testing.expect(!state.shouldSuppress(alert2, 2000, 60000));
}

test "SuppressionState - different region not suppressed" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .region_unavailable,
        .message = "Test",
        .region_name = "Region1",
    };
    const alert2 = Alert{
        .timestamp = 2000,
        .level = .warning,
        .condition = .region_unavailable,
        .message = "Test",
        .region_name = "Region2", // Different region
    };

    state.recordAlert(alert1, 1000);
    try std.testing.expect(!state.shouldSuppress(alert2, 2000, 60000));
}

test "SuppressionState - interval boundary condition" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };
    const alert2 = Alert{
        .timestamp = 301000, // Exactly 5 minutes later from first alert
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    state.recordAlert(alert1, 1000);
    // At exactly the interval boundary (301000 - 1000 = 300000), should NOT suppress
    try std.testing.expect(!state.shouldSuppress(alert2, 301000, 300000));
}

test "SuppressionState - one millimeter before interval" {
    var state = SuppressionState{};
    const alert1 = Alert{
        .timestamp = 1000,
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };
    const alert2 = Alert{
        .timestamp = 300000 - 1, // 1ms before interval
        .level = .warning,
        .condition = .health_low,
        .message = "Test",
    };

    state.recordAlert(alert1, 1000);
    try std.testing.expect(state.shouldSuppress(alert2, 300000 - 1, 300000));
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT HISTORY TRACKING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AlertHistory - maintains insertion order" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 10);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "First" });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "Second" });
    try history.add(.{ .timestamp = 3000, .level = .critical, .condition = .health_low, .message = "Third" });

    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 3), recent.len);
    try std.testing.expectEqual(@as(i64, 1000), recent[0].timestamp);
    try std.testing.expectEqual(@as(i64, 2000), recent[1].timestamp);
    try std.testing.expectEqual(@as(i64, 3000), recent[2].timestamp);
}

test "AlertHistory - respects limit on retrieval" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 100);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "A" });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "B" });
    try history.add(.{ .timestamp = 3000, .level = .critical, .condition = .health_low, .message = "C" });

    const recent = try history.recent(2, null); // Only ask for 2
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 2), recent.len);
    try std.testing.expectEqual(@as(i64, 2000), recent[0].timestamp);
    try std.testing.expectEqual(@as(i64, 3000), recent[1].timestamp);
}

test "AlertHistory - stats count all levels" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 100);
    defer history.deinit();

    // Add mix of alerts
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        // Safe cast: i * 1000 fits in i64 for i < 5 (max 4000)
        const timestamp = @as(i64, @intCast(i)) * 1000;
        try history.add(.{ .timestamp = timestamp, .level = .info, .condition = .health_low, .message = "Info" });
    }
    i = 0;
    while (i < 3) : (i += 1) {
        // Safe cast: (i + 5) * 1000 fits in i64 for i < 3 (max 8000)
        const timestamp = @as(i64, @intCast(i + 5)) * 1000;
        try history.add(.{ .timestamp = timestamp, .level = .warning, .condition = .health_low, .message = "Warn" });
    }
    i = 0;
    while (i < 2) : (i += 1) {
        // Safe cast: (i + 8) * 1000 fits in i64 for i < 2 (max 10000)
        const timestamp = @as(i64, @intCast(i + 8)) * 1000;
        try history.add(.{ .timestamp = timestamp, .level = .critical, .condition = .health_low, .message = "Crit" });
    }

    const stats = try history.stats();
    try std.testing.expectEqual(@as(usize, 10), stats.total);
    try std.testing.expectEqual(@as(usize, 5), stats.info);
    try std.testing.expectEqual(@as(usize, 3), stats.warning);
    try std.testing.expectEqual(@as(usize, 2), stats.critical);
}

test "AlertHistory - resolved alerts tracked correctly" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 100);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .warning, .condition = .health_low, .message = "Unresolved", .resolved = false });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "Resolved", .resolved = true, .resolved_at = 3000 });

    const stats = try history.stats();
    try std.testing.expectEqual(@as(usize, 1), stats.unresolved);
}

test "AlertHistory - recent with null level returns all" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 100);
    defer history.deinit();

    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "A" });
    try history.add(.{ .timestamp = 2000, .level = .warning, .condition = .health_low, .message = "B" });
    try history.add(.{ .timestamp = 3000, .level = .critical, .condition = .health_low, .message = "C" });

    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 3), recent.len);
}

test "AlertHistory - empty history returns empty slice" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 100);
    defer history.deinit();

    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 0), recent.len);
}

test "AlertHistory - oldest removed when over limit" {
    const allocator = std.testing.allocator;
    var history = AlertHistory.init(allocator, 3);
    defer history.deinit();

    // Add alerts with distinct messages
    try history.add(.{ .timestamp = 1000, .level = .info, .condition = .health_low, .message = "First" });
    try history.add(.{ .timestamp = 2000, .level = .info, .condition = .health_low, .message = "Second" });
    try history.add(.{ .timestamp = 3000, .level = .info, .condition = .health_low, .message = "Third" });
    try history.add(.{ .timestamp = 4000, .level = .info, .condition = .health_low, .message = "Fourth" });

    const recent = try history.recent(10, null);
    defer allocator.free(recent);
    try std.testing.expectEqual(@as(usize, 3), recent.len);

    // First should be removed
    for (recent) |alert| {
        try std.testing.expect(!std.mem.eql(u8, "First", alert.message));
    }
}
