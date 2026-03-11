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
    // Metrics (optional, default 0)
    tests_passed: u32 = 0,
    tests_total: u32 = 0,
    files_changed: u32 = 0,
    lines_added: u32 = 0,
    commits: u32 = 0,

    pub fn getStatus(self: *const AgentStatus) []const u8 {
        return self.status[0..self.status_len];
    }

    pub fn getDetail(self: *const AgentStatus) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

var agent_statuses: [MAX_AGENTS]AgentStatus = undefined;
var status_count: usize = 0;

// Track last event time per issue for deduplication (5s window)
var last_event_times: [MAX_AGENTS][2]i64 = [_][2]i64{.{ 0, 0 }} ** MAX_AGENTS; // [issue_index][0]=issue, [1]=timestamp
var last_event_count: usize = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Start the cloud monitor HTTP/WS server.
/// Called when trinity-mcp is started with --cloud-monitor flag.
pub fn runMonitor(port: u16) !void {
    const actual_port = if (port == 0) DEFAULT_PORT else port;

    std.log.info("Cloud Monitor starting on port {d}", .{actual_port});

    // Restore state from JSONL on startup
    restoreStateFromEvents() catch |err| {
        std.log.warn("Failed to restore state from events: {}", .{err});
    };

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
/// Skips duplicate events within 5s window.
pub fn updateStatus(issue: u32, status_str: []const u8, detail: []const u8) void {
    // Deduplication: skip if same status within 5s
    if (shouldSkipEvent(issue, status_str)) {
        return;
    }

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
        std.fmt.format(w, "{{\"issue\":{d},\"status\":\"{s}\",\"detail\":\"{s}\",\"last_heartbeat\":{d},\"metrics\":{{\"tests_passed\":{d},\"tests_total\":{d},\"files_changed\":{d},\"lines_added\":{d},\"commits\":{d}}}}}", .{
            a.issue,
            a.getStatus(),
            a.getDetail(),
            a.last_heartbeat,
            a.tests_passed,
            a.tests_total,
            a.files_changed,
            a.lines_added,
            a.commits,
        }) catch break;
    }

    w.writeAll("]}") catch {};
    return fbs.getWritten();
}

/// Restore agent states from JSONL event log on startup.
/// Reads the last event for each issue and populates agent_statuses.
fn restoreStateFromEvents() !void {
    const file = std.fs.cwd().openFile(EVENTS_FILE, .{}) catch return;
    defer file.close();

    // Read entire file
    var file_buf: [65536]u8 = undefined;
    const file_len = file.readAll(&file_buf) catch 0;
    if (file_len == 0) return;
    const content = file_buf[0..file_len];

    // Track latest status per issue
    var latest_issue: [MAX_AGENTS]u32 = undefined;
    var latest_ts: [MAX_AGENTS]i64 = undefined;
    var latest_status: [MAX_AGENTS][32]u8 = undefined;
    var latest_status_len: [MAX_AGENTS]usize = undefined;
    var latest_detail: [MAX_AGENTS][256]u8 = undefined;
    var latest_detail_len: [MAX_AGENTS]usize = undefined;
    var latest_count: usize = 0;

    var offset: usize = 0;
    while (offset < content.len) {
        const line_end = std.mem.indexOfPos(u8, content, offset, "\n") orelse content.len;
        const line = content[offset..line_end];
        offset = line_end + 1;
        if (line.len == 0) continue;

        // Parse issue
        const issue_idx = std.mem.indexOf(u8, line, "\"issue\":") orelse continue;
        const istart = issue_idx + 8;
        var iend = istart;
        while (iend < line.len and line[iend] >= '0' and line[iend] <= '9') : (iend += 1) {}
        const issue = std.fmt.parseInt(u32, line[istart..iend], 10) catch continue;

        // Parse timestamp
        const ts_idx = std.mem.indexOf(u8, line, "\"ts\":") orelse continue;
        const tstart = ts_idx + 5;
        var tend = tstart;
        while (tend < line.len and line[tend] >= '0' and line[tend] <= '9') : (tend += 1) {}
        const ts = std.fmt.parseInt(i64, line[tstart..tend], 10) catch continue;

        // Parse status and detail
        const status_str = extractJsonString(line, "status") orelse continue;
        const detail_str = extractJsonString(line, "detail") orelse "";

        // Find or create entry for this issue (keep latest timestamp)
        var entry_idx: ?usize = null;
        var is_newer = true;
        for (0..latest_count) |i| {
            if (latest_issue[i] == issue) {
                entry_idx = i;
                is_newer = ts > latest_ts[i];
                break;
            }
        }

        if (entry_idx == null and latest_count < MAX_AGENTS) {
            entry_idx = latest_count;
            latest_issue[latest_count] = issue;
            latest_count += 1;
        }

        if (entry_idx) |idx| {
            if (is_newer) {
                latest_ts[idx] = ts;
                latest_status_len[idx] = @min(status_str.len, 32);
                @memcpy(latest_status[idx][0..latest_status_len[idx]], status_str[0..latest_status_len[idx]]);
                latest_detail_len[idx] = @min(detail_str.len, 256);
                @memcpy(latest_detail[idx][0..latest_detail_len[idx]], detail_str[0..latest_detail_len[idx]]);
            }
        }
    }

    // Populate agent_statuses from latest events
    status_count = 0;
    for (0..latest_count) |i| {
        if (status_count >= MAX_AGENTS) break;
        const entry = &agent_statuses[status_count];
        entry.issue = latest_issue[i];
        entry.status_len = latest_status_len[i];
        @memcpy(entry.status[0..entry.status_len], latest_status[i][0..entry.status_len]);
        entry.detail_len = latest_detail_len[i];
        @memcpy(entry.detail[0..entry.detail_len], latest_detail[i][0..entry.detail_len]);
        entry.last_heartbeat = latest_ts[i];
        status_count += 1;
    }

    std.log.info("Restored {d} agent states from events log", .{status_count});
}

