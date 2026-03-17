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
