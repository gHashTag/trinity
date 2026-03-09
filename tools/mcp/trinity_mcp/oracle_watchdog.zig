//! ORACLE Telegram Watchdog — Read-only observer thread inside MCP server
//! Implements oracle_watchdog.vibee
//! phi^2 + 1/phi^2 = 3 | TRINITY
//!
//! Reads swarm state DIRECTLY from memory (agents, tasks, circuit breakers).
//! Sends status reports to Telegram via std.http.Client.
//! NEVER modifies state. Only observes and reports.

const std = @import("std");
const swarm = @import("swarm_tools.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_INTERVAL_MS: u64 = 300_000; // 5 minutes
const MAX_MESSAGE_LEN: usize = 4096;
const ALERT_COOLDOWN_MS: u64 = 60_000; // 1 min between same alerts
const HEARTBEAT_TIMEOUT_MS: u64 = 120_000; // 2 min — same as swarm_tools

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from oracle_watchdog.vibee)
// ═══════════════════════════════════════════════════════════════════════════════

pub const OracleConfig = struct {
    telegram_token: []const u8,
    chat_id: []const u8,
    interval_ms: u64 = DEFAULT_INTERVAL_MS,
};

const OracleReport = struct {
    active_agents: u32 = 0,
    working_agents: u32 = 0,
    idle_agents: u32 = 0,
    offline_agents: u32 = 0,
    error_agents: u32 = 0,
    total_tasks: u32 = 0,
    pending_tasks: u32 = 0,
    running_tasks: u32 = 0,
    completed_tasks: u32 = 0,
    failed_tasks: u32 = 0,
    circuit_breakers_open: u32 = 0,
};

