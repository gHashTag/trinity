// ═══════════════════════════════════════════════════════════════════════════════
// telegram_alerts v1.1.0 - Enhanced Telegram Alert System for Swarm Watch
// ═══════════════════════════════════════════════════════════════════════════════
//
// DEV-003-PHASE4 Enhanced: Rich alert reports with detailed project information
// - HTTP client for actual Telegram Bot API calls
// - Rich alert messages with 5+ sections
// - System health summary and actionable recommendations
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import system_stats for rich alerts
const system_stats = @import("system_stats");
const SystemStats = system_stats.SystemStats;
const Trend = system_stats.Trend;

// Import real_telegram_http for actual HTTP calls (Phase 5)
const real_telegram_http = @import("real_telegram_http");
const TelegramClient = real_telegram_http.TelegramClient;
const SendResult = real_telegram_http.SendResult;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AlertSeverity = enum {
    info,
    warning,
    critical,
};

pub const AlertCondition = struct {
    name: []const u8,
    threshold: f64,
    current_value: f64,
    triggered_at: i64,

    pub fn isTriggered(self: AlertCondition) bool {
        if (std.mem.eql(u8, self.name, "acceptance_rate")) {
            return self.current_value < self.threshold;
        }
        if (std.mem.eql(u8, self.name, "peer_count")) {
            return self.current_value < self.threshold;
        }
        if (std.mem.eql(u8, self.name, "triples_stored")) {
            return self.current_value < self.threshold;
        }
        return false;
    }
};

pub const TelegramConfig = struct {
    bot_token: []const u8,
    chat_id: []const u8,
    enabled: bool,
    min_interval_seconds: i64,
};

pub const AlertMessage = struct {
    severity: AlertSeverity,
    title: []const u8,
    condition: []const u8,
    current_value: []const u8,
    threshold: []const u8,
    timestamp: i64,
    dashboard_link: []const u8,
    recent_events: []const []const u8,
};

// Alert history entry
const MAX_ALERT_HISTORY = 100;

pub const AlertEntry = struct {
    severity: AlertSeverity,
    condition: []const u8,
    timestamp: i64,
    sent: bool,
};

// Simple ring buffer for alert history
const AlertHistory = struct {
    entries: [MAX_ALERT_HISTORY]AlertEntry = undefined,
    count: usize = 0,
    write_idx: usize = 0,

    pub fn push(self: *AlertHistory, entry: AlertEntry) void {
        if (self.count < MAX_ALERT_HISTORY) {
            self.entries[self.count] = entry;
            self.count += 1;
        } else {
            // Overwrite oldest (ring buffer)
            self.entries[self.write_idx] = entry;
            self.write_idx = (self.write_idx + 1) % MAX_ALERT_HISTORY;
        }
    }

    pub fn slice(self: *const AlertHistory) []const AlertEntry {
        if (self.count < MAX_ALERT_HISTORY) {
            return self.entries[0..self.count];
        }
        return &self.entries;
    }

    pub fn len(self: *const AlertHistory) usize {
        return self.count;
    }
};

// Phase 5: Circuit Breaker for auto-reaction on critical alerts
pub const CircuitBreakerConfig = struct {
    max_critical_alerts: u32 = 3,           // Max critical alerts before tripping
    cooldown_seconds: i64 = 300,            // 5 minutes cooldown after trip
    window_seconds: i64 = 60,               // Time window to count critical alerts
    auto_restart: bool = true,              // Enable auto-restart on critical
};

pub const CircuitBreakerState = struct {
    critical_count: u32 = 0,
    window_start: i64 = 0,
    tripped_at: i64 = 0,
    is_tripped: bool = false,

    /// Check if circuit breaker should trip
    pub fn shouldTrip(self: *CircuitBreakerState, config: CircuitBreakerConfig, now: i64) bool {
        if (self.is_tripped) {
            // Check if cooldown period has passed
            return (now - self.tripped_at) < config.cooldown_seconds;
        }

        // Reset window if expired
        if (now - self.window_start > config.window_seconds) {
            self.critical_count = 0;
            self.window_start = now;
        }

        // Trip if threshold exceeded
        if (self.critical_count >= config.max_critical_alerts) {
            self.is_tripped = true;
            self.tripped_at = now;
            return true;
        }

        return false;
    }

    /// Reset circuit breaker
    pub fn reset(self: *CircuitBreakerState) void {
        self.critical_count = 0;
        self.window_start = 0;
        self.tripped_at = 0;
        self.is_tripped = false;
    }
};

