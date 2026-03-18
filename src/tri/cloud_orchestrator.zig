// @origin(spec:cloud_orchestrator.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD ORCHESTRATOR — Issue-Based Container Lifecycle
// ═══════════════════════════════════════════════════════════════════════════════
//
// Each GitHub issue = one Railway service = one Docker container = one agent.
// State persisted to .trinity/cloud_agents.json
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const railway_farm = @import("railway_farm.zig");

const STATE_FILE = ".trinity/cloud_agents.json";
const METRICS_FILE = ".trinity/agent_metrics.json";
const AGENT_IMAGE = "ghcr.io/ghashtag/trinity-agent:latest";
const MAX_AGENTS = 75;
const MAX_CONCURRENT_AGENTS: u32 = 75; // Farm mode: 3 accounts × 25 = 75
const MAX_METRICS: usize = 1000;

pub const SpawnResult = struct {
    service_id: []const u8,
    issue_number: u32,
    status: []const u8,
};

pub const AgentEntry = struct {
    issue: u32,
    service_id: [128]u8,
    service_id_len: usize,
    account_id: u8, // Railway account that owns this service (0 = legacy/primary)
    created_at: i64,
    active: bool,

    pub fn getServiceId(self: *const AgentEntry) []const u8 {
        return self.service_id[0..self.service_id_len];
    }
};

pub const MetricEntry = struct {
    issue: u32,
    result: [16]u8,
    result_len: usize,
    time_to_pr: ?i64,
    files_changed: u32,
    lines_added: u32,
    lines_removed: u32,
    pr_number: ?u32,
    created_at: i64,

    pub fn getResult(self: *const MetricEntry) []const u8 {
        return self.result[0..self.result_len];
    }
};

pub const MetricsSummary = struct {
    total: u32,
    success: u32,
    failed: u32,
    killed: u32,
    avg_time_to_pr: f64,
    total_files_changed: u32,
    total_lines_added: u32,
    total_lines_removed: u32,
};

var agents: [MAX_AGENTS]AgentEntry = undefined;
var agent_count: usize = 0;
var state_loaded: bool = false;

var metrics_store: [MAX_METRICS]MetricEntry = undefined;
var metrics_count: usize = 0;
var metrics_loaded: bool = false;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Spawn a new agent container for the given issue number.
/// If account_hint is non-null, uses that specific Railway account.
/// Otherwise, the farm scheduler picks the least-loaded account.
pub fn spawnAgent(allocator: Allocator, issue_number: u32) !SpawnResult {
    return spawnAgentOnAccount(allocator, issue_number, null);
}

