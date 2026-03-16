// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// ARENA EXTERNAL API — HTTP Client for OpenAI / Anthropic / z.ai
// ═══════════════════════════════════════════════════════════════════════════════
//
// Calls external LLM APIs using std.http.Client (Zig 0.15)
// Supports: OpenAI chat completions, Anthropic messages, z.ai proxy, echo
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const Allocator = std.mem.Allocator;

/// Completion result from an external API
pub const CompletionResult = struct {
    response: []const u8, // allocated, caller must free
    latency_ms: u64,
    model: []const u8, // allocated
    error_msg: ?[]const u8 = null, // allocated if present
};

/// Get current time in milliseconds
fn nowMs() i64 {
    return @divTrunc(std.time.milliTimestamp(), 1);
}

/// Call an external LLM to complete a prompt
pub fn complete(
    allocator: Allocator,
    kind: types.FighterKind,
    model: ?[]const u8,
    endpoint: ?[]const u8,
    prompt: []const u8,
) !CompletionResult {
    const start_ms = nowMs();

    switch (kind) {
        .echo => {
            const elapsed: u64 = @intCast(@max(0, nowMs() - start_ms));
            const response = try allocator.dupe(u8, prompt);
            const model_name = try allocator.dupe(u8, "echo");
            return .{
                .response = response,
                .latency_ms = elapsed,
                .model = model_name,
            };
        },
        .trinity => {
            return callTrinity(allocator, prompt, start_ms);
        },
        .openai => {
            const mdl = model orelse "gpt-4o";
            const ep = endpoint orelse "https://api.openai.com/v1/chat/completions";
            return callOpenAI(allocator, ep, mdl, prompt, start_ms);
        },
        .anthropic => {
            const mdl = model orelse "claude-sonnet-4-20250514";
            const ep = endpoint orelse "https://api.anthropic.com/v1/messages";
            return callAnthropic(allocator, ep, mdl, prompt, start_ms);
        },
        .local, .custom => {
            const mdl = model orelse "default";
            const ep = endpoint orelse return error.NoEndpoint;
            return callOpenAI(allocator, ep, mdl, prompt, start_ms);
        },
    }
}

fn elapsedMs(start_ms: i64) u64 {
    return @intCast(@max(0, nowMs() - start_ms));
}

/// Call Trinity HSLM via subprocess
fn callTrinity(allocator: Allocator, prompt: []const u8, start_ms: i64) !CompletionResult {
    const argv = [_][]const u8{
        "zig-out/bin/hslm-train",
        "generate",
        "--prompt",
        prompt,
        "--max-tokens",
        "200",
    };
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);
    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1024 * 1024);
    const result = stdout_buf.toOwnedSlice(allocator) catch try allocator.dupe(u8, "");
    const term = try child.wait();

    const elapsed = elapsedMs(start_ms);

    if (term.Exited != 0) {
        const model_name = try allocator.dupe(u8, "trinity-hslm");
        return .{
            .response = result,
            .latency_ms = elapsed,
            .model = model_name,
            .error_msg = try allocator.dupe(u8, "hslm-train exited with non-zero"),
        };
    }

    const model_name = try allocator.dupe(u8, "trinity-hslm");
    return .{
        .response = result,
        .latency_ms = elapsed,
        .model = model_name,
    };
}

/// Call OpenAI-compatible chat completions API
fn callOpenAI(
    allocator: Allocator,
    endpoint: []const u8,
    model: []const u8,
    prompt: []const u8,
    start_ms: i64,
) !CompletionResult {
    const api_key = std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return makeError(allocator, "OPENAI_API_KEY not set", start_ms),
        else => return err,
    };
    defer allocator.free(api_key);

    const body = try buildOpenAIBody(allocator, model, prompt);
    defer allocator.free(body);

    const response = try httpPost(allocator, endpoint, api_key, "Bearer", body, "application/json");
    defer if (response.err) |e| allocator.free(e);

    const elapsed = elapsedMs(start_ms);

    if (response.err) |err_msg| {
        const model_name = try allocator.dupe(u8, model);
        const em = try allocator.dupe(u8, err_msg);
        return .{
            .response = try allocator.dupe(u8, ""),
            .latency_ms = elapsed,
            .model = model_name,
            .error_msg = em,
        };
    }

    const content = extractOpenAIContent(allocator, response.body) catch try allocator.dupe(u8, response.body);
    const model_name = try allocator.dupe(u8, model);

    if (response.body.len > 0 and !std.mem.eql(u8, content, response.body)) {
        allocator.free(response.body);
    }

    return .{
        .response = content,
        .latency_ms = elapsed,
        .model = model_name,
    };
}

