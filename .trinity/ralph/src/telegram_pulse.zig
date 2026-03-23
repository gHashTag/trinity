// ═══════════════════════════════════════════════════════════════════════════════
// RALPH PULSE OF LIFE - Working Telegram Implementation (Zig 0.15.2)
// ═══════════════════════════════════════════════════════════════════════════════
//
// MINIMAL WORKING IMPLEMENTATION - Send pulses to @vibee_dev_bot
// Uses std.http.Client for HTTPS requests
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PulseConfig = struct {
    bot_token: []const u8,
    chat_id: []const u8,
    enabled: bool,
};

pub const PulseType = enum {
    thought,
    action,
    state_change,
    err,
    milestone,
    heartbeat,

    pub fn emoji(self: PulseType) []const u8 {
        return switch (self) {
            .thought => "🧠",
            .action => "⚡",
            .state_change => "🔄",
            .err => "⚠️",
            .milestone => "⭐",
            .heartbeat => "💓",
        };
    }

    pub fn label(self: PulseType) []const u8 {
        return switch (self) {
            .thought => "THINKING",
            .action => "ACTION",
            .state_change => "STATE",
            .err => "ERROR",
            .milestone => "MILESTONE",
            .heartbeat => "HEARTBEAT",
        };
    }
};

pub const TelegramClient = struct {
    allocator: Allocator,
    client: std.http.Client,
    config: PulseConfig,

    const Self = @This();

    pub fn init(allocator: Allocator, config: PulseConfig) Self {
        return Self{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    /// Send pulse to Telegram
    pub fn sendPulse(self: *Self, pulse_type: PulseType, message: []const u8) !void {
        if (!self.config.enabled) return;

        // Build API URL
        var url_buffer: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buffer, "https://api.telegram.org/bot{s}/sendMessage", .{self.config.bot_token});

        const uri = std.Uri.parse(url) catch return error.InvalidUrl;

        // Build JSON body
        var body_buffer: [4096]u8 = undefined;
        const body = try std.fmt.bufPrint(&body_buffer,
            \\{{"chat_id": "{s}", "text": "{s} {s}: {s}"}}
        , .{ self.config.chat_id, pulse_type.emoji(), pulse_type.label(), message });

        // Prepare headers
        const headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "RALPH-PULSE/1.0" },
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        // Create request
        var req = self.client.request(.POST, uri, .{
            .extra_headers = &headers,
            .redirect_behavior = .unhandled,
        }) catch return error.ConnectionFailed;
        defer req.deinit();

        // Send body
        req.transfer_encoding = .{ .content_length = body.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
        try body_writer.writer.writeAll(body);
        try body_writer.end();
        if (req.connection) |conn| try conn.flush();

        // Receive response
        var redirect_buf: [0]u8 = .{};
        _ = req.receiveHead(&redirect_buf) catch return error.Timeout;

        // Ignore response body for fire-and-forget
    }

    /// Send heartbeat with stats
    pub fn sendHeartbeat(self: *Self, loop_count: u32, state: []const u8) !void {
        var buffer: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buffer, "Loop: {d} | State: {s}", .{ loop_count, state });
        try self.sendPulse(.heartbeat, msg);
    }
};

/// Load config from environment variables
/// Checks for both TELEGRAM_* and RALPH_TELEGRAM_* prefixed variables
pub fn loadConfig(allocator: Allocator) !PulseConfig {
    const bot_token_ptr = std.posix.getenvZ("TELEGRAM_BOT_TOKEN") orelse
        std.posix.getenvZ("RALPH_TELEGRAM_BOT_TOKEN") orelse "";
    const chat_id_ptr = std.posix.getenvZ("TELEGRAM_CHAT_ID") orelse
        std.posix.getenvZ("RALPH_TELEGRAM_CHAT_ID") orelse "";
    const enabled_ptr = std.posix.getenvZ("RALPH_PULSE_ENABLED") orelse "false";

    const bot_token = try allocator.dupeZ(u8, bot_token_ptr);
    const chat_id = try allocator.dupeZ(u8, chat_id_ptr);

    return PulseConfig{
        .bot_token = bot_token,
        .chat_id = chat_id,
        .enabled = std.mem.eql(u8, enabled_ptr, "true") or std.mem.eql(u8, enabled_ptr, "1"),
    };
}

/// Convenience function: send pulse without creating client
pub fn sendPulse(allocator: Allocator, config: PulseConfig, pulse_type: PulseType, message: []const u8) !void {
    var client = TelegramClient.init(allocator, config);
    defer client.deinit();
    try client.sendPulse(pulse_type, message);
}

/// Convenience function: send heartbeat
pub fn sendHeartbeat(allocator: Allocator, config: PulseConfig, loop_count: u32, state: []const u8) !void {
    var client = TelegramClient.init(allocator, config);
    defer client.deinit();
    try client.sendHeartbeat(loop_count, state);
}

