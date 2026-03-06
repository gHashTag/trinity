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
