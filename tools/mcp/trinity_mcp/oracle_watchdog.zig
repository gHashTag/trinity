//! ORACLE Telegram Watchdog — Real system status observer
//! phi^2 + 1/phi^2 = 3 | TRINITY
//!
//! Collects REAL metrics via shell commands:
//! - Build status (zig build exit code)
//! - Git activity (last commit, dirty files)
//! - GitHub issues (open count, in-progress)
//! - Bridge agent (pgrep tri-bridge-agent)
//! - Training (pgrep hslm-train)
//!
//! Sends to Telegram only when data changes (FNV-1a dedup).

const std = @import("std");
const swarm = @import("swarm_tools.zig");
const mu_doctor = @import("mu_doctor.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_INTERVAL_MS: u64 = 300_000; // 5 minutes
const MAX_MESSAGE_LEN: usize = 4096;
const ALERT_COOLDOWN_MS: u64 = 60_000;
const HEARTBEAT_TIMEOUT_MS: u64 = 120_000;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const OracleConfig = struct {
    telegram_token: []const u8,
    chat_id: []const u8,
    interval_ms: u64 = DEFAULT_INTERVAL_MS,
};

const LiveReport = struct {
    // Build
    build_ok: bool = false,
    build_error_count: u32 = 0,

    // Git
    last_commit: [128]u8 = [_]u8{0} ** 128,
    last_commit_len: usize = 0,
    dirty_files: u32 = 0,
    branch: [64]u8 = [_]u8{0} ** 64,
    branch_len: usize = 0,

    // GitHub
    open_issues: u32 = 0,
    in_progress_issues: u32 = 0,
    gh_available: bool = false,

    // Bridge
    bridge_agent_up: bool = false,

    // Ralph
    ralph_agent_up: bool = false,

    // MU Doctor
    mu_doctor_active: bool = false,
    mu_last_heal_count: u32 = 0,
    mu_status: [64]u8 = [_]u8{0} ** 64,
    mu_status_len: usize = 0,

    // Training
    training_active: bool = false,

    // Swarm (keep for backward compat)
    active_agents: u32 = 0,
    working_agents: u32 = 0,
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
    const startup_msg = std.fmt.bufPrint(
        &startup_buf,
        "<b>ORACLE v2 started</b>\nInterval: {d} min\nMode: live system metrics",
        .{stored_interval_ms / 60_000},
    ) catch "ORACLE started";
    sendTelegram(token, chat_id, startup_msg);

    var last_hash: u64 = 0;

    // Allocator for shell commands
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (oracle_running.load(.acquire)) {
        // Collect REAL system status
        var report = collectLiveStatus(allocator);

        // MU DOCTOR: diagnose and heal
        const signal = mu_doctor.HealthSignal{
            .build_ok = report.build_ok,
            .ralph_up = report.ralph_agent_up,
            .bridge_up = report.bridge_agent_up,
            .training_active = report.training_active,
            .dirty_files = report.dirty_files,
            .timestamp_ms = currentTimeMs(),
        };
        const heal_report = mu_doctor.diagnoseAndHeal(allocator, signal);

        // Update report with MU Doctor status
        report.mu_doctor_active = true;
        report.mu_last_heal_count = @intCast(heal_report.healed_count);
        var mu_status_buf: [64]u8 = undefined;
        const mu_status = heal_report.formatStatus(&mu_status_buf);
        const mu_copy_len = @min(mu_status.len, report.mu_status.len);
        @memcpy(report.mu_status[0..mu_copy_len], mu_status[0..mu_copy_len]);
        report.mu_status_len = mu_copy_len;

        // Format report
        var msg_buf: [MAX_MESSAGE_LEN]u8 = undefined;
        const msg = formatLiveReportHTML(&msg_buf, report);

        // Smart dedup — only send when data changes
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

    sendTelegram(token, chat_id, "<b>ORACLE v2 stopped</b>");
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE STATUS COLLECTION (shell commands for real data)
// ═══════════════════════════════════════════════════════════════════════════════

fn collectLiveStatus(allocator: std.mem.Allocator) LiveReport {
    var report = LiveReport{};

    // 1. Build status: zig build 2>&1 | wc -l (error count)
    report.build_ok = runCheckExitCode(allocator, &.{ "zig", "build" });

    // 2. Git: last commit
    if (runCommand(allocator, &.{ "git", "log", "--oneline", "-1" })) |output| {
        defer allocator.free(output);
        const trimmed = std.mem.trimRight(u8, output, "\n\r ");
        const copy_len = @min(trimmed.len, report.last_commit.len);
        @memcpy(report.last_commit[0..copy_len], trimmed[0..copy_len]);
        report.last_commit_len = copy_len;
    }

    // 3. Git: branch
    if (runCommand(allocator, &.{ "git", "branch", "--show-current" })) |output| {
        defer allocator.free(output);
        const trimmed = std.mem.trimRight(u8, output, "\n\r ");
        const copy_len = @min(trimmed.len, report.branch.len);
        @memcpy(report.branch[0..copy_len], trimmed[0..copy_len]);
        report.branch_len = copy_len;
    }

    // 4. Git: dirty files count
    if (runCommand(allocator, &.{ "git", "status", "--short" })) |output| {
        defer allocator.free(output);
        var count: u32 = 0;
        var iter = std.mem.splitScalar(u8, output, '\n');
        while (iter.next()) |line| {
            if (line.len > 0) count += 1;
        }
        report.dirty_files = count;
    }

    // 5. GitHub: open issues count
    if (runCommand(allocator, &.{ "gh", "issue", "list", "--state", "open", "--json", "number", "--limit", "50" })) |output| {
        defer allocator.free(output);
        report.gh_available = true;
        // Count "number" occurrences
        var count: u32 = 0;
        var i: usize = 0;
        while (i + 8 < output.len) : (i += 1) {
            if (std.mem.eql(u8, output[i..][0..8], "\"number\"")) count += 1;
        }
        report.open_issues = count;

        // Count in-progress (search for status:in-progress in labels)
        // Simpler: just count from a separate call
    }

    // 6. Bridge agent: pgrep
    report.bridge_agent_up = runCheckExitCode(allocator, &.{ "pgrep", "-f", "tri-bridge-agent" });

    // 6b. Ralph agent: pgrep
    report.ralph_agent_up = runCheckExitCode(allocator, &.{ "pgrep", "-x", "ralph-agent" });

    // 7. Training: pgrep hslm-train
    report.training_active = runCheckExitCode(allocator, &.{ "pgrep", "-f", "hslm-train" });

    // 8. MU Doctor is always active when oracle runs (same process)
    report.mu_doctor_active = true;

    // 9. Swarm memory (keep for any agents that registered)
    const agents_ptr = swarm.getAgentsPtr();
    for (agents_ptr) |*a| {
        if (!a.active) continue;
        report.active_agents += 1;
        const s = a.getStatus();
        if (std.mem.eql(u8, s, "working")) report.working_agents += 1;
    }

    return report;
}

/// Run a command and return stdout (caller owns memory), or null on failure
fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) ?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 8192,
    }) catch return null;
    allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    return result.stdout;
}

