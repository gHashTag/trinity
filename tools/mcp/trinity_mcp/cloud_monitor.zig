//! CLOUD MONITOR — WebSocket Status Monitor for Cloud Agents
//! Receives heartbeats from agent containers via HTTP POST
//! Streams updates to connected WebSocket dashboard clients
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

const DEFAULT_PORT: u16 = 8765;
const MAX_AGENTS = 50;
const MAX_CLIENTS = 20;
const EVENTS_FILE = ".trinity/cloud_events.jsonl";

// P0.5: Auth token for status POST (set via MONITOR_TOKEN env, default "trinity")
var auth_token: [128]u8 = undefined;
var auth_token_len: usize = 0;
var auth_initialized: bool = false;

fn getAuthToken() []const u8 {
    if (!auth_initialized) {
        auth_initialized = true;
        const token = std.process.getEnvVarOwned(std.heap.page_allocator, "MONITOR_TOKEN") catch {
            const default = "trinity";
            @memcpy(auth_token[0..default.len], default);
            auth_token_len = default.len;
            return auth_token[0..auth_token_len];
        };
        auth_token_len = @min(token.len, 128);
        @memcpy(auth_token[0..auth_token_len], token[0..auth_token_len]);
    }
    return auth_token[0..auth_token_len];
}

pub const AgentStatus = struct {
    issue: u32,
    status: [32]u8,
    status_len: usize,
    detail: [256]u8,
    detail_len: usize,
    last_heartbeat: i64,

    pub fn getStatus(self: *const AgentStatus) []const u8 {
        return self.status[0..self.status_len];
    }

    pub fn getDetail(self: *const AgentStatus) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

var agent_statuses: [MAX_AGENTS]AgentStatus = undefined;
var status_count: usize = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Start the cloud monitor HTTP/WS server.
/// Called when trinity-mcp is started with --cloud-monitor flag.
pub fn runMonitor(port: u16) !void {
    const actual_port = if (port == 0) DEFAULT_PORT else port;

    std.log.info("Cloud Monitor starting on port {d}", .{actual_port});

    const address = net.Address.parseIp4("0.0.0.0", actual_port) catch return;
    var server = address.listen(.{ .reuse_address = true }) catch |err| {
        std.log.err("Cloud Monitor failed to bind: {}", .{err});
        return;
    };
    defer server.deinit();

    std.log.info("Cloud Monitor listening on http://0.0.0.0:{d}", .{actual_port});

    // Accept loop
    while (true) {
        const conn = server.accept() catch continue;
        // Handle in same thread (simple model)
        handleConnection(conn.stream) catch |err| {
            std.log.warn("Connection error: {}", .{err});
        };
    }
}

/// Update agent status (called from HTTP POST handler).
/// Persists to JSONL, alerts on error states via tri notify.
pub fn updateStatus(issue: u32, status_str: []const u8, detail: []const u8) void {
    // 1. Append to JSONL event log
    appendEvent(issue, status_str, detail);

    // 2. Alert on error states via tri notify
    if (std.mem.eql(u8, status_str, "STUCK") or
        std.mem.eql(u8, status_str, "ERROR") or
        std.mem.eql(u8, status_str, "FAILED") or
        std.mem.eql(u8, status_str, "KILLED"))
    {
        std.log.warn("CLOUD ALERT: Agent #{d} status={s} detail={s}", .{ issue, status_str, detail });
        // Shell out to tri notify for Telegram alert
        sendTriNotify(issue, status_str, detail);
    }

    // 3. Find existing entry or create new
    for (agent_statuses[0..status_count]) |*a| {
        if (a.issue == issue) {
            setStatus(a, status_str, detail);
            return;
        }
    }

    // New entry
    if (status_count < MAX_AGENTS) {
        var entry = &agent_statuses[status_count];
        entry.issue = issue;
        setStatus(entry, status_str, detail);
        status_count += 1;
    }
}

/// Read event history from JSONL, optionally filtered by issue number.
/// Returns JSON array of events.
pub fn getEventHistory(buf: []u8, issue_filter: ?u32) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    w.writeAll("{\"events\":[") catch return "{}";

    const file = std.fs.cwd().openFile(EVENTS_FILE, .{}) catch {
        w.writeAll("]}") catch {};
        return fbs.getWritten();
    };
    defer file.close();

    // Read entire file
    var file_buf: [32768]u8 = undefined;
    const file_len = file.readAll(&file_buf) catch 0;
    const content = file_buf[0..file_len];

    var first = true;
    var count: u32 = 0;
    var offset: usize = 0;

    while (offset < content.len) {
        const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
        const line = content[offset..line_end];
        offset = line_end + 1;

        if (line.len == 0) continue;

        // Filter by issue if specified
        if (issue_filter) |filter_issue| {
            var issue_needle_buf: [32]u8 = undefined;
            const needle = std.fmt.bufPrint(&issue_needle_buf, "\"issue\":{d}", .{filter_issue}) catch continue;
            if (std.mem.indexOf(u8, line, needle) == null) continue;
        }

        if (!first) w.writeAll(",") catch {};
        first = false;
        w.writeAll(line) catch break;
        count += 1;
        if (count >= 100) break; // Limit to last 100 events
    }

    w.writeAll("],\"count\":") catch {};
    std.fmt.format(w, "{d}}}", .{count}) catch {};
    return fbs.getWritten();
}