/// Check if we should skip this event (deduplication: same status within 5 seconds)
fn shouldSkipEvent(issue: u32, status_str: []const u8) bool {
    const now = std.time.timestamp();
    const dedup_window: i64 = 5; // 5 seconds

    for (0..last_event_count) |i| {
        if (last_event_times[i][0] == @as(i64, @intCast(issue))) {
            if (now - last_event_times[i][1] < dedup_window) {
                // Check if status is the same
                for (0..status_count) |j| {
                    if (agent_statuses[j].issue == issue) {
                        const last_status = agent_statuses[j].getStatus();
                        if (std.mem.eql(u8, last_status, status_str)) {
                            return true; // Skip: same status within 5s window
                        }
                        break;
                    }
                }
            }
            // Update timestamp
            last_event_times[i][1] = now;
            return false;
        }
    }

    // New issue, add to tracking
    if (last_event_count < MAX_AGENTS) {
        last_event_times[last_event_count][0] = @as(i64, @intCast(issue));
        last_event_times[last_event_count][1] = now;
        last_event_count += 1;
    }
    return false;
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

    // Format JSON line to buffer, then write
    var buf: [512]u8 = undefined;
    const ts = std.time.timestamp();
    const line = std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"issue\":{d},\"status\":\"{s}\",\"detail\":\"{s}\"}}\n", .{
        ts,
        issue,
        status_str,
        detail,
    }) catch return;
    _ = file.writeAll(line) catch return;
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

    // Route: POST /api/event — structured ACI event from agent
    if (std.mem.startsWith(u8, request, "POST /api/event")) {
        try handleEventPost(stream, request);
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
        var buf: [16384]u8 = undefined;
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

/// ═══════════════════════════════════════════════════════════════════════════════
/// STRUCTURED ACI PROTOCOL
/// ═══════════════════════════════════════════════════════════════════════════════
/// ACI Event Types
pub const EventType = enum {
    status,
    log,
    metric,
    err, // "error" is a reserved keyword
    pr,

    pub fn fromString(str: []const u8) ?EventType {
        if (std.mem.eql(u8, str, "status")) return .status;
        if (std.mem.eql(u8, str, "log")) return .log;
        if (std.mem.eql(u8, str, "metric")) return .metric;
        if (std.mem.eql(u8, str, "error")) return .err; // "error" maps to err
        if (std.mem.eql(u8, str, "pr")) return .pr;
        return null;
    }

    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .status => "status",
            .log => "log",
            .metric => "metric",
            .err => "error",
            .pr => "pr",
        };
    }
};