// Auto-reaction callback type
pub const AutoReactionCallback = *const fn (severity: AlertSeverity, message: []const u8) anyerror!void;

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM ALERTS SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

pub const TelegramAlerts = struct {
    allocator: Allocator,
    config: TelegramConfig,
    last_alert_timestamp: i64,
    alert_history: AlertHistory,
    http_client: ?TelegramClient,  // Phase 5: Real HTTP client
    circuit_breaker: CircuitBreakerState = .{},  // Phase 5: Circuit breaker state
    circuit_config: CircuitBreakerConfig = .{},  // Phase 5: Circuit breaker config
    auto_reaction: ?AutoReactionCallback = null,  // Phase 5: Auto-reaction callback

    /// Initialize Telegram alerts system
    pub fn init(allocator: Allocator, bot_token: []const u8, chat_id: []const u8) TelegramAlerts {
        const enabled = bot_token.len > 0 and chat_id.len > 0;
        return TelegramAlerts{
            .allocator = allocator,
            .config = TelegramConfig{
                .bot_token = bot_token,
                .chat_id = chat_id,
                .enabled = enabled,
                .min_interval_seconds = 60, // Default 1 minute between alerts
            },
            .last_alert_timestamp = 0,
            .alert_history = AlertHistory{},
            .http_client = if (enabled) TelegramClient.init(allocator, bot_token) else null,
            .circuit_breaker = .{},
            .circuit_config = .{},
            .auto_reaction = null,
        };
    }

    /// Initialize disabled (no alerts will be sent)
    pub fn initDisabled(allocator: Allocator) TelegramAlerts {
        return TelegramAlerts{
            .allocator = allocator,
            .config = TelegramConfig{
                .bot_token = "",
                .chat_id = "",
                .enabled = false,
                .min_interval_seconds = 60,
            },
            .last_alert_timestamp = 0,
            .alert_history = AlertHistory{},
            .http_client = null,
            .circuit_breaker = .{},
            .circuit_config = .{},
            .auto_reaction = null,
        };
    }

    /// Set auto-reaction callback for critical alerts
    pub fn setAutoReaction(self: *TelegramAlerts, callback: AutoReactionCallback) void {
        self.auto_reaction = callback;
    }

    /// Reset circuit breaker manually
    pub fn resetCircuitBreaker(self: *TelegramAlerts) void {
        self.circuit_breaker.reset();
    }

    /// Calculate alert severity from conditions
    fn calculateSeverity(conditions: []const AlertCondition) AlertSeverity {
        for (conditions) |c| {
            if (c.current_value < c.threshold * 0.8) return .critical;
        }
        return .warning;
    }

    /// Check DHT health - returns count of triggered conditions (max 3)
    /// Caller should check conditions[0..count] for results
    pub fn checkDhtHealth(
        self: *TelegramAlerts,
        conditions: *[3]AlertCondition,
        acceptance_rate: f64,
        peer_count: u64,
        triples_stored: u64,
    ) usize {
        _ = self;
        var count: usize = 0;
        const now = std.time.timestamp();

        // Check acceptance rate < 95%
        if (acceptance_rate < 0.95) {
            conditions[count] = AlertCondition{
                .name = "acceptance_rate",
                .threshold = 0.95,
                .current_value = acceptance_rate,
                .triggered_at = now,
            };
            count += 1;
        }

        // Check peer count < 10
        if (peer_count < 10 and count < 3) {
            conditions[count] = AlertCondition{
                .name = "peer_count",
                .threshold = 10,
                .current_value = @floatFromInt(peer_count),
                .triggered_at = now,
            };
            count += 1;
        }

        // Check triples stored (warn if 0)
        if (triples_stored == 0 and count < 3) {
            conditions[count] = AlertCondition{
                .name = "triples_stored",
                .threshold = 1,
                .current_value = 0,
                .triggered_at = now,
            };
            count += 1;
        }

        return count;
    }

    /// Check if enough time has passed since last alert
    pub fn shouldSendAlert(self: *const TelegramAlerts) bool {
        if (!self.config.enabled) return false;

        const now = std.time.timestamp();
        const elapsed = now - self.last_alert_timestamp;
        return elapsed >= self.config.min_interval_seconds;
    }

    /// Format alert message for Telegram
    pub fn formatAlertMessage(
        self: *const TelegramAlerts,
        conditions: []const AlertCondition,
        recent_events: []const []const u8,
    ) ![]const u8 {
        const severity: AlertSeverity = brk: {
            var has_critical = false;
            for (conditions) |c| {
                if (c.current_value < c.threshold * 0.8) has_critical = true;
            }
            break :brk if (has_critical) .critical else .warning;
        };

        const emoji = switch (severity) {
            .info => "ℹ️",
            .warning => "⚠️",
            .critical => "🚨",
        };

        // Use a fixed buffer and then copy to allocator
        var buffer: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();

        // Header
        try writer.print("{s} *SWARM WATCH ALERT*\n\n", .{emoji});
        try writer.print("*Severity: {s}*\n\n", .{@tagName(severity)});

        // Triggered conditions
        try writer.writeAll("*Triggered Conditions:*\n");
        for (conditions, 0..) |cond, i| {
            try writer.print("  {d}. {s}: {d:.1}% (threshold: {d:.1}%)\n", .{
                i + 1,
                cond.name,
                cond.current_value * 100,
                cond.threshold * 100,
            });
        }

        const timestamp = std.time.timestamp();
        try writer.print("\n*Timestamp: {d}*\n", .{timestamp});

        // Recent events
        if (recent_events.len > 0) {
            try writer.writeAll("\n*Recent Events:*\n");
            const show_count = @min(recent_events.len, 5);
            for (recent_events[recent_events.len - show_count ..]) |event| {
                try writer.print("  • {s}\n", .{event});
            }
        }

        try writer.writeAll("\n_Dashboard: `ralph --swarm-monitor`_");

        // Copy to allocator
        const written = fbs.getWritten();
        return self.allocator.dupe(u8, written);
    }

    /// Format RICH alert message with detailed project information
    /// Includes 5+ sections: System Health, Work Results, Swarm Stats, Recent Activity, Recommendations
    pub fn formatRichAlertMessage(
        self: *const TelegramAlerts,
        conditions: []const AlertCondition,
        recent_events: []const []const u8,
        sys_stats: SystemStats,
    ) ![]const u8 {
        const allocator = self.allocator;

        // Calculate severity based on conditions
        const severity: AlertSeverity = brk: {
            var has_critical = false;
            for (conditions) |c| {
                if (c.current_value < c.threshold * 0.8) has_critical = true;
            }
            break :brk if (has_critical) .critical else .warning;
        };

        // Calculate overall system health
        const health_percent = sys_stats.calculateHealth();
        const trend_emoji = SystemStats.getTrendEmoji(sys_stats.dht_health_trend);

        // Use a larger buffer for rich messages
        var buffer: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();

        // ═════════════════════════════════════════════════════════════════════
        // HEADER
        // ═════════════════════════════════════════════════════════════════════
        const header_emoji = switch (severity) {
            .info => "ℹ️",
            .warning => "⚠️",
            .critical => "🚨",
        };

        try writer.print("{s} *TRINITY SWARM ALERT - Health Report*\n", .{header_emoji});
        try writer.writeAll("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n");

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 1: SYSTEM HEALTH
        // ═════════════════════════════════════════════════════════════════════
        try writer.print("📊 *SYSTEM HEALTH: {d:.0}% {s}*\n", .{ health_percent * 100, trend_emoji });
        try writer.print("  • DHT Acceptance: {d:.1}% (target: 95%)\n", .{sys_stats.dht_acceptance_rate * 100});
        try writer.print("  • Build Status: {s}\n", .{if (sys_stats.build_status == .passing) "✅ Passing" else "❌ Failing"});
        try writer.print("  • Tests: {d}/{d} passing\n", .{ sys_stats.tests_passing, sys_stats.tests_total });
        try writer.print("  • Peers: {d}/10 active\n\n", .{sys_stats.peer_count});

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 2: WORK RESULTS
        // ═════════════════════════════════════════════════════════════════════
        try writer.writeAll("🏆 *WORK RESULTS (Last Cycle):*\n");
        try writer.print("  • Files modified: {d}\n", .{sys_stats.files_modified});
        try writer.print("  • Total cycles: {d}\n", .{sys_stats.total_cycles});
        const uptime_hours = @as(f64, @floatFromInt(sys_stats.uptime_seconds)) / 3600.0;
        try writer.print("  • Uptime: {d:.1} hours\n\n", .{uptime_hours});

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 3: SWARM STATS
        // ═════════════════════════════════════════════════════════════════════
        try writer.writeAll("💎 *SWARM STATS:*\n");
        try writer.print("  • Triples stored: {d}\n", .{sys_stats.triples_stored});
        try writer.print("  • Triples distributed: {d}\n", .{sys_stats.triples_distributed});
        try writer.print("  • Total processed: {d}\n", .{sys_stats.triples_processed});
        const tri_amount = @as(f64, @floatFromInt(sys_stats.rewards_earned_wei)) / 1e18;
        try writer.print("  • Rewards earned: {d:.6} TRI\n", .{tri_amount});
        try writer.print("  • Peer rank: #{d}\n\n", .{sys_stats.peer_rank});

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 4: TRIGGERED CONDITIONS
        // ═════════════════════════════════════════════════════════════════════
        if (conditions.len > 0) {
            try writer.writeAll("⚠️  *TRIGGERED CONDITIONS:*\n");
            for (conditions, 0..) |cond, i| {
                const value_str = if (std.mem.eql(u8, cond.name, "acceptance_rate"))
                    try std.fmt.allocPrint(allocator, "{d:.1}%", .{cond.current_value * 100})
                else if (std.mem.eql(u8, cond.name, "peer_count"))
                    try std.fmt.allocPrint(allocator, "{d:.0}", .{cond.current_value})
                else
                    try std.fmt.allocPrint(allocator, "{d:.0}", .{cond.current_value});
                defer allocator.free(value_str);

                const threshold_str = if (std.mem.eql(u8, cond.name, "acceptance_rate"))
                    try std.fmt.allocPrint(allocator, "{d:.1}%", .{cond.threshold * 100})
                else
                    try std.fmt.allocPrint(allocator, "{d:.0}", .{cond.threshold});
                defer allocator.free(threshold_str);

                try writer.print("  {d}. *{s}*: {s} (threshold: {s})\n", .{
                    i + 1, cond.name, value_str, threshold_str,
                });
            }
            try writer.writeAll("\n");
        }

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 5: RECENT ACTIVITY
        // ═════════════════════════════════════════════════════════════════════
        if (recent_events.len > 0) {
            try writer.writeAll("📈 *RECENT ACTIVITY:*\n");
            const show_count = @min(recent_events.len, 5);
            for (recent_events[recent_events.len - show_count ..]) |event| {
                try writer.print("  • {s}\n", .{event});
            }
            try writer.writeAll("\n");
        }

        // ═════════════════════════════════════════════════════════════════════
        // SECTION 6: RECOMMENDATIONS
        // ═════════════════════════════════════════════════════════════════════
        try writer.writeAll("🔧 *RECOMMENDATIONS:*\n");
        try writer.writeAll("  1. Check DHT health: `ralph --swarm-monitor`\n");
        try writer.writeAll("  2. View full status: `ralph --status`\n");
        if (sys_stats.dht_acceptance_rate < 0.95) {
            try writer.writeAll("  3. Review: `.ralph/memory/REGRESSION_PATTERNS.md`\n");
        }
        try writer.writeAll("\n");

        // ═════════════════════════════════════════════════════════════════════
        // FOOTER
        // ═════════════════════════════════════════════════════════════════════
        const timestamp = std.time.timestamp();
        try writer.print("📅 Timestamp: {d}\n", .{timestamp});
        try writer.writeAll("📊 Dashboard: `ralph --swarm-monitor-live`");

        // Copy to allocator
        const written = fbs.getWritten();
        return allocator.dupe(u8, written);
    }

    /// Process DHT stats and send RICH alerts with system information
    pub fn processAndAlertRich(
        self: *TelegramAlerts,
        acceptance_rate: f64,
        peer_count: u64,
        triples_stored: u64,
        recent_events: []const []const u8,
        sys_stats: SystemStats,
    ) !void {
        // Check health conditions
        var conditions_buffer: [3]AlertCondition = undefined;
        const count = self.checkDhtHealth(&conditions_buffer, acceptance_rate, peer_count, triples_stored);

        // Only send alert if conditions are triggered and rate limit allows
        if (count > 0 and self.shouldSendAlert()) {
            const conditions_slice = conditions_buffer[0..count];

            // Calculate severity for circuit breaker (Phase 5)
            const severity = calculateSeverity(conditions_slice);

            // Format RICH message with system stats
            const message = try self.formatRichAlertMessage(conditions_slice, recent_events, sys_stats);
            defer self.allocator.free(message);

            // Send alert with severity (Phase 5)
            _ = try self.sendTelegramAlert(message, severity);

            // Record in history
            for (conditions_slice) |cond| {
                try self.recordAlertSent(severity, cond.name);
            }
        }
    }

    /// Send alert to Telegram (Phase 5: Real HTTP POST + Circuit Breaker)
    pub fn sendTelegramAlert(
        self: *TelegramAlerts,
        message: []const u8,
        severity: AlertSeverity,
    ) !bool {
        if (!self.config.enabled) return false;

        const now = std.time.timestamp();

        // Phase 5: Check circuit breaker
        if (self.circuit_breaker.shouldTrip(self.circuit_config, now)) {
            std.debug.print("⛔ Circuit breaker tripped - suppressing alerts\n", .{});
            return false;
        }

        // Phase 5: Track critical alerts for circuit breaker
        if (severity == .critical) {
            if (self.circuit_breaker.window_start == 0) {
                self.circuit_breaker.window_start = now;
            }
            self.circuit_breaker.critical_count += 1;

            // Phase 5: Trigger auto-reaction callback on critical
            if (self.auto_reaction) |callback| {
                callback(severity, message) catch |err| {
                    std.debug.print("⚠ Auto-reaction callback failed: {}\n", .{err});
                };
            }
        }

        // Phase 5: Use real HTTP client if available
        if (self.http_client) |client| {
            const result = try client.sendMessage(self.config.chat_id, message);

            // Log result for debugging
            switch (result) {
                .success => {
                    std.debug.print("✓ Telegram alert sent successfully\n", .{});
                    self.last_alert_timestamp = now;
                    return true;
                },
                .rate_limited => {
                    std.debug.print("⚠ Telegram rate limited, will retry\n", .{});
                    return false;
                },
                .permanent_error => {
                    std.debug.print("✗ Telegram permanent error (bad token/chat_id?)\n", .{});
                    return false;
                },
                .timeout => {
                    std.debug.print("⚠ Telegram timeout\n", .{});
                    return false;
                },
            }
        } else {
            // Fallback: log the rich alert message (should not happen with valid config)
            std.debug.print("\n" ++ "═" ** 40 ++ "\n", .{});
            std.debug.print("TELEGRAM ALERT (RICH FORMAT - NO HTTP CLIENT):\n{s}\n", .{message});
            std.debug.print("═" ** 40 ++ "\n\n", .{});
        }

        // Record that alert was sent (even if only logged)
        self.last_alert_timestamp = now;
        return true;
    }

    /// Record alert in history
    pub fn recordAlertSent(
        self: *TelegramAlerts,
        severity: AlertSeverity,
        condition_name: []const u8,
    ) !void {
        const entry = AlertEntry{
            .severity = severity,
            .condition = condition_name,
            .timestamp = std.time.timestamp(),
            .sent = true,
        };

        self.alert_history.push(entry);
    }

    /// Get alert history
    pub fn getAlertHistory(self: *const TelegramAlerts) []const AlertEntry {
        return self.alert_history.slice();
    }

    /// Process DHT stats and send alerts if conditions met
    pub fn processAndAlert(
        self: *TelegramAlerts,
        acceptance_rate: f64,
        peer_count: u64,
        triples_stored: u64,
        recent_events: []const []const u8,
    ) !void {
        // Check health conditions
        var conditions_buffer: [3]AlertCondition = undefined;
        const count = self.checkDhtHealth(&conditions_buffer, acceptance_rate, peer_count, triples_stored);

        // Only send alert if conditions are triggered and rate limit allows
        if (count > 0 and self.shouldSendAlert()) {
            const conditions_slice = conditions_buffer[0..count];

            // Calculate severity for circuit breaker (Phase 5)
            const severity = calculateSeverity(conditions_slice);

            // Format message
            const message = try self.formatAlertMessage(conditions_slice, recent_events);
            defer self.allocator.free(message);

            // Send alert with severity (Phase 5)
            _ = try self.sendTelegramAlert(message, severity);

            // Record in history
            for (conditions_slice) |cond| {
                try self.recordAlertSent(severity, cond.name);
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "telegram_alerts: init_disabled" {
    const allocator = std.testing.allocator;
    const alerts = TelegramAlerts.initDisabled(allocator);
    try std.testing.expect(!alerts.config.enabled);
}

test "telegram_alerts: check_dht_health_all_good" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    var conditions_buffer: [3]AlertCondition = undefined;
    const count = alerts.checkDhtHealth(&conditions_buffer, 0.98, 15, 100);

    try std.testing.expectEqual(@as(usize, 0), count);
}

test "telegram_alerts: check_dht_health_acceptance_low" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    var conditions_buffer: [3]AlertCondition = undefined;
    const count = alerts.checkDhtHealth(&conditions_buffer, 0.90, 15, 100);

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqualStrings("acceptance_rate", conditions_buffer[0].name);
}

test "telegram_alerts: check_dht_health_peers_low" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    var conditions_buffer: [3]AlertCondition = undefined;
    const count = alerts.checkDhtHealth(&conditions_buffer, 0.98, 5, 100);

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqualStrings("peer_count", conditions_buffer[0].name);
}

test "telegram_alerts: check_dht_health_multiple_issues" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    var conditions_buffer: [3]AlertCondition = undefined;
    const count = alerts.checkDhtHealth(&conditions_buffer, 0.85, 3, 0);

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "telegram_alerts: should_send_respects_min_interval" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);
    alerts.config.enabled = true; // Manually enable for this test
    alerts.config.min_interval_seconds = 60;
    alerts.last_alert_timestamp = std.time.timestamp() - 30; // 30s ago

    try std.testing.expect(!alerts.shouldSendAlert()); // Too soon
}

