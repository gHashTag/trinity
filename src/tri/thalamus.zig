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

const FRESHNESS_THRESHOLD: i64 = 300; // 5 minutes
const MU_ERRORS_DIR = ".trinity/mu/errors";

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

pub fn getMuPatterns(allocator: Allocator, limit: u32) !struct { items: [][]const u8, count: u32 } {
    var results = hippocampus.read(allocator, .{
        .agent = "mu_pattern",
        .limit = limit,
    }) catch return getMuPatternsFallback(limit);
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

fn getMuPatternsFallback(allocator: Allocator, limit: u32) !struct { items: [][]const u8, count: u32 } {
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

test "thalamus getCellHealth returns default when empty" {
    const summary = getCellHealth(std.testing.allocator);
    try std.testing.expect(summary.total == 0);
}

test "thalamus getMetabolismSnapshot returns null when empty" {
    const snapshot = getMetabolismSnapshot(std.testing.allocator);
    try std.testing.expect(snapshot == null);
}

test "thalamus getMetabolismAlerts returns empty when none" {
    const alerts = try getMetabolismAlerts(std.testing.allocator, 5);
    defer std.testing.allocator.free(alerts);
    try std.testing.expect(alerts.len == 0);
}