/// ACI Event Structure
pub const ACIEvent = struct {
    type: EventType,
    issue: u32,
    payload: []const u8,
    timestamp: i64,

    /// Parse ACI event from JSON string
    /// Format: {"type":"status|log|metric|error|pr","issue":N,"payload":{...},"ts":"ISO8601"}
    pub fn parse(json: []const u8, allocator: Allocator) !ACIEvent {
        const ev_type_str = extractJsonString(json, "type") orelse return error.MissingType;
        const ev_type = EventType.fromString(ev_type_str) orelse return error.UnknownType;

        const issue_idx = std.mem.indexOf(u8, json, "\"issue\":") orelse return error.MissingIssue;
        const istart = issue_idx + 8;
        var iend = istart;
        while (iend < json.len and json[iend] >= '0' and json[iend] <= '9') : (iend += 1) {}
        const issue = try std.fmt.parseInt(u32, json[istart..iend], 10);

        const payload_idx = std.mem.indexOf(u8, json, "\"payload\":") orelse return error.MissingPayload;
        const pstart = payload_idx + 10;
        // Find matching closing brace for payload object
        var brace_depth: u32 = 1;
        var pend = pstart + 1; // Start after the opening brace
        while (pend < json.len) {
            if (json[pend] == '{') brace_depth += 1;
            if (json[pend] == '}') brace_depth -= 1;
            pend += 1;
            if (brace_depth == 0) break;
        }
        // pend now points to the character after the closing brace
        // Slice from pstart (includes opening brace) to pend (includes closing brace)
        const payload = json[pstart..pend];

        // Parse ISO8601 timestamp to unix seconds
        const ts_str = extractJsonString(json, "ts") orelse return error.MissingTimestamp;
        const timestamp = try parseIso8601(ts_str);

        return ACIEvent{
            .type = ev_type,
            .issue = issue,
            .payload = try allocator.dupe(u8, payload),
            .timestamp = timestamp,
        };
    }

    pub fn deinit(self: *ACIEvent, allocator: Allocator) void {
        allocator.free(self.payload);
    }

    /// Get metric payload values
    pub fn getMetric(self: *const ACIEvent, key: []const u8) ?u32 {
        if (self.type != .metric) return null;
        return parseJsonU32(self.payload, key);
    }
};