/// Run a command, return true if exit code == 0
fn runCheckExitCode(allocator: std.mem.Allocator, argv: []const []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 8192,
    }) catch return false;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return result.term.Exited == 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTML FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

fn formatLiveReportHTML(buf: []u8, r: LiveReport) []const u8 {
    const build_icon: []const u8 = if (r.build_ok) "\xe2\x9c\x85" else "\xe2\x9d\x8c"; // checkmark / X
    const bridge_icon: []const u8 = if (r.bridge_agent_up) "\xf0\x9f\x9f\xa2" else "\xf0\x9f\x94\xb4"; // green/red circle
    const ralph_icon: []const u8 = if (r.ralph_agent_up) "\xf0\x9f\x9f\xa2" else "\xf0\x9f\x94\xb4"; // green/red circle
    const train_icon: []const u8 = if (r.training_active) "\xf0\x9f\x8f\x83" else "\xe2\xac\x9c"; // runner / white
    const mu_icon: []const u8 = if (r.mu_status_len == 0 or std.mem.eql(u8, r.mu_status[0..@min(r.mu_status_len, 2)], "OK"))
        "\xf0\x9f\x9f\xa2" // green circle
    else if (r.mu_last_heal_count > 0)
        "\xf0\x9f\x94\xa7" // wrench
    else
        "\xf0\x9f\x94\xb4"; // red circle

    const branch = if (r.branch_len > 0) r.branch[0..r.branch_len] else "?";
    const commit = if (r.last_commit_len > 0) r.last_commit[0..r.last_commit_len] else "?";
    const mu_status: []const u8 = if (r.mu_status_len > 0) r.mu_status[0..r.mu_status_len] else "inactive";

    const dirty_icon: []const u8 = if (r.dirty_files == 0) "\xe2\x9c\x85" else "\xe2\x9a\xa0\xef\xb8\x8f"; // checkmark / warning

    var offset: usize = 0;

    // Main report
    const main_msg = std.fmt.bufPrint(buf,
        \\<b>ORACLE v2</b>
        \\
        \\{s} <b>Build</b>: {s}
        \\{s} <b>Dirty</b>: {d} files
        \\
        \\Branch: <code>{s}</code>
        \\Commit: <code>{s}</code>
        \\
        \\{s} <b>Bridge</b>: {s}
        \\{s} <b>Ralph</b>: {s}
        \\{s} <b>MU Doctor</b>: {s}
        \\{s} <b>Training</b>: {s}
    , .{
        build_icon,
        if (r.build_ok) "OK" else "FAIL",
        dirty_icon,
        r.dirty_files,
        branch,
        commit,
        bridge_icon,
        if (r.bridge_agent_up) "ONLINE" else "OFFLINE",
        ralph_icon,
        if (r.ralph_agent_up) "UP" else "DOWN",
        mu_icon,
        mu_status,
        train_icon,
        if (r.training_active) "RUNNING" else "idle",
    }) catch return buf[0..0];
    offset = main_msg.len;

    // GitHub section
    if (r.gh_available) {
        const gh_msg = std.fmt.bufPrint(buf[offset..],
            \\
            \\
            \\<b>GitHub</b>: {d} open issues
        , .{
            r.open_issues,
        }) catch return buf[0..offset];
        offset += gh_msg.len;
    }

    // Swarm section (only if agents registered)
    if (r.active_agents > 0) {
        const swarm_msg = std.fmt.bufPrint(buf[offset..],
            \\
            \\
            \\<b>Swarm</b>: {d} agents ({d} working)
        , .{
            r.active_agents,
            r.working_agents,
        }) catch return buf[0..offset];
        offset += swarm_msg.len;
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
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{token}) catch return;

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

test "format_live_report produces valid output" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = LiveReport{
        .build_ok = true,
        .dirty_files = 3,
        .bridge_agent_up = true,
        .training_active = false,
        .branch_len = 4,
        .branch = blk: {
            var b: [64]u8 = [_]u8{0} ** 64;
            @memcpy(b[0..4], "main");
            break :blk b;
        },
        .last_commit_len = 7,
        .last_commit = blk: {
            var b: [128]u8 = [_]u8{0} ** 128;
            @memcpy(b[0..7], "abc1234");
            break :blk b;
        },
        .open_issues = 8,
        .gh_available = true,
    };
    const msg = formatLiveReportHTML(&buf, report);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "ORACLE v2") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Build") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Ralph") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "GitHub") != null);
}

test "format_live_report no github" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = LiveReport{ .build_ok = false };
    const msg = formatLiveReportHTML(&buf, report);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "FAIL") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "GitHub") == null);
}

test "format_live_report with swarm" {
    var buf: [MAX_MESSAGE_LEN]u8 = undefined;
    const report = LiveReport{
        .build_ok = true,
        .active_agents = 3,
        .working_agents = 2,
    };
    const msg = formatLiveReportHTML(&buf, report);
    try std.testing.expect(std.mem.indexOf(u8, msg, "Swarm") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "3 agents") != null);
}

test "oracle_status returns not running" {
    var buf: [512]u8 = undefined;
    const status = oracleStatus(&buf);
    try std.testing.expect(std.mem.indexOf(u8, status, "Running: NO") != null);
}