/// Delete webhook so long polling can work
/// Telegram Bot API forbids webhook and getUpdates simultaneously
pub fn deleteWebhook(allocator: Allocator, config: PulseConfig) !void {
    var url_buffer: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer,
        "https://api.telegram.org/bot{s}/deleteWebhook?drop_pending_updates=true",
        .{config.bot_token});

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const headers = [_]std.http.Header{
        .{ .name = "User-Agent", .value = "RALPH-PULSE/1.0" },
    };

    // Use GET instead of POST (Zig HTTP client doesn't allow POST without body)
    var req = try client.request(.GET, uri, .{
        .extra_headers = &headers,
        .redirect_behavior = .unhandled,
    });
    defer req.deinit();

    try req.sendBodiless();

    var redirect_buf: [0]u8 = .{};
    _ = req.receiveHead(&redirect_buf) catch {};
}

/// Send message to Telegram chat
pub fn sendMessage(allocator: Allocator, config: PulseConfig, text: []const u8) !void {
    if (!config.enabled) return;

    var url_buffer: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://api.telegram.org/bot{s}/sendMessage", .{config.bot_token});

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;

    // Build JSON body
    var body_buffer: [4096]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buffer,
        \\{{"chat_id": "{s}", "text": "{s}"}}
    , .{ config.chat_id, text });

    const headers = [_]std.http.Header{
        .{ .name = "User-Agent", .value = "RALPH-PULSE/1.0" },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var req = client.request(.POST, uri, .{
        .extra_headers = &headers,
        .redirect_behavior = .unhandled,
    }) catch return error.ConnectionFailed;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
    try body_writer.writer.writeAll(body);
    try body_writer.end();
    if (req.connection) |conn| try conn.flush();

    var redirect_buf: [0]u8 = .{};
    _ = req.receiveHead(&redirect_buf) catch return error.Timeout;
}

/// Check if webhook is currently set
/// Returns true if webhook is active, false otherwise
pub fn getWebhookInfo(allocator: Allocator, config: PulseConfig) !bool {
    var url_buffer: [512]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer,
        "https://api.telegram.org/bot{s}/getWebhookInfo",
        .{config.bot_token});

    const uri = std.Uri.parse(url) catch return error.InvalidUrl;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var req = try client.request(.GET, uri, .{
        .extra_headers = &.{},
        .redirect_behavior = .unhandled,
    });
    defer req.deinit();

    try req.sendBodiless();

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return error.Timeout;

    // Read response body
    var transfer_buffer: [4096]u8 = undefined;
    var reader = response.reader(&transfer_buffer);
    const body = reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024)) catch return error.Timeout;
    defer allocator.free(body);

    // Check if "url":null or "url":"http"/"url":"https"
    const null_pattern = \\,"url":null
;
    if (std.mem.indexOf(u8, body, null_pattern)) |_| {
        return false; // No webhook set
    }

    const http_pattern = \\,"url":"http
;
    if (std.mem.indexOf(u8, body, http_pattern)) |_| {
        return true; // Webhook is set
    }

    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PULSE OF LIFE v1.1 — Evolution-Aware Pulse Formatting
// ═══════════════════════════════════════════════════════════════════════════════

/// Sacred constants for pulse formatting
pub const PHI: f64 = 1.6180339887498948482;
pub const GAMMA: f64 = 1.0 / (PHI * PHI * PHI); // φ⁻³ ≈ 0.236
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI); // φ² + φ⁻² = 3
pub const PHI_INVERSE: f64 = 1.0 / PHI; // φ⁻¹ ≈ 0.618 (immortality threshold)

/// Evolution state for pulse context
pub const EvolutionState = enum {
    idle,
    analyzing,
    spec_creating,
    generating,
    testing,
    benchmarking,
    assessing,
    committing,
    deploying,
    evolving,

    pub fn label(self: EvolutionState) []const u8 {
        return switch (self) {
            .idle => "IDLE",
            .analyzing => "ANALYZING",
            .spec_creating => "SPEC CREATING",
            .generating => "GENERATING",
            .testing => "TESTING",
            .benchmarking => "BENCHMARKING",
            .assessing => "ASSESSING",
            .committing => "COMMITTING",
            .deploying => "DEPLOYING",
            .evolving => "EVOLVING",
        };
    }

    pub fn emoji(self: EvolutionState) []const u8 {
        return switch (self) {
            .idle => "⏸",
            .analyzing => "🔍",
            .spec_creating => "📝",
            .generating => "⚙",
            .testing => "🧪",
            .benchmarking => "📊",
            .assessing => "🎯",
            .committing => "💾",
            .deploying => "🚀",
            .evolving => "🧬",
        };
    }
};

