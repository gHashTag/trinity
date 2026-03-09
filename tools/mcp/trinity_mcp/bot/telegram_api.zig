// telegram_api.zig — Telegram Bot API: getUpdates (long poll) + sendMessage + sendMessageDraft
// Pattern from agent/telegram.zig (send) and agent/github_poller.zig (HTTP GET)
const std = @import("std");

pub const BotConfig = struct {
    bot_token: []const u8,
    chat_id: []const u8,
    project_root: []const u8,
    max_turns: u32,
};

/// Poll Telegram getUpdates with long polling.
/// Returns raw JSON response body or null on error.
pub fn getUpdates(allocator: std.mem.Allocator, bot_token: []const u8, offset: i64) ?[]const u8 {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/getUpdates?timeout=30&offset={d}", .{ bot_token, offset }) catch return null;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &aw.writer,
    }) catch |err| {
        log("getUpdates error: {s}", .{@errorName(err)});
        return null;
    };

    if (result.status != .ok) {
        log("getUpdates status: {d}", .{@intFromEnum(result.status)});
        return null;
    }

    const body = aw.written();
    return allocator.dupe(u8, body) catch null;
}

/// Send a message via Telegram Bot API sendMessage.
pub fn sendMessage(allocator: std.mem.Allocator, bot_token: []const u8, chat_id: []const u8, text: []const u8) void {
    sendToEndpoint(allocator, bot_token, chat_id, "sendMessage", text);
}

/// Send a streaming draft via Telegram Bot API 9.5 sendMessageDraft.
pub fn sendDraft(allocator: std.mem.Allocator, bot_token: []const u8, chat_id: []const u8, text: []const u8) void {
    sendToEndpoint(allocator, bot_token, chat_id, "sendMessageDraft", text);
}

/// Send a formatted message.
pub fn sendFmt(allocator: std.mem.Allocator, bot_token: []const u8, chat_id: []const u8, buf: []u8, comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.bufPrint(buf, fmt, args) catch return;
    sendMessage(allocator, bot_token, chat_id, msg);
}

fn sendToEndpoint(allocator: std.mem.Allocator, bot_token: []const u8, chat_id: []const u8, endpoint: []const u8, text: []const u8) void {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/{s}", .{ bot_token, endpoint }) catch return;

    // Build JSON body with manual escaping
    var body_buf: [8192]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    const mid = "\",\"text\":\"";
    @memcpy(body_buf[i..][0..mid.len], mid);
    i += mid.len;

    // JSON-escape the text
    for (text) |c| {
        if (i + 2 >= body_buf.len - 10) break;
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
        log("send error: {s}", .{@errorName(err)});
        return;
    };

    if (result.status != .ok) {
        log("API {s} status: {d}", .{ endpoint, @intFromEnum(result.status) });
    }
}

/// Send a potentially long message, splitting at 4000 char boundary.
/// Shared by handlers and streaming.
pub fn sendLongMessage(allocator: std.mem.Allocator, config: BotConfig, text: []const u8) void {
    const max_len: usize = 4000;
    var pos: usize = 0;

    while (pos < text.len) {
        const end = @min(pos + max_len, text.len);
        var split = end;
        if (end < text.len) {
            var j = end;
            while (j > pos + max_len / 2) : (j -= 1) {
                if (text[j] == '\n') {
                    split = j + 1;
                    break;
                }
            }
        }
        const chunk = text[pos..split];
        sendMessage(allocator, config.bot_token, config.chat_id, chunk);
        pos = split;
    }
}

fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[tri-bot] " ++ fmt ++ "\n", args);
}