const GitHubReport = struct {
    open_issues: u32 = 0,
    pending: u32 = 0,
    in_progress: u32 = 0,
    completed: u32 = 0,
    failed: u32 = 0,
    fetch_ok: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL STATE (atomic for thread safety)
// ═══════════════════════════════════════════════════════════════════════════════

var oracle_running = std.atomic.Value(bool).init(false);
var oracle_thread: ?std.Thread = null;
var oracle_messages_sent: u64 = 0;
var oracle_errors: u64 = 0;
var oracle_last_report_ms: u64 = 0;

// Config stored for thread access
var stored_token: [256]u8 = [_]u8{0} ** 256;
var stored_token_len: usize = 0;
var stored_chat_id: [32]u8 = [_]u8{0} ** 32;
var stored_chat_id_len: usize = 0;
var stored_interval_ms: u64 = DEFAULT_INTERVAL_MS;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — called from server.zig MCP tool handlers
// ═══════════════════════════════════════════════════════════════════════════════

/// Start the Oracle watchdog thread
pub fn oracleStart(buf: []u8, token: []const u8, chat_id: []const u8, interval_str: []const u8) []const u8 {
    if (oracle_running.load(.acquire)) {
        return std.fmt.bufPrint(buf, "Oracle already running (sent {d} messages)", .{oracle_messages_sent}) catch buf[0..0];
    }

    if (token.len == 0 or chat_id.len == 0) {
        return std.fmt.bufPrint(buf, "Error: telegram_token and chat_id required", .{}) catch buf[0..0];
    }

    // Store config
    const tok_len = @min(token.len, stored_token.len);
    @memcpy(stored_token[0..tok_len], token[0..tok_len]);
    stored_token_len = tok_len;

    const cid_len = @min(chat_id.len, stored_chat_id.len);
    @memcpy(stored_chat_id[0..cid_len], chat_id[0..cid_len]);
    stored_chat_id_len = cid_len;

    stored_interval_ms = std.fmt.parseInt(u64, interval_str, 10) catch DEFAULT_INTERVAL_MS;
    if (stored_interval_ms < 10_000) stored_interval_ms = 10_000; // min 10s

    // Spawn thread
    oracle_running.store(true, .release);
    oracle_messages_sent = 0;
    oracle_errors = 0;

    oracle_thread = std.Thread.spawn(.{}, watchdogLoop, .{}) catch |err| {
        oracle_running.store(false, .release);
        return std.fmt.bufPrint(buf, "Error spawning thread: {s}", .{@errorName(err)}) catch buf[0..0];
    };

    return std.fmt.bufPrint(buf,
        \\ORACLE started
        \\Interval: {d}ms ({d} min)
        \\Chat ID: {s}
        \\Token: {s}...
    , .{
        stored_interval_ms,
        stored_interval_ms / 60_000,
        stored_chat_id[0..stored_chat_id_len],
        if (stored_token_len > 10) stored_token[0..10] else stored_token[0..stored_token_len],
    }) catch buf[0..0];
}

/// Stop the Oracle watchdog thread
pub fn oracleStop(buf: []u8) []const u8 {
    if (!oracle_running.load(.acquire)) {
        return std.fmt.bufPrint(buf, "Oracle is not running", .{}) catch buf[0..0];
    }

    oracle_running.store(false, .release);

    // Thread will exit on next poll cycle (within interval_ms)
    return std.fmt.bufPrint(buf,
        \\Oracle stop signal sent
        \\Messages sent: {d}
        \\Errors: {d}
    , .{ oracle_messages_sent, oracle_errors }) catch buf[0..0];
}

/// Get Oracle status
pub fn oracleStatus(buf: []u8) []const u8 {
    const running = oracle_running.load(.acquire);
    const now = currentTimeMs();
    const since_last = if (oracle_last_report_ms > 0) now -| oracle_last_report_ms else 0;

    return std.fmt.bufPrint(buf,
        \\ORACLE STATUS
        \\Running: {s}
        \\Messages sent: {d}
        \\Errors: {d}
        \\Last report: {d}s ago
        \\Interval: {d}s
        \\Chat ID: {s}
    , .{
        if (running) "YES" else "NO",
        oracle_messages_sent,
        oracle_errors,
        since_last / 1000,
        stored_interval_ms / 1000,
        if (stored_chat_id_len > 0) stored_chat_id[0..stored_chat_id_len] else "(not set)",
    }) catch buf[0..0];
}

/// Auto-start from env vars (called from server.zig main)
pub fn tryAutoStart() void {
    // Read TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from env
    const token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse
        std.posix.getenv("RALPH_TELEGRAM_BOT_TOKEN") orelse return;
    const chat_id = std.posix.getenv("TELEGRAM_CHAT_ID") orelse
        std.posix.getenv("RALPH_TELEGRAM_CHAT_ID") orelse return;
    const oracle_enabled = std.posix.getenv("ORACLE_ENABLED") orelse "false";

    if (!std.mem.eql(u8, oracle_enabled, "true") and !std.mem.eql(u8, oracle_enabled, "1")) return;

    var buf: [512]u8 = undefined;
    _ = oracleStart(&buf, token, chat_id, "300000");

    const stderr_fd: std.posix.fd_t = 2;
    _ = std.posix.write(stderr_fd, "ORACLE Watchdog auto-started from env vars\n") catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// WATCHDOG LOOP (runs in background thread)
// ═══════════════════════════════════════════════════════════════════════════════

fn watchdogLoop() void {
    const token = stored_token[0..stored_token_len];
    const chat_id = stored_chat_id[0..stored_chat_id_len];

    // Startup message
    var startup_buf: [512]u8 = undefined;
    const startup_msg = std.fmt.bufPrint(&startup_buf,
        "<b>ORACLE started</b>\nInterval: {d} min\nMode: read-only observer",
        .{stored_interval_ms / 60_000},
    ) catch "ORACLE started";
    sendTelegram(token, chat_id, startup_msg);

    var last_hash: u64 = 0;

    // Track circuit breaker states for instant alerts
    var last_cb_states: [50]bool = [_]bool{false} ** 50;

    // Allocator for GitHub API calls
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (oracle_running.load(.acquire)) {
        // Collect status from swarm memory (read-only)
        const report = collectStatus();

        // Collect GitHub status (graceful: returns defaults if no token)
        const gh_report = collectGitHubStatus(allocator);

        // Check for instant alerts (circuit breaker changes)
        checkCircuitBreakerAlerts(token, chat_id, &last_cb_states);

        // Format report
        var msg_buf: [MAX_MESSAGE_LEN]u8 = undefined;
        const msg = formatReportHTML(&msg_buf, report, gh_report);

        // Smart dedup — hash and compare
        const current_hash = hashMessage(msg);
        if (current_hash != last_hash) {
            sendTelegram(token, chat_id, msg);
            last_hash = current_hash;
            oracle_last_report_ms = currentTimeMs();
        }

        // Sleep for interval (check stop flag every second)
        var slept: u64 = 0;
        while (slept < stored_interval_ms and oracle_running.load(.acquire)) {
            std.Thread.sleep(1_000_000_000); // 1 second
            slept += 1000;
        }
    }

    // Shutdown message
    sendTelegram(token, chat_id, "<b>ORACLE stopped</b>");
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS COLLECTION (read-only access to swarm state)
// ═══════════════════════════════════════════════════════════════════════════════

fn collectStatus() OracleReport {
    var report = OracleReport{};

    // Read agents (swarm_tools.zig static arrays — read-only safe)
    const agents_ptr = swarm.getAgentsPtr();
    for (agents_ptr) |*a| {
        if (!a.active) continue;
        report.active_agents += 1;

        const s = a.getStatus();
        if (std.mem.eql(u8, s, "working")) report.working_agents += 1;
        if (std.mem.eql(u8, s, "idle") or std.mem.eql(u8, s, "polling")) report.idle_agents += 1;
        if (std.mem.eql(u8, s, "offline") or std.mem.eql(u8, s, "shutdown")) report.offline_agents += 1;
        if (std.mem.eql(u8, s, "error")) report.error_agents += 1;
        if (a.paused) report.circuit_breakers_open += 1;
    }

    // Read tasks
    const tasks_ptr = swarm.getTasksPtr();
    for (tasks_ptr) |*t| {
        if (!t.active) continue;
        report.total_tasks += 1;

        const s = t.getStatus();
        if (std.mem.eql(u8, s, "pending")) report.pending_tasks += 1;
        if (std.mem.eql(u8, s, "running") or std.mem.eql(u8, s, "assigned")) report.running_tasks += 1;
        if (std.mem.eql(u8, s, "completed")) report.completed_tasks += 1;
        if (std.mem.eql(u8, s, "failed")) report.failed_tasks += 1;
    }

    return report;
}

fn checkCircuitBreakerAlerts(token: []const u8, chat_id: []const u8, last_states: *[50]bool) void {
    const agents_ptr = swarm.getAgentsPtr();
    for (agents_ptr, 0..) |*a, i| {
        if (i >= 50) break;
        if (!a.active) continue;

        const currently_tripped = a.paused and std.mem.eql(u8, a.getStatus(), "error");

        if (currently_tripped and !last_states[i]) {
            // Newly tripped — instant alert
            var alert_buf: [512]u8 = undefined;
            const agent_id = a.getId();

            // HTML-escape agent_id
            var esc_buf: [512]u8 = undefined;
            const esc_id = htmlEscape(&esc_buf, agent_id);

            const alert = std.fmt.bufPrint(&alert_buf,
                \\<b>CIRCUIT BREAKER OPEN!</b>
                \\Agent: <code>{s}</code>
                \\No-progress: {d}
            , .{ esc_id, a.no_progress_count }) catch "CB ALERT";
            sendTelegram(token, chat_id, alert);
        } else if (!currently_tripped and last_states[i]) {
            // Recovered
            sendTelegram(token, chat_id, "Circuit Breaker recovered CLOSED");
        }

        last_states[i] = currently_tripped;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GITHUB API (read-only — collect issue counts by label)
// ═══════════════════════════════════════════════════════════════════════════════

fn collectGitHubStatus(allocator: std.mem.Allocator) GitHubReport {
    var report = GitHubReport{};

    const gh_token = std.posix.getenv("GH_TOKEN") orelse
        std.posix.getenv("GITHUB_TOKEN") orelse return report;
    const owner = std.posix.getenv("GITHUB_OWNER") orelse "gHashTag";
    const repo = std.posix.getenv("GITHUB_REPO") orelse "trinity";

    // GET /repos/{owner}/{repo}/issues?labels=assign:ralph&state=all&per_page=100
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.github.com/repos/{s}/{s}/issues?labels=assign:ralph&state=all&per_page=100", .{ owner, repo }) catch return report;

    // Auth header
    var auth_buf: [300]u8 = undefined;
    const auth_val = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{gh_token}) catch return report;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Use std.Io.Writer.Allocating to capture response body
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Authorization", .value = auth_val },
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "User-Agent", .value = "trinity-oracle/1.0" },
        },
        .response_writer = &aw.writer,
    }) catch return report;

    if (result.status != .ok) return report;

    report.fetch_ok = true;
    const body = aw.written();

    // Count label occurrences in response body
    // Each issue with "status:pending" label will have that string in the JSON
    report.pending = countOccurrences(body, "\"status:pending\"");
    report.in_progress = countOccurrences(body, "\"status:in-progress\"");
    report.completed = countOccurrences(body, "\"status:completed\"");
    report.failed = countOccurrences(body, "\"status:failed\"");

    // Count open issues (state":"open")
    report.open_issues = countOccurrences(body, "\"state\":\"open\"");

    return report;
}

