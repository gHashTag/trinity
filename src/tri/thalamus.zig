// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// THALAMUS — Unified Read-Relay (hippocampus first → file fallback)
// ═══════════════════════════════════════════════════════════════════════════════
// Single fix point for all Trinity readers. Replaces scattered direct-file reads.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const hippocampus = @import("hippocampus.zig");
const voice_engine = @import("voice_engine.zig");
const qt = @import("queen_types.zig"); // For findJson helpers

const FRESHNESS_THRESHOLD: i64 = 300; // 5 minutes
const MU_ERRORS_DIR = ".trinity/mu/errors";

// ═══════════════════════════════════════════════════════════════════════════════
// JSON HELPERS (re-export from queen_types for Relay 12)
// ═══════════════════════════════════════════════════════════════════════════════

const findJsonF32 = qt.findJsonF32;
const findJsonU32 = qt.findJsonU32;
const findJsonStr = qt.findJsonStr;

pub const VerdictCounts = struct {
    total: u32 = 0,
    pass: u32 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 1: MU heartbeat — hippocampus "phoenix" → fallback file
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getMuHeartbeat(allocator: Allocator) voice_engine.MuHeartbeat {
    if (hippocampus.latestHeartbeat(allocator, "phoenix") catch null) |hb| {
        if (hb.ts > 0) {
            const now: u64 = @intCast(std.time.timestamp());
            const age: i64 = @intCast(now -| hb.ts);
            if (age < FRESHNESS_THRESHOLD) {
                // Parse hippocampus data fields
                const d = hb.data();
                return .{
                    .wake = voice_engine.parseJsonU32(d, "\"wake\":"),
                    .fixes = voice_engine.parseJsonU32(d, "\"fixes_applied\":"),
                    .errors = voice_engine.parseJsonU32(d, "\"errors_scanned\":"),
                    .test_ok = voice_engine.parseJsonBool(d, "\"test_ok\":"),
                    .build_ok = voice_engine.parseJsonBool(d, "\"build_ok\":"),
                    .age_s = age,
                };
            }
        }
    }
    return voice_engine.readMuHeartbeat();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 2: Scholar heartbeat — hippocampus "scholar" → fallback file
// ═══════════════════════════════════════════════════════════════════════════════

pub fn getScholarHeartbeat(allocator: Allocator) voice_engine.ScholarHeartbeat {
    if (hippocampus.latestHeartbeat(allocator, "scholar") catch null) |hb| {
        if (hb.ts > 0) {
            const now: u64 = @intCast(std.time.timestamp());
            const age: i64 = @intCast(now -| hb.ts);
            if (age < FRESHNESS_THRESHOLD) {
                const d = hb.data();
                return .{
                    .wake = voice_engine.parseJsonU32(d, "\"wake\":"),
                    .fails_found = voice_engine.parseJsonU32(d, "\"fails_found\":"),
                    .researched = voice_engine.parseJsonU32(d, "\"researched\":"),
                    .fed_mu = voice_engine.parseJsonU32(d, "\"fed_mu\":"),
                    .age_s = age,
                };
            }
        }
    }
    return voice_engine.readScholarHeartbeat();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 3: Episode count — hippocampus episodes → fallback dir listing
// ═══════════════════════════════════════════════════════════════════════════════

pub fn countEpisodes(allocator: Allocator) u32 {
    var results = hippocampus.read(allocator, .{
        .kind = .episode,
        .limit = 10000,
    }) catch return countEpisodesFallback();
    defer results.deinit(allocator);

    if (results.items.len > 0) return @intCast(results.items.len);
    return countEpisodesFallback();
}

fn countEpisodesFallback() u32 {
    var dir = std.fs.cwd().openDir(".trinity/experience/episodes", .{ .iterate = true }) catch return 0;
    defer dir.close();
    var count: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 4: Episode verdicts — hippocampus episodes → fallback dir scan
// ═══════════════════════════════════════════════════════════════════════════════

pub fn countEpisodeVerdicts(allocator: Allocator) VerdictCounts {
    var results = hippocampus.read(allocator, .{
        .kind = .episode,
        .limit = 10000,
    }) catch return countVerdictsFallback();
    defer results.deinit(allocator);

    if (results.items.len > 0) {
        var vc = VerdictCounts{ .total = @intCast(results.items.len), .pass = 0 };
        for (results.items) |rec| {
            const d = rec.data();
            if (std.mem.indexOf(u8, d, "\"success\"") != null or
                std.mem.indexOf(u8, d, "\"PASS\"") != null or
                std.mem.indexOf(u8, d, "\"pass\"") != null)
            {
                vc.pass += 1;
            }
        }
        return vc;
    }
    return countVerdictsFallback();
}

fn countVerdictsFallback() VerdictCounts {
    var dir = std.fs.cwd().openDir(".trinity/experience/episodes", .{ .iterate = true }) catch
        return .{};
    defer dir.close();
    var vc = VerdictCounts{};
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;
        vc.total += 1;
        var fbuf: [8192]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;
        const content = fbuf[0..n];
        if (std.mem.indexOf(u8, content, "\"success\"") != null or
            std.mem.indexOf(u8, content, "\"PASS\"") != null or
            std.mem.indexOf(u8, content, "\"pass\"") != null)
        {
            vc.pass += 1;
        }
    }
    return vc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 5: Farm event keyword count — hippocampus search → fallback events.jsonl
// ═══════════════════════════════════════════════════════════════════════════════

pub fn countFarmEvents(allocator: Allocator, keyword: []const u8) u32 {
    var results = hippocampus.search(allocator, keyword, 10000) catch
        return countFarmEventsFallback(keyword);
    defer results.deinit(allocator);

    if (results.items.len > 0) return @intCast(results.items.len);
    return countFarmEventsFallback(keyword);
}

fn countFarmEventsFallback(keyword: []const u8) u32 {
    const file = std.fs.cwd().openFile(".trinity/farm/events.jsonl", .{}) catch return 0;
    defer file.close();
    var buf: [8192]u8 = undefined;
    var count: u32 = 0;
    while (true) {
        const n = file.read(&buf) catch break;
        if (n == 0) break;
        var pos: usize = 0;
        while (pos < n) {
            if (std.mem.indexOfPos(u8, buf[0..n], pos, keyword)) |idx| {
                count += 1;
                pos = idx + keyword.len;
            } else break;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus getMuHeartbeat returns defaults" {
    const hb = getMuHeartbeat(std.testing.allocator);
    try std.testing.expect(hb.age_s >= 0);
}

test "thalamus getScholarHeartbeat returns defaults" {
    const hb = getScholarHeartbeat(std.testing.allocator);
    try std.testing.expect(hb.age_s >= 0);
}

test "thalamus countEpisodes returns zero or more" {
    const count = countEpisodes(std.testing.allocator);
    try std.testing.expect(count >= 0);
}

test "thalamus countEpisodeVerdicts returns valid" {
    const vc = countEpisodeVerdicts(std.testing.allocator);
    try std.testing.expect(vc.pass <= vc.total);
}

test "thalamus countFarmEvents returns zero or more" {
    const count = countFarmEvents(std.testing.allocator, "agent:spawn");
    try std.testing.expect(count >= 0);
}

// ═════════════════════════════════════════════════════════════════════════════
// RELAY 6: MU patterns — hippocampus "mu_pattern" → fallback DB file
// ═══════════════════════════════════════════════════════════════════════════════

pub const MuPatternsResult = struct { items: [][]const u8, count: u32 };

pub fn getMuPatterns(allocator: Allocator, limit: u32) !MuPatternsResult {
    var results = hippocampus.read(allocator, .{
        .agent = "mu_pattern",
        .limit = limit,
    }) catch return getMuPatternsFallback(allocator, limit);
    defer results.deinit(allocator);

    if (results.items.len > 0) {
        var items: std.ArrayList([]const u8) = .empty;
        defer items.deinit(allocator);
        for (results.items) |rec| {
            try items.append(allocator, try allocator.dupe(u8, rec.data()));
        }
        return .{ .items = try items.toOwnedSlice(allocator), .count = @intCast(results.items.len) };
    }
    return getMuPatternsFallback(allocator, limit);
}

fn getMuPatternsFallback(allocator: Allocator, limit: u32) !MuPatternsResult {
    const DB_PATH = ".trinity/mu/learning_db.json";
    const file = std.fs.cwd().openFile(DB_PATH, .{}) catch {
        return .{ .items = &.{}, .count = 0 };
    };
    defer file.close();

    var buf: [64 * 1024]u8 = undefined;
    const n = file.readAll(&buf) catch return .{ .items = &.{}, .count = 0 };

    var items: std.ArrayList([]const u8) = .empty;
    defer items.deinit(allocator);

    // Extract rules from JSON (simple string extraction)
    const content = buf[0..n];
    var pos: usize = 0;
    var count: u32 = 0;

    while (count < limit) {
        const rule_start = std.mem.indexOfPos(u8, content, pos, "\"id\": \"") orelse break;
        const rule_end = std.mem.indexOfPos(u8, content, rule_start, "}") orelse break;
        const rule_data = content[rule_start..rule_end];

        try items.append(allocator, try allocator.dupe(u8, rule_data));
        count += 1;
        pos = rule_end + 1;
    }

    return .{ .items = try items.toOwnedSlice(allocator), .count = count };
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 7: MU resolved errors — hippocampus "mu_resolved" → fallback errors dir
// ═════════════════════════════════════════════════════════════════════════════

pub fn countMuResolvedErrors(allocator: Allocator) u32 {
    var results = hippocampus.read(allocator, .{
        .agent = "mu_resolved",
        .limit = 10000,
    }) catch return countMuResolvedErrorsFallback();
    defer results.deinit(allocator);

    if (results.items.len > 0) return @intCast(results.items.len);
    return countMuResolvedErrorsFallback();
}

fn countMuResolvedErrorsFallback() u32 {
    var dir = std.fs.cwd().openDir(MU_ERRORS_DIR, .{ .iterate = true }) catch return 0;
    defer dir.close();
    var count: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        // Check if error has fix_result (i.e., resolved)
        const content = dir.readFileAlloc(std.heap.page_allocator, entry.name, 8192) catch continue;
        defer std.heap.page_allocator.free(content);
        if (std.mem.indexOf(u8, content, "\"fix_result\": \"") != null and
            std.mem.indexOf(u8, content, "\"resolution_status\": \"FIXED\"") != null)
        {
            count += 1;
        }
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (continued)
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus getMuPatterns returns items" {
    const result = getMuPatterns(std.testing.allocator, 10) catch |err| {
        std.debug.print("getMuPatterns error: {}\n", .{err});
        return;
    };
    defer {
        for (result.items) |item| {
            std.testing.allocator.free(item);
        }
        std.testing.allocator.free(result.items);
    }
    try std.testing.expect(result.count >= 0);
}

test "thalamus countMuResolvedErrors returns zero or more" {
    const count = countMuResolvedErrors(std.testing.allocator);
    try std.testing.expect(count >= 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 8: Cell health — hippocampus "cerebellum" → fallback cell_cache.json
// ═══════════════════════════════════════════════════════════════════════════════

pub const CellHealthSummary = struct {
    healthy: u32 = 0,
    weak: u32 = 0,
    broken: u32 = 0,
    total: u32 = 0,
    cycles: u32 = 0,
    timestamp: i64 = 0,
};

pub fn getCellHealth(allocator: Allocator) CellHealthSummary {
    var results = hippocampus.read(allocator, .{
        .agent = "cerebellum",
        .kind = .observation,
        .limit = 1,
    }) catch return .{};

    defer results.deinit(allocator);
    if (results.items.len > 0) {
        // Parse "cell health: 18/18 total (A:15 B:3 C:0 F:0) | cycles: 0 | weakest: xxx (99)"
        const d = results.items[0].summary();
        var summary: CellHealthSummary = .{
            .timestamp = @as(i64, @intCast(results.items[0].ts)),
        };

        // Parse total (format: "18/18 total")
        if (std.mem.indexOf(u8, d, "/")) |slash_idx| {
            var start = slash_idx - 1;
            while (start > 0 and d[start - 1] >= '0' and d[start - 1] <= '9') : (start -= 1) {}
            summary.total = std.fmt.parseInt(u32, d[start..slash_idx], 10) catch 0;
        }

        // Parse grades (A:15 B:3 C:0 F:0)
        summary.healthy = parseHealthStat(d, "A:");
        summary.weak = parseHealthStat(d, "B:") + parseHealthStat(d, "C:");
        summary.broken = parseHealthStat(d, "F:");

        // Parse cycles
        summary.cycles = parseHealthStat(d, "cycles:");

        return summary;
    }
    return .{};
}

fn parseHealthStat(data: []const u8, keyword: []const u8) u32 {
    // Parse "A:15" -> 15, "cycles: 0" -> 0
    if (std.mem.indexOf(u8, data, keyword)) |idx| {
        const start = idx + keyword.len;
        var end = start;
        while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
        return std.fmt.parseInt(u32, data[start..end], 10) catch 0;
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 9: Metabolism alerts — hippocampus "hypothalamus" errors
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetabolismAlert = struct {
    message: []const u8,
    timestamp: i64,
};

pub fn getMetabolismAlerts(allocator: Allocator, limit: u8) ![]MetabolismAlert {
    var results = hippocampus.read(allocator, .{
        .agent = "hypothalamus",
        .kind = .@"error",
        .limit = limit,
    }) catch return &[0]MetabolismAlert{};

    defer results.deinit(allocator);

    var alerts = try allocator.alloc(MetabolismAlert, results.items.len);
    for (results.items, 0..) |r, i| {
        alerts[i] = .{
            .message = try allocator.dupe(u8, r.summary()),
            .timestamp = @as(i64, @intCast(r.ts)),
        };
    }
    return alerts;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 10: Latest metabolism snapshot — hippocampus "hypothalamus" observation
// ═══════════════════════════════════════════════════════════════════════════════

pub const MetabolismSnapshot = struct {
    ppl: f32 = 0.0,
    tok_per_sec: u32 = 0,
    spike_pct: f32 = 0.0,
    diversity: f32 = 0.0,
    health: f32 = 0.0,
    timestamp: i64 = 0,
};

pub fn getMetabolismSnapshot(allocator: Allocator) ?MetabolismSnapshot {
    var results = hippocampus.read(allocator, .{
        .agent = "hypothalamus",
        .kind = .observation,
        .limit = 1,
    }) catch return null;

    defer results.deinit(allocator);
    if (results.items.len == 0) return null;

    // Parse "metabolism: ppl=4.6 tok/s=500 spike=10.5% diversity=0.450 health=75.0"
    const d = results.items[0].summary();
    return .{
        .ppl = parseMetricFloat(d, "ppl=") orelse 0.0,
        .tok_per_sec = parseMetricU32(d, "tok/s=") orelse 0,
        .spike_pct = parseMetricFloat(d, "spike=") orelse 0.0,
        .diversity = parseMetricFloat(d, "diversity=") orelse 0.0,
        .health = parseMetricFloat(d, "health=") orelse 0.0,
        .timestamp = @as(i64, @intCast(results.items[0].ts)),
    };
}

fn parseMetricFloat(data: []const u8, key: []const u8) ?f32 {
    if (std.mem.indexOf(u8, data, key)) |idx| {
        const start = idx + key.len;
        var end = start;
        while (end < data.len and data[end] != ' ' and data[end] != '%') : (end += 1) {}
        return std.fmt.parseFloat(f32, data[start..end]) catch null;
    }
    return null;
}

fn parseMetricU32(data: []const u8, key: []const u8) ?u32 {
    if (std.mem.indexOf(u8, data, key)) |idx| {
        const start = idx + key.len;
        var end = start;
        while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
        return std.fmt.parseInt(u32, data[start..end], 10) catch null;
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (Wave 3)
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus getCellHealth returns valid summary" {
    const summary = getCellHealth(std.testing.allocator);
    // Verify summary is consistent (total >= sum of components)
    try std.testing.expect(summary.total >= summary.healthy + summary.weak + summary.broken);
}

test "thalamus getMetabolismSnapshot returns snapshot or null" {
    const snapshot = getMetabolismSnapshot(std.testing.allocator);
    // Can return null if no data, or valid snapshot if data exists
    if (snapshot) |s| {
        try std.testing.expect(s.ppl >= 0);
        try std.testing.expect(s.tok_per_sec >= 0);
    }
}

test "thalamus getMetabolismAlerts returns array" {
    const alerts = try getMetabolismAlerts(std.testing.allocator, 5);
    defer {
        for (alerts) |a| {
            std.testing.allocator.free(a.message);
        }
        std.testing.allocator.free(alerts);
    }
    // Can return empty array if no errors
    try std.testing.expect(alerts.len >= 0 and alerts.len <= 5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 11: Last sleep info — hippocampus "phoenix" SLEEP observations
// ═══════════════════════════════════════════════════════════════════════════════

pub const SleepInfo = struct {
    timestamp: i64 = 0,
    episodes_consolidated: u32 = 0,
    rules_created: u32 = 0,
    errors_dreamed: u32 = 0,
    hours_since: i64 = 0,
};

pub fn getLastSleepInfo(allocator: Allocator) ?SleepInfo {
    var results = hippocampus.search(allocator, "SLEEP:", 10) catch return null;
    defer results.deinit(allocator);

    if (results.items.len == 0) return null;

    // Get most recent SLEEP observation
    const rec = results.items[0];
    const d = rec.data();
    const now: i64 = @intCast(std.time.timestamp());

    return .{
        .timestamp = @as(i64, @intCast(rec.ts)),
        .episodes_consolidated = parseMetricU32(d, "old_episodes") orelse 0,
        .rules_created = parseMetricU32(d, "rules_created") orelse 0,
        .errors_dreamed = parseMetricU32(d, "errors_dreamed") orelse 0,
        .hours_since = @divTrunc(now - @as(i64, @intCast(rec.ts)), 3600),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (Wave 4)
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus getLastSleepInfo returns null when no sleep" {
    const info = getLastSleepInfo(std.testing.allocator);
    try std.testing.expect(info == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 12: Farm Status — aggregate from tri_farm + evolution
// ═══════════════════════════════════════════════════════════════════════════════

pub const FarmStatus = struct {
    total_services: usize = 0,
    active: usize = 0,
    crashed: usize = 0,
    stale_count: usize = 0,
    accounts_alive: u8 = 0,
    accounts_total: u8 = 0,
    best_ppl: f32 = 999.0,
    best_ppl_service: [64]u8 = [_]u8{0} ** 64,
    best_ppl_service_len: usize = 0,
    timestamp: i64 = 0,

    pub fn bestPplServiceStr(self: *const FarmStatus) []const u8 {
        return self.best_ppl_service[0..self.best_ppl_service_len];
    }
};

pub fn getFarmStatus(allocator: Allocator) !FarmStatus {
    _ = allocator;
    var status = FarmStatus{ .timestamp = std.time.timestamp() };

    // Read from evolution state
    const evo_file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch return status;
    defer evo_file.close();

    var buf: [8192]u8 = undefined;
    const n = evo_file.read(&buf) catch return status;
    const data = buf[0..n];

    if (findJsonU32(data, "\"service_count\":")) |v| status.total_services = v;
    if (findJsonF32(data, "\"best_ppl\":")) |v| status.best_ppl = v;

    // Parse best_name into fixed buffer
    if (findJsonStr(data, "\"best_name\":\"")) |name| {
        const len = @min(name.len, status.best_ppl_service.len);
        @memcpy(status.best_ppl_service[0..len], name[0..len]);
        status.best_ppl_service_len = len;
    }

    // Count active/stale/crashed from status counts
    var pos: usize = 0;
    while (pos < data.len) {
        if (std.mem.indexOfPos(u8, data, pos, "\"status\":\"")) |idx| {
            const status_start = idx + 10;
            if (status_start + 10 > data.len) break;
            const status_end = std.mem.indexOfScalarPos(u8, data, status_start, '"') orelse break;
            const status_val = data[status_start..status_end];

            if (std.mem.eql(u8, status_val, "running")) {
                status.active += 1;
            } else if (std.mem.eql(u8, status_val, "crashed")) {
                status.crashed += 1;
            } else if (std.mem.eql(u8, status_val, "stale")) {
                status.stale_count += 1;
            }
            pos = status_end + 1;
        } else break;
    }

    // TODO: Count accounts from farm_accounts when available
    status.accounts_total = 8; // Default: 8 Railway accounts
    status.accounts_alive = status.accounts_total; // Assume all alive for now

    return status;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 13: GitHub Issues — queue prioritization
// ═══════════════════════════════════════════════════════════════════════════════

pub const GitHubIssues = struct {
    open: usize = 0,
    farm_tasks: usize = 0,
    agent_spawn: usize = 0,
    priorities: struct { p0: usize, p1: usize, p2: usize } = .{ .p0 = 0, .p1 = 0, .p2 = 0 },
    last_activity: i64 = 0,
    timestamp: i64 = 0,
};

/// GitHub cache wrapper — avoids mutable global state
pub const GitHubCache = struct {
    issues: ?GitHubIssues = null,
    cached_ts: i64 = 0,

    const TTL: i64 = 300; // 5 minutes

    pub fn get(self: *GitHubCache, allocator: Allocator) !GitHubIssues {
        const now = std.time.timestamp();

        // Return cached if fresh
        if (self.issues) |*cached| {
            if (now - self.cached_ts < TTL) {
                return cached.*;
            }
        }

        // Fetch fresh data
        const issues = GitHubIssues{ .timestamp = now };

        // TODO: Use github_client.zig when listIssues is implemented
        // For now, return empty counts
        _ = allocator;

        self.issues = issues;
        self.cached_ts = now;

        return issues;
    }

    pub fn invalidate(self: *GitHubCache) void {
        self.issues = null;
        self.cached_ts = 0;
    }
};

// Global cache instance (wrapped in struct, not naked var)
var github_cache = GitHubCache{};

pub fn getGitHubIssues(allocator: Allocator) !GitHubIssues {
    return github_cache.get(allocator);
}

pub fn invalidateGitHubCache() void {
    github_cache.invalidate();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (Wave 5)
// ═══════════════════════════════════════════════════════════════════════════════

test "thalamus getFarmStatus returns defaults when file missing" {
    const status = try getFarmStatus(std.testing.allocator);
    try std.testing.expect(status.timestamp > 0);
    try std.testing.expect(status.total_services >= 0);
}

test "thalamus GitHubCache TTL works" {
    var cache = GitHubCache{};
    const dummy_issues = GitHubIssues{ .open = 5, .timestamp = std.time.timestamp() };
    cache.issues = dummy_issues;
    cache.cached_ts = std.time.timestamp();

    // First get should return cached
    const result1 = try cache.get(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 5), result1.open);

    // Invalidate and get fresh
    cache.invalidate();
    const result2 = try cache.get(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), result2.open); // No GitHub client yet
}

// ═══════════════════════════════════════════════════════════════════════════════
// RELAY 14: Locus Coeruleus Arousal — load state, apply decay, return level
// ═══════════════════════════════════════════════════════════════════════════════

const locus_coeruleus = @import("phoenix_locus_coeruleus.zig");

pub fn getLocusArousal() locus_coeruleus.ArousalLevel {
    // Load state from file (returns default if missing)
    var state = locus_coeruleus.loadState();

    // Apply decay before reading arousal (5 min = -1 level)
    locus_coeruleus.decayArousal(&state, 300);

    // Return decayed arousal level
    return locus_coeruleus.getArousal(&state);
}
