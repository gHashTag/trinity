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

/// Send message and return message_id for future edits.
/// Returns null on error or if disabled.
pub fn sendAndCapture(config: TelegramConfig, text: []const u8) ?i64 {
    if (!config.enabled) return null;

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{config.bot_token}) catch return null;

    var body_buf: [4096]u8 = undefined;
    const body = buildJsonBody(&body_buf, config.chat_id, null, text) orelse return null;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
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
        std.debug.print("[telegram] sendAndCapture error: {s}\n", .{@errorName(err)});
        return null;
    };

    if (result.status != .ok) {
        std.debug.print("[telegram] sendAndCapture status {d}\n", .{@intFromEnum(result.status)});
        return null;
    }

    // Parse message_id from response: {"ok":true,"result":{"message_id":123,...}}
    const resp = aw.written();
    return extractMessageId(resp);
}

/// Edit existing message by message_id.
pub fn editMessage(config: TelegramConfig, message_id: i64, text: []const u8) void {
    if (!config.enabled) return;

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/editMessageText", .{config.bot_token}) catch return;

    var body_buf: [4096]u8 = undefined;
    const body = buildJsonBody(&body_buf, config.chat_id, message_id, text) orelse return;

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
        std.debug.print("[telegram] editMessage error: {s}\n", .{@errorName(err)});
        return;
    };

    if (result.status != .ok) {
        std.debug.print("[telegram] editMessage status {d}\n", .{@intFromEnum(result.status)});
    }
}

/// Pin a message in the chat.
pub fn pinMessage(config: TelegramConfig, message_id: i64) void {
    if (!config.enabled) return;

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/pinChatMessage", .{config.bot_token}) catch return;

    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{{\"chat_id\":\"{s}\",\"message_id\":{d}}}", .{ config.chat_id, message_id }) catch return;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    _ = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch return;
}

/// Build JSON body: {"chat_id":"...","message_id":N,"text":"..."}
fn buildJsonBody(buf: []u8, chat_id: []const u8, message_id: ?i64, text: []const u8) ?[]const u8 {
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    if (message_id) |mid| {
        const mid_prefix = "\",\"message_id\":";
        @memcpy(buf[i..][0..mid_prefix.len], mid_prefix);
        i += mid_prefix.len;

        // Format message_id as integer
        var num_buf: [20]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{mid}) catch return null;
        @memcpy(buf[i..][0..num_str.len], num_str);
        i += num_str.len;

        const text_prefix = ",\"text\":\"";
        @memcpy(buf[i..][0..text_prefix.len], text_prefix);
        i += text_prefix.len;
    } else {
        const text_prefix = "\",\"text\":\"";
        @memcpy(buf[i..][0..text_prefix.len], text_prefix);
        i += text_prefix.len;
    }

    // JSON-escape the text
    for (text) |c| {
        if (i + 2 >= buf.len - 30) break;
        switch (c) {
            '"' => {
                buf[i] = '\\';
                buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                buf[i] = '\\';
                buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                buf[i] = '\\';
                buf[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                buf[i] = '\\';
                buf[i + 1] = 'r';
                i += 2;
            },
            else => {
                buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= buf.len) {
        @memcpy(buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    return buf[0..i];
}

/// Extract "message_id":N from Telegram API response.
fn extractMessageId(json: []const u8) ?i64 {
    const needle = "\"message_id\":";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;

    var end = start;
    while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '-')) : (end += 1) {}
    if (end == start) return null;

    return std.fmt.parseInt(i64, json[start..end], 10) catch null;
}

test "TelegramConfig disabled does not crash" {
    const config = TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    send(config, "test");
    sendDraft(config, "test");
}

test "sendAndCapture disabled returns null" {
    const config = TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    try std.testing.expectEqual(@as(?i64, null), sendAndCapture(config, "test"));
}

test "editMessage disabled does not crash" {
    const config = TelegramConfig{ .bot_token = "", .chat_id = "", .enabled = false };
    editMessage(config, 12345, "test");
}

test "extractMessageId" {
    const json = "{\"ok\":true,\"result\":{\"message_id\":12345,\"from\":{}}}";
    try std.testing.expectEqual(@as(?i64, 12345), extractMessageId(json));
}

test "buildJsonBody without message_id" {
    var buf: [512]u8 = undefined;
    const result = buildJsonBody(&buf, "123", null, "hello") orelse return error.BuildFailed;
    try std.testing.expect(std.mem.indexOf(u8, result, "\"chat_id\":\"123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"text\":\"hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "message_id") == null);
}

test "buildJsonBody with message_id" {
    var buf: [512]u8 = undefined;
    const result = buildJsonBody(&buf, "123", 456, "hello") orelse return error.BuildFailed;
    try std.testing.expect(std.mem.indexOf(u8, result, "\"message_id\":456") != null);
}