fn countOccurrences(haystack: []const u8, needle: []const u8) u32 {
    if (needle.len == 0 or haystack.len < needle.len) return 0;
    var count: u32 = 0;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) {
        if (std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            count += 1;
            i += needle.len;
        } else {
            i += 1;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTML FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

fn formatReportHTML(buf: []u8, r: OracleReport, gh: ?GitHubReport) []const u8 {
    // Progress bar (text)
    var bar: [20]u8 = undefined;
    const total_actionable = r.total_tasks;
    const done = r.completed_tasks;
    const pct: u32 = if (total_actionable > 0) done * 100 / total_actionable else 0;
    const filled = pct / 5;
    for (&bar, 0..) |*c, i| {
        c.* = if (i < filled) 0xE2 else 0xE2; // Will use multi-byte below
    }

    // Build progress bar string
    var pb_buf: [80]u8 = undefined;
    var pb_idx: usize = 0;
    var fi: u32 = 0;
    while (fi < 20) : (fi += 1) {
        if (fi < filled) {
            // Full block (UTF-8: E2 96 88)
            if (pb_idx + 3 <= pb_buf.len) {
                pb_buf[pb_idx] = 0xE2;
                pb_buf[pb_idx + 1] = 0x96;
                pb_buf[pb_idx + 2] = 0x88;
                pb_idx += 3;
            }
        } else {
            // Light shade (UTF-8: E2 96 91)
            if (pb_idx + 3 <= pb_buf.len) {
                pb_buf[pb_idx] = 0xE2;
                pb_buf[pb_idx + 1] = 0x96;
                pb_buf[pb_idx + 2] = 0x91;
                pb_idx += 3;
            }
        }
    }
    const progress_bar = pb_buf[0..pb_idx];

    // CB icon
    const cb_icon: []const u8 = if (r.circuit_breakers_open > 0) "\xf0\x9f\x94\xb4" else "\xf0\x9f\x9f\xa2"; // red/green circle

    var offset: usize = 0;

    const swarm_msg = std.fmt.bufPrint(buf,
        \\<b>ORACLE — Swarm Status</b>
        \\
        \\Agents: {d} total
        \\  Working: {d} | Idle: {d} | Offline: {d} | Error: {d}
        \\
        \\Tasks: {d} total
        \\<code>{s}</code> {d}/{d} ({d}%)
        \\  Pending: {d} | Running: {d} | Failed: {d}
        \\
        \\{s} CB: {d} open
    , .{
        r.active_agents,
        r.working_agents,
        r.idle_agents,
        r.offline_agents,
        r.error_agents,
        r.total_tasks,
        progress_bar,
        done,
        total_actionable,
        pct,
        r.pending_tasks,
        r.running_tasks,
        r.failed_tasks,
        cb_icon,
        r.circuit_breakers_open,
    }) catch return buf[0..0];
    offset = swarm_msg.len;

    // Append GitHub section if available
    if (gh) |g| {
        if (g.fetch_ok) {
            const gh_msg = std.fmt.bufPrint(buf[offset..],
                \\
                \\
                \\<b>GitHub Issues</b> (assign:ralph)
                \\  Open: {d} | Pending: {d} | In-Progress: {d}
                \\  Completed: {d} | Failed: {d}
            , .{
                g.open_issues,
                g.pending,
                g.in_progress,
                g.completed,
                g.failed,
            }) catch return buf[0..offset];
            offset += gh_msg.len;
        }
    }

    return buf[0..offset];
}

fn htmlEscape(buf: []u8, input: []const u8) []const u8 {
    var idx: usize = 0;
    for (input) |c| {
        switch (c) {
            '&' => {
                if (idx + 5 <= buf.len) {
                    @memcpy(buf[idx..][0..5], "&amp;");
                    idx += 5;
                }
            },
            '<' => {
                if (idx + 4 <= buf.len) {
                    @memcpy(buf[idx..][0..4], "&lt;");
                    idx += 4;
                }
            },
            '>' => {
                if (idx + 4 <= buf.len) {
                    @memcpy(buf[idx..][0..4], "&gt;");
                    idx += 4;
                }
            },
            else => {
                if (idx < buf.len) {
                    buf[idx] = c;
                    idx += 1;
                }
            },
        }
    }
    return buf[0..idx];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM HTTP CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

fn sendTelegram(token: []const u8, chat_id: []const u8, text: []const u8) void {
    // Build URL: https://api.telegram.org/bot{token}/sendMessage
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{token}) catch return;

    // Build JSON body — escape text for JSON (newlines, quotes)
    var body_buf: [MAX_MESSAGE_LEN + 512]u8 = undefined;
    var body_idx: usize = 0;

    const prefix_fmt = "{\"chat_id\":\"";
    @memcpy(body_buf[body_idx..][0..prefix_fmt.len], prefix_fmt);
    body_idx += prefix_fmt.len;
    @memcpy(body_buf[body_idx..][0..chat_id.len], chat_id);
    body_idx += chat_id.len;

    const mid_fmt = "\",\"text\":\"";
    @memcpy(body_buf[body_idx..][0..mid_fmt.len], mid_fmt);
    body_idx += mid_fmt.len;

    // JSON-escape the text
    for (text) |c| {
        if (body_idx + 2 >= body_buf.len) break;
        switch (c) {
            '"' => {
                body_buf[body_idx] = '\\';
                body_buf[body_idx + 1] = '"';
                body_idx += 2;
            },
            '\\' => {
                body_buf[body_idx] = '\\';
                body_buf[body_idx + 1] = '\\';
                body_idx += 2;
            },
            '\n' => {
                body_buf[body_idx] = '\\';
                body_buf[body_idx + 1] = 'n';
                body_idx += 2;
            },
            '\r' => {
                body_buf[body_idx] = '\\';
                body_buf[body_idx + 1] = 'r';
                body_idx += 2;
            },
            else => {
                body_buf[body_idx] = c;
                body_idx += 1;
            },
        }
    }

    const suffix_fmt = "\",\"parse_mode\":\"HTML\"}";
    if (body_idx + suffix_fmt.len <= body_buf.len) {
        @memcpy(body_buf[body_idx..][0..suffix_fmt.len], suffix_fmt);
        body_idx += suffix_fmt.len;
    }

    const body = body_buf[0..body_idx];

    // Use std.http.Client.fetch (Zig 0.15 API)
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
    }) catch {
        oracle_errors += 1;
        return;
    };

    if (result.status == .ok) {
        oracle_messages_sent += 1;
    } else {
        oracle_errors += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

fn hashMessage(msg: []const u8) u64 {
    // Simple FNV-1a hash for dedup
    var h: u64 = 14695981039346656037;
    for (msg) |byte| {
        h ^= @as(u64, byte);
        h *%= 1099511628211;
    }
    return h;
}

fn currentTimeMs() u64 {
    const ts = std.time.milliTimestamp();
    return @intCast(if (ts < 0) 0 else ts);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "html_escape basic" {
    var buf: [256]u8 = undefined;
    const result = htmlEscape(&buf, "Hello <world> & \"friends\"");
    try std.testing.expectEqualStrings("Hello &lt;world&gt; &amp; \"friends\"", result);
}

test "html_escape empty" {
    var buf: [256]u8 = undefined;
    const result = htmlEscape(&buf, "");
    try std.testing.expectEqualStrings("", result);
}

test "html_escape no special chars" {
    var buf: [256]u8 = undefined;
    const result = htmlEscape(&buf, "plain text 123");
    try std.testing.expectEqualStrings("plain text 123", result);
}

test "hash_message deterministic" {
    const h1 = hashMessage("hello");
    const h2 = hashMessage("hello");
    const h3 = hashMessage("world");
    try std.testing.expectEqual(h1, h2);
    try std.testing.expect(h1 != h3);
}

test "collect_status returns valid report" {
    // Swarm state may be populated by prior tests (static arrays)
    const report = collectStatus();
    // Just verify the function runs and returns a valid struct
    try std.testing.expect(report.active_agents <= 50);
    try std.testing.expect(report.total_tasks <= 200);
    try std.testing.expect(report.working_agents <= report.active_agents);
}

test "format_report_html produces valid output" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = OracleReport{
        .active_agents = 2,
        .working_agents = 1,
        .idle_agents = 1,
        .total_tasks = 5,
        .pending_tasks = 2,
        .completed_tasks = 3,
    };
    const msg = formatReportHTML(&buf, report, null);
    try std.testing.expect(msg.len > 0);
    // Should contain "ORACLE"
    try std.testing.expect(std.mem.indexOf(u8, msg, "ORACLE") != null);
}

test "format_report_html with github section" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = OracleReport{ .active_agents = 1 };
    const gh = GitHubReport{
        .open_issues = 5,
        .pending = 2,
        .in_progress = 1,
        .completed = 2,
        .failed = 0,
        .fetch_ok = true,
    };
    const msg = formatReportHTML(&buf, report, gh);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "GitHub Issues") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "assign:ralph") != null);
}

