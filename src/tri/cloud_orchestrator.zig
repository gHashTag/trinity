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

const STATE_FILE = ".trinity/cloud_agents.json";
const AGENT_IMAGE = "ghcr.io/ghashtag/trinity-agent:latest";
const MAX_AGENTS = 50;
const MAX_CONCURRENT_AGENTS: u32 = 10; // P0.3: Railway billing guard

pub const SpawnResult = struct {
    service_id: []const u8,
    issue_number: u32,
    status: []const u8,
};

pub const AgentEntry = struct {
    issue: u32,
    service_id: [128]u8,
    service_id_len: usize,
    created_at: i64,
    active: bool,

    pub fn getServiceId(self: *const AgentEntry) []const u8 {
        return self.service_id[0..self.service_id_len];
    }
};

var agents: [MAX_AGENTS]AgentEntry = undefined;
var agent_count: usize = 0;
var state_loaded: bool = false;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Spawn a new agent container for the given issue number.
pub fn spawnAgent(allocator: Allocator, issue_number: u32) !SpawnResult {
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

    // P0.3: Check concurrent agent limit (Railway billing guard)
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

    var api = railway_api.RailwayApi.init(allocator) catch
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

    // 2. Connect Docker image source
    _ = api.connectServiceSource(service_id, AGENT_IMAGE) catch {};

    // 3. Set environment variables
    const env_id = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";
    if (env_id.len > 0) {
        const issue_str = std.fmt.allocPrint(allocator, "{d}", .{issue_number}) catch "";
        if (issue_str.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "ISSUE_NUMBER", issue_str) catch {};
            allocator.free(issue_str);
        }

        // Forward tokens from env (prefer AGENT_GH_TOKEN PAT over ephemeral GITHUB_TOKEN)
        const gh_token = std.process.getEnvVarOwned(allocator, "AGENT_GH_TOKEN") catch
            std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch "";
        if (gh_token.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "GITHUB_TOKEN", gh_token) catch {};
            allocator.free(gh_token);
        }

        const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch "";
        if (api_key.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "ANTHROPIC_API_KEY", api_key) catch {};
            allocator.free(api_key);
        }

        const ws_url = std.process.getEnvVarOwned(allocator, "WS_MONITOR_URL") catch "";
        if (ws_url.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "WS_MONITOR_URL", ws_url) catch {};
            allocator.free(ws_url);
        }

        const tg_token = std.process.getEnvVarOwned(allocator, "TELEGRAM_BOT_TOKEN") catch "";
        if (tg_token.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "TELEGRAM_BOT_TOKEN", tg_token) catch {};
            allocator.free(tg_token);
        }

        const tg_chat = std.process.getEnvVarOwned(allocator, "TELEGRAM_CHAT_ID") catch "";
        if (tg_chat.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "TELEGRAM_CHAT_ID", tg_chat) catch {};
            allocator.free(tg_chat);
        }

        // Enable Telegram log streaming by default
        _ = api.upsertVariable(service_id, env_id, "TELEGRAM_STREAM", "true") catch {};

        const mon_token = std.process.getEnvVarOwned(allocator, "MONITOR_TOKEN") catch "";
        if (mon_token.len > 0) {
            _ = api.upsertVariable(service_id, env_id, "MONITOR_TOKEN", mon_token) catch {};
            allocator.free(mon_token);
        }

        allocator.free(env_id);
    }

    // 4. Save to state
    if (agent_count < MAX_AGENTS) {
        var entry = &agents[agent_count];
        entry.issue = issue_number;
        entry.active = true;
        entry.created_at = std.time.timestamp();
        entry.service_id_len = @min(service_id.len, 128);
        @memcpy(entry.service_id[0..entry.service_id_len], service_id[0..entry.service_id_len]);
        agent_count += 1;
    }
    saveState();

    return SpawnResult{
        .service_id = service_id,
        .issue_number = issue_number,
        .status = "spawned",
    };
}

/// Kill an agent container for the given issue number.
pub fn killAgent(allocator: Allocator, issue_number: u32) !void {
    loadState();

    var api = railway_api.RailwayApi.init(allocator) catch
        return error.ApiInitFailed;
    defer api.deinit();

    for (agents[0..agent_count]) |*a| {
        if (a.issue == issue_number and a.active) {
            _ = api.deleteService(a.getServiceId()) catch {};
            a.active = false;
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
        if (!first) w.writeAll(",") catch {};
        first = false;
        std.fmt.format(w, "{{\"issue\":{d},\"service_id\":\"{s}\",\"created_at\":{d}}}", .{
            a.issue,
            a.getServiceId(),
            a.created_at,
        }) catch break;
    }

    w.writeAll("],\"count\":") catch {};
    var active: u32 = 0;
    for (agents[0..agent_count]) |*a| {
        if (a.active) active += 1;
    }
    std.fmt.format(w, "{d},\"max\":{d}}}", .{ active, MAX_CONCURRENT_AGENTS }) catch {};

    return fbs.getWritten();
}

/// Cleanup all agents marked as done (inactive). Returns count cleaned.
pub fn cleanupDone(allocator: Allocator) !u32 {
    loadState();

    var api = railway_api.RailwayApi.init(allocator) catch
        return error.ApiInitFailed;
    defer api.deinit();

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

        var entry = &agents[agent_count];
        entry.issue = issue_num;
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
        if (!first) w.writeAll(",") catch {};
        first = false;
        std.fmt.format(w, "\n  {{\"issue\":{d},\"service_id\":\"{s}\",\"created_at\":{d}}}", .{
            a.issue,
            a.getServiceId(),
            a.created_at,
        }) catch return;
    }

    w.writeAll("\n]\n") catch return;

    const file = std.fs.cwd().createFile(STATE_FILE, .{}) catch return;
    defer file.close();
    file.writeAll(fbs.getWritten()) catch return;
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