/// Spawn on a specific account (or auto-select if account_hint is null).
pub fn spawnAgentOnAccount(allocator: Allocator, issue_number: u32, account_hint: ?u8) !SpawnResult {
    loadState();

    // P0.4: Check if agent already exists for this issue (duplicate guard)
    for (agents[0..agent_count]) |*a| {
        if (a.issue == issue_number and a.active) {
            return SpawnResult{
                .service_id = a.getServiceId(),
                .issue_number = issue_number,
                .status = "already_exists",
            };
        }
    }

    // Initialize farm for multi-account support
    var farm = railway_farm.RailwayFarm.init();

    // Determine which account to use
    const target_account_id: u8 = blk: {
        if (account_hint) |hint| break :blk hint;
        if (farm.account_count > 1) {
            // Multi-account: use farm scheduler
            const acct = farm.selectAccount() orelse {
                return SpawnResult{
                    .service_id = "",
                    .issue_number = issue_number,
                    .status = "limit_reached",
                };
            };
            break :blk acct.id;
        }
        // Single account: use legacy concurrent limit check
        var active_count: u32 = 0;
        for (agents[0..agent_count]) |*a| {
            if (a.active) active_count += 1;
        }
        if (active_count >= MAX_CONCURRENT_AGENTS) {
            return SpawnResult{
                .service_id = "",
                .issue_number = issue_number,
                .status = "limit_reached",
            };
        }
        break :blk 1; // primary
    };

    // Get API client for selected account
    var api = farm.getApi(allocator, target_account_id) catch
        railway_api.RailwayApi.init(allocator) catch
        return error.ApiInitFailed;
    defer api.deinit();

    // 1. Create Railway service
    const name = std.fmt.allocPrint(allocator, "agent-{d}", .{issue_number}) catch
        return error.OutOfMemory;
    defer allocator.free(name);

    const create_response = api.createService(name) catch
        return error.ServiceCreateFailed;
    defer allocator.free(create_response);

    // Extract service ID from response
    const service_id = extractId(create_response) orelse
        return error.InvalidResponse;

    // 2. Connect Docker image source (critical — cannot deploy without it)
    api.connectServiceSource(service_id, AGENT_IMAGE) catch |err| {
        std.log.err("cloud_orchestrator: failed to connect service source: {} — aborting spawn", .{err});
        return error.ServiceSourceConnectionFailed;
    };

    // 3. Set environment variables
    // Use account's environment_id if available, else fallback to env var
    const env_id = if (api.environment_id.len > 0)
        api.environment_id
    else
        std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch {
            std.log.err("cloud_orchestrator: RAILWAY_ENVIRONMENT_ID not set — cannot spawn agent", .{});
            return error.MissingEnvVar;
        };
    const env_id_owned = api.environment_id.len == 0;
    defer if (env_id_owned) allocator.free(env_id);

    const issue_str = std.fmt.allocPrint(allocator, "{d}", .{issue_number}) catch
        return error.OutOfMemory;
    defer allocator.free(issue_str);
    api.upsertVariable(service_id, env_id, "ISSUE_NUMBER", issue_str) catch |err| {
        std.log.err("cloud_orchestrator: failed to set ISSUE_NUMBER: {}", .{err});
        return error.EnvVarSetFailed;
    };

    // Forward tokens from env (prefer AGENT_GH_TOKEN PAT over ephemeral GITHUB_TOKEN)
    const gh_token = std.process.getEnvVarOwned(allocator, "AGENT_GH_TOKEN") catch
        std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch {
        std.log.err("cloud_orchestrator: neither AGENT_GH_TOKEN nor GITHUB_TOKEN set — cannot spawn agent", .{});
        return error.MissingEnvVar;
    };
    defer allocator.free(gh_token);
    api.upsertVariable(service_id, env_id, "GITHUB_TOKEN", gh_token) catch |err| {
        std.log.err("cloud_orchestrator: failed to set GITHUB_TOKEN: {}", .{err});
        return error.EnvVarSetFailed;
    };

    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch {
        std.log.err("cloud_orchestrator: ANTHROPIC_API_KEY not set — cannot spawn agent", .{});
        return error.MissingEnvVar;
    };
    defer allocator.free(api_key);
    api.upsertVariable(service_id, env_id, "ANTHROPIC_API_KEY", api_key) catch |err| {
        std.log.err("cloud_orchestrator: failed to set ANTHROPIC_API_KEY: {}", .{err});
        return error.EnvVarSetFailed;
    };

    // Non-critical vars: warn but continue
    const ws_url = std.process.getEnvVarOwned(allocator, "WS_MONITOR_URL") catch "";
    if (ws_url.len > 0) {
        api.upsertVariable(service_id, env_id, "WS_MONITOR_URL", ws_url) catch |err| {
            std.log.warn("cloud_orchestrator: failed to set WS_MONITOR_URL: {}", .{err});
        };
        allocator.free(ws_url);
    }

    const tg_token = std.process.getEnvVarOwned(allocator, "TELEGRAM_BOT_TOKEN") catch "";
    if (tg_token.len > 0) {
        api.upsertVariable(service_id, env_id, "TELEGRAM_BOT_TOKEN", tg_token) catch |err| {
            std.log.warn("cloud_orchestrator: failed to set TELEGRAM_BOT_TOKEN: {}", .{err});
        };
        allocator.free(tg_token);
    }

    const tg_chat = std.process.getEnvVarOwned(allocator, "TELEGRAM_CHAT_ID") catch "";
    if (tg_chat.len > 0) {
        api.upsertVariable(service_id, env_id, "TELEGRAM_CHAT_ID", tg_chat) catch |err| {
            std.log.warn("cloud_orchestrator: failed to set TELEGRAM_CHAT_ID: {}", .{err});
        };
        allocator.free(tg_chat);
    }

    // Enable Telegram log streaming by default
    api.upsertVariable(service_id, env_id, "TELEGRAM_STREAM", "true") catch |err| {
        std.log.warn("cloud_orchestrator: failed to set TELEGRAM_STREAM: {}", .{err});
    };

    const mon_token = std.process.getEnvVarOwned(allocator, "MONITOR_TOKEN") catch "";
    if (mon_token.len > 0) {
        api.upsertVariable(service_id, env_id, "MONITOR_TOKEN", mon_token) catch |err| {
            std.log.warn("cloud_orchestrator: failed to set MONITOR_TOKEN: {}", .{err});
        };
        allocator.free(mon_token);
    }

    // 4. Save to state
    if (agent_count < MAX_AGENTS) {
        var entry = &agents[agent_count];
        entry.issue = issue_number;
        entry.account_id = target_account_id;
        entry.active = true;
        entry.created_at = std.time.timestamp();
        entry.service_id_len = @min(service_id.len, 128);
        @memcpy(entry.service_id[0..entry.service_id_len], service_id[0..entry.service_id_len]);
        agent_count += 1;
    }

    // Also record in farm agent_map for cross-account tracking
    farm.recordAgent(issue_number, target_account_id, service_id);
    saveState();

    return SpawnResult{
        .service_id = service_id,
        .issue_number = issue_number,
        .status = "spawned",
    };
}