/// Call Anthropic messages API
fn callAnthropic(
    allocator: Allocator,
    endpoint: []const u8,
    model: []const u8,
    prompt: []const u8,
    start_ms: i64,
) !CompletionResult {
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            // Try ZAI_KEY_1 as fallback
            const zai = std.process.getEnvVarOwned(allocator, "ZAI_KEY_1") catch
                return makeError(allocator, "ANTHROPIC_API_KEY not set", start_ms);
            return callAnthropicWithKey(allocator, endpoint, model, prompt, zai, start_ms);
        },
        else => return err,
    };
    return callAnthropicWithKey(allocator, endpoint, model, prompt, api_key, start_ms);
}

fn callAnthropicWithKey(
    allocator: Allocator,
    endpoint: []const u8,
    model: []const u8,
    prompt: []const u8,
    api_key: []const u8,
    start_ms: i64,
) !CompletionResult {
    defer allocator.free(api_key);

    const body = try buildAnthropicBody(allocator, model, prompt);
    defer allocator.free(body);

    const response = try httpPost(allocator, endpoint, api_key, "x-api-key", body, "application/json");
    defer if (response.err) |e| allocator.free(e);

    const elapsed = elapsedMs(start_ms);

    if (response.err) |err_msg| {
        const model_name = try allocator.dupe(u8, model);
        const em = try allocator.dupe(u8, err_msg);
        return .{
            .response = try allocator.dupe(u8, ""),
            .latency_ms = elapsed,
            .model = model_name,
            .error_msg = em,
        };
    }

    const content = extractAnthropicContent(allocator, response.body) catch try allocator.dupe(u8, response.body);
    const model_name = try allocator.dupe(u8, model);

    if (response.body.len > 0 and !std.mem.eql(u8, content, response.body)) {
        allocator.free(response.body);
    }

    return .{
        .response = content,
        .latency_ms = elapsed,
        .model = model_name,
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP helpers
// ─────────────────────────────────────────────────────────────────────────────

const HttpResponse = struct {
    body: []const u8, // allocated
    err: ?[]const u8, // allocated if present
};

fn httpPost(
    allocator: Allocator,
    url: []const u8,
    auth_value: []const u8,
    auth_header: []const u8,
    body: []const u8,
    content_type: []const u8,
) !HttpResponse {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch return .{
        .body = try allocator.dupe(u8, ""),
        .err = try allocator.dupe(u8, "invalid URL"),
    };

    // Build auth header value
    var auth_buf: [512]u8 = undefined;
    const auth_val = if (std.mem.eql(u8, auth_header, "Bearer"))
        std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{auth_value}) catch auth_value
    else
        auth_value;

    // Determine auth header name
    const auth_header_name: []const u8 = if (std.mem.eql(u8, auth_header, "x-api-key"))
        "x-api-key"
    else
        "Authorization";

    const extra_headers = [_]std.http.Header{
        .{ .name = "Content-Type", .value = content_type },
        .{ .name = auth_header_name, .value = auth_val },
        .{ .name = "anthropic-version", .value = "2023-06-01" },
        .{ .name = "Accept-Encoding", .value = "identity" },
    };

    var req = client.request(.POST, uri, .{
        .extra_headers = &extra_headers,
        .redirect_behavior = .unhandled,
    }) catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "connection error: {s}", .{@errorName(err)}),
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "send error: {s}", .{@errorName(err)}),
    };
    body_writer.writer.writeAll(body) catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "write error: {s}", .{@errorName(err)}),
    };
    body_writer.end() catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "finish error: {s}", .{@errorName(err)}),
    };
    if (req.connection) |conn| conn.flush() catch {};

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "receive error: {s}", .{@errorName(err)}),
    };

    var transfer_buf: [8192]u8 = undefined;
    var reader = response.reader(&transfer_buf);
    const resp_body = reader.allocRemaining(allocator, std.Io.Limit.limited(1024 * 1024)) catch |err| return .{
        .body = try allocator.dupe(u8, ""),
        .err = try std.fmt.allocPrint(allocator, "read error: {s}", .{@errorName(err)}),
    };

    return .{ .body = resp_body, .err = null };
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON builders
// ─────────────────────────────────────────────────────────────────────────────