/// Get all agent statuses as JSON.
pub fn getStatusJson(buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    w.writeAll("{\"agents\":[") catch return "{}";

    var first = true;
    for (agent_statuses[0..status_count]) |*a| {
        if (!first) w.writeAll(",") catch {};
        first = false;
        std.fmt.format(w, "{{\"issue\":{d},\"status\":\"{s}\",\"detail\":\"{s}\",\"last_heartbeat\":{d}}}", .{
            a.issue,
            a.getStatus(),
            a.getDetail(),
            a.last_heartbeat,
        }) catch break;
    }

    w.writeAll("]}") catch {};
    return fbs.getWritten();
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL
// ═══════════════════════════════════════════════════════════════════════════════

fn appendEvent(issue: u32, status_str: []const u8, detail: []const u8) void {
    std.fs.cwd().makePath(".trinity") catch return;

    const file = std.fs.cwd().createFile(EVENTS_FILE, .{ .truncate = false }) catch return;
    defer file.close();

    // Seek to end for append
    file.seekFromEnd(0) catch return;
    const w = file.writer();

    const ts = std.time.timestamp();
    std.fmt.format(w, "{{\"ts\":{d},\"issue\":{d},\"status\":\"{s}\",\"detail\":\"{s}\"}}\n", .{
        ts,
        issue,
        status_str,
        detail,
    }) catch return;
}

fn sendTriNotify(issue: u32, status_str: []const u8, detail: []const u8) void {
    var msg_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "CLOUD ALERT: Agent #{d} {s} — {s}", .{
        issue, status_str, detail,
    }) catch return;

    const argv = [_][]const u8{ "/Users/playra/trinity-w1/zig-out/bin/tri", "notify", msg };
    var child = std.process.Child.init(&argv, std.heap.page_allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    child.spawn() catch return;
    _ = child.wait() catch {};
}

fn setStatus(entry: *AgentStatus, status_str: []const u8, detail: []const u8) void {
    entry.status_len = @min(status_str.len, 32);
    @memcpy(entry.status[0..entry.status_len], status_str[0..entry.status_len]);
    entry.detail_len = @min(detail.len, 256);
    @memcpy(entry.detail[0..entry.detail_len], detail[0..entry.detail_len]);
    entry.last_heartbeat = std.time.timestamp();
}

fn handleConnection(stream: net.Stream) !void {
    defer stream.close();

    // Read HTTP request
    var req_buf: [4096]u8 = undefined;
    const n = stream.read(&req_buf) catch return;
    const request = req_buf[0..n];

    // Route: POST /api/status — heartbeat from agent
    if (std.mem.startsWith(u8, request, "POST /api/status")) {
        try handleStatusPost(stream, request);
        return;
    }

    // Route: GET /api/history — event history (optional ?issue=N)
    if (std.mem.startsWith(u8, request, "GET /api/history")) {
        var hist_buf: [16384]u8 = undefined;
        // Parse optional issue parameter from query string
        var issue_filter: ?u32 = null;
        if (std.mem.indexOf(u8, request, "?issue=")) |qidx| {
            const qstart = qidx + 7;
            var qend = qstart;
            while (qend < request.len and request[qend] >= '0' and request[qend] <= '9') : (qend += 1) {}
            issue_filter = std.fmt.parseInt(u32, request[qstart..qend], 10) catch null;
        }
        const history = getEventHistory(&hist_buf, issue_filter);
        try sendHttpResponse(stream, "200 OK", "application/json", history);
        return;
    }

    // Route: GET /api/agents — list agent statuses
    if (std.mem.startsWith(u8, request, "GET /api/agents")) {
        var buf: [8192]u8 = undefined;
        const json = getStatusJson(&buf);
        try sendHttpResponse(stream, "200 OK", "application/json", json);
        return;
    }

    // Route: GET /health
    if (std.mem.startsWith(u8, request, "GET /health")) {
        try sendHttpResponse(stream, "200 OK", "text/plain", "OK");
        return;
    }

    // Default: 404
    try sendHttpResponse(stream, "404 Not Found", "text/plain", "Not Found");
}

fn handleStatusPost(stream: net.Stream, request: []const u8) !void {
    // P0.5: Check Bearer token auth
    const expected_token = getAuthToken();
    const auth_needle = "Authorization: Bearer ";
    if (std.mem.indexOf(u8, request, auth_needle)) |auth_idx| {
        const token_start = auth_idx + auth_needle.len;
        // Find end of header line
        const token_end = std.mem.indexOfPos(u8, request, token_start, "\r\n") orelse request.len;
        const provided = request[token_start..token_end];
        if (!std.mem.eql(u8, provided, expected_token)) {
            try sendHttpResponse(stream, "401 Unauthorized", "application/json", "{\"error\":\"invalid token\"}");
            return;
        }
    } else {
        try sendHttpResponse(stream, "401 Unauthorized", "application/json", "{\"error\":\"missing Authorization header\"}");
        return;
    }

    // Find body (after \r\n\r\n)
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return;
    const body = request[body_start + 4 ..];

    // Parse issue number
    const issue_needle = "\"issue\":";
    const issue_idx = std.mem.indexOf(u8, body, issue_needle) orelse return;
    const istart = issue_idx + issue_needle.len;
    var iend = istart;
    while (iend < body.len and body[iend] >= '0' and body[iend] <= '9') : (iend += 1) {}
    const issue = std.fmt.parseInt(u32, body[istart..iend], 10) catch return;

    // Parse status
    const status = extractJsonString(body, "status") orelse "unknown";
    const detail = extractJsonString(body, "detail") orelse "";

    updateStatus(issue, status, detail);

    try sendHttpResponse(stream, "200 OK", "application/json", "{\"ok\":true}");
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Find "key":"value"
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end];
}

fn sendHttpResponse(stream: net.Stream, status: []const u8, content_type: []const u8, body: []const u8) !void {
    var header_buf: [512]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{
        status, content_type, body.len,
    }) catch return;
    _ = stream.write(header) catch return;
    _ = stream.write(body) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "updateStatus and getStatusJson" {
    status_count = 0;
    updateStatus(42, "THINKING", "Analyzing issue");

    var buf: [4096]u8 = undefined;
    const json = getStatusJson(&buf);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"issue\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "THINKING") != null);
}

test "extractJsonString" {
    const json = "{\"issue\":42,\"status\":\"DONE\",\"detail\":\"PR created\"}";
    try std.testing.expectEqualStrings("DONE", extractJsonString(json, "status").?);
    try std.testing.expectEqualStrings("PR created", extractJsonString(json, "detail").?);
}
