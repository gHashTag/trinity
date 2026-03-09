// telegram.zig — Fire-and-forget Telegram sender for ralph-agent
// Uses sendMessage + sendMessageDraft (Bot API 9.5 streaming)
// Pattern from oracle_watchdog.zig:515-598
const std = @import("std");

pub const TelegramConfig = struct {
    bot_token: []const u8,
    chat_id: []const u8,
    enabled: bool,
};

/// Send a final message via Telegram Bot API sendMessage.
/// Fire-and-forget: errors logged to stderr, never propagated.
pub fn send(config: TelegramConfig, text: []const u8) void {
    if (!config.enabled) return;
    sendToEndpoint(config, "sendMessage", text);
}

/// Send a streaming draft via Telegram Bot API 9.5 sendMessageDraft.
/// Repeated calls with growing text = live streaming in chat.
pub fn sendDraft(config: TelegramConfig, text: []const u8) void {
    if (!config.enabled) return;
    sendToEndpoint(config, "sendMessageDraft", text);
}

/// Format a message and send it.
pub fn sendFmt(config: TelegramConfig, buf: []u8, comptime fmt: []const u8, args: anytype) void {
    if (!config.enabled) return;
    const msg = std.fmt.bufPrint(buf, fmt, args) catch return;
    send(config, msg);
}

fn sendToEndpoint(config: TelegramConfig, endpoint: []const u8, text: []const u8) void {
    // Build URL: https://api.telegram.org/bot{token}/{endpoint}
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/{s}", .{ config.bot_token, endpoint }) catch return;

    // Build JSON body with manual escaping
    var body_buf: [4096]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..config.chat_id.len], config.chat_id);
    i += config.chat_id.len;

    const mid = "\",\"text\":\"";
    @memcpy(body_buf[i..][0..mid.len], mid);
    i += mid.len;

    // JSON-escape the text
    for (text) |c| {
        if (i + 2 >= body_buf.len - 30) break; // reserve space for suffix
        switch (c) {
            '"' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'r';
                i += 2;
            },
            else => {
                body_buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= body_buf.len) {
        @memcpy(body_buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    const body = body_buf[0..i];

    // Fire-and-forget HTTP POST (internal GPA per-call)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch |err| {
        std.debug.print("[telegram] send error: {s}\n", .{@errorName(err)});
        return;
    };

    if (result.status != .ok) {
        std.debug.print("[telegram] API returned status {d}\n", .{@intFromEnum(result.status)});
    }
}

test "TelegramConfig disabled does not crash" {
    const config = TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    send(config, "test");
    sendDraft(config, "test");
}