test "format_report_html github fetch_ok false omits section" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = OracleReport{};
    const gh = GitHubReport{ .fetch_ok = false };
    const msg = formatReportHTML(&buf, report, gh);
    try std.testing.expect(std.mem.indexOf(u8, msg, "GitHub") == null);
}

test "countOccurrences basic" {
    const body = "\"status:pending\" foo \"status:pending\" bar \"status:failed\"";
    try std.testing.expectEqual(@as(u32, 2), countOccurrences(body, "\"status:pending\""));
    try std.testing.expectEqual(@as(u32, 1), countOccurrences(body, "\"status:failed\""));
    try std.testing.expectEqual(@as(u32, 0), countOccurrences(body, "\"status:completed\""));
}

test "countOccurrences empty" {
    try std.testing.expectEqual(@as(u32, 0), countOccurrences("", "needle"));
    try std.testing.expectEqual(@as(u32, 0), countOccurrences("haystack", ""));
}

test "collectGitHubStatus returns default without token" {
    // No GH_TOKEN in test env → returns empty report with fetch_ok=false
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const report = collectGitHubStatus(gpa.allocator());
    try std.testing.expectEqual(false, report.fetch_ok);
    try std.testing.expectEqual(@as(u32, 0), report.open_issues);
}

test "oracle_status returns not running" {
    var buf: [512]u8 = undefined;
    const status = oracleStatus(&buf);
    try std.testing.expect(std.mem.indexOf(u8, status, "Running: NO") != null);
}