/// Parse ISO8601 timestamp (e.g., "2025-03-11T12:34:56Z") to unix seconds
fn parseIso8601(ts: []const u8) !i64 {
    // Simple parser for "YYYY-MM-DDTHH:MM:SSZ" format
    if (ts.len < 20) return error.InvalidFormat;

    // Extract numbers manually (simpler than full date parsing)
    const year = std.fmt.parseInt(u32, ts[0..4], 10) catch return error.InvalidFormat;
    const month = std.fmt.parseInt(u32, ts[5..7], 10) catch return error.InvalidFormat;
    const day = std.fmt.parseInt(u32, ts[8..10], 10) catch return error.InvalidFormat;
    const hour = std.fmt.parseInt(u32, ts[11..13], 10) catch return error.InvalidFormat;
    const minute = std.fmt.parseInt(u32, ts[14..16], 10) catch return error.InvalidFormat;
    const second = std.fmt.parseInt(u32, ts[17..19], 10) catch return error.InvalidFormat;

    // Approximate to unix timestamp (ignoring leap seconds, etc.)
    // This is good enough for monitoring purposes
    // Days since epoch
    const days_since_epoch: i64 = @intCast(year - 1970);
    const leap_years = @divTrunc(days_since_epoch, 4) - @divTrunc(days_since_epoch, 100) + @divTrunc(days_since_epoch, 400);

    var total_days: i64 = days_since_epoch * 365 + leap_years;
    // Add days for months (approximate, ignoring leap year variations)
    const month_days = [_]u32{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    if (month > 0 and month <= 12) {
        total_days += @intCast(month_days[month - 1]);
    }
    total_days += @intCast(day - 1);

    const seconds: i64 = @intCast(hour * 3600 + minute * 60 + second);
    return total_days * 86400 + seconds;
}

/// Process structured ACI event from agent
/// Routes to appropriate handler based on event type
fn processACIEvent(issue: u32, ev_type: EventType, payload: []const u8) void {
    switch (ev_type) {
        .status => {
            const status = extractJsonString(payload, "status") orelse "unknown";
            const detail = extractJsonString(payload, "detail") orelse "";
            updateStatus(issue, status, detail);
        },
        .log => {
            const msg = extractJsonString(payload, "msg") orelse "";
            appendEvent(issue, "log", msg);
        },
        .metric => {
            // Update agent metrics
            for (agent_statuses[0..status_count]) |*a| {
                if (a.issue == issue) {
                    a.tests_passed = parseJsonU32(payload, "tests_passed");
                    a.tests_total = parseJsonU32(payload, "tests_total");
                    // Persist metrics to events
                    var metric_buf: [256]u8 = undefined;
                    const metric_str = std.fmt.bufPrint(&metric_buf, "metrics: tests_passed={d}, tests_total={d}", .{
                        a.tests_passed,
                        a.tests_total,
                    }) catch "metrics: unknown";
                    appendEvent(issue, "metric", metric_str);
                    break;
                }
            }
        },
        .err => {
            const msg = extractJsonString(payload, "msg") orelse "error";
            appendEvent(issue, "error", msg);
            // Also update status to ERROR
            updateStatus(issue, "ERROR", msg);
        },
        .pr => {
            const url = extractJsonString(payload, "url") orelse "";
            appendEvent(issue, "pr", url);
            // Update status to PR_CREATED
            updateStatus(issue, "PR_CREATED", url);
        },
    }
}

/// Handle POST /api/event — structured ACI event from agent
fn handleEventPost(stream: net.Stream, request: []const u8) !void {
    // P0.5: Check Bearer token auth
    const expected_token = getAuthToken();
    const auth_needle = "Authorization: Bearer ";
    if (std.mem.indexOf(u8, request, auth_needle)) |auth_idx| {
        const token_start = auth_idx + auth_needle.len;
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

    // Parse ACI event
    var event = ACIEvent.parse(body, std.heap.page_allocator) catch |err| {
        std.log.warn("Failed to parse ACI event: {}", .{err});
        try sendHttpResponse(stream, "400 Bad Request", "application/json", "{\"error\":\"invalid event format\"}");
        return;
    };
    defer event.deinit(std.heap.page_allocator);

    // Process event based on type
    processACIEvent(event.issue, event.type, event.payload);

    // Append to JSONL event log with full structure
    appendStructuredEvent(&event);

    try sendHttpResponse(stream, "200 OK", "application/json", "{\"ok\":true}");
}

/// Append structured ACI event to JSONL log
fn appendStructuredEvent(event: *const ACIEvent) void {
    std.fs.cwd().makePath(".trinity") catch return;

    const file = std.fs.cwd().createFile(EVENTS_FILE, .{ .truncate = false }) catch return;
    defer file.close();

    file.seekFromEnd(0) catch return;

    var buf: [1024]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"type\":\"{s}\",\"issue\":{d},\"payload\":{s}}}\n", .{
        event.timestamp,
        event.type.toString(),
        event.issue,
        event.payload,
    }) catch return;
    _ = file.writeAll(line) catch return;
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

    // Parse optional metrics block
    if (std.mem.indexOf(u8, body, "\"metrics\":")) |_| {
        for (agent_statuses[0..status_count]) |*a| {
            if (a.issue == issue) {
                a.tests_passed = parseJsonU32(body, "tests_passed");
                a.tests_total = parseJsonU32(body, "tests_total");
                a.files_changed = parseJsonU32(body, "files_changed");
                a.lines_added = parseJsonU32(body, "lines_added");
                a.commits = parseJsonU32(body, "commits");
                break;
            }
        }
    }

    try sendHttpResponse(stream, "200 OK", "application/json", "{\"ok\":true}");
}

fn parseJsonU32(json: []const u8, key: []const u8) u32 {
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":", .{key}) catch return 0;
    const idx = std.mem.indexOf(u8, json, needle) orelse return 0;
    const start = idx + needle.len;
    var end = start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    return std.fmt.parseInt(u32, json[start..end], 10) catch 0;
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

test "ACIEvent parse" {
    const json = "{\"type\":\"status\",\"issue\":42,\"payload\":{\"status\":\"DONE\",\"detail\":\"Test\"},\"ts\":\"2025-03-11T12:34:56Z\"}";
    var event = try ACIEvent.parse(json, std.testing.allocator);
    defer event.deinit(std.testing.allocator);

    try std.testing.expectEqual(EventType.status, event.type);
    try std.testing.expectEqual(@as(u32, 42), event.issue);
    try std.testing.expectEqualStrings("{\"status\":\"DONE\",\"detail\":\"Test\"}", event.payload);
}

test "processACIEvent - metric" {
    status_count = 1;
    agent_statuses[0].issue = 42;
    agent_statuses[0].tests_passed = 0;
    agent_statuses[0].tests_total = 0;

    const payload = "{\"tests_passed\":5,\"tests_total\":8}";
    processACIEvent(42, .metric, payload);

    try std.testing.expectEqual(@as(u32, 5), agent_statuses[0].tests_passed);
    try std.testing.expectEqual(@as(u32, 8), agent_statuses[0].tests_total);
}