/// Kill an agent container for the given issue number.
/// Uses farm to find the correct Railway account for the agent.
pub fn killAgent(allocator: Allocator, issue_number: u32) !void {
    loadState();

    for (agents[0..agent_count]) |*a| {
        if (a.issue == issue_number and a.active) {
            // Use account-specific API if available, fallback to primary
            var farm = railway_farm.RailwayFarm.init();
            var api = farm.getApi(allocator, a.account_id) catch
                railway_api.RailwayApi.init(allocator) catch
                return error.ApiInitFailed;
            defer api.deinit();

            _ = api.deleteService(a.getServiceId()) catch |err| {
                std.log.err("cloud_orchestrator: deleteService failed for issue #{d}: {} — container may still be running on Railway", .{ issue_number, err });
                return error.ServiceDeleteFailed;
            };
            a.active = false;
            farm.removeAgent(issue_number);
            saveState();
            return;
        }
    }
    return error.AgentNotFound;
}

/// List all active agents as JSON string.
pub fn listAgents(buf: []u8) []const u8 {
    loadState();

    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    w.writeAll("{\"agents\":[") catch return "{}";

    var first = true;
    for (agents[0..agent_count]) |*a| {
        if (!a.active) continue;
        if (!first) w.writeAll(",") catch |err| {
            std.log.debug("cloud_orchestrator: JSON write comma failed: {}", .{err});
        };
        first = false;
        std.fmt.format(w, "{{\"issue\":{d},\"service_id\":\"{s}\",\"account_id\":{d},\"created_at\":{d}}}", .{
            a.issue,
            a.getServiceId(),
            a.account_id,
            a.created_at,
        }) catch break;
    }

    w.writeAll("],\"count\":") catch |err| {
        std.log.debug("cloud_orchestrator: JSON write count key failed: {}", .{err});
    };
    var active: u32 = 0;
    for (agents[0..agent_count]) |*a| {
        if (a.active) active += 1;
    }
    std.fmt.format(w, "{d},\"max\":{d}}}", .{ active, MAX_CONCURRENT_AGENTS }) catch |err| {
        std.log.debug("cloud_orchestrator: JSON format count failed: {}", .{err});
    };

    return fbs.getWritten();
}

/// Cleanup all agents marked as done (inactive). Returns count cleaned.
pub fn cleanupDone(allocator: Allocator) !u32 {
    _ = allocator;
    loadState();

    var cleaned: u32 = 0;

    // Compact the array — remove inactive entries
    var write_idx: usize = 0;
    for (agents[0..agent_count]) |a| {
        if (a.active) {
            agents[write_idx] = a;
            write_idx += 1;
        } else {
            cleaned += 1;
        }
    }
    agent_count = write_idx;
    saveState();

    return cleaned;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL
// ═══════════════════════════════════════════════════════════════════════════════

fn extractId(json: []const u8) ?[]const u8 {
    // Find "id":"..." in JSON response
    const needle = "\"id\":\"";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end];
}