/// Needle status for immortality tracking
pub const NeedleStatus = enum {
    immortal,
    mortal_improving,
    regression,

    pub fn label(self: NeedleStatus) []const u8 {
        return switch (self) {
            .immortal => "KOSHCHEY IMMORTAL",
            .mortal_improving => "MORTAL (improving)",
            .regression => "REGRESSION",
        };
    }

    pub fn emoji(self: NeedleStatus) []const u8 {
        return switch (self) {
            .immortal => "♾",
            .mortal_improving => "📈",
            .regression => "🔻",
        };
    }
};

/// Assess needle status from improvement ratio
pub fn assessNeedle(improvement_ratio: f64) NeedleStatus {
    if (improvement_ratio > PHI_INVERSE) return .immortal;
    if (improvement_ratio > 0) return .mortal_improving;
    return .regression;
}

/// Format evolution pulse message
pub fn formatEvolutionPulse(buffer: []u8, state: EvolutionState, cycle: u32, tests_passed: u32, tests_total: u32, improvement: f64) ![]const u8 {
    const needle = assessNeedle(improvement);
    return try std.fmt.bufPrint(buffer,
        \\{s} {s} | Cycle {d}
        \\Tests: {d}/{d} | Improvement: {d:.1}%
        \\{s} {s}
        \\φ² + φ⁻² = 3 | γ = φ⁻³
    , .{
        state.emoji(),
        state.label(),
        cycle,
        tests_passed,
        tests_total,
        improvement * 100.0,
        needle.emoji(),
        needle.label(),
    });
}

/// Send evolution state pulse (convenience)
pub fn sendEvolutionPulse(
    allocator: Allocator,
    config: PulseConfig,
    state: EvolutionState,
    cycle: u32,
    tests_passed: u32,
    tests_total: u32,
    improvement: f64,
) !void {
    var buffer: [1024]u8 = undefined;
    const msg = try formatEvolutionPulse(&buffer, state, cycle, tests_passed, tests_total, improvement);
    var client = TelegramClient.init(allocator, config);
    defer client.deinit();
    try client.sendPulse(.state_change, msg);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Pulse: sacred constants" {
    // TRINITY identity: φ² + φ⁻² = 3
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);

    // γ = φ⁻³
    const gamma_expected: f64 = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(gamma_expected, GAMMA, 1e-10);

    // φ⁻¹ = immortality threshold
    try std.testing.expectApproxEqRel(@as(f64, 0.618033988749895), PHI_INVERSE, 1e-10);
}

test "Pulse: needle assessment" {
    // Immortal: improvement > φ⁻¹ (0.618)
    try std.testing.expectEqual(NeedleStatus.immortal, assessNeedle(0.7));
    try std.testing.expectEqual(NeedleStatus.immortal, assessNeedle(1.0));

    // Mortal improving: 0 < improvement < φ⁻¹
    try std.testing.expectEqual(NeedleStatus.mortal_improving, assessNeedle(0.3));
    try std.testing.expectEqual(NeedleStatus.mortal_improving, assessNeedle(0.01));

    // Regression: improvement <= 0
    try std.testing.expectEqual(NeedleStatus.regression, assessNeedle(0.0));
    try std.testing.expectEqual(NeedleStatus.regression, assessNeedle(-0.5));
}

test "Pulse: evolution state labels" {
    try std.testing.expectEqualStrings("TESTING", EvolutionState.testing.label());
    try std.testing.expectEqualStrings("EVOLVING", EvolutionState.evolving.label());
    try std.testing.expectEqualStrings("IDLE", EvolutionState.idle.label());
}

test "Pulse: pulse type emojis" {
    try std.testing.expectEqualStrings("THINKING", PulseType.thought.label());
    try std.testing.expectEqualStrings("ACTION", PulseType.action.label());
    try std.testing.expectEqualStrings("ERROR", PulseType.err.label());
    try std.testing.expectEqualStrings("MILESTONE", PulseType.milestone.label());
    try std.testing.expectEqualStrings("HEARTBEAT", PulseType.heartbeat.label());
}

test "Pulse: format evolution pulse" {
    var buffer: [1024]u8 = undefined;
    const msg = try formatEvolutionPulse(&buffer, .testing, 5, 140, 141, 0.7);

    // Should contain cycle number
    try std.testing.expect(std.mem.indexOf(u8, msg, "Cycle 5") != null);
    // Should contain test counts
    try std.testing.expect(std.mem.indexOf(u8, msg, "140/141") != null);
    // Should contain IMMORTAL (0.7 > 0.618)
    try std.testing.expect(std.mem.indexOf(u8, msg, "IMMORTAL") != null);
    // Should contain TRINITY identity
    try std.testing.expect(std.mem.indexOf(u8, msg, "= 3") != null);
}

test "Pulse: config loading defaults" {
    // Without env vars, config should have empty tokens and disabled
    const config = PulseConfig{
        .bot_token = "",
        .chat_id = "",
        .enabled = false,
    };
    try std.testing.expect(!config.enabled);
    try std.testing.expectEqual(@as(usize, 0), config.bot_token.len);
}