fn buildOpenAIBody(allocator: Allocator, model: []const u8, prompt: []const u8) ![]const u8 {
    const escaped_prompt = try jsonEscape(allocator, prompt);
    defer allocator.free(escaped_prompt);

    return std.fmt.allocPrint(allocator,
        \\{{"model":"{s}","messages":[{{"role":"user","content":"{s}"}}],"max_tokens":2048,"temperature":0.7}}
    , .{ model, escaped_prompt });
}

fn buildAnthropicBody(allocator: Allocator, model: []const u8, prompt: []const u8) ![]const u8 {
    const escaped_prompt = try jsonEscape(allocator, prompt);
    defer allocator.free(escaped_prompt);

    return std.fmt.allocPrint(allocator,
        \\{{"model":"{s}","messages":[{{"role":"user","content":"{s}"}}],"max_tokens":2048}}
    , .{ model, escaped_prompt });
}

/// Escape a string for JSON embedding
pub fn jsonEscape(allocator: Allocator, input: []const u8) ![]const u8 {
    var result = std.array_list.Managed(u8).init(allocator);
    errdefer result.deinit();

    for (input) |c| {
        switch (c) {
            '"' => try result.appendSlice("\\\""),
            '\\' => try result.appendSlice("\\\\"),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            else => {
                if (c < 0x20) {
                    var esc_buf: [6]u8 = undefined;
                    const s = std.fmt.bufPrint(&esc_buf, "\\u{x:0>4}", .{c}) catch continue;
                    try result.appendSlice(s);
                } else {
                    try result.append(c);
                }
            },
        }
    }

    return result.toOwnedSlice();
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON parsers (minimal, extract content from response)
// ─────────────────────────────────────────────────────────────────────────────

/// Extract content from OpenAI response: {"choices":[{"message":{"content":"..."}}]}
fn extractOpenAIContent(allocator: Allocator, body: []const u8) ![]const u8 {
    return extractJsonStringField(allocator, body, "\"content\":\"");
}

/// Extract content from Anthropic response: {"content":[{"text":"..."}]}
fn extractAnthropicContent(allocator: Allocator, body: []const u8) ![]const u8 {
    return extractJsonStringField(allocator, body, "\"text\":\"");
}

/// Simple JSON string field extractor (no full parser needed)
fn extractJsonStringField(allocator: Allocator, json: []const u8, field_prefix: []const u8) ![]const u8 {
    const start_idx = std.mem.indexOf(u8, json, field_prefix) orelse return error.FieldNotFound;
    const content_start = start_idx + field_prefix.len;

    var result = std.array_list.Managed(u8).init(allocator);
    errdefer result.deinit();

    var i = content_start;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\' and i + 1 < json.len) {
            switch (json[i + 1]) {
                '"' => try result.append('"'),
                '\\' => try result.append('\\'),
                'n' => try result.append('\n'),
                'r' => try result.append('\r'),
                't' => try result.append('\t'),
                else => {
                    try result.append('\\');
                    try result.append(json[i + 1]);
                },
            }
            i += 1;
        } else if (json[i] == '"') {
            break;
        } else {
            try result.append(json[i]);
        }
    }

    return result.toOwnedSlice();
}

fn makeError(allocator: Allocator, msg: []const u8, start_ms: i64) CompletionResult {
    const elapsed = elapsedMs(start_ms);
    return .{
        .response = allocator.dupe(u8, "") catch "",
        .latency_ms = elapsed,
        .model = allocator.dupe(u8, "unknown") catch "unknown",
        .error_msg = allocator.dupe(u8, msg) catch msg,
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "json escape" {
    const allocator = std.testing.allocator;
    const escaped = try jsonEscape(allocator, "hello \"world\"\nnewline");
    defer allocator.free(escaped);
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnewline", escaped);
}

test "extract openai content" {
    const allocator = std.testing.allocator;
    const json =
        \\{"choices":[{"message":{"content":"Hello world"}}]}
    ;
    const content = try extractOpenAIContent(allocator, json);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("Hello world", content);
}

test "extract anthropic content" {
    const allocator = std.testing.allocator;
    const json =
        \\{"content":[{"type":"text","text":"Hello from Claude"}]}
    ;
    const content = try extractAnthropicContent(allocator, json);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("Hello from Claude", content);
}

test "echo fighter" {
    const allocator = std.testing.allocator;
    const result = try complete(allocator, .echo, null, null, "test prompt");
    defer allocator.free(result.response);
    defer allocator.free(result.model);
    try std.testing.expectEqualStrings("test prompt", result.response);
    try std.testing.expectEqualStrings("echo", result.model);
}
