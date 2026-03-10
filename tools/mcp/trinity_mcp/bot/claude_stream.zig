// claude_stream.zig — Streaming via direct Anthropic API (SSE)
// POST to api.anthropic.com/v1/messages with stream:true, parse SSE events,
// send Telegram drafts every 500ms, final message when done.
// No claude CLI dependency. Pure Zig std.http.Client.
const std = @import("std");
const telegram_api = @import("telegram_api.zig");
const handlers = @import("handlers.zig");

const BotConfig = telegram_api.BotConfig;

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
    history: ?[]const u8 = null, // previous session messages JSON (caller-owned, freed by worker)
    bot_state: ?*handlers.BotState = null, // to save response back to conversation history
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
        if (opts.history) |h| allocator.free(h);
    }

    telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xf0\x9f\xa7\xa0 TRI streaming...");

    const model = opts.model orelse default_model;

    // Build request body
    var body_buf: std.ArrayList(u8) = .empty;
    defer body_buf.deinit(allocator);

    buildRequestBody(allocator, &body_buf, model, opts.args, opts.history) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to build request");
        return;
    };

    std.debug.print("[tri-bot] SSE request: {d} bytes, model={s}\n", .{ body_buf.items.len, model });

    // HTTP POST to Anthropic API (supports z.ai and custom proxies via ANTHROPIC_BASE_URL)
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const api_url = std.fmt.allocPrint(allocator, "{s}/v1/messages", .{config.api_base_url}) catch {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Failed to build API URL");
        return;
    };
    defer allocator.free(api_url);

    const uri = std.Uri.parse(api_url) catch unreachable;

    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "x-api-key", .value = config.api_key },
            .{ .name = "anthropic-version", .value = api_version },
            .{ .name = "Accept-Encoding", .value = "identity" },
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

    // Read SSE stream with decompression (z.ai ignores Accept-Encoding: identity)
    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => allocator.alloc(u8, std.compress.zstd.default_window_len) catch {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Decompression alloc failed");
            return;
        },
        .deflate, .gzip => allocator.alloc(u8, std.compress.flate.max_window_len) catch {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Decompression alloc failed");
            return;
        },
        .compress => {
            telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9d\x8c Unsupported compression");
            return;
        },
    };
    defer if (decompress_buffer.len > 0) allocator.free(decompress_buffer);

    var transfer_buf: [8192]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    var reader = response.readerDecompressing(&transfer_buf, &decompress, decompress_buffer);

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
        if (n == 0) break; // Stream ended

        for (read_chunk[0..n]) |byte| {
            if (byte == '\n') {
                const line = line_buf[0..line_len];

                // Parse SSE: "data: {json}"
                if (line.len > 6 and std.mem.eql(u8, line[0..6], "data: ")) {
                    const json = line[6..];
                    if (extractTextDelta(json)) |text_val| {
                        appendJsonUnescaped(&text_buf, allocator, text_val) catch {};
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
        // Save assistant response to conversation history
        if (opts.bot_state) |bs| {
            bs.appendAssistantMessage(text_buf.items);
        }
    } else {
        telegram_api.sendMessage(allocator, config.bot_token, config.chat_id, "\xe2\x9a\xa0 Empty response from API");
    }
}

/// Compact identity prompt — Layer 1 only.
/// Tools discovered on-demand via /tri help, not enumerated.
const system_prompt =
    "You are TRI BOT — Trinity project swarm controller.\n" ++
    "Trinity: pure Zig 0.15 autonomous AI framework. VSA, ternary VM, FPGA, sacred math.\n" ++
    "Identity: phi^2 + 1/phi^2 = 3 = TRINITY.\n\n" ++
    "CAPABILITIES:\n" ++
    "1. Chat freely — I remember full conversation context\n" ++
    "2. /tri <cmd> — execute ANY of 100+ tri CLI commands (run /tri help for full list)\n" ++
    "3. 78 MCP tools available (needle code editing, swarm management, oracle watchdog, science)\n" ++
    "4. /stop /clear /sessions — session control\n\n" ++
    "BEHAVIOR:\n" ++
    "- User asks to DO something -> suggest specific /tri command\n" ++
    "- User asks to KNOW something -> answer from context\n" ++
    "- Unsure which tool -> suggest /tri help <topic>\n" ++
    "- Key commands: /tri status, /tri doctor, /tri constants, /tri pipeline run <task>\n" ++
    "- Be concise. Use emoji and tables for data. Answer in the user's language.";

/// Build JSON request body for Anthropic Messages API (streaming).
/// If history is provided, it's a JSON messages array from a previous session.
fn buildRequestBody(allocator: std.mem.Allocator, body: *std.ArrayList(u8), model: []const u8, prompt: []const u8, history: ?[]const u8) !void {
    try body.appendSlice(allocator, "{\"model\":\"");
    try body.appendSlice(allocator, model);
    try body.appendSlice(allocator, "\",\"max_tokens\":8192,\"stream\":true,\"system\":\"");
    try body.appendSlice(allocator, system_prompt);
    try body.appendSlice(allocator, "\",\"messages\":");

    if (history) |h| {
        // history is like "[{...},{...}]" — strip trailing ] and append new user message
        if (h.len > 1 and h[h.len - 1] == ']') {
            try body.appendSlice(allocator, h[0 .. h.len - 1]);
            try body.appendSlice(allocator, ",{\"role\":\"user\",\"content\":\"");
        } else {
            try body.appendSlice(allocator, "[{\"role\":\"user\",\"content\":\"");
        }
    } else {
        try body.appendSlice(allocator, "[{\"role\":\"user\",\"content\":\"");
    }

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
/// Handles both compact and pretty-printed JSON:
///   {"delta":{"type":"text_delta","text":"Hello"}}       (Anthropic direct)
///   {"delta": {"type": "text_delta", "text": "Hello"}}   (z.ai proxy)
fn extractTextDelta(json: []const u8) ?[]const u8 {
    // Find "text_delta" marker first
    const marker = "\"text_delta\"";
    const marker_idx = std.mem.indexOf(u8, json, marker) orelse return null;
    // Now find "text" field after the marker
    const after_marker = json[marker_idx + marker.len ..];
    const text_key = "\"text\"";
    const text_idx = std.mem.indexOf(u8, after_marker, text_key) orelse return null;
    // Skip past "text" + optional whitespace + : + optional whitespace + opening "
    var pos = text_idx + text_key.len;
    // Skip whitespace
    while (pos < after_marker.len and (after_marker[pos] == ' ' or after_marker[pos] == ':')) : (pos += 1) {}
    // Skip opening quote
    if (pos >= after_marker.len or after_marker[pos] != '"') return null;
    pos += 1;
    const start = pos;
    // Find closing quote (handle escaped quotes and escaped backslashes)
    while (pos < after_marker.len) : (pos += 1) {
        if (after_marker[pos] == '"') {
            // Count consecutive backslashes before this quote
            var num_bs: usize = 0;
            var bp = pos;
            while (bp > start and after_marker[bp - 1] == '\\') {
                num_bs += 1;
                bp -= 1;
            }
            // Even number of backslashes means the quote is real (not escaped)
            if (num_bs % 2 == 0) break;
        }
    }
    if (pos == start) return null;
    return after_marker[start..pos];
}

/// Append a JSON string value to buf, decoding escape sequences:
/// \uXXXX → UTF-8, \\ → \, \" → ", \n → newline, \t → tab, etc.
fn appendJsonUnescaped(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\\' and i + 1 < s.len) {
            switch (s[i + 1]) {
                '"' => {
                    try buf.append(allocator, '"');
                    i += 2;
                },
                '\\' => {
                    try buf.append(allocator, '\\');
                    i += 2;
                },
                'n' => {
                    try buf.append(allocator, '\n');
                    i += 2;
                },
                'r' => {
                    try buf.append(allocator, '\r');
                    i += 2;
                },
                't' => {
                    try buf.append(allocator, '\t');
                    i += 2;
                },
                '/' => {
                    try buf.append(allocator, '/');
                    i += 2;
                },
                'u' => {
                    // \uXXXX unicode escape → UTF-8
                    if (i + 5 < s.len) {
                        const codepoint = std.fmt.parseInt(u21, s[i + 2 .. i + 6], 16) catch {
                            try buf.append(allocator, s[i]);
                            i += 1;
                            continue;
                        };
                        var utf8: [4]u8 = undefined;
                        const len = encodeUtf8(codepoint, &utf8);
                        try buf.appendSlice(allocator, utf8[0..len]);
                        i += 6;
                    } else {
                        try buf.append(allocator, s[i]);
                        i += 1;
                    }
                },
                else => {
                    try buf.append(allocator, s[i]);
                    i += 1;
                },
            }
        } else {
            try buf.append(allocator, s[i]);
            i += 1;
        }
    }
}

/// Encode a Unicode codepoint as UTF-8 bytes. Returns number of bytes written.
fn encodeUtf8(codepoint: u21, buf: *[4]u8) usize {
    if (codepoint <= 0x7F) {
        buf[0] = @intCast(codepoint);
        return 1;
    } else if (codepoint <= 0x7FF) {
        buf[0] = @intCast(0xC0 | (codepoint >> 6));
        buf[1] = @intCast(0x80 | (codepoint & 0x3F));
        return 2;
    } else if (codepoint <= 0xFFFF) {
        buf[0] = @intCast(0xE0 | (codepoint >> 12));
        buf[1] = @intCast(0x80 | ((codepoint >> 6) & 0x3F));
        buf[2] = @intCast(0x80 | (codepoint & 0x3F));
        return 3;
    } else {
        buf[0] = @intCast(0xF0 | (codepoint >> 18));
        buf[1] = @intCast(0x80 | ((codepoint >> 12) & 0x3F));
        buf[2] = @intCast(0x80 | ((codepoint >> 6) & 0x3F));
        buf[3] = @intCast(0x80 | (codepoint & 0x3F));
        return 4;
    }
}

/// Handle API error response — read body and send error to Telegram.
fn handleApiError(allocator: std.mem.Allocator, config: BotConfig, response: *std.http.Client.Response, status: u16) void {
    const decompress_buf: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => allocator.alloc(u8, std.compress.zstd.default_window_len) catch &.{},
        .deflate, .gzip => allocator.alloc(u8, std.compress.flate.max_window_len) catch &.{},
        .compress => &.{},
    };
    defer if (decompress_buf.len > 0) allocator.free(decompress_buf);

    var transfer_buf: [8192]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    var reader = response.readerDecompressing(&transfer_buf, &decompress, decompress_buf);
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
