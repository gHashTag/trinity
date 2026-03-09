// claude_stream.zig — Streaming via direct Anthropic API (SSE)
// POST to api.anthropic.com/v1/messages with stream:true, parse SSE events,
// send Telegram drafts every 500ms, final message when done.
// No claude CLI dependency. Pure Zig std.http.Client.
const std = @import("std");
const telegram_api = @import("telegram_api.zig");

const BotConfig = telegram_api.BotConfig;

const api_url = "https://api.anthropic.com/v1/messages";
const api_version = "2023-06-01";
const default_model = "claude-sonnet-4-20250514";

/// Shared state between main thread (polling) and worker thread (streaming).
pub const StreamState = struct {
    is_busy: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    cancel_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

/// Options for streaming /ask.
pub const StreamOpts = struct {
    args: []const u8, // prompt text (caller-owned, freed by worker)
    model: ?[]const u8 = null, // model override
};

/// Worker thread entry point: POST to Anthropic API, stream SSE, send drafts.
pub fn runStreaming(
    allocator: std.mem.Allocator,
    config: BotConfig,
    opts: StreamOpts,
    state: *StreamState,
) void {
    defer {
        state.cancel_requested.store(false, .release);
        state.is_busy.store(false, .release);
        allocator.free(opts.args);
    }

    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa7\xa0 TRI streaming...");

    const model = opts.model orelse default_model;

    // Build request body
    var body_buf: std.ArrayList(u8) = .empty;
    defer body_buf.deinit(allocator);

    buildRequestBody(allocator, &body_buf, model, opts.args) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to build request");
        return;
    };

    std.debug.print("[tri-bot] SSE request: {d} bytes, model={s}\n", .{ body_buf.items.len, model });

    // HTTP POST to Anthropic API
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(api_url) catch unreachable;

    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "x-api-key", .value = config.api_key },
            .{ .name = "anthropic-version", .value = api_version },
        },
    }) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Connection failed");
        return;
    };
    defer req.deinit();

    // Send body
    req.transfer_encoding = .{ .content_length = body_buf.items.len };
    var bw = req.sendBodyUnflushed(&.{}) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Send failed");
        return;
    };
    bw.writer.writeAll(body_buf.items) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Write failed");
        return;
    };
    bw.end() catch {};
    if (req.connection) |conn| conn.flush() catch {};

    // Receive response head
    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c No response from API");
        return;
    };

    // Check for HTTP errors
    const status = @intFromEnum(response.head.status);
    if (status >= 400) {
        handleApiError(allocator, config, &response, status);
        return;
    }

    std.debug.print("[tri-bot] SSE stream started (status {d})\n", .{status});

    // Read SSE stream line-by-line
    var transfer_buf: [8192]u8 = undefined;
    var reader = response.reader(&transfer_buf);

    var text_buf: std.ArrayList(u8) = .empty;
    defer text_buf.deinit(allocator);

    var last_draft_ns: i128 = std.time.nanoTimestamp();
    const draft_interval: i128 = 500_000_000; // 500ms

    var line_buf: [65536]u8 = undefined;
    var line_len: usize = 0;
    var read_chunk: [4096]u8 = undefined;

    while (true) {
        if (state.cancel_requested.load(.acquire)) break;

        const n = reader.readSliceShort(&read_chunk) catch break;

        for (read_chunk[0..n]) |byte| {
            if (byte == '\n') {
                const line = line_buf[0..line_len];

                // Parse SSE: "data: {json}"
                if (line.len > 6 and std.mem.eql(u8, line[0..6], "data: ")) {
                    const json = line[6..];
                    if (extractTextDelta(json)) |text_val| {
                        text_buf.appendSlice(allocator, text_val) catch {};
                    }
                }
                line_len = 0;

                // Throttle: sendDraft every 500ms
                const now = std.time.nanoTimestamp();
                if (now - last_draft_ns >= draft_interval and text_buf.items.len > 0) {
                    const draft_len = @min(text_buf.items.len, 4000);
                    telegram_api.sendDraft(allocator, config.bot_token, config.chat_id, text_buf.items[0..draft_len]);
                    last_draft_ns = now;
                }
            } else if (line_len < line_buf.len - 1) {
                line_buf[line_len] = byte;
                line_len += 1;
            }
        }
    }

    std.debug.print("[tri-bot] SSE done ({d} bytes text)\n", .{text_buf.items.len});

    // Send final message
    if (text_buf.items.len > 0) {
        telegram_api.sendLongMessage(allocator, config, text_buf.items);
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Empty response from API");
    }
}

/// Build JSON request body for Anthropic Messages API (streaming).
fn buildRequestBody(allocator: std.mem.Allocator, body: *std.ArrayList(u8), model: []const u8, prompt: []const u8) !void {
    try body.appendSlice(allocator, "{\"model\":\"");
    try body.appendSlice(allocator, model);
    try body.appendSlice(allocator, "\",\"max_tokens\":8192,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"");
    // JSON-escape prompt
    for (prompt) |c| {
        switch (c) {
            '"' => try body.appendSlice(allocator, "\\\""),
            '\\' => try body.appendSlice(allocator, "\\\\"),
            '\n' => try body.appendSlice(allocator, "\\n"),
            '\r' => try body.appendSlice(allocator, "\\r"),
            '\t' => try body.appendSlice(allocator, "\\t"),
            else => try body.append(allocator, c),
        }
    }
    try body.appendSlice(allocator, "\"}]}");
}

/// Extract text from SSE content_block_delta event.
/// Input: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
/// Returns: "Hello"
fn extractTextDelta(json: []const u8) ?[]const u8 {
    // Find "text_delta","text":" — the text field after the delta type
    const needle = "\"text_delta\",\"text\":\"";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= json.len) return null;
    var end = start;
    while (end < json.len) : (end += 1) {
        if (json[end] == '"' and (end == start or json[end - 1] != '\\')) break;
    }
    if (end == start) return null;
    return json[start..end];
}

/// Handle API error response — read body and send error to Telegram.
fn handleApiError(allocator: std.mem.Allocator, config: BotConfig, response: *std.http.Client.Response, status: u16) void {
    var transfer_buf: [8192]u8 = undefined;
    var reader = response.reader(&transfer_buf);
    const err_body = reader.allocRemaining(allocator, std.Io.Limit.limited(4096)) catch {
        var buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x8c API error: HTTP {d}", .{status});
        return;
    };
    defer allocator.free(err_body);

    // Try to extract error message from JSON
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"message\":\"", .{}) catch {
        var buf: [256]u8 = undefined;
        telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x8c API error: HTTP {d}", .{status});
        return;
    };
    if (std.mem.indexOf(u8, err_body, needle)) |idx| {
        const msg_start = idx + needle.len;
        if (msg_start < err_body.len) {
            var msg_end = msg_start;
            while (msg_end < err_body.len and err_body[msg_end] != '"') : (msg_end += 1) {}
            const msg = err_body[msg_start..msg_end];
            var buf: [512]u8 = undefined;
            telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x8c API {d}: {s}", .{ status, msg });
            return;
        }
    }

    var buf: [256]u8 = undefined;
    telegram_api.sendFmt(allocator, config.bot_token, config.chat_id, &buf, "\xe2\x9d\x8c API error: HTTP {d}", .{status});
}

/// Cancel the active streaming request.
pub fn stopProcess(allocator: std.mem.Allocator, config: BotConfig, state: *StreamState) void {
    if (state.is_busy.load(.acquire)) {
        state.cancel_requested.store(true, .release);
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9b\x94 Cancelling request...");
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 No active request");
    }
}