fn loadState() void {
    if (state_loaded) return;
    state_loaded = true;

    const file = std.fs.cwd().openFile(STATE_FILE, .{}) catch return;
    defer file.close();

    var buf: [16384]u8 = undefined;
    const len = file.readAll(&buf) catch return;
    const content = buf[0..len];

    // Simple parse: find issue/service_id pairs
    var offset: usize = 0;
    agent_count = 0;
    while (agent_count < MAX_AGENTS) {
        const issue_needle = "\"issue\":";
        const issue_idx = std.mem.indexOfPos(u8, content, offset, issue_needle) orelse break;
        const issue_start = issue_idx + issue_needle.len;
        var issue_end = issue_start;
        while (issue_end < content.len and content[issue_end] >= '0' and content[issue_end] <= '9') : (issue_end += 1) {}
        const issue_num = std.fmt.parseInt(u32, content[issue_start..issue_end], 10) catch break;

        const sid_needle = "\"service_id\":\"";
        const sid_idx = std.mem.indexOfPos(u8, content, issue_end, sid_needle) orelse break;
        const sid_start = sid_idx + sid_needle.len;
        const sid_end = std.mem.indexOfPos(u8, content, sid_start, "\"") orelse break;
        const sid = content[sid_start..sid_end];

        // Parse optional account_id
        var acct_id: u8 = 0;
        if (std.mem.indexOfPos(u8, content, sid_end, "\"account_id\":")) |aid_idx| {
            const aid_start = aid_idx + 13;
            var aid_end = aid_start;
            while (aid_end < content.len and content[aid_end] >= '0' and content[aid_end] <= '9') : (aid_end += 1) {}
            acct_id = std.fmt.parseInt(u8, content[aid_start..aid_end], 10) catch 0;
        }

        var entry = &agents[agent_count];
        entry.issue = issue_num;
        entry.account_id = acct_id;
        entry.active = true;
        entry.created_at = 0;
        entry.service_id_len = @min(sid.len, 128);
        @memcpy(entry.service_id[0..entry.service_id_len], sid[0..entry.service_id_len]);
        agent_count += 1;
        offset = @min(sid_end + 1, content.len);
    }
}