test "telegram_alerts: should_send_after_min_interval" {
    const allocator = std.testing.allocator;
    // Use init with empty token/chat to get enabled=false, or directly set enabled
    var alerts = TelegramAlerts.initDisabled(allocator);
    alerts.config.enabled = true; // Manually enable for this test
    alerts.config.min_interval_seconds = 60;
    alerts.last_alert_timestamp = std.time.timestamp() - 61; // 61s ago

    try std.testing.expect(alerts.shouldSendAlert()); // OK to send
}

test "telegram_alerts: alert_history_tracks_entries" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    try alerts.recordAlertSent(.warning, "acceptance_rate");
    try alerts.recordAlertSent(.critical, "peer_count");

    const history = alerts.getAlertHistory();
    try std.testing.expectEqual(@as(usize, 2), history.len);
    try std.testing.expectEqualStrings("acceptance_rate", history[0].condition);
    try std.testing.expectEqualStrings("peer_count", history[1].condition);
}

test "telegram_alerts: alert_history_max_100" {
    const allocator = std.testing.allocator;
    var alerts = TelegramAlerts.initDisabled(allocator);

    // Add 105 entries (more than MAX_ALERT_HISTORY)
    var i: usize = 0;
    while (i < 105) : (i += 1) {
        try alerts.recordAlertSent(.info, "test_condition");
    }

    const history = alerts.getAlertHistory();
    try std.testing.expectEqual(@as(usize, 100), history.len); // Capped at 100
}