fn saveState() void {
    // Ensure .trinity/ directory exists
    std.fs.cwd().makePath(".trinity") catch return;

    // Build JSON in memory, then write at once
    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();
    w.writeAll("[") catch return;

    var first = true;
    for (agents[0..agent_count]) |*a| {
        if (!a.active) continue;
        if (!first) w.writeAll(",") catch |err| {
            std.log.debug("cloud_orchestrator: history JSON comma failed: {}", .{err});
        };
        first = false;
        std.fmt.format(w, "\n  {{\"issue\":{d},\"service_id\":\"{s}\",\"account_id\":{d},\"created_at\":{d}}}", .{
            a.issue,
            a.getServiceId(),
            a.account_id,
            a.created_at,
        }) catch return;
    }

    w.writeAll("\n]\n") catch return;

    const file = std.fs.cwd().createFile(STATE_FILE, .{}) catch return;
    defer file.close();
    file.writeAll(fbs.getWritten()) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS API
// ═══════════════════════════════════════════════════════════════════════════════

/// Record agent metrics after completion.
pub fn recordMetrics(
    allocator: Allocator,
    issue: u32,
    result: []const u8,
    time_to_pr: ?i64,
    files_changed: u32,
    lines_added: u32,
    lines_removed: u32,
    pr_number: ?u32,
) !void {
    _ = allocator;
    loadMetrics();

    if (metrics_count < MAX_METRICS) {
        var entry = &metrics_store[metrics_count];
        entry.issue = issue;
        entry.result_len = @min(result.len, 16);
        @memcpy(entry.result[0..entry.result_len], result[0..entry.result_len]);
        entry.time_to_pr = time_to_pr;
        entry.files_changed = files_changed;
        entry.lines_added = lines_added;
        entry.lines_removed = lines_removed;
        entry.pr_number = pr_number;
        entry.created_at = std.time.timestamp();
        metrics_count += 1;
    }

    saveMetrics();
}

/// Get aggregate metrics summary.
pub fn getMetrics() MetricsSummary {
    loadMetrics();

    var summary = MetricsSummary{
        .total = @intCast(metrics_count),
        .success = 0,
        .failed = 0,
        .killed = 0,
        .avg_time_to_pr = 0,
        .total_files_changed = 0,
        .total_lines_added = 0,
        .total_lines_removed = 0,
    };

    var time_sum: i64 = 0;
    var time_count: u32 = 0;

    for (metrics_store[0..metrics_count]) |*m| {
        const res = m.getResult();
        if (std.mem.eql(u8, res, "success")) {
            summary.success += 1;
        } else if (std.mem.eql(u8, res, "failed")) {
            summary.failed += 1;
        } else if (std.mem.eql(u8, res, "killed")) {
            summary.killed += 1;
        }

        if (m.time_to_pr) |ttp| {
            time_sum += ttp;
            time_count += 1;
        }

        summary.total_files_changed += m.files_changed;
        summary.total_lines_added += m.lines_added;
        summary.total_lines_removed += m.lines_removed;
    }

    if (time_count > 0) {
        summary.avg_time_to_pr = @as(f64, @floatFromInt(time_sum)) / @as(f64, @floatFromInt(time_count));
    }

    return summary;
}

/// List all metric entries as JSON string.
pub fn listMetrics(buf: []u8) []const u8 {
    loadMetrics();

    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();
    w.writeAll("{\"metrics\":[") catch return "{}";

    var first = true;
    for (metrics_store[0..metrics_count]) |*m| {
        if (!first) w.writeAll(",") catch |err| {
            std.log.debug("cloud_orchestrator: metrics JSON comma failed: {}", .{err});
        };
        first = false;

        std.fmt.format(w, "{{\"issue\":{d},\"result\":\"{s}\",\"files_changed\":{d},\"lines_added\":{d},\"lines_removed\":{d},\"created_at\":{d}}}", .{
            m.issue,
            m.getResult(),
            m.files_changed,
            m.lines_added,
            m.lines_removed,
            m.created_at,
        }) catch break;
    }

    w.writeAll("],\"count\":") catch |err| {
        std.log.debug("cloud_orchestrator: metrics JSON tail failed: {}", .{err});
    };
    std.fmt.format(w, "{d}}}", .{metrics_count}) catch |err| {
        std.log.debug("cloud_orchestrator: metrics count write failed: {}", .{err});
    };

    return fbs.getWritten();
}

fn loadMetrics() void {
    if (metrics_loaded) return;
    metrics_loaded = true;

    const file = std.fs.cwd().openFile(METRICS_FILE, .{}) catch return;
    defer file.close();

    var buf: [65536]u8 = undefined;
    const len = file.readAll(&buf) catch return;
    const content = buf[0..len];

    var offset: usize = 0;
    metrics_count = 0;
    while (metrics_count < MAX_METRICS) {
        const issue_needle = "\"issue\":";
        const issue_idx = std.mem.indexOfPos(u8, content, offset, issue_needle) orelse break;
        const issue_start = issue_idx + issue_needle.len;
        var issue_end = issue_start;
        while (issue_end < content.len and content[issue_end] >= '0' and content[issue_end] <= '9') : (issue_end += 1) {}
        const issue_num = std.fmt.parseInt(u32, content[issue_start..issue_end], 10) catch break;

        const result_needle = "\"result\":\"";
        const result_idx = std.mem.indexOfPos(u8, content, issue_end, result_needle) orelse break;
        const result_start = result_idx + result_needle.len;
        const result_end = std.mem.indexOfPos(u8, content, result_start, "\"") orelse break;
        const result_str = content[result_start..result_end];

        var entry = &metrics_store[metrics_count];
        entry.issue = issue_num;
        entry.result_len = @min(result_str.len, 16);
        @memcpy(entry.result[0..entry.result_len], result_str[0..entry.result_len]);
        entry.time_to_pr = parseOptionalI64(content, result_end, "\"time_to_pr\":");
        entry.files_changed = parseU32(content, result_end, "\"files_changed\":") catch 0;
        entry.lines_added = parseU32(content, result_end, "\"lines_added\":") catch 0;
        entry.lines_removed = parseU32(content, result_end, "\"lines_removed\":") catch 0;
        entry.pr_number = parseOptionalU32(content, result_end, "\"pr_number\":");
        entry.created_at = parseI64(content, result_end, "\"created_at\":") catch 0;

        metrics_count += 1;
        offset = result_end + 1;
    }
}

fn saveMetrics() void {
    std.fs.cwd().makePath(".trinity") catch |err| {
        std.log.warn("cloud_orchestrator: failed to create .trinity dir: {}", .{err});
        return;
    };

    var buf: [131072]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();
    w.writeAll("[") catch return;

    var first = true;
    for (metrics_store[0..metrics_count]) |*m| {
        if (!first) w.writeAll(",") catch return;
        first = false;

        std.fmt.format(w, "\n  {{\"issue\":{d},\"result\":\"{s}\",\"files_changed\":{d},\"lines_added\":{d},\"lines_removed\":{d},\"created_at\":{d}}}", .{
            m.issue,
            m.getResult(),
            m.files_changed,
            m.lines_added,
            m.lines_removed,
            m.created_at,
        }) catch return;
    }

    w.writeAll("\n]\n") catch return;

    const file = std.fs.cwd().createFile(METRICS_FILE, .{}) catch return;
    defer file.close();
    file.writeAll(fbs.getWritten()) catch return;
}

fn parseU32(content: []const u8, start: usize, needle: []const u8) !u32 {
    const idx = std.mem.indexOfPos(u8, content, start, needle) orelse return error.NotFound;
    const val_start = idx + needle.len;
    var val_end = val_start;
    while (val_end < content.len and content[val_end] >= '0' and content[val_end] <= '9') : (val_end += 1) {}
    return std.fmt.parseInt(u32, content[val_start..val_end], 10) catch error.ParseError;
}

fn parseI64(content: []const u8, start: usize, needle: []const u8) !i64 {
    const idx = std.mem.indexOfPos(u8, content, start, needle) orelse return error.NotFound;
    const val_start = idx + needle.len;
    var val_end = val_start;
    while (val_end < content.len and ((content[val_end] >= '0' and content[val_end] <= '9') or content[val_end] == '-')) : (val_end += 1) {}
    return std.fmt.parseInt(i64, content[val_start..val_end], 10) catch error.ParseError;
}

fn parseOptionalU32(content: []const u8, start: usize, needle: []const u8) ?u32 {
    const idx = std.mem.indexOfPos(u8, content, start, needle) orelse return null;
    const val_start = idx + needle.len;
    if (std.mem.startsWith(u8, content[val_start..], "null")) return null;
    var val_end = val_start;
    while (val_end < content.len and content[val_end] >= '0' and content[val_end] <= '9') : (val_end += 1) {}
    return std.fmt.parseInt(u32, content[val_start..val_end], 10) catch null;
}

fn parseOptionalI64(content: []const u8, start: usize, needle: []const u8) ?i64 {
    const idx = std.mem.indexOfPos(u8, content, start, needle) orelse return null;
    const val_start = idx + needle.len;
    if (std.mem.startsWith(u8, content[val_start..], "null")) return null;
    var val_end = val_start;
    while (val_end < content.len and ((content[val_end] >= '0' and content[val_end] <= '9') or content[val_end] == '-')) : (val_end += 1) {}
    return std.fmt.parseInt(i64, content[val_start..val_end], 10) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "extractId basic" {
    const json = "{\"data\":{\"serviceCreate\":{\"id\":\"abc-123\",\"name\":\"agent-42\"}}}";
    const id = extractId(json);
    try std.testing.expectEqualStrings("abc-123", id.?);
}

test "listAgents empty" {
    state_loaded = true;
    agent_count = 0;
    var buf: [1024]u8 = undefined;
    const result = listAgents(&buf);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"count\":0") != null);
}
